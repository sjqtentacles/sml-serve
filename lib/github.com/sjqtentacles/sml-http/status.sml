(* status.sml *)

structure Status :> STATUS =
struct
  fun reason code =
    case code of
        100 => "Continue"
      | 101 => "Switching Protocols"
      | 200 => "OK"
      | 201 => "Created"
      | 202 => "Accepted"
      | 204 => "No Content"
      | 206 => "Partial Content"
      | 301 => "Moved Permanently"
      | 302 => "Found"
      | 303 => "See Other"
      | 304 => "Not Modified"
      | 307 => "Temporary Redirect"
      | 308 => "Permanent Redirect"
      | 400 => "Bad Request"
      | 401 => "Unauthorized"
      | 403 => "Forbidden"
      | 404 => "Not Found"
      | 405 => "Method Not Allowed"
      | 406 => "Not Acceptable"
      | 408 => "Request Timeout"
      | 409 => "Conflict"
      | 410 => "Gone"
      | 411 => "Length Required"
      | 413 => "Content Too Large"
      | 414 => "URI Too Long"
      | 415 => "Unsupported Media Type"
      | 418 => "I'm a teapot"
      | 422 => "Unprocessable Content"
      | 429 => "Too Many Requests"
      | 431 => "Request Header Fields Too Large"
      | 500 => "Internal Server Error"
      | 501 => "Not Implemented"
      | 502 => "Bad Gateway"
      | 503 => "Service Unavailable"
      | 504 => "Gateway Timeout"
      | 505 => "HTTP Version Not Supported"
      | _   => "Unknown"

  fun classOf code = if code >= 100 andalso code <= 599 then code div 100 else 0
  fun isInformational c = classOf c = 1
  fun isSuccess c = classOf c = 2
  fun isRedirect c = classOf c = 3
  fun isClientError c = classOf c = 4
  fun isServerError c = classOf c = 5

  fun line code = Int.toString code ^ " " ^ reason code
end
