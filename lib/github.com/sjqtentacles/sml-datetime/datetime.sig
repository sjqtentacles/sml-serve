(* datetime.sig

   Civil (proleptic Gregorian) date arithmetic for Standard ML: leap years,
   day counting, epoch-day conversion, day-of-week, and ISO-8601 (YYYY-MM-DD)
   parsing/formatting.

   This is timezone-free, I/O-free, and deterministic: a `date` is a plain
   year/month/day record. Months are 1-12 and days are 1-31 (validated against
   the month). The epoch is 1970-01-01 (epoch day 0); dates before it have
   negative epoch days, and the algorithm is valid for any year (including
   negative / pre-1 years in the proleptic calendar).

   Conversions use Howard Hinnant's branch-free days-from-civil algorithm, so
   there is no dependency on the host's `Date`/`Time` structures at runtime. *)

signature DATETIME =
sig
  type date = { year : int, month : int, day : int }   (* month 1-12 *)
  exception Invalid of string

  val isLeapYear  : int -> bool
  val daysInMonth : int * int -> int        (* (year, month) -> days; raises Invalid on bad month *)
  val isValid     : date -> bool

  (* Days since 1970-01-01 (epoch day 0). Inverse: fromEpochDay. *)
  val toEpochDay   : date -> int             (* raises Invalid on an invalid date *)
  val fromEpochDay : int -> date

  val addDays  : date -> int -> date         (* may be negative *)
  val diffDays : date * date -> int          (* a - b in days *)

  val dayOfWeek : date -> int                (* 0 = Sunday .. 6 = Saturday *)

  val parseISO  : string -> date option      (* strict YYYY-MM-DD; year bounded
                                                to signed 32-bit, else NONE *)
  val formatISO : date -> string             (* zero-padded YYYY-MM-DD *)

  (* ---- Time of day -------------------------------------------------------
     A wall-clock time with nanosecond resolution. Like `date`, a `time` is a
     plain record: hour 0-23, minute 0-59, second 0-59 (no leap seconds), and
     nano 0-999999999. Sub-day totals (nanoOfDay) and instant/duration values
     use LargeInt.int so they stay exact even where the default int is 32-bit
     (e.g. MLton); the small record fields remain plain int. *)
  type time = { hour : int, minute : int, second : int, nano : int }

  val midnight    : time                      (* 00:00:00.000000000 *)
  val isValidTime : time -> bool

  val secondOfDay : time -> int               (* whole seconds since midnight; raises Invalid if invalid *)
  val nanoOfDay   : time -> LargeInt.int      (* nanoseconds since midnight; raises Invalid if invalid *)
  val timeFromNanoOfDay : LargeInt.int -> time  (* inverse of nanoOfDay; 0 <= n < 86400 * 1e9 *)

  (* ---- Datetime / instant (UTC) ------------------------------------------
     A `datetime` pairs a civil `date` with a wall-clock `time`, interpreted as
     an instant in UTC. There is no timezone database; ISO offsets are folded
     into UTC at parse time (see parseDateTimeISO). *)
  type datetime = { date : date, time : time }

  val isValidDateTime : datetime -> bool

  (* Seconds since 1970-01-01T00:00:00Z. toEpochSecond drops sub-second
     precision; fromEpochSecond yields nano = 0. *)
  val toEpochSecond   : datetime -> LargeInt.int  (* raises Invalid on an invalid datetime *)
  val fromEpochSecond : LargeInt.int -> datetime

  (* ---- Durations ---------------------------------------------------------
     A signed elapsed time, normalized so that 0 <= nanos < 1e9 (the seconds
     field carries the sign). E.g. -0.5s is { seconds = ~1, nanos = 500000000 }. *)
  type duration = { seconds : LargeInt.int, nanos : int }

  val durationFromSeconds : LargeInt.int -> duration
  val durationToSeconds   : duration -> LargeInt.int  (* whole seconds, floored toward negative infinity *)
  val normalizeDuration   : LargeInt.int * LargeInt.int -> duration  (* (seconds, nanos), any nanos -> normalized *)

  val negateDuration : duration -> duration
  val addDurations   : duration * duration -> duration
  val subDurations   : duration * duration -> duration  (* a - b *)
  val scaleDuration  : duration * int -> duration

  val addDuration : datetime * duration -> datetime
  val subDuration : datetime * duration -> datetime
  val diff        : datetime * datetime -> duration     (* a - b *)

  (* ---- ISO 8601 datetime -------------------------------------------------
     parseDateTimeISO accepts YYYY-MM-DDThh:mm:ss[.fff][Z|+hh:mm|-hh:mm].
     A trailing offset is subtracted to normalize the instant to UTC; a missing
     offset is treated as UTC. Fractional seconds may have 1-9 digits.
     formatDateTimeISO always emits UTC with a trailing 'Z', printing a
     fractional part only when nano <> 0 (trailing zeros trimmed). *)
  val parseDateTimeISO  : string -> datetime option
  val formatDateTimeISO : datetime -> string
end
