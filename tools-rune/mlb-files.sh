#!/bin/sh
# The source files an .mlb names, in order, those of the .mlb files it names
# included where they are named and each file once: what Rune's compiler is
# given to build what MLton builds from the .mlb. The Basis Library
# ($(SML_LIB)) is Rune's own and left out, and so are MLton's annotations
# (ann "..." in ... end) and comments.
#   tools-rune/mlb-files.sh FILE.mlb [SUFFIX=REPLACEMENT ...]
# Each SUFFIX=REPLACEMENT puts the file REPLACEMENT where a path ending in
# SUFFIX would be: a file another ML system's configuration generates, or a
# shim of MLton's.
set -eu
mlb=$1; shift
substs="$*"
walk() {
  dir=$(dirname "$1")
  sed -e 's/(\*[^*]*\*)//g' -e 's/ann *"[^"]*" *in//g' -e 's/\<end\>//g' "$1" |
    tr ' \t' '\n\n' | grep -v '^$' |
    while read -r p; do
      case "$p" in
        '$(SML_LIB)'*) ;;
        *.mlb) (walk "$dir/$p") ;;
        *.sml|*.sig|*.ML|*.fun)
          f=$(realpath -m --relative-to=. "$dir/$p")
          for a in $substs; do
            case "$f" in *"${a%%=*}") f=${a#*=}; break ;; esac
          done
          echo "$f" ;;
      esac
    done
}
walk "$mlb" | awk '!seen[$0]++'
