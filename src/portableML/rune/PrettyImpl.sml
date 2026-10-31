(* Poly/ML's pretty printer (basis/PrettyPrinter.sml of Poly/ML 5.9.2).
   Rune's Compiler.prettyPrint lays a block out from the column where the
   block began, and a hard line break does not by itself make the block
   overflow. Poly/ML indents from the enclosing block, carries a break's
   offset onto the next block, and a hard line break means the block does
   not fit. html_theory in src/proofman/tests/gh725 is checked against
   Poly/ML's layout. *)
structure PrettyImpl =
struct

  datatype pretty = datatype PolyML.pretty

  fun prettyPrint (stream : string -> unit, width : int) (pretty : pretty) : unit =
    let
      fun printBlanks n =
        if n > 0 then (stream " "; printBlanks (n - 1)) else ()

      fun getSize (PrettyBlock (_, _, _, entries), spaceLeft) =
            List.foldl (fn (p, SOME s) => getSize (p, s) | (_, NONE) => NONE)
              (SOME spaceLeft) entries
        | getSize (PrettyBreak (blanks, _), spaceLeft) =
            if blanks <= spaceLeft then SOME (spaceLeft - blanks) else NONE
        | getSize (PrettyString st, spaceLeft) =
            let val size = String.size st
            in if size <= spaceLeft then SOME (spaceLeft - size) else NONE end
        | getSize (PrettyStringWithWidth (_, w), spaceLeft) =
            if w <= spaceLeft then SOME (spaceLeft - w) else NONE
        | getSize (PrettyLineBreak, _) = NONE

      fun layOut (p as PrettyBlock (blockOffset, consistent, _, entries), indent, spaceLeft) =
            let
              val blockIndent = indent + blockOffset
              fun getsp ([], left) = SOME left
                | getsp (PrettyBreak _ :: _, left) = SOME left
                | getsp (next :: rest, left) =
                    case getSize (next, left) of
                      NONE => NONE
                    | SOME sp => getsp (rest, sp)
              fun doPrint ([], _, left) = left
                | doPrint ([PrettyBreak _], _, left) = left
                | doPrint (PrettyBreak (blanks, breakIndent) :: rest, _, left) =
                    let val currentIndent = blockIndent + breakIndent
                    in
                      if consistent orelse left <= blanks orelse
                         not (isSome (getsp (rest, left - blanks)))
                      then (stream "\n";
                            printBlanks currentIndent;
                            doPrint (rest, breakIndent, width - currentIndent))
                      else (printBlanks blanks;
                            doPrint (rest, 0, left - blanks))
                    end
                | doPrint (PrettyString s :: rest, _, left) =
                    (stream s; doPrint (rest, 0, left - String.size s))
                | doPrint (PrettyStringWithWidth (s, w) :: rest, _, left) =
                    (stream s; doPrint (rest, 0, left - w))
                | doPrint ((b as PrettyBlock _) :: rest, breakIndent, left) =
                    doPrint (rest, 0, layOut (b, blockIndent + breakIndent, left))
                | doPrint (PrettyLineBreak :: rest, _, _) =
                    (stream "\n";
                     printBlanks blockIndent;
                     doPrint (rest, 0, width - blockIndent))
            in
              case getSize (p, spaceLeft) of
                SOME s =>
                  (List.foldl (fn (q, space) => layOut (q, blockIndent, space))
                     spaceLeft entries;
                   s)
              | NONE => doPrint (entries, 0, spaceLeft)
            end
        | layOut (PrettyBreak (blanks, _), _, spaceLeft) =
            (printBlanks blanks; Int.max (spaceLeft - blanks, 0))
        | layOut (PrettyString st, _, spaceLeft) =
            (stream st; Int.max (spaceLeft - String.size st, 0))
        | layOut (PrettyStringWithWidth (st, w), _, spaceLeft) =
            (stream st; Int.max (spaceLeft - w, 0))
        | layOut (PrettyLineBreak, _, spaceLeft) = spaceLeft
    in
      if layOut (pretty, 0, width) <> width then stream "\n" else ()
    end

end
