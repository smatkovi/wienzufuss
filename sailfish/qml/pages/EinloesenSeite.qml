import QtQuick 2.0
import Sailfish.Silica 1.0
import "../components"
import "../wzf.js" as W

// Einen Gutschein einloesen. Wie in der Android-App geht an den Server genau
// eine Angabe:
//   Gastronomie    der PIN des Lokals (oder der Text des QR-Codes)
//   Veranstaltung  E-Mail, Postadresse oder Abholstelle -- je nachdem, was
//                  der Gutschein erlaubt (eventPickupRestriction)
//   Spende         ohne Angaben
Page {
    id: seite
    property var g: null
    property string art: g ? String(g.type).toLowerCase() : ""
    property string beschraenkung: g && g.eventPickupRestriction ? String(g.eventPickupRestriction).toLowerCase() : ""
    property bool mitEmail: art === "event" && beschraenkung !== "post"
    property bool mitPost: art === "event" && beschraenkung !== "email"
    property bool mitStellen: mitPost && g && g.pickupStations && g.pickupStations.length > 0 ? true : false
    property var wege: {
        var w = []
        if (mitEmail) w.push({ wert: "email", name: "Per E-Mail" })
        if (mitStellen) w.push({ wert: "stelle", name: "Abholstelle" })
        if (mitPost) w.push({ wert: "post", name: "Per Post" })
        return w
    }
    property string weg: art === "gastronomy" ? "code" : (wege.length > 0 ? wege[0].wert : "")
    property string hinweis: ""

    Component.onCompleted: {
        if (fenster.nutzer && fenster.nutzer.email)
            email.text = fenster.nutzer.email
        var a = fenster.nutzer && fenster.nutzer.address ? fenster.nutzer.address : null
        if (a) {
            vorname.text = a.forename ? a.forename : ""
            nachname.text = a.surname ? a.surname : ""
            strasse.text = a.address ? a.address : ""
            zusatz.text = a.additionalAddressInformation ? a.additionalAddressInformation : ""
            plz.text = a.postalCode ? String(a.postalCode) : ""
            ort.text = a.city ? a.city : ""
        }
    }

    function werte() {
        var w = { id: W.zahl(g.id, 0) }
        if (weg === "code")
            w.code = code.text
        else if (weg === "email")
            w.email = email.text
        else if (weg === "stelle")
            w.pickupStationId = W.zahl(g.pickupStations[stelle.currentIndex].id, 0)
        else if (weg === "post")
            w.address = { forename: vorname.text, surname: nachname.text, address: strasse.text,
                          additionalAddressInformation: zusatz.text, postalCode: plz.text, city: ort.text }
        return w
    }

    property bool bereit: {
        if (weg === "code") return code.text !== ""
        if (weg === "email") return email.text.indexOf("@") > 0
        if (weg === "stelle") return stelle.currentIndex >= 0
        if (weg === "post") return vorname.text !== "" && nachname.text !== "" && strasse.text !== "" && plz.text !== "" && ort.text !== ""
        return true
    }

    RemorsePopup { id: remorse }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: inhalt.height + Theme.paddingLarge

        Column {
            id: inhalt
            width: parent.width
            spacing: Theme.paddingSmall
            PageHeader { title: "Einlösen"; description: seite.g && seite.g.title ? seite.g.title : "" }

            // --- Eingabe -----------------------------------------------------
            Column {
                width: parent.width
                spacing: Theme.paddingSmall

                Hinweis {
                    color: Theme.secondaryHighlightColor
                    text: seite.art === "gastronomy"
                          ? "Im Lokal gibt es zum Einlösen einen QR-Code oder einen PIN. Gib den PIN ein – oder den Text des QR-Codes, "
                            + "wenn du ihn mit einer anderen App (etwa Codereader) gelesen hast."
                          : seite.art === "donation" ? "Mit dem Einlösen spendest du diesen Gutschein." : ""
                }
                ComboBox {
                    label: "Zustellung"
                    visible: seite.art === "event" && seite.wege.length > 0
                    menu: ContextMenu {
                        Repeater {
                            model: seite.wege
                            MenuItem { text: modelData.name; onClicked: seite.weg = modelData.wert }
                        }
                    }
                }
                TextField {
                    id: code
                    width: parent.width
                    visible: seite.weg === "code"
                    label: "PIN oder Code"
                    placeholderText: label
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                }
                TextField {
                    id: email
                    width: parent.width
                    visible: seite.weg === "email"
                    label: "E-Mail"
                    placeholderText: label
                    inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                }
                ComboBox {
                    id: stelle
                    visible: seite.weg === "stelle"
                    label: "Abholstelle"
                    currentIndex: -1
                    value: currentIndex >= 0 && seite.g ? seite.g.pickupStations[currentIndex].name : "auswählen"
                    menu: ContextMenu {
                        Repeater {
                            model: seite.g && seite.g.pickupStations ? seite.g.pickupStations : []
                            MenuItem { text: modelData.name }
                        }
                    }
                }
                Column {
                    width: parent.width
                    visible: seite.weg === "post"
                    TextField { id: vorname; width: parent.width; label: "Vorname"; placeholderText: label }
                    TextField { id: nachname; width: parent.width; label: "Nachname"; placeholderText: label }
                    TextField { id: strasse; width: parent.width; label: "Straße und Hausnummer"; placeholderText: label }
                    TextField { id: zusatz; width: parent.width; label: "Zusatz (Stiege, Tür …)"; placeholderText: label }
                    TextField { id: plz; width: parent.width; label: "PLZ"; placeholderText: label; inputMethodHints: Qt.ImhDigitsOnly }
                    TextField { id: ort; width: parent.width; label: "Ort"; placeholderText: label }
                }
                Button {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Einlösen"
                    enabled: seite.bereit
                    // Eingeloest wird auf der Bestaetigungsseite (wie in der App).
                    onClicked: remorse.execute("Gutschein einlösen", function() {
                        seite.hinweis = ""
                        pageStack.push(Qt.resolvedUrl("EingeloestOriginalSeite.qml"), { werte: seite.werte() })
                    })
                }
                Hinweis { fehler: true; text: seite.hinweis }
            }
        }
        VerticalScrollDecorator { }
    }
}
