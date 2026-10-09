# HOL on Rune

This directory configures HOL to build and run on
Rune, a Standard ML implementation
with a bytecode VM and a REPL. It sits beside `tools-poly`, which does the
same for Poly/ML, and copies its structure: Holmake, `bin/build` and the
other tools are the ones the Poly/ML configuration uses (in fact the source
lists MLton builds them from), and Holmake follows the Poly/ML rules
(`ifdef POLY`). Where Rune differs, the difference lives here or in
`src/portableML/rune`.

## Configuring

    RUNE=/path/to/rune/bin sh tools-rune/configure.sh
    bin/build

`RUNE` is the bin directory of a Rune build or installation (`rune`,
`runevm`, `rune-repl`); without it, the `rune` on `PATH` is used.
`configure.sh` stands in for `poly < tools/smart-configure.sml`:

* writes `tools-rune/Holmake/Systeml.sml` from its template
  (`ML_SYSNAME = "rune"`, `POLY` = `rune-repl`, `POLYC` = `tools-rune/bin/polyc`)
  and Systeml's entries in `sigobj`;
* compiles mllex, mlyacc, Holmake, build, unquote, holdeptool, heapname,
  genscriptdep and linkToSigobj with Rune's compiler, each a `.rbc` in
  `tools-rune/bin` run by a two-line script where the Poly/ML configuration
  puts the executable;
* makes the base image `tools-rune/bin/buildheap.img` and the scripts
  `bin/buildheap`, `bin/hol` and `bin/hol.bare`.

What Rune's compiler and REPL compile goes into one cache,
`tools-rune/cache` (`RUNE_CACHE`), so a second configure or a rebuild
recompiles only what changed.

## How the pieces map

| Poly/ML | Rune |
| --- | --- |
| `tools-poly/poly/poly-init.ML`, `poly-init2.ML` | `rune-init.ML`, `rune-init2.ML` |
| Poly/ML's `PolyML`, `Thread`, `Signal` structures | `rune-polyml.ML`: the parts HOL uses, over Rune's `Compiler` and `Runtime` |
| `tools-poly/buildheap.ML` | `buildheap.ML` (generated from it; see below) |
| `tools-poly/holrepl.ML` | `holrepl.ML`: `Time.+` for Poly/ML's overloaded `+` on times, and exceptions shown by `exnMessage` |
| a heap: `PolyML.SaveState` | an image: `Runtime.save` |
| `buildheap`, an executable that loads a heap and goes on | `bin/buildheap`, a script that restores an image |
| `polyc FILE -o OUT` | `tools-rune/bin/polyc` (`polyc.sh`) |
| `src/portableML/poly` | `src/portableML/rune` |

**Heaps.** Poly/ML's buildheap loads a heap into itself and carries on. A
Rune image can't be loaded into a running program: restoring one replaces
the program and resumes it inside the `Runtime.save` call that wrote it.
So every heap here is a whole world with buildheap in it. `bin/buildheap`
restores the heap that `--holstate` (or `-b`) names, or the base image for
`--poly`, and the restored world runs buildheap's `main` on the arguments.
Writing a heap (`-o`) is `Runtime.save`, and a world later restored from
that heap runs `main` again with its own arguments. Before it is written,
equal immutable values are made one (`PolyML.shareCommonData`, which is
`Runtime.share` here), as Poly/ML's buildheap does. Rune's
`docs/plans/hol4.md` measures the heaps and the speed against Poly/ML.

**polyc.** HOL's Holmakefiles make programs from files that `use` other
files at compile time. `polyc` uses the file in Rune's REPL, saves the world
as `OUT.img` and writes `OUT` as a script that restores it and runs `main`.

**src/portableML/rune** is mostly symlinks: the plain-SML files of
`../poly` (Arbint, Arbnum, Exn, MD5, Random, SHA1, Susp, ...) and of
`../mosml` (Unsynchronized, and `concurrent/`, the thread-free Future and
friends). Only `MLSYSPortable.sml`, `Counter.sml` and `PrettyImpl.sml` are
Rune's own, because Rune has no threads.

## Changes outside tools-rune

* `tools/sequences/*`: `[poly,rune]` tags (a tag may now name several ML
  systems) and the `src/portableML/rune` directories;
  `tools/buildutils.sml` reads such tags.
* `tools/Holmake/Holmake_types.sml`, `Holmake_tools.sml`: `rune` gets
  Poly/ML's Holmake variables (`POLY`, `POLYC`, ...) and heap cleaning.
* `src/portableML/rawtheory`: `mktool-rune.ML`, which makes theorytool from
  `../rune`.

## Not there yet

* threads (`--mt`, `Future` in parallel), the language server
  (`--lsp`), and executables made from a HOL state (`--exe`);
* pretty printers installed with `PolyML.addPrettyPrinter` (they are
  accepted and ignored), and `PolyML.prettyRepresentation`, which shows
  any value as `?`: Rune prints a value only by a type it knows when it
  compiles the printer;
* the `[poly]`-only directories (tactictoe, holyhammer, AI).
