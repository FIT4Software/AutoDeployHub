USE [Auto_opsDataStore]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'spLocal_GetProductionDisplay' AND Routine_Type = 'PROCEDURE')
BEGIN
	DROP PROCEDURE [dbo].[spLocal_GetProductionDisplay]
END
GO

------------------------------------------------------------------------------------------------------------------------
---- Prototype definition
------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_GetProductionDisplay',
		@Version	= '1.7'


--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions WITH(NOLOCK)
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version,
			Modified_On =GETDATE()
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
GO

--------------------------------------------------------------------------------------------------------------
-- 										OPS Database Stored Procedure										--	
--			  This Script will return de production row data formated to show in iODS display	    		--
--																											--
--------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4												--	
--------------------------------------------------------------------------------------------------------------
-- 1.0	2020-06-02		Ivan Coria.				Initial Development	
-- 1.0	2020-06-05		Carreno Maximiliano.	Add rigth formating, fix filter when get the raw data, fix
--												when get if the unit is converting
-- 1.1	2020-07-29		Carreno Maximiliano.	Fix check editable variables
-- 1.2	2020-08-20		Martin Casalis			Use @date parameter as End Time and return previous 7 days
-- 1.3	2020-10-08		Martin Casalis			Allow OP user to edit values 36 hours back
-- 1.4	2021-01-20      Tomas Gahan             Add StartTime and EndTime Headers
-- 1.5	2021-01-21		Villarreal Damián		Limited 2 decimal places in float type
-- 		2021-02-17      Francisco Gil           Return Production row data only for variables which have Adjusted var associated
-- 		2021-04-13		Ivan Corica				Add @group parameter for adm, mng or op and filter in editable values
--		2021-04-20		Martin Casalis			Locked Good Product when it is calculated from Total Cases
-- 1.6	2021-07-13		Martin Casalis			Fixed editable columns
-- 1.7	2021-11-11		Martin Casalis			Force alphabetical order on the editable variables
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[spLocal_GetProductionDisplay]
--DECLARE
    @puId		INTEGER,
    @date		DATETIME,
	@group		NVARCHAR(3)

--WITH ENCRYPTION
AS

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
SET NOCOUNT ON;

--------------------------------------------------------------------------------------------------------------
--SELECT 
--	 @puId	= 480	--251,
--	,@date	= getdate()--'2021-04-20'
--	,@group	= 'adm' --'mng'	--'op' 
	
--exec Auto_opsDataStore.[dbo].[spLocal_GetProductionDisplay] 480,'2021-11-10','adm'
--------------------------------------------------------------------------------------------------------------

DECLARE @Headers TABLE(
	HeaderField		NVARCHAR(255),
	HeaderName		NVARCHAR(255)	
)

DECLARE @Variable TABLE(
	Variable		NVARCHAR(255),
	ExtendedInfo	NVARCHAR(255)
)

if OBJECT_ID('tempdb..#Production') IS NOT NULL
BEGIN
	DROP TABLE #Production
END

CREATE TABLE #Production (
	RcdIdx			INTEGER,
	StartTime       DATETIME,
	EndTime			DATETIME,
	TotalTime       FLOAT,
 	PPId			INTEGER,
	ProcessOrder	NVARCHAR(50),
	ProdCode		VARCHAR(25),
	TeamDesc		VARCHAR(25),
	ShiftDesc		VARCHAR(25),
	LineStatus		VARCHAR(50),
	RunningScrap	BIGINT,
	StartingScrap	BIGINT,
	TotalProduct	BIGINT,
	GoodProduct		BIGINT,
	TotalScrap		BIGINT,
	TargetRate		FLOAT,
	ActualRate		FLOAT,
	IdealRate		FLOAT,
	TotalCases		INTEGER,
	StatFactor		FLOAT
)

DECLARE 
	@StartTime		        DATETIME,
	@CurrentDate	        DATETIME,
	@MaxDate		        DATETIME,
	@Query	                NVARCHAR(MAX),
	@VariablesOfInterest	NVARCHAR(MAX),
	@Editable				INT
 
--------------------------------------------------------------------------------------------------------------------------
SELECT @date = DATEADD(DAY,1,@date)
SELECT @MaxDate = MAX(EndTime) FROM Auto_opsDataStore.dbo.[OpsDB_Production_Data] WHERE PUID = @puId

IF @MaxDate < @date
BEGIN
	SELECT @date = @MaxDate
END

SELECT @StartTime = DATEADD(DAY,-7,@date)
SELECT @CurrentDate = GETDATE()
--------------------------------------------------------------------------------------------------------------------------
-- Fill #Production table
--------------------------------------------------------------------------------------------------------------------------
	INSERT INTO #Production (
		RcdIdx			,
		EndTime			,
		StartTime       ,
		PPId			,
		ProcessOrder	,
		ProdCode		,
		TeamDesc		,
		ShiftDesc		,
		LineStatus		,
		TotalProduct	,
		GoodProduct		,
		RunningScrap	,
		StartingScrap	,
		TotalScrap		,
		TargetRate		,
		ActualRate		,
		IdealRate		,
		TotalCases		,
		StatFactor		)
	SELECT 
		RcdIdx			,
		EndTime			,
		LAG(EndTime,1, CONVERT(date,EndTime))  OVER (ORDER BY EndTime),
		PPId			,
		ProcessOrder	,
		ProdCode		,
		TeamDesc		,
		ShiftDesc		,
		LineStatus		,
		TotalProduct	,
		GoodProduct		,
		RunningScrap	, 
		StartingScrap	,
		TotalScrap		,
		convert(DECIMAL(18,2), TargetRate)		,
		convert(DECIMAL(18,2), ActualRate)		,
		convert(DECIMAL(18,2), IdealRate)		,
		TotalCases		,
		convert(DECIMAL(18,2), StatFactor)
	FROM Auto_opsDataStore.dbo.[OpsDB_Production_Data] WITH(NOLOCK)
	WHERE 
		DeleteFlag	= 0
	AND PUId		= @puId
	AND EndTime	BETWEEN @StartTime AND @date
	ORDER BY EndTime

	UPDATE #Production 
	SET TotalTime = DATEDIFF(ss, StartTime, EndTime)/60
	
--------------------------------------------------------------------------------------------------------------------------
-- Fill @Headers table
--------------------------------------------------------------------------------------------------------------------------
INSERT INTO	@Headers (HeaderField,HeaderName) 
VALUES 
	('EndTime','Date'), 
	('ProcessOrder','Process Order'),
	('LineStatus','Line Status'),
	('TeamDesc','Team'),
	('ShiftDesc','Shift'),
	('ProdCode','Product'),
    ('StartTime' ,'Start Date'),
    ('TotalTime' , 'Total Time')

--------------------------------------------------------------------------------------------------------------------------
-- Fill @Variable table 
--------------------------------------------------------------------------------------------------------------------------
INSERT INTO	@Variable (
			Variable,
			ExtendedInfo) 
SELECT 
	CASE vb.Var_desc
		WHEN 'GoodProductAdj'	THEN 'GoodProduct'
		WHEN 'TotalProductAdj'	THEN 'TotalProduct'
		WHEN 'TotalScrapAdj'	THEN 'TotalScrap'
		WHEN 'TotalCasesAdj'	THEN 'TotalCases'
		WHEN 'RunningScrapAdj'	THEN 'RunningScrap'
		WHEN 'StartingScrapAdj' THEN 'StartingScrap'
	END,
	vb1.Extended_Info
FROM Variables_Base_syn vb  (NOLOCK)
JOIN Variables_Base_syn vb1 (NOLOCK) ON vb.Test_Name = vb1.Var_Id
WHERE vb.Var_Desc LIKE '%Adj' 
AND vb.PU_Id = @puId

--------------------------------------------------------------------------------------------------------------------------
-- Return ResultSet
-- First we obtain the production which have an Adjust variable associated 
--------------------------------------------------------------------------------------------------------------------------

SELECT @VariablesOfInterest = COALESCE(@VariablesOfInterest+',' , '') + CONVERT(NVARCHAR,Variable)
FROM @Variable
ORDER BY Variable

--------------------------------------------------------------------------------------------------------------------------		
-- Return Production Row data filtered
--------------------------------------------------------------------------------------------------------------------------


SET @Query = 'SELECT '+ISNULL(@VariablesOfInterest+',','')+'RcdIdx,
			EndTime,
			StartTime,
			convert(DECIMAL(18,2), TotalTime) AS ''TotalTime'',
			ProcessOrder,
			ProdCode,
			TeamDesc,
			ShiftDesc,
			LineStatus,
			TargetRate,
			ActualRate,
			IdealRate,
			StatFactor FROM #Production WITH(NOLOCK)
		ORDER BY EndTime'

EXEC sp_executesql @Query

--------------------------------------------------------------------------------------------------------------------------		
-- Locked Good Product when it is calculated from Total Cases
--------------------------------------------------------------------------------------------------------------------------		
DELETE FROM @Variable
WHERE Variable = 'GoodProduct'
AND EXISTS(SELECT * FROM @Variable
			WHERE ExtendedInfo = 'POTGoodProduct')
--------------------------------------------------------------------------------------------------------------------------		
-- Return @Headers
--------------------------------------------------------------------------------------------------------------------------
SELECT
    HeaderField
	, HeaderName
FROM @Headers

--------------------------------------------------------------------------------------------------------------------------		
-- Return @Variable
--------------------------------------------------------------------------------------------------------------------------
SELECT
    Variable
FROM @Variable

--------------------------------------------------------------------------------------------------------------------------		
-- Return Editables columns
--------------------------------------------------------------------------------------------------------------------------

SELECT @Editable = CASE WHEN @group = 'adm' THEN 168
						WHEN @group = 'mng' THEN 36
						ELSE 0
						END

SELECT
    RcdIdx AS Editable,EndTime
FROM #Production
WHERE 
	EndTime >= DATEADD(hh, @Editable * -1, @CurrentDate)
    AND EndTime <> @MaxDate
	AND @group <> 'op'
ORDER BY [EndTime]

--------------------------------------------------------------------------------------------------------------------------		
-- Return PO Information
--------------------------------------------------------------------------------------------------------------------------
SELECT
    Process_Order			AS ProcessOrder,
    Actual_Start_Time		AS StartTime,
    Actual_End_Time			AS EndTime,
    Actual_Good_Quantity	AS GoodQuantity,
    Adjusted_Quantity		AS AdjustedQuantity
FROM Production_Plan_syn WITH(NOLOCK)
WHERE PP_Id IN (
	SELECT PPId
FROM #Production WITH(NOLOCK)
)


	
DROP TABLE #Production

GO

GRANT EXECUTE ON OBJECT ::[dbo].[spLocal_GetProductionDisplay] TO [OpDBManager];
GO
