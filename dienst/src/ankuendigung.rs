//! Angekuendigte Aktionen von der Webseite der Mobilitaetsagentur.
//!
//! Warum das ueberhaupt noetig ist: der Dienst listet unter `v1/challenge`
//! nur, was **laeuft**. Eine Challenge, die erst morgen beginnt, steht dort
//! nicht -- am 09.10.2026 nachgemessen: alle drei Faecher leer, waehrend die
//! Webseite "12 Stunden LiDo" fuer den 10.10. ankuendigte. Wer nichts
//! verpassen will, muss also die Ankuendigung lesen.
//!
//! Wie hier geschnitten wird -- und warum es nicht wieder Raterei ist:
//!
//! * Die Seite traegt die Angebote als "flip-card"-Kacheln. Davor stehen
//!   allgemeine Erklaerkacheln, danach die FAQs. Genommen wird **nur der
//!   Abschnitt zwischen den Ueberschriften "Aktuelle Gutscheine &
//!   Challenges" und "FAQs"** -- damit fallen die Erklaerkacheln weg, ohne
//!   dass eine Liste bekannter Titel gepflegt werden muss.
//! * Abgezogen wird, was die App ohnehin schon als Gutschein zeigt. Der
//!   Vergleich laeuft ueber den **Beschreibungstext**, nicht den Titel: die
//!   Kachel heisst nach dem Partner ("GOTA Coffee Experts"), der Gutschein
//!   nach dem Angebot ("20% Rabatt auf Kaffeebohnen") -- der Fliesstext ist
//!   aber derselbe.
//!
//! Uebrig bleibt, was angekuendigt und noch nicht in der App ist. Das ist
//! eine Lesehilfe, keine Schnittstelle: scheitert das Holen oder aendert
//! die Seite ihren Aufbau, liefert die Funktion eine leere Liste und die
//! App zeigt den Abschnitt einfach nicht.
use serde_json::{json, Value};

const SEITE: &str = "https://mobilitaetsagentur.at/zu-fuss-gehen/wien-zu-fuss-app";

/// Sichtbarer Text ohne Markup, Mehrfachleerzeichen zusammengezogen.
fn entmarkten(roh: &str) -> String {
    let mut aus = String::with_capacity(roh.len());
    let mut im_tag = false;
    for z in roh.chars() {
        match z {
            '<' => im_tag = true,
            '>' => im_tag = false,
            _ if !im_tag => aus.push(z),
            _ => {}
        }
    }
    let aus = aus
        .replace("&amp;", "&").replace("&quot;", "\"").replace("&#039;", "'")
        .replace("&nbsp;", " ").replace("&bdquo;", "\u{201e}").replace("&ldquo;", "\u{201c}")
        .replace("&rsquo;", "\u{2019}").replace("&ndash;", "\u{2013}").replace("&lt;", "<")
        .replace("&gt;", ">");
    aus.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Die ersten `n` Woerter -- als Fingerabdruck, um eine Kachel einem
/// Gutschein zuzuordnen, ohne an Zeichensetzung zu scheitern.
fn anfang(text: &str, n: usize) -> String {
    text.split_whitespace()
        .take(n)
        .map(|w| w.chars().filter(|z| z.is_alphanumeric()).collect::<String>().to_lowercase())
        .filter(|w| !w.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}

/// Die Kacheln des Angebotsabschnitts, als (Titel, Text).
///
/// Am Markup entlang statt mit einem groben Schnitt: der Titel steht in
/// `<h3 class="flip-card-title">`, der Text im eigenen Kasten
/// `flip-card-back-content` darunter. Ein Schnitt auf "flip-card-back"
/// allein trifft auch "flip-card-back-header" und zieht dann
/// Attributreste in den Text -- genau das ist beim ersten Versuch
/// passiert.
fn kacheln(html: &str) -> Vec<(String, String)> {
    let von = match html.find("Aktuelle Gutscheine") {
        Some(i) => i,
        None => return Vec::new(),
    };
    let bis = html[von..].find(">FAQs<").map(|i| von + i).unwrap_or(html.len());
    let abschnitt = &html[von..bis];

    let mut aus = Vec::new();
    let mut rest = abschnitt;
    while let Some(i) = rest.find("flip-card-title") {
        let nach_titel = &rest[i..];
        let titel = match (nach_titel.find('>'), nach_titel.find("</")) {
            (Some(a), Some(b)) if b > a => entmarkten(&nach_titel[a + 1..b]),
            _ => String::new(),
        };
        // Der Text folgt im naechsten back-content-Kasten; bis zum
        // naechsten Titel, damit eine Kachel nicht in die naechste laeuft.
        let grenze = nach_titel[1..]
            .find("flip-card-title")
            .map(|k| k + 1)
            .unwrap_or(nach_titel.len());
        let text = match nach_titel[..grenze].find("flip-card-back-content") {
            // Hinter die spitze Klammer des Kastens springen, sonst steht
            // der Rest des Attributs im Text -- und verdirbt den
            // Fingerabdruck, mit dem bekannte Gutscheine abgezogen werden.
            Some(k) => match nach_titel[k..grenze].find('>') {
                Some(o) => entmarkten(&nach_titel[k + o + 1..grenze]),
                None => String::new(),
            },
            None => String::new(),
        };
        if !titel.is_empty() && !text.is_empty() {
            aus.push((titel, text));
        }
        rest = &nach_titel[grenze..];
    }
    aus
}

/// Angekuendigtes, das nicht schon als Gutschein in der App steht.
pub fn ankuendigungen(netz: &crate::netz::Netz, gutscheine: &Value) -> Value {
    let html = match netz.holen_roh(SEITE) {
        Ok((200, _, rumpf)) => String::from_utf8_lossy(&rumpf).into_owned(),
        _ => return json!([]),      // Lesehilfe: stumm nichts, nie ein Fehler
    };

    // Fingerabdruecke dessen, was die App schon zeigt.
    let mut bekannt: Vec<String> = Vec::new();
    if let Some(liste) = gutscheine.as_array() {
        for g in liste {
            for feld in ["description", "name", "title"] {
                if let Some(t) = g.get(feld).and_then(Value::as_str) {
                    let f = anfang(&entmarkten(t), 8);
                    if !f.is_empty() {
                        bekannt.push(f);
                    }
                }
            }
        }
    }

    let mut aus = Vec::new();
    for (titel, text) in kacheln(&html) {
        let f = anfang(&text, 8);
        if bekannt.iter().any(|b| *b == f) {
            continue;                 // steht schon als Gutschein in der App
        }
        aus.push(json!({ "titel": titel, "text": text, "quelle": SEITE }));
    }
    json!(aus)
}
