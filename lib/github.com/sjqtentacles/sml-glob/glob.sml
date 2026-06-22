(* glob.sml

   Implementation of GLOB.

   A pattern compiles to a list of tokens. Matching walks the token list and
   the input characters together; `Star` is handled by backtracking (try to
   match the rest of the pattern at each suffix), which is simple and correct.
   To avoid exponential blow-up on patterns with many stars, consecutive stars
   collapse during compilation and `Star` matching advances greedily with
   backtracking only as needed.

   Matching is anchored: the whole string must be consumed. *)

structure Glob :> GLOB =
struct
  (* A class item is a single char or an inclusive range. *)
  datatype classItem = One of char | Range of char * char

  datatype token =
      Lit of char
    | AnyChar            (* ? *)
    | Star               (* * *)
    | Class of bool * classItem list   (* negated?, items *)

  (* fold-case for case-insensitive matching *)
  type pattern = { toks : token list, fold : char -> char }

  fun idChar c = c
  fun lowerChar c = Char.toLower c

  (* ---- compilation ---- *)

  fun compileWith fold s =
      let
        val n = String.size s
        fun peek i = if i < n then SOME (String.sub (s, i)) else NONE

        (* parse a [...] class starting just after the '['. Returns
           (token, nextIndex) or, if malformed/unterminated, treats '[' as a
           literal: (Lit #"[", startIndex). *)
        fun parseClass start =
            let
              (* a leading ! or ^ negates *)
              val (neg, i0) =
                  case peek start of
                      SOME #"!" => (true, start + 1)
                    | SOME #"^" => (true, start + 1)
                    | _ => (false, start)
              (* a ']' immediately after the (optional) negation is a literal *)
              fun loop (i, acc) =
                  case peek i of
                      NONE => NONE   (* unterminated *)
                    | SOME #"]" =>
                        if i = i0 then
                          (* literal ']' as first class member *)
                          loop2 (i + 1, One #"]" :: acc)
                        else SOME (List.rev acc, i + 1)
                    | SOME _ => loop2 (i, acc)
              and loop2 (i, acc) =
                  (* parse one class item (char or range) at i *)
                  case peek i of
                      NONE => NONE
                    | SOME c =>
                        (* range? c '-' d  where d is not ']' *)
                        (case (peek (i + 1), peek (i + 2)) of
                             (SOME #"-", SOME d) =>
                               if d <> #"]" then
                                 loop (i + 3, Range (c, d) :: acc)
                               else loop (i + 1, One c :: acc)
                           | _ => loop (i + 1, One c :: acc))
            in
              case loop (i0, []) of
                  SOME (items, next) => (Class (neg, items), next)
                | NONE => (Lit #"[", start)  (* unterminated: literal '[' *)
            end

        fun go i acc =
            case peek i of
                NONE => List.rev acc
              | SOME #"*" =>
                  (* collapse consecutive stars *)
                  (case acc of
                       Star :: _ => go (i + 1) acc
                     | _ => go (i + 1) (Star :: acc))
              | SOME #"?" => go (i + 1) (AnyChar :: acc)
              | SOME #"\\" =>
                  (case peek (i + 1) of
                       SOME c => go (i + 2) (Lit c :: acc)
                     | NONE => go (i + 1) (Lit #"\\" :: acc))
              | SOME #"[" =>
                  let val (tok, next) = parseClass (i + 1)
                  in go next (tok :: acc) end
              | SOME c => go (i + 1) (Lit c :: acc)
      in
        { toks = go 0 [], fold = fold }
      end

  fun compile s = compileWith idChar s
  fun caseInsensitive s = compileWith lowerChar s

  (* ---- matching ---- *)

  fun classMatch fold (neg, items) c =
      let
        val c' = fold c
        fun itemHit (One x) = fold x = c'
          | itemHit (Range (lo, hi)) =
              let val l = fold lo and h = fold hi
              in l <= c' andalso c' <= h end
        val hit = List.exists itemHit items
      in
        if neg then not hit else hit
      end

  (* cs is the remaining input as a char list *)
  fun matchToks fold toks cs =
      case (toks, cs) of
          ([], []) => true
        | ([], _ :: _) => false
        | (Star :: ts, _) =>
            (* match rest here, or consume one char and retry *)
            matchToks fold ts cs
            orelse (case cs of [] => false | _ :: rest => matchToks fold (Star :: ts) rest)
        | (_ :: _, []) =>
            (* only an all-stars remainder can match the empty input *)
            List.all (fn Star => true | _ => false) toks
        | (Lit x :: ts, c :: rest) =>
            fold x = fold c andalso matchToks fold ts rest
        | (AnyChar :: ts, _ :: rest) => matchToks fold ts rest
        | (Class cl :: ts, c :: rest) =>
            classMatch fold cl c andalso matchToks fold ts rest

  fun matches ({ toks, fold } : pattern) s =
      matchToks fold toks (String.explode s)

  fun matchString pat s = matches (compile pat) s
end
