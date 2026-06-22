(* middleware.sml -- composable handler -> handler combinators. *)

structure Middleware :> MIDDLEWARE =
struct
  type request = Http.request
  type response = Http.response
  type handler = request -> response
  type middleware = handler -> handler

  fun compose mws h =
    List.foldr (fn (mw, acc) => mw acc) h mws

  fun catchErrors onError inner req =
    inner req handle e => onError e

  fun limitBody max inner (req : request) =
    if String.size (#body req) > max
    then Http.text 413 "Payload Too Large"
    else inner req

  fun logTo sink fmt inner req =
    let
      val res = inner req
      val () = sink := !sink @ [fmt (req, res)]
    in
      res
    end

  fun addHeader name value inner req =
    let
      val res = inner req : response
    in
      { version = #version res, status = #status res, reason = #reason res
      , headers = Headers.set (#headers res) name value
      , body = #body res }
    end

  fun reqPath (req : request) = #path (Http.targetUri req)

  fun static files inner (req : request) =
    let
      val m = #method req
    in
      if m <> "GET" andalso m <> "HEAD"
      then inner req
      else
        let
          val path = reqPath req
          fun find [] = NONE
            | find ((key, payload) :: rest) =
                if key = path orelse Glob.matchString key path
                then SOME payload
                else find rest
        in
          case find files of
              NONE => inner req
            | SOME (ctype, body) =>
                Http.response 200
                  (Headers.fromList [("Content-Type", ctype)])
                  (if m = "HEAD" then "" else body)
        end
    end
end
