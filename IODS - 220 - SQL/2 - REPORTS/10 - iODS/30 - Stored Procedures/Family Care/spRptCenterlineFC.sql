USE Auto_opsDataStore
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
		@SP_Name	= 'spRptCenterlineFC',
		@Inputs		= 5, 
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
	INSERT INTO dbo.AppVersions (
		App_name,
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
				
DROP PROCEDURE [dbo].[spRptCenterlineFC]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptCenterlineFC
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-12-11
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for Centerline Family Care Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-12-11		Gonzalo Luc     		Initial Release
-- 1.1		2019-07-11		Damian Campana			Add parameters StartTime & EndTime for Filter <User Defined>
-- 1.2		2019-09-14		Gonzalo Luc				Auto shiftly returns only subbed columns tests. Change query to not miss displays. Change split condition from ',' to '|'.
-- 1.3		2019-10-21		Pablo Galanzini			Fix a bug of tkt #1209 in Panaya: Centerline  Total Outside Reject doesn't match TGT Alarm or Reject Limits Tab
-- 1.4		2019-10-30		Gonzalo Luc				Fix limit field name on Raw data output.
-- 1.5		2020-04-02		Pablo Galanzini			Fix some bugs from issues in Oxnard (PRB0067653 INC5353309 INC5419302)
--			2020-04-17		Pablo Galanzini			Fix to speedup the search in VarTask table to force to use the PK
-- 1.6		2020-06-12		Pablo Galanzini			Fix Team and Shift when the Units haven't Production in the IODS. Ex. PK21 in MP (PRB0070405 - INC5809572) 
--			2020-06-12		Pablo Galanzini			Fix a bug in DataType
--			2020-07-01		Pablo Galanzini			Show error message when happens “Error converting data type varchar to float."
-- 1.7		2020-09-29		Pablo Galanzini			When it search the data of stops is missing these stops split by Shift and Midnights (field DTStatus).
--													New fields in the Summary Result Set to calculate the summary correctly. 
--													On summary page, the site wants to add another % Comment for Warnings with comment.
--													Add new RS with Lines, Units, dates, displays, etc. to use in summary and definition tabs
-- 1.8		2020-10-23		Pablo Galanzini			In relation the % compliant for warning and reject the calculation should be as follows:
--													PercTGTWarnCompliant = 1 – (# CL Outside of Warning)/(Total # of centerlines)
--													PercTGTRejectCompliant = 1 – (# CL Outside of Reject)/(Total # of centerlines) 
-- 1.9		2021-02-01		Pablo Galanzini			INC7418984 - PRB0078507: Grey cell adding additional line to the report. It was searching the product wrongly
-- 2.0		2021-02-19		Pablo Galanzini			INC7538716: delete Columns when the production data for Converters or PMs yet aren't transferred to IODS.
--													Fix to open stops in IODS.
-- 2.1		2021-03-02		Pablo Galanzini			Fix to don't delete the lines without Cvtg's production (Ex. PK21 in Mehoopany - PRB0079638 - No pack cl data is available)
-- 2.2		2021-03-05		Pablo Galanzini			Fix a bug when it compares the results and limits using float datatypes. 
-- 2.3		2021-03-23		Pablo Galanzini			Fix a bug when it searchs the stops in differents Units but in the same Display (PRB0080292 - INC7773405 in Cape). 
--													Fix a bug to take the Product information from VarTask instead Production Converter data. (INC7730651 in GBay)
--													Fix some queries to speedup the SProc to search the data in IODS
-- 2.4		2021-03-23		Pablo Galanzini			FO-04774: add total commnents and total commnents warning for Paper Machines
-- 2.5		2021-07-02		Pablo Galanzini			FO-04837: Add Variable ID column to HTML5 Centerline Raw Data Tab
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================
CREATE PROCEDURE [dbo].[spRptCenterlineFC]
--DECLARE
	 @strLineId				NVARCHAR(MAX)	= NULL	
	,@timeOption			INT				= NULL
	,@strDisplay			NVARCHAR(MAX)	= NULL
	,@dtmStartTime			DATETIME		= NULL
	,@dtmEndTime			DATETIME		= NULL

--WITH ENCRYPTION 
AS
SET NOCOUNT ON

-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------
-- Test Lab0018: 
--	exec [dbo].[spRptCenterlineFC] '216,219',-1,'FC04 CL Bundler External Manual|FC03 CL Bundler External Manual|FC03 CL Bundler Internal Manual|FC04 CL Bundler Internal Manual', '2020/10/01 06:30:00','2020/10/02 06:30:00'
--	exec [dbo].[spRptCenterlineFC] '38',-1,'FP12 CL Centerline Review', '2020/10/01 06:30:00','2020/10/02 06:30:00'

--SELECT  
--		 @strLineId	= '219'--,56,59,61'--118
--		,@timeOption	= 1
--		,@strDisplay = 'FC04 CL Bundler External Auto Shiftly|FC04 CL Bundler Internal Auto Shiftly|FC04 CL Casepacker External Auto Shiftly|FC04 CL Casepacker Internal Auto Shiftly|FC04 CL Coremachine Auto Shiftly|FC04 CL Karlinal Manual Shiftly|FC04 CL Logsaw External Auto Shiftly|FC04 CL Logsaw Internal Auto Shiftly|FC04 CL Pack Area External Auto Shiftly|FC04 CL Wrapper External Auto Shiftly|FC04 CL Wrapper Internal Auto Shiftly'

-- Ox:  exec [dbo].[spRptCenterlineFC] '27',-1, 'PC1X CL Centerline Review New', '2020-03-13 07:45:00.000', '2020-03-13 10:45:00.000'
--SELECT  
--	 @strLineId	= '27,23'--,56,59,61'--118	PRB0067653-INC5353309
--	,@timeOption	= -1
--	,@strDisplay = 'PC1X CL Centerline Review New'
--	,@dtmStartTime	= '2020-03-13 00:00:00.000'
--	,@dtmEndTime	= DATEADD(mi, 600, @dtmStartTime)

--SELECT  
--	 @strLineId	= '36'--,56,59,61'--118		INC5419302 
--	,@timeOption	= -1
--	,@strDisplay = 'OKK3 RTCIS'
--	,@dtmStartTime	= '2020-03-25 05:30:00.000'
--	,@dtmEndTime	= '2020-03-26 05:30:00.000'

-----------------------------------------------------------------------------------------------------------------------
DECLARE		@minRcdIdx							INT, 
			@maxRcdIdx							INT,
			@hasError							INT,
			@AuditFreqrUDPCL_Id					INT,
			@AuditFreqrUDPRTTNG_Id				INT,
			@AuditFreqrUDPRTTNG					NVARCHAR(255)	,
			@AuditFreqrUDPCL					NVARCHAR(255)

-- --------------------------------------------------------------------------------------------------------------------
DECLARE @Summary TABLE (
			RcdIdx						INT IDENTITY,
			PLID						INT			,
			DisplayId					INT			,
			SheetDesc					VARCHAR(100), -- NVARCHAR(MAX)
			ProdID						INT			,
			ProdDesc					NVARCHAR(50) ,
			TeamDesc					NVARCHAR(150),
			ShiftDesc					NVARCHAR(10) ,
			--
			TotalWithTgtOnly			INT DEFAULT 0,
			TotalTgtOutages				INT DEFAULT 0,
			TotalWarning				INT DEFAULT 0,
			TotalNoTGTOrWarning			INT DEFAULT 0,
			TotalOutWarningLimits		INT DEFAULT 0,
			TotalReject					INT DEFAULT 0,
			TotalNoTGTOrReject			INT DEFAULT 0,
			TotalOutRejectLimits		INT DEFAULT 0,
			--
			TotReqNoUserDefined1		INT DEFAULT 0,
			TotReqWarningNoUserDefined1	INT DEFAULT 0,
			TotReqRejectNoUserDefined1	INT DEFAULT 0,
			TotReqRejectUserDefined1	INT DEFAULT 0,
			TotCompNoUserDefined1		INT DEFAULT 0,
			TotCompWarningNoUserDefined1 INT DEFAULT 0,
			TotCompRejectNoUserDefined1	INT DEFAULT 0,
			TotReqPRCWithReject			INT DEFAULT 0,
			--
			NotDoneNoUserDefined1		INT DEFAULT 0,
			NotDoneWarningNoUserDefined1 INT DEFAULT 0,
			NotDoneRejectNoUserDefined1	INT DEFAULT 0,
			--
			NotDoneReject				INT,
			NotDoneRejectUserDefined1	INT DEFAULT 0,
			TotalRequiredReject			INT DEFAULT 0,
			TotalCompletedReject		INT DEFAULT 0,
			--
			TotalComments				INT DEFAULT 0,
			TotalCommentsW				INT DEFAULT 0,
			TotalAlarms					INT DEFAULT 0,
			--
			TotalRequired				FLOAT DEFAULT 0,
			TotalCompleted				FLOAT DEFAULT 0,
			PercComplete				FLOAT DEFAULT 0,
			TotalOutsideWarn			FLOAT DEFAULT 0,
			--PercTGTWarnCompliantOld		FLOAT DEFAULT 0,
			PercTGTWarnCompliant		FLOAT DEFAULT 0,
			PercTGTWarnComplete			FLOAT DEFAULT 0,
			--PercTGTRejectCompliantOLd	FLOAT DEFAULT 0,
			PercTGTRejectCompliant		FLOAT DEFAULT 0,
			PercTGTRejectComplete		FLOAT DEFAULT 0,
			TotalNotDone				FLOAT DEFAULT 0,
			PercCommented				FLOAT DEFAULT 0,
			PercCommentedW				FLOAT DEFAULT 0,
			TotalOutTGT					FLOAT DEFAULT 0,
			TotalCompletedWithWarn		FLOAT DEFAULT 0,
			TotalNotDoneWWarnLimits		FLOAT DEFAULT 0,
			TotReqWithReject			FLOAT DEFAULT 0,
			TotalCompletedWithReject	FLOAT DEFAULT 0,
			TotalNotDoneWRejectLimits	FLOAT DEFAULT 0
)

-- --------------------------------------------------------------------------------------------------------------------
DECLARE @TGTVariables TABLE(
			VarID						INT,
			VarDesc						VARCHAR(50),
			ATDesc						VARCHAR(50))

-- --------------------------------------------------------------------------------------------------------------------
DECLARE @AuditPUID TABLE (
			PUID							INT,
			PUDESC							VARCHAR(50),
			PLID							INT,
			ScheduleUnit					INT,
			ScheduleUnitDesc				VARCHAR(50),
			MasterUnit						INT,
			MasterUnitDesc					VARCHAR(50),
			ConverterProductionUnitID		INT,
			UWSProductionUnitID				INT,
			CalcMasterUnit AS COALESCE(MasterUnit, PUID) PERSISTED,
			INDEX Idx_PlIdMasterUnit NONCLUSTERED(PLID, CalcMasterUnit),
			INDEX Idx_PUId NONCLUSTERED(PUId))

-- --------------------------------------------------------------------------------------------------------------------
-- Variables_base AND Tables
-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Equipment', 'U') IS NOT NULL
	DROP TABLE #Equipment

CREATE TABLE #Equipment (
			 RcdIdx						INT IDENTITY
			,PLId						INT
			,PLDesc						NVARCHAR(100)
			,DeptId						INT
			,DeptDesc					NVARCHAR(100)
			,DeptType					NVARCHAR(10)
			,StartTime					DATETIME
			,EndTime					DATETIME
)
-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Displays', 'U') IS NOT NULL
	DROP TABLE #Displays

CREATE TABLE #Displays(
			Idx									INT IDENTITY,
			DisplayId							INT,
			Display								NVARCHAR(1000),
			Sheet_Type							INT,
			Dynamic_Rows						INT,
			isAuto								INT DEFAULT 0)

-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#DisplayColumns', 'U') IS NOT NULL
	DROP TABLE #DisplayColumns

CREATE TABLE #DisplayColumns (
			PLID								INT,
			LineStopped							INT DEFAULT 0,
			DisplayID							INT,
			DisplayName							VARCHAR(100),
			DisplayType							INT,
			DynamicRowFlag						INT,
			VarConfigCount						INT,
			ColumnOn							DATETIME,
			TeamDesc							VARCHAR(10),
			ShiftDesc							VARCHAR(10),
			ProdID								INT,
			ProdCode							VARCHAR(100),
			ProdDesc							VARCHAR(100)
			--DevComment							VARCHAR(100)
			)

-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#DisplayVariables', 'U') IS NOT NULL
	DROP TABLE #DisplayVariables

CREATE TABLE #DisplayVariables (
			VARID								INT,
			VarDesc								VARCHAR(100),
			Var_Order							INT,
			DisplayID							INT,
			PLID								INT,
			PUID								INT,
			DataType							VARCHAR(50),
			UserDefined1						VARCHAR(255))
		CREATE UNIQUE NONCLUSTERED INDEX PK_DisplayVariables ON #DisplayVariables (VarID, DisplayId)

-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Alarms', 'U') IS NOT NULL
	DROP TABLE #Alarms

CREATE TABLE #Alarms (
			AlarmId								INT,
			plid								INT,
			pldesc								VARCHAR(100),
			DisplayID							INT,
			DisplayName							VARCHAR(100),
			PUDesc								VARCHAR(100),
			varid								INT,
			vardesc								VARCHAR(255),
			AlarmDesc							VARCHAR(500),
			AlarmTemplate						VARCHAR(500),
			StartTime							DATETIME,
			EndTime								DATETIME,
			TeamDesc							VARCHAR(10),
			ShiftDesc							VARCHAR(10),
			ProdId								INT,
			ProdCode							VARCHAR(25),
			ProdDesc							VARCHAR(255),
			CommentCnt							INT DEFAULT 0,
			-- Added in Ver. 2.4
			CommentFlagReject					INT DEFAULT 0,
			CommentFlagWarning					INT DEFAULT 0,
			--
			ActionCommentID						INT,
			--
			ResultOnIODS						DATETIME,
			Result								VARCHAR(50),
			LowerReject							VARCHAR(50),
			LowerWarning						VARCHAR(50),
			TargetTest							VARCHAR(50),
			UpperWarning						VARCHAR(50),
			UpperReject							VARCHAR(50),
			--
			LRejectAlarm						VARCHAR(50),
			TargetAlarm							VARCHAR(50),
			URejectAlarm						VARCHAR(50),
			StartValue							VARCHAR(50),
			EndValue							VARCHAR(50)
)

-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#VariableTask', 'U') IS NOT NULL
	DROP TABLE #VariableTask

CREATE TABLE #VariableTask (
--			TestID								INT IDENTITY,
			VarID								INT,
			PLID								INT,
			LineStopped							INT DEFAULT 0,
			PUID								INT,
			PUDESC								VARCHAR(255),
			isValid								INT DEFAULT 0,
			DataType							VARCHAR(50),
			ResultOn							DATETIME,
			resultOnIODS						DATETIME NULL,
			EntryOn								DATETIME,
			ModifiedOn							DATETIME,
			DisplayId							INT,
			SheetDesc							VARCHAR(100),
			--DisplayDept							VARCHAR(50),
			DynamicRowFlag						INT,
			TeamDesc							VARCHAR(10),
			ShiftDesc							VARCHAR(10),
			ProdID								INT,
			ProdCode							VARCHAR(25),
			ProdDesc							NVARCHAR(50) ,
			VarDesc								VARCHAR(100),
			Frequency							NVARCHAR(200) ,
			Result								VARCHAR(50),
			LowerControl						VARCHAR(50),
			LowerReject							VARCHAR(50),
			LowerWarning						VARCHAR(50),
			LowerUser							VARCHAR(50),
			Target								VARCHAR(50),
			UpperUser							VARCHAR(50),
			UpperWarning						VARCHAR(50),
			UpperReject							VARCHAR(50),
			UpperControl						VARCHAR(50),
			--INC7773405
			LowerEntry							VARCHAR(50),
			UpperEntry							VARCHAR(50),
			Defect								INT DEFAULT 0,
			--
			HaveReject							BIT NOT NULL DEFAULT 0,
			HaveWarning							BIT NOT NULL DEFAULT 0,
			HaveTGT								BIT NOT NULL DEFAULT 0,
			OutReject							INT,
			OutWarning							INT,
			OutTGT								INT,
			NoTGTOrReject						INT,
			NoTGTOrWarning						INT,
			UserDefined1						VARCHAR(255),
			CommentId							INT,
			Comment								VARCHAR(MAX),
			DevComment							VARCHAR(100),
			--
			TypeOfViolation						VARCHAR(10),
			CheckForTargetAlarm					VARCHAR(50))

CREATE UNIQUE NONCLUSTERED INDEX tVarProdResultOn ON dbo.#VariableTask (VarID, ResultOn, DisplayId)

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
			RawRateloss				FLOAT NULL,
			RateLossRatio			FLOAT NULL,
			Repulper_Tons			DECIMAL(12, 3) NULL)

-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#VariableError', 'U') IS NOT NULL
	DROP TABLE #VariableError

CREATE TABLE #VariableError (
			TypeErr								VARCHAR(50),
			--TestID								INT,
			VarID								INT,
			PLID								INT,
			LineStopped							INT DEFAULT 0,
			PUID								INT,
			Unit								VARCHAR(100),
			isValid								INT DEFAULT 0,
			DataType							VARCHAR(50),
			ResultOn							DATETIME,
			resultOnIODS						DATETIME NULL,
			EntryOn								DATETIME,
			ModifiedOn							DATETIME,
			DisplayId							INT,
			SheetDesc							VARCHAR(100),
			--DisplayDept							VARCHAR(50),
			DynamicRowFlag						INT,
			TeamDesc							VARCHAR(10),
			ShiftDesc							VARCHAR(10),
			ProdID								INT,
			ProdCode							VARCHAR(25),
			ProdDesc							NVARCHAR(50) ,
			VarDesc								VARCHAR(100),
			Frequency							NVARCHAR(200) ,
			Result								VARCHAR(50),
			LowerControl						VARCHAR(50),
			LowerReject							VARCHAR(50),
			LowerWarning						VARCHAR(50),
			LowerUser							VARCHAR(50),
			Target								VARCHAR(50),
			UpperUser							VARCHAR(50),
			UpperWarning						VARCHAR(50),
			UpperReject							VARCHAR(50),
			UpperControl						VARCHAR(50),
			--INC7773405
			LowerEntry							VARCHAR(50),
			UpperEntry							VARCHAR(50),
			Defect								INT,
			HaveReject							BIT NOT NULL DEFAULT 0,
			HaveWarning							BIT NOT NULL DEFAULT 0,
			HaveTGT								BIT NOT NULL DEFAULT 0,
			OutReject							INT,
			OutWarning							INT,
			OutTGT								INT,
			NoTGTOrReject						INT,
			NoTGTOrWarning						INT,
			UserDefined1						VARCHAR(50),
			CommentId							INT,
			Comment								VARCHAR(MAX),
			DevComment							VARCHAR(100),
			--
			TypeOfViolation						VARCHAR(10),
			CheckForTargetAlarm					VARCHAR(50))
	CREATE UNIQUE NONCLUSTERED INDEX tVariableErrorUnique ON dbo.#VariableError (VarID, ResultOn, DisplayId)

-- --------------------------------------------------------------------------------------------------------------------
DECLARE @BaseResults TABLE (
			DisplayId							INT,
			DisplayName							VARCHAR(100),
			Plid								INT,
			ProdID								INT,
			ProdName							VARCHAR(100),
			ProdDesc							VARCHAR(100),
			Team								VARCHAR(10),
			Shift								VARCHAR(10),

			TotalWithTgtOnly					INT,
			TotalTgtOutages						INT,

			TotalWarning						INT,
			TotalNoTGTOrWarning					INT,
			TotalOutWarningLimits				INT,
			TotalReject							INT,
			TotalNoTGTOrReject					INT,
			TotalOutRejectLimits				INT,

			TotReqNoUserDefined1				INT,
			TotReqWarningNoUserDefined1			INT,
			TotReqRejectNoUserDefined1			INT,

			TotCompNoUserDefined1				INT,
			TotCompWarningNoUserDefined1		INT,
			TotCompRejectNoUserDefined1			INT,

			NotDoneReject						INT,
			NotDoneRejectUserDefined1			INT DEFAULT 0,
			NotDoneNoUserDefined1				INT,
			NotDoneWarningNoUserDefined1		INT,
			NotDoneRejectNoUserDefined1			INT,

			TotalComments						INT,
			TotalCommentsW						INT,
			TotalAlarms							INT)

---------------------------------------------------------------------------------------------------------
--	UDP Name
---------------------------------------------------------------------------------------------------------
SELECT  @AuditFreqrUDPCL	 	= 'Centerline_AuditFreq'
SELECT  @AuditFreqrUDPRTTNG	 	= 'RTT_AuditFreq'
SELECT	@hasError				= 0

----------------------------------------------------------------------------------------------------------
--	Search UDP Id in UDP_Dimension Table
----------------------------------------------------------------------------------------------------------
SELECT	@AuditFreqrUDPCL_Id		= UDPIdx FROM dbo.UDP_DIMENSION WITH(NOLOCK) WHERE UDPName = @AuditFreqrUDPCL
SELECT	@AuditFreqrUDPRTTNG_Id	= UDPIdx FROM dbo.UDP_DIMENSION WITH(NOLOCK) WHERE UDPName = @AuditFreqrUDPRTTNG

-- --------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO #Equipment(PLId) 
	SELECT	String 
	FROM dbo.fnLocal_Split(@strLineId, ',')

--Set the Start & End Time
IF @timeOption = -1
BEGIN
	UPDATE e 
		SET	e.StartTime = @dtmStartTime, 
			e.EndTime = @dtmEndTime
		FROM #Equipment e 
END
ELSE
BEGIN
	UPDATE	e 
		SET	e.StartTime = f.dtmStartTime, 
			e.EndTime =	f.dtmEndTime
		FROM	#Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS((SELECT DateDesc 
											   FROM	[dbo].[DATE_DIMENSION] WITH (NOLOCK)
											   WHERE DateId = @timeOption),e.plid) f

		--select @timeOption timeOption, * from dbo.fnGetStartEndTimeiODS((SELECT DateDesc 
		--									   FROM	[dbo].[DATE_DIMENSION] WITH (NOLOCK)
		--									   WHERE DateId = @timeOption),191) f
END

UPDATE e
	SET e.PLDesc = ld.LineDesc, 
		e.DeptId = ld.DeptId,
		e.DeptDesc	= ld.DeptDesc
	FROM #Equipment			e	WITH(NOLOCK)
	JOIN dbo.LINE_DIMENSION ld	WITH(NOLOCK)ON ld.PLId = e.PLId

UPDATE d SET
	DeptType = CASE WHEN d.DeptDesc LIKE 'Cvtg %'
						OR d.DeptDesc = 'Department'
						OR d.DeptDesc = 'Utilities'
					THEN 'Cvtg'
				WHEN d.DeptDesc = 'Pmkg'
					THEN 'Pmkg'
				WHEN d.DeptDesc = 'Intr'
					THEN 'Intr'
				WHEN d.DeptDesc = 'Whse'
					THEN 'Whse'
				ELSE NULL
				END
	FROM #Equipment d

SELECT	@dtmStartTime = e.StartTime ,
		@dtmEndTime = e.EndTime
	FROM #Equipment e
	
-- --------------------------------------------------------------------------------------------------------------------
--	1- Sheets from parameters.
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO #Displays (Display)
	SELECT String FROM dbo.fnLocal_Split(@strDisplay, '|')

UPDATE d
	SET DisplayId = (SELECT Sheet_Id FROM GBDB.dbo.Sheets WITH(NOLOCK)
						WHERE REPLACE(REPLACE(Sheet_Desc, '[', ''),']','') LIKE REPLACE(REPLACE(d.Display, '[', ''),']',''))
	FROM #Displays d

UPDATE d
	SET d.Sheet_Type = s.Sheet_Type,
		d.Dynamic_Rows = s.Dynamic_Rows
	FROM #Displays d
	JOIN GBDB.dbo.Sheets s WITH(NOLOCK) ON d.DisplayId = s.Sheet_Id
	
UPDATE d
	SET isAuto = 1
	FROM #Displays d
	WHERE d.Display LIKE '%Auto%' 
		--OR d.Display LIKE '%Auto Shiftly%'

-------------------------------------------------------------------------------
INSERT INTO @AuditPUID  (
			PUID,
			PUDESC,
			PLID)
	SELECT DISTINCT 
			pu.PU_ID,
			pu.PU_Desc,
			pu.PL_ID
		FROM GBDB.dbo.Variables_base	v	WITH (NOLOCK)
		JOIN GBDB.dbo.Sheet_Variables	sv	WITH (NOLOCK) ON sv.Var_ID = v.Var_ID
		JOIN GBDB.dbo.Sheets			s	WITH (NOLOCK) ON s.Sheet_ID = sv.Sheet_ID
		JOIN GBDB.dbo.Prod_Units_Base	pu	WITH (NOLOCK) ON v.PU_ID = pu.PU_ID
		JOIN #Displays					di	ON sv.Sheet_ID = di.DisplayId

UPDATE ap 
	SET	ScheduleUnit	= dbo.fnLocal_GlblParseInfo(pu.Extended_Info,'ScheduleUnit='),
		MasterUnit		= pu.Master_Unit,
		MasterUnitDesc	= m.pu_desc
	FROM @AuditPUID						ap
	JOIN GBDB.dbo.Prod_Units_Base		pu	WITH (NOLOCK) ON pu.PU_ID = ap.PUID
	LEFT JOIN GBDB.dbo.Prod_Units_Base	m	WITH (NOLOCK) ON pu.Master_Unit = m.PU_ID

UPDATE ap 
	SET	ScheduleUnit = dbo.fnLocal_GlblParseInfo(Extended_Info,'ScheduleUnit=')
	FROM @AuditPUID					ap
	JOIN GBDB.dbo.Prod_Units_Base	pu WITH (NOLOCK) ON pu.PU_ID = ap.MasterUnit
	WHERE ScheduleUnit IS NULL

UPDATE ap 
	SET	ap.ScheduleUnitDesc = pu.pu_desc
	FROM @AuditPUID					ap
	JOIN GBDB.dbo.Prod_Units_Base	pu	WITH (NOLOCK) ON pu.PU_ID = ap.ScheduleUnit

DELETE FROM #Equipment
	WHERE plid NOT IN (SELECT PLID FROM @AuditPUID)

--SELECT 'Equipment', LTRIM(STR(@timeOption))+'-'+ (SELECT DateDesc FROM DATE_DIMENSION WITH (NOLOCK) WHERE DateId = @timeOption) timeOption, GETDATE() TimeInSite, * FROM #Equipment WITH (NOLOCK)
--SELECT 'Displays', * FROM #Displays WITH (NOLOCK)
--SELECT 'Units of Variables', COALESCE(MasterUnit, PUID) UnitSearch, * FROM @AuditPUID order by puid
--return

-----------------------------------------------------------------------------------------------------------------------
-- Fill temp table WITH all downtime data needed.
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #OpsDBDowntimeUptimeData (
			RcdIdx					,
			StartTime				,
			EndTime					,
			Duration				,
			Total_Uptime			,
			Uptime					,
			Fault					,
			FaultCode				,
			Reason1Id				,
			Reason1					,
			Reason1Code				,
			Reason1Category			,
			Reason2Id				,
			Reason2					,
			Reason2Code				,
			Reason2Category			,
			Reason3Id				,
			Reason3					,
			Reason3Code				,
			Reason3Category			,
			Reason4Id				,
			Reason4					,
			Reason4Code				,
			Reason4Category			,
			Action1					,
			Action1Code				,
			Action2					,
			Action2Code				,
			Action3					,
			Action3Code				,
			Action4					,
			Action4Code				,
			Comments				,
			Planned					,
			Location				,
			ProdDesc				,
			ProdCode				,
			ProdFam					,
			ProdGroup				,
			ProcessOrder			,
			TeamDesc				,
			ShiftDesc				,
			LineStatus				,
			DTStatus				,
			PLDesc					,
			PUDesc					,
			PUID					,
			PLID					,
			BreakDown				,
			ProcFailure				,
			TransferFlag			,
			DeleteFlag				,
			Site					,
			TEDetId					,
			Ts						,
			IsContraint				,
			ProductionDay			,
			IsStarved				,
			IsBlocked				,
			ManualStops				,
			MinorStop				,
			MajorStop				,
			ZoneDesc				,
			ZoneGrpDesc				,
			LineGroup				,
			StopsEquipFails			,
			StopsELP				,
			StopsScheduled			,
			StopsUnscheduled		,
			StopsUnscheduledInternal,
			StopsUnscheduledBS		,
			StopsBlockedStarved		,
			ERTD_ID					,
			RawRateloss				,
			RateLossRatio			,
			Repulper_Tons			)
	SELECT	DISTINCT
			 du.RcdIdx			
			,du.StartTime		
			--  Changed in Ver. 2.0
			,ISNULL(du.EndTime, GETDATE())
			,Duration			
			,Total_Uptime		
			,Uptime				
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
			,RawRateloss			 
			,RateLossRatio			 
			,Repulper_Tons			 	
			FROM #Equipment											e	WITH(NOLOCK)
			JOIN @AuditPUID											a	ON e.PLId = a.PLID
			JOIN [Auto_opsDataStore].[dbo].[OpsDB_DowntimeUptime_Data]	du	WITH(NOLOCK)ON du.PLId = e.PLID
																		AND COALESCE(a.MasterUnit, a.PUID) = du.PUID
																		AND du.StartTime >= e.StartTime
																		--  Changed in Ver. 2.0
																		AND (du.EndTime < e.EndTime OR du.EndTime IS NULL)  
																		AND du.deleteFlag = 0
			
-- --------------------------------------------------------------------------------------------------------------------
--	2- Sheet Variables from sheets.
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO #DisplayVariables
SELECT 	DISTINCT
		v.Var_Id,
		V.Var_Desc,
		sv.Var_Order,
		sv.Sheet_Id,
		E.PLId	,
		v.PU_ID	,
		CASE	WHEN	v.Data_Type_Id IN (1, 2, 6, 7) THEN	'VARIABLE'
				ELSE	'ATTRIBUTE'
		END,
		v.User_Defined1
		--, sv.*
	FROM #Equipment					e	WITH (NOLOCK)
	JOIN @AuditPUID					a	ON e.plid = a.PLID
	JOIN GBDB.dbo.Variables_base	v	WITH (NOLOCK) ON a.PUID = v.PU_ID
	JOIN GBDB.dbo.Sheet_Variables	sv	WITH (NOLOCK) ON sv.Var_ID = v.Var_ID
	JOIN #Displays					di	WITH (NOLOCK) ON sv.Sheet_ID = di.DisplayId
	ORDER BY sv.Var_Order

--SELECT '#DisplayVariables', * FROM #DisplayVariables order by displayId, Var_Order

-- --------------------------------------------------------------------------------------------------------------------
--	3- Sheets Columns from sheets and times.
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO #DisplayColumns (
			PLID,
			DisplayID,
			DisplayName,
			DisplayType,
			DynamicRowFlag,
			ColumnOn)
	SELECT	DISTINCT
			e.plid,
			--ap.plid,
			--pu.PL_Id,
			--pu.PU_Id, pu.PU_Desc,
			di.DisplayID,
			di.Display,
			di.Sheet_Type,
			di.Dynamic_Rows,
			sc.Result_On
		FROM #Displays					di	WITH (NOLOCK)
		JOIN GBDB.dbo.Sheet_Columns		sc	WITH (NOLOCK) ON sc.Sheet_ID = di.DisplayID
		JOIN #DisplayVariables			sv	WITH (NOLOCK)ON di.DisplayID = sv.DisplayID
		--JOIN GBDB.dbo.Sheet_Variables	sv	WITH (NOLOCK)ON di.DisplayID = sv.Sheet_ID
		JOIN GBDB.dbo.Variables_base	va	WITH (NOLOCK)ON va.Var_ID = sv.VarID
		JOIN GBDB.dbo.Prod_Units_Base	pu  WITH (NOLOCK)ON va.pu_id = pu.PU_Id
		JOIN @AuditPUID					ap	ON ap.PUID = va.PU_ID
		JOIN #Equipment					e	WITH (NOLOCK)ON pu.PL_Id = e.plid AND e.PLId = ap.PLID
		WHERE (di.Sheet_Type = 1 OR di.Sheet_Type = 16 OR di.Sheet_Type = 25 OR di.Sheet_Type = 2 )
			AND sc.Result_On >= @dtmStartTime
			AND sc.Result_On < @dtmEndTime

-- --------------------------------------------------------------------------------------------------------------------
UPDATE d 
	SET VarConfigCount = (SELECT COUNT(DISTINCT VarID) 
								FROM #DisplayVariables	sv	WITH (NOLOCK)
								--FROM GBDB.dbo.Sheet_Variables sv WITH (NOLOCK)
								WHERE d.DisplayID = sv.DisplayID
									AND VarID IS NOT NULL)
	FROM #DisplayColumns d

-- --------------------------------------------------------------------------------------------------------------------
UPDATE d
	SET d.TeamDesc = p.TeamDesc, 
		d.ShiftDesc = p.ShiftDesc, 
		d.prodid	= p.prodid,
		d.ProdCode = p.ProdCode,
		d.ProdDesc = p.ProdDesc
	FROM dbo.#DisplayColumns			d	WITH(NOLOCK)
	JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = d.plid
	JOIN dbo.OpsDB_Production_Data_PM	p	WITH(NOLOCK)ON e.plid = p.plid
														AND d.ColumnOn >= p.StartTime	
														AND d.ColumnOn < p.EndTime
	WHERE e.DeptDesc LIKE 'Pmkg'
		AND p.DeleteFlag = 0

-- --------------------------------------------------------------------------------------------------------------------
UPDATE d
	SET d.TeamDesc	= p.TeamDesc, 
		d.ShiftDesc = p.ShiftDesc,
		d.prodid	= p.prodid,
		d.ProdCode	= p.ProdCode,
		d.ProdDesc	= p.ProdDesc
	FROM dbo.#DisplayColumns			d	WITH(NOLOCK)
	JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = d.plid
	JOIN dbo.OpsDB_Production_Data_Cvtg	p	WITH(NOLOCK)ON e.plid = p.plid
														AND d.ColumnOn >= p.StartTime	
														AND d.ColumnOn < p.EndTime
	WHERE e.DeptDesc NOT LIKE 'Pmkg'
		AND p.DeleteFlag = 0

-- --------------------------------------------------------------------------------------------------------------------
-- Get Stops
-- --------------------------------------------------------------------------------------------------------------------
UPDATE d SET d.LineStopped = 1
	FROM #DisplayColumns			d	WITH(NOLOCK)
	JOIN #Displays					di	WITH(NOLOCK)ON d.DisplayID = di.DisplayID 
													AND di.isAuto = 1
	-- Fix for Jeff call 2021-04-06
	JOIN #DisplayVariables			dv	WITH(NOLOCK)ON dv.DisplayID = di.DisplayID 
	JOIN @AuditPUID					ap	ON dv.puid = ap.puid
	JOIN #OpsDBDowntimeUptimeData	ted WITH(NOLOCK)ON ted.puid = ap.puid
										AND d.PLID = ted.PLID
	WHERE d.ColumnOn >= ted.StartTime
		AND d.ColumnOn < ted.EndTime
		AND ted.DeleteFlag = 0

--SELECT  distinct 'check stops', ap.puid, d.*
--	FROM #DisplayColumns			d	WITH(NOLOCK)
--	JOIN #Displays					di	WITH(NOLOCK)ON d.DisplayID = di.DisplayID 
--													AND di.isAuto = 1
--	JOIN #DisplayVariables			dv	WITH(NOLOCK)ON dv.DisplayID = di.DisplayID 
--	JOIN @AuditPUID					ap	ON dv.puid = ap.puid
--	JOIN #OpsDBDowntimeUptimeData	ted WITH(NOLOCK)ON ted.puid = ap.puid
--										AND d.PLID = ted.PLID
--	WHERE d.ColumnOn >= ted.StartTime
--		AND d.ColumnOn < ted.EndTime
--		AND ted.DeleteFlag = 0
--RETURN

-- --------------------------------------------------------------------------------------------------------------------
-- INC7538716: delete data in #DisplayColumns when not exists Team, Shift or Product
-- --------------------------------------------------------------------------------------------------------------------
DELETE d
	FROM #DisplayColumns d
	WHERE (TeamDesc IS NULL OR ShiftDesc IS NULL OR ProdID IS NULL)
	-- Added in Ver. 2.1: Fix to don't delete the lines without Cvtg's production (Ex. PK21 in Mehoopany)
	AND EXISTS (SELECT TOP 1 PLID 
					FROM dbo.OpsDB_Production_Data_Cvtg	p	WITH(NOLOCK)
					WHERE d.plid = p.plid
					AND p.DeleteFlag = 0
					AND p.StartTime < d.ColumnOn)

-- --------------------------------------------------------------------------------------------------------------------
--SELECT distinct 'Stops -->', ted.PLID, PLDesc, PUID, PUDesc, ted.TeamDesc, ted.ShiftDesc, DeleteFlag, StartTime, EndTime, Duration, Uptime
--	FROM #OpsDBDowntimeUptimeData ted 
--	join #DisplayColumns d on d.PLID = ted.PLID
--							and d.ColumnOn >= ted.StartTime
--							AND d.ColumnOn < ted.EndTime
--							AND ted.DeleteFlag = 0
--	order by StartTime
--SELECT 'Column Triggered -->', * FROM #DisplayColumns d WITH(NOLOCK) ORDER BY d.ColumnOn
--return

-- --------------------------------------------------------------------------------------------------------------------
--	Used to speedup to search in table [OpsDB_VariablesTasks_RawData] using the PK
-- --------------------------------------------------------------------------------------------------------------------
SELECT	@minRcdIdx = MIN(v.RcdIdx),
		@maxRcdIdx = MAX(v.RcdIdx)
	FROM [dbo].[OpsDB_VariablesTasks_RawData]	v	WITH(NOLOCK) 
	JOIN #Equipment								e	WITH(NOLOCK)ON e.plid = v.plid
													AND v.ResultOn >= e.StartTime
													AND v.ResultOn < e.EndTime

-- --------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX [TmpIdx_DisplayVariables]
	ON #DisplayVariables (PLId, PUId, VarId, DisplayID) 
	INCLUDE (UserDefined1, DataType, VarDesc)

CREATE UNIQUE NONCLUSTERED INDEX [TmpIdx_DisplayColumns]
	ON #DisplayColumns (DisplayId, PLId, ColumnOn) 
	INCLUDE (LineStopped, DisplayName, DynamicRowFlag, TeamDesc, ShiftDesc, Prodid, ProdCode, ProdDesc)

--return

-- --------------------------------------------------------------------------------------------------------------------
--	4- Variable task from IODS with VarId and ResultOn
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO #VariableTask (
			VarID,
			PLID,
			PUID,
			PUDESC,
			DataType,
			ResultOn,
			resultOnIODS,
			EntryOn,
			ModifiedOn,
			--
			LineStopped,
			--
			DisplayId,
			SheetDesc,
			DynamicRowFlag,
			TeamDesc,
			ShiftDesc,
			ProdID,
			ProdCode,
			ProdDesc,
			VarDesc,
			----
			Frequency,
			Result,
			LowerControl,
			LowerReject,
			LowerWarning,
			LowerUser,
			Target,
			UpperUser,
			UpperWarning,
			UpperReject,
			UpperControl,
			Defect,
			--
			UserDefined1,
			CommentId,
			Comment
			)
	SELECT	DISTINCT
			DV.VARID,
			dv.PLID,
			dv.PUId,
			ap.PUDesc,
			dv.DataType,
			DC.ColumnOn,
			t.ResultOn,
			T.EntryOn,
			T.ModifiedOn,
			--
			dc.LineStopped,
			--
			DC.DisplayId,
			DC.DisplayName,
			dc.DynamicRowFlag,
			-- INC7773405
			t.TeamDesc,
			t.ShiftDesc,
			--dc.TeamDesc,
			--dc.ShiftDesc,
			-- INC7730651
			t.ProdID,
			t.ProdCode,
			t.ProdDesc,
			--dc.ProdID,
			--DC.ProdCode,
			--DC.ProdDesc,
			--
			DV.VarDesc,
			--
			T.Frequency,
			T.Result,
			T.LControl,
			T.LReject,
			T.LWarning,
			T.LUser,
			Target,
			T.UUser,
			T.UWarning,
			T.UReject,
			T.UControl,
			T.Defect,
			--
			dv.UserDefined1,
			CommentId,
			T.CommentText
	FROM #DisplayVariables							DV
	INNER JOIN #DisplayColumns						DC	ON DV.DisplayID = dc.DisplayID
														AND DC.PLID = DV.PLID
	INNER JOIN @AuditPUID							ap	ON ap.PUID = DV.PUID
	LEFT JOIN [dbo].[OpsDB_VariablesTasks_RawData]	T	WITH(NOLOCK)
														ON T.VarID = DV.VARID
														AND T.ResultOn = DC.ColumnOn
														-- to activate index
														AND T.RcdIdx >= @minRcdIdx AND T.RcdIdx <= @maxRcdIdx
														AND T.PLId = DV.PLID
														AND T.PUID = DV.PUID

--select '#VariableTask-Start', PLID, DisplayId, SheetDesc, ProdId, ProdCode, TeamDesc, ShiftDesc, count(*) NumTests
--	from #VariableTask 
--	group by PLID, DisplayId, SheetDesc, ProdId, ProdCode, TeamDesc, ShiftDesc
--	ORDER BY PLID, DisplayId
--return

---------------------------------------------------------------------------------------------------------
--	Update Var Specs information from Proficy where the Results are nulls (INC7773405)
---------------------------------------------------------------------------------------------------------
UPDATE v
	SET LowerReject		=  vs.L_Reject	,
		UpperReject		=  vs.U_Reject	,
		LowerWarning	=  vs.L_Warning	,
		UpperWarning	=  vs.U_Warning	,
		LowerUser		=  vs.L_User	,
		UpperUser		=  vs.U_User	,
		Target			=  vs.Target	,
		LowerEntry		=  vs.L_Entry	,
		UpperEntry		=  vs.U_Entry
	FROM #VariableTask			v
	JOIN [GBDB].[dbo].Var_Specs	vs	WITH(NOLOCK)ON v.varid	=	vs.var_id 
												AND	vs.prod_id	=	v.prodid 
												AND	(vs.expiration_date IS NULL or vs.expiration_date > v.ResultOn)
	WHERE vs.Effective_Date <= v.ResultOn 
		AND v.Result IS NULL

-- --------------------------------------------------------------------------------------------------------------------
--  If there is no result value, limits or target, and the dynamic row flag is on, the test is not required.  Otherwise assume that it is.
-- --------------------------------------------------------------------------------------------------------------------
--SELECT 'DELETE', * FROM dbo.#VariableTask 
--	WHERE (DynamicRowFlag = 1 
--			AND Result IS NULL
--			AND LowerEntry IS NULL
--			AND LowerReject IS NULL
--			AND LowerWarning IS NULL
--			AND LowerUser IS NULL
--			AND Target IS NULL
--			AND UpperUser IS NULL
--			AND UpperWarning IS NULL
--			AND UpperReject IS NULL
--			AND UpperEntry IS NULL)
			
DELETE FROM dbo.#VariableTask 
	WHERE (DynamicRowFlag = 1 
			AND Result IS NULL
			AND LowerEntry IS NULL
			AND LowerReject IS NULL
			AND LowerWarning IS NULL
			AND LowerUser IS NULL
			AND Target IS NULL
			AND UpperUser IS NULL
			AND UpperWarning IS NULL
			AND UpperReject IS NULL
			AND UpperEntry IS NULL)

-- --------------------------------------------------------------------------------------------------------------------
--UPDATE v SET
--	DisplayDept = 
--		CASE 
--			WHEN CHARINDEX('Tissue',v.SheetDesc) > 0 
--				THEN 'Tissue'
--			WHEN CHARINDEX('Towel', v.SheetDesc) > 0 
--				THEN 'Towel'
--			WHEN CHARINDEX('Napkin', v.SheetDesc) > 0 
--				THEN 'Napkin'
--			WHEN CHARINDEX('Facial', v.SheetDesc) > 0 
--				THEN 'Facial'
--			ELSE 'ALL'
--		END
--	FROM dbo.#VariableTask v

-- --------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX TmpIdx_InsertTestsTimes ON #VariableTask
	(ResultOn, DisplayId) 
	INCLUDE (ProdID, ProdDesc, ProdCode, TeamDesc, ShiftDesc)
	
UPDATE t
	SET ProdID = tq.ProdID,
		ProdDesc = tq.ProdDesc,
		ProdCode = tq.ProdCode
	FROM #VariableTask t WITH(NOLOCK)
	INNER JOIN (SELECT ProdID, ProdDesc, ProdCode, DisplayId, MIN(ResultOn) AS ResultOn
					FROM #VariableTask tq
					WHERE tq.ProdID IS NOT NULL
					GROUP BY ProdID, ProdDesc, ProdCode, DisplayId) tq
			ON tq.DisplayId = t.DisplayId AND tq.ResultOn <= t.ResultOn
	WHERE t.ProdID IS NULL
	
---- --------------------------------------------------------------------------------------------------------------------
UPDATE t SET
    t.TeamDesc = ISNULL(t.TeamDesc, tq.TeamDesc),
	t.ShiftDesc = ISNULL(t.ShiftDesc, tq.ShiftDesc)
	FROM #VariableTask t WITH(NOLOCK)
	INNER JOIN (SELECT TeamDesc, ShiftDesc, DisplayId, ResultOn AS ResultOn
					FROM #VariableTask tq
					WHERE tq.TeamDesc IS NOT NULL
						AND tq.ShiftDesc IS NOT NULL
					GROUP BY TeamDesc, ShiftDesc, DisplayId, ResultOn) tq
					ON tq.DisplayId = t.DisplayId AND tq.ResultOn = t.ResultOn
	WHERE t.TeamDesc IS NULL OR t.ShiftDesc IS NULL

-- --------------------------------------------------------------------------------------------------------------------
DROP Index TmpIdx_InsertTestsTimes ON #VariableTask
-- --------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX TmpIdx_VT_isValid_LineStopped ON #VariableTask
	(IsValid, LineStopped)
				
-- --------------------------------------------------------------------------------------------------------------------
UPDATE 	vt
	SET isValid = 1
	FROM dbo.#VariableTask	vt	WITH(NOLOCK)
	WHERE LineStopped = 0
		AND isValid = 0

-- Commented in Ver 2.3
--UPDATE 	v
--	SET v.isValid = 1
--	FROM dbo.#VariableTask	v	WITH(NOLOCK)
--	WHERE v.LineStopped = 1
--		AND v.isValid = 0
--		AND NOT EXISTS (SELECT TOP 1 * FROM #OpsDBDowntimeUptimeData	d	WITH(NOLOCK)
--								WHERE v.PLID = d.PLID
--									AND v.PUID = d.PUID
--									AND d.DeleteFlag = 0
--									AND (v.ResultOn >= d.StartTime AND v.ResultOn < d.EndTime))

DROP INDEX TmpIdx_VT_isValid_LineStopped ON #VariableTask

-- --------------------------------------------------------------------------------------------------------------------
-- Update Frecuency field
-- --------------------------------------------------------------------------------------------------------------------
UPDATE v
	SET v.Frequency = udp.Value
	FROM #VariableTask	v 
	JOIN dbo.FACT_UDPs	udp	WITH(NOLOCK)ON	udp.VarId = v.VarId
										AND	(udp.UDP_Dimension_UDPIdx = @AuditFreqrUDPRTTNG_Id OR udp.UDP_Dimension_UDPIdx = @AuditFreqrUDPCL_Id)
										AND v.ResultOn >= udp.EffectiveDate
										AND (v.ResultOn < udp.ExpirationDate OR udp.ExpirationDate IS NULL)
	WHERE v.Frequency IS NULL

-- --------------------------------------------------------------------------------------------------------------------
--	Added in Ver 1.9 (INC7418984 - PRB0078507)
-- --------------------------------------------------------------------------------------------------------------------
UPDATE vt
	SET vt.ProdId	=	t.ProdId,
		vt.ProdCode	=	t.ProdCode,
		vt.ProdDesc	=	t.ProdDesc
	FROM dbo.#VariableTask	vt	
	JOIN dbo.#VariableTask	t	WITH(NOLOCK)ON t.DisplayId = vt.DisplayId
											AND t.ResultOn = vt.ResultOn
											AND t.PLID = vt.PLID	 
	WHERE vt.resultOnIODS IS NULL
		AND t.resultOnIODS IS NOT NULL
		AND ISNULL(vt.ProdId,0) <> ISNULL(t.ProdId,0)

UPDATE vt
	SET vt.TeamDesc	=	t.TeamDesc,
		vt.ShiftDesc=	t.ShiftDesc
	FROM dbo.#VariableTask	vt	
	JOIN dbo.#VariableTask	t	WITH(NOLOCK)ON t.DisplayId = vt.DisplayId
											AND t.ResultOn = vt.ResultOn
											AND t.PLID = vt.PLID	 
	WHERE vt.resultOnIODS IS NULL
		AND t.resultOnIODS IS NOT NULL
		AND (vt.TeamDesc IS NULL OR vt.ShiftDesc IS NULL)

-- --------------------------------------------------------------------------------------------------------------------
UPDATE vt
	SET vt.TeamDesc	= p.TeamDesc, 
		vt.ShiftDesc= p.ShiftDesc
	FROM dbo.#VariableTask				vt	WITH(NOLOCK)
	JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = vt.plid
	JOIN dbo.OpsDB_Production_Data_Cvtg	p	WITH(NOLOCK)ON e.plid = p.plid
														AND vt.resulton >= p.StartTime	
														AND vt.resulton < p.EndTime
	WHERE e.DeptDesc NOT LIKE 'Pmkg'
		AND p.DeleteFlag = 0
		AND vt.TeamDesc IS NULL

-- --------------------------------------------------------------------------------------------------------------------
UPDATE vt
	SET vt.prodid	= p.prodid,
		vt.ProdCode	= p.ProdCode,
		vt.ProdDesc	= p.ProdDesc
	FROM dbo.#VariableTask				vt	WITH(NOLOCK)
	JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = vt.plid
	JOIN dbo.OpsDB_Production_Data_Cvtg	p	WITH(NOLOCK)ON e.plid = p.plid
														AND vt.resulton >= p.StartTime	
														AND vt.resulton < p.EndTime
	WHERE e.DeptDesc NOT LIKE 'Pmkg'
		AND p.DeleteFlag = 0
		AND vt.prodid IS NULL

-- --------------------------------------------------------------------------------------------------------------------
UPDATE vt
	SET vt.TeamDesc	= p.TeamDesc, 
		vt.ShiftDesc= p.ShiftDesc
	FROM dbo.#VariableTask				vt	WITH(NOLOCK)
	JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = vt.plid
	JOIN dbo.OpsDB_Production_Data_PM	p	WITH(NOLOCK)ON e.plid = p.plid
														AND vt.resulton >= p.StartTime	
														AND vt.resulton < p.EndTime
	WHERE e.DeptDesc LIKE 'Pmkg'
		AND p.DeleteFlag = 0
		AND vt.TeamDesc IS NULL

-- --------------------------------------------------------------------------------------------------------------------
UPDATE vt
	SET vt.prodid	= p.prodid,
		vt.ProdCode	= p.ProdCode,
		vt.ProdDesc	= p.ProdDesc
	FROM dbo.#VariableTask				vt	WITH(NOLOCK)
	JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = vt.plid
	JOIN dbo.OpsDB_Production_Data_PM	p	WITH(NOLOCK)ON e.plid = p.plid
														AND vt.resulton >= p.StartTime	
														AND vt.resulton < p.EndTime
	WHERE e.DeptDesc LIKE 'Pmkg'
		AND p.DeleteFlag = 0
		AND vt.prodid IS NULL
		
-- --------------------------------------------------------------------------------------------------------------------
--SELECT '#Tests', DisplayId, SheetDesc, LineStopped, TeamDesc, ShiftDesc, Prodcode, ProdDesc, min(ResultOn), max(ResultOn), COUNT(*) Rows
--	FROM dbo.#VariableTask WITH (NOLOCK)
--	group by DisplayId, SheetDesc, LineStopped, TeamDesc, ShiftDesc, Prodcode, ProdDesc
--	order by Rows desc, ProdDesc, LineStopped, TeamDesc, ShiftDesc

--SELECT distinct '#VariableTask not complete', count(distinct testid) FROM dbo.#VariableTask WITH (NOLOCK)  where result is null
--union SELECT distinct '#VariableTask complete', count(distinct testid) FROM dbo.#VariableTask WITH (NOLOCK)  where result is not null

--select sheetdesc, ProdId, ProdCode, ProdDesc, TeamDesc, ShiftDesc, resulton, LineStopped, isvalid, count(distinct varid) Vars
--	FROM dbo.#VariableTask v WITH (NOLOCK)  
--	group by sheetdesc, ProdId, ProdCode, ProdDesc, TeamDesc, ShiftDesc, resulton, LineStopped, isvalid

--SELECT 'Vars-Disp-2', count(distinct varid) FROM dbo.#VariableTask v WITH (NOLOCK) 

--select '#VariableTask', * from #VariableTask 
--	where isValid = 1
--	order by ResultOn, VarID 
--return

-- --------------------------------------------------------------------------------------------------------------------
-- Alarms for Paper Machines
-- --------------------------------------------------------------------------------------------------------------------
IF ((SELECT COUNT(*) FROM #Equipment WHERE DeptType = 'Pmkg') > 0)
BEGIN

	INSERT INTO #Alarms (
			AlarmId				,
			plid				,		
			pldesc				,	
			DisplayID			,	
			DisplayName			,	
			PUDesc				,	
			varid				,	
			vardesc				,	
			AlarmDesc			,	
			AlarmTemplate		,	
			StartTime			,	
			EndTime				,	
			ProdCode			,	
			ProdDesc			,	
			CommentCnt			,
			ActionCommentID		,
			--
			LRejectAlarm		,
			TargetAlarm			,
			URejectAlarm		,
			StartValue			,
			EndValue			)	
		SELECT  DISTINCT
			a.AlarmId,
			--CONVERT(VARCHAR,COALESCE(a.ActionComment_Rtf,'')) ActionComment_Rtf, 
			e.plid,
			e.pldesc,
			s.DisplayID,
			s.DisplayName,
			a.PUDesc,
			a.varid,
			a.vardesc,
			a.AlarmDesc,
			a.AlarmTemplate,
			a.StartTime,
			a.EndTime,
			a.ProdCode,
			a.ProdDesc,
			CASE WHEN LEN(LTRIM(RTRIM(CONVERT(VARCHAR,COALESCE(a.ActionComment_Rtf,''))))) > 0 
				THEN 1 ELSE 0 END CommentCnt,
			a.ActionCommentID,
			a.LReject,
			a.Target,
			a.UReject,
			a.StartValue,
			a.EndValue
		FROM #DisplayColumns			s
		JOIN #Equipment					e	WITH(NOLOCK)ON e.plid = s.plid
		JOIN #DisplayVariables			sv	WITH(NOLOCK)ON s.DisplayID = sv.DisplayID
		JOIN dbo.OpsDB_Alarms_RawData	a	WITH(NOLOCK)ON a.VarID = sv.VarID
		WHERE a.DeleteFlag = 0
			AND e.Starttime <= a.StartTime 
			AND e.EndTime > a.StartTime
			AND e.DeptType = 'Pmkg'

	---------------------------------------------------------------------------------------------------------
	--	Update data from variables
	---------------------------------------------------------------------------------------------------------
	UPDATE a
		SET a.LowerReject	=  v.LowerReject	,
			a.UpperReject	=  v.UpperReject	,
			a.LowerWarning	=  v.LowerWarning	,
			a.UpperWarning	=  v.UpperWarning	,
			a.TargetTest	=  v.Target
		FROM dbo.#VariableTask	v
		JOIN dbo.#Alarms		a	WITH(NOLOCK)ON v.varid	= a.varid 
												AND v.ResultOn = a.StartTime
		
	---------------------------------------------------------------------------------------------------------
	--	Update if is the alarm was commented with Reject or Warning Limits
	---------------------------------------------------------------------------------------------------------
	UPDATE a
		SET CommentFlagReject = 1
		FROM dbo.#Alarms a	
		WHERE a.CommentCnt = 1
			AND (a.LRejectAlarm	IS NOT NULL OR a.URejectAlarm IS NOT NULL)

	UPDATE a
		SET CommentFlagWarning = 1
		FROM dbo.#Alarms a	
		WHERE a.CommentCnt = 1
			AND(a.LowerWarning	IS NOT NULL OR a.UpperWarning IS NOT NULL)
			AND (a.CommentFlagReject = 0)

	---------------------------------------------------------------------------------------------------------
	--	Update default case by Warning Limits
	---------------------------------------------------------------------------------------------------------
	UPDATE a
		SET CommentFlagWarning = 1
		FROM dbo.#Alarms a	
		WHERE a.CommentCnt = 1
			AND (a.CommentFlagWarning = 0 AND a.CommentFlagReject = 0)

	-- --------------------------------------------------------------------------------------------------------------------
	UPDATE t
		SET t.TeamDesc = p.TeamDesc, 
			t.ShiftDesc = p.ShiftDesc, 
			t.ProdDesc = p.ProdDesc,
			t.ProdID	= p.ProdID
		FROM dbo.OpsDB_Production_Data_PM	p	WITH(NOLOCK)
		JOIN dbo.#Equipment					e	WITH(NOLOCK)ON e.plid = p.plid
		JOIN dbo.#Alarms					t	WITH(NOLOCK)ON t.StartTime >= p.StartTime
															AND t.StartTime < p.EndTime
		WHERE e.DeptDesc LIKE 'Pmkg'
			AND p.DeleteFlag = 0

END 

--SELECT '#Alarms', plid, pldesc, displayId, DisplayName, prodid, prodcode, proddesc, teamdesc, shiftdesc, 
--	COUNT(distinct AlarmId) rows, sum(CommentCnt) CommentCnt, sum(CommentFlagReject) CommentFlagReject, SUM(CommentFlagWarning) CommentFlagWarning 
--	FROM #Alarms group by plid, pldesc, displayId, DisplayName, prodid, prodcode, proddesc, teamdesc, shiftdesc
--SELECT '#Alarms', ActionCommentID, CommentCnt, CommentFlagReject, CommentFlagWarning, * FROM #Alarms where ActionCommentID IS NOT NULL

-- --------------------------------------------------------------------------------------------------------------------
-- Update values for target, warning AND reject alarms
-- -------------------------------------------------------------------------------------------------------------------- 
CREATE NONCLUSTERED INDEX [TmpIdx_VtTarget_DataType_Result] ON #VariableTask
	(DataType, Result, Target)
	-- INCLUDE (LowerWarning, UpperWarning, HaveTGT, HaveWarning, HaveReject, SheetDesc, ResultOn, VarDesc, OutWarning, OutReject, OutTGT)

UPDATE t SET
	HaveReject = 1
	FROM dbo.#VariableTask t WITH (NOLOCK)
	WHERE (t.LowerReject IS NOT NULL OR t.UpperReject IS NOT NULL)

UPDATE t SET
	HaveWarning = 1
	FROM dbo.#VariableTask t WITH (NOLOCK)
	WHERE (LowerWarning IS NOT NULL OR UpperWarning IS NOT NULL) 
		AND DataType = 'VARIABLE' 

-- TgtAlarm
UPDATE t SET
	HaveTGT = 1
	FROM dbo.#VariableTask t WITH (NOLOCK)
	WHERE Target IS NOT NULL

UPDATE t SET
	NoTGTOrReject = CASE
						WHEN COALESCE(HaveTGT,0) <> 1
						AND COALESCE(HaveReject,0) <> 1
						THEN 1
						ELSE 0
		END
	FROM dbo.#VariableTask t WITH (NOLOCK)

UPDATE t SET
	NoTGTOrWarning = CASE
						WHEN COALESCE(HaveTGT,0) <> 1
						AND COALESCE(HaveWarning,0) <> 1
						AND DataType = 'VARIABLE'
						THEN 1
						ELSE 0
		END
	FROM dbo.#VariableTask t WITH (NOLOCK)

--------------------------------------------------------------------------------------------------------
--	Check for Errors in Conversion
--------------------------------------------------------------------------------------------------------
INSERT INTO #VariableError 
SELECT 'Warning Limit Wrong!!!', *
	FROM dbo.#VariableTask
	WHERE DataType = 'VARIABLE' 
		AND  Result IS NOT NULL
		AND HaveWarning = 1
		AND (ISNUMERIC(ISNULL(Result,0)) = 0 OR ISNUMERIC(ISNULL(LowerControl,0)) = 0 OR ISNUMERIC(ISNULL(LowerReject,0)) = 0 
				OR ISNUMERIC(ISNULL(LowerWarning,0)) = 0 OR ISNUMERIC(ISNULL(LowerUser,0)) = 0 OR ISNUMERIC(ISNULL(Target,0)) = 0 
				OR ISNUMERIC(ISNULL(UpperUser,0)) = 0 OR ISNUMERIC(ISNULL(UpperWarning,0)) = 0 OR ISNUMERIC(ISNULL(UpperReject,0)) = 0 
				OR ISNUMERIC(ISNULL(UpperControl,0)) = 0 )
	ORDER BY ResultOn, VarDesc
	
INSERT INTO #VariableError 
SELECT 'Reject Limit Wrong!!!', *
	FROM dbo.#VariableTask
	WHERE DataType = 'VARIABLE' 
		AND Result IS NOT NULL
		AND HaveReject = 1
		AND (ISNUMERIC(ISNULL(Result,0)) = 0 OR ISNUMERIC(ISNULL(LowerControl,0)) = 0 OR ISNUMERIC(ISNULL(LowerReject,0)) = 0 
				OR ISNUMERIC(ISNULL(LowerWarning,0)) = 0 OR ISNUMERIC(ISNULL(LowerUser,0)) = 0 OR ISNUMERIC(ISNULL(Target,0)) = 0 
				OR ISNUMERIC(ISNULL(UpperUser,0)) = 0 OR ISNUMERIC(ISNULL(UpperWarning,0)) = 0 OR ISNUMERIC(ISNULL(UpperReject,0)) = 0 
				OR ISNUMERIC(ISNULL(UpperControl,0)) = 0 )
	ORDER BY ResultOn, VarDesc

INSERT INTO #VariableError 
SELECT 'Target Wrong!!!', *
	FROM dbo.#VariableTask
	WHERE DataType = 'VARIABLE'
		AND Result IS NOT NULL 
		AND COALESCE(HaveTGT,0) = 1
		AND COALESCE(HaveWarning,0) <> 1
		AND COALESCE(HaveReject,0) <> 1
		AND (ISNUMERIC(ISNULL(Result,0)) = 0 OR ISNUMERIC(ISNULL(Target,0)) = 0)
	ORDER BY ResultOn, VarDesc

IF ((SELECT COUNT(*) FROM #VariableError) > 0)
BEGIN
	SET @hasError = 1
	--SELECT '#VariableError', * FROM #VariableError

	DELETE FROM dbo.#VariableTask
END

--return
--------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX [Update_VT] ON #VariableTask
	([DataType], [Result], [HaveReject]) 
	-- INCLUDE ([HaveWarning], [Target], [LowerReject], [UpperReject], [OutReject])


UPDATE dbo.#VariableTask SET
	OutReject = (CASE
					WHEN (LowerReject IS NOT NULL
						AND UpperReject IS NOT NULL) 
						AND	((CONVERT(FLOAT,Result) < CONVERT(FLOAT,LowerReject) 
							OR CONVERT(FLOAT,Result) > CONVERT(FLOAT,UpperReject)))	
					THEN 1
					WHEN (CONVERT(FLOAT,LowerReject) IS NOT NULL
						AND CONVERT(FLOAT,UpperReject) IS NULL	
						AND CONVERT(FLOAT,Result) < CONVERT(FLOAT,LowerReject))
					THEN 1
					WHEN (CONVERT(FLOAT,UpperReject) IS NOT NULL
						AND CONVERT(FLOAT,LowerReject) IS NULL	
						AND	CONVERT(FLOAT,Result) > CONVERT(FLOAT,UpperReject))
					THEN 1
					WHEN (LowerReject IS NOT NULL
						AND UpperReject IS NOT NULL) 
						AND	((CONVERT(FLOAT,Result) > CONVERT(FLOAT,LowerReject) 
						AND CONVERT(FLOAT,Result) < CONVERT(FLOAT,UpperReject)))	
					THEN 0
					WHEN ((CONVERT(FLOAT,LowerReject) IS NOT NULL
								AND CONVERT(FLOAT,UpperReject) IS NULL		
								AND	CONVERT(FLOAT,Result) > CONVERT(FLOAT,LowerReject))										 	
						OR (CONVERT(FLOAT,UpperReject) IS NOT NULL
								AND CONVERT(FLOAT,LowerReject) IS NULL   		
								AND	CONVERT(FLOAT,Result) < CONVERT(FLOAT,UpperReject))											
						OR (CONVERT(FLOAT,LowerReject) IS NOT NULL
								AND CONVERT(FLOAT,Result) = CONVERT(FLOAT,LowerReject)) 
						OR (CONVERT(FLOAT,UpperReject) IS NOT NULL
								AND CONVERT(FLOAT,Result) = CONVERT(FLOAT,UpperReject)))
					THEN 0
					ELSE NULL
		END)
	WHERE DataType = 'VARIABLE' 
		AND Result IS NOT NULL
		AND HaveReject = 1

UPDATE dbo.#VariableTask SET
	OutReject = (CASE WHEN Result = Target THEN 0 END)
	WHERE DataType = 'ATTRIBUTE' 
		AND Target IS NOT NULL  

UPDATE dbo.#VariableTask SET
	OutReject = (CASE
					WHEN Result = LowerReject 
						OR Result = UpperReject	
					THEN 1
					ELSE 0  --Intended to 'pass' entries for initials-type Variables_base.
					END)
	WHERE DataType = 'ATTRIBUTE' 
		AND Result IS NOT NULL 
		AND HaveReject = 1
		
UPDATE dbo.#VariableTask SET				
	OutWarning = (
		CASE
		WHEN (OutReject IS NULL OR OutReject = 0) 
			AND	(LowerWarning IS NOT NULL AND UpperWarning IS NOT NULL) 
			AND	((CONVERT(FLOAT,Result) < CONVERT(FLOAT,LowerWarning) 
				OR CONVERT(FLOAT,Result) > CONVERT(FLOAT,UpperWarning)))	
		THEN 1
		WHEN ((OutReject IS NULL OR OutReject = 0) 
			AND	CONVERT(FLOAT,LowerWarning) IS NOT NULL
			AND CONVERT(FLOAT,UpperWarning) IS NULL	
			AND	CONVERT(FLOAT,Result) < CONVERT(FLOAT,LowerWarning))
		THEN 1
		WHEN ((OutReject IS NULL OR OutReject = 0) 
			AND	CONVERT(FLOAT,UpperWarning) IS NOT NULL
			AND CONVERT(FLOAT,LowerWarning) IS NULL
			AND	CONVERT(FLOAT,Result) > CONVERT(FLOAT,UpperWarning))
		THEN 1
		WHEN (LowerWarning IS NOT NULL AND UpperWarning IS NOT NULL) 
			AND	((CONVERT(FLOAT,Result) > CONVERT(FLOAT,LowerWarning) 
			AND CONVERT(FLOAT,Result) < CONVERT(FLOAT,UpperWarning)))	
		THEN 0
		WHEN ((CONVERT(FLOAT,LowerWarning) IS NOT NULL
				AND CONVERT(FLOAT,UpperWarning) IS NULL	
				AND	CONVERT(FLOAT,Result) > CONVERT(FLOAT,LowerWarning))
				OR	(CONVERT(FLOAT,UpperWarning) IS NOT NULL
						AND CONVERT(FLOAT,LowerWarning) IS NULL   
						AND	CONVERT(FLOAT,Result) < CONVERT(FLOAT,UpperWarning))	
				OR	(CONVERT(FLOAT,LowerWarning) IS NOT NULL
						AND CONVERT(FLOAT,Result) = CONVERT(FLOAT,LowerWarning)) 
				OR	(CONVERT(FLOAT,UpperWarning) IS NOT NULL
						AND CONVERT(FLOAT,Result) = CONVERT(FLOAT,UpperWarning)))
		THEN 0
		WHEN OutReject = 1
		THEN 0
		ELSE NULL
		END)
	WHERE DataType = 'VARIABLE' 
		AND  Result IS NOT NULL
		AND HaveWarning = 1

-- TgtAlarm
UPDATE dbo.#VariableTask SET
	OutTGT = (CASE WHEN CONVERT(FLOAT,Result) <> CONVERT(FLOAT,Target)
				THEN 1
				ELSE NULL
			END)
	WHERE DataType = 'VARIABLE'
		AND Result IS NOT NULL 
		AND COALESCE(HaveTGT,0) = 1
		AND COALESCE(HaveWarning,0) <> 1
		AND COALESCE(HaveReject,0) <> 1

UPDATE dbo.#VariableTask SET
	TypeOfViolation = 'Limits'
	WHERE OutWarning = 1
		OR OutReject = 1

UPDATE dbo.#VariableTask SET
	TypeOfViolation = 'TGT'
	WHERE OutTGT = 1

--------------------------------------------------------------------------------------------------------
INSERT INTO @TGTVariables (
			VarID,
			VarDesc,
			ATDesc)
	SELECT DISTINCT
			v.Var_ID,
			v.Var_Desc, 
			atp.AT_Desc 
			FROM GBDB.dbo.Variables_base			v	WITH (NOLOCK)
			JOIN GBDB.dbo.Alarm_Template_Var_Data	atd WITH (NOLOCK) ON v.Var_ID = atd.Var_ID 
			JOIN GBDB.dbo.Alarm_Templates			atp WITH (NOLOCK) ON atp.AT_Id = atd.AT_Id 
			WHERE atp.AT_Desc LIKE '%RTT Alarm%'
				OR atp.AT_Desc LIKE '%CL Alarm Not At Target%'

UPDATE t 
	SET CheckForTargetAlarm = 'Target Alarm Required'
		FROM dbo.#VariableTask t
		WHERE COALESCE(HaveTGT,0) = 1
		AND COALESCE(HaveWarning,0) <> 1
		AND COALESCE(HaveReject,0) <>1

UPDATE t SET
	CheckForTargetAlarm = NULL --'TGT Alarm Found'
		FROM dbo.#VariableTask	t
		JOIN @TGTVariables		tgtv ON t.VarID = tgtv.VarID
		WHERE COALESCE(HaveTGT,0) = 1
		AND COALESCE(HaveWarning,0) <> 1
		AND COALESCE(HaveReject,0) <> 1

DROP INDEX [TmpIdx_VtTarget_DataType_Result] ON #VariableTask

-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO @BaseResults (
			DisplayId,
			DisplayName, 
			plid,
			ProdID,
			Team, 
			Shift)
	SELECT	DISTINCT
			d.DisplayID,
			d.DisplayName, 
			pu.pl_id,
			ps.Prod_ID,
			d.TeamDesc, 
			d.ShiftDesc
		--FROM @Runs
		FROM GBDB.dbo.Production_Starts		ps	WITH (NOLOCK)
		JOIN GBDB.dbo.Prod_units_base		pu	WITH (NOLOCK) ON ps.Pu_ID = pu.Pu_ID
		JOIN @AuditPUID						ap	ON COALESCE(ap.MasterUnit,ap.PUID) = ps.PU_ID 
		LEFT JOIN GBDB.dbo.Variables_base	v	WITH (NOLOCK) ON ap.PUID = v.PU_ID
		CROSS JOIN #DisplayColumns			d	WITH (NOLOCK) 
		WHERE ps.Start_Time < @dtmEndTime
			AND COALESCE(ps.End_Time,@dtmEndTime) > @dtmStartTime
			AND ps.Prod_ID > 1
			AND ps.Prod_ID IS NOT NULL

UPDATE br 
	SET	ProdName = p.Prod_Desc + ' (' + p.Prod_Code + ')',
		ProdDesc = p.Prod_Desc 
	FROM @BaseResults			br
	JOIN GBDB.dbo.Products_base	p ON br.ProdID = p.Prod_ID

-- --------------------------------------------------------------------------------------------------------------------
--select '@BaseResults-0', * from @BaseResults order by DisplayId, DisplayName
--return

-- --------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX [TmpIdx_VtBaseResult]
	ON #VariableTask
	(SheetDesc, ProdID, TeamDesc, ShiftDesc, isValid)
	INCLUDE (HaveTGT, OutTGT, HaveWarning, HaveReject, NoTGTOrWarning, OutWarning, NoTGTOrReject, OutReject, VarID, UserDefined1,
			Result, Comment, CommentId, DataType, LowerWarning, UpperWarning, LowerReject, UpperReject)

CREATE NONCLUSTERED INDEX [TmpIdx_AlBaseResult]
	ON #Alarms
	(DisplayName, TeamDesc, ProdId, ShiftDesc)
	INCLUDE (CommentFlagWarning, CommentFlagReject, AlarmId)

-- --------------------------------------------------------------------------------------------------------------------
UPDATE sr SET
	TotalWithTgtOnly =(SELECT COUNT(HaveTGT)
						FROM dbo.#VariableTask t WITH (NOLOCK)
						WHERE t.displayId = sr.DisplayId
							AND	t.ProdID = sr.ProdID
							AND	t.TeamDesc = sr.Team
							AND t.ShiftDesc = sr.Shift
							AND t.isValid = 1
							AND HaveTGT = 1
							AND HaveWarning <> 1
							AND HaveReject <> 1),
	TotalTgtOutages = (SELECT COUNT(OutTGT)
							FROM dbo.#VariableTask t WITH (NOLOCK)
							WHERE t.displayId = sr.DisplayId
								AND	t.ProdID = sr.ProdID
								AND	t.TeamDesc = sr.Team
								AND t.ShiftDesc = sr.Shift
								AND t.isValid = 1
								AND	t.OutTGT = 1),
	TotalWarning = (SELECT COUNT(HaveWarning)
						FROM dbo.#VariableTask t WITH (NOLOCK)
						WHERE t.displayId = sr.DisplayId
							AND	t.ProdID = sr.ProdID
							AND	t.TeamDesc = sr.Team
							AND t.ShiftDesc = sr.Shift
							AND t.isValid = 1
							AND	t.HaveWarning = 1), -- Error: IS NOT NULL
	TotalNoTGTOrWarning = (SELECT COUNT(NoTGTOrWarning) -- Before SUM
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.displayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.Team
									AND t.ShiftDesc = sr.Shift
									AND t.isValid = 1
									AND	t.NoTGTOrWarning = 1),
	TotalOutWarningLimits = (SELECT COUNT(OutWarning) -- Before SUM
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.displayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.Team
									AND t.ShiftDesc = sr.Shift
									AND t.isValid = 1
									AND t.OutWarning = 1),
	TotalReject = (SELECT COUNT(HaveReject)
						FROM #VariableTask t WITH (NOLOCK)
						WHERE t.displayId = sr.DisplayId
							AND	t.ProdID = sr.ProdID
							AND	t.TeamDesc = sr.Team
							AND t.ShiftDesc = sr.Shift
							AND t.isValid = 1
							AND	t.HaveReject = 1), -- Error: IS NOT NULL
	TotalNoTGTOrReject = (SELECT COUNT(NoTGTOrReject) -- Before SUM
							FROM #VariableTask t WITH (NOLOCK)
							WHERE t.displayId = sr.DisplayId
								AND	t.ProdID = sr.ProdID
								AND	t.TeamDesc = sr.Team
								AND t.ShiftDesc = sr.Shift
								AND t.isValid = 1
								AND	t.NoTGTOrReject = 1),
	TotalOutRejectLimits = (SELECT COUNT(OutReject) -- Before SUM
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.displayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.Team
									AND t.ShiftDesc = sr.Shift
									AND t.isValid = 1
									AND t.OutReject = 1),
	TotReqNoUserDefined1 = (SELECT COUNT(VarID)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.displayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.Team
									AND t.ShiftDesc = sr.Shift
									AND t.isValid = 1
									AND t.UserDefined1 IS NULL
									AND t.VarID IS NOT NULL),
	TotReqWarningNoUserDefined1 = (SELECT COUNT(VarID)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.displayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.Team
										AND t.ShiftDesc = sr.Shift
										AND t.isValid = 1
										AND	t.HaveWarning = 1
										AND t.UserDefined1 IS NULL
										AND t.VarID IS NOT NULL), -- Add
	TotReqRejectNoUserDefined1 = (SELECT COUNT(VarID)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.displayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.Team
										AND t.ShiftDesc = sr.Shift
										AND t.isValid = 1
										AND	t.HaveReject = 1
										AND t.UserDefined1 IS NULL
										AND t.VarID IS NOT NULL), -- Add
	TotCompNoUserDefined1 = (SELECT COUNT(Result)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.displayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.Team
									AND t.ShiftDesc = sr.Shift
									AND t.isValid = 1
									AND t.Result IS NOT NULL
									AND t.UserDefined1 IS NULL),
	TotCompWarningNoUserDefined1 = (SELECT COUNT(Result)
										FROM #VariableTask t WITH (NOLOCK)
										WHERE t.displayId = sr.DisplayId
											AND	t.ProdID = sr.ProdID
											AND	t.TeamDesc = sr.Team
											AND t.ShiftDesc = sr.Shift
											AND t.isValid = 1
											AND t.Result IS NOT NULL
											AND t.HaveWarning = 1
											AND t.UserDefined1 IS NULL),
	TotCompRejectNoUserDefined1 = (SELECT COUNT(Result)
										FROM #VariableTask t WITH (NOLOCK)
										WHERE t.displayId = sr.DisplayId
											AND	t.ProdID = sr.ProdID
											AND	t.TeamDesc = sr.Team
											AND t.ShiftDesc = sr.Shift
											AND t.isValid = 1
											AND t.Result IS NOT NULL
											AND t.HaveReject = 1
											AND t.UserDefined1 IS NULL),
	TotalComments = CASE WHEN e.DeptType = 'Cvtg'
								OR e.DeptType = 'Intr'
								OR e.DeptType = 'Whse'
							THEN (SELECT COUNT(OutReject)
										FROM #VariableTask t WITH (NOLOCK)
										WHERE t.displayId = sr.DisplayId
											AND	t.ProdID = sr.ProdID
											AND	t.TeamDesc = sr.Team
											AND t.ShiftDesc = sr.Shift
											AND t.isValid = 1
											AND t.OutReject = 1
											AND t.Comment > '')
						-- Comment by Alarms in Pmkg (Ex: MP8M CL Manual MA Log)
						WHEN e.DeptType = 'Pmkg'
							THEN (SELECT COUNT(CommentFlagReject) 
										FROM #Alarms a
										WHERE a.DisplayID = sr.DisplayID
											AND	a.TeamDesc = sr.Team
											AND a.ProdId = sr.ProdID
											AND a.ShiftDesc = sr.Shift
											AND a.CommentFlagReject = 1)
						ELSE 0
						END,
	TotalCommentsW = CASE WHEN e.DeptType = 'Cvtg'
								OR e.DeptType = 'Intr'
								OR e.DeptType = 'Whse'
							THEN (SELECT COUNT(OutWarning) -- Before SUM
										FROM #VariableTask t WITH (NOLOCK)
										WHERE t.displayId = sr.DisplayId
											AND	t.ProdID = sr.ProdID
											AND	t.TeamDesc = sr.Team
											AND t.ShiftDesc = sr.Shift
											AND t.isValid = 1
											AND t.OutWarning = 1
											AND	t.Comment >= '')
						WHEN e.DeptType = 'Pmkg'
							THEN (SELECT COUNT(CommentFlagWarning) 
										FROM #Alarms a
										WHERE a.DisplayID = sr.DisplayID
											AND	a.TeamDesc = sr.Team
											AND a.ProdId = sr.ProdID
											AND a.ShiftDesc = sr.Shift
											AND a.CommentFlagWarning = 1)
						ELSE 0
						END,
	TotalAlarms = CASE WHEN e.DeptType = 'Pmkg'
					THEN (SELECT  COUNT(DISTINCT AlarmId)
							FROM #Alarms a
							WHERE a.DisplayID = sr.DisplayID
								AND	a.TeamDesc = sr.Team
								AND	a.ProdID = sr.ProdID
								AND a.ShiftDesc = sr.Shift)
					ELSE 0 END
	FROM @BaseResults	sr
	JOIN #Equipment		e WITH(NOLOCK) ON sr.plid = e.plid

UPDATE sr 
	SET	TotalWithTgtOnly = 0,
		TotalTgtOutages = 0,
		TotalWarning = 0,
		TotalNoTGTOrWarning = 0,
		TotalOutWarningLimits = 0,
		TotalReject = 0,
		TotalNoTGTOrReject = 0,
		TotalOutRejectLimits = 0,
		TotReqNoUserDefined1 = 0,
		TotReqWarningNoUserDefined1 = 0,
		TotReqRejectNoUserDefined1 = 0,
		TotCompNoUserDefined1 = 0,
		TotCompWarningNoUserDefined1 = 0,
		TotCompRejectNoUserDefined1 = 0
	FROM @BaseResults sr
	WHERE TotCompNoUserDefined1 = 0

UPDATE sr SET
	NotDoneNoUserDefined1 = TotReqNoUserDefined1 - TotCompNoUserDefined1,
	NotDoneWarningNoUserDefined1 = TotReqWarningNoUserDefined1 - TotCompWarningNoUserDefined1,
	NotDoneRejectNoUserDefined1 = TotReqRejectNoUserDefined1 - TotCompRejectNoUserDefined1 
	FROM @BaseResults sr

UPDATE sr SET
	NotDoneNoUserDefined1 = 0
	FROM @BaseResults sr
	WHERE NotDoneNoUserDefined1 < 0	

UPDATE sr SET
	NotDoneWarningNoUserDefined1 = 0
	FROM @BaseResults sr
	WHERE NotDoneWarningNoUserDefined1 < 0	

UPDATE sr SET
	NotDoneRejectNoUserDefined1 = 0
	FROM @BaseResults sr
	WHERE NotDoneRejectNoUserDefined1 < 0	

UPDATE sr SET
	NotDoneReject = COALESCE(NotDoneRejectUserDefined1,0) + COALESCE(NotDoneRejectNoUserDefined1,0)
	FROM @BaseResults sr

-- Comment by Alarms in Pmkg (Ex: MP8M CL Manual MA Log)
--SELECT 'Comment PM', a.DisplayName,a.TeamDesc,a.ProdId,a.ShiftDesc, SUM(CommentCnt) CommentCnt, 
--	SUM(CommentFlagWarning) CommentFlagWarning, SUM(CommentFlagReject) CommentFlagReject
--	FROM #Alarms a
--	--where CommentFlagWarning > 0 or CommentFlagReject > 0
--	group by a.DisplayName,a.TeamDesc,a.ProdId,a.ShiftDesc

--select '@BaseResults-end', TotalComments, TotalCommentsW, TotalAlarms, * from @BaseResults 
--	where TotalComments > 0 or  TotalCommentsW > 0
--return

-- --------------------------------------------------------------------------------------------------------------------
-- Summary Section
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO @Summary (
			PLID
			,ProdID
			,DisplayId
			,SheetDesc
			,ProdDesc
			,TeamDesc
			,ShiftDesc)
	SELECT	PLID
			,ProdID
			,DisplayId
			,SheetDesc
			,ProdDesc
			,TeamDesc
			,ShiftDesc
	FROM dbo.#VariableTask
	-- drop team shift
	GROUP BY PLID, ProdID, DisplayId, SheetDesc, ProdDesc, TeamDesc, ShiftDesc
	ORDER BY PLID, ProdID, SheetDesc, ProdDesc, TeamDesc, ShiftDesc

UPDATE s
	SET s.TotalRequired =
		(SELECT COUNT(t.isValid)
				FROM #VariableTask t WITH (NOLOCK)
					WHERE t.DisplayId = s.DisplayId
					AND	t.ProdID = s.ProdID
					AND	t.TeamDesc = s.TeamDesc
					AND t.ShiftDesc = s.ShiftDesc
					AND t.isValid = 1
					)
	FROM @Summary s

-- -------------------------------------------------------------------------------------------------------------------
UPDATE sr -- @Summary
	SET	TotalWithTgtOnly = (SELECT COUNT(HaveTGT)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND HaveTGT = 1
									AND HaveWarning <> 1
									AND HaveReject <> 1),
	TotalTgtOutages = (SELECT COUNT(OutTGT)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND	t.OutTGT = 1 ),
	TotalWarning = (SELECT COUNT(HaveWarning)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND	t.HaveWarning = 1), -- Error: IS NOT NULL
	TotalNoTGTOrWarning = (SELECT COUNT(NoTGTOrWarning)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND	t.NoTGTOrWarning = 1), -- Error: IS NOT NULL
	TotalOutWarningLimits = (SELECT COUNT(OutWarning)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND t.OutWarning = 1),
	TotalReject = (SELECT COUNT(HaveReject)
							FROM #VariableTask t WITH (NOLOCK)
							WHERE t.DisplayId = sr.DisplayId
								AND	t.ProdID = sr.ProdID
								AND	t.TeamDesc = sr.TeamDesc
								AND t.ShiftDesc = sr.ShiftDesc
								AND t.isValid = 1
								AND	t.HaveReject = 1),
	TotalNoTGTOrReject = (SELECT COUNT(NoTGTOrReject)-- Before SUM
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND	t.NoTGTOrReject = 1),
	TotalOutRejectLimits = (SELECT COUNT(OutReject)-- Before SUM
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND OutReject = 1),
	TotReqNoUserDefined1 = (SELECT COUNT(VarID)
								FROM #VariableTask t WITH (NOLOCK)
								WHERE t.DisplayId = sr.DisplayId
									AND	t.ProdID = sr.ProdID
									AND	t.TeamDesc = sr.TeamDesc
									AND t.ShiftDesc = sr.ShiftDesc
									AND t.isValid = 1
									AND t.UserDefined1 IS NULL
									AND t.VarID IS NOT NULL), 
	TotReqWarningNoUserDefined1 = (SELECT COUNT(VarID)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.DisplayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.TeamDesc
										AND t.ShiftDesc = sr.ShiftDesc
										AND t.isValid = 1
										AND	t.HaveWarning = 1
										AND t.UserDefined1 IS NULL
										AND t.VarID IS NOT NULL),
	TotReqRejectNoUserDefined1 = (SELECT COUNT(VarID)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.DisplayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.TeamDesc
										AND t.ShiftDesc = sr.ShiftDesc
										AND t.isValid = 1
										AND	t.HaveReject = 1
										AND t.UserDefined1 IS NULL
										AND t.VarID IS NOT NULL),
	TotCompNoUserDefined1 = (SELECT COUNT(Result)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.DisplayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.TeamDesc
										AND t.ShiftDesc = sr.ShiftDesc
										AND t.isValid = 1
										AND t.Result IS NOT NULL
										AND t.UserDefined1 IS NULL),
	TotCompWarningNoUserDefined1 = (SELECT COUNT(Result)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.DisplayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.TeamDesc
										AND t.ShiftDesc = sr.ShiftDesc
										AND t.isValid = 1
										AND t.Result IS NOT NULL
										AND t.HaveWarning = 1
										AND t.UserDefined1 IS NULL),
	TotCompRejectNoUserDefined1 = (SELECT COUNT(Result)
									FROM #VariableTask t WITH (NOLOCK)
									WHERE t.DisplayId = sr.DisplayId
										AND	t.ProdID = sr.ProdID
										AND	t.TeamDesc = sr.TeamDesc
										AND t.ShiftDesc = sr.ShiftDesc
										AND t.isValid = 1
										AND t.Result IS NOT NULL
										AND t.HaveReject = 1
										AND t.UserDefined1 IS NULL),
	TotalComments = CASE WHEN e.DeptType = 'Cvtg'
								OR e.DeptType = 'Intr'
								OR e.DeptType = 'Whse'
							THEN (SELECT COUNT(OutReject)
										FROM #VariableTask t WITH (NOLOCK)
										WHERE t.DisplayId = sr.DisplayId
											AND	t.ProdID = sr.ProdID
											AND	t.TeamDesc = sr.TeamDesc
											AND t.ShiftDesc = sr.ShiftDesc
											AND t.isValid = 1
											AND t.OutReject = 1
											AND	t.Comment>='') -- t.Comment>='' OR CommentId IS NOT NULL
						-- Comment by Alarms in Pmkg (Ex: MP8M CL Manual MA Log)
						WHEN e.DeptDesc = 'Pmkg'
							THEN (SELECT COUNT(t.CommentFlagReject) -- Before SUM
										FROM #Alarms t
										WHERE t.DisplayId = sr.DisplayId
											AND	t.TeamDesc = sr.TeamDesc
											AND t.ProdId = sr.ProdID
											AND t.ShiftDesc = sr.ShiftDesc
											AND t.CommentFlagReject = 1)
						ELSE 0
						END,
	TotalCommentsW = CASE WHEN e.DeptType = 'Cvtg'
								OR e.DeptType = 'Intr'
								OR e.DeptType = 'Whse'
							THEN (SELECT COUNT(OutWarning)
										FROM #VariableTask t WITH (NOLOCK)
										WHERE t.DisplayId = sr.DisplayId
											AND	t.ProdID = sr.ProdID
											AND	t.TeamDesc = sr.TeamDesc
											AND t.ShiftDesc = sr.ShiftDesc
											AND t.isValid = 1
											AND t.OutWarning = 1
											AND	t.Comment > '') -- t.Comment>='' OR CommentId IS NOT NULL
						-- Comment by Alarms in Pmkg (Ex: MP8M CL Manual MA Log)
						WHEN e.DeptDesc = 'Pmkg'
							THEN (SELECT COUNT(t.CommentFlagWarning) -- Before SUM
										FROM #Alarms t
										WHERE t.DisplayId = sr.DisplayId
											AND	t.TeamDesc = sr.TeamDesc
											AND t.ProdId = sr.ProdID
											AND t.ShiftDesc = sr.ShiftDesc
											AND t.CommentFlagWarning = 1)
						ELSE 0
						END,
	TotalAlarms = CASE WHEN e.DeptType = 'Pmkg'
					THEN (SELECT  COUNT(DISTINCT AlarmId)
							FROM #Alarms a
							WHERE a.DisplayId = sr.DisplayId
								AND	a.TeamDesc = sr.TeamDesc
								AND	a.ProdID = sr.ProdID
								AND a.ShiftDesc = sr.ShiftDesc)
					ELSE 0 END
	FROM @Summary sr
	JOIN #Equipment e WITH(NOLOCK) ON sr.plid = e.plid

-- -------------------------------------------------------------------------------------------------------------------
UPDATE s 
	SET TotReqWithReject = COALESCE(TotReqRejectNoUserDefined1,0) + COALESCE(TotReqRejectUserDefined1,0) + COALESCE(TotReqPRCWithReject,0)
	FROM @Summary s

UPDATE s
	SET s.TotalCompleted = (SELECT COUNT(*) FROM #VariableTask vt
								WHERE vt.DisplayId = s.DisplayId
								AND	vt.ProdID = s.ProdID
								AND vt.TeamDesc = s.TeamDesc
								AND vt.ShiftDesc = s.ShiftDesc
								AND vt.isValid = 1
								AND vt.Result>'')
	   ,s.TotalOutsideWarn = (SELECT COUNT(*) FROM #VariableTask vt
								WHERE vt.DisplayId = s.DisplayId
								AND	vt.ProdID = s.ProdID
								AND vt.TeamDesc = s.TeamDesc
								AND vt.ShiftDesc = s.ShiftDesc
								AND vt.isValid = 1
								AND (vt.LowerWarning IS NOT NULL OR vt.UpperWarning IS NOT NULL)
								AND (CONVERT(FLOAT,vt.Result) < CONVERT(FLOAT,vt.LowerWarning) OR CONVERT(FLOAT,Result) > CONVERT(FLOAT,vt.UpperWarning))
								AND vt.DataType = 'VARIABLE')
	   ,s.TotalOutTGT = (SELECT COUNT(*) FROM #VariableTask vt
								WHERE vt.DisplayId = s.DisplayId
								AND	vt.ProdID = s.ProdID
								AND vt.TeamDesc = s.TeamDesc
								AND vt.ShiftDesc = s.ShiftDesc
								AND vt.isValid = 1
								AND vt.Target IS NOT NULL
								AND CONVERT(FLOAT, vt.Target) <> CONVERT(FLOAT,vt.Result)
								AND vt.LowerWarning IS NULL
								AND vt.UpperWarning IS NULL
								AND vt.LowerReject IS NULL
								AND vt.UpperReject IS NULL
								AND vt.DataType = 'VARIABLE')
	   ,s.TotalCompletedWithWarn = (SELECT COUNT(*) FROM #VariableTask vt
									WHERE vt.DisplayId = s.DisplayId
									AND	vt.ProdID = s.ProdID
									AND vt.TeamDesc = s.TeamDesc
									AND vt.ShiftDesc = s.ShiftDesc
									AND vt.isValid = 1
									AND vt.Result >=''
									AND vt.LowerWarning IS NOT NULL
									AND vt.UpperWarning IS NOT NULL
									AND vt.DataType = 'VARIABLE')
	   ,s.TotalCompletedWithReject = (SELECT COUNT(*) FROM #VariableTask vt
										WHERE vt.DisplayId = s.DisplayId
										AND	vt.ProdID = s.ProdID
										AND vt.TeamDesc = s.TeamDesc
										AND vt.ShiftDesc = s.ShiftDesc
										AND vt.isValid = 1
										AND vt.Result > ''
										AND vt.LowerReject IS NOT NULL
										AND vt.UpperReject IS NOT NULL
										AND vt.DataType = 'VARIABLE')
	FROM @Summary s
	
UPDATE s 
	SET	s.NotDoneReject = (SELECT SUM(NotDoneReject) FROM @BaseResults vt 
								WHERE vt.DisplayId = s.DisplayId
									AND vt.ProdID = s.ProdID 
									AND vt.Team = s.TeamDesc 
									AND vt.Shift = s.ShiftDesc)
	   ,s.TotalNotDone = CASE WHEN (s.TotalRequired - s.TotalCompleted) >= 0 
								THEN s.TotalRequired - s.TotalCompleted 
							ELSE 0 END
	FROM @Summary s

UPDATE s
	SET	
	   s.PercComplete = 
			CASE WHEN CAST(s.TotalRequired AS FLOAT) > 0 
				THEN (CAST(s.TotalCompleted AS FLOAT) / CAST(s.TotalRequired AS FLOAT)) * 100
				ELSE 0 
			END
		-- Old Changed in Ver 1.8
	  -- ,s.PercTGTWarnCompliantOld =
			--CASE WHEN (s.TotalWithTgtOnly + s.TotalWarning) > 0 
			--	THEN (1 - ((CAST(s.TotalOutTGT AS FLOAT) + CAST(s.TotalOutsideWarn AS FLOAT)) / (CAST(s.TotalWithTgtOnly AS FLOAT) + CAST(s.TotalWarning AS FLOAT)))) * 100  
			--ELSE 0 END
	   ,s.PercTGTWarnCompliant =			-- PercTGTWarnCompliant = 1 – (# CL Outside of Warning)/(Total # of centerlines)
			CASE WHEN (s.TotalRequired) > 0 
				THEN (1 - (CAST(s.TotalOutsideWarn AS FLOAT)) / (CAST(s.TotalRequired AS FLOAT))) * 100  
			ELSE 0 END
	   ,s.TotalNotDoneWWarnLimits = 
			CASE WHEN (TotalWarning - TotalCompletedWithWarn) >= 0 
				THEN (TotalWarning - TotalCompletedWithWarn) 
			ELSE 0 END
	   ,s.PercTGTWarnComplete = 
			CASE WHEN (s.TotalWithTgtOnly + s.TotalWarning) > 0 
				THEN (1 - ((CAST(s.TotalOutTGT AS FLOAT) + CAST(s.TotalOutsideWarn AS FLOAT) + CAST(s.TotalNotDoneWWarnLimits AS FLOAT)) / (CAST(s.TotalWithTgtOnly AS FLOAT) + CAST(s.TotalWarning AS FLOAT)))) * 100 
			ELSE 0 END
		-- Old Changed in Ver 1.8
	  -- ,s.PercTGTRejectCompliantOLd = 
			--CASE WHEN (s.TotalWithTgtOnly + s.TotReqWithReject) > 0 
			--	THEN (1 - ((CAST(s.TotalOutTGT AS FLOAT) + CAST(s.TotalOutRejectLimits AS FLOAT)) / (CAST(s.TotalWithTgtOnly AS FLOAT) + CAST(s.TotReqWithReject AS FLOAT)))) * 100  
			--ELSE 0 END
	   ,s.PercTGTRejectCompliant =		-- PercTGTRejectCompliant = 1 – (# CL Outside of Reject)/(Total # of centerlines) 
			CASE WHEN (s.TotalRequired) > 0 
				THEN (1 - ((CAST(s.TotalOutRejectLimits AS FLOAT)) / (CAST(s.TotalRequired AS FLOAT)))) * 100  
			ELSE 0 END
	   ,s.TotalNotDoneWRejectLimits = 
			CASE WHEN (TotReqWithReject - TotalCompletedWithReject) >= 0 
				THEN (TotReqWithReject - TotalCompletedWithReject) 
			ELSE 0 END
	FROM @Summary s

UPDATE s
	SET	
	   s.PercCommented = CASE WHEN s.TotalOutRejectLimits > 0 
							THEN s.TotalComments / s.TotalOutRejectLimits 
							ELSE 0 END * 100.0
	   ,s.PercCommentedW = CASE WHEN s.TotalOutsideWarn > 0 
							THEN s.TotalCommentsW / s.TotalOutsideWarn 
							ELSE 0 END * 100.0
	   ,s.PercTGTRejectComplete = 
							CASE WHEN (CONVERT(FLOAT,TotalWithTgtOnly) + CONVERT(FLOAT,TotReqWithReject)) > 0.0
								THEN 1.0 - ((TotalTgtOutages + TotalOutRejectLimits + NotDoneReject) 
									/ (CONVERT(FLOAT,TotalWithTgtOnly) + CONVERT(FLOAT,TotReqWithReject))) 
							ELSE 0 END
	FROM @Summary s

-- --------------------------------------------------------------------------------------------------------------------
-- Summary Result Set
-- -------------------------------------------------------------------------------------------------------------------- 
IF (@hasError = 0)
	SELECT	DISTINCT
			 s.SheetDesc              
			,s.ProdDesc               
			,s.TeamDesc               
			,s.ShiftDesc              
			--
			,ISNULL(s.TotalRequired,0)			AS TotalRequired
			,ISNULL(s.TotalCompleted,0)			AS TotalCompleted
			,ISNULL(s.PercComplete,0)			AS PercComplete
			,ISNULL(s.TotalNoTGTOrWarning,0)	AS TotalNoTGTorWarn
			,ISNULL(s.TotalOutsideWarn,0)		AS TotalOutsideWarn
			--,ISNULL(s.PercTGTWarnCompliantOld,0)	AS PercTGTWarnCompliantOld
			,ISNULL(s.PercTGTWarnCompliant,0)	AS PercTGTWarnCompliant
			,ISNULL(s.PercTGTWarnComplete,0)	AS PercTGTWarnComplete
			,ISNULL(s.TotalNoTGTorReject,0)		AS TotalNoTGTorReject
			,ISNULL(s.TotalOutRejectLimits,0)	AS TotalOutsideReject     
			--,ISNULL(s.PercTGTRejectCompliantOLd,0)	AS PercTGTRejectCompliantOld
			,ISNULL(s.PercTGTRejectCompliant,0)	AS PercTGTRejectCompliant
			,ISNULL(s.PercTGTRejectComplete,0)	AS PercTGTRejectComplete
			,ISNULL(s.TotalNotDone,0)			AS TotalNotDone
			,ISNULL(s.TotalComments,0)			AS TotalComments
			,ISNULL(s.TotalAlarms,0)			AS TotalAlarms
			,ISNULL(s.PercCommented,0)			AS PercCommented
			,ISNULL(s.TotalWithTgtOnly,0)		AS TotalWithTgtOnly
			,ISNULL(s.TotalTGTOutages,0)		AS TotalTGTOutages
			-- 'New fields in Output to calculate the summary correctly'
			, ISNULL(s.TotalWarning,0)			AS TotalWarning
			, ISNULL(s.TotalOutTGT,0)			AS TotalOutTGT
			, ISNULL(s.TotalCompletedWithWarn,0)AS TotalCompletedWithWarn
			, ISNULL(s.TotalNotDoneWWarnLimits,0)AS TotalNotDoneWWarnLimits
			, ISNULL(s.TotReqWithReject,0)		AS TotReqWithReject
			, ISNULL(s.TotalCompletedWithReject,0)	AS TotalCompletedWithReject
			, ISNULL(s.NotDoneReject,0)			AS NotDoneReject
			--
			,ISNULL(s.TotalCommentsW,0)			AS TotalCommentsW
			,ISNULL(s.PercCommentedW,0)			AS PercCommentedW
		FROM @Summary s
ELSE
BEGIN
	--	Fill @Summary with error message
	INSERT INTO @Summary (
				SheetDesc,
				ProdDesc )
		SELECT	'Error converting data type varchar to float.',           
				'View the Comment in the Raw Data'               

	SELECT	DISTINCT
			 s.SheetDesc              
			,s.ProdDesc               
			,s.TeamDesc               
			,s.ShiftDesc              
			,ISNULL(s.TotalRequired,0)			AS TotalRequired
			,ISNULL(s.TotalCompleted,0)			AS TotalCompleted
			,ISNULL(s.PercComplete,0)			AS PercComplete
			,ISNULL(s.TotalNoTGTOrWarning,0)	AS TotalNoTGTorWarn
			,ISNULL(s.TotalOutsideWarn,0)		AS TotalOutsideWarn
			,ISNULL(s.PercTGTWarnCompliant,0)	AS PercTGTWarnCompliant
			,ISNULL(s.PercTGTWarnComplete,0)	AS PercTGTWarnComplete
			,ISNULL(s.TotalNoTGTorReject,0)		AS TotalNoTGTorReject
			,ISNULL(s.TotalOutRejectLimits,0)	AS TotalOutsideReject     
			,ISNULL(s.PercTGTRejectCompliant,0)	AS PercTGTRejectCompliant
			,ISNULL(s.PercTGTRejectComplete,0)	AS PercTGTRejectComplete
			,ISNULL(s.TotalNotDone,0)			AS TotalNotDone
			,ISNULL(s.TotalComments,0)			AS TotalComments
			,ISNULL(s.TotalAlarms,0)			AS TotalAlarms
			,ISNULL(s.PercCommented,0)			AS PercCommented
			,ISNULL(s.TotalWithTgtOnly,0)		AS TotalWithTgtOnly
			,ISNULL(s.TotalTGTOutages,0)		AS TotalTGTOutages
			-- New fields in Output to calculate the summary correctly
			, ISNULL(s.TotalWarning,0)			AS TotalWarning
			, ISNULL(s.TotalOutTGT,0)			AS TotalOutTGT
			, ISNULL(s.TotalCompletedWithWarn,0)AS TotalCompletedWithWarn
			, ISNULL(s.TotalNotDoneWWarnLimits,0)AS TotalNotDoneWWarnLimits
			, ISNULL(s.TotReqWithReject,0)		AS TotReqWithReject
			, ISNULL(s.TotalCompletedWithReject,0)	AS TotalCompletedWithReject
			, ISNULL(s.NotDoneReject,0)			AS NotDoneReject
			--
			,ISNULL(s.TotalCommentsW,0)			AS TotalCommentsW
			,ISNULL(s.PercCommentedW,0)			AS PercCommentedW
		FROM @Summary s

END

-- --------------------------------------------------------------------------------------------------------------------
-- TGT Alarm OR Warning Limits
-- -------------------------------------------------------------------------------------------------------------------- 
SELECT	DISTINCT
		 ResultOn		AS TimeOut																			
		,SheetDesc		AS ProficyDisplay																		
		,TeamDesc		AS Team 																				
		,ShiftDesc		AS Shift																				
		,ProdDesc		AS ProductDesc																		
		,VarDesc		AS Variable																			
		,Result		 	
		,LowerWarning	AS 'L_Warning'
		,Target		
		,UpperWarning	AS 'U_Warning'	
		,Comment		AS Comment																																								 
		,TypeOfViolation
		,CheckForTargetAlarm
	FROM #VariableTask
	WHERE (OutWarning = 1 OR OutTGT = 1)
		--AND LineStopped = 0
		AND isValid = 1
	ORDER BY ProductDesc, TimeOut 	

-- --------------------------------------------------------------------------------------------------------------------
-- TGT Alarm OR Reject Limits
-- -------------------------------------------------------------------------------------------------------------------- 	
SELECT	DISTINCT
		 ResultOn		AS TimeOut																			
		,SheetDesc		AS ProficyDisplay																		
		,TeamDesc		AS Team 																				
		,ShiftDesc		AS Shift																				
		,ProdDesc		AS ProductDesc																		
		,VarDesc		AS Variable																			
		 ,Result		 	
		 ,LowerReject	AS 'L_Reject'		
		 ,Target		
		 ,UpperReject	AS 'U_Reject'		
		,Comment		AS Comment																																								 
		 ,TypeOfViolation
		 ,CheckForTargetAlarm
	FROM #VariableTask
	WHERE (OutReject = 1 OR OutTGT = 1)
		AND DataType = 'VARIABLE'
		AND isValid = 1
		--AND LineStopped = 0
	ORDER BY ProductDesc, ProficyDisplay, TimeOut, Team

-- --------------------------------------------------------------------------------------------------------------------
-- Attributes Out
-- -------------------------------------------------------------------------------------------------------------------- 	
SELECT	DISTINCT
		 ResultOn		AS TimeOut																			
		,SheetDesc		AS ProficyDisplay																		
		,TeamDesc		AS Team 																				
		,ShiftDesc		AS Shift																				
		,ProdDesc		AS ProductDesc																		
		,VarDesc		AS Variable																			
		,Result																				
		,LowerReject	AS 'L_Reject'																			
		,Target																				
		,UpperReject	AS 'U_Reject'																					
		,Comment		AS Comment																																								 
	FROM #VariableTask																			 
	WHERE OutReject = 1 
		AND DataType = 'ATTRIBUTE'
		AND isValid = 1
		--AND LineStopped = 0
	ORDER BY ProductDesc, ProficyDisplay, TimeOut, Team

-- --------------------------------------------------------------------------------------------------------------------
-- No TGT OR Warning Limits
-- -------------------------------------------------------------------------------------------------------------------- 	
SELECT	DISTINCT
		SheetDesc		AS ProficyDisplay																		
		,ProdDesc		AS ProductDesc																		
		,VarDesc		AS Variable																			
	FROM #VariableTask 																				
	WHERE NoTGTOrWarning = 1
		AND isValid = 1
		--AND LineStopped = 0
	ORDER BY ProficyDisplay,ProductDesc, Variable

-- --------------------------------------------------------------------------------------------------------------------
-- No TGT OR Reject Limits
-- -------------------------------------------------------------------------------------------------------------------- 	
SELECT	DISTINCT 
		--'here', VARID, 
		SheetDesc		AS ProficyDisplay																		
		,ProdDesc		AS ProductDesc																		
		,VarDesc		AS Variable																			
	FROM #VariableTask 																					 
	WHERE NoTGTOrReject = 1
		AND isValid = 1
		--AND LineStopped = 0
	ORDER BY ProficyDisplay,ProductDesc, Variable

-- --------------------------------------------------------------------------------------------------------------------
-- Raw Data
-- -------------------------------------------------------------------------------------------------------------------- 	
IF (@hasError = 0)

	SELECT 	 DISTINCT
			 ResultOn		AS 'TestTimestamp'
			,SheetDesc		AS 'ProficyDisplay'
			,TeamDesc		AS 'Team'
			,ShiftDesc		AS 'Shift'
			,ProdDesc		AS 'ProductDesc'
			,VarId			AS 'VarId'
			,VarDesc		AS 'Variable'
			,DataType		AS 'DataType'
			,Frequency		AS 'SampleFrequency'
			,Result			AS 'Result'
			,LowerControl	AS 'L_Entry'
			,LowerReject	AS 'L_Reject'
			,LowerWarning	AS 'L_Warning'
			,LowerUser		AS 'L_User'
			,Target			AS 'Target'
			,UpperControl	AS 'U_User'
			,UpperWarning	AS 'U_Warning'
			,UpperReject	AS 'U_Reject'
			,UpperUser		AS 'U_Entry'
			,Comment		AS 'Comment'																													 
		FROM #VariableTask 																					 
		WHERE isValid = 1
			-- Comment by Alarms in Pmkg (Ex: MP8M CL Manual MA Log)
			--and Comment is not null 
		ORDER BY ResultOn, SheetDesc, TeamDesc, ShiftDesc, ProdDesc, VarDesc
ELSE
	SELECT 	 DISTINCT
			 ResultOn		AS 'TestTimestamp'
			,SheetDesc		AS 'ProficyDisplay'
			,TeamDesc		AS 'Team'
			,ShiftDesc		AS 'Shift'
			,ProdDesc		AS 'ProductDesc'
			,VarId			AS 'VarId'
			,VarDesc		AS 'Variable'
			,DataType		AS 'DataType'
			,Frequency		AS 'SampleFrequency'
			,Result			AS 'Result'
			,LowerControl	AS 'L_Entry'
			,LowerReject	AS 'L_Reject'
			,LowerWarning	AS 'L_Warning'
			,LowerUser		AS 'L_User'
			,Target			AS 'Target'
			,UpperControl	AS 'U_User'
			,UpperWarning	AS 'U_Warning'
			,UpperReject	AS 'U_Reject'
			,UpperUser		AS 'U_Entry'
			,TypeErr		AS 'Comment'																													 
		FROM #VariableError																					 
		ORDER BY ResultOn, SheetDesc, TeamDesc, ShiftDesc, ProdDesc, VarDesc

-- --------------------------------------------------------------------------------------------------------------------
--	Lines, dates, displays, etc.
-- --------------------------------------------------------------------------------------------------------------------
SELECT 	DISTINCT 
		DeptId,					
		DeptDesc,						
		DeptType,				
		e.PLId,					
		PLDesc,							
		a.puid,
		a.PUDESC, 
		di.DisplayId, 
		di.Display,
		StartTime,				
		EndTime
	FROM #Equipment					e	WITH (NOLOCK)
	JOIN @AuditPUID					a	ON e.plid = a.PLID
	JOIN GBDB.dbo.Variables_base	v	WITH (NOLOCK) ON a.PUID = v.PU_ID
	JOIN #DisplayVariables			sv	WITH (NOLOCK) ON sv.VarID = v.Var_ID
	--JOIN GBDB.dbo.Sheet_Variables	sv	WITH (NOLOCK) ON sv.Var_ID = v.Var_ID
	JOIN #Displays					di	WITH (NOLOCK) ON sv.DisplayId = di.DisplayId

-- --------------------------------------------------------------------------------------------------------------------
--	CleanUp
-- --------------------------------------------------------------------------------------------------------------------
DROP TABLE #Equipment
DROP TABLE #OpsDBDowntimeUptimeData
DROP TABLE #Displays
DROP TABLE #DisplayColumns
DROP TABLE #Alarms
DROP TABLE #VariableTask
DROP TABLE #VariableError
GO

GRANT  EXECUTE  ON [dbo].[spRptCenterlineFC]  TO OpDBWriter
GO

