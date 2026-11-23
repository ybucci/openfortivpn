#!/bin/bash
# <xbar.title>VPN Solfácil (openfortivpn)</xbar.title>
# <xbar.version>v0.1</xbar.version>
# <xbar.desc>Connect/disconnect the FortiGate SAML VPN using the openfortivpn fork.</xbar.desc>
# <xbar.dependencies>openfortivpn-solfacil</xbar.dependencies>

BIN=/usr/local/bin/openfortivpn-solfacil
NAME="${VPN_PROC:-openfortivpn-solfacil}"
# host:port saved by install.sh; must match the sudoers rule exactly.
GATEWAY="$(head -n1 "$HOME/.config/openfortivpn-solfacil/gateway" 2>/dev/null)"
LOG="$HOME/Library/Logs/openfortivpn-solfacil.log"

case "$1" in
connect)
	[ -n "$GATEWAY" ] || exit 1
	pgrep -x "$NAME" >/dev/null && exit 0
	nohup sudo -n "$BIN" "$GATEWAY" --saml-login --persistent=5 \
		>>"$LOG" 2>&1 </dev/null &
	disown 2>/dev/null
	exit 0
	;;
disconnect)
	sudo -n /usr/bin/pkill -INT -x "$NAME"
	exit 0
	;;
esac

if pgrep -x "$NAME" >/dev/null; then
	if ifconfig ppp0 2>/dev/null | grep -q "flags=.*UP"; then
		state=up
		ip=$(ifconfig ppp0 | awk '/inet /{print $2; exit}')
		domains=$(grep -l "managed by openfortivpn" /etc/resolver/* 2>/dev/null | wc -l | tr -d ' ')
	else
		state=connecting
	fi
else
	state=down
fi

case "$state" in
up)
	echo "VPN ● | color=#2ecc71"
	echo "---"
	echo "Conectado | color=#2ecc71"
	echo "IP do túnel: $ip"
	echo "Domínios internos (DNS): $domains"
	echo "---"
	echo "Desconectar | bash='$0' param1=disconnect terminal=false refresh=true"
	;;
connecting)
	echo "VPN ● | color=#f1c40f"
	echo "---"
	echo "Conectando... (conclua o login SSO no navegador) | color=#f1c40f"
	echo "---"
	echo "Cancelar | bash='$0' param1=disconnect terminal=false refresh=true"
	;;
*)
	echo "VPN ○ | color=#e74c3c"
	echo "---"
	echo "Desconectado | color=#e74c3c"
	echo "---"
	if [ -n "$GATEWAY" ]; then
		echo "Conectar | bash='$0' param1=connect terminal=false refresh=true"
	else
		echo "Gateway não configurado: rode install.sh"
	fi
	;;
esac
echo "---"
echo "Ver log | bash=/usr/bin/open param1=-t param2='$LOG' terminal=false"
