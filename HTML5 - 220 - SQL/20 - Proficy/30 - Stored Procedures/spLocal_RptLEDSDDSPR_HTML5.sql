
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
--=====================================================================================================================
-- Check if the store procedure already exists in the Data Base
--=====================================================================================================================
IF	EXISTS(SELECT * FROM dbo.SYSOBJECTS WHERE Id = OBJECT_ID(N'[dbo].[spLocal_RptLEDSDDSPR_HTML5]')
	AND OBJECTPROPERTY(Id, N'ISPROCEDURE') = 1)
BEGIN
	DROP PROCEDURE [dbo].spLocal_RptLEDSDDSPR_HTML5
END
GO



----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptLEDSDDSPR_HTML5',
		@Inputs		= 5, -- Put the number of inputs here for support purposes
		@Version	= '1.1'  -- Number should match version manager, no exceptions.

SELECT @AppId = MAX(App_Id) + 1 
		FROM AppVersions

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
IF (SELECT COUNT(*) 
		FROM AppVersions 
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE AppVersions 
		SET app_version = @Version 
		WHERE app_name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO AppVersions (
		App_Id,
		App_name,
		App_version)
	VALUES (
		@AppId, 
		@SP_Name,
		@Version)
		
END		




GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO
--=====================================================================================================================      
-- Store Procedure:  spLocal_RptLEDSDDSPR_HTML5   HTML 5 Version
-----------------------------------------------------------------------------------------------------------------------      
-- DESCRIPTION:      
-- This stored procedure has been designed to support the spLocal_RptLEDSDDSPR_HTML5.aspx report      
-- The LEDS Daily Direction Setting Report (DDS) analyses downtime and production data      
-- and groups it into different sections. Each section has its own result set.      
-- Section 1: Report Period Production Summary      
-- Section 2: Line Downtime Summary Measures      
-- Section 3: Unplanned Downtime Summary by DTGroup Category      
-- Section 4: Planned Downtime Summary by DTGroup Category      
-- Section 5: Top X Downtime Summary by Occurrance      
-- Section 6: Top X Downtime Summary by Duration      
-- Section 7: Downtime Top X Longest Events      
-----------------------------------------------------------------------------------------------------------------------      
-- Filters:       
-- Start and End Time      
-- Production Lines      
-- Reason Level      
-- Include Plannes Stops      
-- Include Blocked & Starved      
-----------------------------------------------------------------------------------------------------------------------      
-- Nested sp:       
-- spCmn_ReportCollectionParsing      
-- spCmn_GetRelativeDate      
-- spRS_GetReportDefParam      
-----------------------------------------------------------------------------------------------------------------------      
-- Functions:      
-- fnLocal_LEDS_ProductionRawData      
-- fnLocal_LEDS_DowntimeRawData      
-----------------------------------------------------------------------------------------------------------------------      
-- SP sections:      
-- 1.0 PREPARE SP      
-- 2.0 REPORT FILTERS      
-- 3.0 MAJOR GROUPING      
--  4.0 REPORT HEADER INFO COMMON      
-- 5.0 HEADER INFO VARIABLE      
-- 6.0 REPORT SECTIONS      
--  7.0 REPORT PERIOD PRODUCTION SUMMARY      
-- 8.0 LINE DOWNTIME SUMMARY MEASURES      
--  9.0 UNPLANNED DOWNTIME SUMMAREY BY DTGROUP CATEGORY      
--  10.0 PLANNED DOWNTIME SUMMARY BY DTGROUP CATEGORY      
--  11.0 TOP X DOWNTIME SUMMARY BY OCCURRENCE      
--  12.0 TOP X DOWNTIME SUMMARY BY DURATION      
--  13.0 DOWNTIME TOP X LONGEST EVENTS      
-- 14.0 CALCULATION RESULT SET      
-- 15.0 RETURN RESULT SETS      
--    ResultSet1 >>> Miscellaneous information      
--    ResultSet2 >>> Major Group List      
--    ResultSet3 >>> HdrInfoCommon      
--    ResultSet4 >>> HdrInfoVariable      
--    ResultSet5 >>> SectionList      
--    ResultSet6 >>> SectionColumnList      
--    ResultSet7 >>> Section1: Report Period Production Summary      
--    ResultSet8 >>> Section2: Line Downtime Summary Measures      
--    ResultSet9 >>> Section3: Unplanned Downtime Summary by DTGroup Category      
--    ResultSet10 >>> Section4: Planned Downtime Summary by DTGroup Category      
--    ResultSet11 >>> Section5: Top X Downtime Summary By Occurrence      
--    ResultSet12 >>> Section6: Top X Downtime Summary by Duration      
--    ResultSet13 >>> Section7: Downtime Top X Longest Events      
--    ResultSet14 >>> LEDS Details      
--    ResultSet15 >>> Production Details      
--   ResultSet16 >>> Formulas      
-----------------------------------------------------------------------------------------------------------------------      
 
-----------------------------------------------------------------------------------------------------------------------      
-- EDIT HISTORY:      
-----------------------------------------------------------------------------------------------------------------------      
-- Revision		Date		Who					What      
-- ========		====		===					====      
-- 1.0			2018-12-28	Martin Casalis		Initial Development
-- 1.1			2019-08-28	Damian Campana		Capability to filter with the time option 'Last Week'      

-------------------------------------------------------------------------------------------------------------------------      
-- SAMPLE EXEC STATEMENT      
/*-----------------------------------------------------------------------------------------------------------------------      
 EXEC dbo.spLocal_RptLEDSDDSPR_HTML5      
 @p_intRptId = 1849      
*/-----------------------------------------------------------------------------------------------------------------------      
CREATE PROCEDURE [dbo].[spLocal_RptLEDSDDSPR_HTML5]
--DECLARE  
	@inTimeOption				INT				= NULL			, 
    @RPTStartDate				DATETIME		= NULL			,   
    @RPTEndDate					DATETIME		= NULL			,
	@vchRptProductionLine		VARCHAR(MAX)	= NULL			,  
    @vchRptProductionUnit		VARCHAR(MAX)	= NULL			,  
	@vchRptMajorGrouping		VARCHAR(MAX)	= NULL			,  
    @intRptWithDataValidation	INT				= NULL			,  
    @vchRptLineStatus			VARCHAR(MAX)	= NULL			,
	@intRptFilterPlanned		INT				= NULL			,
	@intRptFilterBlocked	 	INT				= NULL			,
	@intRptShowShift 			INT				= NULL			,
	@intRptTopx 				INT				= NULL			,
	@intRptReasonTreeLevel 		INT				= NULL			 
		
--WITH ENCRYPTION   
AS      
     
--SELECT
--@inTimeOption				= 1,
--@RPTStartDate				= NULL,
--@RPTEndDate					= NULL,
--@vchRptProductionLine		= '21|22',
--@vchRptMajorGrouping		= 'ProdGroup',
--@vchRptProductionUnit		= NULL,
--@intRptWithDataValidation	= 1,
--@vchRptLineStatus			= NULL

--=====================================================================================================================      
SET NOCOUNT ON      
--=====================================================================================================================      
DECLARE @dtmTempDate  DATETIME,      
 @intSecNumber  INT,      
 @intSubSecNumber INT,      
 @intPRINTFlag  INT    ,
   @ReportName NVARCHAR(50),
   @vchTimeOption NVARCHAR(50)
-----------------------------------------------------------------------------------------------------------------------      
-- INITIALIZE Values      
-----------------------------------------------------------------------------------------------------------------------      
SET  @dtmTempDate  = GETDATE()      
SET  @intPRINTFlag  = 1    -- Options: 1 = YES; 0 = NO      
SET  @intSecNumber = 1      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'SP START ' + CONVERT(VARCHAR(50), GETDATE(), 121)      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0 IF @intPRINTFlag = 1 PRINT 'START SECTION: ' + CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PREPARE SP'      
--=====================================================================================================================      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' DECLARE Variables and Temp Tables'      
--=====================================================================================================================      
-- DECLARE Report Variables      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE --@vchRptProductionLine  VARCHAR(500),      
   @dtmRptStartTime   DATETIME,      
   @dtmRptEndTime    DATETIME,    
   --@vchRptProductionUnit  VARCHAR(500),      
  --@intRptWithDataValidation INT,      
  @intRptSplitRecords   INT,  
  --@vchRptMajorGrouping  VARCHAR(50),      
  --@vchRptLineStatus   VARCHAR(50),
  @SumUpTime  BIT       --(FO-03039)
-----------------------------------------------------------------------------------------------------------------------      
-- DECLARE Other Variables      
-----------------------------------------------------------------------------------------------------------------------      
-- INTEGERS      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @intErrorCode       INT,      
    @intRptTimeInSec      INT,      
     @i          INT,      
     @j          INT,      
    @k          INT,      
  @l          INT,      
  @r          INT,      
  @intMaxCount       INT,      
    @intMaxRcdIdx       INT,      
    @intMaxRcdIdx2       INT,      
  @intMaxRcdId       INT,      
  @intMaxShiftId       INT,      
     @intUserId         INT,      
     @intLanguageId        INT,      
   @intFROMFlag       INT,      
    @intHdrLabelColIdx      INT,      
    @intHdrLabelRowIdx      INT,      
     @intHdrLabelSpan      INT,      
    @intHdrValueSpan      INT,      
    @intHdrValueColIdx      INT,      
     @intHdrValueRowIdx      INT,      
   @intTableId        INT,      
   @intFieldId        INT,      
    @intMaxMajorGroupId      INT,      
     @intHdrMajorGroupID      INT,      
  @intMaxSectionId      INT,      
   @intPromptId       INT,      
   @intWordCount       INT,      
  @intMaxLength       INT,      
   @intColWidth       INT,      
   @intSectionId       INT,      
   @intColIdx        INT,      
@intColSpan        INT,      
   @intRowIdx        INT,      
  @intEngColIdx       INT,      
  @intPLId        INT,      
   @intPUId        INT,      
  @intPlannedTrackingLevel    INT,      
  @intConstraintOrder      INT,      
  @intConstraintUnitPUId     INT,      
  @intLastMachine       INT,      
  @intParallelUnit      INT,      
  @intMAXPLIdx       INT,      
  @intMINPLIdx       INT,      
  @intMINRcdIdx       INT,      
  @intMINConstraintOrder     INT,      
  @intMAXConstraintOrder     INT,      
  @intLEDSId        INT,      
  @intCommentId       INT,    @intUptimeInSec       INT,      
  @intInternalPlusSupplyStops    INT,      
  @intInternalPlusSupplyDowntime   INT, --1.50      
  @intBlockedStops      INT,      
  @intRcdIdx        INT,      
  @intScheduleTimeInSec     INT,      
  @intIncludeShiftProduction    INT,      
  @intIncludeShiftDowntime    INT,      
  @intIncludeProductionDay    INT,      
  @intIncludeProduct      INT,      
  @intLinesCount       INT,      
  @intRowLabelPrompt      INT,      
  @intPromptUnitLabel      INT,      
  @intMaxLenghtPerRow      INT,      
  @intWordCountFormulas     INT,      
  @intAppId        INT,      
  @intMaxProductionLineStatusRcIdx  INT,      
  @intMaxShiftRcdIdx      INT      
-----------------------------------------------------------------------------------------------------------------------      
-- VARCHARS      
-----------------------------------------------------------------------------------------------------------------------      
 DECLARE @vchErrorMsg      VARCHAR(100),      
     @vchConstraintMessage    VARCHAR(50),      
   @vchCatPrefixDTSched    VARCHAR(25),      
   @vchCatPrefixDTGroup    VARCHAR(25),      
   @vchCatPrefixDTType     VARCHAR(25),      
   @vchCatPrefixDTMach     VARCHAR(25),      
   @vchCatLEDSUnplanned    VARCHAR(25),      
   @vchCatLEDSPlanned     VARCHAR(25),      
   @vchCatLEDSSTNU      VARCHAR(25),      
   @vchCatDTGroupPlannedMaint    VARCHAR(25),      
   @vchCatDTGroupPlannedCO    VARCHAR(25),      
   @vchCatDTGroupPlannedCOSanitization VARCHAR(25),      
   @vchCatDTGroupPlannedClean    VARCHAR(25),      
    @vchVersion       VARCHAR(25),      
   @vchCatDTMachBlocked     VARCHAR(25),      
   @vchCatDTMachStarved     VARCHAR(25),      
   @vchCatDTMachSupply     VARCHAR(25),      
   @vchCatDTMachInternal     VARCHAR(25),      
   @vchCatDTClassBreakdown    VARCHAR(25),      
    @vchPlannedTrackingLevelFieldName VARCHAR(50),      
      @vchParameterValue     VARCHAR(500),      
   @vchAppName       VARCHAR(50),           
      @vchParameterName     VARCHAR(50),      
    @vchConstraintOrderFieldName  VARCHAR(50),      
    @vchLastMachineFieldName   VARCHAR(50),      
    @vchParallelUnitFieldName   VARCHAR(50),      
      @vchSiteName      VARCHAR(50),      
      @vchServerName      VARCHAR(50),      
     @vchPrompt       VARCHAR(50),      
     @vchPrompt2       VARCHAR(50),      
      @vchHdrLabel      VARCHAR(50),      
      @vchHdrLabelValue     VARCHAR(50),      
      @vchHdrKeyId      VARCHAR(50),      
      @vchHdrValue      VARCHAR(1000),      
    @vchTableFieldDesc     VARCHAR(50),      
      @vchPLDesc       VARCHAR(50),      
    @vchColLabel      VARCHAR(500),      
    @vchEngLabel      VARCHAR(25),      
    @vchHdrEngKeyId     VARCHAR(25),      
    @vchKeyId       VARCHAR(25),      
   @vchStartTime      VARCHAR(25),      
   @vchEndTime       VARCHAR(25),      
   @vchUDPDescREProductionUnit   VARCHAR(25),      
   @vchUDPDescREProdUnitOrder   VARCHAR(25),      
   @vchShift       VARCHAR(10),      
   @vchCommentText      VARCHAR(5000),      
   @vchTempString      VARCHAR(500),      
   @vchColumnLine      VARCHAR(4000),      
   @vchColumnConstraint1    VARCHAR(4000),      
   @vchColumnConstraintx    VARCHAR(4000),      
   @vchRowLabelDesc     VARCHAR(1000),      
   @vchUnitLabelDesc     VARCHAR(1000),      
   @vchFormulaMachine     VARCHAR(500)      
-----------------------------------------------------------------------------------------------------------------------      
-- nVARCHARS      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @nvchSQLCommand  nVARCHAR(4000),      
  @nvchSQLCommand1 nVARCHAR(2000),      
  @nvchSQLCommand2 nVARCHAR(2000),      
  @nvchSQLCommand3 nVARCHAR(2000)      
-----------------------------------------------------------------------------------------------------------------------      
-- DATETIME      
-----------------------------------------------------------------------------------------------------------------------      
-----------------------------------------------------------------------------------------------------------------------      
-- FLOAT      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @fltEquipmentReliability FLOAT,      
  @fltNetProductionStatUnits FLOAT,      
  @fltMachinePR   FLOAT      
-----------------------------------------------------------------------------------------------------------------------      
-- CONSTANTS      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @constCountSections     INT,      
  @constRptStyleOverallTotal   VARCHAR(25),      
  @constRptStyleTotal     VARCHAR(25),      
  @constRptStyleSubTotal    VARCHAR(25),      
  @constRptStyleDetails    VARCHAR(25),      
  @constProdStatusNormalProd   VARCHAR(25),      
  @constProdStatusEO      VARCHAR(25),      
  @constProdStatusQualification  VARCHAR(25)      
-----------------------------------------------------------------------------------------------------------------------      
-- TABLE Variables      
-----------------------------------------------------------------------------------------------------------------------      
-- Variable table used to store prompts VALUES      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblPrompts TABLE (      
  RcdIdx    INT IDENTITY(0,1),      
  PromptId   BIGINT,      
  PromptValue   VARCHAR(100))      
-----------------------------------------------------------------------------------------------------------------------      
-- TABLE used for storing report parameters      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblReportParameters  TABLE(      
  RcdIdx INT Identity (1,1),      
  RPName VARCHAR(500),      
  Value VARCHAR(500) )      
-----------------------------------------------------------------------------------------------------------------------      
-- Table holds units of productions that are associated with the downtime production units      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblVirtualProductionUnits TABLE (      
  PLId INT,      
  PUId INT,      
  PUOrder INT)      
-----------------------------------------------------------------------------------------------------------------------      
-- Table intermediate table used to calculate the "LINE DOWNTIME SUMMARY MEASURES" section      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblLineDowntimeMeasures TABLE (      
  MajorGroupId  INT,      
  PLId    INT,      
  PUId    INT,      
  ConstraintOrder  INT DEFAULT 0,      
  MTBFInSec   FLOAT,      
  MTTRInSec   FLOAT,      
  UpTimeInSec   FLOAT,      
  PlannedStops  INT,      
  PlannedDTInSec  FLOAT,      
  UnPlannedStops  INT,      
  UnPlannedDTInSec FLOAT,      
  SupplyStops   INT,      
  SupplyDTInSec  FLOAT,      
  InternalStops  INT,      
  InternalDTInSec  FLOAT,      
  MTBFDenominator  INT, -- Supply + Internal Stops      
  BlockedStops  INT,      
  MinorStops   INT,      
  ProcessFailures  INT,      
  BreakDowns   INT,      
  LastMachine   INT)      
-----------------------------------------------------------------------------------------------------------------------      
-- Table holds the list of shift for a constraint unit      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblShiftList TABLE (      
  RcdIdx  INT IDENTITY (1,1),      
  Shift  VARCHAR(10))       
-----------------------------------------------------------------------------------------------------------------------      
-- Table holds the list of comment ids if the comment is chained      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblChainedCommentList TABLE (      
  RcdIdx  INT IDENTITY (1,1),      
  LEDSId  INT,      
  CommentId VARCHAR(10))       
-----------------------------------------------------------------------------------------------------------------------      
-- Table holds the list of comment ids if the comment is chained      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblChainedCommentText TABLE (      
  RcdIdx  INT IDENTITY (1,1),      
  CommentId VARCHAR(10),      
  CommentText VARCHAR(5000))       
-----------------------------------------------------------------------------------------------------------------------      
-- Table holds the intermediate values for the KPI calculations      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblProductionAggregates TABLE(      
  MajorGroupId     INT,      
  MinorGroupId     INT,      
  PLId      INT,      
  ProductionCountPUId    INT,      
  ConstraintOrder     INT DEFAULT 0,      
  NormalProdStatUnits    INT,      
  NormalProdScheduleTimeInSec   INT,      
  NormalProdAdjustedUnitsPerTargetRate  FLOAT,      
  DowntimePlannedInSec    FLOAT,      
  DowntimeSTNUInSec    FLOAT,      
  MachinePR     FLOAT,      
  ProductionPURE     FLOAT)      
-----------------------------------------------------------------------------------------------------------------------      
-- Table holds intermediate aggreates       
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblTempAggregates TABLE (      
  MajorGroupId INT,      
  MinorGroupId INT,      
  PUId  INT,      
  VALUE  FLOAT)      
-----------------------------------------------------------------------------------------------------------------------      
-- TempTable used to calculate intermediate value for LineDowntimeMeasures. Need to use this table because updates      
-- don't support aggretates      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblTempValues1 TABLE(      
  RcdIdx   INT IDENTITY (1,1),      
  MajorGroupId  INT,      
  PLId   INT,      
  PUId   INT,      
  ValueL1VARCHAR100 VARCHAR(100),      
  ValueL2VARCHAR100 VARCHAR(100),      
  ValueL3VARCHAR100 VARCHAR(100),      
  ValueL4VARCHAR100 VARCHAR(100),      
  ValueINT  INT,      
  ValueFLOAT  FLOAT)      
-----------------------------------------------------------------------------------------------------------------------      
-- TEMP TABLE used to get the minor stops and process failures.       
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblTempStops TABLE (        
  RcdIdx    INT IDENTITY (1, 1),      
  MajorGroupId   INT,      
  PLId    INT,      
  PUId    INT,      
  ConstraintOrder   INT,      
  LEDSCount   INT,       
  LEDSDurationInSecForRpt  FLOAT,      
  CATDTClass   VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- TempTable used to Get the top X records      
-- Note: using a Temp table for this table because we can use TRUNCATE TABLE to reset the identity      
-----------------------------------------------------------------------------------------------------------------------      
IF OBJECT_ID('tempdb.dbo.#TempValues2', 'U') IS NOT NULL  DROP TABLE #TempValues2
CREATE    TABLE #TempValues2 (      
    RcdIdx   INT IDENTITY (1,1),      
    MajorGroupId  INT,      
    PLId   INT,      
    PUId   INT,      
    ValueL1VARCHAR100 VARCHAR(100),      
    ValueL2VARCHAR100 VARCHAR(100),      
    ValueL3VARCHAR100 VARCHAR(100),      
    ValueL4VARCHAR100 VARCHAR(100),      
    ValueStartTime  VARCHAR(25),      
    ValueFault  VARCHAR(100),      
    ValueINT  INT,      
    ValueFLOAT  FLOAT,      
    ValueComment  VARCHAR(5000))      
-----------------------------------------------------------------------------------------------------------------------      
-- TEMP TABLES      
-----------------------------------------------------------------------------------------------------------------------      
-- TEMP TABLE used for fetching parameters. Only use as a intermediate      
-----------------------------------------------------------------------------------------------------------------------      
IF OBJECT_ID('tempdb.dbo.#tempTableReportParameters', 'U') IS NOT NULL  DROP TABLE #tempTableReportParameters
CREATE  TABLE #tempTableReportParameters  (      
    RDP_Id    INT ,      
    RPName    VARCHAR(500),      
    spName    VARCHAR(500),      
    MultiSelect   VARCHAR(500),      
    Group_Name   VARCHAR(500),      
    RPT_Name   VARCHAR(500),      
    Value    VARCHAR(500),      
    Is_Default   VARCHAR(500))       
-----------------------------------------------------------------------------------------------------------------------      
-- TEMP TABLE used for parsing labels      
-----------------------------------------------------------------------------------------------------------------------      
IF OBJECT_ID('tempdb.dbo.#TempParsingTable', 'U') IS NOT NULL  DROP TABLE #TempParsingTable
CREATE TABLE #TempParsingTable (      
    RcdId  INT,      
    ValueINT INT,      
    ValueVARCHAR100 VARCHAR(100))      
-----------------------------------------------------------------------------------------------------------------------      
-- Variable table for storing Fiter (Production Lines)      
-----------------------------------------------------------------------------------------------------------------------   
IF OBJECT_ID('tempdb.dbo.#FilterProductionLines', 'U') IS NOT NULL  DROP TABLE #FilterProductionLines   
CREATE TABLE #FilterProductionLines (      
    RcdIdx  INT IDENTITY(1,1),      
    PLId  INT,      
    PLDesc  VARCHAR(100) ,     
    PUId    INT,      
    PUDesc    VARCHAR(50) )      
-----------------------------------------------------------------------------------------------------------------------      
-- Variable table for storing Fiter (Production Lines Status)      
-----------------------------------------------------------------------------------------------------------------------  
IF OBJECT_ID('tempdb.dbo.#FilterProductionLineStatus', 'U') IS NOT NULL  DROP TABLE #FilterProductionLineStatus    
CREATE TABLE #FilterProductionLineStatus (      
    RcdIdx  INT ,      
    PLStatusId INT,      
    PLStatusDesc VARCHAR(100))      
-----------------------------------------------------------------------------------------------------------------------      
-- Variable table for storing Fiter (Production Units)      
-----------------------------------------------------------------------------------------------------------------------     
IF OBJECT_ID('tempdb.dbo.#FilterProductionUnits', 'U') IS NOT NULL  DROP TABLE #FilterProductionUnits 
CREATE TABLE #FilterProductionUnits (      
    RcdIdx    INT IDENTITY(1,1),      
    PLId    INT,      
    PUId    INT,      
    PUDesc    VARCHAR(50),      
    PlannedTrackingLevel  INT,      
    ConstraintOrder   INT DEFAULT 0,      
    LastMachine   INT,      
    ParallelUnit   INT,      
    VirtualProductionCountPUId INT,      
    NormalProductionStatUnits FLOAT)      
-----------------------------------------------------------------------------------------------------------------------      
-- Variable table for storing Fiter (Production Units)      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblFilterProductionUnitsTemp TABLE (      
  RcdIdx    INT IDENTITY(1,1),      
  PLId    INT,      
  PUId    INT,      
  PUDesc    VARCHAR(50),      
  PlannedTrackingLevel  INT,      
  ConstraintOrder   INT DEFAULT 0,      
  LastMachine   INT,      
  ParallelUnit   INT,      
  VirtualProductionCountPUId INT,      
  NormalProductionStatUnits FLOAT)      
-----------------------------------------------------------------------------------------------------------------------      
-- Result sets      
-----------------------------------------------------------------------------------------------------------------------      
-- RS1: Misc Info      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblMiscInfo TABLE (      
  ErrorCode  INT,      
  ErrorMsg  VARCHAR(100),      
  WithDataValidation INT, -- Options: 1 = YES; 0 = NO      
  ConstraintMessage VARCHAR(100))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS2: Major Group List      
-----------------------------------------------------------------------------------------------------------------------  
IF OBJECT_ID('tempdb.dbo.#MajorGroupList', 'U') IS NOT NULL  DROP TABLE #MajorGroupList    
CREATE TABLE  #MajorGroupList (      
    MajorGroupId INT IDENTITY(1,1),      
    MajorGroupDesc VARCHAR(100),      
    PLId  INT,      
    PLDesc  VARCHAR(100),     
  PUId    INT,      
  PUDesc    VARCHAR(50),
  ProdGroupDesc VARCHAR(100))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS3: Header Info Common      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblHdrInfoCommon TABLE (      
  RcdIdx   INT IDENTITY(1,1),      
  KeyId   VARCHAR(50),      
  HdrLabelColIdx INT,      
  HdrLabelRowIdx INT,      
  HdrLabelSpan INT,      
  HdrValueColIdx INT,      
  HdrValueRowIdx INT,      
  HdrValueSpan INT,      
  HdrLabel VARCHAR(200),      
  HdrValue VARCHAR(200))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS4: Header Info Variable      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblHdrInfoVariable TABLE (      
  RcdIdx  INT IDENTITY(1,1),      
  MajorGroupId INT,      
  KeyId  VARCHAR(50),      
  HdrLabelColIdx INT,      
  HdrLabelRowIdx INT,      
  HdrLabelSpan INT,      
  HdrValueColIdx INT,      
  HdrValueRowIdx INT,      
  HdrValueSpan INT,      
  HdrLabel VARCHAR(200),      
  HdrValue VARCHAR(1000))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS5: Section List      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSectionList TABLE (      
  SectionId INT Identity(1,1),      
  SectionLabel VARCHAR(100),      
  PromptNumber BIGINT)      
-----------------------------------------------------------------------------------------------------------------------      
-- RS6: Section Column List      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSectionColumn TABLE (        RcdIdx   INT Identity(1,1),      
  SectionID  INT,      
  ColIdx   INT,      
  KeyId   VARCHAR(25),      
  ColLabel  VARCHAR(50),      
  ColLabelPrompt  BIGINT,      
  EngUnits  VARCHAR(25),      
  ColEngUnitsPrompt BIGINT,      
  ColWidth  INT,      
  WordCount  INT,      
  ColSpan   INT,      
  ColPrecision  INT,      
  ColDataTypeId  INT)      
-----------------------------------------------------------------------------------------------------------------------      
-- RS7: Section1      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection1 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  Col0   VARCHAR(50), -- Shift      
  Col1   VARCHAR(50), -- Team      
  Col2   VARCHAR(25), -- StarTime      
  Col3   VARCHAR(50), -- ProductionStatus      
  Col4   VARCHAR(50), -- ProductCode        
  Col5   VARCHAR(50), -- ProductDesc       
  Col6   DECIMAL(10,2),   -- TargetRate      
  Col7   DECIMAL(10,2),   -- Schedule Time      
  Col8   DECIMAL(14,2),   -- TargetUnits      
  Col9   DECIMAL(14,2),   -- TargetCases      
  Col10   DECIMAL(14,2),   -- TotalUnits      
  Col11   DECIMAL(14,2),   -- TotalCases      
  Col12   DECIMAL(14,2),   -- NetProduction      
  Col13   DECIMAL(10,2),   -- PR      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- TempTable to Insert Shift      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblTempShifts  TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  Col0   VARCHAR(50), -- Shift      
  Col1   VARCHAR(50), -- Team      
  Col2   VARCHAR(25), -- StarTime      
  Col3   VARCHAR(50), -- ProductionStatus      
  Col4   VARCHAR(50), -- ProductCode        
  Col5   VARCHAR(50), -- ProductDesc       
  Col6   DECIMAL(10,2),   -- TargetRate      
  Col7   DECIMAL(10,2),   -- Schedule Time      
  Col8   DECIMAL(14,2),   -- TargetUnits      
  Col9   DECIMAL(14,2),   -- TargetCases      
  Col10   DECIMAL(14,2),   -- TotalUnits      
  Col11   DECIMAL(14,2),   -- TotalCases      
  Col12   DECIMAL(14,2),   -- NetProduction      
  Col13   DECIMAL(10,2),   -- PR      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS8: Section2      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection2 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  ConstraintOrder INT DEFAULT 0,      
  Col0   VARCHAR(50),  -- Unit      
  Col1   BIT,      
  Col2   DECIMAL(10,2),  -- Unplanned MTBF      
  Col3   DECIMAL(10,2),  -- MTTR      
  Col4   DECIMAL(10,2),  -- Uptime      
  Col5   INT,   -- PlannedStops      
  Col6   DECIMAL(10,2),  -- PlannedDT      
  Col7   INT,   -- SupplyStops      
  Col8   DECIMAL(10,2),  -- SupplyDT      
  Col9   INT,   -- InternalStops      
  Col10   DECIMAL(10,2),  -- InternalDT      
  Col11   INT,   -- MinorStops      
  Col12   INT,   -- ProcessFailures      
  Col13   INT,   -- Breakdowns      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS9: Section3      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection3 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  Col0   VARCHAR(50),  -- Category      
  Col1   BIT,      
  Col2   BIT,      
  Col3   BIT,      
  Col4   BIT,      
  Col5   BIT,      
  Col6   BIT,      
  Col7   BIT,      
  Col8   BIT,      
  Col9   BIT,      
  Col10   BIT,         
  Col11   DECIMAL(10,2),  -- Downtime      
  Col12   INT,   -- Stops      
  Col13   VARCHAR(10),  -- CalendarTime      
  Col14       VARCHAR(10),     -- ScheduledTime  TCS (FO-00829)      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS10: Section4      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection4 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  Col0   VARCHAR(50),  -- Category      
  Col1   BIT,      
  Col2   BIT,      
  Col3   BIT,      
  Col4   BIT,      
  Col5   BIT,      
  Col6   BIT,      
  Col7   BIT,      
  Col8   BIT,      
  Col9   BIT,      
  Col10   BIT,      
  Col11   DECIMAL(10,2),  -- Downtime      
  Col12   INT,   -- Stops      
  Col13   VARCHAR(10),  -- CalendarTime      
  Col14       VARCHAR(10),     -- ScheduledTime  TCS (FO-00829)      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS11: Section5      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection5 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  Col0   VARCHAR(100),  -- Level1      
  Col1   BIT,      
  Col2   VARCHAR(100),  -- Level2      
  Col3   BIT,      
  Col4   VARCHAR(100),  -- Level3      
  Col5   BIT,      
  Col6   VARCHAR(100),  -- Level4      
  Col7   BIT,      
  Col8   BIT,      
  Col9   BIT,      
  Col10   BIT,      
  Col11   DECIMAL(10,2),  -- Downtime      
  Col12   INT,   -- Stops      
  Col13   BIT,      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS12: Section6      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection6 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  Col0   VARCHAR(100), -- Level1      
  Col1   BIT,      
  Col2   VARCHAR(100), -- Level2      
  Col3   BIT,      
  Col4   VARCHAR(100), -- Level3      
  Col5   BIT,      
  Col6   VARCHAR(100), -- Level4      
  Col7   BIT,      
  Col8   BIT,      
  Col9   BIT,      
  Col10   BIT,      
  Col11   DECIMAL(10,2),   -- Downtime      
  Col12   INT,   -- Stops      
  Col13   BIT,      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS13: Section7      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblSection7 TABLE (      
  RcdIdx   INT Identity (1,1),      
  MajorGroupId INT,      
  PUId   INT,      
  Col0   VARCHAR(100), -- Level1      
  Col1   BIT,      
  Col2   VARCHAR(100), -- Level2      
  Col3   BIT,      
  Col4   VARCHAR(100), -- Level3      
  Col5   BIT,      
  Col6   VARCHAR(100), -- Level4      
  Col7   BIT,      
  Col8   VARCHAR(25), -- StartTime      
  Col9   VARCHAR(100), -- Fault        
  Col10   BIT,       
  Col11   DECIMAL(10,2),   -- Downtime      
  Col12   VARCHAR(1000), -- Comments   was NText,       
  Col13   BIT,      
  NameStyle  VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS14: Formulas      
-----------------------------------------------------------------------------------------------------------------------      
DECLARE @tblFormulas TABLE (      
 RcdIdx   INT IDENTITY(1,1),      
 PromptNum  INT,      
 Measure   VARCHAR(1000),      
 Line   VARCHAR(1000),      
 Constraint1  VARCHAR(1000),      
 Constraintx  VARCHAR(1000),      
 Machine   VARCHAR(500),      
 IntRowCount  INT)       
-----------------------------------------------------------------------------------------------------------------------      
-- RS15: LEDS details      
-----------------------------------------------------------------------------------------------------------------------    
IF OBJECT_ID('tempdb.dbo.#LEDSDetails', 'U') IS NOT NULL  DROP TABLE #LEDSDetails  
CREATE TABLE #LEDSDetails (      
    RcdIdx      INT IDENTITY(1,1) PRIMARY KEY,      
    MajorGroupId    INT,      
    MinorGroupId    INT,      
    PLId      INT,      
    PUId      INT,      
    ProductionCountPUId    INT,      
    ProdGroupId     INT,      
    ProdId      INT,      
    EventProductionDay   VARCHAR(25),      
    EventProductionDayId  INT,      
    EventProductionStatus  VARCHAR(50),      
    Shift      VARCHAR(50),      
    Team      VARCHAR(50),      
    LEDSId      INT,      
    UPTimeStart     DATETIME,      
    UPTimeEnd     DATETIME,      
    UPTimeDurationInSec   INT,      
    LEDSStart     VARCHAR(25),      
    LEDSEnd      VARCHAR(25),      
    LEDSStartForRpt    VARCHAR(25),      
    LEDSEndForRpt    VARCHAR(25),      
    LEDSDurationInSecForRpt  INT,      
    LEDSDurationInSec   INT,      
    LEDSCount     INT,      
    LEDSParentId    INT,      
    CauseRL1Id     INT,      
    CauseRL2Id     INT,      
    CauseRL3Id     INT,      
    CauseRL4Id     INT,      
    Cause1      VARCHAR(100),      
    Cause2      VARCHAR(100),      
    Cause3      VARCHAR(100),      
    Cause4      VARCHAR(100),      
    TreeNodeId     INT,      
    ActionTreeId    INT,      
    Action1Id     INT,      
    Action2Id     INT,      
    Action3Id     INT,      
    Action4Id     INT,      
    ACtionTreeNodeId   INT,      
    CatId      INT,      
    CatDTSched     VARCHAR(50),      
    CatDTType     VARCHAR(50),      
    CatDTGroup     VARCHAR(50),      
    CatDTMach     VARCHAR(50),      
    CatDTClass     VARCHAR(50),      
    CatDTClassCause    VARCHAR(50),      
    CatDTClassAction   VARCHAR(50),      
  FaultId      INT,      
    FaultDesc     VARCHAR(100),      
    LEDSCommentId    INT,      
    LEDSComment     VARCHAR(5000),      
    EventSplitFactor   FLOAT,      
    EventSplitFlag    INT,      
    EventSplitShiftFlag   INT DEFAULT 0,      
    EventSplitProductionDayFlag INT DEFAULT 0,      
    PlannedTrackingLevel  INT,      
    ConstraintOrder    INT DEFAULT 0,      
    LastMachine     INT,      
    ParallelUnit    INT,      
    ErrorCode     INT,      
    Error      VARCHAR(150))      
-----------------------------------------------------------------------------------------------------------------------      
-- LEDS Details Temp used to calculate TOP X Longest Events      
-----------------------------------------------------------------------------------------------------------------------      
IF OBJECT_ID('tempdb.dbo.#LEDSDetailsTemp', 'U') IS NOT NULL  DROP TABLE #LEDSDetailsTemp
CREATE TABLE #LEDSDetailsTemp (      
    MajorGroupId  INT ,      
    LEDSId    INT ,      
    PLId    INT ,      
    PUId    INT ,      
    Cause1    VARCHAR(100),      
    Cause2    VARCHAR(100),      
    Cause3    VARCHAR(100),      
    Cause4    VARCHAR(100),      
    LEDSStart   VARCHAR(25),      
    FaultDesc   VARCHAR(100),       
    LEDSDurationInSec INT,       
    LEDSComment   VARCHAR(5000),      
    CATDTSched   VARCHAR(50),      
    CATDTMach   VARCHAR(50))      
-----------------------------------------------------------------------------------------------------------------------      
-- RS16: Production Raw Data      
-----------------------------------------------------------------------------------------------------------------------   
IF OBJECT_ID('tempdb.dbo.#ProductionRawData', 'U') IS NOT NULL  DROP TABLE #ProductionRawData   
CREATE TABLE #ProductionRawData (      
    RcdIdx       INT Identity(1,1),      
    MajorGroupId     INT,      
    MinorGroupId     INT,      
    PLId       INT,         
    EventId       INT,      
    EventPUId       INT,      
    EventProductionDayId   INT,      
    ProductionCountPUId     INT,      
    ConstraintOrder     INT DEFAULT 0,      
    EventNumber      VARCHAR(100),      
    EventStart       VARCHAR(25),      
    EventEnd       VARCHAR(25),      
    EventStartForRpt     VARCHAR(25),      
    EventEndForRpt      VARCHAR(25),      
    EventProductionTimeInSec  INT,      
    EventProductionTimeInSecForRpt INT,      
    EventProdId      INT,   -- COALESCE(EventAppliedProdId, EventProdId)      
    EventProdCode     VARCHAR(100),      
    EventProdDesc     VARCHAR(100),      
    EventPSProdId     INT,   -- product from production starts table      
    EventAppliedProdId    INT,   -- applied product from dbo.Events      
    EventProdGroupId    INT,           
    EventShift      VARCHAR(25),      
    EventTeam      VARCHAR(25),      
    EventProductionDay    DATETIME,      
    EventProductionStatusVarId  INT,   -- RptHook=ProductionStatus      
    EventProductionStatus   VARCHAR(50),      
    EventAdjustedCasesVarId   INT,   -- RptHook=AdjustedCases      
    EventAdjustedCases    FLOAT,          
    EventStatCaseConvFactorVarId INT,   -- RptHook=StatCaseConvFactor      
    EventStatCaseConvFactor   FLOAT,      
    EventAdjustedUnitsVarId   INT,   -- RptHook=AdjustedCases      
    EventAdjustedUnits    FLOAT,      
    EventUnitsPerCaseVarId   INT,      
    EventUnitsPerCase    FLOAT,      
    EventTargetRateVarId   INT,   -- RptHook=TargetRate      
    EventTargetRatePerMin   FLOAT,      
    EventActualRateVarId   INT,   -- RptHook=ActualRate      
    EventActualRatePerMin   FLOAT,      
    EventScheduledTimeVarId   INT,      
    EventScheduledTimeInSec   FLOAT,      
    EventIdealRateVarId    INT,      
    EventIdealRatePerMin   FLOAT,      
    EventSplitFactor    FLOAT,      
    EventSplitFlag     INT,      
    EventSplitShiftFlag    INT DEFAULT 0, -- Flags events split at shift boundaries      
    EventSplitProductionDayFlag  INT DEFAULT 0, -- Flags events split at production day boundaries      
    ErrorCode      INT,       
    Error        VARCHAR(150))       
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CREATE table indexes'      
--=====================================================================================================================      
CREATE NONCLUSTERED INDEX LEDSDetailsPUIdLEDSStartLEDSEnd_Idx       
ON #LEDSDetails (LEDSId, PUId, LEDSStart, LEDSEnd)       
-----------------------------------------------------------------------------------------------------------------------      
CREATE NONCLUSTERED INDEX LEDSDetailsMajorMinorCat_Idx       
ON #LEDSDetails (MajorGroupId, MinorGroupId, CatDTSched, CatDTType, CatDTGroup, CatDTMach)       
-----------------------------------------------------------------------------------------------------------------------      
CREATE NONCLUSTERED INDEX ProdRawDataMajorProdStatus_Idx       
ON #ProductionRawData (MajorGroupId, EventProductionStatus)       
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INITIALIZE variables'      
--=====================================================================================================================      
-- VALIDATE report id      
-----------------------------------------------------------------------------------------------------------------------      
--IF NOT EXISTS( SELECT Report_Id       
--    FROM dbo.Report_Definitions WITH (NOLOCK)      
--    WHERE Report_Id  = @p_intRptId )      
--BEGIN      
-- SELECT  @vchErrorMsg = 'Report Id not found in the database',      
--   @intErrorCode = 1      
--  GOTO ErrorFinish      
--END      
-----------------------------------------------------------------------------------------------------------------------      
-- SET Production Unit list to '!NULL' this report does not have a production unit filter but needs to return only      
-- Production lines that have downtime configured      
-----------------------------------------------------------------------------------------------------------------------      
-- This section was removed in the new version 1.47 to add unit filtering      
--SET @vchRptProductionUnit = '!NULL'           
--=====================================================================================================================      
-- INITIALEZE Constants      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @constCountSections = 7,      
  @constProdStatusNormalProd   = 'Normal Production',      
  @constProdStatusEO     = 'E.O.',      
  @constProdStatusQualification = 'Qualification'      
--=====================================================================================================================      
-- INITIALEZE VARIABLES      
-----------------------------------------------------------------------------------------------------------------------      
-- ErrorTraping      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @intErrorCode  = 0,      
  @vchErrorMsg  = ''      
-----------------------------------------------------------------------------------------------------------------------      
-- App Id from dbo.AppVersions table      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @intAppId = 50018      
-----------------------------------------------------------------------------------------------------------------------      
-- Record splitting      
-- Default to 1 (YES)      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @intRptSplitRecords = 1      
-----------------------------------------------------------------------------------------------------------------------      
-- LEDS downtime categories prefixes      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchCatPrefixDTSched    = 'DTSched-',      
  @vchCatPrefixDTGroup    = 'DTGroup-',      
  @vchCatPrefixDTType     = 'DTType-',      
  @vchCatPrefixDTMach     = 'DTMach-',      
  @vchCatLEDSUnplanned    = 'DTSched-Unplanned',      
  @vchCatLEDSPlanned     = 'DTSched-Planned',      
  @vchCatLEDSSTNU      = 'DTSched-STNU',      
  @vchCatDTGroupPlannedMaint    = 'DTGroup-Planned-Maint',      
  @vchCatDTGroupPlannedCO    = 'DTGroup-Planned-C/O',      
  @vchCatDTGroupPlannedCOSanitization = 'DTGroup-Planned-C/O-Sanitization',      
  @vchCatDTGroupPlannedClean    = 'DTGroup-Planned-Clean',      
  @vchCatDTMachBlocked     = 'DTMach-Blocked',      
  @vchCatDTMachStarved     = 'DTMach-Starved',      
  @vchCatDTMachSupply     = 'DTMach-Supply',      
  @vchCatDTMachInternal     = 'DTMach-Internal',      
  @vchCatDTClassBreakdown    = 'DTClass-Breakdown'      
-----------------------------------------------------------------------------------------------------------------------      
-- LEDS downtime production Units UDP's      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchPlannedTrackingLevelFieldName = 'RE-PlannedTrackingLevel',      
  @vchConstraintOrderFieldName  = 'RE-ConstraintOrder',      
  @vchLastMachineFieldName   = 'RE-LastMachine',      
  @vchParallelUnitFieldName   = 'RE-ParallelUnit'      
-----------------------------------------------------------------------------------------------------------------------      
-- LEDS corresponding production pu's UDP's      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchUDPDescREProductionUnit =  'RE-ProductionUnit',      
  @vchUDPDescREProdUnitOrder =  'RE-ProdUnitOrder'      
-----------------------------------------------------------------------------------------------------------------------      
-- Report name styles      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @constRptStyleOverallTotal  = 'RptStyleOverallTotal',      
  @constRptStyleTotal   = 'RptStyleTotal',      
  @constRptStyleSubTotal  = 'RptStyleSubTotal',      
  @constRptStyleDetails  = 'RptStyleDetails'      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Report Definition Parameters'      
--=====================================================================================================================      
-- GET Report Definition Parameters      
-----------------------------------------------------------------------------------------------------------------------      
-- EXECUTE  spRs_GetReportDefParam to get report parameters       
--43168 AppName NULL NULL NULL pString Active Web Server Application      
--43062 AppName NULL NULL NULL pString Excel      
-----------------------------------------------------------------------------------------------------------------------      
--INSERT INTO #TempTableReportParameters        
--EXEC spRs_GetReportDefParam      
--  @Report_Id = @p_intRptID      
-----------------------------------------------------------------------------------------------------------------------      
-- COPY data FROM #TempTableReportParameters to table variable @tblReportParameters      
-----------------------------------------------------------------------------------------------------------------------      
--INSERT INTO @tblReportParameters (      
--   RPName,      
--   Value)      
--SELECT RPName,      
--  Value       
--FROM #TempTableReportParameters      

SET @ReportName = 'LEDSDDS_PR'

Insert Into @tblReportParameters (RPName,Value) SELECT 'TimeOption'							,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'TimeOption'), 0)
Insert Into @tblReportParameters (RPName,Value) SELECT 'intRptSplitRecords'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'intRptSplitRecords'), NULL)
Insert Into @tblReportParameters (RPName,Value) SELECT 'SumParallelConstraintUnitsUpTime'	,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'SumParallelConstraintUnitsUpTime'), NULL)
-----------------------------------------------------------------------------------------------------------------------      
-- DROP #TempTableReportParameters      
-----------------------------------------------------------------------------------------------------------------------      
DROP TABLE  #TempTableReportParameters      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Start Date and End Date'      
--=====================================================================================================================      
-- SET START DATE AND END DATE      
-- Business Rule      
-- a. CHECK Value for TimeOption      
-- b. IF TimeOption = 0      
--  take the VALUES of StartDate and EndDate which are user defined      
-- c. ELSE       
--  CALL spCMN_GETRelativeDate and pass the TimeOption Value      
--  The TimeOption Value is the RRD_Id in dbo.Report_Relative_Dates      
--  The spCMN_GETRelativeDate sp takes the RRD_Id and interprets the SQL code in      
--  the dbo.Report_Relative_Dates table and returns the calculated dates      
-----------------------------------------------------------------------------------------------------------------------      
-- a. CHECK Value for TimeOption      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchParameterValue = Value       
FROM @tblReportParameters       
WHERE RPName = 'TimeOption'      
-----------------------------------------------------------------------------------------------------------------------      
-- b. IF TimeOption = 0      
--  take the VALUES of StartDate and EndDate which are user defined      
-- c. ELSE       
--  CALL spCMN_GETRelativeDate and pass the TimeOption Value      
--  The TimeOption Value is the RRD_Id in dbo.Report_Relative_Dates      
--  The spCMN_GETRelativeDate sp takes the RRD_Id and interprets the SQL code in      
--  the dbo.Report_Relative_Dates table and returns the calculated dates      
-----------------------------------------------------------------------------------------------------------------------      
--IF @vchParameterValue = 0       
--BEGIN 

	SELECT @dtmRptStartTime = @RPTStartDate, @dtmRptEndTime = @RPTEndDate
 
	SELECT @vchTimeOption = CASE @inTimeOption
									WHEN	1	THEN	'Last3Days'	
									WHEN	2	THEN	'Yesterday'
									WHEN	3	THEN	'Last7Days'
									WHEN	4	THEN	'Last30Days'
									WHEN	5	THEN	'MonthToDate'
									WHEN	6	THEN	'LastMonth'
									WHEN	7	THEN	'Last3Months'
									WHEN	8	THEN	'LastShift'
									WHEN	9	THEN	'CurrentShift'
									WHEN	10	THEN	'Shift'
									WHEN	11	THEN	'Today'
									WHEN	12	THEN	'LastWeek'
							END


	IF @vchTimeOption IS NOT NULL
	BEGIN
		SELECT	@dtmRptStartTime = dtmStartTime ,
				@dtmRptEndTime = dtmEndTime
		FROM [dbo].[fnLocal_DDSStartEndTime](@vchTimeOption)

	END

--END      
--ELSE      
--BEGIN      
--	EXEC spcmn_GetRelativeDate      
--	@StartTimeStamp = @dtmRptStartTime OUTPUT,      
--	@EndTimeStamp = @dtmRptEndTime OUTPUT,      
--	@PrmRRDId =  @vchParameterValue      
--END      
-----------------------------------------------------------------------------------------------------------------------      
-- Calendar time for Report      
-----------------------------------------------------------------------------------------------------------------------      
SET @intRptTimeInSec = DATEDIFF(SECOND,@dtmRptStartTime, @dtmRptEndTime)      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Other Report Definition Parameters'      
--=====================================================================================================================      
-- GET OTHER REPORT DEFINITION PARAMETERS      
 -------------------------------------------------------------------------------------------------------------------      
 -- Apply Report Filters
 -------------------------------------------------------------------------------------------------------------------     
 SET @intRptFilterBlocked	= COALESCE(@intRptFilterBlocked,1)	
 SET @intRptFilterPlanned	= COALESCE(@intRptFilterPlanned,1)	
 SET @intRptReasonTreeLevel	= COALESCE(@intRptReasonTreeLevel,4)
 SET @intRptTopx			= COALESCE(@intRptTopx,1)	
 SET @intRptShowShift		= COALESCE(@intRptShowShift,1)
-----------------------------------------------------------------------------------------------------------------------      
-- INITIALIAZE variable       
-----------------------------------------------------------------------------------------------------------------------      
SELECT @i = 1,      
  @intMaxRcdIdx  = MAX(RcdIdx)       
FROM @tblReportParameters      
-----------------------------------------------------------------------------------------------------------------------      
-- LOOP through the report parameters      
-----------------------------------------------------------------------------------------------------------------------      
WHILE (@i <= @intMaxRcdIdx)      
BEGIN      
 SELECT @vchParameterName = RPName ,       
   @vchParameterValue= Value      
 FROM @tblReportParameters      
 WHERE RcdIdx = @i      
 -------------------------------------------------------------------------------------------------------------------      
 -- Major Grouping      
 -- Default Major Group by to PL (Production Line)      
 --  NOTE: the only Major Group by supported by this report is Production Line      
 -------------------------------------------------------------------------------------------------------------------      
 --IF  @vchParameterName = 'Local_PG_strRptMajorGroupBy'       
 --BEGIN      
 -- SET @vchRptMajorGrouping = COALESCE(@vchParameterValue, 'PL')        
 -- SET @vchRptMajorGrouping = 'PL'      
 --END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Filter Blocked and Starved Stops      
 -------------------------------------------------------------------------------------------------------------------      
 --IF  @vchParameterName = 'FilterBlocked'       
 --BEGIN      
 -- SET @intRptFilterBlocked = COALESCE(@vchParameterValue, '1')        
 --END      
 ---------------------------------------------------------------------------------------------------------------------      
 ---- Filter Planned Stops      
 ---------------------------------------------------------------------------------------------------------------------      
 --ELSE IF @vchParameterName = 'FilterPlanned'         
 --BEGIN      
 -- SET @intRptFilterPlanned = COALESCE(@vchParameterValue, '1')      
 --END      
 ---------------------------------------------------------------------------------------------------------------------      
 ---- Reason Tree Levels      
 ---------------------------------------------------------------------------------------------------------------------      
 --ELSE IF @vchParameterName = 'ReasonTreeLevels'       
 --BEGIN       
 -- SET @intRptReasonTreeLevel = COALESCE(@vchParameterValue, '4')      
 -- PRINT CONVERT(VARCHAR(15),@intRptReasonTreeLevel) + ' Reason Tree Level'       
 --END      
 ---------------------------------------------------------------------------------------------------------------------      
 ---- Top X      
 ---------------------------------------------------------------------------------------------------------------------      
 --ELSE IF @vchParameterName = 'TopX'       
 --BEGIN       
 -- SET @intRptTopX = COALESCE(@vchParameterValue, '1')      
 --END      
 ---------------------------------------------------------------------------------------------------------------------      
 ---- Show Shift on report      
 ---------------------------------------------------------------------------------------------------------------------      
 --ELSE IF @vchParameterName = 'ShowShift'       
 --BEGIN       
 -- SET @intRptShowShift = COALESCE(@vchParameterValue, '1')      
 --END      

 -------------------------------------------------------------------------------------------------------------------      
 -- List of production lines      
 -------------------------------------------------------------------------------------------------------------------      
 --ELSE IF @vchParameterName = 'strRptPLIdList'         
 --BEGIN      
 -- ---------------------------------------------------------------------------------------------------------------      
 -- -- GET value      
 -- ---------------------------------------------------------------------------------------------------------------      
 -- SET @vchRptProductionLine = COALESCE(@vchParameterValue, '!NULL')      
 --END      
 ---------------------------------------------------------------------------------------------------------------------      
 ---- This section was added for the new version 1.47 to add unit filtering      
 ---- List of production units         
 ---------------------------------------------------------------------------------------------------------------------      
 --ELSE IF @vchParameterName = 'strRptPUIdList'         
 --BEGIN      
 -- ---------------------------------------------------------------------------------------------------------------      
 -- -- GET value      
 -- ---------------------------------------------------------------------------------------------------------------      
 -- SET @vchRptProductionUnit = COALESCE(@vchParameterValue, '!NULL')      
 --END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Miscellaneous      
 -------------------------------------------------------------------------------------------------------------------      
 --ELSE 
 IF @vchParameterName = 'intRptWithDataValidation'       
 BEGIN       
  SET @intRptWithDataValidation = @vchParameterValue       
 END      
 ELSE IF @vchParameterName = 'intRptSplitRecords'       
  BEGIN       
   SET @intRptSplitRecords = @vchParameterValue       
  END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Production Line Status      
 -------------------------------------------------------------------------------------------------------------------      
 ELSE IF @vchParameterName = 'Local_PG_strLineStatusID1'       
 BEGIN       
  SET @vchRptLineStatus = COALESCE(@vchParameterValue, '!NULL')      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT counter      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @i + 1      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- Default values in case parameters is not found      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @intRptFilterPlanned = COALESCE(@intRptFilterPlanned, 1),      
  @intRptReasonTreeLevel = COALESCE(@intRptReasonTreeLevel, 4),      
  @intRptTopX = COALESCE(@intRptTopX, 1),      
  @intRptShowShift = COALESCE(@intRptShowShift, 1),      
  @intIncludeShiftProduction = COALESCE(@intIncludeShiftProduction, 0),      
  @intIncludeShiftDowntime = COALESCE(@intIncludeShiftDowntime, 1),      
  @intIncludeProduct = COALESCE(@intIncludeProduct, 0),      
  @intIncludeProductionDay = COALESCE(@intIncludeProductionDay, 1)      
        
IF  @intRptShowShift = 1      
BEGIN      
 SET @intIncludeShiftProduction = 1      
END      
ELSE      
BEGIN      
 SET @intIncludeShiftProduction = 0      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- Check for empty strings      
-----------------------------------------------------------------------------------------------------------------------      
IF LEN(RTRIM(LTRIM(@vchRptLineStatus))) = 0 SELECT @vchRptLineStatus = 'ALL'      
-----------------------------------------------------------------------------------------------------------------------      
-- Validate parameters      
-----------------------------------------------------------------------------------------------------------------------      
IF @vchRptLineStatus = '!NULL' SELECT @vchRptLineStatus = 'ALL'      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Default Prompt Values'      
--=====================================================================================================================      
-- GET DEFAULT PROMPT VALUES      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827002,'for Procter and Gamble Internal Use Only')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827003,'Start Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827004,'End Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827005,'Prepared Date')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827006,'Site Name')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827007,'Server Name')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827008,'Version')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827009,'Production Line')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827010,'Top X')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827011,'Reason Level')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827012,'Included Planned Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827013,'Included Blocked & Starved')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827014,'Report Period Production Summary')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827015,'Shift')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827016,'Team')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827017,'Start Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827018,'Production Status')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827019,'Product Code')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827020,'Product Description')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827021,'Target Rate')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827022,'Units/Min')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827023,'Schedule Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827024,'Min')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827025,'Target')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827026,'Target')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827027,'Total')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827028,'Total')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827029,'Net Production')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827030,'Stat Units')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827031,'PR')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827032,'%')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827033,'Overall Total')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827034,'Line Downtime Summary Measures')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827035,'Unit')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827036,'Unplanned MTBF')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827037,'MTTR')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827038,'Uptime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827039,'Planned Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827040,'Planned Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827041,'Supply Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827042,'Supply Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827043,'Internal Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827044,'Internal Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827045,'Minor Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827046,'Process Failures')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827047,'Breakdowns')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827048,'Unplanned Downtime Summary by DTGroup Category')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827049,'Category')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827050,'Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827051,'Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827052,'Calendar Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827095,'Scheduled Time')  --TCS (FO-00829)      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827053,'Min')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827054,'#')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827055,'Planned Downtime Summary by DTGroup Category')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827056,'Category')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827057,'Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827058,'Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827059,'Calendar Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827096,'Scheduled Time')  --TCS (FO-00829)      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827060,'Top X Downtime Summary By Ocurrence')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827061,'Level 1')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827062,'Level 2')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827063,'Level 3')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827064,'Level 4')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827065,'Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827066,'Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827067,'Top X Downtime Summary By Duration')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827068,'Level 1')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827069,'Level 2')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827070,'Level 3')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827071,'Level 4')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827072,'Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827073,'Stops')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827074,'Downtime Top X Longest Events')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827075,'Level 1')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827076,'Level 2')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827077,'Level 3')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827078,'Level 4')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827079,'Start Time')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827080,'Fault')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827081,'Downtime')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827082,'Comments')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827083,'LEDS Daily Direction Setting Report')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827084,'denotes it is a constraint unit')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827085,'Yes')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827086,'No')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827087,'LEDS Daily Direction Setting Report')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827088,'<Undefined>')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827089,'Units')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827090,'Cases')      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827091,'Total') -- used for line total      
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827092,'n/a')       
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827093,'Production Status')       
INSERT INTO @tblPrompts ( PromptId, PromptValue) VALUES (99827094,'All')       
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Prompts Values for the language of the user'      
--=====================================================================================================================      
-- GET Prompts Values for the language of the user      
----------------------------------------------------------------------------------------------------------------------      
-- GET language of user      
----------------------------------------------------------------------------------------------------------------------      
--SELECT @intUserId = OwnerID      
--FROM dbo.Report_Definitions WITH (NOLOCK)      
--WHERE Report_Id = @p_intRptID      
----------------------------------------------------------------------------------------------------------------------      
-- GET language      
----------------------------------------------------------------------------------------------------------------------      
SELECT @intLanguageId =  Value       
FROM  dbo.User_Parameters WIDTH(NOLOCK)      
WHERE  User_Id = @intUserId       
 AND Parm_Id = 8      
----------------------------------------------------------------------------------------------------------------------      
-- GET assigned prompt VALUES for the given Language      
----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblPrompts      
SET PromptValue = ld.Prompt_String      
FROM dbo.Language_Data ld WITH(NOLOCK)      
WHERE  ld.Language_Id = @intLanguageId      
 AND PromptId  = ld.Prompt_Number      
----------------------------------------------------------------------------------------------------------------------      
-- Overrride the language prompts where necessary      
-- Prompt override always have language_id = -1      
----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblPrompts      
SET PromptValue = ld.Prompt_String      
FROM dbo.Language_Data ld WITH(NOLOCK)      
WHERE  ld.Language_Id = -1      
 AND PromptId  = ld.Prompt_Number      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Site Parameter Values'      
--=====================================================================================================================      
-- GET Site Parameter Values      
-----------------------------------------------------------------------------------------------------------------------      
-- GET ServerName FROM site_parameters and parameters tables       
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchServerName = sp.Value      
FROM  dbo.Site_Parameters sp WITH (NOLOCK)      
JOIN  dbo.Parameters  p  WITH (NOLOCK)        
        ON  p.parm_id = sp.parm_id      
WHERE p.parm_name = 'ServicesHostName'      
-----------------------------------------------------------------------------------------------------------------------      
-- GET SiteName FROM site_parameters and parameters tables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchSiteName = sp.Value      
FROM  dbo.Site_Parameters sp  WITH(NOLOCK)      
 JOIN  dbo.Parameters  p  WITH(NOLOCK)ON  p.parm_id = sp.parm_id      
WHERE p.parm_name = 'SiteName'      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' REPORT FILTERS'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- REPORT FILTERS      
-- a. Production Line      
-- b. Production Line Status      
-- c. Production Unit (for this report production unit is not a user defined filter but to figure out downtime the      
--  report must include only production units that have downtime configured      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Production Line'      
--=====================================================================================================================      
-- a. Production Line      
-----------------------------------------------------------------------------------------------------------------------      
IF @vchRptProductionLine = '!NULL'  OR @vchRptProductionLine IS NULL  
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 --  Business Rule:       
 -- If no production lines are selected the code will return all production lines that have production units with      
 -- downtime events associated with them      
 -- A downtime event can only be associated with a master production unit and must be active      
 -- The downtime event configuration is recorded in the dbo.Event_Configuration table       
 -- Only want to return master production units that have reason trees associated with them, reason tree can be      
 -- associated with master units or slave units (locations), for this reason the query needs to look at slave units      
 -- Reason tree association can be found on dbo.Prod_Events      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #FilterProductionLines (      
    PLId ,      
    PLDesc )      
 SELECT DISTINCT      
   pl.PL_Id,      
   pl.PL_Desc      
 FROM dbo.Prod_Lines pl WITH (NOLOCK)      
  JOIN dbo.Prod_Units pu1 WITH (NOLOCK)        
         ON  pl.PL_Id = pu1.PL_Id      
  JOIN dbo.Event_Configuration ec WITH (NOLOCK)      
           ON pu1.PU_Id = ec.PU_Id      
  LEFT JOIN dbo.Prod_Units pu2 WITH (NOLOCK)        
           ON  pu1.PU_Id = pu2.Master_Unit      
  LEFT JOIN dbo.Prod_Events pe WITH (NOLOCK)      
           ON pu2.PU_Id = pe.PU_Id      
             OR pu1.PU_Id = pe.PU_Id      
 WHERE ec.ET_Id = 2 -- Downtime      
  AND pu1.Master_Unit IS NULL      
  AND pe.Name_Id IS NOT NULL      
 ORDER BY pl.PL_Desc      
 -------------------------------------------------------------------------------------------------------------------      
 --   CHECK if there's any configured LEDS line      
 -------------------------------------------------------------------------------------------------------------------      
 SET @intLinesCount = (SELECT COUNT(*) FROM #FilterProductionLines)      
 IF @intLinesCount=0      
 BEGIN      
  SELECT  @vchErrorMsg = 'No LEDS lines configured',      
    @intErrorCode = 1      
   GOTO ErrorFinish      
 END      
END      
ELSE      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 --   PARSE Production Line List      
 -------------------------------------------------------------------------------------------------------------------      
 TRUNCATE TABLE #TempParsingTable      
 INSERT INTO #TempParsingTable(RcdId, ValueINT)      
 EXEC spCMN_ReportCollectionParsing       
   @PRMCollectionString =  @vchRptProductionLine,      
   @PRMFieldDelimiter = NULL,        
   @PRMRecordDelimiter = '|',      
   @PRMDataType01 = 'INT'      
 -------------------------------------------------------------------------------------------------------------------      
 -- STORE parse data and      
 -- GET production line description      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #FilterProductionLines (      
    PLId,      
    PLDesc)      
 SELECT  gt.ValueINT,      
   pl.PL_Desc      
 FROM  #TempParsingTable gt      
 LEFT JOIN dbo.Prod_Lines  pl WITH (NOLOCK)       
         ON gt.ValueINT = pl.PL_Id      
 ORDER BY pl.PL_Desc      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- Validate Production Lines      
-----------------------------------------------------------------------------------------------------------------------      
IF EXISTS (SELECT PLId       
   FROM #FilterProductionLines      
   WHERE PLDesc IS NULL)      
BEGIN       
 -------------------------------------------------------------------------------------------------------------------      
 -- INITIALIZE variables      
 -------------------------------------------------------------------------------------------------------------------      
 SET @intErrorCode = 1      
 SELECT @i = 1,      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionLines      
 -------------------------------------------------------------------------------------------------------------------      
 -- LOOP through pl list and create an error meessage WIDTH the list of PLId's have have a NULL PLDesc      
 -------------------------------------------------------------------------------------------------------------------      
 SET @vchErrorMsg = 'The following list of production line ids does not exist in the database:  '      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  IF ( SELECT LEN(COALESCE(PLDesc, ''))      
    FROM #FilterProductionLines      
    WHERE RcdIdx = @i) = 0      
  BEGIN      
   SELECT @vchErrorMsg = @vchErrorMsg + CONVERT(VARCHAR(25), PLId) + ';'      
   FROM #FilterProductionLines      
   WHERE RcdIdx = @i      
  END      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT counter      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 SET @vchErrorMsg = SUBSTRING(@vchErrorMsg, 1, LEN(@vchErrorMsg)-1)      
  GOTO ErrorFinish      
END     

--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Production Status'      
--=====================================================================================================================      
-- b. Production Line Status      
-----------------------------------------------------------------------------------------------------------------------      
IF @vchRptLineStatus <> 'All'      
BEGIN       
 -------------------------------------------------------------------------------------------------------------------      
 -- STORE parse data and      
 -- GET production line description      
 -------------------------------------------------------------------------------------------------------------------      
 TRUNCATE TABLE #FilterProductionLineStatus      
 INSERT INTO #FilterProductionLineStatus(RcdIdx, PLStatusId)      
 EXEC spCMN_ReportCollectionParsing       
   @PRMCollectionString =  @vchRptLineStatus,      
   @PRMFieldDelimiter = NULL,        
   @PRMRecordDelimiter = ',',      
   @PRMDataType01 = 'INT'      
-------------------------------------------------------------------------------------------------------------------      
 -- Update Production Status Description      
 -------------------------------------------------------------------------------------------------------------------      
 UPDATE fps      
  SET PLStatusDesc = Phrase_Value      
 FROM #FilterProductionLineStatus fps      
  JOIN dbo.Phrase    p WITH (NOLOCK)      
           ON fps.PLStatusId = p.Phrase_Id      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Production Unit'      
--=====================================================================================================================      
-- c. Production Unit      
--  this code is the same as the Summary report but only the '!NULL' option is used. The code was left the same      
--  for reference      
--  @vchRptProductionUnit = 'All' was added in the new version 1.47 to add unit filtering      
-----------------------------------------------------------------------------------------------------------------------      
IF @vchRptProductionUnit = '!NULL' OR @vchRptProductionUnit = 'All' OR @vchRptProductionUnit IS NULL  
BEGIN      
 INSERT INTO #FilterProductionUnits (      
    PLId,      
    PUId,      
    PUDesc)      
 SELECT DISTINCT      
   pu.PL_Id,      
   pu.PU_Id,      
   pu.PU_Desc      
 FROM #FilterProductionLines fpl      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)        
          ON  fpl.PLId = pu.PL_Id      
   JOIN dbo.Event_Configuration ec WITH (NOLOCK)      
            ON pu.PU_Id = ec.PU_Id      
 LEFT JOIN dbo.Prod_Units pu2 WITH (NOLOCK)        
          ON  pu.PU_Id = pu2.Master_Unit      
 LEFT JOIN dbo.Prod_Events pe WITH (NOLOCK)      
         ON pu2.PU_Id = pe.PU_Id      
          OR pu.PU_Id = pe.PU_Id      
 WHERE ec.ET_Id = 2 -- Downtime      
  AND pu.Master_Unit IS NULL      
  AND pe.Name_Id IS NOT NULL      
 ORDER BY pu.PL_Id, pu.PU_Desc      
END      
ELSE      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- PARSE Production Unit List      
 -------------------------------------------------------------------------------------------------------------------      
 TRUNCATE TABLE #TempParsingTable      
 INSERT INTO #TempParsingTable(RcdId, ValueINT)      
 EXEC spCMN_ReportCollectionParsing       
   @PRMCollectionString =  @vchRptProductionUnit,      
   @PRMFieldDelimiter = NULL,        
   @PRMRecordDelimiter = '|',      
   @PRMDataType01 = 'INT'      
 -------------------------------------------------------------------------------------------------------------------      
 -- STORE parse data and      
 -- GET production unit description      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #FilterProductionUnits (      
    PLId,      
    PUId,      
    PUDesc)      
 SELECT pu.PL_Id,      
   gt.ValueINT,      
   pu.PU_Desc      
 FROM #TempParsingTable gt      
 LEFT JOIN dbo.Prod_Units pu WITH (NOLOCK)      
         ON gt.ValueINT = pu.PU_Id      

 -------------------------------------------------------------------------------------------------------------------      
 -- Apply Production Unit filter to Production Line list      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE fpl      
 FROM #FilterProductionLines fpl      
 LEFT JOIN #FilterProductionUnits fpu ON fpl.PLId = fpu.PLId      
 WHERE fpu.PLId IS NULL      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- Validate Production Units      
-----------------------------------------------------------------------------------------------------------------------      
IF EXISTS (SELECT PUId       
   FROM #FilterProductionUnits      
   WHERE PUDesc IS NULL)      
BEGIN       
 -------------------------------------------------------------------------------------------------------------------      
 -- INITIALIZE variables      
 -------------------------------------------------------------------------------------------------------------------      
 SET @intErrorCode = 1      
 SELECT @i = 1,      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionUnits      
 -------------------------------------------------------------------------------------------------------------------      
 -- LOOP through pu list and create an error meessage WIDTH the list of PUId's have have a NULL PUDesc      
 -------------------------------------------------------------------------------------------------------------------      
 SET @vchErrorMsg = 'The following list of Production Unit ids does not exist in the database:  '      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  IF ( SELECT LEN(COALESCE(PUDesc, ''))      
    FROM #FilterProductionUnits      
    WHERE RcdIdx = @i) = 0      
  BEGIN      
   SELECT @vchErrorMsg = @vchErrorMsg + CONVERT(VARCHAR(25), PUId) + ';'      
   FROM #FilterProductionUnits      
   WHERE RcdIdx = @i      
  END      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT counter      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 SET @vchErrorMsg = SUBSTRING(@vchErrorMsg, 1, LEN(@vchErrorMsg)-1)      
  GOTO ErrorFinish      
END      
--=====================================================================================================================      
-- UPDS      
--=====================================================================================================================      
-- Update tracking level      
-- Business rule: tracking level is a user defined parameter on the dbo.Production_Units table      
-- a. Find table id      
-- b. Find the field id      
--  'RE-PlannedTrackingLevel'      
--  'RE-ConstraintOrder'      
--  'RE-LastMachine'      
--  'RE-ParallelUnit'      
-- c. Find the UDP value       
-----------------------------------------------------------------------------------------------------------------------      
-- a. Find table id      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @intTableId = TableId      
FROM dbo.Tables      
WHERE TableName = 'Prod_Units'      
-----------------------------------------------------------------------------------------------------------------------      
-- b. Find the field id for 'RE-PlannedTrackingLevel'      
-----------------------------------------------------------------------------------------------------------------------      
SET @i = 1      
WHILE @i <= 4      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------       
 -- Get UDP description      
 -------------------------------------------------------------------------------------------------------------------       
 SELECT @vchTableFieldDesc = CASE WHEN @i = 1 THEN @vchPlannedTrackingLevelFieldName      
          WHEN @i = 2 THEN @vchConstraintOrderFieldName      
          WHEN @i = 3 THEN @vchLastMachineFieldName            
          WHEN @i = 4 THEN @vchParallelUnitFieldName       
          END      
 -------------------------------------------------------------------------------------------------------------------       
 -- Get UDP Field Id      
 -------------------------------------------------------------------------------------------------------------------       
 SELECT @intFieldId = Table_Field_Id      
 FROM dbo.Table_Fields WITH (NOLOCK)      
 WHERE Table_Field_Desc = @vchTableFieldDesc      
 -------------------------------------------------------------------------------------------------------------------       
 -- Get UDP values      
 -------------------------------------------------------------------------------------------------------------------        
 IF @i = 1      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Planned tracking level      
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE fpu      
  SET PlannedTrackingLevel = Value      
  FROM #FilterProductionUnits fpu      
   JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)      
            ON fpu.PUId = tfv.KeyId      
  WHERE tfv.TableId = @intTableId      
   AND tfv.Table_Field_Id = @intFieldId       
 END      
 ELSE IF @i = 2      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Constraint Order      
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE fpu      
  SET ConstraintOrder = Value      
  FROM #FilterProductionUnits fpu      
   JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)      
            ON fpu.PUId = tfv.KeyId      
  WHERE tfv.TableId = @intTableId      
   AND tfv.Table_Field_Id = @intFieldId       
 END        
 ELSE IF @i = 3      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Last Machine      
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE fpu      
  SET LastMachine = Value      
  FROM #FilterProductionUnits fpu      
   JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)      
            ON fpu.PUId = tfv.KeyId      
  WHERE tfv.TableId = @intTableId      
   AND tfv.Table_Field_Id = @intFieldId       
 END        
 ELSE IF @i = 4      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Parallel Unit      
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE fpu      
  SET ParallelUnit = Value      
  FROM #FilterProductionUnits fpu      
   JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)      
            ON fpu.PUId = tfv.KeyId      
  WHERE tfv.TableId = @intTableId      
   AND tfv.Table_Field_Id = @intFieldId       
 END               
 -------------------------------------------------------------------------------------------------------------------       
 -- Increment counter      
 -------------------------------------------------------------------------------------------------------------------       
 SET @i = @i + 1      
END      
--=====================================================================================================================      
-- GET the Virtual Production Units associated with each Downtime Production Unit      
-- Virtual Batch Unit will be identified by a UDP on the dbo.Prod_Units table with a       
-- UDP field name = @constUDPDescREProductionUnit      
-- and a UDP value = 1 (TRUE)      
--=====================================================================================================================      
INSERT INTO @tblVirtualProductionUnits (      
   PLId,      
   PUId)      
SELECT pl.PLId,      
  pu.PU_Id      
FROM  #FilterProductionLines   pl          
 JOIN  dbo.prod_units    pu WITH (NOLOCK)      
          ON pl.PLId = pu.PL_Id      
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)      
          ON pu.PU_Id = tfv.KeyId      
 JOIN dbo.Table_Fields  tf WITH (NOLOCK)      
          ON tf.Table_Field_Id  = tfv.Table_Field_Id      
WHERE tf.Table_Field_Desc = @vchUDPDescREProductionUnit      
 AND tfv.TableId = @intTableId      
 AND tfv.Value = '1' -- True      
-----------------------------------------------------------------------------------------------------------------------      
-- GET the production unit order      
-- UDP = @vchUDPDescREProdUnitOrder      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE vpu       
 SET PUOrder = Value      
FROM @tblVirtualProductionUnits vpu      
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)      
           ON vpu.PUId = tfv.KeyId      
 JOIN dbo.Table_Fields  tf WITH (NOLOCK)      
          ON tf.Table_Field_Id  = tfv.Table_Field_Id      
WHERE tf.Table_Field_Desc = @vchUDPDescREProdUnitOrder      
 AND tfv.TableId = @intTableId       
-----------------------------------------------------------------------------------------------------------------------      
-- Default the PUOrder to 1 UDP is not configured (serial systems)      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE vpu       
 SET PUOrder = COALESCE(PUOrder, 1)      
FROM @tblVirtualProductionUnits vpu      
-----------------------------------------------------------------------------------------------------------------------      
-- Match the Virtual Production Unit to the Downtime Production Unit      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #FilterProductionUnits      
 SET VirtualProductionCountPUId = vpu.PUId      
FROM #FilterProductionUnits fpu      
 JOIN @tblVirtualProductionUnits vpu ON fpu.PLId = vpu.PLId      
            AND fpu.ConstraintOrder = vpu.PUOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- Make the virtual production unit the same as the production unit if production is recorded at the source      
-----------------------------------------------------------------------------------------------------------------------      
IF NOT EXISTS ( SELECT VirtualProductionCountPUId      
     FROM #FilterProductionUnits      
     WHERE VirtualProductionCountPUId IS NOT NULL)      
BEGIN      
 UPDATE #FilterProductionUnits      
  SET VirtualProductionCountPUId = vpu.PUId      
 FROM #FilterProductionUnits fpu      
  JOIN @tblVirtualProductionUnits vpu ON fpu.PUId = vpu.PUId      
 WHERE ConstraintOrder = 0      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- Re-Order production units so that the constraint units appear first in section 2      
-- a. Copy contents of #FilterProductionUnits to a temp table      
-- b. TRUNCATE #FilterProductionUnits      
-- c. Re-insert the list of prod units in the desired order      
-----------------------------------------------------------------------------------------------------------------------      
-- a. Copy contents of #FilterProductionUnits to a temp table      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblFilterProductionUnitsTemp (      
   PLId      ,      
   PUId      ,      
   PUDesc      ,      
   PlannedTrackingLevel  ,      
   ConstraintOrder    ,      
   LastMachine     ,      
   ParallelUnit    ,      
   VirtualProductionCountPUId  ,      
   NormalProductionStatUnits )      
SELECT PLId      ,      
  PUId      ,      
  PUDesc      ,      
  PlannedTrackingLevel  ,      
  ConstraintOrder    ,      
  LastMachine     ,      
  ParallelUnit    ,      
  VirtualProductionCountPUId  ,      
  NormalProductionStatUnits       
FROM #FilterProductionUnits      
-----------------------------------------------------------------------------------------------------------------------      
-- b. TRUNCATE #FilterProductionUnits      
-----------------------------------------------------------------------------------------------------------------------      
TRUNCATE TABLE #FilterProductionUnits      
-----------------------------------------------------------------------------------------------------------------------      
-- c. Re-insert the list of prod units in the desired order      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @intRcdIdx = 1,      
  @intMAXRcdIdx = MAX(RcdIdx)      
FROM #FilterProductionLines      
-----------------------------------------------------------------------------------------------------------------------      
-- Loop through production lines       
-----------------------------------------------------------------------------------------------------------------------      
WHILE @intRcdIdx <= @intMAXRcdIdx      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Production Line      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPLId = PLId      
 FROM #FilterProductionLines      
 WHERE RcdIdx = @intRcdIdx      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET constraint PU's      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #FilterProductionUnits (      
    PLId      ,      
    PUId      ,      
    PUDesc      ,      
    PlannedTrackingLevel  ,      
    ConstraintOrder    ,      
    LastMachine     ,      
    ParallelUnit    ,      
    VirtualProductionCountPUId  ,      
    NormalProductionStatUnits )      
 SELECT PLId      ,      
   PUId      ,      
   PUDesc      ,      
   PlannedTrackingLevel  ,      
   ConstraintOrder    ,      
   LastMachine     ,      
   ParallelUnit    ,      
   VirtualProductionCountPUId  ,      
   NormalProductionStatUnits       
 FROM @tblFilterProductionUnitsTemp      
 WHERE PLId = @intPLId      
  AND ConstraintOrder > 0      
 ORDER BY ConstraintOrder      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET non-constraint PU's      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #FilterProductionUnits (      
    PLId      ,      
    PUId      ,      
    PUDesc      ,      
    PlannedTrackingLevel  ,      
    ConstraintOrder    ,      
    LastMachine     ,      
    ParallelUnit    ,      
    VirtualProductionCountPUId  ,      
    NormalProductionStatUnits )      
 SELECT PLId      ,      
   PUId      ,      
   PUDesc      ,      
   PlannedTrackingLevel  ,      
   ConstraintOrder    ,      
   LastMachine     ,      
   ParallelUnit    ,      
   VirtualProductionCountPUId  ,      
   NormalProductionStatUnits       
 FROM @tblFilterProductionUnitsTemp      
 WHERE PLId = @intPLId      
  AND ConstraintOrder = 0      
 ORDER BY PUDesc      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT counter      
 -------------------------------------------------------------------------------------------------------------------      
 SET @intRcdIdx = @intRcdIdx + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' MAJOR GROUPING'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- MAJOR GROUPING      
-- a.  Major Grouping is NONE      
-- b.  Major Grouping is NOT NONE      
--  Major grouping is Production Line      
--  Major grouping is Production Unit      
--  Major grouping is Product Group      
-- c. Major Grouping Desc      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Major Grouping is NONE'      
--=====================================================================================================================      
-- a. Major Grouping is NONE      
-----------------------------------------------------------------------------------------------------------------------      
IF @vchRptMajorGrouping = '!NULL'      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET prompt value for the word "All"      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @vchPrompt = PromptValue       
 FROM @tblPrompts       
 WHERE PromptID = 99826076      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #MajorGroupList (MajorGroupDesc)      
 VALUES (@vchPrompt)      
END      
ELSE      
BEGIN      
 --=================================================================================================================      
 IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
 IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Major Grouping is NOT NONE'      
 --=================================================================================================================      
 -- b.  Major Grouping is NOT NONE      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @nvchSQLCommand = '',      
   @nvchSQLCommand1 = '',      
   @nvchSQLCommand2 = '',      
   @nvchSQLCommand3 = ''      
 -------------------------------------------------------------------------------------------------------------------       
 SELECT @nvchSQLCommand1 = 'INSERT INTO #MajorGroupList (',      
   @nvchSQLCommand2 = 'SELECT ',      
   @nvchSQLCommand3 = 'FROM ',      
   @intFROMFlag = 0      
 -------------------------------------------------------------------------------------------------------------------       
 -- WHEN major group is Production Line (PL)      
 -------------------------------------------------------------------------------------------------------------------       
 IF (CHARINDEX('PL', @vchRptMajorGrouping, 1)) > 0      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- PREPARE insert statement      
  ---------------------------------------------------------------------------------------------------------------      
  SET @nvchSQLCommand1 =  @nvchSQLCommand1       
     +    'PLId, '      
     +   'PLDesc, '        
  ---------------------------------------------------------------------------------------------------------------      
  -- PREPARE SELECT statement      
  ---------------------------------------------------------------------------------------------------------------      
  SET @nvchSQLCommand2 =  @nvchSQLCommand2      
      +  'fpl.PLId, '      
      +  'fpl.PLDesc, '      
  ---------------------------------------------------------------------------------------------------------------      
  -- PREPARE FROM statement      
  ---------------------------------------------------------------------------------------------------------------       
  SET @nvchSQLCommand3 = @nvchSQLCommand3      
      +  '#FilterProductionLines fpl '      
 END      
 -------------------------------------------------------------------------------------------------------------------       
 -- WHEN major group is Production Units (PU)      
 -------------------------------------------------------------------------------------------------------------------       
 IF (CHARINDEX('PU', @vchRptMajorGrouping, 1)) > 0      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------   -- PREPARE insert statement      
  ---------------------------------------------------------------------------------------------------------------      
  SET @nvchSQLCommand1 =  @nvchSQLCommand1       
     +    'PUId, '      
     +   'PUDesc, '        
  ---------------------------------------------------------------------------------------------------------------      
  -- PREPARE SELECT statement      
  ---------------------------------------------------------------------------------------------------------------      
  SET @nvchSQLCommand2 =  @nvchSQLCommand2      
      +  'fpu.PUId, '      
      +  'fpu.PUDesc, '      
  ---------------------------------------------------------------------------------------------------------------      
  -- PREPARE FROM statement      
  ---------------------------------------------------------------------------------------------------------------       
  IF (CHARINDEX('PL', @vchRptMajorGrouping, 1)) > 0      
  BEGIN      
   SET @nvchSQLCommand3 = @nvchSQLCommand3      
       +  'JOIN #FilterProductionUnits fpu ON fpl.PLId = fpu.PLId'      
  END      
  ELSE      
  BEGIN      
   SET @nvchSQLCommand3 = @nvchSQLCommand3      
       +  '#FilterProductionUnits fpu '      
  END      
 END      
 -------------------------------------------------------------------------------------------------------------------       
 -- WHEN major group is Production Production Group      
 -- TODO for next fiscal      
 -------------------------------------------------------------------------------------------------------------------       
--  IF (CHARINDEX('ProdGroup', @vchRptMajorGrouping, 1)) > 0      
--  BEGIN      
--         
--  END      
 -------------------------------------------------------------------------------------------------------------------      
 -- REMOVE extra comma from select statement and       
 -- ADD '(' to insert statement      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @nvchSQLCommand1 = RTRIM(LTRIM(@nvchSQLCommand1))      
 SELECT @nvchSQLCommand1 = SUBSTRING(@nvchSQLCommand1, 1, LEN(@nvchSQLCommand1) - 1) + ')'      
 -------------------------------------------------------------------------------------------------------------------      
 -- REMOVE extra comma from select statement      
 ------------------------------------------------------------------------------------------------------------------      
 SELECT @nvchSQLCommand2 = RTRIM(LTRIM(@nvchSQLCommand2))      
 SELECT @nvchSQLCommand2 = SUBSTRING(@nvchSQLCommand2, 1, LEN(@nvchSQLCommand2) - 1)      
 -------------------------------------------------------------------------------------------------------------------      
 -- ASSEMBLE final statement      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @nvchSQLCommand = @nvchSQLCommand1 + ' ' + @nvchSQLCommand2 + ' ' + @nvchSQLCommand3      
 -------------------------------------------------------------------------------------------------------------------      
 -- EXECUTE SQL statement      
 -------------------------------------------------------------------------------------------------------------------      
 EXEC sp_ExecuteSQL @nvchSQLCommand      
 --=================================================================================================================      
 IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
 IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Major Group Desc'      
 --=================================================================================================================      
 -- GET Major Group Desc      
 -------------------------------------------------------------------------------------------------------------------      
 SET @nvchSQLCommand = ''      
  SET @nvchSQLCommand = 'UPDATE #MajorGroupList '      
    +   'SET MajorGroupDesc = '      
 -------------------------------------------------------------------------------------------------------------------      
 IF (CHARINDEX('PL', @vchRptMajorGrouping, 1)) > 0      
 BEGIN      
  SET @nvchSQLCommand = @nvchSQLCommand + 'PLDesc'      
  SET @nvchSQLCommand = @nvchSQLCommand + ' + '';'' + '      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 IF (CHARINDEX('PU', @vchRptMajorGrouping, 1)) > 0      
 BEGIN      
  SET @nvchSQLCommand = @nvchSQLCommand + 'PUDesc'      
  SET @nvchSQLCommand = @nvchSQLCommand + ' + '';'' + '      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 IF (CHARINDEX('ProdGroup', @vchRptMajorGrouping, 1)) > 0      
 BEGIN      
  SET @nvchSQLCommand = @nvchSQLCommand + 'ProdGroupDesc'      
  SET @nvchSQLCommand = @nvchSQLCommand + ' + '';'' + '      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- REMOVE extra ; from statement       
 -------------------------------------------------------------------------------------------------------------------      
  SET @nvchSQLCommand = RTRIM(LTRIM(@nvchSQLCommand))      
  SET @nvchSQLCommand = SUBSTRING(@nvchSQLCommand, 1, LEN(@nvchSQLCommand) - 8)      
 -------------------------------------------------------------------------------------------------------------------      
 -- EXECUTE SQL statement      
 -------------------------------------------------------------------------------------------------------------------    
 print @nvchSQLCommand  
 EXEC sp_ExecuteSQL @nvchSQLCommand      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' REPORT HEADER INFO COMMON'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- REPORT HEADER INFO COMMON      
-----------------------------------------------------------------------------------------------------------------------      
-- FILL table HdrInfoCommon      
-----------------------------------------------------------------------------------------------------------------------      
SET @i = 1      
-----------------------------------------------------------------------------------------------------------------------      
-- SET version      
-----------------------------------------------------------------------------------------------------------------------      
SET @vchVersion = '2.0.000.'  +  CONVERT(VARCHAR(4), DATEPART(YEAR, @dtmTempDate))        
    +  RIGHT('00' + (CONVERT(VARCHAR(2), DATEPART(MONTH, @dtmTempDate))), 2)       
        +  RIGHT('00' + (CONVERT(VARCHAR(2), DATEPART(DAY, @dtmTempDate))), 2)        
        + RIGHT('00' + (CONVERT(VARCHAR(2), DATEPART(HOUR, @dtmTempDate))), 2)       
        + RIGHT('00' + (CONVERT(VARCHAR(2), DATEPART(MINUTE, @dtmTempDate))), 2)       
        + RIGHT('00' + (CONVERT(VARCHAR(2), DATEPART(SECOND, @dtmTempDate))), 2)      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE app versions table      
-----------------------------------------------------------------------------------------------------------------------      
--UPDATE AppVersions      
-- SET App_Version = SUBSTRING(@vchVersion, 1, 7)      
--WHERE App_Id = @intAppId      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @i <= 7      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initiliaze variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @vchHdrLabel  = '',      
   @vchHdrLabelValue = ''      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET KeyId      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @vchHdrKeyId = CASE WHEN @i = 1 THEN 'RptTitle'      
         WHEN @i = 2 THEN 'StartDate'      
         WHEN @i = 3 THEN 'EndDate'       
         WHEN @i = 4 THEN 'PreparedDate'      
         WHEN @i = 5 THEN 'SiteName'       
         WHEN @i = 6 THEN 'ServerName'       
         WHEN @i = 7 THEN 'Version'       
         END                
 -------------------------------------------------------------------------------------------------------------------      
 -- GET header label      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @vchHdrLabel = CASE WHEN @i = 2 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827003)      
         WHEN @i = 3 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827004)      
         WHEN @i = 4 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827005)      
         WHEN @i = 5 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827006)      
         WHEN @i = 6 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827007)      
         WHEN @i = 7 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827008)      
         END                
 -------------------------------------------------------------------------------------------------------------------      
 -- GET header Value      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @vchHdrValue =  CASE WHEN @i = 1 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827087)      
          WHEN @i = 2 THEN CONVERT(VARCHAR(25), @dtmRptStartTime, 120)      
          WHEN @i = 3 THEN CONVERT(VARCHAR(25), @dtmRptEndTime, 120)           
          WHEN @i = 4 THEN CONVERT(VARCHAR(50), GETDATE(), 120)      
          WHEN @i = 5 THEN @vchSiteName      
          WHEN @i = 6 THEN @vchServerName      
          WHEN @i = 7 THEN    @vchVersion      
          END      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Header Label Column Index      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intHdrLabelColIdx = CASE WHEN @i = 1 THEN 0      
          WHEN @i = 2 THEN 0      
          WHEN @i = 3 THEN 0      
          WHEN @i = 4 THEN 0      
          WHEN @i = 5 THEN 0      
          WHEN @i = 6 THEN 0      
          WHEN @i = 7 THEN 0              END       
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Header Label Row Index      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intHdrLabelRowIdx = CASE WHEN @i = 1 THEN 0      
          WHEN @i = 2 THEN 1      
          WHEN @i = 3 THEN 2      
          WHEN @i = 4 THEN 3      
          WHEN @i = 5 THEN 4      
          WHEN @i = 6 THEN 5      
          WHEN @i = 7 THEN 6      
          END       
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Header Label Span      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intHdrLabelSpan = CASE WHEN @i = 1 THEN 0      
          WHEN @i = 2 THEN 1      
          WHEN @i = 3 THEN 1      
          WHEN @i = 4 THEN 1      
          WHEN @i = 5 THEN 1      
          WHEN @i = 6 THEN 1      
          WHEN @i = 7 THEN 1      
          END       
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Header Column Index      
 -------------------------------------------------------------------------------------------------------------------      
 SET @intHdrValueColIdx =  @intHdrLabelColIdx + @intHdrLabelSpan      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Header Row Index      
 -------------------------------------------------------------------------------------------------------------------      
 SET @intHdrValueRowIdx =  @intHdrLabelRowIdx      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET Header Value Span      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intHdrValueSpan = CASE WHEN @i = 1 THEN 14      
          WHEN @i = 2 THEN 3      
          WHEN @i = 3 THEN 3      
          WHEN @i = 4 THEN 3      
          WHEN @i = 5 THEN 3      
          WHEN @i = 6 THEN 3      
          WHEN @i = 7 THEN 3      
          END       
 -------------------------------------------------------------------------------------------------------------------      
 -- UPDATE @tblHdrInfoCommon      
 -------------------------------------------------------------------------------------------------------------------           
 INSERT INTO @tblHdrInfoCommon (      
    KeyId,      
    HdrLabelColIdx,      
    HdrLabelRowIdx,      
    HdrLabelSpan,      
    HdrValueColIdx,      
    HdrValueRowIdx,      
    HdrValueSpan,      
    HdrLabel,      
    HdrValue)          
 VALUES  ( @vchHdrKeyId,      
    @intHdrLabelColIdx,      
    @intHdrLabelRowIdx,      
    @intHdrLabelSpan,      
    @intHdrValueColIdx,      
    @intHdrValueRowIdx,      
    @intHdrValueSpan,      
    @vchHdrLabel,      
    @vchHdrValue )      
 -------------------------------------------------------------------------------------------------------------------      
 -- Increment counter      
 -------------------------------------------------------------------------------------------------------------------           
 SET @i = @i + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' HEADER INFO VARIABLE'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- HEADER INFO VARIABLE      
-- This section of code prepares the header information that is dependant on the major grouping options and       
-- the filters      
--=====================================================================================================================      
-- GET the major group count      
-----------------------------------------------------------------------------------------------------------------------      
 SELECT @i = 1,      
   @vchPLDesc = '',      
   @intMAXMajorGroupId =  MAX(MajorGroupId)       
 FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
-- LOOP throught the major groups and prepare the header info      
-----------------------------------------------------------------------------------------------------------------------      
 WHILE @i <= @intMAXMajorGroupId      
 BEGIN      
  -------------------------------------------------------------------------------------------------------------------      
  -- GET major group info      
  -------------------------------------------------------------------------------------------------------------------      
  SELECT  @vchPLDesc = COALESCE(PLDesc, ''),             
    @intHdrMajorGroupID = MajorGroupId       
  FROM #MajorGroupList      
  WHERE MajorGroupId = @i      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET the header info      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = 1      
 WHILE @j <= 6 --Amount of Headers      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- GET KeyId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @vchHdrKeyId = CASE WHEN @j = 1 THEN 'PL'      
          WHEN @j = 2 THEN 'TopX'      
          WHEN @j = 3 THEN 'ReasonLevel'       
          WHEN @j = 4 THEN 'PlannedStops'      
          WHEN @j = 5 THEN 'BlockedStops'       
          WHEN @j = 6 THEN 'ProdStatus'      
          END       
  ---------------------------------------------------------------------------------------------------------------      
  -- GET Header LAbel Column Index      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intHdrLabelColIdx = 9      
  ---------------------------------------------------------------------------------------------------------------      
  -- GET Header Label Row Index      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intHdrLabelRowIdx = CASE WHEN @j = 1 THEN 1      
           WHEN @j = 2 THEN 2      
           WHEN @j = 3 THEN 3      
           WHEN @j = 4 THEN 4      
           WHEN @j = 5 THEN 5      
           WHEN @j = 6 THEN 6      
           END       
  ---------------------------------------------------------------------------------------------------------------      
  -- GET Header Label Span      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intHdrLabelSpan = 3      
  ---------------------------------------------------------------------------------------------------------------      
  -- GET Header Value Column Index      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intHdrValueColIdx =  @intHdrLabelColIdx + @intHdrLabelSpan      
  ---------------------------------------------------------------------------------------------------------------      
  -- GET Header Value Row Index      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intHdrValueRowIdx = @intHdrLabelRowIdx      
  ---------------------------------------------------------------------------------------------------------------      
  -- GET Header Value Span      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intHdrValueSpan = 2      
  ---------------------------------------------------------------------------------------------------------------    -- GET Header Label      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @vchHdrLabel = CASE WHEN @j = 1 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827009)      
          WHEN @j = 2 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827010)      
          WHEN @j = 3 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827011)      
          WHEN @j = 4 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827012)      
          WHEN @j = 5 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827013)      
          WHEN @j = 6 THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827093)      
          END       
  ---------------------------------------------------------------------------------------------------------------      
  -- GET  Header Values      
  -- Production Line      
  -- Production Unit      
  -- Product Group      
  -- Product Code      
  -- Shift       
  -- Team      
  -- Production Status      
  ---------------------------------------------------------------------------------------------------------------      
  IF @j = 1      
  BEGIN      
   -----------------------------------------------------------------------------------------------------------      
   -- Production Lines      
   -----------------------------------------------------------------------------------------------------------      
   SELECT @vchHdrValue = PLDesc      
   FROM #FilterProductionLines      
   WHERE RcdIdx = @i      
  END      
  ELSE IF @j = 2      
  BEGIN      
   SET @vchHdrValue = @intRptTopX         
  END       
  ELSE IF @j = 3      
  BEGIN      
   SET @vchHdrValue = @intRptReasonTreeLevel      
  END       
  ELSE IF @j = 4      
  BEGIN      
   SELECT @vchHdrValue = CASE WHEN @intRptFilterPlanned = 1       
          THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827086)      
          ELSE (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827085)      
          END      
  END       
  ELSE IF @j = 5      
  BEGIN      
   SELECT @vchHdrValue = CASE WHEN @intRptFilterBlocked = 1      
          THEN (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827086)      
          ELSE (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99827085)      
          END       
  END    
  ELSE IF @j = 6      
  BEGIN      
   -----------------------------------------------------------------------------------------------------------      
   -- Production Status      
   ---------------------------------------------------------------------------------------------------------------      
   IF @vchRptLineStatus <> 'ALL'      
   BEGIN      
    -------------------------------------------------------------------------------------------------------      
    -- Initialize variables      
    -------------------------------------------------------------------------------------------------------      
    SELECT @k = 1,      
      @vchHdrValue = '',      
      @intMaxProductionLineStatusRcIdx = MAX(RcdIdx)      
    FROM #FilterProductionLineStatus      
    -------------------------------------------------------------------------------------------------------      
    -- Loop through product code to get list for header      
    -------------------------------------------------------------------------------------------------------      
    WHILE @k <= @intMaxProductionLineStatusRcIdx      
    BEGIN      
     IF  @k = 1       
     BEGIN      
      SELECT @vchHdrValue = PLStatusDesc      
      FROM #FilterProductionLineStatus      
      WHERE RcdIdx = @k      
     END      
     ELSE      
     BEGIN      
      SELECT @vchHdrValue = @vchHdrValue + '; ' + PLStatusDesc      
      FROM #FilterProductionLineStatus      
      WHERE RcdIdx = @k              
     END      
     ---------------------------------------------------------------------------------------------------      
     -- Increment counter      
     ---------------------------------------------------------------------------------------------------      
     SET @k = @k + 1            
    END      
    END      
   ELSE      
   BEGIN      
    SELECT @vchHdrValue = PromptValue      
    FROM @tblPrompts       
    WHERE  PromptID = 99827094       
   END      
  END       
  ---------------------------------------------------------------------------------------------------------------      
  -- Insert values into @tblVariable      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblHdrInfoVariable (      
     MajorGroupId ,      
     KeyId   ,      
     HdrLabelColIdx ,      
     HdrLabelRowIdx ,      
     HdrLabelSpan ,      
     HdrValueColIdx ,      
     HdrValueRowIdx ,      
     HdrValueSpan ,      
     HdrLabel  ,      
     HdrValue  )      
  VALUES ( @intHdrMajorGroupID,      
     @vchHdrKeyId,      
     @intHdrLabelColIdx,      
     @intHdrLabelRowIdx,      
     @intHdrLabelSpan,      
     @intHdrValueColIdx,      
     @intHdrValueRowIdx,      
     @intHdrValueSpan,      
     @vchHdrLabel,      
     @vchHdrValue )      
  ---------------------------------------------------------------------------------------------------------------      
  -- Increment counter      
  ---------------------------------------------------------------------------------------------------------------      
  SET @j = @j + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Increment counter      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @i + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET SECTION INFO'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- GET SECTION INFO      
-- a. Section Labels      
-- b. Section Columns      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INITIALIZE Section List'      
--=====================================================================================================================      
-- INITIALIZE section list      
-- a. GET PromptNumber for section title      
-- b. ADD value to section list      
-----------------------------------------------------------------------------------------------------------------------      
SET @i = 1    WHILE @i <= 7      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. GET PromptNumber for section title      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPromptId = CASE WHEN @i = 1 THEN 99827014 --  Report Period  Production Summary      
         WHEN @i = 2 THEN 99827034 --  Line Downtime Summary Measures      
         WHEN @i = 3 THEN 99827048 --  Unplanned Downtime Summary By DTGroup Category      
         WHEN @i = 4 THEN 99827055 -- Planned Downtime Summary By DTGroup Category      
         WHEN @i = 5 THEN 99827060 -- Top X Downtime Summary By Ocurence      
         WHEN @i = 6 THEN 99827067 --  Top X Downtime Summary By Duration      
         WHEN @i = 7 THEN 99827074 -- Downtime Top X Longest Events      
         END      
 -------------------------------------------------------------------------------------------------------------------      
 -- b. ADD value to section list      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSectionList(      
    SectionLabel,       
    PromptNumber)       
 SELECT  PromptValue,       
   @intPromptId        
 FROM @tblPrompts        
 WHERE PromptId = @intPromptId        
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT counter      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @i + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Section Columns'      
--=====================================================================================================================      
-- REPORT PERIOD PRODUCTION SUMMARY      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 0 , 'Shift'   , 99827015, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 1 , 'Team'   , 99827016, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 2 , 'StartTime'  , 99827017, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 3 , 'ProductionStatus', 99827018, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 4 , 'ProdCode'  , 99827019, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 5 , 'ProdDesc'  , 99827020, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 6 , 'TargetRate'  , 99827021, 99827022,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 7 , 'SchedTime'  , 99827023, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 8 , 'TargetUnits'  , 99827025, 99827089,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 9 , 'TargetCases'  , 99827026, 99827090,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 10 , 'TotalUnits'  , 99827027, 99827089,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 11 , 'TotalCases'  , 99827028, 99827090,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 12 , 'NetProduction' , 99827029, 99827030,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (1, 13 , 'PR'    , 99827031, 99827032,1, 2, 2)      
-----------------------------------------------------------------------------------------------------------------------      
-- LINE DOWNTIME SUMMARY MEASURES      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 0, 'Unit'    , 99827035, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 1, 'Blank'    , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 2, 'MTBF'    , 99827036, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 3, 'MTTR'    , 99827037, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 4, 'Uptime'   , 99827038, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 5, 'PlannedStops'  , 99827039, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 6, 'PlannedDowntime' , 99827040, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 7, 'SupplyStops'  , 99827041, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 8, 'SupplyDowntime' , 99827042, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 9, 'InternalStops'  , 99827043, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 10, 'InternalDowntime' , 99827044, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 11, 'MinorStops'  , 99827045, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 12, 'ProcessFailures' , 99827046, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (2, 13, 'Breakdowns'  , 99827047, 99827054,1, 0, 1)      
-----------------------------------------------------------------------------------------------------------------------     
-- UNPLANNED DOWNTIME SUMMARY BY DTGROUP CATEGORY      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 0, 'Category'  , 99827049, NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 1, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 2, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 3, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 4, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 5, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 6, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 7, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 8, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 9, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 10, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 11, 'Downtime'  , 99827050, 99827024,1 , 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 12, 'Stops'   , 99827051, 99827054,1 , 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (3, 13, 'CalendarTime'  , 99827052, 99827032,1 , 2, 2)      
INSERT INTO   @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId)   VALUES (3, 14,  'ScheduleTime'    , 99827095, 99827032  ,1   ,   2,   2)    --TCS (FO-00829)      
-----------------------------------------------------------------------------------------------------------------------      
-- PLANNED DOWNTIME SUMMARY BY DTGROUP CATEGORY      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 0, 'Category'  , 99827056, NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 1, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 2, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 3, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 4, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 5, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 6, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 7, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 8, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 9, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 10, 'Blank'   , NULL   , NULL ,1 , 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 11, 'Downtime'  , 99827057, 99827024,1 , 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 12, 'Stops'   , 99827058, 99827054,1 , 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (4, 13, 'CalendarTime'  , 99827059, 99827032,1 , 2, 2)      
INSERT INTO   @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId)   VALUES (4, 14,  'ScheduleTime'    , 99827096, 99827032  ,1   ,   2,   2)    --TCS (FO-00829)      
-----------------------------------------------------------------------------------------------------------------------      
-- TOP X DOWNTIME SUMMARY BY OCCURRENCE      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 0, 'Level1' , 99827061, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 2, 'Level2' , 99827062, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 4, 'Level3' , 99827063, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 6, 'Level4' , 99827064, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 8, 'Blank'  , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 9, 'Blank'  , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 10, 'Blank'  , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 11, 'Downtime' , 99827065, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 12, 'Stops'  , 99827066, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (5, 13, 'Blank'  , NULL   , NULL ,1, 0, 3)      
-----------------------------------------------------------------------------------------------------------------------      
-- TOP X DOWNTIME SUMMARY BY DURATION      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 0, 'Level1' , 99827068, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 2, 'Level2' , 99827069, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 4, 'Level3' , 99827070, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 6, 'Level4' , 99827071, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 8, 'Blank'  , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 9, 'Blank'  , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 10, 'Blank'  , NULL   , NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 11, 'Downtime' , 99827072, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 12, 'Stops'  , 99827073, 99827054,1, 0, 1)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (6, 13, 'Blank'  , NULL   , NULL ,1, 0, 3)      
-----------------------------------------------------------------------------------------------------------------------      
-- DOWNTIME TOP X LONGEST EVENTS      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 0, 'Level1' , 99827075, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 2, 'Level2' , 99827076, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 4, 'Level3' , 99827077, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 6, 'Level4' , 99827078, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 8, 'StartTime' , 99827079, NULL ,1, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 9, 'Fault'  , 99827080, NULL ,2, 0, 3)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 11, 'Downtime' , 99827081, 99827024,1, 2, 2)      
INSERT INTO @tblSectionColumn (SectionId, ColIdx, KeyId, ColLabelPrompt, ColEngUnitsPrompt, ColSpan, ColPrecision, ColDataTypeId) VALUES (7, 12, 'Comments' , 99827082, NULL ,2, 0, 100)      
-----------------------------------------------------------------------------------------------------------------------      
-- GET column label values prompt table      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE sc      
 SET ColLabel = p.PromptValue      
FROM @tblSectionColumn sc      
 JOIN @tblPrompts  p ON sc.ColLabelPrompt = p.PromptId        
-----------------------------------------------------------------------------------------------------------------------       
-- GET eng units values from prompt table      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE sc      
 SET EngUnits = p.PromptValue      
FROM @tblSectionColumn sc      
 JOIN @tblPrompts  p ON sc.ColEngUnitsPrompt = p.PromptId        
-----------------------------------------------------------------------------------------------------------------------      
-- GET colum widths for all column labels section      
-- The width of columns in section 1 will be the default in the report. Other sections may override section 1 column      
-- width only if the column label requires a wider column      
-----------------------------------------------------------------------------------------------------------------------      
-- Initialize variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT  @intWordCount = 0,       
  @i = 1,      
  @intMaxRcdIdx = MAX(RcdIdx)      
FROM @tblSectionColumn      
-----------------------------------------------------------------------------------------------------------------------      
-- LOOP through column labels       
-----------------------------------------------------------------------------------------------------------------------      
WHILE @i <= @intMaxRcdIdx      
BEGIN      
 SELECT @vchColLabel = ColLabel      
 FROM @tblSectionColumn      
 WHERE RcdIdx = @i      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET word count      
 -- a. Replace spaces WIDTH '|'      
 -- b. Parse string into individual words      
 -- c. Get the word count and the length of the longest word      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. Replace spaces WIDTH '|'      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @vchColLabel = REPLACE(@vchColLabel, ' ', '|')       
 -------------------------------------------------------------------------------------------------------------------      
 -- b. Parse string into individual words      
 -------------------------------------------------------------------------------------------------------------------      
 IF LEN(LTRIM(RTRIM(@vchColLabel))) > 0      
 BEGIN      
  TRUNCATE TABLE #TempParsingTable      
  INSERT INTO #TempParsingTable(RcdId, ValueVARCHAR100)      
  EXEC spCMN_ReportCollectionParsing       
    @PRMCollectionString =  @vchColLabel,      
    @PRMFieldDelimiter = NULL,        
    @PRMRecordDelimiter = '|',      
    @PRMDataType01 = 'VARCHAR(100)'      
  ---------------------------------------------------------------------------------------------------------------      
  -- c. Get the word count and the length of the longest word      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intWordCount = COUNT(ValueVARCHAR100),      
    @intMaxLength = MAX(LEN(ValueVARCHAR100))      
  FROM #TempParsingTable      
  ---------------------------------------------------------------------------------------------------------------      
  -- GET column WIDTH      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT  @intMaxLength = CASE WHEN @intMaxLength <= 5       
          THEN @intMaxLength * 11      
          ELSE @intMaxLength * 9      
          END      
  ---------------------------------------------------------------------------------------------------------------      
  -- UPDATE word count and ColWidth      
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE @tblSectionColumn      
  SET WordCount = @intWordCount,      
   ColWIDTH = @intMaxLength      
  WHERE RcdIdx = @i      
  ---------------------------------------------------------------------------------------------------------------      
  -- UPDATE ColWidth for the       
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE @tblSectionColumn      
  SET ColWIDTH = @intMaxLength + 20      
  WHERE RcdIdx = 8      
 END      
 ELSE      
 BEGIN      
  UPDATE @tblSectionColumn      
  SET WordCount = 1,      
   ColWIDTH = 1      
  WHERE RcdIdx = @i      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Override ColWidth for col 0, 3 and 5      
 -------------------------------------------------------------------------------------------------------------------      
 IF  @i = 1       
 BEGIN      
  UPDATE @tblSectionColumn      
  SET ColWidth = 180      
  WHERE  RcdIdx = @i      
 END      
 ELSE IF @i = 4      
 BEGIN      
  UPDATE @tblSectionColumn      
  SET ColWidth = ColWidth + 5      
  WHERE  RcdIdx = @i      
 END      
 ELSE IF @i = 5      
 BEGIN      
  UPDATE @tblSectionColumn      
  SET ColWidth = ColWidth + 10      
  WHERE  RcdIdx = @i      
 END      
 ELSE IF @i = 6      
 BEGIN      
  UPDATE @tblSectionColumn      
  SET ColWidth = ColWidth + 35      
  WHERE  RcdIdx = @i      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- SET colwidth = 1 on column that are blank      
 -------------------------------------------------------------------------------------------------------------------      
       
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT counter      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @i = @i + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' LEDS DETAILS'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- LEDS DETAILS      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET LEDS Raw Data'      
--=====================================================================================================================      
-- Initialize Variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @i = 1,      
  @intMaxRcdIdx = MAX(RcdIdx),      
  @vchStartTime =  CONVERT(VARCHAR(25), @dtmRptStartTime, 120),      
  @vchEndTime =  CONVERT(VARCHAR(25), @dtmRptEndTime, 120)      
FROM #FilterProductionUnits      
-----------------------------------------------------------------------------------------------------------------------      
-- Loop through production units and call fnLocal_LEDS_DowntimeRawData to get LEDS raw data      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @i <= @intMaxRcdIdx      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initialize Variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPUId      = NULL,      
   @intPlannedTrackingLevel  = NULL,      
   @intConstraintOrder   = NULL,      
   @intLastMachine    = NULL,      
   @intParallelUnit    = NULL      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPUId      = PUId,      
   @intPlannedTrackingLevel  = PlannedTrackingLevel,      
   @intConstraintOrder   = ConstraintOrder,      
   @intLastMachine    = LastMachine,      
   @intParallelUnit    = ParallelUnit      
 FROM #FilterProductionUnits      
 WHERE RcdIdx = @i      
 -------------------------------------------------------------------------------------------------------------------      
 -- Call Function      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #LEDSDetails (      
    PLId     ,      
    PUId     ,      
    ProductionCountPUId  ,      
    ProdId     ,      
    EventProductionDay  ,      
    EventProductionDayId ,      
    EventProductionStatus ,        
    Shift     ,      
    Team     ,      
    LEDSId     ,      
    UPTimeStart    ,      
    UPTimeEnd    ,      
    UPTimeDurationInSec  ,      
    LEDSStart    ,      
    LEDSEnd     ,      
    LEDSStartForRpt   ,      
    LEDSEndForRpt   ,      
    LEDSDurationInSecForRpt ,      
    LEDSDurationInSec  ,      
    LEDSCount    ,      
    LEDSParentId   ,      
    CauseRL1Id    ,      
    CauseRL2Id    ,      
    CauseRL3Id    ,      
    CauseRL4Id    ,      
    TreeNodeId    ,      
    ActionTreeId   ,      
    Action1Id    ,      
    Action2Id    ,      
    Action3Id    ,      
    Action4Id    ,      
    ACtionTreeNodeId  ,      
    CatDTSched    ,      
    CatDTType    ,      
    CatDTGroup    ,      
    CatDTMach    ,      
    CatDTClass    ,      
    CatDTClassCause   ,      
    CatDTClassAction  ,      
    FaultId     ,      
    LEDSCommentId   ,      
    EventSplitFactor  ,      
    EventSplitFlag   ,      
    EventSplitShiftFlag  ,      
    EventSplitProductionDayFlag ,      
    ErrorCode    ,      
    Error     ,      
    PlannedTrackingLevel ,      
    ConstraintOrder   ,      
    LastMachine    ,      
    ParallelUnit   )      
 SELECT PLId     ,      
   PUId     ,      
   ProductionPUId   ,      
   ProdId     ,      
   EventProductionDay  ,      
   EventProductionDayID ,      
   EventProductionStatus ,       
   EventShift    ,      
   EventTeam    ,      
   LEDSId     ,      
   UPTimeStart    ,      
   UPTimeEnd    ,      
   UPTimeDurationInSec  ,      
   LEDSStart    ,      
   LEDSEnd     ,      
   LEDSStartForRpt   ,      
   LEDSEndForRpt   ,      
   LEDSDurationInSecForRpt ,      
   LEDSDurationInSec  ,      
   LEDSCount    ,      
   LEDSParentId   ,      
   CauseRL1Id    ,      
   CauseRL2Id    ,      
   CauseRL3Id    ,      
   CauseRL4Id    ,      
   TreeNodeId    ,      
   ActionTreeId   ,      
   Action1Id    ,      
   Action2Id    ,      
   Action3Id    ,      
   Action4Id    ,      
   ACtionTreeNodeId  ,      
   CatDTSched    ,      
   CatDTType    ,      
   CatDTGroup    ,      
   CatDTMach    ,      
   CatDTClass    ,      
   CatDTClassCause   ,      
   CatDTClassAction  ,      
   FaultId     ,      
   LEDSCommentId   ,      
   EventSplitFactor  ,      
   EventSplitFlag   ,      
   EventSplitShiftFlag  ,      
   EventSplitProductionDayFlag ,      
   ErrorCode    ,      
   Error     ,      
   @intPlannedTrackingLevel,      
   @intConstraintOrder  ,      
   @intLastMachine   ,      
   @intParallelUnit         
 FROM dbo.fnLocal_LEDS_DowntimeRawData (@intPUId, @vchStartTime, @vchEndTime, @intRptSplitRecords, @intIncludeShiftDowntime, @intIncludeProductionDay, @intIncludeProduct)      
 -------------------------------------------------------------------------------------------------------------------      
 -- Increment counter      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @i + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Apply Filters'      
--=====================================================================================================================      
-- Production Line Status      
-----------------------------------------------------------------------------------------------------------------------      
IF EXISTS ( SELECT  PLStatusDesc      
   FROM  #FilterProductionLineStatus)      
BEGIN      
 DELETE #LEDSDetails      
 WHERE EventProductionStatus NOT IN  ( SELECT  PLStatusDesc      
           FROM  #FilterProductionLineStatus)      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Event Reason Descriptions'      
--=====================================================================================================================      
-- Default to unplanned downtime where CatDTSched IS NULL      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ld      
 SET Cause1 = er1.Event_Reason_Name,      
  Cause2 = er2.Event_Reason_Name,      
  Cause3 = er3.Event_Reason_Name,      
  Cause4 = er4.Event_Reason_Name      
FROM #LEDSDetails ld      
 LEFT JOIN dbo.Event_Reasons er1 WITH (NOLOCK)      
          ON ld.CauseRL1Id = er1.Event_Reason_Id      
 LEFT JOIN dbo.Event_Reasons er2 WITH (NOLOCK)      
          ON ld.CauseRL2Id = er2.Event_Reason_Id      
 LEFT JOIN dbo.Event_Reasons er3 WITH (NOLOCK)      
          ON ld.CauseRL3Id = er3.Event_Reason_Id      
 LEFT JOIN dbo.Event_Reasons er4 WITH (NOLOCK)      
          ON ld.CauseRL4Id = er4.Event_Reason_Id      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Cause Categories Defaults'      
--=====================================================================================================================      
-- Default to unplanned downtime where CatDTSched IS NULL      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #LEDSDetails      
 SET CatDTSched = @vchCatLEDSUnplanned      
WHERE CatDTSched IS NULL      
-----------------------------------------------------------------------------------------------------------------------      
-- Default to unplanned downtime when CatDTShed = Planned and tracking level is 1      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #LEDSDetails      
 SET CatDTSched = @vchCatLEDSUnplanned      
WHERE CatDTSched = @vchCatLEDSPlanned      
 AND PlannedTrackingLevel = 1      
-----------------------------------------------------------------------------------------------------------------------      
-- Default CatDTMach to Internal      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #LEDSDetails      
 SET CatDTMach = @vchCatDTMachInternal      
WHERE CatDTMach IS NULL      
-----------------------------------------------------------------------------------------------------------------------      
-- Default CatDTGroup to <Undefined>      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #LEDSDetails      
 SET CatDTGroup = (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827088)      
WHERE CatDTGroup IS NULL      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET the fault description'      
--=====================================================================================================================      
-- GET the fault description      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ld      
 SET FaultDesc = TEFault_Name      
FROM #LEDSDetails ld      
 JOIN dbo.Timed_Event_Fault tef WITH (NOLOCK)       
          ON tef.TEFault_Id = ld.FaultId      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Comments'      
--=====================================================================================================================      
-- GET Comment text for comments that are not chained      
-----------------------------------------------------------------------------------------------------------------------      
-----------------------------------------------------------------------------------------------------------------------      
-- a. CHECK Value for TimeOption      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @vchAppName = Value       
FROM @tblReportParameters       
WHERE RPName = 'AppName'      
-----------------------------------------------------------------------------------------------------------------------      
-- The case was added for the new version 1.47 to use comment when web base and comment_text when excel      
UPDATE ld      
 SET LEDSComment = CASE WHEN @vchAppName = 'Excel'  THEN Comment_text      
       ELSE Comment      
       END      
FROM #LEDSDetails ld      
 JOIN dbo.Comments c ON ld.LEDSCommentId = Comment_Id      
WHERE NextComment_Id IS NULL      
-----------------------------------------------------------------------------------------------------------------------      
-- Get list of comment id's that have chained comments      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblChainedCommentList (      
   LEDSId,      
   CommentId)      
SELECT LEDSId,      
  LEDSCommentId      
FROM #LEDSDetails      
WHERE LEDSComment IS NULL       
-----------------------------------------------------------------------------------------------------------------------      
-- Initialize variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @i = 1,      
  @intMaxRcdIdx = MAX(RcdIdx)      
FROM @tblChainedCommentList      
-----------------------------------------------------------------------------------------------------------------------      
-- Loop through list of comment id's and get comment chain      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @i <= @intMaxRcdIdx      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- Get comment Id      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intLEDSId = LEDSId,      
   @intCommentId = CommentId      
 FROM @tblChainedCommentList      
 WHERE RcdIdx = @i      
 -------------------------------------------------------------------------------------------------------------------      
 -- Get comment Id      
 -- The case was added for the new version 1.47 to use comment when web base and comment_text when excel      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblChainedCommentText  (      
    CommentId,      
    CommentText)      
 SELECT Comment_Id,      
   CASE WHEN @vchAppName = 'Excel'  THEN Comment_text      
       ELSE Comment      
       END      
 FROM dbo.Comments WITH (NOLOCK)      
 WHERE TopOfChain_Id = @intCommentId      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @j = MIN(RcdIdx),      
   @intMaxRcdIdx2 = MAX(RcdIdx)      
 FROM @tblChainedCommentText      
 -------------------------------------------------------------------------------------------------------------------      
 -- Concatenate comment text      
 -------------------------------------------------------------------------------------------------------------------      
 SET @vchCommentText = ''      
 WHILE @j <= @intMaxRcdIdx2      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get comment text      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @vchCommentText = LTRIM(RTRIM(SUBSTRING(@vchCommentText + '|' + CommentText, 1, 5000)))      
  FROM @tblChainedCommentText      
  WHERE RcdIdx = @j      
  ---------------------------------------------------------------------------------------------------------------      
  -- Increment counter      
  ---------------------------------------------------------------------------------------------------------------      
  SET @j = @j + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Update comment text      
 -------------------------------------------------------------------------------------------------------------------      
 UPDATE ld      
  SET LEDSComment = SUBSTRING(@vchCommentText, 2, LEN(@vchCommentText))      
 FROM #LEDSDetails ld      
 WHERE LEDSId = @intLEDSId      
  AND LEDSCommentId = @intCommentId      
 -------------------------------------------------------------------------------------------------------------------      
 -- Increment counter      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @i + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ASSIGN major group id to LEDS Raw Data'      
--=====================================================================================================================      
-- ASSIGN major and minor groups to LEDS      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ld       
 SET MajorGroupId = mgl.MajorGroupId      
FROM #LEDSDetails ld       
 JOIN #MajorGroupList mgl ON ld.PLId = mgl.PLId      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE LEDS Summary Measures'      
--=====================================================================================================================      
-- CALCULATE LEDS Summary Measures      
-- This section summarizes the LEDS details by production Unit      
-- a. UptimeInSec      
-- b. PlannedStops and PlannedDTInSec      
-- c. UnPlannedStops and UnPlannedDTInSec      
-- d. SupplyStops and SupplyDTInSec      
-- e. InternalStops and InternalDTInSec      
-- f. MinorStops      
-- g. ProcessFailure      
--  h. Breakdowns      
-- i. Blocked Stops      
-- j. MTBF      
-- k. MTTR      
-----------------------------------------------------------------------------------------------------------------------      
-- a. UptimeInSec      
--  Business Rule:      
--  The uptime has been calculated as the time between downtime events      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblLineDowntimeMeasures  (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ConstraintOrder ,      
   UpTimeInSec  ,      
LastMachine  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  ConstraintOrder,      
  SUM(UpTimeDurationInSec),      
  LastMachine      
FROM #LEDSDetails      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder, LastMachine      
-----------------------------------------------------------------------------------------------------------------------      
-- b. PlannedStops and PlannedDTInSec      
--  Business Rule for Planned Downtime:      
--  All DT event records where DTSched = Planned and Planned TrackingLevel = 2 or 3.  If planned tracking level       
--  is 1, report zero planned stops.       
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  ,      
   ValueFLOAT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount),      
  SUM(LEDSDurationInSecForRpt)      
FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE ld.CATDTSched = @vchCatLEDSPlanned      
 AND (ld.PlannedTrackingLevel = 2       
  OR ld.PlannedTrackingLevel = 3 )      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET PlannedStops = ValueINT,      
  PlannedDTInSec = ValueFLOAT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
-- c. UnPlannedStops and UnPlannedDTInSec      
--  Business Rule for UnPlanned Downtime:      
--  All DT event records where DTSched = UnPlanned or is NULL       
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  ,      
   ValueFLOAT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount),      
  SUM(LEDSDurationInSecForRpt)      
FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE ld.CATDTSched = @vchCatLEDSUnPlanned      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET UnPlannedStops = ValueINT,      
  UnPlannedDTInSec = ValueFLOAT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
-- d. SupplyStops and SupplyDTInSec      
--  Business Rule      
--  Unplanned Stops where DTMach = Supply      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1 INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  ,      
   ValueFLOAT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount),      
  SUM(LEDSDurationInSecForRpt)      
FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE CATDTMach = @vchCatDTMachSupply      
AND CaTDTSched =  @vchCatLEDSUnplanned      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET SupplyStops = ValueINT,      
  SupplyDTInSec = ValueFLOAT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
-- e. InternalStops and InternalDTInSec      
--  Business Rule:      
--  Internal Stops = DTEvents where DTSched = Unplanned or NULL and DTMach = Internal Or NULL      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  ,      
   ValueFLOAT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount),      
  SUM(LEDSDurationInSecForRpt)      
FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE CATDTMach = @vchCatDTMachInternal      
 AND CaTDTSched =  @vchCatLEDSUnplanned      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET InternalStops = ValueINT,      
  InternalDTInSec = ValueFLOAT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
-- For minor stops and process failures we need to use and intermediate table, the WHERE clause does not work      
--  properly with <> when the value is NULL      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempStops      
INSERT INTO @tblTempStops(        
   MajorGroupId   ,      
   PLId     ,      
   PUId     ,      
   ConstraintOrder   ,      
   LEDSCount    ,       
   LEDSDurationInSecForRpt ,      
   CATDTClass    )      
SELECT MajorGroupId ,      
 PLId   ,      
  PUId   ,      
  ConstraintOrder ,      
  LEDSCount  ,      
  LEDSDurationInSecForRpt,      
  CATDTClass      
FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE CATDTMach = @vchCatDTMachInternal      
 AND CATDTSched = @vchCatLEDSUnplanned      
---------------------------------------------------------------------------------------------------------------      
-- Delete any records where DTClass = Breakdown      
---------------------------------------------------------------------------------------------------------------      
DELETE @tblTempStops      
WHERE CATDTClass = @vchCatDTClassBreakdown      
-----------------------------------------------------------------------------------------------------------------------      
-- f. MinorStops      
--  Business Rule:      
--  Internal Stops where duration <= 10 minutes      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount)      
FROM @tblTempStops       
WHERE LEDSDurationInSecForRpt <= 600      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET MinorStops = ValueINT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
-- g. ProcessFailure      
--  Business Rule:      
--  Internal Stops where duration > 10 minutes      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount)      
FROM @tblTempStops      
WHERE LEDSDurationInSecForRpt > 600      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET ProcessFailures = ValueINT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
--  h. Breakdowns      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount)      
FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE CATDTClass = @vchCatDTClassBreakdown      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET Breakdowns = ValueINT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
--  i. Blocked stops      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempValues1      
INSERT INTO @tblTempValues1 (      
   MajorGroupId ,      
   PLId   ,      
   PUId   ,      
   ValueINT  )      
SELECT MajorGroupId,      
  PLId,      
  PUId,      
  SUM(LEDSCount)      
FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
WHERE CATDTMach = @vchCatDTMachBlocked      
AND CaTDTSched =  @vchCatLEDSUnplanned      
GROUP BY MajorGroupId, PLId, PUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE @tblLineDowntimeMeasures      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET BlockedStops = ValueINT      
FROM @tblLineDowntimeMeasures ldm      
 JOIN @tblTempValues1 tv ON ldm.MajorGroupId = tv.MajorGroupId      
         AND ldm.PLId = tv.PLId      
         AND ldm.PUId = tv.PUId      
-----------------------------------------------------------------------------------------------------------------------      
-- j. MTBF      
--  Business Rule (Machine (PUID)):      
--  Constraint MTBF: Total UpTime for the Constraint Machine / Total Number of Unplanned Stops for the Constraint      
--  Machine MTBF:  Uptime for the machine / Total number of Internal and Supply stops for the machine      
--  WHERE:      
--  Internal Stops  = DT Events where DTSched = Unplanned or NULL and DTMach = Internal or NULL      
--  Supply Stops  = DT Events where DTSched = Unplanned or NULL and DTMach = Supply      
--  Unplanned Stops = DT Events where DTSched = Unplanned       
-----------------------------------------------------------------------------------------------------------------------      
-- Constraint Machine      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblLineDowntimeMeasures      
 SET MTBFDenominator = COALESCE(UnPlannedStops, 0)      
WHERE ConstraintOrder > 0      
-----------------------------------------------------------------------------------------------------------------------      
-- Non-Constraint Machine      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblLineDowntimeMeasures      
 SET MTBFDenominator = COALESCE(InternalStops, 0) + COALESCE(SupplyStops, 0)      
WHERE ConstraintOrder = 0      
-----------------------------------------------------------------------------------------------------------------------      
-- Calculate MTBF      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET MTBFInSec = (UpTimeInSec / MTBFDenominator)       
FROM @tblLineDowntimeMeasures ldm      
WHERE MTBFDenominator > 0      
-----------------------------------------------------------------------------------------------------------------------      
-- k. MTTR for a machine      
--  Business Rule:      
--  If PU is a constraint unit      
--  MTTR = Total Unplanned downtime for the constraint machine / Number of unplanned stops for the constraint       
--  ELSE      
--  MTTR = Total Internal downtime / Number of Internal stops       
-----------------------------------------------------------------------------------------------------------------------      
-- MTTR for other Machines      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET MTTRInSec = (InternalDTInSec / InternalStops)       
FROM @tblLineDowntimeMeasures ldm      
WHERE InternalStops > 0      
-----------------------------------------------------------------------------------------------------------------------      
-- MTTR for constrain machine      
-- Note: had to calculate the MTTRInSec for all machines first and then nullify the one for constrain = 1 because       
-- the statements WHERE Constraint <> 1 did not work when the constraint field is NULL      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET MTTRInSec = NULL      
FROM @tblLineDowntimeMeasures ldm      
WHERE ConstraintOrder > 0    ----TCS Helpdesk ---Changed ConstraintOrder =1  to ConstraintOrder =0 on 20th Sept 2011  
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ldm      
 SET MTTRInSec = (UnPlannedDTInSec / UnPlannedStops)       
FROM @tblLineDowntimeMeasures ldm      
WHERE ConstraintOrder > 0    ---TCS Helpdesk ---Changed ConstraintOrder >1  to ConstraintOrder > 0 on 20th Sept 2011  
 AND UnPlannedStops > 0      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET PRODUCTION RAW DATA'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- PRODUCTION RAW DATA      
-- Loop throug production line list and call fnLocal_LEDS_ProductionRawData      
--=====================================================================================================================      
-- Call Production Raw Data funciotn       
-----------------------------------------------------------------------------------------------------------------------      
-- Initialize Variables      
-----------------------------------------------------------------------------------------------------------------------      

SELECT   @intMaxPLIdx = COUNT(1),      

   @intMinPLIdx = MIN(RcdIdx),      
   @i      = 1 ,      
   @vchStartTime =  CONVERT(VARCHAR(25), @dtmRptStartTime, 120),      
   @vchEndTime =  CONVERT(VARCHAR(25), @dtmRptEndTime, 120)      
FROM #FilterProductionLines      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @i <= @intMaxPLIdx      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- RETRIEVE production line      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPLId = PlId      
 FROM #FilterProductionLines       
 WHERE RcdIdx = @i      
 -------------------------------------------------------------------------------------------------------------------      
 -- INSERT data      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO #ProductionRawData (      
    PLId       ,      
    EventId       ,      
    EventPUId       ,      
    EventProductionDayId   ,      
    EventNumber      ,      
    EventStart       ,      
    EventEnd       ,      
    EventStartForRpt     ,      
    EventEndForRpt      ,      
    EventProductionTimeInSec  ,      
    EventProductionTimeInSecForRpt ,      
    EventProdId      ,      
    EventPSProdId     ,      
    EventAppliedProdId    ,      
    EventShift      ,      
    EventTeam      ,      
    EventProductionDay    ,          
    EventProductionStatusVarId  ,      
    EventProductionStatus   ,      
    EventAdjustedCasesVarId   ,      
    EventAdjustedCases    ,     
    EventStatCaseConvFactorVarId ,      
    EventStatCaseConvFactor   ,      
    EventAdjustedUnitsVarId   ,      
    EventAdjustedUnits    ,      
    EventUnitsPerCaseVarId   ,      
    EventUnitsPerCase    ,      
    EventTargetRateVarId   ,      
    EventTargetRatePerMin   ,      
    EventActualRateVarId   ,      
    EventActualRatePerMin   ,      
    EventScheduledTimeVarId   ,      
    EventScheduledTimeInSec   ,      
    EventIdealRateVarId    ,      
    EventIdealRatePerMin   ,      
    EventSplitFactor    ,      
    EventSplitFlag     ,      
    EventSplitShiftFlag    , -- Flags events split at shift boundaries      
    EventSplitProductionDayFlag  , -- Flags events split at production day boundaries      
    ErrorCode       ,      
    Error        )       
 SELECT   PLId       ,      
    EventId       ,      
    EventPUId       ,      
    EventProductionDayId   ,      
    EventNumber      ,      
    EventStart       ,      
    EventEnd       ,      
    EventStartForRpt     ,      
    EventEndForRpt      ,      
    EventProductionTimeInSec  ,      
    EventProductionTimeInSecForRpt ,      
    EventProdId      ,      
    EventPSProdId     ,      
    EventAppliedProdId    ,      
    EventShift      ,      
    EventTeam      ,      
    EventProductionDay    ,      
    EventProductionStatusVarId  ,      
    EventProductionStatus   ,      
    EventAdjustedCasesVarId   ,      
    EventAdjustedCases    ,      
    EventStatCaseConvFactorVarId ,      
    EventStatCaseConvFactor   ,      
    EventAdjustedUnitsVarId   ,      
    EventAdjustedUnits    ,      
    EventUnitsPerCaseVarId   ,      
    EventUnitsPerCase    ,      
    EventTargetRateVarId   ,      
    EventTargetRatePerMin   ,      
    EventActualRateVarId   ,      
    EventActualRatePerMin   ,      
    EventScheduledTimeVarId   ,      
    EventScheduledTimeInSec   ,      
    EventIdealRateVarId    ,      
    EventIdealRatePerMin   ,      
    EventSplitFactor    ,      
    EventSplitFlag     ,      
    EventSplitShiftFlag    , -- Flags events split at shift boundaries      
    EventSplitProductionDayFlag  , -- Flags events split at production day boundaries      
    ErrorCode       ,      
    Error               
 FROM dbo.fnLocal_LEDS_ProductionRawData_12_PR ( @intPLId, @vchStartTime, @vchEndTime, @intRptSplitRecords, @intIncludeShiftProduction, @intIncludeProductionDay) -- these two last parameters will be change to variables when we add support for shift and production day      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREASE LOOP VARIABLE      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @i + 1      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- GET the constrain PUId that corresponds to the virtual production unit      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #ProductionRawData      
 SET ProductionCountPUId = fpu.PUId,      
  ConstraintOrder = fpu.ConstraintOrder      
FROM #ProductionRawData prd      
 JOIN #FilterProductionUnits fpu ON prd.EventPUId = fpu.VirtualProductionCountPUId      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Apply Filters'      
--=====================================================================================================================      
-- Production Line Status      
-----------------------------------------------------------------------------------------------------------------------      
IF EXISTS ( SELECT  PLStatusDesc      
   FROM  #FilterProductionLineStatus)      
BEGIN      
 DELETE #ProductionRawData      
 WHERE EventProductionStatus NOT IN  ( SELECT  PLStatusDesc      
           FROM  #FilterProductionLineStatus)      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ASSIGN major and minor groups to Production Raw Data'      
--=====================================================================================================================      
-- ASSIGN major and minor groups to Production Raw Data      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ld       
 SET MajorGroupId = mgl.MajorGroupId      
FROM #ProductionRawData ld       
 JOIN #MajorGroupList mgl ON ld.PLId = mgl.PLId      
-----------------------------------------------------------------------------------------------------------------------      
-- UPDATE ProdCode and ProdDesc      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE #ProductionRawData      
 SET EventProdCode = p.Prod_Code,      
  EventProdDesc = p.Prod_Desc      
FROM #ProductionRawData prd      
 JOIN dbo.Products p WITH (NOLOCK)      
        ON p.Prod_Id = prd.EventProdId       
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET CONSTRAINT UNIT(S) AGGREGATES'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- This section of code gets the intermediate values for the KPI(s) in the PRODUCTION MEASURES section of the report      
-- The purpose of this table is to summarize the intermediate values in one place and help troubleshoot the values of      
-- the KPI(s)      
-- The KPS(s) are:      
-- Process Reliability      
-- Equipment Reliability      
-- Run Efficiency      
-- All data needs to be aggregated by constraint unit for roll-up      
-----------------------------------------------------------------------------------------------------------------------      
-- Get Normal Production in Stat Units and Schedule Time      
-----------------------------------------------------------------------------------------------------------------------      
INSERT INTO @tblProductionAggregates (      
   MajorGroupId    ,      
   MinorGroupId    ,      
   PLId      ,      
   ProductionCountPUId    ,      
   ConstraintOrder    ,      
   NormalProdStatUnits   ,      
   NormalProdScheduleTimeInSec )      
SELECT MajorGroupId  ,      
  MinorGroupId  ,      
  PLId    ,      
  ProductionCountPUId  ,      
  ConstraintOrder  ,      
  SUM(EventAdjustedCases * EventStatCaseConvFactor),      
  SUM(EventProductionTimeInSecForRpt)       
FROM #ProductionRawData      
WHERE EventScheduledTimeInSec > 0.0      
GROUP BY MajorGroupId, MinorGroupId, PLId, ProductionCountPUId, ConstraintOrder      
-----------------------------------------------------------------------------------------------------------------------      
-- GET Normal Production in Adjusted Units / Target Rate      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempAggregates       
INSERT INTO @tblTempAggregates (      
   MajorGroupId,      
   MinorGroupId,      
   PUId ,      
   VALUE )      
SELECT MajorGroupId,      
  MinorGroupId,      
  ProductionCountPUId,      
  SUM(EventAdjustedUnits / EventTargetRatePerMin)      
FROM #ProductionRawData      
WHERE EventScheduledTimeInSec > 0.0      
 AND EventTargetRatePerMin > 0.0      
GROUP BY MajorGroupId, MinorGroupId, ProductionCountPUId      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblProductionAggregates       
 SET NormalProdAdjustedUnitsPerTargetRate = Value      
FROM @tblProductionAggregates ca      
 JOIN @tblTempAggregates ta ON ta.MajorGroupId = ca.MajorGroupId      
          AND ta.PUId = ca.ProductionCountPUId      
-----------------------------------------------------------------------------------------------------------------------      
-- GET Downtime Planned In Sec for the constraint units      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempAggregates       
INSERT INTO @tblTempAggregates (      
   MajorGroupId,      
   MinorGroupId,      
   PUId ,      
   VALUE )      
SELECT ld.MajorGroupId,      
  ld.MinorGroupId,      
  ld.PUId,      
  SUM(ld.LEDSDurationInSecForRpt)      
FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
 JOIN @tblProductionAggregates pa ON ld.PUId = pa.ProductionCountPUId      
WHERE CATDTSched = @vchCatLEDSPlanned      
GROUP BY ld.MajorGroupId, ld.MinorGroupId, ld.PUId      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblProductionAggregates       
 SET DowntimePlannedInSec = Value      
FROM @tblProductionAggregates ca      
 JOIN @tblTempAggregates ta ON ta.PUId = ca.ProductionCountPUId      
-----------------------------------------------------------------------------------------------------------------------      
-- GET Downtime STNU in Sec for the constraint units      
-----------------------------------------------------------------------------------------------------------------------      
DELETE @tblTempAggregates       
INSERT INTO @tblTempAggregates (      
   MajorGroupId,      
   MinorGroupId,      
   PUId ,      
   VALUE )      
SELECT ld.MajorGroupId,      
  ld.MinorGroupId,      
  ld.PUId,      
  SUM(ld.LEDSDurationInSecForRpt)      
FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
 JOIN @tblProductionAggregates pa ON ld.PUId = pa.ProductionCountPUId      
WHERE CATDTSched = @vchCatLEDSSTNU      
GROUP BY ld.MajorGroupId, ld.MinorGroupId, ld.PUId      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE @tblProductionAggregates       
 SET DowntimeSTNUInSec = Value      
FROM @tblProductionAggregates ca      
 JOIN @tblTempAggregates ta ON ta.PUId = ca.ProductionCountPUId      
-----------------------------------------------------------------------------------------------------------------------      
-- CALCULATE constraint PR, ER and RE When Constraint Order = 1      
-- Formulas come from "BHC LEDS Summary Report Production Measures-UPDATE6.xls"      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ca       
 SET MachinePR = NormalProdAdjustedUnitsPerTargetRate / ((NormalProdScheduleTimeInSec) / 60.0)      
FROM @tblProductionAggregates ca      
WHERE ConstraintOrder = 1      
 AND NormalProdScheduleTimeInSec > 0      
-----------------------------------------------------------------------------------------------------------------------      
-- CALCULATE constraint PR, ER and RE When Constraint Order <> 1      
-- Formulas come from "BHC LEDS Summary Report Production Measures-UPDATE6.xls"      
-----------------------------------------------------------------------------------------------------------------------      
UPDATE ca       
 SET MachinePR = NormalProdAdjustedUnitsPerTargetRate / ((NormalProdScheduleTimeInSec) / 60.0)      
FROM @tblProductionAggregates ca      
WHERE ConstraintOrder <> 1      
 AND NormalProdScheduleTimeInSec > 0      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' REPORT PERIOD PRODUCTION SUMMARY'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- REPORT PERIOD PRODUCTION SUMMARY      
-- a. Line Total      
--  Calculate Line PR      
-- b. Constrain Unit Total      
--  Calculate Constraint Unit PR      
-- c. Shift Total        
--  Calculate Shift PR      
-- d. Shift Details      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET PLId that corresponds to the Major Group      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPLId = PLId      
 FROM #MajorGroupList      
 WHERE MajorGroupId = @j      
 --=================================================================================================================      
 -- a. Line Total      
 --=================================================================================================================      
 INSERT INTO @tblSection1 (      
    MajorGroupId,      
    Col0,      
    Col7, -- ScheduleTime      
    Col8, -- TargetUnits      
    Col9, -- TargetCases      
    Col10, -- TotalUnits       
    Col11, -- TotalCases      
    Col12, -- NetProduction      
    Col13, -- PR      
    NameStyle)      
 SELECT MajorGroupId,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   NULL,      
   SUM(EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)),      
   SUM((EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)) / EventUnitsPerCase),      
   SUM(EventAdjustedUnits),      
   SUM(EventAdjustedCases),      
   SUM(EventAdjustedCases * EventStatCaseConvFactor),      
   NULL,       
   @constRptStyleOverallTotal      
 FROM #ProductionRawData prd      
  JOIN dbo.Prod_Lines pl WITH (NOLOCK)      
         ON pl.PL_Id = prd.PLId      
 WHERE EventScheduledTimeInSec > 0.0      
  AND MajorGroupId = @j      
  AND EventUnitsPerCase > 0      
  AND ProductionCountPUId > 0  -- 1.50      
 GROUP BY MajorGroupId, prd.PLId, pl.PL_Desc      
 -------------------------------------------------------------------------------------------------------------------      
 --  GET the record index of the record that was just inserted      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intRcdIdx = MAX(RcdIdx)      
 FROM  @tblSection1      
 -------------------------------------------------------------------------------------------------------------------      
 -- Schedule Time      
 -- Business Rule:       
 -- For a line Sum of the Event Production Time for the report where line status = Normal Production      
 -- and constraint order = 1      
 -- For a Prod Unit Sum of the Event Production Time for the report where line status = Normal Production      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intScheduleTimeInSec = NULL      
 SELECT @intScheduleTimeInSec = SUM(EventProductionTimeInSecForRpt)      
 FROM #ProductionRawData WITH (INDEX (ProdRawDataMajorProdStatus_Idx))      
 WHERE EventScheduledTimeInSec > 0.0          
  AND MajorGroupId = @j        
 -------------------------------------------------------------------------------------------------------------------      
 --  Calculate Line PR      
 -------------------------------------------------------------------------------------------------------------------       
 SELECT @fltEquipmentReliability = NULL      
 -------------------------------------------------------------------------------------------------------------------       
 SELECT @fltMachinePR = MachinePR      
 FROM @tblProductionAggregates      
 WHERE  MajorGroupId = @j       
 -------------------------------------------------------------------------------------------------------------------       
 IF @fltMachinePR > 0      
 BEGIN      
  SELECT @fltEquipmentReliability = SUM(NormalProdStatUnits) /      
           (SUM(NormalProdStatUnits/MachinePR))                  
  FROM @tblProductionAggregates      
  WHERE  MajorGroupId = @j      
   AND NormalProdStatUnits > 0      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Add pr to section 1 result set      
 -------------------------------------------------------------------------------------------------------------------      
 UPDATE @tblSection1      
  SET Col7 = @intScheduleTimeInSec / 60.0,      
   Col13  = @fltEquipmentReliability * 100.0      
 WHERE  RcdIdx =  @intRcdIdx      
 --=================================================================================================================      
 -- b. Production Unit Total      
 --  INITIALIZE variables      
 --=================================================================================================================      
 --  Get the list of production units      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 INSERT INTO @tblTempValues1 (      
    MajorGroupId ,      
    PLId   ,      
    PUId   )      
 SELECT @j,      
   PLId,      
   PUId      
 FROM #FilterProductionUnits pu      
 WHERE pu.VirtualProductionCountPUId > 0      
  AND PLId = @intPLId      
 ORDER BY pu.RcdIdx      
 -------------------------------------------------------------------------------------------------------------------      
 --  INITIALIZE variables      
 --  GET the MIN constraint order and the MAX constraint order of the constraint PU's      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intPLId   = PLId,      
   @intMINRcdIdx = MIN(RcdIdx),      
   @intMAXRcdIdx = MAX(RcdIdx)      
 FROM @tblTempValues1      
 GROUP BY PLId      
 -------------------------------------------------------------------------------------------------------------------      
 --  LOOP through the constraint units      
 -------------------------------------------------------------------------------------------------------------------      
 SET @r = @intMINRcdIdx      
 WHILE @r <= @intMAXRcdIdx      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get the PUId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intPUId = PUId      
  FROM @tblTempValues1      
  WHERE RcdIdx = @r      
---------------------------------------------------------------------------------------------------------------      
  -- GET constraint unit total      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection1 (      
     MajorGroupId,      
     PUId,      
     Col0,      
     Col7, -- ScheduleTime      
     Col8, -- TargetUnits      
     Col9, -- TargetCases      
     Col10, -- TotalUnits       
     Col11, -- TotalCases      
     Col12, -- NetProduction      
     Col13, -- PR      
     NameStyle)      
  SELECT MajorGroupId,      
    prd.ProductionCountPUId,      
    pu.PU_Desc,      
    SUM(EventProductionTimeInSecForRpt) / 60.0,       
    SUM(EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)),      
    SUM((EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)) / EventUnitsPerCase),      
    SUM(EventAdjustedUnits),      
    SUM(EventAdjustedCases),      
    SUM(EventAdjustedCases * EventStatCaseConvFactor),      
    NULL,       
    @constRptStyleTotal      
  FROM #ProductionRawData prd      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)      
          ON pu.PU_Id = prd.ProductionCountPUId      
  WHERE EventScheduledTimeInSec > 0.0      
   AND MajorGroupId = @j      
   AND prd.ProductionCountPUId = @intPUId      
   AND EventUnitsPerCase > 0      
   AND ProductionCountPUId > 0  -- 1.50      
  GROUP BY MajorGroupId, prd.ProductionCountPUId, pu.PU_Desc      
  ---------------------------------------------------------------------------------------------------------------      
  --  GET the record index of the record that was just inserted      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intRcdIdx = MAX(RcdIdx)      
  FROM  @tblSection1      
  ---------------------------------------------------------------------------------------------------------------      
  -- Calculate process reliability for the constraint unit      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @fltEquipmentReliability = NULL        
  -------------------------------------------------------------------------------------------------------------------       
  SELECT @fltEquipmentReliability = SUM(NormalProdStatUnits) /      
           (SUM(NormalProdStatUnits/MachinePR))      
  FROM @tblProductionAggregates      
  WHERE  MajorGroupId = @j      
   AND ProductionCountPUId = @intPUId      
   AND NormalProdStatUnits > 0      
   AND MachinePR > 0      
  GROUP BY MajorGroupId, ProductionCountPUId      
  ---------------------------------------------------------------------------------------------------------------      
  -- Add pr to section 1 result set      
  ---------------------------------------------------------------------------------------------------------------      
  UPDATE @tblSection1      
   SET Col13 = @fltEquipmentReliability * 100.0      
  WHERE  RcdIdx = @intRcdIdx        
  ---------------------------------------------------------------------------------------------------------------      
  -- Get the list of shifts      
  ---------------------------------------------------------------------------------------------------------------      
  IF @intRptShowShift = 1      
  BEGIN      
   DELETE @tblShiftList       
   INSERT INTO @tblShiftList (      
      Shift)       
   SELECT DISTINCT       
     EventShift      
   FROM #ProductionRawData      
   WHERE ProductionCountPUId = @intPUId      
   -----------------------------------------------------------------------------------------------------------      
   -- Initialize variables      
   -----------------------------------------------------------------------------------------------------------      
   SELECT @k = MIN(RcdIdx),      
     @intMaxShiftRcdIdx = MAX(RcdIdx)      
   FROM @tblShiftList      
   -----------------------------------------------------------------------------------------------------------      
   -- Loop through the shifts and get the shift total      
   -----------------------------------------------------------------------------------------------------------      
   WHILE @k <= @intMaxShiftRcdIdx      
   BEGIN      
    -------------------------------------------------------------------------------------------------------      
    -- Get shift      
    -------------------------------------------------------------------------------------------------------      
    SELECT @vchShift = Shift      
    FROM @tblShiftList      
    WHERE RcdIdx = @k      
    --=====================================================================================================      
    -- c. Shift Total      
    --=====================================================================================================      
    INSERT INTO @tblSection1 (      
       MajorGroupId,      
       Col0,      
       Col7, -- ScheduleTime      
       Col8, -- TargetUnits      
       Col9, -- TargetCases      
       Col10, -- TotalUnits       
       Col11, -- TotalCases      
       Col12, -- NetProduction      
       Col13, -- PR      
       NameStyle)      
    SELECT DISTINCT      
      MajorGroupId,      
      prd.EventShift,      
      SUM(EventProductionTimeInSecForRpt) / 60.0,       
      SUM(EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)),      
      SUM((EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)) / EventUnitsPerCase),      
      SUM(EventAdjustedUnits),      
      SUM(EventAdjustedCases),      
      SUM(EventAdjustedCases * EventStatCaseConvFactor),      
      (SUM(EventAdjustedUnits / EventTargetRatePerMin) / (SUM(EventProductionTimeInSecForRpt) / 60.0)) * 100.0,       
      @constRptStyleSubTotal      
    FROM #ProductionRawData prd      
     JOIN dbo.Prod_Units pu WITH (NOLOCK)      
            ON pu.PU_Id = prd.ProductionCountPUId      
    WHERE EventScheduledTimeInSec > 0.0      
     AND MajorGroupId = @j      
     AND ProductionCountPUId = @intPUId      
     AND EventShift =  @vchShift      
     AND EventUnitsPerCase > 0      
     AND ProductionCountPUId > 0  -- 1.50      
     AND EventTargetRatePerMin > 0.0 --1.50      
    GROUP BY MajorGroupId, prd.ProductionCountPUId, prd.EventShift       
    --=====================================================================================================      
    -- d. Shift Details      
    --=====================================================================================================      
     INSERT INTO @tblSection1 (      
        MajorGroupId,      
        Col0, -- Shift      
       Col1, -- Team      
       Col2, -- StartTime      
       Col3, -- ProductionStatus      
       Col4, -- ProductCode      
       Col5, -- ProductDesc      
       Col6, -- TargetRate      
        Col7, -- ScheduleTime      
        Col8, -- TargetUnits      
        Col9, -- TargetCases      
        Col10, -- TotalUnits       
        Col11, -- TotalCases      
        Col12, -- NetProduction      
        Col13, -- PR      
        NameStyle)      
     SELECT MajorGroupId,      
      NULL,       
      EventTeam,       
      EventStart,       
      EventProductionStatus,      
      EventProdCode,      
      EventProdDesc,      
      EventTargetRatePerMin,      
       (EventProductionTimeInSecForRpt / 60.0),       
       (EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0)),      
       CASE WHEN EventUnitsPerCase > 0      
        THEN (EventTargetRatePerMin * (EventProductionTimeInSecForRpt / 60.0) / EventUnitsPerCase)      
        ELSE NULL      
        END,      
       EventAdjustedUnits,      
       EventAdjustedCases,      
       (EventAdjustedCases * EventStatCaseConvFactor),      
       CASE WHEN EventProductionTimeInSecForRpt > 0      
        THEN ((EventAdjustedUnits / EventTargetRatePerMin) / (EventProductionTimeInSecForRpt / 60.0)) * 100.0      
        ELSE NULL      
        END,       
       @constRptStyleDetails      
     FROM #ProductionRawData prd      
      JOIN dbo.Prod_Units pu WITH (NOLOCK)      
             ON pu.PU_Id = prd.ProductionCountPUId      
     WHERE EventScheduledTimeInSec > 0.0      
      AND MajorGroupId = @j      
     AND EventShift  = @vchShift       
     AND ProductionCountPUId = @intPUId     
     AND EventUnitsPerCase > 0       
     AND ProductionCountPUId > 0  -- 1.50      
     AND EventTargetRatePerMin > 0.0  --1.50      
     ORDER BY MajorGroupId, prd.ProductionCountPUId, EventStart              
    -------------------------------------------------------------------------------------------------------      
    -- INCREMENT COUNTER      
    -------------------------------------------------------------------------------------------------------      
    SET @k = @k + 1       
   END       
  END      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @r = @r + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' LINE DOWNTIME SUMMARY MEASURES'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- LINE DOWNTIME SUMMARY MEASURES      
-- a. Line Total      
-- b. Production Unit Total      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. Line Total      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection2 (      
    MajorGroupId,      
    Col0, -- Unit      
    Col2, -- MTBF      
    Col3, -- MTTR      
    Col4, -- Uptime      
    Col5, -- PlannedStops      
    Col6, -- PlannedDowntime      
    Col7, -- SupplyStops      
    Col8, -- SupplyDowntime      
    Col9, -- InternalStops      
    Col10, -- InternalDowntime      
    Col11, -- MinorStops      
    Col12, -- ProcessFailures      
    Col13, -- Breakdowns      
    NameStyle)      
 SELECT MajorGroupId,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   NULL,      
   NULL,      
   NULL,      
   SUM(PlannedStops),      
   SUM(PlannedDTInSec) / 60.0,      
   SUM(SupplyStops),      
   SUM(SupplyDTInSec) / 60.0,      
   SUM(InternalStops),      
   SUM(InternalDTInSec) / 60.0,      
   SUM(MinorStops),      
   SUM(ProcessFailures),      
   SUM(Breakdowns),      
   @constRptStyleTotal      
 FROM @tblLineDowntimeMeasures ldm      
  JOIN dbo.Prod_Lines pl ON pl.PL_Id = ldm.PLId      
 WHERE MajorGroupId = @j      
 GROUP BY MajorGroupId, pl.PL_Desc      
 --=================================================================================================================      
 -- Get UpTime for the line      
 -- Business Rule:      
 -- Uptime for line = Uptime for contraint unit where constraint order >= 1      
 -------------------------------------------------------------------------------------------------------------------       
 --SET @SumUpTime = (SELECT rdp.Value
 --   FROM dbo.Report_Parameters rp WITH (NOLOCK)
 --   JOIN dbo.Report_Type_Parameters rtp WITH (NOLOCK)
 --   ON rp.RP_Id=rtp.RP_Id
 --   JOIN dbo.Report_Definition_Parameters rdp WITH (NOLOCK)
 --   ON rdp.RTP_Id=rtp.RTP_Id
 --   WHERE rp.RP_Name='SumParallelConstraintUnitsUpTime'
 --   AND rdp.Report_Id =@p_intRptId) 

SELECT @SumUpTime = Value      
 FROM @tblReportParameters      
 WHERE RPName = 'SumParallelConstraintUnitsUpTime'

IF @SumUpTime = 1  --Site wants to calculate Total UpTime as SUM of the Uptimes of parallel constraints units (FO-03039)
 BEGIN
 IF EXISTS(SELECT  * FROM #LedsDetails where ParallelUnit = 1 and  MajorGroupId = @j)
 BEGIN
  DELETE @tblTempAggregates       
  INSERT INTO @tblTempAggregates (      
    MajorGroupId,      
    VALUE)      
  SELECT MajorGroupId,      
  SUM(COALESCE(UpTimeInSec,0))      
  FROM @tblLineDowntimeMeasures      
  WHERE MajorGroupId = @j      
  AND ConstraintOrder >= 1      
  GROUP BY MajorGroupId
 END
 ELSE
 BEGIN
  DELETE @tblTempAggregates       
  INSERT INTO @tblTempAggregates (      
    MajorGroupId,      
    VALUE)      
  SELECT MajorGroupId,      
   MAX(UpTimeInSec)      
  FROM @tblLineDowntimeMeasures      
  WHERE MajorGroupId = @j      
  AND ConstraintOrder >= 1      
  GROUP BY MajorGroupId
 END
END

ELSE  --Site wants to calculate Total UpTime as MAX value for parallel constraints units
 BEGIN
  DELETE @tblTempAggregates       
  INSERT INTO @tblTempAggregates (      
    MajorGroupId,      
    VALUE)      
  SELECT MajorGroupId,      
   MAX(UpTimeInSec)      
  FROM @tblLineDowntimeMeasures      
  WHERE MajorGroupId = @j      
  AND ConstraintOrder >= 1      
  GROUP BY MajorGroupId
END     
 -------------------------------------------------------------------------------------------------------------------       
 -- Add Uptime to section 2      
 -------------------------------------------------------------------------------------------------------------------        
 UPDATE @tblSection2      
  SET Col4 = VALUE / 60.0      
 FROM @tblSection2 s2      
  JOIN @tblTempAggregates ta ON s2.MajorGroupId = ta.MajorGroupId      
 --=================================================================================================================      
 -- GET MTBF for the line      
 -- Business Rule:      
 -- SUM(Uptime for the Constraint Units)/      
 -- (SUM(Internal Stops) + SUM(Supply Stops) for all machines on the line) + SUM(Blocked Stops on Last Machine)      
 --=================================================================================================================      
 -- GET Uptime for constraint machine      
 --   There are three different Line Configurations to take into consideration:      
 --  1. single constraint line      
 --  2. Multiple constraint  line with constraint units in serial      
 --   3. Multiple constraint  line with constraint units in parallel      
 -------------------------------------------------------------------------------------------------------------------      
 -- Configurations 1 and 2      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intUptimeInSec = UpTimeInSec      
 FROM @tblLineDowntimeMeasures      
 WHERE MajorGroupId = @j      
  AND ConstraintOrder = 1      
 -------------------------------------------------------------------------------------------------------------------      
 -- Configuration 3      
 -------------------------------------------------------------------------------------------------------------------      
 IF EXISTS(SELECT  * FROM #LedsDetails where ParallelUnit = 1 and  MajorGroupId = @j)      
 BEGIN      
  SELECT @intUptimeInSec = SUM(COALESCE(UpTimeInSec,0))  --1.50      
  FROM @tblLineDowntimeMeasures      
  WHERE MajorGroupId = @j      
   AND ConstraintOrder >= 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET sum of internal stops and supply stops for all machines      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intInternalPlusSupplyStops = SUM(COALESCE(InternalStops, 0)) + SUM(COALESCE(SupplyStops, 0))      
 FROM @tblLineDowntimeMeasures      
 WHERE MajorGroupId = @j      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET sum of blocked stops for last machine      
 -------------------------------------------------------------------------------------------------------------------       
 SELECT @intBlockedStops = SUM(COALESCE(BlockedStops, 0))      
 FROM @tblLineDowntimeMeasures      
 WHERE LastMachine = 1      
  AND MajorGroupId = @j      
 -------------------------------------------------------------------------------------------------------------------      
 -- Calculate MTBF      
 -- Note: had to put a COALESCE to prevent one of the variables to be NULL when there are not stops      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intInternalPlusSupplyStops = COALESCE(@intInternalPlusSupplyStops, 0)      
 SELECT @intBlockedStops = COALESCE(@intBlockedStops, 0)      
 -------------------------------------------------------------------------------------------------------------------      
 IF (@intInternalPlusSupplyStops + @intBlockedStops) > 0      
 BEGIN      
  UPDATE @tblSection2      
   SET Col2 = (@intUptimeInSec / 60.0) / ((@intInternalPlusSupplyStops + @intBlockedStops) * 1.0)      
  FROM @tblSection2 s2      
  WHERE s2.MajorGroupId = @j      
 END      
 --=================================================================================================================      
      
 -- GET MTTR for the line      
 -- Business Rule:      
 -- Total Internal + Supply Downtime  /       
 -- Number of Internal + Supply Stops   (updated in version 1.50)      
 --=================================================================================================================      
 -------------------------------------------------------------------------------------------------------------------      
 -- GET sum of internal and supply Downtime for all machines      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intInternalPlusSupplyDowntime = SUM(COALESCE(InternalDTInSec, 0)) + SUM(COALESCE(SupplyDTInSec, 0))      
 FROM @tblLineDowntimeMeasures      
 WHERE MajorGroupId = @j      
 SELECT @intInternalPlusSupplyDowntime = COALESCE(@intInternalPlusSupplyDowntime, 0)      
 -------------------------------------------------------------------------------------------------------------------      
 -- Calculate MTTR      
 -------------------------------------------------------------------------------------------------------------------      
 IF @intInternalPlusSupplyStops > 0      
 BEGIN      
  DELETE @tblTempAggregates       
  INSERT INTO @tblTempAggregates (      
     MajorGroupId,      
     VALUE)      
  SELECT MajorGroupId,      
    (@intInternalPlusSupplyDowntime / @intInternalPlusSupplyStops) / 60.0  --1.50      
  FROM @tblLineDowntimeMeasures      
  WHERE MajorGroupId = @j      
  --AND  @intInternalPlusSupplyStops > 0      
 -------------------------------------------------------------------------------------------------------------------       
 -- UPDATE MTTR value for section 2      
 -------------------------------------------------------------------------------------------------------------------       
  UPDATE @tblSection2      
   SET Col3 = VALUE      
  FROM @tblSection2 s2      
   JOIN @tblTempAggregates ta ON s2.MajorGroupId = ta.MajorGroupId      
 END      
 --=================================================================================================================      
 -- b. Production Unit Total for constraint units      
 --=================================================================================================================      
 -- Get list of constraint PU's      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 INSERT INTO @tblTempValues1(     
    MajorGroupId ,      
    PUId   )      
  SELECT @j,      
    PUId      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
  AND ConstraintOrder > 0      
 ORDER BY ConstraintOrder ASC      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM @tblTempValues1      
 -------------------------------------------------------------------------------------------------------------------      
 -- Loop throug production units and get pu total and details       
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intPUId = PUId      
  FROM @tblTempValues1      
  WHERE RcdIdx = @i      
  ---------------------------------------------------------------------------------------------------------------      
  -- c. Production Unit Total      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection2 (      
     MajorGroupId,      
     PUId,       
     ConstraintOrder,      
     Col0, -- Unit      
     Col2, -- MTBF      
     Col3, -- MTTR      
     Col4, -- Uptime      
     Col5, -- PlannedStops      
     Col6, -- PlannedDowntime      
     Col7, -- SupplyStops      
     Col8, -- SupplyDowntime      
     Col9, -- InternalStops      
     Col10, -- InternalDowntime      
     Col11, -- MinorStops      
     Col12, -- ProcessFailures      
     Col13, -- Breakdowns      
     NameStyle)      
  SELECT MajorGroupId,      
    pu.PU_Id,      
    ldm.ConstraintOrder,      
    pu.PU_Desc,      
    MTBFInSec / 60.0,      
    MTTRInSec / 60.0,      
    UpTimeInSec / 60.0,      
    PlannedStops,      
    PlannedDTInSec / 60.0,      
    SupplyStops,      
    SupplyDTInSec / 60.0,      
    InternalStops,      
    InternalDTInSec / 60.0,      
    MinorStops,      
    ProcessFailures,      
    Breakdowns,      
    CASE WHEN ConstraintOrder >= 1       
      THEN @constRptStyleSubTotal      
      ELSE @constRptStyleDetails      
      END      
  FROM @tblLineDowntimeMeasures ldm      
   JOIN dbo.Prod_Units pu ON pu.PU_Id = ldm.PUId      
  WHERE ldm.PUId = @intPUId      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 --=================================================================================================================      
 -- c. Production Unit Total for non-constraint units      
 --=================================================================================================================      
 -- Get list of non-constraint PU's      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 INSERT INTO @tblTempValues1 (      
    MajorGroupId ,      
    PUId   )      
  SELECT @j,      
    PUId      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
  AND ConstraintOrder = 0      
 ORDER BY PUDesc ASC      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM @tblTempValues1      
 -------------------------------------------------------------------------------------------------------------------      
 -- Loop throug production units and get pu total and details       
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intPUId = PUId      
  FROM @tblTempValues1      
  WHERE RcdIdx = @i      
  ---------------------------------------------------------------------------------------------------------------      
  -- c. Production Unit Total      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection2 (      
     MajorGroupId,      
     PUId,       
     ConstraintOrder,      
     Col0, -- Unit      
     Col2, -- MTBF      
     Col3, -- MTTR      
     Col4, -- Uptime      
     Col5, -- PlannedStops      
     Col6, -- PlannedDowntime      
     Col7, -- SupplyStops      
     Col8, -- SupplyDowntime      
     Col9, -- InternalStops      
     Col10, -- InternalDowntime      
     Col11, -- MinorStops      
     Col12, -- ProcessFailures      
     Col13, -- Breakdowns      
     NameStyle)      
  SELECT MajorGroupId,      
    pu.PU_Id,      
    ldm.ConstraintOrder,      
    pu.PU_Desc,      
    MTBFInSec / 60.0,      
    MTTRInSec / 60.0,      UpTimeInSec / 60.0,      
    PlannedStops,      
    PlannedDTInSec / 60.0,      
    SupplyStops,      
    SupplyDTInSec / 60.0,      
    InternalStops,      
    InternalDTInSec / 60.0,      
    MinorStops,      
    ProcessFailures,      
    Breakdowns,      
    CASE WHEN ConstraintOrder >= 1       
      THEN @constRptStyleSubTotal      
      ELSE @constRptStyleDetails      
      END      
  FROM @tblLineDowntimeMeasures ldm      
   JOIN dbo.Prod_Units pu ON pu.PU_Id = ldm.PUId      
  WHERE ldm.PUId = @intPUId      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UNPLANNED DOWNTIME SUMMARY BY DTGROUP CATEGORY'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- a. Line Total      
-- b. Line Details grouped by DTGroup Category      
-- c. Production Unit Total      
-- d. Production Unit Details      
--  Business Rule:      
-- Downtime min = SUM(LEDSDurationInSecForRpt) / 60    -- Stops # = SUM(LEDSCount)      
-- Calendar Time % = (SUM(LEDSDurationInSecForRpt) / Report Time) * 100      
-- Schedule Time % = ((SUM(LEDSDurationInSecForRpt)/60.0) / @TotalScheduleTime) * 100  --TCS (FO-00829)      
-----------------------------------------------------------------------------------------------------------------------      
-- INITIALIZE Variables      
-----------------------------------------------------------------------------------------------------------------------      
      
DECLARE @TotalScheduleTime DECIMAL(10,2)  --TCS (FO-00829)      
      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 SET    @TotalScheduleTime = 1  --TCS (FO-00829)      
 SELECT @TotalScheduleTime = Col7 FROM @tblSection1 WHERE MajorGroupID = @j and PUID IS NULL AND Col0 LIKE '%Total%' --TCS (FO-00829)      
      
 -----------------------------------------------------------------------------------------------------------------------      
 -- a. Line Total      
 -----------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection3 (      
    MajorGroupId,      
    Col0,      
    Col11,      
    Col12,      
    Col13,      
    Col14,    --TCS   (FO-00829)      
    NameStyle)      
 SELECT MajorGroupId,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   SUM(LEDSDurationInSecForRpt) / 60.0,      
   SUM(LEDSCount),      
   (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827092),      
   (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827092),   --TCS (FO-00829)      
   @constRptStyleTotal      
 FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
  JOIN dbo.Prod_Lines pl WITH (NOLOCK)      
         ON pl.PL_Id = ld.PLId      
 WHERE CatDTSched = @vchCatLEDSUnplanned      
  AND MajorGroupId = @j      
 GROUP BY MajorGroupId, ld.PLId, pl.PL_Desc      
 -----------------------------------------------------------------------------------------------------------------------      
 -- b. Line Details grouped by DTGroup Category      
 -----------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection3 (      
    MajorGroupId,      
    Col0,      
    Col11,      
    Col12,      
    Col13,      
    Col14,    --TCS (FO-00829)      
    NameStyle)      
 SELECT MajorGroupId,      
   SUBSTRING(CatDTGroup, CHARINDEX('-', CatDTGroup, 1) + 1, LEN(CatDTGroup) + 1),      
   SUM(LEDSDurationInSecForRpt) / 60.0,      
   SUM(LEDSCount),      
   (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827092),      
   (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827092),    --TCS  (FO-00829)      
   @constRptStyleDetails      
 FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
 WHERE CatDTSched = @vchCatLEDSUnplanned      
  AND MajorGroupId = @j      
 GROUP BY MajorGroupId, PLId, CatDTGroup      
 ORDER BY SUM(LEDSCount) DESC --1.50      
 -----------------------------------------------------------------------------------------------------------------------      
 -- GET Totals and details for production units      
 -----------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -----------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
 -----------------------------------------------------------------------------------------------------------------------      
 -- Loop throug production units and get pu total and details for DTGroup      
 -----------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  -------------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  -------------------------------------------------------------------------------------------------------------------       
  SELECT @intPUId = PUId      
  FROM #FilterProductionUnits      
  WHERE RcdIdx = @i      
      
  -------------------------------------------------------------------------------------------------------------------       
  -- c. Production Unit Total      
  -------------------------------------------------------------------------------------------------------------------       
  INSERT INTO @tblSection3 (      
     MajorGroupId,      
     PUId,      
     Col0,      
     Col11,      
     Col12,      
     Col13,      
     Col14,     --TCS (FO-00829)      
     NameStyle)      
  SELECT MajorGroupId,      
    PUId,      
    PU_Desc,      
    SUM(LEDSDurationInSecForRpt) / 60.0,      
    SUM(LEDSCount),      
    STR((   ISNULL(SUM(LEDSDurationInSecForRpt),0) / (@intRptTimeInSec * 1.0)) * 100, 6, 2), --TCS (FO-00829)      
    CASE WHEN @TotalScheduleTime = 1 THEN '0.00' ELSE STR(( ( ISNULL(SUM(LEDSDurationInSecForRpt),0) /60.0) / @TotalScheduleTime ) * 100, 6, 2) END,    --TCS (FO-00829)      
    @constRptStyleTotal      
  FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)      
          ON pu.PU_Id = ld.PUId      
  WHERE CatDTSched = @vchCatLEDSUnplanned      
   AND ld.PUId = @intPUId      
  GROUP BY MajorGroupId, PUId, pu.PU_Desc      
  -------------------------------------------------------------------------------------------------------------------      
  -- d. Production Unit Details      
  -------------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection3 (      
     MajorGroupId,      
     PUId,      
     Col0,      
     Col11,      
     Col12,      
     Col13,      
     Col14,  --TCS (FO-00829)      
     NameStyle)      
  SELECT MajorGroupId,      
    PUId,      
    SUBSTRING(CatDTGroup, CHARINDEX('-', CatDTGroup, 1) + 1, LEN(CatDTGroup) + 1),      
    SUM(LEDSDurationInSecForRpt) / 60.0,      
    SUM(LEDSCount),      
    STR((   ISNULL(SUM(LEDSDurationInSecForRpt),0) / (@intRptTimeInSec * 1.0)) * 100, 6, 2),    --TCS (FO-00829)      
    CASE WHEN @TotalScheduleTime = 1 THEN '0.00' ELSE STR(( ( ISNULL(SUM(LEDSDurationInSecForRpt),0) /60.0) / @TotalScheduleTime ) * 100, 6, 2) END,    --TCS (FO-00829)      
    @constRptStyleDetails      
  FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
  WHERE CatDTSched = @vchCatLEDSUnplanned      
   AND ld.PUId = @intPUId      
  GROUP BY MajorGroupId, PUId, CatDTGroup      
  ORDER BY SUM(LEDSCount) DESC --1.50      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PLANNED DOWNTIME SUMMARY BY DTGROUP CATEGORY'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- a. Line Total      
-- b. Line Details grouped by DTGroup Category      
-- c. Production Unit Total      
-- d. Production Unit Details      
--  Business Rule:      
-- Downtime min = SUM(LEDSDurationInSecForRpt) / 60      
-- Stops # = SUM(LEDSCount)      
-- Calendar Time % = (SUM(LEDSDurationInSecForRpt) / Report Time) * 100      
-- Schedule Time % = ((SUM(LEDSDurationInSecForRpt)/60.0) / @TotalScheduleTime) * 100 --TCS (FO-00829)      
-----------------------------------------------------------------------------------------------------------------------      
-- INITIALIZE Variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 SET    @TotalScheduleTime = 1  --TCS (FO-00829)      
 SELECT @TotalScheduleTime = Col7 FROM @tblSection1 WHERE MajorGroupID = @j and PUID IS NULL AND Col0 LIKE '%Total%' --TCS (FO-00829)      
      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. Line Total      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection4 (      
    MajorGroupId,      
    Col0,      
    Col11,      
    Col12,      
    Col13,      
    Col14,    --TCS (FO-00829)      
    NameStyle)      
 SELECT MajorGroupId,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   SUM(LEDSDurationInSecForRpt) / 60.0,      
   SUM(LEDSCount),      
   (SELECT PromptValue FROM @tblPrompts WHERE  PromptId = 99827092),      
   (SELECT PromptValue FROM @tblPrompts WHERE  PromptId = 99827092),    --TCS (FO-00829)      
   @constRptStyleTotal      
 FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
  JOIN dbo.Prod_Lines pl WITH (NOLOCK)      
         ON pl.PL_Id = ld.PLId      
 WHERE CatDTSched = @vchCatLEDSPlanned      
  AND MajorGroupId = @j      
 GROUP BY MajorGroupId, ld.PLId, pl.PL_Desc      
 -------------------------------------------------------------------------------------------------------------------      
 -- b. Line Details grouped by DTGroup Category      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection4 (      
    MajorGroupId,      
    Col0,      
    Col11,      
    Col12,      
    Col13,      
    Col14,    --TCS (FO-00829)      
    NameStyle)      
 SELECT MajorGroupId,      
   SUBSTRING(CatDTGroup, CHARINDEX('-', CatDTGroup, 1) + 1, LEN(CatDTGroup) + 1),      
   SUM(LEDSDurationInSecForRpt) / 60.0,      
   SUM(LEDSCount),      
   (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827092),      
   (SELECT PromptValue FROM @tblPrompts WHERE  PromptId = 99827092),    --TCS (FO-00829)      
   @constRptStyleDetails      
 FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
 WHERE CatDTSched = @vchCatLEDSPlanned      
  AND MajorGroupId = @j      
 GROUP BY MajorGroupId, PLId, CatDTGroup      
 ORDER BY SUM(LEDSCount) DESC --1.50      
 -----------------------------------------------------------------------------------------------------------------------      
 -- GET Totals and details for production units      
 -----------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -----------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
 -----------------------------------------------------------------------------------------------------------------------      
 -- Loop throug production units and get pu total and details for DTGroup      
 -----------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  -------------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  -------------------------------------------------------------------------------------------------------------------       
  SELECT @intPUId = PUId      
  FROM #FilterProductionUnits      
  WHERE RcdIdx = @i      
      
  -------------------------------------------------------------------------------------------------------------------       
  -- c. Production Unit Total      
  -------------------------------------------------------------------------------------------------------------------       
  INSERT INTO @tblSection4 (      
     MajorGroupId,      
     PUId,      
     Col0,      
     Col11,      
     Col12,      
     Col13,      
     Col14,    --TCS (FO-00829)      
     NameStyle)      
  SELECT MajorGroupId,      
    PUId,      
    PU_Desc,      
    SUM(LEDSDurationInSecForRpt) / 60.0,      
    SUM(LEDSCount),      
    STR((   ISNULL(SUM(LEDSDurationInSecForRpt),0) / (@intRptTimeInSec * 1.0)) * 100, 6, 2), --TCS (FO-00829)      
    CASE WHEN @TotalScheduleTime = 1 THEN '0.00' ELSE STR(( ( ISNULL(SUM(LEDSDurationInSecForRpt),0) /60.0) / @TotalScheduleTime ) * 100, 6, 2) END,    --TCS (FO-00829)      
    @constRptStyleTotal      
  FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)      
          ON pu.PU_Id = ld.PUId      
  WHERE CatDTSched = @vchCatLEDSPlanned      
   AND ld.PUId = @intPUId      
  GROUP BY MajorGroupId, PUId, pu.PU_Desc      
  -------------------------------------------------------------------------------------------------------------------      
  -- d. Production Unit Details      
  -------------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection4 (      
     MajorGroupId,      
     PUId,      
     Col0,      
     Col11,      
     Col12,      
     Col13,      
     Col14,    --TCS (FO-00829)      
     NameStyle)      
  SELECT MajorGroupId,      
    PUId,      
    SUBSTRING(CatDTGroup, CHARINDEX('-', CatDTGroup, 1) + 1, LEN(CatDTGroup) + 1),      
    SUM(LEDSDurationInSecForRpt) / 60.0,      
    SUM(LEDSCount),      
    STR((   ISNULL(SUM(LEDSDurationInSecForRpt),0) / (@intRptTimeInSec * 1.0)) * 100, 6, 2), --TCS (FO-00829)      
    CASE WHEN @TotalScheduleTime = 1 THEN '0.00' ELSE STR(( ( ISNULL(SUM(LEDSDurationInSecForRpt),0) /60.0) / @TotalScheduleTime ) * 100, 6, 2) END,    --TCS (FO-00829)      
    @constRptStyleDetails      
  FROM #LEDSDetails ld WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
  WHERE CatDTSched = @vchCatLEDSPlanned      
   AND ld.PUId = @intPUId      
  GROUP BY MajorGroupId, PUId, CatDTGroup      
  ORDER BY SUM(LEDSCount) DESC --1.50      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' TOP X DOWNTIME SUMMARY BY OCCURRENCE'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- a. GET the aggregated values       
-- b. LOOP through major groups      
-- c. GET Top X values for line      
-- d. GET Top X line total      
-- e. INSERT Top X vales for line      
-- f. GET the aggregated values for a PU       
-- g. LOOP through major group PU's      
-- h. GET Top X values for PU      
-- i. GET Top X PU Total      
-- j. INSERT Top X vales for PU      
-----------------------------------------------------------------------------------------------------------------------      
-- INITIALIZE Variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. GET the aggregated values for a line sorted by occurrence desc      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 IF @intRptReasonTreeLevel = 1      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails       
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 2      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
  ELSE       
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 3      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
 END      
 ELSE       
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,       ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- b. GET Top X vales for line      
 -------------------------------------------------------------------------------------------------------------------      
 TRUNCATE TABLE #TempValues2      
 INSERT INTO  #TempValues2 (      
     MajorGroupId  ,      
     PLId    ,      
     PUId    ,      
     ValueL1VARCHAR100 ,      
     ValueL2VARCHAR100 ,      
     ValueL3VARCHAR100 ,      
     ValueL4VARCHAR100 ,      
     ValueINT   ,      
     ValueFLOAT   )      
 SELECT TOP 15            
    MajorGroupId  ,      
    PLId    ,      
    PUId    ,      
    ValueL1VARCHAR100 ,      
    ValueL2VARCHAR100 ,      
    ValueL3VARCHAR100 ,      
    ValueL4VARCHAR100 ,      
    ValueINT   ,      
    ValueFLOAT         
 FROM @tblTempValues1      
 WHERE MajorGroupId = @j      
 ORDER BY ValueINT DESC      
 -------------------------------------------------------------------------------------------------------------------      
 -- d. GET Top X line total      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection5 (      
    MajorGroupId ,      
    Col0   ,       
    Col11   ,      
    Col12   ,      
    NameStyle  )      
 SELECT MajorGroupId ,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   SUM(ValueFLOAT) ,      
   SUM(ValueINT) ,      
   @constRptStyleTotal      
 FROM #TempValues2 tv2      
  JOIN dbo.Prod_Lines pl WITH (NOLOCK)      
         ON pl.PL_Id = tv2.PLId      
 WHERE RcdIdx <= @intRptTopX      
 GROUP BY tv2.MajorGroupId, tv2.PLId, pl.PL_Desc      
 -------------------------------------------------------------------------------------------------------------------      
 -- e. INSERT Top X vales for line      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection5 (      
    MajorGroupId ,      
    Col0   ,      
    Col2   ,       
    Col4   ,       
    Col6   ,        
    Col11   ,      
    Col12   ,      
    NameStyle  )      
 SELECT MajorGroupId  ,      
   ValueL1VARCHAR100 ,      
   ValueL2VARCHAR100 ,      
   ValueL3VARCHAR100 ,      
   ValueL4VARCHAR100 ,      
   ValueFLOAT   ,      
   ValueINT   ,      
   @constRptStyleDetails      
 FROM #TempValues2 tv2      
 WHERE RcdIdx <= @intRptTopX      
 ORDER BY RcdIdx ASC      
 -------------------------------------------------------------------------------------------------------------------      
 -- f. GET the aggregated values for a PU       
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 IF @intRptReasonTreeLevel = 1      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
  NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 2      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 3      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN    INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
 END      
 ELSE       
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
 -------------------------------------------------------------------------------------------------------------------      
 -- g. LOOP through major group PU's      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intPUId = PUId      
  FROM #FilterProductionUnits      
  WHERE RcdIdx = @i      
  ---------------------------------------------------------------------------------------------------------------       
  -- h. GET Top X values for PU      
  ---------------------------------------------------------------------------------------------------------------       
  TRUNCATE TABLE #TempValues2       
  INSERT INTO  #TempValues2 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
  SELECT TOP 15            
     MajorGroupId  ,      
     PLId    ,      
     PUId    ,      
     ValueL1VARCHAR100 ,      
     ValueL2VARCHAR100 ,      
     ValueL3VARCHAR100 ,      
     ValueL4VARCHAR100 ,      
     ValueINT   ,      
     ValueFLOAT         
  FROM @tblTempValues1      
  WHERE MajorGroupId = @j      
   AND PUId = @intPUId      
  ORDER BY ValueINT DESC      
  ---------------------------------------------------------------------------------------------------------------       
  -- i. GET Top X PU Total      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection5 (      
     MajorGroupId ,      
     Col0   ,       
     Col11   ,      
     Col12   ,      
     NameStyle  )      
  SELECT MajorGroupId ,      
    pu.PU_Desc  ,      
    SUM(ValueFLOAT) ,      
    SUM(ValueINT) ,      
    @constRptStyleTotal      
  FROM #TempValues2 tv2      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)      
          ON pu.PU_Id = tv2.PUId      
  WHERE RcdIdx <= @intRptTopX      
  GROUP BY tv2.MajorGroupId, tv2.PUId, pu.PU_Desc      
  ---------------------------------------------------------------------------------------------------------------      
  -- j. INSERT Top X vales for PU      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection5 (      
     MajorGroupId ,      
     Col0   ,      
     Col2   ,       
     Col4   ,       
     Col6   ,        
     Col11   ,      
     Col12   ,      
     NameStyle  )      
  SELECT MajorGroupId  ,      
    ValueL1VARCHAR100 ,      
    ValueL2VARCHAR100 ,      
    ValueL3VARCHAR100 ,      
    ValueL4VARCHAR100 ,      
    ValueFLOAT   ,      
    ValueINT   ,      
    @constRptStyleDetails      
  FROM #TempValues2 tv2      
  WHERE RcdIdx <= @intRptTopX      
  ORDER BY RcdIdx ASC      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' TOP X DOWNTIME SUMMARY BY DURATION'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- a. GET the aggregated values       
-- b. LOOP through major groups      
-- c. GET Top X values for line      
-- d. GET Top X line total      
-- e. INSERT Top X vales for line      
-- f. GET the aggregated values for a PU       
-- g. LOOP through major group PU's      
-- h. GET Top X values for PU      
-- i. GET Top X PU Total      
-- j. INSERT Top X vales for PU      
-----------------------------------------------------------------------------------------------------------------------      
-- INITIALIZE Variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. GET the aggregated values for a line sorted by occurrence desc      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 IF @intRptReasonTreeLevel = 1       
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1       
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
   Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 2       
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails         WHERE MajorGroupId = @j    GROUP BY MajorGroupId, PLId, Cause1, Cause2      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 3       
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT  ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3      
  END      
 END      
 ELSE      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,        ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, Cause1, Cause2, Cause3, Cause4      
  END      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- b. GET Top X vales for line      
 -------------------------------------------------------------------------------------------------------------------      
 TRUNCATE TABLE #TempValues2       
 INSERT INTO  #TempValues2 (      
     MajorGroupId  ,      
     PLId    ,      
     PUId    ,      
     ValueL1VARCHAR100 ,      
     ValueL2VARCHAR100 ,      
     ValueL3VARCHAR100 ,      
     ValueL4VARCHAR100 ,      
     ValueINT   ,      
     ValueFLOAT   )      
 SELECT TOP 15            
    MajorGroupId  ,      
    PLId    ,      
    PUId    ,      
    ValueL1VARCHAR100 ,      
    ValueL2VARCHAR100 ,      
    ValueL3VARCHAR100 ,      
    ValueL4VARCHAR100 ,      
    ValueINT   ,      
    ValueFLOAT         
 FROM @tblTempValues1      
 WHERE MajorGroupId = @j      
 ORDER BY ValueFLOAT DESC      
 -------------------------------------------------------------------------------------------------------------------      
 -- d. GET Top X line total      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection6 (      
    MajorGroupId ,      
    Col0   ,       
    Col11   ,      
    Col12   ,      
    NameStyle  )      
 SELECT MajorGroupId ,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   SUM(ValueFLOAT) ,      
   SUM(ValueINT) ,      
   @constRptStyleTotal      
 FROM #TempValues2 tv2      
  JOIN dbo.Prod_Lines pl WITH (NOLOCK)      
         ON pl.PL_Id = tv2.PLId      
 WHERE RcdIdx <= @intRptTopX      
 GROUP BY tv2.MajorGroupId, tv2.PLId, pl.PL_Desc      
 -------------------------------------------------------------------------------------------------------------------      
 -- e. INSERT Top X vales for line      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection6 (      
    MajorGroupId ,      
    Col0   ,      
    Col2   ,       
    Col4   ,       
    Col6   ,        
    Col11   ,      
    Col12   ,      
    NameStyle  )      
 SELECT MajorGroupId  ,      
   ValueL1VARCHAR100 ,      
   ValueL2VARCHAR100 ,      
   ValueL3VARCHAR100 ,      
   ValueL4VARCHAR100 ,      
   ValueFLOAT   ,      
   ValueINT   ,      
   @constRptStyleDetails      
 FROM #TempValues2 tv2      
 WHERE RcdIdx <= @intRptTopX      
 ORDER BY RcdIdx ASC      
 -------------------------------------------------------------------------------------------------------------------      
 -- f. GET the aggregated values for a PU       
 -------------------------------------------------------------------------------------------------------------------      
 DELETE @tblTempValues1      
 IF @intRptReasonTreeLevel = 1      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)         
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
  ELSE      
  BEGIN      
      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     NULL,      
     NULL,      
     NULL,      
     SUM(LEDSCount),    
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 2      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
   PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     NULL,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2      
  END      
 END      
 ELSE IF @intRptReasonTreeLevel = 3      
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     NULL,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0    FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3      
  END      
 END      
 ELSE       
 BEGIN      
  IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 0)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTMach <> @vchCatDTMachBlocked      
    AND CATDTMach <> @vchCatDTMachStarved      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE IF (@intRptFilterBlocked = 0 AND @intRptFilterPlanned = 1)      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails WITH (INDEX(LEDSDetailsMajorMinorCat_Idx))      
   WHERE MajorGroupId = @j      
    AND CATDTSched <> @vchCatLEDSPlanned      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
  ELSE      
  BEGIN      
   INSERT INTO @tblTempValues1 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,      
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
   SELECT MajorGroupId,      
     PLId,      
     PUId,      
     Cause1,      
     Cause2,      
     Cause3,      
     Cause4,      
     SUM(LEDSCount),      
     SUM(LEDSDurationInSecForRpt) / 60.0      
   FROM #LEDSDetails      
   WHERE MajorGroupId = @j      
   GROUP BY MajorGroupId, PLId, PUId, Cause1, Cause2, Cause3, Cause4      
  END      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- Initialize variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
 -------------------------------------------------------------------------------------------------------------------      
 -- g. LOOP through major group PU's      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intPUId = PUId      
  FROM #FilterProductionUnits      
  WHERE RcdIdx = @i      
  ---------------------------------------------------------------------------------------------------------------       
  -- h. GET Top X values for PU      
  ---------------------------------------------------------------------------------------------------------------       
  TRUNCATE TABLE #TempValues2       
  INSERT INTO  #TempValues2 (      
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      ValueL1VARCHAR100 ,      
      ValueL2VARCHAR100 ,      
      ValueL3VARCHAR100 ,             
      ValueL4VARCHAR100 ,      
      ValueINT   ,      
      ValueFLOAT   )      
  SELECT TOP 15            
     MajorGroupId  ,      
     PLId    ,      
     PUId    ,      
     ValueL1VARCHAR100 ,      
     ValueL2VARCHAR100 ,      
     ValueL3VARCHAR100 ,      
     ValueL4VARCHAR100 ,      
     ValueINT   ,      
     ValueFLOAT         
  FROM @tblTempValues1      
  WHERE MajorGroupId = @j      
   AND PUId = @intPUId      
  ORDER BY ValueFLOAT DESC      
  ---------------------------------------------------------------------------------------------------------------       
  -- i. GET Top X PU Total      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection6 (      
     MajorGroupId ,      
     Col0   ,       
     Col11   ,      
     Col12   ,      
     NameStyle  )      
  SELECT MajorGroupId ,      
    pu.PU_Desc  ,      
    SUM(ValueFLOAT) ,      
    SUM(ValueINT) ,      
    @constRptStyleTotal      
  FROM #TempValues2 tv2      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)      
          ON pu.PU_Id = tv2.PUId      
  WHERE RcdIdx <= @intRptTopX      
  GROUP BY tv2.MajorGroupId, tv2.PUId, pu.PU_Desc      
  ---------------------------------------------------------------------------------------------------------------      
  -- j. INSERT Top X vales for PU      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection6 (      
     MajorGroupId ,      
     Col0   ,      
     Col2   ,       
     Col4   ,       
     Col6   ,        
     Col11   ,      
     Col12   ,      
     NameStyle  )      
  SELECT MajorGroupId  ,      
    ValueL1VARCHAR100 ,      
    ValueL2VARCHAR100 ,      
    ValueL3VARCHAR100 ,      
    ValueL4VARCHAR100 ,      
    ValueFLOAT   ,      
    ValueINT   ,      
    @constRptStyleDetails      
  FROM #TempValues2 tv2      
  WHERE RcdIdx <= @intRptTopX      
  ORDER BY RcdIdx ASC      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' DOWNTIME TOP X LONGEST EVENTS'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0       
--=====================================================================================================================      
-- a. GET Top X values for line      
-- d. GET Top X line total      
-- e. INSERT Top X vales for line      
-- f. GET the aggregated values for a PU       
-- g. LOOP through major group PU's      
-- h. GET Top X values for PU      
-- i. GET Top X PU Total      
-- j. INSERT Top X vales for PU      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Unsplit LEDS Records'      
--=====================================================================================================================      
INSERT INTO  #LEDSDetailsTemp (      
    MajorGroupId  ,      
    LEDSId    ,      
    PLId    ,      
    PUId    ,      
    Cause1    ,      
    Cause2    ,      
    Cause3    ,      
    Cause4    ,      
    LEDSStart   ,      
    FaultDesc   ,       
    LEDSDurationInSec ,       
    LEDSComment   ,      
    CATDTSched   ,      
    CATDTMach   )      
SELECT DISTINCT      
  MajorGroupId  ,      
  LEDSId    ,      
  PLId    ,      
  PUId    ,      
  Cause1    ,      
  Cause2    ,      
  Cause3    ,      
  Cause4    ,      
  LEDSStart   ,      
  FaultDesc   ,       
  LEDSDurationInSecForRpt ,       
  LEDSComment   ,      
  CATDTSched   ,      
  CATDTMach      
FROM #LEDSDetails      
WHERE LEDSId > 0      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' APPLY FILTERS'      
--=====================================================================================================================      
-- DELETE Planned      
-----------------------------------------------------------------------------------------------------------------------      
IF (@intRptFilterPlanned = 1)      
BEGIN      
 DELETE #LEDSDetailsTemp      
 WHERE CATDTSched = @vchCatLEDSPlanned      
END      
-----------------------------------------------------------------------------------------------------------------------      
-- DELETE Blocked and Starved      
-----------------------------------------------------------------------------------------------------------------------      
IF (@intRptFilterBlocked = 1 AND @intRptFilterPlanned = 1)      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- DELETE Blocked      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE #LEDSDetailsTemp      
  WHERE CATDTMach = @vchCatDTMachBlocked      
 -------------------------------------------------------------------------------------------------------------------      
 -- DELETE Starved      
 -------------------------------------------------------------------------------------------------------------------      
 DELETE #LEDSDetailsTemp      
  WHERE CATDTMach = @vchCatDTMachStarved      
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET TOP X Longest Event for Line'      
--=====================================================================================================================      
-- INITIALIZE Variables      
-----------------------------------------------------------------------------------------------------------------------      
SELECT @j = 1,      
  @intMAXMajorGroupId = MAX(MajorGroupId)      
FROM #MajorGroupList      
-----------------------------------------------------------------------------------------------------------------------      
--  LOOP through MajorGroupIds      
-----------------------------------------------------------------------------------------------------------------------      
WHILE @j <= @intMAXMajorGroupId      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 -- a. GET Top X vales for line      
 -------------------------------------------------------------------------------------------------------------------      
 TRUNCATE TABLE #TempValues2       
 IF @intRptReasonTreeLevel = 1       
 BEGIN      
  INSERT INTO  #TempValues2 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 , -- Level1      
      ValueL2VARCHAR100 , -- Level2      
      ValueL3VARCHAR100 , -- Level3      
      ValueL4VARCHAR100 , -- Level4      
      ValueStartTime  , -- StartTime      
      ValueFault   , -- Fault      
      ValueFLOAT   ,      
      ValueComment  ) --  Comment      
  SELECT TOP 15            
     MajorGroupId  ,      
     PLId    ,      
     Cause1    ,      
     NULL    ,      
     NULL    ,      
     NULL    ,      
     CONVERT(VARCHAR(25), LEDSStart, 120),      
     FaultDesc   ,       
     LEDSDurationInSec / 60.0,       
     LEDSComment         
  FROM #LEDSDetailsTemp      
  WHERE MajorGroupId = @j       
  ORDER BY LEDSDurationInSec DESC      
 END      
 ELSE IF @intRptReasonTreeLevel = 2       
 BEGIN      
  INSERT INTO  #TempValues2 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 , -- Level1      
      ValueL2VARCHAR100 , -- Level2      
      ValueL3VARCHAR100 , -- Level3      
      ValueL4VARCHAR100 , -- Level4      
      ValueStartTime  , -- StartTime      
      ValueFault   , -- Fault      
      ValueFLOAT   ,      
      ValueComment  ) --  Comment      
  SELECT TOP 15            
     MajorGroupId  ,      
     PLId    ,      
     Cause1    ,      
     Cause2    ,      
     NULL    ,      
     NULL    ,      
     CONVERT(VARCHAR(25), LEDSStart, 120),      
     FaultDesc   ,       
     LEDSDurationInSec / 60.0,       
     LEDSComment         
  FROM #LEDSDetailsTemp      
  WHERE MajorGroupId = @j      
  ORDER BY LEDSDurationInSec DESC      
 END      
 ELSE IF @intRptReasonTreeLevel = 3       
 BEGIN      
  INSERT INTO  #TempValues2 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 , -- Level1      
      ValueL2VARCHAR100 , -- Level2      
      ValueL3VARCHAR100 , -- Level3      
      ValueL4VARCHAR100 , -- Level4      
      ValueStartTime  , -- StartTime      
      ValueFault   , -- Fault      
      ValueFLOAT   ,      
      ValueComment  ) --  Comment      
  SELECT TOP 15            
     MajorGroupId  ,      
     PLId    ,      
     Cause1    ,      
     Cause2    ,      
     Cause3    ,      
     NULL    ,      
     CONVERT(VARCHAR(25), LEDSStart, 120),      
     FaultDesc   ,       
     LEDSDurationInSec / 60.0,       
     LEDSComment         
  FROM #LEDSDetailsTemp      
  WHERE MajorGroupId = @j      
  ORDER BY LEDSDurationInSec DESC      
 END      
 ELSE      
 BEGIN      
  INSERT INTO  #TempValues2 (      
      MajorGroupId  ,      
      PLId    ,      
      ValueL1VARCHAR100 , -- Level1      
     ValueL2VARCHAR100 , -- Level2      
      ValueL3VARCHAR100 , -- Level3      
      ValueL4VARCHAR100 , -- Level4      
      ValueStartTime  , -- StartTime      
      ValueFault   , -- Fault      
      ValueFLOAT   ,      
      ValueComment  ) --  Comment      
  SELECT TOP 15            
     MajorGroupId  ,      
     PLId    ,      
     Cause1    ,      
     Cause2    ,      
     Cause3    ,      
     Cause4    ,      
     CONVERT(VARCHAR(25), LEDSStart, 120),      
     FaultDesc   ,       
     LEDSDurationInSec / 60.0,       
     LEDSComment         
  FROM #LEDSDetailsTemp      
  WHERE MajorGroupId = @j      
  ORDER BY LEDSDurationInSec DESC      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- d. GET Top X line total      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection7 (      
    MajorGroupId ,      
    Col0   ,       
    Col11   ,      
    NameStyle  )      
 SELECT MajorGroupId ,      
   pl.PL_Desc + ' ' + (SELECT PromptValue FROM @tblPrompts WHERE PromptId = 99827091),      
   SUM(ValueFLOAT) ,      
   @constRptStyleTotal      
 FROM #TempValues2 tv2      
  JOIN dbo.Prod_Lines pl WITH (NOLOCK)      
         ON pl.PL_Id = tv2.PLId      
 WHERE RcdIdx <= @intRptTopX      
 GROUP BY tv2.MajorGroupId, tv2.PLId, pl.PL_Desc      
 -------------------------------------------------------------------------------------------------------------------      
 -- e. INSERT Top X vales for line      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblSection7 (      
    MajorGroupId ,      
    Col0   ,      
    Col2   ,       
    Col4   ,       
    Col6   ,      
    Col8   ,       
    Col9   ,         
    Col11   ,      
    Col12   ,      
    NameStyle  )      
 SELECT MajorGroupId  ,      
   ValueL1VARCHAR100 ,      
   ValueL2VARCHAR100 ,      
   ValueL3VARCHAR100 ,      
   ValueL4VARCHAR100 ,      
   ValueStartTime  ,      
   ValueFault   ,      
   ValueFLOAT   ,      
   ValueComment  ,      
   @constRptStyleDetails      
 FROM #TempValues2 tv2      
 WHERE RcdIdx <= @intRptTopX      
 ORDER BY RcdIdx ASC      
 --=================================================================================================================      
 IF @intPRINTFlag = 1 SET @intSubSecNumber = @intSubSecNumber + 1      
 IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET TOP X Longest Event for PU'      
 --=================================================================================================================      
 -- Initialize variables      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT @intMinRcdIdx = MIN(RcdIdx),      
   @intMaxRcdIdx = MAX(RcdIdx)      
 FROM #FilterProductionUnits      
 WHERE PLId = (SELECT PLId FROM #MajorGroupList WHERE MajorGroupId = @j)      
 -------------------------------------------------------------------------------------------------------------------      
 -- g. LOOP through major group PU's      
 -------------------------------------------------------------------------------------------------------------------      
 SET @i = @intMinRcdIdx      
 WHILE @i <= @intMaxRcdIdx      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- Get PUId      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT @intPUId = PUId      
  FROM #FilterProductionUnits      
  WHERE RcdIdx = @i      
  ---------------------------------------------------------------------------------------------------------------       
  -- h. GET Top X values for PU      
  ---------------------------------------------------------------------------------------------------------------       
  TRUNCATE TABLE #TempValues2       
  IF @intRptReasonTreeLevel = 1       
  BEGIN      
   INSERT INTO  #TempValues2 (      
       MajorGroupId  ,      
       PLId    ,      
       PUId    ,      
       ValueL1VARCHAR100 , -- Level1      
       ValueL2VARCHAR100 , -- Level2      
       ValueL3VARCHAR100 , -- Level3      
       ValueL4VARCHAR100 , -- Level4      
       ValueStartTime  , -- StartTime      
       ValueFault   , -- Fault      
       ValueFLOAT   ,      
       ValueComment  ) --  Comment      
   SELECT TOP 15            
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      Cause1    ,      
      NULL    ,      
      NULL    ,      
      NULL    ,      
      CONVERT(VARCHAR(25), LEDSStart, 120),      
      FaultDesc   ,       
      LEDSDurationInSec / 60.0,       
      LEDSComment         
   FROM #LEDSDetailsTemp      
   WHERE MajorGroupId = @j      
    AND PUId = @intPUId      
   ORDER BY LEDSDurationInSec DESC      
  END      
  ELSE IF @intRptReasonTreeLevel = 2      
  BEGIN      
   INSERT INTO  #TempValues2 (      
       MajorGroupId  ,      
       PLId    ,      
       PUId    ,      
       ValueL1VARCHAR100 , -- Level1      
       ValueL2VARCHAR100 , -- Level2      
       ValueL3VARCHAR100 , -- Level3      
       ValueL4VARCHAR100 , -- Level4      
       ValueStartTime  , -- StartTime      
       ValueFault   , -- Fault      
       ValueFLOAT   ,      
       ValueComment  ) --  Comment      
   SELECT TOP 15            
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      Cause1    ,      
      Cause2    ,      
      NULL    ,      
      NULL    ,      
      CONVERT(VARCHAR(25), LEDSStart, 120),      
      FaultDesc   ,       
      LEDSDurationInSec / 60.0,       
      LEDSComment         
   FROM #LEDSDetailsTemp      
   WHERE MajorGroupId = @j      
    AND PUId = @intPUId      
   ORDER BY LEDSDurationInSec DESC      
  END      
  ELSE IF @intRptReasonTreeLevel = 3      
  BEGIN      
   INSERT INTO  #TempValues2 (      
       MajorGroupId  ,      
       PLId    ,      
       PUId    ,      
       ValueL1VARCHAR100 , -- Level1      
       ValueL2VARCHAR100 , -- Level2      
       ValueL3VARCHAR100 , -- Level3      
       ValueL4VARCHAR100 , -- Level4      
       ValueStartTime  , -- StartTime      
       ValueFault   , -- Fault      
       ValueFLOAT   ,      
       ValueComment  ) --  Comment      
   SELECT TOP 15            
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      Cause1    ,      
      Cause2    ,      
      Cause3    ,      
      NULL    ,      
      CONVERT(VARCHAR(25), LEDSStart, 120),      
      FaultDesc   ,       
      LEDSDurationInSec / 60.0,       
      LEDSComment         
   FROM #LEDSDetailsTemp      
   WHERE MajorGroupId = @j      
    AND PUId = @intPUId      
   ORDER BY LEDSDurationInSec DESC      
  END      
  ELSE      
  BEGIN      
   INSERT INTO  #TempValues2 (      
       MajorGroupId  ,      
       PLId    ,      
       PUId    ,      
       ValueL1VARCHAR100 , -- Level1      
       ValueL2VARCHAR100 , -- Level2      
       ValueL3VARCHAR100 , -- Level3      
       ValueL4VARCHAR100 , -- Level4      
       ValueStartTime  , -- StartTime      
       ValueFault   , -- Fault      
       ValueFLOAT   ,      
       ValueComment  ) --  Comment      
   SELECT TOP 15            
      MajorGroupId  ,      
      PLId    ,      
      PUId    ,      
      Cause1    ,      
      Cause2    ,      
      Cause3    ,      
      Cause4    ,      
      CONVERT(VARCHAR(25), LEDSStart, 120),      
      FaultDesc   ,       
      LEDSDurationInSec / 60.0,       
      LEDSComment         
   FROM #LEDSDetailsTemp      
   WHERE MajorGroupId = @j      
    AND PUId = @intPUId      
   ORDER BY LEDSDurationInSec DESC      
  END      
  ---------------------------------------------------------------------------------------------------------------       
  -- i. GET Top X PU Total      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection7 (      
     MajorGroupId ,      
     Col0   ,       
     Col11   ,      
     NameStyle  )      
  SELECT MajorGroupId ,      
    pu.PU_Desc  ,      
    SUM(ValueFLOAT) ,      
    @constRptStyleTotal      
  FROM #TempValues2 tv2      
   JOIN dbo.Prod_Units pu WITH (NOLOCK)      
          ON pu.PU_Id = tv2.PUId      
  WHERE RcdIdx <= @intRptTopX      
  GROUP BY tv2.MajorGroupId, tv2.PUId, pu.PU_Desc      
  ---------------------------------------------------------------------------------------------------------------      
  -- j. INSERT Top X vales for PU      
  ---------------------------------------------------------------------------------------------------------------      
  INSERT INTO @tblSection7 (      
     MajorGroupId ,      
     PUId   ,      
     Col0   ,      
     Col2   ,       
     Col4   ,       
     Col6   ,      
     Col8   ,       
     Col9   ,         
     col11   ,      
     Col12   ,      
     NameStyle  )      
  SELECT MajorGroupId  ,      
    PUId    ,      
    ValueL1VARCHAR100 ,      
    ValueL2VARCHAR100 ,      
    ValueL3VARCHAR100 ,      
    ValueL4VARCHAR100 ,      
    ValueStartTime  ,      
    ValueFault   ,      
    ValueFLOAT   ,      
    ValueComment  ,      
    @constRptStyleDetails      
  FROM #TempValues2 tv2      
  WHERE RcdIdx <= @intRptTopX      
  ORDER BY RcdIdx ASC      
  ---------------------------------------------------------------------------------------------------------------      
  -- INCREMENT COUNTER      
  ---------------------------------------------------------------------------------------------------------------      
  SET @i = @i + 1      
 END      
 -------------------------------------------------------------------------------------------------------------------      
 -- INCREMENT COUNTER      
 -------------------------------------------------------------------------------------------------------------------      
 SET @j = @j + 1       
END      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
IF @intPRINTFlag = 1 PRINT '-----------------------------------------------------------------------------------------------------------------------'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
IF @intPRINTFlag = 1 PRINT 'START SECTION : '+ CONVERT(VARCHAR, @intSecNumber)      
IF @intPRINTFlag = 1 PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' RETURN RESULT SETS'      
IF @intPRINTFlag = 1 SET @intSubSecNumber = 0      
--=====================================================================================================================      
-- RETURN RESULT SETS      
-----------------------------------------------------------------------------------------------------------------------      
-- INSERT constraint message on the Miscellaneous Info table      
-----------------------------------------------------------------------------------------------------------------------      
SET @vchConstraintMessage = (SELECT PromptValue FROM @tblPrompts WHERE PromptID = 99826077)      
-----------------------------------------------------------------------------------------------------------------------      
-- ErrorFinish:       
-----------------------------------------------------------------------------------------------------------------------      
ERRORFinish:      
IF @intErrorCode >= 1      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 --  POPULATE Miscellaneous Info      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblMiscInfo (      
    ErrorCode,      
    ErrorMsg)      
 VALUES ( @intErrorCode,       
    @vchErrorMsg)      
 -------------------------------------------------------------------------------------------------------------------      
 --  RETURN Miscellaneous Info      
 -------------------------------------------------------------------------------------------------------------------      
 SELECT * FROM @tblMiscInfo END      
ELSE      
BEGIN      
 -------------------------------------------------------------------------------------------------------------------      
 --  RETURN Miscellaneous Info      
 -------------------------------------------------------------------------------------------------------------------      
 INSERT INTO @tblMiscInfo (      
    ErrorCode,      
    ErrorMsg,      
    WithDataValidation)       
 VALUES( 0,      
   '',      
   @intRptWithDataValidation)      
 -------------------------------------------------------------------------------------------------------------------      
 -- UPDATE Report footer text      
 -------------------------------------------------------------------------------------------------------------------      
 UPDATE @tblMiscInfo       
 SET ConstraintMessage = @vchConstraintMessage      
 -------------------------------------------------------------------------------------------------------------------    
 SELECT * FROM @tblMiscInfo      
 -------------------------------------------------------------------------------------------------------------------      
 --  RETURN Other Result Sets      
 -------------------------------------------------------------------------------------------------------------------      
    SELECT * FROM #MajorGroupList      
   SELECT * FROM @tblHdrInfoCommon      
   SELECT * FROM @tblHdrInfoVariable      
   SELECT * FROM @tblSectionList      
   SELECT * FROM @tblSectionColumn      
   SELECT * FROM @tblSection1      
   SELECT * FROM @tblSection2      
   SELECT * FROM @tblSection3      
   SELECT * FROM @tblSection4      
   SELECT * FROM @tblSection5      
   SELECT * FROM @tblSection6      
   SELECT * FROM @tblSection7      
 -------------------------------------------------------------------------------------------------------------------      
 --  RETURN Data Validation Result Sets      
 -------------------------------------------------------------------------------------------------------------------      
 IF @intRptWithDataValidation = 1      
 BEGIN      
  ---------------------------------------------------------------------------------------------------------------      
  -- LEDS Details      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT RcdIdx     ,      
    MajorGroupId   ,      
    MinorGroupId   ,      
    PLId     ,      
    PUId     ,      
    pu.PU_Desc PUDesc  ,      
    ProdGroupId    ,      
    ProdId     ,      
    CONVERT(VARCHAR(35), EventProductionDay, 120) EventProductionDay,      
    Shift     ,      
    Team     ,      
    EventProductionStatus ,      
    LEDSId     ,      
    CONVERT(VARCHAR(35), UPTimeStart, 120) UPTimeStart,      
    CONVERT(VARCHAR(35), UPTimeEnd, 120) UPTimeEnd,      
    UPTimeDurationInSec  ,      
    CONVERT(VARCHAR(35), LEDSStart, 120) LEDSStart,      
    CONVERT(VARCHAR(35), LEDSEnd, 120)  LEDSEnd,      
    CONVERT(VARCHAR(35), LEDSStartForRpt, 120)  LEDSStartForRpt,      
    CONVERT(VARCHAR(35), LEDSEndForRpt, 120)  LEDSEndForRpt,      
    LEDSDurationInSec  ,      
    LEDSDurationInSecForRpt  ,      
    LEDSCount    ,      
    LEDSParentId   ,      
    CauseRL1Id    ,      
    er1.Event_Reason_Name Cause1,      
    CauseRL2Id    ,      
    er2.Event_Reason_Name Cause2,      
    CauseRL3Id    ,      
    er3.Event_Reason_Name Cause3,      
    CauseRL4Id    ,      
    er4.Event_Reason_Name Cause4,      
    TreeNodeId    ,      
    ActionTreeId   ,      
    Action1Id    ,      
    Action2Id    ,      
    Action3Id    ,      
    Action4Id    ,      
    ACtionTreeNodeId  ,      
    CatId     ,      
    CatDTSched    ,      
    CatDTType    ,      
    CatDTGroup    ,      
    CatDTMach    ,      
    CatDTClass    ,      
    FaultId     ,      
    FaultDesc    ,      
    PlannedTrackingLevel ,      
    ConstraintOrder   ,      
    LastMachine    ,      
    ParallelUnit   ,      
     EventSplitFactor  ,      
     EventSplitFlag   ,      
     EventSplitShiftFlag  ,      
     EventSplitProductionDayFlag       
  FROM #LEDSDetails ld      
     JOIN dbo.Prod_Units  pu WITH (NOLOCK)      
            ON pu.PU_Id = ld.PUId      
   LEFT JOIN dbo.Event_Reasons er1 WITH (NOLOCK)      
            ON ld.CauseRL1Id = er1.Event_Reason_Id      
   LEFT JOIN dbo.Event_Reasons er2 WITH (NOLOCK)      
            ON ld.CauseRL2Id = er2.Event_Reason_Id      
   LEFT JOIN dbo.Event_Reasons er3 WITH (NOLOCK)      
            ON ld.CauseRL3Id = er3.Event_Reason_Id      
   LEFT JOIN dbo.Event_Reasons er4 WITH (NOLOCK)      
            ON ld.CauseRL4Id = er4.Event_Reason_Id      
  ORDER BY PUId, UPTimeStart, UPTimeEnd, LEDSStart, LEDSEnd      
  ---------------------------------------------------------------------------------------------------------------      
  -- Production Raw Data  (Add a blank row when only a non-constraint unit is selected for the report "count = 0")      
  ---------------------------------------------------------------------------------------------------------------      
  IF (SELECT count(1) FROM #ProductionRawData prd       
   JOIN dbo.Prod_Units pu ON pu.PU_Id = prd.ProductionCountPUId) = 0       
  BEGIN      
    SELECT  1 RcdIdx       ,      
    1 MajorGroupId     ,      
    NULL MinorGroupId     ,      
    NULL PLId       ,         
    NULL EventId       ,      
    NULL EventPUId       ,      
    NULL ProductionCountPUId     ,      
    NULL       ProductionPUDesc ,       
    NULL ConstraintOrder     ,      
    NULL EventNumber      ,      
    NULL EventStart       ,      
    NULL EventEnd       ,      
    NULL EventStartForRpt     ,      
    NULL EventEndForRpt      ,      
    NULL  EventProductionDay,      
    NULL EventProductionTimeInSec  ,      
    NULL EventProductionTimeInSecForRpt ,      
    NULL EventProdId      ,   -- COALESCE(EventAppliedProdId, EventProdId)      
    NULL EventProdCode     ,      
    NULL EventProdDesc     ,      
    NULL EventPSProdId     ,   -- product from production starts table      
    NULL EventAppliedProdId    ,   -- applied product from dbo.Events      
    NULL EventProdGroupId    ,           
    NULL EventShift      ,      
    NULL EventTeam      ,      
    NULL EventProductionStatusVarId  ,   -- RptHook=ProductionStatus      
    NULL EventProductionStatus   ,      
    NULL EventAdjustedCasesVarId   ,   -- RptHook=AdjustedCases      
    NULL EventAdjustedCases    ,          
    NULL EventStatCaseConvFactorVarId ,   -- RptHook=StatCaseConvFactor      
    NULL EventStatCaseConvFactor   ,      
    NULL EventAdjustedUnitsVarId   ,   -- RptHook=AdjustedCases      
    NULL EventAdjustedUnits    ,      
    NULL EventTargetRateVarId   ,   -- RptHook=TargetRate      
    NULL EventTargetRatePerMin     ,      
    NULL EventActualRateVarId   ,   -- RptHook=ActualRate      
    NULL EventActualRatePerMin     ,       
    NULL EventScheduledTimeVarId   ,   -- RptHook=ScheduleTime      
    NULL EventScheduledTimeInSec   ,      
    NULL EventIdealRateVarId    ,   -- RptHook=IdealRate      
    NULL EventIdealRatePerMin     ,      
    NULL EventUnitsPerCase    ,      
    NULL EventSplitFactor    ,      
    NULL EventSplitFlag     ,      
    NULL EventSplitShiftFlag    , -- Flags events split at shift boundaries      
    NULL EventSplitProductionDayFlag  , -- Flags events split at production day boundaries      
    NULL ErrorCode      ,       
    NULL Error              
  END      
  ELSE      
  BEGIN      
  SELECT RcdIdx       ,      
    MajorGroupId     ,      
    MinorGroupId     ,      
    PLId       ,         
    EventId       ,      
    EventPUId       ,      
    ProductionCountPUId     ,      
    pu.PU_Desc      ProductionPUDesc ,       
    ConstraintOrder     ,      
    EventNumber      ,      
    EventStart       ,      
    EventEnd       ,      
    EventStartForRpt     ,      
    EventEndForRpt      ,      
    CONVERT(VARCHAR(35), EventProductionDay, 120) EventProductionDay,      
    EventProductionTimeInSec  ,      
    EventProductionTimeInSecForRpt ,      
    EventProdId      ,   -- COALESCE(EventAppliedProdId, EventProdId)      
    EventProdCode     ,      
    EventProdDesc     ,      
    EventPSProdId     ,   -- product from production starts table      
    EventAppliedProdId    ,   -- applied product from dbo.Events      
    EventProdGroupId    ,           
    EventShift      ,      
    EventTeam      ,      
    EventProductionStatusVarId  ,   -- RptHook=ProductionStatus      
    EventProductionStatus   ,      
    EventAdjustedCasesVarId   ,   -- RptHook=AdjustedCases      
    EventAdjustedCases    ,          
    EventStatCaseConvFactorVarId ,   -- RptHook=StatCaseConvFactor      
    EventStatCaseConvFactor   ,      
    EventAdjustedUnitsVarId   ,   -- RptHook=AdjustedCases      
    EventAdjustedUnits    ,      
    EventTargetRateVarId   ,   -- RptHook=TargetRate      
    EventTargetRatePerMin     ,      
    EventActualRateVarId   ,   -- RptHook=ActualRate      
    EventActualRatePerMin     ,       
    EventScheduledTimeVarId   ,   -- RptHook=ScheduleTime      
    EventScheduledTimeInSec   ,      
    EventIdealRateVarId    ,   -- RptHook=IdealRate      
    EventIdealRatePerMin     ,      
    EventUnitsPerCase    ,      
    EventSplitFactor    ,      
    EventSplitFlag     ,      
    EventSplitShiftFlag    , -- Flags events split at shift boundaries      
    EventSplitProductionDayFlag  , -- Flags events split at production day boundaries      
    ErrorCode      ,       
    Error              
   FROM #ProductionRawData prd       
   JOIN dbo.Prod_Units pu ON pu.PU_Id = prd.ProductionCountPUId      
  ORDER BY PLId, EventStart, EventEnd      
  END      
  ---------------------------------------------------------------------------------------------------------------      
  -- Formulas      
  ---------------------------------------------------------------------------------------------------------------      
  SELECT Measure,       
    EngUnits,      
    MultiLineRollUp,       
    Line,       
    Constraint1,      
    Constraintx,      
    Machine,      
    IntRowCount      
  FROM  fnLocal_LEDS_Formulas(@intLanguageId)      
 END      
END      
--=====================================================================================================================      
-- DEBUG SECTION COMMENT BEFORE INSTALLATION      
--=====================================================================================================================      
-- SELECT '@tblReportParameters', * FROM @tblReportParameters      
-- SELECT '#FilterProductionLines', * FROM #FilterProductionLines      
-- SELECT  '@tblPrompts', * FROM @tblPrompts      
-- SELECT '#FilterProductionUnits', * FROM #FilterProductionUnits      
-- SELECT '@tblLineDowntimeMeasures', * FROM @tblLineDowntimeMeasures      
-- SELECT  '@tblTempAggregates', * FROM @tblTempAggregates      
-- SELECT  '@tblProductionAggregates', * FROM @tblProductionAggregates       
-- SELECT '#LEDSDetails', * FROM #LEDSDetails      
--=====================================================================================================================      
-- DROP temp tables      
--=====================================================================================================================      
DROP TABLE  #TempParsingTable      
DROP TABLE  #FilterProductionLines      
DROP TABLE  #FilterProductionUnits      
DROP TABLE #FilterProductionLineStatus      
DROP TABLE #MajorGroupList      
DROP TABLE  #LEDSDetails      
DROP TABLE  #ProductionRawData      
DROP TABLE #TempValues2      
      
DROP TABLE  #LEDSDetailsTemp --TCS (FO-00829)      
--=====================================================================================================================      
IF @intPRINTFlag = 1 PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE()))       
IF @intPRINTFlag = 1 SET @dtmTempDate  = GETDATE()      
IF @intPRINTFlag = 1 SET @intSecNumber  = @intSecNumber + 1      
--=====================================================================================================================      
SET NOCOUNT OFF  
GO


GO 
SET ANSI_NULLS ON 
GO 
SET QUOTED_IDENTIFIER OFF 
GO 

GRANT EXECUTE ON [dbo].spLocal_RptLEDSDDSPR_HTML5 TO [OPDBManager] 
GO    
--=====================================================================================================================      
-- END SP      
--=====================================================================================================================      
  
  