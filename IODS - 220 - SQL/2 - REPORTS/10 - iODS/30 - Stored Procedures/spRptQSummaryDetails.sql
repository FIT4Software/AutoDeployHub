USE [Auto_opsDataStore]
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20)

SELECT
		@SP_Name	= 'spRptQSummaryDetails',
		@Inputs		= 8, 
		@Version	= '1.2'  

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
				
DROP PROCEDURE [dbo].[spRptQSummaryDetails]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

--------------------------------------------------------------------------------------------------
-- Stored Procedure: [spLocal_iODSRptQA_SummaryDetails]
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
-- EDIT HISTORY: 
--------------------------------------------------------------------------------------------------
-- ========		====	  		====					=====
-- 1.0			2018-03-05		Martin Casalis			Initial Release
-- 1.1			2019-09-02		Damian Campana			Add global parameters Trimm Downtimes (min)
-- 1.2			2019-11-25		Martin Casalid			Fixed ambiguous Task Type
--================================================================================================
--------------------------------------------------------------------------------------------------

----------------------------------------[Creation Of SP]------------------------------------------
CREATE PROCEDURE [dbo].[spRptQSummaryDetails]
--DECLARE
				@LineDesc			NVARCHAR(200)	= NULL		,
				@TimeOption			INT				= NULL		,
				@dtmStartDate		DATETIME		= NULL		,
				@dtmEndDate			DATETIME		= NULL		,
				@strGroupBy			NVARCHAR(100)				,
				@ProcessOrder		NVARCHAR(100)	= NULL		,
				@Product			NVARCHAR(100)	= NULL		,
				@KPIOut				NVARCHAR(100)				,
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
				HSEFlag					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				IsTestComplete			NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PrimaryQFactor			NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				QFactorType				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				TaskType				NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				VariableCategory		NVARCHAR(200)	COLLATE DATABASE_DEFAULT	)
				
IF OBJECT_ID('tempdb.dbo.#QASummaryRptDetails', 'U') IS NOT NULL  DROP TABLE #QASummaryRptDetails; 
CREATE TABLE	#QASummaryRptDetails
			(	
				RcdIdx					INT					,
				PLId					INT					,
				PLDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUGDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUId					INT					,
				PUDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				ProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdCode				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT	,
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
				StubberUser				INT					,
				ExcludedFromDT			BIT		DEFAULT 0	,
				TrimmByLine				BIT		DEFAULT 0	)
				
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
				StartTime				DATETIME			,
				EndTime					DATETIME			,
				NumOfTests				INT					,
				NumOfTestsUnpl			INT					,
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
				QFactorTotalUnpl		INT					,
				QFactorCompletion		FLOAT				,
				QFactorCompliance		FLOAT				)

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
		@in_LineDesc			NVARCHAR(200) = NULL,
		@UDPProductRelease		NVARCHAR(150),
		@UDPHSEFlag				NVARCHAR(150),
		@UDPIsTestComplete		NVARCHAR(150),
		@UDPPrimaryQFactor		NVARCHAR(150),
		@UDPQFactorType			NVARCHAR(150),
		@UDPTaskType			NVARCHAR(150),
		@UDPVariableCategory	NVARCHAR(150),
		@ProdId					INT			,
		@PPId					INT			,
		@SQLQuery				NVARCHAR(MAX),
		@SQLQuery1				NVARCHAR(MAX),
		@SQLQuery2				NVARCHAR(MAX),
		@SQLQuery3				NVARCHAR(MAX),
		@SQLQuery4				NVARCHAR(MAX),
		@SQLQuery5				NVARCHAR(MAX),
		@SQLQuery6				NVARCHAR(MAX),
		@MinPOTime				DATETIME	 ,
		@MaxPOTime				DATETIME	 ,
		@strTimeOption			NVARCHAR(100)	,
		--@dtmStartDate			DATETIME		,
		--@dtmEndDate				DATETIME		,
		@HourInterval			INT				,
		@RptNegMin				INT				,
		@ReportName				NVARCHAR(100)	,
		@HourIntervalName		NVARCHAR(100)	,
		@RptNegMinName			NVARCHAR(100)	,
		@ExcludedFromDTName		NVARCHAR(100)	,
		@PUGExcludedFromDT		NVARCHAR(4000)	,
		@Runtime				DATETIME
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------

-- Test Section
--SELECT			
--				@LineDesc		=	'DIMR113',--'PE30-L054',	--'DIMR110',	--	null,	--	'PQ Conv-L00',	--
--				@TimeOption		=	3,
--				@dtmStartDate	=	'2019-06-01 06:00:00',
--				@dtmEndDate		=	'2019-09-01 06:00:00',
--				@strGroupBy		=	'None',
--				@ProcessOrder	=	'',
--				@Product		=	'',
--				@KPIOut			=	'',	--'InSpecification',	--'MissingResults',	--'OutOfLimits',	--'QFactorCompletion',	--	
--				@ExcludeNPT		=	0
--------------------------------------------------------------------------------------------------

--=====================================================================================================================
PRINT '-----------------------------------------------------------------------------------------------------------------------'
PRINT 'SP START ' + CONVERT(VARCHAR(50), GETDATE(), 121)
PRINT '-----------------------------------------------------------------------------------------------------------------------'
-----------------------------------------------------------------------------------------------------------------
-- UDP text values and Constants values
-----------------------------------------------------------------------------------------------------------------
SET @UDPProductRelease		= 'ProductRelease'
SET @UDPHSEFlag				= 'HSE Flag'
SET @UDPIsTestComplete		= 'Is TestComplete'
SET @UDPPrimaryQFactor		= 'Primary Q-Factor?'
SET @UDPQFactorType			= 'Q-Factor Type'
SET @UDPTaskType			= 'Task Type'
SET @UDPVariableCategory	= 'Q_Variable_Category'

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
SELECT @strTimeOption = DateDesc 
FROM [dbo].[DATE_DIMENSION]  (NOLOCK)
WHERE DateId = @timeOption

SELECT @prodLineId = PLId
FROM [dbo].[LINE_DIMENSION] (NOLOCK)
WHERE LineDesc = @LineDesc

SET @in_LineDesc = @LineDesc
	
IF 	(@ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder <> 'No PO' 
		AND (@LineDesc IS NULL OR @LineDesc = ''))
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
		AND (@ProcessOrder IS NOT NULL AND @ProcessOrder <> '')
		BEGIN	
			SELECT	TOP 1	@LineDesc = PLDesc, 
							@prodLineId = PLId
			FROM #Production (NOLOCK)
		END
END
ELSE
BEGIN	
		IF @TimeOption IS NOT NULL
		BEGIN
			INSERT INTO	@tblTimeOption 
			EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @prodLineId

			SELECT	@dtmStartDate = startDate, @dtmEndDate = endDate FROM @tblTimeOption
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


-- Expansion time when group by PO
-------------------------------------------------------------------------------------------------
IF @strGroupBy = 'ProcessOrder'
BEGIN
	SET @HourInterval = ISNULL(@HourInterval,0)

	SELECT @MinPOTime = ISNULL(MIN(StartTime),@dtmStartDate) 
	FROM #Production (NOLOCK)
	WHERE ProcessOrder = @ProcessOrder
	
	SET @MinPOTime = CASE WHEN @MinPOTime > @dtmStartDate
							THEN @dtmStartDate
							ELSE @MinPOTime
							END

	SELECT @MaxPOTime = ISNULL(MAX(EndTime),@dtmEndDate) 
	FROM #Production (NOLOCK)
	WHERE ProcessOrder = @ProcessOrder

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

-------------------------------------------------------------------------------------------------
--SELECT  @LineDesc '@LineDesc',@TimeOption '@TimeOption',@dtmStartDate '@dtmStartDate',@dtmEndDate '@dtmEndDate',
--		@strGroupBy '@strGroupBy',@ProcessOrder '@ProcessOrder',@Product '@Product',@KPIOut	'@KPIOut'
-------------------------------------------------------------------------------------------------

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
	SET HSEFlag = (SELECT TOP 1 Value
					FROM dbo.FACT_UDPs		fudp	(NOLOCK)
					JOIN dbo.UDP_DIMENSION	dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
					WHERE	v.VarId = fudp.VarId
						AND dudp.UDPName = @UDPHSEFlag
						AND EffectiveDate < @dtmEndDate
						AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
					ORDER BY EffectiveDate DESC)
FROM #prodRelVarId	v

UPDATE v
	SET IsTestComplete = (SELECT TOP 1 Value
					FROM dbo.FACT_UDPs		fudp	(NOLOCK)
					JOIN dbo.UDP_DIMENSION	dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
					WHERE	v.VarId = fudp.VarId
						AND dudp.UDPName = @UDPIsTestComplete
						AND EffectiveDate < @dtmEndDate
						AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
					ORDER BY EffectiveDate DESC)
FROM #prodRelVarId	v

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

UPDATE v
	SET TaskType = (SELECT TOP 1 Value
					FROM dbo.FACT_UDPs		fudp	(NOLOCK)
					JOIN dbo.UDP_DIMENSION	dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
					WHERE	v.VarId = fudp.VarId
						AND dudp.UDPName = @UDPTaskType
						AND EffectiveDate < @dtmEndDate
						AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
					ORDER BY EffectiveDate DESC)
FROM #prodRelVarId	v

UPDATE v
	SET VariableCategory = (SELECT TOP 1 Value
								FROM dbo.FACT_UDPs		fudp	(NOLOCK)
								JOIN dbo.UDP_DIMENSION	dudp	(NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
								WHERE	v.VarId = fudp.VarId
									AND dudp.UDPName = @UDPVariableCategory
									AND EffectiveDate < @dtmEndDate
									AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
								ORDER BY EffectiveDate DESC)
FROM #prodRelVarId	v
--=====================================================================================================================
PRINT 'GET DATA ' + CONVERT(VARCHAR(50), GETDATE(), 121)
PRINT '-----------------------------------------------------------------------------------------------------------------------'
-------------------------------------------------------------------------------------------------
--SELECT '#prodRelVarId',* FROM #prodRelVarId p	


-- Get data for variables flagged as release
-------------------------------------------------------------------------------------------------
SELECT @SQLQuery1 = 
			'SELECT		DISTINCT
				RcdIdx					,	
				iodsqa.PLId				,
				PLDesc					,
				PUId					,
				PUDesc					,
				PUGDesc					,
				ISNULL(ProcessOrder,''No PO'')	,
				ISNULL(ProdCode,''No Prod'')		,
				ProdDesc				,
				pr.VarId				,
				VarDesc					,
				ISNULL(SheetDesc,''No Display'')	,
				EntryOn					,
				UserDesc				,
				ResultOn				,
				Result					,
				Defect					,
				DataType				,
				HSEFlag					,
				IsTestComplete			,
				PrimaryQFactor			,
				QFactorType				,
				pr.TaskType				,
				VariableCategory		,
				StubberUser
FROM [dbo].[OpsDB_VariablesTasks_RawData]	iodsqa	(NOLOCK)
JOIN #prodRelVarId							pr		(NOLOCK)
													ON iodsqa.PLId = pr.PLId	
													AND iodsqa.VarId = pr.VarId
													AND pr.ProductRelease = 1
WHERE ResultOn >= pr.EffectiveDate
AND (ResultOn <= pr.ExpirationDate OR pr.ExpirationDate IS NULL) '

SELECT @SQLQuery2 = ' AND ResultOn >= ''' + CONVERT(VARCHAR,@dtmStartDate) + '''' +
					' AND ResultOn < ''' + CONVERT(VARCHAR,@dtmEndDate) + '''' 

-- Grouping Options
SELECT @SQLQuery3 = CASE WHEN (@Product <> '' AND @Product IS NOT NULL) THEN ' AND ISNULL(ProdCode,''No Prod'') = ''' + CONVERT(VARCHAR,@Product) + '''' ELSE '' END
SELECT @SQLQuery4 = CASE WHEN (@ProcessOrder <> '' AND @ProcessOrder IS NOT NULL) THEN @SQLQuery3 + ' AND ISNULL(ProcessOrder,''No PO'') = ''' + CONVERT(VARCHAR,@ProcessOrder) + ''''	ELSE '' END

SELECT @SQLQuery5 =  ' AND RcdIdx NOT IN (SELECT RcdIdx FROM #QASummaryRptDetails (NOLOCK)) '

	
-- KPIs Options
SELECT @SQLQuery6 = CASE 
					WHEN @KPIOut = 'InSpecification'	THEN ' AND Defect = 0 AND Result IS NOT NULL '
					WHEN @KPIOut = 'OutOfLimits'		THEN ' AND Defect = 1 AND Result IS NOT NULL '
					WHEN @KPIOut = 'MissingResults'		THEN ' AND ((Result IS NULL AND StubberUser = 1 AND Canceled = 0) OR (StubberUser = 1 AND Canceled = 1 AND (UserDesc <> ''CalculationMgr'' AND UserDesc NOT LIKE ''%System%''))) '
					WHEN @KPIOut = 'QFactorCompliance'	THEN ' AND PrimaryQFactor = ''Yes'' AND Result IS NOT NULL	AND Defect = 0 '
					WHEN @KPIOut = 'QFactorCompletion'	THEN ' AND PrimaryQFactor = ''Yes'' AND ((Result IS NULL AND StubberUser = 1 AND Canceled = 0) OR (StubberUser = 1 AND Canceled = 1 AND (UserDesc <> ''CalculationMgr'' AND UserDesc NOT LIKE ''%System%''))) '
					ELSE ' AND ( (Defect = 0 AND Result IS NOT NULL) ' +
						 ' OR (Defect = 1 AND Result IS NOT NULL) ' +
						 ' OR ((Result IS NULL AND StubberUser = 1 AND Canceled = 0) OR (StubberUser = 1 AND Canceled = 1 AND (UserDesc <> ''CalculationMgr'' AND UserDesc NOT LIKE ''%System%''))) )'
					END
					
SET @SQLQuery = @SQLQuery1 + @SQLQuery2 + @SQLQuery3 + @SQLQuery4 + @SQLQuery6

-----------------------------------------------------------------------------------------------------------------
PRINT @SQLQuery
-----------------------------------------------------------------------------------------------------------------

INSERT INTO #QASummaryRptDetails (		
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
				HSEFlag					,
				IsTestComplete			,
				PrimaryQFactor			,
				QFactorType				,
				TaskType				,
				VariableCategory		,
				StubberUser				)
EXECUTE (@SQLQuery)


IF 	(@ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder <> 'No PO' 
		AND (@in_LineDesc IS NULL OR @in_LineDesc = ''))
BEGIN	
	
	SET @SQLQuery = ''
	SET @SQLQuery = @SQLQuery1 + @SQLQuery3 + @SQLQuery4 + @SQLQuery5 + @SQLQuery6
		
	-----------------------------------------------------------------------------------------------------------------
	PRINT @SQLQuery
	-----------------------------------------------------------------------------------------------------------------
	
	INSERT INTO #QASummaryRptDetails (		
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
					HSEFlag					,
					IsTestComplete			,
					PrimaryQFactor			,
					QFactorType				,
					TaskType				,
					VariableCategory		,
					StubberUser				)
	EXECUTE (@SQLQuery)
END


-------------------------------------------------------------------------------------------------
-- Filter Line Status
-------------------------------------------------------------------------------------------------
IF @ExcludeNPT = 1
BEGIN
	DELETE #QASummaryRptDetails
		FROM #QASummaryRptDetails	s	(NOLOCK)
		JOIN #Production			p	(NOLOCK)	ON p.PLId = s.PLId
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
	UPDATE #QASummaryRptDetails
		SET TrimmByLine = 1
	WHERE PUId NOT IN(SELECT PUId FROM [dbo].[WorkCell_Dimension] (NOLOCK) WHERE IsActiveDowntime = 1) 

	
	UPDATE #QASummaryRptDetails
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
		OR PUId IN (SELECT PUId FROM #QASummaryRptDetails (NOLOCK)))
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
											
	DELETE #QASummaryRptDetails
		FROM #QASummaryRptDetails	s	(NOLOCK)
		  				-- We now have to do this backwards (x minutes after the stop and x minutes before the stop we need to watch out) 
		JOIN #Downtimes				d	(NOLOCK)	ON d.PUId = s.PUId
													AND d.PLId = s.PLId
			WHERE TrimmByLine = 0
			AND ExcludedFromDT = 0
			AND ResultOn > DateAdd(minute,@RptNegMin,d.StartTime) 
			AND (ResultOn <= DateAdd(minute,-@RptNegMin,d.EndTime) OR d.EndTime is NULL)

	IF EXISTS (SELECT * FROM #QASummaryRptDetails t (NOLOCK) WHERE TrimmByLine = 1)
	BEGIN						
		DELETE #QASummaryRptDetails
			FROM #QASummaryRptDetails	s	(NOLOCK)
			JOIN #Downtimes				d	(NOLOCK)	ON d.PLID = s.PLId
														AND d.IsConstraint = 1
		  					-- We now have to do this backwards (x minutes after the stop and x minutes before the stop we need to watch out) 
				WHERE TrimmByLine = 1
				AND ExcludedFromDT = 0
				AND ResultOn > DateAdd(minute,@RptNegMin,d.StartTime) 
				AND (ResultOn <= DateAdd(minute,-@RptNegMin,d.EndTime) OR d.EndTime is NULL)
	END
END
-----------------------------------------------------------------------------------------------------------------
-- Test section:
--SELECT '#QASummaryRptDetails',* FROM #QASummaryRptDetails
--select * from @tmpMissing
 --SELECT '@tmpAlarms',* FROM @tmpAlarms ORDER BY StartDate
 --SELECT '@tmpMajorGroup',* FROM @tmpMajorGroup ORDER BY StartTime
-- SELECT * FROM dbo.OpsDB_Quality_RawData	WHERE Defect = 1
-- SELECT * FROM [dbo].[OpsDB_Alarm_RawData]
-- SELECT '@tmpPOSummaryRpt',* FROM @tmpPOSummaryRpt
-----------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-- Output
-----------------------------------------------------------------------------------------------------------------
SELECT 	
				PLDesc					,
				PUId					,
				PUDesc					,
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
				HSEFlag					,
				IsTestComplete			,
				PrimaryQFactor			,
				QFactorType				,
				TaskType				,
				VariableCategory		,
				StubberUser				
FROM #QASummaryRptDetails (NOLOCK)
ORDER BY	ResultOn,
			DisplayName,
			VarDesc

DROP TABLE #QASummaryRptDetails
DROP TABLE #prodRelVarId
DROP TABLE #Production
DROP TABLE #Downtimes
-----------------------------------------------------------------------------------------------------------------


GO
GRANT EXECUTE ON [dbo].[spRptQSummaryDetails] TO OpDBWriter
GO