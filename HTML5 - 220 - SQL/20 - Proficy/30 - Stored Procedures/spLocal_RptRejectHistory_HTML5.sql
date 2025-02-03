------------------------------------------------------------------------------------------------------------------------
---- Prototype definition
------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptRejectHistory_HTML5',
		@Inputs		= 11, -- Put the number of inputs here for support purposes
		@Version	= '1.1'  -- Number should match version manager, no exceptions.

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

-----------------------------------------------------------------------------------------------------------------------
-- Update client_sp_Prototype table
--------------------------------------------------------------------------------------------------------------------
IF NOT EXISTS (SELECT * FROM Client_SP_Prototypes WHERE sp_name = 'spLocal_RptRejectHistory_HTML5')
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
	SELECT 					1,
						1,
						0,
						1,
						1,
						3,
						244,
						'spLocal_RptRejectHistory_HTML5', 
						'spLocal_RptRejectHistory_HTML5'
END

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[spLocal_RptRejectHistory_HTML5]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
drop procedure [dbo].[spLocal_RptRejectHistory_HTML5]
GO

--
-- Revision			Date			Who						What
-- ========			=====			=====					=====
-- 1.0				2019-07-12		Facundo Sosa			Inicial Release Original SP spLocal_RptRejectHistory v 2.1
-- 1.1				2019-08-15		Gustavo Conde			Fix for ussing the first value from #FinalResultSet.CommentId

-----------------------------------------------------------------------------------------------------
CREATE PROCEDURE  dbo.spLocal_RptRejectHistory_HTML5
--DECLARE
	@RptPUIdList						NVARCHAR(MAX)	= NULL			,  
	@RptSourcePUIdList					NVARCHAR(MAX)	= '!Null'		,  
    @RptProdIdList						NVARCHAR(MAX)	= '!Null'		,
	@RptEventReasonIdList				NVARCHAR(MAX)	= '!Null'		,
	@RptShiftDescList					NVARCHAR(50)	= 'All'			,
	@RptCrewDescList					NVARCHAR(50)	= 'All'			,
	@RptLineStatusIdList				NVARCHAR(250)	= 'All'			,
	@RptRejectHistoryMajorGroupBy		NVARCHAR(50)	= 'PUId'		,			
	@RptRejectHistoryMinorGroupBy		NVARCHAR(500)	= 'None'		,
    @RptStartDateTime					DATETIME		= NULL			,  
    @RptEndDateTime						DATETIME		= NULL				
--WITH ENCRYPTION
AS	

SET NOCOUNT ON

-- TESTING
--SELECT 
--	 @RptPUIdList					= '497|564'
--	,@RptProdIdList					= '!Null'							
--	,@RptSourcePUIdList				= '!Null'
--	,@RptShiftDescList				= 'All'
--	,@RptCrewDescList				= 'All'
--	,@RptLineStatusIdList			= 'All'
--	,@RptRejectHistoryMajorGroupBy	= 'PUId'
--	,@RptRejectHistoryMinorGroupBy	= '!Null'
--	,@RptEventReasonIdList			= '!Null'
--	,@RptStartDateTime				= '2019-07-14 06:00:00.000'
--	,@RptEndDateTime				= '2019-07-15 06:00:00.000'

--=================================================================================================
DECLARE	@dtmTempDate	DateTime,
		@intSecNumber	Int
SET		@dtmTempDate = GetDate()
---------------------------------------------------------------------------------------------------
SET	@intSecNumber	=	1

DECLARE	
	@RptShiftLength						Int				,
	@RptStartDate						VarChar(25) 	,			
	@RptEndDate							VarChar(25) 	,			
	@RptLineStatusDescList				VarChar(4000)	,		-- Note: Line status is a data_type. Line status names can be found in Phrases table
	@RptTitle							VarChar(255)	= 'Reject History Report',
	@RptSortType						VarChar(5)		,
	@RptShiftStart						DateTime		,
	@RptProdVarTestName					VarChar(50)		,
	@RptName							NVARCHAR(50)	= 'Reject History Report'	
---------------------------------------------------------------------------------------------------
-- Other variables
-- Note: @c_.... are cursor variables
---------------------------------------------------------------------------------------------------
DECLARE
 	@chrTempDate		VarChar(50),
 	@chrTempString		VarChar(1000),
 	@chrCompanyName		VarChar(50),
 	@chrSiteName		VarChar(50),
 	-- @chrRptOwnerDesc	VarChar(50),
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
	@intPadCount			Int,
	@intShiftOffset			Int,
	@intId					INT,
	@NextCommentId			INT, 
	@CommentId				INT
---------------------------------------------------------------------------------------------------
DECLARE
	@c_intPUId				Int,
	@c_intWEDId				Int,
	@c_intCSId				Int,
	@c_intLineStatusSchedId	Int,
	@c_intLineStatusId		Int,
	@c_intWTCId				Int,
	@c_intLookUpPUId		Int,
	@c_intProductionVarId	Int,
	@c_intLSRcdId			Int
---------------------------------------------------------------------------------------------------
DECLARE
	@fltDBVersion		Float,
	@fltProductionTime	Float
---------------------------------------------------------------------------------------------------
DECLARE
 	@dtmStartDateTime 	DateTime,
 	@dtmEndDateTime 	DateTime,
 	@dtmDummyDate		DateTime,
 	@dtmBaseDate		DateTime,
 	@dtmShiftDay		DateTime
---------------------------------------------------------------------------------------------------
DECLARE
 	@c_dtmShiftStart		DateTime,
 	@c_dtmShiftEnd			DateTime,
	@c_dtmLineStatusStart	DateTime,
	@c_dtmLineStatusEnd		DateTime

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
	FilterShift			VarChar(50),
	FilterCrew			VarChar(50),
	FilterLineStatus	VarChar(4000),
	FilterProduct		VarChar(MAX),
	FilterLocation		VarChar(MAX),
	FilterReason1		VarChar(MAX),
	RptTitle			VarChar(255),
	MajorGroupBy		VarChar(25),
	MinorGroupBy		VarChar(1000),
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
	TotalRejectCount	Int,
	TotalPercentScrap	Float,
	TotalEventCount		Int,
	TotalPadCount		Int )
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#PUList', 'U') IS NOT NULL  DROP TABLE #PUList
CREATE TABLE	#PUList (
	RcdId			Int,
	PLId			Int,
	PLDesc			VarChar(100),
	PUId			Int,
	PUDesc			VarChar(50),
	AlternativePUId	Int,			-- This PUId will be used if no schedule or line status has been configured for
									-- the selected PUId
	LookUpPUId		Int,	 		-- Coalesce between PUId and AlternativePUId
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
	LSRcdId					Int Identity (1, 1),
	PUId					Int,
	ProdId					Int,
	LineStatusSchedId		Int,
	LineStatusId			Int,
	LineStatusDesc			VarChar(50),
	LineStatusStart			DateTime,
	LineStatusEnd			DateTime,
	DurationInSec			Int,
	PadCount				Int,
	OverlapFlagProdStarts	Int,
	OverlapSequence 		Int,
	OverlapRcdFlag 			Int,
	SplitFlagProdStarts 	Int )
--
-- A #ProductList temp table should be created 
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
IF OBJECT_ID('tempdb.dbo.#RejectDetail', 'U') IS NOT NULL  DROP TABLE #RejectDetail
CREATE TABlE	#RejectDetail (
	PLId					Int,
	PUId					Int,
	ProdId					Int,
	WEDId					Int,
	RejectTimeStamp			DateTime,
	OffSetFromMidnightInSec	Int,
	LineStatusId			Int,
	LSRcdId					Int,
	ProdStatus				VarChar(50),
	ProductionDay			VarChar(25),
	ShiftDesc				VarChar(25),
	CrewDesc				VarChar(25),
	SourcePUId				Int,		
	SourcePUDesc			VarChar(50),
	WasteRL1Id				Int,
	EventReasonName1		VarChar(100),
	RejectCount				Int,
	EventCount				Int,
	CauseCommentId			VarChar(1000) )

CREATE NONCLUSTERED INDEX RD_PUId_TimeStamp_Idx	ON #RejectDetail (PUId, RejectTimestamp) --
CREATE NONCLUSTERED INDEX RD_WEDId_Idx ON #RejectDetail (WEDId)							 -- (WEDId, PUId, ProdId)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FinalResultSet', 'U') IS NOT NULL  DROP TABLE #FinalResultSet
CREATE TABLE	#FinalResultSet (
	RcId				INT IDENTITY,
	PUId				Int,
	ProdId				Int,
	Border1				VarChar(1),
	PLDesc				VarChar(100),
	PUDesc				VarChar(100),
	RejectTimeStamp		VarChar(25),	-- from #RejectDetail	
	ProductionDay		VarChar(25),
	ProdCode			VarChar(50), 	-- from dbo.Products
	ShiftDesc			VarChar(50),	-- from dbo.Crew_Schedule
	CrewDesc			VarChar(50),	-- from dbo.Crew_Schedule
	ProdStatus			VarChar(50),	-- from dbo.Local_PG_LineStatus
	SourcePUDesc		VarChar(100),	-- from dbo.Prod_Units
	EventReasonName1	VarChar(100), 	-- from dbo.Event_Reasons
	RejectCount			Int,			-- from #RejectDetail
	EventCount			Int,			-- from #RejectDetail
	PercentOfScrap		FLOAT,
	PercentScrap		FLOAT,
	PercentOfEvents		FLOAT,
	RejectsPerDay		FLOAT,
	EventsPerDay		FLOAT,
	CommentId			VarChar(1000),
	Comments			NVARCHAR(MAX),
	NextComment_Id		VarChar(1000),
	Border2				Int,
	TotalProduction		Int,
	TotalRejectCount	Int,
	TotalEventCount		Int )

CREATE TABLE #tblProduction (
		PUId 					Int,
		ProdId					Int,
		MGPadCount				Int,
		MGProductionTimeInSec	Int )
--=================================================================================================
-- Print '	.	Initialize Temp Tables ' 
-- Done to minimize recompiles
--=================================================================================================
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
SET @i = (SELECT	Count(*) FROM 	#RejectDetail)
SET @i = (SELECT	Count(*) FROM	#FinalResultSet)
SET @i = (SELECT  	Count(*) FROM  	#tblProduction )

--================================================================================================= 
-- GET GLOBAL PARAMETERS  
--=================================================================================================
SELECT @RptShiftStart 			=  ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName, 'Local_PG_StartShift'),'6:30:00')		
SELECT @RptShiftLength 					= ISNULL( [OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_ShiftLength' ), 8)		
SELECT @RptProdVarTestName 			= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@RptName,'Local_PG_strRptProdVarTestName'),'ProductionCNT')	
---------------------------------------------------------------------------------------------------
-- Update Variables Major Group & Minor Group
---------------------------------------------------------------------------------------------------
SELECT @RptRejectHistoryMajorGroupBy = CASE 
											WHEN @RptRejectHistoryMajorGroupBy IS NULL	THEN '!Null' 
											WHEN @RptRejectHistoryMajorGroupBy = 'None' OR @RptRejectHistoryMajorGroupBy = ''	THEN '!Null'
											ELSE @RptRejectHistoryMajorGroupBy
									   END

SELECT @RptRejectHistoryMinorGroupBy = CASE 
											WHEN @RptRejectHistoryMinorGroupBy IS NULL	THEN '!Null' 
											WHEN @RptRejectHistoryMinorGroupBy = 'None' OR @RptRejectHistoryMinorGroupBy = ''	THEN '!Null'
											ELSE  @RptRejectHistoryMinorGroupBy
									   END


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
-- Print '	.	DBVersion: ' + RTrim(LTrim(Str(@fltDBVersion, 10, 2))) -- debug
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
-- SELECT		@chrRptOwnerDesc = Coalesce(User_Desc, UserName)
-- 	FROM	dbo.Users WITH(NOLOCK)
-- 	WHERE	User_Id = @RptOwnerId
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Reporting Period'
---------------------------------------------------------------------------------------------------
-- Check Parameter: Reporting period
---------------------------------------------------------------------------------------------------
SET	@dtmStartDateTime	=	Convert(DateTime, @RptStartDateTime)
SET	@dtmEndDateTime		=	Convert(DateTime,	@RptEndDateTime)
--
IF	@dtmStartDateTime > @dtmEndDateTime
BEGIN
	SELECT 3 ErrorCode
	-- RETURN 3
END
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Production Unit List'
---------------------------------------------------------------------------------------------------
-- Check Parameter: Production Unit list
---------------------------------------------------------------------------------------------------
SET	@RptPUIdlist = IsNull(@RptPUIdList,'')
IF	Len(@RptPUIdList) = 0	OR	@RptPUIdList = '!Null'
BEGIN
	SELECT 4 ErrorCode
	-- RETURN 4
END
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
IF	Len(IsNull(@RptProdIdList, '')) > 0 AND @RptProdIdList <> '!Null'
BEGIN
	INSERT INTO 	#FilterProdList (RcdId, ProdId)
	EXEC 	spCmn_ReportCollectionParsing
			@PRMCollectionString = @RptProdIdList, 
			@PRMFieldDelimiter = Null, 
			@PRMRecordDelimiter = '|',
			@PRMDataType01 = 'Int'
	-----------------------------------------------------------------------------------------------
	UPDATE	pl
		SET	ProdDesc = Prod_Desc,
				ProdCode = Prod_Code
		FROM	#FilterProdList	pl
		JOIN	dbo.Products				p  WITH(NOLOCK)	ON pl.ProdId = p.Prod_Id	
END
---------------------------------------------------------------------------------------------------
-- PRINT	'	.	Filter Shifts'	
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
-- PRINT	'	.	Filter Crews'	
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
-- PRINT	'	.	Filter Line Status'	
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
-- PRINT	'	.	Filter Location'	
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
-- PRINT	'	.	Filter Reasons'	
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
-- PRINT	'	.	Column Visibility'	
---------------------------------------------------------------------------------------------------
-- IF @RptRejectHistoryColumnVisibility <> 'None'
-- BEGIN
-- 	INSERT INTO 	#VisibleFieldList (RcdId, FieldName)
-- 	EXEC 	spCmn_ReportCollectionParsing
-- 			@PRMCollectionString = @RptRejectHistoryColumnVisibility, 
-- 			@PRMFieldDelimiter = Null, 
-- 			@PRMRecordDelimiter = '|',
-- 			@PRMDataType01 = 'VarChar(50)'
-- END
---------------------------------------------------------------------------------------------------
-- PrepareTables: get production unit description
---------------------------------------------------------------------------------------------------
UPDATE		pul
	SET		pul.PUDesc 				= 	pu.PU_Desc,
			pul.AlternativePUId		=	Case	WHEN	(CharIndex	('STLS=', 	pu.Extended_Info, 1)) > 0
												THEN	Substring	(			pu.Extended_Info,
													(	CharIndex	('STLS=', 	pu.Extended_Info, 1) + 5),
														Case 	WHEN 	(CharIndex(';', pu.Extended_Info, CharIndex('STLS=', pu.Extended_Info, 1))) > 0
																THEN 	(CharIndex(';', pu.Extended_Info, CharIndex('STLS=', pu.Extended_Info, 1)) - (CharIndex('STLS=', pu.Extended_Info, 1) + 5)) 
																ELSE 	Len(pu.Extended_Info)
														END )
										END,
			pul.PLId				=	pu.PL_Id,
			pul.PLDesc				=	pl.PL_Desc
	FROM	dbo.Prod_Units	pu	 WITH(NOLOCK)
	JOIN	#PUList			pul	ON pul.PUId = pu.PU_Id
	JOIN	dbo.Prod_Lines	pl	 WITH(NOLOCK) ON pu.PL_Id = pl.PL_Id
---------------------------------------------------------------------------------------------------
-- PrepareTables: update LookUp PUId
---------------------------------------------------------------------------------------------------
UPDATE		pl
	SET		pl.LookUpPUId	= 	Coalesce(pl.AlternativePUId, pl.PUId)
	FROM	#PUList	pl			
---------------------------------------------------------------------------------------------------
-- PrepareTables: Find the production var id
-- Note: Reject production units collect their own production information, so the code should not
-- use the value of STLS on the extended_info field of production unit to search for the production
-- variable id.
---------------------------------------------------------------------------------------------------
UPDATE		pl
	SET		pl.ProductionVarId	= 	v.Var_Id
	FROM	#PUList			pl			
	JOIN	dbo.Variables	v  WITH(NOLOCK)	ON	pl.PUId = v.PU_Id
	WHERE	v.Test_Name = @RptProdVarTestName	

--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- PRINT	'	- TimeIntervals '
---------------------------------------------------------------------------------------------------
-- Print '	.	Shifts'
---------------------------------------------------------------------------------------------------
-- Time Interval: Get Shifts
---------------------------------------------------------------------------------------------------
SELECT	@intShiftLengthInMin = 	@RptShiftLength * 60
--
SELECT	@intShiftOffsetInMin = 	DatePart(Hour, @RptShiftStart) * 60 + DatePart(Minute, @RptShiftStart)
---------------------------------------------------------------------------------------------------
-- Print '	.	ShiftSchedCursor' 
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
	-------------------------------------------------------------------------------------------------
	-- Time Interval Get Shifts:
	-- If there is a Crew Schedule for some or all production units
	-------------------------------------------------------------------------------------------------
-- 	Print '		PUId = ' + Convert(VarChar(25), @c_intPUId)
	-------------------------------------------------------------------------------------------------
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
								+		'		FROM	dbo.Crew_Schedule cs  WITH(NOLOCK) '
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
CLOSE		ShiftScheduleCursor
DEALLOCATE 	ShiftScheduleCursor
---------------------------------------------------------------------------------------------------
-- Print '	.	Get Line Status' 
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
			FROM	dbo.Local_PG_Line_Status 	ls WITH(NOLOCK)
			JOIN	#PUList							pl	ON	pl.LookUpPUId 		= ls.Unit_Id						
			JOIN	#FilterLineStatusList		fl	ON	ls.Line_Status_Id = fl.LineStatusId	
			WHERE	Start_DateTime <= @dtmEndDateTime
			AND		(End_DateTime 	>	@dtmStartDateTime OR End_DateTime IS NULL)
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
		SELECT		pl.PUId,
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
			FROM	dbo.Local_PG_Line_Status	ls WITH(NOLOCK)
			JOIN	dbo.Phrase 					p  WITH(NOLOCK)	ON 	ls.Line_Status_Id = p.Phrase_Id
												/*	AND	p.Data_Type_Id = (	SELECT		Data_Type_Id
																				FROM	dbo.Data_Type  WITH(NOLOCK)
																				WHERE	Data_Type_Desc = 'Line Status') */
			JOIN	#PUList						pl	ON	pl.LookUpPUId = ls.Unit_Id			
			WHERE	Start_DateTime 	<= 	@dtmEndDateTime
			AND		(End_DateTime 	>	@dtmStartDateTime OR End_DateTime IS NULL)
END
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- Print '	-	Split line status records that overlap production_starts '
---------------------------------------------------------------------------------------------------
-- Prepare Tables: split line status records that overlap production_starts
---------------------------------------------------------------------------------------------------
UPDATE		ls
	SET		ls.ProdId = ps.Prod_Id 
	FROM	#LineStatusList			ls
	JOIN	dbo.Production_Starts	ps	 WITH(NOLOCK) ON		ls.PUId = ps.PU_Id
	WHERE	ls.LineStatusStart	>= ps.Start_Time
	AND	(	ls.LineStatusStart 	< 	ps.End_Time	
	OR		ps.End_Time IS NULL)	
---------------------------------------------------------------------------------------------------
UPDATE		ls
	SET		OverlapFlagProdStarts 	= ps.Start_Id,
			OverlapSequence 		= 1,
			OverlapRcdFlag 			= 1,
			SplitFlagProdStarts		= 1
	FROM	#LineStatusList 		ls
	JOIN	dbo.Production_Starts 	ps  WITH(NOLOCK) ON ls.PUId = ps.PU_Id
	WHERE	ls.LineStatusStart	< ps.Start_Time
	AND		ls.LineStatusEnd 	> ps.Start_Time
---------------------------------------------------------------------------------------------------
SET	@j = 1
---------------------------------------------------------------------------------------------------
-- Print '	.	Initial @j: ' + Convert(VarChar, @j)
---------------------------------------------------------------------------------------------------
WHILE	@j < 1100 
BEGIN
	INSERT INTO		#LineStatusList (
					PUId,
					LineStatusSchedId,
					LineStatusId,
					LineStatusDesc,
					LineStatusStart,
					LineStatusEnd,
					OverlapFlagProdStarts,
					OverlapSequence,
					OverlapRcdFlag,
					SplitFlagProdStarts )
		SELECT		PUId,
					LineStatusSchedId,
					LineStatusId,
					LineStatusDesc,
					LineStatusStart,
					LineStatusEnd,
					OverlapFlagProdStarts,
					2,
					1,
					1
			FROM	#LineStatusList
			WHERE	OverlapFlagProdStarts > 0
	----------------------------------------------------------------------------
	UPDATE		ls
		SET		LineStatusEnd = ps.Start_Time
		FROM	#LineStatusList 		ls
		JOIN	dbo.Production_Starts 	ps  WITH(NOLOCK)	ON	ls.PUId = ps.PU_Id
											AND ls.OverlapFlagProdStarts = ps.Start_Id
											AND	ls.OverlapSequence = 1
	----------------------------------------------------------------------------
	UPDATE	ls
		SET	LineStatusStart = ps.Start_Time,
				ProdId = ps.Prod_Id
		FROM	#LineStatusList			ls
		JOIN	dbo.Production_Starts	ps  WITH(NOLOCK)	ON	ls.PUId = ps.PU_Id
											AND ls.OverlapFlagProdStarts = ps.Start_Id
											AND	ls.OverlapSequence = 2
	----------------------------------------------------------------------------
	UPDATE		ls
		SET		OverlapFlagProdStarts = 0,
				OverlapSequence = 0
		FROM	#LineStatusList ls
		WHERE	ls.OverlapFlagProdStarts > 0
	----------------------------------------------------------------------------
	UPDATE		ls
		SET		OverlapFlagProdStarts = ps.Start_Id,
				OverlapSequence = 1,
				SplitFlagProdStarts = 1
		FROM	#LineStatusList ls
		JOIN	dbo.Production_Starts ps  WITH(NOLOCK) ON ls.PUId = ps.PU_Id
		WHERE	LineStatusStart	< ps.Start_Time
		AND		LineStatusEnd 	> ps.Start_Time
		AND		ls.OverlapRcdFlag = 1
	----------------------------------------------------------------------------
	UPDATE		ls
		SET		OverlapRcdFlag = 0 
		FROM	#LineStatusList ls
		WHERE	ls.OverlapFlagProdStarts = 0
	----------------------------------------------------------------------------
	IF	(	SELECT 		Count(OverlapFlagProdStarts)
				FROM	#LineStatusList
				WHERE 	OverlapFlagProdStarts > 0) = 0
	BEGIN
		BREAK		
	END
	--
	SELECT	@j = @j + 1
END
---------------------------------------------------------------------------------------------------
-- Prepare Tables: update Line Status Duration
---------------------------------------------------------------------------------------------------
UPDATE	#LineStatusList
	SET	DurationInSec = DateDiff(Second, LineStatusStart, LineStatusEnd)
---------------------------------------------------------------------------------------------------
-- Prepare Tables: update line status pad count
---------------------------------------------------------------------------------------------------

DECLARE	LineStatusCursor INSENSITIVE CURSOR 
FOR (	SELECT	ls.LSRcdId,
					ls.LineStatusStart,
					ls.LineStatusEnd,
					p.ProductionVarId
			FROM	#LineStatusList	ls
			JOIN	#PUList			p	ON	p.PUId = ls.PUId )
FOR READ ONLY
OPEN LineStatusCursor
FETCH	NEXT FROM LineStatusCursor INTO @c_intLSRcdId, @c_dtmLineStatusStart, @c_dtmLineStatusEnd, @c_intProductionVarId
WHILE	@@Fetch_Status = 0
BEGIN
	--
	SELECT		@intPadCount = Sum(Convert(Float, Result))
		FROM	dbo.Tests	t  WITH(NOLOCK)
		WHERE	t.Result_On	>	@c_dtmLineStatusStart
		AND		t.Result_ON <=	@c_dtmLineStatusEnd
		AND		t.Var_Id	= 	@c_intProductionVarId
	--
	UPDATE		#LineStatusList
		SET		PadCount 	= @intPadCount
		WHERE	LSRcdId		= @c_intLSRcdId
	--	
	FETCH	NEXT FROM LineStatusCursor INTO @c_intLSRcdId, @c_dtmLineStatusStart, @c_dtmLineStatusEnd, @c_intProductionVarId
--
END
CLOSE		LineStatusCursor
DEALLOCATE 	LineStatusCursor
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- Select * From #LineStatusList
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- Print '	-	RejectDetails ' 
---------------------------------------------------------------------------------------------------
-- Reject: Obtain the Reject details for the specified time period and apply filters
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand = ''
SET	@chrSQLCommand1 = ''
SET	@chrSQLCommand2 = ''
--
SET	@chrSQLCommand1 = 	'	INSERT INTO 	#RejectDetail ( '
	+					'					PLId,	'
	+					'					PUId, '
	+					'					WEDId, '
	+					'					RejectTimeStamp, '
	+					'					OffSetFromMidnightInSec, '
	+					'					SourcePUId, '
	+					'					WasteRL1Id, '
	+					'					RejectCount, '				
	+					'					EventCount ) '
SET	@chrSQLCommand2 =	'		SELECT		pu.PLId, '
	+					'					pu.PUId, '
	+					'					wed.WED_Id, '
	+					'					wed.TimeStamp, '
	+					'					(DatePart(hh, wed.TimeStamp) * 60 * 60) + (DatePart(mi, wed.TimeStamp) * 60) + DatePart(ss, wed.TimeStamp), '
	+					'					wed.Source_PU_Id, '
	+					'					wed.Reason_Level1, '
	+					'					wed.Amount, '
	+					'					1 '
	+					'			FROM	dbo.Waste_Event_Details wed  WITH(NOLOCK) '
	+					'			JOIN	#PUList				pu	ON	pu.PUId 			=	wed.PU_Id ' 
	+					'			WHERE 	wed.TimeStamp	<= ''' + Convert(VarChar, @dtmEndDateTime, 120) + ''' '
	+					'			AND 	wed.TimeStamp	>  ''' + Convert(VarChar, @dtmStartDateTime, 120) + ''''

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
IF	(	SELECT 		Count(*) 	
			FROM	#FilterEventReasonIdList
			WHERE	ReasonLevelId = 1) > 0
BEGIN
	SET	@chrSQLCommand2 = 	@chrSQLCommand2 + ' AND wed.Reason_Level1 IN (	SELECT 		EventReasonId '
											+ '									FROM 	#FilterEventReasonIdList '
											+ ' 								WHERE 	ReasonLevelId = 1 )'
END
---------------------------------------------------------------------------------------------------
-- Get reject details
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand = @chrSQLCommand1 + ' ' + @chrSQLCommand2

EXEC 		(@chrSQLCommand)

-- PRINT 'Reject Details - ' + @chrSQLCommand
---------------------------------------------------------------------------------------------------
-- UPDATE reject details
---------------------------------------------------------------------------------------------------
-- SELECT * FROM #LineStatusList		

SET	@chrSQLCommand = 	' UPDATE #RejectDetail '
	+					'		SET ProdId 			= 		ls.ProdId, '
	+					'		LineStatusId 		= 		ls.LineStatusId, '
	+					'		LSRcdId 			= 		ls.LSRcdId, '
	+					'		ShiftDesc 			= 		sl.ShiftDesc, '
	+					'		CrewDesc 			= 		sl.CrewDesc, '
	+					'		EventReasonName1 	= 		r1.Event_Reason_Name '
	+					' FROM #RejectDetail rd '
	+					' JOIN	dbo.Event_Reasons 	r1 	WITH(NOLOCK) ON 	rd.WasteRL1Id 	= 	r1.Event_Reason_Id '
	+					' JOIN	#ShiftList 			sl 	ON 	sl.ShiftStart <= rd.RejectTimeStamp 	AND	sl.ShiftEnd	> rd.RejectTimeStamp  '
	+					'											AND sl.PUId = rd.PUId 			'
	+					' JOIN	#LineStatusList 	ls 	ON 	ls.LineStatusStart <= rd.RejectTimeStamp AND (ls.LineStatusEnd > rd.RejectTimeStamp OR ls.LineStatusEnd IS NULL) '
	+					'											AND ls.PUId = rd.PUId	'
	
EXEC	(@chrSQLCommand)

-- PRINT 'Reject Update - ' + @chrSQLCommand

---------------------------------------------------------------------------------------------------
-- Apply Product, Crew, Shift, Line Status Filter (Now should be applyed after the Update)
---------------------------------------------------------------------------------------------------

DELETE FROM #RejectDetail 
	WHERE (ProdId IS NULL) OR (ShiftDesc IS NULL) OR (CrewDesc IS NULL) OR (LineStatusId IS NULL) 

---------------------------------------------------------------------------------------------------
-- UPDATE Production Day
---------------------------------------------------------------------------------------------------
SET	@intShiftOffset = DatePart(hh, @RptShiftStart) * 60 * 60 + DatePart(mi, @RptShiftStart) * 60 + DatePart(ss, @RptShiftStart)  
UPDATE	#RejectDetail
	SET	ProductionDay =	Case	WHEN	OffsetFromMidnightInSec >= 0 AND OffsetFromMidnightInSec < @intShiftOffset
								THEN	Substring(Convert(VarChar, DateAdd(day, -1, RejectTimeStamp), 120), 1, 10)
								ELSE 	Substring(Convert(VarChar, RejectTimeStamp, 120), 1, 10)
						END
---------------------------------------------------------------------------------------------------
-- Print '	.	Get Comments'
---------------------------------------------------------------------------------------------------
-- Waste: Get the comments
-- Note: There is a new field in the Waste_Event_Details table called Cause_Comment_Id
-- This field will collect the comment id's in Proficy 4.0
-- In the meantime, the comment id's for waste events are collected by a table
-- called Waste_n_Timed_Comments where WCT_Type = 3. 
---------------------------------------------------------------------------------------------------
IF	@fltDBVersion <= 300215.70 
BEGIN
	SET	@intCommentTableFlag = 2
	--
	DECLARE	DetailCommentCursor1 INSENSITIVE CURSOR FOR (
	SELECT	WEDId
		FROM	#RejectDetail 				rd -- WITH(INDEX(RD_WEDId_PUId_ProdId_Idx))
		JOIN	dbo.Waste_n_Timed_Comments 	wt WITH(NOLOCK) ON rd.WEDId = wt.WTC_Source_Id
		WHERE	WTC_Type = 3 )
	FOR READ ONLY
	OPEN	DetailCommentCursor1
	FETCH	NEXT FROM DetailCommentCursor1 INTO @c_intWEDId
	WHILE	@@Fetch_Status = 0
	BEGIN
		------------------------------------------------------------------------
		--Print 'WEDId: ' + Convert(VarChar, @c_intWEDId)
		------------------------------------------------------------------------
		-- Note: multiple comments can be entered for each waste record. This is
		-- the reason a cursor has been used here to concatenate all the CommentId's
		------------------------------------------------------------------------
		SET	@chrTempString = ''
		DECLARE	DetailCommentCursor2 INSENSITIVE CURSOR FOR (
		SELECT	WTC_Id
			FROM	dbo.Waste_n_Timed_Comments wt WITH(NOLOCK)
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
		CLOSE			DetailCommentCursor2
		DEALLOCATE 	DetailCommentCursor2
	--
	UPDATE	rd
		SET	CauseCommentId = Substring(LTrim(RTrim(@chrTempString)), 2, Len(@chrTempString))
		FROM	#RejectDetail	rd	-- WITH(INDEX(RD_WEDId_PUId_ProdId_Idx))
		WHERE	WEDId = @c_intWEDId
	--
	FETCH	NEXT FROM DetailCommentCursor1 INTO @c_intWEDId
	------------------------------------------------------------------------
	--Print 'WTCIdList: ' + @chrTempString
	------------------------------------------------------------------------
	END
	CLOSE			DetailCommentCursor1
	DEALLOCATE 	DetailCommentCursor1
END
ELSE
BEGIN
	------------------------------------------------------------------------
	--	Proficy 4.0
	------------------------------------------------------------------------
	SET	@intCommentTableFlag = 1
	--
	UPDATE	rd
		SET	CauseCommentId = Cause_Comment_Id
		FROM	dbo.Waste_Event_Details ted WITH(NOLOCK)
		JOIN	#RejectDetail rd 	-- WITH(INDEX(RD_WEDId_PUId_ProdId_Idx))
										ON rd.WEDId = ted.WED_Id
END
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- Print '	-	RS1: Misc Info ' 
---------------------------------------------------------------------------------------------------
-- RS1: Misc Info
---------------------------------------------------------------------------------------------------
INSERT INTO	#MiscInfo (
			CompanyName,
			SiteName,
			-- RptOwnerDesc,
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
			
			CommentTableFlag )
	SELECT	@chrCompanyName,
			@chrSiteName,
			-- @chrRptOwnerDesc,
			Convert(VarChar(50), @dtmStartDateTime, 120),
			Convert(VarChar(50), @dtmEndDateTime, 120),
			@RptShiftDescList,
			@RptCrewDescList,
			@RptLineStatusDescList,
			@RptProdIdList,
			@RptSourcePUIdList,
			@RptEventReasonIdList,
			@RptTitle,
			@RptRejectHistoryMajorGroupBy,
			@RptRejectHistoryMinorGroupBy,		
			@intCommentTableFlag
-- 
SELECT * FROM	#MiscInfo
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- Print '	-	RS2: Major Group List ' 
---------------------------------------------------------------------------------------------------
-- RS2: Major Group List
---------------------------------------------------------------------------------------------------
SET	@chrProdDescList = ''
--
IF	(SELECT	Count(*)
			FROM	#FilterProdList ) > 0
BEGIN
	--
	DECLARE	ProdCodeCursor INSENSITIVE CURSOR FOR (
	SELECT	Coalesce(ProdCode, '')
		FROM	#FilterProdList )
	ORDER	BY ProdCode
	FOR READ ONLY
	OPEN	ProdCodeCursor
	FETCH	NEXT FROM ProdCodeCursor INTO @c_chrProdCode
	WHILE	@@Fetch_Status = 0
	BEGIN
	--	
		SET	@chrProdDescList = @chrProdDescList + ', ' + @c_chrProdCode
		FETCH	NEXT FROM ProdCodeCursor INTO @c_chrProdCode
	--
	END
	CLOSE		ProdCodeCursor
	DEALLOCATE 	ProdCodeCursor
	--
	SET	@chrProdDescList = LTrim(RTrim(Substring(@chrProdDescList, 2, Len(@chrProdDescList))))
END
ELSE
BEGIN
	SET	@chrProdDescList = 'All'
END
---------------------------------------------------------------------------------------------------
SET	@chrPUDescList = ''
--
DECLARE	PUDescCursor INSENSITIVE CURSOR FOR (
SELECT	PU_Desc
	FROM	#PUList	pl
	JOIN	dbo.Prod_Units	pu WITH(NOLOCK) ON pu.PU_Id = pl.PUId )
ORDER	BY PUDesc
FOR READ ONLY
OPEN	PUDescCursor
FETCH	NEXT FROM PUDescCursor INTO @c_chrPUDesc
WHILE	@@Fetch_Status = 0
BEGIN
	------------------------------------------------
	SET	@chrPUDescList = @chrPUDescList + ', ' + @c_chrPUDesc
	FETCH	NEXT FROM PUDescCursor INTO @c_chrPUDesc
--
END
CLOSE		PUDescCursor
DEALLOCATE 	PUDescCursor
--
SET	@chrPUDescList = LTrim(RTrim(Substring(@chrPUDescList, 2, Len(@chrPUDescList))))
---------------------------------------------------------------------------------------------------
-- SELECT * FROM #FilterProdList

IF	@RptRejectHistoryMajorGroupBy = 'PUId|ProdId'
BEGIN
	IF EXISTS (SELECT * FROM #FilterProdList)
			SELECT		rd.PUId, 
						pu.PU_Desc PUDesc, 
						rd.ProdId, 
						p.Prod_Code ProdCode
				FROM	#RejectDetail 	rd
				JOIN	dbo.Prod_Units 	pu 	WITH(NOLOCK) ON rd.PUId 		= pu.PU_Id
				JOIN	dbo.Products 	p 	WITH(NOLOCK) ON p.Prod_Id 	= rd.ProdId
				JOIN    #FilterProdList fpl 			 ON fpl.ProdId = p.Prod_Id
			GROUP BY	rd.PUId, pu.PU_Desc, rd.ProdId, p.Prod_Code
			ORDER	BY	pu.PU_Desc
	ELSE
			SELECT		rd.PUId, 
						pu.PU_Desc PUDesc, 
						rd.ProdId, 
						p.Prod_Code ProdCode
				FROM	#RejectDetail 	rd
				JOIN	dbo.Prod_Units 	pu 	WITH(NOLOCK) ON rd.PUId 		= pu.PU_Id
				JOIN	dbo.Products 	p 	WITH(NOLOCK) ON p.Prod_Id 	= rd.ProdId
			GROUP BY	rd.PUId, pu.PU_Desc, rd.ProdId, p.Prod_Code
			ORDER	BY	pu.PU_Desc


END
--------------------------------------------------
IF	@RptRejectHistoryMajorGroupBy = 'PUId'
BEGIN
	SELECT	rd.PUId, 
				pu.PU_Desc 			PUDesc, 
				@chrProdDescList	ProdCode
		FROM	#RejectDetail 	rd
		JOIN	dbo.Prod_Units 	pu WITH(NOLOCK) ON rd.PUId = pu.PU_Id
	GROUP BY	rd.PUId, pu.PU_Desc
	ORDER	BY	pu.PU_Desc
END	
--------------------------------------------------
IF	@RptRejectHistoryMajorGroupBy = '!Null'	
OR	Len(@RptRejectHistoryMajorGroupBy) = 0
BEGIN
	SELECT	0					PUId, 
			@chrPUDescList 		PUDesc, 
			@chrProdDescList	ProdCode
END
--------------------------------------------------
IF	@RptRejectHistoryMajorGroupBy = 'ProdId'
BEGIN
		IF EXISTS (SELECT * FROM #FilterProdList)
			SELECT		0				PUId, 
						@chrPUDescList 	PUDesc,
						rd.ProdId, 
						p.Prod_Code 	ProdCode
				FROM	#RejectDetail 	rd
				JOIN	dbo.Products 	p WITH(NOLOCK) 		ON p.Prod_Id = rd.ProdId
				JOIN    #FilterProdList fpl 			 	ON fpl.ProdId = p.Prod_Id
			GROUP BY	rd.ProdId, p.Prod_Code
			ORDER BY	p.Prod_Code
		ELSE
			SELECT		0				PUId, 
						@chrPUDescList 	PUDesc,
						rd.ProdId, 
						p.Prod_Code 	ProdCode
				FROM	#RejectDetail 	rd
				JOIN	dbo.Products 	p WITH(NOLOCK) ON p.Prod_Id = rd.ProdId
			GROUP BY	rd.ProdId, p.Prod_Code
			ORDER BY	p.Prod_Code
END
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- Print '	-	RS3: Hdr Info ' 
---------------------------------------------------------------------------------------------------
-- RS3: Header info
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand = ''
SET	@chrSQLCommand1 = ''
SET	@chrSQLCommand2 = ''

--
IF	@RptRejectHistoryMajorGroupBy = '!Null'
BEGIN
	SET	@chrSQLCommand1 = '	INSERT INTO	#HdrInfo (' 
										+		'	PUId, '
										+		'	TotalRejectCount, '
										+		'	TotalEventCount ) '
	--
	SET	@chrSQLCommand2 =	'SELECT 	0, '
						+		'				Sum(rd.RejectCount), '
						+		'				Sum(rd.EventCount) '
						+		'		FROM	#RejectDetail 		rd '

	IF EXISTS (SELECT * FROM #FilterProdList)
						SET @chrSQLCommand2 = @chrSQLCommand2 + ' JOIN #FilterProdList fpl ON fpl.ProdId = rd.ProdId '

END
ELSE IF	@RptRejectHistoryMajorGroupBy = 'ProdId'
BEGIN
	SET	@chrSQLCommand1 = '	INSERT INTO	#HdrInfo (' 
										+		'PUId, '
										+			Replace(@RptRejectHistoryMajorGroupBy, '|', ',') + ', '
										+		'	TotalRejectCount, '
										+		'	TotalEventCount ) '
	--
	SET	@chrSQLCommand2 =	'SELECT 	0, ' 
						+ 						Replace(@RptRejectHistoryMajorGroupBy, '|', ',') + ', '
						+		'				Sum(rd.RejectCount), '
						+		'				Sum(rd.EventCount) '
						+		'		FROM	#RejectDetail 		rd '

	IF EXISTS (SELECT * FROM #FilterProdList)
						SET @chrSQLCommand2 = @chrSQLCommand2 + ' WHERE rd.ProdId IN (SELECT ProdId FROM #FilterProdList) '

	SET @chrSQLCommand2 = @chrSQLCommand2 +	'		GROUP BY	' + Replace(@RptRejectHistoryMajorGroupBy, '|', ',')

END
ELSE
BEGIN
	SET	@chrSQLCommand1 = '	INSERT INTO	#HdrInfo (' 
										+			Replace(@RptRejectHistoryMajorGroupBy, '|', ',') + ', '
										+		'	TotalRejectCount, '
										+		'	TotalEventCount ) '
	--
	SET	@chrSQLCommand2 =	'SELECT ' + Replace(@RptRejectHistoryMajorGroupBy, '|', ',') + ', '

						+		'				Sum(rd.RejectCount), '
						+		'				Sum(rd.EventCount) '
						+		'		FROM	#RejectDetail 		rd'

	IF EXISTS (SELECT * FROM #FilterProdList)
						SET @chrSQLCommand2 = @chrSQLCommand2 + ' WHERE rd.ProdId IN (SELECT ProdId FROM #FilterProdList) '

   	SET @chrSQLCommand2 = @chrSQLCommand2 +	'		GROUP BY	' + Replace(@RptRejectHistoryMajorGroupBy, '|', ',')

END
--

SET	@chrSQLCommand = @chrSQLCommand1 + ' ' + @chrSQLCommand2
EXEC	(@chrSQLCommand)

PRINT @chrSQLCommand
---------------------------------------------------------------------------------------------------
-- RS3: Header info - update production information
---------------------------------------------------------------------------------------------------
IF	CharIndex('ProdId', @RptRejectHistoryMajorGroupBy, 1) > 0
BEGIN
	---------------------------------------------
	IF	@RptRejectHistoryMajorGroupBy = 'PUId|ProdId'
	BEGIN
			Set @chrSQLCommand = 'SELECT PUId,lsl.ProdId,Sum(PadCount)  FROM #LineStatusList lsl ' 

			IF EXISTS(SELECT * FROM #FilterProdList)
				Set @chrSQLCommand = @chrSQLCommand + 'JOIN #FilterProdList fpl ON fpl.ProdId = lsl.ProdId '

			Set @chrSQLCommand = @chrSQLCommand + ' GROUP BY		PUId, lsl.ProdId'
			
			INSERT INTO #tblProduction (
						PUId,
						ProdId,
						MGPadCount )
			Exec(@chrSQLCommand)
			
	END
	---------------------------------------------
	IF	@RptRejectHistoryMajorGroupBy = 'ProdId'
	BEGIN

			Set @chrSQLCommand = 'SELECT 0,lsl.ProdId,Sum(PadCount)  FROM #LineStatusList lsl ' 

			IF EXISTS(SELECT * FROM #FilterProdList)
				Set @chrSQLCommand = @chrSQLCommand + 'JOIN #FilterProdList fpl ON fpl.ProdId = lsl.ProdId '

			Set @chrSQLCommand = @chrSQLCommand + ' GROUP BY	lsl.ProdId'

			INSERT INTO #tblProduction (
						PUId,
						ProdId,
						MGPadCount )
			Exec(@chrSQLCommand)

	END
	---------------------------------------------
	UPDATE	#HdrInfo
		SET	TotalPadCount = MGPadCount
		FROM	#HdrInfo		hi
		JOIN	#tblProduction	p	ON 	hi.PUId = p.PUId
									AND	hi.ProdId = p.ProdId

END
ELSE IF	@RptRejectHistoryMajorGroupBy = '!Null'
BEGIN

		Set @chrSQLCommand = 'SELECT 0,Sum(PadCount)  FROM #LineStatusList lsl ' 

		IF EXISTS(SELECT * FROM #FilterProdList)
				Set @chrSQLCommand = @chrSQLCommand + 'JOIN #FilterProdList fpl ON fpl.ProdId = lsl.ProdId '

		INSERT INTO #tblProduction (
					PUId,
					MGPadCount )
		Exec(@chrSQLCommand)
	---------------------------------------------
	UPDATE	#HdrInfo
		SET	TotalPadCount = MGPadCount
		FROM	#HdrInfo		hi
		JOIN	#tblProduction 	p 	ON	hi.PUId = p.PUId
END
ELSE
BEGIN
	Set @chrSQLCommand = 'SELECT PUId,Sum(PadCount)  FROM #LineStatusList lsl ' 

	IF EXISTS(SELECT * FROM #FilterProdList)
				Set @chrSQLCommand = @chrSQLCommand + 'JOIN #FilterProdList fpl ON fpl.ProdId = lsl.ProdId '

	Set @chrSQLCommand = @chrSQLCommand + ' GROUP BY	PUId'
	INSERT INTO #tblProduction (
					PUId,
					MGPadCount )
	Exec(@chrSQLCommand)	
	---------------------------------------------
	UPDATE	#HdrInfo
		SET	TotalPadCount = MGPadCount
		FROM	#HdrInfo		hi
		JOIN	#tblProduction	p	ON 	hi.PUId = p.PUId
END
---------------------------------------------------------------------------------------------------
-- RS3: HdrInfo calculations
---------------------------------------------------------------------------------------------------
 UPDATE	#HdrInfo
 	SET	TotalPercentScrap	= 	Case	WHEN	TotalPadCount > 0
 										THEN	Convert(Float, TotalRejectCount) / Convert(Float, TotalPadCount)
 								END
---------------------------------------------------------------------------------------------------
-- RS3: HdrInfo return result set
---------------------------------------------------------------------------------------------------
SELECT	* 	FROM #HdrInfo
--=================================================================================================
-- PRINT	'END SECTION : ' + Convert(VarChar, @intSecNumber) + ' - TOTAL TIME (sec): ' + Convert(VarChar, DateDiff(Second, @dtmTempDate, GetDate())) 
SET	@dtmTempDate 	= GetDate()
SET	@intSecNumber 	= @intSecNumber + 1
-- PRINT '--------------------------------------------------------------------------------------------'
-- PRINT 'START SECTION : '+	Convert(VarChar, @intSecNumber)
--=================================================================================================
-- Print 'RS4: Final Result Set ' + Convert(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) 
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = !Null (None)
---------------------------------------------------------------------------------------------------
SET	@chrSQLCommand1 	= ''
SET	@chrSQLCommand2 	= ''
SET	@chrSQLCommand3		= ''
SET	@chrSQLCommand4		= ''
SET	@chrSQLCommand 		= ''
---------------------------------------------------------------------------------------------------
IF	(@RptRejectHistoryMajorGroupBy = '!Null')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT 0, Null'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = PUId
---------------------------------------------------------------------------------------------------
IF	(@RptRejectHistoryMajorGroupBy = 'PUId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT rd.PUId, Null'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY rd.PUId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = ProdId
---------------------------------------------------------------------------------------------------
IF	(@RptRejectHistoryMajorGroupBy = 'ProdId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT 0, rd.ProdId'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY rd.ProdId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - Major grouping = PUId|ProdId
---------------------------------------------------------------------------------------------------
IF	(@RptRejectHistoryMajorGroupBy = 'PUId|ProdId')
BEGIN
	SET	@chrSQLCommand1 = 'SELECT rd.PUId, rd.ProdId'
	--	
	SET	@chrSQLCommand3 = 'GROUP BY rd.PUId, rd.ProdId '
END
---------------------------------------------------------------------------------------------------
-- RS4: Build select statement - minor group is !Null or Null
---------------------------------------------------------------------------------------------------


IF	(@RptRejectHistoryMinorGroupBy = '!Null' 
OR	(Len(IsNull(@RptRejectHistoryMinorGroupBy, ''))) = 0)
BEGIN
	SET	@chrSQLCommand1 = 	@chrSQLCommand1	+ 	',	Convert(VarChar, rd.RejectTimeStamp, 121), '
											+	'	rd.RejectCount, '
											+	'  	rd.EventCount, '
											+	'	rd.CauseCommentId, '
											+	'	pul.PLDesc, '
											+ 	'	pul.PUDesc, '
											+ 	'	p.Prod_Code, '
											+	'	rd.ShiftDesc, '
											+	'	rd.CrewDesc, '
											+	'	sl.LineStatusDesc, '
											+  	'  	pu.PU_Desc, ' 
											+	'	rd.EventReasonName1, '
											+  	'  	rd.ProductionDay '
	SET	@chrSQLCommand2 = 	'	FROM			#RejectDetail 			rd 	' -- WITH(INDEX(RD_WEDId_PUId_ProdId_Idx)) '
					+		'	JOIN			dbo.Prod_Units 			pu	WITH(NOLOCK)	ON 	pu.PU_Id = rd.SourcePUId '
					+		'	JOIN			#PUList 				pul 	ON 	pul.PUId = rd.PUId '
					+		'	Left 	JOIN	#LineStatusList			sl		ON 	sl.LSRcdId = rd.LSRcdId '
					+		'													AND	sl.PUId = rd.PUId '
					+		'	Left	JOIN	dbo.Products			p		ON		rd.ProdId = p.Prod_Id '
	--	
	
--============================================================================
	 -- Added the  below IF condition to fikter the products FO-01974
  IF EXISTS(SELECT * FROM #FilterProdList)  
   SET @chrSQLCommand2 = @chrSQLCommand2 + ' JOIN   #FilterProdList fpl ON rd.ProdId = fpl.ProdId '
--=============================================================================
   
   
	SET	@chrSQLCommand3 = ''
END
ELSE
BEGIN
	------------------------------------------------------------------------------
	-- RS4: Build select statement - eliminate reject time stamp
	-------------------------------------------------------------------------------
	SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	----------------------------------------------------------------------------
	-- RS4: Build select statement - common sums
	----------------------------------------------------------------------------
	SET	@chrSQLCommand1 =	@chrSQLCommand1 	+ 	',	Sum(rd.RejectCount), '
												+	'	Sum(rd.EventCount), 	'
												+	'	Null '
	--
	SET	@chrSQLCommand2 = '	FROM			#RejectDetail rd '

	IF EXISTS(SELECT * FROM #FilterProdList)
			SET	@chrSQLCommand2 = @chrSQLCommand2 + '	JOIN 		#FilterProdList fpl ON rd.ProdId = fpl.ProdId '
	--
	------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes Production Line
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy LIKE '%PLId%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pul.PLDesc '
		--
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ 'JOIN	#PUList pul ON pul.PUId = rd.PUId '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', pul.PLDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes Production Unit
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy LIKE '%PUId%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pul.PUDesc '
		--
		IF	(@RptRejectHistoryMinorGroupBy NOT LIKE '%PLId%')
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
	------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ShiftDesc
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%ProdCode%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', p.Prod_Code'
		--
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ 'Left	JOIN	dbo.Products p	ON	rd.ProdId = p.Prod_Id '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', p.Prod_Code '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ShiftDesc
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%ShiftDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.ShiftDesc'
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', rd.ShiftDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes CrewDesc
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%CrewDesc%')

	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.CrewDesc'
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', rd.CrewDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProdStatus
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%ProdStatus%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', sl.LineStatusDesc'
		SET	@chrSQLCommand2 = @chrSQLCommand2 
							+		'	Left JOIN ( SELECT DISTINCT PUId,LineStatusId,LineStatusDesc FROM #LineStatusList)	sl	ON 	sl.LineStatusId = rd.LineStatusId '
							+		'												AND	sl.PUId = rd.PUId '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', sl.LineStatusDesc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes SourcePUId
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%SourcePUDesc%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', pu.PU_Desc'
		SET	@chrSQLCommand2 = @chrSQLCommand2	+ '  JOIN dbo.Prod_Units 	pu	ON pu.PU_Id = rd.SourcePUId '
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 + ', pu.PU_Desc '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes EventReasonName1
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%EventReasonName1%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.EventReasonName1'
		--
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', rd.EventReasonName1 '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
	-------------------------------------------------------------------------------
	-- RS4: Build select statement - minor group includes ProductionDay
	-------------------------------------------------------------------------------
	IF	(@RptRejectHistoryMinorGroupBy Like '%ProductionDay%')
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', rd.ProductionDay '
		SET	@chrSQLCommand3 = @chrSQLCommand3 	+ ', rd.ProductionDay '
	END
	ELSE
	BEGIN
		SET	@chrSQLCommand1 = @chrSQLCommand1	+ ', Null'
	END
END
---------------------------------------------------------------------------------------------------
IF	(@RptRejectHistoryMajorGroupBy = '!Null')
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

--  Print 'Final RS - ' + @chrSQLCommand -- debugdel
--
INSERT INTO	#FinalResultSet (
			PUId,
			ProdId,
			RejectTimeStamp,
			RejectCount,
			EventCount,
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
--
EXEC	(@chrSQLCommand)
-------------------------------------------------------------------------------
-- RS4: Minor Grouping calculations - total production time
-------------------------------------------------------------------------------
SELECT	@fltProductionTime = (Sum(DurationInSec) * 1.0) / 60.0
	FROM	#LineStatusList
-------------------------------------------------------------------------------
-- RS4: Minor Grouping calculations 
-------------------------------------------------------------------------------
IF	@RptRejectHistoryMajorGroupBy = 'PUId' OR @RptRejectHistoryMajorGroupBy = '!Null'
BEGIN
	UPDATE	fr
		SET	fr.TotalRejectCount 	= hi.TotalRejectCount,
				fr.TotalEventCount 	= hi.TotalEventCount,
				fr.TotalProduction 	= hi.TotalPadCount
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo	hi ON hi.PUId = fr.PUId
END
ELSE
BEGIN
	UPDATE	fr
		SET	fr.TotalRejectCount 	= hi.TotalRejectCount,
				fr.TotalEventCount	= hi.TotalEventCount,
				fr.TotalProduction	= hi.TotalPadCount
		FROM	#FinalResultSet fr
		JOIN	#HdrInfo	hi ON 	hi.PUId = fr.PUId
								AND	hi.ProdId = fr.ProdId
END
-------------------------------------------------------------------------------
UPDATE	#FinalResultSet 
	SET	PercentOfScrap 	= 	Case	WHEN	TotalRejectCount > 0
									THEN	LTrim(RTrim(Str(Convert(Float, RejectCount) / Convert(Float, TotalRejectCount), 25, 8)))
							END,
		PercentScrap 	= 	Case	WHEN	TotalProduction > 0
									THEN	LTrim(RTrim(Str(Convert(Float, RejectCount) / Convert(Float, TotalProduction), 25, 8)))
							END,
		PercentOfEvents = 	Case	WHEN	TotalEventCount > 0
									THEN	LTrim(RTrim(Str(Convert(Float, EventCount) / Convert(Float, TotalEventCount), 25, 8))) 
							END,
		RejectsPerDay 	= 	Case	WHEN	@fltProductionTime > 0
									THEN	LTrim(RTrim(Str(Convert(Float, RejectCount) * 1440.0  / @fltProductionTime, 25, 2))) 
							END,
		EventsPerDay	= 	Case	WHEN	@fltProductionTime > 0
									THEN	LTrim(RTrim(Str(Convert(Float, EventCount) * 1440.0 / @fltProductionTime, 25, 2)))
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
-------------------------------------------------------------------------------
-- RS4: Return result set
-------------------------------------------------------------------------------

	SELECT		PUId,
				ProdId,
				Border1,
				PLDesc,
				PUDesc,
				RejectTimeStamp,
				ProductionDay,
				ProdCode,
				ShiftDesc,
				CrewDesc,
				ProdStatus,
				SourcePUDesc,
				EventReasonName1,
				RejectCount,	
				EventCount,
				PercentOfScrap,
				PercentScrap,
				PercentOfEvents,
				RejectsPerDay,
				EventsPerDay,
				Comments,
				Border2
		FROM	#FinalResultSet
	ORDER BY	PUId, ProdId, RejectTimeStamp

---------------------------------------------------------------------------------------------------
-- Select from tables -- used for debugging only comment before installation
---------------------------------------------------------------------------------------------------
-- SELECT 'MiscInfo', 						* FROM #MiscInfo
-- SELECT 'HdrInfo',						* FROM #HdrInfo
-- SELECT 'PUList', 						* FROM #PUList
-- SELECT 'FilterLineStatusList',			* FROM #FilterLineStatusList
-- SELECT 'FilterProdList',					* FROM #FilterProdList
-- SELECT 'FilterShiftList',				* FROM #FilterShiftList
-- SELECT 'FilterCrewList',					* FROM #FilterCrewList
-- SELECT 'FilterSourcePUIdList', 			* FROM #FilterSourcePUIdList
-- SELECT 'FilterEventReasonIdList',		* FROM #FilterEventReasonIdList
-- SELECT 'LineStatusList', 				* FROM #LineStatusList Order By ProdId
-- SELECT 'ShiftList',						* FROM #ShiftList
-- SELECT 'VisibleFieldList',				* FROM #VisibleFieldList
-- SELECT 'RejectDetail',					* FROM #RejectDetail ORDER BY PUId, RejectTimeStamp
-- SELECT 'FinalResultSet',					* FROM #FinalResultSet
-- SELECT 'Production', 					* FROM #tblProduction
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
DROP	TABLE	#RejectDetail
DROP	TABLE	#FinalResultSet
DROP  	TABLE 	#FilterSourcePUIdList
DROP  	TABLE 	#FilterEventReasonIdList
DROP  	TABLE 	#tblProduction 

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[spLocal_RptRejectHistory_HTML5]  TO [OPDBManager]
GO