#ifndef QRLESEN_H
#define QRLESEN_H

// QR-Codes lesen, mit quirc (qr/quirc, ISC-Lizenz) -- dieselbe Loesung wie
// im Briar-Port fuer N9 und Sailfish (dort src/qrcode.h), hier nur der
// lesende Teil und als Text statt als Hex: ein Gutschein-Code im Lokal ist
// Schrift, keine Bytes.
//
// C++98 und Qt 4 wie Qt 5: das N9 baut mit MADDEs GCC 4.4.

#include <QByteArray>
#include <QImage>
#include <QString>

#include <string.h>

extern "C" {
#include "quirc/quirc.h"
}

namespace QrLesen {

// Ein Graustufenfeld (Format_Indexed8, wie es der Sucher am N9 baut) oder
// ein beliebiges Bild. Gibt die rohen Bytes des ersten lesbaren Codes zurueck,
// leer, wenn keiner darin steht.
inline QByteArray ausBild(const QImage &bild)
{
    if (bild.isNull())
        return QByteArray();
    struct quirc *q = quirc_new();
    if (!q)
        return QByteArray();
    QByteArray ergebnis;
    if (quirc_resize(q, bild.width(), bild.height()) >= 0) {
        uint8_t *puffer = quirc_begin(q, 0, 0);
        if (bild.format() == QImage::Format_Indexed8) {
            for (int y = 0; y < bild.height(); ++y)
                memcpy(puffer + (size_t)y * (size_t)bild.width(), bild.scanLine(y), (size_t)bild.width());
        } else {
            const QImage rgb = bild.convertToFormat(QImage::Format_RGB32);
            for (int y = 0; y < rgb.height(); ++y) {
                const QRgb *zeile = reinterpret_cast<const QRgb *>(rgb.scanLine(y));
                uint8_t *hin = puffer + (size_t)y * (size_t)rgb.width();
                for (int x = 0; x < rgb.width(); ++x) {
                    const QRgb p = zeile[x];
                    hin[x] = (uint8_t)((qRed(p) * 77 + qGreen(p) * 151 + qBlue(p) * 28) >> 8);
                }
            }
        }
        quirc_end(q);
        const int anzahl = quirc_count(q);
        for (int i = 0; i < anzahl && ergebnis.isEmpty(); ++i) {
            struct quirc_code code;
            struct quirc_data daten;
            quirc_extract(q, i, &code);
            if (quirc_decode(&code, &daten) == QUIRC_SUCCESS)
                ergebnis = QByteArray((const char *)daten.payload, daten.payload_len);
        }
    }
    quirc_destroy(q);
    return ergebnis;
}

// Ein Foto von der Platte. Wie im Briar-Port in Stufen verkleinert, jede
// Breite nur einmal: quirc findet einen Code im Bild der Kamera oft erst bei
// einer bestimmten Groesse.
inline QByteArray ausDatei(const QString &pfad)
{
    QImage bild(pfad);
    if (bild.isNull())
        return QByteArray();
    const int stufen[3] = { 1280, 1600, 800 };
    int schon[4] = { 0, 0, 0, 0 };
    int anzahl = 0;
    for (int i = 0; i < 4; ++i) {
        const int breite = (i < 3) ? qMin(stufen[i], bild.width()) : bild.width();
        bool doppelt = false;
        for (int j = 0; j < anzahl; ++j)
            if (schon[j] == breite)
                doppelt = true;
        if (doppelt)
            continue;
        schon[anzahl++] = breite;
        const QImage stufe = breite < bild.width() ? bild.scaledToWidth(breite, Qt::SmoothTransformation) : bild;
        const QByteArray roh = ausBild(stufe);
        if (!roh.isEmpty())
            return roh;
    }
    return QByteArray();
}

// Die Bytes als Text (UTF-8), ohne Leerraum am Rand.
inline QString alsText(const QByteArray &roh)
{
    return QString::fromUtf8(roh.constData(), roh.size()).trimmed();
}

}

#endif
