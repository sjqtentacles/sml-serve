(* random.sig

   A small, deterministic, splittable pseudo-random generator based on
   SplitMix64 (Steele, Lea & Flood 2014). Suitable for non-cryptographic
   needs across the web stack -- session IDs, CSRF nonces, jitter, sampling
   -- where reproducibility from a seed matters and OS entropy is undesirable
   in a pure core.

   NOT a cryptographically secure RNG. For unguessable secrets, seed it from
   a real entropy source at the impure edge, or use HMAC-based tokens from
   sml-crypto.

   The state is immutable: each step returns a value and the next state, so
   generators can be freely copied, replayed, and `split` into independent
   streams. *)

signature RANDOM =
sig
  type t

  (* Create a generator from a 64-bit seed. *)
  val fromSeed : Word64.word -> t
  (* Convenience: seed from an int. *)
  val fromInt  : int -> t

  (* Next 64-bit word and the advanced generator. *)
  val nextWord : t -> Word64.word * t
  (* Next non-negative int in [0, bound) (bound must be > 0) and the advanced
     generator. Unbiased via rejection. *)
  val nextInt  : t -> int -> int * t
  (* Next real in [0.0, 1.0). *)
  val nextReal : t -> real * t
  (* Next single byte char (0..255). *)
  val nextByte : t -> char * t

  (* A pseudo-random string of n bytes (each 0..255). *)
  val bytes    : t -> int -> string * t
  (* A pseudo-random string of n characters drawn from the given alphabet
     (alphabet must be non-empty). Handy for tokens. *)
  val token    : t -> string -> int -> string * t
  (* A hex token of n hex characters. *)
  val hexToken : t -> int -> string * t

  (* Split into two independent generators. *)
  val split    : t -> t * t
end
