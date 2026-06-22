(* escape.sig

   Context-aware HTML escaping. Different sink contexts require different
   escaping rules, so each context has its own function rather than a single
   "escape" that is wrong half the time:

     - `text`     : element text content (& < > and quotes).
     - `attr`     : double-quoted attribute values (text rules + always quotes).
     - `attrName` : not escaped, but validated to a safe token (we expose a
                    predicate instead of silently corrupting names).

   We escape `&`, `<`, `>`, `"`, and `'` everywhere to be conservative, which
   is safe for both text and quoted-attribute contexts (OWASP guidance). *)

signature ESCAPE =
sig
  (* Escape for HTML text content / quoted attribute values. *)
  val text : string -> string
  val attr : string -> string

  (* True if a string is a safe unquoted HTML attribute *name* (letters,
     digits, '-', '_'). *)
  val isSafeAttrName : string -> bool
end
