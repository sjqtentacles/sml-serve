(* future.sml

   Implementation of FUTURE.

   A future is a ref to one of:
     - Pending cbs : a list of callbacks awaiting resolution (stored reversed,
       i.e. most-recently-added first; we reverse on resolution so callbacks
       fire in registration order);
     - Done r      : the final result.

   On resolution we flip the state to `Done` and schedule each callback via
   `Scheduler.soon`, so callbacks always run asynchronously and in a
   deterministic order. A future also remembers its scheduler so derived
   futures (map/bind/...) stay on the same engine. *)

structure Future :> FUTURE =
struct
  structure R = AsyncResult

  datatype 'a state =
      Pending of ('a R.result -> unit) list
    | Done of 'a R.result

  type 'a future = { sched : Scheduler.t, state : 'a state ref }
  type 'a promise = 'a future   (* same cell; promise = write view *)

  fun scheduler (f : 'a future) = #sched f

  fun promise sched =
    let val f = { sched = sched, state = ref (Pending []) }
    in (f, f) end

  fun peek (f : 'a future) =
    case !(#state f) of
        Done r => SOME r
      | Pending _ => NONE

  fun isResolved f = Option.isSome (peek f)

  fun onComplete (f : 'a future) cb =
    case !(#state f) of
        Done r => Scheduler.soon (#sched f) (fn () => cb r)
      | Pending cbs => #state f := Pending (cb :: cbs)

  (* Write-once. Schedules all waiting callbacks in registration order. *)
  fun complete (f : 'a promise) (r : 'a R.result) =
    case !(#state f) of
        Done _ => raise Fail "Future: promise already completed"
      | Pending cbs =>
          ( #state f := Done r
          ; List.app (fn cb => Scheduler.soon (#sched f) (fn () => cb r))
                     (List.rev cbs) )

  fun fulfil p x = complete p (R.ok x)
  fun reject p e = complete p (R.error e)

  fun fromResult sched r =
    let val (p, f) = promise sched in complete p r; f end

  fun resolved sched x = fromResult sched (R.ok x)
  fun failed sched e = fromResult sched (R.error e)

  fun map g f =
    let
      val (p, out) = promise (#sched f)
    in
      onComplete f (fn r => complete p (R.map g r));
      out
    end

  fun mapError g f =
    let
      val (p, out) = promise (#sched f)
    in
      onComplete f (fn r => complete p (R.mapError g r));
      out
    end

  fun bind f g =
    let
      val (p, out) = promise (#sched f)
    in
      onComplete f
        (fn r =>
          case r of
              R.Error e => complete p (R.error e)
            | R.Ok x =>
                (* g may itself raise synchronously; capture that too. *)
                (case R.capture (fn () => g x) of
                     R.Error e => complete p (R.error e)
                   | R.Ok inner => onComplete inner (fn r2 => complete p r2)));
      out
    end

  fun recover f handler =
    let
      val (p, out) = promise (#sched f)
    in
      onComplete f
        (fn r =>
          case r of
              R.Ok x => complete p (R.ok x)
            | R.Error e =>
                (case R.capture (fn () => handler e) of
                     R.Error e2 => complete p (R.error e2)
                   | R.Ok inner => onComplete inner (fn r2 => complete p r2)));
      out
    end

  fun both (fa : 'a future, fb : 'b future) =
    let
      val (p, out) = promise (#sched fa)
      val slotA : 'a option ref = ref NONE
      val slotB : 'b option ref = ref NONE
      val finished = ref false

      fun fail e = if !finished then ()
                   else (finished := true; complete p (R.error e))

      fun tryFinish () =
        case (!slotA, !slotB) of
            (SOME a, SOME b) =>
              if !finished then ()
              else (finished := true; complete p (R.ok (a, b)))
          | _ => ()
    in
      onComplete fa (fn R.Ok a => (slotA := SOME a; tryFinish ())
                      | R.Error e => fail e);
      onComplete fb (fn R.Ok b => (slotB := SOME b; tryFinish ())
                      | R.Error e => fail e);
      out
    end

  fun all [] =
        (* No scheduler available with an empty list; callers should avoid
           this, but we need *some* engine. Raise a clear error instead of
           guessing. *)
        raise Fail "Future.all: empty list has no scheduler (use resolved s [])"
    | all (first :: rest : 'a future list) =
        let
          val fs = first :: rest
          val n = List.length fs
          val (p, out) = promise (#sched first)
          val slots : 'a option array = Array.array (n, NONE)
          val remaining = ref n
          val finished = ref false

          fun fail e = if !finished then ()
                       else (finished := true; complete p (R.error e))

          fun collect () =
            let
              fun loop i acc =
                if i < 0 then acc
                else case Array.sub (slots, i) of
                         SOME v => loop (i - 1) (v :: acc)
                       | NONE => loop (i - 1) acc  (* unreachable when done *)
            in loop (n - 1) [] end

          fun fill i v =
            ( Array.update (slots, i, SOME v)
            ; remaining := !remaining - 1
            ; if !remaining = 0 andalso not (!finished)
              then (finished := true; complete p (R.ok (collect ())))
              else () )

          fun wire (i, f) =
            onComplete f (fn R.Ok v => fill i v | R.Error e => fail e)

          fun wireAll _ [] = ()
            | wireAll i (f :: fs') = (wire (i, f); wireAll (i + 1) fs')
        in
          wireAll 0 fs;
          out
        end

  fun race [] = raise Empty
    | race (first :: rest) =
        let
          val fs = first :: rest
          val (p, out) = promise (#sched first)
          val finished = ref false
          fun settle r = if !finished then ()
                         else (finished := true; complete p r)
        in
          List.app (fn f => onComplete f settle) fs;
          out
        end
end
