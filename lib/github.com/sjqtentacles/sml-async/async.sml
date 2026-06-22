(* async.sml

   Implementation of ASYNC.

   An `'a async` is `Scheduler.t -> ('a result -> unit) -> unit`: given the
   engine and a continuation, it arranges for the continuation to be called
   with the eventual result. Combinators thread the scheduler through and
   compose continuations.

   `both`, `all`, and `race` are defined by reusing the Future combinators:
   we run each sub-computation into a future and combine those. *)

structure Async :> ASYNC =
struct
  structure R = AsyncResult
  structure F = Future

  type 'a async = Scheduler.t -> ('a R.result -> unit) -> unit

  fun return x = fn _ => fn k => k (R.ok x)
  fun fail e = fn _ => fn k => k (R.error e)

  fun delay thunk = fn _ => fn k => k (R.capture thunk)

  fun bind (a : 'a async) (g : 'a -> 'b async) : 'b async =
    fn s => fn k =>
      a s (fn r =>
            case r of
                R.Error e => k (R.error e)
              | R.Ok x =>
                  (case R.capture (fn () => g x) of
                       R.Error e => k (R.error e)
                     | R.Ok next => next s k))

  fun op >>= (a, g) = bind a g

  fun map g a = bind a (fn x => return (g x))

  fun andThen a b = bind a (fn _ => b)

  fun mapError g (a : 'a async) : 'a async =
    fn s => fn k => a s (fn r => k (R.mapError g r))

  fun recover (a : 'a async) (h : exn -> 'a async) : 'a async =
    fn s => fn k =>
      a s (fn r =>
            case r of
                R.Ok x => k (R.ok x)
              | R.Error e =>
                  (case R.capture (fn () => h e) of
                       R.Error e2 => k (R.error e2)
                     | R.Ok next => next s k))

  fun sleep n = fn s => fn k =>
    (Scheduler.after s n (fn () => k (R.ok ())); ())

  fun fromFuture (fut : 'a F.future) : 'a async =
    fn _ => fn k => F.onComplete fut k

  (* Run an async into a fresh future on the given scheduler. *)
  fun start s (a : 'a async) : 'a F.future =
    let
      val (p, fut) = F.promise s
    in
      a s (fn r => F.complete p r);
      fut
    end

  fun toFuture s a = start s a

  fun both (a, b) =
    fn s => fn k =>
      let
        val fa = start s a
        val fb = start s b
      in
        F.onComplete (F.both (fa, fb)) k
      end

  fun all (xs : 'a async list) : 'a list async =
    fn s => fn k =>
      (case xs of
           [] => k (R.ok [])
         | _ =>
             let val futs = List.map (fn a => start s a) xs
             in F.onComplete (F.all futs) k end)

  fun race (xs : 'a async list) : 'a async =
    fn s => fn k =>
      (case xs of
           [] => k (R.error Empty)
         | _ =>
             let val futs = List.map (fn a => start s a) xs
             in F.onComplete (F.race futs) k end)

  fun runToCompletion (a : 'a async) : 'a R.result =
    let
      val s = Scheduler.new ()
      val fut = start s a
      val () = Scheduler.run s
    in
      case F.peek fut of
          SOME r => r
        | NONE => raise Fail "Async.runToCompletion: computation never resolved"
    end
end
