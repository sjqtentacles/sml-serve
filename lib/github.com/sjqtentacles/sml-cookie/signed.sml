(* signed.sml -- HMAC-signed cookie values via sml-crypto. *)

structure SignedCookie :> SIGNED_COOKIE =
struct
  fun sign { key, name, value } =
    Cookie.cookie name (Token.sign key value)

  fun read { key, name } pairs =
    case List.find (fn (k, _) => k = name) pairs of
        NONE => NONE
      | SOME (_, token) => Token.verify key token
end
