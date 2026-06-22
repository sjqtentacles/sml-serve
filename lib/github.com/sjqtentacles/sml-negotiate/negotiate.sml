(* negotiate.sml -- RFC 9110 proactive content negotiation. *)

structure Negotiate :> NEGOTIATE =
struct
  type entry = { value : string, q : real }

  fun lower s = String.map Char.toLower s

  fun trim s =
    Substring.string (Substring.dropr Char.isSpace
                        (Substring.dropl Char.isSpace (Substring.full s)))

  (* parse a real in [0,1]; tolerate "1", "0.5", ".7" *)
  fun parseQ s =
    case Real.fromString s of
        SOME r => if r < 0.0 then 0.0 else if r > 1.0 then 1.0 else r
      | NONE => 1.0

  (* split "token;q=0.5;other=x" into (token, q) ignoring other params *)
  fun parseEntry raw =
    let
      val parts = List.map trim (String.fields (fn c => c = #";") raw)
    in
      case parts of
          [] => NONE
        | (tok :: params) =>
            if tok = "" then NONE
            else
              let
                fun findQ [] = 1.0
                  | findQ (p :: ps) =
                      let
                        val p' = lower p
                      in
                        if String.isPrefix "q=" p'
                        then parseQ (String.extract (p', 2, NONE))
                        else findQ ps
                      end
              in
                SOME { value = lower tok, q = findQ params }
              end
    end

  fun parse header =
    List.mapPartial parseEntry
      (List.filter (fn s => trim s <> "")
        (String.fields (fn c => c = #",") header))

  (* find the highest q among entries that match `offer`; NONE if none match or
     the best match has q=0. *)
  fun scoreFor matches entries offer =
    let
      fun loop ([], best) = best
        | loop ((e : entry) :: es, best) =
            if matches (#value e, lower offer)
            then loop (es, case best of
                              NONE => SOME (#q e)
                            | SOME b => SOME (Real.max (b, #q e)))
            else loop (es, best)
    in
      loop (entries, NONE)
    end

  fun best { matches } entries offers =
    let
      (* keep server offer order; pick the offer with the highest score *)
      fun loop ([], bestOffer, _) = bestOffer
        | loop (off :: offs, bestOffer, bestScore) =
            (case scoreFor matches entries off of
                 NONE => loop (offs, bestOffer, bestScore)
               | SOME q =>
                   if q <= 0.0 then loop (offs, bestOffer, bestScore)
                   else if q > bestScore
                   then loop (offs, SOME off, q)
                   else loop (offs, bestOffer, bestScore))
    in
      loop (offers, NONE, ~1.0)
    end

  (* media-type matching: accepted "*/*" matches anything; "type/*" matches
     same type; otherwise exact essence match. *)
  fun mediaMatches (accepted, offer) =
    if accepted = "*/*" then true
    else if accepted = offer then true
    else
      (case (CharVector.findi (fn (_, c) => c = #"/") accepted) of
           NONE => false
         | SOME (i, _) =>
             let
               val atype = String.substring (accepted, 0, i)
               val asub = String.extract (accepted, i + 1, NONE)
             in
               if asub = "*"
               then String.isPrefix (atype ^ "/") offer
               else false
             end)

  fun acceptMedia { header, offers } =
    if trim header = ""
    then (case offers of [] => NONE | o0 :: _ => SOME o0)  (* no preference *)
    else best { matches = mediaMatches } (parse header) offers

  fun encodingMatches (accepted, offer) =
    accepted = "*" orelse accepted = offer

  fun acceptEncoding { header, offers } =
    if trim header = ""
    then (case offers of [] => NONE | o0 :: _ => SOME o0)
    else
      let
        val entries = parse header
        val result = best { matches = encodingMatches } entries offers
      in
        case result of
            SOME _ => result
          | NONE =>
              (* identity is acceptable unless explicitly q=0 *)
              let
                fun identityQ [] = NONE
                  | identityQ ((e : entry) :: es) =
                      if #value e = "identity" orelse #value e = "*"
                      then SOME (#q e) else identityQ es
                val identityDisabled =
                  case identityQ entries of SOME q => q <= 0.0 | NONE => false
              in
                if identityDisabled then NONE
                else if List.exists (fn o' => lower o' = "identity") offers
                then SOME "identity"
                else NONE
              end
      end

  (* language: accepted prefix matches offer ("en" matches "en-us"); "*" any *)
  fun languageMatches (accepted, offer) =
    accepted = "*" orelse accepted = offer
    orelse String.isPrefix (accepted ^ "-") offer

  fun acceptLanguage { header, offers } =
    if trim header = ""
    then (case offers of [] => NONE | o0 :: _ => SOME o0)
    else best { matches = languageMatches } (parse header) offers
end
