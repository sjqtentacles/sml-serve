(* signed.sig

   Signed cookies: cookie values that carry an HMAC so the server can detect
   tampering. The value stored in the cookie is `Token.sign key value`
   ("b64url(value).b64url(mac)"); reading it back verifies the MAC and returns
   the original value only if intact.

   Built on sml-crypto (HMAC-SHA256 signed tokens). *)

signature SIGNED_COOKIE =
sig
  (* Build a Set-Cookie whose value is signed with `key`. *)
  val sign : { key : string, name : string, value : string } -> Cookie.set_cookie

  (* Given the request cookie pairs, read a signed cookie by name, verifying
     the signature. NONE if absent or tampered. *)
  val read : { key : string, name : string }
             -> (string * string) list -> string option
end
