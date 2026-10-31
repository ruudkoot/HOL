(* buildheap for Rune (from tools-poly/buildheap.ML): what HOL's build runs
   to load objects into a HOL state, write a heap, build a theory or start
   the REPL. Poly/ML's buildheap is an executable that loads a heap into
   itself and goes on; a Rune image cannot be loaded into a running world,
   and restoring one replaces the world and goes on inside the save that
   wrote it. So every heap here is a world with this file in it, and
   bin/buildheap restores the heap --holstate names (the base image, of
   this file over HOL's top level, for --poly), whose main reads the
   arguments after `--` and does what Poly/ML's does: a heap written (-o)
   is Runtime.save, and the world restored from it runs main again, with
   its own arguments. Used from HOLDIR, by the REPL, after rune-init.ML and
   rune-init2.ML. *)
structure BasicIO = SML90;

val _ = use "tools/Holmake/hmcore.ML";
val _ = use "tools/Holmake/GetOpt.sig";
val _ = use "tools/Holmake/GetOpt.sml";
val _ = use "tools/Holmake/FunctionalRecordUpdate.sml";
val _ = use "tools-rune/holrepl.ML";

(* what Rune does not have: the language server *)
structure LSPServer = struct
  fun start (_ : {diag : string -> unit}) : unit = raise Fail "no language server on Rune yet"
end

(* Poly/ML's --exe exports a native object and links it with cc. Rune saves
   this world, and the program restores that image and runs fnname. The
   image is output_exe ^ ".img". printDepth is 0 while the call is compiled
   so the REPL does not echo `val () = ()`. *)
structure BuildHeap_EXE_Compile = struct
  fun exe_compile {fnname : string, output_exe : string, keep_temp_files : bool} : unit =
    let
      val _ = keep_temp_files
      val img = output_exe ^ ".img"
      val runevm =
          OS.Path.joinDirFile {dir = OS.Path.dir Systeml.POLY, file = "runevm"}
      val cache =
          OS.Path.concat (Systeml.HOLDIR, OS.Path.concat ("tools-rune", "cache"))
      val old_depth = !PolyML.Compiler.printDepth
      val () = PolyML.print_depth 0
      val source = TextIO.openString ("val () = " ^ fnname ^ " ()")
      val function =
          PolyML.compiler (fn () => TextIO.input1 source, [])
          before PolyML.print_depth old_depth
      val () = PolyML.shareCommonData PolyML.rootFunction
      fun write_script () =
        let
          val out = TextIO.openOut output_exe
          fun prot s = Systeml.protect s
        in
          TextIO.output (out,
            "#!/bin/sh\n\
            \RUNE_CACHE=${RUNE_CACHE-" ^ prot cache ^ "}\n\
            \export RUNE_CACHE\n\
            \exec " ^ prot runevm ^
            " --name " ^ prot output_exe ^
            " --restore " ^ prot img ^
            " -- \"$@\"\n");
          TextIO.closeOut out;
          ignore (Systeml.mk_xable output_exe)
        end
    in
      case Runtime.save img of
          Runtime.Saved =>
            (write_script (); OS.Process.exit OS.Process.success)
        | Runtime.Restored =>
            (function ()
             handle e =>
               (TextIO.output (TextIO.stdErr,
                  "Exception- " ^ General.exnMessage e ^ " raised\n");
                TextIO.flushOut TextIO.stdErr;
                OS.Process.exit OS.Process.failure);
             OS.Process.exit OS.Process.success)
    end
end

val SIGOBJ = OS.Path.concat(Systeml.HOLDIR, "sigobj")
local
  open FunctionalRecordUpdate
  fun makeUpdateT z = makeUpdate16 z
in
fun updateT z = let
  fun from all_forced base_state checkerr checkfors debug defaultout exe
           extra_data forced_objs help lsp multithread output quietp repl z_repl =
    {all_forced = all_forced, base_state = base_state,
     checkerr = checkerr, checkfors = checkfors, debug = debug,
     defaultout = defaultout, exe = exe,
     extra_data = extra_data, forced_objs = forced_objs, help = help,
     lsp = lsp, multithread = multithread,
     output = output, quietp = quietp, repl = repl, z_repl = z_repl}
  fun from' z_repl repl quietp output multithread lsp help forced_objs extra_data exe
            defaultout debug checkfors checkerr base_state all_forced =
    {all_forced = all_forced, base_state = base_state, checkfors = checkfors,
     checkerr = checkerr, debug = debug,
     defaultout = defaultout, exe = exe,
     extra_data = extra_data, forced_objs = forced_objs, help = help,
     lsp = lsp, multithread = multithread,
     output = output, quietp = quietp, repl = repl, z_repl = z_repl}
  fun to f {all_forced, base_state, checkerr, checkfors, debug, defaultout, exe,
            extra_data,
            forced_objs, help, lsp, multithread, output, quietp, repl, z_repl} =
    f all_forced base_state checkerr checkfors debug defaultout exe extra_data
      forced_objs help lsp multithread
      output quietp repl z_repl
in
  makeUpdateT (from, from', to)
end z
val U = U
val $$ = $$
end (* FRU local *)

val heapname = ref (SOME Systeml.DEFAULT_STATE)

(* main, which a world restored from a heap runs (create_heap) *)
val rune_main = ref (fn () => ())

structure BuildHeap_CLINE =
struct

datatype option_record = OR of {
  all_forced : bool,
  base_state : string option,
  checkfors : string list,
  checkerr : string option,
  debug : bool,
  defaultout : string option,
  exe : string option,
  extra_data : string option,
  forced_objs : string list,
  help : bool,
  lsp : bool,
  multithread : int option,
  output : string option,
  quietp : bool,
  repl : bool,
  z_repl : bool
}

local
open TextIO
in
fun warn s = (output(stdErr, s ^ "\n"); flushOut stdErr)
fun die (s:string) : 'a =
  (flushOut stdOut;
   (* try to give stdout a chance to clear so that dying message is last *)
   OS.Process.sleep (Time.fromMilliseconds 300);
   warn s; OS.Process.exit OS.Process.failure)
end

fun mk_quiet (OR r) = OR (updateT r (U #quietp true) $$);

local
  open GetOpt
 fun mkBoolT sel = NoArg (fn () => fn (OR r) => OR (updateT r (U sel true) $$))
 fun setStringOpt argnm sel =
   ReqArg ((fn s => fn (OR r) => OR (updateT r (U sel (SOME s)) $$)), argnm)
 val setBaseNone =
     NoArg (fn () => fn (OR r) => OR (updateT r (U #base_state NONE) $$))
 val ConsForced =
   ReqArg ((fn s => fn (OR r) =>
               OR (updateT r (U #forced_objs (#forced_objs r @ [s])) $$)),
           "file.uo")
 fun addString argnm =
   ReqArg((fn s => fn (OR r) =>
              OR (updateT r (U #checkfors (#checkfors r @ [s])) $$)),
          argnm)
 fun set_threadcount sopt =
   case sopt of
       NONE => (fn (OR r) => OR (updateT r (U #multithread (SOME 0)) $$))
     | SOME s =>
       (case Int.fromString s of
            NONE => (warn ("Ignoring malformed thread count"); fn x => x)
          | SOME i =>
            (fn (OR r) => OR (updateT r (U #multithread (SOME i)) $$)))
in
val cline_opts = [
  {help = "error if checked for file is absent", long = ["checkerr"],
   short = "e", desc = setStringOpt "message" #checkerr},
  {help = "check file exists afterwards (can repeat)", long = ["checkfor"],
   short = "c", desc = addString "filename"},
  {help = "provide debug output & preserve temp files",
   long = ["dbg"], short = "", desc = mkBoolT #debug},
  {help = "default outputname", long = ["defaultout"], short = "",
   desc = setStringOpt "filename" #defaultout},
  {help = "fn name to be executable's main", long = ["exe"], short = "",
   desc = setStringOpt "fn-name" #exe},
  {help = "pass 'extra data' to code", long = ["extra"], short = "",
   desc = setStringOpt "data" #extra_data},
  {help = "force all object files", long = [], short = "F",
   desc = mkBoolT #all_forced},
  {help = "force file (will load before others)", long = [], short = "f",
   desc = ConsForced},
  {help = "show this message", long = ["help"], short = "h?",
   desc = mkBoolT #help},
  {help = "load holstate as base", long = ["holstate"], short = "b",
   desc = setStringOpt "filename" #base_state},
  {help = "start an LSP server", long = ["lsp"], short = "",
   desc = mkBoolT #lsp},
  {help = "thread count", long = ["mt"], short = "",
   desc = OptArg (set_threadcount, "c")},
  {help = "Don't use user config file in HOL repl", long = ["noconfig"], short = "",
   desc = NoArg (fn () => fn r => r)}, (* checked for and acted on by HOL repl *)
  {help = "output heap/munger name", long = [], short = "o",
   desc = setStringOpt "filename" #output},
  {help = "use poly as base", long = ["poly"], short = "",
   desc = setBaseNone},
  {help = "reduce verbosity", long = ["quiet"], short = "q",
   desc = mkBoolT #quietp},
  {help = "start REPL after loading", long = ["repl"], short = "",
   desc = mkBoolT #repl},
  {help = "use zero-terminated REPL style", long = ["zero"], short = "z",
   desc = mkBoolT #z_repl}
]
val initial_cline = OR {all_forced = false,
                        base_state = !heapname,
                        checkerr = NONE,
                        checkfors = [],
                        debug = false,
                        defaultout = NONE,
                        exe = NONE,
                        extra_data = NONE,
                        forced_objs = [],
                        help = false,
                        lsp = false,
                        multithread = NONE,
                        output = NONE,
                        quietp = false,
                        repl = false,
                        z_repl = false}
end

fun member _ [] = false
  | member s (h::t) = s = h orelse member s t

fun fullPath ps = List.foldl (fn (p,acc) => OS.Path.concat(acc,p))
                             (hd ps) (tl ps);


fun mkAbs p = OS.Path.mkAbsolute {relativeTo = OS.FileSys.getDir(), path = p}

fun findUo [] _ = NONE
  | findUo (search::rest) modPath =
      let val path =
         OS.Path.mkAbsolute
           {path = modPath, relativeTo = OS.Path.mkAbsolute
                                           {path=search,
                                            relativeTo = OS.FileSys.getDir ()}};
      in
        if HOLFileSys.access (path, []) then
          SOME path
        else
          findUo rest modPath
      end;

fun absPath s =
    OS.Path.mkAbsolute{path = s, relativeTo = OS.FileSys.getDir()}

fun check_objpath die incs (p, b) =
  if b then ()
  else
    if member (absPath (OS.Path.dir p)) (SIGOBJ::incs) then ()
    else die ("Object file "^p^" has suspicious path; use -f to override")

fun time_max (t1, t2) = if Time.<(t1,t2) then t2 else t1

fun fix s =
  let
    open OS.Path
    val {base,ext} = splitBaseExt s
  in
    case ext of
        SOME "uo" => base
      | _ => s
  end

fun create_heap diag qp findMod (objs, outputheap) = let
  open Systeml TextIO
  val p = if qp then fn _ => () else fn s => print (s ^ "\n")
  fun hload obj = (p ("Loading "^obj); load (fix obj))
                  handle e => die ("Loading "^obj^": "^General.exnMessage e)
in
  app hload objs;
  p "Sharing common data";
  PolyML.shareCommonData PolyML.rootFunction;
  p ("Writing heap: "^outputheap);
  (* the world as it is, which, restored, runs main again (rune_main) *)
  (case Runtime.save outputheap of
       Runtime.Saved => ()
     | Runtime.Restored => (!rune_main) ());
  p ("Exported "^outputheap^"\n");
  (case OS.Process.getEnv Systeml.build_after_reloc_envvar of
      NONE => ()
    | SOME "1" =>
      let
        val getTime = HOLFileSys.modTime o findMod
        fun foldthis (modname, t0) = time_max(t0, getTime modname)
        val mtime = foldl foldthis Time.zeroTime objs
      in
        diag ("Setting mod-time of heap to "^
              Date.toString (Date.fromTimeLocal mtime));
        HOLFileSys.setTime (outputheap, SOME mtime)
      end
    | SOME s =>
      warn ("Ignoring strange value (" ^ s ^ ") for " ^
            Systeml.build_after_reloc_envvar));
  diag "Having built-heap, now exiting successfully";
  OS.Process.exit OS.Process.success
end

fun maybe_check_load diag (obj,_) =
  let
    open OS.Path
    val {base,ext} = splitBaseExt obj
  in
    case ext of
        SOME "sml" => (diag ("Using "^obj); QUse.use obj)
      | SOME "sig" => (diag ("Using "^obj); QUse.use obj)
      | SOME "ML" => (diag ("Using "^obj); QUse.use obj)
      | SOME "uo" => (diag ("Loading "^obj); load (fix obj))
      | NONE => (diag ("Loading "^obj); load obj)
      | _ => die ("Not sure what to do with 'object file': "^obj)
  end

fun polyprettify s =
  let
    val ss = Substring.full s
    val (pfx,sfx) = Substring.position "Debug options:\n" ss
    fun isNewline c = c = #"\n"
    fun indent ss = "  " ^ Substring.string ss ^ "\n"
    val pfx_fields = Substring.fields isNewline pfx
    val sfx_fields = Substring.fields isNewline sfx
    val sfx_str =
        case sfx_fields of
            [] => ""
          | h::t => Substring.string h ^ "\n" ^ String.concat (map indent t)
  in
    "\nPoly/ML options:\n" ^ String.concat (map indent pfx_fields) ^ sfx_str
  end

val buildheap_extra_data = ref (NONE : string option)

end (* BuildHeap_CLINE struct *)

val buildheap_cline_mt = ref (NONE : int option)

fun main() = let
  open BuildHeap_CLINE
  val usage_header =
    "Usage:\n  " ^ CommandLine.name() ^ " [options] obj1.uo obj2.uo ...\n\n\
    \Object files can be provided with .uo suffixes or not. If they are not\n\
    \present, they will be assumed. \"Object\" files may also be .sml/.ML\n\
    \files which will be used directly (without any dependency analysis being\n\
    \done).\n\n\
    \If a -o option is provided, a heap containing the context generated\n\
    \by loading/executing the .uo files will be dumped. Otherwise, the files\n\
    \are loaded solely for their side effects.\n\n\
    \If a --holstate option is not given, the operation will be with respect\n\
    \to the core HOL state that contains bossLib, lists and sets.\n\n\
    \Forcing a file means that it will be loaded even though it is in a\n\
    \directory not included in the current directory's Holmakefile's INCLUDES\n\
    \specifications.\n\n\
    \Options:"
  val usage =
      GetOpt.usageInfo {header = usage_header,
                        options = cline_opts} ^
      polyprettify (PolyML.rtsArgumentHelp())
  val (cline_upds, objs0) =
      GetOpt.getOpt {argOrder = GetOpt.Permute, options = cline_opts,
                     errFn = die}
                    (CommandLine.arguments())
  val OR options = List.foldl (fn (f, opts) => f opts) initial_cline cline_upds
  val {quietp = qp, output, base_state, all_forced, forced_objs, lsp,
       repl, z_repl, help, debug, extra_data, defaultout, exe, ...} = options
  val diag = if debug then (fn s => warn ("DIAG: "^s)) else (fn _ => ())
  val _ = not help orelse (print usage; OS.Process.exit OS.Process.success)
  val outrepl_error = "Can't simultaneously dump output and start REPL"
  val _ =
      case (lsp orelse repl, output, defaultout) of
          (true, SOME _, _) => die outrepl_error
        | (true, _, SOME _) => die outrepl_error
        | _ => ()
  fun force s = (s, true)
  fun unforce s = (s, false)
  val forced_objs = map force forced_objs
  val objs = if all_forced then forced_objs @ map force objs0
             else forced_objs @ map unforce objs0
  val _ = diag ("#objs = "^Int.toString (length objs))
  val warn = if qp then (fn _ => ()) else warn
  val original_die = die
  fun die s = if qp then OS.Process.exit OS.Process.failure else original_die s
  val allincs = ReadHMF.find_includes (OS.FileSys.getDir())
  (* Poly/ML extends loadPath and then loadState replaces the process, so
     the extension remains only for --poly. Rune has already restored the
     image, and prelude.ML extends the path again: doing it here too put
     tools/cmp on the REPL's loadPath twice (3 entries, Poly/ML has 2). *)
  val _ =
      case base_state of
          NONE =>
            ReadHMF.extend_path_with_includes
              {verbosity = 1 + (if debug then 1 else 0),
               lpref = Meta.loadPath}
        | SOME _ => ()
  val _ = diag ("allincs = ["^String.concatWith ", " allincs ^"]")
  val base_state = Option.map mkAbs base_state
  val output = Option.map mkAbs output
  val output = case output of NONE => Option.map mkAbs defaultout | _ => output
  val _ = case (output, exe) of
              (NONE, SOME _) => die "Can't have exe without an output"
            | _ => ()
  val _ =
      case base_state of
          NONE => (diag "Not loading a base state"; heapname := NONE)
        | SOME f => (diag ("Base-state "^f^", which bin/buildheap restored");
                     heapname := SOME f)
  val _ = buildheap_extra_data := extra_data
  val _ = diag ("Buildheap extra now = " ^
                (case !buildheap_extra_data of
                     NONE => "NONE"
                   | SOME s => "SOME(\"" ^ s ^"\")"))
  val exts = holpathdb.search_for_extensions ReadHMF.find_includes
               {skip = Binaryset.empty String.compare,
                starter_dirs = [OS.FileSys.getDir()]}
  fun print_ext{vname,path} = vname ^ " |-> " ^ path
  val _ = diag ("holpathdb extensions: "^
                String.concatWith ", " (map print_ext exts))
  val _ = List.app holpathdb.extend_db exts
in
  case (output, exe) of
      (SOME s, NONE) =>
      let
        val _ = List.app (check_objpath die (absPath "." :: allincs)) objs
        val search_these =
            "." :: OS.Path.concat(Systeml.HOLDIR, "sigobj") :: allincs
        fun findmod s =
          case findUo search_these (s ^ ".uo") of
              NONE => die ("In "^OS.FileSys.getDir()^": couldn't find "^s^
                           ".uo\n\
                           \After searching: " ^
                           String.concatWith ", " search_these)
            | SOME p => p
      in
        heapname := SOME s;
        create_heap diag qp findmod (map #1 objs, s)
      end
    | _ =>
      let
      in
        case #multithread options of
            NONE => ()
          | SOME i => buildheap_cline_mt := SOME i;
        List.app
          (maybe_check_load diag)
          ((case #multithread options of
                NONE => []
              | SOME _ => [("poly_decide_threadcount.uo", false)]) @
           objs);
        if lsp then
          LSPServer.start {diag = diag}
        else if repl then
          (diag "Starting REPL";
           PolyML.print_depth 100;
           HOL_REPL.sigint_handler();
           HOL_REPL.topLevel {diag = diag, zeroTerm = z_repl} )
        else
          case exe of
              SOME f => BuildHeap_EXE_Compile.exe_compile
                          {fnname = f, output_exe = valOf output,
                           keep_temp_files = debug}
            | _ => ();
        List.app (fn s => if HOLFileSys.access(s, [HOLFileSys.A_READ]) then ()
                          else die ("Couldn't find required output file: "^s ^
                                    (case #checkerr options of
                                         NONE => ""
                                       | SOME s => "\n" ^ s)))
                 (#checkfors options);
        diag "Buildheap done; about to exit successfully";
        OS.Process.exit OS.Process.success
      end
end handle e =>
      BuildHeap_CLINE.die ("Uncaught exception" ^
        (case PolyML.Exception.exceptionLocation e of
            NONE => ""
          | SOME {file, startLine, ...} => " at " ^ file ^ ":" ^ FixedInt.toString startLine) ^
        ": " ^ General.exnMessage e)

val () = rune_main := main
