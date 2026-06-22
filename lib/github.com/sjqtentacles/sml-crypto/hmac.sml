(* hmac.sml *)

structure Hmac :> HMAC =
struct
  val blockSize = 64   (* SHA-256 block size in bytes *)

  fun xorByte (pad : int) (c : char) =
    Char.chr (Word.toInt (Word.xorb (Word.fromInt (Char.ord c), Word.fromInt pad)))

  fun xorConst (pad : int) (s : string) = String.map (xorByte pad) s

  fun hmacSha256 key message =
    let
      (* Keys longer than the block are hashed; then zero-padded to block. *)
      val k0 = if String.size key > blockSize then Sha256.digest key else key
      val k0 = k0 ^ String.implode (List.tabulate (blockSize - String.size k0, fn _ => Char.chr 0))
      val ipad = xorConst 0x36 k0
      val opad = xorConst 0x5c k0
      val inner = Sha256.digest (ipad ^ message)
    in
      Sha256.digest (opad ^ inner)
    end

  fun hmacSha256Hex key message = Base16.encode (hmacSha256 key message)

  fun constantEq a b =
    if String.size a <> String.size b then false
    else
      let
        val n = String.size a
        fun loop i acc =
          if i >= n then acc
          else
            loop (i + 1)
              (Word.orb (acc,
                 Word.xorb (Word.fromInt (Char.ord (String.sub (a, i))),
                            Word.fromInt (Char.ord (String.sub (b, i))))))
      in
        Word.toInt (loop 0 0w0) = 0
      end
end
