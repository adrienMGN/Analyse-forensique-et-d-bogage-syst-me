#!/usr/bin/env bash

LINES=5000
OUT="erreurs_default.log"
ERREURS_ON=()
SSH_ON=0

while getopts "t:n:o:sh" opt; do
    case "$opt" in
        t)
            IFS=',' read -r -a ERREURS_ON <<< "$OPTARG"
            ;;
        n)
            LINES="$OPTARG"
            ;;
        o)
            OUT="$OPTARG"
            ;;
        s)
            SSH_ON=1
            ;;
        *)
            echo "usage: ./analyse.sh [-t TYPES] [-n LINES] [-o OUTPUT] [-s]"
            exit 1
            ;;
    esac # fin case
done

declare -A ERRORS
ERRORS["SYSTEMD"]="systemd\[[0-9]+\]: .* (failed)"
ERRORS["PERMISSION"]="(resources)"
ERRORS["GPU"]="(nvc0|gpu|framebuffer)"
ERRORS["DBUS"]="(dbus\.error)"
ERRORS["GENERIC"]="\b(failed|no such process|error)\b"

if [ ${#ERREURS_ON[@]} -eq 0 ]; then
    ERREURS_ON=("${!ERRORS[@]}")
fi

for ERR in "${ERREURS_ON[@]}"; do
    if [[ -z "${ERRORS[$ERR]}" ]]; then
        echo "Erreur invalide : $ERR"
        echo "Erreurs valides : SYSTEMD,PERMISSION,GPU,DBUS,GENERIC"
        exit 1
    fi
done

: > "$OUT"

LOGS=$(journalctl -n "$LINES" --no-pager)

for ERROR_NAME in "${ERREURS_ON[@]}"; do
    grep -Ei "${ERRORS[$ERROR_NAME]}" <<< "$LOGS" |
    awk -v err="$ERROR_NAME" '{ print "[" err "] | " $1,$2,$3,"|",$4,"|",$0 }' >> "$OUT"
done

if [ "$SSH_ON" -eq 1 ] && [ -f /var/log/auth.log ]; then
    SSH_PATTERN="Failed password for"
    grep -Ei "$SSH_PATTERN" /var/log/auth.log |
    awk -v err="SSH" '{ print "[" err "] | " $1,$2,$3,"|",$0 }' >> "$OUT"
fi

echo "Resultats fichier: $OUT"
