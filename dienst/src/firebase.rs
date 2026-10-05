//! Anmeldung ueber die REST-Schnittstelle von Firebase Authentication.
//!
//! Die Android-App meldet sich mit dem Firebase-SDK an und schickt das
//! ID-Token als `Authorization: Bearer` ans Backend. Dasselbe Token gibt es
//! ueber identitytoolkit.googleapis.com: der API-Schluessel der App ist nicht
//! auf Android beschraenkt, reCAPTCHA ist fuer E-Mail/Passwort nicht
//! erzwungen (siehe api.md).
//!
//! Gespeichert wird nur das Erneuerungs-Token (und das gerade gueltige
//! ID-Token), nie das Kennwort -- in ~/.config/wienzufuss/anmeldung.json mit
//! Modus 0600.

use crate::ablage::Ablage;
use crate::netz::{Netz, Rumpf};
use crate::zeit;
use serde_json::{json, Value};

/// Der Web-API-Schluessel aus der APK (Ressource google_api_key).
pub const SCHLUESSEL: &str = "AIzaSyDvYwJ8djFcaiKSgpyICAOXRdBE8tU8lsI";
const IDENTITAET: &str = "https://identitytoolkit.googleapis.com/v1/accounts:";
const TOKEN: &str = "https://securetoken.googleapis.com/v1/token";

#[derive(Clone, Debug)]
pub struct Anmeldung {
    pub email: String,
    pub uid: String,
    pub refresh: String,
    pub id_token: String,
    /// Ablauf des ID-Tokens, Unix-Sekunden.
    pub ablauf: i64,
}

/// Warum eine Erneuerung scheiterte: das Konto ist weg (neu anmelden) oder
/// nur das Netz (spaeter wieder versuchen, Anmeldung behalten).
pub enum Fehler {
    Abgemeldet(String),
    Sonst(String),
}

impl Anmeldung {
    pub fn laden(ablage: &Ablage) -> Option<Anmeldung> {
        let v = ablage.lesen(&ablage.anmeldung())?;
        let refresh = v.get("refreshToken")?.as_str()?.to_string();
        if refresh.is_empty() {
            return None;
        }
        Some(Anmeldung {
            email: v.get("email").and_then(Value::as_str).unwrap_or("").to_string(),
            uid: v.get("uid").and_then(Value::as_str).unwrap_or("").to_string(),
            refresh,
            id_token: v.get("idToken").and_then(Value::as_str).unwrap_or("").to_string(),
            ablauf: v.get("ablauf").and_then(Value::as_i64).unwrap_or(0),
        })
    }

    pub fn sichern(&self, ablage: &Ablage) {
        let v = json!({
            "email": self.email,
            "uid": self.uid,
            "refreshToken": self.refresh,
            "idToken": self.id_token,
            "ablauf": self.ablauf,
        });
        if let Err(e) = ablage.schreiben_geheim(&ablage.anmeldung(), &v) {
            crate::protokoll(&format!("firebase: Anmeldung nicht gespeichert: {}", e));
        }
    }

    /// Noch mindestens zwei Minuten gueltig?
    pub fn gueltig(&self) -> bool {
        !self.id_token.is_empty() && zeit::jetzt_utc() + 120 < self.ablauf
    }
}

fn sekunden(v: Option<&Value>) -> i64 {
    match v {
        Some(Value::String(s)) => s.parse().unwrap_or(3600),
        Some(Value::Number(n)) => n.as_i64().unwrap_or(3600),
        _ => 3600,
    }
}

/// Firebase-Fehlercode aus `{"error":{"message":"CODE : Text"}}`.
fn code(v: &Value) -> String {
    let m = v
        .pointer("/error/message")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    m.split(" : ").next().unwrap_or("").trim().to_string()
}

fn fehlertext(code: &str, status: u16) -> String {
    match code {
        "INVALID_LOGIN_CREDENTIALS" | "INVALID_PASSWORD" | "EMAIL_NOT_FOUND" => {
            "E-Mail oder Passwort stimmt nicht.".into()
        }
        "USER_DISABLED" => "Dieses Konto ist gesperrt.".into(),
        "TOO_MANY_ATTEMPTS_TRY_LATER" => "Zu viele Versuche – bitte später noch einmal.".into(),
        "EMAIL_EXISTS" => "Für diese E-Mail-Adresse gibt es schon ein Konto.".into(),
        "WEAK_PASSWORD" => "Das Passwort ist zu schwach (mindestens 6 Zeichen).".into(),
        "INVALID_EMAIL" => "Die E-Mail-Adresse ist ungültig.".into(),
        "MISSING_PASSWORD" => "Bitte ein Passwort eingeben.".into(),
        "OPERATION_NOT_ALLOWED" | "PASSWORD_LOGIN_DISABLED" => {
            "Die Anmeldung mit E-Mail und Passwort ist nicht freigeschaltet.".into()
        }
        "" => format!("Anmeldung fehlgeschlagen (HTTP {}).", status),
        c => format!("Anmeldung fehlgeschlagen ({}).", c),
    }
}

fn konto(netz: &Netz, art: &str, email: &str, passwort: &str) -> Result<Anmeldung, String> {
    let url = format!("{}{}?key={}", IDENTITAET, art, SCHLUESSEL);
    let rumpf = json!({ "email": email, "password": passwort, "returnSecureToken": true });
    let a = netz.senden("POST", &url, None, Rumpf::Json(&rumpf), true)?;
    let v = a.json().unwrap_or(Value::Null);
    if a.status != 200 {
        return Err(fehlertext(&code(&v), a.status));
    }
    let id_token = v.get("idToken").and_then(Value::as_str).unwrap_or("").to_string();
    let refresh = v.get("refreshToken").and_then(Value::as_str).unwrap_or("").to_string();
    if id_token.is_empty() || refresh.is_empty() {
        return Err("Anmeldung fehlgeschlagen: Firebase lieferte kein Token.".into());
    }
    Ok(Anmeldung {
        email: v.get("email").and_then(Value::as_str).unwrap_or(email).to_string(),
        uid: v.get("localId").and_then(Value::as_str).unwrap_or("").to_string(),
        refresh,
        id_token,
        ablauf: zeit::jetzt_utc() + sekunden(v.get("expiresIn")),
    })
}

pub fn anmelden(netz: &Netz, email: &str, passwort: &str) -> Result<Anmeldung, String> {
    konto(netz, "signInWithPassword", email, passwort)
}

pub fn registrieren(netz: &Netz, email: &str, passwort: &str) -> Result<Anmeldung, String> {
    konto(netz, "signUp", email, passwort)
}

pub fn erneuern(netz: &Netz, alt: &Anmeldung) -> Result<Anmeldung, Fehler> {
    let url = format!("{}?key={}", TOKEN, SCHLUESSEL);
    let form: String = url::form_urlencoded::Serializer::new(String::new())
        .append_pair("grant_type", "refresh_token")
        .append_pair("refresh_token", &alt.refresh)
        .finish();
    let a = netz
        .senden("POST", &url, None, Rumpf::Form(form), true)
        .map_err(Fehler::Sonst)?;
    let v = a.json().unwrap_or(Value::Null);
    if a.status != 200 {
        let c = code(&v);
        return match c.as_str() {
            "TOKEN_EXPIRED" | "USER_NOT_FOUND" | "USER_DISABLED" | "INVALID_REFRESH_TOKEN"
            | "INVALID_GRANT_TYPE" | "MISSING_REFRESH_TOKEN" => {
                Err(Fehler::Abgemeldet(format!("Die Anmeldung ist abgelaufen ({}).", c)))
            }
            _ => Err(Fehler::Sonst(fehlertext(&c, a.status))),
        };
    }
    let id_token = v.get("id_token").and_then(Value::as_str).unwrap_or("").to_string();
    if id_token.is_empty() {
        return Err(Fehler::Sonst("Token-Erneuerung lieferte kein Token.".into()));
    }
    Ok(Anmeldung {
        email: alt.email.clone(),
        uid: v.get("user_id").and_then(Value::as_str).unwrap_or(&alt.uid).to_string(),
        refresh: v
            .get("refresh_token")
            .and_then(Value::as_str)
            .unwrap_or(&alt.refresh)
            .to_string(),
        id_token,
        ablauf: zeit::jetzt_utc() + sekunden(v.get("expires_in")),
    })
}
