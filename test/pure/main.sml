(* main.sml -- top-level invocation for MLton's pure test binary.

   Poly/ML's `tools/polybuild` skips any file named `main.sml` and runs the
   exported `main` instead; MLton needs this explicit top-level call. *)

val () = main ()
