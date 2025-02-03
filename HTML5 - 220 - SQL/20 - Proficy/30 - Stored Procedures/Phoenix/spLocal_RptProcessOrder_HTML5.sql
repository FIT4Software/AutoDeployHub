USE [GBDB]
GO

SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO


-----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
-----------------------------------------------------------------------------------------------------------------------
DECLARE 
		@SPName			NVARCHAR(200),			-- the name of the sp begin creted
		@Inputs			INT,					-- the number of inputs
		@Version		NVARCHAR(20),			-- the version number that matches version manager
		@AppId			INT						-- the app_id of SOADB.dbo.appversions

SELECT
		@SPName		= 'dbo.spLocal_RptProcessOrder_HTML5',
		@Inputs		= 1,						-- Put the number of inputs to the Stored Procedure
		@Version	= 'PHX03.5'					-- Number should match version manager.

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
IF (SELECT COUNT(*) 
		FROM [dbo].[AppVersions] WITH (NOLOCK)
		WHERE app_name LIKE @SPName) > 0
	BEGIN
		UPDATE [dbo].[AppVersions]
			SET app_version = @Version, Modified_On = GETDATE()
			WHERE app_name LIKE @SPName
	END
ELSE
	BEGIN
		SELECT @AppId = MAX(App_Id) + 1 
			FROM [dbo].[AppVersions] WITH (NOLOCK)
		INSERT INTO [dbo].[AppVersions]
		(
			App_Id,
			App_name,
			App_version
		)
		VALUES 
		(
			@AppId, 
			@SPName,
			@Version
		)
	END

-----------------------------------------------------------------------------------------------------------------------
-- Drop Stored Procedure
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (
			SELECT * FROM dbo.sysobjects 
				WHERE Id = OBJECT_ID(N'[dbo].[spLocal_RptProcessOrder_HTML5]') 
				AND OBJECTPROPERTY(id, N'IsProcedure') = 1					
			)
DROP PROCEDURE [dbo].[spLocal_RptProcessOrder_HTML5]
GO

--------------------------------------------------------------------------------------------------
-- Stored Procedure: [dbo].[SP NAME]
--------------------------------------------------------------------------------------------------
-- Author				:  
-- Date created			:  
-- Version 				: 1.0
-- SP Type				:  
-- Caller				:  
-- Description			:  
-- Editor tab spacing	: 4
--------------------------------------------------------------------------------------------------
--  
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
/*
  
Stored Procedure: spLocal_RptProcessOrder  
Author   : Donna Lui  
Date Created : 02/1/06  
SP Type   : Report  
  
Description:   
This stored procedure is used to generate the Mucilloid Process Order Report.  
The Report has   
  
Called by:  RptProcessOrder.xlt (Excel/VBA Template)  
  
exec spLocal_RptProcessOrder 'ProcessOrder20070315055926'  
  
Modified History:  
April 22, 2008 DL Update script to show missing known waste, exclude PU_Id check  
April 30, 2008  DL Update script to show missing known waste, include only PU_Id   
   that is part of the path  
June 25, 2008 DT Update Waste queries to use table_field_id 86  
August 29, 2013 VR Replace DECIMAL(6,3) with FLOAT to avoid conversion issue  
     when calculating average of variable results  
March 27 2015 Fran Osorno correct all the issue with not complaint with sql 2008  
March 27 2015 Santosh added a entry in App_Versions table and also added standard sections in the SP  
March 30 2015 Santosh Script changed by Fran was not picking up the unit Id 3, so modified the condition. Removed the left join for Event_Reasons  

3.0   April 16 2018 Michel Mina Changed views to base table names for Proficy 6.2 upgrade 
						  divide by zero error fix when @TheoreticalYield=0
3.1	20-Apr-2018		Fernando Rio		Fixed the Waste Details not to show up duplicates.
3.2	09-Aug-2018     Fernando Rio        Truncate the decimal part if it is zero for Total Charged Kg.
3.3 10-Sep-2018		Fernando Rio		Make the Consumption not to be hardcoded but from a UDP = 'Take waste in account when rationing consumption'
3.4 18-Sep-2018		Fernando Rio		Chaged Actual Yied to be 2 Decimal places
3.5 5-Oct-2018		Fernando Rio		Changed all to be 3 Decimal Places to match the PO Report.
*/
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
  
CREATE PROCEDURE [dbo].[spLocal_RptProcessOrder_HTML5]  
--DECLARE
		 @PPId    int  
--WITH ENCRYPTION 
AS  
  
DECLARE @Prod_PUId    int  
DECLARE @Sched_PUId   int  
-- DECLARE @PPId    int  
DECLARE @PathId   int  
DECLARE @Start    datetime  
DECLARE @End    datetime  
DECLARE @ProdId   int  
DECLARE @PLId    int  
  
DECLARE @ActualYield  decimal(10,3)  
DECLARE @TheoreticalYield decimal(10,3)
DECLARE @lreject   decimal  
DECLARE @ureject   decimal  
DECLARE @PathCode   varchar(30)  
  
DECLARE @ExcludeWaste bit  

DECLARE @PathDesc		NVARCHAR(200)
  
DECLARE @MyTable TABLE ( [PO Number] varchar(50) UNIQUE,  
      [Batch Number]  varchar(50),  
      Path   nvarchar(50),  
      Product  varchar(100),  
      [Product Code] varchar(50),  
      Status  varchar(50),  
      Start  datetime,  
      [End]  datetime,  
      CommentId int,  
      Comment  varchar(4000),  
      Prod_Id  int,  
      Path_Id  int)  
       
DECLARE @PUIdContainer INT,  
 @PropId  INT  
DECLARE @Event TABLE ( EventId int primary key,  
      PUId int,  
      [Timestamp] datetime )  
  
DECLARE @tWasteEvent TABLE (  
 EventId  INT,  -- Primary Key,  
 PUId  INT,  
 TimeStamp DATETIME  
)  
  
DECLARE @Consumption TABLE (   
 ProdDesc varchar(255),   
 ProdCode varchar(50),   
 Qty DECIMAL(10,3)   , -- float,   
 PercentCharged DECIMAL(10,3)  -- float  
)  
  
----------------------------------------------------------------------------  
-- Report Parameters: PO Number  
----------------------------------------------------------------------------  
-- SELECT * FROM dbo.Production_Plan WHERE Process_Order LIKE '%906000014%'
--IF Len(@RptName) > 0   
--BEGIN  
-- --EXEC spCmn_GetReportParameterValue @RptName, 'intPath', NULL, @PathID OUTPUT   
-- EXEC spCmn_GetReportParameterValue @RptName, 'Orders', '', @PPID OUTPUT  
--END  
--ELSE  
--BEGIN  
-- SELECT @PPId = 22054 --1124 -- 950 -- 1083-- 950 --  928 -- 928 -- 751 --530 --290--Donna001  
--END  

----------------------------------------------------------------------------  
-- Process Order  
----------------------------------------------------------------------------  
INSERT INTO @MyTable ( [PO Number], [Batch Number], Path, Product, [Product Code], Status, Start,  
      [End], CommentId, Prod_Id, Path_Id )  
SELECT   pp.Process_Order,  
  setup.Pattern_code,  
  path.Path_Desc,  
  p.Prod_Desc,  
  p.Prod_Code,  
  pps.PP_Status_Desc,  
  pp.Actual_Start_Time,  
  Coalesce(max(ppt.Start_Time), GETDATE()),  
  pp.Comment_Id,  
  p.Prod_Id,  
  pp.Path_Id  
  
FROM dbo.Production_Plan pp (NOLOCK)  
JOIN dbo.Prdexec_Paths path (NOLOCK) ON pp.Path_Id=path.Path_Id  
JOIN dbo.Products_Base p (NOLOCK) ON pp.Prod_Id=p.Prod_Id  
JOIN dbo.Production_Plan_Statuses pps (NOLOCK) ON  pp.PP_Status_Id=pps.PP_Status_Id  
JOIN dbo.Production_Setup setup (NOLOCK)ON pp.pp_id=setup.pp_id  
JOIN dbo.Production_Plan_Transitions ppt (NOLOCK) ON ppt.pp_id = pp.pp_id AND ppt.PPStatus_id in (3, 4)  
  
WHERE pp.PP_Id=@PPId  
GROUP BY pp.Process_Order,  
  setup.Pattern_code,  
  path.Path_Desc,  
  p.Prod_Desc,  
  p.Prod_Code,  
  pps.PP_Status_Desc,  
  pp.Actual_Start_Time,  
  pp.Comment_Id,  
  p.Prod_Id,  
  pp.Path_Id  
  
UPDATE mt  
 SET mt.Comment = c.Comment_Text   
 FROM @MyTable mt  
 JOIN dbo.Comments c ON mt.CommentId = c.Comment_Id  
  
  
SELECT @Start  = Start,  
  @End  = [End],  
  @ProdID  = Prod_Id,  
  @PathID = Path_Id  
FROM  @MyTable  
  
SELECT @PUIdContainer = 37  
SET @ExcludeWaste = 1  

-- SELECT @PathID

DECLARE @OCSubscriptionId							 INT	,
		@FlgConsiderWasteWhenCalculatingMCARationing INT

SELECT	@OCSubscriptionId = s.subscription_id 
FROM	dbo.SUBSCRIPTION s WITH (NOLOCK)
WHERE	s.key_id  = @PathId 
	and s.SUBSCRIPTION_GROUP_ID = -6

EXECUTE [dbo].[spCmn_UDPLookup] 
		@FlgConsiderWasteWhenCalculatingMCARationing OUTPUT,
		27,
		@OCSubscriptionId,
		'Take waste in account when rationing consumption',
		'1'		

-- SELECT '@PathId >>>', @PathId ,'@OCSubscriptionId >>>',@OCSubscriptionId, '@FlgConsiderWasteWhenCalculatingMCARationing >>>',@FlgConsiderWasteWhenCalculatingMCARationing
SELECT @ExcludeWaste = (CASE WHEN @FlgConsiderWasteWhenCalculatingMCARationing = 1 THEN 0 ELSE 1 END)

--
SELECT TOP 1 @Prod_PUId = PU_Id   
FROM  PrdExec_Path_Units (NOLOCK)  
WHERE Is_Production_Point=1  
  AND Path_Id=@PathId    
ORDER BY Unit_Order ASC  
  
----------------------------------------------------------------------------  
-- Scheduled Unit PUId  
----------------------------------------------------------------------------  
SELECT  @Sched_PUId = PU_Id  
FROM  PrdExec_Path_Units (NOLOCK)  
WHERE Is_Schedule_Point=1  AND  
  Path_Id=@PathId  
  
--Report Title  
SELECT  PL_Desc + ' Process Order' RptTitle  
FROM  dbo.Prod_Lines (NOLOCK)  
WHERE PL_Id= (SELECT PL_Id FROM dbo.Prod_Units_Base  (NOLOCK) WHERE PU_Id=@Prod_PUId)  
  
SELECT [PO Number],  
  [Batch Number],  
  Path,   
  Product,  
  [Product Code],  
  Status,  
  Start,  
  [End],  
  Comment  
FROM  @MyTable  
  
--select @Sched_PUId as '@Sched_PUId'  
INSERT INTO @Event ( EventId, PUId, [Timestamp] )  
 SELECT DISTINCT e.Event_Id,  
   e.PU_Id,  
   e.[Timestamp]  
  FROM Event_Details ed (NOLOCK)  
  JOIN Events e (NOLOCK) ON e.Event_Id = ed.Event_Id  
  WHERE ed.PP_Id = @PPId  
   AND e.PU_Id = @Prod_PUId  
 UNION ALL  
 SELECT DISTINCT e.Event_Id,  
   e.PU_Id,  
   e.[Timestamp]  
  FROM Events e (NOLOCK)  
  JOIN Event_Details ed (NOLOCK) ON ed.Event_Id = e.Event_Id  
  LEFT OUTER JOIN Production_Plan_Starts pps (NOLOCK) ON pps.PU_Id = e.PU_Id  
   AND pps.Start_Time <= e.[Timestamp]  
   AND (pps.End_Time > e.[Timestamp] or pps.End_Time is null)  
  WHERE pps.PP_Id = @PPId   
   AND ed.PP_Id is null  
   AND e.PU_Id = @Prod_PUId  

----------------------------------------------------------------------------  
-- Get Paths Information
----------------------------------------------------------------------------   
 SELECT  @PathCode = Path_Code  ,
		@PathDesc = Path_Desc
 FROM  PrdExec_Paths (NOLOCK)  
 WHERE Path_Id = @PathId  
----------------------------------------------------------------------------  
-- Get Consumption  
----------------------------------------------------------------------------   
/*
IF @PathDesc LIKE 'FP Mixing%'
BEGIN
 INSERT INTO @Consumption ( ProdDesc, ProdCode, Qty ) 
 SELECT p.Prod_Desc, p.Prod_Code,SUM(Dimension_X)  
 FROM @Event e  
 JOIN Event_Components ec (NOLOCK) ON ec.event_id = e.EventId  
 JOIN dbo.Events e1                ON e1.Event_Id = ec.Source_Event_Id
 LEFT JOIN Production_Starts ps (NOLOCK) ON ps.PU_Id = e1.PU_Id
											AND ps.Start_Time <= e1.[Timestamp]
											AND (ps.End_Time > e1.[Timestamp] or ps.End_Time is null)
 LEFT JOIN Products_Base p (NOLOCK) ON  p.Prod_Id = ps.Prod_Id  
 GROUP BY p.Prod_Desc, p.Prod_Code  

 END
 ELSE
 BEGIN*/
 INSERT INTO @Consumption ( ProdDesc, ProdCode, Qty ) --, PercentCharged )  
 SELECT p.Prod_Desc,  
   p.Prod_Code,  
   sum(poc.Quantity)
 FROM fnlocal_poconsumption(@PPId,@ExcludeWaste) poc --(1224) poc --second parameter is "Exclude Waste"  
 LEFT JOIN Products_Base p (NOLOCK) ON  p.Prod_Id = poc.prodid  
 GROUP BY p.Prod_Desc, p.Prod_Code  
 --END
----------------------------------------------------------------------------  
-- Yield  
----------------------------------------------------------------------------   
  
-- Actual Yield  
  
SELECT @ActualYield = sum(Initial_Dimension_X)  
FROM @Event e   
JOIN Event_Details ed ON ed.Event_Id = e.EventId  
  
-- Theoretical Yield  
SELECT @TheoreticalYield = sum(Qty)  
 FROM @Consumption  
  
-- SELECT @TheoreticalYield = sum(Dimension_X)  
-- FROM @Event e  
-- JOIN Event_Components ec ON ec.Event_Id = e.EventId  
-- JOIN Events EV ON ec.source_event_id= ev.event_id  
-- and ev.pu_Id <> @PUIdContainer  
  
SELECT @lreject = asp.l_reject,  
  @ureject = asp.u_reject  
 FROM PU_Characteristics puc (NOLOCK)  
 JOIN Characteristics c (NOLOCK) ON c.Char_Id = puc.Char_Id  
  JOIN Specifications s (NOLOCK) ON s.Prop_Id = c.Prop_Id  
    AND s.Spec_Desc = 'Yield'  
   JOIN Active_Specs asp ON asp.Char_Id = c.Char_Id  
    AND s.spec_id = asp.spec_id  -- DGT 11/14/06  
    AND asp.Effective_Date < @Start  
    AND (asp.Expiration_Date >= @Start or asp.Expiration_Date is null)  
 WHERE puc.PU_Id = @Prod_PUId  
  AND puc.Prod_Id = @ProdId  

--------------------------------------------------------------------------------------  
-- Fernando Rio 8/9/2018 the statement below truncates the decimal part if it is zero.
--------------------------------------------------------------------------------------   

DECLARE @decpart INT
SELECT  @decpart = PARSENAME(@TheoreticalYield,1)
 
IF @decpart = 0 
		SELECT 'Yields Kg'     [Description],  
				@ActualYield    [Actual Kg],  
				CONVERT(decimal(10,0),@TheoreticalYield)    [Total Charged Kg],  
				CONVERT(DECIMAL(10,3),@ActualYield/@TheoreticalYield*100) [Produced/Charged]  
ELSE
		SELECT 'Yields Kg'     [Description],  
				@ActualYield    [Actual Kg],  
				@TheoreticalYield    [Total Charged Kg],  
				CONVERT(DECIMAL(10,3),@ActualYield/@TheoreticalYield*100) [Produced/Charged]  

  --@lreject     [Lower Limit],  
  --@ureject     [Upper Limit]  
  
----------------------------------------------------------------------------  
-- Return Consumption  
----------------------------------------------------------------------------   
SELECT ProdDesc as 'Product Description',   
  ProdCode as 'Product Code',   
  Qty as 'Qty (kg)',   
  CONVERT(DECIMAL(10,3),Qty/ NullIf(@TheoreticalYield,0) * 100.0) as '% of Total Charged'  --divide by zero error fix when @TheoreticalYield=0
 FROM @Consumption  
  
----------------------------------------------------------------------------  
-- Quality Analytical  
-- VR 2013-08-29 Replace decimal(6,3) to float to avoid conversion issue  
----------------------------------------------------------------------------   


SELECT 
  MAX(v.Var_Desc)   [Description],  
  AVG(CONVERT(decimal(10,3),CONVERT(FLOAT,t.Result)))  [Result],  
  --AVG(CAST(t.Result AS DECIMAL(10,3)))  [Result],  
  SUM(CASE   
           WHEN convert(float, t.Result) < convert(float, vs.L_Reject) THEN 1  
           WHEN convert(float, t.Result) > convert(float, vs.U_Reject) THEN 1  
           ELSE 0  
       END)    [Spec Exceptions],  
  CONVERT(float,MAX(vs.L_Reject))  [Lower Limit] ,  
  --MAX(vs.Target)   [Target],  
  CONVERT(float,MIN(vs.U_Reject))  [Upper Limit]  
 FROM  dbo.Variables_Base v (NOLOCK)  --changes do by AV
 JOIN dbo.Tests t (NOLOCK)							 ON V.Var_Id = T.var_id  
													 AND @Start  < t.Result_On  
													 AND t.Result_On <= @End  
													 AND  t.result IS NOT NULL  
													 AND t.result_on in (select max(t.result_on) from variables v (NOLOCK), tests t (NOLOCK)  where v.var_id = t.var_id and @Start < t.Result_On  
														  AND t.Result_On <= @End  AND t.result IS NOT NULL  
														  AND v.User_Defined2 LIKE '%' +  @PathCode + '%POQuality%')  
 LEFT JOIN dbo.Var_Specs VS (NOLOCK)				 ON VS.Prod_Id = @ProdID -- added by DT 3/20  
													 AND VS.Var_Id = V.Var_Id  
													 AND vs.effective_date <= @Start   
													 AND (vs.expiration_date > @Start or vs.expiration_date is NULL)   
 JOIN dbo.PrdExec_Path_Units pepu (NOLOCK)			 ON v.PU_Id = pepu.PU_Id   
													 AND pepu.Path_Id = @PathId   
 WHERE  v.User_Defined2 LIKE '%' +  @PathCode + '%POQuality%'  
		AND (vs.L_Reject IS NOT Null OR vs.U_Reject IS NOT Null OR vs.Target IS NOT Null)  
 GROUP BY v.var_id   
 ORDER BY [Upper Limit] DESC, [Lower Limit], MAX(v.Var_Desc)  
  
----------------------------------------------------------------------------  
-- Waste Detail  
----------------------------------------------------------------------------  
-- Get events associated with this PO belonging to any Pu part of the Path  
----------------------------------------------------------------------------  
INSERT @tWasteEvent (  EventId,   
					   PUId,   
					   Timestamp)  
 SELECT				   e.Event_Id,  
					   e.PU_Id,  
                       e.Timestamp  
  FROM dbo.Event_Details ed (NOLOCK) 
  JOIN  dbo.Events		 e	(NOLOCK)      ON     e.Event_Id  = ed.Event_Id  
												 AND ED.PP_Id = @PPId  
  JOIN dbo.PrdExec_Path_Units ppu (NOLOCK)  ON   ppu.Path_Id = @PathId  
												 AND ppu.PU_Id = E.PU_Id  
   
INSERT @tWasteEvent (EventId,   
   PUId,   
   Timestamp)  
 SELECT  e.Event_Id,  
  e.PU_Id,  
  e.[Timestamp]  
  FROM  dbo.Events e (NOLOCK)  
  JOIN dbo.Event_Details ed (NOLOCK)				ON  ed.Event_Id = e.Event_Id  
  JOIN dbo.PrdExec_Path_Units PPU (NOLOCK)			ON  PPU.Path_Id = @PathId  
														AND PPU.PU_Id = E.PU_Id  
  JOIN  dbo.Production_Plan_Starts pps (NOLOCK)		ON  pps.PP_Id = @PPId  
													AND pps.Start_Time <= e.[Timestamp]  
													AND (pps.End_Time > e.[Timestamp]   OR pps.End_Time is null)  
  WHERE  ed.PP_Id is null  
  

 SELECT  pu.PU_Desc [Location],  
				 w.Amount   [Qty (Kg)],   
				 e.Event_Reason_Name  [Waste Description],  
				 w.[TimeStamp]   [Timestamp],   
				 CAST(c.Comment_Text As varchar(4000)) [Comment]   
 FROM dbo.Waste_Event_Details w (NOLOCK)  
 JOIN @tWasteEvent t											 ON w.event_id = t.eventId  
																AND  (w.Amount > 0.01 OR w.Amount < -0.01)  
 JOIN Prod_Units_Base pu (NOLOCK)								ON t.PUId = pu.PU_Id    
 LEFT JOIN dbo.Event_Reasons e (NOLOCK)							ON w.Reason_Level2 = e.Event_Reason_Id  
 LEFT JOIN dbo.Comments C (NOLOCK)								ON C.Comment_Id = w.Cause_Comment_Id  
UNION ALL  
SELECT  DISTINCT pu.PU_Desc [Location],  
  w.Amount    [Qty (Kg)],   
  e.Event_Reason_Name  [Waste Description],  
  w.[TimeStamp]   [Timestamp],   
  CAST(c.Comment_Text As varchar(4000)) [Comment]  
FROM dbo.Waste_Event_Details w (NOLOCK)   
 JOIN dbo.Event_Reasons e (NOLOCK) ON e.Event_Reason_Id = w.Reason_Level2  
 LEFT JOIN dbo.Comments c (NOLOCK) ON c.Comment_Id = w.Cause_Comment_Id  
 JOIN dbo.Prod_Units_Base pu (NOLOCK) ON pu.PU_id = w.PU_Id 
  -- Dup Waste Events 
 JOIN dbo.PrdExec_Path_Units ppu (NOLOCK) ON	 ppu.PU_Id = pu.PU_Id
												 AND ppu.Path_id = @PathId 
WHERE @Start < w.[TimeStamp] AND w.[TimeStamp] <= @End  
 -- pps.Start_Time < w.[TimeStamp] AND w.[TimeStamp] <= pps.End_Time   
 AND (w.Amount >0.01 OR w.amount < = -0.01)  
 AND w.Event_id IS NULL
--ORDER BY e.Event_Reason_Name   
UNION ALL
-- Bring the Manual Rejects
SELECT  DISTINCT pu.PU_Desc [Location],  
  w.Amount    [Qty (Kg)],   
  e.Event_Reason_Name  [Waste Description],  
  w.[TimeStamp]   [Timestamp],   
  CAST(c.Comment_Text As varchar(4000)) [Comment]  
FROM dbo.Waste_Event_Details w (NOLOCK)   
 JOIN dbo.Prod_Units_Base pu (NOLOCK) ON pu.PU_id = w.PU_Id 
 JOIN dbo.Event_Reasons e (NOLOCK) ON e.Event_Reason_Id = w.Reason_Level2  
 LEFT JOIN dbo.Comments c (NOLOCK) ON c.Comment_Id = w.Cause_Comment_Id     
WHERE @Start < w.[TimeStamp] AND w.[TimeStamp] <= @End  
 -- pps.Start_Time < w.[TimeStamp] AND w.[TimeStamp] <= pps.End_Time   
 AND (w.Amount >0.01 OR w.amount < = -0.01)  
 -- AND w.Event_id IS NULL 
 AND w.PU_Id IN (SELECT Value FROM Table_Fields_Values WHERE KeyId = 1 and Table_Field_Id = 86)
 AND @PathDesc LIKE '%Mucilloid%'
--===============================================================================================================
-- Debug
----------------------------------------------------------------------------   
-- Alarm Detail  
----------------------------------------------------------------------------  
  
SELECT DISTINCT v.Var_Desc [Alarm Description],  
 a.Start_Result [Value],  
 a.Start_Time [Start],  
 a.End_Time [End],  
-- a.Cause1 [Cause],  
 CAST(c.Comment_Text As varchar(4000))[Comment]  
 FROM dbo.Alarms a (NOLOCK)  
 JOIN dbo.Variables v (NOLOCK)  
 ON v.Var_Id = a.Key_Id  
 AND v.User_Defined1 LIKE '%' + @PathCode + '%POAlarm%'  
-- AND v.PU_Id  = @Prod_PUId  
 JOIN dbo.PrdExec_Path_Units PPU (NOLOCK)  
 ON v.PU_Id = PPU.PU_Id  
 AND PPU.Path_Id = @PathId  
 LEFT  
 JOIN dbo.Comments c (NOLOCK)  
 ON a.cause_comment_Id = c.Comment_Id  
 WHERE (@Start < a.Start_Time OR (@Start > a.Start_Time AND a.End_Time > @Start))  
 AND (a.Start_Time < @End  
  OR @End Is NULL)   
 ORDER BY  v.Var_Desc -- a.Alarm_Desc  

--------------------------------------------------------------------------------------------------------------------------
-- Debug Section
-- SELECT @PathDesc
-- SELECT 'Consumption >>',* FROM @Consumption
--------------------------------------------------------------------------------------------------------------------------

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO



GRANT EXECUTE ON [dbo].spLocal_RptProcessOrder_HTML5 TO OPDBManager
GO
