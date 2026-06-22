(* random.sml

   SplitMix64. The generator state is a single 64-bit word `s`. Each step
   advances `s := s + GOLDEN` and runs the finalizing mix (mix64) over the
   pre-increment-then-incremented value, per the reference algorithm. *)

structure Random :> RANDOM =
struct
  type t = Word64.word

  val golden : Word64.word = 0wx9E3779B97F4A7C15

  val xorb = Word64.xorb
  val andb = Word64.andb
  val orb  = Word64.orb
  infix 5 andb
  infix 4 xorb
  fun >> (a, b) = Word64.>> (a, b)
  infix 6 >>
  val op ++ = Word64.+
  val op ** = Word64.*
  infix 6 ++
  infix 7 **

  fun fromSeed s = s
  fun fromInt n = Word64.fromInt n

  (* mix64 finalizer from SplitMix64. *)
  fun mix z0 =
    let
      val z1 = (z0 xorb (z0 >> 0w30)) ** 0wxBF58476D1CE4E5B9
      val z2 = (z1 xorb (z1 >> 0w27)) ** 0wx94D049BB133111EB
    in
      z2 xorb (z2 >> 0w31)
    end

  fun nextWord s =
    let val s' = s ++ golden
    in (mix s', s') end

  (* Derive a fresh seed for splitting by mixing differently. *)
  fun split s =
    let
      val (w1, s1) = nextWord s
      val (w2, s2) = nextWord s1
    in
      (fromSeed (mix w1), fromSeed (mix (w2 xorb golden)))
    end

  fun nextReal s =
    let
      val (w, s') = nextWord s
      (* top 53 bits -> [0,1) *)
      val mant = Word64.toLargeInt (w >> 0w11)
      val denom = IntInf.pow (2, 53)
    in
      (Real.fromLargeInt mant / Real.fromLargeInt denom, s')
    end

  fun nextInt s bound =
    if bound <= 0 then raise Domain
    else
      let
        val b = Word64.fromInt bound
        (* rejection sampling to avoid modulo bias *)
        val limit = 0wxFFFFFFFFFFFFFFFF - (0wxFFFFFFFFFFFFFFFF mod b)
        fun loop st =
          let val (w, st') = nextWord st
          in
            if Word64.<= (w, limit) then (Word64.toInt (w mod b), st')
            else loop st'
          end
      in
        loop s
      end

  fun nextByte s =
    let val (w, s') = nextWord s
    in (Char.chr (Word64.toInt (w andb 0wxFF)), s') end

  fun bytes s n =
    let
      fun loop 0 st acc = (String.implode (List.rev acc), st)
        | loop k st acc =
            let val (c, st') = nextByte st in loop (k - 1) st' (c :: acc) end
    in
      if n < 0 then raise Domain else loop n s []
    end

  fun token s alphabet n =
    let
      val m = String.size alphabet
    in
      if m = 0 then raise Domain
      else if n < 0 then raise Domain
      else
        let
          fun loop 0 st acc = (String.implode (List.rev acc), st)
            | loop k st acc =
                let val (i, st') = nextInt st m
                in loop (k - 1) st' (String.sub (alphabet, i) :: acc) end
        in
          loop n s []
        end
    end

  fun hexToken s n = token s "0123456789abcdef" n
end
