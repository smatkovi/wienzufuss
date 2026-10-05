// wzf-schritte fuer Sailfish OS: zaehlt Schritte im Hintergrund.
//
// Laeuft als systemd-Benutzerdienst (wienzufuss-schritte.service) und auf
// dem Sitzungsbus als org.smatkovi.WienZuFuss.Schritte -- die App weckt ihn
// ueber D-Bus, falls er nicht laeuft.
//
// Quelle der Schritte, in dieser Reihenfolge:
//  1. der Schrittzaehler des Sensorchips ueber sensorfw (Hardwarezaehler.h):
//     zaehlt auch, wenn das Telefon schlaeft; der Dienst wacht alle zehn
//     Minuten kurz auf (keepalive), liest den Stand und schlaeft weiter.
//  2. sonst, wenn in den Einstellungen erlaubt: der Beschleunigungssensor
//     mit der Schritterkennung des N9. Dafuer darf das Telefon nicht
//     schlafen (keepalive haelt es wach) -- das kostet Akku.

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QSocketNotifier>
#include <QTimer>
#include <QtSensors/QAccelerometer>
#include <QtSensors/QAccelerometerFilter>

#include <keepalive/backgroundactivity.h>

#include <csignal>
#include <cstdio>
#include <sys/socket.h>
#include <unistd.h>

#include "../Schrittdienst.h"
#include "../Schritterkennung.h"
#include "../Ruhewaechter.h"
#include "Hardwarezaehler.h"

#ifndef NETZDIENST
#define NETZDIENST "/usr/libexec/wienzufuss/wzf-dienst"
#endif

static int signalPaar[2];

static void beiSignal(int)
{
    char c = 1;
    ssize_t r = ::write(signalPaar[0], &c, 1);
    (void)r;
}

class Beschleunigung : public QAccelerometerFilter
{
public:
    Beschleunigung(Schrittdienst *d) : m_dienst(d), m_steuerung(0) {}
    bool filter(QAccelerometerReading *r)
    {
        const long long t = (long long)(r->timestamp() / 1000);
        const int n = m_erkennung.probe(r->x(), r->y(), r->z(), t);
        if (n > 0)
            m_dienst->schritte(n);
        m_dienst->setGeht(m_erkennung.geht());
        // Liegt das Telefon still, langsamer messen (Ruhewaechter.h).
        if (m_waechter.probe(r->x(), r->y(), r->z(), t, m_erkennung.geht()) && m_steuerung)
            QMetaObject::invokeMethod(m_steuerung, "rateAnpassen", Qt::QueuedConnection);
        return false;
    }
    Schritterkennung m_erkennung;
    Ruhewaechter m_waechter;
    QObject *m_steuerung;
private:
    Schrittdienst *m_dienst;
};

class Steuerung : public QObject
{
    Q_OBJECT
public:
    Steuerung(Schrittdienst *d)
        : m_dienst(d), m_hw(new Hardwarezaehler(this)), m_sensor(0), m_filter(d),
          m_wecker(new BackgroundActivity(this)), m_wach(new BackgroundActivity(this))
    {
        m_filter.m_steuerung = this;
        connect(m_hw, SIGNAL(stand(qint64)), this, SLOT(hwStand(qint64)));
        connect(m_hw, SIGNAL(verloren()), this, SLOT(hwVerloren()));
        connect(m_dienst, SIGNAL(einstellungenGeaendert()), this, SLOT(anwenden()));
        connect(m_dienst, SIGNAL(aktualisierenAngefordert()), this, SLOT(hwLesen()));
        connect(m_wecker, SIGNAL(running()), this, SLOT(geweckt()));
        // Solange das Telefon wach ist, alle 30 s nachsehen.
        QTimer *t = new QTimer(this);
        t->setInterval(30000);
        connect(t, SIGNAL(timeout()), this, SLOT(hwLesen()));
        t->start();
    }

public slots:
    void anwenden()
    {
        const Einstellungen &e = m_dienst->einstellungen();
        m_filter.m_erkennung.setEmpfindlichkeit(e.empfindlichkeit);
        if (!e.zaehlen) {
            allesAus();
            m_dienst->setQuelle(QLatin1String("aus"), QString::fromUtf8("Zählen ist ausgeschaltet."));
            return;
        }
        if (m_hw->laeuft() || m_hw->starten()) {
            beschleunigungAus();
            m_dienst->setQuelle(QLatin1String("hardware"), QString());
            hwLesen();
            // Regelmaessig aufwachen, auch wenn das Telefon schlaeft.
            m_wecker->wait(BackgroundActivity::TenMinutes);
            return;
        }
        const QString warum = m_hw->fehler();
        m_wecker->stop();
        if (!e.beschleunigung) {
            beschleunigungAus();
            m_dienst->setQuelle(QLatin1String("keine"),
                                warum + QLatin1String(". Der Beschleunigungssensor ist als Ersatz möglich, "
                                                      "braucht aber mehr Akku (Einstellungen)."));
            return;
        }
        beschleunigungAn();
    }

    void rateAnpassen()
    {
        const int ziel = m_filter.m_waechter.ruhig() ? 5 : 20;
        if (!m_sensor || !m_sensor->isActive() || m_sensor->dataRate() == ziel)
            return;
        m_sensor->stop();
        m_sensor->setDataRate(ziel);
        m_sensor->start();
        std::fprintf(stderr, "wzf-schritte: %s, %d Hz\n", m_filter.m_waechter.ruhig() ? "ruhig" : "Bewegung", ziel);
    }

    void hwLesen()
    {
        if (!m_hw->laeuft())
            return;
        const qint64 s = m_hw->lesen();
        if (s >= 0)
            m_dienst->zaehlerstand(s);
    }

    void hwStand(qint64 s)
    {
        m_dienst->zaehlerstand(s);
    }

    void hwVerloren()
    {
        // sensorfwd neu gestartet? In einer Minute neu verbinden.
        QTimer::singleShot(60000, this, SLOT(anwenden()));
    }

    void geweckt()
    {
        hwLesen();
        m_dienst->sichern(true);
        m_wecker->wait(BackgroundActivity::TenMinutes);
    }

private:
    void beschleunigungAn()
    {
        if (!m_sensor) {
            m_sensor = new QAccelerometer(this);
            m_sensor->setAlwaysOn(true);
            m_sensor->setDataRate(20);
            // Zehn Messungen je Lieferung (am N950 halbiert das den
            // Verbrauch; sensorfw unter Sailfish kann dasselbe).
            m_sensor->setBufferSize(10);
            m_sensor->addFilter(&m_filter);
        }
        if (!m_sensor->isActive() && !m_sensor->start()) {
            m_dienst->setQuelle(QLatin1String("keine"), QString::fromUtf8("Beschleunigungssensor nicht verfügbar."));
            return;
        }
        // Ohne das schlaeft das Telefon ein und der Sensor mit.
        m_wach->run();
        m_dienst->setQuelle(QLatin1String("beschleunigung"), QString());
    }

    void beschleunigungAus()
    {
        if (m_sensor && m_sensor->isActive())
            m_sensor->stop();
        m_wach->stop();
    }

    void allesAus()
    {
        beschleunigungAus();
        m_hw->stoppen();
        m_wecker->stop();
    }

    Schrittdienst *m_dienst;
    Hardwarezaehler *m_hw;
    QAccelerometer *m_sensor;
    Beschleunigung m_filter;
    BackgroundActivity *m_wecker;
    BackgroundActivity *m_wach;
};

int main(int argc, char *argv[])
{
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

    Steuerung steuerung(&dienst);
    steuerung.anwenden();

    // SIGTERM (systemd beim Abmelden/Herunterfahren): sauber sichern.
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
