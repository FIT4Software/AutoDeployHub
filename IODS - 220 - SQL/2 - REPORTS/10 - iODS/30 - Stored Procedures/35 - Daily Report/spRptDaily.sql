USE Auto_opsDataStore

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
		@SP_Name	= 'spRptDaily',
		@Inputs		= 8, 
		@Version	= '4.5'  

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
				
DROP PROCEDURE [dbo].[spRptDaily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptDaily
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-07-17
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for Daily Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-07-17		Gonzalo Luc     		Initial Release
-- 1.1		2019-04-03		Gustavo Conde			Add KPI to output (Area4lossPer, ConvertedCases)
-- 1.2		2019-06-03		Gonzalo Luc				Update formulas for TOTAL column: PR, Scrap %, Survival Rate 210/240 %, Room Loss
-- 1.3		2019-07-02		Gonzalo Luc				Update formula TOTAL PR to avoid divided by zero error.
-- 1.4		2019-08-13		Gonzalo Luc				Added PR Rate Loss KPI, changed PR formula for TOTAL TOTAL to use MSU instead of good Product.
-- 1.5		2019-09-04		Gonzalo Luc				Change R0 formula for totals and PR Rate Loss formula for totals.
-- 1.6		2019-10-02		Gonzalo Luc				Added User Defined feature.
-- 1.7		2019-10-17		Gonzalo Luc				Added Flexible Variables KPI's
-- 1.8		2019-11-04		Gonzalo Luc				Added new grouping Line/Product
-- 1.9		2019-11-12		Gonzalo Luc				Change formula PR Loss Planned DT and PR Loss Unplanned DT.
-- 2.0		2019-11-22		Martin Casalis			Use Target Rate when Ideal Rate is 0 for CU and SU
-- 2.1		2019-12-16		Gonzalo Luc				Fix flex variables query to get only the ones in KPI_Dimension.
-- 2.2		2019-12-17		Gonzalo Luc				Fix flex variables for minor group Product.
-- 2.3		2020-01-14		Gonzalo Luc				Change minorGroupId field from int to NVARCHAR(255) to address non-numeric prod codes-
-- 2.4		2020-01-15		Gonzalo Luc				Added COLLATE DATABASE_DEFAULT to all fields for 2 byte databases.
-- 2.5		2020-03-02		Gonzalo Luc				Change on Total Group, if only one line is selected copy what existe in Major Group.
-- 2.6		2020-03-09		Gonzalo Luc				Fix Major Group Prod Day for PR calculation, use NetProduction instead of GoodProduct / Target Rate
-- 2.7		2020-04-20		Gonzalo Luc				Add PR Excluded PR In Development KPI.
-- 2.8		2020-06-12		Ivan Corica				Change formula PR on Major for formula PR of Total
-- 2.9      2020-07-08      Alvaro Palacios         Flexible variables Expiration Date condition for User Defined
-- 3.0      2020-07-15      Alvaro Palacios         Change ProdDay to use Fact Production instead Line Dimension
-- 3.1		2020-07-20		Gabriel Canepa			Changed INSERT to #MinorFlexVars to use the right field for TeamDesc (minor group by team/shift)
-- 3.2		2020-08-10		Gonzalo Luc				Fix division by zero on PR Excl pr in DEV
-- 3.3		2020-06-30		Gonzalo Luc				Added validation for Line Groups.
-- 3.4		2020-09-21		Pablo Bazan				Added condition for PR formula in Major:'ProdDay', Minor:'Line'
-- 3.5		2020-12-04		Delaporte Facundo		Added project construct and Schedule var columns to all the tables with STNU columns.
-- 3.6		2021-01-14		Gonzalo Luc				Fix Rate Utilization formula on Total Group.
-- 3.7		2021-01-29		Gonzalo Luc				Fix planned and unplanned rate loss for major group ProdDay and modify RateLossTgtRate from TotalProduct/Uptime to ActualRate
-- 3.8		2021-04-28		Gonzalo Luc				Added PR Loss Scrap calculation for grooming using TotalScrap instead of RunningScrap.
-- 3.9      2021-07-01      Gonzalo Luc             Added TOTAL column for y-lines calculated only with the selected y-lines.
-- 4.0		2021-07-21		Gonzalo Luc				Fix user defined for grooming groupings.
-- 4.1		2021-09-23		Gonzalo Luc				Fix minorgroup/Majorgroup "workcell" when user defined is selected.
-- 4-2		2021-11-17		Damian Villareal		Fix issue on PR Loss Rate Loss % for grooming Total Group PRB0088211
-- 4.3		2022-03-28		Gonzalo Luc				Change PR and Rate Loss formulas to account for 0PR records and standardize the Rate Loss formula with StatFactor.
-- 4.4		2022-04-07      Gonzalo Luc				Fix PRB0091574 Change pr formula from old grooming to pr standard in valuestream total.
-- 4.5      2022-12-13		Gonzalo Luc				FIX PRB0098333 EditedStopsPer on Major group Valuestream convert to float.
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptDaily]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE
	@strMajorGroupBy		NVARCHAR(200) 				,
	@strMinorGroupBy		NVARCHAR(200)				,
	@strLineId				NVARCHAR(MAX)	= ''		,
	@strWorkCellId			NVARCHAR(MAX)	= ''		,
	@intTimeOption			INT				= NULL		,
	@excludeNPT				INT				= NULL		,
	@dtmStartTime			DATETIME					,
	@dtmEndTime				DATETIME			

--WITH ENCRYPTION
AS
SET NOCOUNT ON
-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------
 ----EXEC spRptDaily 'Line','ProdDay','8,5,3,6,7,9,38,12',null ,2,0,'2019-09-22 06:00', '2019-09-23 06:00'
	--SELECT  

	--	 @strLineId	= '11,9,15,16,37,38'
	--	,@strWorkCellId	= 0--'251,223,279'	--'1371,1394,1417,1440,1463,1486'
	--	,@intTimeOption	= 5
	--	,@excludeNPT	= 1
	--	,@strMajorGroupBy = 'Line' 
	--	,@strMinorGroupBy = 'None'
	--	,@dtmStartTime = '2022-03-01 06:00:00'	
	--	,@dtmEndTime = '2022-03-15 06:00:00'		


	--	--select * from Auto_opsDataStore.dbo.line_dimension
-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE 
		 @PLId					INT
		,@strTimeOption			NVARCHAR(50) 
		,@strNPT				NVARCHAR(50)
		,@startTime				DATETIME
		,@endTime				DATETIME
		,@ReportedTime			DATETIME
		,@TotalProduct			INT
		,@maxMajor				INT
		,@index					INT
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
		,@Query					NVARCHAR(MAX)
		,@TempVal				NVARCHAR(50)
		,@SpecialCasesFlag		INT -- if 0 all lines with special cases, if 1 all lines without special cases and if 2 Mixed lines with special cases.
		,@LineGroupFlag			INT -- if a plid in the sp input belongs to a line group then 1 else 0
		,@IsGrooming			INT -- if a PLId/Workcell belongs to grooming then set this flag to 1 else 0
-- --------------------------------------------------------------------------------------------------------------------
-- Output Minor Table
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE @MinorGroup TABLE (
		 ID							INT IDENTITY
		,MajorGroupId				INT
		,MajorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupId				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,TeamDesc					NVARCHAR(25)  COLLATE DATABASE_DEFAULT
		,StartTime					DATETIME 
		,LineStatus					NVARCHAR(50) COLLATE DATABASE_DEFAULT
		,EndTime					DATETIME 
		,GoodProduct				BIGINT 
		,TotalProduct				FLOAT 
		,TotalScrap					FLOAT 
		,ActualRate					FLOAT 
		,TargetRate					FLOAT 
		,ScheduleTime				FLOAT 
		,CalendarTime				FLOAT
		,PR							FLOAT 
		,ScrapPer					FLOAT 
		,IdealRate					FLOAT 
		,STNU						FLOAT 
		,CapacityUtilization		FLOAT 
		,ScheduleUtilization		FLOAT 
		,Availability				FLOAT 
		,PRAvailability				FLOAT 
		,StopsMSU					FLOAT 
		,DownMSU					FLOAT 
		,RunningScrapPer			FLOAT 
		,RunningScrap				INT 
		,StartingScrapPer			FLOAT 
		,StartingScrap				INT 
		,RoomLoss					FLOAT 
		,MSU						FLOAT 
		,TotalCases					FLOAT 
		,RateUtilization			FLOAT 
		,RunEff						FLOAT 
		--,SafetyTrigg				INT 
		--,QualityTrigg				INT 
		,VSNetProduction			FLOAT 
		,VSPR						FLOAT 
		,VSPRLossPer				FLOAT 
		,TotalStops					INT 
		,Duration					FLOAT 
		,TotalUpdDowntime			FLOAT 
		,TotalUpdStops				INT 
		,MinorStops					INT 
		,ProcFailures				INT 
		,MajorStops					INT 
		,Uptime						FLOAT 
		,MTBF						FLOAT 
		,MTBFUpd					FLOAT 
		,MTTR						FLOAT 
		,UpsDTPRLoss				FLOAT 
		,R0							FLOAT 
		,R2							FLOAT 
		,BreakDown					INT 
		,MTTRUpd					FLOAT 
		,UpdDownPerc				FLOAT 
		,StopsDay					FLOAT 
		,ProcFailuresDay			FLOAT 
		,Availability_Unpl_DT		FLOAT 
		,Availability_Total_DT		FLOAT 
		,MTBS						FLOAT 
		,ACPStops					INT 
		,ACPStopsDay				FLOAT 
		,RepairTimeT				INT 
		,FalseStarts0				INT 
		,FalseStarts0Per			FLOAT 
		,FalseStartsT				INT 
		,FalseStartsTPer			FLOAT 
		,Survival240Rate			FLOAT 
		,Survival240RatePer			FLOAT 
		,EditedStops				INT 
		,EditedStopsPer				FLOAT 
		,TotalUpdStopDay			FLOAT 
		,StopsBDSDay				FLOAT 
		,TotalPlannedStops			INT 
		,TotalPlannedStopsDay		FLOAT 
		,MajorStopsDay				FLOAT 
		,MinorStopsDay				FLOAT 
		,TotalStarvedStops			INT 
		,TotalBlockedStops			INT 
		,TotalStarvedDowntime		FLOAT 
		,TotalBlockedDowntime		FLOAT 
		,VSScheduledTime			FLOAT 
		,VSPRLossPlanned			FLOAT 
		,VSPRLossUnplanned			FLOAT 
		,VSPRLossBreakdown			FLOAT 
		,Survival210Rate			FLOAT 
		,Survival210RatePer			FLOAT 
		,R210						FLOAT 
		,R240						FLOAT 
		,Availability_Planned_DT	FLOAT 
		,TotalPlannedDowntime		FLOAT 
		,PlannedDTPRLoss			FLOAT
		,ProductionTime				FLOAT
		,LineSpeed					FLOAT
		,PRRateLossTgtRate			FLOAT
		,EffRateLossDT				FLOAT
		,PercentPRRateLoss			FLOAT
		,Area4LossPer				FLOAT
		,ConvertedCases				FLOAT
		,BrandProjectPer			FLOAT		
		,EO_NonShippablePer			FLOAT		
		,LineNotStaffedPer			FLOAT		
		,STNUPer					FLOAT			
		,PRLossScrap				FLOAT	
		,StatUnits					FLOAT  
		,PRLossDivisor				FLOAT
		,NetProduction				FLOAT
		,IdleTime					FLOAT
		,ExcludedTime				FLOAT
		,MAchineStopsDay			FLOAT
		,StatCases					FLOAT
		,TargetRateAdj				FLOAT
		,PR_Excl_PRInDev			FLOAT
		,NetProductionExcDev		FLOAT	
		,ScheduleTimeExcDev			FLOAT	
		,TargetRateExcDev			FLOAT	
		,ActualRateExcDev			FLOAT		
		,MSUExcDev					FLOAT
		,ProjConstructPerc			FLOAT
		,STNUSchedVarPerc			FLOAT
		,StatFactor					FLOAT)


-- --------------------------------------------------------------------------------------------------------------------
-- Output Major Table
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE @MajorGroup TABLE (
		 ID							INT IDENTITY
		,MajorGroupId				INT
		,MajorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupId				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,TeamDesc					NVARCHAR(25)  COLLATE DATABASE_DEFAULT
		,StartTime					DATETIME 
		,LineStatus					NVARCHAR(50)  COLLATE DATABASE_DEFAULT
		,EndTime					DATETIME 
		,GoodProduct				BIGINT 
		,TotalProduct				FLOAT 
		,TotalScrap					FLOAT 
		,ActualRate					FLOAT 
		,TargetRate					FLOAT 
		,ScheduleTime				FLOAT 
		,CalendarTime				FLOAT
		,PR							FLOAT 
		,ScrapPer					FLOAT 
		,IdealRate					FLOAT 
		,STNU						FLOAT 
		,CapacityUtilization		FLOAT 
		,ScheduleUtilization		FLOAT 
		,Availability				FLOAT 
		,PRAvailability				FLOAT 
		,StopsMSU					FLOAT 
		,DownMSU					FLOAT 
		,RunningScrapPer			FLOAT 
		,RunningScrap				INT 
		,StartingScrapPer			FLOAT 
		,StartingScrap				INT 
		,RoomLoss					FLOAT 
		,MSU						FLOAT 
		,TotalCases					FLOAT 
		,RateUtilization			FLOAT 
		,RunEff						FLOAT 
		--,SafetyTrigg				INT 
		--,QualityTrigg				INT 
		,VSNetProduction			FLOAT 
		,VSPR						FLOAT 
		,VSPRLossPer				FLOAT 
		,TotalStops					INT 
		,Duration					FLOAT 
		,TotalUpdDowntime			FLOAT 
		,TotalUpdStops				INT 
		,MinorStops					INT 
		,ProcFailures				INT 
		,MajorStops					INT 
		,Uptime						FLOAT 
		,MTBF						FLOAT 
		,MTBFUpd					FLOAT 
		,MTTR						FLOAT 
		,UpsDTPRLoss				FLOAT 
		,R0							FLOAT 
		,R2							FLOAT 
		,BreakDown					INT 
		,MTTRUpd					FLOAT 
		,UpdDownPerc				FLOAT 
		,StopsDay					FLOAT 
		,ProcFailuresDay			FLOAT 
		,Availability_Unpl_DT		FLOAT 
		,Availability_Total_DT		FLOAT 
		,MTBS						FLOAT 
		,ACPStops					INT 
		,ACPStopsDay				FLOAT 
		,RepairTimeT				INT 
		,FalseStarts0				INT 
		,FalseStarts0Per			FLOAT 
		,FalseStartsT				INT 
		,FalseStartsTPer			FLOAT 
		,Survival240Rate			FLOAT 
		,Survival240RatePer			FLOAT 
		,EditedStops				INT 
		,EditedStopsPer				FLOAT 
		,TotalUpdStopDay			FLOAT 
		,StopsBDSDay				FLOAT 
		,TotalPlannedStops			INT 
		,TotalPlannedStopsDay		FLOAT 
		,MajorStopsDay				FLOAT 
		,MinorStopsDay				FLOAT 
		,TotalStarvedStops			INT 
		,TotalBlockedStops			INT 
		,TotalStarvedDowntime		FLOAT 
		,TotalBlockedDowntime		FLOAT 
		,VSScheduledTime			FLOAT 
		,VSPRLossPlanned			FLOAT 
		,VSPRLossUnplanned			FLOAT 
		,VSPRLossBreakdown			FLOAT 
		,Survival210Rate			FLOAT 
		,Survival210RatePer			FLOAT 
		,R210						FLOAT 
		,R240						FLOAT 
		,Availability_Planned_DT	FLOAT 
		,TotalPlannedDowntime		FLOAT 
		,PlannedDTPRLoss			FLOAT
		,ProductionTime				FLOAT
		,VSTotalUpdDowntime			FLOAT
		,VSTotalPlannedDowntime		FLOAT
		,VSBreakdown 				FLOAT
		,VSTargetRate				FLOAT
		,EffRateLossDT				FLOAT
		,PercentPRLossBreakdownDT   FLOAT
		,PercentPRRateLoss			FLOAT
		,VSEffRateLossDowntime		FLOAT
		,VSTotalProduction			FLOAT
		,NetProduction				FLOAT
		,Area4LossPer				FLOAT
		,ConvertedCases				FLOAT
		,PRRateLossTgtRate			FLOAT
		,BrandProjectPer			FLOAT		
		,EO_NonShippablePer			FLOAT		
		,LineNotStaffedPer			FLOAT		
		,STNUPer					FLOAT			
		,PRLossScrap				FLOAT		
		,StatUnits					FLOAT 
		,PRLossDivisor				FLOAT
        ,IdleTime					FLOAT
        ,ExcludedTime				FLOAT
        ,MAchineStopsDay			FLOAT
		,StatCases					FLOAT
		,TargetRateAdj				FLOAT
		,PR_Excl_PRInDev			FLOAT
		,NetProductionExcDev		FLOAT	
		,ScheduleTimeExcDev			FLOAT	
		,TargetRateExcDev			FLOAT	
		,ActualRateExcDev			FLOAT		
		,MSUExcDev					FLOAT
		,ProjConstructPerc			FLOAT
		,STNUSchedVarPerc			FLOAT
		,StatFactor					FLOAT)


-- --------------------------------------------------------------------------------------------------------------------
-- Output Major Table
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE @TotalGroup TABLE (
		 ID							INT IDENTITY
		,MajorGroupId				INT
		,MajorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupId				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,TeamDesc					NVARCHAR(25)  COLLATE DATABASE_DEFAULT
		,StartTime					DATETIME 
		,LineStatus					NVARCHAR(50)  COLLATE DATABASE_DEFAULT
		,EndTime					DATETIME 
		,GoodProduct				BIGINT 
		,TotalProduct				FLOAT 
		,TotalScrap					FLOAT 
		,ActualRate					FLOAT 
		,TargetRate					FLOAT 
		,ScheduleTime				FLOAT 
		,CalendarTime				FLOAT 
		,PR							FLOAT 
		,ScrapPer					FLOAT 
		,IdealRate					FLOAT 
		,STNU						FLOAT 
		,CapacityUtilization		FLOAT 
		,ScheduleUtilization		FLOAT 
		,Availability				FLOAT 
		,PRAvailability				FLOAT 
		,StopsMSU					FLOAT 
		,DownMSU					FLOAT 
		,RunningScrapPer			FLOAT 
		,RunningScrap				INT 
		,StartingScrapPer			FLOAT 
		,StartingScrap				INT 
		,RoomLoss					NVARCHAR(100) COLLATE DATABASE_DEFAULT
		,MSU						FLOAT 
		,TotalCases					FLOAT 
		,RateUtilization			FLOAT 
		,RunEff						FLOAT 
		--,SafetyTrigg				INT 
		--,QualityTrigg				INT 
		,VSNetProduction			FLOAT 
		,VSPR						FLOAT 
		,VSPRLossPer				FLOAT 
		,TotalStops					INT 
		,Duration					FLOAT 
		,TotalUpdDowntime			FLOAT 
		,TotalUpdStops				INT 
		,MinorStops					INT 
		,ProcFailures				INT 
		,MajorStops					INT 
		,Uptime						FLOAT 
		,MTBF						FLOAT 
		,MTBFUpd					FLOAT 
		,MTTR						FLOAT 
		,UpsDTPRLoss				FLOAT 
		,R0							FLOAT 
		,R2							FLOAT 
		,BreakDown					INT 
		,MTTRUpd					FLOAT 
		,UpdDownPerc				FLOAT 
		,StopsDay					FLOAT 
		,ProcFailuresDay			FLOAT 
		,Availability_Unpl_DT		FLOAT 
		,Availability_Total_DT		FLOAT 
		,MTBS						FLOAT 
		,ACPStops					INT 
		,ACPStopsDay				FLOAT 
		,RepairTimeT				INT 
		,FalseStarts0				INT 
		,FalseStarts0Per			FLOAT 
		,FalseStartsT				INT 
		,FalseStartsTPer			FLOAT 
		,Survival240Rate			FLOAT 
		,Survival240RatePer			FLOAT 
		,EditedStops				INT 
		,EditedStopsPer				FLOAT 
		,TotalUpdStopDay			FLOAT 
		,StopsBDSDay				FLOAT 
		,TotalPlannedStops			INT 
		,TotalPlannedStopsDay		FLOAT 
		,MajorStopsDay				FLOAT 
		,MinorStopsDay				FLOAT 
		,TotalStarvedStops			INT 
		,TotalBlockedStops			INT 
		,TotalStarvedDowntime		FLOAT 
		,TotalBlockedDowntime		FLOAT 
		,VSScheduledTime			FLOAT 
		,VSPRLossPlanned			FLOAT 
		,VSPRLossUnplanned			FLOAT 
		,VSPRLossBreakdown			FLOAT 
		,Survival210Rate			FLOAT 
		,Survival210RatePer			FLOAT 
		,R210						FLOAT 
		,R240						FLOAT 
		,Availability_Planned_DT	FLOAT 
		,TotalPlannedDowntime		FLOAT 
		,PlannedDTPRLoss			FLOAT
		,ProductionTime				FLOAT
		,VSTotalUpdDowntime			FLOAT
		,VSTotalPlannedDowntime		FLOAT
		,VSBreakdown 				FLOAT
		,VSTargetRate				FLOAT
		,EffRateLossDT				FLOAT
		,PercentPRLossBreakdownDT   FLOAT
		,PercentPRRateLoss			FLOAT
		,VSEffRateLossDowntime		FLOAT
		,VSTotalProduction			FLOAT
		,NetProduction				FLOAT
		,Area4LossPer				FLOAT
		,ConvertedCases				FLOAT
		,PRRateLossTgtRate			FLOAT
		,BrandProjectPer			FLOAT	
		,EO_NonShippablePer			FLOAT		
		,LineNotStaffedPer			FLOAT		
		,STNUPer					FLOAT			
		,PRLossScrap				FLOAT		
		,StatUnits					FLOAT 
		,PRLossDivisor				FLOAT
        ,IdleTime					FLOAT
        ,ExcludedTime				FLOAT
        ,MAchineStopsDay			FLOAT
		,StatCases					FLOAT
		,TargetRateAdj				FLOAT
		,PR_Excl_PRInDev			FLOAT
		,NetProductionExcDev		FLOAT	
		,ScheduleTimeExcDev			FLOAT	
		,TargetRateExcDev			FLOAT	
		,ActualRateExcDev			FLOAT	
		,MSUExcDev					FLOAT
		,ProjConstructPerc			FLOAT
		,STNUSchedVarPerc			FLOAT
		,StatFactor					FLOAT)
-- --------------------------------------------------------------------------------------------------------------------
-- Final Output
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE @FinalOutput TABLE (
		 ID							INT IDENTITY
		,MajorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MinorGroupBy				NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,MajorGroup					NVARCHAR(255) COLLATE DATABASE_DEFAULT
		,OutputOrder				INT
		,PlannedDTPRLoss			FLOAT			-- Grooming Daily Report
		,UpsDTPRLoss				FLOAT			-- Grooming Daily Report
		,EditedStopsPer				FLOAT			-- Grooming Daily Report
		,Availability_Planned_DT	FLOAT			-- Grooming Daily Report
		,Availability_Unpl_DT		FLOAT			-- Grooming Daily Report
		,Availability_Total_DT		FLOAT			-- Grooming Daily Report
		,UpdDownPerc				FLOAT			-- Grooming Daily Report
		,MTBF						FLOAT			-- Grooming Daily Report
		,MTBFUpd					FLOAT			-- Grooming Daily Report
		,MTTR						FLOAT			-- Grooming Daily Report
		,MTTRUpd					FLOAT			-- Grooming Daily Report
		,ScrapPer					FLOAT			-- Grooming Daily Report
		,MajorStopsDay				FLOAT			-- Grooming Daily Report
		,MinorStopsDay				FLOAT			-- Grooming Daily Report
		,GoodProduct				BIGINT			-- Grooming Daily Report 
		,TotalProduct				FLOAT			-- Grooming Daily Report
		,TotalPlannedStops			INT				-- Grooming Daily Report
		,TotalPlannedStopsDay		FLOAT			-- Grooming Daily Report
		,ProcFailuresDay			FLOAT			-- Grooming Daily Report
		,PR							FLOAT			-- Grooming Daily Report
		,PR_Excl_PRInDev			FLOAT	
		,ScheduleTime				FLOAT			-- Grooming Daily Report
		,StopsDay					FLOAT			-- Grooming Daily Report
		,StopsBDSDay				FLOAT			-- Grooming Daily Report
		,TotalStops					INT				-- Grooming Daily Report
		,TotalUpdStops				INT				-- Grooming Daily Report
		,TotalUpdStopDay			FLOAT			-- Grooming Daily Report
		,VSNetProduction			FLOAT			-- Grooming Daily Report
		,VSPR						FLOAT			-- Grooming Daily Report
		,VSPRLossPer				FLOAT			-- Grooming Daily Report 
		,VSScheduledTime			FLOAT			-- Grooming Daily Report
		,VSPRLossPlanned			FLOAT			-- Grooming Daily Report
		,VSPRLossUnplanned			FLOAT			-- Grooming Daily Report
		,VSPRLossBreakdown			FLOAT			-- Grooming Daily Report
		,PercentPRRateLoss			FLOAT
		,Area4LossPer				FLOAT
		,BrandProjectPer			FLOAT		
		,EO_NonShippablePer			FLOAT		
		,LineNotStaffedPer			FLOAT		
		,STNUPer					FLOAT		
		,PRLossScrap				FLOAT			
		,Duration					FLOAT 
		--------------------------------------------------------------------------
		,LineStatus					NVARCHAR(50) COLLATE DATABASE_DEFAULT	--DPR Report
		,TotalScrap					FLOAT			--DPR Report
		,IdealRate					FLOAT			--DPR Report
		,STNU						FLOAT			--DPR Report
		,CapacityUtilization		FLOAT			--DPR Report
		,ScheduleUtilization		FLOAT			--DPR Report
		,Availability				FLOAT			--DPR Report
		,PRAvailability				FLOAT			--DPR Report
		,StopsMSU					FLOAT			--DPR Report
		,DownMSU					FLOAT			--DPR Report
		,RunningScrapPer			FLOAT			--DPR Report
		,RunningScrap				INT				--DPR Report
		,StartingScrapPer			FLOAT			--DPR Report
		,StartingScrap				INT				--DPR Report
		,RoomLoss					NVARCHAR(100) COLLATE DATABASE_DEFAULT	--DPR Report
		,MSU						FLOAT			--DPR Report
		,TotalCases					FLOAT			--DPR Report
		,RateUtilization			FLOAT			--DPR Report
		,RunEff						FLOAT			--DPR Report
		,TotalUpdDowntime			FLOAT			--DPR Report
		,Uptime						FLOAT			--DPR Report
		,R0							FLOAT			--DPR Report
		,R2							FLOAT			--DPR Report
		,MTBS						FLOAT			--DPR Report
		,ACPStops					INT				--DPR Report
		,ACPStopsDay				FLOAT			--DPR Report
		,RepairTimeT				INT				--DPR Report
		,FalseStarts0				INT				--DPR Report
		,FalseStarts0Per			FLOAT			--DPR Report
		,FalseStartsT				INT				--DPR Report
		,FalseStartsTPer			FLOAT			--DPR Report
		,Survival240Rate			FLOAT			--DPR Report
		,Survival240RatePer			FLOAT			--DPR Report
		,EditedStops				INT				--DPR Report
		,Survival210Rate			FLOAT			--DPR Report
		,Survival210RatePer			FLOAT			--DPR Report
		,TotalPlannedDowntime		FLOAT			--DPR Report
		,TargetRate					FLOAT			--LEDS DDS
		,ProcFailures				INT				--LEDS DDS
		,BreakDown					INT				--LEDS DDS
		,TotalStarvedStops			INT				--LEDS DDS
		,TotalBlockedStops			INT				--LEDS DDS
		,TotalStarvedDowntime		FLOAT			--LEDS DDS
		,TotalBlockedDowntime		FLOAT			--LEDS DDS
        ,IdleTime					FLOAT
        ,ExcludedTime				FLOAT
        ,MAchineStopsDay			FLOAT
		,StatCases					FLOAT
		,ActualRate					FLOAT 
		,TargetRateAdj				FLOAT
		,ProjConstructPerc			FLOAT
		,STNUSchedVarPerc			FLOAT
		)

---------------------------------------------------------------------------------------------------
DECLARE @Equipment TABLE (
		RcdIdx						INT IDENTITY							,						
		PUId						INT										,
		PUDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		PLId						INT										,
		PLDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		VSId						INT										,
		ValueStreamDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		StartTime					DATETIME								,
		EndTime						DATETIME								,
		DayStartTime				TIME									,
		YLineFlag					INT										,
		isConverter					INT										,
		isLeg						INT										)
---------------------------------------------------------------------------------------------------
DECLARE @ProdDay TABLE (
		RcdIdx						INT IDENTITY	,	
		ProdDayId					INT				,					
		PUId						INT				,
		PUDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		PLId						INT				,
		PLDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		VSId						INT				,
		ValueStreamDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		ProdDay						DATE			,
		StartTime					DATETIME		,
		EndTime						DATETIME		)
---------------------------------------------------------------------------------------------------
DECLARE @TeamShift TABLE (
		RcdIdx						INT IDENTITY	,		
		TeamDesc					NVARCHAR(255)	COLLATE DATABASE_DEFAULT,		
		ShiftDesc					NVARCHAR(255)	COLLATE DATABASE_DEFAULT,			
		PUId						INT				,
		PUDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		PLId						INT				,
		PLDesc						NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		VSId						INT				,
		ValueStreamDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
		StartTime					DATETIME		,
		EndTime						DATETIME		)
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
DECLARE @FlexibleVars TABLE (
			Idx						INT IDENTITY							,
			KPIDesc					NVARCHAR(100)	COLLATE DATABASE_DEFAULT)
--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#MinorFlexVars') IS NOT NULL
BEGIN
	DROP TABLE #MinorFlexVars
END
CREATE TABLE #MinorFlexVars ( 
			Idx						INT IDENTITY							,
			MajorGroupId			INT										,
			MajorGroupBy			NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			MinorGroupId			NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			MinorGroupBy			NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			TeamDesc				NVARCHAR(25)  	COLLATE DATABASE_DEFAULT,
			StartTime				DATETIME 								,
			EndTime					DATETIME 								,
			LineStatus				NVARCHAR(50) 	COLLATE DATABASE_DEFAULT)
--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#MajorFlexVars') IS NOT NULL
BEGIN
	DROP TABLE #MajorFlexVars
END
CREATE TABLE #MajorFlexVars ( 
			Idx						INT IDENTITY							,
			MajorGroupId			INT										,
			MajorGroupBy			NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			TeamDesc				NVARCHAR(25)  	COLLATE DATABASE_DEFAULT,
			StartTime				DATETIME 								,
			EndTime					DATETIME 								,
			LineStatus				NVARCHAR(50) 	COLLATE DATABASE_DEFAULT)
--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#TotalFlexVars') IS NOT NULL
BEGIN
	DROP TABLE #TotalFlexVars
END
CREATE TABLE #TotalFlexVars ( 
			Idx						INT	)

--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#FinalFlexVars') IS NOT NULL
BEGIN
	DROP TABLE #FinalFlexVars
END
CREATE TABLE #FinalFlexVars ( 
			 Idx					INT IDENTITY							,
			 MajorGroupBy			NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			 MinorGroupBy			NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			 MajorGroup				NVARCHAR(255)	COLLATE DATABASE_DEFAULT,
			 OutputOrder			INT										)
--------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#UserDefinedFlexVariables') IS NOT NULL
BEGIN
	DROP TABLE #UserDefinedFlexVariables
END

CREATE TABLE #UserDefinedFlexVariables					( 
			LineId					INT										,		
			WorkCellId				INT										,
			DateId					INT										,
			ProductId				INT										,
			ProductCode				VARCHAR(25)		COLLATE DATABASE_DEFAULT,
			TeamDesc				VARCHAR(25)		COLLATE DATABASE_DEFAULT,
			ShiftDesc				VARCHAR(25)		COLLATE DATABASE_DEFAULT,
			Starttime				DATETIME								,
			Status					VARCHAR(50)		COLLATE DATABASE_DEFAULT,
			FACT_UDPs_Idx			INT										,
			Result					FLOAT									)
-- --------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @strMajorGroupBy = 'Line' AND NOT @strMajorGroupBy = 'ProdDay'
BEGIN
	INSERT INTO @Equipment(
			PUId)
			SELECT String FROM fnLocal_Split(@strWorkCellId,',')
END
ELSE
BEGIN
	INSERT INTO @Equipment(
			PLId)
			SELECT String FROM fnLocal_Split(@strLineId,',')
END		

-- --------------------------------------------------------------------------------------------------------------------
-- Check if Lines have special cases.
-- --------------------------------------------------------------------------------------------------------------------
SET @SpecialCasesFlag = (SELECT COUNT(*)
					  FROM [Auto_opsDataStore].[dbo].[AGGREGATION_FORMULAS] ag (NOLOCK)
					  JOIN [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd (NOLOCK) ON kd.KPI_Id = ag.KPI_Id
					  WHERE kd.KPI_Desc = 'Area4LossPer'
					  AND ag.LineId IN (SELECT PLId FROM @Equipment))

SET @SpecialCasesFlag = (CASE WHEN @SpecialCasesFlag = (SELECT COUNT(PLId) FROM @Equipment) THEN 0 ELSE CASE WHEN @SpecialCasesFlag = 0 THEN 1 ELSE 2 END END)

-- --------------------------------------------------------------------------------------------------------------------
-- SET flag for line group.
-- --------------------------------------------------------------------------------------------------------------------
SET @LineGroupFlag = (CASE WHEN (SELECT COUNT(*) FROM dbo.LINE_DIMENSION WHERE PLId IN (SELECT String FROM fnLocal_Split(@strLineId,',')) AND BUId = 'Y-Line') > 0 THEN 1 ELSE 0 END)

-- --------------------------------------------------------------------------------------------------------------------
-- SET flag for Grooming.
-- --------------------------------------------------------------------------------------------------------------------
SET @IsGrooming = (CASE WHEN (SELECT COUNT(*) FROM dbo.LINE_DIMENSION WHERE PLId IN (SELECT String FROM fnLocal_Split(@strLineId,',')) AND BUId = 'Grooming') > 0 THEN 1 ELSE 0 END)

-- --------------------------------------------------------------------------------------------------------------------
-- Update @Equipment table with all the needed values
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @strMajorGroupBy = 'Line' AND NOT @strMajorGroupBy = 'ProdDay'
BEGIN
	--update plid, VSId and pudesc 
	UPDATE e
		SET PLID = (SELECT PLID FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId),
			VSId = (SELECT VSId FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId),
			PUDesc = (SELECT PUDesc FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId)
	FROM @Equipment e
	--update valuestream desc
	UPDATE e
		SET ValuestreamDesc	= (SELECT LineDesc 
								FROM dbo.LINE_DIMENSION ld (NOLOCK)
								JOIN dbo.Workcell_Dimension wd (NOLOCK) ON ld.LineId = wd.VSId
								WHERE wd.PUId = e.PUId)
		FROM @Equipment e
	--Update Line Desc for Line major group
END
UPDATE e
	SET PLDesc	= (SELECT LineDesc FROM dbo.LINE_DIMENSION ld WHERE ld.PLId = e.PLId),
		DayStartTime = (SELECT CONVERT(TIME,ShiftStartTime) FROM dbo.LINE_DIMENSION ld WHERE ld.PLId = e.PLId)
	FROM @Equipment e
UPDATE e
	SET YLineFlag = 1
FROM @Equipment e
JOIN dbo.Line_Dimension ld ON ld.PLId = e.PLId
WHERE BUId = 'Y-Line'
--Update Start and End time
IF @intTimeOption > 0
BEGIN
	--Update start time and end time if a time option is selected
	SELECT @strTimeOption = DateDesc 
	FROM [dbo].[DATE_DIMENSION] (NOLOCK)
	WHERE DateId = @intTimeOption

	UPDATE e 
			SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
			FROM @Equipment e 
			OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f
END
ELSE
BEGIN
	--update the Start and End Time from input parameters (user defined selected on report)
	UPDATE e 
			SET	e.StartTime = @dtmStartTime, e.EndTime = @dtmEndTime
	FROM @Equipment e
			
END
--In case of a line group selected update start time and end time from the converter line
IF @LineGroupFlag = 1
BEGIN
	UPDATE e
		SET StartTime = (SELECT StartTime FROM @Equipment WHERE PLId = (SELECT DISTINCT w.plid 
																		FROM dbo.zones z WITH(NOLOCK) 
																		JOIN dbo.formulas f WITH(NOLOCK) ON z.formulaidx=f.FormulaIdx 
																		JOIN dbo.line_dimension l WITH(NOLOCK) ON l.lineid=f.line_dimension_lineid
																		JOIN dbo.workcell_dimension w WITH(NOLOCK) ON z.workcell_dimension_workcellid=w.workcellid
																		WHERE l.plid=e.PLId 
																		  AND z.zone_id=1)),
			EndTime = (SELECT EndTime FROM @Equipment WHERE PLId = (SELECT DISTINCT w.plid 
																		FROM dbo.zones z WITH(NOLOCK) 
																		JOIN dbo.formulas f WITH(NOLOCK) ON z.formulaidx=f.FormulaIdx 
																		JOIN dbo.line_dimension l WITH(NOLOCK) ON l.lineid=f.line_dimension_lineid
																		JOIN dbo.workcell_dimension w WITH(NOLOCK) ON z.workcell_dimension_workcellid=w.workcellid
																		WHERE l.plid=e.PLId 
																		  AND z.zone_id=1))
	FROM @Equipment e
	WHERE YLineFlag = 1

	UPDATE e
		SET isConverter = 1
	
	FROM @Equipment e
	WHERE e.PLId IN (SELECT DISTINCT w.plid 
																		FROM dbo.zones z WITH(NOLOCK) 
																		JOIN dbo.formulas f WITH(NOLOCK) ON z.formulaidx=f.FormulaIdx 
																		JOIN dbo.line_dimension l WITH(NOLOCK) ON l.lineid=f.line_dimension_lineid
																		JOIN dbo.workcell_dimension w WITH(NOLOCK) ON z.workcell_dimension_workcellid=w.workcellid
																		JOIN @Equipment e1 ON l.plid=e1.PLId 
																		WHERE z.zone_id=1
																		  AND e1.YLineFlag = 1)
	UPDATE e
		SET isLeg = 1
	
	FROM @Equipment e
	WHERE e.PLId IN (SELECT DISTINCT w.plid 
																		FROM dbo.zones z WITH(NOLOCK) 
																		JOIN dbo.formulas f WITH(NOLOCK) ON z.formulaidx=f.FormulaIdx 
																		JOIN dbo.line_dimension l WITH(NOLOCK) ON l.lineid=f.line_dimension_lineid
																		JOIN dbo.workcell_dimension w WITH(NOLOCK) ON z.workcell_dimension_workcellid=w.workcellid
																		JOIN @Equipment e1 ON l.plid=e1.PLId 
																		WHERE z.zone_id=2
																		  AND e1.YLineFlag = 1)
END
--SELECT '@Equipment',* FROM @Equipment	

-- --------------------------------------------------------------------------------------------------------------------
-- Get NPT
-- --------------------------------------------------------------------------------------------------------------------
	SELECT	@strNPT = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'All' END)

---------------------------------------------------------------------------------------------------
-- Build Production Day time slices
---------------------------------------------------------------------------------------------------
IF @strMinorGroupBy = 'ProdDay' OR @strMajorGroupBy = 'ProdDay'
BEGIN
	SET @index = 1
	SET @i = 1 --RcdIdx
	SELECT @j = COUNT(*) FROM @Equipment 
	WHILE (@i <= @j)
	BEGIN
		SELECT @StartTimeAux = StartTime FROM @Equipment WHERE RcdIdx = @i
		SELECT @EndTimeAux = EndTime FROM @Equipment WHERE RcdIdx = @i
		SELECT @PUIdAux = PUId FROM @Equipment WHERE RcdIdx = @i
		SELECT @PLIdAux = PLId FROM @Equipment WHERE RcdIdx = @i
		SELECT @PUDescAux = PUDesc FROM @Equipment WHERE RcdIdx = @i
		SELECT @PLDescAux = PLDesc FROM @Equipment WHERE RcdIdx = @i
		SELECT @VSIdAux = VSId FROM @Equipment WHERE RcdIdx = @i
		SELECT @VSDescAux = ValueStreamDesc FROM @Equipment WHERE RcdIdx = @i
		SELECT @DayStart = DayStartTime FROM @Equipment WHERE RcdIdx = @i
		--SELECT @DayStart
		IF(@PUIdAux IS NOT NULL OR @PLIdAux IS NOT NULL)
		BEGIN
			IF(@intTimeOption < 0)
			BEGIN

				SET @index = 0
				--Insert manually the first record
				SET @dtmProdDayStartAux = @StartTimeAux 
				SELECT @dtmProdDayEndAux = ISNULL((select top 1 EndTime from Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK)  
		                            JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
									where DATE_DIMENSION_DateId = 2 and l.PLId IN (@PLIdAux)
		                            AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayStartAux AS DATE)
								 order by StartTime desc), DATEADD(hh,24,@dtmProdDayStartAux)) 




				SET @index = 1
			END
			ELSE
			BEGIN
				SET @dtmProdDayStartAux = @StartTimeAux --It already has the start of day
				SET @dtmProdDayEndAux = ISNULL((select top 1 EndTime from Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK) 
		                            JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
									where DATE_DIMENSION_DateId = 2 and l.PLId IN (@PLIdAux)
		                            AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayStartAux AS DATE)
								 order by StartTime desc), DATEADD(hh,24,@dtmProdDayStartAux))
				SET @index = 1
			END
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
				SET @dtmProdDayStartAux = ISNULL((select top 1 StartTime from Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK)  
		                            JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
									where DATE_DIMENSION_DateId = 2 and l.PLId IN (@PLIdAux)
		                            AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayEndAux AS DATE)
								 order by StartTime desc), DATEADD(hh,24,@dtmProdDayStartAux))

				SET @dtmProdDayEndAux = ISNULL((select top 1 EndTime from Auto_opsDataStore.dbo.Line_Dimension l (NOLOCK) 
		                            JOIN FACT_PRODUCTION fp  (NOLOCK) ON fp.line_dimension_lineId = l.LineId
									where DATE_DIMENSION_DateId = 2 and l.PLId IN (@PLIdAux)
		                            AND CAST(fp.StartTime AS DATE) = CAST(@dtmProdDayEndAux AS DATE)
								 order by StartTime desc), DATEADD(hh,24,@dtmProdDayEndAux))

				--SELECT 'INSERTO ESTE ID',@PUIdAux, @dtmProdDayStartAux, @dtmProdDayEndAux, @EndTimeAux
			END
			--update last record if the endtime time does not match the line daystart
			IF (SELECT TOP 1 CAST(EndTime AS TIME) FROM @ProdDay pd WHERE PLId = @PLIdAux Order By ProdDayId DESC) <> CAST(@EndTimeAux AS TIME)
			BEGIN
				UPDATE pd
					SET EndTime = @EndTimeAux
				FROM @ProdDay pd
				WHERE ProdDayId = (SELECT MAX(ProdDayId) FROM @ProdDay WHERE PLId = @PLIdAux)
			END
		END

		SET @i = @i+1
	END
END		
--select '@ProdDay',* from @ProdDay

---------------------------------------------------------------------------------------------------
-- Build Team or Shift time slices
---------------------------------------------------------------------------------------------------
IF (@strMajorGroupBy = 'ValueStream' OR @strMajorGroupBy = 'Workcell')
BEGIN
	IF (@strMinorGroupBy = 'Shift')
	BEGIN
		INSERT INTO @TeamShift(PUId, PUDesc,ShiftDesc,ValueStreamDesc,PLId,PLDesc,VSId, StartTime, EndTime)
		SELECT DISTINCT pd.PUId, pd.PUDesc,pd.ShiftDesc, e.ValueStreamDesc, e.PLId, e.PLDesc,e.VSId, e.StartTime, e.EndTime
		FROM [dbo].[OpsDB_Production_Data] pd (NOLOCK)
		JOIN @Equipment e ON e.PUId = pd.PUId
		WHERE pd.StartTime >= e.StartTime
		AND   pd.EndTime <= e.EndTime
		AND   pd.DeleteFlag = 0
	END

	IF (@strMinorGroupBy = 'Team')
	BEGIN
		INSERT INTO @TeamShift(PUId, PUDesc,TeamDesc,ValueStreamDesc,PLId,PLDesc,VSId, StartTime, EndTime)
		SELECT DISTINCT pd.PUId, pd.PUDesc,pd.TeamDesc, e.ValueStreamDesc, e.PLId, e.PLDesc,e.VSId, e.StartTime, e.EndTime
		FROM [dbo].[OpsDB_Production_Data] pd (NOLOCK)
		JOIN @Equipment e ON e.PUId = pd.PUId
		WHERE pd.StartTime >= e.StartTime
		AND   pd.EndTime <= e.EndTime
		AND   pd.DeleteFlag = 0
	END
END
ELSE
BEGIN
	IF (@strMinorGroupBy = 'Shift')
	BEGIN
		INSERT INTO @TeamShift(ShiftDesc,ValueStreamDesc,PLId,PLDesc,VSId, StartTime, EndTime)
		SELECT DISTINCT pd.ShiftDesc, e.ValueStreamDesc, e.PLId, e.PLDesc,e.VSId, e.StartTime, e.EndTime
		FROM [dbo].[OpsDB_Production_Data] pd (NOLOCK)
		LEFT JOIN [dbo].[OpsDB_DowntimeUptime_Data] dd (NOLOCK) ON pd.PLId = dd.PLId
		JOIN @Equipment e ON e.PLId = pd.PLId
		WHERE pd.StartTime >= e.StartTime
		AND   pd.EndTime <= e.EndTime
		AND   pd.DeleteFlag = 0
	END

	IF (@strMinorGroupBy = 'Team')
	BEGIN
		INSERT INTO @TeamShift(TeamDesc,ValueStreamDesc,PLId,PLDesc,VSId, StartTime, EndTime)
		SELECT DISTINCT pd.TeamDesc, e.ValueStreamDesc, e.PLId, e.PLDesc,e.VSId, e.StartTime, e.EndTime
		FROM [dbo].[OpsDB_Production_Data] pd (NOLOCK)
		LEFT JOIN [dbo].[OpsDB_DowntimeUptime_Data] dd (NOLOCK) ON pd.PLId = dd.PLId
		JOIN @Equipment e ON e.PLId = pd.PLId
		WHERE pd.StartTime >= e.StartTime
		AND   pd.EndTime <= e.EndTime
		AND   pd.DeleteFlag = 0
	END
END
--SELECT '@TeamShift', * FROM @TeamShift

-- --------------------------------------------------------------------------------------------------------------------
-- add columns to temp table for Flex variables 
-- --------------------------------------------------------------------------------------------------------------------

INSERT INTO @FlexibleVars(
				KPIDesc)
SELECT kd.KPI_Desc
  FROM [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd
  WHERE kd.Fact like '%Flexible_Variables%'
  
-- --------------------------------------------------------------------------------------------------------------------
-- insert flex vars in variable table for minor grouping
-- --------------------------------------------------------------------------------------------------------------------
--SELECT * FROM @FlexibleVars
SET @Query = 'ALTER TABLE #MinorFlexVars ADD '
SELECT @i = COUNT(*) FROM @FlexibleVars
SET @j = 1

SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
SET @Query += '[' + @TempVal  + ']' + ' FLOAT '
SET @j += 1

WHILE @j <= @i
BEGIN
	SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
	SET @Query += ',' + '[' + @TempVal  + ']' + ' FLOAT '
	SET @j += 1
END

EXEC (@Query)

-- --------------------------------------------------------------------------------------------------------------------
-- insert flex vars in variable table for major grouping
-- --------------------------------------------------------------------------------------------------------------------
--SELECT * FROM @FlexibleVars
SET @Query = 'ALTER TABLE #MajorFlexVars ADD '
SELECT @i = COUNT(*) FROM @FlexibleVars
SET @j = 1

SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
SET @Query += '[' + @TempVal  + ']' + ' FLOAT '
SET @j += 1

WHILE @j <= @i
BEGIN
	SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
	SET @Query += ',' + '[' + @TempVal  + ']' + ' FLOAT '
	SET @j += 1
END

EXEC (@Query)

-- --------------------------------------------------------------------------------------------------------------------
-- insert flex vars in variable table for total grouping
-- --------------------------------------------------------------------------------------------------------------------
--SELECT * FROM @FlexibleVars
SET @Query = 'ALTER TABLE #TotalFlexVars ADD '
SELECT @i = COUNT(*) FROM @FlexibleVars
SET @j = 1

SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
SET @Query += '[' + @TempVal  + ']' + ' FLOAT '
SET @j += 1

WHILE @j <= @i
BEGIN
	SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
	SET @Query += ',' + '[' + @TempVal  + ']' + ' FLOAT '
	SET @j += 1
END

EXEC (@Query)

-- --------------------------------------------------------------------------------------------------------------------
-- insert flex vars in variable table for Final grouping
-- --------------------------------------------------------------------------------------------------------------------
--SELECT * FROM @FlexibleVars
SET @Query = 'ALTER TABLE #FinalFlexVars ADD '
SELECT @i = COUNT(*) FROM @FlexibleVars
SET @j = 1

SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
SET @Query += '[' + @TempVal  + ']' + ' FLOAT '
SET @j += 1

WHILE @j <= @i
BEGIN
	SELECT @TempVal = KPIDesc FROM @FlexibleVars WHERE Idx = @j
	SET @Query += ',' + '[' + @TempVal  + ']' + ' FLOAT '
	SET @j += 1
END

EXEC (@Query)

-- --------------------------------------------------------------------------------------------------------------------
-- Get KPI's for the minor group
-- --------------------------------------------------------------------------------------------------------------------

IF @strMajorGroupBy = 'Valuestream'
BEGIN
		DELETE FROM @Equipment WHERE VSId IS NULL
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
				 MinorGroupId
				,MinorGroupBy
				,MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime					
				,GoodProduct				
				,TotalProduct				
				,TotalScrap					
				,ActualRate					
				,TargetRate					
				,ScheduleTime				
				,PR							
				,ScrapPer					
				,IdealRate					
				,STNU						
				,CapacityUtilization		
				,ScheduleUtilization		
				,Availability				
				,PRAvailability				
				,StopsMSU					
				,DownMSU					
				,RunningScrapPer			
				,RunningScrap				
				,StartingScrapPer			
				,StartingScrap				
				,RoomLoss					
				,MSU						
				,TotalCases					
				,RateUtilization			
				,RunEff						
				--,SafetyTrigg				
				--,QualityTrigg				
				,VSNetProduction			
				,VSPR						
				,VSPRLossPer				
				,PercentPRRateLoss		
				,TotalStops					
				,Duration					
				,TotalUpdDowntime			
				,TotalUpdStops				
				,MinorStops					
				,ProcFailures				
				,MajorStops					
				,Uptime						
				,MTBF						
				,MTBFUpd					
				,MTTR						
				,UpsDTPRLoss				
				,R0							
				,R2							
				,BreakDown					
				,MTTRUpd					
				,UpdDownPerc				
				,StopsDay					
				,ProcFailuresDay			
				,Availability_Unpl_DT		
				,Availability_Total_DT		
				,MTBS						
				,ACPStops					
				,ACPStopsDay				
				,RepairTimeT				
				,FalseStarts0				
				,FalseStarts0Per			
				,FalseStartsT				
				,FalseStartsTPer			
				,Survival240Rate			
				,Survival240RatePer			
				,EditedStops				
				,EditedStopsPer				
				,TotalUpdStopDay			
				,StopsBDSDay				
				,TotalPlannedStops			
				,TotalPlannedStopsDay		
				,MajorStopsDay				
				,MinorStopsDay				
				,TotalStarvedStops			
				,TotalBlockedStops			
				,TotalStarvedDowntime		
				,TotalBlockedDowntime		
				,VSScheduledTime			
				,VSPRLossPlanned			
				,VSPRLossUnplanned			
				,VSPRLossBreakdown			
				,Survival210Rate			
				,Survival210RatePer			
				,R210						
				,R240						
				,Availability_Planned_DT	
				,TotalPlannedDowntime		
				,PlannedDTPRLoss
				,Area4LossPer
				,ConvertedCases
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap			
				,StatUnits					
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay			
				,StatCases		
				,TargetRateAdj
				,PR_Excl_PRInDev	
				,NetProductionExcDev
				,ScheduleTimeExcDev	
				,MSUExcDev			
				,ProjConstructPerc
				,STNUSchedVarPerc
				,StatFactor)			

			SELECT DISTINCT
				 e.PUId	
				,e.PUDesc
				,e.VSId
				,e.ValuestreamDesc
				,ISNULL(fp.TeamDesc,0)
				,e.StartTime
				,fp.LineStatus					
				,e.EndTime						
				,ISNULL(fp.GoodProduct,0)
				,ISNULL(fp.TotalProduct,0)
				,ISNULL(fp.TotalScrap,0)
				,ISNULL(fp.ActualRate,0)
				,ISNULL(fp.TargetRate,0)
				,ISNULL(fp.ScheduleTime,0)
				,ISNULL(fp.PR,0)
				,ISNULL(fp.ScrapPer,0)
				,ISNULL(fp.IdealRate,0)
				,ISNULL(fp.STNU,0)
				,ISNULL(fp.CapacityUtilization,0)
				,ISNULL(fp.ScheduleUtilization,0)
				,ISNULL(fp.Availability,0)
				,ISNULL(fp.PRAvailability,0)
				,ISNULL(fp.StopsMSU,0)
				,ISNULL(fp.DownMSU,0)
				,ISNULL(fp.RunningScrapPer,0)
				,ISNULL(fp.RunningScrap,0)
				,ISNULL(fp.StartingScrapPer,0)
				,ISNULL(fp.StartingScrap,0)
				,ISNULL(fp.RoomLoss,0)
				,ISNULL(fp.MSU,0)
				,ISNULL(fp.TotalCases,0)
				,ISNULL(fp.RateUtilization,0)
				,ISNULL(fp.RunEff,0)
				--,ISNULL(fp.SafetyTrigg,0)
				--,ISNULL(fp.QualityTrigg,0)
				,ISNULL(fp.VSNetProduction,0)
				,ISNULL(fp.VSPR,0)
				,ISNULL(fp.VSPRLossPer,0)--
				,ISNULL(fp.PRRateLoss,0)
				,ISNULL(fd.TotalStops,0)
				,ISNULL(fd.Duration,0)
				,ISNULL(fd.TotalUpdDowntime,0)
				,ISNULL(fd.TotalUpdStops,0)
				,ISNULL(fd.MinorStops,0)
				,ISNULL(fd.ProcFailures,0)
				,ISNULL(fd.MajorStops,0)
				,ISNULL(fd.Uptime,0)
				,ISNULL(fd.MTBF,0)
				,ISNULL(fd.MTBFUpd,0)
				,ISNULL(fd.MTTR,0)
				,ISNULL(fd.UpsDTPRLoss,0)
				,ISNULL(fd.R0,0)
				,ISNULL(fd.R2,0)
				,ISNULL(fd.BreakDown,0)
				,ISNULL(fd.MTTRUpd,0)
				,ISNULL(fd.UpdDownPerc,0)
				,ISNULL(fd.StopsDay,0)
				,ISNULL(fd.ProcFailuresDay,0)
				,ISNULL(fd.Availability_Unpl_DT,0)
				,ISNULL(fd.Availability_Total_DT,0)
				,ISNULL(fd.MTBS,0)
				,ISNULL(fd.ACPStops,0)
				,ISNULL(fd.ACPStopsDay,0)
				,ISNULL(fd.RepairTimeT,0)
				,ISNULL(fd.FalseStarts0,0)
				,ISNULL(fd.FalseStarts0Per,0)
				,ISNULL(fd.FalseStartsT,0)
				,ISNULL(fd.FalseStartsTPer,0)
				,ISNULL(fd.Survival240Rate,0)
				,ISNULL(fd.Survival240RatePer,0)
				,ISNULL(fd.EditedStops,0)
				,ISNULL(fd.EditedStopsPer,0)
				,ISNULL(fd.TotalUpdStopDay,0)
				,ISNULL(fd.StopsBDSDay,0)
				,ISNULL(fd.TotalPlannedStops,0)
				,ISNULL(fd.TotalPlannedStopsDay,0)
				,ISNULL(fd.MajorStopsDay,0)
				,ISNULL(fd.MinorStopsDay,0)
				,ISNULL(fd.TotalStarvedStops,0)
				,ISNULL(fd.TotalBlockedStops,0)
				,ISNULL(fd.TotalStarvedDowntime,0)
				,ISNULL(fd.TotalBlockedDowntime,0)
				,ISNULL(fd.VSScheduledTime,0)
				,ISNULL(fd.VSPRLossPlanned,0)
				,ISNULL(fd.VSPRLossUnplanned,0)
				,ISNULL(fd.VSPRLossBreakdown,0)
				,ISNULL(fd.Survival210Rate,0)
				,ISNULL(fd.Survival210RatePer,0)
				,ISNULL(fd.R210,0)
				,ISNULL(fd.R240,0)
				,ISNULL(fd.Availability_Planned_DT,0)
				,ISNULL(fd.TotalPlannedDowntime,0)
				,ISNULL(fd.PlannedDTPRLoss,0)
				,ISNULL(fp.Area4LossPer,0)
				,0 --,ISNULL(fp.ConvertedCases,0) 
				,ISNULL(fp.BrandProjectPer,0)		
				,ISNULL(fp.EO_NonShippablePer,0)		
				,ISNULL(fp.LineNotStaffedPer,0)		
				,ISNULL(fp.STNUPer,0)	
				,ISNULL(fp.PRLossScrap,0)	
				,ISNULL(fp.StatUnits,0)
				,ISNULL(fd.IdleTime,0)					
				,ISNULL(fd.ExcludedTime,0)				
				,ISNULL(fd.MAchineStopsDay,0)			
				,ISNULL(fp.StatCases,0)				
				,ISNULL(fp.TargetRateAdj,0)
				,ISNULL(fp.PR_Excl_PRInDev,0)
				,ISNULL(fp.NetProductionExcDev,0)
				,ISNULL(fp.ScheduleTimeExcDev,0)
				,ISNULL(fp.MSUExcDev,0)
				,ISNULL(fp.ProjConstructPerc,0)
				,ISNULL(fp.STNUSchedVarPerc,0)
				,ISNULL(fp.StatFactor,0)
			
			FROM @Equipment e 
			JOIN dbo.Workcell_Dimension wd (NOLOCK) ON e.PUId = wd.PUId
			LEFT JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.Workcell_Dimension_WorkcellId = wd.WorkcellId
														AND fp.LineStatus = @strNPT		
														AND fp.Date_Dimension_DateId = @intTimeOption		
														AND fp.StartTime >= e.StartTime
														AND fp.EndTime <= e.EndTime
														AND fp.ShiftDesc = 'All'		
														AND fp.TeamDesc = 'All'
			LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.Workcell_Dimension_WorkcellId = wd.WorkcellId
														AND fd.LineStatus = @strNPT
														AND fd.Date_Dimension_DateId = @intTimeOption
														AND fd.StartTime >= e.StartTime
														AND fd.EndTime <= e.EndTime
														AND fd.ShiftDesc = 'All'
														AND fd.TeamDesc = 'All'

		END
		ELSE
		BEGIN
			--Delete tables before reuse.
			DELETE #UserDefinedProduction
			DELETE #UserDefinedDowntime
			DELETE #UserDefinedFlexVariables
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Unit'
														,0
	
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Unit'
		
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime

			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer							
					,PercentPRRateLoss
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap			
					,StatUnits						
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

			SELECT DISTINCT
				 e.PUId	
				,e.PUDesc
				,e.VSId
				,e.ValuestreamDesc
				,ISNULL(udp.TeamDesc,0)
				,e.StartTime
				,udp.Status					
				,e.EndTime						
				,ISNULL(udp.GoodProduct,0)
				,ISNULL(udp.TotalProduct,0)
				,ISNULL(udp.TotalScrap,0)
				,ISNULL(udp.ActualRate,0)
				,ISNULL(udp.TargetRate,0)
				,ISNULL(udp.ScheduleTime,0)
				,ISNULL(udp.PR,0)
				,ISNULL(udp.ScrapPer,0)
				,ISNULL(udp.IdealRate,0)
				,ISNULL(udp.STNU,0)
				,ISNULL(udp.CapacityUtilization,0)
				,ISNULL(udp.ScheduleUtilization,0)
				,ISNULL(udp.Availability,0)
				,ISNULL(udp.PRAvailability,0)
				,ISNULL(udp.StopsMSU,0)
				,ISNULL(udp.DownMSU,0)
				,ISNULL(udp.RunningScrapPer,0)
				,ISNULL(udp.RunningScrap,0)
				,ISNULL(udp.StartingScrapPer,0)
				,ISNULL(udp.StartingScrap,0)
				,ISNULL(udp.RoomLoss,0)
				,ISNULL(udp.MSU,0)
				,ISNULL(udp.TotalCases,0)
				,ISNULL(udp.RateUtilization,0)
				,ISNULL(udp.RunEff,0)
				--,ISNULL(udp.SafetyTrigg,0)
				--,ISNULL(udp.QualityTrigg,0)
				,ISNULL(udp.VSNetProduction,0)
				,ISNULL(udp.VSPR,0)
				,ISNULL(udp.VSPRLossPer,0)--
				,ISNULL(udp.PRRateLoss,0)
				,ISNULL(udd.TotalStops,0)
				,ISNULL(udd.Duration,0)
				,ISNULL(udd.TotalUpdDowntime,0)
				,ISNULL(udd.TotalUpdStops,0)
				,ISNULL(udd.MinorStops,0)
				,ISNULL(udd.ProcFailures,0)
				,ISNULL(udd.MajorStops,0)
				,ISNULL(udd.Uptime,0)
				,ISNULL(udd.MTBF,0)
				,ISNULL(udd.MTBFUpd,0)
				,ISNULL(udd.MTTR,0)
				,ISNULL(udd.UpsDTPRLoss,0)
				,ISNULL(udd.R0,0)
				,ISNULL(udd.R2,0)
				,ISNULL(udd.BreakDown,0)
				,ISNULL(udd.MTTRUpd,0)
				,ISNULL(udd.UpdDownPerc,0)
				,ISNULL(udd.StopsDay,0)
				,ISNULL(udd.ProcFailuresDay,0)
				,ISNULL(udd.Availability_Unpl_DT,0)
				,ISNULL(udd.Availability_Total_DT,0)
				,ISNULL(udd.MTBS,0)
				,ISNULL(udd.ACPStops,0)
				,ISNULL(udd.ACPStopsDay,0)
				,ISNULL(udd.RepairTimeT,0)
				,ISNULL(udd.FalseStarts0,0)
				,ISNULL(udd.FalseStarts0Per,0)
				,ISNULL(udd.FalseStartsT,0)
				,ISNULL(udd.FalseStartsTPer,0)
				,ISNULL(udd.Survival240Rate,0)
				,ISNULL(udd.Survival240RatePer,0)
				,ISNULL(udd.EditedStops,0)
				,ISNULL(udd.EditedStopsPer,0)
				,ISNULL(udd.TotalUpdStopDay,0)
				,ISNULL(udd.StopsBDSDay,0)
				,ISNULL(udd.TotalPlannedStops,0)
				,ISNULL(udd.TotalPlannedStopsDay,0)
				,ISNULL(udd.MajorStopsDay,0)
				,ISNULL(udd.MinorStopsDay,0)
				,ISNULL(udd.TotalStarvedStops,0)
				,ISNULL(udd.TotalBlockedStops,0)
				,ISNULL(udd.TotalStarvedDowntime,0)
				,ISNULL(udd.TotalBlockedDowntime,0)
				,ISNULL(udd.VSScheduledTime,0)
				,ISNULL(udd.VSPRLossPlanned,0)
				,ISNULL(udd.VSPRLossUnplanned,0)
				,ISNULL(udd.VSPRLossBreakdown,0)
				,ISNULL(udd.Survival210Rate,0)
				,ISNULL(udd.Survival210RatePer,0)
				,ISNULL(udd.R210,0)
				,ISNULL(udd.R240,0)
				,ISNULL(udd.Availability_Planned_DT,0)
				,ISNULL(udd.TotalPlannedDowntime,0)
				,ISNULL(udd.PlannedDTPRLoss,0)
				,ISNULL(udp.Area4LossPer,0)
				,0 --,ISNULL(udp.ConvertedCases,0) 
				,ISNULL(udp.BrandProjectPer,0)		
				,ISNULL(udp.EO_NonShippablePer,0)		
				,ISNULL(udp.LineNotStaffedPer,0)		
				,ISNULL(udp.STNUPer,0)		
				,ISNULL(udp.PRLossScrap,0)
				,ISNULL(udp.StatUnits,0)
				,ISNULL(udd.IdleTime,0)					
				,ISNULL(udd.ExcludedTime,0)				
				,ISNULL(udd.MAchineStopsDay,0)			
				,ISNULL(udp.StatCases,0)			
				,ISNULL(udp.TargetRateAdj,0)
				,ISNULL(udp.PR_Excl_PRInDev,0)
				,ISNULL(udp.NetProductionExcDev,0)
				,ISNULL(udp.ScheduleTimeExcDev,0)	
				,ISNULL(udp.MSUExcDev,0)
				,ISNULL(udp.ProjConstructPerc,0)
				,ISNULL(udp.STNUSchedVarPerc,0)
				,ISNULL(udp.StatFactor,0)
			FROM @Equipment e 
			JOIN dbo.LINE_DIMENSION l (NOLOCK) ON e.PLId = l.PLId
			JOIN dbo.Workcell_Dimension wd (NOLOCK) ON e.PUId = wd.PUId
			LEFT JOIN #UserDefinedProduction udp ON udp.WorkCellId = wd.WorkCellId
			LEFT JOIN #UserDefinedDowntime udd ON udd.WorkCellId = wd.WorkCellId

		END		
		-- Add Production Time metric to minor group
			UPDATE @MinorGroup
				SET ProductionTime = Uptime + Duration

		--SELECT '@MinorGroup',* from @MinorGroup

		UPDATE	@MinorGroup
			SET	LineSpeed = CASE WHEN Uptime > 0 THEN TotalProduct / Uptime ELSE 0 END

		UPDATE	@MinorGroup
			SET	PRRateLossTgtRate = (CASE WHEN TargetRate < LineSpeed THEN LineSpeed ELSE TargetRate END)

		UPDATE	@MinorGroup
			SET	EffRateLossDT = CASE WHEN PRRateLossTgtRate > 0 THEN (((PRRateLossTgtRate - LineSpeed) * Uptime) / PRRateLossTgtRate) ELSE 0 END

		--UPDATE @MinorGroup
		--	SET	PercentPRRateLoss = CASE WHEN ScheduleTime > 0 THEN (EffRateLossDT / ScheduleTime) ELSE 0 END	

		-- --------------------------------------------------------------------------------------------------------------------
		-- Get KPI's for the MAJOR group
		-- --------------------------------------------------------------------------------------------------------------------
		IF ((SELECT COUNT(*) FROM @Equipment) = 1)
		BEGIN
			INSERT INTO @MajorGroup(
					 MajorGroupId
					,MajorGroupBy	
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,CalendarTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss			
					,ProductionTime				
					,EffRateLossDT				
					,PercentPRRateLoss			
					,NetProduction				
					,Area4LossPer				
					,ConvertedCases				
					,PRRateLossTgtRate			
					,BrandProjectPer			
					,EO_NonShippablePer			
					,LineNotStaffedPer			
					,STNUPer					
					,PRLossScrap				
					,StatUnits					
					,PRLossDivisor	
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev			
					,IdleTime					
					,ExcludedTime						
					,StatCases			
					,TargetRateAdj
					,MAchineStopsDay
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)

			SELECT  
					 MajorGroupId
					,MajorGroupBy	
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,CalendarTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime	
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss			
					,ProductionTime				
					,EffRateLossDT				
					,PercentPRRateLoss			
					,NetProduction				
					,Area4LossPer				
					,ConvertedCases				
					,PRRateLossTgtRate			
					,BrandProjectPer			
					,EO_NonShippablePer			
					,LineNotStaffedPer			
					,STNUPer					
					,PRLossScrap				
					,StatUnits					
					,PRLossDivisor		
				    ,PR_Excl_PRInDev	
				    ,NetProductionExcDev
				    ,ScheduleTimeExcDev	
				    ,MSUExcDev			
					,IdleTime					
					,ExcludedTime				
					,StatCases			
					,TargetRateAdj	
					,MAchineStopsDay
					,ProjConstructPerc
					,STNUSchedVarPerc		
					,StatFactor		

			FROM @MinorGroup
		END
		ELSE
		BEGIN
			INSERT INTO @MajorGroup(
					MajorGroupId
					,MajorGroupBy		)	
					--,StartTime				
					--,EndTime)
			SELECT DISTINCT 
					 VSId	
					,ValuestreamDesc	
					--,StartTime			
					--,EndTime
			FROM @Equipment			

			--select '@MinorGroup',* from @MinorGroup
			--select '@MajorGroup',* from @MajorGroup
			--select '@Equipment',* from @Equipment

			SELECT @maxMajor = MAX(ID) FROM @MajorGroup

			SET @index = 1
		

			WHILE @index <= @maxMajor
			BEGIN	
				UPDATE mag
							SET 
								TotalScrap = (SELECT SUM(TotalScrap) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)					,
								Duration = (SELECT SUM(Duration) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)						,
								Uptime = (SELECT SUM(Uptime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)							,
								TotalUpdDowntime = (SELECT SUM(TotalUpdDowntime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)		,
								TotalPlannedDowntime = (SELECT SUM(TotalPlannedDowntime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId),							
								Breakdown = (SELECT SUM(Breakdown) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)						,
								ProductionTime = (SELECT SUM(ProductionTime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)			,
								TotalProduct  = (SELECT SUM(TotalProduct) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)				,
								GoodProduct  = (SELECT SUM(GoodProduct) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)					,
								ScheduleTime = (SELECT SUM(ScheduleTime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)				,
								TotalStops = (SELECT SUM(TotalStops) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)					,
								EditedStops = (SELECT SUM(EditedStops) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)					,
								TotalUpdStops = (SELECT SUM(TotalUpdStops) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)				,
								TotalPlannedStops = (SELECT SUM(TotalPlannedStops) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)		,
								EffRateLossDT = (SELECT SUM(EffRateLossDT) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)				,
								MinorStops = (SELECT SUM(MinorStops) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)					,
								MajorStops = (SELECT SUM(MajorStops) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)					,
								ProcFailures = 	(SELECT SUM(ProcFailures) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)									
				FROM   @MajorGroup mag
				WHERE  ID = @index
	
				UPDATE @MajorGroup
					SET TargetRate	= CASE	WHEN	(GoodProduct = 0 OR GoodProduct IS NULL) THEN 0 ELSE
											(SELECT SUM(GoodProduct)/SUM(GoodProduct/TargetRate)
												FROM @MinorGroup min 
												WHERE min.MajorGroupId = om.MajorGroupId
												AND min.TargetRate > 0
												AND min.GoodProduct > 0) END	
				FROM   @MajorGroup om
				WHERE  ID = @index

				UPDATE @MajorGroup
					SET ActualRate	= CASE	WHEN	(GoodProduct = 0 OR GoodProduct IS NULL) THEN 0 ELSE
											(SELECT SUM(GoodProduct)/SUM(GoodProduct/ActualRate)
												FROM @MinorGroup min 
												WHERE min.MajorGroupId = om.MajorGroupId
												AND min.ActualRate > 0
												AND min.GoodProduct > 0) END	
				FROM   @MajorGroup om
				WHERE  ID = @index
			
				UPDATE mag
						SET
						PlannedDTPRLoss		= (CASE WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0 ELSE (TotalPlannedDowntime / ScheduleTime) * 100 END),
						UpsDTPRLoss	= (CASE WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0 ELSE (TotalUpdDowntime / ScheduleTime) * 100 END),
						PercentPRLossBreakdownDT	= (CASE WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0 ELSE (Breakdown / ScheduleTime) * 100 END),
					
						EditedStopsPer		= (CASE WHEN TotalStops = 0 OR TotalStops IS NULL THEN 0 ELSE (CONVERT(FLOAT,EditedStops) / CONVERT(FLOAT,TotalStops)) * 100 END),
						UpdDownPerc			= ISNULL((CASE WHEN Duration = 0 THEN 0 ELSE (TotalUpdDowntime / Duration) * 100 END),0),
						PercentPRRateLoss   = (CASE WHEN ScheduleTime = 0 THEN 0 ELSE (EffRateLossDT / ScheduleTime) * 100 END)
					FROM @MajorGroup mag
					WHERE  ID = @index


				UPDATE @MajorGroup
					SET Availability_Total_DT		= CASE	WHEN Uptime > 0 AND (ProductionTime = 0 OR ProductionTime IS NULL) THEN 100 
														WHEN Uptime = 0 THEN 0 
														ELSE (Uptime / ProductionTime)   
														END,
										
						Availability_Unpl_DT		= CASE	WHEN Uptime > 0 AND (TotalUpdDowntime = 0 OR TotalUpdDowntime IS NULL) THEN 100 
														WHEN Uptime = 0 THEN 0 
														ELSE (Uptime / (Uptime + TotalUpdDowntime)) 
														END,
						Availability_Planned_DT		= CASE	WHEN Uptime > 0 AND (TotalPlannedDowntime = 0 OR TotalPlannedDowntime IS NULL) THEN 100 
														WHEN Uptime = 0 THEN 0 
														ELSE (Uptime / (Uptime + TotalPlannedDowntime)) 
														END
					WHERE  ID = @index
			
				------------------------------------------------------------------------------------------------------------------------------------
				-- Machine Scrap
				UPDATE @MajorGroup
					SET ScrapPer			= CASE	WHEN	(TotalProduct = 0 OR TotalProduct IS NULL)
																THEN 0 ELSE (TotalScrap / TotalProduct) * 100  END
				WHERE  ID = @index
		
				------------------------------------------------------------------------------------------------------------------------
				UPDATE	mag
					SET 
						MTBFUpd  = 				(	SELECT 
															SUM(Uptime) / SUM(Uptime / MTBFUpd)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND MTBFUpd > 0		
															HAVING SUM(Uptime / MTBFUpd) > 0	)				,
						MTBF =					(	SELECT 
															SUM(Uptime) / SUM(Uptime / MTBF)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND MTBF > 0
															HAVING SUM(Uptime / MTBF) > 0		)		,
						MTTR =					(	SELECT 
															SUM(Duration) / SUM(Duration / MTTR)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND MTTR > 0
															HAVING SUM(Duration / MTTR) > 0		)			,
						MTTRUpd =				(	SELECT 
															SUM(TotalUpdDowntime) / SUM(TotalUpdDowntime / MTTRUpd)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND MTTRUpd > 0
															HAVING SUM(TotalUpdDowntime / MTTRUpd) > 0		)		,
						TotalUpdStopDay =		(	SELECT 
															SUM(ScheduleTime * TotalUpdStopDay) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	)							,
						TotalPlannedStopsDay =	(	SELECT 
															SUM(ScheduleTime * TotalPlannedStopsDay) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	)							,
						MinorStopsDay =			(	SELECT 
															SUM(ScheduleTime * MinorStopsDay) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	)							,
						ProcFailuresDay = 		(	SELECT 
															SUM(ScheduleTime * ProcFailuresDay) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	)							,
						MajorStopsDay =			(	SELECT 
															SUM(ScheduleTime * MajorStopsDay) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	)							,
						StopsDay =				(	SELECT 
															SUM(ScheduleTime * StopsDay) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	)	,
						StopsBDSDay =			(	SELECT 
															SUM(ScheduleTime * Breakdown) / SUM(ScheduleTime)
															FROM @MinorGroup mig
															WHERE mig.MajorGroupId = mag.MajorGroupId
															AND ScheduleTime > 0
															HAVING SUM(ScheduleTime) > 0	) 		
				FROM	@MajorGroup mag	
				WHERE  ID = @index
			
				-- New PR formula					
				UPDATE @MajorGroup
					SET PR	= ((GoodProduct/ CASE WHEN TargetRate > ActualRate THEN TargetRate ELSE ActualRate END)  / ScheduleTime ) * 100
				FROM	@MajorGroup mag	
				WHERE  ID = @index
				AND  ScheduleTime > 0
				AND  TargetRate > 0
				--------------------------------------------------------------------------------------------------------------------------------------
				-- New calculations from Latest Mockup: Value Stream Net Production, Value Stream Scheduled Time:		
				UPDATE mag
						SET
								VSTotalProduction = (SELECT SUM(TotalProduct) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)		,
								VSNetProduction = (SELECT SUM(GoodProduct) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)		,
								VSScheduledTime = (SELECT SUM(ScheduleTime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId)		,
								VSTargetRate	= ISNULL((	SELECT SUM(GoodProduct * ISNULL(TargetRate,0)) / SUM(GoodProduct) 
															FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId
																AND GoodProduct > 0
																AND GoodProduct IS NOT NULL	),0)										,
								VSTotalUpdDowntime = (SELECT SUM(TotalUpdDowntime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId) ,
								VSTotalPlannedDowntime = (SELECT SUM(TotalPlannedDowntime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId) ,
								VSBreakdown = (SELECT SUM(Breakdown) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId), 
								VSEffRateLossDowntime = (SELECT SUM(EffRateLossDT) / SUM(ScheduleTime) FROM @MinorGroup min WHERE min.MajorGroupId = mag.MajorGroupId HAVING SUM(ScheduleTime) <> 0) 
				FROM   @MajorGroup mag
				WHERE  ID = @index	

				-- New VS metrics	
				UPDATE @MajorGroup
						SET	VSPRLossUnplanned	= CASE	WHEN	(VSScheduledTime = 0 OR VSScheduledTime IS NULL)
															THEN 0 ELSE (VSTotalUpdDowntime / VSScheduledTime) * 100 END
				FROM   @MajorGroup
				WHERE  ID = @index	

				UPDATE @MajorGroup
						SET	VSPRLossPlanned	= CASE	WHEN	(VSScheduledTime = 0 OR VSScheduledTime IS NULL)
															THEN 0 ELSE (VSTotalPlannedDowntime / VSScheduledTime) * 100 END
					FROM   @MajorGroup
					WHERE  ID = @index	
				
				UPDATE @MajorGroup
						SET	VSPRLossBreakdown	= CASE	WHEN	(VSScheduledTime = 0 OR VSScheduledTime IS NULL)
															THEN 0 ELSE (VSBreakdown / VSScheduledTime) * 100 END
				FROM   @MajorGroup
				WHERE  ID = @index	
			
				UPDATE @MajorGroup
						SET	VSPRLossPer	= CASE	WHEN (VSScheduledTime = 0 OR VSScheduledTime IS NULL)
															THEN 0 
															ELSE (VSEffRateLossDowntime / VSScheduledTime) * 100 END
				FROM   @MajorGroup
				WHERE  ID = @index

				UPDATE mag
					SET MTBF = (CASE WHEN TotalStops = 0 THEN Uptime ELSE MTBF  END)  ,
						MTBFUpd = (CASE WHEN TotalUpdStops = 0 THEN Uptime ELSE MTBFUpd END) 
				FROM	@MajorGroup mag	

		
				UPDATE mag
					SET VSPR = (VSNetProduction / ((VSScheduledTime * VSTargetRate) / 1)) * 100 							
																	
				FROM	@MajorGroup mag	
				WHERE  ID = @index
				AND VSScheduledTime > 0
				AND VSTargetRate > 0


				-- DO not let ValueStreamPR go negative
				UPDATE mag
						SET VSPR = 0										
					FROM	@MajorGroup mag	
					WHERE VSPR < 0 
					OR VSPR IS NULL
					AND ID = @index

				SET @index = @index + 1
			END
		END
		--SELECT '@MajorGroup',* FROM @MajorGroup
END
		--return
--=====================================================================================================================
-- Major Group: Workcell
-- --------------------------------------------------------------------------------------------------------------------
IF @strMajorGroupBy = 'WorkCell'
BEGIN
	IF @strMinorGroupBy = 'ProdDay'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap				
					,StatUnits	
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay						
					,StatCases			
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev			
					,ProjConstructPerc
					,STNUSchedVarPerc
					,StatFactor)					

				SELECT DISTINCT
					 pd.ProdDayId	
					,CONVERT(DATE,pd.ProdDay)
					,pd.PUId
					,pd.PUDesc
					,ISNULL(fp.TeamDesc,0)
					,pd.StartTime
					,fp.LineStatus					
					,pd.EndTime						
					,ISNULL(fp.GoodProduct,0)
					,ISNULL(fp.TotalProduct,0)
					,ISNULL(fp.TotalScrap,0)
					,ISNULL(fp.ActualRate,0)
					,ISNULL(fp.TargetRate,0)
					,ISNULL(fp.ScheduleTime,0)
					,ISNULL(fp.PR,0)
					,ISNULL(fp.ScrapPer,0)
					,ISNULL(fp.IdealRate,0)
					,ISNULL(fp.STNU,0)
					,ISNULL(fp.CapacityUtilization,0)
					,ISNULL(fp.ScheduleUtilization,0)
					,ISNULL(fp.Availability,0)
					,ISNULL(fp.PRAvailability,0)
					,ISNULL(fp.StopsMSU,0)
					,ISNULL(fp.DownMSU,0)
					,ISNULL(fp.RunningScrapPer,0)
					,ISNULL(fp.RunningScrap,0)
					,ISNULL(fp.StartingScrapPer,0)
					,ISNULL(fp.StartingScrap,0)
					,ISNULL(fp.RoomLoss,0)
					,ISNULL(fp.MSU,0)
					,ISNULL(fp.TotalCases,0)
					,ISNULL(fp.RateUtilization,0)
					,ISNULL(fp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(fp.VSNetProduction,0)
					,ISNULL(fp.VSPR,0)
					,ISNULL(fp.VSPRLossPer,0)--
					,ISNULL(fp.PRRateLoss,0)
					,ISNULL(fd.TotalStops,0)
					,ISNULL(fd.Duration,0)
					,ISNULL(fd.TotalUpdDowntime,0)
					,ISNULL(fd.TotalUpdStops,0)
					,ISNULL(fd.MinorStops,0)
					,ISNULL(fd.ProcFailures,0)
					,ISNULL(fd.MajorStops,0)
					,ISNULL(fd.Uptime,0)
					,ISNULL(fd.MTBF,0)
					,ISNULL(fd.MTBFUpd,0)
					,ISNULL(fd.MTTR,0)
					,ISNULL(fd.UpsDTPRLoss,0)
					,ISNULL(fd.R0,0)
					,ISNULL(fd.R2,0)
					,ISNULL(fd.BreakDown,0)
					,ISNULL(fd.MTTRUpd,0)
					,ISNULL(fd.UpdDownPerc,0)
					,ISNULL(fd.StopsDay,0)
					,ISNULL(fd.ProcFailuresDay,0)
					,ISNULL(fd.Availability_Unpl_DT,0)
					,ISNULL(fd.Availability_Total_DT,0)
					,ISNULL(fd.MTBS,0)
					,ISNULL(fd.ACPStops,0)
					,ISNULL(fd.ACPStopsDay,0)
					,ISNULL(fd.RepairTimeT,0)
					,ISNULL(fd.FalseStarts0,0)
					,ISNULL(fd.FalseStarts0Per,0)
					,ISNULL(fd.FalseStartsT,0)
					,ISNULL(fd.FalseStartsTPer,0)
					,ISNULL(fd.Survival240Rate,0)
					,ISNULL(fd.Survival240RatePer,0)
					,ISNULL(fd.EditedStops,0)
					,ISNULL(fd.EditedStopsPer,0)
					,ISNULL(fd.TotalUpdStopDay,0)
					,ISNULL(fd.StopsBDSDay,0)
					,ISNULL(fd.TotalPlannedStops,0)
					,ISNULL(fd.TotalPlannedStopsDay,0)
					,ISNULL(fd.MajorStopsDay,0)
					,ISNULL(fd.MinorStopsDay,0)
					,ISNULL(fd.TotalStarvedStops,0)
					,ISNULL(fd.TotalBlockedStops,0)
					,ISNULL(fd.TotalStarvedDowntime,0)
					,ISNULL(fd.TotalBlockedDowntime,0)
					,ISNULL(fd.VSScheduledTime,0)
					,ISNULL(fd.VSPRLossPlanned,0)
					,ISNULL(fd.VSPRLossUnplanned,0)
					,ISNULL(fd.VSPRLossBreakdown,0)
					,ISNULL(fd.Survival210Rate,0)
					,ISNULL(fd.Survival210RatePer,0)
					,ISNULL(fd.R210,0)
					,ISNULL(fd.R240,0)
					,ISNULL(fd.Availability_Planned_DT,0)
					,ISNULL(fd.TotalPlannedDowntime,0)
					,ISNULL(fd.PlannedDTPRLoss,0)
					,ISNULL(fp.Area4LossPer,0)
					,0 --,ISNULL(fp.ConvertedCases,0) 
					,ISNULL(fp.BrandProjectPer,0)		
					,ISNULL(fp.EO_NonShippablePer,0)		
					,ISNULL(fp.LineNotStaffedPer,0)		
					,ISNULL(fp.STNUPer,0)		
					,ISNULL(fp.PRLossScrap,0)
					,ISNULL(fp.StatUnits,0)
					,ISNULL(fd.IdleTime,0)					
					,ISNULL(fd.ExcludedTime,0)				
					,ISNULL(fd.MAchineStopsDay,0)			
					,ISNULL(fp.StatCases,0)			
					,ISNULL(fp.TargetRateAdj,0)
					,ISNULL(fp.PR_Excl_PRInDev,0)
					,ISNULL(fp.NetProductionExcDev,0)
					,ISNULL(fp.ScheduleTimeExcDev,0)	
					,ISNULL(fp.MSUExcDev,0)	
					,ISNULL(fp.ProjConstructPerc,0)
					,ISNULL(fp.STNUSchedVarPerc,0)		
					,ISNULL(fp.StatFactor,0)
				FROM @ProdDay pd 
				JOIN dbo.Workcell_Dimension wd (NOLOCK) ON pd.PUId = wd.PUId
				LEFT JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.Workcell_Dimension_WorkcellId = wd.WorkcellId
															AND fp.LineStatus = @strNPT		
															AND fp.Date_Dimension_DateId = 2		
															AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,pd.StartTime)
															AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,pd.EndTime)
															AND fp.ShiftDesc = 'All'		
															AND fp.TeamDesc = 'All'
				LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.Workcell_Dimension_WorkcellId = wd.WorkcellId
															AND fd.LineStatus = @strNPT
															AND fd.Date_Dimension_DateId = 2
															AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,pd.StartTime)
															AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,pd.EndTime)
															AND fd.ShiftDesc = 'All'
															AND fd.TeamDesc = 'All'

				--SELECT '@MinorGroup',* from @MinorGroup
		END
		ELSE
		BEGIN
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Day'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Day'
			
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime


			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					----,SafetyTrigg				
					----,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer
					,PercentPRRateLoss					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap					
					,StatUnits							
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

				SELECT 
					 pd.ProdDayId	
					,CONVERT(DATE,pd.ProdDay)
					,pd.PUId
					,pd.PUDesc
					,ISNULL(udp.TeamDesc,0)
					,pd.StartTime
					,udp.Status					
					,pd.EndTime									
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(udp.SafetyTrigg,0)
					--,ISNULL(udp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,ISNULL(udp.Area4LossPer,0)
					,ISNULL(udp.ConvertedCases,0) 
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)	
					,ISNULL(udp.PRLossScrap,0)
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)	
					,ISNULL(udp.StatFactor,0)
					
				FROM @ProdDay pd 
				JOIN dbo.LINE_DIMENSION l (NOLOCK) ON pd.PLId = l.PLId
				JOIN dbo.Workcell_Dimension wd (NOLOCK) ON pd.PUId = wd.PUId
				LEFT JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
											   AND udp.Starttime = pd.StartTime
											   AND udp.Endtime = pd.EndTime
				LEFT JOIN #UserDefinedDowntime udd ON udd.WorkCellId = wd.WorkCellId
											   AND udd.Starttime = pd.StartTime
											   AND udd.Endtime = pd.EndTime
			
			--SELECT '@MinorGroup',* from @MinorGroup
		END
	END

	IF @strMinorGroupBy = 'Shift'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap							
					,StatUnits	
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay						
					,StatCases			
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)				

				SELECT DISTINCT
					 ts.RcdIdx
					,fp.ShiftDesc
					,ts.PUId
					,ts.PUDesc
					,ISNULL(fp.TeamDesc,0)
					,ts.StartTime
					,fp.LineStatus					
					,ts.EndTime						
					,ISNULL(fp.GoodProduct,0)
					,ISNULL(fp.TotalProduct,0)
					,ISNULL(fp.TotalScrap,0)
					,ISNULL(fp.ActualRate,0)
					,ISNULL(fp.TargetRate,0)
					,ISNULL(fp.ScheduleTime,0)
					,ISNULL(fp.PR,0)
					,ISNULL(fp.ScrapPer,0)
					,ISNULL(fp.IdealRate,0)
					,ISNULL(fp.STNU,0)
					,ISNULL(fp.CapacityUtilization,0)
					,ISNULL(fp.ScheduleUtilization,0)
					,ISNULL(fp.Availability,0)
					,ISNULL(fp.PRAvailability,0)
					,ISNULL(fp.StopsMSU,0)
					,ISNULL(fp.DownMSU,0)
					,ISNULL(fp.RunningScrapPer,0)
					,ISNULL(fp.RunningScrap,0)
					,ISNULL(fp.StartingScrapPer,0)
					,ISNULL(fp.StartingScrap,0)
					,ISNULL(fp.RoomLoss,0)
					,ISNULL(fp.MSU,0)
					,ISNULL(fp.TotalCases,0)
					,ISNULL(fp.RateUtilization,0)
					,ISNULL(fp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(fp.VSNetProduction,0)
					,ISNULL(fp.VSPR,0)
					,ISNULL(fp.VSPRLossPer,0)--
					,ISNULL(fp.PRRateLoss,0)
					,ISNULL(fd.TotalStops,0)
					,ISNULL(fd.Duration,0)
					,ISNULL(fd.TotalUpdDowntime,0)
					,ISNULL(fd.TotalUpdStops,0)
					,ISNULL(fd.MinorStops,0)
					,ISNULL(fd.ProcFailures,0)
					,ISNULL(fd.MajorStops,0)
					,ISNULL(fd.Uptime,0)
					,ISNULL(fd.MTBF,0)
					,ISNULL(fd.MTBFUpd,0)
					,ISNULL(fd.MTTR,0)
					,ISNULL(fd.UpsDTPRLoss,0)
					,ISNULL(fd.R0,0)
					,ISNULL(fd.R2,0)
					,ISNULL(fd.BreakDown,0)
					,ISNULL(fd.MTTRUpd,0)
					,ISNULL(fd.UpdDownPerc,0)
					,ISNULL(fd.StopsDay,0)
					,ISNULL(fd.ProcFailuresDay,0)
					,ISNULL(fd.Availability_Unpl_DT,0)
					,ISNULL(fd.Availability_Total_DT,0)
					,ISNULL(fd.MTBS,0)
					,ISNULL(fd.ACPStops,0)
					,ISNULL(fd.ACPStopsDay,0)
					,ISNULL(fd.RepairTimeT,0)
					,ISNULL(fd.FalseStarts0,0)
					,ISNULL(fd.FalseStarts0Per,0)
					,ISNULL(fd.FalseStartsT,0)
					,ISNULL(fd.FalseStartsTPer,0)
					,ISNULL(fd.Survival240Rate,0)
					,ISNULL(fd.Survival240RatePer,0)
					,ISNULL(fd.EditedStops,0)
					,ISNULL(fd.EditedStopsPer,0)
					,ISNULL(fd.TotalUpdStopDay,0)
					,ISNULL(fd.StopsBDSDay,0)
					,ISNULL(fd.TotalPlannedStops,0)
					,ISNULL(fd.TotalPlannedStopsDay,0)
					,ISNULL(fd.MajorStopsDay,0)
					,ISNULL(fd.MinorStopsDay,0)
					,ISNULL(fd.TotalStarvedStops,0)
					,ISNULL(fd.TotalBlockedStops,0)
					,ISNULL(fd.TotalStarvedDowntime,0)
					,ISNULL(fd.TotalBlockedDowntime,0)
					,ISNULL(fd.VSScheduledTime,0)
					,ISNULL(fd.VSPRLossPlanned,0)
					,ISNULL(fd.VSPRLossUnplanned,0)
					,ISNULL(fd.VSPRLossBreakdown,0)
					,ISNULL(fd.Survival210Rate,0)
					,ISNULL(fd.Survival210RatePer,0)
					,ISNULL(fd.R210,0)
					,ISNULL(fd.R240,0)
					,ISNULL(fd.Availability_Planned_DT,0)
					,ISNULL(fd.TotalPlannedDowntime,0)
					,ISNULL(fd.PlannedDTPRLoss,0)
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(fp.Area4LossPer,0)
					,0 --,ISNULL(fp.ConvertedCases,0) 
					,ISNULL(fp.BrandProjectPer,0)		
					,ISNULL(fp.EO_NonShippablePer,0)		
					,ISNULL(fp.LineNotStaffedPer,0)		
					,ISNULL(fp.STNUPer,0)
					,ISNULL(fp.PRLossScrap,0)	
					,ISNULL(fp.StatUnits,0)	
					,ISNULL(fd.IdleTime,0)					
					,ISNULL(fd.ExcludedTime,0)				
					,ISNULL(fd.MAchineStopsDay,0)				
					,ISNULL(fp.StatCases,0)		
					,ISNULL(fp.TargetRateAdj,0)
					,ISNULL(fp.PR_Excl_PRInDev,0)
					,ISNULL(fp.NetProductionExcDev,0)
					,ISNULL(fp.ScheduleTimeExcDev,0)	
					,ISNULL(fp.MSUExcDev,0)	
					,ISNULL(fp.ProjConstructPerc,0)
					,ISNULL(fp.STNUSchedVarPerc,0)
					,ISNULL(fp.StatFactor,0)
				FROM @TeamShift ts 
				JOIN dbo.Workcell_Dimension wd (NOLOCK) ON wd.PUId = ts.PUId
				JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.Workcell_Dimension_WorkcellId = wd.WorkcellId
															AND fp.LineStatus = @strNPT		
															AND fp.Date_Dimension_DateId = @intTimeOption		
															AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,ts.StartTime)
															AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,ts.EndTime)
															AND fp.ShiftDesc = ts.ShiftDesc
															AND fp.TeamDesc = 'All'
				LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.Workcell_Dimension_WorkcellId = wd.WorkcellId
															AND fd.LineStatus = @strNPT		
															AND fd.Date_Dimension_DateId = @intTimeOption	
															AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,ts.StartTime)
															AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,ts.EndTime)
															AND fd.ShiftDesc = ts.ShiftDesc
															AND fd.TeamDesc = 'All'

				--SELECT '@MinorGroup',* from @MinorGroup
		END
		ELSE
		BEGIN
			--inser values from custom aggregates
			--Production AGG		
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Shift'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Shift'
			
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime


			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					----,SafetyTrigg				
					----,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer
					,PercentPRRateLoss					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap						
					,StatUnits							
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,TargetRateAdj
					,PR_Excl_PRInDev
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc				
					,StatFactor)			

				SELECT 
					 ts.RcdIdx								
					,udp.ShiftDesc							
					,ts.PUId								
					,ts.PUDesc								
					,ISNULL(udp.TeamDesc,0)					
					,ts.StartTime							
					,udp.Status								
					,ts.EndTime							
					,ISNULL(udp.GoodProduct,0)				
					,ISNULL(udp.TotalProduct,0)				
					,ISNULL(udp.TotalScrap,0)				
					,ISNULL(udp.ActualRate,0)				
					,ISNULL(udp.TargetRate,0)				
					,ISNULL(udp.ScheduleTime,0)				
					,ISNULL(udp.PR,0)						
					,ISNULL(udp.ScrapPer,0)					
					,ISNULL(udp.IdealRate,0)				
					,ISNULL(udp.STNU,0)						
					,ISNULL(udp.CapacityUtilization,0)		
					,ISNULL(udp.ScheduleUtilization,0)		
					,ISNULL(udp.Availability,0)				
					,ISNULL(udp.PRAvailability,0)			
					,ISNULL(udp.StopsMSU,0)					
					,ISNULL(udp.DownMSU,0)					
					,ISNULL(udp.RunningScrapPer,0)			
					,ISNULL(udp.RunningScrap,0)				
					,ISNULL(udp.StartingScrapPer,0)			
					,ISNULL(udp.StartingScrap,0)			
					,ISNULL(udp.RoomLoss,0)					
					,ISNULL(udp.MSU,0)						
					,ISNULL(udp.TotalCases,0)				
					,ISNULL(udp.RateUtilization,0)			
					,ISNULL(udp.RunEff,0)					
					--,ISNULL(udp.SafetyTrigg,0)			
					--,ISNULL(udp.QualityTrigg,0)			
					,ISNULL(udp.VSNetProduction,0)			
					,ISNULL(udp.VSPR,0)						
					,ISNULL(udp.VSPRLossPer,0)--			
					,ISNULL(udp.PRRateLoss,0)				
					,ISNULL(udd.TotalStops,0)				
					,ISNULL(udd.Duration,0)					
					,ISNULL(udd.TotalUpdDowntime,0)			
					,ISNULL(udd.TotalUpdStops,0)			
					,ISNULL(udd.MinorStops,0)				
					,ISNULL(udd.ProcFailures,0)				
					,ISNULL(udd.MajorStops,0)				
					,ISNULL(udd.Uptime,0)					
					,ISNULL(udd.MTBF,0)						
					,ISNULL(udd.MTBFUpd,0)					
					,ISNULL(udd.MTTR,0)						
					,ISNULL(udd.UpsDTPRLoss,0)				
					,ISNULL(udd.R0,0)						
					,ISNULL(udd.R2,0)						
					,ISNULL(udd.BreakDown,0)				
					,ISNULL(udd.MTTRUpd,0)					
					,ISNULL(udd.UpdDownPerc,0)				
					,ISNULL(udd.StopsDay,0)					
					,ISNULL(udd.ProcFailuresDay,0)			
					,ISNULL(udd.Availability_Unpl_DT,0)		
					,ISNULL(udd.Availability_Total_DT,0)	
					,ISNULL(udd.MTBS,0)						
					,ISNULL(udd.ACPStops,0)					
					,ISNULL(udd.ACPStopsDay,0)				
					,ISNULL(udd.RepairTimeT,0)				
					,ISNULL(udd.FalseStarts0,0)				
					,ISNULL(udd.FalseStarts0Per,0)			
					,ISNULL(udd.FalseStartsT,0)				
					,ISNULL(udd.FalseStartsTPer,0)			
					,ISNULL(udd.Survival240Rate,0)			
					,ISNULL(udd.Survival240RatePer,0)		
					,ISNULL(udd.EditedStops,0)				
					,ISNULL(udd.EditedStopsPer,0)			
					,ISNULL(udd.TotalUpdStopDay,0)			
					,ISNULL(udd.StopsBDSDay,0)				
					,ISNULL(udd.TotalPlannedStops,0)		
					,ISNULL(udd.TotalPlannedStopsDay,0)		
					,ISNULL(udd.MajorStopsDay,0)			
					,ISNULL(udd.MinorStopsDay,0)			
					,ISNULL(udd.TotalStarvedStops,0)		
					,ISNULL(udd.TotalBlockedStops,0)		
					,ISNULL(udd.TotalStarvedDowntime,0)		
					,ISNULL(udd.TotalBlockedDowntime,0)		
					,ISNULL(udd.VSScheduledTime,0)			
					,ISNULL(udd.VSPRLossPlanned,0)			
					,ISNULL(udd.VSPRLossUnplanned,0)		
					,ISNULL(udd.VSPRLossBreakdown,0)		
					,ISNULL(udd.Survival210Rate,0)			
					,ISNULL(udd.Survival210RatePer,0)		
					,ISNULL(udd.R210,0)						
					,ISNULL(udd.R240,0)						
					,ISNULL(udd.Availability_Planned_DT,0)	
					,ISNULL(udd.TotalPlannedDowntime,0)		
					,ISNULL(udd.PlannedDTPRLoss,0)			
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(udp.Area4LossPer,0)				
					,0 --,ISNULL(udp.ConvertedCases,0) 		
					,ISNULL(udp.BrandProjectPer,0)			
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)		
					,ISNULL(udp.PRLossScrap,0)
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)	
					,ISNULL(udp.StatFactor,0)
					
				FROM @TeamShift ts 
				JOIN dbo.LINE_DIMENSION l (NOLOCK) ON ts.PLId = l.PLId
				JOIN dbo.Workcell_Dimension wd (NOLOCK) ON wd.PUId = ts.PUId
				JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
											   AND udp.ShiftDesc = ts.ShiftDesc
											   AND udp.Starttime = ts.StartTime
											   AND udp.Endtime = ts.EndTime
				LEFT JOIN #UserDefinedDowntime udd ON udd.WorkCellId = wd.WorkCellId
											   AND udd.ShiftDesc = ts.ShiftDesc
											   AND udd.Starttime = ts.StartTime
											   AND udd.Endtime = ts.EndTime
			
			--SELECT '@MinorGroup',* from @MinorGroup
		END
	END

	IF @strMinorGroupBy = 'Team'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap							
					,StatUnits	
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay						
					,StatCases			
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)						

				SELECT DISTINCT
					 ts.RcdIdx
					,fp.TeamDesc
					,ts.PUId
					,ts.PUDesc
					,ISNULL(fp.TeamDesc,0)
					,ts.StartTime
					,fp.LineStatus					
					,ts.EndTime						
					,ISNULL(fp.GoodProduct,0)
					,ISNULL(fp.TotalProduct,0)
					,ISNULL(fp.TotalScrap,0)
					,ISNULL(fp.ActualRate,0)
					,ISNULL(fp.TargetRate,0)
					,ISNULL(fp.ScheduleTime,0)
					,ISNULL(fp.PR,0)
					,ISNULL(fp.ScrapPer,0)
					,ISNULL(fp.IdealRate,0)
					,ISNULL(fp.STNU,0)
					,ISNULL(fp.CapacityUtilization,0)
					,ISNULL(fp.ScheduleUtilization,0)
					,ISNULL(fp.Availability,0)
					,ISNULL(fp.PRAvailability,0)
					,ISNULL(fp.StopsMSU,0)
					,ISNULL(fp.DownMSU,0)
					,ISNULL(fp.RunningScrapPer,0)
					,ISNULL(fp.RunningScrap,0)
					,ISNULL(fp.StartingScrapPer,0)
					,ISNULL(fp.StartingScrap,0)
					,ISNULL(fp.RoomLoss,0)
					,ISNULL(fp.MSU,0)
					,ISNULL(fp.TotalCases,0)
					,ISNULL(fp.RateUtilization,0)
					,ISNULL(fp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(fp.VSNetProduction,0)
					,ISNULL(fp.VSPR,0)
					,ISNULL(fp.VSPRLossPer,0)--
					,ISNULL(fp.PRRateLoss,0)
					,ISNULL(fd.TotalStops,0)
					,ISNULL(fd.Duration,0)
					,ISNULL(fd.TotalUpdDowntime,0)
					,ISNULL(fd.TotalUpdStops,0)
					,ISNULL(fd.MinorStops,0)
					,ISNULL(fd.ProcFailures,0)
					,ISNULL(fd.MajorStops,0)
					,ISNULL(fd.Uptime,0)
					,ISNULL(fd.MTBF,0)
					,ISNULL(fd.MTBFUpd,0)
					,ISNULL(fd.MTTR,0)
					,ISNULL(fd.UpsDTPRLoss,0)
					,ISNULL(fd.R0,0)
					,ISNULL(fd.R2,0)
					,ISNULL(fd.BreakDown,0)
					,ISNULL(fd.MTTRUpd,0)
					,ISNULL(fd.UpdDownPerc,0)
					,ISNULL(fd.StopsDay,0)
					,ISNULL(fd.ProcFailuresDay,0)
					,ISNULL(fd.Availability_Unpl_DT,0)
					,ISNULL(fd.Availability_Total_DT,0)
					,ISNULL(fd.MTBS,0)
					,ISNULL(fd.ACPStops,0)
					,ISNULL(fd.ACPStopsDay,0)
					,ISNULL(fd.RepairTimeT,0)
					,ISNULL(fd.FalseStarts0,0)
					,ISNULL(fd.FalseStarts0Per,0)
					,ISNULL(fd.FalseStartsT,0)
					,ISNULL(fd.FalseStartsTPer,0)
					,ISNULL(fd.Survival240Rate,0)
					,ISNULL(fd.Survival240RatePer,0)
					,ISNULL(fd.EditedStops,0)
					,ISNULL(fd.EditedStopsPer,0)
					,ISNULL(fd.TotalUpdStopDay,0)
					,ISNULL(fd.StopsBDSDay,0)
					,ISNULL(fd.TotalPlannedStops,0)
					,ISNULL(fd.TotalPlannedStopsDay,0)
					,ISNULL(fd.MajorStopsDay,0)
					,ISNULL(fd.MinorStopsDay,0)
					,ISNULL(fd.TotalStarvedStops,0)
					,ISNULL(fd.TotalBlockedStops,0)
					,ISNULL(fd.TotalStarvedDowntime,0)
					,ISNULL(fd.TotalBlockedDowntime,0)
					,ISNULL(fd.VSScheduledTime,0)
					,ISNULL(fd.VSPRLossPlanned,0)
					,ISNULL(fd.VSPRLossUnplanned,0)
					,ISNULL(fd.VSPRLossBreakdown,0)
					,ISNULL(fd.Survival210Rate,0)
					,ISNULL(fd.Survival210RatePer,0)
					,ISNULL(fd.R210,0)
					,ISNULL(fd.R240,0)
					,ISNULL(fd.Availability_Planned_DT,0)
					,ISNULL(fd.TotalPlannedDowntime,0)
					,ISNULL(fd.PlannedDTPRLoss,0)
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(fp.Area4LossPer,0)
					,0 --,ISNULL(fp.ConvertedCases,0) 
					,ISNULL(fp.BrandProjectPer,0)		
					,ISNULL(fp.EO_NonShippablePer,0)		
					,ISNULL(fp.LineNotStaffedPer,0)		
					,ISNULL(fp.STNUPer,0)
					,ISNULL(fp.PRLossScrap,0)	
					,ISNULL(fp.StatUnits,0)	
					,ISNULL(fd.IdleTime,0)					
					,ISNULL(fd.ExcludedTime,0)				
					,ISNULL(fd.MAchineStopsDay,0)				
					,ISNULL(fp.StatCases,0)	
					,ISNULL(fp.TargetRateAdj,0)
					,ISNULL(fp.PR_Excl_PRInDev,0)
					,ISNULL(fp.NetProductionExcDev,0)
					,ISNULL(fp.ScheduleTimeExcDev,0)	
					,ISNULL(fp.MSUExcDev,0)
					,ISNULL(fp.ProjConstructPerc,0)
					,ISNULL(fp.STNUSchedVarPerc,0)	
					,ISNULL(fp.StatFactor,0)
				FROM @TeamShift ts 
				JOIN dbo.Workcell_Dimension wd (NOLOCK) ON wd.PUId = ts.PUId
				JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.Workcell_Dimension_WorkcellId = wd.WorkcellId
															AND fp.LineStatus = @strNPT		
															AND fp.Date_Dimension_DateId = @intTimeOption	
															AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,ts.StartTime)
															AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,ts.EndTime)
															AND fp.ShiftDesc = 'All'
															AND fp.TeamDesc = ts.TeamDesc
				LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.Workcell_Dimension_WorkcellId = wd.WorkcellId
															AND fd.LineStatus = @strNPT		
															AND fd.Date_Dimension_DateId = @intTimeOption	
															AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,ts.StartTime)
															AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,ts.EndTime)
															AND fd.ShiftDesc = 'All'
															AND fd.TeamDesc = ts.TeamDesc

				--SELECT '@MinorGroup',* from @MinorGroup
		END
		ELSE
		BEGIN
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Team'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Team'
			
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime


			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap							
					,StatUnits							
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)				

				SELECT 
					 ts.RcdIdx
					,udp.TeamDesc
					,ts.PUId
					,ts.PUDesc
					,ISNULL(udp.TeamDesc,0)
					,ts.StartTime
					,udp.Status					
					,ts.EndTime						
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(udp.SafetyTrigg,0)
					--,ISNULL(udp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(udp.Area4LossPer,0)
					,0 --,ISNULL(udp.ConvertedCases,0) 
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)
					,ISNULL(udp.PRLossScrap,0)	
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)
					,ISNULL(udp.StatFactor,0)
				FROM @TeamShift ts 
				JOIN dbo.LINE_DIMENSION l (NOLOCK) ON ts.PLId = l.PLId
				JOIN dbo.Workcell_Dimension wd (NOLOCK) ON wd.PUId = ts.PUId
				JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
											   AND udp.TeamDesc = ts.TeamDesc
											   AND udp.Starttime = ts.StartTime
											   AND udp.Endtime = ts.EndTime
				LEFT JOIN #UserDefinedDowntime udd ON udd.WorkCellId = wd.WorkCellId
											   AND udd.TeamDesc = ts.TeamDesc
											   AND udd.Starttime = ts.StartTime
											   AND udd.Endtime = ts.EndTime
			
			--SELECT '@MinorGroup',* from @MinorGroup
		END
	END
	-- --------------------------------------------------------------------------------------------------------------------
	-- Get KPI's for the MAJOR group
	-- --------------------------------------------------------------------------------------------------------------------
	IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MajorGroup(
				 MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime					
				,GoodProduct				
				,TotalProduct				
				,TotalScrap					
				,ActualRate					
				,TargetRate					
				,ScheduleTime				
				,PR							
				,ScrapPer					
				,IdealRate					
				,STNU						
				,CapacityUtilization		
				,ScheduleUtilization		
				,Availability				
				,PRAvailability				
				,StopsMSU					
				,DownMSU					
				,RunningScrapPer			
				,RunningScrap				
				,StartingScrapPer			
				,StartingScrap				
				,RoomLoss					
				,MSU						
				,TotalCases					
				,RateUtilization			
				,RunEff						
				--,SafetyTrigg				
				--,QualityTrigg				
				,VSNetProduction			
				,VSPR						
				,VSPRLossPer		
				,PercentPRRateLoss			
				,TotalStops					
				,Duration					
				,TotalUpdDowntime			
				,TotalUpdStops				
				,MinorStops					
				,ProcFailures				
				,MajorStops					
				,Uptime						
				,MTBF						
				,MTBFUpd					
				,MTTR						
				,UpsDTPRLoss				
				,R0							
				,R2							
				,BreakDown					
				,MTTRUpd					
				,UpdDownPerc				
				,StopsDay					
				,ProcFailuresDay			
				,Availability_Unpl_DT		
				,Availability_Total_DT		
				,MTBS						
				,ACPStops					
				,ACPStopsDay				
				,RepairTimeT				
				,FalseStarts0				
				,FalseStarts0Per			
				,FalseStartsT				
				,FalseStartsTPer			
				,Survival240Rate			
				,Survival240RatePer			
				,EditedStops				
				,EditedStopsPer				
				,TotalUpdStopDay			
				,StopsBDSDay				
				,TotalPlannedStops			
				,TotalPlannedStopsDay		
				,MajorStopsDay				
				,MinorStopsDay				
				,TotalStarvedStops			
				,TotalBlockedStops			
				,TotalStarvedDowntime		
				,TotalBlockedDowntime		
				,VSScheduledTime			
				,VSPRLossPlanned			
				,VSPRLossUnplanned			
				,VSPRLossBreakdown			
				,Survival210Rate			
				,Survival210RatePer			
				,R210						
				,R240						
				,Availability_Planned_DT	
				,TotalPlannedDowntime		
				,PlannedDTPRLoss
				,Area4LossPer
				,ConvertedCases
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap				
				,StatUnits	
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay						
				,StatCases			
				,TargetRateAdj
				,PR_Excl_PRInDev	
				,NetProductionExcDev
				,ScheduleTimeExcDev	
				,MSUExcDev
				,ProjConstructPerc
				,STNUSchedVarPerc			
				,StatFactor)				

			SELECT DISTINCT
				 e.PUId	
				,e.PUDesc
				,ISNULL(fp.TeamDesc,0)
				,e.StartTime
				,fp.LineStatus					
				,e.EndTime						
				,ISNULL(fp.GoodProduct,0)
				,ISNULL(fp.TotalProduct,0)
				,ISNULL(fp.TotalScrap,0)
				,ISNULL(fp.ActualRate,0)
				,ISNULL(fp.TargetRate,0)
				,ISNULL(fp.ScheduleTime,0)
				,ISNULL(fp.PR,0)
				,ISNULL(fp.ScrapPer,0)
				,ISNULL(fp.IdealRate,0)
				,ISNULL(fp.STNU,0)
				,ISNULL(fp.CapacityUtilization,0)
				,ISNULL(fp.ScheduleUtilization,0)
				,ISNULL(fp.Availability,0)
				,ISNULL(fp.PRAvailability,0)
				,ISNULL(fp.StopsMSU,0)
				,ISNULL(fp.DownMSU,0)
				,ISNULL(fp.RunningScrapPer,0)
				,ISNULL(fp.RunningScrap,0)
				,ISNULL(fp.StartingScrapPer,0)
				,ISNULL(fp.StartingScrap,0)
				,ISNULL(fp.RoomLoss,0)
				,ISNULL(fp.MSU,0)
				,ISNULL(fp.TotalCases,0)
				,ISNULL(fp.RateUtilization,0)
				,ISNULL(fp.RunEff,0)
				--,ISNULL(fp.SafetyTrigg,0)
				--,ISNULL(fp.QualityTrigg,0)
				,ISNULL(fp.VSNetProduction,0)
				,ISNULL(fp.VSPR,0)
				,ISNULL(fp.VSPRLossPer,0)--
				,ISNULL(fp.PRRateLoss,0)
				,ISNULL(fd.TotalStops,0)
				,ISNULL(fd.Duration,0)
				,ISNULL(fd.TotalUpdDowntime,0)
				,ISNULL(fd.TotalUpdStops,0)
				,ISNULL(fd.MinorStops,0)
				,ISNULL(fd.ProcFailures,0)
				,ISNULL(fd.MajorStops,0)
				,ISNULL(fd.Uptime,0)
				,ISNULL(fd.MTBF,0)
				,ISNULL(fd.MTBFUpd,0)
				,ISNULL(fd.MTTR,0)
				,ISNULL(fd.UpsDTPRLoss,0)
				,ISNULL(fd.R0,0)
				,ISNULL(fd.R2,0)
				,ISNULL(fd.BreakDown,0)
				,ISNULL(fd.MTTRUpd,0)
				,ISNULL(fd.UpdDownPerc,0)
				,ISNULL(fd.StopsDay,0)
				,ISNULL(fd.ProcFailuresDay,0)
				,ISNULL(fd.Availability_Unpl_DT,0)
				,ISNULL(fd.Availability_Total_DT,0)
				,ISNULL(fd.MTBS,0)
				,ISNULL(fd.ACPStops,0)
				,ISNULL(fd.ACPStopsDay,0)
				,ISNULL(fd.RepairTimeT,0)
				,ISNULL(fd.FalseStarts0,0)
				,ISNULL(fd.FalseStarts0Per,0)
				,ISNULL(fd.FalseStartsT,0)
				,ISNULL(fd.FalseStartsTPer,0)
				,ISNULL(fd.Survival240Rate,0)
				,ISNULL(fd.Survival240RatePer,0)
				,ISNULL(fd.EditedStops,0)
				,ISNULL(fd.EditedStopsPer,0)
				,ISNULL(fd.TotalUpdStopDay,0)
				,ISNULL(fd.StopsBDSDay,0)
				,ISNULL(fd.TotalPlannedStops,0)
				,ISNULL(fd.TotalPlannedStopsDay,0)
				,ISNULL(fd.MajorStopsDay,0)
				,ISNULL(fd.MinorStopsDay,0)
				,ISNULL(fd.TotalStarvedStops,0)
				,ISNULL(fd.TotalBlockedStops,0)
				,ISNULL(fd.TotalStarvedDowntime,0)
				,ISNULL(fd.TotalBlockedDowntime,0)
				,ISNULL(fd.VSScheduledTime,0)
				,ISNULL(fd.VSPRLossPlanned,0)
				,ISNULL(fd.VSPRLossUnplanned,0)
				,ISNULL(fd.VSPRLossBreakdown,0)
				,ISNULL(fd.Survival210Rate,0)
				,ISNULL(fd.Survival210RatePer,0)
				,ISNULL(fd.R210,0)
				,ISNULL(fd.R240,0)
				,ISNULL(fd.Availability_Planned_DT,0)
				,ISNULL(fd.TotalPlannedDowntime,0)
				,ISNULL(fd.PlannedDTPRLoss,0)
				,ISNULL(fp.Area4LossPer,0)
				,0 --,ISNULL(fp.ConvertedCases,0)
				,ISNULL(fp.BrandProjectPer,0)		
				,ISNULL(fp.EO_NonShippablePer,0)		
				,ISNULL(fp.LineNotStaffedPer,0)		
				,ISNULL(fp.STNUPer,0)
				,ISNULL(fp.PRLossScrap,0)	
				,ISNULL(fp.StatUnits,0)	 
				,ISNULL(fd.IdleTime,0)					
				,ISNULL(fd.ExcludedTime,0)				
				,ISNULL(fd.MAchineStopsDay,0)				
				,ISNULL(fp.StatCases,0)		
				,ISNULL(fp.TargetRateAdj,0)
				,ISNULL(fp.PR_Excl_PRInDev,0)
				,ISNULL(fp.NetProductionExcDev,0)
				,ISNULL(fp.ScheduleTimeExcDev,0)	
				,ISNULL(fp.MSUExcDev,0)
				,ISNULL(fp.ProjConstructPerc,0)
				,ISNULL(fp.STNUSchedVarPerc,0)	
				,ISNULL(fp.StatFactor,0)
			FROM @Equipment e 
			JOIN dbo.Workcell_Dimension wd (NOLOCK) ON e.PUId = wd.PUId
			LEFT JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.Workcell_Dimension_WorkcellId = wd.WorkcellId
														AND fp.LineStatus = @strNPT		
														AND fp.Date_Dimension_DateId = @intTimeOption		
														AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,e.StartTime)
														AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,e.EndTime)
														AND fp.ShiftDesc = 'All'		
														AND fp.TeamDesc = 'All'
			LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.Workcell_Dimension_WorkcellId = wd.WorkcellId
														AND fd.LineStatus = @strNPT
														AND fd.Date_Dimension_DateId = @intTimeOption
														AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,e.StartTime)
														AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,e.EndTime)
														AND fd.ShiftDesc = 'All'
														AND fd.TeamDesc = 'All'

			--SELECT '@MajorGroup',* FROM @MajorGroup
		END
		ELSE
		BEGIN
			--Delete tables before reuse.
			DELETE #UserDefinedProduction
			DELETE #UserDefinedDowntime
			DELETE #UserDefinedFlexVariables
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Unit'
														, 0
		
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Unit'
		
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime


			--Insert values to minor group table
			INSERT INTO @MajorGroup(
				 MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime					
				,GoodProduct				
				,TotalProduct				
				,TotalScrap					
				,ActualRate					
				,TargetRate					
				,ScheduleTime				
				,PR							
				,ScrapPer					
				,IdealRate					
				,STNU						
				,CapacityUtilization		
				,ScheduleUtilization		
				,Availability				
				,PRAvailability				
				,StopsMSU					
				,DownMSU					
				,RunningScrapPer			
				,RunningScrap				
				,StartingScrapPer			
				,StartingScrap				
				,RoomLoss					
				,MSU						
				,TotalCases					
				,RateUtilization			
				,RunEff						
				--,SafetyTrigg				
				--,QualityTrigg				
				,VSNetProduction			
				,VSPR						
				,VSPRLossPer	
				,PercentPRRateLoss				
				,TotalStops					
				,Duration					
				,TotalUpdDowntime			
				,TotalUpdStops				
				,MinorStops					
				,ProcFailures				
				,MajorStops					
				,Uptime						
				,MTBF						
				,MTBFUpd					
				,MTTR						
				,UpsDTPRLoss				
				,R0							
				,R2							
				,BreakDown					
				,MTTRUpd					
				,UpdDownPerc				
				,StopsDay					
				,ProcFailuresDay			
				,Availability_Unpl_DT		
				,Availability_Total_DT		
				,MTBS						
				,ACPStops					
				,ACPStopsDay				
				,RepairTimeT				
				,FalseStarts0				
				,FalseStarts0Per			
				,FalseStartsT				
				,FalseStartsTPer			
				,Survival240Rate			
				,Survival240RatePer			
				,EditedStops				
				,EditedStopsPer				
				,TotalUpdStopDay			
				,StopsBDSDay				
				,TotalPlannedStops			
				,TotalPlannedStopsDay		
				,MajorStopsDay				
				,MinorStopsDay				
				,TotalStarvedStops			
				,TotalBlockedStops			
				,TotalStarvedDowntime		
				,TotalBlockedDowntime		
				,VSScheduledTime			
				,VSPRLossPlanned			
				,VSPRLossUnplanned			
				,VSPRLossBreakdown			
				,Survival210Rate			
				,Survival210RatePer			
				,R210						
				,R240						
				,Availability_Planned_DT	
				,TotalPlannedDowntime		
				,PlannedDTPRLoss
				,Area4LossPer
				,ConvertedCases
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap						
				,StatUnits							
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay			
				,StatCases		
				,TargetRateAdj
				,PR_Excl_PRInDev	
				,NetProductionExcDev
				,ScheduleTimeExcDev	
				,MSUExcDev
				,ProjConstructPerc
				,STNUSchedVarPerc			
				,StatFactor)				

			SELECT DISTINCT
					 e.PUId	
					,e.PUDesc
					,ISNULL(udp.TeamDesc,0)
					,e.StartTime
					,udp.Status					
					,e.EndTime						
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,ISNULL(udp.Area4LossPer,0)
					,ISNULL(udp.ConvertedCases,0)
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)	
					,ISNULL(udp.PRLossScrap,0)
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)		
					,ISNULL(udp.StatFactor,0)
			FROM @Equipment e 
			JOIN dbo.LINE_DIMENSION l (NOLOCK) ON e.PLId = l.PLId
			JOIN dbo.Workcell_Dimension wd (NOLOCK) ON e.PUId = wd.PUId
			LEFT JOIN #UserDefinedProduction udp ON udp.WorkCellId = wd.WorkCellId
			LEFT JOIN #UserDefinedDowntime udd ON udd.WorkCellId = wd.WorkCellId
		END
END

--=====================================================================================================================
-- Major Group: Line
-----------------------------------------------------------------------------------------------------------------------
IF @strMajorGroupBy = 'Line'
BEGIN
	IF @strMinorGroupBy = 'ProdDay'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer
					,PercentPRRateLoss					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap							
					,StatUnits	
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay						
					,StatCases			
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

				SELECT DISTINCT
					 pd.ProdDayId	
					,CONVERT(DATE,pd.ProdDay)
					,pd.PLId
					,pd.PLDesc
					,ISNULL(fp.TeamDesc,0)
					,pd.StartTime
					,fp.LineStatus					
					,pd.EndTime						
					,ISNULL(fp.GoodProduct,0)
					,ISNULL(fp.TotalProduct,0)
					,ISNULL(fp.TotalScrap,0)
					,ISNULL(fp.ActualRate,0)
					,ISNULL(fp.TargetRate,0)
					,ISNULL(fp.ScheduleTime,0)
					,ISNULL(fp.PR,0)
					,ISNULL(fp.ScrapPer,0)
					,ISNULL(fp.IdealRate,0)
					,ISNULL(fp.STNU,0)
					,ISNULL(fp.CapacityUtilization,0)
					,ISNULL(fp.ScheduleUtilization,0)
					,ISNULL(fp.Availability,0)
					,ISNULL(fp.PRAvailability,0)
					,ISNULL(fp.StopsMSU,0)
					,ISNULL(fp.DownMSU,0)
					,ISNULL(fp.RunningScrapPer,0)
					,ISNULL(fp.RunningScrap,0)
					,ISNULL(fp.StartingScrapPer,0)
					,ISNULL(fp.StartingScrap,0)
					,ISNULL(fp.RoomLoss,0)
					,ISNULL(fp.MSU,0)
					,ISNULL(fp.TotalCases,0)
					,ISNULL(fp.RateUtilization,0)
					,ISNULL(fp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(fp.VSNetProduction,0)
					,ISNULL(fp.VSPR,0)
					,ISNULL(fp.VSPRLossPer,0)--
					,ISNULL(fp.PRRateLoss,0)
					,ISNULL(fd.TotalStops,0)
					,ISNULL(fd.Duration,0)
					,ISNULL(fd.TotalUpdDowntime,0)
					,ISNULL(fd.TotalUpdStops,0)
					,ISNULL(fd.MinorStops,0)
					,ISNULL(fd.ProcFailures,0)
					,ISNULL(fd.MajorStops,0)
					,ISNULL(fd.Uptime,0)
					,ISNULL(fd.MTBF,0)
					,ISNULL(fd.MTBFUpd,0)
					,ISNULL(fd.MTTR,0)
					,ISNULL(fd.UpsDTPRLoss,0)
					,ISNULL(fd.R0,0)
					,ISNULL(fd.R2,0)
					,ISNULL(fd.BreakDown,0)
					,ISNULL(fd.MTTRUpd,0)
					,ISNULL(fd.UpdDownPerc,0)
					,ISNULL(fd.StopsDay,0)
					,ISNULL(fd.ProcFailuresDay,0)
					,ISNULL(fd.Availability_Unpl_DT,0)
					,ISNULL(fd.Availability_Total_DT,0)
					,ISNULL(fd.MTBS,0)
					,ISNULL(fd.ACPStops,0)
					,ISNULL(fd.ACPStopsDay,0)
					,ISNULL(fd.RepairTimeT,0)
					,ISNULL(fd.FalseStarts0,0)
					,ISNULL(fd.FalseStarts0Per,0)
					,ISNULL(fd.FalseStartsT,0)
					,ISNULL(fd.FalseStartsTPer,0)
					,ISNULL(fd.Survival240Rate,0)
					,ISNULL(fd.Survival240RatePer,0)
					,ISNULL(fd.EditedStops,0)
					,ISNULL(fd.EditedStopsPer,0)
					,ISNULL(fd.TotalUpdStopDay,0)
					,ISNULL(fd.StopsBDSDay,0)
					,ISNULL(fd.TotalPlannedStops,0)
					,ISNULL(fd.TotalPlannedStopsDay,0)
					,ISNULL(fd.MajorStopsDay,0)
					,ISNULL(fd.MinorStopsDay,0)
					,ISNULL(fd.TotalStarvedStops,0)
					,ISNULL(fd.TotalBlockedStops,0)
					,ISNULL(fd.TotalStarvedDowntime,0)
					,ISNULL(fd.TotalBlockedDowntime,0)
					,ISNULL(fd.VSScheduledTime,0)
					,ISNULL(fd.VSPRLossPlanned,0)
					,ISNULL(fd.VSPRLossUnplanned,0)
					,ISNULL(fd.VSPRLossBreakdown,0)
					,ISNULL(fd.Survival210Rate,0)
					,ISNULL(fd.Survival210RatePer,0)
					,ISNULL(fd.R210,0)
					,ISNULL(fd.R240,0)
					,ISNULL(fd.Availability_Planned_DT,0)
					,ISNULL(fd.TotalPlannedDowntime,0)
					,ISNULL(fd.PlannedDTPRLoss,0)
					,ISNULL(fp.Area4LossPer,0)
					,ISNULL(fp.ConvertedCases,0) 
					,ISNULL(fp.BrandProjectPer,0)		
					,ISNULL(fp.EO_NonShippablePer,0)		
					,ISNULL(fp.LineNotStaffedPer,0)		
					,ISNULL(fp.STNUPer,0)	
					,ISNULL(fp.PRLossScrap,0)	
					,ISNULL(fp.StatUnits,0)		
					,ISNULL(fd.IdleTime,0)					
					,ISNULL(fd.ExcludedTime,0)				
					,ISNULL(fd.MAchineStopsDay,0)				
					,ISNULL(fp.StatCases,0)		
					,ISNULL(fp.TargetRateAdj,0)
					,ISNULL(fp.PR_Excl_PRInDev,0)
					,ISNULL(fp.NetProductionExcDev,0)
					,ISNULL(fp.ScheduleTimeExcDev,0)	
					,ISNULL(fp.MSUExcDev,0)
					,ISNULL(fp.ProjConstructPerc,0)
					,ISNULL(fp.STNUSchedVarPerc,0)	
					,ISNULL(fp.StatFactor,0)
				FROM @ProdDay pd 
				JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON pd.PLId = ld.PLId
				LEFT JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
														AND fp.LineStatus = @strNPT		
														AND fp.Date_Dimension_DateId = 2		
														AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,pd.StartTime)
														AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,pd.EndTime)
														AND fp.ShiftDesc = 'All'		
														AND fp.TeamDesc = 'All'
														AND fp.Workcell_Dimension_WorkcellId = 0
				LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.LINE_DIMENSION_LineId = ld.LineId
														AND fd.LineStatus = @strNPT
														AND fd.Date_Dimension_DateId = 2
														AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,pd.StartTime)
														AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,pd.EndTime)
														AND fd.ShiftDesc = 'All'
														AND fd.TeamDesc = 'All'
														AND fd.Workcell_Dimension_WorkcellId = 0

				--SELECT '@MinorGroup',* from @MinorGroup
				INSERT INTO #MinorFlexVars(
						 MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy
						,TeamDesc						
						,StartTime					
						,LineStatus					
						,EndTime		)	
				SELECT   MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy
						,TeamDesc						
						,StartTime					
						,LineStatus					
						,EndTime	
				FROM @MinorGroup

				--SELECT '#MinorFlexVars1',* from #MinorFlexVars

				SET @Query = ''

				SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
					' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(fv.Result,0) ' + CHAR(13) +
					' FROM [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd  ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON kd.KPI_Desc = fu.VarDesc ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_PRODUCTION_Flexible_Variables] fv (NOLOCK) ON fu.Idx = fv.FACT_UDPs_Idx ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  fv.Line_Dimension_LineId = l.LineId ' + CHAR(13) +
					'	WHERE kd.Fact like ''%Flexible_Variables%'' ' + CHAR(13) +
					'	AND kd.KPI_Desc  = ''' + c.name + '''' + CHAR(13) +
					'	AND fu.ExpirationDate IS NULL ' + CHAR(13) +
					'	AND fv.LineStatus = ''' + @strNPT + ''' ' + CHAR(13) +
					'	AND fv.TeamDesc = ''All'' ' + CHAR(13) +
					'	AND fv.ShiftDesc = ''All'' ' + CHAR(13) +
					'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
					'	AND fv.Date_Dimension_DateId = 2 ' + CHAR(13) +
					'	AND fv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
					'	AND fv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
				from tempdb.sys.columns c
				where object_id = object_id('tempdb..#MinorFlexVars')
				AND	c.name NOT LIKE 'Idx'
				AND	c.name NOT LIKE 'MinorGroupId'
				AND	c.name NOT LIKE 'MinorGroupBy'
				AND	c.name NOT LIKE 'MajorGroupId'
				AND	c.name NOT LIKE 'MajorGroupBy'
				AND	c.name NOT LIKE 'TeamDesc'		
				AND	c.name NOT LIKE 'StartTime'	
				AND	c.name NOT LIKE 'LineStatus'	
				AND	c.name NOT LIKE 'EndTime'

				EXEC (@Query)

		END
		ELSE
		BEGIN
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Day'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction
			
			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Day'
			
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime

			--inser values from custom aggregates
			--Production AGG for Flexible Variables
			INSERT INTO #UserDefinedFlexVariables
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Day'
														, 1
			--SELECT '#UserDefinedFlexVariables',* FROM #UserDefinedFlexVariables
			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					----,SafetyTrigg				
					----,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer
					,PercentPRRateLoss					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap						
					,StatUnits							
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

				SELECT 
					 pd.ProdDayId	
					,CONVERT(DATE,pd.ProdDay)
					,pd.PLId
					,pd.PLDesc
					,ISNULL(udp.TeamDesc,0)
					,pd.StartTime
					,udp.Status					
					,pd.EndTime						
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(udp.SafetyTrigg,0)
					--,ISNULL(udp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,ISNULL(udp.Area4LossPer,0)
					,ISNULL(udp.ConvertedCases,0) 
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)
					,ISNULL(udp.PRLossScrap,0)	
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)
					,ISNULL(udp.StatFactor,0)
				FROM @ProdDay pd 
				JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON pd.PLId = l.PLId
				LEFT JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
											   AND udp.Starttime = pd.StartTime
											   AND udp.Endtime = pd.EndTime
				LEFT JOIN #UserDefinedDowntime udd ON udd.LineId = l.LineId
											   AND udd.Starttime = pd.StartTime
											   AND udd.Endtime = pd.EndTime
			
			--SELECT '@MinorGroup',* from @MinorGroup

			INSERT INTO #MinorFlexVars(
						 MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy			
						,StartTime					
						,LineStatus					
						,EndTime		)	
				SELECT   pd.ProdDayId	
						,CONVERT(DATE,pd.ProdDay)
						,pd.PLId
						,pd.PLDesc			
						,pd.StartTime		
						,@strNPT							
						,pd.EndTime					
				FROM @ProdDay pd 
				JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON pd.PLId = l.PLId

				SET @Query = ''

				SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
					' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(udfv.Result,0) ' + CHAR(13) +
					' FROM #UserDefinedFlexVariables udfv  ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON udfv.FACT_UDPs_Idx = fu.Idx ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  udfv.LineId = l.LineId ' + CHAR(13) +
					'	WHERE fu.VarDesc  = ''' + c.name + '''' + CHAR(13) +
					'   AND ((fu.ExpirationDate IS NOT NULL ' + CHAR(13) + ' AND fu.EffectiveDate >= udfv.StartTime'  + CHAR(13) + ' AND fu.ExpirationDate <= udfv.StartTime'  + CHAR(13) + ') OR (fu.ExpirationDate IS NULL ' + CHAR(13) + '))' +
					'	AND udfv.Status = #MinorFlexVars.LineStatus ' + CHAR(13) +
					'	AND udfv.TeamDesc = ''All'' ' + CHAR(13) +
					'	AND udfv.ShiftDesc = ''All'' ' + CHAR(13) +
					'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
					'	AND udfv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
					'	AND udfv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
				from tempdb.sys.columns c
				where object_id = object_id('tempdb..#MinorFlexVars')
				AND	c.name NOT LIKE 'Idx'
				AND	c.name NOT LIKE 'MinorGroupId'
				AND	c.name NOT LIKE 'MinorGroupBy'
				AND	c.name NOT LIKE 'MajorGroupId'
				AND	c.name NOT LIKE 'MajorGroupBy'
				AND	c.name NOT LIKE 'TeamDesc'		
				AND	c.name NOT LIKE 'StartTime'	
				AND	c.name NOT LIKE 'LineStatus'	
				AND	c.name NOT LIKE 'EndTime'

				EXEC (@Query)
		END
	END
	
	IF @strMinorGroupBy = 'Shift'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
				 MinorGroupId
				,MinorGroupBy
				,MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime					
				,GoodProduct				
				,TotalProduct				
				,TotalScrap					
				,ActualRate					
				,TargetRate					
				,ScheduleTime				
				,PR							
				,ScrapPer					
				,IdealRate					
				,STNU						
				,CapacityUtilization		
				,ScheduleUtilization		
				,Availability				
				,PRAvailability				
				,StopsMSU					
				,DownMSU					
				,RunningScrapPer			
				,RunningScrap				
				,StartingScrapPer			
				,StartingScrap				
				,RoomLoss					
				,MSU						
				,TotalCases					
				,RateUtilization			
				,RunEff						
				--,SafetyTrigg				
				--,QualityTrigg				
				,VSNetProduction			
				,VSPR						
				,VSPRLossPer	
				,PercentPRRateLoss				
				,TotalStops					
				,Duration					
				,TotalUpdDowntime			
				,TotalUpdStops				
				,MinorStops					
				,ProcFailures				
				,MajorStops					
				,Uptime						
				,MTBF						
				,MTBFUpd					
				,MTTR						
				,UpsDTPRLoss				
				,R0							
				,R2							
				,BreakDown					
				,MTTRUpd					
				,UpdDownPerc				
				,StopsDay					
				,ProcFailuresDay			
				,Availability_Unpl_DT		
				,Availability_Total_DT		
				,MTBS						
				,ACPStops					
				,ACPStopsDay				
				,RepairTimeT				
				,FalseStarts0				
				,FalseStarts0Per			
				,FalseStartsT				
				,FalseStartsTPer			
				,Survival240Rate			
				,Survival240RatePer			
				,EditedStops				
				,EditedStopsPer				
				,TotalUpdStopDay			
				,StopsBDSDay				
				,TotalPlannedStops			
				,TotalPlannedStopsDay		
				,MajorStopsDay				
				,MinorStopsDay				
				,TotalStarvedStops			
				,TotalBlockedStops			
				,TotalStarvedDowntime		
				,TotalBlockedDowntime		
				,VSScheduledTime			
				,VSPRLossPlanned			
				,VSPRLossUnplanned			
				,VSPRLossBreakdown			
				,Survival210Rate			
				,Survival210RatePer			
				,R210						
				,R240						
				,Availability_Planned_DT	
				,TotalPlannedDowntime		
				,PlannedDTPRLoss
				,CalendarTime
				,Area4LossPer
				,ConvertedCases
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap								
				,StatUnits	
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay						
				,StatCases			
				,TargetRateAdj
				,PR_Excl_PRInDev	
				,NetProductionExcDev
				,ScheduleTimeExcDev	
				,MSUExcDev
				,ProjConstructPerc
				,STNUSchedVarPerc			
				,StatFactor)			

			SELECT DISTINCT
				 ts.RcdIdx
				,fp.ShiftDesc
				,ts.PLId
				,ts.PLDesc
				,ISNULL(fp.TeamDesc,'')
				,ts.StartTime
				,fp.LineStatus					
				,ts.EndTime						
				,ISNULL(fp.GoodProduct,0)
				,ISNULL(fp.TotalProduct,0)
				,ISNULL(fp.TotalScrap,0)
				,ISNULL(fp.ActualRate,0)
				,ISNULL(fp.TargetRate,0)
				,ISNULL(fp.ScheduleTime,0)
				,ISNULL(fp.PR,0)
				,ISNULL(fp.ScrapPer,0)
				,ISNULL(fp.IdealRate,0)
				,ISNULL(fp.STNU,0)
				,ISNULL(fp.CapacityUtilization,0)
				,ISNULL(fp.ScheduleUtilization,0)
				,ISNULL(fp.Availability,0)
				,ISNULL(fp.PRAvailability,0)
				,ISNULL(fp.StopsMSU,0)
				,ISNULL(fp.DownMSU,0)
				,ISNULL(fp.RunningScrapPer,0)
				,ISNULL(fp.RunningScrap,0)
				,ISNULL(fp.StartingScrapPer,0)
				,ISNULL(fp.StartingScrap,0)
				,ISNULL(fp.RoomLoss,0)
				,ISNULL(fp.MSU,0)
				,ISNULL(fp.TotalCases,0)
				,ISNULL(fp.RateUtilization,0)
				,ISNULL(fp.RunEff,0)
				--,ISNULL(fp.SafetyTrigg,0)
				--,ISNULL(fp.QualityTrigg,0)
				,ISNULL(fp.VSNetProduction,0)
				,ISNULL(fp.VSPR,0)
				,ISNULL(fp.VSPRLossPer,0)--
				,ISNULL(fp.PRRateLoss,0)
				,ISNULL(fd.TotalStops,0)
				,ISNULL(fd.Duration,0)
				,ISNULL(fd.TotalUpdDowntime,0)
				,ISNULL(fd.TotalUpdStops,0)
				,ISNULL(fd.MinorStops,0)
				,ISNULL(fd.ProcFailures,0)
				,ISNULL(fd.MajorStops,0)
				,ISNULL(fd.Uptime,0)
				,ISNULL(fd.MTBF,0)
				,ISNULL(fd.MTBFUpd,0)
				,ISNULL(fd.MTTR,0)
				,ISNULL(fd.UpsDTPRLoss,0)
				,ISNULL(fd.R0,0)
				,ISNULL(fd.R2,0)
				,ISNULL(fd.BreakDown,0)
				,ISNULL(fd.MTTRUpd,0)
				,ISNULL(fd.UpdDownPerc,0)
				,ISNULL(fd.StopsDay,0)
				,ISNULL(fd.ProcFailuresDay,0)
				,ISNULL(fd.Availability_Unpl_DT,0)
				,ISNULL(fd.Availability_Total_DT,0)
				,ISNULL(fd.MTBS,0)
				,ISNULL(fd.ACPStops,0)
				,ISNULL(fd.ACPStopsDay,0)
				,ISNULL(fd.RepairTimeT,0)
				,ISNULL(fd.FalseStarts0,0)
				,ISNULL(fd.FalseStarts0Per,0)
				,ISNULL(fd.FalseStartsT,0)
				,ISNULL(fd.FalseStartsTPer,0)
				,ISNULL(fd.Survival240Rate,0)
				,ISNULL(fd.Survival240RatePer,0)
				,ISNULL(fd.EditedStops,0)
				,ISNULL(fd.EditedStopsPer,0)
				,ISNULL(fd.TotalUpdStopDay,0)
				,ISNULL(fd.StopsBDSDay,0)
				,ISNULL(fd.TotalPlannedStops,0)
				,ISNULL(fd.TotalPlannedStopsDay,0)
				,ISNULL(fd.MajorStopsDay,0)
				,ISNULL(fd.MinorStopsDay,0)
				,ISNULL(fd.TotalStarvedStops,0)
				,ISNULL(fd.TotalBlockedStops,0)
				,ISNULL(fd.TotalStarvedDowntime,0)
				,ISNULL(fd.TotalBlockedDowntime,0)
				,ISNULL(fd.VSScheduledTime,0)
				,ISNULL(fd.VSPRLossPlanned,0)
				,ISNULL(fd.VSPRLossUnplanned,0)
				,ISNULL(fd.VSPRLossBreakdown,0)
				,ISNULL(fd.Survival210Rate,0)
				,ISNULL(fd.Survival210RatePer,0)
				,ISNULL(fd.R210,0)
				,ISNULL(fd.R240,0)
				,ISNULL(fd.Availability_Planned_DT,0)
				,ISNULL(fd.TotalPlannedDowntime,0)
				,ISNULL(fd.PlannedDTPRLoss,0)
				,DATEDIFF(second,ts.StartTime,ts.EndTime)
				,ISNULL(fp.Area4LossPer,0)
				,ISNULL(fp.ConvertedCases,0) 
				,ISNULL(fp.BrandProjectPer,0)		
				,ISNULL(fp.EO_NonShippablePer,0)		
				,ISNULL(fp.LineNotStaffedPer,0)		
				,ISNULL(fp.STNUPer,0)	
				,ISNULL(fp.PRLossScrap,0)	
				,ISNULL(fp.StatUnits,0)
				,ISNULL(fd.IdleTime,0)					
				,ISNULL(fd.ExcludedTime,0)				
				,ISNULL(fd.MAchineStopsDay,0)				
				,ISNULL(fp.StatCases,0)		
				,ISNULL(fp.TargetRateAdj,0)
				,ISNULL(fp.PR_Excl_PRInDev,0)
				,ISNULL(fp.NetProductionExcDev,0)
				,ISNULL(fp.ScheduleTimeExcDev,0)	
				,ISNULL(fp.MSUExcDev,0)
				,ISNULL(fp.ProjConstructPerc,0)
				,ISNULL(fp.STNUSchedVarPerc,0)	
				,ISNULL(fp.StatFactor,0)
			FROM @TeamShift ts 
			JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON ts.PLId = ld.PLId
			JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
													AND fp.LineStatus = @strNPT		
													AND fp.Date_Dimension_DateId = @intTimeOption		
													AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,ts.StartTime)
													AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,ts.EndTime)
													AND fp.ShiftDesc = ts.ShiftDesc
													AND fp.TeamDesc = 'All'
													AND fp.Workcell_Dimension_WorkcellId = 0
			LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.LINE_DIMENSION_LineId = ld.LineId
													AND fd.LineStatus = @strNPT
													AND fd.Date_Dimension_DateId = @intTimeOption
													AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,ts.StartTime)
													AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,ts.EndTime)
													AND fd.ShiftDesc = ts.ShiftDesc
													AND fd.TeamDesc = 'All'
													AND fd.Workcell_Dimension_WorkcellId = 0
			--SELECT '@MinorGroup',* from @MinorGroup
			INSERT INTO #MinorFlexVars(
						 MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy
						,TeamDesc						
						,StartTime					
						,LineStatus					
						,EndTime		)	
				SELECT   MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy
						,TeamDesc						
						,StartTime					
						,LineStatus					
						,EndTime	
				FROM @MinorGroup

				SET @Query = ''

				SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
					' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(fv.Result,0) ' + CHAR(13) +
					' FROM [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd  ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON kd.KPI_Desc = fu.VarDesc ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_PRODUCTION_Flexible_Variables] fv (NOLOCK) ON fu.Idx = fv.FACT_UDPs_Idx ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  fv.Line_Dimension_LineId = l.LineId ' + CHAR(13) +
					'	WHERE kd.Fact like ''%Flexible_Variables%'' ' + CHAR(13) +
					'	AND kd.KPI_Desc  = ''' + c.name + '''' + CHAR(13) +
					'	AND fu.ExpirationDate IS NULL ' + CHAR(13) +
					'	AND fv.LineStatus = ''' + @strNPT + ''' ' + CHAR(13) +
					'	AND fv.TeamDesc = ''All'' ' + CHAR(13) +
					'	AND fv.ShiftDesc = #MinorFlexVars.MinorGroupBy ' + CHAR(13) +
					'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
					'	AND fv.Date_Dimension_DateId =  ''' + CAST(@intTimeOption AS NVARCHAR(10)) + ''' ' + CHAR(13) +
					'	AND fv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
					'	AND fv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
				from tempdb.sys.columns c
				where object_id = object_id('tempdb..#MinorFlexVars')
				AND	c.name NOT LIKE 'Idx'
				AND	c.name NOT LIKE 'MinorGroupId'
				AND	c.name NOT LIKE 'MinorGroupBy'
				AND	c.name NOT LIKE 'MajorGroupId'
				AND	c.name NOT LIKE 'MajorGroupBy'
				AND	c.name NOT LIKE 'TeamDesc'		
				AND	c.name NOT LIKE 'StartTime'	
				AND	c.name NOT LIKE 'LineStatus'	
				AND	c.name NOT LIKE 'EndTime'

				EXEC (@Query)		
				--SELECT '#MinorFlexVars1',* from #MinorFlexVars
		END
		ELSE
		BEGIN
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Shift'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Shift'
			
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime
			--inser values from custom aggregates
			--Production AGG for Flexible Variables
			INSERT INTO #UserDefinedFlexVariables
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Shift'
														, 1

			--SELECT '#UserDefinedFlexVariables',* FROM #UserDefinedFlexVariables

			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					----,SafetyTrigg				
					----,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer
					,PercentPRRateLoss					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap							
					,StatUnits						
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases			
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

				SELECT 
					 ts.RcdIdx
					,udp.ShiftDesc
					,ts.PLId
					,ts.PLDesc
					,ISNULL(udp.TeamDesc,'')
					,ts.StartTime
					,udp.Status					
					,ts.EndTime						
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(udp.Area4LossPer,0)
					,ISNULL(udp.ConvertedCases,0) 
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)	
					,ISNULL(udp.PRLossScrap,0)	
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)
					,ISNULL(udp.StatFactor,0)
				FROM @TeamShift ts 
					JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON ts.PLId = l.PLId
					JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
												   AND udp.ShiftDesc = ts.ShiftDesc
												   AND udp.Starttime = ts.StartTime
												   AND udp.Endtime = ts.EndTime
					LEFT JOIN #UserDefinedDowntime udd ON udd.LineId = l.LineId
												   AND udd.ShiftDesc = ts.ShiftDesc
												   AND udd.Starttime = ts.StartTime
												   AND udd.Endtime = ts.EndTime
			
			--SELECT '@MinorGroup',* from @MinorGroup
			--SELECT '@TeamShift',* from @TeamShift
			INSERT INTO #MinorFlexVars(
						 MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy		
						,TeamDesc					
						,StartTime		
						,LineStatus		
						,EndTime		)	
			SELECT		
						 ts.RcdIdx
						,ts.ShiftDesc
						,ts.PLId
						,ts.PLDesc
						,ts.TeamDesc
						,ts.StartTime
						,@strNPT			
						,ts.EndTime		
			FROM @TeamShift ts 
			JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON ts.PLId = l.PLId

			--select '#MinorFlexVars',* from #MinorFlexVars

			SET @Query = ''

			SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
				' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(udfv.Result,0) ' + CHAR(13) +
				' FROM #UserDefinedFlexVariables udfv  ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON udfv.FACT_UDPs_Idx = fu.Idx ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  udfv.LineId = l.LineId ' + CHAR(13) +
				'	WHERE fu.VarDesc  = ''' + c.name + '''' + CHAR(13) +
				'   AND ((fu.ExpirationDate IS NOT NULL ' + CHAR(13) + ' AND fu.EffectiveDate >= udfv.StartTime'  + CHAR(13) + ' AND fu.ExpirationDate <= udfv.StartTime'  + CHAR(13) + ') OR (fu.ExpirationDate IS NULL ' + CHAR(13) + '))' +
				'	AND udfv.Status = #MinorFlexVars.LineStatus ' + CHAR(13) +
				'	AND udfv.TeamDesc = ''All'' ' + CHAR(13) +
				'	AND udfv.ShiftDesc = #MinorFlexVars.MinorGroupBy ' + CHAR(13) +
				'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
				'	AND udfv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
				'	AND udfv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
			from tempdb.sys.columns c
			where object_id = object_id('tempdb..#MinorFlexVars')
			AND	c.name NOT LIKE 'Idx'
			AND	c.name NOT LIKE 'MinorGroupId'
			AND	c.name NOT LIKE 'MinorGroupBy'
			AND	c.name NOT LIKE 'MajorGroupId'
			AND	c.name NOT LIKE 'MajorGroupBy'
			AND	c.name NOT LIKE 'TeamDesc'		
			AND	c.name NOT LIKE 'StartTime'	
			AND	c.name NOT LIKE 'LineStatus'	
			AND	c.name NOT LIKE 'EndTime'

			EXEC (@Query)
			--select '#MinorFlexVars1',* from #MinorFlexVars
		END
	END

	IF @strMinorGroupBy = 'Team'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap							
					,StatUnits	
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay						
					,StatCases			
					,TargetRateAdj			
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)				

				SELECT DISTINCT
					 ts.RcdIdx
					,fp.TeamDesc
					,ts.PLId
					,ts.PLDesc
					,ISNULL(fp.TeamDesc,'')
					,ts.StartTime
					,fp.LineStatus					
					,ts.EndTime						
					,ISNULL(fp.GoodProduct,0)
					,ISNULL(fp.TotalProduct,0)
					,ISNULL(fp.TotalScrap,0)
					,ISNULL(fp.ActualRate,0)
					,ISNULL(fp.TargetRate,0)
					,ISNULL(fp.ScheduleTime,0)
					,ISNULL(fp.PR,0)
					,ISNULL(fp.ScrapPer,0)
					,ISNULL(fp.IdealRate,0)
					,ISNULL(fp.STNU,0)
					,ISNULL(fp.CapacityUtilization,0)
					,ISNULL(fp.ScheduleUtilization,0)
					,ISNULL(fp.Availability,0)
					,ISNULL(fp.PRAvailability,0)
					,ISNULL(fp.StopsMSU,0)
					,ISNULL(fp.DownMSU,0)
					,ISNULL(fp.RunningScrapPer,0)
					,ISNULL(fp.RunningScrap,0)
					,ISNULL(fp.StartingScrapPer,0)
					,ISNULL(fp.StartingScrap,0)
					,ISNULL(fp.RoomLoss,0)
					,ISNULL(fp.MSU,0)
					,ISNULL(fp.TotalCases,0)
					,ISNULL(fp.RateUtilization,0)
					,ISNULL(fp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(fp.VSNetProduction,0)
					,ISNULL(fp.VSPR,0)
					,ISNULL(fp.VSPRLossPer,0)--
					,ISNULL(fp.PRRateLoss,0)
					,ISNULL(fd.TotalStops,0)
					,ISNULL(fd.Duration,0)
					,ISNULL(fd.TotalUpdDowntime,0)
					,ISNULL(fd.TotalUpdStops,0)
					,ISNULL(fd.MinorStops,0)
					,ISNULL(fd.ProcFailures,0)
					,ISNULL(fd.MajorStops,0)
					,ISNULL(fd.Uptime,0)
					,ISNULL(fd.MTBF,0)
					,ISNULL(fd.MTBFUpd,0)
					,ISNULL(fd.MTTR,0)
					,ISNULL(fd.UpsDTPRLoss,0)
					,ISNULL(fd.R0,0)
					,ISNULL(fd.R2,0)
					,ISNULL(fd.BreakDown,0)
					,ISNULL(fd.MTTRUpd,0)
					,ISNULL(fd.UpdDownPerc,0)
					,ISNULL(fd.StopsDay,0)
					,ISNULL(fd.ProcFailuresDay,0)
					,ISNULL(fd.Availability_Unpl_DT,0)
					,ISNULL(fd.Availability_Total_DT,0)
					,ISNULL(fd.MTBS,0)
					,ISNULL(fd.ACPStops,0)
					,ISNULL(fd.ACPStopsDay,0)
					,ISNULL(fd.RepairTimeT,0)
					,ISNULL(fd.FalseStarts0,0)
					,ISNULL(fd.FalseStarts0Per,0)
					,ISNULL(fd.FalseStartsT,0)
					,ISNULL(fd.FalseStartsTPer,0)
					,ISNULL(fd.Survival240Rate,0)
					,ISNULL(fd.Survival240RatePer,0)
					,ISNULL(fd.EditedStops,0)
					,ISNULL(fd.EditedStopsPer,0)
					,ISNULL(fd.TotalUpdStopDay,0)
					,ISNULL(fd.StopsBDSDay,0)
					,ISNULL(fd.TotalPlannedStops,0)
					,ISNULL(fd.TotalPlannedStopsDay,0)
					,ISNULL(fd.MajorStopsDay,0)
					,ISNULL(fd.MinorStopsDay,0)
					,ISNULL(fd.TotalStarvedStops,0)
					,ISNULL(fd.TotalBlockedStops,0)
					,ISNULL(fd.TotalStarvedDowntime,0)
					,ISNULL(fd.TotalBlockedDowntime,0)
					,ISNULL(fd.VSScheduledTime,0)
					,ISNULL(fd.VSPRLossPlanned,0)
					,ISNULL(fd.VSPRLossUnplanned,0)
					,ISNULL(fd.VSPRLossBreakdown,0)
					,ISNULL(fd.Survival210Rate,0)
					,ISNULL(fd.Survival210RatePer,0)
					,ISNULL(fd.R210,0)
					,ISNULL(fd.R240,0)
					,ISNULL(fd.Availability_Planned_DT,0)
					,ISNULL(fd.TotalPlannedDowntime,0)
					,ISNULL(fd.PlannedDTPRLoss,0)
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(fp.Area4LossPer,0)
					,ISNULL(fp.ConvertedCases,0)
					,ISNULL(fp.BrandProjectPer,0)		
					,ISNULL(fp.EO_NonShippablePer,0)		
					,ISNULL(fp.LineNotStaffedPer,0)		
					,ISNULL(fp.STNUPer,0)		
					,ISNULL(fp.PRLossScrap,0) 
					,ISNULL(fp.StatUnits,0)
					,ISNULL(fd.IdleTime,0)					
					,ISNULL(fd.ExcludedTime,0)				
					,ISNULL(fd.MAchineStopsDay,0)				
					,ISNULL(fp.StatCases,0)	
					,ISNULL(fp.TargetRateAdj,0)
					,ISNULL(fp.PR_Excl_PRInDev,0)
					,ISNULL(fp.NetProductionExcDev,0)
					,ISNULL(fp.ScheduleTimeExcDev,0)	
					,ISNULL(fp.MSUExcDev,0)
					,ISNULL(fp.ProjConstructPerc,0)
					,ISNULL(fp.STNUSchedVarPerc,0)	
					,ISNULL(fp.StatFactor,0)
				FROM @TeamShift ts 
				JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON ts.PLId = ld.PLId
				JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
														AND fp.LineStatus = @strNPT		
														AND fp.Date_Dimension_DateId = @intTimeOption		
														AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,ts.StartTime)
														AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,ts.EndTime)
														AND fp.ShiftDesc = 'All'
														AND fp.TeamDesc = ts.TeamDesc
														AND fp.Workcell_Dimension_WorkcellId = 0
				LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.LINE_DIMENSION_LineId = ld.LineId
														AND fd.LineStatus = @strNPT
														AND fd.Date_Dimension_DateId = @intTimeOption
														AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,ts.StartTime)
														AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,ts.EndTime)
														AND fd.ShiftDesc = 'All'
														AND fd.TeamDesc = ts.TeamDesc
														AND fd.Workcell_Dimension_WorkcellId = 0

			--SELECT '@MinorGroup',* from @MinorGroup
			INSERT INTO #MinorFlexVars(
						 MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy
						,TeamDesc						
						,StartTime					
						,LineStatus					
						,EndTime		)	
				SELECT   MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy
						,TeamDesc						
						,StartTime					
						,LineStatus					
						,EndTime	
				FROM @MinorGroup

				SET @Query = ''

				SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
					' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(fv.Result,0) ' + CHAR(13) +
					' FROM [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd  ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON kd.KPI_Desc = fu.VarDesc ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_PRODUCTION_Flexible_Variables] fv (NOLOCK) ON fu.Idx = fv.FACT_UDPs_Idx ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  fv.Line_Dimension_LineId = l.LineId ' + CHAR(13) +
					'	WHERE kd.Fact like ''%Flexible_Variables%'' ' + CHAR(13) +
					'	AND kd.KPI_Desc  = ''' + c.name + '''' + CHAR(13) +
					'	AND fu.ExpirationDate IS NULL ' + CHAR(13) +
					'	AND fv.LineStatus = ''' + @strNPT + ''' ' + CHAR(13) +
					'	AND fv.TeamDesc = #MinorFlexVars.MinorGroupBy ' + CHAR(13) +
					'	AND fv.ShiftDesc = ''All'' ' + CHAR(13) +
					'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
					'	AND fv.Date_Dimension_DateId =  ''' + CAST(@intTimeOption AS NVARCHAR(10)) + ''' ' + CHAR(13) +
					'	AND fv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
					'	AND fv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
				from tempdb.sys.columns c
				where object_id = object_id('tempdb..#MinorFlexVars')
				AND	c.name NOT LIKE 'Idx'
				AND	c.name NOT LIKE 'MinorGroupId'
				AND	c.name NOT LIKE 'MinorGroupBy'
				AND	c.name NOT LIKE 'MajorGroupId'
				AND	c.name NOT LIKE 'MajorGroupBy'
				AND	c.name NOT LIKE 'TeamDesc'		
				AND	c.name NOT LIKE 'StartTime'	
				AND	c.name NOT LIKE 'LineStatus'	
				AND	c.name NOT LIKE 'EndTime'

				EXEC (@Query)		
		END
		ELSE
		BEGIN
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Team'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Team'
			
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime
			--inser values from custom aggregates
			--Production AGG for Flexible Variables
			INSERT INTO #UserDefinedFlexVariables
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @dtmStartTime
														, @dtmEndTime
														, @strLineId
														, @strWorkcellId
														, @strNPT
														,'All'
														,'All'
														,'Team'
														, 1

			--SELECT '#UserDefinedFlexVariables',* FROM #UserDefinedFlexVariables

			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					----,SafetyTrigg				
					----,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer
					,PercentPRRateLoss					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,CalendarTime
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap				
					,StatUnits							
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,TargetRateAdj			
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

				SELECT 
					 ts.RcdIdx
					,udp.TeamDesc
					,ts.PLId
					,ts.PLDesc
					,ISNULL(udp.TeamDesc,'')
					,ts.StartTime
					,udp.Status					
					,ts.EndTime						
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,DATEDIFF(second,ts.StartTime,ts.EndTime)
					,ISNULL(udp.Area4LossPer,0)
					,ISNULL(udp.ConvertedCases,0) 
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)	
					,ISNULL(udp.PRLossScrap,0)	
					,ISNULL(udp.StatUnits,0)
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)	
					,ISNULL(udp.StatFactor,0)
				FROM @TeamShift ts 
					JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON ts.PLId = l.PLId
					JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
												   AND udp.TeamDesc = ts.TeamDesc
												   AND udp.Starttime = ts.StartTime
												   AND udp.Endtime = ts.EndTime
					LEFT JOIN #UserDefinedDowntime udd ON udd.LineId = l.LineId
												   AND udd.TeamDesc = ts.TeamDesc
												   AND udd.Starttime = ts.StartTime
												   AND udd.Endtime = ts.EndTime
			
			--SELECT '@MinorGroup',* from @MinorGroup
			--SELECT '@TeamShift',* from @TeamShift
			INSERT INTO #MinorFlexVars(
						 MinorGroupId
						,MinorGroupBy
						,MajorGroupId
						,MajorGroupBy		
						,TeamDesc					
						,StartTime		
						,LineStatus		
						,EndTime		)	
			SELECT		
						 ts.RcdIdx
						,ts.TeamDesc
						,ts.PLId
						,ts.PLDesc
						,ts.TeamDesc
						,ts.StartTime
						,@strNPT			
						,ts.EndTime		
			FROM @TeamShift ts 
			JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON ts.PLId = l.PLId

			--select '#MinorFlexVars',* from #MinorFlexVars

			SET @Query = ''

			SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
				' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(udfv.Result,0) ' + CHAR(13) +
				' FROM #UserDefinedFlexVariables udfv  ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON udfv.FACT_UDPs_Idx = fu.Idx ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  udfv.LineId = l.LineId ' + CHAR(13) +
				'	WHERE fu.VarDesc  = ''' + c.name + '''' + CHAR(13) +
				'   AND ((fu.ExpirationDate IS NOT NULL ' + CHAR(13) + ' AND fu.EffectiveDate >= udfv.StartTime'  + CHAR(13) + ' AND fu.ExpirationDate <= udfv.StartTime'  + CHAR(13) + ') OR (fu.ExpirationDate IS NULL ' + CHAR(13) + '))' +
				'	AND udfv.Status = #MinorFlexVars.LineStatus ' + CHAR(13) +
				'	AND udfv.TeamDesc =  #MinorFlexVars.MinorGroupBy ' + CHAR(13) +
				'	AND udfv.ShiftDesc = ''All'' ' + CHAR(13) +
				'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
				'	AND udfv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
				'	AND udfv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
			from tempdb.sys.columns c
			where object_id = object_id('tempdb..#MinorFlexVars')
			AND	c.name NOT LIKE 'Idx'
			AND	c.name NOT LIKE 'MinorGroupId'
			AND	c.name NOT LIKE 'MinorGroupBy'
			AND	c.name NOT LIKE 'MajorGroupId'
			AND	c.name NOT LIKE 'MajorGroupBy'
			AND	c.name NOT LIKE 'TeamDesc'		
			AND	c.name NOT LIKE 'StartTime'	
			AND	c.name NOT LIKE 'LineStatus'	
			AND	c.name NOT LIKE 'EndTime'

			EXEC (@Query)
			--select '#MinorFlexVars1',* from #MinorFlexVars
		END
	END
	IF @strMinorGroupBy = 'Product'
	BEGIN
		--select '@Equipment',* from @Equipment
		--Iterate the equipment table to get the product data for each line
		SELECT @i = COUNT(*) FROM @Equipment
		SET @j = 1
		WHILE @j <= @i
		BEGIN
			SELECT @startTime = StartTime, @endTime = EndTime, @PLIdAux = PLId, @PUIdAux = PUId FROM @Equipment WHERE RcdIdx = @j
			--inser values from custom aggregates
			--Production AGG
			INSERT INTO #UserDefinedProduction
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @startTime
														, @endTime
														, @PLIdAux
														, @PUIdAux
														, @strNPT
														,'All'
														,'All'
														,'Product'
														, 0
			
			--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

			--Downtime AGG
			INSERT INTO #UserDefinedDowntime
			EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
														, @startTime
														, @endTime
														, @PLIdAux
														, ''
														, @strNPT
														,'All'
														,'All'
														,'Product'
		
			--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime

			--inser values from custom aggregates
			--Production AGG for Flexible Variables
			INSERT INTO #UserDefinedFlexVariables
			EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
														, @startTime
														, @endTime
														, @PLIdAux
														, @PUIdAux
														, @strNPT
														,'All'
														,'All'
														,'Product'
														, 1
			--SELECT '#UserDefinedFlexVariables',* FROM #UserDefinedFlexVariables
			SET @j = @j + 1
		END
		--SELECT '#UserDefinedFlexVariables',* FROM #UserDefinedFlexVariables
		--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime
		--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction
		
		----Insert values to minor group table
		INSERT INTO @MinorGroup(
				 MinorGroupId
				,MinorGroupBy
				,MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime					
				,GoodProduct				
				,TotalProduct				
				,TotalScrap					
				,ActualRate					
				,TargetRate					
				,ScheduleTime				
				,PR							
				,ScrapPer					
				,IdealRate					
				,STNU						
				,CapacityUtilization		
				,ScheduleUtilization		
				,Availability				
				,PRAvailability				
				,StopsMSU					
				,DownMSU					
				,RunningScrapPer			
				,RunningScrap				
				,StartingScrapPer			
				,StartingScrap				
				,RoomLoss					
				,MSU						
				,TotalCases					
				,RateUtilization			
				,RunEff						
				----,SafetyTrigg				
				----,QualityTrigg				
				,VSNetProduction			
				,VSPR						
				,VSPRLossPer
				,PercentPRRateLoss					
				,TotalStops					
				,Duration					
				,TotalUpdDowntime			
				,TotalUpdStops				
				,MinorStops					
				,ProcFailures				
				,MajorStops					
				,Uptime						
				,MTBF						
				,MTBFUpd					
				,MTTR						
				,UpsDTPRLoss				
				,R0							
				,R2							
				,BreakDown					
				,MTTRUpd					
				,UpdDownPerc				
				,StopsDay					
				,ProcFailuresDay			
				,Availability_Unpl_DT		
				,Availability_Total_DT		
				,MTBS						
				,ACPStops					
				,ACPStopsDay				
				,RepairTimeT				
				,FalseStarts0				
				,FalseStarts0Per			
				,FalseStartsT				
				,FalseStartsTPer			
				,Survival240Rate			
				,Survival240RatePer			
				,EditedStops				
				,EditedStopsPer				
				,TotalUpdStopDay			
				,StopsBDSDay				
				,TotalPlannedStops			
				,TotalPlannedStopsDay		
				,MajorStopsDay				
				,MinorStopsDay				
				,TotalStarvedStops			
				,TotalBlockedStops			
				,TotalStarvedDowntime		
				,TotalBlockedDowntime		
				,VSScheduledTime			
				,VSPRLossPlanned			
				,VSPRLossUnplanned			
				,VSPRLossBreakdown			
				,Survival210Rate			
				,Survival210RatePer			
				,R210						
				,R240						
				,Availability_Planned_DT	
				,TotalPlannedDowntime		
				,PlannedDTPRLoss
				,Area4LossPer
				,ConvertedCases
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap							
				,StatUnits						
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay			
				,StatCases			
				,TargetRateAdj
				,PR_Excl_PRInDev	
				,NetProductionExcDev
				,ScheduleTimeExcDev	
				,MSUExcDev
				,ProjConstructPerc
				,STNUSchedVarPerc			
				,StatFactor)			

			SELECT DISTINCT
				 udp.ProductCode	
				,udp.ProductCode
				,e.PLId
				,e.PLDesc
				,ISNULL(udp.TeamDesc,'')
				,e.StartTime
				,udp.Status					
				,e.EndTime						
				,ISNULL(udp.GoodProduct,0)
				,ISNULL(udp.TotalProduct,0)
				,ISNULL(udp.TotalScrap,0)
				,ISNULL(udp.ActualRate,0)
				,ISNULL(udp.TargetRate,0)
				,ISNULL(udp.ScheduleTime,0)
				,ISNULL(udp.PR,0)
				,ISNULL(udp.ScrapPer,0)
				,ISNULL(udp.IdealRate,0)
				,ISNULL(udp.STNU,0)
				,ISNULL(udp.CapacityUtilization,0)
				,ISNULL(udp.ScheduleUtilization,0)
				,ISNULL(udp.Availability,0)
				,ISNULL(udp.PRAvailability,0)
				,ISNULL(udp.StopsMSU,0)
				,ISNULL(udp.DownMSU,0)
				,ISNULL(udp.RunningScrapPer,0)
				,ISNULL(udp.RunningScrap,0)
				,ISNULL(udp.StartingScrapPer,0)
				,ISNULL(udp.StartingScrap,0)
				,ISNULL(udp.RoomLoss,0)
				,ISNULL(udp.MSU,0)
				,ISNULL(udp.TotalCases,0)
				,ISNULL(udp.RateUtilization,0)
				,ISNULL(udp.RunEff,0)
				--,ISNULL(udp.SafetyTrigg,0)
				--,ISNULL(udp.QualityTrigg,0)
				,ISNULL(udp.VSNetProduction,0)
				,ISNULL(udp.VSPR,0)
				,ISNULL(udp.VSPRLossPer,0)--
				,ISNULL(udp.PRRateLoss,0)
				,ISNULL(udd.TotalStops,0)
				,ISNULL(udd.Duration,0)
				,ISNULL(udd.TotalUpdDowntime,0)
				,ISNULL(udd.TotalUpdStops,0)
				,ISNULL(udd.MinorStops,0)
				,ISNULL(udd.ProcFailures,0)
				,ISNULL(udd.MajorStops,0)
				,ISNULL(udd.Uptime,0)
				,ISNULL(udd.MTBF,0)
				,ISNULL(udd.MTBFUpd,0)
				,ISNULL(udd.MTTR,0)
				,ISNULL(udd.UpsDTPRLoss,0)
				,ISNULL(udd.R0,0)
				,ISNULL(udd.R2,0)
				,ISNULL(udd.BreakDown,0)
				,ISNULL(udd.MTTRUpd,0)
				,ISNULL(udd.UpdDownPerc,0)
				,ISNULL(udd.StopsDay,0)
				,ISNULL(udd.ProcFailuresDay,0)
				,ISNULL(udd.Availability_Unpl_DT,0)
				,ISNULL(udd.Availability_Total_DT,0)
				,ISNULL(udd.MTBS,0)
				,ISNULL(udd.ACPStops,0)
				,ISNULL(udd.ACPStopsDay,0)
				,ISNULL(udd.RepairTimeT,0)
				,ISNULL(udd.FalseStarts0,0)
				,ISNULL(udd.FalseStarts0Per,0)
				,ISNULL(udd.FalseStartsT,0)
				,ISNULL(udd.FalseStartsTPer,0)
				,ISNULL(udd.Survival240Rate,0)
				,ISNULL(udd.Survival240RatePer,0)
				,ISNULL(udd.EditedStops,0)
				,ISNULL(udd.EditedStopsPer,0)
				,ISNULL(udd.TotalUpdStopDay,0)
				,ISNULL(udd.StopsBDSDay,0)
				,ISNULL(udd.TotalPlannedStops,0)
				,ISNULL(udd.TotalPlannedStopsDay,0)
				,ISNULL(udd.MajorStopsDay,0)
				,ISNULL(udd.MinorStopsDay,0)
				,ISNULL(udd.TotalStarvedStops,0)
				,ISNULL(udd.TotalBlockedStops,0)
				,ISNULL(udd.TotalStarvedDowntime,0)
				,ISNULL(udd.TotalBlockedDowntime,0)
				,ISNULL(udd.VSScheduledTime,0)
				,ISNULL(udd.VSPRLossPlanned,0)
				,ISNULL(udd.VSPRLossUnplanned,0)
				,ISNULL(udd.VSPRLossBreakdown,0)
				,ISNULL(udd.Survival210Rate,0)
				,ISNULL(udd.Survival210RatePer,0)
				,ISNULL(udd.R210,0)
				,ISNULL(udd.R240,0)
				,ISNULL(udd.Availability_Planned_DT,0)
				,ISNULL(udd.TotalPlannedDowntime,0)
				,ISNULL(udd.PlannedDTPRLoss,0)
				,ISNULL(udp.Area4LossPer,0)
				,ISNULL(udp.ConvertedCases,0) 
				,ISNULL(udp.BrandProjectPer,0)		
				,ISNULL(udp.EO_NonShippablePer,0)		
				,ISNULL(udp.LineNotStaffedPer,0)		
				,ISNULL(udp.STNUPer,0)
				,ISNULL(udp.PRLossScrap,0)	
				,ISNULL(udp.StatUnits,0)
				,ISNULL(udd.IdleTime,0)					
				,ISNULL(udd.ExcludedTime,0)				
				,ISNULL(udd.MAchineStopsDay,0)			
				,ISNULL(udp.StatCases,0)		
				,ISNULL(udp.TargetRateAdj,0)
				,ISNULL(udp.PR_Excl_PRInDev,0)
				,ISNULL(udp.NetProductionExcDev,0)
				,ISNULL(udp.ScheduleTimeExcDev,0)	
				,ISNULL(udp.MSUExcDev,0)
				,ISNULL(udp.ProjConstructPerc,0)
				,ISNULL(udp.STNUSchedVarPerc,0)		
				,ISNULL(udp.StatFactor,0)
			FROM @Equipment e 
			JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON e.PLId = l.PLId
			JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
										   AND udp.Starttime = e.StartTime
										   AND udp.Endtime = e.EndTime
			LEFT JOIN #UserDefinedDowntime udd ON udd.LineId = l.LineId
										   AND udd.Starttime = e.StartTime
										   AND udd.Endtime = e.EndTime
										   AND udp.ProductCode = udd.ProductCode
		
		--SELECT '@MinorGroup',* from @MinorGroup
		
		INSERT INTO #MinorFlexVars(
					 MinorGroupId
					,MinorGroupBy
					,MajorGroupId
					,MajorGroupBy			
					,StartTime					
					,LineStatus					
					,EndTime		)	
			SELECT  
					 mg.MinorGroupId	
					,mg.MinorGroupBy
					,e.PLId
					,e.PLDesc			
					,e.StartTime		
					,@strNPT							
					,e.EndTime					
			FROM @Equipment e 
			JOIN @MinorGroup mg ON e.PLId = mg.MajorGroupId

			--select '#MinorFlexVars',* from #MinorFlexVars
			SET @Query = ''

			SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
				' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(udfv.Result,0) ' + CHAR(13) +
				' FROM #UserDefinedFlexVariables udfv  ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON udfv.FACT_UDPs_Idx = fu.Idx ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  udfv.LineId = l.LineId ' + CHAR(13) +
				'	WHERE fu.VarDesc  = ''' + c.name + '''' + CHAR(13) +
				'   AND ((fu.ExpirationDate IS NOT NULL ' + CHAR(13) + ' AND fu.EffectiveDate >= udfv.StartTime'  + CHAR(13) + ' AND fu.ExpirationDate <= udfv.StartTime'  + CHAR(13) + ') OR (fu.ExpirationDate IS NULL ' + CHAR(13) + '))' +
				'	AND udfv.Status = #MinorFlexVars.LineStatus ' + CHAR(13) +
				'	AND udfv.TeamDesc = ''All'' ' + CHAR(13) +
				'	AND udfv.ShiftDesc = ''All'' ' + CHAR(13) +
				'	AND l.PLId = #MinorFlexVars.MajorGroupId ' + CHAR(13) +
				'	AND udfv.ProductCode = #MinorFlexVars.MinorGroupBy ' + CHAR(13) +
				'	AND udfv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
				'	AND udfv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
			from tempdb.sys.columns c
			where object_id = object_id('tempdb..#MinorFlexVars')
			AND	c.name NOT LIKE 'Idx'
			AND	c.name NOT LIKE 'MinorGroupId'
			AND	c.name NOT LIKE 'MinorGroupBy'
			AND	c.name NOT LIKE 'MajorGroupId'
			AND	c.name NOT LIKE 'MajorGroupBy'
			AND	c.name NOT LIKE 'TeamDesc'		
			AND	c.name NOT LIKE 'StartTime'	
			AND	c.name NOT LIKE 'LineStatus'	
			AND	c.name NOT LIKE 'EndTime'

			EXEC (@Query)
	END
	-- --------------------------------------------------------------------------------------------------------------------
	-- Get KPI's for the MAJOR group
	-- --------------------------------------------------------------------------------------------------------------------
	IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MajorGroup(
				 MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime					
				,GoodProduct				
				,TotalProduct				
				,TotalScrap					
				,ActualRate					
				,TargetRate					
				,ScheduleTime				
				,PR							
				,ScrapPer					
				,IdealRate					
				,STNU						
				,CapacityUtilization		
				,ScheduleUtilization		
				,Availability				
				,PRAvailability				
				,StopsMSU					
				,DownMSU					
				,RunningScrapPer			
				,RunningScrap				
				,StartingScrapPer			
				,StartingScrap				
				,RoomLoss					
				,MSU						
				,TotalCases					
				,RateUtilization			
				,RunEff						
				--,SafetyTrigg				
				--,QualityTrigg				
				,VSNetProduction			
				,VSPR						
				,VSPRLossPer	
				,PercentPRRateLoss				
				,TotalStops					
				,Duration					
				,TotalUpdDowntime			
				,TotalUpdStops				
				,MinorStops					
				,ProcFailures				
				,MajorStops					
				,Uptime						
				,MTBF						
				,MTBFUpd					
				,MTTR						
				,UpsDTPRLoss				
				,R0							
				,R2							
				,BreakDown					
				,MTTRUpd					
				,UpdDownPerc				
				,StopsDay					
				,ProcFailuresDay			
				,Availability_Unpl_DT		
				,Availability_Total_DT		
				,MTBS						
				,ACPStops					
				,ACPStopsDay				
				,RepairTimeT				
				,FalseStarts0				
				,FalseStarts0Per			
				,FalseStartsT				
				,FalseStartsTPer			
				,Survival240Rate			
				,Survival240RatePer			
				,EditedStops				
				,EditedStopsPer				
				,TotalUpdStopDay			
				,StopsBDSDay				
				,TotalPlannedStops			
				,TotalPlannedStopsDay		
				,MajorStopsDay				
				,MinorStopsDay				
				,TotalStarvedStops			
				,TotalBlockedStops			
				,TotalStarvedDowntime		
				,TotalBlockedDowntime		
				,VSScheduledTime			
				,VSPRLossPlanned			
				,VSPRLossUnplanned			
				,VSPRLossBreakdown			
				,Survival210Rate			
				,Survival210RatePer			
				,R210						
				,R240						
				,Availability_Planned_DT	
				,TotalPlannedDowntime		
				,PlannedDTPRLoss
				,Area4LossPer
				,ConvertedCases
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap								
				,StatUnits	
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay						
				,StatCases			
				,TargetRateAdj
				,PR_Excl_PRInDev	
				,NetProductionExcDev
				,ScheduleTimeExcDev	
				,MSUExcDev
				,ProjConstructPerc
				,STNUSchedVarPerc			
				,StatFactor)				

			SELECT DISTINCT
				 e.PLId	
				,e.PLDesc
				,ISNULL(fp.TeamDesc,'')
				,e.StartTime
				,fp.LineStatus					
				,e.EndTime						
				,ISNULL(fp.GoodProduct,0)
				,ISNULL(fp.TotalProduct,0)
				,ISNULL(fp.TotalScrap,0)
				,ISNULL(fp.ActualRate,0)
				,ISNULL(fp.TargetRate,0)
				,ISNULL(fp.ScheduleTime,0)
				,ISNULL(fp.PR,0)
				,ISNULL(fp.ScrapPer,0)
				,ISNULL(fp.IdealRate,0)
				,ISNULL(fp.STNU,0)
				,ISNULL(fp.CapacityUtilization,0)
				,ISNULL(fp.ScheduleUtilization,0)
				,ISNULL(fp.Availability,0)
				,ISNULL(fp.PRAvailability,0)
				,ISNULL(fp.StopsMSU,0)
				,ISNULL(fp.DownMSU,0)
				,ISNULL(fp.RunningScrapPer,0)
				,ISNULL(fp.RunningScrap,0)
				,ISNULL(fp.StartingScrapPer,0)
				,ISNULL(fp.StartingScrap,0)
				,ISNULL(fp.RoomLoss,0)
				,ISNULL(fp.MSU,0)
				,ISNULL(fp.TotalCases,0)
				,ISNULL(fp.RateUtilization,0)
				,ISNULL(fp.RunEff,0)
				--,ISNULL(fp.SafetyTrigg,0)
				--,ISNULL(fp.QualityTrigg,0)
				,ISNULL(fp.VSNetProduction,0)
				,ISNULL(fp.VSPR,0)
				,ISNULL(fp.VSPRLossPer,0)--
				,ISNULL(fp.PRRateLoss,0)
				,ISNULL(fd.TotalStops,0)
				,ISNULL(fd.Duration,0)
				,ISNULL(fd.TotalUpdDowntime,0)
				,ISNULL(fd.TotalUpdStops,0)
				,ISNULL(fd.MinorStops,0)
				,ISNULL(fd.ProcFailures,0)
				,ISNULL(fd.MajorStops,0)
				,ISNULL(fd.Uptime,0)
				,ISNULL(fd.MTBF,0)
				,ISNULL(fd.MTBFUpd,0)
				,ISNULL(fd.MTTR,0)
				,ISNULL(fd.UpsDTPRLoss,0)
				,ISNULL(fd.R0,0)
				,ISNULL(fd.R2,0)
				,ISNULL(fd.BreakDown,0)
				,ISNULL(fd.MTTRUpd,0)
				,ISNULL(fd.UpdDownPerc,0)
				,ISNULL(fd.StopsDay,0)
				,ISNULL(fd.ProcFailuresDay,0)
				,ISNULL(fd.Availability_Unpl_DT,0)
				,ISNULL(fd.Availability_Total_DT,0)
				,ISNULL(fd.MTBS,0)
				,ISNULL(fd.ACPStops,0)
				,ISNULL(fd.ACPStopsDay,0)
				,ISNULL(fd.RepairTimeT,0)
				,ISNULL(fd.FalseStarts0,0)
				,ISNULL(fd.FalseStarts0Per,0)
				,ISNULL(fd.FalseStartsT,0)
				,ISNULL(fd.FalseStartsTPer,0)
				,ISNULL(fd.Survival240Rate,0)
				,ISNULL(fd.Survival240RatePer,0)
				,ISNULL(fd.EditedStops,0)
				,ISNULL(fd.EditedStopsPer,0)
				,ISNULL(fd.TotalUpdStopDay,0)
				,ISNULL(fd.StopsBDSDay,0)
				,ISNULL(fd.TotalPlannedStops,0)
				,ISNULL(fd.TotalPlannedStopsDay,0)
				,ISNULL(fd.MajorStopsDay,0)
				,ISNULL(fd.MinorStopsDay,0)
				,ISNULL(fd.TotalStarvedStops,0)
				,ISNULL(fd.TotalBlockedStops,0)
				,ISNULL(fd.TotalStarvedDowntime,0)
				,ISNULL(fd.TotalBlockedDowntime,0)
				,ISNULL(fd.VSScheduledTime,0)
				,ISNULL(fd.VSPRLossPlanned,0)
				,ISNULL(fd.VSPRLossUnplanned,0)
				,ISNULL(fd.VSPRLossBreakdown,0)
				,ISNULL(fd.Survival210Rate,0)
				,ISNULL(fd.Survival210RatePer,0)
				,ISNULL(fd.R210,0)
				,ISNULL(fd.R240,0)
				,ISNULL(fd.Availability_Planned_DT,0)
				,ISNULL(fd.TotalPlannedDowntime,0)
				,ISNULL(fd.PlannedDTPRLoss,0)
				,ISNULL(fp.Area4LossPer,0)
				,ISNULL(fp.ConvertedCases,0)
				,ISNULL(fp.BrandProjectPer,0)		
				,ISNULL(fp.EO_NonShippablePer,0)		
				,ISNULL(fp.LineNotStaffedPer,0)		
				,ISNULL(fp.STNUPer,0)	
				,ISNULL(fp.PRLossScrap,0)	 
				,ISNULL(fp.StatUnits,0)
				,ISNULL(fd.IdleTime,0)					
				,ISNULL(fd.ExcludedTime,0)				
				,ISNULL(fd.MAchineStopsDay,0)				
				,ISNULL(fp.StatCases,0)	
				,ISNULL(fp.TargetRateAdj,0)
				,ISNULL(fp.PR_Excl_PRInDev,0)
				,ISNULL(fp.NetProductionExcDev,0)
				,ISNULL(fp.ScheduleTimeExcDev,0)	
				,ISNULL(fp.MSUExcDev,0)
				,ISNULL(fp.ProjConstructPerc,0)
				,ISNULL(fp.STNUSchedVarPerc,0)	
				,ISNULL(fp.StatFactor,0)
			FROM @Equipment e 
			JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON e.PLId = ld.PLId
			LEFT JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
															AND fp.LineStatus = @strNPT
															AND fp.Date_Dimension_DateId = @intTimeOption
															AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,e.StartTime)
															AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,e.EndTime)
															AND fp.ShiftDesc = 'All'
															AND fp.TeamDesc = 'All'
															AND fp.Workcell_Dimension_WorkcellId = 0
			LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.LINE_DIMENSION_LineId = ld.LineId
															AND fd.LineStatus = @strNPT
															AND fd.Date_Dimension_DateId = @intTimeOption
															AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,e.StartTime)
															AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,e.EndTime)
															AND fd.ShiftDesc = 'All'
															AND fd.TeamDesc = 'All'
															AND fd.Workcell_Dimension_WorkcellId = 0
		--select '@Equipment',* from @Equipment
		--SELECT '@MajorGroup',* FROM @MajorGroup

		INSERT INTO #MajorFlexVars(
				 MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime		)	
		SELECT   MajorGroupId
				,MajorGroupBy
				,TeamDesc						
				,StartTime					
				,LineStatus					
				,EndTime	
		FROM @MajorGroup

		--SELECT '#MajorFlexVars',* from #MajorFlexVars

		SET @Query = ''

		SELECT @Query = @Query + ' UPDATE #MajorFlexVars ' + CHAR(13) +
			' SET #MajorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(fv.Result,0) ' + CHAR(13) +
			' FROM [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd  ' + CHAR(13) +
			'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON kd.KPI_Desc = fu.VarDesc ' + CHAR(13) +
			'	JOIN [Auto_opsDataStore].[dbo].[FACT_PRODUCTION_Flexible_Variables] fv (NOLOCK) ON fu.Idx = fv.FACT_UDPs_Idx ' + CHAR(13) +
			'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  fv.Line_Dimension_LineId = l.LineId ' + CHAR(13) +
			'	WHERE kd.Fact like ''%Flexible_Variables%'' ' + CHAR(13) +
			'	AND kd.KPI_Desc  = ''' + c.name + '''' + CHAR(13) +
			'	AND fu.ExpirationDate IS NULL ' + CHAR(13) +
			'	AND fv.LineStatus = ''' + @strNPT + ''' ' + CHAR(13) +
			'	AND fv.TeamDesc = ''All'' ' + CHAR(13) +
			'	AND fv.ShiftDesc = ''All'' ' + CHAR(13) +
			'	AND l.PLId = #MajorFlexVars.MajorGroupId ' + CHAR(13) +
			'	AND fv.Date_Dimension_DateId =  ''' + CAST(@intTimeOption AS NVARCHAR(10)) + ''' ' + CHAR(13) +
			'	AND fv.StartTime >= #MajorFlexVars.StartTime ' + CHAR(13) +
			'	AND fv.StartTime < #MajorFlexVars.EndTime ),0);' + CHAR(13) 
		from tempdb.sys.columns c
		where object_id = object_id('tempdb..#MajorFlexVars')
		AND	c.name NOT LIKE 'Idx'
		AND	c.name NOT LIKE 'MajorGroupId'
		AND	c.name NOT LIKE 'MajorGroupBy'
		AND	c.name NOT LIKE 'TeamDesc'		
		AND	c.name NOT LIKE 'StartTime'	
		AND	c.name NOT LIKE 'LineStatus'	
		AND	c.name NOT LIKE 'EndTime'

		exec (@Query)
		--SELECT '#MajorFlexVars',* from #MajorFlexVars
	END
	ELSE
	BEGIN
		--Delete tables before reuse.
		DELETE #UserDefinedProduction
		DELETE #UserDefinedDowntime
		DELETE #UserDefinedFlexVariables
		--inser values from custom aggregates
		--Production AGG
		INSERT INTO #UserDefinedProduction
		EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
													, @dtmStartTime
													, @dtmEndTime
													, @strLineId
													, @strWorkcellId
													, @strNPT
													,'All'
													,'All'
													,'Line'
													, 0
		
		--SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction

		--Downtime AGG
		INSERT INTO #UserDefinedDowntime
		EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
													, @dtmStartTime
													, @dtmEndTime
													, @strLineId
													, @strWorkcellId
													, @strNPT
													,'All'
													,'All'
													,'Line'
		
		--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime
		--inser values from custom aggregates
		--Production AGG for Flexible Variables
		INSERT INTO #UserDefinedFlexVariables
		EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
													, @dtmStartTime
													, @dtmEndTime
													, @strLineId
													, @strWorkcellId
													, @strNPT
													,'All'
													,'All'
													,'Line'
													, 1
	
		--SELECT '#UserDefinedFlexVariablesasdad',* FROM #UserDefinedFlexVariables


		--Insert values to minor group table
		INSERT INTO @MajorGroup(
			 MajorGroupId
			,MajorGroupBy
			,TeamDesc						
			,StartTime					
			,LineStatus					
			,EndTime					
			,GoodProduct				
			,TotalProduct				
			,TotalScrap					
			,ActualRate					
			,TargetRate					
			,ScheduleTime				
			,PR							
			,ScrapPer					
			,IdealRate					
			,STNU						
			,CapacityUtilization		
			,ScheduleUtilization		
			,Availability				
			,PRAvailability				
			,StopsMSU					
			,DownMSU					
			,RunningScrapPer			
			,RunningScrap				
			,StartingScrapPer			
			,StartingScrap				
			,RoomLoss					
			,MSU						
			,TotalCases					
			,RateUtilization			
			,RunEff						
			--,SafetyTrigg				
			--,QualityTrigg				
			,VSNetProduction			
			,VSPR						
			,VSPRLossPer	
			,PercentPRRateLoss				
			,TotalStops					
			,Duration					
			,TotalUpdDowntime			
			,TotalUpdStops				
			,MinorStops					
			,ProcFailures				
			,MajorStops					
			,Uptime						
			,MTBF						
			,MTBFUpd					
			,MTTR						
			,UpsDTPRLoss				
			,R0							
			,R2							
			,BreakDown					
			,MTTRUpd					
			,UpdDownPerc				
			,StopsDay					
			,ProcFailuresDay			
			,Availability_Unpl_DT		
			,Availability_Total_DT		
			,MTBS						
			,ACPStops					
			,ACPStopsDay				
			,RepairTimeT				
			,FalseStarts0				
			,FalseStarts0Per			
			,FalseStartsT				
			,FalseStartsTPer			
			,Survival240Rate			
			,Survival240RatePer			
			,EditedStops				
			,EditedStopsPer				
			,TotalUpdStopDay			
			,StopsBDSDay				
			,TotalPlannedStops			
			,TotalPlannedStopsDay		
			,MajorStopsDay				
			,MinorStopsDay				
			,TotalStarvedStops			
			,TotalBlockedStops			
			,TotalStarvedDowntime		
			,TotalBlockedDowntime		
			,VSScheduledTime			
			,VSPRLossPlanned			
			,VSPRLossUnplanned			
			,VSPRLossBreakdown			
			,Survival210Rate			
			,Survival210RatePer			
			,R210						
			,R240						
			,Availability_Planned_DT	
			,TotalPlannedDowntime		
			,PlannedDTPRLoss
			,Area4LossPer
			,ConvertedCases
			,BrandProjectPer		
			,EO_NonShippablePer		
			,LineNotStaffedPer		
			,STNUPer				
			,PRLossScrap							
			,StatUnits							
			,IdleTime					
			,ExcludedTime				
			,MAchineStopsDay			
			,StatCases		
			,TargetRateAdj
			,PR_Excl_PRInDev	
			,NetProductionExcDev
			,ScheduleTimeExcDev	
			,MSUExcDev
			,ProjConstructPerc
			,STNUSchedVarPerc			
			,StatFactor)				

		SELECT DISTINCT
				 e.PLId	
				,e.PLDesc
				,ISNULL(udp.TeamDesc,'')
				,e.StartTime
				,udp.Status					
				,e.EndTime						
				,ISNULL(udp.GoodProduct,0)
				,ISNULL(udp.TotalProduct,0)
				,ISNULL(udp.TotalScrap,0)
				,ISNULL(udp.ActualRate,0)
				,ISNULL(udp.TargetRate,0)
				,ISNULL(udp.ScheduleTime,0)
				,ISNULL(udp.PR,0)
				,ISNULL(udp.ScrapPer,0)
				,ISNULL(udp.IdealRate,0)
				,ISNULL(udp.STNU,0)
				,ISNULL(udp.CapacityUtilization,0)
				,ISNULL(udp.ScheduleUtilization,0)
				,ISNULL(udp.Availability,0)
				,ISNULL(udp.PRAvailability,0)
				,ISNULL(udp.StopsMSU,0)
				,ISNULL(udp.DownMSU,0)
				,ISNULL(udp.RunningScrapPer,0)
				,ISNULL(udp.RunningScrap,0)
				,ISNULL(udp.StartingScrapPer,0)
				,ISNULL(udp.StartingScrap,0)
				,ISNULL(udp.RoomLoss,0)
				,ISNULL(udp.MSU,0)
				,ISNULL(udp.TotalCases,0)
				,ISNULL(udp.RateUtilization,0)
				,ISNULL(udp.RunEff,0)
				--,ISNULL(fp.SafetyTrigg,0)
				--,ISNULL(fp.QualityTrigg,0)
				,ISNULL(udp.VSNetProduction,0)
				,ISNULL(udp.VSPR,0)
				,ISNULL(udp.VSPRLossPer,0)--
				,ISNULL(udp.PRRateLoss,0)
				,ISNULL(udd.TotalStops,0)
				,ISNULL(udd.Duration,0)
				,ISNULL(udd.TotalUpdDowntime,0)
				,ISNULL(udd.TotalUpdStops,0)
				,ISNULL(udd.MinorStops,0)
				,ISNULL(udd.ProcFailures,0)
				,ISNULL(udd.MajorStops,0)
				,ISNULL(udd.Uptime,0)
				,ISNULL(udd.MTBF,0)
				,ISNULL(udd.MTBFUpd,0)
				,ISNULL(udd.MTTR,0)
				,ISNULL(udd.UpsDTPRLoss,0)
				,ISNULL(udd.R0,0)
				,ISNULL(udd.R2,0)
				,ISNULL(udd.BreakDown,0)
				,ISNULL(udd.MTTRUpd,0)
				,ISNULL(udd.UpdDownPerc,0)
				,ISNULL(udd.StopsDay,0)
				,ISNULL(udd.ProcFailuresDay,0)
				,ISNULL(udd.Availability_Unpl_DT,0)
				,ISNULL(udd.Availability_Total_DT,0)
				,ISNULL(udd.MTBS,0)
				,ISNULL(udd.ACPStops,0)
				,ISNULL(udd.ACPStopsDay,0)
				,ISNULL(udd.RepairTimeT,0)
				,ISNULL(udd.FalseStarts0,0)
				,ISNULL(udd.FalseStarts0Per,0)
				,ISNULL(udd.FalseStartsT,0)
				,ISNULL(udd.FalseStartsTPer,0)
				,ISNULL(udd.Survival240Rate,0)
				,ISNULL(udd.Survival240RatePer,0)
				,ISNULL(udd.EditedStops,0)
				,ISNULL(udd.EditedStopsPer,0)
				,ISNULL(udd.TotalUpdStopDay,0)
				,ISNULL(udd.StopsBDSDay,0)
				,ISNULL(udd.TotalPlannedStops,0)
				,ISNULL(udd.TotalPlannedStopsDay,0)
				,ISNULL(udd.MajorStopsDay,0)
				,ISNULL(udd.MinorStopsDay,0)
				,ISNULL(udd.TotalStarvedStops,0)
				,ISNULL(udd.TotalBlockedStops,0)
				,ISNULL(udd.TotalStarvedDowntime,0)
				,ISNULL(udd.TotalBlockedDowntime,0)
				,ISNULL(udd.VSScheduledTime,0)
				,ISNULL(udd.VSPRLossPlanned,0)
				,ISNULL(udd.VSPRLossUnplanned,0)
				,ISNULL(udd.VSPRLossBreakdown,0)
				,ISNULL(udd.Survival210Rate,0)
				,ISNULL(udd.Survival210RatePer,0)
				,ISNULL(udd.R210,0)
				,ISNULL(udd.R240,0)
				,ISNULL(udd.Availability_Planned_DT,0)
				,ISNULL(udd.TotalPlannedDowntime,0)
				,ISNULL(udd.PlannedDTPRLoss,0)
				,ISNULL(udp.Area4LossPer,0)
				,ISNULL(udp.ConvertedCases,0)
				,ISNULL(udp.BrandProjectPer,0)		
				,ISNULL(udp.EO_NonShippablePer,0)		
				,ISNULL(udp.LineNotStaffedPer,0)		
				,ISNULL(udp.STNUPer,0)	
				,ISNULL(udp.PRLossScrap,0)	
				,ISNULL(udp.StatUnits,0)
				,ISNULL(udd.IdleTime,0)					
				,ISNULL(udd.ExcludedTime,0)				
				,ISNULL(udd.MAchineStopsDay,0)			
				,ISNULL(udp.StatCases,0)		
				,ISNULL(udp.TargetRateAdj,0)
				,ISNULL(udp.PR_Excl_PRInDev,0)
				,ISNULL(udp.NetProductionExcDev,0)
				,ISNULL(udp.ScheduleTimeExcDev,0)	
				,ISNULL(udp.MSUExcDev,0)
				,ISNULL(udp.ProjConstructPerc,0)
				,ISNULL(udp.STNUSchedVarPerc,0)			
				,ISNULL(udp.StatFactor,0)
		FROM @Equipment e 
		JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON e.PLId = l.PLId
		LEFT JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
									   --AND udp.Starttime = pd.StartTime
									   --AND udp.Endtime = pd.EndTime
		LEFT JOIN #UserDefinedDowntime udd ON udd.LineId = l.LineId
											AND udd.ProductCode = udp.ProductCode
									   --AND udd.Starttime = pd.StartTime
										  -- AND udd.Endtime = pd.EndTime

		--SELECT '@Equipment',* from @Equipment
		INSERT INTO #MajorFlexVars(
					 MajorGroupId
					,MajorGroupBy
					,StartTime			
					,LineStatus					
					,EndTime		)	
		SELECT		
					 e.PLId	
					,e.PLDesc
					,e.StartTime
					,@strNPT			
					,e.EndTime			
		FROM @Equipment e 
		JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON e.PLId = l.PLId

		--select '#MajorFlexVarsasd',* from #MajorFlexVars

		SET @Query = ''
		SELECT @Query = @Query + ' UPDATE #MajorFlexVars ' + CHAR(13) +
			' SET #MajorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(udfv.Result,0) ' + CHAR(13) +
			' FROM #UserDefinedFlexVariables udfv  ' + CHAR(13) +
			'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON udfv.FACT_UDPs_Idx = fu.Idx ' + CHAR(13) +
			'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  udfv.LineId = l.LineId ' + CHAR(13) +
			'	WHERE fu.VarDesc  = ''' + c.name + '''' + CHAR(13) +
			'   AND ((fu.ExpirationDate IS NOT NULL ' + CHAR(13) + ' AND fu.EffectiveDate >= udfv.StartTime'  + CHAR(13) + ' AND fu.ExpirationDate <= udfv.StartTime'  + CHAR(13) + ') OR (fu.ExpirationDate IS NULL ' + CHAR(13) + '))' +
			'	AND udfv.Status = ''' + @strNPT + ''' ' + CHAR(13) +
			'	AND udfv.TeamDesc =  ''All'' ' + CHAR(13) +
			'	AND udfv.ShiftDesc = ''All'' ' + CHAR(13) +
			'	AND l.PLId = #MajorFlexVars.MajorGroupId ' + CHAR(13) +
			'	AND udfv.StartTime >= #MajorFlexVars.StartTime ' + CHAR(13) +
			'	AND udfv.StartTime < #MajorFlexVars.EndTime ),0);' + CHAR(13) 
		from tempdb.sys.columns c
		where object_id = object_id('tempdb..#MajorFlexVars')
		AND	c.name NOT LIKE 'Idx'
		AND	c.name NOT LIKE 'MinorGroupId'
		AND	c.name NOT LIKE 'MinorGroupBy'
		AND	c.name NOT LIKE 'MajorGroupId'
		AND	c.name NOT LIKE 'MajorGroupBy'
		AND	c.name NOT LIKE 'TeamDesc'		
		AND	c.name NOT LIKE 'StartTime'	
		AND	c.name NOT LIKE 'LineStatus'	
		AND	c.name NOT LIKE 'EndTime'

		EXEC (@Query)
		--select '#MajorFlexVars1',* from #MajorFlexVars
	END
END

--=====================================================================================================================
-- Major Group: Production Day
-- --------------------------------------------------------------------------------------------------------------------
IF @strMajorGroupBy = 'ProdDay'
BEGIN
	IF @strMinorGroupBy = 'Line'
	BEGIN
		IF @intTimeOption > 0
		BEGIN
			INSERT INTO @MinorGroup(
					 MajorGroupId
					,MajorGroupBy
					,MinorGroupId
					,MinorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime		
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap								
					,StatUnits	
					,NetProduction	
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay						
					,StatCases			
					,TargetRateAdj
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

				SELECT DISTINCT
					 pd.ProdDayId	
					,CONVERT(DATE,pd.ProdDay)
					,pd.PLId
					,pd.PLDesc
					,ISNULL(fp.TeamDesc,'')
					,pd.StartTime
					,ISNULL(fp.LineStatus, @strNPT)					
					,pd.EndTime						
					,ISNULL(fp.GoodProduct,0)
					,ISNULL(fp.TotalProduct,0)
					,ISNULL(fp.TotalScrap,0)
					,ISNULL(fp.ActualRate,0)
					,ISNULL(fp.TargetRate,0)
					,ISNULL(fp.ScheduleTime,0)
					,ISNULL(fp.PR,0)
					,ISNULL(fp.ScrapPer,0)
					,ISNULL(fp.IdealRate,0)
					,ISNULL(fp.STNU,0)
					,ISNULL(fp.CapacityUtilization,0)
					,ISNULL(fp.ScheduleUtilization,0)
					,ISNULL(fp.Availability,0)
					,ISNULL(fp.PRAvailability,0)
					,ISNULL(fp.StopsMSU,0)
					,ISNULL(fp.DownMSU,0)
					,ISNULL(fp.RunningScrapPer,0)
					,ISNULL(fp.RunningScrap,0)
					,ISNULL(fp.StartingScrapPer,0)
					,ISNULL(fp.StartingScrap,0)
					,ISNULL(fp.RoomLoss,0)
					,ISNULL(fp.MSU,0)
					,ISNULL(fp.TotalCases,0)
					,ISNULL(fp.RateUtilization,0)
					,ISNULL(fp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(fp.VSNetProduction,0)
					,ISNULL(fp.VSPR,0)
					,ISNULL(fp.VSPRLossPer,0)--
					,ISNULL(fp.PRRateLoss,0)
					,ISNULL(fd.TotalStops,0)
					,ISNULL(fd.Duration,0)
					,ISNULL(fd.TotalUpdDowntime,0)
					,ISNULL(fd.TotalUpdStops,0)
					,ISNULL(fd.MinorStops,0)
					,ISNULL(fd.ProcFailures,0)
					,ISNULL(fd.MajorStops,0)
					,ISNULL(fd.Uptime,0)
					,ISNULL(fd.MTBF,0)
					,ISNULL(fd.MTBFUpd,0)
					,ISNULL(fd.MTTR,0)
					,ISNULL(fd.UpsDTPRLoss,0)
					,ISNULL(fd.R0,0)
					,ISNULL(fd.R2,0)
					,ISNULL(fd.BreakDown,0)
					,ISNULL(fd.MTTRUpd,0)
					,ISNULL(fd.UpdDownPerc,0)
					,ISNULL(fd.StopsDay,0)
					,ISNULL(fd.ProcFailuresDay,0)
					,ISNULL(fd.Availability_Unpl_DT,0)
					,ISNULL(fd.Availability_Total_DT,0)
					,ISNULL(fd.MTBS,0)
					,ISNULL(fd.ACPStops,0)
					,ISNULL(fd.ACPStopsDay,0)
					,ISNULL(fd.RepairTimeT,0)
					,ISNULL(fd.FalseStarts0,0)
					,ISNULL(fd.FalseStarts0Per,0)
					,ISNULL(fd.FalseStartsT,0)
					,ISNULL(fd.FalseStartsTPer,0)
					,ISNULL(fd.Survival240Rate,0)
					,ISNULL(fd.Survival240RatePer,0)
					,ISNULL(fd.EditedStops,0)
					,ISNULL(fd.EditedStopsPer,0)
					,ISNULL(fd.TotalUpdStopDay,0)
					,ISNULL(fd.StopsBDSDay,0)
					,ISNULL(fd.TotalPlannedStops,0)
					,ISNULL(fd.TotalPlannedStopsDay,0)
					,ISNULL(fd.MajorStopsDay,0)
					,ISNULL(fd.MinorStopsDay,0)
					,ISNULL(fd.TotalStarvedStops,0)
					,ISNULL(fd.TotalBlockedStops,0)
					,ISNULL(fd.TotalStarvedDowntime,0)
					,ISNULL(fd.TotalBlockedDowntime,0)
					,ISNULL(fd.VSScheduledTime,0)
					,ISNULL(fd.VSPRLossPlanned,0)
					,ISNULL(fd.VSPRLossUnplanned,0)
					,ISNULL(fd.VSPRLossBreakdown,0)
					,ISNULL(fd.Survival210Rate,0)
					,ISNULL(fd.Survival210RatePer,0)
					,ISNULL(fd.R210,0)
					,ISNULL(fd.R240,0)
					,ISNULL(fd.Availability_Planned_DT,0)
					,ISNULL(fd.TotalPlannedDowntime,0)
					,ISNULL(fd.PlannedDTPRLoss,0)
					,ISNULL(fp.Area4LossPer,0)
					,ISNULL(fp.ConvertedCases,0)
					,ISNULL(fp.BrandProjectPer,0)		
					,ISNULL(fp.EO_NonShippablePer,0)		
					,ISNULL(fp.LineNotStaffedPer,0)		
					,ISNULL(fp.STNUPer,0)	
					,ISNULL(fp.PRLossScrap,0)	
					,ISNULL(fp.StatUnits,0) 
					,ISNULL(fp.NetProduction,0)
					,ISNULL(fd.IdleTime,0)					
					,ISNULL(fd.ExcludedTime,0)				
					,ISNULL(fd.MAchineStopsDay,0)				
					,ISNULL(fp.StatCases,0)		
					,ISNULL(fp.TargetRateAdj,0)
					,ISNULL(fp.PR_Excl_PRInDev,0)
					,ISNULL(fp.NetProductionExcDev,0)
					,ISNULL(fp.ScheduleTimeExcDev,0)	
					,ISNULL(fp.MSUExcDev,0)
					,ISNULL(fp.ProjConstructPerc,0)
					,ISNULL(fp.STNUSchedVarPerc,0)	
					,ISNULL(fp.StatFactor,0)
				FROM @ProdDay pd 
				JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON pd.PLId = ld.PLId
				LEFT JOIN dbo.FACT_PRODUCTION fp (NOLOCK) ON fp.LINE_DIMENSION_LineId = ld.LineId
														AND fp.LineStatus = @strNPT
														AND fp.Date_Dimension_DateId = 2
														AND CONVERT(DATE,fp.StartTime) >= CONVERT(DATE,pd.StartTime)
														AND CONVERT(DATE,fp.EndTime) <= CONVERT(DATE,pd.EndTime)
														AND fp.ShiftDesc = 'All'
														AND fp.TeamDesc = 'All'
														AND fp.Workcell_Dimension_WorkcellId = 0
				LEFT JOIN dbo.FACT_DOWNTIME fd (NOLOCK) ON fd.LINE_DIMENSION_LineId = ld.LineId
														AND fd.LineStatus = @strNPT
														AND fd.Date_Dimension_DateId = 2
														AND CONVERT(DATE,fd.StartTime) >= CONVERT(DATE,pd.StartTime)
														AND CONVERT(DATE,fd.EndTime) <= CONVERT(DATE,pd.EndTime)
														AND fd.ShiftDesc = 'All'
														AND fd.TeamDesc = 'All'
														AND fd.Workcell_Dimension_WorkcellId = 0
				--SELECT '@ProdDay',* FROM @ProdDay
				--SELECT '@MinorGroup',* from @MinorGroup
				INSERT INTO #MinorFlexVars(
						 MajorGroupId
						,MajorGroupBy
						,MinorGroupId				
						,MinorGroupBy			
						,TeamDesc					
						,StartTime		
						,LineStatus		
						,EndTime		)	
				SELECT   MajorGroupId
						,MajorGroupBy
						,MinorGroupId				
						,MinorGroupBy			
						,TeamDesc		
						,StartTime		
						,LineStatus		
						,EndTime		
				FROM @MinorGroup

				--SELECT '#MinorFlexVars',* from #MinorFlexVars

				SET @Query = ''

				SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
					' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(fv.Result,0) ' + CHAR(13) +
					' FROM [Auto_opsDataStore].[dbo].[KPI_DIMENSION] kd  ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON kd.KPI_Desc = fu.VarDesc ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[FACT_PRODUCTION_Flexible_Variables] fv (NOLOCK) ON fu.Idx = fv.FACT_UDPs_Idx ' + CHAR(13) +
					'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  fv.Line_Dimension_LineId = l.LineId ' + CHAR(13) +
					'	WHERE kd.Fact like ''%Flexible_Variables%'' ' + CHAR(13) +
					'	AND kd.KPI_Desc  = ''' + c.name + '''' + CHAR(13) +
					'	AND fu.ExpirationDate IS NULL ' + CHAR(13) +
					'	AND fv.LineStatus = ''' + @strNPT + ''' ' + CHAR(13) +
					'	AND fv.TeamDesc = ''All'' ' + CHAR(13) +
					'	AND fv.ShiftDesc = ''All'' ' + CHAR(13) +
					'	AND l.PLId = #MinorFlexVars.MinorGroupId ' + CHAR(13) +
					'	AND fv.Date_Dimension_DateId =  2' + CHAR(13) +--+ CAST(@intTimeOption AS NVARCHAR(10)) + ''' ' + CHAR(13) +
					'	AND fv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
					'	AND fv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
				from tempdb.sys.columns c
				where object_id = object_id('tempdb..#MinorFlexVars')
				AND	c.name NOT LIKE 'Idx'
				AND	c.name NOT LIKE 'MinorGroupId'
				AND	c.name NOT LIKE 'MinorGroupBy'
				AND	c.name NOT LIKE 'MajorGroupId'
				AND	c.name NOT LIKE 'MajorGroupBy'
				AND	c.name NOT LIKE 'TeamDesc'		
				AND	c.name NOT LIKE 'StartTime'	
				AND	c.name NOT LIKE 'LineStatus'	
				AND	c.name NOT LIKE 'EndTime'
				--print @Query
				EXEC (@Query)

				--SELECT '#MinorFlexVars',* from #MinorFlexVars
		END
		ELSE
		BEGIN
			--Delete tables before reuse.
			DELETE #UserDefinedProduction
			DELETE #UserDefinedDowntime
			DELETE #UserDefinedFlexVariables
			--Iterate to get the line total for each day

			SELECT @i = COUNT(*) FROM @ProdDay
			SELECT @j = 1

			WHILE (@j <= @i)
			BEGIN
				SELECT @StartTime = StartTime, @EndTime = EndTime, @PLId = PLId FROM @ProdDay WHERE RcdIdx = @j

				--inser values from custom aggregates
				--Production AGG
				INSERT INTO #UserDefinedProduction
				EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
															, @StartTime
															, @EndTime
															, @PLId
															, ''
															, @strNPT
															,'All'
															,'All'
															,'Line'
															, 0
				--Downtime AGG
				INSERT INTO #UserDefinedDowntime
				EXEC [dbo].[spLocal_OpsDS_Agg_DowntimeData]   NULL
															, @StartTime
															, @EndTime
															, @PLId
															, ''
															, @strNPT
															,'All'
															,'All'
															,'Line'
				--SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime
				--inser values from custom aggregates
				--Production AGG for Flexible Variables
				INSERT INTO #UserDefinedFlexVariables
				EXEC [dbo].[spLocal_OpsDS_Agg_ProductionData] NULL
															, @StartTime
															, @EndTime
															, @PLId
															, ''
															, @strNPT
															,'All'
															,'All'
															,'Line'
															, 1

				
				SET @j = @j + 1
			END
			--SELECT '#UserDefinedFlexVariablesasdad',* FROM #UserDefinedFlexVariables
			--	SELECT '#UserDefinedProduction',* FROM #UserDefinedProduction
			--	SELECT '#UserDefinedDowntime',* FROM #UserDefinedDowntime
			--Insert values to minor group table
			INSERT INTO @MinorGroup(
					 MajorGroupId
					,MajorGroupBy
					,MinorGroupId
					,MinorGroupBy
					,TeamDesc						
					,StartTime					
					,LineStatus					
					,EndTime					
					,GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime		
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer	
					,PercentPRRateLoss				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,Area4LossPer
					,ConvertedCases
					,BrandProjectPer		
					,EO_NonShippablePer		
					,LineNotStaffedPer		
					,STNUPer				
					,PRLossScrap						
					,StatUnits						
					,IdleTime					
					,ExcludedTime				
					,MAchineStopsDay			
					,StatCases		
					,NetProduction		
					,TargetRateAdj	
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev
					,ProjConstructPerc
					,STNUSchedVarPerc			
					,StatFactor)			

			SELECT DISTINCT
					pd.ProdDayId	
					,CONVERT(DATE,pd.ProdDay)
					,pd.PLId
					,pd.PLDesc
					,ISNULL(udp.TeamDesc,'')
					,pd.StartTime
					,udp.Status	
					,pd.EndTime						
					,ISNULL(udp.GoodProduct,0)
					,ISNULL(udp.TotalProduct,0)
					,ISNULL(udp.TotalScrap,0)
					,ISNULL(udp.ActualRate,0)
					,ISNULL(udp.TargetRate,0)
					,ISNULL(udp.ScheduleTime,0)
					,ISNULL(udp.PR,0)
					,ISNULL(udp.ScrapPer,0)
					,ISNULL(udp.IdealRate,0)
					,ISNULL(udp.STNU,0)
					,ISNULL(udp.CapacityUtilization,0)
					,ISNULL(udp.ScheduleUtilization,0)
					,ISNULL(udp.Availability,0)
					,ISNULL(udp.PRAvailability,0)
					,ISNULL(udp.StopsMSU,0)
					,ISNULL(udp.DownMSU,0)
					,ISNULL(udp.RunningScrapPer,0)
					,ISNULL(udp.RunningScrap,0)
					,ISNULL(udp.StartingScrapPer,0)
					,ISNULL(udp.StartingScrap,0)
					,ISNULL(udp.RoomLoss,0)
					,ISNULL(udp.MSU,0)
					,ISNULL(udp.TotalCases,0)
					,ISNULL(udp.RateUtilization,0)
					,ISNULL(udp.RunEff,0)
					--,ISNULL(fp.SafetyTrigg,0)
					--,ISNULL(fp.QualityTrigg,0)
					,ISNULL(udp.VSNetProduction,0)
					,ISNULL(udp.VSPR,0)
					,ISNULL(udp.VSPRLossPer,0)--
					,ISNULL(udp.PRRateLoss,0)
					,ISNULL(udd.TotalStops,0)
					,ISNULL(udd.Duration,0)
					,ISNULL(udd.TotalUpdDowntime,0)
					,ISNULL(udd.TotalUpdStops,0)
					,ISNULL(udd.MinorStops,0)
					,ISNULL(udd.ProcFailures,0)
					,ISNULL(udd.MajorStops,0)
					,ISNULL(udd.Uptime,0)
					,ISNULL(udd.MTBF,0)
					,ISNULL(udd.MTBFUpd,0)
					,ISNULL(udd.MTTR,0)
					,ISNULL(udd.UpsDTPRLoss,0)
					,ISNULL(udd.R0,0)
					,ISNULL(udd.R2,0)
					,ISNULL(udd.BreakDown,0)
					,ISNULL(udd.MTTRUpd,0)
					,ISNULL(udd.UpdDownPerc,0)
					,ISNULL(udd.StopsDay,0)
					,ISNULL(udd.ProcFailuresDay,0)
					,ISNULL(udd.Availability_Unpl_DT,0)
					,ISNULL(udd.Availability_Total_DT,0)
					,ISNULL(udd.MTBS,0)
					,ISNULL(udd.ACPStops,0)
					,ISNULL(udd.ACPStopsDay,0)
					,ISNULL(udd.RepairTimeT,0)
					,ISNULL(udd.FalseStarts0,0)
					,ISNULL(udd.FalseStarts0Per,0)
					,ISNULL(udd.FalseStartsT,0)
					,ISNULL(udd.FalseStartsTPer,0)
					,ISNULL(udd.Survival240Rate,0)
					,ISNULL(udd.Survival240RatePer,0)
					,ISNULL(udd.EditedStops,0)
					,ISNULL(udd.EditedStopsPer,0)
					,ISNULL(udd.TotalUpdStopDay,0)
					,ISNULL(udd.StopsBDSDay,0)
					,ISNULL(udd.TotalPlannedStops,0)
					,ISNULL(udd.TotalPlannedStopsDay,0)
					,ISNULL(udd.MajorStopsDay,0)
					,ISNULL(udd.MinorStopsDay,0)
					,ISNULL(udd.TotalStarvedStops,0)
					,ISNULL(udd.TotalBlockedStops,0)
					,ISNULL(udd.TotalStarvedDowntime,0)
					,ISNULL(udd.TotalBlockedDowntime,0)
					,ISNULL(udd.VSScheduledTime,0)
					,ISNULL(udd.VSPRLossPlanned,0)
					,ISNULL(udd.VSPRLossUnplanned,0)
					,ISNULL(udd.VSPRLossBreakdown,0)
					,ISNULL(udd.Survival210Rate,0)
					,ISNULL(udd.Survival210RatePer,0)
					,ISNULL(udd.R210,0)
					,ISNULL(udd.R240,0)
					,ISNULL(udd.Availability_Planned_DT,0)
					,ISNULL(udd.TotalPlannedDowntime,0)
					,ISNULL(udd.PlannedDTPRLoss,0)
					,ISNULL(udp.Area4LossPer,0)
					,ISNULL(udp.ConvertedCases,0)
					,ISNULL(udp.BrandProjectPer,0)		
					,ISNULL(udp.EO_NonShippablePer,0)		
					,ISNULL(udp.LineNotStaffedPer,0)		
					,ISNULL(udp.STNUPer,0)	
					,ISNULL(udp.PRLossScrap,0)	
					,ISNULL(udp.StatUnits,0) 
					,ISNULL(udd.IdleTime,0)					
					,ISNULL(udd.ExcludedTime,0)				
					,ISNULL(udd.MAchineStopsDay,0)			
					,ISNULL(udp.StatCases,0)		
					,ISNULL(udp.NetProduction,0)
					,ISNULL(udp.TargetRateAdj,0)
					,ISNULL(udp.PR_Excl_PRInDev,0)
					,ISNULL(udp.NetProductionExcDev,0)
					,ISNULL(udp.ScheduleTimeExcDev,0)	
					,ISNULL(udp.MSUExcDev,0)
					,ISNULL(udp.ProjConstructPerc,0)
					,ISNULL(udp.STNUSchedVarPerc,0)	
					,ISNULL(udp.StatFactor,0)
			FROM @ProdDay pd 
				JOIN dbo.LINE_DIMENSION l WITH(NOLOCK) ON pd.PLId = l.PLId
				LEFT JOIN #UserDefinedProduction udp ON udp.LineId = l.LineId
											   AND udp.Starttime = pd.StartTime
											   AND udp.Endtime = pd.EndTime
				LEFT JOIN #UserDefinedDowntime udd ON udd.LineId = l.LineId
											   AND udd.Starttime = pd.StartTime
											   AND udd.Endtime = pd.EndTime

			--SELECT '@ProdDay',* from @ProdDay
			--SELECT '@MinorGroup',* from @MinorGroup

			INSERT INTO #MinorFlexVars(
						 MajorGroupId
						,MajorGroupBy
						,MinorGroupId				
						,MinorGroupBy			
						,TeamDesc					
						,StartTime		
						,LineStatus		
						,EndTime		)	
				SELECT   MajorGroupId
						,MajorGroupBy
						,MinorGroupId				
						,MinorGroupBy			
						,TeamDesc		
						,StartTime		
						,LineStatus		
						,EndTime		
				FROM @MinorGroup
			
			--SELECT '#MinorFlexVars',* from #MinorFlexVars
			SET @Query = ''

			SELECT @Query = @Query + ' UPDATE #MinorFlexVars ' + CHAR(13) +
				' SET #MinorFlexVars.[' + c.name + '] = ISNULL((SELECT ISNULL(udfv.Result,0) ' + CHAR(13) +
				' FROM #UserDefinedFlexVariables udfv  ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[FACT_UDPs] fu (NOLOCK) ON udfv.FACT_UDPs_Idx = fu.Idx ' + CHAR(13) +
				'	JOIN [Auto_opsDataStore].[dbo].[LINE_DIMENSION] l (NOLOCK) ON  udfv.LineId = l.LineId ' + CHAR(13) +
				'	WHERE fu.VarDesc  = ''' + c.name + '''' + CHAR(13) +
				'   AND ((fu.ExpirationDate IS NOT NULL ' + CHAR(13) + ' AND fu.EffectiveDate >= udfv.StartTime'  + CHAR(13) + ' AND fu.ExpirationDate <= udfv.StartTime'  + CHAR(13) + ') OR (fu.ExpirationDate IS NULL ' + CHAR(13) + '))' +
				'	AND udfv.Status = #MinorFlexVars.LineStatus ' + CHAR(13) +
				'	AND udfv.TeamDesc = ''All'' ' + CHAR(13) +
				'	AND udfv.ShiftDesc = ''All'' ' + CHAR(13) +
				'	AND l.PLId = #MinorFlexVars.MinorGroupId ' + CHAR(13) +
				'	AND udfv.StartTime >= #MinorFlexVars.StartTime ' + CHAR(13) +
				'	AND udfv.StartTime < #MinorFlexVars.EndTime ),0);' + CHAR(13) 
			from tempdb.sys.columns c
			where object_id = object_id('tempdb..#MinorFlexVars')
			AND	c.name NOT LIKE 'Idx'
			AND	c.name NOT LIKE 'MinorGroupId'
			AND	c.name NOT LIKE 'MinorGroupBy'
			AND	c.name NOT LIKE 'MajorGroupId'
			AND	c.name NOT LIKE 'MajorGroupBy'
			AND	c.name NOT LIKE 'TeamDesc'		
			AND	c.name NOT LIKE 'StartTime'	
			AND	c.name NOT LIKE 'LineStatus'	
			AND	c.name NOT LIKE 'EndTime'

			EXEC (@Query)
			
			--SELECT '#MinorFlexVars1',* from #MinorFlexVars
		END
	END

	-- --------------------------------------------------------------------------------------------------------------------
	-- Get KPI's for the MAJOR group 
	-- --------------------------------------------------------------------------------------------------------------------
	INSERT INTO @MajorGroup(																																													
			 MajorGroupId																				
			,MajorGroupBy																						
			,StartTime																					
			,EndTime																					
			,LineStatus																					
			,GoodProduct																				
			,TotalProduct																				
			,TotalScrap																					
			,ActualRate																					
			,TargetRate	
			,ScheduleTime	
			,ConvertedCases																			
			,CalendarTime																			
			,IdealRate																					
			,STNU
			,RunningScrap																					
			,StartingScrap																				
			,MSU																						
			,TotalCases																				
			--,SafetyTrigg																				
			--,QualityTrigg																				
			,TotalStops																					
			,Duration																					
			,TotalUpdDowntime																			
			,TotalUpdStops																				
			,MinorStops																					
			,ProcFailures																				
			,MajorStops																					
			,Uptime																					
			,R0																							
			,R2																							
			,BreakDown																
			,ACPStops
			,RepairTimeT																				
			,FalseStarts0
			,FalseStartsT
			,Survival240Rate
			,EditedStops
			,TotalPlannedStops																			
			,TotalStarvedStops																			
			,TotalBlockedStops																			
			,TotalStarvedDowntime																		
			,TotalBlockedDowntime
			,Survival210Rate
			,R210																						
			,R240
			,TotalPlannedDowntime
			,IdleTime					
			,ExcludedTime			
			,MAchineStopsDay					
			,StatCases		
			,StatFactor)																		
		SELECT																							
			mg.MajorGroupId																																		
			,mg.MajorGroupBy
			,mg.StartTime					
			,mg.EndTime		
			,mg.LineStatus			
			,SUM(GoodProduct)
			,SUM(TotalProduct)
			,SUM(TotalScrap)
			,SUM(mg.ScheduleTime * mg.ActualRate)
			,SUM(mg.ScheduleTime * mg.TargetRate)
			,SUM(ScheduleTime)
			,SUM(ConvertedCases)
			,SUM(DATEDIFF (dd,mg.StartTime, mg.EndTime) * 1440)
			,SUM(mg.ScheduleTime * mg.IdealRate)
			,SUM(STNU)
			,SUM(RunningScrap)
			,SUM(StartingScrap)
			,SUM(MSU)
			,SUM(TotalCases)
			--,SUM(SafetyTrigg)
			--,SUM(QualityTrigg)
			,SUM(TotalStops)
			,SUM(Duration)
			,SUM(TotalUpdDowntime)
			,SUM(TotalUpdStops)
			,SUM(MinorStops)
			,SUM(ProcFailures)
			,SUM(MajorStops)
			,SUM(Uptime)
			,AVG(R0)
			,AVG(R2)
			,SUM(BreakDown)
			,SUM(ACPStops)
			,SUM(RepairTimeT)
			,SUM(FalseStarts0)
			,SUM(FalseStartsT)
			,SUM(Survival240Rate)
			,SUM(EditedStops)
			,SUM(TotalPlannedStops)
			,SUM(TotalStarvedStops)
			,SUM(TotalBlockedStops)
			,SUM(TotalStarvedDowntime)
			,SUM(TotalBlockedDowntime)
			,SUM(Survival210Rate)
			,SUM(R210)
			,SUM(R240)
			,SUM(TotalPlannedDowntime)
			,SUM(IdleTime)					
			,SUM(ExcludedTime)	
			,SUM(MAchineStopsDay)
			,SUM(StatCases)
			,AVG(StatFactor)
		FROM @MinorGroup mg
		JOIN @ProdDay pd ON pd.PLId = mg.MinorGroupId
							AND mg.EndTime <= pd.EndTime
							AND mg.StartTime >= pd.StartTime
		GROUP BY 	
			mg.MajorGroupId
			,mg.MajorGroupBy
			,mg.StartTime					
			,mg.EndTime			
			,mg.LineStatus

		UPDATE @MajorGroup
			SET TargetRate = CASE 
								WHEN TargetRate = 0 OR TargetRate IS NULL THEN 0
								WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
								ELSE TargetRate / ScheduleTime
								END,
				ActualRate = CASE 
								WHEN ActualRate = 0 OR ActualRate IS NULL THEN 0
								WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
								ELSE ActualRate / ScheduleTime
								END,
				IdealRate = CASE 
								WHEN IdealRate = 0 OR IdealRate IS NULL THEN NULL
								WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
								ELSE IdealRate / ScheduleTime
								END

		UPDATE  @MajorGroup
		SET	Availability		= CASE WHEN (Convert(float,Uptime) + Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime)) = 0 THEN 0  
									 ELSE Convert(float,Uptime) / (Convert(float,Uptime) + Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime))  
									END

		UPDATE  @MajorGroup
		SET	ScrapPer			= CASE	WHEN TotalProduct > 0 
									THEN (CONVERT(FLOAT,TotalProduct) - CONVERT(FLOAT,GoodProduct)) / CONVERT(FLOAT,TotalProduct) 
									ELSE 0
									END,
			RunningScrapPer		= CASE WHEN TotalProduct = 0 
									THEN 0 
									ELSE 100 * (RunningScrap / convert(float,TotalProduct))
									END,
			StartingScrapPer	= CASE WHEN TotalProduct = 0 
									THEN 0 
									ELSE 100 * (StartingScrap / convert(float,TotalProduct))
									END,
			PRAvailability		= CASE 
									WHEN ((Convert(float,TotalProduct) - Convert(float,isnull(StartingScrap,0))) = 0 or ( Convert(float,Uptime) +  Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime) ) = 0) 
									THEN 0  
									Else 100 * Convert(float,Availability) * (1 - (Convert(float,isnull(RunningScrap,0)) / (Convert(float,TotalProduct)-Convert(float,isnull(StartingScrap,0))))) 
									END,
			CapacityUtilization = CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0')) = 0 or (CONVERT(FLOAT,ISNULL(TargetRate,'0'))= 0 OR CONVERT(FLOAT,IdealRate)= 0)) THEN  0  
									ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,CASE WHEN (IdealRate = 0 ) THEN TargetRate ELSE IdealRate END))/(CONVERT(FLOAT,CalendarTime)) * 100.00 END,
			RateUtilization		= CASE WHEN (CONVERT(FLOAT,ISNULL(GoodProduct,'0')) = 0 OR (CONVERT(FLOAT,ISNULL(TargetRate,'0')) = 0 OR CONVERT(FLOAT,IdealRate) = 0)) THEN 0  
									ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,CASE WHEN (IdealRate = 0 ) THEN TargetRate ELSE IdealRate END))/(CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,TargetRate )) * 100.00   END,
		
			RoomLoss			= CASE  WHEN (CONVERT(FLOAT,ISNULL(GoodProduct,'0'))) = 0 THEN 0 ELSE (1.00-(ConvertedCases/CONVERT(FLOAT,GoodProduct))) * 100 END  ,
		
			ScheduleUtilization = CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0'))) = 0  THEN 0 ELSE (CONVERT(FLOAT,ScheduleTime) / CONVERT(FLOAT,CalendarTime)) * 100    END,
			DownMSU				= CASE  WHEN (CONVERT(FLOAT,ISNULL(MSU,'0'))) = 0  THEN 0 ELSE ((TotalPlannedDowntime + TotalUpdDowntime) / MSU ) END,
			StopsMSU			= CASE  WHEN (CONVERT(FLOAT,ISNULL(MSU,'0'))) = 0  THEN 0 ELSE (TotalStops / MSU ) END,
			RunEff				= CASE    
										WHEN (CONVERT(FLOAT,ISNULL(ScheduleTime,'0')) - CONVERT(FLOAT,ISNULL(TotalPlannedDowntime,'0')) = 0 OR (CONVERT(FLOAT,ISNULL(TargetRate,'0')) = 0)) 
										THEN 0  
										ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,TargetRate)) / (CONVERT(FLOAT,ISNULL(ScheduleTime,'0')) - CONVERT(FLOAT,ISNULL(TotalPlannedDowntime,'0'))) * 100  
										END,
			MTBF				= CASE WHEN TotalStops = 0 
									THEN Uptime
									ELSE Uptime/TotalStops 
									END,
			MTBFUpd				= CASE WHEN TotalUpdStops = 0 
									THEN Uptime 
									ELSE Uptime/TotalUpdStops END,
			MTTR				= CASE WHEN TotalStops=0 
									THEN Duration 
									ELSE Duration / TotalStops END,
			--UpsDTPRLoss			= CASE WHEN ScheduleTime=0 THEN 0 ELSE 100 * ISNULL(TotalUpdDowntime,0) / CONVERT(FLOAT,ScheduleTime) END,
			--PlannedDTPRLoss		= CASE WHEN ScheduleTime=0 THEN 0 ELSE 100 * ISNULL((Duration - TotalUpdDowntime),0) / CONVERT(FLOAT,ScheduleTime) END,
			MTTRUpd				= CASE 
									WHEN TotalUpdDowntime > 0 AND TotalUpdStops > 0 THEN TotalUpdDowntime / CONVERT(FLOAT,TotalUpdStops)	
									WHEN TotalUpdStops <= 0 THEN TotalUpdDowntime	
									ELSE 0
									END,
			UpdDownPerc			= CASE WHEN Duration = 0 
									THEN 0 
									ELSE (TotalUpdDowntime / Duration) END,
			StopsDay			= Case When Convert(Float,ScheduleTime) <= 0 Then TotalStops  
									Else Convert(Float,TotalStops) * 1440 / (Convert(Float,ScheduleTime))End  ,
			ProcFailuresDay		= Case When Convert(Float,ScheduleTime) <= 0 Then ProcFailures  
									Else Convert(Float,ProcFailures) * 1440 / (Convert(Float,ScheduleTime))End ,
			Availability_Unpl_DT = CASE WHEN (Uptime + TotalUpdDowntime) = 0 THEN 0 ELSE Uptime /(Uptime + TotalUpdDowntime) END,	
			Availability_Planned_DT = CASE WHEN (Uptime + (Duration - TotalUpdDowntime)) = 0 THEN 0 ELSE Uptime /(Uptime + (Duration - TotalUpdDowntime)) END,	
			Availability_Total_DT =	CASE WHEN (Uptime + Duration) = 0 THEN 0 ELSE Uptime /(Uptime + Duration) END ,	
			MTBS				= CASE WHEN TotalStops = 0 THEN 0 ELSE Uptime/ TotalStops END,
			ACPStopsDay			= CASE WHEN CONVERT(FLOAT,ScheduleTime) < 1440 THEN AcpStops   
									ELSE (CONVERT(FLOAT,AcpStops) * 1440) / CONVERT(FLOAT,ScheduleTime)
									END,  
			FalseStarts0Per 	= CASE WHEN Cast(TotalStops AS FLOAT) = 0 THEN 0  ELSE Cast(FalseStarts0 AS FLOAT) * 100 / Cast(TotalStops As Float) End, 
			FalseStartsTPer		= CASE WHEN Cast(TotalStops AS FLOAT) = 0 THEN 0  ELSE Cast(FalseStartsT AS FLOAT) * 100 / Cast(TotalStops As Float) End	,
			Survival240RatePer	= CASE WHEN ISNULL(ScheduleTime,0) = 0 THEN 0 ELSE (CONVERT(FLOAT,Survival240Rate)/(CONVERT(FLOAT,ScheduleTime)/240)) *100 END  ,
			Survival210RatePer	= CASE WHEN ISNULL(ScheduleTime,0) = 0 THEN 0 ELSE (CONVERT(FLOAT,Survival210Rate)/(CONVERT(FLOAT,ScheduleTime)/210)) *100 END  ,
			EditedStopsPer		= CASE WHEN Convert(float,TotalStops) = 0 THEN 0 ELSE 100.0 * (Convert(float,EditedStops) / Convert(FLOAT,TotalStops)) END,
			TotalUpdStopDay		= Case When Convert(Float,ScheduleTime) <= 0 Then TotalUpdStops  ELSE (TotalUpdStops * 1440) / ScheduleTime END  ,
			StopsBDSDay			= Case When Convert(Float,ScheduleTime) <= 0 Then BreakDown  ELSE (BreakDown * 1440) / ScheduleTime END,
			TotalPlannedStopsDay = Case When Convert(Float,ScheduleTime) <= 0 Then TotalPlannedStops  
									Else Convert(Float,TotalPlannedStops) * 1440 / (Convert(Float,ScheduleTime))End,
			MajorStopsDay		= Case When Convert(Float,ScheduleTime) <= 0 Then  MajorStops  ELSE ( MajorStops * 1440) / ScheduleTime END,
			MinorStopsDay		= Case When Convert(Float,ScheduleTime) <= 0 Then  MinorStops  ELSE ( MinorStops * 1440) / ScheduleTime END ,
			Area4LossPer		= CASE WHEN @SpecialCasesFlag = 1 THEN 
										CASE WHEN Convert(FLOAT,TotalProduct) <= 0 THEN 0 ELSE (((Convert(float,TotalProduct) - Convert(float,TotalScrap)) - Convert(float,ConvertedCases)) / Convert(float,TotalProduct)) * 100 END
								  ELSE '' END
	

			UPDATE @MajorGroup
				SET R2 = CONVERT(FLOAT,((CONVERT(FLOAT,TotalStops) - CONVERT(FLOAT,FalseStartsT)) + 1) / (CONVERT(FLOAT,TotalStops) + 1))

			UPDATE @MajorGroup 
				SET R0 =  CONVERT(FLOAT,((CONVERT(FLOAT,TotalStops) - CONVERT(FLOAT,FalseStarts0)) + 1) / (CONVERT(FLOAT,TotalStops) + 1))

			IF (SELECT COUNT(*) FROM @MinorGroup WHERE PR = 0 AND ScheduleTime > 0) > 1
			BEGIN
				UPDATE maj
					SET PR = ( SELECT CASE 
									WHEN SUM(StatFactor) = 0 
									THEN 0
									ELSE  SUM(PR * ScheduleTime * (CASE WHEN TargetRate > ActualRate THEN TargetRate ELSE ActualRate END) * (StatFactor / 1000)) / SUM(ScheduleTime * (CASE WHEN TargetRate > ActualRate THEN TargetRate ELSE ActualRate END) * (StatFactor / 1000))
									END
								FROM @MinorGroup
							 )
				FROM @MajorGroup maj
			END
			ELSE
			BEGIN
				UPDATE maj
				SET PR = (	SELECT CASE 
								   WHEN SUM(MSU) = 0 OR SUM(MSU / PR) = 0 
								   		THEN 0 
								   ELSE (SUM(MSU * 1000) / SUM((MSU * 1000) / PR)) 
								   END 
										
									FROM @MinorGroup mg
									WHERE	maj.MajorGroupBy = mg.MajorGroupBy
									AND PR > 0 AND MSU > 0)
									
				FROM @MajorGroup maj
			END


			UPDATE maj
			SET PR_Excl_PRInDev = (SELECT CASE WHEN SUM(min.ScheduleTimeExcDev) = 0 THEN 0 ELSE 100 * (SUM(min.NetProductionExcDev) / SUM(min.ScheduleTimeExcDev)) END FROM @MinorGroup min WHERE min.MajorGroupBy = maj.MajorGroupBy)
			FROM @MajorGroup maj

			UPDATE @MajorGroup
				SET PRRateLossTgtRate = (SELECT CASE WHEN TargetRate < ActualRate THEN ActualRate ELSE TargetRate END)

			UPDATE @MajorGroup
				SET PercentPRRateLoss = (CASE WHEN ScheduleTime > 0 and TargetRate > 0 and PRRateLossTgtRate > 0 and StatFactor > 0
													THEN ( ( ((PRRateLossTgtRate/StatFactor) - IIF(Uptime > 0 ,(CASE WHEN TotalProduct = 0 AND GoodProduct > 0 THEN  (GoodProduct/StatFactor) ELSE ((TotalProduct/StatFactor) - (StartingScrap/StatFactor)) END) / Uptime, 0)) * Uptime  ) / (PRRateLossTgtRate / StatFactor) ) / (ScheduleTime)  
													ELSE 0
												END) * 100
			
			UPDATE min
				SET PRLossDivisor = CASE WHEN PR > 0 AND MSU > 0
												 THEN MSU / PR
												 ELSE CASE WHEN StatFactor > 0
														   THEN ScheduleTime * (TargetRate/StatFactor)
														   ELSE 0 END
												 END	
			FROM @MinorGroup min

			UPDATE mg
				SET PlannedDTPRLoss = (SELECT CASE WHEN SUM(min.PRLossDivisor) > 0 
												   THEN (SUM(min.PlannedDTPRLoss * min.PRLossDivisor) / SUM(min.PRLossDivisor))
												   ELSE 0
												   END
										FROM @MinorGroup min WHERE mg.MajorGroupBy = min.MajorGroupBy)
			FROM @MajorGroup mg

			UPDATE mg
				SET UpsDTPRLoss = (SELECT CASE WHEN SUM(min.PRLossDivisor) > 0 
												   THEN (SUM(min.UpsDTPRLoss * min.PRLossDivisor) / SUM(min.PRLossDivisor))
												   ELSE 0
												   END
										FROM @MinorGroup min WHERE mg.MajorGroupBy = min.MajorGroupBy)
			FROM @MajorGroup mg
			

			UPDATE @MajorGroup
				SET PRLossScrap = CASE WHEN ScheduleTime <= 0 OR TargetRate <= 0 THEN 0 ELSE 100 * ISNULL((RunningScrap / TargetRate),0) / CONVERT(FLOAT,ScheduleTime) END
			
				
	--SELECT '@MinorGroup',* from @MinorGroup
	--SELECT '@MajorGroup',* FROM @MajorGroup
	INSERT INTO #MajorFlexVars(
			MajorGroupId																				
			,MajorGroupBy																						
			,StartTime																					
			,EndTime																					
			,LineStatus			)	
	SELECT  MajorGroupId																				
			,MajorGroupBy																						
			,StartTime																					
			,EndTime																					
			,LineStatus				
	FROM @MajorGroup

	SET @Query = ''

	SELECT @Query = @Query + ' UPDATE #MajorFlexVars ' + CHAR(13) +
			' SET #MajorFlexVars.[' + c.name + '] = (SELECT SUM(ISNULL(CONVERT(FLOAT, [' + c.name + ']),0)) ' + CHAR(13) +
			' FROM #MinorFlexVars mfv ' + CHAR(13) +
			' WHERE mfv.MajorGroupBy = #MajorFlexVars.MajorGroupBy );' + CHAR(13) 
		from tempdb.sys.columns c
		where object_id = object_id('tempdb..#MinorFlexVars')
		AND	c.name NOT LIKE 'Idx'
		AND	c.name NOT LIKE 'MinorGroupId'
		AND	c.name NOT LIKE 'MinorGroupBy'
		AND	c.name NOT LIKE 'MajorGroupId'
		AND	c.name NOT LIKE 'MajorGroupBy'
		AND	c.name NOT LIKE 'TeamDesc'		
		AND	c.name NOT LIKE 'StartTime'	
		AND	c.name NOT LIKE 'LineStatus'	
		AND	c.name NOT LIKE 'EndTime'

	EXEC (@Query)
	--select '#MajorFlexVars',* from #MajorFlexVars
END

--=====================================================================================================================
-- Total Calculations for Non Grooming sites
-- --------------------------------------------------------------------------------------------------------------------
IF @LineGroupFlag = 0
BEGIN
	IF @strMajorGroupBy = 'Line' OR @strMajorGroupBy = 'ProdDay'  OR @strMajorGroupBy = 'WorkCell' 
	BEGIN	
		IF ((SELECT COUNT(*) FROM @Equipment) > 1)
		BEGIN
			INSERT INTO @TotalGroup(
					--StartTime					
					--,EndTime					
					GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime
					,CalendarTime			
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,ConvertedCases
					,IdleTime					
					,ExcludedTime						
					,MAchineStopsDay			
					,StatCases		
					,StatFactor)				
			
				SELECT			
					--StartTime					
					--,EndTime					
					SUM(GoodProduct)
					,SUM(TotalProduct)
					,SUM(TotalScrap)
					,SUM(ScheduleTime * ActualRate)
					,SUM(ScheduleTime * TargetRate)
					,SUM(ScheduleTime)
					--,(SUM(DATEDIFF (dd,StartTime, EndTime)) * 1440)
					,SUM(CASE WHEN CalendarTime IS NOT NULL THEN CalendarTime ELSE DATEDIFF(dd,StartTime, EndTime) * 1440 END)
					,AVG(ScrapPer)
					,SUM(ScheduleTime * IdealRate)
					,SUM(STNU)
					,AVG(CapacityUtilization)
					,AVG(ScheduleUtilization)
					,AVG(Availability)
					,AVG(PRAvailability)
					,SUM(StopsMSU)
					,SUM(DownMSU)
					,AVG(RunningScrapPer)
					,SUM(RunningScrap)
					,AVG(StartingScrapPer)
					,SUM(StartingScrap)
					,SUM(RoomLoss)
					,SUM(MSU)
					,SUM(TotalCases)
					,AVG(RateUtilization)
					,AVG(RunEff)
					--,SUM(SafetyTrigg)
					--,SUM(QualityTrigg)
					,SUM(VSNetProduction)
					,SUM(VSPR)
					,AVG(VSPRLossPer)
					,SUM(TotalStops)
					,SUM(Duration)
					,SUM(TotalUpdDowntime)
					,SUM(TotalUpdStops)
					,SUM(MinorStops)
					,SUM(ProcFailures)
					,SUM(MajorStops)
					,SUM(Uptime)
					,AVG(MTBF)
					,AVG(MTBFUpd)
					,AVG(MTTR)
					,AVG(UpsDTPRLoss)
					,AVG(R0)
					,AVG(R2)
					,SUM(BreakDown)
					,SUM(MTTRUpd)
					,AVG(UpdDownPerc)
					,AVG(StopsDay)
					,AVG(ProcFailuresDay)
					,AVG(Availability_Unpl_DT)
					,AVG(Availability_Total_DT)
					,AVG(MTBS)
					,SUM(ACPStops)
					,SUM(ACPStopsDay)
					,SUM(RepairTimeT)
					,SUM(FalseStarts0)
					,AVG(FalseStarts0Per)
					,SUM(FalseStartsT)
					,SUM(FalseStartsTPer)
					,SUM(Survival240Rate)
					,AVG(Survival240RatePer)
					,SUM(EditedStops)
					,AVG(EditedStopsPer)
					,SUM(TotalUpdStopDay)
					,SUM(StopsBDSDay)
					,SUM(TotalPlannedStops)
					,AVG(TotalPlannedStopsDay)
					,AVG(MajorStopsDay)
					,AVG(MinorStopsDay)
					,SUM(TotalStarvedStops)
					,SUM(TotalBlockedStops)
					,SUM(TotalStarvedDowntime)
					,SUM(TotalBlockedDowntime)
					,SUM(VSScheduledTime)
					,SUM(VSPRLossPlanned)
					,SUM(VSPRLossUnplanned)
					,SUM(VSPRLossBreakdown)
					,SUM(Survival210Rate)
					,SUM(Survival210RatePer)
					,SUM(R210)
					,SUM(R240)
					,AVG(Availability_Planned_DT)
					,SUM(TotalPlannedDowntime)
					,AVG(PlannedDTPRLoss)
					,SUM(ConvertedCases)
					,SUM(IdleTime)					
					,SUM(ExcludedTime)				
					,AVG(MAchineStopsDay)	
					,SUM(StatCases)		
					,AVG(StatFactor)
				FROM @MajorGroup

				UPDATE @TotalGroup
					SET TargetRate = CASE 
										WHEN TargetRate = 0 OR TargetRate IS NULL THEN 0
										WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
										ELSE TargetRate / ScheduleTime
										END,
						ActualRate = CASE 
										WHEN ActualRate = 0 OR ActualRate IS NULL THEN 0
										WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
										ELSE ActualRate / ScheduleTime
										END,
						IdealRate = CASE 
										WHEN IdealRate = 0 OR IdealRate IS NULL THEN NULL
										WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
										ELSE IdealRate / ScheduleTime
										END
				--UPDATE @TotalGroup
				--	SET StatFactor = CASE 
				--						WHEN StatFactor = 0 OR StatFactor IS NULL THEN 0
				--						ELSE GoodProduct / StatFactor
				--						END
				--si ideal rate = 0 o null usar target rate
				UPDATE  @TotalGroup
					SET	Availability		= CASE WHEN (Convert(float,Uptime) + Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime)) = 0 THEN 0  
											 ELSE Convert(float,Uptime) / (Convert(float,Uptime) + Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime)) 
											END

				UPDATE  @TotalGroup
					SET	ScrapPer			= CASE	WHEN TotalProduct > 0 
												THEN 100 * (CONVERT(FLOAT,TotalScrap) / CONVERT(FLOAT,TotalProduct))
												ELSE 0
												END,
						RunningScrapPer		= CASE WHEN TotalProduct = 0 
												THEN 0 
												ELSE 100 * (RunningScrap / convert(float,TotalProduct))
												END,
						StartingScrapPer	= CASE WHEN TotalProduct = 0 
												THEN 0 
												ELSE 100 * (StartingScrap / convert(float,TotalProduct))
												END,
						PRAvailability		= CASE 
												WHEN ((Convert(float,TotalProduct) - Convert(float,isnull(StartingScrap,0))) = 0 or ( Convert(float,Uptime) +  Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime) ) = 0) 
												THEN 0  
												Else 100 * Convert(float,Availability) * (1 - (Convert(float,isnull(RunningScrap,0)) / (Convert(float,TotalProduct)-Convert(float,isnull(StartingScrap,0))))) 
												END,
						CapacityUtilization = CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0')) = 0 or (CONVERT(FLOAT,ISNULL(TargetRate,'0'))= 0 OR CONVERT(FLOAT,IdealRate)= 0)) THEN  0  
												ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,CASE WHEN (IdealRate = 0 ) THEN TargetRate ELSE IdealRate END))/(CONVERT(FLOAT,CalendarTime)) * 100.00 END,
						RateUtilization		= CASE WHEN (CONVERT(FLOAT,ISNULL(GoodProduct,'0')) = 0 OR (CONVERT(FLOAT,ISNULL(TargetRate,'0')) = 0 OR CONVERT(FLOAT,IdealRate) = 0)) THEN 0  
												ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,CASE WHEN (IdealRate = 0 ) THEN TargetRate ELSE IdealRate END))/(CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,TargetRate)) * 100.00   END,
						RoomLoss			= CASE WHEN (CONVERT(FLOAT,ISNULL(GoodProduct,'0'))) = 0 THEN 0 ELSE (1 - (CONVERT(FLOAT,ConvertedCases) / CONVERT(FLOAT,GoodProduct))) * 100 END,
		
						ScheduleUtilization = CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0'))) = 0  THEN 0 ELSE (CONVERT(FLOAT,ScheduleTime) / CONVERT(FLOAT,CalendarTime)) * 100    END,
						DownMSU				= CASE  WHEN (CONVERT(FLOAT,ISNULL(MSU,'0'))) = 0  THEN 0 ELSE ((TotalPlannedDowntime + TotalUpdDowntime) / MSU ) END,
						StopsMSU			= CASE  WHEN (CONVERT(FLOAT,ISNULL(MSU,'0'))) = 0  THEN 0 ELSE (TotalStops / MSU ) END,
						RunEff				= CASE    
											WHEN (CONVERT(FLOAT,ISNULL(ScheduleTime,'0')) - CONVERT(FLOAT,ISNULL(TotalPlannedDowntime,'0')) = 0 OR (CONVERT(FLOAT,ISNULL(TargetRate,'0')) = 0)) 
											THEN 0  
											ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,TargetRate)) / (CONVERT(FLOAT,ISNULL(ScheduleTime,'0')) - CONVERT(FLOAT,ISNULL(TotalPlannedDowntime,'0'))) * 100  
											END,
						MTBF				= CASE WHEN TotalStops = 0 
												THEN Uptime
												ELSE Uptime/TotalStops 
												END,
						MTBFUpd				= CASE WHEN TotalUpdStops = 0 
												THEN Uptime 
												ELSE Uptime/TotalUpdStops END,
						MTTR				= CASE WHEN TotalStops=0 
												THEN Duration 
												ELSE Duration / TotalStops END,
						UpsDTPRLoss			= CASE WHEN ScheduleTime=0 THEN 0 ELSE 100 * ISNULL(TotalUpdDowntime,0) / CONVERT(FLOAT,ScheduleTime) END,
						PlannedDTPRLoss		= CASE WHEN ScheduleTime=0 THEN 0 ELSE 100 * ISNULL((Duration - TotalUpdDowntime),0) / CONVERT(FLOAT,ScheduleTime) END,
						MTTRUpd				= CASE 
												WHEN TotalUpdDowntime > 0 AND TotalUpdStops > 0 THEN TotalUpdDowntime / CONVERT(FLOAT,TotalUpdStops)	
												WHEN TotalUpdStops <= 0 THEN TotalUpdDowntime	
												ELSE 0
												END,
						UpdDownPerc			= CASE WHEN Duration = 0 
												THEN 0 
												ELSE 100 * (TotalUpdDowntime / Duration) END,
						StopsDay			= Case When Convert(Float,ScheduleTime) <= 0 Then TotalStops  
												Else Convert(Float,TotalStops) * 1440 / (Convert(Float,ScheduleTime))End  ,
						ProcFailuresDay		= Case When Convert(Float,ScheduleTime) <= 0 Then ProcFailures  
												Else Convert(Float,ProcFailures) * 1440 / (Convert(Float,ScheduleTime))End ,
						Availability_Unpl_DT = CASE WHEN (Uptime + TotalUpdDowntime) = 0 THEN 0 ELSE Uptime /(Uptime + TotalUpdDowntime) END,	
						Availability_Planned_DT = CASE WHEN (Uptime + (Duration - TotalUpdDowntime)) = 0 THEN 0 ELSE Uptime /(Uptime + (Duration - TotalUpdDowntime)) END,	
						Availability_Total_DT =	CASE WHEN (Uptime + Duration) = 0 THEN 0 ELSE Uptime /(Uptime + Duration) END ,	
						MTBS				= CASE WHEN TotalStops = 0 THEN 0 ELSE Uptime/ TotalStops END,
						ACPStopsDay			= CASE WHEN CONVERT(FLOAT,ScheduleTime) < 1440 THEN AcpStops   
												ELSE (CONVERT(FLOAT,AcpStops) * 1440) / CONVERT(FLOAT,ScheduleTime)
												END,    
						FalseStarts0Per 	= CASE WHEN Cast(TotalStops AS FLOAT) = 0 THEN 0  ELSE Cast(FalseStarts0 AS FLOAT) * 100 / Cast(TotalStops As Float) End, 
						FalseStartsTPer		= CASE WHEN Cast(TotalStops AS FLOAT) = 0 THEN 0  ELSE Cast(FalseStartsT AS FLOAT) * 100 / Cast(TotalStops As Float) End	,
						Survival240RatePer	= CASE WHEN ISNULL(ScheduleTime,0) = 0 THEN 0 ELSE (CONVERT(FLOAT,Survival240Rate)/(CONVERT(FLOAT,ScheduleTime)/240)) *100 END  ,
						Survival210RatePer	= CASE WHEN ISNULL(ScheduleTime,0) = 0 THEN 0 ELSE (CONVERT(FLOAT,Survival210Rate)/(CONVERT(FLOAT,ScheduleTime)/210)) *100 END  ,
						EditedStopsPer		= CASE WHEN Convert(float,TotalStops) = 0 THEN 0 ELSE 100.0 * (Convert(float,EditedStops) / Convert(FLOAT,TotalStops)) END,
						TotalUpdStopDay		= Case When Convert(Float,ScheduleTime) <= 0 Then TotalUpdStops  ELSE (TotalUpdStops * 1440) / ScheduleTime END  ,
						StopsBDSDay			= Case When Convert(Float,ScheduleTime) <= 0 Then BreakDown  ELSE (BreakDown * 1440) / ScheduleTime END,
						TotalPlannedStopsDay = Case When Convert(Float,ScheduleTime) <= 0 Then TotalPlannedStops  
												Else Convert(Float,TotalPlannedStops) * 1440 / (Convert(Float,ScheduleTime))End,
						MajorStopsDay		= Case When Convert(Float,ScheduleTime) <= 0 Then  MajorStops   ELSE ( MajorStops * 1440) / ScheduleTime END,
						MinorStopsDay		= Case When Convert(Float,ScheduleTime) <= 0 Then  MinorStops  ELSE ( MinorStops * 1440) / ScheduleTime END ,
						Area4LossPer		= CASE WHEN @SpecialCasesFlag = 1 THEN 
												CASE WHEN Convert(FLOAT,TotalProduct) <= 0 THEN 0 ELSE (((Convert(float,TotalProduct) - Convert(float,TotalScrap)) - Convert(float,ConvertedCases)) / Convert(float,TotalProduct)) * 100 END
										  ELSE NULL END
									 
				
				UPDATE @TotalGroup
					SET R2 = CONVERT(FLOAT,((CONVERT(FLOAT,TotalStops) - CONVERT(FLOAT,FalseStartsT)) + 1) / (CONVERT(FLOAT,TotalStops) + 1))

				UPDATE @TotalGroup
					SET R0 =  CONVERT(FLOAT,((CONVERT(FLOAT,TotalStops) - CONVERT(FLOAT,FalseStarts0)) + 1) / (CONVERT(FLOAT,TotalStops) + 1))
				
				
				IF (SELECT COUNT(*) FROM @MajorGroup WHERE PR = 0 AND ScheduleTime > 0) > 1
				BEGIN
					UPDATE tot
						SET PR = ( SELECT CASE 
										WHEN SUM(StatFactor) = 0 
										THEN 0
										ELSE SUM(PR * ScheduleTime * (CASE WHEN TargetRate > ActualRate THEN TargetRate ELSE ActualRate END) * (StatFactor / 1000)) / SUM(ScheduleTime * (CASE WHEN TargetRate > ActualRate THEN TargetRate ELSE ActualRate END) * (StatFactor / 1000))
										END
									FROM @MajorGroup
								 )
					FROM @TotalGroup tot
				END
				ELSE
				BEGIN
					UPDATE @TotalGroup
					SET PR = (	SELECT CASE 
									   WHEN SUM(MSU) = 0 OR SUM(MSU / PR) = 0 
								   			THEN 0 
									   ELSE (SUM(MSU * 1000) / SUM((MSU * 1000) / PR)) 
									   END 
										
										FROM @MajorGroup mg
										WHERE  PR > 0 AND MSU > 0)
				END


 				UPDATE @TotalGroup
					SET PR_Excl_PRInDev = (SELECT CASE WHEN SUM(MSUExcDev) = 0 OR SUM (MSUExcDev / PR_Excl_PRInDev) = 0 THEN 0 ELSE (SUM(MSUExcDev * 1000) / SUM((MSUExcDev * 1000) / PR_Excl_PRInDev)) END FROM @MajorGroup
								WHERE PR_Excl_PRInDev > 0
								  AND MSUExcDev > 0)       
				UPDATE @TotalGroup
					SET PRRateLossTgtRate = (SELECT CASE WHEN TargetRate < ActualRate THEN ActualRate ELSE TargetRate END)
					
				UPDATE @TotalGroup
					SET PercentPRRateLoss = (CASE WHEN ScheduleTime > 0 and TargetRate > 0 and PRRateLossTgtRate > 0 and StatFactor > 0
													THEN ( ( ((PRRateLossTgtRate/StatFactor) - IIF(Uptime > 0 ,(CASE WHEN TotalProduct = 0 AND GoodProduct > 0 THEN  (GoodProduct/StatFactor) ELSE ((TotalProduct/StatFactor) - (StartingScrap/StatFactor)) END) / Uptime, 0)) * Uptime  ) / (PRRateLossTgtRate / StatFactor) ) / (ScheduleTime)  
													ELSE 0
												END) * 100
				IF @IsGrooming = 1
				BEGIN
					UPDATE @TotalGroup
						SET PRLossScrap = CASE WHEN ScheduleTime <= 0 OR TargetRate <= 0 THEN 0 ELSE 100 * ISNULL((TotalScrap / TargetRate),0) / CONVERT(FLOAT,ScheduleTime) END
				END
				ELSE
				BEGIN
					UPDATE @TotalGroup
						SET PRLossScrap = CASE WHEN ScheduleTime <= 0 OR TargetRate <= 0 THEN 0 ELSE 100 * ISNULL((RunningScrap / TargetRate),0) / CONVERT(FLOAT,ScheduleTime) END
					--SELECT '@TotalGroup',* from @TotalGroup
				END

				UPDATE mg
					SET PRLossDivisor = CASE WHEN PR > 0 AND MSU > 0
													 THEN MSU / PR
													 ELSE CASE WHEN ScheduleTime * TargetRate > 0
															   THEN ScheduleTime * TargetRate
															   ELSE 0 END
													 END	
				FROM @MajorGroup mg
		
				UPDATE @TotalGroup
					SET PRLossDivisor = (SELECT SUM(PRLossDivisor) FROM @MajorGroup)

				UPDATE @TotalGroup
					SET PlannedDTPRLoss = (SELECT CASE WHEN SUM(mg.PRLossDivisor) > 0 
													   THEN (SUM(mg.PlannedDTPRLoss * mg.PRLossDivisor) / SUM(mg.PRLossDivisor))
													   ELSE 0
													   END
											FROM @MajorGroup mg)


				UPDATE @TotalGroup
					SET UpsDTPRLoss = (SELECT CASE WHEN SUM(mg.PRLossDivisor) > 0 
													   THEN (SUM(mg.UpsDTPRLoss * mg.PRLossDivisor) / SUM(mg.PRLossDivisor))
													   ELSE 0
													   END
											FROM @MajorGroup mg )




		END
		ELSE IF ((SELECT COUNT(*) FROM @Equipment) = 1)
		BEGIN
			INSERT INTO @TotalGroup(
					 GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,CalendarTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss			
					,ProductionTime				
					,VSTotalUpdDowntime			
					,VSTotalPlannedDowntime		
					,VSBreakdown 				
					,VSTargetRate				
					,EffRateLossDT				
					,PercentPRLossBreakdownDT   
					,PercentPRRateLoss			
					,VSEffRateLossDowntime		
					,VSTotalProduction			
					,NetProduction				
					,Area4LossPer				
					,ConvertedCases				
					,PRRateLossTgtRate			
					,BrandProjectPer			
					,EO_NonShippablePer			
					,LineNotStaffedPer			
					,STNUPer					
					,PRLossScrap				
					,StatUnits					
					,PRLossDivisor	
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev			
					,IdleTime					
					,ExcludedTime						
					,StatCases			
					,TargetRateAdj
					,MAchineStopsDay
					,ProjConstructPerc
					,STNUSchedVarPerc			)

			SELECT  
					 GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,CalendarTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss			
					,ProductionTime				
					,VSTotalUpdDowntime			
					,VSTotalPlannedDowntime		
					,VSBreakdown 				
					,VSTargetRate				
					,EffRateLossDT				
					,PercentPRLossBreakdownDT   
					,PercentPRRateLoss			
					,VSEffRateLossDowntime		
					,VSTotalProduction			
					,NetProduction				
					,Area4LossPer				
					,ConvertedCases				
					,PRRateLossTgtRate			
					,BrandProjectPer			
					,EO_NonShippablePer			
					,LineNotStaffedPer			
					,STNUPer					
					,PRLossScrap				
					,StatUnits					
					,PRLossDivisor		
				    ,PR_Excl_PRInDev	
				    ,NetProductionExcDev
				    ,ScheduleTimeExcDev	
				    ,MSUExcDev			
					,IdleTime					
					,ExcludedTime				
					,StatCases			
					,TargetRateAdj	
					,MAchineStopsDay
					,ProjConstructPerc
					,STNUSchedVarPerc				

			FROM @MajorGroup

				
		END

		-- --------------------------------------------------------------------------------------------------------------------
		-- FLEXIBLE VARIABLES TOTAL
		-- --------------------------------------------------------------------------------------------------------------------
		SET @Query = ''
		INSERT INTO #TotalFlexVars (idx) VALUES(1)
		SELECT @Query = @Query + ' UPDATE #TotalFlexVars ' + CHAR(13) +
			' SET #TotalFlexVars.[' + c.name + '] = (SELECT SUM(ISNULL(CONVERT(FLOAT, [' + c.name + ']),0)) ' + CHAR(13) +
			' FROM #MajorFlexVars )' + CHAR(13) +
			' WHERE #TotalFlexVars.Idx = 1 ;' + CHAR(13)
		from tempdb.sys.columns c
		where object_id = object_id('tempdb..#TotalFlexVars')
		AND	c.name NOT LIKE 'Idx'

		EXEC (@Query)

		--SELECT '#TotalFlexVars',* FROM #TotalFlexVars
	END
END
ELSE 
BEGIN
	IF @strMajorGroupBy = 'Line'  
	BEGIN
		IF ((SELECT COUNT(*) FROM @Equipment WHERE YLineFlag = 1) > 1)
		BEGIN
			
			INSERT INTO @TotalGroup(
					--StartTime					
					--,EndTime					
					GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime
					,CalendarTime			
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer					
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss
					,ConvertedCases
					,IdleTime					
					,ExcludedTime						
					,MAchineStopsDay			
					,StatCases		)				
		
				SELECT			
					--StartTime					
					--,EndTime					
					SUM(GoodProduct)
					,SUM(TotalProduct)
					,SUM(TotalScrap)
					,SUM(ScheduleTime * ActualRate)
					,SUM(ScheduleTime * TargetRate)
					,SUM(ScheduleTime)
					--,(SUM(DATEDIFF (dd,StartTime, EndTime)) * 1440)
					,SUM(CASE WHEN CalendarTime IS NOT NULL THEN CalendarTime ELSE DATEDIFF(dd,mg.StartTime, mg.EndTime) * 1440 END)
					,AVG(ScrapPer)
					,SUM(ScheduleTime * IdealRate)
					,SUM(STNU)
					,AVG(CapacityUtilization)
					,AVG(ScheduleUtilization)
					,AVG(Availability)
					,AVG(PRAvailability)
					,SUM(StopsMSU)
					,SUM(DownMSU)
					,AVG(RunningScrapPer)
					,SUM(RunningScrap)
					,AVG(StartingScrapPer)
					,SUM(StartingScrap)
					,SUM(RoomLoss)
					,SUM(MSU)
					,SUM(TotalCases)
					,AVG(RateUtilization)
					,AVG(RunEff)
					--,SUM(SafetyTrigg)
					--,SUM(QualityTrigg)
					,SUM(VSNetProduction)
					,SUM(VSPR)
					,AVG(VSPRLossPer)
					,SUM(TotalStops)
					,SUM(Duration)
					,SUM(TotalUpdDowntime)
					,SUM(TotalUpdStops)
					,SUM(MinorStops)
					,SUM(ProcFailures)
					,SUM(MajorStops)
					,SUM(Uptime)
					,AVG(MTBF)
					,AVG(MTBFUpd)
					,AVG(MTTR)
					,AVG(UpsDTPRLoss)
					,AVG(R0)
					,AVG(R2)
					,SUM(BreakDown)
					,SUM(MTTRUpd)
					,AVG(UpdDownPerc)
					,AVG(StopsDay)
					,AVG(ProcFailuresDay)
					,AVG(Availability_Unpl_DT)
					,AVG(Availability_Total_DT)
					,AVG(MTBS)
					,SUM(ACPStops)
					,SUM(ACPStopsDay)
					,SUM(RepairTimeT)
					,SUM(FalseStarts0)
					,AVG(FalseStarts0Per)
					,SUM(FalseStartsT)
					,SUM(FalseStartsTPer)
					,SUM(Survival240Rate)
					,AVG(Survival240RatePer)
					,SUM(EditedStops)
					,AVG(EditedStopsPer)
					,SUM(TotalUpdStopDay)
					,SUM(StopsBDSDay)
					,SUM(TotalPlannedStops)
					,AVG(TotalPlannedStopsDay)
					,AVG(MajorStopsDay)
					,AVG(MinorStopsDay)
					,SUM(TotalStarvedStops)
					,SUM(TotalBlockedStops)
					,SUM(TotalStarvedDowntime)
					,SUM(TotalBlockedDowntime)
					,SUM(VSScheduledTime)
					,SUM(VSPRLossPlanned)
					,SUM(VSPRLossUnplanned)
					,SUM(VSPRLossBreakdown)
					,SUM(Survival210Rate)
					,SUM(Survival210RatePer)
					,SUM(R210)
					,SUM(R240)
					,AVG(Availability_Planned_DT)
					,SUM(TotalPlannedDowntime)
					,AVG(PlannedDTPRLoss)
					,SUM(ConvertedCases)
					,SUM(IdleTime)					
					,SUM(ExcludedTime)				
					,AVG(MAchineStopsDay)	
					,SUM(StatCases)		
				FROM @MajorGroup mg
				JOIN @Equipment e ON e.PLId = mg.MajorGroupId
				WHERE e.YLineFlag = 1
				
				UPDATE @TotalGroup
					SET TargetRate = CASE 
										WHEN TargetRate = 0 OR TargetRate IS NULL THEN 0
										WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
										ELSE TargetRate / ScheduleTime
										END,
						ActualRate = CASE 
										WHEN ActualRate = 0 OR ActualRate IS NULL THEN 0
										WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
										ELSE ActualRate / ScheduleTime
										END,
						IdealRate = CASE 
										WHEN IdealRate = 0 OR IdealRate IS NULL THEN NULL
										WHEN ScheduleTime = 0 OR ScheduleTime IS NULL THEN 0
										ELSE IdealRate / ScheduleTime
										END
				--si ideal rate = 0 o null usar target rate
			
				UPDATE  @TotalGroup
					SET	Availability		= CASE WHEN (Convert(float,Uptime) + Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime)) = 0 THEN 0  
											 ELSE Convert(float,Uptime) / (Convert(float,Uptime) + Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime)) 
											END
		
				UPDATE  @TotalGroup
					SET	ScrapPer			= CASE	WHEN TotalProduct > 0 
												THEN 100 * (CONVERT(FLOAT,TotalScrap) / CONVERT(FLOAT,TotalProduct))
												ELSE 0
												END,
						RunningScrapPer		= CASE WHEN TotalProduct = 0 
												THEN 0 
												ELSE 100 * (RunningScrap / convert(float,TotalProduct))
												END,
						StartingScrapPer	= CASE WHEN TotalProduct = 0 
												THEN 0 
												ELSE 100 * (StartingScrap / convert(float,TotalProduct))
												END,
						PRAvailability		= CASE 
												WHEN ((Convert(float,TotalProduct) - Convert(float,isnull(StartingScrap,0))) = 0 or ( Convert(float,Uptime) +  Convert(float,TotalPlannedDowntime) + Convert(float,TotalUpdDowntime) ) = 0) 
												THEN 0  
												Else 100 * Convert(float,Availability) * (1 - (Convert(float,isnull(RunningScrap,0)) / (Convert(float,TotalProduct)-Convert(float,isnull(StartingScrap,0))))) 
												END,
						--CapacityUtilization = CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0')) = 0 or (CONVERT(FLOAT,ISNULL(TargetRate,'0'))= 0 OR CONVERT(FLOAT,IdealRate)= 0)) THEN  0  
						--						ELSE (CONVERT(FLOAT,StatCases) / CONVERT(FLOAT,CASE WHEN (IdealRate = 0 ) THEN TargetRate ELSE IdealRate END))/(CONVERT(FLOAT,CalendarTime)) * 100.00 END,

						CapacityUtilization = (SELECT  CASE  WHEN (CONVERT(FLOAT,SUM(ISNULL(mg.CalendarTime,DATEDIFF(dd,mg.StartTime, mg.EndTime) * 1440))) = 0 or (SUM(CONVERT(FLOAT,ISNULL(mg.TargetRate,'0')))= 0 OR SUM(CONVERT(FLOAT,mg.IdealRate))= 0)) THEN  0  
												ELSE (CONVERT(FLOAT,SUM(mg.GoodProduct)) / CONVERT(FLOAT,CASE WHEN ((SUM(mg.IdealRate * mg.ScheduleTime) / SUM(mg.ScheduleTime)) = 0 ) THEN (SUM(mg.TargetRate * mg.ScheduleTime) / SUM(mg.ScheduleTime)) ELSE (SUM(mg.IdealRate * mg.ScheduleTime) / SUM(mg.ScheduleTime)) END))/(CONVERT(FLOAT,SUM(ISNULL(mg.CalendarTime,DATEDIFF(dd,mg.StartTime, mg.EndTime) * 1440)))) * 100.00 END
												FROM @MajorGroup mg
									            JOIN @Equipment e ON e.PLId = mg.MajorGroupId
												WHERE e.isLeg = 1),

						RateUtilization		= (SELECT  CASE WHEN SUM(mg.StatCases) <= 0 
													   THEN 0 
													   ELSE SUM(mg.RateUtilization * mg.StatCases) / SUM(mg.StatCases)														 
													   END
												FROM @MajorGroup mg
									            JOIN @Equipment e ON e.PLId = mg.MajorGroupId
												WHERE e.YLineFlag = 1),
										
						RoomLoss			= CASE WHEN (CONVERT(FLOAT,ISNULL(GoodProduct,'0'))) = 0 THEN 0 ELSE (1 - (CONVERT(FLOAT,ConvertedCases) / CONVERT(FLOAT,GoodProduct))) * 100 END,
		
						ScheduleUtilization = CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0'))) = 0  THEN 0 ELSE (CONVERT(FLOAT,ScheduleTime) / CONVERT(FLOAT,CalendarTime)) * 100    END,
						DownMSU				= CASE  WHEN (CONVERT(FLOAT,ISNULL(MSU,'0'))) = 0  THEN 0 ELSE ((TotalPlannedDowntime + TotalUpdDowntime) / MSU ) END,
						StopsMSU			= CASE  WHEN (CONVERT(FLOAT,ISNULL(MSU,'0'))) = 0  THEN 0 ELSE (TotalStops / MSU ) END,
						RunEff				= CASE    
											WHEN (CONVERT(FLOAT,ISNULL(ScheduleTime,'0')) - CONVERT(FLOAT,ISNULL(TotalPlannedDowntime,'0')) = 0 OR (CONVERT(FLOAT,ISNULL(TargetRate,'0')) = 0)) 
											THEN 0  
											ELSE (CONVERT(FLOAT,GoodProduct) / CONVERT(FLOAT,TargetRate)) / (CONVERT(FLOAT,ISNULL(ScheduleTime,'0')) - CONVERT(FLOAT,ISNULL(TotalPlannedDowntime,'0'))) * 100  
											END,
						MTBF				= CASE WHEN TotalStops = 0 
												THEN Uptime
												ELSE Uptime/TotalStops 
												END,
						MTBFUpd				= CASE WHEN TotalUpdStops = 0 
												THEN Uptime 
												ELSE Uptime/TotalUpdStops END,
						MTTR				= CASE WHEN TotalStops=0 
												THEN Duration 
												ELSE Duration / TotalStops END,
						UpsDTPRLoss			= CASE WHEN ScheduleTime=0 THEN 0 ELSE 100 * ISNULL(TotalUpdDowntime,0) / CONVERT(FLOAT,ScheduleTime) END,
						PlannedDTPRLoss		= CASE WHEN ScheduleTime=0 THEN 0 ELSE 100 * ISNULL((Duration - TotalUpdDowntime),0) / CONVERT(FLOAT,ScheduleTime) END,
						MTTRUpd				= CASE 
												WHEN TotalUpdDowntime > 0 AND TotalUpdStops > 0 THEN TotalUpdDowntime / CONVERT(FLOAT,TotalUpdStops)	
												WHEN TotalUpdStops <= 0 THEN TotalUpdDowntime	
												ELSE 0
												END,
						UpdDownPerc			= CASE WHEN Duration = 0 
												THEN 0 
												ELSE 100 * (TotalUpdDowntime / Duration) END,
						StopsDay			= Case When Convert(Float,ScheduleTime) <= 0 Then TotalStops  
												Else Convert(Float,TotalStops) * 1440 / (Convert(Float,ScheduleTime))End  ,
						ProcFailuresDay		= Case When Convert(Float,ScheduleTime) <= 0 Then ProcFailures  
												Else Convert(Float,ProcFailures) * 1440 / (Convert(Float,ScheduleTime))End ,
						Availability_Unpl_DT = CASE WHEN (Uptime + TotalUpdDowntime) = 0 THEN 0 ELSE Uptime /(Uptime + TotalUpdDowntime) END,	
						Availability_Planned_DT = CASE WHEN (Uptime + (Duration - TotalUpdDowntime)) = 0 THEN 0 ELSE Uptime /(Uptime + (Duration - TotalUpdDowntime)) END,	
						Availability_Total_DT =	CASE WHEN (Uptime + Duration) = 0 THEN 0 ELSE Uptime /(Uptime + Duration) END ,	
						MTBS				= CASE WHEN TotalStops = 0 THEN 0 ELSE Uptime/ TotalStops END,
						ACPStopsDay			= CASE WHEN CONVERT(FLOAT,ScheduleTime) < 1440 THEN AcpStops   
												ELSE (CONVERT(FLOAT,AcpStops) * 1440) / CONVERT(FLOAT,ScheduleTime)
												END,    
						FalseStarts0Per 	= CASE WHEN Cast(TotalStops AS FLOAT) = 0 THEN 0  ELSE Cast(FalseStarts0 AS FLOAT) * 100 / Cast(TotalStops As Float) End, 
						FalseStartsTPer		= CASE WHEN Cast(TotalStops AS FLOAT) = 0 THEN 0  ELSE Cast(FalseStartsT AS FLOAT) * 100 / Cast(TotalStops As Float) End	,
						Survival240RatePer	= CASE WHEN ISNULL(ScheduleTime,0) = 0 THEN 0 ELSE (CONVERT(FLOAT,Survival240Rate)/(CONVERT(FLOAT,ScheduleTime)/240)) *100 END  ,
						Survival210RatePer	= CASE WHEN ISNULL(ScheduleTime,0) = 0 THEN 0 ELSE (CONVERT(FLOAT,Survival210Rate)/(CONVERT(FLOAT,ScheduleTime)/210)) *100 END  ,
						EditedStopsPer		= CASE WHEN Convert(float,TotalStops) = 0 THEN 0 ELSE 100.0 * (Convert(float,EditedStops) / Convert(FLOAT,TotalStops)) END,
						TotalUpdStopDay		= Case When Convert(Float,ScheduleTime) <= 0 Then TotalUpdStops  ELSE (TotalUpdStops * 1440) / ScheduleTime END  ,
						StopsBDSDay			= Case When Convert(Float,ScheduleTime) <= 0 Then BreakDown  ELSE (BreakDown * 1440) / ScheduleTime END,
						TotalPlannedStopsDay = Case When Convert(Float,ScheduleTime) <= 0 Then TotalPlannedStops  
												Else Convert(Float,TotalPlannedStops) * 1440 / (Convert(Float,ScheduleTime))End,
						MajorStopsDay		= Case When Convert(Float,ScheduleTime) <= 0 Then  MajorStops   ELSE ( MajorStops * 1440) / ScheduleTime END,
						MinorStopsDay		= Case When Convert(Float,ScheduleTime) <= 0 Then  MinorStops  ELSE ( MinorStops * 1440) / ScheduleTime END ,
						Area4LossPer		= CASE WHEN @SpecialCasesFlag = 1 THEN 
												CASE WHEN Convert(FLOAT,TotalProduct) <= 0 THEN 0 ELSE (((Convert(float,TotalProduct) - Convert(float,TotalScrap)) - Convert(float,ConvertedCases)) / Convert(float,TotalProduct)) * 100 END
										  ELSE NULL END,
						TargetRateAdj =	CASE WHEN ActualRate > TargetRate  THEN  (ActualRate-Targetrate) / TargetRate ELSE 0 END
			
				UPDATE @TotalGroup
					SET R2 = CONVERT(FLOAT,((CONVERT(FLOAT,TotalStops) - CONVERT(FLOAT,FalseStartsT)) + 1) / (CONVERT(FLOAT,TotalStops) + 1))

				UPDATE @TotalGroup
					SET R0 =  CONVERT(FLOAT,((CONVERT(FLOAT,TotalStops) - CONVERT(FLOAT,FalseStarts0)) + 1) / (CONVERT(FLOAT,TotalStops) + 1))
				  
				UPDATE @TotalGroup
					SET PR = (SELECT CASE WHEN SUM(MSU) = 0 OR SUM (MSU / PR) = 0 THEN 0 ELSE (SUM(MSU * 1000) / SUM((MSU * 1000) / PR)) END 
								FROM @MajorGroup mg
								JOIN @Equipment e ON e.PLId = mg.MajorGroupId
								WHERE e.YLineFlag = 1
								  AND PR > 0
								  AND MSU > 0)
 				UPDATE @TotalGroup
					SET PR_Excl_PRInDev = (SELECT CASE WHEN SUM(MSUExcDev) = 0 OR SUM (MSUExcDev / PR_Excl_PRInDev) = 0 THEN 0 ELSE (SUM(MSUExcDev * 1000) / SUM((MSUExcDev * 1000) / PR_Excl_PRInDev)) END 
											FROM @MajorGroup mg
											JOIN @Equipment e ON e.PLId = mg.MajorGroupId
											WHERE e.YLineFlag = 1
											  AND PR_Excl_PRInDev > 0
											  AND MSUExcDev > 0)       
				UPDATE @TotalGroup
					SET PRRateLossTgtRate = (SELECT CASE WHEN TargetRate < ActualRate THEN ActualRate ELSE TargetRate END)

				UPDATE @TotalGroup
					SET PercentPRRateLoss = (CASE WHEN ScheduleTime > 0 and TargetRate > 0 and PRRateLossTgtRate > 0
													THEN ( ( (PRRateLossTgtRate - IIF(Uptime > 0 ,((SELECT SUM(StatCases) 
																									 FROM @MajorGroup mg
																									 JOIN @Equipment e ON e.PLId = mg.MajorGroupId
																									 WHERE e.isConverter = 1) / Uptime), 0)) * Uptime ) / PRRateLossTgtRate ) / ScheduleTime
													ELSE 0
												END) * 100
				UPDATE @TotalGroup
					SET PRLossScrap = CASE WHEN ScheduleTime <= 0 OR PRRateLossTgtRate <= 0 THEN 0 ELSE 100 * ISNULL((RunningScrap / PRRateLossTgtRate),0) / CONVERT(FLOAT,ScheduleTime) END
				--SELECT '@TotalGroup',* from @TotalGroup
		
				UPDATE mg
					SET PRLossDivisor = CASE WHEN PR > 0 AND MSU > 0
													 THEN MSU / PR
													 ELSE CASE WHEN ScheduleTime * TargetRate > 0
															   THEN ScheduleTime * TargetRate
															   ELSE 0 END
													 END	
				FROM @MajorGroup mg
				JOIN @Equipment e ON e.PLId = mg.MajorGroupId
				WHERE e.YLineFlag = 1
		
				UPDATE @TotalGroup
					SET PRLossDivisor = (SELECT SUM(PRLossDivisor) 
										 FROM @MajorGroup mg
										 JOIN @Equipment e ON e.PLId = mg.MajorGroupId
										 WHERE e.YLineFlag = 1) 

				UPDATE @TotalGroup
					SET PlannedDTPRLoss = (SELECT CASE WHEN SUM(mg.PRLossDivisor) > 0 
													   THEN (SUM(mg.PlannedDTPRLoss * mg.PRLossDivisor) / SUM(mg.PRLossDivisor))
													   ELSE 0
													   END
											FROM @MajorGroup mg
											JOIN @Equipment e ON e.PLId = mg.MajorGroupId
											WHERE e.YLineFlag = 1)


				UPDATE @TotalGroup
					SET UpsDTPRLoss = (SELECT CASE WHEN SUM(mg.PRLossDivisor) > 0 
													   THEN (SUM(mg.UpsDTPRLoss * mg.PRLossDivisor) / SUM(mg.PRLossDivisor))
													   ELSE 0
													   END
											FROM @MajorGroup mg
											JOIN @Equipment e ON e.PLId = mg.MajorGroupId
											WHERE e.YLineFlag = 1 )
		END	
		ELSE IF ((SELECT COUNT(*) FROM @Equipment WHERE YLineFlag = 1) = 1)
		BEGIN
			INSERT INTO @TotalGroup(
					 GoodProduct				
					,TotalProduct				
					,TotalScrap					
					,ActualRate					
					,TargetRate					
					,ScheduleTime				
					,CalendarTime				
					,PR							
					,ScrapPer					
					,IdealRate					
					,STNU						
					,CapacityUtilization		
					,ScheduleUtilization		
					,Availability				
					,PRAvailability				
					,StopsMSU					
					,DownMSU					
					,RunningScrapPer			
					,RunningScrap				
					,StartingScrapPer			
					,StartingScrap				
					,RoomLoss					
					,MSU						
					,TotalCases					
					,RateUtilization			
					,RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,VSNetProduction			
					,VSPR						
					,VSPRLossPer				
					,TotalStops					
					,Duration					
					,TotalUpdDowntime			
					,TotalUpdStops				
					,MinorStops					
					,ProcFailures				
					,MajorStops					
					,Uptime						
					,MTBF						
					,MTBFUpd					
					,MTTR						
					,UpsDTPRLoss				
					,R0							
					,R2							
					,BreakDown					
					,MTTRUpd					
					,UpdDownPerc				
					,StopsDay					
					,ProcFailuresDay			
					,Availability_Unpl_DT		
					,Availability_Total_DT		
					,MTBS						
					,ACPStops					
					,ACPStopsDay				
					,RepairTimeT				
					,FalseStarts0				
					,FalseStarts0Per			
					,FalseStartsT				
					,FalseStartsTPer			
					,Survival240Rate			
					,Survival240RatePer			
					,EditedStops				
					,EditedStopsPer				
					,TotalUpdStopDay			
					,StopsBDSDay				
					,TotalPlannedStops			
					,TotalPlannedStopsDay		
					,MajorStopsDay				
					,MinorStopsDay				
					,TotalStarvedStops			
					,TotalBlockedStops			
					,TotalStarvedDowntime		
					,TotalBlockedDowntime		
					,VSScheduledTime			
					,VSPRLossPlanned			
					,VSPRLossUnplanned			
					,VSPRLossBreakdown			
					,Survival210Rate			
					,Survival210RatePer			
					,R210						
					,R240						
					,Availability_Planned_DT	
					,TotalPlannedDowntime		
					,PlannedDTPRLoss			
					,ProductionTime				
					,VSTotalUpdDowntime			
					,VSTotalPlannedDowntime		
					,VSBreakdown 				
					,VSTargetRate				
					,EffRateLossDT				
					,PercentPRLossBreakdownDT   
					,PercentPRRateLoss			
					,VSEffRateLossDowntime		
					,VSTotalProduction			
					,NetProduction				
					,Area4LossPer				
					,ConvertedCases				
					,PRRateLossTgtRate			
					,BrandProjectPer			
					,EO_NonShippablePer			
					,LineNotStaffedPer			
					,STNUPer					
					,PRLossScrap				
					,StatUnits					
					,PRLossDivisor	
					,PR_Excl_PRInDev	
					,NetProductionExcDev
					,ScheduleTimeExcDev	
					,MSUExcDev			
					,IdleTime					
					,ExcludedTime						
					,StatCases			
					,TargetRateAdj
					,MAchineStopsDay
					,ProjConstructPerc
					,STNUSchedVarPerc			)

			SELECT  
					 mg.GoodProduct				
					,mg.TotalProduct				
					,mg.TotalScrap					
					,mg.ActualRate					
					,mg.TargetRate					
					,mg.ScheduleTime				
					,mg.CalendarTime				
					,mg.PR							
					,mg.ScrapPer					
					,mg.IdealRate					
					,mg.STNU						
					,mg.CapacityUtilization		
					,mg.ScheduleUtilization		
					,mg.Availability				
					,mg.PRAvailability				
					,mg.StopsMSU					
					,mg.DownMSU					
					,mg.RunningScrapPer			
					,mg.RunningScrap				
					,mg.StartingScrapPer			
					,mg.StartingScrap				
					,mg.RoomLoss					
					,mg.MSU						
					,mg.TotalCases					
					,mg.RateUtilization			
					,mg.RunEff						
					--,SafetyTrigg				
					--,QualityTrigg				
					,mg.VSNetProduction			
					,mg.VSPR						
					,mg.VSPRLossPer				
					,mg.TotalStops					
					,mg.Duration					
					,mg.TotalUpdDowntime			
					,mg.TotalUpdStops				
					,mg.MinorStops					
					,mg.ProcFailures				
					,mg.MajorStops					
					,mg.Uptime						
					,mg.MTBF						
					,mg.MTBFUpd					
					,mg.MTTR						
					,mg.UpsDTPRLoss				
					,mg.R0							
					,mg.R2							
					,mg.BreakDown					
					,mg.MTTRUpd					
					,mg.UpdDownPerc				
					,mg.StopsDay					
					,mg.ProcFailuresDay			
					,mg.Availability_Unpl_DT		
					,mg.Availability_Total_DT		
					,mg.MTBS						
					,mg.ACPStops					
					,mg.ACPStopsDay				
					,mg.RepairTimeT				
					,mg.FalseStarts0				
					,mg.FalseStarts0Per			
					,mg.FalseStartsT				
					,mg.FalseStartsTPer			
					,mg.Survival240Rate			
					,mg.Survival240RatePer			
					,mg.EditedStops				
					,mg.EditedStopsPer				
					,mg.TotalUpdStopDay			
					,mg.StopsBDSDay				
					,mg.TotalPlannedStops			
					,mg.TotalPlannedStopsDay		
					,mg.MajorStopsDay				
					,mg.MinorStopsDay				
					,mg.TotalStarvedStops			
					,mg.TotalBlockedStops			
					,mg.TotalStarvedDowntime		
					,mg.TotalBlockedDowntime		
					,mg.VSScheduledTime			
					,mg.VSPRLossPlanned			
					,mg.VSPRLossUnplanned			
					,mg.VSPRLossBreakdown			
					,mg.Survival210Rate			
					,mg.Survival210RatePer			
					,mg.R210						
					,mg.R240						
					,mg.Availability_Planned_DT	
					,mg.TotalPlannedDowntime		
					,mg.PlannedDTPRLoss			
					,mg.ProductionTime				
					,mg.VSTotalUpdDowntime			
					,mg.VSTotalPlannedDowntime		
					,mg.VSBreakdown 				
					,mg.VSTargetRate				
					,mg.EffRateLossDT				
					,mg.PercentPRLossBreakdownDT   
					,mg.PercentPRRateLoss			
					,mg.VSEffRateLossDowntime		
					,mg.VSTotalProduction			
					,mg.NetProduction				
					,mg.Area4LossPer				
					,mg.ConvertedCases				
					,mg.PRRateLossTgtRate			
					,mg.BrandProjectPer			
					,mg.EO_NonShippablePer			
					,mg.LineNotStaffedPer			
					,mg.STNUPer					
					,mg.PRLossScrap				
					,mg.StatUnits					
					,mg.PRLossDivisor		
				    ,mg.PR_Excl_PRInDev	
				    ,mg.NetProductionExcDev
				    ,mg.ScheduleTimeExcDev	
				    ,mg.MSUExcDev			
					,mg.IdleTime					
					,mg.ExcludedTime				
					,mg.StatCases			
					,mg.TargetRateAdj	
					,mg.MAchineStopsDay
					,mg.ProjConstructPerc
					,mg.STNUSchedVarPerc				

			FROM @MajorGroup mg
			JOIN @Equipment e ON mg.MajorGroupId = e.PLId
			WHERE e.YLineFlag = 1

				
		END
	END
END

-- --------------------------------------------------------------------------------------------------------------------
-- Final Output construction
-- --------------------------------------------------------------------------------------------------------------------
--select '@Equipment',* from @Equipment
--select '@MinorGroup',* from @MinorGroup
--select '@MajorGroup',* from @MajorGroup
--select '@TotalGroup',* from @TotalGroup
--===============================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'                 
PRINT 'OUTPUT GROUPING SECTION ' + CONVERT(VARCHAR(50), GETDATE(), 121)                                              
PRINT '-----------------------------------------------------------------------------------------------------------------------'                 
--===============================================================================================
IF NOT((@strMajorGroupBy = 'ValueStream' AND @strMinorGroupBy = 'None') OR (@strMajorGroupBy = 'WorkCell' AND @strMinorGroupBy = 'None') OR (@strMajorGroupBy = 'Line' AND @strMinorGroupBy = 'None') )
BEGIN
		INSERT INTO @FinalOutput(
				 MajorGroupBy			
				,MinorGroupBy	
				,MajorGroup
				,OutputOrder		
				,PlannedDTPRLoss		
				,UpsDTPRLoss
				,PercentPRRateLoss			
				,EditedStopsPer			
				,Availability_Planned_DT
				,Availability_Unpl_DT	
				,Availability_Total_DT	
				,UpdDownPerc			
				,MTBF					
				,MTBFUpd				
				,MTTR					
				,MTTRUpd				
				,ScrapPer				
				,MajorStopsDay			
				,MinorStopsDay			
				,GoodProduct			
				,TotalProduct			
				,TotalPlannedStops		
				,TotalPlannedStopsDay	
				,ProcFailuresDay		
				,PR						
				,PR_Excl_PRInDev	
				,ScheduleTime			
				,Area4LossPer
				,StopsDay				
				,StopsBDSDay			
				,TotalStops				
				,TotalUpdStops			
				,TotalUpdStopDay		
				,VSNetProduction		
				,VSPR					
				,VSPRLossPer			
				,VSScheduledTime		
				,VSPRLossPlanned		
				,VSPRLossUnplanned		
				,VSPRLossBreakdown
				,LineStatus				
				,TotalScrap				
				,IdealRate				
				,STNU					
				,CapacityUtilization	
				,ScheduleUtilization	
				,Availability			
				,PRAvailability			
				,StopsMSU				
				,DownMSU				
				,RunningScrapPer		
				,RunningScrap			
				,StartingScrapPer		
				,StartingScrap			
				,RoomLoss				
				,MSU					
				,TotalCases				
				,RateUtilization		
				,RunEff					
				,TotalUpdDowntime		
				,Uptime					
				,R0						
				,R2						
				,MTBS					
				,ACPStops				
				,ACPStopsDay			
				,RepairTimeT			
				,FalseStarts0			
				,FalseStarts0Per		
				,FalseStartsT			
				,FalseStartsTPer		
				,Survival240Rate		
				,Survival240RatePer		
				,EditedStops			
				,Survival210Rate		
				,Survival210RatePer		
				,TotalPlannedDowntime	
				,TargetRate				
				,ProcFailures			
				,BreakDown				
				,TotalStarvedStops		
				,TotalBlockedStops		
				,TotalStarvedDowntime	
				,TotalBlockedDowntime
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer				
				,PRLossScrap			
				,Duration		
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay						
				,StatCases			
				,ActualRate	
				,TargetRateAdj
				,ProjConstructPerc
				,STNUSchedVarPerc		)			

		SELECT 
				 MajorGroupBy			
				,MinorGroupBy	
				,MajorGroupBy	
				,1		
				,PlannedDTPRLoss		
				,UpsDTPRLoss	
				,PercentPRRateLoss		
				,EditedStopsPer			
				,Availability_Planned_DT
				,Availability_Unpl_DT	
				,Availability_Total_DT	
				,UpdDownPerc			
				,MTBF					
				,MTBFUpd				
				,MTTR					
				,MTTRUpd				
				,ScrapPer				
				,MajorStopsDay			
				,MinorStopsDay			
				,GoodProduct			
				,TotalProduct			
				,TotalPlannedStops		
				,TotalPlannedStopsDay	
				,ProcFailuresDay		
				,PR						
				,PR_Excl_PRInDev	
				,ScheduleTime			
				,Area4LossPer
				,StopsDay				
				,StopsBDSDay			
				,TotalStops				
				,TotalUpdStops			
				,TotalUpdStopDay		
				,VSNetProduction		
				,VSPR					
				,VSPRLossPer			
				,VSScheduledTime		
				,VSPRLossPlanned		
				,VSPRLossUnplanned		
				,VSPRLossBreakdown
				,LineStatus				
				,TotalScrap				
				,IdealRate				
				,STNU					
				,CapacityUtilization	
				,ScheduleUtilization	
				,Availability			
				,PRAvailability			
				,StopsMSU				
				,DownMSU				
				,RunningScrapPer		
				,RunningScrap			
				,StartingScrapPer		
				,StartingScrap			
				,RoomLoss				
				,MSU					
				,TotalCases				
				,RateUtilization		
				,RunEff					
				,TotalUpdDowntime		
				,Uptime					
				,R0						
				,R2						
				,MTBS					
				,ACPStops				
				,ACPStopsDay			
				,RepairTimeT			
				,FalseStarts0			
				,FalseStarts0Per		
				,FalseStartsT			
				,FalseStartsTPer		
				,Survival240Rate		
				,Survival240RatePer		
				,EditedStops			
				,Survival210Rate		
				,Survival210RatePer		
				,TotalPlannedDowntime	
				,TargetRate				
				,ProcFailures			
				,BreakDown				
				,TotalStarvedStops		
				,TotalBlockedStops		
				,TotalStarvedDowntime	
				,TotalBlockedDowntime
				,BrandProjectPer		
				,EO_NonShippablePer		
				,LineNotStaffedPer		
				,STNUPer	
				,PRLossScrap				
				,Duration					
				,IdleTime					
				,ExcludedTime				
				,MAchineStopsDay			
				,StatCases	
				,ActualRate				
				,TargetRateAdj	
				,ProjConstructPerc
				,STNUSchedVarPerc		

		FROM @MinorGroup
		--select '@FinalOutput',* from @FinalOutput

		-- FLEXIBLE VARIABLES TOTAL
		INSERT INTO #FinalFlexVars(
				 MajorGroupBy	
				,MinorGroupBy	
				,MajorGroup
				,OutputOrder	
				)	
		SELECT   MajorGroupBy	
				,MinorGroupBy	
				,MajorGroupBy	
				,1
		FROM @MinorGroup

		--SET Final RS for Flex variables
		SET @Query = ''

		SELECT @Query = @Query + ' UPDATE #FinalFlexVars ' + CHAR(13) +
			' SET #FinalFlexVars.[' + c.name + '] = (SELECT SUM(ISNULL(CONVERT(FLOAT, [' + c.name + ']),0)) ' + CHAR(13) +
			' FROM #MinorFlexVars mfv ' + CHAR(13) +
			' WHERE mfv.MajorGroupBy = #FinalFlexVars.MajorGroupBy ' + CHAR(13) +
			'   AND mfv.MinorGroupBy = #FinalFlexVars.MinorGroupBy );' + CHAR(13) 
		from tempdb.sys.columns c
		where object_id = object_id('tempdb..#MinorFlexVars')
		AND	c.name NOT LIKE 'Idx'
		AND	c.name NOT LIKE 'MinorGroupId'
		AND	c.name NOT LIKE 'MinorGroupBy'
		AND	c.name NOT LIKE 'MajorGroupId'
		AND	c.name NOT LIKE 'MajorGroupBy'
		AND	c.name NOT LIKE 'TeamDesc'		
		AND	c.name NOT LIKE 'StartTime'	
		AND	c.name NOT LIKE 'LineStatus'	
		AND	c.name NOT LIKE 'EndTime'

		EXEC (@Query)
END

INSERT INTO @FinalOutput(
		 MajorGroupBy			
		,MinorGroupBy
		,MajorGroup	
		,OutputOrder			
		,PlannedDTPRLoss		
		,UpsDTPRLoss
		,PercentPRRateLoss			
		,EditedStopsPer			
		,Availability_Planned_DT
		,Availability_Unpl_DT	
		,Availability_Total_DT	
		,UpdDownPerc			
		,MTBF					
		,MTBFUpd				
		,MTTR					
		,MTTRUpd				
		,ScrapPer				
		,MajorStopsDay			
		,MinorStopsDay			
		,GoodProduct			
		,TotalProduct			
		,TotalPlannedStops		
		,TotalPlannedStopsDay	
		,ProcFailuresDay		
		,PR					
		,PR_Excl_PRInDev		
		,ScheduleTime	
		,Area4LossPer		
		,StopsDay				
		,StopsBDSDay			
		,TotalStops				
		,TotalUpdStops			
		,TotalUpdStopDay		
		,VSNetProduction		
		,VSPR					
		,VSPRLossPer			
		,VSScheduledTime		
		,VSPRLossPlanned		
		,VSPRLossUnplanned		
		,VSPRLossBreakdown
		,LineStatus				
		,TotalScrap				
		,IdealRate				
		,STNU					
		,CapacityUtilization	
		,ScheduleUtilization	
		,Availability			
		,PRAvailability			
		,StopsMSU				
		,DownMSU				
		,RunningScrapPer		
		,RunningScrap			
		,StartingScrapPer		
		,StartingScrap			
		,RoomLoss				
		,MSU					
		,TotalCases				
		,RateUtilization		
		,RunEff					
		,TotalUpdDowntime		
		,Uptime					
		,R0						
		,R2						
		,MTBS					
		,ACPStops				
		,ACPStopsDay			
		,RepairTimeT			
		,FalseStarts0			
		,FalseStarts0Per		
		,FalseStartsT			
		,FalseStartsTPer		
		,Survival240Rate		
		,Survival240RatePer		
		,EditedStops			
		,Survival210Rate		
		,Survival210RatePer		
		,TotalPlannedDowntime	
		,TargetRate				
		,ProcFailures			
		,BreakDown				
		,TotalStarvedStops		
		,TotalBlockedStops		
		,TotalStarvedDowntime	
		,TotalBlockedDowntime	
		,BrandProjectPer		
		,EO_NonShippablePer		
		,LineNotStaffedPer		
		,STNUPer				
		,PRLossScrap							
		,Duration		
		,IdleTime					
		,ExcludedTime				
		,MAchineStopsDay						
		,StatCases		
		,ActualRate	
		,TargetRateAdj
		,ProjConstructPerc
		,STNUSchedVarPerc		)		
	
SELECT 
		 MajorGroupBy		
		,'Total'	
		,MajorGroupBy	
		,2
		--,MinorGroupBy			
		,PlannedDTPRLoss		
		,UpsDTPRLoss	
		,PercentPRRateLoss		
		,EditedStopsPer			
		,Availability_Planned_DT
		,Availability_Unpl_DT	
		,Availability_Total_DT	
		,UpdDownPerc			
		,MTBF					
		,MTBFUpd				
		,MTTR					
		,MTTRUpd				
		,ScrapPer				
		,MajorStopsDay			
		,MinorStopsDay			
		,GoodProduct			
		,TotalProduct			
		,TotalPlannedStops		
		,TotalPlannedStopsDay	
		,ProcFailuresDay		
		,PR	
		,PR_Excl_PRInDev						
		,ScheduleTime	
		,Area4LossPer		
		,StopsDay				
		,StopsBDSDay			
		,TotalStops				
		,TotalUpdStops			
		,TotalUpdStopDay		
		,VSNetProduction		
		,VSPR					
		,VSPRLossPer			
		,VSScheduledTime		
		,VSPRLossPlanned		
		,VSPRLossUnplanned		
		,VSPRLossBreakdown
		,LineStatus				
		,TotalScrap				
		,IdealRate				
		,STNU					
		,CapacityUtilization	
		,ScheduleUtilization	
		,Availability			
		,PRAvailability			
		,StopsMSU				
		,DownMSU				
		,RunningScrapPer		
		,RunningScrap			
		,StartingScrapPer		
		,StartingScrap			
		,RoomLoss				
		,MSU					
		,TotalCases				
		,RateUtilization		
		,RunEff					
		,TotalUpdDowntime		
		,Uptime					
		,R0						
		,R2						
		,MTBS					
		,ACPStops				
		,ACPStopsDay			
		,RepairTimeT			
		,FalseStarts0			
		,FalseStarts0Per		
		,FalseStartsT			
		,FalseStartsTPer		
		,Survival240Rate		
		,Survival240RatePer		
		,EditedStops			
		,Survival210Rate		
		,Survival210RatePer		
		,TotalPlannedDowntime	
		,TargetRate				
		,ProcFailures			
		,BreakDown				
		,TotalStarvedStops		
		,TotalBlockedStops		
		,TotalStarvedDowntime	
		,TotalBlockedDowntime
		,BrandProjectPer		
		,EO_NonShippablePer		
		,LineNotStaffedPer		
		,STNUPer			
		,PRLossScrap						
		,Duration			
		,IdleTime					
		,ExcludedTime				
		,MAchineStopsDay			
		,StatCases			
		,ActualRate		
		,TargetRateAdj
		,ProjConstructPerc
		,STNUSchedVarPerc				
FROM @MajorGroup

--SET Final RS for Flex variables Major group
-- FLEXIBLE VARIABLES TOTAL
INSERT INTO #FinalFlexVars(
		 MajorGroupBy	
		,MinorGroupBy	
		,MajorGroup
		,OutputOrder	
		)	
SELECT   MajorGroupBy	
		,'Total'		
		,MajorGroupBy	
		,2
FROM @MajorGroup

SET @Query = ''

SELECT @Query = @Query + ' UPDATE ffv ' + CHAR(13) +
	' SET ffv.[' + c.name + '] = ISNULL((SELECT SUM(ISNULL(CONVERT(FLOAT, mfv.[' + c.name + ']),0)) ' + CHAR(13) +
	' FROM #MajorFlexVars mfv ' + CHAR(13) +
	' WHERE mfv.MajorGroupBy = ffv.MajorGroupBy ),0)' + CHAR(13) +
	' FROM #FinalFlexVars ffv ' + CHAR(13) +
	' WHERE ffv.MinorGroupBy  = ''Total'' ;' + CHAR(13)
from tempdb.sys.columns c
where object_id = object_id('tempdb..#MajorFlexVars')
AND	c.name NOT LIKE 'Idx'
AND	c.name NOT LIKE 'MinorGroupId'
AND	c.name NOT LIKE 'MajorGroupId'
AND	c.name NOT LIKE 'MajorGroupBy'
AND	c.name NOT LIKE 'TeamDesc'		
AND	c.name NOT LIKE 'StartTime'	
AND	c.name NOT LIKE 'LineStatus'	
AND	c.name NOT LIKE 'EndTime'

EXEC (@Query)

INSERT INTO @FinalOutput(
		 MajorGroupBy			
		,MinorGroupBy
		,MajorGroup
		,OutputOrder			
		,PlannedDTPRLoss		
		,UpsDTPRLoss
		,PercentPRRateLoss			
		,EditedStopsPer			
		,Availability_Planned_DT
		,Availability_Unpl_DT	
		,Availability_Total_DT	
		,UpdDownPerc			
		,MTBF					
		,MTBFUpd				
		,MTTR					
		,MTTRUpd				
		,ScrapPer				
		,MajorStopsDay			
		,MinorStopsDay			
		,GoodProduct			
		,TotalProduct			
		,TotalPlannedStops		
		,TotalPlannedStopsDay	
		,ProcFailuresDay		
		,PR		
		,PR_Excl_PRInDev					
		,ScheduleTime	
		,Area4LossPer		
		,StopsDay				
		,StopsBDSDay			
		,TotalStops				
		,TotalUpdStops			
		,TotalUpdStopDay		
		,VSNetProduction		
		,VSPR					
		,VSPRLossPer			
		,VSScheduledTime		
		,VSPRLossPlanned		
		,VSPRLossUnplanned		
		,VSPRLossBreakdown
		,LineStatus				
		,TotalScrap				
		,IdealRate				
		,STNU					
		,CapacityUtilization	
		,ScheduleUtilization	
		,Availability			
		,PRAvailability			
		,StopsMSU				
		,DownMSU				
		,RunningScrapPer		
		,RunningScrap			
		,StartingScrapPer		
		,StartingScrap			
		,RoomLoss				
		,MSU					
		,TotalCases				
		,RateUtilization		
		,RunEff					
		,TotalUpdDowntime		
		,Uptime					
		,R0						
		,R2						
		,MTBS					
		,ACPStops				
		,ACPStopsDay			
		,RepairTimeT			
		,FalseStarts0			
		,FalseStarts0Per		
		,FalseStartsT			
		,FalseStartsTPer		
		,Survival240Rate		
		,Survival240RatePer		
		,EditedStops			
		,Survival210Rate		
		,Survival210RatePer		
		,TotalPlannedDowntime	
		,TargetRate				
		,ProcFailures			
		,BreakDown				
		,TotalStarvedStops		
		,TotalBlockedStops		
		,TotalStarvedDowntime	
		,TotalBlockedDowntime	
		,BrandProjectPer		
		,EO_NonShippablePer		
		,LineNotStaffedPer		
		,STNUPer				
		,PRLossScrap							
		,Duration				
		,IdleTime					
		,ExcludedTime				
		,MAchineStopsDay						
		,StatCases			
		,ActualRate	
		,TargetRateAdj
		,ProjConstructPerc
		,STNUSchedVarPerc				)	
SELECT 
		 'TOTAL'		
		,'Total'	
		,'ZZZZZ'
		,3
		--,MinorGroupBy			
		,PlannedDTPRLoss		
		,UpsDTPRLoss	
		,PercentPRRateLoss		
		,EditedStopsPer			
		,Availability_Planned_DT
		,Availability_Unpl_DT	
		,Availability_Total_DT	
		,UpdDownPerc			
		,MTBF					
		,MTBFUpd				
		,MTTR					
		,MTTRUpd				
		,ScrapPer				
		,MajorStopsDay			
		,MinorStopsDay			
		,GoodProduct			
		,TotalProduct			
		,TotalPlannedStops		
		,TotalPlannedStopsDay	
		,ProcFailuresDay		
		,PR				
		,PR_Excl_PRInDev			
		,ScheduleTime	
		,Area4LossPer		
		,StopsDay				
		,StopsBDSDay			
		,TotalStops				
		,TotalUpdStops			
		,TotalUpdStopDay		
		,VSNetProduction		
		,VSPR					
		,VSPRLossPer			
		,VSScheduledTime		
		,VSPRLossPlanned		
		,VSPRLossUnplanned		
		,VSPRLossBreakdown
		,LineStatus				
		,TotalScrap				
		,IdealRate				
		,STNU					
		,CapacityUtilization	
		,ScheduleUtilization	
		,Availability			
		,PRAvailability			
		,StopsMSU				
		,DownMSU				
		,RunningScrapPer		
		,RunningScrap			
		,StartingScrapPer		
		,StartingScrap			
		,RoomLoss				
		,MSU					
		,TotalCases				
		,RateUtilization		
		,RunEff					
		,TotalUpdDowntime		
		,Uptime					
		,R0						
		,R2						
		,MTBS					
		,ACPStops				
		,ACPStopsDay			
		,RepairTimeT			
		,FalseStarts0			
		,FalseStarts0Per		
		,FalseStartsT			
		,FalseStartsTPer		
		,Survival240Rate		
		,Survival240RatePer		
		,EditedStops			
		,Survival210Rate		
		,Survival210RatePer		
		,TotalPlannedDowntime	
		,TargetRate				
		,ProcFailures			
		,BreakDown				
		,TotalStarvedStops		
		,TotalBlockedStops		
		,TotalStarvedDowntime	
		,TotalBlockedDowntime	
		,BrandProjectPer		
		,EO_NonShippablePer		
		,LineNotStaffedPer		
		,STNUPer			
		,PRLossScrap					
		,Duration	
		,IdleTime					
		,ExcludedTime				
		,MAchineStopsDay				
		,StatCases			
		,ActualRate		
		,TargetRateAdj
		,ProjConstructPerc
		,STNUSchedVarPerc				
FROM @TotalGroup

--SET Final RS for Flex variables TOTAL group
-- FLEXIBLE VARIABLES TOTAL
INSERT INTO #FinalFlexVars(
		 MajorGroupBy	
		,MinorGroupBy	
		,MajorGroup
		,OutputOrder	
		)	
SELECT   'TOTAL'		
		,'Total'	
		,'ZZZZZ'	
		,3
FROM @TotalGroup

SET @Query = ''

SELECT @Query = @Query + ' UPDATE ffv ' + CHAR(13) +
	' SET ffv.[' + c.name + '] = ISNULL((SELECT SUM(ISNULL(CONVERT(FLOAT, tfv.[' + c.name + ']),0)) ' + CHAR(13) +
	' FROM #TotalFlexVars tfv ),0)' + CHAR(13) +
	' FROM #FinalFlexVars ffv ' + CHAR(13) +
	' WHERE ffv.MinorGroupBy  = ''Total'' ' + CHAR(13) +
	'   AND ffv.MajorGroupBy  = ''TOTAL'' ;' + CHAR(13)
from tempdb.sys.columns c
where object_id = object_id('tempdb..#TotalFlexVars')
AND	c.name NOT LIKE 'Idx'
AND	c.name NOT LIKE 'MinorGroupId'
AND	c.name NOT LIKE 'MajorGroupId'
AND	c.name NOT LIKE 'MajorGroupBy'
AND	c.name NOT LIKE 'TeamDesc'		
AND	c.name NOT LIKE 'StartTime'	
AND	c.name NOT LIKE 'LineStatus'	
AND	c.name NOT LIKE 'EndTime'

EXEC (@Query)
--select '@MinorGroup',* from @MinorGroup order by MajorGroupId,MinorGroupId
--select '@MajorGroup',* from @MajorGroup 
--select '@TotalGroup',* from @TotalGroup
--select '@FinalOutput',* from @FinalOutput
--select '#FinalFlexVars',* from #FinalFlexVars
--===============================================================================================
-- OUTPUT
--IF NOT((@strMajorGroupBy = 'Area' AND @strMinorGroupBy = 'ProdDay') OR (@strMajorGroupBy = 'WorkCell' AND (@strMinorGroupBy = 'ProdDay' OR @strMinorGroupBy = 'Team' OR @strMinorGroupBy = 'Shift' OR @strMinorGroupBy = 'Product')))
--BEGIN 
	SELECT 
		 ISNULL(fo.MajorGroupBy,0)					AS 'MajorGroup'
		,ISNULL(fo.MinorGroupBy,0)					AS 'MinorGroup'
		,ISNULL(fo.PlannedDTPRLoss,0)				AS 'kpiPercPRLossPlannedDT'
		,ISNULL(fo.UpsDTPRLoss,0)					AS 'kpiPercPRLossUnplDT'
		,ISNULL(fo.PercentPRRateLoss,0)				AS 'kpiPercPRLossRateLoss'
		,ISNULL(fo.EditedStopsPer,0)				AS 'kpiPercStopsEdited'
		,ISNULL(fo.Availability_Planned_DT,0)		AS 'kpiAvPlannedDT'
		,ISNULL(fo.Availability_Unpl_DT,0)			AS 'kpiAvUnplDT'
		,ISNULL(fo.Availability_Total_DT,0)			AS 'kpiAvTotalDT'
		,ISNULL(fo.UpdDownPerc,0)					AS 'kpiUnplDowntime'
		,ISNULL(fo.MTBF,0)							AS 'kpiMTBFTotalStops'
		,ISNULL(fo.MTBFUpd,0)						AS 'kpiMTBFUnplStops'
		,ISNULL(fo.MTTR,0)							AS 'kpiMTTRTotalDT'
		,ISNULL(fo.MTTRUpd,0)						AS 'kpiMTTRUnplDT'
		,ISNULL(fo.ScrapPer,0)						AS 'kpiMachineScrap'
		,ISNULL(fo.MajorStopsDay,0)					AS 'kpiMajorStopsDay'
		,ISNULL(fo.MinorStopsDay,0)					AS 'kpiMinorStopsDay'
		,ISNULL(fo.GoodProduct,0)					AS 'kpiNetProd'
		,ISNULL(fo.TotalProduct,0)					AS 'kpiNetProdScrap'
		,ISNULL(fo.TotalPlannedStops,0)				AS 'kpiPlannedStops'
		,ISNULL(fo.TotalPlannedStopsDay,0)			AS 'kpiPlannedStopsDay'
		,ISNULL(fo.ProcFailuresDay,0)				AS 'kpiProcFailuresDay'
		,ISNULL(fo.PR,0)							AS 'kpiProcessReliab'
		,ISNULL(fo.PR_Excl_PRInDev,0)				AS 'kpiPRExclPRInDevelopment'
		,ISNULL(fo.ScheduleTime,0)					AS 'kpiScheduledTime'
		,fo.Area4LossPer							AS 'kpiArea4LossPer'
		,ISNULL(fo.StopsDay,0)						AS 'kpiStopsDay'
		,ISNULL(fo.StopsBDSDay,0)					AS 'kpiStopsBDday'
		,ISNULL(fo.TotalStops,0)					AS 'kpiTotalStops'
		,ISNULL(fo.TotalUpdStops,0)					AS 'kpiUnplannedStops'
		,ISNULL(fo.TotalUpdStopDay,0)				AS 'kpiUnplStopsDay'
		,ISNULL(fo.LineStatus,'')					AS 'kpiLineStatus'
		,ISNULL(fo.TotalScrap,0)					AS 'kpiTotalScrap'
		,ISNULL(fo.IdealRate,0)						AS 'kpiIdealRate'
		,ISNULL(fo.STNU,0)							AS 'kpiSTNU'
		,ISNULL(fo.CapacityUtilization,0)			AS 'kpiCU'
		,ISNULL(fo.ScheduleUtilization,0)			AS 'kpiSU'
		,ISNULL(fo.Availability,0)					AS 'kpiAvailability'
		,ISNULL(fo.PRAvailability,0)				AS 'kpiPRAvailability'
		,ISNULL(fo.StopsMSU,0)						AS 'kpiStopsMSU'
		,ISNULL(fo.DownMSU,0)						AS 'kpiDowntimeMSU'
		,ISNULL(fo.RunningScrapPer,0)				AS 'kpiRunningScrapPer'
		,ISNULL(fo.RunningScrap,0)					AS 'kpiRunningScrap'
		,ISNULL(fo.StartingScrapPer,0)				AS 'kpiStartingScrapPer'
		,ISNULL(fo.StartingScrap,0)					AS 'kpiStartingScrap'
		,ISNULL(fo.RoomLoss,0)						AS 'kpiRoomLoss'
		,ISNULL(fo.MSU,0)							AS 'kpiMSU'
		,ISNULL(fo.TotalCases,0)					AS 'kpiTotalCases'
		,ISNULL(fo.RateUtilization,0)				AS 'kpiRateUtilization'
		,ISNULL(fo.RunEff,0)						AS 'kpiRunEfficiency'
		,ISNULL(fo.TotalUpdDowntime,0)				AS 'kpiTotalUnplDowntime'
		,ISNULL(fo.Uptime,0)						AS 'kpiUptime'
		,ISNULL(fo.R0,0)							AS 'kpiR0'
		,ISNULL(fo.R2,0)							AS 'kpiR2'
		,ISNULL(fo.MTBS,0)							AS 'kpiMTBS'
		,ISNULL(fo.ACPStops,0)						AS 'kpiACPStops'
		,ISNULL(fo.ACPStopsDay,0)					AS 'kpiACPStopsDay'
		,ISNULL(fo.RepairTimeT,0)					AS 'kpiRepairTimeT'
		,ISNULL(fo.FalseStarts0,0)					AS 'kpiFalseStarts0'
		,ISNULL(fo.FalseStarts0Per,0)				AS 'kpiFalseStarts0Per'
		,ISNULL(fo.FalseStartsT,0)					AS 'kpiFalseStartsT'
		,ISNULL(fo.FalseStartsTPer,0)				AS 'kpiFalseStartsTPer'
		,ISNULL(fo.Survival240Rate,0)				AS 'kpiSurvival240Rate'
		,ISNULL(fo.Survival240RatePer,0)			AS 'kpiSurvival240RatePer'
		,ISNULL(fo.EditedStops,0)					AS 'kpiEditedStops'
		,ISNULL(fo.Survival210Rate,0)				AS 'kpiSurvival210Rate'
		,ISNULL(fo.Survival210RatePer,0)			AS 'kpiSurvival210RatePer'
		,ISNULL(fo.TotalPlannedDowntime,0)			AS 'kpiTotalPlannedDowntime'
		,ISNULL(fo.TargetRate,0)					AS 'kpiTargetRate'
		,ISNULL(fo.ProcFailures,0)					AS 'kpiProcessFailures'
		,ISNULL(fo.BreakDown,0)						AS 'kpiBreakDown'
		,ISNULL(fo.TotalStarvedStops,0)				AS 'kpiTotalStarvedStops'
		,ISNULL(fo.TotalBlockedStops,0)				AS 'kpiTotalBlockedStops'
		,ISNULL(fo.TotalStarvedDowntime,0)			AS 'kpiTotalStarvedDowntime'
		,ISNULL(fo.TotalBlockedDowntime,0)			AS 'kpiTotalBlockedDowntime'
		,ISNULL(fo.BrandProjectPer,0)				AS 'kpiBrandProjectPer'
		,ISNULL(fo.EO_NonShippablePer,0)			AS 'kpiEO_NonShippablePer'
		,ISNULL(fo.LineNotStaffedPer,0)				AS 'kpiLineNotStaffedPer'
		,ISNULL(fo.STNUPer,0)						AS 'kpiSTNUPer'
		,ISNULL(fo.PRLossScrap,0)					AS 'kpiPRLossScrapPer'
		,ISNULL(fo.Duration,0)						AS 'kpiTotalDowntime'
		,ISNULL(fo.IdleTime,0)						AS 'kpiIdleTime'
		,ISNULL(fo.ExcludedTime,0)					AS 'kpiExcludedTime'
		,ISNULL(fo.MAchineStopsDay,0)				AS 'kpiMachineStopsDay'
		,ISNULL(fo.StatCases,0)						AS 'kpiStatCases'
		,ISNULL(fo.ActualRate,0)					AS 'kpiActualRate'
		,ISNULL(fo.TargetRateAdj,'')				AS 'kpiLineSpeedTargetAdjst'
		,ISNULL(fo.ProjConstructPerc,0)				AS 'kpiProjConstructPerc'
		,ISNULL(fo.STNUSchedVarPerc,0)				AS 'kpiSTNUSchedVarPerc'
		
	FROM @FinalOutput fo
	ORDER BY fo.MajorGroup,fo.OutputOrder,fo.MinorGroupBy 
--END
--ELSE
--BEGIN
--	SELECT * FROM @FinalOutput
--	ORDER BY MajorGroup,MinorGroupBy
--END
--===============================================================================================
-------------------------------------------------------------------------------------------------
--Output 2 for report header
-------------------------------------------------------------------------------------------------
	SELECT
		 PLId
		,PLDesc
		,CONVERT(VARCHAR, StartTime, 120)		AS 'StartTime'
		,CONVERT(VARCHAR, EndTime, 120)			AS 'EndTime'
		,CONVERT(VARCHAR, GETDATE(), 120)		AS 'RunTime'
	FROM @Equipment

-------------------------------------------------------------------------------------------------
--Output 3 FLEXIBLE VARIABLES
-------------------------------------------------------------------------------------------------
SELECT *
FROM #FinalFlexVars ffv
ORDER BY ffv.MajorGroup,ffv.OutputOrder,ffv.MinorGroupBy 

-------------------------------------------------------------------------------------------------
--TABLE CLEAN OUT
-------------------------------------------------------------------------------------------------
DROP TABLE #UserDefinedProduction
DROP TABLE #UserDefinedDowntime
DROP TABLE #UserDefinedFlexVariables
DROP TABLE #MinorFlexVars
DROP TABLE #MajorFlexVars
DROP TABLE #TotalFlexVars
DROP TABLE #FinalFlexVars

GO
GRANT  EXECUTE  ON [dbo].[spRptDaily]  TO OpDBWriter
GO
