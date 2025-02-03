
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--======================================================================================================================================
-- Check if the store procedure already exists in the Data Base
--======================================================================================================================================
IF	EXISTS(SELECT * FROM dbo.SYSOBJECTS WHERE Id = OBJECT_ID(N'[dbo].[spLocal_RptNptHistory]')
	AND OBJECTPROPERTY(Id, N'ISPROCEDURE') = 1)
BEGIN
	DROP PROCEDURE [dbo].[spLocal_RptNptHistory]
END
GO

----------------------------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptNptHistory',
		@Inputs		= 4,		-- Put the number of inputs here for support purposes
		@Version	= '1.3'		-- Number should match version manager, no exceptions.

SELECT @AppId = MAX(App_Id) + 1 
		FROM AppVersions
			
--======================================================================================================================================
--	Update table AppVersions
--======================================================================================================================================
IF (SELECT COUNT(*) 
		FROM AppVersions 
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE AppVersions 
		SET app_version = @Version , Modified_On = GETDATE()
		WHERE app_name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO AppVersions (
		App_Id,
		App_name,
		App_version)
	VALUES (
		@AppId, 
		@SP_Name,
		@Version)
		
END		

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO 

--======================================================================================================================================  
--======================================================================================================================================  
----------------------------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spLocal_RptNptHistory
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
----------------------------------------------------------------------------------------------------------------------------------------
-- Revision		Date			Who					What  
----------------------------------------------------------------------------------------------------------------------------------------
-- 1.0			2021-02-26		Ivan Corica		Initial Release
-- 1.1			2021-04-06		Ivan Corica		Add Comment column and the iteration for concatenate all comments for every row
-- 1.2			2021-12-08		Gonzalo Luc		Change dates datatypes from DATE to DATETIME
-- 1.3			2022-03-29		Gonzalo Luc		Add User name to the output and filter out all sistem made changes.
----------------------------------------------------------------------------------------------------------------------------------------  
-- Report parameters :  
----------------------------------------------------------------------------------------------------------------------------------------  
CREATE PROCEDURE [dbo].[spLocal_RptNptHistory]
--DECLARE
		@prodLineId				NVARCHAR(200)		= NULL
		,@strTimeOption			NVARCHAR(50)		= NULL
		,@startTime				DATETIME			= NULL
		,@endTime				DATETIME			= NULL

--WITH ENCRYPTION 
AS
SET NOCOUNT ON
---------------------------------------------------------------------------------------------------
-- Test Values
---------------------------------------------------------------------------------------------------
--SELECT
--		@prodLineId				= '59'--'112,137'
--		,@strTimeOption			= 'userdefined'
--		,@startTime				= '2020-10-01 00:00:00' --'2016-01-01 00:00:00' 
--		,@endTime				= '2021-01-04 00:00:00' --'2021-01-04 00:00:00' 
---------------------------------------------------------------------------------------------------
--Variables
---------------------------------------------------------------------------------------------------
DECLARE  @commentText				NVARCHAR(4000)
		,@commentId					INT		= -1
		,@i							INT		= 1
		,@countRows					INT		= 0
---------------------------------------------------------------------------------------------------
--Tables
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#NPTHResult', 'U') IS NOT NULL  DROP TABLE #NPTHResult
CREATE TABLE #NPTHResult  (
							NPTId					INT IDENTITY(1,1)
							,PU_Id					INT										
							,PL_Id					INT			
							,PU_Desc				NVARCHAR(200)	
							,PL_Desc				NVARCHAR(200)	
							,Npdet_Id				INT			
							,Start_Time				DATETIME		
							,End_Time				DATETIME 			
							,Modified_On			DATETIME 		
							,Event_Reason_Name		NVARCHAR(200)
							,DBTT_Desc				NVARCHAR(200)
							,Comment_Id				INT
							,Comment				NVARCHAR(4000)
							,UserName				NVARCHAR(200))

IF OBJECT_ID('tempdb.dbo.#CmntsTable', 'U') IS NOT NULL  DROP TABLE #CmntsTable
CREATE TABLE #CmntsTable  (
							 Id						INT IDENTITY(1,1)
							,NPTId					INT
							,Comment_Id				INT
							,Comment				NVARCHAR(4000))

IF OBJECT_ID('tempdb.dbo.#PLIDs', 'U') IS NOT NULL  DROP TABLE #PLIDs
CREATE TABLE #PLIDs  (PLId					INT)

---------------------------------------------------------------------------------------------------
-- Split and insert PLIds in table
---------------------------------------------------------------------------------------------------
INSERT INTO #PLIDs
SELECT String FROM fnLocal_Split(@prodLineId,',')
---------------------------------------------------------------------------------------------------
-- Get the Start and End Time for the Report
---------------------------------------------------------------------------------------------------
IF @strTimeOption <> 'UserDefined'
BEGIN
		SELECT  @startTime = dtmStartTime	,
				@endTime = dtmEndTime
		FROM	dbo.fnLocal_DDSStartEndTime (CASE @strTimeOption
													WHEN 'MTD' 		THEN 'MonthToDate'
													WHEN 'PreviousMonth' THEN 'LastMonth'
													WHEN 'Past3Month' THEN 'Last3Months'
													ELSE @strTimeOption END
											)
END

---------------------------------------------------------------------------------------------------
-- Insert to #NPTHResult for data
---------------------------------------------------------------------------------------------------
INSERT INTO #NPTHResult (PU_Id														
							,PL_Id						
							,PU_Desc				
							,PL_Desc				
							,Npdet_Id							
							,Start_Time						
							,End_Time				 			
							,Modified_On			 		
							,Event_Reason_Name		
							,DBTT_Desc			
							,Comment_Id
							,UserName)
SELECT pub.PU_Id, plid.PLId, pub.pu_desc, plb.PL_Desc, npth.npdet_id, npth.start_time, npth.end_time, npth.Modified_On, r.event_reason_name, d.DBTT_Desc, npth.Comment_Id, u.Username
FROM #PLIDs plid
JOIN Prod_Units_Base pub WITH(NOLOCK) ON pub.PL_Id = plid.PLId 
JOIN Prod_Lines_Base plb WITH(NOLOCK) ON plb.PL_Id = pub.PL_Id 
JOIN NonProductive_Detail_History npth WITH(NOLOCK) ON npth.PU_Id = pub.PU_Id 
JOIN event_reasons r WITH(NOLOCK) ON npth.reason_level1 = r.event_reason_id 
JOIN db_trans_types d WITH(NOLOCK) ON npth.dbtt_id = d.DBTT_Id
JOIN Users_Base u WITH(NOLOCK) ON npth.User_Id = u.User_Id
 
WHERE npth.Start_Time >= @startTime
AND npth.End_Time <= @endTime
AND npth.User_Id > 50
ORDER BY pub.PU_Desc, npth.Modified_On DESC

---------------------------------------------------------------------------------------------------
-- Insert to #CmntsTable for all rows with comments
---------------------------------------------------------------------------------------------------
INSERT INTO #CmntsTable(NPTId, Comment_id)
SELECT NPTId, Comment_id
FROM #NPTHResult
WHERE Comment_Id <> 0 AND Comment_Id IS NOT NULL

--Set count rows for loop
SET @countRows = (SELECT MAX(Id) FROM #CmntsTable)
WHILE(@i <= @countRows)
BEGIN

SET @commentId = (SELECT Comment_Id FROM #CmntsTable WHERE Id=@i)

WHILE(@commentId <> -1)
BEGIN
--Concatenate comment
SELECT @commentText = CONCAT(@commentText , ' ' , (SELECT Comment 
													FROM Comments WITH(NOLOCK) 
													WHERE Comment_Id = @commentId))

--If have NextComment_Id else exit loop
IF((SELECT NextComment_Id FROM Comments WITH(NOLOCK) WHERE Comment_Id = @commentId) IS NULL)
	BEGIN
		SELECT @commentId = -1 
	END
ELSE
	BEGIN
		SELECT @commentId = (SELECT NextComment_Id 
							 FROM Comments WITH(NOLOCK) 
							 WHERE Comment_Id = @commentId)
	END
END

--Update #CmntsTable comment column
UPDATE cmnt
SET cmnt.Comment = @commentText
FROM #CmntsTable cmnt
WHERE id = @i	


-- Reset values fot next loop and increment @i
SET @commentText = ''
SET @i = @i + 1

END

---------------------------------------------------------------------------------------------------
--Update #NPTHResult
---------------------------------------------------------------------------------------------------
UPDATE npth
SET npth.Comment = cmnt.Comment
FROM #NPTHResult npth
LEFT JOIN #CmntsTable cmnt ON cmnt.NPTId = npth.NPTId
---------------------------------------------------------------------------------------------------
--Output
---------------------------------------------------------------------------------------------------
SELECT PU_Id, PL_Id,PU_Desc,PL_Desc,Npdet_Id,Start_Time,End_Time,Modified_On,Event_Reason_Name,DBTT_Desc, Comment, UserName
FROM #NPTHResult npth


---------------------------------------------------------------------------------------------------
--Drops
---------------------------------------------------------------------------------------------------
DROP TABLE #NPTHResult
DROP TABLE #CmntsTable
DROP TABLE #PLIDs

----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSIONS / OVERHEAD
----------------------------------------------------------------------------------------------------------------------------------------

SET NOCOUNT OFF
GO
GRANT EXECUTE ON [dbo].[spLocal_RptNptHistory] TO [OPDBManager] As [dbo]
GO