(* html.sml -- HTML AST + safe rendering, building output via sml-buffer. *)

structure Html :> HTML =
struct
  datatype node =
      Text of string
    | Raw of string
    | Element of
        { tag : string
        , attrs : (string * string) list
        , children : node list }

  fun text s = Text s
  fun raw s = Raw s
  fun el tag attrs children = Element { tag = tag, attrs = attrs, children = children }
  fun void tag attrs = Element { tag = tag, attrs = attrs, children = [] }

  (* HTML5 void elements: no closing tag, ignore any children. *)
  fun isVoid tag =
    case String.map Char.toLower tag of
        "area" => true | "base" => true | "br" => true | "col" => true
      | "embed" => true | "hr" => true | "img" => true | "input" => true
      | "link" => true | "meta" => true | "param" => true | "source" => true
      | "track" => true | "wbr" => true | _ => false

  fun addAttr b (name, value) =
    if Escape.isSafeAttrName name
    then ( Buffer.addChar b #" "
         ; Buffer.addString b name
         ; Buffer.addString b "=\""
         ; Buffer.addString b (Escape.attr value)
         ; Buffer.addChar b #"\"" )
    else ()   (* drop unsafe attribute names rather than emit injection *)

  fun emit b node =
    case node of
        Text s => Buffer.addString b (Escape.text s)
      | Raw s => Buffer.addString b s
      | Element { tag, attrs, children } =>
          ( Buffer.addChar b #"<"
          ; Buffer.addString b tag
          ; List.app (addAttr b) attrs
          ; if isVoid tag then Buffer.addString b ">"
            else
              ( Buffer.addChar b #">"
              ; List.app (emit b) children
              ; Buffer.addString b "</"
              ; Buffer.addString b tag
              ; Buffer.addChar b #">" ) )

  fun render node = Buffer.build (fn b => emit b node)
  fun renderList nodes = Buffer.build (fn b => List.app (emit b) nodes)
  fun document node = "<!DOCTYPE html>\n" ^ render node
end
