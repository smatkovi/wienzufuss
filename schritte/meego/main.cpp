// wzf-schritte fuer das N9/N950: zaehlt Schritte im Hintergrund.
//
// Das N9 hat keinen Schrittzaehler im Sensorchip, nur den
// Beschleunigungssensor (lis3lv02d). Der Dienst liest ihn mit 20 Hz ueber
// QtMobility und sensord; mit der Eigenschaft "alwaysOn" setzt das
// Meego-Sensor-Plugin den Standby-Override, und sensord liefert auch bei
// dunklem Bildschirm weiter (am N950 nachgesehen: libqtsensors_meego.so ruft
// setStandbyOverride). Erkannt werden die Schritte mit Schritterkennung.h.
//
// Gestartet wird der Dienst ueber den Sitzungsbus
// (org.smatkovi.WienZuFuss.Schritte): die App weckt ihn, und ein Job unter
// /etc/init/apps stoesst ihn alle fuenf Minuten an, falls er nicht laeuft --
// dasselbe Muster wie das WhatsApp-Backend auf diesem Geraet.

#include <QCoreApplication>
#include <QDBusConnection>
#include <QFile>
#include <QSocketNotifier>
#include <QStringList>
#include <QTimer>
#include <QAccelerometer>

#include <csignal>
#include <cstdio>
#include <sys/socket.h>
#include <unistd.h>

#include "../Schrittdienst.h"
#include "../Schritterkennung.h"
#include "../Ruhewaechter.h"

QTM_USE_NAMESPACE

#ifndef NETZDIENST
#define NETZDIENST "/opt/wienzufuss/bin/wzf-dienst"
#endif

static int signalPaar[2];

static void beiSignal(int)
{
    char c = 1;
    ssize_t r = ::write(signalPaar[0], &c, 1);
    (void)r;
}

// Per ssh gestartet fehlt die Adresse des Sitzungsbusses; Harmattan legt
// sie in dieser Datei ab.
static void sitzungsBusSetzen()
{
    if (!qgetenv("DBUS_SESSION_BUS_ADDRESS").isEmpty())
        return;
    QFile f(QLatin1String("/tmp/session_bus_address.user"));
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QStringList zeilen = QString::fromLatin1(f.readAll()).split(QLatin1Char('\n'));
    for (int i = 0; i < zeilen.size(); ++i) {
        const QString z = zeilen.at(i);
        const int p = z.indexOf(QLatin1String("DBUS_SESSION_BUS_ADDRESS="));
        if (p < 0)
            continue;
        QString wert = z.mid(p + 25).trimmed();
        if (wert.endsWith(QLatin1Char(';')))
            wert.chop(1);
        if (wert.length() > 1 && (wert.at(0) == QLatin1Char('"') || wert.at(0) == QLatin1Char('\''))
                && wert.at(wert.length() - 1) == wert.at(0))
            wert = wert.mid(1, wert.length() - 2);
        if (!wert.isEmpty())
            qputenv("DBUS_SESSION_BUS_ADDRESS", wert.toLatin1());
        return;
    }
}

class Beschleunigung : public QObject, public QAccelerometerFilter
{
    Q_OBJECT
public:
    Beschleunigung(Schrittdienst *d)
        : m_dienst(d), m_sensor(new QAccelerometer(this)), m_proben(0), m_ersteZeit(0),
          m_diagnose(!qgetenv("WZF_DIAGNOSE").isEmpty())
    {
        m_sensor->setProperty("alwaysOn", true);
        m_sensor->setDataRate(20);
        // sensord buendelt zehn Messungen je Lieferung (jede mit eigenem
        // Zeitstempel). Am N950 gemessen, CPU-Ticks je Minute fuer Dienst +
        // sensord: 20 Hz ungepuffert 211, gepuffert 96; ruhig (5 Hz) 64
        // bzw. 26.
        m_sensor->setProperty("bufferSize", qgetenv("WZF_PUFFER").isEmpty() ? 10 : qgetenv("WZF_PUFFER").toInt());
        m_sensor->addFilter(this);
        connect(m_dienst, SIGNAL(einstellungenGeaendert()), this, SLOT(anwenden()));
    }

    bool filter(QAccelerometerReading *r)
    {
        const long long t = (long long)(r->timestamp() / 1000);
        if (m_proben == 0)
            m_ersteZeit = t;
        if (++m_proben == 200) {
            // Einmal ins Protokoll: welche Rate sensord wirklich liefert.
            std::fprintf(stderr, "wzf-schritte: %.1f Messungen/s\n",
                         199000.0 / double(t - m_ersteZeit > 0 ? t - m_ersteZeit : 1));
        }
        const int n = m_erkennung.probe(r->x(), r->y(), r->z(), t);
        if (n > 0)
            m_dienst->schritte(n);
        m_dienst->setGeht(m_erkennung.geht());
        // Liegt das Telefon still, langsamer messen (Ruhewaechter.h). Nicht
        // hier umschalten: filter() laeuft mitten in der Messung.
        if (m_waechter.probe(r->x(), r->y(), r->z(), t, m_erkennung.geht()))
            QMetaObject::invokeMethod(this, "rateAnpassen", Qt::QueuedConnection);
        if (m_diagnose && m_proben % 40 == 0)
            std::fprintf(stderr, "wzf-schritte: t=%lld x=%.2f y=%.2f z=%.2f ruhig=%d rate=%d\n",
                         t, r->x(), r->y(), r->z(), int(m_waechter.ruhig()), m_sensor->dataRate());
        // false: das Signal readingChanged wird nicht ausgeloest, das spart
        // je Messung einen Umweg durch die Ereignisschleife.
        return false;
    }

public slots:
    void rateAnpassen()
    {
        const int ziel = m_waechter.ruhig() ? 5 : 20;
        if (!m_sensor->isActive() || m_sensor->dataRate() == ziel)
            return;
        m_sensor->stop();
        m_sensor->setDataRate(ziel);
        m_sensor->start();
        std::fprintf(stderr, "wzf-schritte: %s, %d Hz\n", m_waechter.ruhig() ? "ruhig" : "Bewegung", ziel);
    }

    void anwenden()
    {
        const Einstellungen &e = m_dienst->einstellungen();
        m_erkennung.setEmpfindlichkeit(e.empfindlichkeit);
        if (!e.zaehlen) {
            if (m_sensor->isActive())
                m_sensor->stop();
            m_erkennung.zuruecksetzen();
            m_dienst->setQuelle(QLatin1String("aus"), QString::fromUtf8("Zählen ist ausgeschaltet."));
            return;
        }
        if (!m_sensor->isActive()) {
            if (!m_sensor->start()) {
                m_dienst->setQuelle(QLatin1String("keine"),
                                    QString::fromUtf8("Beschleunigungssensor nicht verfügbar."));
                // In einer Minute noch einmal.
                QTimer::singleShot(60000, this, SLOT(anwenden()));
                return;
            }
            QList<qrange> raten = m_sensor->availableDataRates();
            QStringList t;
            for (int i = 0; i < raten.size(); ++i)
                t << QString::fromLatin1("%1-%2").arg(raten.at(i).first).arg(raten.at(i).second);
            std::fprintf(stderr, "wzf-schritte: Sensor an, Raten %s, eingestellt %d, Puffer %s (max %s, guenstig %s)\n",
                         t.join(QLatin1String(",")).toLatin1().constData(), m_sensor->dataRate(),
                         m_sensor->property("bufferSize").toString().toLatin1().constData(),
                         m_sensor->property("maxBufferSize").toString().toLatin1().constData(),
                         m_sensor->property("efficientBufferSize").toString().toLatin1().constData());
        }
        m_dienst->setQuelle(QLatin1String("beschleunigung"), QString());
    }

private:
    Schrittdienst *m_dienst;
    QAccelerometer *m_sensor;
    Schritterkennung m_erkennung;
    Ruhewaechter m_waechter;
    int m_proben;
    long long m_ersteZeit;
    bool m_diagnose;
};

int main(int argc, char *argv[])
{
    sitzungsBusSetzen();
    QCoreApplication app(argc, argv);
    app.setApplicationName(QLatin1String("wzf-schritte"));

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.isConnected()) {
        std::fprintf(stderr, "wzf-schritte: kein Sitzungsbus\n");
        return 1;
    }
    if (!bus.registerService(QLatin1String("org.smatkovi.WienZuFuss.Schritte"))) {
        std::fprintf(stderr, "wzf-schritte: laeuft schon\n");
        return 0;
    }

    Schrittdienst dienst(QLatin1String(NETZDIENST));
    bus.registerObject(QLatin1String("/"), &dienst,
                       QDBusConnection::ExportScriptableSlots | QDBusConnection::ExportScriptableSignals);

    Beschleunigung sensor(&dienst);
    sensor.anwenden();

    ::socketpair(AF_UNIX, SOCK_STREAM, 0, signalPaar);
    QSocketNotifier melder(signalPaar[1], QSocketNotifier::Read);
    QObject::connect(&melder, SIGNAL(activated(int)), &app, SLOT(quit()));
    std::signal(SIGTERM, beiSignal);
    std::signal(SIGINT, beiSignal);

    const int r = app.exec();
    dienst.sichern(true);
    return r;
}

#include "main.moc"
