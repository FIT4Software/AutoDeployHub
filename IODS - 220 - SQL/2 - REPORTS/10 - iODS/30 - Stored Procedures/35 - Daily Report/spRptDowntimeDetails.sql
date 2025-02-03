use Auto_opsDataStore
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spRptDowntimeDetails',
		@Inputs		= 7, 
		@Version	= '1.4'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions 
		WHERE App_Name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version,
			Modified_On = GETDATE() 
		WHERE App_Name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_Name,
		App_version,
		Modified_On )
	VALUES (	
		@SP_Name,
		@Version,
		GETDATE())
END
--===================================================================================================================== 
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
			FROM	Information_schema.Routines
			WHERE	Specific_schema = 'dbo'
				AND	Specific_Name = @SP_Name
				AND	Routine_Type = 'PROCEDURE' )
				
DROP PROCEDURE [dbo].[spRptDowntimeDetails]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptDowntimeDetails
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-08-02
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides Downtime Details data.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-08-02		Gonzalo Luc     		Initial Release
-- 1.1		2019-08-02		Federico Vicente		Add ReportTime and ScheduleTime
-- 1.2		2019-10-04		Gonzalo Luc				Added User Defined time option.
-- 1.3		2019-10-14		Gonzalo Luc				Added Planned DT and Unplanned DT to details grid for in grid calc
-- 1.4		2019-12-20		Gonzalo Luc				Added validation for special cases units that have more than one line.
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptDowntimeDetails]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE
	 @prodLineId	VARCHAR(MAX)	= NULL
	,@workCellId	VARCHAR(MAX)	= NULL
	,@timeOption	INT				= NULL
	,@excludeNPT	INT				= NULL
	,@groupBy		VARCHAR(50)		= NULL --workcell or line
	,@startTime		DATETIME	
	,@endTime		DATETIME

--WITH ENCRYPTION
AS
SET NOCOUNT ON
-- --------------------------------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE 
		 @PLId					INT
		,@strTimeOption			VARCHAR(50)
		,@strNPT				VARCHAR(50)
		

	DECLARE 
		 @tbl_TimeOption		TABLE (startDate DATETIME, endDate DATETIME)

	
-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------

	--SELECT  
	--	 @prodLineId	= 0
	--	,@workCellId	= '100'
	--	,@timeOption	= 1
	--	,@excludeNPT	= 0
	--	,@groupBy		= 'workcell'
	--	,@startTime		= '2019-10-01 06:00:00'
	--	,@endTime		= '2019-10-03 06:00:00'

---------------------------------------------------------------------------------------------------
DECLARE @Equipment TABLE (
		RcdIdx						INT IDENTITY	,						
		PUId						INT				,
		PUDesc						NVARCHAR(255)	,
		PLId						INT				,
		PLDesc						NVARCHAR(255)	,
		DeptDesc					NVARCHAR(255)	,
		VSId						INT				,
		ValueStreamDesc				NVARCHAR(255)	,
		StartTime					DATETIME		,
		EndTime						DATETIME		)
---------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @groupBy = 'Line'
BEGIN
	INSERT INTO @Equipment(
			PUId)
			SELECT String FROM fnLocal_Split(@workCellId,',')
END
ELSE
BEGIN
	INSERT INTO @Equipment(
			PLId)
			SELECT String FROM fnLocal_Split(@prodLineId,',')
END	
-- --------------------------------------------------------------------------------------------------------------------
-- Validation for MTD when It's the 1 Day of the month
-- --------------------------------------------------------------------------------------------------------------------
IF @timeOption = 5 AND ((SELECT DAY(GETDATE())) = 1)
BEGIN
	SET @timeOption = 6
END
-- --------------------------------------------------------------------------------------------------------------------
-- Update @Equipment table with all the needed values
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @groupBy = 'Line'
BEGIN
	--update plid, VSId and pudesc 
	UPDATE e
		SET PLID = (SELECT TOP 1 PLId FROM [dbo].[OpsDB_DowntimeUptime_Data] (NOLOCK) WHERE PUId = e.PUId)
	FROM @Equipment e
END
--update department desc
UPDATE e
		SET DeptDesc = (SELECT DeptDesc FROM dbo.LINE_Dimension WHERE PLId = e.PLId)
FROM @Equipment e

--Update Start and End time
IF @timeOption > 0
BEGIN
	--Update start time and end time if a time option is selected
	SELECT @strTimeOption = DateDesc 
	FROM [dbo].[DATE_DIMENSION] (NOLOCK)
	WHERE DateId = @timeOption

	UPDATE e 
			SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
			FROM @Equipment e 
			OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f
END
ELSE
BEGIN
	--update the Start and End Time from input parameters (user defined selected on report)
	UPDATE e 
			SET	e.StartTime = @startTime, e.EndTime = @endTime
	FROM @Equipment e
			
END
-- --------------------------------------------------------------------------------------------------------------------
-- Get NPT
-- --------------------------------------------------------------------------------------------------------------------
	SELECT			@strNPT = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'PR' END)
--SELECT '@Equipment',* from @Equipment
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 1. Detail Grid
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @groupBy = 'line'
BEGIN	
	SELECT 
		 od.StartTime				AS 'StartTime'
		,od.LineStatus
		,od.EndTime					AS 'EndTime'
		,od.Duration				AS 'Downtime'
		,od.Uptime					AS 'Uptime'
		,od.LineGroup				AS 'ValueStream'
		,e.DeptDesc					AS 'Area'
		,od.PLId
		,od.PLDesc					AS 'ProductionLine'
		,od.PUId
		,od.PUDesc					AS 'WorkCell'
		,od.Fault					AS 'Fault'
		,od.Location				AS 'Location'
		,od.Reason1					AS 'ReasonLevel1'
		,od.Reason2					AS 'ReasonLevel2'
		,od.Reason3					AS 'ReasonLevel3'
		,od.Reason4					AS 'ReasonLevel4'
		,od.Action1					AS 'ActionLevel1'
		,od.Action2					AS 'ActionLevel2'
		,od.Action3					AS 'ActionLevel3'
		,od.Action4					AS 'ActionLevel4'
		,od.Reason1Category			AS 'Reason1Category'
		,od.Reason2Category			AS 'Reason2Category'
		,od.Reason3Category			AS 'Reason3Category'
		,od.Reason4Category			AS 'Reason4Category'
		,od.Comment_Rtf				AS 'Comments'
		,od.ShiftDesc				AS 'Shift'
		,od.TeamDesc				AS 'Team'
		,od.ProductionDay			AS 'ProductionDay'
		,od.LineStatus				AS 'ProductionStatus'
		,od.ProdCode				AS 'ProductionCode'
		,od.ProdDesc				AS 'ProductDescription'
		,CASE	WHEN BreakDown = 1 THEN 'BreakDown'
				WHEN Planned = 1 THEN 'Planned'
				ELSE 'Unplanned'
				END AS 'DowntimeType'
		,CASE	WHEN ProcFailure = 1 AND BreakDown <> 1 THEN 'PF'
				WHEN MajorStop = 1 THEN 'MJ'
				WHEN MinorStop = 1 THEN 'MN'
				WHEN BreakDown = 1 THEN 'BD'
				END AS 'StopClass'
		,DTStatus			AS 'IsStop'
        ,DATEDIFF(second,e.StartTime,e.EndTime) AS 'ReportTime'
		,ISNULL((od.Uptime + od.Duration),0) AS 'ScheduleTime'
		,CASE	WHEN od.Planned = 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalPlannedDowntime'
		,CASE	WHEN od.Planned <> 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalUnplPlannedDowntime'
	FROM @Equipment e
	JOIN [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) ON od.PLId = e.PLId
	WHERE 1=1
	AND od.PUId	= e.PUId
	AND (od.LineStatus	LIKE '%' + @strNPT + '%')
	AND od.StartTime >= e.StartTime
	AND od.EndTime <= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND DeleteFlag		= 0
	--AND IsContraint = 1
	--AND od.ShiftDesc  = 'All'
	--AND od.TeamDesc = 'All'
	ORDER BY od.PUDesc
			--,ProductionDay
			,od.StartTime
END
ELSE
BEGIN
	SELECT 
		 od.StartTime				AS 'StartTime'
		,od.LineStatus
		,od.EndTime					AS 'EndTime'
		,od.Duration				AS 'Downtime'
		,od.Uptime					AS 'Uptime'
		,od.LineGroup				AS 'ValueStream'
		,e.DeptDesc					AS 'Area'
		,od.PLId
		,od.PLDesc					AS 'ProductionLine'
		,od.PUId
		,od.PUDesc					AS 'WorkCell'
		,od.Fault					AS 'Fault'
		,od.Location				AS 'Location'
		,od.Reason1					AS 'ReasonLevel1'
		,od.Reason2					AS 'ReasonLevel2'
		,od.Reason3					AS 'ReasonLevel3'
		,od.Reason4					AS 'ReasonLevel4'
		,od.Action1					AS 'ActionLevel1'
		,od.Action2					AS 'ActionLevel2'
		,od.Action3					AS 'ActionLevel3'
		,od.Action4					AS 'ActionLevel4'
		,od.Reason1Category			AS 'Reason1Category'
		,od.Reason2Category			AS 'Reason2Category'
		,od.Reason3Category			AS 'Reason3Category'
		,od.Reason4Category			AS 'Reason4Category'
		,od.Comment_Rtf				AS 'Comments'
		,od.ShiftDesc				AS 'Shift'
		,od.TeamDesc				AS 'Team'
		,od.ProductionDay			AS 'ProductionDay'
		,od.LineStatus				AS 'ProductionStatus'
		,od.ProdCode				AS 'ProductionCode'
		,od.ProdDesc				AS 'ProductDescription'
		,CASE	WHEN BreakDown = 1 THEN 'BreakDown'
				WHEN Planned = 1 THEN 'Planned'
				ELSE 'Unplanned'
				END AS 'DowntimeType'
		,CASE	WHEN ProcFailure = 1 THEN 'PF'
				WHEN MajorStop = 1 THEN 'MJ'
				WHEN MinorStop = 1 THEN 'MN'
				WHEN BreakDown = 1 THEN 'BD'
				END AS 'StopClass'
		,DTStatus			AS 'IsStop'
        ,DATEDIFF(second,e.StartTime,e.EndTime) AS 'ReportTime'
		,ISNULL((od.Uptime + od.Duration),0) AS 'ScheduleTime'
		,CASE	WHEN od.Planned = 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalPlannedDowntime'
		,CASE	WHEN od.Planned <> 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalUnplPlannedDowntime'
	FROM @Equipment e
	JOIN [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) ON od.PLId = e.PLId
	WHERE 1=1
	AND od.PLId	= e.PLId
	AND (od.LineStatus	LIKE '%' + @strNPT + '%')
	AND od.StartTime >= e.StartTime
	AND od.EndTime <= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND DeleteFlag		= 0
	--AND od.ShiftDesc  = 'All'
	--AND od.TeamDesc = 'All'
	AND IsContraint = 1
	ORDER BY od.PUDesc
			--,ProductionDay
			,od.StartTime
END
GO
GRANT  EXECUTE  ON [dbo].[spRptDowntimeDetails]  TO OpDBWriter
GO