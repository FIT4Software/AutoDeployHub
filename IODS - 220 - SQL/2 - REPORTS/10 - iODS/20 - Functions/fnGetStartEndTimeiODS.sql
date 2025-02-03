USE [Auto_opsDataStore]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----------------------------------------------------------------------------------------------------------------------
-- DROP Function
----------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'fnGetStartEndTimeiODS' AND Routine_Type = 'FUNCTION')
BEGIN
	DROP FUNCTION [dbo].[fnGetStartEndTimeiODS]
END
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'fnGetStartEndTimeiODS',
		@Version	= '1.6'  


--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions 
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version,
			Modified_On = GETDATE() 
		WHERE app_name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_name,
		App_version,
		Modified_On )
	VALUES (
		@SP_Name,
		@Version,
		GETDATE())
END
GO
--====================================================================================================
------------------------------------------------------------------------------------------------------
-- Local Function: fnGetStartEndTimeiODS
------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-07-19
-- Version 				: 1.0
-- Description			: This local function calculates the Start Time and End Time for HTML5 Reports
-- Editor tab spacing	: 4 
-------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-------------------------------------------------------------------------------------------------------
-- ========		====	  		====					=====
-- 1.0			2018-07-19		Gonzalo Luc				Initial Release
-- 1.1			2018-08-21		Pablo Galanzini			Add DATE Option Today FO-3561 and fixed Yesterday
-- 1.2  		2019-06-25		Gonzalo Luc				Change MTD end time to the end time of last shift.		
-- 1.3  		2019-08-27		Campana Damian			Add Last Week time option.
-- 1.4			2019-09-30		Martin Casalis			Fixed previous month to change after production day starts		
-- 1.5			2020-01-16		Gonzalo Luc				Fix Previous month when calendar time is between 00 and shift start.
-- 1.6 			2020-04-17		Gonzalo Luc				Address time zone hour change.
--=====================================================================================================
CREATE FUNCTION [dbo].[fnGetStartEndTimeiODS] (
--DECLARE 
		@DateOption NVARCHAR(100),
		@LineId		NVARCHAR(250)
) RETURNS 
--DECLARE 
		@tblTimeWindows TABLE (
		dtmStartTime				DATETIME,
		dtmEndTime					DATETIME)


--WITH ENCRYPTION 
AS
BEGIN
--TEST DATA
--SET @DateOption = 'Last 30 Days'
--SET @LineId = '11'
--------------------------------------------------------------------------------------------------	
-- VARIABLES
--------------------------------------------------------------------------------------------------
DECLARE @ShiftStartTime NVarchar(7)
DECLARE @ShiftEndTime	NVarchar(7)
DECLARE @WeekStartTime	DATETIME
DECLARE @DATE			DATE
DECLARE @DATEStart		DATETIME
DECLARE @DATEEnd		DATETIME
DECLARE @Start_Shift	DATETIME
DECLARE @End_Shift		DATETIME
DECLARE @Start_Current	DATETIME
DECLARE @End_Current	DATETIME
DECLARE @GetDate		DATETIME

--------------------------------------------------------------------------------------------------

SET @GetDate = GETDATE()

SELECT	@ShiftEndTime=ShiftStartTime,
		@WeekStartTime = l.WeekStartTime 
	FROM dbo.Line_Dimension l WITH(NOLOCK) 
	WHERE l.PLId = @LineId 
	--Group By l.ShiftStartTime
    
SET @DATEEND = CONVERT(DATETIME,CONVERT(NVARCHAR(10),CONVERT(DATE,@GetDate)) + ' ' + @ShiftEndTime)

--I need to know the ProdDay where go to look the ShiftStartTime
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
SET  @DATE = CASE  @DateOption
		WHEN 'Last 3 Days'		THEN CASE WHEN @DATEEnd > @GetDate
										THEN DATEADD(dd,-4,convert(date,@DATEEnd))
										ELSE DATEADD(dd,-3,convert(date,@DATEEnd))
									END
		WHEN 'Yesterday'		THEN CASE WHEN @DATEEnd > @GetDate
										THEN DATEADD(dd,-2,convert(date,@DATEEnd))
										ELSE DATEADD(dd,-1,convert(date,@DATEEnd))
									END
		WHEN 'Last 7 Days'		THEN CASE WHEN @DATEEnd > @GetDate
										THEN DATEADD(dd,-8,convert(date,@DATEEnd))
										ELSE DATEADD(dd,-7,convert(date,@DATEEnd))
									END
		WHEN 'Last 30 Days'		THEN CASE WHEN @DATEEnd > @GetDate
										THEN DATEADD(dd,-31,convert(date,@DATEEnd))
										ELSE DATEADD(dd,-30,convert(date,@DATEEnd))
								END
        WHEN 'MTD'				THEN  CASE WHEN @DATEEnd > @GetDate
										THEN CONVERT(DATETIME, CONVERT(VARCHAR,MONTH(DATEADD(DD, -1, @DATEEnd))) + '/1/' + CONVERT(VARCHAR,YEAR(DATEADD(DD, -1, @DATEEnd))) )
										ELSE CONVERT(DATETIME, CONVERT(VARCHAR,MONTH(@DATEEnd)) + '/1/' + CONVERT(VARCHAR,YEAR(@DATEEnd)))
									END
		WHEN 'Previous MONTH'	THEN 
									CONVERT(datetime,CONVERT(varchar, dbo.daterelative(@DateOption,
										CASE WHEN @DATEEnd > @GetDate
											THEN DATEADD(DAY, -1, convert(date,@DATEEnd))
											ELSE convert(date,@DATEEnd)
										END
									))) 
		WHEN 'Past 3 MONTH'		THEN CASE WHEN @DATEEnd > @GetDate
										THEN DATEADD(MONTH,-3,DATEADD(DD, -1, convert(date,@DATEEnd)))
										ELSE DATEADD(MONTH,-3,convert(date,@DATEEnd))
								END
		END

----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
SELECT @ShiftStartTime = StartShift
FROM (    SELECT CAST(CAST(StartTime  AS VARCHAR(12)) AS DATE)AS ProdDay, PLId AS PLId, MIN(StartTime) AS StartTime , CONVERT(VARCHAR(8),MIN(StartTime),108) AS StartShift
        FROM Auto_opsDataStore.dbo.OpsDB_Production_Data
        WHERE  ShiftDesc = '1' AND StartTime >= DATEADD(mm,-3, CONVERT(date,getdate())) AND PLID=@LineId and deleteflag=0
        GROUP BY CAST(CAST(StartTime As VARCHAR(12)) AS DATE), PLId) AS s 
WHERE ProdDay = @DATE  

SET @ShiftStartTime=CASE  WHEN  @ShiftStartTime IS NULL THEN @ShiftEndTime  ELSE @ShiftStartTime END

SET @ShiftStartTime=CASE  WHEN  CONVERT(TIME,@ShiftEndTime ) >='12:00'  THEN @ShiftEndTime  ELSE @ShiftStartTime END

SET @DATEStart= CONVERT(DATETIME,CONVERT(NVARCHAR(10),CONVERT(DATE,@GetDate)) + ' ' + @ShiftStartTime)


SELECT @Start_Shift = ls.Starttime	
	FROM dbo.LastShift_Dimension	ls WITH(NOLOCK) 
	JOIN dbo.line_dimension			l  WITH(NOLOCK) ON ls.lineid = l.lineid 
	WHERE l.PLId = @LineId

SELECT @End_Shift = ls.Endtime	
	FROM (dbo.LastShift_Dimension	ls WITH(NOLOCK) 
	JOIN dbo.line_dimension			l WITH(NOLOCK) ON ls.lineid = l.lineid) 
	WHERE l.PLId = @LineId

SELECT @Start_Current = CASE WHEN CONVERT(DATETIME,CONVERT(NVARCHAR(10),@GetDate,121)+' '+CONVERT(VARCHAR(5),CONVERT(TIME,ls.endtime))) > @GETDATE
							THEN CONVERT(DATETIME,CONVERT(NVARCHAR(10),DATEADD(DAY, -1, @GetDate),121)+' '+CONVERT(VARCHAR(5),CONVERT(TIME,ls.endtime))) 
							ELSE CONVERT(DATETIME,CONVERT(NVARCHAR(10),@GetDate,121)+' '+CONVERT(VARCHAR(5),CONVERT(TIME,ls.endtime)))
						END
	FROM dbo.LastShift_Dimension ls WITH(NOLOCK) 
	JOIN dbo.line_dimension l WITH(NOLOCK) ON ls.lineid = l.lineid 
	WHERE l.PLId = @LineId

-----------------------------------------------------------------------------------------------------
-- Output
-----------------------------------------------------------------------------------------------------

INSERT INTO @tblTimeWindows (
					dtmStartTime		,
					dtmEndTime			)
			SELECT 
			CASE @DateOption 
				WHEN 'Today'			THEN CASE WHEN @DATEEnd > @GetDate
										THEN DATEADD(dd,-1,@DATEEnd)
										ELSE @DATEEnd
									END
				WHEN 'Last 3 Days'		THEN CASE WHEN @DATEStart > @GetDate
												THEN DATEADD(dd,-4,@DATEStart)
												ELSE DATEADD(dd,-3,@DATEStart)
											END
				WHEN 'Yesterday'		THEN CASE WHEN @DATEEnd > @GetDate
												THEN DATEADD(dd,-2,@DATEEnd)
												ELSE DATEADD(dd,-1,@DATEEnd)
											END
				WHEN 'Last 7 Days'		THEN CASE WHEN @DATEStart > @GetDate
												THEN DATEADD(dd,-8,@DATEStart)
												ELSE DATEADD(dd,-7,@DATEStart)
											END
				WHEN 'Last 30 Days'		THEN CASE WHEN @DATEStart > @GetDate
												THEN DATEADD(dd,-31,@DATEStart)
												ELSE DATEADD(dd,-30,@DATEStart)
											END
				WHEN 'MTD'				THEN  CASE WHEN @DATEStart > @GetDate
												THEN CONVERT(DATETIME, CONVERT(VARCHAR,MONTH(DATEADD(DD, -1, @DATEStart))) + '/1/' + CONVERT(VARCHAR,YEAR(DATEADD(DD, -1, @DATEStart))) + ' ' + @ShiftStartTime)
												ELSE CONVERT(DATETIME, CONVERT(VARCHAR,MONTH(@DATEStart)) + '/1/' + CONVERT(VARCHAR,YEAR(@DATEStart))+' '+@ShiftStartTime)
											END
				WHEN 'Previous MONTH'	THEN 
											CONVERT(datetime,CONVERT(varchar, dbo.daterelative(@DateOption,
												CASE WHEN @DATEStart > @GetDate
													THEN DATEADD(DAY, -1, @DATEStart)
													ELSE @DATEStart
												END
											))+' '+@ShiftStartTime) 
				WHEN 'Past 3 MONTH'		THEN CASE WHEN @DATEStart > @GetDate
												THEN DATEADD(MONTH,-3,DATEADD(DD, -1, @DATEStart))
												ELSE DATEADD(MONTH,-3,@DATEStart)
											END
				WHEN 'Last Shift'		THEN @Start_Shift
				WHEN 'Current Shift'	THEN @Start_Current
				WHEN 'Last Week'		THEN DATEADD(DAY,-7,@WeekStartTime)
			END As StartTime,
			CASE @DateOption 
				WHEN 'Today'			THEN @GetDate
				WHEN 'Last 3 Days'		THEN CASE WHEN @DATEEnd > @GetDate
												THEN DATEADD(dd,-1,@DATEEnd)
												ELSE @DATEEnd
											END
				WHEN 'Yesterday'		THEN CASE WHEN @DATE > @GetDate
												THEN DATEADD(dd,-1,@DATE)
												ELSE @DATEEnd
											END
				WHEN 'Last 7 Days'		THEN CASE WHEN @DATEEnd > @GetDate
												THEN DATEADD(dd,-1,@DATEEnd)
												ELSE @DATEEnd
											END
				WHEN 'Last 30 Days'		THEN CASE WHEN @DATEEnd > @GetDate
												THEN DATEADD(dd,-1,@DATEEnd)
												ELSE @DATEEnd
											END
				WHEN 'MTD'				THEN @End_Shift
				WHEN 'Previous MONTH'	THEN CASE WHEN @DATEEnd > @GetDate
												THEN CONVERT(DATETIME, CONVERT(NVARCHAR(10),CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(dd,-1,@DATEEnd)),0))) + ' ' + @ShiftEndTime)
												ELSE CONVERT(DATETIME, CONVERT(NVARCHAR(10),CONVERT(DATE,DATEADD(MONTH,DATEDIFF(MONTH,0,@DATEEnd),0))) + ' ' + @ShiftEndTime)
											END
				WHEN 'Past 3 MONTH'		THEN CASE WHEN @DATEEnd > @GetDate
												THEN DATEADD(DD,-1,@DATEEnd)
												ELSE @DATEEnd
											END
				WHEN 'Last Shift'		THEN @End_Shift
				WHEN 'Current Shift'	THEN @GetDate
				WHEN 'Last Week'		THEN @WeekStartTime	
			END As EndTime
--SELECT * FROM @tblTimeWindows		
RETURN
END
GO
GRANT SELECT ON [dbo].[fnGetStartEndTimeiODS] TO OpDBWriter
GO
