(* headers.sig

   A case-insensitive HTTP header collection (RFC 9110 field names are
   case-insensitive). Order is preserved and duplicates are allowed (e.g.
   multiple Set-Cookie). Lookup folds duplicates per RFC 9110 5.2 when
   joined with commas. *)

signature HEADERS =
sig
  type headers

  val empty   : headers
  val fromList : (string * string) list -> headers
  val toList  : headers -> (string * string) list   (* original order/case *)

  (* Case-insensitive first value for a field name. *)
  val get     : headers -> string -> string option
  (* All values for a field name, in order. *)
  val getAll  : headers -> string -> string list
  (* Combined value: duplicates joined with ", " (RFC 9110 5.2). NONE if absent. *)
  val getCombined : headers -> string -> string option
  val has     : headers -> string -> bool

  (* Append a field (keeps any existing ones). *)
  val add     : headers -> string -> string -> headers
  (* Replace all fields of this name with a single value. *)
  val set     : headers -> string -> string -> headers
  (* Remove all fields of this name. *)
  val remove  : headers -> string -> headers
end
