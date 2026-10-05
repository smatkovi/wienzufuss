// Prueft die Schritterkennung an kuenstlichen Signalen.
//
//   g++ -std=c++98 -O2 -Wall -o /tmp/schritttest schritte/test/test.cpp && /tmp/schritttest
//
// Kuenstlich heisst: das ersetzt keinen Gang mit dem Telefon in der
// Tasche, aber es haelt fest, dass Ruhe und einzelne Stoesse nichts zaehlen
// und dass Gehen bei 20 Hz (N9) wie bei 100 Hz gezaehlt wird.

#include "../Schritterkennung.h"
#include "../Ruhewaechter.h"
#include <cmath>
#include <cstdio>

static unsigned long long zustand = 88172645463325252ULL;
static double gleich() // 0..1
{
    zustand ^= zustand << 13; zustand ^= zustand >> 7; zustand ^= zustand << 17;
    return (zustand >> 11) * (1.0 / 9007199254740992.0);
}
static double normal()
{
    double u = gleich(), v = gleich();
    if (u < 1e-12) u = 1e-12;
    return std::sqrt(-2.0 * std::log(u)) * std::cos(2 * 3.14159265358979 * v);
}

struct Fall {
    const char *name;
    double hz;        // Abtastrate
    double dauer;     // s
    double takt;      // Schritte/s (0 = keine)
    double hub;       // m/s^2 Amplitude der Grundschwingung
    double rauschen;  // m/s^2
    double stoesse;   // einzelne Stoesse je Minute
    double schwanken; // Taktschwankung (0..1)
    int erwartet;     // erwartete Schritte (-1: nur ausgeben)
    double toleranz;  // relativ
};

static int lauf(const Fall &f, int empf)
{
    Schritterkennung s(empf);
    const double dt = 1.0 / f.hz;
    double phase = 0;
    int schritte = 0;
    double naechsterStoss = f.stoesse > 0 ? 60.0 / f.stoesse * gleich() : 1e9;
    for (double t = 0; t < f.dauer; t += dt) {
        double takt = f.takt * (1.0 + f.schwanken * std::sin(t * 0.3));
        phase += 2 * 3.14159265358979 * takt * dt;
        double m = 0;
        if (f.takt > 0)
            m = f.hub * std::sin(phase) + 0.45 * f.hub * std::sin(2 * phase + 0.8);
        if (t >= naechsterStoss && t < naechsterStoss + 0.15)
            m += 9.0 * std::sin((t - naechsterStoss) / 0.15 * 3.14159265358979);
        if (t >= naechsterStoss + 0.15)
            naechsterStoss += 60.0 / f.stoesse * (0.5 + gleich());
        // Lage im Raum dreht sich langsam: der Betrag bleibt, die Achsen nicht.
        double g = 9.81 + m;
        double w = t * 0.05;
        double x = g * std::sin(w) * 0.6 + f.rauschen * normal();
        double y = g * std::cos(w) * 0.6 + f.rauschen * normal();
        double z = g * 0.8 + f.rauschen * normal();
        schritte += s.probe(x, y, z, (long long)(t * 1000.0 + 0.5));
    }
    return schritte;
}

int main()
{
    const Fall faelle[] = {
        { "Ruhe 10 min, 20 Hz",            20, 600, 0,   0,   0.08, 0,  0,   0,   0 },
        { "Ruhe 10 min, 100 Hz",          100, 600, 0,   0,   0.08, 0,  0,   0,   0 },
        { "Stoesse 6/min, 20 Hz",          20, 600, 0,   0,   0.08, 6,  0,   0,   0 },
        { "Gehen 1,8/s 100 s, 20 Hz",      20, 100, 1.8, 2.5, 0.3,  0,  0,   180, 0.04 },
        { "Gehen 1,8/s 100 s, 100 Hz",    100, 100, 1.8, 2.5, 0.3,  0,  0,   180, 0.04 },
        { "langsam 1,2/s 100 s, 20 Hz",    20, 100, 1.2, 1.8, 0.3,  0,  0,   120, 0.05 },
        { "schnell 2,6/s 100 s, 25 Hz",    25, 100, 2.6, 5.0, 0.4,  0,  0,   260, 0.05 },
        { "Gehen schwankend 300 s, 20 Hz", 20, 300, 1.8, 2.5, 0.4,  0,  0.25, 540, 0.06 },
        { "Gehen + Stoesse 300 s, 20 Hz",  20, 300, 1.8, 2.5, 0.3,  4,  0,   540, 0.06 },
        { "schwach (Hand) 100 s, 20 Hz",   20, 100, 1.7, 1.0, 0.2,  0,  0,   -1,  0 },
    };
    int fehler = 0;
    for (int empf = 2; empf <= 4; ++empf) {
        std::printf("== Empfindlichkeit %d\n", empf);
        for (unsigned i = 0; i < sizeof(faelle) / sizeof(faelle[0]); ++i) {
            const Fall &f = faelle[i];
            int n = lauf(f, empf);
            bool ok = true;
            if (f.erwartet == 0)
                ok = n == 0;
            else if (f.erwartet > 0)
                ok = std::fabs(n - f.erwartet) <= f.toleranz * f.erwartet + 1;
            if (!ok) ++fehler;
            std::printf("  %-32s %5d  (erwartet %s%d) %s\n", f.name, n,
                        f.erwartet < 0 ? "~" : "", f.erwartet < 0 ? 0 : f.erwartet, ok ? "ok" : "FALSCH");
        }
    }
    // Ruhewaechter: 60 s Ruhe bei 20 Hz -> nach gut 30 s ruhig; dann
    // Gehen mit 5 Hz -> binnen einer Sekunde wieder wach.
    {
        Ruhewaechter w;
        long long ruhigAb = -1, wachAb = -1;
        for (int i = 0; i < 1200; ++i) {
            const long long t = i * 50;
            if (w.probe(0.1 * normal(), 0.1 * normal(), 9.81 + 0.08 * normal(), t, false) && w.ruhig())
                ruhigAb = t;
        }
        for (int i = 0; i < 50; ++i) {
            const long long t = 60000 + i * 200;
            const double m = 9.81 + 2.5 * std::sin(2 * 3.14159265358979 * 1.8 * t / 1000.0 + 0.3);
            if (w.probe(0.2, 0.3, m, t, false) && !w.ruhig() && wachAb < 0)
                wachAb = t - 60000;
        }
        const bool ok = ruhigAb >= 30000 && ruhigAb <= 31000 && wachAb >= 0 && wachAb <= 1000;
        if (!ok) ++fehler;
        std::printf("== Ruhewaechter: ruhig nach %lld ms, wach nach %lld ms %s\n", ruhigAb, wachAb, ok ? "ok" : "FALSCH");
    }
    std::printf(fehler ? "%d Fehler\n" : "alles ok\n", fehler);
    return fehler ? 1 : 0;
}
