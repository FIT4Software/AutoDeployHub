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
		@SP_Name	= 'spRptConvertingDDS',
		@Inputs		= 5, 
		@Version	= '2.0'  

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
	DROP PROCEDURE [dbo].[spRptConvertingDDS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptConvertingDDS
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Federico Vicente - Arido Software
-- Date created			: 2018-10-22
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for Converting DDS Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-10-22		Federico Vicente    Initial Release
-- 1.1		2019-07-10		Damian Campana		Add parameters StartTime & EndTime for Filter <User Defined>
-- 1.2		2019-07-16		Pablo Galanzini		Add check by deleteFlag in Ops tables. (Defect Panaya #821)
-- 1.3		2019-08-30		Gustavo Conde		Fix ON data quality summary calculation 
-- 1.4		2019-10-07		Pablo Galanzini		Fix in the data for Stops (INC4255482 - INC4203990)
-- 1.5		2019-10-30		Gonzalo Luc			Fix StartTime and EndTime ON @Lines table.
-- 1.6		2019-11-03		Pablo Galanzini		Fix Stops grid to show the correct rate loss data.
-- 1.7		2019-12-05		Pablo Galanzini		Update of RawUptime (INC4746656 in Cape)
-- 1.8		2020-09-05		Pablo Galanzini		Fix the KPIs Production time and Rate Loss (PRB0072349)
--			2020-10-06		Pablo Galanzini		Replace the use of Crew_Schedule on GBDB to use the table in Production of Converters ([OpsDB_Production_Data_Cvtg])
-- 1.9		2020-09-05		Pablo Galanzini		Add new fields used for Rate Loss (EffectiveDowntime, LineActualSpeed and RateLossPRID)
-- 2.0		2020-12-01		Pablo Galanzini		FO-04637: Code Change to ELP calculations. ELP calculation will be changed to 
--												(ELP Downtime + ELP Rateloss Downtime) / Paper Runtime. 
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================
CREATE PROCEDURE [dbo].[spRptConvertingDDS]
--DECLARE
	 @strLineId			NVARCHAR(MAX)
	,@timeOption		INT
	,@strNPT			NVARCHAR(MAX)	= ''
	,@dtmStartTime		DATETIME		= NULL
	,@dtmEndTime		DATETIME		= NULL	

--WITH ENCRYPTION 
AS
SET NOCOUNT ON

-- --------------------------------------------------------------------------------------------------------------------
-- Test
-- --------------------------------------------------------------------------------------------------------------------
--SET @dtmStartTime = '2019-10-31 06:30:00.000'
--SET @dtmEndTime = '2019-11-01 06:30:00.000'
----SET @dtmEndTime = '2019-09-23 06:30'
--SET @strLineId = '222,216,178'	-- Gbay
--SET @strLineId = '222'	-- Gbay
----SET @strLineId = '222'	-- Gbay
----SET @strLineId = '240'	-- Cape
----SET @strLineId = '142'	-- Cape
--SET @strNPT = 'PR In:Line Normal,PR Out:Brand Development,PR Out:Brand Project,PR Out:EO Non-Shippable,PR Out:Line Not Staffed,PR Out:STNU'
--SET @timeOption = 1

--exec [dbo].[spRptConvertingDDS] @strLineId, @timeOption, @strNPT, @dtmStartTime, @dtmEndTime
--return

--SELECT 'DATES', @dtmStartTime, @dtmEndTime

-- test Lab0018
--exec [dbo].[spRptConvertingDDS] '178,222,216,219,103,44', -1, 'PR In:Line Normal,PR Out:Brand Development,PR Out:Brand Project,PR Out:EO Non-Shippable,PR Out:Line Not Staffed,PR Out:STNU',  '2019-07-01 05:30', '2019-07-10 05:30'

-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
DECLARE		@strTimeOption	NVARCHAR(50)
---------------------------------------------------------------------------------------------------

-----------------------------------------------------------------------
-- this table will hold Prod Units data for Converting lines
-----------------------------------------------------------------------
if OBJECT_ID('tempdb..#LinesUnits') IS NOT NULL
BEGIN
	DROP TABLE #LinesUnits
END
CREATE TABLE #LinesUnits (
		PLId						INTEGER,
		PLDesc						VARCHAR(100),
		PUId						INTEGER PRIMARY KEY,
		PUDesc						VARCHAR(100),
		CombinedPUDesc				VARCHAR(100),
		OrderIndex					INTEGER DEFAULT 1,
		--EquipmentType				VARCHAR(100),
		DelayType					VARCHAR(255),
		StartTime					DATETIME,
		EndTime						DATETIME,
		RcdIdx						INTEGER IDENTITY)
-----------------------------------------------------------------------
DECLARE @Equipment TABLE (
		RcdIdx						INT IDENTITY	,						
		--PUId						INT				,
		--PUDesc						NVARCHAR(255)	,
		PLId						INT				,
		PLDesc						NVARCHAR(255)	,
		StartTime					DATETIME		,
		EndTime						DATETIME		)
-----------------------------------------------------------------------------------------------------------------------
if OBJECT_ID('tempdb..#dataQuality') IS NOT NULL
BEGIN
	DROP TABLE #dataQuality
END
CREATE TABLE #dataQuality (
		PUId			INT				, 
		Unit			NVARCHAR(255)	, 
		LineStatus		NVARCHAR(63)	, 
		StartTime		DATETIME		, 
		EndTime			DATETIME		, 
		ClockHrs		INT				);
-----------------------------------------------------------------------------------------------------------------------		
-- (Ver. 1.4)
-----------------------------------------------------------------------------------------------------------------------	
if OBJECT_ID('tempdb..#SplitUptime') IS NOT NULL
BEGIN
	DROP TABLE #SplitUptime
END

CREATE TABLE #SplitUptime (		
		PLID				INTEGER DEFAULT 0,
		PUID				INTEGER DEFAULT 0,
		PLDesc				VARCHAR(100),
		PUDesc				VARCHAR(100),
		CombinedPUDesc		VARCHAR(100),
		tedetid				INTEGER DEFAULT 0,
		StartTime			DATETIME,
		EndTime				DATETIME,
		teamdesc			VARCHAR(10),
		duration			FLOAT DEFAULT 0,
		Uptime				FLOAT DEFAULT 0,
		Total_Uptime		FLOAT DEFAULT 0,
		SplitUptime			FLOAT DEFAULT 0,
		R2Numerator			INT)

----------------------------------------------------------------------------------
-- @CrewSchedule will hold information pertaining to the crew AND shift schedule
---------------------------------------------------------------------------------
DECLARE @CrewSchedule TABLE	(
		CS_Id						INTEGER,					
		Start_Time					DATETIME,
		End_Time					DATETIME,
		pu_id						INT,
		pl_id						INT,
		Crew_Desc					VARCHAR(10),
		Shift_Desc					VARCHAR(10))

----------------------------------------------------------------------------------------------------------------------
-- (Ver. 1.4)
-----------------------------------------------------------------------------------------------------------------------		
if OBJECT_ID('tempdb..#DDSStopTeam') IS NOT NULL
BEGIN
	DROP TABLE #DDSStopTeam
END

CREATE TABLE #DDSStopTeam (	
			PlId					INT,
			ProductionLine			VARCHAR(100),
			PUId					INT,
			MasterUnit				VARCHAR(100),
			TeamDesc				VARCHAR(25) ,
			ShiftDesc				VARCHAR(25) ,
			inOutput				INT DEFAULT 1,
			orderOut				INT,
			TotalStops				INT,
			UnscheduledStops		INT,
			UnscheduledStopsByDay	NVARCHAR(255),
			UnscheduledStopsDayValue	INT DEFAULT 0,
			MinorStops				INT,
			EquipmentFailures		INT,
			ProcessFailures			INT,
			SplitDowntime			FLOAT,
			UnscheduledSplitDT		FLOAT,
			RawUptime				FLOAT,
			SplitUptime				FLOAT,
			PlannedAvailabilityVal	FLOAT DEFAULT 0,
			PlannedAvailability		NVARCHAR(255) ,
			UnplannedMTBFVal		FLOAT DEFAULT 0,
			UnplannedMTBF			NVARCHAR(255) ,
			UnplannedMTTRVal		FLOAT DEFAULT 0,
			UnplannedMTTR			NVARCHAR(255) ,
			StopswithUptime2Min		INT DEFAULT 0,
			R2Denominator			INT,
			R2						NVARCHAR(255),
			--
			ELPStops				INT,
			ELPLossesMins			FLOAT,
			ELPVal					FLOAT DEFAULT 0,
			ELP						NVARCHAR(255) ,
			-- FO-04637
			ELPDowntime				FLOAT	DEFAULT 0, 
			RLELPDowntime			FLOAT	DEFAULT 0, 
			--
			RateLossEvents			INT DEFAULT 0,
			RawRateLoss				FLOAT DEFAULT 0,
			--
			RL_EffectiveDT			FLOAT DEFAULT 0,
			RL_LineActualSpeed		FLOAT DEFAULT 0,
			--RateLossPercent			FLOAT,
			RateLossPercent			NVARCHAR(255),
			PaperRuntime			FLOAT DEFAULT 0,
			ProductionTime			FLOAT,
			PRPolyChangeEvents		INT,
			PRPolyChangeDowntime	FLOAT,
			AvgPRPolyChangeTimeVal	FLOAT DEFAULT 0,
			AvgPRPolyChangeTime		NVARCHAR(255),
			UPDT					NVARCHAR(255))

---------------------------------------------------------------------------------------------------------------------------
--	table of downtime's data
---------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#OpsDBDowntimeUptimeData', 'U') IS NOT NULL  
	DROP TABLE #OpsDBDowntimeUptimeData

CREATE TABLE #OpsDBDowntimeUptimeData (
		RcdIdx					INT NOT NULL,
		StartTime				DATETIME NULL,
		EndTime					DATETIME NULL,
		Duration				DECIMAL(12, 3) NULL,
		Total_Uptime			FLOAT NULL,
		Uptime					DECIMAL(12, 3) NULL,
		RawRateloss				FLOAT NULL,
		RateLossRatio			FLOAT NULL,
		-- Rate Loss
		EffectiveDowntime		FLOAT DEFAULT 0,
		LineActualSpeed			FLOAT DEFAULT 0,
		RateLossPRID			NVARCHAR(50) NULL,
		--
		Fault					VARCHAR(100) NULL,
		FaultCode				VARCHAR(30) NULL,
		Reason1Id				INT NULL,
		Reason1					VARCHAR(100) NULL,
		Reason1Code				VARCHAR(30) NULL,
		Reason1Category			VARCHAR(500) NULL,
		Reason2Id				INT NULL,
		Reason2					VARCHAR(100) NULL,
		Reason2Code				VARCHAR(30) NULL,
		Reason2Category			VARCHAR(500) NULL,
		Reason3Id				INT NULL,
		Reason3					VARCHAR(100) NULL,
		Reason3Code				VARCHAR(30) NULL,
		Reason3Category			VARCHAR(500) NULL,
		Reason4Id				INT NULL,
		Reason4					VARCHAR(100) NULL,
		Reason4Code				VARCHAR(30) NULL,
		Reason4Category			VARCHAR(500) NULL,
		Action1					VARCHAR(100) NULL,
		Action1Code				VARCHAR(30) NULL,
		Action2					VARCHAR(100) NULL,
		Action2Code				VARCHAR(30) NULL,
		Action3					VARCHAR(100) NULL,
		Action3Code				VARCHAR(30) NULL,
		Action4					VARCHAR(100) NULL,
		Action4Code				VARCHAR(30) NULL,
		Comments				NVARCHAR(MAX),
		Planned					FLOAT NULL,
		Location				VARCHAR(100) NULL,
		ProdDesc				NVARCHAR(255) NULL,
		ProdCode				VARCHAR(25) NULL,
		ProdFam					NVARCHAR(100) NULL,
		ProdGroup				NVARCHAR(100) NULL,
		ProcessOrder			NVARCHAR(50) NULL,
		TeamDesc				VARCHAR(25) NULL,
		ShiftDesc				VARCHAR(25) NULL,
		LineStatus				NVARCHAR(50) NULL,
		DTStatus				INT NULL,
		PLDesc					VARCHAR(100) NULL,
		PUDesc					VARCHAR(200) NULL,
		PUID					INT NULL,
		PLID					INT NULL,
		BreakDown				FLOAT NULL,
		ProcFailure				FLOAT NULL,
		TransferFlag			INT NULL,
		DeleteFlag				FLOAT NOT NULL,
		Site					VARCHAR(50) NULL,
		TEDetId					INT NOT NULL,
		Ts						DATETIME NULL,
		IsContraint				FLOAT NULL,
		ProductionDay			DATE NULL,
		IsStarved				FLOAT NULL,
		IsBlocked				FLOAT NULL,
		ManualStops				FLOAT NOT NULL,
		MinorStop				INT NULL,
		MajorStop				INT NULL,
		ZoneDesc				NVARCHAR(255) NULL,
		ZoneGrpDesc				NVARCHAR(255) NULL,
		LineGroup				NVARCHAR(255) NULL,
		StopsEquipFails			INT NULL,
		StopsELP				INT NULL,
		StopsScheduled			INT NULL,
		StopsUnscheduled		INT NULL,
		StopsUnscheduledInternal INT NULL,
		StopsUnscheduledBS		INT NULL,
		StopsBlockedStarved		INT NULL,
		ERTD_ID					INT NULL,
		Repulper_Tons			DECIMAL(12, 3) NULL)


---------------------------------------------------------------------------------------------------------------------------
--	table of elp's data
---------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#OpsDBELPData', 'U') IS NOT NULL  
	DROP TABLE #OpsDBELPData

CREATE TABLE #OpsDBELPData (
		RcdIdx				INT  NOT NULL,
		Site				VARCHAR(50) NULL,
		PRConvStartTime		DATETIME NULL,
		PRConvEndTime		DATETIME NULL,
		PLId				INT NULL,
		PLDesc				VARCHAR(75) NULL,
		PUId				INT NULL,
		PUDesc				VARCHAR(200) NULL,
		NPTStatus			VARCHAR(50) NULL,
		ProcessOrder		VARCHAR(50) NULL,
		ProdId				INT NULL,
		ProdCode			VARCHAR(50) NULL,
		ProdDesc			VARCHAR(255) NULL,
		ProdFam				VARCHAR(100) NULL,
		ProdGroup			VARCHAR(100) NULL,
		ParentType			INT NULL,
		ParentPRID			VARCHAR(50) NULL,
		ParentPM			VARCHAR(50) NULL,
		ParentTeam			VARCHAR(15) NULL,
		ParentPLId			INT NULL,
		ParentPLDesc		NVARCHAR(50) NULL,
		ParentPUId			INT NULL,
		ParentPUDesc		NVARCHAR(50) NULL,
		GrandParentPRID		NVARCHAR(50) NULL,
		GrandParentPM		NVARCHAR(50) NULL,
		GrandParentTeam		NVARCHAR(15) NULL,
		PM					NVARCHAR(50) NULL,
		PMTeam				NVARCHAR(15) NULL,
		PaperSource			VARCHAR(50) NULL,
		PaperRunBy			VARCHAR(50) NULL,
		INTR				VARCHAR(50) NULL,
		EventId				INT NULL,
		SourceId			INT NULL,
		EventNum			VARCHAR(50) NULL,
		EventTimestamp		DATETIME NULL,
		UWS					VARCHAR(200) NULL,
		InputOrder			INT NULL,
		ParentRollTimestamp DATETIME NULL,
		ParentRollAge		FLOAT NULL,
		TotalRuntime		FLOAT NULL,
		TotalRolls			INT NULL,
		FreshRolls			INT NULL,
		StorageRolls		INT NULL,
		TotalStops			INT NULL,
		TotalDowntime		FLOAT NULL,
		TotalRateLossDT		FLOAT NULL,
		TotalScheduledDT	FLOAT NULL,
		PaperRuntime		FLOAT NULL,
		StartTimeLine		DATETIME NULL,
		EndTimeLine			DATETIME NULL,
		TotalRuntimeLine	FLOAT NULL,
		TotalStopsLine		INT NULL,
		TotalDowntimeLine	FLOAT NULL,
		TotalRateLossDTLine FLOAT NULL,
		TotalScheduledDTLine FLOAT NULL,
		TotalFreshRuntimeLine FLOAT NULL,
		TotalFreshStopsLine INT NULL,
		TotalFreshDowntimeLine FLOAT NULL,
		TotalFreshRateLossDTLine FLOAT NULL,
		TotalFreshScheduledDTLine FLOAT NULL,
		TotalStorageRuntimeLine FLOAT NULL,
		TotalStorageStopsLine INT NULL,
		TotalStorageDowntimeLine FLOAT NULL,
		TotalStorageRateLossDTLine FLOAT NULL,
		TotalStorageScheduledDTLine FLOAT NULL,
		StartTimeLinePS DATETIME NULL,
		EndTimeLinePS DATETIME NULL,
		TotalRuntimeLinePS FLOAT NULL,
		TotalStopsLinePS INT NULL,
		TotalDowntimeLinePS FLOAT NULL,
		TotalRateLossDTLinePS FLOAT NULL,
		TotalScheduledDTLinePS FLOAT NULL,
		TotalFreshRuntimeLinePS FLOAT NULL,
		TotalFreshStopsLinePS INT NULL,
		TotalFreshDowntimeLinePS FLOAT NULL,
		TotalFreshRateLossDTLinePS FLOAT NULL,
		TotalFreshScheduledDTLinePS FLOAT NULL,
		TotalStorageRuntimeLinePS FLOAT NULL,
		TotalStorageStopsLinePS INT NULL,
		TotalStorageDowntimeLinePS FLOAT NULL,
		TotalStorageRateLossDTLinePS FLOAT NULL,
		TotalStorageScheduledDTLinePS FLOAT NULL,
		StartTimeIntrPL DATETIME NULL,
		EndTimeIntrPL DATETIME NULL,
		TotalRuntimeIntrPL FLOAT NULL,
		TotalStopsIntrPL INT NULL,
		TotalDowntimeIntrPL FLOAT NULL,
		TotalRateLossDTIntrPL FLOAT NULL,
		TotalScheduledDTIntrPL FLOAT NULL,
		TotalFreshRuntimeIntrPL FLOAT NULL,
		TotalFreshStopsIntrPL INT NULL,
		TotalFreshDowntimeIntrPL FLOAT NULL,
		TotalFreshRateLossDTIntrPL FLOAT NULL,
		TotalFreshScheduledDTIntrPL FLOAT NULL,
		TotalStorageRuntimeIntrPL FLOAT NULL,
		TotalStorageStopsIntrPL INT NULL,
		TotalStorageDowntimeIntrPL FLOAT NULL,
		TotalStorageRateLossDTIntrPL FLOAT NULL,
		TotalStorageScheduledDTIntrPL FLOAT NULL,
		StartTimePMRunBy DATETIME NULL,
		EndTimePMRunBy DATETIME NULL,
		TotalRuntimePMRunBy FLOAT NULL,
		TotalStopsPMRunBy INT NULL,
		TotalDowntimePMRunBy FLOAT NULL,
		TotalRateLossDTPMRunBy FLOAT NULL,
		TotalScheduledDTPMRunBy FLOAT NULL,
		TotalFreshRuntimePMRunBy FLOAT NULL,
		TotalFreshStopsPMRunBy INT NULL,
		TotalFreshDowntimePMRunBy FLOAT NULL,
		TotalFreshRateLossDTPMRunBy FLOAT NULL,
		TotalFreshScheduledDTPMRunBy FLOAT NULL,
		TotalStorageRuntimePMRunBy FLOAT NULL,
		TotalStorageStopsPMRunBy INT NULL,
		TotalStorageDowntimePMRunBy FLOAT NULL,
		TotalStorageRateLossDTPMRunBy FLOAT NULL,
		TotalStorageScheduledDTPMRunBy FLOAT NULL,
		TS				DATETIME NULL,
		DeleteFlag		BIT NULL)



---------------------------------------------------------------------------------------------------------------------------
--	table of elp's data
---------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#OpsDBProdCvtg', 'U') IS NOT NULL  
	DROP TABLE #OpsDBProdCvtg

CREATE TABLE #OpsDBProdCvtg (
		[RecordID] [int] NOT NULL,
		[SITE] [varchar](50) NULL,
		[ProcessOrder] [varchar](100) NULL,
		[PLId] [int] NULL,
		[PUId] [int] NULL,
		[EventId] [int] NULL,
		[StartTime] [datetime] NULL,
		[EndTime] [datetime] NULL,
		[StartTimeUTC] [datetimeoffset](7) NULL,
		[EndTimeUTC] [datetimeoffset](7) NULL,
		[ProdId] [int] NULL,
		[PLDesc] [varchar](50) NULL,
		[ReliabilityPUID] [int] NULL,
		[PUDesc] [varchar](50) NULL,
		[ShiftDesc] [varchar](100) NULL,
		[TeamDesc] [varchar](100) NULL,
		[ProdCode] [varchar](50) NULL,
		[ProdDesc] [varchar](100) NULL,
		[ProdFamily] [varchar](100) NULL,
		[ProdGroup] [varchar](100) NULL,
		[PPId] [int] NULL,
		[POStatus] [varchar](50) NULL,
		[PPStatusId] [int] NULL,
		[BatchNumber] [varchar](100) NULL,
		[TotalUnits] [float] NULL,
		[GoodUnits] [float] NULL,
		[RejectUnits] [float] NULL,
		[WebWidth] [float] NULL,
		[SheetWidth] [float] NULL,
		[LineSpeedIdeal] [float] NULL,
		[LineSpeedTarget] [float] NULL,
		[LineSpeedAvg] [float] NULL,
		[TargetLineSpeed] [float] NULL,
		[LineStatus] [varchar](50) NULL,
		[RollsPerLog] [float] NULL,
		[RollsInPack] [float] NULL,
		[PacksInBundle] [float] NULL,
		[CartonsInCase] [float] NULL,
		[SheetCount] [float] NULL,
		[ShipUnit] [int] NULL,
		[CalendarRuntime] [float] NULL,
		[ProductionRuntime] [float] NULL,
		[PlanningRuntime] [float] NULL,
		[OperationsRuntime] [float] NULL,
		[SheetLength] [float] NULL,
		[StatFactor] [float] NULL,
		[TargetUnits] [float] NULL,
		[ActualUnits] [float] NULL,
		[OperationsTargetUnits] [float] NULL,
		[HolidayCurtailDT] [float] NULL,
		[PlninterventionDT] [float] NULL,
		[ChangeOverDT] [float] NULL,
		[HygCleaningDT] [float] NULL,
		[EOProjectsDT] [float] NULL,
		[UnscheduledDT] [float] NULL,
		[CLAuditsDT] [float] NULL,
		[IdealUnits] [float] NULL,
		[RollWidth2Stage] [float] NULL,
		[RollWidth3Stage] [float] NULL,
		[SplitUptime] [float] NULL,
		[Runtime] [float] NULL,
		[CnvtLineSpeedToSheetLength] [float] NULL,
		[CnvtParentRollWidthToSheetWidth] [float] NULL,
		[DefaultPMRollWidth] [float] NULL,
		[LineSpeedUOM] [varchar](10) NULL,
		[SheetLengthSpec] [float] NULL,
		[SheetLengthSpecUOM] [varchar](10) NULL,
		[SheetWidthSpec] [float] NULL,
		[SheetWidthSpecUOM] [varchar](10) NULL,
		[PlannedRejectLogs] [int] NULL,
		[UnplannedRejectLogs] [int] NULL,
		[BreakoutRejectLogs] [int] NULL,
		[ManualRejectLogs] [int] NULL,
		[OtherRejectLogs] [int] NULL,
		[ILOCSetpointTarget] [float] NULL,
		[ILOCSetpointAverage] [float] NULL,
		[ILOCSetpointSampleCount] [float] NULL,
		[ILOCActualAverage] [float] NULL,
		[ILOCActualSampleCount] [float] NULL,
		[ts] [datetime] NULL,
		[deleteflag] [int] NULL)

----------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO @Equipment(PLId) 
	SELECT String FROM fnLocal_Split(@strLineId,',')

-- --------------------------------------------------------------------------------------------------------------------
-- Update @Equipment table WITH all the needed values
-- --------------------------------------------------------------------------------------------------------------------
UPDATE e
	SET PLDesc	= (SELECT LineDesc 
							FROM dbo.LINE_DIMENSION ld
							WHERE ld.PLId = e.PLId)
	FROM @Equipment e
	
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #LinesUnits	(
			PUId			,
			PUDesc			,
			CombinedPUDesc	,
			--EquipmentType	
			DelayType		,
			PLId			,
			PLDesc			,
			StartTime		,
			EndTime			)
	SELECT 
			w.PUId			,
			w.PUDesc		,
			w.PUDesc		,
			--EquipmentType	
			dbo.fnLocal_GlblParseInfo(w.Extended_Info, 'DelayType='), 
			w.PLId			,
			l.linedesc		,
			@dtmStartTime	,
			@dtmEndTime
		FROM [Auto_opsDataStore].[dbo].[WorkCell_Dimension]	w	WITH (NOLOCK)
		JOIN [Auto_opsDataStore].[dbo].[Line_Dimension]		l	WITH (NOLOCK)
															ON w.plid = l.plid 
		WHERE w.PLID IN (SELECT String FROM fnLocal_Split(@strLineId,','))
			AND dbo.fnLocal_GlblParseInfo(w.Extended_Info, 'DelayType=') IN ('CvtrDowntime','Downtime','Rateloss','BlockedStarved')
			-- test
			--and w.PUId = 1072
			
-----------------------------------------------------------------------------------------------------------------------
UPDATE pu 
	SET CombinedPUDesc = REPLACE(CombinedPUDesc,'Blocked/Starved','Reliability') 
	FROM #LinesUnits pu
	WHERE CombinedPUDesc LIKE '%Block%Starv%'

UPDATE pu 
	SET CombinedPUDesc = RTRIM(REPLACE(CombinedPUDesc,'Reliability','Reliability & Blocked/Starved')) 
	FROM #LinesUnits pu
	WHERE (SELECT COUNT(*)
				FROM #LinesUnits pu2
				WHERE pu2.CombinedPUDesc = pu.CombinedPUDesc
		) > 1

UPDATE pu 
	SET OrderIndex = 0
	FROM #LinesUnits pu
	WHERE pu.CombinedPUDesc LIKE '%Converter Reliability%'
	
-----------------------------------------------------------------------------------------------------------------------
--Set the Start & End Time
-----------------------------------------------------------------------------------------------------------------------
IF @timeOption = -1
BEGIN
	UPDATE e 
		SET	e.StartTime = @dtmStartTime, 
			e.EndTime = @dtmEndTime
		FROM @Equipment e 

END
ELSE
BEGIN
	SELECT @strTimeOption = DateDesc 
		FROM [dbo].[DATE_DIMENSION] (NOLOCK)
		WHERE DateId = @timeOption

	UPDATE e 
		SET	 e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
		FROM @Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f		

END

-----------------------------------------------------------------------------------------------------------------------
-- Update dates
-----------------------------------------------------------------------------------------------------------------------
SELECT TOP 1 @dtmStartTime = e.StartTime
	FROM @Equipment e 
		
SELECT TOP 1 @dtmEndTime = e.EndTime
	FROM @Equipment e 
		
UPDATE l 
	SET	 l.StartTime = e.StartTime, l.EndTime =	e.EndTime
	FROM #LinesUnits	l 
	JOIN @Equipment		e ON l.plid = e.plid

--select '@Equipment-TEST', @dtmStartTime, @dtmEndTime, * from @Equipment
--SELECT '#LinesUnits',  * FROM #LinesUnits 
--return

-----------------------------------------------------------------------------------------------------------------------
-- Fill temp table WITH all downtime data needed.
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #OpsDBDowntimeUptimeData
	SELECT 
		 du.RcdIdx			
		,du.StartTime		
		--,CASE WHEN du.EndTime IS NULL THEN GETDATE() ELSE du.EndTime END
		, du.EndTime
		,Duration			
		,Total_Uptime		
		,Uptime				
		,RawRateloss			 
		,RateLossRatio			 
		-- Rate Loss
		,EffectiveDowntime		
		,LineActualSpeed		
		,RateLossPRID			
		--
		,Fault				
		,FaultCode			
		,Reason1Id			
		,Reason1			
		,Reason1Code		
		,Reason1Category	
		,Reason2Id			
		,Reason2			
		,Reason2Code		
		,Reason2Category	
		,Reason3Id			
		,Reason3			
		,Reason3Code		
		,Reason3Category	
		,Reason4Id			
		,Reason4			
		,Reason4Code		
		,Reason4Category	
		,Action1			
		,Action1Code		
		,Action2			
		,Action2Code		
		,Action3			
		,Action3Code		
		,Action4			
		,Action4Code		
		,Comments			
		,Planned			
		,Location			
		,ProdDesc			
		,ProdCode			
		,ProdFam			
		,ProdGroup			
		,ProcessOrder		
		,TeamDesc			
		,ShiftDesc			
		,LineStatus			
		,DTStatus			
		,du.PLDesc			
		,du.PUDesc			
		,du.PUID			
		,du.PLID			
		,BreakDown			
		,ProcFailure		
		,TransferFlag		
		,DeleteFlag			
		,Site				
		,TEDetId			
		,Ts					
		,IsContraint		
		,ProductionDay		
		,IsStarved			
		,IsBlocked			
		,ManualStops		
		,MinorStop			
		,MajorStop			
		,ZoneDesc			
		,ZoneGrpDesc		
		,LineGroup			
		,StopsEquipFails	
		,StopsELP			
		,StopsScheduled		
		,StopsUnscheduled	
		,StopsUnscheduledInternal
		,StopsUnscheduledBS		
		,StopsBlockedStarved	 
		,ERTD_ID				 
		,Repulper_Tons			 	
		FROM [Auto_opsDataStore].[dbo].[OpsDB_DowntimeUptime_Data]	du	WITH(NOLOCK)
		JOIN #LinesUnits										l	ON du.PLId = l.PLID
																	AND du.PUId = l.PUId
																	AND du.StartTime < l.EndTime 
																	AND du.EndTime > l.StartTime 
																		--OR du.EndTime IS NULL)
																	AND du.deleteFlag = 0
																	AND du.LineStatus IN (SELECT String FROM fnLocal_Split(@strNPT,','))

--select '#OpsDBDowntimeUptimeData',TEDetId, PLDESC, starttime, Duration, RawRateloss, RateLossRatio, EffectiveDowntime,LineActualSpeed,RateLossPRID
--	, * from #OpsDBDowntimeUptimeData d
--	--where [EffectiveDowntime] > 0
--	where IsContraint = 1
--		AND	(Reason2Category like '%Category:Paper (ELP)%' OR Reason1Category like '%Category:Paper (ELP)%')
--	order by d.PLDESC, d.starttime
--return

-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #OpsDBELPData
	SELECT 		
		elp.RcdIdx				   ,
		Site				 ,
		PRConvStartTime		 ,
		PRConvEndTime		 ,
		elp.PLId				 ,
		elp.PLDesc				 ,
		PUId				 ,
		PUDesc				 ,
		NPTStatus			 ,
		ProcessOrder		 ,
		ProdId				 ,
		ProdCode			 ,
		ProdDesc			 ,
		ProdFam				 ,
		ProdGroup			 ,
		ParentType			 ,
		ParentPRID			 ,
		ParentPM			 ,
		ParentTeam			 ,
		ParentPLId			 ,
		ParentPLDesc		 ,
		ParentPUId			 ,
		ParentPUDesc		 ,
		GrandParentPRID		 ,
		GrandParentPM		 ,
		GrandParentTeam		 ,
		PM					 ,
		PMTeam				 ,
		PaperSource			 ,
		PaperRunBy			 ,
		INTR				 ,
		EventId				 ,
		SourceId			 ,
		EventNum			 ,
		EventTimestamp		 ,
		UWS					 ,
		InputOrder			 ,
		ParentRollTimestamp  ,
		ParentRollAge		 ,
		TotalRuntime		 ,
		TotalRolls			 ,
		FreshRolls			 ,
		StorageRolls		 ,
		TotalStops			 ,
		TotalDowntime		 ,
		TotalRateLossDT		 ,
		TotalScheduledDT	 ,
		PaperRuntime		 ,
		StartTimeLine		 ,
		EndTimeLine			 ,
		TotalRuntimeLine	 ,
		TotalStopsLine		 ,
		TotalDowntimeLine	 ,
		TotalRateLossDTLine  ,
		TotalScheduledDTLine  ,
		TotalFreshRuntimeLine  ,
		TotalFreshStopsLine  ,
		TotalFreshDowntimeLine  ,
		TotalFreshRateLossDTLine  ,
		TotalFreshScheduledDTLine  ,
		TotalStorageRuntimeLine  ,
		TotalStorageStopsLine  ,
		TotalStorageDowntimeLine  ,
		TotalStorageRateLossDTLine  ,
		TotalStorageScheduledDTLine  ,
		StartTimeLinePS  ,
		EndTimeLinePS  ,
		TotalRuntimeLinePS  ,
		TotalStopsLinePS  ,
		TotalDowntimeLinePS  ,
		TotalRateLossDTLinePS  ,
		TotalScheduledDTLinePS  ,
		TotalFreshRuntimeLinePS  ,
		TotalFreshStopsLinePS  ,
		TotalFreshDowntimeLinePS  ,
		TotalFreshRateLossDTLinePS  ,
		TotalFreshScheduledDTLinePS  ,
		TotalStorageRuntimeLinePS  ,
		TotalStorageStopsLinePS  ,
		TotalStorageDowntimeLinePS  ,
		TotalStorageRateLossDTLinePS  ,
		TotalStorageScheduledDTLinePS  ,
		StartTimeIntrPL  ,
		EndTimeIntrPL  ,
		TotalRuntimeIntrPL  ,
		TotalStopsIntrPL  ,
		TotalDowntimeIntrPL  ,
		TotalRateLossDTIntrPL  ,
		TotalScheduledDTIntrPL  ,
		TotalFreshRuntimeIntrPL  ,
		TotalFreshStopsIntrPL  ,
		TotalFreshDowntimeIntrPL  ,
		TotalFreshRateLossDTIntrPL  ,
		TotalFreshScheduledDTIntrPL  ,
		TotalStorageRuntimeIntrPL  ,
		TotalStorageStopsIntrPL  ,
		TotalStorageDowntimeIntrPL  ,
		TotalStorageRateLossDTIntrPL  ,
		TotalStorageScheduledDTIntrPL  ,
		StartTimePMRunBy  ,
		EndTimePMRunBy  ,
		TotalRuntimePMRunBy  ,
		TotalStopsPMRunBy  ,
		TotalDowntimePMRunBy  ,
		TotalRateLossDTPMRunBy  ,
		TotalScheduledDTPMRunBy  ,
		TotalFreshRuntimePMRunBy  ,
		TotalFreshStopsPMRunBy  ,
		TotalFreshDowntimePMRunBy  ,
		TotalFreshRateLossDTPMRunBy  ,
		TotalFreshScheduledDTPMRunBy  ,
		TotalStorageRuntimePMRunBy  ,
		TotalStorageStopsPMRunBy  ,
		TotalStorageDowntimePMRunBy  ,
		TotalStorageRateLossDTPMRunBy  ,
		TotalStorageScheduledDTPMRunBy  ,
		TS				 ,
		DeleteFlag		 
	FROM [Auto_opsDataStore].[dbo].[OpsDB_ELP_Data]	elp	WITH(NOLOCK)
	JOIN @Equipment								e	ON elp.PLId = e.PLId
													AND elp.PRConvStartTime < e.EndTime 
													AND (elp.PRConvEndTime > e.StartTime OR elp.PRConvEndTime IS NULL)
													AND elp.deleteFlag = 0

-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #OpsDBProdCvtg
		SELECT 
			RecordID  ,
			SITE  ,
			ProcessOrder  ,
			c.PLId  ,
			PUId  ,
			EventId  ,
			c.StartTime  ,
			c.EndTime  ,
			StartTimeUTC  ,
			EndTimeUTC  ,
			ProdId  ,
			c.PLDesc  ,
			ReliabilityPUID  ,
			PUDesc  ,
			ShiftDesc  ,
			TeamDesc  ,
			ProdCode  ,
			ProdDesc  ,
			ProdFamily  ,
			ProdGroup  ,
			PPId  ,
			POStatus  ,
			PPStatusId  ,
			BatchNumber  ,
			TotalUnits  ,
			GoodUnits  ,
			RejectUnits  ,
			WebWidth  ,
			SheetWidth  ,
			LineSpeedIdeal  ,
			LineSpeedTarget  ,
			LineSpeedAvg  ,
			TargetLineSpeed  ,
			LineStatus  ,
			RollsPerLog  ,
			RollsInPack  ,
			PacksInBundle  ,
			CartonsInCase  ,
			SheetCount  ,
			ShipUnit  ,
			CalendarRuntime  ,
			ProductionRuntime  ,
			PlanningRuntime  ,
			OperationsRuntime  ,
			SheetLength  ,
			StatFactor  ,
			TargetUnits  ,
			ActualUnits  ,
			OperationsTargetUnits  ,
			HolidayCurtailDT  ,
			PlninterventionDT  ,
			ChangeOverDT  ,
			HygCleaningDT  ,
			EOProjectsDT  ,
			UnscheduledDT  ,
			CLAuditsDT  ,
			IdealUnits  ,
			RollWidth2Stage  ,
			RollWidth3Stage  ,
			SplitUptime  ,
			Runtime  ,
			CnvtLineSpeedToSheetLength  ,
			CnvtParentRollWidthToSheetWidth  ,
			DefaultPMRollWidth  ,
			LineSpeedUOM  ,
			SheetLengthSpec  ,
			SheetLengthSpecUOM  ,
			SheetWidthSpec  ,
			SheetWidthSpecUOM  ,
			PlannedRejectLogs  ,
			UnplannedRejectLogs  ,
			BreakoutRejectLogs  ,
			ManualRejectLogs  ,
			OtherRejectLogs  ,
			ILOCSetpointTarget  ,
			ILOCSetpointAverage  ,
			ILOCSetpointSampleCount  ,
			ILOCActualAverage  ,
			ILOCActualSampleCount  ,
			ts  ,
			deleteflag  
		FROM [dbo].[OpsDB_Production_Data_Cvtg]	c	(NOLOCK) 
		JOIN @Equipment							e	ON c.PLId = e.PLId
													AND c.StartTime < e.EndTime 
													AND (c.EndTime > e.StartTime OR c.EndTime IS NULL)
													AND c.deleteFlag = 0

-----------------------------------------------------------------------------------------------------------------------
--SELECT 'RawData IODS', plid, pldesc, sum(p.ProductionRuntime) ProductionRuntime, sum(p.ProductionRuntime)/1440.0 NumDays, 
--	sum(p.actualunits) actualunits, sum(p.TargetUnits) TargetUnits, 
--	-- PRB0072349 (Issues with Operating Efficiency, CVTI, Production time, Rate Loss (and possibly other KPIs) in the CVGT DDS Report for FC)
--	SUM(p.OperationsTargetUnits) OperationsTargetUnits, SUM(CONVERT(FLOAT,p.IdealUnits)) IdealUnits
--	,CASE WHEN sum(p.TargetUnits) = 0 THEN 0
--		ELSE CONVERT(FLOAT, COALESCE(sum(p.actualunits) , 0)) / ROUND(CONVERT(FLOAT, sum(p.TargetUnits)),0) 
--		END * 100.0 [CVPR %] 
--	,CASE WHEN SUM(CONVERT(FLOAT,p.OperationsTargetUnits)) > 0 
--		THEN SUM(CASE WHEN p.OperationsTargetUnits IS NOT NULL THEN CONVERT(FLOAT,p.ActualUnits) ELSE 0 END) 													
--			/ SUM(CONVERT(FLOAT,p.OperationsTargetUnits))
--		ELSE NULL END * 100.0 [Operations Efficiency %]	
--	,CASE WHEN SUM(CONVERT(FLOAT,p.IdealUnits)) > 0.0 				
--		THEN SUM(CASE WHEN p.IdealUnits IS NOT NULL THEN CONVERT(FLOAT,p.ActualUnits) ELSE 0.0 END) 											
--				  / SUM(CONVERT(FLOAT,p.IdealUnits))
--		ELSE NULL END * 100.0 [CVTI %]
--	FROM #OpsDBProdCvtg p 
--	group by plid, pldesc
	--having sum(p.TargetUnits) > 0

--return

-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #SplitUptime (
			PLID			
			,PUID			
			,PLDesc			
			,PUDesc			
			,CombinedPUDesc	
			,tedetid			
			,StartTime		
			,EndTime			
			,teamdesc		
			,duration		
			,Uptime			
			,Total_Uptime
			, SplitUptime
			, R2Numerator)	
	SELECT	e.PLId, 
			e.puid, 
			e.pldesc, 
			e.pudesc, 
			e.CombinedPUDesc, 
			dd.tedetid, 
			dd.StartTime, 
			dd.EndTime, 
			dd.teamdesc, 
			dd.duration, 
			dd.Uptime, 
			dd.Total_Uptime,
			(SELECT DATEDIFF(ss, (CASE WHEN MAX(e.EndTime) > @dtmStartTime
										THEN MAX(e.EndTime)
										ELSE @dtmStartTime END) , dd.StartTime) / 60.0
							FROM #OpsDBDowntimeUptimeData e (NOLOCK)
							WHERE dd.PLId = e.PLId 
							AND e.DeleteFlag = 0
							AND dd.StartTime > e.StartTime
							AND e.PUId = dd.PUId) SplitUptime,
					(CASE WHEN  Total_Uptime < 2 AND DTStatus = 1 THEN  1  ELSE  0 END) R2Numerator
		FROM #LinesUnits					e	(NOLOCK)	
		JOIN #OpsDBDowntimeUptimeData		dd	(NOLOCK) ON dd.PLId = e.PLId
														AND dd.puid = e.puid
		WHERE dd.StartTime >= e.StartTime 
			AND dd.EndTime <= e.EndTime
			AND dd.DeleteFlag = 0
			AND dd.PUDesc NOT LIKE '%Rate%Loss%'

--select '#SplitUptime', sum(duration) Duration, sum(uptime) Uptime, sum(duration)+sum(uptime) PaperRunTime from #SplitUptime
--	where PUDesc like '%Converter Reliability%'
--select '#SplitUptime', * from #SplitUptime
--	where PUDesc like '%Converter Reliability%'
--return

-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @CrewSchedule (
			CS_Id,				
			Start_Time,
			End_Time,
			pl_id,
			pu_id,
			Crew_Desc,
			Shift_Desc)
	SELECT distinct	
			cs.RecordID,										
			cs.starttime,
			cs.endtime,
			cs.plid,
			pl.puid,
			cs.TeamDesc,
			cs.ShiftDesc
		FROM #OpsDBProdCvtg		cs	WITH (NOLOCK)
		JOIN dbo.#LinesUnits	pu	WITH (NOLOCK) ON cs.puid = pu.PUId
		JOIN dbo.#LinesUnits	pl	WITH (NOLOCK) ON pl.plid = pu.PlId
		WHERE cs.starttime < pu.endtime
			AND (cs.endtime > pu.starttime OR cs.endtime IS NULL)
		OPTION (KEEP PLAN)

--select '#OpsDBProdCvtg', * from #OpsDBProdCvtg
--SELECT '@CrewSchedule', * FROM @CrewSchedule order by pl_id, pu_id, Start_Time
--RETURN

-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #DDSStopTeam	(
			PlId			,
			ProductionLine	,
			PUId			,
			MasterUnit		,
			TeamDesc		,
			ShiftDesc		,
			orderOut		,
			TotalStops		,
			UnscheduledStops,
			EquipmentFailures,
			ProcessFailures	,
			SplitDowntime	,
			UnscheduledSplitDT,
			RawUptime		,
			StopswithUptime2Min,
			--R2Numerator	,
			R2Denominator	,
			ELPStops		,
			ELPDowntime		,
			PRPolyChangeEvents	,
			PRPolyChangeDowntime,
			MinorStops		)
	SELECT	pu.plid			,
			pu.pldesc		,
			pu.puid			,
			pu.PUDesc		,
			cs.Crew_Desc	,
			cs.shift_desc	,
			CASE WHEN pu.PUDesc LIKE  '%Converter Reliability%' THEN 0 ELSE 1 END,
			SUM(dd.dtstatus),
			SUM(CASE WHEN dd.DTStatus = 1 THEN dd.StopsUnscheduled ELSE 0 END),
			SUM(dd.StopsEquipFails),
			SUM(ISNULL(CAST(dd.ProcFailure AS INT),0)),
			SUM(CASE WHEN dd.Location NOT LIKE '%Rate%Loss%'
							AND dd.StartTime >= @dtmStartTime 
							AND (dd.StartTime < @dtmEndTime OR dd.EndTime < @dtmEndTime)
							AND dd.TEDetId IS NOT NULL
					THEN dd.Duration ELSE 0 END) AS SplitDowntime,		
			SUM(CASE WHEN dd.StopsUnscheduled = 1
							AND (pu.pudesc LIKE '%Reliability%' AND pu.pudesc not LIKE '%Converter Reliability%')
						THEN dd.Duration
						WHEN (dd.StopsScheduled = 1 OR dd.StopsBlockedStarved = 1)
							AND (pu.pudesc LIKE '%Converter Reliability%' OR pu.PUDesc LIKE '%Converter Blocked/Starved')
						THEN dd.Duration
				ELSE 0.0 END) AS UnscheduledSplitDT,
			SUM(CASE WHEN (CASE WHEN pu.PUDesc LIKE '%Reliability%'	THEN dd.Uptime ELSE 0.0 END)
								> (CASE WHEN pu.PUDesc LIKE '%Block%Starv%' THEN dd.Duration ELSE 0.0 END)	
							THEN ((CASE WHEN pu.PUDesc LIKE '%Reliability%'	THEN dd.Uptime ELSE 0.0 END)
								- (CASE WHEN pu.PUDesc LIKE '%Block%Starv%' THEN dd.Duration ELSE 0.0 END))
							ELSE 0.0 END) AS RawUptime,
			SUM(CASE WHEN dd.Total_Uptime < 2 AND dd.DTStatus = 1 THEN 1 ELSE 0 END) AS StopswithUptime2Min,
			SUM(CASE 
					WHEN dd.StopsScheduled = 1 
					THEN COALESCE(dd.dtStatus,0)
					ELSE 0.0 
					END) ,
			SUM(CASE WHEN (pu.pudesc LIKE '%Converter Reliability%' 
						AND dd.IsContraint = 1
						AND (dd.Reason2Category like '%Category:Paper (ELP)%' OR dd.Reason1Category like '%Category:Paper (ELP)%')
						--AND dd.StopsELP > 0 
						--AND dd.dtstatus = 1
						)
				THEN dd.StopsELP ELSE 0 END),
			SUM(CASE WHEN (pu.pudesc LIKE '%Converter Reliability%' 
						AND dd.IsContraint = 1
						AND (dd.Reason2Category like '%Category:Paper (ELP)%' OR dd.Reason1Category like '%Category:Paper (ELP)%')
						--AND dd.StopsELP > 0 
						--AND dd.dtstatus = 1
						)
				THEN dd.duration ELSE 0 END) ELPDowntime,
			SUM(IIF (dd.Reason2Category LIKE '%Schedule:PR/Poly Change%' AND dd.DTStatus = 1,1,0)),
			SUM(IIF (dd.Reason2Category LIKE '%Schedule:PR/Poly Change%',dd.duration,0)),
			SUM(dd.MinorStop)
		FROM @CrewSchedule				cs
		JOIN dbo.#LinesUnits			pu	WITH (NOLOCK) ON cs.pl_id = pu.PlId
															AND cs.pu_id = pu.PUId
		JOIN #OpsDBDowntimeUptimeData	dd	WITH (NOLOCK) ON dd.puid = pu.PUId 
											AND dd.plid = pu.PlId
											AND cs.Crew_Desc = dd.TeamDesc
											AND cs.shift_desc = dd.ShiftDesc
											AND dd.starttime < cs.End_Time
											AND dd.endtime > cs.Start_Time
		GROUP BY pu.plid	,
			pu.pldesc		,
			pu.puid			,
			pu.PUDesc		,
			cs.Crew_Desc	,
			cs.shift_desc		
		
-----------------------------------------------------------------------------------------------------------------------
-- Update of RawUptime (INC4746656 12-05-2019)
-----------------------------------------------------------------------------------------------------------------------
UPDATE dds
	SET dds.RawUptime = (SELECT SUM(CASE WHEN (CASE WHEN d.PUDesc LIKE '%Reliability%'	THEN d.Uptime ELSE 0.0 END)
										> (CASE WHEN d.PUDesc LIKE '%Block%Starv%' THEN d.Duration ELSE 0.0 END)	
									THEN ((CASE WHEN d.PUDesc LIKE '%Reliability%'	THEN d.Uptime ELSE 0.0 END)
										- (CASE WHEN d.PUDesc LIKE '%Block%Starv%' THEN d.Duration ELSE 0.0 END))
									ELSE 0.0 END) 
							FROM #OpsDBDowntimeUptimeData	d
							WHERE dds.plid	= d.plid
								AND dds.puid	= d.puid
								AND dds.TeamDesc = d.TeamDesc
								AND dds.ShiftDesc = d.ShiftDesc)
	FROM #DDSStopTeam dds
	
UPDATE #DDSStopTeam
	SET inOutput = 0
	WHERE MasterUnit LIKE '%Rate%Loss%'
		--'%Converter Rate Loss%'
		
-----------------------------------------------------------------------------------------------------------------------
UPDATE u
	SET u.SplitUptime = (SELECT SUM(ISNULL(CASE WHEN (CASE WHEN s.pudesc LIKE '%Reliability%' THEN s.SplitUptime ELSE 0.0 END)
											> (CASE WHEN s.pudesc LIKE '%Block%Starv%' THEN s.Duration ELSE 0.0 END)	
											THEN ((CASE WHEN s.pudesc LIKE '%Reliability%' THEN s.SplitUptime ELSE 0.0 END)
												- (CASE WHEN s.pudesc LIKE '%Block%Starv%' THEN s.Duration ELSE 0.0 END))
											ELSE 0.0 END ,0))
							FROM #SplitUptime	s	
								WHERE s.PLId = u.plid
								AND s.PuId = u.puid
								AND S.teamdesc = u.teamDesc),
		u.R2 = CAST(ISNULL(u.StopswithUptime2Min,0) AS NVARCHAR(10)) + '|' + CAST(ISNULL(u.R2Denominator,0) AS NVARCHAR(10))
		--u.R2	= CASE WHEN u.R2Denominator = 0 THEN 0
		--			ELSE CAST(u.StopswithUptime2Min AS FLOAT)/ u.R2Denominator END
						--(SELECT SUM(s.R2Numerator)
						--	FROM #SplitUptime	s	
						--		WHERE s.PLId = u.plid
						--		AND s.PuId = u.puid
						--		AND S.teamdesc = u.teamDesc) / u.R2Denominator END
	FROM #DDSStopTeam	u
		
-----------------------------------------------------------------------------------------------------------------------
UPDATE u
	SET u.RateLossEvents = (SELECT COUNT(DISTINCT dd.TEDetId)
								FROM #OpsDBDowntimeUptimeData	dd (NOLOCK)
								JOIN #LinesUnits				e	ON dd.PLId = e.PLId
																	AND dd.PuId = e.PuId
								WHERE dd.PuDesc LIKE '%Rate%Loss%'
									--'%Converter Rate Loss%'
									AND dd.PLId = u.plid
									AND dd.shiftDesc = u.shiftDesc
									AND dd.teamdesc = u.teamDesc
									AND ISNULL(dd.RawRateloss,0) > 0)
	FROM #DDSStopTeam	u
	WHERE u.MasterUnit LIKE '%Converter Reliability%'
	
UPDATE u
	SET u.RawRateLoss = (SELECT ISNULL(SUM(dd.RawRateLoss),0)/60.0
										FROM #OpsDBDowntimeUptimeData	dd (NOLOCK)
										JOIN #LinesUnits				e	ON dd.PLId = e.PLId
																			AND dd.PuId = e.PuId
										WHERE dd.PuDesc LIKE '%Rate%Loss%'
											--'%Converter Rate Loss%'
											AND dd.PLId = u.plid
											AND dd.shiftDesc = u.shiftDesc
											AND dd.teamdesc = u.teamDesc
											AND ISNULL(dd.RawRateloss,0) > 0)
	FROM #DDSStopTeam	u
	WHERE u.MasterUnit LIKE '%Converter Reliability%'	
									
UPDATE u
	SET u.RL_EffectiveDT = (SELECT ISNULL(SUM(dd.EffectiveDowntime),0) -- /60.0
										FROM #OpsDBDowntimeUptimeData	dd (NOLOCK)
										JOIN #LinesUnits				e	ON dd.PLId = e.PLId
																			AND dd.PuId = e.PuId
										WHERE dd.PuDesc LIKE '%Rate%Loss%'
											--'%Converter Rate Loss%'
											AND dd.PLId = u.plid
											AND dd.shiftDesc = u.shiftDesc
											AND dd.teamdesc = u.teamDesc
											AND ISNULL(dd.RawRateloss,0) > 0)
	FROM #DDSStopTeam	u
	WHERE u.MasterUnit LIKE '%Converter Reliability%'	

UPDATE u
	SET u.RL_LineActualSpeed = (SELECT ISNULL(SUM(dd.LineActualSpeed),0)/60.0
										FROM #OpsDBDowntimeUptimeData	dd (NOLOCK)
										JOIN #LinesUnits				e	ON dd.PLId = e.PLId
																			AND dd.PuId = e.PuId
										WHERE dd.PuDesc LIKE '%Rate%Loss%'
											--'%Converter Rate Loss%'
											AND dd.PLId = u.plid
											AND dd.shiftDesc = u.shiftDesc
											AND dd.teamdesc = u.teamDesc
											AND ISNULL(dd.RawRateloss,0) > 0)
	FROM #DDSStopTeam	u
	WHERE u.MasterUnit LIKE '%Converter Reliability%'	

-----------------------------------------------------------------------------------
UPDATE u
	SET u.RLELPDowntime = (SELECT ISNULL(SUM(dd.EffectiveDowntime),0) -- /60.0
										FROM #OpsDBDowntimeUptimeData	dd (NOLOCK)
										JOIN #LinesUnits				e	ON dd.PLId = e.PLId
																			AND dd.PuId = e.PuId
										WHERE dd.PuDesc LIKE '%Rate%Loss%'
											--'%Converter Rate Loss%'
											AND dd.PLId = u.plid
											AND dd.shiftDesc = u.shiftDesc
											AND dd.teamdesc = u.teamDesc
											AND dd.IsContraint = 1
											AND	(dd.Reason2Category like '%Category:Paper (ELP)%' OR dd.Reason1Category like '%Category:Paper (ELP)%')
											AND ISNULL(dd.RawRateloss,0) > 0)
	FROM #DDSStopTeam	u
	WHERE u.MasterUnit LIKE '%Converter Reliability%'	

--select '#OpsDBDowntimeUptimeData',TEDetId, PLDESC, starttime, shiftDesc, teamDesc, RawRateloss, RateLossRatio, EffectiveDowntime,LineActualSpeed,RateLossPRID
--	, * from #OpsDBDowntimeUptimeData d
--	--where [EffectiveDowntime] > 0
--	where IsContraint = 1
--		AND	(Reason2Category like '%Category:Paper (ELP)%' OR Reason1Category like '%Category:Paper (ELP)%')
--		AND ISNULL(d.RawRateloss,0) > 0
--	order by d.PLDESC, d.starttime

-----------------------------------------------------------------------------------
UPDATE #DDSStopTeam 
		-- (Unscheduled Stops * 1440.0 / (Split Uptime + Unscheduled Split DT)
	SET UnscheduledStopsDayValue = CASE WHEN SplitUptime + UnscheduledSplitDT > 0 
										THEN ROUND((UnscheduledStops * 1440.0) / (SplitUptime + UnscheduledSplitDT),0)					
									ELSE 0 END,
		--Split Uptime / (Split Uptime + Unscheduled Split Downtime)
		PlannedAvailabilityVal = CASE WHEN SplitUptime + UnscheduledSplitDT > 0 
										THEN SplitUptime / (SplitUptime + UnscheduledSplitDT)					
								ELSE 0 END,
		-- Split Uptime / Unscheduled Stops.
		UnplannedMTBFVal = CASE	WHEN UnscheduledStops > 0 
							THEN SplitUptime / UnscheduledStops
						ELSE 0 END,
		--Sum of the Unscheduled Split DT / Sum of the Unscheduled Stops
		UnplannedMTTRVal = CASE	WHEN UnscheduledStops > 0 
							THEN UnscheduledSplitDT / UnscheduledStops
						ELSE 0 END,
		--(Sum of PR/Poly Change Downtime) / (Sum of PR/Poly Change Events)	
		AvgPRPolyChangeTimeVal = CASE WHEN [PRPolyChangeEvents] > 0								
									THEN [PRPolyChangeDowntime] / CONVERT(FLOAT,[PRPolyChangeEvents]) 
								ELSE 0 END

UPDATE #DDSStopTeam 
	SET UPDT = CONCAT(ISNULL(UnscheduledSplitDT, 0), '|',ISNULL([SplitDowntime],0), '|',ISNULL([SplitUptime], 0)) 
	
UPDATE #DDSStopTeam 
	SET PlannedAvailability = CONCAT(ISNULL(SplitUptime, 0), '|',ISNULL(SplitUptime,0), '|',ISNULL(UnscheduledSplitDT,0)) 
	
UPDATE #DDSStopTeam 
	SET UnplannedMTBF = CONCAT(ISNULL(SplitUptime, 0), '|',ISNULL((UnscheduledStops), 0)) 

UPDATE #DDSStopTeam 
	SET UnplannedMTTR = CONCAT(ISNULL(UnscheduledSplitDT, 0), '|',ISNULL((UnscheduledStops), 0)) 

UPDATE #DDSStopTeam 
	SET AvgPRPolyChangeTime = CONCAT(ISNULL([PRPolyChangeDowntime], 0), '|',ISNULL((CONVERT(FLOAT,[PRPolyChangeEvents]) ), 0)) 

-----------------------------------------------------------------------------------
-- (Unscheduled Stops * 1440.0 / (Split Uptime + Unscheduled Split DT)
UPDATE #DDSStopTeam 
	SET UnscheduledStopsByDay = CONCAT(ISNULL(UnscheduledStops,0) ,'|', ISNULL(SplitUptime,0) ,'|', ISNULL(UnscheduledSplitDT,0) ) 

-----------------------------------------------------------------------------------------------------------------------
UPDATE u
	SET u.ProductionTime =	(SELECT SUM(c.ProductionRuntime)
									FROM #OpsDBProdCvtg		c	(NOLOCK)
									WHERE c.PLId = u.plid
										AND c.TeamDesc = u.TeamDesc
										AND c.ShiftDesc = u.ShiftDesc
										AND c.deleteFlag = 0
									GROUP BY c.pldesc, c.PUID, c.pudesc, c.teamDesc, c.ShiftDesc)
	FROM #DDSStopTeam u

--UPDATE u
--	SET u.PaperRuntime = u.ProductionTime - (SELECT SUM(Duration) Duration
--												FROM #OpsDBDowntimeUptimeData dd
--												WHERE dd.StopsScheduled > 0
--													AND dd.PUDesc like '%Converter%Reliability%'
--													AND dd.PlId = u.PlId
--													AND dd.TeamDesc = u.TeamDesc
--													AND dd.ShiftDesc = u.ShiftDesc
--												GROUP BY PLDesc, PUDesc, TeamDesc, ShiftDesc)
--	FROM #DDSStopTeam u

-- FO-04637
--UPDATE d
--	SET d.PaperRuntime = (SELECT SUM(TotalRuntimeLine)/60.0 - SUM(TotalScheduledDTLine)/60.0 AS TotalPaperRuntimeLine
--								FROM #LinesUnits		l (NOLOCK) 
--								JOIN #OpsDBELPData		e (NOLOCK)	ON e.PLId = l.PLId
--															AND e.StartTimeLine >= l.StartTime
--															AND e.StartTimeLine < l.EndTime
--								JOIN @CrewSchedule		c ON l.PlId = c.pl_id
--															AND l.PUId = c.pu_id
--															AND c.start_time < e.EndTimeLine
--															AND c.end_time > e.StartTimeLine
--								WHERE e.deleteFlag = 0
--									--AND l.PUDesc like '%Converter%Reliability%'
--									AND e.StartTimeLine < e.EndTimeLine
--									AND c.PU_Id = d.PUId
--									AND c.Crew_Desc = d.TeamDesc
--									AND c.shift_desc = d.ShiftDesc
--								GROUP BY l.plid, l.pldesc, l.puid, l.PUDesc, c.Crew_Desc, c.shift_desc)
--	FROM #DDSStopTeam d

-- FO-04637
UPDATE d
	SET d.PaperRuntime = (SELECT SUM(TotalRuntimeLine)/60.0 AS TotalPaperRuntimeLine
								FROM #LinesUnits		l (NOLOCK) 
								JOIN #OpsDBELPData		e (NOLOCK)	ON e.PLId = l.PLId
															AND e.StartTimeLine >= l.StartTime
															AND e.StartTimeLine < l.EndTime
								JOIN @CrewSchedule		c ON l.PlId = c.pl_id
															AND l.PUId = c.pu_id
															AND c.start_time < e.EndTimeLine
															AND c.end_time > e.StartTimeLine
								WHERE e.deleteFlag = 0
									--AND l.PUDesc like '%Converter%Reliability%'
									AND e.StartTimeLine < e.EndTimeLine
									AND c.PU_Id = d.PUId
									AND c.Crew_Desc = d.TeamDesc
									AND c.shift_desc = d.ShiftDesc
								GROUP BY l.plid, l.pldesc, l.puid, l.PUDesc, c.Crew_Desc, c.shift_desc)
	FROM #DDSStopTeam d

UPDATE d
	SET d.PaperRuntime = d.ProductionTime
	FROM #DDSStopTeam d
	WHERE d.PaperRuntime > d.ProductionTime

UPDATE d
	SET d.PaperRuntime = 0
	FROM #DDSStopTeam d
	WHERE d.PaperRuntime IS NULL
	
--select '#OpsDBELPData', sum(TotalRuntime)/60.0 as TotalRuntime, sum(TotalScheduledDT)/60.0 TotalScheduledDT 
--	,sum(TotalRuntimeLine)/60.0 as TotalRuntimeLine, sum(TotalScheduledDTLine)/60.0 TotalScheduledDTLine, 
--	sum(TotalRuntimeLine)/60.0 - sum(TotalScheduledDTLine)/60.0 AS TotalPaperRuntimeLine
--	--,sum(TotalRuntimeLinePS)/60.0 as TotalRuntimeLinePS, sum(TotalScheduledDTLinePS)/60.0 TotalScheduledDTLinePS, sum(TotalRuntimeLinePS)/60.0 - sum(TotalScheduledDTLinePS)/60.0 AS TotalPaperRuntimeLinePS
--	from #OpsDBELPData

-----------------------------------------------------------------------------------------------------------------------
--ELP Losses (Mins) = ReportELPDownTime + ReportRLELPDownTime
--ELP % = ELP Losses (Mins) / Paper Runtime
--Rate Loss % = RateLossEffectiveDT / Production Time
--Rate Loss % will be calculated by the pivot grid

UPDATE #DDSStopTeam 
	SET ELPLossesMins = ISNULL(ELPDowntime,0) + ISNULL(RLELPDowntime,0)

-----------------------------------------------------------------------------------------------------------------------
-- FO-04637
--UPDATE #DDSStopTeam 
--	SET ELP = CONCAT(ISNULL([ELPLossesMins], 0), '|',ISNULL([SplitDowntime],0), '|',ISNULL([SplitUptime], 0)) 
-- (u.ELPLossesMins + u.RLELPDowntime) / u.PaperRuntime
UPDATE #DDSStopTeam 
	SET ELP = CONCAT(ISNULL((ELPLossesMins), 0), '|',ISNULL(PaperRuntime, 0)) 

-----------------------------------------------------------------------------------------------------------------------
--UPDATE u
--	SET u.RateLossPercent = CASE WHEN u.ProductionTime > 0
--								THEN u.RateLossEffectiveDT / u.ProductionTime
--								ELSE 0 END
--	FROM #DDSStopTeam u

UPDATE u
	SET u.ELPVal =	CASE u.PaperRuntime WHEN 0 THEN 0
						ELSE u.ELPLossesMins / u.PaperRuntime
					END
	FROM #DDSStopTeam u

UPDATE u
	SET u.RateLossPercent = CAST(ISNULL(RL_EffectiveDT,0) AS NVARCHAR(100)) + '|' + CAST(ISNULL(ProductionTime,0) AS NVARCHAR(100))
	FROM #DDSStopTeam u
-----------------------------------------------------------------------------------------------------------------------
--select 'Check', PlId, ProductionLine, PUId, MasterUnit, TeamDesc, ShiftDesc, UnscheduledSplitDT, *
-- from #DDSStopTeam

--select 'Output'
-----------------------------------------------------------------------------------
--	STOPS (Ver. 1.4)
-----------------------------------------------------------------------------------
select	
		--'#DDSStopTeam', 
		PlId					
		,ProductionLine			
		,PUId					
		,MasterUnit				
		,TeamDesc				
		,ShiftDesc		
		-- FO-04637 Check
		--,ELPVal					
		--,ELP
		--,ELPDowntime, RLELPDowntime
		--,PaperRuntime			
		--,ProductionTime			AS 'ProductionRuntime'	
		--
		,inOutput				
		,orderOut				
		--
		,TotalStops				
		,UnscheduledStops		
		,UnscheduledStopsByDay	
		,UnscheduledStopsDayValue
		,MinorStops				
		,EquipmentFailures		
		,ProcessFailures			
		,SplitDowntime			
		,UnscheduledSplitDT		
		,RawUptime				
		,SplitUptime				
		,PlannedAvailabilityVal	
		,PlannedAvailability		
		,UnplannedMTBFVal		
		,UnplannedMTBF			
		,UnplannedMTTRVal		
		,UnplannedMTTR			
		,StopswithUptime2Min		
		,R2Denominator			
		,R2						
		,ELPStops				
		,ELPLossesMins			
		,ELPVal					
		,ELP						
		,RateLossEvents			
		,RL_EffectiveDT			AS 'RateLossEffectiveDowntime'		
		,RL_LineActualSpeed		AS 'RateLossLineActualSpeedAVG'		
		,RateLossPercent			
		,PaperRuntime			
		,ProductionTime			AS 'ProductionRuntime'	
		,PRPolyChangeEvents		
		,PRPolyChangeDowntime	
		,AvgPRPolyChangeTimeVal	
		,AvgPRPolyChangeTime		
		,UPDT					
 from #DDSStopTeam
	WHERE inOutput = 1 
	ORDER BY orderOut, MasterUnit

--return

-----------------------------------------------------------------------------------
--	PRODUCTION
-----------------------------------------------------------------------------------
SELECT DISTINCT
		pd.PLDesc AS ProductionLine, 
		ProdCode AS Product, 
		TeamDesc,
		ProductionRuntime [ProductionTime],
		concat( ISNULL ( ActualUnits , 0),'|',ISNULL ( ProductionRuntime , 0)) [AvgStatCLD],
		concat( CASE WHEN TargetUnits IS NOT NULL	THEN CONVERT(FLOAT, ISNULL ( ActualUnits , 0)) 
				ELSE 0.0
				END,'|',CONVERT(FLOAT, ISNULL ( TargetUnits , 0))) [CVPR],
		concat( CASE WHEN TargetUnits IS NOT NULL	THEN CONVERT(FLOAT, ISNULL ( ActualUnits , 0))
				ELSE 0
				END,'|',CONVERT(FLOAT, ISNULL ( OperationsTargetUnits , 0))) [OperationsEfficiency],	
		TotalUnits,
		GoodUnits,
		RejectUnits,
		concat(ISNULL ( RejectUnits , 0),'|',ISNULL ( TotalUnits , 0)) [UnitBroke%],
		ActualUnits [ActualStatCases],
		TargetUnits [ReliabilityTargetStatCases],
		OperationsTargetUnits [OperationsTargetStatCases],
		IdealUnits [IdealStatCases],
		concat( ISNULL ( LineSpeedAvg , 0),'|',ISNULL ( SplitUptime , 0)) [LineSpeedAvg],
		concat( ISNULL ( LineSpeedTarget , 0),'|',case 
									when LineSpeedTarget > 0.0
									then convert(float,ISNULL ( ProductionRuntime , 0))
									else 0.0
									end) [TargetLineSpeed],
		concat( ISNULL ( LineSpeedIdeal , 0),'|', case
									when LineSpeedIdeal > 0.0
									then convert(float,ISNULL ( ProductionRuntime , 0))
									else 0.0
									end,'|') [IdealLineSpeed],
		concat( ISNULL ( IdealUnits , 0),'|', CASE 	WHEN IdealUnits IS NOT NULL		
								THEN CONVERT(FLOAT,ISNULL ( ActualUnits , 0))	
								ELSE 0.0										
								END) [CVTI],
		LineSpeedAvg,
		LineSpeedTarget,
		LineSpeedIdeal,
		SplitUptime,
		PlannedRejectLogs [PlannedSULogs],
		UnplannedRejectLogs [UnplannedSULogs],
		BreakoutRejectLogs [BreakoutLogs],
		ManualRejectLogs [ManualRunningRejectLogs],
		OtherRejectLogs [OtherRejectLogs],
		ISNULL ( ILOCSetpointTarget , 0) [ILOCSetPointTarget],
		ISNULL ( ILOCSetpointAverage , 0) [ILOCSetPointAverage],
		ISNULL ( ILOCActualAverage , 0) [ILOCActualAverage]
	FROM #OpsDBProdCvtg			pd	(NOLOCK) 
	--FROM [Auto_opsDataStore].[dbo].[OpsDB_Production_Data_Cvtg] pd (NOLOCK)
	JOIN @Equipment e ON pd.PLId = e.PLId
	WHERE pd.StartTime >= e.StartTime
		AND pd.StartTime < e.EndTime
		-- v1.2
		AND pd.deleteFlag = 0
		AND pd.LineStatus IN (SELECT String FROM fnLocal_Split(@strNPT,','))
	 ORDER BY pd.PLDesc ASC, ProdCode DESC, TeamDesc DESC

-----------------------------------------------------------------------------------
--	DATA QUALITY (Ver.1.3)
-----------------------------------------------------------------------------------
INSERT INTO #dataQuality (
			PUId, 
			Unit, 
			LineStatus, 
			StartTime, 
			EndTime, 
			ClockHrs)
	SELECT	pd.PUId, 
			pd.PUDesc, 
			LineStatus, 
			CASE WHEN pd.starttime < e.StartTime THEN e.StartTime ELSE pd.starttime END,
			CASE WHEN pd.endtime > e.EndTime THEN e.EndTime ELSE pd.endtime END,
			0
	FROM #OpsDBProdCvtg		pd	(NOLOCK) 
	--FROM [Auto_opsDataStore].[dbo].[OpsDB_Production_Data_Cvtg] pd (NOLOCK)
	JOIN @Equipment e ON pd.PLId = e.PLId
	WHERE 
		(pd.StartTime BETWEEN e.StartTime AND e.EndTime OR pd.EndTime BETWEEN e.StartTime AND e.EndTime)
		AND pd.deleteFlag = 0 -- v1.2
		AND pd.LineStatus IN (SELECT String FROM fnLocal_Split(@strNPT,','))

UPDATE #dataQuality	
	SET ClockHrs = DATEDIFF(HOUR, StartTime, EndTime) 

SELECT 
		'PUId'		= PUId,
		'Unit'		= Unit,
		'LineStatus'= LineStatus,
		'StartTime'	= MIN(StartTime), 
		'EndTime'	= MAX(EndTime),
		'ClockHrs'	= SUM(ClockHrs)
	FROM #dataQuality
	GROUP BY PUId, Unit, LineStatus

-----------------------------------------------------------------------------------
--	DATA QUALITY (2nd) (Ver.1.3)
-----------------------------------------------------------------------------------
SELECT 
		CASE WHEN Total_Uptime  > 120
			THEN 	(CASE WHEN pd.StartTime < '2018-11-11 07:00:00.000' THEN
						'Improbable Uptime - Beginning Event'
					ELSE
						'Improbable Uptime - Ending Event'
					END)
			ELSE 'Significant Uncoded Downtime' END 	AS [Issue],
		pd.PLDesc				AS Line,
		pd.PUDesc				AS Unit,
		pd.StartTime,
		pd.EndTime,
		Duration				AS Downtime,
		Total_Uptime			AS Uptime,
		Reason1					AS 'FailureMode',
		Reason2					AS 'FailureModeCause',
		SUBSTRING (
				Reason2Category
			,CHARINDEX ('Category:', Reason2Category) + LEN ('Category:')
			,ISNULL (
				NULLIF (
					CHARINDEX ('|',
						SUBSTRING (
								Reason2Category
							,CHARINDEX ('Category:', Reason2Category) + LEN ('Category:')
							,LEN (Reason2Category)
						)
					) -1
					, -1
				)
				,LEN (Reason2Category)
				)
			)					AS 'Category',
		SUBSTRING (
				Reason2Category
			,CHARINDEX ('Schedule:', Reason2Category) + LEN ('Schedule:')
			,ISNULL (
				NULLIF (
					CHARINDEX ('|',
						SUBSTRING (
								Reason2Category
							,CHARINDEX ('Schedule:', Reason2Category) + LEN ('Schedule:')
							,LEN (Reason2Category)
						)
					) -1
					, -1
				)
				,LEN (Reason2Category)
				)
			)					AS 'Schedule'
	FROM #OpsDBDowntimeUptimeData		pd	(NOLOCK) 
	--FROM [Auto_opsDataStore].[dbo].[OpsDB_DowntimeUptime_Data] pd (NOLOCK)
		JOIN @Equipment e ON pd.PLId = e.PLId
		WHERE ((Total_Uptime  > 120) 											-- Uptime greater than 120 minutes.
				OR	(Reason1Id IS NULL OR Reason2Id IS NULL)) AND Duration > 60	-- Uncoded events greater than 60 minutes.
				AND	(pd.PUDesc LIKE '%Converter%Reliability%')						-- Only include Converter.
				AND pd.StartTime >= e.StartTime
				AND pd.EndTime <= e.EndTime
				-- v1.2
				AND pd.deleteFlag = 0
		ORDER BY [Issue], pd.PLId, pd.PUId
	
-----------------------------------------------------------------------------------
--	ILOC
-----------------------------------------------------------------------------------
SELECT pd.PLDesc AS ProductionLine
		  ,pd.PUDesc AS MasterUnit
		  ,ProdCode AS Product
		  ,ShiftDesc AS ShiftDesc
		  ,TeamDesc AS TeamDesc
		  ,ILOCSetpointAverage 
		  ,ILOCActualAverage
	FROM #OpsDBProdCvtg		pd	(NOLOCK) 
	--FROM [Auto_opsDataStore].[dbo].[OpsDB_Production_Data_Cvtg] pd (NOLOCK)
	JOIN @Equipment e ON pd.PLId = e.PLId
	WHERE pd.StartTime >= e.StartTime
		AND  pd.EndTime  <= e.EndTime
		-- v1.2
		AND pd.deleteFlag = 0
	 AND  pd.LineStatus IN (SELECT String FROM fnLocal_Split(@strNPT,','))

-----------------------------------------------------------------------------------
--	PACK PROD
-----------------------------------------------------------------------------------
SELECT pd.PLDesc AS ProductionLine,
		   pd.PUDesc AS MasterUnit,
		   TeamDesc,
		   ProdCode AS Product,
		   -- GoodUnits,
		   SUM(GoodUnits) AS GoodUnits,
		   StatFactor AS StatUnits,
		   StatFactor 
	FROM #OpsDBProdCvtg		pd	(NOLOCK) 
	--FROM [Auto_opsDataStore].[dbo].[OpsDB_Production_Data_Cvtg] pd (NOLOCK)
	JOIN @Equipment e ON pd.PLId = e.PLId
	WHERE pd.StartTime >= e.StartTime
		-- AND  pd.EndTime  <= e.EndTime
		AND pd.StartTime < e.EndTime
		-- v1.2
		AND pd.deleteFlag = 0
		AND  pd.LineStatus IN (SELECT String FROM fnLocal_Split(@strNPT,','))
	 GROUP BY pd.PLDesc, pd.PUDesc, TeamDesc, ProdCode, StatFactor

-----------------------------------------------------------------------------------
--	ALL STOPS
-----------------------------------------------------------------------------------
EXEC [dbo].[spRptConvertingAllStops] @strLineId,@timeOption,@strNPT,@dtmStartTime,@dtmEndTime

-----------------------------------------------------------------------------------
--	TIME PREVIEW
-----------------------------------------------------------------------------------
SELECT
		 RcdIdx		
		--,PUId		
		--,PUDesc		
		,PLId		
		,PLDesc		
		,CONVERT(VARCHAR, StartTime, 120)	AS StartTime	
		,CONVERT(VARCHAR, EndTime, 120)		AS EndTime	
		,CONVERT(VARCHAR, GETDATE(), 120)	AS RunTime
	FROM @Equipment

-----------------------------------------------------------------------------------
DROP TABLE #LinesUnits
DROP TABLE #SplitUptime
DROP TABLE #DDSStopTeam
DROP TABLE #dataQuality
DROP TABLE #OpsDBDowntimeUptimeData
GO

GRANT  EXECUTE  ON [dbo].[spRptConvertingDDS]  TO OpDBWriter
GO
