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

  val parseISO  : string -> date option      (* strict YYYY-MM-DD *)
  val formatISO : date -> string             (* zero-padded YYYY-MM-DD *)
end
