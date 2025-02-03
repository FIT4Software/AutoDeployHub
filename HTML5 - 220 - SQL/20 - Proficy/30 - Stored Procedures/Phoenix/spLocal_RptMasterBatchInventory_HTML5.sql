USE [GBDB]
GO
--Step A the developer needs to update the sp name for checking if it exists and then to drop the sp 
-----------------------------------------------------------------------------------------------------------------------
--Drop Stored Procedure
----------------------------------------------------------------------------------------------------------------------- 
IF  EXISTS (SELECT * FROM dbo.sysobjects 
				WHERE Id = OBJECT_ID(N'[dbo].[spLocal_RptMasterBatchInventory_HTML5]') 
				AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
DROP PROCEDURE [dbo].[spLocal_RptMasterBatchInventory_HTML5]
GO

/*-----------------------------------------------------------------------------  
Stored Procedure	:	spLocal_RptMasterBatchInventory_HTML5
Author				:   Fernando Rio
Date Created		:   2018-08-07  
SP Type				:   Report  
  
Description			:   
This stored procedure is used to generate the Master Batch Inventory Report.  
  
Called by			:	HTML5 Report
  
NOTE	 :  If column names are changed for the Output Result Sets run the stored procedure in a query anaylyzer window.  
  Otherwise you may get an error   
  Report Generation Failed. [Template:] RptMasterBatchInv.xlt [ErrorCode:] 6 [Description:] [-1][RptMasterBatchInv38][RptData()][DO Exec SQL false 'Exec spLocal_RptMasterBatchInventory @RptName = 'MasterBatchInventory20060927112306' 'ExecuteSQL>> ODBC drive   
    
  
3/23/2015   Santosh S	Fixed the Unique key violation issue by adding a condition TableId = 43 --Prod_Units_Base while populating @Tree since there are 2 UDP of name ReportConsumption      
3/24/2015	Santosh S	Removed PK constraint from @Tree
3/27/2015	Santosh S	Added a entry in App_Versions table and also added standard sections in the SP
4/16/2018	Michel M	Changed views to base table names for Proficy 6.2 upgrade
-------------------------------------------------------------------------------  
8/7/2018	Fernando Rio	Created a new version for HTML5 Reports
*/-----------------------------------------------------------------------------  

CREATE PROCEDURE dbo.spLocal_RptMasterBatchInventory_HTML5  
	@PUIdList NVARCHAR(4000)  
--WITH ENCRYPTION	
AS  
SET NOCOUNT ON  
SET ANSI_WARNINGS OFF  
  
DECLARE @DebugLevel INT  
SET @DebugLevel = 0  
  
--IF (@DebugLevel > 1)  
-- INSERT Local_Debug ( Timestamp, Message, CallingSP )  
-- VALUES (GETDATE(), 'Start - '  
--  + '  @RptName='+isnull(convert(varchar(8000),@RptName),''),  
--  Object_Name(@@ProcId))  
  
-------------------------------------------------------------------------------  
-- Declare variables  
-------------------------------------------------------------------------------  
 
DECLARE @I int,  
 @EventId int,  
 @MB varchar(255),  
 @MBTemp varchar(50),  
 @MaxLevel int,  
 @Type_MBCurrent int,  
 @Type_MBUp int,  
 @Type_MBDown int,  
 @Type_Control int  
  
DECLARE @RptOwnerId int,   
 @RptOwnerDesc nvarchar(50),  
 @CompanyName nvarchar(50),  
 @SiteName nvarchar(50)  
  
DECLARE @Tree TABLE (  
 [Id] int IDENTITY(1,1),  
 TopEventId int,  
 EventId int,  
 PPSetupId int,  
 ReportConsumption int,  
 [Level] int  
 --primary key ([Level], TopEventId, EventId)  --Removed the Primary Key constraint
)  
  
DECLARE @EventMasterBatches TABLE (   
 [Id] int IDENTITY(1,1),  
 EventId int,   
 PPSetupId int,  
 MasterBatch varchar(50),  
 MasterBatchCon varchar(50)  
 primary key ([Id])  
)  
  
DECLARE @Event TABLE (  
 [Id] int IDENTITY(1,1),  
 EventId int,  
 PPSetupId int,  
 MasterBatch_ControlGroup varchar(255),  
 Type int, -- Master Batch current, Master Batch up, Master Batch down, Control Group  
 primary key (EventId)  
)  
  
DECLARE @Inventory TABLE (   
 [Id] int IDENTITY(1,1),  
 Unit varchar(50),   
 Product varchar(50),   
 MasterBatch varchar(255),   
 ProcessOrder varchar(50),   
 Weight float,   
 [User] varchar(255),   
 Approver varchar(255),  
 Order1 varchar(50),   
 Order2 int  
)  
  
CREATE TABLE #TempCollection (  
 RcdId int,  
 Field1 int  
)  
  
-------------------------------------------------------------------------------  
-- Set Constants  
-------------------------------------------------------------------------------  
SELECT @Type_MBCurrent = 1,  
 @Type_MBUp = 2,  
 @Type_MBDown = 3,  
 @Type_Control = 4  
  
SET @MaxLevel = 20  
  
-------------------------------------------------------------------------------  
-- Check Parameter: Company and Site Name  
-------------------------------------------------------------------------------  
SELECT @CompanyName = Coalesce(Value, 'Company Name') -- Company Name  
 FROM Site_Parameters   
 WHERE Parm_Id = 11  
IF Len(@CompanyName)<=0  
BEGIN  
   SELECT @CompanyName = 'Company Name'  
END  
--  
SELECT @SiteName = Coalesce(Value, 'Site Name') -- Site Name  
 FROM Site_Parameters   
 WHERE Parm_Id = 12  
  
----------------------------------------------------------------------------  
-- Get applicable Events   
----------------------------------------------------------------------------  
IF (isnull(@PUIdList,'') <> '')  
BEGIN  
 TRUNCATE TABLE #TempCollection  
 INSERT INTO #TempCollection ( RcdId, Field1 )  
  EXEC spCmn_ReportCollectionParsing   
   @PrmCollectionString = @PUIdList,  
   @PrmFieldDelimiter = null,   
   @PrmRecordDelimiter = ',',   
   @PrmDataType01 = 'Int'  
END  
ELSE  
BEGIN  
 TRUNCATE TABLE #TempCollection  
 INSERT INTO #TempCollection ( RcdId, Field1 )  
  EXEC spCmn_ReportCollectionParsing   
   @PrmCollectionString = '35,3,5,6,7,8,10,12,15,17,19,20,21,22,23,24,27,28,29,30,31,33',  
   @PrmFieldDelimiter = null,   
   @PrmRecordDelimiter = ',',   
   @PrmDataType01 = 'Int'  
/*  
 INSERT INTO #TempCollection ( Field1 )  
  SELECT PU_Id  
  FROM Prod_Units_Base pu  --changes done by AV
  WHERE pu.PU_Desc not like 'Test%'  
  WHERE pu.PU_  
   AND EXISTS (SELECT 1 FROM Event_Configuration ec WHERE ec.PU_Id = pu.PU_Id and ec.ET_Id = 1)  
*/  
END  
  
INSERT INTO @Event ( EventId, Type )  
  SELECT e.Event_Id,  
   CASE upper(left(tfv_mb.Value,1))  
    WHEN 'C' THEN @Type_Control  --Control Group  
    WHEN 'T' THEN @Type_MBCurrent --This Unit  
    WHEN 'U' THEN @Type_MBUp  --Up  
    WHEN 'D' THEN @Type_MBDown  --Down  
    ELSE null  
    END  
  FROM dbo.Events e  WITH(NOLOCK)
  JOIN dbo.Production_Status prs WITH(NOLOCK) on prs.ProdStatus_Id = e.Event_Status  
  JOIN dbo.Table_Fields tf_mb WITH(NOLOCK) ON tf_mb.Table_Field_Desc = 'MasterBatchSearchType'  
   JOIN dbo.Table_Fields_Values tfv_mb WITH(NOLOCK) ON tfv_mb.Table_Field_Id = tf_mb.Table_Field_Id  
             AND tfv_mb.TableId = 43 --Prod_Units_Base     
             AND tfv_mb.KeyId = e.PU_Id  
  WHERE prs.Count_For_Inventory = 1  
   AND e.PU_Id in ( SELECT Field1 FROM #TempCollection )  
--    OR (isnull(@PUIdList,'') = '' AND pu.PU_Desc not like 'Test%'))  
  
DELETE @Event  
 WHERE Type is null  
  
----------------------------------------------------------------------------  
-- Process Current PU events  
----------------------------------------------------------------------------  
UPDATE @Event  
 SET PPSetupId = ps.PP_Setup_Id  
 FROM @Event e1  
 JOIN dbo.Events e WITH(NOLOCK) ON e.Event_Id = e1.EventId  
  LEFT OUTER JOIN dbo.Event_Details ed WITH(NOLOCK) ON ed.Event_Id = e.Event_Id  
  LEFT OUTER JOIN dbo.Production_Plan_Starts pps WITH(NOLOCK) ON pps.PU_Id = e.PU_Id  
          AND pps.Start_Time <= e.[Timestamp]  
          AND (pps.End_Time > e.[Timestamp] OR pps.End_Time is null)  
   LEFT OUTER JOIN dbo.Production_Setup ps WITH(NOLOCK) ON ps.PP_Id = isnull(ed.PP_Id,pps.PP_Id)  
 WHERE e1.Type = @Type_MBCurrent  
  
----------------------------------------------------------------------------  
-- Process Up PU events  
-- Don't include PO of Top event since we want the PO of the original material  
----------------------------------------------------------------------------  
SET @I = @MaxLevel  
  
DELETE @Tree  
INSERT INTO @Tree  
 SELECT e.Event_Id,  
   e.Event_Id,  
   null, --ps.PP_Setup_Id,  
   0, --tfv_rc.Value,  
   @I  
  FROM @Event e1  
  JOIN dbo.Events e WITH(NOLOCK) ON e.Event_Id = e1.EventId  
   LEFT OUTER JOIN dbo.Event_Details ed WITH(NOLOCK) ON ed.Event_Id = e.Event_Id  
--    LEFT OUTER JOIN Production_Plan_Starts pps ON pps.PU_Id = e.PU_Id  
--            AND pps.Start_Time <= e.[Timestamp]  
--            AND (pps.End_Time > e.[Timestamp] OR pps.End_Time is null)  
--     LEFT OUTER JOIN Production_Setup ps ON ps.PP_Id = isnull(ed.PP_Id,pps.PP_Id)  
--    JOIN Table_Fields tf_rc ON tf_rc.Table_Field_Desc = 'ReportConsumption'  
--     LEFT OUTER JOIN Table_Fields_Values tfv_rc ON tfv_rc.Table_Field_Id = tf_rc.Table_Field_Id  
--               AND tfv_rc.TableId = 43 --Prod_Units_Base     
--               AND tfv_rc.KeyId = e.PU_Id  
  WHERE e1.Type = @Type_MBUp  
  
WHILE (@I > 0)  
BEGIN  
-- select * from @Tree  
 INSERT INTO @Tree  
  SELECT DISTINCT   
    t.TopEventId,  
    e.Event_Id,  
    ps.PP_Setup_Id,  
    tfv_rc.Value,  
    @I - 1  
   FROM @Tree t  
   JOIN dbo.Event_Components ec WITH(NOLOCK) ON ec.Event_Id = t.EventId  
    JOIN dbo.Events e WITH(NOLOCK) ON e.Event_Id = ec.Source_Event_Id  
     LEFT OUTER JOIN dbo.Event_Details ed WITH(NOLOCK) ON ed.Event_Id = e.Event_Id  
     LEFT OUTER JOIN dbo.Production_Plan_Starts pps WITH(NOLOCK) ON pps.PU_Id = e.PU_Id  
             AND pps.Start_Time <= e.[Timestamp]  
             AND (pps.End_Time > e.[Timestamp] OR pps.End_Time is null)  
      LEFT OUTER JOIN dbo.Production_Setup ps WITH(NOLOCK) ON ps.PP_Id = isnull(ed.PP_Id,pps.PP_Id)  
   JOIN dbo.Table_Fields tf_rc WITH(NOLOCK) ON tf_rc.Table_Field_Desc = 'ReportConsumption' AND tf_rc.TableId = 43 --Prod_Units_Base  --Added by TCS tf_rc.TableId = 43    
    LEFT OUTER JOIN dbo.Table_Fields_Values tfv_rc WITH(NOLOCK) ON tfv_rc.Table_Field_Id = tf_rc.Table_Field_Id  
              AND tfv_rc.TableId = 43 --Prod_Units_Base     
              AND tfv_rc.KeyId = e.PU_Id  
   WHERE t.[Level] = @I  
    AND t.PPSetupId is null  
--    AND t.ReportConsumption = 0  
    AND (ec.Report_As_Consumption = 0 or @I = @MaxLevel)  
     
 IF (@@Rowcount = 0)  
  SET @I = -1  
 ELSE  
  SET @I = @I - 1  
  
END  
  
-- select * from @Tree  
--  where TopEventId = 73742  
-- SELECT *, (SELECT TOP 1 t.PPSetupId FROM @Tree t WHERE t.TopEventId = e.EventId AND t.ReportConsumption = 1 ORDER BY t.[Level] ASC)  
--  FROM @Event e  
--  where e.EventId = 73742  
  
UPDATE e  -- need to pick a better order by in the next line (duplicated below)  
 SET PPSetupId = (SELECT TOP 1 t.PPSetupId FROM @Tree t WHERE t.TopEventId = e.EventId ORDER BY t.[Level] ASC) --AND t.ReportConsumption = 1   
 FROM @Event e  
 WHERE e.Type = @Type_MBUp  
  
--SELECT * FROM @Tree ORDER BY TopEventId ASC  
  
INSERT @EventMasterBatches ( EventId, PPSetupId )  
 SELECT DISTINCT t.TopEventId, t.PPSetupId  
 FROM @Tree t  
 WHERE t.[Level] in (SELECT min(t2.[Level]) FROM @Tree t2 WHERE t2.TopEventId = t.TopEventId GROUP BY t2.TopEventId)  
  AND t.PPSetupId is not null  
  
----------------------------------------------------------------------------  
-- Process Down PU events  
-- Don't include PO of Top event since we want the PO of the original material (?)  
----------------------------------------------------------------------------  
SET @I = @MaxLevel  
  
DELETE @Tree  
INSERT INTO @Tree  
 SELECT e.Event_Id,  
   e.Event_Id,  
   null, --ps.PP_Setup_Id,  
   0, --tfv_rc.Value,  
   @I  
  FROM @Event e1  
  JOIN dbo.Events e WITH(NOLOCK) ON e.Event_Id = e1.EventId  
   LEFT OUTER JOIN dbo.Event_Details ed  WITH(NOLOCK) ON ed.Event_Id = e.Event_Id  
--    LEFT OUTER JOIN Production_Plan_Starts pps ON pps.PU_Id = e.PU_Id  
--            AND pps.Start_Time <= e.[Timestamp]  
--            AND (pps.End_Time > e.[Timestamp] OR pps.End_Time is null)  
--     LEFT OUTER JOIN Production_Setup ps ON ps.PP_Id = isnull(ed.PP_Id,pps.PP_Id)  
--    JOIN Table_Fields tf_rc ON tf_rc.Table_Field_Desc = 'ReportConsumption'  
--     LEFT OUTER JOIN Table_Fields_Values tfv_rc ON tfv_rc.Table_Field_Id = tf_rc.Table_Field_Id  
--               AND tfv_rc.TableId = 43 --Prod_Units_Base     
--               AND tfv_rc.KeyId = e.PU_Id  
  WHERE e1.Type = @Type_MBDown  
  
WHILE (@I > 0)  
BEGIN  
-- select * from @Tree  
 INSERT INTO @Tree  
  SELECT DISTINCT   
    t.TopEventId,  
    e.Event_Id,  
    ps.PP_Setup_Id,  
    tfv_rc.Value,  
    @I - 1  
   FROM @Tree t  
   JOIN Event_Components ec ON ec.Source_Event_Id = t.EventId  
    JOIN dbo.Events e WITH(NOLOCK) ON e.Event_Id = ec.Event_Id  
     LEFT OUTER JOIN dbo.Event_Details ed WITH(NOLOCK) ON ed.Event_Id = e.Event_Id  
     LEFT OUTER JOIN dbo.Production_Plan_Starts pps WITH(NOLOCK) ON pps.PU_Id = e.PU_Id  
             AND pps.Start_Time <= e.[Timestamp]  
             AND (pps.End_Time > e.[Timestamp] OR pps.End_Time is null)  
      LEFT OUTER JOIN dbo.Production_Setup ps WITH(NOLOCK) ON ps.PP_Id = isnull(ed.PP_Id,pps.PP_Id)  
   JOIN dbo.Table_Fields tf_rc WITH(NOLOCK) ON tf_rc.Table_Field_Desc = 'ReportConsumption' AND tf_rc.TableId = 43 --Prod_Units_Base  --Added by TCS tf_rc.TableId = 43    
    LEFT OUTER JOIN dbo.Table_Fields_Values tfv_rc WITH(NOLOCK) ON tfv_rc.Table_Field_Id = tf_rc.Table_Field_Id  
              AND tfv_rc.TableId = 43 --Prod_Units_Base     
              AND tfv_rc.KeyId = e.PU_Id  
   WHERE t.[Level] = @I  
    AND t.PPSetupId is null  
--    AND t.ReportConsumption = 0  
    AND (ec.Report_As_Consumption = 0 or @I = @MaxLevel)  
     
 IF (@@Rowcount = 0)  
  SET @I = -1  
 ELSE  
  SET @I = @I - 1  
  
END  
  
-- select * from @Tree  
--  where TopEventId = 73742  
-- SELECT *, (SELECT TOP 1 t.PPSetupId FROM @Tree t WHERE t.TopEventId = e.EventId AND t.ReportConsumption = 1 ORDER BY t.[Level] ASC)  
--  FROM @Event e  
--  where e.EventId = 73742  
  
UPDATE e  -- need to pick a better order by in the next line (duplcated above)  
 SET PPSetupId = (SELECT TOP 1 t.PPSetupId FROM @Tree t WHERE t.TopEventId = e.EventId ORDER BY t.[Level] ASC) --AND ReportConsumption = 1   
 FROM @Event e  
 WHERE e.Type = @Type_MBDown  
  
--SELECT * FROM @Tree ORDER BY TopEventId ASC  
  
INSERT @EventMasterBatches ( EventId, PPSetupId )  
 SELECT DISTINCT t.TopEventId, t.PPSetupId  
 FROM @Tree t  
 WHERE t.[Level] in (SELECT min(t2.[Level]) FROM @Tree t2 WHERE t2.TopEventId = t.EventId GROUP BY t2.TopEventId)  
  AND t.PPSetupId is not null  
   
--SELECT * FROM @EventMasterBatches  
  
----------------------------------------------------------------------------  
-- Process Control Group events  
----------------------------------------------------------------------------  
UPDATE @EventMasterBatches  
 SET MasterBatch = pset.Pattern_Code  
 FROM @EventMasterBatches emb  
 LEFT OUTER JOIN Production_Setup pset ON pset.PP_Setup_Id = emb.PPSetupId  
   LEFT OUTER JOIN Production_Plan pp ON pp.PP_Id = pset.PP_Id  
  
--SELECT * FROM @EventMasterBatches  
  
SELECT @I = max([Id])  
 FROM @EventMasterBatches  
  
WHILE (@I > 0)  
BEGIN  
 SELECT @EventId = EventId  
  FROM @EventMasterBatches  
  WHERE [Id] = @I  
  
 SET @MB = ''  
 DECLARE Event CURSOR FOR  
  SELECT DISTINCT MasterBatch  
  FROM @EventMasterBatches  
  WHERE EventId = @EventId  
 OPEN Event  
 FETCH NEXT FROM Event INTO @MBTemp  
  
 WHILE (@@Fetch_Status = 0)  
 BEGIN  
  IF (@MB not like '%' + @MBTemp + '%')  
   SET @MB = @MB + @MBTemp + '/'  
  FETCH NEXT FROM Event INTO @MBTemp  
 END  
  
 CLOSE Event  
 DEALLOCATE Event  
  
 UPDATE @EventMasterBatches  
  SET MasterBatchCon = left(@MB,len(@MB)-1)  
  WHERE [Id] = @I  
  
 SET @I = @I - 1  
END  
  
UPDATE e  
 SET MasterBatch_ControlGroup = emb.MasterBatchCon  
 FROM @Event e  
 JOIN @EventMasterBatches emb ON emb.EventId = e.EventId  
  
UPDATE e  -- need to pick a better order by in the next line (duplcated above)  
 SET MasterBatch_ControlGroup = t.Result  
 FROM @Event e  
 JOIN dbo.Events e2 WITH(NOLOCK) ON e2.Event_Id = e.EventId  
  JOIN dbo.Variables_Base v WITH(NOLOCK) ON v.PU_Id = e2.PU_Id  
      AND v.Var_Desc = 'Control Group'  
   JOIN dbo.Tests t WITH(NOLOCK) ON t.Result_On = e2.[Timestamp]  
      AND t.Var_Id = v.Var_Id  
 WHERE e.Type = @Type_Control  
  
-------------------------------------------------------------------------------  
-- Build main data table  
-------------------------------------------------------------------------------  
-- select pu.PU_Desc, *   
--  from @Event e  
--  join Events e2 on e2.Event_Id = e.EventId  
--  join Prod_Units_Base pu on pu.PU_ID = e2.PU_Id  
  
INSERT INTO @Inventory ( Unit, Product, MasterBatch, ProcessOrder, Weight, [User], Approver, Order1, Order2 )  
 SELECT pu.PU_Desc,  
  p.Prod_Code,  
  isnull(e1.MasterBatch_ControlGroup,pset.Pattern_Code),  
  pp.Process_Order,  
  convert(numeric(20,2),sum(ed.Final_Dimension_X)),  
  pp.User_General_1,  
  pp.User_General_2,  
--  convert(varchar(25),pps.Start_Time,120)  
  pl.PL_Desc,   
  pu.PU_Order  
 FROM dbo.Prod_Units_Base pu  WITH(NOLOCK) --changes done by AV
 JOIN dbo.Prod_Lines_Base pl  WITH(NOLOCK)   ON pl.PL_Id = pu.PL_Id  
 LEFT OUTER JOIN dbo.Events e  WITH(NOLOCK)
  JOIN @Event e1 ON e1.EventId = e.Event_Id  
 ON e.PU_Id = pu.PU_Id  
  LEFT OUTER JOIN dbo.Production_Starts ps WITH(NOLOCK) ON ps.PU_Id = e.PU_Id  
        AND ps.Start_Time <= e.[Timestamp]  
        AND (ps.End_Time > e.[Timestamp] or ps.End_Time is null)  
  LEFT OUTER JOIN dbo.Event_Details ed WITH(NOLOCK) ON ed.Event_Id = e.Event_Id  
   LEFT OUTER JOIN dbo.Products_Base p WITH(NOLOCK) ON p.Prod_Id = isnull(e.Applied_Product,ps.Prod_Id)  
--   LEFT OUTER JOIN (SELECT t.TopEventId,  -- THIS NEEDS TO BE A DOUBLE JOIN TO GET THE EVENT WITH THE MOST, OR PART OR WHATEVER  
--      max(t.PPSetupId) as PPSetupId  
--     FROM @Tree t  
--     GROUP BY t.TopEventId) t2 ON t2.TopEventId = e.Event_Id  
   LEFT OUTER JOIN dbo.Production_Setup pset WITH(NOLOCK) ON pset.PP_Setup_Id = e1.PPSetupId  
     LEFT OUTER JOIN dbo.Production_Plan pp WITH(NOLOCK) ON pp.PP_Id = pset.PP_Id  
--   LEFT OUTER JOIN Production_Plan_Starts pps ON pps.PU_Id = e.PU_Id  
--              AND pps.Start_Time <= e.[Timestamp]  
--              AND (pps.End_Time > e.[Timestamp] or pps.End_Time is null)  
--    LEFT OUTER JOIN Production_Plan pp ON pp.PP_Id = isnull(ed.PP_Id,pps.PP_Id)  
 WHERE pu.PU_Id in ( SELECT Field1 FROM #TempCollection )   
 GROUP BY pu.PU_Desc,  
  p.Prod_Code,  
  pp.Process_Order,  
  isnull(MasterBatch_ControlGroup,pset.Pattern_Code),  
  pp.User_General_1,  
  pp.User_General_2,  
--  pps.Start_Time,  
  pl.PL_Desc,  
  pu.PU_Order  
  
-------------------------------------------------------------------------------  
-- Resultset 1: Miscellaneous information  
-------------------------------------------------------------------------------  
SET @RptOwnerId = 1  
SET @RptOwnerDesc = ''  
SELECT @RptOwnerDesc = Coalesce(User_Desc, Username)  
 FROM  dbo.Users_Base   WITH(NOLOCK) --changes done by AV
 WHERE [User_Id] = @RptOwnerId  
  
SELECT @RptOwnerId as 'RptOwnerId',   
 @RptOwnerDesc as 'RptOwnerDesc',   
 @CompanyName as 'CompanyName',  
 @SiteName as 'SiteName',  
 convert(varchar,getdate()) as 'StartDateTime',  
 convert(varchar,getdate()) as 'EndDateTime',  
 'Master Batch Inventory' as 'RptTitle'  
-- Added to show date when used as html output  
SELECT 'Batch Inventory Report    ' + convert(varchar(17),getdate(),13) as 'Report Details'  
-------------------------------------------------------------------------------  
-- Resultset 2: Inventory by PU  
-------------------------------------------------------------------------------  
SELECT Unit as 'Unit|JL;NR;',  
  sum(Weight) as 'Weight|JR;NF"#,##0";GT;'  --NF"#,###.0";  
--  convert(varchar(25),pps.Start_Time,120) as 'Start Time'  
 FROM @Inventory  
 GROUP BY Unit, Order1, Order2   
 ORDER BY Order1, Order2  
  
-------------------------------------------------------------------------------  
-- Resultset 3: Inventory by PU and Master Batch  
-------------------------------------------------------------------------------  
SELECT Unit as 'Unit|JL;NR;',  
  Product as 'Product|JL;',  
  MasterBatch as 'Master Batch|JR;',  
  ProcessOrder as 'Process Order|JR;',  
  Weight as 'Weight|JR;NF"#,##0";GT;',  
  [User] as 'User',  
  Approver as 'Approver'  
--  convert(varchar(25),pps.Start_Time,120) as 'Start Time'  
 FROM @Inventory  
 ORDER BY Order1, Order2  
GO 
  
--Step D update the sp for the grant normally to ComxClient
GRANT EXEC ON [dbo].[spLocal_RptMasterBatchInventory_HTML5] TO [ComxClient]
GO

GRANT EXEC ON [dbo].[spLocal_RptMasterBatchInventory_HTML5] TO [RptUser]
GO
--Step E update table dbo.AppVersions to maintain SP Version
---------------------------------------------------------------------------------------------------
-- Prototype definition
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@Input 			INT, --# of parameters that are used as Input to SP
		@Input_Output 	INT, --# of parameters that are used as Input / Output to SP
		@Output 		INT, --# of parameters that are used as Output to SP
		@SP 			VARCHAR(100),
		@Version		VARCHAR(25),
		@AppId			INT

SELECT	@Input 			= 1, 
		@Input_Output 	= 0, 	
		@Output 		= 0,
		@SP	 			= 'spLocal_RptMasterBatchInventory_HTML5',
		@Version		= '1.0' 

SELECT @AppId = MAX(App_Id) + 1 
		FROM dbo.AppVersions

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
IF EXISTS (SELECT 1 
		FROM dbo.AppVersions (NOLOCK)
		WHERE app_name = @SP) 
BEGIN
	UPDATE dbo.AppVersions 
		SET App_Version = @Version,
			Modified_On = GETDATE()
		WHERE APP_NAME  = @SP
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_Id,
		App_Name,
		App_version)
	VALUES (
		@AppId, 
		@SP,
		@Version)
END
GO  

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO


GRANT EXECUTE ON [dbo].spLocal_RptMasterBatchInventory_HTML5 TO OPDBManager
GO