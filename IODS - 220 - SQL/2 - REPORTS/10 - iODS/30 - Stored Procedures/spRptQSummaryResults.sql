USE [Auto_opsDataStore]
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20)

SELECT
		@SP_Name	= 'spRptQSummaryResults',
		@Inputs		= 5, 
		@Version	= '1.7'  

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
				
DROP PROCEDURE [dbo].[spRptQSummaryResults]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-----------------------------------------------------------------------------------------------------------------
-- Quality Results Summary Report
--
-- 2017-5-3		Fernando Rio						Arido Software
-----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
--  Results:
------------
--
--  ResultSet 1: Report Groupings
---------------------------------
--  1. Process Order
--  2. Product
--  3. None
--	Report Output KPIs:
-----------------------
--	1. #Of Tests
--  2. #Of In Specs
--  3. #Of OOS
--  4. #Of Missing
--  5. #Of Alarms
--	6. #Of Open Alarms
--  7. #Of Closed Alarms
--  8. Overall% Completion
--  9. Overall% Compliance
--
--  Resultset 6: Process Order Status
---------------------------------
--  1. Reassuring Testing
--  2. Status: (FAIL / PASS / Incomplete - FAIL / Incomplete - PASS)
----------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
-- EDIT HISTORY: 
--------------------------------------------------------------------------------------------------
-- ========		====	  		====					=====
-- 1.0			2018-03-05		Martin Casalis			Initial Release
-- 1.1			2019-08-01		Damian Campana			Change function to get the Start and End time
-- 1.2			2019-08-02		Damian Campana			Add global parameters Trimm Downtimes (min)
-- 1.3			2019-08-28		Damian Campana			Capability to filter with the time option 'Last Week'
-- 1.4			2019-09-24		Gustavo Conde			Add PO, Product and Batch lists to output
-- 1.5			2019-10-24		Damian Campana			Include alarms variables "_AL"
-- 1.6			2019-11-25		Martin Casalis			Fixed ProdDesc and ProdCode when there is not products
--														Increased the length of ProcessOrderList, ProductList and BatchList fields
-- 1.7			2020-02-04		Gonzalo Luc				Fix LEN when value (batch/po) is null or empty.
--================================================================================================
--------------------------------------------------------------------------------------------------

------------------------------------------[Creation Of SP]------------------------------------------
CREATE PROCEDURE [dbo].[spRptQSummaryResults]
-- EXEC spRptQSummaryResults 'TUBR006','2018-01-01 00:00:00','2018-01-16 00:00:00','ProcessOrder',0
--DECLARE
				@LineDesc			NVARCHAR(200)	= NULL		,
				@TimeOption			INT				= NULL		,
				@dtmStartDate		DATETIME		= NULL		,
				@dtmEndDate			DATETIME		= NULL		,
				@strGroupBy			NVARCHAR(100)				,
				@ProcessOrder		NVARCHAR(100)	= NULL		,
				@Product			NVARCHAR(100)	= NULL		,
				@ExcludeNPT			BIT				= NULL		,
				@TrimmDowntimesMin	INT				= NULL

--WITH ENCRYPTION 
AS

--SET STATISTICS IO ON;
--SET STATISTICS TIME ON;
-----------------------------------------------------------------------------------------------------------------
-- Tables Declaration
-----------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#prodRelVarId', 'U') IS NOT NULL  DROP TABLE #prodRelVarId; 
CREATE TABLE #prodRelVarId (	
				PLId					INT					,
				VarId					INT					,
				ProductRelease			NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				EffectiveDate			DATETIME			,
				ExpirationDate			DATETIME			,
				PrimaryQFactor			NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				QFactorType				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	)

IF OBJECT_ID('tempdb.dbo.#tmpQASummaryRpt', 'U') IS NOT NULL  DROP TABLE #tmpQASummaryRpt; 
CREATE TABLE #tmpQASummaryRpt
			(	RcdIdx					INT					,
				PLId					INT					,
				PLDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUGDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUId					INT					,
				PUDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				ProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdCode				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT	,
				BatchNumber				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				VarId					INT					,
				VarDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				ResultOn				DATETIME			,
				DisplayName				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				EntryOn					DATETIME			,
				EntryBy					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				Result					NVARCHAR(50)	COLLATE DATABASE_DEFAULT	,
				Defect					INT					,
				VarType					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				HSEFlag					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				IsTestComplete			NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PrimaryQFactor			NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				QFactorType				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				TaskType				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				VariableCategory		NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				StubberUser				INT					,			-- 0: Resample,	1: Normal Sampling
				Canceled				INT					,
				ExcludedFromDT			BIT		DEFAULT 0	,
				TrimmByLine				BIT		DEFAULT 0	)

IF OBJECT_ID('tempdb.dbo.#tmpAlarms', 'U') IS NOT NULL  DROP TABLE #tmpAlarms; 
CREATE TABLE #tmpAlarms 
			(	RcdIdx					INT					,
				VarId					INT					,
				VarDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				StartDate				DATETIME			,
				EndDate					DATETIME			,
				PUId					INT					,
				PLDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				ProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				StartProcessOrder		NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				EndProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdCode				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT	,
				OpenAlarm				BIT					)
				
IF OBJECT_ID('tempdb.dbo.#Production', 'U') IS NOT NULL  DROP TABLE #Production; 
CREATE TABLE  #Production (
				RcdIdx					INT					,				
				PLId					INT					,
				PLDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				ProdId					INT					,
				ProdCode				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT	,
				ProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				BatchNumber				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				LineStatus				NVARCHAR(50)	COLLATE DATABASE_DEFAULT	,
				StartTime				DATETIME			, 
				EndTime					DATETIME			)

IF OBJECT_ID('tempdb.dbo.#ProductionPlan', 'U') IS NOT NULL  DROP TABLE #ProductionPlan; 
CREATE TABLE  #ProductionPlan (
				ProdId					INT					,
				ProdCode				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT	,
				ProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				BatchNumber				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				StartTime				DATETIME			, 
				EndTime					DATETIME			)

IF OBJECT_ID('tempdb.dbo.#Downtimes', 'U') IS NOT NULL  DROP TABLE #Downtimes; 
CREATE TABLE  #Downtimes (
				TEDetId					INT					,
				PLId					INT					,
				PUId					INT					,
				IsConstraint			INT					,
				StartTime				DATETIME			, 
				EndTime					DATETIME			,
				Duration				FLOAT				)

DECLARE @tmpMajorGroup	TABLE (
				MajorGroupName			NVARCHAR(200)		,
				MajorGroupDesc			NVARCHAR(200)		,
				ProdCode				NVARCHAR(100)		,
				ProdDesc				NVARCHAR(255)		,
				BatchNumber				NVARCHAR(200)		,
				StartTime				DATETIME			,
				EndTime					DATETIME			,
				NumOfTests				INT					,
				NumOfTestsPlanned		INT					,
				NumTestsInSpec			INT					,
				NumOfOOS				INT					,
				NumOfMissing			INT					,
				NumOfAlarms				INT					,
				NumOfOpenAlarm			INT					,
				NumOfCloseAlarm			INT					,
				TAMUTotal				INT					,
				TAMUTotalUnpl			INT					,
				TAMUPerCompletion		FLOAT				,
				TAMUPerCompliance		FLOAT				,
				QFactorTotal			INT					,
				QFactorTotalPlanned		INT					,
				QFactorCompletion		FLOAT				,
				QFactorCompliance		FLOAT				,
				ProcessOrderList		NVARCHAR(MAX)		,
				ProductList				NVARCHAR(MAX)		,
				BatchList				NVARCHAR(MAX)		)

DECLARE @tblTimeOption	TABLE (
				startDate				DATETIME			, 
				endDate					DATETIME			)

DECLARE @PUGExcluded TABLE(
				RcdIdx					INT					,
				PUGDesc					NVARCHAR(200)		)
-----------------------------------------------------------------------------------------------------------------
-- Variables Declaration
-----------------------------------------------------------------------------------------------------------------
DECLARE
				@prodLineId				INT				,
				@prodCode				NVARCHAR(150)	,
				@prodDesc				NVARCHAR(150)	,
				@UDPProductRelease		NVARCHAR(150)	,
				@UDPHSEFlag				NVARCHAR(150)	,
				@UDPIsTestComplete		NVARCHAR(150)	,
				@UDPPrimaryQFactor		NVARCHAR(150)	,
				@UDPQFactorType			NVARCHAR(150)	,
				@UDPTaskType			NVARCHAR(150)	,
				@UDPVariableCategory	NVARCHAR(150)	,
				@MinPOTime				DATETIME		,
				@MaxPOTime				DATETIME		,
				@strTimeOption			NVARCHAR(100)	,
				@in_StartDate			DATETIME		,
				@in_EndDate				DATETIME		,
				@StartDate				DATETIME		,
				@EndDate				DATETIME		,
				@HourInterval			INT				,
				@RptNegMin				INT				,
				@ReportName				NVARCHAR(100)	,
				@HourIntervalName		NVARCHAR(100)	,
				@RptNegMinName			NVARCHAR(100)	,
				@ExcludedFromDTName		NVARCHAR(100)	,
				@PUGExcludedFromDT		NVARCHAR(4000)	,
				@Runtime				DATETIME		,
				@processOrderList		NVARCHAR(MAX)	,
				@productList			NVARCHAR(MAX)	,
				@batchList				NVARCHAR(MAX)	
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
---- Test Section 
--SELECT			
--				@LineDesc		=	'QPAZ201',--'PE30-L054',	--'DIMR110',	--	null,	--	'PQ Conv-L00',	--
--				@TimeOption		=	null,
--				@dtmStartDate	=	'2020-02-03 00:00:00',
--				@dtmEndDate		=	'2020-02-04 00:00:00',
--				@strGroupBy		=	'Product',
--				@ProcessOrder	=	'',
--				@Product		=	'',
--				@ExcludeNPT		=	0 ,
--				@TrimmDowntimesMin = 0
		
----exec spRptQSummaryResults null,null,null,null,'ProcessOrder','000900000249',null
-----------------------------------------------------------------------------------------------------------------
--=====================================================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'SP START ' + CONVERT(VARCHAR(50), GETDATE(), 121)
PRINT '-----------------------------------------------------------------------------------------------------------------------'
-----------------------------------------------------------------------------------------------------------------
-- UDP text values and Constants values
-----------------------------------------------------------------------------------------------------------------
SET @UDPProductRelease		= 'ProductRelease'
SET @UDPPrimaryQFactor		= 'Primary Q-Factor?'
SET @UDPQFactorType			= 'Q-Factor Type'
SET @UDPTaskType			= 'Task Type'

SET @ReportName				= 'Q Summary Report'
SET @HourIntervalName		= '@HourInterval'
SET @RptNegMinName			= '@RptNegMin'
SET @ExcludedFromDTName		= '@PUGExcludedFromDT'


-- Get Report Parameters
-------------------------------------------------------------------------------------------------
SELECT @HourInterval		= [dbo].[fnRptGetParameterValue] (@ReportName,@HourIntervalName)
SELECT @PUGExcludedFromDT	= [dbo].[fnRptGetParameterValue] (@ReportName,@ExcludedFromDTName)
--SELECT @RptNegMin			= [dbo].[fnRptGetParameterValue] (@ReportName,@RptNegMinName)
SELECT @RptNegMin			= @TrimmDowntimesMin 

-- Get PUG to be excluded from Downtime Trimm
-------------------------------------------------------------------------------------------------
INSERT INTO @PUGExcluded(RcdIdx,PUGDesc)
SELECT Id, String FROM [dbo].[fnLocal_Split](@PUGExcludedFromDT,',')

-- --------------------------------------------------------------------------------------------------------------------
-- Get Start time & End time
-- --------------------------------------------------------------------------------------------------------------------
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
	
SELECT @prodLineId = PLId
FROM [dbo].[LINE_DIMENSION] (NOLOCK)
WHERE LineDesc = @LineDesc
			
IF 	(@ProcessOrder IS NOT NULL AND @ProcessOrder <> '')
BEGIN		
		-- Get Production Data
		----------------------------------------------------------------------------------------------------------------------
		INSERT INTO #Production(
					RcdIdx			,
					pd.PLId			,
					PLDesc			,
					ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder	,
					BatchNumber		,
					LineStatus		,
					StartTime		,
					EndTime			)
		SELECT		
					RcdIdx			,
					pd.PLId			,
					PLDesc			,
					ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder	,
					BatchNumber		,
					LineStatus		,
					StartTime		,
					EndTime	
		FROM [dbo].[OpsDB_Production_Data]	pd (NOLOCK)
		JOIN [dbo].[WorkCell_Dimension]		wd (NOLOCK)	ON pd.PUID = wd.PUId
		WHERE ProcessOrder = @ProcessOrder
		AND DeleteFlag <> 1
		AND Class = 1
		
		SELECT	@dtmStartDate = MIN(StartTime) ,
				@dtmEndDate = MAX(EndTime) 
		FROM #Production (NOLOCK)
																
		-- Get Line Id and Line Desc if a PO is selected
		----------------------------------------------------------------------------------------------------------------------
		IF (@LineDesc = '' OR @LineDesc IS NULL)
		BEGIN	
			SELECT	TOP 1	@LineDesc = PLDesc, 
							@prodLineId = PLId
			FROM #Production (NOLOCK)
		END

		SET @strGroupBy = 'ProcessOrder'
END
ELSE
BEGIN
		IF @strTimeOption IS NOT NULL
		BEGIN
			SELECT	@dtmStartDate = dtmStartTime,
					@dtmEndDate = dtmEndTime
			FROM gbdb.[dbo].[fnLocal_RptStartEndTime](@strTimeOption)
		
			--INSERT INTO	@tblTimeOption 
			--EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @prodLineId
			
			--SELECT	@dtmStartDate = startDate, @dtmEndDate = endDate FROM @tblTimeOption
		END

		-- Get Production Data
		----------------------------------------------------------------------------------------------------------------------
		INSERT INTO #Production(
					RcdIdx			,
					pd.PLId			,
					PLDesc			,
					ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder	,
					BatchNumber		,
					LineStatus		,
					StartTime		,
					EndTime			)
		SELECT		
					RcdIdx			,
					pd.PLId			,
					PLDesc			,
					ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder	,
					BatchNumber		,
					LineStatus		,
					StartTime		,
					EndTime			
		FROM [dbo].[OpsDB_Production_Data]	pd (NOLOCK)
		JOIN [dbo].[WorkCell_Dimension]		wd (NOLOCK)	ON pd.PUID = wd.PUId
		WHERE pd.PLId = @prodLineId
		AND StartTime <= @dtmEndDate
		AND (EndTime > @dtmStartDate OR EndTime IS NULL)
		AND DeleteFlag <> 1
		AND Class = 1
END

SELECT	@prodCode = ProdCode	,
		@prodDesc = ProdDesc
FROM #Production (NOLOCK)
WHERE (ProdCode = @Product
OR ProcessOrder = @ProcessOrder)

IF (@Product IS NOT NULL AND @Product <> '') DELETE FROM #Production WHERE ProdCode <> @Product


-- Expansion time when group by PO
-------------------------------------------------------------------------------------------------
IF @strGroupBy = 'ProcessOrder'
BEGIN
		SET @in_StartDate = @dtmStartDate
		SET @in_EndDate = @dtmEndDate

		INSERT INTO #ProductionPlan(
					ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder	,
					StartTime		,
					EndTime			)
		SELECT		
					ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder	,
					MIN(StartTime)	,
					MAX(EndTime)		
		FROM #Production (NOLOCK)
		WHERE PLDesc = @LineDesc
		AND StartTime <= @dtmEndDate
		AND (EndTime > @dtmStartDate OR EndTime IS NULL)
		GROUP BY	ProdId			,
					ProdCode		,
					ProdDesc		,
					ProcessOrder

		SET @HourInterval = ISNULL(@HourInterval,0)
		 
		SELECT @MinPOTime = MIN(StartTime) FROM #ProductionPlan (NOLOCK)

		SET @MinPOTime = CASE WHEN @MinPOTime > @dtmStartDate
								THEN @dtmStartDate
								ELSE @MinPOTime
								END

		SELECT @MaxPOTime = MAX(EndTime) FROM #ProductionPlan (NOLOCK)

		SET @MaxPOTime = CASE WHEN @MaxPOTime < @dtmEndDate
								THEN @dtmEndDate
								ELSE @MaxPOTime
								END
	
		SET @dtmStartDate = CASE WHEN @MinPOTime <= DATEADD(hh,-1 * @HourInterval,@dtmStartDate) 
								THEN DATEADD(hh,-1 * @HourInterval,@dtmStartDate)
								ELSE @MinPOTime
								END
	
		SET @dtmEndDate = CASE WHEN @MaxPOTime >= DATEADD(hh,1 * @HourInterval,@dtmEndDate) 
								THEN DATEADD(hh,1 * @HourInterval,@dtmEndDate) 
								ELSE @MaxPOTime
								END

END

UPDATE #Production
	SET	StartTime = CASE WHEN StartTime < @dtmStartDate THEN @dtmStartDate ELSE StartTime END	,
		EndTime = CASE WHEN EndTime > @dtmEndDate THEN @dtmEndDate ELSE EndTime END		
--=====================================================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'GET VARIABLES ' + CONVERT(VARCHAR(50), GETDATE(), 121)
PRINT '-----------------------------------------------------------------------------------------------------------------------'

-- Get all variables flagged as Release
-------------------------------------------------------------------------------------------------
INSERT INTO #prodRelVarId (
		PLId				,
		VarId				,
		ProductRelease		,
		EffectiveDate		,
		ExpirationDate		)	
SELECT	DISTINCT 
		@prodLineId			,
		fudp.VarId			,
		1					,
		fudp.EffectiveDate	,
		fudp.ExpirationDate	
FROM [dbo].[FACT_UDPs]						fudp	(NOLOCK) 
JOIN [dbo].[UDP_DIMENSION]					dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
WHERE	UDPName = @UDPProductRelease
	AND Value = '1'
	AND fudp.EffectiveDate < @dtmEndDate
	AND (fudp.ExpirationDate > @dtmStartDate OR fudp.ExpirationDate IS NULL)


-- Get values from other UDPs
-------------------------------------------------------------------------------------------------

UPDATE v
	SET PrimaryQFactor = (SELECT TOP 1 Value
					FROM dbo.FACT_UDPs		fudp	(NOLOCK)
					JOIN dbo.UDP_DIMENSION	dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
					WHERE	v.VarId = fudp.VarId
						AND dudp.UDPName = @UDPPrimaryQFactor
						AND EffectiveDate < @dtmEndDate
						AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
					ORDER BY EffectiveDate DESC)
FROM #prodRelVarId	v

UPDATE v
	SET QFactorType = (SELECT TOP 1 Value
					FROM dbo.FACT_UDPs		fudp	(NOLOCK)
					JOIN dbo.UDP_DIMENSION	dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
					WHERE	v.VarId = fudp.VarId
						AND dudp.UDPName = @UDPQFactorType
						AND EffectiveDate < @dtmEndDate
						AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
					ORDER BY EffectiveDate DESC)
FROM #prodRelVarId	v

--=====================================================================================================================
PRINT 'GET DATA ' + CONVERT(VARCHAR(50), GETDATE(), 121)
PRINT '-----------------------------------------------------------------------------------------------------------------------'
-------------------------------------------------------------------------------------------------
-- Get data for variables flagged as release
-------------------------------------------------------------------------------------------------

INSERT INTO #tmpQASummaryRpt (		
				RcdIdx					,
				PLId					,
				PLDesc					,
				PUId					,
				PUDesc					,
				PUGDesc					,
				ProcessOrder			,
				ProdCode				,
				ProdDesc				,
				VarId					,
				VarDesc					,
				DisplayName				,
				EntryOn					,
				EntryBy					,
				ResultOn				,
				Result					,
				Defect					,
				VarType					,
				PrimaryQFactor			,
				QFactorType				,
				StubberUser				,
				Canceled				)
SELECT			DISTINCT
				RcdIdx					,
				iodsqa.PLId				,
				PLDesc					,
				iodsqa.PUId				,
				PUDesc					,
				PUGDesc					,
				ISNULL(ProcessOrder,'No PO')	,
				ISNULL(ProdCode,'No Prod')		,
				ProdDesc				,
				pr.VarId					,
				VarDesc				,
				ISNULL(SheetDesc,'No Display')	,
				EntryOn				,
				UserDesc				,
				ResultOn				,
				Result					,
				Defect					,
				DataType				,
				PrimaryQFactor			,
				QFactorType				,
				StubberUser				,
				Canceled
FROM [dbo].[OpsDB_VariablesTasks_RawData]	iodsqa	(NOLOCK)
JOIN #prodRelVarId							pr		(NOLOCK)
													ON iodsqa.PLId = pr.PLId	
													AND iodsqa.VarId = pr.VarId	
													AND pr.ProductRelease = 1		
													AND ResultOn >= pr.EffectiveDate
													AND (ResultOn <= pr.ExpirationDate OR pr.ExpirationDate IS NULL)
WHERE	(ResultOn >= @dtmStartDate  
		AND ResultOn < @dtmEndDate
		AND (@Product IS NULL OR @Product = '' OR ISNULL(ProdCode,'No Prod') = @Product))
	
-- Add tests for SCO units where the PO starts doesn't match with Production	
IF (@ProcessOrder IS NOT NULL AND @ProcessOrder <> '')
BEGIN
	SELECT @processOrderList = @ProcessOrder;

	INSERT INTO #tmpQASummaryRpt (		
					RcdIdx					,
					PLId					,
					PLDesc					,
					PUId					,
					PUDesc					,
					PUGDesc					,
					ProcessOrder			,
					ProdCode				,
					ProdDesc				,
					VarId					,
					VarDesc					,
					DisplayName				,
					EntryOn					,
					EntryBy					,
					ResultOn				,
					Result					,
					Defect					,
					VarType					,
					PrimaryQFactor			,
					QFactorType				,
					StubberUser				,
					Canceled				)
	SELECT			
					RcdIdx					,
					iodsqa.PLId				,
					PLDesc					,
					iodsqa.PUId				,
					PUDesc					,
					PUGDesc					,
					ISNULL(ProcessOrder,'No PO')	,
					ISNULL(ProdCode,'No Prod')		,
					ProdDesc				,
					pr.VarId					,
					VarDesc				,
					ISNULL(SheetDesc,'No Display')	,
					EntryOn				,
					UserDesc				,
					ResultOn				,
					Result					,
					Defect					,
					DataType				,
					PrimaryQFactor			,
					QFactorType				,
					StubberUser				,
					Canceled
	FROM [dbo].[OpsDB_VariablesTasks_RawData]	iodsqa	(NOLOCK)
	JOIN #prodRelVarId							pr		(NOLOCK)
														ON iodsqa.VarId = pr.VarId
														AND iodsqa.PLId = pr.PLId	
														AND pr.ProductRelease = 1		
														AND ResultOn >= pr.EffectiveDate
														AND (ResultOn <= pr.ExpirationDate OR pr.ExpirationDate IS NULL)
	WHERE	ISNULL(ProcessOrder,'No PO') = @ProcessOrder
	AND RcdIdx NOT IN (SELECT RcdIdx FROM #tmpQASummaryRpt)
	
END
--=====================================================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'GET ALARMS ' + CONVERT(VARCHAR(50), GETDATE(), 121) + ' - ' + CONVERT(NVARCHAR,DATEDIFF(mi,@Runtime,GETDATE()))
PRINT '-----------------------------------------------------------------------------------------------------------------------'
SET @Runtime = CONVERT(VARCHAR(50), GETDATE(), 121)
--
INSERT INTO #tmpAlarms (
				RcdIdx					,
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				--PUId					,
				PLDesc					,
				PUDesc					,
				--ProcessOrder			,
				StartProcessOrder		,
				ProdCode				,
				ProdDesc				,
				OpenAlarm				)
SELECT			
				RcdIdx					,
				pr.VarId				,
				VarDesc					,
				StartTime				,
				EndTime					,
				--PUId					,
				PLDesc					,
				PUDesc					,
				ISNULL(ProcessOrder,'No PO')	,
				ISNULL(ProdCode,'No Prod')		,
				ProdDesc				,
				CASE WHEN EndTime > @in_EndDate and EndTime > @dtmEndDate  THEN 1 ELSE 0 END
FROM dbo.OpsDB_Alarms_RawData	iodsal	(NOLOCK)
JOIN #prodRelVarId				pr		(NOLOCK) ON iodsal.VarId = pr.VarId	 OR iodsal.SourceVarId = pr.VarId
WHERE PLDesc = @LineDesc 
	AND StartTime < @dtmEndDate
	AND ( EndTime >= @dtmStartDate OR EndTime IS NULL )
	AND DeleteFlag <> 1
ORDER BY StartTime

IF (@ProcessOrder IS NOT NULL AND @ProcessOrder <> '')
BEGIN
	INSERT INTO #tmpAlarms (
					RcdIdx					
					,VarId					
					,VarDesc				
					,StartDate				
					,EndDate				
					--PUId					
					,PLDesc					
					,PUDesc					
					,StartProcessOrder		
					,ProdCode				
					,ProdDesc				
					,OpenAlarm				)
	SELECT			
					iodsal.RcdIdx
					,iodsal.VarId	
					,iodsal.VarDesc	
					,iodsal.StartTime
					,iodsal.EndTime	
					--pr.PUId			
					,iodsal.PLDesc	
					,iodsal.PUDesc
					,ISNULL(iodsal.ProcessOrder,'No PO')
					,ISNULL(iodsal.ProdCode,'No Prod')
					,iodsal.ProdDesc
					,CASE WHEN iodsal.EndTime > @in_EndDate and iodsal.EndTime > @dtmEndDate  THEN 1 ELSE 0 END
	FROM dbo.OpsDB_Alarms_RawData		iodsal	(NOLOCK)
	JOIN #prodRelVarId					pr		(NOLOCK)	ON iodsal.VarId = pr.VarId OR iodsal.SourceVarId = pr.VarId
	JOIN #tmpQASummaryRpt				v		(NOLOCK)	ON iodsal.VarId = v.VarId OR iodsal.SourceVarId = v.VarId
															AND v.ProcessOrder = @ProcessOrder
															AND iodsal.EndTime IS NOT NULL
															AND (iodsal.EndTime = v.ResultOn
																OR iodsal.EndTime BETWEEN DATEADD(ss,-1,v.ResultOn) AND DATEADD(ss,1,v.ResultOn))
	WHERE iodsal.PLDesc = @LineDesc 
	AND iodsal.RcdIdx NOT IN(SELECT RcdIdx FROM #tmpAlarms (NOLOCK))
	AND DeleteFlag <> 1
	ORDER BY iodsal.StartTime
END

-- Alarms closed on next PO
UPDATE a
	SET EndProcessOrder = pd.ProcessOrder
FROM #tmpAlarms					a	
JOIN [OpsDB_Production_Data]	pd	(NOLOCK) ON a.PLDesc = pd.PLDesc
WHERE a.EndDate IS NOT NULL
	AND pd.StartTime < a.EndDate
	AND ( a.EndDate <= pd.EndTime OR pd.EndTime IS NULL )

UPDATE a
	SET EndProcessOrder = t.ProcessOrder
FROM #tmpAlarms				a
JOIN #tmpQASummaryRpt		t (NOLOCK) ON a.VarId = t.VarId
WHERE	a.EndProcessOrder IS NULL 
	AND a.EndDate IS NOT NULL
	AND (a.EndDate = t.ResultOn
		OR a.EndDate BETWEEN DATEADD(ss,-1,t.ResultOn) AND DATEADD(ss,1,t.ResultOn))


UPDATE #tmpAlarms
	SET OpenAlarm = 1
WHERE OpenAlarm = 0
AND EndDate IS NOT NULL
AND StartProcessOrder <> EndProcessOrder


IF EXISTS( SELECT * FROM #Production (NOLOCK)) AND (@Product IS NOT NULL AND @Product <> '')
BEGIN		
	DELETE #tmpAlarms
	WHERE RcdIdx NOT IN(
		SELECT a.RcdIdx
		FROM #tmpAlarms  a	(NOLOCK)
		JOIN #Production p	(NOLOCK)	ON	(a.EndDate IS NOT NULL
											AND a.EndDate > p.StartTime
											AND a.EndDate <= p.EndTime )
										OR ((a.EndDate IS NULL
											AND a.StartDate <= p.EndTime )
											OR OpenAlarm = 1))
END

-------------------------------------------------------------------------------------------------
-- Filter Line Status
-------------------------------------------------------------------------------------------------
IF @ExcludeNPT = 1
BEGIN
	DELETE #tmpQASummaryRpt
		FROM #tmpQASummaryRpt	s	(NOLOCK)
		JOIN #Production		p	(NOLOCK)	ON p.PLId = s.PLId
		WHERE ResultOn > p.StartTime 
		AND (ResultOn <= p.EndTime OR p.EndTime is NULL)
		AND LineStatus LIKE '%PR Out%'	
		AND PUGDesc NOT IN(SELECT PUGDesc FROM @PUGExcluded) 
END
-------------------------------------------------------------------------------------------------
-- Apply Trimm logic to exclude tests on downtimes
-------------------------------------------------------------------------------------------------
IF @RptNegMin IS NOT NULL OR @RptNegMin <> ''
BEGIN
	UPDATE #tmpQASummaryRpt
		SET TrimmByLine = 1
	WHERE PUId NOT IN(SELECT PUId FROM [dbo].[WorkCell_Dimension] (NOLOCK) WHERE IsActiveDowntime = 1) 

	
	UPDATE #tmpQASummaryRpt
		SET ExcludedFromDT = 1
	WHERE PUGDesc IN(SELECT PUGDesc FROM @PUGExcluded) 

	INSERT INTO #Downtimes(
				TEDetId			,
				PLId			,
				PUId			,
				IsConstraint	)
	SELECT		TEDetId			,
				PLId			,
				PUId			,
				IsContraint
	FROM [dbo].[OpsDB_DowntimeUptime_Data] (NOLOCK)
	WHERE StartTime < @dtmEndDate
	AND (EndTime > @dtmStartDate OR EndTime IS NULL)
	AND TEDetId <> 0
	AND DeleteFlag <> 1
	AND PLId = @prodLineId
	AND (IsContraint = 1
		OR PUId IN (SELECT PUId FROM #tmpQASummaryRpt (NOLOCK)))
	GROUP BY TEDetId,PLId,PUId,IsContraint

	UPDATE d
		SET StartTime	= (SELECT MIN(StartTime)
							FROM [OpsDB_DowntimeUptime_Data] o (NOLOCK)
							WHERE d.TEDetId = o.TEDetId),
			EndTime		= (SELECT MAX(EndTime)
							FROM [OpsDB_DowntimeUptime_Data] o (NOLOCK)
							WHERE d.TEDetId = o.TEDetId)
	FROM #Downtimes d

	UPDATE #Downtimes
		SET Duration = DATEDIFF(SECOND,StartTime,EndTime) / 60.0

	DELETE FROM #Downtimes WHERE Duration IS NOT NULL AND ( Duration < @RptNegMin OR Duration = 0 )
											
	DELETE #tmpQASummaryRpt
		FROM #tmpQASummaryRpt	s	(NOLOCK)
		  				-- We now have to do this backwards (x minutes after the stop and x minutes before the stop we need to watch out) 
		JOIN #Downtimes			d	(NOLOCK)	ON d.PUId = s.PUId
												AND d.PLId = s.PLId
			WHERE TrimmByLine = 0
			AND ExcludedFromDT = 0
			AND ResultOn > DateAdd(minute,@RptNegMin,d.StartTime) 
			AND (ResultOn <= DateAdd(minute,-@RptNegMin,d.EndTime) OR d.EndTime is NULL)

	IF EXISTS (SELECT * FROM #tmpQASummaryRpt t (NOLOCK) WHERE TrimmByLine = 1)
	BEGIN						
		DELETE #tmpQASummaryRpt
			FROM #tmpQASummaryRpt	s	(NOLOCK)
			JOIN #Downtimes			d	(NOLOCK)	ON d.PLID = s.PLId
													AND d.IsConstraint = 1
		  					-- We now have to do this backwards (x minutes after the stop and x minutes before the stop we need to watch out) 
				WHERE TrimmByLine = 1
				AND ExcludedFromDT = 0
				AND ResultOn > DateAdd(minute,@RptNegMin,d.StartTime) 
				AND (ResultOn <= DateAdd(minute,-@RptNegMin,d.EndTime) OR d.EndTime is NULL)
	END
END
--=====================================================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'BUILD GROUPINGS ' + CONVERT(VARCHAR(50), GETDATE(), 121)
PRINT '-----------------------------------------------------------------------------------------------------------------------'

IF @strGroupBy = 'ProcessOrder'
BEGIN
	INSERT INTO @tmpMajorGroup	( 				
				MajorGroupName			,
				MajorGroupDesc			,
				NumOfTests				,
				ProdCode				,
				ProdDesc				,
				BatchNumber				)
			
	--	Process Order - Line -  Unit - Variable Name -Variable Result - Result On - Display Name
	--  Total Tests
	SELECT 'ProcessOrder'	,
			ProcessOrder	,
			COUNT(*)		,
			'No Prod'		,
			'No Prod'		,
			'-'
	FROM #tmpQASummaryRpt (NOLOCK)
	GROUP BY 
			ProcessOrder

	-- Insert POs with no tests	
	IF (@ProcessOrder IS NULL OR @ProcessOrder = '')
	BEGIN
		INSERT INTO @tmpMajorGroup	( 				
					MajorGroupName	,
					MajorGroupDesc	,
					NumOfTests		,
					ProdCode		,
					ProdDesc		,
					BatchNumber		)
		SELECT		
					'ProcessOrder'	,
					ProcessOrder	,
					0				,
					ProdCode		,
					ProdDesc		,
					'-'
		FROM #ProductionPlan (NOLOCK)
		WHERE ProcessOrder NOT IN (SELECT MajorGroupDesc FROM @tmpMajorGroup) 
	END

	UPDATE mg
		SET ProdCode = tmp.ProdCode,
			ProdDesc = tmp.ProdDesc
	FROM @tmpMajorGroup		mg
	JOIN #tmpQASummaryRpt	tmp	(NOLOCK)	ON tmp.ProcessOrder = mg.MajorGroupDesc
	WHERE MajorGroupDesc <> 'No PO'
	
	UPDATE mg
		SET BatchNumber = p.BatchNumber
	FROM @tmpMajorGroup		mg
	JOIN #Production		p	(NOLOCK)	ON p.ProcessOrder = mg.MajorGroupDesc

	-------------------------------------------------------------------------------------------------
	--  KPI section
	-------------------------------------------------------------------------------------------------
	-- In Spec
	UPDATE tmp
		SET NumTestsInSpec = (SELECT COUNT(*) 
								FROM   #tmpQASummaryRpt (NOLOCK)
								WHERE  ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
									AND	Defect = 0
									AND Result IS NOT NULL)
	FROM   @tmpMajorGroup tmp

	-- OOS
	UPDATE tmp
		SET NumOfOOS = (SELECT COUNT(*) 
								FROM   #tmpQASummaryRpt (NOLOCK)
								WHERE  ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
									AND	Defect = 1
									AND Result IS NOT NULL)
	FROM   @tmpMajorGroup tmp

	-- Missing
	UPDATE tmp
		SET NumOfMissing = (SELECT COUNT(*) 
								FROM   #tmpQASummaryRpt (NOLOCK)
								WHERE  ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
								AND	(	(Result IS NULL	AND StubberUser = 1 AND Canceled = 0) 
									OR	(StubberUser = 1 AND Canceled = 1 AND EntryBy <> 'CalculationMgr' AND EntryBy NOT LIKE '%System%')))
	FROM   @tmpMajorGroup tmp		

	
	UPDATE @tmpMajorGroup
		SET NumOfTests = NumOfMissing + NumOfOOS + NumTestsInSpec
	
	-- Overall Section
	-------------------------------------------------------------------------------------------------
	UPDATE tmp
		SET TAMUPerCompletion = CONVERT(DECIMAL(10,2),(CONVERT(FLOAT,(NumOfTests - NumOfMissing)) / CONVERT(FLOAT,NumOfTests)) * 100.0)
	FROM   @tmpMajorGroup tmp
	WHERE NumOfTests > 0
	--
	-- Overall % Compliance Calculation
	UPDATE tmp
		SET TAMUPerCompliance = CONVERT(DECIMAL(10,2),(CONVERT(FLOAT,NumTestsInSpec) / CONVERT(FLOAT,NumOfTests)) * 100.0)
	FROM   @tmpMajorGroup tmp
	WHERE NumOfTests > 0
	
	-- QFactor Section
	-------------------------------------------------------------------------------------------------	
	-- QFactor Total
	UPDATE tmp
		SET QFactorTotal = (SELECT COUNT(*) 
										FROM	#tmpQASummaryRpt (NOLOCK)
										WHERE	ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
										AND		PrimaryQFactor = 'Yes') -
							(SELECT COUNT(*) 
										FROM	#tmpQASummaryRpt (NOLOCK)
										WHERE	ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
										AND		PrimaryQFactor = 'Yes'
										AND		StubberUser = 0
										AND		Result IS NULL)	
	FROM   @tmpMajorGroup tmp

	-- QFactor Total Unplanned
	UPDATE tmp
		SET QFactorTotalPlanned = QFactorTotal - (SELECT COUNT(*) 
													FROM   #tmpQASummaryRpt (NOLOCK)
													WHERE  ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
													AND    PrimaryQFactor = 'Yes'
													AND Result IS NULL)	
	FROM   @tmpMajorGroup tmp
	
	-- Overall % Completion
	UPDATE tmp
		SET QFactorCompletion = (SELECT COUNT(*) 
										FROM	#tmpQASummaryRpt (NOLOCK)
										WHERE	ISNULL(ProcessOrder,'NoPO') = tmp.MajorGroupDesc
										AND		PrimaryQFactor = 'Yes'
										AND	(	(Result IS NULL	AND StubberUser = 1 AND Canceled = 0) 
											OR	(StubberUser = 1 AND Canceled = 1 AND EntryBy <> 'CalculationMgr' AND EntryBy NOT LIKE '%System%')))
										--AND		Result IS NOT NULL
										--AND		StubberUser = 1)
	FROM   @tmpMajorGroup tmp
	
	-- Overall % Compliance
	UPDATE tmp
		SET QFactorCompliance = (SELECT COUNT(*) 
										FROM   #tmpQASummaryRpt (NOLOCK)
										WHERE  ISNULL(ProcessOrder,'No PO') = tmp.MajorGroupDesc
										AND    PrimaryQFactor = 'Yes'
										AND    Result IS NOT NULL
										AND    Defect = 0)
	FROM   @tmpMajorGroup tmp
		
	-- QFactor % Completion Calculation
	UPDATE tmp
		SET QFactorCompletion = CONVERT(DECIMAL(10,2),((QFactorTotal - QFactorCompletion) / QFactorTotal) * 100)
	FROM   @tmpMajorGroup tmp
	WHERE QFactorTotal > 0
	
	-- QFactor % Compliance Calculation
	UPDATE tmp
		SET QFactorCompliance = CONVERT(DECIMAL(10,2),(QFactorCompliance / QFactorTotal) * 100)
	FROM   @tmpMajorGroup tmp
	WHERE QFactorTotal > 0

	UPDATE  tmg
	SET StartTime = pp.StartTime,
		EndTime	  =	pp.EndTime
	FROM @tmpMajorGroup		tmg
	JOIN #ProductionPlan	pp	(NOLOCK)	ON pp.ProcessOrder = tmg.MajorGroupDesc							
										
	UPDATE  @tmpMajorGroup
		SET StartTime =	@dtmStartDate,
			EndTime	  =	@dtmEndDate
	WHERE MajorGroupDesc = 'No PO'
	  	   	    
	UPDATE @tmpMajorGroup  
		SET StartTime = NULL  
	WHERE StartTime < @dtmStartDate  
	
	UPDATE @tmpMajorGroup  
		SET EndTime = NULL  
	WHERE EndTime > @dtmEndDate
	OR EndTime < @dtmStartDate 

	-----------------------------------------------------------------------------------------------------------------
	--  Alarms section
	-----------------------------------------------------------------------------------------------------------------
	--
	-- Open Alarm Count	
	UPDATE tmp
		SET NumOfOpenAlarm = ISNULL((	SELECT COUNT(*) 
										FROM   #tmpAlarms (NOLOCK)
										WHERE (EndDate IS NULL OR OpenAlarm = 1) 
										AND ISNULL(StartProcessOrder,'No PO') = tmp.MajorGroupDesc
										AND (@Product IS NULL OR @Product = '' OR ISNULL(tmp.ProdCode,'No Prod') = @Product))	,0)
	FROM   @tmpMajorGroup tmp
	--WHERE tmp.MajorGroupDesc <> 'No PO'
	
	--
	-- Closed Alarm Count	
	UPDATE tmp
		SET NumOfCloseAlarm =  ISNULL((	SELECT COUNT(*) 
										FROM   #tmpAlarms (NOLOCK)
										WHERE EndDate IS NOT NULL
										AND ISNULL(EndProcessOrder,'No PO') = tmp.MajorGroupDesc
										--AND EndDate >= ISNULL(tmp.StartTime,@dtmStartDate)
										--AND EndDate < ISNULL(tmp.EndTime,@dtmEndDate))	
										),0)
	FROM   @tmpMajorGroup tmp
	WHERE tmp.MajorGroupDesc <> 'No PO'
	--
	-- Closed Alarm Count	
	UPDATE tmp
		SET NumOfCloseAlarm = ISNULL((	SELECT ISNULL(COUNT(*) ,0)
										FROM   #tmpAlarms (NOLOCK)
										WHERE EndDate IS NOT NULL
										AND ISNULL(EndProcessOrder,'No PO') = tmp.MajorGroupDesc
										AND EndDate >= @dtmStartDate
										AND EndDate < @dtmEndDate
										AND RcdIdx NOT IN (SELECT RcdIdx 
															FROM #tmpAlarms a (NOLOCK)
															JOIN @tmpMajorGroup mg	ON	a.EndDate IS NOT NULL
																						AND a.EndDate >= ISNULL(mg.StartTime,@dtmStartDate)
																						AND a.EndDate < ISNULL(mg.EndTime,@dtmEndDate)
															WHERE mg.MajorGroupDesc <> 'No PO' ))	,0)
	FROM   @tmpMajorGroup tmp
	WHERE tmp.MajorGroupDesc = 'No PO'

	--
	-- Alarm Count	
	UPDATE @tmpMajorGroup
		SET NumOfAlarms = NumOfCloseAlarm + NumOfOpenAlarm
	
END
ELSE IF @strGroupBy = 'Product'
BEGIN
	INSERT INTO @tmpMajorGroup	( 				
				MajorGroupName			,
				MajorGroupDesc			,
				NumOfTests				,
				ProdCode				,
				ProdDesc				,
				StartTime				,
				EndTime					)
			
	--	Process Order - Line -  Unit - Variable Name -Variable Result - Result On - Display Name
	--  Total Tests
	SELECT 'Product'					,
			ISNULL(ProdCode,'No Prod')	,
			COUNT(*)					,
			ISNULL(ProdCode,'No Prod')	,
			ISNULL(ProdDesc,'No Prod')	,
			@dtmStartDate				,
			@dtmEndDate
	FROM #tmpQASummaryRpt (NOLOCK)
	GROUP BY ProdCode,
			ProdDesc

					
	UPDATE mj
		SET BatchNumber = CASE
							WHEN (SELECT COUNT(DISTINCT BatchNumber) FROM #Production p (NOLOCK) WHERE p.ProdCode = mj.ProdCode) = 1
								THEN (SELECT TOP 1 BatchNumber FROM #Production p (NOLOCK) WHERE p.ProdCode = mj.ProdCode)
							WHEN (SELECT COUNT(DISTINCT BatchNumber) FROM #Production p (NOLOCK) WHERE p.ProdCode = mj.ProdCode) > 1
								THEN 'Multiple Batches'
							ELSE '-'
							END			
	FROM @tmpMajorGroup mj
	
	-- In Spec
	UPDATE tmp
		SET NumTestsInSpec = (SELECT COUNT(*) 
								FROM   #tmpQASummaryRpt (NOLOCK)
								WHERE	ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
									AND	Result IS NOT NULL
									AND Defect = 0)
	FROM   @tmpMajorGroup tmp

	-- OOS
	UPDATE tmp
		SET NumOfOOS = (SELECT COUNT(*) 
								FROM   #tmpQASummaryRpt (NOLOCK)
								WHERE	ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
									AND Result IS NOT NULL
									AND Defect = 1)
	FROM   @tmpMajorGroup tmp

	-- Missing
	UPDATE tmp
		SET NumOfMissing = (SELECT COUNT (*) 
								FROM #tmpQASummaryRpt (NOLOCK)
								WHERE	ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
								AND  	(	(Result IS NULL	AND StubberUser = 1 AND Canceled = 0) 
									OR	(StubberUser = 1 AND Canceled = 1 AND EntryBy <> 'CalculationMgr' AND EntryBy NOT LIKE '%System%')))
	FROM   @tmpMajorGroup tmp
	
	UPDATE @tmpMajorGroup
		SET NumOfTests = NumOfMissing + NumOfOOS + NumTestsInSpec

	-- Overall Section
	-------------------------------------------------------------------------------------------------
	UPDATE tmp
		SET TAMUPerCompletion = CONVERT(DECIMAL(10,2),(CONVERT(FLOAT,(NumOfTests - NumOfMissing)) / CONVERT(FLOAT,NumOfTests)) * 100.0)
	FROM   @tmpMajorGroup tmp
	WHERE NumOfTests > 0
	--
	-- Overall % Compliance Calculation
	UPDATE tmp
		SET TAMUPerCompliance = CONVERT(DECIMAL(10,2),(CONVERT(FLOAT,NumTestsInSpec) / CONVERT(FLOAT,NumOfTests)) * 100.0)
	FROM   @tmpMajorGroup tmp
	WHERE NumOfTests > 0

		
	-- QFactor Section
	-------------------------------------------------------------------------------------------------

	-- QFactor Total
	UPDATE tmp
		SET QFactorTotal = (SELECT COUNT(*) 
										FROM   #tmpQASummaryRpt (NOLOCK)
										WHERE  ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
										AND    PrimaryQFactor = 'Yes') -
							(SELECT COUNT(*) 
										FROM	#tmpQASummaryRpt (NOLOCK)
										WHERE  ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
										AND		PrimaryQFactor = 'Yes'
										AND		StubberUser = 0
										AND		Result IS NULL)		
	FROM   @tmpMajorGroup tmp

	-- QFactor Total Unplanned
	UPDATE tmp
		SET QFactorTotalPlanned = QFactorTotal - (SELECT COUNT(*) 
												FROM   #tmpQASummaryRpt (NOLOCK)
												WHERE  ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
												AND    PrimaryQFactor = 'Yes'
												AND		StubberUser = 0 )
	FROM   @tmpMajorGroup tmp
	
	-- QFactor % Completion
	UPDATE tmp
		SET QFactorCompletion = (SELECT COUNT(*) 
										FROM   #tmpQASummaryRpt (NOLOCK)
										WHERE  ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
										AND    PrimaryQFactor = 'Yes'
										AND	(	(Result IS NULL	AND StubberUser = 1 AND Canceled = 0) 
											OR	(StubberUser = 1 AND Canceled = 1 AND EntryBy <> 'CalculationMgr' AND EntryBy NOT LIKE '%System%')))
										--AND    Result IS NOT NULL
										--AND		StubberUser = 1)
	FROM   @tmpMajorGroup tmp
	
	-- QFactor % Compliance
	UPDATE tmp
		SET QFactorCompliance = (SELECT COUNT(*) 
										FROM   #tmpQASummaryRpt (NOLOCK)
										WHERE  ISNULL(ProdCode,'No Prod') = tmp.MajorGroupDesc
										AND    PrimaryQFactor = 'Yes'
										AND    Result IS NOT NULL
										AND    Defect = 0)
	FROM   @tmpMajorGroup tmp
		
	-- QFactor % Completion Calculation
	UPDATE tmp
		SET QFactorCompletion = CONVERT(DECIMAL(10,2),((QFactorTotal - QFactorCompletion) / QFactorTotal) * 100)
	FROM   @tmpMajorGroup tmp
	WHERE QFactorTotal > 0
	
	-- QFactor % Compliance Calculation
	UPDATE tmp
		SET QFactorCompliance = CONVERT(DECIMAL(10,2),(QFactorCompliance / QFactorTotal) * 100)
	FROM   @tmpMajorGroup tmp
	WHERE QFactorTotal > 0


	-----------------------------------------------------------------------------------------------------------------
	--  Alarms section
	-----------------------------------------------------------------------------------------------------------------
	--
	-- Open Alarm Count	
	UPDATE tmp
		SET NumOfOpenAlarm = (	SELECT COUNT(*) 
								FROM   #tmpAlarms (NOLOCK)
								WHERE EndDate IS NULL 
								AND StartDate >= ISNULL(tmp.StartTime,@dtmStartDate)
								AND StartDate < ISNULL(tmp.EndTime,@dtmEndDate)
									--OR (StartDate < @dtmStartDate))
								AND tmp.MajorGroupDesc = ProdCode)

	FROM   @tmpMajorGroup tmp
	WHERE tmp.MajorGroupDesc <> 'No Prod'
	--
	-- Closed Alarm Count	
	UPDATE tmp
		SET NumOfCloseAlarm = (	SELECT COUNT(*) 
								FROM   #tmpAlarms (NOLOCK)
								WHERE EndDate IS NOT NULL
								AND EndDate >= ISNULL(tmp.StartTime,@dtmStartDate)
								AND EndDate < ISNULL(tmp.EndTime,@dtmEndDate)
								AND tmp.MajorGroupDesc = ProdCode)
	FROM   @tmpMajorGroup tmp
	WHERE tmp.MajorGroupDesc <> 'No Prod'

	
	-- Open Alarm Count	
	UPDATE tmp
		SET NumOfOpenAlarm = (	SELECT ISNULL(COUNT(*) ,0)
								FROM   #tmpAlarms (NOLOCK)
								WHERE EndDate IS NULL 
								AND StartDate >= @dtmStartDate
								AND StartDate < @dtmEndDate
								AND RcdIdx NOT IN (SELECT RcdIdx 
													FROM #tmpAlarms a (NOLOCK)
													JOIN @tmpMajorGroup mg	ON	a.EndDate IS NULL
																				AND a.StartDate >= ISNULL(mg.StartTime,@dtmStartDate)
																				AND a.StartDate < ISNULL(mg.EndTime,@dtmEndDate)
													WHERE mg.MajorGroupDesc <> 'No Prod' ))
	FROM   @tmpMajorGroup tmp
	WHERE tmp.MajorGroupDesc = 'No Prod'
		
	-- Closed Alarm Count	
	UPDATE tmp
		SET NumOfCloseAlarm = (	SELECT ISNULL(COUNT(*) ,0)
								FROM   #tmpAlarms (NOLOCK)
								WHERE EndDate IS NOT NULL 
								AND EndDate >= @dtmStartDate
								AND EndDate < @dtmEndDate
								AND RcdIdx NOT IN (SELECT RcdIdx 
													FROM #tmpAlarms a (NOLOCK)
													JOIN @tmpMajorGroup mg	ON	a.EndDate IS NOT NULL
																				AND a.EndDate >= ISNULL(mg.StartTime,@dtmStartDate)
																				AND a.EndDate < ISNULL(mg.EndTime,@dtmEndDate)
													WHERE mg.MajorGroupDesc <> 'No Prod' ))
	FROM   @tmpMajorGroup tmp
	WHERE tmp.MajorGroupDesc = 'No Prod'
	
	--
	-- Alarm Count	
	UPDATE @tmpMajorGroup
		SET NumOfAlarms = NumOfCloseAlarm + NumOfOpenAlarm

END
ELSE IF @strGroupBy = 'None'
BEGIN
	INSERT INTO @tmpMajorGroup	( 				
				MajorGroupName			,
				MajorGroupDesc			,
				NumOfTests				,
				ProdCode				,
				ProdDesc				)			
	--	Process Order - Line -  Unit - Variable Name -Variable Result - Result On - Display Name
	--  Total Tests
	SELECT		'None'					,
				'None'					,
				COUNT(*)				,
				ISNULL(@prodCode,'Multiple Products')		,
				ISNULL(@prodDesc,'Multiple Products')
	FROM #tmpQASummaryRpt (NOLOCK)
		
	IF (SELECT COUNT(DISTINCT ProdCode) FROM #tmpQASummaryRpt (NOLOCK)) = 1
	BEGIN
		UPDATE @tmpMajorGroup
		SET ProdCode = (SELECT DISTINCT TOP 1 ProdCode FROM #tmpQASummaryRpt (NOLOCK)),
			ProdDesc = (SELECT DISTINCT TOP 1 ProdDesc FROM #tmpQASummaryRpt (NOLOCK))
	END
			
	UPDATE @tmpMajorGroup
		SET BatchNumber = CASE
							WHEN (SELECT COUNT(DISTINCT BatchNumber) FROM #Production (NOLOCK) WHERE BatchNumber IS NOT NULL) = 1
								THEN (SELECT TOP 1 BatchNumber FROM #Production (NOLOCK) WHERE BatchNumber IS NOT NULL)
							WHEN (SELECT COUNT(DISTINCT BatchNumber) FROM #Production (NOLOCK) WHERE BatchNumber IS NOT NULL) > 1
								THEN 'Multiple Batches'
							ELSE '-'
							END

	-- In Spec
	UPDATE tmp
		SET NumTestsInSpec = (SELECT COUNT(*) 
								FROM	#tmpQASummaryRpt (NOLOCK)
								WHERE	Defect = 0
									AND	Result IS NOT NULL)
	FROM   @tmpMajorGroup tmp

	-- OOS
	UPDATE tmp
		SET NumOfOOS = (SELECT COUNT(*) 
								FROM   #tmpQASummaryRpt (NOLOCK)
								WHERE   Defect = 1
									AND	Result IS NOT NULL)
	FROM   @tmpMajorGroup tmp

	-- Missing
	UPDATE tmp
		SET NumOfMissing = (SELECT COUNT (*) 
								FROM	#tmpQASummaryRpt (NOLOCK)
								WHERE  	(	(Result IS NULL	AND StubberUser = 1 AND Canceled = 0) 
									OR	(StubberUser = 1 AND Canceled = 1 AND EntryBy <> 'CalculationMgr' AND EntryBy NOT LIKE '%System%')))
	FROM   @tmpMajorGroup tmp
		
	UPDATE @tmpMajorGroup
		SET NumOfTests = NumOfMissing + NumOfOOS + NumTestsInSpec

	-- Overall % Completion Calculation
	UPDATE tmp
		SET TAMUPerCompletion = CONVERT(DECIMAL(10,2),(CONVERT(FLOAT,(NumOfTests - NumOfMissing)) / CONVERT(FLOAT,NumOfTests)) * 100.0)
	FROM   @tmpMajorGroup tmp
	WHERE NumOfTests > 0

	--
	-- Overall % Compliance Calculation
	UPDATE tmp
		SET TAMUPerCompliance = CONVERT(DECIMAL(10,2),(CONVERT(FLOAT,NumTestsInSpec) / CONVERT(FLOAT,NumOfTests)) * 100.0)
	FROM   @tmpMajorGroup tmp
	WHERE NumOfTests > 0

	-- QFactor Section
	-------------------------------------------------------------------------------------------------
	-- QFactor Total
	UPDATE tmp
		SET QFactorTotal = (SELECT COUNT(*) 
										FROM   #tmpQASummaryRpt (NOLOCK)
										WHERE  PrimaryQFactor = 'Yes') -
							(SELECT COUNT(*) 
										FROM	#tmpQASummaryRpt (NOLOCK)
										WHERE	PrimaryQFactor = 'Yes'
										AND		StubberUser = 0
										AND		Result IS NULL)	
	FROM   @tmpMajorGroup tmp

	-- QFactor Total Unplanned
	UPDATE tmp
		SET QFactorTotalPlanned = QFactorTotal - (SELECT COUNT(*) 
												FROM	#tmpQASummaryRpt (NOLOCK)
												WHERE	PrimaryQFactor = 'Yes'
													AND	StubberUser = 0 )
	FROM   @tmpMajorGroup tmp
	
	-- QFactor % Completion
	UPDATE tmp
		SET QFactorCompletion = (SELECT COUNT(*) 
										FROM	#tmpQASummaryRpt (NOLOCK)
										WHERE	PrimaryQFactor = 'Yes'
										AND	(	(Result IS NULL	AND StubberUser = 1 AND Canceled = 0) 
											OR	(StubberUser = 1 AND Canceled = 1 AND EntryBy <> 'CalculationMgr' AND EntryBy NOT LIKE '%System%')))
	FROM   @tmpMajorGroup tmp
	
	-- QFactor % Compliance
	UPDATE tmp
		SET QFactorCompliance = (SELECT COUNT(*) 
										FROM   #tmpQASummaryRpt (NOLOCK)
										WHERE  PrimaryQFactor = 'Yes'
										AND    Result IS NOT NULL
										AND    Defect = 0)
	FROM   @tmpMajorGroup tmp
	
	-- QFactor % Completion Calculation
	UPDATE tmp
		SET QFactorCompletion = CONVERT(DECIMAL(10,2),((QFactorTotal - QFactorCompletion) / QFactorTotal) * 100)
	FROM   @tmpMajorGroup tmp
	WHERE QFactorTotal > 0
	
	-- QFactor % Compliance Calculation
	UPDATE tmp
		SET QFactorCompliance = CONVERT(DECIMAL(10,2),(QFactorCompliance / QFactorTotal) * 100)
	FROM   @tmpMajorGroup tmp
	WHERE QFactorTotal > 0

	--
	-- Open Alarm Count	
	UPDATE tmp
		SET NumOfOpenAlarm = (SELECT COUNT(*) 
								FROM  #tmpAlarms (NOLOCK)
								WHERE EndDate IS NULL
								AND StartDate >= ISNULL(tmp.StartTime,@dtmStartDate)
								AND StartDate < ISNULL(tmp.EndTime,@dtmEndDate)	)
	FROM   @tmpMajorGroup tmp
	--
	-- Closed Alarm Count	
	UPDATE tmp
		SET NumOfCloseAlarm = (SELECT COUNT(*) 
								FROM   #tmpAlarms (NOLOCK)
								WHERE  EndDate IS NOT NULL
								AND EndDate >= ISNULL(tmp.StartTime,@dtmStartDate)
								AND EndDate < ISNULL(tmp.EndTime,@dtmEndDate)	)
	FROM   @tmpMajorGroup tmp
	
	--
	-- Alarm Count	
	UPDATE @tmpMajorGroup
		SET NumOfAlarms = NumOfCloseAlarm + NumOfOpenAlarm
	
	UPDATE @tmpMajorGroup  
	SET StartTime = @dtmStartDate  


	UPDATE @tmpMajorGroup  
	SET EndTime = @dtmEndDate  
END


-----------------------------------------------------------------------------------------------------------------
-- Test section:
--SELECT '#tmpQASummaryRpt',* FROM #tmpQASummaryRpt
--select * from @tmpMissing
 --SELECT '#tmpAlarms',* FROM #tmpAlarms ORDER BY StartDate
 --SELECT '@tmpMajorGroup',* FROM @tmpMajorGroup ORDER BY StartTime
-- SELECT * FROM dbo.OpsDB_Quality_RawData	WHERE Defect = 1
-- SELECT * FROM [dbo].[OpsDB_Alarm_RawData]
-- SELECT '@tmpPOSummaryRpt',* FROM @tmpPOSummaryRpt
-----------------------------------------------------------------------------------------------------------------

--=====================================================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'OUTPUT ' + CONVERT(VARCHAR(50), GETDATE(), 121) 
PRINT '-----------------------------------------------------------------------------------------------------------------------'

---------------------------------------------------------------------------------------------------------------
-- ProcessOrder, Product and batches Output lists
-----------------------------------------------------------------------------------------------------------------
SELECT @batchList = '';

IF @strGroupBy = 'ProcessOrder'	BEGIN
	UPDATE @tmpMajorGroup
	SET ProcessOrderList = MajorGroupDesc, ProductList = ProdDesc, BatchList=ISNULL(BatchNumber,'N/A')
END

IF @strGroupBy = 'Product'	BEGIN
	UPDATE @tmpMajorGroup SET ProductList = MajorGroupDesc

	--POs
	DECLARE @tmpPOs TABLE(product NVARCHAR(50), po NVARCHAR(50));
	DECLARE @proder TABLE(product NVARCHAR(50), po NVARCHAR(2000));

	INSERT INTO @tmpPOs (product, po)
	SELECT DISTINCT ProdCode,ProcessOrder FROM #Production

	INSERT INTO @proder
	SELECT Main.product,
       LEFT(Main.po,Len(CASE WHEN Main.po IS NULL OR Main.po = '' THEN 'No PO' ELSE Main.po END)-1) As 'po'
	FROM
		(
			SELECT DISTINCT ST2.product, 
				(
					SELECT ST1.po + ',' AS [text()]
					FROM @tmpPOs ST1
					WHERE ST1.product = ST2.product
					ORDER BY ST1.product
					FOR XML PATH ('')
				) [po]
			FROM @tmpPOs ST2
		) [Main]

	--Batches
	DECLARE @tmpBCH TABLE(product NVARCHAR(50), batch NVARCHAR(50));
	DECLARE @baches TABLE(product NVARCHAR(50), batch NVARCHAR(2000));

	INSERT INTO @tmpBCH (product, batch)
	SELECT DISTINCT ProdCode,BatchNumber FROM #Production WHERE BatchNumber IS NOT NULL

	INSERT INTO @baches
	SELECT Main.product,
       LEFT(Main.batch,Len(CASE WHEN Main.batch IS NULL OR Main.batch = '' THEN 'No PO' ELSE Main.batch END)-1) As 'batch'
	FROM
		(
			SELECT DISTINCT ST2.product, 
				(
					SELECT ST1.batch + ',' AS [text()]
					FROM @tmpBCH ST1
					WHERE ST1.product = ST2.product
					ORDER BY ST1.product
					FOR XML PATH ('')
				) [batch]
			FROM @tmpBCH ST2
		) [Main]
		
	UPDATE @tmpMajorGroup 
	SET ProcessOrderList = (SELECT TOP 1 p.po FROM @proder p WHERE p.product=ProductList),
		BatchList = (SELECT TOP 1 b.batch FROM @baches b WHERE b.product=ProductList)
END

IF @strGroupBy = 'None'	BEGIN
	
	SELECT @processOrderList = COALESCE(@processOrderList + ',', '') + prod.po  FROM (SELECT  DISTINCT 'po'=ProcessOrder FROM #Production) prod ;
	SELECT @productList = COALESCE(@productList + ',', '') + prod.prod + ' - ' + prod.[desc]  FROM (SELECT DISTINCT 'prod'=ProdCode, 'desc'=ProdDesc FROM #Production) prod ;
	SELECT @batchList = COALESCE(@batchList + ',', '') + prod.batch  FROM (SELECT DISTINCT 'batch'=BatchNumber FROM #Production (NOLOCK) WHERE BatchNumber IS NOT NULL) prod ;

	IF SUBSTRING(@batchList,1,1) = ',' SET @batchList = SUBSTRING(@batchList,2,LEN(@batchList));

	UPDATE @tmpMajorGroup
		SET ProcessOrderList = @processOrderList,
			ProductList = @productList,
			ProdCode = CASE WHEN @productList IS NULL THEN '-' ELSE ProdCode END,
			ProdDesc = CASE WHEN @productList IS NULL THEN '-' ELSE ProdDesc END,
			BatchList = @batchList
END

---------------------------------------------------------------------------------------------------------------
-- Output
-----------------------------------------------------------------------------------------------------------------
IF EXISTS(SELECT * FROM @tmpMajorGroup)
BEGIN
	-- ResultSet 1: Major Group and KPIs data
	SELECT 'RS1'							,
			MajorGroupName					,
			MajorGroupDesc					,
			ProdCode						,
			ProdDesc						,
			BatchNumber						,
			StartTime						,
			EndTime							,
			NumOfTests						,
			NumOfTestsPlanned				,
			NumTestsInSpec					,
			NumOfOOS						,
			NumOfMissing					,
			NumOfAlarms						,
			NumOfOpenAlarm					,
			NumOfCloseAlarm					,
			TAMUTotal						,
			TAMUTotalUnpl					,
			TAMUPerCompletion				,
			TAMUPerCompliance				,
			QFactorTotal					,
			QFactorTotalPlanned				,
			QFactorCompletion				,
			QFactorCompliance				,
			ProcessOrderList				,
			ProductList						,
			BatchList						
	FROM @tmpMajorGroup ORDER BY StartTime
	-----------------------------------------------------------------------------------------------------------------
	-- ResultSet 2: Status
	IF @strGroupBy = 'ProcessOrder'
	BEGIN
		SELECT 'RS2', 
				MajorGroupDesc AS ReassuranceTesting ,
				CASE	WHEN (NumOfOOS = 0) AND (NumOfMissing = 0) AND (NumOfOpenAlarm = 0) AND (StartTime IS NOT NULL) AND (EndTime IS NOT NULL)	THEN 'PASS'
						WHEN (NumOfOOS = 0) AND (NumOfMissing = 0) AND (NumOfOpenAlarm = 0) AND ((StartTime IS NULL) OR (EndTime IS NULL))			THEN 'Incomplete - PASS' 
						WHEN ((NumOfOOS > 0) OR (NumOfMissing > 0) OR (NumOfOpenAlarm > 0)) AND ((StartTime IS NULL) OR (EndTime IS NULL))			THEN 'Incomplete - FAIL' 
						WHEN ((NumOfOOS > 0) OR (NumOfMissing > 0) OR (NumOfOpenAlarm > 0)) AND (StartTime IS NOT NULL) AND (EndTime IS NOT NULL)	THEN 'FAIL' 
				END AS Status
		FROM @tmpMajorGroup   
		ORDER BY StartTime
	END
	ELSE IF @strGroupBy = 'Product' OR  @strGroupBy = 'None' 
	BEGIN
		SELECT 'RS2', 
				MajorGroupDesc AS ReassuranceTesting ,
				CASE	WHEN (NumOfOOS = 0 AND NumOfMissing = 0 AND NumOfOpenAlarm = 0) THEN 'PASS' 
						ELSE 'FAIL'END AS Status
		FROM @tmpMajorGroup  
		ORDER BY StartTime
	END
END
ELSE
BEGIN
	-- ResultSet 1: Major Group and KPIs data
	SELECT 'RS1',				
			NULL		'MajorGroupName'		,
			NULL		'MajorGroupDesc'		,
			NULL		'ProdCode'				,
			NULL		'ProdDesc'				,
			NULL		'BatchNumber'			,
			NULL		'StartTime'				,
			NULL		'EndTime'				,
			0			'NumOfTests'			,
			0			'NumOfTestsPlanned'		,
			0			'NumTestsInSpec'		,
			0			'NumOfOOS'				,
			0			'NumOfMissing'			,
			0			'NumOfAlarms'			,
			0			'NumOfOpenAlarm'		,
			0			'NumOfCloseAlarm'		,
			0			'TAMUTotal'				,
			0			'TAMUTotalUnpl'			,
			0			'TAMUPerCompletion'		,
			0			'TAMUPerCompliance'		,
			0			'QFactorTotal'			,
			0			'QFactorTotalPlanned'	,
			0			'QFactorCompletion'		,
			0			'QFactorCompliance'	
	-----------------------------------------------------------------------------------------------------------------
	-- ResultSet 2: Status
	SELECT 'RS2'								, 
			NULL		'ReassuranceTesting'	,
			'PASS' 		'Status'
	 
END
-----------------------------------------------------------------------------------------------------------------
-- ResultSet 3: Start and End Time	   
-- IF @dtmStartDate IS NULL AND @strTimeOption IS NOT NULL
-- BEGIN
	-- INSERT INTO	@tblTimeOption 
	-- EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @prodLineId

	-- SELECT	@dtmStartDate = startDate FROM @tblTimeOption
-- END
-- IF @dtmEndDate IS NULL AND @strTimeOption IS NOT NULL
-- BEGIN
	-- INSERT INTO	@tblTimeOption 
	-- EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @prodLineId

	-- SELECT	@dtmEndDate = endDate FROM @tblTimeOption
-- END

SELECT @dtmStartDate	'StartDate',
	   @dtmEndDate		'EndDate'
	   
-----------------------------------------------------------------------------------------------------------------
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'END REPORT ' + CONVERT(VARCHAR(50), GETDATE(), 121) + ' - ' + CONVERT(NVARCHAR,DATEDIFF(mm,@Runtime,GETDATE()))
PRINT '-----------------------------------------------------------------------------------------------------------------------'

DROP TABLE #tmpQASummaryRpt
DROP TABLE #tmpAlarms
DROP TABLE #prodRelVarId
DROP TABLE #ProductionPlan
DROP TABLE #Production
DROP TABLE #Downtimes

GO
GRANT EXECUTE ON [dbo].[spRptQSummaryResults] TO OpDBWriter
GO