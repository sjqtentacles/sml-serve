(* glob.sig

   Shell-style glob pattern matching for Standard ML.

   A glob pattern is compiled once into an abstract `pattern`, then matched
   against whole strings (matching is anchored: the entire string must match,
   as with filename globbing). Supported syntax:

     *        matches any run of characters, including the empty run
     ?        matches exactly one character
     [abc]    a character class: matches any one of a, b, c
     [a-z]    a range inside a class
     [!...]   a negated class (also [^...]); matches one char NOT listed
     \c       an escape: matches the literal character c (so \* matches '*')

   Inside a class, a leading `]` or `!`/`^` and `-` at the ends are treated as
   literals in the usual shell way. Any other character matches itself. *)

signature GLOB =
sig
  type pattern

  (* Compile a glob pattern. Always succeeds: a trailing backslash matches a
     literal backslash, and an unterminated `[` is treated as a literal `[`. *)
  val compile : string -> pattern

  (* Does the pattern match the whole string? *)
  val matches : pattern -> string -> bool

  (* compile + match in one step. *)
  val matchString : string -> string -> bool

  (* Compile a pattern that matches case-insensitively. *)
  val caseInsensitive : string -> pattern
end
