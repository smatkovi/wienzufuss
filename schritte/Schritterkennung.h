#ifndef SCHRITTERKENNUNG_H
#define SCHRITTERKENNUNG_H

// Schritte aus dem Beschleunigungssensor, fuer Geraete ohne
// Hardware-Schrittzaehler (N9/N950 immer, Sailfish nur als Rueckfall).
//
// Das Verfahren folgt dem HTML5-Schrittzaehler von Sebastien Menigot
// (Firefox OS, GPLv3; dieselbe Grundlage steckt in "pedoMeter" fuer
// Sailfish): Betrag der Beschleunigung, geglaettet, eine gleitende
// Schwelle aus den letzten zwei Sekunden, ein Schritt je Durchgang von unten
// nach oben, wenn der Hub (Maximum - Minimum) gross genug ist. Neu
// geschrieben, mit drei Aenderungen:
//
//  * Die Schwelle ist der Mittelwert des Fensters, nicht die Mitte zwischen
//    Minimum und Maximum: ein einzelner Stoss beim Gehen hebt sonst die
//    Schwelle zwei Sekunden lang ueber die Schritte (im Test 8 % weniger,
//    so 1 %).
//  * Die Glaettung ist ein Tiefpass erster Ordnung mit fester Grenzfrequenz
//    statt Menigots Kalman-Filter, dessen Rauschannahme aus dem Fenster
//    abgeleitet wird -- die haengt dort von der Abtastrate ab, und das N9
//    liefert 20 Hz statt 60-100.
//  * Gezaehlt wird erst ab dem vierten gleichmaessigen Schritt; die ersten
//    drei werden dann nachgetragen. Ein Telefon, das in die Tasche gesteckt
//    oder auf den Tisch gelegt wird, zaehlt so keine Schritte.
//
// Reines C++98 ohne Qt: das N9 baut mit GCC 4.4 (MADDE), und der Test
// (schritte/test/) laeuft am Rechner.

#include <cmath>

class Schritterkennung
{
public:
    explicit Schritterkennung(int empfindlichkeit = 3)
    {
        setEmpfindlichkeit(empfindlichkeit);
        zuruecksetzen();
    }

    // 1 (unempfindlich) .. 5 (empfindlich): kleinster Hub in m/s^2, der
    // als Schritt gilt.
    void setEmpfindlichkeit(int e)
    {
        static const double hub[5] = { 3.0, 2.2, 1.6, 1.2, 0.8 };
        if (e < 1) e = 1;
        if (e > 5) e = 5;
        m_mindestHub = hub[e - 1];
    }

    void zuruecksetzen()
    {
        m_hatGlatt = false;
        m_glatt = 0;
        m_vorher = 0;
        m_letzteZeit = 0;
        m_kopf = 0;
        m_anzahl = 0;
        m_letzterKandidat = 0;
        m_letzterAbstand = 0;
        m_serie = 0;
        m_offen = 0;
        m_geht = false;
    }

    bool geht() const { return m_geht; }

    // Ein Messwert: Beschleunigung in m/s^2, Zeit in Millisekunden
    // (monoton). Gibt die Zahl der Schritte zurueck, die damit feststehen --
    // meist 0, beim Bestaetigen einer neuen Serie auf einmal 4.
    int probe(double x, double y, double z, long long t)
    {
        const double betrag = std::sqrt(x * x + y * y + z * z);
        if (!m_hatGlatt) {
            m_glatt = betrag;
            m_vorher = betrag;
            m_letzteZeit = t;
            m_hatGlatt = true;
            merken(t, betrag);
            return 0;
        }
        long long dt = t - m_letzteZeit;
        if (dt <= 0)
            return 0;
        if (dt > 1000) {
            // Luecke (Sensor angehalten): neu anfangen statt ueber die
            // Luecke hinweg zu rechnen.
            zuruecksetzen();
            return probe(x, y, z, t);
        }
        m_letzteZeit = t;

        // Tiefpass erster Ordnung, Grenzfrequenz 3 Hz: Gehen hat 1-3
        // Schritte je Sekunde, darueber ist es Zittern.
        const double rc = 1.0 / (2.0 * 3.14159265358979 * 3.0);
        const double a = (dt / 1000.0) / (rc + dt / 1000.0);
        m_glatt += a * (betrag - m_glatt);
        merken(t, m_glatt);

        int neu = 0;
        // Laenger als zwei Sekunden nichts: die Serie ist vorbei, offene
        // (unbestaetigte) Schritte verfallen.
        if (m_letzterKandidat && t - m_letzterKandidat > MAX_ABSTAND) {
            m_serie = 0;
            m_offen = 0;
            m_geht = false;
            m_letzterKandidat = 0;
            m_letzterAbstand = 0;
        }

        if (fensterDauer() >= 1000) {
            double lo, hi, mittel;
            fenster(lo, hi, mittel);
            const double schwelle = mittel;
            if (hi - lo >= m_mindestHub && m_vorher < schwelle && m_glatt >= schwelle)
                neu = kandidat(t);
        }
        m_vorher = m_glatt;
        return neu;
    }

private:
    enum { FENSTER = 512, FENSTER_MS = 2000, MIN_ABSTAND = 250, MAX_ABSTAND = 2000, BESTAETIGUNG = 4 };

    void merken(long long t, double w)
    {
        m_zeit[m_kopf] = t;
        m_wert[m_kopf] = w;
        m_kopf = (m_kopf + 1) % FENSTER;
        if (m_anzahl < FENSTER)
            ++m_anzahl;
        // Alles vor dem Fenster faellt hinten heraus.
        while (m_anzahl > 1 && t - m_zeit[(m_kopf - m_anzahl + FENSTER) % FENSTER] > FENSTER_MS)
            --m_anzahl;
    }

    long long fensterDauer() const
    {
        if (m_anzahl < 2)
            return 0;
        const int erster = (m_kopf - m_anzahl + FENSTER) % FENSTER;
        const int letzter = (m_kopf - 1 + FENSTER) % FENSTER;
        return m_zeit[letzter] - m_zeit[erster];
    }

    void fenster(double &lo, double &hi, double &mittel) const
    {
        lo = 1e30;
        hi = -1e30;
        double summe = 0;
        for (int i = 0; i < m_anzahl; ++i) {
            const double w = m_wert[(m_kopf - 1 - i + 2 * FENSTER) % FENSTER];
            if (w < lo) lo = w;
            if (w > hi) hi = w;
            summe += w;
        }
        mittel = m_anzahl ? summe / m_anzahl : 0;
    }

    // Ein Durchgang durch die Schwelle von unten: vielleicht ein Schritt.
    int kandidat(long long t)
    {
        if (m_letzterKandidat == 0) {
            neueSerie(t);
            return 0;
        }
        const long long abstand = t - m_letzterKandidat;
        if (abstand < MIN_ABSTAND)
            return 0;   // Prellen innerhalb eines Schritts
        // Gleichmaessig? Ein Schritt darf hoechstens halb so lang oder
        // doppelt so lang dauern wie der vorige.
        if (m_letzterAbstand && (abstand * 2 < m_letzterAbstand || abstand > 2 * m_letzterAbstand)) {
            neueSerie(t);
            return 0;
        }
        m_letzterKandidat = t;
        m_letzterAbstand = abstand;
        ++m_serie;
        if (m_geht)
            return 1;
        ++m_offen;
        if (m_serie >= BESTAETIGUNG) {
            m_geht = true;
            const int n = m_offen;
            m_offen = 0;
            return n;
        }
        return 0;
    }

    void neueSerie(long long t)
    {
        m_letzterKandidat = t;
        m_letzterAbstand = 0;
        m_serie = 1;
        m_offen = 1;
        m_geht = false;
    }

    double m_mindestHub;
    bool m_hatGlatt;
    double m_glatt;
    double m_vorher;
    long long m_letzteZeit;
    long long m_zeit[FENSTER];
    double m_wert[FENSTER];
    int m_kopf;
    int m_anzahl;
    long long m_letzterKandidat;
    long long m_letzterAbstand;
    int m_serie;
    int m_offen;
    bool m_geht;
};

#endif
