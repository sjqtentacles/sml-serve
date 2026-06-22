(* forms.sml -- error-accumulating validation over form/query/JSON sources. *)

structure Forms :> FORMS =
struct
  type error = { field : string, message : string }

  datatype 'a validation = Valid of 'a | Invalid of error list

  type source = string -> string option

  fun fromPairs pairs name =
    Option.map #2 (List.find (fn (k, _) => k = name) pairs)

  fun fromUrlEncoded s = fromPairs (Query.parse s)

  fun fromJson json =
    let
      val members =
        case json of
            Json.JObj kvs => kvs
          | _ => []
      fun valueToString v =
        case v of
            Json.JStr s => SOME s
          | Json.JInt i => SOME (Int.toString i)
          | Json.JReal r => SOME (Real.toString r)
          | Json.JBool b => SOME (Bool.toString b)
          | _ => NONE
    in
      fn name =>
        case List.find (fn (k, _) => k = name) members of
            NONE => NONE
          | SOME (_, v) => valueToString v
    end

  fun pure x = Valid x
  fun fail field message = Invalid [{ field = field, message = message }]

  fun map f (Valid x) = Valid (f x)
    | map _ (Invalid es) = Invalid es

  fun and2 (a, b) =
    case (a, b) of
        (Valid x, Valid y) => Valid (x, y)
      | (Invalid e1, Invalid e2) => Invalid (e1 @ e2)
      | (Invalid e1, _) => Invalid e1
      | (_, Invalid e2) => Invalid e2

  fun and3 (a, b, c) =
    map (fn ((x, y), z) => (x, y, z)) (and2 (and2 (a, b), c))

  fun and4 (a, b, c, d) =
    map (fn (((w, x), y), z) => (w, x, y, z)) (and2 (and2 (and2 (a, b), c), d))

  fun string (src : source) name =
    case src name of
        SOME v => Valid v
      | NONE => fail name "is required"

  (* strict integer: optional sign then all digits *)
  fun parseIntStrict s =
    let
      val (sign, digits) =
        if String.size s > 0 andalso (String.sub (s, 0) = #"-" orelse String.sub (s, 0) = #"+")
        then (String.substring (s, 0, 1), String.extract (s, 1, NONE))
        else ("", s)
    in
      if digits <> "" andalso CharVector.all Char.isDigit digits
      then Int.fromString (if sign = "-" then "~" ^ digits else digits)
      else NONE
    end

  fun int (src : source) name =
    case src name of
        NONE => fail name "is required"
      | SOME v =>
          (case parseIntStrict v of
               SOME i => Valid i
             | NONE => fail name "must be an integer")

  fun bool (src : source) name =
    case src name of
        NONE => fail name "is required"
      | SOME v =>
          (case String.map Char.toLower v of
               "true" => Valid true
             | "false" => Valid false
             | "1" => Valid true
             | "0" => Valid false
             | "on" => Valid true
             | _ => fail name "must be a boolean")

  fun optional (src : source) name = Valid (src name)

  fun default d (src : source) name =
    case src name of SOME v => Valid v | NONE => Valid d

  fun isValid (Valid _) = true
    | isValid (Invalid _) = false

  fun errors (Valid _) = []
    | errors (Invalid es) = es
end
