//! Beispielantworten fuer den Probelauf der Oberflaeche ohne Konto.
//!
//!   WZF_ATTRAPPE=1 wzf-dienst
//!
//! Dann geht keine Anfrage an Firebase oder das Backend; die Befehle, die
//! sonst den Server fragen, antworten mit festen Daten in der Form der
//! Modellklassen aus der APK (siehe api.md). Nur fuer tools/probe.sh und
//! die Bildschirmfotos -- im Paket ist die Variable nie gesetzt.

use crate::zeit;
use serde_json::{json, Value};

pub fn aktiv() -> bool {
    std::env::var_os("WZF_ATTRAPPE").is_some()
}

fn nutzer() -> Value {
    json!({
        "_id": "probe", "username": "Gehsteigfan", "email": "probe@example.org",
        "gender": "female", "yearOfBirth": 1987, "territory": "1070", "newsletter": false,
        "dailyTarget": 8000, "steps": 1234567, "distance": 864197.0, "points": 4180,
        "signInProvider": "password",
        "latestHealth": { "_id": "h", "from": zeit::heute(), "until": zeit::heute(), "steps": 5120, "distance": 3584.0 }
    })
}

fn challenge(id: i64, titel: &str, dabei: bool) -> Value {
    json!({
        "id": id, "title": titel,
        "description": "Gemeinsam **eine Million Schritte** im Oktober – für mehr Platz zum Gehen.\n\nMehr auf [wienzufuss.at](https://www.wienzufuss.at).",
        "imageUrl": "", "from": "2026-10-01", "to": "2026-10-31",
        "stepGoal": 1000000, "totalSteps": 612345, "hasJoined": dabei, "challengeIsLocked": false,
        "userRank": if dabei { json!({ "_id": "u", "username": "Gehsteigfan", "steps": 41230, "position": 17 }) } else { Value::Null },
        "ranking": [
            { "_id": "a", "username": "Donaukanalgeher", "steps": 98211, "position": 1 },
            { "_id": "b", "username": "Margaretner", "steps": 87120, "position": 2 },
            { "_id": "c", "username": "Stiegenläuferin", "steps": 80544, "position": 3 }
        ]
    })
}

fn gutschein(id: i64, titel: &str, art: &str, schritte: i64) -> Value {
    json!({
        "id": id, "name": "Partnerbetrieb", "title": titel, "type": art,
        "description": "Einzulösen bis Ende des Jahres. *Pro Person ein Gutschein.*",
        "requiredSteps": schritte, "contingent": 200, "redeemed": 57, "hasCodes": false,
        "listImageUrl": "", "headerImageUrl": "",
        "published": { "from": "2026-09-01", "until": "2026-12-31" },
        "eventPickupRestriction": if art == "event" { json!("post") } else { Value::Null },
        "pickupStations": [
            { "id": 3, "name": "Mobilitätsagentur", "address": { "street": "Große Sperlgasse 4", "zip": "1020", "city": "Wien" } }
        ]
    })
}

pub fn antwort(befehl: &str, werte: &Value) -> Option<Result<Value, String>> {
    let v = match befehl {
        "status" => json!({ "angemeldet": true, "email": "probe@example.org", "heute": zeit::heute() }),
        "anmelden" => json!({ "angemeldet": true, "email": "probe@example.org", "nutzer": nutzer(), "profilFehlt": false }),
        "nutzer" | "tagesziel" | "profil_speichern" | "profil_anlegen" => nutzer(),
        "rang" => json!({
            "steps": 48210, "distance": 33747.0,
            "global": { "rank": 1532, "stepsToLead": 61022, "distanceToLead": 42715.0 },
            "territory": { "rank": 41, "stepsToLead": 30120, "distanceToLead": 21084.0 }
        }),
        "bestenliste" => {
            let ab = werte.get("offset").and_then(Value::as_i64).unwrap_or(0);
            let liste: Vec<Value> = (0..30)
                .map(|i| {
                    let p = ab + i + 1;
                    json!({ "_id": format!("n{}", p), "username": if p == 7 { "Gehsteigfan".to_string() } else { format!("Geher{}", p) },
                            "steps": 120000 - p * 1371, "distance": (120000 - p * 1371) as f64 * 0.7, "position": p })
                })
                .collect();
            json!({ "interval": "WEEK", "limit": 30, "offset": ab, "total": 95, "list": liste })
        }
        "challenges" => json!({
            "joined": [challenge(1, "Oktober-Million", true)],
            "available": [challenge(2, "Grätzlrunde Neubau", false)],
            "closed": [challenge(3, "Sommer am Donaukanal", false)]
        }),
        "challenge" => {
            let id = werte.get("id").and_then(Value::as_i64).unwrap_or(1);
            challenge(id, "Oktober-Million", id == 1)
        }
        "teilnehmen" => json!({ "teilgenommen": werte.get("ja").and_then(Value::as_bool).unwrap_or(true) }),
        "gutscheine" => json!([
            gutschein(11, "Melange im Kaffeehaus", "gastronomy", 50000),
            gutschein(12, "Zwei Karten fürs Volkstheater", "event", 120000),
            gutschein(13, "Baum für den Augarten", "donation", 30000)
        ]),
        "eingeloest" => {
            let mut g = gutschein(10, "Eis am Schwedenplatz", "gastronomy", 40000);
            g["redeemedVoucher"] = json!({ "id": 99, "code": "WZF-4711", "redeemText": "Beim Bezahlen den Code zeigen.", "createdAt": "2026-08-14T15:02:11.000Z" });
            json!([g])
        }
        "gutschein" => {
            let id = werte.get("id").and_then(Value::as_i64).unwrap_or(11);
            match id {
                12 => gutschein(12, "Zwei Karten fürs Volkstheater", "event", 120000),
                13 => gutschein(13, "Baum für den Augarten", "donation", 30000),
                _ => gutschein(id, "Melange im Kaffeehaus", "gastronomy", 50000),
            }
        }
        "einloesen" => json!({ "id": 100, "code": "WZF-0815", "redeemText": "Viel Freude damit!", "createdAt": "2026-10-05T10:00:00.000Z" }),
        "rueckblick" => json!({
            "year": werte.get("jahr").cloned().unwrap_or(json!(2026)),
            "review": {
                "totalSteps": 2412000, "totalDistance": 1688400.0, "totalStepsForYear": 2412000,
                "totalDistanceForYear": 1688400.0, "dailyTarget": 8000, "dailyTargetReached": 187,
                "daysWithZeroSteps": 3, "numberOfChallenges": 4, "numberOfVouchers": 6,
                "mostSteps": { "date1": "2026-06-21", "steps1": 31244, "date2": "2026-05-09", "steps2": 28710, "date3": "2026-07-14", "steps3": 25002 },
                "leastSteps": { "date1": "2026-02-02", "steps1": 412, "date2": "2026-01-12", "steps2": 530, "date3": "2026-03-01", "steps3": 611 },
                "fromCityName": "Wien", "toCityName": "Barcelona",
                "nextGoalCityName": "Lissabon", "nextGoalCityDistance": 598000.0
            }
        }),
        "synchronisieren" => json!({ "gesendet": [{ "date": zeit::heute(), "steps": 5120, "distance": 3584.0 }], "abweichung": [], "unveraendert": 0 }),
        _ => return None,
    };
    Some(Ok(v))
}
