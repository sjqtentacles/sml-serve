(* query.sig

   application/x-www-form-urlencoded query strings: a list of key/value
   pairs preserving order and duplicates. Parsing decodes percent-escapes
   and '+'; building re-encodes them. *)

signature QUERY =
sig
  type query = (string * string) list

  (* Parse a query string (without a leading '?'). Empty string -> []. A
     bare key "a" (no '=') yields ("a", ""). *)
  val parse  : string -> query
  (* Serialize to "k1=v1&k2=v2" with form-encoding. *)
  val build  : query -> string

  (* First value for a key, if present. *)
  val get    : query -> string -> string option
  (* All values for a key, in order. *)
  val getAll : query -> string -> string list
end
