(* What examples/RL_Environment calls. The threaded structure is
   src/AI/sml_inspection/smlTimeout.sml, and that directory is built only
   for Poly/ML. Rune cannot preempt a call, so timeout runs it.
   FunctionTimeout is never raised. *)
structure smlTimeout =
struct

exception FunctionTimeout

fun timeout (_ : real) f x = f x

end
