(* middleware.sig

   Composable middleware for the pure HTTP core. A `handler` turns a request
   into a response; a `middleware` wraps a handler to produce a new handler, so
   they stack with ordinary function composition.

   Everything here is pure: the request/response model is sml-http's, and even
   "logging" and "static files" are pure -- logs are accumulated in a mutable
   sink the caller owns, and static files are served from an in-memory map
   rather than the OS, keeping the core deterministic and testable. *)

signature MIDDLEWARE =
sig
  type request = Http.request
  type response = Http.response
  type handler = request -> response
  type middleware = handler -> handler

  (* Apply middlewares left-to-right so the first listed wraps outermost:
     `compose [a, b] h` = `a (b h)`. *)
  val compose : middleware list -> middleware

  (* Catch any exception raised by the inner handler and return `onError`
     applied to it (typically a 500). *)
  val catchErrors : (exn -> response) -> middleware

  (* Reject requests whose body exceeds `max` bytes with a 413 response. *)
  val limitBody : int -> middleware

  (* Append a log line per request to `sink` using `fmt (req, res)`. The sink
     is the caller's ref so tests can inspect it deterministically. *)
  val logTo : string list ref -> (request * response -> string) -> middleware

  (* Add a fixed response header to every response. *)
  val addHeader : string -> string -> middleware

  (* Serve files from an in-memory map of (path, (contentType, body)). If the
     request method is GET/HEAD and its path matches an entry (exact match, or
     a glob pattern key), respond with it; otherwise fall through to the inner
     handler. *)
  val static : (string * (string * string)) list -> middleware
end
