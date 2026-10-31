#!/bin/sh
# Configure HOL for Rune (tools-rune/README.md): the counterpart of
#   poly < tools/smart-configure.sml
# which fills in tools-rune/Holmake/Systeml.sml, writes Systeml's entries in
# sigobj, and builds HOL's tools -- mllex, mlyacc, Holmake, build, unquote,
# holdeptool, heapname, genscriptdep, linkToSigobj -- with Rune's compiler,
# each a bytecode file in tools-rune/bin and a script of the tool's name
# that runs it, where the Poly/ML configuration puts the tool.
#   sh tools-rune/configure.sh
# Rune's compiler, VM and REPL are taken from RUNE (the bin directory of a
# Rune build or installation), else from beside the rune on PATH.
set -eu
holdir=$(cd "$(dirname "$0")/.." && pwd)
cd "$holdir"

if [ -n "${RUNE:-}" ]; then runebin=$RUNE
elif command -v rune > /dev/null 2>&1; then runebin=$(dirname "$(command -v rune)")
else echo "configure: no Rune: put rune on PATH, or set RUNE to the bin directory of a Rune build" >&2; exit 1
fi
runebin=$(cd "$runebin" && pwd)
for t in rune runevm rune-repl; do
  [ -x "$runebin/$t" ] || { echo "configure: no $runebin/$t" >&2; exit 1; }
done
case "$(uname -s)" in
  Linux) os=linux ;;
  Darwin) os=macosx ;;
  SunOS) os=solaris ;;
  *) os=unix ;;
esac
# what Rune's compiler and REPL compile they keep in one cache (Rune's
# docs/units.md, The cache), rather than in a .rune beside every file
RUNE_CACHE=$holdir/tools-rune/cache
export RUNE_CACHE
make=$(command -v gmake || command -v make || echo make)
dot=$(command -v dot || true)
echo "HOL for Rune: HOLDIR $holdir, Rune $runebin, OS $os"

# ---- Systeml, from its template, and its entries in sigobj ----------------
quote() { printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; }
if [ -n "$dot" ]; then dotopt="SOME $(quote "$dot")"; else dotopt=NONE; fi
sed -e "s|^val HOLDIR = \"\"|val HOLDIR = $(quote "$holdir")|" \
    -e "s|^val POLY = \"\"|val POLY = $(quote "$runebin/rune-repl")|" \
    -e "s|^val POLYC = \"\"|val POLYC = $(quote "$holdir/tools-rune/bin/polyc")|" \
    -e "s|^val OS = \"\"|val OS = \"$os\"|" \
    -e "s|^val GNUMAKE = \"\"|val GNUMAKE = $(quote "$make")|" \
    -e 's|^val DYNLIB = ""|val DYNLIB = false|' \
    -e 's|^val version = ""|val version = 2|' \
    -e 's|^val ML_SYSNAME = ""|val ML_SYSNAME = "rune"|' \
    -e 's|^val release = ""|val release = "Trindemossen"|' \
    -e "s|^val DOT_PATH = \"\"|val DOT_PATH = $dotopt|" \
    -e 's|^val MV = ""|val MV = "/bin/mv"|' \
    -e 's|^val CP = ""|val CP = "/bin/cp"|' \
    tools-rune/Holmake/unix-systeml.sml > tools-rune/Holmake/Systeml.sml
mkdir -p sigobj
# as the Poly/ML configuration has them: "compiled" into sigobj, the .ui and
# .uo being the lists of what to use
printf '$(HOLDIR)/sigobj/Systeml.sig\n' > sigobj/Systeml.ui
cp tools/Holmake/Systeml.sig sigobj/Systeml.sig
printf '%s\n' "$holdir/sigobj/Systeml.sml" > sigobj/Systeml.uo
cp tools-rune/Holmake/Systeml.sml sigobj/Systeml.sml

# ---- the tools ------------------------------------------------------------
mkdir -p tools-rune/bin bin
# polyc, which the Holmakefiles make programs with (POLYC)
sed -e "s|@RUNEBIN@|$runebin|" -e "s|@HOLDIR@|$holdir|" tools-rune/polyc.sh > tools-rune/bin/polyc
chmod a+x tools-rune/bin/polyc
# tool NAME TARGET FILE...: FILE... compiled into tools-rune/bin/NAME.rbc,
# and TARGET the script that runs it
tool() {
  name=$1 target=$2
  shift 2
  echo "Making $name"
  "$runebin/rune" -o "tools-rune/bin/$name.rbc" "$@" ||
    { echo "configure: $name does not compile" >&2; exit 1; }
  # named by its own path (CommandLine.name), as an executable would be:
  # Holmake goes by it
  printf '#!/bin/sh\nexec %s --name %s %s "$@"\n' "$runebin/runevm" "$holdir/$target" \
    "$holdir/tools-rune/bin/$name.rbc" > "$target"
  chmod a+x "$target"
}
subst="tools-poly/Holmake/Systeml.sml=tools-rune/Holmake/Systeml.sml \
       tools/Holmake/mlton/PolyML.sml=tools-rune/Holmake/PolyML.sml"
mlb() { sh tools-rune/mlb-files.sh "$1" $subst; }
hm=tools/Holmake
systeml="$hm/Systeml.sig tools-rune/Holmake/Systeml.sml"
mosmlish="tools-poly/poly/Binaryset.sig tools-poly/poly/Binaryset.sml tools-poly/poly/Binarymap.sig \
          tools-poly/poly/Binarymap.sml tools-poly/poly/Listsort.sig tools-poly/poly/Listsort.sml"
names="$hm/HOLFS_dtype.sml $hm/HFS_NameMunge.sig $hm/poly/HFS_NameMunge.sml"
hmcore="$names $hm/HOLFileSys.sig $hm/HOLFileSys.sml $hm/regexpMatch.sig $hm/regexpMatch.sml \
        $hm/parse_glob.sig $hm/parse_glob.sml $hm/Holdep_tokens.sig $hm/Holdep_tokens.sml \
        $hm/AttributeSyntax.sig $hm/AttributeSyntax.sml $hm/HolLex.sml $hm/Holmake_tools_dtype.sml \
        $hm/terminal_primitives.sig $hm/poly-terminal-prims.ML $hm/HolParser.sig $hm/HolParser.sml \
        $hm/Holdep.sig $hm/Holdep.sml $hm/Holmake_tools.sig $hm/Holmake_tools.sml \
        $hm/internal_functions.sig $hm/internal_functions.sml $hm/Holmake_types.sig $hm/Holmake_types.sml \
        $hm/ReadHMF.sig $hm/ReadHMF.sml"

# mllex, and the lexers it makes
tool mllex tools/mllex/mllex.exe tools/mllex/mllex.sml tools-rune/mains/mllex.sml
(cd tools/mlyacc/src && ../../mllex/mllex.exe yacc.lex > /dev/null)
(cd "$hm" && ../mllex/mllex.exe HolLex > /dev/null)

# mlyacc
y=tools/mlyacc/src
yl=tools/mlyacc/mlyacclib
tool mlyacc "$y/mlyacc.exe" "$yl/MLY_base-sig.sml" "$yl/MLY_join.sml" "$yl/MLY_lrtable.sml" \
  "$yl/MLY_stream.sml" "$yl/MLY_parser2.sml" \
  $(for f in utils-sig utils sigs verbose hdr yacc-grm-sig yacc-grm yacc.lex parse core coreutils graph \
               look lalr mklrtable grammar mkprstruct shrink absyn-sig yacc absyn link; do echo "$y/$f.sml"; done) \
  "$y/poly-main.ML" tools-rune/mains/mlyacc.sml

# Holmake and build, from the lists MLton builds them from
# shellcheck disable=SC2046
tool Holmake bin/Holmake $(mlb "$hm/mlton/Holmake.mlb")
# shellcheck disable=SC2046
tool build bin/build $(mlb tools/build.mlb)

# the quotation filter
q=tools/quote-filter
# shellcheck disable=SC2086
tool unquote bin/unquote $systeml $hm/AttributeSyntax.sig $hm/AttributeSyntax.sml $hm/HolLex.sml \
  $hm/HM_SimpleBuffer.sig $hm/HM_SimpleBuffer.sml $names $hm/HOLFileSys.sig $hm/HOLFileSys.sml \
  $hm/HolParser.sig $hm/HolParser.sml $q/quotefix.sig $q/quotefix.sml $q/qfilter_util.sig $q/qfilter_util.sml \
  tools-rune/mains/unquote.sml

# holdeptool, heapname, genscriptdep, linkToSigobj
# shellcheck disable=SC2086
tool holdeptool bin/holdeptool.exe tools-poly/poly/Binaryset.sig tools-poly/poly/Binaryset.sml \
  tools-poly/poly/Binarymap.sig tools-poly/poly/Binarymap.sml $names $hm/HOLFileSys.sig $hm/HOLFileSys.sml \
  $hm/Holdep_tokens.sig $hm/Holdep_tokens.sml $systeml $hm/AttributeSyntax.sig $hm/AttributeSyntax.sml \
  $hm/HolLex.sml $hm/HolParser.sig $hm/HolParser.sml $hm/holdeptool.sml tools-rune/mains/holdeptool.sml
# shellcheck disable=SC2086
tool heapname bin/heapname $systeml $mosmlish $hm/holpathdb.sig $hm/holpathdb.sml \
  tools-rune/mains/interrupt.sml $hmcore tools-rune/mains/heapname.sml
# shellcheck disable=SC2086
tool genscriptdep bin/genscriptdep tools-poly/poly/Mosml.sml $mosmlish $hm/holpathdb.sig $hm/holpathdb.sml \
  $systeml tools-rune/mains/interrupt.sml $hmcore $hm/poly/genscriptdep.sml tools-rune/mains/genscriptdep.sml
# shellcheck disable=SC2086
tool linkToSigobj bin/linkToSigobj $systeml $names $hm/poly/LTSprimitives.sml $hm/linkToSigobj.sml \
  tools-rune/mains/linkToSigobj.sml

# ---- HOL's top level: the base image, and bin/buildheap ------------------
echo "Making the base image (tools-rune/bin/buildheap.img)"
rm -f tools-rune/bin/buildheap.img
"$runebin/rune-repl" tools-rune/base.ML < /dev/null > tools-rune/bin/base.log 2>&1 || true
[ -f tools-rune/bin/buildheap.img ] ||
  { echo "configure: the base image was not made (tools-rune/bin/base.log)" >&2; tail -5 tools-rune/bin/base.log >&2; exit 1; }
# The image records Rune's equality budget. Restore keeps the stricter of
# that and --equality-work, so a flag cannot raise it later. Term.identical
# compares a whole term with one polymorphic `=`; milawa_core's term is
# bigger than the default million steps.
python3 - tools-rune/bin/buildheap.img << 'PY'
import struct, sys
path, = sys.argv[1:]
limit = 1000000000
with open(path, "r+b") as f:
    magic = f.read(64)
    nul = magic.find(b"\x00", len(b"runevm image 15 isa "))
    if not magic.startswith(b"runevm image 15 isa ") or nul < 0:
        raise SystemExit("configure: base image has no runevm header")
    # kind, floor, six u32s, two intinf u32s, heap limit, then equality work
    off = nul + 1 + 4 + 8 + 6 * 4 + 2 * 4 + 8
    f.seek(off)
    got = struct.unpack("<Q", f.read(8))[0]
    if got < limit:
        f.seek(off)
        f.write(struct.pack("<Q", limit))
PY
cat > bin/buildheap <<EOB
#!/bin/sh
# HOL's buildheap on Rune (tools-rune/buildheap.ML): the heap that
# --holstate names (or -b) restored, the base image for --poly, else HOL's
# default state; its main reads the arguments, these but Poly/ML's runtime's
RUNE_CACHE=\${RUNE_CACHE-$holdir/tools-rune/cache}
export RUNE_CACHE
state=$holdir/bin/hol.state
prev=""
n=\$#
while [ \$n -gt 0 ]; do
  a=\$1
  shift
  n=\$((n - 1))
  case "\$prev" in --holstate|-b) state=\$a ;; esac
  case "\$a" in
    --holstate=*) state=\${a#--holstate=} ;;
    -b?*) state=\${a#-b} ;;
    --poly) state=$holdir/tools-rune/bin/buildheap.img ;;
  esac
  prev=\$a
  # what Poly/ML's runtime takes for itself, not buildheap: left out
  case "\$a" in --gcthreads=*) ;; *) set -- "\$@" "\$a" ;; esac
done
exec $runebin/runevm --name $holdir/bin/buildheap --restore "\$state" -- "\$@"
EOB
chmod a+x bin/buildheap
# hol.bare and hol, as the Poly/ML configuration has them (its
# emit_hol_script): the REPL of a HOL state, with Poly/ML's preludes
holscript() {
  printf '#!/bin/sh\n# The HOL script (tools-rune/configure.sh)\n%s --gcthreads=1 --repl --holstate=%s %s "$@"\n' \
    "$holdir/bin/buildheap" "$2" "$3" > "bin/$1"
  chmod a+x "bin/$1"
}
holscript hol.bare "$holdir/bin/hol.state0" "Arbint Arbrat $holdir/tools-poly/prelude.ML"
holscript hol "\`$holdir/bin/heapname\`" "Arbint Arbrat $holdir/tools-poly/prelude.ML $holdir/tools-poly/prelude2.ML"

echo "Configured HOL for Rune: now run bin/build"
