(* session.sml -- pure session model with in-memory and signed-cookie backends. *)

structure Session :> SESSION =
struct
  (* Ordered map as an assoc list; newest writes overwrite in place so order
     is stable across put/remove. *)
  type session = (string * string) list

  val empty = []

  fun get s k =
    Option.map #2 (List.find (fn (k', _) => k' = k) s)

  fun remove s k = List.filter (fn (k', _) => k' <> k) s

  fun put s k v =
    let
      fun go [] = [(k, v)]
        | go ((k', v') :: rest) =
            if k' = k then (k, v) :: rest else (k', v') :: go rest
    in
      go s
    end

  fun toList s = s
  fun fromList pairs = List.foldl (fn ((k, v), acc) => put acc k v) [] pairs

  (* ----- JSON serialization (flat object of strings) ----- *)
  fun toJson s =
    JsonPretty.toString (Json.JObj (List.map (fn (k, v) => (k, Json.JStr v)) s))

  fun fromJson str =
    case Json.parseJson str of
        CharParsec.Ok (Json.JObj fields) =>
          let
            fun conv (k, Json.JStr v) = SOME (k, v)
              | conv (k, Json.JInt n) = SOME (k, Int.toString n)
              | conv (k, Json.JBool b) = SOME (k, Bool.toString b)
              | conv _ = NONE
          in
            case List.foldr (fn (f, acc) =>
                   case (conv f, acc) of
                       (SOME p, SOME ps) => SOME (p :: ps)
                     | _ => NONE) (SOME []) fields of
                SOME ps => SOME (fromList ps)
              | NONE => NONE
          end
      | _ => NONE

  structure Memory =
  struct
    type store = (string * session) list

    val empty = []

    fun load store sid =
      Option.map #2 (List.find (fn (s, _) => s = sid) store)

    fun save store sid sess =
      (sid, sess) :: List.filter (fn (s, _) => s <> sid) store

    fun destroy store sid =
      List.filter (fn (s, _) => s <> sid) store

    fun create store rng sess =
      let
        val (sid, rng') = Random.hexToken rng 32
      in
        (sid, save store sid sess, rng')
      end
  end

  structure SignedCookie =
  struct
    fun encode key sess = Token.sign key (toJson sess)

    fun decode key token =
      case Token.verify key token of
          NONE => NONE
        | SOME payload => fromJson payload
  end
end
