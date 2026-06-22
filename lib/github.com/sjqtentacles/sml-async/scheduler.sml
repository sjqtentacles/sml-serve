(* scheduler.sml

   Implementation of SCHEDULER.

   Data structures (chosen for portability and clarity over raw speed):

     - ready: a queue of thunks held as a pair of lists (front, back) so
       enqueue is O(1) on `back` and dequeue is amortised O(1) from `front`.
     - timers: a list kept sorted by (time, seq), where `seq` is a global
       insertion counter that makes ordering total and deterministic even
       when two timers share a logical time.

   Determinism guarantees:
     - thunks enqueued with `soon` run in FIFO order;
     - timers at the same logical time fire in the order they were created;
     - the clock only advances when there is no ready work, and only to the
       time of the earliest pending timer. *)

structure Scheduler :> SCHEDULER =
struct
  type time = int
  val zeroTime = 0
  fun timeToInt t = t
  fun timeFromInt n = n
  fun timeLess (a, b) = a < b
  fun timeAdd (t, d) = t + d

  (* A timer carries a unique id (for cancellation), its fire time, an
     insertion sequence number (for stable ordering), and the action.
     `cancelled` lets us cancel in O(1) and simply skip it when popped. *)
  type timer = { id : int
               , time : time
               , seq : int
               , action : unit -> unit
               , cancelled : bool ref }

  type t = { clock : time ref
           , front : (unit -> unit) list ref
           , back  : (unit -> unit) list ref
           , timers : timer list ref      (* sorted ascending by (time, seq) *)
           , nextId : int ref
           , nextSeq : int ref }

  fun new () : t =
    { clock = ref zeroTime
    , front = ref []
    , back = ref []
    , timers = ref []
    , nextId = ref 0
    , nextSeq = ref 0 }

  fun now (s : t) = !(#clock s)

  fun soon (s : t) thunk =
    #back s := thunk :: !(#back s)

  (* Pop the next ready thunk, refilling `front` from reversed `back`. *)
  fun popReady (s : t) : (unit -> unit) option =
    case !(#front s) of
        (x :: xs) => (#front s := xs; SOME x)
      | [] =>
          (case List.rev (!(#back s)) of
               [] => NONE
             | (x :: xs) => (#front s := xs; #back s := []; SOME x))

  fun hasReady (s : t) =
    not (List.null (!(#front s))) orelse not (List.null (!(#back s)))

  (* Insert a timer into the sorted timer list, keyed on (time, seq). *)
  fun insertTimer (s : t) (timer : timer) =
    let
      fun precedes (a : timer, b : timer) =
        (#time a) < (#time b)
        orelse ((#time a) = (#time b) andalso (#seq a) < (#seq b))
      fun ins [] = [timer]
        | ins (t :: ts) =
            if precedes (timer, t) then timer :: t :: ts
            else t :: ins ts
    in
      #timers s := ins (!(#timers s))
    end

  fun at (s : t) when action =
    let
      val () = if timeLess (when, now s)
               then raise Fail "Scheduler.at: time is in the past"
               else ()
      val id = !(#nextId s)
      val seq = !(#nextSeq s)
      val () = #nextId s := id + 1
      val () = #nextSeq s := seq + 1
      val timer = { id = id, time = when, seq = seq
                  , action = action, cancelled = ref false }
      val () = insertTimer s timer
    in
      timer
    end

  fun after (s : t) delay action =
    if delay < 0 then raise Fail "Scheduler.after: negative delay"
    else at s (timeAdd (now s, delay)) action

  fun cancel (timer : timer) =
    (#cancelled timer) := true

  (* Drop already-cancelled timers from the front of the (sorted) list. *)
  fun dropCancelled (s : t) =
    let
      fun loop [] = []
        | loop (t :: ts) = if !(#cancelled t) then loop ts else t :: ts
    in
      #timers s := loop (!(#timers s))
    end

  fun isIdle (s : t) =
    (dropCancelled s; not (hasReady s) andalso List.null (!(#timers s)))

  (* Advance the clock to the next live timer and move its action onto the
     ready queue. Returns true if a timer was promoted, false if none remain. *)
  fun fireNextTimer (s : t) : bool =
    (dropCancelled s;
     case !(#timers s) of
         [] => false
       | (t :: ts) =>
           ( #timers s := ts
           ; #clock s := (#time t)
           ; soon s (#action t)
           ; true ))

  (* Run a single ready thunk if one exists (promoting a timer first if the
     ready queue is empty). Returns true if a thunk ran. *)
  fun step (s : t) : bool =
    case popReady s of
        SOME thunk => (thunk (); true)
      | NONE =>
          if fireNextTimer s then
            (case popReady s of
                 SOME thunk => (thunk (); true)
               | NONE => false)
          else false

  fun run (s : t) =
    if step s then run s else ()

  fun runSteps (s : t) maxSteps =
    let
      fun loop n =
        if n >= maxSteps then n
        else if step s then loop (n + 1)
        else n
    in
      loop 0
    end
end
