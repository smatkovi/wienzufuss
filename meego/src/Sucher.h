#ifndef SUCHER_H
#define SUCHER_H

// Ein Sucherbild am N9 und N950 -- und darin gelesen wird gleich mit.
// Uebernommen aus dem Briar-Port (meego/sucher.h), dort am N9 erprobt; hier
// meldet er Text statt Hex.
//
// Das QML-Element aus QtMultimediaKit faellt auf diesen Geraeten aus: sein
// Unterbau "camerabin" kommt nicht ueber PAUSED hinaus. Die Kamera selbst
// liefert aber -- ueber subdevsrc2 unmittelbar, ohne camerabin (am N9
// nachgemessen: UYVY 640x480, Puffer kommen, kein Fehler).
//
// UYVY ist gepacktes 4:2:2 (U Y0 V Y1 ...): die Helligkeit steht auf jeder
// ungeraden Stelle. quirc will genau ein Graustufenfeld -- also nur jedes
// zweite Byte, ohne Farbumrechnung und Skalieren. Dasselbe Feld ist das
// Sucherbild; grau reicht zum Zielen.
//
// Gelesen wird im Faden von GStreamer, nicht im Oberflaechenfaden: quirc
// braucht auf einem 1-GHz-A8 seine Zeit. Der appsink laesst alte Rahmen
// fallen (max-buffers=1, drop=true), das bremst sich von selbst ein.

#include <QDeclarativeItem>
#include <QImage>
#include <QMutex>
#include <QMutexLocker>
#include <QPainter>
#include <QString>
#include <QVector>

#include <gst/gst.h>
#include <gst/app/gstappsink.h>

#include "../../qr/QrLesen.h"

class Sucher : public QDeclarativeItem
{
    Q_OBJECT
    Q_PROPERTY(bool laeuft READ laeuft NOTIFY laeuftChanged)
    /// Um wie viel das Bild beim Zeichnen zu drehen ist: der Bildaufnehmer
    /// sitzt quer zum Schirm. quirc bekommt das ungedrehte Feld -- ein
    /// QR-Code ist in jeder Lage zu lesen.
    Q_PROPERTY(int drehung READ drehung WRITE setDrehung NOTIFY drehungChanged)

public:
    explicit Sucher(QDeclarativeItem *parent = 0)
        : QDeclarativeItem(parent), m_pipeline(0), m_sink(0), m_drehung(90), m_gefunden(false)
    {
        setFlag(QGraphicsItem::ItemHasNoContents, false);
    }
    ~Sucher() { anhalten(); }

    bool laeuft() const { return m_pipeline != 0; }
    int drehung() const { return m_drehung; }
    void setDrehung(int grad)
    {
        if (m_drehung == grad)
            return;
        m_drehung = grad;
        emit drehungChanged();
        update();
    }

    /// Die Kamera anwerfen. false, wenn die Kette nicht steht.
    Q_INVOKABLE bool starten()
    {
        if (m_pipeline)
            return true;
        m_gefunden = false;
        GError *fehler = 0;
        // 640x480 ist ausgehandelt, nicht geraten: kleiner waere billiger,
        // aber ein Code auf einem Bildschirm braucht die Punkte.
        m_pipeline = gst_parse_launch(
            "subdevsrc2 ! video/x-raw-yuv,format=(fourcc)UYVY,width=640,height=480 ! appsink name=aus", &fehler);
        if (!m_pipeline) {
            if (fehler) {
                qWarning("Sucher: Kette nicht zu bauen: %s", fehler->message);
                g_error_free(fehler);
            }
            return false;
        }
        if (fehler)
            g_error_free(fehler);
        m_sink = gst_bin_get_by_name(GST_BIN(m_pipeline), "aus");
        if (!m_sink) {
            anhalten();
            return false;
        }
        g_object_set(G_OBJECT(m_sink), "emit-signals", TRUE, "sync", FALSE,
                     "max-buffers", 1, "drop", TRUE, NULL);
        g_signal_connect(m_sink, "new-buffer", G_CALLBACK(rahmenAngekommen), this);
        if (gst_element_set_state(m_pipeline, GST_STATE_PLAYING) == GST_STATE_CHANGE_FAILURE) {
            qWarning("Sucher: die Kette laeuft nicht an");
            anhalten();
            return false;
        }
        emit laeuftChanged();
        return true;
    }

    /// Nach einem Fund, der nichts taugte, weiterlesen.
    Q_INVOKABLE void weitersuchen() { m_gefunden = false; }

    Q_INVOKABLE void anhalten()
    {
        if (m_sink) {
            g_signal_handlers_disconnect_by_func(m_sink, (gpointer)G_CALLBACK(rahmenAngekommen), this);
            gst_object_unref(m_sink);
            m_sink = 0;
        }
        if (m_pipeline) {
            gst_element_set_state(m_pipeline, GST_STATE_NULL);
            gst_object_unref(m_pipeline);
            m_pipeline = 0;
            emit laeuftChanged();
        }
        QMutexLocker sperre(&m_sperre);
        m_bild = QImage();
    }

    void paint(QPainter *maler, const QStyleOptionGraphicsItem *, QWidget *)
    {
        QImage bild;
        {
            QMutexLocker sperre(&m_sperre);
            bild = m_bild;
        }
        const QRectF ziel = boundingRect();
        maler->fillRect(ziel, Qt::black);
        if (bild.isNull())
            return;
        // Wie die Android-App: das Kamerabild fuellt die Flaeche (randlos,
        // ueberstehendes wird abgeschnitten). Nach einer Vierteldrehung sind
        // Breite und Hoehe vertauscht.
        QSizeF quelle = QSizeF(bild.size());
        const bool quer = (m_drehung % 180) != 0;
        if (quer)
            quelle.transpose();
        QSizeF passend = quelle;
        passend.scale(ziel.size(), Qt::KeepAspectRatioByExpanding);
        maler->save();
        maler->setClipRect(ziel);
        maler->translate(ziel.center());
        maler->rotate(m_drehung);
        const QSizeF innen = quer ? QSizeF(passend.height(), passend.width()) : passend;
        maler->drawImage(QRectF(-innen.width() / 2, -innen.height() / 2, innen.width(), innen.height()), bild);
        maler->restore();
    }

signals:
    /// Ein Code ist gelesen worden, als Text.
    void gelesen(const QString &text);
    void laeuftChanged();
    void drehungChanged();

private slots:
    void neuZeichnen() { update(); }
    void fundMelden(const QString &text)
    {
        if (m_gefunden)
            return;
        m_gefunden = true;
        emit gelesen(text);
    }

private:
    /// Im Faden von GStreamer: Helligkeitsfeld herausgreifen und lesen.
    static void rahmenAngekommen(GstAppSink *sink, gpointer daten)
    {
        Sucher *selbst = static_cast<Sucher *>(daten);
        GstBuffer *puffer = gst_app_sink_pull_buffer(sink);
        if (!puffer)
            return;
        int breite = 0, hoehe = 0;
        GstCaps *caps = gst_buffer_get_caps(puffer);
        if (caps) {
            GstStructure *bau = gst_caps_get_structure(caps, 0);
            if (bau) {
                gst_structure_get_int(bau, "width", &breite);
                gst_structure_get_int(bau, "height", &hoehe);
            }
            gst_caps_unref(caps);
        }
        const guint8 *roh = GST_BUFFER_DATA(puffer);
        const guint groesse = GST_BUFFER_SIZE(puffer);
        if (breite <= 0 || hoehe <= 0 || groesse < (guint)(breite * hoehe * 2)) {
            gst_buffer_unref(puffer);
            return;
        }
        QImage grau(breite, hoehe, QImage::Format_Indexed8);
        grau.setColorTable(graustufen());
        for (int y = 0; y < hoehe; ++y) {
            const guint8 *zeile = roh + (guint)y * (guint)breite * 2;
            uchar *hin = grau.scanLine(y);
            for (int x = 0; x < breite; ++x)
                hin[x] = zeile[x * 2 + 1];
        }
        gst_buffer_unref(puffer);
        {
            QMutexLocker sperre(&selbst->m_sperre);
            selbst->m_bild = grau;
        }
        QMetaObject::invokeMethod(selbst, "neuZeichnen", Qt::QueuedConnection);

        if (selbst->m_gefunden)
            return;
        const QString text = QrLesen::alsText(QrLesen::ausBild(grau));
        if (text.isEmpty())
            return;
        QMetaObject::invokeMethod(selbst, "fundMelden", Qt::QueuedConnection, Q_ARG(QString, text));
    }

    static const QVector<QRgb> &graustufen()
    {
        static QVector<QRgb> tafel;
        if (tafel.isEmpty()) {
            tafel.resize(256);
            for (int i = 0; i < 256; ++i)
                tafel[i] = qRgb(i, i, i);
        }
        return tafel;
    }

    GstElement *m_pipeline;
    GstElement *m_sink;
    QImage m_bild;
    QMutex m_sperre;
    int m_drehung;
    volatile bool m_gefunden;
};

#endif
