USE [Auto_opsDataStore]
GO

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
	@SP_Name	= 'spRptScrap',
	@Inputs		= 13,
	@Version	= '2.5'

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
	INSERT INTO dbo.AppVersions
		(
		App_name,
		App_version,
		Modified_On )
	VALUES
		(
			@SP_Name,
			@Version,
			GETDATE())
END

--===================================================================================================================== 
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
FROM Information_schema.Routines
WHERE	Specific_schema = 'dbo'
	AND Specific_Name = @SP_Name
	AND Routine_Type = 'PROCEDURE' )
				
DROP PROCEDURE [dbo].[spRptScrap]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptScrap
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-06-05
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for Scrap Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-06-05		Gonzalo Luc     		Initial Release
-- 1.1		2019-03-28		Damian Campana			Add filter by Team, Shift, Location & User Defined
-- 1.2		2019-07-25		Damian Campana			Modify the calculation for the Production Day
-- 1.3		2020-03-10		Gonzalo Luc				Add grouping by All.
-- 1.4		2020-06-18		Ivan	Corica			Add PercentOfScrap and EventsPerc columns
-- 1.5		2020-06-24		Ivan	Corica			Add grouping by minor, added one more input @MinorGroupBy
-- 1.6		2020-07-02		Ivan	Corica			Add userDefined filter or timeOption -1
-- 1.7      2020-07-17      Alvaro Palacios         Add Production Day after the first Shift of the next day.
-- 1.8		2020-08-26		Gonzalo Luc				Change source to get PU desc and PL desc to avoid multiple records on the update.
-- 1.9      2020-08-27      Alvaro Palacios         Change INT to BIGINT variables fro totalProduct and totalScrap
-- 2.0		2020-11-27		Gonzalo Luc				Fix Prod Day on raw data when user defined is selected.
-- 2.1		2021-01-26		Ivan	Corica			Add eventReasons and fault filters
-- 2.2		2021-07-21		Gonzalo Luc				Fix user defined for grooming
-- 2.3		2022-06-07		Gonzalo Luc				Fix Group by All KPI when is grooming.
-- 2.4		2023-03-08		Jorge Merino			Fix User Defined for grooming.
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptScrap]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE
	 @prodLineId	VARCHAR(MAX)	= NULL
	,@workCellId	VARCHAR(MAX)	= NULL
	,@timeOption	INT				= NULL
	,@excludeNPT	INT				= NULL
	,@MajorGroupBy	VARCHAR(50)		= NULL --workcell or line
	,@MinorGroupBy	VARCHAR(50)		= NULL --Null, ProdDesc, TeamDesc, Reason1, Fault
	,@dtmStartTime	DATETIME		= NULL
	,@dtmEndTime	DATETIME		= NULL
	,@crew			VARCHAR(MAX)	= 'All'
	,@shift			VARCHAR(MAX)	= 'All'
	,@location		VARCHAR(MAX)	= 'All'
	,@eventReasons	NVARCHAR(MAX)   = NULL
	,@fault			NVARCHAR(MAX)	= NULL
--WITH ENCRYPTION
AS
SET NOCOUNT ON
--set statistics io on;
--set statistics time on;
-- --------------------------------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------------------------------
-- Test
-- --------------------------------------------------------------------------------------------------------------------
--SELECT 
--	 @prodLineId	= '206,213,214,215,383'
--	,@workCellId	= '14253,14772,14829,14886,23627,25559'
--	,@timeOption	= 1
--	,@excludeNPT	= 0
--	,@MajorGroupBy	= 'All'
--	,@MinorGroupBy  = NULL -- ProdDesc, TeamDesc, Reason1, Fault
--	,@dtmStartTime	= '2021-07-19 06:00:00'--'2020-12-27 05:00:00'
--	,@dtmEndTime	= '2021-07-20 06:00:00'--'2021-01-26 05:00:00'
--	,@crew			= 'All'
--	,@shift			= 'All'
--	,@location		= 'All'
--	,@eventReasons	= ''
--	,@fault			= ''
-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
DECLARE 
	 @PLId					INT
	,@strTimeOption			NVARCHAR(50)
	,@strNPT				NVARCHAR(50)
	,@strNPTDet				NVARCHAR(50)
	,@startTime				DATETIME
	,@endTime				DATETIME
	,@ReportedTime			DATETIME
	,@TotalProduct			BIGINT
	,@TotalScrap			BIGINT
	,@TotalEvent			INT
	,@commandSQL			NVARCHAR(MAX)

DECLARE 
	 @index					INT
	,@StartTimeAux			DATETIME
	,@EndTimeAux			DATETIME
	,@PUIdAux				INT
	,@PLIdAux				INT
	,@dtmProdDayStartAux	DATETIME
	,@i						INT				
	,@j						INT
	,@PUDescAux				NVARCHAR(255)
	,@PLDescAux				NVARCHAR(255)
	,@VSIdAux				INT
	,@VSDescAux				NVARCHAR(255)
	,@dtmProdDayEndAux		DATETIME
	,@DayStart				TIME
	,@DateAux				DATE
	,@ProdDayAux			DATE
		

DECLARE 
		 @tbl_TimeOption		TABLE (startDate DATETIME,
	endDate DATETIME)

IF OBJECT_ID('tempdb.dbo.#RejectsDetails', 'U') IS NOT NULL  DROP TABLE #RejectsDetails
CREATE TABLE #RejectsDetails
(
	RCIdx					INT IDENTITY	,
	Timestamp				DATETIME		,
	Amount					INT				,
	PLDesc					NVARCHAR(50)	,
	PLId					INT				,
	PUDesc					NVARCHAR(50)	,
	Fault					NVARCHAR(100)	,
	Location				NVARCHAR(100)	,
	Reason1					NVARCHAR(100)	,
	Comments				NVARCHAR(MAX)	,
	ShiftDesc				NVARCHAR(100)	,
	TeamDesc				NVARCHAR(100)	,
	ProdDay					DATE			,
	LineStatus				NVARCHAR(100)	,
	ProdCode				NVARCHAR(100)	,
	ProdDesc				NVARCHAR(100)	,
	ValueStream				NVARCHAR(100)	,
	Units					NVARCHAR(100)	,
	PUId					INT				,
	ScrapPerc				DECIMAL(19,10)	,
	PercOfScrap				DECIMAL(19,10)  ,
	EventsPerc				DECIMAL(19,10)
)
--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Production') IS NOT NULL
BEGIN
	DROP TABLE #Production
END
CREATE TABLE #Production
(
	 LineId					INT				
	,WorkCellId				INT			
	,DateId					INT				
	,ProductId				INT			
	,ProductCode			NVARCHAR(50) COLLATE DATABASE_DEFAULT
	,TeamDesc				NVARCHAR(25) COLLATE DATABASE_DEFAULT
	,ShiftDesc				NVARCHAR(25) COLLATE DATABASE_DEFAULT
	,Starttime				DATETIME		
	,DeleteFlag				INT				
	,BU						NVARCHAR(25) COLLATE DATABASE_DEFAULT
	,Status					NVARCHAR(50) COLLATE DATABASE_DEFAULT
	,EndTime				DATETIME	
	,GoodProduct			BIGINT	
	,TotalProduct			FLOAT	
	,TotalScrap				FLOAT	
	,ActualRate				FLOAT	
	,TargetRate				FLOAT	
	,ScheduleTime			FLOAT	
	,PR						FLOAT			
	,ScrapPer				FLOAT		
	,IdealRate				FLOAT	
	,STNU					FLOAT			
	,STNUPer				FLOAT		
	,BrandProjectPer		FLOAT		
	,EO_NonShippablePer		FLOAT	
	,LineNotStaffedPer		FLOAT	
	,StartingScrap			INT			
	,RunningScrap			FLOAT			
	,StartingScrapPer		FLOAT		
	,RunningScrapPer		FLOAT		
	,PRAvailability			FLOAT		
	,Availability			FLOAT			
	,CapacityUtilization	FLOAT	
	,RateUtilization		FLOAT		
	,TotalCases				FLOAT			
	,RoomLoss				FLOAT			
	,MSU					FLOAT			
	,ScheduleUtilization	FLOAT	
	,DownMSU				FLOAT			
	,StopsMSU				FLOAT			
	,RunEff					FLOAT			
	,PRRateLoss				FLOAT			
	,PRLossScrap			FLOAT			
	,Area4LossPer			FLOAT			
	,VSNetProduction		FLOAT		
	,VSPR					FLOAT			
	,VSPRLossPer			FLOAT			
	,StatUnits				FLOAT			
	,ConvertedCases			BIGINT		
	,NetProduction			FLOAT
)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Equipment') IS NOT NULL
BEGIN
	DROP TABLE #Equipment
END
CREATE TABLE #Equipment
(
	 RcdIdx					INT IDENTITY							
	,PUId					INT										
	,PUDesc					NVARCHAR(255) COLLATE DATABASE_DEFAULT
	,PLId					INT										
	,PLDesc					NVARCHAR(255) COLLATE DATABASE_DEFAULT
	,VSId					INT										
	,ValueStreamDesc		NVARCHAR(255) COLLATE DATABASE_DEFAULT
	,StartTime				DATETIME								
	,EndTime				DATETIME								
	,DayStartTime			TIME
	,FlagLine				bit
)

---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Output') IS NOT NULL
BEGIN
	DROP TABLE #Output
END
CREATE TABLE #Output
(
	RCIdx					INT IDENTITY	,
	Timestamp				DATETIME		,
	Amount					INT				,
	EventCount				INT				,
	PLDesc					NVARCHAR(50)	,
	PLId					INT				,
	PUDesc					NVARCHAR(50)	,
	Fault					NVARCHAR(100)	,
	Location				NVARCHAR(100)	,
	Reason1					NVARCHAR(100)	,
	Comments				NVARCHAR(MAX)	,
	ShiftDesc				NVARCHAR(100)	,
	TeamDesc				NVARCHAR(100)	,
	ProdDay					DATE			,
	LineStatus				NVARCHAR(100)	,
	ProdCode				NVARCHAR(100)	,
	ProdDesc				NVARCHAR(100)	,
	ValueStream				NVARCHAR(100)	,
	Units					NVARCHAR(100)	,
	PUId					INT				,
	ScrapPerc				DECIMAL(19,10)	,
	PercOfScrap				DECIMAL(19,10)  ,
	EventsPerc				DECIMAL(19,10)
)
--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#UserDefinedProduction') IS NOT NULL
BEGIN
	DROP TABLE #UserDefinedProduction
END

CREATE TABLE #UserDefinedProduction
(
	 LineId					INT			
	,WorkCellId				INT		
	,DateId					INT			
	,ProductId				INT		
	,ProductCode			NVARCHAR(50) COLLATE DATABASE_DEFAULT
	,TeamDesc				NVARCHAR(25) COLLATE DATABASE_DEFAULT
	,ShiftDesc				NVARCHAR(25) COLLATE DATABASE_DEFAULT
	,Starttime				DATETIME		
	,DeleteFlag				INT				
	,BU						NVARCHAR(25) COLLATE DATABASE_DEFAULT
	,Status					NVARCHAR(50) COLLATE DATABASE_DEFAULT
	,EndTime				DATETIME		
	,GoodProduct			BIGINT			
	,TotalProduct			FLOAT			
	,TotalScrap				FLOAT			
	,ActualRate				FLOAT			
	,TargetRate				FLOAT			
	,ScheduleTime			FLOAT			
	,PR						FLOAT			
	,ScrapPer				FLOAT			
	,IdealRate				FLOAT			
	,STNU					FLOAT			
	,STNUPer				FLOAT			
	,BrandProjectPer		FLOAT			
	,EO_NonShippablePer		FLOAT			
	,LineNotStaffedPer		FLOAT			
	,StartingScrap			INT				
	,RunningScrap			FLOAT		
	,StartingScrapPer		FLOAT		
	,RunningScrapPer		FLOAT			
	,PRAvailability			FLOAT			
	,Availability			FLOAT			
	,CapacityUtilization	FLOAT			
	,RateUtilization		FLOAT			
	,TotalCases				FLOAT			
	,RoomLoss				FLOAT			
	,MSU					FLOAT			
	,MSUExcDev				FLOAT			
	--If dont have last iODS comment this
	,ScheduleUtilization	FLOAT			
	,DownMSU				FLOAT			
	,StopsMSU				FLOAT			
	,RunEff					FLOAT			
	,PRRateLoss				FLOAT			
	,PRLossScrap			FLOAT			
	,Area4LossPer			FLOAT			
	,VSNetProduction		FLOAT			
	,VSPR					FLOAT			
	,VSPRLossPer			FLOAT			
	,StatUnits				FLOAT			
	,ConvertedCases			BIGINT			
	,NetProduction			FLOAT		
	,StatCases				FLOAT			
	,TargetRateAdj			FLOAT				
	,NetProductionExcDev	FLOAT			
	,ScheduleTimeExcDev		FLOAT			
	,PR_Excl_PRInDev		FLOAT			
	,TargetRateExcDev		FLOAT			
	,ActualRateExcDev		FLOAT
	,ProjConstructPerc		FLOAT			
	,STNUSchedVarPerc		FLOAT
	,StatFactor				FLOAT			
	)
---------------------------------------------------------------------------------------------------
DECLARE @ProdDay TABLE (
	 RcdIdx					INT IDENTITY		
	,ProdDayId				INT									
	,PUId					INT				
	,PUDesc					NVARCHAR(255)	COLLATE DATABASE_DEFAULT
	,PLId					INT				
	,PLDesc					NVARCHAR(255)	COLLATE DATABASE_DEFAULT
	,VSId					INT				
	,ValueStreamDesc		NVARCHAR(255)	COLLATE DATABASE_DEFAULT
	,ProdDay				DATE			
	,StartTime				DATETIME		
	,EndTime				DATETIME		
)
---------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
----------------------------------------------------------------------------------------------------------------------
IF @MajorGroupBy = 'Line' 
BEGIN
	INSERT INTO #Equipment
		(
		PLId)
	SELECT String
	FROM fnLocal_Split(@prodLineId,',')
END
ELSE 
BEGIN
	INSERT INTO #Equipment
		(
		PUId)
	SELECT String
	FROM fnLocal_Split(@workCellId,',')
END

-- --------------------------------------------------------------------------------------------------------------------
-- Update #Equipment table with all the needed values
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @MajorGroupBy = 'Line' 
BEGIN
	UPDATE e

		SET PLID = (SELECT PL_Id FROM dbo.Prod_Units_Base_syn WHERE PU_Id = e.PUId),
			VSId = (SELECT TOP 1 VSId FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId),
			PUDesc = (SELECT PU_Desc FROM dbo.Prod_Units_Base_syn WHERE PU_Id = e.PUId)

	FROM #Equipment e
	JOIN dbo.Prod_Units_Base_syn pub WITH(NOLOCK) ON pub.PU_Id = e.PUId
	--update valuestream desc
	UPDATE e
		SET ValuestreamDesc	= (SELECT LineDesc
								FROM dbo.LINE_DIMENSION ld WITH(NOLOCK) WHERE ld.LineId = e.VSId)
		FROM #Equipment e
--Update Line Desc for Line major group
END
UPDATE e
SET PLDesc = ld.LineDesc, DayStartTime = CONVERT(TIME,ld.ShiftStartTime)
FROM #Equipment e
JOIN dbo.LINE_DIMENSION ld WITH(NOLOCK) ON ld.PLId = e.PLId

--Update Start and End time
IF @timeOption > 0
BEGIN
	--Update start time and end time if a time option is selected
	SELECT @strTimeOption = DateDesc
	FROM [dbo].[DATE_DIMENSION] WITH(NOLOCK)
	WHERE DateId = @timeOption

	UPDATE e 
			SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
			FROM #Equipment e 
			OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f
END
ELSE
BEGIN
	--update the Start and End Time from input parameters (user defined selected on report)
	UPDATE e 
			SET	e.StartTime = @dtmStartTime, e.EndTime = @dtmEndTime
	FROM #Equipment e
END
-- --------------------------------------------------------------------------------------------------------------------
-- Get NPT
-- --------------------------------------------------------------------------------------------------------------------
SELECT @strNPT = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'All' END)
--NPT for details
SELECT @strNPTDet = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'PR' END)
-- --------------------------------------------------------------------------------------------------------------------
--UPDATE FLAG
UPDATE e 
	SET FlagLine = 1
	FROM #Equipment e
	WHERE RcdIdx IN (SELECT MIN(RcdIdx)
					FROM #Equipment 
					group by PLId)

-- --------------------------------------------------------------------------------------------------------------------
-- Result set 1. KPI's
-- --------------------------------------------------------------------------------------------------------------------
IF @timeOption > 0
BEGIN
	IF @MajorGroupBy = 'workcell'
	BEGIN
		IF ((SELECT COUNT(*)
		FROM dbo.LINE_DIMENSION ld (NOLOCK)
			JOIN #Equipment e ON e.PLId = ld.PLId
		WHERE ld.BuId = 'Grooming') < 1)
		BEGIN
			SELECT DISTINCT
				ISNULL(TotalScrap,0)						AS 'totalScrap',
				ISNULL(TotalProduct,0)						AS 'totalMachineCount',
				ISNULL(ScrapPer,0)							AS 'totalScrapPercent',
				CASE WHEN ScheduleTime = 0 THEN 0 ELSE ISNULL((TotalScrap * 1440)/ScheduleTime,0) END	AS 'totalRejectDay'

			FROM #Equipment e
			JOIN [dbo].[LINE_DIMENSION]		ld (NOLOCK) ON ld.PLId = e.PLId 
			JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 
																AND fp.Workcell_Dimension_WorkCellId = 0

			WHERE 1=1
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))

			-- Save total scrap and total product for scrap and PercOfScrap % calculation on details
			SELECT DISTINCT @TotalScrap = ISNULL(TotalScrap,0), @TotalProduct = ISNULL(TotalProduct,0)
			FROM [dbo].FACT_PRODUCTION		fp (NOLOCK)
				JOIN [dbo].[LINE_DIMENSION]		ld (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
				JOIN #Equipment					e ON ld.PLId = e.PLId

			WHERE 1=1
				AND ld.PLId	= e.PLId
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.Workcell_Dimension_WorkCellId = 0
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))
		END
		ELSE
		BEGIN

			SELECT DISTINCT
				ISNULL(TotalScrap,0)						AS 'totalScrap',
				ISNULL(TotalProduct,0)						AS 'totalMachineCount',
				ISNULL(ScrapPer,0)      					AS 'totalScrapPercent',
				CASE WHEN ScheduleTime = 0 THEN 0 ELSE ISNULL((TotalScrap * 1440)/ScheduleTime,0) END	AS 'totalRejectDay'

			FROM #Equipment e
			JOIN [dbo].[WorkCell_Dimension] wcd WITH(NOLOCK) ON wcd.PUId = e.PUId
			JOIN  [dbo].FACT_PRODUCTION		fp  WITH(NOLOCK) ON fp.WORKCELL_DIMENSION_WorkCellId = wcd.WorkCellId

			WHERE 1=1
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))

			-- Save total scrap and total product for scrap and PercOfScrap % calculation on details
			SELECT DISTINCT @TotalScrap = ISNULL(TotalScrap,0), @TotalProduct = ISNULL(TotalProduct,0)
			FROM #Equipment e
			JOIN [dbo].[WorkCell_Dimension] wcd WITH(NOLOCK) ON wcd.PUId = e.PUId
			JOIN  [dbo].FACT_PRODUCTION		fp  WITH(NOLOCK) ON fp.WORKCELL_DIMENSION_WorkCellId = wcd.WorkCellId
				
			WHERE 1=1
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))
		END

	END
	ELSE IF @MajorGroupBy = 'Line'
	BEGIN
		SELECT DISTINCT
			ISNULL(TotalScrap,0)						AS 'totalScrap',
			ISNULL(TotalProduct,0)						AS 'totalMachineCount',
			ISNULL(ScrapPer,0)      					AS 'totalScrapPercent',
			CASE WHEN ScheduleTime = 0 THEN 0 ELSE ISNULL((TotalScrap * 1440)/ScheduleTime,0) END	AS 'totalRejectDay'

		FROM #Equipment e
			JOIN [dbo].[LINE_DIMENSION]		ld WITH(NOLOCK) ON ld.PLId = e.PLId 
			JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 
																AND fp.Workcell_Dimension_WorkCellId = 0

		WHERE 1=1
			AND fp.DATE_DIMENSION_DateId	 = @timeOption
			AND fp.LineStatus	LIKE '%' + @strNPT + '%'
			AND fp.StartTime				>= e.StartTime
			AND fp.EndTime					<= e.EndTime
			AND fp.ShiftDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@shift, ','))
			AND fp.TeamDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@crew, ','))

		-- Save total scrap and total product for scrap and PercOfScrap % calculation on details
		SELECT DISTINCT @TotalScrap = ISNULL(TotalScrap,0), @TotalProduct = ISNULL(TotalProduct,0)
		FROM #Equipment e
			JOIN [dbo].[LINE_DIMENSION]		ld WITH(NOLOCK) ON ld.PLId = e.PLId 
			JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 
																AND fp.Workcell_Dimension_WorkCellId = 0

		WHERE 1=1
			AND fp.DATE_DIMENSION_DateId	 = @timeOption
			AND fp.LineStatus	LIKE '%' + @strNPT + '%'
			AND fp.StartTime				>= e.StartTime
			AND fp.EndTime					<= e.EndTime
			AND fp.ShiftDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@shift, ','))
			AND fp.TeamDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@crew, ','))
	END
	ELSE 
	BEGIN
		IF (SELECT COUNT(*) FROM #Equipment WHERE VSId IS NOT NULL) = 0
		BEGIN
			SELECT DISTINCT
				SUM(ISNULL(TotalScrap,0))						AS 'totalScrap',
				SUM(ISNULL(TotalProduct,0))						AS 'totalMachineCount',
				SUM((ISNULL(TotalScrap,0) / TotalProduct)) * 100  AS 'totalScrapPercent', --ISNULL(ScrapPer,0)      						AS 'totalScrapPercent',
				SUM(ISNULL((TotalScrap * 1440)/ScheduleTime,0))	AS 'totalRejectDay'

			FROM #Equipment e
				JOIN [dbo].[LINE_DIMENSION]		ld WITH(NOLOCK) ON ld.PLId = e.PLId 
				JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 
															   AND fp.Workcell_Dimension_WorkCellId = 0

			WHERE 1=1
				AND e.FlagLine = 1
				AND (fp.TotalProduct <> 0 AND fp.TotalProduct IS NOT NULL)
				AND (fp.ScheduleTime <> 0 AND fp.ScheduleTime IS NOT NULL)
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))

			-- Save total product and TotalScrap for scrap and PercOfScrap % calculation on details
			SELECT DISTINCT @TotalScrap =	SUM(ISNULL(TotalScrap,0)), @TotalProduct = SUM(ISNULL(TotalProduct,0))
			FROM #Equipment e
				JOIN [dbo].[LINE_DIMENSION]		ld WITH(NOLOCK) ON ld.PLId = e.PLId 
				JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 
																	AND fp.Workcell_Dimension_WorkCellId = 0

			WHERE 1=1
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))
		END
		ELSE
		BEGIN
			SELECT DISTINCT
				SUM(ISNULL(TotalScrap,0))						AS 'totalScrap',
				SUM(ISNULL(TotalProduct,0))						AS 'totalMachineCount',
				SUM((ISNULL(TotalScrap,0) / TotalProduct)) * 100  AS 'totalScrapPercent', --ISNULL(ScrapPer,0)      						AS 'totalScrapPercent',
				SUM(ISNULL((TotalScrap * 1440)/ScheduleTime,0))	AS 'totalRejectDay'

			FROM #Equipment e
				JOIN [dbo].[LINE_DIMENSION]		ld WITH(NOLOCK) ON ld.PLId = e.PLId 
				JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 

			WHERE 1=1
				AND e.FlagLine = 1
				AND (fp.TotalProduct <> 0 AND fp.TotalProduct IS NOT NULL)
				AND (fp.ScheduleTime <> 0 AND fp.ScheduleTime IS NOT NULL)
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))

			-- Save total product and TotalScrap for scrap and PercOfScrap % calculation on details
			SELECT DISTINCT @TotalScrap =	SUM(ISNULL(TotalScrap,0)), @TotalProduct = SUM(ISNULL(TotalProduct,0))
			FROM #Equipment e
				JOIN [dbo].[LINE_DIMENSION]		ld WITH(NOLOCK) ON ld.PLId = e.PLId 
				JOIN [dbo].FACT_PRODUCTION		fp WITH(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId 

			WHERE 1=1
				AND fp.DATE_DIMENSION_DateId	 = @timeOption
				AND fp.LineStatus	LIKE '%' + @strNPT + '%'
				AND fp.StartTime				>= e.StartTime
				AND fp.EndTime					<= e.EndTime
				AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
				AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))
		END
	END
END
ELSE
BEGIN
	IF(@MajorGroupBy = 'workcell')
	--Get update @prodLineId with PLId
	BEGIN
		SELECT @prodLineId = (SELECT TOP 1 PLId
			FROM #Equipment
			WHERE PUId IN (SELECT String
			FROM dbo.fnLocal_Split(@workCellId, ',')))
	END

	DECLARE @inGrouping NVARCHAR(10) = (SELECT CASE WHEN BuId = 'Grooming' THEN 'unit' ELSE 'line' END FROM dbo.Line_Dimension WHERE PLId = @prodLineId)

	INSERT INTO #UserDefinedProduction
	EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
												, @dtmStartTime
												, @dtmEndTime
												, @prodLineId
												, @workCellId
												, @strNPT
												, @shift
												, @crew
												, @inGrouping
												, 0


	SELECT DISTINCT
		SUM(ISNULL(TotalScrap,0))						AS 'totalScrap',
		SUM(ISNULL(TotalProduct,0))						AS 'totalMachineCount',
		SUM(ISNULL(ScrapPer,0))      					AS 'totalScrapPercent',
		SUM(ISNULL((TotalScrap * 1440)/ScheduleTime,0))	AS 'totalRejectDay'
	FROM #UserDefinedProduction

	-- Save total scrap and total product for scrap and PercOfScrap % calculation on details
	SELECT @TotalScrap = SUM(ISNULL(TotalScrap,0)), @TotalProduct = SUM(ISNULL(TotalProduct,0))
	FROM #UserDefinedProduction

END
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 2. Detail Grid
-- --------------------------------------------------------------------------------------------------------------------
IF (@MajorGroupBy = 'workcell' OR @MajorGroupBy = 'All')
BEGIN
	INSERT INTO #RejectsDetails
		(
		Timestamp
		,Amount
		,PLDesc
		,PUDesc
		,Fault
		,Location
		,Reason1
		,Comments
		,ShiftDesc
		,TeamDesc
		,ProdDay
		--,LineStatus	
		,ProdCode
		,ProdDesc
		,Units
		,PUId
		,PLId)
	SELECT
		rd.Timestamp
      , rd.Amount
      , rd.PLDesc
      , rd.PUDesc
      , rd.Fault
      , rd.Location
      , rd.Reason1
      , rd.Comments
      , rd.ShiftDesc
      , rd.TeamDesc
	  , CASE WHEN rd.Timestamp > CAST(CONCAT(CAST(rd.Timestamp AS DATE), ' ', CAST(e.EndTime AS TIME(0))) AS DATETIME)
			THEN CAST(rd.Timestamp AS DATE)
			ELSE DATEADD(DAY, -1, CAST(rd.Timestamp AS DATE))
	   END
      --,pd.LineStatus
      , rd.ProdCode
      , rd.ProdDesc
      , rd.Units
	  , rd.PUId
	  , rd.PLId
	FROM #Equipment							e
	JOIN [dbo].[OpsDB_Reject_Data]			rd (NOLOCK) ON rd.PLId = e.PLId
														AND rd.PUId = e.PUId
														AND rd.Timestamp	> e.StartTime
														AND rd.Timestamp	<= e.EndTime
	WHERE 1=1
		AND ((	@shift IS NULL OR @shift = ''	OR @shift = 'All')	OR rd.ShiftDesc IN (SELECT String FROM dbo.fnLocal_Split(@shift, ',')))
		AND ((	@crew IS NULL OR @crew = ''	OR @crew = 'All')	OR rd.TeamDesc IN (	SELECT String	FROM dbo.fnLocal_Split(@crew, ',')	))
		AND ((	@location IS NULL	OR @location = '' OR @location = 'All')	OR rd.Location IN (SELECT String FROM dbo.fnLocal_Split(@location, ',')))
		AND (@eventReasons = '' OR rd.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
		AND (@fault = '' OR rd.Fault IN (SELECT String FROM dbo.fnLocal_Split(@fault, ',')))
	--ORDER BY rd.PUDesc ,rd.TimeStamp ASC

	UPDATE rd
		SET LineStatus = pdd.LineStatus
	FROM #RejectsDetails rd
	cross apply (SELECT TOP 1
			LineStatus
		FROM [dbo].[OpsDB_Production_Data]	pd (NOLOCK)
		WHERE rd.PLId = pd.PLId
			AND rd.Timestamp	> pd.StartTime
			AND rd.TimeStamp	<= pd.EndTime) pdd

	IF @excludeNPT = 1
	BEGIN
		DELETE rd
		FROM #RejectsDetails rd
		WHERE rd.LineStatus NOT LIKE '%' + @strNPTDet + '%'
	END
END
ELSE IF @MajorGroupBy = 'Line'
BEGIN
	INSERT INTO #RejectsDetails
		(
		Timestamp
		,Amount
		,PLDesc
		,PUDesc
		,Fault
		,Location
		,Reason1
		,Comments
		,ShiftDesc
		,TeamDesc
		,ProdDay
		--,LineStatus	
		,ProdCode
		,ProdDesc
		,Units
		,PUId
		,PLId)
	SELECT
		rd.Timestamp
      , rd.Amount
      , rd.PLDesc
      , rd.PUDesc
      , rd.Fault
      , rd.Location
      , rd.Reason1
      , rd.Comments
      , rd.ShiftDesc
      , rd.TeamDesc
	  , CASE WHEN rd.Timestamp > CAST(CONCAT(CAST(rd.Timestamp AS DATE), ' ', CAST(e.EndTime AS TIME(0))) AS DATETIME)
			THEN CAST(rd.Timestamp AS DATE)
			ELSE DATEADD(DAY, -1, CAST(rd.Timestamp AS DATE))
	   END
      --,pd.LineStatus
      , rd.ProdCode
      , rd.ProdDesc
      , rd.Units
	  , rd.PUId
	  , rd.PLId
	FROM #Equipment		e
	JOIN [dbo].[OpsDB_Reject_Data]			rd (NOLOCK) ON rd.PLId = e.PLId
														--AND rd.PUID = e.PUId
														AND rd.Timestamp	> e.StartTime
														--AND rd.Timestamp	<= e.EndTime

	WHERE 1=1
		AND rd.Timestamp	<= e.EndTime
		AND ((	@shift IS NULL
		OR @shift = ''
		OR @shift = 'All'
		)
		OR rd.ShiftDesc IN (
			SELECT String
		FROM dbo.fnLocal_Split(@shift, ',')
	))
		AND ((	@crew IS NULL
		OR @crew = ''
		OR @crew = 'All'
		)
		OR rd.TeamDesc IN (
			SELECT String
		FROM dbo.fnLocal_Split(@crew, ',')
	))
		AND ((	@location IS NULL
		OR @location = ''
		OR @location = 'All'
		)
		OR rd.Location IN (
			SELECT String
		FROM dbo.fnLocal_Split(@location, ',')
	))
	AND (@eventReasons = '' OR rd.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	AND (@fault = '' OR rd.Fault IN (SELECT String FROM dbo.fnLocal_Split(@fault, ',')))
	--ORDER BY rd.PLDesc,rd.TimeStamp

	UPDATE rd
		SET LineStatus = pdd.LineStatus
	FROM #RejectsDetails rd
	cross apply (SELECT TOP 1
			LineStatus
		FROM [dbo].[OpsDB_Production_Data]	pd (NOLOCK)
		WHERE rd.PLId = pd.PLId
			AND rd.Timestamp	> pd.StartTime
			AND rd.TimeStamp	<= pd.EndTime) pdd

	IF @excludeNPT = 1
	BEGIN
		DELETE rd
		FROM #RejectsDetails rd
		WHERE rd.LineStatus NOT LIKE '%' + @strNPTDet + '%'
	END
END

--Update scrap % from line dimension
IF (@TotalProduct = 0)
BEGIN
	UPDATE #RejectsDetails
		SET ScrapPerc = 0
END
ELSE
BEGIN
	UPDATE #RejectsDetails
		SET ScrapPerc = ISNULL(((CONVERT(float,Amount) * 100) / @TotalProduct),0)
END

--Update PercOfScrap % from line dimension
IF (@TotalScrap = 0)
BEGIN
	UPDATE #RejectsDetails
		SET PercOfScrap = 0
END
ELSE
BEGIN
	UPDATE #RejectsDetails
		SET PercOfScrap = ISNULL(((CONVERT(float,Amount) * 100) / @TotalScrap),0)
END

--Saving total events values
SELECT @TotalEvent = COUNT (*)
FROM #RejectsDetails

--Update EventsPerc
IF @TotalEvent > 0
BEGIN
	UPDATE #RejectsDetails
		SET EventsPerc = (CONVERT(float,100) / @TotalEvent)
END

--UPDATE Production day for User defined time option
IF @timeOption < 0
BEGIN
	SET @index = 1
	SET @i = 1 --RcdIdx
	SELECT @j = COUNT(*) FROM #Equipment 
	WHILE (@i <= @j)
	BEGIN
		SELECT @StartTimeAux = StartTime FROM #Equipment WHERE RcdIdx = @i
		SELECT @EndTimeAux = EndTime FROM #Equipment WHERE RcdIdx = @i
		SELECT @PUIdAux = PUId FROM #Equipment WHERE RcdIdx = @i
		SELECT @PLIdAux = PLId FROM #Equipment WHERE RcdIdx = @i
		SELECT @PUDescAux = PUDesc FROM #Equipment WHERE RcdIdx = @i
		SELECT @PLDescAux = PLDesc FROM #Equipment WHERE RcdIdx = @i
		SELECT @VSIdAux = VSId FROM #Equipment WHERE RcdIdx = @i
		SELECT @VSDescAux = ValueStreamDesc FROM #Equipment WHERE RcdIdx = @i
		SELECT @DayStart = DayStartTime FROM #Equipment WHERE RcdIdx = @i

		IF(@PUIdAux IS NOT NULL OR @PLIdAux IS NOT NULL)
		BEGIN
			
			SET @index = 0
			--Insert manually the first record
			SET @dtmProdDayStartAux = @StartTimeAux 
			SELECT @dtmProdDayEndAux = ISNULL((select top 1 EndTime from Auto_opsDataStore.dbo.Workcell_Dimension wd
			                    JOIN Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK) ON wd.PLId = l.PLId 
			                    JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
								where DATE_DIMENSION_DateId = 2 and wd.PLId IN (@PLIdAux)
			                    AND wd.Class = 1  AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayStartAux AS DATE)
							 order by StartTime desc), DATEADD(hh,24,@dtmProdDayStartAux)) --CAST(@DateAux AS DATETIME) + CAST(@DayStart AS DATETIME)
			SET @index = 1
			
			WHILE (	@dtmProdDayStartAux < @EndTimeAux)--@dtmEndTime )
			BEGIN		
				INSERT INTO @ProdDay (		
											ProdDayId		,
											StartTime		,
											EndTime			,
											ProdDay			,
											PLId			,
											PLDesc			,
											PUId			,
											PUDesc			,
											VSId			,
											ValueStreamDesc )
				SELECT						
											@index			,
											@dtmProdDayStartAux,
											@dtmProdDayEndAux,
											CAST(@dtmProdDayStartAux AS DATE),
											@PLIdAux			,
											@PLDescAux			,
											@PUIdAux			,
											@PUDescAux			,
											@VSIdAux			,
											@VSDescAux	
						
				SET @index = @index + 1
				SET @dtmProdDayStartAux = ISNULL((select top 1 StartTime from Auto_opsDataStore.dbo.Workcell_Dimension wd
		                            JOIN Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK) ON wd.PLId = l.PLId 
		                            JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
									where DATE_DIMENSION_DateId = 2 and wd.PLId IN (@PLIdAux)
		                            AND wd.Class = 1  AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayEndAux AS DATE)
								 order by StartTime desc), DATEADD(hh,24,@dtmProdDayStartAux))

				SET @dtmProdDayEndAux = ISNULL((select top 1 EndTime from Auto_opsDataStore.dbo.Workcell_Dimension wd
		                            JOIN Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK) ON wd.PLId = l.PLId 
		                            JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
									where DATE_DIMENSION_DateId = 2 and wd.PLId IN (@PLIdAux)
		                            AND wd.Class = 1  AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayEndAux AS DATE)
								 order by StartTime desc), DATEADD(hh,24,@dtmProdDayEndAux))

				--SELECT 'INSERTO ESTE ID',@PUIdAux, @dtmProdDayStartAux, @dtmProdDayEndAux, @EndTimeAux
			END
		END

		SET @i = @i+1
	END

	--UPDATE STATEMENT FOR PROD DAY ON #RejectsDetails
	UPDATE rd
		SET rd.ProdDay = (SELECT pd.ProdDay FROM @ProdDay pd WHERE rd.TimeStamp >= pd.StartTime AND rd.TimeStamp < pd.EndTime AND rd.PUId = pd.PUId)  
	FROM #RejectsDetails rd
END		

--Result set select
---------------------------------------------------------------------------------------------------
-- RS2: Build select statement - minor group is !Null or Null
---------------------------------------------------------------------------------------------------
IF(@MinorGroupBy = 'Null' OR @MinorGroupBy = '' OR @MinorGroupBy IS NULL)	-- If don't have any minor grouping
BEGIN
	SELECT Timestamp	
			, PLDesc		
			, PLId		
			, PUDesc		
			, Fault		
			, Location	
			, Reason1		
			, Comments	
			, ShiftDesc	
			, TeamDesc	
			, ProdDay		
			, LineStatus	
			, ProdCode	
			, ProdDesc	
			, ValueStream	
			, Units		
			, PUId	
			, Amount
			, '1' as EventCount	
			, ScrapPerc	
			, PercOfScrap
			, EventsPerc
	FROM #RejectsDetails
	ORDER BY PUDesc ,TimeStamp ASC
END
---------------------------------------------------------------------------------------------------
-- RS2: Build select statement - minor group is ProdDesc -> TeamDesc -> Reason1 -> Fault.
---------------------------------------------------------------------------------------------------
ELSE
BEGIN
	SET @commandSQL = 'INSERT INTO #Output ('+@MinorGroupBy+', EventCount ,Amount, ScrapPerc, PercOfScrap, EventsPerc) '+
	'SELECT '+@MinorGroupBy+', COUNT(*), SUM(Amount) as Amount, SUM(ScrapPerc) as ScrapPerc, SUM(PercOfScrap) as PercOfScrap, SUM(EventsPerc) as EventsPerc '+
	'FROM #RejectsDetails '+
	'GROUP BY ' + @MinorGroupBy +
	' ORDER BY ' + @MinorGroupBy +

	' SELECT Timestamp
			,Amount
			,EventCount
			,PLDesc		
			,PLId		
			,PUDesc		
			,Fault		
			,Location	
			,Reason1		
			,Comments	
			,ShiftDesc	
			,TeamDesc	
			,ProdDay		
			,LineStatus	
			,ProdCode	
			,ProdDesc	
			,ValueStream	
			,Units		
			,PUId		
			,ScrapPerc	
			,PercOfScrap
			,EventsPerc 
			FROM #Output'

	EXEC (@commandSQL)
END
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 3. Chart data
-- --------------------------------------------------------------------------------------------------------------------
SELECT
	CONVERT(DATE, rd.ProdDay)		AS 'Date'
		, SUM(rd.Amount)						AS 'Scrap'
FROM #RejectsDetails rd
GROUP BY CONVERT(DATE, rd.ProdDay)
ORDER BY Date ASC
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 4. Top 5 by Fault
-- --------------------------------------------------------------------------------------------------------------------
SELECT TOP 5
	SUM(rd.Amount)	AS 'CountFault'
		, rd.Fault			AS 'Fault'
FROM #RejectsDetails rd
GROUP BY rd.Fault
ORDER BY CountFault DESC

-- --------------------------------------------------------------------------------------------------------------------
-- Result set 5. Header Data
-- --------------------------------------------------------------------------------------------------------------------
SELECT
	(SELECT TOP 1
		SiteId
	FROM dbo.Line_Dimension WITH(NOLOCK)) AS 'Plant'
		, CONVERT(VARCHAR, StartTime, 120)		AS 'StartTime'
		, CONVERT(VARCHAR, EndTime, 120)			AS 'EndTime'
		, @timeOption							AS 'TimeOption'
		, CONVERT(VARCHAR, GETDATE(), 120)		AS 'ReportRun'
FROM #Equipment

DROP TABLE #RejectsDetails
DROP TABLE #Production
DROP TABLE #Equipment
DROP TABLE #Output
DROP TABLE #UserDefinedProduction
GO
GRANT  EXECUTE  ON [dbo].[spRptScrap]  TO OpDBWriter
GO
