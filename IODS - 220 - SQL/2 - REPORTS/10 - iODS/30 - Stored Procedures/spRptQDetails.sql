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
		@Version	NVARCHAR(20)

SELECT
		@SP_Name	= 'spRptQDetail',
		@Inputs		= 6, 
		@Version	= '1.8'  

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
				
DROP PROCEDURE [dbo].[spRptQDetail]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptQDetail
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Campana Damian - Arido Software
-- Date created			: 2018-06-08
-- Version 				: 1.6
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for the Q Detail Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-06-08		Campana Damian     		Initial Release
-- 1.1		2019-07-08		Conde Gustavo			Added default collation on temporal table nvarchar fields 
--													for avoid collation conflicts
-- 1.2		2019-08-01		Camapana Damian			Change function to get the Start and End time
-- 1.3		2019-08-05		Conde Gustavo			Validate non-numeric values on OpsDB_VariablesTasks_RawData.Result 
-- 1.4		2019-08-14		Gonzalo Luc				Add User column to the output
-- 1.5		2019-08-28		Damian Campana			Capability to filter with the time option 'Last Week'
-- 1.6		2019-08-28		Gustavo Conde			Add parameter for variables filtering
-- 1.7		2019-10-17		Damian Campana			Change code to update the Parent PPM
-- 1.8		2019-11-08		Federico Vicente		Add Column Comment_Rtf
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptQDetail]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
 --DECLARE
	 @prodLineId	VARCHAR(MAX)	= NULL
	,@timeOption	INT				= NULL
	,@dtmStartDate	DATETIME		= NULL
	,@dtmEndDate	DATETIME		= NULL
	,@ProcessOrder	NVARCHAR(100)	= NULL
	,@Product		NVARCHAR(100)	= NULL
	,@variableId	NVARCHAR(MAX)	= NULL
	
--WITH ENCRYPTION
AS
SET NOCOUNT ON
-- --------------------------------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
DECLARE 
		 @strPLDesc				NVARCHAR(200)
		,@strTimeOption			NVARCHAR(50)
		,@strPRDesc				NVARCHAR(50)
		--,@dtmStartDate		DATETIME
		--,@dtmEndDate			DATETIME

-- DECLARE 
		-- @tblTimeOption		TABLE (startDate DATETIME, endDate DATETIME)

-- --------------------------------------------------------------------------------------------------------------------
-- Output table
-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FinalOutput', 'U') IS NOT NULL  DROP TABLE #FinalOutput; 
CREATE TABLE #FinalOutput (	
			  DataType			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, VarId				INT
			, VarDesc_Chart		NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, ResultInt			FLOAT
			, PUId				INT
			, PUDesc			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, PLId				INT
			, PLDesc			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, ProdId			INT
			, ProdCode			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, ProcessOrder		NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, ProdDesc			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, Result			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, LReject			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, UReject			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, LWarning			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, UWarning			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, Target			NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, EffectiveDate		DATETIME
			, Defect			INT
			, ProductGrpDesc	NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, LineStatus		NVARCHAR(100) COLLATE DATABASE_DEFAULT
			, ProdDay			DATE
			, EntryOn			DATETIME
			, ResultOn			DATETIME
			, ModifiedOn		DATETIME
			, UserDesc			NVARCHAR(255)
			, Comment_Rtf		NVARCHAR(MAX))


-- --------------------------------------------------------------------------------------------------------------------
-- Variables table
-- --------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#VariablesFilter', 'U') IS NOT NULL  DROP TABLE #VariablesFilter; 
CREATE TABLE #VariablesFilter (VarId INT)

-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------
	--	EXEC [dbo].[spRptQDetail] 2, 7, '2018-04-01T08:00:00','2018-07-01T08:00:00',null,null
		
	 -- SELECT  
		-- @prodLineId	= null
		--,@timeOption	= 1
		--,@dtmStartDate	= '2019-08-24T06:00:00'
		--,@dtmEndDate	= '2019-08-27T06:00:00'
		--,@ProcessOrder	= '000000613994'--'000900000521'
		--,@Product		= '80316163'
		--,@variableId	= '76016,60084,76017,76018,76019,76020'
		--,@variableId	= ''
			
-- --------------------------------------------------------------------------------------------------------------------
-- Get Start time & End time
-- --------------------------------------------------------------------------------------------------------------------
--SELECT @strTimeOption = DateDesc FROM [dbo].[DATE_DIMENSION] WHERE DateId = @timeOption

SELECT @strTimeOption = CASE @timeOption
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
							WHEN	12  THEN	'LastWeek'
						END

IF 	(@ProcessOrder IS NOT NULL AND @ProcessOrder <> '')
BEGIN

	SELECT	TOP 1 
			@strPLDesc = PLDesc,
			@prodLineId = PLId	
	FROM [OpsDB_Production_Data]
	WHERE ProcessOrder = @ProcessOrder

	SELECT @dtmStartDate = CASE
							WHEN @ProcessOrder IS NOT NULL
								THEN ( SELECT MIN(StartTime) 
										FROM [OpsDB_Production_Data]
										WHERE ProcessOrder = @ProcessOrder)
							END
	
	SELECT @dtmEndDate = CASE
							WHEN @ProcessOrder IS NOT NULL
								THEN ( SELECT MAX(EndTime) 
										FROM [OpsDB_Production_Data]
										WHERE ProcessOrder = @ProcessOrder)
							END
END
ELSE
BEGIN
	SELECT	TOP 1 @strPLDesc = LineDesc 
	FROM [dbo].[LINE_DIMENSION] (NOLOCK)
	WHERE	PLId = @prodLineId

	IF @TimeOption IS NOT NULL
	BEGIN
		SELECT	@dtmStartDate = dtmStartTime,
				@dtmEndDate = dtmEndTime
		FROM gbdb.[dbo].[fnLocal_RptStartEndTime](@strTimeOption)
	
		-- INSERT INTO	@tblTimeOption 
		-- EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @prodLineId

		-- SELECT		@dtmStartDate = startDate, @dtmEndDate = endDate FROM @tblTimeOption
	END
END

-- --------------------------------------------------------------------------------------------------------------------
-- Split Variables 
-- --------------------------------------------------------------------------------------------------------------------
IF @variableId IS NOT NULL AND RTRIM(LTRIM(@variableId)) <> ''
BEGIN
	INSERT INTO #VariablesFilter (VarId)
	SELECT 	
		RTRIM(LTRIM(plit.String))
	FROM dbo.fnLocal_Split(@variableId,',') plit

	PRINT CONVERT(NVARCHAR,@@ROWCOUNT) + ' variables in array parameter';
END ELSE BEGIN
	PRINT 'variableId array empty';
END

-- --------------------------------------------------------------------------------------------------------------------
-- Result set 1. Report Data
-- --------------------------------------------------------------------------------------------------------------------
SELECT	
		  @prodLineId							AS 'PLID'
		, @strPLDesc							AS 'PLDesc'
		, @strTimeOption						AS 'TimeOption'
		, CONVERT(smalldatetime, @dtmStartDate)	AS 'StartTime'
		, CONVERT(smalldatetime, @dtmEndDate)	AS 'EndTime'


-- --------------------------------------------------------------------------------------------------------------------
-- Result set 2. Detail Grid
-- --------------------------------------------------------------------------------------------------------------------
IF (@ProcessOrder IS NULL OR @ProcessOrder = '') AND @prodLineId IS NOT NULL
BEGIN
			INSERT INTO #FinalOutput (	
						  DataType	
						, VarId
						, VarDesc_Chart	
						, ResultInt		
						, PUId			
						, PUDesc			
						, PLId
						, PLDesc	
						, ProdId		
						, ProdCode		
						, ProcessOrder	
						, ProdDesc		
						, Result		
						, LReject		
						, UReject		
						, LWarning		
						, UWarning		
						, Target		
						, EffectiveDate	
						, Defect		
						, ProductGrpDesc
						, LineStatus	
						, ProdDay		
						, EntryOn		
						, ResultOn		
						, ModifiedOn
						, UserDesc
						, Comment_Rtf)
			SELECT		v.DataType,
						v.VarId,
						  CASE RTRIM(LTRIM(v.DataType)) 
						  WHEN 'VARIABLE' THEN '1' 
										  ELSE '0' 
						  END + '|' + v.VarDesc					
						, CASE 
						  WHEN RTRIM(LTRIM(v.DataType)) = 'VARIABLE' AND ISNUMERIC(Result) = 1 THEN  Result ELSE NULL END
						, PUId
						, PUDesc
						, @prodLineId
						, @strPLDesc
						, ProdId
						, ProdCode
						, ProcessOrder
						, ProdDesc
						, Result
						, LReject
						, UReject
						, LWarning
						, UWarning
						, Target
						, v.EffectiveDate
						, Defect
						, ProductGrpDesc
						, LineStatus
						, ProdDay
						, EntryOn
						, ResultOn
						, v.ModifiedOn
						, UserDesc
						, Comment_Rtf
			FROM	[dbo].[OpsDB_VariablesTasks_RawData]	v		(NOLOCK) 
			JOIN	[dbo].[FACT_UDPs]						fudp	(NOLOCK) ON v.VarId = fudp.VarId
			JOIN	[dbo].[UDP_DIMENSION]					dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
			WHERE	PLId	  = @prodLineId
				AND	ResultOn >= @dtmStartDate
				AND	ResultOn <= @dtmEndDate
				AND UDPName = 'Task Type'
				AND Value = 'QA'
				AND fudp.EffectiveDate < ResultOn
				AND (fudp.ExpirationDate > ResultOn OR fudp.ExpirationDate IS NULL)
				AND (@ProcessOrder IS NULL OR @ProcessOrder = '' OR ProcessOrder = @ProcessOrder)
				AND (@Product IS NULL OR @Product = '' OR ProdCode = @Product)
END
ELSE
BEGIN
			INSERT INTO #FinalOutput (	
						  DataType
						, v.VarId
						, VarDesc_Chart	
						, ResultInt		
						, PUId			
						, PUDesc		
						, PLId
						, PLDesc
						, ProdId		
						, ProdCode		
						, ProcessOrder	
						, ProdDesc		
						, Result		
						, LReject		
						, UReject		
						, LWarning		
						, UWarning		
						, Target		
						, EffectiveDate	
						, Defect		
						, ProductGrpDesc
						, LineStatus	
						, ProdDay		
						, EntryOn		
						, ResultOn		
						, ModifiedOn
						, UserDesc
						, Comment_Rtf)
				SELECT  v.DataType,
						v.VarId,
						  CASE RTRIM(LTRIM(v.DataType)) 
						  WHEN 'VARIABLE' THEN '1' 
										  ELSE '0' 
						  END + '|' + v.VarDesc			
						, CASE 
						  WHEN RTRIM(LTRIM(v.DataType)) = 'VARIABLE' AND ISNUMERIC(Result) = 1 THEN  Result ELSE NULL END
						, PUId
						, PUDesc
						, @prodLineId
						, @strPLDesc
						, ProdId
						, ProdCode
						, ProcessOrder
						, ProdDesc
						, Result
						, LReject
						, UReject
						, LWarning
						, UWarning
						, Target
						, v.EffectiveDate
						, Defect
						, ProductGrpDesc
						, LineStatus
						, ProdDay
						, EntryOn
						, ResultOn
						, v.ModifiedOn
						, UserDesc
						, Comment_Rtf
			FROM	[dbo].[OpsDB_VariablesTasks_RawData]	v		(NOLOCK) 
			JOIN	[dbo].[FACT_UDPs]						fudp	(NOLOCK) ON v.VarId = fudp.VarId
			JOIN	[dbo].[UDP_DIMENSION]					dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
			WHERE	PLId = @prodLineId
				AND ProcessOrder = @ProcessOrder
				AND UDPName = 'Task Type'
				AND Value = 'QA'
				AND fudp.EffectiveDate < ResultOn
				AND (fudp.ExpirationDate > ResultOn OR fudp.ExpirationDate IS NULL)
END

	
	UPDATE final
	SET final.PLDesc = ISNULL(final.PLDesc + ' (' + elpd.PM + ')',final.PLDesc)
	FROM #FinalOutput final
	JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON final.PLId = ld.PLId AND ld.PlatformId LIKE 'Converting'
	JOIN [dbo].[OpsDB_ELP_Data] elpd
	ON elpd.ProdCode = final.ProdCode
	AND elpd.PLId = final.PLId
	AND final.ResultOn >= elpd.PRConvStartTime
	AND final.ResultOn <= elpd.PRConvEndTime
	AND elpd.PM NOT LIKE 'NoAssignedPRID'

--Output SELECT
SELECT 
	--'filter'=vf.VarId, 
	fo.* 
FROM #FinalOutput fo 
LEFT JOIN #VariablesFilter vf ON fo.VarId = vf.VarId
WHERE (@variableId IS NULL OR RTRIM(LTRIM(@variableId)) = '' OR vf.VarId IS NOT NULL)


--SELECT * FROM #VariablesFilter 
-----------------------------------------------------------------------------------------------------------------
-- ResultSet 2: Start and End Time
SELECT @dtmStartDate	'StartDate'	,
	   @dtmEndDate		'EndDate'
-----------------------------------------------------------------------------------------------------------------
DROP TABLE #FinalOutput
DROP TABLE #VariablesFilter

GO
GRANT EXECUTE ON [dbo].[spRptQDetail] TO OpDBWriter
GO
