(* Restoring this image continues here, then buildheap's main takes the
   new arguments (bin/buildheap -b holfoot.state ...). *)
val _ = PolyML.shareCommonData PolyML.rootFunction
val _ =
  case Runtime.save "holfoot.state" of
      Runtime.Saved => ()
    | Runtime.Restored => (!rune_main) ()
