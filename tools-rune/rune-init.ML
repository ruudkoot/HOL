(* The start of HOL's top level for Rune, what tools-poly/poly/poly-init.ML
   makes of Poly/ML: Poly/ML's names over Rune's REPL
   (tools-rune/rune-polyml.ML), the maps and sets HOL's tools share, and
   Systeml. tools-rune/rune-init2.ML is the rest. Used from HOLDIR, by the
   REPL. *)
val _ = use "tools-rune/rune-polyml.ML";

val _ = use "tools-poly/poly/Mosml.sml";
val _ = use "tools-poly/poly/Binarymap.sig";
val _ = use "tools-poly/poly/Binarymap.sml";
val _ = use "tools-poly/poly/Binaryset.sig";
val _ = use "tools-poly/poly/Binaryset.sml";
val _ = use "tools-poly/poly/Listsort.sig";
val _ = use "tools-poly/poly/Listsort.sml";
val _ = use "tools/Holmake/holpathdb.sig";
val _ = use "tools/Holmake/holpathdb.sml";
val _ = use "tools-rune/Holmake/CompilerSpecific.ML";
val _ = use "tools/Holmake/Systeml.sig";
val _ = use "tools-rune/Holmake/Systeml.sml";
