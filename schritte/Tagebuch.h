#ifndef TAGEBUCH_H
#define TAGEBUCH_H

// Die Tagessummen der gezaehlten Schritte, in
// ~/.local/share/wienzufuss/schritte.json:
//
//   {"version":1,"quelle":"hardware","hinweis":"","stand":"2026-10-05 14:03:00",
//    "hw":{"letzter":12345,"boot":"<boot_id>"},
//    "tage":{"2026-10-04":8123,"2026-10-05":312}}
//
// Geschrieben nur vom Schrittdienst; gelesen vom Netzdienst (Upload) und
// ueber diesen von der Oberflaeche. Qt 4.7 hat kein JSON -- das Format ist
// fest und klein genug, um es von Hand zu schreiben und zu lesen.
//
// Qt 4.7 (N9, C++98) und Qt 5.6 (Sailfish) aus derselben Quelle.

#include <QMap>
#include <QString>

class Tagebuch
{
public:
    explicit Tagebuch(const QString &datei);

    void laden();
    bool sichern();

    // n Schritte auf den heutigen Tag (Ortszeit des Geraets).
    void hinzu(int n);
    int heute() const;
    QString heuteDatum() const;
    const QMap<QString, int> &tage() const { return m_tage; }

    QString quelle;
    QString hinweis;

    // Hardware-Zaehler: letzter gesehener Stand und die Boot-ID, zu der er
    // gehoert. Der Zaehler beginnt bei jedem Start des Geraets bei 0.
    qint64 hwLetzter;
    QString hwBoot;

    // Was davon fuer die Oberflaeche ueber D-Bus geht.
    QString json(bool geht) const;

private:
    void kuerzen();
    QString m_datei;
    QMap<QString, int> m_tage;
};

QString jetztText();
QString bootId();

#endif
