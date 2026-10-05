//! Die Einstellungen in ~/.config/wienzufuss/einstellungen.json.
//!
//! Drei Leser: die Oberflaeche (ueber diesen Dienst), der Dienst selbst
//! (Schrittlaenge, ob hochgeladen werden darf) und der Schrittdienst (ob und
//! wie gezaehlt wird). Geschrieben wird nur hier, zusammengefuehrt mit dem,
//! was schon in der Datei steht -- unbekannte Schluessel bleiben erhalten.

use crate::ablage::Ablage;
use serde_json::{json, Map, Value};

pub fn vorgaben() -> Value {
    json!({
        // Meter je Schritt; daraus wird die Strecke fuer den Upload.
        "schrittlaenge": 0.7,
        // Zaehlt der Schrittdienst ueberhaupt?
        "zaehlen": true,
        // Sailfish: Beschleunigungssensor, wenn kein Hardware-Schrittzaehler
        // da ist. Kostet Akku, deshalb erst auf Wunsch. (Am N9 gibt es nur
        // diesen Weg, dort zaehlt der Dienst immer so.)
        "beschleunigung": false,
        // 1 (unempfindlich) .. 5 (empfindlich)
        "empfindlichkeit": 3,
        // Schritte an Wien zu Fuss uebertragen. Aus, bis der Nutzer es
        // einschaltet.
        "hochladen": false
    })
}

pub fn laden(ablage: &Ablage) -> Value {
    let mut v = vorgaben();
    if let Some(Value::Object(datei)) = ablage.lesen(&ablage.einstellungen()) {
        if let Value::Object(ziel) = &mut v {
            for (k, w) in datei {
                ziel.insert(k, w);
            }
        }
    }
    v
}

pub fn setzen(ablage: &Ablage, neu: &Value) -> Result<Value, String> {
    let mut alt: Map<String, Value> = match ablage.lesen(&ablage.einstellungen()) {
        Some(Value::Object(m)) => m,
        _ => Map::new(),
    };
    if let Value::Object(m) = neu {
        for (k, w) in m {
            alt.insert(k.clone(), w.clone());
        }
    }
    ablage
        .schreiben(&ablage.einstellungen(), &Value::Object(alt))
        .map_err(|e| format!("Einstellungen nicht gespeichert: {}", e))?;
    Ok(laden(ablage))
}

pub fn schrittlaenge(e: &Value) -> f64 {
    let l = e.get("schrittlaenge").and_then(Value::as_f64).unwrap_or(0.7);
    if (0.3..=1.5).contains(&l) {
        l
    } else {
        0.7
    }
}
