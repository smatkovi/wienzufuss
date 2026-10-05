// Wien zu Fuss fuer MeeGo Harmattan (Nokia N9/N950).
//
// Die Oberflaeche ist QML 1 mit den Harmattan-Komponenten. Ins Netz geht
// alles ueber wzf-dienst (Rust, eigenes OpenSSL -- das Qt 4.7 des Geraets
// kann kein TLS 1.2), gezaehlt wird von wzf-schritte im Hintergrund. Beide
// erreicht QML ueber Kontexteigenschaften: "Dienst" (src/Dienst.h) und
// "Schritte" (src/Schrittzaehler.h).

#include <QApplication>
#include <QDeclarativeContext>
#include <QDeclarativeEngine>
#include <QDeclarativeView>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QInputContext>
#include <QInputContextFactory>
#include <QStringList>

#include <QtDeclarative>

#include "src/Dienst.h"
#include "src/Schrittzaehler.h"
#include "src/Sucher.h"

// Harmattan schreibt die Adresse des Sitzungsbusses hierhin. Ein per ssh
// gestarteter Prozess erbt sie nicht -- ohne sie erreicht die App weder den
// Schrittdienst noch Browser oder Mail.
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

int main(int argc, char *argv[])
{
    sitzungsBusSetzen();
    // GStreamer fuer den QR-Sucher (src/Sucher.h). Scheitert es, faellt nur
    // der Sucher aus; die Seite sagt dann, dass nach dem PIN zu fragen ist.
    gst_init(&argc, &argv);
    QApplication app(argc, argv);

    // Ohne das bleibt die virtuelle Tastatur weg, sobald die ausziehbare
    // eingeklappt ist (N950): eine nackte QApplication waehlt keinen
    // Eingabekontext.
    if (QInputContext *ic = QInputContextFactory::create(QLatin1String("MInputContext"), &app))
        app.setInputContext(ic);

    app.setApplicationName(QLatin1String("wienzufuss"));
    app.setOrganizationName(QLatin1String("wienzufuss"));

    // Alles relativ zum Programm: /opt/wienzufuss/bin/wienzufuss -> /opt/wienzufuss
    const QString wurzel = QDir(QFileInfo(QCoreApplication::applicationFilePath())
                                .absolutePath() + QLatin1String("/..")).absolutePath();

    // Der Sucher zeichnet selbst, also ein QML-Element, keine Eigenschaft.
    qmlRegisterType<Sucher>("WienZuFuss", 1, 0, "Sucher");

    Dienst dienst(wurzel + QLatin1String("/bin/wzf-dienst"));
    Schrittzaehler schritte;

    QDeclarativeView view;
    view.engine()->rootContext()->setContextProperty(QLatin1String("Dienst"), &dienst);
    view.engine()->rootContext()->setContextProperty(QLatin1String("Schritte"), &schritte);
    // Zum Probieren am Geraet: WZF_START=QrScanSeite.qml oeffnet diese Seite
    // gleich nach dem Start.
    view.engine()->rootContext()->setContextProperty(QLatin1String("startSeite"),
                                                     QString::fromLocal8Bit(qgetenv("WZF_START")));
    view.setResizeMode(QDeclarativeView::SizeRootObjectToView);
    view.setSource(QUrl::fromLocalFile(wurzel + QLatin1String("/qml/main.qml")));
    view.showFullScreen();
    return app.exec();
}
