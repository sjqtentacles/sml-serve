(* hmac.sig

   HMAC (RFC 2104) over SHA-256. Operates on byte strings; returns the raw
   32-byte MAC or its lowercase hex form. *)

signature HMAC =
sig
  (* hmacSha256 key message -> raw 32-byte MAC *)
  val hmacSha256    : string -> string -> string
  val hmacSha256Hex : string -> string -> string

  (* Constant-time equality of two equal-length byte strings. Returns false
     for differing lengths. Comparison time depends only on the common
     length, not on where the first difference is. *)
  val constantEq : string -> string -> bool
end
