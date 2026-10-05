#ifndef RUHEWAECHTER_H
#define RUHEWAECHTER_H

// Merkt, ob das Telefon ruhig liegt, damit der Beschleunigungssensor dann
// langsamer laufen kann.
//
// Am N950 gemessen: 20 Messungen/s kosten den Schrittdienst und sensord
// zusammen gut 2 % eines Kerns (bei 0 % ohne ihn), auch bei dunklem
// Bildschirm -- und die meiste Zeit des Tages liegt das Telefon still.
// Liegt es 30 s ruhig, schaltet main.cpp auf 5 Hz; bei der ersten
// Bewegung zurueck auf 20 Hz. Die ersten ein, zwei Schritte eines Gangs
// gehen dabei verloren; gezaehlt wird ohnehin erst ab dem vierten.
//
// Reines C++98 wie Schritterkennung.h.

#include <cmath>

class Ruhewaechter
{
public:
    Ruhewaechter() : m_hat(false), m_mittel(0), m_letzteZeit(0), m_bewegt(0), m_ruhe(false) {}

    // Ein Messwert (m/s^2, ms). Gibt zurueck, ob sich der Zustand
    // geaendert hat; ruhig() sagt dann, welcher.
    bool probe(double x, double y, double z, long long t, bool geht)
    {
        const double betrag = std::sqrt(x * x + y * y + z * z);
        if (!m_hat) {
            m_hat = true;
            m_mittel = betrag;
            m_letzteZeit = t;
            m_bewegt = t;
            return false;
        }
        long long dt = t - m_letzteZeit;
        if (dt <= 0)
            return false;
        if (dt > 2000)
            dt = 2000;
        m_letzteZeit = t;
        // Langsamer Mittelwert (Zeitkonstante 2 s): Lage und Schwerkraft.
        m_mittel += (dt / (2000.0 + dt)) * (betrag - m_mittel);
        const double abweichung = std::fabs(betrag - m_mittel);

        if (m_ruhe) {
            if (abweichung > 0.8) {
                m_ruhe = false;
                m_bewegt = t;
                return true;
            }
            return false;
        }
        if (abweichung > 0.5 || geht)
            m_bewegt = t;
        else if (t - m_bewegt > 30000) {
            m_ruhe = true;
            return true;
        }
        return false;
    }

    bool ruhig() const { return m_ruhe; }

private:
    bool m_hat;
    double m_mittel;
    long long m_letzteZeit;
    long long m_bewegt;
    bool m_ruhe;
};

#endif
