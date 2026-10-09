(* Counters for unique identifiers > 0, as ../poly/Counter.sml's, without
   threads: Rune has none *)
signature COUNTER =
sig
  val make: unit -> unit -> int
end;

structure Counter: COUNTER =
struct

fun make () =
  let
    val counter = ref 0;
    fun next () = (counter := !counter + 2; !counter);
  in next end;

end;
