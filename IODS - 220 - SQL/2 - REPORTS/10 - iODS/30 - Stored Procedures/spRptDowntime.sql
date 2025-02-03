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
		@SP_Name	= 'spRptDowntime',
		@Inputs		= 7, 
		@Version	= '2.1'  

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
				
DROP PROCEDURE [dbo].[spRptDowntime]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptDowntime
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Campana Damian - Arido Software
-- Date created			: 2018-04-24
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for the Downtimes Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-05-04		Campana Damian     		Initial Release
-- 1.1		2019-04-03		Campana Damian     		Add filter by Team and Shift
-- 1.2		2019-09-24		Gonzalo Luc				Added total planned and unplanned downtime columns on Details.
-- 1.3		2019-10-24		Gonzalo Luc				Use OVER () to calculate the schedule time for the entire selection
-- 1.4		2019-11-11		Gonzalo Luc				User defined feature for downtime report with KPI's.
-- 1.5		2019-12-20		Gonzalo Luc				Added validation for special case units with more than one line.
-- 1.6		2020-06-05		Leontes Alan			
-- 1.7		2020-06-09		Gonzalo Luc				Added the new fields to #UserDefinedProduction table.
-- 1.8		2020-07-01		Gonzalo Luc				Added Group by All.
-- 1.9		2020-07-03		Gonzalo Luc				Added Filter by Reason
-- 2.0		2020-10-02		Gonzalo Luc				Added M2P Fields to user defined tables
-- 2.1		2021-07-21		Gonzalo Luc				Fix User defined for grooming
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptDowntime]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
 --------------------------------------------------------------------------------------------------------------------
--DECLARE
	 @prodLineId	VARCHAR(MAX)	= NULL
	,@workCellId	VARCHAR(MAX)	= NULL
	,@timeOption	INT				= NULL
	,@excludeNPT	INT				= NULL
	,@groupBy		VARCHAR(50)		= NULL --workcell or line
	,@dtmStartTime	DATETIME
	,@dtmEndTime	DATETIME
	,@crew			VARCHAR(MAX)	= 'All'
	,@shift			VARCHAR(MAX)	= 'All'	
	,@eventReasons	NVARCHAR(MAX)

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
		,@strNPTDet				VARCHAR(50)
		,@startTime				DATETIME
		,@endTime				DATETIME
		,@i						INT
		,@j						INT
		,@k						INT
		,@l						INT
		,@teamAux				NVARCHAR(10)
		,@shiftAux				NVARCHAR(10)

		

	DECLARE 
		 @tbl_TimeOption		TABLE (startDate DATETIME, endDate DATETIME)

	DECLARE	@DowntimeKPI TABLE(
					TotalUptime					FLOAT	,
					TotalStops					INT		,
					TotalDowntime				FLOAT	,
					MinorStops					INT		,
					AvailabilityTotalDT			FLOAT	,
					AvailabilityUnplDT			FLOAT	,
					DowntimePctUnplanned		FLOAT	,
					LineStops					INT		,
					LineStopsUnplanned			INT		,
					MajorStops					INT		,
					MajorStopsDay				FLOAT	,
					MinorStopsDay				FLOAT	,
					BreakdownStops				INT		,
					BreakdownStopsDay			FLOAT	,
					UnplannedStops				INT		,
					UnplannedStopsDay			FLOAT	,
					PlannedStops				INT		,
					PlannedStopsDay				FLOAT	,
					MTBFUnplStops				FLOAT	,
					MTBFTotalStops				FLOAT	,
					MTTRTotalDT					FLOAT	,
					MTTRUnplDT					FLOAT	,
					ProcessFailures				INT		,
					ProcessFailuresDay			FLOAT	,
					ScheduledTime				FLOAT	,
					ProcessReliability			FLOAT	,
					RepairTime					FLOAT	,
					ReportedTime				FLOAT	,
					StopsDay					FLOAT	,
					UnplannedDowntime			FLOAT	,
					EditedStopsPct				FLOAT	)
--------------------------------------------------------------------------------------------------
if OBJECT_ID('tempdb..#UserDefinedDowntime') IS NOT NULL
BEGIN
	DROP TABLE #UserDefinedDowntime
END
CREATE TABLE #UserDefinedDowntime (
        TeamDesc						VARCHAR(25)    COLLATE DATABASE_DEFAULT ,
		ShiftDesc						VARCHAR(25)    COLLATE DATABASE_DEFAULT ,
		Status							VARCHAR(50)    COLLATE DATABASE_DEFAULT ,
		DeleteFlag          			INT     		,
		Starttime						DATETIME		,
		Endtime							DATETIME        ,
		TotalStops          			INT     		,
		Duration						FLOAT			,
		TotalUpdDowntime				FLOAT           ,
		TotalPlannedDowntime			FLOAT           ,
		TotalUpdStops					INT             ,
		MinorStops						INT             ,
		ProcFailures					INT             ,
		MajorStops						INT             ,
		Uptime  						FLOAT           ,
		MTBF							FLOAT           ,
		MTBFUpd							FLOAT           ,
		MTTR							FLOAT           ,
		UpsDTPRLoss						FLOAT           ,
		PlannedDTPRLoss					FLOAT           ,
		R0								FLOAT           ,
		R2								FLOAT           ,
		R210        					FLOAT		    ,
		R240							FLOAT           ,
		BreakDown						INT             ,
		MTTRUpd							FLOAT           ,
		UpdDownPerc						FLOAT           ,
		StopsDay						FLOAT           ,
		ProcFailuresDay					FLOAT           ,
		Availability_Unpl_DT			FLOAT           ,
		Availability_Planned_DT			FLOAT           ,
		Availability_Total_DT			FLOAT           ,
		MTBS							FLOAT           ,
		ACPStops						INT             ,
		ACPStopsDay         			FLOAT           ,
		RepairTimeT						INT             ,
		FalseStarts0					INT             ,
		FalseStarts0Per					FLOAT           ,
		FalseStartsT					INT             ,
		FalseStartsTPer					FLOAT           ,
		Survival240Rate					FLOAT           ,
		Survival240RatePer				FLOAT           ,
		EditedStops						INT             ,
		EditedStopsPer					FLOAT           ,
		TotalUpdStopDay     			FLOAT           ,
		StopsBDSDay						FLOAT           ,
		TotalPlannedStops				INT             ,
		TotalPlannedStopsDay			FLOAT           ,
		MajorStopsDay					FLOAT       	,
		MinorStopsDay					FLOAT       	,
		TotalStarvedStops				INT             ,
		TotalBlockedStops				INT             ,
		TotalStarvedDowntime			FLOAT           ,
		TotalBlockedDowntime			FLOAT           ,
		LineId							INT             ,
		WorkCellId						INT             ,
		DateId							INT             ,
		ProductId						INT             ,
		ProductCode						NVARCHAR(50)	COLLATE DATABASE_DEFAULT,
		Survival210Rate					FLOAT           ,
		Survival210RatePer				FLOAT           ,
		VSScheduledTime					FLOAT           ,
		VSPRLossPlanned					FLOAT           ,
		VSPRLossUnplanned				FLOAT           ,
		VSPRLossBreakdown				FLOAT			,
		DChangeOverAlltypesStops		INT				,  
		DChangeOverPackingCOStops		INT				,
		DChangeOverAlltypesDuration		INT				,  
		DChangeOverPackingCODuration	INT				,
		IdleTime						FLOAT			,
		ExcludedTime					FLOAT			,
		MAchineStopsDay					FLOAT			)

--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#UserDefinedProduction') IS NOT NULL
BEGIN
	DROP TABLE #UserDefinedProduction
END

CREATE TABLE #UserDefinedProduction					( 
			LineId					INT				,		
			WorkCellId				INT				,
			DateId					INT				,
			ProductId				INT				,
			ProductCode				NVARCHAR(50)	COLLATE DATABASE_DEFAULT,
			TeamDesc				NVARCHAR(25)	COLLATE DATABASE_DEFAULT,
			ShiftDesc				NVARCHAR(25)	COLLATE DATABASE_DEFAULT,
			Starttime				DATETIME		,
			DeleteFlag				INT				,
			BU						NVARCHAR(25)	COLLATE DATABASE_DEFAULT,
			Status					NVARCHAR(50)	COLLATE DATABASE_DEFAULT,
			EndTime					DATETIME		,
			GoodProduct				BIGINT			,
			TotalProduct			FLOAT			,
			TotalScrap				FLOAT			,
			ActualRate				FLOAT			,
			TargetRate				FLOAT			,
			ScheduleTime			FLOAT			,
			PR						FLOAT			,
			ScrapPer				FLOAT			,
			IdealRate				FLOAT			,
			STNU					FLOAT			,
			STNUPer					FLOAT			,
			BrandProjectPer			FLOAT			,
			EO_NonShippablePer 		FLOAT			,
			LineNotStaffedPer		FLOAT			,
			StartingScrap			INT				,
			RunningScrap			FLOAT			,
			StartingScrapPer		FLOAT			,
			RunningScrapPer			FLOAT			,
			PRAvailability			FLOAT			,
			Availability			FLOAT			,
			CapacityUtilization		FLOAT			,
			RateUtilization			FLOAT			,
			TotalCases				FLOAT			,
			RoomLoss				FLOAT			,
			MSU						FLOAT			,
			MSUExcDev				FLOAT			,
			ScheduleUtilization		FLOAT			,
			DownMSU					FLOAT			,
			StopsMSU				FLOAT			,
			RunEff					FLOAT			,
			PRRateLoss				FLOAT			,
			PRLossScrap				FLOAT			,
      		Area4LossPer			FLOAT			,
			VSNetProduction			FLOAT			,
			VSPR					FLOAT			,
			VSPRLossPer				FLOAT			,
			StatUnits				FLOAT			,
			ConvertedCases			BIGINT			,
			NetProduction			FLOAT			,
			StatCases				FLOAT			,
			TargetRateAdj			FLOAT			,
			NetProductionExcDev		FLOAT			,
			ScheduleTimeExcDev		FLOAT			,
			PR_Excl_PRInDev			FLOAT			,
			TargetRateExcDev		FLOAT			,
			ActualRateExcDev		FLOAT			,
			ProjConstructPerc		FLOAT			,
			STNUSchedVarPerc		FLOAT			,
		    StatFactor				FLOAT			)

--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Equipment') IS NOT NULL
BEGIN
	DROP TABLE #Equipment
END
CREATE TABLE #Equipment (
		RcdIdx						INT IDENTITY							,						
		PUId						INT										,
		PUDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		PLId						INT										,
		PLDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		VSId						INT										,
		ValueStreamDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		StartTime					DATETIME								,
		EndTime						DATETIME								,
		DayStartTime				TIME									)
-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------
	--EXEC [dbo].[spRptDowntime] 8, null, 7, 0, 'line'
	--EXEC [dbo].[spRptDowntime] 124, 0, 4, 0, 'line'
	
	--SELECT  

	--	 @prodLineId   = '11,9'
	--	,@workCellId   = '307'
	--	,@timeOption      = -1
	--	,@excludeNPT      = 0
	--	,@groupBy          = 'workcell' --workcell, line or All
	--	,@dtmStartTime 	= '2021-07-19 06:00:00'
	--	,@dtmEndTime  	= '2021-07-20 06:00:00'
	--	,@crew           = 'All'
	--	,@shift           = 'All'   
	--	,@eventReasons  = ''


----------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
----------------------------------------------------------------------------------------------------------------------
IF @groupBy = 'Line' 
BEGIN
	INSERT INTO #Equipment(
			PLId)
			SELECT String FROM fnLocal_Split(@prodLineId,',')
END
ELSE 
BEGIN
	INSERT INTO #Equipment(
			PUId)
			SELECT String FROM fnLocal_Split(@workCellId,',')
END		

-- --------------------------------------------------------------------------------------------------------------------
-- Update #Equipment table with all the needed values
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @groupBy = 'Line' 
BEGIN
	--update plid, VSId and pudesc 
	UPDATE e
		SET PLID = (SELECT PL_Id FROM dbo.Prod_Units_Base_syn WHERE PU_Id = e.PUId),
			VSId = (SELECT TOP 1 VSId FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId),
			PUDesc = (SELECT PU_Desc FROM dbo.Prod_Units_Base_syn WHERE PU_Id = e.PUId)
	FROM #Equipment e
	--update plid when groupby WorkCell
	IF @groupBy = 'workcell'
	BEGIN
		SELECT TOP 1 @prodLineId = PL_Id FROM dbo.Prod_Units_Base_syn WHERE PU_Id = @workCellId
	END
	--update valuestream desc
	UPDATE e
		SET ValuestreamDesc	= (SELECT LineDesc 
								FROM dbo.LINE_DIMENSION ld (NOLOCK)
								JOIN dbo.Workcell_Dimension wd (NOLOCK) ON ld.LineId = wd.VSId
								WHERE wd.PUId = e.PUId)
		FROM #Equipment e
	--Update Line Desc for Line major group
END
UPDATE e
	SET PLDesc	= (SELECT LineDesc FROM dbo.LINE_DIMENSION ld WHERE ld.PLId = e.PLId),
		DayStartTime = (SELECT CONVERT(TIME,ShiftStartTime) FROM dbo.LINE_DIMENSION ld WHERE ld.PLId = e.PLId)
	FROM #Equipment e

--Update Start and End time
IF @timeOption > 0
BEGIN
	--Update start time and end time if a time option is selected
	SELECT @strTimeOption = DateDesc 
	FROM [dbo].[DATE_DIMENSION] (NOLOCK)
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
--SELECT '#Equipment', * FROM #Equipment	

-- --------------------------------------------------------------------------------------------------------------------
-- Get NPT
-- --------------------------------------------------------------------------------------------------------------------
	SELECT	@strNPT = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'All' END)
	--PR Out: STNU
	--PR In:Line Normal
	--PR In:
	--PR Out:
	--NPT For Detais
	SELECT @strNPTDet = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'PR' END)
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 1. KPI's
-- --------------------------------------------------------------------------------------------------------------------
IF(@timeOption > 0)
BEGIN
	--IF ('Grooming' <> (SELECT BUId FROM dbo.LINE_DIMENSION ld (NOLOCK)
	--									JOIN dbo.WORKCELL_DIMENSION wcd (NOLOCK) ON wcd.PLId = ld.PLId
	--									WHERE wcd.PUId = @workCellId AND wcd.PLId = @PLId))
	IF @groupBy = 'workcell'
		BEGIN
		INSERT INTO @DowntimeKPI(
			TotalUptime			
			,TotalStops			
			,TotalDowntime		
			,MinorStops			
			,AvailabilityTotalDT	
			,AvailabilityUnplDT	
			,DowntimePctUnplanned
			,LineStops			
			,LineStopsUnplanned	
			,MajorStops			
			,MajorStopsDay		
			,MinorStopsDay		
			,BreakdownStops		
			,BreakdownStopsDay	
			,UnplannedStops		
			,UnplannedStopsDay	
			,PlannedStops		
			,PlannedStopsDay		
			,MTBFUnplStops		
			,MTBFTotalStops		
			,MTTRTotalDT			
			,MTTRUnplDT			
			,ProcessFailures		
			,ProcessFailuresDay	
			--,ScheduledTime		
			,RepairTime			
			,ReportedTime		
			,StopsDay			
			,UnplannedDowntime	
			,EditedStopsPct	)
		SELECT DISTINCT
			 ISNULL(Uptime,0)								--AS 'TotalUptime'
			,ISNULL(TotalStops,0)							--AS 'TotalStops'
			,ISNULL(Duration,0)								--AS 'TotalDowntime'
			,ISNULL(MinorStops,0)							--AS 'MinorStops'
			,ISNULL(Availability_Total_DT,0)				--AS 'AvailabilityTotalDT'
			,ISNULL(Availability_Unpl_DT,0)					--AS 'AvailabilityUnplDT'
			,ISNULL(UpdDownPerc,0)							--AS 'DowntimePctUnplanned'
			,ISNULL(TotalStops,0)							--AS 'LineStops'
			,ISNULL(TotalUpdStops,0)						--AS 'LineStopsUnplanned'
			,ISNULL(MajorStops,0)							--AS 'MajorStops'
			,ISNULL(MajorStopsDay,0)						--AS 'MajorStopsDay'
			,ISNULL(MinorStopsDay,0)						--AS 'MinorStopsDay'
			,ISNULL(BreakDown,0)							--AS 'BreakdownStops'
			,ISNULL(StopsBDSDay,0)							--AS 'BreakdownStopsDay'
			,ISNULL(TotalUpdStops,0)						--AS 'UnplannedStops'
			,ISNULL(TotalUpdStopDay,0)						--AS 'UnplannedStopsDay'
			,ISNULL(TotalPlannedStops,0)					--AS 'PlannedStops'
			,ISNULL(TotalPlannedStopsDay,0)					--AS 'PlannedStopsDay'
			,ISNULL(MTBFUpd,0)								--AS 'MTBFUnplStops'
			,ISNULL(MTBF,0)									--AS 'MTBFTotalStops'
			,ISNULL(MTTR,0)									--AS 'MTTRTotalDT'
			,ISNULL(MTTRUpd,0)								--AS 'MTTRUnplDT'
			,ISNULL(ProcFailures,0)							--AS 'ProcessFailures'
			,ISNULL(ProcFailuresDay,0)						--AS 'ProcessFailuresDay'
			--,ISNULL(ScheduleTime,0)						--AS 'ScheduledTime'
			,ISNULL(RepairTimeT,0)							--AS 'RepairTime'
			,DATEDIFF(SECOND,e.StartTime,e.EndTime) / 60.0	--AS 'ReportedTime'
			,ISNULL(StopsDay,0)								--AS 'StopsDay'
			,ISNULL(TotalUpdDowntime,0)						--AS 'UnplannedDowntime'
			,ISNULL(EditedStopsPer,0)						--AS 'EditedStopsPct'
		FROM #Equipment e
		JOIN [dbo].[WorkCell_Dimension] wcd (NOLOCK) ON e.PUId = wcd.PUId
		JOIN [dbo].[LINE_DIMENSION]		ld 	(NOLOCK) ON wcd.plId = ld.plid
		JOIN [dbo].[FACT_DOWNTIME]		fd  (NOLOCK) ON fd.WORKCELL_DIMENSION_WorkCellId = wcd.WorkCellId
														AND	fd.LINE_DIMENSION_LineId = ld.LineId
		WHERE 1=1
		AND fd.DATE_DIMENSION_DateId	 = @timeOption
		AND fd.LineStatus	LIKE '%' + @strNPT + '%'
		AND fd.StartTime				>= e.StartTime
		AND fd.EndTime					<= e.EndTime
		--AND fd.ShiftDesc = 'All'
		--AND fd.TeamDesc = 'All'
		AND fd.ShiftDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@shift, ','))
		AND fd.TeamDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@crew, ','))

	
		UPDATE @DowntimeKPI
			SET ScheduledTime = fp.ScheduleTime,
				ProcessReliability = fp.PR
													
		FROM [dbo].[FACT_PRODUCTION] fp (NOLOCK)
		JOIN [dbo].[LINE_DIMENSION]		ld 	(NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
		JOIN [dbo].[WorkCell_Dimension] wcd	  (NOLOCK) ON ld.PLId = wcd.PLId
		JOIN #Equipment e ON wcd.PUId = e.PUId
		WHERE fp.DATE_DIMENSION_DateId	 = @timeOption
		AND fp.LineStatus	LIKE '%' + @strNPT + '%'								
		AND fp.StartTime	>= e.StartTime
		AND fp.EndTime		<= e.EndTime
		--AND fp.ShiftDesc = 'All'
		--AND fp.TeamDesc = 'All'
		AND fp.ShiftDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@shift, ','))
		AND fp.TeamDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@crew, ','))
		
		
	END
	ELSE IF @groupBy = 'Line'
	BEGIN
		INSERT INTO @DowntimeKPI(
			TotalUptime			
			,TotalStops			
			,TotalDowntime		
			,MinorStops			
			,AvailabilityTotalDT	
			,AvailabilityUnplDT	
			,DowntimePctUnplanned
			,LineStops			
			,LineStopsUnplanned	
			,MajorStops			
			,MajorStopsDay		
			,MinorStopsDay		
			,BreakdownStops		
			,BreakdownStopsDay	
			,UnplannedStops		
			,UnplannedStopsDay	
			,PlannedStops		
			,PlannedStopsDay		
			,MTBFUnplStops		
			,MTBFTotalStops		
			,MTTRTotalDT			
			,MTTRUnplDT			
			,ProcessFailures		
			,ProcessFailuresDay	
			--,ScheduledTime		
			,RepairTime			
			,ReportedTime		
			,StopsDay			
			,UnplannedDowntime	
			,EditedStopsPct	)
		SELECT DISTINCT
			 ISNULL(Uptime,0)								--AS 'TotalUptime'
			,ISNULL(TotalStops,0)							--AS 'TotalStops'
			,ISNULL(Duration,0)								--AS 'TotalDowntime'
			,ISNULL(MinorStops,0)							--AS 'MinorStops'
			,ISNULL(Availability_Total_DT,0)				--AS 'AvailabilityTotalDT'
			,ISNULL(Availability_Unpl_DT,0)					--AS 'AvailabilityUnplDT'
			,ISNULL(UpdDownPerc,0)							--AS 'DowntimePctUnplanned'
			,ISNULL(TotalStops,0)							--AS 'LineStops'
			,ISNULL(TotalUpdStops,0)						--AS 'LineStopsUnplanned'
			,ISNULL(MajorStops,0)							--AS 'MajorStops'
			,ISNULL(MajorStopsDay,0)						--AS 'MajorStopsDay'
			,ISNULL(MinorStopsDay,0)						--AS 'MinorStopsDay'
			,ISNULL(BreakDown,0)							--AS 'BreakdownStops'
			,ISNULL(StopsBDSDay,0)							--AS 'BreakdownStopsDay'
			,ISNULL(TotalUpdStops,0)						--AS 'UnplannedStops'
			,ISNULL(TotalUpdStopDay,0)						--AS 'UnplannedStopsDay'
			,ISNULL(TotalPlannedStops,0)					--AS 'PlannedStops'
			,ISNULL(TotalPlannedStopsDay,0)					--AS 'PlannedStopsDay'
			,ISNULL(MTBFUpd,0)								--AS 'MTBFUnplStops'
			,ISNULL(MTBF,0)									--AS 'MTBFTotalStops'
			,ISNULL(MTTR,0)									--AS 'MTTRTotalDT'
			,ISNULL(MTTRUpd,0)								--AS 'MTTRUnplDT'
			,ISNULL(ProcFailures,0)							--AS 'ProcessFailures'
			,ISNULL(ProcFailuresDay,0)						--AS 'ProcessFailuresDay'
			--,ISNULL(ScheduleTime,0)						--AS 'ScheduledTime'
			,ISNULL(RepairTimeT,0)							--AS 'RepairTime'
			,DATEDIFF(SECOND,e.StartTime,e.EndTime) / 60.0	--AS 'ReportedTime'
			,ISNULL(StopsDay,0)								--AS 'StopsDay'
			,ISNULL(TotalUpdDowntime,0)						--AS 'UnplannedDowntime'
			,ISNULL(EditedStopsPer,0)						--AS 'EditedStopsPct'
		FROM #Equipment e
		JOIN [dbo].[LINE_DIMENSION]		ld 	(NOLOCK) ON e.PLId = ld.PLId
		JOIN [dbo].[FACT_DOWNTIME]		fd  (NOLOCK) ON fd.LINE_DIMENSION_LineId = ld.LineId
		WHERE 1=1
		AND fd.DATE_DIMENSION_DateId	 = @timeOption
		AND fd.LineStatus	LIKE '%' + @strNPT + '%'
		AND fd.StartTime				>= e.StartTime
		AND fd.EndTime					<= e.EndTime
		AND fd.WORKCELL_DIMENSION_WorkCellId = 0
		AND fd.ShiftDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@shift, ','))
		AND fd.TeamDesc
			IN (SELECT String
			FROM dbo.fnLocal_Split(@crew, ','))

		UPDATE @DowntimeKPI
			SET ScheduledTime = fp.ScheduleTime,
				ProcessReliability = fp.PR
			 
			FROM #Equipment e
			JOIN [dbo].[LINE_DIMENSION]		ld 	(NOLOCK) ON e.PLId = ld.PLId
			JOIN [dbo].[FACT_PRODUCTION]	fp  (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
			WHERE fp.DATE_DIMENSION_DateId	 = @timeOption
			AND fp.LineStatus	LIKE '%' + @strNPT + '%'								
			AND fp.StartTime	>= e.StartTime
			AND fp.EndTime		<= e.EndTime
			--AND fp.ShiftDesc = 'All'
			--AND fp.TeamDesc = 'All'
			AND fp.ShiftDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@shift, ','))
			AND fp.TeamDesc
				IN (SELECT String
				FROM dbo.fnLocal_Split(@crew, ','))

			
	END
	ELSE
	BEGIN
	
		SELECT TOP 1 @startTime = StartTime FROM #Equipment
		SELECT TOP 1 @endTime = EndTime FROM #Equipment
		IF (SELECT COUNT(*) FROM dbo.LINE_DIMENSION WHERE PLId IN (SELECT String FROM fnLocal_Split(@prodLineId,',')) AND UPPER(BUId) = UPPER('Family Care')) = 0 
		BEGIN
		INSERT INTO #UserDefinedProduction
		EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
													, @startTime
													, @endTime
													, @prodLineId
													, @workCellId
													, @strNPT
													, @shift
													, @crew
													,'line'
													, 0
		END
		
		--Downtime AGG
		INSERT INTO #UserDefinedDowntime
		EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
													, @startTime
													, @endTime
													, @prodLineId
													, @workCellId
													, @strNPT
													, @shift
													, @crew
													,'unit'

		

		--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction
		--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime

		INSERT INTO @DowntimeKPI(
			TotalUptime			
			,TotalStops			
			,TotalDowntime		
			,MinorStops			
			,AvailabilityTotalDT	
			,AvailabilityUnplDT	
			,DowntimePctUnplanned
			,LineStops			
			,LineStopsUnplanned	
			,MajorStops			
			,MajorStopsDay		
			,MinorStopsDay		
			,BreakdownStops		
			,BreakdownStopsDay	
			,UnplannedStops		
			,UnplannedStopsDay	
			,PlannedStops		
			,PlannedStopsDay		
			,MTBFUnplStops		
			,MTBFTotalStops		
			,MTTRTotalDT			
			,MTTRUnplDT			
			,ProcessFailures		
			,ProcessFailuresDay		
			,RepairTime			
			,ReportedTime		
			,StopsDay			
			,UnplannedDowntime	
			,EditedStopsPct	
			,ScheduledTime
			,ProcessReliability)
		SELECT DISTINCT
			 SUM(ISNULL(fd.Uptime,0))							
			,SUM(ISNULL(fd.TotalStops,0))						
			,SUM(ISNULL(fd.Duration,0))							
			,SUM(ISNULL(fd.MinorStops,0))						
			,AVG(ISNULL(fd.Availability_Total_DT,0))				
			,AVG(ISNULL(fd.Availability_Unpl_DT,0))				
			,AVG(ISNULL(fd.UpdDownPerc,0))						
			,SUM(ISNULL(fd.TotalStops,0))						
			,SUM(ISNULL(fd.TotalUpdStops,0))						
			,SUM(ISNULL(fd.MajorStops,0))						
			,SUM(ISNULL(fd.MajorStopsDay,0))						
			,SUM(ISNULL(fd.MinorStopsDay,0))						
			,SUM(ISNULL(fd.BreakDown,0))						
			,SUM(ISNULL(fd.StopsBDSDay,0))						
			,SUM(ISNULL(fd.TotalUpdStops,0))						
			,SUM(ISNULL(fd.TotalUpdStopDay,0))					
			,SUM(ISNULL(fd.TotalPlannedStops,0))					
			,SUM(ISNULL(fd.TotalPlannedStopsDay,0))				
			,SUM(ISNULL(fd.MTBFUpd,0))							
			,SUM(ISNULL(fd.MTBF,0))								
			,SUM(ISNULL(fd.MTTR,0))								
			,SUM(ISNULL(fd.MTTRUpd,0))							
			,SUM(ISNULL(fd.ProcFailures,0))						
			,SUM(ISNULL(fd.ProcFailuresDay,0))					
			,SUM(ISNULL(fd.RepairTimeT,0))						
			,SUM(DATEDIFF(SECOND,@startTime,@endTime) / 60.0)	
			,SUM(ISNULL(fd.StopsDay,0))							
			,SUM(ISNULL(fd.TotalUpdDowntime,0))					
			,AVG(ISNULL(fd.EditedStopsPer,0))					
			,SUM(ISNULL(ScheduleTime,0))							
			,CASE WHEN SUM(MSU) = 0 OR SUM (MSU / PR) = 0 THEN 0 ELSE (SUM(MSU * 1000) / SUM((MSU * 1000) / PR)) END	
										
		FROM [dbo].[LINE_DIMENSION]		ld 	(NOLOCK) 
		JOIN #UserDefinedDowntime		fd  (NOLOCK) ON fd.LineId = ld.LineId
		LEFT JOIN #UserDefinedProduction		fp	(NOLOCK) ON fp.LineId = ld.LineId
													AND fp.LineId = fp.LineId
													AND fp.TeamDesc = fp.TeamDesc
													AND fp.ShiftDesc = fp.ShiftDesc
													AND PR > 0
													AND MSU > 0
		
	END
END
ELSE
BEGIN
	IF (SELECT COUNT(*) FROM dbo.LINE_DIMENSION WHERE PLId IN (SELECT String FROM fnLocal_Split(@prodLineId,',')) AND UPPER(BUId) = UPPER('Family Care')) = 0 
		BEGIN
		
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @prodLineId
														, @workCellId
														, @strNPT
														, @shift
														, @crew
														,'line'
														, 0
		END
	IF @groupBy = 'workcell' OR @groupBy = 'All'
	BEGIN

		--Downtime AGG
		INSERT INTO #UserDefinedDowntime
		EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
													, @dtmStartTime
													, @dtmEndTime
													, @prodLineId
													, @workCellId
													, @strNPT
													, @shift
													, @crew
													,'unit'

	END
	ELSE
	BEGIN

		--Downtime AGG
		INSERT INTO #UserDefinedDowntime
		EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
													, @dtmStartTime
													, @dtmEndTime
													, @prodLineId
													, @workCellId
													, @strNPT
													, @shift
													, @crew
													,'line'
	END

		--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction
		--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime

		INSERT INTO @DowntimeKPI(
			TotalUptime			
			,TotalStops			
			,TotalDowntime		
			,MinorStops			
			,AvailabilityTotalDT	
			,AvailabilityUnplDT	
			,DowntimePctUnplanned
			,LineStops			
			,LineStopsUnplanned	
			,MajorStops			
			,MajorStopsDay		
			,MinorStopsDay		
			,BreakdownStops		
			,BreakdownStopsDay	
			,UnplannedStops		
			,UnplannedStopsDay	
			,PlannedStops		
			,PlannedStopsDay		
			,MTBFUnplStops		
			,MTBFTotalStops		
			,MTTRTotalDT			
			,MTTRUnplDT			
			,ProcessFailures		
			,ProcessFailuresDay		
			,RepairTime			
			,ReportedTime		
			,StopsDay			
			,UnplannedDowntime	
			,EditedStopsPct	
			,ScheduledTime
			,ProcessReliability)
		SELECT DISTINCT
			 SUM(ISNULL(fd.Uptime,0))							
			,SUM(ISNULL(fd.TotalStops,0))						
			,SUM(ISNULL(fd.Duration,0))							
			,SUM(ISNULL(fd.MinorStops,0))						
			,AVG(ISNULL(fd.Availability_Total_DT,0))				
			,AVG(ISNULL(fd.Availability_Unpl_DT,0))				
			,AVG(ISNULL(fd.UpdDownPerc,0))						
			,SUM(ISNULL(fd.TotalStops,0))						
			,SUM(ISNULL(fd.TotalUpdStops,0))						
			,SUM(ISNULL(fd.MajorStops,0))						
			,SUM(ISNULL(fd.MajorStopsDay,0))						
			,SUM(ISNULL(fd.MinorStopsDay,0))						
			,SUM(ISNULL(fd.BreakDown,0))						
			,SUM(ISNULL(fd.StopsBDSDay,0))						
			,SUM(ISNULL(fd.TotalUpdStops,0))						
			,SUM(ISNULL(fd.TotalUpdStopDay,0))					
			,SUM(ISNULL(fd.TotalPlannedStops,0))					
			,SUM(ISNULL(fd.TotalPlannedStopsDay,0))				
			,SUM(ISNULL(fd.MTBFUpd,0))							
			,SUM(ISNULL(fd.MTBF,0))								
			,SUM(ISNULL(fd.MTTR,0))								
			,SUM(ISNULL(fd.MTTRUpd,0))							
			,SUM(ISNULL(fd.ProcFailures,0))						
			,SUM(ISNULL(fd.ProcFailuresDay,0))					
			,SUM(ISNULL(fd.RepairTimeT,0))						
			,SUM(DATEDIFF(SECOND,@dtmStartTime,@dtmEndTime) / 60.0)	
			,SUM(ISNULL(fd.StopsDay,0))							
			,SUM(ISNULL(fd.TotalUpdDowntime,0))					
			,AVG(ISNULL(fd.EditedStopsPer,0))					
			,SUM(ISNULL(ScheduleTime,0))							
			,CASE WHEN SUM(MSU) = 0 OR SUM (MSU / PR) = 0 THEN 0 ELSE (SUM(MSU * 1000) / SUM((MSU * 1000) / PR)) END	
										
		FROM [dbo].[LINE_DIMENSION]		ld 	(NOLOCK) 
		JOIN #UserDefinedDowntime		fd  (NOLOCK) ON fd.LineId = ld.LineId
		LEFT JOIN #UserDefinedProduction		fp	(NOLOCK) ON fp.LineId = ld.LineId
													AND fp.LineId = fp.LineId
													AND fp.TeamDesc = fp.TeamDesc
													AND fp.ShiftDesc = fp.ShiftDesc
													AND PR > 0
													AND MSU > 0
		

		
	
END

SELECT 
		TotalUptime			
		,TotalStops			
		,TotalDowntime		
		,MinorStops			
		,AvailabilityTotalDT	
		,AvailabilityUnplDT	
		,DowntimePctUnplanned
		,LineStops			
		,LineStopsUnplanned	
		,MajorStops			
		,MajorStopsDay		
		,MinorStopsDay		
		,BreakdownStops		
		,BreakdownStopsDay	
		,UnplannedStops		
		,UnplannedStopsDay	
		,PlannedStops		
		,PlannedStopsDay		
		,MTBFUnplStops		
		,MTBFTotalStops		
		,MTTRTotalDT			
		,MTTRUnplDT			
		,ProcessFailures		
		,ProcessFailuresDay	
		,ScheduledTime		
		,ProcessReliability
		,RepairTime			
		,ReportedTime		
		,StopsDay			
		,UnplannedDowntime	
		,EditedStopsPct
 FROM @DowntimeKPI

-- --------------------------------------------------------------------------------------------------------------------
-- Result set 2. Detail Grid
-- --------------------------------------------------------------------------------------------------------------------
IF @groupBy = 'workcell' OR @groupBy = 'All'
BEGIN
	SELECT 
		 od.StartTime		AS 'StartTime'
		,od.EndTime			AS 'EndTime'
		,od.Duration		AS 'Downtime'
		,od.Uptime			AS 'Uptime'
		,od.LineGroup		AS 'ValueStream'
		,DeptDesc			AS 'Area'
		,od.PLId
		,od.PLDesc			AS 'ProductionLine'
		,od.PUId
		,od.PUDesc			AS 'WorkCell'
		,od.Fault			AS 'Fault'
		,od.Location		AS 'Location'
		,od.Reason1			AS 'ReasonLevel1'
		,od.Reason2			AS 'ReasonLevel2'
		,od.Reason3			AS 'ReasonLevel3'
		,od.Reason4			AS 'ReasonLevel4'
		,od.Action1			AS 'ActionLevel1'
		,od.Action2			AS 'ActionLevel2'
		,od.Action3			AS 'ActionLevel3'
		,od.Action4			AS 'ActionLevel4'
		,od.Reason1Category	AS 'Reason1Category'
		,od.Reason2Category	AS 'Reason2Category'
		,od.Reason3Category	AS 'Reason3Category'
		,od.Reason4Category	AS 'Reason4Category'
		,od.Comment_Rtf		AS 'Comments'
		,od.ShiftDesc		AS 'Shift'
		,od.TeamDesc		AS 'Team'
		,od.ProductionDay	AS 'ProductionDay'
		,od.LineStatus		AS 'ProductionStatus'
		,od.ProdCode		AS 'ProductionCode'
		,od.ProdDesc		AS 'ProductDescription'
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
		,SUM(ISNULL((od.Uptime + od.Duration),0)) OVER () AS 'ScheduleTime'
		,CASE	WHEN od.Planned = 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalPlannedDowntime'
		,CASE	WHEN od.Planned <> 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalUnplPlannedDowntime'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PUId = od.PUId
	JOIN dbo.Line_Dimension ld (NOLOCK) ON e.PLId = ld.PLId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND DeleteFlag		= 0
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	--AND IsContraint = 1
	ORDER BY od.PUDesc
			--,ProductionDay
			,od.StartTime
END
ELSE
BEGIN
	SELECT 
		 od.StartTime		AS 'StartTime'
		,od.EndTime			AS 'EndTime'
		,od.Duration		AS 'Downtime'
		,od.Uptime			AS 'Uptime'
		,od.LineGroup		AS 'ValueStream'
		,DeptDesc			AS 'Area'
		,od.PLId
		,od.PLDesc			AS 'ProductionLine'
		,od.PUId
		,od.PUDesc			AS 'WorkCell'
		,od.Fault			AS 'Fault'
		,od.Location		AS 'Location'
		,od.Reason1			AS 'ReasonLevel1'
		,od.Reason2			AS 'ReasonLevel2'
		,od.Reason3			AS 'ReasonLevel3'
		,od.Reason4			AS 'ReasonLevel4'
		,od.Action1			AS 'ActionLevel1'
		,od.Action2			AS 'ActionLevel2'
		,od.Action3			AS 'ActionLevel3'
		,od.Action4			AS 'ActionLevel4'
		,od.Reason1Category	AS 'Reason1Category'
		,od.Reason2Category	AS 'Reason2Category'
		,od.Reason3Category	AS 'Reason3Category'
		,od.Reason4Category	AS 'Reason4Category'
		,od.Comment_Rtf		AS 'Comments'
		,od.ShiftDesc		AS 'Shift'
		,od.TeamDesc		AS 'Team'
		,od.ProductionDay	AS 'ProductionDay'
		,od.LineStatus		AS 'ProductionStatus'
		,od.ProdCode		AS 'ProductionCode'
		,od.ProdDesc		AS 'ProductDescription'
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
		,SUM(ISNULL((od.Uptime + od.Duration),0)) OVER () AS 'ScheduleTime'
		,CASE	WHEN od.Planned = 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalPlannedDowntime'
		,CASE	WHEN od.Planned <> 1 THEN ISNULL(od.Duration,0) ELSE 0 END AS 'TotalUnplPlannedDowntime'
	FROM #Equipment e
	JOIN [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) ON e.PLId = od.PLId
	JOIN dbo.Line_Dimension ld (NOLOCK) ON e.PLId = ld.PLId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND DeleteFlag		= 0
	AND IsContraint = 1
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	ORDER BY od.PUDesc
			--,ProductionDay
			,od.StartTime
END

-- --------------------------------------------------------------------------------------------------------------------
-- Result set 3. Chart data
-- --------------------------------------------------------------------------------------------------------------------
IF @groupBy = 'workcell' OR @groupBy = 'All'
BEGIN
	SELECT 
		 od.ProductionDay						AS 'Date'
		,SUM(od.Duration)					AS 'Downtime'
		,SUM(od.Uptime)						AS 'Uptime'
		,SUM(od.DTStatus)					AS 'Stops'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PUId = od.PUId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND od.DeleteFlag		= 0
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	--AND IsContraint = 1
	GROUP BY od.ProductionDay
END
ELSE
BEGIN
	SELECT 
		 od.ProductionDay						AS 'Date'
		,SUM(od.Duration)					AS 'Downtime'
		,SUM(od.Uptime)						AS 'Uptime'
		,SUM(od.DTStatus)					AS 'Stops'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PLId = od.PLId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND IsContraint = 1
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	GROUP BY od.ProductionDay	
END
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 4. Top 5 by Reason 1
-- --------------------------------------------------------------------------------------------------------------------
IF @groupBy = 'workcell' OR @groupBy = 'All'
BEGIN
	SELECT TOP 5
		 COUNT(od.Reason1)	AS 'CountReason1'
		,od.Reason1			AS 'ReasonLevel1'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PUId = od.PUId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	--AND IsContraint = 1
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	GROUP BY od.Reason1
	ORDER BY CountReason1 DESC, ReasonLevel1
END
ELSE
BEGIN
	SELECT TOP 5
		 COUNT(od.Reason1)	AS 'CountReason1'
		,od.Reason1			AS 'ReasonLevel1'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PLId = od.PLId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND IsContraint = 1
	AND od.DeleteFlag		= 0
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	GROUP BY od.Reason1
	ORDER BY CountReason1 DESC, ReasonLevel1
END
-- --------------------------------------------------------------------------------------------------------------------
-- Result set 5. Top 5 by Fault
-- --------------------------------------------------------------------------------------------------------------------
IF @groupBy = 'workcell' OR @groupBy = 'All'
BEGIN
	SELECT TOP 5
		 COUNT(od.Fault)	AS 'CountFault'
		,od.Fault			AS 'Fault'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PUId = od.PUId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	--AND IsContraint = 1
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	GROUP BY od.Fault
	ORDER BY CountFault DESC
END
ELSE
BEGIN
	SELECT TOP 5
		 COUNT(od.Fault)	AS 'CountFault'
		,od.Fault			AS 'Fault'
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) 
	JOIN #Equipment e ON e.PLId = od.PLId
	WHERE 1=1
	AND (od.LineStatus	LIKE '%' + @strNPTDet + '%')
	AND od.StartTime	>= e.StartTime
	AND od.EndTime		<= e.EndTime
	AND ((od.StartTime <> e.StartTime AND od.EndTime <> e.StartTime) OR od.Duration <> 0)
	AND IsContraint = 1
	AND (@shift = 'All' OR
		od.ShiftDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@shift, ','))
	)
	AND (@crew = 'All' OR
		od.TeamDesc
		IN (SELECT String
		FROM dbo.fnLocal_Split(@crew, ','))
	)
	AND (@eventReasons = '' OR od.Reason1 IN (SELECT String FROM dbo.fnLocal_Split(@eventReasons, ',')))
	GROUP BY od.Fault
	ORDER BY CountFault DESC
END

-- --------------------------------------------------------------------------------------------------------------------
-- Result set 6. Header Data
-- --------------------------------------------------------------------------------------------------------------------
	SELECT
		(SELECT TOP 1 SiteId 
		  FROM dbo.Line_Dimension WITH(NOLOCK)) AS 'Plant'
		,CONVERT(VARCHAR, StartTime, 120)		AS 'StartTime'
		,CONVERT(VARCHAR, EndTime, 120)			AS 'EndTime'
		,@timeOption							AS 'TimeOption'
		,CONVERT(VARCHAR, GETDATE(), 120)		AS 'ReportRun'
	FROM #Equipment


GO
GRANT  EXECUTE  ON [dbo].[spRptDowntime]  TO OpDBWriter
GO