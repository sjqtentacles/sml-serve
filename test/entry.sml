(* entry.sml -- defines `main`, the MLton entry point for the test binary.

   Runs the loopback integration suite, prints the harness summary, and exits
   non-zero if any check failed. (MLton-only: there is no Poly/ML build here,
   because the adapter is impure and socket-bound.) *)

fun runAllSuites () =
  ( Harness.reset ()
  ; JsonBoundaryTests.run ()
  ; IntegrationTests.run ()
  ; Harness.run () )

fun main () =
  OS.Process.exit
    (if runAllSuites () then OS.Process.success else OS.Process.failure)
