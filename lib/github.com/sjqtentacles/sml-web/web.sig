(* web.sig

   The umbrella: one pure `request -> response` application assembled from a
   router and a middleware stack. This is the top of the sjqtentacles web
   stack -- it does not add new protocol logic, it wires the pieces (sml-router,
   sml-middleware, sml-negotiate, sml-http) into a single handler that can be
   tested end-to-end over hand-built requests, with no sockets.

   `make` builds an app from middlewares (applied outermost-first), a route
   list, and a fallback handler. `handle` runs a request through it. *)

signature WEB =
sig
  type request = Http.request
  type response = Http.response
  type app

  (* Build an app: middleware stack (outermost first), routes, and a fallback
     for unmatched requests. *)
  val make :
    { middleware : Middleware.middleware list
    , routes : Router.route list
    , notFound : request -> response }
    -> app

  (* Run a parsed request through the app. *)
  val run : app -> request -> response

  (* Convenience: parse a raw HTTP request string and run it; NONE if the
     request is malformed. *)
  val runString : app -> string -> response option

  (* Negotiation helpers reading the request's Accept* headers. *)
  val negotiateMedia    : request -> string list -> string option
  val negotiateLanguage : request -> string list -> string option
  val negotiateEncoding  : request -> string list -> string option
end
