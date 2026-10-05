#ifndef HARDWAREZAEHLER_H
#define HARDWAREZAEHLER_H

// Der Schrittzaehler des Sensorchips, ueber sensorfw (sensorfwd).
//
// Viele Telefone, auf denen Sailfish laeuft, zaehlen Schritte im
// Sensor-Hub selbst -- auch wenn das Telefon schlaeft, fast ohne Akku.
// sensorfw reicht ihn ueber den hybris-Adapter als "stepcountersensor"
// durch, sofern die Geraetekonfiguration ihn einschaltet
// (/etc/sensorfw/primaryuse.conf: stepcountersensor=True).
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
//   4. Stand lesen: steps() -> (tu) Zeitstempel, Schritte seit Boot.
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

    // Stand ueber D-Bus, -1 bei Fehler.
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
