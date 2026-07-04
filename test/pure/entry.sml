(* test/poly_entry.sml -- entry point for the PURE, dual-compiler test binary.

   The main test binary (entry.sml) drives the impure, socket-bound loopback
   integration suite and is therefore MLton-only. This entry runs only the
   PURE suites -- currently the vendored sml-json integer-boundary checks --
   which are deterministic `string -> string` computations with no sockets,
   clock, or OS I/O. That makes them portable to Poly/ML, so their output is
   byte-identical across MLton and Poly/ML and can be diffed directly (the same
   guarantee the rest of the sjqtentacles stack provides). *)

fun runPureSuites () =
  ( Harness.reset ()
  ; JsonBoundaryTests.run ()
  ; Harness.run () )

fun main () =
  OS.Process.exit
    (if runPureSuites () then OS.Process.success else OS.Process.failure)
