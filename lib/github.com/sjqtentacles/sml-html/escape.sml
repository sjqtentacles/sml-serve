(* escape.sml -- context-aware HTML escaping. *)

structure Escape :> ESCAPE =
struct
  fun escapeChar #"&" = "&amp;"
    | escapeChar #"<" = "&lt;"
    | escapeChar #">" = "&gt;"
    | escapeChar #"\"" = "&quot;"
    | escapeChar #"'" = "&#x27;"
    | escapeChar c = String.str c

  fun text s = String.translate escapeChar s

  (* Same conservative rules; quoting is the caller's job (the renderer always
     emits attributes as name="value"). *)
  val attr = text

  fun safeNameChar c =
    Char.isAlphaNum c orelse c = #"-" orelse c = #"_"

  fun isSafeAttrName s = s <> "" andalso CharVector.all safeNameChar s
end
