#include "Schrittdienst.h"

#include <QDate>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QRegExp>
#include <QStringList>
#include <QTimer>

#include <cstdio>
#include <cstdlib>

Einstellungen::Einstellungen()
    : zaehlen(true), beschleunigung(false), empfindlichkeit(3), hochladen(false)
{
}

bool Einstellungen::operator==(const Einstellungen &o) const
{
    return zaehlen == o.zaehlen && beschleunigung == o.beschleunigung
            && empfindlichkeit == o.empfindlichkeit && hochladen == o.hochladen;
}

static bool wahr(const QString &json, const char *name, bool vorgabe)
{
    QRegExp re(QLatin1String("\"") + QLatin1String(name) + QLatin1String("\"\\s*:\\s*(true|false)"));
    if (re.indexIn(json) < 0)
        return vorgabe;
    return re.cap(1) == QLatin1String("true");
}

static int ganz(const QString &json, const char *name, int vorgabe)
{
    QRegExp re(QLatin1String("\"") + QLatin1String(name) + QLatin1String("\"\\s*:\\s*(-?\\d+)"));
    if (re.indexIn(json) < 0)
        return vorgabe;
    return re.cap(1).toInt();
}

QString Schrittdienst::heim()
{
    const QByteArray h = qgetenv("HOME");
    return h.isEmpty() ? QString::fromLatin1("/home/user") : QString::fromLocal8Bit(h);
}

Schrittdienst::Schrittdienst(const QString &netzdienst, QObject *parent)
    : QObject(parent),
      m_buch(heim() + QLatin1String("/.local/share/wienzufuss/schritte.json")),
      m_netzdienst(netzdienst),
      m_einstDatei(heim() + QLatin1String("/.config/wienzufuss/einstellungen.json")),
      m_geaendert(false),
      m_geht(false),
      m_seitUpload(true)
{
    m_buch.laden();
    m_letzterTag = m_buch.heuteDatum();
    m_uploadTag = m_letzterTag;
    einstellungenLesen(false);

    // Alle 20 s: Tageswechsel, Einstellungen, auf die Platte, wenn noetig.
    m_takt = new QTimer(this);
    m_takt->setInterval(20000);
    connect(m_takt, SIGNAL(timeout()), this, SLOT(zeitgeber()));
    m_takt->start();

    // Stuendlich hochladen, falls erlaubt und sich etwas getan hat. Der
    // erste Versuch zehn Minuten nach dem Start, nicht sofort: nach dem
    // Booten ist das Netz oft noch nicht da.
    m_upload = new QTimer(this);
    m_upload->setInterval(60 * 60 * 1000);
    connect(m_upload, SIGNAL(timeout()), this, SLOT(hochladenPruefen()));
    m_upload->start();
    QTimer::singleShot(10 * 60 * 1000, this, SLOT(hochladenPruefen()));
}

void Schrittdienst::einstellungenLesen(bool melden)
{
    QFileInfo info(m_einstDatei);
    const QDateTime stand = info.exists() ? info.lastModified() : QDateTime();
    if (melden && stand == m_einstStand)
        return;
    m_einstStand = stand;
    Einstellungen neu;
    QFile f(m_einstDatei);
    if (f.open(QIODevice::ReadOnly)) {
        const QString json = QString::fromUtf8(f.readAll());
        neu.zaehlen = wahr(json, "zaehlen", true);
        neu.beschleunigung = wahr(json, "beschleunigung", false);
        neu.empfindlichkeit = ganz(json, "empfindlichkeit", 3);
        neu.hochladen = wahr(json, "hochladen", false);
    }
    const bool anders = neu != m_einst;
    m_einst = neu;
    if (melden && anders) {
        std::fprintf(stderr, "wzf-schritte: Einstellungen: zaehlen=%d beschleunigung=%d empfindlichkeit=%d hochladen=%d\n",
                     m_einst.zaehlen, m_einst.beschleunigung, m_einst.empfindlichkeit, m_einst.hochladen);
        emit einstellungenGeaendert();
    }
}

void Schrittdienst::schritte(int n)
{
    if (n <= 0)
        return;
    m_buch.hinzu(n);
    m_geaendert = true;
    m_seitUpload = true;
    emit Geaendert(m_buch.heute());
}

void Schrittdienst::zaehlerstand(qint64 stand)
{
    if (stand < 0)
        return;
    const QString boot = bootId();
    qint64 neu = 0;
    if (m_buch.hwLetzter < 0 || boot != m_buch.hwBoot) {
        // Erster Wert ueberhaupt: nichts nachtragen, was vor der
        // Installation gezaehlt wurde. Nach einem Neustart des Geraets
        // zaehlt der Zaehler wieder ab 0 -- alles seitdem ist neu.
        neu = (m_buch.hwLetzter < 0) ? 0 : stand;
    } else if (stand >= m_buch.hwLetzter) {
        neu = stand - m_buch.hwLetzter;
    } else {
        // Ruecklaeufig ohne Neustart (Sensordienst neu gestartet?): ab hier
        // weiterzaehlen, nichts erfinden.
        neu = 0;
    }
    // Unplausible Spruenge (mehr als 50 000 auf einmal) nicht uebernehmen.
    if (neu > 50000)
        neu = 0;
    m_buch.hwLetzter = stand;
    m_buch.hwBoot = boot;
    m_geaendert = true;
    if (neu > 0)
        schritte(int(neu));
}

void Schrittdienst::setQuelle(const QString &quelle, const QString &hinweis)
{
    if (quelle == m_buch.quelle && hinweis == m_buch.hinweis)
        return;
    std::fprintf(stderr, "wzf-schritte: Quelle %s (%s)\n", quelle.toUtf8().constData(),
                 hinweis.toUtf8().constData());
    m_buch.quelle = quelle;
    m_buch.hinweis = hinweis;
    m_geaendert = true;
    sichern(true);
}

void Schrittdienst::setGeht(bool geht)
{
    m_geht = geht;
}

void Schrittdienst::sichern(bool sofort)
{
    if (!m_geaendert)
        return;
    // Hoechstens alle 20 s auf die Platte, ausser es eilt.
    if (!sofort && m_gesichert.isValid() && m_gesichert.secsTo(QDateTime::currentDateTime()) < 20)
        return;
    if (m_buch.sichern()) {
        m_geaendert = false;
        m_gesichert = QDateTime::currentDateTime();
    } else {
        std::fprintf(stderr, "wzf-schritte: schritte.json nicht geschrieben\n");
    }
}

void Schrittdienst::zeitgeber()
{
    const QString tag = m_buch.heuteDatum();
    if (tag != m_letzterTag) {
        // Mitternacht: der neue Tag soll in der Datei stehen, auch mit 0.
        m_letzterTag = tag;
        m_geaendert = true;
        emit Geaendert(m_buch.heute());
    }
    einstellungenLesen(true);
    sichern(false);
}

void Schrittdienst::hochladenPruefen()
{
    if (!m_einst.hochladen)
        return;
    const QString tag = m_buch.heuteDatum();
    // Auch nach Mitternacht ohne neue Schritte einmal: die letzten Schritte
    // des Vortags sollen noch hinauf.
    if (!m_seitUpload && tag == m_uploadTag)
        return;
    sichern(true);
    if (!QProcess::startDetached(m_netzdienst, QStringList() << QLatin1String("sync"))) {
        std::fprintf(stderr, "wzf-schritte: %s nicht startbar\n", m_netzdienst.toUtf8().constData());
        return;
    }
    m_seitUpload = false;
    m_uploadTag = tag;
}

QString Schrittdienst::Stand()
{
    return m_buch.json(m_geht);
}

void Schrittdienst::Aktualisieren()
{
    emit aktualisierenAngefordert();
    sichern(true);
}

void Schrittdienst::Neuladen()
{
    m_einstStand = QDateTime();
    einstellungenLesen(true);
}
