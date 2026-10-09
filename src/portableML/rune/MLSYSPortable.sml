(* What HOL asks of the ML system, on Rune (tools-rune/README.md): Poly/ML's
   (../poly/MLSYSPortable.sml) with Rune's interrupts and pointer
   equality, and, as Moscow ML's, a counter and a reference without
   threads, Rune having none. *)
structure MLSYSPortable =
struct

exception Interrupt = SML90.Interrupt

fun listDir s =
   let
      val ds = OS.FileSys.openDir s
      fun recurse acc =
         case OS.FileSys.readDir ds of
            NONE => acc
          | SOME f => recurse (f :: acc)
   in
      recurse [] before OS.FileSys.closeDir ds
   end

fun pointer_eq (x: 'a, y: 'a) = Runtime.same (x, y)
fun ref_to_int (x: 'a ref) = 0 (* as Poly/ML's *)

fun catch_SIGINT () = ignore (Runtime.catchInterrupt ())

fun md5sum s =
   let
      val mstate = MD5.update (MD5.init, Byte.stringToBytes s)
      val hash = MD5.final mstate
   in
      MD5.toBase64String hash
   end

fun time f x =
   let
      fun p t =
        let
           val s = Time.fmt 3 t
        in
           case size (List.last (String.fields (fn x => x = #".") s)) of
              3 => s
            | 2 => s ^ "0"
            | 1 => s ^ "00"
            | _ => raise Fail "mlibPortable.time"
        end
      val c = Timer.startCPUTimer ()
      val r = Timer.startRealTimer ()
      fun pt () =
         let
            val {usr, sys} = Timer.checkCPUTimer c
            val gc = Timer.checkGCTime c
            val real = Timer.checkRealTimer r
         in
            print ("User: " ^ p usr ^ "  System: " ^ p sys ^
                   "  GC: " ^ p gc ^ "  Real: " ^ p real ^ "\n")
         end
      val y = f x handle e => (pt (); raise e)
      val () = pt ()
   in
      y
   end

structure HOLSusp = Susp

fun reraise e = raise e

fun make_counter {inc,init} =
  let
    val n = ref init
  in
    fn () => !n before n := !n + inc
  end

fun syncref init =
  let
    val r = ref init
  in
    { get = fn() => !r,
      upd = fn f => let val (res,nv) = f (!r) in r := nv; res end
    }
  end

end
