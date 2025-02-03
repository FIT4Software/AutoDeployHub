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
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spGetPOProd',
		@Inputs		= 3, 
		@Version	= '1.0'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions 
		WHERE App_Name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version,
			Modified_On = GETDATE() 
		WHERE App_Name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_Name,
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
				
DROP PROCEDURE [dbo].[spGetPOProd]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Function: spGetPOProd
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Martin Casalis - Arido Software
-- Date created			: 2018-07-05
-- Version 				: 1.0
-- Caller				: Report
-- Description			: This stored procedure is used by QA Reports to fill the PO or Product filters
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-07-05		Martin Casalis     		Initial Release
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

----------------------------------------[Creation Of SP]------------------------------------------
CREATE PROCEDURE [dbo].[spGetPOProd]
-- EXEC spRptQSummaryResults 'TUBR006','2018-01-01 00:00:00','2018-01-16 00:00:00','ProcessOrder',0
--DECLARE
		@LineDesc			NVARCHAR(MAX)				,
		@TimeOption			INT				= NULL		,
		@dtmStartDate		DATETIME		= NULL		,
		@dtmEndDate			DATETIME		= NULL		,
		@Type				NVARCHAR(100)				

--WITH ENCRYPTION
AS

DECLARE @tblTimeOption	TABLE (
				PLId				INT			,
				startDate			DATETIME	, 
				endDate				DATETIME	)
				
DECLARE @Lines	TABLE (
				RcdIdx				INT	IDENTITY,
				LineId				INT			, 
				LineDesc			NVARCHAR(50))
				
DECLARE @Output	TABLE (
				OutputId			INT			,
				StartTime			DATETIME	, 
				EndTime				DATETIME	,
				OutputValue			NVARCHAR(50),
				OutputDesc			NVARCHAR(250))
				
DECLARE			@PLId				INT			,
				@strTimeOption		NVARCHAR(50),
				@idx				INT = 1		,
				@maxIdx				INT

-- Test statements
--SELECT @LineDesc		= '74,71,76,55,57,53,4,3,14,56,59,61,49,62,42,63,70,-100,54,5,13', --'PE30-L58',
--	   @TimeOption		= null,
--	   @dtmStartDate	= null,	
--	   @dtmEndDate		= '2018-10-01 00:00:00',	
--	   @Type			= 'product'

--select top 10 ProcessOrder,* from [OpsDB_Production_Data] where PLID = 612 order by EndTime desc
--exec spGetPOProd '124,125,126,123,127,128,129,130,178,179,180,181,182,183,184,185,186,187,188,189,190,191,132,133,134,135,141,143,144,146',null,'2018-06-27 08:00:00','2018-07-27 08:00:00','ProcessOrder' 
--exec spGetPOProd '183,612,557,558',3,'2018-09-06 06:00:00','2018-09-13 06:00:00','ProcessOrder'

-- --------------------------------------------------------------------------------------------------------------------
-- Get Start time & End time
-- --------------------------------------------------------------------------------------------------------------------
IF @LineDesc IS NULL OR @LineDesc = ''
BEGIN
		IF @Type = 'Product'
		BEGIN
			INSERT INTO @Output (StartTime,EndTime,OutputId,OutputValue,OutputDesc)
			SELECT DISTINCT TOP 1000 MIN(StartTime),MAX(EndTime),ProdId,ProdCode,ProdDesc
			FROM [OpsDB_Production_Data] (NOLOCK)
			WHERE ProdCode IS NOT NULL
			AND (EndTime >= @dtmStartDate OR @dtmStartDate IS NULL OR @dtmStartDate = '')
			AND (StartTime <= @dtmEndDate OR @dtmEndDate IS NULL OR @dtmEndDate = '')
			GROUP BY ProdId,ProdCode,ProdDesc
			ORDER BY MAX(EndTime) DESC
		END
		ELSE
		BEGIN
			INSERT INTO @Output (StartTime,EndTime,OutputValue)
			SELECT DISTINCT TOP 1000 MIN(StartTime),MAX(EndTime),ProcessOrder
			FROM [OpsDB_Production_Data] (NOLOCK)
			WHERE ProcessOrder IS NOT NULL
			AND (EndTime >= @dtmStartDate OR @dtmStartDate IS NULL OR @dtmStartDate = '')
			AND (StartTime <= @dtmEndDate OR @dtmEndDate IS NULL OR @dtmEndDate = '')
			GROUP BY ProcessOrder
			ORDER BY MAX(EndTime) DESC
		END
END
ELSE
BEGIN
		SELECT @strTimeOption = DateDesc 
		FROM [dbo].[DATE_DIMENSION] (NOLOCK)
		WHERE DateId = @timeOption

		INSERT INTO @Lines (
					LineId	,
					LineDesc)
		SELECT		
					String	,
					LineDesc 
		FROM  [dbo].[fnLocal_Split] (@LineDesc,',') AS fn
		JOIN [dbo].[LINE_DIMENSION] ld (NOLOCK) ON ld.PLId = fn.String
				
		SELECT @maxIdx = COUNT(*) FROM @Lines

		WHILE @idx <= @maxIdx
		BEGIN
			SELECT	@LineDesc = LineDesc,
					@PLId = LineId
			FROM @Lines
			WHERE RcdIdx = @idx
			
			INSERT INTO	@tblTimeOption (startDate,endDate)
			EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @PLId
			
			UPDATE @tblTimeOption
				SET PLId = @PLId
			WHERE PLId IS NULL
			
			SET @idx = @idx + 1
		END

		UPDATE @tblTimeOption
			SET startDate = ISNULL(@dtmStartDate,DATEADD(MONTH,-6,@dtmEndDate)),
				endDate = @dtmEndDate
		WHERE startDate IS NULL
		AND endDate IS NULL
				
		IF @Type = 'Product'
		BEGIN
			INSERT INTO @Output (StartTime,EndTime,OutputId,OutputValue,OutputDesc)
			SELECT DISTINCT TOP 1000 MIN(StartTime),MAX(EndTime),ProdId,ProdCode,ProdDesc
			FROM [OpsDB_Production_Data]	pd (NOLOCK)
			JOIN @tblTimeOption				tbl ON pd.PLID = tbl.PLId
			WHERE pd.StartTime < tbl.endDate
			AND (pd.EndTime >= tbl.startDate OR pd.EndTime IS NULL)
			AND ProdCode IS NOT NULL
			GROUP BY ProdId,ProdCode,ProdDesc
			ORDER BY MAX(EndTime) DESC
		END
		ELSE
		BEGIN
			INSERT INTO @Output (StartTime,EndTime,OutputValue)
			SELECT DISTINCT TOP 1000 MIN(StartTime),MAX(EndTime),ProcessOrder
			FROM [OpsDB_Production_Data]	pd (NOLOCK)
			JOIN @tblTimeOption				tbl ON pd.PLID = tbl.PLId
			WHERE pd.StartTime < tbl.endDate
			AND (pd.EndTime >= tbl.startDate OR pd.EndTime IS NULL)
			AND ProcessOrder IS NOT NULL
			GROUP BY ProcessOrder
			ORDER BY MAX(EndTime) DESC
		END
END

------------------------------------------------------------------------------------
-- Output
------------------------------------------------------------------------------------
	SELECT DISTINCT OutputId,OutputValue,OutputDesc
	FROM @Output
	ORDER BY OutputValue
------------------------------------------------------------------------------------

GO
GRANT EXECUTE ON [spGetPOProd] TO RptUser
GRANT EXECUTE ON [spGetPOProd] TO OPDBWriter
GO