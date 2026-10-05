import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Drei Faelle mit denselben Feldern:
//   registrieren  neues Konto (E-Mail, Passwort) samt Profil
//   anlegen       angemeldet, aber noch kein Profil bei Wien zu Fuss
//   bearbeiten    Benutzername, Bezirk usw. aendern
Page {
    id: seite
    property string modus: "bearbeiten"
    property string email: ""
    property string bezirk: ""
    property string geschlecht: ""
    property string hinweis: ""

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; visible: seite.modus !== "anlegen"; onClicked: pageStack.pop() }
    }

    Component.onCompleted: {
        if (modus === "bearbeiten" && fenster.nutzer) {
            var n = fenster.nutzer
            name.text = n.username ? n.username : ""
            bezirk = n.territory ? String(n.territory) : ""
            geschlecht = n.gender ? String(n.gender).toLowerCase() : ""
            jahr.text = n.yearOfBirth ? String(n.yearOfBirth) : ""
            newsletter.checked = n.newsletter === true
        }
        if (email !== "")
            emailFeld.text = email
    }

    Anfrage {
        id: speichern
        onFertig: {
            if (seite.modus === "registrieren") {
                fenster.angemeldet = true
                fenster.nutzer = daten.nutzer ? daten.nutzer : null
                fenster.meldung("Konto angelegt. Bitte die E-Mail-Adresse über den Link in der Mail bestätigen.")
                pageStack.pop(null)
            } else {
                fenster.nutzer = daten
                fenster.meldung("Gespeichert.")
                pageStack.pop(null)
            }
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    SelectionDialog {
        id: bezirkWahl
        titleText: "Bezirk"
        model: ListModel { id: bezirkModell }
        Component.onCompleted: {
            for (var i = 0; i < W.bezirke.length; ++i)
                bezirkModell.append({ name: W.bezirke[i].name, plz: W.bezirke[i].plz })
            selectedIndex = W.bezirkIndex(seite.bezirk)
        }
        onAccepted: seite.bezirk = bezirkModell.get(selectedIndex).plz
    }
    SelectionDialog {
        id: geschlechtWahl
        titleText: "Geschlecht"
        model: ListModel {
            ListElement { name: "keine Angabe"; wert: "" }
            ListElement { name: "weiblich"; wert: "female" }
            ListElement { name: "männlich"; wert: "male" }
            ListElement { name: "divers"; wert: "diverse" }
        }
        onAccepted: seite.geschlecht = model.get(selectedIndex).wert
    }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: seite.modus === "registrieren" ? "Neues Konto" : (seite.modus === "anlegen" ? "Profil anlegen" : "Profil")
        laedt: speichern.laeuft
    }

    Flickable {
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 32
        clip: true
        Column {
            id: inhalt
            x: 16
            width: parent.width - 32
            spacing: 12
            Item { width: 1; height: 8 }
            Text {
                width: parent.width
                visible: seite.modus === "anlegen"
                wrapMode: Text.WordWrap
                color: "#bfbfbf"
                font.pixelSize: 22
                text: "Für dieses Konto gibt es noch kein Profil bei Wien zu Fuß. Benutzername und Bezirk braucht das Ranking."
            }
            TextField {
                id: emailFeld
                width: parent.width
                visible: seite.modus === "registrieren"
                placeholderText: "E-Mail"
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            TextField {
                id: passwort
                width: parent.width
                visible: seite.modus === "registrieren"
                placeholderText: "Passwort (mindestens 6 Zeichen)"
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            TextField {
                id: name
                width: parent.width
                placeholderText: "Benutzername (im Ranking sichtbar)"
                inputMethodHints: Qt.ImhNoPredictiveText
            }
            Column {
                width: parent.width + 32
                x: -16
                Zeile {
                    titel: "Bezirk"
                    wert: seite.bezirk !== "" ? W.bezirkName(seite.bezirk) : "auswählen"
                    onClicked: { bezirkWahl.selectedIndex = W.bezirkIndex(seite.bezirk); bezirkWahl.open() }
                }
                Zeile {
                    titel: "Geschlecht (freiwillig)"
                    wert: seite.geschlecht === "female" ? "weiblich" : seite.geschlecht === "male" ? "männlich"
                          : seite.geschlecht === "diverse" ? "divers" : "keine Angabe"
                    onClicked: geschlechtWahl.open()
                }
            }
            TextField {
                id: jahr
                width: parent.width
                placeholderText: "Geburtsjahr (freiwillig)"
                inputMethodHints: Qt.ImhDigitsOnly
                maximumLength: 4
            }
            Row {
                width: parent.width
                spacing: 12
                Switch { id: newsletter }
                Text {
                    width: parent.width - newsletter.width - 12
                    anchors.verticalCenter: newsletter.verticalCenter
                    wrapMode: Text.WordWrap
                    color: "white"
                    font.pixelSize: 22
                    text: "Newsletter von Wien zu Fuß"
                }
            }
            Button {
                width: parent.width
                text: seite.modus === "registrieren" ? "Konto anlegen" : "Speichern"
                enabled: !speichern.laeuft && name.text !== "" && seite.bezirk !== ""
                         && (seite.modus !== "registrieren" || (emailFeld.text !== "" && passwort.text.length >= 6))
                onClicked: {
                    seite.hinweis = ""
                    var werte = {
                        benutzername: name.text,
                        bezirk: seite.bezirk,
                        newsletter: newsletter.checked
                    }
                    if (seite.geschlecht !== "")
                        werte.geschlecht = seite.geschlecht
                    if (jahr.text !== "")
                        werte.geburtsjahr = parseInt(jahr.text, 10)
                    if (seite.modus === "registrieren") {
                        werte.email = emailFeld.text
                        werte.passwort = passwort.text
                        speichern.senden("registrieren", werte)
                    } else {
                        speichern.senden(seite.modus === "anlegen" ? "profil_anlegen" : "profil_speichern", werte)
                    }
                }
            }
            Text {
                width: parent.width
                visible: seite.hinweis !== ""
                wrapMode: Text.WordWrap
                color: "#ff6060"
                font.pixelSize: 22
                text: seite.hinweis
            }
        }
    }
}
