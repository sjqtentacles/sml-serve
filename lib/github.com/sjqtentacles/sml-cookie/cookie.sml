(* cookie.sml -- RFC 6265 Cookie / Set-Cookie. *)

structure Cookie :> COOKIE =
struct
  datatype same_site = Strict | Lax | None

  type set_cookie =
    { name : string, value : string
    , path : string option, domain : string option
    , maxAge : int option, expires : string option
    , secure : bool, httpOnly : bool
    , sameSite : same_site option }

  fun cookie name value =
    { name = name, value = value
    , path = NONE, domain = NONE, maxAge = NONE, expires = NONE
    , secure = false, httpOnly = false, sameSite = NONE }

  fun trim s =
    Substring.string (Substring.dropr Char.isSpace
                        (Substring.dropl Char.isSpace (Substring.full s)))

  fun splitFirst c s =
    case CharVector.findi (fn (_, ch) => ch = c) s of
        NONE => (s, NONE)
      | SOME (i, _) =>
          (String.substring (s, 0, i), SOME (String.extract (s, i + 1, NONE)))

  fun parsePair s =
    case splitFirst #"=" s of
        (k, NONE) => (trim k, "")
      | (k, SOME v) => (trim k, trim v)

  fun parseCookie header =
    List.map parsePair
      (List.filter (fn s => trim s <> "")
        (String.fields (fn c => c = #";") header))

  (* ----- HTTP-date formatting (IMF-fixdate, RFC 7231 7.1.1.1) ----- *)
  val dayNames = Vector.fromList ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
  val monNames = Vector.fromList ["Jan","Feb","Mar","Apr","May","Jun",
                   "Jul","Aug","Sep","Oct","Nov","Dec"]
  fun pad2 n = if n < 10 then "0" ^ Int.toString n else Int.toString n

  fun httpDate (d : DateTime.date) (h, m, s) =
    let
      val dow = DateTime.dayOfWeek d
    in
      Vector.sub (dayNames, dow) ^ ", " ^
      pad2 (#day d) ^ " " ^
      Vector.sub (monNames, #month d - 1) ^ " " ^
      Int.toString (#year d) ^ " " ^
      pad2 h ^ ":" ^ pad2 m ^ ":" ^ pad2 s ^ " GMT"
    end

  fun sameSiteStr Strict = "Strict"
    | sameSiteStr Lax = "Lax"
    | sameSiteStr None = "None"

  fun build (c : set_cookie) =
    let
      val parts = ref [#name c ^ "=" ^ #value c]
      fun add s = parts := s :: !parts
      val () = case #path c of SOME p => add ("Path=" ^ p) | NONE => ()
      val () = case #domain c of SOME d => add ("Domain=" ^ d) | NONE => ()
      val () = case #maxAge c of SOME a => add ("Max-Age=" ^ Int.toString a) | NONE => ()
      val () = case #expires c of SOME e => add ("Expires=" ^ e) | NONE => ()
      val () = if #secure c then add "Secure" else ()
      val () = if #httpOnly c then add "HttpOnly" else ()
      val () = case #sameSite c of SOME ss => add ("SameSite=" ^ sameSiteStr ss) | NONE => ()
    in
      String.concatWith "; " (List.rev (!parts))
    end

  fun lower s = String.map Char.toLower s

  fun parseSetCookie header =
    let
      val segs = List.filter (fn s => trim s <> "")
                   (String.fields (fn c => c = #";") header)
    in
      case segs of
          [] => NONE
        | (first :: attrs) =>
            (case splitFirst #"=" first of
                 (_, NONE) => NONE
               | (name, SOME value) =>
                   let
                     val base = cookie (trim name) (trim value)
                     fun applyAttr (acc : set_cookie) attr =
                       let
                         val (k, vOpt) = splitFirst #"=" attr
                         val key = lower (trim k)
                         val v = case vOpt of SOME x => trim x | NONE => ""
                       in
                         case key of
                             "path" => { name = #name acc, value = #value acc
                                       , path = SOME v, domain = #domain acc
                                       , maxAge = #maxAge acc, expires = #expires acc
                                       , secure = #secure acc, httpOnly = #httpOnly acc
                                       , sameSite = #sameSite acc }
                           | "domain" => { name = #name acc, value = #value acc
                                         , path = #path acc, domain = SOME v
                                         , maxAge = #maxAge acc, expires = #expires acc
                                         , secure = #secure acc, httpOnly = #httpOnly acc
                                         , sameSite = #sameSite acc }
                           | "max-age" => { name = #name acc, value = #value acc
                                          , path = #path acc, domain = #domain acc
                                          , maxAge = Int.fromString v, expires = #expires acc
                                          , secure = #secure acc, httpOnly = #httpOnly acc
                                          , sameSite = #sameSite acc }
                           | "expires" => { name = #name acc, value = #value acc
                                          , path = #path acc, domain = #domain acc
                                          , maxAge = #maxAge acc, expires = SOME v
                                          , secure = #secure acc, httpOnly = #httpOnly acc
                                          , sameSite = #sameSite acc }
                           | "secure" => { name = #name acc, value = #value acc
                                         , path = #path acc, domain = #domain acc
                                         , maxAge = #maxAge acc, expires = #expires acc
                                         , secure = true, httpOnly = #httpOnly acc
                                         , sameSite = #sameSite acc }
                           | "httponly" => { name = #name acc, value = #value acc
                                           , path = #path acc, domain = #domain acc
                                           , maxAge = #maxAge acc, expires = #expires acc
                                           , secure = #secure acc, httpOnly = true
                                           , sameSite = #sameSite acc }
                           | "samesite" =>
                               let
                                 val ss = case lower v of
                                              "strict" => SOME Strict
                                            | "lax" => SOME Lax
                                            | "none" => SOME None
                                            | _ => NONE
                               in
                                 { name = #name acc, value = #value acc
                                 , path = #path acc, domain = #domain acc
                                 , maxAge = #maxAge acc, expires = #expires acc
                                 , secure = #secure acc, httpOnly = #httpOnly acc
                                 , sameSite = ss }
                               end
                           | _ => acc
                       end
                   in
                     SOME (List.foldl (fn (a, acc) => applyAttr acc a) base attrs)
                   end)
    end
end
