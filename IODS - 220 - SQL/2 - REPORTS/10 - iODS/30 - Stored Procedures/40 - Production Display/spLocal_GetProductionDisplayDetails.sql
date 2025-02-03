
USE [Auto_opsDataStore]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'spLocal_GetProductionDisplayDetails' AND Routine_Type = 'PROCEDURE')
BEGIN
	DROP PROCEDURE [dbo].[spLocal_GetProductionDisplayDetails]
END
GO

------------------------------------------------------------------------------------------------------------------------
---- Prototype definition
------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_GetProductionDisplayDetails',
		@Version	= '1.0'


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

-------------------------------------------------------------------------------------------------------------
--	Description:
--	===========================================================================
--	Returns the selected measure (TotalProduct, GoodProduct or Scrap) from the Auto_opsDataStore
--	and the Test values of GBDB which have been computed to obtain those values.

--	@PUId				:	KeyId of the Prod_Units_Base_syn table
--	@EndTime			:	Final execution time of the variable
--	@MeasureSelection	:	Flag that allows us to select which measure we want to corroborate
--	                        TotalProduct, GoodProduct, TotalScrap

--	CALLED BY:  Production Display
--	Revision 	    Date				Who							                    What
--	========		=====				====						                    =====
--	1.0				2020-08-10			Damian Villarreal and Francisco Gil 		    Initial Release
--	                                    (Arido Software)
-------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[spLocal_GetProductionDisplayDetails]
--DECLARE 
	@PUId INT, 
	@EndTime DATETIME, 
	@MeasureSelection NVARCHAR(50)

--WITH ENCRYPTION 
AS

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
SET NOCOUNT ON;


-------------------------------------------------------------------------------------------------------------
-- Testing Section
--SELECT 
--@PUId = 2
--,@EndTime = '2020-08-22 15:00:00'
--,@MeasureSelection = 'GoodProduct'	--'TotalProduct'--'TotalCases'--	

--exec 	[spLocal_GetProductionDisplayDetails]  2,'2020-08-22 15:00:00','GoodProduct'
-------------------------------------------------------------------------------------------------------------

CREATE TABLE #tblProductionRawData (    
	VarDesc					NVARCHAR(255)     
	,VarId			   		INT
	,ResultOn       		DATETIME
	,EntryOn				DATETIME
	,Result          		FLOAT
	,EntryBy				NVARCHAR(255))

DECLARE 
    @StartTime				DATETIME
    ,@TotalProduct			FLOAT
	,@GoodProduct			FLOAT
	,@Scrap 				FLOAT
    ,@TotalOrGoodProduct	BIT
	,@VarId					INT
	,@AdjVarId				INT
	,@VarDesc				NVARCHAR(255)
	,@AdjVarDesc			NVARCHAR(255)

SELECT @StartTime = StartTime 
FROM Auto_opsDataStore.dbo.Opsdb_Production_Data (NOLOCK) 
WHERE PUId = @PUId 
AND EndTime = @EndTime
AND DeleteFlag = 0

SELECT @TotalOrGoodProduct = Total_Or_Good_Product 
FROM Prod_Units_Base_syn (NOLOCK) 
WHERE PU_Id = @PUId
	
IF @MeasureSelection = 'TotalScrap'
BEGIN
	SELECT	 @VarId = vb.Var_Id
			,@VarDesc = vb.Var_Desc
    FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
    JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
												AND pub.PU_Id = vb.PU_Id
												AND pub.Waste_Variable = vb.Var_Id 
END
ELSE IF @MeasureSelection = 'StartingScrap'
BEGIN
	SELECT	 @VarId = vb.Var_Id
			,@VarDesc = vb.Var_Desc
    FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
    JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
												AND pub.PU_Id = vb.PU_Id
												AND vb.Test_Name = 'POTStartingScrap'
END
ELSE IF @MeasureSelection = 'RunningScrap'
BEGIN
	SELECT	 @VarId = vb.Var_Id
			,@VarDesc = vb.Var_Desc
    FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
    JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
												AND pub.PU_Id = vb.PU_Id
												AND vb.Test_Name = 'POTRunningScrap'
END
ELSE IF @MeasureSelection = 'TotalCases'
BEGIN
	SELECT	 @VarId = vb.Var_Id
			,@VarDesc = vb.Var_Desc
    FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
    JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
												AND pub.PU_Id = vb.PU_Id
												AND vb.Test_Name = 'POTTotalCases'
END
ELSE IF @MeasureSelection = 'TotalProduct'
BEGIN
	IF @TotalOrGoodProduct = 1
	BEGIN
		SELECT	 @VarId = vb.Var_Id
				,@VarDesc = vb.Var_Desc
		FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
		JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
													AND pub.PU_Id = vb.PU_Id
													AND pub.Production_Variable = vb.Var_Id 
	END
	ELSE
	BEGIN
		SELECT	 @VarId = vb.Var_Id
				,@VarDesc = vb.Var_Desc
		FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
		JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
													AND pub.PU_Id = vb.PU_Id
													AND vb.Test_Name = 'POTTotalProduct'
	END
END
ELSE IF @MeasureSelection = 'GoodProduct'
BEGIN		
	IF @TotalOrGoodProduct = 0
	BEGIN
		SELECT	 @VarId = vb.Var_Id
				,@VarDesc = vb.Var_Desc
		FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
		JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
													AND pub.PU_Id = vb.PU_Id
													AND pub.Production_Variable = vb.Var_Id 
	END
	ELSE
	BEGIN
		SELECT	 @VarId = vb.Var_Id
				,@VarDesc = vb.Var_Desc
		FROM dbo.Prod_Units_Base_syn	pub (NOLOCK)
		JOIN dbo.Variables_Base_syn		vb	(NOLOCK)	ON pub.PU_Id = @PUId
													AND pub.PU_Id = vb.PU_Id
													AND vb.Test_Name = 'POTGoodProduct'
	END
END
		
SELECT	 @AdjVarId = Var_Id
		,@AdjVarDesc = Var_Desc
FROM dbo.Variables_Base_syn	(NOLOCK)	
WHERE PU_Id = @PUId
AND Test_Name = CONVERT(NVARCHAR,@VarId)
	
--SELECT @VarId,@VarDesc,@AdjVarId,@AdjVarDesc
		
INSERT INTO #tblProductionRawData
		(VarId		
		,VarDesc		
		,ResultOn 
		,EntryOn  
		,Result   
		,EntryBy)
SELECT 
		 @VarId
		,@VarDesc
		,Result_on
		,Entry_on
		,Result
		,Username
FROM dbo.Tests_syn		t (NOLOCK)
JOIN dbo.Users_Base_syn	u (NOLOCK) ON t.Entry_By = u.User_Id
WHERE Result_on > @StartTime
    AND Result_on <= @EndTime
    AND Var_Id = @VarId
	AND Result IS NOT NULL
				
INSERT INTO #tblProductionRawData
		(VarId		
		,VarDesc		
		,ResultOn 
		,EntryOn  
		,Result
		,EntryBy)
SELECT 
		 @AdjVarId
		,@AdjVarDesc
		,Result_on
		,Entry_on
		,Result - (SELECT ISNULL(SUM(Result),0) FROM #tblProductionRawData WHERE VarId = @VarId)
		,Username
FROM dbo.Tests_syn		t (NOLOCK)
JOIN dbo.Users_Base_syn	u (NOLOCK) ON t.Entry_By = u.User_Id
WHERE Result_on = @EndTime
    AND Var_Id = @AdjVarId
	AND Result IS NOT NULL
	AND Result > 0


SELECT	
		 VarDesc
		,ResultOn
		,Result 
		,EntryBy
FROM #tblProductionRawData
ORDER BY ResultOn

DROP TABLE #tblProductionRawData
GO

GRANT EXECUTE ON OBJECT ::[dbo].[spLocal_GetProductionDisplayDetails] TO [OpDBManager];
GO