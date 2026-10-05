#!/bin/sh
# Treibt den Netzdienst auf dem N9/N950 per ssh mit allen Lesebefehlen und
# zeigt die Antworten gekuerzt -- fuer den Abgleich der echten
# Antwortformen mit dem, was die Seiten erwarten (api.md).
#
#   tools/geraet-pruefen.sh [ip] [zeichen]
#
# Nur lesende Befehle; nichts wird hochgeladen, eingeloest oder geaendert.
# Tokens gibt der Dienst nie aus.
IP=${1:-192.168.1.8}
LAENGE=${2:-600}
O="-i $HOME/.ssh/qtc_id_rsa -oHostKeyAlgorithms=+ssh-rsa -oPubkeyAcceptedAlgorithms=+ssh-rsa -oConnectTimeout=8"
JAHR=$(date +%Y)
BIS=$(date +%F)
VON=$(date -d "-13 days" +%F)
ssh $O user@$IP "printf '1\tstatus\t{}\n2\tnutzer\t{}\n3\tgesundheit\t{\"von\":\"$VON\",\"bis\":\"$BIS\",\"gruppierung\":\"DAY\"}\n4\trang\t{\"intervall\":\"WEEK\"}\n5\tbestenliste\t{\"intervall\":\"WEEK\",\"limit\":3}\n6\tchallenges\t{}\n7\tgutscheine\t{}\n8\teingeloest\t{}\n9\trueckblick\t{\"jahr\":$JAHR}\n10\trueckblick\t{\"jahr\":$((JAHR-1))}\n' | /opt/wienzufuss/bin/wzf-dienst 2>/dev/null" 2>/dev/null \
    | sort -n | cut -c1-"$LAENGE"
