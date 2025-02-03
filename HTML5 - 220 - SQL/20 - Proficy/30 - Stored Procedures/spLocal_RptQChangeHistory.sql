
----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptQChangeHistory',
		@Inputs		= 6, 
		@Version	= '1.2'  

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
				
DROP PROCEDURE [dbo].[spLocal_RptQChangeHistory]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

----================================================================================================================================
----================================================================================================================================
CREATE   PROCEDURE [dbo].[spLocal_RptQChangeHistory]
-----------------------------------------------------------------------------------------------------------------------
--    This procedure provides information related to user-modified variable 
--    values per a provided timeframe.  
-----------------------------------------------------------------------------------------------------------------------
-- 1.0	2018-07-16		Martin Casalis		Initial Release
-- 1.1	2019-08-02		Damian Campana		Get comments from column Colmment with the value in rtf
-- 1.2  20222-02-08     Daniela Giraudi	    Change int to bigint test_id field in #Tests table.
-----------------------------------------------------------------------------------------------------------------------
--DECLARE
	@in_LineID			NVARCHAR(MAX)	=	NULL	,
	@in_StartTime		DATETIME		=	NULL	,
	@in_EndTime			DATETIME		=	NULL	,
	@DefaultQGroups		NVARCHAR(MAX)	=	NULL	,
	@ProcessOrder		NVARCHAR(100)	=	NULL	,
	@Product			NVARCHAR(100)	=	NULL	

 --SELECT  
	--@in_LineID = null,
	--@in_StartTime = '2018-11-06 06:00:00', 
	--@in_EndTime = '2018-11-07 17:38:00',
	--@DefaultQGroups = 'All',
	--@ProcessOrder = '000900000529', --null,--
	--@Product = ''
	
--WITH ENCRYPTION 
AS

-----------------------------------------------------------------------------------------------------------------------
PRINT	'	- Create temporary tables '
-----------------------------------------------------------------------------------------------------------------------

IF OBJECT_ID('tempdb.dbo.#Tests', 'U') IS NOT NULL  DROP TABLE #Tests; 
CREATE TABLE #Tests(
					ID						INT IDENTITY	,
					TestId					BIGINT			,
					VarId					INT				,
					EntryOn					DATETIME2(0)	,
					ResultOn				DATETIME		,
					Username				NVARCHAR(30)	,
					Result					NVARCHAR(50)	,
					VarDesc					NVARCHAR(250)	,
					LineDesc				NVARCHAR(50)	,
					CommentId				INT				,
					NextCommentId			INT				,
					CommentDesc				NVARCHAR(MAX)	,
					ProdCode				NVARCHAR(50)	,
					ProcessOrder			NVARCHAR(250)	,
					IsCalc					INT				,
					DeletionFlag			INT	DEFAULT 0	)

IF OBJECT_ID('tempdb.dbo.#Variables', 'U') IS NOT NULL  DROP TABLE #Variables; 
CREATE TABLE #Variables(
					RCDID					INT				,
					VarID					INT				,
					VarDesc					NVARCHAR(250)	,
					VarType					NVARCHAR(50)	,
					PUId					INT				)

IF OBJECT_ID('tempdb.dbo.#PL_IDs', 'U') IS NOT NULL  DROP TABLE #PL_IDs; 
CREATE TABLE #PL_IDs(
					RCDID					INT				,
					PL_ID					INT				,
					PL_Desc					NVARCHAR(100)	,
					PU_Id					INT				,
					POStartTime				DATETIME		,
					POEndTime				DATETIME		,
					IsProductionPoint		INT				)

IF OBJECT_ID('tempdb.dbo.#PUGDescList', 'U') IS NOT NULL  DROP TABLE #PUGDescList; 
CREATE TABLE #PUGDescList (
					RCDID					INT,
					PUG_Desc				NVARCHAR(4000),
					PUG_Id					INT,
					PL_Id					INT
)

IF OBJECT_ID('tempdb.dbo.#LookUp_Tests', 'U') IS NOT NULL  DROP TABLE #LookUp_Tests; 
CREATE TABLE #LookUp_Tests(
					Test_Id					BIGINT			,
					Var_Id					INT				,
					Result_On				DATETIME		,
					Entry_On				DATETIME		,
					CommentId				INT				,
					Entry_By				INT				,
					Result					NVARCHAR(25)	)

-----------------------------------------------------------------------------------------------------------------------
-- Variables to hold parameters
-----------------------------------------------------------------------------------------------------------------------

DECLARE
			@in_VarId      					NVARCHAR(4000)	,
			@TimeOption						INT				,
			@intId							INT				,
			@i								INT				,
			@j								INT				,
			@NextCommentId					INT				


-----------------------------------------------------------------------------------------------------------------------
--	SP Variables
-----------------------------------------------------------------------------------------------------------------------

DECLARE
			@Var_Id 						INT				,
			@Test_Id						BIGINT			,
 			@Change							INT				,
			@intTableId						INT				,
			@intTableFieldId 				INT				,
			@Entry_On						DATETIME		,
			@Result_On						DATETIME		,
			@PrevResult_On					DATETIME		,
			@UserName						NVARCHAR(50)	,
			@Result							NVARCHAR(50)	,
			@vchUDPDescDefaultQProdGrps		NVARCHAR(25)	,
			@PL_Desc						NVARCHAR(50) 
			
-----------------------------------------------------------------------------------------------------------------------
--	UDP field names
-----------------------------------------------------------------------------------------------------------------------
SELECT	
		@vchUDPDescDefaultQProdGrps	=	'DefaultQProdGrps'

--------------------------------------------------------------------------------------------------------------
-- Parse the Report Parameters
--------------------------------------------------------------------------------------------------------------
IF @in_LineID IS NOT NULL AND @in_LineID <> ''
BEGIN
	INSERT INTO #PL_IDs (	RCDID	,
							PL_ID	)
	EXEC SPCMN_ReportCollectionParsing
		@PRMCollectionString = @in_LineID, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',' ,
		@PRMDataType01 = 'INT'
END

IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> ''
BEGIN	
	INSERT INTO #PL_IDs ( 
					PL_Id					,
					PU_Id					,
					IsProductionPoint		,
					POStartTime				,
					POEndTime				)	
	SELECT			
					pu.PL_Id				,
					pu.PU_Id				,
					ppu.Is_Production_Point	,
					pps.Start_Time			,
					ISNULL(pps.End_Time,GETDATE())
	FROM dbo.Prod_Units_Base		pu	WITH(NOLOCK) 			
	JOIN dbo.Production_Plan_Starts pps (NOLOCK)	ON pu.PU_Id = pps.PU_Id
	JOIN dbo.Production_Plan		pp	(NOLOCK)	ON pps.PP_Id = pp.PP_Id	
	JOIN dbo.PrdExec_Path_Units		ppu	(NOLOCK)	ON pps.PU_Id = ppu.PU_Id
	WHERE Process_Order = @ProcessOrder
		
	SELECT	@in_StartTime = POStartTime,
			@in_EndTime = POEndTime
	FROM #PL_IDs
	WHERE IsProductionPoint = 1
END


IF @DefaultQGroups <> 'All'
BEGIN
	INSERT INTO #PUGDescList (	RCDID		,
								PUG_Desc	)
	EXEC SPCMN_ReportCollectionParsing
		@PRMCollectionString = @DefaultQGroups, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',' ,
		@PRMDataType01 = 'NVARCHAR(255)'
END

-------------------------------------------------------------------------------------------------------------------
--	GET table Id for PU_Groups
-------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableId = TableId
FROM	dbo.Tables	WITH (NOLOCK)	
WHERE	TableName = 'PU_Groups'
-------------------------------------------------------------------------------------------------------------------	
--	GET table field Id for DefaultQProdGrps
-------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps

---------------------------------------------------------------------------------------------------------------
-- Business Rule for the Report :
-- a. If @DefaultQGroups = 'All' get all Variables from the @vchUDPDescDefaultQProdGrps PU Groups configured in the UDP
-- b. If @DefaultQGroups <> 'All' get all Variables from the PU Groups configured in the input parameter
---------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT * FROM #PUGDescList)
BEGIN 
			INSERT INTO #PUGDescList (
						PL_Id			,
						PUG_Desc		,
						PUG_Id			)
			SELECT 		pl.PL_Id		,
						pug.PUG_Desc	,
						pug.PUG_Id
            FROM dbo.Prod_Units_Base		pu 		WITH(NOLOCK)			
			JOIN #PL_Ids					pl	  	ON pl.PL_Id = pu.PL_Id
            JOIN dbo.PU_Groups				pug  	WITH(NOLOCK) 
													ON pug.PU_Id = pu.PU_Id
			JOIN dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
													ON	tfv.KeyId = pug.PUG_Id
            WHERE 	tfv.TableId = @intTableId
				AND	tfv.Table_Field_Id = @intTableFieldId
				AND	tfv.Value = 'Yes'
END
ELSE
BEGIN
			UPDATE pugl
				SET PUG_Id = pug.PUG_Id	,
					PL_Id = pl.PL_Id
			FROM #PUGDescList			pugl
            JOIN dbo.PU_Groups			pug  	WITH(NOLOCK)	ON pug.PUG_Desc = pugl.PUG_Desc
            JOIN dbo.Prod_Units_Base	pu 		WITH(NOLOCK)	ON pu.PU_Id = pug.PU_Id
			JOIN #PL_Ids				pl	  					ON pl.PL_Id = pu.PL_Id
END

--SELECT '#PUGDescList',* FROM #PUGDescList
---------------------------------------------------------------------------------------------------------------
-- Get Variables
--------------------------------------------------------------------------------------------------------------- 
INSERT INTO #Variables (
			VarId			,
			VarDesc			,
			PUId			,
			VarType			)
SELECT 	DISTINCT 
			v.Var_Id		,
			v.Var_Desc		,
			v.PU_Id			,
			--	Flag for Non-Numeric variables
			CASE	WHEN	v.Data_Type_Id =	1	THEN	'VARIABLE'
					WHEN	v.Data_Type_Id	=	2	THEN	'VARIABLE'
					WHEN	v.Data_Type_Id	=	6	THEN	'VARIABLE'
					WHEN	v.Data_Type_Id	=	7	THEN	'VARIABLE'
				ELSE	'ATTRIBUTE'
			END	
FROM dbo.Variables_Base		v  		WITH(NOLOCK)
JOIN #PUGDescList			pug		ON v.PUG_Id = pug.PUG_Id


--SELECT '#Variables',* FROM #Variables
---------------------------------------------------------------------------------------------------------------
--    Get lookup Tests
---------------------------------------------------------------------------------------------------------------
-- Tests based on start and end time of the report
INSERT INTO #LookUp_Tests (		Test_Id			,
								Var_Id			,
								Result_On		,
								Entry_On		,
								CommentId		,
								Entry_By		,
								Result			)
SELECT 							Test_Id			,
								Var_Id			,
								Result_On		,
								Entry_On		,
								Comment_Id		,
								Entry_By		,
								Result
FROM 							dbo.Tests t		WITH(NOLOCK)
JOIN 							#Variables v 	ON 		v.VarId 	= 	t.Var_Id
WHERE 
								t.Result_On >= @In_StartTime 
								AND t.Result_On < @In_EndTime

-- Tests based on start and end time of the Process Order
INSERT INTO #LookUp_Tests (		Test_Id			,
								Var_Id			,
								Result_On		,
								Entry_On		,
								CommentId		,
								Entry_By		,
								Result			)
SELECT 							Test_Id			,
								Var_Id			,
								Result_On		,
								Entry_On		,
								Comment_Id		,
								Entry_By		,
								Result
FROM 							dbo.Tests	t	WITH(NOLOCK)
JOIN 							#Variables	v 	ON 		v.VarId 	= 	t.Var_Id
JOIN							#PL_IDs		pl	ON		pl.PU_Id	=	v.PUId
WHERE 
								t.Result_On >= POStartTime
								AND t.Result_On < POEndTime
								AND t.Test_Id NOT IN (SELECT Test_Id FROM #LookUp_Tests)

---------------------------------------------------------------------------------------------------------------
--    Get Variable Historical Tests
---------------------------------------------------------------------------------------------------------------
INSERT INTO 	#Tests 	(		
								TestId			,
								VarId			,
								EntryOn			, 
								ResultOn		,
								Username		, 
								Result			, 
								VarDesc			, 
								LineDesc		,
								CommentId		)
SELECT 							
								t.Test_Id		,
								t.Var_Id		,
								th.Entry_On		, 
								t.Result_On		, 
								u.UserName		, 
								th.Result		, 
								--tv.VarDesc		,
								CASE WHEN VarType = 'VARIABLE'
									THEN '1|' + tv.VarDesc
									ELSE '0|' + tv.VarDesc
								END				,
								pl.PL_Desc		,
								t.CommentId 
FROM 							dbo.Test_History		th		WITH(NOLOCK)
JOIN 							#LookUp_Tests			t 		ON 		th.Test_Id	= t.Test_Id
JOIN 							#Variables				tv 		ON 		tv.VarID   	= t.Var_ID
JOIN 							dbo.Prod_Units_Base		pu		WITH(NOLOCK) 
																ON 		tv.PUID 	= pu.PU_ID
JOIN 							dbo.Prod_Lines_Base		pl 		WITH(NOLOCK)
																ON 		pl.PL_ID 	= pu.PL_ID
JOIN 							dbo.Users_Base			u		WITH(NOLOCK)
																ON 		th.Entry_By = u.User_ID
WHERE 
								t.Result_On = th.Result_On
								AND UPPER(u.username) <> 'STUBBER'
								AND th.Entry_On <> t.Entry_On							
	
---------------------------------------------------------------------------------------------------------------
--    For All the Tests that have changed insert the 'master' record
---------------------------------------------------------------------------------------------------------------
INSERT INTO 	#Tests 	(		
								TestId		,
								VarId		,
								EntryOn		, 
								ResultOn	,
								Username	, 
								Result		, 
								VarDesc		, 
								LineDesc	,
								CommentId	)
SELECT 							
								t.Test_Id	,
								VarId		,
								t.Entry_On	, 
								t.Result_On	,
								u.Username	, 
								t.Result	, 
								VarDesc		, 
								LineDesc	,
								th.CommentId	
FROM 							#LookUp_Tests	t
JOIN							#Tests			th	ON t.Var_Id = th.VarId
													AND t.Result_On = th.ResultOn
JOIN 							dbo.Users_Base	u	WITH(NOLOCK)
													ON t.Entry_By = u.User_ID
GROUP BY						
								t.Test_Id	,
								VarId		,
								t.Entry_On	, 
								t.Result_On	,
								u.Username	, 
								t.Result	, 
								VarDesc		, 
								LineDesc	,
								th.CommentId

UPDATE #Tests
	SET IsCalc = 1
WHERE TestId IN (
					SELECT DISTINCT TestId
					FROM #Tests
					WHERE Username LIKE 'CalculationMgr'	)

---------------------------------------------------------------------------------------------------------------
--    UPDATE Product
---------------------------------------------------------------------------------------------------------------
UPDATE t
	SET ProdCode = (SELECT Prod_Code 
					FROM dbo.Products			p	(NOLOCK)
					JOIN dbo.Production_Starts	ps	(NOLOCK) ON p.Prod_Id = ps.Prod_Id
					WHERE ResultOn >= ps.Start_Time
					AND (ResultOn < ps.End_Time OR ps.End_Time IS NULL)
					AND v.PUId = ps.PU_Id)
FROM #Tests		t
JOIN #Variables v	ON t.VarId = v.VarId

IF @Product IS NOT NULL AND @Product <> ''
BEGIN
		DELETE FROM #Tests
		WHERE ProdCode <> @Product
END

---------------------------------------------------------------------------------------------------------------
--    UPDATE Process Order
---------------------------------------------------------------------------------------------------------------
UPDATE t
	SET ProcessOrder = (SELECT Process_Order 
						FROM dbo.Production_Plan		pp	(NOLOCK)
						JOIN dbo.Production_Plan_Starts	pps	(NOLOCK) ON pp.PP_Id = pps.PP_Id
						WHERE ResultOn >= pps.Start_Time
						AND (ResultOn < pps.End_Time OR pps.End_Time IS NULL)
						AND v.PUId = pps.PU_Id)
FROM #Tests		t
JOIN #Variables v	ON t.VarId = v.VarId

IF @ProcessOrder IS NOT NULL AND @ProcessOrder <> ''
BEGIN
		DELETE FROM #Tests
		WHERE ProcessOrder <> @ProcessOrder
END

---------------------------------------------------------------------------------------------------------------
--    UPDATE From Comments table
---------------------------------------------------------------------------------------------------------------
UPDATE t
		SET    CommentDesc = CASE	WHEN	LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
									THEN	LEFT(CONVERT(NVARCHAR(MAX),c.Comment),3997) + '...'
									WHEN	LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 <= 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
									THEN	(CONVERT(NVARCHAR(MAX),c.Comment))
									ELSE	''
									END    ,
				NextCommentId      = NextComment_Id
FROM   dbo.Comments	c WITH(NOLOCK)
JOIN   #Tests t ON t.CommentId  = c.Comment_Id 

-- Iterate to get all comment levels
---------------------------------------------------------------------------------------------------
SELECT	@intId = MAX(Id),
		@i = 1           ,
		@j = 1
FROM #Tests
WHILE @i <= @intId
BEGIN
       IF EXISTS (   SELECT * FROM #Tests
                           WHERE ID = @i
                           AND NextCommentId IS NOT NULL   )
       BEGIN
			SET @NextCommentId = NULL

             SELECT @NextCommentId	= NextCommentId
             FROM #Tests
             WHERE ID = @i
			 			 
			 SET @j = 1
			 			 			 
             WHILE @NextCommentId IS NOT NULL AND @j < 10
             BEGIN
                    -- Subtract the comments length by 2 to deal with PPA comments issue
					UPDATE #Tests
						SET    CommentDesc = CASE  WHEN   NextCommentId > 0 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
																THEN   CommentDesc + ' | ' + LEFT(CONVERT(NVARCHAR(MAX),c.Comment),3997) + '...'
																WHEN   NextCommentId > 0 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 <= 4000 AND LEN(CONVERT(NVARCHAR(MAX),c.Comment)) - 2 > 0
																THEN   CommentDesc + ' | ' + (CONVERT(NVARCHAR(MAX),c.Comment))
										END  
					FROM   dbo.Comments c WITH(NOLOCK)
					WHERE  c.Comment_Id = @NextCommentId
					AND ID = @i
					
					SELECT @NextCommentId = NextComment_Id
					FROM dbo.Comments WITH(NOLOCK)
					WHERE Comment_Id = @NextCommentId

					SET @j = @j + 1
             END
       END
       SET @i = @i + 1
END

---------------------------------------------------------------------------------------------------------------
-- Do not show Calculation Manager variables when they are not modified by an end user
UPDATE t
	SET DeletionFlag = 1
FROM #Tests	t
WHERE IsCalc = 1
AND	TestId IN (
					SELECT TestId
					FROM #Tests		t
					WHERE IsCalc = 1
					GROUP BY TestId
					HAVING COUNT(DISTINCT Username) < 2	)
					
DELETE FROM #Tests WHERE DeletionFlag = 1
---------------------------------------------------------------------------------------------------------------

--SELECT '#Tests',* FROM #Tests
--ORDER BY 	 VarDesc		,
--			 ResultOn		,
--			 EntryOn
---------------------------------------------------------------------------------------------------------------
-- FINAL Result Set
---------------------------------------------------------------------------------------------------------------
SELECT DISTINCT
			 EntryOn										,
			 ResultOn										,
			 Username										,
			 ISNULL(Result,'')			AS 'Result'			,
			 VarDesc										,
			 LineDesc										,
			 ProcessOrder									,
			 ProdCode										,
			 ISNULL(CommentDesc	,'')	AS 'CommentDesc'	
FROM		 #Tests 
--WHERE        Username <> 'CalculationMgr'
ORDER BY 	 VarDesc		,
			 ResultOn		,
			 EntryOn

---------------------------------------------------------------------------------------------------------------
-- ResultSet: Start and End Time
SELECT @In_StartTime	'StartDate'	,
	   @in_EndTime		'EndDate'
---------------------------------------------------------------------------------------------------------------


---------------------------------------------------------------------------------------------------------------
--Test Section
---------------------------------------------------------------------------------------------------------------
--SELECT '#Variables',* FROM #Variables
--SELECT '#PL_IDs',* FROM #PL_IDs
--SELECT '#PUGDescList',* FROM #PUGDescList
---------------------------------------------------------------------------------------------------------------
-- DROP TABLES
---------------------------------------------------------------------------------------------------------------

DROP TABLE #Tests
DROP TABLE #Variables
DROP TABLE #PL_IDs
DROP TABLE #PUGDescList
DROP TABLE #LookUp_Tests

---------------------------------------------------------------------------------------------------------------
GO
GRANT EXECUTE ON [dbo].[spLocal_RptQChangeHistory] TO [OPDBManager] As [dbo]
GRANT EXECUTE ON [dbo].[spLocal_RptQChangeHistory] TO [RptUser] As [dbo]
GO
