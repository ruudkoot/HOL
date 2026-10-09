(* What of Poly/ML's structure PolyML the tools built for Rune name (as
   tools/Holmake/mlton/PolyML.sml is MLton's) *)
structure PolyML =
struct
  structure Compiler = struct
    val compilerVersionNumber = 0
  end
  val pointerEq = Runtime.same
end

exception Interrupt = SML90.Interrupt
