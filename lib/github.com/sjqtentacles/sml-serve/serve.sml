(* serve.sml -- the one impure edge of the sjqtentacles web stack.

   A real, MLton-only socket adapter that drives a pure `Web.app` (from
   sml-web) over a live TCP listener, using the sml-async scheduler as the
   accept event loop. It is the only module in the whole stack that opens
   sockets, reads/writes bytes, and touches the OS; everything it dispatches
   to (`Web.run` / `Http.*`) is pure and fully tested in the core repos.

   Pipeline (per the README's "Responsibilities of the adapter"):

     1. Listen   -- bind a passive stream socket on host/port.
     2. Accept   -- on the sml-async scheduler, accept connections and start
                    one async task per connection (Async.start).
     3. Read     -- frame one full HTTP/1.1 message: headers up to CRLFCRLF,
                    then a body sized by Content-Length or Transfer-Encoding:
                    chunked (decoded purely by Http.decodeChunked).
     4. Dispatch -- hand the assembled request to the pure app (Web.run); a
                    malformed message becomes a 400.
     5. Write    -- serialize with Http.serializeResponse and write it back.
     6. Repeat   -- loop for keep-alive (RFC 9112), or close.

   Quarantine: MLton-only, impure, NOT covered by the dual-compiler
   byte-identical purity guarantee that the rest of the stack provides. *)

structure Serve =
struct
  structure WV  = Word8Vector
  structure WVS = Word8VectorSlice

  type sock = (INetSock.inet, Socket.active Socket.stream) Socket.sock

  infix >>= ;  val op>>= = Async.>>=

  val chunkSize = 4096

  (* ---- byte <-> string helpers over MLton sockets ---- *)

  fun sendAll (sock : sock) (s : string) : unit =
    let
      val v = Byte.stringToBytes s
      fun go i =
        if i >= WV.length v then ()
        else
          let val sent = Socket.sendVec (sock, WVS.slice (v, i, NONE))
          in if sent <= 0 then () else go (i + sent) end
    in
      go 0
    end

  (* Receive one chunk; NONE marks an orderly shutdown / EOF. *)
  fun recvChunk (sock : sock) : string option =
    let val v = Socket.recvVec (sock, chunkSize)
    in if WV.length v = 0 then NONE else SOME (Byte.bytesToString v) end

  (* Read every remaining byte until EOF (used by the close path / clients). *)
  fun recvAll (sock : sock) : string =
    let
      fun go acc =
        case recvChunk sock of
            NONE => String.concat (List.rev acc)
          | SOME more => go (more :: acc)
    in
      go []
    end

  (* ---- HTTP/1.1 message framing ---- *)

  (* Index just past the first CRLFCRLF header terminator, if present. *)
  fun headerEnd (buf : string) : int option =
    let val (pre, rest) = Substring.position "\r\n\r\n" (Substring.full buf)
    in if Substring.isEmpty rest then NONE else SOME (Substring.size pre + 4) end

  (* Given the parsed headers and the bytes that follow the head, decide how
     much of `afterHead` is this message's body and what remains for the next
     pipelined message. NONE means "need more bytes from the socket". *)
  fun frameBody headers (afterHead : string)
      : { body : string, rest : string } option =
    let
      val lower = String.map Char.toLower
    in
      case Headers.get headers "Transfer-Encoding" of
          SOME te =>
            if String.isSubstring "chunked" (lower te)
            then (case Http.decodeChunked afterHead of
                      (* complete chunked body present; we cannot cheaply know
                         how many raw bytes it consumed, so assume the chunked
                         message is not pipelined and consume the remainder. *)
                      SOME _ => SOME { body = afterHead, rest = "" }
                    | NONE => NONE)
            else SOME { body = afterHead, rest = "" }
        | NONE =>
            (case Headers.get headers "Content-Length" of
                 SOME lenStr =>
                   (case Int.fromString lenStr of
                        SOME n =>
                          if n < 0 then SOME { body = "", rest = afterHead }
                          else if String.size afterHead >= n
                          then SOME { body = String.substring (afterHead, 0, n)
                                    , rest = String.extract (afterHead, n, NONE) }
                          else NONE
                      | NONE => SOME { body = "", rest = afterHead })
               (* No framing headers => a request has no body (RFC 9112 6.3). *)
               | NONE => SOME { body = "", rest = afterHead })
    end

  (* Read exactly one full HTTP message, starting from any bytes already
     buffered in `initial`. Returns SOME (rawMessage, leftover) or NONE on EOF
     before any bytes arrived. On a malformed head we hand back the whole
     buffer so dispatch can answer 400. *)
  fun readMessage (sock : sock) (initial : string)
      : (string * string) option =
    let
      fun frame buf =
        case headerEnd buf of
            NONE => NONE
          | SOME hbEnd =>
              let
                val head = String.substring (buf, 0, hbEnd)
                val afterHead = String.extract (buf, hbEnd, NONE)
              in
                case Http.parseRequest head of
                    NONE => SOME (buf, "")     (* malformed head -> 400 *)
                  | SOME req =>
                      (case frameBody (#headers req) afterHead of
                           NONE => NONE
                         | SOME { body, rest } => SOME (head ^ body, rest))
              end
      fun go buf =
        case frame buf of
            SOME res => SOME res
          | NONE =>
              (case recvChunk sock of
                   NONE => if buf = "" then NONE else SOME (buf, "")
                 | SOME more => go (buf ^ more))
    in
      go initial
    end

  (* ---- keep-alive policy (RFC 9112 9.x) ---- *)

  fun keepAlive (req : Http.request) : bool =
    case Headers.get (#headers req) "Connection" of
        SOME c => not (String.isSubstring "close" (String.map Char.toLower c))
      | NONE => #version req = "HTTP/1.1"

  (* Make a response wire-safe: add a Content-Length when the handler left the
     body unframed (no Content-Length and no Transfer-Encoding), and advertise
     the connection disposition we actually intend to use. *)
  fun finalize (alive : bool) (res : Http.response) : Http.response =
    let
      val hs0 = #headers res
      val framed = Headers.has hs0 "Content-Length"
                   orelse Headers.has hs0 "Transfer-Encoding"
      val hs1 = if framed then hs0
                else Headers.set hs0 "Content-Length"
                       (Int.toString (String.size (#body res)))
      val hs2 = Headers.set hs1 "Connection"
                  (if alive then "keep-alive" else "close")
    in
      { version = #version res, status = #status res, reason = #reason res
      , headers = hs2, body = #body res }
    end

  fun badRequest () : Http.response = Http.text 400 "Bad Request"

  (* ---- per-connection handler (async) ---- *)

  (* Serve one accepted connection: frame -> dispatch (pure) -> write, looping
     while keep-alive holds, then close. All I/O is lifted through Async.delay
     so the handler is an ordinary `unit Async.async` the scheduler can run. *)
  fun handleConn (app : Web.app) (sock : sock) : unit Async.async =
    let
      fun loop leftover =
        Async.delay (fn () => readMessage sock leftover) >>= (fn msgOpt =>
          case msgOpt of
              NONE => Async.delay (fn () => Socket.close sock)
            | SOME (raw, rest) =>
                let
                  val (res, alive) =
                    case Http.parseRequest raw of
                        NONE => (badRequest (), false)
                      | SOME req => (Web.run app req, keepAlive req)
                  val wire = Http.serializeResponse (finalize alive res)
                in
                  Async.delay (fn () => sendAll sock wire) >>= (fn () =>
                    if alive then loop rest
                    else Async.delay (fn () => Socket.close sock))
                end)
    in
      loop ""
    end

  (* ---- listener setup ---- *)

  fun resolveAddr (host : string, port : int) : INetSock.sock_addr =
    case NetHostDB.fromString host of
        SOME ia => INetSock.toAddr (ia, port)
      | NONE =>
          (case NetHostDB.getByName host of
               SOME entry => INetSock.toAddr (NetHostDB.addr entry, port)
             | NONE => INetSock.any port)

  (* Bind a passive listener and return it together with the port actually
     bound (useful when `port = 0` asks the OS for an ephemeral port). *)
  fun listenOn { host : string, port : int }
      : (INetSock.inet, Socket.passive Socket.stream) Socket.sock * int =
    let
      val listener = INetSock.TCP.socket ()
      val () = Socket.Ctl.setREUSEADDR (listener, true)
      val () = Socket.bind (listener, resolveAddr (host, port))
      val () = Socket.listen (listener, 128)
      val (_, boundPort) = INetSock.fromAddr (Socket.Ctl.getSockName listener)
    in
      (listener, boundPort)
    end

  (* ---- the public entry point ---- *)

  (* Bind a listener and serve forever, accepting on the sml-async scheduler
     and starting one async task per connection. Returns only if the scheduler
     ever goes idle (in practice it blocks in `accept`).

     The accept step is trampolined through `Scheduler.soon` so the loop runs
     in constant stack space across unboundedly many connections, rather than
     recursing through CPS continuations. *)
  fun serve { host : string, port : int } (app : Web.app) : unit =
    let
      val sched = Scheduler.new ()
      val (listener, _) = listenOn { host = host, port = port }
      fun acceptOne () =
        let
          val (conn, _) = Socket.accept listener
        in
          ignore (Async.start sched (handleConn app conn));
          Scheduler.soon sched acceptOne
        end
      val () = Scheduler.soon sched acceptOne
    in
      Scheduler.run sched
    end
end
