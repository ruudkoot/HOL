(* tools-poly/Holmake/CompilerSpecific.ML for Rune: a string compiled and
   run with nothing echoed, the REPL's print depth 0 while it is *)
structure CompilerSpecific :>
  sig
    val quietbind : string -> unit
  end
= struct

fun reader s =
    let
      val i = ref 0
      val sz = String.size s
      fun r () = if !i < sz then SOME (String.sub(s,!i)) before i := !i + 1
                 else NONE
    in
      r
    end

fun quietbind s =
    let
      val depth = !RuneCompiler.printDepth
      val () = RuneCompiler.printDepth := 0
    in
      (RuneCompiler.compile {read = reader s, file = "<quietbind>", line = 1} ();
       RuneCompiler.printDepth := depth)
      handle e => (RuneCompiler.printDepth := depth; raise e)
    end

end
