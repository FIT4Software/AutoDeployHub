SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

---------------------------------------------------------------------------------------------------------------------------
------ Drop Stored Procedure
---------------------------------------------------------------------------------------------------------------------------
IF EXISTS (
			SELECT * FROM dbo.sysobjects WITH(NOLOCK)
				WHERE Id = OBJECT_ID(N'[dbo].[spLocal_PositiveRelease]') 
				AND OBJECTPROPERTY(id, N'IsProcedure') = 1					
			)
DROP PROCEDURE [dbo].[spLocal_PositiveRelease]

GO


----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_PositiveRelease',
		@Inputs		= 6, 
		@Version	= '1.0.2'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================

SELECT @AppId = MAX(App_Id) + 1 
		FROM dbo.AppVersions WITH(NOLOCK)

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions WITH(NOLOCK)
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
		App_Id,
		App_name,
		App_version,
		Modified_On )
	VALUES (
		@AppId, 
		@SP_Name,
		@Version,
		GETDATE())
END
--=====================================================================================================================
SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 

GO
-------------------------------------------------------------------------------------------------------------------------
---- Positive Release
----
---- 2018-08-17		Martin Casalis						Arido Software
-------------------------------------------------------------------------------------------------------------------------

---- 	----------Based on v4.0-----------
---- 	---Reference for other versions---
---- 	legacy excel v2.9	=> iODS v1.0.x
---- 	legacy excel v3.9 	=> iODS v1.1.x
---- 	legacy excel v4.0 	=> iODS v1.2.x
----	----------------------------------

-------------------------------------------------------------------------------------------------------------------------
---- EDIT HISTORY: 
-------------------------------------------------------------------------------------------------------------------------
---- ========		====	  		====					=====
---- 1.0.0			2018-08-17		Martin Casalis			Initial Release
---- 1.0.1			2019-08-13		N/A						New version convention
---- 1.0.2			2019-08-28		Damian Campana			Capability to filter with the time option 'Last Week'  
----=====================================================================================================================
--------------------------------------------------[Creation Of SP]-------------------------------------------------------
CREATE PROCEDURE [dbo].[spLocal_PositiveRelease]  
--------------------------------------------------------------------------------------------------------------------------------------  
--DECLARE 
	@in_TimeOption			INT				,
	@in_StartTime			DATETIME		,       -- Start Time of Sample SET  
	@in_EndTime				DATETIME		,       -- END Time of Sample SET      
	@PLIDList				NVARCHAR(100)	,
	@int_RptGroupBy			INT				,		-- 0 None, 1 Product, 2 PO 
	@int_ShowDetails		INT				,
	@INT_RptPosMin 			INT				,
	@INT_RptNegMin			INT		
	
	--WITH ENCRYPTION
	AS  
	SET NOCOUNT ON

	DECLARE 
			@Owner							NVARCHAR(200)	= ''					,
			@ReportName						NVARCHAR(20)	= 'Positive Release'	,
			@QFactorPrimaryUDF				NVARCHAR(200)	= ''					,  
			@QFactorPrimaryFilters			NVARCHAR(200)	= ''					,  
			@QFactorTypeUDF					NVARCHAR(200)	= ''					,  
			@QFactorTypeFilters				NVARCHAR(200)	= ''					,
			@str_PUGExcludedFromDT			NVARCHAR(500)	= ''					,  
			@int_HourInterval				INT				= 0			
			-- @INT_RptPosMin 					INT				,
			-- @INT_RptNegMin					INT				,
			
--*******************************************************************************************************************  
-- GET GLOBAL PARAMETERS  
--*******************************************************************************************************************  
	-- SELECT @INT_RptPosMin 			= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'INT_RptPosMin')		
	-- SELECT @INT_RptNegMin 			= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'INT_RptNegMin')		
	SELECT @QFactorPrimaryUDF 		= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'QFactorPrimaryUDF')	
	SELECT @QFactorPrimaryFilters	= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'QFactorPrimaryFilters')
	SELECT @QFactorTypeUDF 			= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'QFactorTypeUDF')		
	SELECT @QFactorTypeFilters 		= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'QFactorTypeFilters')	
	SELECT @str_PUGExcludedFromDT	= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'str_PUGExcludedFromDT')
	SELECT @int_HourInterval		= [OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'intHourInterval')
	
---------------------------------------------------------------------------------------------------------------------  
--*******************************************************************************************************************  
-- DECLARE VARIABLE TABLES  
--*******************************************************************************************************************  
DECLARE @TotalTests TABLE (  
        PU_Id			   INT,  
        PUG_ID			   INT,  
        PUGDesc            VARCHAR(50),  
        Var_id             INT,  
        Result_ON          DATETIME,  
        Result             VARCHAR(50),  
        Status             VARCHAR(10),  
        Include			   INT)  
  
  
DECLARE @ProdUnitPrdPath TABLE  
      (   
        PU_Id				INT,  
        PU_Desc				VARCHAR(200),  
        PUG_Id				INT,  
        PUG_Desc			VARCHAR(200),  
        PL_Id				INT,  
        Path_Id				INT,  
        Unit_Order			INT,  
        Class				INT,  
        IsProductionPoint   INT,  
        --STLSUnit     INT, -- In CASE is not using PrdUnitPath  
        TestCompleteVarId   INT,  
        SheetId      INT,  
        QVReestPUGId    INT,  
        QAReestPUGId    INT,  
        QVReEvalPUGId    INT,  
        QAReEvalPUGId    INT,  
        QAReEstVarId    INT,  
        QAReEvalVarId    INT,  
        QAReEvalTimeVarId   INT,  
        QVReEvalVarId    INT,  
        QVReEstVarId    INT,  
        QVReEvalTimeVarId   INT )  
        
          

--------------------------------------------------------------------------------------------------------  
DECLARE @OpenIssues TABLE (  
        PU_Id      INT   ,  
        PUG_Id      INT   ,          
        PUGDesc      VARCHAR(50) ,  
        Type      NVARCHAR(100),  
        Result      VARCHAR(100) ,   
        Result_On     DATETIME ,  
        Entry_On     DATETIME ,  
        Var_Id      INT   ,  
        Var_Desc     VARCHAR(50) ,  
        AlarmStatus     NVARCHAR(20),  
        Duration     NVARCHAR(20),  
        Action1      VARCHAR(1000),  
        Comments     VARCHAR(1000),  
        Defect      INT,
        Isopen        INT,
        IDAlarm       INT)  
--------------------------------------------------------------------------------------------------------  
DECLARE @PosRelGrouping TABLE (  
        PRGId      INT IDENTITY,  
        PLId      INT  ,  
        StartTime     DATETIME,  
        EndTime      DATETIME,  
        PLDesc      NVARCHAR(100),  
        ProdId      INT,  
        ProdDesc     NVARCHAR(100),  
        ProdCode     NVARCHAR(1200),  
         PO       NVARCHAR(1200),  
        Batch      NVARCHAR(1200),  
        MinorGrouping    NVARCHAR(100),  
        VolumeCount     INT,  
        PathId      INT ,
		HybridConfig	NVARCHAR(20) 
        )   
--------------------------------------------------------------------------------------------------------  
DECLARE @UDEBatch TABLE  (  
        BatchRow     INT IDENTITY,  
        StartTime     DATETIME,  
        EndTime      DATETIME,  
        BatchNumber     NVARCHAR(100)  
       )  
--------------------------------------------------------------------------------------------------------  
DECLARE @Production TABLE (  
        PLId      INT  ,  
        StartTime     DATETIME,  
        EndTime      DATETIME,          
        ProdId      INT,  
        ProdCode     VARCHAR(50),  
        PathId      INT,  
        ProdRow      INT IDENTITY)  
--------------------------------------------------------------------------------------------------------  
DECLARE @ProductionPlan TABLE (  
        PLId      INT  ,  
        StartTime     DATETIME,  
        EndTime     DATETIME,          
        ProdId      INT,  
        PO			NVARCHAR(100),
        Batch		NVARCHAR(100),
        PathId      INT,  
		HybridConf	NVARCHAR(20),
        PORow      INT IDENTITY)  
  
--------------------------------------------------------------------------------------------------------  
  
DECLARE @Temp_language_data TABLE (     
        Prompt_Number     VARCHAR(20),   
        Prompt_String     VARCHAR(200), 
        language_id     INT)  
  
--------------------------------------------------------------------------------------------------------  
DECLARE @RS1Summary TABLE (   
        PUId      INT   ,  
        PUGId      INT   ,  
        Category        NVARCHAR(50) ,          
           Col_Count             INT   ,  
        Col_CountNI     INT   ,  
        Category_Status    NVARCHAR(50) ,  
        Sort_Order        INT   ,  
        txt_Signature    NVARCHAR(50) ,  
        txt_glbSignature   NVARCHAR(50))   
--------------------------------------------------------------------------------------------------------  
DECLARE @RS2Summary TABLE (   
        PUId      INT   ,  
        PUGId      INT   ,  
        Category        NVARCHAR(50) ,          
           Col_Count             INT   ,  
        Col_CountNI     INT   ,  
        Col_OOS      INT   ,  
        Dummy1      INT   ,  
        Category_Status    NVARCHAR(50) ,  
        PUGGRouping     NVARCHAR(50))   
--------------------------------------------------------------------------------------------------------  
DECLARE @RS3Summary TABLE (   
        Category        NVARCHAR(50) ,  
        Perc_Completion    INT   ,  
        Perc_Compliance    INT   ,  
           Col_Completion           INT   ,  
        Col_Compliance    INT   ,  
        Category_Status    NVARCHAR(50) ,  
        TestCount     INT   )   
--------------------------------------------------------------------------------------------------------  
DECLARE @RS4Summary TABLE (   
        Category        NVARCHAR(50) ,          
        Col_Count             INT   ,  
        Col_CountNI     INT   ,  
        Dummy1      INT   ,  
        Dummy2      INT   ,  
        Dummy3      INT   ,  
        Category_Status    NVARCHAR(50) )   
--------------------------------------------------------------------------------------------------------  
DECLARE @RS5Summary TABLE (   
        Category        NVARCHAR(50) ,          
           StartTime     DATETIME , 
           EndTime       DATETIME , 
        Type      NVARCHAR(50) ,  
        Reason      NVARCHAR(100) ,  
        PUDesc      NVARCHAR(50) ,  
        Comments     NVARCHAR(1000))   
--------------------------------------------------------------------------------------------------------  
DECLARE @RS6Summary TABLE (   
        Category        NVARCHAR(50) ,          
           StartTime     DATETIME ,  
        Duration     NVARCHAR(50) ,  
        Reason      NVARCHAR(1000) ,  
        PUDesc      NVARCHAR(50) ,  
        Comments     NVARCHAR(1000))   
--------------------------------------------------------------------------------------------------------  
DECLARE @RS7Summary TABLE (   
        Category        NVARCHAR(50) ,          
           StartTime     DATETIME  ,  
        Type      NVARCHAR(50) ,  
        Reason      NVARCHAR(50) ,  
        PUDesc      NVARCHAR(50) ,  
        Category_Status    NVARCHAR(50) )  
--------------------------------------------------------------------------------------------------------  
DECLARE @OutPut TABLE (  
        Col1      NVARCHAR(200) ,  
        Col2      NVARCHAR(200) ,  
        Col3      NVARCHAR(200) ,  
        Col4      NVARCHAR(200) ,  
        Col5      NVARCHAR(200) ,  
        Col6      NVARCHAR(200) )   
--------------------------------------------------------------------------------------------------------  
-- Q-FACTORS Variable Tables  
--------------------------------------------------------------------------------------------------------  
DECLARE @QFactorPrimary TABLE  
  (      PLId      INT,  
         PUId      INT,  
         VarId      INT,  
        DataTypeId     INT)  
--------------------------------------------------------------------------------------------------------  
DECLARE @QFactorType TABLE  
  (      PLId      INT,  
         PUId      INT,  
         VarId      INT,  
         Type      NVARCHAR(100))  
--------------------------------------------------------------------------------------------------------  
DECLARE @QFactorTests TABLE  
  (      PLId			INT,  
        PUId			INT,  
        PUGDesc			NVARCHAR(50),  
        VarId      INT,  
        Var_Desc     NVARCHAR(200),  
        Type      NVARCHAR(100),  
         ProdId      INT,  
         ResultOn     DATETIME,  
        EntryOn      DATETIME,  
        Result      NVARCHAR(25),  
        L_Reject     NVARCHAR(25),  
        Target      NVARCHAR(25),  
        U_Reject     NVARCHAR(25),  
        Defect      INT     ,  
        VariableType    NVARCHAR(50),  
        Status      NVARCHAR(20) ,  
        AlarmId      INT  ,  
        Ack       INT  ,  
        Action1      NVARCHAR(300)  ,  
        Cause1      NVARCHAR(300)  ,   
        AlarmEndTime    DATETIME ,  
        AlarmStatus     NVARCHAR(20) ,  
        AlarmComment    NVARCHAR(20),  
        AlarmMessage    NVARCHAR(200),  
        Duration     NVARCHAR(20))  

--------------------------------------------------------------------------------------------------------------------  
DECLARE @tblDowntimes TABLE (
		PLID			INT			,
		PUId			INT			,
		StartTime		DATETIME	,
		EndTime			DATETIME	,
		STLookUP		DATETIME	,
		ETLookUP		DATETIME		)
		 

--*******************************************************************************************************************  
-- CREATE TEMPORARY TABLES  
--*******************************************************************************************************************  
  
CREATE TABLE #PLIDList  (  
       RCDID			INT,         
       PL_ID			INT,  
       PL_Desc			NVARCHAR(200),  
       HasPrdPath		NVARCHAR(3))  

--------------------------------------------------------------------------------------------------------  
-- CRITERIA List TABLES  
--------------------------------------------------------------------------------------------------------  
CREATE TABLE #QFactorPrimaryFilters (RcdId      INT   ,  
         Value			NVARCHAR(200))  
--------------------------------------------------------------------------------------------------------  
CREATE TABLE #QFactorTypeFilters (RcdId      INT   ,  
         Value			NVARCHAR(200))  
--------------------------------------------------------------------------------------------------------  
CREATE TABLE #PUGExcluded (  
        RcdId			INT			 ,  
        PUGDesc			NVARCHAR(50) ,  
        PUGId			INT				)  
  
--=================================================================================================  
  
-------------------------------------------------------------------------------------------------------------------------------------------------  
-- INTEGER  
-------------------------------------------------------------------------------------------------------------------------------------------------  
DECLARE  
 @UDPDesc		VARCHAR (30),
 @intTableId       INT  ,  
 @intTableFieldId     INT  ,  
 @i         INT  ,  
 @TableIdVar       INT  ,  
 @LocalRPTLanguage     INT  ,   
 @ProdRow       INT  ,  
 @PORow        INT  ,  
 @PRRow        INT  ,  
 @BatchRow       INT  ,  
 @CountPRRow       INT  ,  
 @CountBatchRow      INT  ,  
 @RECNo        INT  ,  
 @PLID        INT  ,  
 @iDet        INT  ,  
 @iRows        INT  ,  
 @intPeriodIncompleteFlag   INT  ,  
 @EventSubtypeId      INT  ,     
 @RS5Count       INT  ,  
 @RS6Count       INT  ,  
 @RS7Count       INT  ,  
 @AlTypeIdVarLimits     INT  ,  
 @AlTypeIdSPC      INT  ,  
 @AlTypeIdSPCGroup     INT  

-------------------------------------------------------------------------------------------------------------------------------------------------  
-- NVARCHAR - VARCHAR  
-------------------------------------------------------------------------------------------------------------------------------------------------  
DECLARE    
 @vchUDPDescDefaultQProdGrps    NVARCHAR(25) ,  
 @vchUDPDescIsAtt      NVARCHAR(25) ,  
 @vchUDPDescCriticality     NVARCHAR(25) ,  
 @vchUDPDescIsTestComplete    NVARCHAR(25) ,  
 @vchUDPDescPUG_PRRGrouping    NVARCHAR(25) ,  
 @vchUDPReestReevDesc     NVARCHAR(25) ,  
 @vchProdCode       NVARCHAR(100) ,  
 @Plant         NVARCHAR(200) ,  
 @QFactorTFVar       NVARCHAR(200) ,   
 @strQualityUnit       NVARCHAR(200) ,  
 @QVReSubdivideScrap      NVARCHAR(25) ,  
 @QVReEstPUGDesc             NVARCHAR(25) ,  
 @QAReEstPUGDesc             NVARCHAR(25) ,  
 @QAReEvalPUGDesc            NVARCHAR(25) ,  
 @QVReEvalPUGDesc            NVARCHAR(25) ,  
 @SpecDesc                  NVARCHAR(25) ,  
 @QAReEstExtInfo             NVARCHAR(25) ,  
 @QAReEvalExtInfo            NVARCHAR(25) ,  
 @QVReEstExtInfo             NVARCHAR(25) ,  
 @QVReEvalExtInfo            NVARCHAR(25) ,  
 @QAReEvalTimeExtInfo        NVARCHAR(25) ,  
 @QVReEvalTimeExtInfo        NVARCHAR(25) ,  
 @ConstOpen                  NVARCHAR(25) ,  
 @QVReEvalConstOpen             NVARCHAR(25) ,  
 @QVReEvalNoDefect            NVARCHAR(25) ,  
 @strPass                 NVARCHAR(25) ,  
 @strFail                 NVARCHAR(25) , 
 @strPassIncPo                 NVARCHAR(25) , 
 @strFailIncPo                 NVARCHAR(25) , 
 @strTestComplete            NVARCHAR(25) ,  
 @strOOS         NVARCHAR(25) ,  
 @strMissingSample            NVARCHAR(25) ,   
 @Pass         NVARCHAR(100) ,  
 @Fail         NVARCHAR(100) ,  
 @PassIncomplete         NVARCHAR(100) ,  
 @FailIncomplete         NVARCHAR(100) ,


 -- Add for search Version  
 @vchAppVersion       NVARCHAR(10) ,  
 @vchRTVersion       NVARCHAR(10) ,  
 @vchSP_name        NVARCHAR(50) ,  
 @vchRT_xlt        NVARCHAR(50)   ,
 @PONull           INT

-------------------------------------------------------------------------------------------------------------------------------------------------  
-- FLOAT  
-------------------------------------------------------------------------------------------------------------------------------------------------  
DECLARE   
 @DBVersiON        FLOAT    
  
  
-------------------------------------------------------------------------------------------------------------------------------------------------  
-- DATETIME  
-------------------------------------------------------------------------------------------------------------------------------------------------  
DECLARE  
 @RptStartTime       DATETIME  ,  
 @RptENDTime        DATETIME  ,    
 @MAX_attrTest       DATETIME  ,  
 @MIN_attrTest       DATETIME  ,  
 @StartTime        DATETIME  ,  
 @EndTime        DATETIME  ,
 @vchTimeOption						NVARCHAR(50) 

--====================================================================================================  
-------------------------------------------------------------------------------------------  
-- GET Proficy Version  
-------------------------------------------------------------------------------------------  
IF ( SELECT  IsNumeric(App_Version)  
    FROM dbo.AppVersions WITH(NOLOCK)   
    WHERE App_Id = 2) = 1  
BEGIN  
  SELECT  @DBVersiON = Convert(Float, App_Version)  
   FROM dbo.AppVersions WITH(NOLOCK)   
   WHERE App_Id = 2  
END  
ELSE  
BEGIN  
  SELECT @DBVersiON = 1.0  
END  

----------------------------------------------------------------------------------------------------------------------------------------
-- Time Options
----------------------------------------------------------------------------------------------------------------------------------------
	SELECT @vchTimeOption = CASE @in_TimeOption
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
		SELECT	@in_StartTime = dtmStartTime,
				@in_EndTime = dtmEndTime
		FROM [dbo].[fnLocal_DDSStartEndTime](@vchTimeOption)

	END


IF @in_TimeOption = 0 
BEGIN 
		SELECT @in_StartTime = @in_StartTime ,@in_EndTime = @in_EndTime  
END
  
-----------------------------------------------------------------------------------------------------------
-- RS1: Start Time, End Time and runtime to display on the report.
-----------------------------------------------------------------------------------------------------------
SELECT @in_StartTime AS 'ReportStartTime' , @in_EndTime AS 'ReportEndTime', GETDATE() AS 'ReportRunTime'
-----------------------------------------------------------------------------------------------------------  
-- POPULATE QFactor Filters  
-----------------------------------------------------------------------------------------------------------  
INSERT INTO #QFactorPrimaryFilters(RCDID, Value)  
EXEC SPCMN_ReportCollectionParsing  
  @PRMCollectionString = @QFactorPrimaryFilters, @PRMFieldDelimiter = null, @PRMRecordDelimiter = '|',   
  @PRMDataType01 = 'NVARCHAR(200)'  
  
INSERT INTO #QFactorTypeFilters(RCDID, Value)  
EXEC SPCMN_ReportCollectionParsing  
  @PRMCollectionString = @QFactorTypeFilters, @PRMFieldDelimiter = null, @PRMRecordDelimiter = '|',   
  @PRMDataType01 = 'NVARCHAR(200)'  
  
  
-----------------------------------------------------------------------------------------------------------  
-- POPULATE PUGs Excluded From DT  
-----------------------------------------------------------------------------------------------------------  
INSERT INTO #PUGExcluded(RCDID, PUGDesc)  
EXEC SPCMN_ReportCollectionParsing  
  @PRMCollectionString = @str_PUGExcludedFromDT, @PRMFieldDelimiter = null, @PRMRecordDelimiter = '|',   
  @PRMDataType01 = 'NVARCHAR(200)'  
  
-----------------------------------------------------------------------------------------------------------  
-- GET LINES AND PRODUCTION UNITS FROM PRODUCTION PATH AND FROM Standard Configuration  
-----------------------------------------------------------------------------------------------------------  
IF LEN(IsNull(@PLIdList, '')) > 0   
AND @PLIdList <> '!NULL'    
BEGIN  
   INSERT INTO #PLIDList(  RCDID,   
          PL_Id)  
   EXEC SPCMN_ReportCollectionParsing  
     @PRMCollectionString = @PLIDList, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',   
     @PRMDataType01 = 'INT'  
END  
ELSE  
BEGIN  
 INSERT INTO #PLIDList(PL_Id)  
     SELECT PL_Id  
     FROM dbo.Prod_Lines_Base WITH(NOLOCK)            
-- --return 4  
END  
  
-- Lets assume that no line has production pathing  
UPDATE #PLIDList  
 SET HasPrdPath = 'NO'   
FROM #PLIDList pl   
  
  
-----------------------------------------------------------------------------------------------------------------------  
-- UDP field names  
-----------------------------------------------------------------------------------------------------------------------  
SELECT @vchUDPDescIsTestComplete = 'Is TestComplete',  
  @vchUDPDescPUG_PRRGrouping = 'PUG_PRRGrouping',  
  @vchUDPReestReevDesc  = 'ReestReevPU'  
  -- @vchUDPDescDefaultQProdGrps = 'DefaultQProdGrps',  
  -- @vchUDPDescIsAtt   = 'Is Attribute',  
  
  
-------------------------------------------------------------------------------------------------------  
-- Get Quality Units with Execution Path  
-------------------------------------------------------------------------------------------------------   
UPDATE #PLIDList  
 SET HasPrdPath = 'YES'  
 FROM #PLIDList pl   
 JOIN dbo.Prdexec_Paths pep  WITH(NOLOCK) ON pep.PL_Id = pl.PL_Id   
    
  
SELECT @intTableId = NULL  
SELECT @intTableFieldId = NULL  
-----------------------------------------------------------------------------------------------------------  
-- GET table Id for PU_Groups  
-----------------------------------------------------------------------------------------------------------  
SELECT @intTableId = TableId  
 FROM dbo.Tables WITH (NOLOCK)   
 WHERE TableName = 'Variables'   --'PU_Groups'  
------------------------------------------------------------------------------------------------------------   
-- GET table field Id for PUGs that holds at least one Test Complete Variable
------------------------------------------------------------------------------------------------------------  
SELECT @intTableFieldId = Table_Field_Id  
 FROM dbo.Table_Fields WITH (NOLOCK)  
 WHERE Table_Field_Desc = @vchUDPDescIsTestComplete 
  
------------------------------------------------------------------------------------------------------------   
-- GET Production Units and PUGs  
------------------------------------------------------------------------------------------------------------   
INSERT INTO @ProdUnitPrdPath (  
   PL_Id,  
   PU_Id,  
   PUG_Id,  
   PUG_Desc )  
SELECT  DISTINCT  
   pl.PL_Id,  
   pg.PU_Id,  
   pg.PUG_Id,  
   pg.PUG_Desc  
FROM dbo.Prdexec_Paths pep    WITH(NOLOCK)  
 JOIN #PLIDList pl     ON pep.PL_Id = pl.PL_Id  
 JOIN dbo.PrdExec_Path_Units pepu WITH(NOLOCK)   
          ON pepu.Path_Id = pep.Path_Id  
 JOIN dbo.PU_Groups  pg  WITH (NOLOCK)  
          ON pg.PU_Id = pepu.PU_Id  
 JOIN dbo.Variables_Base v    WITH (NOLOCK)  
          ON pg.PUG_Id = v.PUG_Id  
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
          ON tfv.KeyId = v.Var_Id  
WHERE tfv.TableId = @intTableId  
 AND tfv.Table_Field_Id = @intTableFieldId  
 AND pg.PU_Id > 0  
 AND pl.HasPrdPath = 'YES'  
 
 
------------------------------------------------------------------------------------------------------------   
-- If the Line does not have an Execution Path then look into all the PU's for all the PUG's flagged with  
-- our default UDP.  
------------------------------------------------------------------------------------------------------------   
INSERT INTO @ProdUnitPrdPath (  
     PL_Id,  
     PU_Id,  
     PUG_Id,  
     PUG_Desc )  
SELECT  DISTINCT  
     pl.PL_Id,  
     pg.PU_Id,  
     pg.PUG_Id,  
     pg.PUG_Desc  
FROM  #PLIDList pl   
 JOIN dbo.Prod_Units_Base   pu WITH (NOLOCK)  
          ON pl.PL_Id = pu.PL_Id  
 JOIN dbo.PU_Groups   pg WITH (NOLOCK)  
          ON pg.PU_Id = pu.PU_Id  
 JOIN dbo.Variables_Base   v WITH (NOLOCK)  
          ON pg.PUG_Id = v.PUG_Id  
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
          ON tfv.KeyId = v.Var_Id  
WHERE tfv.TableId = @intTableId  
 AND tfv.Table_Field_Id = @intTableFieldId  
 AND pl.HasPrdPath = 'NO'  
  
-------------------------------------------------------------------------------------------------------  
-- Update the PU_Desc, PL_Desc  
-------------------------------------------------------------------------------------------------------  
UPDATE @ProdUnitPrdPath  
 SET PU_Desc = pu.PU_Desc  
FROM @ProdUnitPrdPath pupp  
JOIN dbo.Prod_Units_Base pu WITH(NOLOCK)   
      ON pupp.PU_Id = pu.PU_Id  
  
UPDATE #PLIDList  
 SET PL_Desc = PL.PL_Desc  
FROM #PLIDList PLid  
JOIN dbo.Prod_Lines_Base pl WITH(NOLOCK)   
      ON pl.PL_Id = PLId.PL_Id  
  
  
-------------------------------------------------------------------------------------------  
-- GET LOCAL TRANSLATIONS FOR SELECTED CRITERIAS   
-- PRINT 'GET LOCAL TRANSLATIONS ..'  
-------------------------------------------------------------------------------------------  
-- Init default translatiON variables  
SELECT @LocalRPTLanguage = Value   
  FROM dbo.Site_Parameters sp WITH(NOLOCK)  
  JOIN dbo.Parameters p   WITH(NOLOCK)   
         ON sp.parm_id = p.parm_id  
  WHERE Parm_Name Like 'LanguageNumber'  
  
SELECT @Pass = COALESCE(Prompt_String,'PASS')   
  FROM dbo.Language_Data WITH(NOLOCK)  
  WHERE Prompt_Number = (SELECT MAX(Prompt_Number)   
         FROM dbo.Language_Data WITH(NOLOCK)   
         WHERE Prompt_String = 'PASS')  
  AND Language_Id = @LocalRPTLanguage  
  
SELECT @Fail = COALESCE(Prompt_String,'FAIL')  
  FROM dbo.Language_Data WITH(NOLOCK)  
  WHERE Prompt_Number = (SELECT MAX(Prompt_Number)   
          FROM dbo.Language_Data WITH(NOLOCK)   
             WHERE Prompt_String = 'FAIL')  
  AND Language_Id = @LocalRPTLanguage  
/*
SELECT @PassIncomplete = COALESCE(Prompt_String,'Incomplete - PASS')   
  FROM dbo.Language_Data WITH(NOLOCK)  
  WHERE Prompt_Number = (SELECT MAX(Prompt_Number)   
         FROM dbo.Language_Data WITH(NOLOCK)   
         WHERE Prompt_String = 'Incomplete - PASS')  
  AND Language_Id = @LocalRPTLanguage  
  
SELECT @FailIncomplete = COALESCE(Prompt_String,'Incomplete - FAIL')  
  FROM dbo.Language_Data WITH(NOLOCK)  
  WHERE Prompt_Number = (SELECT MAX(Prompt_Number)   
          FROM dbo.Language_Data WITH(NOLOCK)   
             WHERE Prompt_String = 'Incomplete - FAIL')  
  AND Language_Id = @LocalRPTLanguage  
  */
----------------------------------------------------------------------------------------------------  
-- Get Products for current time frame  
----------------------------------------------------------------------------------------------------  
INSERT INTO @Production (  
    PLId   ,  
    StartTime  ,   
    EndTime   ,           
    ProdId   ,  
    ProdCode  ,  
    PathId   )  
  
SELECT   DISTINCT  
    pl.PL_Id      PLId   ,  
    ps.Start_Time     StartTime  ,  
    ISNULL(ps.END_Time,@in_ENDTime) EndTime   ,          
    p.Prod_Id      ProdId   ,  
    p.Prod_Code      ProdCode  ,  
    pep.Path_Id      PathId  
FROM  dbo.Production_Starts ps    WITH(NOLOCK)   
  JOIN dbo.Products_Base p      WITH(NOLOCK)    
            ON  ps.prod_id  =  p.prod_id   
  JOIN dbo.PrdExec_Path_Units pepu  WITH(NOLOCK)  
             ON  pepu.PU_Id  =  ps.PU_Id  
  JOIN dbo.Prdexec_Paths pep    WITH(NOLOCK)  
             ON  pepu.Path_Id = pep.Path_Id  
  JOIN #PLIDList    pl    ON pl.PL_Id = pep.PL_Id  
WHERE  ps.Start_time <= @in_ENDTime  
  AND  (ps.END_Time > @in_StartTime OR ps.END_Time IS NULL)     
  AND  Prod_Desc <> 'No Grade'     
  AND  Prod_Code <> '<None>'    
  AND     pepu.Is_Production_Point = 1  
  
  
--DELETE FROM @Production  
--WHERE PathId NOT IN (  
--     SELECT Path_Id  
--     FROM @Production p  
--     JOIN dbo.Production_Plan pp  WITH(NOLOCK)  
--             ON  pp.Path_Id = p.PathId   
--     JOIN dbo.Production_Plan_Starts pps WITH(NOLOCK)   
--             ON  pps.PP_Id = pp.PP_Id  
--     WHERE   
--      (pps.Start_Time <= p.EndTime  
--       AND (pps.End_Time > p.StartTime OR pps.End_Time IS NULL))  
--    )  


 
----------------------------------------------------------------------------------------------------  
-- Get Production Plan for current time frame  
----------------------------------------------------------------------------------------------------  
INSERT INTO @ProductionPlan (PLID,  
        StartTime,  
        EndTime,   
        ProdId,  
        PO,  
        Batch,
        PathId  ,
		HybridConf
       )  
SELECT DISTINCT   pl.PL_Id,  
      Start_Time,   
      End_Time,  
      Prod_Id,  
      Process_Order,
	  -- Change for EUS
      pp.User_General_1,  
      pp.Path_Id  ,
	  'No'      
FROM  dbo.Production_Plan pp    WITH(NOLOCK) 
 JOIN dbo.Production_Plan_Starts pps WITH(NOLOCK) ON pps.PP_Id = pp.PP_Id  
 JOIN dbo.PrdExec_Path_Units pepu  WITH(NOLOCK) ON pepu.Path_Id = pp.Path_Id  
 JOIN dbo.Prdexec_Paths pep   WITH(NOLOCK) ON pep.Path_Id = pp.Path_Id  
 JOIN #PLIDList pl         ON pep.PL_Id = pl.PL_Id  
 LEFT JOIN dbo.Production_Setup ps WITH(NOLOCK) ON pp.PP_id = ps.PP_id   
WHERE   
 (pps.Start_Time <= @in_EndTime  
  AND (pps.End_Time > @in_StartTime OR pps.End_Time IS NULL))  
 AND pepu.Is_Production_Point = 1  


-- Remove products only in lines where there is an Active Path  
DELETE FROM @Production  
WHERE PathId NOT IN (  
     SELECT Path_Id  
     FROM @Production p  
     JOIN dbo.Production_Plan pp  WITH(NOLOCK)  
             ON  pp.Path_Id = p.PathId   
     JOIN dbo.Production_Plan_Starts pps WITH(NOLOCK)   
             ON  pps.PP_Id = pp.PP_Id  
     WHERE   
      (pps.Start_Time <= p.EndTime  
       AND (pps.End_Time > p.StartTime OR pps.End_Time IS NULL))  
    )  
 AND PLId NOT IN(  
     SELECT pl.PL_Id FROM #PLIDList pl  
     LEFT JOIN @ProductionPlan pp ON pl.PL_Id = pp.PLId  
     WHERE pp.PLId IS NULL  
     AND HasPrdPath = 'YES' )  
  
  
--Add planned Process Orders if there is not Active Paths  
INSERT INTO @ProductionPlan (PLID,  
        StartTime,  
        EndTime,   
        ProdId,  
        PO,  
        PathId  ,
		HybridConf
       )  
SELECT DISTINCT  
     pep.PL_Id   ,  
     Forecast_start_date ,  
     Forecast_End_Date ,  
     p.Prod_Id   ,  
     Process_Order  ,  
     pp.Path_Id,
	 'No'
FROM  dbo.Production_Plan  pp   WITH(NOLOCK)   
 JOIN dbo.PrdExec_Path_Units pupp WITH(NOLOCK)   
           ON pupp.Path_Id = pp.Path_Id  
 JOIN dbo.Prdexec_Paths  pep  WITH(NOLOCK)   
           ON pep.Path_Id = pp.Path_Id  
 JOIN #PLIDList    pl  ON pep.pl_id = pl.pl_id  
 LEFT JOIN dbo.Production_Starts ps   WITH(NOLOCK)    
           ON (ps.Prod_Id = pp.Prod_Id   
           AND ps.Pu_Id = pupp.Pu_Id)   
 LEFT JOIN dbo.Products_Base    p   WITH (NOLOCK)    
           ON p.Prod_Id = pp.Prod_Id   
WHERE   
 (ps.End_Time > @in_StartTime OR ps.End_Time IS NULL)   
 AND ((pp.Forecast_End_Date > @in_StartTime AND pp.Forecast_End_Date < @in_EndTime)  
  OR (pp.Forecast_Start_Date > @in_StartTime AND pp.Forecast_Start_Date < @in_EndTime))  
 AND     pupp.Is_Production_Point = 1  
 AND Process_Order NOT IN (SELECT PO FROM @ProductionPlan)  
 AND pl.PL_Id IN(  
     SELECT pl.PL_Id FROM #PLIDList pl  
     LEFT JOIN @ProductionPlan pp ON pl.PL_Id = pp.PLId  
     WHERE pp.PLId IS NULL   
     AND HasPrdPath = 'YES')  

UPDATE @ProductionPlan
	SET HybridConf = 'Yes'
FROM @ProductionPlan		pp
JOIN dbo.PrdExec_Path_Units pepu	WITH(NOLOCK) 
									ON pepu.Path_Id = pp.PathId  
JOIN dbo.Events				e		WITH(NOLOCK)
									ON	e.Start_Time = pp.StartTime
									--AND	e.Timestamp = pp.EndTime
									AND pepu.PU_Id = e.PU_Id

----------------------------------------------------------------------------------------------------  
-- Test Grouping   -- 0 = None / 1 = Product / 2 = Process Order  
-- SET @int_RptGroupBy = 1 
-- SELECT @int_HourInterval = 10
----------------------------------------------------------------------------------------------------  
----------------------------------------------------------------------------------------------------  
-- Grouping by: None  
----------------------------------------------------------------------------------------------------  

IF @int_RptGroupBy = 0   
BEGIN  
  INSERT INTO @PosRelGrouping (  
     PLId    ,  
     StartTime   ,   
     EndTime    ,   
     PLDesc    ,  
     MinorGrouping)  
  SELECT DISTINCT TOP 50  
     PL_Id    ,  
     @in_StartTime  ,   
     @in_EndTime   ,  
     PL_Desc    ,  
     PL_Desc  
  FROM  #PLIDList      
  
  
  
  SELECT @ProdRow = 1  
  WHILE  @ProdRow <= (SELECT MAX(ProdRow) FROM @Production)  
  BEGIN  
   UPDATE @PosRelGrouping  
    SET ProdCode = (CASE WHEN LEN(ISNULL(ProdCode,'')) +   
           (SELECT LEN(ProdCode) FROM @Production   
            WHERE ProdRow = @ProdRow) < 1200 -- avoid the rows to grow  
         THEN ISNULL(ProdCode,'') + ' ' +  
                                            (SELECT ProdCode FROM @Production   
            WHERE ProdRow = @ProdRow)  
         ELSE ProdCode  
         END )  
   WHERE PLId = (SELECT PLId FROM @Production WHERE ProdRow = @ProdRow)         
   SELECT @ProdRow = @ProdRow + 1  
  END     
  
  SELECT @PORow = 1  
  WHILE  @PORow <= (SELECT MAX(PORow) FROM @ProductionPlan)  
  BEGIN  
  
   UPDATE @PosRelGrouping  
   SET PO = (CASE WHEN LEN(ISNULL(PO,'')) +   
          (SELECT LEN(PO) FROM @ProductionPlan   
           WHERE PORow = @PORow)   < 1200  
         THEN ISNULL(PO,'') + ' ' +  
                                            (SELECT PO FROM @ProductionPlan   
            WHERE PORow = @PORow)  
         ELSE PO  
         END )  ,
       Batch = (CASE WHEN LEN(ISNULL(Batch,'')) +   
          (SELECT LEN(Batch) FROM @ProductionPlan   
           WHERE PORow = @PORow)   < 1200  
         THEN ISNULL(Batch,'') + ' ' +  
                                            (SELECT Batch FROM @ProductionPlan   
            WHERE PORow = @PORow)  
         ELSE Batch  
         END )  
   WHERE PLId = (SELECT PLId FROM @ProductionPlan WHERE PORow = @PORow)      
    
   SELECT @PORow = @PORow + 1  
   SELECT  @PONull =count(*)from @ProductionPlan WHERE ENDTIME IS NULL 
  END    
 
  ---------------------------------------------------------------------------------------------------  
  -- Volume Count  
  -- Convert to MSU  
  ---------------------------------------------------------------------------------------------------  
  UPDATE @PosRelGrouping  
   SET VolumeCount = ( SELECT SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1.0))  
          FROM dbo.Tests t   WITH(NOLOCK)        
          JOIN dbo.Prod_Units_Base pu WITH(NOLOCK)  
                 ON pu.Production_Variable = t.Var_id  
          JOIN dbo.PrdExec_Path_Units pepu WITH(NOLOCK)   
                 ON pepu.PU_Id = pu.PU_Id   
          JOIN @Production p  ON p.PathId = pepu.Path_Id  
          LEFT JOIN dbo.Var_Specs vs WITH (NOLOCK)  
                 ON pu.Production_Variable= vs.Var_Id  
                 AND p.ProdId = vs.Prod_ID  
          WHERE pl.PLId = p.PLId  
           AND t.Result_On > p.StartTime  
           AND t.Result_On <= p.EndTime  
           AND t.Result_On > @in_StartTime  
           AND t.Result_On <= @in_EndTime  
           AND pepu.Is_Production_Point = 1 )  
  FROM @PosRelGrouping  pl   
END  
ELSE   
BEGIN  
 ----------------------------------------------------------------------------------------------------  
 -- Grouping by: Product  
 ----------------------------------------------------------------------------------------------------  
 IF @int_RptGroupBy = 1  
 BEGIN  
   INSERT INTO @PosRelGrouping (  
       PLId   ,  
       StartTime  ,   
       EndTime   ,   
       PLDesc   ,  
       ProdId   ,  
       ProdDesc  ,  
       ProdCode  ,  
       PO    ,  
       Batch	,
       MinorGrouping ,  
       PathId   )  
            SELECT DISTINCT TOP 50  -- Because the 100 RS limit   
       Prod.PLId  ,  
       Prod.StartTime ,  
       Prod.EndTime ,  
       pl.PL_Desc  ,  
       p.Prod_Id  ,  
       p.Prod_Desc  ,  
       p.Prod_Code  ,  
       ''    ,  
       ''    ,
       p.Prod_Code  ,  
       PathId  
            FROM  @Production Prod    
            JOIN  dbo.Products_Base P    WITH(NOLOCK)    
           ON   Prod.ProdId = p.prod_id  
   JOIN  #PLIDList  pl   ON  Prod.PLId = PL.PL_id  
     
   UPDATE @PosRelGrouping  
                SET StartTime = @in_StartTime  
            WHERE StartTime < @in_StartTime  
  
            UPDATE @PosRelGrouping  
                SET EndTime = @in_EndTime  
            WHERE EndTime > @in_EndTime  
  
  
   -- Make the Product Code unique for use on the Excel Template  
   WHILE EXISTS( SELECT * FROM (   
         SELECT COUNT(*) AS Cnt FROM @PosRelGrouping  
         GROUP BY MinorGrouping ) AS Tbl  
       WHERE Tbl.Cnt > 1  
      )  
   BEGIN  
    SELECT TOP 1 @vchProdCode = MinorGrouping FROM (   
     SELECT COUNT(*) AS Cnt,MinorGrouping FROM @PosRelGrouping  
     GROUP BY MinorGrouping ) AS Tbl  
    WHERE Tbl.Cnt > 1   
  
    SET @i = 1   
    SELECT @ProdRow =  COUNT(*) FROM @PosRelGrouping  
      WHERE MinorGrouping = @vchProdCode  
  
    WHILE @i <= ISNULL(@ProdRow,1)  
    BEGIN  
     UPDATE @PosRelGrouping  
      SET MinorGrouping = MinorGrouping + '_' + CONVERT(NVARCHAR,@i)  
     WHERE PRGId IN (SELECT TOP 1 PRGId FROM @PosRelGrouping  
         WHERE MinorGrouping = @vchProdCode)  
  
     SET @i = @i + 1  
    END  
   END  
  
   -- Check for if not exists Products available  
   IF (SELECT COUNT(*) FROM @PosRelGrouping) = 0  
   BEGIN  
   -- SELECT 'No exists Products available'  
  
    INSERT INTO @PosRelGrouping (  
       PLId    ,  
       StartTime   ,   
       EndTime    ,   
       ProdDesc   ,  
       ProdCode   ,  
       PO     ,  
       VolumeCount   ,  
       PLDesc    ,  
       MinorGrouping)  
    SELECT DISTINCT TOP 50  
       PL_Id    ,  
       @in_StartTime  ,   
       @in_EndTime   ,  
       'No Data'   ,  
       'No Data'   ,  
       'No Data'   ,  
       0     ,  
       PL_Desc    ,  
       PL_Desc  
    FROM  #PLIDList      
   END 
   
 END  


----------------------------------------------------------------------------------------------------  
-- Grouping by: Process Order  
---------------------------------------------------------------------------------------------------- 
SET @int_HourInterval = ISNULL(@int_HourInterval,0)

IF @int_RptGroupBy = 2 
BEGIN   
	   	    
	UPDATE @ProductionPlan  
	   SET StartTime = NULL  
	WHERE StartTime <   DATEADD(hh,-1 * @int_HourInterval,@in_StartTime)  

	UPDATE @ProductionPlan  
	   SET EndTime = NUll  
	WHERE EndTime > DATEADD(hh,@int_HourInterval,@in_EndTime) 		
	

	INSERT INTO @PosRelGrouping (  
				 PLId    ,  
				 StartTime   ,   
				 EndTime    ,   
				 PLDesc    ,  
				 ProdId    ,  
				 ProdDesc   ,  
				 ProdCode   ,  
				 PO     ,  
				 Batch	,
				 MinorGrouping  ,  
				 PathId    ,
				 HybridConfig	)  
	SELECT DISTINCT TOP 50  -- Because the 100 RS limit  
				 pp.PLId    ,  
				 pp.StartTime  ,   
				 pp.EndTime   ,   
				 pl.PL_Desc   ,  
				 ProdId    ,  
				 p.Prod_Desc   ,  
				 p.Prod_Code   ,  
				 pp.PO    ,  
				 pp.Batch ,
				 pp.PO    ,  
				 PathId  ,
				 HybridConf
	FROM @ProductionPlan	pp       
	JOIN #PLIDList			pl	ON  pp.PLId  = pl.PL_Id  
	LEFT JOIN dbo.Products_Base	p	WITH (NOLOCK)      
								ON  pp.ProdId  =  p.Prod_Id   
	ORDER BY pp.PLId, pp.StartTime, pp.EndTime  





	-- Make the Process Order unique for use on the Excel Template  
	WHILE EXISTS( SELECT * FROM (   
		SELECT COUNT(*) AS Cnt FROM @PosRelGrouping  
		GROUP BY MinorGrouping ) AS Tbl  
	  WHERE Tbl.Cnt > 1  
	 )  
	BEGIN  
	SELECT TOP 1 @vchProdCode = MinorGrouping FROM (   
	SELECT COUNT(*) AS Cnt,MinorGrouping FROM @PosRelGrouping  
	GROUP BY MinorGrouping ) AS Tbl  
	WHERE Tbl.Cnt > 1   

	SET @i = 1   
	SELECT @ProdRow =  COUNT(*) FROM @PosRelGrouping  
	 WHERE MinorGrouping = @vchProdCode  

	WHILE @i <= ISNULL(@ProdRow,1)  
	BEGIN  
	UPDATE @PosRelGrouping  
	 SET MinorGrouping = MinorGrouping + '_' + CONVERT(NVARCHAR,@i)  
	WHERE PRGId IN (SELECT TOP 1 PRGId FROM @PosRelGrouping  
		WHERE MinorGrouping = @vchProdCode)  

	SET @i = @i + 1  
	END  
	END  

	-- Check for if not exists PO available  
	IF (SELECT COUNT(*) FROM @PosRelGrouping) = 0  
	BEGIN  
	-- SELECT 'No exists PO available'  

	INSERT INTO @PosRelGrouping (  
	  PLId    ,  
	  StartTime   ,   
	  EndTime    ,   
	  ProdDesc   ,  
	  ProdCode   ,  
	  PO     ,  
	  VolumeCount   ,  
	  PLDesc    ,  
	  MinorGrouping)  
	SELECT DISTINCT TOP 50  
	  PL_Id    ,  
	  @in_StartTime  ,   
	  @in_EndTime   ,  
	  'No Data'   ,  
	  'No Data'   ,  
	  'No Data'   ,  
	  0     ,  
	  PL_Desc    ,  
	  PL_Desc  
	FROM  #PLIDList  
	END  
END  
  
 ---------------------------------------------------------------------------------------------------  
 -- Volume Count  
 ---------------------------------------------------------------------------------------------------  
 UPDATE @PosRelGrouping  
  SET VolumeCount = (SELECT SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1.0))  
         FROM dbo.Tests t   WITH(NOLOCK)  
         JOIN dbo.Prod_Units_Base pu WITH(NOLOCK)				ON pu.Production_Variable = t.Var_id  
         JOIN dbo.PrdExec_Path_Units pepu WITH(NOLOCK)		ON pepu.PU_Id = pu.PU_Id  
         JOIN @Production p									ON p.PathId = pepu.Path_Id  
		 LEFT JOIN dbo.Var_Specs vs WITH (NOLOCK)			ON pu.Production_Variable= vs.Var_Id  
															AND p.ProdId = vs.Prod_ID  
         JOIN @PosRelGrouping pl							ON (pepu.Path_Id = pl.PathId  
															AND t.Result_On > pl.StartTime  
															AND t.Result_On <= pl.EndTime)  
		WHERE t.Result_On > p.StartTime  
			   	  AND t.Result_On <= p.EndTime  
				  AND pepu.Is_Production_Point = 1  
					  AND pl.MinorGrouping = pl2.MinorGrouping		
         GROUP BY pl.MinorGrouping)  
 FROM @PosRelGrouping  pl2  
 WHERE HybridConfig = 'No'
	
--
--
UPDATE @PosRelGrouping
		SET VolumeCount = pp.Actual_Good_Quantity 
FROM @PosRelGrouping prg
JOIN dbo.Production_Plan pp WITH(NOLOCK) ON prg.PO = pp.Process_Order
WHERE HybridConfig = 'Yes'
	 --

END  
  
PRINT 'END GET TIME FRAMES ...'  
-- SELECT '@PosRelGrouping',* FROM @PosRelGrouping  
-- SELECT '@ProductionPlan',* FROM @ProductionPlan  
---------------------------------------------------------------------------------------------------  
-- Batch Number  
---------------------------------------------------------------------------------------------------  
/*
SELECT @EventSubtypeId = Event_Subtype_Id   
FROM dbo.Event_Subtypes WITH(NOLOCK)  
WHERE Event_Subtype_Desc LIKE '%Batch Change%'  
  
INSERT INTO @UDEBatch( StartTime,  
      EndTime,  
      BatchNumber)  
SELECT DISTINCT  Start_Time,  
      End_Time,  
      UDE_Desc  
--FROM dbo.User_Defined_Events ude WITH(NOLOCK)  
FROM dbo.Production_Setup ps
JOIN dbo.Prod_Units pu    WITH(NOLOCK)   
         ON ude.PU_Id = pu.PU_Id  
JOIN #PLIDList pl     ON pu.PL_Id = pl.PL_Id  
WHERE (Start_Time <= @in_EndTime  
  AND ( End_Time > @in_StartTime OR End_Time IS NULL ))  
  AND ude.Event_Subtype_Id = @EventSubtypeId  
  
SELECT @CountPRRow  = COUNT(*) FROM @PosRelGrouping  
SELECT @CountBatchRow = COUNT(*) FROM @UDEBatch  
  
IF @CountBatchRow > 0  
BEGIN  
  SELECT @PRRow = 1  
  WHILE  @PRRow <= @CountPRRow  
  BEGIN  
   SELECT @StartTime = StartTime, @EndTime = EndTime  
    FROM @PosRelGrouping  
    WHERE PRGId = @PRRow  
  
   SELECT @BatchRow = 1  
   WHILE  @BatchRow <= @CountBatchRow  
   BEGIN  
    IF EXISTS (SELECT BatchNumber FROM @UDEBatch   
       WHERE BatchRow = @BatchRow  
       AND (StartTime <= @EndTime   
         AND (EndTime > @StartTime OR EndTime IS NULL))  
       )  
    BEGIN  
     UPDATE @PosRelGrouping  
      SET Batch = ISNULL(Batch,'') + ' ' + (SELECT BatchNumber FROM @UDEBatch WHERE BatchRow = @BatchRow)  
     WHERE PRGId = @PRRow  
    END  
    SELECT @BatchRow = @BatchRow + 1  
   END  
    
   SELECT @PRRow = @PRRow + 1  
  END   
END  
ELSE  
BEGIN  
  UPDATE @PosRelGrouping  
   SET Batch = ''  
END   
*/  
-- SELECT '@UDEBatch',* FROM @UDEBatch  
---------------------------------------------------------------------------------------------------  
-- Check Parameter: Reporting period  
---------------------------------------------------------------------------------------------------  
---------------------------------------------------------------------------------------------------  
IF @RptStartTime > @RptEndTime   
BEGIN  
 SELECT 3 ErrorCode  
END  
---------------------------------------------------------------------------------------------------  
IF @RptStartTime  = @RptEndTime  
BEGIN  
 SELECT 7 ErrorCode  
END  
---------------------------------------------------------------------------------------------------  
-- Check Parameter: Period Incomplete Flag  
---------------------------------------------------------------------------------------------------  
IF @RptEndTime  > GETDATE()  
BEGIN  
 SELECT @intPeriodIncompleteFlag = 1,  
   @RptEndTime  = GETDATE()  
END  
ELSE  
BEGIN  
 SELECT @intPeriodIncompleteFlag = 0  
END  
-----------------------------------------------------------------------------------------------------------  
-- GET SITE  
-----------------------------------------------------------------------------------------------------------  
SELECT @Plant =  COALESCE(Value, 'Site Name')  
 FROM  dbo.Site_Parameters WITH(NOLOCK)  
 WHERE  Parm_Id = 12  
-----------------------------------------------------------------------------------------------------------  
-- Define Constants  
-----------------------------------------------------------------------------------------------------------  
SELECT @SpecDesc                   = 'Test Complete'  
SELECT @QVReEstPUGDesc             = 'QV Reestablish'  
SELECT @QAReEstPUGDesc             = 'QA Reestablish'  
SELECT @QAReEvalPUGDesc            = 'QA Reevaluation'  
SELECT @QVReEvalPUGDesc            = 'QV Reevaluation'  
SELECT @ConstOpen                  = 'Open'  
SELECT @QVReEvalConstOpen          = 'ReevaluatiON Successful'  
SELECT @QVReSubdivideScrap		   = 'Subdivide or Scrap'  
SELECT @QVReEvalNoDefect           = 'No Deviation'  
SELECT @QAReEstExtInfo             = 'RPT=OOSSTAT'  
SELECT @QAReEvalExtInfo            = 'RPT=STATReEvA'  
SELECT @QVReEstExtInfo             = 'RPT=OOSSTAT'  
SELECT @QVReEvalExtInfo            = 'RPT=STATReEvV'  
SELECT @QAReEvalTimeExtInfo        = 'QA-REEVAL-TIME'  
SELECT @QVReEvalTimeExtInfo        = 'REEVALTIME'  
SELECT @strPass                    = 'PASS'     -- @Pass  
SELECT @strFail                    = 'FAIL'     -- @Fail  
select @strPassIncPo			   = 'Incomplete - PASS'---- @PassInc 
select @strFailIncPo			   = 'Incomplete - FAIL ' -- @FailIncomplete
SELECT @strTestComplete            = 'Test Not Complete'  
SELECT @strOOS					   = ' '  
SELECT @strMissingSample           = 'Missing Sample'  
  
  
-------------------------------------------------------------------------------------------------------  
-- Get the Reest/Reev Unit  
-------------------------------------------------------------------------------------------------------  
-- Step 1.  
SELECT  @intTableId = TableId   
FROM  dbo.Tables WITH(NOLOCK)  
WHERE   TableName = 'Prod_Lines'  
  
-- Step 2.  
SELECT @intTableFieldId = Table_Field_Id  
FROM  dbo.Table_Fields WITH(NOLOCK)  
WHERE Table_Field_Desc = @vchUDPReestReevDesc  
AND TableId = @intTableId
  
-----------------------------------------------------------------------------------------------------------  
-- Phrase IDs  
-----------------------------------------------------------------------------------------------------------  
UPDATE @ProdUnitPrdPath  
 SET QVReestPUGId = pug.PUG_Id  
FROM @ProdUnitPrdPath pupp  
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
          ON tfv.KeyId = pupp.PL_Id  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK)   
       ON pupp.PL_Id = pu.PL_Id  
 JOIN dbo.PU_Groups pug WITH(NOLOCK)   
       ON pug.PU_Id = pu.PU_Id  
WHERE pug.PUG_Desc = @QVReEstPUGDesc   
 AND pu.PU_Id = CONVERT(INT,Value)  
 AND tfv.TableId = @intTableId  
 AND tfv.Table_Field_Id = @intTableFieldId  
  
UPDATE @ProdUnitPrdPath  
 SET QAReEstPUGId = pug.PUG_Id  
FROM @ProdUnitPrdPath pupp  
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
          ON tfv.KeyId = pupp.PL_Id  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK)   
       ON pupp.PL_Id = pu.PL_Id  
 JOIN dbo.PU_Groups pug WITH(NOLOCK)   
       ON pug.PU_Id = pu.PU_Id  
WHERE pug.PUG_Desc = @QAReEstPUGDesc   
 AND pu.PU_Id = CONVERT(INT,Value)  
 AND tfv.TableId = @intTableId  
 AND tfv.Table_Field_Id = @intTableFieldId   
  
--   
UPDATE @ProdUnitPrdPath  
 SET QVReEvalPUGId = pug.PUG_Id  
FROM @ProdUnitPrdPath pupp  
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
          ON tfv.KeyId = pupp.PL_Id  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pupp.PL_Id = pu.PL_Id  
 JOIN dbo.PU_Groups pug WITH(NOLOCK) ON pug.PU_Id = pu.PU_Id  
 WHERE pug.PUG_Desc = @QVReEvalPUGDesc   
 AND pu.PU_Id = CONVERT(INT,Value)  
 AND tfv.TableId = @intTableId  
 AND tfv.Table_Field_Id = @intTableFieldId   
   
  
UPDATE @ProdUnitPrdPath  
 SET QAReEvalPUGId = pug.PUG_Id  
FROM @ProdUnitPrdPath pupp  
 JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
          ON tfv.KeyId = pupp.PL_Id  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pupp.PL_Id = pu.PL_Id  
 JOIN dbo.PU_Groups pug WITH(NOLOCK) ON pug.PU_Id = pu.PU_Id  
 WHERE pug.PUG_Desc = @QAReEvalPUGDesc   
 AND pu.PU_Id = CONVERT(INT,Value)  
 AND tfv.TableId = @intTableId  
 AND tfv.Table_Field_Id = @intTableFieldId   
  
--   
-- QA ReEstabish  
UPDATE @ProdUnitPrdPath  
 SET QAReEstVarId = v.Var_Id  
FROM dbo.Variables_Base V        WITH (NOLOCK)  
  JOIN @ProdUnitPrdPath pupp     ON  V.PUG_Id = pupp.QAReestPUGId  
  WHERE  ExtENDed_Info = @QAReEstExtInfo     
    
-- QA ReEvaluation  
UPDATE @ProdUnitPrdPath  
 SET QAReEvalVarId = V.Var_Id   
FROM dbo.Variables_Base V        WITH (NOLOCK)  
  JOIN @ProdUnitPrdPath pupp     ON  v.PUG_Id = pupp.QAReEvalPUGId    
  WHERE   ExtENDed_Info = @QAReEvalExtInfo  
  
  
-- QA ReEvalTime  
UPDATE @ProdUnitPrdPath  
 SET QAReEvalTimeVarId = Var_Id   
FROM dbo.Variables_Base V        WITH (NOLOCK)  
  JOIN @ProdUnitPrdPath pupp     ON  v.PUG_Id = pupp.QAReEvalPUGId   
  WHERE  ExtENDed_Info = @QAReEvalTimeExtInfo  
  
-- QVReEstabish      
UPDATE @ProdUnitPrdPath  
 SET QVReEstVarId = V.Var_Id   
FROM dbo.Variables_Base V        WITH (NOLOCK)  
  JOIN @ProdUnitPrdPath pupp     ON  v.PUG_Id = pupp.QVReestPUGId   
  WHERE  ExtENDed_Info = @QVReEstExtInfo       
  
-- QVReEvaluation  
UPDATE @ProdUnitPrdPath  
 SET QVReEvalVarId = V.Var_Id   
FROM dbo.Variables_Base V         WITH (NOLOCK)  
  JOIN @ProdUnitPrdPath pupp     ON  v.PUG_Id = pupp.QVReEvalPUGId    
  WHERE   ExtENDed_Info = @QVReEvalExtInfo  
  
-- QVReEvaluation  
UPDATE @ProdUnitPrdPath  
 SET QVReEvalTimeVarId = V.Var_Id  
FROM dbo.Variables_Base  V         WITH (NOLOCK)  
  JOIN @ProdUnitPrdPath pupp     ON  v.PUG_Id = pupp.QVReEvalPUGId   
  WHERE   ExtENDed_Info = @QVReEvalTimeExtInfo  
  
 
--=========================================================================================================  
-- Get Test Complete Variable AND Sheet_Id  
-----------------------------------------------------------------------------------------------------------  
SELECT @intTableId = NULL  
SELECT @intTableFieldId = NULL  
-----------------------------------------------------------------------------------------------------------  
-- GET table Id for Variables  
-----------------------------------------------------------------------------------------------------------  
SELECT @intTableId = TableId  
FROM dbo.Tables WITH (NOLOCK)   
WHERE TableName = 'Variables'  
------------------------------------------------------------------------------------------------------------   
-- GET table field Id for 'Is TestComplete'  
-- This might be a list if several Test Complete Variables are on different PUGs
------------------------------------------------------------------------------------------------------------  
SELECT @intTableFieldId = Table_Field_Id  
FROM dbo.Table_Fields WITH (NOLOCK)  
WHERE Table_Field_Desc = @vchUDPDescIsTestComplete  
  
  
UPDATE @ProdUnitPrdPath  
 SET TestCompleteVarId = V.Var_id   
FROM @ProdUnitPrdPath pupp  
 JOIN dbo.Variables_Base v    WITH(NOLOCK)   
          ON v.PUG_ID = pupp.PUG_Id   
          AND v.PU_Id = pupp.PU_Id  
 JOIN dbo.Table_Fields_Values tfv WITH(NOLOCK)   
          ON tfv.KeyID = v.Var_Id  
WHERE tfv.Table_Field_Id = @intTableFieldId  
    
   
  
UPDATE @ProdUnitPrdPath  
 SET SheetId = sv.Sheet_Id  
FROM @ProdUnitPrdPath pupp  
  JOIN dbo.Sheet_Variables sv    WITH(NOLOCK)   
            ON pupp.TestCompleteVarId = sv.Var_Id  
  
  
IF EXISTS( SELECT * FROM dbo.Sysobjects WITH(NOLOCK)   
   WHERE Id = OBJECT_ID(N'[dbo].[Local_PG_Translations]')   
   AND OBJECTPROPERTY(id, N'IsTable') = 1 )  
BEGIN  
    -- Phrase Open text  
    SELECT @ConstOpen = lpt.Translated_Text   
 FROM dbo.Local_PG_Translations lpt     WITH(NOLOCK)  
    JOIN dbo.Local_PG_Languages lpl     WITH(NOLOCK)   
             ON lpl.Language_Id = lpt.Language_Id  
     WHERE lpl.Is_Active = 1   
        AND lpt.Global_Text = @ConstOpen  
  
    SELECT @QVReEvalConstOpen = lpt.Translated_Text   
 FROM dbo.Local_PG_Translations lpt     WITH(NOLOCK)  
     JOIN dbo.Local_PG_Languages lpl    WITH(NOLOCK)   
             ON lpl.Language_Id = lpt.Language_Id  
     WHERE lpl.Is_Active = 1   
      AND lpt.Global_Text = @QVReEvalConstOpen  
  
    SELECT @QVReEvalNoDefect = lpt.Translated_Text   
  FROM dbo.Local_PG_Translations lpt    WITH(NOLOCK)  
     JOIN dbo.Local_PG_Languages lpl    WITH(NOLOCK)   
             ON lpl.Language_Id = lpt.Language_Id  
     WHERE lpl.Is_Active = 1   
      AND lpt.Global_Text = @QVReEvalNoDefect  
  
 SELECT @QVReSubdivideScrap = lpt.Translated_text   
  FROM dbo.Local_PG_Translations lpt    WITH(NOLOCK)  
     JOIN dbo.Local_PG_Languages lpl    WITH(NOLOCK)   
             ON lpl.Language_Id = lpt.Language_Id  
     WHERE lpl.Is_Active = 1   
      AND lpt.Global_Text = @QVReSubdivideScrap  
END  
  
-----------------------------------------------------------------------------------------------------------  
-- End Get Test Complete Var_Id  
--=========================================================================================================  
  
------------------------------------------------------------------------------------------------------------   
-- GET Alarm Types Ids for Q - Factors and Standard Alarms  
------------------------------------------------------------------------------------------------------------  
SELECT @AlTypeIdVarLimits = Alarm_Type_Id FROM dbo.Alarm_Types WITH(NOLOCK) WHERE Alarm_Type_Desc = 'Variable Limits'  
SELECT @AlTypeIdSPC   = Alarm_Type_Id FROM dbo.Alarm_Types WITH(NOLOCK) WHERE Alarm_Type_Desc = 'SPC'  
SELECT @AlTypeIdSPCGroup = Alarm_Type_Id FROM dbo.Alarm_Types WITH(NOLOCK) WHERE Alarm_Type_Desc = 'SPC Group'  
  
  
--   
--=========================================================================================================  
-- START PROCESSING Report DATA.  
-- Loop By Grouping Option  
--=========================================================================================================  

SELECT @RECNo = 1  
  
IF (SELECT COUNT(*) FROM @PosRelGrouping) > 0  
BEGIN  
  
 WHILE @RECNo < (SELECT COUNT(*) FROM @PosRelGrouping) + 1  
 BEGIN  
   
  SELECT   @PLID			= PLID		,  
		   @RptStartTime	= StartTime ,  
		   @RptEndTime		= EndTime
  FROM  @PosRelGrouping  
  WHERE   PRGId   = @RECNo   
  
  -- PO Grouping
  IF (	@int_RptGroupBy = 2
		AND (@RptStartTime IS NULL
			 OR @RptEndTime IS NULL)	)
  BEGIN
	SELECT @RptStartTime	= ISNULL(@RptStartTime,DATEADD(hh,-1 * @int_HourInterval,@in_StartTime))  ,  
		   @RptEndTime		= ISNULL(@RptEndTime,DATEADD(hh,@int_HourInterval,@in_EndTime))
		   
  END
  
  ------------------------------------------------------------------------------------------------------------------  
  -- GET QFactors Variables  
  ------------------------------------------------------------------------------------------------------------------  
  
  DELETE FROM @QFactorType  
  
  SELECT @TableIdVar = TableId FROM dbo.Tables WITH(NOLOCK) WHERE TableName = 'Variables'  
    
  -- Variables with UDP 'Q-Factor Type' that are 'Q-Parameter' or 'Q-Task'  
  INSERT INTO @QFactorType (  
    PLId,  
    PUId,  
    VarId,  
    Type)  
  SELECT  pu.PL_Id,  
    pu.PU_Id,  
    v.Var_Id,  
    Value  
  FROM dbo.Table_Fields_Values tfv    WITH(NOLOCK)  
  JOIN dbo.Table_Fields   tf  WITH(NOLOCK)  
           ON  tfv.Table_Field_Id = tf.Table_Field_Id  
  JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
           ON  v.Var_Id =  tfv.KeyId  
  JOIN dbo.Prod_Units_Base    pu     WITH(NOLOCK)  
           ON      pu.PU_Id =  v.PU_Id  
  WHERE Table_Field_Desc =  @QFactorTypeUDF  
  AND   Value  IN ( SELECT Value   
        FROM #QFactorTypeFilters )  
  AND   tfv.TableId   = @TableIdVar  
  AND   pu.PL_Id = @PLId  
    
  -- Variables with UDP 'Q-Factor Primary' value 'Yes' that are already in the QFactor Type Table  
  INSERT INTO @QFactorPrimary (  
    PLId ,  
    PUId ,  
    VarId ,  
    DataTypeId)  
  SELECT  pu.PL_Id,  
    pu.PU_Id,  
    v.Var_Id,  
    v.Data_Type_Id  
  FROM dbo.Table_Fields_Values tfv WITH(NOLOCK)  
  JOIN dbo.Table_Fields   tf  WITH(NOLOCK)  
           ON  tfv.Table_Field_Id = tf.Table_Field_Id  
  JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
           ON  v.Var_Id =  tfv.KeyId  
  JOIN dbo.Prod_Units_Base    pu     WITH(NOLOCK)  
           ON      pu.PU_Id =  v.PU_Id  
  JOIN @QFactorType    qt  ON  qt.Varid =  v.Var_Id       
  WHERE Table_Field_Desc  =  @QFactorPrimaryUDF  
  AND   Value   IN ( SELECT Value   
         FROM #QFactorPrimaryFilters )  
  AND   tfv.TableId   = @TableIdVar  
  
  
   
  DELETE FROM @QFactorTests  
  
  ------------------------------------------------------------------------------------------------------------------  
  -- QFactors Tests  
     ------------------------------------------------------------------------------------------------------------------  
  -- SELECT * FROM @Production  
  -- Just get the last Alarm IF same variable is alarming multiple times    
  INSERT INTO @QFactorTests (     
         PLId   ,  
         PUId   ,  
     PUGDesc   ,  
         VarId   ,  
         Var_Desc  ,  
         Type   ,  
         ResultOn  ,  
         EntryOn   ,  
         Result   ,  
         Defect   ,  
         Status   ,  
         AlarmStatus    
         )  
  SELECT         qf.PLId  ,  
           qf.PUId  ,  
           pug.PUG_Desc ,  
           qf.VarId  ,           
           v.Var_Desc  ,  
           qft.Type  ,  
           t.Result_On  ,  
           t.Entry_On  ,  
           t.Result  ,  
           0    ,  
           @strPass  ,  
           'CLOSED'  
  FROM dbo.Tests t     WITH(NOLOCK)  
  JOIN @QFactorPrimary    qf  ON t.Var_Id   = qf.VarId  
  JOIN dbo.Variables_Base v   WITH(NOLOCK)  
          ON v.Var_id      =  qf.VarId  
  JOIN dbo.PU_Groups pug     WITH(NOLOCK)  
          ON v.pug_id   =   pug.pug_id  
  JOIN @QFactorType  qft  ON qft.VarId  = qf.VarId  
  WHERE Result_On >= @RptStartTime  
    AND Result_On < @RptEndTime  
    AND qf.PLId = @PLId  
    AND t.Canceled = 0  
  
  
  UPDATE  @QFactorTests   
   Set VariableType = (CASE   
         WHEN dt.data_type_desc LIKE '%PassFail%' THEN 'ATTRIBUTE'  
         ELSE 'VARIABLE'  
        END)  
  FROM    @QFactorTests  qft  
  JOIN  @QFactorPrimary qf     ON qft.VarId = qf.VarId  
  JOIN  dbo.Data_Type dt      WITH(NOLOCK)   
             ON qf.DataTypeID = dt.Data_Type_ID   
  WHERE  dt.Data_Type_Desc IN ('Float','Integer') Or dt.Data_Type_Desc Like '%PassFail%'  
  
  
  
  UPDATE  @QFactorTests   
    SET ProdId   = p.ProdId  
  FROM    @QFactorTests  qf  
  JOIN  @Production  p  ON  qf.PLId = p.PLId      
           AND qf.ResultOn > p.StartTime  
           AND qf.ResultOn <= p.EndTime  
  
  
  -- Get the Alarm data.  
  UPDATE @QFactorTests  
   SET -- AlarmStatus = (CASE WHEN ISNULL(a.End_Time,'') = '' THEN 'OPEN' ELSE 'CLOSED' END),  
       AlarmId   = a.Alarm_Id  ,  
    Action1   = er.Event_Reason_Name  ,  
    Cause1   = a.Cause1  ,  
    Ack    = a.Ack   ,  
    AlarmEndTime = a.End_Time   ,  
    Defect    = 1   ,  
    AlarmStatus  = 'OPEN' , -- (CASE WHEN ISNULL(a.End_Time,'') = '' THEN 1 ELSE 0 END)  
    AlarmMessage = (CASE   
         WHEN Action_Comment_Id IS NOT NULL AND   
           Cause_Comment_Id IS NOT NULL   
           THEN CONVERT(VARCHAR,c.Comment_Text) + ' - ' +  
             CONVERT(VARCHAR,c1.Comment_Text)  
         WHEN Action_Comment_Id IS NOT NULL AND   
           Cause_Comment_Id IS NULL THEN CONVERT(VARCHAR,c.Comment_Text)  
         WHEN Action_Comment_Id IS NULL AND   
           Cause_Comment_Id IS NOT NULL THEN CONVERT(VARCHAR,c1.Comment_Text)  
         ELSE NULL  
         END )  
      
  -- SELECT a.action1,*  
  FROM  dbo.Alarms  a     WITH(NOLOCK)  
  JOIN    @QFactorTests qft  ON  a.Key_id    = qft.VarId  
          AND  a.Start_Time  = qft.ResultOn  
  LEFT JOIN dbo.Event_Reasons er WITH(NOLOCK)   
           ON er.event_reason_id = a.action1  
  LEFT JOIN dbo.Comments c  WITH(NOLOCK)  
           ON c.Comment_Id = a.Action_Comment_id  
  LEFT JOIN dbo.Comments c1  WITH(NOLOCK)  
           ON c1.Comment_Id = a.Cause_Comment_Id  
  WHERE Alarm_Type_Id = @AlTypeIdVarLimits          -- 2010-09-27  
   OR Alarm_Type_Id = @AlTypeIdSPC  
   OR Alarm_Type_Id = @AlTypeIdSPCGroup  
  
  UPDATE @QFactorTests  
   SET  Defect = 0,  
     AlarmStatus = 'CLOSED',  
     AlarmComment = 'CLOSED',  
     Duration = datediff(mi,ResultOn,AlarmEndTime)  
  WHERE  (  
     Action1 IS NOT NULL  OR  
     Cause1 IS NOT NULL  OR  
     Ack = 1    
    )  
     AND AlarmEndTime  IS NOT NULL  
     AND Alarmid IS NOT NULL  
  
  UPDATE @QFactorTests  
   SET  Defect    = 1,  
     AlarmStatus  = 'Not acknowledged',  
     Duration  = 'Still Open'  
  WHERE  (   
     Action1 IS NULL    
     AND Cause1 IS NULL  
     AND Ack <> 1  
    )  
     AND AlarmEndTime IS NOT NULL  
     AND Alarmid IS NOT NULL  
  
  
  UPDATE @QFactorTests  
  SET  Defect    = 1,  
    AlarmStatus  = 'OPEN',  
    Duration  = 'OPEN'  
  WHERE (AlarmEndTime  IS NULL  
    AND Alarmid IS NOT NULL)  
  
  UPDATE @QFactorTests  
  SET  Defect    = 1,  
    AlarmStatus  = NULL,  
    Duration  = NULL  
  WHERE Result IS NULL  
  
  
  ----------------------------------------------------------------------------------------------  
  -- START Building the Recordsets for OutPUT  
  ----------------------------------------------------------------------------------------------  
  
  DELETE FROM @RS2Summary  
  DELETE FROM @RS3Summary  
  DELETE FROM @RS4Summary  
  DELETE FROM @RS5Summary  
  DELETE FROM @RS6Summary  
  DELETE FROM @RS7Summary  
  --DELETE FROM @AttrTests  
  DELETE FROM @OpenIssues  
  DELETE FROM @TotalTests  
  DELETE FROM @Output  
   

SET @UDPDesc = 'Is_Downtime' -- FO-02619

-- Step 1.
SELECT @intTableId = TableId 
FROM 	dbo.Tables WITH (NOLOCK)
WHERE TableName = 'prod_units'

-- Step 2.

SELECT @intTableFieldId = Table_Field_Id
FROM dbo.Table_Fields WITH (NOLOCK) 
WHERE Table_Field_Desc = @UDPDesc
AND TableId = @intTableId


-- Modify this to get the @AttrTests from the Downtimes table from now ON.
INSERT INTO @tblDowntimes (
		PLID			,
		PUId			,
		StartTime		,
		EndTime				)
SELECT DISTINCT
		pupp.PL_Id		,
		ted.PU_Id		,
		Start_Time	,
		End_Time		
FROM dbo.Timed_Event_Details ted WITH(NOLOCK)
	JOIN   dbo.Prod_Units_Base Pu WITH (NOLOCK) ON ted.PU_Id = pu.PU_Id
	JOIN   @ProdUnitPrdPath pupp ON pu.PL_Id = pupp.PL_Id
	JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK) ON tfv.KeyId = pu.pu_id
WHERE tfv.TableId = @intTableId AND tfv.Table_Field_Id = @intTableFieldId AND tfv.value = 1 
AND Start_Time < @in_ENDTime AND (End_Time > @in_StartTime OR End_Time is NULL) 



	--
	-- There is no Downtimes Events so lets create them
	--INSERT INTO @tblDowntimes  (PLID,PUId,StartTime,EndTime)
	--VALUES (1,1,'2010-06-10 12:00','2010-06-10 16:00')
	----
	--INSERT INTO @tblDowntimes  (PLID,PUId,StartTime,EndTime)
	--VALUES (1,3,'2010-06-10 16:00','2010-06-10 18:00')
	--

	UPDATE @tblDowntimes
		SET STLookUp = DateAdd(minute,@INT_RptNegMin,StartTime),
			ETLookUp = DateAdd(minute,-@INT_RptNegMin,EndTime)

	--
	-- select '@tblDowntimes',* from @tblDowntimes ORDER BY StartTime


	/*
     INSERT @AttrTests (   PU_Id,  
         PUGDesc,  
         PUG_ID,  
         Result,  
         Result_On,  
         Result_OnNeg30,  
         Result_OnPos30,  
         Entry_On,  
         Var_Id )  
     SELECT       pupp.PU_Id,  
         PUG_Desc,  
         PUG_Id,  
         Result,  
         Result_on,  
         DateAdd(minute,-@INT_RptNegMin,Result_On),  
            DateAdd(minute,@INT_RptPosMin,Result_On),  
         Entry_on,  
         Var_Id  
     FROM dbo.Tests T    WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON pupp.TestCompleteVarId = t.Var_Id   
     WHERE pupp.PUG_Desc LIKE '%Attr%'  
    AND pupp.PUG_Desc NOT LIKE '%Measurable%'  
    AND T.Result_ON >= @RptStartTime   
       AND T.Result_ON < @RptENDTime      
    AND pupp.PL_Id  =  @PLId  
  */

 
  -- All that is not UDE and is Production Events or Time
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        Isopen)  
     SELECT  
		v.PU_Id,  
        v.PUG_ID,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        t.Result,  
        t.Result_on,  
        t.Entry_on,  
        t.Var_Id ,
        1 
  FROM  
		  @ProdUnitPrdPath  pupp 
		  JOIN dbo.Tests T    WITH(NOLOCK) ON pupp.TestCompleteVarId = t.Var_Id   
		  JOIN dbo.Variables_Base v WITH(NOLOCK) ON v.Var_Id = pupp.TestCompleteVarId
		  JOIN dbo.PU_Groups pug WITH(NOLOCK) ON v.PUG_Id = pug.PUG_Id

  WHERE 
 	 --    
    pupp.PL_Id  = @PLId  
	AND t.Result_ON >= @RptStartTime   
    AND t.Result_ON < @RptENDTime  	
	-- Just for Time Variables
	-- AND v.Event_Type = '0'
	AND v.Event_Type IN (0,1)
	AND (t.result = 0  OR t.result IS NULL) 


		-- Get rid of those Time Events or Production Events that drops inside a Downtime Stop.
		DELETE @OpenIssues
		FROM @OpenIssues  oi
		JOIN dbo.Prod_Units_Base pu ON pu.PU_Id = oi.PU_Id
		JOIN @tblDowntimes d ON d.PLId = pu.PL_Id
		  			-- We now have to do this backwards (x minutes after the stop and x minutes before the stop we need to watch out) 
		--AND (Result_ON > DateAdd(minute,@INT_RptNegMin,d.StartTime) AND Result_On <= DateAdd(minute,-@INT_RptNegMin,d.EndTime))
		AND (Result_ON > DateAdd(minute,@INT_RptNegMin,d.StartTime) AND (Result_On <= DateAdd(minute,-@INT_RptNegMin,d.EndTime) OR d.EndTime is NULL))--FO-02173

								
-- All that is User Defined Events
  INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        IsOpen)  
  SELECT DISTINCT   pupp.PU_Id,  
        pupp.PUG_ID,  
        pupp.PUG_Desc,  
        v.Var_Desc,  
        t.Result,  
        t.Result_on,  
        t.Entry_on,  
        t.Var_Id,
        1         
  FROM dbo.Tests t     WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON  pupp.TestCompleteVarId = t.Var_Id  
  JOIN dbo.Variables_Base v  WITH(NOLOCK) ON v.Var_Id = t.Var_Id  
  WHERE   t.Result_ON >= @RptStartTime   
    AND t.Result_ON < @RptENDTime  
    AND pupp.PL_Id  = @PLId 
    AND (t.result = 0  OR t.result IS NULL) 
	AND v.Event_Type NOT IN (0,1)



  -- Variable groups such that all test entries within that group are reported,   
  -- whether or not the line is up or down  
  INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        IsOpen)  
  SELECT DISTINCT   pupp.PU_Id,  
        pupp.PUG_ID,  
        pupp.PUG_Desc,  
        v.Var_Desc,  
        t.Result,  
        t.Result_on,  
        t.Entry_on,  
        t.Var_Id,
        1         
  FROM dbo.Tests t     WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON  pupp.TestCompleteVarId = t.Var_Id  
  JOIN dbo.Variables_Base v  WITH(NOLOCK)  
         ON v.Var_Id = t.Var_Id  
  JOIN #PUGExcluded pe  ON pe.PUGDesc = pupp.PUG_Desc  
  WHERE   t.Result_ON >= @RptStartTime   
    AND t.Result_ON < @RptENDTime  
    AND pupp.PL_Id  = @PLId 
    AND (t.result = 0  OR t.result IS NULL) 
   

  --SELECT '@OpenIssues',* FROM @OpenIssues WHERE PUGDesc = 'Attributes' OR PUGDesc = 'Measurable Attributes' ORDER BY PUGDesc

     -- PQM Tests  
  -- Check if exists Attributes columns to insert the Variables, if not inserts all variables  
  -- at report time windows  
  --IF (SELECT COUNT(*) FROM @AttrTests) > 0  
  --BEGIN  
  -- INSERT @OpenIssues ( PU_Id,  
  --       PUG_ID,  
  --       PUGDesc,  
  --       Var_Desc,  
  --       Result,  
  --       Result_On,  
  --       Entry_On,  
  --       Var_Id,
  --       IsOpen)  
  -- SELECT DISTINCT   pupp.PU_Id,  
  --       pupp.PUG_ID,  
  --       pupp.PUG_Desc,  
  --       v.Var_Desc,  
  --       T.Result,  
  --       T.Result_on,  
  --       T.Entry_on,  
  --       T.Var_Id ,
  --       1 
  --  FROM dbo.Tests T     WITH(NOLOCK)       
  --  JOIN @ProdUnitPrdPath  pupp  ON pupp.TestCompleteVarId = t.Var_Id    
  --  JOIN dbo.Variables    v  WITH(NOLOCK)  
  --          ON    v.Var_Id = t.Var_Id  
  --  JOIN @AttrTests AT     ON T.Result_ON >= AT.Result_onNeg30   
  --          AND T.Result_ON < AT.Result_onPos30   
  --          AND at.PU_Id = pupp.PU_Id  
  --  JOIN dbo.Sheet_Columns sc   WITH(NOLOCK)   
  --          ON sc.Sheet_Id = pupp.SheetId   
  --          AND sc.Result_ON = T.Result_ON   
  --  LEFT JOIN #PUGExcluded pe  ON pe.PUGDesc = pupp.PUG_Desc      
  -- WHERE (T.result = 0  OR T.result IS NULL)  
  --    AND T.Result_ON  >=  @RptStartTime   
  --    AND T.Result_ON  <  @RptENDTime      
  --    AND pupp.PL_Id  = @PLId  
  --    AND pe.PUGDesc IS NULL  
  --    AND pupp.PUG_Id NOT IN ( SELECT DISTINCT PUG_Id FROM @OpenIssues )  
  --END  
--  ELSE  
--  BEGIN  
--   INSERT @OpenIssues ( PU_Id,  
--         PUG_ID,  
--         PUGDesc,  
--         Var_Desc,  
--         Result,  
--         Result_On,  
--         Entry_On,  
--         Var_Id)  
--   SELECT DISTINCT   pupp.PU_Id,  
--         pupp.PUG_ID,  
--         pupp.PUG_Desc,  
--         v.Var_Desc,  
--         T.Result,  
--         T.Result_on,  
--         T.Entry_on,  
--         T.Var_Id  
--    FROM dbo.Tests T     WITH(NOLOCK)       
--    JOIN @ProdUnitPrdPath  pupp  ON pupp.TestCompleteVarId = t.Var_Id    
--    JOIN dbo.Variables    v  WITH(NOLOCK)  
--            ON    v.Var_Id = t.Var_Id  
--    JOIN dbo.Sheet_Columns sc   WITH(NOLOCK)   
--            ON sc.Sheet_Id = pupp.SheetId   
--            AND sc.Result_ON = T.Result_ON       
--    WHERE ( T.Result <> 1 OR T.Result IS NULL )  
--      AND T.Result_ON  >=  @RptStartTime   
--      AND T.Result_ON  <  @RptENDTime      
--      AND pupp.PL_Id  = @PLId  
--  END  
 
  ---------------------------------------------------------------------------------------------------------------  
   -- OOS Issues  
  -- Get only the open alarms of alarm types 'Variable Limits', 'SPC' or 'SPC Group'  
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Type,  
        Result,  
        Result_on,  
        Entry_On,  
        Var_Id,
        IsOpen,
        IDAlarm)  
  SELECT DISTINCT   pupp.PU_Id,  
        pupp.PUG_ID,  
        pupp.PUG_Desc,  
        v.Var_Desc,  
        'OOS',  
        COALESCE(er.Event_Reason_Name,@strOOS),  
        a.Start_Time,  
        a.End_Time,  
        v.Var_Id ,
        (CASE WHEN a.End_Time IS NULL THEN   1
                     ELSE 0  
            END),
            a.Alarm_Id 
  FROM dbo.Alarms a   WITH(NOLOCK)  
  JOIN dbo.Variables_Base v  WITH(NOLOCK)   
          ON a.Key_Id = v.Var_Id  
  JOIN @ProdUnitPrdPath pupp  ON v.PUG_Id = pupp.PUG_Id  
  LEFT JOIN dbo.Event_Reasons er WITH(NOLOCK)   
          ON a.Cause1 = er.Event_Reason_Id  
  WHERE pupp.PL_Id = @PLId  
    AND Start_Time >= @RptStartTime  
    AND Start_Time < @RptEndTime  
    AND a.End_Time IS NOT NULL  
	AND ( Alarm_Type_Id = @AlTypeIdVarLimits   -- 2010-09-27  
     OR Alarm_Type_Id = @AlTypeIdSPC  
     OR Alarm_Type_Id = @AlTypeIdSPCGroup  
     )  
    AND v.Var_Id NOT IN (SELECT VarId FROM @QFactorTests)  
  
  

   -- OOS Issues  
  -- Get only the open alarms of alarm types 'Variable Limits', 'SPC' or 'SPC Group'  
      INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Type,  
        Result,
        Result_on,  
        Entry_On,  
        Var_Id,
        IsOpen,
        IDAlarm)  
  SELECT DISTINCT   pupp.PU_Id,  
        pupp.PUG_ID,  
        pupp.PUG_Desc,  
        v.Var_Desc,  
        'Open',
        COALESCE(er.Event_Reason_Name,@strOOS),
		a.Start_Time,  
        a.End_Time,  
        v.Var_Id  ,
        (CASE WHEN a.End_Time IS NULL THEN   1
              ELSE 0  
         END),
         a.alarm_id
  FROM dbo.Alarms a   WITH(NOLOCK)  
  JOIN dbo.Variables_Base v  WITH(NOLOCK)   
          ON a.Key_Id = v.Var_Id  
  JOIN @ProdUnitPrdPath pupp  ON v.PUG_Id = pupp.PUG_Id  
  LEFT JOIN dbo.Event_Reasons er WITH(NOLOCK)   
          ON a.Cause1 = er.Event_Reason_Id  
  WHERE pupp.PL_Id = @PLId
    AND Start_Time >= @RptStartTime
     AND Start_Time <  @RptEndTime
	AND a.End_Time is null
    AND ( Alarm_Type_Id = @AlTypeIdVarLimits   -- 2010-09-27  
     OR Alarm_Type_Id = @AlTypeIdSPC  
     OR Alarm_Type_Id = @AlTypeIdSPCGroup  
     )  
    AND v.Var_Id NOT IN (SELECT VarId FROM @QFactorTests)  

----------------------------------------------------------------------------------------
--Update Cause/Action of alarm types 'Variable Limits', 'SPC' or 'SPC Group'
----------------------------------------------------------------------------------------

IF  (SELECT count(a.cause4) from alarms a join @openissues oi on a.alarm_id = oi.idalarm)>0
BEGIN

		UPDATE @OpenIssues
				SET Result= er.Event_Reason_Name
		FROM  @OpenIssues OI
		JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
		left JOIN dbo.Event_Reasons er WITH(NOLOCK)   
		ON a.Cause4 = er.Event_Reason_Id 
		WHERE a.Cause4 IS NOT NULL 

		UPDATE @OpenIssues
				SET Result=Result + ' / ' +er.Event_Reason_Name 
		FROM  @OpenIssues OI
		JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
		JOIN dbo.Event_Reasons er WITH(NOLOCK)   
		ON a.Action4 = er.Event_Reason_Id  
		WHERE a.Action4 IS NOT NULL 

END
ELSE
BEGIN
	IF (SELECT count(a.cause3) from alarms a join @openissues oi on a.alarm_id = oi.idalarm)>0
	BEGIN
	
	UPDATE @OpenIssues
	SET Result=er.Event_Reason_Name
	FROM  @OpenIssues OI
	JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
	left JOIN dbo.Event_Reasons er WITH(NOLOCK)   
	ON a.Cause3 = er.Event_Reason_Id  
	WHERE a.Cause3 IS NOT NULL 
	
	UPDATE @OpenIssues
	SET Result=Result + ' / ' +er.Event_Reason_Name 
	FROM  @OpenIssues OI
	JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
	JOIN dbo.Event_Reasons er WITH(NOLOCK)   
	ON a.Action3 = er.Event_Reason_Id  
	WHERE a.Action3 IS NOT NULL 
	END
	ELSE
	BEGIN
	if  (SELECT count(a.cause2) from alarms a join @openissues oi on a.alarm_id = oi.idalarm)>0
	BEGIN
	
		UPDATE @OpenIssues
		SET Result=er.Event_Reason_Name
		FROM  @OpenIssues OI
		JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
		left JOIN dbo.Event_Reasons er WITH(NOLOCK)   
		ON a.Cause2 = er.Event_Reason_Id  
		WHERE a.Cause2 IS NOT NULL 
		
		UPDATE @OpenIssues
		SET Result=Result + ' / ' +er.Event_Reason_Name 
		FROM  @OpenIssues OI
		JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
		JOIN dbo.Event_Reasons er WITH(NOLOCK)   
		ON a.Action2 = er.Event_Reason_Id  
		WHERE a.Action2 IS NOT NULL 
	END
	ELSE
	BEGIN
	if  (SELECT count(a.cause1) from alarms a join @openissues oi on a.alarm_id = oi.idalarm)>0
	BEGIN
	
	UPDATE @OpenIssues
	SET Result= er.Event_Reason_Name
	FROM  @OpenIssues OI
	JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
	JOIN dbo.Event_Reasons er WITH(NOLOCK)   
	ON a.Cause1 = er.Event_Reason_Id  
	WHERE a.Cause1 IS NOT NULL 
	
	UPDATE @OpenIssues
	SET Result=Result + ' / ' +er.Event_Reason_Name 
	FROM  @OpenIssues OI
	JOIN Alarms A WITH(NOLOCK) ON A.Alarm_Id=OI.IDAlarm
	JOIN dbo.Event_Reasons er WITH(NOLOCK)   
	ON a.Action1 = er.Event_Reason_Id  
	WHERE a.Action1 IS NOT NULL 
	END
	END
	END
	
END

  ---------------------------------------------------------------------------------------------------------------  
  -- QA ReEst Tests  
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_on,  
        Entry_On,  
        Var_Id,
        IsOpen)  
     SELECT      pupp.PU_Id,  
        pupp.QAReestPUGId,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        Result,  
        Result_on,   
        Entry_on,  
        v.Var_Id ,
        1 
      FROM dbo.Tests t     WITH(NOLOCK)  
   JOIN @ProdUnitPrdPath pupp  ON pupp.QAReEstVarId = t.Var_Id    
   JOIN dbo.Variables_Base  v  WITH(NOLOCK)  
           ON  v.Var_Id = t.Var_Id  
            AND v.PUG_Id = pupp.QAReestPUGId  
   JOIN dbo.PU_Groups  pug  WITH(NOLOCK)  
           ON pug.PUG_Id = pupp.QAReestPUGId  
      WHERE Result = @ConstOpen  
      AND pupp.PL_Id  = @PLId  
      AND T.Result_ON >= @RptStartTime   
          AND T.Result_ON < @RptENDTime   
   GROUP BY Test_Id,  
      pupp.PU_Id,  
      pupp.QAReestPUGId,  
      pug.PUG_Desc,  
      v.Var_Desc,  
      Result,  
      Result_on,  
      Entry_on,  
      v.Var_Id     
   
  -- QV ReEst Tests  
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_on,  
        Entry_On,  
        Var_Id,
        IsOpen)  
     SELECT         pupp.PU_Id,  
        pupp.QVReestPUGId,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        Result,  
        Result_on,  
        Entry_on,  
        v.Var_Id,
        1  
      FROM dbo.Tests t     WITH(NOLOCK)  
   JOIN @ProdUnitPrdPath  pupp  ON pupp.QVReEstVarId = t.Var_Id   
   JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
    ON  v.Var_Id = t.Var_Id  
            AND v.PUG_Id = pupp.QVReestPUGId   
   JOIN dbo.PU_Groups  pug  WITH(NOLOCK)  
           ON pug.PUG_Id = pupp.QVReestPUGId        
         WHERE  Result = @ConstOpen  
      AND pupp.PL_Id  = @PLId  
     AND T.Result_ON >= @RptStartTime   
        AND T.Result_ON < @RptENDTime    
   GROUP BY Test_Id,  
      pupp.PU_Id,  
      pupp.QVReestPUGId,  
      pug.PUG_Desc,  
      v.Var_Desc,  
      Result,  
      Result_on,  
      Entry_on,  
      v.Var_Id    
   
     -- QV ReEval Tests  
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        IsOpen)  
     SELECT      pupp.PU_Id,  
        pupp.QVReEvalPUGId,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        Result,  
        Result_on,  
        Entry_on,  
        v.Var_Id ,
        1 
      FROM dbo.Tests t     WITH(NOLOCK)  
   JOIN @ProdUnitPrdPath  pupp  ON  pupp.QVReEvalVarId = t.Var_Id    
   JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
           ON  v.Var_Id = t.Var_Id  
            AND v.PUG_Id = pupp.QVReEvalPUGId  
   JOIN dbo.PU_Groups  pug  WITH(NOLOCK)  
           ON pug.PUG_Id = pupp.QVReEvalPUGId               
      WHERE Result <> @QVReEvalConstOpen   
        AND Result <> @QVReEvalNoDefect  
     AND Result <> @QVReSubdivideScrap  
     AND pupp.PL_Id  = @PLId  
     AND T.Result_ON >= @RptStartTime   
        AND T.Result_ON < @RptENDTime   
   GROUP BY Test_Id,  
      pupp.PU_Id,  
      pupp.QVReEvalPUGId,  
      pug.PUG_Desc,  
      v.Var_Desc,  
      Result,  
      Result_on,  
      Entry_on,  
      v.Var_Id   
    
   
  -- QA ReEval Tests  
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        Isopen)  
     SELECT      pupp.PU_Id,  
        pupp.QAReEvalPUGId,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        Result,  
        Result_on,  
        Entry_on,  
        v.Var_Id  ,
        1
      FROM dbo.Tests t     WITH(NOLOCK)  
   JOIN @ProdUnitPrdPath  pupp  ON  pupp.QAReEvalVarId = t.Var_Id     
   JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
           ON  v.Var_Id = t.Var_Id  
            AND v.PUG_Id = pupp.QAReEvalPUGId  
   JOIN dbo.PU_Groups  pug  WITH(NOLOCK)  
           ON pug.PUG_Id = pupp.QAReEvalPUGId              
      WHERE  Result = @ConstOpen  
       AND pupp.PL_Id  = @PLId  
     AND T.Result_ON >= @RptStartTime   
        AND T.Result_ON < @RptENDTime      
   GROUP BY Test_Id,  
      pupp.PU_Id,  
      pupp.QAReEvalPUGId,  
      pug.PUG_Desc,  
      v.Var_Desc,  
      Result,  
      Result_on,  
      Entry_on,  
      v.Var_Id  
  ---------------------------------------------------------------------------------------------------------------  
  ---------------------------------------------------------------------------------------------------------------  
     -- Deal with open deviations that occured for the timeframe, but were open after the ENDtime   
     INSERT @OpenIssues ( PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        Isopen)  
      SELECT     pupp.PU_Id,  
        pupp.QAReEvalPUGId,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        Result,  
        Result_on,  
        Entry_on,  
        v.Var_Id ,
        1 
      FROM dbo.Tests t     WITH(NOLOCK)   
   JOIN @ProdUnitPrdPath  pupp  ON  pupp.QAReEvalVarId = t.Var_Id    
   JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
           ON  v.Var_Id = t.Var_Id  
            AND v.PUG_Id = pupp.QAReEvalPUGId  
   JOIN dbo.PU_Groups  pug  WITH(NOLOCK)  
           ON pug.PUG_Id = pupp.QAReEvalPUGId      
      WHERE Result_ON IN (  
SELECT Result_ON   
      FROM dbo.Tests T2 WITH(NOLOCK)                     
      WHERE T2.Var_id = pupp.QAReEvalTimeVarId  
        AND IsDate(Result) = 1  
        AND Result < @RptEndTime  
        AND Result >= @RptStartTime  
        AND T2.Result_ON >= @RptEndTime  
                 )  
         AND Result = @ConstOpen  
      AND pupp.PL_Id  = @PLId  
   GROUP BY Test_Id,  
      pupp.PU_Id,  
      pupp.QAReEvalPUGId,  
      pug.PUG_Desc,  
      v.Var_Desc,  
      Result,  
      Result_on,  
      Entry_on,  
      v.Var_Id  
  
              
      INSERT @OpenIssues (    PU_Id,  
        PUG_ID,  
        PUGDesc,  
        Var_Desc,  
        Result,  
        Result_On,  
        Entry_On,  
        Var_Id,
        Isopen)  
      SELECT     pupp.PU_Id,  
        pupp.QVReEvalPUGId,  
        pug.PUG_Desc,  
        v.Var_Desc,  
        Result,  
        Result_on,  
        Entry_on,  
        v.Var_Id ,
        1 
      FROM dbo.Tests t     WITH(NOLOCK)  
   JOIN @ProdUnitPrdPath  pupp  ON  pupp.QVReEvalVarId = t.Var_Id   
   JOIN dbo.Variables_Base    v  WITH(NOLOCK)  
           ON  v.Var_Id = t.Var_Id  
            AND v.PUG_Id = pupp.QVReEvalPUGId  
   JOIN dbo.PU_Groups  pug  WITH(NOLOCK)  
           ON pug.PUG_Id = pupp.QVReEvalPUGId      
      WHERE Result_ON IN (  
         SELECT Result_ON   
      FROM dbo.Tests T2 WITH(NOLOCK)                     
      WHERE T2.Var_id = pupp.QVReEvalTimeVarId  
        AND IsDate(Result) = 1  
        AND Result < @RptEndTime  
        AND Result >= @RptStartTime  
        AND T2.Result_ON >= @RptEndTime )  
       AND Result <> @QVReEvalConstOpen   
       AND Result <> @QVReEvalNoDefect  
    AND Result <> @QVReSubdivideScrap  
    AND pupp.PL_Id  = @PLId  
   GROUP BY Test_Id,  
      pupp.PU_Id,  
      pupp.QVReEvalPUGId,  
      pug.PUG_Desc,  
      v.Var_Desc,  
      Result,  
      Result_on,  
      Entry_on,  
      v.Var_Id  
  
  --SELECT '@ProdUnitPrdPath',* FROM @ProdUnitPrdPath

  -- @TotalTests  
     INSERT INTO @TotalTests ( PU_Id ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result,  
         Status,  
         Include )  
  SELECT       		 
		 v.PU_Id  ,  
         v.PUG_ID  ,  
         pug.PUG_Desc  ,  
         v.Var_Id  ,  
         Result_On ,  
         Result  ,  
         @strPass   ,  
         1  
  --FROM @AttrTests at  
  --JOIN @ProdUnitPrdPath  pupp  ON  pupp.PUG_Id = at.PUG_Id  
  --   WHERE at.Result_ON >= @RptStartTime   
  --    AND at.Result_ON < @RptENDTime  
  -- AND pupp.PL_Id  = @PLId  
   FROM  
		  @ProdUnitPrdPath  pupp 
		  JOIN dbo.Tests T    WITH(NOLOCK) ON pupp.TestCompleteVarId = t.Var_Id   
		  JOIN dbo.Variables_Base v WITH(NOLOCK) ON v.Var_Id = pupp.TestCompleteVarId
		  JOIN dbo.PU_Groups pug WITH(NOLOCK) ON v.PUG_Id = pug.PUG_Id
  WHERE 
 		 --    
		pupp.PL_Id  = @PLId  
		AND t.Result_ON >= @RptStartTime   
		AND t.Result_ON < @RptENDTime  	
		-- Just for Time Variables
		--AND v.Event_Type = '0'
		AND v.Event_Type IN (0,1)
		AND pug.PUg_Desc NOT IN (SELECT PUGDesc FROM #PUGExcluded)  



-- Get rid of those Time Events or Production Events that drops inside a Downtime Stop.
DELETE @TotalTests
FROM @TotalTests  tt
JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.PU_Id = tt.PU_Id
JOIN @tblDowntimes d ON d.PLId = pu.PL_Id
		  	-- We now have to do this backwards (x minutes after the stop and x minutes before the stop we need to watch out) 
--AND (Result_ON > DateAdd(minute,@INT_RptNegMin,d.StartTime) AND Result_On <= DateAdd(minute,-@INT_RptNegMin,d.EndTime))
AND (Result_ON > DateAdd(minute,@INT_RptNegMin,d.StartTime) AND (Result_On <= DateAdd(minute,-@INT_RptNegMin,d.EndTime) OR d.EndTime is NULL))--FO-02173
--
--
--	@TotalTests that User Defined Events
     INSERT INTO @TotalTests ( PU_Id ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result,  
         Status,  
         Include )  
  SELECT       
		 v.PU_Id  ,  
         v.PUG_ID  ,  
         pug.PUG_Desc  ,  
         v.Var_Id  ,  
         Result_On ,  
         Result  ,  
         @strPass   ,  
         1  
   FROM  
		  @ProdUnitPrdPath  pupp 
		  JOIN dbo.Tests T    WITH(NOLOCK) ON pupp.TestCompleteVarId = t.Var_Id   
		  JOIN dbo.Variables_Base v WITH(NOLOCK) ON v.Var_Id = pupp.TestCompleteVarId
		  JOIN dbo.PU_Groups pug WITH(NOLOCK) ON v.PUG_Id = pug.PUG_Id
  WHERE 
 		 --    
		pupp.PL_Id  = @PLId  
		AND t.Result_ON >= @RptStartTime   
		AND t.Result_ON < @RptENDTime  	
		-- Just for Time Variables
		-- AND v.Event_Type = '0'
		AND v.Event_Type NOT IN (0,1)
		AND pug.PUg_Desc NOT IN (SELECT PUGDesc FROM #PUGExcluded)  

  -- Variable groups such that all test entries within that group are reported,   
  -- whether or not the line is up or down  
  INSERT INTO @TotalTests( PU_ID ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result,  
         Status,  
         Include )  
  SELECT DISTINCT    pupp.PU_Id,  
         pupp.PUG_ID,  
         PUG_Desc,  
         T.Var_Id,  
         t.Result_On,  
         t.Result,  
         @strPass,  
         1           
  FROM dbo.Tests t     WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON  pupp.TestCompleteVarId = t.Var_Id  
  JOIN #PUGExcluded pe  ON pe.PUGDesc = pupp.PUG_Desc  
  WHERE   t.Result_ON >= @RptStartTime   
    AND t.Result_ON < @RptENDTime  
    AND pupp.PL_Id  = @PLId  

--SELECT '@TotalTests',* FROM @TotalTests  WHERE PUGDesc LIKE '%GMP%'

   --SELECT '@TotalTests',* FROM @TotalTests WHERE PUGDesc = 'Attributes' OR PUGDesc = 'Measurable Attributes' 
   --ORDER BY PUGDesc, Result_On

     -- PQM Tests  
  -- Check if exists Attributes columns to insert the Variables, if not inserts all variables  
  -- at report time windows  
  --IF (SELECT COUNT(*) FROM @AttrTests) > 0  
  -- BEGIN  
    --INSERT INTO @TotalTests( PU_ID ,  
    --       PUG_ID ,  
    --       PUGDesc ,  
    --       Var_Id ,  
    --       Result_On,  
    --       Result,  
    --       Status,  
    --       Include )  
    --SELECT DISTINCT    pupp.PU_Id,  
    --       pupp.PUG_ID,  
    --       PUG_Desc,  
    --       T.Var_Id,  
    --       t.Result_On,  
    --       t.Result,  
    --       @strPass,  
    --       (CASE WHEN AT.PUGDesc IS NOT NULL THEN 1  
    --                 ELSE 0  
    --        END)  
    --FROM dbo.Tests t     WITH(NOLOCK)  
    --JOIN @ProdUnitPrdPath  pupp ON  pupp.TestCompleteVarId = t.Var_Id  
    --LEFT JOIN @AttrTests AT  ON T.Result_ON >= AT.Result_onNeg30   
    --       AND T.Result_ON < AT.Result_onPos30   
    --       AND AT.PU_Id = pupp.PU_Id     
    --JOIN dbo.Sheet_Columns sc  WITH(NOLOCK)   
    --       ON sc.Sheet_Id = pupp.SheetId  
    --       AND sc.Result_ON = T.Result_On  
    --WHERE  t.Result_ON >= @RptStartTime   
    --     AND t.Result_ON < @RptENDTime  
    --  AND pupp.PL_Id  = @PLId  
    --  AND t.Var_Id NOT IN (SELECT Var_Id FROM @TotalTests)  
   --END  
--  ELSE  
--   BEGIN  
--    INSERT INTO @TotalTests( PU_ID ,  
--           PUG_ID ,  
--           PUGDesc ,  
--           Var_Id ,  
--           Result_On,  
--           Result,  
--           Status,  
--           Include )  
--    SELECT DISTINCT    pupp.PU_Id,  
--           pupp.PUG_ID,  
--           PUG_Desc,  
--           T.Var_Id,  
--           t.Result_On,  
--           t.Result,  
--           @strPass,  
--           1  
--    FROM dbo.Tests t     WITH(NOLOCK)  
--    JOIN @ProdUnitPrdPath  pupp ON  pupp.TestCompleteVarId = t.Var_Id   
--    JOIN dbo.Sheet_Columns sc  WITH(NOLOCK)   
--           ON sc.Sheet_Id = pupp.SheetId  
--           AND sc.Result_ON = T.Result_On  
--    WHERE   t.Result_ON >= @RptStartTime   
--         AND t.Result_ON < @RptENDTime  
--      AND pupp.PL_Id  = @PLId  
--      AND t.Var_Id NOT IN (SELECT Var_Id FROM @TotalTests)  
--   END  
  
  -- QAReest   
     INSERT INTO @TotalTests( PU_Id ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result ,  
         Status ,  
         Include  )  
     SELECT       pupp.PU_Id ,  
         pupp.QAReEstPUGId,  
         pug.PUG_Desc ,  
         t.Var_Id  ,  
         Result_On ,  
         Result  ,  
         @strPass  ,  
         1  
     FROM dbo.Tests t     WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp  ON   pupp.QAReEstVarId = t.Var_Id  
  JOIN dbo.PU_Groups pug   WITH(NOLOCK)  
          ON  pug.PUG_Id = pupp.QAReEstPUGId  
     WHERE T.Result_ON >= @RptStartTime   
    AND T.Result_ON < @RptEndTime   
      AND pupp.PL_Id  = @PLId  
  GROUP BY Test_Id,  
     pupp.PU_Id,  
     pupp.QAReestPUGId,  
     pug.PUG_Desc,  
     t.Var_Id  ,  
     Result,  
     Result_on  
       
  -- QVReest   
     INSERT INTO @TotalTests ( PU_Id ,  
         PUG_ID,  
         PUGDesc,  
         Var_Id ,  
         Result_On,  
         Result,  
         Status,  
         Include)  
     SELECT       pupp.PU_Id ,  
         pupp.QVReestPUGId ,  
         pug.PUG_Desc ,  
         Var_Id  ,  
         Result_On ,  
         Result  ,  
         @strPass  ,  
         1  
     FROM dbo.Tests t    WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON   pupp.QVReEstVarId = t.Var_Id  
  JOIN dbo.PU_Groups pug  WITH(NOLOCK)  
         ON  pug.PUG_Id = pupp.QVReestPUGId  
     WHERE T.Result_ON >= @RptStartTime   
    AND T.Result_ON < @RptEndTime   
      AND pupp.PL_Id  = @PLId  
  GROUP BY Test_Id,  
     pupp.PU_Id ,  
     pupp.QVReEstPUGId ,  
     pug.PUG_Desc ,  
     Var_Id  ,  
     Result_On ,  
     Result  
   
  -- QAReEval   
     INSERT INTO @TotalTests ( PU_Id ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result ,  
         Status ,  
         Include )  
     SELECT       pupp.PU_Id ,  
         pupp.QAReEvalPUGId ,  
         pug.PUG_Desc ,  
         Var_Id  ,  
         Result_On ,  
         Result  ,  
         @strPass  ,  
         1  
     FROM dbo.Tests t    WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON   pupp.QAReEvalVarId = t.Var_Id  
  JOIN dbo.PU_Groups pug  WITH(NOLOCK)  
         ON  pug.PUG_Id = pupp.QAReEvalPUGId  
     WHERE T.Result_ON >= @RptStartTime   
    AND T.Result_ON < @RptEndTime   
      AND pupp.PL_Id  = @PLId  
  GROUP BY Test_Id,  
     pupp.PU_Id ,  
     pupp.QAReEvalPUGId ,  
     pug.PUG_Desc ,  
     Var_Id  ,  
     Result_On ,  
     Result  
   
  -- QVReEval  
     INSERT INTO @TotalTests ( PU_Id ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result ,  
         Status ,  
         Include )  
     SELECT       pupp.PU_Id ,  
         pupp.QVReEvalPUGId ,  
         pug.PUG_Desc ,  
         Var_Id  ,  
         Result_On ,  
         Result  ,  
         @strPass  ,  
         1  
     FROM dbo.Tests t    WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON   pupp.QVReevalVarId = t.Var_Id  
  JOIN dbo.PU_Groups pug  WITH(NOLOCK)  
         ON  pug.PUG_Id = pupp.QVReEvalPUGId  
    WHERE T.Result_ON >= @RptStartTime   
    AND T.Result_ON < @RptEndTime   
      AND pupp.PL_Id  = @PLId  
  GROUP BY Test_Id,  
     pupp.PU_Id ,  
     pupp.QVReEvalPUGId ,  
     pug.PUG_Desc ,  
     Var_Id  ,  
     Result_On ,  
     Result  
  
  --------------------------------------------------------------------------------------------  
  -- Deal with open deviations that occured for the timeframe, but were open after the ENDtime  
  --------------------------------------------------------------------------------------------  
     INSERT INTO @TotalTests ( PU_ID ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result ,  
         Status ,  
         Include )  
     SELECT       pupp.PU_Id ,  
         pupp.QAReEvalPUGId ,  
         pug.PUG_Desc ,  
         Var_Id  ,  
         Result_on ,  
         Result  ,  
         @strPass  ,  
         1  
     FROM dbo.Tests t    WITH(NOLOCK)   
  JOIN @ProdUnitPrdPath  pupp ON  pupp.QAReEvalVarId = t.Var_Id   
  JOIN dbo.PU_Groups pug  WITH(NOLOCK)  
         ON pug.PUG_Id = pupp.QAReEvalPUGId  
     WHERE Result_ON IN (  
         SELECT Result_ON   
      FROM dbo.Tests T2 WITH(NOLOCK)                     
      WHERE T2.Var_id = pupp.QAReEvalTimeVarId  
        AND IsDate(Result) = 1  
        AND Result < @RptEndTime  
        AND Result >= @RptStartTime  
        AND T2.Result_ON >= @RptEndTime )   
      AND pupp.PL_Id  = @PLId  
  GROUP BY Test_Id,  
     pupp.PU_Id ,  
     pupp.QAReEvalPUGId ,  
     pug.PUG_Desc ,  
     Var_Id  ,  
     Result_on ,  
     Result  
   

     INSERT INTO @TotalTests ( PU_ID ,  
         PUG_ID ,  
         PUGDesc ,  
         Var_Id ,  
         Result_On,  
         Result ,  
         Status,  
         Include )  
  SELECT       pupp.PU_Id ,  
         pupp.QVReEvalPUGId ,  
         pug.PUG_Desc ,  
         Var_Id  ,  
         Result_on ,  
         Result  ,  
         @strPass  ,  
         1  
     FROM dbo.Tests t    WITH(NOLOCK)  
  JOIN @ProdUnitPrdPath  pupp ON  pupp.QVReEvalVarId = t.Var_Id  
  JOIN dbo.PU_Groups pug  WITH(NOLOCK)  
         ON pug.PUG_Id = pupp.QVReEvalPUGId  
     WHERE Result_ON IN (  
         SELECT Result_ON   
      FROM dbo.Tests T2 WITH(NOLOCK)                     
      WHERE T2.Var_id = pupp.QVReEvalTimeVarId  
        AND IsDate(Result) = 1  
        AND Result < @RptEndTime  
        AND Result >= @RptStartTime  
        AND T2.Result_ON >= @RptEndTime )     
      AND pupp.PL_Id  = @PLId        
  GROUP BY Test_Id,  
     pupp.PU_Id ,  
     pupp.QVReEvalPUGId ,  
     pug.PUG_Desc ,  
     Var_Id  ,  
     Result_on ,  
     Result   



     ------------------------------------------------------------------------------------------------------------------  
  -- Now UPDATE the TESTS FROM the @OpenIssues table.  
     ------------------------------------------------------------------------------------------------------------------  
 
  UPDATE @TotalTests  
         SET Status = @strFail   
      FROM @TotalTests tt   
      JOIN @OpenIssues oi ON  CONVERT(DATETIME,tt.result_ON,121) = CONVERT(DATETIME,oi.result_ON,121)   
         AND tt.PUG_Id = OI.PUG_Id  
         AND tt.var_id = oi.var_id  
  
  UPDATE @OpenIssues   
    SET Result = @strTestComplete   
  WHERE  Result = '0'   
    OR Result IS NULL  
  
  -- SELECT * FROM @QFactorTests  
  -- Update Q-Factors and Add them to the OpenIssues List  
  UPDATE @QFactorTests  
   SET Status = @strFail  
  WHERE Defect = 1 -- Result IS NULL OR Defect = 1  
  
  INSERT INTO @OpenIssues (PU_id  ,   
        PUGDesc  ,  
        Type  ,  
        Result  ,  
        Result_On ,  
        Entry_On ,  
        Var_Id  ,  
        Var_Desc ,  
        AlarmStatus ,  
        Duration ,  
        Action1  ,  
        Comments ,  
        Defect,
        Isopen  )  
  SELECT      PUId  ,   
        PUGDesc  ,  
        Type  ,  
        Result  ,  
        ResultOn ,  
        EntryON  ,  
        VarId  ,  
        Var_Desc  ,  
        AlarmStatus ,  
        Duration ,  
        Action1  ,  
        AlarmMessage,  
        Defect ,
        1
        
  FROM  @QFactorTests qft    
  WHERE  Defect = 1   
    OR Result IS NULL  
    OR AlarmId IS NOT NULL  
  
  
  ----------------------------------------------------------------------------------------------  
  -- CREATE @Summary OUTPUT  
  ----------------------------------------------------------------------------------------------  
  INSERT @RS2Summary (PUId,PUGId,Category)  
   SELECT DISTINCT PU_Id,0,PU_Desc  
    FROM @ProdUnitPrdPath  
    WHERE PL_Id = @PLId  
          
  INSERT @RS2Summary (PUId,PUGId,Category,Category_Status)  
   SELECT DISTINCT PU_Id,PUG_Id,'    ' + PUG_Desc,@strPass  
    FROM @ProdUnitPrdPath  
    WHERE PL_Id = @PLId  
            
  IF (SELECT COUNT(*) FROM @RS2Summary) = 0  
  INSERT @RS2Summary (PUId) VALUES (0)  
   -------------------------------------------------------------------------------------------------------------------------------  
  -- QFACTORS  
  -------------------------------------------------------------------------------------------------------------------------------  
  IF EXISTS( SELECT *  
     FROM #QFactorTypeFilters )  
  BEGIN  
   SELECT  @iDet = 4,  
     @iRows  = (SELECT COUNT(*) FROM #QFactorTypeFilters) + @iDet - 1  
  
   WHILE (@iDet < = @iRows) AND (@iDet < = 8)  
   BEGIN  
    SELECT @QFactorTFVar = Value FROM #QFactorTypeFilters WHERE RcdId = @iDet - 3  
  
    INSERT @RS3Summary (Category,Category_Status,TestCount)  
       SELECT @QFactorTFVar,@strPass,COUNT(*)   
     FROM @QFactorTests   
     WHERE Type = @QFactorTFVar  
  
    SELECT  @iDet = @iDet + 1  
   END  
  END  
  
  -------------------------------------------------------------------------------------------------------------------------------  
  -- Reest - Reev  
  -------------------------------------------------------------------------------------------------------------------------------  
  IF EXISTS( SELECT * FROM @ProdUnitPrdPath  
     WHERE QVReestPUGId IS NOT NULL  
     OR  QAReestPUGId IS NOT NULL  
     OR  QVReEvalPUGId IS NOT NULL  
     OR  QAReEvalPUGId IS NOT NULL )  
     BEGIN  
    INSERT @RS4Summary (Category,Category_Status)  
       VALUES (@QAReEstPUGDesc,@strPass)  
     
    INSERT @RS4Summary (Category,Category_Status)  
       VALUES (@QAReEvalPUGDesc,@strPass)  
     
       INSERT @RS4Summary (Category,Category_Status)  
       VALUES (@QVReEstPUGDesc,@strPass)  
     
       INSERT @RS4Summary (Category,Category_Status)  
       VALUES (@QVReEvalPUGDesc ,@strPass)  
  END  
  
     -----------------------------------------------------------------------------------------------------------  
     -- Summary Section UPDATE fails  
     -----------------------------------------------------------------------------------------------------------  
  -----------------------------------------------------------------------------------------------------------  
     -- @RS2Summary  
     -----------------------------------------------------------------------------------------------------------  

 ----------------------------------------------------------------------------------------------    
 
  -- Reassurance Testing  
  
  UPDATE @RS2Summary  
   SET Col_Count = ( SELECT Count(*)   
        FROM @TotalTests  
        WHERE Include = 1   
        AND PUG_Id = rs2.PUGId ),  
    Col_CountNI = ( SELECT Count(*)   
        FROM @TotalTests  
        WHERE Include = 1   
        AND PUG_Id = rs2.PUGId   
        AND Status = @strFail ),  
    Col_OOS = (SELECT COUNT(*)  
        FROM @OpenIssues  
        WHERE Type = 'OOS'  
        AND PUG_Id = rs2.PUGId )  
  FROM @RS2Summary rs2  
  WHERE PUGId <> 0  
  

  ------------------------------------------------------------------------------------------------------------   
  -- Update PUG Grouping  
  ------------------------------------------------------------------------------------------------------------  
  -- GET table Id for PU_Groups  
  SELECT @intTableId = TableId  
  FROM dbo.Tables WITH (NOLOCK)   
  WHERE TableName = 'PU_Groups'  
  
  -- GET table field Id for 'PUG_PRRGrouping' UDP  
  SET  @intTableFieldId = NULL  
  SELECT @intTableFieldId = Table_Field_Id  
   FROM dbo.Table_Fields WITH (NOLOCK)  
   WHERE Table_Field_Desc = @vchUDPDescPUG_PRRGrouping  
  
  
  IF EXISTS( SELECT * FROM @RS2Summary rs2  
     JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
              ON tfv.KeyId = rs2.PUGId  
     WHERE tfv.TableId = @intTableId  
      AND tfv.Table_Field_Id = @intTableFieldId  
      AND PUGId <> 0)  
  BEGIN  
   INSERT INTO @RS2Summary (PUId,PUGId,Category,Col_Count,Col_CountNI,Col_OOS,Category_Status)  
   SELECT PUId,1,'    ' + tfv.Value,SUM(Col_Count),SUM(Col_CountNI),SUM(Col_OOS),@strPass  
    FROM @RS2Summary rs2  
    JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
             ON tfv.KeyId = rs2.PUGId  
    WHERE tfv.TableId = @intTableId  
     AND tfv.Table_Field_Id = @intTableFieldId  
     AND PUGId <> 0  
    GROUP BY PUId,tfv.Value  
  
  
   DELETE FROM @RS2Summary  
   WHERE PUGId IN(  
     SELECT PUGId FROM @RS2Summary rs2  
     JOIN dbo.Table_Fields_Values tfv WITH (NOLOCK)  
              ON tfv.KeyId = rs2.PUGId  
     WHERE tfv.TableId = @intTableId  
      AND tfv.Table_Field_Id = @intTableFieldId  
      AND PUGId <> 0 )  
  END  

  
     -----------------------------------------------------------------------------------------------------------  
  UPDATE @RS2Summary  
   SET Category_Status = @strFail  
  WHERE ( Col_CountNI > 0  
     AND Col_CountNI IS NOT NULL )  
  OR  ( Col_OOS > 0  
     AND Col_OOS IS NOT NULL )  
  
  
  -----------------------------------------------------------------------------------------------------------  
     -- @RS3Summary  
     -----------------------------------------------------------------------------------------------------------  
  -- Q-Parameter Completion  
  SELECT  @iDet  = 1,  
    @iRows = (SELECT COUNT(*) FROM #QFactorTypeFilters)  
  
  
  WHILE (@iDet < = @iRows) AND (@iDet < = 5)  
  BEGIN  
    SELECT @QFactorTFVar = Value FROM #QFactorTypeFilters WHERE RcdId = @iDet  
    -- Q-Factors Completion  
    IF EXISTS (SELECT * FROM @QFactorTests WHERE Type = @QFactorTFVar AND Result IS NULL)  
    BEGIN  
     UPDATE @RS3Summary   
      SET Col_Completion = ( SELECT COUNT(*) FROM @QFactorTests   
            WHERE Type = @QFactorTFVar AND Result IS NULL),  
       Perc_Completion = (( SELECT COUNT(*) FROM @QFactorTests   
             WHERE Type = @QFactorTFVar   
             AND Result IS NOT NULL)* 100 ) / TestCount,  
       Category_Status = @strFail  
        WHERE Category = @QFactorTFVar  
    END  
    ELSE  
    BEGIN  
     UPDATE @RS3Summary  
      SET Perc_Completion = ( CASE ( SELECT ISNULL(COUNT(*),0)   
              FROM @QFactorTests WHERE Type = @QFactorTFVar )  
            WHEN 0 THEN NULL  
            ELSE 100  
            END   )  
        WHERE Category = @QFactorTFVar  
    END  
  
    -- Q-Factors Compliance  
    IF EXISTS (SELECT * FROM @OpenIssues WHERE Type = @QFactorTFVar AND Defect = 1)  
    BEGIN  
     UPDATE @RS3Summary   
      SET Col_Compliance = ( SELECT COUNT(*) FROM @OpenIssues WHERE Type = @QFactorTFVar AND Defect = 1),  
          Perc_Compliance = 100 - (  
             (( SELECT COUNT(*)   
              FROM @OpenIssues   
              WHERE Type = @QFactorTFVar   
              AND Defect = 1  
                  ) * 100 ) / TestCount  
             ),  
          
       Category_Status = @strFail  
           WHERE Category = @QFactorTFVar  
    END  
    ELSE  
    BEGIN  
     UPDATE @RS3Summary   
      SET Perc_Compliance = ( CASE ( SELECT COUNT(*)  
              FROM @QFactorTests WHERE Type = @QFactorTFVar )  
            WHEN 0 THEN NULL  
            ELSE 100  
            END   ),  
       Category_Status = ( CASE ( SELECT COUNT(*)  
              FROM @QFactorTests WHERE Type = @QFactorTFVar )  
            WHEN 0 THEN NULL  
            ELSE Category_Status  
            END   )  
     WHERE Category = @QFactorTFVar  
    END  
  
    SELECT @iDet = @iDet + 1  
  END  
  -----------------------------------------------------------------------------------------------------------  
     -- @RS4Summary  
     -----------------------------------------------------------------------------------------------------------  
  -- QA ReEstablish  
  UPDATE @RS4Summary   
   SET Category_Status = ( CASE WHEN (SELECT Count(*) FROM @OpenIssues   
            WHERE PUGDesc = @QAReEstPUGDesc ) > 0  
          THEN @strFail   
          ELSE Category_Status   
         END ),  
                Col_Count = (SELECT Count(*) FROM @TotalTests   
        WHERE Include = 1  
        AND PUGDesc = @QAReEstPUGDesc )  
        WHERE Category = @QAReEstPUGDesc  
   
     -- QV ReEstablish  
  IF (SELECT Count(*) FROM @OpenIssues OI  
   JOIN @ProdUnitPrdPath  pupp ON  pupp.QVReEstPUGID = OI.PUG_Id)  > 0   
     BEGIN  
   UPDATE @RS4Summary   
    SET Category_Status = @strFail,  
                 Col_Count = (SELECT Count(*) FROM @TotalTests  
         WHERE Status = @strFail   
         AND Include = 1  
         AND PUGDesc = @QVReEstPUGDesc)  
         WHERE Category = @QVReEstPUGDesc  
     END  
     ELSE  
     BEGIN  
   UPDATE @RS4Summary   
                SET Col_Count = (SELECT Count(*) FROM @TotalTests  
         WHERE Status = @strPass   
         AND Include = 1  
         AND PUGDesc = @QVReEstPUGDesc)  
         WHERE Category = @QVReEstPUGDesc  
     END  
   
   
     -- QA ReEvaluation  
  IF (SELECT Count(*) FROM @OpenIssues OI  
   JOIN @ProdUnitPrdPath  pupp ON  pupp.QAReEvalPUGID = OI.PUG_Id)  > 0   
     BEGIN  
   UPDATE @RS4Summary   
    SET Category_Status = @strFail,  
                 Col_Count = (SELECT COUNT(*) FROM @TotalTests TT  
         WHERE Status = @strFail AND Include = 1 AND TT.PUGDesc = @QAReevalPUGDesc),  
     Col_CountNI = 0  
         WHERE Category = @QAReEvalPUGDesc  
     END  
  ELSE  
     BEGIN  
         UPDATE @RS4Summary SET   
                Col_Count = (SELECT COUNT(*) FROM @TotalTests TT  
         WHERE Status = @strPass AND Include = 1 AND TT.PUGDesc = @QAReevalPUGDesc  
        ),  
       Col_CountNI = (SELECT COUNT(*) FROM @TotalTests TT  
         WHERE Status = @strPass AND Include = 0 AND Result = 1 AND TT.PUGDesc = @QAReevalPUGDesc  
        )   
         WHERE  Category = @QAReEvalPUGDesc  
  END  
   
     -- QV ReEvaluation  
     IF (SELECT Count(*) FROM @OpenIssues OI  
   JOIN @ProdUnitPrdPath  pupp ON  pupp.QVReEvalPUGID = OI.PUG_Id)  > 0   
     BEGIN  
   UPDATE @RS4Summary SET Category_Status = @strFail,  
                 Col_Count = (SELECT COUNT(*) FROM @TotalTests TT  
         WHERE Status = @strFail AND Include = 1 AND TT.PUGDesc = @QVReevalPUGDesc  
        ),  
     Col_CountNI = 0  
         WHERE Category = @QVReEvalPUGDesc  
     END  
     ELSE  
     BEGIN  
         UPDATE @RS4Summary SET   
                Col_Count = (SELECT COUNT(*) FROM @TotalTests TT  
         WHERE Status = @strPass AND Include = 1 AND TT.PUGDesc = @QVReevalPUGDesc  
        ),  
                 Col_CountNI = (SELECT COUNT(*) FROM @TotalTests TT  
         WHERE Status = @strPass AND Include = 0 AND Result = 1 AND TT.PUGDesc = @QVReevalPUGDesc  
        )  
         WHERE Category = @QVReEvalPUGDesc  
     END  
  
  -----------------------------------------------------------------------------------------------------------  
     -- @RS5Summary  
     -----------------------------------------------------------------------------------------------------------  
  -- if exists Missed testing  
  IF EXISTS (SELECT  *  FROM  @OpenIssues oi  
        JOIN  dbo.Prod_Units_Base pu WITH(NOLOCK) ON PU.PU_Id = OI.PU_Id  
       WHERE (Type NOT IN (SELECT Value FROM #QFactorTypeFilters)   
         OR Type IS NULL)  
         AND PUGDesc NOT IN (SELECT Category FROM @RS4Summary))  
  BEGIN   
   -- Non-QVariables output  
      INSERT @RS5Summary  ( Category  ,  
          StartTime  ,
          EndTime,  
         Type   ,  
         Reason   ,  
         PUDesc   )  
    SELECT     Var_Desc  ,         
         Result_On  ,  
         Entry_On	,
         PUGDesc   ,  
         Result   ,  
         pu.PU_Desc   
      FROM @OpenIssues oi  
   JOIN dbo.Prod_Units_Base pu WITH(NOLOCK)   
        ON PU.PU_Id = OI.PU_Id  
   WHERE (Type NOT IN (SELECT Value FROM #QFactorTypeFilters)   
     OR Type IS NULL )  
     AND PUGDesc NOT IN (SELECT Category FROM @RS4Summary)  
  END  
  ELSE  
  BEGIN   
   -- Insert row empty  
      INSERT @RS5Summary  (Category) VALUES ('')  
  END  
  
  -----------------------------------------------------------------------------------------------------------  
     -- @RS6Summary  
     -----------------------------------------------------------------------------------------------------------  
  IF EXISTS( SELECT *  
     FROM #QFactorTypeFilters )  
  BEGIN  
   -- If not exists Variables Non-Complaint  
   IF EXISTS (SELECT  *  FROM  @OpenIssues oi  
         JOIN  dbo.Prod_Units_Base pu  WITH(NOLOCK)  ON PU.PU_Id = OI.PU_Id  
          WHERE Type IN (SELECT Value FROM #QFactorTypeFilters))  
   BEGIN  
  
  
    -- QVariables should show the Output in a different way than Non-QVariables does  
    -- QVariables output  
  
       INSERT @RS6Summary ( Category ,  
           StartTime ,  
          Duration ,  
          Reason  ,  
          PUDesc  ,  
          Comments )  
    SELECT      Var_Desc ,  
          Result_On ,  
          Duration ,  
          Action1  ,  
          PU_Desc  ,  
          Comments  
    FROM @OpenIssues oi  
    JOIN dbo.Prod_Units_Base pu  WITH(NOLOCK)   
          ON PU.PU_Id = OI.PU_Id  
    WHERE Type IN (SELECT Value FROM #QFactorTypeFilters)    
   END  
   ELSE  
   BEGIN   
    -- Insert row empty  
    INSERT @RS6Summary  (Category) VALUES ('')  
   END  
  END  
  -----------------------------------------------------------------------------------------------------------  
     -- @RS7Summary  
     -----------------------------------------------------------------------------------------------------------  
  IF EXISTS( SELECT * FROM @ProdUnitPrdPath  
   WHERE QVReestPUGId IS NOT NULL  
   OR  QAReestPUGId IS NOT NULL  
   OR  QVReEvalPUGId IS NOT NULL  
   OR  QAReEvalPUGId IS NOT NULL )  
     BEGIN  
   IF EXISTS (SELECT  *  FROM  @OpenIssues oi  
         JOIN  dbo.Prod_Units_Base pu  WITH(NOLOCK)  ON PU.PU_Id = OI.PU_Id  
          WHERE PUGDesc IN (SELECT Category FROM @RS4Summary))  
   BEGIN  
  
    -- QVariables should show the Output in a different way than Non-QVariables does  
    -- QVariables output  
       INSERT @RS7Summary ( Category  ,  
           StartTime  ,  
          Type   ,  
          Category_Status ,  
          PUDesc  )  
    SELECT      Var_Desc ,  
          Result_On ,  
          PUGDesc  ,  
          Result  ,  
          PU_Desc    
    FROM @OpenIssues oi  
    JOIN dbo.Prod_Units_Base pu  WITH(NOLOCK)   
          ON PU.PU_Id = OI.PU_Id  
    WHERE PUGDesc IN (SELECT Category FROM @RS4Summary)  
   END  
   ELSE  
   BEGIN   
    -- Insert row empty  
    INSERT @RS7Summary  (Category) VALUES ('')  
   END  
  END  
  
   
  
---------------------------------------------------------------------------------------------------------------------  
--             Final Output                --  
---------------------------------------------------------------------------------------------------------------------  
  
  -- Details Variables  
  -- 0 = Only show top 5 variables, 1 = Show Details TOP 100 variables.   
  IF @int_ShowDetails = 1   
  BEGIN  
   SELECT @RS5Count = CASE WHEN COUNT(*) > 100 THEN 100 ELSE COUNT(*) END FROM @RS5Summary  
   SELECT @RS6Count = CASE WHEN COUNT(*) > 100 THEN 100 ELSE COUNT(*) END FROM @RS6Summary  
   SELECT @RS7Count = CASE WHEN COUNT(*) > 100 THEN 100 ELSE COUNT(*) END FROM @RS7Summary  
  END  
  ELSE  
  BEGIN  
   SELECT @RS5Count = CASE WHEN COUNT(*) < 5 THEN COUNT(*) ELSE 5 END FROM @RS5Summary  
   SELECT @RS6Count = CASE WHEN COUNT(*) < 5 THEN COUNT(*) ELSE 5 END FROM @RS6Summary  
   SELECT @RS7Count = CASE WHEN COUNT(*) < 5 THEN COUNT(*) ELSE 5 END FROM @RS7Summary  
  END  
  -----------------------------------------------------------------------------------------------------------  
  -- Header  
	  SELECT   @Plant  Plant  ,  
			   PLDESC    ,   
			   StartTime   ,  
			   EndTime    ,  
			  (CASE @int_RptGroupBy  
			   WHEN 1 THEN ProdDesc  -- 1 = Grouping by Product  
				 ELSE ProdCode  
			   END) ProdCode,  
			  PO     ,  
			  MinorGrouping  ,  
			  VolumeCount   ,  
			  Batch    ,  
				(CASE   @int_RptGroupBy
							WHEN 2 THEN
							   (CASE (SELECT COUNT(*) FROM  @ProductionPlan ps WHERE (ENDTIME IS NULL or StartTime IS NULL)and ps.PO=prg.PO)
										WHEN 0 THEN
											 (CASE (SELECT COUNT(*) FROM @OpenIssues WHERE Defect <> 0 OR Defect IS NULL) 
													WHEN 0 THEN 
													@strPass 
												   ELSE @strFail  
												   END)
										ELSE
										(CASE (SELECT COUNT(*) FROM @OpenIssues WHERE Defect <> 0 OR Defect IS NULL) 
													WHEN 0 THEN 
													@strPassIncPo 
												   ELSE @strFailIncPo --PO INCOMPLETE 
												   END)
										 
										END)
							ELSE
								  (CASE (SELECT COUNT(*) FROM @OpenIssues WHERE Defect <> 0 OR Defect IS NULL) 
									 WHEN 0 THEN 
									  @strPass 
									 ELSE @strFail  
								   END)
					  END)  
				 AS txt_GlobalSignature ,   
		        
	         
		  ISNULL(@vchAppVersion,'')   AS AppVersion   ,  
		  ISNULL(@vchRTVersion,'')   AS RTversion   ,  
		  (SELECT COUNT(*) FROM @RS2Summary) AS RS2Count    ,  
		  (SELECT COUNT(*) FROM @RS3Summary) AS RS3Count    ,  
		  (SELECT COUNT(*) FROM @RS4Summary) AS RS4Count    ,  
		  @RS5Count       AS RS5Count    ,  
		  @RS6Count       AS RS6Count    ,  
		  @RS7Count       AS RS7Count      
	  FROM    @PosRelGrouping   prg
	  WHERE     PRGId   = @RECNo   
    
  
  -----------------------------------------------------------------------------------------------------------  
  -- Insert @RS2Summary on @Output table  
  --INSERT INTO @Output  
  --SELECT 'RS2 - Category',  
  --  'Col_Count',  
  --  'Col_CountNI',  
  --  'Col_OOS',  
  --  'Dummy1',  
  --  'Category_Status'  
  
  INSERT INTO @Output  
  SELECT Category,  
    Col_Count,  
    Col_CountNI,  
    Col_OOS,  
    Dummy1,  
    Category_Status  
  FROM @RS2Summary  
  ORDER BY PUId,PUGId  
     
  
  -----------------------------------------------------------------------------------------------------------  
  -- Insert @RS3Summary on @Output table   
  IF (SELECT COUNT(*) FROM @RS3Summary) <> 0  
  BEGIN    
   INSERT INTO @Output  
   SELECT 'RS3 - Category',  
     'Col_Completion',  
     'Col_Compliance',  
     'Perc_Completion',  
     'Perc_Compliance',  
     'Category_Status'  
  
   INSERT INTO @Output  
   SELECT Category,  
     Col_Completion,  
     Col_Compliance,  
     Perc_Completion,  
     Perc_Compliance,  
     Category_Status  
   FROM @RS3Summary  
  END  
  
  -----------------------------------------------------------------------------------------------------------     
  -- Insert @RS4Summary on @Output table  
  IF (SELECT COUNT(*) FROM @RS4Summary) <> 0  
  BEGIN  
   INSERT INTO @Output  
   SELECT 'RS4 - Category',  
     'Col_Count',  
     'Dummy1',  
     'Dummy2',  
     'Dummy3',  
     'Category_Status'  
  
   INSERT INTO @Output  
   SELECT Category,  
     Col_Count,  
     Dummy1,  
     Dummy2,  
     Dummy3,  
     Category_Status  
   FROM @RS4Summary  
  END  
  
  -----------------------------------------------------------------------------------------------------------  
  -- Details Variables  
  -- 0 = Only show top 5 variables, 1 = Show Details TOP 100 variables.   
  -----------------------------------------------------------------------------------------------------------  
  -- Insert @RS5Summary on @Output table  
  IF @RS5Count <> 0  
  BEGIN  
   INSERT INTO @Output  
   SELECT 'RS5 - Category',  
     'StartTime',  
     'Type',  
     'Reason',  
     'PUDesc',  
     'Comments'  
  
   IF @int_ShowDetails = 1   
   BEGIN  
    INSERT INTO @Output  
    SELECT TOP 100  
      Category,  
      CAST(StartTime AS NVARCHAR)+ ' - ' + (case when EndTime is null then 'Open' else CAST(EndTime AS NVARCHAR) end),
      Type,  
      Reason,  
      PUDesc,  
      Comments  
    FROM @RS5Summary  
    ORDER BY StartTime  
   END  
   ELSE  
   BEGIN  
    INSERT INTO @Output  
    SELECT TOP 5  
      Category,  
      StartTime,  
      Type,  
      Reason,  
      PUDesc,  
      Comments  
    FROM @RS5Summary  
    ORDER BY StartTime  
   END  
  END  
  

  -----------------------------------------------------------------------------------------------------------  
  -- Insert @RS6Summary on @Output table  
  IF (SELECT COUNT(*) FROM @RS6Summary) <> 0  
  BEGIN  
   INSERT INTO @Output  
   SELECT 'RS6 - Category',  
     'StartTime',  
     'Duration',  
     'Reason',  
     'PUDesc',  
     'Comments'  
  
   IF @int_ShowDetails = 1   
   BEGIN  
    INSERT INTO @Output  
    SELECT TOP 100  
      Category,  
      StartTime,  
      Duration,  
      Reason,  
      PUDesc,  
      Comments  
    FROM @RS6Summary  
    ORDER BY StartTime  
   END  
   ELSE  
   BEGIN  
    INSERT INTO @Output  
    SELECT TOP 5  
      Category,  
      StartTime,  
      Duration,  
      Reason,  
      PUDesc,  
      Comments  
    FROM @RS6Summary  
    ORDER BY StartTime  
   END  
  END  
  -----------------------------------------------------------------------------------------------------------  
  -- Insert @RS7Summary on @Output table  
  IF (SELECT COUNT(*) FROM @RS7Summary) <> 0  
  BEGIN  
   INSERT INTO @Output  
   SELECT 'RS7 - Category',  
     'StartTime',  
     'Type',  
     'Reason',  
     'PUDesc',  
     'Category_Status'  
  
   IF @int_ShowDetails = 1   
   BEGIN  
    INSERT INTO @Output  
    SELECT TOP 100  
      Category,  
      StartTime,  
      Type,  
      Reason,  
      PUDesc,  
      Category_Status  
    FROM @RS7Summary  
    ORDER BY StartTime  
   END  
   ELSE  
   BEGIN  
    INSERT INTO @Output  
    SELECT TOP 5  
      Category,  
      StartTime,  
      Type,  
      Reason,  
      PUDesc,  
      Category_Status  
    FROM @RS7Summary  
    ORDER BY StartTime  
   END  
  END  
  -----------------------------------------------------------------------------------------------------------  
  -- Shows the Final RS  
  -----------------------------------------------------------------------------------------------------------  
  SELECT * FROM @Output  
  -----------------------------------------------------------------------------------------------------------  
  
  -----------------------------------------------------------------------------------------------------------  
  SET @RECNo = @RECNo + 1  
  
 END  
END  
  
-------------------------------------------------------------------------------------------------------------  
-- Drop Temp Tables  
-------------------------------------------------------------------------------------------------------------  
DROP TABLE		#QFactorPrimaryFilters  
DROP  TABLE		#QFactorTypeFilters  
DROP TABLE		#PLIDList  
DROP TABLE		#PUGExcluded  
-------------------------------------------------------------------------------------------------------------  
--
RETURN  
SET NOCOUNT OFF

GO

GRANT EXECUTE ON [dbo].[spLocal_PositiveRelease] TO [OpDBManager] As [dbo]
GO