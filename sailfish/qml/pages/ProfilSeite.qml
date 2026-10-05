import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Drei Faelle mit denselben Feldern:
//   registrieren  neues Konto (E-Mail, Passwort) samt Profil
//   anlegen       angemeldet, aber noch kein Profil bei Wien zu Fuss
//   bearbeiten    Benutzername, Bezirk usw. aendern
Page {
    id: seite
    property string modus: "bearbeiten"
    property string email: ""
    property string hinweis: ""
    backNavigation: modus !== "anlegen"

    property var geschlechter: [
        { name: "keine Angabe", wert: "" },
        { name: "weiblich", wert: "female" },
        { name: "männlich", wert: "male" },
        { name: "divers", wert: "diverse" }
    ]

    Component.onCompleted: {
        if (modus === "bearbeiten" && fenster.nutzer) {
            var n = fenster.nutzer
            name.text = n.username ? n.username : ""
            bezirk.currentIndex = W.bezirkIndex(n.territory ? String(n.territory) : "")
            var g = n.gender ? String(n.gender).toLowerCase() : ""
            for (var i = 0; i < geschlechter.length; ++i)
                if (geschlechter[i].wert === g)
                    geschlecht.currentIndex = i
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
            } else {
                fenster.nutzer = daten
                fenster.meldung("Gespeichert.")
            }
            pageStack.pop(pageStack.find(function(p) { return p.istStart === true }))
        }
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingSmall
            PageHeader {
                title: seite.modus === "registrieren" ? "Neues Konto" : (seite.modus === "anlegen" ? "Profil anlegen" : "Profil")
            }
            Hinweis {
                visible: seite.modus === "anlegen"
                color: Theme.secondaryHighlightColor
                text: seite.modus === "anlegen" ? "Für dieses Konto gibt es noch kein Profil bei Wien zu Fuß. Benutzername und Bezirk braucht das Ranking." : ""
            }
            TextField {
                id: emailFeld
                width: parent.width
                visible: seite.modus === "registrieren"
                label: "E-Mail"
                placeholderText: label
                inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
            }
            PasswordField {
                id: passwort
                width: parent.width
                visible: seite.modus === "registrieren"
                placeholderText: "Passwort (mindestens 6 Zeichen)"
            }
            TextField {
                id: name
                width: parent.width
                label: "Benutzername (im Ranking sichtbar)"
                placeholderText: "Benutzername"
            }
            ComboBox {
                id: bezirk
                label: "Bezirk"
                currentIndex: -1
                value: currentIndex >= 0 ? W.bezirke[currentIndex].name : "auswählen"
                menu: ContextMenu {
                    Repeater {
                        model: W.bezirke
                        MenuItem { text: modelData.name }
                    }
                }
            }
            ComboBox {
                id: geschlecht
                label: "Geschlecht (freiwillig)"
                menu: ContextMenu {
                    Repeater {
                        model: seite.geschlechter
                        MenuItem { text: modelData.name }
                    }
                }
            }
            TextField {
                id: jahr
                width: parent.width
                label: "Geburtsjahr (freiwillig)"
                placeholderText: label
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1900; top: 2030 }
            }
            TextSwitch {
                id: newsletter
                text: "Newsletter von Wien zu Fuß"
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: seite.modus === "registrieren" ? "Konto anlegen" : "Speichern"
                enabled: !speichern.laeuft && name.text !== "" && bezirk.currentIndex >= 0
                         && (seite.modus !== "registrieren" || (emailFeld.text !== "" && passwort.text.length >= 6))
                onClicked: {
                    seite.hinweis = ""
                    var werte = {
                        benutzername: name.text,
                        bezirk: W.bezirke[bezirk.currentIndex].plz,
                        newsletter: newsletter.checked
                    }
                    if (geschlecht.currentIndex > 0)
                        werte.geschlecht = seite.geschlechter[geschlecht.currentIndex].wert
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
            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: speichern.laeuft
                visible: running
                size: BusyIndicatorSize.Medium
            }
            Hinweis { fehler: true; text: seite.hinweis }
        }
        VerticalScrollDecorator { }
    }
}
