
------------------------------------------------------------------------------------------------------------------------
---- Prototype definition
------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptSpliceReject',
		@Inputs		= 13, -- Put the number of inputs here for support purposes
		@Version	= '1.7'  -- Number should match version manager, no exceptions.

SELECT @AppId = MAX(App_Id) + 1 
		FROM AppVersions

----=====================================================================================================================
----	Update table AppVersions
----=====================================================================================================================
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

-------------------------------------------------------------------------------------------------------------------------
---- Update client_sp_Prototype table
----------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM Client_SP_Prototypes WHERE sp_name = 'spLocal_RptSpliceReject')
BEGIN
	INSERT INTO client_sp_prototypes (	system, 
						stored_proc, 
						server_cursor, 
						prepare_sp,
						updated,
						input,
						timeout,
						command_text,
						sp_name)
	SELECT 				1,
						1,
						0,
						1,
						1,
						3,
						244,
						'spLocal_RptSpliceReject', 
						'spLocal_RptSpliceReject'
END

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[spLocal_RptSpliceReject]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[spLocal_RptSpliceReject]
GO

-----------------------------------------------------------------------------------------------------
---- !!!!!!!!!! TO VIEW THIS SP PLEASE SET TAB SPACING TO 4 !!!!!!!!!!
-----------------------------------------------------------------------------------------------------
---- Desc:
---- This stored procedure returns Splice information for a give time period
-----------------------------------------------------------------------------------------------------
---- Major Grouping:
---- Production Unit
---- Product
-----------------------------------------------------------------------------------------------------
---- Minor Grouping:
---- None
---- Production Unit
---- Product
---- Shift
---- Team
---- Production Status
---- Location
---- EventReasonLevel1
---- Production Day
---------------------------------------------------------------------------------
---- Filters: 
---- Production Unit
---- Product
---- Shift
---- Team
---- Production Status
---- Location
---- Reason1
---------------------------------------------------------------------------------
---- Calculations:
---- Splices Attempted	- 	Count of waste events
---- Splices Successful 	- 	Count of waste events where amount = 1
---- Splices Failed		-	Count of waste events where amount = 0
---- Splice Efficiency	-	Sum(Splices Successful) / Sum(Splices Attempted)
---- Success Rate			-	Sum(Splices Successful per Minor Group)/Sum(Splices Attempted per Minor Group)
---- Status				-	If Amount = 1 then OK else Failed
---- % of Event			- 	Event Count/Total Event Count
-----------------------------------------------------------------------------------------------------
---- Nested sp: 
---- spCmn_ReportCollectionParsing
---- spCmn_GetReportParameterValue
---- spCmn_GetRelativeDate
-----------------------------------------------------------------------------------------------------
---- SP sections:
---- 1.  CreateTables
---- 2.  ParameterValues
---- 3.  CheckParameters
---- 4.  PrepareTables
---- 5.  TimeIntervals
---- 6.  SpliceDetail
---- 7.  ResultSet1	>>> Miscellaneous information
---- 8.  ResultSet2	>>> Header information
---- 9.  ResultSet3	>>> Splice detail/summary
-----------------------------------------------------------------------------------------------------
---- Error codes:
---- 1	Start Date is not a valid date option
---- 2	End Date is not a valid date option
---- 3	Start Date is greater than End Date
---- 4	Please select a production unit for the report
---- 5
-----------------------------------------------------------------------------------------------------
---- Edit History:
---- RP 18-Mar-2004 Case #49684: Development
---- RP 06-Apr-2004 Case #49684: added code to support MajorGroupBy = "None"
---- RP 14-Apr-2004 Case #49684: changed #FinalResultSet column name "SpliceEff" to "SpliceEfficiency"
---- 							   to match the parameter to match the value being returned by FormatRptSpliceHistory
----							   web page
---- RP 28-Jun-2004 Case #51826: added code to support MinorGroupBy = "PLId" and "PUId"
-----------------------------------------------------------------------------------------------------
---- RP 30-May-2005 SlimSoft	Project: 05-P004-PG-BF-HistoryRpts
----							Added logic to support "Minor Group" Production Day
----							Fixed a typo in result set 2 that was causing the value of the product list 
----							to be incorrect
----							Removed PLId and ProdId from final select Order By. This was preventing the columns
----							from sorting as expected.
---- RP 02-Jun-2005 SlimSoft	Project: 05-P004-PG-BF-HistoryRpts
----							Fixed bug with "Null" Product list on report header
---- RP 15-Sep-2005 SlimSoft	Project: 05-P015-PG-BF-MiscInfo
----							Fixed bug with Shift logic
---- MT 06-OCT-2008 P&G		Fixed the store procedure to work with the Old Line Status ( PR Renewal Project)
---------------------------------------------------------------------------------------------------------
---- From here below we are versioning according Serena Version Manager
---- 1.3		2010-19-17		Mike Thomas				FO-01129 Fixed issue with data type mismatch for reason selections
---- 1.4		2013-11-18		TCS LEDS Product Team	FO-01683 Removing pProficyPurge account as per compatiblity with Proficy Version 5. (This account is not needed for V5)
---- 1.5		2019-07-26		Damian Campana 			Modify the calculation for the Production Day
---- 1.6		2019-08-15		Gustavo Conde			Fix for ussing the first value from #FinalResultSet.CommentIdList
---- 1.7		2019-08-28		Damian Campana			Capability to filter with the time option 'Last Week'
-----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------
CREATE PROCEDURE  dbo.spLocal_RptSpliceReject
--DECLARE
	@inTimeOption						INT				= NULL			,
	@RptPUIdList						NVARCHAR(MAX)	= NULL			,  
	@RptSourcePUIdList					NVARCHAR(MAX)	= '!Null'		,  
    @RptProdIdList						NVARCHAR(MAX)	= '!Null'		,
	@RptEventReasonIdList				NVARCHAR(MAX)	= '!Null'		,
	@RptShiftDescList					NVARCHAR(50)	= 'All'			,
	@RptCrewDescList					NVARCHAR(50)	= 'All'			,
	@RptLineStatusIdList				NVARCHAR(250)	= 'All'			,
	@RptSpliceHistoryMajorGroupBy		NVARCHAR(25)	= 'PUId'		,			
	@RptSpliceHistoryMinorGroupBy		NVARCHAR(25)	= 'None'		,
    @RptStartDateTime					DATETIME		= NULL			,  
    @RptEndDateTime						DATETIME		= NULL			,
	@RptSpliceHistoryColumnVisibility	NVARCHAR(MAX)	= '!Null'			

--with encryption
AS
SET NOCOUNT ON
--TESTING
--SELECT
--	 @inTimeOption						= 1
--	,@RptPUIdList						= '400|509|576'
--	,@RptSourcePUIdList					= '401|402|403|404|405|406|407|408|409|410|411|510|511|512|513|514|515|516|517|518|519|520|577|578|579|580|581|582|583|584|585|586|587|400|509|576'
--	,@RptProdIdList						= '!Null'
--	,@RptEventReasonIdList				= '1~2769|1~2770|1~2772|1~2773|1~2774|1~2775|1~2776|1~2777|1~2778|1~2779|1~2784|1~2785|1~2788|1~2789|1~2792|1~2793|1~2794|1~2795|1~2796|1~2797|1~13901|1~13902|1~13903|1~13904|1~2804|1~2805|1~2806|1~2807|1~2808|1~2809|1~2814|1~2815|1~2816|1~2817|1~2818|1~2819|1~2820|1~2821|1~2822|1~13905|1~13906|1~2823|1~2824|1~2827|1~2834|1~2835|1~2836|1~2837|1~2838|1~2839'
--	,@RptShiftDescList					= 'All'
--	,@RptCrewDescList					= 'All'
--	,@RptLineStatusIdList				= 'All'
--	,@RptSpliceHistoryMajorGroupBy		= 'PUId'
--	,@RptSpliceHistoryMinorGroupBy		= 'None'
--	,@RptStartDateTime					= '2019-07-13 06:00:00'
--	,@RptEndDateTime					= '2019-07-16 06:00:00'
--	,@RptSpliceHistoryColumnVisibility	= '!Null'

DECLARE	
-------------------------------------------------------------------------------
-- Report parameters
-------------------------------------------------------------------------------
	@RptOwnerId							Int 			,
	@RptShiftLength						Int				,
	@RptSpliceHistoryCommentColWidth	Int				,
	@RptStartDate						VarChar(25) 	,			
	@RptEndDate							VarChar(25) 	,			
	@RptStartTime						VarChar(25) 	,
	@RptEndTime							VarChar(25) 	,
	--@RptSpliceHistoryColumnVisibility 	VarChar(4000)	,
	--@RptSpliceHistoryMajorGroupBy		VarChar(50)		,
	--@RptSpliceHistoryMinorGroupBy		VarChar(500)	,
	--@RptPUIdList						VarChar(1000) 	,
	--@RptProdIdList						VarChar(1000)	,
	--@RptSourcePUIdList					VarChar(1000)	,
	--@RptEventReasonIdList				VarChar(8000)	,
	--@RptShiftDescList					VarChar(50)		,
	--@RptCrewDescList					VarChar(50)		,
	--@RptLineStatusIdList				VarChar(500)	,
	@RptLineStatusDescList				VarChar(4000)	,		-- Note: Line status is a data_type. Line status names can be found in Phrases table
	@RptTitle							VarChar(255)	,
	@RptSortType						VarChar(5)		,
	@RptShiftStart						DateTime		,
	@vchTimeOption						VarChar(50)		,
-------------------------------------------------------------------------------
-- Other variables
-- Note: @c_.... are cursor variables
-------------------------------------------------------------------------------
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
	@chrProdDescList	VarChar(8000),
	--
	@c_chrShiftDesc		VarChar(10),
	@c_chrCrewDesc		VarChar(10),
	@c_chrProdCode		VarChar(50),
	@c_chrPUDesc		VarChar(50),
	--
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
	@intPadCount			Int,
	@intShiftOffset			Int,
	@intId					INT,
	@NextCommentId			INT, 
	@CommentId				INT,
	--
	@c_intPUId				Int,
	@c_intWEDId				Int,
	@c_intCSId				Int,
	@c_intLineStatusSchedId	Int,
	@c_intLineStatusId		Int,
	@c_intWTCId				Int,
	@c_intLookUpPUId		Int,
	@c_intProductionVarId	Int,
	--
	@fltDBVersion			Float,
	@fltProductionTime		Float,
	--
 	@dtmStartDateTime 		DateTime,
 	@dtmEndDateTime 		DateTime,
 	@dtmDummyDate			DateTime,
 	@dtmBaseDate			DateTime,
 	@dtmShiftDay			DateTime,
	@dtmTempDate			DateTime,
	--
 	@c_dtmShiftStart		DateTime,
 	@c_dtmShiftEnd			DateTime,
	@c_dtmLineStatusStart	DateTime,
	@c_dtmLineStatusEnd		DateTime

---------------------------------------------------------------------------------------------------
-- Update Variables Major Group & Minor Group
---------------------------------------------------------------------------------------------------
SELECT @RptSpliceHistoryMajorGroupBy = CASE 
											WHEN @RptSpliceHistoryMajorGroupBy IS NULL	THEN '!Null' 
											WHEN @RptSpliceHistoryMajorGroupBy = 'None' OR @RptSpliceHistoryMajorGroupBy = ''	THEN '!Null'
											ELSE @RptSpliceHistoryMajorGroupBy
									   END

SELECT @RptSpliceHistoryMinorGroupBy = CASE 
											WHEN @RptSpliceHistoryMinorGroupBy IS NULL	THEN '!Null' 
											WHEN @RptSpliceHistoryMinorGroupBy = 'None' OR @RptSpliceHistoryMinorGroupBy = ''	THEN '!Null'
											ELSE  @RptSpliceHistoryMinorGroupBy
									   END

									 
---------------------------------------------------------------------------------------------------
-- Create table variables
---------------------------------------------------------------------------------------------------
DECLARE	@tblProduction	TABLE (
		PUId 					Int,
		ProdId					Int,
		MGPadCount				Int,
		MGProductionTimeInSec	Int )
---------------------------------------------------------------------------------------------------
-- Create temporary tables.
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MiscInfo', 'U') IS NOT NULL  DROP TABLE #MiscInfo
CREATE TABLE	#MiscInfo (
	CompanyName			VarChar(50),
	SiteName			VarChar(50),
	RptOwnerDesc		VarChar(50),
	RptStartDateTime 	VarChar(25),
	RptEndDateTime		VarChar(25),
	FilterShift			VarChar(4000),
	FilterCrew			VarChar(4000),
	FilterLineStatus	VarChar(4000),
	FilterProduct		VarChar(MAX),
	FilterLocation		VarChar(MAX),
	FilterReason1		VarChar(MAX),
	RptTitle			VarChar(255),
	MajorGroupBy		VarChar(8000),
	MinorGroupBy		VarChar(8000),
	CommentColWidth		Int,
	CommentTableFlag	Int )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#HdrInfo', 'U') IS NOT NULL  DROP TABLE #HdrInfo
CREATE TABLE	#HdrInfo (
	PUId				Int,
	ProdId				Int,
	LineStatusId		Int,
	PUDesc				VarChar(50),
	LineStatusDesc		VarChar(50),
	ProdCode			VarChar(50),
	ShiftDesc			VarChar(10),
	CrewDesc			VarChar(10),
	SplicesAttempted	Int,
	SplicesSuccessful	Int,
	SpliceEfficiency	Float,
	SplicesFailed		Int )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#PUList', 'U') IS NOT NULL  DROP TABLE #PUList
CREATE TABLE	#PUList (
	RcdId			Int,
	PLId			Int,
	PLDesc			VarChar(100),
	PUId			Int,
	PUDesc			VarChar(50),
	AlternativePUId	Int,		-- This PUId will be used if no schedule or line status has been configured for
								-- the selected PUId
	LookUpPUId		Int,		-- Coalesce between PUId and AlternativePUId
	ProductionVarId	Int )
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
IF OBJECT_ID('tempdb.dbo.#FilterSourcePUIdList', 'U') IS NOT NULL  DROP TABLE #FilterSourcePUIdList
CREATE TABLE	#FilterSourcePUIdList (
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
	ProdId				Int,
	LineStatusSchedId	Int,
	LineStatusId		Int,
	LineStatusDesc		VarChar(50),
	LineStatusStart		DateTime,
	LineStatusEnd		DateTime,
	DurationInSec		Int,
	PadCount			Int )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ShiftList', 'U') IS NOT NULL  DROP TABLE #ShiftList
CREATE TABLE	#ShiftList (
	CSId		Int,
	PUId		Int,
	ShiftDesc	VarChar(10),
	CrewDesc	VarChar(10),
	ShiftStart	DateTime,
	ShiftEnd	DateTime )		
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#VisibleFieldList', 'U') IS NOT NULL  DROP TABLE #VisibleFieldList
CREATE TABLE	#VisibleFieldList (
	RcdId		Int,
	ColOrder	Int,
	FieldName	VarChar(50))
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#SpliceDetail', 'U') IS NOT NULL  DROP TABLE #SpliceDetail
CREATE TABlE	#SpliceDetail (
	PLId					Int,
	PUId					Int,
	ProdId					Int,
	WEDId					Int,
	SpliceTimeStamp			DateTime,
	OffSetFromMidnightInSec	Int,
	LineStatusId			Int,
	LineStatusSchedId		Int,
	ProdStatus				VarChar(50),
	ProductionDay			DateTime, -- VarChar(25),
	ShiftDesc				VarChar(25),
	CrewDesc				VarChar(25),
	SourcePUId				Int,		
	SourcePUDesc			VarChar(50),
	WasteRL1Id				Int,
	EventReasonName1		VarChar(100),
	SpliceStatus			Int,
	SpliceSuccCount			Int,
	SpliceFailedCount		Int,
	EventCount				Int,
	CauseCommentId			VarChar(1000) )

CREATE NONCLUSTERED INDEX RD_WEDId_PUId_ProdId_Idx	ON #SpliceDetail (WEDId, PUId, ProdId)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FinalResultSet', 'U') IS NOT NULL  DROP TABLE #FinalResultSet
CREATE TABLE	#FinalResultSet (
	RcId				INT IDENTITY,
	PUId				Int,
	ProdId				Int,
	Border1				VarChar(1),
	PLDesc				VarChar(100),
	PUDesc				VarChar(100),
	SpliceTimeStamp		VarChar(25),	-- from #SpliceDetail	
	ProductionDay		VarChar(25),
	ProdCode			VarChar(50), 	-- from dbo.Products
	ShiftDesc			VarChar(50),	-- from dbo.Crew_Schedule
	CrewDesc			VarChar(50),	-- from dbo.Crew_Schedule
	ProdStatus			VarChar(50),	-- from dbo.Local_PG_LineStatus
	SourcePUDesc		VarChar(100),	-- from dbo.Prod_Units
	EventReasonName1	VarChar(100), 	-- from dbo.Event_Reasons
	Status				Int,
	TotalSplices		Int,			-- from #SpliceDetail
	SucSplices			Int,
	FailedSplices		Int,
	SuccessRate			Float,
	PercentOfEvent		Float,
	SpliceEfficiency	Float,
	CommentId			VarChar(1000),
	Comments			NVARCHAR(MAX),
	NextComment_Id		VarChar(1000),
	Border2				Int,
	TotalEventCount		Int )
--=============================================================================
Print 'Initialize Temp Tables - ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
-- Done to minimize recompiles
--=============================================================================
SET @i = (SELECT 	Count(*) FROM	#MiscInfo)
SET @i = (SELECT	Count(*) FROM 	#HdrInfo)
SET @i = (SELECT	Count(*) FROM 	#PUList)
SET @i = (SELECT	Count(*) FROM	#FilterProdList)
SET @i = (SELECT	Count(*) FROM	#FilterShiftList)
SET @i = (SELECT	Count(*) FROM	#FilterCrewList)
SET @i = (SELECT	Count(*) FROM	#FilterSourcePUIdList)
SET @i = (SELECT	Count(*) FROM	#FilterEventReasonIdList)
SET @i = (SELECT	Count(*) FROM	#LineStatusList)
SET @i = (SELECT	Count(*) FROM	#ShiftList)
SET @i = (SELECT	Count(*) FROM 	#VisibleFieldList)
SET @i = (SELECT	Count(*) FROM 	#SpliceDetail)
SET @i = (SELECT	Count(*) FROM	#FinalResultSet)
--=============================================================================
Print 'ParameterValues - ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
--=============================================================================
/*IF	Len(@RptName) > 0	
BEGIN
	EXEC	spCmn_GetReportParameterValue @RptName, 'intRptOwnerId'									, '1'				, @RptOwnerID OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'strRptPUIdList'								, Null				, @RptPUIdList	OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'strRptProdIdList'								, '!Null'			, @RptProdIdList	OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'strRptSourcePUIdList'							, '!Null'			, @RptSourcePUIdList OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'strRptEventReasonIdList'						, '!Null'			, @RptEventReasonIdList	OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'strRptTitle'									, 'Splice History'	, @RptTitle	OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'strRptSortType'								, 'ASC'				, @RptSortType OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strShifts1'							, '!Null'			, @RptShiftDescList OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strTeamsByName'						, '!Null'			, @RptCrewDescList OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strLineStatusID1'						, 'All'				, @RptLineStatusIdList OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strLineStatusName1'					, 'All'				, @RptLineStatusDescList OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strRptSpliceHistoryColumnVisibility'	, '!Null'			, @RptSpliceHistoryColumnVisibility OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strRptSpliceHistoryMajorGroupBy'		, 'PUId'			, @RptSpliceHistoryMajorGroupBy OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_strRptSpliceHistoryMinorGroupBy'		, 'None'			, @RptSpliceHistoryMinorGroupBy OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_StartShift'							, '6:30:00'			, @RptShiftStart OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_ShiftLength'							, 8					, @RptShiftLength OUTPUT
	EXEC	spCmn_GetReportParameterValue @RptName, 'Local_PG_intRptSpliceHistoryCommentColWidth'	, 30				, @RptSpliceHistoryCommentColWidth OUTPUT
END
ELSE
BEGIN
	SELECT	@RptOwnerId							= 1,
			@RptPUIdList						= 537, --'30|32|58',
			@RptProdIdList						= '!Null',
			@RptSourcePUIdList					= '!Null',	
			@RptEventReasonIdList				= '!Null',
			@RptTitle							= 'Splice History',
			@RptSortType						= 'ASC',
			@RptShiftDescList					= 'All',
			@RptCrewDescList					= 'All',
			@RptLineStatusIdList				= 'All', 		--'2^Vorgesehene Produktion',
			@RptLineStatusDescList				= 'All', 		--'Vorgesehene Produktion',
			@RptSpliceHistoryColumnVisibility	= '!Null',  	-- Options: 'SpliceTimeStamp|ProductionDay|ProdCode|ShiftDesc|CrewDesc|
																-- ProdStatus|SourcePUDesc|EventReasonName1|Status|TotalSplices|
																-- SucSplices|FailedSplices|SpliceEfficiency|SuccessRate|CommentId				
			@RptSpliceHistoryMajorGroupBy		= 'ProdId',    	-- Options: PUId|ProdId
			@RptSpliceHistoryMinorGroupBy		= 'ProductionDay', 		-- Options: !Null OR ShiftDesc|CrewDesc|ProdCode|ProductionDay 
																-- ProdStatus|SourcePUDesc|EventReasonName1|PLId|PUId
			@RptShiftStart						= '6:15:00 AM',
			@RptShiftLength						= 8,
			@RptSpliceHistoryCommentColWidth	= 30
END*/


-------------------------------------------------------------------------------------------------------------------
-- Time Options
-------------------------------------------------------------------------------------------------------------------
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
		SELECT	@RptStartDateTime = dtmStartTime ,
				@RptEndDateTime = dtmEndTime
		FROM [dbo].[fnLocal_DDSStartEndTime](@vchTimeOption)

	END
		
-------------------------------------------------------------------------------
-- Check report parameters
-------------------------------------------------------------------------------
--Print '-----------------'
--Print 'Report Parameters' 
--Print '-----------------'
--Print 'RptName: ' + @RptName
--Print 'RptOwnerId: ' + Convert(VarChar, @RptOwnerId)
--Print 'RptStartDate: ' + Coalesce(@RptStartDateTime, '')
--Print 'RptEndDate: ' + Coalesce(@RptEndDateTime, '')
--Print 'RptPUIdList: ' + Coalesce(@RptPUIdList, '')
--Print 'RptProdIdList: ' + Coalesce(@RptProdIdList, '')
--Print 'RptSourcePUIdList:' + Coalesce(@RptSourcePUIdList, '')
--Print 'RptEventReasonIdList:' + Coalesce(@RptEventReasonIdList, '')
--Print 'RptTitle: ' + Coalesce(@RptTitle, '')
--Print 'RptSortType: ' + Coalesce(@RptSortType, '')
--Print 'RptShiftDescList: ' + Coalesce(@RptShiftDescList, '')
--Print 'RptCrewDescList: ' + Coalesce(@RptCrewDescList, '')
--Print 'RptLineStatusIdList: ' + Coalesce(@RptLineStatusIdList, '')
--Print 'RptLineStatusDescList: ' + Coalesce(@RptLineStatusDescList, '')
--Print 'RptSpliceHistoryColumnVisibility: ' + Coalesce(@RptSpliceHistoryColumnVisibility, '')
--Print 'RptSpliceHistoryMajorGroupBy: ' + Coalesce(@RptSpliceHistoryMajorGroupBy, '')
--Print 'RptSpliceHistoryMinorGroupBy: ' + Coalesce(@RptSpliceHistoryMinorGroupBy, '')
--Print 'RptShiftStart: ' + Coalesce(Convert(VarChar, @RptShiftStart), '')
--Print 'RptShiftLength: ' + Coalesce(Convert(VarChar, @RptShiftLength), '')
--Print '-----------------'
---------------------------------------------------------------------------------------------------
Print 'Check Parameters - ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) -- debug
---------------------------------------------------------------------------------------------------
-- Check Parameter: Database version
---------------------------------------------------------------------------------------------------
IF	(	SELECT		IsNumeric(App_Version)
			FROM	AppVersions
			WHERE	App_Id = 2) = 1
BEGIN
	SELECT		@fltDBVersion = Convert(Float, App_Version)
		FROM	AppVersions
		WHERE	App_Id = 2
END
ELSE
BEGIN
	SELECT	@fltDBVersion = 1.0
END
---------------------------------------------------------------------------------------------------
Print	'DBVersion: ' + RTrim(LTrim(Str(@fltDBVersion, 10, 2))) -- debug
---------------------------------------------------------------------------------------------------
-- Check Parameter: Company, Site Name and report owner description
---------------------------------------------------------------------------------------------------
SELECT		@chrCompanyName = Coalesce(Value, 'Company Name')
	FROM 	dbo.Site_Parameters  WITH(NOLOCK)
	WHERE 	Parm_Id = 11
---------------------------------------------------------------------------------------------------
SELECT		@chrSiteName = Coalesce(Value, 'Site Name')
	FROM 	dbo.Site_Parameters  WITH(NOLOCK)
	WHERE 	Parm_Id = 12
---------------------------------------------------------------------------------------------------
SELECT		@chrRptOwnerDesc = Coalesce(User_Desc, UserName)
	FROM	dbo.Users_Base WITH(NOLOCK)
	WHERE	User_Id = @RptOwnerId
---------------------------------------------------------------------------------------------------
-- Check Parameter: Reporting period
---------------------------------------------------------------------------------------------------
SET	@dtmStartDateTime	=	Convert(DateTime, @RptStartDateTime)
SET	@dtmEndDateTime	=	Convert(DateTime,	@RptEndDateTime)
--
IF	@dtmStartDateTime > @dtmEndDateTime
BEGIN
	SELECT 3 ErrorCode
	RETURN
END
---------------------------------------------------------------------------------------------------
-- Check Parameter: Production Unit list
---------------------------------------------------------------------------------------------------
SET	@RptPUIdlist = IsNull(@RptPUIdList,'')
IF	Len(@RptPUIdList) = 0	OR	@RptPUIdList = '!Null'
BEGIN
	SELECT 4 ErrorCode
	RETURN
END
---------------------------------------------------------------------------------------------------
Print 'PrepareTables- ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) -- debug
---------------------------------------------------------------------------------------------------
-- PrepareTables: String parsing
---------------------------------------------------------------------------------------------------
INSERT INTO 	#PUList (RcdId, PUId)
EXEC 	spCmn_ReportCollectionParsing
		@PRMCollectionString = @RptPUIdList, 
		@PRMFieldDelimiter = Null, 
		@PRMRecordDelimiter = '|',
		@PRMDataType01 = 'Int'
---------------------------------------------------------------------------------------------------
IF	Len(IsNull(@RptProdIdList, '')) > 0 AND @RptProdIdList <> '!Null'
BEGIN
	INSERT INTO 	#FilterProdList (RcdId, ProdId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptProdIdList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'Int'
	--
	UPDATE	pl
		SET	ProdDesc = Prod_Desc,
				ProdCode = Prod_Code
		FROM	#FilterProdList	pl
		JOIN	Products_Base				p WITH(NOLOCK) 	ON pl.ProdId = p.Prod_Id	
END
---------------------------------------------------------------------------------------------------
IF	@RptShiftDescList <> 'All' AND Len(IsNull(@RptShiftDescList, '')) > 0
BEGIN
	INSERT INTO 	#FilterShiftList (RcdId, ShiftDesc)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptShiftDescList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = ',',
			@PRMDataType01 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
IF @RptCrewDescList <> 'All' AND Len(IsNull(@RptCrewDescList, '')) > 0
BEGIN
	INSERT INTO 	#FilterCrewList (RcdId, CrewDesc)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptCrewDescList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = ',',
			@PRMDataType01 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
IF @RptLineStatusIdList <> 'All' AND Len(IsNull(@RptLineStatusIdList, '')) > 0
BEGIN
	INSERT INTO 	#FilterLineStatusList (RcdId, LineStatusId, LineStatusDesc)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptLineStatusIdList, 
			@PRMFieldDelimiter = '^', 
			@PRMRecordDelimiter = ',',
			@PRMDataType01 = 'Int',
			@PRMDataType02 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
IF @RptSourcePUIdList <> '!Null'	AND Len(IsNull(@RptSourcePUIdList, '')) > 0
BEGIN
	INSERT INTO 	#FilterSourcePUIdList (RcdId, SourcePUId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptSourcePUIdList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'Int'
END
---------------------------------------------------------------------------------------------------
IF @RptEventReasonIdList <> '!Null' AND Len(IsNull(@RptEventReasonIdList, '')) > 0
BEGIN
	INSERT INTO 	#FilterEventReasonIdList (RcdId, ReasonLevelId, EventReasonId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptEventReasonIdList, 
			@PRMFieldDelimiter = '~', 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'Int',
			@PRMDataType02 = 'Int'
END
---------------------------------------------------------------------------------------------------
IF @RptSpliceHistoryColumnVisibility <> 'None'
BEGIN
	INSERT INTO 	#VisibleFieldList (RcdId, FieldName)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptSpliceHistoryColumnVisibility, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'VarChar(50)'
END
---------------------------------------------------------------------------------------------------
-- PrepareTables: get production unit description
---------------------------------------------------------------------------------------------------
UPDATE	pul
	SET	pul.PUDesc 				= 	pu.PU_Desc,
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
	FROM	Prod_Units_Base		pu  WITH(NOLOCK)
	JOIN	#PUList			pul	ON pul.PUId = pu.PU_Id
	JOIN	dbo.Prod_Lines_Base	pl	WITH(NOLOCK) ON pu.PL_Id = pl.PL_Id
---------------------------------------------------------------------------------------------------
-- PrepareTables: update LookUp PUId
---------------------------------------------------------------------------------------------------
UPDATE	pl
	SET	pl.LookUpPUId	= 	Coalesce(pl.AlternativePUId, pl.PUId)
	FROM	#PUList	pl			
---------------------------------------------------------------------------------------------------
Print 'TimeIntervals - ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) -- debug
---------------------------------------------------------------------------------------------------
Print 'Shifts'
---------------------------------------------------------------------------------------------------
-- Time Interval: Get Shifts
---------------------------------------------------------------------------------------------------
SELECT	@intShiftLengthInMin = 	@RptShiftLength * 60
--
SELECT	@intShiftOffsetInMin = 	DatePart(Hour, @RptShiftStart) * 60 + DatePart(Minute, @RptShiftStart)
---------------------------------------------------------------------------------------------------
Print 'ShiftSchedCursor' 
---------------------------------------------------------------------------------------------------
SET	@i = 1
DECLARE	ShiftScheduleCursor INSENSITIVE CURSOR 
FOR (	SELECT		PUId,
					LookUpPUId
			FROM	#PUList )
ORDER BY PUId
FOR READ ONLY
OPEN	ShiftScheduleCursor
FETCH	NEXT FROM ShiftScheduleCursor INTO @c_intPUId, @c_intLookUpPUId
WHILE	@@Fetch_Status = 0
BEGIN
	-----------------------------------------------------------------------------------------------
	-- Time Interval Get Shifts:
	-- If there is a Crew Schedule for some or all production units
	-----------------------------------------------------------------------------------------------
	Print 'PUId = ' + Convert(VarChar(25), @c_intPUId)
	-----------------------------------------------------------------------------------------------
	IF (	SELECT 	Count(Start_Time) 
				FROM	dbo.Crew_Schedule  WITH(NOLOCK)
				--
				WHERE PU_Id = @c_intLookUpPUId
				AND Start_Time 	<= 	@dtmEndDateTime 
				AND End_Time 	> 	@dtmStartDateTime ) > 0
	BEGIN
		----------------------------------------------------------------------
		-- Shifts: with filter and without filter
		----------------------------------------------------------------------
		SET	@chrSQLCommand =	'	SELECT	CS_Id, '
								+						Convert(VarChar, @c_intPUId)	+ ', '
								+		'				Shift_Desc,	Crew_Desc, '
								+		'				Start_Time,	Coalesce(End_Time, GetDate()) '
								+		'		FROM	dbo.Crew_Schedule cs WITH(NOLOCK)'
				------------------------------------------------------
		IF	(	SELECT	Count(*)
					FROM	#FilterShiftList) > 0
		BEGIN
			SET	@chrSQLCommand =	@chrSQLCommand + ' JOIN	#FilterShiftList	sl	ON	sl.ShiftDesc = cs.Shift_Desc ' 
		END
				------------------------------------------------------
		IF	(	SELECT	Count(*)
					FROM	#FilterCrewList) > 0
		BEGIN
			SET	@chrSQLCommand =	@chrSQLCommand + ' JOIN	#FilterCrewList	cl	ON	cl.CrewDesc = cs.Crew_Desc ' 
		END
				------------------------------------------------------
		SET	@chrSQLCommand = @chrSQLCommand	+	'	WHERE	PU_Id = ' + Convert(VarChar, @c_intLookUpPUId) + ' '
															+	'	AND	cs.Start_Time	<=	'''	+	Convert(VarChar, @dtmEndDateTime, 121) + ''''
															+	'	AND	cs.End_Time 	>	''' 	+	Convert(VarChar, @dtmStartDateTime, 121) + ''''
		------------------------------------------------------------
		INSERT INTO	#ShiftList (
						CSId,
						PUId,
						ShiftDesc,	CrewDesc,
						ShiftStart,	ShiftEnd )
		EXEC	(@chrSQLCommand)		
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
		SELECT	@intShiftMaxCount = (24 * 60) / @intShiftLengthInMin
		SELECT	@intShiftDesc		= 1
		--
		IF	@dtmStartDateTime < @dtmShiftDay
		BEGIN
			SELECT	@dtmShiftDay = DateAdd(Minute, -@intShiftLengthInMin, @dtmShiftDay)
			SELECT	@intShiftDesc = @intShiftMaxCount
		END
		--
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
			--
			IF	@intShiftDesc >= @intShiftMaxCount
			BEGIN
				SELECT	@intShiftDesc = 1
			END
			ELSE
			BEGIN
				SELECT	@intShiftDesc = @intShiftDesc + 1
			END
			--
			SET	@i = @i + 1
			SET	@dtmShiftDay = DateAdd(Minute, @intShiftLengthInMin, @dtmShiftDay)
		END
	END
	--
	FETCH	NEXT FROM ShiftScheduleCursor INTO @c_intPUId, @c_intLookUpPUId
--
END
CLOSE			ShiftScheduleCursor
DEALLOCATE 	ShiftScheduleCursor
---------------------------------------------------------------------------------------------------
Print 'Time Intervals: Get Line Status' 
---------------------------------------------------------------------------------------------------
-- Time Intervals: Line Status list with filter
---------------------------------------------------------------------------------------------------
IF		(SELECT 	Count(*)
			FROM	#FilterLineStatusList) > 0
BEGIN
	INSERT INTO	#LineStatusList (
					PUId,
					LineStatusSchedId,
					LineStatusId,
					LineStatusDesc,
					LineStatusStart,
					LineStatusEnd )
		SELECT	pl.PUId,
					ls.Status_Schedule_Id,
					ls.Line_Status_Id,
					fl.LineStatusDesc,
					Case	WHEN	ls.Start_DateTime <	@dtmStartDateTime
							THEN	@dtmStartDateTime
							ELSE	ls.Start_DateTime
							END,
					Case	WHEN	Coalesce(ls.End_DateTime, GetDate()) > @dtmEndDateTime
							THEN	@dtmEndDateTime
							ELSE	ls.End_DateTime
							END
			FROM	dbo.Local_PG_Line_Status 	ls  WITH(NOLOCK)
			JOIN	#PUList							pl	ON	pl.LookUpPUId 		= ls.Unit_Id						
			JOIN	#FilterLineStatusList		fl	ON	ls.Line_Status_Id = fl.LineStatusId	
			WHERE	Start_DateTime <= @dtmEndDateTime
			AND	(End_DateTime 	>	@dtmStartDateTime OR End_DateTime IS NULL)
END
ELSE
---------------------------------------------------------------------------------------------------
-- PrepareTables: Line Status list with no filter
---------------------------------------------------------------------------------------------------
BEGIN
	INSERT INTO	#LineStatusList (
					PUId,
					LineStatusSchedId,
					LineStatusId,
					LineStatusDesc,
					LineStatusStart,
					LineStatusEnd )
		SELECT	pl.PUId,
					ls.Status_Schedule_Id,
					ls.Line_Status_Id,
					p.Phrase_Value,
					Case	WHEN	ls.Start_DateTime <	@dtmStartDateTime
							THEN	@dtmStartDateTime
							ELSE	ls.Start_DateTime
							END,
					Case	WHEN	Coalesce(ls.End_DateTime, GetDate()) > @dtmEndDateTime
							THEN	@dtmEndDateTime
							ELSE	ls.End_DateTime
							END
			FROM	dbo.Local_PG_Line_Status 	ls  WITH(NOLOCK)
			JOIN	dbo.Phrase 						p 	WITH(NOLOCK) ON 	ls.Line_Status_Id = p.Phrase_Id
														/*	AND	p.Data_Type_Id = (	SELECT	Data_Type_Id
																									FROM	Data_Type
																									WHERE	Data_Type_Desc = 'Line Status') */
			JOIN	#PUList							pl	ON		pl.LookUpPUId = ls.Unit_Id						
			WHERE	Start_DateTime <= @dtmEndDateTime
			AND	(End_DateTime 	>	@dtmStartDateTime OR End_DateTime IS NULL)
		GROUP BY	pl.PUId, ls.Status_Schedule_Id, ls.Line_Status_Id, p.Phrase_Value, 
					ls.Start_DateTime, ls.End_DateTime	
END
---------------------------------------------------------------------------------------------------
-- Prepare Tables: update Line Status Duration
---------------------------------------------------------------------------------------------------
UPDATE	#LineStatusList
	SET	DurationInSec = DateDiff(Second, LineStatusStart, LineStatusEnd)
---------------------------------------------------------------------------------------------------
Print 'SpliceDetails - ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) -- debug
---------------------------------------------------------------------------------------------------
-- Splice: Obtain the Splice details for the specified time period and apply filters
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand = ''
SET	@chrSQLCommand1 = ''
SET	@chrSQLCommand2 = ''
--
SET	@chrSQLCommand1 = 	'	INSERT INTO 	#SpliceDetail ( '
	+					'					PLId, '
	+					'					PUId, '
	+					'					ProdId, '
	+					'					WEDId, '
	+					'					SpliceTimeStamp, '
	+					'					OffSetFromMidnightInSec, '
	+					'					LineStatusId, '
	+					'					LineStatusSchedId, '
	+					'					ShiftDesc, '
	+					'					CrewDesc, '
	+					'					SourcePUId, '
	+					'					WasteRL1Id, '
	+					'					EventReasonName1, '
	+					'					SpliceStatus, '
	+					'					SpliceSuccCount, '
	+					'					SpliceFailedCount, '				
	+					'					EventCount ) '
SET	@chrSQLCommand2 =	'		SELECT		pu.PLId, '
	+					'					pu.PUId, '
	+					'					ps.Prod_Id, '
	+					'					wed.WED_Id, '
	+					'					wed.TimeStamp, '
	+					'					(DatePart(hh, wed.TimeStamp) * 60 * 60) + (DatePart(mi, wed.TimeStamp) * 60) + DatePart(ss, wed.TimeStamp), '
	+					'					ls.LineStatusId, '
	+					'					ls.LineStatusSchedId, '
	+					'					sl.ShiftDesc, '
	+					'					sl.CrewDesc, '	
	+					'					wed.Source_PU_Id, '
	+					'					wed.Reason_Level1, '
	+					'					r1.Event_Reason_Name, '
	+					'					wed.Amount, '
	+					'					Case	WHEN	wed.Amount > 0 '
	+					'							THEN	1 '
	+					'							ELSE	0 '
	+					'							END, '
	+					'					Case	WHEN	wed.Amount = 0 '
	+					'							THEN	1 '
	+					'							ELSE	0 '
	+					'							END, '
	+					'					1 '
	+					'			FROM	dbo.Waste_Event_Details wed WITH(NOLOCK)'
	+					'			JOIN	#ShiftList 				sl 	ON 	sl.ShiftStart	<= 	wed.TimeStamp '
	+			 		'												AND	sl.ShiftEnd 	>	wed.TimeStamp '
	+	 				'												AND sl.PUId 		=  	wed.PU_id '
	+					'			JOIN 	dbo.Production_Starts 	ps	WITH(NOLOCK) ON 	ps.Start_Time	<=	wed.TimeStamp '
	+					'												AND (ps.End_Time	>	wed.TimeStamp '
	+					'												OR	ps.End_Time 	IS NULL) '
	+					'												AND ps.PU_Id 		= 	wed.PU_Id '
	+					'			JOIN	#LineStatusList 		ls 	ON 	ls.LineStatusStart 	<= 	wed.TimeStamp '
	+			 		'												AND	(ls.LineStatusEnd 	>	wed.TimeStamp '
	+					'												OR	ls.LineStatusEnd IS NULL) '
	+			 		'												AND ls.PUId				= 	wed.PU_Id '
	+					'			JOIN	dbo.Event_Reasons 		r1 	WITH(NOLOCK) ON 	wed.Reason_Level1 	= 	r1.Event_Reason_Id '
	+					'			JOIN	#PUList					pu 	ON	pu.PUId = wed.PU_Id '
	+					'			WHERE 	wed.TimeStamp	<= ''' + Convert(VarChar, @dtmEndDateTime, 120) + ''' '
	+					'			AND 	wed.TimeStamp	>  ''' + Convert(VarChar, @dtmStartDateTime, 120) + ''''
---------------------------------------------------------------------------------------------------
-- Add Product Filter
---------------------------------------------------------------------------------------------------
IF	(SELECT Count(*) FROM	#FilterProdList) > 0
BEGIN
	SET	@chrSQLCommand2 = 	@chrSQLCommand2 + ' AND	ps.Prod_Id IN (SELECT ProdId FROM #FilterProdList)'
END
---------------------------------------------------------------------------------------------------
-- Add Source PU (Location) Filter
---------------------------------------------------------------------------------------------------
IF	(SELECT Count(*) FROM	#FilterSourcePUIdList) > 0
BEGIN
	SET	@chrSQLCommand2 = 	@chrSQLCommand2 + ' AND wed.Source_PU_Id IN (SELECT SourcePUId FROM #FilterSourcePUIdList)'
END
---------------------------------------------------------------------------------------------------
-- Add Reason level 1 filter Filter
---------------------------------------------------------------------------------------------------
IF	(SELECT Count(*) 	FROM	#FilterEventReasonIdList
							WHERE	ReasonLevelId = 1) > 0
BEGIN
	SET	@chrSQLCommand2 = 	@chrSQLCommand2	+ ' AND wed.Reason_Level1 IN (	SELECT 		EventReasonId '
											+ '									FROM 	#FilterEventReasonIdList '
											+ ' 								WHERE 	ReasonLevelId = 1 )'
END
---------------------------------------------------------------------------------------------------
-- Get Splice details
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand = @chrSQLCommand1 + ' ' + @chrSQLCommand2
EXEC	(@chrSQLCommand)
---------------------------------------------------------------------------------------------------
print @chrSQLCommand
---------------------------------------------------------------------------------------------------
-- UPDATE Production Day
---------------------------------------------------------------------------------------------------
SET	@intShiftOffset = DatePart(hh, @RptShiftStart) * 60 * 60 + DatePart(mi, @RptShiftStart) * 60 + DatePart(ss, @RptShiftStart)  
UPDATE	#SpliceDetail
	SET	ProductionDay = CASE WHEN SpliceTimeStamp > CAST(CONCAT(CAST(SpliceTimeStamp AS DATE), ' ', CAST(@dtmStartDateTime AS TIME(0))) AS DATETIME)
							 THEN CAST(SpliceTimeStamp AS DATE)
							 ELSE DATEADD(DAY, -1, CAST(SpliceTimeStamp AS DATE))
						END
						
------------------------------------------------------------------------------
Print 'Get Comments'
-------------------------------------------------------------------------------
-- Waste: Get the comments
-- Note: There is a new field in the Waste_Event_Details table called Cause_Comment_Id
-- This field will collect the comment id's in Proficy 4.0
-- In the meantime, the comment id's for waste events are collected by a table
-- called Waste_n_Timed_Comments where WCT_Type = 3. 
-------------------------------------------------------------------------------
IF	@fltDBVersion <= 300215.70 
BEGIN
	----------------------------------------------------------------------------
	Print '---------------------'
	Print 'Splice Detail Comment'
	Print '---------------------'
	----------------------------------------------------------------------------
	SET	@intCommentTableFlag = 2
	--
	DECLARE	DetailCommentCursor1 INSENSITIVE CURSOR FOR (
	SELECT	WEDId
		FROM	#SpliceDetail 			rd WITH(INDEX(RD_WEDId_PUId_ProdId_Idx))
		JOIN	Waste_n_Timed_Comments 	wt ON rd.WEDId = wt.WTC_Source_Id
		WHERE	WTC_Type = 3 )
	FOR READ ONLY
	OPEN	DetailCommentCursor1
	FETCH	NEXT FROM DetailCommentCursor1 INTO @c_intWEDId
	WHILE	@@Fetch_Status = 0
	BEGIN
		------------------------------------------------------------------------
		Print 'WEDId: ' + Convert(VarChar, @c_intWEDId)
		------------------------------------------------------------------------
		-- Note: multiple comments can be entered for each waste record. This is
		-- the reason a cursor has been used here to concatenate all the CommentId's
		------------------------------------------------------------------------
		SET	@chrTempString = ''
		DECLARE	DetailCommentCursor2 INSENSITIVE CURSOR FOR (
		SELECT	WTC_Id
			FROM	Waste_n_Timed_Comments wt 
			WHERE	WTC_Type = 3
			AND	WTC_Source_Id = @c_intWEDId )
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
		CLOSE		DetailCommentCursor2
		DEALLOCATE 	DetailCommentCursor2
	--
	UPDATE		rd
		SET		CauseCommentId = Substring(LTrim(RTrim(@chrTempString)), 2, Len(@chrTempString))
		FROM	#SpliceDetail	rd	WITH(INDEX(RD_WEDId_PUId_ProdId_Idx))
		WHERE	WEDId = @c_intWEDId
	--
	FETCH	NEXT FROM DetailCommentCursor1 INTO @c_intWEDId
	------------------------------------------------------------------------
	Print 'WTCIdList: ' + @chrTempString
	------------------------------------------------------------------------
	END
	CLOSE		DetailCommentCursor1
	DEALLOCATE 	DetailCommentCursor1
	------------------------------------------------------------------------
	Print '--------------'
	------------------------------------------------------------------------
END
ELSE
BEGIN
	------------------------------------------------------------------------
	--	Proficy 4.0
	------------------------------------------------------------------------
	SET	@intCommentTableFlag = 1
	--
	UPDATE		rd
		SET		CauseCommentId = Cause_Comment_Id
		FROM	dbo.Waste_Event_Details ted WITH(NOLOCK)
		JOIN	#SpliceDetail rd 	WITH(INDEX(RD_WEDId_PUId_ProdId_Idx))
									ON rd.WEDId = ted.WED_Id
END
-------------------------------------------------------------------------------
Print 'RS1: Misc Info ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
-------------------------------------------------------------------------------
-- RS1: Misc Info
-------------------------------------------------------------------------------
INSERT INTO	#MiscInfo (
			CompanyName,
			SiteName,
			RptOwnerDesc,
			RptStartDateTime,	
			RptEndDateTime,
			FilterShift,
			FilterCrew,
			FilterLineStatus,
			FilterProduct,
			FilterLocation,
			FilterReason1,
			RptTitle,
			MajorGroupBy,
			MinorGroupBy,
			CommentColWidth,
			CommentTableFlag )
	SELECT	@chrCompanyName,
			@chrSiteName,
			@chrRptOwnerDesc,
			Convert(VarChar(50), @dtmStartDateTime, 120),
			Convert(VarChar(50), @dtmEndDateTime, 120),
			@RptShiftDescList,
			@RptCrewDescList,
			@RptLineStatusDescList,
			@RptProdIdList,
			@RptSourcePUIdList,
			@RptEventReasonIdList,
			@RptTitle,
			@RptSpliceHistoryMajorGroupBy,
			@RptSpliceHistoryMinorGroupBy,
			@RptSpliceHistoryCommentColWidth,
			@intCommentTableFlag
-- 
SELECT * FROM	#MiscInfo
---------------------------------------------------------------------------------------------------
Print 'RS2: Major Group List ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
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
			JOIN	dbo.Prod_Units_Base	pu WITH(NOLOCK) ON pu.PU_Id = pl.PUId )
		ORDER BY PUDesc
FOR READ ONLY
OPEN	PUDescCursor
FETCH	NEXT FROM PUDescCursor INTO @c_chrPUDesc
WHILE	@@Fetch_Status = 0
BEGIN
	SET	@chrPUDescList = @chrPUDescList + ', ' + @c_chrPUDesc
	FETCH NEXT FROM PUDescCursor INTO @c_chrPUDesc
END
CLOSE		PUDescCursor
DEALLOCATE 	PUDescCursor
--
SET	@chrPUDescList = LTrim(RTrim(Substring(@chrPUDescList, 2, Len(@chrPUDescList))))
---------------------------------------------------------------------------------------------------
IF	@RptSpliceHistoryMajorGroupBy = 'PUId|ProdId'
BEGIN
	SELECT		rd.PUId, 
				pu.PU_Desc 	PUDesc, 
				rd.ProdId, 
				p.Prod_Code ProdCode
		FROM	#SpliceDetail 	rd
		JOIN	dbo.Prod_Units_Base	pu WITH(NOLOCK)	ON rd.PUId 		= pu.PU_Id
		JOIN	dbo.Products_Base 	p  WITH(NOLOCK)	ON p.Prod_Id 	= rd.ProdId
	GROUP BY	rd.PUId, pu.PU_Desc, rd.ProdId, p.Prod_Code
	ORDER BY	pu.PU_Desc
END
---------------------------------------------------------------------------------------------------
IF	@RptSpliceHistoryMajorGroupBy = 'PUId'
BEGIN
	SELECT		rd.PUId, 
				pu.PU_Desc 			PUDesc, 
				@chrProdDescList	ProdCode
		FROM	#SpliceDetail 	rd
		JOIN	dbo.Prod_Units_Base pu WITH(NOLOCK) ON rd.PUId = pu.PU_Id
	GROUP BY	rd.PUId, pu.PU_Desc
	ORDER	BY	pu.PU_Desc
END	
---------------------------------------------------------------------------------------------------
IF	@RptSpliceHistoryMajorGroupBy = '!Null'	
OR	Len(@RptSpliceHistoryMajorGroupBy) = 0
BEGIN
	SELECT	0					PUId, 
			@chrPUDescList 		PUDesc, 
			@chrProdDescList	ProdCode
END
---------------------------------------------------------------------------------------------------
IF	@RptSpliceHistoryMajorGroupBy = 'ProdId'
BEGIN
	SELECT		0				PUId, 
				@chrPUDescList 	PUDesc,
				rd.ProdId, 
				p.Prod_Code 	ProdCode
		FROM	#SpliceDetail 	rd
		JOIN	dbo.Products_Base p WITH(NOLOCK) ON p.Prod_Id = rd.ProdId
	GROUP BY	rd.ProdId, p.Prod_Code
	ORDER BY	p.Prod_Code
END
---------------------------------------------------------------------------------------------------
Print 'RS3: Hdr Info ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
---------------------------------------------------------------------------------------------------
-- RS3: Header info
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand 	= ''
SET	@chrSQLCommand1 = ''
SET	@chrSQLCommand2 = ''

IF	@RptSpliceHistoryMajorGroupBy = '!Null'
BEGIN
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 = 	'	INSERT INTO		#HdrInfo (' 
					+		'		PUId, '
					+		'		SplicesAttempted, '
					+		'		SplicesSuccessful, '
					+		'		SplicesFailed ) '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand2 =	'SELECT 	0, '
					+		'				Sum(rd.EventCount), '
					+		'				Sum(rd.spliceSuccCount), '
					+		'				Sum(rd.spliceFailedCount) '
					+		'		FROM	#SpliceDetail 		rd'
	-----------------------------------------------------------------------------------------------
END
ELSE IF	@RptSpliceHistoryMajorGroupBy = 'ProdId'
BEGIN
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 = 	'	INSERT INTO		#HdrInfo (' 
					+		'		PUId, '
					+				Replace(@RptSpliceHistoryMajorGroupBy, '|', ',') + ', '
					+		'		SplicesAttempted, '
					+		'		SplicesSuccessful, '
					+		'		SplicesFailed ) '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand2 =	'SELECT 	0, ' 
					+ 						Replace(@RptSpliceHistoryMajorGroupBy, '|', ',') + ', '
					+		'				Sum(rd.EventCount), '
					+		'				Sum(rd.spliceSuccCount), '
					+		'				Sum(rd.spliceFailedCount) '
					+		'		FROM	#SpliceDetail 		rd'
					+		'		GROUP BY	' + Replace(@RptSpliceHistoryMajorGroupBy, '|', ',')
	-----------------------------------------------------------------------------------------------
END
ELSE
BEGIN
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 = 	'	INSERT INTO		#HdrInfo (' 
					+				Replace(@RptSpliceHistoryMajorGroupBy, '|', ',') + ', '
					+		'		SplicesAttempted, '
					+		'		SplicesSuccessful, '
					+		'		SplicesFailed ) '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand2 =	'SELECT ' + Replace(@RptSpliceHistoryMajorGroupBy, '|', ',') + ', '
					+		'				Sum(rd.EventCount), '
					+		'				Sum(rd.spliceSuccCount), '
					+		'				Sum(rd.spliceFailedCount) '
					+		'		FROM	#SpliceDetail 		rd'
					+		'		GROUP BY	' + Replace(@RptSpliceHistoryMajorGroupBy, '|', ',')
	-----------------------------------------------------------------------------------------------
END
---------------------------------------------------------------------------------------------------
SET		@chrSQLCommand = @chrSQLCommand1 + ' ' + @chrSQLCommand2
EXEC	(@chrSQLCommand)
---------------------------------------------------------------------------------------------------
-- RS3: HdrInfo calculations
---------------------------------------------------------------------------------------------------
UPDATE	#HdrInfo
 	SET	SpliceEfficiency	= 	Case	WHEN	SplicesAttempted > 0
										THEN	Convert(Float, SplicesSuccessful) / Convert(Float, SplicesAttempted)
								END
---------------------------------------------------------------------------------------------------
-- RS3: HdrInfo return result set
---------------------------------------------------------------------------------------------------
SELECT	* 	FROM #HdrInfo
---------------------------------------------------------------------------------------------------
Print 'RS4: Final Result Set ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = None
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand1 = ''
SET	@chrSQLCommand2 = ''
SET	@chrSQLCommand3	= ''
SET	@chrSQLCommand4	= ''
SET	@chrSQLCommand 	= ''
---------------------------------------------------------------------------------------------------
IF	(@RptSpliceHistoryMajorGroupBy = '!Null')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT 0, Null'	
	SET	@chrSQLCommand3 = 'GROUP BY '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = PUId
---------------------------------------------------------------------------------------------------
IF	(@RptSpliceHistoryMajorGroupBy = 'PUId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT rd.PUId, Null'	
	SET	@chrSQLCommand3 = 'GROUP BY rd.PUId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = ProdId
---------------------------------------------------------------------------------------------------
IF	(@RptSpliceHistoryMajorGroupBy = 'ProdId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT 0, rd.ProdId'	
	SET	@chrSQLCommand3 = 'GROUP BY rd.ProdId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = PUId|ProdId
---------------------------------------------------------------------------------------------------
IF	(@RptSpliceHistoryMajorGroupBy = 'PUId|ProdId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT rd.PUId, rd.ProdId'	
	SET	@chrSQLCommand3 = 'GROUP BY rd.PUId, rd.ProdId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - minor group is !Null or Null
---------------------------------------------------------------------------------------------------
IF	(@RptSpliceHistoryMinorGroupBy = '!Null' 
OR	(Len(IsNull(@RptSpliceHistoryMinorGroupBy, ''))) = 0)
BEGIN
	SET	@chrSQLCommand1 = 	@chrSQLCommand1	+ 	', Convert(VarChar, rd.SpliceTimeStamp, 121), '
											+	'	rd.EventCount, '
											+	'  	rd.SpliceSuccCount, '
											+	'	rd.SpliceFailedCount, '
											+	'	rd.SpliceStatus, '
											+	'	rd.CauseCommentId, '
											+	'	pul.PLDesc, '
											+ 	'	pul.PUDesc, '
											+ 	'	p.Prod_Code, '
											+	'	rd.ShiftDesc, '
											+	'	rd.CrewDesc, '
											+	'	sl.LineStatusDesc, '
											+  	'  	pu.PU_Desc, ' 
											+	'	rd.EventReasonName1, '
											+  	'  	Substring(Convert(VarChar, rd.ProductionDay, 120), 1, 10) '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand2 = 	'	FROM			#SpliceDetail 	rd 		WITH(INDEX(RD_WEDId_PUId_ProdId_Idx)) '
					+		'	JOIN			dbo.Prod_Units_Base 	pu	WITH(NOLOCK)	ON 	pu.PU_Id = rd.SourcePUId '
					+		'	JOIN			#PUList 		pul 	ON 	pul.PUId = rd.PUId '
					+		'	Left 	JOIN	#LineStatusList	sl		ON 	sl.LineStatusSchedId = rd.LineStatusSchedId '
					+		'											AND	sl.PUId = rd.PUId '
					+		'	Left	JOIN	dbo.Products_Base		p	WITH(NOLOCK)    ON	rd.ProdId = p.Prod_Id '
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand3 = ''
END
ELSE
BEGIN
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - eliminate Splice time stamp
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - common sums
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand1 =	@chrSQLCommand1 	+ 	',	Sum(rd.EventCount), '
												+	'	Sum(rd.SpliceSuccCount), '
												+	'  	Sum(rd.SpliceFailedCount), '
												+	'  	Null, '
												+	'	Null '
	--
	SET	@chrSQLCommand2 = '	FROM			#SpliceDetail rd '
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes Production Line
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy LIKE '%PLId%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pul.PLDesc '
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ 'JOIN	#PUList pul ON pul.PUId = rd.PUId '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', pul.PLDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes Production Unit
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy LIKE '%PUId%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pul.PUDesc '
		--
		IF	(@RptSpliceHistoryMinorGroupBy NOT LIKE '%PLId%')
		BEGIN
			SET	@chrSQLCommand2 = @chrSQLCommand2	+ 'JOIN	#PUList pul ON pul.PUId = rd.PUId '
		END
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', pul.PUDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ShiftDesc
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%ProdCode%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', p.Prod_Code'
		--
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ 'Left	JOIN	dbo.Products_Base p	WITH(NOLOCK) ON	rd.ProdId = p.Prod_Id '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', p.Prod_Code '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ShiftDesc
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%ShiftDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.ShiftDesc'
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', rd.ShiftDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes CrewDesc
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%CrewDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.CrewDesc'
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', rd.CrewDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProdStatus
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%ProdStatus%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', sl.LineStatusDesc'
		SET	@chrSQLCommand2 = @chrSQLCommand2 
								+		'	Left 	JOIN	#LineStatusList	sl	ON 	sl.LineStatusId = rd.LineStatusId '
								+		'										AND	sl.PUId = rd.PUId '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', sl.LineStatusDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes SourcePUId
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%SourcePUDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pu.PU_Desc'
		SET	@chrSQLCommand2 = @chrSQLCommand2
								+		'	JOIN			dbo.Prod_Units_Base 	pu	WITH(NOLOCK) ON pu.PU_Id = rd.SourcePUId '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', pu.PU_Desc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes EventReasonName1
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%EventReasonName1%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.EventReasonName1'
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', rd.EventReasonName1 '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-----------------------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProductionDay
	-----------------------------------------------------------------------------------------------
	IF	(@RptSpliceHistoryMinorGroupBy Like '%ProductionDay%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Substring(Convert(VarChar, rd.ProductionDay, 120), 1, 10)' -- + ', rd.ProductionDay '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', rd.ProductionDay '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
END
---------------------------------------------------------------------------------------------------
IF (@RptSpliceHistoryMajorGroupBy = '!Null')
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

INSERT INTO	#FinalResultSet (
			PUId,
			ProdId,
			SpliceTimeStamp,
			TotalSplices,
			SucSplices,
			FailedSplices,
			Status,
			CommentId,
			PLDesc,
			PUDesc,
			ProdCode,
			ShiftDesc,
			CrewDesc,
			ProdStatus,
			SourcePUDesc,
			EventReasonName1,
			ProductionDay )

EXEC	(@chrSQLCommand)
---------------------------------------------------------------------------------------------------
Print 'FinalResultSet - ' + @chrSQLCommand
---------------------------------------------------------------------------------------------------
-- RS4: Minor Grouping calculations 
---------------------------------------------------------------------------------------------------
IF	@RptSpliceHistoryMajorGroupBy = 'PUId' 
OR 	@RptSpliceHistoryMajorGroupBy = '!Null'
BEGIN
	UPDATE		fr
		SET		fr.TotalEventCount = hi.SplicesAttempted
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo	hi ON hi.PUId = fr.PUId
END
ELSE
BEGIN
	UPDATE		fr
		SET		fr.TotalEventCount	= hi.SplicesAttempted
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo		hi 	ON 	hi.PUId 	= fr.PUId
									AND	hi.ProdId 	= fr.ProdId
END
---------------------------------------------------------------------------------------------------
UPDATE	#FinalResultSet 
SET	SuccessRate 		= 	Case	WHEN	TotalSplices > 0
									THEN	LTrim(RTrim(Str(Convert(Float, SucSplices) / Convert(Float, TotalSplices), 25, 8)))
							END,
	PercentOfEvent 		= 	Case	WHEN	TotalEventCount > 0
									THEN	LTrim(RTrim(Str(Convert(Float, TotalSplices) / Convert(Float, TotalEventCount), 25, 8))) 
							END,
	SpliceEfficiency	= 	Case	WHEN	TotalSplices > 0
									THEN	LTrim(RTrim(Str(Convert(Float, SucSplices) / Convert(Float, TotalSplices), 25, 8)))
							END
							
--------------------------------------------------------------------------------------------------------------------
-- Keep just the first commentId in case exists more than one
--------------------------------------------------------------------------------------------------------------------
UPDATE #FinalResultSet
SET CommentId = SUBSTRING(CommentId, 0, CHARINDEX('|',CommentId,0))
WHERE CommentId IS NOT NULL AND ISNUMERIC(CommentId) = 0
							
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
JOIN   #FinalResultSet fr ON fr.CommentId  = c.Comment_Id 
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
					@CommentId = CommentId
             FROM #FinalResultSet
             WHERE RcId = @i

			 SET @j=1
             WHILE @NextCommentId IS NOT NULL AND @j <= 10
             BEGIN

                    -- Subtract the comments length by 2 to deal with PPA comments issue
					UPDATE #FinalResultSet--ct
							SET		Comments =	CASE  WHEN   CommentId > 0 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
															THEN   CONVERT(NVARCHAR(MAX),Comments) + '|**|' + LEFT(CONVERT(NVARCHAR(MAX),c.Comment),3994) + '...'
															WHEN   CommentId > 0 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 <= 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
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
IF (@RptSpliceHistoryColumnVisibility = '!Null' 
OR Len(IsNull(@RptSpliceHistoryColumnVisibility, '')) = 0)
BEGIN
	SELECT		PUId,
				ProdId,
				Border1,
				PLDesc,
				PUDesc,
				SpliceTimeStamp,
				ProductionDay,
				ProdCode,
				ShiftDesc,
				CrewDesc,
				ProdStatus,
				SourcePUDesc,
				EventReasonName1,
				Status,
				TotalSplices,	
				SucSplices,
				FailedSplices,
				SuccessRate,
				PercentOfEvent,
				SpliceEfficiency,
				Comments,
				Border2
		FROM	#FinalResultSet
	ORDER BY	PUId, ProdId, SpliceTimeStamp
END
ELSE
BEGIN
	SET	@chrSQLCommand4 = ''
	SET	@i = 1
	WHILE	@i <= 4
	BEGIN
		IF	(SELECT Count(RcdId) FROM	#VisibleFieldList WHERE RcdId = @i) > 0
		BEGIN
			IF	@i = 1
			BEGIN
				SELECT		@chrSQLCommand4 = FieldName + ' ' + @RptSortType + ' '
					FROM	#VisibleFieldList 
					WHERE	RcdId = @i
			END
			ELSE
			BEGIN
				SELECT		@chrSQLCommand4 = @chrSQLCommand4 + ', ' + FieldName + ' ' + @RptSortType + ' '
					FROM	#VisibleFieldList 
					WHERE	RcdId = @i
			END
		END
		ELSE
		BEGIN
			BREAK
		END
		SET	@i = @i + 1
	END
	-----------------------------------------------------------------------------------------------
	SET	@chrSQLCommand = ''
	SET	@chrSQLCommand = '	SELECT 	PUId, '
					+		'						ProdId, '
					+		'						Border1, '
					+								Replace(@RptSpliceHistoryColumnVisibility, '|', ',') + ', ' 
					+		'						Border2 '
					+		'				FROM	#FinalResultSet	'
					+		'			ORDER BY	' + @chrSQLCommand4	
	EXEC (@chrSQLCommand)
END
---------------------------------------------------------------------------------------------------
-- Select from tables -- used for debugging only comment before installation
---------------------------------------------------------------------------------------------------
-- SELECT 'MiscInfo', 				* FROM #MiscInfo
-- SELECT 'HdrInfo',				* FROM #HdrInfo
-- SELECT 'PUList', 				* FROM #PUList
-- SELECT 'FilterLineStatusList',	* FROM #FilterLineStatusList
-- SELECT 'FilterProdList',			* FROM #FilterProdList
-- SELECT 'FilterShiftList',		* FROM #FilterShiftList
-- SELECT 'FilterCrewList',			* FROM #FilterCrewList
-- SELECT 'FilterSourcePUIdList', 	* FROM #FilterSourcePUIdList
-- SELECT 'FilterEventReasonIdList',* FROM #FilterEventReasonIdList
-- SELECT 'LineStatusList', 		* FROM #LineStatusList
-- SELECT 'ShiftList',				* FROM #ShiftList
-- SELECT 'VisibleFieldList',		* FROM #VisibleFieldList
-- SELECT 'SpliceDetail',			* FROM #SpliceDetail ORDER BY PUId, SpliceTimeStamp
-- SELECT 'FinalResultSet',			* FROM #FinalResultSet
---------------------------------------------------------------------------------------------------
-- Drop tables
---------------------------------------------------------------------------------------------------
DROP	TABLE	#MiscInfo
DROP 	TABLE	#HdrInfo
DROP	TABLE	#PUList
DROP	TABLE	#FilterLineStatusList
DROP 	TABLE	#FilterProdList
DROP	TABLE	#FilterShiftList
DROP 	TABLE	#FilterCrewList
DROP 	TABLE	#LineStatusList
DROP	TABLE	#ShiftList
DROP	TABLE	#VisibleFieldList
DROP	TABLE	#SpliceDetail
DROP	TABLE	#FinalResultSet

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[spLocal_RptSpliceReject]  TO [OPDBManager]
GO