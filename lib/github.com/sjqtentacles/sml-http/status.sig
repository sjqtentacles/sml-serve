(* status.sig

   HTTP status codes and their reason phrases (RFC 9110 + common
   registrations). *)

signature STATUS =
sig
  (* Standard reason phrase for a status code, or "Unknown" if unrecognized. *)
  val reason : int -> string
  (* Code class: 1..5 for 1xx..5xx, 0 if out of range. *)
  val classOf : int -> int
  val isInformational : int -> bool
  val isSuccess       : int -> bool
  val isRedirect      : int -> bool
  val isClientError   : int -> bool
  val isServerError   : int -> bool
  (* "200 OK", "404 Not Found", ... *)
  val line : int -> string
end
