USE [GBDB]

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
		@SP_Name	= 'spLocal_ReportsRTT_OpenAlarms_HTML5',
		@Inputs		= 3,
		@Version	= '1'

----=====================================================================================================================
----	Update table AppVersions
----=====================================================================================================================

--IF (SELECT COUNT(*) 
--		FROM dbo.AppVersions 
--		WHERE App_Name like @SP_Name) > 0
--BEGIN
--	UPDATE dbo.AppVersions 
--		SET app_version = @Version,
--			Modified_On = GETDATE() 
--		WHERE App_Name like @SP_Name
--END
--ELSE
--BEGIN
--	INSERT INTO dbo.AppVersions (
--		App_Name,
--		App_version,
--		Modified_On )
--	VALUES (	
--		@SP_Name,
--		@Version,
--		GETDATE())
--END
--===================================================================================================================== 
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
			FROM	Information_schema.Routines
			WHERE	Specific_schema = 'dbo'
				AND	Specific_Name = @SP_Name
				AND	Routine_Type = 'PROCEDURE' )
				
DROP PROCEDURE [dbo].[spLocal_ReportsRTT_OpenAlarms_HTML5]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
--====================================================================================================================
----------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spLocal_ReportsRTT_OpenAlarms_HTML5
----------------------------------------------------------------------------------------------------------------------
-- Author				: Corica Ivan - Arido Software
-- Date created			: 2020-08-05
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for RTT Open Alarms HTML5
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
----------------------------------------------------------------------------------------------------------------------
-- 1.0		2020-08-05		Corica Ivan			Revamped from dbo.spLocal_ReportsRTT_OpenAlarms version 1.2 - 2019-05-16 Megha Lohana (TCS)
-- 1.1		2020-09-04		Corica Ivan			Added Product group, product & alarm duration to SP output
----------------------------------------------------------------------------------------------------------------------
--====================================================================================================================

CREATE PROCEDURE dbo.spLocal_ReportsRTT_OpenAlarms_HTML5

----------------------------------------------------------------------------------------------------------------------
-- Report Parameters
----------------------------------------------------------------------------------------------------------------------
--DECLARE

		@PLIDs		NVARCHAR(MAX)
		,@StartDate	DATE
		,@EndDate	DATE

--WITH ENCRYPTION
AS
SET NOCOUNT ON
----------------------------------------------------------------------------------------------------------------------
-- Report Test
----------------------------------------------------------------------------------------------------------------------
	--SELECT @PLIDs = '56, 59, 61'
	--,@StartDate = '2018-08-04T06:00:00'--'2020-05-22 00:00:00'
	--,@EndDate = '2020-09-03T06:00:00'--'2020-06-30 00:00:00'
--------------------------------------------------------------------------------------------------------------------------
--TABLES
--------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Temp_MaxAlarms', 'U') IS NOT NULL  DROP TABLE #Temp_MaxAlarms
Create Table #Temp_MaxAlarms
			(	Key_Id				int,
				action_comment_id	int,
				action1				int,
				cause1				int,
				max_start_time		datetime)

IF OBJECT_ID('tempdb.dbo.#IDs', 'U') IS NOT NULL  DROP TABLE #IDs
CREATE TABLE #IDs
			(RCDID   		int,
			 PL_Desc 		nVarchar(20),
			 PL_id  		int,
			 PU_ID  		NVARCHAR(MAX),
			 Conv_ID 		int )

IF OBJECT_ID('tempdb.dbo.#OpenAlarms', 'U') IS NOT NULL  DROP TABLE #OpenAlarms
Create Table #OpenAlarms
			(pu_id			int,
			 var_id			int,
			 Var_Desc VarChar(150)Null,
			 start_time		datetime,
			 end_time		datetime,
			 start_result	Varchar(25),  -- FO-03896
			 source_pu_id	int,
			 action_comment	nvarchar(500),
			 action			nvarchar(500),
			 cause			nvarchar(500),
			 PL_Desc 		varchar(50),
			 Area 			VarChar(4)Null,			 
 	  		 LSL 			VarChar(20)Null,
			 Target 		VarChar(20)Null,
			 USL 			VarChar(20)Null,
			 Last_Result_On DateTime Null,
			 Priority 		nvarchar(10),
			 alarm_duration	int)

--------------------------------------------------------------------------------------------------------------------------
--FILL TABLE
--------------------------------------------------------------------------------------------------------------------------
--PU_ID, PL_ID, PL_Desc
INSERT INTO #IDs(PU_ID, PL_ID, PL_Desc)
SELECT pu.PU_Id, pu.PL_ID, pl.PL_Desc
FROM dbo.Prod_Units_Base pu WITH(NOLOCK)
JOIN dbo.Prod_Lines pl WITH(NOLOCK) ON pl.PL_ID = pu.PL_ID
WHERE pu.PL_ID IN (SELECT String FROM fnLocal_Split(@PLIDs,','))
AND pl.PL_Desc NOT LIKE 'Z_OB%'

--------------------------------------------------------------------------------------------------------------------------
--CONV_ID
		Update #IDs
		Set Conv_ID = (Select distinct PU_ID from Prod_Units_Base
			       where PU_Desc = #IDs.PL_Desc + ' Converter')
--------------------------------------------------------------------------------------------------------------------------
	Insert Into #Temp_MaxAlarms
			(	Key_Id				,
				action_comment_id	,
				action1				,
				cause1				,
				max_start_time)
	Select 	alms.Key_Id,
			NULL as action_comment_id,
			NULL as action1,
			NULL as cause1,
			Max(alms.Start_Time) as max_start_time
	From dbo.Alarms alms WITH(NOLOCK)
	Where (Action_Comment_Id is not null) Or (Action1 is not null) Or (Cause1 is not null)
	Group by alms.key_id
--------------------------------------------------------------------------------------------------------------------------
	Update #Temp_MaxAlarms
	   set action_comment_id = a.action_comment_id,
	        action1 = a.action1,
	        cause1 = a.cause1
	From #temp_maxalarms tma
	Join alarms a on a.key_id = tma.key_id and a.start_time = tma.max_start_time
--------------------------------------------------------------------------------------------------------------------------	
--INSERT TO #OpenAlarms
--------------------------------------------------------------------------------------------------------------------------
	 Insert Into #OpenAlarms
			(pu_id			,
			 var_id			,
			 var_desc		,
			 start_time		,
			 end_time		,
			 start_result	,
			 source_pu_id	,
			 action_comment	,
			 action			,
			 cause			,
			 pl_desc		)
	 Select ids.PU_ID,
			alms.key_id,
			v.var_desc,
			alms.start_time,
			End_Time,
			Start_Result,
			Source_PU_Id,
		    Convert(Varchar(300),Comment_Text) as 'Action_Comment',
			Convert(Varchar(100),ER1.Event_Reason_Name) as 'Action',
			Convert(Varchar(100),ER2.Event_Reason_Name) as 'Cause',
			ids.pl_desc
	 From dbo.Alarms alms WITH(NOLOCK)
	 Join #IDs ids On ids.pu_id = alms.source_pu_id --PU ID para join con alarms
	 LEFT Join #Temp_MaxAlarms tma on alms.key_id = tma.key_id and alms.start_time = tma.max_start_time
	 Join dbo.Variables_Base v On v.var_id = alms.key_id
	 LEFT JOIN dbo.Comments cs WITH(NOLOCK) on cs.Comment_ID = tma.Action_Comment_ID 
	 LEFT JOIN dbo.Event_Reasons ER1 WITH(NOLOCK) on tma.Action1 = ER1.Event_Reason_ID 
	 LEFT JOIN dbo.Event_Reasons ER2 WITH(NOLOCK) on tma.Cause1 = ER2.Event_Reason_ID
	 Where End_Time Is NULL 
			and var_id Not In (SELECT var_id
			    From (SELECT     var_id,start_time,a.action1,a.cause1
			    From  dbo.Variables_Base v WITH(NOLOCK) 
			    Join dbo.Alarms a WITH(NOLOCK) ON v.Var_Id = a.Key_Id 
			    Join Prod_Units_Base pu on v.pu_id = pu.pu_id
			    Where (a.End_Time IS NULL) and (pu.pu_desc like '%RTT%')) as a
			    Left JOIN dbo.Event_Reasons er WITH(NOLOCK) ON a.Action1 = er.Event_Reason_Id 
			    Left JOIN dbo.Event_Reasons er1 WITH(NOLOCK) ON a.Cause1 = er1.Event_Reason_Id
			    Where (er.Event_Reason_Name LIKE '%Tym%' or er.Event_Reason_Name LIKE '%Temp%'))
--------------------------------------------------------------------------------------------------------------------------
--UPDATE AREA TO #OpenAlarms
--------------------------------------------------------------------------------------------------------------------------
	Update #OpenAlarms    			    
	    			Set Area = 'EA' + LEFT(A.Var_Desc, 1),			 	
		                LSL = VS.L_Reject, 
						Target = VS.Target, 
						USL = VS.U_Reject, 
	                	Priority = ap.ap_Desc
	FROM 	#OpenAlarms A 
	        JOIN Alarm_Template_Var_Data atvd on a.var_id = atvd.var_id
	        JOIN Alarm_Templates at on atvd.at_id = at.at_id
	        JOIN Alarm_Priorities ap on ap.ap_id = at.ap_id
			JOIN Production_Starts PS WITH (NOLOCK) ON a.Source_PU_Id = PS.PU_Id 
			JOIN Var_Specs VS WITH (NOLOCK) ON a.Var_Id = VS.Var_Id 
				AND PS.Prod_Id = VS.Prod_Id 
				AND A.var_Id = VS.Var_Id 		
	WHERE 	(A.Start_Time >= PS.Start_Time AND (A.Start_Time < PS.End_Time or PS.End_Time is null)) 
			AND (VS.Expiration_Date IS NULL)
--------------------------------------------------------------------------------------------------------------------------
--UPDATE LAST RESULT
--------------------------------------------------------------------------------------------------------------------------
--IF HAVE DATE FILTER
IF((@StartDate IS NOT NULL AND @StartDate <> '') AND (@EndDate IS NOT NULL AND @EndDate <> ''))
BEGIN
	Update #OpenAlarms    				
			SET Last_Result_On = (Select MAX(Result_On) 
								  FROM Tests Where Var_Id = A.Var_Id
								  AND A.start_time >= @StartDate
								  AND A.start_time <= @EndDate)		
	From #OpenAlarms A 
END
ELSE
BEGIN
	Update #OpenAlarms    				
			SET Last_Result_On = (Select MAX(Result_On) 
								  FROM Tests Where Var_Id = A.Var_Id)		
	From #OpenAlarms A 
END
--------------------------------------------------------------------------------------------------------------------------
--UPDATE ALARM DURATION
UPDATE #OpenAlarms
		SET alarm_duration = DATEDIFF(MINUTE, Start_Time, GETDATE())
--------------------------------------------------------------------------------------------------------------------------
--OUTPUT
--------------------------------------------------------------------------------------------------------------------------
	SELECT     	PL_Desc,
				Area,
				Var_Desc, 
				oa.Start_Time, 
				Start_Result, 
				Cause, 
				Action, 
	            LSL, 
				Target, 
				USL,
				Last_Result_On, 
				Action_Comment as Comment_Text, 
				T.Result,
				Priority,
				pg.Product_GRP_Desc,
				pb.Prod_Desc,
				alarm_duration
				
	FROM         #OpenAlarms oa
	JOIN Tests t ON oa.Var_Id = t.Var_Id AND oa.Last_Result_On = t.Result_On 
	JOIN dbo.Production_Starts ps ON ps.PU_Id = oa.pu_id AND ps.Start_Time <= oa.Last_Result_On AND ps.End_Time >= oa.Last_Result_On
	JOIN dbo.Products_Base pb ON pb.Prod_Id = ps.Prod_Id
	JOIN dbo.Product_Group_Data pgd ON pgd.Prod_Id = ps.Prod_Id
	JOIN dbo.Product_Groups pg ON pg.Product_GRP_ID = pgd.Product_GRP_ID
	ORDER BY PL_Desc,Area, oa.Start_Time desc ,Var_Desc,Priority
--------------------------------------------------------------------------------------------------------------------------
--DROPS
--------------------------------------------------------------------------------------------------------------------------
Drop Table #OpenAlarms
Drop Table #Temp_MaxAlarms
Drop Table #IDs


GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[spLocal_ReportsRTT_OpenAlarms_HTML5]  TO OpDBManager
GO