(* scheduler.sig

   The scheduler is the engine that drives all async work. It owns:

     - a FIFO ready-queue of `unit -> unit` thunks to run as soon as possible;
     - a set of timers, each scheduled at a logical time, ordered so the
       earliest fires first (ties broken by insertion order for determinism);
     - a logical clock (an abstract, monotonic time) that only ever advances
       when the ready-queue is empty and a timer needs to fire.

   There is deliberately no wall-clock time and no OS I/O: time is a pure,
   logical quantity, which makes every program built on top fully
   deterministic and reproducible. *)

signature SCHEDULER =
sig
  type t

  (* A logical instant. Larger is later. *)
  eqtype time
  val zeroTime : time
  val timeToInt : time -> int
  val timeFromInt : int -> time
  val timeLess : time * time -> bool
  val timeAdd : time * int -> time

  (* A handle to a scheduled timer, so it can be cancelled before it fires. *)
  type timer

  val new : unit -> t

  (* Current logical time. Starts at zeroTime, advances monotonically. *)
  val now : t -> time

  (* Enqueue a thunk to run as soon as possible, after already-ready work. *)
  val soon : t -> (unit -> unit) -> unit

  (* Run a thunk at an absolute logical time (>= now). Returns a cancel handle. *)
  val at : t -> time -> (unit -> unit) -> timer

  (* Run a thunk after `delay` ticks from now (delay >= 0). *)
  val after : t -> int -> (unit -> unit) -> timer

  (* Cancel a timer if it has not yet fired. Idempotent. *)
  val cancel : timer -> unit

  (* Are there no ready thunks and no pending timers? *)
  val isIdle : t -> bool

  (* Run until idle: drain ready thunks, advancing the clock to the next
     timer whenever the ready-queue empties, until nothing remains. *)
  val run : t -> unit

  (* Run at most `steps` ready-thunk executions (advancing the clock as
     needed between them). Returns the number of steps actually performed.
     Useful for stepping through execution in tests. *)
  val runSteps : t -> int -> int
end
