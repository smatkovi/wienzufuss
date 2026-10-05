#include "Schrittzaehler.h"

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QTimer>

#include <cstdio>

static const char *NAME = "org.smatkovi.WienZuFuss.Schritte";

Schrittzaehler::Schrittzaehler(QObject *parent)
    : QObject(parent), m_erreichbar(false), m_aktiv(true), m_laeuft(false)
{
    m_takt = new QTimer(this);
    m_takt->setInterval(4000);
    connect(m_takt, SIGNAL(timeout()), this, SLOT(aktualisieren()));
    m_takt->start();
    QDBusConnection::sessionBus().connect(QLatin1String(NAME), QLatin1String("/"), QLatin1String(NAME),
                                          QLatin1String("Geaendert"), this, SLOT(signalGeaendert(int)));
    aktualisieren();
}

void Schrittzaehler::setAktiv(bool a)
{
    if (a == m_aktiv)
        return;
    m_aktiv = a;
    if (a) {
        m_takt->start();
        aktualisieren();
    } else {
        m_takt->stop();
    }
    emit aktivChanged();
}

void Schrittzaehler::rufen(const char *methode, bool mitAntwort)
{
    QDBusMessage m = QDBusMessage::createMethodCall(QLatin1String(NAME), QLatin1String("/"),
                                                    QLatin1String(NAME), QLatin1String(methode));
    QDBusPendingCall p = QDBusConnection::sessionBus().asyncCall(m, 25000);
    if (mitAntwort) {
        m_laeuft = true;
        QDBusPendingCallWatcher *w = new QDBusPendingCallWatcher(p, this);
        connect(w, SIGNAL(finished(QDBusPendingCallWatcher*)), this, SLOT(antwort(QDBusPendingCallWatcher*)));
    }
}

void Schrittzaehler::aktualisieren()
{
    // Eine Anfrage zur Zeit: haengt der Dienst (er wird gerade gestartet),
    // stapeln sich sonst die Aufrufe.
    if (m_laeuft)
        return;
    rufen("Stand", true);
}

void Schrittzaehler::neuladen()
{
    rufen("Neuladen", false);
    QTimer::singleShot(500, this, SLOT(aktualisieren()));
}

void Schrittzaehler::antwort(QDBusPendingCallWatcher *w)
{
    m_laeuft = false;
    QDBusPendingReply<QString> r = *w;
    w->deleteLater();
    if (r.isError()) {
        if (m_erreichbar)
            std::fprintf(stderr, "schritte: %s\n", r.error().message().toUtf8().constData());
        if (m_erreichbar) {
            m_erreichbar = false;
            emit geaendert();
        }
        return;
    }
    const QString neu = r.value();
    if (neu != m_stand || !m_erreichbar) {
        m_stand = neu;
        m_erreichbar = true;
        emit geaendert();
    }
}

void Schrittzaehler::signalGeaendert(int)
{
    if (m_aktiv)
        aktualisieren();
}
