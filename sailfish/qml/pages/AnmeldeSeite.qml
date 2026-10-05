import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Anmelden mit E-Mail und Passwort (Firebase, wie die Android-App).
// Gespeichert wird nur das Token, nie das Passwort.
Page {
    id: seite
    property bool istAnmeldung: true
    property string hinweis: ""
    backNavigation: fenster.angemeldet

    Anfrage {
        id: anmeldung
        onFertig: {
            passwort.text = ""
            fenster.angemeldet = true
            fenster.nutzer = daten.nutzer ? daten.nutzer : null
            Schritte.aktualisieren()
            if (daten.profilFehlt)
                pageStack.replace(Qt.resolvedUrl("ProfilSeite.qml"), { modus: "anlegen" })
            else
                pageStack.pop()
            if (daten.fehler)
                fenster.meldung(W.fehlerText(daten.fehler))
        }
        onFehler: seite.hinweis = W.fehlerText(text)
    }
    Anfrage {
        id: vergessen
        onFertig: seite.hinweis = "Wenn es zu dieser Adresse ein Konto gibt, kommt gleich eine E-Mail zum Zurücksetzen des Passworts."
        onFehler: seite.hinweis = W.fehlerText(text)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        PullDownMenu {
            busy: anmeldung.laeuft || vergessen.laeuft
            MenuItem {
                text: "Neues Konto anlegen"
                onClicked: pageStack.push(Qt.resolvedUrl("ProfilSeite.qml"), { modus: "registrieren", email: email.text })
            }
            MenuItem {
                text: "Passwort vergessen"
                enabled: email.text !== ""
                onClicked: { seite.hinweis = ""; vergessen.senden("passwort_vergessen", { email: email.text }) }
            }
        }

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingMedium
            PageHeader { title: "Anmelden"; description: "Wien zu Fuß" }
            Hinweis {
                color: Theme.secondaryHighlightColor
                text: "Mit dem Konto aus der Wien-zu-Fuß-App anmelden. Die Schritte zählt dieses Telefon, "
                      + "übertragen werden sie erst, wenn du das in den Einstellungen einschaltest."
            }
            TextField {
                id: email
                width: parent.width
                label: "E-Mail"
                placeholderText: label
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                EnterKey.iconSource: "image://theme/icon-m-enter-next"
                EnterKey.onClicked: passwort.focus = true
            }
            PasswordField {
                id: passwort
                width: parent.width
                EnterKey.enabled: email.text !== "" && text !== ""
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: knopf.clicked(null)
            }
            Button {
                id: knopf
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Anmelden"
                enabled: email.text !== "" && passwort.text !== "" && !anmeldung.laeuft
                onClicked: {
                    seite.hinweis = ""
                    anmeldung.senden("anmelden", { email: email.text, passwort: passwort.text })
                }
            }
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: anmeldung.laeuft || vergessen.laeuft
                visible: running
                size: BusyIndicatorSize.Medium
            }
            Hinweis { text: seite.hinweis }
            Hinweis {
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeExtraSmall
                text: "Konten, die in der Android- oder iPhone-App mit Google, Facebook oder Apple angelegt wurden, "
                      + "lassen sich hier nicht anmelden – nur Konten mit E-Mail und Passwort. Neues Konto und "
                      + "„Passwort vergessen“ im Menü oben."
            }
        }
    }
}
