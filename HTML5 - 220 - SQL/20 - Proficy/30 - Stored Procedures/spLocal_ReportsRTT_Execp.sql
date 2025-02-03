
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO
----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_ReportsRTT_Execp',
		@Inputs		= 8, 
		@Version	= '3.3'  

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

-----------------------------------------[Drop Existing PROCEDURE]--------------------------------------
IF EXISTS	(
				SELECT	* 
				FROM		dbo.sysobjects WITH(NOLOCK)
				WHERE		(Id = object_id(N'[dbo].[spLocal_ReportsRTT_Execp]')
				AND          OBJECTPROPERTY(id, N'IsProcedure') = 1)
			)
	BEGIN
		DROP PROCEDURE [dbo].[spLocal_ReportsRTT_Execp]
	END
GO 

CREATE   PROCEDURE [dbo].[spLocal_ReportsRTT_Execp] 

/*
----------------------------------------------------------------------------------------------------------------------
-- 	Report Name : RTT Exception Report														  	
-----------------------------------------------------------------------------------------------------------------------
--	SP Version :3.2

-- Version history:
-- =============

 Version	Date		Author				Description
 =======	====		======				===========
 3.3		2021-12-02	Gonzalo Luc			Fix npt slices adding the order and the correct starttime slice when multiple lines are selected.
 3.2		2021-05-08	Jorge Merino		Added condition for NPTs that are covering all the report time window.
 3.1		2021-07-23	Jorge Merino		Standarizing NPT phrases to have a blank space after ':'.
 3.0		2021-05-11	Gonzalo Luc			Fix filling npt gaps with line normal for more than one unit.
 2.9		2020-08-27	Santiago Gimenez	Reference Local_PG_Line_Status if NPT is empty.
 2.8		2020-07-27	Santiago Gimenez	Fix NPT.
 2.7		2020-05-06	Gonzalo Luc			FO-04381: Add ThingWorx user and uncomment NO COUNT ON
 2.6		2020-04-16	Santiago Gimenez	FO-04381: Replace Local_PG_Line_Status with NonProductive_Detail.

Gonzalo Luc 2020-02-28
VERSION 2.5
FO

Alvaro Palacios - 11/Feb/2020
VERSION 2.4
FO-04286: Extend PUG_Desc to include the whole name of the Equipment Area.
===========
VERSION 2.3
FO-03213: Update the Centerline report to use LocalUser instead of Comxclient
VERSION 2.2 
FO-02573 Added clause to exclude RTT units under obsoleted lines and removed the SP registration and update appversion section
VERSION 2.0 
27-June-2013 Chaitanya Joshi-TCS(EM-00094) 
--Added the appversion code at the beginning.
  
-- Panpaliya.np
--	(30-July-2012)  Modified condition to detect the target only variable for defect handling
-- Panpaliya.np  
-- (11-April-2012) Modified Defect Handling Section to consider defect for off target values.
-- Kapadia.n.1
-- (19-Aug-2010)   Error handling on DML statements and modified SP to handle Non numeric & comma values in specs limit.

-- FRio :

-- (20-AUG-2007) Covered FO-00012 MES Change Request: RTT exception report logic correction .
-- (5-Jul-07)  Last #Output table population is not filtering Crew, Shift and LineStatus
-- (19-Oct-06) Get rid of all variables with RPT=N when populating the #PreVar_Ids table.
-- (22-Sep-06) Avoid Issue when daily column is greyed and not blue.
-- (9-Aug-06)  Change the way to get the displays associated to a specific Line, seems that the sheet_group_desc
--			   does not always match.
-- (1-Aug-06)  Changed from description for time options to numbers
-- (14-Jul-06) Optimized Physical Reads to disk to improve performance.
-- (21-Jun-06) Optimized.
-- (30-Mar-06) If the start_date of a time frame is before the Line Start Time then the Report Fails in getting 
--			   the variables for that.
-- (20-Mar-06) Get rid of statements that includes or excludes time frames according line status
--			   get the line status from a variable as the line status of the Line when the variable
--			   is fired.
-- (13-Jan-2006) Do not show Action/Comments/Cause for Missed/Remaining Sheets
-- (27-Dec-2005) Change the way to get the Alarms, when same variable alarms in the same period.
-- (16-Dec-2005) Fixed Weekly Time Frames check on label 2005-12-16.
-- (7-Nov-2005)  Added Index on Frequency, avoid report hungup when multiple lines are selected
--               and the amount of variables is huge.
-- (13-Oct-2005) Get rid of first join to var_specs table that was not using the prod_id.
-- (11-Oct-2005) Added some WITH(NOLOCK) missed on new coding for Alarms logic.
-- (29-Sep-2005) Fixed Comments, Action and Cause when the Alarms are still opened.
-- (16-Sep-2005) Be Aware of the NULLs on the Stubbed column to check if they are complete.
-- (9-Sep-2005)  Get rid of variables that has no column sttubed for a given time period.
-- (29-Aug-2005) Set as 'No Team' when no crew schedule for a selected period.
-- (26-Aug-2005) Increased the string to hold the line desc list
-- (2-Aug-2005)  Checked the #Line_Status table and the #Crew_Schedule table.
-- (1-Aug-2005)  Fixed the calculation for LASTMONTH. Fixed calculation for Start_Date, End_Date for Weeklys.

-- (26-Jul-2005) Made some changes to the Start_Time calculation of Daily variables, when SHIFTLYs also this impacts
-- on End_Time calculation.

-- (14-Jul-2005) When SHIFTLY report then get the Start_Time from the Crew_Schedule to avoid Crews with different
-- shift lenght

-- DJM and FRio 2005 Jul 13: 
-- Changed update of Next_start_date for Shiftly variables to use the End time from Crew Schedule table.

-- FRio :
-- (5-Jul-2005) Added Priority to the TempCL sheet.

-- FRio :              version 1.5b   (1-Jul-2005)
-- Added logic to deal with the TT on Daily variables.

-- DJM :               version 1.5a   (16-Jun-2005)
-- Removed Missing Samples from Deviations Sheet
-- Report now considers tests as missed if the sample is not performed by the report end time.
-- Previous statement was if test was less than (<) report end time, now looks at equal to or less than (<=)

-- Frio :               version 1.5   (6-Jun-2005)
-- Removed deletion for Test_Freq = 0.

-- Frio :               version 1.5   (3-Jun-2005)
-- Added requests by Dan. 

-- FRio :               version 1.4.1 (23-May-2005)
-- THIS IS THE CURRENT VERSION SENT TO DAN, IT IS COMMENTED THE TEMPCL STUFF AND THE LAST RECORDSET.

-- Frio :               version 1.4.1 (2-May-2005)
-- Re-Written piece of code that gets all variables, updates to Crew, Shift, LineStatus. Speed up all.
-- the script for CRA and BELL lines wich large amount of Shiftly Auto variables.

-- Frio :               version 1.3.13 (21-Apr-2005)
-- Change the way to get the Dailys time frames when the Local_PG_Schedule Display is empty.
-- Use Result_on to compare Line Status.

-- Frio :               version 1.3.12 (16-Apr-2005)
-- Change the way to get the samples missed and the not yet due, not complete.

-- Frio :               version 1.3.12 (11-Apr-2005)
-- If no samples taken then no defects.
-- Changed the Samples_Due calculation.

-- Frio :               version 1.3.12 (1-Apr-2005)
-- Some variables belong to the RTT Alarm display, this causes some mess when looking for Result_On columns.

-- Frio :               version 1.3.11 (21-Mar-2005)
-- Now using the Columns from the Sheets table to detect the columns on the display instead of the time frames.
-- Shiftly Autos and Recipe are not recorded there, so need to add from Time_Frames.
  
-- FRio : 		version 1.3.10 (16-Feb-2005)
-- Change the way to calculate Missing Samples according to Dan M. comments. 
-- Set Result_On = End_Date when no samples taken in the period and changed the comparision to detect overdue samples.

-- FRio : 		version 1.3.9 (10-Dec-2004)
-- Change Logic to get time frames. If a variable has no column for any given time frame then do not
-- count it as missed or due. Logic for Line Status is the standard one, check for each period the
-- correspondant line status and according to that include or exclude it. 
-- 16-Dec-2004 Fix for Recipe Dynamic group.

-- FRio : 		version 1.3.8 (20-Nov-2004)
-- Changed Recipe variables, get the time frame from Crew_Schedule table.

-- FRio :		version 1.3.7 (20-Aug-2004)
-- Fixed Line_Status_Lookup table, does not get all the Tests.

-- FRio :		version 1.3.6 (18-Aug-2004)
-- Set the start time to look for a line_status to 3 years instead of 1 year,
-- that causes troubles at some sites. Fixed Recipe Time Frames.

-- FRio :		version 1.3.5 (22-Jul-2004)
-- 7/22/2004 added some COLLATE functionalities to avoid conficts between collations

-- FRio :		version 1.3.4 (13-Jul-2004)
-- 7/13/2004 Get the Shiftly time Frames from Crew Schedule table instead of getting from
-- shiftlenght logic

-- FRio :		version 1.3.3 (7-Jul-2004)
-- 7/7/2004 Fixed bug about monthly based time frames

-- FRio : 		version 1.3.2 (28-May-2004)
-- 6/4/2004 Fixed Line Status bug, caused by the Result_On = Start_time update.

-- FRio : 		version 1.3.2 (28-May-2004)
-- 5/13/2004 Fixed bug related to weekly TT=; extended_info variables.

-- FRio : 4/13/2004 Added extra-parameter @in_TimeOption, @isMonthlyBased must be set to 'Yes' or 'No'
-- according to parameters selected on the Web Server.

-- FRio : 4/7/2004 Changed the logic for looking Active Specs, must be done after getting the Result_on value

-- FRio : 4/6/2004 Added Master and Detail, for Defects to prevent variables that has more than one defect in 
-- that time frame

-- FRio : 3/28/2004 changed the way to filter Not Due Variables, Not Complete Variables, in order to include as
-- due the early samples.

-- FRio : 3/28/2004 need to understand better the TT=; logic for monthly variables it is not clear after last
-- call that for monthly variables TT=010730; means that becomes due the first day of the month.

-- FRio : 3/25/2004 Create another column at #Var_IDs temporary table named Due_Date for Due_Date 
-- calculation instead of calculating with Start_Time.

-- FRio : 3/24/2004 After talking to Joe : add another column named due date, and modify it according to TT values.

-- FRio : 3/22/2004 f) Total_W_O_Recipe calculation included and working.

-- FRio : 3/16/2004 Changed f)Quarterly to g)Quarterly in order to include f)Total_WO_Recipe.

-- FRio : 3/5/2004 Modified to include the Result_on field at output.

-- This script replace Time Frames buildings instead of doing it on #Var_IDs table (5000 records)
-- it builds a #Time_Frames temp table with Start_Times and End_Times, later will be applied to
-- #All_Variables temp table at Start_Time and End_Time fields. */

-- Script parameters

 --Declare 

	@in_LineDesc 		    nvarchar(250),
	@in_StartTime 		    datetime,
	@in_EndTime 		    datetime,
	@in_Crew            	varchar(1250),      	-- Crew Description or 'All' (Also called Team)
	@in_Shift           	varchar(30),        	-- Shift Description or 'All'
	@in_LineStatus          varchar(600),   	    -- Line Status or 'All'
	@in_ReportType          varchar(20),    	    -- 'Recipe', 'NonRecipe' or 'All'
	@in_TimeOption		    varchar(20)
    
  	        -- Yes, No if Some Monthly option is selected

-- Test Values
-- Select * From Prod_Lines_Base where pl_desc like '%71%'

 --set @in_StartTime 	    = '2021-11-01 06:15:00'
 --set @in_EndTime 	    = '2021-11-08 06:15:00'
 --set @in_LineDesc 	    = 'QRAE71,QRAE72,QRAE73,QRAE74,QRAE75,QRAE76,QRAE77,QRAE78,QRAE79,QRAE80,QRAE81,QRAE82,QRAE84,QRAE85,QRAE86'--w,DIEU171,DIEU172,DIEU173,DIEU174,DIEU175,DIEU176,DIEU177'--'DIEU137,DIEU138,DIEU139'
 --set @in_Crew      	    = 'All'         	        -- Crew Description or 'All' (Also called Team)
 --set @in_Shift      	= 'All'   	    	        -- Shift Description or 'All'
 --set @in_LineStatus     = 'PR In:E.O. Shippable,PR In:Line Normal,PR In:Line Project,PR In:Qualification,PR Out:STNU,PR In: EO Shippable,PR In: Line Normal,PR In: Line Project,PR In: Qualification,PR Out: STNU'--'PR In: EO Shippable,PR In: Line Normal,PR In: Line Project,PR In: Project,PR In: Qualification'	    				-- Line Status or 'All'	
 --set @in_ReportType     = 'NonRecipe'        		-- 'Recipe', 'NonRecipe' or 'All'
 --set @in_TimeOption	    = '-1'	   


--WITH ENCRYPTION 
AS

-- DBCC DROPCLEANBUFFERS
-- DBCC FREEPROCCACHE

SET NOCOUNT ON
-- SET STATISTICS IO OFF
-- SET STATISTICS TIME OFF -- ON

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

--------------------------------------------------------------------------------------------
-- Set @isMonthly variable to 'Yes' o 'No' according to @in_TimeOption value
--------------------------------------------------------------------------------------------
declare @isMonthlyBased as nvarchar(3)

If @in_TimeOption In ('10008','10009','10013','25','10014','29')
   set @isMonthlyBased = 'Yes'
Else
   set @isMonthlyBased = 'No'

-- Select @isMonthlyBased
--------------------------------------------------------------------------------------------
-- Apply Appropriate Report Time-Limit Filters (1 Week for Recipe; 1 Day for Combined)
-- Also need to check here if @isMonthlyBased = 'Yes' then @in_EndTime = @in_StartTime + 30?
--------------------------------------------------------------------------------------------

If DateDiff (d, @in_StartTime, @in_EndTime)> 7
and @in_ReportType = 'Recipe'
Begin
	Print convert(varchar(25), getdate(), 120) + ' Report Spans More than One Week.' 
	Print convert(varchar(25), getdate(), 120) + ' End Date will be reset to one week from start date.' 
	Set @in_EndTime = DateAdd(dd, 7, @in_StartTime)
	Set @isMonthlyBased = 'No'
End

If DateDiff (d, @in_StartTime, @in_EndTime)> 1	and @in_ReportType NOT IN ('Recipe', 'NonRecipe')
Begin
	Print convert(varchar(25), getdate(), 120) + ' Report Spans More than One Day.' 
	Print convert(varchar(25), getdate(), 120) + ' End Date will be reset to one day from start date.' 
	Set @in_EndTime = DateAdd(dd, 1, @in_StartTime)
	Set @isMonthlyBased = 'No'
End

-----------------------------------------------------------------------------------------------------------------
-- CREATE ALL TEMPORARY TABLES
-----------------------------------------------------------------------------------------------------------------
Create Table #PL_IDs
(RCDID   		int,
 PL_Desc 		nVarchar(20),
 PL_id  		int,
 PU_ID  		int,
 Conv_ID 		int,
 LineStarts		datetime )

Create Table #PLStatusDescList
(RCDID int,
PLStatusDesc nvarchar(50))

Create Table #Pre_Var_IDs 
(
		PU_Id  					int,
		PUG_Id          		int,
		PUG_Desc				nvarchar(50) ,
		Var_ID 					int,
		Var_Desc     			nvarchar(250),
		Extended_Info			nvarchar(255) ,
		Var_Type				nvarchar(20) ,
		Frequency				nvarchar(20),
		Sheet_Id        		int,
		Data_Type_Id			int
)


CREATE NONCLUSTERED INDEX IDX_VarId
ON #Pre_Var_Ids(Var_Id) ON [PRIMARY]

Create Table #Time_Frames
(
		PL_ID					int,
		PU_Id					int,
		PU_Desc					nvarchar(50) ,
		Frequency 				nvarchar(50) ,
		Start_Time 	    		datetime ,
		End_Time 				datetime ,
		day_period				int,
		Phrase_Value			nvarchar(50),
		Include 				nvarchar(3),
		Start_Date		        datetime,			-- Start date for determining sample info
   	    End_Date		        datetime,
		Due_Date		        datetime,
		Next_Start_Date 	    datetime		-- Start date for determining sample info

)

Create table #All_Variables (
		 RCIDx					INT IDENTITY,
		 PL_ID 			        int,
		 Line			        nvarchar(50) ,	
		 Pu_id                  int,
		 Var_ID			        int,
		 Var_Type		        nvarchar(50) ,
		 Var_Desc		        nvarchar(255) ,
		 Pug_Desc		        nvarchar(100) ,
		 Ext_Info		        nvarchar(100) ,
		 Prod_ID		        int,
		 Prod_Code		        nvarchar(30) ,
		 Master			        int,				-- "Master" record indicator (0 = summary; 1 = detail)
		 Frequency		        nvarchar(30) ,			-- Eg. Shiftly, Weekly or Monthly
		 Start_Date		        datetime,			-- Start date for determining sample info
		 End_Date		        datetime,
		 Due_Date		        datetime,
		 Next_Start_Date 	    datetime,			-- Start date for determining sample info
		 Day_Period             int,
		 Samples_Due 		    int,
		 Future_Samples_Due	    int,		
		 Samples_Taken		    int,				-- Samples Taken (to be updated later in code)
		 Prod_Desc		        nvarchar(100) ,		-- Product Description
		 L_Reject		        float,				-- Lower Reject Limit
		 L_Warning		        float,				-- Lower Warning Limit
		 L_User			        float,				-- User from Active Specs table
		 Target			        float,				-- Target for this variable from active specs
		 U_User			        float,
		 U_Warning		        float,
		 U_Reject		        float,
		 Result			        nvarchar(50) ,
		 Result_On		        datetime,
		 Defects		        int,				-- Defects (to be updated later in code)
		 Team			        nvarchar(15) ,
		 Shift			        nvarchar(30) ,
		 Line_Status		    nvarchar(100) ,
		 Include_Result 	    nvarchar(3) ,
		 Include_Crew 		    nvarchar(3) ,
		 Include_Shift 		    nvarchar(3),
		 Include_LineStatus 	nvarchar(3),
		 Include_Test           nvarchar(3),
		 Stubbed                nvarchar(3),
		 Canceled               int,
		 Test_Freq              int,
		 TempCL                 varchar(3),
		 Sheet_id               int,
		 CurrentSpec            nvarchar(3),
		 Action_Comment 		varchar(300),
		 Action 				varchar(100),
		 Cause 					varchar(100),
		 Alarm_Id				int)

CREATE NONCLUSTERED INDEX IDX_VarId_ProdId_ResultOn
ON #All_Variables(Var_Id,Prod_Id,Result_On) ON [PRIMARY]

Create Table #Outdata (
		   Plant		   	    varchar(50),
		   Line			   	    varchar(50),
		   PU_Group		  	    varchar(50),
		   Frequency	 		varchar(25),		
		   Team			   	    varchar(12),
		   Shift		   	    varchar(12),
		   Line_Status			varchar(50),
		   result_on			varchar(50),
		   result		   	    float,
		   ls             		float,
		   lc             		float,
		   lw             		float,
		   target         		float,
		   uw             		float,
		   uc             		float,
		   us             		float,
		   samples              int,
		   defects              int,
		   samples_due		   	int,   
		   future_samples_due	int,
		   tempcl_defects       int,
		   no_samples_taken     varchar(6),
		   product_desc		    varchar(200),
		   master		        int, 
		   var_desc		        varchar (350),		
		   pug_desc		        varchar (150),
		   var_id		        int,	
		   Due_Complete		    int,	
		   Prod_Code		    varchar (150),
		   Next_Start_Date	    datetime,
		   -- 
		   Ext_Info		        varchar(200),
		   TimeStamp		    datetime,
		   Action_Comment 		varchar(300),
		   Action 				varchar(100),
		   Cause 				varchar(100))

CREATE NONCLUSTERED INDEX IDX_VarId_Frequency
ON #OutData(Var_Id,Frequency) ON [PRIMARY]



Create Table #Temp_OutData
		(  Result_on		   		varchar(50),
		   Plant		   			varchar(50),
		   Line			   			varchar(50),
		   Team			   			varchar(12),
		   Shift		   			varchar(12),
		   Line_Status		   		varchar(50),
		   Pug_Desc 		   		varchar(100),
		   Product_Desc		   		varchar(300),
		   Frequency	 	   		varchar(55),		
		   Percent_Compliance	   	float,
		   Percent_Completed       	float,
		   Percent_TempCLCompliance float,		   Samples_Taken           	float,
		   Samples_Due             	float,
		   Defects	           		float,   
		   TempCL_Defects          	float)   

Create Table #Tests
			(RCIDX					INT IDENTITY,
			Var_id 				int,
			Frequency 				nvarchar(50),
			Start_Date 				datetime,
			End_Date 				datetime,
			Result_On 				datetime,
			Result 					nvarchar(50),
			Include_Test 			nvarchar(3),
			Tested					nvarchar(3))

Create Table #RTTTempCLId  (
        PL_Desc						VarChar(100),
        VarId						Int,
        Area						VarChar(4),
        Var_Desc					VarChar(150),
        Start_Time					DateTime,
        Start_Result				VarChar(20),
        Cause						VarChar(150),
        Action						VarChar(150),
        Action_Comment_ID			Int,
        Min_Result					VarChar(20),
        Max_Result					VarChar(20),
        Last_Result_On				DateTime,
        Priority					nvarchar(10))

CREATE TABLE #Var_Specs (
		RCIDX						INT IDENTITY
	   ,VS_Id						INT
       ,Effective_Date				DATETIME
       ,Expiration_Date				DATETIME
       ,Deviation_From				INT
       ,First_Exception				INT
       ,Test_Freq					INT
       ,AS_Id						INT
       ,Comment_Id					INT
       ,Var_Id						INT
       ,Prod_Id						INT
       ,Is_OverRiden				INT		
       ,Is_Deviation				INT
       ,Is_OverRidable				INT
       ,Is_Defined					INT
       ,Is_L_Rejectable				TINYINT
       ,Is_U_Rejectable				TINYINT
       ,L_Warning					VARCHAR(25)
       ,L_Reject					VARCHAR(25)
       ,L_Entry						VARCHAR(25)
       ,U_User						VARCHAR(25)
       ,Target						VARCHAR(25)
       ,L_User						VARCHAR(25)
       ,U_Entry						VARCHAR(25)
       ,U_Reject					VARCHAR(25)
       ,U_Warning					VARCHAR(25)
       ,Esignature_Level			INT
       ,L_Control					VARCHAR(25)
       ,T_Control					VARCHAR(25)
       ,U_Control					VARCHAR(25)
)
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
--new crew schedule table
DECLARE @Crew_Schedule TABLE(
			CS_Id					int
		   ,Start_Time				datetime
		   ,End_Time				datetime
		   ,PU_Id					int
		   ,Comment_Id				int
		   ,Crew_Desc				varchar(10)
		   ,Shift_Desc				varchar(10)
		   ,User_Id					int
)	
Declare @temp_variables_without_samples Table
		   (var_id					int,
			start_date				datetime,
			end_date				datetime,
			result_on				datetime) 

Declare @temp_variables_with_samples Table
		   (var_id					int,
			start_date				datetime,
			end_date				datetime,
			result_on				datetime) 


Declare @OpenAlarms Table (
		key_id 							int,
		Start_Time 						datetime,
		End_Time 						datetime,
		Action_Comment 					varchar(300),
		Action 							varchar(100),
		Cause 							varchar(100),
		InTimeFrame    					int)

Declare @Production_Starts  Table  (
 		Pu_id						int, 
		Prod_id						int, 
		Prod_Code					nvarchar(50), 
		Prod_Desc					nvarchar(200),  
		Start_Time					datetime, 
		End_Time					datetime)

--Declare @Local_Pg_Line_Status Table
--			(Unit_id				int,
--			 start_dateTime			datetime,
--			 end_datetime			datetime,
--			 Phrase_Value			nvarchar(200))

DECLARE	@NonProductive_Detail TABLE (
		Idx							INT IDENTITY(1,1),
		Processed					INT DEFAULT 0,
		PUId						INT,
		StartTime					DATETIME,
		EndTime						DATETIME,
		Reason_Desc					NVARCHAR(100))
			
-----------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------
-- Init temporary tables
declare @r as int

set @r = (select count(*) from #PL_IDs)
set @r = (select count(*) from #Pre_Var_IDs) 
set @r = (select count(*) from #Time_Frames)
set @r = (select count(*) from #All_Variables)
set @r = (select count(*) from #Outdata)
set @r = (select count(*) from #Temp_OutData)
-----------------------------------------------------------------------------------------------------------------

--******************************************************************************
-- Create a temp table of all PL_ID's passed to the sp for processing
-- (parses the string of line id's passed to the sp)
--******************************************************************************

Declare

   @nCounterAll		   	int,
   @Plant_Name		   	varchar(30),
   @StringSQL		   	varchar(750),		
   @strSQL 		   		varchar(4000),
   @strWHERE 		   	varchar(1000),
   @LocalRptLanguage	int,
   @Pass				varchar(20),
   @idx					int --index to fill npt gaps by Unit 

Select @LocalRPTLanguage = Value From dbo.Site_Parameters sp WITH(NOLOCK)
	Join dbo.Parameters p WITH(NOLOCK) On sp.parm_id = p.parm_id
	Where Parm_Name Like 'LanguageNumber'

	-- open and close go to site_parameters table
	Select @Pass = prompt_string From dbo.Language_Data WITH(NOLOCK)
	Where prompt_number = (Select Max(prompt_number) from dbo.language_data where prompt_string = 'PASS')
	and Language_Id = @LocalRPTLanguage
	
	If Len(@Pass) = 0 
		Set @Pass = 'PASS'
		
Print convert(varchar(25), getdate(), 120) + ' Creating #PL_IDs' 

Insert #PL_IDs (RCDID, PL_Desc)
Exec SPCMN_ReportCollectionParsing
@PRMCollectionString = @in_LineDesc, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',	
@PRMDataType01 = 'nVarchar (20)'

If @@Error <> 0
BEGIN
   
   Select 'Error in insert PL_IDs Line 500'
   Return
END 

--******************************************************************************
-- Update the PL_ID, PU_ID and Conv_ID fields within the #PL_IDs table
--******************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Updating #PL_IDs' 

Update #PL_IDs
Set PL_ID = (Select distinct PL_ID from dbo.Prod_Lines_base WITH(NOLOCK) where PL_Desc =#PL_IDs.PL_Desc)

If @@Error <> 0
BEGIN
   
   Select 'Error in Update PL_IDs Line 517'
   Return
END 
PRINT 'Remove units from obsoleted lines'
--FO-02573 Added clause to exclude RTT units under obsoleted lines
Update #PL_IDs
Set PU_ID = (Select distinct PU_ID from dbo.Prod_Units_Base pu with (nolock)
                JOIN dbo.prod_lines_base pl (NOLOCK) ON pl.pl_id = pu.pl_id
                where PU_Desc = #PL_IDs.PL_Desc + ' RTT'
                AND pl.pl_desc NOT LIKE 'Z_OB%') 

If @@Error <> 0
BEGIN
   
   Select 'Error in Update PL_IDs'
   Return
END 



Update #PL_IDs
Set Conv_ID = SUBSTRING(extended_info,6,charindex(';',extended_info)-6)
From #PL_IDs pl	
JOIN  dbo.Prod_Units_Base pu WITH(NOLOCK) ON pl.pl_id = pu.pl_id
WHERE CHARINDEX('STLS=',Extended_Info) > 0
	  AND (CHARINDEX(';',Extended_Info)>CHARINDEX('STLS=',Extended_Info))
	  AND Extended_Info IS NOT NULL
					  
If @@Error <> 0
BEGIN
   
   Select 'Error in Update PL_IDs'
   Return
END 


Update #PL_IDs
Set Conv_ID = SUBSTRING(Extended_Info,6,LEN(Extended_Info)-5)        
From #PL_IDs pl
JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) 	ON pl.pl_id = pu.pl_id
WHERE CHARINDEX('STLS=',extended_info) > 0
AND CHARINDEX(';',extended_info) = 0
AND Extended_Info IS NOT NULL

If @@Error <> 0
BEGIN
   
   Select 'Error in Update PL_IDs'
   Return
END 


Update #PL_IDs
Set	LineStarts = Convert(datetime,SUBString(Extended_Info,CHARINDEX('=',Extended_Info)+1,
					CHARINDEX(';',Extended_Info)-CHARINDEX('=',Extended_Info)-1)) 
From #PL_IDs pl
JOIN dbo.Prod_Lines_Base pl2 WITH(NOLOCK) ON pl2.PL_Id = pl.PL_Id
WHERE CHARINDEX(';',extended_info) > 0
AND CHARINDEX('=',extended_info) > 0

If @@Error <> 0
BEGIN
   
   Select 'Error in Update PL_IDs'
   Return
END 

PRINT convert(varchar(25), getdate(), 120) + 'END of PL_Ids table data process'

-- Select * from #PL_IDs
---------------------------------------------------------------------------------------------------------------------
-- Format properly the time frames for SHIFTLY report
---------------------------------------------------------------------------------------------------------------------
If @in_TimeOption = '10001'
    Select @in_StartTime = Start_Time From Crew_Schedule cs WITH(NOLOCK)
                        Join #PL_IDs pl on cs.pu_id = pl.Conv_ID 
                        Where @in_EndTime between Start_Time and End_Time
---------------------------------------------------------------------------------------------------------------------

if @in_LineStatus = 'All'
Insert #PLStatusDESCList (PLStatusDESC)
		Select distinct Event_Reason_Name
		FROM dbo.Event_Reasons r (NOLOCK)
		JOIN dbo.Event_Reason_Tree_Data d (NOLOCK) ON r.Event_Reason_Id = d.Event_Reason_Id
		JOIN dbo.Event_Reason_Tree t (NOLOCK) ON d.Tree_Name_Id = t.Tree_Name_Id
		WHERE t.Tree_Name = 'Non-Productive Time'

		-- From dbo.Event_Reasons PH WITH(NOLOCK)
		-- Join dbo.Data_Type DT WITH(NOLOCK) on PH.Data_Type_ID = DT.Data_Type_ID
		-- where DT.Data_Type_DESC = 'Line Status'

        If @@Error <> 0
		BEGIN
		   
		   Select 'Error in Insert @in_LineStatus'
		   Return
		END 
 
Else
Insert #PLStatusDescList (RCDID,PLStatusDESC)
	Exec SPCMN_ReportCollectionParsing
	@PRMCollectionString = @in_LineStatus, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',
	@PRMDataType01 = 'varchar(50)'

    If @@Error <> 0
		BEGIN
		   
		   Select 'Error in Insert #PLStatusDescList'
		   Return
		END  

-- *****************************************************************************************
-- JMerino : Standarizing NPT Phrases for possible mismatch on #PLStatusDescList
-- *****************************************************************************************

UPDATE PLSDL
	SET PLStatusDesc = CASE
						WHEN SUBSTRING(PLStatusDesc, CHARINDEX(':',PLStatusDesc)+1, 1) = ' ' --IF Blank Space exist
						THEN PLStatusDesc --Leave it like that
						ELSE LEFT(PLStatusDesc, CHARINDEX(':',PLStatusDesc)) + ' ' + RIGHT(PLStatusDesc, LEN(PLStatusDesc) - CHARINDEX(':',PLStatusDesc)) --Else add it
					   END
FROM #PLStatusDescList PLSDL
--******************************************************************************
--  Get the Plant Name
--******************************************************************************
Set @Plant_Name = (Select Value From dbo.Site_Parameters WITH(NOLOCK) Where Parm_ID = 12)

If @Plant_Name = ''
BEGIN
	Set @Plant_Name = 'Plant Name Unavailable, Please config your site parameters'
END
-- *****************************************************************************************
-- FRio : Build temp tables to allocate Variables to be processed
-- *****************************************************************************************
-- 
-- Insert into #Pre_Var_IDs(PU_Id,pug_id,PUG_Desc,Var_ID,Var_Desc, Extended_Info,Var_Type,Frequency) --,Start_Time,Next_Start_Time)

Print convert(varchar(25), getdate(), 120) + 'START #PRE_VAR_IDS SETTINGS '

set @strWHERE = ''
if @in_ReportType = 'Recipe'
  set @strWHERE = ' And pug.PUG_DESC LIKE ''' + '%Recipe' + ''''
if @in_ReportType = 'NonRecipe'
  set @strWHERE = ' And (pug.PUG_DESC LIKE ''' + '%Recipe Dynamic%' + '''  OR pug.PUG_DESC NOT LIKE ''' + '%Recipe' + ''' )' -- JJR TESTING; Do not include 'Recipe' vars
if @in_ReportType NOT IN ('NonRecipe', 'Recipe')
  set @strWHERE = ''

Insert into #Pre_Var_IDs(PU_Id,Var_ID,Sheet_id) 
Select tpids.Pu_Id,sv.Var_Id,Max(s.Sheet_Id)
From dbo.Sheet_variables sv WITH(NOLOCK)
Join dbo.Sheets s WITH(NOLOCK) On s.Sheet_Id = sv.Sheet_Id
-- Join dbo.Sheet_Groups sg WITH(NOLOCK) On s.Sheet_Group_id = sg.sheet_group_id
Join #PL_Ids tpids On  s.sheet_desc Like '%' + tpids.pl_desc + '%'
Where 	s.Sheet_Desc Like '%RTT%' 
		and s.Sheet_Desc Not Like '%RTT Alarms%' 
		and s.Is_Active = 1	
Group By tpids.Pu_Id,sv.Var_Id	

If @@Error <> 0
BEGIN
   
   Select 'Error in Insert Pre_Var_Ids'
   Return
END 


Set @strSQL = ' Update #Pre_Var_IDs ' +
		' Set Pug_Id 		  = pug.PUG_Id, ' +
		' 	  Pug_Desc 	      = pug.Pug_Desc, ' +
		' 	  Var_Desc 	      = v.Var_Desc, ' +
		'	  Extended_Info   = v.Extended_Info, ' +
		'     Data_Type_Id    = v.Data_Type_Id,  ' +
		--'	Var_Type 	  = (CASE ' +
		--						' WHEN dt.data_type_desc LIKE ''' + '%PassFail%' + ''' THEN ''' +' ATTRIBUTE'+ '''' +
		--						' ELSE ''' + 'VARIABLE' + '''' +
		--					' END), ' +	
		'	Frequency	  = (CASE' +
								' WHEN v.Extended_Info LIKE ''' + '%PAS%' + ''' THEN ''' + 'a) Shiftly Manual' + '''' +
								' WHEN v.Extended_Info LIKE ''' + '%PAD%' + ''' THEN ''' + 'c) Daily' + '''' +
								' WHEN v.Extended_Info LIKE ''' + '%PAW%' + ''' THEN ''' + 'd) Weekly' + '''' +
								' WHEN v.Extended_Info LIKE ''' + '%PAM%' + ''' THEN ''' + 'e) Monthly' + '''' +
								' WHEN v.Extended_Info LIKE ''' + '%PAQ%' + ''' THEN ''' + 'f) Quarterly' + '''' +
							' END) ' +	
' From  dbo.Variables_Base v WITH(NOLOCK)  ' +
' Join #Pre_Var_IDs pvids on v.var_id = pvids.var_id' +
-- ' Join dbo.Data_Type dt WITH(NOLOCK) on v.Data_Type_ID = dt.Data_Type_ID ' +
' Join dbo.PU_Groups pug WITH(NOLOCK) On v.pug_id = pug.pug_id ' +
' Where ' +
				' pug.PUG_DESC NOT LIKE ''' + '%Process Audit Variables%' + '''' +
				' AND pug.PUG_DESC NOT LIKE ''' + '%System%' + '''' +
				' AND pug.PUG_DESC NOT LIKE ''' + '%Utility%' + '''' + 
				-- ' AND v.extended_info NOT like(''' + '%RPT=N%' + ''')' +  
				' AND v.extended_info like(''' + '%PA%' + ''')' + 		
				-- ' AND dt.data_type_desc IN (''' + 'Float' + ''','''+ 'Integer'+''')' +		
				' AND v.var_desc NOT LIKE ''' + '%zpv%' + '''' +
				' AND v.var_desc NOT LIKE ''' + '%z_obs%' + ''''

Exec (@StrSQL + @StrWHERE)

If @@Error <> 0
BEGIN
   
   Select 'Error in Update Pre_Var_Ids'
   Return
END 


Update #Pre_Var_Ids
		Set Var_Type 	  = (CASE 
								 WHEN dt.data_type_desc LIKE '%PassFail%' THEN 'ATTRIBUTE'
								 ELSE 'VARIABLE'
							 END)
From #Pre_Var_ids pvids
Join dbo.Data_Type dt WITH(NOLOCK) on pvids.Data_Type_ID = dt.Data_Type_ID 
Where dt.data_type_desc IN ('Float','Integer') Or dt.data_type_desc Like '%PassFail%'

If @@Error <> 0
BEGIN
   
   Select 'Error in Update Pre_Var_Ids'
   Return
END 


Delete From #Pre_Var_Ids 
Where (Var_Desc Is NULL) Or (Var_Type Not In ('ATTRIBUTE','VARIABLE')) OR (Extended_Info LIKE '%RPT=N%' )


If @@Error <> 0
BEGIN
   
   Select 'Error in Delete Pre_Var_Ids'
   Return
END 

-- Print @strSQL + @strWHERE

-- Insert into #Pre_Var_IDs(PU_Id,pug_id,PUG_Desc,Var_ID,Var_Desc, Extended_Info,Var_Type,Frequency) 
-- Exec (@strSQL + @strWHERE)

-- Update the 'Frequency Categories' for Shiftly Auto Variables
-- Update only if Report Type = 'NonRecipe' 

UPDATE #Pre_Var_IDs
	Set FREQUENCY = 'b) Shiftly Auto'
WHERE FREQUENCY COLLATE database_default = 'a) Shiftly Manual' AND (PUG_DESC LIKE '%Auto%' OR PUG_DESC LIKE '%Recipe Dynamic%')

If @@Error <> 0
BEGIN
   
   Select 'Error in Update Pre_Var_Ids'
   Return
END 


-- Add all 'Recipe' and 'Recipe Dynamic' variables to a seperate grouping
-- If ReportType = 'Recipe'?

if @in_ReportType = 'Recipe' or @in_ReportType = 'All'
begin
	INSERT INTO #Pre_Var_IDs
	Select PU_Id, pug_id,PUG_Desc, Var_ID,Var_Desc, Extended_Info,
	'VARIABLE', 				
	'h) Recipe',
    0,
	NULL
	from #Pre_Var_IDs 
	where PUG_Desc LIKE '%Recipe'

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Pre_Var_Ids if Report Type Recipe or All'
	   Return
	END 
 

	DELETE From #Pre_Var_IDs
	Where Frequency = 'a) Shiftly Manual'
	And PUG_Desc LIKE '%Recipe'

	If @@Error <> 0
	BEGIN
		
		Select 'Error in Delete Pre_Var_Ids if Report Type Recipe or All'
		Return
	END 

end

if @in_ReportType = 'NonRecipe'
begin
	INSERT INTO #Pre_Var_IDs
	Select PU_Id, pug_id,PUG_Desc, Var_ID,Var_Desc, Extended_Info,
	'VARIABLE',
	'b) Shiftly Auto',
    0,
	NULL
	from #Pre_Var_IDs 
	where PUG_Desc LIKE '%Recipe Dynamic%'

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Pre_Var_Ids if Report Type NonRecipe'
	   Return
	END 
end

Update #Pre_Var_ids
	SET PUG_Desc = Substring(Pug_Desc, CharIndex('EA', Pug_Desc), (CharIndex(' ', Pug_Desc, CharIndex('EA', Pug_Desc)) - CharIndex('EA', Pug_Desc)))
	WHERE CharIndex('EA',Pug_Desc) > 0

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Pre_Var_Ids'
	   Return
	END 

Print convert(varchar(25), getdate(), 120) + 'END #PRE_VAR_IDS SETTINGS ' 
-- *****************************************************************************************
-- FRio : End of #Var_IDs Table
-- *****************************************************************************************
-- Select * From #Pre_Var_IDs Where Frequency Like '%Daily%'
-- Select 'Pre Var Ids - > ',* from #Pre_Var_Ids where frequency like '%Weekly%' and pug_desc like '%EA2%'
-- *****************************************************************************************
-- FRio : Building #Time_Frames Table
-- *****************************************************************************************
Print convert(varchar(25), getdate(), 120) + 'GET TIME FRAMES ' 
-- FRio : Get the interval for shift lenght
Declare 	@ShiftLength int

Select @ShiftLength = sp.Value / 60
From dbo.Site_Parameters sp WITH(NOLOCK)
JOIN dbo.Parameters p WITH(NOLOCK) on sp.Parm_ID = p.Parm_ID
Where P.Parm_Name = 'ShiftInterval'

If @ShiftLength Is Null
BEGIN
Select @ShiftLength = 12
END
-- End getting the interval 
-- Create #Time_Frame temp table

insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time)
select pl.pl_id,pl.pl_desc,'a) Shiftly Manual',start_time,end_time from dbo.Crew_schedule cs WITH(NOLOCK)
join #PL_IDs pl on cs.pu_id = pl.Conv_id
where  start_time >= @in_StartTime and start_time < @in_EndTime 

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Shiftly Manual'
	   Return
	END 

insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time)
select pl.pl_id,pl.pl_desc,'b) Shiftly Auto',start_time,end_time from dbo.Crew_schedule cs WITH(NOLOCK)
join #PL_IDs pl on cs.pu_id = pl.Conv_id
where start_time >= @in_StartTime and start_time < @in_EndTime 

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Shiftly Auto'
	   Return
	END 

insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time)
select pl.PL_Id,pl.PL_Desc,'c) Daily',@in_StartTime,dateadd(dd,1,@in_StartTime)
From #PL_Ids plids 
Join dbo.Prod_Lines_Base pl WITH(NOLOCK) on plids.PL_id = pl.pl_id

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Shiftly Daily'
	   Return
	END 


if @in_ReportType = 'Recipe' or @in_ReportType = 'All'
begin
    insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time)
    select pl.pl_id,pl.pl_desc,'h) Recipe',start_time,end_time from dbo.Crew_schedule cs WITH(NOLOCK)
    join #PL_IDs pl on cs.pu_id = pl.Conv_id
    where start_time >= @in_StartTime and start_time < @in_EndTime 

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Recipe'
	   Return
	END 
 
end 

-- FRio : for Weekly time frames start inserting values from Local_PG_Schedule_Display

insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time,day_period)
select pl.PL_Id,sheet_group_desc,'d) Weekly',Min(LastTime),Min(NextTime),Max(day_period)
from dbo.local_pg_schedule_display lpsd WITH(NOLOCK)
Join #PL_Ids pl On lpsd.sheet_group_desc COLLATE database_default = pl.pl_desc
where sheet_group_desc COLLATE database_default IN (select PL_Desc from #PL_IDs) and type like '%weekly%'
group by pl.PL_Id,sheet_group_desc

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Weekly'
	   Return
	END 


-- FRio : for Monthly time frames start inserting values from Local_PG_Schedule_Display
Insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time,day_period)
Select pl.PL_Id,sheet_group_desc,'e) Monthly',Max(LastTime),Max(NextTime),Max(day_period)
From dbo.local_pg_schedule_display lpsd WITH(NOLOCK)
Join #PL_Ids pl On lpsd.sheet_group_desc COLLATE database_default = pl.pl_desc
Where Sheet_group_desc COLLATE database_default IN (select PL_Desc from #PL_IDs) and type like '%monthly%'
Group By pl.PL_Id,sheet_group_desc


    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Monthly'
	   Return
	END 

-- FRio : for Quarterly time frames start inserting values from Local_PG_Schedule_Display

insert into #Time_Frames (PL_ID,PU_Desc,frequency,start_time,end_time,day_period)
select pl.PL_Id,sheet_group_desc,'f) Quarterly',Max(LastTime),Max(NextTime),Max(day_period)
from dbo.local_pg_schedule_display lpsd WITH(NOLOCK)
Join #PL_Ids pl On lpsd.sheet_group_desc COLLATE database_default = pl.pl_desc
where sheet_group_desc COLLATE database_default IN (select PL_Desc from #PL_IDs) and type like '%quarterly%'
group by pl.PL_Id,sheet_group_desc

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Quarterly'
	   Return
	END 


-- Set accurate Start_Time and End_Time
declare @day_period as int
declare @BackDate_Date as datetime
declare @PU_Desc as nvarchar(50)
declare @PL_Id as int
declare @Max_Start_Time as datetime
declare @Frequency as nvarchar(50)
declare @Projected_Max_Start_Time as datetime
declare @Interval_EndDate as datetime
declare @Next_Projected_Max_Start_Time as datetime

-- FRio : Declare Cursor if Multiple Line selection
PRINT convert(varchar(25), getdate(), 120) + 'CURSOR START'
--DECLARE PL_Ids_Cursor CURSOR FOR 
--SELECT PL_Id,PL_Desc FROM #PL_IDs

--OPEN PL_IDs_Cursor

--FETCH NEXT FROM PL_IDs_Cursor INTO @Pl_id,@PU_Desc

--WHILE @@FETCH_STATUS = 0
DECLARE @i INT, @j INT

SELECT @i = COUNT(*) FROM #PL_IDs
SET @j = 1
WHILE @j <= @i
BEGIN
SELECT @pl_id = PL_Id, @PU_Desc = PL_Desc FROM #PL_IDs WHERE RCDID = @j
-- FRio : 1st STEP : set accurate start_times from @in_StartTime
-- While Loop for detecting first day of week from day_period and @in_StartTime
select @day_period = day_period from #Time_Frames where Frequency like '%Weekly%' and PU_Desc = @PU_Desc
select @BackDate_Date = start_time from #Time_Frames where Frequency like '%Weekly%' and PU_Desc = @PU_Desc

while @BackDate_Date > @in_StartTime
	begin
		set @BackDate_Date =  DateAdd (dd, -7, @BackDate_Date)
	end

update #Time_Frames
  set Start_Time = @BackDate_Date,
	End_Time = dateadd(ww,1,@BackDate_Date)
where frequency like '%weekly%' and PU_Desc = @PU_Desc

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame Weekly'
	   Return
	END 


-- While loop for backdating monthly variables
select @BackDate_Date = Start_Time from #Time_Frames where Frequency like '%monthly%' and PU_Desc = @PU_Desc
if @BackDate_Date > @in_StartTime
begin
	while @BackDate_Date > @in_StartTime 		begin
			set @BackDate_Date =  DateAdd (m, -1, @BackDate_Date)
		end
end
update #Time_Frames
  set Start_Time = @BackDate_Date,
	End_Time = dateadd(m,1,@BackDate_Date)
where frequency like '%monthly%' and PU_Desc = @PU_Desc

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame Monthly'
	   Return
	END 


-- While loop for backdating quarterly variables
select @BackDate_Date = Start_Time from #Time_Frames where Frequency like '%quarterly%' and PU_Desc = @PU_Desc
if @BackDate_Date > @in_StartTime
begin
	while @BackDate_Date > @in_StartTime
		begin
			set @BackDate_Date =  DateAdd (m, -3, @BackDate_Date)
		end
end
update #Time_Frames
  set Start_Time = @BackDate_Date,
	End_Time = dateadd(m,3,@BackDate_Date)
where frequency like '%quarterly%' and PU_Desc = @PU_Desc

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame Quarterly'
	   Return
	END 


-- FRio : Daily Time Frames
select @Projected_Max_Start_Time = dateadd (dd, 1, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'c' and PU_Desc = @PU_Desc -- Daily
select @Interval_EndDate = @in_EndTime -- Daily
select @Next_Projected_Max_Start_Time = dateadd (dd, 2, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'c' and PU_Desc = @PU_Desc-- Daily

while @Projected_Max_Start_Time < @Interval_EndDate 
begin
	insert into #Time_Frames (PL_Id,PU_Desc,frequency,start_time,end_time)
	select @PL_id,@PU_Desc,'c) Daily',@Projected_Max_Start_Time,@Next_Projected_Max_Start_Time
	
	set @Max_Start_Time = @Projected_Max_Start_Time
	set @Projected_Max_Start_Time = dateadd (d, 1, @Max_Start_Time) 
	set @Next_Projected_Max_Start_Time = dateadd(d, 1, @Projected_Max_Start_Time) -- Daily    
end

-- FRio : Weekly Time Frames
select @Projected_Max_Start_Time = dateadd (wk, 1, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'd' and PU_Desc = @PU_Desc-- Weekly
select @Interval_EndDate = @in_EndTime +( 7 - datepart(dw,@in_EndTime)) -- Weekly
select @Next_Projected_Max_Start_Time = dateadd(wk, 2, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'd' and PU_Desc = @PU_Desc-- Weekly
select @day_period = day_period from #Time_frames where LEFT(Frequency,1)= 'd' and PU_Desc = @PU_Desc-- Weekly

while @Projected_Max_Start_Time < @Interval_EndDate 
begin
	insert into #Time_Frames (PL_id,PU_Desc,frequency,start_time,end_time,day_period)
	select @PL_id,@PU_Desc,'d) Weekly',@Projected_Max_Start_Time,@Next_Projected_Max_Start_Time ,@day_period

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Weekly'
	   Return
	END 

	set @Max_Start_Time = @Projected_Max_Start_Time
	set @Projected_Max_Start_Time = dateadd (wk, 1, @Max_Start_Time)
	set @Next_Projected_Max_Start_Time = dateadd (wk, 1, @Projected_Max_Start_Time) -- Weekly   
end
-- FRio : Just in case delete all time frames where Start_Date > @in_EndTime
Delete from #Time_Frames where start_time > @in_EndTime and frequency like '%weekly%' and PU_Desc = @PU_Desc 

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete Time_Frame Weekly'
	   Return
	END 


-- @isMonthlyBased logic
-- Also must include logic to delete time frames where End_Date not in current month if @isMonthlyBased
If @isMonthlyBased = 'Yes'
	Delete from #Time_Frames 
	where End_Time > @in_EndTime and Frequency like '%weekly%' and PU_Desc = @PU_Desc 

   If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete Time_Frame Weekly for Monthly Report'
	   Return
	END 

-- ****
-- FRio : Monthly Time Frames
-- Select * from #Time_Frames -- where frequency like '%Monthly%'

select @Projected_Max_Start_Time = dateadd (m, 1, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'e' and PU_Desc = @PU_Desc-- Monthly
select @Interval_EndDate = dateadd(dd, -day(dateadd(mm,1, @in_EndTime)),dateadd(mm,1, @in_EndTime)) -- Monthly
select @Next_Projected_Max_Start_Time = dateadd (m, 2, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'e' and PU_Desc = @PU_Desc-- Monthly
select @day_period = day_period from #Time_frames where LEFT(Frequency,1)= 'e'-- Monthly

while @Projected_Max_Start_Time < @Interval_EndDate 
begin
	insert into #Time_Frames (Pl_id,PU_Desc,frequency,start_time,end_time,day_period)
	select @PL_Id,@PU_Desc,'e) Monthly',@Projected_Max_Start_Time,@Next_Projected_Max_Start_Time ,@day_period

   If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Monthly'
	   Return
	END 
   
	
	set @Max_Start_Time = @Projected_Max_Start_Time
	set @Projected_Max_Start_Time = dateadd (m, 1, @Max_Start_Time)
	set @Next_Projected_Max_Start_Time = dateadd (m, 1, @Projected_Max_Start_Time) -- Monthly
end
-- FRio : Just in case delete all time frames where Start_Date > @in_EndTime
-- Select @Max_Start_Time 
-- Select @Projected_Max_Start_Time 
-- Select @Next_Projected_Max_Start_Time 


Delete from #Time_Frames 
where (start_time > @in_EndTime or start_time = end_time) and frequency like '%monthly%' and PU_Desc = @PU_Desc 

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete Time_Frame Monthly'
	   Return
	END 

-- Select @Max_Start_Time,* from #Time_Frames where frequency like '%monthly%'
If @Max_Start_Time < @in_EndTime
        Set @Max_Start_Time = dateadd(m,1,@Max_Start_Time)

If @isMonthlyBased = 'Yes'
Begin
   
   If @in_TimeOption = '29'
   Begin

	 Delete From #Time_Frames 
	 Where End_Time = dateadd(m,-1,@Max_Start_Time) and Frequency like '%monthly%' and PU_Desc = @PU_Desc 	

   If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete Time_Frame Monthly'
	   Return
	END 

         Update #Time_Frames
                Set End_Time = @in_EndTime
         Where @in_EndTime > End_time and Frequency like '%monthly%' and PU_Desc = @PU_Desc 	

            If @@Error <> 0

 	BEGIN
	   
	   Select 'Error in Insert Time_Frame monthly'
	   Return
	END 


   End

   If @in_TimeOption like '25'
   Begin
	
	 Delete From #Time_Frames 
         Where Not (@in_EndTime between Start_Time and End_Time) and Frequency like '%monthly%' and PU_Desc = @PU_Desc 

        If @@Error <> 0

	BEGIN
	   
	   Select 'Error in Insert Time_Frame monthly'
	   Return
	END 
   End
End


-- FRio : Quarterly Time Frames
select @Projected_Max_Start_Time = dateadd(dd, -day(dateadd(mm,2, @in_EndTime)),dateadd(mm,2, @in_EndTime)) from #Time_frames where LEFT(Frequency,1)= 'f' and PU_Desc = @PU_Desc -- Quarterly
select @Interval_EndDate = dateadd(dd, -day(dateadd(mm,2, @in_EndTime)),dateadd(mm,2, @in_EndTime)) from #Time_frames where LEFT(Frequency,1)= 'f'  -- Quarterly
select @Next_Projected_Max_Start_Time = dateadd (m, 6, Start_Time) from #Time_frames where LEFT(Frequency,1)= 'f' and PU_Desc = @PU_Desc -- Quarterly
select @day_period = day_period from #Time_frames where LEFT(Frequency,1)= 'f' and PU_Desc = @PU_Desc -- Quarterly

While @Projected_Max_Start_Time < @Interval_EndDate 
Begin
	Insert into #Time_Frames (PL_Id,PU_Desc,frequency,start_time,end_time,day_period)
	Select @PL_id,@PU_Desc,'f) Quarterly',@Projected_Max_Start_Time,@Next_Projected_Max_Start_Time ,@day_period

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert Time_Frame Quarterly'
	   Return
	END 
  
	
	Set @Max_Start_Time = @Projected_Max_Start_Time
	set @Projected_Max_Start_Time = dateadd (m, 3, @Max_Start_Time)
	set @Next_Projected_Max_Start_Time = dateadd (m, 3, @Projected_Max_Start_Time) -- Quarterly
end

SET @j = @j + 1
--FETCH NEXT FROM PL_IDs_Cursor INTO @Pl_id,@PU_Desc
END -- Cursor PL_IDs_Cursor

--CLOSE PL_IDs_Cursor
--DEALLOCATE PL_IDs_Cursor
PRINT convert(varchar(25), getdate(), 120) + 'CURSOR END'
-- Update PU_Id field
Update #Time_Frames
	Set PU_Id = pl.PU_Id
From #Time_frames tf inner join #PL_IDs pl on tf.PU_Desc = pl.PL_Desc

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame'
	   Return
	END 

-- *****************************************************************************************
-- FRio : End Building #Time_Frames Table
-- *****************************************************************************************
Update #Time_Frames
	set End_Time = @in_EndTime
Where End_Time > @in_EndTime

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame'
	   Return
	END 


Delete from #Time_Frames where End_Time = Start_Time

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete Time_Frame where End_Time = Start_Time'
	   Return
	END 


-- *****************************************************************************************
-- BUILD NPT TABLE
-- *****************************************************************************************
DECLARE	@CurIdx				INT,
		@LastIdx			INT,
		@NextStartTime		DATETIME,
		@LastEndTime		DATETIME,
		@LineNormalDesc		VARCHAR(20) = 'PR In: Line Normal',
		@minTimeFrame		DATETIME,
		@maxTimeFrame		DATETIME
IF (SELECT COUNT(Event_Reason_Id) FROM dbo.Event_Reasons WITH (NOLOCK) WHERE Event_Reason_Name = @LineNormalDesc) < 1
BEGIN
    SET @LineNormalDesc = 'PR In:Line Normal'
END

SELECT 
		@minTimeFrame	= (CASE 
								WHEN MIN(Start_Time) < @in_StartTime 
									THEN MIN(Start_Time) 
								ELSE @in_StartTime
							END),
		@maxTimeFrame	= (CASE 
								WHEN MAX(End_Time) > @in_EndTime 
									THEN MAX(End_Time) 
								ELSE @in_EndTime 
							END)
	FROM #Time_Frames

INSERT INTO @NonProductive_Detail(
				PUId,
				StartTime,
				EndTime,
				Reason_Desc
				)
	SELECT 
				Conv_Id,
				/*Ensure the start time and end time of the record is not bigger than the report scope.*/
				(CASE 
					WHEN @minTimeFrame > npt.Start_Time
						THEN @minTimeFrame
					ELSE
						npt.Start_Time
					END),
				(CASE
					WHEN @maxTimeFrame < npt.End_Time
						THEN @maxTimeFrame
					ELSE
						npt.End_Time
					END),
				/*Ensure the start time and end time of the record is not bigger than the report scope.*/
				r.Event_Reason_Name
	FROM		#PL_IDs						l
	JOIN		dbo.NonProductive_Detail	npt		WITH (NOLOCK) ON l.Conv_Id = npt.PU_Id AND ((npt.Start_Time < @minTimeFrame AND npt.End_Time > @minTimeFrame AND npt.End_Time < @maxTimeFrame) OR (npt.Start_Time >= @minTimeFrame AND npt.End_Time <= @maxTimeFrame) OR (npt.Start_Time < @maxTimeFrame AND npt.Start_Time > @minTimeFrame AND npt.End_Time > @maxTimeFrame) OR (npt.start_time < @minTimeFrame AND npt.End_Time > @maxTimeFrame))
	JOIN		dbo.Event_Reasons			r		WITH (NOLOCk) ON npt.Reason_Level1 = r.Event_Reason_Id

--********************************************************************
-- LOOP INSERTING PR IN TO FILL ANY TIMEGAP BY UNIT
--********************************************************************
--set index for units to 1
SET @idx = 1
WHILE @idx <= (SELECT COUNT(RCDID) FROM #PL_IDs)
BEGIN

	SELECT 
		@minTimeFrame	= (CASE 
								WHEN MIN(Start_Time) < @in_StartTime 
									THEN MIN(Start_Time) 
								ELSE @in_StartTime
							END),
		@maxTimeFrame	= (CASE 
								WHEN MAX(End_Time) > @in_EndTime 
									THEN MAX(End_Time) 
								ELSE @in_EndTime 
							END)
	FROM #Time_Frames
	WHERE PU_Id = (select PU_Id FROM #PL_IDs WHERE RCDID = @idx)

	IF(SELECT COUNT(*) FROM @NonProductive_Detail where PUID = (select Conv_Id FROM #PL_IDs WHERE RCDID = @idx)) = 0
	BEGIN


	INSERT INTO @NonProductive_Detail(
					PUId,
					StartTime,
					EndTime,
					Reason_Desc,
					Processed
					)
		SELECT
					Conv_Id,
					@minTimeFrame,
					@maxTimeFrame,
					@LineNormalDesc,
					1
		FROM	#PL_IDs
		END
	
	WHILE (SELECT COUNT(Processed) FROM @NonProductive_Detail WHERE Processed = 0 AND PUID = (select Conv_Id FROM #PL_IDs WHERE RCDID = @idx)) > 0 
	BEGIN
	
		SELECT TOP 1 
				@CurIdx		= nd.Idx
			FROM @NonProductive_Detail nd
			JOIN #PL_IDs pl ON nd.PUId = pl.Conv_ID
						   AND RCDID = @idx
			WHERE nd.Processed = 0
			ORDER BY StartTime ASC

	
		SELECT	
				@LastEndTime = EndTime
			FROM	@NonProductive_Detail nd
			JOIN #PL_IDs pl ON nd.PUId = pl.Conv_ID
						   AND RCDID = @idx
			WHERE	Idx = @LastIdx

	  IF @LastEndTime IS NULL
			BEGIN
				SET @LastEndTime = @minTimeFrame
			END


		IF @NextStartTime IS NULL
			BEGIN
				SET @NextStartTime = @maxTimeFrame
			END

		SELECT			@NextStartTime = nd.StartTime
			FROM	@NonProductive_Detail nd
			JOIN #PL_IDs pl ON nd.PUId = pl.Conv_ID
						   AND RCDID = @idx
			WHERE	Idx = @CurIdx

		INSERT INTO @NonProductive_Detail(
						PUId,
						StartTime,
						EndTime,
						Reason_Desc,
						Processed
						)
			SELECT
						Conv_Id,
						@LastEndTime,
						@NextStartTime,
						@LineNormalDesc,
						1
			FROM	#PL_IDs
			WHERE RCDID = @idx

		UPDATE	n
			SET		Processed = 1
			FROM	@NonProductive_Detail n
			WHERE	Idx = @CurIdx

		SET @LastIdx = @CurIdx
		
	END

	
	--********************************************************************
	-- ENSURE IT HAS A LINE STATUS TO THE END OF SCOPE
	--********************************************************************
	IF(SELECT MAX(EndTime) FROM @NonProductive_Detail WHERE PUId = (select Conv_Id FROM #PL_IDs WHERE RCDID = @idx)) <> @maxTimeFrame
	BEGIN
		SELECT	@LastEndTime	= MAX(EndTime),
				@NextStartTIme	= @maxTimeFrame
		FROM @NonProductive_Detail
		WHERE PUId = (select Conv_Id FROM #PL_IDs WHERE RCDID = @idx)

		INSERT INTO @NonProductive_Detail(
						PUId,
						StartTime,
						EndTime,
						Reason_Desc,
						Processed
						)
			SELECT
						Conv_Id,
						@LastEndTime,
						@NextStartTime,
						@LineNormalDesc,
						1
			FROM	#PL_IDs
			WHERE RCDID = @idx
	END

	SET @LastIdx = NULL
	SET @LastEndTime = NULL
	SET @NextStartTime = NULL
	SET @idx = @idx + 1

END

--DELETE records that has equal starttime and endtime
	DELETE FROM @NonProductive_Detail WHERE StartTime = EndTime
-- *****************************************************************************************
-- JMerino : Standarizing NPT Phrases for possible mismatch on @NonProductive_Detail
-- *****************************************************************************************

UPDATE N
	SET Reason_Desc = CASE
						WHEN SUBSTRING(Reason_Desc, CHARINDEX(':',Reason_Desc)+1, 1) = ' ' --IF Blank Space exist
						THEN Reason_Desc --Leave it like that
						ELSE LEFT(Reason_Desc, CHARINDEX(':',Reason_Desc)) + ' ' + RIGHT(Reason_Desc, LEN(Reason_Desc) - CHARINDEX(':',Reason_Desc)) --Else add it
					  END
FROM @NonProductive_Detail N

-- *****************************************************************************************
-- FRio : Building Line_Status on #Time_Frames table
-- *****************************************************************************************

Update #Time_Frames	
		
		Set Phrase_Value = npt.Reason_Desc, Include = 'No'

	From #Time_Frames tf

	Join #PL_IDs pl on tf.pl_id = pl.pl_id

	JOIN @NonProductive_Detail npt
					 ON pl.Conv_Id = npt.PUId
					AND tf.Start_Time >= npt.StartTime
					AND (tf.Start_Time < npt.EndTime)
	Where npt.Reason_Desc IN (Select PLStatusDesc From #PLStatusDescList )
	
    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame'
	   Return
	END 


Update #Time_Frames
	Set Include = 'Yes'
From #Time_Frames tf
Join #PL_IDs pl on tf.PL_Id = pl.pl_id
Where phrase_value IN (Select PLStatusDesc From #PLStatusDescList )
Or Start_Time < LineStarts

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame'
	   Return
	END 


Update #Time_Frames
	Set	Start_Date = Start_Time,
		End_Date		= End_Time,
		Due_Date   = Start_Time,
		Next_Start_Date = End_Time
From #Time_Frames tf

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame'
	   Return
	END 


Update #Time_Frames Set 
        Next_Start_Date = (Select End_time From Crew_Schedule WITH(NOLOCK) Where Start_time = tf.Start_Date and pu_id = pl.conv_id ),
    	End_Date = (Select End_time From Crew_Schedule WITH(NOLOCK) Where Start_time = tf.Start_Date and pu_id = pl.conv_id )
From #Time_Frames tf
Join #PL_ids pl on tf.pl_id = pl.pl_id
Where tf.Frequency = 'a) Shiftly Manual' Or tf.Frequency = 'b) Shiftly Auto'

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame'
	   Return
	END 


If @in_TimeOption = '10001'
Begin
   Update #Time_Frames Set 
      Start_Date = (case when Start_Date > @in_StartTime then dateadd(dd,-1,Start_Date) else Start_Date end)    
   Where Frequency = 'c) Daily'
       If @@Error <> 0

	BEGIN
	   
	   Select 'Error in Update Time_Frame for TimeOption 10001'
	   Return
	END 


End

Update #Time_Frames
  Set Next_Start_Date = (case Frequency 
	 when 'e) Monthly' then 
	     dateadd(mm,1,due_date)
	 when 'f) Quarterly' then
	     dateadd (mm,3,due_date)
	 end)
Where Frequency = 'e) Monthly' or Frequency = 'f) Quarterly' 

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame for Month and Quarter'
	   Return
	END 

Update #Time_Frames
  Set End_Date = (Case when dateadd(dd,7,Start_Date)>@in_EndTime Then @in_Endtime Else dateadd(dd,7,Start_Date) End),
      Next_Start_Date =  dateadd(dd,7,Due_Date)	 
Where Frequency = 'd) Weekly'

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame Weekly'
	   Return
	END 


Update #Time_Frames 
	Set 
        End_Date = (case when dateadd(dd,1,Start_Date) > @in_EndTime then @in_EndTime else dateadd(dd,1,Start_Date) end), 
        Due_Date = Start_Date, 
        Next_Start_Date = dateadd(dd,1,Start_Date)
Where Frequency = 'c) Daily'

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update Time_Frame Daily'
	   Return
	END 



-- Delete  from #Time_Frames Where Include = 'No' or Include Is NULL


Print  Convert(varchar,getdate(),120) + ' END GET TIME FRAMES '  --**************************************************************************************************
-- Build a Time_Frames Lookup tables
-- Select pl_id,pu_id,pu_desc,frequency,min(start_time) as min_start_time, max(end_time) as max_end_time
-- Into #Time_Frame_LookUp
-- From #Time_Frames
-- Group By pl_id,pu_id,pu_desc,frequency
--**************************************************************************************************
-- Select * from #Time_Frames where frequency like 'Monthly%'
-- Select * from #Time_Frame_LookUp where frequency like '%Weekly%'
-- Select * From #Pre_Var_Ids --where frequency like '%Weekly%' and pug_desc like '%ea1%'
--**************************************************************************************************
Print  Convert(varchar,getdate(),120) + ' START INSERTING VARIABLES ' 
-- **************************************************************************************************************
-- Creating the #All_Variables Table
-- **************************************************************************************************************
Insert Into #All_Variables(  PL_ID , Pu_id,Line, Var_ID, Var_Type, Var_Desc, Pug_Desc, Ext_Info,
Master, Frequency,Start_Date,End_Date,Due_Date,Next_Start_Date,Day_Period,
Samples_Due, Future_Samples_Due, Samples_Taken,
Result_On,Result,Defects, Team, Shift, Include_Result, Include_Crew, Include_Shift, 
Include_LineStatus,Include_test,Stubbed,Canceled,Test_Freq,Sheet_id,CurrentSpec)

Select 
    tplids.PL_ID as PL_ID,
    tplids.pu_id as pu_id,
	tplids.PL_Desc as Line,
	pvids.var_id as Var_ID,
	pvids.Var_Type as Var_Type,
	pvids.var_desc as Var_Desc,
	pvids.pug_Desc as Pug_Desc,
	pvids.Extended_Info as Ext_Info,
	1 as Master,						-- "Master" record indicator (0 = summary; 1 = detail)
	pvids.Frequency,					-- Eg. Shiftly, Weekly or Monthly
    tf.Start_Date as Start_Date,
    tf.End_Date as End_Date,
    tf.Due_Date as Due_Date,
    tf.Next_Start_Date as Next_Start_Date,
    tf.Day_Period,
	1 as Samples_Due,
	1 as Future_Samples_Due,		
	0 as Samples_Taken,					-- Samples Taken (to be updated later in code)
    tf.Start_Time as Result_On,
	'123abcxxx' as Result,
	0 as Defects,						-- Defects (to be updated later in code)
	'No Team' as Team,
	'9' as Shift,
	'No ' as Include_Result ,
	'Yes' as Include_Crew ,
	'Yes' as Include_Shift ,
	'Yes' as Include_LineStatus ,
    'No' as Include_Test,
    'No' as Stubbed,
    0,
    0, -- Test Freq
    pvids.Sheet_id,
    'No' as CurrentSpec
From #Pre_Var_IDs pvids
Join #Time_Frames tf WITH(NOLOCK) on tf.frequency = pvids.frequency and tf.pu_id = pvids.pu_id
Join #PL_IDs tplids WITH(NOLOCK) on pvids.pu_id = tplids.PU_ID

    If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert All_Variables first'
	   Return
	END 

-- Join dbo.pu_groups pug WITH(NOLOCK) ON pvids.pug_id = pug.pug_id
-- Join dbo.Variables_Base vars WITH(NOLOCK) on pvids.var_id = vars.var_id
-- Join dbo.Prod_Units_Base pu WITH(NOLOCK) on pvids.PU_ID = pu.PU_ID 


-- DJM and FRio 2005 Jul 13: 
-- Changed update of Next_start_date for Shiftly variables to use the End time from Crew Schedule table.
-------------------------------------------------------------------------------------------------------------->
Print  Convert(varchar,getdate(),120) + ' START UPDATE STATEMENTS FOR VARIABLES' 
-- GET ALL START DATES --------------------------------------------------------------------------------------->

Update #All_Variables
Set Start_Date = convert(datetime,Convert(varchar,year(Start_Date))+'-'+
Convert(varchar,month(Start_Date))+'-'+
Convert(varchar,day(Start_Date))+' '+
Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 5, 2)
+ ':'
+ Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 7, 2))
From #All_Variables
Where Frequency = 'c) Daily' and CHARINDEX('TT=;',Ext_Info) = 0


If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update All_Variables'
	   Return
	END 

Update #All_Variables
  Set Due_Date = (case Frequency 
  when 'e) Monthly' then 
     Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 3, 2)
 + ' ' + 
 (Case Month(Start_Date)
   when 1 then 'Jan'
   when 2 then 'Feb'
   when 3 then 'Mar'
   when 4 then 'Apr'
   when 5 then 'May'
   when 6 then 'Jun'
   when 7 then 'Jul'
   when 8 then 'Aug'
   when 9 then 'Sep'
   when 10 then 'Oct'
   when 11 then 'Nov'
   when 12 then 'Dec'
end) + ' ' + Cast(Year(Start_Date) as varchar(4))
+ ' '
+ Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 5, 2)
+ ':'
+ Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 7, 2)
 when 'f) Quarterly' then
'01' + 
(Case 
	When DATEPART (Quarter, Start_Date) < 2 Then 'JAN'
	When DATEPART (Quarter, Start_Date) < 3 Then 'APR'
	When DATEPART (Quarter, Start_Date) < 4 Then 'JUL'
	Else 'OCT' 
end) + ' ' + Cast(Year(Start_Date) as varchar(4))
+ ' '
+ Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 5, 2)
+ ':' + Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 7, 2)
end) 
from #All_Variables		-- nuevo start_time de acuerdo al TT
where CHARINDEX('TT=;',Ext_Info) = 0 and (Frequency = 'e) Monthly' or Frequency = 'f) Quarterly')

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update All_Variables'
	   Return
	END 


-- 2005-12-16: TT information for Weekly variables should add from the start of the week not from Start_Date

Update #All_Variables Set 
        Due_Date = dateadd(dd,convert(int,Substring(Ext_Info, CHARINDEX('TT=', Ext_Info) + 3, 2))- 1,DateAdd(dd,-1*(Day_Period-1),Start_Date))    
Where Frequency = 'd) Weekly' and CHARINDEX('TT=;',Ext_Info) = 0

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update All_Variables'
	   Return
	END 

------------------------------------------------------------------------------------------------------------------>
Print  Convert(varchar,getdate(),120) + ' END UPDATE STATEMENTS FOR VARIABLES' 
-- **************************************************************************************************************
-- **************************************************************************************************************
-- Delete Time Frames not considered on this report
-- Print 'Deleting tables with Start_Time = NULL'
Delete from #All_Variables where Start_Date Is NULL

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete All_Variables'
	   Return
	END 

-- **************************************************************************************************************
-- Select '#All_Variables Ids - > ',count(*) from #All_Variables where frequency like '%Shiftly Auto%' -- and pug_desc like '%EA4%' 
-- Select * From #Var_ids where frequency = 'a) Shiftly Manual' and pug_desc like '%EA2%'
-- Select * From #all_variables where frequency like '%Daily%' -- and pug_desc like '%EA3%' 
-----------------------------------------------------------------------------------------------------------------
-- Assign values from Tests table
-----------------------------------------------------------------------------------------------------------------
Print convert(varchar(25), getdate(), 120) + 'Assign values from Tests table'
PRINT  Convert(varchar,getdate(),120) + 'INSERT INTO #Tests'

Insert Into #Tests (Var_id,Frequency,Start_Date,End_Date,Result_On,Result,Include_Test,Tested)
Select av.var_id,av.Frequency,av.Start_Date,av.End_Date,t.Result_On,t.Result,'No',
(Case ISNULL(t.Result,'') When '' Then 'No'
               -- When NULL Then 'No'
			   Else 'Yes' End) as Tested
From #All_Variables av --With(Index(IDX_VarId_ResultOn))
Join dbo.Tests t WITH (NOLOCK) on av.var_id = t.var_id 
and (t.Result_On >= av.Start_Date and t.Result_On < av.End_Date)
Where t.Entry_on >= av.Start_Date and t.Entry_On < av.End_Date and t.Canceled <> 1

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert #Test'
	   Return
	END 


PRINT Convert(varchar,getdate(),120) + ' END INSERT IN #Test ' 

-- Select * From #Tests Where Frequency Like '%Daily%'
--*******************************************************************************************************
-- PERFORM TWO SCANS TO GET RID OF VARIABLES THAT HAS MULTIPLE TESTS ON THE SAME PERIOD
-- If the variable is completed then get the minimun test on that period

-- If the variable is NOT completed then get the maximun result_on
 Insert Into @temp_variables_without_samples (var_id,start_date,end_date,result_on)
 Select var_id,start_date,end_date,max(result_on) as result_on 
 from #Tests
 Where Tested = 'No' 
 group by var_id,start_date,end_date

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert @temp_variables'
	   Return
	END 


-- Delete the variables without samples if there exists a sample on that time frame
 Delete from @temp_variables_without_samples
 from @temp_variables_without_samples tvwos
 join (Select var_id,start_date,end_date,min(result_on) as result_on 
			 from #Tests 
			 Where Tested = 'Yes' 
			 group by var_id,start_date,end_date) tvws on tvws.var_id = tvwos.var_id
 and tvws.start_date = tvwos.start_date
 and tvws.end_date = tvwos.end_date

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete @temp_variables_without_samples'
	   Return
	END 

-- 
PRINT Convert(varchar,getdate(),120) + ' UPDATE #Tests'
Update #Tests
        Set Include_Test = 'Yes'
From #Tests av
Join (Select var_id,start_date,end_date,min(result_on) as result_on 
			 from #Tests 
			 Where Tested = 'Yes' 
			 group by var_id,start_date,end_date) tvws on av.var_id = tvws.var_id 
        and av.start_date = tvws.start_date
        and av.end_date = tvws.end_date
        and av.result_on = tvws.result_on

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #Test'
	   Return
	END 


Update #Tests
        Set Include_Test = 'Yes'
From #Tests av
Join @temp_variables_without_samples tvws on av.var_id = tvws.var_id 
        and av.start_date = tvws.start_date
        and av.end_date = tvws.end_date
        and av.result_on = tvws.result_on

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #Test'
	   Return
	END 


Delete From #Tests Where Include_Test = 'No'

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete #Test'
	   Return
	END 

PRINT Convert(varchar,getdate(),120) + 'END UPDATE Tests'

PRINT Convert(varchar,getdate(),120) + 'UPDATE #All_Variables FROM TESTs'
UPDATE #All_Variables
	Set Result = (Case t.Result When @Pass Then '1' Else t.Result End), 
		Result_On = t.Result_On,
		Stubbed = 'Yes'
From #All_Variables av 
Join #Tests t on av.var_id = t.var_id and av.Start_Date = t.Start_Date and av.End_Date = t.End_Date

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #All_Variables'
	   Return
	END 
PRINT Convert(varchar,getdate(),120) + 'END UPDATE UPDATE #All_Variables from tests'
--******************************************************************************************************
-- Delete variables that has no column Stubbed
Delete From #All_Variables Where Stubbed = 'No'

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete #All_Variables'
	   Return
	END 

--******************************************************************************************************

--**********************************************************************************
-- Determine if Test Results should be included based on end-user's 'Crew/Team' Criteria
-- Select * from #Tests
--**********************************************************************************

Print convert(varchar(25), getdate(), 120) + ' Validating Crew/Shift'
declare 
        @min_start_date as datetime,
        @max_end_date as datetime
		--@nptStartDate datetime

Select @min_start_date=Min(start_date) from #All_Variables
Select @max_end_date=Max(end_date) from #All_Variables

Insert Into @Production_Starts(Pu_id, Prod_id, Prod_Code, Prod_Desc,Start_Time,End_Time)
Select Ps.Pu_id, Ps.Prod_id, P.Prod_Code, P.Prod_Desc,  Ps.Start_Time, Ps.End_Time              
 From 	dbo.Production_Starts PS WITH(NOLOCK) 
        Join #PL_Ids tpl on tpl.Conv_ID = PS.PU_ID
		and  (ps.End_Time > @min_start_date or ps.End_Time IS null)
        Join dbo.Products_Base P WITH(NOLOCK) on ps.Prod_ID = P.Prod_ID


If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert @Production_Starts'
	   Return
	END 

--Gonzalo change crew_schedule table.
INSERT INTO @Crew_Schedule(
			CS_Id
		   ,Start_Time
		   ,End_Time
		   ,PU_Id
		   ,Comment_Id
		   ,Crew_Desc
		   ,Shift_Desc
		   ,User_Id)
	   SELECT
		    cs.CS_Id
		   ,cs.Start_Time
		   ,cs.End_Time
		   ,cs.PU_Id
		   ,cs.Comment_Id
		   ,cs.Crew_Desc
		   ,cs.Shift_Desc
		   ,cs.User_Id
From
        dbo.Crew_Schedule cs WITH(NOLOCK)
        Join #PL_Ids tpl on tpl.Conv_ID = cs.PU_ID
Where  cs.End_Time >= @min_start_date and cs.End_Time <= @max_end_date

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Insert @Crew_Schedule'
	   Return
	END 

--SELECT @nptStartDate = MAX(Start_Time) FROM dbo.NonProductive_Detail npt WITH (NOLOCK) JOIN #PL_Ids l ON npt.PU_Id = l.Conv_Id

--Insert Into @Local_PG_Line_Status (Unit_id,Start_DateTime,End_Datetime,Phrase_Value)
--Select npt.PU_Id,npt.Start_Time,(CASE WHEN npt.End_Time < @min_start_date THEN NULL ELSE npt.End_Time END),r.Event_Reason_Name
--From   dbo.NonProductive_Detail npt (NOLOCK)
----dbo.Local_PG_Line_Status LPG WITH(NOLOCK)
--       Join #PL_Ids tpl on tpl.Conv_id = npt.PU_id 
--			and (npt.end_Time >= @nptStartDate or DATEPART(mm,DATEADD(mm,6,Entry_On)) = DATEPART(mm,End_Time))
--		JOIN Event_Reasons r (NOLOCK) ON npt.Reason_Level1 = r.Event_Reason_Id
--  	--    Join dbo.Phrase phr WITH(NOLOCK) on lpg.Line_Status_ID = phr.Phrase_ID	

--If @@Error <> 0
--	BEGIN
	   
--	   Select 'Error in Insert @Local_PG_Line_Status'
--	   Return
--	END 


-- Select * from @Production_Starts
-- Select @min_start_date,@max_end_date,* from @Crew_Schedule
-- Select * from @Local_Pg_Line_Status
PRINT Convert(varchar,getdate(),120) + ' UPDATE All_Variables for Production starts, crew schedule and line status'
Update #All_Variables
      	Set     Prod_ID = ps.Prod_id,
    	        Prod_Code = PS.Prod_Code,
                Prod_Desc = Ps.Prod_Desc

	From #All_Variables tdt --With(Index(IDX_VarId_ResultOn))

	Join #PL_Ids tpl on tdt.PL_ID = tpl.PL_ID

	Join @Production_Starts PS on tpl.Conv_Id = PS.PU_ID
	Where Result_On >= ps.Start_Time 
		and (Result_On < ps.End_Time or ps.End_Time IS null)


If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #All_Variables'
	   Return
	END 

Update #All_Variables
      	Set     Team = cs.Crew_DESC, 
		Shift = cs.Shift_DESC                

	From #All_Variables tdt --With(Index(IDX_VarId_ResultOn))

	Join #PL_Ids tpl on tdt.PL_ID = tpl.PL_ID

	Join @Crew_Schedule cs on tpl.Conv_Id = cs.PU_ID
	Where Result_On >= cs.Start_Time 
		and (Result_On < cs.End_Time or cs.End_Time IS null)

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #All_variables'
	   Return
	END 


Update #All_Variables

      	Set     Line_Status = npt.Reason_Desc 
            
	From #All_Variables tdt --With(Index(IDX_VarId_ResultOn))

	Join #PL_Ids tpl on tdt.PL_ID = tpl.PL_ID

	JOIN @NonProductive_Detail npt on tpl.Conv_Id = npt.PUId

	Where Result_On >= npt.StartTime
			and (Result_On < npt.EndTime)

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #All_Variables'
	   Return
	END 

PRINT Convert(varchar,getdate(),120) + ' END UPDATE All_Variables for Production starts, crew schedule and line status'

-- **********************************************************************************
-- Need to update the Active Specs for that variable taking in account the Result_on
-- date to get the correct Specification for the Variable
-- **********************************************************************************
Print convert(varchar(25), getdate(), 120) +  'Assigning specs'

INSERT INTO #Var_Specs(
			 VS_Id				
			,Effective_Date		
			,Expiration_Date		
			,Deviation_From		
			,First_Exception		
			,Test_Freq			
			,AS_Id				
			,Comment_Id			
			,Var_Id				
			,Prod_Id				
			,Is_OverRiden		
			,Is_Deviation		
			,Is_OverRidable		
			,Is_Defined			
			,Is_L_Rejectable		
			,Is_U_Rejectable		
			,L_Warning			
			,L_Reject			
			,L_Entry				
			,U_User				
			,Target				
			,L_User				
			,U_Entry				
			,U_Reject			
			,U_Warning			
			,Esignature_Level	
			,L_Control			
			,T_Control			
			,U_Control)
SELECT		
			 vs.VS_Id				
			,vs.Effective_Date		
			,vs.Expiration_Date		
			,vs.Deviation_From		
			,vs.First_Exception		
			,vs.Test_Freq			
			,vs.AS_Id				
			,vs.Comment_Id			
			,vs.Var_Id				
			,vs.Prod_Id				
			,vs.Is_OverRiden		
			,vs.Is_Deviation		
			,vs.Is_OverRidable		
			,vs.Is_Defined			
			,vs.Is_L_Rejectable		
			,vs.Is_U_Rejectable		
			,vs.L_Warning			
			,vs.L_Reject			
			,vs.L_Entry				
			,vs.U_User				
			,vs.Target				
			,vs.L_User				
			,vs.U_Entry				
			,vs.U_Reject			
			,vs.U_Warning			
			,vs.Esignature_Level	
			,vs.L_Control			
			,vs.T_Control			
			,vs.U_Control			
FROM dbo.Var_Specs vs WITH(NOLOCK) 
JOIN #All_Variables av ON av.var_id = vs.var_id 
        			 AND vs.effective_date <= Result_On 
        			 AND (vs.expiration_date > Result_On or vs.expiration_date IS NULL)
					 AND vs.Prod_ID = av.Prod_ID
					 AND vs.Test_Freq = 1 


-- All specs variables for current time, Non numeric or comma in specs will be replaced by '77777' for error handeling

PRINT Convert(varchar,getdate(),120) + ' ***** UPDATE All_Variables against Var_Specs table *****'

Update #All_variables
Set  
      L_Reject  = (Case IsNumeric(a_s.l_reject) when 1 then (Case charindex(',',a_s.l_reject) when 0 then a_s.l_reject else  '77777' end) else (case isnull(a_s.l_reject,'1') when '1' then Null else '77777' end) end ),
		L_Warning = (Case IsNumeric(a_s.l_warning) when 1 then (Case charindex(',',a_s.l_warning) when 0 then a_s.l_warning else  '77777'  end) else (case isnull(a_s.l_warning,'1') when '1' then Null else '77777' end) end),
		L_User    = (Case IsNumeric(a_s.l_user) when 1 then (Case charindex(',',a_s.l_user) when 0 then a_s.l_user else  '77777'  end) else (case isnull(a_s.l_user,'1') when '1' then Null else '77777' end) end ),
		Target    = (Case IsNumeric(a_s.target) when 1 then (Case charindex(',',a_s.target) when 0 then a_s.target else  '77777'  end) else (case isnull(a_s.target,'1') when '1' then Null else '77777' end) end ),
		U_User    = (Case IsNumeric(a_s.u_user) when 1 then (Case charindex(',',a_s.u_user) when 0 then a_s.u_user else  '77777'  end) else (case isnull(a_s.u_user,'1') when '1' then Null else '77777' end) end ),
		U_Warning = (Case IsNumeric(a_s.u_warning) when 1 then (Case charindex(',',a_s.u_warning) when 0 then a_s.u_warning else '77777'  end) else (case isnull(a_s.u_warning,'1') when '1' then Null else '77777' end) end ),
		U_Reject  = (Case IsNumeric(a_s.u_reject) when 1 then (Case charindex(',',a_s.u_reject) when 0 then a_s.u_reject else  '77777' end) else (case isnull(a_s.u_reject,'1') when '1' then Null else '77777' end) end ),
      Test_Freq = 1,
      CurrentSpec = 'Yes'
From #All_Variables av 
 	  JOIN #Var_Specs a_s ON av.var_id = a_s.var_id 
        	    AND a_s.effective_date <= Result_On 
        	    AND (a_s.expiration_date > Result_On or a_s.expiration_date IS NULL)
				 AND a_s.Prod_ID = av.Prod_ID
				 AND a_s.Test_Freq = 1 

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Update #All_Variables'
	   Return
	END 
PRINT Convert(varchar,getdate(),120) + '*****END UPDATE All_Variables against Var_Specs table*****'
-- Excecution should be end,if there are Non numeric values in specification.
-- This is reported in user excel report

IF (SELECT COUNT(*) FROM #All_Variables where L_reject='77777' or 
           L_warning='77777' or  L_User='77777' or Target='77777' or
           U_warning='77777' or  U_User='77777' or U_reject='77777') > 0
           BEGIN

		   Select 'Error : Report cannot complete! Non numeric or comma(,) were found in the RTT specification limits instead of decimal(s) or numeric values. Please contact your RTT SSO to correct the issue(s) and rerun the report.' as err1
          
           Select 'Var_id' as var_id,'Var_Desc' as Var_Desc,'Prod_Id' as Prod_Id,'L_Reject' as L_Reject,'L_Warning' as L_Warning,'L_User' as L_User,'Target' as Target,'U_User' as U_User,'U_Warning' as U_Warning,'U_Reject' as U_Seject

           Select  Distinct av.Var_id,av.Var_desc,vs.prod_id,vs.L_Reject,vs.L_warning,vs.L_User,vs.Target,vs.U_User,vs.U_Warning,vs.U_Reject from #All_Variables av
           Join #Var_Specs vs WITH (NOLOCK) ON vs.var_id = av.var_id
           AND vs.prod_id = av.prod_id
           AND (av.L_reject='77777' or 
		   av.L_warning='77777' or  av.L_User='77777' or av.Target='77777' or
		   av.U_warning='77777' or  av.U_User='77777' or av.U_reject='77777')
           AND vs.effective_date <= Result_On 
           AND (vs.expiration_date > Result_On or vs.expiration_date IS NULL) 
           AND vs.Test_Freq = 1  

		   Return
           END                          

		

Print convert(varchar(25), getdate(), 120) +  'Deleting variables with no specs'
Delete from #All_Variables Where Test_Freq = 0 -- Or CurrentSpec = 'No'

If @@Error <> 0
	BEGIN
	   
	   Select 'Error in Delete #All_Variables where Test_Freq=0'
	   Return
	END 


Print convert(varchar(25), getdate(), 120) +  ' Parsings'
--************************************************************************************
-- Determine if this Test Result should be included based on the Crew, Shift Criteria
--************************************************************************************       	
      IF @in_Crew <> 'ALL'
   	  BEGIN
      		UPDATE #All_Variables
		            Set Include_Crew = 'No'
		    Where CHARINDEX(@in_Crew, Team, 1) = 0
      END  
      
      IF @in_Shift <> 'ALL'
      BEGIN
      	UPDATE #All_Variables
	            Set Include_Shift = 'No'
	    Where CHARINDEX(@in_Shift, Shift, 1) = 0
 
        If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END 

      END 	      

	  IF @in_LineStatus <> 'ALL'
		UPDATE #All_Variables 
				Set Include_LineStatus = 'No'
		WHERE Line_Status Not In (Select PLStatusDesc From #PLStatusDescList )		
        
        If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END    
	  ELSE
		UPDATE #All_Variables 
				Set Include_LineStatus = 'No'
		WHERE Line_Status Is NULL
        
        If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END      
-- **********************************************************************************
-- Update "Samples Taken" field where results are not null and not like " "
-- **********************************************************************************
	UPDATE #All_Variables
	Set Samples_Taken = 1
	Where Result is not null and
        Result <> '123abcxxx'

		If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END 
	
--**********************************************************************************
-- Update "Defects" field where variable results are > upper limit or < lower limit
--**********************************************************************************
	UPDATE #All_Variables
	Set Defects = 1
	WHERE Var_Type = 'VARIABLE' 
	AND Result <> '123abcxxx'
	AND (CAST(Result AS FLOAT) > CAST(U_Reject AS FLOAT)
	OR CAST(Result AS FLOAT) < CAST(L_Reject AS FLOAT))

   If @@Error <> 0
		BEGIN
		   
		   Select 'Error in Update #All_Variables'
		   Return
	END 

--**********************************************************************************
-- Update "Defects" field where variable results are <> target.
--**********************************************************************************		
		
	UPDATE #All_Variables
	Set Defects = 1
	WHERE Var_Type = 'VARIABLE' 
	AND Result <> '123abcxxx'
	AND (CAST(Result AS FLOAT) > CAST(Target AS FLOAT)
	OR CAST(Result AS FLOAT) < CAST(Target AS FLOAT))
	AND U_Reject IS NULL
	AND L_Reject IS NULL

	If @@Error <> 0
		BEGIN
		   Select 'Error in Update #All_Variables'
		   Return
		END 

--**********************************************************************************
-- Update "Defects" field where attribute results <> Target
--**********************************************************************************
	UPDATE #All_Variables
	SET Defects = 1
	WHERE Var_Type = 'ATTRIBUTE'
	AND Result <> Target

	If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables where Var_Type = ATTRIBUTE'
			   Return
			END 

--**********************************************************************************
-- Update the "Include Results" Flag
--**********************************************************************************	   
UPDATE #All_Variables
	SET Include_Result = 'Yes'
	WHERE Include_Crew = 'Yes'
	and Include_Shift = 'Yes'
	and Include_LineStatus = 'Yes'

	If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END 

--**********************************************************************************
-- Update the Pug_Desc Field (leave only the 'EA' designation)
--**********************************************************************************	   
	
--**********************************************************************************
-- Update the 'Result', 'Samples_Completed' and 'Defects' fields where 
-- no matching data in #Tests (no samples taken)
--**********************************************************************************	   
		
UPDATE #All_Variables
	SET Samples_Taken = 0, 
		Result = '', 
		Defects = 1
	From #All_Variables
	WHERE Result = '123abcxxx'
	
   If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END   	
--**********************************************************************************
-- Update Samples_Due field where Due_Date > @End_Date
--**********************************************************************************
UPDATE #All_Variables
	Set Samples_Due = 0 -- Due
        Where Due_Date > @in_EndTime and Samples_Taken = 0 

	If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END 

--**********************************************************************************
-- Update Future_Samples_Due field where Start_Date < @End_Date
-- DJM 2005 Jul 13 
-- 	Added comparison of the current date. If report end date is less than current Date
-- 	then tests are set to overdue if the Next_start_Date is <= report end date, if the 
--	report end date is greater than the current date, then only tests that are less than
--	report end date are considered overdue.
--*********************************************************************************
 	Update #All_Variables 
	Set Future_Samples_Due =  0
	where Next_Start_Date <= @in_EndTime and Samples_Taken = 0 -- DJM 2005 June 12 Added "=" to include samples not taken by report end time.

   If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END 
--**********************************************************************************
-- Update Samples_Taken field where no samples are due
--**********************************************************************************
	Update #All_Variables
	Set Samples_Taken = 0
	Where Samples_Due = 0 and Future_Samples_Due = 0 

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END  

	Delete From #All_Variables
	Where Samples_Taken = 0	and Samples_Due = 0 and Future_Samples_Due = 0

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Delete #All_Variables'
			   Return
			END 

--*******************************************************************************************************
-- Update Defects field where no samples are due, if the sample is Due then still no defect
--*******************************************************************************************************
	Update #All_Variables
	        Set Defects = 0
	Where Samples_Taken = 0 -- Samples_Due = 0

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables Where Samples_Taken = 0'
			   Return
			END  

--*******************************************************************************************************
-- Delete from #All_Variables where Include_Test = 'No'
--*******************************************************************************************************

 
-- and pug_desc = 'EA1'
--*******************************************************************************************************
-- Create the Output Temp Table
Print convert(varchar(25), getdate(), 120) +  'End Parsings'

  
-- and Start_Date = '2005-07-18 07:30:00.000' 
-- and pug_desc = 'EA1'
--*******************************************************************************************************
-- Create the Output Temp Table

PRINT Convert(varchar,getdate(),120) + 'INSERT INTO #RTTTempCLId join tests and pre_vars_id'

INSERT INTO #RTTTempCLId
SELECT     pl.PL_Desc,v.Var_Id, 'EA' + LEFT(v.Var_Desc, 1) AS Area, v.Var_Desc, a.Start_Time, a.Start_Result, 
                      er1.Event_Reason_Name AS Cause, er.Event_Reason_Name AS Action, a.Action_Comment_Id, a.Min_Result, 
                      a.Max_Result, MAX(t.Result_On) AS Last_Result_On,ap.ap_desc as Priority
FROM dbo.Tests t WITH(NOLOCK)
JOIN dbo.#Pre_Var_ids v WITH(NOLOCK) ON t.Var_Id = v.Var_Id 
JOIN dbo.Alarms a WITH(NOLOCK) ON t.Var_Id = a.Key_Id 
join dbo.Alarm_Template_Var_Data atvd WITH(NOLOCK) on a.key_id = atvd.var_id
join dbo.Alarm_Templates at WITH(NOLOCK) on atvd.at_id = at.at_id
join dbo.Alarm_Priorities ap WITH(NOLOCK) on ap.ap_id = at.ap_id
JOIN #PL_IDs pl ON v.pu_id = pl.pu_id
LEFT JOIN dbo.Event_Reasons er WITH(NOLOCK) ON a.Action1 = er.Event_Reason_Id 
LEFT JOIN dbo.Event_Reasons er1 WITH(NOLOCK) ON a.Cause1 = er1.Event_Reason_Id
WHERE (a.End_Time IS NULL) AND (er.Event_Reason_Name LIKE '%Tym%' or er.Event_Reason_Name LIKE '%Temp%')
GROUP BY pl.PL_Desc,a.Start_Time, a.Action_Comment_Id, er.Event_Reason_Name, er1.Event_Reason_Name, 
                      a.Start_Result, a.Min_Result, a.Max_Result, v.Var_Desc, v.Var_Id,ap.ap_desc
ORDER BY 'EA' + LEFT(v.Var_Desc, 1), v.Var_Desc

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #RTTTempCLId'
			   Return
			END  


PRINT Convert(varchar,getdate(),120) + 'END INSERT INTO #RTTTempCLId join tests and pre_vars_id'
-- Select varid from #RTTTempCLId


PRINT Convert(varchar,getdate(),120) + ' UPDATE Alarms from RTTTempCLId to All_Variables'
-- Update TempCL Variables
Update #All_Variables
        Set TempCL = 'Yes'
From #All_Variables av
Join #RTTTempCLId tempcl on av.var_id = tempcl.varid

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END  



--*******************************************************************************************************
-- Get the Open Alarms for Current Variables
Update #All_Variables
		Set Alarm_Id = alms.Alarm_Id 
From #All_Variables av
Join dbo.Alarms alms WITH(NOLOCK) On av.Var_Id = alms.key_id 
					and alms.Start_Time <= av.Result_On
					and (alms.End_Time >= av.Result_On Or alms.End_Time Is NULL)

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END  


 Update #All_Variables
        Set 	Action_Comment = Convert(Varchar(300),Comment_Text),
                Action = Convert(Varchar(100),ER1.Event_Reason_Name),
                Cause = Convert(Varchar(100),ER2.Event_Reason_Name) 
 From dbo.Alarms alms WITH(NOLOCK)
 Join #All_Variables av On av.Alarm_Id = alms.Alarm_Id
 LEFT JOIN dbo.Comments cs WITH(NOLOCK) on cs.Comment_ID = alms.Action_Comment_ID 
 LEFT JOIN dbo.Event_Reasons ER1 WITH(NOLOCK) on alms.Action1 = ER1.Event_Reason_ID 
 LEFT JOIN dbo.Event_Reasons ER2 WITH(NOLOCK) on alms.Cause1 = ER2.Event_Reason_ID

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #All_Variables'
			   Return
			END  

PRINT Convert(varchar,getdate(),120) + 'end UPDATE Alarms from RTTTempCLId to All_Variables'
-- Select * From #All_Variables where frequency like '%Daily%' 
--**********************************************************************************
-- Insert the "Master Records" (summary records) into the output table first
--**********************************************************************************
PRINT Convert(varchar,getdate(),120) + 'INSERT INTO OUTDATA'
Insert Into #OUTDATA
(Plant, Line, PU_Group, Frequency, Team, Shift, Line_Status, Result_On, 
Samples, Defects, Samples_Due,
Future_Samples_Due,Tempcl_Defects,No_Samples_Taken, Product_Desc, Master, Pug_Desc, Due_Complete,
Prod_Code, Next_Start_Date)

Select @Plant_Name, Line, Pug_Desc, Frequency, Team, Shift, Line_Status, Result_on, 
Sum(SAMPLES_TAKEN), Sum(DEFECTS), Sum(SAMPLES_DUE), Sum(Future_Samples_Due), 
Sum(Case TempCL When 'Yes' Then Defects Else 0 End),
Case
	When Sum(SAMPLES_TAKEN)>0 Then 'FALSE'
	Else 'TRUE'
End,
Prod_Desc, 0, PUG_DESC,0, Prod_Code, Next_Start_Date
From #ALL_VARIABLES
Where Include_Result = 'Yes'
Group By Line, Frequency,
PUG_DESC, Prod_Code, Team, Shift, Line_Status,Result_on ,PROD_DESC, Next_Start_Date

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #OUTDATA First'
			   Return
			END  


-- select 'Outdata -->',count(*) as cant from #outdata where Frequency Like '%Shiftly%'
-- select 'AllVariables -->',count(*) as cant from #All_Variables

Insert Into #OUTDATA
(Plant, Line, Team, Shift, Line_Status, PU_Group, Pug_Desc,Frequency, product_desc, Defects, 
Samples_Due,Samples,TempCL_Defects)

Select  @Plant_Name, 
		Line, 
		Team, 
		Shift, 
		Line_Status, 
		Pug_Desc,
		'Totals', 
		Frequency, 
		PRODUCT_DESC,
		Sum(DEFECTS),
		Sum(SAMPLES_DUE),
		Sum(SAMPLES),
		Sum(TempCL_Defects)
From #OUTDATA
Where Frequency NOT LIKE '%Totals_W_O_Recipe%'
Group By Line, Team, Shift, Line_Status, Pug_Desc, Frequency, PRODUCT_DESC


    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #OUTDATA'
			   Return
			END  
PRINT Convert(varchar,getdate(),120) + 'END INSERT INTO OUTDATA'
--**********************************************************************************
-- Create the Summary-Level Record Set, insert in the #Temp_OutData table and average
-- to calculate Totals_W_O_Recipe.
--**********************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Summary-Level Record Set' 


Insert Into #Temp_OutData 
(Result_on,Plant,Line,Team,Shift,Line_Status,Pug_Desc,Frequency,Product_Desc,
Percent_Compliance, Percent_Completed,Percent_TempCLCompliance, Samples_Taken,Samples_Due,Defects,TempCL_Defects)


Select Result_on,Plant, Line, Team, Shift, Line_Status, Pug_Desc, Frequency, Product_Desc,
Case
	When Sum(Convert(Float,DEFECTS))> 0 AND Sum(Convert(float,SAMPLES_DUE)) > 0 THEN Convert(Decimal(10, 4),(SUM(Convert(float,SAMPLES)) - Sum(Convert(float,DEFECTS))) / Sum(Convert(float,SAMPLES_DUE)))
	When Sum(Convert(Float, DEFECTS))= 0 AND Sum(Convert(Float, SAMPLES_DUE)) >= 0 THEN '1.0' --When Sum(Convert(Float, DEFECTS))= 0 AND Sum(Convert(Float, SAMPLES)) >= 0 THEN '0.0'
	Else '0.0'
End
As 'Percent_Compliance',
Case 
	When Sum(Convert(Float, SAMPLES))> 0 AND SUM(CONVERT(Float, SAMPLES_DUE)) > 0 THEN CONVERT(Decimal(10,4), Sum(Convert(Float, SAMPLES)) / Sum(Convert(Float, SAMPLES_DUE)))
	When Sum(Convert(Float, SAMPLES_DUE)) = 0 AND Sum(Convert(Float, SAMPLES))= 0 THEN '0.0'
	Else '0.0'
End
As 'Percent_Completed',
Case
	When Sum(Convert(Float,SAMPLES_DUE))> 0 AND Sum(Convert(float,TempCL_DEFECTS)) > 0 THEN Convert(Decimal(10, 4),Sum(Convert(float,TempCL_DEFECTS)) / Sum(Convert(float,SAMPLES_DUE)))
	When Sum(Convert(Float, TEMPCL_DEFECTS))= 0 THEN '1.0' --When Sum(Convert(Float, DEFECTS))= 0 AND Sum(Convert(Float, SAMPLES)) >= 0 THEN '0.0'
	Else '0.0'
End
As 'Percent_TempCLCompliance',
Sum(Convert(Float, SAMPLES)) as 'Samples_Taken',
Sum(Convert(Float, SAMPLES_DUE)) as 'Samples_Due',
Sum(Convert(Float, DEFECTS)) as 'Defects',
Sum(Convert(Float, TempCL_DEFECTS)) as 'TempCL_Defects'
From #OUTDATA
Where Team <> 'None' 
Group By Result_on,Plant, Line, Team, Shift, Line_Status, Pug_Desc, Frequency, PRODUCT_DESC

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #Temp_OutData'
			   Return
			END  


--**********************************************************************************
-- Need to insert back Totals_W_O_Recipe Column here. Allow 'Recipe Dynamic' variables and all others
-- except 'Recipe' variables
--**********************************************************************************
if @in_ReportType <> 'Recipe'
Begin

    Insert into #Temp_OutData 
  (Result_on,Plant,Line,Team,Shift,Line_Status,Pug_Desc,Frequency,Product_Desc,
   Percent_Compliance, Percent_Completed,Percent_TempClCompliance, Samples_Taken,Samples_Due,Defects,TempCL_Defects)

   Select Result_on,Plant,Line,Team,Shift,Line_Status,Pug_Desc,'g) Totals_W_O_Recipe',Product_Desc,
   Avg(Percent_Compliance) as Percent_Compliance,avg(Percent_Completed) as Percent_Completed,
   Avg(Percent_TempCLCompliance) as Percent_TempCLCompliance,
   Sum(samples_taken) as 'Samples_Taken',
   Sum(samples_due) as 'Samples_Due',
   Sum(defects) as 'Defects',
   Sum(TempCL_Defects) as 'TempCL_Defects'
   From #Temp_OutData
   Where pug_Desc <> 'Totals' and 
   (Frequency like '%Recipe Dynamic%' or CHARINDEX('Recipe',Frequency)=0 or Frequency like '%Shiftly%Auto%' or Frequency like '%Daily%' or Frequency like '%Weekly%' or Frequency like '%Monthly%' or Frequency like '%Quarterly%')
   Group By Result_on,Plant,Line,Team,Shift,Line_Status,Pug_Desc,Product_Desc

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #Temp_OutData'
			   Return
			END  
 

   Insert Into #Temp_OutData 
  (Plant,Line,Team,Shift,Line_Status,Pug_Desc,Frequency,Product_Desc,
   Percent_Compliance, Percent_Completed, Percent_TempClCompliance,Samples_Taken,Samples_Due,Defects,TempCL_Defects)

   Select Plant,Line,Team,Shift,Line_Status,'Totals','g) Totals_W_O_Recipe',Product_Desc,
   Avg(Percent_Compliance) as Percent_Compliance,avg(Percent_Completed) as Percent_Completed,
   Avg(Percent_TempCLCompliance) as Percent_TempCLCompliance,
   Sum(samples_taken) as 'Samples_Taken',
   Sum(samples_due) as 'Samples_Due',
   Sum(defects) as 'Defects',
   Sum(TempCL_Defects) as 'TempCL_Defects'

   From #Temp_OutData
   Where pug_Desc <> 'Totals' 
   and Frequency like 'g) Totals_W_O_Recipe%' 
   Group By Plant,Line,Team,Shift,Line_Status,Product_Desc

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #Temp_OutData'
			   Return
			END  
 
End
--**********************************************************************************
-- End of insert back Total WO Repcipe Column here
--**********************************************************************************

--************************************************************************************************
-- Show summary level record set
--************************************************************************************************

If Exists(Select * From #Temp_OutData)
		Select Result_on,Plant,Line,Team,Shift,Line_Status,Pug_Desc,Frequency,Product_Desc,
		Percent_Compliance, Percent_Completed,Percent_TempCLCompliance, Samples_Taken,Samples_Due,
		Defects, TempCL_Defects,@in_StartTime as Start_Time,@in_EndTime as End_Time
		From #Temp_OutData
Else
		Select NULL as Result_on,
			   @Plant_Name as Plant,
			   '' as Line, '' as Team,'' as Shift,'' as Line_Status,'None' as Pug_Desc,
			   'No Data' as Frequency,'' as Product_Desc,
			   '' as Percent_Compliance, '' as Percent_Completed,'' as Percent_TempCLCompliance, '' as Samples_Taken,
			   '' as Samples_Due,
			   '' as Defects, '' as TempCL_Defects,@in_StartTime as Start_Time,@in_EndTime as End_Time
		
--************************************************************************************************
-- end show summary lever record set
--************************************************************************************************
--select '#outdata antes de borrar',* from #outdata

Truncate Table #Outdata -- WHERE Pug_Desc = 'Totals'
--************************************************************************************************
-- Insert the "Detail Records" into the output table
--************************************************************************************************
Insert Into #OutData
(Plant, Line, PU_Group, Team, Shift, Line_Status, Frequency,
Result_on, Result, LS, LC, LW, TARGET, UW, UC, US, 
Samples, Samples_Due, Future_Samples_Due, Defects, 
Product_Desc, Master, Var_Desc, Pug_Desc, var_id, Due_Complete, Prod_Code, Next_Start_Date, Ext_Info,
TimeStamp,Action_Comment,Action,Cause)

Select @Plant_Name, Line, Pug_Desc, Team, Shift, Line_Status, Frequency,
 Result_On, 
(Case IsNumeric(Result) when 1 then Result else NULL end ), 
(Case IsNumeric(l_reject) when 1 then l_reject else NULL end ),
(Case IsNumeric(l_warning) when 1 then l_warning else NULL end),
(Case IsNumeric(l_user) when 1 then l_user else NULL end ),
(Case IsNumeric(target) when 1 then target else NULL end ),
(Case IsNumeric(u_user) when 1 then u_user else NULL end ),
(Case IsNumeric(u_warning) when 1 then u_warning else NULL end ),
(Case IsNumeric(u_reject) when 1 then u_reject else NULL end ),
Samples_Taken, Samples_Due, Future_Samples_Due, Defects, 
Prod_Desc, 1, Var_Desc, Pug_Desc, var_id, 0,Prod_Code, Next_Start_Date, Ext_Info,
Convert(datetime,Result_on),Action_Comment,Action,Cause
From #All_VARIABLES 
WHERE Include_Result = 'Yes'

 If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #OutData'
			   Return
			END  


Set @nCounterAll = (select count(*) from #outdata)

If @nCounterAll = 0 or @nCounterAll is null
Begin
	Insert into #outdata (samples_due,no_samples_taken)
	Values(0,'True')

    If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #OutData'
			   Return
			END  
 
End 

--************************************************************************************************
-- Update the Product_Desc field of the master records to prevent duplicate
-- records in the output set based on multiple products
--************************************************************************************************

Update #Outdata
Set Product_Desc = 'Master Record'
Where master = 0

        If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Update #OutData'
			   Return
			END  


--************************************************************************************************
-- Building SQL Sentence for defects
--************************************************************************************************

Insert Into #OutData
(Plant, Line, PU_Group, Team, Shift, Line_Status, Frequency,
Result_on, LS, LC, LW, TARGET, UW, UC, US, 
Samples, Samples_Due, Future_Samples_Due, Defects, 
Product_Desc, Master, Var_Desc, Pug_Desc, var_id, Due_Complete, Prod_Code, Next_Start_Date, Ext_Info,
TimeStamp)

Select @Plant_Name, Line, Pug_Desc, Team, 0, Line_Status, Frequency,
'Master', 
(Case IsNumeric(l_reject) when 1 then l_reject else NULL end ),
(Case IsNumeric(l_warning) when 1 then l_warning else NULL end),
(Case IsNumeric(l_user) when 1 then l_user else NULL end ),
(Case IsNumeric(target) when 1 then target else NULL end ),
(Case IsNumeric(u_user) when 1 then u_user else NULL end ),(Case IsNumeric(u_warning) when 1 then u_warning else NULL end ),
(Case IsNumeric(u_reject) when 1 then u_reject else NULL end ),
Samples_Taken, Samples_Due, Future_Samples_Due, Defects, 
Prod_Desc, 0, Var_Desc, Pug_Desc, var_id, 0,Prod_Code, Next_Start_Date, Ext_Info,
'01/01/00 7:30:00 AM'
FROM #ALL_VARIABLES
WHERE Defects = 1 --Or Samples_Taken = 0 -- DJM 16 June 2005 -  Commented out the Samples Taken statement. Do not want to include Samples Missed in Defects.
AND		Include_Result = 'Yes' 	

 If @@Error <> 0
			BEGIN
			   
			   Select 'Error in Insert #OutData'
			   Return
			END  

-- Select Convert(float,l_reject),* From #All_Variables Where Defects = 1 and Var_Id = 5500

-- Update the Timestamp field
--Update #OutData
--	Set TimeStamp = (Case Result_On When 'Master' Then '01/01/00 7:30:00 AM'
--			  Else Convert(datetime,Result_on) End)
--************************************************************************************************
-- Building SQL Sentence Defects Record Set
--************************************************************************************************
-- declare @strSQL nvarchar(4000) 
-- declare @strWHERE nvarchar(1000)
declare @strGROUPBY nvarchar(1000)
declare @strORDERBY nvarchar(1000)
--
set @strSQL = 
'Select top 10000 tod.Plant, tod.Line, tod.pug_desc, '''+'None'+''' as Team, Shift,'''+
'None' +''' as Line_Status,''' +
'None' + ''' as PRODUCT_DESC, tod.var_id, tod.var_desc, tod.Master,'+
-- 'TimeStamp as Result_on,'+

' ' + 'convert(varchar,year(TimeStamp)) + ''' +'-'+ 
''' + Case Len(convert(varchar,month(Timestamp))) When 2 Then convert(varchar,month(Timestamp)) Else ''' + '0' + ''' + convert(varchar,month(Timestamp)) End  + ''' + '-' + 
''' + Case Len(convert(varchar,day(timestamp))) When 2 Then convert(varchar,day(timestamp)) Else ''' + '0' + ''' + convert(varchar,day(timestamp)) End  + ''' + 
' ' + ''' + Case Len(convert(varchar,datepart(hh,Timestamp))) When 2 Then convert(varchar,datepart(hh,Timestamp)) Else '''+ '0' + ''' + convert(varchar,datepart(hh,Timestamp)) End + ''' +
':'+ 
''' + Case Len(convert(varchar,datepart(mi,Timestamp))) When 2 Then convert(varchar,datepart(mi,Timestamp)) Else ''' + '0' + ''' + convert(varchar,datepart(mi,Timestamp)) End as Result_On ,' +


' tod.result,'+
' tod.ls, tod.target, tod.us, Sum(tod.samples) as samples, Action, Cause, Action_Comment'+
' FROM #OutData tod  ' 

set @strGROUPBY = ' GROUP BY tod.Result_on,tod.Plant, tod.Line, tod.pug_desc, tod.var_id, tod.var_desc, tod.Master,'+
' tod.result_on, tod.result, tod.ls, tod.target, tod.us, Action, Cause,'+
' Action_Comment,tod.Shift,TimeStamp'

set @strORDERBY = ' ORDER BY tod.pug_desc, tod.var_id, tod.master ASC,TimeStamp, tod.Shift,tod.us,tod.ls,tod.target'

--************************************************************************************************
-- Shiftly Defect Record Set
-- select '----> Defects '
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Shiftly Defects' 

set @strWHERE = ' WHERE (Frequency = ''' + 'a) Shiftly Manual' + ''' Or Frequency = '''+ 'b) Shiftly Auto' + ''')' +
' AND tod.defects > 0' -- +
--' AND tod.samples <> 0)'			--- DJM 16 June 2005 -  Do not add Missed samples
-- Print (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)

--************************************************************************************************
-- Daily Defect Record Set
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Daily Defects' 

set @strWHERE = ' WHERE Frequency = ''' + 'c) Daily' +''''+
' AND tod.defects > 0'-- +
--' AND tod.samples <> 0)'			--- DJM 16 June 2005 -  Do not add Missed samples

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)

--************************************************************************************************
-- Weekly Defect Record Set
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Weekly Defects' 

set @strWHERE = 'WHERE Frequency = ''' + 'd) Weekly' + '''' +
' AND tod.defects > 0' -- +
--' OR tod.samples = 0)'			--- DJM 16 June 2005 -  Do not add Missed samples

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Monthly Defect Record Set
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Monthly Defects' 

set @strWHERE = ' WHERE Frequency = ''' + 'e) Monthly' + '''' +
' AND tod.defects > 0' --+
--' OR tod.samples = 0)'			--- DJM 16 June 2005 -  Do not add Missed samples

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Quarterly Defect Record Set
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Quarterly Defects' 

set @strWHERE = ' WHERE Frequency = ''' + 'f) Quarterly' + '''' +
' AND tod.defects > 0' --+
--' OR tod.samples = 0)'			--- DJM 16 June 2005 -  Do not add Missed samples

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Recipe Defect Record Set
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Recipe Defects' 

set @strWHERE = ' WHERE Frequency = ''' + 'h) Recipe' + '''' +
' AND tod.defects > 0' -- +
--' OR tod.samples = 0)'			--- DJM 16 June 2005 -  Do not add Missed samples
--' AND tod.defects > 0'+
--' AND tod.samples <> 0'

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)

--************************************************************************************************
-- Building SQL Sentence Missing Sample Record Set
--************************************************************************************************

set @strSQL = ' Select tod.TimeStamp as Result_On,tod.Plant, tod.Line, tod.pug_desc,' +
' tod.var_desc,' +
' Sum(tod.samples_due)- Sum(tod.due_complete) as samples,' +
' Action, ' +
' Cause,' +
' Action_Comment' +
' FROM #OutData tod   ' 


set @strGROUPBY = ' GROUP BY tod.TimeStamp,tod.Plant, tod.Line, tod.pug_desc,' +
' tod.var_desc,' +
' tod.Action, ' +
' tod.Cause, ' +
' tod.Action_Comment '
 
set @strORDERBY = ' ORDER BY tod.pug_desc, tod.var_desc '

-- If the Result_On is greater than Next_Start_Time (OverDue date) then the sample is missed
--************************************************************************************************
-- Shiftly Missing Sample Record Set
-- select '----> Samples Missing '
-- select 'Shiftly',* from #outdata where var_id = 144855
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Shiftly Missing Samples' 

set @strWHERE = 'WHERE (Frequency = ''' + 'a) Shiftly Manual' + ''' Or Frequency = '''+ 'b) Shiftly Auto' + ''')' +
' AND tod.samples_due > tod.Samples AND tod.future_samples_due = 0 ' +
-- ' AND CONVERT(datetime, tod.Result_On)<= tod.Next_Start_Date ' + REsult_on = Next_Start_Date
-- ' AND CONVERT(datetime, tod.Result_On) >= tod.Next_Start_Date ' +
' AND tod.Master = 1' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)

 --print @strSQL + @strWHERE + @strGROUPBY + @strORDERBY
--************************************************************************************************
-- Daily Overdue = Missing Sample Record Set 
-- select 'Daily'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Daily Missing Samples' 

set @strWHERE = ' WHERE Frequency = ''' + 'c) Daily' +''''+
' AND tod.samples_due > tod.Samples AND tod.future_samples_due = 0 ' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Weekly Missing Sample Record Set
-- select 'Weekly'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Weekly Missing Samples' 

set @strWHERE = ' WHERE Frequency = ''' + 'd) Weekly' + '''' +
' AND tod.samples_due > tod.Samples AND tod.future_samples_due = 0 ' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Monthly Missing Sample Record Set
-- select 'Monthly'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Monthly Missing Samples' 

set @strWHERE = ' WHERE Frequency = ''' + 'e) Monthly' + '''' +
' AND tod.samples_due > tod.Samples AND tod.future_samples_due = 0 ' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Quarterly Missing Sample Record Set
-- select 'Quarterly'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Quarterly Missing Samples' 

set @strWHERE = ' WHERE Frequency = ''' + 'f) Quarterly' + '''' +
' AND tod.samples_due > tod.Samples AND tod.future_samples_due = 0 ' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Recipe Missing Sample Record Set
-- select 'Recipe'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Recipe Missing Samples' 

set @strWHERE = ' WHERE Frequency = ''' + 'h) Recipe' + '''' +
' AND tod.samples_due > tod.Samples AND tod.future_samples_due = 0 ' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Building SQL Sentence Samples Not Yet Due / Not Complete
-- select '----> Not Yet Due / Not Complete '
--************************************************************************************************

set @strSQL = ' Select tod.Plant, tod.Line, tod.pug_desc,' +
' tod.var_desc,' +
' Sum(tod.samples_due)- Sum(tod.due_complete) as samples,' +
' Action, ' +
' Cause,' +
' Action_Comment,' +
' Substring(Ext_Info, CHARINDEX('''+ 'TT='+ ''', Ext_Info), 9) as TT_Value' +
' FROM #OutData tod  ' 

set @strGROUPBY = ' GROUP BY tod.Plant, tod.Line, tod.pug_desc, ' +
' tod.var_desc, Action, Cause, Action_Comment, ' +
' Substring(Ext_Info, CHARINDEX(''' +'TT='+ ''', Ext_Info), 9) ' 

set @strORDERBY = ' ORDER BY tod.pug_desc, tod.var_desc'

--************************************************************************************************
-- Shiftly Samples Not Yet Due / Not Complete
-- select 'Shiftlys'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Future Shiftly Samples To Be Completed' 

set @strWHERE = 'WHERE (Frequency = ''' + 'a) Shiftly Manual' + ''' Or Frequency = '''+ 'b) Shiftly Auto' + ''')' +
' AND tod.Samples_Due = 1 and tod.Samples = 0 and tod.Future_Samples_Due = 1' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Daily Samples Not Yet Due / Not Complete
-- select 'Dailys'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Future Daily Samples To Be Completed' 

set @strWHERE = ' WHERE Frequency = ''' + 'c) Daily' +''''+
' AND tod.Samples_Due = 1 and tod.Samples = 0 and tod.Future_Samples_Due = 1' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Weekly Samples Not Yet Due / Not Complete
-- select 'Weeklys',* from #outdata where frequency like '%Weekly%' and Master = 1 
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Future Weekly Samples To Be Completed' 

set @strWHERE = 'WHERE Frequency = ''' + 'd) Weekly' + '''' +
' AND tod.Samples_Due = 1 and tod.Samples = 0 and tod.Future_Samples_Due = 1' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Monthly Samples Not Yet Due / Not Complete
-- select 'Monthlys'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Future Monthly Samples To Be Completed' 

set @strWHERE = ' WHERE Frequency = ''' + 'e) Monthly' + '''' +
' AND tod.Samples_Due = 1 and tod.Samples = 0 and tod.Future_Samples_Due = 1' +
' AND tod.Master = 1 ' 
exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Quarterly Samples Not Yet Due / Not Complete
-- select 'Quarterlys'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Future Quarterly Samples To Be Completed' 

set @strWHERE = ' WHERE Frequency = ''' + 'f) Quarterly' + '''' +
' AND tod.Samples_Due = 1 and tod.Samples = 0 and tod.Future_Samples_Due = 1' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)
--************************************************************************************************
-- Recipe Samples Not Yet Due / Not Complete
-- select 'Recipe'
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' Future Recipe Samples To Be Completed' 

set @strWHERE = ' WHERE Frequency = ''' + 'h) Recipe' + '''' +
' AND tod.Samples_Due = 1 and tod.Samples = 0 and tod.Future_Samples_Due = 1' +
' AND tod.Master = 1 ' 

exec (@strSQL + @strWHERE + @strGROUPBY + @strORDERBY)

--************************************************************************************************
-- Temp Center Line Variables
SELECT  rtt.PL_Desc,rtt.Area, rtt.Var_Desc, rtt.Start_Time, rtt.Start_Result, rtt.Cause, 
	rtt.Action, rtt.Min_Result, rtt.Max_Result, rtt.Last_Result_On, CONVERT(VarChar(250), c.Comment_Text) 
                      AS Comment_Text, t.Result,Priority
FROM    #RTTTempCLId rtt
JOIN dbo.Tests t WITH(NOLOCK) ON rtt.VarId = t.Var_Id AND rtt.Last_Result_On = t.Result_On 
LEFT JOIN Comments c WITH(NOLOCK) ON rtt.Action_Comment_ID = c.Comment_Id
ORDER BY rtt.Area, rtt.Var_Desc
--************************************************************************************************
Print convert(varchar(25), getdate(), 120) + ' END OF SP' 

Drop table #Tests
Drop Table #Time_Frames
Drop Table #All_Variables
Drop Table #Pre_Var_IDs
Drop Table #PL_IDs
Drop Table #OUTDATA
Drop Table #Temp_OutData
Drop Table #PLStatusDescList
Drop Table #RTTTempCLId
Drop Table #Var_Specs



Return

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[spLocal_ReportsRTT_Execp]  TO [LocalUser]
GO
GRANT EXECUTE ON [dbo].[spLocal_ReportsRTT_Execp] TO OPDBManager
GO
GRANT EXECUTE ON [dbo].[spLocal_ReportsRTT_Execp] TO ThingWorx
GO