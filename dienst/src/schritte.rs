//! Die gezaehlten Schritte hochladen.
//!
//! Gezaehlt wird vom Schrittdienst (wzf-schritte); er schreibt Tagessummen
//! nach ~/.local/share/wienzufuss/schritte.json:
//!
//!   {"version":1, "quelle":"hardware", "tage":{"2026-10-05":8123, ...}, ...}
//!
//! Hochgeladen werden Tagessummen wie bei der Android-App
//! (`POST v1/user/health`). Ob der Server je Datum ersetzt oder addiert, ist
//! nicht beobachtet, nur aus dem Verhalten der App geschlossen. Und am Server
//! stehen meist schon Tage, die das Android-Telefon gezaehlt hat. Deshalb:
//!
//! * nur Tage, fuer die es hier eine Zaehlung gibt -- nie Nullen fuer Tage,
//!   an denen nicht gezaehlt wurde;
//! * vorher den Stand am Server lesen und einen Tag nur schicken, wenn hier
//!   MEHR Schritte stehen als dort: ein Wert am Server wird nie kleiner;
//! * nachher noch einmal lesen. Steht dort nicht genau, was geschickt wurde,
//!   haelt das Hochladen an (sync.json "gesperrt"), bis der Nutzer es in der
//!   App wieder freigibt.

use crate::api::Kontext;
use crate::{einstellungen, protokoll, zeit};
use serde_json::{json, Value};
use std::collections::BTreeMap;
use std::io::Write;

/// So weit zurueck wird hochgeladen (heute eingeschlossen).
const TAGE_ZURUECK: i64 = 13;

fn schritte_von(v: &Value) -> Option<u64> {
    match v {
        Value::Number(n) => n.as_u64().or_else(|| n.as_f64().filter(|f| *f >= 0.0).map(|f| f.round() as u64)),
        Value::String(t) => t.trim().parse().ok(),
        _ => None,
    }
}

/// Die Tage aus schritte.json, nur gueltige Daten mit mehr als 0 Schritten.
fn lokale_tage(k: &Kontext) -> BTreeMap<String, u64> {
    let mut aus = BTreeMap::new();
    let datei = match k.ablage.lesen(&k.ablage.schritte()) {
        Some(d) => d,
        None => return aus,
    };
    if let Some(Value::Object(tage)) = datei.get("tage") {
        for (datum, wert) in tage {
            let n = match wert {
                Value::Object(o) => o.get("schritte").and_then(schritte_von),
                anders => schritte_von(anders),
            };
            if let (Some(_), Some(n)) = (zeit::datum_lesen(datum), n) {
                if n > 0 {
                    aus.insert(datum[0..10].to_string(), n);
                }
            }
        }
    }
    aus
}

/// Was die Oberflaeche fuer Startseite und Verlauf braucht: die lokale
/// Zaehlung, den Stand des Hochladens und die Einstellungen.
pub fn lokal(k: &Kontext) -> Value {
    let datei = k.ablage.lesen(&k.ablage.schritte()).unwrap_or(Value::Null);
    let sync = k.ablage.lesen(&k.ablage.sync()).unwrap_or(json!({}));
    let tage: serde_json::Map<String, Value> =
        lokale_tage(k).into_iter().map(|(d, n)| (d, json!(n))).collect();
    let heute = zeit::heute();
    json!({
        "heute": heute,
        "schritteHeute": tage.get(&heute).cloned().unwrap_or(json!(0)),
        "tage": tage,
        "quelle": datei.get("quelle").cloned().unwrap_or(Value::Null),
        "hinweis": datei.get("hinweis").cloned().unwrap_or(Value::Null),
        "stand": datei.get("stand").cloned().unwrap_or(Value::Null),
        "sync": sync,
        "einstellungen": einstellungen::laden(&k.ablage),
    })
}

/// Server-Stand je Tag aus der Antwort von GET v1/user/health. Liefert
/// None, wenn die Antwort nicht nach einer Liste von Tagen aussieht -- dann
/// wird NICHT hochgeladen, denn ohne den Server-Stand laesst sich nicht
/// garantieren, dass kein Wert kleiner wird.
fn server_tage(antwort: &Value) -> Option<BTreeMap<String, u64>> {
    let liste = antwort.as_array()?;
    let mut aus = BTreeMap::new();
    for e in liste {
        let datum = ["from", "date", "until"]
            .iter()
            .filter_map(|k| e.get(*k).and_then(Value::as_str))
            .find(|d| zeit::datum_lesen(d).is_some())?;
        let n = e.get("steps").and_then(schritte_von)?;
        let d = datum[0..10].to_string();
        let alt = aus.get(&d).copied().unwrap_or(0);
        aus.insert(d, alt.max(n));
    }
    Some(aus)
}

fn protokoll_upload(k: &Kontext, text: &str) {
    let pfad = k.ablage.daten.join("hochgeladen.log");
    if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(pfad) {
        let _ = writeln!(f, "{} {}", zeit::jetzt_text(), text);
    }
}

pub fn synchronisieren(k: &Kontext, werte: &Value, hintergrund: bool) -> Result<Value, String> {
    let einst = einstellungen::laden(&k.ablage);
    if !einst.get("hochladen").and_then(Value::as_bool).unwrap_or(false) {
        if hintergrund {
            return Ok(json!({ "uebersprungen": "Hochladen ist ausgeschaltet." }));
        }
        return Err("Das Hochladen ist in den Einstellungen ausgeschaltet.".into());
    }
    if k.angemeldet().is_none() {
        if hintergrund {
            return Ok(json!({ "uebersprungen": "Nicht angemeldet." }));
        }
        return Err(format!("{} Bitte zuerst anmelden.", crate::api::ABGEMELDET));
    }

    let sync_pfad = k.ablage.sync();
    let mut sync = k.ablage.lesen(&sync_pfad).unwrap_or(json!({}));
    if !sync.is_object() {
        sync = json!({});
    }
    if let Some(grund) = sync.get("gesperrt").and_then(Value::as_str) {
        if werte.get("freigeben").and_then(Value::as_bool) == Some(true) && !hintergrund {
            protokoll_upload(k, &format!("Sperre aufgehoben ({})", grund));
            sync.as_object_mut().unwrap().remove("gesperrt");
        } else {
            return Err(format!("Hochladen angehalten: {}", grund));
        }
    }

    let heute = zeit::heute();
    let heute_t = zeit::datum_lesen(&heute).unwrap_or(0);
    let tage: BTreeMap<String, u64> = lokale_tage(k)
        .into_iter()
        .filter(|(d, _)| {
            let t = zeit::datum_lesen(d).unwrap_or(0);
            t >= heute_t - TAGE_ZURUECK && t <= heute_t
        })
        .collect();
    let jetzt = zeit::jetzt_text();
    if tage.is_empty() {
        return Ok(json!({ "gesendet": [], "hinweis": "Noch keine gezählten Schritte." }));
    }
    let von = tage.keys().next().cloned().unwrap_or_else(|| heute.clone());
    let pfad = format!("v1/user/health?from={}&until={}&grouping=DAY", von, heute);

    let vorher = server_tage(&k.backend("GET", &pfad, None)?)
        .ok_or("Der Stand am Server ist nicht lesbar – nichts hochgeladen.")?;

    let laenge = einstellungen::schrittlaenge(&einst);
    let mut senden = Vec::new();
    let mut gleich = 0;
    for (d, n) in &tage {
        let am_server = vorher.get(d).copied().unwrap_or(0);
        if *n > am_server {
            let meter = (*n as f64 * laenge * 10.0).round() / 10.0;
            senden.push(json!({ "date": d, "steps": n, "distance": meter }));
        } else {
            gleich += 1;
        }
    }
    sync["letzterAbgleich"] = json!(jetzt);
    if senden.is_empty() {
        let _ = k.ablage.schreiben(&sync_pfad, &sync);
        return Ok(json!({
            "gesendet": [],
            "hinweis": "Am Server steht schon gleich viel oder mehr.",
            "unveraendert": gleich,
        }));
    }

    k.backend("POST", "v1/user/health", Some(&json!({ "health": senden })))?;
    for e in &senden {
        protokoll_upload(k, &format!("gesendet {} {} Schritte", e["date"].as_str().unwrap_or(""), e["steps"]));
    }

    // Nachkontrolle: steht am Server jetzt genau, was geschickt wurde?
    let mut abweichung = Vec::new();
    match k.backend("GET", &pfad, None).ok().as_ref().and_then(server_tage) {
        Some(nachher) => {
            for e in &senden {
                let d = e["date"].as_str().unwrap_or("");
                let soll = e["steps"].as_u64().unwrap_or(0);
                let ist = nachher.get(d).copied().unwrap_or(0);
                if ist != soll {
                    abweichung.push(json!({ "date": d, "gesendet": soll, "amServer": ist,
                                            "vorher": vorher.get(d).copied().unwrap_or(0) }));
                }
            }
        }
        None => protokoll("sync: Nachkontrolle nicht lesbar"),
    }
    if !abweichung.is_empty() {
        let grund = format!(
            "Nach dem Hochladen stand am Server ein anderer Wert als geschickt ({}). \
             Automatisches Hochladen ist angehalten.",
            abweichung
                .iter()
                .map(|a| format!("{}: {} statt {}", a["date"].as_str().unwrap_or(""), a["amServer"], a["gesendet"]))
                .collect::<Vec<_>>()
                .join(", ")
        );
        protokoll(&format!("sync: {}", grund));
        protokoll_upload(k, &grund);
        sync["gesperrt"] = json!(grund);
    }

    sync["letzter"] = json!(jetzt);
    let mut gesendet = sync.get("gesendet").cloned().unwrap_or(json!({}));
    if !gesendet.is_object() {
        gesendet = json!({});
    }
    for e in &senden {
        gesendet[e["date"].as_str().unwrap_or("")] = e["steps"].clone();
    }
    // Nur die letzten Wochen behalten.
    if let Value::Object(m) = &mut gesendet {
        let alt: Vec<String> = m
            .keys()
            .filter(|d| zeit::datum_lesen(d).map(|t| t < heute_t - 60).unwrap_or(true))
            .cloned()
            .collect();
        for d in alt {
            m.remove(&d);
        }
    }
    sync["gesendet"] = gesendet;
    let _ = k.ablage.schreiben(&sync_pfad, &sync);
    Ok(json!({ "gesendet": senden, "abweichung": abweichung, "unveraendert": gleich }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn server_liste_lesen() {
        let v = json!([
            { "_id": "a", "from": "2026-10-04", "until": "2026-10-04", "steps": 8123, "distance": 5000.0 },
            { "_id": "b", "from": "2026-10-05T00:00:00.000Z", "until": "2026-10-05", "steps": 312.0 }
        ]);
        let m = server_tage(&v).unwrap();
        assert_eq!(m.get("2026-10-04"), Some(&8123));
        assert_eq!(m.get("2026-10-05"), Some(&312));
        assert!(server_tage(&json!({ "steps": 3 })).is_none());
        assert!(server_tage(&json!([{ "steps": 3 }])).is_none());
        assert_eq!(server_tage(&json!([])).unwrap().len(), 0);
    }
}
