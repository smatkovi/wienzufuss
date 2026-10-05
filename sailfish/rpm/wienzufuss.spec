Name:       wienzufuss

Summary:    Wien zu Fuß: Schritte zählen, Ranking, Challenges, Gutscheine (inoffiziell)
Version:    0.2.2
Release:    1
License:    GPLv3
URL:        https://github.com/smatkovi/wienzufuss
Source0:    %{name}-%{version}.tar.bz2
Requires:   sailfishsilica-qt5 >= 0.10.9
# Kamera fuer den QR-Scanner (QML-Import QtMultimedia)
Requires:   qt5-qtdeclarative-import-multimedia
BuildRequires:  pkgconfig(sailfishapp) >= 1.0.2
BuildRequires:  pkgconfig(Qt5Core)
BuildRequires:  pkgconfig(Qt5Qml)
BuildRequires:  pkgconfig(Qt5Quick)
BuildRequires:  pkgconfig(Qt5DBus)
BuildRequires:  pkgconfig(Qt5Network)
BuildRequires:  pkgconfig(Qt5Concurrent)
BuildRequires:  pkgconfig(Qt5Sensors)
BuildRequires:  pkgconfig(keepalive)
BuildRequires:  desktop-file-utils

%description
Inoffizieller Client für „Wien zu Fuß“: zählt Schritte mit dem
Schrittzähler des Telefons (sensorfw) oder dem Beschleunigungssensor und
überträgt sie auf Wunsch. Ranking, Challenges, Gutscheine und
Jahresrückblick wie in der Android-App. Nicht von der Stadt Wien.

%prep
%setup -q -n %{name}-%{version}

%build
%qmake5 wienzufuss.pro VERSION=%{version}
%make_build

%install
%qmake5_install
# Der Netzdienst ist ein statisches Rust-Binary, gebaut von
# tools/build-dienst.sh fuer genau diese Architektur.
install -D -m 755 prebuilt/%{_target_cpu}/wzf-dienst %{buildroot}/usr/libexec/wienzufuss/wzf-dienst
install -D -m 644 wienzufuss-schritte.service %{buildroot}/usr/lib/systemd/user/wienzufuss-schritte.service
mkdir -p %{buildroot}/usr/lib/systemd/user/user-session.target.wants
ln -s ../wienzufuss-schritte.service %{buildroot}/usr/lib/systemd/user/user-session.target.wants/wienzufuss-schritte.service
install -D -m 644 org.smatkovi.WienZuFuss.Schritte.service %{buildroot}%{_datadir}/dbus-1/services/org.smatkovi.WienZuFuss.Schritte.service
# Wird in %post nach /etc/sensorfw/sensord.conf.d kopiert, wenn das Geraet
# einen Schrittzaehler hat, den sensorfw ausblendet.
install -D -m 644 sensorfw/90-wienzufuss-schrittzaehler.conf %{buildroot}%{_datadir}/%{name}/sensorfw/90-wienzufuss-schrittzaehler.conf
desktop-file-install --delete-original \
  --dir %{buildroot}%{_datadir}/applications \
  %{buildroot}%{_datadir}/applications/*.desktop

%post
# Hardware-Schrittzaehler freischalten: nur, wenn der Android-Unterbau einen
# meldet und sensorfw keinen Adapter dafuer eingetragen hat (Jolla Phone
# 2026). Beim Entfernen der App kommt die Datei wieder weg.
SFW=/etc/sensorfw/sensord.conf.d/90-wienzufuss-schrittzaehler.conf
if [ ! -e "$SFW" ] && [ -d /etc/sensorfw/sensord.conf.d ] \
   && ! grep -qs '^ *stepcounteradaptor *=' /etc/sensorfw/*.conf /etc/sensorfw/sensord.conf.d/*.conf \
   && grep -qs 'android.hardware.sensor.stepcounter"' /vendor/etc/permissions/*.xml \
        /odm/etc/permissions/*.xml /system/vendor/etc/permissions/*.xml /system/etc/permissions/*.xml; then
    cp %{_datadir}/%{name}/sensorfw/90-wienzufuss-schrittzaehler.conf "$SFW" \
        && systemctl try-restart sensorfwd.service >/dev/null 2>&1 || :
fi
systemctl-user daemon-reload >/dev/null 2>&1 || :
systemctl-user try-restart wienzufuss-schritte.service >/dev/null 2>&1 || :
systemctl-user start wienzufuss-schritte.service >/dev/null 2>&1 || :

%preun
if [ "$1" -eq 0 ]; then
    systemctl-user stop wienzufuss-schritte.service >/dev/null 2>&1 || :
fi

%postun
if [ "$1" -eq 0 ] && [ -e /etc/sensorfw/sensord.conf.d/90-wienzufuss-schrittzaehler.conf ]; then
    rm -f /etc/sensorfw/sensord.conf.d/90-wienzufuss-schrittzaehler.conf
    systemctl try-restart sensorfwd.service >/dev/null 2>&1 || :
fi
systemctl-user daemon-reload >/dev/null 2>&1 || :

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%{_datadir}/dbus-1/services/org.smatkovi.WienZuFuss.Schritte.service
/usr/libexec/wienzufuss
/usr/lib/systemd/user/wienzufuss-schritte.service
/usr/lib/systemd/user/user-session.target.wants/wienzufuss-schritte.service
