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
  (* Parse a complete response message. *)
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

  (* Framing decoders, given headers and the raw bytes after the head.
     decodeBody returns the message body honoring Transfer-Encoding: chunked
     or Content-Length; if neither is present the whole input is the body. *)
  val decodeBody   : Headers.headers -> string -> string option
  val decodeChunked : string -> string option
  (* Encode a body as chunked transfer-coding. *)
  val encodeChunked : string -> string
end
