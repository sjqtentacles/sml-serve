(* percent.sml *)

structure Percent :> PERCENT =
struct
  fun isUnreserved c =
    Char.isAlphaNum c orelse c = #"-" orelse c = #"." orelse c = #"_" orelse c = #"~"

  fun hexDigit n =
    String.sub ("0123456789ABCDEF", n)

  fun encodeByte c =
    let val b = Char.ord c
    in String.implode [#"%", hexDigit (b div 16), hexDigit (b mod 16)] end

  fun encodeWith spacePlus s =
    String.concat
      (List.map
        (fn c =>
          if isUnreserved c then String.str c
          else if spacePlus andalso c = #" " then "+"
          else encodeByte c)
        (String.explode s))

  fun encode s = encodeWith false s
  fun encodeForm s = encodeWith true s

  fun hexVal c =
    if c >= #"0" andalso c <= #"9" then SOME (Char.ord c - Char.ord #"0")
    else if c >= #"a" andalso c <= #"f" then SOME (Char.ord c - Char.ord #"a" + 10)
    else if c >= #"A" andalso c <= #"F" then SOME (Char.ord c - Char.ord #"A" + 10)
    else NONE

  fun decodeWith plusSpace s =
    let
      val n = String.size s
      fun loop i acc =
        if i >= n then String.implode (List.rev acc)
        else
          let val c = String.sub (s, i) in
            if c = #"%" andalso i + 2 < n then
              (case (hexVal (String.sub (s, i+1)), hexVal (String.sub (s, i+2))) of
                   (SOME hi, SOME lo) => loop (i + 3) (Char.chr (hi * 16 + lo) :: acc)
                 | _ => loop (i + 1) (c :: acc))
            else if plusSpace andalso c = #"+" then loop (i + 1) (#" " :: acc)
            else loop (i + 1) (c :: acc)
          end
    in
      loop 0 []
    end

  fun decode s = decodeWith false s
  fun decodeForm s = decodeWith true s
end
