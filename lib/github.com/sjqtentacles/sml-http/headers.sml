(* headers.sml *)

structure Headers :> HEADERS =
struct
  (* Stored newest-appended last, preserving insertion order and original case. *)
  type headers = (string * string) list

  val empty = []
  fun fromList xs = xs
  fun toList hs = hs

  fun lower s = String.map Char.toLower s
  fun eqName a b = lower a = lower b

  fun getAll hs name =
    List.map (fn (_, v) => v) (List.filter (fn (k, _) => eqName k name) hs)

  fun get hs name =
    case getAll hs name of [] => NONE | (v :: _) => SOME v

  fun getCombined hs name =
    case getAll hs name of
        [] => NONE
      | vs => SOME (String.concatWith ", " vs)

  fun has hs name = not (List.null (getAll hs name))

  fun add hs name value = hs @ [(name, value)]

  fun remove hs name = List.filter (fn (k, _) => not (eqName k name)) hs

  fun set hs name value = remove hs name @ [(name, value)]
end
