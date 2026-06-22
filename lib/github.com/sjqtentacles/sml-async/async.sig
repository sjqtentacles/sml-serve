(* async.sig

   The async monad: an `'a async` is a recipe for an asynchronous
   computation that, when run on a Scheduler, eventually produces an
   `'a` (or fails). It is the ergonomic, composable surface over Futures.

   Representation is continuation-passing: an `'a async` is a function that,
   given the scheduler and a continuation expecting an `'a result`, arranges
   to eventually call that continuation. This keeps composition cheap and
   avoids allocating a future per intermediate step.

   `infix >>=` is provided for chaining; open Async or use Async.>>= with a
   local `infix` declaration to get the operator. *)

signature ASYNC =
sig
  type 'a async

  (* --- Constructing --- *)

  val return    : 'a -> 'a async
  val fail      : exn -> 'a async

  (* Lift a thunk; any exception it raises becomes a failure. *)
  val delay     : (unit -> 'a) -> 'a async

  (* Suspend for `n` logical ticks, then continue. *)
  val sleep     : int -> unit async

  (* --- Sequencing --- *)

  val bind      : 'a async -> ('a -> 'b async) -> 'b async
  val >>=       : 'a async * ('a -> 'b async) -> 'b async
  val andThen   : 'a async -> 'b async -> 'b async   (* discard first result *)
  val map       : ('a -> 'b) -> 'a async -> 'b async

  (* --- Error handling --- *)

  val mapError  : (exn -> exn) -> 'a async -> 'a async
  val recover   : 'a async -> (exn -> 'a async) -> 'a async

  (* --- Combining --- *)

  val both      : 'a async * 'b async -> ('a * 'b) async
  val all       : 'a async list -> 'a list async
  val race      : 'a async list -> 'a async

  (* --- Future interop --- *)

  val fromFuture: 'a Future.future -> 'a async
  val toFuture  : Scheduler.t -> 'a async -> 'a Future.future

  (* --- Running --- *)

  (* Start the computation on the scheduler, returning a future for its
     result. Does NOT drive the scheduler; call Scheduler.run yourself. *)
  val start     : Scheduler.t -> 'a async -> 'a Future.future

  (* Convenience: start on a fresh scheduler, run it to completion, and
     return the final result. Raises if the computation never resolves. *)
  val runToCompletion : 'a async -> 'a AsyncResult.result
end
