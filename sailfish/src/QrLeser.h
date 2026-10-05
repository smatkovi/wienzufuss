#ifndef QRLESER_H
#define QRLESER_H

// Liest ein Foto der Kamera in einem Arbeitsfaden (quirc, qr/QrLesen.h) und
// meldet den Text per Signal. Aus dem Briar-Port (src/qrleser.h): liefe quirc
// im Oberflaechenfaden, stuende der Sucher still und der Autofokus kaeme nicht
// zur Ruhe. Qt am Ziel ist 5.6 -- deshalb QtConcurrent::run mit einer
// statischen Funktion.

#include <QFile>
#include <QFutureWatcher>
#include <QObject>
#include <QString>
#include <QtConcurrent/QtConcurrentRun>

#include "QrLesen.h"

class QrLeser : public QObject
{
    Q_OBJECT
public:
    explicit QrLeser(QObject *parent = 0) : QObject(parent)
    {
        connect(&m_wache, SIGNAL(finished()), this, SLOT(fertigGeworden()));
    }

    /// Ein Foto zum Lesen geben. false, wenn schon eines im Leser liegt --
    /// dann ist die Datei gleich weggeraeumt, sonst liefe der
    /// Zwischenspeicher voll.
    Q_INVOKABLE bool lesen(const QString &datei)
    {
        QString pfad = datei;
        if (pfad.startsWith(QLatin1String("file://")))
            pfad = pfad.mid(7);
        if (m_wache.isRunning()) {
            QFile::remove(pfad);
            return false;
        }
        m_wache.setFuture(QtConcurrent::run(&QrLeser::arbeiten, pfad));
        return true;
    }

signals:
    /// Leer heisst: in dem Bild stand kein Code.
    void fertig(const QString &text);

private slots:
    void fertigGeworden() { emit fertig(m_wache.result()); }

private:
    static QString arbeiten(const QString &pfad)
    {
        const QString text = QrLesen::alsText(QrLesen::ausDatei(pfad));
        QFile::remove(pfad);
        return text;
    }

    QFutureWatcher<QString> m_wache;
};

#endif
