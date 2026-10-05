#ifndef HARDWAREZAEHLER_H
#define HARDWAREZAEHLER_H

// Der Schrittzaehler des Sensorchips, ueber sensorfw (sensorfwd).
//
// Viele Telefone, auf denen Sailfish laeuft, zaehlen Schritte im
// Sensor-Hub selbst -- auch wenn das Telefon schlaeft, fast ohne Akku.
// sensorfw reicht ihn ueber den hybris-Adapter als "stepcountersensor"
// durch, sofern die Geraetekonfiguration ihn einschaltet
// (/etc/sensorfw: stepcounteradaptor = hybrisstepcounteradaptor,
// stepcountersensor=True). Manche Geraete haben ihn, blenden ihn aber aus
// (Jolla Phone 2026) -- dann schaltet ihn das RPM frei, siehe
// sailfish/sensorfw/.
//
// Statt der Client-Bibliothek von sensorfw (libsensorclient-qt5, im
// SDK-Ziel nicht vorhanden) spricht diese Klasse das Protokoll selbst:
//
//   1. System-Bus com.nokia.SensorService /SensorManager local.SensorManager:
//      loadPlugin("stepcountersensor"), requestSensor(id, pid) -> Sitzung
//   2. /run/sensord.sock verbinden, Server schickt "\n", Client schickt die
//      Sitzungsnummer (int). Ohne das verwirft sensorfwd die Sitzung nach
//      10 s (SOCKET_CONNECTION_TIMEOUT_MS).
//   3. /SensorManager/stepcountersensor local.StepCounterSensor:
//      setStandbyOverride(sitzung, true), start(sitzung)
//   4. Stand lesen: steps() -> (tu) Zeitstempel, Schritte seit Boot
//      (Zeitstempel 0: noch keine Meldung seit dem Einschalten).
//      Ueber den Socket kommen ausserdem Rahmen <uint32 n><n x {u64 t, u32 w}>.

#include <QObject>
#include <QByteArray>

class QLocalSocket;

class Hardwarezaehler : public QObject
{
    Q_OBJECT
public:
    explicit Hardwarezaehler(QObject *parent = 0);
    ~Hardwarezaehler();

    // true, wenn es den Zaehler gibt und er laeuft. Sonst steht in
    // fehler(), warum nicht.
    bool starten();
    void stoppen();
    bool laeuft() const { return m_sitzung >= 0; }
    QString fehler() const { return m_fehler; }

    // Stand ueber D-Bus (Schritte seit Boot), -1 bei Fehler. KEIN_WERT,
    // solange der Sensor seit dem Einschalten nichts gemeldet hat: steps()
    // liefert dann Zeitstempel 0 und 0 Schritte -- das ist kein Stand.
    enum { KEIN_WERT = -2 };
    qint64 lesen();

signals:
    void stand(qint64 wert);
    void verloren();

private slots:
    void socketLesen();
    void socketWeg();

private:
    int m_sitzung;
    QLocalSocket *m_socket;
    QByteArray m_puffer;
    bool m_kennungGelesen;
    QString m_fehler;
};

#endif
