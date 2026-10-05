#ifndef SCHRITTZAEHLER_H
#define SCHRITTZAEHLER_H

// Die Verbindung der Oberflaeche zum Schrittdienst (wzf-schritte) ueber den
// Sitzungsbus. Der Dienst laeuft im Hintergrund weiter, auch wenn die App
// zu ist; ein Aufruf an seinen Namen startet ihn, falls er nicht laeuft
// (D-Bus-Aktivierung).
//
// `stand` ist die JSON-Antwort von Stand(); zerlegt wird sie in QML
// (JSON.parse), weil Qt 4.7 kein JSON kennt. Gilt fuer N9 und Sailfish.

#include <QObject>
#include <QString>

class QDBusPendingCallWatcher;
class QTimer;

class Schrittzaehler : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString stand READ stand NOTIFY geaendert)
    Q_PROPERTY(bool erreichbar READ erreichbar NOTIFY geaendert)
    Q_PROPERTY(bool aktiv READ aktiv WRITE setAktiv NOTIFY aktivChanged)

public:
    explicit Schrittzaehler(QObject *parent = 0);

    QString stand() const { return m_stand; }
    bool erreichbar() const { return m_erreichbar; }
    bool aktiv() const { return m_aktiv; }
    // Solange die App vorne ist, alle paar Sekunden nachfragen.
    void setAktiv(bool a);

    Q_INVOKABLE void aktualisieren();
    // Der Dienst soll die Einstellungen neu lesen (nach einer Aenderung).
    Q_INVOKABLE void neuladen();

signals:
    void geaendert();
    void aktivChanged();

private slots:
    void antwort(QDBusPendingCallWatcher *w);
    void signalGeaendert(int heute);

private:
    void rufen(const char *methode, bool mitAntwort);

    QString m_stand;
    bool m_erreichbar;
    bool m_aktiv;
    bool m_laeuft;
    QTimer *m_takt;
};

#endif
