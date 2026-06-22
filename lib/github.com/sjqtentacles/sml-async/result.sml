(* result.sml

   A small success/failure carrier so futures and the async monad can
   propagate errors as values rather than relying on exceptions crossing
   callback (and scheduler) boundaries.

   Errors are carried as `exn`, which is SML's open, extensible sum type:
   any module can introduce its own error constructors without this core
   needing to know about them. *)

structure AsyncResult :>
sig
  datatype 'a result = Ok of 'a | Error of exn

  val ok      : 'a -> 'a result
  val error   : exn -> 'a result

  val isOk    : 'a result -> bool
  val isError : 'a result -> bool

  (* Project out the success value, raising the carried exn on Error. *)
  val get     : 'a result -> 'a

  val map     : ('a -> 'b) -> 'a result -> 'b result
  val mapError: (exn -> exn) -> 'a result -> 'a result
  val bind    : 'a result -> ('a -> 'b result) -> 'b result

  (* Run f, capturing any raised exception as Error. *)
  val capture : (unit -> 'a) -> 'a result
end =
struct
  datatype 'a result = Ok of 'a | Error of exn

  fun ok x = Ok x
  fun error e = Error e

  fun isOk (Ok _) = true
    | isOk _ = false

  fun isError r = not (isOk r)

  fun get (Ok x) = x
    | get (Error e) = raise e

  fun map f (Ok x) = Ok (f x)
    | map _ (Error e) = Error e

  fun mapError _ (Ok x) = Ok x
    | mapError f (Error e) = Error (f e)

  fun bind (Ok x) f = f x
    | bind (Error e) _ = Error e

  fun capture f = Ok (f ()) handle e => Error e
end
