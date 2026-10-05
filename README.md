# Wien zu Fuß für Sailfish OS und MeeGo Harmattan

Schritte zählen, Ranking, Challenges, Gutscheine und Jahresrückblick von
„Wien zu Fuß“ – auf Sailfish-Telefonen (armv7hl, aarch64) und auf dem
Nokia N9/N950. Ein **inoffizieller** Client, nicht von der Stadt Wien oder
der Mobilitätsagentur.

## Warum kein Port der APK

Die Android-App (`com.digitalsunray.wienzufuss`) ist natives Kotlin und
zählt selbst keine Schritte: sie liest sie aus Health Connect oder Google
Fit und lädt Tagessummen hoch. Beides gibt es weder auf dem N9 noch
(brauchbar) unter Sailfish. Was die App sonst tut, ist eine schlichte
REST-Schnittstelle hinter einer Firebase-Anmeldung – die übernimmt dieser
Client, mit eigener Schrittzählung. Die Schnittstelle steht in
[api.md](api.md).

## Aufbau

    ┌───────────────────────────────┐   ┌───────────────────────────────┐
    │ Oberfläche                    │   │ wzf-schritte (Hintergrund)    │
    │ N9: Qt 4.7, QML 1, Harmattan  │   │ zählt, schreibt Tagessummen   │
    │ SFOS: Qt 5.6, Silica          │◄─►│ ~/.local/share/wienzufuss/    │
    └──────────────┬────────────────┘   │ D-Bus: org.smatkovi.          │
                   │ stdin/stdout        │        WienZuFuss.Schritte    │
    ┌──────────────┴────────────────┐   └──────────────┬────────────────┘
    │ wzf-dienst (Rust, statisch)   │◄──── „sync“ ─────┘ etwa stündlich
    │ Firebase-Login, Backend, Upload│
    └───────────────────────────────┘

* **wzf-dienst** (`dienst/`): derselbe Rust-Dienst auf allen drei
  Architekturen, statisch gegen musl, eigenes OpenSSL und eingebettete
  Mozilla-Wurzeln (das TLS des N9 ist zu alt). Zeilenprotokoll wie bei
  den Bahn-Ports (`meego/src/Dienst.h`); `wzf-dienst sync` lädt einmal hoch
  und endet.
* **wzf-schritte** (`schritte/`): läuft im Hintergrund weiter, auch wenn
  die App zu ist.
  * **Sailfish:** liest den Schrittzähler des Sensorchips über sensorfw
    (`stepcountersensor`, hybris) – direkt über D-Bus und den Socket von
    sensorfwd, ohne Client-Bibliothek. Der zählt auch, wenn das Telefon
    schläft; der Dienst wacht alle zehn Minuten kurz auf (keepalive).
    Bietet das Gerät keinen an, zählt er auf Wunsch mit dem
    Beschleunigungssensor (kostet Akku, weil das Telefon dann wach bleibt).
    systemd-Benutzerdienst `wienzufuss-schritte.service`.
  * **N9/N950:** nur Beschleunigungssensor (lis3lv02d), 20 Hz über
    QtMobility mit `alwaysOn` – sensord liefert damit auch bei dunklem
    Bildschirm. Liegt das Telefon 30 s still, misst er mit 5 Hz, und
    sensord bündelt je zehn Messungen: am N950 gemessen 0,4 % eines Kerns
    in Ruhe (statt 3,5 % ungepuffert bei 20 Hz), 1,6 % beim Gehen. Gestartet über den Sitzungsbus; ein Job unter
    `/etc/init/apps` stößt ihn alle fünf Minuten an (Muster des
    WhatsApp-Backends).
* **Schritterkennung** (`schritte/Schritterkennung.h`): geglätteter Betrag
  der Beschleunigung, gleitende Schwelle aus den letzten zwei Sekunden, ein
  Schritt je Durchgang nach oben; gezählt wird erst ab dem vierten
  gleichmäßigen Schritt. Angelehnt an Sébastien Ménigots HTML5-Schrittzähler
  (GPLv3), neu geschrieben. Test an künstlichen Signalen:

      g++ -std=c++98 -O2 -o /tmp/t schritte/test/test.cpp && /tmp/t

## Anmeldung

Nur **E-Mail und Passwort** (Firebase-REST, wie die App über ihr SDK).
Gespeichert wird das Erneuerungs-Token in `~/.config/wienzufuss/anmeldung.json`
(Modus 0600), nie das Passwort. Konten, die mit Google, Facebook oder Apple
angelegt wurden, gehen nicht. Neues Konto und „Passwort vergessen“ gibt es
in der App.

## Übertragen der Schritte

Aus, bis man es in den Einstellungen einschaltet. Dann:

* Übertragen werden Tagessummen der letzten 14 Tage, nur Tage, an denen
  dieses Telefon gezählt hat.
* Vorher wird der Stand am Server gelesen; ein Tag geht nur hinauf, wenn
  hier **mehr** Schritte stehen. Ein Wert am Server – etwa vom
  Android-Telefon – wird nie kleiner. Wer an einem Tag mit zwei Telefonen
  geht, bekommt den höheren Wert, nicht die Summe.
* Nachher wird noch einmal gelesen. Steht dort nicht genau, was geschickt
  wurde, hält das Übertragen an, bis man es in der App freigibt
  (`~/.local/share/wienzufuss/sync.json`, Protokoll in `hochgeladen.log`).

Ob der Server je Tag ersetzt oder addiert, ist aus der App nur
geschlossen (sie schickt bei jedem Lauf die letzte Woche neu) – die
Nachkontrolle fängt es ab, falls nicht.

Es gibt keine Eingabe von Hand: übertragen wird nur, was gezählt wurde.

## Logo, Schrift und Foto der Android-App

Nicht in diesem Repo: Symbol, Schrift (Neo Sans Pro) und das Foto der
Einlöse-Bestätigung gehören der Stadt Wien bzw. den Rechteinhabern. Die
Build-Skripte holen sie aus der **eigenen** APK, wenn sie da ist
(`~/Downloads/Wien+zu+Fuß_3.3.3_APKPure.apk` oder `WZF_APK=/pfad/zur.apk`):

    python3 icons/make-icons.py     # Startsymbole
    python3 tools/apk-vorlage.py    # build/vorlage/: Schrift, Foto

Ohne APK gibt es ein eigenes Symbol (Fußabdrücke) und die Systemschrift.

## Bauen

    tools/build-meego.sh            # N9: Rust-Dienst, Schrittdienst, Oberfläche
    meego/build-deb.sh 0.2.0        # -> build/wienzufuss_0.2.0_armel.deb
    tools/build-sailfish.sh         # -> build/wienzufuss-0.2.0-1.{armv7hl,aarch64}.rpm

Rust und die musl-Toolchains legt `tools/toolchain.sh` unter `/tmp/rust`
an. Das N9 baut mit MADDEs GCC 4.4.1 gegen den Harmattan-Sysroot (QtSDK),
Sailfish mit `mb2` in der Platform-SDK-Chroot gegen SailfishOS 5.1.0.11.

## Probeläufe ohne Telefon

* `tools/probe.sh 'js:…' warte:… bild:/tmp/a.png` – zeichnet die
  N9-Oberfläche mit Qt 4.8 aus dem QtSDK auf einem Dummy-X-Server.
* `tools/sfos-probe.sh 'js:…' warte:…` – erzeugt alle Sailfish-Seiten in
  der echten Silica-Laufzeit des SDK-Ziels unter qemu und zeigt jede
  QML-Warnung (gezeichnet wird dabei nichts).

Beide lassen den Dienst mit `WZF_ATTRAPPE=1` laufen: feste Beispieldaten
statt Server, nie im Paket gesetzt.

## Installieren

* **N9/N950:** `dpkg -i wienzufuss_0.2.0_armel.deb` (als root bzw.
  `devel-su`); der Schrittdienst startet sofort.
* **Sailfish (ab 5.0):** `devel-su pkcon install-local wienzufuss-0.2.0-1.aarch64.rpm`
  (bzw. armv7hl). Gebaut gegen SailfishOS 5.1.0.11; das RPM verlangt
  glibc 2.34 und lässt sich auf Sailfish 4.x nicht installieren. Der Schrittdienst läuft danach als Benutzerdienst:
  `systemctl --user status wienzufuss-schritte`.
  Ob das Gerät einen Hardware-Schrittzähler anbietet:
  `grep -r step /etc/sensorfw/` (`stepcountersensor=True`).

## Stand

0.2.0 – geprüft:

* **N950 (Hardware):** Installation, Schrittdienst (Start über D-Bus,
  Zählen bei dunklem Bildschirm, Ruhe-Umschaltung, CPU-Verbrauch),
  Oberfläche ohne QML-Fehler.
* **Echtes Konto:** Anmeldung (Firebase-REST) und alle Lesebefehle –
  Profil, Schritte je Tag, Ranking, Bestenliste, Challenges, Gutscheine,
  Rückblick; Antwortformen in `api.md` abgeglichen.
* **Sailfish:** alle Seiten in der echten Silica-Laufzeit des SDK unter
  qemu; ein Sailfish-Gerät (Hardware-Schrittzähler) noch nicht.

Noch offen: Genauigkeit beim Gehen, Akku über den ganzen Tag, ein echter
Upload (ersetzen oder addieren) und ein echtes Einlösen.

## Einlösen wie in der App

Einlösen (PIN im Lokal) und die Bestätigung, die man vor Ort herzeigt,
sind der Android-App nachgebaut (`meego/qml/Original*.qml`, für Sailfish
beim Bauen übernommen): Layout, Farben, Texte, Fehlermeldungen; Schrift
und Foto aus der eigenen APK (siehe oben). Die Bestätigung erscheint nur,
wenn der Server das Einlösen bestätigt hat, und lässt sich nicht erneut
aufrufen. QR-Codes kann der Client nicht lesen – im Lokal nach dem
PIN-Code fragen.

## Lizenz

GPLv3 (`COPYING`).

* `dienst/certs/cacert.pem`: Mozilla-CA-Bündel von curl.se
  (https://curl.se/docs/caextract.html), MPL 2.0.
* Das Symbol im Repo-Build (Fußabdrücke) ist eigen; Logo, Schrift und Foto
  der Android-App kommen nur aus der eigenen APK und gehören den
  jeweiligen Rechteinhabern.
