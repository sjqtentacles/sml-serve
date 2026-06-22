(* negotiate.sig

   RFC 9110 5.3 proactive content negotiation. Parses Accept,
   Accept-Encoding, and Accept-Language header values into weighted entries
   and selects the best matching offer from a server's list.

   Quality (q) values range 0..1; q=0 means "not acceptable". Parsing is
   tolerant of whitespace and missing q (defaults to 1.0). Selection prefers
   higher q, then the server's offer order as a tie-breaker (stable). *)

signature NEGOTIATE =
sig
  type entry = { value : string, q : real }   (* value lowercased *)

  (* Parse a comma-separated weighted list, e.g.
     "text/html;q=0.8, application/json" -> entries with q. *)
  val parse : string -> entry list

  (* Generic best-match: given the parsed Accept entries and the server's
     offers (in preference order), return the chosen offer or NONE.
     `matches (accepted, offer)` decides whether an Accept token covers an
     offer (used to implement wildcards/type matching). *)
  val best :
    { matches : string * string -> bool }
    -> entry list -> string list -> string option

  (* Accept (media types): supports "*/*" and "type/*" wildcards. *)
  val acceptMedia : { header : string, offers : string list } -> string option
  (* Accept-Encoding: supports "*"; "identity" is implicitly acceptable
     unless explicitly disabled with q=0. *)
  val acceptEncoding : { header : string, offers : string list } -> string option
  (* Accept-Language: RFC 4647 basic prefix matching ("en" matches "en-US"). *)
  val acceptLanguage : { header : string, offers : string list } -> string option
end
