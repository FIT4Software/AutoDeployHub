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
		@SP_Name	= 'spRptProductionDetails',
		@Inputs		= 7, 
		@Version	= '1.2'  

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
				
DROP PROCEDURE [dbo].[spRptProductionDetails]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptProductionDetails
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-08-03
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides Production Details data.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-08-03		Gonzalo Luc     		Initial Release
-- 1.1		2019-10-04		Gonzalo	Luc				Added User Defined.
-- 1.2		2019-10-14		Gonzalo Luc				Added SubPR for internal grid PR calculation
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptProductionDetails]

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
	--	 @prodLineId	= '61'
	--	,@workCellId	= ''
	--	,@timeOption	= 1
	--	,@excludeNPT	= 0
	--	,@groupBy		= 'line'
	--	,@startTime		= '2019-10-01 06:00:00'
	--	,@endTime		= '2019-10-04 06:00:00'

---------------------------------------------------------------------------------------------------
DECLARE @Equipment TABLE (
		RcdIdx						INT IDENTITY	,						
		PUId						INT				,
		PUDesc						NVARCHAR(255)	,
		PLId						INT				,
		PLDesc						NVARCHAR(255)	,
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
		SET PLID = (SELECT PLID FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId)
	FROM @Equipment e
END
--update the Start and End Time 
UPDATE e 
		SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
		FROM @Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f

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
IF NOT @groupBy = 'Line'
BEGIN
	SELECT																							 
		
		 pd.StartTime				  	AS 'StartTime'
		,pd.EndTime						AS 'EndTime'
		,pd.POStatus					AS 'POStatus'
		,pd.EndTimeUTC					AS 'EndTimeUTC'
		,pd.StartTimeUTC				AS 'StartTimeUTC'
		,pd.LineGroup					AS 'ValueStream'					 
		,DeptDesc						AS 'DeptDesc'									 
		,pd.PLDesc						AS 'PLDesc'											 
		,pd.PUDesc						AS 'PUDesc'
		,pd.ProcessOrder				AS 'ProcessOrder'
		,pd.ProdCode					AS 'ProdCode'
		,pd.ProdDesc					AS 'ProdDesc'
		,pd.ProdFam						AS 'ProdFam'
		,pd.ProdGroup					AS 'ProdGroup'
		,pd.ShiftDesc					AS 'ShiftDesc'
		,pd.TeamDesc					AS 'TeamDesc'
		,pd.LineStatus					AS 'LineStatus'
		,ISNULL(pd.TotalProduct,0)		AS 'TotalProduct'
		,ISNULL(pd.GoodProduct,0)		AS 'GoodProduct'
		,ISNULL(pd.TotalScrap,0)		AS 'TotalScrap'
		,ISNULL(pd.ActualRate,0)		AS 'ActualRate'
		,ISNULL(pd.TargetRate,0)		AS 'TargetRate'
		,ISNULL(pd.IdealRate,0)			AS 'IdealRate'
		,ISNULL(pd.TotalCases,0)		AS 'TotalCases'
		,ISNULL(pd.RunningScrap,0)		AS 'RunningScrap'
		,ISNULL(pd.StartingScrap,0)		AS 'StartingScrap'
		,ISNULL(pd.FirstPackCount,0)	AS 'FirstPackCount'
		,ISNULL(pd.SecondPackCount,0)	AS 'SecondPackCount'
		,ISNULL(pd.ThirdPackCount,0)	AS 'ThirdPackCount'
		,ISNULL(pd.FourthPackCount,0)	AS 'FourthPackCount'
		,ISNULL(pd.ProdPerStat,0)		AS 'ProdPerStat'
		,ISNULL(pd.StatFactor,0)		AS 'StatFactor'
		,ISNULL(pd.StatUnits,0)			AS 'StatUnits'
		,ISNULL(pd.ConvertedCases,0)	AS 'ConvertedCases'
		,ISNULL(pd.Uptime,0)			AS 'Uptime'
		,ISNULL(pd.DownTime,0)			AS 'DownTime'
		,ISNULL(pd.ScheduledTime,0)		AS 'ScheduledTime'
		,ISNULL(pd.Stops,0)				AS 'Stops'
		,ISNULL(pd.BatchNumber,'')		AS 'BatchNumber'
		,ISNULL(pd.CalcSpeed,0)			AS 'CalcSpeed'
		,pd.Ts							AS 'Ts'
		,ISNULL(pd.ZoneDesc,'')			AS 'ZoneDesc'
		,ISNULL(pd.ZoneGrpDesc,'')		AS 'ZoneGrpDesc'			
		,CASE WHEN pd.ActualRate > pd.TargetRate 
				THEN CASE WHEN pd.ActualRate > 0 THEN ISNULL((pd.GoodProduct / pd.ActualRate),0) ELSE 0 END
				ELSE CASE WHEN pd.TargetRate > 0 THEN ISNULL((pd.GoodProduct / pd.TargetRate),0) ELSE 0 END END AS 'SubPR'														 
	FROM @Equipment e																			
	JOIN [dbo].[WorkCell_Dimension]			wd (NOLOCK) ON wd.PUId = e.PUId						
	JOIN [dbo].[LINE_DIMENSION]				ld (NOLOCK) ON wd.plid = ld.plid					
	JOIN [dbo].[OpsDB_Production_Data]  	pd (NOLOCK) ON pd.PLId = ld.PLId					
	WHERE 1=1
	AND pd.PUId	= e.PUId
	AND (pd.LineStatus	LIKE '%' + @strNPT + '%')
	AND pd.StartTime >= e.StartTime
	AND pd.EndTime <= e.EndTime
	AND DeleteFlag		= 0
	ORDER BY pd.PUDesc
			,pd.StartTime
END 
ELSE
BEGIN
	SELECT																							 
		
		 pd.StartTime				  	AS 'StartTime'
		,pd.EndTime						AS 'EndTime'
		,pd.POStatus					AS 'POStatus'
		,pd.EndTimeUTC					AS 'EndTimeUTC'
		,pd.StartTimeUTC				AS 'StartTimeUTC'
		,pd.LineGroup					AS 'ValueStream'					 
		,DeptDesc						AS 'DeptDesc'									 
		,pd.PLDesc						AS 'PLDesc'											 
		,pd.PUDesc						AS 'PUDesc'
		,pd.ProcessOrder				AS 'ProcessOrder'
		,pd.ProdCode					AS 'ProdCode'
		,pd.ProdDesc					AS 'ProdDesc'
		,pd.ProdFam						AS 'ProdFam'
		,pd.ProdGroup					AS 'ProdGroup'
		,pd.ShiftDesc					AS 'ShiftDesc'
		,pd.TeamDesc					AS 'TeamDesc'
		,pd.LineStatus					AS 'LineStatus'
		,ISNULL(pd.TotalProduct,0)		AS 'TotalProduct'
		,ISNULL(pd.GoodProduct,0)		AS 'GoodProduct'
		,ISNULL(pd.TotalScrap,0)		AS 'TotalScrap'
		,ISNULL(pd.ActualRate,0)		AS 'ActualRate'
		,ISNULL(pd.TargetRate,0)		AS 'TargetRate'
		,ISNULL(pd.IdealRate,0)			AS 'IdealRate'
		,ISNULL(pd.TotalCases,0)		AS 'TotalCases'
		,ISNULL(pd.RunningScrap,0)		AS 'RunningScrap'
		,ISNULL(pd.StartingScrap,0)		AS 'StartingScrap'
		,ISNULL(pd.FirstPackCount,0)	AS 'FirstPackCount'
		,ISNULL(pd.SecondPackCount,0)	AS 'SecondPackCount'
		,ISNULL(pd.ThirdPackCount,0)	AS 'ThirdPackCount'
		,ISNULL(pd.FourthPackCount,0)	AS 'FourthPackCount'
		,ISNULL(pd.ProdPerStat,0)		AS 'ProdPerStat'
		,ISNULL(pd.StatFactor,0)		AS 'StatFactor'
		,ISNULL(pd.StatUnits,0)			AS 'StatUnits'
		,ISNULL(pd.ConvertedCases,0)	AS 'ConvertedCases'
		,ISNULL(pd.Uptime,0)			AS 'Uptime'
		,ISNULL(pd.DownTime,0)			AS 'DownTime'
		,ISNULL(pd.ScheduledTime,0)		AS 'ScheduledTime'
		,ISNULL(pd.Stops,0)				AS 'Stops'
		,ISNULL(pd.BatchNumber,'')		AS 'BatchNumber'
		,ISNULL(pd.CalcSpeed,0)			AS 'CalcSpeed'
		,pd.Ts							AS 'Ts'
		,ISNULL(pd.ZoneDesc,'')			AS 'ZoneDesc'
		,ISNULL(pd.ZoneGrpDesc,'')		AS 'ZoneGrpDesc'				
		,CASE WHEN pd.ActualRate > pd.TargetRate 
				THEN CASE WHEN pd.ActualRate > 0 THEN ISNULL((pd.GoodProduct / pd.ActualRate),0) ELSE 0 END
				ELSE CASE WHEN pd.TargetRate > 0 THEN ISNULL((pd.GoodProduct / pd.TargetRate),0) ELSE 0 END END AS 'SubPR'													 
	FROM @Equipment e																			
	JOIN [dbo].[LINE_DIMENSION]				ld (NOLOCK) ON e.plid = ld.plid					
	JOIN [dbo].[OpsDB_Production_Data]  	pd (NOLOCK) ON pd.PLId = ld.PLId					
	WHERE 1=1
	AND pd.PLId	= e.PLId
	AND (pd.LineStatus	LIKE '%' + @strNPT + '%')
	AND pd.StartTime >= e.StartTime
	AND pd.EndTime <= e.EndTime
	AND DeleteFlag		= 0
	ORDER BY pd.PUDesc
			,pd.StartTime
END
GO
GRANT  EXECUTE  ON [dbo].[spRptProductionDetails]  TO OpDBWriter
GO