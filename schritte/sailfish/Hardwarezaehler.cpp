#include "Hardwarezaehler.h"

#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QLocalSocket>
#include <QVariant>

#include <cstdio>
#include <cstring>
#include <unistd.h>

static const char *DIENST = "com.nokia.SensorService";
static const char *SENSOR = "stepcountersensor";

static QDBusInterface *verwalter()
{
    return new QDBusInterface(QLatin1String(DIENST), QLatin1String("/SensorManager"),
                              QLatin1String("local.SensorManager"), QDBusConnection::systemBus());
}

static QDBusInterface *sensor()
{
    return new QDBusInterface(QLatin1String(DIENST),
                              QLatin1String("/SensorManager/") + QLatin1String(SENSOR),
                              QLatin1String("local.StepCounterSensor"), QDBusConnection::systemBus());
}

Hardwarezaehler::Hardwarezaehler(QObject *parent)
    : QObject(parent), m_sitzung(-1), m_socket(0), m_kennungGelesen(false)
{
}

Hardwarezaehler::~Hardwarezaehler()
{
    stoppen();
}

bool Hardwarezaehler::starten()
{
    if (m_sitzung >= 0)
        return true;
    m_fehler.clear();

    QScopedPointer<QDBusInterface> sm(verwalter());
    if (!sm->isValid()) {
        m_fehler = QLatin1String("sensorfwd nicht erreichbar");
        return false;
    }
    QDBusReply<bool> geladen = sm->call(QLatin1String("loadPlugin"), QLatin1String(SENSOR));
    if (!geladen.isValid() || !geladen.value()) {
        m_fehler = QString::fromUtf8("Kein Hardware-Schrittzähler (sensorfw kennt stepcountersensor nicht)");
        return false;
    }
    QDBusReply<int> sitzung = sm->call(QLatin1String("requestSensor"), QLatin1String(SENSOR),
                                       qint64(::getpid()));
    if (!sitzung.isValid() || sitzung.value() < 0) {
        m_fehler = QString::fromUtf8("Schrittzähler nicht verfügbar (requestSensor)");
        return false;
    }
    m_sitzung = sitzung.value();

    // Innerhalb von 10 s die Sitzung am Socket anmelden, sonst ist sie weg.
    m_socket = new QLocalSocket(this);
    m_puffer.clear();
    m_kennungGelesen = false;
    connect(m_socket, SIGNAL(readyRead()), this, SLOT(socketLesen()));
    connect(m_socket, SIGNAL(disconnected()), this, SLOT(socketWeg()));
    const QByteArray pfad = qgetenv("SENSORFW_SOCKET_PATH") + QByteArray("/run/sensord.sock");
    m_socket->connectToServer(QString::fromLocal8Bit(pfad), QIODevice::ReadWrite);
    if (!m_socket->waitForConnected(3000)) {
        m_fehler = QLatin1String("sensord.sock: ") + m_socket->errorString();
        stoppen();
        return false;
    }
    const int nummer = m_sitzung;
    m_socket->write(reinterpret_cast<const char *>(&nummer), sizeof(nummer));
    m_socket->flush();
    m_socket->waitForBytesWritten(1000);

    QScopedPointer<QDBusInterface> s(sensor());
    // Auch bei dunklem Bildschirm weiterzaehlen. Scheitert das still, steht
    // der Zaehler bei dunklem Bildschirm -- deshalb ins Protokoll.
    QDBusReply<bool> standby = s->call(QLatin1String("setStandbyOverride"), m_sitzung, true);
    std::fprintf(stderr, "wzf-schritte: setStandbyOverride -> %s\n",
                 !standby.isValid() ? standby.error().message().toUtf8().constData()
                                    : (standby.value() ? "ja" : "nein"));
    s->call(QLatin1String("start"), m_sitzung);
    // KEIN_WERT ist in Ordnung: der Sensor antwortet, hat nur noch nichts
    // gemeldet (am Jolla Phone 2026 bis zum ersten Schritt).
    if (lesen() == -1) {
        m_fehler = QString::fromUtf8("Schrittzähler liefert keinen Stand");
        stoppen();
        return false;
    }
    std::fprintf(stderr, "wzf-schritte: Hardware-Schrittzähler läuft (Sitzung %d)\n", m_sitzung);
    return true;
}

void Hardwarezaehler::stoppen()
{
    if (m_sitzung >= 0) {
        QScopedPointer<QDBusInterface> s(sensor());
        s->call(QLatin1String("stop"), m_sitzung);
        QScopedPointer<QDBusInterface> sm(verwalter());
        sm->call(QLatin1String("releaseSensor"), QLatin1String(SENSOR), m_sitzung, qint64(::getpid()));
        m_sitzung = -1;
    }
    if (m_socket) {
        m_socket->disconnect(this);
        m_socket->abort();
        m_socket->deleteLater();
        m_socket = 0;
    }
}

qint64 Hardwarezaehler::lesen()
{
    if (m_sitzung < 0)
        return -1;
    QScopedPointer<QDBusInterface> s(sensor());
    QDBusMessage antwort = s->call(QLatin1String("steps"));
    if (antwort.type() != QDBusMessage::ReplyMessage || antwort.arguments().isEmpty())
        return -1;
    const QVariant v = antwort.arguments().at(0);
    if (!v.canConvert<QDBusArgument>())
        return v.canConvert<qulonglong>() ? qint64(v.toULongLong()) : -1;
    const QDBusArgument arg = v.value<QDBusArgument>();
    quint64 zeit = 0;
    quint32 wert = 0;
    arg.beginStructure();
    arg >> zeit >> wert;
    arg.endStructure();
    // Zeitstempel 0: seit dem Einschalten noch keine Meldung. Als Stand
    // genommen, kaeme die erste echte Meldung (Schritte seit Boot) auf
    // einen Schlag als heute gegangen dazu.
    if (zeit == 0)
        return KEIN_WERT;
    return qint64(wert);
}

void Hardwarezaehler::socketLesen()
{
    m_puffer += m_socket->readAll();
    if (!m_kennungGelesen) {
        if (m_puffer.isEmpty())
            return;
        m_puffer.remove(0, 1);   // das "\n" des Servers
        m_kennungGelesen = true;
    }
    // Rahmen: uint32 Anzahl, dann je 16 Byte {u64 Zeit, u32 Wert, 4 Fuell}.
    qint64 letzter = -1;
    while (m_puffer.size() >= 4) {
        quint32 n = 0;
        std::memcpy(&n, m_puffer.constData(), 4);
        if (n == 0 || n > 1000) {
            // Nicht das erwartete Format: verwerfen und den Stand ueber
            // D-Bus holen.
            m_puffer.clear();
            letzter = lesen();
            break;
        }
        const int laenge = 4 + int(n) * 16;
        if (m_puffer.size() < laenge)
            break;
        const char *rahmen = m_puffer.constData() + 4 + (int(n) - 1) * 16;
        quint64 zeit = 0;
        quint32 wert = 0;
        std::memcpy(&zeit, rahmen, 8);
        std::memcpy(&wert, rahmen + 8, 4);
        if (zeit != 0)
            letzter = wert;
        m_puffer.remove(0, laenge);
    }
    if (letzter >= 0)
        emit stand(letzter);
}

void Hardwarezaehler::socketWeg()
{
    std::fprintf(stderr, "wzf-schritte: Verbindung zu sensorfwd verloren\n");
    m_sitzung = -1;
    if (m_socket) {
        m_socket->deleteLater();
        m_socket = 0;
    }
    emit verloren();
}
