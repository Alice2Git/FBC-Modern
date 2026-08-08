'' fb/chrono.bi -- a modern date/time library
''
''     #include once "fb/chrono.bi"
''
'' Specified by C:\dev\docs\datetime\RFC-0001-core-representation.md (core types) and
'' RFC-0002-timespan.md (durations).  This header is phase 2: the types, their
'' component accessors, exact arithmetic and operators.  Formatting and parsing
'' (RFC-0005/0006), calendar arithmetic (RFC-0004), clocks (RFC-0003) and zones
'' (RFC-0007) arrive in later phases.
''
'' This is a SEPARATE surface from datetime.bi.  Nothing here touches, replaces
'' or depends on DateSerial / DateAdd / Now / FORMAT, which keep working exactly
'' as they always have.  RFC-0007 will add converters so a program can migrate
'' one function at a time.
''
'' THE TICK.  Everything measures in ticks of 100 ns.  A DateTime is a count of
'' ticks since 0001-01-01T00:00:00 in the proleptic Gregorian calendar; the
'' range is year 1 to 9999.  A single LONGINT, so these types pass in a register
'' and copy trivially.
''
'' IMMUTABLE.  AddDays returns a NEW value; it does not modify the receiver.
''
''     dt = dt.AddDays( 3 )                      '' do
''     dt.AddDays( 3 )                           '' does nothing -- result dropped
''
'' This is what java.time, NodaTime, Temporal, Rust and Go all converged on, and
'' it is what makes it safe to pass one of these BYREF.
''
'' INVALID.  There is no exception and no ERR( ).  Out-of-range construction and
'' overflowing arithmetic both yield an Invalid value, which is absorbing --
'' anything touching it becomes Invalid.  Arithmetic NEVER wraps.
''
''     dim as FB.DateTime d = FB.DateTime( 2025, 2, 30 )   '' no such date
''     if d.IsValid then ...
''
'' BEWARE: comparing an Invalid value with ANYTHING is false, including
'' comparing it with itself.  Invalid = Invalid is FALSE, deliberately, for the
'' same reason IEEE NaN works that way -- an equality that succeeded would let
'' invalid values slip silently through validation.  IsValid is the only correct
'' test, and CompareTo returns -2 rather than an ordering.

#pragma once

'' ---------------------------------------------------------------- constants

const DT_TICKS_PER_MICROSECOND as longint = 10ll
const DT_TICKS_PER_MILLISECOND as longint = 10000ll
const DT_TICKS_PER_SECOND      as longint = 10000000ll
const DT_TICKS_PER_MINUTE      as longint = 600000000ll
const DT_TICKS_PER_HOUR        as longint = 36000000000ll
const DT_TICKS_PER_DAY         as longint = 864000000000ll

const DT_MIN_YEAR              as long    = 1
const DT_MAX_YEAR              as long    = 9999
const DT_MIN_DAYS              as long    = 0
const DT_MAX_DAYS              as long    = 3652058

const DT_MIN_TICKS             as longint = 0ll
const DT_MAX_TICKS             as longint = 3155378975999999999ll

'' The sentinel is LLONG_MIN, so it lies outside every valid range and a wrapped
'' result can never collide with it.  It therefore also costs TimeSpan one value
'' at the bottom of its range: TimeSpan.MinValue is LLONG_MIN + 1.
const DT_INVALID_TICKS         as longint = -9223372036854775807ll - 1ll
const DT_INVALID_DAYS          as long    = -2147483647 - 1

const DT_TICKS_LLONG_MAX       as longint = 9223372036854775807ll
const DT_TICKS_LLONG_MIN       as longint = -9223372036854775807ll

'' Interop epochs, as tick counts measured from 0001-01-01, so each conversion
'' is an addition.  This is why the epoch and tick size were chosen at all --
'' see C:\dev\docs\datetime\rationale.md.  The converters themselves are RFC-0007.
'' Julian day number of 0001-01-01.  JD 2451545.0 is 2000-01-01T12:00 UTC.
const DT_JULIAN_DAY_AT_EPOCH   as longint = 1721426ll

const DT_DAYS_TO_UNIX_EPOCH    as longint = 719162ll
const DT_TICKS_TO_UNIX_EPOCH   as longint = 621355968000000000ll   '' 1970-01-01
const DT_TICKS_TO_FILETIME     as longint = 504911232000000000ll   '' 1601-01-01
const DT_TICKS_TO_OLE_EPOCH    as longint = 599264352000000000ll   '' 1899-12-30

'' Offset states.  0 means UTC.  DT_OFFSET_UNSPECIFIED means "the caller never
'' said", which is a DISTINCT state from UTC -- conflating the two is the
'' DateTimeKind.Unspecified mistake that C# is stuck with.  Anything else is a
'' fixed offset in minutes east of UTC.
const DT_OFFSET_UNSPECIFIED    as short   = 32767
const DT_OFFSET_MIN            as short   = -1080   '' -18:00, the ISO 8601 limit
const DT_OFFSET_MAX            as short   =  1080   '' +18:00

'' Locale formatting styles (RFC-0007 section 3).
const lsShort as long = 0
const lsLong  as long = 1
const lsFull  as long = 2

'' ISO 8601 day of week.  NOTE this is 1 = Monday, which differs from
'' datetime.bi's Weekday( ) (1 = Sunday) on purpose: the ISO week-number
'' algorithm needs it, and two neighbouring conventions is one too many.
const DT_MONDAY    as long = 1
const DT_TUESDAY   as long = 2
const DT_WEDNESDAY as long = 3
const DT_THURSDAY  as long = 4
const DT_FRIDAY    as long = 5
const DT_SATURDAY  as long = 6
const DT_SUNDAY    as long = 7

'' ------------------------------------------------------------- the C kernel
''
'' C:\dev\docs\datetime\RFC-0001 section 5.  Pure functions in src/rtlib/dt_core.c:
'' no OS calls, no allocation, no locale.  Declared here rather than in a
'' separate header so the whole library is one #include.

declare function fb_DtFromCivil       alias "fb_DtFromCivil" _
          ( byval year as long, byval month as long, byval day as long, _
            byval hour as long, byval minute as long, byval second as long, _
            byval subsecond_ticks as longint, byval out_ticks as longint ptr ) as long

declare sub      fb_DtToCivil         alias "fb_DtToCivil" _
          ( byval ticks as longint, _
            byval year as long ptr, byval month as long ptr, byval day as long ptr, _
            byval hour as long ptr, byval minute as long ptr, byval second as long ptr, _
            byval subsecond_ticks as longint ptr )

declare function fb_DtDaysFromCivil   alias "fb_DtDaysFromCivil" _
          ( byval year as long, byval month as long, byval day as long ) as long
declare sub      fb_DtCivilFromDays   alias "fb_DtCivilFromDays" _
          ( byval days as long, _
            byval year as long ptr, byval month as long ptr, byval day as long ptr )

declare function fb_DtIsLeapYear      alias "fb_DtIsLeapYear"    ( byval year as long ) as long
declare function fb_DtDaysInMonth     alias "fb_DtDaysInMonth"   ( byval year as long, byval month as long ) as long
declare function fb_DtDaysInYear      alias "fb_DtDaysInYear"    ( byval year as long ) as long
declare function fb_DtDayOfWeek       alias "fb_DtDayOfWeek"     ( byval days as long ) as long
declare function fb_DtDayOfYear       alias "fb_DtDayOfYear"     ( byval year as long, byval month as long, byval day as long ) as long
declare function fb_DtIsoWeek         alias "fb_DtIsoWeek"       ( byval year as long, byval month as long, byval day as long, byval out_iso_year as long ptr ) as long
declare function fb_DtIsoWeeksInYear  alias "fb_DtIsoWeeksInYear"( byval year as long ) as long
declare function fb_DtIsValidDate     alias "fb_DtIsValidDate"   ( byval year as long, byval month as long, byval day as long ) as long
declare function fb_DtIsValidTime     alias "fb_DtIsValidTime"   ( byval hour as long, byval minute as long, byval second as long, byval subsecond_ticks as longint ) as long
declare function fb_DtIsValidTicks    alias "fb_DtIsValidTicks"  ( byval ticks as longint ) as long

'' Clocks (RFC-0003).  The only part of the library that touches the OS.
declare function fb_DtClockUtcNow         alias "fb_DtClockUtcNow"        ( ) as longint
declare function fb_DtClockResolution     alias "fb_DtClockResolution"    ( ) as longint
declare function fb_DtClockLocalOffsetNow alias "fb_DtClockLocalOffsetNow"( ) as long
declare function fb_DtMonoTimestamp       alias "fb_DtMonoTimestamp"      ( ) as longint
declare function fb_DtMonoFrequency       alias "fb_DtMonoFrequency"      ( ) as longint
declare function fb_DtMonoIsHighRes       alias "fb_DtMonoIsHighRes"      ( ) as long
declare function fb_DtTicksFromCounts     alias "fb_DtTicksFromCounts"    ( byval counts as longint, byval freq as longint ) as longint
declare function fb_DtCpuProcessTime      alias "fb_DtCpuProcessTime"     ( byval user as longint ptr, byval kernel as longint ptr ) as long
declare function fb_DtCpuThreadTime       alias "fb_DtCpuThreadTime"      ( byval user as longint ptr, byval kernel as longint ptr ) as long
declare function fb_DtCpuIsSupported      alias "fb_DtCpuIsSupported"     ( ) as long

'' ISO 8601 / RFC 3339 (RFC-0005).  Pure, ASCII-only, locale-independent.
declare function fb_DtIsoFormat         alias "fb_DtIsoFormat"        ( byval ticks as longint, byval offMin as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtIsoFormatDate     alias "fb_DtIsoFormatDate"    ( byval days as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtIsoFormatTime     alias "fb_DtIsoFormatTime"    ( byval tod as longint, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtIsoFormatDuration alias "fb_DtIsoFormatDuration"( byval ticks as longint, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtIsoParse          alias "fb_DtIsoParse"         ( byval s as const zstring ptr, byval slen as long, byval outTicks as longint ptr, byval outOff as long ptr ) as long
declare function fb_DtIsoParseDate      alias "fb_DtIsoParseDate"     ( byval s as const zstring ptr, byval slen as long, byval outDays as long ptr ) as long
declare function fb_DtIsoParseTime      alias "fb_DtIsoParseTime"     ( byval s as const zstring ptr, byval slen as long, byval outTod as longint ptr ) as long
declare function fb_DtIsoParseDuration  alias "fb_DtIsoParseDuration" ( byval s as const zstring ptr, byval slen as long, byval outTicks as longint ptr ) as long

'' Custom patterns (RFC-0006).  Invariant English, no locale.
declare function fb_DtPatFormat alias "fb_DtPatFormat" ( byval ticks as longint, byval offMin as long, byval pat as const zstring ptr, byval patlen as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtPatParse  alias "fb_DtPatParse"  ( byval s as const zstring ptr, byval slen as long, byval pat as const zstring ptr, byval patlen as long, byval outTicks as longint ptr, byval outOff as long ptr ) as long

'' Zones and locale (RFC-0007).  Per-OS: win32/dt_zone.c, unix/dt_zone.c.
declare function fb_DtZoneOffsetAt      alias "fb_DtZoneOffsetAt"     ( byval utcTicks as longint ) as long
declare function fb_DtZoneIsDst         alias "fb_DtZoneIsDst"        ( byval utcTicks as longint ) as long
declare function fb_DtZoneSupportsDst   alias "fb_DtZoneSupportsDst"  ( ) as long
declare function fb_DtZoneStandardName  alias "fb_DtZoneStandardName" ( byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtZoneDaylightName  alias "fb_DtZoneDaylightName" ( byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtLocaleDateString  alias "fb_DtLocaleDateString" ( byval ticks as longint, byval style as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtLocaleTimeString  alias "fb_DtLocaleTimeString" ( byval ticks as longint, byval style as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtLocaleMonthName   alias "fb_DtLocaleMonthName"  ( byval mo as long, byval abbreviated as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtLocaleWeekdayName alias "fb_DtLocaleWeekdayName"( byval dow as long, byval abbreviated as long, byval buf as zstring ptr, byval buflen as long ) as long
declare function fb_DtLocaleIsSupported alias "fb_DtLocaleIsSupported"( ) as long

namespace FB

'' ------------------------------------------------------------------ helpers
''
'' TYPE ORDER IS LOAD-BEARING.  FreeBASIC cannot forward-declare a UDT well
'' enough to return one BY VALUE, so a type may only return types defined
'' ABOVE it.  Hence: TimeSpan, LocalDate, LocalTime, Instant, DateTime.
'' That is also why the Instant -> DateTime conversion is spelled
'' DateTime.FromInstant rather than Instant.ToUtc; the reverse direction,
'' DateTime.ToInstant, is a member because Instant is already complete by then.

'' A quiet NaN, for the one operation (TimeSpan.DivideBy zero) whose specified
'' result is NaN.  Built from the bit pattern so no arithmetic trap is risked.
private function dtNaN( ) as double
	dim as ulongint u = &hFFF8000000000000ull
	return *cptr( double ptr, @u )
end function

'' True when a + b would overflow a signed 64-bit integer.  Checked BEFORE the
'' addition, never by inspecting the result for a sign flip.
private function dtAddOverflows( byval a as longint, byval b as longint ) as boolean
	if b > 0 then
		return a > DT_TICKS_LLONG_MAX - b
	elseif b < 0 then
		return a < DT_TICKS_LLONG_MIN - b
	end if
	return false
end function

'' Round half away from zero, matching the RFC-0002 rule for the From* family.
private function dtRoundHalfAway( byval v as double ) as double
	if v >= 0 then
		return int( v + 0.5 )
	end if
	return -int( -v + 0.5 )
end function

'' Convert a double tick count to a longint, or the sentinel if it is NaN,
'' infinite, or beyond the representable span.  The bound is deliberately a
'' little conservative -- 9.2e18 ticks is 29,000 years, so nothing real is lost.
private function dtTicksFromDouble( byval v as double ) as longint
	'' NaN is the only value not equal to itself
	if v <> v then return DT_INVALID_TICKS
	dim as boolean tooBig = ( v >= 9.2e18 )
	dim as boolean tooSmall = ( v <= -9.2e18 )
	if tooBig orelse tooSmall then return DT_INVALID_TICKS
	return clngint( dtRoundHalfAway( v ) )
end function

'' ================================================================= TimeSpan
''
'' RFC-0002.  A FIXED duration -- an exact count of ticks.  Signed, so
'' 'earlier - later' is meaningful rather than an error.
''
'' This is NOT a calendar period.  "One month" is not a TimeSpan, because a
'' month has no fixed length; that is AddMonths, in RFC-0004.  There is
'' deliberately no FromMonths.
''
'' TOTALS vs COMPONENTS.  Total* gives the whole span in that unit,
'' fractionally.  The component properties give the broken-down pieces.  For a
'' span of 1 day 2 hours 3 minutes: TotalHours is 26.05, Hours is 2.
''
'' Components of a NEGATIVE span are ALL negative, matching C#.  -1h30m has
'' Hours = -1 and Minutes = -30, not -1 and +30, so that the pieces always
'' reconstruct the whole.
type TimeSpan
	m_ticks as longint

	declare constructor( )
	declare constructor( byval t as longint )
	declare constructor( byval h as long, byval mi as long, byval s as long )
	declare constructor( byval d as long, byval h as long, byval mi as long, _
	                     byval s as long, byval ms as long )

	declare static function FromDays        ( byval v as double  ) as TimeSpan
	declare static function FromHours       ( byval v as double  ) as TimeSpan
	declare static function FromMinutes     ( byval v as double  ) as TimeSpan
	declare static function FromSeconds     ( byval v as double  ) as TimeSpan
	declare static function FromMilliseconds( byval v as double  ) as TimeSpan
	declare static function FromMicroseconds( byval v as longint ) as TimeSpan
	declare static function FromTicks       ( byval v as longint ) as TimeSpan

	declare static function Zero    ( ) as TimeSpan
	declare static function MinValue( ) as TimeSpan
	declare static function MaxValue( ) as TimeSpan
	declare static function Invalid ( ) as TimeSpan

	declare property Ticks( ) as longint

	declare property TotalDays        ( ) as double
	declare property TotalHours       ( ) as double
	declare property TotalMinutes     ( ) as double
	declare property TotalSeconds     ( ) as double
	declare property TotalMilliseconds( ) as double
	declare property TotalMicroseconds( ) as longint

	declare property Days        ( ) as long
	declare property Hours       ( ) as long
	declare property Minutes     ( ) as long
	declare property Seconds     ( ) as long
	declare property Milliseconds( ) as long
	declare property Microseconds( ) as long

	declare property IsValid   ( ) as boolean
	declare property IsZero    ( ) as boolean
	declare property IsNegative( ) as boolean

	declare function Negate   ( ) as TimeSpan
	declare function Duration ( ) as TimeSpan
	declare function Add      ( byref o as TimeSpan ) as TimeSpan
	declare function Subtract ( byref o as TimeSpan ) as TimeSpan
	declare function Multiply ( byval f as double   ) as TimeSpan
	declare function Divide   ( byval f as double   ) as TimeSpan
	declare function DivideBy ( byref o as TimeSpan ) as double
	declare function CompareTo( byref o as TimeSpan ) as long

	declare function ToIsoString( ) as string
	declare function ToString   ( ) as string
	declare static function TryParseIso( byref s as string, byref result as TimeSpan ) as boolean
	declare static function ParseIso   ( byref s as string ) as TimeSpan

	declare function ToIsoUString( ) as ustring
	declare static function TryParseIso overload ( byref s as ustring, byref result as TimeSpan ) as boolean
	declare static function ParseIso    overload ( byref s as ustring ) as TimeSpan
end type

declare operator + ( byref a as TimeSpan, byref b as TimeSpan ) as TimeSpan
declare operator - ( byref a as TimeSpan, byref b as TimeSpan ) as TimeSpan
declare operator - ( byref a as TimeSpan ) as TimeSpan
declare operator * ( byref a as TimeSpan, byval f as double ) as TimeSpan
declare operator * ( byval f as double, byref a as TimeSpan ) as TimeSpan
declare operator / ( byref a as TimeSpan, byval f as double ) as TimeSpan
declare operator =  ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
declare operator <> ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
declare operator <  ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
declare operator >  ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
declare operator <= ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
declare operator >= ( byref a as TimeSpan, byref b as TimeSpan ) as boolean

private constructor TimeSpan( )
	this.m_ticks = 0
end constructor

private constructor TimeSpan( byval t as longint )
	this.m_ticks = t
end constructor

private constructor TimeSpan( byval h as long, byval mi as long, byval s as long )
	this.m_ticks = clngint( h ) * DT_TICKS_PER_HOUR _
	             + clngint( mi ) * DT_TICKS_PER_MINUTE _
	             + clngint( s ) * DT_TICKS_PER_SECOND
end constructor

private constructor TimeSpan( byval d as long, byval h as long, byval mi as long, _
                              byval s as long, byval ms as long )
	this.m_ticks = clngint( d ) * DT_TICKS_PER_DAY _
	             + clngint( h ) * DT_TICKS_PER_HOUR _
	             + clngint( mi ) * DT_TICKS_PER_MINUTE _
	             + clngint( s ) * DT_TICKS_PER_SECOND _
	             + clngint( ms ) * DT_TICKS_PER_MILLISECOND
end constructor

private function TimeSpan.FromDays( byval v as double ) as TimeSpan
	return TimeSpan( dtTicksFromDouble( v * DT_TICKS_PER_DAY ) )
end function
private function TimeSpan.FromHours( byval v as double ) as TimeSpan
	return TimeSpan( dtTicksFromDouble( v * DT_TICKS_PER_HOUR ) )
end function
private function TimeSpan.FromMinutes( byval v as double ) as TimeSpan
	return TimeSpan( dtTicksFromDouble( v * DT_TICKS_PER_MINUTE ) )
end function
private function TimeSpan.FromSeconds( byval v as double ) as TimeSpan
	return TimeSpan( dtTicksFromDouble( v * DT_TICKS_PER_SECOND ) )
end function
private function TimeSpan.FromMilliseconds( byval v as double ) as TimeSpan
	return TimeSpan( dtTicksFromDouble( v * DT_TICKS_PER_MILLISECOND ) )
end function
private function TimeSpan.FromMicroseconds( byval v as longint ) as TimeSpan
	'' longint, not double: at this magnitude a double has already lost bits
	if v > DT_TICKS_LLONG_MAX \ DT_TICKS_PER_MICROSECOND then return TimeSpan( DT_INVALID_TICKS )
	if v < DT_TICKS_LLONG_MIN \ DT_TICKS_PER_MICROSECOND then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( v * DT_TICKS_PER_MICROSECOND )
end function
private function TimeSpan.FromTicks( byval v as longint ) as TimeSpan
	return TimeSpan( v )
end function

private function TimeSpan.Zero( ) as TimeSpan
	return TimeSpan( 0ll )
end function
private function TimeSpan.MinValue( ) as TimeSpan
	return TimeSpan( DT_TICKS_LLONG_MIN )
end function
private function TimeSpan.MaxValue( ) as TimeSpan
	return TimeSpan( DT_TICKS_LLONG_MAX )
end function
private function TimeSpan.Invalid( ) as TimeSpan
	return TimeSpan( DT_INVALID_TICKS )
end function

private property TimeSpan.Ticks( ) as longint
	return this.m_ticks
end property

private property TimeSpan.IsValid( ) as boolean
	return this.m_ticks <> DT_INVALID_TICKS
end property
private property TimeSpan.IsZero( ) as boolean
	return this.m_ticks = 0
end property
private property TimeSpan.IsNegative( ) as boolean
	dim as boolean valid = ( this.m_ticks <> DT_INVALID_TICKS )
	dim as boolean neg = ( this.m_ticks < 0 )
	return valid andalso neg
end property

private property TimeSpan.TotalDays( ) as double
	return this.m_ticks / DT_TICKS_PER_DAY
end property
private property TimeSpan.TotalHours( ) as double
	return this.m_ticks / DT_TICKS_PER_HOUR
end property
private property TimeSpan.TotalMinutes( ) as double
	return this.m_ticks / DT_TICKS_PER_MINUTE
end property
private property TimeSpan.TotalSeconds( ) as double
	return this.m_ticks / DT_TICKS_PER_SECOND
end property
private property TimeSpan.TotalMilliseconds( ) as double
	return this.m_ticks / DT_TICKS_PER_MILLISECOND
end property
private property TimeSpan.TotalMicroseconds( ) as longint
	return this.m_ticks \ DT_TICKS_PER_MICROSECOND
end property

'' Components. FreeBASIC's \ truncates toward zero and MOD takes the sign of the
'' dividend, which is exactly the all-negative-for-a-negative-span rule.
private property TimeSpan.Days( ) as long
	return clng( this.m_ticks \ DT_TICKS_PER_DAY )
end property
private property TimeSpan.Hours( ) as long
	return clng( ( this.m_ticks \ DT_TICKS_PER_HOUR ) mod 24 )
end property
private property TimeSpan.Minutes( ) as long
	return clng( ( this.m_ticks \ DT_TICKS_PER_MINUTE ) mod 60 )
end property
private property TimeSpan.Seconds( ) as long
	return clng( ( this.m_ticks \ DT_TICKS_PER_SECOND ) mod 60 )
end property
private property TimeSpan.Milliseconds( ) as long
	return clng( ( this.m_ticks \ DT_TICKS_PER_MILLISECOND ) mod 1000 )
end property
private property TimeSpan.Microseconds( ) as long
	return clng( ( this.m_ticks \ DT_TICKS_PER_MICROSECOND ) mod 1000000 )
end property

private function TimeSpan.Negate( ) as TimeSpan
	if this.m_ticks = DT_INVALID_TICKS then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( -this.m_ticks )
end function

private function TimeSpan.Duration( ) as TimeSpan
	if this.m_ticks = DT_INVALID_TICKS then return TimeSpan( DT_INVALID_TICKS )
	if this.m_ticks < 0 then return TimeSpan( -this.m_ticks )
	return TimeSpan( this.m_ticks )
end function

private function TimeSpan.Add( byref o as TimeSpan ) as TimeSpan
	dim as boolean bad = ( this.m_ticks = DT_INVALID_TICKS )
	dim as boolean badO = ( o.m_ticks = DT_INVALID_TICKS )
	if bad orelse badO then return TimeSpan( DT_INVALID_TICKS )
	if dtAddOverflows( this.m_ticks, o.m_ticks ) then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( this.m_ticks + o.m_ticks )
end function

private function TimeSpan.Subtract( byref o as TimeSpan ) as TimeSpan
	dim as boolean bad = ( this.m_ticks = DT_INVALID_TICKS )
	dim as boolean badO = ( o.m_ticks = DT_INVALID_TICKS )
	if bad orelse badO then return TimeSpan( DT_INVALID_TICKS )
	'' -o.m_ticks is safe: MinValue is LLONG_MIN + 1, so it negates cleanly
	if dtAddOverflows( this.m_ticks, -o.m_ticks ) then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( this.m_ticks - o.m_ticks )
end function

private function TimeSpan.Multiply( byval f as double ) as TimeSpan
	if this.m_ticks = DT_INVALID_TICKS then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( dtTicksFromDouble( this.m_ticks * f ) )
end function

private function TimeSpan.Divide( byval f as double ) as TimeSpan
	if this.m_ticks = DT_INVALID_TICKS then return TimeSpan( DT_INVALID_TICKS )
	if f = 0 then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( dtTicksFromDouble( this.m_ticks / f ) )
end function

private function TimeSpan.DivideBy( byref o as TimeSpan ) as double
	dim as boolean bad = ( this.m_ticks = DT_INVALID_TICKS )
	dim as boolean badO = ( o.m_ticks = DT_INVALID_TICKS )
	if bad orelse badO then return dtNaN( )
	if o.m_ticks = 0 then return dtNaN( )
	return this.m_ticks / o.m_ticks
end function

'' -2 means "not comparable" -- at least one operand is Invalid.  It is not an
'' ordering, and it is deliberately not 0.
private function TimeSpan.CompareTo( byref o as TimeSpan ) as long
	dim as boolean bad = ( this.m_ticks = DT_INVALID_TICKS )
	dim as boolean badO = ( o.m_ticks = DT_INVALID_TICKS )
	if bad orelse badO then return -2
	if this.m_ticks < o.m_ticks then return -1
	if this.m_ticks > o.m_ticks then return 1
	return 0
end function

private operator + ( byref a as TimeSpan, byref b as TimeSpan ) as TimeSpan
	return a.Add( b )
end operator
private operator - ( byref a as TimeSpan, byref b as TimeSpan ) as TimeSpan
	return a.Subtract( b )
end operator
private operator - ( byref a as TimeSpan ) as TimeSpan
	return a.Negate( )
end operator
private operator * ( byref a as TimeSpan, byval f as double ) as TimeSpan
	return a.Multiply( f )
end operator
private operator * ( byval f as double, byref a as TimeSpan ) as TimeSpan
	return a.Multiply( f )
end operator
private operator / ( byref a as TimeSpan, byval f as double ) as TimeSpan
	return a.Divide( f )
end operator
private operator = ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
	return a.CompareTo( b ) = 0
end operator
private operator <> ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean cmp = ( c <> 0 )
	dim as boolean known = ( c <> -2 )
	return cmp andalso known
end operator
private operator < ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
	return a.CompareTo( b ) = -1
end operator
private operator > ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
	return a.CompareTo( b ) = 1
end operator
private operator <= ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean le = ( c <= 0 )
	dim as boolean known = ( c <> -2 )
	return le andalso known
end operator
private operator >= ( byref a as TimeSpan, byref b as TimeSpan ) as boolean
	return a.CompareTo( b ) >= 0
end operator

'' ================================================================ LocalDate
''
'' A date with no time and no offset.  A separate type so that "2025-03-04" and
'' "14:30" cannot be compared, subtracted or passed to each other's functions --
'' and so that a date-shaped value cannot carry a hidden midnight-vs-noon.
type LocalDate
	m_days as long

	declare constructor( )
	declare constructor( byval y as long, byval mo as long, byval d as long )

	declare static function FromDayNumber( byval days as long ) as LocalDate
	declare static function MinValue( ) as LocalDate
	declare static function MaxValue( ) as LocalDate
	declare static function Invalid ( ) as LocalDate

	declare property IsValid  ( ) as boolean
	declare property DayNumber( ) as long
	declare property Year     ( ) as long
	declare property Month    ( ) as long
	declare property Day      ( ) as long
	declare property DayOfWeek( ) as long
	declare property DayOfYear( ) as long

	declare property IsoWeek    ( ) as long
	declare property IsoWeekYear( ) as long
	declare property Quarter    ( ) as long
	declare property IsFirstDayOfMonth( ) as boolean
	declare property IsLastDayOfMonth ( ) as boolean

	declare function AddDays  ( byval n as long ) as LocalDate
	declare function AddMonths( byval n as long ) as LocalDate
	declare function AddYears ( byval n as long ) as LocalDate
	declare function StartOfMonth( ) as LocalDate
	declare function EndOfMonth  ( ) as LocalDate
	declare function CompareTo( byref o as LocalDate ) as long

	declare function ToIsoString( ) as string
	declare function ToString   ( ) as string
	declare static function TryParseIso( byref s as string, byref result as LocalDate ) as boolean
	declare static function ParseIso   ( byref s as string ) as LocalDate

	declare function ToIsoUString( ) as ustring
	declare static function TryParseIso overload ( byref s as ustring, byref result as LocalDate ) as boolean
	declare static function ParseIso    overload ( byref s as ustring ) as LocalDate
end type

declare operator - ( byref a as LocalDate, byref b as LocalDate ) as long
declare operator =  ( byref a as LocalDate, byref b as LocalDate ) as boolean
declare operator <> ( byref a as LocalDate, byref b as LocalDate ) as boolean
declare operator <  ( byref a as LocalDate, byref b as LocalDate ) as boolean
declare operator >  ( byref a as LocalDate, byref b as LocalDate ) as boolean
declare operator <= ( byref a as LocalDate, byref b as LocalDate ) as boolean
declare operator >= ( byref a as LocalDate, byref b as LocalDate ) as boolean

private constructor LocalDate( )
	this.m_days = DT_INVALID_DAYS
end constructor

private constructor LocalDate( byval y as long, byval mo as long, byval d as long )
	if fb_DtIsValidDate( y, mo, d ) = 0 then
		this.m_days = DT_INVALID_DAYS
	else
		this.m_days = fb_DtDaysFromCivil( y, mo, d )
	end if
end constructor

private function LocalDate.FromDayNumber( byval days as long ) as LocalDate
	dim as LocalDate r
	dim as boolean lo = ( days < DT_MIN_DAYS )
	dim as boolean hi = ( days > DT_MAX_DAYS )
	if lo orelse hi then
		r.m_days = DT_INVALID_DAYS
	else
		r.m_days = days
	end if
	return r
end function

private function LocalDate.MinValue( ) as LocalDate
	return LocalDate.FromDayNumber( DT_MIN_DAYS )
end function
private function LocalDate.MaxValue( ) as LocalDate
	return LocalDate.FromDayNumber( DT_MAX_DAYS )
end function
private function LocalDate.Invalid( ) as LocalDate
	dim as LocalDate r
	r.m_days = DT_INVALID_DAYS
	return r
end function

private property LocalDate.IsValid( ) as boolean
	return this.m_days <> DT_INVALID_DAYS
end property
private property LocalDate.DayNumber( ) as long
	return this.m_days
end property
private property LocalDate.Year( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )
	return y
end property
private property LocalDate.Month( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )
	return mo
end property
private property LocalDate.Day( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )
	return d
end property
private property LocalDate.DayOfWeek( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	return fb_DtDayOfWeek( this.m_days )
end property
private property LocalDate.DayOfYear( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )
	return fb_DtDayOfYear( y, mo, d )
end property

private function LocalDate.AddDays( byval n as long ) as LocalDate
	if this.m_days = DT_INVALID_DAYS then return LocalDate.Invalid( )
	'' widen so the range test happens before any 32-bit wrap
	dim as longint r = clngint( this.m_days ) + clngint( n )
	dim as boolean lo = ( r < DT_MIN_DAYS )
	dim as boolean hi = ( r > DT_MAX_DAYS )
	if lo orelse hi then return LocalDate.Invalid( )
	return LocalDate.FromDayNumber( clng( r ) )
end function

private property LocalDate.IsoWeek( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )
	return fb_DtIsoWeek( y, mo, d, 0 )
end property
private property LocalDate.IsoWeekYear( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	dim as long y, mo, d, iy
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )
	fb_DtIsoWeek( y, mo, d, @iy )
	return iy
end property
private property LocalDate.Quarter( ) as long
	if this.m_days = DT_INVALID_DAYS then return 0
	return ( ( this.Month - 1 ) \ 3 ) + 1
end property
private property LocalDate.IsFirstDayOfMonth( ) as boolean
	if this.m_days = DT_INVALID_DAYS then return false
	return this.Day = 1
end property
private property LocalDate.IsLastDayOfMonth( ) as boolean
	if this.m_days = DT_INVALID_DAYS then return false
	return this.Day = fb_DtDaysInMonth( this.Year, this.Month )
end property

'' RFC-0004 section 2, the end-of-month rule.  Add n to the month field, then
'' CLAMP the day to the last day of the target month if it does not exist there.
''
''     2025-01-31 AddMonths( 1 )  ->  2025-02-28
''     2024-01-31 AddMonths( 1 )  ->  2024-02-29
''
'' Clamping makes this LOSSY and not reversible: +1mo then -1mo on 31 Jan gives
'' the 28th, not the 31st.  Every language that implements calendar months does
'' exactly this; the alternative (overflowing into 3 March) is what nobody chose.
'' AddMonths( n ) is ONE operation on the original day-of-month, never n
'' repetitions -- +2 and +1+1 differ for 31 December.
private function LocalDate.AddMonths( byval n as long ) as LocalDate
	if this.m_days = DT_INVALID_DAYS then return LocalDate.Invalid( )

	dim as long y, mo, d
	fb_DtCivilFromDays( this.m_days, @y, @mo, @d )

	'' floor division, because FreeBASIC's \ truncates toward zero
	dim as longint total = clngint( y ) * 12ll + clngint( mo - 1 ) + clngint( n )
	dim as longint ny = total \ 12ll
	dim as longint rm = total mod 12ll
	if rm < 0 then
		rm += 12
		ny -= 1
	end if

	dim as boolean lo = ( ny < DT_MIN_YEAR )
	dim as boolean hi = ( ny > DT_MAX_YEAR )
	if lo orelse hi then return LocalDate.Invalid( )

	dim as long nm = clng( rm ) + 1
	dim as long last = fb_DtDaysInMonth( clng( ny ), nm )
	if d > last then d = last                          '' the clamp

	return LocalDate.FromDayNumber( fb_DtDaysFromCivil( clng( ny ), nm, d ) )
end function

'' Exactly AddMonths( n * 12 ), so the clamping lives in one place.
private function LocalDate.AddYears( byval n as long ) as LocalDate
	if n > 178956970 then return LocalDate.Invalid( )
	if n < -178956970 then return LocalDate.Invalid( )
	return this.AddMonths( n * 12 )
end function

private function LocalDate.StartOfMonth( ) as LocalDate
	if this.m_days = DT_INVALID_DAYS then return LocalDate.Invalid( )
	return LocalDate( this.Year, this.Month, 1 )
end function
private function LocalDate.EndOfMonth( ) as LocalDate
	if this.m_days = DT_INVALID_DAYS then return LocalDate.Invalid( )
	return LocalDate( this.Year, this.Month, fb_DtDaysInMonth( this.Year, this.Month ) )
end function

private function LocalDate.CompareTo( byref o as LocalDate ) as long
	dim as boolean bad = ( this.m_days = DT_INVALID_DAYS )
	dim as boolean badO = ( o.m_days = DT_INVALID_DAYS )
	if bad orelse badO then return -2
	if this.m_days < o.m_days then return -1
	if this.m_days > o.m_days then return 1
	return 0
end function

private operator - ( byref a as LocalDate, byref b as LocalDate ) as long
	dim as boolean bad = ( a.m_days = DT_INVALID_DAYS )
	dim as boolean badO = ( b.m_days = DT_INVALID_DAYS )
	if bad orelse badO then return DT_INVALID_DAYS
	return a.m_days - b.m_days
end operator
private operator = ( byref a as LocalDate, byref b as LocalDate ) as boolean
	return a.CompareTo( b ) = 0
end operator
private operator <> ( byref a as LocalDate, byref b as LocalDate ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean cmp = ( c <> 0 )
	dim as boolean known = ( c <> -2 )
	return cmp andalso known
end operator
private operator < ( byref a as LocalDate, byref b as LocalDate ) as boolean
	return a.CompareTo( b ) = -1
end operator
private operator > ( byref a as LocalDate, byref b as LocalDate ) as boolean
	return a.CompareTo( b ) = 1
end operator
private operator <= ( byref a as LocalDate, byref b as LocalDate ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean le = ( c <= 0 )
	dim as boolean known = ( c <> -2 )
	return le andalso known
end operator
private operator >= ( byref a as LocalDate, byref b as LocalDate ) as boolean
	return a.CompareTo( b ) >= 0
end operator

'' ================================================================ LocalTime
''
'' A time of day with no date and no offset: 0 .. one tick short of a day.
type LocalTime
	m_ticks as longint

	declare constructor( )
	declare constructor( byval h as long, byval mi as long, byval s as long, _
	                     byval ms as long )

	declare static function FromTicks( byval t as longint ) as LocalTime
	declare static function Midnight ( ) as LocalTime
	declare static function Noon     ( ) as LocalTime
	declare static function MaxValue ( ) as LocalTime
	declare static function Invalid  ( ) as LocalTime

	declare property IsValid    ( ) as boolean
	declare property Ticks      ( ) as longint
	declare property Hour       ( ) as long
	declare property Minute     ( ) as long
	declare property Second     ( ) as long
	declare property Millisecond( ) as long
	declare property Microsecond( ) as long

	declare function CompareTo( byref o as LocalTime ) as long

	declare function ToIsoString( ) as string
	declare function ToString   ( ) as string
	declare static function TryParseIso( byref s as string, byref result as LocalTime ) as boolean
	declare static function ParseIso   ( byref s as string ) as LocalTime

	declare function ToIsoUString( ) as ustring
	declare static function TryParseIso overload ( byref s as ustring, byref result as LocalTime ) as boolean
	declare static function ParseIso    overload ( byref s as ustring ) as LocalTime
end type

declare operator - ( byref a as LocalTime, byref b as LocalTime ) as TimeSpan
declare operator =  ( byref a as LocalTime, byref b as LocalTime ) as boolean
declare operator <> ( byref a as LocalTime, byref b as LocalTime ) as boolean
declare operator <  ( byref a as LocalTime, byref b as LocalTime ) as boolean
declare operator >  ( byref a as LocalTime, byref b as LocalTime ) as boolean
declare operator <= ( byref a as LocalTime, byref b as LocalTime ) as boolean
declare operator >= ( byref a as LocalTime, byref b as LocalTime ) as boolean

private constructor LocalTime( )
	this.m_ticks = 0
end constructor

private constructor LocalTime( byval h as long, byval mi as long, byval s as long, _
                               byval ms as long )
	if fb_DtIsValidTime( h, mi, s, clngint( ms ) * DT_TICKS_PER_MILLISECOND ) = 0 then
		this.m_ticks = DT_INVALID_TICKS
	else
		this.m_ticks = clngint( h ) * DT_TICKS_PER_HOUR _
		             + clngint( mi ) * DT_TICKS_PER_MINUTE _
		             + clngint( s ) * DT_TICKS_PER_SECOND _
		             + clngint( ms ) * DT_TICKS_PER_MILLISECOND
	end if
end constructor

private function LocalTime.FromTicks( byval t as longint ) as LocalTime
	dim as LocalTime r
	dim as boolean lo = ( t < 0 )
	dim as boolean hi = ( t >= DT_TICKS_PER_DAY )
	if lo orelse hi then
		r.m_ticks = DT_INVALID_TICKS
	else
		r.m_ticks = t
	end if
	return r
end function

private function LocalTime.Midnight( ) as LocalTime
	return LocalTime.FromTicks( 0 )
end function
private function LocalTime.Noon( ) as LocalTime
	return LocalTime.FromTicks( 12 * DT_TICKS_PER_HOUR )
end function
private function LocalTime.MaxValue( ) as LocalTime
	return LocalTime.FromTicks( DT_TICKS_PER_DAY - 1 )
end function
private function LocalTime.Invalid( ) as LocalTime
	dim as LocalTime r
	r.m_ticks = DT_INVALID_TICKS
	return r
end function

private property LocalTime.IsValid( ) as boolean
	dim as boolean lo = ( this.m_ticks >= 0 )
	dim as boolean hi = ( this.m_ticks < DT_TICKS_PER_DAY )
	return lo andalso hi
end property
private property LocalTime.Ticks( ) as longint
	return this.m_ticks
end property
private property LocalTime.Hour( ) as long
	if this.IsValid = false then return 0
	return clng( this.m_ticks \ DT_TICKS_PER_HOUR )
end property
private property LocalTime.Minute( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_MINUTE ) mod 60 )
end property
private property LocalTime.Second( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_SECOND ) mod 60 )
end property
private property LocalTime.Millisecond( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_MILLISECOND ) mod 1000 )
end property
private property LocalTime.Microsecond( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_MICROSECOND ) mod 1000000 )
end property

private function LocalTime.CompareTo( byref o as LocalTime ) as long
	dim as boolean bad = ( this.IsValid = false )
	dim as boolean badO = ( o.IsValid = false )
	if bad orelse badO then return -2
	if this.m_ticks < o.m_ticks then return -1
	if this.m_ticks > o.m_ticks then return 1
	return 0
end function

private operator - ( byref a as LocalTime, byref b as LocalTime ) as TimeSpan
	dim as boolean bad = ( a.IsValid = false )
	dim as boolean badO = ( b.IsValid = false )
	if bad orelse badO then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( a.m_ticks - b.m_ticks )
end operator
private operator = ( byref a as LocalTime, byref b as LocalTime ) as boolean
	return a.CompareTo( b ) = 0
end operator
private operator <> ( byref a as LocalTime, byref b as LocalTime ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean cmp = ( c <> 0 )
	dim as boolean known = ( c <> -2 )
	return cmp andalso known
end operator
private operator < ( byref a as LocalTime, byref b as LocalTime ) as boolean
	return a.CompareTo( b ) = -1
end operator
private operator > ( byref a as LocalTime, byref b as LocalTime ) as boolean
	return a.CompareTo( b ) = 1
end operator
private operator <= ( byref a as LocalTime, byref b as LocalTime ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean le = ( c <= 0 )
	dim as boolean known = ( c <> -2 )
	return le andalso known
end operator
private operator >= ( byref a as LocalTime, byref b as LocalTime ) as boolean
	return a.CompareTo( b ) >= 0
end operator

'' ================================================================== Instant
''
'' An absolute point on the UTC timeline.  No offset field, because an absolute
'' point does not have one.  This is the type for "when did this happen":
'' timestamps, log lines, expiry times, anything compared across machines.
''
'' Converting to a DateTime always names a zone explicitly and never happens
'' implicitly -- see DateTime.FromInstant.  ToLocal arrives in RFC-0007.
type Instant
	m_ticks as longint

	declare constructor( )
	declare constructor( byval t as longint )

	declare static function FromTicks( byval t as longint ) as Instant
	declare static function MinValue ( ) as Instant
	declare static function MaxValue ( ) as Instant
	declare static function Invalid  ( ) as Instant

	declare property IsValid( ) as boolean
	declare property Ticks  ( ) as longint

	declare function Add      ( byref s as TimeSpan ) as Instant
	declare function Subtract ( byref s as TimeSpan ) as Instant
	declare function CompareTo( byref o as Instant  ) as long

	declare function ToIsoString( ) as string
	declare function ToString   ( ) as string
	'' Requires an offset in the input: there is no way to place a naive
	'' reading on the UTC timeline without guessing.
	declare static function TryParseIso( byref s as string, byref result as Instant ) as boolean
	declare static function ParseIso   ( byref s as string ) as Instant

	declare static function FromUnixSeconds     ( byval v as longint ) as Instant
	declare static function FromUnixMilliseconds( byval v as longint ) as Instant
	declare static function FromUnixMicroseconds( byval v as longint ) as Instant
	declare property UnixSeconds     ( ) as longint
	declare property UnixMilliseconds( ) as longint
	declare property UnixMicroseconds( ) as longint

	declare function ToIsoUString( ) as ustring
	declare static function TryParseIso overload ( byref s as ustring, byref result as Instant ) as boolean
	declare static function ParseIso    overload ( byref s as ustring ) as Instant
end type

declare operator + ( byref a as Instant, byref s as TimeSpan ) as Instant
declare operator - ( byref a as Instant, byref s as TimeSpan ) as Instant
declare operator - ( byref a as Instant, byref b as Instant  ) as TimeSpan
declare operator =  ( byref a as Instant, byref b as Instant ) as boolean
declare operator <> ( byref a as Instant, byref b as Instant ) as boolean
declare operator <  ( byref a as Instant, byref b as Instant ) as boolean
declare operator >  ( byref a as Instant, byref b as Instant ) as boolean
declare operator <= ( byref a as Instant, byref b as Instant ) as boolean
declare operator >= ( byref a as Instant, byref b as Instant ) as boolean

private constructor Instant( )
	this.m_ticks = DT_INVALID_TICKS
end constructor

private constructor Instant( byval t as longint )
	if fb_DtIsValidTicks( t ) = 0 then
		this.m_ticks = DT_INVALID_TICKS
	else
		this.m_ticks = t
	end if
end constructor

private function Instant.FromTicks( byval t as longint ) as Instant
	return Instant( t )
end function
private function Instant.MinValue( ) as Instant
	return Instant( DT_MIN_TICKS )
end function
private function Instant.MaxValue( ) as Instant
	return Instant( DT_MAX_TICKS )
end function
private function Instant.Invalid( ) as Instant
	dim as Instant r
	r.m_ticks = DT_INVALID_TICKS
	return r
end function

private property Instant.IsValid( ) as boolean
	return fb_DtIsValidTicks( this.m_ticks ) <> 0
end property
private property Instant.Ticks( ) as longint
	return this.m_ticks
end property

private function Instant.Add( byref s as TimeSpan ) as Instant
	dim as boolean bad = ( this.IsValid = false )
	dim as boolean badS = ( s.IsValid = false )
	if bad orelse badS then return Instant.Invalid( )
	if dtAddOverflows( this.m_ticks, s.Ticks ) then return Instant.Invalid( )
	return Instant( this.m_ticks + s.Ticks )
end function

private function Instant.Subtract( byref s as TimeSpan ) as Instant
	dim as boolean bad = ( this.IsValid = false )
	dim as boolean badS = ( s.IsValid = false )
	if bad orelse badS then return Instant.Invalid( )
	if dtAddOverflows( this.m_ticks, -s.Ticks ) then return Instant.Invalid( )
	return Instant( this.m_ticks - s.Ticks )
end function

private function Instant.CompareTo( byref o as Instant ) as long
	dim as boolean bad = ( this.IsValid = false )
	dim as boolean badO = ( o.IsValid = false )
	if bad orelse badO then return -2
	if this.m_ticks < o.m_ticks then return -1
	if this.m_ticks > o.m_ticks then return 1
	return 0
end function

private operator + ( byref a as Instant, byref s as TimeSpan ) as Instant
	return a.Add( s )
end operator
private operator - ( byref a as Instant, byref s as TimeSpan ) as Instant
	return a.Subtract( s )
end operator
private operator - ( byref a as Instant, byref b as Instant ) as TimeSpan
	dim as boolean bad = ( a.IsValid = false )
	dim as boolean badO = ( b.IsValid = false )
	if bad orelse badO then return TimeSpan( DT_INVALID_TICKS )
	return TimeSpan( a.Ticks - b.Ticks )
end operator
private operator = ( byref a as Instant, byref b as Instant ) as boolean
	return a.CompareTo( b ) = 0
end operator
private operator <> ( byref a as Instant, byref b as Instant ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean cmp = ( c <> 0 )
	dim as boolean known = ( c <> -2 )
	return cmp andalso known
end operator
private operator < ( byref a as Instant, byref b as Instant ) as boolean
	return a.CompareTo( b ) = -1
end operator
private operator > ( byref a as Instant, byref b as Instant ) as boolean
	return a.CompareTo( b ) = 1
end operator
private operator <= ( byref a as Instant, byref b as Instant ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean le = ( c <= 0 )
	dim as boolean known = ( c <> -2 )
	return le andalso known
end operator
private operator >= ( byref a as Instant, byref b as Instant ) as boolean
	return a.CompareTo( b ) >= 0
end operator

'' ================================================================= DateTime
''
'' A civil date-time plus a UTC offset.  m_ticks holds the LOCAL wall-clock
'' reading, not the UTC instant -- that is what survives a round trip through
'' ISO 8601 text without losing what the writer meant, and it is what
'' DateTimeOffset (C#) and OffsetDateTime (java.time) both do.
''
'' Three offset states, per RFC-0001 section 2.1:
''     0                        explicitly UTC          renders as Z
''     -1080 .. 1080            a known fixed offset    renders as +05:30
''     DT_OFFSET_UNSPECIFIED    naive; nobody said      renders bare
type DateTime
	m_ticks  as longint
	m_offset as short

	declare constructor( )
	declare constructor( byval y as long, byval mo as long, byval d as long )
	declare constructor( byval y as long, byval mo as long, byval d as long, _
	                     byval h as long, byval mi as long, byval s as long, _
	                     byval ms as long )

	declare static function FromTicks( byval t as longint, _
	                                   byval offMin as short ) as DateTime
	declare static function FromDate    ( byref d as LocalDate ) as DateTime
	declare static function FromDateTime( byref d as LocalDate, byref t as LocalTime ) as DateTime
	declare static function FromInstant ( byref i as Instant, byval offMin as short ) as DateTime
	declare static function MinValue( ) as DateTime
	declare static function MaxValue( ) as DateTime
	declare static function Invalid ( ) as DateTime

	declare property IsValid      ( ) as boolean
	declare property Ticks        ( ) as longint
	declare property OffsetMinutes( ) as short
	declare property HasOffset    ( ) as boolean
	declare property IsUtc        ( ) as boolean

	declare property Year       ( ) as long
	declare property Month      ( ) as long
	declare property Day        ( ) as long
	declare property Hour       ( ) as long
	declare property Minute     ( ) as long
	declare property Second     ( ) as long
	declare property Millisecond( ) as long
	declare property Microsecond( ) as long
	declare property TickOfDay  ( ) as longint
	declare property DayOfWeek  ( ) as long
	declare property DayOfYear  ( ) as long

	declare function GetDate     ( ) as LocalDate
	declare function GetTimeOfDay( ) as LocalTime

	'' WithOffset REINTERPRETS: keeps the wall reading, changes the instant.
	'' ToOffset CONVERTS: keeps the instant, changes the wall reading.
	'' Neither is a safe default, which is why neither is implicit.
	declare function WithOffset( byval offMin as short ) as DateTime
	declare function ToOffset  ( byval offMin as short ) as DateTime
	declare function AssumeUtc ( ) as Instant
	declare function ToInstant ( ) as Instant

	'' Exact tick arithmetic.  AddDays( 1 ) adds exactly 86400 seconds and so
	'' does NOT preserve the wall-clock time across a DST boundary; that is
	'' AddCalendarDays, in RFC-0007.  AddMonths / AddYears are RFC-0004.
	declare function Add            ( byref s as TimeSpan ) as DateTime
	declare function Subtract       ( byref s as TimeSpan ) as DateTime
	declare function AddTicks       ( byval n as longint ) as DateTime
	declare function AddDays        ( byval n as double  ) as DateTime
	declare function AddHours       ( byval n as double  ) as DateTime
	declare function AddMinutes     ( byval n as double  ) as DateTime
	declare function AddSeconds     ( byval n as double  ) as DateTime
	declare function AddMilliseconds( byval n as double  ) as DateTime

	'' Calendar arithmetic (RFC-0004).  Takes a plain LONG, not a TimeSpan,
	'' because months and years are not fixed-length units -- keeping the two
	'' kinds of arithmetic visibly separate is the whole point.
	declare function AddMonths( byval n as long ) as DateTime
	declare function AddYears ( byval n as long ) as DateTime

	'' Calendar utilities (RFC-0004 section 3)
	declare static function IsLeapYear ( byval y as long ) as boolean
	declare static function DaysInMonth( byval y as long, byval mo as long ) as long
	declare static function DaysInYear ( byval y as long ) as long
	declare static function WeeksInYear( byval y as long ) as long

	declare property IsoWeek    ( ) as long
	declare property IsoWeekYear( ) as long
	declare property Quarter    ( ) as long
	declare property IsFirstDayOfMonth( ) as boolean
	declare property IsLastDayOfMonth ( ) as boolean

	declare function StartOfDay  ( ) as DateTime
	declare function EndOfDay    ( ) as DateTime
	declare function StartOfMonth( ) as DateTime
	declare function EndOfMonth  ( ) as DateTime
	declare function StartOfYear ( ) as DateTime
	declare function EndOfYear   ( ) as DateTime
	declare function StartOfWeek ( byval firstDay as long = DT_MONDAY ) as DateTime
	declare function NextWeekday ( byval dow as long ) as DateTime
	declare function PrevWeekday ( byval dow as long ) as DateTime

	declare property JulianDay      ( ) as double
	declare property JulianDayNumber( ) as longint
	declare static function FromJulianDay( byval jd as double ) as DateTime

	declare function CompareTo      ( byref o as DateTime ) as long

	declare function ToIsoString( ) as string
	declare function ToString   ( ) as string
	declare static function TryParseIso( byref s as string, byref result as DateTime ) as boolean
	declare static function TryParse   ( byref s as string, byref result as DateTime ) as boolean
	declare static function ParseIso   ( byref s as string ) as DateTime

	'' Custom patterns (RFC-0006).  Output depends only on the value and the
	'' pattern -- names are invariant English, never the OS locale, so this is
	'' safe to write to a file.  Locale formatting is RFC-0007.
	declare function ToString ( byref pattern as string ) as string
	declare function TryFormat( byref pattern as string, byref result as string ) as boolean
	declare static function TryParseExact( byref s as string, byref pattern as string, _
	                                       byref result as DateTime ) as boolean
	declare static function ParseExact   ( byref s as string, byref pattern as string ) as DateTime

	'' Calendar-preserving arithmetic (RFC-0007 section 2).  "Same time
	'' tomorrow" -- unlike AddDays( 1 ), which is exactly 86400 seconds.
	'' They differ twice a year and the names say which is which.
	declare function AddCalendarDays  ( byval n as long ) as DateTime
	declare function AddCalendarMonths( byval n as long ) as DateTime
	declare function AddCalendarYears ( byval n as long ) as DateTime

	declare function ToLocal( ) as DateTime

	'' Locale formatting (RFC-0007 section 3).  Output is whatever the
	'' machine says; use RFC-0006 patterns for anything written to a file.
	declare function ToLocaleDateString( byval style as long = lsShort ) as string
	declare function ToLocaleTimeString( byval style as long = lsShort ) as string
	declare function ToLocaleString    ( byval style as long = lsShort ) as string

	declare static function MonthName  ( byval mo as long, byval abbreviated as boolean = false ) as string
	declare static function WeekdayName( byval dow as long, byval abbreviated as boolean = false ) as string

	'' Interop (RFC-0007 section 4)
	declare static function FromUnixSeconds     ( byval v as longint ) as DateTime
	declare static function FromUnixMilliseconds( byval v as longint ) as DateTime
	declare static function FromSerial          ( byval d as double  ) as DateTime
	declare property UnixSeconds     ( ) as longint
	declare property UnixMilliseconds( ) as longint
	declare property UnixMicroseconds( ) as longint
	declare property Serial          ( ) as double
	declare property FileTime        ( ) as longint
	declare static function FromFileTime( byval ft as longint ) as DateTime
	declare property OleDate         ( ) as double
	declare static function FromOleDate  ( byval d as double ) as DateTime

	'' ------------------------------------------------ USTRING (phase 8)
	'' The tree's rule (fb/string.bi) is that the INPUT type decides the
	'' output type, and that a function cannot return the type it was
	'' handed.  So anything taking text overloads and returns USTRING;
	'' anything taking none cannot overload on return type alone and so
	'' carries a U in its name.
	declare function ToIsoUString( ) as ustring
	declare function ToString  overload ( byref pattern as ustring ) as ustring
	declare function TryFormat overload ( byref pattern as ustring, byref result as ustring ) as boolean

	declare static function TryParseIso   overload ( byref s as ustring, byref result as DateTime ) as boolean
	declare static function TryParse      overload ( byref s as ustring, byref result as DateTime ) as boolean
	declare static function ParseIso      overload ( byref s as ustring ) as DateTime
	declare static function TryParseExact overload ( byref s as ustring, byref pattern as ustring, byref result as DateTime ) as boolean
	declare static function ParseExact    overload ( byref s as ustring, byref pattern as ustring ) as DateTime

	'' Locale output is the ONLY part of this library that is routinely
	'' non-ASCII, and so the only part where USTRING genuinely earns it.
	declare function ToLocaleDateUString( byval style as long = lsShort ) as ustring
	declare function ToLocaleTimeUString( byval style as long = lsShort ) as ustring
	declare function ToLocaleUString    ( byval style as long = lsShort ) as ustring
	declare static function MonthUName  ( byval mo as long, byval abbreviated as boolean = false ) as ustring
	declare static function WeekdayUName( byval dow as long, byval abbreviated as boolean = false ) as ustring
end type

declare operator + ( byref a as DateTime, byref s as TimeSpan ) as DateTime
declare operator - ( byref a as DateTime, byref s as TimeSpan ) as DateTime
declare operator - ( byref a as DateTime, byref b as DateTime ) as TimeSpan
declare operator =  ( byref a as DateTime, byref b as DateTime ) as boolean
declare operator <> ( byref a as DateTime, byref b as DateTime ) as boolean
declare operator <  ( byref a as DateTime, byref b as DateTime ) as boolean
declare operator >  ( byref a as DateTime, byref b as DateTime ) as boolean
declare operator <= ( byref a as DateTime, byref b as DateTime ) as boolean
declare operator >= ( byref a as DateTime, byref b as DateTime ) as boolean

private function dtOffsetIsValid( byval m as short ) as boolean
	if m = DT_OFFSET_UNSPECIFIED then return true
	dim as boolean lo = ( m >= DT_OFFSET_MIN )
	dim as boolean hi = ( m <= DT_OFFSET_MAX )
	return lo andalso hi
end function

private constructor DateTime( )
	this.m_ticks = DT_INVALID_TICKS
	this.m_offset = DT_OFFSET_UNSPECIFIED
end constructor

private constructor DateTime( byval y as long, byval mo as long, byval d as long )
	this.m_offset = DT_OFFSET_UNSPECIFIED
	if fb_DtFromCivil( y, mo, d, 0, 0, 0, 0, @this.m_ticks ) <> 0 then
		this.m_ticks = DT_INVALID_TICKS
	end if
end constructor

private constructor DateTime( byval y as long, byval mo as long, byval d as long, _
                              byval h as long, byval mi as long, byval s as long, _
                              byval ms as long )
	this.m_offset = DT_OFFSET_UNSPECIFIED
	if fb_DtFromCivil( y, mo, d, h, mi, s, clngint( ms ) * DT_TICKS_PER_MILLISECOND, _
	                   @this.m_ticks ) <> 0 then
		this.m_ticks = DT_INVALID_TICKS
	end if
end constructor

private function DateTime.FromTicks( byval t as longint, byval offMin as short ) as DateTime
	dim as DateTime r
	dim as boolean okTicks = ( fb_DtIsValidTicks( t ) <> 0 )
	dim as boolean okOff = dtOffsetIsValid( offMin )
	if okTicks andalso okOff then
		r.m_ticks = t
		r.m_offset = offMin
	end if
	return r
end function

private function DateTime.FromDate( byref d as LocalDate ) as DateTime
	if d.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( d.DayNumber ) * DT_TICKS_PER_DAY, _
	                           DT_OFFSET_UNSPECIFIED )
end function

private function DateTime.FromDateTime( byref d as LocalDate, byref t as LocalTime ) as DateTime
	dim as boolean bad = ( d.IsValid = false )
	dim as boolean badT = ( t.IsValid = false )
	if bad orelse badT then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( d.DayNumber ) * DT_TICKS_PER_DAY + t.Ticks, _
	                           DT_OFFSET_UNSPECIFIED )
end function

'' The Instant -> DateTime direction.  It is a static here rather than a member
'' on Instant only because FreeBASIC cannot forward-declare a UDT return type.
private function DateTime.FromInstant( byref i as Instant, byval offMin as short ) as DateTime
	if i.IsValid = false then return DateTime.Invalid( )
	if dtOffsetIsValid( offMin ) = false then return DateTime.Invalid( )
	if offMin = DT_OFFSET_UNSPECIFIED then return DateTime.Invalid( )
	dim as longint shift = clngint( offMin ) * DT_TICKS_PER_MINUTE
	if dtAddOverflows( i.Ticks, shift ) then return DateTime.Invalid( )
	return DateTime.FromTicks( i.Ticks + shift, offMin )
end function

private function DateTime.MinValue( ) as DateTime
	return DateTime.FromTicks( DT_MIN_TICKS, DT_OFFSET_UNSPECIFIED )
end function
private function DateTime.MaxValue( ) as DateTime
	return DateTime.FromTicks( DT_MAX_TICKS, DT_OFFSET_UNSPECIFIED )
end function
private function DateTime.Invalid( ) as DateTime
	dim as DateTime r
	return r
end function

private property DateTime.IsValid( ) as boolean
	return fb_DtIsValidTicks( this.m_ticks ) <> 0
end property
private property DateTime.Ticks( ) as longint
	return this.m_ticks
end property
private property DateTime.OffsetMinutes( ) as short
	return this.m_offset
end property
private property DateTime.HasOffset( ) as boolean
	return this.m_offset <> DT_OFFSET_UNSPECIFIED
end property
private property DateTime.IsUtc( ) as boolean
	return this.m_offset = 0
end property

private property DateTime.Year( ) as long
	if this.IsValid = false then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( clng( this.m_ticks \ DT_TICKS_PER_DAY ), @y, @mo, @d )
	return y
end property
private property DateTime.Month( ) as long
	if this.IsValid = false then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( clng( this.m_ticks \ DT_TICKS_PER_DAY ), @y, @mo, @d )
	return mo
end property
private property DateTime.Day( ) as long
	if this.IsValid = false then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( clng( this.m_ticks \ DT_TICKS_PER_DAY ), @y, @mo, @d )
	return d
end property
private property DateTime.TickOfDay( ) as longint
	if this.IsValid = false then return 0
	return this.m_ticks mod DT_TICKS_PER_DAY
end property
private property DateTime.Hour( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks mod DT_TICKS_PER_DAY ) \ DT_TICKS_PER_HOUR )
end property
private property DateTime.Minute( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_MINUTE ) mod 60 )
end property
private property DateTime.Second( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_SECOND ) mod 60 )
end property
private property DateTime.Millisecond( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_MILLISECOND ) mod 1000 )
end property
private property DateTime.Microsecond( ) as long
	if this.IsValid = false then return 0
	return clng( ( this.m_ticks \ DT_TICKS_PER_MICROSECOND ) mod 1000000 )
end property
private property DateTime.DayOfWeek( ) as long
	if this.IsValid = false then return 0
	return fb_DtDayOfWeek( clng( this.m_ticks \ DT_TICKS_PER_DAY ) )
end property
private property DateTime.DayOfYear( ) as long
	if this.IsValid = false then return 0
	dim as long y, mo, d
	fb_DtCivilFromDays( clng( this.m_ticks \ DT_TICKS_PER_DAY ), @y, @mo, @d )
	return fb_DtDayOfYear( y, mo, d )
end property

private function DateTime.GetDate( ) as LocalDate
	if this.IsValid = false then return LocalDate.Invalid( )
	return LocalDate.FromDayNumber( clng( this.m_ticks \ DT_TICKS_PER_DAY ) )
end function

private function DateTime.GetTimeOfDay( ) as LocalTime
	if this.IsValid = false then return LocalTime.Invalid( )
	return LocalTime.FromTicks( this.m_ticks mod DT_TICKS_PER_DAY )
end function

private function DateTime.WithOffset( byval offMin as short ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( this.m_ticks, offMin )
end function

private function DateTime.ToOffset( byval offMin as short ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	if this.HasOffset = false then return DateTime.Invalid( )
	if dtOffsetIsValid( offMin ) = false then return DateTime.Invalid( )
	if offMin = DT_OFFSET_UNSPECIFIED then return DateTime.Invalid( )
	dim as longint delta = ( clngint( offMin ) - clngint( this.m_offset ) ) * DT_TICKS_PER_MINUTE
	if dtAddOverflows( this.m_ticks, delta ) then return DateTime.Invalid( )
	return DateTime.FromTicks( this.m_ticks + delta, offMin )
end function

'' Reads the wall-clock value AS IF it were UTC, whatever the offset says.
private function DateTime.AssumeUtc( ) as Instant
	if this.IsValid = false then return Instant.Invalid( )
	return Instant( this.m_ticks )
end function

'' Uses the carried offset.  Invalid when nobody said what the offset was --
'' there is no defensible way to place a naive reading on the UTC timeline.
private function DateTime.ToInstant( ) as Instant
	if this.IsValid = false then return Instant.Invalid( )
	if this.HasOffset = false then return Instant.Invalid( )
	dim as longint shift = clngint( this.m_offset ) * DT_TICKS_PER_MINUTE
	if dtAddOverflows( this.m_ticks, -shift ) then return Instant.Invalid( )
	return Instant( this.m_ticks - shift )
end function

private function DateTime.AddTicks( byval n as longint ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	'' Belt and braces: FromTicks already rejects anything outside the range,
	'' and because m_ticks is in [0, MAX] the sum can only overflow POSITIVELY
	'' (wrapping negative, which FromTicks rejects) -- underflow is impossible
	'' since m_ticks >= 0 means the sum is never below LLONG_MIN.  So this guard
	'' cannot change a result today; it is here so the code never relies on
	'' wraparound, and mutation testing correctly reports it as unkillable.
	if dtAddOverflows( this.m_ticks, n ) then return DateTime.Invalid( )
	return DateTime.FromTicks( this.m_ticks + n, this.m_offset )
end function

private function DateTime.Add( byref s as TimeSpan ) as DateTime
	if s.IsValid = false then return DateTime.Invalid( )
	return this.AddTicks( s.Ticks )
end function

private function DateTime.Subtract( byref s as TimeSpan ) as DateTime
	if s.IsValid = false then return DateTime.Invalid( )
	return this.AddTicks( -s.Ticks )
end function

private function DateTime.AddDays( byval n as double ) as DateTime
	dim as longint t = dtTicksFromDouble( n * DT_TICKS_PER_DAY )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	return this.AddTicks( t )
end function
private function DateTime.AddHours( byval n as double ) as DateTime
	dim as longint t = dtTicksFromDouble( n * DT_TICKS_PER_HOUR )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	return this.AddTicks( t )
end function
private function DateTime.AddMinutes( byval n as double ) as DateTime
	dim as longint t = dtTicksFromDouble( n * DT_TICKS_PER_MINUTE )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	return this.AddTicks( t )
end function
private function DateTime.AddSeconds( byval n as double ) as DateTime
	dim as longint t = dtTicksFromDouble( n * DT_TICKS_PER_SECOND )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	return this.AddTicks( t )
end function
private function DateTime.AddMilliseconds( byval n as double ) as DateTime
	dim as longint t = dtTicksFromDouble( n * DT_TICKS_PER_MILLISECOND )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	return this.AddTicks( t )
end function

'' Calendar arithmetic.  Delegates to LocalDate so the end-of-month clamping
'' rule is implemented exactly once; the time of day and the offset ride through
'' untouched.
private function DateTime.AddMonths( byval n as long ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	dim as LocalDate d = this.GetDate( ).AddMonths( n )
	if d.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( d.DayNumber ) * DT_TICKS_PER_DAY _
	                           + ( this.m_ticks mod DT_TICKS_PER_DAY ), this.m_offset )
end function

private function DateTime.AddYears( byval n as long ) as DateTime
	if n > 178956970 then return DateTime.Invalid( )
	if n < -178956970 then return DateTime.Invalid( )
	return this.AddMonths( n * 12 )
end function

private function DateTime.IsLeapYear( byval y as long ) as boolean
	return fb_DtIsLeapYear( y ) <> 0
end function
private function DateTime.DaysInMonth( byval y as long, byval mo as long ) as long
	return fb_DtDaysInMonth( y, mo )
end function
private function DateTime.DaysInYear( byval y as long ) as long
	return fb_DtDaysInYear( y )
end function
private function DateTime.WeeksInYear( byval y as long ) as long
	return fb_DtIsoWeeksInYear( y )
end function

private property DateTime.IsoWeek( ) as long
	if this.IsValid = false then return 0
	return this.GetDate( ).IsoWeek
end property
'' NOT always the same as Year: 2025-12-29 is week 1 of ISO year 2026.  Using
'' Year here instead is the canonical bug in ISO week rendering.
private property DateTime.IsoWeekYear( ) as long
	if this.IsValid = false then return 0
	return this.GetDate( ).IsoWeekYear
end property
private property DateTime.Quarter( ) as long
	if this.IsValid = false then return 0
	return ( ( this.Month - 1 ) \ 3 ) + 1
end property
private property DateTime.IsFirstDayOfMonth( ) as boolean
	if this.IsValid = false then return false
	return this.Day = 1
end property
private property DateTime.IsLastDayOfMonth( ) as boolean
	if this.IsValid = false then return false
	return this.Day = fb_DtDaysInMonth( this.Year, this.Month )
end property

private function DateTime.StartOfDay( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( ( this.m_ticks \ DT_TICKS_PER_DAY ) * DT_TICKS_PER_DAY, _
	                           this.m_offset )
end function
private function DateTime.EndOfDay( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( ( this.m_ticks \ DT_TICKS_PER_DAY ) * DT_TICKS_PER_DAY _
	                           + DT_TICKS_PER_DAY - 1, this.m_offset )
end function
private function DateTime.StartOfMonth( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( this.GetDate( ).StartOfMonth( ).DayNumber ) _
	                           * DT_TICKS_PER_DAY, this.m_offset )
end function
private function DateTime.EndOfMonth( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( this.GetDate( ).EndOfMonth( ).DayNumber ) _
	                           * DT_TICKS_PER_DAY + DT_TICKS_PER_DAY - 1, this.m_offset )
end function
private function DateTime.StartOfYear( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( fb_DtDaysFromCivil( this.Year, 1, 1 ) ) _
	                           * DT_TICKS_PER_DAY, this.m_offset )
end function
private function DateTime.EndOfYear( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromTicks( clngint( fb_DtDaysFromCivil( this.Year, 12, 31 ) ) _
	                           * DT_TICKS_PER_DAY + DT_TICKS_PER_DAY - 1, this.m_offset )
end function

private function DateTime.StartOfWeek( byval firstDay as long ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	dim as boolean lo = ( firstDay < DT_MONDAY )
	dim as boolean hi = ( firstDay > DT_SUNDAY )
	if lo orelse hi then return DateTime.Invalid( )
	dim as long back = this.DayOfWeek - firstDay
	if back < 0 then back += 7
	return this.StartOfDay( ).AddTicks( -clngint( back ) * DT_TICKS_PER_DAY )
end function

'' Strictly later: already on that weekday means a week forward, not a no-op.
private function DateTime.NextWeekday( byval dow as long ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	dim as boolean lo = ( dow < DT_MONDAY )
	dim as boolean hi = ( dow > DT_SUNDAY )
	if lo orelse hi then return DateTime.Invalid( )
	dim as long fwd = dow - this.DayOfWeek
	if fwd <= 0 then fwd += 7
	return this.AddTicks( clngint( fwd ) * DT_TICKS_PER_DAY )
end function

private function DateTime.PrevWeekday( byval dow as long ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	dim as boolean lo = ( dow < DT_MONDAY )
	dim as boolean hi = ( dow > DT_SUNDAY )
	if lo orelse hi then return DateTime.Invalid( )
	dim as long back = this.DayOfWeek - dow
	if back <= 0 then back += 7
	return this.AddTicks( -clngint( back ) * DT_TICKS_PER_DAY )
end function

'' Julian day: fractional and NOON-based, which is why the half-day appears.
'' JD 2451545.0 is 2000-01-01T12:00 UTC.
private property DateTime.JulianDay( ) as double
	if this.IsValid = false then return 0
	return ( this.m_ticks / DT_TICKS_PER_DAY ) + DT_JULIAN_DAY_AT_EPOCH - 0.5
end property
private property DateTime.JulianDayNumber( ) as longint
	if this.IsValid = false then return 0
	return ( this.m_ticks \ DT_TICKS_PER_DAY ) + DT_JULIAN_DAY_AT_EPOCH
end property
private function DateTime.FromJulianDay( byval jd as double ) as DateTime
	dim as double days = jd - DT_JULIAN_DAY_AT_EPOCH + 0.5
	dim as longint t = dtTicksFromDouble( days * DT_TICKS_PER_DAY )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	return DateTime.FromTicks( t, DT_OFFSET_UNSPECIFIED )
end function

'' RFC-0004 section 1: two offset-bearing values compare as INSTANTS; two naive
'' values compare as civil readings; one of each is not comparable, because
'' there is no defensible answer.
private function DateTime.CompareTo( byref o as DateTime ) as long
	dim as boolean bad = ( this.IsValid = false )
	dim as boolean badO = ( o.IsValid = false )
	if bad orelse badO then return -2

	dim as boolean hasA = this.HasOffset
	dim as boolean hasB = o.HasOffset
	if hasA <> hasB then return -2

	dim as longint ta = this.m_ticks
	dim as longint tb = o.m_ticks
	if hasA then
		ta -= clngint( this.m_offset ) * DT_TICKS_PER_MINUTE
		tb -= clngint( o.m_offset ) * DT_TICKS_PER_MINUTE
	end if

	if ta < tb then return -1
	if ta > tb then return 1
	return 0
end function

private operator + ( byref a as DateTime, byref s as TimeSpan ) as DateTime
	return a.Add( s )
end operator
private operator - ( byref a as DateTime, byref s as TimeSpan ) as DateTime
	return a.Subtract( s )
end operator
private operator - ( byref a as DateTime, byref b as DateTime ) as TimeSpan
	dim as boolean bad = ( a.IsValid = false )
	dim as boolean badO = ( b.IsValid = false )
	if bad orelse badO then return TimeSpan( DT_INVALID_TICKS )
	dim as boolean hasA = a.HasOffset
	dim as boolean hasB = b.HasOffset
	if hasA <> hasB then return TimeSpan( DT_INVALID_TICKS )

	dim as longint ta = a.Ticks
	dim as longint tb = b.Ticks
	if hasA then
		ta -= clngint( a.OffsetMinutes ) * DT_TICKS_PER_MINUTE
		tb -= clngint( b.OffsetMinutes ) * DT_TICKS_PER_MINUTE
	end if
	return TimeSpan( ta - tb )
end operator
private operator = ( byref a as DateTime, byref b as DateTime ) as boolean
	return a.CompareTo( b ) = 0
end operator
private operator <> ( byref a as DateTime, byref b as DateTime ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean cmp = ( c <> 0 )
	dim as boolean known = ( c <> -2 )
	return cmp andalso known
end operator
private operator < ( byref a as DateTime, byref b as DateTime ) as boolean
	return a.CompareTo( b ) = -1
end operator
private operator > ( byref a as DateTime, byref b as DateTime ) as boolean
	return a.CompareTo( b ) = 1
end operator
private operator <= ( byref a as DateTime, byref b as DateTime ) as boolean
	dim as long c = a.CompareTo( b )
	dim as boolean le = ( c <= 0 )
	dim as boolean known = ( c <> -2 )
	return le andalso known
end operator
private operator >= ( byref a as DateTime, byref b as DateTime ) as boolean
	return a.CompareTo( b ) >= 0
end operator

'' ============================================== ISO 8601 / RFC 3339 (0005)
''
'' Emission is CANONICAL: one value produces exactly one string.  All the
'' variety ISO 8601 permits is accepted on input only.
''
'' Parsing is STRICT.  There is no locale and no guessing -- 03/04/2025 is
'' March 4th or April 3rd depending on where the machine is, and a parser that
'' resolves that silently is a data-corruption engine.  The lenient parser
'' behind datetime.bi's IsDate / DateValue keeps working and is not built upon.
''
'' TryParse ALWAYS writes its result, so a caller who ignores the return value
'' still cannot read a stale value -- it gets Invalid.

private function DateTime.ToIsoString( ) as string
	dim as zstring * 40 buf
	dim as long n = fb_DtIsoFormat( this.m_ticks, this.m_offset, @buf, 40 )
	if n <= 0 then return ""
	return left( buf, n )
end function
private function DateTime.ToString( ) as string
	return this.ToIsoString( )
end function

private function DateTime.TryParseIso( byref s as string, byref result as DateTime ) as boolean
	dim as longint t
	dim as long off
	result = DateTime.Invalid( )
	if fb_DtIsoParse( strptr( s ), len( s ), @t, @off ) <> 0 then return false
	result = DateTime.FromTicks( t, cshort( off ) )
	return result.IsValid
end function
private function DateTime.TryParse( byref s as string, byref result as DateTime ) as boolean
	return DateTime.TryParseIso( s, result )
end function
private function DateTime.ParseIso( byref s as string ) as DateTime
	dim as DateTime r
	DateTime.TryParseIso( s, r )
	return r
end function

private function Instant.ToIsoString( ) as string
	dim as zstring * 40 buf
	dim as long n = fb_DtIsoFormat( this.m_ticks, 0, @buf, 40 )
	if n <= 0 then return ""
	return left( buf, n )
end function
private function Instant.ToString( ) as string
	return this.ToIsoString( )
end function

'' An Instant REQUIRES an offset in the input.  A naive reading cannot be
'' placed on the UTC timeline without guessing, and this is the type system
'' doing its job rather than a limitation.
private function Instant.TryParseIso( byref s as string, byref result as Instant ) as boolean
	dim as longint t
	dim as long off
	result = Instant.Invalid( )
	if fb_DtIsoParse( strptr( s ), len( s ), @t, @off ) <> 0 then return false
	if off = DT_OFFSET_UNSPECIFIED then return false
	dim as longint shift = clngint( off ) * DT_TICKS_PER_MINUTE
	if dtAddOverflows( t, -shift ) then return false
	result = Instant( t - shift )
	return result.IsValid
end function
private function Instant.ParseIso( byref s as string ) as Instant
	dim as Instant r
	Instant.TryParseIso( s, r )
	return r
end function

private function LocalDate.ToIsoString( ) as string
	dim as zstring * 16 buf
	dim as long n = fb_DtIsoFormatDate( this.m_days, @buf, 16 )
	if n <= 0 then return ""
	return left( buf, n )
end function
private function LocalDate.ToString( ) as string
	return this.ToIsoString( )
end function
private function LocalDate.TryParseIso( byref s as string, byref result as LocalDate ) as boolean
	dim as long d
	result = LocalDate.Invalid( )
	if fb_DtIsoParseDate( strptr( s ), len( s ), @d ) <> 0 then return false
	result = LocalDate.FromDayNumber( d )
	return result.IsValid
end function
private function LocalDate.ParseIso( byref s as string ) as LocalDate
	dim as LocalDate r
	LocalDate.TryParseIso( s, r )
	return r
end function

private function LocalTime.ToIsoString( ) as string
	dim as zstring * 24 buf
	dim as long n = fb_DtIsoFormatTime( this.m_ticks, @buf, 24 )
	if n <= 0 then return ""
	return left( buf, n )
end function
private function LocalTime.ToString( ) as string
	return this.ToIsoString( )
end function
private function LocalTime.TryParseIso( byref s as string, byref result as LocalTime ) as boolean
	dim as longint t
	result = LocalTime.Invalid( )
	if fb_DtIsoParseTime( strptr( s ), len( s ), @t ) <> 0 then return false
	result = LocalTime.FromTicks( t )
	return result.IsValid
end function
private function LocalTime.ParseIso( byref s as string ) as LocalTime
	dim as LocalTime r
	LocalTime.TryParseIso( s, r )
	return r
end function

'' ------------------------------------------- custom patterns (RFC-0006)
''
'' A ONE-CHARACTER pattern is a named constant format, not a field:
''     "o"/"O"  round-trip ISO 8601, byte-identical to ToIsoString
''     "s"      sortable, second resolution, no offset
''     "u"      universal sortable, converted to UTC
''     "R"      RFC 1123 for HTTP headers -- always GMT, always English
''     "d"      invariant short date       "T"  invariant time
''
'' To format a single pattern letter as a field, give it a companion:
'' "dd" or "d " rather than "d".  This is the wart C# has too; the shorthands
'' earn it.
private function DateTime.ToString( byref pattern as string ) as string
	dim as string r
	if this.TryFormat( pattern, r ) = false then return ""
	return r
end function

'' Distinguishes "the pattern is broken" (false) from "the value formatted to
'' nothing" (true, empty) -- which a valid pattern can legitimately produce,
'' e.g. "K" on a value with no offset.
private function DateTime.TryFormat( byref pattern as string, byref result as string ) as boolean
	dim as zstring * 256 buf
	result = ""
	dim as long n = fb_DtPatFormat( this.m_ticks, this.m_offset, _
	                                strptr( pattern ), len( pattern ), @buf, 256 )
	if n < 0 then return false
	result = left( buf, n )
	return true
end function

private function DateTime.TryParseExact( byref s as string, byref pattern as string, _
                                         byref result as DateTime ) as boolean
	dim as longint t
	dim as long off
	result = DateTime.Invalid( )
	if fb_DtPatParse( strptr( s ), len( s ), strptr( pattern ), len( pattern ), _
	                  @t, @off ) <> 0 then return false
	result = DateTime.FromTicks( t, cshort( off ) )
	return result.IsValid
end function

private function DateTime.ParseExact( byref s as string, byref pattern as string ) as DateTime
	dim as DateTime r
	DateTime.TryParseExact( s, pattern, r )
	return r
end function

private function TimeSpan.ToIsoString( ) as string
	dim as zstring * 48 buf
	dim as long n = fb_DtIsoFormatDuration( this.m_ticks, @buf, 48 )
	if n <= 0 then return ""
	return left( buf, n )
end function
private function TimeSpan.ToString( ) as string
	return this.ToIsoString( )
end function
private function TimeSpan.TryParseIso( byref s as string, byref result as TimeSpan ) as boolean
	dim as longint t
	result = TimeSpan.Invalid( )
	if fb_DtIsoParseDuration( strptr( s ), len( s ), @t ) <> 0 then return false
	result = TimeSpan( t )
	return result.IsValid
end function
private function TimeSpan.ParseIso( byref s as string ) as TimeSpan
	dim as TimeSpan r
	TimeSpan.TryParseIso( s, r )
	return r
end function

'' ================================== zones, locale, interop (RFC-0007)
''
'' In scope: UTC, the OS local zone, explicit fixed offsets.
'' OUT of scope: the IANA tz database, named zones, DST-ambiguity policies.
'' The OS already knows the user's zone and keeps its rules current; shipping
'' and maintaining a copy of the tzdb is a project of its own.  Nothing here
'' forecloses a future ZonedDateTime -- DateTime already carries an offset.
namespace TimeZoneInfo

	'' The offset AT A GIVEN INSTANT, not "right now".  Converting a July
	'' timestamp with January's offset is the commonest timezone bug there is,
	'' and an API offering only "the current offset" makes it the default.
	private function LocalOffsetAt( byref i as Instant ) as short
		if i.IsValid = false then return 0
		return cshort( fb_DtZoneOffsetAt( i.Ticks ) )
	end function

	private function LocalOffset( ) as short
		return cshort( fb_DtZoneOffsetAt( fb_DtClockUtcNow( ) ) )
	end function

	private function IsDaylightSavingTime( byref i as Instant ) as boolean
		if i.IsValid = false then return false
		return fb_DtZoneIsDst( i.Ticks ) <> 0
	end function

	private function SupportsDaylightSavingTime( ) as boolean
		return fb_DtZoneSupportsDst( ) <> 0
	end function

	private function StandardName( ) as string
		dim as zstring * 160 buf
		dim as long n = fb_DtZoneStandardName( @buf, 160 )
		if n <= 0 then return ""
		return left( buf, n )
	end function

	private function DaylightName( ) as string
		dim as zstring * 160 buf
		dim as long n = fb_DtZoneDaylightName( @buf, 160 )
		if n <= 0 then return ""
		return left( buf, n )
	end function

end namespace

'' -- local conversion -------------------------------------------------

private function DateTime.ToLocal( ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	dim as Instant i = this.ToInstant( )
	if i.IsValid = false then i = this.AssumeUtc( )
	if i.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromInstant( i, cshort( fb_DtZoneOffsetAt( i.Ticks ) ) )
end function

'' -- calendar-preserving arithmetic (RFC-0007 section 2) ---------------
''
'' AddDays( 1 ) is exact tick arithmetic: 86400 seconds, which does NOT keep
'' the wall-clock time across a DST boundary.  These operate on the civil
'' fields and then re-resolve the offset, so they DO.
''     "24 hours from now"  -> AddDays( 1 )
''     "same time tomorrow" -> AddCalendarDays( 1 )
private function DateTime.AddCalendarDays( byval n as long ) as DateTime
	if this.IsValid = false then return DateTime.Invalid( )
	dim as LocalDate d = this.GetDate( ).AddDays( n )
	if d.IsValid = false then return DateTime.Invalid( )
	dim as DateTime r = DateTime.FromTicks( _
		clngint( d.DayNumber ) * DT_TICKS_PER_DAY + ( this.m_ticks mod DT_TICKS_PER_DAY ), _
		this.m_offset )
	if r.IsValid = false then return DateTime.Invalid( )
	if this.HasOffset = false then return r
	'' re-resolve the offset for the new local time
	return r.WithOffset( cshort( fb_DtZoneOffsetAt( r.AssumeUtc( ).Ticks ) ) )
end function

private function DateTime.AddCalendarMonths( byval n as long ) as DateTime
	dim as DateTime r = this.AddMonths( n )
	if r.IsValid = false then return DateTime.Invalid( )
	if this.HasOffset = false then return r
	return r.WithOffset( cshort( fb_DtZoneOffsetAt( r.AssumeUtc( ).Ticks ) ) )
end function

private function DateTime.AddCalendarYears( byval n as long ) as DateTime
	if n > 178956970 then return DateTime.Invalid( )
	if n < -178956970 then return DateTime.Invalid( )
	return this.AddCalendarMonths( n * 12 )
end function

'' -- locale formatting (RFC-0007 section 3) ----------------------------
''
'' HONEST LIMITATION: this output is whatever the machine's locale says and
'' CANNOT be asserted by exact string.  Its tests check non-emptiness, valid
'' UTF-8, ordering and distinctness -- and nothing more.  Anything written to
'' a file should use the RFC-0006 pattern formatter, which is invariant.
private function DateTime.ToLocaleDateString( byval style as long ) as string
	dim as zstring * 256 buf
	if this.IsValid = false then return ""
	dim as long n = fb_DtLocaleDateString( this.m_ticks, style, @buf, 256 )
	if n <= 0 then return ""
	return left( buf, n )
end function

private function DateTime.ToLocaleTimeString( byval style as long ) as string
	dim as zstring * 256 buf
	if this.IsValid = false then return ""
	dim as long n = fb_DtLocaleTimeString( this.m_ticks, style, @buf, 256 )
	if n <= 0 then return ""
	return left( buf, n )
end function

private function DateTime.ToLocaleString( byval style as long ) as string
	dim as string d = this.ToLocaleDateString( style )
	dim as string t = this.ToLocaleTimeString( style )
	if len( d ) = 0 then return t
	if len( t ) = 0 then return d
	return d + " " + t
end function

private function DateTime.MonthName( byval mo as long, byval abbreviated as boolean ) as string
	dim as zstring * 128 buf
	dim as long n = fb_DtLocaleMonthName( mo, iif( abbreviated, 1, 0 ), @buf, 128 )
	if n <= 0 then return ""
	return left( buf, n )
end function

private function DateTime.WeekdayName( byval dow as long, byval abbreviated as boolean ) as string
	dim as zstring * 128 buf
	dim as long n = fb_DtLocaleWeekdayName( dow, iif( abbreviated, 1, 0 ), @buf, 128 )
	if n <= 0 then return ""
	return left( buf, n )
end function

'' -- interop converters (RFC-0007 section 4) ---------------------------
''
'' The bridge that lets existing code migrate one function at a time.  Every
'' one of these is a single addition (and at most one division), which is the
'' whole reason RFC-0001 chose this epoch and tick size.

private function Instant.FromUnixSeconds( byval v as longint ) as Instant
	if v > 2147483647000ll then return Instant.Invalid( )
	if v < -2147483647000ll then return Instant.Invalid( )
	return Instant( v * DT_TICKS_PER_SECOND + DT_TICKS_TO_UNIX_EPOCH )
end function
private function Instant.FromUnixMilliseconds( byval v as longint ) as Instant
	if v > 2147483647000000ll then return Instant.Invalid( )
	if v < -2147483647000000ll then return Instant.Invalid( )
	return Instant( v * DT_TICKS_PER_MILLISECOND + DT_TICKS_TO_UNIX_EPOCH )
end function
private function Instant.FromUnixMicroseconds( byval v as longint ) as Instant
	if v > 922337203685477ll then return Instant.Invalid( )
	if v < -922337203685477ll then return Instant.Invalid( )
	return Instant( v * DT_TICKS_PER_MICROSECOND + DT_TICKS_TO_UNIX_EPOCH )
end function

'' Floor toward minus infinity, NOT toward zero: pre-1970 instants must not
'' round the wrong way across the epoch.
private function dtFloorDiv( byval a as longint, byval b as longint ) as longint
	dim as longint q = a \ b
	if ( a mod b ) <> 0 then
		dim as boolean negA = ( a < 0 )
		dim as boolean negB = ( b < 0 )
		if negA <> negB then q -= 1
	end if
	return q
end function

private property Instant.UnixSeconds( ) as longint
	if this.IsValid = false then return DT_INVALID_TICKS
	return dtFloorDiv( this.m_ticks - DT_TICKS_TO_UNIX_EPOCH, DT_TICKS_PER_SECOND )
end property
private property Instant.UnixMilliseconds( ) as longint
	if this.IsValid = false then return DT_INVALID_TICKS
	return dtFloorDiv( this.m_ticks - DT_TICKS_TO_UNIX_EPOCH, DT_TICKS_PER_MILLISECOND )
end property
private property Instant.UnixMicroseconds( ) as longint
	if this.IsValid = false then return DT_INVALID_TICKS
	return dtFloorDiv( this.m_ticks - DT_TICKS_TO_UNIX_EPOCH, DT_TICKS_PER_MICROSECOND )
end property

private function DateTime.FromUnixSeconds( byval v as longint ) as DateTime
	dim as Instant i = Instant.FromUnixSeconds( v )
	if i.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromInstant( i, 0 )
end function
private function DateTime.FromUnixMilliseconds( byval v as longint ) as DateTime
	dim as Instant i = Instant.FromUnixMilliseconds( v )
	if i.IsValid = false then return DateTime.Invalid( )
	return DateTime.FromInstant( i, 0 )
end function
private property DateTime.UnixSeconds( ) as longint
	return this.AssumeUtc( ).UnixSeconds
end property
private property DateTime.UnixMilliseconds( ) as longint
	return this.AssumeUtc( ).UnixMilliseconds
end property
private property DateTime.UnixMicroseconds( ) as longint
	return this.AssumeUtc( ).UnixMicroseconds
end property

'' The migration pair.  datetime.bi's serial double shares the OLE epoch
'' (1899-12-30), so a program can adopt this API in one function while the rest
'' keeps using DateSerial and DateAdd.  LOSSY below about a millisecond: a
'' double has ~15 significant digits and present-day serials use most of them.
private function DateTime.FromSerial( byval d as double ) as DateTime
	dim as longint t = dtTicksFromDouble( d * DT_TICKS_PER_DAY )
	if t = DT_INVALID_TICKS then return DateTime.Invalid( )
	if dtAddOverflows( t, DT_TICKS_TO_OLE_EPOCH ) then return DateTime.Invalid( )
	return DateTime.FromTicks( t + DT_TICKS_TO_OLE_EPOCH, DT_OFFSET_UNSPECIFIED )
end function
private property DateTime.Serial( ) as double
	if this.IsValid = false then return 0
	return ( this.m_ticks - DT_TICKS_TO_OLE_EPOCH ) / DT_TICKS_PER_DAY
end property

'' Win32 FILETIME: 100 ns ticks since 1601-01-01.  Same unit as ours, so this
'' is pure addition -- no scaling, no rounding, nothing lost.
private function DateTime.FromFileTime( byval ft as longint ) as DateTime
	if ft < 0 then return DateTime.Invalid( )
	if dtAddOverflows( ft, DT_TICKS_TO_FILETIME ) then return DateTime.Invalid( )
	return DateTime.FromTicks( ft + DT_TICKS_TO_FILETIME, 0 )
end function
private property DateTime.FileTime( ) as longint
	if this.IsValid = false then return DT_INVALID_TICKS
	return this.AssumeUtc( ).Ticks - DT_TICKS_TO_FILETIME
end property

private function DateTime.FromOleDate( byval d as double ) as DateTime
	return DateTime.FromSerial( d )
end function
private property DateTime.OleDate( ) as double
	return this.Serial
end property


'' ============================================ USTRING overloads (phase 8)
''
'' Thin by construction.  The C layer already emits UTF-8 on both platforms,
'' and FreeBASIC decodes STRING -> USTRING as UTF-8 and encodes back the
'' same way, so each of these is a boundary conversion and nothing more.
''
'' ISO 8601 and the pattern formatter are ASCII by construction, so their
'' USTRING forms exist for uniformity rather than need.  The LOCALE family
'' is the one that matters -- month, weekday and zone names are routinely
'' non-ASCII -- and is why phase 8 waited for a frozen STRING surface.

private function DateTime.ToIsoUString( ) as ustring
	return this.ToIsoString( )
end function
private function Instant.ToIsoUString( ) as ustring
	return this.ToIsoString( )
end function
private function LocalDate.ToIsoUString( ) as ustring
	return this.ToIsoString( )
end function
private function LocalTime.ToIsoUString( ) as ustring
	return this.ToIsoString( )
end function
private function TimeSpan.ToIsoUString( ) as ustring
	return this.ToIsoString( )
end function

private function DateTime.ToString overload ( byref pattern as ustring ) as ustring
	dim as string p = pattern
	return this.ToString( p )
end function

private function DateTime.TryFormat overload ( byref pattern as ustring, byref result as ustring ) as boolean
	dim as string p = pattern
	dim as string r
	dim as boolean ok = this.TryFormat( p, r )
	result = r
	return ok
end function

private function DateTime.TryParseIso overload ( byref s as ustring, byref result as DateTime ) as boolean
	dim as string t = s
	return DateTime.TryParseIso( t, result )
end function
private function DateTime.TryParse overload ( byref s as ustring, byref result as DateTime ) as boolean
	dim as string t = s
	return DateTime.TryParseIso( t, result )
end function
private function DateTime.ParseIso overload ( byref s as ustring ) as DateTime
	dim as string t = s
	return DateTime.ParseIso( t )
end function
private function DateTime.TryParseExact overload ( byref s as ustring, byref pattern as ustring, byref result as DateTime ) as boolean
	dim as string t = s
	dim as string p = pattern
	return DateTime.TryParseExact( t, p, result )
end function
private function DateTime.ParseExact overload ( byref s as ustring, byref pattern as ustring ) as DateTime
	dim as string t = s
	dim as string p = pattern
	return DateTime.ParseExact( t, p )
end function

private function Instant.TryParseIso overload ( byref s as ustring, byref result as Instant ) as boolean
	dim as string t = s
	return Instant.TryParseIso( t, result )
end function
private function Instant.ParseIso overload ( byref s as ustring ) as Instant
	dim as string t = s
	return Instant.ParseIso( t )
end function

private function LocalDate.TryParseIso overload ( byref s as ustring, byref result as LocalDate ) as boolean
	dim as string t = s
	return LocalDate.TryParseIso( t, result )
end function
private function LocalDate.ParseIso overload ( byref s as ustring ) as LocalDate
	dim as string t = s
	return LocalDate.ParseIso( t )
end function

private function LocalTime.TryParseIso overload ( byref s as ustring, byref result as LocalTime ) as boolean
	dim as string t = s
	return LocalTime.TryParseIso( t, result )
end function
private function LocalTime.ParseIso overload ( byref s as ustring ) as LocalTime
	dim as string t = s
	return LocalTime.ParseIso( t )
end function

private function TimeSpan.TryParseIso overload ( byref s as ustring, byref result as TimeSpan ) as boolean
	dim as string t = s
	return TimeSpan.TryParseIso( t, result )
end function
private function TimeSpan.ParseIso overload ( byref s as ustring ) as TimeSpan
	dim as string t = s
	return TimeSpan.ParseIso( t )
end function

private function DateTime.ToLocaleDateUString( byval style as long ) as ustring
	return this.ToLocaleDateString( style )
end function
private function DateTime.ToLocaleTimeUString( byval style as long ) as ustring
	return this.ToLocaleTimeString( style )
end function
private function DateTime.ToLocaleUString( byval style as long ) as ustring
	return this.ToLocaleString( style )
end function
private function DateTime.MonthUName( byval mo as long, byval abbreviated as boolean ) as ustring
	return DateTime.MonthName( mo, abbreviated )
end function
private function DateTime.WeekdayUName( byval dow as long, byval abbreviated as boolean ) as ustring
	return DateTime.WeekdayName( dow, abbreviated )
end function

'' =================================================================== Clock
''
'' RFC-0003 section 2.  The wall clock: what time is it.  It CAN jump backwards
'' -- NTP corrections, DST, a user setting the clock -- so it is the wrong tool
'' for measuring elapsed time.  Use Stopwatch for that.
'' A namespace rather than a TYPE: FreeBASIC will not accept a TYPE with no
'' data members, and the call syntax Clock.UtcNow( ) is identical either way.
namespace Clock

private function UtcNow( ) as Instant
	return Instant( fb_DtClockUtcNow( ) )
end function

'' The offset is the one in force AT THIS INSTANT, and it is recorded in the
'' value -- so Clock.Now( ).ToInstant( ) round-trips even across a DST change.
private function Now( ) as DateTime
	dim as longint utc = fb_DtClockUtcNow( )
	if fb_DtIsValidTicks( utc ) = 0 then return DateTime.Invalid( )
	dim as short offMin = cshort( fb_DtClockLocalOffsetNow( ) )
	return DateTime.FromInstant( Instant( utc ), offMin )
end function

private function Today( ) as LocalDate
	return Now( ).GetDate( )
end function

private function TimeOfDay( ) as LocalTime
	return Now( ).GetTimeOfDay( )
end function

private function Resolution( ) as TimeSpan
	return TimeSpan( fb_DtClockResolution( ) )
end function

end namespace

'' =============================================================== Stopwatch
''
'' RFC-0003 section 3.  The monotonic clock: how long since.  Never jumps, so
'' unlike TIMER it stays correct across an NTP correction or a DST shift.
''
'' ACCUMULATES rather than recomputing from two stored timestamps, so
'' start/stop/start is correct with no special cases.  That is why Elapsed is a
'' property over an accumulator and not a subtraction of endpoints.
type Stopwatch
	m_elapsed as longint      '' ticks banked from completed segments
	m_started as longint      '' raw counter when the current segment began
	m_running as boolean

	declare constructor( )
	declare static function StartNew( ) as Stopwatch

	declare sub Start  ( )
	declare sub Stop_  ( )
	declare sub Reset  ( )
	declare sub Restart( )

	declare property IsRunning( ) as boolean
	declare property Elapsed  ( ) as TimeSpan
	declare property ElapsedMilliseconds( ) as longint
	declare property ElapsedTicks( ) as longint

	declare static function Frequency       ( ) as longint
	declare static function GetTimestamp    ( ) as longint
	declare static function IsHighResolution( ) as boolean
end type

private constructor Stopwatch( )
	this.m_elapsed = 0
	this.m_started = 0
	this.m_running = false
end constructor

private function Stopwatch.StartNew( ) as Stopwatch
	dim as Stopwatch s
	s.Start( )
	return s
end function

private sub Stopwatch.Start( )
	if this.m_running then exit sub            '' no-op when already running
	this.m_started = fb_DtMonoTimestamp( )
	this.m_running = true
end sub

'' Named Stop_ because STOP is a FreeBASIC statement keyword.
private sub Stopwatch.Stop_( )
	if this.m_running = false then exit sub    '' no-op when already stopped
	dim as longint counts = fb_DtMonoTimestamp( ) - this.m_started
	this.m_elapsed += fb_DtTicksFromCounts( counts, fb_DtMonoFrequency( ) )
	this.m_running = false
end sub

private sub Stopwatch.Reset( )
	this.m_elapsed = 0
	this.m_started = 0
	this.m_running = false
end sub

private sub Stopwatch.Restart( )
	this.m_elapsed = 0
	this.m_started = fb_DtMonoTimestamp( )
	this.m_running = true
end sub

private property Stopwatch.IsRunning( ) as boolean
	return this.m_running
end property

private property Stopwatch.ElapsedTicks( ) as longint
	dim as longint total = this.m_elapsed
	if this.m_running then
		dim as longint counts = fb_DtMonoTimestamp( ) - this.m_started
		total += fb_DtTicksFromCounts( counts, fb_DtMonoFrequency( ) )
	end if
	return total
end property

private property Stopwatch.Elapsed( ) as TimeSpan
	return TimeSpan( this.ElapsedTicks )
end property

private property Stopwatch.ElapsedMilliseconds( ) as longint
	return this.ElapsedTicks \ DT_TICKS_PER_MILLISECOND
end property

private function Stopwatch.Frequency( ) as longint
	return fb_DtMonoFrequency( )
end function
private function Stopwatch.GetTimestamp( ) as longint
	return fb_DtMonoTimestamp( )
end function
private function Stopwatch.IsHighResolution( ) as boolean
	return fb_DtMonoIsHighRes( ) <> 0
end function

'' ================================================================ CpuClock
''
'' RFC-0003 section 4.  How much CPU this process or thread has consumed --
'' which a SLEEP does not advance, and that is the whole point.
'' A namespace, for the same reason as Clock above.
namespace CpuClock

private function ProcessTime( ) as TimeSpan
	dim as longint u, k
	if fb_DtCpuProcessTime( @u, @k ) <> 0 then return TimeSpan.Invalid( )
	if k < 0 then return TimeSpan( u )
	return TimeSpan( u + k )
end function

private function ProcessUserTime( ) as TimeSpan
	dim as longint u, k
	if fb_DtCpuProcessTime( @u, @k ) <> 0 then return TimeSpan.Invalid( )
	return TimeSpan( u )
end function

private function ProcessKernelTime( ) as TimeSpan
	dim as longint u, k
	if fb_DtCpuProcessTime( @u, @k ) <> 0 then return TimeSpan.Invalid( )
	'' -1 means the platform does not split user from kernel here
	if k < 0 then return TimeSpan.Invalid( )
	return TimeSpan( k )
end function

private function ThreadTime( ) as TimeSpan
	dim as longint u, k
	if fb_DtCpuThreadTime( @u, @k ) <> 0 then return TimeSpan.Invalid( )
	if k < 0 then return TimeSpan( u )
	return TimeSpan( u + k )
end function

private function IsSupported( ) as boolean
	return fb_DtCpuIsSupported( ) <> 0
end function

end namespace

end namespace
