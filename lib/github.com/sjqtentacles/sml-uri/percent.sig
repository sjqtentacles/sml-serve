(* percent.sig

   Percent-encoding (RFC 3986 section 2). `encode` escapes everything that
   is not an unreserved character; `encodeComponent` is the same but is the
   name used when escaping a single path/query component. `decode` reverses
   any %XX sequences and is total (a malformed `%` is left as a literal). *)

signature PERCENT =
sig
  (* Escape all but RFC 3986 unreserved characters (ALPHA / DIGIT / -._~). *)
  val encode : string -> string
  (* Decode %XX sequences (case-insensitive hex). Lone/short '%' left as-is. *)
  val decode : string -> string

  (* application/x-www-form-urlencoded: like encode but space -> '+', and on
     decode '+' -> space. *)
  val encodeForm : string -> string
  val decodeForm : string -> string
end
