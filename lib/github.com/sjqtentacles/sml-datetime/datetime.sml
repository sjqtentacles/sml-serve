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
end
