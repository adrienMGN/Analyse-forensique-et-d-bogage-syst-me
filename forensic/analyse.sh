#!/usr/bin/env bash

LINES=5000
OUT="erreurs_default.log"
ERREURS_ON=()

while getopts "t:n:o:h" opt; do
    case "$opt" in
        t)
            IFS=',' read -r -a ERREURS_ON <<< "$OPTARG" #input field separator ,
            ;;
        n)
            LINES="$OPTARG"
            ;;
        o)
            OUT="$OPTARG"
            ;;
        *)
            echo "usage: ./analyse.sh [-t TYPES] [-n LINES] [-o OUTPUT]"
            ;;
    esac # fin case
done

declare -A ERRORS
ERRORS["SYSTEMD"]="systemd\[[0-9]+\]: .* (failed)"
ERRORS["PERMISSION"]="(resources)"
ERRORS["GPU"]="(nvc0|gpu|framebuffer)"
ERRORS["DBUS"]="(dbus\.error)"
ERRORS["GENERIC"]="\b(failed|no such process|error)\b" # majorite des erruers


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

: > "$OUT" # vide et redirige stdout dans #OUT

LOGS=$(journalctl -n "$LINES" --no-pager)

for ERROR_NAME in "${ERREURS_ON[@]}"; do
    grep -Ei "${ERRORS[$ERROR_NAME]}" <<< "$LOGS" |
    awk -v err="$ERROR_NAME" ' # -v set
    { print "[" err "] | " $1,$2,$3,"|",$4,"|",$0 } # col 1 2 3 4, $0 = ligne entiere
    ' >> "$OUT"
done

echo "Resultats fichier: $OUT"
