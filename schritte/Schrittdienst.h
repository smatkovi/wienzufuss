#ifndef SCHRITTDIENST_H
#define SCHRITTDIENST_H

// Der Kern des Schrittdienstes, fuer N9 (Qt 4.7) und Sailfish (Qt 5.6)
// gleich: fuehrt das Tagebuch, liest die Einstellungen, stoesst das
// Hochladen an und antwortet der Oberflaeche ueber den Sitzungsbus.
//
//   Dienst:      org.smatkovi.WienZuFuss.Schritte
//   Objekt:      /
//   Schnittstelle org.smatkovi.WienZuFuss.Schritte
//     Stand() -> s           JSON: heute, schritteHeute, geht, quelle, hinweis, tage
//     Aktualisieren()        Zaehler jetzt lesen und sichern
//     Neuladen()             Einstellungen neu lesen
//     Signal Geaendert(i)    Schritte heute
//
// Woher die Schritte kommen, entscheidet main.cpp der jeweiligen Plattform:
// es ruft schritte(n) (Beschleunigungssensor) oder zaehlerstand(n)
// (Hardware-Zaehler, Stand seit dem Einschalten).

#include <QObject>
#include <QDateTime>
#include <QString>

#include "Tagebuch.h"

class QTimer;

struct Einstellungen
{
    Einstellungen();
    bool zaehlen;
    bool beschleunigung;
    int empfindlichkeit;
    bool hochladen;
    bool operator==(const Einstellungen &o) const;
    bool operator!=(const Einstellungen &o) const { return !(*this == o); }
};

class Schrittdienst : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.smatkovi.WienZuFuss.Schritte")

public:
    // netzdienst: Pfad zu wzf-dienst, fuer "wzf-dienst sync".
    explicit Schrittdienst(const QString &netzdienst, QObject *parent = 0);

    static QString heim();
    const Einstellungen &einstellungen() const { return m_einst; }

    // Vom Beschleunigungssensor: n neue Schritte, jetzt.
    void schritte(int n);
    // Vom Hardware-Zaehler: Stand seit dem Einschalten des Geraets.
    void zaehlerstand(qint64 stand);
    void setQuelle(const QString &quelle, const QString &hinweis);
    void setGeht(bool geht);

    // Auf die Platte, falls sich etwas geaendert hat.
    void sichern(bool sofort = false);

public slots:
    Q_SCRIPTABLE QString Stand();
    Q_SCRIPTABLE void Aktualisieren();
    Q_SCRIPTABLE void Neuladen();

signals:
    Q_SCRIPTABLE void Geaendert(int heute);
    // Fuer main.cpp: Einstellungen anders / bitte den Zaehler jetzt lesen.
    void einstellungenGeaendert();
    void aktualisierenAngefordert();

private slots:
    void zeitgeber();
    void hochladenPruefen();

private:
    void einstellungenLesen(bool melden);

    Tagebuch m_buch;
    Einstellungen m_einst;
    QString m_netzdienst;
    QString m_einstDatei;
    QDateTime m_einstStand;
    bool m_geaendert;
    bool m_geht;
    QDateTime m_gesichert;
    QString m_letzterTag;
    bool m_seitUpload;
    QString m_uploadTag;
    QTimer *m_takt;
    QTimer *m_upload;
};

#endif
