//! Datum in Wiener Ortszeit, ohne Zeitzonen-Bibliothek.
//!
//! Die App ist eine Wiener App, die Tage, nach denen Schritte gezaehlt
//! werden, sind Wiener Kalendertage. Gerechnet wird deshalb fest mit MEZ/MESZ
//! nach der EU-Regel (Sommerzeit vom letzten Sonntag im Maerz bis zum letzten
//! Sonntag im Oktober, Wechsel jeweils um 01:00 UTC) -- unabhaengig davon, ob
//! das statisch gegen musl gebundene Binary die Zeitzone des Geraets findet.

use std::time::{SystemTime, UNIX_EPOCH};

/// Tage seit 1970-01-01 (proleptisch gregorianisch).
pub fn tage(jahr: i32, monat: u32, tag: u32) -> i64 {
    let y = if monat <= 2 { jahr as i64 - 1 } else { jahr as i64 };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let m = monat as i64;
    let doy = (153 * (if m > 2 { m - 3 } else { m + 9 }) + 2) / 5 + tag as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146097 + doe - 719468
}

pub fn datum_aus_tagen(t: i64) -> (i32, u32, u32) {
    let z = t + 719468;
    let era = if z >= 0 { z } else { z - 146096 } / 146097;
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = (doy - (153 * mp + 2) / 5 + 1) as u32;
    let m = if mp < 10 { mp + 3 } else { mp - 9 } as u32;
    ((if m <= 2 { y + 1 } else { y }) as i32, m, d)
}

/// 0 = Montag ... 6 = Sonntag. Der 1.1.1970 war ein Donnerstag.
fn wochentag(t: i64) -> i64 {
    (t + 3).rem_euclid(7)
}

fn letzter_sonntag(jahr: i32, monat: u32) -> i64 {
    let ende = tage(jahr, monat, 31);
    ende - (wochentag(ende) + 1) % 7
}

pub fn jetzt_utc() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0)
}

/// Versatz Wien gegen UTC in Sekunden zum Zeitpunkt `utc` (Unix-Sekunden).
pub fn wien_versatz(utc: i64) -> i64 {
    let (jahr, _, _) = datum_aus_tagen(utc.div_euclid(86400));
    let beginn = letzter_sonntag(jahr, 3) * 86400 + 3600;
    let ende = letzter_sonntag(jahr, 10) * 86400 + 3600;
    if utc >= beginn && utc < ende {
        7200
    } else {
        3600
    }
}

pub fn datum_text(t: i64) -> String {
    let (j, m, d) = datum_aus_tagen(t);
    format!("{:04}-{:02}-{:02}", j, m, d)
}

/// Heutiges Datum in Wien, "JJJJ-MM-TT".
pub fn heute() -> String {
    let utc = jetzt_utc();
    datum_text((utc + wien_versatz(utc)).div_euclid(86400))
}

/// Ortszeit fuers Protokoll und fuer "zuletzt hochgeladen".
pub fn jetzt_text() -> String {
    let utc = jetzt_utc();
    let ort = utc + wien_versatz(utc);
    let sek = ort.rem_euclid(86400);
    format!("{} {:02}:{:02}:{:02}", datum_text(ort.div_euclid(86400)), sek / 3600, sek / 60 % 60, sek % 60)
}

/// "JJJJ-MM-TT" -> Tage seit 1970, nur wenn es ein gueltiges Datum ist.
pub fn datum_lesen(s: &str) -> Option<i64> {
    let s = s.trim();
    if s.len() < 10 {
        return None;
    }
    let b = s.as_bytes();
    if b[4] != b'-' || b[7] != b'-' {
        return None;
    }
    let jahr: i32 = s[0..4].parse().ok()?;
    let monat: u32 = s[5..7].parse().ok()?;
    let tag: u32 = s[8..10].parse().ok()?;
    if !(1..=12).contains(&monat) || !(1..=31).contains(&tag) {
        return None;
    }
    let t = tage(jahr, monat, tag);
    if datum_aus_tagen(t) != (jahr, monat, tag) {
        return None;
    }
    Some(t)
}

pub fn datum_plus(datum: &str, delta: i64) -> Option<String> {
    datum_lesen(datum).map(|t| datum_text(t + delta))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn kalender() {
        assert_eq!(tage(1970, 1, 1), 0);
        assert_eq!(datum_aus_tagen(tage(2026, 10, 5)), (2026, 10, 5));
        assert_eq!(datum_aus_tagen(tage(2024, 2, 29)), (2024, 2, 29));
        assert_eq!(datum_lesen("2025-02-29"), None);
        assert_eq!(datum_plus("2026-01-01", -1).as_deref(), Some("2025-12-31"));
        // 5.10.2026 ist ein Montag
        assert_eq!(wochentag(tage(2026, 10, 5)), 0);
    }

    #[test]
    fn sommerzeit() {
        // 2026: Beginn 29. Maerz, Ende 25. Oktober
        assert_eq!(datum_aus_tagen(letzter_sonntag(2026, 3)), (2026, 3, 29));
        assert_eq!(datum_aus_tagen(letzter_sonntag(2026, 10)), (2026, 10, 25));
        let vor = tage(2026, 3, 29) * 86400 + 3599;
        assert_eq!(wien_versatz(vor), 3600);
        assert_eq!(wien_versatz(vor + 1), 7200);
        let winter = tage(2026, 10, 25) * 86400 + 3600;
        assert_eq!(wien_versatz(winter - 1), 7200);
        assert_eq!(wien_versatz(winter), 3600);
    }
}
