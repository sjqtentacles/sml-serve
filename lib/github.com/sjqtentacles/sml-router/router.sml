(* router.sml -- pure method+path routing with parameter capture. *)

structure Router :> ROUTER =
struct
  type params = (string * string) list
  type handler = Http.request -> params -> Http.response

  type route =
    { method : string, pattern : string, handler : handler }

  type router = route list

  fun upper s = String.map Char.toUpper s

  fun route m p h = { method = upper m, pattern = p, handler = h }
  fun get p h = route "GET" p h
  fun post p h = route "POST" p h
  fun put p h = route "PUT" p h
  fun del p h = route "DELETE" p h

  fun make routes = routes

  (* split a path into non-empty segments; "/" -> [] *)
  fun segments path =
    List.filter (fn s => s <> "") (String.fields (fn c => c = #"/") path)

  fun matchPattern pattern path =
    let
      val pats = segments pattern
      val segs = segments path

      fun go ([], []) acc = SOME (List.rev acc)
        | go (p :: ps, ss) acc =
            if String.size p > 0 andalso String.sub (p, 0) = #"*"
            then
              (* wildcard: capture the rest of the path (with slashes) *)
              let
                val name = String.extract (p, 1, NONE)
                val rest = String.concatWith "/" ss
              in
                case ps of
                    [] => SOME (List.rev ((name, rest) :: acc))
                  | _ => NONE   (* wildcard must be the last pattern segment *)
              end
            else
              (case ss of
                   [] => NONE
                 | (s :: ss') =>
                     if String.size p > 0 andalso String.sub (p, 0) = #":"
                     then go (ps, ss') ((String.extract (p, 1, NONE), s) :: acc)
                     else if p = s then go (ps, ss') acc
                     else NONE)
        | go ([], _ :: _) _ = NONE
    in
      go (pats, segs) []
    end

  fun match (router : router) { method, path } =
    let
      val m = upper method
      fun loop [] = NONE
        | loop ((r : route) :: rs) =
            if #method r = m
            then
              (case matchPattern (#pattern r) path of
                   SOME ps => SOME (#handler r, ps)
                 | NONE => loop rs)
            else loop rs
    in
      loop router
    end

  fun dispatch router onMiss (req : Http.request) =
    let
      val uri = Http.targetUri req
      val path = #path uri
    in
      case match router { method = #method req, path = path } of
          SOME (h, ps) => h req ps
        | NONE => onMiss req
    end
end
