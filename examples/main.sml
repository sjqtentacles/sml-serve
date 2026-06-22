(* examples/main.sml -- a runnable sml-serve demo.

   Defines a small pure `Web.app` (routing + middleware + HTML, exactly the
   shape of sml-web/examples/app.sml) and serves it over a real socket.

   Two modes:

     bin/serve-mlton serve [PORT]   -- bind 127.0.0.1:PORT (default 8080) and
                                       serve forever (Ctrl-C to stop).
     bin/serve-mlton                -- a self-contained loopback demo: bind an
                                       ephemeral 127.0.0.1 port, issue one real
                                       HTTP request to ourselves, print the
                                       response, and exit. (Deterministic.) *)

(* ---- the pure app (no sockets) ---- *)

val accessLog = ref ([] : string list)

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
        [ Middleware.logTo accessLog
            (fn (rq, rs) => #method rq ^ " " ^ #target rq ^ " -> "
                            ^ Int.toString (#status rs))
        , Middleware.catchErrors (fn _ => Http.text 500 "Internal Error")
        , Middleware.addHeader "X-Powered-By" "sml-serve" ]
    , routes =
        [ Router.get "/" home
        , Router.get "/greet/:name" greet ]
    , notFound = fn _ => Http.text 404 "Not Found" }

(* ---- a real loopback round-trip against the adapter ---- *)

fun roundTrip (request : string) : string =
  let
    val (listener, port) = Serve.listenOn { host = "127.0.0.1", port = 0 }
    val client : Serve.sock = INetSock.TCP.socket ()
    val addr = INetSock.toAddr (valOf (NetHostDB.fromString "127.0.0.1"), port)
    val () = Socket.connect (client, addr)
    val () = Serve.sendAll client request
    val (conn, _) = Socket.accept listener
    val _ = Async.runToCompletion (Serve.handleConn app conn)
    val resp = Serve.recvAll client
    val () = Socket.close client
    val () = Socket.close listener
  in
    resp
  end

fun runDemo () =
  let
    val request = "GET /greet/alice HTTP/1.1\r\nHost: localhost\r\nConnection: close\r\n\r\n"
    val resp = roundTrip request
  in
    print "=== sml-serve loopback demo ===\n";
    print "request:  GET /greet/alice HTTP/1.1\n";
    print "response over a real 127.0.0.1 socket:\n";
    print resp;
    (if String.isSuffix "\n" resp then () else print "\n");
    print "access log: ";
    print (String.concatWith " | " (!accessLog));
    print "\n"
  end

fun runServe port =
  ( print ("sml-serve: listening on http://127.0.0.1:" ^ Int.toString port ^ "/ (Ctrl-C to stop)\n")
  ; Serve.serve { host = "127.0.0.1", port = port } app )

fun main () =
  case CommandLine.arguments () of
      ("serve" :: rest) =>
        let
          val port = case rest of
                         (p :: _) => (case Int.fromString p of SOME n => n | NONE => 8080)
                       | [] => 8080
        in
          runServe port
        end
    | _ => runDemo ()

val () = main ()
