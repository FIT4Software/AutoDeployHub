

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER OFF
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_Centerline30',
		@Inputs		= 15, 
		@Version	= '3.0.37'  


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


-------------------------------------------[Drop Existing SP]--------------------------------------
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE Id = object_id(N'[dbo].[spLocal_Centerline30]') AND OBJECTPROPERTY(Id, N'IsProcedure') = 1)
	BEGIN
		DROP PROCEDURE [dbo].[spLocal_Centerline30]
	END
GO

-----------------------------------------------------------------------------------------------------------------------
-- 	Report Name : Centerline Exception Report														  	
-----------------------------------------------------------------------------------------------------------------------
--	SP Version :3.0 

--	Version history:
--	=============
--	Version Who					When			Description
--  3.0		Fernando Rio		2018-02-25		New Version created for Centerline 3.0
--  3.0		Fernando Rio		2018-04-09		Make RTT Auto show under the Shiftly Auto Section of the Report.
--			Fernando Rio		2018-04-10		Make the Alarm to match the REsult_On of the column
--  3.0		Fernando Rio		2018-04-12		Changed the way to identify Attribute Checks vs Variable Checks to avoid issues with the Data Type.
--  3.0		Fernando Rio		2018-04-20		Fix a small issue with temporary CL Filter
--  3.0		Fernando Rio		2018-04-25		Prevent having RTT UDP to other tables that are not Variables
--  3.0		Fernando Rio		2018-04-30		Corrected typo on Specs assignment 'VARIABLES' to 'VARIABLE'
--  3.0		Damian Campana		2018-05-04		Fix Line Status, Team & Shift Filter
--	3.0		Fernando Rio		2018-05-07		Fix the multiplication of the alarms 
--	3.0		Damian Campana		2018-05-08		Add HSE Tag filter
--	3.0		Damian Campana		2018-05-09		Display one record for each alarm
--	3.0		Santiago Gimenez	2018-05-21		Added GroupBy and Product code filter
--	3.0		Santiago Gimenez	2018-05-22		Fixed start and end time of Time_Frames to only have times inside input scope.
--	3.0		Santiago Gimenez	2018-05-23		Add Q-Factor, Recipe, PUGroup, Department, Cause & Action
--	3.0		Santiago Gimenez	2018-05-24		Add Columns Start Result, End Result, Cause Comment, Action Comment, Min and Max Result, Last Checked, 
--												Last Result, ProdCode and ProdDesc to ResultSet 2 (Alarms)
--	3.0		Santiago Gimenez	2018-05-28		Adapted Daily and Quarterly variables for CL 3.0.
--	3.0		Santiago Gimenez	2018-05-29		Adapted Recipe and Weekly variables for CL 3.0.
--	3.0		Santiago Gimenez	2018-06-08		Extended PL_Desc field size, adapted STLS UDP for Prod_Lines.
--	3.0		Santiago Gimenez	2018-06-25		Added all open alarmas, regardless scope time.
--	3.0		Santiago Gimenez	2018-06-26		Change scope of Recipe variables IF scope is > 7 days AND Recipe vars are selected.
--	3.0		Santiago Gimenez	2018-06-26		Crew schedule is taking up to the max end time available.
--	3.0		Santiago Gimenez	2018-06-29		Corrected PUGroup for Open Alarms.
--	3.0		Santiago Gimenez	2018-07-02		Enabled the code to process non-numeric data-types.
--	3.0		Santiago Gimenez	2018-07-03		Return empty alarm table if is Recipe.
--									16:56		Monthly variables are working.
--									18:17		Alarms will check against #Time_Frames table and not @inStartTime and @inEndTime.
--	3.0		Santiago Gimenez	2018-07-04		Monthly variables get the start time from Begining of month. Not from events.
--	3.0		Santiago Gimenez	2018-07-05		Fixed Quarterly variables and End time on alarms is working now.
--	3.0		Santiago Gimenez	2018-07-09		Fixed CPE variables not showing with Last 7 Days and Yesterday.
--	3.0		Santiago Gimenez	2018-07-10		If #All_Variables grid is empty, insert a NULL row.
--	3.0		Santiago Gimenez	2018-07-12		Code is working with Change Over.
--	3.0		Santiago Gimenez	2018-07-13		Team and Shift filter only works for Shiftly variables.
--	3.0		Santiago Gimenez	2018-07-16		Fixed CPE variables scope.
--	3.0		Santiago Gimenez	2018-07-19		Corrected Recipe Variables scope.
--	3.0		Santiago Gimenez	2018-07-20		Added Test Confirm capability.
--	3.0		Santiago Gimenez	2018-08-01		Remove Test Confirm variable from results. #This change got obsolete when @Sheets table got removed.
--	3.0		Santiago Gimenez	2018-08-02		Added 5 mins of tolerance for product changes.
--	3.0		Santiago Gimenez	2018-08-10		Daily variables consider the whole day regardless the TestTime UDP.
--												Replaced SPCMN_ReportCollectionParsing for Split Function.
--	3.0		Santiago Gimenez	2018-08-15		Added Offsets table.
--												Daily variables are using the start time of the shift.
--	3.0		Santiago Gimenez	2018-08-16		Remove CPE variables IF Start Date is >= than first shift of end day.
--	3.0		Santiago Gimenez	2018-08-17		Add missing results on #All_Variables.
--												Removed 5 mins as it's been replaced.
--	3.0		Santiago Gimenez	2018-08-21		Limit shiftly and daily variables up to date.
--	3.0		Santiago Gimenez	2018-08-22		Remove variables where sample time is bigger than day if time option requires.
--												Created table for closed alarms.
--	3.0		Santiago Gimenez	2018-08-23		Fixed Due Samples.
--	3.0		Santiago Gimenez	2018-08-28		Replaced views for tables and nolock.
--	3.0		Santiago Gimenez	2018-08-30		Set End_Time = @InEndTime for Daily Variables.
--	3.0		Santiago Gimenez	2018-09-03		Added ActiveOn column.
--	3.0		Santiago Gimenez	2018-09-04		Readded filters for all groupings.
--	3.0		Santiago Gimenez	2018-09-05		Product Filter affects only shiftly variables. 
--												One day is removed from Due_Date if it's bigger than Result_On.
--												Daily variables take current end time to previous 24hrs.
--	3.0		Santiago Gimenez	2018-09-12		Recipe variables should look to the First Shift.
--	3.0		Santiago Gimenez	2018-10-02		Alarms are getting their Priority from Rule Priority and not from Alarm template.
--	3.0		Santiago Gimenez	2018-10-17		Changed Conv_Id for PU_Id as some lines don't use STLS.
--	3.0		Santiago Gimenez	2018-10-23		Added AppVersions and capability for Line Status with space after colon.
--	3.0		Santiago Gimenez	2018-11-05		Fixed Line Status from Local_PG_Line_Status.
--	3.0		Daiana Barzola		2018-11-22		Fixed Action and Cause comments.
--	3.0		Santiago Gimenez	2018-11-22		Improve join for results.
--	3.0		Santiago Gimenez	2019-02-11		Create more Temp Tables for data gathering to improve performance.
--  3.0.1	Santiago Gimenez	2019-09-26		(FO-04106) Replace default value for Is_Reported on #Pre_Var_Ids.
--	3.0.1	Santiago Gimenez	2019-10-10		Removed ShiftLength as was not being used anywhere else in the code.
--												Added missing NOLOCK.
--												Removed dead code.
--	3.0.2	Santiago Gimenez	2019-10-28		(FO-04200) Replace WHILE with JOIN to improve performance.
--  3.0.2	Santiago Gimenez	2020-02-03		(FO-04200) Remove Alarms table from JOIN, add Cause and Action in @ClosedAlarms. Add Group By on #Event_Reasons.
--	3.0.3	Santiago Gimenez	2020-02-03		Add Alarm type input.
--	3.0.3	Santiago Gimenez	2020-03-28		Avoid having repeated open alarms.
--	3.0.3	Santiago Gimenez	2020-04-23		FO-04376: BRD22 - Add OOS depending on SpecificationSettings in Site Parameters.
--	3.0.4	Camila Olguin		2020-05-05		BRD72 - Add Frequency
--	3.0.5	Juan Pisani			2020-05-05		BRD92 - Add KPIs Summary section.
--	3.0.6	Santiago Gimenez	2020-06-25		BRD36 - Add QCL Events capability.
--	3.0.7	Camila Olguin		2020-08-12		BRD60 - Add PO columns.
--  3.0.8   Santiago Gimenez    2020-09-16      Query AuditFreq from Event_Subtypes table.
--												Add DefaultTestTime.
--												Calculate TestTime as the first shift of the start of the period for CPE variables if TestTime is null.
--												Move RTT_Recipe to production groups.
--  3.0.9	Santiago Gimenez	2020-12-01		Add Family Care compatibility.
--	3.0.10	Santiago Gimenez	2021-01-22		Add VersionSelection.
--	3.0.11	Santiago Gimenez	2021-03-12		Add compatibility with Centerline 2.
--  3.0.12	Gonzalo Luc			2021-04-12		Fix Defect 78 when no crew schedule get the fist shift available in the time period selected.
--  3.0.13	Gonzalo Luc			2021-04-16		Fix Defect 76 RTT_Reported = 0 correctly filtered on the variables update.
--  3.0.14	Gonzalo Luc			2021-04-23		Fix get variables for 3.0 version.
--	3.0.15	Santiago Gimenez	2021-04-28		Fix Shiftly Auto typo.
--												Join TestConfirm result with AllVariables on ResultOn
--	3.0.16	Santiago Gimenez	2021-04-29		Add compatibility on Recipe for 3.1
--	3.0.17	Santiago Gimenez	2021-05-03		Remove Test Confirm variable from results.
--	3.0.18	Alan Leontes		2021-05-14		Added a version handler to use Var_Id or EventSubtypeId
--	3.0.19	Alan Leontes		2021-05-18		@Freq parameter max lenght increased and #CType now contemplates the @InReportType = 'All'
--  3.0.20	Gonzalo Luc			2021-05-24		Fix alarm fetch, get all open alarms that where created within the timeframe of the report 
-- 												and all closed alarms that close after the report timeframe
--	3.0.21	Alan Leontes		2021-05-28		Add condition to check when @InProcessOrder is distinct to 'All'
--  3.0.22	Gonzalo Luc			2021-06-15		Validation for 3.0 variables when 3.1 version is selected.
--  3.0.23  Gonzalo Luc			2021-06-22		Remove weekly, monthly and quarterly timefreames when user defined is selected.
--  3.0.24  Gonzalo Luc			2021-07-13		Fix when @columnsTobeIncluded = 0 get always the first column
--  3.0.25	Gonzalo Luc			2021-07-28		Filter alarms according to the filters related to the group.
--  3.0.26	Gonzalo Luc			2021-08-25		fix update tempcl field to account for actions as well.
--  3.0.27	Gonzalo Luc			2021-11-03		Fix line status when test time is prior start time of the report.
--  3.0.28	Gonzalo Luc			2022-01-12		Fix duplicated alarms due Temp CL Reasons
--  3.0.29	Gonzalo Luc			2022-01-22		Fix default shift desc issue
--  3.0.30	Gonzalo Luc			2022-05-26		Remove Local_PG_Line_Status reference.
--  3.0.31	Gonzalo Luc			2023-01-26		Change PO and Prod input to VARCHAR(MAX
--  3.0.32	Gonzalo Luc			2023-03-06		Fix OAVariables and ClosedAlarms tables join with Crew_Schedule.
--  3.0.33	Pablo Galanzini	    2023-03-20		Use the UDP 'STLS_ST_MASTER_UNIT_ID' to get the scheduled unit in the line and units
--  3.0.34	Pablo Galanzini	    2023-03-29		Fix a bug to retrieve the Units used to group by Workcell.
--  3.0.35	Santiago Garcia	    2023-03-29		add logic to Slave Units
--  3.0.36	Camila Olguin	    2023-05-15		Fix to get the crew scheduled unit in the line and units
--  3.0.37	Santiago Garcia	    2023-05-15		add logic to identify Master and Slave units 
-----------------------------------------------------------------------------------------------------------------------
-- !!!!!!!!!! TO VIEW THIS SP PLEASE SET TAB SPACING TO 4
-----------------------------------------------------------------------------------------------------------------------

--================================================================================================
 CREATE PROCEDURE [dbo].[spLocal_Centerline30]
--================================================================================================
--DECLARE		
			@InLineDesc 			NVARCHAR(250),		--	Equipment			
			@InCrew            		VARCHAR(1250),   	--	Team
			@InShift           		VARCHAR(30),		--	Shifts
			@InTimeOption			VARCHAR(20),		--	TimeWindow
			@InStartTime 			DATETIME,			--	Start
			@InENDTime				DATETIME,			--	End
			@InReportType			VARCHAR(20),	    --	'Recipe', 'NonRecipe' or 'All'
			@QFactorOnly			BIT			,		--	Filter on Q Factors
			@HSETag					BIT			,		--	Filter on HSE Tag
			@InLineStatus			VARCHAR(600),		--	Line Status or 'All'
			@InGroupBy				VARCHAR(25),		--	'Product','Team','Line','Workcell'
			@InProdCode				VARCHAR(MAX),		--	Products
			@AlarmType				NVARCHAR(30),		--	'All', 'Open' or 'AHistory' 
			@Freq					VARCHAR(1000),		--	
			@KPISummary				BIT = 0,			--	Show KPI Summary. 0 = Usual report output (centerline variables + alarms) | 1 = KPIs Summary output only
			@InProcessOrder			VARCHAR(MAX),			--	Process Order
			@columnsTobeIncluded	BIT = 1,			-- If 1 everything is included.
			@VersionSelection		VARCHAR(5)


WITH ENCRYPTION 
AS
SET NOCOUNT ON

 --SELECT 
 --			@InLineDesc 		='2743',
 --			@InCrew            	='D',
 --			@InShift           	='1',
 --			@InTimeOption		='Last3Hours',
 --			@InStartTime 		='2023-03-08 12:05:27',
 --			@InENDTime			='2023-03-08 15:05:27',
 --			@InReportType       ='NonRecipe',
 --			@QFactorOnly		= 0,
 --			@HSETag				= 0,
 --			@InLineStatus       ='Not Specified,PR In: EO Shippable,PR In: Line Normal,PR In: Line Project,PR In: Qualification,PR Out: Brand Project,PR Out: EO Non-Shippable,PR Out: Line Not Staffed,PR Out: Project Construct,PR Out: STNU,PR Out: STNU Schedule Var',
 --			@InGroupBy			='WorkCell',
 --			@InProdCode			='10312',
 --			@AlarmType			='All',
 --			@Freq				='Shiftly Auto,QCL Auto,Shiftly Manual,QCL Manual,Daily,Weekly,Monthly,Quarterly',
 --			@KPISummary			= 0,
 --			@InProcessOrder		='357129',
 --			@VersionSelection 	='3.1',
	--		@columnsTobeIncluded = 1

-----------------------------------------------------------------------------------------------------------------
-- CREATE ALL TEMPORARY TABLES
-----------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb..#Parsed_PUIDs') IS NOT NULL
BEGIN
	DROP TABLE #Parsed_PUIDs
END

CREATE TABLE #Parsed_PUIDs (
			 RCDID					INT
			,PUId					INT
)

IF OBJECT_ID('tempdb..#PL_IDs') IS NOT NULL
BEGIN
	DROP TABLE #PL_IDs
END

CREATE TABLE #PL_IDs (
			 RCDID   				INT IDENTITY (1,1)
			,PL_Desc 				NVARCHAR(200)
			,PL_id  				INT
			,PU_ID  				INT
			,Conv_ID 				INT
			--,LineStarts				DATETIME
			,ProdStarts_PUId		INT 
			,PUID_CS				INT NULL
) 


IF OBJECT_ID('tempdb..#PU_IDs') IS NOT NULL
BEGIN
	DROP TABLE #PU_IDs
END

CREATE TABLE #PU_IDs (
			 RCDID   				INT
			,PL_Desc 				NVARCHAR(50)
			,PL_id					INT
			,PU_ID  				INT
			,Conv_ID 				INT
			--,LineStarts				DATETIME
			,MasterUnit				INT
			,PUID_CS				INT NULL
)


IF OBJECT_ID('tempdb..#PLStatusDescList') IS NOT NULL
BEGIN
	DROP TABLE #PLStatusDescList
END

CREATE TABLE #PLStatusDescList (
			 RCDID 					INT
			,PLStatusDesc 			NVARCHAR(50)
			,RemSpace				INT DEFAULT 0
)


IF OBJECT_ID('tempdb..#Pre_Var_IDs') IS NOT NULL
BEGIN
	DROP TABLE #Pre_Var_IDs
END

CREATE TABLE #Pre_Var_IDs (
			 PU_Id  				INT
		    ,PUG_Id          		INT
		    ,PUG_Desc				NVARCHAR(50)
		    ,Var_ID 				INT
		    ,Var_Desc     			NVARCHAR(250)
		    ,Data_Type_Id			NVARCHAR(20)
			,Data_Source_Id			INT
		    ,Var_Type				NVARCHAR(20)
		    ,Frequency				NVARCHAR(20)
		    ,Is_Reported			NVARCHAR(20) DEFAULT 1
		    ,Is_Recipe	        	NVARCHAR(20)
			,EventSubTypeId			INT	
)
CREATE NONCLUSTERED INDEX IDX_VarId
ON #Pre_Var_Ids(Var_Id) ON [PRIMARY]


IF OBJECT_ID('tempdb..#Time_Frames') IS NOT NULL
BEGIN
	DROP TABLE #Time_Frames
END

CREATE TABLE #Time_Frames (
			 PL_ID					INT
			,PU_Id					INT
			,PU_Desc				NVARCHAR(50)
			,Frequency 				NVARCHAR(50)
			,Start_Time 	    	DATETIME
			,End_Time 				DATETIME
			,day_period				INT
			,Phrase_Value			NVARCHAR(50)
			,Include 				NVARCHAR(3)
			,Start_Date		        DATETIME					-- Start date for determining sample info
   	    	,End_Date		        DATETIME
			,Due_Date		        DATETIME
			,Next_Start_Date 	    DATETIME					-- Start date for determining sample info

)


IF OBJECT_ID('tempdb..#All_Variables') IS NOT NULL
BEGIN
	DROP TABLE #All_Variables
END

CREATE TABLE #All_Variables (
			AVIdx					INT IDENTITY(1,1)
			,Dept_Id				INT
			,Department				VARCHAR(100)
			,PL_ID 			        INT
			,Line			        NVARCHAR(50) 	
			,Pu_id                  INT
			,MasterPUDesc			NVARCHAR(100)
			,ChildPUDesc			NVARCHAR(100)
            ,EventSubtypeId			INT
			,Var_ID			        INT
			,Var_Type		        NVARCHAR(50) 
			,Var_Desc		        NVARCHAR(255) 
            ,Pug_Id					INT
			,Pug_Desc		        NVARCHAR(100) 
			,Test_Time		        NVARCHAR(100) 
			,Prod_ID		        INT
			,Prod_Code		        NVARCHAR(30)
			,Master			        INT							-- "Master" record indicator (0 = summary; 1 = detail)
			,Frequency		        NVARCHAR(30)				-- Eg. Shiftly, Weekly or Monthly
			,Start_Date		        DATETIME					-- Start date for determining sample info
			,End_Date		        DATETIME
			,Due_Date		        DATETIME
			,Next_Start_Date 	    DATETIME					-- Start date for determining sample info
			,Day_Period             INT		
			,Samples_Due 		    INT		
			,Future_Samples_Due	    INT				
			,Samples_Taken		    INT							-- Samples Taken (to be UPDATEd later IN code)
			,Prod_Desc		        NVARCHAR(100)				-- Product Description
			,L_Reject		        NVARCHAR(50)				-- Lower Reject Limit
			,L_Warning		        NVARCHAR(50)				-- Lower Warning Limit
			,L_User			        NVARCHAR(50)				-- User FROM Active Specs table
			,Target			        NVARCHAR(50)				-- Target for this variable FROM active specs
			,U_User			        NVARCHAR(50)
			,U_Warning		        NVARCHAR(50)
			,U_Reject		        NVARCHAR(50)
			,Result			        NVARCHAR(50)
			,Result_On		        DATETIME
			,Entry_On				DATETIME
			,On_Time				INT
			,Defects		        INT							-- Defects (to be UPDATEd later IN code)
			,Team			        NVARCHAR(15) 
			,Shift			        NVARCHAR(30) 
			,Line_Status		    NVARCHAR(100)
			,Include_Result 	    NVARCHAR(3)
			,Include_Crew 		    NVARCHAR(3)
			,Include_Shift 		    NVARCHAR(3)
			,Include_LineStatus 	NVARCHAR(3)
			,Include_Test           NVARCHAR(3)
			,Stubbed                NVARCHAR(3)
			,Canceled               INT
			,Test_Freq              INT
			,TempCL                 VARCHAR(3)
			,Sheet_id               INT
			,CurrentSpec            NVARCHAR(3)
			,Action_Comment 		VARCHAR(300)
			,Action 				VARCHAR(100)
			,Cause 					VARCHAR(100)
			,Alarm_Id				INT			
			,AckVar					INT			
			,TestConfirm			INT			
			,HSETag					INT
			,Recipe					INT
			,QFactor				INT
			,TestIdx				INT
            ,Comment				TEXT 
			,ProcessOrderiD			VARCHAR(50)
			,ProcessOrder			VARCHAR(50)

)
CREATE NONCLUSTERED INDEX IDX_VarId_ProdId_ResultOn
ON #All_Variables(Var_Id,Prod_Id,Result_On) ON [PRIMARY]


IF OBJECT_ID('tempdb..#Tests') IS NOT NULL
BEGIN
	DROP TABLE #Tests
END

CREATE TABLE #Tests (
			TestIdx					INT IDENTITY(1,1)
			,Var_id 				INT			
			,Frequency 				NVARCHAR(50)
			,Start_Date 			DATETIME	
			,End_Date 				DATETIME	
			,Result_On 				DATETIME	
			,Result 				NVARCHAR(50)
			,Entry_On				DATETIME
			,Include_Test 			NVARCHAR(3)	
			,Tested					NVARCHAR(3)
			,OnTime					INT
   			,Comment_id				INT 
			,Comment				TEXT 
)


IF OBJECT_ID('tempdb..#Alarms') IS NOT NULL
BEGIN
	DROP TABLE #Alarms
END

CREATE TABLE #Alarms (
			 PlantName				VARCHAR(200)
			,Department				VARCHAR(100)
			,Line					VARCHAR(50)	
			,MasterUnit				VARCHAR(100)
			,SlaveUnit				VARCHAR(100)
			,VarId					INT
			,VariableDescription	VARCHAR(50)
			,AlarmDescription		VARCHAR(255)
			,EquipmentUnit			VARCHAR(100)
			,Team					VARCHAR(30)	
			,Shift					VARCHAR(30)	
			,Frequency				VARCHAR(30) 
			,StartTime				DATETIME
			,EndTime				DATETIME
			,StartResult			VARCHAR(50)
			,EndResult				VARCHAR(50)
			,MinResult				VARCHAR(50)
			,MaxResult				VARCHAR(50)
			,LastCheck				DATETIME
			,LastResult				VARCHAR(50)
			,ValueOOS				VARCHAR(50)	
			,FinalValue				VARCHAR(50)	
			,RejectLimit			VARCHAR(50)	
			,Target					VARCHAR(50)	
			,UpperReject			VARCHAR(50)	
			,Status					VARCHAR(15)	
			,TempCenterline			BIT
			,QFactor				INT
			,Recipe					INT
			,Cause					VARCHAR(350)
			,CauseComments			VARCHAR(2000)
			,Action					VARCHAR(350)
			,ActionComments			VARCHAR(2000)
			,Priority				VARCHAR(20)
			,ProdCode				VARCHAR(20)
			,ProdDesc				VARCHAR(500)
			,Comment_id				INT 
			,Comment				TEXT 
			,ProcessOrderiD			VARCHAR(50)
			,ProcessOrder			VARCHAR(50)
)


IF OBJECT_ID('tempdb..#Line_Status') IS NOT NULL
BEGIN
	DROP TABLE #Line_Status
END

CREATE TABLE #Line_Status (
			LSId		INT,
			LSDesc		VARCHAR(200),
			UnitId		INT,
			StartTime	DATETIME,
			EndTime		DATETIME
)


IF OBJECT_ID('tempdb..#TC_Tests') IS NOT NULL
BEGIN
	DROP TABLE #TC_Tests
END

CREATE TABLE #TC_Tests (
			VarId		INT,
			Result		NVARCHAR(50),
			ResultOn	DATETIME
)


IF OBJECT_ID('tempdb..#EventReasons') IS NOT NULL
BEGIN
	DROP TABLE #EventReasons
END

CREATE TABLE #EventReasons(
			ReasonId		INT,
			ReasonName		NVARCHAR(800),
			ReasonType		NVARCHAR(30),
			TempCL			BIT
)


IF OBJECT_ID('tempdb..#AlarmPriority') IS NOT NULL
BEGIN
	DROP TABLE #AlarmPriority
END

CREATE TABLE #AlarmPriority(
			AlarmId			INT,
			Priority		NVARCHAR(500)
)


IF OBJECT_ID('tempdb.dbo.#CType', 'U') IS NOT NULL
BEGIN
	DROP TABLE #CType
END

CREATE TABLE #CType (
			ID				INT IDENTITY,
            CType           VARCHAR(100))


IF OBJECT_ID('tempdb..#KPISummarization') IS NOT NULL
BEGIN
	DROP TABLE #KPISummarization
END

CREATE TABLE #KPISummarization (
			--KPIdx					INT IDENTITY(1,1)
			GroupBy					NVARCHAR(50)
			,SamplesTaken			FLOAT	DEFAULT	0
			,SamplesNonRecipe		FLOAT	DEFAULT 0
			,SamplesDefects			FLOAT	DEFAULT 0
			,Completion				FLOAT	DEFAULT 0
			,Compliance				FLOAT	DEFAULT 0
			,OutCompliance			FLOAT	DEFAULT 0
			,DueChecks				FLOAT	DEFAULT 0
			,TempCenterline			FLOAT	DEFAULT 0
			,OutComplianceRecipe	FLOAT	DEFAULT 0
			,QFactorDone			FLOAT	DEFAULT 0
			,OutComplianceQFactor	FLOAT	DEFAULT 0
			,ClosedAlarms			FLOAT	DEFAULT 0
			,OpenAlarms				FLOAT	DEFAULT 0
			,NotCompletedChecks		FLOAT	DEFAULT 0
)

IF OBJECT_ID('tempdb..#ProcessOrders') IS NOT NULL
BEGIN
	DROP TABLE #ProcessOrders
END

CREATE TABLE #ProcessOrders (
			PPId		INT,
			PUId		INT,
			StartTime	DATETIME,
			EndTime		DATETIME,
			PO			VARCHAR(50),
			Prd			BIT DEFAULT 0
)
-----------------------------------------------------------------------------------------------------------------
-- CREATE ALL VARIABLES TABLES
-----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
DECLARE @QFactorTable TABLE (
		 VarId					INT					
)	

DECLARE @Temp_Variables_Without_Samples TABLE (
		 var_id					INT			
		,start_date				DATETIME	
		,End_date				DATETIME	
		,result_on				DATETIME
) 

DECLARE @Temp_Variables_With_Samples TABLE (
		 var_id					INT			
		,start_date				DATETIME	
		,End_date				DATETIME	
		,result_on				DATETIME
) 

DECLARE @OpenAlarms TABLE (
		OAIdx					INT IDENTITY(1,1)
		,AlarmId				INT			
	    ,PL_Desc                VARCHAR(100)	
	    ,VarId                  INT		
		,MasterDesc				VARCHAR(200)
	    ,Area                   VARCHAR(50)	
	    ,Var_Desc               VARCHAR(250)
		,Alarm_Desc				VARCHAR(250)	
	    ,Start_Time             DATETIME		
		,EndTime				DATETIME		
	    ,Start_Result           NVARCHAR(25)
		,End_Result				NVARCHAR(25)	
	    ,Cause                  VARCHAR(350)
		,Cause_Comment_ID		INT
		,CauseComments			VARCHAR(2000)	
	    ,Action                 VARCHAR(350)
	    ,Action_Comment_ID      INT
		,ActionComments			VARCHAR(2000)			
	    ,Min_Result             VARCHAR(25)	
	    ,Max_Result             VARCHAR(25)	
	    ,Last_Result_On         DATETIME
		,Last_Result			VARCHAR(50)		
	    ,Priority               NVARCHAR(10)	
		,IsTempCL				BIT	
		,Comment_id				INT
		,Comment				TEXT
		,ProcessOrderiD			INT
		,ProcessOrder			VARCHAR(50)		
		,CauseId				INT
		,ActionId				INT
)

DECLARE @Production_Starts  TABLE  (
	 	 Pu_id					INT
		,Prod_id				INT 
		,Prod_Code				NVARCHAR(50)
		,Prod_Desc				NVARCHAR(200)  
		,Start_Time				DATETIME 
		,End_Time				DATETIME
)

DECLARE @tblHSETag TABLE (
		 Var_Id					INT
		,Var_Desc				VARCHAR(200)
)

DECLARE	@NonProdTime TABLE (
		 NPTIdx					INT	IDENTITY	
		,StartTime				DATETIME		
		,EndTime				DATETIME		
		,PUId					INT				
		,NPReasonId				INT				
		,NPReasonName			NVARCHAR(200)	
		,Duration				FLOAT			
)

DECLARE @Units TABLE (
		UnitId					INT,
		UnitDesc				VARCHAR(200),
		MasterUnit				INT,
		MasterDesc				VARCHAR(200),
		LineId					INT,
		LineDesc				VARCHAR(200),
		DeptId					INT,
		DeptDesc				VARCHAR(200)
)

DECLARE @Products TABLE (
		ProdId					INT,
		ProdDesc				VARCHAR(300),
		ProdCode				VARCHAR(20),
		StartTime				DATETIME,
		EndTime					DATETIME
)

DECLARE @OAVariables TABLE (
		 OAVIdx					INT IDENTITY(1,1)	
		,AlarmId				INT
		,DeptDesc				VARCHAR(200)
		,LineDesc				VARCHAR(200)
		,MasterDesc				VARCHAR(200)
		,PUId					INT
		,SlaveDesc				VARCHAR(200)
		,PUGroup				VARCHAR(50)
	    ,VarId                  INT			
	    ,VarDesc				VARCHAR(250)
		,Team					VARCHAR(10)
		,Shift					VARCHAR(10)
		,Frequency				VARCHAR(200)
		,LReject				VARCHAR(20)
		,Target					VARCHAR(20)
		,UReject				VARCHAR(20)
		,ResultOOS				VARCHAR(20)
		,ResultOnOOS			DATETIME
		,QFactor				INT
		,Recipe					INT
)

DECLARE	@ClosedAlarms TABLE (
		CAIdx			INT IDENTITY(1,1),
		AlarmId			INT,
		DeptDesc		VARCHAR(200),
		LineDesc		VARCHAR(200),
		MasterDesc		VARCHAR(200),
		PUId			INT,
		SlaveDesc		VARCHAR(200),
		PUGroup			VARCHAR(50),
		VarId			INT,
		VarDesc			VARCHAR(250),
		AlarmDesc		VARCHAR(500),
		Team			VARCHAR(10),
		Shift			VARCHAR(10),
		Frequency		VARCHAR(200),
		LReject			VARCHAR(20),
		Target			VARCHAR(20),
		UReject			VARCHAR(20),
		ResultOOS		VARCHAR(20),
		ResultOnOOS		DATETIME,
		QFactor			INT,
		Recipe			INT,
		StartTime		DATETIME,
		EndTime			DATETIME,
		StartResult		VARCHAR(500),
		EndResult		VARCHAR(500),
		MinResult		VARCHAR(500),
		MaxResult		VARCHAR(500),
		TempCL			BIT,
		Cause			VARCHAR(2000),
		CauseId			INT,
		CauseCommentId	INT,
		CauseComments	NVARCHAR(2000),
		Action			VARCHAR(2000),
		ActionId		INT,
		ActionCommentId	INT,
		ActionComments	NVARCHAR(2000),
		Priority		VARCHAR(20),		
		Comment_id		INT,
		Comment			TEXT,
		ProcessOrderiD	INT,
		ProcessOrder	VARCHAR(50)
)

DECLARE @TCVars TABLE (
		SheetId				INT,
		VarId			INT
)

DECLARE @Offsets TABLE (
		UnitId				INT,
		UnitDesc			VARCHAR(200),
		Frequency			VARCHAR(20),
		Offset				INT,
		ECId				INT,
		ESId				INT,
		ESDesc				VARCHAR(200)
		)

DECLARE	@MaxResults TABLE (
		Var_Id				INT,
		Result_On			DATETIME,
		Start_Date			DATETIME,
		End_Date			DATETIME,
		Idx					INT
		)

DECLARE	@DEPREventSubtypes TABLE (
		SubtypeId			INT,
		SubtypeDesc			VARCHAR(50)
		)

DECLARE @DEPRUDE TABLE (
		Frequency			VARCHAR(200),
		EndTime				DATETIME,
		SubtypeId			INT,
		PUId				INT
		)

-----------------------------------------------------------------------------------------------------------------
-- Init temporary tables
-----------------------------------------------------------------------------------------------------------------
DECLARE @r AS INT

SET @r = (SELECT COUNT(*) FROM #PL_IDs)
SET @r = (SELECT COUNT(*) FROM #Pre_Var_IDs) 
SET @r = (SELECT COUNT(*) FROM #Time_Frames)
SET @r = (SELECT COUNT(*) FROM #All_Variables)

-----------------------------------------------------------------------------------------------------------------------------------
-- Declare Local Variables
-----------------------------------------------------------------------------------------------------------------------------------

DECLARE

	@Plant_Name		   	VARCHAR(30),
	@LocalRptLanguage	INT,
	@Pass				VARCHAR(20),
	@intTableFieldId	INT,
	@VarTableId			INT,
	@VariableTypeUDP	INT,
	@AuditFreqUDP		INT,
	@IsReportableUDP	INT,
	@IsRecipeUDP		INT,
	@AreaUDP			INT,
	@TestTimeUDP		int,
	@LinesTableId		INT,
	@Current			INT, --To be used with counters.
	@Stop				INT, --To be used with counters.
	@MaxEndCS			DATETIME,
	@LSCount			INT,
	@LSStop				INT,
	@LSIdx				INT,
	@MinStartDate		DATETIME,
	@MaxEndDate			DATETIME,
	@TempCL				INT,
	@SpecSetting		INT,
	@CurrentPPId		INT,
    @ESTableId			INT,
	@PUGTableId			INT,
	@DefaultTestTimeUDP	INT,
	@ResOn				DATETIME,
	@VersionTable		INT,
	@GroupTypeUDP		INT

-----------------------------------------------------------------------------------------------------------------------------------
-- Get SpecificationSetting from Site Parameters. If NULL use 1 (Test Value > Limit Triggers Spec Exceedence).
-----------------------------------------------------------------------------------------------------------------------------------

SELECT @SpecSetting = ISNULL(Value,1)
FROM Site_Parameters s (NOLOCK)
JOIN Parameters p (NOLOCK) ON s.Parm_Id = p.Parm_Id
WHERE p.Parm_Name = 'SpecificationSetting'

-----------------------------------------------------------------------------------------------------------------------------------
-- Get the Local Phrase value for PASS
-----------------------------------------------------------------------------------------------------------------------------------

SELECT @LocalRPTLanguage = Value FROM dbo.Site_Parameters sp WITH(NOLOCK)
	JOIN dbo.Parameters p WITH(NOLOCK) ON sp.parm_id = p.parm_id
	WHERE Parm_Name Like 'LanguageNumber'

	-- open AND close go to site_parameters table
SELECT @Pass = prompt_string FROM dbo.Language_Data WITH(NOLOCK)
	WHERE prompt_number = (SELECT Max(prompt_number) FROM language_data WITH(NOLOCK) WHERE prompt_string = 'PASS')
	AND Language_Id = @LocalRPTLanguage

IF Len(@Pass) = 0 
		SET @Pass = 'PASS'

-----------------------------------------------------------------------------------------------------------------------------------
-- Create a temp table of all PL_ID's passed to the sp for processing
-- (parses the string of line id's passed to the sp)
-----------------------------------------------------------------------------------------------------------------------------------

INSERT INTO #Parsed_PUIDs(RCDID, PUId)
SELECT Id, String FROM dbo.fnLocal_Split(@InLineDesc, ',')
		

INSERT INTO #PL_IDs ( PL_Desc, PU_ID, PL_id)
	SELECT DISTINCT pl1.PL_Desc, COALESCE(pu.Master_Unit, pu.PU_ID), pl1.PL_id
	FROM Prod_Units_Base pu WITH(NOLOCK)
	JOIN Prod_Lines_Base pl1 WITH(NOLOCK) ON pl1.PL_Id = pu.PL_Id
	JOIN #Parsed_PUIDs pu2 WITH(NOLOCK) ON pu2.PUId = pu.PU_Id 


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #PL_IDs'
	   RETURN
	END 

UPDATE pl2 
	SET PL_ID = pl.PL_ID 
FROM dbo.Prod_Lines_Base 				pl 		WITH(NOLOCK) 
JOIN #PL_Ids 						pl2		ON			pl.PL_Desc =  pl2.PL_Desc

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #PL_IDs'
	   RETURN
	END  

-----------------------------------------------------------------------------------------------------------------------------------
-- Create a temp table of all PL_ID's passed to the sp for processing
-- (parses the string of line id's passed to the sp)
-----------------------------------------------------------------------------------------------------------------------------------
INSERT @Units (UnitId, UnitDesc, MasterUnit, MasterDesc, LineId)
SELECT	u.PU_Id			,
		u.PU_Desc		,
		ISNULL(u.Master_Unit,u.PU_Id),
		ISNULL(pu.PU_Desc,u.PU_Desc),
		u.PL_Id
FROM	Prod_Units_Base u WITH (NOLOCK)
LEFT JOIN	Prod_Units_Base pu WITH (NOLOCK) ON u.Master_Unit = pu.PU_Id 
JOIN	#PL_Ids l  WITH (NOLOCK) ON (u.Master_Unit = l.PU_Id OR l.PU_Id = u.PU_Id) AND u.PL_Id = l.PL_Id


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert @Units'
	   RETURN
	END  

UPDATE u
SET LineDesc = PL_Desc,
	DeptId	= Dept_Id
FROM @Units u
JOIN Prod_Lines_Base l WITH (NOLOCK) ON u.LineId = l.PL_Id

UPDATE u
SET	DeptDesc = Dept_Desc
FROM @Units u
JOIN Departments_Base d WITH (NOLOCK) ON u.DeptId = d.Dept_Id


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update @Units'
	   RETURN
	END  

-----------------------------------------------------------------------------------------------------------------------------------
-- Create table with all products in scope.
-----------------------------------------------------------------------------------------------------------------------------------

INSERT INTO @Products 
SELECT	p.Prod_Id		,
		Prod_Desc		,
		Prod_Code		,
		Start_Time		,
		End_Time
FROM	Products_Base p WITH (NOLOCK)
LEFT JOIN	Production_Starts ps WITH (NOLOCK) ON p.Prod_Id = ps.Prod_Id AND (@InStartTime <= ps.End_Time AND (ps.End_Time < @InEndTime OR ps.End_Time IS NULL))
WHERE	p.Prod_Id IN (SELECT String FROM dbo.fnLocal_Split(@InProdCode, ','))

-----------------------------------------------------------------------------------------------------------------------------------
-- Get the STLS PU_Id using the STLS UDP and the Line Start usign the Extended Information
-----------------------------------------------------------------------------------------------------------------------------------

SET @LinesTableId		= (SELECT TableId FROM dbo.Tables WITH(NOLOCK) WHERE TableName = 'Prod_Units')

SET	@intTableFieldId = (	SELECT Table_Field_Id 
							FROM dbo.Table_Fields WITH(NOLOCK)
							WHERE Table_Field_Desc = 'STLS_ST_MASTER_UNIT_ID'
							  AND TableId = @LinesTableId)

-------------------------------------------------------------------------------------------------------------------------
--	Update ConvId for each Production Line. We will check this doing a comparison with all Production Units that
--	were flagged with STLS_ST_MASTER_UNIT_ID UDP

--	NOTE: STLS_Info temp table holds all Conv Ids for all Units that belongs to all Lines in #PL_IDs.
-------------------------------------------------------------------------------------------------------------------------
UPDATE #PL_Ids 
	SET Conv_Id = STLS_Info.Value
FROM (	SELECT KeyId, Value
		FROM dbo.Table_Fields_Values WITH(NOLOCK)
		WHERE (Table_Field_Id = @intTableFieldId
			AND KeyId IN(	SELECT pu.PU_Id
							FROM Prod_Units_Base	pu WITH(NOLOCK)
							JOIN #PL_Ids	pl	 WITH(NOLOCK) ON(pu.PU_Id = pl.PU_Id)
						)) 
	)	STLS_Info

WHERE(STLS_Info.KeyId IN (	SELECT pu.PU_Id 
							FROM Prod_Units_Base pu WITH(NOLOCK)
							JOIN #PL_Ids	plids WITH(NOLOCK)	ON(plids.PU_Id = pu.PU_Id)))
					
-- JPG
UPDATE P SET Conv_ID = (SELECT dbo.fnLocal_STI_Cmn_GetUDP(PU_ID, 'STLS_ST_MASTER_UNIT_ID', 'Prod_Units'))   
	FROM #PL_Ids P
	WHERE Conv_ID IS NULL

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #PL_IDs'
	   RETURN
	END  

UPDATE #PL_IDs 
		SET ProdStarts_PUId = ppu.PU_ID
		FROM #PL_IDs pl
		JOIN PrdExec_Path_Units ppu WITH(NOLOCK) on ppu.PU_Id = pl.PU_ID 
		
		
UPDATE #PL_IDs 
		SET ProdStarts_PUId = PU_ID
		FROM #PL_IDs 
		WHERE ProdStarts_PUId IS NULL	

---------------------------------------------------------------------------------------------------------------------
--													Line Status
---------------------------------------------------------------------------------------------------------------------

INSERT #PLStatusDescList (RCDID,PLStatusDESC)
SELECT Id, String FROM dbo.fnLocal_Split(@InLineStatus, ',')

-- Add Line Status without spaces after colon if necessary.
SELECT	@LSCount =	MIN(RCDID),
		@LSStop	 =	MAX(RCDID)
FROM	#PLStatusDescList WITH(NOLOCK)

WHILE @LSCount <= @LSStop 
BEGIN
	IF (SELECT CHARINDEX(': ',PLStatusDESC) FROM #PLStatusDescList WITH(NOLOCK) WHERE RCDID = @LSCount) > 0  
	BEGIN
		UPDATE #PLStatusDescList
		SET	RemSpace = 1
		WHERE	RCDID = @LSCount
	END
		
	SELECT @LSIdx = MAX(RCDID) + 1 FROM #PLStatusDescList WITH(NOLOCK)
	
	INSERT INTO #PLStatusDescList (RCDID,PLStatusDESC)
	SELECT	@LSIdx,
			REPLACE(PLStatusDESC, ': ',':')
	FROM	#PLStatusDescList  WITH(NOLOCK)
	WHERE	RCDID = @LSCount
	  AND	RemSpace = 1

	SET @LSCount = @LSCount + 1
END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #PLStatusDESCList'
	   RETURN
	END  
--END

---------------------------------------------------------------------------------------------------------------------
--													END Line Status
---------------------------------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------------------------------
--													Frequency
---------------------------------------------------------------------------------------------------------------------
INSERT INTO #CType(CType)
	SELECT String FROM  dbo.fnLocal_Split(@Freq, ',') 

IF @InReportType = 'Recipe' OR @InReportType = 'All'
BEGIN
	INSERT INTO #CType (CType)
	VALUES ('Recipe')
END
---------------------------------------------------------------------------------------------------------------------
--  Get the Plant Name
---------------------------------------------------------------------------------------------------------------------
SET @Plant_Name = (SELECT Value FROM dbo.Site_Parameters WITH(NOLOCK) WHERE Parm_ID = 12)

IF @Plant_Name = ''
BEGIN
	SET @Plant_Name = 'Plant Name Unavailable, Please config your site parameters'
END

---------------------------------------------------------------------------------------------------------------------
-- Build temp tables to allocate Variables to be processed
-- Get the RTT UDP for Audit Frequency, Reported, Recipe, Area and TestTime
---------------------------------------------------------------------------------------------------------------------
PRINT CONVERT(VARCHAR,GETDATE(),120) + 'START #PRE_VAR_IDS SETTINGS '

SET @VarTableId 		= (SELECT TableId FROM dbo.Tables WITH(NOLOCK) WHERE TableName = 'Variables')
SET @ESTableId			= (SELECT TableId FROM dbo.Tables WITH(NOLOCK) WHERE TableName = 'Event_Subtypes')
SET @PUGTableId			= (SELECT TableId FROM dbo.Tables WITH(NOLOCK) WHERE TableName = 'PU_Groups')
SET	@IsReportableUDP	= (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_Reported'  AND TableId = @VarTableId)
SET	@IsRecipeUDP		= (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_Recipe' AND TableId = @VarTableId)
SET @GroupTypeUDP		= (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_GroupType' AND TableId = @PUGTableId)
SET	@AreaUDP			= (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_EquipmentGroup'  AND TableId = @VarTableId)
SET	@TestTimeUDP		= (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_TestTime'  AND TableId = @VarTableId)
SET @DefaultTestTimeUDP = (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_DefaultTestTime'  AND TableId = @ESTableId)

IF @VersionSelection = '3.0'
BEGIN
	SET @VersionTable = @VarTableId
END
ELSE
BEGIN
	SET @VersionTable = @ESTableId
END

SET @AuditFreqUDP	= (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_AuditFreq' AND TableId = @VersionTable)

-- Insert all the Variables that belong to the Master Unit
INSERT INTO #Pre_Var_IDs(
			PU_Id,	
			Var_ID)
SELECT 	    pu.PU_id,
			v.Var_id
			
FROM dbo.Variables_Base				v	  	WITH(NOLOCK)		
JOIN dbo.Prod_Units_Base			pu 		WITH(NOLOCK)	ON pu.PU_Id = v.PU_Id
JOIN #PL_Ids       					pl	  	WITH(NOLOCK)	ON pl.PU_id = pu.PU_Id
JOIN dbo.Table_Fields_Values 		tfv 	WITH(NOLOCK)	ON tfv.KeyId = CASE WHEN @VersionSelection = '3.0' THEN v.Var_Id ELSE v.Event_Subtype_Id END

WHERE 	tfv.TableId = @VersionTable
		AND	tfv.Table_Field_id = @AuditFreqUDP
		AND v.var_desc NOT LIKE '%zpv%'
		AND v.var_desc NOT LIKE '%z_obs%'


-- Insert all the Variables that belong to the Child Unit
INSERT INTO #Pre_Var_IDs(
			PU_Id,	
			Var_ID)
SELECT 	    pu1.Master_Unit,
			v.Var_id 
FROM dbo.Variables_Base 			v	  	WITH(NOLOCK)		
JOIN dbo.Prod_Units_Base			pu1		WITH(NOLOCK)	ON pu1.PU_Id = v.PU_Id
JOIN dbo.Prod_Units_Base			pu2		WITH(NOLOCK)	ON pu2.PU_Id = pu1.Master_Unit
JOIN #PL_Ids       					pl	  	WITH(NOLOCK)	ON pl.PU_id = pu2.PU_Id
JOIN dbo.Table_Fields_Values 		tfv 	WITH(NOLOCK)	ON tfv.KeyId = CASE WHEN @VersionSelection = '3.0' THEN v.Var_Id ELSE v.Event_Subtype_Id END

WHERE 	tfv.TableId = @VersionTable
		AND	tfv.Table_Field_id = @AuditFreqUDP
		AND v.var_desc NOT LIKE '%zpv%'
		AND v.var_desc NOT LIKE '%z_obs%'

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Pre_Var_IDs'
	   RETURN
	END  
-----------------------------------------------------------------------------------------------------------------------------------
--Remove all the 3.0 variables when 3.1 is selected.
-----------------------------------------------------------------------------------------------------------------------------------
IF @VersionSelection = '3.1'
BEGIN
	
	DELETE FROM #Pre_Var_IDs
	WHERE Var_ID IN (   SELECT v.Var_id			
						FROM dbo.Variables_Base 			v	  	WITH(NOLOCK)		
						JOIN dbo.Prod_Units_Base			pu1		WITH(NOLOCK)	ON pu1.PU_Id = v.PU_Id
						JOIN dbo.Prod_Units_Base			pu2		WITH(NOLOCK)	ON pu2.PU_Id = pu1.Master_Unit
						JOIN #PL_Ids       					pl	  	WITH(NOLOCK)	ON pl.PU_id = pu2.PU_Id
						JOIN dbo.Table_Fields_Values 		tfv 	WITH(NOLOCK)	ON tfv.KeyId = v.Var_Id

						WHERE 	tfv.TableId = @VarTableId
								AND	tfv.Table_Field_id = (SELECT Table_Field_id FROM dbo.Table_Fields WITH(NOLOCK) WHERE Table_Field_Desc = 'RTT_AuditFreq' AND TableId = @VarTableId)
								AND v.var_desc NOT LIKE '%zpv%'
								AND v.var_desc NOT LIKE '%z_obs%')
END

-----------------------------------------------------------------------------------------------------------------------------------
--	Update variable info
-----------------------------------------------------------------------------------------------------------------------------------
UPDATE #Pre_Var_IDs 
	SET Pug_Id 		  	= pug.PUG_Id,
		PUG_Desc		= pug.PUG_Desc,
		Var_Desc 	    = v.Var_Desc,
		Data_Type_Id	= v.Data_Type_Id,
		Data_Source_id	= v.DS_Id,
		Is_Reported		= (CASE WHEN @VersionSelection = '3.0' THEN 'No' ELSE 'Yes' END),
		EventsubtypeId  = v.Event_Subtype_Id  ,
		Is_Recipe		= 'No'
FROM dbo.Variables_Base				v 		WITH(NOLOCK)
JOIN #Pre_Var_IDs 					pvids 	ON v.var_id = pvids.var_id
JOIN dbo.Data_Type 					dt 		WITH(NOLOCK) 
											ON v.Data_Type_ID = dt.Data_Type_ID
JOIN dbo.PU_Groups 					pug 	WITH(NOLOCK) 
											ON v.PUG_Id = pug.PUG_Id

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END 

----------------------------------------------------------------------------------------------------------------
-- Get Q Factor Variable List
----------------------------------------------------------------------------------------------------------------
INSERT INTO @QFactorTable(VarId)
			SELECT	KeyId 
			FROM		dbo.Table_Fields_Values TFV		WITH(NOLOCK)
			JOIN		dbo.Table_Fields TF				WITH(NOLOCK)	ON TFV.Table_Field_Id = TF.Table_Field_Id
			JOIN 		dbo.Tables	T					WITH(NOLOCK)	ON T.TableId = TF.Tableid
			JOIN		Variables_Base v				WITH(NOLOCK)	ON v.Var_Id = TFV.KeyId
			JOIN		@Units u										ON v.PU_Id = u.UnitId
			WHERE		TF.Table_Field_Desc	= 'Q-Factor Type' AND T.TABLENAME = 'Variables'
			AND		TFV.Value				IN ('Q-Task','Q-Parameter','Q-Parameters')

IF @QFactorOnly = 1
	BEGIN

		DELETE FROM #Pre_Var_IDs 
		WHERE Var_Id NOT IN (SELECT VarId FROM @QFactorTable)

	END

UPDATE #Pre_Var_IDs
	SET		Frequency	= (	CASE
							WHEN Value = 'S' THEN 'a) Shiftly Manual'
                            WHEN Value = 'A' THEN 'b) Shiftly Auto'
							WHEN Value = 'D' THEN 'c) Daily'
							WHEN Value = 'W' THEN 'd) Weekly'
							WHEN Value = 'M' THEN 'e) Monthly'
							WHEN Value = 'Q' THEN 'f) Quarterly'
							WHEN Value = 'QCLA' THEN 'g) QCL Auto'
							WHEN Value = 'QCLM' THEN 'h) QCL Manual'
							END)
FROM 		dbo.Table_Fields_Values			WITH(NOLOCK)
WHERE 		
			KeyId = CASE
						WHEN @VersionSelection = '3.0' THEN Var_Id
						ELSE EventSubtypeId
					END
			AND TableId = @VersionTable
			AND	Table_Field_id = @AuditFreqUDP

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END


UPDATE #Pre_Var_IDs
	SET		Is_Reported = CASE WHEN Value = 0 THEN 'No' ELSE 'Yes' END
FROM 		dbo.Table_Fields_Values			WITH(NOLOCK)
WHERE 		Var_Id = KeyId
			AND TableId = @VarTableId 
			AND	Table_Field_id = @IsReportableUDP

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END

IF @VersionSelection = '3.0'
BEGIN
	UPDATE #Pre_Var_IDs
		SET		Is_Recipe	= 'Yes'		--Value
	FROM 		dbo.Table_Fields_Values			WITH(NOLOCK)
	WHERE 		KeyId = Var_ID
				AND TableId = @VarTableId
				AND	Table_Field_id = @IsRecipeUDP
				AND Value = '1'
END
ELSE IF @VersionSelection = '3.1'
BEGIN
	UPDATE #Pre_Var_IDs
		SET		Is_Recipe	= 'Yes'		--Value
	FROM 		dbo.Table_Fields_Values			WITH(NOLOCK)
	WHERE 		KeyId = PUG_Id
				AND TableId = @PUGTableId
				AND	Table_Field_id = @GroupTypeUDP
				AND Value = 'Recipe'
END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END

UPDATE #Pre_Var_Ids
			SET Var_Type 	  = (CASE 
									 WHEN  dt.data_type_desc IN ('Float','Integer') THEN 'VARIABLE'
									 ELSE 'ATTRIBUTE'
								 END)
FROM 		#Pre_Var_ids pvids
JOIN 		dbo.Data_Type 			dt 		WITH(NOLOCK) 
											ON pvids.Data_Type_ID = dt.Data_Type_ID 


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END

DELETE FROM #Pre_Var_Ids 
WHERE (Var_Desc IS NULL) 
	OR (Var_Type NOT IN ('ATTRIBUTE','VARIABLE')) 
	OR (Is_Reported = 'No')
	OR (Is_Reported = '0')
	OR (Is_Reported = 'False')

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Delete #Pre_Var_IDs'
	   RETURN
	END

IF @VersionSelection = '3.0'
BEGIN
	UPDATE #Pre_Var_IDs
		Set FREQUENCY = 'b) Shiftly Auto'
	FROM #Pre_Var_IDs pvids
	JOIN dbo.Event_Subtypes es WITH (NOLOCK) ON pvids.EventSubtypeId = es.Event_Subtype_Id 
	WHERE es.Event_SubType_Desc LIKE 'RTT Auto'
END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END

-- Add all 'Recipe' and 'Recipe Dynamic' variables to a seperate grouping
-- If ReportType = 'Recipe'?

if @inReportType = 'Recipe' or @inReportType = 'All'
begin
	INSERT INTO #Pre_Var_IDs  (PU_Id ,  PUG_Id ,PUG_Desc, Var_ID 	,  Var_Desc,   Data_Type_Id,Data_Source_Id,Var_Type,Frequency,Is_Reported,Is_Recipe,EventSubTypeId)
	Select PU_Id, pug_id, PUG_Desc, Var_ID,Var_Desc, Data_Type_Id, Data_Source_Id,
	Var_Type, 				
	'h) Recipe',
	Is_Reported,
	Is_Recipe,
	EventSubTypeId
	from #Pre_Var_IDs 
	where Is_Recipe = 'Yes'

	If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Pre_Var_IDs'
	   RETURN
	END

	DELETE From #Pre_Var_IDs
	Where Frequency <> 'h) Recipe'
	and Is_Recipe = 'Yes'
	
	If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Delete #Pre_Var_IDs'
	   RETURN
	END
end

-- If report type is Recipe ONLY, delete all non-recipe variables
IF @InReportType = 'Recipe'
BEGIN
	DELETE FROM #Pre_Var_Ids WHERE Frequency <> 'h) Recipe'

	IF @@Error <> 0
	BEGIN
	   SELECT 'Error in Delete #Pre_Var_IDs'
	   RETURN
	END
END

IF @InReportType = 'NonRecipe'
BEGIN
	DELETE From #Pre_Var_IDs
	Where Is_Recipe = 'Yes'

	IF @@Error <> 0
	BEGIN
	   SELECT 'Error in Delete #Pre_Var_IDs'
	   RETURN
	END
END

-- Get Equipment Areas
UPDATE #Pre_Var_ids
	SET PUG_Desc = Value
FROM dbo.Table_Fields_Values		WITH(NOLOCK)
WHERE 	Var_Id = KeyId
	AND 	TableId = @VarTableId
	AND		Table_Field_id = @AreaUDP

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Pre_Var_IDs'
	   RETURN
	END

---------------------------------------------------------------------------------------------------------------------
-- Fill the #PU_IDs temporary table from the List of Variables Collected
---------------------------------------------------------------------------------------------------------------------

INSERT INTO #PU_IDs (
			PL_Desc		,
			PL_Id		,
			PU_Id		,
			--LineStarts	,
			MasterUnit)
SELECT 	DISTINCT
			pl.PL_Desc,
			pl.PL_Id,
			pu.PU_Id,
			--pl.LineStarts,
			pu.Master_Unit
FROM #Pre_Var_ids 				v   WITH(NOLOCK)
JOIN dbo.Prod_Units_Base 		pu 	WITH(NOLOCK)	ON(v.PU_id = pu.PU_id)			
JOIN #PL_Ids 					pl 	WITH(NOLOCK)	ON(pu.PL_id = pl.PL_id)

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #PU_IDs'
	   RETURN
	END

-------------------------------------------------------------------------------------------------------------------------
--	Update ConvId for each Slave Production Unit. We will check this doing a comparison with all Production Units that
--	were flagged with STLS_ST_MASTER_UNIT_ID UDP

--	NOTE: STLS_Info temp table holds all Conv Ids for all Units that belongs to all Lines in #PU_IDs.
-------------------------------------------------------------------------------------------------------------------------
UPDATE #PU_IDs 
	SET Conv_Id = STLS_Info.Value
FROM
	(SELECT KeyId, Value
	FROM dbo.Table_Fields_Values WITH(NOLOCK)
	WHERE(Table_Field_Id = @intTableFieldId
		AND KeyId IN(	SELECT DISTINCT pu.PU_Id 
						FROM Prod_Units_Base	pu WITH(NOLOCK)
						JOIN #PU_IDs	puids	 WITH(NOLOCK) ON(pu.PL_Id = puids.PL_Id)))) STLS_Info

WHERE(PU_ID <> STLS_Info.KeyId
	AND MasterUnit IS NOT NULL)

-- JPG
UPDATE P SET Conv_ID = (SELECT dbo.fnLocal_STI_Cmn_GetUDP(PU_ID, 'STLS_ST_MASTER_UNIT_ID', 'Prod_Units'))   
	FROM #PU_IDs P
	WHERE Conv_ID IS NULL

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #PU_IDs'
	   RETURN
	END

---------------------------------------------------------------------------------------------------------------------
PRINT 'END #PRE_VAR_IDS SETTINGS ' + CONVERT(VARCHAR,GETDATE(),120)
---------------------------------------------------------------------------------------------------------------------

--******************************************************************
--	CREATE OFFSET TABLE
--******************************************************************
	
INSERT INTO @Offsets
SELECT	u.MasterUnit,
		u.MasterDesc,
		'a) Shiftly Manual',
		SUBSTRING(ecp.Value,6,3),
		ec.EC_Id,
		ec.Event_Subtype_Id,
		es.Event_Subtype_Desc
FROM	@Units u 
JOIN	Event_Configuration ec WITH (NOLOCK) ON u.MasterUnit = ec.PU_Id
JOIN	Event_Configuration_Properties ecp WITH (NOLOCK) ON ec.EC_Id = ecp.EC_Id
JOIN	ED_Field_Properties efp WITH (NOLOCK) ON ecp.ED_Field_Prop_Id = efp.ED_Field_Prop_Id
JOIN	Event_Subtypes es WITH (NOLOCK) ON ec.Event_Subtype_Id = es.Event_Subtype_Id
WHERE	ec.EC_Desc LIKE '%RTT%Manual%'
  AND   Field_Desc LIKE '%Offset%'


INSERT INTO @Offsets
SELECT	u.MasterUnit,
		u.MasterDesc,
		'b) Shiftly Auto',
		SUBSTRING(ecp.Value,6,3),
		ec.EC_Id,
		ec.Event_Subtype_Id,
		es.Event_Subtype_Desc
FROM	@Units u
JOIN	Event_Configuration ec WITH (NOLOCK) ON u.MasterUnit = ec.PU_Id
JOIN	Event_Configuration_Properties ecp WITH (NOLOCK) ON ec.EC_Id = ecp.EC_Id
JOIN	ED_Field_Properties efp WITH (NOLOCK) ON ecp.ED_Field_Prop_Id = efp.ED_Field_Prop_Id
JOIN	Event_Subtypes es WITH (NOLOCK) ON ec.Event_Subtype_Id = es.Event_Subtype_Id
WHERE	ec.EC_Desc LIKE '%RTT%Auto%'
  AND   Field_Desc LIKE '%Offset%'


---------------------------------------------------------------------------------------------------
--	NON-PRODUCTIVE TIME SECTION 
---------------------------------------------------------------------------------------------------
INSERT INTO @NonProdTime (
		PUId								,
		StartTime							,
		EndTime								,
		NPReasonId							,
		NPReasonName						,
		Duration							)
SELECT  PU_Id								,
		Start_Time							, 
		End_Time							,		
		Reason_Level1						,
		Event_Reason_Name					, 
		SUM( 
			ROUND(DATEDIFF(ss,(CASE WHEN npd.Start_Time < @InStartTime THEN @InStartTime ELSE npd.Start_Time END),
			(CASE WHEN npd.End_Time > @InEndTime THEN @InEndTime ELSE npd.End_Time END)), 0))		    
	FROM dbo.NonProductive_Detail		npd WITH(NOLOCK)
	JOIN dbo.Event_Reasons				er  WITH(NOLOCK) 
											ON (npd.Reason_Level1 = er.Event_Reason_Id)
	WHERE npd.Start_Time <= @inEndTime 
		AND npd.End_Time >= @inStartTime 	
		AND npd.PU_Id IN (SELECT ProdStarts_PUId FROM #PL_Ids WITH(NOLOCK))
	GROUP BY PU_Id,Start_Time, End_Time,Event_Reason_Name,Reason_Level1		 

UPDATE @NonProdTime
	SET Duration = Duration / 60.0

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert @NonProdTime'
	   RETURN
	END

---------------------------------------------------------------------------------------------------
--	PROCESS ORDERS
---------------------------------------------------------------------------------------------------

INSERT INTO #ProcessOrders (PPId, PUId, StartTime, EndTime, PO)
SELECT	s.PP_Id,
		l.PU_Id,
		s.Start_Time,
		ISNULL(s.End_Time, @InENDTime),
		p.Process_Order
FROM dbo.Production_Plan_Starts s 	WITH(NOLOCK)
JOIN #PL_Ids l 						WITH(NOLOCK) ON s.PU_Id = l.PU_Id
JOIN dbo.Production_Plan p 			WITH(NOLOCK) ON s.PP_Id = p.PP_Id
WHERE ((s.Start_Time < @InENDTime AND (s.End_Time > @InENDTime OR s.End_Time IS NULL)) OR (s.End_Time > @InStartTime AND (s.End_Time < @InENDTime OR s.End_Time IS NULL)))

IF @InProcessOrder <> 'All'
    BEGIN
        DELETE po
        FROM #ProcessOrders po
        WHERE PPId NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProcessOrder, ',')) OR PPId IS NULL
    END
---------------------------------------------------------------------------------------------------------------------
PRINT 'GET TIME FRAMES ' + CONVERT(VARCHAR,GETDATE(),120)
---------------------------------------------------------------------------------------------------------------------
-- SG: Correct daily time frames.
DECLARE @CurrentStart	DATETIME,
		@CurrentEnd		DATETIME,
		@FirstShift		DATETIME,
		@FirstDayOfQtr	DATETIME,	--First day of quarter.
		@BegOfDayHr		INT,		--Begining of day.
		@BegOfDayMi		INT

DECLARE	@BegOfWeek		DATETIME,
		@EndOfWeek		DATETIME,
		@PEndOfWeek		INT

-- SG: Correct monthly inserts.
DECLARE	@StartBegOfMonth	DATETIME,
		@EndBegOfMonth		DATETIME,
		@BegOfMonth			DATETIME,
		@EndOfMonth			DATETIME,
		@EndTimeEndOfMonth	DATETIME

SET @FirstDayOfQtr = '2018-01-01'

SELECT	@BegOfDayHr = Value
FROM	dbo.Site_Parameters sp WITH(NOLOCK)
JOIN	dbo.Parameters p WITH (NOLOCK) ON sp.Parm_Id = p.Parm_Id
WHERE	Parm_Name = 'EndOfDayHour'

SELECT	@BegOfDayMi = Value
FROM	dbo.Site_Parameters sp WITH (NOLOCK)
JOIN	dbo.Parameters p WITH (NOLOCK) ON sp.Parm_Id = p.Parm_Id
WHERE	Parm_Name = 'EndOfDayMinute'

SELECT	@FirstDayOfQtr = DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,@FirstDayOfQtr))

WHILE ((SELECT DATEADD(mm,3,@FirstDayOfQtr)) < @InStartTime OR (SELECT DATEADD(mm,3,@FirstDayOfQtr)) = @InStartTime)
BEGIN
	SET @FirstDayOfQtr = DATEADD(mm,3,@FirstDayOfQtr)
END

--v. 
UPDATE s
	SET s.PUID_CS = cs.pu_id
	FROM #PU_IDs s 
	JOIN Crew_Schedule cs WITH(NOLOCK) ON s.pu_id = cs.pu_id
WHERE	Start_Time >= @InStartTime

--SG: First shift of the timescope for Shiftly Variables.
SELECT	@FirstShift = MAX(Start_Time)
FROM	Crew_Schedule cs WITH(NOLOCK)
-- JOIN	#PU_IDs pu WITH(NOLOCK) ON(cs.PU_Id = pu.PU_ID)
JOIN	#PU_IDs 		pu 	WITH(NOLOCK)ON(cs.pu_id = ISNULL(pu.PUID_CS, pu.Conv_ID))

WHERE	Start_Time <= @InStartTime

--FIX Defect 77 - GL - check if @FirstShift has values, if null (no crew schedule) get the last available shift from the time option.
IF @FirstShift IS NULL
BEGIN
	SELECT @FirstShift = MIN(Start_Time)
	FROM dbo.Crew_Schedule cs WITH(NOLOCK)
	-- JOIN #PU_Ids pu WITH(NOLOCK) ON cs.PU_Id = pu.PU_ID
	JOIN #PU_IDs 	pu 	WITH(NOLOCK)ON(cs.pu_id = ISNULL(pu.PUID_CS, pu.Conv_ID))
	WHERE Start_Time <= @InENDTime
	  AND Start_Time >= @InStartTime
END


--SG: Set Start of Day for daily Variables using the hour and minutes of the first shift
SELECT	@CurrentStart = DATEADD(hh,DATEPART(hh,@FirstShift),DATEADD(mi,DATEPART(mi,@FirstShift),DATEADD(dd, DATEDIFF(dd, 0, @InStartTime), 0)))

--SG: Set Start of week
SELECT @PEndOfWeek = sp.Value
FROM Site_Parameters sp WITH (NOLOCK)
JOIN Parameters p WITH (NOLOCK) ON sp.Parm_Id = p.Parm_Id
WHERE p.Parm_Name = 'EndOfWeekDay'

SELECT @EndOfWeek	= DATEADD(dd, 7-(DATEPART(dw, @InStartTime)), @InStartTime)

SELECT @BegOfWeek	= DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,CONVERT(DATETIME,CONVERT(DATE,DATEADD(dd,-@PEndOfWeek,@EndOfWeek)))))

-- SG: Set beginning of month from Start Time
SELECT	@StartBegOfMonth = DATEADD(month, DATEDIFF(month, 0, @InStartTime), 0),
		@EndBegOfMonth = DATEADD(month, DATEDIFF(month, 0, @InENDTime), 0)

SELECT	@BegOfMonth = DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,@StartBegOfMonth)),
		@EndOfMonth = DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,DATEADD(dd,1,CONVERT(DATETIME,EOMONTH(@InStartTime))))),
		@EndTimeEndOfMonth = DATEADD(hh,@BegOfDayHr,DATEADD(mi,@BegOfDayMi,DATEADD(dd,1,CONVERT(DATETIME,EOMONTH(@InENDTime)))))


INSERT INTO #Time_Frames (
			PL_ID		,
			PU_Id		,
			PU_Desc		,
			Frequency	,
			Start_Time	,
			End_time)

SELECT 		pu.PL_Id,
			pu.PU_Id,
			pu.PL_Desc,
			'a) Shiftly Manual',
			Start_Time,
			End_Time 
	FROM dbo.Crew_Schedule 		cs 		WITH(NOLOCK)
	-- JOIN #PU_IDs 				pu 		WITH(NOLOCK)	ON(cs.pu_id = pu.PU_ID)
	JOIN #PU_IDs 			pu 	WITH(NOLOCK)ON(cs.pu_id = ISNULL(pu.PUID_CS, pu.Conv_ID))
	WHERE(Start_Time >= @FirstShift 
	AND Start_Time < @InEndTime)

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Time_Frames'
	   RETURN
	END

INSERT INTO #Time_Frames (
			PL_ID		,
			PU_Id		,
			PU_Desc		,
			Frequency	,
			Start_Time,
			End_Time)

SELECT 		pu.PL_Id,
			pu.PU_Id,
			pu.PL_Desc,
			'b) Shiftly Auto',
			Start_Time,
			End_Time
	FROM dbo.Crew_Schedule 			cs 		WITH(NOLOCK)
	-- JOIN #PU_IDs 					pu 		WITH(NOLOCK) ON(cs.pu_id = pu.PU_ID)
	JOIN	#PU_IDs 		pu 	WITH(NOLOCK)ON(cs.pu_id = ISNULL(pu.PUID_CS, pu.Conv_ID))
	WHERE 	Start_Time >= @FirstShift 
			AND Start_Time < @InEndTime

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Time_Frames'
	   RETURN
	END

SET @CurrentStart = @InEndTime

WHILE @CurrentStart > @InStartTime
BEGIN
	INSERT INTO #Time_Frames (
			PL_Id		,
			PU_Id		,
			PU_Desc		,
			Frequency	,
			Start_Time	,
			End_Time	)
SELECT		PL_Id,
			PU_Id,
			PL_Desc,
			'c) Daily',
			DATEADD(dd,-1,@CurrentStart),
			@CurrentStart
	FROM	#PU_Ids WITH(NOLOCK)

	SET @CurrentStart = DATEADD(dd,-1,@CurrentStart)
END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Time_Frames'
	   RETURN
	END


IF @InReportType = 'Recipe' OR @InReportType = 'All'
BEGIN

	DECLARE	@RecipeEnd		DATETIME

	-- SG
	-- IF Recipe variables are in scope AND scope is bigger than 7 days, THEN limit scope to first 7 days.

	SET @RecipeEnd = @InENDTime

	IF DATEDIFF(d, @InStartTime, @InENDTime)> 7 AND (@InReportType = 'Recipe' OR @InReportType = 'All')
	BEGIN
		PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + ' Report Spans More than One Week.' 
		PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + ' END Date will be reSET to one week FROM start date.' 
		SET @RecipeEnd = DATEADD(dd, 7, @InStartTime)
	END

-- INSERT OF Recipe TIMES

    INSERT INTO #Time_Frames (
						PL_ID	,
						PU_Id	,
						PU_Desc	,
						Frequency,
						Start_Time,
						End_time	)

    SELECT 				pu.PL_Id	,
						pu.PU_Id	,
						pu.PL_Desc	,
						'h) Recipe'	,
						Start_Time	,
						End_time 
	FROM dbo.Crew_Schedule 			cs 		WITH(NOLOCK)
    -- JOIN #PU_IDs 					pu 		WITH(NOLOCK) ON(cs.pu_id = pu.PU_ID)
   	JOIN	#PU_IDs 		pu 	WITH(NOLOCK)ON(cs.pu_id = ISNULL(pu.PUID_CS, pu.Conv_ID))
	WHERE (Start_Time >= @FirstShift 
			AND Start_Time < @RecipeEnd)

	If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Time_Frames'
	   RETURN
	END

END 

-- SG
-- Weekly time frames will be inserted from the start of the week based on Start Time of the report.
-- Correct end time will be set later.
WHILE @BegOfWeek < @InEndTime
BEGIN
	INSERT INTO  #Time_Frames (PL_ID,PU_Id,PU_Desc,Frequency,Start_time,End_time)
	SELECT	pu.PL_Id,
			pu.PU_Id,
			pu.PL_Desc,
			'd) Weekly',
			@BegOfWeek,
			DATEADD(dd,7,@BegOfWeek)
	FROM #PU_Ids	pu WITH(NOLOCK)

	SELECT @BegOfWeek = DATEADD(dd,7,@BegOfWeek)

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #Time_Frames'
	   RETURN
	END
END
	
--SG: Monthly variables get their start time from the begining of the month for the start time
--	  and the end of the month of the end time. The end time is fixed later in the code.

	WHILE @BegOfMonth < @EndTimeEndOfMonth --OR @EndOfMonth != @EndTimeEndOfMonth
	BEGIN

		INSERT INTO #Time_Frames (PL_ID,PU_Id,PU_Desc,Frequency,start_time,End_time)
			SELECT	pu.PL_Id,
					pu.PU_Id,
					pu.PL_Desc,
					'e) Monthly',
					@BegOfMonth,
					@EndOfMonth
			FROM	#PU_Ids pu WITH(NOLOCK)
			WHERE	pu.MasterUnit IS NULL
			GROUP BY pu.PL_Id,pu.PU_Id,pu.PL_Desc

		If @@Error <> 0
			BEGIN
	   
			   SELECT 'Error in Insert #Time_Frames'
			   RETURN
			END

		SELECT	@BegOfMonth = DATEADD(mm,1,@BegOfMonth),
				@EndOfMonth = DATEADD(mm,1,@EndOfMonth)
	END

--SG: Quarterly variables get start time and end time from start of quarter.
WHILE @FirstDayOfQtr < @InENDTime
BEGIN
	INSERT INTO #Time_Frames (PL_ID,PU_Id,PU_Desc,Frequency,start_time,End_time)
		SELECT 	pu.PL_Id,
				pu.PU_Id,
				pu.PL_Desc,
				'f) Quarterly',
				@FirstDayOfQtr,
				DATEADD(mm,3,@FirstDayOfQtr)
		FROM #PU_Ids pu WITH(NOLOCK)

	If @@Error <> 0
		BEGIN
	   
		   SELECT 'Error in Insert #Time_Frames'
		   RETURN
		END

	SELECT @FirstDayOfQtr = DATEADD(mm,3,@FirstDayOfQtr)

END

WHILE (SELECT COUNT(*) FROM #ProcessOrders WITH(NOLOCK) WHERE Prd = 0) > 0
BEGIN
	SELECT TOP 1 @CurrentPPId = PPId FROM #ProcessOrders WITH(NOLOCK) WHERE Prd = 0

	INSERT INTO #Time_Frames (PL_ID,PU_Id,PU_Desc,Frequency,start_time,End_time)
	SELECT	l.PL_Id,
			p.PUId,
			l.PL_Desc,
			'g) QCL Auto',
			StartTime,
			EndTime
	FROM #ProcessOrders p 	WITH(NOLOCK)
	JOIN #PL_Ids l 			WITH(NOLOCK) ON p.PUId = l.PU_Id
	WHERE PPId = @CurrentPPId

	INSERT INTO #Time_Frames (PL_ID,PU_Id,PU_Desc,Frequency,start_time,End_time)
	SELECT	l.PL_Id,
			p.PUId,
			l.PL_Desc,
			'h) QCL Manual',
			StartTime,
			EndTime
	FROM #ProcessOrders p 	WITH(NOLOCK)
	JOIN #PL_Ids l 			WITH(NOLOCK) ON p.PUId = l.PU_Id
	WHERE PPId = @CurrentPPId

	UPDATE #ProcessOrders
	SET Prd = 1
	WHERE PPId = @CurrentPPId

END
----------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------
-- SET accurate Start_Time AND End_Time
DECLARE @DayPeriod as int
DECLARE @BackDateDate as DATETIME
DECLARE @PL_Desc as NVARCHAR(50)
DECLARE @PL_Id as int
DECLARE @MaxStartTime as DATETIME
DECLARE @Frequency as NVARCHAR(50)
DECLARE @ProjectedMaxStartTime as DATETIME
DECLARE @IntervalENDDate as DATETIME
DECLARE @NextProjectedMaxStartTime as DATETIME

DECLARE @PUId			INT

--Change Cursor
DECLARE @i 				INT

SET @i = (SELECT Count(*) FROM #PL_IDs WITH(NOLOCK))

WHILE @i > 0 
BEGIN

	SELECT 	@Pl_id 		= PL_Id,
		   	@PUId  		= PU_Id, 
			@PL_Desc 	= PL_Desc 
	FROM #PL_IDs p WITH(NOLOCK)
	WHERE p.RCDID = @i

	-- FRio : 1st STEP : SET accurate start_times FROM @InStartTime
	-- While Loop for detecting first day of week FROM day_period AND @InStartTime
	SELECT @DayPeriod = day_period FROM #Time_Frames WITH(NOLOCK) WHERE Frequency like '%Weekly%' AND PU_Desc = @PL_Desc
	SELECT @BackDateDate = start_time FROM #Time_Frames WITH(NOLOCK) WHERE Frequency like '%Weekly%' AND PU_Desc = @PL_Desc
	--SG
	IF @InGroupBy = 'Workcell' AND @KPISummary = 0
	BEGIN
	while @BackDateDate > @InStartTime
		BEGIN
			SET @BackDateDate =  DATEADD (dd, -7, @BackDateDate)
		END

	UPDATE #Time_Frames
	SET Start_Time = @BackDateDate,
		End_Time = DATEADD(ww,1,@BackDateDate)
	WHERE frequency like '%weekly%' AND PU_Desc = @PL_Desc

	If @@Error <> 0
		BEGIN	   
		SELECT 'Error in Update #Time_Frames'
		RETURN
		END
	END

	-- FRio : 1st STEP : SET accurate start_times FROM @InStartTime
	-- While Loop for detecting first day of week FROM day_period AND @InStartTime
	SELECT @DayPeriod = day_period FROM #Time_Frames WITH(NOLOCK) WHERE Frequency like '%Weekly%' AND PU_Desc = @PL_Desc
	SELECT @BackDateDate = start_time FROM #Time_Frames WITH(NOLOCK) WHERE Frequency like '%Weekly%' AND PU_Desc = @PL_Desc

	IF @InGroupBy = 'Workcell' AND @KPISummary = 0
	BEGIN
	while @BackDateDate > @InStartTime
		BEGIN
			SET @BackDateDate =  DATEADD (dd, -7, @BackDateDate)
		END

	UPDATE #Time_Frames
	SET Start_Time = @BackDateDate,
		End_Time = DATEADD(ww,1,@BackDateDate)
	WHERE frequency like '%weekly%' AND PU_Desc = @PL_Desc

	If @@Error <> 0
		BEGIN	   
		SELECT 'Error in Update #Time_Frames'
		RETURN
		END
	END

	-- FRio : Weekly Time Frames
	SELECT @ProjectedMaxStartTime = DATEADD (wk, 1, Start_Time) FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'd' AND PU_Desc = @PL_Desc-- Weekly
	SELECT @IntervalENDDate = @InENDTime +( 7 - datepart(dw,@InENDTime)) -- Weekly
	SELECT @NextProjectedMaxStartTime = DATEADD(wk, 2, Start_Time) FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'd' AND PU_Desc = @PL_Desc-- Weekly
	SELECT @DayPeriod = day_period FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'd' AND PU_Desc = @PL_Desc-- Weekly

	while @ProjectedMaxStartTime < @IntervalENDDate 
	BEGIN
		INSERT INTO #Time_Frames (PL_id,PU_Id,PU_Desc,frequency,start_time,End_time,day_period)
		SELECT @PL_id,@PUId,@PL_Desc, 'd) Weekly',
		@ProjectedMaxStartTime,@NextProjectedMaxStartTime ,@DayPeriod

		If @@Error <> 0
		BEGIN
		
		SELECT 'Error in Insert #Time_Frames'
		RETURN
		END
		
		SET @MaxStartTime = @ProjectedMaxStartTime
		SET @ProjectedMaxStartTime = DATEADD (wk, 1, @MaxStartTime)
		SET @NextProjectedMaxStartTime = DATEADD (wk, 1, @ProjectedMaxStartTime) -- Weekly   
	END

	-- FRio : Just IN case delete all time frames WHERE Start_Date > @InENDTime
	Delete FROM #Time_Frames WHERE start_time > @InENDTime AND frequency like '%weekly%' AND PU_Desc = @PL_Desc 

	-- FRio : Just IN case delete all time frames WHERE Start_Date > @InENDTime
	DELETE FROM #Time_Frames 
	WHERE (start_time > @InENDTime or start_time = End_time) AND frequency like '%monthly%' AND PU_Desc = @PL_Desc

	If @@Error <> 0
		BEGIN
		
		SELECT 'Error in Delete #Time_Frames'
		RETURN
		END

	-- SELECT @MaxStartTime,* FROM #Time_Frames WHERE frequency like '%monthly%'
	IF @MaxStartTime < @InENDTime
			SET @MaxStartTime = DATEADD(m,1,@MaxStartTime)

	-- FRio : Quarterly Time Frames
	SELECT @ProjectedMaxStartTime = DATEADD(dd, -day(DATEADD(mm,2, @InENDTime)),DATEADD(mm,2, @InENDTime)) FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'f' AND PU_Desc = @PL_Desc -- Quarterly
	SELECT @IntervalENDDate = DATEADD(dd, -day(DATEADD(mm,2, @InENDTime)),DATEADD(mm,2, @InENDTime)) FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'f'  -- Quarterly
	SELECT @NextProjectedMaxStartTime = DATEADD (m, 6, Start_Time) FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'f' AND PU_Desc = @PL_Desc -- Quarterly
	SELECT @DayPeriod = day_period FROM #Time_frames WITH(NOLOCK) WHERE LEFT(Frequency,1)= 'f' AND PU_Desc = @PL_Desc -- Quarterly

	While @ProjectedMaxStartTime < @IntervalENDDate 
	BEGIN
		INSERT INTO #Time_Frames (PL_Id,PU_Id,PU_Desc,frequency,start_time,End_time,day_period)
		SELECT @PL_id,@PUId,@PL_Desc,'f) Quarterly',
		@ProjectedMaxStartTime,@NextProjectedMaxStartTime ,@DayPeriod

		If @@Error <> 0
		BEGIN
		
		SELECT 'Error in Insert #Time_Frames'
		RETURN
		END
		
		SET @MaxStartTime = @ProjectedMaxStartTime
		SET @ProjectedMaxStartTime = DATEADD (m, 3, @MaxStartTime)
		SET @NextProjectedMaxStartTime = DATEADD (m, 3, @ProjectedMaxStartTime) -- Quarterly
	END

	SET @i = @i - 1
END

-- END Change cursor

-- *****************************************************************************************
-- FRio : END Building #Time_Frames Table
-- *****************************************************************************************
DELETE FROM #Time_Frames WHERE End_Time = Start_Time

-- SG: Update Start and End time if out of scope.
--UPDATE #Time_Frames SET Start_Time = @InStartTime WHERE Start_Time < @InStartTime AND Frequency = 'e) Monthly'
--UPDATE #Time_Frames SET End_Time = @InEndTime WHERE End_Time >= @InEndTime

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Delete #Time_Frames'
	   RETURN
	END
-- *****************************************************************************************
-- FRio : Building Line_Status ON #Time_Frames table
-- *****************************************************************************************

UPDATE #Time_Frames	
		SET Phrase_Value = ISNULL(er.Event_Reason_Name,'PR In:Line Normal'), --phr.Phrase_Value, 
		Include = 'No'
	FROM #Time_Frames tf
	JOIN dbo.NonProductive_Detail npt WITH(NOLOCK) ON tf.PU_Id = npt.PU_Id
	JOIN dbo.Event_Reasons er WITH(NOLOCK) ON npt.Reason_Level1 = er.Event_Reason_Id
	--JOIN @NonProdTime npt ON tf.PU_Id = npt.PUId
		AND tf.Start_Time >= npt.Start_Time
		AND (tf.Start_Time < npt.End_Time  OR npt.End_Time IS NULL)
	WHERE er.Event_Reason_Name IN (SELECT PLStatusDesc FROM #PLStatusDescList WITH(NOLOCK))

UPDATE #Time_Frames	
	SET Phrase_Value = 'PR In:Line Normal'
WHERE Phrase_Value IS NULL

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

UPDATE #Time_Frames
	SET Include = 'Yes'
FROM #Time_Frames tf
JOIN #PL_IDs pl WITH(NOLOCK) ON tf.PL_Id = pl.pl_id
WHERE phrase_value IN (SELECT PLStatusDesc FROM #PLStatusDescList WITH(NOLOCK) )
-- Or Start_Time < LineStarts

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

UPDATE #Time_Frames
	Set	Start_Date 	= Start_Time,
		End_Date	= End_Time,
		Due_Date   = Start_Time,
		Next_Start_Date = End_Time
FROM #Time_Frames tf

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

UPDATE	pl
	SET pl.PUID_CS = cs.PU_ID
	FROM #PL_ids pl
	JOIN dbo.Crew_Schedule cs WITH(NOLOCK) ON pl.PU_ID = cs.pu_id
	WHERE	Start_Time >= @InStartTime

UPDATE #Time_Frames SET 
        -- Next_Start_Date = (SELECT End_time FROM dbo.Crew_Schedule WITH(NOLOCK) WHERE Start_time = tf.Start_Date AND pu_id = pl.PU_ID ),
    	-- End_Date = (SELECT End_time FROM dbo.Crew_Schedule WITH(NOLOCK) WHERE Start_time = tf.Start_Date AND pu_id = pl.PU_ID )
	Next_Start_Date = (SELECT End_time FROM dbo.Crew_Schedule WITH(NOLOCK) WHERE Start_time = tf.Start_Date AND pu_id = ISNULL(pl.PUID_CS, pl.Conv_ID)),
    End_Date = (SELECT End_time FROM dbo.Crew_Schedule WITH(NOLOCK) WHERE Start_time = tf.Start_Date AND pu_id = ISNULL(pl.PUID_CS, pl.Conv_ID) )
	FROM #Time_Frames 	tf
JOIN #PL_ids 		pl 		WITH(NOLOCK) ON tf.pl_id 	= 	pl.pl_id
WHERE tf.Frequency = 'a) Shiftly Manual' Or tf.Frequency = 'b) Shiftly Auto'


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

UPDATE #Time_Frames
  SET Next_Start_Date = (case Frequency 
	 WHEN 'e) Monthly' 
				then 
	     DATEADD(mm,1,due_date)
	 WHEN 'f) Quarterly' then
	     DATEADD (mm,3,due_date)
	 END)
WHERE Frequency = 'e) Monthly' or Frequency = 'f) Quarterly'

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

UPDATE #Time_Frames
  SET --End_Date = (Case WHEN DATEADD(dd,7,Start_Date)>@InENDTime Then @InENDtime ELSE DATEADD(dd,7,Start_Date) END), -- This is keeping Weekly variables out.
      Next_Start_Date =  DATEADD(dd,7,Due_Date)	 
WHERE Frequency = 'd) Weekly'

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

UPDATE #Time_Frames 
	SET 
        --End_Date = (case WHEN DATEADD(dd,1,Start_Date) > @InENDTime then @InENDTime ELSE DATEADD(dd,1,Start_Date) END), 
        Due_Date = Start_Date, 
        Next_Start_Date = DATEADD(dd,1,Start_Date)
WHERE Frequency = 'c) Daily'

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #Time_Frames'
	   RETURN
	END

--SG: Adding offsets from the model.
UPDATE	tf
SET		End_Date = DATEADD(mi, ISNULL(Offset,0), End_Date)
FROM	#Time_Frames tf
JOIN	@Offsets o ON tf.PU_Id = o.UnitId AND tf.Frequency = o.Frequency

-- Fix for Defect #5542
IF @InTimeOption IN ('LastMonth','Last7Days','LastWeek','Last3Days','userDefined')
BEGIN
	DELETE FROM #Time_Frames WHERE Start_Time >= DATEADD(hh,DATEPART(hh,@FirstShift),DATEADD(mi,DATEPART(mi,@FirstShift),DATEADD(dd, DATEDIFF(dd, 0, @InENDTime), 0))) AND Frequency IN('d) Weekly','e) Monthly','f) Quarterly')
END

--SG: Remove shiftly and daily variables where the start time is equal or bigger than the end time when the period is in the same day.
IF @InTimeOption IN ('LastWeek','LastMonth','Yesterday','Last7Days','Last3Days')
BEGIN
	DELETE FROM #Time_Frames WHERE Start_Time >= DATEADD(hh,DATEPART(hh,@FirstShift),DATEADD(mi,DATEPART(mi,@FirstShift),DATEADD(dd, DATEDIFF(dd, 0, @InENDTime), 0))) AND Frequency IN ('a) Shiftly Manual','b) Shiftly Auto','c) Daily')
END

--SG: Limit End Time for Daily variables up to now and not the whole day.
UPDATE	tf 
SET		End_Date = @InEndTime
FROM	#Time_Frames tf
WHERE	Frequency = 'c) Daily'
  AND	Start_Time = (SELECT MAX(Start_Time) FROM #Time_Frames  WITH(NOLOCK) WHERE Frequency = 'c) Daily')

  --where due_Date >= '2022-01-01'
PRINT 'END GET TIME FRAMES ' + CONVERT(VARCHAR,GETDATE(),120)
--**************************************************************************************************
-- Build a Time_Frames Lookup tables
--**************************************************************************************************


PRINT 'START INSERTING VARIABLES ' + CONVERT(VARCHAR,GETDATE(),120)
-- **************************************************************************************************************
-- Creating the #All_Variables Table
-- **************************************************************************************************************
INSERT Into #All_Variables(  
						PL_ID,
						PU_Id,
						Line,
                        EventSubtypeId,
						Var_ID,
						Var_Type,
						Var_Desc,
                        Pug_Id,
						Pug_Desc,
						Test_Time,
						Master,
						Frequency,
						Start_Date,
						End_Date,
						Due_Date,
						Next_Start_Date,
						Day_Period,
						Samples_Due,
						Future_Samples_Due,
						Samples_Taken,
						Result_On,
						Result,
						Defects,
						Team,
						Shift,
						Include_Result,
						Include_Crew,
						Include_Shift, 
						Include_LineStatus,
						Include_test,
						Stubbed,
						Canceled,
						Test_Freq,
						--Sheet_id,
						CurrentSpec)
		
SELECT DISTINCT 
    tplids.PL_ID as PL_ID,
    COALESCE(tplids.MasterUnit,tplids.pu_id) as pu_id, 
	tplids.PL_Desc as Line,
    pvids.EventSubtypeId as EventSubtypeId,
	pvids.var_id as Var_ID,
	pvids.Var_Type as Var_Type,
	pvids.var_desc as Var_Desc,
    pvids.PUG_Id as Pug_Id,
	pvids.pug_Desc as Pug_Desc,
	Null,
	1 as Master,						-- "Master" record indicator (0 = summary; 1 = detail)
	pvids.Frequency,					-- Eg. Shiftly, Weekly or Monthly
    tf.Start_Date as Start_Date,
    tf.End_Date as End_Date,
    tf.Due_Date as Due_Date,
    tf.Next_Start_Date as Next_Start_Date,
    tf.Day_Period,
	0 as Samples_Due,
	0 as Future_Samples_Due,		
	0 as Samples_Taken,					-- Samples Taken (to be UPDATEd later IN code)
    tf.Start_Time as Result_On,
	'123abcxxx' as Result,
	0 as Defects,						-- Defects (to be UPDATEd later IN code)
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
    --pvids.Sheet_id,
    'No' as CurrentSpec
FROM #Pre_Var_IDs 			pvids 	WITH(NOLOCK)
JOIN #Time_Frames 			tf		WITH(NOLOCK) 	ON 	tf.frequency = pvids.frequency AND tf.pu_id = pvids.pu_id
JOIN #PU_IDs 				tplids 	WITH(NOLOCK)	ON 	pvids.pu_id = tplids.PU_ID


UPDATE #All_Variables
		SET MasterPUDesc = pu.PU_Desc
FROM  #All_Variables av
JOIN  dbo.Prod_Units_Base pu WITH(NOLOCK) ON av.PU_Id = pu.PU_Id

UPDATE #All_Variables
		SET ChildPUDesc = pu.PU_Desc
FROM  #All_Variables av
JOIN  dbo.Variables_Base  v WITH(NOLOCK) ON av.Var_Id = v.Var_Id
JOIN  dbo.Prod_Units_Base pu WITH(NOLOCK) ON v.PU_Id = pu.PU_Id

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #All_Variables'
	   RETURN
	END

-- Set Test Time
UPDATE #All_Variables
	SET		Test_Time = Value
FROM 		dbo.Table_Fields_Values			WITH(NOLOCK)
WHERE 		Var_Id = KeyId
			AND TableId = @VarTableId
			AND	Table_Field_id = @TestTimeUDP
		
IF @VersionSelection = '3.1'
BEGIN
	-- IF A VARIABLE IS SET AS SHIFTLY AND HAS TEST TIME, IT IS A DAILY VARIABLE.
	UPDATE	#All_Variables
	SET Frequency = 'c) Daily'
	WHERE Frequency = 'a) Shiftly Manual'
	AND Test_Time IS NOT NULL

	-- Set Default Test Time if is empty
	UPDATE #All_Variables
		SET		Test_Time = Value
	FROM 		dbo.Table_Fields_Values			WITH(NOLOCK)
	WHERE 		EventSubtypeId = KeyId
				AND TableId = @ESTableId
				AND	Table_Field_id = @DefaultTestTimeUDP
				AND Test_Time IS NULL
				AND Frequency NOT IN ('a) Shiftly Manual', 'b) Shiftly Auto', 'c) Daily', 'g) QCL Auto', 'h) QCL Manual')
													
	-- Set Test Time to the first shift of the period if is NULL. This only applies for CPE.
	WHILE (SELECT COUNT(AVIdx) FROM #All_Variables WITH(NOLOCK) WHERE Test_Time IS NULL AND Frequency NOT IN ('a) Shiftly Manual', 'b) Shiftly Auto', 'c) Daily', 'g) QCL Auto', 'h) QCL Manual')) > 0
	BEGIN
		
		SELECT TOP 1 @Current = AVIdx FROM #All_Variables WITH(NOLOCK) WHERE Test_Time IS NULL AND Frequency NOT IN ('a) Shiftly Manual', 'b) Shiftly Auto', 'c) Daily', 'g) QCL Auto', 'h) QCL Manual')

		UPDATE v 
		SET Test_Time = a.TestTimeString
		FROM #All_Variables v
		JOIN (
			SELECT TOP 1	AVIdx AS Idx, 
							'01' + 
							(CASE WHEN LEN(DATEPART(HH, Start_Time)) = '1' THEN '0' + CONVERT(VARCHAR(1), DATEPART(HH, Start_Time)) ELSE CONVERT(VARCHAR(1), DATEPART(HH, Start_Time)) END) + -- Hour
							(CASE WHEN LEN(DATEPART(MI, Start_Time)) = '1' THEN '0' + CONVERT(VARCHAR(1), DATEPART(MI, Start_Time)) ELSE CONVERT(VARCHAR(1), DATEPART(MI, Start_Time)) END)  -- Minute
								AS TestTimeString
			FROM dbo.Crew_Schedule cs	WITH (NOLOCK)
			JOIN #PL_Ids l WITH(NOLOCK) ON cs.PU_Id = ISNULL(l.PUID_CS, l.Conv_Id)
			JOIN #All_Variables av  WITH(NOLOCK) ON l.PU_Id = av.PU_Id
			WHERE cs.Start_Time <= av.Start_Date
			AND cs.Shift_Desc = '1'
			AND AvIdx = @Current
			) AS a ON v.AVIdx = a.Idx

	END

	If @@Error <> 0
		BEGIN
		
		SELECT 'Error in Update #All_Variables'
		RETURN
		END
END
-------------------------------------------------------------------------------------------------------------->
PRINT 'START UPDATE STATEMENTS ' + CONVERT(VARCHAR,GETDATE(),120)
-- GET ALL START DATES --------------------------------------------------------------------------------------->

IF @VersionSelection = '3.0'
BEGIN
	UPDATE #All_Variables
	SET Due_Date = (CASE Frequency 
					WHEN 'e) Monthly' 
							THEN 
								CONVERT(DATETIME,	
								DATEADD(MI, convert(int,Substring(Test_Time, 5, 2)),
								DATEADD(hh,	convert(int,Substring(Test_Time, 3, 2)),
										CONVERT(DATETIME,
											convert(nvarchar,Year(Start_Date)) + '-' +
											convert(nvarchar,Month(Start_Date)) + '-' +
											CASE
												WHEN 	convert(int,Substring(Test_Time, 1, 2)) > 
														DATEDIFF(dd, Start_Date, DATEADD(mm, 1, Start_Date))
												THEN 	convert(nvarchar,DATEDIFF(dd, Start_Date, DATEADD(mm, 1, Start_Date)))
												ELSE	Substring(Test_Time, 1, 2)
												END
											)
										))	
								)												
					WHEN 'f) Quarterly' THEN
                        TRY_CONVERT(DATETIME,
                        '01 ' + 
                        (CASE 
                            WHEN Datepart (Quarter, Start_Date) < 2 THEN 'JAN'
                            WHEN Datepart (Quarter, Start_Date) < 3 THEN 'APR'
                            WHEN Datepart (Quarter, Start_Date) < 4 THEN 'JUL'
                            ELSE 'OCT' 
                            END) 
                        + ' ' + 
                        Cast(Year(Start_Date) AS VARCHAR(4)) + ' ' + 
                        Substring(Test_Time, 3, 2) + ':' +
                        Substring(Test_Time, 5, 2))
						END) 
	FROM #All_Variables av		-- nuevo start_time de acuerdo al UDP RTT_TestFreq
	JOIN dbo.Table_Fields_Values tfv WITH(NOLOCK) ON  av.Var_Id = tfv.KeyId
	WHERE (av.Frequency= 'e) Monthly' 
	OR av.Frequency = 'f) Quarterly')
	AND Table_Field_Id = @TestTimeUDP
END
ELSE
BEGIN
	UPDATE #All_Variables
	SET Due_Date = (CASE Frequency 
					WHEN 'e) Monthly' 
							THEN 
								CONVERT(DATETIME,	
								DATEADD(MI, convert(int,Substring(Test_Time, 5, 2)),
								DATEADD(hh,	convert(int,Substring(Test_Time, 3, 2)),
										CONVERT(DATETIME,
											convert(nvarchar,Year(Start_Date)) + '-' +
											convert(nvarchar,Month(Start_Date)) + '-' +
											CASE
												WHEN 	convert(int,Substring(Test_Time, 1, 2)) > 
														DATEDIFF(dd, Start_Date, DATEADD(mm, 1, Start_Date))
												THEN 	convert(nvarchar,DATEDIFF(dd, Start_Date, DATEADD(mm, 1, Start_Date)))
												ELSE	Substring(Test_Time, 1, 2)
												END
											)
										))	
								)												
					WHEN 'f) Quarterly' THEN
                        TRY_CONVERT(DATETIME,
                        '01 ' + 
                        (CASE 
                            WHEN Datepart (Quarter, Start_Date) < 2 THEN 'JAN'
                            WHEN Datepart (Quarter, Start_Date) < 3 THEN 'APR'
                            WHEN Datepart (Quarter, Start_Date) < 4 THEN 'JUL'
                            ELSE 'OCT' 
                            END) 
                        + ' ' + 
                        Cast(Year(Start_Date) AS VARCHAR(4)) + ' ' + 
                        Substring(Test_Time, 3, 2) + ':' +
                        Substring(Test_Time, 5, 2))
						END) 
	FROM #All_Variables av		-- nuevo start_time de acuerdo al UDP RTT_TestFreq
	-- JOIN dbo.Table_Fields_Values tfv WITH(NOLOCK) ON  av.Var_Id = tfv.KeyId
	WHERE (av.Frequency= 'e) Monthly' 
	OR av.Frequency = 'f) Quarterly')
	-- AND Table_Field_Id = @TestTimeUDP
END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

UPDATE	av
SET		Next_Start_Date = DATEADD(mm,1,Due_Date)
FROM	#All_Variables av
WHERE	Frequency = 'e) Monthly'

--SG: Update Due Dates for weekly variables. 
UPDATE	av
SET		Due_Date = DATEADD(mi,CONVERT(INT,SUBSTRING(Test_Time,5,2)),DATEADD(hh,CONVERT(INT,SUBSTRING(Test_Time,3,2)),DATEADD(dd,CONVERT(INT,SUBSTRING(Test_Time,1,2)) - 1,CONVERT(DATETIME,CONVERT(DATE,Start_Date)))))
FROM	#All_Variables av
WHERE	Frequency IN ('d) Weekly','f) Quarterly')

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

------------------------------------------------------------------------------------------------------------------>
PRINT 'END UPDATE STATEMENTS ' + CONVERT(VARCHAR,GETDATE(),120)
-- **************************************************************************************************************
-- **************************************************************************************************************
--	Delete Time Frames not considered ON this report
DELETE FROM #All_Variables WHERE [Start_Date] IS NULL
-- **************************************************************************************************************

-- **************************************************************************************************************
--	Delete not considered frequency variables on this report
PRINT 'DELETE NOT CONSIDERED FREQUENCY VARIABLES ON THIS REPORT ' + CONVERT(VARCHAR,GETDATE(),120)
DELETE FROM #All_Variables WHERE SUBSTRING(Frequency,4,100) NOT IN (SELECT CType FROM #CType)

-----------------------------------------------------------------------------------------------------------------
-- Assign values FROM Tests table
-----------------------------------------------------------------------------------------------------------------
PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + 'Assign values FROM Tests table'

INSERT INTO #Tests (Var_id,Frequency,Start_Date,End_Date,Result_On,Result,Entry_On,Include_Test,Tested,OnTime,Comment_Id)
SELECT 	av.var_id,
		av.Frequency,
		av.Start_Date,
		av.End_Date,
		t.Result_On,
		t.Result,
		t.Entry_On,
		'No',
		(CASE Isnull(t.Result,'') 
			WHEN '' THEN 'No'
            -- WHEN NULL Then 'No'
			ELSE 'Yes' END) AS Tested,
		0,
  		t.Comment_Id 
FROM #All_Variables av 	WITH(NOLOCK) --With(Index(IDX_VarId_ResultOn))
JOIN dbo.Tests t 		WITH (NOLOCK) 	ON 	av.var_id = t.var_id 
										AND t.Result_On >= av.Start_Date 
										AND t.Result_On <= av.End_Date
WHERE t.Canceled <> 1
AND t.Entry_on >= av.Start_Date 
AND t.Entry_On <= av.End_Date
--SG: Removed so it takes all the results regardless the entry on, it'll be considered as not completed on the KPI.

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

UPDATE #Tests
SET	OnTime = 1
WHERE Entry_On <= End_Date

IF @columnsTobeIncluded <> 1
BEGIN
	SELECT TOP 1 @ResOn = Result_On FROM #Tests WITH(NOLOCK) WHERE Result_On > @FirstShift order by Result_On ASC
	
	DELETE FROM #Tests WHERE Result_On <> ISNULL(@ResOn, '1970-01-01')
END

-- CO - Adding comments 
UPDATE t
SET	t.Comment = c.Comment_Text
FROM #Tests t
JOIN dbo.Comments c (NOLOCK) ON t.Comment_id = c.Comment_id 

UPDATE #All_Variables
	SET TestIdx = t.TestIdx
FROM #All_Variables av 
JOIN #Tests t WITH(NOLOCK) ON av.var_id = t.var_id AND av.Start_Date = t.Start_Date AND av.End_Date = t.End_Date

UPDATE #All_Variables
	SET Result = t.Result,--(Case t.Result WHEN @Pass Then '1' ELSE t.Result END), SG: It need to process non-numeric results.
		Result_On = t.Result_On,
		Stubbed = 'Yes',
		Entry_On = t.Entry_On,
		On_Time = t.OnTime,
		Comment = t.Comment
FROM #All_Variables av 
JOIN #Tests t WITH(NOLOCK) ON av.var_id = t.var_id AND av.TestIdx = t.TestIdx

-- Adding missing variables into #All_Variables. 

INSERT INTO	#All_Variables (
		PL_Id,
		Line,
		PU_Id,
		MasterPUDesc,
		ChildPUDesc,
		av.Var_ID,
		Var_Type,
		Var_Desc,
		Pug_Desc,
		Test_Time,
		Master,
		Frequency,
		Start_Date,
		End_Date,
		Due_Date,
		Next_Start_Date,
		Samples_Due,
		Future_Samples_Due,
		Samples_Taken,
		Result,
		Result_On,
		Entry_On,
		On_Time,
		Defects,
		Team,
		Shift,
		Line_Status,
		Include_Result,
		Include_Crew,
		Include_Shift,
		Include_LineStatus,
		Include_Test,
		Stubbed,
		Canceled,
		Test_Freq,
		CurrentSpec,
		TestIdx,
		Comment
		)
SELECT	PL_Id,
		Line,
		PU_Id,
		MasterPUDesc,
		ChildPUDesc,
		av.Var_ID,
		Var_Type,
		Var_Desc,
		Pug_Desc,
		Test_Time,
		Master,
		t.Frequency,
		av.Start_Date,
		av.End_Date,
		Due_Date,
		Next_Start_Date,
		Samples_Due,
		Future_Samples_Due,
		Samples_Taken,
		t.Result,
		t.Result_On,
		t.Entry_On,
		t.OnTime,
		Defects,
		Team,
		Shift,
		Line_Status,
		Include_Result,
		Include_Crew,
		Include_Shift,
		Include_LineStatus,
		av.Include_Test,
		'Yes',
		Canceled,
		Test_Freq,
		CurrentSpec,
		t.TestIdx,
		t.Comment
FROM	#All_Variables av
JOIN	#Tests t WITH(NOLOCK) ON av.Var_Id = t.Var_Id AND t.TestIdx != av.TestIdx AND av.Start_Date = t.Start_Date AND t.Result_On != av.Result_On

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert #All_Variables'
	   RETURN
	END
--******************************************************************************************************
-- Delete variables that has no column Stubbed
DELETE FROM #All_Variables WHERE Stubbed = 'No'


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Delete #All_Variables'
	   RETURN
	END
--******************************************************************************************************

--**********************************************************************************
-- Determine IF Test Results should be included based ON END-user's 'Crew/Team' Criteria
 --SELECT * FROM #Tests WHERE Var_Id = 47717
--**********************************************************************************

PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + ' Validating Crew/Shift'
DECLARE 
        @min_start_date as DATETIME,
        @max_End_date as DATETIME

SELECT @min_start_date	=	Min(start_date) 	FROM 	#All_Variables WITH(NOLOCK)
SELECT @max_End_date	=	Max(End_date) 		FROM 	#All_Variables WITH(NOLOCK)
SELECT @MaxEndCS		=	Max(End_date) 		FROM 	#All_Variables WITH(NOLOCK)

SET @max_End_date = DATEADD(dd,1,@max_End_date)

INSERT Into @Production_Starts(Pu_id, Prod_id, Prod_Code, Prod_Desc,Start_Time,End_Time)
SELECT   DISTINCT Ps.Pu_id, Ps.Prod_id, P.Prod_Code, P.Prod_Desc,  Ps.Start_Time, Ps.End_Time      
FROM 	dbo.Production_Starts	PS	WITH(NOLOCK) 
        JOIN #PL_Ids			tpl	WITH(NOLOCK)				ON tpl.ProdStarts_PUId = PS.PU_ID  
																AND ps.Start_Time <= @max_End_date 
																AND (ps.End_Time > @min_start_date 
																OR ps.End_Time IS NULL)
        JOIN dbo.Products_Base	P	WITH(NOLOCK)	ON ps.Prod_ID = P.Prod_ID

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Insert @Production_Starts'
	   RETURN
	END
	
INSERT INTO	@DEPREventSubtypes
	SELECT	Event_Subtype_Id,
			Event_Subtype_Desc
	FROM	dbo.Event_Subtypes	WITH (NOLOCK)
	WHERE	Event_Subtype_Desc IN ('Centerline Auto', 'Centerline Manual', 'Centerline CPE Weekly', 'Centerline CPE Monthly', 'Centerline CPE Quarterly')

INSERT INTO @DEPRUDE (EndTime, PUId, SubtypeId)
	SELECT	MAX(End_Time),
			PU_Id,
			Event_Subtype_Id
	FROM	dbo.User_Defined_Events e	WITH (NOLOCK)
	JOIN	@Units u	ON (e.PU_Id = u.UnitId OR e.PU_Id = u.MasterUnit)
	WHERE	Event_Subtype_Id IN (SELECT SubtypeId FROM @DEPREventSubtypes)
	GROUP BY Event_Subtype_Id, PU_Id

UPDATE	u
	SET		Frequency = CASE
							WHEN SubtypeDesc LIKE '%Manual%'
								THEN 'a) Shiftly Manual'
							WHEN SubtypeDesc LIKE '%Auto%'
								THEN 'b) Shiftly Auto'
							WHEN SubtypeDesc LIKE '%Weekly%'
								THEN 'd) Weekly'
							WHEN SubtypeDesc LIKE '%Monthly%'
								THEN 'e) Monthly'
							WHEN SubtypeDesc LIKE '%Quarterly%'
								THEN 'f) Quarterly'
							ELSE
								NULL
						END
	FROM	@DEPRUDE u
	JOIN	@DEPREventSubtypes s ON u.SubtypeId = s.SubtypeId

IF OBJECT_ID('tempdb..#Crew_Schedule') IS NOT NULL
BEGIN
	DROP TABLE #Crew_Schedule
END

SELECT	cs.*
INTO 	#Crew_Schedule
FROM	dbo.Crew_Schedule 	cs 		WITH(NOLOCK)
-- JOIN 	#PL_Ids 			tpl 	WITH(NOLOCK) ON 	tpl.PU_ID = cs.PU_ID
JOIN 	#PL_Ids 			tpl 	WITH(NOLOCK) ON ISNULL(tpl.PUID_CS, tpl.Conv_ID) = cs.PU_ID
WHERE  cs.End_Time >= @min_start_date AND cs.End_Time <= @max_End_date

DELETE FROM #Crew_Schedule WHERE Start_Time > @MaxEndCS

UPDATE cs
SET		End_Time = @MaxEndCS
FROM	#Crew_Schedule cs
WHERE	End_Time > @MaxEndCS

---------------------------------------------------------------------------------------------------
-- Set Product information.
---------------------------------------------------------------------------------------------------
UPDATE #All_Variables
      	SET     Prod_ID = ps.Prod_id,
    	        Prod_Code = PS.Prod_Code,
                Prod_Desc = Ps.Prod_Desc

	FROM #All_Variables tdt 
	JOIN @Production_Starts PS ON tdt.PU_ID = PS.PU_ID
	WHERE Result_On >= ps.Start_Time 
		AND (Result_On < ps.End_Time OR ps.End_Time IS NULL)

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

IF (SELECT COUNT(SubtypeId) FROM @DEPRUDE) > 0
 BEGIN
	UPDATE #All_Variables
      		SET     Team = cs.Crew_DESC, 
			Shift = cs.Shift_DESC                
		FROM #All_Variables tdt --With(Index(IDX_VarId_ResultOn))
		JOIN #PL_Ids tpl 		WITH(NOLOCK) 	ON tdt.PL_ID = tpl.PL_ID
		JOIN #Crew_Schedule cs 	WITH(NOLOCK)	ON tpl.PU_ID = cs.PU_ID
		WHERE Start_Date >= cs.Start_Time 
			AND (Start_Date < cs.End_Time OR cs.End_Time IS NULL)
		--WHERE DATEADD(mi,-DATEDIFF(mi, Start_Date, End_Date),Result_On) >= cs.Start_Time 
		--	AND (DATEADD(mi,-DATEDIFF(mi, Start_Date, End_Date),Result_On) < cs.End_Time OR cs.End_Time IS NULL)

 END
ELSE
 BEGIN
	UPDATE #All_Variables
      		SET     Team = cs.Crew_DESC, 
			Shift = cs.Shift_DESC                
		FROM #All_Variables tdt --With(Index(IDX_VarId_ResultOn))
		JOIN #PL_Ids tpl 		WITH(NOLOCK) 	ON tdt.PL_ID = tpl.PL_ID
		JOIN #Crew_Schedule cs 	WITH(NOLOCK)	ON tpl.PU_ID = cs.PU_ID
		WHERE Result_On >= cs.Start_Time 
			AND (Result_On < cs.End_Time OR cs.End_Time IS NULL)
 END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

-----------------------------------------------------------------------------------------------------------------------
UPDATE #All_Variables
      	SET     Line_Status = er.Event_Reason_Name -- lpg.Phrase_Value          
	FROM #All_Variables tdt --With(Index(IDX_VarId_ResultOn))
	JOIN dbo.NonProductive_Detail npt WITH(NOLOCK) ON tdt.PU_Id = npt.PU_Id
	JOIN dbo.Event_Reasons er WITH(NOLOCK) ON npt.Reason_Level1 = er.Event_Reason_Id
	--JOIN @NonProdTime  npt ON npt.PUId = tdt.PU_Id
	WHERE Result_On >= npt.Start_Time -- lpg.start_DATETIME
			AND (Result_On < npt.End_Time -- lpg.End_DATETIME 
						OR npt.End_Time IS NULL) -- lpg.End_DATETIME IS NULL)
		
-----------------------------------------------------------------------------------------------------------------------
-- As Non Productive Time only stores when there is something that is out, then we have to fill all the PR Ins
-----------------------------------------------------------------------------------------------------------------------
UPDATE #All_Variables
	SET Line_Status = 'PR In:Line Normal'
WHERE Line_Status IS NULL

--*******************************************************************************************************
--	BRD #60 - Add Column of Process Order
--*******************************************************************************************************
UPDATE av
SET	av.ProcessOrderiD	= pos.PPId,
	av.ProcessOrder		= pos.PO
FROM #All_Variables av
JOIN #ProcessOrders pos WITH(NOLOCK) On pos.puid = pu_id
WHERE av.Result_On <= pos.EndTime and av.Result_On >= pos.StartTime

-----------------------------------------------------------------------------------------------------------------------
-- Apply LineStatus, Team, Shift & Product Filter
-----------------------------------------------------------------------------------------------------------------------

IF @InLineStatus <> 'All'
	DELETE FROM #All_Variables WHERE Line_Status NOT IN (SELECT PLStatusDesc FROM #PLStatusDescList WITH(NOLOCK))

IF @InCrew <> 'All'
	DELETE FROM #All_Variables WHERE Team NOT IN (SELECT String FROM dbo.fnLocal_Split(@InCrew, ',')) AND Frequency IN ('a) Shiftly Manual','b) Shiftly Auto')
	
IF @InCrew <> 'All' AND @InGroupBy = 'Team'
	DELETE FROM #All_Variables WHERE Team NOT IN (SELECT String FROM dbo.fnLocal_Split(@InCrew, ','))

IF @InShift <> 'All'
	DELETE FROM #All_Variables WHERE Shift NOT IN (SELECT String FROM dbo.fnLocal_Split(@InShift, ',')) AND Frequency IN ('a) Shiftly Manual','b) Shiftly Auto')

IF @InShift <> 'All' AND @InGroupBy = 'Team'
	DELETE FROM #All_Variables WHERE Shift NOT IN (SELECT String FROM dbo.fnLocal_Split(@InShift, ','))

IF @InProdCode <> 'All'
	DELETE FROM #All_Variables WHERE Prod_Id NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProdCode, ',')) AND Frequency IN ('a) Shiftly Manual','b) Shiftly Auto')

IF @InProdCode <> 'All' AND @InGroupBy = 'Product'
	DELETE FROM #All_Variables WHERE Prod_Id NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProdCode, ','))

IF @InProcessOrder <> 'All' AND @InGroupBy = 'PO'
	BEGIN
		DELETE FROM #All_Variables WHERE ProcessOrderiD NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProcessOrder, ',')) OR ProcessOrderiD IS NULL 
		DELETE FROM #ProcessOrders WHERE PPId NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProcessOrder, ','))
	END

IF @InProcessOrder <> 'All'
	BEGIN
		DELETE FROM #All_Variables WHERE ProcessOrderiD NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProcessOrder, ',')) OR ProcessOrderiD IS NULL 
	END

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

-- **********************************************************************************
-- Need to UPDATE the Active Specs for that variable taking IN acCOUNT the Result_on
-- date to get the correct Specification for the Variable
-- **********************************************************************************
PRINT CONVERT(VARCHAR(25), GETDATE(), 120) +  'Assigning specs'
-- All specs variables for current time

UPDATE #All_variables
	SET  
	  L_Reject  = (CASE ISNUMERIC(a_s.l_reject)		WHEN 1 THEN (CASE CHARINDEX(',', a_s.l_reject)		WHEN 0 THEN a_s.l_reject ELSE '77777' END) ELSE		(CASE ISNULL(a_s.l_reject, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.l_reject,
	  L_Warning = (CASE ISNUMERIC(a_s.l_warning)	WHEN 1 THEN (CASE CHARINDEX(',', a_s.l_warning)		WHEN 0 THEN a_s.l_warning ELSE '77777' END) ELSE	(CASE ISNULL(a_s.l_warning, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.l_warning,
	  L_User    = (CASE ISNUMERIC(a_s.l_user)		WHEN 1 THEN (CASE CHARINDEX(',', a_s.l_user)		WHEN 0 THEN a_s.l_user ELSE '77777' END) ELSE		(CASE ISNULL(a_s.l_user, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.l_user,
	  Target    = (CASE ISNUMERIC(a_s.target)		WHEN 1 THEN (CASE CHARINDEX(',', a_s.target)		WHEN 0 THEN a_s.target ELSE '77777' END) ELSE		(CASE ISNULL(a_s.target, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.target,
	  U_User    = (CASE ISNUMERIC(a_s.u_user)		WHEN 1 THEN (CASE CHARINDEX(',', a_s.u_user)		WHEN 0 THEN a_s.u_user ELSE '77777' END) ELSE		(CASE ISNULL(a_s.u_user, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.u_user,
	  U_Warning = (CASE ISNUMERIC(a_s.u_warning)	WHEN 1 THEN (CASE CHARINDEX(',', a_s.u_warning)		WHEN 0 THEN a_s.u_warning ELSE '77777' END) ELSE	(CASE ISNULL(a_s.u_warning, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.u_warning,
	  U_Reject  = (CASE ISNUMERIC(a_s.u_reject)		WHEN 1 THEN (CASE CHARINDEX(',', a_s.u_reject)		WHEN 0 THEN a_s.u_reject ELSE '77777' END) ELSE		(CASE ISNULL(a_s.u_reject, '1') WHEN '1' THEN NULL ELSE '77777' END) END), --a_s.u_reject,
      Test_Freq = 1,
      CurrentSpec = 'Yes'
FROM
        #All_Variables av 
 	    JOIN dbo.Var_Specs a_s WITH (NOLOCK) ON av.var_id = a_s.var_id 
        	    AND a_s.Effective_date <= Result_On 
        	    AND (a_s.expiration_date > Result_On or a_s.expiration_date IS NULL)
				AND a_s.Prod_ID = av.Prod_ID
		AND a_s.Test_Freq = 1 
WHERE Var_Type = 'VARIABLE'


UPDATE #All_variables
	SET  
	  L_Reject  = (CASE CHARINDEX(',',a_s.L_Reject)		WHEN 0 THEN a_s.L_Reject	ELSE	(CASE ISNULL(a_s.L_Reject,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
	  L_Warning = (CASE CHARINDEX(',',a_s.L_Warning)	WHEN 0 THEN a_s.L_Warning	ELSE	(CASE ISNULL(a_s.L_Warning,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
	  L_User    = (CASE CHARINDEX(',',a_s.L_User)		WHEN 0 THEN a_s.L_User		ELSE	(CASE ISNULL(a_s.L_User,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
	  Target	= (CASE CHARINDEX(',',a_s.Target)		WHEN 0 THEN a_s.Target		ELSE	(CASE ISNULL(a_s.Target,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
	  U_User    = (CASE CHARINDEX(',',a_s.U_User)		WHEN 0 THEN a_s.U_User		ELSE	(CASE ISNULL(a_s.U_User,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
	  U_Warning = (CASE CHARINDEX(',',a_s.U_Warning)	WHEN 0 THEN a_s.U_Warning	ELSE	(CASE ISNULL(a_s.U_Warning,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
	  U_Reject  = (CASE CHARINDEX(',',a_s.U_Reject)		WHEN 0 THEN a_s.U_Reject	ELSE	(CASE ISNULL(a_s.U_Reject,	'1')	WHEN '1' THEN NULL ELSE '77777' END)END),
      Test_Freq = 1,
      CurrentSpec = 'Yes'
FROM
        #All_Variables av 
 	    JOIN dbo.Var_Specs a_s WITH (NOLOCK) ON av.var_id = a_s.var_id 
        	    AND a_s.Effective_date <= Result_On 
        	    AND (a_s.expiration_date > Result_On or a_s.expiration_date IS NULL)
				AND a_s.Prod_ID = av.Prod_ID
		AND a_s.Test_Freq = 1 
WHERE Var_Type = 'ATTRIBUTE'


IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END


IF	(SELECT COUNT(*) 
	FROM #All_Variables WITH(NOLOCK) 
	WHERE (L_Reject = '77777' OR
		L_Warning = '77777' OR
		L_User = '77777' OR 
		Target = '77777' OR
		U_Warning = '77777' OR 
		U_User = '77777' OR 
		U_Reject = '77777')) > 0
	BEGIN

	SELECT 'Error : Report cannot complete! Non numeric or comma(,) were found in the RTT specification limits instead of decimal(s) or numeric values. Please contact your RTT SSO to correct the issue(s) and rerun the report.' AS Err1
	SELECT 'Var_Id' AS Var_Id, 'Var_Desc' AS Var_Desc, 'Prod_Id' AS Prod_Id, 'L_Reject' AS L_Reject, 'Target' AS Target, 'U_Reject' AS U_Reject
	SELECT DISTINCT av.Var_Id, av.Var_Desc, vs.Prod_Id, vs.L_Reject, vs.Target, vs.U_Reject
	FROM #All_Variables	av WITH(NOLOCK)
	JOIN dbo.Var_Specs	vs	WITH(NOLOCK)	ON(vs.Var_Id = av.Var_Id 
												AND vs.Prod_Id = av.Prod_Id
												AND (av.L_Reject = '77777' OR
													av.L_Warning = '77777' OR
													av.L_User = '77777' OR 
													av.Target = '77777' OR
													av.U_Warning = '77777' OR 
													av.U_User = '77777' OR 
													av.U_Reject = '77777')
												AND vs.Effective_Date <= Result_On
												AND (vs.Expiration_Date > Result_On OR
													vs.Expiration_Date IS NULL)
												AND vs.Test_Freq = 1)
	RETURN
	END


PRINT CONVERT(VARCHAR(25), GETDATE(), 120) +  ' Parsings'
--************************************************************************************
-- Determine IF this Test Result should be included based ON the Crew, Shift Criteria
--************************************************************************************        	
	IF @inCrew <> 'ALL'
   	  BEGIN
      		UPDATE #All_Variables
		            SET Include_Crew = 'No'
		    WHERE CHARINDEX(@inCrew, Team, 1) = 0

			If @@Error <> 0
			BEGIN
	   
				SELECT 'Error in Update #All_Variables'
				RETURN
			END
      END
      
    IF @inShift <> 'ALL'
    BEGIN
      	UPDATE #All_Variables
	            SET Include_Shift = 'No'
	    WHERE CHARINDEX(@inShift, Shift, 1) = 0

		If @@Error <> 0
		BEGIN
		   
		   SELECT 'Error in Update #All_Variables'
		   RETURN
		END
    END 	    

	UPDATE #All_Variables
		SET Line_Status = 'None'
	WHERE(Line_Status IS NULL)

	If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END	
	
	IF @inLineStatus <> 'ALL'
		UPDATE #All_Variables 
				SET Include_LineStatus = 'No'
		WHERE Line_Status NOT IN (SELECT PLStatusDesc FROM #PLStatusDescList )		
	ELSE
		UPDATE #All_Variables 
				SET Include_LineStatus = 'No'
		WHERE Line_Status IS NULL

	IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END
	
-- **********************************************************************************
-- UPDATE "Samples Taken" field WHERE results are not null AND not like " "
-- **********************************************************************************
UPDATE #All_Variables
	SET Samples_Taken = 1
	WHERE Result is not null and
        Result <> '123abcxxx'

IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END

--**********************************************************************************
-- UPDATE "Defects" field WHERE variable results are > upper limit or < lower limit
--**********************************************************************************
-- Check OOS depending on Site Parameters SpecificationSetting
IF @SpecSetting = 1 -- Test Value > Limit Triggers Spec Exceedence
BEGIN
	UPDATE #All_Variables
		SET Defects = 1
		WHERE Var_Type = 'VARIABLE' 
		AND Result <> '123abcxxx'
		AND (CAST(Result AS FLOAT) > CAST(U_Reject AS FLOAT)
		OR CAST(Result AS FLOAT) < CAST(L_Reject AS FLOAT))

	IF @@ERROR <> 0
		BEGIN

			SELECT 'Error in Update #All_Variables'
			RETURN
		END
END

IF @SpecSetting = 2 -- Test Value >= Limit Triggers Spec Exceedence
BEGIN
	UPDATE #All_Variables
		SET Defects = 1
		WHERE Var_Type = 'VARIABLE' 
		AND Result <> '123abcxxx'
		AND (CAST(Result AS FLOAT) >= CAST(U_Reject AS FLOAT)
		OR CAST(Result AS FLOAT) <= CAST(L_Reject AS FLOAT))

	IF @@ERROR <> 0
		BEGIN

			SELECT 'Error in Update #All_Variables'
			RETURN
		END
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
-- UPDATE "Defects" field WHERE attribute results <> Target
--**********************************************************************************
UPDATE #All_Variables
	SET Defects = 1
	WHERE Var_Type = 'ATTRIBUTE'
	AND Result <> Target

IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END
	 	
--**********************************************************************************
-- UPDATE the "Include Results" Flag
--**********************************************************************************	   
UPDATE #All_Variables
	SET Include_Result = 'Yes'
	WHERE Include_Crew = 'Yes'
	AND Include_Shift = 'Yes'
	AND Include_LineStatus = 'Yes'

IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END
  
--**********************************************************************************
-- UPDATE the 'Result', 'Samples_Completed' AND 'Defects' fields WHERE 
-- no matching data IN #Tests (no samples taken)
--**********************************************************************************	   
UPDATE #All_Variables
	SET Samples_Taken = 0, 
		Result = '', 
		Defects = 1
	FROM #All_Variables
	WHERE Result = '123abcxxx'

IF @@ERROR <> 0
	BEGIN
		SELECT 'Error in Update #All_Variables'
		RETURN
	END	


--**************************************
--	UPDATE Due Date for Daily variables.
--**************************************
UPDATE	av
SET	Due_Date = DATEADD(hh,CONVERT(INT,SUBSTRING(Test_Time,5,2)),DATEADD(mi,CONVERT(INT,SUBSTRING(Test_Time, 3,2)),CONVERT(DATETIME,CONVERT(DATE,Result_On))))
FROM #All_Variables av
WHERE Frequency = 'c) Daily'

--**********************************************************************************
-- UPDATE Samples_Due field WHERE Due_Date > @End_Date
--**********************************************************************************
UPDATE #All_Variables
	SET Samples_Due = 1 -- Due
        WHERE Due_Date <= @InENDTime --AND Samples_Taken = 0 

IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END
	
--**********************************************************************************
-- UPDATE Future_Samples_Due field WHERE Start_Date < @End_Date
-- 	Added comparison of the current date. IF report END date is less than current Date
-- 	then tests are SET to overdue IF the Next_start_Date is <= report END date, IF the 
--	report END date is greater than the current date, then only tests that are less than
--	report END date are considered overdue.
--*********************************************************************************

UPDATE #All_Variables 
	SET Future_Samples_Due =  1
WHERE Due_Date > @InENDTime --AND Samples_Taken = 0

IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END

--**********************************************************************************
-- UPDATE Samples_Taken field WHERE no samples are due
--**********************************************************************************
	Delete FROM #All_Variables
	WHERE Samples_Taken = 0	AND Samples_Due = 0 AND Future_Samples_Due = 0
	
	IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END
	
--*******************************************************************************************************
-- UPDATE Defects field WHERE no samples are due, IF the sample is Due then still no defect
--*******************************************************************************************************
	UPDATE #All_Variables
	        SET Defects = 0
	WHERE Samples_Taken = 0 -- Samples_Due = 0

	IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END
	

---------------------------------------------------------------------
-- Get Acknowledge function.
---------------------------------------------------------------------

-- Get sheet ids.
UPDATE	av
SET		Sheet_Id = sv.Sheet_Id
FROM	#All_Variables av
JOIN	Sheet_Variables sv WITH (NOLOCK) ON av.Var_Id = sv.Var_Id
JOIN	Sheets s WITH (NOLOCK) ON sv.Sheet_Id = s.Sheet_Id
WHERE	s.Sheet_Desc NOT LIKE '%Alarms%'

INSERT INTO @TCVars
SELECT	sv.Sheet_Id,
		sv.Var_Id
FROM	Variables_Base v (NOLOCK)
JOIN	Sheet_Variables sv (NOLOCK) ON v.Var_Id = sv.Var_Id
JOIN	(	SELECT Sheet_Id
			FROM	#All_Variables WITH(NOLOCK)
			GROUP BY Sheet_Id
		) AS s ON sv.Sheet_id = s.Sheet_Id
WHERE	Extended_Info LIKE '%ForceAck%'

-- Get Test Confirm results within the scope.
INSERT INTO	#TC_Tests
SELECT	VarId,
		t.Result,
		t.Result_On
FROM	@TCVars v
JOIN	Tests t (NOLOCK) ON v.VarId = t.Var_Id
WHERE	t.Result_On >= @min_start_date
  AND	t.Result_On <= @max_end_date

UPDATE	av
SET		TestConfirm =	CASE
							WHEN t.Result IS NULL THEN '0'
							ELSE t.Result
						END
FROM	#All_Variables av
JOIN	@TCVars v ON av.Sheet_Id = v.SheetId
JOIN	#TC_Tests t WITH(NOLOCK) ON v.VarId = t.VarId AND av.Result_On = t.ResultOn

UPDATE	av
SET		Samples_Taken = 0,
		Defects = 1
FROM	#All_Variables av
WHERE	TestConfirm = 0

UPDATE	av
SET		Samples_Taken = 0
FROM	#All_Variables av
WHERE	On_Time = 0
  AND	Result IS NOT NULL

IF @@ERROR <> 0
	BEGIN

		SELECT 'Error in Update #All_Variables'
		RETURN
	END

-----------------------------------------------------------------
--	Gather Event Reasons for alarms.
-----------------------------------------------------------------
PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + ' START Gather Event Reasons'

SELECT	@MinStartDate = MIN(Start_Time),
		@MaxEndDate = MAX(End_Time)
FROM	#Time_Frames WITH(NOLOCK)

SELECT @TempCL = ERC_Id FROM Event_Reason_Catagories (NOLOCK) WHERE Erc_Desc = 'TempCL'

INSERT INTO #EventReasons
SELECT	e.Event_Reason_Id,
		e.Event_Reason_Name,
		'Action',
		0
FROM	#Pre_Var_Ids v 			WITH(NOLOCK)
JOIN	Alarms a 					(NOLOCK) ON v.Var_Id = a.Key_Id
JOIN	Event_Reasons e 			(NOLOCK) ON a.Action1 = e.Event_Reason_Id
WHERE	End_Time IS NULL
   OR	(a.Start_Time >= @MinStartDate AND a.End_Time <= @MaxEndDate)
GROUP BY e.Event_Reason_Id, e.Event_Reason_Name

INSERT INTO #EventReasons
SELECT	e.Event_Reason_Id,
		e.Event_Reason_Name,
		'Cause',
		0
FROM	#Pre_Var_Ids v 			WITH(NOLOCK)
JOIN	Alarms a 					(NOLOCK) ON v.Var_Id = a.Key_Id
JOIN	Event_Reasons e 			(NOLOCK) ON a.Cause1 = e.Event_Reason_Id
WHERE	End_Time IS NULL
   OR	(a.Start_Time >= @MinStartDate AND a.End_Time <= @MaxEndDate)
GROUP BY e.Event_Reason_Id, e.Event_Reason_Name

UPDATE	e
SET		TempCL = (CASE WHEN ercd.erc_id = @TempCL THEN 1 ELSE 0 END)
FROM	#EventReasons e
LEFT JOIN	Event_Reason_Tree_Data ertdc WITH (NOLOCK) ON e.ReasonId = ertdc.Event_Reason_Id
LEFT JOIN	Event_Reason_Category_Data ercd WITH (NOLOCK) ON ertdc.Event_Reason_Tree_Data_Id = ercd.Event_Reason_Tree_Data_Id

PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + ' END Gather Event Reasons - START Alarm Priorities'

-----------------------------------------------------------------
--	Gather Priorities for alarms.
-----------------------------------------------------------------
INSERT INTO #AlarmPriority
SELECT	a.Alarm_Id,
		p.AP_Desc
FROM	#Pre_Var_Ids v 						WITH(NOLOCK)
JOIN	Alarms a								(NOLOCK) ON v.Var_Id = a.Key_id
JOIN	Alarm_Template_Var_Data atd 			(NOLOCK) ON a.ATD_Id = atd.ATD_Id
JOIN	Alarm_Template_Variable_Rule_Data atvrd (NOLOCK) ON atd.ATVRD_Id = atvrd.ATVRD_Id
JOIN	Alarm_Priorities p 						(NOLOCK) ON atvrd.AP_Id = p.AP_Id
WHERE	End_Time IS NULL
   OR	(a.Start_Time >= @MinStartDate AND a.End_Time <= @MaxEndDate)

PRINT CONVERT(VARCHAR(25), GETDATE(), 120) + ' END Alarm Priorities - START Open Alarms'

--*******************************************************************************************************
-- Create Open Alarm Variables Table
--*******************************************************************************************************

INSERT INTO @OAVariables (
					AlarmId			,
					DeptDesc		,
					LineDesc		,
					MasterDesc		,
					PUId			,
					SlaveDesc		,
					VarId			,
					VarDesc			,
					ResultOnOOS		,
					Team			,
					Shift			,
					QFactor			,
					Recipe			,
					Frequency
					)
SELECT DISTINCT		
					Alarm_Id		,
					DeptDesc		,
					LineDesc		,
					MasterDesc		,
					MasterUnit		,
					UnitDesc		,
					Var_Id			,
					Var_Desc		,
					Start_Time		,
					'No Team'		,
					'No Shift'		,
					0				,
                    (CASE 
						WHEN v.Is_Recipe = 'Yes' 
							THEN 1 
							ELSE 0 
						END)		,
					v.Frequency
FROM	@Units u
JOIN	Alarms a 		WITH (NOLOCK) ON u.UnitId = a.Source_PU_Id
JOIN	#Pre_Var_Ids v	WITH (NOLOCK) ON  a.Key_Id = v.Var_Id
WHERE	a.End_Time IS NULL

If @@Error <> 0
	BEGIN
   
	   SELECT 'Error in Insert @OAVariables'
	   RETURN
	END


IF @VersionSelection = '3.0'
BEGIN
	UPDATE oav
	SET		Frequency	= (	CASE
								WHEN Value LIKE '%S%' THEN 'a) Shiftly Manual'
								WHEN Value LIKE '%D%' THEN 'c) Daily'
								WHEN Value LIKE '%W%' THEN 'd) Weekly'
								WHEN Value LIKE '%M%' THEN 'e) Monthly'
								WHEN Value LIKE '%Q%' THEN 'f) Quarterly'
								END)
	FROM	@OAVariables oav
	JOIN	Table_Fields_Values tfv WITH (NOLOCK) ON oav.VarId = tfv.KeyId
	WHERE	Table_Field_Id = @AuditFreqUDP
	AND	TableId = @VarTableId
END

UPDATE oav
SET		PUGroup = Value
FROM	@OAVariables oav
JOIN	dbo.Table_Fields_Values	tfv	WITH(NOLOCK) ON oav.VarId = tfv.KeyId
WHERE 	TableId = @VarTableId
  AND	Table_Field_id = @AreaUDP


UPDATE oav
SET		LReject		= L_Reject,
		Target		= vs.Target,
		UReject		= U_Reject
FROM	@OAVariables oav
JOIN	Var_Specs vs WITH (NOLOCK) ON oav.VarId = vs.Var_Id
JOIN	@Products p ON vs.Prod_Id = p.ProdId
WHERE	Expiration_Date IS NULL

UPDATE oav
SET		ResultOOS = t.Result
FROM	@OAVariables oav
JOIN	Tests t WITH (NOLOCK) ON oav.VarId = t.Var_Id AND oav.ResultOnOOS = t.Result_On

SELECT	@Current = 1,
		@Stop = MAX(OAVIdx) + 1
FROM	@OAVariables

WHILE	@Current < @Stop
BEGIN
	UPDATE oav
	SET	Team = cs.Crew_Desc,
		[Shift] = cs.Shift_Desc
	FROM @OAVariables			oav
	JOIN dbo.Crew_Schedule 		cs		WITH (NOLOCK)		ON (oav.PUId = cs.PU_Id 
																AND cs.Start_Time < oav.ResultOnOOS 
																AND cs.End_Time > oav.ResultOnOOS)
	WHERE OAVIdx = @Current

	SET @Current = @Current + 1
END
  

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update @OAVariables'
	   RETURN
	END

--*******************************************************************************************************
-- Create CLOSED ALARMS Variables Table
--*******************************************************************************************************
PRINT CONVERT(VARCHAR(25), GETDATE(), 120) +  ' END Open Alarms - START Closed Alarms'

IF @AlarmType <> 'Open'
BEGIN
	INSERT INTO	@ClosedAlarms (
					AlarmId,
					DeptDesc,
					LineDesc,
					MasterDesc,
					PUId,
					SlaveDesc,
					VarId,
					VarDesc,
					AlarmDesc,
					StartTime,
					EndTime,
					StartResult,
					EndResult,
					MinResult,
					MaxResult,
					QFactor,
					Recipe,
					CauseId,
					ActionId,
					CauseCommentId,
					ActionCommentId,
					Frequency
					)
	SELECT			Alarm_Id,
					DeptDesc,
					LineDesc,
					MasterDesc,
					MasterUnit,
					(CASE 
						WHEN UnitDesc = MasterDesc 
							THEN NULL 
							ELSE UnitDesc 
						END),
					Var_Id,
					Var_Desc,
					Alarm_Desc,
					a.Start_Time,
					a.End_Time,
					Start_Result,
					End_Result,
					Min_Result,
					Max_Result,
					0,
					(CASE 
						WHEN v.Is_Recipe = 'Yes' 
							THEN 1 
						ELSE 0 
					END),
					Cause1,
					Action1,
					Cause_Comment_Id,
					Action_Comment_Id,
					v.Frequency
	FROM	@Units u
	JOIN	Alarms a 		WITH(NOLOCK) ON u.UnitId = a.Source_PU_Id
	JOIN	#Pre_Var_Ids v 	WITH(NOLOCK) ON a.Key_Id = v.Var_Id
	WHERE	(a.End_Time >= @InStartTime AND a.End_Time <= @InEndTime) 
	OR a.Start_Time <= @InEndTime AND a.End_Time >= @InEndTime
END

IF @VersionSelection = '3.0'
BEGIN
	UPDATE ca
	SET		Frequency	= (	CASE
								WHEN Value LIKE '%S%' THEN 'a) Shiftly Manual'
								WHEN Value LIKE '%D%' THEN 'c) Daily'
								WHEN Value LIKE '%W%' THEN 'd) Weekly'
								WHEN Value LIKE '%M%' THEN 'e) Monthly'
								WHEN Value LIKE '%Q%' THEN 'f) Quarterly'
								END)
	FROM	@ClosedAlarms ca
	JOIN	Table_Fields_Values tfv WITH (NOLOCK) ON ca.VarId = tfv.KeyId
	WHERE	Table_Field_Id = @AuditFreqUDP
	AND	TableId = @VarTableId
END

UPDATE	ca
SET		PUGroup = Value
FROM	@ClosedAlarms ca
JOIN	Table_Fields_Values tfv WITH (NOLOCK) ON ca.VarId = tfv.KeyId
WHERE	Table_Field_Id = @AreaUDP
  AND	TableId = @VarTableId
   
UPDATE	ca
SET		LReject = L_Reject,
		ca.Target = vs.Target,
		UReject = U_Reject
FROM	@ClosedAlarms ca
JOIN	Var_Specs vs WITH (NOLOCK) ON ca.VarId = vs.Var_Id
JOIN	@Products p ON vs.Prod_Id = p.ProdId
WHERE	Expiration_Date IS NULL

UPDATE	ca
SET		ResultOOS = StartResult,
		ResultOnOOS = StartTime
FROM	@ClosedAlarms ca

SELECT	@Current = 1,
		@Stop = MAX(CAIdx) + 1
FROM	@ClosedAlarms

WHILE	@Current < @Stop
BEGIN
	UPDATE ca
	SET	Team = cs.Crew_Desc,
		[Shift] = cs.Shift_Desc
	FROM @ClosedAlarms			ca
	JOIN dbo.Crew_Schedule 		cs		WITH (NOLOCK)		ON (ca.PUId = cs.PU_Id 
																AND cs.Start_Time < ca.StartTime 
																AND cs.End_Time > ca.StartTime)
	WHERE CAIdx = @Current

	SET @Current = @Current + 1
END

UPDATE	ca
SET		Cause = erc.ReasonName,
		Action = era.ReasonName
		--TempCL = erc.TempCL
FROM	@ClosedAlarms ca
LEFT JOIN	#EventReasons erc WITH (NOLOCK) ON ca.CauseId = erc.ReasonId
LEFT JOIN	#EventReasons era WITH (NOLOCK) ON ca.ActionId = era.ReasonId

UPDATE	ca
SET		TempCL = er.TempCL
FROM	@ClosedAlarms ca
LEFT JOIN	#EventReasons er WITH (NOLOCK) ON ca.CauseId = er.ReasonId or ca.ActionId = er.ReasonId

-- CO Adding Comments
UPDATE ca
SET ca.Comment_id = ts.Comment_id
FROM @ClosedAlarms ca
JOIN dbo.Tests ts (nolock) on ts.Result_On = ca.StartTime and ts.var_id = ca.VarId

UPDATE ca
SET ca.Comment = cm.Comment_text
FROM @ClosedAlarms ca
JOIN dbo.Comments cm (nolock) on cm.Comment_id = ca.Comment_id 

UPDATE	ca
SET		CauseComments = cc.Comment_Text,
		ActionComments = ac.Comment_Text
FROM	@ClosedAlarms ca
LEFT JOIN	Comments cc WITH (NOLOCK) ON ca.CauseCommentId = cc.Comment_Id
LEFT JOIN	Comments ac WITH (NOLOCK) ON ca.ActionCommentId = ac.Comment_Id

UPDATE	ca
SET		ca.Priority = ap.Priority
FROM @ClosedAlarms ca
JOIN #AlarmPriority ap WITH(NOLOCK) ON ca.AlarmId = ap.AlarmId 

UPDATE ca
SET		 ProcessOrderiD	= pp.PP_Id
		,ProcessOrder	= pp.Process_Order
FROM @ClosedAlarms ca
JOIN Prod_Units_base pu with(nolock) on ca.MasterDesc = pu.pu_desc
JOIN dbo.production_plan_starts pps with(nolock) on ((ca.StartTime between pps.Start_Time and pps.End_Time and pps.pu_id=pu.pu_id) or (ca.Starttime>pps.Start_Time and pps.End_time is null and pps.pu_id=pu.pu_id))
join dbo.production_plan pp with(nolock) on pps.pp_id=pp.pp_id

If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update @ClosedAlarms'
	   RETURN
	END

--*******************************************************************************************************
-- Create the Output Temp Table
PRINT CONVERT(VARCHAR(25), GETDATE(), 120) +  'END Parsings'


--*******************************************************************************************************
-- Create the Output Temp Table

INSERT @OpenAlarms (
			AlarmId				   ,
	        PL_Desc                ,
	        VarId                  ,
			MasterDesc			   ,
	        Var_Desc               ,
			Alarm_Desc			   ,
	        Start_Time             ,
			EndTime				   ,
	        Start_Result           ,
			End_Result			   ,
			CauseId				   ,
			Cause_Comment_ID	   ,
			ActionId			   ,
	        Action_Comment_ID      ,
	        Min_Result             ,
	        Max_Result             ,
	        Priority			   ,
			Last_Result_On		   )
SELECT		
			a.Alarm_id			,
			pl.PL_Desc			,
			v.Var_Id			, 
			pu.pu_desc			,
			v.Var_Desc			, 
			a.Alarm_Desc		,
			a.Start_Time		, 
			a.End_Time			,
			a.Start_Result		, 
			a.End_Result		,
            a.Cause1, 
			a.Cause_Comment_Id		,
			a.Action1,
			a.Action_Comment_Id, 
			a.Min_Result, 
            a.Max_Result, 
			NULL ,
			a.Modified_On
	FROM #Pre_Var_ids v  				WITH(NOLOCK)
		JOIN dbo.Alarms a 				WITH(NOLOCK) ON v.Var_Id = a.Key_Id 
		JOIN dbo.Prod_Units_Base	pu 	WITH(NOLOCK)	ON pu.PU_Id = v.PU_Id
		JOIN dbo.Prod_Lines_Base	pl	WITH(NOLOCK) ON pl.PL_Id = pu.PL_Id
		JOIN #Time_Frames f 			WITH(NOLOCK) ON v.Frequency = f.Frequency AND (a.Start_Time >= f.Start_Time AND a.Start_Time <= f.End_Time)

--*************************************************************************************************
-- Get open alarms per unit.
--*************************************************************************************************
INSERT @OpenAlarms (
			AlarmId					,
	        PL_Desc					,
	        VarId					,
			MasterDesc				,
	        Var_Desc				,
			Alarm_Desc				,
	        Start_Time				,
			EndTime					,
	        Start_Result			,
			End_Result				,
	        CauseId					,
			Cause_Comment_ID		,
	        ActionId					,
	        Action_Comment_ID		,
	        Min_Result				,
	        Max_Result				,
	        Priority				,
			IsTempCL				,
			Last_Result_On			)
SELECT		
			a.Alarm_id				,
			u.LineDesc				,
			v.VarId					, 
			u.UnitDesc				,
			v.VarDesc				, 
			a.Alarm_Desc			,
			a.Start_Time			, 
			a.End_Time				,
			a.Start_Result			, 
			a.End_Result			,
            a.Cause1				,
			a.Cause_Comment_Id		,
			a.Action1				,
			a.Action_Comment_Id		, 
			a.Min_Result			, 
            a.Max_Result			, 
			NULL					,
			0,--(CASE WHEN ercd.erc_id = @TempCL THEN 1 ELSE 0 END),
			a.Modified_On			
	FROM			@OAVariables v 
		JOIN		dbo.Alarms a 						WITH(NOLOCK) ON v.AlarmId = a.Alarm_Id AND a.Alarm_Id NOT IN (SELECT AlarmId FROM @OpenAlarms) -- Avoid having repeated alarms.
		JOIN		@Units u 										 ON a.Source_PU_Id = u.UnitId


--*******************************************************************************************************
-- Get the Open Alarms for Current Variables

UPDATE #All_Variables
		SET Alarm_Id = alms.Alarm_Id 
FROM #All_Variables av
JOIN dbo.Alarms alms WITH(NOLOCK) 	ON av.Var_Id = alms.key_id 
									AND alms.Start_Time <= av.Result_On
									AND (alms.End_Time >= av.Result_On Or alms.End_Time Is NULL)


If @@Error <> 0
	BEGIN
	   
	   SELECT 'Error in Update #All_Variables'
	   RETURN
	END

--*******************************************************************************************************
-- Update Action, Cause and isTempCL for alarms
--*******************************************************************************************************

UPDATE	oa
SET		Cause = erc.ReasonName,
		Action = era.ReasonName
FROM	@OpenAlarms oa
LEFT JOIN	#EventReasons erc WITH (NOLOCK) ON oa.CauseId = erc.ReasonId
LEFT JOIN	#EventReasons era WITH (NOLOCK) ON oa.ActionId = era.ReasonId

UPDATE	oa
SET		IsTempCL = er.TempCL
FROM	@OpenAlarms oa
LEFT JOIN	#EventReasons er WITH (NOLOCK) ON oa.CauseId = er.ReasonId or oa.ActionId = er.ReasonId					  

--*******************************************************************************************************
-- Update FROM #All_Variables: Include HSE Flag
--*******************************************************************************************************
INSERT INTO @tblHSETag
SELECT		Var_Id, Var_Desc
FROM dbo.Table_Fields_Values	tfv	WITH(NOLOCK)
JOIN dbo.Table_Fields			tf	WITH(NOLOCK)	ON tfv.Table_Field_Id = tf.Table_Field_Id
JOIN #Pre_Var_IDs				pv	WITH(NOLOCK)	ON pv.Var_Id = tfv.KeyId
WHERE	tf.Table_Field_Desc = 'HSE Flag' 
AND		tfv.Value = '1'

UPDATE #All_Variables
SET	HSETag = 1
FROM #All_Variables av
JOIN @tblHSETag hse ON av.Var_Id = hse.Var_Id 

IF @@Error <> 0
BEGIN
	SELECT 'Error in Update #All_Variables'
	RETURN
END


--*******************************************************************************************************
-- Update #All_Variables: Include department.
--*******************************************************************************************************
UPDATE v
SET v.Dept_Id = d.Dept_Id,
	v.Department = d.Dept_Desc
FROM #All_Variables v
JOIN Prod_Lines_Base l WITH (NOLOCK)
			ON v.PL_Id = l.PL_Id
JOIN Departments_Base d WITH (NOLOCK)
			ON l.Dept_Id = d.Dept_Id

--*******************************************************************************************************
-- Update #All_Variables and @OAVariables: Include Q-Factor.
--*******************************************************************************************************
UPDATE #All_Variables
SET QFactor = 0

UPDATE av
SET QFactor = 1
FROM #All_Variables av
JOIN @QFactorTable q ON av.Var_Id = q.VarId

UPDATE oav
SET QFactor = 1
FROM @OAVariables oav
JOIN @QFactorTable q ON oav.VarId = q.VarId

UPDATE ca
SET QFactor = 1
FROM @ClosedAlarms ca
JOIN @QFactorTable q ON ca.VarId = q.VarId

--*******************************************************************************************************
-- Update #All_Variables and @OAVariables: Include Recipe.
--*******************************************************************************************************
UPDATE #All_Variables
SET Recipe = 0


IF @VersionSelection = '3.0'
BEGIN
	UPDATE av
	SET av.Recipe = tfv.Value
	FROM #All_Variables av
	JOIN Table_Fields_Values tfv WITH(NOLOCK) ON av.Var_Id = tfv.KeyId
	WHERE Table_Field_Id = @IsRecipeUDP
	  and TableId = @VarTableId
END
ELSE IF @VersionSelection = '3.1'
BEGIN
	UPDATE av
	SET av.Recipe = (CASE tfv.Value WHEN 'Recipe' THEN 1 ELSE 0 END)
	FROM #All_Variables av
	JOIN Table_Fields_Values tfv WITH(NOLOCK) ON av.Pug_Id = tfv.KeyId
	WHERE Table_Field_Id = @GroupTypeUDP
	  and TableId = @PUGTableId
END


IF @VersionSelection = '3.0'
BEGIN
	UPDATE oav
	SET oav.Recipe = tfv.Value
	FROM @OAVariables oav
	JOIN Table_Fields_Values tfv WITH(NOLOCK) ON oav.VarId = tfv.KeyId
	WHERE Table_Field_Id = @IsRecipeUDP
	and TableId = @VarTableId

	UPDATE ca
	SET ca.Recipe = tfv.Value
	FROM @ClosedAlarms ca
	JOIN Table_Fields_Values tfv WITH(NOLOCK) ON ca.VarId = tfv.KeyId
	WHERE Table_Field_Id = @IsRecipeUDP
	and TableId = @VarTableId
END ELSE IF @VersionSelection = '3.1'
BEGIN
	UPDATE oav
	SET oav.Recipe = (CASE tfv.Value WHEN 'Recipe' THEN 1 ELSE 0 END)
	FROM @OAVariables oav
	JOIN Table_Fields_Values tfv WITH(NOLOCK) ON oav.VarId = tfv.KeyId
	WHERE Table_Field_Id = @GroupTypeUDP
	and TableId = @PUGTableId

	UPDATE ca
	SET ca.Recipe = (CASE tfv.Value WHEN 'Recipe' THEN 1 ELSE 0 END)
	FROM @ClosedAlarms ca
	JOIN Table_Fields_Values tfv WITH(NOLOCK) ON ca.VarId = tfv.KeyId
	WHERE Table_Field_Id = @GroupTypeUDP
	and TableId = @PUGTableId
END

--*******************************************************************************************************
-- Cause and Action comments on @OpenAlarms.
--*******************************************************************************************************
UPDATE oa
SET CauseComments = Comment_Text
FROM @OpenAlarms oa
JOIN Comments c WITH (NOLOCK) ON oa.Cause_Comment_Id = c.Comment_Id

UPDATE oa
SET ActionComments = Comment_Text
FROM @OpenAlarms oa
JOIN Comments c WITH (NOLOCK) ON oa.Action_Comment_Id = c.Comment_Id

--*******************************************************************************************************
-- Alarm Priority on @OpenAlarms.
--*******************************************************************************************************
UPDATE oa
SET oa.Priority = ap.Priority
FROM @OpenAlarms oa
JOIN #AlarmPriority ap WITH(NOLOCK) ON oa.AlarmId = ap.AlarmId
--*******************************************************************************************************
-- Last Result
--*******************************************************************************************************
SELECT	@Current = 1,
		@Stop = MAX(OAIdx) + 1
FROM @OpenAlarms

UPDATE oa
SET	oa.Last_Result_On = t.Result_On
FROM @OpenAlarms oa
JOIN (
		SELECT t.Var_Id, Result_On = MAX(t.Result_On)
		FROM Tests t (NOLOCK)
		JOIN @OpenAlarms oa1 ON t.Var_Id = oa1.VarID
								AND t.Result IS NOT NULL
		GROUP BY t.Var_Id) t ON t.Var_Id = oa.VarId

UPDATE oa
SET Last_Result = Result,
	Comment_id	= t.Comment_Id
FROM @OpenAlarms oa
JOIN Tests t WITH(NOLOCK) ON oa.VarId = t.Var_Id AND oa.Last_Result_On = t.Result_On

-- CO Adding comments
UPDATE oa
SET Comment = cm.Comment_Text
FROM @OpenAlarms oa
JOIN dbo.Comments cm WITH(NOLOCK) ON oa.Comment_id = cm.Comment_id 

--*******************************************************************************************************
-- Equipment Area
--*******************************************************************************************************
UPDATE oa
SET Area = PUG_Desc
FROM @OpenAlarms oa
JOIN #Pre_Var_IDs v WITH(NOLOCK) ON oa.VarId = v.Var_ID

--*******************************************************************************************************
-- BRD 60
--*******************************************************************************************************
UPDATE oa
SET		 ProcessOrderiD	= pp.PP_Id
		,ProcessOrder	= pp.Process_Order
FROM @OpenAlarms oa
JOIN Prod_Units_base pu with(nolock) on oa.MasterDesc = pu.pu_desc
JOIN dbo.production_plan_starts pps with(nolock) on ((oa.Start_Time between pps.Start_Time and pps.End_Time and pps.pu_id=pu.pu_id) or (oa.Start_time>pps.Start_Time and pps.End_time is null and pps.pu_id=pu.pu_id))
join dbo.production_plan pp with(nolock) on pps.pp_id=pp.pp_id

--*******************************************************************************************************
-- Get #Alarms with only the last value entered
--*******************************************************************************************************
INSERT INTO #Alarms (
				PlantName						,
				Department						,
				Line							,
				MasterUnit						,
				SlaveUnit						,
				VarId							,
				VariableDescription				,
				AlarmDescription				,
				EquipmentUnit					,
				Team							,
				Shift							,
				Frequency						,
				StartTime						,
				EndTime							,
				StartResult						,
				EndResult						,
				MinResult						,
				MaxResult						,
				LastCheck						,
				LastResult						,
				ValueOOS						,
				FinalValue						,
				RejectLimit						,
				Target							,
				UpperReject						,
				Status							,
				TempCenterline					,
				QFactor							,
				Recipe							,
				Cause							,
				CauseComments					,
				Action							,
				ActionComments					,
				Priority						,
				Comment							,
				ProcessOrderiD					,
				ProcessOrder
				)
SELECT			@Plant_Name		,
				DeptDesc		,
				LineDesc		,
				MasterDesc		,
				SlaveDesc		,
				VarId			,
				VarDesc			,
				AlarmDesc		,
				PUGroup			,
				Team			,
				Shift			,
				Frequency		,
				StartTime		,
				EndTime			,
				StartResult		,
				EndResult		,
				MinResult		,
				MaxResult		,
				EndTime			,
				EndResult		,
				StartResult		,
				EndResult		,
				LReject			,
				Target			,
				UReject			,
				'Closed'		,
				TempCL			,
				QFactor			,
				Recipe			,
				Cause			,
				CauseComments	,
				Action			,
				ActionComments	,
				Priority		,
				Comment			,
				ProcessOrderiD	,
				ProcessOrder	
FROM	@ClosedAlarms ca

--*******************************************************************************************************
-- INSERT Alarms with end time NULL and source pu id IN @Units.
--*******************************************************************************************************
INSERT INTO #Alarms (
				PlantName						,
				Department						,
				Line							,
				MasterUnit						,
				SlaveUnit						,
				VarId							,
				VariableDescription				,
				AlarmDescription				,
				EquipmentUnit					,
				Team							,
				Shift							,
				Frequency						,
				StartTime						,
				EndTime							,
				StartResult						,
				EndResult						,
				MinResult						,
				MaxResult						,
				LastCheck						,
				LastResult						,
				ValueOOS						,
				FinalValue						,
				RejectLimit						,
				Target							,
				UpperReject						,
				Status							,
				TempCenterline					,
				QFactor							,
				Recipe							,
				Cause							,
				CauseComments					,
				Action							,
				ActionComments					,
				Priority						,
				Comment_id						,
				ProcessOrderiD					,
				ProcessOrder			
			)
SELECT DISTINCT
				@Plant_Name						,
				u.DeptDesc						,
				u.LineDesc						,
				u.MasterDesc					,
				CASE WHEN u.UnitDesc = u.MasterDesc THEN NULL ELSE u.UnitDesc END,
				oa.VarId						,
				oa.Var_Desc						,
				oa.Alarm_Desc					,
				oav.PUGroup						,
				oav.Team						,
				oav.Shift						,
				oav.Frequency					,
				oa.Start_Time					,
				oa.EndTime						,
				oa.Start_Result					,
				oa.End_Result					,
				oa.Min_Result					,
				oa.Max_Result					,
				oa.Last_Result_On				,
				oa.Last_Result					,
				oav.ResultOOS					,
				oa.Max_Result					,
				oav.LReject						,
				oav.Target						,
				oav.UReject						,
				(CASE 
						WHEN oa.EndTime IS NULL 
						THEN 'Open' 
						ELSE 'Closed' 
				END)							,
				oa.IsTempCL						,
				oav.QFactor						,
				oav.Recipe						,
				oa.Cause						,
				oa.CauseComments				,
				oa.Action						,
				oa.ActionComments				,
				oa.Priority						,
				oa.Comment_id					,
				oa.ProcessOrderiD				,
				oa.ProcessOrder	
FROM	@OAVariables oav
JOIN	@OpenAlarms oa ON oav.AlarmId = oa.AlarmId
JOIN	@Units u ON oav.LineDesc = u.LineDesc AND oav.MasterDesc = u.MasterDesc AND oav.SlaveDesc = u.UnitDesc

-- CO Adding Comments 
UPDATE al
SET al.Comment = oa.Comment
FROM #Alarms al
JOIN @OpenAlarms oa ON al.Comment_id = oa.Comment_id

--*******************************************************************************************************
-- Update #Alarms: Include Prod Code and Prod Desc
--*******************************************************************************************************
UPDATE a
SET ProdCode = Prod_Code,
	ProdDesc = Prod_Desc
FROM #Alarms a
JOIN Prod_Units_Base u WITH (NOLOCK)
		ON a.MasterUnit = u.PU_Desc
JOIN Production_Starts ps WITH (NOLOCK) 
		ON (a.StartTime >= ps.Start_Time AND a.StartTime < ISNULL(ps.End_Time,a.LastCheck))
		AND u.PU_Id = ps.PU_Id
JOIN Products_Base p WITH (NOLOCK)
		ON ps.Prod_Id = p.Prod_Id

UPDATE	a
SET	TempCenterline = (CASE TempCenterline WHEN 'True' THEN 1 ELSE 0 END)
FROM #Alarms a

--*******************************************************************************************************
-- If AHistory is selected remove all alarms that were not open during the timeframe of the report.
--*******************************************************************************************************
DELETE FROM #Alarms 
WHERE StartTime > @InEndTime
AND EndTime < @InStartTime

----------------------------------------------------------------------------------------------------------------
-- If it's Recipe, return empty alarms table.
----------------------------------------------------------------------------------------------------------------

IF @InReportType = 'Recipe'
BEGIN
	DELETE FROM #Alarms
END

----------------------------------------------------------------------------------------------------------------
-- If it's Q-Factor Only, return ONLY QFactor variables alarms.
----------------------------------------------------------------------------------------------------------------

IF @QFactorOnly <> 0
BEGIN
	DELETE FROM #Alarms WHERE QFactor = 0
END

----------------------------------------------------------------------------------------------------------------
-- Delete from alarms accoring the the group filter
----------------------------------------------------------------------------------------------------------------

IF(@InGroupBy = 'Product')
BEGIN
	DELETE FROM #Alarms WHERE ProdCode NOT IN (SELECT ProdCode FROM dbo.Products_Base WHERE Prod_Id IN (SELECT String FROM dbo.fnLocal_Split(@InProdCode, ',')))
END
IF(@InGroupBy = 'PO')
BEGIN
	DELETE FROM #Alarms WHERE ProcessOrderID NOT IN (SELECT String FROM dbo.fnLocal_Split(@InProcessOrder, ','))
END
IF(@InGroupBy = 'Team')
BEGIN
	DELETE FROM #Alarms WHERE Team NOT IN (SELECT String FROM dbo.fnLocal_Split(@InCrew, ','))
END

-- Delete TestConfirm variables.
DELETE av FROM #All_Variables AS av WHERE av.Var_Id IN (SELECT v.Var_Id FROM dbo.Variables_Base v(NOLOCK) WHERE av.Var_ID = v.Var_Id and v.Extended_Info = 'ForceAck')

-- Set defect where result is NULL.
UPDATE #All_Variables SET Defects = 1 WHERE Result IS NULL

-- Update Due_Date for the result.

UPDATE #All_Variables SET Due_Date = Result_On WHERE Frequency IN ('a) Shiftly Manual','b) Shiftly Auto')
UPDATE #All_Variables SET Due_Date = DATEADD(hh,CONVERT(INT,SUBSTRING(Test_Time,3,2)),DATEADD(mi,CONVERT(INT,SUBSTRING(Test_Time,5,2)),CONVERT(DATETIME,CONVERT(DATE,Due_Date)))) WHERE Frequency = 'c) Daily'
UPDATE #All_Variables SET Due_Date = DATEADD(dd,-1,Due_Date) WHERE Due_Date > Result_On

--*******************************************************************************************************
-- Get Output data!
--*******************************************************************************************************
IF(@KPISummary = 0)
BEGIN 

	----------------------------------------------------------------------------------------------------------------
	-- Get Details data
	----------------------------------------------------------------------------------------------------------------
		SELECT 
					--@Plant_Name					ServerName			,
					av.Department										,
					av.Line												,
					av.MasterPUDesc					'MasterUnit'		,
					av.ChildPUDesc					'ChildUnit'			,
					av.Pug_Desc						'PUGroup'			,
					av.Team												,
					av.Shift											,
					av.Line_Status					ProdStatus			,
					SUBSTRING(av.Frequency,4,100)	Frequency			,
					av.Result_On					ResultOn			,
					av.Result											,
					av.L_Reject						LReject				,
					av.L_Warning					LWarning			,
					av.L_User						LUser				,
					av.Target											,
					av.U_User						UUser				,
					av.U_Warning					UWarning			,
					av.U_Reject						UReject				,
					av.Samples_Taken				SamplesTaken		,
					av.Samples_Due					SamplesDue			,
					av.Future_Samples_Due			FutureSamplesDue	,
					av.Defects						OOS					,
					av.Prod_Desc					ProdDesc			,
					av.Var_Desc						VarDesc				,
					av.Var_Id						VarId				,
					av.Prod_Code					ProdCode			,
					av.Next_Start_Date				NextStartDate		,
					av.Test_Time					TestTime			,
					av.TestConfirm										,
					ISNULL(HSETag, 0)				HSETag				,
					av.Recipe											,
					av.QFactor											,
					av.Entry_On											, 
					av.On_Time											,
					av.Due_Date						ActiveOn            ,
	   				av.Comment											,
					av.ProcessOrder
		FROM	#All_Variables av WITH(NOLOCK)
		WHERE	(@HSETag = 0 OR HSETag = @HSETag)
		order by av.result_on
	
	----------------------------------------------------------------------------------------------------------------
	-- Get Alarms data
	---------------------------------------------------------------------------------------------------------------- 
	SELECT	
			PlantName		'ServerName'	,
			Department						,
			Line							,
			MasterUnit						,
			SlaveUnit						,
			EquipmentUnit   'PUGroup'		,
			QFactor							,
			VariableDescription				,
			AlarmDescription				,
			RejectLimit		'L_Reject'		,
			Target							,
			UpperReject		'U_Reject'		,
			StartTime						,
			EndTime							,
			StartResult						,
			EndResult						,
			Cause							,
			CauseComments					,
			Action							,
			ActionComments					,
			MinResult						,
			MaxResult						,
			LastCheck						,
			LastResult						,
			Priority						,
			ProdCode						,
			ProdDesc						,
			Status							,
			--FinalValue		'Final Value'	,
			ValueOOS		'Value OOS'		,
			TempCenterline					,
			Comment							,
			ProcessOrder
	FROM	#Alarms WITH(NOLOCK)
END
ELSE
BEGIN

	--	Init #KPISummarization table according to grouping option parameter
	IF(@InGroupBy = 'Product')
	BEGIN

		INSERT INTO #KPISummarization (GroupBy)
		SELECT DISTINCT ProdDesc
		FROM	@Products
	END
	ELSE IF (@InGroupBy = 'Team')
	BEGIN

		INSERT INTO #KPISummarization (GroupBy)
		SELECT DISTINCT String 
		FROM dbo.fnLocal_Split(@InCrew, ',')
	END
	ELSE IF (@InGroupBy = 'Lines')
	BEGIN

		INSERT INTO #KPISummarization (GroupBy)
		SELECT DISTINCT PL_Desc
		FROM	#PL_IDs WITH(NOLOCK)
	END
	ELSE IF (@InGroupBy = 'Workcell')
	BEGIN

		INSERT INTO #KPISummarization (GroupBy)
		SELECT DISTINCT MasterDesc
		FROM @Units
	END
	ELSE IF (@InGroupBy = 'PO') -- BRD #60
	BEGIN

		INSERT INTO #KPISummarization (GroupBy)
		SELECT DISTINCT PO
		FROM #ProcessOrders WITH(NOLOCK)
	END

	--	KPIs Summary calculation section
	UPDATE kpi
	SET kpi.SamplesTaken = (		SELECT ISNULL(SUM(Samples_Taken), 0)
									FROM	#All_Variables av WITH(NOLOCK)
									WHERE	(@HSETag = 0 OR HSETag = @HSETag)
										AND av.Recipe = 0
										AND	(av.Line = kpi.GroupBy
											OR av.MasterPUDesc = kpi.GroupBy
											OR av.Team = kpi.GroupBy
											OR av.Prod_Desc = kpi.GroupBy
											OR av.ProcessOrder = kpi.GroupBy)),

		kpi.SamplesNonRecipe = (	SELECT ISNULL(COUNT(av.Recipe), 0)
									FROM	#All_Variables av WITH(NOLOCK)
									WHERE	(@HSETag = 0 OR HSETag = @HSETag)
										AND av.Recipe = 0
										AND	(av.Line = kpi.GroupBy
											OR av.MasterPUDesc = kpi.GroupBy
											OR av.Team = kpi.GroupBy
											OR av.Prod_Desc = kpi.GroupBy
											OR av.ProcessOrder = kpi.GroupBy)),

		kpi.SamplesDefects = (		SELECT ISNULL(SUM(av.Defects), 0)
									FROM	#All_Variables av WITH(NOLOCK)
									WHERE	(@HSETag = 0 OR HSETag = @HSETag)
										AND av.Recipe = 0
										AND	(av.Line = kpi.GroupBy
											OR av.MasterPUDesc = kpi.GroupBy
											OR av.Team = kpi.GroupBy
											OR av.Prod_Desc = kpi.GroupBy
											OR av.ProcessOrder = kpi.GroupBy)),

		kpi.OutComplianceRecipe = (		SELECT COUNT(Defects)
										FROM	#All_Variables av WITH(NOLOCK)
										WHERE	(@HSETag = 0 OR HSETag = @HSETag)
											AND av.Defects = 1
											AND av.Recipe = 1
											AND	(av.Line = kpi.GroupBy
												OR av.MasterPUDesc = kpi.GroupBy
												OR av.Team = kpi.GroupBy
												OR av.Prod_Desc = kpi.GroupBy
												OR av.ProcessOrder = kpi.GroupBy)),

		kpi.OutComplianceQFactor = (	SELECT COUNT(Defects)
										FROM	#All_Variables av WITH(NOLOCK)
										WHERE	(@HSETag = 0 OR HSETag = @HSETag)
											AND av.Defects = 1
											AND av.QFactor = 1
											AND	(av.Line = kpi.GroupBy
												OR av.MasterPUDesc = kpi.GroupBy
												OR av.Team = kpi.GroupBy
												OR av.Prod_Desc = kpi.GroupBy
												OR av.ProcessOrder = kpi.GroupBy)),

		kpi.QFactorDone	= (		SELECT COUNT(Samples_Taken )
								FROM	#All_Variables av WITH(NOLOCK)
								WHERE	(@HSETag = 0 OR HSETag = @HSETag)
									AND av.Samples_Taken = 1
									AND av.QFactor = 1
									AND	(av.Line = kpi.GroupBy
										OR av.MasterPUDesc = kpi.GroupBy
										OR av.Team = kpi.GroupBy
										OR av.Prod_Desc = kpi.GroupBy
										OR av.ProcessOrder = kpi.GroupBy)),
	
		kpi.DueChecks = (		SELECT COUNT(Samples_Due)
								FROM	#All_Variables av WITH(NOLOCK)
								WHERE	(@HSETag = 0 OR HSETag = @HSETag)
									AND av.Samples_Due = 1
									AND av.Recipe = 0
									AND	(av.Line = kpi.GroupBy
										OR av.MasterPUDesc = kpi.GroupBy
										OR av.Team = kpi.GroupBy
										OR av.Prod_Desc = kpi.GroupBy
										OR av.ProcessOrder = kpi.GroupBy)),


		kpi.NotCompletedChecks = (		SELECT COUNT(*)
								FROM	#All_Variables av WITH(NOLOCK)
								WHERE	(@HSETag = 0 OR HSETag = @HSETag)
									AND av.Samples_Taken = 0
									AND av.Recipe = 0
									AND	(av.Line = kpi.GroupBy
										OR av.MasterPUDesc = kpi.GroupBy
										OR av.Team = kpi.GroupBy
										OR av.Prod_Desc = kpi.GroupBy
										OR av.ProcessOrder = kpi.GroupBy))
	FROM #KPISummarization		kpi
	
	UPDATE #KPISummarization		
	SET	OutCompliance = SamplesDefects

	UPDATE kpi
	SET kpi.TempCenterline= (	SELECT COUNT(*)
								FROM #Alarms	a	  WITH(NOLOCK)
								WHERE TempCenterline = 1
									AND (a.Line = kpi.GroupBy
										OR a.MasterUnit = kpi.GroupBy
										OR a.Team = kpi.GroupBy
										OR a.ProdDesc = kpi.GroupBy
										OR a.ProcessOrder = kpi.GroupBy)),

		kpi.OpenAlarms = (		SELECT COUNT(*)
								FROM #Alarms	a	  WITH(NOLOCK)
								WHERE EndTime IS NULL
									AND (a.Line = kpi.GroupBy
										OR a.MasterUnit = kpi.GroupBy
										OR a.Team = kpi.GroupBy
										OR a.ProdDesc = kpi.GroupBy
										OR a.ProcessOrder = kpi.GroupBy)),
									
		kpi.ClosedAlarms = (	SELECT COUNT(*)
								FROM #Alarms	a	  WITH(NOLOCK)
								WHERE EndTime IS NOT NULL
									AND (a.Line = kpi.GroupBy
										OR a.MasterUnit = kpi.GroupBy
										OR a.Team = kpi.GroupBy
										OR a.ProdDesc = kpi.GroupBy
										OR a.ProcessOrder = kpi.GroupBy))
	FROM #KPISummarization		kpi

	--	KPIs Summary calculation here (Total)
	INSERT INTO #KPISummarization (GroupBy) VALUES ('Total')

	UPDATE #KPISummarization 
	SET SamplesTaken = (	SELECT SUM(SamplesTaken)
							FROM #KPISummarization  WITH(NOLOCK)),

		SamplesNonRecipe = (	SELECT SUM(SamplesNonRecipe)
								FROM #KPISummarization  WITH(NOLOCK)),

		SamplesDefects = (	SELECT SUM(SamplesDefects)
							FROM #KPISummarization WITH(NOLOCK)),

		OutCompliance = (	SELECT SUM(OutCompliance)
							FROM #KPISummarization WITH(NOLOCK)),

		DueChecks = (	SELECT SUM(DueChecks)
						FROM #KPISummarization WITH(NOLOCK)),
	
		TempCenterline = (	SELECT SUM(TempCenterline)
							FROM #KPISummarization WITH(NOLOCK)),

		OutComplianceRecipe = (	SELECT SUM(OutComplianceRecipe)
								FROM #KPISummarization WITH(NOLOCK)),

		QFactorDone = (	SELECT SUM(QFactorDone)
						FROM #KPISummarization WITH(NOLOCK)),

		OutComplianceQFactor = (	SELECT SUM(OutComplianceQFactor)
									FROM #KPISummarization WITH(NOLOCK)),

		OpenAlarms =  (	SELECT SUM(OpenAlarms)
						FROM #KPISummarization WITH(NOLOCK)),

		ClosedAlarms =  (	SELECT SUM(ClosedAlarms)
							FROM #KPISummarization WITH(NOLOCK)),

		NotCompletedChecks =  (	SELECT SUM(NotCompletedChecks)
								FROM #KPISummarization WITH(NOLOCK))
	WHERE GroupBy = 'Total'

	UPDATE #KPISummarization		
	SET	OutCompliance = SamplesDefects,
		Completion = 	CASE
							WHEN	SamplesNonRecipe <> 0	THEN (SamplesTaken / SamplesNonRecipe)
							ELSE	0
						END,
		Compliance =	CASE
							WHEN	SamplesNonRecipe <> 0	THEN ((SamplesNonRecipe - SamplesDefects) / SamplesNonRecipe)
							ELSE	0
						END

	SELECT *
	FROM #KPISummarization WITH(NOLOCK)
END


--******************************************************************************************
-- Debug
--------------------------------------------------------------------------------------------
  --SELECT '#Pre_Var_ids', av.* FROM #Pre_Var_ids av --WHERE Var_Id = 3549
  --SELECT '#Tests', * FROM #Tests-- WHERE Var_Id = 54138
 --SELECT * FROM #Pre_Var_IDs
 --SELECT * FROM @OAVariables
--SELECT 'Alarms', * FROM #Alarms  
 --SELECT '@QFactorTable', * FROM @QFactorTable
 --SELECT '#Time_Frames', * FROM #Time_Frames --WHERE Frequency LIKE '%daily%'
 --SELECT @BegOfMonth, @EndOfMonth
 --SELECT * FROM #Tests WHERE frequency like '%da%' order by result_on
 --SELECT @CurrentStart '@CurrentStart'
 --SELECT '#Time_Frames', * FROM #Time_Frames where frequency like '%dai%'
--SELECT '#All_Variables', * FROM #All_Variables av --where frequency like '%dai%' order by Due_Date---var_desc = '100  Auto 04' order by result_on
 --select @InStartTime, @InEndTime
--------------------------------------------------------------------------------------------
--==========================================================================================
DROP TABLE #Tests
DROP TABLE #Time_Frames
DROP TABLE #All_Variables
DROP TABLE #Pre_Var_IDs
DROP TABLE #PL_IDs
DROP TABLE #PU_IDs
DROP TABLE #PLStatusDescList
DROP TABLE #Crew_Schedule
DROP TABLE #Parsed_PUIDs
DROP TABLE #Alarms
DROP TABLE #Line_Status
DROP TABLE #TC_Tests
DROP TABLE #CType
DROP TABLE #EventReasons
DROP TABLE #AlarmPriority
DROP TABLE #KPISummarization
DROP TABLE #ProcessOrders

SET NOCOUNT OFF
GO


GRANT EXECUTE  ON [dbo].[spLocal_Centerline30]  TO [OpDBManager]
GO
GRANT EXECUTE ON [dbo].[spLocal_CmnRptCrewFilter] TO [OpDBManager]
GO