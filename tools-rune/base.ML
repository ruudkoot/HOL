(* The base image of HOL on Rune (tools-rune/configure.sh): HOL's top level
   and buildheap in Rune's REPL, saved; restored (bin/buildheap --poly, and
   every heap made from it), it runs buildheap's main on its arguments. Used
   from HOLDIR. *)
val _ = Compiler.printDepth := 0;
val _ = use "tools-rune/rune-init.ML";
val _ = use "tools-rune/rune-init2.ML";
val _ = use "tools-rune/buildheap.ML";
val _ = Runtime.share ();
val () =
  case Runtime.save "tools-rune/bin/buildheap.img" of
    Runtime.Saved => ()
  | Runtime.Restored => main ();
