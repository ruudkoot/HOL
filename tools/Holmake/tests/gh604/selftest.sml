open testutils
val _ = tprint "Test loadPath initialisation over multiple INCLUDES links"
val _ = OS.FileSys.chDir "final"
fun HOL s = OS.Path.concat(Globals.HOLDIR, s)
val holswitch =
    if Systeml.ML_SYSNAME = "poly" orelse Systeml.ML_SYSNAME = "rune" then
      " --noconfig"
    else ""
val res = OS.Process.system
            (Systeml.protect (HOL "bin/hol.bare") ^ holswitch ^
             " < ../testfile.ML")

val _ = if OS.Process.isSuccess res then OK() else die""
