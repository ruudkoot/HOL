#!/bin/sh
# polyc for Rune (tools-rune/README.md), installed by tools-rune/configure.sh
# as tools-rune/bin/polyc and named POLYC in Systeml:
#   polyc [-o OUT] FILE
# As Poly/ML's polyc: FILE is used, as the REPL would -- so that it may use
# others -- and OUT is a program that runs its main : unit -> unit. Here FILE
# is used in Rune's REPL, after Poly/ML's names (tools-rune/rune-polyml.ML),
# which such a file may use as it does on Poly/ML; the world is then saved
# as OUT.img, and OUT is a
# script that restores it, whose main then runs on OUT's arguments; an
# exception main does not handle is reported, as Poly/ML's program would, and
# the program fails.
set -eu
RUNEBIN=@RUNEBIN@
# what the REPL compiles goes into HOL's one cache (tools-rune/configure.sh)
RUNE_CACHE=${RUNE_CACHE-@HOLDIR@/tools-rune/cache}
export RUNE_CACHE
out=a.out
file=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) out=$2; shift 2 ;;
    -*) echo "polyc: unknown option $1" >&2; exit 2 ;;
    *) file=$1; shift ;;
  esac
done
[ -n "$file" ] || { echo "usage: polyc [-o OUT] FILE" >&2; exit 2; }
case $out in /*) ;; *) out=$(pwd)/$out ;; esac
img=$out.img
rm -f "$out" "$img"
driver=$(mktemp "${TMPDIR:-/tmp}/polyc.XXXXXX")
trap 'rm -f "$driver"' EXIT
sml_string() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
cat > "$driver" <<EOF
val _ = Compiler.printDepth := 0;
val _ = use $(sml_string "@HOLDIR@/tools-rune/rune-polyml.ML");
val _ = use $(sml_string "$file");
val () =
  case Runtime.save $(sml_string "$img") of
    Runtime.Saved => ()
  | Runtime.Restored =>
      (main ()
       handle e =>
         (TextIO.output (TextIO.stdErr, "Exception- " ^ General.exnMessage e ^ " raised\n");
          OS.Process.exit OS.Process.failure);
       OS.Process.exit OS.Process.success);
EOF
"$RUNEBIN/rune-repl" "$driver" < /dev/null > "$driver.log" 2>&1 || true
if [ ! -f "$img" ]; then
  grep -v '^- *$' "$driver.log" >&2 || true
  rm -f "$driver.log"
  echo "polyc: $file did not compile" >&2
  exit 1
fi
rm -f "$driver.log"
printf '#!/bin/sh\nexec %s --name %s --restore %s -- "$@"\n' "$RUNEBIN/runevm" "$out" "$img" > "$out"
chmod a+x "$out"
