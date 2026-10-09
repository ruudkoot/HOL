(* What of Poly/ML's structures PolyML and Thread HOL's top level names
   (tools-poly/poly/poly-init2.ML, quse.sml, holrepl.ML, the preludes), for
   Rune: the compiler (PolyML.compiler) is Rune's Compiler.compile, the
   controls Rune's Compiler's, the pretty-printing datatype Poly/ML's with
   Moscow ML's layout (src/portableML/mosml/PrettyImpl.sml), and what Rune
   does not have -- a printer chosen by the type of the value the top level
   prints, exceptions' locations, sharing of data -- nothing. *)
structure FixedInt = Int

structure PolyML =
struct
  type location = {file : string, startLine : FixedInt.int, startPosition : FixedInt.int,
                   endLine : FixedInt.int, endPosition : FixedInt.int}
  datatype context = ContextLocation of location | ContextProperty of string * string
  datatype pretty =
           PrettyBlock of int * bool * context list * pretty list
         | PrettyBreak of int * int
         | PrettyLineBreak
         | PrettyString of string
         | PrettyStringWithWidth of string * int

  fun prettyPrint (stream, lineWidth) pretty =
    let
      fun printBlanks n =
        if n > 0 then (stream " "; printBlanks(n-1)) else ()

      (* Find out whether the block fits and return the space left if it does.
         Terminates with NONE as soon as it finds the line doesn't fit. *)
      fun getSize(PrettyBlock (_, _, _, entries), spaceLeft) =
            List.foldl(fn (p, SOME s) => getSize(p, s) | (_, NONE) => NONE)
                      (SOME spaceLeft)
                      entries

      |   getSize(PrettyBreak (blanks, _), spaceLeft) =
            if blanks <= spaceLeft then SOME(spaceLeft-blanks) else NONE

      |   getSize(PrettyString st, spaceLeft) =
            let
              val size = String.size st
            in
              if size <= spaceLeft then SOME(spaceLeft-size) else NONE
            end

      |   getSize(PrettyStringWithWidth(_, w), spaceLeft) =
            if w <= spaceLeft then SOME(spaceLeft-w) else NONE

      |   getSize(PrettyLineBreak, _) = NONE

        (* Lay out the block and return the space that is left after the line
           has been printed. *)
      fun layOut(p as PrettyBlock (blockOffset, consistent, context, entries),
                 indent, spaceLeft) =
        let
          val blockIndent = indent+blockOffset
        in
          case getSize(p, spaceLeft) of
              SOME s => (* Fits *)
                (* Lay out the contents. This will not need to break. *)
                (List.foldl(fn(p, space) => layOut(p, blockIndent, space))
                           spaceLeft entries;
                 s)
           |   NONE => (* Doesn't fit - break line somewhere. *)
               let
                 (* Lay out this block, breaking where necessary. *)
                 fun doPrint([], _, left) = (* Finished: return what's left. *)
                       left

                 |   doPrint([PrettyBreak _], _, left) =
                       left (* Ignore trailing breaks. *)

                 |   doPrint(PrettyBreak (blanks, breakIndent)::rest, _, left) =
                     let
                       val currentIndent = blockIndent+breakIndent
                       (* Compute the space of the next item(s) up to the end
                          or the next space.  Since we only break at spaces if
                          there are Blocks or Strings without spaces between we
                          need to know the total size. *)
                       fun getsp([], left) = SOME left
                       |   getsp(PrettyBreak _ :: _, left) = SOME left
                       |   getsp(next::rest, left) =
                           case getSize(next, left) of
                               NONE => NONE
                            |   SOME sp => getsp(rest, sp)

                     in
                       if consistent orelse left <= blanks orelse
                          not(isSome(getsp(rest, left-blanks)))
                       then
                         (* Either a consistent break or the next item won't
                            fit. *)
                         (
                           stream "\n";
                           printBlanks currentIndent;
                           (* Carry the indent associated with this item
                              forward so that it is included in the block
                              indentation if the next item is a block.  If
                              it is a string we have already included it. *)
                           doPrint(rest, breakIndent, lineWidth-currentIndent)
                         )
                       else (* We don't need to break here. *)
                         (
                           printBlanks blanks;
                           doPrint(rest, 0, left-blanks)
                         )
                     end

                 |   doPrint(PrettyString s :: rest, _, left) =
                       (
                         stream s;
                         doPrint(rest, 0, left - size s)
                       )

                 |   doPrint(PrettyStringWithWidth(s, w) :: rest, _, left) =
                       (
                         stream s;
                         doPrint(rest, 0, left-w)
                       )

                 |   doPrint((b as PrettyBlock _) :: rest, breakIndent, left) =
                       doPrint(rest,0, layOut(b, blockIndent+breakIndent, left))
                 |   doPrint(PrettyLineBreak :: rest, _, _) =
                       (
                         stream "\n";
                         printBlanks blockIndent;
                         doPrint(rest, 0, lineWidth-blockIndent)
                       )

                 val onLine = doPrint(entries, 0, spaceLeft);
               in
                 onLine
               end
        end

      |   layOut (PrettyBreak (blanks, _), _, spaceLeft) =
                ( printBlanks blanks; Int.max(spaceLeft-blanks, 0) )

      |   layOut (PrettyString st, _, spaceLeft) =
            ( stream st;
              Int.max(spaceLeft - String.size st, 0) )

      |   layOut (PrettyStringWithWidth(st, w), _, spaceLeft) =
            ( stream st; Int.max(spaceLeft-w, 0) )

      |   layOut (PrettyLineBreak, _, spaceLeft) = spaceLeft

    in
      if layOut(pretty, 0, lineWidth) <> lineWidth
      then stream "\n" (* End the line unless we haven't written anything. *)
      else ()
    end

  fun print_depth n = RuneCompiler.printDepth := n

  structure Compiler =
  struct
    val printDepth = RuneCompiler.printDepth
    val prompt1 = RuneCompiler.prompt1
    val prompt2 = RuneCompiler.prompt2
    val timing = ref false
    val lineLength = ref 80
    val compilerVersionNumber = 0
    datatype compilerParameters =
        CPOutStream of string -> unit
      | CPFileName of string
      | CPLineNo of unit -> int
      | CPLineOffset of unit -> int
      | CPErrorMessageProc of {message : pretty, hard : bool, location : location, context : pretty option} -> unit
      | CPPrintDepth of unit -> int
      | CPPrintInAlphabeticalOrder of bool
  end

  (* the compiler on a reader: Rune's Compiler.compile, at the file and line
     the parameters give *)
  fun compiler (read : unit -> char option, params : Compiler.compilerParameters list) : unit -> unit =
    let
      val file = List.foldl (fn (Compiler.CPFileName f, _) => f | (_, f) => f) "<stdIn>" params
      val line = List.foldl (fn (Compiler.CPLineNo f, _) => f () | (_, l) => l) 1 params
    in RuneCompiler.compile {read = read, file = file, line = line} end

  val use = RuneCompiler.use

  (* a printer for the values of a type, which Rune's REPL does not yet
     choose by the type of what it prints: nothing *)
  fun addPrettyPrinter (_ : int -> 'a -> 'b -> pretty) = ()

  (* a value of a type it is not told: what Rune's REPL shows of a value of
     an abstract type *)
  fun prettyRepresentation (_ : 'a, _ : FixedInt.int) : pretty = PrettyString "?"

  structure Exception =
  struct
    fun reraise e = raise e
    fun exceptionLocation (_ : exn) : location option = NONE
    (* the handler is given the exception and no trace: Rune's traces are
       written by the VM where an exception goes uncaught *)
    fun traceException (f : unit -> 'a, h : string list * exn -> 'a) : 'a = f () handle e => h ([], e)
  end

  val pointerEq = Runtime.same
  (* the whole heap's, whatever it is given (Runtime.share) *)
  fun shareCommonData (_ : 'a) = ignore (Runtime.share ())
  fun rootFunction () = ()
  fun rtsArgumentHelp () = ""
  fun architecture () = "Rune"
end

(* Poly/ML's threads, of which HOL's top level names the interrupt: Rune's is
   SML90.Interrupt (Runtime.catchInterrupt) *)
structure Thread =
struct
  structure Thread =
  struct
    exception Interrupt = SML90.Interrupt
    fun broadcastInterrupt () = ()
  end
end

(* Poly/ML's signals, of which HOL's top level catches SIGINT: Rune's
   catchInterrupt, which raises SML90.Interrupt where the program next
   polls; nothing else *)
structure Signal =
struct
  datatype sig_handle = SIG_DFL | SIG_IGN | SIG_HANDLE of int -> unit
  fun signal (2, SIG_HANDLE _) = (ignore (Runtime.catchInterrupt ()); SIG_DFL)
    | signal (_, _) = SIG_DFL
end
