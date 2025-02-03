SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
-----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'fnLocal_DDSStartEndTime',
		@Inputs		= 1,
		@Version	= '2.3'

SELECT @AppId = MAX(App_Id) + 1 
		FROM dbo.AppVersions

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
IF (SELECT COUNT(*) 
		FROM dbo.AppVersions 
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version 
		WHERE app_name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_Id,
		App_name,
		App_version)
	VALUES (
		@AppId, 
		@SP_Name,
		@Version)
END

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-----------------------------------------------------------------------------------------------------------------------
-- Drop Stored Function
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (
			SELECT * FROM dbo.sysobjects 
				WHERE name = 'fnLocal_DDSStartEndTime'
			)
DROP function [dbo].[fnLocal_DDSStartEndTime]
-----------------------------------------------------------------------------------------------------------------------
GO


--------------------------------------------------------------------------------------------------
-- Local Function: fnLocal_DDSStartEndTime
--------------------------------------------------------------------------------------------------
-- Author				: Fernando Rio - Arido Software
-- Date created			: 2012-4-19
-- Version 				: 1.6
-- Description			: This local function calculates the Start Time and End Time for a given 
--						  timeOption.
-- Editor tab spacing	: 4 
--------------------------------------------------------------------------------------------------
--select * from fnLocal_DDSStartEndTime('LastWeek')
--------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
--------------------------------------------------------------------------------------------------
-- ========		====	  		====					=====
-- 1.0			2012-04-09		Juan Pisani				Initial Release
-- 1.1			2012-5-14		Fernando Rio			Added Line ID parameter
-- 1.2			2012-05-20		Fernando Rio			Line id parameter removed.  
--														Added more time options to meet the requirements of Downtimes Report
-- 1.3			2012-07-03		Fernando Rio			Fixed 'Last Week' option & moved variable lookups to equipment model properties.
-- 1.4			2012-06-03		Fernando Rio			Added some exception handling for the time option selection
-- 1.5			2012-08-23		Mike Thomas				Fixed 'Week to Date' time option to give it the correct start time.
-- 1.6			2012-09-10		Pablo Galanzini			Time option 'Today' end time < start time when run earlier than 06:00
-- 1.7			2013-06-18		Mike Thomas				Fixed issue with grabbing an empty value from the 'Site Common Element' class
-- 1.8			2013-08-09		Mike Thomas				Added GRANT Statement
-- 1.9			2013-12-09		Mike Thomas				Sync version number with VM
-- 1.10			2014-02-11		Martin Casalis			Fixed calculations when Current Time is between Day Start Time and Production
--														Start Time
-- 2.0			2014-03-21		Mike Thomas				Fixed appversion update and updated version number
-- 2.1			2014-04-1		Fernando Rio			On the first day of the month for MonthToDate option if the actualdate < monthtodate starttime then
--														month to date starttime. 
-- 2.2			2014-04-3		Fernando Rio			Added last 7 days time option
-- 2.3			2014-05-22		Martin Casalis			Fixed time option MonthToDate when the actual time for first day of the month < production day start.
-- 2.4			2015-06-26		Martin Casalis			FO-02211: For all DMO project reports remove the database reference from all code
-- 1.1			2015-11-09		Fran Osorno				new location
-- 1.2			2016-09-19		Martin Casalis			New time option: Last 3 Shifts
-- 2.0			2016-11-21		Martin Casalis			FO-02593: HTML5 reports to support aspected and non aspected databases
-- 2.1			2017-01-04		Daniela Giraudi			Removed use of aspecting tempory solutipon for PA5 
-- 2.1			2018-05-30		Santiago Gimenez		Corrected Week to Date.
-- 2.2			2018-07-13		Santiago Gimenez		Corrected Last Week.
-- 2.3			2018-07-13     	Gonzalo Luc				Added Last30Days and Last3Months options
--================================================================================================
CREATE FUNCTION [dbo].[fnLocal_DDSStartEndTime] (
--DECLARE 
		@strRptTimeOption  nvarchar(100)
) RETURNS 
--DECLARE 
		@tblTimeWindows TABLE (
		dtmStartTime				DATETIME,
		dtmEndTime					DATETIME)
		
--WITH ENCRYPTION		
AS 
BEGIN

---------------------------------------------------------------------------------------------------------------
-- Test Statements
 --SELECT @strRptTimeOption = 'lastweek'
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-- Store Procedure Variables
-- Output Time Options
DECLARE
		@lastShiftStartTime				DATETIME,
		@lastShiftEndTime				DATETIME,
		@dayStartTime					DATETIME,		
		@dayEndTime						DATETIME,
		@wtdStartTime					DATETIME,
		@wtdEndTime						DATETIME,
		@mtdStartTime					DATETIME,
		@mtdEndTime						DATETIME
		
DECLARE
        @strRptStartDate                as         datetime,			 -- 
        @strRptEndDate                  as         datetime,
        @intRptShiftLength              as         int,                  -- Shift length from Local_PG_ShiftLength
		@dateRptShiftStartTime          as         datetime,             -- Start time of the shift from Local_PG_StartShift
		@in_strRptStartDate             as         datetime,             -- Report StartDate parameter
		@in_strRptEndDate               as         datetime,             -- Report EndDate parameter
	    @actual_Time                    as         datetime,
        @production_day_start           as         datetime,
        @calendar_day_start             as         datetime,
        @1st_day_production_month       as         datetime,
        @production_day_12PM            as         datetime,
		@1st_day_calendar_month			as		   datetime,
		@1st_day_ofweek					as		   INT,
		@shift_offsetFromMidnight		as		   int	,
		@shift_Interval					as		   int	,
		@dtmDinColStartTime						   DATETIME,
		@dtmDinColEndTime						   DATETIME,
		@timeProdDayStart				NVARCHAR(12),
		@firstBow						DATETIME				,
		@EndOfWeek						DATETIME	,
		@BegOfDayMi						INT,
		@BegOfDayHr						INT



---------------------------------------------------------------------------------------------------------------
-- Function Temporary Tables
DECLARE  @Temp_Shifts Table
(rec_no              int,
StartTime            datetime,
EndTime              datetime)

DECLARE @TempLastShifts TABLE
			(StartTime            DATETIME,
			 EndTime              DATETIME)			
---------------------------------------------------------------------------------------------------------
-- Format the @dateRptShiftStartTime from HH:MM:SS to 1/1/1999 HH:MM:SS 
---------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Get the UseProficyClient parameter
---------------------------------------------------------------------------------------------------
--SET		@UseProficyClient	= 0

--SELECT	@UseProficyClient  = ISNULL(sp.Value,0)
--FROM	dbo.Site_Parameters sp	WITH(NOLOCK)
--JOIN	dbo.Parameters		p	WITH(NOLOCK) ON p.Parm_Id = sp.Parm_Id
--WHERE	p.Parm_Name = 'UseProficyClient'

---------------------------------------------------------------------------------------------------------
-- Get the first day of the week based on SOA Properties
---------------------------------------------------------------------------------------------------------
--IF @UseProficyClient = 1
--BEGIN
--		SELECT @1st_day_ofweek = (CASE Value WHEN 'Monday' THEN 2
--											 WHEN 'Tuesday' THEN 3 
--											 WHEN 'Wednesday' THEN 4
--											 WHEN 'Thursday' THEN 5
--											 WHEN 'Friday' THEN 6
--											 WHEN 'Saturday' THEN 7
--											 WHEN 'Sunday' THEN 1
--									END)
--		FROM  dbo.Property_Equipment_EquipmentClass WITH(NOLOCK)
--		WHERE Name = 'PGStartOfWeek' AND Class = 'Site Common Element'
--		AND IsValueOverridden = 1

--		SELECT @timeProdDayStart = CONVERT(NVARCHAR(10),Value) 
--		FROM  dbo.Property_Equipment_EquipmentClass WITH(NOLOCK)
--		WHERE Name = 'PGDayStart' AND Class = 'Site Common Element'
--		AND IsValueOverridden = 1
--END
--ELSE
--BEGIN

		SELECT @BegOfDayMi = value 
		FROM dbo.Site_Parameters sp
		JOIN dbo.Parameters p ON p.parm_id = sp.parm_id
		WHERE p.parm_name LIKE '%EndOfDayMin%'

		SELECT @BegOfDayHr = value 
		FROM dbo.Site_Parameters sp
		JOIN dbo.Parameters p ON p.parm_id = sp.parm_id
		WHERE p.parm_name LIKE '%EndOfDayHour%'

		SELECT @1st_day_ofweek = CONVERT(NVARCHAR(10),Value) 	
		FROM dbo.Site_Parameters sp
		JOIN dbo.Parameters p ON p.parm_id = sp.parm_id
		WHERE p.parm_name LIKE '%EndOfWeek%'

		SELECT @timeProdDayStart = value FROM dbo.Site_Parameters sp
		JOIN dbo.Parameters p ON p.parm_id = sp.parm_id
		WHERE p.parm_name LIKE '%EndOfDayHour%'

		SELECT @timeProdDayStart = @timeProdDayStart + ':' + value 
		FROM dbo.Site_Parameters sp
		JOIN dbo.Parameters p ON p.parm_id = sp.parm_id
		WHERE p.parm_name LIKE '%EndOfDayMin%'
--END

SELECT @shift_offsetFromMidnight = value FROM dbo.Site_Parameters sp WITH(NOLOCK)
JOIN dbo.Parameters p WITH(NOLOCK) on sp.Parm_Id = p.Parm_Id 
WHERE parm_name like 'ShiftOffset'

SELECT @shift_Interval = value FROM dbo.Site_Parameters sp WITH(NOLOCK)
JOIN dbo.Parameters p WITH(NOLOCK) on sp.Parm_Id = p.Parm_Id 
WHERE parm_name like 'ShiftInterval'


---------------------------------------------------------------------------------------------------------
-- Set variables that will help on date calculations
---------------------------------------------------------------------------------------------------------
SET         @actual_time                 =		GetDate()
SET         @production_day_start        =		Convert(datetime,Left(Convert(varchar,@actual_time),12) + ' ' + Right(Convert(varchar,@timeProdDayStart),8))

-- If Actual Time is lower than Production Day Start then get the previous day
IF (@actual_Time < @production_day_start)
BEGIN
	SELECT	@production_day_start = DateAdd(d, -1, @production_day_start)
END

SET         @calendar_day_start          =		Convert(datetime,Left(Convert(varchar,@actual_time),12) + ' ' + '00:00:00 AM')
SET         @1st_day_production_month    =		Convert(datetime,Convert(varchar,Month(@actual_time))+'/1/'+Convert(varchar,Year(GetDate())) + ' ' + Right(Convert(varchar,@production_day_start),8))
SET         @1st_day_calendar_month    	 =		Convert(datetime,Convert(varchar,Month(@actual_time))+'/1/'+Convert(varchar,Year(GetDate())) + ' ' + '00:00:00 AM')
SET         @production_day_12PM         =		Convert(datetime,Left(Convert(varchar,@actual_time),12) + ' ' + '12:00:00 AM')


SELECT @dateRptShiftStartTime = @production_day_start -- DATEADD(mi,@shift_offsetFromMidnight, Convert(datetime,Left(Convert(varchar,GETDATE()),12) + ' ' + '00:00:00 AM'))

---------------------------------------------------------------------------------------------------------
-- Variables Testing
---------------------------------------------------------------------------------------------------------
 --print '@actual_time                 ----------> '+ Convert(varchar,@actual_time)
 --print '@production_day_start        ----------> '+ Convert(varchar,@production_day_start)
 --print '@calendar_day_start          ----------> '+ Convert(varchar,@calendar_day_start)
 --print '@1st_day_production_month    ----------> '+ Convert(varchar,@1st_day_production_month)
 --print '@production_day_12PM         ----------> '+ Convert(varchar,@production_day_12PM)
---------------------------------------------------------------------------------------------------------
-- BUILD A TEMPORARY TABLE TO HOLD LAST 40 SHIFTS
---------------------------------------------------------------------------------------------------------
DECLARE     
        @i_shift         as         int,
        @s_startTime     as         datetime,
        @s_endTime       as         datetime

SET @i_shift       = 1
SET @s_startTime   = DATEADD(dd,1,@dateRptShiftStartTime) -- Dateadd(dd,1,@production_day_start)
SET @s_endTime     = DATEADD(mi,@shift_Interval,@s_startTime)

WHILE @i_shift <= 100
BEGIN
    
    INSERT INTO @Temp_Shifts(rec_no,StartTime,EndTime)
    VALUES(@i_shift,@s_startTime,@s_endTime)

    SET @i_shift = @i_shift + 1
    SET @s_endTime = @s_startTime
    SET @s_startTime = dateadd(mi,-1 * @shift_Interval,@s_endTime)

End

--------------------------------------------------------------------------------------------------
-- END BUILD TABLE
--------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- Fill Last Shift Values
------------------------------------------------------------------------------------------------
SELECT @lastShiftStartTime = StartTime, @lastShiftEndTime = EndTime  
FROM @Temp_Shifts WHERE EndTime =
(SELECT StartTime 
	FROM @Temp_Shifts
WHERE @actual_time >= StartTime and @actual_time < EndTime)
		   
------------------------------------------------------------------------------------------------
-- Fill Yesterday Values
------------------------------------------------------------------------------------------------ 		   
SET @strRptStartDate = dateadd(dd,-1,@production_day_start)
If @strRptStartDate > @actual_time 
   SET @strRptStartDate = DateAdd(d, -1, @strRptStartDate)

SET @strRptEndDate = @production_day_start
		   
SELECT  @dayStartTime = @strRptStartDate,
		@dayEndTime	= @strRptEndDate

------------------------------------------------------------------------------------------------
-- Fill	MTD Values
------------------------------------------------------------------------------------------------   
If (Day(@actual_time) = 1 And @actual_time < @1st_day_production_month) 
Begin
				
	SET @strRptEndDate = @actual_time
	SET @strRptStartDate = DateAdd(mm, -1, @1st_day_production_month)
    --SET @strRptEndDate = @production_day_start    
                
End
Else
Begin
    SET @strRptStartDate = @1st_day_production_month        
    SET @strRptEndDate = @production_day_start
End

SELECT 	@mtdStartTime	=		@strRptStartDate,
		@mtdEndTime		=		@strRptEndDate

------------------------------------------------------------------------------------------------
-- Week to date values
------------------------------------------------------------------------------------------------         	

SELECT @firstBow = convert(datetime,-53690+((@1st_day_ofweek+5)%7))
					
SELECT	-- Start of the Week
		@wtdStartTime =	DATEADD(dd, (DATEDIFF(dd,@firstBow,@actual_Time)/7)*7, @firstBow)+ @timeProdDayStart,
		-- End of yesterday production day
		@wtdEndTime =	@dayEndTime	

IF (@wtdEndTime <= @wtdStartTime)
BEGIN
	SELECT @wtdStartTime = DATEADD(dd,-7,@wtdStartTime)
END 

------------------------------------------------------------------------------------------------
-- 'LastShift'
------------------------------------------------------------------------------------------------      								
If (Upper(@strRptTimeOption) = 'LastShift') 
Begin						
		   SELECT	@dtmDinColStartTime = @lastShiftStartTime,
					@dtmDinColEndTime = @lastShiftEndTime		
				
		       
End
                             
------------------------------------------------------------------------------------------------
-- 'CurrentShift'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'CurrentShift' 
Begin
		 		   SELECT	@dtmDinColStartTime = @lastShiftEndTime	,
					@dtmDinColEndTime = @actual_time	
					
End

------------------------------------------------------------------------------------------------
-- 'Last2Shifts'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last2Shifts' 
Begin
		   INSERT INTO @TempLastShifts
			(StartTime          ,
			 EndTime		)
		   SELECT Top 2 StartTime,
						EndTime 
		   FROM @Temp_Shifts WHERE EndTime <= @actual_Time 
		   ORDER BY EndTime DESC   
		   
		   SELECT	@dtmDinColStartTime = MIN(StartTime)	,
					@dtmDinColEndTime = MAX(EndTime)	
		   FROM @TempLastShifts	
					
End

------------------------------------------------------------------------------------------------
-- 'Last3Shifts'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last3Shifts' 
Begin
		   INSERT INTO @TempLastShifts
			(StartTime          ,
			 EndTime		)
		   SELECT Top 3 StartTime,
						EndTime 
		   FROM @Temp_Shifts WHERE EndTime <= @actual_Time 
		   ORDER BY EndTime DESC   
		   
		   SELECT	@dtmDinColStartTime = MIN(StartTime)	,
					@dtmDinColEndTime = MAX(EndTime)	
		   FROM @TempLastShifts	
					
End

------------------------------------------------------------------------------------------------
-- 'Last2Days'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last2Days' 
Begin
		  
			SELECT  @dtmDinColStartTime = DATEADD(dd,-1,@dayStartTime),
					@dtmDinColEndTime = @dayEndTime	
		   			
End

------------------------------------------------------------------------------------------------
-- 'Today'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Today' 
Begin
			SELECT  @dtmDinColStartTime = @dayEndTime,
					@dtmDinColEndTime = @actual_time
	-- Check if (end time < start time) when run earlier than 06:00
	IF @dtmDinColEndTime < @dtmDinColStartTime
	BEGIN
--		SELECT 'LESS MORE', @dtmDinColEndTime, @dtmDinColStartTime
		SET @dtmDinColStartTime = DATEADD(D, -1, @dtmDinColStartTime)
	END

End
------------------------------------------------------------------------------------------------
-- 'Last3Days'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last3Days' 
Begin
		  
			SELECT  @dtmDinColStartTime = DATEADD(dd,-2,@dayStartTime),
					@dtmDinColEndTime = @dayEndTime	
		   			
End

------------------------------------------------------------------------------------------------
-- 'Last7Days'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last7Days' 
Begin
		  
			SELECT  @dtmDinColStartTime = DATEADD(dd,-6,@dayStartTime),
					@dtmDinColEndTime = @dayEndTime	
		   			
End
------------------------------------------------------------------------------------------------
-- 'Last30Days'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last30Days' 
Begin
		  
			SELECT  @dtmDinColStartTime = DATEADD(dd,-29,@dayStartTime),
					@dtmDinColEndTime = @dayEndTime	
		   			
End
------------------------------------------------------------------------------------------------
-- 'Yesterday'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Yesterday' 
Begin
		  
			SELECT  @dtmDinColStartTime = @dayStartTime,
					@dtmDinColEndTime =@dayEndTime	
		   			
End
------------------------------------------------------------------------------------------------
-- 'Last24Hours'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last24Hours' 
Begin
		  
			SELECT  @dtmDinColStartTime = DATEADD(hh,-24,@actual_time),
					@dtmDinColEndTime = @actual_time
		   			
End
------------------------------------------------------------------------------------------------
-- 'Last3Hours'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last3Hours' 
Begin
		  
			SELECT  @dtmDinColStartTime = DATEADD(hh,-3,@actual_time),
					@dtmDinColEndTime = @actual_time	
		   			
End
------------------------------------------------------------------------------------------------
-- 'LastWeek'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'LastWeek' 
Begin

					 
					------------------------------------------------------------------------------------------------
					-- Last Week values
					------------------------------------------------------------------------------------------------         	
					SELECT	
							-- End of last week.
							@wtdEndTime = CONVERT(DATE,DATEADD(dd, 7-(DATEPART(dw, @actual_time)), DATEADD(dd,-7,@actual_time))),
							-- Start of last Week
							@wtdStartTime	= DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,CONVERT(DATETIME,CONVERT(DATE,DATEADD(dd,-@1st_day_ofweek,@wtdEndTime)))))
						
		 					
		 			SELECT  @dtmDinColStartTime	 = @wtdStartTime ,
		 					@dtmDinColEndTime = DATEADD(dd,1,DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,@wtdEndTime)))
End

------------------------------------------------------------------------------------------------
-- 'WeekToDate'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'WeekToDate' 
Begin
--SG   
					SELECT @EndOfWeek = CONVERT(DATE,DATEADD(dd, 7-(DATEPART(dw, @actual_time)), @actual_time))
					SELECT @wtdStartTime = DATEADD(dd,-@1st_day_ofweek,@EndOfWeek)
					SELECT @wtdStartTime = @wtdStartTime + ' ' + @timeProdDayStart
					
		 ----------------------------------------------------------------------------------------
		 			SELECT  @dtmDinColStartTime = @wtdStartTime,
							@dtmDinColEndTime = @actual_time
		   			
End
------------------------------------------------------------------------------------------------
-- 'LastMonth'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'LastMonth' 
Begin
		  	SELECT  @dtmDinColStartTime = DATEADD(mm,-1,@mtdStartTime),
					@dtmDinColEndTime = @mtdStartTime 
		   			
End
------------------------------------------------------------------------------------------------
-- 'MonthToDate'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'MonthToDate' 
Begin
		  	SELECT  @dtmDinColStartTime = @mtdStartTime,
					@dtmDinColEndTime = (CASE WHEN @actual_time < @mtdStartTime THEN @mtdStartTime ELSE @actual_time END)
		   			
End
------------------------------------------------------------------------------------------------
-- 'Last3Months'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'Last3Months' 
Begin
		  	SELECT  @dtmDinColStartTime = DATEADD(mm,-3,@mtdStartTime),
					@dtmDinColEndTime = @mtdStartTime
		   			
End
------------------------------------------------------------------------------------------------
-- 'UserDefined'
------------------------------------------------------------------------------------------------      								
If Upper(@strRptTimeOption) = 'UserDefined' 
Begin
		  	SELECT  @dtmDinColStartTime = @actual_time,
					@dtmDinColEndTime = @actual_time
		   			
End

IF (LEN(@strRptTimeOption) > 0)
BEGIN 
	INSERT INTO @tblTimeWindows (
					dtmStartTime				,
					dtmEndTime					)
	SELECT			@dtmDinColStartTime			,
					@dtmDinColEndTime		
END

--SELECT * FROM @tblTimeWindows		
RETURN
END

------------------------------------------------------------------------------------------------

--==============================================================================================

GO
GRANT SELECT ON [dbo].[fnLocal_DDSStartEndTime] TO SSRSDDSUser AS [dbo]
GRANT SELECT ON [dbo].[fnLocal_DDSStartEndTime] TO ComXClient AS [dbo]
GO
