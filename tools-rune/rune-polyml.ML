(* What of Poly/ML's structures PolyML and Thread HOL's top level names
   (tools-poly/poly/poly-init2.ML, quse.sml, holrepl.ML, the preludes), for
   Rune: the compiler (PolyML.compiler) is Rune's Compiler.compile, the
   controls, the pretty-printing and the printers of one's own
   (addPrettyPrinter) Rune's Compiler's, and what Rune does not have --
   exceptions' locations, a value shown at a type it is not told --
   nothing. *)
structure FixedInt = Int

structure PolyML =
struct
  (* Poly/ML's pretty-printing, which Rune's Compiler has in its shape *)
  type location = Compiler.location
  datatype context = datatype Compiler.context
  datatype pretty = datatype Compiler.pretty
  val prettyPrint = Compiler.prettyPrint

  fun print_depth n = RuneCompiler.printDepth := n

  structure Compiler =
  struct
    val printDepth = RuneCompiler.printDepth
    val prompt1 = RuneCompiler.prompt1
    val prompt2 = RuneCompiler.prompt2
    val timing = ref false
    val lineLength = RuneCompiler.lineLength
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

  (* the REPL's printer of the type the printer's third argument has where
     this is applied: another name for Rune's Compiler.addPrettyPrinter (RuneCompiler, which
     PolyML.Compiler hides here),
     which the compiler follows to the application (Rune's docs/repl.md) *)
  val addPrettyPrinter = RuneCompiler.addPrettyPrinter

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
(* Poly/ML's threads, of which HOL forks one, to read the help database
   (tools-poly/poly/Help.sml): Rune has none, so a thread forked runs to
   its end before fork returns, and a mutex is never held by another *)
structure Mutex =
struct
  type mutex = unit
  fun mutex () = ()
  fun lock () = ()
  fun unlock () = ()
  fun trylock () = true
end
structure ConditionVar =
struct
  type conditionVar = unit
  fun conditionVar () = ()
  (* nothing else runs that could signal it *)
  fun wait ((), ()) = raise Fail "ConditionVar.wait: no threads on Rune"
  fun signal () = ()
  fun broadcast () = ()
end
structure Thread =
struct
  exception Interrupt = SML90.Interrupt
  type thread = unit
  datatype threadAttribute = EnableBroadcastInterrupt of bool | MaximumMLStack of int option
  fun fork (f : unit -> unit, _ : threadAttribute list) : thread = f ()
  fun broadcastInterrupt () = ()
  structure Thread =
  struct
    exception Interrupt = SML90.Interrupt
    type thread = thread
    val fork = fork
    fun broadcastInterrupt () = ()
  end
  structure Mutex = Mutex
  structure ConditionVar = ConditionVar
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
