USE [Auto_opsDataStore]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'spLocal_Auto_opsDataStore_AdjustProductionValue' AND Routine_Type = 'PROCEDURE')
BEGIN
	DROP PROCEDURE [dbo].[spLocal_Auto_opsDataStore_AdjustProductionValue]
END
GO

------------------------------------------------------------------------------------------------------------------------
---- Prototype definition
------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_Auto_opsDataStore_AdjustProductionValue',
		@Version	= '1.9'


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
-- 										OPS Database Stored Procedure											--	
-- This Script will create a new record in dbo.Test table with the adjusted production value for			 	--
--											a specifict variable												--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0	2020-06-02		Carreno Maximiliano		Initial Development												--
-- 1.1	2020-07-17		Carreno Maximiliano		Add filter to find the GoodProduct variable to adj				--
-- 1.2	2020-07-29		Carreno Maximiliano		Find TotalCase variable to adjust by test_name					--
-- 1.3  2020-11-04      Villarreal Damian		Fixed OP issue                                                  --
-- 1.4	2020-11-05		Martin Casalis			Fixed permissions
-- 1.5	2021-04-13		Daniela Giraudi			Fixed issue with calculation tied with adjusted variables.      --
-- 1.6	2021-05-31		Francisco Gil			Independence of flag TotalOrGoodProduct, now we search the new variables by the Alias
-- 1.7  2021-07-01		Daniela Giraudi			PRB0084120      --
-- 1.8	2021-07-27		Martin Casalis			Fixed Total Cases alias when it is a calculation
-- 1.9	2022-03-14		Martin Casalis			FO-05163: Update TS field when an adjustment is made
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

CREATE PROCEDURE [dbo].[spLocal_Auto_opsDataStore_AdjustProductionValue]
--DECLARE
	@rcdIdx INTEGER,
	@varDesc NVARCHAR(255),
	@value NVARCHAR(255),
	@Username NVARCHAR(255) = NULL,
	@group NVARCHAR(3)

--------------------------------------------------------------------------------------------------	
--WITH ENCRYPTION 
AS

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
SET NOCOUNT ON;

--SELECT 
--	@rcdIdx = 139659,	
--	@varDesc ='TotalCases',
--	@value =0,
--	@Username= 'GIRAUDI.DG',
--	@group = 'adm'

DECLARE
	@RetCode				INTEGER,
	@PLId					INTEGER,
	@PURawId				INTEGER,
	@Total_Or_Good_Product	INTEGER,
	@PUId					INTEGER,
	@VarId					INTEGER,
	@AliasName				VARCHAR(50),
	@Extended				VARCHAR(50),
	@VarToAdj				VARCHAR(50),
	@VarToAdjInt			VARCHAR(50),
	@UserId					INTEGER,
	@sqlStr					NVARCHAR(2000),
	@PUColumnVariable		VARCHAR(50),
	@ResultOn				DATETIME,
	@SQLQuery				NVARCHAR(MAX),
	-- OUTPUT
	@TestId					BIGINT,
	@EntryOn				DATETIME,
	@Total_Product_IsActive INTEGER 

	-------------------------------------------------------------------------------------------------------------------------------
	-------------------------------------- GET PUID, VARID, AND VARIABLES TO MAKE THE ADJUST --------------------------------------
	
	SELECT 
		@PLId		= PLId		,
		@ResultOn	= EndTime	,
		@PURawId	= PUID
	FROM [dbo].[OpsDB_Production_Data] WITH(NOLOCK)
	WHERE RcdIdx = @rcdIdx

	--Check if Total Product variable is actived.
	SELECT @Total_Product_IsActive= Is_Active FROM Variables_Base_syn WITH(NOLOCK) WHERE PU_ID= @PURawId AND Test_Name='POTTotalProduct'
	--

	SELECT @PUColumnVariable = CASE WHEN @varDesc = 'TotalCases'
										THEN 'POTTotalCases'
									WHEN @varDesc = 'TotalProduct' 
										THEN 'POTTotalProduct'
									WHEN @varDesc = 'GoodProduct' 
										THEN 'POTGoodProduct'
									WHEN @varDesc = 'TotalScrap'
										THEN 'Waste_Variable'
									WHEN @varDesc = 'RunningScrap'
										THEN 'POTRunningScrap'
									WHEN @varDesc = 'StartingScrap'
										THEN 'POTStartingScrap'
									ELSE NULL
								END 

	IF @PUColumnVariable IS NOT NULL
	BEGIN

		IF  @varDesc IN ('TotalScrap') 
		BEGIN
			SET @sqlStr = 'SELECT @VarId = '+ @PUColumnVariable +' FROM Prod_Units_Base_syn WITH(NOLOCK) WHERE '+ @PUColumnVariable +' IS NOT NULL AND PU_Id = ' + convert(varchar,@PURawId)
		END
		ELSE IF @varDesc IN ('TotalCases') OR @varDesc IN ('RunningScrap', 'StartingScrap') OR @varDesc IN ('TotalProduct', 'GoodProduct')
		BEGIN
			SET @sqlStr = 'SELECT @VarId = Var_Id FROM Variables_Base_syn WITH(NOLOCK) WHERE Test_Name LIKE ''' + @PUColumnVariable + '%'' AND PU_Id = ' + convert(varchar,@PURawId)
		END

		EXEC Sp_executesql
		  @sqlStr,
		  N'@VarId INT OUTPUT',
		  @VarId OUTPUT
	END

	SELECT TOP 1 @VarToAdj = Var_Id FROM Variables_Base_syn WITH(NOLOCK)
	WHERE Test_Name = CONVERT(VARCHAR,@VarId )

	SELECT @AliasName  = Test_Name		FROM Variables_Base_syn WITH(NOLOCK) WHERE Var_Id =@VarId
	SELECT @Extended	= Extended_Info	FROM Variables_Base_syn WITH(NOLOCK) WHERE Var_Id =@VarId
  
	-------------------------------------- GET PUID, VARID, AND VARIABLES TO MAKE THE ADJUST --------------------------------------
	-------------------------------------------------------------------------------------------------------------------------------

IF( @VarToAdj IS NOT NULL AND @VarToAdj  != '' AND ISNUMERIC(@VarToAdj) = 1 )
BEGIN

	SELECT @VarToAdjInt = CONVERT(INTEGER, @VarToAdj)
	
	SELECT @UserId = User_Id FROM Users_Base_syn WITH(NOLOCK)
	WHERE Username = CASE 
						WHEN @Username IS NULL THEN 'OpDBManager'
						ELSE @Username
					END

	IF( @UserId IS NULL )
	BEGIN
		RAISERROR('The user no exist in PPA.',16,1);
		RETURN;
	END

	-------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------- VALIDATE USER ------------------------------------------------------------------
	IF @group = 'adm' AND @ResultOn < DATEADD(d, -7,GETDATE())
	BEGIN
		RAISERROR('The admin does not have permissions to modify.',16,1);
		RETURN;
	END
	IF @group = 'mng' AND @ResultOn < DATEADD(HOUR,-36,GETDATE())
	BEGIN
		RAISERROR('The manager does not have permissions to modify.',16,1);
		RETURN;
	END
	IF @group = 'op' AND @ResultOn < DATEADD(HOUR, 0,GETDATE())
	BEGIN
		RAISERROR('The operator does not have permissions to modify.',16,1);
		RETURN;
	END
	-------------------------------------------------------------------------------------------------------------------------------
	---------------------------------------------- UPDATE Proficy DATA FOR DISPLAY ------------------------------------------------
	BEGIN TRY
		EXECUTE @RetCode = spServer_DBMgrUpdTest2_syn
		  @VarToAdjInt,
		  @UserId,
		  0,
		  @value,
		  @ResultOn,
		  0,
		  NULL,
		  NULL,
		  NULL, --@EventId,
		  @PUId OUTPUT,
		  @TestId OUTPUT,
		  @EntryOn OUTPUT;
	END TRY
	BEGIN CATCH
		RAISERROR('Variable no UPDATED in Proficy',16,1);
		RETURN;
	END CATCH

	IF ((@RetCode <> 0) And (@RetCode <> 3))
	BEGIN
		RAISERROR('Variable no UPDATED in Proficy',16,1);
		RETURN
	END
	---------------------------------------------- UPDATE Proficy DATA FOR DISPLAY ------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------------------

	-------------------------------------------------------------------------------------------------------------------------------
	----------------------------------------------UPDATE iODS DATA FOR DISPLAY-----------------------------------------------------
	BEGIN TRY
			IF  @varDesc NOT IN  ('TotalCases','RunningScrap','StartingScrap','TotalScrap', 'GoodProduct') 
			     EXEC('UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] SET '+ @varDesc +' = '+ @value +' WHERE RcdIdx = '+ @rcdIdx)
			ELSE
			BEGIN
				IF @varDesc ='TotalCases'
					BEGIN
						IF @AliasName= 'POTTotalCases'   
							BEGIN
								IF @Extended <> 'POTGoodProduct' OR @Extended IS NULL
								BEGIN
									SELECT @SQLQuery = 'UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] 
										SET '+ @varDesc +' = '+ @value +' ,
										ConvertedCases = ('+ @value +' * ISNULL(FirstPackCount,1) * ISNULL(SecondPackCount,1)),
										StatUnits = ('+ @value +' * ISNULL(StatFactor,1)),
										TS = GETDATE() 
                                        WHERE RcdIdx = '+ CONVERT(VARCHAR,@rcdIdx)

									EXEC(@SQLQuery)
								END
								ELSE
								BEGIN
									SELECT @SQLQuery = 'UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] 
										SET '+ @varDesc +' = '+ @value +' ,
										GoodProduct = ('+ @value +' * ISNULL(FirstPackCount,1)),
										ConvertedCases = ('+ @value +' * ISNULL(FirstPackCount,1) * ISNULL(SecondPackCount,1)),
										StatUnits = ('+ @value +' * ISNULL(StatFactor,1)) ,
										TS = GETDATE() 
                                        WHERE RcdIdx = '+ CONVERT(VARCHAR,@rcdIdx)

									EXEC(@SQLQuery)
								END

							END
						ELSE 
						BEGIN
							IF  @AliasName  LIKE 'POTTotalCases%POTGoodProduct'  
								BEGIN
									SELECT @SQLQuery = 'UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] 
									SET '+ @varDesc +' = '+ @value +' ,
									GoodProduct = '+ @value +' ,
									ConvertedCases   = ('+ @value +' * ISNULL(FirstPackCount,1) * ISNULL(SecondPackCount,1)),
									StatUnits = ('+ @value +' * ISNULL(StatFactor,1)) ,
									TS = GETDATE() 
                                    WHERE RcdIdx = '+ CONVERT(VARCHAR,@rcdIdx)

									EXEC(@SQLQuery)
								END
						END
				   END
					
				ELSE 
					BEGIN
						IF @varDesc='RunningScrap' OR  @varDesc='StartingScrap'  
							BEGIN
									SELECT @SQLQuery = 'UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] 
									  SET '+ @varDesc + '= '+ @value +',
										TotalScrap =  CASE WHEN '''+ @VarDesc +''' = ''RunningScrap'' THEN '+ @Value +'+ StartingScrap ELSE '+ @Value +' + RunningScrap END,
										TotalProduct= CASE WHEN '''+ @VarDesc +''' = ''RunningScrap'' THEN '+ @Value +'+ StartingScrap + GoodProduct ELSE '+ @Value +' + RunningScrap + GoodProduct END,
										TS = GETDATE() 
										WHERE RcdIdx = '+ CONVERT(VARCHAR,@rcdIdx)

									EXEC(@SQLQuery)
							END 
							ELSE
							BEGIN
								IF  @varDesc='TotalScrap' OR  @varDesc='GoodProduct'
								 BEGIN
								 IF ISNULL(@Total_Product_IsActive,0) = 1
								 BEGIN
									SELECT @SQLQuery = 'UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] 
									      SET '+ @varDesc +' = '+ @value +',
											TotalProduct = CASE WHEN '''+ @VarDesc +''' = ''TotalScrap'' THEN '+ @Value +'+ GoodProduct ELSE '+ @Value +' + TotalScrap END,
											TS = GETDATE() 
											WHERE RcdIdx = '+ CONVERT(VARCHAR,@rcdIdx)
								END
								ELSE
								BEGIN
									SELECT @SQLQuery = 'UPDATE Auto_opsDataStore.dbo.[OpsDB_Production_Data] 
									      SET '+ @varDesc +' = '+ @value +',
											TS = GETDATE() 
											WHERE RcdIdx = '+ CONVERT(VARCHAR,@rcdIdx)
								END 
									EXEC(@SQLQuery)
								END
						   END
			    END
			END			

	END TRY
	BEGIN CATCH
		RAISERROR('Variable no UPDATED in iODS',16,1);
	RETURN;
		END CATCH
	----------------------------------------------UPDATE iODS DATA FOR DISPLAY-----------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------------------

END
ELSE
BEGIN
	RAISERROR('Adjusted Variable is not configurated',16,1);
    RETURN;
END

SELECT @PUId
SELECT @TestId
SELECT @EntryOn 

GO


GRANT EXECUTE ON OBJECT ::[dbo].[spLocal_Auto_opsDataStore_AdjustProductionValue] TO [OpDBManager];
GO

USE GBDB
GO

GRANT EXECUTE ON [dbo].[spServer_DBMgrUpdTest2] to OpDBManager
GO
