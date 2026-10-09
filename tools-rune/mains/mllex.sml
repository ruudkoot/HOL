(* mllex's main, for Rune: as tools/mllex/poly-mllex.ML, compiled with
   tools/mllex/mllex.sml by rune *)
val () =
  let val name = CommandLine.name ()
  in
    case CommandLine.arguments () of
      [] => (TextIO.output (TextIO.stdErr, name ^ ": no arguments\n"); OS.Process.exit OS.Process.failure)
    | args => List.app LexGen.lexGen args
  end
