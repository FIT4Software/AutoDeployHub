
----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptCenterlineSpecs',
		@Inputs		= 6, 
		@Version	= '1.2'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
SELECT @AppId = MAX(App_Id) + 1 
		FROM dbo.AppVersions (NOLOCK)

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions (NOLOCK)
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


-----------------------------------------------------------------------------------------------------------------------
-- Drop Stored Procedure
-----------------------------------------------------------------------------------------------------------------------

IF EXISTS (
                  SELECT * FROM dbo.sysobjects 
                        WHERE Id = OBJECT_ID(N'[dbo].[spLocal_RptCenterlineSpecs]') 
                        AND OBJECTPROPERTY(id, N'IsProcedure') = 1                              
                  )
DROP PROCEDURE [dbo].[spLocal_RptCenterlineSpecs]

GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Report Name                    : Centerline Specifications
-- Store Procedure Name : spLocal_RptCenterlineSpecs
--
--
--     FRio : Arido Software
--     2018-02-10 
--     Store procedure re-writed to meet Centerline configuration for version 3.0.
--
---------------------------------------------------------------------------------------------------------------------------------------------------------
--     Version 1.0                Fernando Rio        Initial Release
--=================================================================================================
--		2018-2-10				Fernando Rio			Centerline 3.0	  Added: a - Product Selector  b - Centerline type filter
--		2018-03-17				Fernando Rio			Changed condition to look for Product Changes
--		2018-03-22				Fernando Rio			Fix an issue with Recipe Variables
--		2018-03-26				Damian Campana			Add columns MasterUnit and ChildUnit
--		2018-03-27				Fernando Rio			Output should be only of RTT_Reported = 1
--		2018-05-14				Santiago Gimenez		Output should have RTT Recipe UDP Value
--		2018-07-06				Santiago Gimenez		Delete variables NOT IN passed Prod Id.
--		2018-09-07				Santiago Gimenez		Adapted for RTT Lines.
--		2018-10-02				Santiago Gimenez		Changed Frequencies.
--		2018-11-07				Gonzalo Luc				Added calculation variables for RTT and Update Recipe flag based on Frequency for RTT.
--		2018-11-15				Gonzalo Luc				Change Recipe Dynamic frequency from recipe to (S)
--		2019-04-24				Santiago Gimenez		Change ProdCode field type to NVARCHAR.
--		2020-03-16              Camila Olguin           FO:Centerline - BRD 84, 45       
--		2020-09-16              Santiago Gimenez        Adapt the code for the new UDPs.
-- 1.1	2021-06-28				Gonzalo Luc				Added validation to update QCL Frequency names.
-- 1.2  2021-08-25				Gonzalo Luc				Add 3.1 UPD design to get recipe values.
--=================================================================================================

CREATE PROCEDURE dbo.spLocal_RptCenterlineSpecs
 --DECLARE
       @Equipment                 VARCHAR(1000),             --what equipment
       @CenterlineTypes           VARCHAR(1000)		= NULL ,             --all or certian
       @Start                     DATETIME     ,            --if @TimeWindows is UserDefined
       @ProdId                        INT           = NULL ,
       @CenterlineFilter		  VARCHAR(50)  

--WITH ENCRYPTION 
AS

--EXEC dbo.spLocal_RptCenterlineSpecs     '3731',null,'2018-10-30 00:00:00',null,'All'
 --SELECT 
 --          @Equipment                 =     '6591'                                         ,
 --          @CenterlineTypes           =     'Shiftly Auto,Shiftly Manual,Daily,Weekly,Monthly,Quarterly,QCL Manual,QCL Auto'                                          ,
 --          @Start                     =     '2021-08-03 18:30:00'                   ,
 --          @ProdId                    =		''                                              ,
 --          @CenterlineFilter          =		'All'

---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#CType', 'U') IS NOT NULL  DROP TABLE #CType
CREATE TABLE #CType (
                    ID                         INT,
                    CType               VARCHAR(100),
					Frequency			VARCHAR(10))
                    
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Data', 'U') IS NOT NULL  DROP TABLE #Data
CREATE TABLE #Data (
                    ID                         INT IDENTITY,
                    PUId                INT                 ,
                    UDEID               INT,
                    UDEStart            DATETIME,
                    UDEEnd              DATETIME,
                    FrecuencyStart      DATETIME,
                    FrecuencyEnd DATETIME,
                    UDEPUID                    INT,
                    UDEESTID            INT DEFAULT 0,
                    ESTDesc                    VARCHAR(50),
                    VarID               INT,
                    VarDesc                    VARCHAR(50),
                    EngUnits            VARCHAR(15),
                    UDEDesc                    VARCHAR(100),
                    MPUID               INT,
                    CTestTime           VARCHAR(50),        -- UDP Centerline_TestTime
                    CAuditFreq          VARCHAR(50),        -- UDP Centerline_AuditFreq
                    CQStartTime         VARCHAR(50),        -- UDP Centerline_QuarterStartTime
                    CReported           VARCHAR(50),        -- UDP Centerline_Reported 
                    EqGroup                    VARCHAR(50),
                    DataEntered         INT DEFAULT(0),            -- 1 data has been entered 0 not
                    EntryOnTime         INT DEFAULT (0),    -- 1 data was entered within the event time 0 not
                    EntryInSpec         INT DEFAULT(0),            -- 1 data within spec if entered 0 not	
                    EntryWindowEnd      DATETIME,
                    ProdID              INT,
                    LReject                    VARCHAR(25),
                    LWarning            NVARCHAR(25), 
                    LUser               NVARCHAR(25), 
                    Target              VARCHAR(25),
                    UUser               NVARCHAR(25), 
                    UWarning            NVARCHAR(25), 
                    UReject                    VARCHAR(25),
					Recipe				INT DEFAULT(0),
					PUGId				INT,
					PUGDesc				VARCHAR(50)
                    )

---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MasterOutput', 'U') IS NOT NULL  DROP TABLE #MasterOutput
CREATE TABLE #MasterOutput (
                    Id                         INT IDENTITY,
                    PlantName           NVARCHAR(200), 
                    Line                NVARCHAR(200), 
                    PUId                INT                 ,
                    PugDesc                    NVARCHAR(200), 
                     Frequency           NVARCHAR(200),
                    Lreject                    NVARCHAR(25), 
                    Lwarning            NVARCHAR(25), 
                    Luser               NVARCHAR(25), 
                    Target              NVARCHAR(25), 
                    UUser               NVARCHAR(25), 
                    UWarning            NVARCHAR(25), 
                    Ureject                    NVARCHAR(25),
                    SamplesTaken INT, 
                    SamplesDue          INT, 
                    FutureSamplesDue INT, 
                    Defects                    INT, 
                    ProdDesc            NVARCHAR(200), 
                    VarId               INT, 
                    VarDesc                    NVARCHAR(200), 
                    EngUnits            VARCHAR(15),
                    ProdCode            NVARCHAR(25), 
                    NextStartDate DATETIME, 
                    TestTime            DATETIME,
                    AlarmId                    INT                 ,
                    ActionComment NVARCHAR(200),
                    Action              NVARCHAR(200),
                    Cause               NVARCHAR(200),
                    MPUID               INT,
                    MasterUnit          NVARCHAR(200),
                    ChildUnit           NVARCHAR(200),
					Recipe				INT DEFAULT(0)
                    )

--RTT Test Times.
IF OBJECT_ID('tempdb.dbo.#RTT_EI', 'U') IS NOT NULL  DROP TABLE #RTT_EI
CREATE TABLE #RTT_EI ( 
					VarId				INT,
					Ext_Info			VARCHAR(200),
					EI_Start			INT,
					EI_Len				INT,
					TestTime			VARCHAR(30)
					)


DECLARE	@UnitProducts TABLE (
					UnitId			INT,
					ProdId			INT
					)

---------------------------------------------------------------------------------------------------
--Declare local variables
---------------------------------------------------------------------------------------------------
DECLARE
                    @End						DATETIME            ,
                    @PlantName					NVARCHAR(200)		,
					@DSId_Manual				INT					,
					@DSId_Auto					INT					,
					@DSId_Calc					INT					,
					@ESTableId					INT					
			


---------------------------------------------------------------------------------------------------
-- IF Product equals 0, means it's NULL
---------------------------------------------------------------------------------------------------

IF @ProdId = 0
BEGIN
	SET @ProdId = NULL
END

---------------------------------------------------------------------------------------------------
-- IF Start is bigger than now AND there no product selected, set Start = now.
---------------------------------------------------------------------------------------------------

IF @Start > GETDATE() AND @ProdId IS NULL
BEGIN
	SET @Start = GETDATE()
END

---------------------------------------------------------------------------------------------------
--Set the local variables
---------------------------------------------------------------------------------------------------


SET @PlantName             = (SELECT Value FROM dbo.Site_Parameters WITH(NOLOCK) WHERE Parm_ID = 12)
SELECT @End                = DATEADD(d, 1, @Start)
SELECT @DSId_Manual		   = DS_Id	FROM Data_Source WITH(NOLOCK) WHERE DS_Desc = 'AutoLog'
SELECT @DSId_Auto		   = DS_Id FROM Data_Source WITH(NOLOCK) WHERE DS_Desc = 'Historian'
SELECT @DSId_Calc		   = DS_Id FROM Data_Source WITH(NOLOCK) WHERE DS_Desc = 'CalculationMgr'
SELECT @ESTableId			= TableId FROM dbo.Tables WITH (NOLOCK) WHERE TableName = 'Event_Subtypes'

---------------------------------------------------------------------------------------------------
-- Get Centerline Event Types 
---------------------------------------------------------------------------------------------------

INSERT INTO #CType
	SELECT	ec.Event_Subtype_Id,
			Event_Subtype_Desc,
			fv.Value
	FROM	dbo.Event_Configuration ec	WITH (NOLOCK)
	JOIN	dbo.Event_Subtypes es		WITH (NOLOCK)	ON ec.Event_Subtype_Id = es.Event_Subtype_Id
	JOIN	dbo.Table_Fields_Values fv	WITH (NOLOCK)	ON es.Event_Subtype_Id = fv.KeyId
	JOIN	dbo.Table_Fields f			WITH (NOLOCK)	ON fv.Table_Field_Id = f.Table_Field_Id
	WHERE		ec.PU_Id IN (SELECT Value FROM Split(@Equipment))
	  AND		f.Table_Field_Desc = 'RTT_AuditFreq'
	  AND		f.TableId = @ESTableId

---------------------------------------------------------------------------------------------------
-- Get Data for CL 3.0 Lines.
---------------------------------------------------------------------------------------------------
INSERT	@UnitProducts
SELECT	PU_Id		,
		Prod_Id
FROM	PU_Products up	WITH (NOLOCK)
WHERE	PU_Id IN (SELECT Value FROM Split(@Equipment))
  AND	Prod_Id IN (SELECT Value FROM Split(@ProdId))

INSERT INTO #Data (        
                    PUId         ,
                    ESTDesc      ,
                    VarID        ,
                    VarDesc      ,
                    EngUnits     ,
                    MPUID        ,
					PUGId		 ,
					CAuditFreq   ,
					UDEESTID	 )
       SELECT pu.PU_Id      ,
                    ct.CType,
                    v.Var_Id,
                    v.Var_Desc,
                    v.Eng_Units,
                    pu.Master_Unit,
					v.PUG_Id,
					ct.Frequency,
					ct.ID
             FROM dbo.Event_Configuration		ec	WITH (NOLOCK)
             JOIN dbo.Prod_Units_Base			pu	WITH (NOLOCK) ON pu.Master_Unit = ec.PU_Id
             JOIN dbo.Variables_Base			v	WITH (NOLOCK) ON v.PU_Id = pu.PU_Id AND v.Event_Subtype_Id = ec.Event_Subtype_Id
             JOIN #CType                        ct	WITH (NOLOCK) ON ct.ID = v.Event_Subtype_Id
             WHERE ec.PU_Id IN (SELECT value FROM Split(@Equipment))

INSERT INTO #Data (        
                    PUId         ,
                    ESTDesc      ,
                    VarID        ,
                    VarDesc      ,
                    EngUnits     ,
                    MPUID        ,
					PUGId		 ,
					CAuditFreq   ,
					UDEESTID	 )
       SELECT pu.PU_Id      ,
                    ct.CType,
                    v.Var_Id,
                    v.Var_Desc,
                    v.Eng_Units,
                    pu.Master_Unit,
					v.PUG_Id,
					ct.Frequency,
					ct.ID
             FROM dbo.Event_Configuration		ec	WITH (NOLOCK)
             JOIN dbo.Prod_Units_Base			pu	WITH (NOLOCK) ON pu.Master_Unit = ec.PU_Id
             JOIN dbo.Variables_Base			v	WITH (NOLOCK) ON v.PU_Id = pu.PU_Id AND v.Event_Subtype_Id = ec.Event_Subtype_Id
             JOIN #CType                        ct	WITH (NOLOCK) ON ct.ID = v.Event_Subtype_Id
             WHERE v.PU_Id IN (SELECT value FROM Split(@Equipment))
			 

-----------------------------------------------
-- Insert Data for RTT lines.
-----------------------------------------------
INSERT INTO	#Data (
				PUId		,
				CAuditFreq		,
				VarId		,
				VarDesc		,
				EngUnits	,
				MPUID		,
				UDEESTID	,
				EqGroup
				)
		SELECT	p.PU_Id		,
				(CASE 
					WHEN v.Extended_Info LIKE '%PAS%' 
						THEN 'S'
					WHEN v.Extended_Info LIKE '%PAW%'
						THEN 'W'
					WHEN v.Extended_Info LIKE '%PAM%'
						THEN 'M'
					WHEN v.Extended_Info LIKE '%PAQ%'
						THEN 'Q'
					WHEN v.Extended_Info LIKE '%PAD%'
						THEN 'D'
					END)	,
				v.Var_Id	,
				v.Var_Desc	,
				v.Eng_Units	,
				v.PU_Id		,
				-1			,
				g.PUG_Desc
		FROM dbo.Prod_Units_Base p WITH(NOLOCK)
		JOIN dbo.Variables_Base v WITH(NOLOCK) ON p.PU_Id = v.PU_Id
		JOIN dbo.PU_Groups g WITH(NOLOCK) ON v.PUG_Id = g.PUG_Id
		WHERE v.PU_Id IN (SELECT Value FROM Split(@Equipment))
		  AND v.DS_Id = @DSId_Manual --Check the variables are Autolog
		  AND (	v.Extended_Info LIKE '%PAS%' OR 
				v.Extended_Info LIKE '%PAM%' OR
				v.Extended_Info LIKE '%PAW%' OR
				v.Extended_Info LIKE '%PAQ%' OR
				v.Extended_Info LIKE '%PAD%')

INSERT INTO	#Data (
				PUId		,
				CAuditFreq	,
				VarId		,
				VarDesc		,
				EngUnits	,
				MPUID		,
				UDEESTID	,
				EqGroup
				)
		SELECT	p.PU_Id		,
				(CASE
					WHEN g.PUG_Desc LIKE '%Recipe%' AND g.PUG_Desc NOT LIKE '%Dynamic%'
						THEN 'Recipe'
					ELSE 'S'
					END)	,
				v.Var_Id	,
				v.Var_Desc	,
				v.Eng_Units	,
				v.PU_Id		,
				-1			,
				g.PUG_Desc
		FROM dbo.Prod_Units_Base p WITH(NOLOCK)
		JOIN dbo.Variables_Base v WITH(NOLOCK) ON p.PU_Id = v.PU_ID
		JOIN dbo.PU_Groups g WITH(NOLOCK) ON v.PUG_Id = g.PUG_Id
		WHERE v.PU_Id IN (SELECT Value FROM Split(@Equipment))
		  AND v.DS_Id IN (@DSId_Auto,@DSId_Calc)
		  AND v.Extended_Info LIKE '%PAS%'


INSERT INTO #RTT_EI (
			VarId	,
			Ext_Info
			)
	SELECT	v.Var_Id,
			v.Extended_Info
	FROM	#Data d              WITH(NOLOCK)
	JOIN	Variables_Base v     WITH(NOLOCK) ON d.VarId = v.Var_Id
	WHERE	UDEESTID = -1

--**********************************************
-- Finish getting data.
--**********************************************
--update 'Recipe' for 3.0
UPDATE	d
	SET Recipe = tfv.Value
	FROM #Data d
	JOIN dbo.Table_Fields_Values tfv (NOLOCK) ON tfv.KeyId = d.PUGId
	JOIN dbo.Table_Fields tf (NOLOCK) ON tfv.Table_Field_Id = tf.Table_Field_Id AND tf.TableId = tfv.TableId
	JOIN dbo.Tables t (NOLOCK) ON tf.TableId = t.TableId AND t.TableName = 'PU_Groups'		 
	WHERE tf.Table_Field_Desc = 'RTT_Recipe'


--update 'Recipe' for 3.1
UPDATE	d
	SET Recipe = 1
	FROM #Data d
	JOIN dbo.Table_Fields_Values tfv (NOLOCK) ON tfv.KeyId = d.PUGId
	JOIN dbo.Table_Fields tf (NOLOCK) ON tfv.Table_Field_Id = tf.Table_Field_Id AND tf.TableId = tfv.TableId
	JOIN dbo.Tables t (NOLOCK) ON tf.TableId = t.TableId  
	WHERE t.TableId = (SELECT TableId FROM dbo.Tables WITH(NOLOCK) WHERE TableName = 'PU_Groups')
	  AND tf.Table_Field_Desc = 'RTT_GroupType'
	  AND Value = 'Recipe'

--**********************************************
-- RTT Recipe flag update
--**********************************************
UPDATE	d
	SET Recipe = 1
	FROM #Data d
	WHERE CAuditFreq like '%Recipe%'
	AND UDEESTID = -1
	
		
-- @CenterlineFilter = 'All', 'Recipe', 'Non-Recipe'
IF @CenterlineFilter <> 'All'
BEGIN
       IF @CenterlineFilter = 'Recipe'
       BEGIN  -- Delete the ones that are nor Recipe (RECIPE)
                    DELETE FROM #Data WHERE Recipe <> 1 AND UDEESTID <> -1 -- Remove NonRecipe variables for CL 3.0
								  
					DELETE FROM #Data WHERE UDEESTID = -1 AND CAuditFreq != 'Recipe' -- Remove NonRecipe variables for RTT
       END
       ELSE
       BEGIN         -- Delete the ones that are Recipe (NON-RECIPE)
                    DELETE FROM #Data WHERE Recipe = 1 AND UDEESTID <> -1 -- Remove Recipe variables for CL 3.0
								  
					DELETE FROM #Data WHERE UDEESTID = -1 AND CAuditFreq = 'Recipe' -- Remove Recipe variables for RTT
       END
END

--Update 'Centerline_TestTime'          
UPDATE d
       SET CTestTime = tfv.value
       FROM dbo.Table_Fields_Values      tfv (NOLOCK) 
       JOIN dbo.Table_Fields                   tf (NOLOCK) ON tf.Table_Field_Id = tfv.Table_Field_Id AND tf.TableId = tfv.TableId
       JOIN dbo.Tables                                t (NOLOCK) ON t.TableId = tf.TableId AND t.TableName = 'Variables'
       JOIN #Data                                     d ON d.VarID = tfv.KeyId
       WHERE tf.Table_Field_Desc = 'RTT_TestTime'

UPDATE d
		SET CAuditFreq = 'D'
		FROM #Data d
		WHERE CTestTime IS NOT NULL
		  AND CAuditFreq = 'S'

UPDATE d
       SET CTestTime = tfv.value
       FROM dbo.Table_Fields_Values      tfv (NOLOCK) 
       JOIN dbo.Table_Fields                   tf (NOLOCK) ON tf.Table_Field_Id = tfv.Table_Field_Id AND tf.TableId = tfv.TableId
       JOIN dbo.Tables                                t (NOLOCK) ON t.TableId = tf.TableId AND t.TableName = 'Event_Subtypes'
       JOIN #Data                                     d ON d.UDEESTID = tfv.KeyId
       WHERE tf.Table_Field_Desc = 'RTT_DefaultTestTime'
		 AND CTestTime IS NULL
		 AND CAuditFreq NOT IN ('A','S','D')

--update 'Centerline_TAuditFreq   
UPDATE d
       SET CAuditFreq = tfv.value
       FROM dbo.Table_Fields_Values tfv (NOLOCK) 
       JOIN dbo.Table_Fields tf (NOLOCK) ON tf.Table_Field_Id = tfv.Table_Field_Id AND tf.TableId = tfv.TableId
       JOIN dbo.Tables t (NOLOCK) ON t.TableId = tf.TableId AND t.TableName = 'Variables'
       JOIN #Data d ON d.VarID = tfv.KeyId
       WHERE tf.Table_Field_Desc = 'RTT_AuditFreq'  -- 'Centerline_AuditFreq'

-- Update Test Time on Temp Table.
UPDATE r
	SET	EI_Start = CHARINDEX('TT',Ext_Info) + 3,
		EI_Len = CHARINDEX(';',Ext_Info,CHARINDEX('TT',Ext_Info)) - (CHARINDEX('TT',Ext_Info) + 3)
	FROM #RTT_EI r

UPDATE r
	SET TestTime = (CASE	WHEN EI_Len < 1 THEN NULL
							ELSE SUBSTRING(Ext_Info,EI_Start,EI_Len)
							END)
	FROM #RTT_EI r

-- Update Test time for RTT variables.
UPDATE	d
	SET CTestTime = TestTime
	FROM #Data d
	JOIN #RTT_EI r ON d.VarID = r.VarId

--BRD 45 - RTT
UPDATE d
SET CAuditFreq = 'SA'
FROM #Data d
WHERE CAuditFreq LIKE '%S%' AND EqGroup like '%Auto%'

UPDATE d
SET CAuditFreq = 'SM'
FROM #Data d
WHERE CAuditFreq LIKE '%S%' AND EqGroup like '%Manual%'

--BRD 84
UPDATE d
SET CAuditFreq = (CASE 
	WHEN CAuditFreq = 'A' 
		THEN 'Shiftly Auto'
	WHEN CAuditFreq = 'S'
		THEN 'Shiftly Manual'
	WHEN CAuditFreq = 'W'
		THEN 'Weekly'
	WHEN CAuditFreq = 'M'
		THEN 'Monthly'
	WHEN CAuditFreq = 'Q'
		THEN 'Quarterly'
	WHEN CAuditFreq = 'D'
		THEN 'Daily'
	WHEN CAuditFreq = 'QCLM'
		THEN 'QCL Manual'
	WHEN CAuditFreq = 'QCLA'
		THEN 'QCL Auto'
	END)
FROM #Data d
---------------------------------------------------------------------------------------------------
-- @CenterlineTypes is going to be used to Filter Frequency
---------------------------------------------------------------------------------------------------
IF @CenterlineTypes <> 'All'
BEGIN
       DELETE FROM #Data 
	   WHERE CAuditFreq NOT IN (SELECT value FROM Split(@CenterlineTypes))
	   AND CAuditFreq NOT LIKE 'Recipe'
END

---------------------------------------------------------------------------------------------------
--update 'Centerline_QuarterStartTime'
UPDATE d
       SET CQStartTime = '0101'
	   FROM #Data d
	   WHERE CAuditFreq LIKE '%Quarterly%'

UPDATE d
		SET CReported = 1
		FROM #Data d

--update 'Centerline_Reported
UPDATE d
       SET CReported = tfv.value
       FROM dbo.Table_Fields_Values tfv (NOLOCK) 
       JOIN dbo.Table_Fields tf (NOLOCK) ON tf.Table_Field_Id = tfv.Table_Field_Id AND tf.TableId = tfv.TableId
       JOIN dbo.Tables t (NOLOCK) ON t.TableId = tf.TableId AND t.TableName = 'Variables'
       JOIN #Data d ON d.VarID = tfv.KeyId
       WHERE tf.Table_Field_Desc = 'RTT_Reported' -- 'Centerline_Reported'

--update Equipment Group
UPDATE d
       SET EqGroup = tfv.value
       FROM dbo.Table_Fields_Values tfv (NOLOCK) 
       JOIN dbo.Table_Fields tf (NOLOCK) ON tf.Table_Field_Id = tfv.Table_Field_Id AND tf.TableId = tfv.TableId
       JOIN dbo.Tables t (NOLOCK) ON t.TableId = tf.TableId AND t.TableName = 'Variables'
       JOIN #Data d ON d.VarID = tfv.KeyId
       WHERE tf.Table_Field_Desc = 'RTT_EquipmentGroup' -- 'Centerline_EquipmentGroup'

-- update Quarter Start Time
UPDATE d
	SET CQStartTime = '0101'
	FROM #Data d
	WHERE UDEESTID = -1
	  AND CAuditFreq LIKE '%Quarterly%'

-- update Reported
UPDATE d
	SET CReported = 1
	FROM #Data d
	JOIN dbo.Variables_Base v WITH(NOLOCK) ON d.VarId = v.Var_Id
	WHERE v.Extended_Info LIKE '%RPT=Y;%'

-- update ProdID
IF @ProdId IS NULL
BEGIN
       UPDATE d
             SET ProdID = p.prod_id
             FROM dbo.production_starts ps (NOLOCK)
             JOIN dbo.Products_Base      p (NOLOCK) ON p.prod_id = ps.prod_id
             JOIN #Data d ON d.MPUID = ps.pu_id
             WHERE ps.start_time <= @Start AND (ps.end_time > @Start OR ps.End_Time IS NULL)  
END
ELSE
BEGIN
       UPDATE d
             SET ProdId = @ProdId
    FROM #Data d
	JOIN @UnitProducts u ON d.MPUId = u.UnitId --aca sg

END        


--Update the Specs
UPDATE d
       SET    LReject             = vs.l_reject,
             LWarning      = vs.L_Warning,
             LUser         = vs.L_User,
             Target        = vs.Target,
             UUser         = vs.U_User,
             UWarning      = vs.U_Warning,
             UReject             = vs.U_reject
       FROM dbo.Var_Specs  vs     (NOLOCK) 
       JOIN #Data                 d      ON d.VarID = vs.var_id AND d.ProdID = vs.Prod_Id
       WHERE vs.Effective_Date <= @Start 
             AND (vs.Expiration_Date >= @start OR vs.Expiration_Date IS NULL)

--Update EntryWindowEnd for CAuditFreq = S
UPDATE d
       SET EntryWindowEnd = cs.Start_Time
       FROM dbo.Crew_Schedule     cs (NOLOCK)
       JOIN #Data                        d      ON d.MPUID = cs.pu_id
       WHERE cs.Start_Time = d.UDEEnd

DELETE FROM #Data WHERE ProdId IS NULL
----------------------------------------------------------------------------------------------------------------
ReturnData:

INSERT INTO  #MasterOutput (
                    PlantName           , 
                    Line                , 
                    PUId                ,
                    PugDesc                    , 
                    Frequency           ,
                    Lreject                    , 
                    Lwarning            , 
                    Luser               , 
                    Target              , 
                    UUser               , 
                    UWarning            , 
                    Ureject                    ,
                    SamplesTaken , 
                    SamplesDue          , 
                    FutureSamplesDue, 
                    Defects                    , 
                    ProdDesc            , 
                    VarDesc                    , 
                    VarId               , 
                    EngUnits            ,
                    ProdCode            , 
                    NextStartDate ,
                    MPUID				,
					Recipe)
       SELECT @PlantName          ,
                    PL_Desc                    ,
                    PUId                ,
                    EqGroup                    ,
                    CAuditFreq          ,
                    Lreject                    , 
                    LWarning            , 
                    LUser               , 
                    Target              , 
                    UUser               , 
                    UWarning            , 
                    Ureject                    ,
                    DataEntered                                                               'Samples Taken'                   ,
                    (CASE WHEN DATAEntered = 0 THEN 1 ELSE 0 END)    'SamplesDue'                           ,      
                    0                                                                                'Future Samples Due'       ,
                    EntryInSpec                                                               'Defects'                               ,      
                    p.Prod_Desc         ,
                    VarDesc                    ,
                    VarId               ,
                    EngUnits            ,
                    p.Prod_Code         ,
                    ''                                                                               'Next Start Time'                 ,
                    MPUID				,
					d.Recipe
             FROM #Data                 d      WITH(NOLOCK)
             JOIN dbo.Prod_Units_Base   pu     WITH(NOLOCK) ON pu.PU_Id = d.PUId
             JOIN dbo.Prod_Lines_Base   pl     WITH(NOLOCK) ON pl.PL_Id = pu.PL_Id
             LEFT JOIN dbo.Products_Base     p WITH(NOLOCK) ON p.Prod_Id = d.ProdId
			 WHERE CReported = 1

             UPDATE #MasterOutput
                           SET MasterUnit = pu.PU_Desc
             FROM  #MasterOutput av
             JOIN  dbo.Prod_Units_Base pu WITH(NOLOCK) ON av.MPUID = pu.PU_Id

             UPDATE #MasterOutput
                           SET ChildUnit = pu.PU_Desc
             FROM  #MasterOutput av
             JOIN  dbo.Variables_Base  v WITH(NOLOCK) ON av.VarId = v.Var_Id
             JOIN  dbo.Prod_Units_Base pu WITH(NOLOCK) ON v.PU_Id = pu.PU_Id

			 --update 'Recipe'
			 UPDATE m
					SET Recipe = tfv.Value
			 FROM dbo.Table_Fields_Values tfv (NOLOCK)
			 JOIN dbo.Table_Fields tf (NOLOCK) ON tfv.Table_Field_Id = tf.Table_Field_Id AND tf.TableId = tfv.TableId
			 JOIN dbo.Tables t (NOLOCK) ON tf.TableId = t.TableId AND t.TableName = 'Variables'
			 JOIN #MasterOutput m on m.VarId = tfv.KeyId
			 WHERE tf.Table_Field_Desc = 'RTT_Recipe'

-- SELECT '#MasterOutput',* FROM #MasterOutput
----------------------------------------------------------------------------------------------------------------
-- Report Output
----------------------------------------------------------------------------------------------------------------
SELECT PlantName           , 
             Line                , 
             VarId               , 
             VarDesc                    , 
             EngUnits            ,
             Frequency           ,
             PugDesc                    , 
             Lreject                    , 
             Lwarning            , 
             Luser               , 
             Target              , 
             UUser               , 
             UWarning            , 
             Ureject                    ,
             ProdCode            , 
             ProdDesc            ,
             MasterUnit          ,
             ChildUnit           ,
			 Recipe
       FROM #MasterOutput WITH(NOLOCK)

-- SELECT DISTINCT '#Data >>>',MPUID, ProdId FROM #Data
--select * from @UnitProducts
--SELECT * FRom #Data
CleanUp:
DROP TABLE #CType
DROP TABLE #Data
DROP TABLE #MasterOutput
DROP TABLE #RTT_EI


SET NOCOUNT OFF
GO

GRANT EXECUTE ON [dbo].[spLocal_RptCenterlineSpecs] TO [OPDBManager] As [dbo]
GRANT EXECUTE ON [dbo].[spLocal_RptCenterlineSpecs] TO [LocalUser] As [dbo]
GO