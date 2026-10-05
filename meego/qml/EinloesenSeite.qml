import QtQuick 1.1
import com.nokia.meego 1.1
import "wzf.js" as W

// Einen Gutschein einloesen. Wie in der Android-App geht an den Server genau
// eine Angabe:
//   Gastronomie    der PIN des Lokals (die App scannt dort einen QR-Code;
//                  hier wird sein Text bzw. der PIN eingetippt)
//   Veranstaltung  E-Mail, Postadresse oder Abholstelle -- je nachdem, was
//                  der Gutschein erlaubt (eventPickupRestriction)
//   Spende         ohne Angaben
Page {
    id: seite
    property variant g: null
    property string art: g ? String(g.type).toLowerCase() : ""
    property string beschraenkung: g && g.eventPickupRestriction ? String(g.eventPickupRestriction).toLowerCase() : ""
    property bool mitEmail: art === "event" && beschraenkung !== "post"
    property bool mitPost: art === "event" && beschraenkung !== "email"
    property bool mitStellen: mitPost && g && g.pickupStations && g.pickupStations.length > 0 ? true : false
    property string weg: art === "gastronomy" ? "code" : (mitEmail ? "email" : (mitStellen ? "stelle" : (mitPost ? "post" : "")))
    property int stelle: -1
    property string stelleName: ""
    property string hinweis: ""
    property variant ergebnis: null

    tools: ToolBarLayout {
        ToolIcon { iconId: "toolbar-back"; onClicked: pageStack.pop() }
    }

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
            w.pickupStationId = stelle
        else if (weg === "post")
            w.address = { forename: vorname.text, surname: nachname.text, address: strasse.text,
                          additionalAddressInformation: zusatz.text, postalCode: plz.text, city: ort.text }
        return w
    }

    function bereit() {
        if (weg === "code") return code.text !== ""
        if (weg === "email") return email.text.indexOf("@") > 0
        if (weg === "stelle") return stelle >= 0
        if (weg === "post") return vorname.text !== "" && nachname.text !== "" && strasse.text !== "" && plz.text !== "" && ort.text !== ""
        return true
    }

    Anfrage {
        id: einloesen
        onFertig: seite.ergebnis = daten
        onFehler: if (!fenster.fehler(text)) seite.hinweis = W.fehlerText(text)
    }

    QueryDialog {
        id: sicher
        titleText: "Jetzt einlösen?"
        message: "Ein eingelöster Gutschein lässt sich nicht zurückgeben."
        acceptButtonText: "Einlösen"
        rejectButtonText: "Abbrechen"
        // Eingeloest wird auf der Bestaetigungsseite (wie in der App).
        onAccepted: { seite.hinweis = ""; pageStack.push(Qt.resolvedUrl("EingeloestOriginalSeite.qml"), { werte: seite.werte() }) }
    }

    SelectionDialog {
        id: stellenWahl
        titleText: "Abholstelle"
        model: ListModel { id: stellenModell }
        onAccepted: {
            seite.stelle = stellenModell.get(selectedIndex).sid
            seite.stelleName = stellenModell.get(selectedIndex).name
        }
    }

    Kopf {
        id: kopf
        anchors.top: parent.top
        titel: "Einlösen"
        untertitel: g && g.title ? g.title : ""
        laedt: einloesen.laeuft
    }

    Flickable {
        id: flick
        anchors { top: kopf.bottom; left: parent.left; right: parent.right; bottom: parent.bottom }
        contentHeight: inhalt.height + 32
        clip: true
        Column {
            id: inhalt
            x: 16
            width: parent.width - 32
            spacing: 12
            Item { width: 1; height: 8 }

            // --- Ergebnis --------------------------------------------------
            Column {
                width: parent.width
                spacing: 10
                visible: seite.ergebnis ? true : false
                Text { text: "Eingelöst!"; color: "#a0b436"; font.pixelSize: 30 }
                Text {
                    width: parent.width
                    visible: seite.ergebnis && seite.ergebnis.code ? true : false
                    text: seite.ergebnis && seite.ergebnis.code ? seite.ergebnis.code : ""
                    color: "white"
                    font.pixelSize: 36
                    wrapMode: Text.WrapAnywhere
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    textFormat: Text.RichText
                    color: "white"
                    font.pixelSize: 22
                    text: seite.ergebnis && seite.ergebnis.redeemTextHtml ? seite.ergebnis.redeemTextHtml : ""
                    onLinkActivated: Dienst.oeffnen(link)
                }
                Button { width: parent.width; text: "Fertig"; onClicked: pageStack.pop() }
            }

            // --- Eingabe ---------------------------------------------------
            Column {
                width: parent.width
                spacing: 12
                visible: !seite.ergebnis

                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: "#bfbfbf"
                    font.pixelSize: 22
                    text: seite.art === "gastronomy"
                          ? "Im Lokal gibt es zum Einlösen einen QR-Code oder einen PIN. Gib den PIN ein – oder den Text des QR-Codes, "
                            + "wenn du ihn mit einer anderen App gelesen hast."
                          : seite.art === "event" ? "Wie möchtest du den Gutschein bekommen?"
                          : seite.art === "donation" ? "Mit dem Einlösen spendest du diesen Gutschein."
                          : ""
                }
                ButtonColumn {
                    width: parent.width
                    visible: seite.art === "event"
                    Button { text: "Per E-Mail"; visible: seite.mitEmail; checked: seite.weg === "email"; onClicked: seite.weg = "email" }
                    Button { text: "Abholstelle"; visible: seite.mitStellen; checked: seite.weg === "stelle"; onClicked: seite.weg = "stelle" }
                    Button { text: "Per Post"; visible: seite.mitPost; checked: seite.weg === "post"; onClicked: seite.weg = "post" }
                }
                TextField {
                    id: code
                    width: parent.width
                    visible: seite.weg === "code"
                    placeholderText: "PIN oder Code"
                    inputMethodHints: Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                }
                TextField {
                    id: email
                    width: parent.width
                    visible: seite.weg === "email"
                    placeholderText: "E-Mail"
                    inputMethodHints: Qt.ImhEmailCharactersOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                }
                Button {
                    width: parent.width
                    visible: seite.weg === "stelle"
                    text: seite.stelle >= 0 ? seite.stelleName : "Abholstelle wählen"
                    onClicked: {
                        stellenModell.clear()
                        var l = seite.g.pickupStations
                        for (var i = 0; i < l.length; ++i)
                            stellenModell.append({ name: String(l[i].name), sid: W.zahl(l[i].id, 0) })
                        stellenWahl.open()
                    }
                }
                Column {
                    width: parent.width
                    spacing: 8
                    visible: seite.weg === "post"
                    TextField { id: vorname; width: parent.width; placeholderText: "Vorname" }
                    TextField { id: nachname; width: parent.width; placeholderText: "Nachname" }
                    TextField { id: strasse; width: parent.width; placeholderText: "Straße und Hausnummer" }
                    TextField { id: zusatz; width: parent.width; placeholderText: "Zusatz (Stiege, Tür …)" }
                    TextField { id: plz; width: parent.width; placeholderText: "PLZ"; inputMethodHints: Qt.ImhDigitsOnly }
                    TextField { id: ort; width: parent.width; placeholderText: "Ort" }
                }
                Button {
                    width: parent.width
                    text: "Einlösen"
                    enabled: !einloesen.laeuft && seite.bereit()
                    onClicked: sicher.open()
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
    ScrollDecorator { flickableItem: flick }
}
