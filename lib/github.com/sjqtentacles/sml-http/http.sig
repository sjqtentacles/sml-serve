(* http.sig

   HTTP/1.1 message model (RFC 9110/9112) as pure values plus pure
   parse/serialize functions over strings. No sockets: a request is parsed
   from a complete byte string (head + body) and serialized back to one.

   Bodies are plain strings. Two framing helpers decode a body region given
   the headers: Content-Length and chunked transfer-coding (RFC 9112 7.1). *)

signature HTTP =
sig
  type request =
    { method  : string
    , target  : string          (* raw request-target, e.g. "/a?b=c" *)
    , version : string          (* e.g. "HTTP/1.1" *)
    , headers : Headers.headers
    , body    : string }

  type response =
    { version : string
    , status  : int
    , reason  : string
    , headers : Headers.headers
    , body    : string }

  (* Parse a complete request message. NONE on a malformed start line or
     headers. The body is taken verbatim (caller may re-frame via the
     helpers below). *)
  val parseRequest  : string -> request option
  (* Parse a complete response message. The status code is range-checked via
     IntInf (bounded to a fixed 32-bit signed range): an oversized or
     non-numeric code yields NONE rather than raising Overflow, so behaviour is
     identical under MLton (32-bit Int) and Poly/ML (63-bit Int); both are
     fixed width, only IntInf is arbitrary precision. *)
  val parseResponse : string -> response option

  (* Serialize back to wire form (CRLF line endings). *)
  val serializeRequest  : request -> string
  val serializeResponse : response -> string

  (* The request-target parsed as a URI (path/query extraction). *)
  val targetUri : request -> Uri.uri

  (* Constructors. `response` fills in the standard reason phrase. *)
  val response : int -> Headers.headers -> string -> response
  (* A simple text/plain response. *)
  val text     : int -> string -> response
  (* A 200 text/html response (Content-Type text/html; charset=utf-8 plus
     Content-Length). *)
  val html     : string -> response
  (* A 302 Found response carrying the given Location and an empty body. *)
  val redirect : string -> response          (* redirect location *)
  (* A redirect with an explicit 3xx status code and Location. *)
  val redirectWith : int -> string -> response   (* redirectWith code location *)

  (* Request builders. The version defaults to "HTTP/1.1"; `target` is the raw
     request-target (path[?query]). `post`/`put` set Content-Length from the
     body. *)
  val get    : string -> request                 (* get target *)
  val delete : string -> request                 (* delete target *)
  val post   : string -> string -> request       (* post target body *)
  val put    : string -> string -> request       (* put target body *)

  (* Framing decoders, given headers and the raw bytes after the head.
     decodeBody returns the message body honoring Transfer-Encoding: chunked
     or Content-Length; if neither is present the whole input is the body.
     A Content-Length value is range-checked via IntInf (bounded to a fixed
     32-bit signed range): an oversized or non-numeric value yields NONE rather
     than raising Overflow, keeping MLton and Poly/ML in agreement. *)
  val decodeBody   : Headers.headers -> string -> string option
  val decodeChunked : string -> string option
  (* Encode a body as chunked transfer-coding. *)
  val encodeChunked : string -> string
end
