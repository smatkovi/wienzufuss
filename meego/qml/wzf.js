.pragma library
// Gemeinsame Hilfen fuer die Seiten (N9 und Sailfish benutzen dieselbe Datei).

var bezirke = [
    { plz: "1010", name: "1., Innere Stadt" },
    { plz: "1020", name: "2., Leopoldstadt" },
    { plz: "1030", name: "3., Landstraße" },
    { plz: "1040", name: "4., Wieden" },
    { plz: "1050", name: "5., Margareten" },
    { plz: "1060", name: "6., Mariahilf" },
    { plz: "1070", name: "7., Neubau" },
    { plz: "1080", name: "8., Josefstadt" },
    { plz: "1090", name: "9., Alsergrund" },
    { plz: "1100", name: "10., Favoriten" },
    { plz: "1110", name: "11., Simmering" },
    { plz: "1120", name: "12., Meidling" },
    { plz: "1130", name: "13., Hietzing" },
    { plz: "1140", name: "14., Penzing" },
    { plz: "1150", name: "15., Rudolfsheim-Fünfhaus" },
    { plz: "1160", name: "16., Ottakring" },
    { plz: "1170", name: "17., Hernals" },
    { plz: "1180", name: "18., Währing" },
    { plz: "1190", name: "19., Döbling" },
    { plz: "1200", name: "20., Brigittenau" },
    { plz: "1210", name: "21., Floridsdorf" },
    { plz: "1220", name: "22., Donaustadt" },
    { plz: "1230", name: "23., Liesing" },
    { plz: "9999", name: "Außerhalb von Wien" }
];

function bezirkName(plz) {
    var p = String(plz)
    for (var i = 0; i < bezirke.length; ++i)
        if (bezirke[i].plz === p)
            return bezirke[i].name
    return p === "" || p === "null" || p === "undefined" ? "" : p
}

function bezirkIndex(plz) {
    var p = String(plz)
    for (var i = 0; i < bezirke.length; ++i)
        if (bezirke[i].plz === p)
            return i
    return -1
}

// 8123 -> "8.123"
function tausender(n) {
    if (n === undefined || n === null || isNaN(n))
        return "–"
    var s = String(Math.round(Number(n)))
    var neg = s.charAt(0) === "-"
    if (neg)
        s = s.substring(1)
    var aus = ""
    while (s.length > 3) {
        aus = "." + s.substring(s.length - 3) + aus
        s = s.substring(0, s.length - 3)
    }
    return (neg ? "-" : "") + s + aus
}

// Meter -> "5,7 km" (unter einem Kilometer "830 m")
function strecke(meter) {
    if (meter === undefined || meter === null || isNaN(meter))
        return "–"
    var m = Number(meter)
    if (m < 1000)
        return Math.round(m) + " m"
    var zehntel = Math.round(m / 100)
    var ganz = Math.floor(zehntel / 10)
    var rest = zehntel % 10
    return tausender(ganz) + (rest ? "," + rest : "") + " km"
}

var wochentage = ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]
var monate = ["Jän.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sep.", "Okt.", "Nov.", "Dez."]

function zuDatum(iso) {
    if (!iso)
        return null
    var s = String(iso)
    var j = parseInt(s.substring(0, 4), 10), m = parseInt(s.substring(5, 7), 10), t = parseInt(s.substring(8, 10), 10)
    if (isNaN(j) || isNaN(m) || isNaN(t))
        return null
    return new Date(j, m - 1, t, 12, 0, 0)
}

// "2026-10-05" -> "Mo, 5. Okt."
function tag(iso) {
    var d = zuDatum(iso)
    if (!d)
        return ""
    return wochentage[d.getDay()] + ", " + d.getDate() + ". " + monate[d.getMonth()]
}

// "2026-10-05..." -> "5.10.2026"
function datum(iso) {
    var d = zuDatum(iso)
    if (!d)
        return ""
    return d.getDate() + "." + (d.getMonth() + 1) + "." + d.getFullYear()
}

function kurzTag(iso) {
    var d = zuDatum(iso)
    return d ? wochentage[d.getDay()] : ""
}

function isoTag(d) {
    function zwei(n) { return n < 10 ? "0" + n : String(n) }
    return d.getFullYear() + "-" + zwei(d.getMonth() + 1) + "-" + zwei(d.getDate())
}

// Die letzten n Tage bis heute (iso), aeltester zuerst.
function letzteTage(heuteIso, n) {
    var d = zuDatum(heuteIso) || new Date()
    var aus = []
    for (var i = n - 1; i >= 0; --i) {
        var x = new Date(d.getFullYear(), d.getMonth(), d.getDate() - i, 12, 0, 0)
        aus.push(isoTag(x))
    }
    return aus
}

var intervalle = [
    { wert: "DAY", name: "Heute" },
    { wert: "WEEK", name: "Woche" },
    { wert: "MONTH", name: "Monat" },
    { wert: "YEAR", name: "Jahr" }
]

function quelleText(q) {
    if (q === "hardware") return "Schrittzähler des Telefons"
    if (q === "beschleunigung") return "Beschleunigungssensor"
    if (q === "aus") return "Zählen ausgeschaltet"
    if (q === "keine") return "Kein Sensor"
    return "Schrittdienst startet …"
}

function gutscheinArt(t) {
    var s = String(t).toLowerCase()
    if (s === "gastronomy") return "Gastronomie"
    if (s === "event") return "Veranstaltung"
    if (s === "donation") return "Spende"
    return ""
}

// Fehlertext ohne die Kennung fuer "abgemeldet".
function fehlerText(t) {
    var s = String(t)
    if (s.indexOf("ABGEMELDET:") === 0)
        return s.substring(11).replace(/^\s+/, "")
    return s
}

function abgemeldet(t) {
    return String(t).indexOf("ABGEMELDET:") === 0
}

function json(text, ersatz) {
    try {
        return JSON.parse(text)
    } catch (e) {
        return ersatz
    }
}

function zahl(v, ersatz) {
    var n = Number(v)
    return (v === undefined || v === null || isNaN(n)) ? ersatz : n
}

// Wie weit die Punkte fuer einen Gutschein reichen.
function gutscheinStand(punkte, noetig) {
    var p = zahl(punkte, -1), n = zahl(noetig, 0)
    if (p < 0 || n <= 0)
        return ""
    return p >= n ? "einlösbar" : "noch " + tausender(n - p) + " Schritte"
}

// Beste/ruhigste Tage im Rueckblick. Der Server liefert
// {date1, steps1, date2, steps2, date3, steps3}; aeltere Form {date, steps}.
function rueckblickTage(t) {
    if (!t)
        return ""
    var aus = []
    for (var i = 1; i <= 3; ++i) {
        var d = t["date" + i], n = t["steps" + i]
        if (d || (n !== undefined && n !== null))
            aus.push((d ? datum(d) : "?") + ": " + tausender(n))
    }
    if (aus.length === 0 && (t.date || t.steps))
        aus.push((t.date ? datum(t.date) : "?") + ": " + tausender(t.steps))
    return aus.join(" · ")
}
