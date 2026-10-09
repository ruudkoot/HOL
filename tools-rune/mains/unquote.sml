(* The quotation filter's main, for Rune (as
   tools/quote-filter/poly-unquote.ML, without its signal handler: Rune's
   programs end at SIGINT unless they catch it) *)
local
  open OS.Process
  val {instrm, outstrm, interactive, quotefixp, quietOpen, closefn, infilename} =
      qfilter_util.processArgs (false, false, false, false) (CommandLine.arguments ())
  fun read _ = TextIO.input instrm
  fun write s = TextIO.output (outstrm, s)
  val () =
    if quotefixp then quotefix.run read write
    else
      let
        open HolParser.ToSML
        val read = mkPushTranslator {
          read = read,
          filename = infilename,
          parseError = fn (start, stop) => fn s =>
            TextIO.output (TextIO.stdErr,
              "parse error at " ^ Int.toString start ^ "-" ^ Int.toString stop ^ ": " ^ s ^ "\n"),
          quietOpen = quietOpen
        } (mkStrcode write)
        fun loop () = if read () then () else loop ()
      in loop () end
in
  val () = (closefn (); exit success)
end
