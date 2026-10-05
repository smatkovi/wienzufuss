import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Anmelden mit E-Mail und Passwort (Firebase, wie die Android-App).
// Gespeichert wird nur das Token, nie das Passwort.
Page {
    id: seite
    property bool istAnmeldung: true
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon {
            iconId: "toolbar-back"
            visible: fenster.angemeldet
            onClicked: pageStack.pop()
        }
    }

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

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Anmelden"
        untertitel: "Wien zu Fuß"
        laedt: anmeldung.laeuft || vergessen.laeuft
    }

    Flickable {
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 32
        clip: true
        Column {
            id: inhalt
            x: 16
            width: parent.width - 32
            spacing: 14
            Item { width: 1; height: 8 }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#bfbfbf"
                font.pixelSize: 22
                text: "Mit dem Konto aus der Wien-zu-Fuß-App anmelden. Die Schritte zählt dieses Telefon, "
                      + "übertragen werden sie erst, wenn du das in den Einstellungen einschaltest."
            }
            TextField {
                id: email
                width: parent.width
                placeholderText: "E-Mail"
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            TextField {
                id: passwort
                width: parent.width
                placeholderText: "Passwort"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                Keys.onReturnPressed: anmeldenKnopf.clicked()
            }
            Button {
                id: anmeldenKnopf
                width: parent.width
                text: "Anmelden"
                enabled: email.text !== "" && passwort.text !== "" && !anmeldung.laeuft
                onClicked: {
                    seite.hinweis = ""
                    anmeldung.senden("anmelden", { email: email.text, passwort: passwort.text })
                }
            }
            Text {
                width: parent.width
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#e8bc2c"
                font.pixelSize: 22
                text: seite.hinweis
            }
            Item { width: 1; height: 8 }
            Button {
                width: parent.width
                text: "Passwort vergessen"
                enabled: email.text !== "" && !vergessen.laeuft
                onClicked: {
                    seite.hinweis = ""
                    vergessen.senden("passwort_vergessen", { email: email.text })
                }
            }
            Button {
                width: parent.width
                text: "Neues Konto anlegen"
                onClicked: pageStack.push(Qt.resolvedUrl("ProfilSeite.qml"), { modus: "registrieren", email: email.text })
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                color: "#8c8c8c"
                font.pixelSize: 20
                text: "Konten, die in der Android- oder iPhone-App mit Google, Facebook oder Apple angelegt wurden, "
                      + "lassen sich hier nicht anmelden – nur Konten mit E-Mail und Passwort."
            }
        }
    }
}
