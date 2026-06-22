(* uri.sig

   A generic URI per RFC 3986. Components are stored *raw* (still
   percent-encoded) so that round-tripping `parse`/`toString` is exact;
   decode individual pieces with `Percent.decode` as needed.

       scheme "://" authority path [ "?" query ] [ "#" fragment ]

   Each optional component is NONE when absent (distinct from present-but-
   empty, e.g. `foo:` has scheme "foo" and empty path). *)

signature URI =
sig
  type uri =
    { scheme    : string option
    , authority : string option   (* host[:port], possibly userinfo@ *)
    , path      : string
    , query     : string option
    , fragment  : string option }

  (* Parse any URI or relative reference (RFC 3986 Appendix B regex). Total. *)
  val parse    : string -> uri
  (* Reassemble (RFC 3986 section 5.3). toString o parse is the identity. *)
  val toString : uri -> string

  (* Resolve a (possibly relative) reference against a base URI
     (RFC 3986 section 5.2). *)
  val resolve  : uri -> uri -> uri   (* resolve base ref *)
  (* Convenience over strings. *)
  val resolveStr : string -> string -> string

  (* Parsed query of the URI's query component (form-urlencoded). *)
  val queryParams : uri -> (string * string) list
end
