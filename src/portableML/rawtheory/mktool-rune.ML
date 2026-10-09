(* mktool.ML for Rune: what tools-rune/bin/polyc makes theorytool of, with
   tools-rune's start of HOL's top level and ../rune's files where mktool.ML
   has Poly/ML's, which use its threads *)
val origdir = OS.FileSys.getDir();
OS.FileSys.chDir "../../..";
val _ = use "tools-rune/rune-init.ML";
OS.FileSys.chDir origdir;

structure BasicIO = SML90;
exception Interrupt = SML90.Interrupt;

use "../../../tools/Holmake/hmcore.ML";

fun useB s = (use (s ^ ".sig"); use (s ^ ".sml"));

use "../rune/PrettyImpl.sml";
use "../quotation_dtype.sml";
useB "../Uref";
useB "../HOLPP";
useB "../UTF8";
useB "../OldPP";
useB "../rune/Arbnumcore";
useB "../Arbnum";
useB "../rune/Exn";
useB "../HOLquotation";
useB "../rune/MD5";
useB "../rune/Susp";
useB "../rune/Unsynchronized";
use  "../rune/MLSYSPortable.sml";
useB "../Portable";
use  "../Table.sml";
useB "../AList";
use  "../Graph.sml";

(* mlyacc cruft *)
fun MLYuse s = use ("../../../tools/mlyacc/mlyacclib/MLY_" ^ s ^ ".sml");
MLYuse "base-sig";
MLYuse "join";
MLYuse "lrtable";
MLYuse "stream";
MLYuse "parser2";

use  "../HOLsexp_dtype.sml";

use  "../HOLsexp.grm-sig.sml";
use  "../HOLsexp.grm.sml";
use  "../HOLsexp.lex.sml";
useB "../HOLsexp_parser";
useB "../HOLsexp";
use  "RawTheory_dtype.sml";
useB "RawTheoryReader";

useB "../rune/SHA1_ML";
useB "../SHA1";

use "theorystats.sml";
use "theorytool.ML";
