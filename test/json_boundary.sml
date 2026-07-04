(* test/json_boundary.sml -- boundary tests for the vendored sml-json's widened
   integer payload.

   Upstream sml-json changed `JInt of int` to `JInt of IntInf.int` so that a
   large JSON integer (a millisecond timestamp, a 64-bit id, ...) parses and
   serializes losslessly instead of raising `Overflow`. sml-serve vendors that
   library (through sml-session and sml-forms), so these checks guard the whole
   integer path end to end: parse a document -> inspect the `JInt` -> serialize
   it back.

   Unlike the loopback integration suite, this file is PURE: no sockets, no
   clock, no OS I/O. It is a deterministic `string -> string` over the JSON
   serializer, so it produces byte-identical output under MLton (fixed-width
   default `int`) and Poly/ML (fixed-width 63-bit `int`) -- exactly the values
   that a naive machine-`int` `JInt` would have overflowed. That portability is
   what lets the same assertions run and be diffed on both compilers. *)

structure JsonBoundaryTests =
struct
  fun parse s =
    case Json.parseJson s of
        CharParsec.Ok v  => v
      | CharParsec.Err e => raise Fail ("parse failed: " ^ CharParsec.errorToString e)

  (* A value comfortably past MLton's default 32-bit `Int` range
     (2^31 - 1 = 2147483647); a real-world millisecond epoch timestamp. *)
  val bigStr = "1700000000000"
  val big    = 1700000000000 : IntInf.int

  (* A value past even a 63-bit `Int` (Poly/ML's default): 2^70. Only genuine
     arbitrary precision (IntInf) round-trips this at all. *)
  val hugeStr = "1180591620717411303424"
  val huge    = IntInf.<< (1, 0w70)

  fun run () =
    let
      open Harness
    in
      section "sml-serve vendored sml-json integer boundary";

      (* 1. A large integer field parses to the exact IntInf value (no
            Overflow, no truncation) -- the crash this change fixes. *)
      let val v = parse ("{\"ts\":" ^ bigStr ^ "}")
      in
        check "parse: large int does not raise" true;
        case v of
            Json.JObj [("ts", Json.JInt n)] =>
              check "parse: large int value is exact" (n = big)
          | _ => check "parse: large int shape" false
      end;

      (* 2. Round-trip: parse then serialize reproduces the digits losslessly
            (this is the byte-identical, cross-compiler property). *)
      checkString "round-trip: large int serializes losslessly"
        (bigStr, JsonPretty.toString (parse bigStr));

      (* 3. Arbitrary precision: a value beyond 63-bit int also round-trips,
            proving it is IntInf and not a widened-but-still-fixed machine int. *)
      let val v = parse hugeStr
      in
        (case v of
             Json.JInt n => check "parse: 2^70 value is exact" (n = huge)
           | _ => check "parse: 2^70 shape" false);
        checkString "round-trip: 2^70 serializes losslessly"
          (hugeStr, JsonPretty.toString v)
      end;

      (* 4. asInt narrows when it fits and returns NONE (rather than raising)
            when the value is out of the machine-`int` range on this compiler. *)
      checkBool "asInt: small value narrows"
        (true, Json.asInt (Json.JInt 42) = SOME 42);
      checkBool "asInt: 2^70 is out of range -> NONE"
        (true, Json.asInt (Json.JInt huge) = NONE);

      ()
    end
end
