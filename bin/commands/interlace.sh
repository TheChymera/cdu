#!/usr/bin/env bash
set -euo pipefail

A="$1"
B="$2"
OUT="$3"

PAGES_A=$(pdfinfo "$A" | awk '/^Pages:/ {print $2}')
PAGES_B=$(pdfinfo "$B" | awk '/^Pages:/ {print $2}')

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

MERGE_LIST=()

i=1
while [[ $i -le $PAGES_A || $i -le $PAGES_B ]]; do
    if [[ $i -le $PAGES_A ]]; then
        pa="$TMPDIR/a_$i.pdf"
        gs -q -dNOPAUSE -dBATCH \
           -sDEVICE=pdfwrite \
           -dFirstPage=$i -dLastPage=$i \
           -sOutputFile="$pa" \
           "$A"
        MERGE_LIST+=("$pa")
    fi

    if [[ $i -le $PAGES_B ]]; then
        pb="$TMPDIR/b_$i.pdf"
        gs -q -dNOPAUSE -dBATCH \
           -sDEVICE=pdfwrite \
           -dFirstPage=$i -dLastPage=$i \
           -sOutputFile="$pb" \
           "$B"
        MERGE_LIST+=("$pb")
    fi

    ((i++))
done

gs -q -dNOPAUSE -dBATCH \
   -sDEVICE=pdfwrite \
   -sOutputFile="$OUT" \
   "${MERGE_LIST[@]}"
