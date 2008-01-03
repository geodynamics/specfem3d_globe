
! open-source subroutines taken from the World Ocean Circulation Experiment (WOCE)
! web site at http://www.coaps.fsu.edu/woce/html/wcdtools.htm

! converted to Fortran90 by Dimitri Komatitsch,
! University of Pau, France, January 2008.
! Also converted "convtime" from a function to a subroutine.

  subroutine convtime(timestamp,yr,mon,day,hr,min)

! Originally written by Shawn Smith (smith AT coaps.fsu.edu)
! Updated Spring 1999 for Y2K compliance by Anthony Arguez
! (anthony AT coaps.fsu.edu).

! This subroutine will convert a given year, month, day, hour, and
! minutes to a minutes from 01 Jan 1980 00:00 time stamp.

  implicit none

  integer, intent(out) :: timestamp

  integer, intent(in) :: yr,mon,day,hr,min

  integer :: year(1980:2020),month(12),leap_mon(12)

  integer ::  min_day,min_hr

  data year /0, 527040, 1052640, 1578240, 2103840, 2630880, 3156480, &
               3682080, 4207680, 4734720, 5260320, 5785920, 6311520, &
               6838560, 7364160, 7889760,  8415360, 8942400, 9468000, &
               9993600, 10519200, 11046240, 11571840, 12097440, &
              12623040, 13150080, 13675680, 14201280, 14726880, &
              15253920, 15779520, 16305120, 16830720, 17357760, &
              17883360, 18408960, 18934560, 19461600, 19987200, &
              20512800, 21038400/

  data month /0, 44640, 84960, 129600, 172800, 217440, 260640, &
              305280, 349920, 393120, 437760, 480960/

  data leap_mon /0, 44640, 86400, 131040, 174240, 218880, 262080, &
                 306720, 351360, 394560, 439200, 482400/

  data min_day, min_hr /1440, 60/

! Test values to see if they fit valid ranges
  if (yr < 1980 .or. yr > 2020) stop 'Error in convtime: year out of range (1980-2020)'

  if (mon < 1 .or. mon > 12) stop 'Error in convtime: month out of range (1-12)'

  if (mon == 2) then
   if ((mod(yr,4) == 0).and.(day < 1 .or. day > 29)) then
      stop 'Error in convtime: Feb. day out of range (1-29)'
   elseif ((mod(yr,4) /= 0).and.(day < 1 .or. day > 28)) then
      stop 'Error in convtime: Feb. day out of range (1-28)'
   endif
  elseif ((mon == 4) .or. (mon == 6) .or. (mon == 9) .or. (mon == 11)) then
   if (day < 1 .or. day > 30) stop 'Error in convtime: day out of range (1-30)'
  else
   if (day < 1 .or. day > 31) stop 'Error in convtime: day out of range (1-31)'
  endif

  if (hr < 0 .or. hr > 23) stop 'Error in convtime: hour out of range (0-23)'

  if (min < 0 .or. min > 60) stop 'Error in convtime: minute out of range (0-60)'

! convert time
!! DK DK beware here, the test for the leap year is not complete here,
!! DK DK should check if multiple of 4 but not 100, except if multiple of 400,
!! DK DK but works fine because this does not happen between 1980 and 2020
  if (mod(yr,4) == 0) then
   timestamp = year(yr)+leap_mon(mon)+((day-1)*min_day)+(hr*min_hr)+min
  else
   timestamp = year(yr)+month(mon)+((day-1)*min_day)+(hr*min_hr)+min
  endif

  end subroutine convtime

!
!----
!

  subroutine invtime(timestamp,yr,mon,day,hr,min)

! This subroutine will convert a minutes timestamp to a year/month
! date. Based on the function convtime by Shawn Smith (COAPS).
!
! Written the spring of 1995, several iterations.
! James N. Stricherz (stricherz AT coaps.fsu.edu)
!
! Updated for Y2K compliance in July 1999.
! Shyam Lakshmin (lakshmin AT coaps.fsu.edu)
!
! This code returns correct results for the range of 01 Jan 1980 00:00
! thru 31 Dec 2020 23:59. I know it does, because I tried each minute
! of that range.

  implicit none

  integer, intent(in) :: timestamp

  integer, intent(out) :: yr,mon,day,hr,min

  integer :: year(1980:2021),month(13),leap_mon(13)

  integer :: min_day,min_hr,itime,tmon,ttime,thour,iyr,imon,iday,ihour

  data year /0, 527040, 1052640, 1578240, 2103840, 2630880, 3156480, &
               3682080, 4207680, 4734720, 5260320, 5785920, 6311520, &
               6838560, 7364160, 7889760, 8415360, 8942400, 9468000, &
               9993600, 10519200, 11046240, 11571840, 12097440, &
              12623040, 13150080, 13675680, 14201280, 14726880, &
              15253920, 15779520, 16305120, 16830720, 17357760, &
              17883360, 18408960, 18934560, 19461600, 19987200, &
              20512800, 21038400, 21565440/

  data month /0,  44640, 84960, 129600, 172800, 217440, 260640, &
            305280, 349920, 393120, 437760, 480960,525600/

  data leap_mon /0,  44640,  86400, 131040, 174240, 218880, 262080, &
            306720, 351360, 394560, 439200, 482400,527040/

  data min_day, min_hr /1440, 60/

!     ok, let us invert the effects of the years -- subtract off the
!     number of minutes per year until it goes negative
!     iyr then gives the year that the time (in minutes) occurs...
  if (timestamp >= year(2021)) then
   yr=-9999
   return
  endif

  iyr=1979
  itime=timestamp

 10   iyr=iyr+1
  ttime=itime-year(iyr)
  if (ttime <= 0) then
   if (iyr == 1980) iyr=iyr+1
   iyr=iyr-1
   itime=itime-year(iyr)
  else
   goto 10
  endif

!     assign the return variable
  yr=iyr

!     ok, the remaining time is less than one full year, so convert
!     by the same method as above into months:
  imon=0

!     if leap month
!! DK DK beware here, the test for the leap year is not complete here,
!! DK DK should check if multiple of 4 but not 100, except if multiple of 400,
!! DK DK but works fine because this does not happen between 1980 and 2020
  if (mod(iyr,4) /= 0) then

!     increment the month, and subtract off the minutes from the
!     remaining time for a non-leap year
 20      imon=imon+1
   tmon=itime-month(imon)
   if (tmon > 0) then
      goto 20
   else if (tmon < 0) then
      imon=imon-1
      itime=itime-month(imon)
   else
      if (imon > 12) then
         imon=imon-12
         yr=yr+1
      endif
      mon=imon
      day=1
      hr=0
      min=0
      return
   endif
  else

!     same thing, same code, but for a leap year
 30      imon=imon+1
   tmon=itime-leap_mon(imon)
   if (tmon > 0) then
      goto 30
   elseif (tmon < 0) then
      imon=imon-1
      itime=itime-month(imon)
   else
      if (imon > 12) then
         imon=imon-12
         yr=yr+1
      endif
      mon=imon
      day=1
      hr=0
      min=0
      return
   endif
  endif

!     assign the return variable
  mon=imon

!     any remaining minutes will belong to day/hour/minutes
!     ok, let's get those pesky days!
  iday=0
 40   iday=iday+1
  ttime=itime-min_day
  if (ttime >= 0) then
   itime=ttime
   goto 40
  endif

!     assign the return variable
  if (mod(iyr,4) == 0 .and. mon > 2) then
   day=iday-1
  else
   day=iday
  endif

!     pick off the hours of the days...remember, hours can be 0,
!     so we start at -1
  ihour=-1
 50   ihour=ihour+1
  thour=itime-min_hr
  if (thour >= 0) then
   itime=thour
   goto 50
  endif

!     assign the return variables
  hr=ihour

!     the remainder at this point is the minutes, so return them directly!
  min=itime

  end subroutine invtime

