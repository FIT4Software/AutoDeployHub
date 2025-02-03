
----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptQSpecifications',
		@Inputs		= 3, 
		@Version	= '1.0'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
SELECT @AppId = MAX(App_Id) + 1 
		FROM dbo.AppVersions

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


----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
			FROM	Information_schema.Routines
			WHERE	Specific_schema = 'dbo'
				AND	Specific_Name = @SP_Name
				AND	Routine_Type = 'PROCEDURE' )
				
DROP PROCEDURE [dbo].[spLocal_RptQSpecifications]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-------------------------------------------------------------------------------------------------------------------------------------------------------
-- Report Name 			: Specifications
-- Store Procedure Name : spLocal_RptQSpecifications
-- Pablo Galanzini - Arido Software - 2017-03-30 
--	Store procedure is used to get the Specifications.
-- 
-------------------------------------------------------------------------------------------------------------------------------------------------------
--	1.0		2018-06-06	Martin Casalis		Initial Release
--=================================================================================================
CREATE PROCEDURE [dbo].[spLocal_RptQSpecifications]
--DECLARE
       @Equipment			VARCHAR(1000),		--what equipment
       @PugDesc				VARCHAR(1000),      --all or certain
       @Start				DATETIME     ,       --if @TimeWindows is UserDefined
	   @ProcessOrder		NVARCHAR(100),
	   @Product				NVARCHAR(100)

--WITH ENCRYPTION
AS

-- Test
-- EXEC dbo.spLocal_RptQSpecifications '1','All','2017-04-10 15:58:21.367'

--SELECT
--    @Equipment          =	'183,612',
--    @PugDesc			=	'All',
--	@PugDesc			=	'All',
--    @Start              =	'2018-11-08',
--	@ProcessOrder		=	'',
--	@Product			=	''


---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#QProdGrps', 'U') IS NOT NULL  DROP TABLE #QProdGrps
CREATE TABLE #QProdGrps (
			PUG_ID			INT				,
			PUG_Desc		VARCHAR(50)		,
			PU_ID			INT				)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Equipment', 'U') IS NOT NULL  DROP TABLE #Equipment
CREATE TABLE #Equipment (
			RcdIdx			INT IDENTITY	,						
			Equipment		VARCHAR(255)	,			
			PLId			INT				,
			PUId			INT				)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Data', 'U') IS NOT NULL  DROP TABLE #Data
CREATE TABLE #Data (
			ID					INT IDENTITY	,
			PUId				INT				,
			UDEID				INT				,
			UDEStart			DATETIME		,
			UDEEnd				DATETIME		,
			FrecuencyStart		DATETIME		,
			FrecuencyEnd		DATETIME		,
			UDEPUID				INT				,
			UDEESTID			INT				,
			VarID				INT				,
			VarDesc				VARCHAR(50)		,
			EngUnits			VARCHAR(15)		,
			SamplingInterval	INT				,
			SamplingOffset		INT				,
			UDEDesc				VARCHAR(100)	,
			MPUID				INT				,
			CTestTime			VARCHAR(50)		,		-- UDP Centerline_TestTime
			CAuditFreq			VARCHAR(50)		,		-- UDP Centerline_AuditFreq
			CQStartTime			VARCHAR(50)		,		-- UDP Centerline_QuarterStartTime
			CReported			VARCHAR(50)		,		-- UDP Centerline_Reported	
			EqGroup				VARCHAR(50)		,
			DataEntered			INT DEFAULT(0)	,		-- 1 data has been entered 0 not
			EntryOnTime			INT DEFAULT (0)	,	-- 1 data was entered within the event time 0 not
			EntryInSpec			INT DEFAULT(0)	,		-- 1 data within spec if entered 0 not
			EntryWindowEnd		DATETIME		,
			ProdID				INT				,
			ProcessOrder		NVARCHAR(200)	, 
			LReject				VARCHAR(25)		,
			LWarning			NVARCHAR(25)	, 
			LUser				NVARCHAR(25)	, 
			Target				VARCHAR(25)		,
			UUser				NVARCHAR(25)	, 
			UWarning			NVARCHAR(25)	, 
			UReject				VARCHAR(25)		,
			TestFreq			VARCHAR(25)		)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MasterOutput', 'U') IS NOT NULL  DROP TABLE #MasterOutput 
CREATE TABLE #MasterOutput (
			Id					INT IDENTITY	,
			PlantName			NVARCHAR(200)	, 
			Line				NVARCHAR(200)	, 
			PUDesc				NVARCHAR(200)	, 
			PUId				INT				,	
			PugDesc				NVARCHAR(200)	, 
			Frequency			NVARCHAR(200)	,
			Lreject				NVARCHAR(25)	, 
			Lwarning			NVARCHAR(25)	, 
			Luser				NVARCHAR(25)	, 
			Target				NVARCHAR(25)	, 
			UUser				NVARCHAR(25)	, 
			UWarning			NVARCHAR(25)	, 
			Ureject				NVARCHAR(25)	,
			ProdDesc			NVARCHAR(200)	, 
			ProcessOrder		NVARCHAR(200)	, 
			VarId				INT				, 
			VarDesc				NVARCHAR(200)	, 
			EngUnits			VARCHAR(15)		,
			ProdCode			NVARCHAR(200)	,
			TestFreq			VARCHAR(25)		,
			SamplingInterval	INT				,
			SamplingOffset		INT				)

---------------------------------------------------------------------------------------------------
--Declare local variables
---------------------------------------------------------------------------------------------------
DECLARE
			--@End							DATETIME,
			@PlantName						NVARCHAR(200),
			@vchUDPDescDefaultQProdGrps		VARCHAR(25),
			@intTableId						INT,
			@intTableFieldId				INT
	
---------------------------------------------------------------------------------------------------
--Set the local variables
---------------------------------------------------------------------------------------------------
SET		@PlantName	= (SELECT Value FROM dbo.Site_Parameters WITH(NOLOCK) WHERE Parm_ID = 12)
--SELECT	@End		= DATEADD(d, 1, @Start)
SELECT	@vchUDPDescDefaultQProdGrps	= 'DefaultQProdGrps'

---------------------------------------------------------------------------------------------------	
-- Get selected Equipment information
---------------------------------------------------------------------------------------------------	
-- Get Prod Units
IF @Equipment > ''AND (@ProcessOrder IS NULL OR @ProcessOrder = '')
BEGIN
		INSERT INTO #Equipment ( 
					Equipment				,
					PUId					,
					PLId					)	
		EXEC ('SELECT		pu.PU_Desc				,
							pu.PU_Id				,
							pu.PL_Id				
					FROM dbo.Prod_Units_Base					pu	WITH(NOLOCK) 
					WHERE pu.PL_Id IN (' + @Equipment + ')')
END
ELSE IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> ''
BEGIN	
	INSERT INTO #Equipment ( 
					Equipment				,
					PUId					,
					PLId					)	
	SELECT		pu.PU_Desc				,
				pu.PU_Id				,
				pu.PL_Id				
	FROM dbo.Prod_Units_Base		pu	(NOLOCK) 			
	JOIN dbo.Production_Plan_Starts pps (NOLOCK)	ON pu.PU_Id = pps.PU_Id
	JOIN dbo.Production_Plan		pp	(NOLOCK)	ON pps.PP_Id = pp.PP_Id
	WHERE Process_Order = @ProcessOrder
END
---------------------------------------------------------------------------------------------------
--	Get variables
---------------------------------------------------------------------------------------------------
IF (@PugDesc = 'All')
BEGIN

	-----------------------------------------------------------------------------------------------------------
	--	GET table Id for PU_Groups
	-----------------------------------------------------------------------------------------------------------
	SELECT	@intTableId = TableId
		FROM	dbo.Tables	WITH (NOLOCK)	
		WHERE	TableName = 'PU_Groups'
	------------------------------------------------------------------------------------------------------------	
	--	GET table field Id for DefaultQProdGrps
	------------------------------------------------------------------------------------------------------------
	SELECT	@intTableFieldId = Table_Field_Id
		FROM	dbo.Table_Fields	WITH (NOLOCK)
		WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps

	INSERT INTO #QProdGrps
		SELECT 	pg.PUG_Id, 
				pg.PUG_Desc, 
				pg.PU_Id
		FROM	dbo.Prod_Units_Base			pu	WITH(NOLOCK)	
		JOIN	dbo.PU_Groups				pg	WITH(NOLOCK)ON pu.PU_Id = pg.PU_Id
		JOIN	dbo.Table_Fields_Values		tfv	WITH(NOLOCK)ON tfv.KeyId = pg.PUG_Id
		JOIN	#Equipment					e	WITH(NOLOCK)ON pu.PU_Id = e.PUId
		WHERE	tfv.TableId = @intTableId
			AND	tfv.Table_Field_Id = @intTableFieldId
			AND	tfv.Value = 'Yes'

	--select '#QProdGrps', * from #QProdGrps

	---------------------------------------------------------------------------------------------------
	-- Get Data
	---------------------------------------------------------------------------------------------------
	INSERT INTO #Data (		
				PUId				,
				VarID				,
				VarDesc				,
				EngUnits			,
				MPUID				,
				EqGroup				,
				SamplingInterval	,
				SamplingOffset		)
		SELECT	pu.PU_Id			,
				v.Var_Id			,
				v.Var_Desc			,
				v.Eng_Units			,
				pu.Master_Unit		,
				pg.PUG_Desc			,
				Sampling_Interval	,
				Sampling_Offset
			FROM dbo.Prod_Units_Base		pu	WITH(NOLOCK) 
			JOIN dbo.Variables_Base			v	WITH(NOLOCK) ON v.PU_Id = pu.PU_Id 
			JOIN #QProdGrps					pg	ON pg.PUG_Id = V.PUG_Id
			LEFT JOIN dbo.Specifications	s	WITH(NOLOCK) ON s.Spec_Id = v.Spec_Id
			WHERE s.Spec_Desc NOT LIKE '%Test Complete%'  
			AND Is_Active = 1 
END
ELSE
BEGIN

	INSERT INTO #QProdGrps
		SELECT 	pg.PUG_Id, pg.PUG_Desc, pg.PU_Id
		FROM	dbo.Prod_Units_Base		pu	WITH(NOLOCK)	
		JOIN	dbo.PU_Groups			pg	WITH(NOLOCK) ON pu.PU_Id = pg.PU_Id
		JOIN	#Equipment				e	WITH(NOLOCK) ON pu.PU_Id = e.PUId
		WHERE	pg.PUG_Desc = @PugDesc

	--select '#QProdGrps', * from #QProdGrps

	---------------------------------------------------------------------------------------------------
	-- Get Data
	---------------------------------------------------------------------------------------------------
	INSERT INTO #Data (		
				PUId				,
				VarID				,
				VarDesc				,
				EngUnits			,
				MPUID				,
				EqGroup				,
				SamplingInterval	,
				SamplingOffset		)
		SELECT	pu.PU_Id			,
				v.Var_Id			,
				v.Var_Desc			,
				v.Eng_Units			,
				pu.Master_Unit		,
				pg.PUG_Desc			,
				Sampling_Interval	,
				Sampling_Offset
			FROM dbo.Prod_Units_Base		pu	(NOLOCK) 
			JOIN dbo.Variables_Base			v	(NOLOCK) ON v.PU_Id = pu.PU_Id 
			JOIN #QProdGrps					pg	ON pg.PUG_Id = V.PUG_Id
			LEFT JOIN dbo.Specifications	s	WITH(NOLOCK) ON s.Spec_Id = v.Spec_Id
			WHERE s.Spec_Desc NOT LIKE '%Test Complete%'   
			AND Is_Active = 1 

END

IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> ''
BEGIN	
	UPDATE d
		SET ProdID		 = pp.Prod_Id	,
			ProcessOrder = @ProcessOrder
	FROM dbo.Production_Plan		pp	(NOLOCK)
	JOIN dbo.Production_Plan_Starts pps (NOLOCK)	ON pp.PP_Id = pps.PP_Id
	JOIN #Data						d	ON COALESCE(d.MPUID,PUId) = pps.PU_Id
	WHERE Process_Order = @ProcessOrder
	
	SELECT @Start = MIN(Start_Time)
	FROM dbo.Production_Plan		pp	(NOLOCK)
	JOIN dbo.Production_Plan_Starts pps (NOLOCK)	ON pp.PP_Id = pps.PP_Id
	WHERE Process_Order = @ProcessOrder

END
ELSE IF @Product IS NOT NULL AND @Product <> ''
BEGIN
	--update ProdID
	UPDATE #Data
		SET ProdID = Prod_Id
	FROM dbo.Products_Base	(NOLOCK) 
	WHERE Prod_Code = @Product
END
ELSE
BEGIN
	--update ProdID
	UPDATE d
		SET ProdID = p.prod_id
		FROM dbo.Production_Starts	ps (NOLOCK)
		JOIN dbo.Products_Base		p (NOLOCK) ON p.prod_id = ps.prod_id
		JOIN #Data					d ON COALESCE(d.MPUID,PUId) = ps.pu_id
	WHERE ps.start_time <= @Start AND (ps.end_time >= @Start OR ps.End_Time IS NULL)	
END

-- Remove variables that are not assigned to a Product
DELETE FROM #Data
WHERE VarId IN(
				SELECT VarId
				FROM		#Data			d
				LEFT JOIN	dbo.Var_Specs	vs (NOLOCK) ON	d.VarId = vs.Var_Id
												AND d.ProdId = vs.Prod_Id
				WHERE vs.VS_Id IS NULL )

--select '#Data',* from #Data

--update Process Order
UPDATE d
	SET ProcessOrder = pp.Process_Order
	FROM dbo.Production_Plan		 	pp (NOLOCK)
	JOIN dbo.Production_Plan_Starts 	ps (NOLOCK) ON pp.PP_Id = ps.PP_Id
	JOIN #Data							d ON COALESCE(d.MPUID,PUId) = ps.pu_id
WHERE ps.start_time <= @Start 
AND (ps.end_time > @Start OR ps.End_Time IS NULL)	
AND pp.Prod_Id = d.ProdId


--Update the Specs
UPDATE d
	SET	LReject			= vs.l_reject,
		LWarning		= vs.L_Warning,
		LUser			= vs.L_User,
		Target			= vs.Target,
		UUser			= vs.U_User,
		UWarning		= vs.U_Warning,
		UReject			= vs.U_reject,
		TestFreq		= vs.Test_Freq
	FROM dbo.Var_Specs	vs	(NOLOCK) 
	JOIN #Data			d	ON d.VarID = vs.var_id AND d.ProdID = vs.Prod_Id
	WHERE vs.Effective_Date <= @Start 
		AND (vs.Expiration_Date >= @start OR vs.Expiration_Date IS NULL)

 
-- Delete Variables with test_freq is null or <1 and not have Specs    
DELETE FROM #Data      
WHERE     
 (LReject IS NULL AND LWarning IS NULL AND LUser IS NULL     
 AND UUser IS NULL AND UWarning IS NULL AND Ureject IS NULL)    
 AND (  TestFreq IS NULL    
   OR ( TestFreq IS NOT NULL     
     AND ISNUMERIC(TestFreq) = 1    
     AND TestFreq < 1))     
----------------------------------------------------------------------------------------------------------------
ReturnData:

INSERT INTO	#MasterOutput (
			PlantName			, 
			Line				, 
			PUId				,
			PUDesc				,
			PugDesc				, 
			Frequency			,
			Lreject				, 
			Lwarning			, 
			Luser				, 
			Target				, 
			UUser				, 
			UWarning			, 
			Ureject				,
			ProdDesc			, 
			VarDesc				, 
			VarId				, 
			EngUnits			,
			SamplingInterval	,
			SamplingOffset		,
			TestFreq			,
			ProdCode			, 
			ProcessOrder		)
	SELECT	@PlantName			,
			PL_Desc				,
			PUId				,
			pu.PU_Desc			,
			EqGroup				,
			CAuditFreq			,
			Lreject				, 
			LWarning			, 
			LUser				, 
			Target				, 
			UUser				, 
			UWarning			, 
			Ureject				,	
			p.Prod_Desc			,
			VarDesc				,
			VarId				,
			EngUnits			,
			SamplingInterval	,
			SamplingOffset		,
			TestFreq			,
			p.Prod_Code			,
			ISNULL(ProcessOrder,'No PO')
		FROM #Data			d
		JOIN dbo.Prod_Units_Base		pu	WITH(NOLOCK) ON pu.PU_Id = d.PUId
		JOIN dbo.Prod_Lines_Base		pl	WITH(NOLOCK) ON pl.PL_Id = pu.PL_Id
		LEFT JOIN dbo.Products_Base		p	WITH(NOLOCK) ON p.Prod_Id = d.ProdId
		WHERE ((TestFreq IS NOT NULL    
		AND ISNUMERIC(TestFreq) = 1    
		AND TestFreq > 0)    
		OR LReject IS NOT NULL     
		OR LWarning IS NOT NULL    
		OR LUser IS NOT NULL    
		OR UUser IS NOT NULL    
		OR UWarning IS NOT NULL    
		OR Ureject IS NOT NULL)    

----------------------------------------------------------------------------------------------------------------
-- Report Output
----------------------------------------------------------------------------------------------------------------
SELECT	PlantName			, 
		Line				, 
		PUDesc				,
		VarId				, 
		VarDesc				, 
		EngUnits			,
		Frequency			,
		PugDesc				, 
		Lreject				, 
		Lwarning			, 
		Luser				, 
		Target				, 
		UUser				, 
		UWarning			, 
		Ureject				,
		TestFreq			,
		SamplingInterval	,
		SamplingOffset		,
		ProdCode			, 
		ProdDesc			,
		ProcessOrder		
	FROM #MasterOutput 


DROP TABLE #QProdGrps
DROP TABLE #Equipment 
DROP TABLE #Data
DROP TABLE #MasterOutput

GO
GRANT EXECUTE ON [dbo].[spLocal_RptQSpecifications] TO [OPDBManager] As [dbo]
GRANT EXECUTE ON [dbo].[spLocal_RptQSpecifications] TO [RptUser] As [dbo]
GO
