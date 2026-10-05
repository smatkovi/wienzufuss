// Wien zu Fuss fuer Sailfish OS.
//
// Silica-Oberflaeche; ins Netz geht alles ueber wzf-dienst (derselbe
// Rust-Dienst wie am N9, statisch gebaut), gezaehlt wird von wzf-schritte
// (systemd-Benutzerdienst). Beide erreicht QML ueber Kontexteigenschaften:
// "Dienst" und "Schritte" -- dieselben Klassen wie am N9 (meego/src).

#include <QGuiApplication>
#include <QQmlContext>
#include <QQuickView>
#include <QScopedPointer>

#include <sailfishapp.h>

#include "Dienst.h"
#include "QrLeser.h"
#include "Schrittzaehler.h"

int main(int argc, char *argv[])
{
    QScopedPointer<QGuiApplication> app(SailfishApp::application(argc, argv));
    app->setOrganizationName(QStringLiteral("wienzufuss"));
    app->setApplicationName(QStringLiteral("wienzufuss"));
    app->setApplicationVersion(QStringLiteral(APP_VERSION));

    Dienst dienst(QStringLiteral(NETZDIENST));
    Schrittzaehler schritte;
    QrLeser qrLeser;

    QScopedPointer<QQuickView> view(SailfishApp::createView());
    QQmlContext *ctx = view->rootContext();
    ctx->setContextProperty(QStringLiteral("Dienst"), &dienst);
    ctx->setContextProperty(QStringLiteral("Schritte"), &schritte);
    ctx->setContextProperty(QStringLiteral("QrLeser"), &qrLeser);
    ctx->setContextProperty(QStringLiteral("appVersion"), QStringLiteral(APP_VERSION));
    view->setSource(SailfishApp::pathTo(QStringLiteral("qml/wienzufuss.qml")));
    view->show();
    return app->exec();
}
