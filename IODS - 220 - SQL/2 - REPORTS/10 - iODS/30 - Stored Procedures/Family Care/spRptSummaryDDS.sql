USE [Auto_opsDataStore]
GO

-- -----------------------------------------------------------------------------------------------------------------------------
-- Prototype definition
-- -----------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20)

SELECT
		@SP_Name	= 'spRptSummaryDDS',
		@Inputs		= 4, 
		@Version	= '2.4' 

-- =============================================================================================================================
--	Update table AppVersions
-- =============================================================================================================================
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

-- =============================================================================================================================

-- -----------------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
-- -----------------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
			FROM	Information_schema.Routines
			WHERE	Specific_schema = 'dbo'
				AND	Specific_Name = @SP_Name
				AND	Routine_Type = 'PROCEDURE' )
	DROP PROCEDURE [dbo].[spRptSummaryDDS]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================================================================================================
-- -----------------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: [spRptSummaryDDS]
-- -----------------------------------------------------------------------------------------------------------------------------
-- -----------------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY: 
-- -----------------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-12-18		Damian Campana		Initial Release
-- 1.1		2019-04-12		Damian Campana		Adjust to execute with multiple lines
-- 1.2		2019-07-11		Damian Campana		Add parameters StartTime & EndTime for Filter <User Defined>
-- 1.3		2019-08-08		Damian Campana		Add Tab Machine with the following data: SPEED, CLOTHING LIFE (HOURS),
--												PAPER MACHINE RELIABILITY, MACHINE TIME, USAGE/YANK. (FURNISH-CHEMICAL)
-- 1.4		2019-09-11		Pablo Galanzini		Add check by deleteFlag in Ops tables. (Defect Panaya #821)
-- 1.5		2019-10-07		Pablo Galanzini		Fix values wrong in table #ELPSummary (Tkt #1208 Panaya)
-- 1.6		2019-10-15		Pablo Galanzini		Data from two tabs in the same report showing different values of a number Sheetbreaks (INC4364006-PRB0063658)
--												Added temp tables to retrieve data in begin of SP and used more times.		
-- 1.7		2019-11-12		Pablo Galanzini		Re-calculate Result SET 6: Get ELP Summary using table #ELPSummary and @ELPStops
-- 1.8		2019-11-21		Pablo Galanzini		Add the kpis 'Cat Promoter' and 'Defoamer' in Chemical grid
--												Changing the way to search Units Rate Loss to '%Rate%Loss%'
-- 1.9		2019-11-27		Pablo Galanzini		Calculate the ShtBrkCnt	and RepulpMin for SheetBreaks from data of Downtimes
--												In the Top 5 SheetBreaks Causes: To show 'All' sheetbreaks is counting the primary and extended SB
--												For the sheetbreaks grouped by Team and Product only is counting the primary SB
-- 2.0		2020-06-25		Pablo Galanzini		Changes the formulas in the KPIs: 1-KPI (PMBRPCT, PMDTPCT, PMRJPCT, PMRLPCT)
-- 2.1		2020-08-20		Pablo Galanzini		Add new fields of Cleaner and Creper Blades information:
--													1. Last Cleaner Change:	The time since the last cleaner change for the selected process.
--													2. # of Cleaners Changed: The total number of cleaner changed for the selected process.
--													3. Last Creper Changed: The time since the last creper change for the selected process.
--													4. # of Crepers Changed: The total number of crepers changed for the selected process.
--													5. Cleaner Blade Life: The AVG of duration of cleaner blade for the selected process.
--													6. Creper Blade Life: The AVG of duration of cleper blade for the selected process.
-- 2.2		2020-12-01		Pablo Galanzini		FO-04637: Code Change to ELP calculations. ELP calculation will be changed to 
--												(ELP Downtime + ELP Rateloss Downtime) / Paper Runtime. 
--												FO-04716 Add Downtime Reliability events for Paper machines
-- 2.3		2021-04-27		Pablo Galanzini		The Sheetbreaks Extended are the stops with Uptime=0 (Splitted) orherwise they are Primary (PRB0081608)
-- 2.4		2021-05-1		Pablo Galanzini		Is needed to fix a bug when the data for Paper Machines are retrieved from Raw data (PRB0081887)
--												The Sheetbreaks on Production's tab must show the same values of Sheet break's tab, no matters if they are Primary or Extended.
-- =============================================================================================================================
CREATE PROCEDURE [dbo].[spRptSummaryDDS]
--DECLARE
		 @strLineId			NVARCHAR(MAX)
		,@timeOption		INT
		,@dtmStartTime		DATETIME			= NULL
		,@dtmEndTime		DATETIME			= NULL

--WITH ENCRYPTION 
AS

SET NOCOUNT ON

/******************************************************************************************************************************
*																															  *
*				                                      Test procedure														  *
*																															  *
*******************************************************************************************************************************/
-- Lab0018
--EXEC [dbo].[spRptSummaryDDS] '36,37,38,25,20,168', -1, '2020-10-01 06:30:00.000', '2020-10-02 06:30:00.000'

--SELECT 
	 --@strLineId	= '36,37,38,25,20,168'	--  gbay lab0018
	 --@strLineId	= '42,37,73,28'			--  ay
	 --@strLineId	= '38,2,191'			-- cape
	 --@strLineId	= '107,154,146,147,109,67,168,163' -- MP
	 -- Blades in Lab0018
	-- @strLineId		= '38,20'	--  test
	-- ,@strLineId		= '37,38,25,20,168'	
	--,@timeOption	= -1
	--,@dtmStartTime	= '2019-07-15 06:30:00.000'
	--,@dtmEndTime	= '2019-07-20 06:30:00.000'
	--,@dtmEndTime	= '2019-07-08 06:30:00.000'

--EXEC [dbo].[spRptSummaryDDS] @strLineId,@timeOption,@dtmStartTime,@dtmEndTime
--return 

/******************************************************************************************************************************
*																															  *
*				                                      Get time option														  *
*																															  *
*******************************************************************************************************************************/
DECLARE @Equipment TABLE (
	 RcdIdx		INT IDENTITY							
	,PLId		INT				
	,PLDesc		NVARCHAR(255)	
	,StartTime	DATETIME		
	,EndTime	DATETIME		
)

/******************************************************************************************************************************
*																															  *
*				                                        Declarations														  *
*																															  *
*******************************************************************************************************************************/
IF OBJECT_ID('tempdb.dbo.#Blades', 'U') IS NOT NULL  DROP TABLE #Blades
CREATE TABLE #Blades (
	 PLID               INT
	,PLDesc             VARCHAR(255)
	,Equipment			VARCHAR(255)
	,OrderNum			INT
	,Data				VARCHAR(255)
	,Value				VARCHAR(255)
)

IF OBJECT_ID('tempdb.dbo.#Top5Sheetbreaks', 'U') IS NOT NULL  DROP TABLE #Top5Sheetbreaks
CREATE TABLE #Top5Sheetbreaks (
	 PLID               INT
	,PLDesc             VARCHAR(255)
	,Equipment			VARCHAR(255)
	,Cause				VARCHAR(255)
	,Minutes			DECIMAL(18,1)
	,ByTime				DECIMAL(18,2)
	,Tonnes				DECIMAL(18,3)
	,Count				INT
)

IF OBJECT_ID('tempdb.dbo.#ELPSummary', 'U') IS NOT NULL  DROP TABLE #ELPSummary
CREATE TABLE #ELPSummary (
	 PLID               INT
    ,PLDesc				VARCHAR(255)
	,ParentPM			VARCHAR(255)
	,Data				VARCHAR(255)
	,StartTime			DATETIME
	,EndTime			DATETIME
	,FreshStops			INT
	,StorageStops		INT
	,TotalStops			INT
	,FreshMins			DECIMAL(18,2)
	,StorageMins		DECIMAL(18,2)
	,TotalMins			DECIMAL(18,2)
	,FreshOverallELP	DECIMAL(18,1)
	,StorageOverallELP	DECIMAL(18,1)
	,OverallELP			DECIMAL(18,1)
	,SchedMins			DECIMAL(18,2)
	,FreshSchedDT		DECIMAL(18,2)
	,StorageSchedDT		DECIMAL(18,2)
	,FreshRuntime		DECIMAL(18,2)
	,StorageRuntime		DECIMAL(18,2)
	,OverallRuntime		DECIMAL(18,2)
)

IF OBJECT_ID('tempdb.dbo.#ELPTop5Causes', 'U') IS NOT NULL  DROP TABLE #ELPTop5Causes
CREATE TABLE #ELPTop5Causes (
	 PLID				INT
	,PLDesc				VARCHAR(255)
	,ParentPM			VARCHAR(255)
	,Type				VARCHAR(255)
	,StartTime			DATETIME
	,EndTime			DATETIME
	,Reason2			VARCHAR(255)
	,Stops				INT
	,Duration			FLOAT
	,PaperRuntime		FLOAT
	,PercentLoss		FLOAT
)

IF OBJECT_ID('tempdb.dbo.#SheetScheduled', 'U') IS NOT NULL  DROP TABLE #SheetScheduled
CREATE TABLE #SheetScheduled (
	 PLID				INT
	,PLDesc				VARCHAR(255)
	--,ParentPM			VARCHAR(255)
	,StartTime			DATETIME
	,EndTime			DATETIME
	,Primary_Stops		INT
	,PrimarySched_SB	INT
	,Scheduled_SB_Perc	DECIMAL(18,2)
	,SB12HsNumerator	DECIMAL(18,2)
	,Tub12HsNumerator	DECIMAL(18,2)
	,GI_Uptime			DECIMAL(18,2)
	,SB12Hs				DECIMAL(18,2)
	,Tubtime12Hs		DECIMAL(18,2)
)

---------------------------------------------------------------------------------------------------------------------------
--	table of data production PM
---------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#OpsDBProductionDataPM', 'U') IS NOT NULL  
	DROP TABLE #OpsDBProductionDataPM

CREATE TABLE #OpsDBProductionDataPM (
		RcdIdx					INT NOT NULL,
		Site					VARCHAR(50) NULL,
		PLID					INT NULL,
		PLDesc					VARCHAR(75) NULL,
		PUID					INT NULL,
		PUDesc					VARCHAR(200) NULL,
		StartTime				DATETIME NULL,
		EndTime					DATETIME NULL,
		ShiftDesc				VARCHAR(50) NULL,
		TeamDesc				VARCHAR(50) NULL,
		ProdId					INT NULL,
		ProdCode				VARCHAR(50) NULL,
		ProdDesc				VARCHAR(255) NULL,
		ProdFam					VARCHAR(100) NULL,
		ProdGroup				VARCHAR(100) NULL,
		NPTStatus				VARCHAR(50) NULL,
		ProcessOrder			VARCHAR(50) NULL,
		ProductTime				DECIMAL(10, 2) NULL,
		--
		GoodTons				DECIMAL(10, 3) NULL,
		RejectTons				DECIMAL(10, 3) NULL,
		HoldTons				DECIMAL(10, 3) NULL,
		FireTons				DECIMAL(10, 3) NULL,
		TAYTons					DECIMAL(10, 3) NULL,
		SlabTons				DECIMAL(10, 3) NULL,
		RepulperTons			DECIMAL(10, 3) NULL,
		TeardownTons			DECIMAL(10, 3) NULL,
		RATons					DECIMAL(10, 3) NULL,
		TotalTons				DECIMAL(10, 3) NULL,
		UnExpTons				DECIMAL(10, 3) NULL,
		GoodRolls				INT NULL,
		RejectRolls				INT NULL,
		HoldRolls				INT NULL,
		FireRolls				INT NULL,
		-- Ver 2.1
		LastCleaningBlades		DATETIME,
		CleaningBlades			INT,
		LifeCleaningBlades		FLOAT,
		LastCrepingBlades		DATETIME,
		CrepingBlades			INT,
		LifeCrepingBlades		FLOAT,
		--
		Sheetbreaks				INT NULL,
		SheetbreaksTime			DECIMAL(10, 2) NULL,
		Stops					INT NULL,
		YankeeSpeedSum			DECIMAL(10, 2) NULL,
		YankeeSpeedCount		INT NULL,
		ReelSpeedSum			DECIMAL(10, 2) NULL,
		ReelSpeedCount			INT NULL,
		FormingWireLife			DECIMAL(10, 2) NULL,
		BackingWireLife			DECIMAL(10, 2) NULL,
		BeltLife				DECIMAL(10, 2) NULL,
		Ts						DATETIME NULL,
		DeleteFlag				FLOAT NOT NULL,
		GI_Downtime				DECIMAL(10, 2) NULL,
		GE_Downtime				DECIMAL(10, 2) NULL,
		GI_Uptime				DECIMAL(10, 2) NULL,
		GE_Uptime				DECIMAL(10, 2) NULL,
		Belt_Id					VARCHAR(20) NULL,
		T3rd_Furnish_Sum		FLOAT NULL,
		CTMP_Sum				FLOAT NULL,
		Fiber_1_Sum				FLOAT NULL,
		Fiber_2_Sum				FLOAT NULL,
		Long_Fiber_Sum			FLOAT NULL,
		Machine_Broke_Sum		FLOAT NULL,
		Product_Broke_Sum		FLOAT NULL,
		Short_Fiber_Sum			FLOAT NULL,
		Absorb_Aid_Towel_Sum	FLOAT NULL,
		Aloe_E_Additive_Sum		FLOAT NULL,
		Biocide_Sum				FLOAT NULL,
		Cat_Promoter_Sum		FLOAT NULL,
		Chem_1_Sum				FLOAT NULL,
		Chem_2_Sum				FLOAT NULL,
		Chlorine_Control_Sum	FLOAT NULL,
		Defoamer_Sum			FLOAT NULL,
		Dry_Strength_Facial_Sum FLOAT NULL,
		Dry_Strength_Tissue_Sum FLOAT NULL,
		Recycle_Fiber_Sum		FLOAT NULL,
		Dry_Strength_Towel_Sum	FLOAT NULL,
		Dye_1_Sum				FLOAT NULL,
		Dye_2_Sum				FLOAT NULL,
		Emulsion_1_Sum			FLOAT NULL,
		Emulsion_2_Sum			FLOAT NULL,
		Flocculant_Sum			FLOAT NULL,
		Glue_Adhesive_Sum		FLOAT NULL,
		Glue_Crepe_Aid_Sum		FLOAT NULL,
		Glue_Release_Aid_Sum	FLOAT NULL,
		Glue_Total_Sum			FLOAT NULL,
		pH_Control_Tissue_Acid_Sum FLOAT NULL,
		pH_Control_Towel_Base_Sum FLOAT NULL,
		Single_Glue_Sum			FLOAT NULL,
		Softener_Facial_Sum		FLOAT NULL,
		Softener_Tissue_Sum		FLOAT NULL,
		Softener_Towel_Sum		FLOAT NULL,
		Wet_Strength_Facial_Sum FLOAT NULL,
		Wet_Strength_Tissue_Sum FLOAT NULL,
		Wet_Strength_Towel_Sum	FLOAT NULL,
		Air_Sum					FLOAT NULL,
		Air_UOM					NVARCHAR(15) NULL,
		Air_Per_YKT				FLOAT NULL,
		Electric_Sum			FLOAT NULL,
		Electric_UOM			NVARCHAR(15) NULL,
		Electric_Per_YKT		FLOAT NULL,
		Gas_Sum					FLOAT NULL,
		Gas_UOM					NVARCHAR(15) NULL,
		Gas_Per_YKT				FLOAT NULL,
		Steam_Sum				FLOAT NULL,
		Steam_UOM				NVARCHAR(15) NULL,
		Steam_Per_YKT			FLOAT NULL,
		Water_Sum				FLOAT NULL,
		Water_UOM				NVARCHAR(15) NULL,
		Water_Per_YKT			FLOAT NULL,
		GRHF_Tons				DECIMAL(10, 3) NULL,
		All_Tons				DECIMAL(10, 3) NULL,
		All_Furnish				DECIMAL(10, 3) NULL,
		All_Furnish_Perc_Calc	DECIMAL(10, 3) NULL,
		Total_Roll_Status_Cnt	FLOAT NULL)

---------------------------------------------------------------------------------------------------------------------------
--	table of downtime's data
---------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#OpsDBStopsPMs', 'U') IS NOT NULL  
	DROP TABLE #OpsDBStopsPMs

CREATE TABLE #OpsDBStopsPMs (
		RcdIdx					INT NOT NULL,
		Site					VARCHAR(50) NULL,
		PLID					INT NULL,
		PLDesc					VARCHAR(100) NULL,
		PUID					INT NULL,
		PUDesc					VARCHAR(200) NULL,
		TEDetId					INT NOT NULL,
		StartTime				DATETIME NULL,
		EndTime					DATETIME NULL,
		TeamDesc				VARCHAR(25) NULL,
		ShiftDesc				VARCHAR(25) NULL,
		LineStatus				NVARCHAR(50) NULL,
		Duration				DECIMAL(12, 3) NULL,
		Total_Uptime			FLOAT NULL,
		Uptime					DECIMAL(12, 3) NULL,
		SheetBreakPrimary		INT NULL,
		Planned					FLOAT NULL,
		Location				VARCHAR(100) NULL,
		ProdDesc				NVARCHAR(255) NULL,
		ProdCode				VARCHAR(25) NULL,
		ProdFam					NVARCHAR(100) NULL,
		ProdGroup				NVARCHAR(100) NULL,
		ProcessOrder			NVARCHAR(50) NULL,
		DTStatus				INT NULL,
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
		BreakDown				FLOAT NULL,
		ProcFailure				FLOAT NULL,
		TransferFlag			INT NULL,
		DeleteFlag				FLOAT NOT NULL,
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
		RawRateloss				FLOAT NULL,
		RateLossRatio			FLOAT NULL,
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
--	table of downtime's data of Converters
---------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#OpsDBStopsCVTGs', 'U') IS NOT NULL  
	DROP TABLE #OpsDBStopsCVTGs

CREATE TABLE #OpsDBStopsCVTGs (
		RcdIdx					INT NOT NULL,
		Site					VARCHAR(50) NULL,
		TEDetId					INT NOT NULL,
		PLID					INT NULL,
		PLDesc					VARCHAR(100) NULL,
		PUID					INT NULL,
		PUDesc					VARCHAR(200) NULL,
		StartTime				DATETIME NULL,
		EndTime					DATETIME NULL,
		Duration				DECIMAL(12, 3) NULL,
		Total_Uptime			FLOAT NULL,
		Uptime					DECIMAL(12, 3) NULL,
		DTStatus				INT NULL,
		ProdCode				VARCHAR(25) NULL,
		ProdDesc				NVARCHAR(255) NULL,
		ProdFam					NVARCHAR(100) NULL,
		ProdGroup				NVARCHAR(100) NULL,
		ProcessOrder			NVARCHAR(50) NULL,
		TeamDesc				VARCHAR(25) NULL,
		ShiftDesc				VARCHAR(25) NULL,
		LineStatus				NVARCHAR(50) NULL,
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
		Planned					FLOAT NULL,
		Location				VARCHAR(100) NULL,
		BreakDown				FLOAT NULL,
		ProcFailure				FLOAT NULL,
		TransferFlag			INT NULL,
		DeleteFlag				FLOAT NOT NULL,
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
		RawRateloss				FLOAT NULL,
		RateLossRatio			FLOAT NULL,
		Repulper_Tons			DECIMAL(12, 3) NULL)

-- New --
DECLARE @ELPStops TABLE	(
		PMPLId							INT	,
		PMPLDesc						NVARCHAR(50),
		PLId							INT	,
		PLDesc							NVARCHAR(50),
		PUId							INT	,
		PuDesc							NVARCHAR(50),
		Reason2							NVARCHAR(100),
		Duration						FLOAT,
		Stop							INT, 
		Fresh							INT DEFAULT 0, 
		MinorStop						INT, 
		RateLoss						FLOAT,
		StartTime						DATETIME,
		EndTime							DATETIME,
		TEDetId							INT
	) 

-----------------------------------------------------------------------------------------------------------------------
DECLARE		@minRcdIdx					INT, 
			@maxRcdIdx					INT,
			@GETDATE					DATETIME

/******************************************************************************************************************************
*				                                           DATA															  *
*******************************************************************************************************************************/
SET @GETDATE = GETDATE()
-- --------------------------------------------------------------------------------------------------------------------

INSERT INTO @Equipment(PLId) 
	SELECT String FROM dbo.fnLocal_Split(@strLineId, ',')

UPDATE e
	SET PLDesc	= ld.LineDesc 
	FROM @Equipment e
	JOIN dbo.LINE_DIMENSION ld WITH(NOLOCK) ON ld.PLId = e.PLId

--Set the Start & End Time
IF @timeOption = -1
BEGIN
	UPDATE e 
	SET	 e.StartTime = @dtmStartTime, e.EndTime = @dtmEndTime
	FROM @Equipment e 
END
ELSE
BEGIN
	DECLARE @strTimeOption NVARCHAR(50) = (SELECT	DateDesc 
											FROM	[dbo].[DATE_DIMENSION]  WITH(NOLOCK)
											WHERE DateId = @timeOption)

	UPDATE e 
		SET	e.StartTime = f.dtmStartTime, 
			e.EndTime = f.dtmEndTime
		FROM @Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption, e.plid) f
END

--select '@Equipment-Time', plid, pldesc, @timeOption timeOption, d.DateDesc, e.StartTime StartTime, e.EndTime EndTime
--	from @Equipment e
--	JOIN dbo.DATE_DIMENSION d on d.DateId = @timeOption

-- --------------------------------------------------------------------------------------------------------------------
--	Used to speedup to search in table [OpsDB_VariablesTasks_RawData] using the PK
-- --------------------------------------------------------------------------------------------------------------------
SELECT	@minRcdIdx = MIN(v.RcdIdx),
		@maxRcdIdx = MAX(v.RcdIdx)
	FROM [dbo].[OpsDB_VariablesTasks_RawData]	v	WITH(NOLOCK) 
	JOIN @Equipment								e	ON e.plid = v.plid
													AND v.ResultOn >= e.StartTime
													AND v.ResultOn < e.EndTime

/******************************************************************************************************************************
*																															  *
*				                                       Fill temp tables														  *
*																															  *
*******************************************************************************************************************************/
INSERT INTO #OpsDBProductionDataPM (
			RcdIdx			  ,
			StartTime		,
			EndTime				 ,
			Site				 ,
			pd.PLID				 ,
			pd.PLDesc			,
			PUID				 ,
			PUDesc				 ,
			ProdId				 ,
			ProdCode			 ,
			ProdDesc			 ,
			ProdFam				 ,
			ProdGroup			 ,
			ShiftDesc			 ,
			TeamDesc			 ,
			NPTStatus			 ,
			ProcessOrder		 ,
			ProductTime			  ,
			GoodTons			  ,
			RejectTons			  ,
			HoldTons			  ,
			FireTons			  ,
			TAYTons				  ,
			SlabTons			  ,
			RepulperTons		  ,
			TeardownTons		  ,
			RATons				  ,
			TotalTons			  ,
			UnExpTons			  ,
			GoodRolls			 ,
			RejectRolls			 ,
			HoldRolls			 ,
			FireRolls			 ,
			-- Ver 2.1
			LastCleaningBlades		,
			CleaningBlades			,
			LifeCleaningBlades		,
			LastCrepingBlades		,
			CrepingBlades			,
			LifeCrepingBlades		,
			--
			Sheetbreaks			 ,
			SheetbreaksTime		  ,
			Stops				 ,
			YankeeSpeedSum		  ,
			YankeeSpeedCount	 ,
			ReelSpeedSum		  ,
			ReelSpeedCount		 ,
			FormingWireLife		  ,
			BackingWireLife		  ,
			BeltLife			  ,
			Ts					 ,
			DeleteFlag			  ,
			GI_Downtime			  ,
			GE_Downtime			  ,
			GI_Uptime			  ,
			GE_Uptime			  ,
			Belt_Id				 ,
			T3rd_Furnish_Sum	 ,
			CTMP_Sum			 ,
			Fiber_1_Sum			 ,
			Fiber_2_Sum			 ,
			Long_Fiber_Sum		 ,
			Machine_Broke_Sum	 ,
			Product_Broke_Sum	 ,
			Short_Fiber_Sum		 ,
			Absorb_Aid_Towel_Sum	 ,
			Aloe_E_Additive_Sum	 ,
			Biocide_Sum			 ,
			Cat_Promoter_Sum	 ,
			Chem_1_Sum			 ,
			Chem_2_Sum			 ,
			Chlorine_Control_Sum	 ,
			Defoamer_Sum		 ,
			Dry_Strength_Facial_Sum  ,
			Dry_Strength_Tissue_Sum  ,
			Recycle_Fiber_Sum	 ,
			Dry_Strength_Towel_Sum  ,
			Dye_1_Sum			 ,
			Dye_2_Sum			 ,
			Emulsion_1_Sum		 ,
			Emulsion_2_Sum		 ,
			Flocculant_Sum		 ,
			Glue_Adhesive_Sum	 ,
			Glue_Crepe_Aid_Sum	 ,
			Glue_Release_Aid_Sum	 ,
			Glue_Total_Sum		 ,
			pH_Control_Tissue_Acid_Sum  ,
			pH_Control_Towel_Base_Sum  ,
			Single_Glue_Sum		 ,
			Softener_Facial_Sum	 ,
			Softener_Tissue_Sum	 ,
			Softener_Towel_Sum	 ,
			Wet_Strength_Facial_Sum  ,
			Wet_Strength_Tissue_Sum  ,
			Wet_Strength_Towel_Sum  ,
			Air_Sum				 ,
			Air_UOM				 ,
			Air_Per_YKT			 ,
			Electric_Sum		 ,
			Electric_UOM		 ,
			Electric_Per_YKT	 ,
			Gas_Sum				 ,
			Gas_UOM				 ,
			Gas_Per_YKT			 ,
			Steam_Sum			 ,
			Steam_UOM			 ,
			Steam_Per_YKT		 ,
			Water_Sum			 ,
			Water_UOM			 ,
			Water_Per_YKT		 ,
			GRHF_Tons			  ,
			All_Tons			  ,
			All_Furnish			  ,
			All_Furnish_Perc_Calc   ,
			Total_Roll_Status_Cnt  
	)
	SELECT 
			pd.RcdIdx			  ,
			pd.StartTime		,
			ISNULL(pd.EndTime,@GETDATE),
			Site				 ,
			pd.PLID				 ,
			pd.PLDesc			,
			PUID				 ,
			PUDesc				 ,
			ProdId				 ,
			ProdCode			 ,
			ProdDesc			 ,
			ProdFam				 ,
			ProdGroup			 ,
			ShiftDesc			 ,
			TeamDesc			 ,
			NPTStatus			 ,
			ProcessOrder		 ,
			ISNULL(ProductTime, 0) ,
			ISNULL(GoodTons, 0) ,
			ISNULL(RejectTons, 0) ,
			ISNULL(HoldTons, 0) ,
			ISNULL(FireTons, 0) ,
			ISNULL(TAYTons, 0) ,
			ISNULL(SlabTons, 0) ,
			ISNULL(RepulperTons, 0) ,
			ISNULL(TeardownTons, 0) ,
			ISNULL(RATons, 0) ,
			ISNULL(TotalTons, 0) ,
			ISNULL(UnExpTons, 0) ,
			ISNULL(GoodRolls, 0) ,
			ISNULL(RejectRolls, 0) ,
			ISNULL(HoldRolls, 0) ,
			ISNULL(FireRolls, 0) ,
			-- Ver 2.1
			LastCleaningBlades		,
			ISNULL(CleaningBlades, 0)	,
			ISNULL(LifeCleaningBlades,0),
			LastCrepingBlades		,
			ISNULL(CrepingBlades, 0) ,
			ISNULL(LifeCrepingBlades,0),
			--
			ISNULL(Sheetbreaks, 0) ,
			ISNULL(SheetbreaksTime, 0) ,
			ISNULL(Stops, 0) ,
			ISNULL(YankeeSpeedSum, 0) ,
			ISNULL(YankeeSpeedCount, 0) ,
			ISNULL(ReelSpeedSum, 0) ,
			ISNULL(ReelSpeedCount, 0) ,
			ISNULL(FormingWireLife, 0) ,
			ISNULL(BackingWireLife, 0) ,
			ISNULL(BeltLife, 0) ,
			Ts					 ,
			DeleteFlag			  ,
			ISNULL(GI_Downtime, 0) ,
			ISNULL(GE_Downtime, 0) ,
			ISNULL(GI_Uptime, 0) ,
			ISNULL(GE_Uptime, 0) ,
			Belt_Id				 ,
			ISNULL(T3rd_Furnish_Sum, 0) ,
			ISNULL(CTMP_Sum, 0) ,
			ISNULL(Fiber_1_Sum, 0) ,
			ISNULL(Fiber_2_Sum, 0) ,
			ISNULL(Long_Fiber_Sum, 0) ,
			ISNULL(Machine_Broke_Sum, 0) ,
			ISNULL(Product_Broke_Sum, 0) ,
			ISNULL(Short_Fiber_Sum, 0) ,
			ISNULL(Absorb_Aid_Towel_Sum, 0) ,
			ISNULL(Aloe_E_Additive_Sum, 0) ,
			ISNULL(Biocide_Sum, 0) ,
			ISNULL(Cat_Promoter_Sum, 0) ,
			ISNULL(Chem_1_Sum, 0) ,
			ISNULL(Chem_2_Sum, 0) ,
			ISNULL(Chlorine_Control_Sum, 0) ,
			ISNULL(Defoamer_Sum, 0) ,
			ISNULL(Dry_Strength_Facial_Sum  , 0) ,
			ISNULL(Dry_Strength_Tissue_Sum  , 0) ,
			ISNULL(Recycle_Fiber_Sum, 0) ,
			ISNULL(Dry_Strength_Towel_Sum  , 0) ,
			ISNULL(Dye_1_Sum, 0) ,
			ISNULL(Dye_2_Sum, 0) ,
			ISNULL(Emulsion_1_Sum, 0) ,
			ISNULL(Emulsion_2_Sum, 0) ,
			ISNULL(Flocculant_Sum, 0) ,
			ISNULL(Glue_Adhesive_Sum, 0) ,
			ISNULL(Glue_Crepe_Aid_Sum, 0) ,
			ISNULL(Glue_Release_Aid_Sum, 0) ,
			ISNULL(Glue_Total_Sum, 0) ,
			ISNULL(pH_Control_Tissue_Acid_Sum  , 0) ,
			ISNULL(pH_Control_Towel_Base_Sum  , 0) ,
			ISNULL(Single_Glue_Sum, 0) ,
			ISNULL(Softener_Facial_Sum, 0) ,
			ISNULL(Softener_Tissue_Sum, 0) ,
			ISNULL(Softener_Towel_Sum, 0) ,
			ISNULL(Wet_Strength_Facial_Sum  , 0) ,
			ISNULL(Wet_Strength_Tissue_Sum  , 0) ,
			ISNULL(Wet_Strength_Towel_Sum  , 0) ,
			ISNULL(Air_Sum, 0) ,
			Air_UOM,
			ISNULL(Air_Per_YKT, 0) ,
			ISNULL(Electric_Sum, 0) ,
			Electric_UOM,
			ISNULL(Electric_Per_YKT, 0) ,
			ISNULL(Gas_Sum, 0) ,
			Gas_UOM,
			ISNULL(Gas_Per_YKT, 0) ,
			ISNULL(Steam_Sum, 0) ,
			Steam_UOM,
			ISNULL(Steam_Per_YKT, 0) ,
			ISNULL(Water_Sum, 0) ,
			Water_UOM,
			ISNULL(Water_Per_YKT, 0) ,
			ISNULL(GRHF_Tons, 0) ,
			ISNULL(All_Tons, 0) ,
			ISNULL(All_Furnish, 0) ,
			ISNULL(All_Furnish_Perc_Calc   , 0) ,
			ISNULL(Total_Roll_Status_Cnt  , 0) 
		FROM  [Auto_opsDataStore].[dbo].[OpsDB_Production_Data_PM]	pd	WITH(NOLOCK)	
		JOIN  @Equipment										e	ON pd.PLId = e.PLID
																	AND pd.StartTime < e.EndTime
																	AND (pd.EndTime > e.StartTime  OR pd.EndTime IS NULL)
																	AND pd.deleteFlag = 0

--select * from [OpsDB_Production_Data_PM] where 	EndTime IS NULL
/******************************************************************************************************************************
*				                                      DATA DTs															  *
*******************************************************************************************************************************/
INSERT INTO #OpsDBStopsPMs (
		RcdIdx				  ,
		StartTime				 ,
		EndTime				 ,
		Duration				,
		Total_Uptime			 ,
		Uptime				,
		Fault				,
		FaultCode			,
		Reason1Id			,
		Reason1				,
		Reason1Code			,
		Reason1Category		,
		Reason2Id				 ,
		Reason2				,
		Reason2Code			,
		Reason2Category		,
		Reason3Id				 ,
		Reason3				,
		Reason3Code			,
		Reason3Category		,
		Reason4Id				 ,
		Reason4				,
		Reason4Code			,
		Reason4Category		,
		Action1				,
		Action1Code			,
		Action2				 ,
		Action2Code			 ,
		Action3				 ,
		Action3Code			 ,
		Action4				 ,
		Action4Code			 ,
		Planned				 ,
		Location				 ,
		ProdDesc				 ,
		ProdCode				,
		ProdFam				 ,
		ProdGroup				 ,
		ProcessOrder			,
		TeamDesc				,
		ShiftDesc				,
		LineStatus			 ,
		DTStatus				 ,
		PLDesc				 ,
		PUDesc				,
		PUID					 ,
		PLID					 ,
		BreakDown				 ,
		ProcFailure			 ,
		TransferFlag			 ,
		DeleteFlag			  ,
		Site				,
		TEDetId				  ,
		Ts					 ,
		IsContraint			 ,
		ProductionDay			 ,
		IsStarved				 ,
		IsBlocked				 ,
		ManualStops			  ,
		MinorStop				 ,
		MajorStop				 ,
		ZoneDesc			,
		ZoneGrpDesc			,
		LineGroup			,
		StopsEquipFails		 ,
		StopsELP				 ,
		StopsScheduled		 ,
		StopsUnscheduled		 ,
		StopsUnscheduledInternal  ,
		StopsUnscheduledBS	 ,
		StopsBlockedStarved	 ,
		ERTD_ID				 ,
		RawRateloss			 ,
		RateLossRatio			 ,
		Repulper_Tons		)
	SELECT 
		du.RcdIdx				  ,
		du.StartTime				 ,
		ISNULL(du.EndTime,@GETDATE),
		Duration				,
		Total_Uptime			 ,
		Uptime				,
		Fault				,
		FaultCode			,
		Reason1Id			,
		--Reason1				,
		ISNULL(Reason1, 'No Reason Assigned'),
		Reason1Code			,
		Reason1Category		,
		Reason2Id				 ,
		--Reason2				,
		ISNULL(Reason2, 'No Reason Assigned'),
		Reason2Code			,
		Reason2Category		,
		Reason3Id				 ,
--		Reason3				,
		ISNULL(Reason3, 'No Reason Assigned'),
		Reason3Code			,
		Reason3Category		,
		Reason4Id				 ,
		--Reason4				,
		ISNULL(Reason4, 'No Reason Assigned'),
		Reason4Code			,
		Reason4Category		,
		Action1				,
		Action1Code			,
		Action2				 ,
		Action2Code			 ,
		Action3				 ,
		Action3Code			 ,
		Action4				 ,
		Action4Code			 ,
		Planned				 ,
		Location				 ,
		ProdDesc				 ,
		ProdCode				,
		ProdFam				 ,
		ProdGroup				 ,
		ProcessOrder			,
		TeamDesc				,
		ShiftDesc				,
		LineStatus			 ,
		DTStatus				 ,
		du.PLDesc				 ,
		PUDesc				,
		du.PUID					 ,
		du.PLID					 ,
		BreakDown				 ,
		ProcFailure			 ,
		TransferFlag			 ,
		DeleteFlag			  ,
		Site				,
		TEDetId				  ,
		Ts					 ,
		IsContraint			 ,
		ProductionDay			 ,
		IsStarved				 ,
		IsBlocked				 ,
		ManualStops			  ,
		MinorStop				 ,
		MajorStop				 ,
		ZoneDesc			,
		ZoneGrpDesc			,
		LineGroup			,
		StopsEquipFails		 ,
		StopsELP				 ,
		StopsScheduled		 ,
		StopsUnscheduled		 ,
		StopsUnscheduledInternal  ,
		StopsUnscheduledBS	 ,
		StopsBlockedStarved	 ,
		ERTD_ID				 ,
		RawRateloss			 ,
		RateLossRatio			 ,
		Repulper_Tons			 	
		FROM [Auto_opsDataStore].[dbo].[OpsDB_DowntimeUptime_Data]	du	WITH(NOLOCK)
		JOIN @Equipment											e	ON du.PLId = e.PLID
																	AND du.StartTime < e.EndTime
																	AND (du.EndTime > e.StartTime  OR du.EndTime IS NULL)
																	AND du.deleteFlag = 0
																	
/******************************************************************************************************************************
*				                                      DATA ELP															  *
*******************************************************************************************************************************/
INSERT INTO #OpsDBELPData	(
		RcdIdx				   ,
		Site				 ,
		PRConvStartTime		 ,
		PRConvEndTime		 ,
		PLId				 ,
		PLDesc				 ,
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
		DeleteFlag		 )
	SELECT 		
		elp.RcdIdx				   ,
		Site				 ,
		PRConvStartTime		 ,
		ISNULL(PRConvEndTime, @GETDATE)		 ,
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
	JOIN @Equipment								e	ON elp.ParentPLID = e.PLID
													AND elp.PRConvStartTime < e.EndTime
													AND (elp.PRConvEndTime > e.StartTime  OR elp.PRConvEndTime IS NULL)
													AND elp.deleteFlag = 0

/******************************************************************************************************************************
*				                                      DATA DTs Converters															  *
*******************************************************************************************************************************/
INSERT INTO #OpsDBStopsCVTGs	(
		RcdIdx				  ,
		StartTime				 ,
		EndTime				 ,
		Duration				,
		Total_Uptime			 ,
		Uptime				,
		Fault				,
		FaultCode			,
		Reason1Id			,
		Reason1				,
		Reason1Code			,
		Reason1Category		,
		Reason2Id				 ,
		Reason2				,
		Reason2Code			,
		Reason2Category		,
		Reason3Id				 ,
		Reason3				,
		Reason3Code			,
		Reason3Category		,
		Reason4Id				 ,
		Reason4				,
		Reason4Code			,
		Reason4Category		,
		Action1				,
		Action1Code			,
		Action2				 ,
		Action2Code			 ,
		Action3				 ,
		Action3Code			 ,
		Action4				 ,
		Action4Code			 ,
		Planned				 ,
		Location				 ,
		d.ProdDesc				 ,
		d.ProdCode				,
		d.ProdFam				 ,
		d.ProdGroup				 ,
		d.ProcessOrder			,
		TeamDesc				,
		ShiftDesc				,
		LineStatus			 ,
		DTStatus				 ,
		PLDesc				 ,
		PUDesc				,
		PUID					 ,
		PLID					 ,
		BreakDown				 ,
		ProcFailure			 ,
		TransferFlag			 ,
		DeleteFlag			  ,
		Site				,
		TEDetId				  ,
		Ts					 ,
		IsContraint			 ,
		ProductionDay			 ,
		IsStarved				 ,
		IsBlocked				 ,
		ManualStops			  ,
		MinorStop				 ,
		MajorStop				 ,
		ZoneDesc			,
		ZoneGrpDesc			,
		LineGroup			,
		StopsEquipFails		 ,
		StopsELP				 ,
		StopsScheduled		 ,
		StopsUnscheduled		 ,
		StopsUnscheduledInternal  ,
		StopsUnscheduledBS	 ,
		StopsBlockedStarved	 ,
		ERTD_ID				 ,
		RawRateloss			 ,
		RateLossRatio			 ,
		Repulper_Tons			)
	SELECT DISTINCT
		d.RcdIdx				  ,
		d.StartTime				 ,
		d.EndTime				 ,
		Duration				,
		Total_Uptime			 ,
		Uptime				,
		Fault				,
		FaultCode			,
		Reason1Id			,
		Reason1				,
		Reason1Code			,
		Reason1Category		,
		Reason2Id				 ,
		Reason2				,
		Reason2Code			,
		Reason2Category		,
		Reason3Id				 ,
		--Reason3				,
		ISNULL(Reason3, 'No Reason Assigned'),
		Reason3Code			,
		Reason3Category		,
		Reason4Id				 ,
		Reason4				,
		Reason4Code			,
		Reason4Category		,
		Action1				,
		Action1Code			,
		Action2				 ,
		Action2Code			 ,
		Action3				 ,
		Action3Code			 ,
		Action4				 ,
		Action4Code			 ,
		Planned				 ,
		Location				 ,
		d.ProdDesc				 ,
		d.ProdCode				,
		d.ProdFam				 ,
		d.ProdGroup				 ,
		d.ProcessOrder			,
		TeamDesc				,
		ShiftDesc				,
		LineStatus			 ,
		DTStatus				 ,
		d.PLDesc				 ,
		d.PUDesc				,
		d.PUID					 ,
		d.PLID					 ,
		BreakDown				 ,
		ProcFailure			 ,
		TransferFlag			 ,
		d.DeleteFlag			  ,
		d.Site				,
		TEDetId				  ,
		d.Ts					 ,
		IsContraint			 ,
		ProductionDay			 ,
		IsStarved				 ,
		IsBlocked				 ,
		ManualStops			  ,
		MinorStop				 ,
		MajorStop				 ,
		ZoneDesc			,
		ZoneGrpDesc			,
		LineGroup			,
		StopsEquipFails		 ,
		StopsELP				 ,
		StopsScheduled		 ,
		StopsUnscheduled		 ,
		StopsUnscheduledInternal  ,
		StopsUnscheduledBS	 ,
		StopsBlockedStarved	 ,
		ERTD_ID				 ,
		RawRateloss			 ,
		RateLossRatio			 ,
		Repulper_Tons			 	
	FROM #OpsDBELPData										e	WITH(NOLOCK)
	JOIN @Equipment											p	ON e.ParentPLID = p.PLID
	JOIN [Auto_opsDataStore].[dbo].[OpsDB_DowntimeUptime_Data]	d	WITH(NOLOCK) ON e.PLID = d.PLID
																AND d.deleteFlag = 0
																AND d.StartTime >= e.PRConvStartTime
																AND d.StartTime < e.PRConvEndTime
																AND d.DTStatus = 1
																AND (d.PUDesc LIKE '%Converter Reliability%'
																	OR (d.pudesc LIKE '%Rate%Loss%'))
																AND (d.Reason1Category LIKE '%Category:Paper (ELP)%' 
																	OR d.Reason2Category LIKE '%Category:Paper (ELP)%')
		WHERE e.deleteFlag = 0

-----------------------------------------------------------------------------------
--	GET ELP Stops
-----------------------------------------------------------------------------------
INSERT INTO @ELPStops	(
			PMPLId		,
			PMPLDesc	,
			PLId		,
			PLDesc		,
			PUId		,
			PuDesc		,
			Reason2		,
			Duration	,
			Stop		,
			MinorStop	,
			RateLoss	,
			StartTime	,
			EndTime		,
			Fresh		,
			TEDetId		)
	SELECT	DISTINCT
			elp.ParentPLId,
			elp.ParentPLDesc,
			d.PLId		,
			d.PLDesc	,
			d.PuId		,
			d.PuDesc	,
			d.Reason2	,
			CASE WHEN Location NOT LIKE '%Rate%Loss%' THEN d.Duration ELSE 0 END 'Duration', 
			ISNULL(d.StopsELP,0) 'Stop',
			ISNULL(d.MinorStop,0) AS 'MinorStop',
			ISNULL(d.RawRateloss, 0) / 60.0 'Rateloss',
			d.StartTime,
			d.EndTime,
			CASE WHEN ParentRollAge < 1 THEN 1 ELSE 0 END 'Fresh',
			TEDetId
		FROM #OpsDBStopsCVTGs	d	(NOLOCK)
		JOIN #OpsDBELPData		elp	(NOLOCK) ON d.plid = elp.plid
										AND elp.deleteFlag = 0
										AND d.StartTime >= elp.StartTimePMRunBy	
										AND d.StartTime < elp.EndTimePMRunBy
		JOIN @Equipment			e	ON elp.ParentPLID = e.PLID 			
		WHERE d.DeleteFlag = 0
			AND d.IsContraint = 1
			AND elp.ParentPRID <> 'NoAssignedPRID'
			AND (d.Reason2Category like '%Paper (ELP%)%' OR d.Reason1Category like '%Paper (ELP%)%')
			AND d.StartTime >= e.StartTime
			AND d.StartTime < e.EndTime
		ORDER BY PLDesc, d.PuDesc, Reason2

-----------------------------------------------------------------------------------
--UPDATE #OpsDBStopsPMs set Reason2 = null where TEDetId = 79910852
--UPDATE #OpsDBStopsPMs set Uptime = 0 where TEDetId = 79910852

UPDATE #OpsDBStopsPMs
	SET SheetBreakPrimary = CASE WHEN Uptime = 0 THEN 0 ELSE 1 END
	WHERE PUDesc LIKE '%Sheetbreak%'
		AND Reason2 NOT LIKE '%False Sheetbreak Event%'
		AND Reason2 LIKE '%Sheetbreak%'
		AND DeleteFlag = 0

-----------------------------------------------------------------------------------
--SELECT '@Equipment', * FROM @Equipment
--select '@ELPStops', * from @ELPStops ORDER BY StartTime

--SELECT '#OpsDBStopsPMs SBs', count(*) FROM #OpsDBStopsPMs WHERE PUDesc LIKE '%Sheetbreak%'
--SELECT '#OpsDBStopsPMs SBs', SheetBreakPrimary, * FROM #OpsDBStopsPMs WHERE PUDesc LIKE '%Sheetbreak%' ORDER BY plid, puid, starttime

--select du.PUDesc, du.TEDetId, du.Reason2, du.DeleteFlag, SheetBreakPrimary, duration, Uptime, *
--	FROM #OpsDBStopsPMs du	WITH(NOLOCK)
--	WHERE du.PUDesc LIKE '%Sheet%'
--		AND du.TEDetId <> 0
--		AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
--		AND du.Reason2 LIKE '%Sheetbreak%'
--		AND du.DeleteFlag = 0
--		--and TEDetId in (79910852,79911504,79911632,79917262,79919593,79921515)
--	order by du.TEDetId

--SELECT PLID,PLDesc
--		,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 
--			  THEN 'All' 
--			  ELSE TeamDesc + '-' + ProdCode 
--		 END														'Equipment'
--		,CASE WHEN SheetBreakPrimary = 0 THEN 'Extended' ELSE 'Primary' END	'Type'
--		--,CASE WHEN DTStatus = 1 THEN 'Primary' ELSE 'Extended' END	'Type'
--		--,CAST(ROUND(SUM(Duration), 1) AS DECIMAL(18,1))				'Minutes'
--		,SUM(Duration)												'Minutes'
--		,SUM(Repulper_Tons)											'Tonnes'
--		,COUNT(*)													'Count'
--	FROM #OpsDBStopsPMs du	WITH(NOLOCK)
--	WHERE du.PUDesc LIKE '%Sheet%'
--		AND du.TEDetId <> 0
--		AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
--		AND du.Reason2 LIKE '%Sheetbreak%'
--		AND du.DeleteFlag = 0
--	GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), SheetBreakPrimary, PLID, PLDesc
--	ORDER BY 'Equipment', PLID

--SELECT '#OpsDBELPData', count(*) FROM #OpsDBELPData
--SELECT '#OpsDBStopsCVTGs',count(*) FROM #OpsDBStopsCVTGs
--SELECT '#OpsDBStopsCVTGs',* FROM #OpsDBStopsCVTGs ORDER BY starttime

--SELECT '#OpsDBStopsPMs Reliability', count(*), sum(duration),sum(uptime) FROM #OpsDBStopsPMs WHERE PUDesc LIKE '%Reliability%'
--SELECT '#OpsDBStopsPMs Reliability', * FROM #OpsDBStopsPMs WHERE PUDesc LIKE '%Reliability%' ORDER BY starttime

--SELECT '#OpsDBProductionDataPM',count(*), sum(gi_uptime) FROM #OpsDBProductionDataPM
--SELECT '#OpsDBProductionDataPM',gi_uptime,* FROM #OpsDBProductionDataPM ORDER BY StartTime
--RETURN

/******************************************************************************************************************************
*																															  *
*				                                           Results															  *
*																															  *
*******************************************************************************************************************************/
-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 1. Equipment [Group] > Production [Tab] => Get data for the first grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS1'
SELECT
		 PLID
		,PLDesc
		,TeamDesc + '-' + ProdCode									'Equipment'
		,ProdDesc													'Brand'
		,TeamDesc													'Team'
		,SUM(GoodTons)												'GoodTNE'
		,SUM(RejectTons)											'RejectTNE'
		,SUM(HoldTons)												'HoldTNE'
		,SUM(FireTons)												'FireTNE'
		,SUM(TAYTons)												'YankeeTNE'
		,SUM(SlabTons)												'SlabTNE'
		--,SUM(RepulperTons)											'RepulpTNE'
		,(SELECT SUM(Repulper_Tons)
				FROM #OpsDBStopsPMs du	WITH(NOLOCK)
				WHERE du.PUDesc LIKE '%Sheet%'
					AND du.TEDetId <> 0
					AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
					AND du.Reason2 LIKE '%Sheetbreak%'
					AND du.DeleteFlag = 0
					AND p.TeamDesc = du.TeamDesc
					AND p.ProdDesc = du.ProdDesc
					AND du.plid = p.plid)							'RepulpTNE'
		,SUM(TeardownTons)											'TeardownTNE'
		,SUM(UnExpTons)												'UnexplTNE'
	FROM  #OpsDBProductionDataPM p	WITH(NOLOCK)
	GROUP BY TeamDesc + '-' + ProdCode, TeamDesc, ProdDesc, PLID, PLDesc
	ORDER BY ProdDesc, TeamDesc

---- -----------------------------------------------------------------------------------------------------------------------------
---- Result SET 2. Equipment [Group] > Production [Tab] => Get data for the second grid
--	Fixed in (Ver. 1.6)
---- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS2'
SELECT	PLID
		,PLDesc
		,TeamDesc + '-' + ProdCode									'Equipment'
		,ProdDesc													'Brand'
		,TeamDesc													'Team'
		,SUM(GoodRolls)												'GoodRolls'
		,SUM(RejectRolls)											'RejectRolls'
		,SUM(HoldRolls)												'HoldRolls'
		,SUM(FireRolls)												'FireRolls'
		-- Ver 2.1
		,MAX(LastCleaningBlades)									'Last Cleaning Blade'
		,SUM(CleaningBlades)										'Clean Blades'
		,CASE SUM(CleaningBlades) WHEN 0 THEN 0 
			ELSE SUM(LifeCleaningBlades) / SUM(CleaningBlades) END	'Life Cleaning Blades'
		,MAX(LastCrepingBlades)										'Last Creping Blade'
		,SUM(CrepingBlades)											'Crepe Blades'
		,CASE SUM(CrepingBlades) WHEN 0 THEN 0 
			ELSE SUM(LifeCrepingBlades) / SUM(CrepingBlades) END	'Life Creping Blades'
		--
		--,SUM(Sheetbreaks)											'ShtBrkCnt_old'
		,(SELECT COUNT(*)
				FROM #OpsDBStopsPMs du	WITH(NOLOCK)
				WHERE du.PUDesc LIKE '%Sheet%'
					AND du.TEDetId <> 0
					AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
					AND du.Reason2 LIKE '%Sheetbreak%'
					AND du.DeleteFlag = 0
					--AND du.DTStatus = 1
					-- Changed in Ver. 2.4
					--AND du.SheetBreakPrimary = 1
					AND p.TeamDesc = du.TeamDesc
					AND p.ProdDesc = du.ProdDesc
					AND du.plid = p.plid)							'ShtBrkCnt'
		--,SUM(SheetbreaksTime)										'RepulpMin_old'
		,(SELECT SUM(duration)
				FROM #OpsDBStopsPMs du	WITH(NOLOCK)
				WHERE du.PUDesc LIKE '%Sheet%'
					AND du.TEDetId <> 0
					AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
					AND du.Reason2 LIKE '%Sheetbreak%'
					AND du.DeleteFlag = 0
					AND p.TeamDesc = du.TeamDesc
					AND p.ProdDesc = du.ProdDesc
					AND du.plid = p.plid)							'RepulpMin'
		,SUM(Stops)													'Stops'
		,SUM(GI_Downtime)											'DTMin'
	FROM  #OpsDBProductionDataPM	p	WITH(NOLOCK)
	GROUP BY TeamDesc + '-' + ProdCode, TeamDesc, ProdDesc, PLID, PLDesc
	ORDER BY ProdDesc, TeamDesc

--return
---- -----------------------------------------------------------------------------------------------------------------------------
---- Result SET 3. Equipment [Group] > Sheetbreaks [Tab] => Get data for All Causes 
---- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS3'
SELECT PLID
		,PLDesc
		,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 
			  THEN 'All' 
			  ELSE TeamDesc + '-' + ProdCode 
		 END														'Equipment'
		,CASE WHEN SheetBreakPrimary = 0 THEN 'Extended' ELSE 'Primary' END	'Type'
		--,CASE WHEN DTStatus = 1 THEN 'Primary' ELSE 'Extended' END	'Type'
		--,CAST(ROUND(SUM(Duration), 1) AS DECIMAL(18,1))				'Minutes'
		,SUM(Duration)												'Minutes'
		,SUM(Repulper_Tons)											'Tonnes'
		,COUNT(*)													'Count'
	FROM #OpsDBStopsPMs du	WITH(NOLOCK)
	WHERE du.PUDesc LIKE '%Sheet%'
		AND du.TEDetId <> 0
		AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
		AND du.Reason2 LIKE '%Sheetbreak%'
		AND du.DeleteFlag = 0
	GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), SheetBreakPrimary, PLID, PLDesc
	ORDER BY 'Equipment', PLID
--return

---- -----------------------------------------------------------------------------------------------------------------------------
---- Result SET 4. Equipment [Group] > Sheetbreaks [Tab] => Get data for Top 5 Causes
---- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS4'
-- For All sheetbreaks is counting the primary and extended SB
INSERT INTO #Top5Sheetbreaks
	SELECT	PLID
			,PLDesc
			,'All'										'Equipment'
			,Reason3									'Cause'
			,CAST(SUM(Duration) AS DECIMAL(18,2))		'Minutes'
			,NULL										'ByTime'
			,SUM(Repulper_Tons)							'Tonnes'
			--,SUM(DTStatus)								'Count'
			,COUNT(DISTINCT du.TEDetId)					'Count'
			--,COUNT(*)									'Count'
		FROM #OpsDBStopsPMs du	WITH(NOLOCK)
		WHERE du.PUDesc LIKE '%Sheet%'
			AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
			AND du.Reason2 LIKE '%Sheetbreak%'
			AND du.DeleteFlag = 0
			AND du.SheetBreakPrimary = 1
		GROUP BY Reason3, PLID, PLDesc
		order BY 'Minutes' desc
	
-- For the sheetbreaks by Team and Product only is counting the primary SB
INSERT INTO #Top5Sheetbreaks
	SELECT	PLID
			,PLDesc
			,TeamDesc + '-' + ProdCode
			,Reason3									'Cause'
			,CAST(SUM(Duration) AS DECIMAL(18,2))		'Minutes'
			,NULL										'ByTime'
			,SUM(Repulper_Tons)							'Tonnes'
			--,SUM(DTStatus)								'Count'
			,COUNT(DISTINCT du.TEDetId)					'Count'
			--,COUNT(*)									'Count'
		FROM #OpsDBStopsPMs du	WITH(NOLOCK)
		WHERE du.PUDesc LIKE '%Sheet%'
			AND du.Reason2 NOT LIKE '%False Sheetbreak Event%'
			AND du.Reason2 LIKE '%Sheetbreak%'
			AND du.DeleteFlag = 0
			AND du.SheetBreakPrimary = 1
		GROUP BY (TeamDesc + '-' + ProdCode), Reason3, PLID, PLDesc
		order BY PLID, PLDesc, (TeamDesc + '-' + ProdCode), 'Minutes' desc
	
UPDATE #Top5Sheetbreaks
	SET  [ByTime] = IIF([Minutes] = 0.0, 1.0, [Minutes]) * 100 / IIF([TMinutes] = 0.0, 1.0, [TMinutes])
	FROM (SELECT 
			 [Equipment]
			,SUM([Minutes]) [TMinutes] 
		  FROM (
			SELECT 
				 [Equipment]
				,[Minutes]
				,RANK() OVER (PARTITION BY [Equipment] ORDER BY [Equipment], [Minutes] DESC) AS [Rank] 
			FROM #Top5Sheetbreaks WITH(NOLOCK)
			) sh WHERE [Rank] <= 5
			GROUP BY [Equipment]) grp
	WHERE #Top5Sheetbreaks.[Equipment] = grp.[Equipment]

SELECT
	--'#Top5Sheetbreaks', 
	 PLID,
	 PLDesc,
	 [Equipment]			
	,[Cause]		
	,[Minutes]		
	,[ByTime]		
	,[Tonnes]		
	,[Count] 
	FROM (
		SELECT
			 PLID,PLDesc,[Equipment]			
			,[Cause]		
			,[Minutes]		
			,[ByTime]		
			,[Tonnes]		
			,[Count]
			,RANK() OVER (PARTITION BY [Equipment], PLID ORDER BY [Equipment], [Minutes] DESC) AS [Rank]
		FROM #Top5Sheetbreaks WITH(NOLOCK)
	) sh WHERE [Rank] <= 5
	ORDER BY [Equipment], PLID

--return
---- -----------------------------------------------------------------------------------------------------------------------------
---- Result SET 5. Equipment [Group] > Sheetbreaks [Tab] => Get data for % Scheduled
---- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS5'
INSERT INTO #SheetScheduled (
			PLID, 
			PLdesc, 
			--ParentPM, 
			StartTime, 
			EndTime, 
			Primary_Stops )
	SELECT	e.PLID, 
			e.PLDesc, 
			--d.PLDesc, 
			e.StartTime, 
			e.EndTime, 
			--TEDetId, d.PUDesc, Reason2, DeleteFlag, SheetBreakPrimary, DTStatus
			COUNT(DISTINCT d.TEDetId) AS Primary_Stops
		FROM #OpsDBStopsPMs	d	WITH(NOLOCK)
		JOIN @Equipment					e ON d.PLId = e.PLID
											AND d.StartTime >= e.StartTime 
											AND (d.EndTime < e.EndTime)
		WHERE d.DeleteFlag = 0
			AND d.SheetBreakPrimary = 1
			--AND d.DTStatus = 1
		GROUP BY e.PLID, e.PLDesc, d.PLDesc, e.StartTime, e.EndTime

UPDATE s 
	SET s.PrimarySched_SB = (SELECT COUNT(*) AS Primary_Stops
								FROM #OpsDBStopsPMs d WITH(NOLOCK)
								  WHERE d.PUDesc LIKE '%Sheetbreak%'
								  AND d.DeleteFlag = 0
								  AND d.PLID = s.PLID
								  --AND d.DTStatus = 1
									AND d.SheetBreakPrimary = 1
								  AND d.Reason2 LIKE '%Scheduled%'
								  GROUP BY d.PLDesc)
	FROM #SheetScheduled s

UPDATE #SheetScheduled 
	SET Scheduled_SB_Perc = CASE
								WHEN CONVERT(FLOAT, Primary_Stops) > 0.0
								THEN CONVERT(DECIMAL(10,4), CONVERT(FLOAT, PrimarySched_SB) 
										/ CONVERT(FLOAT, Primary_Stops)*100)	
								ELSE NULL
							END  

UPDATE #SheetScheduled
	SET SB12HsNumerator = Primary_Stops

UPDATE s 
	SET s.Tub12HsNumerator = (SELECT SUM(d.duration) AS Primary_Stops
								FROM #OpsDBStopsPMs d WITH(NOLOCK)
								WHERE d.PUDesc LIKE '%Sheetbreak%'
									AND d.DeleteFlag = 0
									AND d.PLID = s.PLID
									GROUP BY d.PLDesc)
	FROM #SheetScheduled s

UPDATE s 
	SET s.GI_Uptime = (SELECT SUM(GI_Uptime) 
							FROM #OpsDBProductionDataPM p WITH(NOLOCK)
							WHERE p.DeleteFlag = 0
								AND p.PLID = s.PLID
								AND NOT EXISTS (SELECT * FROM #OpsDBStopsPMs p2 WITH(NOLOCK)
													WHERE p.PLDesc LIKE p2.PLDesc
													AND p.StartTime > p2.StartTime 
													AND p.EndTime = p2.EndTime  
													AND p2.PLID = s.PLID
													AND p2.DeleteFlag = 0))
	FROM #SheetScheduled s
		
UPDATE s
	SET s.GI_Uptime = (GI_Uptime - (SELECT  SUM(duration)  
								  FROM #OpsDBStopsPMs d WITH(NOLOCK)
								  WHERE d.PUDesc LIKE '%Reliability%'
									AND d.DeleteFlag = 0
									AND d.PLID = s.PLID
									AND d.StartTime <> d.EndTime)) / 720.0
	FROM #SheetScheduled s
										
UPDATE #SheetScheduled 
	SET SB12Hs	= CASE WHEN GI_Uptime > 0 
						THEN SB12HsNumerator / GI_Uptime
					ELSE 0 END,
		Tubtime12Hs = CASE WHEN GI_Uptime > 0 
						THEN Tub12HsNumerator / GI_Uptime
					ELSE 0 END
	
SELECT	PLID
		,PLDesc
		,Scheduled_SB_Perc		'SB'
		,SB12Hs					'SB12H'
		,Tubtime12Hs			'Tubtime12H'
	FROM #SheetScheduled WITH(NOLOCK)

--SELECT '#SheetScheduled', * FROM #SheetScheduled
--RETURN

---- -----------------------------------------------------------------------------------------------------------------------------
---- Result SET 6. Equipment [Group] > ELP [Tab] => Get ELP Summary for All Roll Statuses
---- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS6'
INSERT INTO #ELPSummary  (
			PLID                      ,
			PLDesc                    ,
			ParentPM                  ,
			Data                      ,
			StartTime                 , 
			Endtime                   
			, FreshStops
			, StorageStops
			--, TotalStops
			, FreshMins
			, StorageMins
    )
    SELECT 
			t.PLID                    ,
			t.PLDesc                  ,
			t.PLID                    , 
			'Stops'					  ,
			t.StartTime               ,
			t.EndTime                 
			, SUM(CASE WHEN e.stop = 1 AND e.Fresh = 1 THEN 1 ELSE 0 END) FreshStops
			, SUM(CASE WHEN e.stop = 1 AND e.Fresh = 0 THEN 1 ELSE 0 END) StorageStops
			--, SUM(CASE WHEN e.stop = 1 THEN 1 ELSE 0 END) 
			, SUM(CASE WHEN e.Fresh = 1 THEN e.duration ELSE 0 END) 
				+ SUM(CASE WHEN e.Fresh = 1 THEN e.RateLoss ELSE 0 END) AS FreshMins
			, SUM(CASE WHEN e.Fresh = 0 THEN e.duration ELSE 0 END) 
				+ SUM(CASE WHEN e.Fresh = 0 THEN e.RateLoss ELSE 0 END) AS StorageMins
		FROM @Equipment t
		JOIN @ELPStops	e ON t.plid = e.pmplid
		GROUP BY
			t.PLID                    ,
			t.PLDesc                  ,
			t.PLID                    , 
			t.StartTime               ,
			t.EndTime                 
		 

UPDATE #ELPSummary
	SET TotalStops	= ISNULL(FreshStops,0) + ISNULL(StorageStops, 0),
		TotalMins	= ISNULL(FreshMins,0) + ISNULL(StorageMins, 0)
 
UPDATE #ELPSummary
       SET FreshSchedDT = ISNULL((SELECT SUM(DISTINCT ISNULL(e.TotalScheduledDT,0))
										FROM #OpsDBELPData		e	WITH(NOLOCK)
											JOIN @Equipment		p	ON p.PLID = e.ParentPLID
											WHERE e.ParentPLID = d.ParentPM 
											AND e.StartTimePMRunBy < p.EndTime AND e.EndTimePMRunBy > p.StartTime
											--AND e.InputOrder = 1
											--AND e.PRConvStartTime < p.EndTime AND e.PRConvEndTime > p.StartTime
											AND e.FreshRolls = 1
											AND e.deleteFlag = 0
											GROUP BY e.ParentPLID), 0) / 60.0
       FROM #ELPSummary d

UPDATE #ELPSummary
       SET StorageSchedDT = ISNULL((SELECT SUM(DISTINCT ISNULL(e.TotalScheduledDT,0))
										FROM #OpsDBELPData		e	WITH(NOLOCK)	
											JOIN @Equipment		p	ON p.PLID = e.ParentPLID
											WHERE e.ParentPLID = d.ParentPM 
											AND e.StartTimePMRunBy < p.EndTime AND e.EndTimePMRunBy > p.StartTime
											--AND e.InputOrder = 1
											--AND e.PRConvStartTime < p.EndTime AND e.PRConvEndTime > p.StartTime
											AND e.StorageRolls = 1
											AND e.deleteFlag = 0
											GROUP BY e.ParentPLID),0) / 60.0 
       FROM #ELPSummary d

UPDATE  d
       SET d.SchedMins = d.FreshSchedDT + d.StorageSchedDT
       FROM #ELPSummary d

--SELECT e.PLId, e.PLDesc, e.ParentPLId, e.ParentPLDesc,
--	SUM(ISNULL(e.TotalRuntime,0))/60.0 AS TotalRuntime,
--	SUM(ISNULL(e.PaperRuntime,0))/60.0 AS PaperRuntime,
--	SUM(ISNULL(e.TotalFreshRuntimePMRunBy,0))/60.0 AS TotalFreshRuntimePMRunBy,
--	--SUM(ISNULL(e.TotalFreshRuntimeLine,0))/60.0 AS TotalFreshRuntimeLine,
--	--SUM(ISNULL(e.TotalFreshRuntimeIntrPL,0))/60.0 AS TotalFreshRuntimeIntrPL,
--	--SUM(ISNULL(e.TotalFreshRuntimeLinePS,0))/60.0 AS TotalFreshRuntimeLine,
--	SUM(ISNULL(e.TotalStorageRuntimePMRunBy,0))/60.0 AS TotalStorageRuntimePMRunBy
--	--SUM(ISNULL(e.TotalStorageRuntimeLine,0))/60.0 AS TotalStorageRuntimeLine,
--	--SUM(ISNULL(e.TotalStorageRuntimeIntrPL,0))/60.0 AS TotalStorageRuntimeIntrPL,
--	--SUM(ISNULL(e.TotalStorageRuntimeLinePS,0))/60.0 AS TotalStorageRuntimeLine
--										FROM #OpsDBELPData	e	WITH(NOLOCK)
--										JOIN @Equipment		p	ON p.PLID = e.ParentPLID
--										WHERE e.deleteFlag = 0
----											AND e.ParentPLID = d.ParentPM 
--											AND e.StartTimePMRunBy < p.EndTime AND e.EndTimePMRunBy > p.StartTime
--											--AND e.PRConvStartTime >= p.StartTime AND e.PRConvStartTime < p.EndTime 
--	GROUP BY e.PLId, e.PLDesc, e.ParentPLId, e.ParentPLDesc
																						
UPDATE #ELPSummary
       SET FreshRuntime = ISNULL((SELECT SUM(ISNULL(e.TotalFreshRuntimePMRunBy,0))
										FROM #OpsDBELPData	e	WITH(NOLOCK)
										JOIN @Equipment		p	ON p.PLID = e.ParentPLID
										WHERE e.deleteFlag = 0
											AND e.ParentPLID = d.ParentPM 
											AND e.StartTimePMRunBy < p.EndTime AND e.EndTimePMRunBy > p.StartTime
											--AND e.PRConvStartTime >= p.StartTime AND e.PRConvStartTime < p.EndTime 
											GROUP BY e.ParentPLID ), 0) / 60.0
       FROM #ELPSummary d

UPDATE #ELPSummary
       SET StorageRuntime = ISNULL((SELECT SUM(ISNULL(e.TotalStorageRuntimePMRunBy,0))
										FROM #OpsDBELPData		e	WITH(NOLOCK)
											JOIN @Equipment		p	ON p.PLID = e.ParentPLID
											WHERE e.ParentPLID = d.ParentPM 
											AND e.deleteFlag = 0
											AND e.StartTimePMRunBy < p.EndTime AND e.EndTimePMRunBy > p.StartTime
											--AND e.PRConvStartTime >= p.StartTime AND e.PRConvStartTime < p.EndTime 
											GROUP BY e.ParentPLID) , 0) / 60.0
       FROM #ELPSummary d

-- Runtime
UPDATE #ELPSummary
       SET OverallRuntime = 
					--FreshRuntime + StorageRuntime
					ISNULL((SELECT SUM(ISNULL(e.TotalRuntimePMRunBy,0))
										FROM #OpsDBELPData		e	WITH(NOLOCK)
											JOIN @Equipment		p	ON p.PLID = e.ParentPLID
											WHERE e.ParentPLID = d.ParentPM 
											AND e.deleteFlag = 0
											AND e.StartTimePMRunBy < p.EndTime AND e.EndTimePMRunBy > p.StartTime
											--AND e.PRConvStartTime >= p.StartTime AND e.PRConvStartTime < p.EndTime 
											GROUP BY e.ParentPLID), 0) / 60.0
       FROM #ELPSummary d
       
-- FO-04637 Before
--UPDATE #ELPSummary
--       SET	 FreshOverallELP	= CASE 
--									WHEN ISNULL(FreshRuntime, 0) > 0 
--									THEN (ISNULL(FreshMins,0)) / IIF((ISNULL(FreshRuntime,0) - ISNULL(FreshSchedDT,0)) = 0, 1, 
--											(ISNULL(FreshRuntime,0) - ISNULL(FreshSchedDT,0))) * 100 
--									ELSE 0 
--								  END
--			,StorageOverallELP	= CASE 
--									WHEN (ISNULL(StorageRuntime,0)) > 0 
--									THEN (ISNULL(StorageMins,0)) / IIF((ISNULL(StorageRuntime,0) - ISNULL(StorageSchedDT,0)) = 0, 1, 
--											(ISNULL(StorageRuntime,0) - ISNULL(StorageSchedDT,0))) * 100 
--									ELSE 0 
--								  END
--            ,OverallELP			= CASE 
--									WHEN (ISNULL(OverallRuntime,0)) > 0 
--									THEN (ISNULL(TotalMins,0)) / IIF((ISNULL(OverallRuntime,0) - ISNULL(SchedMins,0)) = 0, 1, 
--											(ISNULL(OverallRuntime,0) - ISNULL(SchedMins,0))) * 100 
--									ELSE 0 
--								  END

-- FO-04637
UPDATE #ELPSummary
       SET	 FreshOverallELP	= CASE 
									WHEN ISNULL(FreshRuntime, 0) > 0 
									THEN (ISNULL(FreshMins,0)) / IIF((ISNULL(FreshRuntime,0)) = 0, 1, 
											(ISNULL(FreshRuntime,0))) * 100 
									ELSE 0 
								  END
			,StorageOverallELP	= CASE 
									WHEN (ISNULL(StorageRuntime,0)) > 0 
									THEN (ISNULL(StorageMins,0)) / IIF((ISNULL(StorageRuntime,0)) = 0, 1, 
											(ISNULL(StorageRuntime,0))) * 100 
									ELSE 0 
								  END
            ,OverallELP			= CASE 
									WHEN (ISNULL(OverallRuntime,0)) > 0 
									THEN (ISNULL(TotalMins,0)) / IIF((ISNULL(OverallRuntime,0)) = 0, 1, 
											(ISNULL(OverallRuntime,0))) * 100 
									ELSE 0 
								  END

--SELECT '#ELPSummary', * FROM #ELPSummary
--return

SELECT
		 PLID
		,PLDesc
		,Type = REPLACE(Type, '_Stops', '')
		,Stops
		,Minutes
		,ELP
	FROM (
		SELECT
			 PLID
			,PLDesc
			,ISNULL(FreshStops, 0)				[Fresh Paper_Stops]
			,ISNULL(FreshMins, 0)				[Fresh Paper_Minutes]
			,ISNULL(FreshOverallELP, 0)			[Fresh Paper_ELP]
			,ISNULL(StorageStops, 0)			[Storage Paper_Stops]
			,ISNULL(StorageMins, 0)				[Storage Paper_Minutes]
			,ISNULL(StorageOverallELP, 0)		[Storage Paper_ELP]
			,ISNULL(TotalStops, 0)				[Total_Stops]
			,ISNULL(TotalMins, 0)				[Total_Minutes]
			,ISNULL(OverallELP, 0)				[Total_ELP]
		FROM #ELPSummary WITH(NOLOCK)
	) ELPSummary
	UNPIVOT (
		Stops
		FOR Type IN ([Fresh Paper_Stops],[Storage Paper_Stops],[Total_Stops])
	) AS unpivot_stops
	UNPIVOT (
		Minutes
		FOR Type_Minutes IN ([Fresh Paper_Minutes],[Storage Paper_Minutes],[Total_Minutes])
	) AS unpivot_stops
	UNPIVOT (
		ELP
		FOR Type_ELP IN ([Fresh Paper_ELP],[Storage Paper_ELP],[Total_ELP])
	) AS unpivot_elp
	WHERE REPLACE(Type, '_Stops', '') = REPLACE(Type_Minutes, '_Minutes', '')
		AND REPLACE(Type, '_Stops', '') = REPLACE(Type_ELP, '_ELP', '')
	ORDER BY PLDesc, Type

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 7. Equipment [Group] > ELP [Tab] => Get data for Top 5 Causes on Fresh Paper (All Roll Statuses)
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS7'
INSERT INTO #ELPTop5Causes (
			PLID				,
			PLDesc				,
			ParentPM			,
			Type				,
			StartTime			, 
			EndTime				,
			Reason2				,
			Stops)
	SELECT 
			t.PLID				,
			t.PLDesc			,
			e.ParentPM			,
			'Fresh Paper' Type	,
			t.StartTime			,
			t.EndTime			,
			d.Reason2			,
			COUNT(DISTINCT d.TEDetId) [NumStops]
		FROM #OpsDBELPData				e	WITH(NOLOCK) 
		JOIN @Equipment					t	ON e.ParentPLID = t.PLID
											AND e.PRConvStartTime < t.EndTime
											AND e.PRConvEndTime > t.StartTime
											AND e.InputOrder = 1
											AND e.FreshRolls = 1
		LEFT JOIN #OpsDBStopsCVTGs	d	WITH(NOLOCK)ON e.PLID = d.PLID
											AND d.StartTime >= e.PRConvStartTime
											AND d.StartTime < e.PRConvEndTime
											AND d.DTStatus = 1
											AND d.deleteFlag = 0
											AND d.PUDesc LIKE '%Converter Reliability%'
											AND (d.Reason1Category LIKE '%Category:Paper (ELP)%' 
												OR d.Reason2Category LIKE '%Category:Paper (ELP)%')
		WHERE d.Reason2 IS NOT NULL
			AND e.deleteFlag = 0
		GROUP BY t.PLID, t.PLDesc, e.ParentPM, StopsELP, Reason2, t.StartTime, t.EndTime
		ORDER BY NumStops DESC

UPDATE t 
	SET t.duration =  
			ISNULL((SELECT SUM(ISNULL(d.duration,0))
					FROM #OpsDBELPData			e WITH(NOLOCK)
					JOIN @Equipment				p ON p.PLID = e.ParentPLID
					JOIN #OpsDBStopsCVTGs		d WITH(NOLOCK)ON e.PLID = d.PLID
													AND t.Reason2 = d.Reason2
													AND t.PLID = p.PLID
													AND d.StartTime >= e.PRConvStartTime
													AND d.StartTime < e.PRConvEndTime
													AND e.FreshRolls = 1
													AND e.InputOrder = 1
													AND d.StartTime >= p.StartTime
													AND d.StartTime < p.EndTime
													AND d.deleteFlag = 0
													AND d.pudesc LIKE '%Converter Reliability%'
													AND (d.Reason1Category LIKE '%Category:Paper (ELP)%' 
														OR d.Reason2Category LIKE '%Category:Paper (ELP)%')
					WHERE e.deleteFlag = 0), 0)
	FROM #ELPTop5Causes t 
	WHERE t.Reason2 IS NOT NULL
		AND t.type = 'Fresh Paper'

UPDATE t 
	SET t.duration = t.duration + 
			ISNULL((SELECT SUM(ISNULL(e.TotalRateLossDT,0)/60.0) 
					FROM #OpsDBELPData			e WITH(NOLOCK)
					JOIN @Equipment				p ON p.PLID = e.ParentPLID
					JOIN #OpsDBStopsCVTGs		d WITH(NOLOCK)ON e.PLID = d.PLID
													AND t.Reason2 = d.Reason2
													AND t.PLID = p.PLID
													AND d.StartTime >= e.PRConvStartTime
													AND d.StartTime < e.PRConvEndTime
													AND d.deleteFlag = 0
													AND e.FreshRolls = 1
													AND e.InputOrder = 1
													AND d.StartTime >= p.StartTime
													AND d.StartTime < p.EndTime
													AND d.pudesc LIKE '%Rate%Loss%'
													AND (d.Reason1Category LIKE '%Category:Paper (ELP)%' 
														OR d.Reason2Category LIKE '%Category:Paper (ELP)%')
						WHERE e.deleteFlag = 0), 0)
	FROM #ELPTop5Causes t 
	WHERE t.Reason2 IS NOT NULL
		AND t.type = 'Fresh Paper'

UPDATE	t
	SET t.PaperRuntime = 
		(SELECT SUM(e.TotalFreshRuntimeLine/60.0) 
			FROM #OpsDBELPData	e WITH(NOLOCK) 
			WHERE EXISTS (SELECT *	FROM #OpsDBStopsCVTGs	d1	WITH(NOLOCK)
									JOIN @Equipment			e1 ON e1.PLID = e.ParentPLID
																AND d1.StartTime >= e1.StartTime
																AND d1.StartTime < e1.EndTime
									WHERE e.PLID = d1.PLID
										AND t.Reason2 = d1.Reason2
										AND e.deleteFlag = 0
										AND d1.deleteFlag = 0
										AND t.PLID = e1.PLID
										AND (d1.starttime BETWEEN e.PRConvStartTime AND e.PRConvEndTime
											OR d1.Endtime BETWEEN e.PRConvStartTime AND e.PRConvEndTime)
										AND e.FreshRolls = 1		
										AND (d1.Reason1Category LIKE '%Category:Paper (ELP)%' 
											OR d1.Reason2Category LIKE '%Category:Paper (ELP)%')
			)
			GROUP BY e.ParentPM)
	FROM #ELPTop5Causes t
	WHERE type = 'Fresh Paper'

UPDATE #ELPTop5Causes
	SET [PercentLoss] = ROUND(CASE WHEN PaperRuntime > 0 
								THEN Duration / PaperRuntime
							ELSE 0 END , 2)
						WHERE Type = 'Fresh Paper'

SELECT 
		 n.PLID
		,n.PLDesc
		,n.Reason2													'Cause'
		,n.Stops													'Stops'
		,n.PercentLoss												'Loss'
	FROM (
		SELECT 
			 ROW_NUMBER() OVER(PARTITION BY PLID ORDER BY PercentLoss DESC) AS Loss
			,PLID
			,PLDesc
			,Reason2
			,Stops
			,PercentLoss
			,Type
		FROM #ELPTop5Causes WITH(NOLOCK)) n 
	WHERE Loss IN (1, 2, 3, 4, 5)
	AND n.Type = 'Fresh Paper'
	ORDER BY n.PLID, n.PercentLoss DESC, Stops DESC

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 8. Equipment [Group] > ELP [Tab] => Get data for Top 5 Causes on Storage Paper (All Roll Statuses)
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS8'
INSERT INTO #ELPTop5Causes (
			PLID				,
			PLDesc				,
			ParentPM			,
			Type				,
			StartTime			, 
			EndTime				,
			Reason2				,
			Stops				,
			Duration 
		)
	SELECT 
			t.PLID				,
			t.PLDesc			,
			e.ParentPM			,  
			'Storage Paper' Type, 
			t.StartTime			,
			t.EndTime			,
			d.Reason2			, 
			COUNT(DISTINCT TEDetId) [NumStops], 
			SUM(d.Duration)			[Duration]
		FROM #OpsDBELPData				e	WITH(NOLOCK)
		JOIN @Equipment					t	ON e.ParentPLID = t.PLID
											AND e.InputOrder = 1
											AND e.StorageRolls = 1
		LEFT JOIN #OpsDBStopsCVTGs	d	WITH(NOLOCK)ON e.PLID = d.PLID
											AND d.deleteFlag = 0
											AND d.StartTime >= e.PRConvStartTime
											AND d.StartTime <= e.PRConvEndTime
											AND d.StartTime >= t.StartTime
											AND d.StartTime < t.EndTime
											AND d.StopsUnscheduledInternal = 1
											AND d.StopsELP = 1
		WHERE d.Reason2 IS NOT NULL
			AND e.deleteFlag = 0
		GROUP BY t.PLID, t.PLDesc, e.ParentPM, StopsELP, Reason2, t.StartTime, t.EndTime
		ORDER BY NumStops DESC
 
UPDATE t 
	SET t.Duration = t.Duration + 
			ISNULL((SELECT SUM(ISNULL(RawRateloss,0)/60.0) 
					FROM #OpsDBELPData				e	WITH(NOLOCK)
					JOIN @Equipment					p	ON p.PLID = e.ParentPLID
					LEFT JOIN #OpsDBStopsCVTGs	d	WITH(NOLOCK)ON e.PLID = d.PLID
														AND t.Reason2 = d.Reason2
														AND d.StartTime >= e.PRConvStartTime
														AND d.StartTime <= e.PRConvEndTime
														AND e.StorageRolls = 1
														AND e.InputOrder = 1
														AND d.StartTime >= p.StartTime
														AND d.StartTime < p.EndTime
														AND d.DTStatus = 1
														AND d.deleteFlag = 0
														AND ISNULL(d.RawRateloss,0) > 0
					WHERE e.deleteFlag = 0), 0)
	FROM #ELPTop5Causes t 
	WHERE t.Reason2 IS NOT NULL


UPDATE	t
	SET t.PaperRuntime = 
		(SELECT SUM(TotalRuntime/60.0) 
				FROM #OpsDBELPData		e	WITH(NOLOCK)
				JOIN @Equipment			p	ON p.PLID = e.ParentPLID
				JOIN #OpsDBStopsCVTGs	d	WITH(NOLOCK)ON e.PLID = d.PLID
											AND d.starttime < e.PRConvEndTime
											AND d.endtime > e.PRConvStartTime
											AND e.ParentPM = t.ParentPM
											AND e.StorageRolls = 1
											AND e.InputOrder = 1
											AND d.StartTime >= p.StartTime
											AND d.StartTime < p.EndTime
											AND d.DTStatus = 1
											AND d.deleteFlag = 0
											AND t.Reason2 = d.Reason2
											AND (d.StopsELP = 1 OR ISNULL(RawRateloss,0) > 0)
			WHERE d.Reason2 IS NOT NULL
				AND e.deleteFlag = 0
			GROUP BY e.ParentPM, d.Reason2)
	FROM #ELPTop5Causes t
	WHERE Type = 'Storage Paper'
	  

UPDATE #ELPTop5Causes
	SET [PercentLoss] = ROUND(CASE WHEN PaperRuntime > 0 
								THEN duration /PaperRuntime
							ELSE 0 END , 2)
						WHERE Type = 'Storage Paper'

SELECT	n.PLID
		,n.PLDesc
		,n.Reason2													'Cause'
		,n.Stops													'Stops'
		,n.PercentLoss												'Loss'
	FROM (
		SELECT 
			 ROW_NUMBER() OVER(PARTITION BY PLID ORDER BY PercentLoss DESC) AS Loss
			,PLID
			,PLDesc
			,Reason2
			,Stops
			,PercentLoss
			,Type
		FROM #ELPTop5Causes) n 
	WHERE Loss IN (1, 2, 3, 4, 5)
	AND n.Type = 'Storage Paper'
	ORDER BY n.PLID, n.PercentLoss DESC, Stops DESC

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 9. Equipment [Group] > Reel Quality [Tab] => Get data for Quality grid (Old version without attributes)
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS9'
SELECT
		 e.PLID
		,e.PLDesc
		,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 
			  THEN 'All' 
			  ELSE TeamDesc + '-' + ProdCode 
		 END														'Equipment'
		,VarDesc													'TEST'
		,COUNT(*)													'COUNT'
		,CAST(MAX(Result) AS DECIMAL(18,2))							'MAX'
		,CAST(MIN(Result) AS DECIMAL(18,2))							'MIN'
		,CAST(AVG(CAST(Result AS FLOAT)) AS DECIMAL(18,2))			'AVG'
		,CAST(STDEV(CAST(Result AS FLOAT)) AS DECIMAL(18,4))		'STDDEV'
	FROM [dbo].[OpsDB_VariablesTasks_RawData]	v	WITH(NOLOCK)
	JOIN @Equipment								e	ON v.PLId = e.PLID
													AND (v.ResultOn BETWEEN e.StartTime AND e.EndTime)
													-- to activate index
													AND v.RcdIdx >= @minRcdIdx AND v.RcdIdx <= @maxRcdIdx
	WHERE Canceled = 0
		AND SamplesTaken = 1
		AND UDEDesc LIKE '%Rolls%'
		AND ISNUMERIC(Result) = 1
		GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), VarDesc, e.PLID, e.PLDesc
		ORDER BY PLID, Equipment, VarDesc

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 10. Equipment [Group] > Machine [Tab] => Get data for Speeds grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS10'
SELECT 
	 e.PLID
	,e.PLDesc
	,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 
		  THEN 'All' 
		  ELSE TeamDesc + '-' + ProdCode 
	 END																'Equipment'
	,AVG(YankeeSpeedSum)												'Yankee'
	,AVG(ReelSpeedSum)													'Reel'
	,CASE WHEN AVG(YankeeSpeedSum) > 0
		THEN ((AVG(ReelSpeedSum)-AVG(YankeeSpeedSum))/AVG(YankeeSpeedSum))*100	
		ELSE 0 END														'Crepe'
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
	GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 11. Equipment [Group] > Machine [Tab] => Get data for Clothing Life (hours) grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS11'
SELECT 
	 e.PLID
	,e.PLDesc
	,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 
		  THEN 'All' 
		  ELSE TeamDesc + '-' + ProdCode 
	 END							'Equipment'
	,MAX(BeltLife)					'Belt'
	,MAX(FormingWireLife)			'FormWire'
	,MAX(BackingWireLife)			'BackWire'
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN  @Equipment			e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 12. Equipment [Group] > Machine [Tab] => Get data for Paper Machine Reliability grid
-- Changed in Ver. 2.0			
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS12'
SELECT 
	 e.PLID
	,e.PLDesc
	,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 THEN 'All' 
	 ELSE TeamDesc + '-' + ProdCode 
	 END																		AS 'Equipment'
	--,CASE WHEN SUM(All_Tons) = 0 THEN NULL
	--	  WHEN SUM(All_Tons) > 0 THEN (SUM(GRHF_Tons)/SUM(All_Tons)*100)
	-- END																		AS 'PMBR_old'
	,CASE WHEN SUM(All_Tons) = 0 THEN NULL
		  WHEN SUM(All_Tons) > 0 THEN (1-(SUM(GRHF_Tons)/SUM(All_Tons))) * 100
	 END																		AS 'PMBR'
	--,CASE WHEN SUM(ProductTime) = 0 THEN NULL
	--	  WHEN SUM(ProductTime) > 0 THEN 100 - ((SUM(GI_Downtime)+SUM(GE_Downtime))/SUM(ProductTime)*100)
	-- END																		AS 'PMDT_old'
	,CASE WHEN SUM(ProductTime) = 0 THEN NULL
		  WHEN SUM(ProductTime) > 0 THEN ((SUM(GI_Downtime)+SUM(GE_Downtime))/SUM(ProductTime)) * 100
	 END																		AS 'PMDT'
	--,CASE
	--	  WHEN  SUM(GRHF_Tons) = 0 THEN NULL
	--	  WHEN  SUM(GRHF_Tons) > 0 THEN 100 - (SUM(RejectTons)/SUM(GRHF_Tons)*100)
	-- END																		AS 'PMRJ_old'
	,CASE
		  WHEN  SUM(GRHF_Tons) = 0 THEN NULL
		  WHEN  SUM(GRHF_Tons) > 0 THEN (SUM(RejectTons)/SUM(GRHF_Tons)*100)
	 END																		AS 'PMRJ'
	,'N/A'																		AS 'PMRL'
	,CASE
		  WHEN SUM(All_Tons) = 0 OR SUM(ProductTime) = 0 OR SUM(GRHF_Tons) = 0 THEN Null
		  WHEN SUM(All_Tons) > 0 OR SUM(ProductTime) > 0 OR SUM(GRHF_Tons) > 0 THEN
			  (SUM(GRHF_Tons)/SUM(All_Tons)) * (1-(SUM(GI_Downtime)+SUM(GE_Downtime))/SUM(ProductTime)) * (1-SUM(RejectTons)/SUM(GRHF_Tons))*100
	 END																		AS 'MOPR'
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
										AND pd.deleteFlag = 0
	GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc

--return

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 13. Equipment [Group] > Machine [Tab] => Get data for Machine Time grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS13'
SELECT 
	 e.PLID
	,e.PLDesc
	,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 
		  THEN 'All' 
		  ELSE TeamDesc + '-' + ProdCode 
	 END																'Equipment'
	,SUM(GI_Uptime)														'GIUptime'
	,SUM(GI_Downtime)													'GIDowntime'
	,SUM(GE_Uptime)														'GEUptime'
	,SUM(GE_Downtime)													'GEDowntime'
	,SUM(ProductTime)													'TotalTime'
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 14. Equipment [Group] > Machine [Tab] => Get data for Energy & Water grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS14'
SELECT 
	 PLID
	,PLDesc
	,Equipment
	,Type = CASE Description WHEN 'Water' THEN 'Water' ELSE 'Energy' END
	,Description
	,Usage
	,TNE
	,UsageUOM
	FROM (
		SELECT 
			 e.PLID																	[PLID]
			,e.PLDesc																[PLDesc]
			,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 THEN 'All' 
				  ELSE TeamDesc + '-' + ProdCode 
			 END																	[Equipment]
			,SUM(ISNULL(Gas_Sum,0))													[Gas]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0
				  WHEN SUM(TAYTons) > 0 THEN SUM(Gas_Sum)/SUM(TAYTons)
			 END																	[Gas_TNE]
			,Gas_UOM																[Gas_Usage_UOM]
			,SUM(ISNULL(Steam_Sum,0))												[Steam]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0
				  WHEN SUM(TAYTons) > 0 THEN SUM(Steam_Sum)/SUM(TAYTons)
			 END																	[Steam_TNE]
			,Steam_UOM																[Steam_Usage_UOM]
			,SUM(ISNULL(Electric_Sum,0))											[Electric]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0
				  WHEN SUM(TAYTons) > 0 THEN SUM(Electric_Sum)/SUM(TAYTons)
			 END																	[Electric_TNE]
			,Electric_UOM															[Electric_Usage_UOM]
			,SUM(ISNULL(Air_Sum,0))													[Air]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0
				  WHEN SUM(TAYTons) > 0 THEN SUM(Air_Sum)/SUM(TAYTons)
			 END																	[Air_TNE]
			,Air_UOM																[Air_Usage_UOM]
			,SUM(ISNULL(Water_Sum,0))												[Water]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0
				  WHEN SUM(TAYTons) > 0 THEN SUM(Water_Sum)/SUM(TAYTons)
			 END																	[Water_TNE]
			,Water_UOM																[Water_Usage_UOM]
		FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
		JOIN @Equipment				e	ON pd.PLId = e.PLID
										AND pd.deleteFlag = 0
		GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc, Gas_UOM, Steam_UOM, Electric_UOM, Air_UOM, Water_UOM
	) Speed
	UNPIVOT (
		Usage
		FOR Description IN (Gas, Steam, Electric, Air, Water)
	) AS unpivot_usage
	UNPIVOT (
		TNE
		FOR Desc_TNE IN (Gas_TNE, Steam_TNE, Electric_TNE, Air_TNE, Water_TNE)
	) AS unpivot_tne
	UNPIVOT (
		UsageUOM
		FOR Desc_Usage_UOM IN (Gas_Usage_UOM, Steam_Usage_UOM, Electric_Usage_UOM, Air_Usage_UOM, Water_Usage_UOM)
	) AS unpivot_usage_uom
	WHERE Description = REPLACE(Desc_TNE, '_TNE', '')
	AND Description = REPLACE(Desc_Usage_UOM, '_Usage_UOM', '')

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 15. Equipment [Group] > Machine [Tab] => Get data for Furnish grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS15'
SELECT 
	 PLID
	,PLDesc
	,Equipment
	,Furnish = REPLACE(Furnish, '_Tonnes', '')
	,Tonnes
	,Total
	FROM (
		SELECT 
			 e.PLID															[PLID]
			,e.PLDesc														[PLDesc]
			,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 THEN 'All' 
			 ELSE TeamDesc + '-' + ProdCode END								[Equipment]
			,SUM(Long_Fiber_Sum)											[Long Fiber_Tonnes]
			,CASE (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum)) WHEN 0 THEN 0
			 ELSE SUM(Long_Fiber_Sum) * 100 / (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum))
			 END															[Long Fiber_Total]
			,SUM(Product_Broke_Sum)											[Product Broke_Tonnes]
			,CASE (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum)) WHEN 0 THEN 0
			 ELSE SUM(Product_Broke_Sum) * 100 / (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum))
			 END															[Product Broke_Total]
			,SUM(Machine_Broke_Sum)											[Machine Broke_Tonnes]
			,CASE (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum)) WHEN 0 THEN 0
			 ELSE SUM(Machine_Broke_Sum) * 100 / (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum))
			 END															[Machine Broke_Total]
			,SUM(Short_Fiber_Sum)											[Short Fiber_Tonnes]
			,CASE (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum)) WHEN 0 THEN 0
			 ELSE SUM(Short_Fiber_Sum) * 100 / (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum))
			 END															[Short Fiber_Total]
			,SUM(T3rd_Furnish_Sum)											[Third Furnish_Tonnes]
			,CASE (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum)) WHEN 0 THEN 0
			 ELSE SUM(T3rd_Furnish_Sum) * 100 / (SUM(Long_Fiber_Sum) + SUM(Machine_Broke_Sum) + SUM(Product_Broke_Sum) + SUM(Short_Fiber_Sum) + SUM(T3rd_Furnish_Sum))
			 END															[Third Furnish_Total]
		FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
		JOIN @Equipment				e	ON pd.PLId = e.PLID
										AND pd.deleteFlag = 0
		GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc
	) Furnish
	UNPIVOT (
		Tonnes
		FOR Furnish IN ([Long Fiber_Tonnes], [Product Broke_Tonnes], [Machine Broke_Tonnes], [Short Fiber_Tonnes], [Third Furnish_Tonnes])
	) AS unpivot_tonnes
	UNPIVOT (
		Total
		FOR Furnish_Total IN ([Long Fiber_Total], [Product Broke_Total], [Machine Broke_Total], [Short Fiber_Total], [Third Furnish_Total])
	) AS unpivot_total
	WHERE REPLACE(Furnish, '_Tonnes', '') = REPLACE(Furnish_Total, '_Total', '')
	AND Tonnes > 0.0
	AND Total > 0.0

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 16. Equipment [Group] > Machine [Tab] => Get data for Chemical grid
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS16', Defoamer_Sum, Cat_Promoter_Sum, * 
--	from #OpsDBProductionDataPM
--	where Defoamer_Sum > 0
--		or Cat_Promoter_Sum > 0
	
SELECT
	 PLID
	,PLDesc
	,Equipment
	,Chemical = REPLACE(Chemical, '_Kgs', '')
	,Kgs
	,TNE
	FROM (
		SELECT 
			 e.PLID															[PLID]
			,e.PLDesc														[PLDesc]
			,CASE WHEN GROUPING(TeamDesc + '-' + ProdCode) = 1 THEN 'All' 
			 ELSE TeamDesc + '-' + ProdCode END								[Equipment]
			,SUM(Absorb_Aid_Towel_Sum)										[Absorb Aid Towel_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0
				  ELSE SUM(Absorb_Aid_Towel_Sum) / SUM(TAYTons)
			 END															[Absorb Aid Towel_TNE]
			,SUM(Dry_Strength_Towel_Sum)									[Dry Strength Towel_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Dry_Strength_Towel_Sum) / SUM(TAYTons)			
			 END															[Dry Strength Towel_TNE]
			,SUM(Emulsion_1_Sum)											[Emulsion 1_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Emulsion_1_Sum) / SUM(TAYTons)			
			 END															[Emulsion 1_TNE]
			,SUM(Emulsion_2_Sum)											[Emulsion 2_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Emulsion_2_Sum) / SUM(TAYTons)			
			 END															[Emulsion 2_TNE]
			,SUM(Glue_Adhesive_Sum)											[Glue Adhesive_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Glue_Adhesive_Sum) / SUM(TAYTons)			
			 END															[Glue Adhesive_TNE]
			,SUM(Glue_Crepe_Aid_Sum)										[Glue Crepe Aid_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Glue_Crepe_Aid_Sum) / SUM(TAYTons)			
			 END															[Glue Crepe Aid_TNE]
			,SUM(Glue_Release_Aid_Sum)										[Glue Release Aid_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Glue_Release_Aid_Sum) / SUM(TAYTons)			
			 END															[Glue Release Aid_TNE]
			,SUM(Single_Glue_Sum)											[Single Glue_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Single_Glue_Sum) / SUM(TAYTons)			
			 END															[Single Glue_TNE]
			,SUM(Glue_Total_Sum)											[Glue Total_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Glue_Total_Sum) / SUM(TAYTons)			
			 END															[Glue Total_TNE]
			,SUM(Wet_Strength_Tissue_Sum)									[Wet Strength Tissue_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Wet_Strength_Tissue_Sum) / SUM(TAYTons)			
			 END															[Wet Strength Tissue_TNE]
			,SUM(Wet_Strength_Towel_Sum)									[Wet Strength Towel_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Wet_Strength_Towel_Sum) / SUM(TAYTons)			
			 END															[Wet Strength Towel_TNE]
			,SUM(Wet_Strength_Facial_Sum)									[Wet Strength Facial_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Wet_Strength_Facial_Sum) / SUM(TAYTons)			
			 END															[Wet Strength Facial_TNE]
			,SUM(Aloe_E_Additive_Sum)										[Aloe E Additive_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Aloe_E_Additive_Sum) / SUM(TAYTons)			
			 END															[Aloe E Additive_TNE]
			,SUM(Biocide_Sum)												[Biocide_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Biocide_Sum) / SUM(TAYTons)			
			 END															[Biocide_TNE]
			,SUM(Chlorine_Control_Sum)										[Chlorine Control_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Chlorine_Control_Sum) / SUM(TAYTons)			
			 END															[Chlorine Control_TNE]
			-- Added in Ver. 1.8
			,SUM(Cat_Promoter_Sum)											[Cat_Promoter_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Cat_Promoter_Sum) / SUM(TAYTons)			
			 END															[Cat_Promoter_TNE]
			,SUM(Defoamer_Sum)												[Defoamer_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Defoamer_Sum) / SUM(TAYTons)			
			 END															[Defoamer_TNE]
			--
			,SUM(Dry_Strength_Facial_Sum)									[Dry Strength Facial_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Dry_Strength_Facial_Sum) / SUM(TAYTons)			
			 END															[Dry Strength Facial_TNE]
			,SUM(Dry_Strength_Tissue_Sum)									[Dry Strength Tissue_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Dry_Strength_Tissue_Sum) / SUM(TAYTons)			
			 END															[Dry Strength Tissue_TNE]
			,SUM(Recycle_Fiber_Sum)											[Recycle Fiber_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Recycle_Fiber_Sum) / SUM(TAYTons)			
			 END															[Recycle Fiber_TNE]
			,SUM(Flocculant_Sum)											[Flocculant_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Flocculant_Sum) / SUM(TAYTons)			
			 END															[Flocculant_TNE]
			,SUM(pH_Control_Tissue_Acid_Sum)								[pH Control Tissue Acid_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(pH_Control_Tissue_Acid_Sum) / SUM(TAYTons)			
			 END															[pH Control Tissue Acid_TNE]
			,SUM(pH_Control_Towel_Base_Sum)									[pH Control Towel Base_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(pH_Control_Towel_Base_Sum) / SUM(TAYTons)			
			 END															[pH Control Towel Base_TNE]
			,SUM(Softener_Tissue_Sum)										[Softener Tissue_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Softener_Tissue_Sum) / SUM(TAYTons)			
			 END															[Softener Tissue_TNE]
			,SUM(Softener_Facial_Sum)										[Softener Facial_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Softener_Facial_Sum) / SUM(TAYTons)			
			 END															[Softener Facial_TNE]
			,SUM(Softener_Towel_Sum)										[Softener Towel_Kgs]
			,CASE WHEN SUM(TAYTons) = 0 THEN 0								 
				  ELSE SUM(Softener_Towel_Sum) / SUM(TAYTons)			
			 END															[Softener Towel_TNE]
		FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
		JOIN @Equipment				e	ON pd.PLId = e.PLID
										AND pd.deleteFlag = 0
		GROUP BY ROLLUP(TeamDesc + '-' + ProdCode), e.PLID, e.PLDesc
	) Chemical
	UNPIVOT (
		Kgs
		FOR Chemical IN ([Absorb Aid Towel_Kgs],[Defoamer_Kgs],[Cat_Promoter_Kgs],[Dry Strength Towel_Kgs],
							[Emulsion 1_Kgs],[Emulsion 2_Kgs],[Glue Adhesive_Kgs],[Glue Crepe Aid_Kgs],
							[Glue Release Aid_Kgs],[Single Glue_Kgs],[Glue Total_Kgs],[Wet Strength Tissue_Kgs],
							[Wet Strength Towel_Kgs],[Wet Strength Facial_Kgs],[Aloe E Additive_Kgs],[Biocide_Kgs],
							[Chlorine Control_Kgs],[Dry Strength Facial_Kgs],[Dry Strength Tissue_Kgs],[Recycle Fiber_Kgs],
							[Flocculant_Kgs],[pH Control Tissue Acid_Kgs],[pH Control Towel Base_Kgs],[Softener Tissue_Kgs],
							[Softener Facial_Kgs],[Softener Towel_Kgs])
	) AS unpivot_kgs
	UNPIVOT (
		TNE
		FOR Chemical_TNE IN ([Absorb Aid Towel_TNE],[Defoamer_TNE],[Cat_Promoter_TNE],[Dry Strength Towel_TNE],[Emulsion 1_TNE],
							[Emulsion 2_TNE],[Glue Adhesive_TNE],[Glue Crepe Aid_TNE],[Glue Release Aid_TNE],[Single Glue_TNE],
							[Glue Total_TNE],[Wet Strength Tissue_TNE],[Wet Strength Towel_TNE],[Wet Strength Facial_TNE],
							[Aloe E Additive_TNE],[Biocide_TNE],[Chlorine Control_TNE],[Dry Strength Facial_TNE],[Dry Strength Tissue_TNE],
							[Recycle Fiber_TNE],[Flocculant_TNE],[pH Control Tissue Acid_TNE],[pH Control Towel Base_TNE],
							[Softener Tissue_TNE],[Softener Facial_TNE],[Softener Towel_TNE])
	) AS unpivot_tne
	WHERE REPLACE(Chemical, '_Kgs', '') = REPLACE(Chemical_TNE, '_TNE', '')
	AND Kgs > 0.0
	AND TNE > 0.0
	--order by 2,3,4
	
--return

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 17. Equipment [Group] > Machine [Tab] => Cleaning and Creping Blades Summary (Ver 2.1)
-- -----------------------------------------------------------------------------------------------------------------------------
--select 'RS17'

-- Cleaning Blades
INSERT INTO #Blades
SELECT	 e.PLID
		,e.PLDesc
		,'All'										
		,1
		,'Last Cleaning Blade'						
		,CAST(MAX(LastCleaningBlades) AS VARCHAR)	
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY e.PLID, e.PLDesc
	ORDER BY e.PLDesc

INSERT INTO #Blades
SELECT	 e.PLID
		,e.PLDesc
		,'All'									
		,2
		, 'Clean Blades'
		,CAST(SUM(CleaningBlades) AS VARCHAR)	
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY e.PLID, e.PLDesc
	ORDER BY e.PLDesc

INSERT INTO #Blades
SELECT	 e.PLID
		,e.PLDesc
		,'All'									
		,3
		, 'Life Cleaning Blades'
		,CASE SUM(CleaningBlades) WHEN 0 THEN 0 
			ELSE SUM(LifeCleaningBlades) / SUM(CleaningBlades) END	
		--''
		--''
		--'LifeCrepingBlades'
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY e.PLID, e.PLDesc
	ORDER BY e.PLDesc

-- Creping Blades
INSERT INTO #Blades
SELECT	 e.PLID
		,e.PLDesc
		,'All'										
		,4
		,'Last Creping Blade'						
		,CAST(MAX(LastCrepingBlades) AS VARCHAR)	
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY e.PLID, e.PLDesc
	ORDER BY e.PLDesc

INSERT INTO #Blades
SELECT	 e.PLID
		,e.PLDesc
		,'All'									
		,5
		, 'Crepe Blades'
		,CAST(SUM(CrepingBlades) AS VARCHAR)	
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY e.PLID, e.PLDesc
	ORDER BY e.PLDesc

INSERT INTO #Blades
SELECT	 e.PLID
		,e.PLDesc
		,'All'									
		,6
		, 'Life Creping Blades'
		,CASE SUM(CrepingBlades) WHEN 0 THEN 0 
			ELSE SUM(LifeCrepingBlades) / SUM(CrepingBlades) END	
	FROM #OpsDBProductionDataPM	pd	WITH(NOLOCK)
	JOIN @Equipment				e	ON pd.PLId = e.PLID
									AND pd.deleteFlag = 0
	GROUP BY e.PLID, e.PLDesc
	ORDER BY e.PLDesc

-- Show data of Blades
SELECT * FROM #Blades
	ORDER BY PLDesc, OrderNum

-- -----------------------------------------------------------------------------------------------------------------------------
-- Result SET 18. Stops in the Reliability Units (Added in Ver.2.2)
-- -----------------------------------------------------------------------------------------------------------------------------
SELECT 'Reliability' type, * 
	FROM #OpsDBStopsPMs 
	WHERE PUDesc LIKE '%Reliability%'
		--AND Reason2 NOT LIKE '%False Sheetbreak Event%'
		--AND TEDetId <> 0
	ORDER BY PLDESC, PUDesc, StartTime

-- ----------------------------------------------------------------------------------------------------------------------------
-- Result SET 19. Time Preview
-- -----------------------------------------------------------------------------------------------------------------------------
SELECT TOP 1
		 NULL								'PLID'
		,NULL								'PLDesc'
		,@timeOption						'TimeOption'
		,CONVERT(VARCHAR, StartTime, 120)	'StartTime'
		,CONVERT(VARCHAR, EndTime, 120)		'EndTime'
		,CONVERT(VARCHAR, @GETDATE, 120)	'RunTime'
	FROM @Equipment
UNION
SELECT 
		 PLId		
		,PLDesc
		,@timeOption		
		,CONVERT(VARCHAR, StartTime, 120)
		,CONVERT(VARCHAR, EndTime, 120)
		,CONVERT(VARCHAR, @GETDATE, 120)	'RunTime'
	FROM @Equipment

-- -----------------------------------------------------------------------------------------------------------------------------
-- Drop tables
-- -----------------------------------------------------------------------------------------------------------------------------
DROP TABLE #Top5Sheetbreaks
DROP TABLE #ELPSummary
DROP TABLE #ELPTop5Causes
DROP TABLE #SheetScheduled
DROP TABLE #OpsDBProductionDataPM
DROP TABLE #OpsDBStopsPMs
DROP TABLE #OpsDBELPData
DROP TABLE #OpsDBStopsCVTGs
DROP TABLE #Blades
GO

-- -----------------------------------------------------------------------------------------------------------------------------
GRANT EXECUTE ON [dbo].[spRptSummaryDDS] TO OpDBWriter
GO
