(* web.sml -- the umbrella app wiring router + middleware + negotiation. *)

structure Web :> WEB =
struct
  type request = Http.request
  type response = Http.response

  type app = { handler : request -> response }

  fun make { middleware, routes, notFound } =
    let
      val router = Router.make routes
      val base : request -> response =
        fn req => Router.dispatch router notFound req
      val handler = Middleware.compose middleware base
    in
      { handler = handler }
    end

  fun run (app : app) req = #handler app req

  fun runString app raw =
    Option.map (run app) (Http.parseRequest raw)

  fun headerOr (req : request) name =
    case Headers.get (#headers req) name of SOME v => v | NONE => ""

  fun negotiateMedia req offers =
    Negotiate.acceptMedia { header = headerOr req "accept", offers = offers }

  fun negotiateLanguage req offers =
    Negotiate.acceptLanguage { header = headerOr req "accept-language", offers = offers }

  fun negotiateEncoding req offers =
    Negotiate.acceptEncoding { header = headerOr req "accept-encoding", offers = offers }
end
