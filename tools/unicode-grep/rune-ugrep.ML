(* unicode-grep for Rune: what tools-rune/bin/polyc makes of ugrep.sml, with
   tools-rune's start of HOL's top level where poly-ugrep.ML has Poly/ML's,
   which uses tools-poly/Holmake/Systeml.sml *)
val _ = PolyML.Compiler.prompt1 := "";
val _ = PolyML.Compiler.prompt2 := "";
val _ = PolyML.print_depth 0;
val origdir = OS.FileSys.getDir();
OS.FileSys.chDir "../..";
val _ = use "tools-rune/rune-init.ML";
OS.FileSys.chDir origdir;

structure BasicIO = SML90;
exception Interrupt = SML90.Interrupt;

use "../../tools/Holmake/hmcore.ML";
use "../../tools/Holmake/FunctionalRecordUpdate.sml";
use "../../tools/Holmake/GetOpt.sig";
use "../../tools/Holmake/GetOpt.sml";
use "../../src/portableML/UTF8.sig";
use "../../src/portableML/UTF8.sml";
use "ugrep.sml";
