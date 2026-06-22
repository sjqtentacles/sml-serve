(* router.sig

   A pure HTTP router: match a request's method + path against a list of route
   patterns, capturing path parameters, and dispatch to a handler. Handlers are
   pure `request -> response` functions (with captured params), so the whole
   router is deterministic and testable without a network.

   Patterns are "/"-separated segments:
     - a literal segment matches itself ("/users")
     - ":name" captures one segment as a parameter ("/users/:id")
     - "*name" (only as the last segment) captures the rest of the path,
       including slashes, as a parameter ("/static/*path")

   Matching is exact otherwise; trailing slashes are normalized away (except
   the root "/"). *)

signature ROUTER =
sig
  type params = (string * string) list
  type handler = Http.request -> params -> Http.response

  type route
  type router

  (* Build a route for a method (uppercased) + pattern. *)
  val route : string -> string -> handler -> route

  (* Method-specific helpers. *)
  val get  : string -> handler -> route
  val post : string -> handler -> route
  val put  : string -> handler -> route
  val del  : string -> handler -> route

  (* A router from an ordered route list (first match wins). *)
  val make : route list -> router

  (* Match a method + path against the routes; NONE if nothing matches. *)
  val match : router -> { method : string, path : string }
              -> (handler * params) option

  (* Dispatch a request: run the matched handler, or `onMiss` if none matches. *)
  val dispatch : router -> (Http.request -> Http.response)
                 -> Http.request -> Http.response

  (* Low-level: does a single pattern match a path? Returns captured params. *)
  val matchPattern : string -> string -> params option
end
