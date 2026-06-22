(* forms.sig

   Decode form/query/JSON inputs into typed values with a validation
   applicative that *accumulates* errors (rather than failing on the first).

   The core is `'a validation = Valid of 'a | Invalid of error list`. Field
   readers pull a named value from a source and coerce it; `and2`/`and3`/...
   combine independent readers, collecting every field error before reporting.

   Sources are normalized to `(string -> string option)` lookups, so the same
   readers work over `application/x-www-form-urlencoded` bodies, query strings,
   or flattened JSON objects. *)

signature FORMS =
sig
  type error = { field : string, message : string }

  datatype 'a validation = Valid of 'a | Invalid of error list

  type source = string -> string option   (* field name -> raw value *)

  (* Build a source from key/value pairs (first value wins). *)
  val fromPairs : (string * string) list -> source
  (* Parse "a=1&b=2" (urlencoded) into a source via sml-uri. *)
  val fromUrlEncoded : string -> source
  (* Build a source from a flat JSON object's string/number/bool members. *)
  val fromJson : Json.json -> source

  (* Field readers. Each yields a `validation`. *)
  val string  : source -> string -> string validation        (* required *)
  val int     : source -> string -> int validation           (* required, strict *)
  val bool    : source -> string -> bool validation
  val optional : source -> string -> string option validation (* always Valid *)
  val default : string -> source -> string -> string validation

  (* Applicative combinators (errors accumulate). *)
  val map  : ('a -> 'b) -> 'a validation -> 'b validation
  val and2 : 'a validation * 'b validation -> ('a * 'b) validation
  val and3 : 'a validation * 'b validation * 'c validation -> ('a * 'b * 'c) validation
  val and4 : 'a validation * 'b validation * 'c validation * 'd validation
             -> ('a * 'b * 'c * 'd) validation

  (* Lift a pure value / a single error. *)
  val pure  : 'a -> 'a validation
  val fail  : string -> string -> 'a validation   (* field, message *)

  val isValid : 'a validation -> bool
  val errors  : 'a validation -> error list
end
