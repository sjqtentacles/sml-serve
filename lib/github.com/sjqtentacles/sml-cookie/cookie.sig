(* cookie.sig

   RFC 6265 Cookie / Set-Cookie parsing and building.

   - `parseCookie`  reads a request "Cookie:" header value ("a=1; b=2") into
     name/value pairs.
   - `Set-Cookie` is modeled as a record with the standard attributes; `build`
     serializes it and `parseSetCookie` reads one back.

   Expires is formatted as an IMF-fixdate (RFC 7231) from a sml-datetime date
   (+ time of day); Max-Age is an integer count of seconds. SameSite is a small
   enum. *)

signature COOKIE =
sig
  datatype same_site = Strict | Lax | None

  type set_cookie =
    { name : string
    , value : string
    , path : string option
    , domain : string option
    , maxAge : int option              (* seconds *)
    , expires : string option          (* pre-formatted HTTP-date *)
    , secure : bool
    , httpOnly : bool
    , sameSite : same_site option }

  (* A bare cookie with sensible defaults (no attributes). *)
  val cookie : string -> string -> set_cookie

  (* Parse a request "Cookie" header value into pairs. *)
  val parseCookie : string -> (string * string) list

  (* Serialize a Set-Cookie value (without the "Set-Cookie:" prefix). *)
  val build : set_cookie -> string
  (* Parse a Set-Cookie value back into a record. NONE if there's no name=val.
     A Max-Age is kept only when it parses within the signed 32-bit range;
     otherwise `maxAge` is NONE (an oversized value never overflows the default
     `int`). *)
  val parseSetCookie : string -> set_cookie option

  (* Format an IMF-fixdate ("Sun, 06 Nov 1994 08:49:37 GMT") for `Expires`,
     from a date and a (h, m, s) time of day. *)
  val httpDate : DateTime.date -> int * int * int -> string
end
