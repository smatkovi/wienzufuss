//! Die Befehle der Oberflaeche und ihre Uebersetzung in Aufrufe an Firebase
//! und an das Backend unter https://wzfapp.wienzufuss.at/api/.
//!
//! Die Antworten des Backends gehen weitgehend unveraendert an die
//! Oberflaeche: ihre Form ist aus den Modellklassen der APK abgelesen, nicht
//! beobachtet, und ein falsch geratener Feldname soll eine Seite nicht
//! still leer lassen. Ergaenzt wird nur, was QML nicht selbst kann:
//! Markdown als HTML (Schluessel `…Html`) und Bilder als lokale Dateien.

use crate::ablage::Ablage;
use crate::einstellungen;
use crate::firebase::{self, Anmeldung};
use crate::netz::{Netz, Rumpf};
use crate::{protokoll, schritte, zeit};
use serde_json::{json, Map, Value};
use std::collections::HashMap;
use std::sync::{Arc, Mutex, OnceLock};

pub const BASIS: &str = "https://wzfapp.wienzufuss.at/api/";

/// Steht am Anfang einer Fehlermeldung, wenn die Anmeldung weg ist. Die
/// Oberflaeche schickt dann zur Anmeldeseite.
pub const ABGEMELDET: &str = "ABGEMELDET:";

pub struct Kontext {
    pub netz: Netz,
    pub ablage: Ablage,
    anmeldung: Mutex<Option<Anmeldung>>,
    /// Nur ein Faden erneuert das Token; die anderen warten und nehmen dann
    /// das neue.
    erneuern: Mutex<()>,
}

fn s<'a>(v: &'a Value, k: &str) -> &'a str {
    v.get(k).and_then(Value::as_str).unwrap_or("")
}

impl Kontext {
    pub fn neu(ablage: Ablage) -> Kontext {
        let anmeldung = Anmeldung::laden(&ablage);
        Kontext {
            netz: Netz::neu(),
            ablage,
            anmeldung: Mutex::new(anmeldung),
            erneuern: Mutex::new(()),
        }
    }

    pub fn angemeldet(&self) -> Option<Anmeldung> {
        self.anmeldung.lock().unwrap_or_else(|e| e.into_inner()).clone()
    }

    fn setzen(&self, a: Option<Anmeldung>) {
        match &a {
            Some(a) => a.sichern(&self.ablage),
            None => self.ablage.loeschen(&self.ablage.anmeldung()),
        }
        *self.anmeldung.lock().unwrap_or_else(|e| e.into_inner()) = a;
    }

    /// Ein gueltiges ID-Token, bei Bedarf erneuert.
    fn token(&self, erzwingen: bool) -> Result<String, String> {
        let _sperre = self.erneuern.lock().unwrap_or_else(|e| e.into_inner());
        let a = match self.angemeldet() {
            Some(a) => a,
            None => return Err(format!("{} Bitte zuerst anmelden.", ABGEMELDET)),
        };
        if !erzwingen && a.gueltig() {
            return Ok(a.id_token);
        }
        match firebase::erneuern(&self.netz, &a) {
            Ok(neu) => {
                let t = neu.id_token.clone();
                self.setzen(Some(neu));
                Ok(t)
            }
            Err(firebase::Fehler::Abgemeldet(t)) => {
                protokoll(&format!("api: {}", t));
                self.setzen(None);
                Err(format!("{} {} Bitte neu anmelden.", ABGEMELDET, t))
            }
            Err(firebase::Fehler::Sonst(t)) => Err(t),
        }
    }

    /// Aufruf ans Backend mit Token. Antwortet es mit 401, wird das Token
    /// einmal erneuert und der Aufruf wiederholt.
    pub fn backend(&self, methode: &str, pfad: &str, rumpf: Option<&Value>) -> Result<Value, String> {
        let url = format!("{}{}", BASIS, pfad);
        let mut token = self.token(false)?;
        let mut versuch = 0;
        loop {
            let r = match rumpf {
                Some(v) => Rumpf::Json(v),
                None => Rumpf::Keiner,
            };
            let a = self.netz.senden(methode, &url, Some(&token), r, false)?;
            if a.status == 401 && versuch == 0 {
                versuch += 1;
                token = self.token(true)?;
                continue;
            }
            if (200..300).contains(&a.status) {
                return a.json();
            }
            return Err(backend_fehler(a.status, &a.text));
        }
    }

    /// Backend ohne Anmeldung (Passwort vergessen).
    fn backend_offen(&self, methode: &str, pfad: &str, rumpf: &Value) -> Result<Value, String> {
        let url = format!("{}{}", BASIS, pfad);
        let a = self.netz.senden(methode, &url, None, Rumpf::Json(rumpf), false)?;
        if (200..300).contains(&a.status) {
            return a.json();
        }
        Err(backend_fehler(a.status, &a.text))
    }
}

/// Fehlertext aus einer Backend-Antwort. Die Form der Fehlerrumpfe ist
/// unbekannt; genommen wird, was nach einer Meldung aussieht.
fn backend_fehler(status: u16, text: &str) -> String {
    let v: Value = serde_json::from_str(text).unwrap_or(Value::Null);
    if let Some(t) = gutschein_fehler(&v) {
        return t.to_string();
    }
    let meldung = ["message", "error", "detail", "title"]
        .iter()
        .filter_map(|k| match v.get(*k) {
            Some(Value::String(t)) => Some(t.clone()),
            Some(Value::Object(o)) => o.get("message").and_then(Value::as_str).map(String::from),
            _ => None,
        })
        .next();
    let grund = match status {
        401 => format!("{} Der Server hat die Anmeldung nicht angenommen.", ABGEMELDET),
        403 => "Das ist für dieses Konto nicht erlaubt.".to_string(),
        404 => "Nicht gefunden.".to_string(),
        429 => "Zu viele Anfragen – bitte kurz warten.".to_string(),
        500..=599 => "Der Server von Wien zu Fuß hat ein Problem.".to_string(),
        _ => format!("Fehler vom Server (HTTP {}).", status),
    };
    match meldung {
        Some(m) if !m.is_empty() => format!("{} ({})", grund, m),
        _ => {
            if text.trim().is_empty() || status == 401 {
                grund
            } else {
                format!("{} {:.160}", grund, text.trim())
            }
        }
    }
}

/// Die Fehler beim Einloesen, mit den Texten der Android-App. Das Backend
/// antwortet mit {statusCode, errorCode, error, message}; errorCode ist die
/// Zahl aus WienZuFussApiErrorCodes (exceptions/ in der APK).
fn gutschein_fehler(v: &Value) -> Option<&'static str> {
    let code = v.get("errorCode").and_then(Value::as_i64).unwrap_or(0);
    let name = ["error", "message"]
        .iter()
        .filter_map(|k| v.get(*k).and_then(Value::as_str))
        .find(|t| t.starts_with("VOUCHER_"))
        .unwrap_or("");
    Some(match (code, name) {
        (10301, _) | (_, "VOUCHER_ALREADY_REDEEMED") => "Dieser Gutschein wurde bereits eingelöst!",
        (10302, _) | (_, "VOUCHER_OUT_OF_STOCK") | (10305, _) | (_, "VOUCHER_CODES_OUT_OF_STOCK") => {
            "Dieser Gutschein ist nicht mehr vorhanden!"
        }
        (10303, _) | (_, "VOUCHER_INVALID_CODE") => "Eingegebener Pin ist ungültig!",
        (10304, _) | (_, "VOUCHER_REQUIRED_STEPS") => "Für diesen Gutschein hast du noch nicht genug Schritte gesammelt.",
        (10324, _) | (_, "VOUCHER_POST_PICKUP_REQUIRED") | (10325, _) | (_, "VOUCHER_EMAIL_PICKUP_REQUIRED") => {
            "Für diesen Gutschein ist diese Option leider nicht möglich."
        }
        _ => return None,
    })
}

/// Schreibt fuer jeden Text-Schluessel, der Markdown sein kann, eine
/// HTML-Fassung daneben: "description" -> "descriptionHtml".
fn html_ergaenzen(v: &mut Value) {
    match v {
        Value::Array(a) => a.iter_mut().for_each(html_ergaenzen),
        Value::Object(o) => {
            let mut neu = Vec::new();
            for (k, w) in o.iter_mut() {
                if let Value::String(t) = w {
                    if k == "description" || k == "redeemText" || k == "eventPickupRestrictionText" {
                        neu.push((format!("{}Html", k), Value::String(markdown(t))));
                    }
                } else {
                    html_ergaenzen(w);
                }
            }
            for (k, w) in neu {
                o.insert(k, w);
            }
        }
        _ => {}
    }
}

/// Markdown -> die HTML-Teilmenge, die Text { textFormat: Text.RichText }
/// in QML 1 und 2 darstellt. Bilder werden zu Links: QML 1 laedt sie sonst
/// selbst nach, und das alte TLS des N9 scheitert daran.
pub fn markdown(md: &str) -> String {
    use pulldown_cmark::{html, Event, Options, Parser, Tag, TagEnd};
    let mut opt = Options::empty();
    opt.insert(Options::ENABLE_STRIKETHROUGH);
    let ereignisse = Parser::new_ext(md, opt).map(|e| match e {
        Event::Start(Tag::Image { dest_url, .. }) => {
            Event::Html(format!("<a href=\"{}\">[Bild]", dest_url).into())
        }
        Event::End(TagEnd::Image) => Event::Html("</a>".into()),
        Event::SoftBreak => Event::HardBreak,
        andere => andere,
    });
    let mut aus = String::new();
    html::push_html(&mut aus, ereignisse);
    aus.trim().to_string()
}

fn fnv(text: &str) -> u64 {
    let mut h: u64 = 0xcbf29ce484222325;
    for b in text.bytes() {
        h ^= b as u64;
        h = h.wrapping_mul(0x100000001b3);
    }
    h
}

/// Laedt ein Bild in den Cache und gibt den Pfad zurueck. QML 1 auf dem N9
/// kann die https-Adressen nicht selbst laden (kein TLS 1.2).
fn bild(k: &Kontext, url: &str) -> Result<Value, String> {
    if !(url.starts_with("https://") || url.starts_with("http://")) {
        return Err("Keine Bildadresse.".into());
    }
    let ordner = k.ablage.bilder();
    let _ = std::fs::create_dir_all(&ordner);
    let stamm = format!("{:016x}", fnv(url));
    let im_cache = || -> Option<Value> {
        for endung in ["png", "jpg", "gif", "webp", "svg", "bild"] {
            let p = ordner.join(format!("{}.{}", stamm, endung));
            if p.exists() {
                return Some(json!({ "datei": p.to_string_lossy(), "art": endung }));
            }
        }
        None
    };
    if let Some(v) = im_cache() {
        return Ok(v);
    }
    // Dasselbe Bild nur einmal laden: wer es gleichzeitig will (Liste und
    // Detailseite), wartet auf den ersten Download und nimmt dann die Datei.
    static LADEN: OnceLock<Mutex<HashMap<String, Arc<Mutex<()>>>>> = OnceLock::new();
    let sperre = {
        let mut laufend = LADEN.get_or_init(|| Mutex::new(HashMap::new())).lock().unwrap_or_else(|e| e.into_inner());
        laufend.entry(url.to_string()).or_insert_with(|| Arc::new(Mutex::new(()))).clone()
    };
    let _wache = sperre.lock().unwrap_or_else(|e| e.into_inner());
    if let Some(v) = im_cache() {
        return Ok(v);
    }
    let (status, art, daten) = k.netz.holen_roh(url)?;
    if status != 200 || daten.is_empty() {
        return Err(format!("Bild nicht geladen (HTTP {}).", status));
    }
    let endung = match () {
        _ if daten.starts_with(b"\x89PNG") => "png",
        _ if daten.starts_with(&[0xff, 0xd8]) => "jpg",
        _ if daten.starts_with(b"GIF8") => "gif",
        _ if daten.len() > 12 && &daten[0..4] == b"RIFF" && &daten[8..12] == b"WEBP" => "webp",
        _ if art.contains("svg") => "svg",
        _ => "bild",
    };
    let p = ordner.join(format!("{}.{}", stamm, endung));
    k.ablage
        .schreiben_roh(&p, &daten)
        .map_err(|e| format!("Bild nicht gespeichert: {}", e))?;
    Ok(json!({ "datei": p.to_string_lossy(), "art": endung }))
}

fn zahl(v: &Value, k: &str) -> Option<i64> {
    match v.get(k) {
        Some(Value::Number(n)) => n.as_i64().or_else(|| n.as_f64().map(|f| f as i64)),
        Some(Value::String(t)) => t.trim().parse().ok(),
        _ => None,
    }
}

fn intervall(v: &Value) -> &'static str {
    match s(v, "intervall").to_ascii_uppercase().as_str() {
        "DAY" | "TAG" => "DAY",
        "MONTH" | "MONAT" => "MONTH",
        "YEAR" | "JAHR" => "YEAR",
        _ => "WEEK",
    }
}

fn kodiert(t: &str) -> String {
    url::form_urlencoded::byte_serialize(t.as_bytes()).collect()
}

/// Der Rumpf fuer POST v1/user/sync mit den Profildaten. Die App schickt
/// immer alle sechs Felder; was der Aufrufer nicht angibt, kommt aus dem
/// aktuellen Profil.
fn profil_rumpf(werte: &Value, alt: &Value, email: &str) -> Value {
    let nimm = |neu: &str, alt_k: &str| -> Value {
        match werte.get(neu) {
            Some(v) if !v.is_null() => v.clone(),
            _ => alt.get(alt_k).cloned().unwrap_or(Value::Null),
        }
    };
    let mut m = Map::new();
    let mail = match alt.get("email").and_then(Value::as_str) {
        Some(e) if !e.is_empty() => e.to_string(),
        _ => email.to_string(),
    };
    m.insert("email".into(), Value::String(mail));
    m.insert("username".into(), nimm("benutzername", "username"));
    let geschlecht = nimm("geschlecht", "gender");
    if !geschlecht.is_null() {
        m.insert("gender".into(), Value::String(geschlecht.as_str().unwrap_or("").to_lowercase()));
    }
    let jahr = nimm("geburtsjahr", "yearOfBirth");
    if let Some(j) = jahr.as_i64().or_else(|| jahr.as_str().and_then(|t| t.parse().ok())) {
        m.insert("yearOfBirth".into(), json!(j));
    }
    let bezirk = nimm("bezirk", "territory");
    let bezirk = match &bezirk {
        Value::Number(n) => Value::String(n.to_string()),
        andere => andere.clone(),
    };
    m.insert("territory".into(), bezirk);
    m.insert(
        "newsletter".into(),
        Value::Bool(nimm("newsletter", "newsletter").as_bool().unwrap_or(false)),
    );
    Value::Object(m)
}

pub fn bearbeiten(k: &Kontext, befehl: &str, werte: &Value) -> Result<Value, String> {
    if crate::attrappe::aktiv() {
        if let Some(a) = crate::attrappe::antwort(befehl, werte) {
            return a.map(|mut v| {
                html_ergaenzen(&mut v);
                v
            });
        }
    }
    match befehl {
        "status" => {
            let a = k.angemeldet();
            Ok(json!({
                "angemeldet": a.is_some(),
                "email": a.as_ref().map(|a| a.email.clone()).unwrap_or_default(),
                "heute": zeit::heute(),
            }))
        }

        "anmelden" => {
            let email = s(werte, "email").trim().to_string();
            let passwort = s(werte, "passwort");
            if email.is_empty() || passwort.is_empty() {
                return Err("Bitte E-Mail und Passwort eingeben.".into());
            }
            let a = firebase::anmelden(&k.netz, &email, passwort)?;
            k.setzen(Some(a.clone()));
            protokoll(&format!("api: angemeldet als {}", a.email));
            nach_anmeldung(k, &a)
        }

        "registrieren" => {
            let email = s(werte, "email").trim().to_string();
            let passwort = s(werte, "passwort");
            if s(werte, "benutzername").trim().is_empty() || s(werte, "bezirk").is_empty() {
                return Err("Bitte Benutzernamen und Bezirk angeben.".into());
            }
            let a = firebase::registrieren(&k.netz, &email, passwort)?;
            k.setzen(Some(a.clone()));
            let rumpf = profil_rumpf(werte, &Value::Null, &a.email);
            let nutzer = k.backend("POST", "v1/user/sync", Some(&rumpf))?;
            // Bestaetigungsmail; scheitert sie, ist das Konto trotzdem da.
            if let Err(e) = k.backend("POST", "v1/user/verify-email", None) {
                protokoll(&format!("api: verify-email: {}", e));
            }
            Ok(json!({ "angemeldet": true, "email": a.email, "nutzer": nutzer }))
        }

        "profil_anlegen" | "profil_speichern" => {
            let a = k.angemeldet().ok_or(format!("{} Bitte zuerst anmelden.", ABGEMELDET))?;
            let alt = if befehl == "profil_speichern" {
                k.backend("GET", "v1/user", None)?
            } else {
                Value::Null
            };
            let rumpf = profil_rumpf(werte, &alt, &a.email);
            if s(&rumpf, "username").trim().is_empty() {
                return Err("Bitte einen Benutzernamen angeben.".into());
            }
            k.backend("POST", "v1/user/sync", Some(&rumpf))
        }

        "abmelden" => {
            k.setzen(None);
            Ok(json!({ "angemeldet": false }))
        }

        "passwort_vergessen" => {
            let email = s(werte, "email").trim().to_string();
            if email.is_empty() {
                return Err("Bitte die E-Mail-Adresse eingeben.".into());
            }
            k.backend_offen("POST", "v1/user/reset-password", &json!({ "email": email }))?;
            Ok(json!({ "gesendet": true }))
        }

        "bestaetigung_senden" => {
            k.backend("POST", "v1/user/verify-email", None)?;
            Ok(json!({ "gesendet": true }))
        }

        "nutzer" => k.backend("GET", "v1/user", None),

        "tagesziel" => {
            let ziel = zahl(werte, "ziel").ok_or("Kein Tagesziel angegeben.")?;
            if !(100..=100000).contains(&ziel) {
                return Err("Das Tagesziel muss zwischen 100 und 100 000 Schritten liegen.".into());
            }
            k.backend("POST", "v1/user/sync", Some(&json!({ "dailyTarget": ziel })))
        }

        "gesundheit" => {
            let bis = match s(werte, "bis") {
                "" => zeit::heute(),
                b => b.to_string(),
            };
            let von = match s(werte, "von") {
                "" => zeit::datum_plus(&bis, -6).unwrap_or_else(|| bis.clone()),
                v => v.to_string(),
            };
            let gruppe = match s(werte, "gruppierung").to_ascii_uppercase().as_str() {
                "WEEK" | "WOCHE" => "WEEK",
                "MONTH" | "MONAT" => "MONTH",
                "YEAR" | "JAHR" => "YEAR",
                _ => "DAY",
            };
            k.backend(
                "GET",
                &format!("v1/user/health?from={}&until={}&grouping={}", kodiert(&von), kodiert(&bis), gruppe),
                None,
            )
        }

        "rang" => k.backend(
            "GET",
            &format!("v1/user/rank?interval={}&withTerritory=true&withGlobal=true", intervall(werte)),
            None,
        ),

        "bestenliste" => {
            let limit = zahl(werte, "limit").unwrap_or(30).clamp(1, 100);
            let offset = zahl(werte, "offset").unwrap_or(0).max(0);
            let mut pfad = format!("v1/rank?interval={}&limit={}&offset={}", intervall(werte), limit, offset);
            let bezirk = match werte.get("bezirk") {
                Some(Value::String(b)) => b.clone(),
                Some(Value::Number(n)) => n.to_string(),
                _ => String::new(),
            };
            if !bezirk.is_empty() {
                pfad.push_str(&format!("&territory={}", kodiert(&bezirk)));
            }
            k.backend("GET", &pfad, None)
        }

        // Was die Webseite ankuendigt und noch nicht in der App steht.
        // Bewusst getrennt von "challenges": das hier ist gelesene
        // Webseite, keine Schnittstelle -- und wirft nie einen Fehler,
        // sonst blockiert ein Umbau der Seite die ganze Liste.
        "ankuendigungen" => {
            let gutscheine = k.backend("GET", "v1/voucher", None)
                .unwrap_or_else(|_| json!([]));
            Ok(crate::ankuendigung::ankuendigungen(&k.netz, &gutscheine))
        }

        "challenges" => {
            let mut v = k.backend("GET", "v1/challenge", None)?;
            html_ergaenzen(&mut v);
            Ok(v)
        }

        "challenge" => {
            let id = zahl(werte, "id").ok_or("Keine Challenge angegeben.")?;
            let mut v = k.backend("GET", &format!("v1/challenge/{}", id), None)?;
            html_ergaenzen(&mut v);
            Ok(v)
        }

        "teilnehmen" => {
            let id = zahl(werte, "id").ok_or("Keine Challenge angegeben.")?;
            let ja = werte.get("ja").and_then(Value::as_bool).unwrap_or(true);
            k.backend("PUT", &format!("v1/challenge/{}/participate", id), Some(&json!({ "participate": ja })))?;
            Ok(json!({ "teilgenommen": ja }))
        }

        "gutscheine" | "eingeloest" => {
            let pfad = if befehl == "gutscheine" { "v1/voucher" } else { "v1/voucher/redeemed" };
            let mut v = k.backend("GET", pfad, None)?;
            html_ergaenzen(&mut v);
            Ok(v)
        }

        "gutschein" => {
            let id = zahl(werte, "id").ok_or("Kein Gutschein angegeben.")?;
            let mut v = k.backend("GET", &format!("v1/voucher/{}", id), None)?;
            html_ergaenzen(&mut v);
            Ok(v)
        }

        "einloesen" => {
            let id = zahl(werte, "id").ok_or("Kein Gutschein angegeben.")?;
            // Wie die App: genau eines der vier Felder (CODE, EMAIL,
            // PICKUPSTATION, ADDRESS), die anderen fehlen im Rumpf.
            let mut m = Map::new();
            let code = s(werte, "code").trim();
            let email = s(werte, "email").trim();
            if !code.is_empty() {
                m.insert("code".into(), Value::String(code.to_string()));
            } else if !email.is_empty() {
                m.insert("email".into(), Value::String(email.to_string()));
            } else if let Some(st) = zahl(werte, "pickupStationId") {
                m.insert("pickupStationId".into(), json!(st));
            } else if let Some(Value::Object(adr)) = werte.get("address") {
                let mut a = adr.clone();
                if let Some(plz) = a.get("postalCode").cloned() {
                    let p = match plz {
                        Value::String(t) => t.trim().parse::<i64>().ok(),
                        Value::Number(n) => n.as_i64(),
                        _ => None,
                    };
                    match p {
                        Some(p) => {
                            a.insert("postalCode".into(), json!(p));
                        }
                        None => return Err("Die Postleitzahl muss eine Zahl sein.".into()),
                    }
                }
                m.insert("address".into(), Value::Object(a));
            }
            let mut v = k.backend("POST", &format!("v1/voucher/{}/redeem", id), Some(&Value::Object(m)))?;
            html_ergaenzen(&mut v);
            Ok(v)
        }

        "rueckblick" => {
            let jahr = zahl(werte, "jahr").unwrap_or_else(|| zeit::heute()[0..4].parse().unwrap_or(2026));
            k.backend("GET", &format!("v1/user/review?year={}", jahr), None)
        }

        "feedback" => {
            let sterne = zahl(werte, "sterne").unwrap_or(5).clamp(1, 5);
            k.backend("POST", "v1/feedback", Some(&json!({ "stars": sterne, "note": s(werte, "text") })))?;
            Ok(json!({ "gesendet": true }))
        }

        "bild" => bild(k, s(werte, "url")),

        "einstellungen" => Ok(einstellungen::laden(&k.ablage)),
        "einstellungen_setzen" => einstellungen::setzen(&k.ablage, werte),

        "lokal" => Ok(schritte::lokal(k)),
        "synchronisieren" => schritte::synchronisieren(k, werte, false),

        anders => Err(format!("Unbekannter Befehl: {}", anders)),
    }
}

/// Nach der Firebase-Anmeldung: gibt es ein Profil bei Wien zu Fuss? Wer
/// sich nur ueber Firebase angemeldet, das Profil aber nie angelegt hat,
/// bekommt "profilFehlt" und die Oberflaeche fragt nach Name und Bezirk.
fn nach_anmeldung(k: &Kontext, a: &Anmeldung) -> Result<Value, String> {
    match k.backend("GET", "v1/user", None) {
        Ok(nutzer) => {
            let fehlt = nutzer.is_null() || s(&nutzer, "username").is_empty();
            Ok(json!({ "angemeldet": true, "email": a.email, "nutzer": nutzer, "profilFehlt": fehlt }))
        }
        Err(e) if e.starts_with("Nicht gefunden") => {
            Ok(json!({ "angemeldet": true, "email": a.email, "nutzer": null, "profilFehlt": true }))
        }
        Err(e) => Ok(json!({ "angemeldet": true, "email": a.email, "nutzer": null, "fehler": e })),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn markdown_wird_html() {
        let h = markdown("**Gratis** Eintritt\n\n* eins\n* zwei\n\n![x](https://a/b.png)");
        assert!(h.contains("<strong>Gratis</strong>"));
        assert!(h.contains("<li>eins</li>"));
        assert!(h.contains("<a href=\"https://a/b.png\">[Bild]"));
        assert!(!h.contains("<img"));
    }

    #[test]
    fn html_neben_beschreibung() {
        let mut v = json!([{ "id": 1, "description": "*a*", "redeemedVoucher": { "redeemText": "b" } }]);
        html_ergaenzen(&mut v);
        assert_eq!(v[0]["descriptionHtml"], "<p><em>a</em></p>");
        assert_eq!(v[0]["redeemedVoucher"]["redeemTextHtml"], "<p>b</p>");
    }

    #[test]
    fn profil_nimmt_altes() {
        let alt = json!({ "email": "a@b.at", "username": "Ana", "gender": "female", "yearOfBirth": 1990, "territory": "1070", "newsletter": true });
        let r = profil_rumpf(&json!({ "bezirk": 1150 }), &alt, "x@y.at");
        assert_eq!(r["email"], "a@b.at");
        assert_eq!(r["username"], "Ana");
        assert_eq!(r["territory"], "1150");
        assert_eq!(r["yearOfBirth"], 1990);
        assert_eq!(r["newsletter"], true);
    }

    #[test]
    fn gutscheinfehler() {
        assert_eq!(backend_fehler(400, "{\"statusCode\":400,\"errorCode\":10303,\"message\":\"x\"}"), "Eingegebener Pin ist ungültig!");
        assert_eq!(backend_fehler(409, "{\"error\":\"VOUCHER_ALREADY_REDEEMED\"}"), "Dieser Gutschein wurde bereits eingelöst!");
        assert!(backend_fehler(400, "{\"errorCode\":10001}").starts_with("Fehler vom Server"));
    }

    #[test]
    fn fehlertexte() {
        assert!(backend_fehler(401, "").starts_with(ABGEMELDET));
        assert_eq!(backend_fehler(404, "{\"message\":\"User not found\"}"), "Nicht gefunden. (User not found)");
        assert!(backend_fehler(500, "<html>").starts_with("Der Server"));
    }
}
