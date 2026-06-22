(* query.sml *)

structure Query :> QUERY =
struct
  type query = (string * string) list

  fun parsePair s =
    case Substring.position "=" (Substring.full s) of
        (k, rest) =>
          if Substring.isEmpty rest
          then (Percent.decodeForm (Substring.string k), "")
          else (Percent.decodeForm (Substring.string k),
                Percent.decodeForm (Substring.string (Substring.triml 1 rest)))

  fun parse "" = []
    | parse s =
        List.map parsePair (String.fields (fn c => c = #"&") s)

  fun build pairs =
    String.concatWith "&"
      (List.map (fn (k, v) => Percent.encodeForm k ^ "=" ^ Percent.encodeForm v) pairs)

  fun get q key =
    case List.find (fn (k, _) => k = key) q of
        SOME (_, v) => SOME v
      | NONE => NONE

  fun getAll q key =
    List.map (fn (_, v) => v) (List.filter (fn (k, _) => k = key) q)
end
