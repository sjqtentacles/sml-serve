(* future.sig

   A future is a write-once placeholder for a value that becomes available
   later. A promise is the write capability for a future: you hand out the
   future to consumers and keep the promise to fulfil it.

   Every future carries an `'a AsyncResult.result`, so it represents either
   eventual success or eventual failure.

   Callbacks registered on a future are never invoked synchronously at
   registration or resolution time; they are scheduled via the owning
   Scheduler. This keeps evaluation order deterministic and stack-safe. *)

signature FUTURE =
sig
  type 'a future
  type 'a promise

  (* --- Creating --- *)

  (* A fresh unresolved promise/future pair bound to a scheduler. *)
  val promise   : Scheduler.t -> 'a promise * 'a future

  (* Already-resolved futures. *)
  val resolved  : Scheduler.t -> 'a -> 'a future
  val failed    : Scheduler.t -> exn -> 'a future
  val fromResult: Scheduler.t -> 'a AsyncResult.result -> 'a future

  (* --- Fulfilling a promise (write-once; second write raises) --- *)

  val fulfil    : 'a promise -> 'a -> unit
  val reject    : 'a promise -> exn -> unit
  val complete  : 'a promise -> 'a AsyncResult.result -> unit

  (* --- Inspecting --- *)

  val isResolved: 'a future -> bool
  val peek      : 'a future -> 'a AsyncResult.result option
  val scheduler : 'a future -> Scheduler.t

  (* Register a callback to run (via the scheduler) once resolved.
     If already resolved, the callback is scheduled soon. *)
  val onComplete: 'a future -> ('a AsyncResult.result -> unit) -> unit

  (* --- Transforming --- *)

  (* map/bind only fire on success; an upstream Error propagates unchanged. *)
  val map       : ('a -> 'b) -> 'a future -> 'b future
  val bind      : 'a future -> ('a -> 'b future) -> 'b future
  val mapError  : (exn -> exn) -> 'a future -> 'a future

  (* Recover from failure by mapping any Error into a fresh future. *)
  val recover   : 'a future -> (exn -> 'a future) -> 'a future

  (* --- Combining --- *)

  (* Succeeds with both values; fails as soon as either side fails. *)
  val both      : 'a future * 'b future -> ('a * 'b) future

  (* Wait for all; succeeds with all values in order, or fails with the
     first error (by resolution order). Empty list succeeds with []. *)
  val all       : 'a future list -> 'a list future

  (* First future to resolve (success OR failure) wins. Requires a
     non-empty list; raises Empty otherwise. Needs a scheduler, taken from
     the first future. *)
  val race      : 'a future list -> 'a future
end
