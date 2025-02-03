USE [Auto_opsDataStore]
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20)

SELECT
		@SP_Name	= 'spRptQSummaryAlarms',
		@Inputs		= 6, 
		@Version	= '1.4'  

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
				
DROP PROCEDURE [dbo].[spRptQSummaryAlarms]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



--------------------------------------------------------------------------------------------------
-- Stored Procedure: [spRptQSummaryAlarms]
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
-- EDIT HISTORY: 
--------------------------------------------------------------------------------------------------
-- ========		====	  		====					=====
-- 1.0			2018-03-05		Martin Casalis			Initial Release
-- 1.1			2019-08-02		Damian Campana			Add global parameters Trimm Downtimes (min)
-- 1.2			2019-10-22		Damian Campana			Add the ability to see comments
-- 1.3			2019-10-24		Damian Campana			Include alarms variables "_AL"
-- 1.4			2022-12-14		Gonzalo Luc				Fix PRB0097980 Process Order name field in the output.
--================================================================================================
--------------------------------------------------------------------------------------------------

----------------------------------------[Creation Of SP]------------------------------------------
CREATE PROCEDURE [dbo].[spRptQSummaryAlarms]

--DECLARE		
				@LineDesc			NVARCHAR(200)	= NULL		,
				@TimeOption			INT				= NULL		,
				@dtmStartDate		DATETIME		= NULL		,
				@dtmEndDate			DATETIME		= NULL		,
				@strGroupBy			NVARCHAR(100)				,
				@ProcessOrder		NVARCHAR(100)	= NULL		,
				@Product			NVARCHAR(100)	= NULL      ,
				@KPIOut				NVARCHAR(100)				,
				@ExcludeNPT			BIT				= NULL		,
				@TrimmDowntimesMin	INT				= NULL
--WITH ENCRYPTION
AS

-----------------------------------------------------------------------------------------------------------------
-- TEST DATA
-----------------------------------------------------------------------------------------------------------------
--SELECT		
--				@LineDesc			= 'DIMR112'
--				,@TimeOption		= 1
--				,@dtmStartDate		= ''
--				,@dtmEndDate		= ''
--				,@strGroupBy		= 'None'
--				,@ProcessOrder		= ''
--				,@Product			= ''
--				,@KPIOut			= ''
--				,@ExcludeNPT		= 0
--				,@TrimmDowntimesMin	= ''
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
				PrimaryQFactor			NVARCHAR(150)		,
				QFactorType				NVARCHAR(150)		)
				
IF OBJECT_ID('tempdb.dbo.#tmpAlarms', 'U') IS NOT NULL  DROP TABLE #tmpAlarms; 
CREATE TABLE #tmpAlarms 
			(	RcdIdx					INT					,
				PLId					INT					,
				VarId					INT					,
				VarDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				StartDate				DATETIME			,
				EndDate					DATETIME			,
				PUId					INT					,
				PLDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUDesc					NVARCHAR(200)	COLLATE DATABASE_DEFAULT	,
				PUGDesc					NVARCHAR(200)		,
				StartProcessOrder		NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				EndProcessOrder			NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdCode				NVARCHAR(100)	COLLATE DATABASE_DEFAULT	,
				ProdDesc				NVARCHAR(255)	COLLATE DATABASE_DEFAULT	,
				OpenAlarm				BIT											,
				CauseComment			TEXT										,
				ActionComment			TEXT										,
				Cause1					NVARCHAR(100)								,
				Cause2					NVARCHAR(100)								,
				Cause3					NVARCHAR(100)								,
				Action1					NVARCHAR(100)								,
				Action2					NVARCHAR(100)								,
				Action3					NVARCHAR(100)								,
				PrimaryQFactor			NVARCHAR(150)								,
				QFactorType				NVARCHAR(150))

DECLARE @tblTimeOption	TABLE (
				startDate				DATETIME			, 
				endDate					DATETIME			)

DECLARE @Production	TABLE (
				ProdId					INT					,
				ProdDesc				NVARCHAR(100)		,
				startDate				DATETIME			, 
				endDate					DATETIME			)
-----------------------------------------------------------------------------------------------------------------
-- Variables Declaration
-----------------------------------------------------------------------------------------------------------------
DECLARE
				@prodLineId				INT				,
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
				@MinPOTime				DATETIME	 ,
				@MaxPOTime				DATETIME		,
				@strTimeOption			NVARCHAR(100)	,
				@in_StartDate			DATETIME		,
				@in_EndDate				DATETIME		,
				@HourInterval			INT				,
				@RptNegMin				INT				,
				@ReportName				NVARCHAR(100)	,
				@HourIntervalName		NVARCHAR(100)	
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
-- UDP text values
-------------------------------------------------------------------------------------------------
SET @UDPProductRelease		= 'ProductRelease'
SET @UDPPrimaryQFactor		= 'Primary Q-Factor?'
SET @UDPQFactorType			= 'Q-Factor Type'
SET @ReportName				= 'Q Summary Report'
SET @HourIntervalName		= '@HourInterval'
		
-- --------------------------------------------------------------------------------------------------------------------
-- Get Start time & End time
-- --------------------------------------------------------------------------------------------------------------------
	SELECT @strTimeOption = DateDesc 
	FROM [dbo].[DATE_DIMENSION] (NOLOCK)
	WHERE DateId = @timeOption
	
	SELECT @prodLineId = PLId
	FROM [dbo].[LINE_DIMENSION] (NOLOCK)
	WHERE LineDesc = @LineDesc
	
IF 	(@ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder <> 'No PO' 
		AND (@LineDesc IS NULL OR @LineDesc = ''))
BEGIN
		SELECT @dtmStartDate = MIN(StartTime) 
		FROM [OpsDB_Production_Data] (NOLOCK)
		WHERE ProcessOrder = @ProcessOrder
	
		SELECT @dtmEndDate = MAX(EndTime) 
		FROM [OpsDB_Production_Data] (NOLOCK)
		WHERE ProcessOrder = @ProcessOrder
																
		-- Get Line Id and Line Desc if a PO is selected
		----------------------------------------------------------------------------------------------------------------------
		IF (@LineDesc = '' OR @LineDesc IS NULL)
		AND (@ProcessOrder IS NOT NULL AND @ProcessOrder <> '')
		BEGIN	
			SELECT	TOP 1 @LineDesc = PLDesc,
							@prodLineId = PLId
			FROM [OpsDB_Production_Data] (NOLOCK)
			WHERE ProcessOrder = @ProcessOrder
		END

		SET @strGroupBy = 'ProcessOrder'
END
ELSE IF (@Product IS NOT NULL AND @Product <> '' AND @Product <> 'No Prod' 
		AND (@LineDesc IS NULL OR @LineDesc = ''))
BEGIN
		INSERT INTO @Production(
					ProdId		,
					ProdDesc	,
					startDate	,
					endDate		)
		SELECT		
					ProdId		,
					ProdDesc	,
					CASE WHEN StartTime < @dtmStartDate THEN @dtmStartDate ELSE StartTime END	,
					CASE WHEN EndTime < @dtmEndDate THEN @dtmEndDate ELSE EndTime END		
		FROM [OpsDB_Production_Data] (NOLOCK)
		WHERE PLDesc = @LineDesc
		AND ProdCode = @Product
		AND StartTime <= @dtmEndDate
		AND (EndTime > @dtmStartDate OR EndTime IS NULL)
END
ELSE
BEGIN
		IF @TimeOption IS NOT NULL
		BEGIN
			INSERT INTO	@tblTimeOption 
			EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @prodLineId

			SELECT	@dtmStartDate = startDate, @dtmEndDate = endDate FROM @tblTimeOption
		END
END

-- Get Report Parameters
-------------------------------------------------------------------------------------------------
SELECT @HourInterval	= [dbo].[fnRptGetParameterValue] (@ReportName,@HourIntervalName)


-- Expansion time when group by PO
-------------------------------------------------------------------------------------------------
IF @strGroupBy = 'ProcessOrder'
BEGIN
	SET @in_StartDate = @dtmStartDate
	SET @in_EndDate = @dtmEndDate

	SET @HourInterval = ISNULL(@HourInterval,0)

	SELECT @MinPOTime = ISNULL(MIN(StartTime),@dtmStartDate) FROM [OpsDB_Production_Data] (NOLOCK)
									WHERE ProcessOrder = @ProcessOrder

	SELECT @MaxPOTime = ISNULL(MAX(EndTime),@dtmEndDate) FROM [OpsDB_Production_Data] (NOLOCK)
									WHERE ProcessOrder = @ProcessOrder


	IF @MinPOTime < @dtmStartDate
	BEGIN
		SET @dtmStartDate = CASE WHEN @MinPOTime <= DATEADD(hh,-1 * @HourInterval,@dtmStartDate) 
								THEN DATEADD(hh,-1 * @HourInterval,@dtmStartDate)
								ELSE @MinPOTime
								END
	END
	ELSE
	BEGIN
		SET @dtmStartDate = @MinPOTime
	END
	IF @MaxPOTime > @dtmEndDate
	BEGIN			
		SET @dtmEndDate = CASE WHEN @MaxPOTime >= DATEADD(hh,1 * @HourInterval,@dtmEndDate) 
								THEN DATEADD(hh,1 * @HourInterval,@dtmEndDate) 
								ELSE @MaxPOTime
								END
	END
	ELSE
	BEGIN
		SET @dtmEndDate = @MaxPOTime
	END
END


-------------------------------------------------------------------------------------------------
--SELECT  @LineDesc '@LineDesc',@TimeOption '@TimeOption',@dtmStartDate '@dtmStartDate',@dtmEndDate '@dtmEndDate',@in_StartDate '@in_StartDate',
--		@in_EndDate '@in_EndDate',@strGroupBy '@strGroupBy',@ProcessOrder '@ProcessOrder',@Product '@Product',@KPIOut	'@KPIOut'
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
	AND (Value = '1' OR Value='QA' OR Value='CL')
	AND fudp.EffectiveDate < @dtmEndDate
	AND (fudp.ExpirationDate > @dtmStartDate OR fudp.ExpirationDate IS NULL)
	
-------------------------------------------------------------------------------------------------
--SELECT '#prodRelVarId',* FROM #prodRelVarId p	
-------------------------------------------------------------------------------------------------
--UPDATE
-------------------------------------------------------------------------------------------------
UPDATE v
    SET PrimaryQFactor = (SELECT TOP 1 Value
                    FROM dbo.FACT_UDPs        fudp    (NOLOCK)
                    JOIN dbo.UDP_DIMENSION    dudp    (NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
                    WHERE    v.VarId = fudp.VarId
                        AND dudp.UDPName = @UDPPrimaryQFactor
                        AND EffectiveDate < @dtmEndDate
                        AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
                    ORDER BY EffectiveDate DESC)
FROM #prodRelVarId    v

 

UPDATE v
    SET QFactorType = (SELECT TOP 1 Value
                    FROM dbo.FACT_UDPs        fudp    (NOLOCK)
                    JOIN dbo.UDP_DIMENSION    dudp    (NOLOCK) ON dudp.UDPIdx = fudp.UDP_Dimension_UDPIdx
                    WHERE    v.VarId = fudp.VarId
                        AND dudp.UDPName = @UDPQFactorType
                        AND EffectiveDate < @dtmEndDate
                        AND (ExpirationDate > @dtmStartDate OR ExpirationDate IS NULL)
                    ORDER BY EffectiveDate DESC)
FROM #prodRelVarId    v
-------------------------------------------------------------------------------------------------
-- Get data for variables flagged as release
-------------------------------------------------------------------------------------------------

--
INSERT INTO #tmpAlarms (
				RcdIdx					,
				PLId					,
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				--PUId					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				StartProcessOrder		,
				ProdCode				,
				ProdDesc				,
				OpenAlarm				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
				)
SELECT			
				RcdIdx					,
				@prodLineId				,
				pr.VarId				,
				VarDesc					,
				StartTime				,
				EndTime					,
				--PUId					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				ISNULL(ProcessOrder,'No PO')	,
				ISNULL(ProdCode,'No Prod')		,
				ProdDesc				,
				CASE WHEN EndTime > @in_EndDate and EndTime > @dtmEndDate  THEN 1 ELSE 0 END,
				CauseComment_Rtf		,
				ActionComment_Rtf		,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				pr.PrimaryQFactor		,
				pr.QFactorType
FROM dbo.OpsDB_Alarms_RawData	iodsal	(NOLOCK)
JOIN #prodRelVarId				pr		(NOLOCK)	ON iodsal.VarId = pr.VarId OR iodsal.SourceVarId = pr.VarId
WHERE PLDesc = @LineDesc 
	AND StartTime < @dtmEndDate
	AND ( EndTime >= @dtmStartDate OR EndTime IS NULL )
	AND DeleteFlag <> 1
ORDER BY StartTime

IF @strGroupBy = 'ProcessOrder'
BEGIN
	INSERT INTO #tmpAlarms (
					RcdIdx					,
					PLId					,
					VarId					,
					VarDesc					,
					StartDate				,
					EndDate					,
					--PUId					,
					PLDesc					,
					PUDesc					,
					PUGDesc					,
					StartProcessOrder		,
					ProdCode				,
					ProdDesc				,
					OpenAlarm				,
					CauseComment			,
					ActionComment			,
					Cause1					,
					Cause2					,
					Cause3					,
					Action1					,
					Action2					,
					Action3					,
					PrimaryQFactor			,
					QFactorType
					)
	SELECT			
					iodsal.RcdIdx					,
					@prodLineId						,
					iodsal.VarId					,
					iodsal.VarDesc					,
					iodsal.StartTime				,
					iodsal.EndTime					,
					--pr.PUId						,
					iodsal.PLDesc					,
					iodsal.PUDesc					,
					iodsal.PUGDesc					,
					ISNULL(iodsal.ProcessOrder,'No PO')	,
					ISNULL(iodsal.ProdCode,'No Prod')	,
					iodsal.ProdDesc					,
					CASE WHEN iodsal.EndTime > @in_EndDate and iodsal.EndTime > @dtmEndDate  THEN 1 ELSE 0 END,
					CauseComment_Rtf				,
					ActionComment_Rtf				,
					Cause1							,
					Cause2							,
					Cause3							,
					Action1							,
					Action2							,
					Action3							,
					pr.PrimaryQFactor				,
					pr.QFactorType
	FROM dbo.OpsDB_Alarms_RawData		iodsal	(NOLOCK)
	JOIN #prodRelVarId					pr		(NOLOCK)	ON iodsal.VarId = pr.VarId OR iodsal.SourceVarId = pr.VarId
	JOIN [OpsDB_VariablesTasks_RawData]	v		(NOLOCK)	ON iodsal.VarId = v.VarId OR iodsal.SourceVarId = v.VarId
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
	SET EndProcessOrder = ProcessOrder
FROM #tmpAlarms					a
JOIN [OpsDB_Production_Data]	pd	(NOLOCK) ON a.PLDesc = pd.PLDesc
WHERE a.EndDate IS NOT NULL
	AND pd.StartTime < a.EndDate
	AND ( a.EndDate <= pd.EndTime OR pd.EndTime IS NULL )

UPDATE a
	SET EndProcessOrder = v.ProcessOrder
FROM #tmpAlarms						a
JOIN [OpsDB_VariablesTasks_RawData]	v	(NOLOCK) ON a.VarId = v.VarId
WHERE	a.EndProcessOrder IS NULL 
	AND a.EndDate IS NOT NULL
	AND (a.EndDate = v.ResultOn
		OR a.EndDate BETWEEN DATEADD(ss,-1,v.ResultOn) AND DATEADD(ss,1,v.ResultOn))

UPDATE #tmpAlarms
	SET OpenAlarm = 1
WHERE OpenAlarm = 0
AND EndDate IS NOT NULL
AND StartProcessOrder <> EndProcessOrder

IF EXISTS( SELECT * FROM @Production )
BEGIN		
	DELETE #tmpAlarms
	WHERE RcdIdx NOT IN(
		SELECT RcdIdx
		FROM #tmpAlarms  a (NOLOCK)
		JOIN @Production p ON	(a.EndDate IS NOT NULL
									AND a.EndDate > p.startDate
									AND a.EndDate <= p.endDate )
								OR (a.EndDate IS NULL
									AND a.StartDate <= p.endDate ))
END


IF @strGroupBy = 'None'
BEGIN
		SELECT @SQLQuery = 
							'SELECT 
								VarId					,
								VarDesc					,
								StartDate				,
								EndDate					,
								PLDesc					,
								PUDesc					,
								StartProcessOrder	AS	''ProcessOrder'',
								ProdCode				,
								ProdDesc				,
								CauseComment			,
								ActionComment			,
								Cause1					,
								Cause2					,
								Cause3					,
								Action1					,
								Action2					,
								Action3					,
								PrimaryQFactor			,
								QFactorType
							FROM   #tmpAlarms (NOLOCK) '
		SELECT @SQLQuery2 = CASE 
							WHEN @KPIOut = 'OpenAlarms' THEN ' WHERE EndDate IS NULL AND StartDate >= ''' + CONVERT(VARCHAR,@dtmStartDate) + ''' AND StartDate < ''' + CONVERT(VARCHAR,@dtmEndDate) + ''''
							WHEN @KPIOut = 'ClosedAlarms'	THEN ' WHERE EndDate IS NOT NULL  AND EndDate >= ''' + CONVERT(VARCHAR,@dtmStartDate) + ''' AND EndDate < ''' + CONVERT(VARCHAR,@dtmEndDate) + ''''
							ELSE ' WHERE (EndDate IS NULL AND StartDate >= ''' + CONVERT(VARCHAR,@dtmStartDate) + ''' AND StartDate < ''' + CONVERT(VARCHAR,@dtmEndDate) + ''')' +
								' OR (EndDate IS NOT NULL  AND EndDate >= ''' + CONVERT(VARCHAR,@dtmStartDate) + ''' AND EndDate < ''' + CONVERT(VARCHAR,@dtmEndDate) + ''')'
							END

		SET @SQLQuery = @SQLQuery + @SQLQuery2
		
		PRINT @SQLQuery

		EXECUTE (@SQLQuery)

END
ELSE
BEGIN
	IF @KPIOut = 'OpenAlarms'
	BEGIN 
		IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> ''
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				@ProcessOrder			'ProcessOrder',
				ProdCode				,
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE (EndDate IS NULL OR OpenAlarm = 1)
			AND ISNULL(StartProcessOrder,'No PO') = @ProcessOrder
		END
		ELSE IF @Product IS NOT NULL AND @Product <> ''
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				StartProcessOrder	AS	'ProcessOrder',
				@Product				'ProdCode',
				ProdDesc				,
				CauseCommen				,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE EndDate IS NULL
			AND StartDate >= @dtmStartDate
			AND StartDate < @dtmEndDate
			AND ISNULL(ProdCode,'No Prod') = @Product
		END 
	END
	ELSE IF @KPIOut = 'ClosedAlarms' 
	BEGIN 
		IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder <> 'No PO'
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				@ProcessOrder			'ProcessOrder',
				ProdCode				,
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE EndDate IS NOT NULL
			--AND EndDate >= @dtmStartDate
			--AND EndDate < @dtmEndDate
			AND EndProcessOrder = @ProcessOrder
		END
		ELSE IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder = 'No PO'
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				@ProcessOrder			'ProcessOrder',
				ProdCode				,
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE EndDate IS NOT NULL 
			AND EndDate >= @dtmStartDate
			AND EndDate < @dtmEndDate
			AND RcdIdx NOT IN (SELECT a.RcdIdx 
								FROM #tmpAlarms				a	(NOLOCK)
								JOIN OpsDB_Production_Data	pd	(NOLOCK)	ON a.PLDesc = pd.PLDesc
																			AND a.EndDate IS NOT NULL
																			AND a.EndDate >= ISNULL(pd.StartTime,@dtmStartDate)
																			AND a.EndDate < ISNULL(pd.EndTime,@dtmEndDate)
								WHERE pd.ProcessOrder <> 'No PO' )
		END
		ELSE IF @Product IS NOT NULL AND @Product <> '' AND @Product <> 'No PO'
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				StartProcessOrder	AS	'ProcessOrder',
				@Product				'ProdCode',
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE EndDate IS NOT NULL
			AND EndDate >= @dtmStartDate
			AND EndDate < @dtmEndDate
			AND ProdCode = @Product
		END
		ELSE IF @Product IS NOT NULL AND @Product <> '' AND @Product = 'No Prod'
		BEGIN

			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				StartProcessOrder	AS	'ProcessOrder',
				@Product				'ProdCode',
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE EndDate IS NOT NULL 
			AND EndDate >= @dtmStartDate
			AND EndDate < @dtmEndDate
			AND RcdIdx NOT IN (SELECT a.RcdIdx 
								FROM #tmpAlarms				a	(NOLOCK)
								JOIN OpsDB_Production_Data	pd	(NOLOCK)	ON a.PLDesc = pd.PLDesc
																			AND a.EndDate IS NOT NULL
																			AND a.EndDate >= ISNULL(pd.StartTime,@dtmStartDate)
																			AND a.EndDate < ISNULL(pd.EndTime,@dtmEndDate)
								WHERE pd.ProdCode <> 'No Prod' )
		END
	END
	ELSE		-- All Alarms
	BEGIN				
		IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder <> 'No PO'
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				@ProcessOrder			'ProcessOrder',
				ProdCode				,
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE (EndDate IS NOT NULL
			--AND EndDate >= @dtmStartDate
			--AND EndDate < @dtmEndDate			
			AND EndProcessOrder = @ProcessOrder)
			OR((EndDate IS NULL OR OpenAlarm = 1)
			AND ISNULL(StartProcessOrder,'No PO') = @ProcessOrder)
		END
		ELSE IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> '' AND @ProcessOrder = 'No PO'
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				PUGDesc					,
				@ProcessOrder			'ProcessOrder',
				ProdCode				,
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE (EndDate IS NOT NULL 
			AND EndDate >= @dtmStartDate
			AND EndDate < @dtmEndDate
			AND RcdIdx NOT IN (SELECT a.RcdIdx 
								FROM #tmpAlarms				a	(NOLOCK)
								JOIN OpsDB_Production_Data	pd	(NOLOCK)	ON a.PLDesc = pd.PLDesc
																			AND a.EndDate IS NOT NULL
																			AND a.EndDate >= ISNULL(pd.StartTime,@dtmStartDate)
																			AND a.EndDate < ISNULL(pd.EndTime,@dtmEndDate)
								WHERE pd.ProcessOrder <> 'No PO' ))
			OR(EndDate IS NULL 
			AND ISNULL(StartProcessOrder,'No PO') = @ProcessOrder)
		END
		ELSE IF @Product IS NOT NULL AND @Product <> '' AND @Product <> 'No Prod'
		BEGIN
			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				StartProcessOrder	AS	'ProcessOrder',
				@Product				'ProdCode',
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE (EndDate IS NOT NULL
			AND EndDate >= @dtmStartDate
			AND EndDate < @dtmEndDate
			AND ProdCode = @Product)
			OR( EndDate IS NULL
			AND StartDate >= @dtmStartDate
			AND StartDate < @dtmEndDate
			AND ISNULL(ProdCode,'No Prod') = @Product)
		END
		ELSE IF @Product IS NOT NULL AND @Product <> '' AND @Product = 'No PO'
		BEGIN

			SELECT 
				VarId					,
				VarDesc					,
				StartDate				,
				EndDate					,
				PLDesc					,
				PUDesc					,
				StartProcessOrder	AS	'ProcessOrder',
				@Product				'ProdCode',
				ProdDesc				,
				CauseComment			,
				ActionComment			,
				Cause1					,
				Cause2					,
				Cause3					,
				Action1					,
				Action2					,
				Action3					,
				PrimaryQFactor			,
				QFactorType
			FROM   #tmpAlarms (NOLOCK)
			WHERE (EndDate IS NOT NULL 
			AND EndDate >= @dtmStartDate
			AND EndDate < @dtmEndDate
			AND RcdIdx NOT IN (SELECT a.RcdIdx 
								FROM #tmpAlarms				a	(NOLOCK)
								JOIN OpsDB_Production_Data	pd	(NOLOCK)	ON a.PLDesc = pd.PLDesc
																			AND a.EndDate IS NOT NULL
																			AND a.EndDate >= ISNULL(pd.StartTime,@dtmStartDate)
																			AND a.EndDate < ISNULL(pd.EndTime,@dtmEndDate)
								WHERE pd.ProdCode <> 'No Prod' ))
			OR( EndDate IS NULL
			AND ISNULL(ProdCode,'No Prod') = @Product)
		END
	END
END

DROP TABLE #tmpAlarms
DROP TABLE #prodRelVarId
-----------------------------------------------------------------------------------------------------------------


GO
GRANT EXECUTE ON [dbo].[spRptQSummaryAlarms] TO OpDBWriter
GO
