(* test/integration.sml -- loopback integration tests for the socket adapter.

   Unlike every other repo in the stack, these are NOT pure, byte-identical
   Harness checks: the adapter is impure and MLton-only, so we exercise it the
   only honest way -- by binding a real listener on 127.0.0.1, issuing real
   HTTP requests over the loopback interface, and asserting on the bytes that
   come back.

   Everything runs in a single OS thread: a client socket connects to the
   listener (the kernel completes the handshake into the accept backlog), we
   write the request, then the adapter accepts and handles the connection on
   the sml-async scheduler, and finally the client reads the response. This
   needs the local loopback network but no external hosts. *)

structure IntegrationTests =
struct
  (* ---- the pure app under test ---- *)

  fun page title body =
    Html.render
      (Html.el "html" []
         [ Html.el "head" [] [ Html.el "title" [] [ Html.text title ] ]
         , Html.el "body" [] body ])

  val home : Router.handler =
    fn _ => fn _ =>
      Http.response 200
        (Headers.fromList [("Content-Type", "text/html")])
        (page "Home" [ Html.el "h1" [] [ Html.text "Welcome to sml-web" ] ])

  val greet : Router.handler =
    fn _ => fn params =>
      let
        val who = case List.find (fn (k, _) => k = "name") params of
                      SOME (_, v) => v | NONE => "stranger"
      in
        Http.response 200
          (Headers.fromList [("Content-Type", "text/html")])
          (page "Greeting" [ Html.el "p" [] [ Html.text ("Hello, " ^ who ^ "!") ] ])
      end

  val app =
    Web.make
      { middleware =
          [ Middleware.catchErrors (fn _ => Http.text 500 "Internal Error")
          , Middleware.addHeader "X-Powered-By" "sml-serve" ]
      , routes =
          [ Router.get "/" home
          , Router.get "/greet/:name" greet ]
      , notFound = fn _ => Http.text 404 "Not Found" }

  (* ---- loopback driver ---- *)

  fun loopbackAddr port =
    INetSock.toAddr (valOf (NetHostDB.fromString "127.0.0.1"), port)

  (* Send `request` over a fresh loopback connection, let the adapter handle
     the connection to completion, and return the full response bytes (read
     until the adapter closes the socket). *)
  fun exchange (request : string) : string =
    let
      val (listener, port) = Serve.listenOn { host = "127.0.0.1", port = 0 }
      val client : Serve.sock = INetSock.TCP.socket ()
      val () = Socket.connect (client, loopbackAddr port)
      val () = Serve.sendAll client request
      val (conn, _) = Socket.accept listener
      val _ = Async.runToCompletion (Serve.handleConn app conn)
      val resp = Serve.recvAll client
      val () = Socket.close client
      val () = Socket.close listener
    in
      resp
    end

  fun occurrences (needle : string) (hay : string) : int =
    let
      val n = String.size needle
      fun go i acc =
        if i + n > String.size hay then acc
        else if String.substring (hay, i, n) = needle then go (i + 1) (acc + 1)
        else go (i + 1) acc
    in
      if n = 0 then 0 else go 0 0
    end

  fun has needle hay = String.isSubstring needle hay

  fun run () =
    let
      open Harness
    in
      section "sml-serve loopback integration";

      (* 1. a routed GET with a path parameter *)
      let val r = exchange
            "GET /greet/alice HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n"
      in
        check "greet: 200 status line"   (has "HTTP/1.1 200" r);
        check "greet: rendered body"     (has "Hello, alice!" r);
        check "greet: adapter Content-Length added"
                                         (has "Content-Length:" r);
        check "greet: Connection: close honored"
                                         (has "Connection: close" r);
        check "greet: middleware header" (has "X-Powered-By: sml-serve" r)
      end;

      (* 2. the index route *)
      let val r = exchange "GET / HTTP/1.1\r\nConnection: close\r\n\r\n"
      in
        check "home: 200 status line"  (has "HTTP/1.1 200" r);
        check "home: rendered body"    (has "Welcome to sml-web" r)
      end;

      (* 3. an unmatched route -> notFound 404 *)
      let val r = exchange "GET /missing HTTP/1.1\r\nConnection: close\r\n\r\n"
      in
        check "missing: 404 status line" (has "404" r);
        check "missing: Not Found body"  (has "Not Found" r)
      end;

      (* 4. a malformed message -> 400 *)
      let val r = exchange "GARBAGE\r\n\r\n"
      in
        check "malformed: 400 status line" (has "400" r);
        check "malformed: Bad Request body" (has "Bad Request" r)
      end;

      (* 5. a Content-Length body is framed and consumed (POST -> 404 here) *)
      let val r = exchange
            ("POST /submit HTTP/1.1\r\nContent-Length: 11\r\n"
             ^ "Connection: close\r\n\r\nhello world")
      in
        check "body: framed + dispatched (404)" (has "404" r)
      end;

      (* 6. keep-alive: two pipelined requests on one connection; the first
            keeps the connection alive, the second closes it. Both must be
            answered, proving the keep-alive loop + pipelined framing. *)
      let
        val r = exchange
          ("GET / HTTP/1.1\r\n\r\n"
           ^ "GET /greet/bob HTTP/1.1\r\nConnection: close\r\n\r\n")
      in
        check "keep-alive: two 200 responses"
              (occurrences "HTTP/1.1 200" r = 2);
        check "keep-alive: first body"  (has "Welcome to sml-web" r);
        check "keep-alive: second body" (has "Hello, bob!" r)
      end;

      ()
    end
end
