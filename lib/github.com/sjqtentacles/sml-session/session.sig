(* session.sig

   Pure session handling, two backends sharing one data model.

   A `session` is an ordered string -> string map (insertion order preserved,
   last write wins). Helpers `get`/`put`/`remove`/`toList`/`fromList` are pure.

   Backends:
   - `Memory`: a server-side store keyed by session id. `create` mints a fresh
     id from an sml-random generator; the store is an immutable value threaded
     through `load`/`save`/`destroy`. Good for tests and single-process apps.
   - `SignedCookie`: stateless. The whole session is JSON-serialized and stored
     in an HMAC-signed cookie value (sml-crypto); `decode` verifies and parses
     it back, rejecting tampered payloads. No server storage. *)

signature SESSION =
sig
  type session

  val empty   : session
  val get     : session -> string -> string option
  val put     : session -> string -> string -> session
  val remove  : session -> string -> session
  val toList  : session -> (string * string) list
  val fromList : (string * string) list -> session

  (* JSON round-trip used by the cookie backend (also handy directly). *)
  val toJson   : session -> string
  val fromJson : string -> session option

  structure Memory :
  sig
    type store
    val empty   : store
    (* Mint a fresh session id (hex token) and store the given session. *)
    val create  : store -> Random.t -> session -> string * store * Random.t
    val load    : store -> string -> session option
    val save    : store -> string -> session -> store
    val destroy : store -> string -> store
  end

  structure SignedCookie :
  sig
    (* key -> session -> signed cookie value (use as a Set-Cookie value). *)
    val encode : string -> session -> string
    (* key -> cookie value -> SOME session if signature + JSON are valid. *)
    val decode : string -> string -> session option
  end
end
