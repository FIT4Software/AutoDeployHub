
GO
set ANSI_NULLS ON
GO
set QUOTED_IDENTIFIER ON
GO

---------------------------------------------------------------------------------------------------
-- !!!!!!!!!! TO VIEW THIS SP PLEASE SET TAB SPACING TO 4 !!!!!!!!!!
---------------------------------------------------------------------------------------------------
-- Prototype definition
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@Input 			INT, 
		@Input_Output 	INT, 
		@Output 		INT,
		@SP_Name 		NVARCHAR(200),
		@Version		NVARCHAR(20),
		@AppId			INT
		
SELECT	@Input 			= 12, 
		@Input_Output 	= 0, 	
		@Output 		= 0,
		@SP_Name	 	= 'spLocal_RptStopHistory_HTML5',
		@Version		= '1.4'  -- Number should match version manager

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
--=====================================================================================================================

-----------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM Client_SP_Prototypes WHERE	sp_name = @SP_Name)
	INSERT	INTO	Client_SP_Prototypes (	
				SP_Name, 				Command_Text,	Stored_Proc, 	Input, 
				Input_Output, 			Output, 		Server_Cursor, 	CursorType_Id, 
				LockType_Id, 			Prepare_SP, 	Timeout, 		MaxRetries, 
				SP_Desc )
	VALUES(		@SP_Name, 				@SP_Name,		1,				@Input, 
				@Input_Output, 			@Output,		0, 				1, 
				1, 						1, 				0, 				0, 
				' ')


SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO
-----------------------------------------------------------------------------------------------------------------------
-- Drop store procedure
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (	SELECT	* 
					FROM 	dbo.sysobjects 
					WHERE Id = object_id(N'[dbo].[spLocal_RptStopHistory_HTML5]') 
	AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
    DROP PROCEDURE [dbo].[spLocal_RptStopHistory_HTML5]
GO

--
-- Revision			Date			Who						What
-- ========			=====			=====					=====
-- 1.0				2019-07-12		Gonzalo Luc				Inicial Release Original SP spLocal_RptStopHistory v 2.0
-- 1.1				2019-08-15		Gustavo Conde			Fix for ussing the first value from #FinalResultSet.CommentIdList
-- 1.2				2019-10-16		Damian Campana			Add column ProdDesc to the output data
-- 1.3				2020-02-13		Facundo Sosa			Fix ProdDesc when Minor group selected
-- 1.4				2020-05-19		Gonzalo Luc				Eliminate join with Timed_event_details_History and get the Initial user from Timed_event_Details table.

---------------------------------------------------------------------------------------------------
-- Example:
---------------------------------------------------------------------------------------------------
CREATE   PROCEDURE  [dbo].[spLocal_RptStopHistory_HTML5]
--DECLARE

	 @RptPUIdList					NVARCHAR(1000) 	= Null	
	,@RptProdIdList					NVARCHAR(1000)	= Null									
	,@RptSourcePUIdList				NVARCHAR(1000)	= '!Null'
	,@RptShiftDescList				NVARCHAR(50)	= '!Null'
	,@RptCrewDescList				NVARCHAR(50)	= '!Null'
	,@RptLineStatusIdList			NVARCHAR(500)	= 'All'	
	,@RptStopHistoryMajorGroupBy	NVARCHAR(50)	= 'PUId'
	,@RptStopHistoryMinorGroupBy	NVARCHAR(500)	= 'None'
	,@RptEventReasonIdList			NVARCHAR(MAX)	= '!Null'
	,@RptStartDateTime				DATETIME		= NULL
	,@RptEndDateTime				DATETIME		= NULL	
--WITH ENCRYPTION
AS
--=================================================================================================
-- Testing - dbo.spLocal_RptStopHistory_HTML5
-- SELECT report_name, * FROM REPORT_DEFINITIONS order by Report_ID WHERE report_name like 'RE_StopHistory_Test_FO%' -- Id: 369953
-- exec [dbo].[spLocal_RptStopHistory_HTML5] 'RE_StopReport20111202195435', '2011-11-10 06:15:00.000', '2011-12-02 06:15:00.000'

 --SELECT 
 --	 @RptPUIdList					= '600|607|611|612|613|1158'
 --	,@RptProdIdList					= '!Null'							
 --	,@RptSourcePUIdList				= '601|602|603|604|605|606|1119|1184|1185|1186|600|607|611|612|613|1158'
 --	,@RptShiftDescList				= 'All'
 --	,@RptCrewDescList				= 'All'
 --	,@RptLineStatusIdList			= 'All'
 --	,@RptStopHistoryMajorGroupBy	= 'PUId'
 --	,@RptStopHistoryMinorGroupBy	= '!Null'
 --	,@RptEventReasonIdList			= '!Null'
 --	,@RptStartDateTime				= '2020-04-01 00:00:00'
 --	,@RptEndDateTime				= '2020-04-16 00:00:00'
--=================================================================================================

SET NOCOUNT ON
--=================================================================================================
DECLARE	@dtmTempDate	DateTime,
		@intSecNumber	Int
SET		@dtmTempDate = GetDate()
---------------------------------------------------------------------------------------------------
SET	@intSecNumber	=	1
-- PRINT 'SP START ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + Convert(VarChar, @@TRANCount) 
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- PRINT	'	- Declare variables '
-- PRINT	'		. Report Variables '
---------------------------------------------------------------------------------------------------

-- RptPUIdList: "54|55|58|472|764|3262"
-- RptProdIdList: "!Null"
-- RptSourcePUIdList: "!Null"
-- RptShiftDescList: "All"
-- RptCrewDescList: "All"
-- RptLineStatusIdList: "All"
-- RptStopHistoryMajorGroupBy: "!Null"
-- RptStopHistoryMinorGroupBy: "PLId|ProductionDay|EventReasonName1"
-- RptEventReasonIdList: "!Null"
-- RptStartDateTime: "2020-02-12 00:00:00"
-- RptEndDateTime: "2020-02-13 00:00:00"
DECLARE	
	@RptOwnerId						Int 			,
	@RptSUFactor					Int				,
	@RptT							Int				,
	@RptTDowntime					Int				,
	@RptShiftLength					Int				,
	@RptStopHistoryCommentColWidth	Int				,
	@RptStartDate					VarChar(25) 	,			
	@RptEndDate						VarChar(25) 	,			
	@RptStartTime					VarChar(25) 	,
	@RptEndTime						VarChar(25) 	,
	@RptStopHistoryColumnVisibility VarChar(4000)	,
	@RptLineStatusDescList			VarChar(4000)	,		-- Note: Line status is a data_type. Line status names can be found in Phrases table
	@RptTitle						VarChar(255)	,
	@RptSortType					VarChar(5)		,
	@RptShiftStart					DateTime		,
	@RptName						NVARCHAR(50)	= 'Stops History Report',	
	@RptStrCategoriesToExclude		nvarchar(1000)	

---------------------------------------------------------------------------------------------------
-- PRINT '	.	Other Variables'
---------------------------------------------------------------------------------------------------
-- Other variables
-- Note: @c_.... are cursor variables
---------------------------------------------------------------------------------------------------
DECLARE
 	@chrTempDate		VarChar(50),
 	@chrTempString		VarChar(1000),
 	@chrCompanyName		VarChar(50),
 	@chrSiteName		VarChar(50),
 	@chrRptOwnerDesc	VarChar(50),
	@chrSQLCommand		VarChar(8000),
	@chrSQLCommand1		VarChar(8000),
	@chrSQLCommand2		VarChar(8000),
	@chrSQLCommand3		VarChar(8000),
	@chrSQLCommand4		VarChar(8000),
	@chrPUDescList		VarChar(8000),
	@chrProdDescList	VarChar(8000)
---------------------------------------------------------------------------------------------------
DECLARE
	@c_chrShiftDesc		VarChar(10),
	@c_chrCrewDesc		VarChar(10),
	@c_chrProdCode		VarChar(50),
	@c_chrPUDesc		VarChar(50)
---------------------------------------------------------------------------------------------------
DECLARE
 	@i						Int,
	@j						Int,
 	@intShiftLengthInMin	Int,
 	@intShiftOffsetInMin	Int,
 	@intShiftMaxCount		Int,
 	@intShiftDesc			Int,
	@intDetId1				Int,
	@intDetId2				Int,
	@intCommentTableFlag	Int,
	@intReliabilityUserId	Int,
	@intDetId				Int,
	@intShiftOffset			Int,
	@intId					INT,
	@NextCommentId			INT, 
	@CommentId				INT
---------------------------------------------------------------------------------------------------
DECLARE
	@c_intPUId				Int,
	@c_intDetId				Int,
	@c_intCSId				Int,
	@c_intLineStatusSchedId	Int,
	@c_intLineStatusId		Int,
	@c_intWTCId				Int,
	@c_intLookUpPUId		Int
---------------------------------------------------------------------------------------------------
DECLARE
	@fltDBVersion			Float
---------------------------------------------------------------------------------------------------
DECLARE
 	@dtmStartDateTime 	DateTime,
 	@dtmEndDateTime 	DateTime,
 	@dtmDummyDate		DateTime,
 	@dtmBaseDate		DateTime,
 	@dtmShiftDay		DateTime,
	@dtmDlyTempDate		DateTime,
	@dtmMasterDelayEnd	DateTime
---------------------------------------------------------------------------------------------------
DECLARE
	@c_dtmDelayStart		DateTime,
	@c_dtmDelayEnd			DateTime,
 	@c_dtmShiftStart		DateTime,
 	@c_dtmShiftEnd			DateTime,
	@c_dtmLineStatusStart	DateTime,
	@c_dtmLineStatusEnd		DateTime
---------------------------------------------------------------------------------------------------
-- PRINT '	.	Create table variables'
---------------------------------------------------------------------------------------------------
DECLARE	@tblRptStartOverlappingRcds	TABLE	(
		DetId		Int,
		DelayStart	DateTime	)
---------------------------------------------------------------------------------------------------
-- PRINT '	.	Create temporary tables.'
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MiscInfo', 'U') IS NOT NULL  DROP TABLE #MiscInfo
CREATE TABLE	#MiscInfo (
	CompanyName			VarChar(50),
	SiteName			VarChar(50),
	RptOwnerDesc		VarChar(50),
	RptStartDateTime 	VarChar(25),
	RptEndDateTime		VarChar(25),
	ShiftFilter			VarChar(50),
	CrewFilter			VarChar(50),
	LineStatusFilter	VarChar(1000),
	ProductFilter		VarChar(1000),
	RptTitle			VarChar(255),
	MajorGroupBy		VarChar(25),
	CommentColWidth		Int,
	CommentTableFlag	Int )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#HdrInfo', 'U') IS NOT NULL  DROP TABLE #HdrInfo
CREATE TABLE	#HdrInfo (
	PUId					Int,
	LineStatusId			Int,
	ProdId					Int,
	PUDesc					VarChar(50),
	LineStatusDesc			VarChar(50),
	ProdCode				VarChar(50),
	ShiftDesc				VarChar(10),
	CrewDesc				VarChar(10),
	TotalUptime				VarChar(50),
	TotalDowntime			VarChar(50),
	-- FO-00847-B: 2) Add Total Unplanned Downtime to Stop Summary section 
	TotalDownTimeUnplan		VarChar(50),	
	TotalStops				Int,
	TotalStopsUnplan		Int,
	TotalUpTimeGreaterThan0	Int,
	TotalUpTimeGreaterThanT	Int,
	SucStarts				Int,
	R0						VarChar(10),
	RT						VarChar(10),
	-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
	MTBS					VarChar(10),
	MTTR					VarChar(10),
	-- FO-00847-B: 3) Add MTBF defined as Total Uptime / Total Unplanned Downtime to Stop Summary section
	MTBF					VarChar(10),	
	Availability			VarChar(10),
	AvailableTimeInMin		VarChar(10) )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#PUList', 'U') IS NOT NULL  DROP TABLE #PUList
CREATE TABLE	#PUList (
	RcdId			Int,
	PLId			Int,
	PLDesc			VarChar(100),
	PUId			Int,
	PUDesc			VarChar(100),
	AlternativePUId	Int,				-- This PUId will be used if no schedule or line status has been configured for
										-- the selected PUId
	LookUpPUId		Int )				-- Coalesce between PUId and AlternativePUId
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FilterLineStatusList', 'U') IS NOT NULL  DROP TABLE #FilterLineStatusList
CREATE TABLE	#FilterLineStatusList (
	RcdId			Int,
	LineStatusId	Int,
	LineStatusDesc	VarChar(100) )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FilterProdList', 'U') IS NOT NULL  DROP TABLE #FilterProdList
CREATE TABLE	#FilterProdList (
	RcdId		Int,
	ProdId		Int,
	ProdDesc	VarChar(50),
	ProdCode	VarChar(50))	
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FilterShiftList', 'U') IS NOT NULL  DROP TABLE #FilterShiftList
CREATE TABLE	#FilterShiftList (
	RcdId		Int,
	ShiftDesc	VarChar(50))	
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FilterCrewList', 'U') IS NOT NULL  DROP TABLE #FilterCrewList
CREATE TABLE	#FilterCrewList (
	RcdId		Int,
	CrewDesc	VarChar(50))	
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ReasonsToExclude', 'U') IS NOT NULL  DROP TABLE #ReasonsToExclude
CREATE TABLE	#ReasonsToExclude(  
	ERC_id		int,  
	ERC_Desc	nvarchar(100))  
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FilterSourcePUList', 'U') IS NOT NULL  DROP TABLE #FilterSourcePUList
CREATE TABLE	#FilterSourcePUList (
	RcdId		Int,
	SourcePUId	Int )	
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FilterEventReasonIdList', 'U') IS NOT NULL  DROP TABLE #FilterEventReasonIdList
CREATE TABLE	#FilterEventReasonIdList (
	RcdId			Int,
	ReasonLevelId	Int,
	EventReasonId	Int )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#LineStatusList', 'U') IS NOT NULL  DROP TABLE #LineStatusList
CREATE TABLE	#LineStatusList (
	PUId				Int,
	LineStatusSchedId	Int,
	LineStatusId		Int,
	LineStatusDesc		VarChar(50),
	LineStatusStart		DateTime,
	LineStatusEnd		DateTime )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ShiftList', 'U') IS NOT NULL  DROP TABLE #ShiftList
CREATE TABLE	#ShiftList (
	CSId			Int,
	PUId			Int,
	ShiftDesc		VarChar(10),
	CrewDesc		VarChar(10),
	ShiftStart		DateTime,
	ShiftEnd		DateTime )		
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#VisibleFieldList', 'U') IS NOT NULL  DROP TABLE #VisibleFieldList
CREATE TABLE	#VisibleFieldList (
	RcdId		Int,
	ColOrder	Int,
	FieldName	VarChar(50))
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#DelayDetail', 'U') IS NOT NULL  DROP TABLE #DelayDetail
CREATE TABlE	#DelayDetail (
	PLId						Int,
	PUId						Int,			-- Master Unit
	ProdId						Int,
	LineStatusId				Int,
	LineStatusSchedId			Int,
	ShiftDesc					VarChar(25),
	CrewDesc					VarChar(25),
	DetId						Int,
	ParentId					Int,
	DelayCount					Int,
	MachineRcdEntry				Int,				-- Options: 0 record split was done manually, 1 record split was done by a machine
													-- so it counts as a stop
	UserId						Int,
	UpTimeStart					DateTime,
	UpTimeEnd					DateTime,
	UpTimeDurationInSec			Int,
	UpTimeGreaterThan0Count		Int Default 0,
	UpTimeGreaterThanTCount		Int Default 0,
	ProductionDay				VarChar(25),
	DelayStart					DateTime,
	DelayEnd					DateTime,
	DelayDurationInSec			Int,
	OffSetFromMidnightInSec		Int,
	DelayGreaterThanTCount		Int Default 0,
	MasterDelayStart			DateTime,
	MasterDelayEnd				DateTime,
	MasterDelayDurationInSec	Int,
	DelayTreeId					Int,
	DelayTreeNodeId				Int,
	TEFaultId					Int,
	SourcePUId					Int,		
	DelayRL1Id					Int,
	DelayRL2Id					Int,
	DelayRL3Id					Int,
	DelayRL4Id					Int,
	EventReasonName1			VarChar(100),
	EventReasonName2			VarChar(100),
	EventReasonName3			VarChar(100),
	EventReasonName4			VarChar(100),
	CauseCommentId				VarChar(1000),
	SummaryCauseCommentId		VarChar(1000),
	DelayCommentIdList			Varchar(1000),
	ERCId						Int,
	DelayCategoryDesc			VarChar(100),
	OverlapFlagShift			Int Default 0,		-- The overlap fields are used in the logic that split records
	OverlapFlagLineStatus		Int Default 0,		-- accross shifts and line status boundaries. The fields are zeroed	
	OverlapSequence				Int,					-- out after the record has been split
	OverlapRcdFlag				Int Default 0,		
	SplitFlagShift				Int Default 0,		-- Used for debugging only: marks records that have been split at shift boundaries
	SplitFlagLineStatus			Int Default 0,  	-- Used for debugging only: marks records that have been split at line status boundaries
	UpTimeRcdFlag				VarChar(1) )

---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FinalResultSet', 'U') IS NOT NULL  DROP TABLE #FinalResultSet
CREATE TABLE	#FinalResultSet (
	RcId				INT IDENTITY,
	PUId				Int,
	ProdId				Int,
	Border1				VarChar(1),
	PLDesc				VarChar(100),
	PUDesc				VarChar(100),
	DelayStart			VarChar(25),	-- from #DelayDetail	
	ProductionDay		VarChar(25),
	ProdCode			VarChar(50), 	-- from dbo.Products
	ProdDesc			VarChar(550), 	-- from dbo.Products
	ShiftDesc			VarChar(50),	-- from dbo.Crew_Schedule
	CrewDesc			VarChar(50),	-- from dbo.Crew_Schedule
	ProdStatus			VarChar(50),	-- from dbo.Local_PG_LineStatus
	TEFaultValue		VarChar(100), 	-- from dbo.Timed_Event_Fault
	SourcePUDesc		VarChar(100),	-- from dbo.Prod_Units
	EventReasonName1	VarChar(100), 	-- from dbo.Event_Reasons
	EventReasonName2	VarChar(100), 	-- from dbo.Event_Reasons
	EventReasonName3	VarChar(100), 	-- from dbo.Event_Reasons
	EventReasonName4	VarChar(100), 	-- from dbo.Event_Reasons
	DelayCategoryDesc	VarChar(100),	-- from dbo.Event_Reason_Catagories
	UpTime				FLOAT,			-- from #DelayDetail: 	UptimeDurationInSec/60
	DownTime			FLOAT,			-- from #DelayDetail:	DelayDurationInSec/60
	Stops				Int,
	StopsGreaterThanT	Int,
	UpTimeGreaterThanT	Int,
	PercentStops		FLOAT,
	MTTR				FLOAT,
	-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
	MTBS				FLOAT,
	Availability		FLOAT,
	CommentIdList		VarChar(1000),
	Comments			NVARCHAR(MAX),
	NextComment_Id		VarChar(1000),
	Border2				Int,
	TotalStops			Int,
	TotalUptime			Float,
	AvailableTimeInMin	Float,
	StopsPerMSU			Int,
	DownPerMSU			Int )

--=================================================================================================
-- PRINT '	.	Initialize Temp Tables' 
-- Done to minimize recompiles
--=================================================================================================
SET @i = (SELECT 	Count(*) 	FROM	#MiscInfo)
SET @i = (SELECT	Count(*) 	FROM 	#HdrInfo)
SET @i = (SELECT	Count(*) 	FROM 	#PUList)
SET @i = (SELECT	Count(*) 	FROM	#FilterProdList)
SET @i = (SELECT	Count(*) 	FROM	#FilterShiftList)
SET @i = (SELECT	Count(*)	FROM	#FilterCrewList)
SET @i = (SELECT	Count(*) 	FROM	#FilterEventReasonIdList)
SET @i = (SELECT	Count(*)	FROM	#LineStatusList)
SET @i = (SELECT	Count(*) 	FROM	#ShiftList)
SET @i = (SELECT	Count(*) 	FROM 	#VisibleFieldList)
SET @i = (SELECT	Count(*) 	FROM 	#DelayDetail)
SET @i = (SELECT	Count(*) 	FROM	#FinalResultSet)
set @i = (SELECT	Count(*)	FROM	#ReasonsToExclude)  


--================================================================================================= 
-- GET GLOBAL PARAMETERS  
--=================================================================================================
SELECT @RptSUFactor 				= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_SUFactor'),'240')		
SELECT @RptT 						= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_T'), 2)		
SELECT @RptTDowntime 				= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_TDowntime'),5)	
SELECT @RptShiftStart 				= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_StartShift'),'6:30:00')	
SELECT @RptShiftLength				= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_ShiftLength'),8)	
SELECT @RptStrCategoriesToExclude 	= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_StrCategoriesToExclude'),'!Null')	
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- PRINT	'	- Check Parameters '
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Check Parameter: Database version
---------------------------------------------------------------------------------------------------
IF	(	SELECT		IsNumeric(App_Version)
			FROM	dbo.AppVersions WITH(NOLOCK)
			WHERE	App_Id = 2) = 1
BEGIN
	SELECT		@fltDBVersion = Convert(Float, App_Version)
		FROM	dbo.AppVersions WITH(NOLOCK)
		WHERE	App_Id = 2
END
ELSE
BEGIN
	SELECT	@fltDBVersion = 1.0
END
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	DBVersion: ' + RTrim(LTrim(Str(@fltDBVersion, 10, 2))) -- debug
---------------------------------------------------------------------------------------------------
-- Check Parameter: Company, Site Name and report owner description
---------------------------------------------------------------------------------------------------
SELECT		@chrCompanyName = Coalesce(Value, 'Company Name')
	FROM 	dbo.Site_Parameters WITH(NOLOCK)
	WHERE 	Parm_Id = 11
---------------------------------------------------------------------------------------------------
SELECT		@chrSiteName = Coalesce(Value, 'Site Name')
	FROM 	dbo.Site_Parameters WITH(NOLOCK)
	WHERE 	Parm_Id = 12
---------------------------------------------------------------------------------------------------
SELECT	@chrRptOwnerDesc = Coalesce(User_Desc, UserName)
	FROM	dbo.Users WITH(NOLOCK)
	WHERE	User_Id = @RptOwnerId
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Reporting Period'
---------------------------------------------------------------------------------------------------
-- Check Parameter: Reporting period
---------------------------------------------------------------------------------------------------
SET	@dtmStartDateTime	=	Convert(DateTime, 	@RptStartDateTime)
SET	@dtmEndDateTime		=	Convert(DateTime,	@RptEndDateTime)
--
IF	@dtmStartDateTime > @dtmEndDateTime
BEGIN
	SELECT 3 ErrorCode
--	RETURN 3
END
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Production Unit List'
---------------------------------------------------------------------------------------------------
-- Check Parameter: Production Unit list
---------------------------------------------------------------------------------------------------
SET	@RptPUIdlist = IsNull(@RptPUIdList,'')
IF	Len(@RptPUIdList) = 0	
OR	@RptPUIdList = '!Null'
BEGIN
	SELECT 4 ErrorCode
--	RETURN 4
END


---------------------------------------------------------------------------------------------------
-- Check Parameter: Production Unit list
---------------------------------------------------------------------------------------------------
SELECT		@intReliabilityUserId = User_Id
	FROM	dbo.Users WITH(NOLOCK)
	WHERE	UserName = 'ReliabilitySystem'
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- PRINT	'- Prepare Tables '
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Filter Production Units'	
---------------------------------------------------------------------------------------------------
INSERT INTO 	#PUList (RcdId, PUId)
EXEC 	spCmn_ReportCollectionParsing
		@PRMCollectionString = @RptPUIdList, 
		@PRMFieldDelimiter = Null, 
		@PRMRecordDelimiter = '|',
		@PRMDataType01 = 'Int'
---------------------------------------------------------------------------------------------------
-- Filter Products
---------------------------------------------------------------------------------------------------
IF	Len(IsNull(@RptProdIdList, '')) > 0 AND @RptProdIdList <> '!Null'
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Filter Products'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#FilterProdList (RcdId, ProdId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptProdIdList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'Int'
	---------------------------------------------
	UPDATE	pl
		SET	ProdDesc = Prod_Desc,
				ProdCode = Prod_Code
		FROM	#FilterProdList	pl
		JOIN	dbo.Products				p WITH(NOLOCK)	ON pl.ProdId = p.Prod_Id	
END
---------------------------------------------------------------------------------------------------
-- Filter Shifts
---------------------------------------------------------------------------------------------------
IF	@RptShiftDescList <> 'All'
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Filter Shifts'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#FilterShiftList (RcdId, ShiftDesc)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptShiftDescList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = ',',
			@PRMDataType01 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
-- Filter Crews
---------------------------------------------------------------------------------------------------
IF @RptCrewDescList <> 'All'
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Filter Crews'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#FilterCrewList (RcdId, CrewDesc)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptCrewDescList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = ',',
			@PRMDataType01 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
-- Filter Line Status
---------------------------------------------------------------------------------------------------
IF @RptLineStatusIdList <> 'All'
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Filter Line Status'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#FilterLineStatusList (RcdId, LineStatusId, LineStatusDesc)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptLineStatusIdList, 
			@PRMFieldDelimiter 	= '^', 
			@PRMRecordDelimiter 	= ',',
			@PRMDataType01 		= 'Int',
			@PRMDataType02 		= 'VarChar(50)'
END

---------------------------------------------------------------------------------------------------
-- Filter Categories
---------------------------------------------------------------------------------------------------
IF		Len(IsNull(@RptStrCategoriesToExclude, '')) > 0 
AND 	@RptStrCategoriesToExclude <> '!Null'
BEGIN
	Insert #ReasonsToExclude(ERC_Id,ERC_Desc)  
		Exec SPCMN_ReportCollectionParsing  
		@PRMCollectionString = @RptStrCategoriesToExclude, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',   
		@PRMDataType01 = 'nvarchar(100)'  
  
	UPDATE #ReasonsToExclude  
		Set ERC_Id = erc.erc_id  
		FROM dbo.Event_Reason_Catagories  erc WITH(NOLOCK)  
		Join #ReasonsToExclude rte on erc.erc_desc = rte.ERC_Desc       
    
End  

-- SELECT '#ReasonsToExclude',* FROM #ReasonsToExclude

---------------------------------------------------------------------------------------------------
-- Filter Location
---------------------------------------------------------------------------------------------------
IF 	@RptSourcePUIdList <> '!Null'	
AND 	Len(IsNull(@RptSourcePUIdList, '')) > 0
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Filter Location'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#FilterSourcePUList (RcdId, SourcePUId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptSourcePUIdList, 
			@PRMFieldDelimiter 	= Null, 
			@PRMRecordDelimiter 	= '|',
			@PRMDataType01 		= 'Int'
END
---------------------------------------------------------------------------------------------------
-- Filter event reasons
---------------------------------------------------------------------------------------------------
IF 	@RptEventReasonIdList <> '!Null' 
AND Len(IsNull(@RptEventReasonIdList, '')) > 0
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Filter Event Reasons 1'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#FilterEventReasonIdList (RcdId, ReasonLevelId, EventReasonId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptEventReasonIdList, 
			@PRMFieldDelimiter = '~', 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'Int',
			@PRMDataType02 = 'Int'
END
---------------------------------------------------------------------------------------------------
-- Column Visibility
---------------------------------------------------------------------------------------------------
IF @RptStopHistoryColumnVisibility <> 'None'
BEGIN
	------------------------------------------------------------------------------------------------
	-- PRINT	'	.	Column Visibility'	
	------------------------------------------------------------------------------------------------
	INSERT INTO 	#VisibleFieldList (RcdId, FieldName)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptStopHistoryColumnVisibility, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Get Production Unit Description and Production Line'	
---------------------------------------------------------------------------------------------------
UPDATE		pul
	SET		pul.PUDesc 			= 	pu.PU_Desc,
			pul.AlternativePUId	=	Case	WHEN	(CharIndex	('STLS=', pu.Extended_Info, 1)) > 0
											THEN	Substring	(	pu.Extended_Info,
												(	CharIndex	('STLS=', pu.Extended_Info, 1) + 5),
													Case 	WHEN 	(CharIndex(';', pu.Extended_Info, CharIndex('STLS=', pu.Extended_Info, 1))) > 0
															THEN 	(CharIndex(';', pu.Extended_Info, CharIndex('STLS=', pu.Extended_Info, 1)) - (CharIndex('STLS=', pu.Extended_Info, 1) + 5)) 
															ELSE 	Len(pu.Extended_Info)
													END )
									END,
			pul.PLId			=	pu.PL_Id,
			pul.PLDesc			=	pl.PL_Desc
	FROM	dbo.Prod_Units	pu	WITH(NOLOCK)
	JOIN	#PUList			pul	ON	pul.PUId = pu.PU_Id
	JOIN	dbo.Prod_Lines	pl	WITH(NOLOCK) ON	pu.PL_Id = pl.PL_Id
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Update LookUp PUId'	
---------------------------------------------------------------------------------------------------
UPDATE		pl
	SET		pl.LookUpPUId	= 	Coalesce(pl.AlternativePUId, pl.PUId)
	FROM	#PUList	pl			
---------------------------------------------------------------------------------------------------
-- PRINT '	.	TimeIntervals: Get Shifts'
---------------------------------------------------------------------------------------------------
SELECT	@intShiftLengthInMin = 	@RptShiftLength * 60
SELECT	@intShiftOffsetInMin = 	DatePart(Hour, @RptShiftStart) * 60 + DatePart(Minute, @RptShiftStart)
---------------------------------------------------------------------------------------------------
-- PRINT '		ShiftSchedCursor' 
---------------------------------------------------------------------------------------------------
SET	@i = 1
DECLARE	ShiftScheduleCursor INSENSITIVE CURSOR FOR (
SELECT	PUId,
			LookUpPUId
	FROM	#PUList )
ORDER	BY PUId
FOR READ ONLY
OPEN	ShiftScheduleCursor
FETCH	NEXT FROM ShiftScheduleCursor INTO @c_intPUId, @c_intLookUpPUId
WHILE	@@Fetch_Status = 0
BEGIN
	------------------------------------------------------------------------
	-- Time Interval Get Shifts:
	-- If there is a Crew Schedule for some or all production units
	-- PRINT '		PUId = ' + Convert(VarChar(25), @c_intPUId)
	-------------------------------------------------------------------------

	IF (	SELECT 	Count(Start_Time) 
				FROM	dbo.Crew_Schedule WITH(NOLOCK)
				WHERE	PU_Id = @c_intLookUpPUId
				AND 	Start_Time 	<= @dtmEndDateTime 
				AND 	End_Time 	> 	@dtmStartDateTime ) > 0
	BEGIN
		INSERT INTO	#ShiftList (
					CSId,
					PUId,
					ShiftDesc,	
					CrewDesc,
					ShiftStart,	
					ShiftEnd )
			SELECT	CS_Id,
					@c_intPUId,
					Shift_Desc,	
					Crew_Desc,
					Start_Time,	
					End_Time 
			FROM	dbo.Crew_Schedule WITH(NOLOCK)
			WHERE	PU_Id = @c_intLookUpPUId
			AND 	Start_Time 	<= 	@dtmEndDateTime 
			AND 	End_Time 	> 	@dtmStartDateTime
	END
	ELSE
	-----------------------------------------------------------------------
	-- Time Interval Get Shifts:
	-- Use default crew schedule for units that do not have crew schedule 
	-- configured
	-----------------------------------------------------------------------
	BEGIN
		SELECT	@dtmBaseDate 		= Convert(DateTime, Convert(VarChar(25), @dtmStartDateTime,102))
		SELECT	@dtmShiftDay		= DateAdd(Minute, @intShiftOffSetInMin, @dtmBaseDate)
		SELECT	@intShiftMaxCount 	= (24 * 60) / @intShiftLengthInMin
		SELECT	@intShiftDesc		= 1
		----------------------------------------
		IF	@dtmStartDateTime < @dtmShiftDay
		BEGIN
			SELECT	@dtmShiftDay 	= DateAdd(Minute, -@intShiftLengthInMin, @dtmShiftDay)
			SELECT	@intShiftDesc 	= @intShiftMaxCount
		END
		----------------------------------------
		WHILE	@dtmShiftDay < @dtmEndDateTime
		BEGIN
			INSERT INTO	#ShiftList (
							CSId,
							PUId,
							ShiftStart,
							ShiftEnd,
							ShiftDesc,
							CrewDesc )
				SELECT	@i,
							@c_intPUId,
							@dtmShiftDay, 
							DateAdd(Minute, @intShiftLengthInMin, @dtmShiftDay),
							@intShiftDesc,
							@intShiftDesc
			----------------------------------------
			IF	@intShiftDesc >= @intShiftMaxCount
			BEGIN
				SELECT	@intShiftDesc = 1
			END
			ELSE
			BEGIN
				SELECT	@intShiftDesc = @intShiftDesc + 1
			END
			----------------------------------------
			SET	@i = @i + 1
			SET	@dtmShiftDay = DateAdd(Minute, @intShiftLengthInMin, @dtmShiftDay)
		END
	END
	----------------------------------------------
	FETCH	NEXT FROM ShiftScheduleCursor INTO @c_intPUId, @c_intLookUpPUId
-------------------------------------------------
END
CLOSE			ShiftScheduleCursor
DEALLOCATE 	ShiftScheduleCursor
-------------------------------------------------------------------------------
-- PRINT '		LineStatus' 
-------------------------------------------------------------------------------
INSERT INTO		#LineStatusList (
				PUId,
				LineStatusSchedId,
				LineStatusId,
				LineStatusDesc,
				LineStatusStart,
				LineStatusEnd )
	SELECT		pl.PUId,
				Status_Schedule_Id,
				Line_Status_Id,
				Phrase_Value,
				Case	WHEN	Start_DateTime <	@dtmStartDateTime
						THEN	@dtmStartDateTime
						ELSE	Start_DateTime
				END,
				Case	WHEN	Coalesce(End_DateTime, GetDate()) > @dtmEndDateTime
						THEN	@dtmEndDateTime
						ELSE	End_DateTime
				END
		FROM	dbo.Local_PG_Line_Status 	ls WITH(NOLOCK)
		JOIN	dbo.Phrase 					p  WITH(NOLOCK)	ON 	ls.Line_Status_Id = p.Phrase_Id
												/*AND	p.Data_Type_Id = (	SELECT		Data_Type_Id
																			FROM	Data_Type
																			WHERE	Data_Type_Desc = 'Line Status')*/
		JOIN	#PUList						pl	ON	pl.LookUpPUId = ls.Unit_Id						
		WHERE	Start_DateTime < 	@dtmEndDateTime
		AND		(End_DateTime  >	@dtmStartDateTime OR End_DateTime IS NULL)

--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- PRINT	'	- DelayDetails '
---------------------------------------------------------------------------------------------------
-- PRINT '	.	Obtain the Delay details for the specified time period'
---------------------------------------------------------------------------------------------------
INSERT INTO 	#DelayDetail (
				DetId,
				DelayStart, 
				DelayEnd,
				PLId,
				PUId,
				SourcePUId, 
				TEFaultId,
				DelayRL1Id, 
				DelayRL2Id, 
				DelayRL3Id, 
				DelayRL4Id,
				DelayTreeNodeId,
				MachineRcdEntry,
				UserId )
	SELECT 		d.TEDet_Id, 
				d.Start_Time, 
				Coalesce(d.End_Time, GetDate()),
				pu.PLId,
				pu.PUId,
				d.Source_PU_Id,
				d.TEFault_Id,
				d.Reason_Level1,
				d.Reason_Level2,
				d.Reason_Level3,
				d.Reason_Level4,
				d.Event_Reason_Tree_Data_Id,
				Case	WHEN	Min(d.Initial_User_Id) < 50
						THEN	1
						WHEN	Min(d.Initial_User_Id) = @intReliabilityUserId
						THEN	1
						ELSE	0
				END,
				Min(d.Initial_User_Id)
		FROM 			dbo.Timed_Event_Details 		d  WITH(NOLOCK)
		INNER	JOIN 	#PUList							pu	ON	pu.PUId = d.PU_Id
		WHERE 	d.Start_Time 	<= @dtmEndDateTime 
		AND 	(	d.End_Time  >  @dtmStartDateTime 
		OR 			d.End_Time IS NULL)
		GROUP BY	d.TEDet_Id, d.Start_Time, d.End_Time, pu.PLId, pu.PUId, d.Source_PU_Id, 
					d.TEFault_Id, d.Reason_Level1, d.Reason_Level2, d.Reason_Level3, d.Reason_Level4,
					d.Event_Reason_Tree_Data_Id

--Tuned for performance 
	UPDATE d SET EventReasonName1 = r1.Event_Reason_Name,
				EventReasonName2 = r2.Event_Reason_Name,
				EventReasonName3 = r3.Event_Reason_Name,
				EventReasonName4 = r4.Event_Reason_Name
		FROM #DelayDetail d
		LEFT JOIN dbo.Event_Reasons r1 WITH(NOLOCK) ON d.DelayRL1Id = r1.Event_Reason_Id
		LEFT JOIN dbo.Event_Reasons r2 WITH(NOLOCK) ON d.DelayRL2Id = r2.Event_Reason_Id
		LEFT JOIN dbo.Event_Reasons r3 WITH(NOLOCK) ON d.DelayRL3Id = r3.Event_Reason_Id
		LEFT JOIN dbo.Event_Reasons r4 WITH(NOLOCK) ON d.DelayRL4Id = r4.Event_Reason_Id

-------------------------------------------------------------------------------
-- PRINT '	.	Get list of delay records that overlapp report period start'
-------------------------------------------------------------------------------
INSERT INTO		@tblRptStartOverlappingRcds (
				DetId,
				DelayStart )
	SELECT		DetId,	
				DelayStart
		FROM	#DelayDetail
		WHERE	DelayStart	<= @dtmStartDateTime
---------------------------------------------------------------------------------------------------
-- PRINT '	.	Get Comments'
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Delay: Get the comments
---------------------------------------------------------------------------------------------------

IF	@fltDBVersion <= 300215.90 
BEGIN
	-----------------------------------------------------------------------------------------------
	-- PRINT '		Summary Comments'
	-----------------------------------------------------------------------------------------------
	-- Delay: Get summary comments
	-----------------------------------------------------------------------------------------------
	SET	@intCommentTableFlag = 2
	--
	DECLARE	SummaryCommentCursor1 INSENSITIVE CURSOR FOR (
	SELECT	DetId
		FROM	#DelayDetail dd
		JOIN	dbo.Waste_n_Timed_Comments wt WITH(NOLOCK) ON dd.DetId = wt.WTC_Source_Id
		WHERE	WTC_Type = 1 
	GROUP BY	DetId)
	FOR READ ONLY
	OPEN	SummaryCommentCursor1
	FETCH	NEXT FROM SummaryCommentCursor1 INTO @c_intDetId
	WHILE	@@Fetch_Status = 0
	BEGIN
		-------------------------------------------------------------------------------------------
		-- PRINT 'DetId: ' + Convert(VarChar, @c_intDetId)
		-------------------------------------------------------------------------------------------
		SET	@chrTempString = ''
		--
		DECLARE	SummaryCommentCursor2 INSENSITIVE CURSOR FOR (
		SELECT	WTC_Id
			FROM	dbo.Waste_n_Timed_Comments wt WITH(NOLOCK)
			WHERE	WTC_Type = 1
			AND	WTC_Source_Id = @c_intDetId )
		FOR READ ONLY
		OPEN	SummaryCommentCursor2
		FETCH	NEXT FROM SummaryCommentCursor2 INTO @c_intWTCId
		WHILE	@@Fetch_Status = 0
		BEGIN
			--
			SET	@chrTempString = @chrTempString + '|' +Convert(VarChar, @c_intWTCId)
			--
		FETCH	NEXT FROM SummaryCommentCursor2 INTO @c_intWTCId

		--
		UPDATE	#DelayDetail
			SET	SummaryCauseCommentId = Substring(LTrim(RTrim(@chrTempString)), 2, Len(@chrTempString))
			WHERE	DetId = @c_intDetId
		--
		END
		CLOSE			SummaryCommentCursor2
		DEALLOCATE 	SummaryCommentCursor2		
		-------------------------------------------------------------------------------------------
		-- PRINT 'WTCIdList: ' + @chrTempString
		-------------------------------------------------------------------------------------------
		FETCH	NEXT FROM SummaryCommentCursor1 INTO @c_intDetId
	--
	END
	CLOSE			SummaryCommentCursor1
	DEALLOCATE 	SummaryCommentCursor1

    Select @chrTempString = ''


	-----------------------------------------------------------------------------------------------
	-- PRINT '		Detail Comment'
	-----------------------------------------------------------------------------------------------
	-- Delay: Get detail comments
	-----------------------------------------------------------------------------------------------
	DECLARE	DetailCommentCursor1 INSENSITIVE CURSOR FOR (
	SELECT	DetId
		FROM	#DelayDetail dd
		JOIN	dbo.Waste_n_Timed_Comments wt WITH(NOLOCK) ON dd.DetId = wt.WTC_Source_Id
		WHERE	WTC_Type = 2 )
	FOR READ ONLY
	OPEN	DetailCommentCursor1
	FETCH	NEXT FROM DetailCommentCursor1 INTO @c_intDetId
	WHILE	@@Fetch_Status = 0
	BEGIN
		------------------------------------------------------------------------
		--PRINT 'DetId: ' + Convert(VarChar, @c_intDetId)
		------------------------------------------------------------------------
		SET	@chrTempString = ''
		DECLARE	DetailCommentCursor2 INSENSITIVE CURSOR FOR (
		SELECT	WTC_Id
			FROM	dbo.Waste_n_Timed_Comments wt WITH(NOLOCK)
			WHERE	WTC_Type = 2
			AND	WTC_Source_Id = @c_intDetId )
		FOR READ ONLY
		OPEN	DetailCommentCursor2
		FETCH	NEXT FROM DetailCommentCursor2 INTO @c_intWTCId
		WHILE	@@Fetch_Status = 0
		BEGIN
			--
			SET	@chrTempString = @chrTempString + '|' + Convert(VarChar, @c_intWTCId)
            
			--
		FETCH	NEXT FROM DetailCommentCursor2 INTO @c_intWTCId
		--
		END
		CLOSE			DetailCommentCursor2
		DEALLOCATE 	DetailCommentCursor2
	--
    

	UPDATE	#DelayDetail
		SET	CauseCommentId = Substring(LTrim(RTrim(@chrTempString)), 2, Len(@chrTempString))
		WHERE	DetId = @c_intDetId
	--
	FETCH	NEXT FROM DetailCommentCursor1 INTO @c_intDetId
	------------------------------------------------------------------------
	-- PRINT '		WTCIdList: ' + @chrTempString
	------------------------------------------------------------------------
	END
	CLOSE			DetailCommentCursor1
	DEALLOCATE 	DetailCommentCursor1
	------------------------------------------------------------------------
END
ELSE
BEGIN

	SET	@intCommentTableFlag = 1
	---------------------------------------------
	
	SET @chrSQLCommand1 = ' UPDATE	dd ' 
		+		' SET	CauseCommentId 			= Cause_Comment_Id, '
		+		' SummaryCauseCommentId 	= Summary_Cause_Comment_Id '
		+ ' FROM	dbo.Timed_Event_Details ted WITH(NOLOCK) '
		+ ' JOIN	#DelayDetail dd ON dd.DetId = ted.TEDet_Id '
	
	EXEC (@chrSQLCommand1)
	
END

-------------------------------------------------------------------------------
-- PRINT '	.	Trim records for reporting period'
-------------------------------------------------------------------------------
-- Delay: Trim the records to the reporting period constraints
-------------------------------------------------------------------------------
UPDATE	#DelayDetail 
	SET	DelayStart	= Case	WHEN DelayStart < @dtmStartDateTime THEN @dtmStartDateTime 
										ELSE DelayStart 
										END,
			DelayEnd 	= Case	WHEN DelayEnd > @dtmEndDateTime THEN @dtmEndDateTime 
										ELSE DelayEnd 
										END
---------------------------------------------------------------------------------------------------
-- PRINT '	.	Update parent Id' 
---------------------------------------------------------------------------------------------------
-- Delay: Update the ParentId if the record has a "parent" record.
---------------------------------------------------------------------------------------------------
UPDATE		d 
	SET		ParentId = pd.DetId
	FROM 	#DelayDetail d 
	JOIN	#DelayDetail pd 	ON	d.DelayStart = pd.DelayEnd
	WHERE 	d.DetId <> pd.DetId
---------------------------------------------------------------------------------------------------
-- PRINT '	.	Get Reasons and Tree Nodes'
---------------------------------------------------------------------------------------------------
-- Delay: Determine which Reason trees are associated with the PUID's
---------------------------------------------------------------------------------------------------
UPDATE 		dd
	SET 	DelayTreeId = pe.Name_Id
	FROM	#DelayDetail dd 
	JOIN 	dbo.Prod_Events pe WITH(NOLOCK) ON Coalesce(dd.SourcePUId, dd.PUID) = pe.PU_Id
	WHERE	pe.Event_Type = 2 -- Event_type = 2 (Delay)

---------------------------------------------------------------------------------------------------
-- PRINT '	.	Update Delay count'
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	DelayCount 	=	Case 	WHEN 	ParentId IS NULL 
								THEN 	1 
								ELSE 	0 
						END
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	DelayCount 	=	Case 	WHEN 	MachineRcdEntry = 1 
								THEN 	1 
								ELSE 	0 
						END
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Set DelayCount = 0 on records that ovelap the reporting period start'
---------------------------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		DelayCount	 = 0
	FROM	#DelayDetail				dd
	JOIN	@tblRptStartOverlappingRcds	so	ON	dd.DetId = so.DetId
-------------------------------------------------------------------------------
-- PRINT '	.	Update Master Delay Start'
-------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		MasterDelayStart = DelayStart
	WHERE	DelayCount = 1
-------------------------------------------------------------------------------
--PRINT '	.	Update Master Delay End'
-------------------------------------------------------------------------------
DECLARE	MasterDelayRcdCursor INSENSITIVE CURSOR 
FOR (	SELECT		DetId
			FROM	#DelayDetail
			WHERE	DelayCount = 1 )
FOR READ ONLY
OPEN	MasterDelayRcdCursor
FETCH	NEXT FROM MasterDelayRcdCursor INTO @c_intDetId
WHILE	@@Fetch_Status = 0
BEGIN
--
	IF	(SELECT		Count(*)
			FROM	#DelayDetail
			WHERE	ParentId = @c_intDetId ) > 0
	BEGIN
		SET	@i = 1
		SET	@intDetId1 = @c_intDetId
		--
		WHILE	@i > 0
		BEGIN
			SELECT	@i = Count(DetId)	
				FROM	#DelayDetail
				WHERE	ParentId = @intDetId1
			--
			IF	@i > 0
			BEGIN	
				SELECT	@intDetId2 = DetId
					FROM	#DelayDetail
					WHERE	ParentId = 	@intDetId1	
				--
				SET	@intDetId1 = @intDetId2				
			END
			ELSE
			BEGIN
				SELECT	@dtmMasterDelayEnd = DelayEnd
					FROM	#DelayDetail
					WHERE	DetId = @intDetId1
			BREAK
			END
		END
	END
	ELSE
	BEGIN
		SELECT	@dtmMasterDelayEnd = DelayEnd
			FROM	#DelayDetail
			WHERE	DetId = @c_intDetId	
	END
	--
	UPDATE	#DelayDetail
		SET	MasterDelayEnd = @dtmMasterDelayEnd
		WHERE	DetId = @c_intDetId		
	--
	FETCH	NEXT FROM MasterDelayRcdCursor INTO @c_intDetId
--
END
CLOSE			MasterDelayRcdCursor
DEALLOCATE 	MasterDelayRcdCursor
-------------------------------------------------------------------------------
-- Delay: Update Master Duration
-------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	MasterDelayDurationInSec = DateDiff(Second, MasterDelayStart, MasterDelayEnd)
-------------------------------------------------------------------------------
-- Delay: Find Product
-------------------------------------------------------------------------------
UPDATE	dd
	SET	ProdId 	=	Prod_Id
	FROM	#DelayDetail dd
	JOIN	dbo.Production_Starts ps WITH(NOLOCK) ON dd.PUId = ps.PU_Id
	WHERE	DelayStart >= ps.Start_Time
	AND	(DelayStart < ps.End_Time OR ps.End_Time IS NULL)
-------------------------------------------------------------------------------
-- Delay: Find Shift and Crew
-------------------------------------------------------------------------------
UPDATE	dd
	SET	dd.ShiftDesc 	=	sl.ShiftDesc,
			dd.CrewDesc		=	sl.CrewDesc
	FROM	#DelayDetail dd
	JOIN	#ShiftList sl ON dd.PUId = sl.PUId
	WHERE	DelayStart 	>= sl.ShiftStart
	AND	(DelayStart <	sl.ShiftEnd OR sl.ShiftEnd IS NULL)
--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT	'	- Split overlapping records '
---------------------------------------------------------------------------------------------------
--	Delay: Split overlapping shift records
---------------------------------------------------------------------------------------------------
UPDATE		dd
	SET		OverlapFlagShift 	= sl.CSId,
			OverlapSequence 	= 1,
			OverlapRcdFlag 		= 1,
			SplitFlagShift 		= 1
	FROM	#DelayDetail 	dd
	JOIN	#ShiftList 		sl ON sl.PUId = dd.PUId
	WHERE	DelayStart 	< sl.ShiftStart
	AND		DelayEnd 	> sl.ShiftStart
---------------------------------------------------------------------------------------------------
SET	@j = 1
---------------------------------------------------------------------------------------------------
--PRINT 'Initial @j: ' + Convert(VarChar, @j)
---------------------------------------------------------------------------------------------------
WHILE	@j < 1100 
BEGIN
	INSERT INTO		#DelayDetail (
					PLId,
					PUId,
					LineStatusId,
					ProdId,
					DetId,
					ParentId,
					MachineRcdEntry,
					UserId,
					DelayCount,
					DelayStart,
					DelayEnd,
					DelayTreeId,
					DelayTreeNodeId,
					TEFaultId,
					SourcePUId,
					DelayRL1Id,
					DelayRL2Id,
					DelayRL3Id,
					DelayRL4Id,
					EventReasonName1,
					EventReasonName2,
					EventReasonName3,
					EventReasonName4,
					OverlapFlagShift,
					OverlapSequence,
					OverlapRcdFlag,
					SplitFlagShift )
		SELECT		PLId,
					PUId,
					LineStatusId,
					ProdId,
					DetId,
					ParentId,
					MachineRcdEntry,
					UserId,
					0,
					DelayStart,
					DelayEnd,
					DelayTreeId,
					DelayTreeNodeId,
					TEFaultId,
					SourcePUId,
					DelayRL1Id,
					DelayRL2Id,
					DelayRL3Id,
					DelayRL4Id,
					EventReasonName1,
					EventReasonName2,
					EventReasonName3,
					EventReasonName4,
					OverlapFlagShift,
					2,
					1,
					1
			FROM	#DelayDetail
			WHERE	OverlapFlagShift > 0
	----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		DelayEnd = sl.ShiftStart
		FROM	#DelayDetail 	dd
		JOIN	#ShiftList 		sl 	ON 		sl.PUId = dd.PUId
									AND 	dd.OverlapFlagShift = sl.CSId
									AND		dd.OverlapSequence = 1
	----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		DelayStart 	= sl.ShiftStart,
				ShiftDesc 	= sl.ShiftDesc,
				CrewDesc 	= sl.CrewDesc
		FROM	#DelayDetail 	dd
		JOIN	#ShiftList 		sl 	ON 		sl.PUId = dd.PUId
									AND 	dd.OverlapFlagShift = sl.CSId
									AND		dd.OverlapSequence = 2
	----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapFlagShift 	= 0,
				OverlapSequence 	= 0
		FROM	#DelayDetail dd
		WHERE	dd.OverlapFlagShift > 0
	----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapFlagShift	= sl.CSId,
				OverlapSequence 	= 1,
				SplitFlagShift 		= 1
		FROM	#DelayDetail 	dd
		JOIN	#ShiftList 		sl ON sl.PUId = dd.PUId
		WHERE	DelayStart 	< sl.ShiftStart
		AND		DelayEnd 	> sl.ShiftStart
		AND		dd.OverlapRcdFlag = 1
	----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapRcdFlag = 0 
		FROM	#DelayDetail dd
		WHERE	dd.OverlapFlagShift = 0
	----------------------------------------------------------------------------------------------
	IF	(	SELECT 	Count(OverlapFlagShift)
				FROM	#DelayDetail
				WHERE OverlapFlagShift > 0) = 0
	BEGIN
		BREAK		
	END
	--
	SELECT	@j = @j + 1
END
---------------------------------------------------------------------------------------------------
--PRINT 'Final @j: ' + Convert(VarChar, @j)
---------------------------------------------------------------------------------------------------
--PRINT 'Find Line Status'
---------------------------------------------------------------------------------------------------
-- Delay: Find Line Status
---------------------------------------------------------------------------------------------------
UPDATE		dd
	SET		dd.LineStatusId 		=	ps.LineStatusId,
			dd.LineStatusSchedId	= 	ps.LineStatusSchedId
	FROM	#DelayDetail dd
	JOIN	#LineStatusList ps ON dd.PUId = ps.PUId
	WHERE	DelayStart >= ps.LineStatusStart
	AND		(DelayStart < ps.LineStatusEnd OR ps.LineStatusEnd IS NULL)
---------------------------------------------------------------------------------------------------
--PRINT 'Split Overlapping Line Status Records '
---------------------------------------------------------------------------------------------------
--	Delay: Split overlapping line status records
---------------------------------------------------------------------------------------------------
UPDATE		dd
	SET		OverlapFlagLineStatus	= sl.LineStatusSchedId,
			OverlapSequence 		= 1,
			OverlapRcdFlag 			= 1,
			SplitFlagLineStatus 	= 1
	FROM	#DelayDetail 	dd
	JOIN	#LineStatusList sl ON sl.PUId = dd.PUId
	WHERE	DelayStart 	< sl.LineStatusStart
	AND		DelayEnd 	> sl.LineStatusStart
---------------------------------------------------------------------------------------------------
SET	@j = 1
---------------------------------------------------------------------------------------------------
--PRINT 'Initial @j: ' + Convert(VarChar, @j)
---------------------------------------------------------------------------------------------------
WHILE	@j < 1000 
BEGIN
	INSERT INTO		#DelayDetail (
					PUId,
					ProdId,
					ShiftDesc,
					CrewDesc,
					DetId,
					ParentId,
					DelayCount,
					DelayStart,
					DelayEnd,
					DelayTreeId,
					DelayTreeNodeId,
					TEFaultId,
					SourcePUId,
					DelayRL1Id,
					DelayRL2Id,
					DelayRL3Id,
					DelayRL4Id,
					EventReasonName1,

					EventReasonName2,
					EventReasonName3,
					EventReasonName4,
					OverlapFlagLineStatus,
					OverlapSequence,
					OverlapRcdFlag,
					SplitFlagLineStatus )
		SELECT		PUId,
					ProdId,
					ShiftDesc,
					CrewDesc,

					DetId,
					ParentId,
					0,
					DelayStart,
					DelayEnd,
					DelayTreeId,
					DelayTreeNodeId,
					TEFaultId,
					SourcePUId,
					DelayRL1Id,
					DelayRL2Id,
					DelayRL3Id,
					DelayRL4Id,
					EventReasonName1,
					EventReasonName2,
					EventReasonName3,
					EventReasonName4,
					OverlapFlagLineStatus,
					2,
					1,
					1
			FROM	#DelayDetail
			WHERE	OverlapFlagLineStatus > 0
	----------------------------------------------------------------------------
	UPDATE		dd
		SET		DelayEnd = sl.LineStatusStart
		FROM	#DelayDetail dd
		JOIN	#LineStatusList sl 	ON 	sl.PUId = dd.PUId
									AND dd.OverlapFlagLineStatus = sl.LineStatusSchedId
									AND	dd.OverlapSequence = 1
	----------------------------------------------------------------------------
	UPDATE		dd
		SET		DelayStart 		= sl.LineStatusStart,
				LineStatusId 	= sl.LineStatusId
		FROM	#DelayDetail dd
		JOIN	#LineStatusList sl 	ON 	sl.PUId = dd.PUId
									AND dd.OverlapFlagLineStatus = sl.LineStatusSchedId
									AND	dd.OverlapSequence = 2
	----------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapFlagLineStatus 	= 0,
				OverlapSequence 		= 0
		FROM	#DelayDetail dd
		WHERE	dd.OverlapFlagLineStatus > 0
	----------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapFlagLineStatus 	= sl.LineStatusSchedId,
				OverlapSequence 		= 1,
				SplitFlagLineStatus 	= 1
		FROM	#DelayDetail dd
		JOIN	#LineStatusList sl ON sl.PUId = dd.PUId
		WHERE	DelayStart 	< sl.LineStatusStart
		AND		DelayEnd 	> sl.LineStatusStart
		AND		dd.OverlapRcdFlag = 1
	----------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapRcdFlag = 0 
		FROM	#DelayDetail dd
		WHERE	dd.OverlapFlagLineStatus = 0
	----------------------------------------------------------------------------
	IF	(	SELECT 		Count(OverlapFlagLineStatus)
				FROM	#DelayDetail
				WHERE 	OverlapFlagLineStatus > 0) = 0
	BEGIN
		BREAK		
	END
	--
	SELECT	@j = @j + 1
END
---------------------------------------------------------------------------------------------------
--PRINT 'Final @j: ' + Convert(VarChar, @j)
--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT	'	- UpTime Cursors '
---------------------------------------------------------------------------------------------------
-- Delay: UpTime
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	UpTimeEnd = DelayStart
---------------------------------------------------------------------------------------------------
DECLARE	UpTimePUCursor INSENSITIVE CURSOR FOR (
SELECT	PUId
	FROM	#PUList )
	ORDER	BY PUId
FOR READ ONLY
OPEN	UpTimePUCursor
FETCH	NEXT FROM UpTimePUCursor INTO @c_intPUId
WHILE	@@Fetch_Status = 0
BEGIN
	--
	SET	@i = 1
	--
	DECLARE		UpTimeCursor INSENSITIVE CURSOR FOR (
	SELECT		DetId, 
				DelayStart,
				DelayEnd
		FROM	#DelayDetail 
		WHERE	PUId	= @c_intPUId )
	ORDER BY 	DelayStart
	FOR READ ONLY
	OPEN	UpTimeCursor
	FETCH	NEXT FROM UpTimeCursor INTO @c_intDetId, @c_dtmDelayStart, @c_dtmDelayEnd
	WHILE	@@Fetch_Status = 0
	BEGIN
		-------------------------------------------------------------------------------------------
		-- PRINT	'PUID:' + Convert(VarChar, @c_intPUId) + ' DetId: ' + Convert(VarChar, @c_intDetId) + ' DelayStart: ' + Convert(VarChar, @c_dtmDelayStart, 121) + ' DelayEnd: ' + Convert(VarChar, @c_dtmDelayEnd, 121)
		-------------------------------------------------------------------------------------------
		IF	@i = 1
		BEGIN
			UPDATE		#DelayDetail
				SET		UpTimeStart = @dtmStartDateTime
				WHERE	DetId		= @c_intDetId
				AND		UpTimeEnd 	= @c_dtmDelayStart
		END
		ELSE
		BEGIN
			UPDATE		#DelayDetail
				SET		UpTimeStart = @dtmDlyTempDate
				WHERE	DetId 		= @c_intDetId	
				AND		UpTimeEnd 	= @c_dtmDelayStart
		END
		--
		SET	@dtmDlyTempDate = @c_dtmDelayEnd
		SET	@i = @i + 1
		--
		FETCH	NEXT FROM UpTimeCursor INTO @c_intDetId, @c_dtmDelayStart, @c_dtmDelayEnd
	--
	END
	CLOSE		UpTimeCursor
	DEALLOCATE 	UpTimeCursor
	--
	FETCH	NEXT FROM UpTimePUCursor INTO @c_intPUId
	--
END
CLOSE		UpTimePUCursor
DEALLOCATE 	UpTimePUCursor
---------------------------------------------------------------------------------------------------
--PRINT '	.	Add uptime record at bottom of result set' 
---------------------------------------------------------------------------------------------------
-- Delay: add an uptime record at the bottom of the result set when the last
-- delay record does not overlap the reporting period
---------------------------------------------------------------------------------------------------
DECLARE	UpTimeRcdCursor INSENSITIVE CURSOR 
FOR (	SELECT		PUId
			FROM	#PUList)
		ORDER BY	PUId
FOR READ ONLY
OPEN	UpTimeRcdCursor
FETCH	NEXT FROM UpTimeRcdCursor INTO @c_intPUId
WHILE	@@Fetch_Status = 0
BEGIN
	----------------------------------------------------------------------------------------------
	SELECT		@dtmDlyTempDate = Max(DelayEnd)
		FROM	#DelayDetail
		WHERE	PUId = @c_intPUId
	----------------------------------------------------------------------------------------------
	IF	@dtmDlyTempDate < @dtmEndDateTime
	BEGIN
		INSERT INTO		#DelayDetail (
						PUId,
						ProdId,
						LineStatusId,
						LineStatusSchedId,
						ShiftDesc,
						CrewDesc,
						DelayCount,
						UpTimeStart,
						UpTimeEnd )
			SELECT		@c_intPUId,
						ProdId,
						LineStatusId,
						LineStatusSchedId,
						ShiftDesc,
						CrewDesc,
						0,
						@dtmDlyTempDate,
						@dtmEndDateTime	
				FROM	#DelayDetail
				WHERE	PUId = @c_intPUId
				AND		DelayEnd = @dtmDlyTempDate
	END
	--
	FETCH	NEXT FROM UpTimeRcdCursor INTO @c_intPUId
--
END
CLOSE		UpTimeRcdCursor
DEALLOCATE 	UpTimeRcdCursor
---------------------------------------------------------------------------------------------------
--PRINT '	.	Split Overlapping shift UpTime Records '
---------------------------------------------------------------------------------------------------
--	Delay: Split overlapping uptime records records when Minor Grouping includes
-- 	shift
---------------------------------------------------------------------------------------------------
IF CharIndex('ShiftDesc', @RptStopHistoryMinorGroupBy) 	> 0 
OR CharIndex('CrewDesc', @RptStopHistoryMinorGroupBy) 	> 0
BEGIN
	UPDATE		dd
		SET		OverlapFlagShift 	= sl.CSId,
				OverlapSequence 	= 1,
				OverlapRcdFlag 		= 1,
				SplitFlagShift 		= 1
		FROM	#DelayDetail	dd
		JOIN	#ShiftList 		sl ON sl.PUId = dd.PUId
		WHERE	UpTimeStart < sl.ShiftStart
		AND		UpTimeEnd 	> sl.ShiftStart
	----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapFlagShift = sl.CSId
		FROM	#DelayDetail dd
		JOIN	#ShiftList sl ON sl.PUId = dd.PUId
		WHERE	UpTimeStart >= 	sl.ShiftStart
		AND		UpTimeStart < 	sl.ShiftEnd
		AND		dd.OverlapFlagShift > 0
	----------------------------------------------------------------------------------------------
	SET	@j = 1
	----------------------------------------------------------------------------------------------
	--PRINT 'Initial @j: ' + Convert(VarChar, @j)
	----------------------------------------------------------------------------------------------
	WHILE	@j < 1100 
	BEGIN
		INSERT INTO		#DelayDetail (
						PLId,
						PUId,
						LineStatusId,
						LineStatusSchedId,
						ProdId,
						DetId,
						DelayCount,
						UpTimeStart,
						UpTimeEnd,
						OverlapFlagShift,
						OverlapSequence,
						OverlapRcdFlag,
						SplitFlagShift )
			SELECT		PLId,
						PUId,
						LineStatusId,
						LineStatusSchedId,
						ProdId,
						DetId,
						0,
						UpTimeStart,
						UpTimeEnd,
						OverlapFlagShift,
						2,
						1,
						1
				FROM	#DelayDetail
				WHERE	OverlapFlagShift > 0
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		UpTimeStart = sl.ShiftEnd
			FROM	#DelayDetail 	dd
			JOIN	#ShiftList 		sl 	ON 	sl.PUId 			= dd.PUId
										AND dd.OverlapFlagShift = sl.CSId
										AND	dd.OverlapSequence 	= 1
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		UpTimeEnd 	= sl.ShiftEnd,
					ShiftDesc 	= sl.ShiftDesc,
					CrewDesc 	= sl.CrewDesc
			FROM	#DelayDetail 	dd
			JOIN	#ShiftList 		sl 	ON 	sl.PUId 			= dd.PUId
										AND dd.OverlapFlagShift = sl.CSId
										AND	dd.OverlapSequence 	= 2
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		OverlapFlagShift 	= 0,
					OverlapSequence 	= 0
			FROM	#DelayDetail dd
			WHERE	dd.OverlapFlagShift > 0
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		OverlapFlagShift 	= sl.CSId,
					OverlapSequence 	= 1,
					SplitFlagShift 		= 1
			FROM	#DelayDetail dd
			JOIN	#ShiftList	 sl ON sl.PUId = dd.PUId
			WHERE	UpTimeStart = sl.ShiftStart
			AND		UptimeEnd 	> sl.ShiftEnd
			--WHERE	UpTimeStart < sl.ShiftStart
			--AND		UptimeEnd 	> sl.ShiftStart
			AND		dd.OverlapRcdFlag = 1
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		OverlapRcdFlag = 0 
			FROM	#DelayDetail dd
			WHERE	dd.OverlapFlagShift = 0
		-------------------------------------------------------------------------------------------
		IF	(	SELECT 		Count(OverlapFlagShift)
					FROM	#DelayDetail
					WHERE 	OverlapFlagShift > 0) = 0
		BEGIN
			BREAK		
		END
		-------------------------------------------------------------------------------------------
		SELECT	@j = @j + 1
	END
END
---------------------------------------------------------------------------------------------------
--PRINT '	.	Split Overlapping Line Status uptime Records '
---------------------------------------------------------------------------------------------------
IF CharIndex('ProdStatus', @RptStopHistoryMinorGroupBy) > 0 
BEGIN
	UPDATE		dd
		SET		OverlapFlagLineStatus = sl.LineStatusSchedId,
				OverlapSequence 	= 1,
				OverlapRcdFlag 		= 1,
				SplitFlagLineStatus = 1
		FROM	#DelayDetail 	dd
		JOIN	#LineStatusList sl ON sl.PUId = dd.PUId
		WHERE	UpTimeStart < sl.LineStatusStart
		AND		UpTimeEnd 	> sl.LineStatusStart
	-----------------------------------------------------------------------------------------------
	UPDATE		dd
		SET		OverlapFlagLineStatus = sl.LineStatusSchedId
		FROM	#DelayDetail 	dd
		JOIN	#LineStatusList sl ON sl.PUId = dd.PUId
		WHERE	UpTimeStart >= sl.LineStatusStart
		AND		UpTimeStart < 	sl.LineStatusEnd
		AND		dd.OverlapFlagLineStatus > 0
	-----------------------------------------------------------------------------------------------
	SET	@j = 1
	-----------------------------------------------------------------------------------------------
	--PRINT 'Initial @j: ' + Convert(VarChar, @j)
	-----------------------------------------------------------------------------------------------
	WHILE	@j < 1000 
	BEGIN
		INSERT INTO		#DelayDetail (
						PLId,
						PUId,
						LineStatusId,
						LineStatusSchedId,
						ProdId,
						DetId,
						DelayCount,
						UpTimeStart,
						UpTimeEnd,
						OverlapFlagLineStatus,

						OverlapSequence,
						OverlapRcdFlag,
						SplitFlagLineStatus )
			SELECT		PLId,
						PUId,
						LineStatusId,
						LineStatusSchedId,
						ProdId,
						DetId,
						0,
						UpTimeStart,
						UpTimeEnd,
						OverlapFlagLineStatus,
						2,
						1,
						1
				FROM	#DelayDetail
				WHERE	OverlapFlagLineStatus > 0
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		UpTimeStart = sl.LineStatusEnd
			FROM	#DelayDetail dd
			JOIN	#LineStatusList sl 	ON 	sl.PUId 					= dd.PUId
										AND dd.OverlapFlagLineStatus 	= sl.LineStatusSchedId
										AND	dd.OverlapSequence 			= 1
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		UpTimeEnd 		= sl.LineStatusEnd,
					LineStatusId 	= sl.LineStatusId
			FROM	#DelayDetail 	dd
			JOIN	#LineStatusList sl 	ON 	sl.PUId 					= dd.PUId
										AND dd.OverlapFlagLineStatus 	= sl.LineStatusSchedId
										AND	dd.OverlapSequence 			= 2
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		OverlapFlagLineStatus 	= 0,
					OverlapSequence 		= 0
			FROM	#DelayDetail dd
			WHERE	dd.OverlapFlagLineStatus > 0
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		OverlapFlagLineStatus 	= sl.LineStatusSchedId,
					OverlapSequence 		= 1,
					SplitFlagLineStatus 	= 1
			FROM	#DelayDetail 	dd
			JOIN	#LineStatusList sl ON sl.PUId = dd.PUId
			WHERE	UpTimeStart < sl.LineStatusStart
			AND		UpTimeEnd 	> sl.LineStatusStart
			AND		dd.OverlapRcdFlag = 1
		-------------------------------------------------------------------------------------------
		UPDATE		dd
			SET		OverlapRcdFlag = 0 
			FROM	#DelayDetail dd
			WHERE	dd.OverlapFlagLineStatus = 0
		-------------------------------------------------------------------------------------------
		IF	(	SELECT 	Count(OverlapFlagLineStatus)
					FROM	#DelayDetail
					WHERE OverlapFlagLineStatus > 0) = 0
		BEGIN
			BREAK		
		END
		--
		SELECT	@j = @j + 1
	END
END
--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT	'	- Apply Filters '
---------------------------------------------------------------------------------------------------
--	Delay: Filter Line Status
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterLineStatusList ) > 0
BEGIN
	-----------------------------------------------------------------------------------------------
	--PRINT	'	.	Line Status'
	-----------------------------------------------------------------------------------------------
	DELETE			dd
		FROM		#DelayDetail			dd
		Left JOIN	#FilterLineStatusList	ls ON dd.LineStatusId = ls.LineStatusId
		WHERE		ls.LineStatusId IS NULL
END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Product
---------------------------------------------------------------------------------------------------
IF	(	SELECT	Count(*)
			FROM	#FilterProdList ) > 0
BEGIN

	---------------------------------------------
	--PRINT	'	.	Product'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail	dd
		Left JOIN	#FilterProdList	pl	ON dd.ProdId = pl.ProdId
		WHERE		pl.ProdId IS NULL

END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Shift
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterShiftList ) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Shift'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail		dd
		Left JOIN	#FilterShiftList	sl ON dd.ShiftDesc = sl.ShiftDesc
		WHERE		sl.ShiftDesc IS NULL
END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Crew
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterCrewList ) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Crew'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail 		dd
		Left JOIN	#FilterCrewList 	cl ON dd.CrewDesc = cl.CrewDesc
		WHERE		cl.CrewDesc IS NULL
END

---------------------------------------------------------------------------------------------------
--	Delay: Filter Location
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterSourcePUList ) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Location'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail 			dd
		Left JOIN	#FilterSourcePUList 	sl ON dd.SourcePUId = sl.SourcePUId
		WHERE		sl.SourcePUId IS NULL
END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Event Reason Level 1
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterEventReasonIdList 
			WHERE	ReasonLevelId = 1) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Event Reason Level 1'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail 				dd
		Left JOIN	#FilterEventReasonIdList 	ferl	ON 	dd.DelayRL1Id 		= ferl.EventReasonId
														AND ferl.ReasonLevelId 	= 1
		WHERE		ferl.EventReasonId IS NULL
END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Event Reason Level 2
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterEventReasonIdList 
			WHERE	ReasonLevelId = 2) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Event Reason Level 2'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail 				dd
		Left JOIN	#FilterEventReasonIdList 	ferl	ON 	dd.DelayRL2Id 		= ferl.EventReasonId
														AND ferl.ReasonLevelId 	= 2
		WHERE		ferl.EventReasonId IS NULL
END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Event Reason Level 3
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterEventReasonIdList 
			WHERE	ReasonLevelId = 3) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Event Reason Level 3'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail 				dd
		Left JOIN	#FilterEventReasonIdList 	ferl	ON 	dd.DelayRL3Id 		= ferl.EventReasonId
														AND ferl.ReasonLevelId 	= 3
		WHERE		ferl.EventReasonId IS NULL
END
---------------------------------------------------------------------------------------------------
--	Delay: Filter Event Reason Level 4
---------------------------------------------------------------------------------------------------
IF	(	SELECT		Count(*)
			FROM	#FilterEventReasonIdList 
			WHERE	ReasonLevelId = 4) > 0
BEGIN
	---------------------------------------------
	--PRINT	'	.	Event Reason Level 4'
	---------------------------------------------
	DELETE			dd
		FROM		#DelayDetail 				dd
		Left JOIN	#FilterEventReasonIdList 	ferl	ON 	dd.DelayRL4Id 		= ferl.EventReasonId
														AND ferl.ReasonLevelId 	= 4
		WHERE		ferl.EventReasonId IS NULL
END
--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT 'Get Production Day'
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	OffsetFromMidnightInSec	=	(DatePart(hh, DelayStart) * 60 * 60) + (DatePart(mi, DelayStart) * 60) + DatePart(ss, DelayStart)
---------------------------------------------------------------------------------------------------
SET	@intShiftOffset = DatePart(hh, @RptShiftStart) * 60 * 60 + DatePart(mi, @RptShiftStart) * 60 + DatePart(ss, @RptShiftStart)  
UPDATE	#DelayDetail
	SET	ProductionDay = 	Case	WHEN	OffsetFromMidnightInSec >= 0 AND OffsetFromMidnightInSec < @intShiftOffset
									THEN	Substring(Convert(VarChar, DateAdd(day, -1, DelayStart), 120), 1, 10)
									ELSE 	Substring(Convert(VarChar, DelayStart, 120), 1, 10)
							END
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	OffsetFromMidnightInSec	=	(DatePart(hh, UpTimeStart) * 60 * 60) + (DatePart(mi, UpTimeStart) * 60) + DatePart(ss, UpTimeStart)
	WHERE	DelayStart	IS NULL
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	ProductionDay = 	Case	WHEN	OffsetFromMidnightInSec >= 0 AND OffsetFromMidnightInSec < @intShiftOffset
									THEN	Substring(Convert(VarChar, DateAdd(day, -1, UpTimeStart), 120), 1, 10)
									ELSE 	Substring(Convert(VarChar, UpTimeStart, 120), 1, 10)
							END
	WHERE	DelayStart 	IS NULL
--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT 'Get summary and detail comments and Reason Categories'
---------------------------------------------------------------------------------------------------
-- Delay: get comments
-- Note: There are a couple fields in the Timed_Event_Details table called 
-- Cause_Comment_Id and Summary_Cause_Comment_Id.  If you have a comment on the 
-- detail the comment_id will be under the Cause_Comment_Id field.  
-- If you have a comment on the summary it will be under the Summary_Cause_Comment_Id.  
-- Only the detail at the fop of the chain will populate the Summary_Cause_Comment_Id field.
-- These two field will be implemented in Proficy 4.0 onward.
---------------------------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		DelayCommentIdList = CauseCommentId
	FROM	#DelayDetail
	WHERE	SummaryCauseCommentId IS NULL
	AND		CauseCommentId IS NOT NULL
---------------------------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		DelayCommentIdList = SummaryCauseCommentId
	FROM	#DelayDetail
	WHERE	SummaryCauseCommentId IS NOT NULL
	AND		CauseCommentId IS NULL
---------------------------------------------------------------------------------------------------

UPDATE		#DelayDetail
	SET		-- DelayCommentIdList = Convert(VarChar, SummaryCauseCommentId) + '|' + Convert(VarChar, CauseCommentId)
            DelayCommentIdList = Convert(nvarchar(1000),SummaryCauseCommentId + '|' + CauseCommentId)
	FROM	#DelayDetail
	WHERE	SummaryCauseCommentId IS NOT NULL
	AND		CauseCommentId IS NOT NULL

---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Retrieve Downtime Categories '
---------------------------------------------------------------------------------------------------
UPDATE		dd
	SET		ERCId				=	rd.ERC_Id,
			DelayCategoryDesc	=	rc.ERC_Desc
	FROM		#DelayDetail					dd
	Left JOIN	dbo.Event_Reason_Category_Data	rd	WITH (NOLOCK)
													ON	dd.DelayTreeNodeId = rd.Event_Reason_Tree_Data_Id
	Left JOIN	dbo.Event_Reason_Catagories		rc	WITH (NOLOCK)
													ON	rc.ERC_Id = rd.ERC_Id 
--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT 'Calculations'
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- Delay: calculations
---------------------------------------------------------------------------------------------------
UPDATE	#DelayDetail
	SET	UpTimeDurationInSec	= DateDiff(Second, UpTimeStart, UpTimeEnd),
		DelayDurationInSec	= DateDiff(Second, DelayStart, DelayEnd)
---------------------------------------------------------------------------------------------------
-- Delay: Update UpTimeGreaterThan0Count
---------------------------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		UpTimeGreaterThan0Count = 	1
	WHERE	UpTimeDurationInSec > 0
	AND		DelayCount > 0
---------------------------------------------------------------------------------------------------
-- Delay: Update UpTimeGreaterThanTCount
---------------------------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		UpTimeGreaterThanTCount = 1
	WHERE	UptimeDurationInSec > (@RptT * 60)
	AND		DelayCount > 0
---------------------------------------------------------------------------------------------------
-- Delay: Update DelayGreaterThanTCount
---------------------------------------------------------------------------------------------------
UPDATE		#DelayDetail
	SET		DelayGreaterThanTCount = 1
	WHERE	MasterDelayDurationInSec > (@RptTDowntime * 60)
	AND		DelayCount > 0
---------------------------------------------------------------------------------------------------
-- Delay: Identify uptime records
---------------------------------------------------------------------------------------------------
UPDATE		dd
	SET		dd.UpTimeRcdFlag	=	'^'
	FROM	#DelayDetail	dd
	WHERE	dd.DelayStart IS NULL

--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
--PRINT '--------------------------------------------------------------------------------------------'
--PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
--PRINT '-	Return Result Sets'
---------------------------------------------------------------------------------------------------
--PRINT '	.	RS1: Misc Info ' 
---------------------------------------------------------------------------------------------------
-- RS1: Misc Info
---------------------------------------------------------------------------------------------------
INSERT INTO		#MiscInfo (
				CompanyName,
				SiteName,
				RptOwnerDesc,
				RptStartDateTime,	
				RptEndDateTime,
				ShiftFilter,
				CrewFilter,
				LineStatusFilter,
				RptTitle,
				MajorGroupBy,
				CommentColWidth,
				CommentTableFlag )
	SELECT		@chrCompanyName,
				@chrSiteName,
				@chrRptOwnerDesc,
				Convert(VarChar(50), @dtmStartDateTime, 120),
				Convert(VarChar(50), @dtmEndDateTime, 120),
				@RptShiftDescList,
				@RptCrewDescList,
				@RptLineStatusDescList,
				@RptTitle,
				@RptStopHistoryMajorGroupBy,
				@RptStopHistoryCommentColWidth,
				@intCommentTableFlag
-- 
SELECT * FROM	#MiscInfo
---------------------------------------------------------------------------------------------------
--PRINT '	.	RS2: Major Group List ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
---------------------------------------------------------------------------------------------------
-- RS2: Major Group List
---------------------------------------------------------------------------------------------------
SET	@chrProdDescList = ''

IF	(SELECT		Count(*)
		FROM	#FilterProdList ) > 0
BEGIN
	-----------------------------------------------------------------------------------------------
	DECLARE	ProdCodeCursor INSENSITIVE CURSOR 
	FOR (	SELECT		Coalesce(ProdCode, '')
				FROM	#FilterProdList )
			ORDER BY 	ProdCode
	FOR READ ONLY
	OPEN	ProdCodeCursor
	FETCH	NEXT FROM ProdCodeCursor INTO @c_chrProdCode
	WHILE	@@Fetch_Status = 0
	BEGIN
		
		SET	@chrProdDescList = @chrProdDescList + ', ' + @c_chrProdCode

		FETCH	NEXT FROM ProdCodeCursor INTO @c_chrProdCode
	
	END
	CLOSE		ProdCodeCursor
	DEALLOCATE 	ProdCodeCursor
	-----------------------------------------------------------------------------------------------
	SET	@chrProdDescList = LTrim(RTrim(Substring(@chrProdDescList, 2, Len(@chrProdDescList))))
END
ELSE
BEGIN
	SET	@chrProdDescList = 'All'
END
---------------------------------------------------------------------------------------------------
SET	@chrPUDescList = ''
--
DECLARE	PUDescCursor INSENSITIVE CURSOR 
FOR (	SELECT		PU_Desc
			FROM	#PUList	pl
			JOIN	dbo.Prod_Units	pu WITH(NOLOCK) ON pu.PU_Id = pl.PUId )
		ORDER BY 	PUDesc
FOR READ ONLY
OPEN	PUDescCursor
FETCH	NEXT FROM PUDescCursor INTO @c_chrPUDesc
WHILE	@@Fetch_Status = 0
BEGIN

	SET	@chrPUDescList = @chrPUDescList + ', ' + @c_chrPUDesc

	FETCH	NEXT FROM PUDescCursor INTO @c_chrPUDesc
END
CLOSE		PUDescCursor
DEALLOCATE 	PUDescCursor
--

-- Select 'Last Update',* from #DelayDetail

SET	@chrPUDescList = LTrim(RTrim(Substring(@chrPUDescList, 2, Len(@chrPUDescList))))
---------------------------------------------------------------------------------------------------
IF	@RptStopHistoryMajorGroupBy = 'PUId|ProdId'
BEGIN
	SELECT		dd.PUId, 
				pu.PU_Desc PUDesc, 
				dd.ProdId, 
				p.Prod_Code ProdCode
		FROM	#DelayDetail dd
		JOIN	dbo.Prod_Units pu WITH(NOLOCK) ON dd.PUId = pu.PU_Id
		JOIN	dbo.Products p WITH(NOLOCK) ON p.Prod_Id = dd.ProdId
	GROUP BY	dd.PUId, pu.PU_Desc, dd.ProdId, p.Prod_Code
	ORDER BY	pu.PU_Desc
END
---------------------------------------------------------------------------------------------------
IF	@RptStopHistoryMajorGroupBy = 'PUId'
BEGIN
	SELECT		dd.PUId, 
				pu.PU_Desc 			PUDesc, 
				@chrProdDescList	ProdCode
		FROM	#DelayDetail dd
		JOIN	dbo.Prod_Units pu WITH(NOLOCK) ON dd.PUId = pu.PU_Id
	GROUP BY	dd.PUId, pu.PU_Desc
	ORDER BY	pu.PU_Desc
END	
---------------------------------------------------------------------------------------------------
IF	@RptStopHistoryMajorGroupBy = '!Null'	
OR	Len(@RptStopHistoryMajorGroupBy) = 0
BEGIN
	SELECT	0					PUId, 
			@chrPUDescList 		PUDesc, 
			@chrProdDescList	ProdCode
END
---------------------------------------------------------------------------------------------------
IF	@RptStopHistoryMajorGroupBy = 'ProdId'
BEGIN
	SELECT		0				PUId, 
				@chrPUDescList	PUDesc,
				dd.ProdId, 
				p.Prod_Code 	ProdCode
		FROM	#DelayDetail	dd
		JOIN	dbo.Products 	p	WITH(NOLOCK) ON	p.Prod_Id = dd.ProdId
	GROUP BY	dd.ProdId, p.Prod_Code
	ORDER BY	p.Prod_Code
END
---------------------------------------------------------------------------------------------------
--PRINT '	.	RS3: Hdr Info ' 
---------------------------------------------------------------------------------------------------
-- RS3: Header info
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand 	= ''
SET	@chrSQLCommand1 = ''
SET	@chrSQLCommand2 = ''
--
IF	@RptStopHistoryMajorGroupBy = '!Null'
BEGIN
	SET	@chrSQLCommand1 = '	INSERT INTO	#HdrInfo (' 
										+		'	PUId, '
										+		'	TotalUptime, '
										+		'	TotalDownTime, ' 
										-- FO-00847-B: 2) Add Total Unplanned Downtime to Stop Summary section 
										+		'	TotalDownTimeUnplan, ' 
										+		'	TotalStops, '
										+		'	TotalStopsUnplan, '
										+		'	TotalUpTimeGreaterThan0, '
										+		'	TotalUpTimeGreaterThanT, '
										+		'	AvailableTimeInMin )'
	--
	SET	@chrSQLCommand2 =	'SELECT 	0, '
						+		'				LTrim(RTrim(Str((Convert(Float, Sum(UpTimeDurationInSec)) / 60.0), 50, 1))), '
						+		'				LTrim(Rtrim(Str((Convert(Float, Sum(DelayDurationInSec )) / 60.0), 50, 1))), '							
						+		'				LTrim(Rtrim(Str((Convert(Float, Sum(DelayDurationInSec )) / 60.0) - (Convert(Float, (SELECT Sum(DelayDurationInSec) FROM #DelayDetail dd1 JOIN #ReasonsToExclude cl ON dd1.ERCId = cl.ERC_Id )) / 60.0), 50, 1))), '
						+		'				Sum(DelayCount), '
						+		'				(((SELECT sum(DelayCount) FROM #DelayDetail dd1 ) - (SELECT count(*) FROM #DelayDetail dd1 JOIN #ReasonsToExclude cl ON dd1.ERCId = cl.ERC_Id))), '
						+		'				Sum(UpTimeGreaterThan0Count), '
						+		'				Sum(UpTimeGreaterThanTCount), '
						+		'				LTrim(RTrim(Str(Sum(UpTimeDurationInSec + Coalesce(DelayDurationInSec, 0)) * 1.0 / 60.0, 50, 1))) '
						+		'		FROM	#DelayDetail '
END
ELSE IF	@RptStopHistoryMajorGroupBy = 'ProdId'
BEGIN
	SET	@chrSQLCommand1 = '	INSERT INTO	#HdrInfo (' 
										+		'	PUId, '
										+			Replace(@RptStopHistoryMajorGroupBy, '|', ',') + ', '
										+		'	TotalUptime, '
										+		'	TotalDownTime, ' 
										-- FO-00847-B: 2) Add Total Unplanned Downtime to Stop Summary section 
										+		'	TotalDownTimeUnplan, ' 
										+		'	TotalStops, '
										+		'	TotalStopsUnplan, '
										+		'	TotalUpTimeGreaterThan0, '
										+		'	TotalUpTimeGreaterThanT, '
										+		'	AvailableTimeInMin )'
	--
	SET	@chrSQLCommand2 =	'SELECT 	0, ' 
						+ 						Replace(@RptStopHistoryMajorGroupBy, '|', ',') + ', '
						+		'				LTrim(RTrim(Str((Convert(Float, Sum(UpTimeDurationInSec)) / 60.0), 50, 1))), '
						+		'				LTrim(Rtrim(Str((Convert(Float, Sum(DelayDurationInSec )) / 60.0), 50, 1))), '							
						+		'				LTrim(Rtrim(Str((Convert(Float, Sum(DelayDurationInSec )) / 60.0) - (Convert(Float, (SELECT Sum(DelayDurationInSec) FROM #DelayDetail dd1 JOIN #ReasonsToExclude cl ON dd1.ERCId = cl.ERC_Id WHERE dd.ProdId = dd1.ProdId)) / 60.0), 50, 1))), '
						+		'				Sum(DelayCount), '
						+		'				(((SELECT sum(DelayCount) FROM #DelayDetail dd1 WHERE dd.ProdId	= dd1.ProdId) - (SELECT count(*) FROM #DelayDetail dd1 JOIN #ReasonsToExclude cl ON dd1.ERCId = cl.ERC_Id WHERE dd.ProdId	= dd1.ProdId))), '
						+		'				Sum(UpTimeGreaterThan0Count), '
						+		'				Sum(UpTimeGreaterThanTCount), '
						+		'				LTrim(RTrim(Str(Sum(UpTimeDurationInSec + Coalesce(DelayDurationInSec, 0)) * 1.0 / 60.0, 50, 1))) '
						+		'		FROM	#DelayDetail dd'
						+		'		GROUP BY	' + Replace(@RptStopHistoryMajorGroupBy, '|', ',')
END
ELSE
BEGIN
	SET	@chrSQLCommand1 = '	INSERT INTO	#HdrInfo (' 
										+			Replace(@RptStopHistoryMajorGroupBy, '|', ',') + ', '
										+		'	TotalUptime, '
										+		'	TotalDownTime, ' 
										-- FO-00847-B: 2) Add Total Unplanned Downtime to Stop Summary section 
										+		'	TotalDownTimeUnplan, ' 
										+		'	TotalStops, '
										+		'	TotalStopsUnplan, '
										+		'	TotalUpTimeGreaterThan0, '
										+		'	TotalUpTimeGreaterThanT, '
										+		'	AvailableTimeInMin )'
	--
	SET	@chrSQLCommand2 =	'SELECT ' + Replace(@RptStopHistoryMajorGroupBy, '|', ',') + ', '
						+		'				LTrim(RTrim(Str((Convert(Float, Sum(UpTimeDurationInSec)) / 60.0), 50, 1))), '
						+		'				LTrim(Rtrim(Str((Convert(Float, Sum(DelayDurationInSec )) / 60.0), 50, 1))), '							
						+		'				LTrim(Rtrim(Str((Convert(Float, Sum(DelayDurationInSec )) / 60.0) - (Convert(Float, (SELECT Sum(DelayDurationInSec) FROM #DelayDetail dd1 JOIN #ReasonsToExclude cl ON dd1.ERCId = cl.ERC_Id WHERE dd.PUId	= dd1.PUId)) / 60.0), 50, 1))) , '
						+		'				Sum(DelayCount), '
						+		'				(((SELECT sum(DelayCount) FROM #DelayDetail dd1 WHERE dd.PUId	= dd1.PUId) - (SELECT count(*) FROM #DelayDetail dd1 JOIN #ReasonsToExclude cl ON dd1.ERCId = cl.ERC_Id WHERE dd.PUId	= dd1.PUId))), '
						+		'				Sum(UpTimeGreaterThan0Count), '
						+		'				Sum(UpTimeGreaterThanTCount), '
						+		'				LTrim(RTrim(Str(Sum(UpTimeDurationInSec + Coalesce(DelayDurationInSec, 0)) * 1.0 / 60.0, 50, 1))) '
						+		'		FROM	#DelayDetail dd'
						+		'		GROUP BY	' + Replace(@RptStopHistoryMajorGroupBy, '|', ',')
END
--
SET	@chrSQLCommand = @chrSQLCommand1 + ' ' + @chrSQLCommand2
EXEC	(@chrSQLCommand)

-- FO-00847-B: 2) Add Total Unplanned Downtime to Stop Summary section 
-- Testing: 
-- SELECT '#DelayDetail -->', * FROM #DelayDetail dd1 
-- PRINT 'Hdr ' + @chrSQLCommand
-- select 'Hdr', *  from #HdrInfo

---------------------------------------------------------------------------------------------------
-- RS3: HdrInfo calculations
---------------------------------------------------------------------------------------------------
--PRINT '		HdrInfo Calculations'
---------------------------------------------------------------------------------------------------
UPDATE	#HdrInfo
	SET	R0 		= 	Case	WHEN	TotalStops > 0
							THEN	LTrim(RTrim(Str(Convert(Float, TotalUpTimeGreaterThan0) / Convert(Float, TotalStops), 25, 3))) 
					END,
		RT 		= 	Case	WHEN	TotalStops > 0
							THEN	LTrim(RTrim(Str(Convert(Float, TotalUpTimeGreaterThanT) / Convert(Float, TotalStops), 25, 3))) 
					END,
		-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
		MTBS 	= 	Case	WHEN	TotalStops > 0
							THEN	LTrim(RTrim(Str(Convert(Float, TotalUptime) / Convert(Float, TotalStops), 25, 2))) 
					END,
		MTTR 	= 	Case	WHEN	TotalStops > 0
							THEN	LTrim(RTrim(Str(Convert(Float, TotalDowntime) / Convert(Float, TotalStops), 25, 1))) 
					END
---------------------------------------------------------------------------------------------------
UPDATE	#HdrInfo
SET	Availability	= 	-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
						Case	WHEN	(Convert(Float, MTBS) + Convert(Float, MTTR)) > 0
								THEN	LTrim(RTrim(Str(Convert(Float, MTBS) / (Convert(Float, MTBS) + Convert(Float, MTTR)), 25, 6)))
						END

---------------------------------------------------------------------------------------------------
-- FO-00847-B: 3) Add MTBF defined as Total Uptime / Total Unplanned Downtime to Stop Summary section
UPDATE	#HdrInfo
SET		MTBF		= 	Case	WHEN	(Convert(Float, TotalStopsUnplan)) > 0
								THEN	LTrim(RTrim(Str(Convert(Float, TotalUptime) / (Convert(Float, TotalStopsUnplan)), 25, 1)))
						END
FROM #HdrInfo

---------------------------------------------------------------------------------------------------
-- RS3: HdrInfo return result set
---------------------------------------------------------------------------------------------------
SELECT	* 	FROM #HdrInfo

--=================================================================================================
--PRINT '	.	RS4: Final Result Set ' 
--=================================================================================================
-- RS4: Build select statement - Major grouping = !Null (No grouping
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand1 	= ''
SET	@chrSQLCommand2 	= ''
SET	@chrSQLCommand3		= ''
SET	@chrSQLCommand4		= ''
SET	@chrSQLCommand 		= ''
--
IF	(@RptStopHistoryMajorGroupBy = '!Null')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT 0, Null'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY '
END
-------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = PUId
-------------------------------------------------------------------------------
IF	(@RptStopHistoryMajorGroupBy = 'PUId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT dd.PUId, Null'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY dd.PUId '
END
-------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = ProdId
-------------------------------------------------------------------------------
IF	(@RptStopHistoryMajorGroupBy = 'ProdId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT 0, dd.ProdId'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY dd.ProdId '
END
-------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = PUId|ProdId
-------------------------------------------------------------------------------
IF	(@RptStopHistoryMajorGroupBy = 'PUId|ProdId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT dd.PUId, dd.ProdId'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY dd.PUId, dd.ProdId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - minor group is !Null or Null
---------------------------------------------------------------------------------------------------
IF	(@RptStopHistoryMinorGroupBy = '!Null' 
OR	(Len(IsNull(@RptStopHistoryMinorGroupBy, ''))) = 0)
BEGIN
	SET	@chrSQLCommand1 = 	@chrSQLCommand1	+ 	',	LTrim(RTrim(Str(Convert(Float, dd.UpTimeDurationInSec) /60.0, 50, 1))), '
											+	'	LTrim(RTrim(Str(Convert(Float, dd.DelayDurationInSec) /60.0, 50, 1))), '
											+	'	dd.DelayCount, '
											+ 	'	dd.DelayGreaterThanTCount, '
											+	'	dd.UpTimeGreaterThanTCount, '
											+	'	dd.DelayCommentIdList, '
											+	'	Case	WHEN	dd.ParentId IS NOT NULL '
											+	'			THEN	''.'' '
											+	'			WHEN	dd.DelayStart IS NULL '
											+	'			THEN	''^'' '
											+	'	END, '
											+	'	pul.PLDesc, '
											+ 	'	pul.PUDesc, '
											+	'	Convert(VarChar, dd.DelayStart, 120), '
											+  	'  	p.Prod_Code, ' 
											+  	'  	p.Prod_Desc, ' 
											+	'	dd.ShiftDesc, '
											+	'	dd.CrewDesc, '
											+	'  	sl.LineStatusDesc, '
											+	'	tef.TEFault_Name, '
											+	'	pu.PU_Desc, '
											+	'	dd.EventReasonName1, '
											+	'	dd.EventReasonName2, '
											+	'	dd.EventReasonName3, '
											+	'	dd.EventReasonName4, '
											+	'	dd.DelayCategoryDesc, '
											+  	'	dd.ProductionDay '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand2 = 	'	FROM			#DelayDetail dd '
					+		'	Left	JOIN	dbo.Prod_Units 			pu WITH(NOLOCK)	ON	pu.PU_Id = dd.SourcePUId '
					+		'			JOIN	#PUList					pul	ON	pul.PUId = dd.PUId '
--					+		'	Left 	JOIN	#LineStatusList			sl	ON 	sl.LineStatusSchedId = dd.LineStatusSchedId '
-- New 01-05-2009
					+		'	Left	JOIN	#LineStatusList			sl	ON	sl.LineStatusId = dd.LineStatusId '
					+		'												AND	sl.PUId = dd.PUId '
					+		'												AND dd.DelayStart >= sl.LineStatusStart '
					+		'												AND  (dd.DelayStart < sl.LineStatusEnd OR sl.LineStatusEnd IS NULL) '
					+		'	Left 	JOIN	dbo.Timed_Event_Fault 	tef WITH(NOLOCK) ON	dd.TEFaultId = tef.TEFault_Id	'
					+		'	Left	JOIN	dbo.Products			p	WITH(NOLOCK) ON	dd.ProdId = p.Prod_Id '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand3 = ''
END
ELSE
BEGIN
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - common sums
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 =	@chrSQLCommand1 	+ 	',	LTrim(RTrim(Str(Sum(Convert(Float, dd.UpTimeDurationInSec)) /60.0, 50, 1))), '
												+	'	LTrim(RTrim(Str(Sum(Convert(Float, dd.DelayDurationInSec )) /60.0, 50, 1))), '
												+	'	Sum(dd.DelayCount), '
												+ 	'	Sum(dd.DelayGreaterThanTCount), '
												+	'	Sum(dd.UpTimeGreaterThanTCount), '
												+	'	Null, '
												+	'	Min(dd.UpTimeRcdFlag) '

	SET	@chrSQLCommand2 = '	FROM			#DelayDetail dd '
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes Production Line
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%PLId%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pul.PLDesc '
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ 'JOIN	#PUList pul ON pul.PUId = dd.PUId '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', pul.PLDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes Production Unit
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%PUId%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pul.PUDesc '
		-------------------------------------------------------------------------------------------
		IF	(@RptStopHistoryMinorGroupBy NOT LIKE '%PLId%')

		BEGIN
			SET	@chrSQLCommand2 = @chrSQLCommand2	+ ' JOIN	#PUList pul ON pul.PUId = dd.PUId '
		END
		-------------------------------------------------------------------------------------------
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', pul.PUDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - eliminate delay start
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProdCode
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%ProdCode%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', p.Prod_Code, p.Prod_Desc'
		
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ ' Left	JOIN	dbo.Products p	ON	dd.ProdId = p.Prod_Id '
		
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', p.Prod_Code, p.Prod_Desc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null, Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ShiftDesc
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%ShiftDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.ShiftDesc'
		
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', dd.ShiftDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes CrewDesc
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%CrewDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.CrewDesc'
		
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', dd.CrewDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProdStatus
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%ProdStatus%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', sl.LineStatusDesc'
		SET	@chrSQLCommand2 = @chrSQLCommand2 
						+		'	Left JOIN (SELECT DISTINCT PUId,LineStatusId,LineStatusDesc FROM	#LineStatusList)	sl	ON 	sl.LineStatusId = dd.LineStatusId '
						+		'												AND	sl.PUId = dd.PUId '
		
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', sl.LineStatusDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes TEFaultValue
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%TEFaultValue%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ 	', 	tef.TEFault_Name'
		SET	@chrSQLCommand2 = @chrSQLCommand2 	+	'	Left	JOIN	dbo.Timed_Event_Fault tef ON	dd.TEFaultId = tef.TEFault_Id	'
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ 	', 	tef.TEFault_Name '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes SourcePUId
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%SourcePUDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ 	', 	pu.PU_Desc'
		SET	@chrSQLCommand2 = @chrSQLCommand2	+	'	Left JOIN	dbo.Prod_Units 	pu	ON pu.PU_Id = dd.SourcePUId '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ 	', 	pu.PU_Desc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes EventReasonName1
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%EventReasonName1%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.EventReasonName1 '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', dd.EventReasonName1 '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes EventReasonName2
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%EventReasonName2%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.EventReasonName2 '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', dd.EventReasonName2 '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes EventReasonName3
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%EventReasonName3%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.EventReasonName3 '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', dd.EventReasonName3 '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes EventReasonName4
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%EventReasonName4%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.EventReasonName4 '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', dd.EventReasonName4 '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes DelayCategoryDesc
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%DelayCategoryDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.DelayCategoryDesc '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', dd.DelayCategoryDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProductionDay
	-----------------------------------------------------------------------------------------------
	IF	(@RptStopHistoryMinorGroupBy LIKE '%ProductionDay%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', dd.ProductionDay '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', dd.ProductionDay '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
END
---------------------------------------------------------------------------------------------------
IF	(@RptStopHistoryMajorGroupBy = '!Null')
BEGIN
	IF Len(@chrSQLCommand3) > 0
	BEGIN
		SET	@i = CharIndex(',', @chrSQLCommand3, 1)
		SET	@chrSQLCommand3 = Substring(@chrSQLCommand3, 1, @i - 1) + ' ' + Substring(@chrSQLCommand3, @i + 1, Len(@chrSQLCommand3))
	END
END
---------------------------------------------------------------------------------------------------
-- RS4: Apply minor grouping
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand = @chrSQLCommand1 + ' ' + @chrSQLCommand2 + ' ' + @chrSQLCommand3
---------------------------------------------------------------------------------------------------
--PRINT 	'		Final SQLCommand: ' + @chrSQLCommand -- debugdel


---------------------------------------------------------------------------------------------------
INSERT INTO		#FinalResultSet (
				PUId,
				ProdId,
				UpTime,
				DownTime,
				Stops,
				StopsGreaterThanT,
				UpTimeGreaterThanT,
				CommentIdList,
				Border1,
				PLDesc,
				PUDesc,
				DelayStart,
				ProdCode,
				ProdDesc,
 				ShiftDesc,
 				CrewDesc,
 				ProdStatus,
 				TEFaultValue,
 				SourcePUDesc,
 				EventReasonName1,
 				EventReasonName2,
 				EventReasonName3,
 				EventReasonName4,
				DelayCategoryDesc,
				ProductionDay)
EXEC	(@chrSQLCommand)

PRINT	'SQL: ' + @chrSQLCommand
-------------------------------------------------------------------------------
-- RS4: Major Grouping calculations
-------------------------------------------------------------------------------
IF	@RptStopHistoryMajorGroupBy = 'PUId' OR @RptStopHistoryMajorGroupBy = '!Null'
BEGIN
	UPDATE	fr
		SET	fr.TotalStops 				= hi.TotalStops,
				fr.TotalUptime			= Convert(Float, hi.TotalUptime),
				fr.AvailableTimeInMin 	= hi.AvailableTimeInMin
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo	hi ON hi.PUId = fr.PUId
END
ELSE	IF	@RptStopHistoryMajorGroupBy = 'ProdId' 
BEGIN
	UPDATE	fr
		SET	fr.TotalStops 				= hi.TotalStops,
				fr.TotalUptime				= Convert(Float, hi.TotalUptime),
				fr.AvailableTimeInMin	= hi.AvailableTimeInMin
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo	hi ON hi.ProdId = fr.ProdId	
END
ELSE
BEGIN
	UPDATE	fr
		SET	fr.TotalStops 				= hi.TotalStops,
				fr.TotalUptime				= Convert(Float, hi.TotalUptime),
				fr.AvailableTimeInMin	= hi.AvailableTimeInMin
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo	hi ON 	hi.PUId = fr.PUId
								AND	hi.ProdId = fr.ProdId
END
---------------------------------------------------------------------------------------------------
UPDATE	#FinalResultSet 
SET	PercentStops 	= 	Case	WHEN	TotalStops > 0
								THEN	LTrim(RTrim(Str(Convert(Float, Stops) / Convert(Float, TotalStops), 25, 4)))
						END,
	-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
	MTBS 			= 	Case	WHEN	Stops > 0
								THEN	LTrim(RTrim(Str(TotalUptime / Convert(Float, Stops), 25, 1))) 
						END,
	MTTR 			= 	Case	WHEN	Stops > 0
								THEN	LTrim(RTrim(Str(Convert(Float, Downtime) / Convert(Float, Stops), 25, 1))) 
						END
---------------------------------------------------------------------------------------------------
UPDATE	#FinalResultSet 
	SET	Availability	=	-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
							Case	WHEN	(Convert(Float, MTBS) + Convert(Float, MTTR)) > 0
									THEN	LTrim(RTrim(Str(Convert(Float, MTBS) / (Convert(Float, MTBS) + Convert(Float, MTTR)), 25, 6)))
							END
---------------------------------------------------------------------------------------------------
-- UPDATE COMMENT FIELD
---------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------
-- Keep just the first commentId in case is more than one
--------------------------------------------------------------------------------------------------------------------
UPDATE #FinalResultSet
SET CommentIdList = SUBSTRING(CommentIdList, 0, CHARINDEX('|',CommentIdList,0))
WHERE CommentIdList IS NOT NULL AND ISNUMERIC(CommentIdList) = 0

--------------------------------------------------------------------------------------------------------------------
-- Get the Comments for first level
--------------------------------------------------------------------------------------------------------------------
UPDATE fr
		SET	Comments	= CASE  WHEN   LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
								THEN   LEFT(CONVERT(NVARCHAR(MAX),c.Comment),3997) + '...'
								WHEN   LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 <= 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
								THEN   (CONVERT(NVARCHAR(MAX),c.Comment))
								ELSE   ''
								END  ,
			NextComment_Id = c.NextComment_Id
FROM   gbdb.dbo.Comments c WITH(NOLOCK)
JOIN   #FinalResultSet fr ON fr.CommentIdList  = c.Comment_Id 

--------------------------------------------------------------------------------------------------------------------
-- Iterate to get all comment levels
--------------------------------------------------------------------------------------------------------------------
SELECT @intId = MAX(RcId)    ,
             @i = 1                     ,
             @j = 1
FROM #FinalResultSet

WHILE @i <= @intId
BEGIN
       IF EXISTS (   SELECT * FROM #FinalResultSet
                           WHERE RcId = @i
                           AND NextComment_Id IS NOT NULL   )
       BEGIN
             SELECT @NextCommentId = NextComment_Id,
					@CommentId = CommentIdList
             FROM #FinalResultSet
             WHERE RcId = @i

			 SET @j=1
             WHILE @NextCommentId IS NOT NULL AND @j <= 10
             BEGIN

                    -- Subtract the comments length by 2 to deal with PPA comments issue
					UPDATE #FinalResultSet--ct
							SET		Comments =	CASE  WHEN   CommentIdList > 0 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
															THEN   CONVERT(NVARCHAR(MAX),Comments) + '|**|' + LEFT(CONVERT(NVARCHAR(MAX),c.Comment),3994) + '...'
															WHEN   CommentIdList > 0 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 <= 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
															THEN   CONVERT(NVARCHAR(MAX),Comments) + '|**|' + (CONVERT(NVARCHAR(MAX),c.Comment))
															ELSE CONVERT(NVARCHAR(MAX),Comments)
															END 
					FROM	gbdb.dbo.Comments c WITH(NOLOCK)
					WHERE  c.Comment_Id = @NextCommentId
					AND RcId = @i

					SELECT	@NextCommentId = NextComment_Id
					FROM gbdb.dbo.Comments WITH(NOLOCK)
					WHERE Comment_Id = @NextCommentId
					SET @j = @j + 1
             END
       END

       SET @i = @i + 1
END
---------------------------------------------------------------------------------------------------
-- RS4: Return result set
---------------------------------------------------------------------------------------------------

SELECT		PUId,
			ProdId,
			Border1,
			PLDesc,
			PUDesc,
			DelayStart,
			ProductionDay,
			ProdCode,
			ProdDesc,
			ShiftDesc,
			CrewDesc,
			UpTime,
			DownTime,
			ProdStatus,
			TEFaultValue,
			SourcePUDesc,
			EventReasonName1,
			EventReasonName2,
			EventReasonName3,
			EventReasonName4,
			Stops,	
			StopsGreaterThanT,
			UpTimeGreaterThanT,
			PercentStops,
			MTTR,
			-- FO-00847-B: 1) Rename MTBF to MTBS in all report sections (Stop Summary and detail data)
			MTBS,
			Availability,
			DelayCategoryDesc,
			Comments,
			Border2
	FROM	#FinalResultSet
ORDER BY	PUId, ProdId, PLDesc, PUDesc, DelayStart


--=================================================================================================
--PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
--PRINT 	'THE END ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + Convert(VarChar, @@TRANCount) 
-------------------------------------------------------------------------------
-- Select from tables -- used for debugging only comment before installation
-------------------------------------------------------------------------------
-- SELECT 'MiscInfo', 				* FROM #MiscInfo
-- SELECT 'HdrInfo',				* FROM #HdrInfo
-- SELECT 'PUList', 				* FROM #PUList
-- SELECT 'FilterLineStatusList',	* FROM #FilterLineStatusList
-- SELECT 'FilterProdList',			* FROM #FilterProdList
-- SELECT 'FilterShiftList',		* FROM #FilterShiftList
-- SELECT 'FilterCrewList',			* FROM #FilterCrewList
-- SELECT 'FilterEventReasonIdList',* FROM #FilterEventReasonIdList
-- SELECT 'LineStatusList', 		* FROM #LineStatusList
-- SELECT 'ShiftList',				* FROM #ShiftList
-- SELECT 'VisibleFieldList',		* FROM #VisibleFieldList
-- SELECT 'DelayDetail',			* FROM #DelayDetail ORDER BY PUId, UpTimeStart
 --SELECT 'FinalResultSet',			* FROM #FinalResultSet where PUId = 388

-------------------------------------------------------------------------------
-- Drop tables
-------------------------------------------------------------------------------
DROP	TABLE	#MiscInfo
DROP 	TABLE	#HdrInfo
DROP	TABLE	#PUList
DROP	TABLE	#FilterLineStatusList
DROP 	TABLE	#FilterProdList
DROP	TABLE	#FilterShiftList
DROP 	TABLE	#FilterCrewList
DROP	TABLE	#FilterSourcePUList
DROP	TABLE	#FilterEventReasonIdList
DROP 	TABLE	#LineStatusList
DROP	TABLE	#ShiftList
DROP	TABLE	#VisibleFieldList
DROP	TABLE	#DelayDetail
DROP	TABLE	#FinalResultSet
DROP	TABLE	#ReasonsToExclude


GO
GRANT EXECUTE ON [dbo].[spLocal_RptStopHistory_HTML5] TO [OpDBManager]
GO