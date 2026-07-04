(* datetime.sml

   Implementation of DATETIME via Howard Hinnant's days-from-civil algorithm.

   days_from_civil(y, m, d) returns the number of days since 1970-01-01. It is
   exact for the proleptic Gregorian calendar over the full int range. The
   inverse, civil_from_days, recovers (y, m, d). Day-of-week is derived from
   the epoch day (1970-01-01 was a Thursday). *)

structure DateTime :> DATETIME =
struct
  type date = { year : int, month : int, day : int }
  exception Invalid of string

  fun isLeapYear y =
      (y mod 4 = 0 andalso y mod 100 <> 0) orelse (y mod 400 = 0)

  fun daysInMonth (y, m) =
      case m of
          1 => 31 | 2 => (if isLeapYear y then 29 else 28)
        | 3 => 31 | 4 => 30 | 5 => 31 | 6 => 30
        | 7 => 31 | 8 => 31 | 9 => 30 | 10 => 31 | 11 => 30 | 12 => 31
        | _ => raise Invalid ("month out of range: " ^ Int.toString m)

  fun isValid {year, month, day} =
      month >= 1 andalso month <= 12
      andalso day >= 1
      andalso day <= daysInMonth (year, month)

  (* Hinnant: days from 1970-01-01.  Valid for m in [1,12], d in [1, dim]. *)
  fun daysFromCivil (y, m, d) =
      let
        val y' = if m <= 2 then y - 1 else y
        (* era: 400-year cycle *)
        val era = (if y' >= 0 then y' else y' - 399) div 400
        val yoe = y' - era * 400                              (* [0, 399] *)
        val doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) div 5 + d - 1  (* [0,365] *)
        val doe = yoe * 365 + yoe div 4 - yoe div 100 + doy   (* [0, 146096] *)
      in
        era * 146097 + doe - 719468
      end

  fun civilFromDays z0 =
      let
        val z = z0 + 719468
        val era = (if z >= 0 then z else z - 146096) div 146097
        val doe = z - era * 146097                            (* [0, 146096] *)
        val yoe = (doe - doe div 1460 + doe div 36524 - doe div 146096) div 365  (* [0,399] *)
        val y = yoe + era * 400
        val doy = doe - (365 * yoe + yoe div 4 - yoe div 100)  (* [0, 365] *)
        val mp = (5 * doy + 2) div 153                         (* [0, 11] *)
        val d = doy - (153 * mp + 2) div 5 + 1                 (* [1, 31] *)
        val m = if mp < 10 then mp + 3 else mp - 9             (* [1, 12] *)
        val year = if m <= 2 then y + 1 else y
      in
        {year = year, month = m, day = d}
      end

  fun toEpochDay (date as {year, month, day}) =
      if isValid date then daysFromCivil (year, month, day)
      else raise Invalid (formatBad date)
  and formatBad {year, month, day} =
      "invalid date: " ^ Int.toString year ^ "-"
      ^ Int.toString month ^ "-" ^ Int.toString day

  fun fromEpochDay z = civilFromDays z

  fun addDays date n = fromEpochDay (toEpochDay date + n)

  fun diffDays (a, b) = toEpochDay a - toEpochDay b

  fun dayOfWeek date =
      let
        (* 1970-01-01 is a Thursday = 4 (with 0=Sunday). *)
        val e = toEpochDay date
        val w = (e + 4) mod 7
      in
        if w < 0 then w + 7 else w
      end

  (* ---- ISO 8601 (YYYY-MM-DD) ---- *)

  fun pad4 n =
      let val s = Int.toString (Int.abs n)
          val s' = if String.size s >= 4 then s
                   else StringCvt.padLeft #"0" 4 s
      in if n < 0 then "-" ^ s' else s' end

  fun pad2 n = StringCvt.padLeft #"0" 2 (Int.toString n)

  fun formatISO {year, month, day} =
      pad4 year ^ "-" ^ pad2 month ^ "-" ^ pad2 day

  (* strict: optional leading '-', then 4+ year digits, '-', 2 month, '-', 2 day *)
  fun parseISO s =
      let
        val (neg, rest) =
            if String.size s > 0 andalso String.sub (s, 0) = #"-"
            then (true, String.extract (s, 1, NONE))
            else (false, s)
        fun allDigits str =
            String.size str > 0 andalso CharVector.all Char.isDigit str
      in
        case String.tokens (fn c => c = #"-") rest of
            [ys, ms, ds] =>
              if allDigits ys andalso String.size ys >= 4
                 andalso allDigits ms andalso String.size ms = 2
                 andalso allDigits ds andalso String.size ds = 2
              then
                (case (Int.fromString ys, Int.fromString ms, Int.fromString ds) of
                     (SOME y, SOME m, SOME d) =>
                       let val date = {year = if neg then ~y else y, month = m, day = d}
                       in if isValid date then SOME date else NONE end
                   | _ => NONE)
              else NONE
          | _ => NONE
      end

  (* ===================================================================== *)
  (* Time of day                                                           *)
  (* ===================================================================== *)

  type time = { hour : int, minute : int, second : int, nano : int }

  (* Small bound that fits the default 32-bit int (e.g. MLton). *)
  val nanosPerSecond = 1000000000

  (* Wide constants for sub-day / instant arithmetic. LargeInt is arbitrary
     precision (IntInf) on both MLton and Poly/ML, so these stay exact even
     though the default `int` is fixed-width (32-bit MLton, 63-bit Poly/ML). *)
  val billion        : LargeInt.int = 1000000000
  val secondsPerDayL : LargeInt.int = 86400

  val midnight : time = { hour = 0, minute = 0, second = 0, nano = 0 }

  fun isValidTime {hour, minute, second, nano} =
      hour   >= 0 andalso hour   <= 23
      andalso minute >= 0 andalso minute <= 59
      andalso second >= 0 andalso second <= 59
      andalso nano   >= 0 andalso nano   <  nanosPerSecond

  fun formatBadTime {hour, minute, second, nano} =
      "invalid time: " ^ Int.toString hour ^ ":" ^ Int.toString minute
      ^ ":" ^ Int.toString second ^ "." ^ Int.toString nano

  fun secondOfDay (t as {hour, minute, second, ...}) =
      if isValidTime t then hour * 3600 + minute * 60 + second
      else raise Invalid (formatBadTime t)

  fun nanoOfDay (t as {nano, ...}) =
      LargeInt.fromInt (secondOfDay t) * billion + LargeInt.fromInt nano

  fun timeFromNanoOfDay n =
      let
        val nano   = n mod billion
        val totSec = n div billion
        val second = totSec mod 60
        val totMin = totSec div 60
        val minute = totMin mod 60
        val hour   = totMin div 60
      in
        { hour   = LargeInt.toInt hour,
          minute = LargeInt.toInt minute,
          second = LargeInt.toInt second,
          nano   = LargeInt.toInt nano }
      end

  (* ===================================================================== *)
  (* Datetime / instant (UTC)                                              *)
  (* ===================================================================== *)

  type datetime = { date : date, time : time }

  fun isValidDateTime {date, time} = isValid date andalso isValidTime time

  fun toEpochSecond {date, time} =
      (* toEpochDay validates the date; secondOfDay validates the time. *)
      LargeInt.fromInt (toEpochDay date) * secondsPerDayL
      + LargeInt.fromInt (secondOfDay time)

  fun fromEpochSecond s =
      let
        (* SML div/mod floor toward negative infinity, so sod is in [0,86399]. *)
        val day = s div secondsPerDayL
        val sod = s mod secondsPerDayL
      in
        { date = fromEpochDay (LargeInt.toInt day),
          time = timeFromNanoOfDay (sod * billion) }
      end

  (* ===================================================================== *)
  (* Durations                                                             *)
  (* ===================================================================== *)

  type duration = { seconds : LargeInt.int, nanos : int }

  fun normalizeDuration (s, n) =
      let
        val carry = n div billion     (* floors toward -inf *)
        val nanos = n mod billion      (* [0, 1e9) *)
      in
        { seconds = s + carry, nanos = LargeInt.toInt nanos }
      end

  fun durationFromSeconds s = { seconds = s, nanos = 0 }

  (* nanos is always >= 0, so the floored whole-seconds value is #seconds. *)
  fun durationToSeconds ({seconds, ...} : duration) = seconds

  fun negateDuration ({seconds, nanos} : duration) =
      normalizeDuration (~seconds, ~ (LargeInt.fromInt nanos))

  fun addDurations (a : duration, b : duration) =
      normalizeDuration (#seconds a + #seconds b,
                         LargeInt.fromInt (#nanos a) + LargeInt.fromInt (#nanos b))

  fun subDurations (a : duration, b : duration) =
      normalizeDuration (#seconds a - #seconds b,
                         LargeInt.fromInt (#nanos a) - LargeInt.fromInt (#nanos b))

  fun scaleDuration ({seconds, nanos} : duration, k) =
      let val kL = LargeInt.fromInt k
      in normalizeDuration (seconds * kL, LargeInt.fromInt nanos * kL) end

  fun addDuration (dt as {time, ...} : datetime, dur : duration) =
      let
        val {seconds, nanos} =
            normalizeDuration (toEpochSecond dt + #seconds dur,
                               LargeInt.fromInt (#nano time)
                               + LargeInt.fromInt (#nanos dur))
        val {date = d', time = t'} = fromEpochSecond seconds
      in
        { date = d',
          time = { hour = #hour t', minute = #minute t',
                   second = #second t', nano = nanos } }
      end

  fun subDuration (dt, dur) = addDuration (dt, negateDuration dur)

  fun diff (a : datetime, b : datetime) =
      normalizeDuration (toEpochSecond a - toEpochSecond b,
                         LargeInt.fromInt (#nano (#time a))
                         - LargeInt.fromInt (#nano (#time b)))

  (* ===================================================================== *)
  (* ISO 8601 datetime                                                     *)
  (* ===================================================================== *)

  fun formatFraction 0 = ""
    | formatFraction n =
      let
        val s = StringCvt.padLeft #"0" 9 (Int.toString n)
        fun lastNonZero i =
            if i < 0 then 0
            else if String.sub (s, i) <> #"0" then i + 1
            else lastNonZero (i - 1)
        val keep = lastNonZero (String.size s - 1)
      in
        "." ^ String.substring (s, 0, keep)
      end

  fun formatDateTimeISO {date, time = {hour, minute, second, nano}} =
      formatISO date ^ "T" ^ pad2 hour ^ ":" ^ pad2 minute ^ ":" ^ pad2 second
      ^ formatFraction nano ^ "Z"

  (* Parse exactly `count` digits starting at index i; return (value, nextIndex). *)
  fun takeDigits (s, i, count) =
      let
        fun loop (j, acc, taken) =
            if taken = count then SOME (acc, j)
            else if j < String.size s andalso Char.isDigit (String.sub (s, j))
            then loop (j + 1, acc * 10 + (Char.ord (String.sub (s, j)) - Char.ord #"0"), taken + 1)
            else NONE
      in
        loop (i, 0, 0)
      end

  fun fracToNanos digits =
      let
        val n = String.size digits
      in
        if n = 0 orelse n > 9 orelse not (CharVector.all Char.isDigit digits)
        then NONE
        else
          (case Int.fromString (StringCvt.padRight #"0" 9 digits) of
               SOME v => SOME v
             | NONE => NONE)
      end

  (* Parse "+hh:mm" / "-hh:mm" into a signed offset in seconds. *)
  fun parseOffset s =
      if String.size s <> 6 then NONE
      else
        let
          val sign = String.sub (s, 0)
        in
          if (sign <> #"+" andalso sign <> #"-") orelse String.sub (s, 3) <> #":"
          then NONE
          else
            let
              val hh = String.substring (s, 1, 2)
              val mm = String.substring (s, 4, 2)
            in
              if CharVector.all Char.isDigit hh andalso CharVector.all Char.isDigit mm
              then
                (case (Int.fromString hh, Int.fromString mm) of
                     (SOME h, SOME m) =>
                       if h <= 23 andalso m <= 59
                       then SOME ((if sign = #"-" then ~1 else 1) * (h * 3600 + m * 60))
                       else NONE
                   | _ => NONE)
              else NONE
            end
        end

  fun parseDateTimeISO s =
      let
        fun findT i =
            if i >= String.size s then NONE
            else if String.sub (s, i) = #"T" then SOME i
            else findT (i + 1)
      in
        case findT 0 of
            NONE => NONE
          | SOME ti =>
              (case parseISO (String.substring (s, 0, ti)) of
                   NONE => NONE
                 | SOME date =>
                     let
                       val tp = String.extract (s, ti + 1, NONE)
                       (* Peel a trailing offset (Z or +/-hh:mm) off the time. *)
                       val (core, offset) =
                           if String.size tp > 0
                              andalso (String.sub (tp, String.size tp - 1) = #"Z"
                                       orelse String.sub (tp, String.size tp - 1) = #"z")
                           then (String.substring (tp, 0, String.size tp - 1), SOME 0)
                           else if String.size tp >= 6
                                   andalso (String.sub (tp, String.size tp - 6) = #"+"
                                            orelse String.sub (tp, String.size tp - 6) = #"-")
                           then (String.substring (tp, 0, String.size tp - 6),
                                 parseOffset (String.extract (tp, String.size tp - 6, NONE)))
                           else (tp, SOME 0)
                     in
                       case offset of
                           NONE => NONE
                         | SOME offSecs => parseTimeCore (date, core, offSecs)
                     end)
      end
  and parseTimeCore (date, core, offSecs) =
      (* core is "hh:mm:ss" or "hh:mm:ss.fff" *)
      (case takeDigits (core, 0, 2) of
           SOME (hh, i1) =>
             if i1 < String.size core andalso String.sub (core, i1) = #":"
             then
               (case takeDigits (core, i1 + 1, 2) of
                    SOME (mm, i2) =>
                      if i2 < String.size core andalso String.sub (core, i2) = #":"
                      then
                        (case takeDigits (core, i2 + 1, 2) of
                             SOME (ss, i3) =>
                               let
                                 val fracRes =
                                     if i3 = String.size core then SOME 0
                                     else if String.sub (core, i3) = #"."
                                     then fracToNanos (String.extract (core, i3 + 1, NONE))
                                     else NONE
                               in
                                 case fracRes of
                                     NONE => NONE
                                   | SOME nano =>
                                       let
                                         val time = {hour = hh, minute = mm,
                                                     second = ss, nano = nano}
                                       in
                                         if isValidTime time
                                         then
                                           let
                                             val utcSec =
                                                 LargeInt.fromInt (toEpochDay date)
                                                 * secondsPerDayL
                                                 + LargeInt.fromInt (secondOfDay time)
                                                 - LargeInt.fromInt offSecs
                                             val {date = d', time = t'} =
                                                 fromEpochSecond utcSec
                                           in
                                             SOME { date = d',
                                                    time = { hour = #hour t',
                                                             minute = #minute t',
                                                             second = #second t',
                                                             nano = nano } }
                                           end
                                         else NONE
                                       end
                               end
                           | NONE => NONE)
                      else NONE
                  | NONE => NONE)
             else NONE
         | NONE => NONE)
end
