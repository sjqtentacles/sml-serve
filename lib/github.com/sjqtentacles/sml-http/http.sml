(* http.sml *)

structure Http :> HTTP =
struct
  type request =
    { method : string, target : string, version : string
    , headers : Headers.headers, body : string }

  type response =
    { version : string, status : int, reason : string
    , headers : Headers.headers, body : string }

  val crlf = "\r\n"

  (* Split a message into (head, body) at the first blank line (CRLF CRLF,
     tolerating bare LF LF). *)
  fun splitHeadBody s =
    case Substring.position "\r\n\r\n" (Substring.full s) of
        (h, rest) =>
          if not (Substring.isEmpty rest)
          then (Substring.string h, Substring.string (Substring.triml 4 rest))
          else
            (case Substring.position "\n\n" (Substring.full s) of
                 (h2, rest2) =>
                   if not (Substring.isEmpty rest2)
                   then (Substring.string h2, Substring.string (Substring.triml 2 rest2))
                   else (s, ""))

  (* Split head into lines, tolerating CRLF or LF. *)
  fun headLines head =
    List.map
      (fn l => if String.isSuffix "\r" l
               then String.substring (l, 0, String.size l - 1) else l)
      (String.fields (fn c => c = #"\n") head)

  fun trim s =
    Substring.string (Substring.dropr Char.isSpace (Substring.dropl Char.isSpace (Substring.full s)))

  (* Parse "Name: value" -> (Name, value), trimming OWS around value. *)
  fun parseHeaderLine line =
    case Substring.position ":" (Substring.full line) of
        (k, rest) =>
          if Substring.isEmpty rest then NONE
          else SOME (Substring.string k, trim (Substring.string (Substring.triml 1 rest)))

  fun parseHeaderLines lines =
    let
      fun loop [] acc = SOME (Headers.fromList (List.rev acc))
        | loop (l :: ls) acc =
            if l = "" then loop ls acc
            else (case parseHeaderLine l of
                      SOME kv => loop ls (kv :: acc)
                    | NONE => NONE)
    in
      loop lines []
    end

  fun words3 line =
    (* split request/status line into exactly 3 fields, third may contain spaces *)
    case String.fields (fn c => c = #" ") line of
        (a :: b :: rest) => SOME (a, b, String.concatWith " " rest)
      | _ => NONE

  fun parseRequest s =
    let
      val (head, body) = splitHeadBody s
    in
      case headLines head of
          [] => NONE
        | (start :: rest) =>
            (case words3 start of
                 SOME (method, target, version) =>
                   (case parseHeaderLines rest of
                        SOME hs => SOME { method = method, target = target,
                                         version = version, headers = hs, body = body }
                      | NONE => NONE)
               | NONE => NONE)
    end

  fun parseResponse s =
    let
      val (head, body) = splitHeadBody s
    in
      case headLines head of
          [] => NONE
        | (start :: rest) =>
            (case words3 start of
                 SOME (version, codeStr, reason) =>
                   (case Int.fromString codeStr of
                        SOME code =>
                          (case parseHeaderLines rest of
                               SOME hs => SOME { version = version, status = code,
                                                reason = reason, headers = hs, body = body }
                             | NONE => NONE)
                      | NONE => NONE)
               | NONE => NONE)
    end

  fun renderHeaders hs =
    String.concat
      (List.map (fn (k, v) => k ^ ": " ^ v ^ crlf) (Headers.toList hs))

  fun serializeRequest ({ method, target, version, headers, body } : request) =
    String.concat
      [ method, " ", target, " ", version, crlf
      , renderHeaders headers
      , crlf
      , body ]

  fun serializeResponse ({ version, status, reason, headers, body } : response) =
    String.concat
      [ version, " ", Int.toString status, " ", reason, crlf
      , renderHeaders headers
      , crlf
      , body ]

  fun targetUri ({ target, ... } : request) = Uri.parse target

  fun response code headers body =
    { version = "HTTP/1.1", status = code, reason = Status.reason code
    , headers = headers, body = body }

  fun text code body =
    response code
      (Headers.fromList [("Content-Type", "text/plain; charset=utf-8"),
                         ("Content-Length", Int.toString (String.size body))])
      body

  (* ---- framing ---- *)

  fun hexToInt s =
    let
      (* parse hex chunk size, stopping at first ';' (chunk extensions) *)
      val core = hd (String.fields (fn c => c = #";") s)
      fun loop i acc =
        if i >= String.size core then SOME acc
        else
          let val c = String.sub (core, i) in
            case (if c >= #"0" andalso c <= #"9" then SOME (Char.ord c - Char.ord #"0")
                  else if c >= #"a" andalso c <= #"f" then SOME (Char.ord c - Char.ord #"a" + 10)
                  else if c >= #"A" andalso c <= #"F" then SOME (Char.ord c - Char.ord #"A" + 10)
                  else NONE) of
                SOME d => loop (i + 1) (acc * 16 + d)
              | NONE => NONE
          end
    in
      if core = "" then NONE else loop 0 0
    end

  fun decodeChunked input =
    let
      val n = String.size input
      (* read up to next CRLF (or LF), returning (line, indexAfter) *)
      fun readLine i =
        let
          fun find j =
            if j >= n then NONE
            else if String.sub (input, j) = #"\n" then SOME j
            else find (j + 1)
        in
          case find i of
              NONE => NONE
            | SOME j =>
                let
                  val raw = String.substring (input, i, j - i)
                  val raw = if String.isSuffix "\r" raw
                            then String.substring (raw, 0, String.size raw - 1) else raw
                in SOME (raw, j + 1) end
        end
      fun loop i acc =
        case readLine i of
            NONE => NONE
          | SOME (sizeLine, i1) =>
              (case hexToInt sizeLine of
                   NONE => NONE
                 | SOME 0 => SOME (String.concat (List.rev acc))   (* last chunk; ignore trailers *)
                 | SOME size =>
                     if i1 + size > n then NONE
                     else
                       let
                         val chunk = String.substring (input, i1, size)
                         (* skip trailing CRLF after the chunk data *)
                         val afterData = i1 + size
                         val afterCrlf =
                           if afterData + 1 < n
                              andalso String.sub (input, afterData) = #"\r"
                              andalso String.sub (input, afterData + 1) = #"\n"
                           then afterData + 2
                           else if afterData < n andalso String.sub (input, afterData) = #"\n"
                           then afterData + 1
                           else afterData
                       in
                         loop afterCrlf (chunk :: acc)
                       end)
    in
      loop 0 []
    end

  fun encodeChunked body =
    let
      val size = String.size body
      fun toHex 0 = "0"
        | toHex n =
            let
              fun go 0 acc = acc
                | go n acc = go (n div 16) (String.str (String.sub ("0123456789abcdef", n mod 16)) ^ acc)
            in go n "" end
    in
      if size = 0 then "0" ^ crlf ^ crlf
      else toHex size ^ crlf ^ body ^ crlf ^ "0" ^ crlf ^ crlf
    end

  fun decodeBody headers raw =
    case Headers.get headers "Transfer-Encoding" of
        SOME te =>
          if String.isSubstring "chunked" (String.map Char.toLower te)
          then decodeChunked raw
          else SOME raw
      | NONE =>
          (case Headers.get headers "Content-Length" of
               SOME lenStr =>
                 (case Int.fromString (trim lenStr) of
                      SOME len =>
                        if len <= String.size raw
                        then SOME (String.substring (raw, 0, len))
                        else NONE
                    | NONE => NONE)
             | NONE => SOME raw)
end
