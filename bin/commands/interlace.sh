#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [-r] <pdfA> <pdfB> <output.pdf>
   or: $(basename "$0") [-h|--help]

Interlaces two PDF files page by page (A then B), with B optionally reversed.
Unequal document page counts are handled by appending pages from longer document sequentially at the end.

Options:
  -r, --reverse-b    Reverse the page order of the second PDF (B).
                     Example: A1 A2 + B1 B2 B3  →  A1 B3 A2 B2 B1

  -h, --help         Show this help message and exit.

Examples:
  $(basename "$0") fileA.pdf fileB.pdf merged.pdf
  $(basename "$0") -r fileA.pdf fileB.pdf reverse_merged.pdf
EOF
}

# Parse options
REVERSE_B=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -r|--reverse-b)
            REVERSE_B=true
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Error: Unknown option '$1'" >&2
            usage >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

# Check arguments
if [[ $# -ne 3 ]]; then
    echo "Error: Wrong number of arguments." >&2
    usage >&2
    exit 1
fi

A="$1"
B="$2"
OUT="$3"

# Validate input files exist
[[ -f "$A" ]] || { echo "Error: File not found: $A" >&2; exit 1; }
[[ -f "$B" ]] || { echo "Error: File not found: $B" >&2; exit 1; }

PAGES_A=$(pdfinfo "$A" | awk '/^Pages:/ {print $2}')
PAGES_B=$(pdfinfo "$B" | awk '/^Pages:/ {print $2}')

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

MERGE_LIST=()

i=1
while [[ $i -le ${PAGES_A} || $i -le ${PAGES_B} ]]; do
    # Page from A (always forward)
    if [[ $i -le $PAGES_A ]]; then
        pa="$TMPDIR/a_$i.pdf"
        gs -q -dNOPAUSE -dBATCH \
           -sDEVICE=pdfwrite \
           -dFirstPage=$i -dLastPage=$i \
           -sOutputFile="$pa" \
           "$A"
        MERGE_LIST+=("$pa")
    fi

    # Page from B (forward or reversed)
    if [[ $i -le $PAGES_B ]]; then
        if [[ "$REVERSE_B" == true ]]; then
            BPAGE=$((PAGES_B - i + 1))
        else
            BPAGE=$i
        fi

        pb="$TMPDIR/b_$i.pdf"
        gs -q -dNOPAUSE -dBATCH \
           -sDEVICE=pdfwrite \
           -dFirstPage=$BPAGE -dLastPage=$BPAGE \
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
