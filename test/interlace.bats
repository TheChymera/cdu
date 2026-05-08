#!/usr/bin/env bats

SCRIPT="$(dirname "$BATS_TEST_FILENAME")/../bin/cdu"

make_pdf() {
    local path="$1"; shift
    local gs_args=""
    for label in "$@"; do
        gs_args+="/Helvetica findfont 40 scalefont setfont 100 500 moveto ($label) show showpage "
    done
    gs -q -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -sOutputFile="$path" \
        -c "$gs_args"
}

setup() {
    TMPDIR="$(mktemp -d)"
    make_pdf "$TMPDIR/a.pdf" "A1" "A2"
    make_pdf "$TMPDIR/b.pdf" "B1" "B2"
    OUT="$TMPDIR/merged.pdf"
}

teardown() {
    rm -rf "$TMPDIR"
}

page_text() {
    pdftotext -f "$1" -l "$1" "$OUT" - | tr -d '[:space:]'
}

@test "merged PDF has correct page count" {
    run "$SCRIPT" interlace "$TMPDIR/a.pdf" "$TMPDIR/b.pdf" "$OUT"
    [ "$status" -eq 0 ]
    pages=$(pdfinfo "$OUT" | awk '/^Pages:/ {print $2}')
    [ "$pages" -eq 4 ]
}

@test "pages are interleaved in correct order" {
    run "$SCRIPT" interlace "$TMPDIR/a.pdf" "$TMPDIR/b.pdf" "$OUT"
    [ "$status" -eq 0 ]
    [ "$(page_text 1)" = "A1" ]
    [ "$(page_text 2)" = "B1" ]
    [ "$(page_text 3)" = "A2" ]
    [ "$(page_text 4)" = "B2" ]
}

@test "works when A has more pages than B" {
    make_pdf "$TMPDIR/a.pdf" "A1" "A2" "A3"
    run "$SCRIPT" interlace "$TMPDIR/a.pdf" "$TMPDIR/b.pdf" "$OUT"
    [ "$status" -eq 0 ]
    pages=$(pdfinfo "$OUT" | awk '/^Pages:/ {print $2}')
    [ "$pages" -eq 5 ]
    [ "$(page_text 5)" = "A3" ]
}

@test "fails gracefully with missing input file" {
    run "$SCRIPT" interlace "$TMPDIR/a.pdf" "$TMPDIR/nonexistent.pdf" "$OUT"
    [ "$status" -ne 0 ]
}
