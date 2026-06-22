(* html.sig

   A small HTML AST with safe-by-default rendering. Text and attribute values
   are escaped automatically; the only way to emit unescaped markup is the
   explicit `raw` node, so XSS holes are opt-in and greppable.

   Void elements (br, img, input, ...) render as self-contained start tags
   with no closing tag (HTML5 13.1.2). *)

signature HTML =
sig
  datatype node =
      Text of string                          (* escaped text content *)
    | Raw of string                            (* trusted, emitted verbatim *)
    | Element of
        { tag : string
        , attrs : (string * string) list       (* values escaped on render *)
        , children : node list }

  (* Convenience constructors. *)
  val text    : string -> node
  val raw     : string -> node
  val el      : string -> (string * string) list -> node list -> node
  (* Void/self-closing element (no children). *)
  val void    : string -> (string * string) list -> node

  (* Render a node (or a list / full document) to a string. *)
  val render     : node -> string
  val renderList : node list -> string
  (* Prepend "<!DOCTYPE html>\n" before the rendered root. *)
  val document   : node -> string
end
