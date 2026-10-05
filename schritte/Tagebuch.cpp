#include "Tagebuch.h"

#include <QDate>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegExp>
#include <QStringList>

#include <cstdio>
#include <unistd.h>

// Wie viele Tage die Datei behaelt. Hochgeladen werden hoechstens die
// letzten 14; der Rest ist fuer den Verlauf in der App.
static const int BEHALTEN = 120;

QString jetztText()
{
    return QDateTime::currentDateTime().toString(QLatin1String("yyyy-MM-dd hh:mm:ss"));
}

QString bootId()
{
    QFile f(QLatin1String("/proc/sys/kernel/random/boot_id"));
    if (!f.open(QIODevice::ReadOnly))
        return QString();
    return QString::fromLatin1(f.readAll()).trimmed();
}

static QString zeichenkette(const QString &s)
{
    QString t = s;
    t.replace(QLatin1String("\\"), QLatin1String("\\\\"));
    t.replace(QLatin1String("\""), QLatin1String("\\\""));
    t.replace(QLatin1String("\n"), QLatin1String("\\n"));
    t.replace(QLatin1String("\r"), QString());
    t.replace(QLatin1String("\t"), QLatin1String(" "));
    return QLatin1String("\"") + t + QLatin1String("\"");
}

static QString textFeld(const QString &json, const char *name)
{
    QRegExp re(QLatin1String("\"") + QLatin1String(name) + QLatin1String("\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""));
    if (re.indexIn(json) < 0)
        return QString();
    QString w = re.cap(1);
    w.replace(QLatin1String("\\n"), QLatin1String("\n"));
    w.replace(QLatin1String("\\\""), QLatin1String("\""));
    w.replace(QLatin1String("\\\\"), QLatin1String("\\"));
    return w;
}

Tagebuch::Tagebuch(const QString &datei)
    : hwLetzter(-1), m_datei(datei)
{
}

void Tagebuch::laden()
{
    QFile f(m_datei);
    if (!f.open(QIODevice::ReadOnly))
        return;
    const QString json = QString::fromUtf8(f.readAll());
    m_tage.clear();
    const int tageAb = json.indexOf(QLatin1String("\"tage\""));
    if (tageAb >= 0) {
        const int auf = json.indexOf(QLatin1Char('{'), tageAb);
        const int zu = json.indexOf(QLatin1Char('}'), auf);
        if (auf >= 0 && zu > auf) {
            const QString block = json.mid(auf, zu - auf);
            QRegExp re(QLatin1String("\"(\\d{4}-\\d{2}-\\d{2})\"\\s*:\\s*(\\d+)"));
            int pos = 0;
            while ((pos = re.indexIn(block, pos)) >= 0) {
                m_tage.insert(re.cap(1), re.cap(2).toInt());
                pos += re.matchedLength();
            }
        }
    }
    quelle = textFeld(json, "quelle");
    hinweis = textFeld(json, "hinweis");
    hwBoot = textFeld(json, "boot");
    QRegExp letzter(QLatin1String("\"letzter\"\\s*:\\s*(-?\\d+)"));
    hwLetzter = letzter.indexIn(json) >= 0 ? letzter.cap(1).toLongLong() : -1;
    // Bis 0.2.1 konnte ein noch stummer Hardware-Zaehler den Stand 0
    // hinterlassen; die erste echte Meldung haette dann alle Schritte seit
    // Boot auf heute gebucht. Einen solchen Stand verwerfen.
    QRegExp version(QLatin1String("\"version\"\\s*:\\s*(\\d+)"));
    if ((version.indexIn(json) < 0 || version.cap(1).toInt() < 2) && hwLetzter == 0)
        hwLetzter = -1;
}

void Tagebuch::kuerzen()
{
    const QString grenze = QDate::currentDate().addDays(-BEHALTEN).toString(Qt::ISODate);
    QMap<QString, int>::iterator it = m_tage.begin();
    while (it != m_tage.end()) {
        if (it.key() < grenze || it.value() <= 0)
            it = m_tage.erase(it);
        else
            ++it;
    }
}

QString Tagebuch::heuteDatum() const
{
    return QDate::currentDate().toString(Qt::ISODate);
}

void Tagebuch::hinzu(int n)
{
    if (n <= 0)
        return;
    const QString d = heuteDatum();
    m_tage[d] = m_tage.value(d) + n;
}

int Tagebuch::heute() const
{
    return m_tage.value(heuteDatum());
}

bool Tagebuch::sichern()
{
    kuerzen();
    QString aus = QLatin1String("{\"version\":2,\"quelle\":") + zeichenkette(quelle)
            + QLatin1String(",\"hinweis\":") + zeichenkette(hinweis)
            + QLatin1String(",\"stand\":") + zeichenkette(jetztText())
            + QLatin1String(",\"hw\":{\"letzter\":") + QString::number(hwLetzter)
            + QLatin1String(",\"boot\":") + zeichenkette(hwBoot)
            + QLatin1String("},\"tage\":{");
    bool erster = true;
    for (QMap<QString, int>::const_iterator it = m_tage.constBegin(); it != m_tage.constEnd(); ++it) {
        if (!erster)
            aus += QLatin1Char(',');
        erster = false;
        aus += zeichenkette(it.key()) + QLatin1Char(':') + QString::number(it.value());
    }
    aus += QLatin1String("}}\n");

    QDir().mkpath(QFileInfo(m_datei).absolutePath());
    const QString neben = m_datei + QLatin1String(".neu");
    QFile f(neben);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    const QByteArray daten = aus.toUtf8();
    if (f.write(daten) != daten.size()) {
        f.close();
        return false;
    }
    f.flush();
    ::fsync(f.handle());
    f.close();
    // rename() ersetzt atomar; QFile::rename weigert sich, wenn das Ziel
    // existiert.
    return ::rename(QFile::encodeName(neben).constData(), QFile::encodeName(m_datei).constData()) == 0;
}

QString Tagebuch::json(bool geht) const
{
    QString aus = QLatin1String("{\"heute\":") + zeichenkette(heuteDatum())
            + QLatin1String(",\"schritteHeute\":") + QString::number(heute())
            + QLatin1String(",\"geht\":") + QLatin1String(geht ? "true" : "false")
            + QLatin1String(",\"quelle\":") + zeichenkette(quelle)
            + QLatin1String(",\"hinweis\":") + zeichenkette(hinweis)
            + QLatin1String(",\"tage\":{");
    bool erster = true;
    // Nur die letzten 31 Tage: das reicht fuer den Verlauf in der App.
    const QString ab = QDate::currentDate().addDays(-31).toString(Qt::ISODate);
    for (QMap<QString, int>::const_iterator it = m_tage.constBegin(); it != m_tage.constEnd(); ++it) {
        if (it.key() < ab)
            continue;
        if (!erster)
            aus += QLatin1Char(',');
        erster = false;
        aus += zeichenkette(it.key()) + QLatin1Char(':') + QString::number(it.value());
    }
    aus += QLatin1String("}}");
    return aus;
}
