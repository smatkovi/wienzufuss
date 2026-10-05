// Probelauf der N9-Oberflaeche am Rechner, ohne Telefon und ohne Fenster.
//
// Laedt meego/qml/main.qml in Qt 4.8 (X11-Bau aus dem QtSDK) mit den
// Desktop-Harmattan-Komponenten, haengt den echten Netzdienst (am Rechner
// gebaut, mit WZF_ATTRAPPE=1: feste Beispieldaten statt Server) als
// "Dienst" an und einen Ersatz fuer den Schrittdienst als "Schritte".
// Dann arbeitet es eine Liste von Schritten ab:
//
//   warte:MS        Ereignisschleife MS Millisekunden laufen lassen
//   js:AUSDRUCK     im Kontext von main.qml auswerten (ids sind sichtbar)
//   bild:DATEI.png  das Fenster als Bild ablegen
//
// Uebernommen aus regiojet-meego (tools/probe), gestartet von tools/probe.sh.

#include <QApplication>
#include <QDate>
#include <QDeclarativeContext>
#include <QDeclarativeEngine>
#include <QDeclarativeExpression>
#include <QDeclarativeItem>
#include <QDeclarativeView>
#include <QEventLoop>
#include <QPixmap>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <cstdio>

#include "src/Dienst.h"

// Steht statt des Schrittdienstes da: eine Woche Beispielschritte.
class ErsatzSchritte : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString stand READ stand NOTIFY geaendert)
    Q_PROPERTY(bool erreichbar READ erreichbar NOTIFY geaendert)
    Q_PROPERTY(bool aktiv READ aktiv WRITE setAktiv NOTIFY geaendert)
public:
    QString stand() const
    {
        const QDate h = QDate::currentDate();
        const int werte[7] = { 9120, 4310, 11250, 7020, 8640, 2010, 5120 };
        QString tage;
        for (int i = 0; i < 7; ++i) {
            if (i)
                tage += QLatin1Char(',');
            tage += QString::fromLatin1("\"%1\":%2").arg(h.addDays(i - 6).toString(Qt::ISODate)).arg(werte[i]);
        }
        return QString::fromLatin1("{\"heute\":\"%1\",\"schritteHeute\":5120,\"geht\":true,"
                                   "\"quelle\":\"beschleunigung\",\"hinweis\":\"\",\"tage\":{%2}}")
                .arg(h.toString(Qt::ISODate), tage);
    }
    bool erreichbar() const { return true; }
    bool aktiv() const { return true; }
    void setAktiv(bool) {}
    Q_INVOKABLE void aktualisieren() {}
    Q_INVOKABLE void neuladen() {}
signals:
    void geaendert();
};

static void warten(int ms)
{
    QEventLoop schleife;
    QTimer::singleShot(ms, &schleife, SLOT(quit()));
    schleife.exec();
}

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    const QStringList args = app.arguments();
    if (args.size() < 3) {
        std::fprintf(stderr, "probe DIENST MAIN.QML [schritte...]\n");
        return 2;
    }
    Dienst dienst(args.at(1));
    ErsatzSchritte schritte;
    QDeclarativeView view;
    view.setAttribute(Qt::WA_DontShowOnScreen);
    view.engine()->rootContext()->setContextProperty(QLatin1String("Dienst"), &dienst);
    view.engine()->rootContext()->setContextProperty(QLatin1String("Schritte"), &schritte);
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.resize(480, 854);
    view.setSource(QUrl::fromLocalFile(args.at(2)));
    view.show();
    warten(800);
    if (!view.errors().isEmpty() || !view.rootObject()) {
        for (int i = 0; i < view.errors().size(); ++i)
            std::fprintf(stderr, "probe: QML-Fehler: %s\n", qPrintable(view.errors().at(i).toString()));
        return 1;
    }
    QDeclarativeContext *kontext = QDeclarativeEngine::contextForObject(view.rootObject());

    for (int i = 3; i < args.size(); ++i) {
        const QString s = args.at(i);
        if (s.startsWith(QLatin1String("warte:"))) {
            warten(s.mid(6).toInt());
        } else if (s.startsWith(QLatin1String("js:"))) {
            QDeclarativeExpression ausdruck(kontext, view.rootObject(), s.mid(3));
            const QVariant wert = ausdruck.evaluate();
            if (ausdruck.hasError())
                std::fprintf(stderr, "probe: js-Fehler: %s\n", qPrintable(ausdruck.error().toString()));
            else if (wert.isValid())
                std::printf("probe: %s => %s\n", qPrintable(s.mid(3, 60)), qPrintable(wert.toString()));
            warten(50);
        } else if (s.startsWith(QLatin1String("bild:"))) {
            warten(100);
            QPixmap::grabWidget(&view).save(s.mid(5));
            std::printf("probe: Bild %s\n", qPrintable(s.mid(5)));
        }
    }
    return 0;
}

#include "probe.moc"
