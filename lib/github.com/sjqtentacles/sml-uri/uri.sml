(* uri.sml

   Implements the RFC 3986 Appendix B parsing decomposition and the
   section 5.2/5.3 reference-resolution algorithm directly over strings. *)

structure Uri :> URI =
struct
  type uri =
    { scheme    : string option
    , authority : string option
    , path      : string
    , query     : string option
    , fragment  : string option }

  (* Split off a prefix delimited by the first occurrence of `delim`.
     Returns (before, SOME after) or (whole, NONE). *)
  fun splitFirst delim s =
    case Substring.position delim (Substring.full s) of
        (pre, rest) =>
          if Substring.isEmpty rest then (s, NONE)
          else (Substring.string pre,
                SOME (Substring.string (Substring.triml (String.size delim) rest)))

  (* A scheme is present iff the leading run of scheme-chars is followed by
     ':' and starts with a letter (RFC 3986 3.1). *)
  fun extractScheme s =
    let
      val n = String.size s
      fun go i =
        if i >= n then NONE
        else
          let val c = String.sub (s, i) in
            if c = #":" then
              (if i > 0 andalso Char.isAlpha (String.sub (s, 0)) then SOME i else NONE)
            else if Char.isAlphaNum c orelse c = #"+" orelse c = #"-" orelse c = #"." then go (i + 1)
            else NONE
          end
    in
      case go 0 of
          SOME idx => SOME (String.substring (s, 0, idx), String.extract (s, idx + 1, NONE))
        | NONE => NONE
    end

  fun parse s =
    let
      (* fragment *)
      val (beforeFrag, fragment) = splitFirst "#" s
      (* query *)
      val (beforeQuery, query) = splitFirst "?" beforeFrag
      (* scheme *)
      val (scheme, afterScheme) =
        case extractScheme beforeQuery of
            SOME (sch, rest) => (SOME sch, rest)
          | NONE => (NONE, beforeQuery)
      (* authority: present iff begins with "//" *)
      val (authority, path) =
        if String.isPrefix "//" afterScheme then
          let
            val rest = String.extract (afterScheme, 2, NONE)
            (* authority ends at first '/', and there is no '?' or '#' here *)
            val n = String.size rest
            fun findSlash i =
              if i >= n then n
              else if String.sub (rest, i) = #"/" then i
              else findSlash (i + 1)
            val cut = findSlash 0
          in
            (SOME (String.substring (rest, 0, cut)),
             String.extract (rest, cut, NONE))
          end
        else (NONE, afterScheme)
    in
      { scheme = scheme, authority = authority, path = path,
        query = query, fragment = fragment }
    end

  fun toString ({ scheme, authority, path, query, fragment } : uri) =
    String.concat
      [ case scheme of SOME s => s ^ ":" | NONE => ""
      , case authority of SOME a => "//" ^ a | NONE => ""
      , path
      , case query of SOME q => "?" ^ q | NONE => ""
      , case fragment of SOME f => "#" ^ f | NONE => "" ]

  (* RFC 3986 5.2.4 remove_dot_segments. *)
  fun removeDotSegments path =
    let
      (* Work on a list of "/seg" tokens by scanning the input buffer. *)
      fun loop input (out : string list) =
        if input = "" then String.concat (List.rev out)
        else if String.isPrefix "../" input then loop (String.extract (input, 3, NONE)) out
        else if String.isPrefix "./" input then loop (String.extract (input, 2, NONE)) out
        else if String.isPrefix "/./" input then loop ("/" ^ String.extract (input, 3, NONE)) out
        else if input = "/." then loop "/" out
        else if String.isPrefix "/../" input then
          loop ("/" ^ String.extract (input, 4, NONE)) (popLast out)
        else if input = "/.." then loop "/" (popLast out)
        else if input = "." then loop "" out
        else if input = ".." then loop "" out
        else
          let
            (* move the first path segment (including any leading '/') to out *)
            val n = String.size input
            fun seg i =
              if i >= n then n
              else if i > 0 andalso String.sub (input, i) = #"/" then i
              else seg (i + 1)
            val cut = if n > 0 andalso String.sub (input, 0) = #"/" then seg 1 else seg 0
            val piece = String.substring (input, 0, cut)
          in
            loop (String.extract (input, cut, NONE)) (piece :: out)
          end
      and popLast out =
        case out of [] => [] | (_ :: rest) => rest
    in
      loop path []
    end

  fun merge (base : uri) (refPath : string) =
    case #authority base of
        SOME _ =>
          if #path base = "" then "/" ^ refPath else
            (case rsplitSlash (#path base) of dir => dir ^ refPath)
      | NONE => (case rsplitSlash (#path base) of dir => dir ^ refPath)

  and rsplitSlash p =
    (* everything up to and including the last '/', or "" if none *)
    let
      fun lastSlash i acc =
        if i >= String.size p then acc
        else lastSlash (i + 1) (if String.sub (p, i) = #"/" then i else acc)
    in
      case lastSlash 0 ~1 of
          ~1 => ""
        | idx => String.substring (p, 0, idx + 1)
    end

  (* RFC 3986 5.2.2 transform references. *)
  fun resolve (base : uri) (r : uri) : uri =
    let
      val (scheme, authority, path, query) =
        case #scheme r of
            SOME _ => (#scheme r, #authority r, removeDotSegments (#path r), #query r)
          | NONE =>
              (case #authority r of
                   SOME _ => (#scheme base, #authority r, removeDotSegments (#path r), #query r)
                 | NONE =>
                     if #path r = "" then
                       (#scheme base, #authority base, #path base,
                        case #query r of SOME q => SOME q | NONE => #query base)
                     else if String.isPrefix "/" (#path r) then
                       (#scheme base, #authority base, removeDotSegments (#path r), #query r)
                     else
                       (#scheme base, #authority base,
                        removeDotSegments (merge base (#path r)), #query r))
    in
      { scheme = scheme, authority = authority, path = path,
        query = query, fragment = #fragment r }
    end

  fun resolveStr base ref' = toString (resolve (parse base) (parse ref'))

  fun queryParams (u : uri) =
    case #query u of NONE => [] | SOME q => Query.parse q
end
