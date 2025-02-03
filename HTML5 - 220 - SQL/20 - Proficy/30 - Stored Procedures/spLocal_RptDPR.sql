
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
-----------------------------------------------------------------------------------------------------------------------

-----------------------------------[Register SP Version]-----------------------------------------
SET NOCOUNT ON
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'splocal_RptDPR',
		@Inputs		= 10,
		@Version	= '1.1'

SELECT @AppId = MAX(App_Id) + 1 
		FROM AppVersions

-------------------------------------------------------------------------------------------------
--	Update table AppVersions
-------------------------------------------------------------------------------------------------
IF (SELECT COUNT(*) 
		FROM AppVersions 
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE AppVersions 
		SET app_version = @Version
		WHERE app_name like @SP_Name

	SELECT TOP 1 @AppId = App_Id
		FROM AppVersions 
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

PRINT '- Registered ' +  @SP_Name + ' ( App_Id : ' + CONVERT(VARCHAR,@AppId) + ' - Version : ' + @Version + ' )'

SET NOCOUNT OFF
GO


-----------------------------------------------------------------------------------------------------------------------
-- Drop Store Procedure
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (
			SELECT * FROM dbo.sysobjects 
				WHERE Id = OBJECT_ID(N'[dbo].[splocal_RptDPR]') 
				AND OBJECTPROPERTY(id, N'IsProcedure') = 1					
			)
	DROP PROCEDURE [dbo].[splocal_RptDPR]
GO



--========================================================================================================================================
--------------------------------------------------------------------------------------------------
-- Stored Procedure: splocal_RptDPR
--------------------------------------------------------------------------------------------------
-- Author				: <Fernando Rios, Arido Software>
-- Date created			: 2005?
-- Version 				: Version 2.0
-- SP Type				: Report
-- Caller				: Report template (Excel)
-- Description			: Returns result seta used by Baby/Fem Daily Production (DPR) report.
-- Editor tab spacing	: 4 <for devlopers so they can set visual studio correctly>
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
/*--------------------------------------------------------------------------------------------------
-- Revision		Date			Who					What  
-- ========		=====			=====				=====
-- 1.0			2018-12-28		Martin Casalis		Initial Release
-- 1.1			2019-08-28		Damian Campana		Capability to filter with the time option 'Last Week'    
*/
--------------------------------------------------------------------------------------------------  
-- Report parameters :  
--------------------------------------------------------------------------------------------------  
CREATE PROCEDURE [dbo].[splocal_RptDPR]  
--DECLARE
	@inTimeOption			INT				= NULL			,
	@RPTLineDESCList		NVARCHAR(MAX)	= NULL			,  
    @RPTShiftDESCList		NVARCHAR(MAX)	= NULL			,  
    @RPTCrewDESCList		NVARCHAR(MAX)	= NULL			,  
    @RPTPLStatusDESCList	NVARCHAR(MAX)	= NULL			,
	@RPTMajorGroupBy		NVARCHAR(50)	= NULL			,  
	@RPTMinorGroupBy		NVARCHAR(50)	= NULL			,   
    @RPTStartDate			NVARCHAR(25)	= NULL			,  
    @RPTEndDate				NVARCHAR(25)	= NULL			,
	@OutputType 			NVARCHAR(255)	= NULL			,
	@RPTKPISelectionList	NVARCHAR(MAX)	= '!Null'			
 
--WITH ENCRYPTION --Causes stack overflow error when enabled
AS    
--*********************************************************************************************  
-- FOR TESTING  
--*********************************************************************************************  

--SELECT       
--@inTimeOption		  = 1,
--@RPTLineDESCList	  = 'DIMR111,DIMR112,DIMR113',--'DIEU133,DIEU134,DIEU136,DIEU137,DIEU138,DIEU139,DIEU171,DIEU172,DIEU173,DIEU174,DIEU175,DIEU176,DIEU177,DIEU178,DIEU179',
----@Report_Name		  = 
--@RPTShiftDESCList	  = '',
--@RPTCrewDESCList	  = '',
--@RPTPLStatusDESCList  = '',
--@RPTMajorGroupBy	  = 'Line',
--@RPTMinorGroupBy	  = 'Crew',
--@RPTStartDate		  = '',
--@RPTEndDate			  = '',
--@OutputType 		  = '',
--@RPTKPISelectionList  = 'ACPStops,ACPStops/Day,Area4Loss%,Area4Loss_FromToClass,Availability,AverageLineSpeed,CaseCounter,CU,Down/MSU,Downtime,DowntimeScrap,DowntimeScrap%,DowntimeUnplanned,DowntimeUnplanned%,EditedStops,EditedStops%,EditedStopsReason1,EditedStopsReason1%,EditedStopsReason2,EditedStopsReason2%,EditedStopsReason3,EditedStopsReason3%,FailedSplices,FalseStarts(UT=0),FalseStarts(UT=0)%,FalseStarts(UT=T),FalseStarts(UT=T)%,GoodProduct,IdealSpeed,Line_Stops,LineStopsUnplanned,MSU,MTBF,MTBS,MTTR,MTTR_Unplanned,ProductionTime,PRusingAvailability,PRusingProductCount,R(T=0),R(T=T),RealDowntime,RealUptime,RepairTime>T,RU,RunEfficiency,RunningScrap,RunningScrap%,Scrap,Scrap%,ShowClassProduct,ShowTop5Downtimes,ShowTop5Rejects,ShowTop5Stops,STNU,Stops/Day,Stops/MSU,SU,SuccessRate,SucSplices,SucSplices,SurvivalRate,SurvivalRate%,TargetSpeed,TotalProduct,TotalSplices,Uptime'
		  

--*************************************************************************************************  
-- END  
--*************************************************************************************************  
-- SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED  
  
SET NOCOUNT ON
 
--Print convert(varchar(25), getdate(), 120) + ' Starting_Point'   
----------------------------------------------------------------------------------------------------------------------  
-- Declare variables for the stored procedure    
----------------------------------------------------------------------------------------------------------------------  
-- Report Constants :  
DECLARE  
	@ReportName					NVARCHAR(50),
	@vchTimeOption				NVARCHAR(50),

	@LineSpec					varchar(4000)	,     
	@RPTDowntimeFieldorder		varchar(500)	,     
	@RPTWasteFieldorder			varchar(500)	,    
	@RPTFilterMinutes			float			,      
	@RPTDowntimesystemUser		varchar(50)		,	     
	@RPTPadCountTag				varchar(50)		,     
	@RPTCaseCountTag			varchar(50)		,     
	@RPTRunCountTag				varchar(50)		,     
	@RPTStartupCountTag			varchar(50)		,     
	@RPTConverterSpeedTag		varchar(50)		,     
	@RPTSpecProperty			varchar(50)		,     
	@RPTDowntimeTag				varchar(50)		,     
	@RPTDowntimesurvivalRate	float			,      
	@RPTDowntimeFilterMinutes	float			,  
	@RPTIdealSpeed				VARCHAR(50)		,  
	@PlannedStopTreeName		NVARCHAR(200)  
  
	-- DEFAULT VALUES FOR PARAMETER VARIABLES   
	set @RPTDowntimesystemUser   = 'ReliabilitySystem'  
	set @RPTPadCountTag			 = 'ProductionOut'  
	set @RPTConverterSpeedTag	 = 'TargetSpeed'  
	set @RPTCaseCountTag		 = 'Cases Produced'  
	set @RPTRunCountTag			 = 'RunScrap'  
	set @RPTStartupCountTag		 = 'StartScrap'  
	set @RPTSpecProperty		 = 'RE_Product Information'  
	set @RPTDowntimeTag			 = 'DT/Uptime'  
	Set @RPTDowntimeFieldorder	 = 'Reason1~Reason2'  
	Set @RPTWasteFieldorder		 = 'Reason1~!Null'  
	Set @RPTDowntimesurvivalRate = 230  
	SET @RPTIdealSpeed			 = 'Ideal Speed'  
	SET @PlannedStopTreeName	 = 'Planned Stop'  
  
Declare  
	@StartDateTime				datetime           ,  
	@EndDateTime				datetime           ,  
	@ErrMsg						varchar(1000)      ,  
	@CompanyName				varchar(50)        ,  
	@SiteName					varchar(50)        ,  
	@CrewDESCList				varchar(4000)      ,  
	@ShiftDESCList				varchar(4000)      ,  
	@PLStatusDESCList           varchar(4000)      ,  
	@ProdCodeList				varchar(4000)      ,  
	@PLDESCList                 varchar(4000)      ,  
	@DowntimesystemUserID       int                ,  
	@PLID						int                ,  
	@EndTime					datetime           ,  
	@Pu_Id						int                ,  
	@ID							int                ,  
	@StartTime					datetime           ,  
    @ClassNum                   int                ,  
	@PadsPerStatSpecID          int                ,  
	@IdealSpeedSpecID			INT				   ,  
	@SpecPropertyID             int                ,  
	@SQLString                  nvarchar(MAX)      ,  
	@GroupValue                 varchar(50)        ,  
	@i                          int                ,  
	@j                          int                ,  
	@ColumnCount                int                ,  
	@TableName                  varchar(50)        ,  
	@ColNum                     varchar(3)         ,  
	@FIELD1                     varchar(50)        ,  
	@FIELD2                     varchar(50)        ,  
	@TEMPValue                  varchar(50)        ,  
	@FieldName                  VarChar(50)        ,  
	@SumGroupBy                 varchar(25)        ,  
	@SumLineStops               varchar(25)        ,  
    @SumLineStopsERC            varchar(25)		   ,  
	@SumACPStops                varchar(25)        ,  
	@SumDowntime                varchar(25)        ,  
    @SumDowntimeERC             varchar(25)        ,  
	@SumPlannedStops			VARCHAR(25)   ,  
	@SumUptime					varchar(25)     ,  
	@SumFalseStarts             varchar(25)     ,  
	@SumTotalSplices            varchar(25)     ,  
	@SumSUCSplices				varchar(25)     ,  
	-- JPG
--	@SumTotalPads             varchar(75)     ,  
	@SumTotalPads             FLOAT,  
	@SumUptimeGreaterT            varchar(25)      ,  
	@SumNumEdits             varchar(25)   ,  
	@SumNumEditsR1             varchar(25)   ,  
	@SumNumEditsR2             varchar(25)   ,  
	@SumNumEditsR3             varchar(25)   ,  
	@SumSurvivalRate            varchar(25)   ,  
	@SumRunningScrap            varchar(25)   ,  
	@SumDowntimeScrap            varchar(25)   ,  
	-- jpg
--	@SumGoodPads             varchar(25)   ,  
	@SumGoodPads             FLOAT,  
	@SumMSU                  varchar(25)   ,  
	@SumArea4LossPer            varchar(25)   ,  
	@SumRepairTimeT             varchar(25)   ,  
	@Avg_Linespeed_Calc            float    ,  
	@Flex1                  varchar(25)   ,  
	@Flex2                  varchar(25)   ,  
	@Flex3                  varchar(25)   ,  
	@Flex4                  varchar(25)   ,  
	@Flex5                  varchar(25)   ,  
	@Flex6                  varchar(25)   ,  
	@Flex7                  varchar(25)   ,  
	@Flex8                  varchar(25)   ,  
	@Flex9                  varchar(25)   ,  
	@Flex10                  varchar(25)   ,  
	@param                  nvarchar(100)  ,   --  for web parameters  
	@SumStops                 varchar(25)   ,  
	@SumStopsPerDay             varchar(25)   ,  
	@SumFalseStartsT            varchar(25)   ,  
	@sumACPStopsPerDay            varchar(25)   ,  
	@SumTotalScrap             varchar(25)   ,  
	@SumGoodClass1             varchar(25)   ,  
	@SumGoodClass2             varchar(25)   ,  
	@SumGoodClass3             varchar(25)   ,  
	@SumGoodClass4             varchar(25)   ,  
	@SumGoodClass5             varchar(25)   ,  
	@SumGoodClass6             varchar(25)   ,  
	@SumGoodClass7             varchar(25)   ,  
	@SumGoodClass8             varchar(25)   ,  
	@SumGoodClass9             varchar(25)   ,  
	@SumGoodClass10             varchar(25)   ,  
	@SumGoodClass11             varchar(25)   ,  
	@SumGoodClass12             varchar(25)   ,  
	@SumGoodClass13             varchar(25)   ,  
	@SumGoodClass14             varchar(25)   ,  
	@SumGoodClass15             varchar(25)   ,  
	@SumGoodClass16             varchar(25)   ,  
	@SumGoodClass17             varchar(25)   ,  
	@SumGoodClass18             varchar(25)   ,  
	@SumGoodClass19             varchar(25)   ,  
	@SumGoodClass20             varchar(25)   ,    
	@SumTotalClass1             varchar(25)   ,  
	@SumTotalClass2             varchar(25)   ,  
	@SumTotalClass3             varchar(25)   ,  
	@SumTotalClass4             varchar(25)   ,  
	@SumTotalClass5             varchar(25)   ,  
	@SumTotalClass6             varchar(25)   ,  
	@SumTotalClass7             varchar(25)   ,  
	@SumTotalClass8             varchar(25)   ,  
	@SumTotalClass9             varchar(25)   ,  
	@SumTotalClass10            varchar(25)   ,  
	@SumTotalClass11            varchar(25)   ,  
	@SumTotalClass12            varchar(25)   ,  
	@SumTotalClass13            varchar(25)   ,  
	@SumTotalClass14            varchar(25)   ,  
	@SumTotalClass15            varchar(25),  
	@SumTotalClass16            varchar(25),  
	@SumTotalClass17            varchar(25),  
	@SumTotalClass18            varchar(25),  
	@SumTotalClass19					varchar(25),  
	@SumTotalClass20					varchar(25),  
	@maxclass							int,  
	@minclass							int,  
	@Scheduled_Time						Float,  
	@TotalScheduled_Time				Float,
	@CalendarTime						FLOAT,
	@STNU								FLOAT,  
	@TotalSTNU							FLOAT,  
	@SumTargetSpeed						FLOAT,  
	@SumIdealSpeed						FLOAT,  
	@SumTotalCases						varchar(25),  
	@Local_PG_strRptDPRColumnVisibility	nvarchar (4000),  
	@Local_PG_StrCategoriesToExclude	nvarchar (1000),  
	--@RPTMajorGroupBy					varchar(50),  
	--@RPTMinorGroupBy					varchar(50),  
	@GroupMajorFieldName				varchar(50),  
	@GroupMinorFieldName				varchar(50),  
	@LocalRPTLanguage					int,  
	@Owner								varchar(50),  
	@r									int ,  
    @RPT_ShowClassProduct				varchar(10),  
    @RPT_ShowTop5Rejects				varchar(10),  
    @RPT_ShowSplices					varchar(10),  
    @RPT_ShowSucSplices					varchar(10),  
    @RPT_SurvivalRate					varchar(10),  
    @RPT_SurvivalRatePer				varchar(10),  
    @RPT_CaseCountClass					varchar(10),  
    @Rpt_ShowTop5Downtimes				varchar(10),  
    @Rpt_ShowTop5Stops					varchar(10),  
	@ClassNo							int,  
	@Prod_Id							nvarchar(20),  
	@Value								float  ,
	@intTimeOption     					INT,
	@intRptShiftLength 					INT,
	@dtmRptShiftStart					NVARCHAR(25)


          
----------------------------------------------------------------------------  
-- Prompts For output ON report.  Used in Language trans  
----------------------------------------------------------------------------  
  
Declare  
  
 @lblPlant    varchar(50),  
 @lblStartDate   varchar(50),  
 @lblShift    varchar(50),  
 @lblProductCode   varchar(50),  
 @lblLine    varchar(50),  
 @lblEndDate    varchar(50),  
 @lblCrew    varchar(50),  
 @lblLineStatus   varchar(50),  
 @lblTop5Downtime  varchar(50),  
 @lblTop5DTColmn1  varchar(50),  
 @lblTop5DTColmn2  varchar(50),  
 @lblTop5Stops   varchar(50),  
 @lblTop5Rejects   varchar(50),  
 @lblTop5RJColmn1  varchar(50),  
 @lblTop5RJColmn2  varchar(50),  
 @lblVarDESC    varchar(50),   
 @lblTotal    varchar(50),  
 @lblAll     varchar(50),  
 @lblSecurity   varchar(1000),  
 @lblStops    varchar(50),  
 @lblEvents    varchar(50),  
 @lblDTLevel1   varchar(50),  
 @lblDTLevel2   varchar(50),  
 @lblRJLevel1   varchar(50),  
 @lblRJLevel2   varchar(50),  
 @lblTotalProduct  varchar(50),  
 @lblProductionStatus    varchar(50),  
 @lblDowntime            varchar(50),  
 @lblPads                varchar(50)  
        --  
  
 Set @lblPlant     = 'Plant'  
 Set @lblStartDate   = 'Start Date'  
 Set @lblShift     = 'Shift'  
 Set @lblProductCode   = 'Product Code'  
 Set @lblLine     = 'Line'  
 Set @lblEndDate    = 'End Date'  
 Set @lblCrew     = 'Team'  
 Set @lblProductionStatus  = 'Production Status'  
 Set @lblTop5Downtime   = 'Top 5 Downtime'  
 Set @lblTop5Stops    = 'Top 5 Stops'  
 Set @lblTop5Rejects   = 'Top 5 Rejects'  
 Set @lblAll     = 'All'  
 Set @lblSecurity    = 'For P&G internal use Only'  
 Set @lblStops    = 'Stops'  
 Set @lblEvents    = 'Events'  
 Set @lblDTLevel1   = 'Feature'  
 Set @lblDTLevel2   = 'Component'  
 Set @lblRJLevel1   = 'AutoCause'  
 Set @lblRJLevel2   = ''   
    Set @lblDowntime            = 'Downtime'  
    Set @lblPads                = 'Pads'  
          
    
Declare   
  
 @Operator as nvarchar(5),  
 @ClassList as nvarchar(200),  
 @Variable as nvarchar(100),  
    @Prec as int  
  
--  
--Print convert(varchar(25), getdate(), 120) + ' Create Temp Tables'   
----------------------------------------------------------------------------------------------------------------------  
-- CREATE TEMPORARY TABLES :   
----------------------------------------------------------------------------------------------------------------------  
     
IF OBJECT_ID('tempdb.dbo.#PLIDList', 'U') IS NOT NULL  DROP TABLE #PLIDList
Create Table #PLIDList  
( RCDID     int,  
 PLID     int,  
 PLDESC     varchar(50),  
 ConvUnit    int,  
 SpliceUnit    int,  
 Packerunit    int,  
 QualityUnit   int,  
 ScheduleUnit   int,  
 ProductUnit   int,  
 ProcUnit    int,  
 PartPadCountVarID  int,  
 CompPadCountVarID  int,  
 PartCaseCountVarID  int,  
 CompCaseCountVarID  int,  
 PartRunCountVarID  int,  
 CompRunCountVarID  int,  
 PartStartUPCountVarID  int,  
 CompStartUPCountVarID  int,  
 CompSpeedTargetVarID  int,  
 PartSpeedTargetVarID  int,  
 REDowntimeVarID   int,  
 Class    int,  
 CaseCountVarID   varchar(25),  
 Flex1    varchar(25),  
 Flex2    varchar(25),  
 Flex3    varchar(25),  
 Flex4    varchar(25),  
 Flex5    varchar(25),  
 Flex6    varchar(25),  
 Flex7    varchar(25),  
 Flex8    varchar(25),  
 Flex9    varchar(25),  
 Flex10    varchar(25),  
 UseCaseCount   int  
)     
IF OBJECT_ID('tempdb.dbo.#ShiftDESCList', 'U') IS NOT NULL  DROP TABLE #ShiftDESCList
Create Table #ShiftDESCList  
( RCDID     int,  
 ShiftDESC    varchar(50))  
    
IF OBJECT_ID('tempdb.dbo.#CrewDESCList', 'U') IS NOT NULL  DROP TABLE #CrewDESCList 
Create Table #CrewDESCList  
(	RCDID		int,  
	CrewDESC    varchar(50))  
     
IF OBJECT_ID('tempdb.dbo.#PLStatusDESCList', 'U') IS NOT NULL  DROP TABLE #PLStatusDESCList
Create Table #PLStatusDESCList  
( RCDID     int,  
 PLStatusDESC    varchar(50))  
     
IF OBJECT_ID('tempdb.dbo.#Splices', 'U') IS NOT NULL  DROP TABLE #Splices
Create Table #Splices   
(  spl_id    int primary key identity,  
  Nrecords   int,  
      SpliceStatus   float,  
      Product    varchar(50),  
        Product_Size        varchar(100),  
      Crew    varchar(25),  
      Shift    varchar(25),  
      LineStatus   varchar(50),  
      PLID    int,  
      pu_id    int,   
  class    int,  
      InRun    int,  
  ProdDay    nvarchar(12),  
  Location   varchar(50),)  
  
   
IF OBJECT_ID('tempdb.dbo.#Rejects', 'U') IS NOT NULL  DROP TABLE #Rejects  
Create Table #Rejects   
(  nrecords   bigint,  
      PadCount   float,  
        Reason1       varchar(100),  
      Reason2    varchar(100),  
      Product    varchar(50),  
        Product_Size        varchar(100),  
      Crew    varchar(25),  
      Shift    varchar(25),  
      LineStatus   varchar(50),  
      PLID    int,  
      pu_id    int,  
        Location   varchar(50),  
  Schedule_Unit  int)  
  
     
IF OBJECT_ID('tempdb.dbo.#Summary', 'U') IS NOT NULL  DROP TABLE #Summary
Create Table #Summary  
( Sortorder   int,  
 Label    varchar(60),  
 null01    varchar(60),  
 null02    varchar(25),  
 GroupField   varchar(25),  
 Value1    nvarchar(35),  
 Value2    nvarchar(35),  
 Value3    nvarchar(35),  
 Value4    nvarchar(35),  
 Value5    nvarchar(35),  
 Value6    nvarchar(35),  
 Value7    nvarchar(35),  
 Value8    nvarchar(35),  
 Value9    nvarchar(35),  
 Value10    nvarchar(35),  
 Value11    nvarchar(35),  
 Value12    nvarchar(35),  

 Value13    nvarchar(35),  
 Value14    nvarchar(35),  
 Value15    nvarchar(35),  
 Value16    nvarchar(35),  
 Value17    nvarchar(35),  
 Value18    nvarchar(35),  
 Value19    nvarchar(35),  
 Value20    nvarchar(35),  
 Value21    nvarchar(35),  
 Value22    nvarchar(35),  
 Value23    nvarchar(35),  
 Value24    nvarchar(35),  
 Value25    nvarchar(35),  
 Value26    nvarchar(35),  
 Value27    nvarchar(35),  
 Value28    nvarchar(35),  
 Value29    nvarchar(35),  
 Value30    nvarchar(35),  
 Value31    nvarchar(35),  
 Value32    nvarchar(35),  
 Value33    nvarchar(35),  
 Value34    nvarchar(35),  
 Value35    nvarchar(35),  
 Value36    nvarchar(35),  
 Value37    nvarchar(35),  
 Value38    nvarchar(35),  
 Value39    nvarchar(35),  
 Value40    nvarchar(35),  
 Value41    nvarchar(35),  
 Value42    nvarchar(35),  
 Value43    nvarchar(35),  
 Value44    nvarchar(35),  
 Value45    nvarchar(35),  
 Value46    nvarchar(35),  
 Value47    nvarchar(35),  
 Value48    nvarchar(35),  
 Value49    nvarchar(35),  
 Value50    nvarchar(35),  
 Value51    nvarchar(35),  
 Value52    nvarchar(35),  
 Value53    nvarchar(35),   
 Value54    nvarchar(35),  
 Value55    nvarchar(35),  
 Value56    nvarchar(35),  
 Value57    nvarchar(35),  
 Value58    nvarchar(35),  
 Value59    nvarchar(35),  
 Value60    nvarchar(35),  
 Value61    nvarchar(35),  
 Value62    nvarchar(35),  
 Value63    nvarchar(35),  
 Value64    nvarchar(35),  
 Value65    nvarchar(35),  
 Value66    nvarchar(35),  
 Value67    nvarchar(35),  
 Value68    nvarchar(35),  
 Value69    nvarchar(35),  
 Value70    nvarchar(35),  
 Value71    nvarchar(35),  
 Value72    nvarchar(35),  
 Value73    nvarchar(35),  
 Value74    nvarchar(35),  
 Value75    nvarchar(35),  
 Value76    nvarchar(35),  
 Value77    nvarchar(35),  
 Value78    nvarchar(35),  
 Value79    nvarchar(35),  
 Value80    nvarchar(35),  
 Value81    nvarchar(35),  
 Value82    nvarchar(35),  
 Value83    nvarchar(35),  
 Value84    nvarchar(35),  
 Value85    nvarchar(35),  
 Value86    nvarchar(35),  
 Value87    nvarchar(35),  
 Value88    nvarchar(35),  
 Value89    nvarchar(35),  
 Value90    nvarchar(35),  
 Value91    nvarchar(35),  
 Value92    nvarchar(35),  
 Value93    nvarchar(35),  
 Value94    nvarchar(35),  
 Value95    nvarchar(35),  
 Value96    nvarchar(35),  
 Value97    nvarchar(35),  
 Value98    nvarchar(35),  
 Value99    nvarchar(35),  
 Value100   nvarchar(35),  
 AGGREGATE   nvarchar(35),  
 EmptyCol   nvarchar(35),  
 ProdDay    nvarchar(12)  
)  
    
IF OBJECT_ID('tempdb.dbo.#Top5Downtime', 'U') IS NOT NULL  DROP TABLE #Top5Downtime 
Create Table #Top5Downtime  
( Sortorder   int IDENTITY,  
 DESC01    varchar(150),  
 DESC02    varchar(150),  
 Stops    varchar(25),  
 GroupField   varchar(25),  
 Value1    nvarchar(35),  
 Value2    nvarchar(35),  
 Value3    nvarchar(35),  
 Value4    nvarchar(35),  
 Value5    nvarchar(35),  
 Value6    nvarchar(35),  
 Value7    nvarchar(35),  
 Value8    nvarchar(35),  
 Value9    nvarchar(35),  
 Value10    nvarchar(35),  
 Value11    nvarchar(35),  
 Value12    nvarchar(35),  
 Value13    nvarchar(35),  
 Value14    nvarchar(35),  
 Value15    nvarchar(35),  
 Value16    nvarchar(35),  
 Value17    nvarchar(35),  
 Value18    nvarchar(35),  
 Value19    nvarchar(35),  
 Value20    nvarchar(35),  
 Value21    nvarchar(35),  
 Value22    nvarchar(35),  
 Value23    nvarchar(35),  
 Value24    nvarchar(35),  
 Value25    nvarchar(35),  
 Value26    nvarchar(35),  
 Value27    nvarchar(35),  
 Value28    nvarchar(35),  
 Value29    nvarchar(35),  
 Value30    nvarchar(35),  
 Value31    nvarchar(35),  
 Value32    nvarchar(35),  
 Value33    nvarchar(35),  
 Value34    nvarchar(35),  
 Value35    nvarchar(35),  
 Value36    nvarchar(35),  
 Value37    nvarchar(35),  
 Value38    nvarchar(35),  
 Value39    nvarchar(35),  
 Value40    nvarchar(35),  
 Value41    nvarchar(35),  
 Value42    nvarchar(35),  
 Value43    nvarchar(35),  
 Value44    nvarchar(35),  
 Value45    nvarchar(35),  
 Value46    nvarchar(35),  
 Value47    nvarchar(35),  
 Value48    nvarchar(35),  
 Value49    nvarchar(35),  
 Value50    nvarchar(35),  
    Value51    nvarchar(35),  
 Value52    nvarchar(35),  
 Value53    nvarchar(35),  
 Value54    nvarchar(35),  
 Value55    nvarchar(35),  
 Value56    nvarchar(35),  
 Value57    nvarchar(35),  
 Value58    nvarchar(35),  
 Value59    nvarchar(35),  
 Value60    nvarchar(35),  
 Value61    nvarchar(35),  
 Value62    nvarchar(35),  
 Value63    nvarchar(35),  
 Value64    nvarchar(35),  
 Value65    nvarchar(35),  
 Value66    nvarchar(35),  
 Value67    nvarchar(35),  
 Value68    nvarchar(35),  
 Value69    nvarchar(35),  
 Value70    nvarchar(35),  
 Value71    nvarchar(35),  
 Value72    nvarchar(35),  
 Value73    nvarchar(35),  
 Value74    nvarchar(35),  
 Value75    nvarchar(35),  
 Value76    nvarchar(35),  
 Value77    nvarchar(35),  
 Value78    nvarchar(35),  
 Value79    nvarchar(35),  
 Value80    nvarchar(35),  
 Value81    nvarchar(35),  
 Value82    nvarchar(35),  
 Value83    nvarchar(35),  
 Value84    nvarchar(35),  
 Value85    nvarchar(35),  
 Value86    nvarchar(35),  
 Value87    nvarchar(35),  
 Value88    nvarchar(35),  
 Value89    nvarchar(35),  
 Value90    nvarchar(35),  
 Value91    nvarchar(35),  
 Value92    nvarchar(35),  
 Value93    nvarchar(35),  
 Value94    nvarchar(35),  
 Value95    nvarchar(35),  
 Value96    nvarchar(35),  
 Value97    nvarchar(35),  
 Value98    nvarchar(35),  
 Value99    nvarchar(35),  
 Value100   nvarchar(35),  
 Aggregate   nvarchar(35),  
 EmptyCol   varchar(35))  
  
     
IF OBJECT_ID('tempdb.dbo.#Top5Stops', 'U') IS NOT NULL  DROP TABLE #Top5Stops
Create Table #Top5Stops  
( Sortorder   int Identity,  
 DESC01    varchar(150),  
 DESC02    varchar(150),  
 Downtime   varchar(25),  
 GroupField   varchar(25),  
 Value1    nvarchar(35),  
 Value2    nvarchar(35),  
 Value3    nvarchar(35),  
 Value4    nvarchar(35),  
 Value5    nvarchar(35),  
 Value6    nvarchar(35),  
 Value7    nvarchar(35),  
 Value8    nvarchar(35),  
 Value9    nvarchar(35),  
 Value10    nvarchar(35),  
 Value11    nvarchar(35),  
 Value12    nvarchar(35),  
 Value13    nvarchar(35),  
 Value14    nvarchar(35),  
 Value15    nvarchar(35),  
 Value16    nvarchar(35),  
 Value17    nvarchar(35),  
 Value18    nvarchar(35),  
 Value19    nvarchar(35),  
 Value20    nvarchar(35),  
 Value21    nvarchar(35),  
 Value22    nvarchar(35),  
 Value23    nvarchar(35),  
 Value24    nvarchar(35),  
 Value25    nvarchar(35),  
 Value26    nvarchar(35),  
 Value27    nvarchar(35),  
 Value28    nvarchar(35),  
 Value29    nvarchar(35),  
 Value30    nvarchar(35),  
 Value31    nvarchar(35),  
 Value32    nvarchar(35),  
 Value33    nvarchar(35),  
 Value34    nvarchar(35),  
 Value35    nvarchar(35),  
 Value36    nvarchar(35),  
 Value37    nvarchar(35),  
 Value38    nvarchar(35),  
 Value39    nvarchar(35),  
 Value40    nvarchar(35),  
 Value41    nvarchar(35),  
 Value42    nvarchar(35),  
 Value43    nvarchar(35),  
 Value44    nvarchar(35),  
 Value45    nvarchar(35),  
 Value46    nvarchar(35),  
 Value47    nvarchar(35),  
 Value48    nvarchar(35),  
 Value49    nvarchar(35),  
 Value50    nvarchar(35),  
 Value51    nvarchar(35),  
 Value52    nvarchar(35),  
 Value53    nvarchar(35),  
 Value54    nvarchar(35),  
 Value55    nvarchar(35),  
 Value56    nvarchar(35),  
 Value57    nvarchar(35),  
 Value58    nvarchar(35),  
 Value59    nvarchar(35),  
 Value60    nvarchar(35),  
 Value61    nvarchar(35),  
 Value62    nvarchar(35),  
 Value63    nvarchar(35),  
 Value64    nvarchar(35),  
 Value65    nvarchar(35),  
 Value66    nvarchar(35),  
 Value67    nvarchar(35),  
 Value68    nvarchar(35),  
 Value69    nvarchar(35),  
 Value70    nvarchar(35),  
 Value71    nvarchar(35),  
 Value72    nvarchar(35),  
 Value73    nvarchar(35),  
 Value74    nvarchar(35),  
 Value75    nvarchar(35),  
 Value76    nvarchar(35),  
 Value77    nvarchar(35),  
 Value78    nvarchar(35),  
 Value79    nvarchar(35),  
 Value80    nvarchar(35),  
 Value81    nvarchar(35),  
 Value82    nvarchar(35),  
 Value83    nvarchar(35),  
 Value84    nvarchar(35),  
 Value85    nvarchar(35),  
 Value86    nvarchar(35),  
 Value87    nvarchar(35),  
 Value88    nvarchar(35),  
 Value89    nvarchar(35),  
 Value90    nvarchar(35),  
 Value91    nvarchar(35),  
 Value92    nvarchar(35),  
 Value93    nvarchar(35),  
 Value94    nvarchar(35),  
 Value95    nvarchar(35),  
 Value96    nvarchar(35),  
 Value97    nvarchar(35),  
 Value98    nvarchar(35),  
 Value99    nvarchar(35),  
 Value100   nvarchar(35),  
 Aggregate   varchar(75),  
 EmptyCol   varchar(75))  
   
IF OBJECT_ID('tempdb.dbo.#Top5Rejects', 'U') IS NOT NULL  DROP TABLE #Top5Rejects  
Create Table #Top5Rejects  
( Sortorder   int IDENTITY,  
 DESC01    varchar(150),  
 DESC02    varchar(150),  
 Events    varchar(25),  
 GroupField   varchar(25),  
 Value1    nvarchar(35),  
 Value2    nvarchar(35),  
 Value3    nvarchar(35),  
 Value4    nvarchar(35),  
 Value5    nvarchar(35),  
 Value6    nvarchar(35),  
 Value7    nvarchar(35),  
 Value8    nvarchar(35),  
 Value9    nvarchar(35),  
 Value10    nvarchar(35),  
 Value11    nvarchar(35),  
 Value12    nvarchar(35),  
 Value13    nvarchar(35),  
 Value14    nvarchar(35),  
 Value15    nvarchar(35),  
 Value16    nvarchar(35),  
 Value17    nvarchar(35),  
 Value18    nvarchar(35),  
 Value19    nvarchar(35),  
 Value20    nvarchar(35),  
 Value21    nvarchar(35),  
 Value22    nvarchar(35),  
 Value23    nvarchar(35),  
 Value24    nvarchar(35),  
 Value25    nvarchar(35),  
 Value26    nvarchar(35),  
 Value27    nvarchar(35),  
 Value28    nvarchar(35),  
 Value29    nvarchar(35),  
 Value30    nvarchar(35),  
 Value31    nvarchar(35),  
 Value32    nvarchar(35),  
 Value33    nvarchar(35),  
 Value34    nvarchar(35),  
 Value35    nvarchar(35),  
 Value36    nvarchar(35),  
 Value37    nvarchar(35),  
 Value38    nvarchar(35),  
 Value39    nvarchar(35),  
 Value40    nvarchar(35),  
 Value41    nvarchar(35),  
 Value42    nvarchar(35),  
 Value43    nvarchar(35),  
 Value44    nvarchar(35),  
 Value45    nvarchar(35),  
 Value46    nvarchar(35),  
 Value47    nvarchar(35),  
 Value48    nvarchar(35),  
 Value49    nvarchar(35),  
 Value50    nvarchar(35),  
 Value51    nvarchar(35),  
 Value52    nvarchar(35),  
 Value53    nvarchar(35),  
 Value54    nvarchar(35),  
 Value55    nvarchar(35),  
 Value56    nvarchar(35),  
 Value57    nvarchar(35),  
 Value58    nvarchar(35),  
 Value59    nvarchar(35),  
 Value60    nvarchar(35),  
 Value61    nvarchar(35),  
 Value62    nvarchar(35),  
 Value63    nvarchar(35),  
 Value64    nvarchar(35),  
 Value65    nvarchar(35),  
 Value66    nvarchar(35),  
 Value67    nvarchar(35),  
 Value68    nvarchar(35),  
 Value69    nvarchar(35),  
 Value70    nvarchar(35),  
 Value71    nvarchar(35),  
 Value72    nvarchar(35),  
 Value73    nvarchar(35),  
 Value74    nvarchar(35),  
 Value75    nvarchar(35),  
 Value76    nvarchar(35),  
 Value77    nvarchar(35),  
 Value78    nvarchar(35),  
 Value79    nvarchar(35),  
 Value80    nvarchar(35),  
 Value81    nvarchar(35),  
 Value82    nvarchar(35),  
 Value83    nvarchar(35),  
 Value84    nvarchar(35),  
 Value85    nvarchar(35),  
 Value86    nvarchar(35),  
 Value87    nvarchar(35),  
 Value88    nvarchar(35),  
 Value89    nvarchar(35),  
 Value90    nvarchar(35),  
 Value91    nvarchar(35),  
 Value92    nvarchar(35),  
 Value93    nvarchar(35),  
 Value94    nvarchar(35),  
 Value95    nvarchar(35),  
 Value96    nvarchar(35),  
 Value97    nvarchar(35),  
 Value98    nvarchar(35),  
 Value99    nvarchar(35),  
 Value100   nvarchar(35),  
 AGGREGATE   varchar(75),  
 EmptyCol   varchar(75))  
     
IF OBJECT_ID('tempdb.dbo.#Downtimes', 'U') IS NOT NULL  DROP TABLE #Downtimes
Create Table #Downtimes  
( TedID     int,  
 PU_ID     int,  
 PLID     int,  
 Start_Time    datetime,  
 End_Time    datetime,  
 Fault     varchar(100),  
 Location_id    int,  
 Location    varchar(50),  
 Tree_Name    NVARCHAR(200),
 Tree_Name_Id	int,     
 Reason1     varchar(100),  
 Reason1_Code   int,  
 Reason2     varchar(100),  
 Reason2_Code   int,  
 Reason3     varchar(100),  
 Reason3_Code   int,  
 Reason4     varchar(100),  
 Reason4_Code   int,  
 Duration    float,  
 Uptime     float,  
 IsStops     int,  
 Product     varchar(50),  
    Product_Size         varchar(100),  
 Crew     varchar(10),  
 Shift     varchar(10),  
 LineStatus    varchar(25),  
 Uptime_LineStatus  varchar(25),  
 Uptime_Product   varchar(25),  
 SurvEnd_Time   datetime,  
 SurvRateUptime   float,  
 ID      int primary key Identity,  
 Dev_Comment    varchar (50),  
 UserID     int,  
 class      int,  
 Action_Level1   int,  
 ProdDay     nvarchar(12),  
 DowntimeTreeId   Int,  
 DowntimeNodeTreeId  Int,  
 ERC_Id       int,  
 ERC_Desc     nvarchar(50))  
  
CREATE NONCLUSTERED INDEX IDX_Downtimes  
ON #Downtimes(TedId) ON [PRIMARY]  
  
     
IF OBJECT_ID('tempdb.dbo.#Production', 'U') IS NOT NULL  DROP TABLE #Production
Create Table #Production  (	 
			 ID			 int primary key identity,
			 ParentIdCrew	int,  
			 ParentIdLs		int,  
			 SplitCrew	 INT DEFAULT 0,
			 SplitLS	 INT DEFAULT 0,
			 StartTIME   DATETIME,  
			 EndTIME     DATETIME,  
			 PLID		 INT,  
			 pu_id       INT,  
			 Product     VARCHAR(50),  
		     Product_Size       VARCHAR(100),  
			 Crew				VARCHAR(25),  
			 Shift				VARCHAR(25),  
			 LineStatus   varchar(25),  
			 EventId	 INT	 ,
			 TotalPad   float,  
			 RunningScrap  float,  
			 Stopscrap   float,  
			 IdealSpeed   FLOAT,  
			 TargetSpeed   FLOAT,  
			 LineSpeedTAR  float,  
			 TotalCaseS   float,   
			 ProdPerStat   float,  
			 ConvFactor   float,  
			 TypeOfEvent   varchar(50),
			 -- Hybrid Configurations
			 HybridConf		varchar(5),  
			 casecount   varchar(25),  
			 flex1    varchar(25),  
			 flex2    varchar(25),  
			 flex3    varchar(25),  
			 flex4    varchar(25),  
			 flex5    varchar(25),  
			 flex6    varchar(25),  
			 flex7    varchar(25),  
			 flex8    varchar(25),  
			 flex9    varchar(25),  
			 flex10    varchar(25),  
			 class    int,  
			 ProdDay    nvarchar(12),  
			 Location   varchar(50),  
			 SchedTime   int)  -- in seconds  
    
IF OBJECT_ID('tempdb.dbo.#TEMPORARY', 'U') IS NOT NULL  DROP TABLE #TEMPORARY 
Create Table #TEMPORARY  
( TEMPValue1   varchar(100),  
 TEMPValue2   varchar(100),  
 TEMPValue3   varchar(100),  
 TEMPValue4   varchar(100),  
 TEMPValue5   varchar(100),  
 TEMPValue6   varchar(100),  
 TEMPValue7   varchar(100),  
 TEMPValue8   varchar(100),  
 TEMPValue9   varchar(100),  
 TEMPValue10   varchar(100),  
 TEMPValue11   varchar(100))  
  
-- jpg: Create and used to don't loss precision in Float and Integer values    
IF OBJECT_ID('tempdb.dbo.#TemporaryFloat', 'U') IS NOT NULL  DROP TABLE #TemporaryFloat
Create Table #TemporaryFloat  
( TEMPValue1   float,  
 TEMPValue2   float,  
 TEMPValue3   float,  
 TEMPValue4   float,  
 TEMPValue5   float,  
 TEMPValue6   float,  
 TEMPValue7   float,  
 TEMPValue8   float,  
 TEMPValue9   float,  
 TEMPValue10   float,  
 TEMPValue11   float)  
    
IF OBJECT_ID('tempdb.dbo.#InvertedSummary', 'U') IS NOT NULL  DROP TABLE #InvertedSummary
Create Table #InvertedSummary ( 
	ID      int primary key identity,  
	GroupBy					Varchar(25),  
	ColType					varchar(25),  
	Availability			varchar(25),  
	PRAvail					varchar(25),  
	PR						varchar(25),  
	SU						varchar(25),  
	RU						varchar(25),  
	CU						varchar(25),  
	RunEff					varchar(25),  
	LineStops				varchar(25),  
	LineStopsERC			varchar(25),  
	RepairTimeT				varchar(25),  
	ACPStops				varchar(25),  
	Downtime				varchar(25),  
	DowntimeERC				varchar(25),  
	DowntimePlannedStops	VARCHAR(25),  
	-- % Unplanned Downtime 
	DowntimeUnplannedPerc	varchar(25), 
	MTBF					varchar(25),  
	MTBF_ERC				varchar(25),  
	MTTR					varchar(25),  
	MTTR_ERC				Varchar(25),  
	MSU						varchar(25),  
	StopsPerMSU				varchar(25),  
	DownPerMSU				varchar(25),  
	TotalScrap				varchar(25),  
	TotalScrapPer			varchar(25),  
	RunningScrap			varchar(25),  
	RunningScrapPer			varchar(25),  
	DowntimeScrap			varchar(25),  
	DowntimescrapPer		varchar(25),  
	Area4LossPer			varchar(25),  
	Uptime					varchar(25),  
	IdealSpeed				varchar(25),  
	TargetSpeed				varchar(25),  
	LineSpeed				varchar(25),  
	RofT					varchar(25),  
	RofZero					varchar(25),  
	TotalSplices			varchar(25),  
	SucSplices				varchar(25),  
	FailedSplices			varchar(25),  
	SuccessRate				varchar(25),  
	ProdTime				varchar(25),  
	CalendarTime			varchar(25),  
	TotalProdTime			varchar(25),  
	TotalUptime				varchar(25),  
	TotalDowntime			varchar(25),  
	SurvivalRate			varchar(25),  
	SurvivalRatePer			varchar(25),  
	--  
	FalseStarts       varchar(25),   
	FalseStarts0Per   varchar(25),  
	FalseStartsT   varchar(25),  
	FalseStartsTper   varchar(25),  
	STNU     VARCHAR(25),  
	--   
	NumEdits       varchar(25),  
	EditedStopsPer   varchar(25),  
	NumEditsR1              varchar(25),  
	EditedStopsR1Per        varchar(25),  
	NumEditsR2              varchar(25),  
	EditedStopsR2Per        varchar(25),  
	NumEditsR3              varchar(25),  
	EditedStopsR3Per        varchar(25),  
	--  
	CaseCount    varchar(25),  
	StopsPerDay    varchar(25),  
	UptimeGreaterT   varchar(25),  
	ACPStopsPerDay    varchar(25),  
	ConverterStopsPerDay  varchar(25),  
	Class     varchar(25),  
	TotalPads    varchar(75),  
	TotalClass1    varchar(75),     
	TotalClass2    varchar(75),     
	TotalClass3    varchar(75),   
	TotalClass4    varchar(75),     
	TotalClass5    varchar(75),     
	TotalClass6    varchar(75),     
	TotalClass7    varchar(75),     
	TotalClass8    varchar(75),     
	TotalClass9    varchar(75),  
	TotalClass10   varchar(75),     
	TotalClass11   varchar(75),     
	TotalClass12   varchar(75),     
	TotalClass13   varchar(75),     
	TotalClass14   varchar(75),     
	TotalClass15   varchar(75),   
	TotalClass16   varchar(75),     
	TotalClass17   varchar(75),     
	TotalClass18   varchar(75),     
	TotalClass19   varchar(75),     
	TotalClass20   varchar(75),            
	GoodPads    varchar(75),  
	GoodClass1    varchar(75),     
	GoodClass2    varchar(75),     
	GoodClass3    varchar(75),     
	GoodClass4    varchar(75),     
	GoodClass5    varchar(75),     
	GoodClass6    varchar(75),     
	GoodClass7    varchar(75),     
	GoodClass8    varchar(75),  
	GoodClass9    varchar(75),     
	GoodClass10    varchar(75),     
	GoodClass11    varchar(75),     
	GoodClass12    varchar(75),     
	GoodClass13    varchar(75),     
	GoodClass14    varchar(75),     
	GoodClass15    varchar(75),   
	GoodClass16    varchar(75),     
	GoodClass17    varchar(75),     
	GoodClass18    varchar(75),     
	GoodClass19    varchar(75),     
	GoodClass20    varchar(75),       
	Flex1     varchar(25),  
	Flex2    varchar(25),  
	Flex3    varchar(25),  
	Flex4    varchar(25),  
	Flex5    varchar(25),  
	Flex6    varchar(25),  
	Flex7    varchar(25),  
	Flex8    varchar(25),  
	Flex9    varchar(25),  
	Flex10    varchar(25))  
  
     
IF OBJECT_ID('tempdb.dbo.#Temp_LinesParam', 'U') IS NOT NULL  DROP TABLE #Temp_LinesParam
Create Table #Temp_LinesParam(  
        RecId int,  
        PlDesc nvarchar(200))  
     
IF OBJECT_ID('tempdb.dbo.#FlexParam', 'U') IS NOT NULL  DROP TABLE #FlexParam
Create Table #FlexParam(  
        Temp1 int,  
        Temp2 varchar(100))  
     
IF OBJECT_ID('tempdb.dbo.#ReasonsToExclude', 'U') IS NOT NULL  DROP TABLE #ReasonsToExclude
Create table #ReasonsToExclude(  
        ERC_id int,  
        ERC_Desc nvarchar(100))  
     
IF OBJECT_ID('tempdb.dbo.#Equations', 'U') IS NOT NULL  DROP TABLE #Equations
Create Table #Equations(  
        eq_id int primary key identity,  
        Param nvarchar(100),  
        Label nvarchar(350),  
        Variable nvarchar(100),  
        Operator nvarchar(10),  
        Class nvarchar(1000),  
        Prec int)  
     
IF OBJECT_ID('tempdb.dbo.#ac_Top5Downtimes', 'U') IS NOT NULL  DROP TABLE #ac_Top5Downtimes
Create table #ac_Top5Downtimes  
(    SortOrder int,   
    DESC01 nvarchar(200),   
    DESC02 nvarchar(200),  
    WHEREString1 nvarchar(500),  
    WHEREString2 nvarchar(500))  
     
IF OBJECT_ID('tempdb.dbo.#ac_Top5Stops', 'U') IS NOT NULL  DROP TABLE #ac_Top5Stops
Create table #ac_Top5Stops  
(    SortOrder int,   
    DESC01 nvarchar(200),   
    DESC02 nvarchar(200),  
    WHEREString1 nvarchar(500),  
    WHEREString2 nvarchar(500))  
     
IF OBJECT_ID('tempdb.dbo.#ac_Top5Rejects', 'U') IS NOT NULL  DROP TABLE #ac_Top5Rejects
Create table #ac_Top5Rejects  
(    SortOrder int,   
    DESC01 nvarchar(200),   
    DESC02 nvarchar(200),  
    WHEREString1 nvarchar(500),  
    WHEREString2 nvarchar(500))  
     
IF OBJECT_ID('tempdb.dbo.#Temp_ColumnVisibility', 'U') IS NOT NULL  DROP TABLE #Temp_ColumnVisibility
Create Table #Temp_ColumnVisibility   
(      ColId int,  
    VariableName   varchar(100))  
  
     
IF OBJECT_ID('tempdb.dbo.#Params', 'U') IS NOT NULL  DROP TABLE #Params
Create Table  #Params   
      ( Param varchar(255),  
       Value varchar(2000))  
   
IF OBJECT_ID('tempdb.dbo.#Local_PG_StartEndTime', 'U') IS NOT NULL  DROP TABLE #Local_PG_StartEndTime
CREATE TABLE #Local_PG_StartEndTime (
						rptStartTime			DATETIME,
						rptEndTime				DATETIME)
						
--Added below table for FO-02558   
IF OBJECT_ID('tempdb.dbo.#Event_Detail_History', 'U') IS NOT NULL  DROP TABLE #Event_Detail_History
CREATE TABLE #Event_Detail_History
(	EDH_ID int IDENTITY,
	eventID int,
	ID Int,
	enteredON_Start Datetime,
	enteredOn_End Datetime,
	FinalCount int,
	InitialCount int,
	FinalCases as (FinalCount-InitialCount) 
)						
----------------------------------------------------------------------------------------------------------------------  
--    TABLE VARIABLES  
----------------------------------------------------------------------------------------------------------------------  
  
Declare @Temp_language_data Table  
     ( Prompt_Number varchar(20),   
      Prompt_String varchar(200),  
      language_id int)  
  
Declare @ColumnVisibility Table  
     (   ColId int primary key identity,  
      VariableName   varchar(100),  
         LabelName               varchar(100),  
         TranslatedName          varchar(100),  
         FieldName               varchar(100))  
  
Declare @Class Table  
     ( Line_Desc varchar(255),   
      PLID int,   
      Class_Code varchar(33),   
      Class int,   
      PU_ID int,   
      PuDesc varchar(255))  
  
Declare @Cursor Table  
     (   Cur_Id int primary key identity,  
            Major_id nvarchar(200),  
            Major_desc nvarchar(200),  
            Minor_id nvarchar(200),  
            Minor_desc nvarchar(200),  
            Major_Order_by int,  
            Minor_Order_by int,
			EffectiveDate	datetime)  
  
Declare @Temp_Uptime Table (  
         id  int,  
         pu_id  int,  
         Start_Time datetime,  
         End_Time  datetime,  
         Uptime  float,  
         LineStatus nvarchar(100),  
         Product  nvarchar(25))  
  
Declare @Make_Complete Table  
   (    pu_id int,  
       start_time datetime,  
       end_time datetime,  
       next_start_time datetime  
    )  
  
Declare @RE_Specs Table  
   (    spec_id   int,  
       spec_desc  varchar(200))  
  
Declare @Product_Specs Table  
   (     prod_code   nvarchar(20),  
        prod_desc      nvarchar(200),  
        spec_id  int,  
        spec_desc  nvarchar(200),  
        target   float)  
  
Declare @Conv_Class_Prod Table (  
       Class   int,  
       Prod_Id   varchar(20),  
       Value   float)  
  
Declare @RptEqns Table  
 (      VariableName    varchar(100),  
       Equation   varchar(1000))  
  
Declare @ClassREInfo Table (  
             Class int,  
             Conversion nvarchar(200))  
     
IF OBJECT_ID('tempdb.dbo.#Timed_Event_Detail_History', 'U') IS NOT NULL  DROP TABLE #Timed_Event_Detail_History
Create Table #Timed_Event_Detail_History  
       ( Tedet_ID int,  
         User_ID int)  
  
CREATE NONCLUSTERED INDEX IDX_DownHistory  
ON #Timed_Event_Detail_History(Tedet_ID) ON [PRIMARY]  
  
Declare @LineStatus Table  (
		RcID	int identity,
		PU_ID  int,  
		Phrase_Value  nvarchar(50),  
		StartTime  datetime,  
		EndTime  datetime)  
  
Declare @Products Table  
         (PU_ID       int,  
          Prod_ID      int,  
          Prod_Code      nvarchar(50),  
          Prod_Desc      nvarchar(100),  
          Product_Size    nvarchar(100),  
          StartTime      datetime,  
          EndTime      datetime  
      )  
  
Declare @Crew_Schedule Table  (
		RcId			int identity,
		StartTime        datetime,   
		EndTime           datetime,  
		Pu_id             int,  
		Crew              varchar(20),   
		Shift             varchar(5))

DECLARE	@tOutput TABLE
(
	PRLossPDT			INT,
	PRLossUDT			FLOAT,
	PR					FLOAT,
	StopsE				INT,
	CenterlineOut		INT,
	MachineScrap		FLOAT,
	NetProduction		FLOAT,
	StopsP				INT,
	ScheduleTime		INT,
	StopsU				INT,
	StopsUD				INT,
	CenterlineComplete	INT,
	Stops				INT,
	SCrap				FLOAT,
	UPPR				FLOAT
)		
  
  
----------------------------------------------------------------------------------------------------------------------  
-- END CREATE TEMPORARY TABLES :   
----------------------------------------------------------------------------------------------------------------------  
-- INITIALIZE TEMPORARY TABLES TO MINIMIZE RECOMPILE :  
--Print convert(varchar(25), getdate(), 120) + ' Start Initialization'   
----------------------------------------------------------------------------------------------------------------------  
  
set @r = (Select Count(*) FROM #PLIDList)  
set @r = (Select Count(*) FROM #ShiftDESCList)  
set @r = (Select Count(*) FROM #CrewDESCList)  
set @r = (Select Count(*) FROM #PLStatusDESCList)  
set @r = (Select Count(*) FROM #Splices)  
set @r = (Select Count(*) FROM #Rejects)  
set @r = (Select Count(*) FROM #Summary)  
set @r = (Select Count(*) FROM #Top5Downtime)  
set @r = (Select Count(*) FROM #Top5Stops)  
set @r = (Select Count(*) FROM #Top5Rejects)  
set @r = (Select Count(*) FROM #Downtimes)  
set @r = (Select Count(*) FROM #Production)  
set @r = (Select Count(*) FROM #TEMPORARY)  
set @r = (Select Count(*) FROM #InvertedSummary)  
set @r = (Select Count(*) FROM #FlexParam)  
set @r = (Select Count(*) FROM #ReasonsToExclude)  
set @r = (Select Count(*) FROM #Equations)  
set @r = (Select Count(*) FROM #ac_Top5Stops)  
set @r = (Select Count(*) FROM #ac_Top5Downtimes)  
set @r = (Select Count(*) FROM #ac_Top5Rejects)  
set @r = (Select Count(*) FROM #Params)  
----------------------------------------------------------------------------------------------------------------------  
--  GET Parameters FROM Report Name  
--Print convert(varchar(25), getdate(), 120) + ' End Initialization'   
----------------------------------------------------------------------------------------------------------------------  
DECLARE  
 @fltDBVersion   Float  
---------------------------------------------------------------------------------------------------  
-- Check Parameter: Database version  
---------------------------------------------------------------------------------------------------  
IF ( SELECT  IsNumeric(App_Version)  
   FROM AppVersions  
   WHERE App_Id = 2) = 1  
BEGIN  
 SELECT  @fltDBVersion = CONVERT(Float, App_Version)  
  FROM AppVersions  
  WHERE App_Id = 2  
END  
ELSE  
BEGIN  
 SELECT @fltDBVersion = 1.0  
END  

---------------------------------------------------------------------------------------------------  
--PRINT ' . DBVersion: ' + RTrim(LTrim(Str(@fltDBVersion, 10, 2))) -- debug  
---------------------------------------------------------------------------------------------------  
SELECT  @ReportName = 'DPR'

Select @Rpt_ShowTop5Rejects  = 'TRUE'  
Select @Rpt_ShowTop5Downtimes  = 'TRUE'  
Select @Rpt_ShowTop5Stops   = 'TRUE'  
  
--Select @Report_Id = Report_Id FROM Report_Definitions WHERE Report_Name = @Report_Name  
  
-- Search Parameters
--Insert Into #Params (Param,Value)  
--	Select rp.rp_name as param, rdp.value   
--		FROM dbo.report_definition_parameters rdp WITH(NOLOCK)  
--		JOIN dbo.report_type_parameters rtp WITH(NOLOCK) ON rtp.rtp_id = rdp.rtp_id  
--		JOIN dbo.report_parameters rp WITH(NOLOCK) ON rp.rp_id = rtp.rp_id  
--		WHERE rdp.Report_Id = @Report_Id  

-- Parameters
--SELECT	@RPTWasteFieldorder = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'WasteFieldorder'), 0)
--SELECT	@RPTDowntimeFieldorder = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DowntimeFieldorder'), 0)
--SELECT	@RPTDowntimeFilterMinutes = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DowntimeFilterMinutes'), 0)
--SELECT	@RPTFilterMinutes = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'FilterMinutes'), 0)
--SELECT	@Local_PG_strRptDPRColumnVisibility = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'ColumnVisibility'), 0)
--SELECT	@Local_PG_StrCategoriesToExclude = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'CategoriesToExclude'), 0)
--SELECT	@RPT_ShowClassProduct = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'ShowClassProduct'), 0)
--SELECT	@RptDowntimeSurvivalRate = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DowntimeSurvivalRate'), 0)
--SELECT	@RPTMajorGroupBy = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'MajorGroupBy'), 0)
--SELECT	@RPTMinorGroupBy = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'MinorGroupBy'), 0)
--SELECT	@Rpt_ShowTop5Rejects = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Rpt_ShowTop5Rejects'), 'TRUE')
--SELECT	@Rpt_ShowTop5Stops = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'ShowTop5Stops'), 'TRUE')
--SELECT	@Rpt_ShowTop5Downtimes = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'ShowTop5Downtimes'), 'TRUE')
--SELECT	@RPT_ShowSplices = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'ShowSplices'), 0)
--SELECT	@RPT_ShowSucSplices = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'ShowSucSplices'), 0)
--SELECT	@RPT_SurvivalRate = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'SurvivalRate'), 0)
--SELECT	@RPT_SurvivalRatePer = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'SurvivalRatePer'), 0)
--SELECT	@RPT_CaseCountClass = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'CaseCountClass'), 3)
--SELECT	@intTimeOption = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'TimeOption'), 0)
--SELECT	@dtmRptShiftStart = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName, 'Local_PG_StartShift'), '6:30:00')
--SELECT	@intRptShiftLength = ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName, 'Local_PG_ShiftLength'), 8)
  

Insert Into #Params (Param,Value) SELECT 'TimeOption'							,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'TimeOption'), 0)
Insert Into #Params (Param,Value) SELECT 'strRPTDowntimeFieldorder'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'strRPTDowntimeFieldorder'), 'Reason1~Reason2')
Insert Into #Params (Param,Value) SELECT 'strRPTWasteFieldorder'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'strRPTWasteFieldorder'), 'Reason1~!Null')
Insert Into #Params (Param,Value) SELECT 'Local_PG_TDowntime'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_TDowntime'), 10)
Insert Into #Params (Param,Value) SELECT 'Local_PG_T'							,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_T'), 2)
Insert Into #Params (Param,Value) SELECT 'Local_PG_StrRptDPRColumnVisibility'	,@RPTKPISelectionList--,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_StrRptDPRColumnVisibility'), 'ACPStops,ACPStops/Day')
Insert Into #Params (Param,Value) SELECT 'Local_PG_StrCategoriesToExclude'		,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_StrCategoriesToExclude'), 'Planned Downtime')
-- Insert Into #Params (Param,Value) SELECT 'Local_PG_StrLineStatusName1'			,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_StrLineStatusName1'), 'All')
Insert Into #Params (Param,Value) SELECT 'DPR_ShowClassProduct'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_ShowClassProduct'), 'FALSE')
Insert Into #Params (Param,Value) SELECT 'intRptDowntimeSurvivalRate'			,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'intRptDowntimeSurvivalRate'), '230')
Insert Into #Params (Param,Value) SELECT 'DPR_ShowTop5Rejects'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_ShowTop5Rejects'), 'TRUE')
Insert Into #Params (Param,Value) SELECT 'DPR_ShowTop5Stops'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_ShowTop5Stops'), 'TRUE')
Insert Into #Params (Param,Value) SELECT 'DPR_ShowTop5Downtimes'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_ShowTop5Downtimes'), 'TRUE')
Insert Into #Params (Param,Value) SELECT 'DPR_TotalSplices'						,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_TotalSplices'), 'TRUE')
Insert Into #Params (Param,Value) SELECT 'DPR_SucSplices'						,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_SucSplices'), 'FALSE')
Insert Into #Params (Param,Value) SELECT 'DPR_SurvivalRate'						,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_SurvivalRate'), 'FALSE')
Insert Into #Params (Param,Value) SELECT 'DPR_SurvivalRate%'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_SurvivalRate%'), 'FALSE')
Insert Into #Params (Param,Value) SELECT 'Local_PG_StartShift'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_StartShift'), '6:30:00')
Insert Into #Params (Param,Value) SELECT 'Local_PG_ShiftLength'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_ShiftLength'), 8)
Insert Into #Params (Param,Value) SELECT 'DPR_Class1_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class1_Translation'),'Pads')
Insert Into #Params (Param,Value) SELECT 'DPR_Class2_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class2_Translation'),'Bags')
Insert Into #Params (Param,Value) SELECT 'DPR_Class3_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class3_Translation'),'Cases')
Insert Into #Params (Param,Value) SELECT 'DPR_Class4_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class4_Translation'),'Class 4')
Insert Into #Params (Param,Value) SELECT 'DPR_Class5_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class5_Translation'),'Class 5')
Insert Into #Params (Param,Value) SELECT 'DPR_Class6_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class6_Translation'),'Class 6')
Insert Into #Params (Param,Value) SELECT 'DPR_Class7_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class7_Translation'),'Class 7')
Insert Into #Params (Param,Value) SELECT 'DPR_Class8_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class8_Translation'),'Class 8')
Insert Into #Params (Param,Value) SELECT 'DPR_Class9_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class9_Translation'),'Class 9')
Insert Into #Params (Param,Value) SELECT 'DPR_Class10_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class10_Translation'),'Class 10')
Insert Into #Params (Param,Value) SELECT 'DPR_Class11_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class11_Translation'),'Class 11')
Insert Into #Params (Param,Value) SELECT 'DPR_Class12_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class12_Translation'),'Class 12')
Insert Into #Params (Param,Value) SELECT 'DPR_Class13_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class13_Translation'),'Class 13')
Insert Into #Params (Param,Value) SELECT 'DPR_Class14_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class14_Translation'),'Class 14')
Insert Into #Params (Param,Value) SELECT 'DPR_Class15_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class15_Translation'),'Class 15')
Insert Into #Params (Param,Value) SELECT 'DPR_Class16_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class16_Translation'),'Class 16')
Insert Into #Params (Param,Value) SELECT 'DPR_Class17_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class17_Translation'),'Class 17')
Insert Into #Params (Param,Value) SELECT 'DPR_Class18_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class18_Translation'),'Class 18')
Insert Into #Params (Param,Value) SELECT 'DPR_Class19_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class19_Translation'),'Class 19')
Insert Into #Params (Param,Value) SELECT 'DPR_Class20_Translation'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Class20_Translation'),'Class 20')
Insert Into #Params (Param,Value) SELECT 'DPR_Downtime_EQN'						,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Downtime_EQN'		),'OP=SUM;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_LineStops_EQN'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_LineStops_EQN'		),'OP=SUM;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_Scrap_EQN'						,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_Scrap_EQN'			),'OP=SUM;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_TargetSpeed_EQN'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_TargetSpeed_EQN'	),'OP=AVG;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_TotalProduct_EQN'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_TotalProduct_EQN'	),'OP=SUM;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_TotalSplices_EQN'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_TotalSplices_EQN'	),'OP=SUM;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_GoodProduct_EQN'					,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_GoodProduct_EQN'	),'OP=SUM;CLASS=1')
Insert Into #Params (Param,Value) SELECT 'DPR_ACPStops_EQN'						,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_ACPStops_EQN'		),'OP=SUM;CLASS=3')
Insert Into #Params (Param,Value) SELECT 'DPR_TotalProdTime_EQN'				,ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'DPR_TotalProdTime_EQN'	),'OP=SUM;CLASS=1')

-- Set Variables from Parameters
Select @RPTDowntimeFieldorder = value FROM #Params WHERE param = 'strRPTDowntimeFieldorder'  
Select @RPTWasteFieldorder = value FROM #Params WHERE param  = 'strRPTWasteFieldorder'  
      
-- GROUPING : set the two new parameters  
--Select @RPTMajorGroupBy = value FROM #Params WHERE param  = 'StrRptMajorGroupBy'  
--Select @RPTMinorGroupBy = value FROM #Params WHERE param  = 'StrRptMinorGroupBy'  
         
Select @RPTDowntimeFilterMinutes = value FROM #Params WHERE param = 'Local_PG_TDowntime'  
If @RPTDowntimeFilterMinutes Is Null Select @RPTDowntimeFilterMinutes = @RptFilterMinutes  

Select @RPTFilterMinutes = value FROM #Params WHERE param = 'Local_PG_T'  

If @RPTFilterMinutes Is Null Select @RptFilterMinutes = @RPTDowntimeFilterMinutes  
Set @Local_PG_strRptDPRColumnVisibility = '!Null'  

Select @Local_PG_strRptDPRColumnVisibility = IsNull(Value,'!Null') FROM #Params WHERE Param = 'Local_PG_StrRptDPRColumnVisibility'  
Select @Local_PG_StrCategoriesToExclude = '!Null'  
Select @Local_PG_StrCategoriesToExclude = IsNull(Value,'!Null') FROM #Params WHERE Param = 'Local_PG_StrCategoriesToExclude'  

 --SELECT '@Local_PG_StrCategoriesToExclude -->', @Local_PG_StrCategoriesToExclude

-- Select @RPTPLStatusDESCList = value FROM #Params WHERE Param = 'Local_PG_StrLineStatusName1'  
Select @RPT_ShowClassProduct = value FROM #Params WHERE Param = 'DPR_ShowClassProduct'  
Select @RptDowntimeSurvivalRate = value FROM #Params WHERE Param = 'intRptDowntimeSurvivalRate'  
  
Select @Rpt_ShowTop5Rejects = Value FROM #Params WHERE Param = 'DPR_ShowTop5Rejects'  
If @RPTMinorGroupBy = 'ProdDay'  
	Select @Rpt_ShowTop5Rejects = 'TRUE'  
          
Select @Rpt_ShowTop5Stops = Value FROM #Params WHERE Param = 'DPR_ShowTop5Stops'  
Select @Rpt_ShowTop5Downtimes = Value FROM #Params WHERE Param = 'DPR_ShowTop5Downtimes'  
          
Select @RPT_ShowSplices = Value FROM #Params WHERE Param = 'DPR_TotalSplices'  
Select @RPT_ShowSucSplices  = Value FROM #Params WHERE Param = 'DPR_SucSplices'  
  
Select @RPT_SurvivalRate = Value FROM #Params WHERE Param = 'DPR_SurvivalRate'  
Select @RPT_SurvivalRatePer = Value FROM #Params WHERE Param = 'DPR_SurvivalRate%'  
Select @RPT_CaseCountClass = '3'  
Select @RPT_CaseCountClass = IsNull(Value,'3') FROM #Params WHERE Param = 'DPR_CaseCount_EQN'  


-- Conditional parameters
If @RPTMinorGroupBy = 'ProdDay'  
 	Select @Rpt_ShowTop5Rejects = 'TRUE'
If @RPTDowntimeFilterMinutes Is Null 
	Select @RPTDowntimeFilterMinutes = @RptFilterMinutes 
If @RPTFilterMinutes Is Null 
	Select @RptFilterMinutes = @RPTDowntimeFilterMinutes  

--EXEC spCmn_GetReportParameterValue 	@Report_Name, 'TimeOption'						, 31  , @intTimeOption OUTPUT
--EXEC spCmn_GetReportParameterValue 	@Report_Name, 'Local_PG_StartShift'				, '6:30:00'	, @dtmRptShiftStart OUTPUT
--EXEC spCmn_GetReportParameterValue 	@Report_Name, 'Local_PG_ShiftLength'			, 8			, @intRptShiftLength OUTPUT

-- SELECT @intTimeOption , @dtmRptShiftStart, @intRptShiftLength
--SET @intTimeOption = 0

Select @intTimeOption = Value FROM #Params WHERE Param = 'TimeOption'  

-------------------------------------------------------------------------------------------------------------------
-- Time Options
-------------------------------------------------------------------------------------------------------------------
	SELECT @vchTimeOption = CASE @inTimeOption
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
		SELECT	@RptStartDate = dtmStartTime ,
				@RptEndDate = dtmEndTime
		FROM [dbo].[fnLocal_DDSStartEndTime](@vchTimeOption)

	END


IF @intTimeOption = 0 
BEGIN 
		SELECT @StartDateTime = @RptStartDate ,@EndDateTime = @RptEndDate  
END
ELSE
BEGIN 
		INSERT INTO #Local_PG_StartEndTime (
								rptStartTime,
								rptEndTime				)
		EXEC dbo.spLocal_RptRunTime @intTimeOption,@intRptShiftLength ,@dtmRptShiftStart,@RptStartDate ,@EndDateTime
					
		SELECT   	 @StartDateTime 	= CONVERT(DATETIME,rptStartTime)		,
					 @EndDateTime       = CONVERT(DATETIME,rptEndTime)
		FROM 		 #Local_PG_StartEndTime
END
 
--SELECT '@StartDateTime',@StartDateTime,@EndDateTime,Getdate()
--*******************************************************************************************************  
-- GROUPING : Insert into #Summary the labels for Report  
--*******************************************************************************************************  
-- Select * FROM #Status order by pu_id,starttime  
  
    
Insert #Summary   (GroupField,null02) Values ('Major',@RPTMajorGroupBy )  
Insert #Summary   (GroupField,null02) Values ('Minor',@RPTMinorGroupBy )  
If @RPT_ShowTop5Downtimes = 'TRUE'  
Begin  
 Insert #Top5Downtime   (GroupField) Values ('Major')  
 Insert #Top5Downtime   (GroupField) Values ('Minor')  
End  
If @RPT_ShowTop5Stops = 'TRUE'  
Begin  
 Insert #Top5Stops   (GroupField) Values ('Major')  
 Insert #Top5Stops   (GroupField) Values ('Minor')  
End  
If @RPT_ShowTop5Rejects = 'TRUE' AND @RPTMinorGroupBy <> 'ProdDay'  
Begin  
 Insert #Top5Rejects   (GroupField) Values ('Major')  
 Insert #Top5Rejects   (GroupField) Values ('Minor')  
End  
--  
If @RPT_ShowTop5Downtimes = 'TRUE'  
        Insert #TOP5Downtime (Desc01, Desc02, Stops) Values (@lblDTLevel1, @lblDTLevel2, @lblStops)  
  
If @RPT_ShowTop5Stops = 'TRUE'  
        Insert #TOP5Stops (Desc01, Desc02, Downtime) Values (@lblDTLevel1, @lblDTLevel2, @lblDowntime)  
  
If @RPT_ShowTop5Rejects = 'TRUE' AND @RPTMinorGroupBy <> 'ProdDay'  
        Insert #TOP5REJECTS (Desc01, Desc02, Events) Values (@lblRJLevel1, @lblRJLevel2, @lblEvents)  
  
-----------------------------------------------------------------------------------------------------------------  
-- Insert values in the Column Visibility table to be used for Report Output  
--Print convert(varchar(25), getdate(), 120) + ' Start Building Column Visibility TABLE'  
-----------------------------------------------------------------------------------------------------------------  
  
Declare @NoLabels as int  
  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Availability','Availability','Availability')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('PRusingProductCount','PR using Product Count','PR')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('PRusingAvailability','PR using Availability','PRavail')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('SU','Schedule Utilization','SU')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('CU','Capacity Utilization','CU')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RU','Rate Utilization','RU')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RunEfficiency','Run Efficiency','RunEff')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Line_Stops','Line Stops','LineStops')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('LineStopsUnplanned','Line Stops (Unplanned)','LineStopsERC')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Stops/Day','Stops/Day','StopsPerDay')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Stops/MSU','Stops/MSU','StopsPerMSU')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Down/MSU','Down/MSU','DownPerMSU')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Downtime','Downtime','Downtime')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('DowntimeUnplanned','Downtime (Unplanned)','DowntimeERC')  
-- FO-00806: % Unplanned Downtime 
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('DowntimeUnplanned%','Downtime (Unplanned) % ','DowntimeUnplannedPerc')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Uptime','Uptime','Uptime')  
-- FO-00847-A: Rename MTBF in the DPR Report. 
--Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MTBF','MTBF','MTBF')  
--Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MTBF_Unplanned','MTBF (Unplanned)','MTBF_ERC')  

Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MTBS','MTBS','MTBF')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MTBF','MTBF','MTBF_ERC')  

Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MTTR','MTTR','MTTR')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MTTR_Unplanned','MTTR (Unplanned)','MTTR_ERC')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('ACPStops','ACP Stops','ACPStops')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('ACPStops/Day','ACP Stops/Day','ACPSTOpsperday')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Scrap','Rejected Product','TotalScrap')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Scrap%','Scrap %','TotalScrapPer')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RunningScrap%','Running Scrap %','RunningScrapPer')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('DowntimeScrap%','Downtime Scrap %','DowntimescrapPer')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RunningScrap','Running Scrap','RunningScrap')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('DowntimeScrap','Downtime Scrap','DowntimeScrap')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Area4Loss%','Area 4 Loss %','Area4LossPer')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RepairTime>T','Repair Time > 10','RepairTimeT')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('FalseStarts(UT=0)','False Starts (UT=0)','FalseStarts')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('FalseStarts(UT=0)%','False Starts (UT=0)%','FalseStarts0Per')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('FalseStarts(UT=T)','False Starts (UT=T)','FalseStartsT')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('FalseStarts(UT=T)%','False Starts (UT=T)%','FalseStartsTPer')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('R(T=0)','R(0)','Rofzero')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('R(T=T)','R(2)','RofT')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('SurvivalRate','Survival Rate','SurvivalRate')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('SurvivalRate% ','Survival Rate %','SurvivalRatePer')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('TotalSplices','Total Splices','TotalSplices')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('SucSplices','Success Splices','SucSplices')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('FailedSplices','Failed Splices','FailedSplices')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('SuccessRate','Success Rate','SuccessRate')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('MSU','MSU','MSU')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('TotalProduct','Total Product','TotalPads')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass1Product','Total ' + IsNull(value,'Class1') + ' Product' ,'Totalclass1' FROM #Params WHERE param = 'DPR_Class1_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass2Product','Total ' + IsNull(value,'Class2') + ' Product' ,'Totalclass2' FROM #Params WHERE param = 'DPR_Class2_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass3Product','Total ' + IsNull(value,'Class3') + ' Product' ,'Totalclass3' FROM #Params WHERE param = 'DPR_Class3_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass4Product','Total ' + IsNull(value,'Class4') + ' Product' ,'Totalclass4' FROM #Params WHERE param = 'DPR_Class4_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass5Product','Total ' + IsNull(value,'Class5') + ' Product' ,'Totalclass5' FROM #Params WHERE param = 'DPR_Class5_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass6Product','Total ' + IsNull(value,'Class6') + ' Product' ,'Totalclass6' FROM #Params WHERE param = 'DPR_Class6_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass7Product','Total ' + IsNull(value,'Class7') + ' Product' ,'Totalclass8' FROM #Params WHERE param = 'DPR_Class7_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass8Product','Total ' + IsNull(value,'Class8') + ' Product' ,'Totalclass8' FROM #Params WHERE param = 'DPR_Class8_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass9Product','Total ' + IsNull(value,'Class9') + ' Product' ,'Totalclass9' FROM #Params WHERE param = 'DPR_Class9_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass10Product','Total ' + IsNull(value,'Class10') + ' Product' ,'Totalclass10' FROM #Params WHERE param = 'DPR_Class10_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass11Product','Total ' + IsNull(value,'Class11') + ' Product' ,'Totalclass11' FROM #Params WHERE param = 'DPR_Class11_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass12Product','Total ' + IsNull(value,'Class12') + ' Product' ,'Totalclass12' FROM #Params WHERE param = 'DPR_Class12_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass13Product','Total ' + IsNull(value,'Class13') + ' Product' ,'Totalclass13' FROM #Params WHERE param = 'DPR_Class13_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass14Product','Total ' + IsNull(value,'Class14') + ' Product' ,'Totalclass14' FROM #Params WHERE param = 'DPR_Class14_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass15Product','Total ' + IsNull(value,'Class15') + ' Product' ,'Totalclass15' FROM #Params WHERE param = 'DPR_Class15_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass16Product','Total ' + IsNull(value,'Class16') + ' Product' ,'Totalclass16' FROM #Params WHERE param = 'DPR_Class16_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass17Product','Total ' + IsNull(value,'Class17') + ' Product' ,'Totalclass17' FROM #Params WHERE param = 'DPR_Class17_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass18Product','Total ' + IsNull(value,'Class18') + ' Product' ,'Totalclass18' FROM #Params WHERE param = 'DPR_Class18_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass19Product','Total ' + IsNull(value,'Class19') + ' Product' ,'Totalclass19' FROM #Params WHERE param = 'DPR_Class19_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'TotalClass20Product','Total ' + IsNull(value,'Class20') + ' Product' ,'Totalclass20' FROM #Params WHERE param = 'DPR_Class20_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('GoodProduct','Good Product','GoodPads')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass1Product','Good ' + IsNull(value,'Class1') + ' Product','GoodClass1' FROM #Params WHERE param = 'DPR_Class1_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass2Product','Good ' + IsNull(value,'Class2') + ' Product','GoodClass2' FROM #Params WHERE param = 'DPR_Class2_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass3Product','Good ' + IsNull(value,'Class3') + ' Product','GoodClass3' FROM #Params WHERE param = 'DPR_Class3_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass4Product','Good ' + IsNull(value,'Class4') + ' Product','GoodClass4' FROM #Params WHERE param = 'DPR_Class4_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass5Product','Good ' + IsNull(value,'Class5') + ' Product','GoodClass5' FROM #Params WHERE param = 'DPR_Class5_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass6Product','Good ' + IsNull(value,'Class6') + ' Product','GoodClass6' FROM #Params WHERE param = 'DPR_Class6_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass7Product','Good ' + IsNull(value,'Class7') + ' Product','GoodClass7' FROM #Params WHERE param = 'DPR_Class7_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass8Product','Good ' + IsNull(value,'Class8') + ' Product','GoodClass8' FROM #Params WHERE param = 'DPR_Class8_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass9Product','Good ' + IsNull(value,'Class9') + ' Product','GoodClass9' FROM #Params WHERE param = 'DPR_Class9_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass10Product','Good ' + IsNull(value,'Class10') + ' Product','GoodClass10' FROM #Params WHERE param = 'DPR_Class10_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass11Product','Good ' + IsNull(value,'Class11') + ' Product','GoodClass11' FROM #Params WHERE param = 'DPR_Class11_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass12Product','Good ' + IsNull(value,'Class12') + ' Product','GoodClass12' FROM #Params WHERE param = 'DPR_Class12_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass13Product','Good ' + IsNull(value,'Class13') + ' Product','GoodClass13' FROM #Params WHERE param = 'DPR_Class13_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass14Product','Good ' + IsNull(value,'Class14') + ' Product','GoodClass14' FROM #Params WHERE param = 'DPR_Class14_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass15Product','Good ' + IsNull(value,'Class15') + ' Product','GoodClass15' FROM #Params WHERE param = 'DPR_Class15_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass16Product','Good ' + IsNull(value,'Class16') + ' Product','GoodClass16' FROM #Params WHERE param = 'DPR_Class16_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass17Product','Good ' + IsNull(value,'Class17') + ' Product','GoodClass17' FROM #Params WHERE param = 'DPR_Class17_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass18Product','Good ' + IsNull(value,'Class18') + ' Product','GoodClass18' FROM #Params WHERE param = 'DPR_Class18_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass19Product','Good ' + IsNull(value,'Class19') + ' Product','GoodClass19' FROM #Params WHERE param = 'DPR_Class19_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Select 'GoodClass20Product','Good ' + IsNull(value,'Class20') + ' Product','GoodClass20' FROM #Params WHERE param = 'DPR_Class20_Translation'  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('TargetSpeed','Target Speed','TargetSpeed')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('IdealSpeed','Ideal Speed','IdealSpeed')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('AverageLineSpeed','Line Speed','LineSpeed')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('ProductionTime','Line Status Schedule Time','ProdTime')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('STNU','Staff Time Not Used','STNU')  

Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RealDowntime','Real Downtime','TotalDowntime')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('RealUptime','Real Uptime','TotalUptime')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStops','Edited Stops','NumEdits')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStops%','Edited Stops %','EditedStopsPer')  
  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_1','Flexible_Variable_1','Flex1')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_2','Flexible_Variable_2','Flex2')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_3','Flexible_Variable_3','Flex3')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_4','Flexible_Variable_4','Flex4')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_5','Flexible_Variable_5','Flex5')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_6','Flexible_Variable_6','Flex6')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_7','Flexible_Variable_7','Flex7')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_8','Flexible_Variable_8','Flex8')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_9','Flexible_Variable_9','Flex9')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('Flexible_Variable_10','Flexible_Variable_10','Flex10')  
  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStopsReason1','Edited Stops Reason 1','NumEditsR1')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStopsReason1%','Edited Stops Reason 1%','EditedStopsR1Per')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStopsReason2','Edited Stops Reason 2','NumEditsR2')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStopsReason2%','Edited Stops Reason 2%','EditedStopsR2Per')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStopsReason3','Edited Stops Reason 3','NumEditsR3')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('EditedStopsReason3%','Edited Stops Reason 3%','EditedStopsR3Per')  
Insert Into @ColumnVisibility(VariableName,LabelName,FieldName) Values('CaseCounter','CaseCounter','CaseCount')  
  
Select @NoLabels = Count(*) FROM @ColumnVisibility  
-----------------------------------------------------------------------------------------------------------  
--Print convert(varchar(25), getdate(), 120) + ' END Building Column Visibility TABLE'  
-----------------------------------------------------------------------------------------------------------  
-- FORMAT MAJOR AND MINOR GROUPING   
 Declare   
        @RPTMinorGroupByOld as nvarchar(100),  
        @RPTMajorGroupByOld as nvarchar(100)  
  
 Set  @RPTMajorGroupByOld = @RPTMajorGroupBy   
          
 If @RPTMinorGroupBy = @RPTMajorGroupBy   
        Set @RPTMinorGroupBy = 'None'  
  
 If @RPTMinorGroupBy = 'None'  
 Begin  
 Set @RPTMinorGroupBy = @RPTMajorGroupBy  
        Set @RPTMajorGroupBy = 'Line'  
 End  
  
 Set  @RPTMinorGroupByOld = @RPTMinorGroupBy  
  
-----------------------------------------------------------------------------------------------------------  
  
-- Checking the strRptPageOrientation parameter modify the DPR_HorizontalLayout  
--  if landscape layout, then only one reason column is displayed so the second sort order must be null  
Declare @strRptPageOrientation as nvarchar(20)  
  
Select @strRptPageOrientation = value FROM #Params WHERE param like '%strRptPageOrientation%'  
  
If @strRptPageOrientation = 'Landscape'  
 UPDATE #Params Set value = 'TRUE' WHERE param = 'DPR_HorizontalLayout'  
Else  
 UPDATE #Params Set value = 'FALSE' WHERE param = 'DPR_HorizontalLayout'  
  
If (Select value FROM #Params WHERE param = 'DPR_HorizontalLayout') = 'TRUE'  
 Begin  
  Select @RPTDowntimeFieldOrder=LEFT(@RptDowntimeFieldOrder,CHARINDEX('~',@RptDowntimeFieldOrder))+'!Null'  
  Select @RPTWasteFieldOrder=LEFT(@RptWasteFieldOrder,CHARINDEX('~',@RPTwasteFieldOrder))+'!Null'  
 End   
  
----------------------------------------------------------------------------  
-- Check Parameter: Company AND Site Name  
----------------------------------------------------------------------------  
Select @CompanyName = Coalesce(Value, 'Company Name') -- Company Name  
 FROM Site_Parameters  
 WHERE Parm_Id = 11  
  
Select @SiteName = Coalesce(Value, 'Site Name') -- Site Name  
 FROM Site_Parameters  
 WHERE Parm_Id = 12  
----------------------------------------------------------------------------  
-- Check Parameter: Downtime User used For PLCEP, should be ReliablitySystem   
----------------------------------------------------------------------------  
Select @DowntimesystemUserID =   
 User_ID  
 FROM USERS  
 WHERE UserName = @RPTDowntimesystemUser  
  
If @DowntimesystemUserID Is null  
Begin  
 Select @ErrMsg = 'Downtime User ID Is null'  
 --GOTO ErrorCode  
End  
  
----------------------------------------------------------------------------  
-- Check Parameter: Specifications  
----------------------------------------------------------------------------  
-- @RPTPadsPerStat  
  
Select @SpecPropertyID = PROP_ID  
 FROM dbo.Product_Properties WITH(NOLOCK)  
 WHERE Prop_Desc = @RPTSpecProperty  
  
Select @PadsPerStatSpecID = Spec_ID  
 FROM dbo.Specifications ss WITH(NOLOCK)  
 WHERE (Spec_Desc like '%Per Stat%' Or Spec_Desc ='Stat Unit')  
 AND Prop_Id = @SpecPropertyID  
  
Select @IdealSpeedSpecID = Spec_ID  
 FROM dbo.Specifications ss WITH(NOLOCK)  
 WHERE Spec_Desc = @RPTIdealSpeed   
 AND Prop_Id = @SpecPropertyID  
----------------------------------------------------------------------------------------------------------------------  
-- String Parsing: Parse Line ID, also gets info associated Only to the Line  
-- e.g the Converter Unit ID.  
----------------------------------------------------------------------------------------------------------------------  
  
--Select @LineSpec = Value FROM #Params WHERE Param = 'Local_PG_strLinesByName1'  
Select @LineSpec = @RPTLineDESCList


Insert #Temp_LinesParam (RecId,PlDesc)  
   Exec SPCMN_ReportCollectionParsing  
   @PRMCollectionString = @LineSpec, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',   
   @PRMDataType01 = 'nvarchar(200)'  

  
Declare   
  @LS_Prop_Id  as  Int  
  
Select @LS_Prop_Id = Prop_Id FROM Product_Properties WHERE Prop_Desc = 'Line Configuration'  
  
Insert Into @Class  
Select cc.Char_Desc, cc.Char_Id, ss.Spec_Desc,Null, pu.PU_ID, PU_Desc  
FROM dbo.Specifications ss WITH(NOLOCK)   
JOIN dbo.Characteristics cc WITH(NOLOCK) ON cc.prop_id = ss.prop_id   
JOIN dbo.Active_Specs sa WITH(NOLOCK) ON sa.char_id = cc.char_id AND sa.spec_id = ss.spec_id AND sa.expiration_date is Null  
JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pu_id = cast(cast (sa.target as float)as int)  
WHERE cc.Char_Desc In (Select PLDesc FROM #Temp_LinesParam)  
   AND ss.Prop_Id = @LS_Prop_Id  

  
-- Step 2 : GET ALL THE CLASSES  
  
UPDATE @Class Set Class = 1 WHERE charindex( '_I_', Class_Code)>0  
UPDATE @Class Set Class = 2 WHERE charindex( '_II_', Class_Code)>0  
UPDATE @Class Set Class = 3 WHERE charindex( '_III_', Class_Code)>0  
UPDATE @Class Set Class = 4 WHERE charindex( '_IV_', Class_Code)>0  
UPDATE @Class Set Class = 5 WHERE charindex( '_V_', Class_Code)>0  
UPDATE @Class Set Class = 6 WHERE charindex( '_VI_', Class_Code)>0  
UPDATE @Class Set Class = 7 WHERE charindex( '_VII_', Class_Code)>0  
UPDATE @Class Set Class = 8 WHERE charindex( '_VIII_', Class_Code)>0  
UPDATE @Class Set Class = 9 WHERE charindex( '_IX_', Class_Code)>0  
UPDATE @Class Set Class = 10 WHERE charindex( '_X_', Class_Code)>0  
UPDATE @Class Set Class = 11 WHERE charindex( '_XI_', Class_Code)>0  
UPDATE @Class Set Class = 12 WHERE charindex( '_XII_', Class_Code)>0  
UPDATE @Class Set Class = 13 WHERE charindex( '_XIII_', Class_Code)>0  
UPDATE @Class Set Class = 14 WHERE charindex( '_XIV_', Class_Code)>0  
UPDATE @Class Set Class = 15 WHERE charindex( '_XV_', Class_Code)>0  
UPDATE @Class Set Class = 16 WHERE charindex( '_XVI_', Class_Code)>0  
UPDATE @Class Set Class = 17 WHERE charindex( '_XVII_', Class_Code)>0  
UPDATE @Class Set Class = 18 WHERE charindex( '_XVIII_', Class_Code)>0  
UPDATE @Class Set Class = 19 WHERE charindex( '_XIX_', Class_Code)>0  
UPDATE @Class Set Class = 20 WHERE charindex( '_XX_', Class_Code)>0  
  
  
UPDATE @Class   
	Set PLID = PL_Id  
	FROM @Class		c  
	JOIN Prod_Lines PL WITH(NOLOCK) ON c.Line_Desc = pl.pl_desc  
  
Insert INTO #PLIDList (
			Class, 
			PLID, 
			ConvUnit,
			PLDESC,
			UseCaseCount)    
	Select	Class, 
			PLID, 
			PU_Id, 
			Line_Desc,
			0 
		FROM @Class  
  
------------------------------------------------------------------------------------------------  
-- Get column visibility parameter  
------------------------------------------------------------------------------------------------  
--Print convert(varchar(25), getdate(), 120) + ' Get Column Visibility Parameters'  
  
-- Testing FO-00806
--SELECT '@ColumnVisibility', * FROM @ColumnVisibility --WHERE VariableName IN ('DowntimeUnplanned','DowntimeUnplanned%')  

PRINT '@Local_PG_strRptDPRColumnVisibility -->' + @Local_PG_strRptDPRColumnVisibility
If @Local_PG_strRptDPRColumnVisibility <> '!Null'  
Begin  
   --   
   Insert #Temp_ColumnVisibility (ColId,VariableName)  
   Exec SPCMN_ReportCollectionParsing  
   @PRMCollectionString = @Local_PG_strRptDPRColumnVisibility, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',   
   @PRMDataType01 = 'varchar(100)'                                    
   --   
            If exists (select * FROM #Temp_ColumnVisibility WHERE VariableName Like '%ShowClassProduct%')  
                                Select @RPT_ShowClassProduct = 'TRUE'  
         Else  
                                Select @RPT_ShowClassProduct = 'FALSE'       
  
   -- Before deleting all Parameters set them to FALSE  
     
   --UPDATE dbo.Report_Definition_Parameters   
   --        Set Value = 'FALSE'  
   --FROM dbo.Report_Definition_Parameters rdp WITH(NOLOCK)  
   --JOIN dbo.Report_Definitions r WITH(NOLOCK) ON rdp.report_id=r.report_id  
   --JOIN dbo.Report_Type_Parameters rtp WITH(NOLOCK) ON rtp.rtp_id = rdp.rtp_id  
   --JOIN dbo.Report_Parameters rp WITH(NOLOCK) ON rp.rp_id = rtp.rp_id  
   --WHERE r.report_id = @Report_Id  
   --AND rp_name IN (SELECT 'DPR_' + VariableName FROM @ColumnVisibility  
   --    WHERE VariableName Not Like 'TotalClass%'  
   --             AND VariableName Not Like 'GoodClass%'             
   --             AND VariableName Not Like 'Flexible_Variable_%')  
     
   --  
            Delete FROM @ColumnVisibility 
				WHERE VariableName Not In (Select VariableName FROM #Temp_ColumnVisibility)  
	            AND VariableName Not Like 'TotalClass%'  
		        AND VariableName Not Like 'GoodClass%'             
			    AND VariableName Not Like 'Flexible_Variable_%'  
  
End     
Else  
Begin            
      --  

		Delete FROM @ColumnVisibility   
			FROM @ColumnVisibility CV  
			WHERE VariableName Not In (select CV.VariableName FROM #Params WHERE param = 'DPR_' + CV.VariableName AND value = 'TRUE')  
				AND VariableName Not Like 'TotalClass%'  
				AND VariableName Not Like 'GoodClass%'                          
				AND	VariableName Not Like 'Flexible_Variable_%'  
      --
		--select '#Params', * FROM #Params -- WHERE param = 'DPR_' + CV.VariableName AND value = 'TRUE'  
End		

Delete FROM @ColumnVisibility   
WHERE   
  (VariableName Like 'TotalClass%' Or VariableName Like 'GoodClass%')  
  AND  
  (VariableName Not In  
  (Select Distinct 'TotalClass'+CONVERT(nvarchar,Class)+'Product' FROM @Class))  
  AND   
  (VariableName Not In  
  (Select Distinct 'GoodClass'+CONVERT(nvarchar,Class)+'Product' FROM @Class))  

If @RPT_ShowClassProduct = 'FALSE'   
  Delete FROM @ColumnVisibility WHERE VariableName like 'TotalClass%' or VariableName like 'GoodClass%'  
Else  
     Delete FROM @ColumnVisibility WHERE VariableName like 'TotalProduct' or VariableName like 'GoodProduct'  
  
  
-- Testing FO-00806
--SELECT '@ColumnVisibility2',* FROM @ColumnVisibility-- WHERE VariableName IN ('DowntimeUnplanned','DowntimeUnplanned%')  

--------------------------------------------------------------------------------------------------  
-- Get the EQN for each 'Defined' variable :  
--------------------------------------------------------------------------------------------------  
  
Insert Into #Equations (Param,Label,Variable,Operator,Class,Prec)  
Select param,NULL,  
(case param When 'DPR_Downtime_EQN'         Then 'Downtime'   
            When 'DPR_GoodProduct_EQN'      Then 'GoodPads'  
            When 'DPR_LineStops_EQN'        Then 'LineStops'  
            When 'DPR_Scrap_EQN'            Then 'TotalScrap'  
            When 'DPR_TargetSpeed_EQN'      Then 'TargetSpeed'  
            When 'DPR_TotalProduct_EQN'     Then 'TotalPads'  
            When 'DPR_TotalSplices_EQN'     Then 'TotalSplices'  
            When 'DPR_ACPStops_EQN'         Then 'ACPStops'  
            When 'DPR_TotalProdTime_EQN'    Then 'ProdTime'  
        end),  
substring(value,charindex('OP=',value)+3,charindex(';CLASS=',value)-(charindex('OP=',value)+3)) as Op,  
substring(value,charindex(';CLASS=',value)+7,Len(value)-(charindex(';CLASS=',value)+6)) as Class,  
1 as Prec  
FROM #Params  
WHERE right(param,4)='_EQN' AND param <> 'DPR_CaseCount_EQN'  
  
-- Select * FROM #Equations  
-- LineStops  
Insert Into #Equations Select 'DPR_RepairTime>T_EQN','Label=RepairTimeT;','RepairTimeT',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_SurvivalRate_EQN','Label=SurvivalRate;','SurvivalRate',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_EditedStops_EQN','Label=NumEdits;','NumEdits',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_FalseStarts(UT=0)_EQN','Label=FalseStarts;','FalseStarts',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_FalseStarts(UT=T)_EQN','Label=FalseStartsT;','FalseStartsT',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
-- Added  
Insert Into #Equations Select 'DPR_EditedStops_EQN','Label=NumEditsR1;','NumEditsR1',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_EditedStops_EQN','Label=NumEditsR2;','NumEditsR2',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_EditedStops_EQN','Label=NumEditsR3;','NumEditsR3',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_FalseStarts(UT=0)_EQN','Label=FalseStarts;','FalseStarts',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
Insert Into #Equations Select 'DPR_FalseStarts(UT=T)_EQN','Label=FalseStartsT;','FalseStartsT',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
-- TotalSplices  
Insert Into #Equations Select 'DPR_SuccessRate_EQN','Label=SuccessRate;','SuccessRate',Operator,Class,1 FROM #Equations WHERE Variable = 'TotalSplices'  
Insert Into #Equations Select 'DPR_SucSplices_EQN','Label=SucSplices;','SucSplices',Operator,Class,1 FROM #Equations WHERE Variable = 'TotalSplices'  
Insert Into #Equations Select 'DPR_FailedSplices_EQN','Label=FailedSplices;','FailedSplices',Operator,Class,1 FROM #Equations WHERE Variable = 'TotalSplices'  
-- TotalScrap  
Insert Into #Equations Select 'DPR_DowntimeScrap_EQN','Label=DowntimeScrap;','DowntimeScrap',Operator,Class,1 FROM #Equations WHERE Variable = 'TotalScrap'  
Insert Into #Equations Select 'DPR_RunningScrap_EQN','Label=RunningScrap;','RunningScrap',Operator,Class,1 FROM #Equations WHERE Variable = 'TotalScrap'  
-- Downtime  
Insert Into #Equations Select 'DPR_Uptime_EQN','Label=Uptime;','Uptime',Operator,Class,1 FROM #Equations WHERE Variable = 'Downtime'  
-- Production Time  
Insert Into #Equations Select 'DPR_CalendarTime_EQN','Label=CalendarTime;','CalendarTime',Operator,Class,1 FROM #Equations WHERE Variable = 'ProdTime'  
-- Good Product  
Insert Into #Equations Select 'DPR_MSU_EQN','Label=MSU;','MSU',Operator,Class,2 FROM #Equations WHERE Variable = 'GoodPads'  
-- Target Speed  
Insert Into #Equations Select 'DPR_IdealSpeed_EQN','Label=IdealSpeed;','IdealSpeed',Operator,Class,1 FROM #Equations WHERE Variable = 'TargetSpeed'  
-- Total Production Time  
INSERT INTO #Equations SELECT 'DPR_STNU_EQN','Label=STNU;','STNU',Operator,Class,1 FROM #Equations WHERE Variable = 'ProdTime'  
  
-- SELECT * FROM #Equations  
--------------------------------------------------------------------------------------------------  
-- Get the RE Product Info for each Class :  
--------------------------------------------------------------------------------------------------  
  
Insert Into @ClassREInfo (Class,Conversion)  
Select substring(param,charindex('Class',param)+5,charindex('ProductInfo',param)-(charindex('Class',param)+5)),value   
FROM #Params   
WHERE param like '%ProductInfo'  
AND (Value Is Not NULL Or Value > '')  
  
------------------------------------------------------------------------------------------------  
-- New logic to get the PU Extended info  
--Print convert(varchar(25), getdate(), 120) + ' New logic to get the PU Extended info'  
------------------------------------------------------------------------------------------------  
UPDATE #PlidList 
	Set ScheduleUnit=Substring(SubString(pu.Extended_Info,6,len(pu.Extended_Info)),1,Charindex(';',pu.Extended_Info)-6)  
	FROM #PlidList	PLID  
	JOIN Prod_Units pu ON PLID.ConvUnit = pu.pu_id --WHERE ConvUnit = @Conv -- AND ScheduleUnit>0  
	WHERE Extended_Info Like '%STLS%'  
  
UPDATE #PLIDList 
	Set ScheduleUnit = ConvUnit 
	WHERE ScheduleUnit Is Null  

UPDATE #PLIDList 
	Set ProductUnit = ConvUnit 
	WHERE ProductUnit Is Null  
  
-- End PU Extended Info  
------------------------------------------------------------------------------------------------------  
-- Change if PPA 6
--****************************************************************************************************  
-- Watchout here: these variables would probably not exist anymore. Need to be replaced by the Event
-- Dimensions of the Production Events.
--****************************************************************************************************  


UPDATE TPL Set SpliceUnit = PU.PU_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Prod_Lines_Base pl WITH(NOLOCK) ON TPL.PLDesc = pl.PL_Desc  
 JOIN @Class c ON c.pu_id = TPL.convUnit AND c.class_code = 'Class_I_1'  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pl_id = pl.pl_id AND pu.pu_desc Like '%Splicers%'  
  
UPDATE TPL Set PartPadCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type IN(0,5)  
  AND (V.test_name Like '%'+ @RPTPadCountTag + '%' or V.test_name ='ProductionCNT')  
  AND V.DATA_Type_ID IN(1,2)  
   
UPDATE TPL Set CompPadCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type = 1  
  AND (V.test_name Like '%'+ @RPTPadCountTag + '%' or V.test_name ='ProductionCNT' )  
  AND V.DATA_Type_ID IN(1,2)  
  
-- UPDATE TPL Set Class = 3 FROM #PLIDList TPL WHERE CompPadCountVarID is not null  
  
UPDATE TPL Set PartCaseCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pu_id = tpl.convunit  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON V.PU_ID = pu.pu_id  
  AND V.Event_Type IN(0,5)  
  AND (v.extended_info like '%PRCaseCount%' AND v.user_defined1 = 'Class'+@RPT_CaseCountClass )  
  AND V.DATA_Type_ID IN(1,2)  
  
-- Get Complete Case Counter  
UPDATE TPL Set CompCaseCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pu_id = tpl.convunit  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON V.PU_ID = pu.pu_id  
  AND V.Event_Type = 1  
  AND (v.extended_info like '%PRCaseCount%' AND v.user_defined1 = 'Class'+@RPT_CaseCountClass )  
  AND V.DATA_Type_ID IN(1,2)  
  
--****************************************************************************************************   
-- Step 3 : Get the partial case counter  
-- If the Partial Case Counter user_defined2 field like 'UseCaseCount' the use CaseCount for GoodPads  
  
UPDATE TPL Set PartRunCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConvUnit = V.PU_ID  
  AND V.Event_Type IN(0,5)  
  AND V.test_name Like '%'+ @RPTRunCountTag + '%'  
  AND V.DATA_Type_ID IN(1,2)  
  
UPDATE TPL Set CompRunCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type = 1  
  AND V.test_name Like '%'+ @RPTRunCountTag + '%'  
  AND V.DATA_Type_ID IN(1,2)  
  
UPDATE TPL Set CompStartUPCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type = 1  
  AND V.test_name Like '%'+ @RPTStartUPCountTag + '%'  
  AND V.DATA_Type_ID IN(1,2)  
  
UPDATE TPL Set PartStartUPCountVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type IN(0,5)  
  AND V.test_name Like '%'+ @RPTStartUPCountTag + '%'  
  AND V.DATA_Type_ID IN(1,2)  
  
UPDATE TPL Set PartSpeedTargetVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type in ( 0,5)  
  AND v.test_name = @RPTConvertERSpeedTag  
  AND V.DATA_Type_ID IN(1,2)  
  
UPDATE TPL Set CompSpeedTargetVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Event_Type = 1  
  AND v.test_name = @RPTConvertERSpeedTag   
  AND V.DATA_Type_ID IN(1,2)  
  
UPDATE TPL Set REDowntimeVarID = VAR_ID  
 FROM #PLIDList TPL  
 JOIN dbo.Variables_Base V WITH(NOLOCK) ON TPL.ConVUnit = V.PU_ID  
  AND V.Extended_Info Like '%'+ @RPTDowntimeTag  
  
--****************************************************************************************************  
-- END BUILD the #PLIDList Table  
--****************************************************************************************************  
--Select '#PLIDList', * FROM #PLIDList  
------------------------------------------------------------------------------------------------------  
-- FRio New code for Flex Variables  
--Print convert(varchar(25), getdate(), 120) + 'Flex Variables'  
------------------------------------------------------------------------------------------------------  
  
Declare   
 @k as int,  
 @Flex_param as nvarchar(100),  
 @u as varchar(100),  
 @v as varchar(100),   @rows_no as int,  
 @SQLunit as nvarchar(100)   
  
Set @k = 1  
  
While @k < 11  
Begin  
  
 -- Aqui hay que hacer un Split para quedarme con la Unidad del parametro  
 -- Si el | no esta en la variable entonces asumo que es la convertidora   
 Set @Flex_param = null  
  
 Set @Flex_param = (Select value FROM #Params   
  WHERE param = 'dpr_flexible_variable_' + convert(varchar,@k))    
  
 Insert Into #FlexParam (Temp1,Temp2)  
 Exec SPCMN_ReportCollectionParsing  
   @PRMCollectionString = @Flex_param, @PRMFieldDelimiter = null, @PRMRecordDelimiter = '|',   
   @PRMDataType01 = 'varchar(100)'  
   
 Select @rows_no = count(*) FROM #FlexParam  
 If @rows_no = 2    
 Begin  
  Set @u = (Select Temp2 FROM #FlexParam WHERE Temp1 = 1)  
  Set @v = (Select Temp2 FROM #FlexParam WHERE Temp1 = 2)  
 End  
 Else  
  Set @v = (Select Temp2 FROM #FlexParam WHERE Temp1 = 1)  
  
  
 Set @SQLString = ' UPDATE TPL set flex' + convert(varchar,@k)  + ' = v.var_id ' +  
           ' FROM dbo.Variables_Base v WITH(NOLOCK) ' +  
           ' JOIN #PLIDList TPL ON v.pu_id = TPL.ConvUnit ' +  
                 ' JOIN dbo.Prod_Units_Base pu ON pu.pu_id = TPL.ConvUnit ' +  
                 ' WHERE pu.Pu_Desc Like ''' + '%' + @u  + '%' + '''' +  
           ' AND v.var_desc = ''' + @v + ''''   
  
 Exec(@SQLString)   
    
 Set @SQLString = ' UPDATE #Params set value = ''' + @v + '''' +  
           ' WHERE param = ''' + 'DPR_flexible_variable_' + convert(varchar,@k) + ''''  
  
 Exec(@SQLString)  
  
 Set @k = @k + 1  
 Truncate Table #FlexParam  
  
End  
  
Delete FROM @ColumnVisibility WHERE VariableName Like 'Flexible_Variable_%' AND  
VariableName Not In (  
Select SubString(Param,5,Len(Param)-4) FROM #Params WHERE param like 'DPR_Flexible_Variable_%' AND Len(Value) > 1)  
  
------------------------------------------------------------------------------------------------------  
-- End Flex Variables  
------------------------------------------------------------------------------------------------------  
--*******************************************************************************************************  
-- Start building Products Table  
--Print convert(varchar(25), getdate(), 120) + ' Build @Products Table'  
--*******************************************************************************************************  
  
Insert Into @Products(PU_ID ,Prod_ID,Prod_Code,Prod_Desc,Product_Size,StartTime,EndTime)  
Select PU_ID,P.Prod_ID,Prod_Code,Prod_Desc,'',start_Time as StartTime,End_Time as EndTime  
 FROM dbo.Production_Starts Ps WITH(NOLOCK)      
 JOIN #PLIDList pl ON ps.pu_id = pl.convUnit  
    JOIN dbo.Products_Base P WITH(NOLOCK) ON PS.Prod_ID = P.Prod_ID      
        WHERE  
          Ps.Start_Time <= @EndDateTime AND  
            (Ps.End_Time > @StartDateTime or PS.End_TIME IS null)  
  
-- This statement avoid same product that belongs to different sizes to cause duplicated entries  
UPDATE @Products   
 Set Product_Size = pg.Product_Grp_Desc  
FROM @Products p  
JOIN dbo.Product_Group_Data pgd WITH(NOLOCK) ON pgd.Prod_Id = P.Prod_Id  
JOIN dbo.Product_Groups pg WITH(NOLOCK) ON pgd.product_grp_id = pg.product_grp_id  
   
Insert Into @RE_Specs (Spec_Id,Spec_Desc)  
Select spec_id,spec_desc  
FROM Specifications   
WHERE Prop_Id = (Select Prop_Id   
    FROM Product_Properties WHERE Prop_Desc = 'RE_Product Information')  
  
INSERT INTO @Product_Specs (Prod_Code,  
       Prod_Desc,  
       Spec_Id,  
       Spec_Desc,  
       Target)  
Select Distinct    p.Prod_Code,  
       p.Prod_Desc,  
       rs.Spec_Id,  
       rs.Spec_Desc,  
       ass.Target   
  
FROM @Products p  
LEFT JOIN dbo.Characteristics c WITH(NOLOCK) ON (c.Char_Desc Like '%' + P.Prod_Code + '%'  
             OR c.Char_Desc = P.Prod_Desc)  
        AND c.Prop_Id = @SpecPropertyId  
LEFT JOIN Active_Specs ass WITH(NOLOCK) ON c.char_id = ass.char_id  
LEFT JOIN @RE_Specs rs ON ass.Spec_Id = rs.Spec_Id   
WHERE ass.Expiration_Date Is Null   
--------------------------------------------------------------------------------------------------------  
  
--*******************************************************************************************************  
-- Start building LineStatus Table  
--Print convert(varchar(25), getdate(), 120) + ' Build @LineStatus Table'  
--*******************************************************************************************************  
Insert Into @LineStatus (
			PU_ID,
			Phrase_Value,
			StartTime,
			EndTime)  
	Select	DISTINCT 
			Unit_ID,
			Phrase_Value,
			Start_DateTime, 
			End_DateTime
		FROM dbo.Local_PG_Line_Status	LPG		WITH(NOLOCK)  
        JOIN #PLIDList					plid	ON LPG.Unit_Id = plid.ScheduleUnit -- plid.ConvUnit  
		LEFT JOIN dbo.Phrase			PHR		WITH(NOLOCK) ON LPG.Line_Status_ID = PHR.Phrase_ID  
		WHERE LPG.Start_DateTime <= @EndDateTime 
			AND  (LPG.End_DateTime > @StartDateTime or LPG.End_DateTime IS null)  
			AND UPDATE_status <> 'DELETED'  

--*******************************************************************************************************  
-- Start building Crew Schedule Table  
--Print convert(varchar(25), getdate(), 120) + ' Building @Crew_Schedule Table'  
--*******************************************************************************************************  
Insert Into @Crew_Schedule (
			StartTime,
			EndTime,
			Pu_id,
			Crew,
			Shift)  
	Select	DISTINCT 
			Start_Time, 
			End_Time, 
			Pu_id, 
			Crew_Desc , 
			Shift_Desc 
	FROM dbo.Crew_Schedule	cs WITH(NOLOCK)  
	JOIN #PLIDList			pl ON cs.pu_id = pl.ScheduleUnit -- pl.ConvUnit  
	WHERE Start_Time <= @EndDateTime   
		AND (End_Time > @StartDateTime)  

-- JPG
-- Select '#PLIDList', * FROM #PLIDList  
-- Select '@Crew_Schedule', * FROM @Crew_Schedule ORDER BY StartTime
--  
------------------------------------------------------------------------------------------------------  
-- String Parsing: Shift DESC, If ALL  
--Print convert(varchar(25), getdate(), 120) + 'String Parsing: Shift DESC'  
------------------------------------------------------------------------------------------------------  
  
If  @RPTShiftDESCList = '!null'  OR @RPTShiftDESCList  = ''
Begin  
 Set @ShiftDESCList = @lblAll  
 --  
 Insert #ShiftDESCList (ShiftDESC)  
  Select Distinct CS.Shift  
  FROM #PLIDList TPL  
  JOIN @Crew_Schedule CS ON tpl.convunit = CS.PU_ID  
  WHERE Crew <> 'No Team'   
End  
Else  
Begin  
 Insert #ShiftDESCList (RCDID,ShiftDESC)  
  Exec SPCMN_ReportCollectionParsing  
  @PRMCollectionString = @RPTShiftDESCList, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',  
  @PRMDataType01 = 'varchar(50)'  
  
 Select @ShiftDESCList = @RPTShiftDESCList  
End  
   
------------------------------------------------------------------------------------------------------  
-- String Parsing: Crew(Team) DESC, If All  Use the word Crew to map to Prof  
--Print convert(varchar(25), getdate(), 120) + 'String Parsing: Crew DESC'  
------------------------------------------------------------------------------------------------------  
If  @RPTCrewDESCList = '!null'  OR @RPTCrewDESCList = ''
Begin  
 Set @CrewDESCList = @lblAll  
 --  
 	Insert #CrewDESCList (CrewDESC)  
		SELECT DISTINCT cs.Crew
			FROM #PLIDList		TPL  
			JOIN @Crew_Schedule cs	ON	tpl.convunit = CS.PU_ID	
									AND cs.Crew Is Not NULL  
			WHERE cs.Crew <> 'No Team'   

End  
Else  
Begin  
  
 Insert #CrewDESCList (RCDID,CrewDESC)  
  Exec SPCMN_ReportCollectionParsing  
  @PRMCollectionString = @RPTCrewDESCList, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',  
  @PRMDataType01 = 'varchar(50)'  
  
 Select @CrewDESCList = @RPTCrewDESCList  
End  
  
  
------------------------------------------------------------------------------------------------------  
-- String Parsing: Line Status DESC, If All   
--Print convert(varchar(25), getdate(), 120) + 'String Parsing: Line Status DESC'  
------------------------------------------------------------------------------------------------------  
  
If  @RPTPLStatusDESCList = 'All' or @RPTPLStatusDESCList = '!Null'  
Begin  
 Set @PLStatusDESCList = @lblAll  
 --  
 Insert #PLStatusDESCList (PLStatusDESC)  
  Select distinct Phrase_Value  
  FROM @LineStatus  
  
--	select 'PLStatusDESCList', * from #PLStatusDESCList

End  
Else  
Begin  
 Insert #PLStatusDESCList (RCDID, PLStatusDESC)  
  Exec SPCMN_ReportCollectionParsing  
  @PRMCollectionString = @RPTPLStatusDESCList, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',   
  @PRMDataType01 = 'varchar(50)'  
  
 Select @PLStatusDESCList = @RPTPLStatusDESCList  
End  
  

-----------------------------------------------------------------------------------------------------  
-- Preparing Output Tables for PIVOT:   
-----------------------------------------------------------------------------------------------------  
-- Get Data: Production  
--*****************************************************************************************************  
-- Print convert(varchar(25), getdate(), 120) + ' Get Production Data'
-- Get the Events for the Hybird PE Configuration  
-- NewPE  
-- Now the events has Start Time so add it:
INSERT #Production  (		
			EventId		,
			StartTime	,
			EndTIME		, 
			PLID		, 
			pu_id		, 
			TypeOfEvent	,
			HybridConf )  
	SELECT	DISTINCT
			e.Event_Id	, 
			CASE WHEN ISNULL(Start_Time,@StartDATETIME) < @StartDATETIME
				THEN @StartDATETIME
				ELSE ISNULL(Start_Time,@StartDATETIME)
			END,
			CASE WHEN TimeStamp <= @EndDATETIME 
				THEN TimeStamp
				ELSE @EndDATETIME
			END,
			TPL.PLID	,
			e.pu_id		, 
			'Complete'  ,
			'Yes'
	FROM dbo.Events E WITH(NOLOCK)  
	JOIN #PLIDList TPL ON TPL.ConvUnit = E.PU_ID  
	--  FO-03394 changed conditions for timestamp ad start_time of events to be considered 
	--=====================================
		 --AND Timestamp >= @StartDATETIME  
		 --AND Start_Time <= @EndDATETIME 
		 AND Timestamp > @StartDATETIME  
		 AND Start_Time < @EndDATETIME 
	--==========================================
		 AND Start_Time IS NOT NULL 
		 		 
-- Get Events for non Hybrid lines:
INSERT #Production  (		
			EventId		,
			StartTime	,
			EndTIME		, 
			PLID		, 
			pu_id		, 
			TypeOfEvent	,
			HybridConf )  
	SELECT	DISTINCT
			e.Event_Id	, 
			NULL		,
			CASE WHEN TimeStamp <= @EndDATETIME 
				THEN TimeStamp
				ELSE @EndDATETIME
			END,
			TPL.PLID	,
			e.pu_id		, 
			'Complete'  ,
			'No'
	FROM dbo.Events E WITH(NOLOCK)  
	JOIN #PLIDList TPL ON TPL.ConvUnit = E.PU_ID  
		 AND TimeStamp >= @StartDATETIME  
		 AND TimeStamp <= @EndDATETIME  
		 AND Start_Time IS NULL
--
-- 
INSERT #Production (
			pu_id, 
			PLID, 
			StartTIME, 
			EndTime, 
			TypeOfEvent,
			HybridConf)  
	Select	p.pu_id,
			tpl.PLID,
			@EndDateTime,
			@EndDateTime,
			'Partial',
			'Yes' 
	FROM #Production	p  
	JOIN #PLIDList		TPL ON TPL.ConvUnit = p.PU_ID  
	JOIN (	Select	PU_Id,
					Max(EndTime) as EndTime 
			FROM #Production 
			group by pu_id) as met 
							ON met.pu_id = p.pu_id 
							AND met.EndTime = p.EndTime  
	WHERE met.EndTime != @EndDateTime  

 
-- 'NoEvent' Scenario  
Insert #Production (pu_id, PLID, StartTIME, EndTime, TypeOfEvent,HybridConf)  
	Select TPL.ConvUnit,TPL.PLID,@StartDateTime,@EndDateTime,'Partial','Yes' FROM #PLIDList TPL  
	LEFT JOIN #Production P ON TPL.ConvUnit = P.pu_id  
	WHERE P.ID Is Null  
 
 
--Print convert(varchar(25), getdate(), 120) + ' Get Production Start Data '  
 -- FDR Only do this for NON Hybrid Lines
Declare ProductionStart INSENSITIVE Cursor For  
 (Select ID, EndTIME, pu_id  
    FROM #Production
	--WHERE HybridConf = 'No'
	)  
    For Read Only  
  
Open ProductionStart  
  
FETCH NEXT FROM ProductionStart into @Id, @EndTime, @PU_Id  
  
While @@Fetch_Status = 0  
Begin  
 Set @StartTime = null  
 
 SELECT @StartTime = Max(EndTime)  
  FROM #Production P WITH(NOLOCK)   
  WHERE p.pu_id = @PU_Id  
   AND p.EndTime < @EndTime
    
  UPDATE #Production  
   Set StartTIME = @StartTime  
  WHERE ID = @Id
  -- fdr
  AND StartTime IS NULL
    
 --  
 Fetch Next FROM ProductionStart into @Id, @EndTime, @PU_Id  
End  
Close ProductionStart  
Deallocate ProductionStart  



  
Delete FROM #Production WHERE NOT (EndTime >= @StartDATETIME  
  and EndTime <= @EndDATETIME)  
  
UPDATE #Production   
  Set StartTime = @StartDATETIME,  
   TypeOfEvent = 'Partial'  
WHERE StartTIme Is NULL  


-- Delete non-sense Production Events:
DELETE FROM #Production 
	WHERE NOT (EndTime >= @StartDATETIME  
		AND EndTime <= @EndDATETIME)  

DELETE FROM #Production 
	WHERE StartTIME = EndTIME 
--
--Print convert(varchar(25), getdate(), 120) + ' End Get Production Start Data '  

----------------------------------------------------------------------------------------------------  
-- Compute FLEX VARIABLES  
----------------------------------------------------------------------------------------------------  
  
set @k = 1  
  
while @k < 11  
begin  
 select @param=value FROM #Params WHERE param='DPR_Flexible_variable_' + convert(varchar,@k)  
 if @param<>''  
 begin   
  
 set @SQLString = ' UPDATE #Production Set flex' + convert(varchar,@k) + '= ' +  
      '(select Sum(CONVERT(float, T.RESULT)) FROM #PLIDList TPL ' +  
                         ' JOIN Variables v ON v.var_id = ' + 'TPL.Flex'+ convert(varchar,@k) + ' AND v.pu_id = TPT.PU_id ' +  
    --' LEFT JOIN dbo.TESTS T WITH (INDEX(Test_By_Variable_And_Result_On),NOLOCK) ON  T.VAR_ID = ' + 'TPL.Flex'+ convert(varchar,@k) +    (Commented for FO-02506 and added next LOC)
	' LEFT JOIN dbo.TESTS T WITH (NOLOCK) ON  T.VAR_ID = ' + 'TPL.Flex'+ convert(varchar,@k) + 
    ' AND T.Result_on > TPT.StartTime AND T.RESULT_on <= TPT.EndTIME AND T.Canceled <> 1) ' +  
     ' FROM #Production tpt ' +  
    ' JOIN #PLIDList tpl ON tpt.pu_id = tpl.ConvUnit '   

	exec(@SQLString)  
 end  
 set @k = @k + 1  
end  
  
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
--	Split by @Crew_Schedule
--  This splits needs to be done only if the Configuration is an HybridConfiguration !!!!!!!!!!!!!!!!!!!!!!!!!!
---------------------------------------------------------------------------------------------------------------
-- aca JPG
--select '@Crew_Schedule', * from @Crew_Schedule ORDER BY StartTime

UPDATE tpt SET tpt.SplitCrew = 1
	FROM #Production	tpt
	JOIN #PLIDList		TPL ON tpt.Pu_ID = TPL.ConvUnit  
	JOIN @Crew_Schedule	cs1	ON tpl.ScheduleUnit = cs1.PU_ID  
							AND tpt.StartTime >= cs1.StartTime 
							AND tpt.StartTime < cs1.EndTime
	WHERE HybridConf = 'Yes'

UPDATE tpt SET tpt.SplitCrew = 1
	FROM #Production	tpt
	JOIN #PLIDList		TPL ON tpt.Pu_ID = TPL.ConvUnit 	
	JOIN @Crew_Schedule	cs2	ON tpl.ScheduleUnit = cs2.PU_ID
							AND cs2.StartTime > tpt.StartTime
							AND cs2.EndTime <= tpt.EndTime
WHERE HybridConf = 'Yes'

-- Insert new records in #Production from the Splits by Crew
Insert into #Production (
			pu_id, 
			PLID, 
			StartTIME, 
			EndTime, 
			EventId,
			TypeOfEvent, 
			Crew, 
			Shift, 
			ParentIdCrew,
			HybridConf )  
	SELECT	DISTINCT 
			tpt.pu_id, 
			tpt.plid, 
			CASE WHEN cs.StartTime > tpt.StartTime 
				THEN cs.StartTime 
				ELSE tpt.StartTime 
			END,
			CASE WHEN cs.EndTime < tpt.EndTime 
				THEN cs.EndTime 
				ELSE tpt.EndTime 
			END, 
			tpt.EventId,
			tpt.TypeOfEvent, 
			cs.Crew, 
			cs.Shift, 
			tpt.Id,
			'Yes'
	FROM #Production	tpt
	JOIN #PLIDList		TPL ON tpt.Pu_ID = TPL.ConvUnit  
	JOIN @Crew_Schedule	cs	ON tpl.ScheduleUnit = cs.PU_ID  
							AND (((tpt.StartTime BETWEEN cs.StartTime AND cs.EndTime) 
									OR (tpt.EndTime BETWEEN cs.StartTime AND cs.EndTime)
									OR (cs.StartTime >= tpt.StartTime AND cs.EndTime < tpt.EndTime)))
	WHERE tpt.SplitCrew = 1
		
-- Delete rows with the same time
DELETE FROM #Production 
	WHERE StartTIME = EndTIME 

-- Delete records in #Production
DELETE FROM #Production	
	WHERE SplitCrew = 1 

---------------------------------------------------------------------------------------------------------------
--	Update #Production
----------------------------------------------------------------------------------------------------  
UPDATE #Production  
	SET Crew = CS.Crew,   
		Shift = CS.Shift  
	FROM #Production	TPT  
	JOIN #PLIDList		TPL ON tpt.Pu_ID = TPL.ConvUnit  
	JOIN @Crew_Schedule cs	ON tpl.ScheduleUnit = cs.PU_ID  
							AND tpt.EndTime > cs.StartTime   
							AND (tpt.EndTime <= cs.EndTime or cs.EndTime IS null)  

---------------------------------------------------------------------------------------------------------------
--	Split by Line Status
---------------------------------------------------------------------------------------------------------------
-- aca JPG
--Select '@LineStatus', * FROM @LineStatus ORDER BY StartTime
--SELECT '#Production',* FROM #Production ORDER BY PU_Id,StartTime
--SELECT '@Products',* FROM @Products

--SELECT 'Production LS-Splits', ls1.RcID, ls1.StartTime, ls1.EndTime, Ls2.RcID, tpt.id, tpt.Pu_ID, TPT.StartTime, TPT.EndTime
--	FROM #Production	TPT  
--	JOIN #PLIDList		TPL	ON tpt.Pu_ID = TPL.ConvUnit  
--	JOIN @Products		PS	ON ps.pu_id = tpt.pu_id   
--							AND tpt.EndTime >= ps.StartTime   
--							AND (tpt.EndTime < ps.EndTime or ps.EndTime IS Null)  
--	JOIN @LineStatus	Ls1	ON TPL.scheduleUnit = Ls1.PU_ID  
--							AND TPT.StartTime > Ls1.StartTime   
--							AND (TPT.StartTime <= Ls1.EndTime or Ls1.EndTime IS null)   
--	JOIN @LineStatus	Ls2	ON TPL.scheduleUnit = Ls2.PU_ID  
--							AND TPT.EndTime > Ls2.StartTime   
--							AND (TPT.EndTime <= Ls2.EndTime or Ls2.EndTime IS null)   
--	WHERE Ls1.RcID <> Ls2.RcID


UPDATE tpt SET tpt.SplitLS = 1
	FROM #Production	TPT  
	JOIN #PLIDList		TPL	ON tpt.Pu_ID = TPL.ConvUnit  
	JOIN @Products		PS	ON ps.pu_id = tpt.pu_id   
							AND tpt.EndTime >= ps.StartTime   
							AND (tpt.EndTime < ps.EndTime or ps.EndTime IS Null)  
	JOIN @LineStatus	Ls1	ON TPL.scheduleUnit = Ls1.PU_ID  
							AND TPT.StartTime > Ls1.StartTime   
							AND (TPT.StartTime <= Ls1.EndTime or Ls1.EndTime IS null)   
	JOIN @LineStatus	Ls2	ON TPL.scheduleUnit = Ls2.PU_ID  
							AND TPT.EndTime > Ls2.StartTime   
							AND (TPT.EndTime <= Ls2.EndTime or Ls2.EndTime IS null)   
	WHERE Ls1.RcID <> Ls2.RcID
	AND HybridConf = 'Yes'

-- Insert new records in #Production from the Splits by Line Status
Insert into #Production (
			StartTIME, 
			EndTime, 
			PLID, 
			pu_id, 
			Crew, 
			Shift, 
			EventId,
			TypeOfEvent, 
			ParentIdLs,
			HybridConf )  
	select	DISTINCT 
			CASE WHEN cs.StartTime > tpt.StartTime 
				THEN cs.StartTime 
				ELSE tpt.StartTime 
			END,
			CASE WHEN cs.EndTime < tpt.EndTime 
				THEN cs.EndTime 
				ELSE tpt.EndTime 
			END, 
			tpt.plid, 
			tpt.pu_id, 
			tpt.Crew, 
			tpt.Shift, 
			tpt.EventId,
			tpt.TypeOfEvent, 
			tpt.Id	,
			'Yes'
	FROM #Production	TPT  
	JOIN #PLIDList		TPL	ON tpt.Pu_ID = TPL.ConvUnit  
	JOIN @Products		PS	ON ps.pu_id = tpt.pu_id   
							AND tpt.EndTime >= ps.StartTime   
							AND (tpt.EndTime < ps.EndTime or ps.EndTime IS Null)  
	JOIN @LineStatus	cs	ON tpl.ScheduleUnit = cs.PU_ID  
							AND (((tpt.StartTime BETWEEN cs.StartTime AND cs.EndTime)  -- FO-02740 added "("
								OR (tpt.EndTime BETWEEN cs.StartTime AND cs.EndTime)
								OR (cs.StartTime >= tpt.StartTime AND cs.EndTime < tpt.EndTime)) 
								--OR (cs.StartTime >= tpt.StartTime AND (cs.EndTime < tpt.EndTime OR cs.Endtime IS NULL))	)--FO-02307
								OR ((cs.StartTime BETWEEN tpt.startTime and tpt.EndTime) and cs.EndTime IS NULL ))	-- FO-02558  --FO-02740 added ")"
	WHERE tpt.SplitLS = 1

-- Delete rows with the same time
DELETE FROM #Production 
	WHERE StartTIME = EndTIME 

--SELECT 'To Split by LS', * FROM #Production 
--	WHERE SplitLS = 1 

-- Delete records in #Production
DELETE FROM #Production	
	WHERE SplitLS = 1 

--SELECT * FROM #Production 
--	WHERE ParentIdLs is not null
--	ORDER BY PU_ID, starttime	

UPDATE #Production  
	SET Product		= PS.Prod_Code   ,   
		Product_Size= PS.Product_Size ,  
		IdealSpeed	= spec2.Target  ,  
		LineStatus	= LPG.Phrase_Value ,   
		ProdPerStat = spec.Target   
	 FROM #Production			TPT  
	 JOIN #PLIDList				TPL		ON tpt.Pu_ID = TPL.ConvUnit  
	 JOIN @Products				PS		ON ps.pu_id = tpt.pu_id   
										AND tpt.EndTime >= ps.StartTime   
										AND (tpt.EndTime < ps.EndTime or ps.EndTime IS Null)  
	 JOIN @LineStatus			LPG		ON TPL.scheduleUnit = LPG.PU_ID  
										AND TPT.EndTime > LPG.StartTime   
										AND (TPT.EndTime <= LPG.EndTime or LPG.EndTime IS null)   
	 LEFT JOIN @Product_Specs	spec	ON PS.prod_code = spec.prod_code 
										AND spec.spec_id = @PadsPerStatSpecId  
	 LEFT JOIN @Product_Specs	spec2	ON PS.prod_code = spec2.prod_code 
										AND spec2.spec_id = @IdealSpeedSpecID  
  
UPDATE #Production  
	Set	TotalPad	=  cast(CONVERT(float, TPad.RESULT)as bigint),  
		RunningScrap= CONVERT(float, TRun.RESULT),  
		Stopscrap	= CONVERT(float, TSTOP.RESULT),  
		LineSpeedTAR= CONVERT(float, TSpeed.RESULT)   --,  
        --TotalCases =  cast(CONVERT(float, TCases.RESULT)as bigint),  
        --CaseCount = cast(CONVERT(float, TCases.RESULT)as bigint)  
	FROM #Production	TPT  
	JOIN #PLIDList		TPL		ON tpt.Pu_ID = TPL.ConvUnit  
	LEFT JOIN dbo.TESTS TRun	WITH(NOLOCK) 
								ON TPL.CompRunCountVarID = TRun.VAR_ID  
								AND TRun.RESULT_on = TPT.EndTIME AND TRun.Canceled <> 1  
	LEFT JOIN dbo.TESTS TSTOP	WITH(NOLOCK)  
								ON TPL.CompStartUPCountVarID = TSTOP.VAR_ID  
								AND TSTOP.RESULT_on = TPT.EndTIME AND TStop.Canceled <> 1  
	LEFT JOIN dbo.TESTS TSpeed	WITH(NOLOCK)   
								ON TPL.CompSpeedTargetVarID = TSpeed.VAR_ID  
								AND TSpeed.RESULT_on = TPT.EndTIME AND TSpeed.Canceled <> 1  
	LEFT JOIN dbo.TESTS TPad	WITH(NOLOCK)  
								ON tpl.CompPadCountVarID = TPad.VAR_ID  
								AND TPad.RESULT_on = tpt.EndTIME AND TPad.Canceled <> 1  
	LEFT JOIN dbo.TESTS TCases	WITH (NOLOCK) 
								ON tpl.CompCaseCountVarID = TCases.VAR_ID  
								AND TCases.RESULT_on = tpt.EndTIME AND TCases.Canceled <> 1  
	WHERE TypeOfEvent = 'Complete'  
	--FDR : Do this for all the configurations now
	--AND HybridConf = 'No'


--SELECT 'TotalPad', TPad.VAR_ID, v.var_desc, TPad.RESULT_on, cast(CONVERT(float, TPad.RESULT)as bigint) TotalPad, *
--	FROM #Production	TPT  
--	JOIN #PLIDList		TPL		ON tpt.Pu_ID = TPL.ConvUnit  
--	JOIN dbo.Variables_Base	v		WITH(NOLOCK)	ON tpl.CompPadCountVarID = V.VAR_ID
--	JOIN dbo.TESTS		TPad	WITH(NOLOCK)  
--								ON tpl.CompPadCountVarID = TPad.VAR_ID  
--								AND TPad.RESULT_on = tpt.EndTIME 
--								AND TPad.Canceled <> 1  
--	WHERE TypeOfEvent = 'Complete'  
--	AND TPT.PU_ID = 754


UPDATE #Production  
	SET Product		= PS.Prod_Code   ,   
        Product_Size= PS.Product_Size ,  
		IdealSpeed	= spec2.Target  ,  
		LineStatus	= LPG.Phrase_Value ,   
		ProdPerStat = spec.Target   
	FROM #Production	TPT  
	JOIN #PLIDList		TPL ON tpt.Pu_ID = TPL.ConvUnit  
	JOIN @Products		PS	ON ps.pu_id = tpt.pu_id   
							AND tpt.EndTime >= ps.StartTime   
							AND (tpt.EndTime < ps.EndTime or ps.EndTime IS Null)  
	JOIN @LineStatus	LPG ON TPL.scheduleUnit = LPG.PU_ID  
							AND TPT.EndTime > LPG.StartTime   
							AND (TPT.EndTime <= LPG.EndTime or LPG.EndTime IS null)   
	LEFT JOIN @Product_Specs	spec	ON PS.prod_code = spec.prod_code 
										AND spec.spec_id = @PadsPerStatSpecId  
	LEFT JOIN @Product_Specs	spec2	ON PS.prod_code = spec2.prod_code 
										AND spec2.spec_id = @IdealSpeedSpecID  
  
--SELECT * FROM #Production where StartTime = EndTime ORDER BY PU_ID, starttime		
--SELECT * FROM #Production ORDER BY PU_ID, starttime		

---------------------------------------------------------------------------------------------  
-- SELECT '#PLIDList',* FROM #PLIDList
-- Make this for both Configuration Types:
-- FDR Commented out the HybridConf Statement
UPDATE #Production  
		 Set     TotalCases =  CAST(CONVERT(FLOAT, TCases.RESULT)as bigint),  
				 CaseCount = CAST(CONVERT(FLOAT, TCases.RESULT)as bigint)  
FROM #Production TPT  
JOIN #PLIDList TPL ON tpt.Pu_ID = TPL.ConvUnit  
LEFT JOIN dbo.TESTS TCases WITH (NOLOCK) ON tpl.CompCaseCountVarID = TCases.VAR_ID  
							AND TCases.RESULT_on = tpt.EndTIME AND TCases.Canceled <> 1  
WHERE TypeOfEvent = 'Complete'  
-- AND HybridConf = 'No'

---------------------------------------------------------------------------------------------  
-- FRio, replaced code for make complete events FROM partial events  
---------------------------------------------------------------------------------------------  
  
Insert Into @Make_Complete (pu_id,start_time)  
Select pu_id,MIN(StartTime) FROM #Production  
Group by pu_id  
  
UPDATE @Make_Complete  
        Set end_time = (Select MIN(EndTime) FROM #Production WHERE pu_id = mc.pu_id)  
FROM @Make_Complete mc  
  
UPDATE @Make_Complete  
        Set next_start_time = (Select MIN(EndTime) FROM #Production   
                               WHERE PU_ID = mc.pu_id AND EndTime > mc.Start_Time)  
FROM @Make_Complete mc  
  
UPDATE #Production  
        Set TypeofEvent = 'Complete'  
FROM #Production p  
JOIN @Make_Complete mc ON p.pu_id = mc.pu_id AND p.StartTime = mc.start_time  
WHERE mc.start_time = mc.next_start_time AND mc.next_start_time Is Not NULL  
  
-- Select * FROM @Make_Complete  
---------------------------------------------------------------------------------------------  
-- Avoid cursor below, get rid of Complete events, use only partials  
-- FDR : Comment out the TypeOfEvent, should not override the HybridConf
Select ID, pu_id, TPL.PLID,StartTIME, EndTIME, PartPadCountVarID,PartCaseCountVarID,  
  PartRunCountVarID,PartStartUPCountVarID,PartSpeedTargetVarID  
into #tcur_PartProd  
FROM #Production  P   
JOIN #PLIDList TPL ON TPL.ConvUnit = P.PU_id   
WHERE TypeOfEvent = 'Partial'  
--OR (TypeOfEvent = 'Complete' AND HybridConf = 'Yes')

--Select * FROM #tcur_PartProd  
  
-- PartPadCountVarID  
Truncate Table #Temporary  
Insert into #Temporary (TEMPValue1,TEMPValue2)  
Select  ID,Sum(CONVERT(float, RESULT))  
   FROM dbo.TESTS T WITH(NOLOCK) -- WITH (INDEX(Test_By_Variable_And_Result_On),NOLOCK)  
   JOIN #tcur_PartProd PP ON PP.PartPadCountVarID = T.Var_id  
   AND T.RESULT_on > PP.StartTIME  
   AND T.RESULT_on <= PP.EndTIME  
   WHERE Canceled <> 1  
Group by ID  

  
UPDATE #Production  
	SET TotalPad = t.TEMPValue2  
	FROM #Production P JOIN #Temporary t ON p.id = t.TEMPValue1  

---------------------------------------------------------------------------------------------------------------------------------------
-- PartCaseCountVarID 

--select 'DBVersion 5.x'
Truncate Table #Temporary  
Insert into #Temporary (TEMPValue1,TEMPValue2)  
Select  ID,Sum(CONVERT(float, RESULT))  
FROM dbo.Tests T WITH(NOLOCK) -- WITH (INDEX(Test_By_Variable_And_Result_On),NOLOCK)  
   JOIN #tcur_PartProd PP ON PP.PartCaseCountVarID = T.Var_id  
   AND T.RESULT_on > PP.StartTIME  
   AND T.RESULT_on <= PP.EndTIME  
WHERE Canceled <> 1  
Group By ID  


UPDATE #Production  
		 SET TotalCases = t.TEMPValue2,  
			 CaseCount  = t.TEMPValue2  
FROM #Production P JOIN #Temporary t ON p.id = t.TEMPValue1  


---------------------------------------------------------------------------------------------------------------------------------------
  
-- PartRunCountVarID  
TRUNCATE table #Temporary  
Insert into #Temporary (TEMPValue1,TEMPValue2)  
Select  ID,Sum(CONVERT(float, RESULT))  
   FROM dbo.Tests T WITH(NOLOCK) --WITH (INDEX(Test_By_Variable_And_Result_On),NOLOCK)  
   JOIN #tcur_PartProd PP ON PP.PartRunCountVarID = T.Var_id  
   AND T.RESULT_on > PP.StartTIME  
   AND T.RESULT_on <= PP.EndTIME  
   WHERE Canceled <> 1  
group by ID  
  
UPDATE #Production  
 Set RunningScrap = t.TEMPValue2  
FROM #Production P JOIN #Temporary t ON p.id = t.TEMPValue1  
  
-- PartStartUpCountVarID  
TRUNCATE table #Temporary  
Insert into #Temporary (TEMPValue1,TEMPValue2)  
Select  ID,Sum(CONVERT(float, RESULT))  
   FROM dbo.Tests T WITH(NOLOCK) -- WITH (INDEX(Test_By_Variable_And_Result_On),NOLOCK)  
   JOIN #tcur_PartProd PP ON PP.PartStartUpCountVarID = T.Var_id  
   AND T.RESULT_on > PP.StartTIME  
   AND T.RESULT_on <= PP.EndTIME  
   WHERE Canceled <> 1  
Group By Id  
  
UPDATE #Production  
 Set StopScrap = t.TEMPValue2  
FROM #Production P JOIN #Temporary t ON p.id = t.TEMPValue1  
  
-- PartSpeedTargetVarID  
TRUNCATE table #Temporary  
Insert into #Temporary (TEMPValue1,TEMPValue2)  
Select  ID,Avg(convert(float, RESULT))  
   FROM dbo.Tests T WITH(NOLOCK) --WITH (INDEX(Test_By_Variable_And_Result_On),NOLOCK)  
   JOIN #tcur_PartProd PP ON PP.PartSpeedTargetVarID = T.Var_id  
   AND T.RESULT_on > PP.StartTIME  
   AND T.RESULT_on <= PP.EndTIME  
   WHERE Canceled <> 1  
Group By Id  
  
UPDATE #Production  
 Set LineSpeedTAR = t.TEMPValue2  
FROM #Production P JOIN #Temporary t ON p.id = t.TEMPValue1  
  
---------------------------------------------------------------------------------------------  
-- Calculate the LineSpeedTarget for that intervals with NULL Line Speed  
TRUNCATE table #Temporary  
  
Insert into #Temporary (TEMPValue1,TEMPValue2)  
Select PU_ID,AVG(LineSpeedTAR)  
FROM #Production tpt   
WHERE LineSpeedTAR IS NOT NULL  
Group By PU_ID  
  
  
UPDATE #Production  
 Set LineSpeedTAR = T.TEMPValue2  
FROM #Production P JOIN #Temporary T ON P.PU_ID = T.TEMPValue1  
WHERE P.LineSpeedTAR Is NULL  
  
DROP TABLE #TCur_PartProd  
--------------------------------------------------------------------------------------------- 
-- UPDATE Class column ON product table.  
UPDATE #Production Set Class = (Select Class FROM @Class WHERE Pu_id = #Production.Pu_id)  
  
-- UPDATE statement for Production Day  
UPDATE #Production  
 Set ProdDay = CONVERT(nvarchar(12),cs.StartTime)  
FROM #Production p  
JOIN #PLIDLIst PL ON p.pu_id = pl.ConvUnit  
JOIN @Crew_Schedule cs ON pl.ScheduleUnit = cs.pu_id  
AND p.StartTime >= cs.StartTime AND p.StartTime < cs.EndTime  
  
UPDATE #Production  
 Set SchedTime = DateDiff(ss,StartTime,EndTime),  
  ConvFactor = 1  
  
  
  -- Added for FO-02558

UPDATE p 
	Set TypeOfEvent = 'Partial' 
	From #Production p 
		Inner Join (Select EventId from #Production where HybridConf = 'yes' group by EventId  having count(eventID) >1 ) p2
		on p.eventID= p2.eventid



Insert Into #Event_Detail_History
(eventId,
ID,
enteredON_Start,
enteredOn_End)
Select P.EventID,P.ID,  min(Entered_On),max(Entered_On)
From #Production P with (nolock)
JOIN Event_Detail_History EDH with (nolock) on P.eventID = EDH.Event_ID
Where P.TypeOfEvent = 'Partial' AND P.Class=3
	AND ( EDH.entered_on > DATEADD(minute,2,P.StartTime) AND EDH.entered_on <= DATEADD(minute,5,P.EndTime))
	Group by P.ID,P.Eventid


-- fdr This is causing an issue:
Update #Event_Detail_History
	SET FinalCount = (Select SUM(Initial_Dimension_X) from Event_Detail_History where event_id = eventid AND Entered_on = enteredOn_End)

Update #Event_Detail_History
	SET InitialCount = (Select SUM(Initial_Dimension_X) from Event_Detail_History where event_id = eventid AND Entered_on = enteredON_Start)

--==============================================================================================================================================
-- UPDATE the Total Cases depending ON what Type Of Event:
-- CaseCount:  
-- TotalCases:
	-- old
	--UPDATE #Production	
	--	SET TotalCases = (SELECT SUM(ed.Final_Dimension_X) 
	--						FROM dbo.Event_Details ed WITH(NOLOCK) 
	--						WHERE ed.Event_Id = p.EventId)		
	--FROM   #Production p
	--WHERE TypeOfEvent = 'Complete'
	--AND class = 3
	--AND HybridConf = 'Yes'

	-- FDR
	/* UPDATE p
		SET p.TotalCases = ed.Final_Dimension_X
		FROM #Production		p				
		JOIN dbo.Events			e	WITH(NOLOCK)ON p.eventId = e.Event_Id
												AND e.start_time BETWEEN p.starttime AND p.endtime
		join dbo.Event_Details	ed	WITH(NOLOCK)ON ed.Event_Id = e.Event_Id
		WHERE TypeOfEvent = 'Complete'
			AND class = 3
			AND HybridConf = 'Yes'*/

	--SELECT distinct p.EventId, ed.Final_Dimension_X, p.crew, p.shift, e.start_time, p.starttime, p.endtime
	--	FROM #Production		p				
	--	JOIN dbo.Events			e	WITH(NOLOCK)ON p.eventId = e.Event_Id
	--											AND e.start_time BETWEEN p.starttime AND p.endtime
	--	join dbo.Event_Details	ed	WITH(NOLOCK)ON ed.Event_Id = e.Event_Id
	--	WHERE p.TypeOfEvent = 'Complete'
	--		AND p.class = 3
	--		AND p.HybridConf = 'Yes'
	--select '@crew_schedule',* from @crew_schedule
		--Commented for FO-02558					
	--UPDATE #Production	
	--	SET TotalCases =(	SELECT MAX(edh.Initial_Dimension_X) - MIN(edh.Initial_Dimension_X)
	--						FROM	
	--						GBDB.dbo.Event_Details			ed	WITH(NOLOCK)
	--						JOIN	GBDB.dbo.Event_Detail_history	edh	WITH(NOLOCK) 
	--																	ON ed.Event_Id = edh.Event_Id
	--						WHERE	
	--							p.eventId = ed.Event_Id
	--							AND	edh.Modified_On >= StartTime
	--							AND edh.Modified_On <= EndTime	
	--						GROUP BY ed.Event_Id
	--										)
	--FROM   #Production p
	--WHERE TypeOfEvent = 'Partial'
	--AND class = 3
	--AND HybridConf = 'Yes'
			
		-- update Total Cases from the values calculated in Temp Event_Details_History table for FO-02558
	-- FDR
	/*
	UPDATE #Production	
		SET TotalCases =finalcases 
							FROM #Event_Detail_History			edh	WITH(NOLOCK)
							join #Production p on p.id=edh.id	
		*/	
	-- Dont remember why I was doing this but:
	UPDATE #Production SET CaseCount = TotalCaseS -- WHERE Class = 3
	-- SELECT '#Production>>',* FROM #Production -- WHERE PU_Id = 175
	--jpg
	--select 'TotalCaseS', TotalCaseS, * from #Production WHERE Class = 3
--==============================================================================================================================================
 
 --select '#Production-0',* from #Production 
-----------------------------------------------------------------------------------------------------  
-- Get Data: Reject Data  
--Print convert(varchar(25), getdate(), 120) + ' Get Reject Data'  
-----------------------------------------------------------------------------------------------------  
  
If @RPT_ShowTop5Rejects = 'TRUE' AND @RPTMinorGroupBy <> 'ProdDay'  
Begin  
  
Insert Into #Rejects (NRecords,PadCount, Reason1,Reason2,   
        Product, Product_Size,Crew, Shift, LineStatus, PLID, pu_id,Location)  
Select  
     count(wed.TimeStamp)       ,   
  sum(wed.amount)         ,   
        wedf.wefault_name        ,  
     Null           ,    
        P.Product   As   'Product'  ,  
     P.Product_Size   As   'Product Size' ,  
  P.Crew     As   'Crew'   ,  
  P.Shift     As   'Shift'   ,  
  P.LineStatus  As   'LineStatus' ,  
        PL.PLID           ,   
        WED.PU_ID          ,  
        pu.pu_desc            
From  
  dbo.Waste_Event_Details as wed WITH(NOLOCK) -- WITH (INDEX(WEvent_Details_IDX_PUIdTime),NOLOCK)  
  JOIN dbo.Waste_Event_Fault wedf  WITH(NOLOCK) ON wed.reason_level1 = wedf.reason_level1   
                AND wed.pu_id = wedf.pu_id  
     JOIN #PLIDList PL ON PL.ConvUnit = wed.Pu_id  
     JOIN Prod_Units pu ON pu.pu_id = wed.source_pu_id  
  JOIN #Production P ON P.PU_Id = wed.Pu_Id AND wed.TimeStamp >= P.StartTime AND wed.TimeStamp < P.EndTime  
  
 WHERE  
 (wed.TimeStamp >= @StartDateTime AND wed.TimeStamp < @EndDateTime)  
        
Group By  
 wedf.wefault_name,P.Product,P.Product_Size, P.Crew, P.Shift,   
 P.LineStatus,PL.PLID, WED.PU_ID,pu.pu_desc,pl.ScheduleUnit  
  
  
End  
  
--Print convert(varchar(25), getdate(), 120) + ' End Get Reject Data'  
  
--Print convert(varchar(25), getdate(), 120) + ' Get Splice Data'  
-----------------------------------------------------------------------------------------------------  
-- Get Data: Splice Data  
-----------------------------------------------------------------------------------------------------  
--   
If Exists(Select count(*) FROM @ColumnVisibility WHERE VariableName like '%Splice%' Or VariableName like '%SuccessRate%') -- AND @RPTMinorGroupBy <> 'ProdDay'  
Begin  
Insert into #Splices (nrecords, SpliceStatus, Product,Product_Size,  
                 Crew, Shift, LineStatus, PLID, pu_id, class,ProdDay)  
Select  
 count(*)         ,  
 sum(wed.amount)  As   'SpliceStatus' ,  
  P.Product   As   'Product'  ,  
     P.Product_Size   As   'Product Size' ,  
  P.Crew     As   'Crew'   ,  
  P.Shift     As   'Shift'   ,  
  P.LineStatus  As   'LineStatus' ,  
 PL.PLID    As   'PLID'   ,  
 WED.PU_ID    As   'pu_id'   ,  
 PL.Class            ,  
    CONVERT(nvarchar(12),Timestamp)  
  
 From  
  
 dbo.Waste_Event_Details wed WITH(NOLOCK) 
  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON (pu.pu_id = wed.source_PU_Id)   
  
 Inner JOIN #PLIDList pl ON wed.pu_id = pl.SpliceUnit   
      
 JOIN #Production P ON P.PU_Id = pl.ScheduleUnit AND wed.TimeStamp >= P.StartTime AND wed.TimeStamp < P.EndTime  
  
 WHERE  
  
  (wed.TimeStamp >= @StartDateTime AND wed.TimeStamp < @EndDateTime)  
      
   
    Group By  
 wed.Timestamp,pl.Class,P.Product,P.Product_Size, P.Crew, P.Shift,   
 P.LineStatus,PL.PLID, WED.PU_ID,pu.pu_desc,pl.ScheduleUnit  
  
  
 If @RptMajorGroupBy = 'Unit'  
 Begin  
   UPDATE #Splices  
    Set PU_ID = TPLID.ConvUnit  
   FROM #Splices s  
   JOIN #PLIDList TPLID ON s.pu_id = TPLID.SpliceUnit  
 End  
  
End  
  
--**************************************************************************************************  
-- Get Data: Downtime Data  
--Print convert(varchar(25), getdate(), 120) + ' Get Downtime Data'  
--**************************************************************************************************  
Insert #Downtimes  
	(TedID,PU_ID, PLID, Start_Time,End_Time, Fault,Location,Location_id, Tree_Name_Id,  
	Reason1_Code,Reason2_Code,  Reason3_Code,Reason4_Code,  
	IsStops, UserID, Action_Level1)  
Select   
	ted.TEDet_Id, ted.PU_Id, tpl.PLID,     
	Case   
		When ted.Start_Time < @StartDateTime THEN @StartDateTime  
		Else ted.Start_Time  
	End,  
	Case  
	--When ted.End_Time Is null THEN @Now  
		When ted.End_Time Is null THEN @EndDateTime -- JJR 4/24/03  
		When ted.End_Time > @EndDateTime THEN @EndDateTime  
		Else ted.End_Time  
	End,  
	tef.teFault_Name,   
	--  '',  
	pu.pu_DESC,   
	pu.pu_id,  
	ertd.Tree_Name_Id,
    ted.Reason_level1,  
    ted.Reason_level2, 
    ted.Reason_level3,
    ted.Reason_level4,
    Case   -- If the stop belongs to a previous period, then count it as IsStops = 0  
		When ted.Start_Time < @StartDateTime THEN 0  
		Else 1  
	End,  
	ted.User_ID,  
	ted.Action_Level1  
	From  dbo.Timed_Event_Details ted WITH(NOLOCK)      -- WITH (INDEX(TEvent_Details_IDX_PUIdSTime),NOLOCK)  
	JOIN  #PLIDList tpl WITH (NOLOCK)  ON ted.PU_Id = tpl.convUnit -- or ted.pu_Id = tpl.Packerunit    
  
	LEFT JOIN dbo.Event_Reason_Tree_Data ertd WITH (NOLOCK) 
												ON ertd.Event_Reason_Tree_Data_Id = ted.Event_Reason_Tree_Data_Id
   
	LEFT JOIN dbo.timed_Event_Fault tef WITH(NOLOCK) ON ted.teFault_id = tef.teFault_id   
	JOIN dbo.Prod_Units_Base PU WITH(NOLOCK) ON ted.source_pu_id = pu.pu_id  
	WHERE ted.Start_Time < @EndDateTime  
			AND (ted.End_Time > @StartDateTime or ted.End_Time IS null)   
 
--Tuned for performance 
UPDATE d SET	Reason1 = er1.Event_Reason_Name,
			Reason2 = er2.Event_Reason_Name,
			Reason3 = er3.Event_Reason_Name,
			Reason4 = er4.Event_Reason_Name 
	FROM #Downtimes d
	LEFT JOIN dbo.Event_Reasons er1 WITH(NOLOCK) ON Reason1_Code = er1.Event_Reason_id   
	LEFT JOIN dbo.Event_Reasons er2 WITH(NOLOCK) ON Reason2_Code = er2.Event_Reason_id   
	LEFT JOIN dbo.Event_Reasons er3 WITH(NOLOCK) ON Reason3_Code = er3.Event_Reason_id   
	LEFT JOIN dbo.Event_Reasons er4 WITH(NOLOCK) ON Reason4_Code = er4.Event_Reason_id 
	  
-----------------------------------------------------------------------------------------------------  
-- If the sp is run with endtime = GetDate () AND the line is down at  
-- that point in time, set the endtime of the last record (which would otherwise be NULL)  
-- equal to the endtime passed to the sp by the end user  
-----------------------------------------------------------------------------------------------------  
  
IF (Select Top 1 TedID FROM #Downtimes WHERE End_Time IS NULL) IS NOT NULL  
 BEGIN  
 UPDATE #Downtimes  
 SET End_Time = @RPTEndDate  
 WHERE End_Time IS NULL  
 END  
  
UPDATE #Downtimes Set Class = (select cc.class FROM @Class cc WHERE cc.pu_id = #downtimes.pu_id)  
  
-----------------------------------------------------------------------------------------------------  
-------------------------------------------------------------------------------------------------------- 
--*************************************************************************************************  
-- NEW fix for BELL  
--*************************************************************************************************  
-- Saco los LineStatus changes  
  
--**********************************************************************************************************   

Declare LineStatusSplit INSENSITIVE Cursor For (   
  Select PLID,PU_ID,EndTime FROM #Production) Order By PU_Id,EndTime  
  
  For Read Only  
 --  
 Open LineStatusSplit   
 --  
 Fetch Next FROM LineStatusSplit into @PLID, @PU_Id, @EndTime  
 --  
 While @@Fetch_Status = 0  
 --  
 Begin   
  
  Insert #Downtimes  
   (TedID,PU_ID, PLID, Start_Time,End_Time, Fault,
		Tree_Name_Id,
		Location_Id,Location,  
		Reason1_code,Reason1, 
		Reason2_code,Reason2, 
		Reason3_code,Reason3, 
		Reason4_code,Reason4, 
	IsStops, Dev_Comment, UserID, Action_Level1,Class)  
   Select TedID, PU_ID, PLID, @EndTime, End_Time, Fault, 
		Tree_Name_Id,
		Location_Id,Location,  
		Reason1_code,Reason1, 
		Reason2_code,Reason2, 
		Reason3_code,Reason3, 
		Reason4_code,Reason4, 
	0, 'DowntimeSplit', UserID, Action_Level1,Class  
   FROM #Downtimes tdt WITH (NOLOCK)   
   WHERE tdt.PU_ID = @PU_Id  
    AND tdt.Start_Time < @EndTime  
    AND (tdt.End_Time > @EndTime or End_Time is NULL)  
  
  --  
  BEGIN  
            IF Not Exists (Select * FROM #Downtimes  
      WHERE ISNULL(Dev_Comment, 'Blank') = 'DowntimeSplit'  
      AND PU_ID = @PU_Id AND (End_Time = @EndTime Or Start_Time = @EndTime))  
      BEGIN  
              Insert #Downtimes   
              (TedID, PU_ID, PLID, Start_Time, End_Time, IsStops, Dev_Comment,Class)  
              Select 9999, @PU_Id, @PLID, @EndTime, @EndTime, 0, 'DowntimeSplit',  
                    Class FROM @Class WHERE pu_id = @PU_Id  
            END  
  END     
  --  
  UPDATE #Downtimes  
   Set End_Time = @EndTime  
   WHERE PU_ID = @PU_Id  
    AND Start_Time < @EndTime  
    AND (End_Time > @EndTime or End_Time is NULL)  
  --  
  FETCH NEXT FROM LineStatusSplit into @PLID, @PU_Id, @EndTime  
 End   
   
 Close LineStatusSplit   
 Deallocate LineStatusSplit   
  
  
--*************************************************************************************************  
--Print convert(varchar(25), getdate(), 120) + 'No Event Cursors'  
  
Declare DowntimeNoEvent INSENSITIVE Cursor For (   
  Select distinct tpl.PLID, cs.PU_ID, cs.EndTime  
  FROM #PLIDList tpl  
  JOIN (Select PU_ID,Crew,Shift,StartTime,EndTime FROM @Crew_Schedule) as cs   
   ON tpl.ScheduleUnit = cs.pu_id  
  WHERE cs.StartTime <= @EndDateTime AND   
  (cs.EndTime > @StartDateTime or cs.EndTime Is null))  
  
  For Read Only  
 --  
 Open DowntimeNoEvent  
 --  
 Fetch Next FROM DowntimeNoEvent into @PLID, @PU_Id, @EndTime  
 --  
 While @@Fetch_Status = 0  
 --  
 Begin  
  Select @StartTime = MIN(Start_Time)   
         FROM #Downtimes  
         WHERE Start_Time > @EndTime  
         AND PU_ID = @PU_Id   
  --  
  IF Not Exists (Select * FROM #Downtimes  
      WHERE ISNULL(Dev_Comment, 'Blank') = 'DowntimeSplit'  
      AND PU_ID = @PU_Id AND (End_Time = @EndTime Or Start_Time = @EndTime))  
  --  
  BEGIN  
  --  
  Insert #Downtimes  
	(TedID,PU_ID, PLID, Start_Time,End_Time, Fault,
		Tree_Name_Id,
		Location_Id,Location,  
		Reason1_code,Reason1, 
		Reason2_code,Reason2, 
		Reason3_code,Reason3, 
		Reason4_code,Reason4, 
	IsStops, Dev_Comment, UserID, Action_Level1,Class)
	Select TedID, PU_ID, PLID, @EndTime, @EndTime, Fault, 
		Tree_Name_Id,
		Location_Id,Location,  
		Reason1_code,Reason1, 
		Reason2_code,Reason2, 
		Reason3_code,Reason3, 
		Reason4_code,Reason4, 
	0, 'DowntimeNoEvent', UserID, Action_Level1,Class  
   FROM #Downtimes tdt  
   WHERE tdt.PU_ID = @PU_Id  
   AND tdt.Start_Time = @StartTime  
   AND (tdt.End_Time > @EndTime or End_Time is NULL)  
  
   --  
  END -- Insertion Loop   
   
 FETCH NEXT FROM DowntimeNoEvent into @PLID, @PU_Id, @EndTime  
 End -- DowntimeNoEvent Loop  
 --  
 Close DowntimeNoEvent  
 Deallocate DowntimeNoEvent  
-- End  
  
--*************************************************************************************************  
--Print convert(varchar(25), getdate(), 120) + 'Downtime End Cursors'  
  
Declare DowntimeEnd INSENSITIVE Cursor For  
 (Select ConvUnit, PLID.PLID, c.Class  
  FROM #PLIDList PLID  
                JOIN @Class c ON PLID.ConvUnit = c.pu_id)  
 For Read Only  
  
Open DowntimeEnd  
  
FETCH NEXT FROM DowntimeEnd into @PU_Id, @PLID,@ClassNum  
  
While @@Fetch_Status = 0  
Begin  
 Set @EndTime = null  
 Select @EndTime = Max(End_Time)  
  FROM #Downtimes  
  WHERE PU_ID = @PU_Id  
 --  
 If @EndTime < @EndDateTime  
 Insert #Downtimes -- 4/16/03 Added dummy TedID '9999' JJR  
  (TedID, PU_ID, PLID, Start_Time, End_Time, IsStops, Dev_Comment,Class)  
  Values (9999, @PU_Id, @PLID, @EndDateTime, @EndDateTime, 0, 'DowntimeEnd',@ClassNum)  
 --  
 Set @StartTime = null  
  Select @StartTime = Min(Start_Time)  
  FROM #Downtimes  
  WHERE PU_ID = @PU_Id  
 --  
 If @StartTime > @StartDateTime  
 Insert #Downtimes -- 4/16/03 Added dummy TedID '9999' JJR  
  (TedID, PU_ID, PLID, Start_Time, End_Time, IsStops, Dev_Comment,Class)  
  Values (9999, @PU_Id, @PLID, @StartDateTime, @StartDateTime, 0, 'DowntimeEnd',@ClassNum)  
 --  
 Fetch Next FROM DowntimeEnd into @PU_Id, @PLID,@ClassNum  
End  
Close DowntimeEnd  
Deallocate DowntimeEnd  
  
--------------------------------------------------------------------------------------------------  
--10/01/03 JJR  NoStops Cursor added to prevent sp FROM returning an empty record set  
--              when run for a period in which no stops take place.  
--------------------------------------------------------------------------------------------------  
--Print convert(varchar(25), getdate(), 120) + ' NoStops Cursor'   
  
Declare NoStops INSENSITIVE Cursor For  
 (Select ConvUnit, PLID  
  FROM #PLIDList)  
 For Read Only  
--  
Open NoStops  
--  
FETCH NEXT FROM NoStops into @PU_Id, @PLID  
--  
While @@Fetch_Status = 0  
Begin  
 If (Select MAX(PU_ID) FROM #Downtimes WHERE PU_ID = @PU_Id) IS NULL  
 BEGIN  
  
 Insert #Downtimes -- 4/16/03 Added dummy TedID '9999' JJR  
 (TedID, PU_ID, PLID, Start_Time, End_Time, IsStops, Dev_Comment)   
 Values (9999, @PU_Id, @PLID, @StartDateTime, @EndDateTime, 0, 'NoStops') -- JJR 10/01/03  
 --  
 UPDATE #Downtimes  
 Set Uptime = Datediff(ss, Start_Time, End_Time) / 60.0 --,  
 WHERE PU_ID = @PU_Id  
 --  
  
 END  
--  
FETCH NEXT FROM NoStops into @PU_Id, @PLID  
End -- NoStops Cursor Loop  
Close NoStops  
Deallocate NoStops  
  
  
  
  
---------------------------------------------------------------------------------------  
--Print convert(varchar(25), getdate(), 120) + ' Updating Duration'   
UPDATE TDT  
 Set Duration = Str(DatedIff(ss, tdt.Start_Time, tdt.End_Time) / 60.0,12,1),   
  Product = P.Product,   
        Product_Size = P.Product_Size,  
  Crew = P.Crew,   
  Shift = P.Shift,   
  LineStatus = P.LineStatus  
  
 FROM #Downtimes tdt  
 JOIN #Production P ON (tdt.PU_Id = P.PU_ID AND   
     tdt.Start_Time >= p.StartTime   
     AND tdt.Start_Time < p.EndTime )  
  
-----------------------------------------------------------------------------------------------  
-- 8/23/02 JJR: New code to UPDATE the shift entry for 'non-event' records  
-- Print convert(varchar(25), getdate(), 120) + ' Updating No-Event records'   
-----------------------------------------------------------------------------------------------  
  
  
UPDATE TDT  
 Set   
  Shift     =     P.Shift,  
  Crew         =     P.Crew,  
  LineStatus   =     P.LineStatus  
  
 FROM #Downtimes tdt  
 JOIN #Production P   ON (tdt.Pu_Id = P.PU_ID AND   
     tdt.Start_Time > p.StartTime   
     AND tdt.Start_Time <= p.EndTime )  
  
 WHERE tdt.Duration = 0  
  
  
-- End 8/23/02 UPDATE shift for non-event records  
-----------------------------------------------------------------------------------------------  
-- Print convert(varchar(25), getdate(), 120) + ' Calculating the Uptime column'  
-- Insert Into @Temp_Uptime (id,pu_id,Start_Time,End_Time)  
  
Select d1.id,d1.pu_id,MAX(d2.End_Time) as Start_Time,d1.Start_Time as End_Time  
Into #Temp_Uptime  
FROM #Downtimes d1  
JOIN #Downtimes d2 ON (d1.pu_id = d2.pu_id) AND (d2.End_Time <= d1.Start_Time) AND (d1.id <> d2.id)  
Group By d1.id,d1.Start_Time,d1.pu_id  
  
UPDATE #Downtimes   
        Set Uptime = Str(IsNull(DatedIff(ss,t1.Start_Time,t1.End_Time) / 60.0,0),12,1)   
FROM #Downtimes d  
JOIN #Temp_Uptime t1 ON d.id = t1.id   
  
-----------------------------------------------------------------------------------------------   
UPDATE #Downtimes  
 Set Duration = 0 WHERE ISNULL(Dev_Comment, 'Blank') = 'NoStops'  
-----------------------------------------------------------------------------------------------   
  
-----------------------------------------------------------------------------------------------  
--Print convert(varchar(25), getdate(), 120) + ' Start getting the #History table'  
-----------------------------------------------------------------------------------------------  
  
INSERT INTO #Timed_Event_Detail_History   
Select  Tedet_ID, Initial_User_ID  
FROM dbo.Timed_Event_Details  ted WITH(NOLOCK)  
JOIN #Downtimes tdt ON ted.TEDET_ID = tdt.TedID --AND Modified_On > @RptStartDate  
  
-----------------------------------------------------------------------------------------------   
-- Delete FROM #Downtimes WHERE TedID IS NULL  
-----------------------------------------------------------------------------------------------   
-- select @fltDBVersion   
  
UPDATE #Downtimes  
    Set IsStops = ISNULL((Select Case WHEN Min(User_Id) < 50  
          THEN 1  
          WHEN Min(User_Id) = @DowntimeSystemUserID  
          THEN 1  
          ELSE 0  
        END  
        FROM #Timed_Event_Detail_History   
        WHERE Tedet_Id = ted.TEDET_ID   
        ),0)  
FROM #Downtimes tdt  
LEFT JOIN #Timed_Event_Detail_History ted ON tdt.TEDID = ted.TEDET_ID  
WHERE Dev_Comment Is NULL    
  
UPDATE #Downtimes  
    Set IsStops = 1  
FROM #Downtimes tdt  
JOIN #Timed_Event_Detail_History tedh ON tdt.TEDID = tedh.TEDET_ID  
WHERE tedh.User_ID = @DowntimeSystemUserID  
   AND tdt.Duration <> 0  
   AND Dev_Comment Not Like '%DowntimeSplit'  

----------------------------------------------------------------------------------------------   
  
----------------------------------------------------------------------------------------------   
-- UPDATE Below addresses instances of the line being down at the start of a report  
UPDATE #Downtimes  
 Set IsStops = 0  
FROM #Downtimes tdt  
WHERE tdt.Start_Time = @StartDateTime AND tdt.Uptime = 0  
  
  
----------------------------------------------------------------------------------------------   
-- Get the Tree_Name for the FMECA  
----------------------------------------------------------------------------------------------   
  
UPDATE #Downtimes  
 SET Tree_Name = ert.Tree_Name  
FROM #Downtimes d  
JOIN dbo.Event_Reason_Tree  ert  ON ert.Tree_Name_Id = d.Tree_Name_Id
  
----------------------------------------------------------------------------------------------   
-- UPDATE Survival Rate FROM Test table  
--Print convert(varchar(25), getdate(), 120) + 'UPDATE SurvRate variable'  
----------------------------------------------------------------------------------------------   
  
  
If @RPT_SurvivalRate = 'TRUE' Or @RPT_SurvivalRatePer = 'TRUE'  
Begin  
UPDATE TDT  
 Set SurvRateUptime = T.Result  
 FROM #Downtimes TDT  
 JOIN #PLIDList TPL ON TPL.PLId = TDT.PLID  
    JOIN dbo.Tests T WITH(NOLOCK) ON DateAdd(second, 5, TDT.End_Time) >= T.Result_on  
          AND DateAdd(second, -5, TDT.End_Time) <= T.Result_on AND T.Canceled <> 1  
          AND T.Var_ID = TPL.REDowntimeVarID  
WHERE CONVERT(float,T.REsult) >= @RPTDowntimesurvivalRate  
End  
  
  
--Print convert(varchar(25), getdate(), 120) + 'End UPDATE SurvRate variable'  
  
-- UPDATE for Production Day Grouping  
UPDATE #Downtimes  
 Set ProdDay = CONVERT(nvarchar(12),cs.StartTime)  
FROM #Downtimes dt  
JOIN #PLIDLIst PL ON dt.pu_id = pl.ConvUnit  
JOIN @Crew_Schedule cs ON pl.ScheduleUnit = cs.pu_id  
AND dt.Start_Time >= cs.StartTime AND dt.Start_Time < cs.EndTime  

--**************************************************************************************************************  
-- EVENT REASON CATEGORIES  
--Print convert(varchar(25), getdate(), 120) + ' Get Event Reason categories'  
--**************************************************************************************************************  
-- UPDATE the Event Reason Categories select * FROM prod_units  
  
----------------------------------------------------------------------------------------------------------------------  
-- Get List of parameters to exclude FROM downtimes  
----------------------------------------------------------------------------------------------------------------------  
If @Local_PG_StrCategoriesToExclude <> '!Null'  
Begin   
	Insert #ReasonsToExclude(ERC_Id,ERC_Desc)  
		Exec SPCMN_ReportCollectionParsing  
		@PRMCollectionString = @Local_PG_StrCategoriesToExclude, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',   
		@PRMDataType01 = 'nvarchar(100)'  
  
	UPDATE #ReasonsToExclude  
		Set ERC_Id = erc.erc_id  
		FROM dbo.Event_Reason_Catagories  erc WITH(NOLOCK)  
		JOIN #ReasonsToExclude rte ON erc.erc_desc = rte.ERC_Desc       
    
		-- LineStops ERC  
		Insert Into #Equations Select 'DPR_LineStopsERC_EQN','Label=LineStopsERC;','LineStopsERC',Operator,Class,1 FROM #Equations WHERE Variable = 'LineStops'  
		-- Downtime ERC  
		Insert Into #Equations Select 'DPR_DowntimeERC_EQN','Label=DowntimeERC;','DowntimeERC',Operator,Class,1 FROM #Equations WHERE Variable = 'Downtime'  
End  
Else  
Begin  
    Delete FROM @ColumnVisibility WHERE VariableName Like '%DowntimeUnplanned%'   
                                     Or VariableName Like '%LineStopsUnplanned%'  
                                     Or VariableName Like '%MTBF%'  
                                     Or VariableName Like '%MTTR_Unplanned%'  
End  
  
-- Select '#ReasonsToExclude -->', * FROM #ReasonsToExclude  
----------------------------------------------------------------------------------------------------------------------  
-- End Get Parameters  
----------------------------------------------------------------------------------------------------------------------  

If @Local_PG_StrCategoriesToExclude <> '!Null'  
Begin  
	UPDATE    dr  
		SET    DowntimeTreeId = pe.Name_Id  
		FROM   #Downtimes dr   
		JOIN    dbo.Prod_Events pe WITH(NOLOCK) ON dr.Location_id = pe.PU_Id   
		WHERE   pe.Event_Type = 2 -- Event_type = 2 (Downtime)  
  
	---------------------------------------------------------------------------------------------------  
	-- Find the node ID associated with Reason Level 4  
	---------------------------------------------------------------------------------------------------  
	UPDATE dr  
		Set dr.DowntimeNodeTreeId = l4.Event_Reason_Tree_Data_Id  
		FROM #Downtimes dr        
		JOIN dbo.Event_Reason_Tree_Data l4 WITH (NOLOCK) ON dr.DowntimeTreeId = l4.Tree_Name_Id AND dr.Reason4_Code = l4.Event_Reason_Id AND l4.Event_Reason_Level = 4  
		JOIN dbo.Event_Reason_Tree_Data l3 WITH (NOLOCK) ON l3.Event_Reason_Tree_Data_Id = l4.Parent_Event_R_Tree_Data_Id AND dr.Reason3_Code = l4.Parent_Event_Reason_Id AND l3.Event_Reason_Level = 3  
		JOIN dbo.Event_Reason_Tree_Data l2 WITH (NOLOCK) ON l2.Event_Reason_Tree_Data_Id = l3.Parent_Event_R_Tree_Data_Id AND dr.Reason2_Code = l3.Parent_Event_Reason_Id AND l2.Event_Reason_Level = 2  
		JOIN dbo.Event_Reason_Tree_Data l1 WITH (NOLOCK) ON l1.Event_Reason_Tree_Data_Id = l2.Parent_Event_R_Tree_Data_Id AND dr.Reason1_Code = l2.Parent_Event_Reason_Id AND l1.Event_Reason_Level = 1  
        WHERE dr.Reason4_Code Is Not NULL  
  
	UPDATE dr  
		Set ERC_Id = ed.ERC_Id,  ERC_Desc = ec.ERC_Desc  
		FROM #Downtimes dr  
		JOIN dbo.Event_Reason_Category_Data ed WITH (NOLOCK) ON dr.DowntimeNodeTreeId = ed.Event_Reason_Tree_Data_Id  
		JOIN dbo.Event_Reason_Catagories ec WITH (NOLOCK) ON ec.ERC_Id = ed.ERC_Id    
		WHERE ec.ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude)   
  
	---------------------------------------------------------------------------------------------------  
	--   Find the node ID associated with Reason Level 3 when Reason Level 4 is null  
	---------------------------------------------------------------------------------------------------  
	UPDATE dr  
		SET dr.DowntimeNodeTreeId = l3.Event_Reason_Tree_Data_Id   
		FROM #Downtimes dr        
		JOIN dbo.Event_Reason_Tree_Data l3 WITH (NOLOCK) ON dr.DowntimeTreeId = l3.Tree_Name_Id AND dr.Reason3_Code = l3.Event_Reason_Id AND l3.Event_Reason_Level = 3  
		JOIN dbo.Event_Reason_Tree_Data l2 WITH (NOLOCK) ON l2.Event_Reason_Tree_Data_Id = l3.Parent_Event_R_Tree_Data_Id AND dr.Reason2_Code = l3.Parent_Event_Reason_Id AND l2.Event_Reason_Level = 2  
		JOIN dbo.Event_Reason_Tree_Data l1 WITH (NOLOCK) ON l1.Event_Reason_Tree_Data_Id = l2.Parent_Event_R_Tree_Data_Id AND dr.Reason1_Code = l2.Parent_Event_Reason_Id AND l1.Event_Reason_Level = 1  
        WHERE dr.Reason3_Code Is Not NULL  
  
	UPDATE dr  
		Set ERC_Id = ed.ERC_Id,  ERC_Desc = ec.ERC_Desc  
		FROM #Downtimes dr  
		JOIN dbo.Event_Reason_Category_Data ed WITH (NOLOCK) ON dr.DowntimeNodeTreeId = ed.Event_Reason_Tree_Data_Id  
		JOIN dbo.Event_Reason_Catagories ec WITH (NOLOCK) ON ec.ERC_Id = ed.ERC_Id    
		WHERE ec.ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude)   
  
	---------------------------------------------------------------------------------------------------  
	--   Find the node ID associated with Reason Level 2 when Reason Level 3 is null  
	---------------------------------------------------------------------------------------------------  
  
	UPDATE dr  
		SET dr.DowntimeNodeTreeId = l2.Event_Reason_Tree_Data_Id  
		FROM #Downtimes dr        
		JOIN dbo.Event_Reason_Tree_Data l2 WITH (NOLOCK) ON dr.DowntimeTreeId = l2.Tree_Name_Id AND dr.Reason2_Code = l2.Event_Reason_Id AND l2.Event_Reason_Level = 2  
		JOIN dbo.Event_Reason_Tree_Data l1 WITH (NOLOCK) ON l1.Event_Reason_Tree_Data_Id = l2.Parent_Event_R_Tree_Data_Id AND dr.Reason1_Code = l2.Parent_Event_Reason_Id AND l1.Event_Reason_Level = 1   
		WHERE Reason2_Code Is Not NULL  
  
	UPDATE dr  
		Set ERC_Id = ed.ERC_Id,  ERC_Desc = ec.ERC_Desc  
		FROM #Downtimes dr  
		JOIN dbo.Event_Reason_Category_Data ed WITH (NOLOCK) ON dr.DowntimeNodeTreeId = ed.Event_Reason_Tree_Data_Id  
		JOIN dbo.Event_Reason_Catagories ec WITH (NOLOCK) ON ec.ERC_Id = ed.ERC_Id    
		WHERE ec.ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude)   
  
	--------------------------------------------------------------------------------------------------  
	--   Find the node ID associated with Reason Level 1 when Reason Level 2 is null  
	---------------------------------------------------------------------------------------------------  
  
	UPDATE dr  
		Set dr.DowntimeNodeTreeId = l1.Event_Reason_Tree_Data_Id   
		FROM #Downtimes dr        
		JOIN dbo.Event_Reason_Tree_Data l1 WITH (NOLOCK) ON dr.DowntimeTreeId = l1.Tree_Name_Id AND dr.Reason1_Code = l1.Event_Reason_Id AND l1.Event_Reason_Level = 1  
		WHERE Reason1_Code Is Not NULL  
  
	UPDATE dr  
		Set ERC_Id = ed.ERC_Id,  ERC_Desc = ec.ERC_Desc  
		FROM #Downtimes dr  
		JOIN dbo.Event_Reason_Category_Data ed WITH (NOLOCK) ON dr.DowntimeNodeTreeId = ed.Event_Reason_Tree_Data_Id  
		JOIN dbo.Event_Reason_Catagories ec WITH (NOLOCK) ON ec.ERC_Id = ed.ERC_Id    
		WHERE ec.ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude)   
  
	--------------------------------------------------------------------------------------------------  
	--   Delete FROM #Downtimes all Reason Categories Found  
	---------------------------------------------------------------------------------------------------  
	-- Not doing this anymore, now counting them as sepparate variable  
	-- UPDATE #Downtimes Set IsStops = 0 WHERE ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude)   
  
End  
  
--**************************************************************************************************************  
-- END  
--**************************************************************************************************************  
-- Select '#Downtimes',* FROM #Downtimes 
--*****************************************************************************************************  
--Print convert(varchar(25), getdate(), 120) + ' End Get Event Reason categories'  
-- ******************************************************************************************  
-- START OF GROUPING FEATURE : Check the cursor  
-- MAJOR GROUPING !!  
-- ******************************************************************************************  
----------------------------------------------------------------------------------------------------  
-- Create Major Cursors, must include CLASS  
----------------------------------------------------------------------------------------------------  
-- Select * FROM #Downtimes WHERE IsStops = 1  
-----------------------------------------------------------------------------------------------------------  
-- LINE MAJOR GROUPING  
--Print convert(varchar(25), getdate(), 120) + ' Building Cursors for Grouping'  
------------------------------------------------------------------------------------------------------------  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Line'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLDesc,PLID.PLID,PLID.PLDesc,0,0 FROM #PLIDList PLID        
    Order By PLID.PLDesc  
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Unit'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLDesc,c.Pu_id,pu.Pu_desc,0,c.Class FROM #PLIDList PLID  
        JOIN @Class c ON PLID.PLID = c.PLID  
        JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pu_id = c.pu_id  
        Order By PLID.PLDesc,c.Class  
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Crew'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLdesc,p.Crew,p.Crew,0,0 FROM #PLIDList PLID  
 JOIN #Production p ON p.PLID = PLID.PLID  
        WHERE p.Crew Is Not Null  
 Order By PLID.PLDesc,p.Crew        
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Shift'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLdesc,p.Shift,p.Shift,0,0 FROM #PLIDList PLID  
 JOIN #Production p ON p.PLID = PLID.PLID  
 WHERE p.Shift Is Not Null        
        Order by PLID.PLDesc,p.Shift  
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Location'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLdesc,d.Location,d.Location,0,0 FROM #PLIDList PLID  
 JOIN #Downtimes d ON d.PLID = PLID.PLID  
 WHERE d.Location Is Not Null  
        Order by PLID.PLDesc,d.Location  
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'ProdDay'  
Begin
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by,EffectiveDate)  
 Select distinct PLID.PLID,PLID.PLdesc,p.ProdDay,p.ProdDay,0,0,CAST(p.ProdDay AS datetime) FROM #PLIDList PLID  
 JOIN #Production p ON p.PLID = PLID.PLID WHERE p.ProdDay Is Not Null  
        Order by PLID.PLDesc,CAST(p.ProdDay AS datetime)
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Product'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLdesc,p.Product,p.Product,0,0 FROM #PLIDList PLID  
 JOIN #Production p ON p.PLID = PLID.PLID  
        WHERE p.Product Is Not Null  
        Order by PLID.PLDesc, p.Product  
End  
If @RPTMajorGroupBy = 'Line' AND @RPTMinorGroupBy = 'Product_Size'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct PLID.PLID,PLID.PLdesc,p.Product_Size,p.Product_Size,0,0 FROM #PLIDList PLID  
 JOIN #Production p ON p.PLID = PLID.PLID  
        WHERE p.Product Is Not Null  
        Order by PLID.PLDesc, p.Product_Size  
End  
------------------------------------------------------------------------------------------------------------  
-- END Line Major Grouping  
------------------------------------------------------------------------------------------------------------  
-- print 'Unit grouping'  
------------------------------------------------------------------------------------------------------------  
-- UNIT MAJOR GROUPING  
------------------------------------------------------------------------------------------------------------  
  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'Unit'  
Begin Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct c.pu_id,pu.pu_desc,c.pu_id,pu.pu_desc,c.class,c.class FROM @Class c  
 JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pu_id = c.pu_id  
        Order By c.Class  
End  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'Crew'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.PU_id,pu.PUDesc,p.Crew,p.Crew,pu.Class,0  FROM #Production p  
 JOIN @Class pu ON p.pu_id = pu.pu_id  
 WHERE p.Crew Is Not NULL   
        Order By pu.Class  
End  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'Shift'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.PU_id,pu.PUDesc,p.Shift,p.Shift,pu.Class,0  FROM #Production p  
 JOIN @Class pu ON p.pu_id = pu.pu_id  
 WHERE p.Shift Is Not NULL    
        Order By pu.Class  
End  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'Location'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct d.pu_id,pu.pudesc,d.Location,d.Location,pu.Class,0  FROM #Downtimes d  
 JOIN @Class pu ON d.pu_id = pu.pu_id  
 WHERE d.Location Is Not NULL  
        Order By pu.Class  
End  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'ProdDay'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.pu_id,pu.pudesc,p.ProdDay,p.ProdDay,pu.Class,0  FROM #Production p   
 JOIN @Class pu ON p.pu_id = pu.pu_id WHERE p.ProdDay Is Not Null  
    Order By pu.Class  
End  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'Product'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.pu_id,pu.pudesc,p.Product,p.Product,pu.Class,0  FROM #Production p  
 JOIN @Class pu ON p.pu_id = pu.pu_id  
    Order By pu.Class  
End  
If @RPTMajorGroupBy = 'Unit' AND @RPTMinorGroupBy = 'Product_Size'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.pu_id,pu.pudesc,p.Product_Size,p.Product_Size,pu.Class,0  FROM #Production p  
 JOIN @Class pu ON p.pu_id = pu.pu_id  
    Order By pu.Class,p.Product_Size  
End  
------------------------------------------------------------------------------------------------------------  
-- END Line Major Grouping  
------------------------------------------------------------------------------------------------------------  
-- print 'Product grouping'  
------------------------------------------------------------------------------------------------------------  
-- PRODUCT MAJOR GROUPING  
------------------------------------------------------------------------------------------------------------  
If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'Product'  
  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.Product,p.Product,p.Product,p.Product,0,0 FROM #Production p       
        Order by p.Product  
End  
If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'Unit'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.Product,p.Product,p.Pu_id,pu.Pu_desc,0,c.Class FROM #Production p   
        JOIN @Class c ON p.pu_id = c.pu_id  
        JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.pu_id = c.pu_id  
        Order by p.Product, c.Class  
End  
If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'Crew'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.Product,p.Product,p.Crew,p.Crew,0,0 
		FROM #Production  p
        WHERE p.Crew is Not Null  
 Order by p.Product,p.Crew        
End  
If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'Shift'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.Product,p.Product,p.Shift,p.Shift,0,0 
 FROM #Production  p
 WHERE Shift Is Not Null      
        Order by p.Product,p.Shift  
End  

If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'Location'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct d.Product,d.Product,d.Location,d.Location,0,0 
	FROM #Downtimes  d
	WHERE d.Location Is Not NULL  
        Order by d.Product,d.Location  
End  

If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'ProdDay'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.Product,p.Product,p.ProdDay,p.ProdDay,0,0 
	FROM #Production p
	WHERE ProdDay Is Not Null  
    Order by p.Product, p.ProdDay  
End  

If @RPTMajorGroupBy = 'Product' AND @RPTMinorGroupBy = 'Product_Size'  
Begin  
 Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
 Select distinct p.Product,p.Product,p.Product_Size,p.Product_Size,0,0 
	FROM #Production   p
    WHERE p.Product_Size Is Not Null  
    Order by p.Product, p.Product_Size  
End  
  
------------------------------------------------------------------------------------------------------------  
-- END Product Major Grouping  
------------------------------------------------------------------------------------------------------------  
 -- Select '@Cursor',* FROM @Cursor  
  
----------------------------------------------------------------------------------------------------  
If @RPTMajorGroupBy = 'Line'  
 set @RPTMajorGroupBy = 'PLID'  
  
If @RPTMinorGroupBy = 'Line'  
 set @RPTMinorGroupBy = 'PLID'  
  
If @RPTMajorGroupBy = 'Unit'  
 set @RPTMajorGroupBy = 'PU_ID'  
  
If @RPTMinorGroupBy = 'Unit'  
 set @RPTMinorGroupBy = 'PU_ID'  
  
-- If @RPTMajorGroupBy = @RPTMinorGroupBy  
--        UPDATE @Cursor Set Minor_id = 'ZZZ', Minor_Desc = 'ZZZ'  
  
--  
----------------------------------------------------------------------------  
-- If 1 major grouping column then do not show the ALL column  
--Print convert(varchar(25), getdate(), 120) + ' Building Output Tables'  
----------------------------------------------------------------------------  
Declare   
        @ShowAll as int,  
        @TotalTables as int  
  
Set @TotalTables = 4  
  
Select @ShowAll = Count(Distinct Major_id) FROM @Cursor  
  
----------------------------------------------------------------------------  
  
  
Set @GroupMajorFieldName = @RPTMajorGroupBy   
Set @GroupMinorFieldName = @RPTMinorGroupBy  
  
Declare   
 @MajGroupValue as nvarchar(20),  
 @MajGroupDesc as nvarchar(100),  
 @MinGroupValue as nvarchar(100),  
 @MinGroupDesc as nvarchar(100),  
    @MajOrderby as int,  
    @MinOrderby as int,  
 @Class_var as int  ,
 @Cur_id as int  
  
  
Set  @i = 1  
  
Set @j = 1  
While @j <= @TotalTables  
Begin  
                If @j = 1   
          Select @TableName =  '#Summary'  
                If @j = 2 AND @RPT_ShowTop5Downtimes = 'TRUE'  
                        Select @TableName =  '#Top5Downtime'  
                If @j = 3 AND @RPT_ShowTop5Stops = 'TRUE'  
                        Select @TableName =  '#Top5Stops'  
                If @j = 4 AND @RPT_ShowTop5Rejects = 'TRUE' AND @RPTMinorGroupBy <> 'ProdDay'  
                        Select @TableName =  '#Top5Rejects'  
    
-- print 'Abro el cursor mayor ...'  
  
Declare RSMjCursor Insensitive Cursor For (Select distinct Major_Order_by,Major_Id, Major_desc FROM @Cursor)  
Order by Major_Order_by,Major_Desc  
Open RSMjCursor  
  
FETCH NEXT FROM RSMjCursor into @Class_Var,@MajGroupValue, @MajGroupDesc  
  
While @@Fetch_Status = 0 AND @i < 100  
Begin  
  
    
 Set @ColNum = LTrim(RTrim(CONVERT(VarChar(3), @i)))  
                  
   
  Select @SQLString = ''  
  Select @SQLString =  ' UPDATE ' + @TableName + ' '   
    + ' Set Value'  + @ColNum + ' = ''' + @MajGroupDesc + '''' +  
    + ' WHERE GroupField = ''' + 'Major' + ''''  
  
  Exec  (@SQLString)  
    
  If @GroupMajorFieldName <> @GroupMinorFieldName  
  Begin  
  
  -- print 'Abro el cursor menor'  
  
  Declare RSMiCursor Insensitive Cursor For (Select Cur_id,Minor_Order_by,Minor_Id, Minor_desc FROM @Cursor
    WHERE Major_id = @MajGroupValue  
                                UNION Select 99,99,'ZZZ','ZZZ'  
                                ) Order by Cur_id,Minor_Order_by,Minor_desc  
  Open RSMiCursor  
  FETCH NEXT FROM RSMiCursor into @Cur_id,@Class_Var,@MinGroupValue,@MinGroupDesc 

   
  While @@Fetch_Status = 0 AND @i < 100  
  Begin   
    If @MinGroupValue <> 'ZZZ'  
    Begin  
      Set @ColNum = LTrim(RTrim(CONVERT(VarChar(3), @i)))  
      Select @SQLString = ''  
      Select @SQLString =  ' UPDATE '  + @TableName + ' '   
       + ' Set Value'  + @ColNum + ' = ''' + @MinGroupDesc + '''' +  
       + ' WHERE GroupField = ''' + 'Minor' + ''''  
  
      Exec  (@SQLString)  
        
      Set @i = @i + 1  
    End   
  
  FETCH NEXT FROM RSMiCursor into @Cur_id,@Class_Var,@MinGroupValue, @MinGroupDesc 
  
  
  End  
  
  Close  RSMiCursor  
  Deallocate RSMiCursor    
  
  End    
    
                If @ShowAll > 1                  
                Begin  
  Set @ColNum = LTrim(RTrim(CONVERT(VarChar(3), @i)))  
   Select @SQLString = ''  
  
                If @RPTMajorGroupBy <> @RPTMinorGroupBy  
  
  Select @SQLString =  ' UPDATE '  + @TableName + ' '   
         + ' Set Value'  + @ColNum + ' = ''' + 'All' + '''' +  
         + ' WHERE GroupField = ''' + 'Minor' + ''''  
  
                Else  
                -- If Line = Line or Line = None  
                Select @SQLString =  ' UPDATE '  + @TableName + ' '   
         + ' Set Value'  + @ColNum + ' = ''' + @MajGroupDesc + '''' +  
         + ' WHERE GroupField = ''' + 'Minor' + ''''  
  
  Exec (@SQLString)  
                  
                End -- End Show All  
  
          
  Set @i = @i + 1  
  
 FETCH NEXT FROM RSMjCursor into @Class_Var,@MajGroupValue, @MajGroupDesc  
  
End  
  
  
Close  RSMjCursor  
Deallocate RSMjCursor  
  
Set @j = @j + 1  
Set @i = 1  
End  
  
----------------------------------------------------------------------------  
-- Code below for label insertion based ON presence of 'aggregate' column  
--Print convert(varchar(25), getdate(), 120) + ' Inserting data in Top 5 Tables'  
  
If @RPT_ShowTop5Downtimes = 'TRUE'  
Begin  
   Select @SQLString = ''  
   Select @SQLString = 'UPDATE #TOP5DOWNTIME' + ' '   
   + 'Set AGGREGATE = ''' + @lblDowntime + '''' +  
   + 'WHERE Sortorder = 1 or Sortorder is Null'  
   Exec  (@SQLString)  
End  
  
If @RPT_ShowTop5Stops = 'TRUE'  
Begin  
  Select @SQLString = ''  
  Select @SQLString = 'UPDATE #TOP5STOPS' + ' '   
  + 'Set AGGREGATE = ''' + @lblStops + '''' +  
  + 'WHERE Sortorder = 1 or Sortorder is Null'  
  Exec  (@SQLString)  
End  
  
If @RPT_ShowTop5Rejects = 'TRUE' AND @RPTMinorGroupBy <> 'ProdDay'  
Begin  
        Select @SQLString = ''  
        Select @SQLString = 'UPDATE #TOP5REJECTS' + ' '   
        + 'Set AGGREGATE = ''' + @lblPads + '''' +  
        + 'WHERE Sortorder = 1 or Sortorder is Null'  
        Exec  (@SQLString)  
End  
  
---------------------------------------------------------------------------------------------  
-- FRio : change datatype to fix the sort order issue  
---------------------------------------------------------------------------------------------  
----------------------------------------------------------------------------------------------  
-- LineStops  
Set @Operator = 'SUM'    -- (Select Operator FROM #Equations WHERE Variable = 'LineStops')  
Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'LineStops')  
  
If @RPT_ShowTop5Stops = 'TRUE'  
Begin  
Select @SQLString = ' Insert Into #TOP5Stops (DESC01, DESC02, AGGREGATE, Downtime) '+  
    ' Select Top 5 ' + REPLACE(REPLACE(@RPTDowntimeFieldOrder,'~',','),'!null','null') + ', LTrim(RTrim(str(Sum(CONVERT(float,isstops)),9,1))), LTrim(RTrim(str(Sum(CONVERT(float,Duration)),9,1))) ' +  
 ' FROM #Downtimes TDT ' +   
 ' JOIN #PLIDList TPL ON TDT.PU_ID = TPL.ConvUnit ' +   
 ' JOIN #ShiftDESCList TSD ON TDT.Shift = TSD.ShiftDESC ' +  
 ' JOIN #CrewDESCList CSD ON TDT.Crew = CSD.CrewDESC ' +  
 ' JOIN #PLStatusDESCList TPLSD ON TDT.LineStatus = TPLSD.PLStatusDESC '   
  
If NOT (@RPTMinorGroupBy = 'PU_Id' Or @RPTMajorGroupBy = 'PU_Id')   
        Select @SQLString = @SQLString + ' WHERE TDT.Class IN (' + @ClassList + ')'   
  
Select @SQLString = @SQLString + ' GROUP BY ' + REPLACE(REPLACE(REPLACE(@RPTDowntimeFieldOrder,'~',','),'!null,',''), ',!null','') + ' ' +  
 ' Order BY convert(float,sum(isstops)) DESC'  
  
Execute (@SQLString)  
  
Select @SQLString = 'Insert #Top5Stops (Desc01,Downtime, AGGREGATE) ' +  
  ' Select '''+'.'+''', LTrim(RTrim(CONVERT(varchar(50),Sum(CONVERT(float,Downtime))))), LTrim(RTrim(CONVERT(varchar(50),Sum(CONVERT(Float,AGGREGATE))))) ' +  
  ' FROM #Top5Stops ' +  
  ' WHERE SortOrder > 3'  
  
Execute (@SQLString)  
  
  
End  
  
If @RPT_ShowTop5Downtimes = 'TRUE'  
Begin  
Select @SQLString =  
 ' Insert #TOP5Downtime ' +  
  ' (DESC01, DESC02, AGGREGATE, Stops) ' +  
 ' Select TOP 5 ' + REPLACE(REPLACE(@RPTDowntimeFieldOrder,'~',','),'!null','null') + ', LTrim(RTrim(STR(Sum(Duration),10,1))), Sum(IsStops) ' +  
 ' FROM #Downtimes TDT WITH (NOLOCK)' +  
 ' JOIN #PLIDList TPL WITH (NOLOCK) ON TDT.PU_ID = TPL.ConvUnit ' +   
 ' JOIN #ShiftDESCList TSD WITH (NOLOCK) ON TDT.Shift = TSD.ShiftDESC ' +  
 ' JOIN #CrewDESCList CSD WITH (NOLOCK) ON TDT.Crew = CSD.CrewDESC ' +  
 ' JOIN #PLStatusDESCList TPLSD WITH (NOLOCK) ON TDT.LineStatus = TPLSD.PLStatusDESC '   
  
If NOT (@RPTMinorGroupBy = 'PU_Id' Or @RPTMajorGroupBy = 'PU_Id')   
        Select @SQLString = @SQLString + ' WHERE TDT.Class IN (' + @ClassList + ')'   
  
Select @SQLString = @SQLString + ' GROUP BY ' + REPLACE(REPLACE(REPLACE(@RPTDowntimeFieldOrder,'~',','),'!null,',''), ',!null','') + ' ' +  
 ' Order BY CONVERT(float,Sum(Duration)) DESC'  
  
Execute (@SQLString)  
  
  
Select @SQLString = ' Insert #TOP5Downtime (Desc01,Stops, AGGREGATE) ' +  
  ' Select '''+'.'+''',LTrim(RTrim(CONVERT(varchar(50),Sum(CONVERT(int,Stops))))), LTrim(RTrim(CONVERT(varchar(50),Sum(CONVERT(Float,AGGREGATE))))) ' +  
  ' FROM #TOP5Downtime ' +  
  ' WHERE SortOrder > 3'  
  
Execute (@SQLString)  
End  
  
  
If @RPT_ShowTop5Rejects = 'TRUE' AND @RPTMinorGroupBy <> 'ProdDay'  
Begin  
  
Select @SQLString =  
 ' Insert #TOP5REJECTS ' +  
 ' (DESC01, DESC02, AGGREGATE, Events) ' +  
 ' Select TOP 5 ' + REPLACE(REPLACE(@RPTWasTEFieldOrder,'~',','),'!null','null') + ', Sum(PadCount), sum(nrecords) ' +  
 ' FROM #REJECTS TR ' +  
 ' JOIN #ShiftDESCList TSD ON TR.Shift = TSD.ShiftDESC ' +  
 ' JOIN #CrewDESCList CSD ON TR.Crew = CSD.CrewDESC ' +  
 ' JOIN #PLStatusDESCList TPLSD ON TR.LineStatus = TPLSD.PLStatusDESC ' +  
       ' GROUP BY ' + REPLACE(REPLACE(REPLACE(@RPTWasTEFieldOrder,'~',','),'!null,',''), ',!null','') + ' ' +  
 ' Order BY CONVERT(float,Sum(PadCount)) DESC'  
  
Execute (@SQLString)  
 
Select @SQLString = ' Insert #TOP5REJECTS (Events, AGGREGATE) ' +  
  ' Select LTrim(RTrim(CONVERT(varchar(50),Sum(CONVERT(int,Events))))), LTrim(RTrim(CONVERT(varchar(50),Sum(CONVERT(Float,AGGREGATE))))) ' +  
  ' FROM #TOP5REJECTS ' +  
  ' WHERE SortOrder > 3'  
  
Execute (@SQLString)  
End  
  
-- FRio :   
-- Select * FROM #top5downtime  
-- Select * FROM #top5stops  
-- Select * FROM #top5rejects  
-------------------------------------------------------------------------------------------------------  
-- POPULATE OUTPUT Tables:  
-------------------------------------------------------------------------------------------------------  
-- Select pu_id,Sum(datediff(s,starttime,endtime)/60.0) FROM #Status group by pu_id  
-- Select * FROM #Status WHERE pu_id = 968 order by starttime  
-- Select * FROM #Status --WHERE pu_id = 1000 order by starttime  
-- Build Temporary tables to get the Products for calculating #uptimes downtimes  
-------------------------------------------------------------------------------------------------------  
-- POPULATE OUTPUT Tables: Some data For Top 5 Downtime  
-------------------------------------------------------------------------------------------------------  
-- Select * FROM #TempProdSched  
-- Select * FROM @Product_Specs  
  
-- For Testing
--select * from @ClassREInfo
--select '@Product_Specs',* from @Product_Specs
  
Truncate Table #Temporary  
Declare   
  @ClassCounter as int,  
  @ConvVar as nvarchar(100)  
   
  
 Set @ClassCounter = 1  
  
 While @ClassCounter <= (Select Max(Class) FROM @ClassREInfo)  
  
  Begin  
  
   Select @ConvVar = Conversion FROM @ClassREInfo WHERE Class = @ClassCounter  
     
   Insert #Temporary (TempValue1,TempValue2)  
   Exec SPCMN_ReportCollectionParsing  
   @PRMCollectionString = @ConvVar, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ';',   
   @PRMDataType01 = 'nvarchar(200)'  
  
   Insert Into @Conv_Class_Prod (Class,Prod_Id,Value)  
   Select @ClassCounter as Class,Prod_Code,Target FROM #Temporary t  
   JOIN @Product_Specs ps ON CONVERT(varchar,t.TempValue2) = CONVERT(varchar,ps.Spec_Desc)  
     
   -- Select * FROM #Production WHERE Class = @ClassCounter  
     
   Select @ClassCounter = Min(Class) FROM @ClassREInfo WHERE Class > @ClassCounter  
  
   Truncate Table #Temporary  
  
  End  
  
Declare  
  @ConvFactor  as  float  
  
Declare ConvCursor Insensitive Cursor For   
   (Select Class, Prod_Id, Value FROM @Conv_Class_Prod) Order By Class, Prod_Id  
  
Open ConvCursor  
  
FETCH NEXT FROM ConvCursor  into @ClassNo,@Prod_Id, @Value  
  
While @@Fetch_Status = 0   
Begin  
   
 UPDATE #Production  
  Set ConvFactor = ConvFactor * @Value  
 WHERE Class = @ClassNo AND Product = @Prod_Id  
  
 FETCH NEXT FROM ConvCursor  into @ClassNo,@Prod_Id,@Value  
  
End  

-- For Testing
--select 'set ConvFactor ', ConvFactor, @Value, *	from #Production
  
Close ConvCursor  
Deallocate ConvCursor  

-- Select LineStatus,datediff(ss,starttime,endtime)/60,* FROM #Production --WHERE pu_id = 118  
-- Select * FROM #Downtimes WHERE class = 2 Order By pu_id, start_time  
-- Select ProdDay,* FROM #Downtimes Order by start_time  
 
If @RPTMajorGroupBy <> @RPTMinorGroupBy  
        Insert Into @Cursor (Major_id,Major_desc,Minor_id,Minor_desc,Major_Order_by,Minor_Order_by)  
        Select distinct Major_id,Major_Desc,'ZZZ','ZZZ',Major_Order_by,99 FROM @Cursor  
Else  
        UPDATE @Cursor Set Minor_id = 'ZZZ',Minor_Desc = 'ZZZ'   

------------------------------------------------------------------------------------------------------------------------  
-- Populate ac_Top5Downtimes cursor  
------------------------------------------------------------------------------------------------------------------------  
Select @FIELD1 = SUBString(@RPTDowntimeFieldOrder, 1,CHARINDEX('~',@RPTDowntimeFieldOrder)-1)  
Select @FIELD2 = SUBString(@RPTDowntimeFieldOrder, CHARINDEX('~',@RPTDowntimeFieldOrder)+1,255)  
  
Insert Into #ac_Top5Downtimes (SortOrder, DESC01, DESC02)  
Select SortOrder, DESC01, DESC02  
  FROM #TOP5Downtime  
  WHERE SortOrder > 3 AND SortOrder < 9  
  
If @FIELD1 <> '!null'  
Begin  
UPDATE #ac_Top5Downtimes  
        Set WHEREString1 = (Case IsNull(DESC01,'xyz') When 'xyz' then CONVERT(nvarchar,@FIELD1 + ' IS null') else CONVERT(nvarchar(200),@FIELD1 + ' = ''' + DESC01 + '''') end)  
End  
  
If @FIELD2 <> '!null'  
Begin  
UPDATE #ac_Top5Downtimes  
        Set WHEREString2 = (Case IsNull(DESC02,'xyz') When 'xyz' then CONVERT(nvarchar,@FIELD2 + ' IS null') else CONVERT(nvarchar(200),@FIELD2 + ' = ''' + DESC02 + '''') end)  
End  
  
------------------------------------------------------------------------------------------------------------------------  
-- Populate ac_Top5Stops cursor  
------------------------------------------------------------------------------------------------------------------------  
  
Insert Into #ac_Top5Stops (SortOrder, DESC01, DESC02)  
Select DISTINCT SortOrder, DESC01, DESC02  
  FROM #TOP5Stops  
  WHERE SortOrder > 3 AND SortOrder < 9  
  
  
If @FIELD1 <> '!null'  
Begin  
UPDATE #ac_Top5Stops  
        Set WHEREString1 = (Case IsNull(DESC01,'xyz') When 'xyz' then CONVERT(nvarchar,@FIELD1 + ' IS Null') else CONVERT(nvarchar(200),@FIELD1 + ' = ''' + DESC01 + '''') end)  
End  
  
  
If @FIELD2 <> '!null'  
Begin  
UPDATE #ac_Top5Stops  
        Set WHEREString2 = (Case IsNull(DESC02,'xyz') When 'xyz' then CONVERT(nvarchar,@FIELD2 + ' IS Null') else CONVERT(nvarchar(200),@FIELD2 + ' = ''' + DESC02 + '''') end)  
End  
  
------------------------------------------------------------------------------------------------------------------------  
-- Populate ac_Top5Rejects cursor  
------------------------------------------------------------------------------------------------------------------------  
Declare   
             @FIELD1Waste as nvarchar(50),  
             @FIELD2Waste as nvarchar(50)  
  
Select @FIELD1Waste = SUBString(@RPTWasTEFieldOrder, 1,CHARINDEX('~',@RPTWasTEFieldOrder)-1)  
Select @FIELD2Waste = SUBString(@RPTWasTEFieldOrder, CHARINDEX('~',@RPTWasTEFieldOrder)+1,255)  
  
Insert Into #ac_Top5Rejects (SortOrder, DESC01, DESC02)  
Select SortOrder, DESC01, DESC02  
  FROM #TOP5Rejects  
  WHERE SortOrder > 3 AND SortOrder < 9  
  
If @FIELD1Waste <> '!null'  
Begin  
UPDATE #ac_Top5Rejects  
        Set WHEREString1 = (Case IsNull(DESC01,'xyz') When 'xyz' then CONVERT(nvarchar,@FIELD1Waste + ' IS null') else CONVERT(nvarchar(200),@FIELD1Waste + ' = ''' + DESC01 + '''') end)  
End  
  
If @FIELD2Waste <> '!null'  
Begin  
UPDATE #ac_Top5Rejects  
        Set WHEREString2 = (Case IsNull(DESC02,'xyz') When 'xyz' then CONVERT(nvarchar,@FIELD2Waste + ' IS null') else CONVERT(nvarchar(200),@FIELD2Waste + ' = ''' + DESC02 + '''') end)  
End  
  
  
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  
-- FRio : NOTE , Start of cursor for filling #TEMPORARY TABLES  
--Print convert(varchar(25), getdate(), 120) + 'BEFORE GOING INTO THE CURSOR !!'  
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  

-- jpg
--Select 'Loop Cursor', Major_id, Major_desc,Major_Order_by,Minor_id, Minor_desc,Minor_Order_by  FROM @Cursor

-- Select * FROM #Summary  
Set @i = (Select Min(Cur_id) FROM @Cursor)  
Declare   
 @WHEREString as nvarchar(1000),  
    @GroupByString as nvarchar(500),  
 @Active_Class as int,  
 @Prev_Value as nvarchar(100)  
  
Set @Prev_Value = ''			
  
        Declare RSMiCursor Insensitive Cursor For ( 
				Select	Major_id, 
						Major_desc, 
						Major_Order_by,
						Minor_id, 
						Minor_desc,
						Minor_Order_by  FROM @Cursor)   
                ORDER BY Major_Order_by,Major_Desc,Minor_Order_by,effectivedate,Minor_Desc	         
   
  Open RSMiCursor  
  
  FETCH NEXT FROM RSMiCursor into @MajGroupValue, @MajGroupDesc,@MajOrderby,@MinGroupValue, @MinGroupDesc,@MinOrderby
  
  WHILE  @@FETCH_Status = 0 AND @i <=100  
    -- @i <= (Select Max(cur_id) FROM @Cursor) Or @i > 100  
  BEGIN  
  /*  
  Select  @MajGroupValue = Major_id,   
    @MajGroupDesc = Major_desc,  
    @MajOrderby = Major_Order_by,  
    @MinGroupValue = Minor_id,   
    @MinGroupDesc = Minor_desc,  
    @MinOrderby = Minor_Order_by    
  FROM @Cursor  
  WHERE Cur_Id = @i  
  */  
                
  Set @Active_Class = NULL  
    
  If @RPTMajorGroupBy = 'PU_ID'  
   Select @Active_Class = Class FROM @Class WHERE PU_Id = @MajGroupValue  
  Else   
   If @RPTMinorGroupBy = 'PU_ID' AND @MinGroupValue <> 'ZZZ'  
    Select @Active_Class = Class FROM @Class   
                                WHERE PU_Id = @MinGroupValue  
     
  -- Select @MajGroupValue,@MinGroupValue,@Active_Class    
                ----------------------------------------------------------------------------------------------  
  
  ----------------------------------------------------------------------------  
  -- POPULATE OUTPUT Tables: Some data For Top 5 Downtimes  
  ----------------------------------------------------------------------------   
  
          Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'LineStops')  
         Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'LineStops')  
                Set @GROUPBYString = ' Group by DESC01, DESC02'  
                                                       
                        IF @RPTMajorGroupBy = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID'  
   BEGIN  
   Select @SQLString = 'Select ac.desc01,ac.desc02,STR(Sum(Duration),6,1) '+  
     'FROM #Downtimes TDT'  
     + ' JOIN #PLIDList TPL ON TDT.PU_ID = TPL.ConvUnit'          
     + ' JOIN #ShiftDESCList TSD ON TDT.Shift = TSD.ShiftDESC'  
     + ' JOIN #CrewDESCList CSD ON TDT.Crew = CSD.CrewDESC'  
     + ' JOIN #PLStatusDESCList TPLSD ON TDT.LineStatus = TPLSD.PLStatusDESC'  
                                        + ' JOIN #ac_Top5Downtimes ac ON IsNull(ac.desc01,''' +'xyz' +''') = IsNull(tdt.'+@FIELD1+', ''' + 'xyz' + ''')'  
                                        If @FIELD2 <> '!null'  
                                              Select @SQLString = @SQLString + ' AND IsNull(ac.desc02,''' +'xyz' +''') = IsNull(tdt.'+@FIELD2+', ''' + 'xyz' + ''')'  
  
  
     Select @SQLString = @SQLString + ' WHERE TDT.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''  
       
     if (@MinGroupValue <> 'ZZZ' AND @MinGroupValue <> '999')  
      Select @SQLString = @SQLString + ' AND TDT.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
     Select @SQLString = @SQLString + @GROUPBYString  
                        END  
                        ELSE  
                        BEGIN  
                        Select @SQLString = 'Select ac.desc01,ac.desc02,STR(Sum(Duration),6,1) '+  
     'FROM #Downtimes TDT'  
     + ' JOIN #PLIDList TPL ON TDT.PU_ID = TPL.ConvUnit'          
     + ' JOIN #ShiftDESCList TSD ON TDT.Shift = TSD.ShiftDESC'  
     + ' JOIN #CrewDESCList CSD ON TDT.Crew = CSD.CrewDESC'  
     + ' JOIN #PLStatusDESCList TPLSD ON TDT.LineStatus = TPLSD.PLStatusDESC'  
                                        + ' JOIN #ac_Top5Downtimes ac ON IsNull(ac.desc01,''' +'xyz' +''') = IsNull(tdt.'+@FIELD1+', ''' + 'xyz' + ''')'  
                                        If @FIELD2 <> '!null'  
                                              Select @SQLString = @SQLString + ' AND IsNull(ac.desc02,''' +'xyz' +''') = IsNull(tdt.'+@FIELD2+', ''' + 'xyz' + ''')'  
  
     Select @SQLString = @SQLString + ' WHERE TDT.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''  
                                        + ' AND tdt.Class In (' + @ClassList + ')'  
       
     if (@MinGroupValue <> 'ZZZ' AND @MinGroupValue <> '999')  
      Select @SQLString = @SQLString + ' AND TDT.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
                                 Select @SQLString = @SQLString + @GROUPBYString  
  
                        END  
                          
   --  
   TRUNCATE Table #TEMPORARY  
  
            --           print 'Top 5 ' + @SQLString  
  
   Insert #Temporary(TempValue1,TempValue2,TempValue3)  
   Execute (@SQLString)  
  
                        
          Select @SQLString =     ' UPDATE #TOP5Downtime ' +  
             ' Set Value' + CONVERT(varchar,@i) + ' = CONVERT(varchar,t.TEMPValue3)' +  
                                                ' FROM #Top5Downtime tdt ' +  
                                                ' JOIN #Temporary t ON IsNull(tdt.desc01,''' + 'xyz' + ''') = IsNull(t.TempValue1,''' + 'xyz' + ''')'    
                                                If @FIELD2 <> '!null'  
                                                    Select @SQLString = @SQLString + ' AND IsNull(tdt.desc02,''' + 'xyz' + ''') = IsNull(t.TempValue2,''' + 'xyz' + ''')'    
                                                Select @SQLString = @SQLString + ' WHERE Sortorder > 3 '   
              
   Execute (@SQLString)  
                                                      
          Select @TEMPValue = Sum(CONVERT(float,TEMPValue3)) FROM #TEMPORARY   
  
          Select @SQLString =  'UPDATE #TOP5Downtime ' +  
           'Set Value' + CONVERT(varchar,@i) + ' = ''' + CONVERT(varchar,@TEMPValue) + '''' +  
           'WHERE SortOrder = 9'   
          Execute (@SQLString)  
  
  ----------------------------------------------------------------------------  
  -- POPULATE OUTPUT Tables: Some data For Top 5 Stops  
  ----------------------------------------------------------------------------   
  
         IF @RPTMajorGroupBy = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID'  
   BEGIN  
   Select @SQLString = 'Select ac.desc01,ac.desc02,Count(*) '+  
     'FROM #Downtimes TDT'  
     + ' JOIN #PLIDList TPL ON TDT.PU_ID = TPL.ConvUnit'           
     + ' JOIN #ShiftDESCList TSD ON TDT.Shift = TSD.ShiftDESC'  
     + ' JOIN #CrewDESCList CSD ON TDT.Crew = CSD.CrewDESC'  
     + ' JOIN #PLStatusDESCList TPLSD ON TDT.LineStatus = TPLSD.PLStatusDESC'  
                                         + ' JOIN #ac_Top5Stops ac ON IsNull(ac.desc01,''' +'xyz' +''') = IsNull(tdt.'+@FIELD1+', ''' + 'xyz' + ''')'  
                                        If @FIELD2 <> '!null'  
                                              Select @SQLString = @SQLString + ' AND IsNull(ac.desc02,''' +'xyz' +''') = IsNull(tdt.'+@FIELD2+', ''' + 'xyz' + ''')'  
  
  
     Select @SQLString = @SQLString + ' WHERE TDT.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''  
     + ' AND IsStops = 1 '  
  
     if (@MinGroupValue <> 'ZZZ' AND @MinGroupValue <> '999')  
      Select @SQLString = @SQLString + ' AND TDT.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
     Select @SQLString = @SQLString + @GROUPBYString  
                        END  
                        ELSE  
                        BEGIN  
                        Select @SQLString = 'Select ac.desc01,ac.desc02,Count(*) '+  
     'FROM #Downtimes TDT'  
     + ' JOIN #PLIDList TPL ON TDT.PU_ID = TPL.ConvUnit'      
     + ' JOIN #ShiftDESCList TSD ON TDT.Shift = TSD.ShiftDESC'  
     + ' JOIN #CrewDESCList CSD ON TDT.Crew = CSD.CrewDESC'  
     + ' JOIN #PLStatusDESCList TPLSD ON TDT.LineStatus = TPLSD.PLStatusDESC'  
                                        + ' JOIN #ac_Top5Stops ac ON IsNull(ac.desc01,''' +'xyz' +''') = IsNull(tdt.'+@FIELD1+', ''' + 'xyz' + ''')'  
                                        If @FIELD2 <> '!null'  
                                              Select @SQLString = @SQLString + ' AND IsNull(ac.desc02,''' +'xyz' +''') = IsNull(tdt.'+@FIELD2+', ''' + 'xyz' + ''')'  
  
     Select @SQLString = @SQLString + ' WHERE TDT.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''  
                                        + ' AND tdt.Class In (' + @ClassList + ') AND IsStops = 1 '  
       
     if (@MinGroupValue <> 'ZZZ' AND @MinGroupValue <> '999')  
      Select @SQLString = @SQLString + ' AND TDT.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
                                 Select @SQLString = @SQLString + @GROUPBYString  
  
                        END  
                          
   --  
   TRUNCATE Table #TEMPORARY  
  
            -- Print @SQLString  
  
   Insert #Temporary(TempValue1,TempValue2,TempValue3)  
   Execute (@SQLString)    
                         
          Select @SQLString =     ' UPDATE #TOP5Stops ' +  
             ' Set Value' + CONVERT(varchar,@i) + ' = CONVERT(varchar,t.TEMPValue3)' +  
                                                ' FROM #Top5Stops tdt ' +  
                                                ' JOIN #Temporary t ON IsNull(tdt.desc01,''' + 'xyz' + ''') = IsNull(t.TempValue1,''' + 'xyz' + ''')'    
                                                If @FIELD2 <> '!null'  
                                                    Select @SQLString = @SQLString + ' AND IsNull(tdt.desc02,''' + 'xyz' + ''') = IsNull(t.TempValue2,''' + 'xyz' + ''')'    
                                                Select @SQLString = @SQLString + ' WHERE Sortorder > 3 '   
              
   Execute (@SQLString)  
                                                      
          Select @TEMPValue = Sum(CONVERT(float,TEMPValue3)) FROM #TEMPORARY   
  
          Select @SQLString =  'UPDATE #TOP5Stops ' +  
           'Set Value' + CONVERT(varchar,@i) + ' = ''' + CONVERT(varchar,@TEMPValue) + '''' +  
           'WHERE SortOrder = 9'   
          Execute (@SQLString)  
  
  
                 ----------------------------------------------------------------------------  
                 -- POPULATE OUTPUT Tables: Some data For Top 5 Reject  
                 ----------------------------------------------------------------------------   
  
   Select @SQLString = 'Select t.desc01,Sum(CONVERT(int,PadCount)) '+  
    ' FROM #REJECTS r ' +  
    + ' JOIN #PLIDList TPL ON r.PU_ID = TPL.ConvUnit'      
    + ' JOIN #ShiftDESCList TSD ON r.Shift = TSD.ShiftDESC'  
    + ' JOIN #CrewDESCList CSD ON r.Crew = CSD.CrewDESC'  
    + ' JOIN #PLStatusDESCList TPLSD ON r.LineStatus = TPLSD.PLStatusDESC'  
                +               ' JOIN #ac_Top5Rejects t ON r.Reason1 = t.desc01 ' +  
                                ' WHERE r.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''  
  
   If @MinGroupValue <> 'ZZZ' AND @RPTMinorGroupBy <> 'ProdDay'  
      Select @SQLString = @SQLString + ' AND r.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
   Select @SQLString = @SQLString + ' Group By t.desc01'  
  
   TRUNCATE Table #TEMPORARY  
   Insert #TEMPORARY(TEMPValue1,TempValue2)  
   Execute (@SQLString)  
  
     
   Select @SQLString =     ' UPDATE #TOP5Rejects ' +  
             ' Set Value' + CONVERT(varchar,@i) + ' = CONVERT(varchar,t.TEMPValue2)' +  
                                                ' FROM #Top5Rejects tdt ' +  
                                                ' JOIN #Temporary t ON tdt.desc01 = t.TempValue1 '  
  
  Select @SQLString = @SQLString + ' WHERE Sortorder > 3 '   
              
   Execute (@SQLString)  
                                                      
          Select @TEMPValue = Sum(CONVERT(float,TEMPValue2)) FROM #TEMPORARY   
  
          Select @SQLString =  'UPDATE #TOP5Rejects ' +  
           'Set Value' + CONVERT(varchar,@i) + ' = ''' + CONVERT(varchar,@TEMPValue) + '''' +  
           'WHERE SortOrder = 9'   
          Execute (@SQLString)  
         
                ----------------------------------------------------------------------------  
                -- POPULATE OUTPUT Tables: Some data For Summary #InvertedSummary  
                -- using an Inverted Table to help with the work.  will transpose later  
                ----------------------------------------------------------------------------  
  
 Select   
  @SumGroupBy   = 'Value' + CONVERT(Varchar(25),@i),   
     @SumLineStops   = Null,   
        @SumLineStopsERC    = Null,  
  @SumACPStops   = Null,  
  @SumDowntime   = Null,   
        @SumDowntimeERC     = Null,  
  @SumUptime       = Null,   
  @SumFalseStarts  = Null,  
  @SumTotalSplices  = Null,   
  @SumSUCSplices   = Null,   
  @SumTotalClass1  = Null,  
  @SumTotalPads   = Null,   
  @SumUptimeGreaterT  = Null,    
  @SumNumEdits   = Null,   
       @SumNumEditsR1      = Null,  
        @SumNumEditsR2      = Null,  
        @SumNumEditsR3      = Null,  
  @SumSurvivalRate = Null,   
  @SumGoodClass1   = Null,   
  @SumGoodPads  = Null,  
  @SumTotalCases   = Null  
  
  
 --***************************************************************************************************  
 -- FIRST STEP : CALCULATE ALL DEFINED VARIABLES  
 --***************************************************************************************************  
 -------------------------------------------------------------------------------------------------------------  
 -- ProdTime  
 -- Getting the SCHEDULED TIME -> @defScheduledTime  
 DECLARE   
    @STNUSQLString    NVARCHAR(4000)  
  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'ProdTime')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'ProdTime')  
  
 IF @RPTMinorGroupBy NOT IN ('Product')   
 BEGIN  
  IF @MinGroupValue <> 'ZZZ'  
            IF (@RPTMinorGroupBy = 'PU_ID' OR @RPTMajorGroupBy = 'PU_ID' )  
   BEGIN  
     -- ProdTime  
     Select @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +  
                          ' mt.Pu_Id FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                          ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
     -- STNU  
     SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                 + ' GROUP BY mt.PU_Id'   
     -- ProdTime  
              SELECT @SQLString = @SQLString      +     ' Group by mt.pu_id'   
   END  
      ELSE  
   BEGIN  
     SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +   
                          ' mt.pu_id' +   
        ' FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
        ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                          ' AND mt.Class IN (' + @ClassList + ')'   
     -- STNU  
     SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                 + ' GROUP BY mt.PU_Id'   
     -- ProdTime  
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
   END  
  ELSE  
      IF @RPTMajorGroupBy = 'PU_ID'  
   BEGIN   
     SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +  
                          ' mt.Pu_Id FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
     -- STNU  
     SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                 + ' GROUP BY mt.PU_Id'   
     -- ProdTime  
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
   END  
      ELSE  
   BEGIN  
     SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime), ' +  
        ' mt.pu_id ' +   
        ' FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
        ' AND mt.Class IN (' + @ClassList + ')'   
     -- STNU  
     SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                 + ' GROUP BY mt.PU_Id'   
     -- ProdTime  
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
   END  
 END  
 ELSE  
 BEGIN  
  -- GROUPING BY PRODUCT  
  IF @MinGroupValue <> 'ZZZ'   
                        IF (@RPTMajorGroupBy  = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID')  
      BEGIN  
                           SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +   
                                   ' mt.pu_id ' +  
                                   ' FROM #Production mt ' +  
           ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
           ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
           ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
           ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +   
           ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
         -- STNU  
         SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                     + ' GROUP BY mt.PU_Id'   
         -- ProdTime  
                  SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
      END  
  
      ELSE  
      BEGIN  
               SELECT  @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +   
                                   ' mt.pu_id ' +  
                                   ' FROM #Production mt ' +  
           ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
           ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
           ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
           ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +   
           ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                                   ' AND mt.Class IN (' + @ClassList + ')'   
  
         -- STNU  
         SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                     + ' GROUP BY mt.PU_Id'   
         -- ProdTime  
                  SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
                                   -- ' Group By mt.pu_id '   
      END  
  ELSE  
                    IF  @RPTMajorGroupBy = 'PU_ID'  
     BEGIN  
        -- ProdTime  

                                SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),'+  
                                ' mt.pu_id ' +   
                                ' FROM #Production mt ' +  
                       ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                       ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                       ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                       ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
        -- STNU  
        SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                     + ' GROUP BY mt.PU_Id'   
        -- ProdTime  
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'                                   
     END  
                    ELSE  
     BEGIN  
        -- ProdTime  
                       SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),'+  
                                ' mt.pu_id ' +   
                                ' FROM #Production mt ' +  
                       ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                       ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                       ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                       ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                                ' AND mt.Class IN (' + @ClassList + ')'   
        -- STNU  
        SELECT @STNUSQLString = @SQLString + ' AND mt.LineStatus Like ''' + '%STNU%' + ''''   
                     + ' GROUP BY mt.PU_Id'   
        -- ProdTime  
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'                                   
  
     END  
 END  
  
	 -- print 'ProdTime -> ' + @SQLString  
	 -- print 'STNU ->' + @STNUSQLString  
	 --------------------------------------------------------------------------------------------------------------------------------  
	 -- PRODUCTION TIME CALCULATION   
	 --------------------------------------------------------------------------------------------------------------------------------  
	 Truncate Table #Temporary  
	 Insert #Temporary(TEMPValue1,TempValue2,TempValue3)  
	 Execute (@SQLString)  
          
        -- Select @RPTMajorGroupBy,@RPTMinorGroupBy,TempValue1,TempValue2,TempValue3 FROM #Temporary  
  
        Declare @cantUnits as int  
  
        set @cantUnits = (select distinct count(TempValue3) FROM #Temporary)  
  
        If @MinGroupValue = 'ZZZ'  
        Begin  
          Select @Scheduled_Time = Sum(convert(float,TempValue1))/60 FROM #Temporary  
                Select @Scheduled_Time = @Scheduled_Time / @cantUnits  
        End  
        Else  
               Select @Scheduled_Time = Avg(convert(float,TempValue1))/60 FROM #Temporary   
  
        Select @TotalScheduled_Time = Sum(convert(float,TempValue2)) FROM #Temporary   
 
 -------------------------------------------------------------------------------------------------------------  
 -- Calendar Time  
 -------------------------------------------------------------------------------------------------------------  
 IF @RPTMinorGroupBy NOT IN ('Product')   
 BEGIN  
  IF @MinGroupValue <> 'ZZZ'  
            IF (@RPTMinorGroupBy = 'PU_ID' OR @RPTMajorGroupBy = 'PU_ID' )  
   BEGIN  
 
     Select @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +  
                          ' mt.Pu_Id FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                          ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
     -- ProdTime  
              SELECT @SQLString = @SQLString      +     ' Group by mt.pu_id'   
   END  
      ELSE  
   BEGIN  
     SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +   
                          ' mt.pu_id' +   
        ' FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
        ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                          ' AND mt.Class IN (' + @ClassList + ')'   
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
   END  
  ELSE  
      IF @RPTMajorGroupBy = 'PU_ID'  
   BEGIN   
     SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +  
                          ' mt.Pu_Id FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
   END  
      ELSE  
   BEGIN  
     SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime), ' +  
        ' mt.pu_id ' +   
        ' FROM #Production mt ' +  
        ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
        ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
        ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
        ' AND mt.Class IN (' + @ClassList + ')'   
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
   END  
 END  
 ELSE  
 BEGIN  
  -- GROUPING BY PRODUCT  
  IF @MinGroupValue <> 'ZZZ'   
                        IF (@RPTMajorGroupBy  = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID')  
      BEGIN  
                           SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +   
                                   ' mt.pu_id ' +  
                                   ' FROM #Production mt ' +  
           ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
           ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
           ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +   
           ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
                  SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
  
      END  
  
      ELSE  
      BEGIN  
               SELECT  @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),' +   
                                   ' mt.pu_id ' +  
                                   ' FROM #Production mt ' +  
           ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
           ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
           ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +   
           ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                                   ' AND mt.Class IN (' + @ClassList + ')'   
                  SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'   
                                   -- ' Group By mt.pu_id '   
      END  
  ELSE  
                    IF  @RPTMajorGroupBy = 'PU_ID'  
     BEGIN  
        -- ProdTime  

                                SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),'+  
                                ' mt.pu_id ' +   
                                ' FROM #Production mt ' +  
                       ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                       ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                       ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'                                   
     END  
                    ELSE  
     BEGIN  
        -- ProdTime  
                       SELECT @SQLString = 'Select Sum(SchedTime),Sum(SchedTime),'+  
                                ' mt.pu_id ' +   
                                ' FROM #Production mt ' +  
                       ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                       ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                       ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                                ' AND mt.Class IN (' + @ClassList + ')'   
              SELECT @SQLString = @SQLString     + ' Group by mt.pu_id'                                   
  
     END  
 END  
  
	 print 'CalendarTime -> ' + @SQLString  
	 --------------------------------------------------------------------------------------------------------------------------------  
	 -- CALENDAR TIME CALCULATION   
	 --------------------------------------------------------------------------------------------------------------------------------  
	 Truncate Table #Temporary  
	 Insert #Temporary(TEMPValue1,TempValue2,TempValue3)  
	 Execute (@SQLString)  
          
        -- Select @RPTMajorGroupBy,@RPTMinorGroupBy,TempValue1,TempValue2,TempValue3 FROM #Temporary  
  
        SET @cantUnits = (select distinct count(TempValue3) FROM #Temporary)  
  
        If @MinGroupValue = 'ZZZ'  
        Begin  
          Select @CalendarTime = Sum(convert(float,TempValue1))/60 FROM #Temporary   
        End  
        Else  
               Select @CalendarTime = Avg(convert(float,TempValue1))/60 FROM #Temporary   
 
 --------------------------------------------------------------------------------------------------------------------------------  
 -- STAFF TIME NOT USED CALCULATION   
 --------------------------------------------------------------------------------------------------------------------------------  
 TRUNCATE TABLE #Temporary  
 INSERT INTO #Temporary(TEMPValue1,TempValue2,TempValue3)  
 EXECUTE (@STNUSQLString)  
          
        SET @cantUnits = (SELECT DISTINCT COUNT(TempValue3) FROM #Temporary)  
  
        IF @MinGroupValue = 'ZZZ'  
        BEGIN  
          SELECT @STNU = SUM(CONVERT(FLOAT,TempValue1))/60 FROM #Temporary  
                SELECT @STNU = @STNU / @cantUnits  
        END  
        ELSE  
                SELECT @STNU = AVG(CONVERT(FLOAT,TempValue1))/60 FROM #Temporary   
  
        Select @TotalSTNU = SUM(CONVERT(FLOAT,TempValue2)) FROM #Temporary   
  
 -------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- TotalSplices, SucSplices  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'TotalSplices')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'TotalSplices')  
    
 If @MinGroupValue <> 'ZZZ'  
  Select @SQLString = 'Select Sum(nrecords), Sum(SpliceStatus) '+  
  'FROM #Splices mt ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
 Else   
   Select @SQLString = 'Select '+ @Operator + '(nrecords), '+ @Operator + '(SpliceStatus) '+  
   'FROM #Splices mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' -- +   
     
 Truncate Table #Temporary  
 Insert #Temporary (TempValue1, TempValue2)  
 Execute (@SQLString)  
   
 Select @SumTotalSplices = TempValue1, @SumSUCSplices = TempValue2  
 FROM #Temporary  
 -- TotalSplices, SucSplices  
 -------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- Downtime  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'Downtime')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'Downtime')  
    -- Altough the Operator could be 'AVG', will not apply when the report is Major Grouped by Unit  
    If @RPTMajorGroupBy = 'PU_ID'   
                        Set @Operator = 'SUM'  
        --  
 If @MinGroupValue <> 'ZZZ'  
                If (@RPTMinorGroupBy = 'PU_ID' or @RPTMajorGroupBy = 'PU_ID')  
                  Select @SQLString = 'Select SUM(Duration), mt.pu_id' +  
                  ' FROM #Downtimes mt ' +  
                  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' Group By mt.pu_id'  
                Else  
                        Select @SQLString = 'Select SUM(Duration), mt.pu_id ' +  
                  ' FROM #Downtimes mt ' +  
                  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' AND mt.Class IN (' + @ClassList + ')' +  
                        ' Group by mt.pu_id '   
 Else   
  If @RPTMajorGroupBy = 'PU_ID'  
   Select @SQLString = 'Select SUM(Duration), mt.' + @RPTMinorGroupBy +  
   ' FROM #Downtimes mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
            ' Group by mt.' + @RPTMinorGroupBy  
      Else  
   Select @SQLString = 'Select SUM(Duration), mt.pu_id ' +  
   ' FROM #Downtimes mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
   ' AND mt.Class IN (' + @ClassList + ')' +  
                        ' Group by mt.pu_id '  
  
 -- Print 'Up, Down -> ' + @SQLString  
  
 Truncate Table #Temporary  
 Insert #Temporary (TempValue1,TempValue2)  
 Execute (@SQLString)  
  
        -- Select @MajGroupValue,@MinGroupValue,@Operator,* FROM #Temporary  
  
       If @Operator = 'SUM'  
         Select  @SumDowntime = IsNull(Sum(CONVERT(float,TempValue1)),0) FROM #Temporary  
        Else  
            Select  @SumDowntime = IsNull(Avg(CONVERT(float,TempValue1)),0) FROM #Temporary  
  
 -- Downtime  
 -----------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- Uptime  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'Uptime')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'Uptime')  
    -- Altough the Operator could be 'AVG', will not apply when the report is Major Grouped by Unit  
    If @RPTMajorGroupBy = 'PU_ID'   
                        Set @Operator = 'SUM'  
        --  
 If @MinGroupValue <> 'ZZZ'  
                If (@RPTMinorGroupBy = 'PU_ID' or @RPTMajorGroupBy = 'PU_ID')  
                  Select @SQLString = 'Select Str(Sum(SchedTime),12,1), mt.pu_id' +  
                  ' FROM #Production mt ' +  
                  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' Group By mt.pu_id'  
                Else  
                        Select @SQLString = 'Select Str(Sum(SchedTime),12,1), mt.pu_id ' +  
                  ' FROM #Production mt ' +  
                  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
      ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
      ' AND mt.Class IN (' + @ClassList + ')' + ' Group by mt.pu_id '   
 Else   
  If @RPTMajorGroupBy = 'PU_ID'  
   Select @SQLString = 'Select Str(Sum(SchedTime),12,1), mt.' + @RPTMinorGroupBy +  
   ' FROM #Production mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
            ' Group by mt.' + @RPTMinorGroupBy  
      Else  
   Select @SQLString = 'Select Str(Sum(SchedTime),12,1), mt.pu_id ' +  
   ' FROM #Production mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
   ' AND mt.Class IN (' + @ClassList + ')' +  
            ' Group by mt.pu_id '  
  
 -- Print 'Uptime -> ' + @SQLString  
  
 Truncate Table #Temporary  
 Insert #Temporary (TempValue1,TempValue2)  
 Execute (@SQLString)  
  
        -- Select @MajGroupValue,@MinGroupValue,@Operator,* FROM #Temporary  
  
       If @Operator = 'SUM'  
         Select  @SumUptime = IsNull(Sum(CONVERT(float,TempValue1))/60,0) FROM #Temporary  
        Else  
            Select  @SumUptime = IsNull(Avg(CONVERT(float,TempValue1))/60,0) FROM #Temporary  
    
  Select @SumUptime = Str(CONVERT(Float,@SumUptime) - CONVERT(Float,@SumDowntime),12,1)    
  
 -- Uptime  
 -----------------------------------------------------------------------------------------------------------------  
     
    -------------------------------------------------------------------------------------------------------------  
 -- ERC Downtime  (Arido)
 -- AND Planned Downtime --> Downtime
	DECLARE @SQLStrPlanned     NVARCHAR(4000)  
	Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'Downtime')  
	-- Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'DowntimeERC')  
	Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'Downtime')  

    -- Altough the Operator could be 'AVG', will not apply when the report is Major Grouped by Unit  
    If @RPTMajorGroupBy = 'PU_ID'   
		Set @Operator = 'SUM'  
    --  
	If @MinGroupValue <> 'ZZZ'  
			begin
               If (@RPTMinorGroupBy = 'PU_ID' or @RPTMajorGroupBy = 'PU_ID')  
                  Select @SQLString = 'Select '+ @Operator + ' (Duration)' +  
                  ' FROM #Downtimes mt ' +  
                  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
                Else  
                        Select @SQLString = 'Select '+ @Operator + '(Duration)' +  
                  ' FROM #Downtimes mt ' +  
                  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
                  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
                  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' AND mt.Class IN (' + @ClassList + ')'   

				--select '@SQLString (PU_ID + ZZZ)', @SQLString
				--exec (@SQLString)
			end
		Else   
		BEGIN
			If @RPTMajorGroupBy = 'PU_ID'  
				Select @SQLString = 'Select '+ @Operator + '(Duration) ' +  
				   ' FROM #Downtimes mt ' +  
				   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
				   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
				   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
					' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
			Else  
			   Select @SQLString = 'Select '+ @Operator + '(Duration) ' +  
			   ' FROM #Downtimes mt ' +  
			   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
			   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
			   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
			   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
			   ' AND mt.Class IN (' + @ClassList + ')'   
		END


	SET @SQLStrPlanned = @SQLString   
	SET @SQLStrPlanned = @SQLStrPlanned + ' AND Tree_Name LIKE ''' + @PlannedStopTreeName + '%'''  
	Set @SQLString = @SQLString + ' AND ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude) '  
  
	Truncate Table #Temporary  

	Insert #Temporary (TempValue1)  
	Execute (@SQLString)  

--	PRINT 'SQLStrPlanned ->' + @SQLStrPlanned  
	Print 'Up, Down -> ' + @SQLString  
  
	--PRINT @SQLString
	-- SELECT '#Temporary', * FROM #Temporary

    Select @SumDowntimeERC = IsNull(Sum(CONVERT(float,TempValue1)),0) FROM #Temporary  
	Select @SumDowntimeERC = CONVERT(Float,@SumDowntime) - CONVERT(Float,@SumDowntimeERC)  
 -- ERC Downtime  
 -- Planned Downtime Duration  
	TRUNCATE TABLE #Temporary  

	INSERT INTO #Temporary (TempValue1)  
	EXECUTE (@SQLStrPlanned)  
  
	Print 'ERC Downtime  -> ' + @SQLString  

	Select @SumPlannedStops = IsNull(Sum(CONVERT(float,TempValue1)),0) FROM #Temporary  
 -- Select @SumPlannedStops = CONVERT(Float,@SumDowntime) - CONVERT(Float,@SumPlannedStops)  
 -----------------------------------------------------------------------------------------------------------------  
  
  
  
    -----------------------------------------------------------------------------------------------------------------  
 -- LineStops, SuccessRate, RepairTimeT, FalseStarts0, FalseStartsT, NumEdits  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'LineStops')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'LineStops')  
  
 Select @SQLString = 'Select mt.' + @RPTMinorGroupBy + ',SUM(Case ' +     
      'When ISStops = 1 THEN 1 Else 0 ' +  
      'End),' + -- Line Stops  
  'SUM(Case ' + -- Survival Rate  
   'When SurvRateUptime > ' + CONVERT(VARCHAR(25),@RPTDowntimesurvivalRate) + ' Then 1 '+  
   'Else 0 ' +  
         'End), ' +  
  'SUM(Case ' +  -- Repair Time   
   'When ISStops = 1 AND Duration > ' + CONVERT(VARCHAR(25),@RPTDowntimeFilterMinutes) +' Then 1 ' +  
   'Else 0 ' +  
      'End), ' +  
  'SUM(Case ' +   -- False Starts  
   'When ISStops = 1 AND Uptime = 0 Then 1 ' +  
   'Else 0 '+  
      'End), ' +  
  'SUM(Case ' +   -- Uptime Greater T  
   'When ISStops = 1 AND Uptime > ' + CONVERT(VARCHAR(25),@RPTFilterMinutes) + ' Then 1 '+  
   'Else 0 ' +  
      'End), '+  
  'SUM(Case ' +   -- Num Edits R4  
   'When ISStops = 1 AND Reason4 IS NOT null Then 1 ' +  
   ' Else 0 ' +  
      'End), ' +    
        'SUM(Case ' +   -- Num Edits R1  
   'When ISStops = 1 AND Reason1 IS NOT null Then 1 ' +  
   ' Else 0 ' +  
      'End), ' +    
        'SUM(Case ' +   -- Num Edits R2  
   'When ISStops = 1 AND Reason2 IS NOT null Then 1 ' +  
   ' Else 0 ' +  
      'End), ' +    
        'SUM(Case ' +   -- Num Edits R3  
   'When ISStops = 1 AND Reason3 IS NOT null Then 1 ' +  
   ' Else 0 ' +  
      'End), ' +    
  'SUM(Case ' +   -- False Starts T  
   'When ISStops = 1 AND Uptime < ' + CONVERT(VARCHAR(25),@RPTFilterMinutes) + ' Then 1 '+  
   'Else 0 ' +  
         ' End) '+  
  ' FROM #Downtimes mt ' +  
  ' JOIN #PLIDList TPL ON mt.PU_ID = TPL.ConvUnit ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC '   
  
 If @MinGroupValue <> 'ZZZ'  
                If (@RPTMajorGroupBy = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID')  
                   Set @SQLString = @SQLString +   
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
                Else   
                         Set @SQLString = @SQLString +   
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' AND mt.Class IN (' + @ClassList + ')'  
 Else   
  If @RPTMajorGroupBy = 'PU_ID'   
    Set @SQLString = @SQLString +   
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
  Else  
   Set @SQLString = @SQLString +   
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
   ' AND mt.Class IN (' + @ClassList + ')'  
  
 Set @SQLSTring = @SQLString + ' Group By mt.' + @RPTMinorGroupBy  
  
 -- print 'LineStops -> ' + @SQLString   
  
 Truncate Table #Temporary  
 Insert #Temporary (TempValue1,TempValue2,TempValue3,TempValue4,TempValue5,TempValue6,  
                       TempValue7,TempValue8,TempValue9,TempValue10,TempValue11)  
 Execute (@SQLString)  
  
 If @Operator = 'SUM'  
    Select @SumLineStops = Sum(IsNull(CONVERT(Float,TempValue2),0)),  
    @SumSurvivalRate = Sum(IsNull(CONVERT(Float,TempValue3),0)),  
    @SumRepairTimeT = Sum(IsNull(CONVERT(Float,TempValue4),0)),  
    @SumFalseStarts = Sum(IsNull(CONVERT(Float,TempValue5),0)),  
    @SumUptimeGreaterT = Sum(IsNull(CONVERT(Float,TempValue6),0)),  
    @SumNumEdits = Sum(IsNull(CONVERT(Float,TempValue7),0)),  
    @SumNumEditsR1 = Sum(IsNull(CONVERT(Float,TempValue8),0)),  
    @SumNumEditsR2 = Sum(IsNull(CONVERT(Float,TempValue9),0)),  
    @SumNumEditsR3 = Sum(IsNull(CONVERT(Float,TempValue10),0)),  
    @SumFalseStartsT = Sum(IsNull(CONVERT(Float,TempValue11),0))  
    FROM #Temporary  
 Else  
     Select @SumLineStops = Avg(IsNull(CONVERT(Float,TempValue2),0)),  
    @SumSurvivalRate = Avg(IsNull(CONVERT(Float,TempValue3),0)),  
    @SumRepairTimeT = Avg(IsNull(CONVERT(Float,TempValue4),0)),  
    @SumFalseStarts = Avg(IsNull(CONVERT(Float,TempValue5),0)),  
    @SumUptimeGreaterT = Avg(IsNull(CONVERT(Float,TempValue6),0)),  
    @SumNumEdits = Avg(IsNull(CONVERT(Float,TempValue7),0)),  
    @SumNumEditsR1 = Avg(IsNull(CONVERT(Float,TempValue8),0)),  
    @SumNumEditsR2 = Avg(IsNull(CONVERT(Float,TempValue9),0)),  
    @SumNumEditsR3 = Avg(IsNull(CONVERT(Float,TempValue10),0)),  
    @SumFalseStartsT = Avg(IsNull(CONVERT(Float,TempValue11),0))  
    FROM #Temporary  
  
 -- LineStops, SurivalRate, RepairTimeT, FalseStarts0, FalseStartsT, NumEdits  
 -------------------------------------------------------------------------------------------------------------  
  
    -----------------------------------------------------------------------------------------------------------------  
 -- ERC LineStops  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'LineStops')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'LineStops')  
   
 Select @SQLString = 'Select mt.' + @RPTMinorGroupBy + ',SUM(Case ' +     
      'When ISStops = 1 THEN 1 Else 0 ' +  
      'End)' + -- Line Stops  
  ' FROM #Downtimes mt ' +  
  ' JOIN #PLIDList TPL ON mt.PU_ID = TPL.ConvUnit ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC '   
  
 If @MinGroupValue <> 'ZZZ'  
                If (@RPTMajorGroupBy = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID')  
                   Set @SQLString = @SQLString +   
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
                Else   
                         Set @SQLString = @SQLString +   
                  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' AND mt.Class IN (' + @ClassList + ')'  
 Else   
  If @RPTMajorGroupBy = 'PU_ID'   
    Set @SQLString = @SQLString +   
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
  Else  
   Set @SQLString = @SQLString +   
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
   ' AND mt.Class IN (' + @ClassList + ')'  
  
   
    Set @SQLString = @SQLString + ' AND ERC_Desc IN (Select ERC_Desc FROM #ReasonsToExclude) '  
 Set @SQLSTring = @SQLString + ' Group By mt.' + @RPTMinorGroupBy  
    -- print 'ERC LineStops -> ' + @SQLString   
    

 Truncate Table #Temporary  
 Insert #Temporary (TempValue1,TempValue2)  
 Execute (@SQLString)  
   
 -- select * from #Temporary  
  
 If @Operator = 'SUM'  
  Select @SumLineStopsERC = ISNULL(Sum(CONVERT(Float,TempValue2)),0) FROM #Temporary   
 Else  
  Select @SumLineStopsERC = ISNULL(Avg(CONVERT(Float,TempValue2)),0) FROM #Temporary   
  
 Select @SumLineStopsERC = CONVERT(Float,@SumLineStops) - CONVERT(Float,@SumLineStopsERC)  

 -- LineStops, SurivalRate, RepairTimeT, FalseStarts0, FalseStartsT, NumEdits  
 -------------------------------------------------------------------------------------------------------------  
  
 -------------------------------------------------------------------------------------------------------------  
 -- ACP stops  
    Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'ACPStops')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'ACPStops')  
  
 Select @SQLString = 'Select '+ @Operator +'(convert(float,ISStops)) '+   
 ' FROM #Downtimes mt ' +  
 ' JOIN #PLIDList TPL ON mt.PU_ID = tpl.convunit '  +   
    -- ' JOIN @Class c ON mt.PU_ID = c.pu_id ' +  
 ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC ' +   
 ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC ' +  
 ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
 ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' + -- 1/13/03 JJR Added to account for Prod_Code vs. Prod_Desc  
    ' AND mt.Class IN (' + @ClassList + ')'  
   
 If @MinGroupValue <> 'ZZZ'  
  Select @SQLString = @SQLString + ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
  
 TRUNCATE Table #Temporary  
 Insert #Temporary (TempValue1)  
 Execute (@SQLString)  
  
    -- print 'ACPStops ' + @SQLString  
  
 Select @SumACPStops = TempValue1 FROM #Temporary  
 Select @SumACPStopsPerDay = (CONVERT(Float,@SumACPStops) / (convert(float,@Scheduled_Time) / 1440)) --(CONVERT(Float,@SumUptime) + CONVERT(Float,@SumDowntime))  
 -- ACP stops  
 -------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- TotalProduct  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'TotalPads')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'TotalPads')  

-- 	For Testing
--select 'Operator ' + @Operator
  
-- jpg
--select @MinGroupValue MinGroupValue, @RPTMajorGroupBy RPTMajorGroupBy, @RPTMinorGroupBy RPTMinorGroupBy

If @MinGroupValue <> 'ZZZ'  
	If @RPTMajorGroupBy = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID'  
		Select @SQLString = 'Select CONVERT(FLOAT ,Sum(TotalPad * ConvFactor ))' +  
	      ' FROM #Production mt ' +    
		  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
		  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
		  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
		  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
		  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
    Else  
  		Select @SQLString = 'Select CONVERT(FLOAT ,Sum(TotalPad * ConvFactor )) ' +               
  		' FROM #Production mt ' +  
  		' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
		' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
		' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
		' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
		' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
		' AND mt.Class IN (' + @ClassList + ')'  
Else  
    If @RPTMajorGroupBy = 'PU_ID'  
		Select @SQLString = 'Select CONVERT(FLOAT ,Sum(TotalPad * ConvFactor ))' +  
            ' FROM #Production mt ' +  
  			' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  			' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  			' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  			' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
	Else   
  		Select @SQLString = 'Select CONVERT(FLOAT  ,'+ @Operator +'(TotalPad * ConvFactor)) ' +           
  			' FROM #Production mt ' +  
  			' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  			' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  			' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  			' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
  			' AND mt.Class IN (' + @ClassList + ')'  
   

	Print 'Total Product ->' + @SQLString  

	-- jpg
	Truncate Table #TemporaryFloat  
--	Truncate Table #Temporary  
	Insert 	#TemporaryFloat (TempValue1)  
		Execute (@SQLString)
	--Insert #Temporary (TempValue1)  
	--	Execute (@SQLString)

	 Select @SumTotalPads = CONVERT(INTEGER,ISNULL(TempValue1,0))  FROM #TemporaryFloat  
	 -- TotalProduct  
	
	-- jpg changed to avoid rounded
	--select '#TemporaryFloat', * from #TemporaryFloat

	-- For Testing
	-- jpg
	--If @MinGroupValue <> 'ZZZ'  
	--	Select 'testing', mt.PLID, mt.PU_ID, mt.Shift, mt.Crew, mt.LineStatus
	--		Product, Product_Size, TotalPad, ConvFactor, TotalPad * ConvFactor as pads_X_conv, @SumTotalPads SumTotalPads,
	--		CONVERT(FLOAT, @SumTotalPads) AS SumTotalPadsNEW
	--		--CONVERT(INTEGER,Sum(TotalPad * ConvFactor )) 
 -- 			FROM #Production mt 
 -- 			JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC
	--		JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC  
	--		JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC 
	--		WHERE mt.PU_ID = 754
	--			AND TotalPad > 0 AND ConvFactor > 0

 -------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- GoodProduct  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'GoodPads')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'GoodPads')  
   
 If @MinGroupValue <> 'ZZZ'   
          If @RPTMajorGroupBy = 'PU_ID' Or @RPTMinorGroupBy = 'PU_ID'  
  Select @SQLString = 'Select  Sum( ' +
  ' CONVERT(FLOAT,(TotalPad * ConvFactor) - isnull(RunningScrap * ConvFactor,0) - isnull(Stopscrap * ConvFactor,0)) ' +  
  ' ),' +  
                ' Sum(Case ProdPerStat WHEN 0 THEN 0 ' +  
  '  ELSE  ' +            
           ' (IsNull(TotalPad * ConvFactor ,0) - IsNull(RunningScrap * ConvFactor,0) - IsNull(Stopscrap * ConvFactor,0)) / ProdPerStat / 1000  ' +                       
         ' END),' +  
                ' SUM(CONVERT(INTEGER,(TotalPad)-IsNull(RunningScrap,0)-IsNull(Stopscrap,0)-IsNull(ConvFactor * TotalCases,0)))' +  
  ' FROM #Production mt ' +  
                ' JOIN #PLIDList PL ON PL.ConvUnit = mt.PU_Id ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
    Else  
  Select @SQLString = 'Select Sum( ' +  
   'CONVERT(FLOAT,(TotalPad * ConvFactor) - isnull(RunningScrap * ConvFactor,0) - isnull(Stopscrap * ConvFactor,0)) ' +  
   '),' +  
                ' Sum(CASE ProdPerStat WHEN 0 THEN 0 ' +  
  '  ELSE  ' +  
          ' (IsNull(TotalPad * ConvFactor ,0) - IsNull(RunningScrap * ConvFactor,0) - IsNull(Stopscrap * ConvFactor,0)) / ProdPerStat / 1000  ' +                      
         ' END),' +  
                ' SUM(CONVERT(INTEGER,(TotalPad)-IsNull(RunningScrap,0)-IsNull(Stopscrap,0)-IsNull(ConvFactor*TotalCases,0)))' +  
  ' FROM #Production mt ' +  
                ' JOIN #PLIDList PL ON PL.ConvUnit = mt.PU_Id ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
  ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
  ' AND mt.Class IN (' + @ClassList + ')'  
 Else  
    If @RPTMajorGroupBy = 'PU_ID' -- or @RPTMinorGroupBy = 'PU_ID'  
       Select @SQLString = 'Select Sum( ' +  
   ' CONVERT(FLOAT,(TotalPad * ConvFactor) - isnull(RunningScrap * ConvFactor,0) - isnull(Stopscrap * ConvFactor,0)) '+  
   '),' +  
                ' Sum(Case ProdPerStat WHEN 0 THEN 0 ' +  
  '  ELSE  ' +  
          ' (IsNull(TotalPad * ConvFactor ,0) - IsNull(RunningScrap * ConvFactor,0) - IsNull(Stopscrap * ConvFactor,0)) / ProdPerStat / 1000  ' +                   
          ' END),' +  
                ' Sum(CONVERT(INTEGER,(TotalPad)-IsNull(RunningScrap,0)-IsNull(Stopscrap,0)- IsNull(ConvFactor*TotalCases,0)))' +  
  ' FROM #Production mt ' +  
                ' JOIN #PLIDList PL ON PL.ConvUnit = mt.PU_Id ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
     Else   
  Select @SQLString = 'Select ' + @Operator + '( ' +  
   ' CONVERT(FLOAT,(TotalPad * ConvFactor) - isnull(RunningScrap * ConvFactor,0) - isnull(Stopscrap * ConvFactor,0)) '+  
   ' ),' +  
                ' Sum(Case ProdPerStat WHEN 0 THEN 0 ' +  
  '  ELSE  ' +  
          ' (IsNull(TotalPad * ConvFactor ,0) - IsNull(RunningScrap * ConvFactor,0) - IsNull(Stopscrap * ConvFactor,0)) / ProdPerStat / 1000  ' +                      
          ' END),' +  
                ' Sum(CONVERT(INTEGER,(TotalPad)-IsNull(RunningScrap,0)-IsNull(Stopscrap,0)-IsNull(ConvFactor * TotalCases,0)))' +  
  ' FROM #Production mt ' +  
                ' JOIN #PLIDList PL ON PL.ConvUnit = mt.PU_Id ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
  ' AND mt.Class IN (' + @ClassList + ')'  
  

	Print 'Good Product ->' + @SQLString  

	-- jpg
--	Truncate Table #Temporary  
	Truncate Table #TemporaryFloat  
--	Insert #Temporary (TempValue1,TempValue2,TempValue3)  
	Insert #TemporaryFloat (TempValue1,TempValue2,TempValue3)  
		Execute (@SQLString)  
 
	--select '#TemporaryFloat', * from #TemporaryFloat
-- 	For Testing 
--if @@ERROR <> 0 
--BEGIN
--	PRINT 'Sql Error: ' + @SQLString
--	Select 'Good Product', mt.PLID, mt.PU_ID, Product, Product_Size, TotalPad, ConvFactor, TotalPad * ConvFactor as pads_X_conv
----CONVERT(INTEGER,Sum(TotalPad * ConvFactor )) 
--		FROM #Production mt  
--		JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC 
--		JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC 
--		JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC  
--		WHERE mt.PLID = '55' AND mt.PU_ID = '1557'
--END
--ELSE
--	PRINT 'Not Sql Error: ' + @SQLString
 
 -- jpg
-- Select @SumGoodPads = TempValue1, @SumMSU = STR(TempValue2,6,2) FROM #Temporary  
 Select @SumGoodPads = TempValue1, @SumMSU = STR(TempValue2,6,2) FROM #TemporaryFloat  
 -- GoodProduct  

--select @SumGoodPads SumGoodPads
 -------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- TotalScrap, RunningScrap, DowntimeScrap  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'TotalScrap')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'TotalScrap')   
  
 If @MinGroupValue <> 'ZZZ'  
             If (@RPTMinorGroupBy = 'PU_ID' or @RPTMajorGroupBy = 'PU_ID')  
          Select @SQLString = 'Select Sum(RunningScrap * ConvFactor), Sum(Stopscrap * ConvFactor) ' +  
          ' FROM #Production mt ' +  
          ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
          ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
          ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
          ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
          ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
              Else  
                        Select @SQLString = 'Select Sum(RunningScrap * ConvFactor), Sum(Stopscrap * ConvFactor) ' +  
          ' FROM #Production mt ' +  
          ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
          ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
          ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
          ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
          ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' AND mt.Class IN (' + @ClassList+ ')'  
 Else  
     If (@RPTMajorGroupBy = 'PU_ID')  
  Select @SQLString = 'Select Sum(RunningScrap * ConvFactor), Sum(Stopscrap * ConvFactor) ' +  
  ' FROM #Production mt ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
     Else  
  Select @SQLString = 'Select Sum(RunningScrap * ConvFactor), Sum(Stopscrap * ConvFactor) ' +  
  ' FROM #Production mt ' +  
  ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
  ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
  ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
  ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +    
  ' AND mt.Class IN (' + @ClassList+ ')'   
  

 Truncate Table #Temporary  
 Insert #Temporary (TempValue1, TempValue2)  
 Execute (@SQLString)  

  
        -- Select * FROM #Temporary  
  
 Select @SumRunningScrap = TEMPValue1, @SumDowntimeScrap = TEMPValue2 FROM #Temporary  
  
    Set @SumTotalScrap = CONVERT(Float,IsNull(@SumRunningScrap,0)) + CONVERT(Float,IsNull(@SumDowntimeScrap,0))  
  
 -- RejectedProduct, RunningScrap, StarttingScrap  
    -- Set @SumArea4LossPer = convert(float,@SumTotalPads) - convert(float,@SumRunningScrap) - convert(float,@SumDowntimeScrap) - convert(float,@SumGoodPads)  
 -------------------------------------------------------------------------------------------------------------  
 -------------------------------------------------------------------------------------------------------------  
 -- TargetSpeed,IdealSpeed  
 Set @Operator = (Select Operator FROM #Equations WHERE Variable = 'TargetSpeed')  
 Set @ClassList = (Select Class FROM #Equations WHERE Variable = 'TargetSpeed')   
 Set @Operator = 'SUM'  
 If @MinGroupValue <> 'ZZZ'  
              If @RPTMinorGroupBy = 'PU_ID' or @RPTMajorGroupBy = 'PU_ID'   
              -- If Major or Minor is a Unit then Class will not apply  
   Select @SQLString = 'Select CONVERT(Float, SUM(LineSpeedTar * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
   'CONVERT(Float, SUM(IdealSpeed * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
   ' mt.PU_id ' +  
   ' FROM #Production mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
                        ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' Group by mt.pu_id '   
               Else  
          Select @SQLString = 'Select CONVERT(Float, SUM(LineSpeedTar * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
    ' CONVERT(Float, SUM(IdealSpeed * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
          ' mt.PU_id ' +  
          ' FROM #Production mt ' +  
          ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
          ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
          ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
          ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
          ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + '''' +  
                        ' AND mt.Class IN (' + @ClassList+ ')' +  
                        ' Group by mt.pu_id'  
 Else  
  
  If @RPTMajorGroupBy = 'PU_ID'   
   Select @SQLString = 'Select CONVERT(Float, SUM(LineSpeedTar * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
   ' CONVERT(Float, SUM(IdealSpeed * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
   ' mt.PU_id ' +  
   ' FROM #Production mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
            ' Group by mt.pu_id'  
  Else  
   Select @SQLString = 'Select CONVERT(Float, SUM(LineSpeedTar * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
   ' CONVERT(Float, SUM(IdealSpeed * CONVERT(float,datediff(mi,StartTime,EndTime))) / (SUM(CONVERT(float,datediff(ss,StartTime,EndTime)))/60)), ' +  
            ' mt.PU_id ' +  
   ' FROM #Production mt ' +  
   ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
   ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
   ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
   ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + '''' +  
   ' AND mt.Class IN (' + @ClassList+ ')' +                       
            ' Group by mt.pu_id'  

 Truncate Table #Temporary  
 Insert #Temporary (TempValue1,TempValue2,TempValue3)  
 Execute (@SQLString)  
  
 -- print 'TargetSpeed '+ @SQLString  
  
    If @Operator = 'SUM'  
                        Select @Sumtargetspeed = Sum(CONVERT(float,TempValue1)) FROM #Temporary   
    Else  
                        Select @Sumtargetspeed = Avg(CONVERT(float,TempValue1)) FROM #Temporary  
  
  -- Ideal Speed works tied to Target Speed  
 If @Operator = 'SUM'  
                        Select @SumIdealSpeed = Sum(CONVERT(float,TempValue2)) FROM #Temporary   
    Else  
                        Select @SumIdealSpeed = Avg(CONVERT(float,TempValue2)) FROM #Temporary  
        -- TargetSpeed  
 -------------------------------------------------------------------------------------------------------------  
  
 -------------------------------------------------------------------------------------------------------------    
-- TotalCase          
 Select @SQLString = 'Select ' +    
 ' CONVERT(Float,Sum(TotalCases)) ' +  
 ' FROM #Production mt ' +  
 ' JOIN #ShiftDESCList TSD ON mt.Shift = TSD.ShiftDESC' +   
 ' JOIN #CrewDESCList CSD ON mt.Crew = CSD.CrewDESC' +  
 ' JOIN #PLStatusDESCList TPLSD ON mt.LineStatus = TPLSD.PLStatusDESC ' +  
 ' WHERE mt.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''    
 --  
 If @MinGroupValue <> 'ZZZ'  
  Select @SQLString =   
                        @SQLString + ' AND mt.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''   
    --                    
 Truncate Table #Temporary  
  
 Insert #Temporary (TempValue1)  
 Execute (@SQLString)  
  
 Select @SumTotalCases=TempValue1 FROM #Temporary  
 -- TotalCase  
 -------------------------------------------------------------------------------------------------------------   
          
 Select @SQLString = 'Select sum(convert(float,flex1)), sum(convert(float,flex2)), sum(convert(float,flex3)),' +  
 'sum(convert(float,flex4)), sum(convert(float,flex5)), sum(convert(float,flex6)),' +  
 'sum(convert(float,flex7)), sum(convert(float,flex8)), sum(convert(float,flex9)), sum(convert(float,flex10)) ' +  
 'FROM #Production TP ' +  
 'JOIN #CrewDESCList TCDL ON TP.Crew = TCDL.CrewDESC ' +  
 'JOIN #ShiftDESCList TSDL ON TP.Shift = TSDL.ShiftDESC ' +  
 'JOIN #PLStatusDESCList TPLSL ON TP.LineStatus = TPLSL.PLStatusDESC ' +  
 'WHERE TP.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''   
  
 If @MinGroupValue <> 'ZZZ'  
  Select @SQLString = @SQLString + ' AND ' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
  
  
 TRUNCATE Table #Temporary  
 Insert #Temporary  
 (TempValue1, TempValue2, TempValue3, TempValue4, TempValue5, TempValue6, TempValue7, TempValue8, TempValue9, TempValue10)  
 Execute (@SQLString)  
  
 Select  @Flex1 = TEMPValue1,  @Flex2 = TEMPValue2, @Flex3 = TEMPValue3, @Flex4 = TEMPValue4,  
 @Flex5 = TEMPValue5, @Flex6 = TEMPValue6, @Flex7 = TEMPValue7, @Flex8 = TEMPValue8, @Flex9 = TEMPValue9,  
 @Flex10 = TEMPValue10 FROM #Temporary  
  
          
-- *************************************************************************************************************  
-- Only need to insert at the Inverted Summary THE DEFINED VARIABLES, others as they are Math will be calculated  
-- in the next Stpep  
--**************************************************************************************************************  
  
   Insert #InvertedSummary  
       ( GroupBy,   
        ColType,  
        TotalSplices,   
        SUCSplices,   
        RunningScrap,  
        Downtimescrap,   
        TotalPads,   
        GoodPads,   
        MSU,   
        Area4LossPer,  
        TotalScrap,  
        LineStops,  
        LineStopsERC,   
        RepairTimeT,   
        Downtime,   
        DowntimeERC,  
        DowntimePlannedStops,  
        Uptime,   
        FalseStarts,   
        UptimeGreaterT,   
        FalseStartsT,  
        SurvivalRate,   
        ACPStops,   
        NumEdits,  
        NumEditsR1,  
        NumEditsR2,  
        NumEditsR3,  
        CaseCount,  
        Flex1, Flex2, Flex3, Flex4, Flex5, Flex6, Flex7, Flex8, Flex9, Flex10,   
        ACPStopsPerDay,   
        StopsPerDay,  
        ProdTime,          
        TotalProdTime,  
        STNU   ,  
        CalendarTime,   
        TargetSpeed,  
        IdealSpeed,  
        Class)  
   Values   ( @SumGroupBy,  
        @MinGroupValue,   
        CASE WHEN @SumTotalSplices = '0' THEN NULL   
          ELSE @SumTotalSplices END,  
              @SumSUCSplices,    
        ISNULL(@SumRunningScrap,0),  
        ISNULL(@SumDowntimescrap,0),   
        STR(CONVERT(float,@SumTotalPads),12,0),   
        STR(CONVERT(float,@SumGoodPads),12,0),   
        @SumMSU,  
           CASE When @SumArea4LossPer = '0' THEN NULL   
          ELSE @SumArea4LossPer END,  
        STR(@SumTotalScrap,12,0),  
        @SumLineStops,   
        @SumLineStopsERC,  
        @SumRepairTimeT,   
        STR(@SumDowntime,9,1),   
        STR(@SumDowntimeERC,9,1),   
        STR(@SumPlannedStops,9,1),   
        STR(@SumUptime,9,1),   
        @SumFalseStarts,  
        ISNULL(@SumUptimeGreaterT,0),  
        @SumFalseStartsT,   
        @SumSurvivalRate,   
        @SumACPStops,   
        @SumNumEdits,  
        @SumNumEditsR1,  
        @SumNumEditsR2,  
        @SumNumEditsR3,  
        STR(@SumTotalCases),  
        STR(@Flex1), STR(@Flex2), STR(@Flex3), STR(@Flex4), STR(@Flex5), STR(@Flex6), STR(@Flex7), STR(@Flex8), STR(@Flex9), STR(@Flex10),   
        @sumACPStopsPerDay,   
        STR(@sumStopsPerDay,9,1),  
        @Scheduled_time,  
        @TotalScheduled_Time,   
        @STNU,  
        @CalendarTime,  
        @SumTargetspeed,  
        @SumIdealSpeed,  
        @Active_Class)  
  --jpisani
    
  Declare @lastinsertion as int  
  
  Select @lastinsertion = @@Identity  
  
 -------------------------------------------------------------------------------------------------------------   
 -- UPDATE TotalClassProducts, GoodClassProducts  
 Set @ClassCounter = 1   
   
 While @ClassCounter <= (Select Max(Class) FROM @Class)  
  
  Begin     
     
   Select @SQLString =   
   'Select Sum((IsNull(TotalPad * ConvFactor ,0)) - (IsNull(StopScrap * ConvFactor,0)) - (IsNull(RunningScrap * ConvFactor,0))) , ' +   
   'Sum(IsNull(TotalPad * ConvFactor,0)) ' +  
   'FROM #Production TP ' +  
   'JOIN #CrewDESCList TCDL ON TP.Crew = TCDL.CrewDESC ' +  
   'JOIN #ShiftDESCList TSDL ON TP.Shift = TSDL.ShiftDESC ' +  
            'JOIN #PLStatusDESCList TPLSD ON tp.LineStatus = TPLSD.PLStatusDESC ' +  
   'WHERE Tp.class = ' + CONVERT(varchar,@ClassCounter)+' AND TP.' + @RPTMajorGroupBy + ' = ''' + @MajGroupValue + ''''  
   
   If @MinGroupValue <> 'ZZZ'  
    Select @SQLString = @SQLString + ' AND TP.' + @RPTMinorGroupBy + ' = ''' + @MinGroupValue + ''''  
   
   TRUNCATE Table #Temporary  
   
   Insert #Temporary (TEMPValue1,TEMPValue2)  
   Execute (@SQLString)  
     
   -- Print 'Conversion Class : ' + @SQLString  
                        --Select @ClassCounter,@MajGroupValue,@MinGroupValue,* FROM #Temporary  
  
   Select  @SumGoodClass1 = Str(TEMPValue1,15,0),@SumTotalClass1 = Str(TEMPValue2,15,0) FROM #Temporary  
     
   Set @SQLString = 'UPDATE #InvertedSummary ' +   
    ' Set TotalClass' + CONVERT(varchar,@ClassCounter) + ' = ''' + @SumTotalClass1 + '''' +  
    ',GoodClass' + CONVERT(varchar,@ClassCounter) + '= ''' +  @SumGoodClass1 + '''' +  
    ' WHERE id = ' + CONVERT(varchar,@LastInsertion)  
     
           
   Exec(@SQLString)  
            --            Print 'UPDATEr ' + @SQLString  
   Set @ClassCounter = @ClassCounter + 1  
    
  End   
  
  -- UPDATE TotalClassProducts, GoodClassProducts  
  -------------------------------------------------------------------------------------------------------------   
   
  -- *************************************************************************************************************  
  -- Only need to insert at the Inverted Summary THE DEFINED VARIABLES, others as they are Math will be calculated  
  -- in the next Stpep  
  --**************************************************************************************************************  
  --  
  Select @i = @i + 1    
  
  FETCH NEXT FROM RSMiCursor into @MajGroupValue, @MajGroupDesc,@MajOrderby,@MinGroupValue, @MinGroupDesc,@MinOrderby  
  END 
  
  Close RSMiCursor  
  Deallocate RSMiCursor  

 
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  
-- FRio : NOTE , END of cursor for filling #TEMPORARY TABLES  
-- Print convert(varchar(25), getdate(), 120) + 'OUT OF THE CURSOR !!'  
-- !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  
--> AHORA DESDE ACA LOS CALCULOS DEL AGGREGATE  
----------------------------------------------------------------------------------------------------------------  
-- POPULATE OUTPUT Tables: Some Totals data For #InvertedSummary  
----------------------------------------------------------------------------------------------------------------  
-- First insertion for Aggregate Values with variables that are the SUM FROM Partial Values (No special Math or no Def.)  
-- Select LineStops,TotalProdTime,Downtime,Uptime,TotalPads,DowntimeScrap,* FROM #InvertedSummary  
  
UPDATE #InvertedSummary   
        Set StopsPerDay = (Case When CONVERT(Float,Uptime)+CONVERT(Float,Downtime) < 1440 Then LineStops  
                                Else CONVERT(Float,LineStops) * 1440 / (CONVERT(Float,Uptime)+CONVERT(Float,Downtime))End),  
            ACPStopsPerDay = (Case When CONVERT(Float,Uptime)+CONVERT(Float,Downtime) < 1440 Then ACPStops  
                                Else CONVERT(Float,ACPStops) * 1440 / (CONVERT(Float,Uptime)+CONVERT(Float,Downtime))End)  
  
Insert #InvertedSummary  
(GroupBy, CaseCount,TotalUptime,TotalDowntime,UptimeGreaterT,--Area4LossPer,-- MSU,  
ACPStops,  
Flex1, Flex2, Flex3, Flex4, Flex5, Flex6, Flex7, Flex8, Flex9, Flex10,  
TotalClass1, TotalClass2, TotalClass3, TotalClass4, TotalClass5, TotalClass6, TotalClass7, TotalClass8, TotalClass9, TotalClass10, TotalClass11, TotalClass12, TotalClass13, TotalClass14, TotalClass15,TotalClass16, TotalClass17, TotalClass18,TotalClass19,
 TotalClass20,  
GoodClass1, GoodClass2, GoodClass3, GoodClass4, GoodClass5, GoodClass6, GoodClass7, GoodClass8, GoodClass9, GoodClass10, GoodClass11, GoodClass12, GoodClass13, GoodClass14, GoodClass15, GoodClass16, GoodClass17, GoodClass18, GoodClass19, GoodClass20)  
  
Select 'AGGREGATE',   
STR(SUM(CONVERT(FLOAT,CaseCount)),15,0),  
STR(SUM(CONVERT(float,Uptime)),15,1),  
STR(SUM(convert(float,Downtime)),15,1),  
STR(SUM(CONVERT(FLOAT,UptimeGreaterT)),15,1),  
--sum(convert(float,Area4LossPer)),  
--sum(convert(float,MSU)),  
STR(SUM(CONVERT(FLOAT,ACPStops)),15,0),  
STR(sum(convert(float,Flex1))),   
STR(sum(convert(float,Flex2))),   
STR(sum(convert(float,Flex3))),   
STR(sum(convert(float,Flex4))),   
STR(sum(convert(float,Flex5))),  
STR(sum(convert(float,Flex6))),   
STR(sum(convert(float,Flex7))),   
STR(sum(convert(float,Flex8))),   
STR(sum(convert(float,Flex9))),   
STR(sum(convert(float,Flex10))),  
str(sum(convert(float,isnull(TotalClass1,0))),15,0),   
str(sum(convert(float,isnull(TotalClass2,0))),15,0),   
str(sum(convert(float,isnull(TotalClass3,0))),15,0),   
str(sum(convert(float,isnull(totalClass4,0))),15,0),   
str(sum(convert(float,isnull(TotalClass5,0))),15,0),   
str(sum(convert(float,isnull(TotalClass6,0))),15,0),   
str(sum(convert(float,isnull(totalClass7,0))),15,0),   
str(sum(convert(float,isnull(TotalClass8,0))),15,0),   
str(sum(convert(float,isnull(TotalClass9,0))),15,0),   
str(sum(convert(float,isnull(TotalClass10,0))),15,0),   
str(sum(convert(float,isnull(TotalClass11,0))),15,0),   
str(sum(convert(float,isnull(TotalClass12,0))),15,0),   
str(sum(convert(float,isnull(totalClass13,0))),15,0),   
str(sum(convert(float,isnull(TotalClass14,0))),15,0),   
str(sum(convert(float,isnull(TotalClass15,0))),15,0),   
str(sum(convert(float,isnull(TotalClass16,0))),15,0),   
str(sum(convert(float,isnull(TotalClass17,0))),15,0),   
str(sum(convert(float,isnull(TotalClass18,0))),15,0),   
str(sum(convert(float,isnull(totalClass19,0))),15,0),   
str(sum(convert(float,isnull(TotalClass20,0))),15,0),   
str(sum(convert(float,GoodClass1)),15,0),   
str(sum(convert(float,GoodClass2)),15,0),   
str(sum(convert(float,GoodClass3)),15,0),  
str(sum(convert(float,GoodClass4)),15,0),   
str(sum(convert(float,GoodClass5)),15,0),   
str(sum(convert(float,GoodClass6)),15,0),  
str(sum(convert(float,GoodClass7)),15,0),   
str(sum(convert(float,GoodClass8)),15,0),   
str(sum(convert(float,GoodClass9)),15,0),  
str(sum(convert(float,GoodClass10)),15,0),   
str(sum(convert(float,GoodClass11)),15,0),   
str(sum(convert(float,GoodClass12)),15,0),  
str(sum(convert(float,GoodClass13)),15,0),   
str(sum(convert(float,GoodClass14)),15,0),   
str(sum(convert(float,GoodClass15)),15,0),  
str(sum(convert(float,GoodClass16)),15,0),   
str(sum(convert(float,GoodClass17)),15,0),   
str(sum(convert(float,GoodClass18)),15,0),  
str(sum(convert(float,GoodClass19)),15,0),   
str(sum(convert(float,GoodClass20)),15,0)  
FROM #InvertedSummary  
WHERE ColType = 'ZZZ'  
----------------------------------------------------------------------------  
-- CALCULATE 'DEFINED' VARIABLES FIRST  
--Print convert(varchar(25), getdate(), 120) + 'CALCULATING EQUATIONS'  
----------------------------------------------------------------------------  
-- Select * FROM #InvertedSummary  
-- Select * From #Equations  
  
Declare @eq_id as int  
  
Select @eq_id = Min(eq_id) FROM #Equations  
  
While @eq_id Is Not NULL  
Begin  
      
    Select @Variable = Variable, @Operator = Operator, @ClassList = Class , @Prec = Prec FROM #Equations WHERE eq_id = @eq_id  
  
    If @RPTMajorGroupBy = 'PU_ID' -- Or @RptMinorGroupBy = 'PU_ID'  
    Begin  
        --If (@Variable = 'ProdTime')  
   --                Set @Operator = 'AVG'  
      
     Set @SQLString = 'UPDATE #InvertedSummary ' +  
       ' Set ' + @Variable + ' = Str(IsNull((Select ' + @Operator + '(IsNull(CONVERT(Float,'+ @Variable+'),0)) ' +  
       ' FROM #InvertedSummary ' +  
       ' WHERE Class IN ( ' + @ClassList + ' ) AND ColType = ''' + 'ZZZ' + ''' AND ' + @Variable + ' Is Not NULL),0),15,' + convert(varchar,@Prec) + ') ' +  
       ' WHERE GroupBy = ''' + 'Aggregate' + ''''  
    End  
    Else  
    Begin  
        If @RPTMajorGroupBy = 'Product' AND ( @Variable = 'TargetSpeed' Or @Variable = 'IdealSpeed')  
                            Set @Operator = 'AVG'  
      
     Set @SQLString = 'UPDATE #InvertedSummary ' +   
       ' Set ' + @Variable + ' = Str(IsNull((Select ' + @Operator + '(IsNull(CONVERT(Float,'+ @Variable+'),0)) ' +  
       ' FROM #InvertedSummary ' +  
       ' WHERE ColType = ''' + 'ZZZ' + ''' AND ' + @Variable + ' Is Not NULL),0),15,' + convert(varchar,@Prec)+ ') ' +  
       ' WHERE GroupBy = ''' + 'Aggregate' + ''''  
    End  
      
    Exec(@SQLString)  
  
 Select @eq_id = Min(eq_id) FROM #Equations WHERE eq_id > @eq_id  
 -- Print 'Testing Operators ' +  @Variable + ' ' + @SQLString  
  
End  
  
--Print convert(varchar(25), getdate(), 120) + 'END CALCULATING EQUATIONS'  
  
------------------------------------------------------------------------------------------------------------------------  
-- UPDATE TotalProdTime, used for PerDay measurements  
--UPDATE #InvertedSummary  
--        Set  TotalProdTime = (Select Sum(CONVERT(Float,IsNull(TotalProdTime,0))) FROM #InvertedSummary WHERE ColType = 'ZZZ')  
--WHERE GroupBy = 'AGGREGATE'  
------------------------------------------------------------------------------------------------------------------------  
-- UPDATE Calendar Time just for CU purposes  
-- Use class list for these  
  
DECLARE  
        @uptimeClass as nvarchar(50)  
  
Select @uptimeClass = Class FROM #Equations WHERE Variable = 'Uptime'  
Select @Operator = Operator FROM #Equations WHERE Variable = 'Uptime'  
  
If @RPTMajorGroupBy = 'PU_ID' or @RPTMinorGroupBy = 'PU_ID'  
Begin  
    If @Operator = 'SUM'  
        Set @SQLString = 'UPDATE #InvertedSummary ' +   
                         'Set Uptime = Str((Select SUM(CONVERT(Float,Uptime)) FROM #InvertedSummary ' +   
                         'WHERE ColType <> ''' + 'ZZZ' + ''' AND Class in ('+ @uptimeClass +')),15,1) ' +   
                         'WHERE GroupBy = '''+ 'AGGREGATE' + ''''  
    Else  
        Set @SQLString = 'UPDATE #InvertedSummary ' +   
                         'Set Uptime = Str((Select AVG(CONVERT(Float,Uptime)) FROM #InvertedSummary ' +   
                         'WHERE ColType <> ''' + 'ZZZ' + ''' AND Class in ('+ @uptimeClass +')),15,1) ' +   
                         'WHERE GroupBy = '''+ 'AGGREGATE' + ''''  
End  
Else  
Begin  
    If @Operator = 'SUM'  
        Set @SQLString = 'UPDATE #InvertedSummary ' +   
                         'Set Uptime = Str((Select SUM(CONVERT(Float,Uptime)) FROM #InvertedSummary ' +   
                         'WHERE ColType = ''' + 'ZZZ' + '''),15,1)' +   
                         'WHERE GroupBy = '''+ 'AGGREGATE' + ''''  
    Else  
        Set @SQLString = 'UPDATE #InvertedSummary ' +   
                         'Set Uptime = Str((Select AVG(CONVERT(Float,Uptime)) FROM #InvertedSummary ' +   
                         'WHERE ColType = ''' + 'ZZZ' + ''' AND Class in ('+ @uptimeClass +')),15,1) ' +   
                         'WHERE GroupBy = '''+ 'AGGREGATE' + ''''  
End  
  
Exec (@SQLString)  
  
----------------------------------------------------------------------------------------------------------------------  
-- Calculate Area 4 Loss  
  
declare   
        @startClass as varchar(1),  
        @endClass as varchar(1)  
  
select @startClass = LEFT(Value,1) FROM #Params WHERE param = 'DPR_Area4Loss_FromToClass'  
select @endClass = right(Value,1) FROM #Params WHERE param = 'DPR_Area4Loss_FromToClass'  
  
if (Len(@startClass)>0) or (Len(@endClass)>0)  
begin  
        set @SQLString = 'UPDATE #InvertedSummary ' +  
                ' Set Area4LossPer = CONVERT(float,TotalClass' + @startClass + ') - CONVERT(float,RunningScrap) - CONVERT(float,DowntimeScrap) - CONVERT(float,GoodClass' + @endClass + ')'  
          
        -- print ' ---> ' + @SQLString  
        exec(@SQLString)  
end  
  
  
-- Print convert(varchar(25), getdate(), 120) + 'CALCULATING PRODTIME'  
-------------------------------------------------------------------------------  
-- Need a trick for Production Time as it should not be > 1440 for a single day  
-------------------------------------------------------------------------------  
/*If @RPTMajorGroupBy = 'PU_ID' or @RPTMajorGroupBy = 'PLID'  
Begin  
  
        If Exists (Select * FROM #Equations WHERE Variable = 'ProdTime' AND Operator = 'SUM')  
            UPDATE #InvertedSummary  
          Set ProdTime = (Select Sum(CONVERT(float,Isnull(ProdTime,0))) FROM #InvertedSummary WHERE ColType = 'ZZZ' AND ProdTime Is Not NULL)   
         WHERE GroupBy = 'Aggregate'  
        Else  
            UPDATE #InvertedSummary  
          Set ProdTime = (Select Avg(CONVERT(float,Isnull(ProdTime,0))) FROM #InvertedSummary WHERE ColType = 'ZZZ' AND ProdTime Is Not NULL)   
         WHERE GroupBy = 'Aggregate'  
  
End*/  
-------------------------------------------------------------------------------  
-------------------------------------------------------------------------------  
-- MATH VARIABLES  
--Print convert(varchar(25), getdate(), 120) + 'Updating MATH VARIABLES'  
----------------------------------------------------------------------------  
--  
  
UPDATE #InvertedSummary  
 Set   
    -- Availability  
    Availability = Str(   
  Case  
   When (CONVERT(float,Uptime) + CONVERT(float,Downtime)) = 0 THEN 0  
   Else CONVERT(float,Uptime) / (CONVERT(float,Uptime) + CONVERT(float,Downtime))  
  End, 6, 2),  
    -- MTBF  
    MTBF = Str(   
  Case  
   When CONVERT(float,LineStops) = 0 THEN Uptime  
   Else CONVERT(float,Uptime) / CONVERT(float,LineStops)  
  End, 6, 1),  
        -- MTBF ERC  
    MTBF_ERC = Str(   
  Case  
   When CONVERT(float,LineStopsERC) = 0 THEN Uptime  
   Else CONVERT(float,Uptime) / CONVERT(float,LineStopsERC)  
  End, 6, 1),  
    -- MTTR  
       MTTR = Str(  
  Case  
   When CONVERT(float,LineStops)= 0 THEN Downtime  
   Else CONVERT(float,Downtime) / CONVERT(float,LineStops)  
  End, 6, 1),  
       -- MTTR  
       MTTR_ERC = Str(  
  Case  
   When CONVERT(float,LineStopsERC)= 0 THEN DowntimeERC  
   Else CONVERT(float,DowntimeERC) / CONVERT(float,LineStopsERC)  
  End, 6, 1),  
    -- Stops/MSU  
    StopsPerMSU = Str(  
  Case  
   When CONVERT(float,MSU)= 0 THEN 0     
   Else CONVERT(float,LineStops) / CONVERT(float,MSU)  
  End, 6, 1),  
    DownPerMSU = Str(  
  Case  
   When CONVERT(float,MSU)= 0 THEN 0  
   Else CONVERT(float,Downtime) / CONVERT(float,MSU)  
  End, 6, 1),  
    -- Total Scrap           
    TotalScrapPer = Str(  
  Case  
   When CONVERT(float,TotalPads) = 0 THEN 0  
   Else 100.0 * (CONVERT(float,isnull(TotalScrap,0)) / CONVERT(float,TotalPads))  
  End, 6, 2) + '%',  
    -- Area4Loss%  
    Area4LossPer = Str(  
     Case  
      When IsNull(CONVERT(float,TotalPads),0) = 0 THEN 0  
      Else 100.0 * (CONVERT(float,IsNull(Area4LossPer,0)) / CONVERT(float,IsNull(TotalPads,0)))  
     End, 6, 2) + '%',  
    RofT = Str(  
  Case  
   When CONVERT(float,LineStops) = 0 THEN 0  
   Else CONVERT(float,UptimeGreaterT)  / CONVERT(float,LineStops)  
   End, 6, 2),  
    RofZero = Str(  
  Case  
   When CONVERT(float,LineStops) = 0 THEN 0  
   Else  ( CONVERT(float,linestops) - CONVERT(float,falsestarts) )/ CONVERT(float,LineStops)  
   End, 6, 2),  
    -- EditedStops  
    EditedStopsPer =  Str(  
  Case  
   When CONVERT(float,LineStops) = 0 THEN 0  
   Else 100.0 * (CONVERT(float,NumEdits) / CONVERT(float,LineStops))  
  End, 6, 0) + '%',  
       -- EditedStopsR1  
    EditedStopsR1Per =  Str(  
  Case  
   When CONVERT(float,LineStops) = 0 THEN 0  
   Else 100.0 * (CONVERT(float,NumEditsR1) / CONVERT(float,LineStops))  
  End, 6, 0) + '%',  
       -- EditedStopsR2  
    EditedStopsR2Per =  Str(  
  Case  
   When CONVERT(float,LineStops) = 0 THEN 0  
   Else 100.0 * (CONVERT(float,NumEditsR2) / CONVERT(float,LineStops))  
  End, 6, 0) + '%',  
       -- EditedStopsR3  
    EditedStopsR3Per =  Str(  
  Case  
   When CONVERT(float,LineStops) = 0 THEN 0  
   Else 100.0 * (CONVERT(float,NumEditsR3) / CONVERT(float,LineStops))  
  End, 6, 0) + '%',  
    --   
    FailedSplices = Str(CONVERT(float, TotalSplices) - CONVERT(float,SUCSplices), 6, 1),  
    SuccessRate = Str(  
  Case  
  
   When CONVERT(float,TotalSplices) = 0 THEN 0  
   Else 100.0 * CONVERT(float,SucSplices) / CONVERT(float,TotalSplices)  
  End, 6, 1) + '%',  
    -- LineSpeed  
    LineSpeed = Str(  
  Case  
   When (CONVERT(float,Uptime) = 0 Or TotalPads Is NULL)THEN NULL  
   Else FLOOR((isnull(CONVERT(float,TotalPads),0) - isnull(CONVERT(float,DowntimeScrap),0)) / CONVERT(float,Uptime))  
   End, 6, 1),      
    -- PRUsingProductCount  
    PR = STR(  
  Case  
   When (CONVERT(float,PRODTIME) * CONVERT(FLOAT,TargetSpeed))= 0 THEN 0  
   -- Else  CONVERT(float,goodpads) / (CONVERT(float,PRODTIME) * CONVERT(FLOAT,targetSPEED) )*100.0  
   Else (CONVERT(float,GoodPads) / CONVERT(FLOAT,TargetSPEED)) / CONVERT(float,PRODTIME) * 100.0  
   End, 6, 2) + '%',  
    -- RunningScrap%  
    RunningScrapPer = STR(  
  Case  
   When CONVERT(float,TotalPads) = 0 THEN 0  
   Else 100.0 * CONVERT(float,RunningScrap) / CONVERT(float,TotalPads)  
   End, 6, 2) + '%',  
       -- DowntimeScrap%  
    DowntimescrapPer = STR(  
  Case  
   When CONVERT(float,TotalPads) = 0 THEN 0  
   Else 100.0 * CONVERT(float,DowntimeScrap) / CONVERT(float,TotalPads)  
   End, 6, 2) + '%',  
    
    -- FalseStart(UT=T)%  
    FalseStartsTPer = STR(  
  Case  
   When cast(linestops as float)=0 THEN 0  
   else cast(falsestartst as float) * 100 / cast(linestops as float)  
   end  
   ) + '%',  
  
        -- FalseStart(UT=0)%  
        FalseStarts0Per = Str(  
   (Case When Cast(LineStops As Float) = 0 Then 0  
   Else Cast(FalseStarts As Float) * 100 / Cast(LineStops As Float)  
   End),6,2  
   ) + '%' ,  
    SurvivalRatePer = Str (  
  (Case When (@RPTDowntimesurvivalRate = 0 or CONVERT(float,ProdTime) = 0) Then 0  
   Else CONVERT(float,SurvivalRate) / (CONVERT(float,ProdTime) / @RPTDowntimesurvivalRate) * 100  
   End),6,2  
  ) + '%'  

--select '#InvertedSummary',GoodPads,TargetSPEED,PRODTIME,PR,* from #InvertedSummary
  
-- PRUsingAvailability  
UPDATE #InvertedSummary  
 Set   
    PRAvail = STR (  
  Case  
   When ((CONVERT(float,TotalPads) - CONVERT(float,isnull(DowntimeScrap,0)))=0 or ( CONVERT(float,Uptime) + convert(float,Downtime) ) = 0) THEN 0  
   Else 100 * CONVERT(float,Availability) * (1 - (CONVERT(float,isnull(RunningScrap,0)) / (CONVERT(float,TotalPads)-CONVERT(float,isnull(DowntimeScrap,0)))))  
   End, 6, 2) + '%' ,  
 SU = STR (  
  CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0')) = 0) THEN 0  
   ELSE (CONVERT(FLOAT,ProdTime) / CONVERT(FLOAT,CalendarTime)) * 100   
   END, 6, 2) + '%' ,     
 RU = STR (  
  CASE    
   WHEN (CONVERT(FLOAT,ISNULL(GoodPads,'0')) = 0 OR CONVERT(FLOAT,ISNULL(TargetSpeed,'0')) = 0 OR CONVERT(FLOAT,ISNULL(IdealSpeed,'0')) = 0) THEN 0  
   ELSE (CONVERT(FLOAT,GoodPads) / CONVERT(FLOAT,IdealSpeed))/(CONVERT(FLOAT,GoodPads) / CONVERT(FLOAT,TargetSpeed)) * 100   
   END, 6, 2) + '%',  
 CU = STR (  
  CASE  WHEN (CONVERT(FLOAT,ISNULL(CalendarTime,'0')) = 0 or CONVERT(FLOAT,IdealSpeed)= 0 or CONVERT(FLOAT,IdealSpeed)= 0) THEN  0  
   ELSE (CONVERT(FLOAT,GoodPads) / CONVERT(FLOAT,IdealSpeed))/(CONVERT(FLOAT,CalendarTime)) * 100   
   END, 6, 2) + '%',  
 RunEff = STR (  
  CASE    WHEN (CONVERT(FLOAT,ISNULL(ProdTime,'0')) - CONVERT(FLOAT,ISNULL(DowntimePlannedStops,'0')) = 0 OR (CONVERT(FLOAT,ISNULL(TargetSpeed,'0')) = 0)) THEN 0  
   ELSE (CONVERT(FLOAT,GoodPads) / CONVERT(FLOAT,TargetSpeed)) / (CONVERT(FLOAT,ISNULL(ProdTime,'0')) - CONVERT(FLOAT,ISNULL(DowntimePlannedStops,'0'))) * 100  
   END, 6, 2) + '%'  
  
-- Total Uptime,  only UPDATEs the Aggregate column  
UPDATE #InvertedSummary  
	Set    
		StopsPerDay = Str(
						Case  When CONVERT(Float,Uptime) + CONVERT(Float,Downtime) < 1440 Then LineStops  
						Else (CONVERT(Float,LineStops) * 1440 / ((CONVERT(float,Uptime) + CONVERT(float,Downtime))    )) 
						End,6,1),           
		ACPStopsPerDay = Str(
						Case  When CONVERT(Float,Uptime) + CONVERT(Float,Downtime) < 1440 Then AcpStops   
                        Else (CONVERT(Float,AcpStops) * 1440 / ((CONVERT(float,Uptime) + CONVERT(float,Downtime))    )) 
						End,6,1)  
WHERE GroupBy = 'AGGREGATE'  

  
-- FO-00741: Change the PR Formula
IF  @RPTMajorGroupBy = 'PLId'
BEGIN
	UPDATE #InvertedSummary
            SET PR = Str((Case When (CONVERT(Float,GoodPads)) = 0
						  Then 0
						  Else	
							(CONVERT(Float,GoodPads) / 
                                    (SELECT Sum(CONVERT(Float,GoodPads) / (CASE WHEN CONVERT(Float,substring(PR,1,charindex('%',PR)-1)) = 0 
																			THEN 1
																			ELSE CONVERT(Float,substring(PR,1,charindex('%',PR)-1))
																			END))
                                          FROM #InvertedSummary 
                                          WHERE Coltype = 'ZZZ'))
						  End
						  ), 6,2) + '%'
            WHERE GroupBy = 'AGGREGATE'

	-- aca JPG
	--SELECT Sum(CONVERT(Float,GoodPads) / (CASE WHEN CONVERT(Float,substring(PR,1,charindex('%',PR)-1)) = 0 
	--																		THEN 1
	--																		ELSE CONVERT(Float,substring(PR,1,charindex('%',PR)-1))
	--																		END))
 --                                         FROM #InvertedSummary 
 --                                         WHERE Coltype = 'ZZZ'

END

--select @RPTMajorGroupBy

--	FO-00806: Add % Unplanned Downtime to DPR report.
--	% Unplanned downtime = 100 * (Downtime Unplanned / Line Status Schedule Time)
--	Downtime Unplanned			--> 				--> DowntimeERC
--	Line Status Schedule Time	--> ProductionTime	-->	ProdTime
--	In Variables: DowntimeUnplannedPerc = (TotalDowntime - Downtime) / ProdTime
-- SELECT '% Unplanned Downtime', Downtime, DowntimeERC, ProdTime, ISNULL(CONVERT(FLOAT,DowntimeERC),0) / ISNULL(CONVERT(FLOAT,ProdTime),0), * FROM #InvertedSummary WHERE GroupBy = 'AGGREGATE'  

UPDATE #InvertedSummary  
	SET DowntimeUnplannedPerc =  
		STR((	CASE  
					WHEN (ISNULL(CONVERT(FLOAT,ProdTime),0)) = 0 THEN 0  
					ELSE (100 * ISNULL(CONVERT(FLOAT,DowntimeERC),0) / ISNULL(CONVERT(FLOAT,ProdTime),0))
				END)
				, 6, 2) + '%'   

---------------------------------------------------------------------------------------------------------------  
-- TRANSPOSE #InvertedSummary TO Summary:  
---------------------------------------------------------------------------------------------------------------  
-- Select * FROM @ColumnVisibility  
-- Select * FROM #PLIDList  
-- Select * FROM #Params WHERE param like '%Date%' 
-- Testing FO-00806
-- Select id, groupby, coltype, TotalDowntime, Downtime, ProdTime, DowntimeUnplannedPerc FROM #InvertedSummary order by id  
-- Select * FROM @Cursor  
-- Select * FROM #Summary  
  
--Print convert(varchar(25), getdate(), 120) + ' POPULATE OUTPUT Tables Summary'   
  
If Exists (Select * FROM #InvertedSummary) -- < 100  
BEGIN  
  
UPDATE @ColumnVisibility  
    Set LabelName = (select value FROM #Params WHERE param = 'DPR_' + VariableName)  
WHERE Charindex( 'Flexible_Variable_', VariableName)>0   
  
Insert into #Summary (SortOrder, Label)  
Select CONVERT(Varchar(10),ColId),LabelName FROM @ColumnVisibility 
	-- jpg
	--where LabelName like 'Total Product'
  
-- jpg  
--select '#summary', * FROM #summary  
  --select '@ColumnVisibility',* from @ColumnVisibility
--------------------------------------------------------------------------------------------------------------------  
--   
Declare @id_is as int  
  
Select @id_is = Min(id) FROM #InvertedSummary  
  
While @id_is Is Not NULL  
Begin  
  
    Select @GroupValue = Groupby FROM #InvertedSummary WHERE ID = @id_is  
  
 Set @j = 1  
 While @j <= @NoLabels  
  Begin  
  --  
  If Exists ( Select * FROM #Summary WHERE SortOrder = @j)  
     
   Begin  
           Select @FIELDName = FieldName FROM @ColumnVisibility WHERE ColId = @j  
     
     Select @SQLString = ''  
     Select @SQLString = 'Select ' + @FIELDName +  
      ' FROM #InvertedSummary ' +  
      ' WHERE GroupBy = ''' + @GroupValue + ''''  
     -- Print @SQLSTring  
     --   
     TRUNCATE Table #TEMPORARY  
     Insert #TEMPORARY (TEMPValue1)  
     Execute (@SQLString)  
     --  
     -- Set @TEMPValue = null      
     Select @TEMPValue = TEMPValue1 FROM #TEMPORARY  
     -- Select @SQLString = ''  
     --  
     Select @SQLString = 'UPDATE #Summary' +  
      ' Set '+ @GroupValue + ' = ''' + LTrim(RTrim(@TEMPValue)) + '''' +  
      ' WHERE SortOrder = ' + CONVERT(VARCHAR(25),@J)  
     --   
     -- Print @SQLString         
     Execute (@SQLString)  
  
   End  
  --  
  Set @j = @j + 1  
 End  
  
    Select @id_is = Min(ID) FROM #InvertedSummary WHERE ID > @id_is  
  
End  
END  
ELSE  
        UPDATE #Summary   
                Set Label = 'The Report has reach the maximun number of columns!'  
  
  
-- Select * FROM #Summary  
----------------------------------------------------------------------------------------------------------  
--   
----------------------------------------------------------------------------------------------------------  
----------------------------------------------------------------------------------------------------------  
-- UPDATE the report definition FROM the @ColumnVisibility table  
--Print convert(varchar(25), getdate(), 120) + ' UPDATE the parameters table'   
----------------------------------------------------------------------------------------------------------  
-- Select * FROM #Temp_ColumnVisibility  
-- Select * FROM @ColumnVisibility  
  
--UPDATE dbo.Report_Definition_Parameters   
--        Set Value = 'TRUE'  
--FROM dbo.Report_Definition_Parameters rdp WITH(NOLOCK)  
--JOIN dbo.Report_Definitions r WITH(NOLOCK) ON rdp.report_id=r.report_id  
--JOIN dbo.Report_Type_Parameters rtp WITH(NOLOCK) ON rtp.rtp_id = rdp.rtp_id  
--JOIN dbo.Report_Parameters rp WITH(NOLOCK) ON rp.rp_id = rtp.rp_id  
--JOIN (select 'DPR_' + VariableName as VariableName FROM @ColumnVisibility) cv ON cv.VariableName = rp_name  
--WHERE r.report_id = @Report_Id  AND rp_name Not Like '%ShowTop5%'  
--AND rp_name Not Like '%DPR_Flexible_Variable%'  
--AND rp_name Not Like '%DPR_HorizontalLayout%'  
  
--UPDATE dbo.Report_Definition_Parameters  
--        Set Value = '!Null'  
--FROM dbo.Report_Definition_Parameters rdp WITH(NOLOCK)  
--JOIN dbo.Report_Definitions r WITH(NOLOCK) ON rdp.report_id=r.report_id  
--JOIN dbo.Report_Type_Parameters rtp WITH(NOLOCK) ON rtp.rtp_id = rdp.rtp_id  
--JOIN dbo.Report_Parameters rp ON rp.rp_id = rtp.rp_id  
--WHERE r.report_id = @Report_id  
--AND rp_name = 'Local_PG_strRptDPRColumnVisibility'  
  
--Print convert(varchar(25), getdate(), 120) + ' End UPDATE the parameters table'   
  
----------------------------------------------------------------------------  
-- Data Check: Used For Trouble Shooting  
----------------------------------------------------------------------------  
-- Select 'DPR_'+ VariableName FROM @ColumnVisibility  
-- Select * FROM #Status WHERE pu_id = 166 --order by start_time  
-- Select * FROM #PLIDList   
-- Select * FROM @Products  
-- Select * FROM #Production order by pu_id,StartTime   
-- Select * FROM #Summary  
-- Select * FROM @Class  
-- Select * FROM @LineStatus WHERE pu_id = 233   
-- Select * FROM #ShiftDESCList  
-- Select * FROM #CrewDESCList   
-- Select * FROM #PLStatusDESCList  
-- Select * FROM #Variables   
-- Select * FROM Local_PG_Line_Status  
-- Select * FROM Crew_Schedule  
-- Select * FROM #Splices  
-- Select * FROM #Rejects  
-- Select '#Production',* FROM #Production order by PU_Id,StartTime
-- Select pu_id, count(*) FROM #Downtimes WHERE isStops = 1 group by pu_id  --pu_id = 93 order by start_Time   
-- Select schedtime,* FROM #Production order by pu_id,starttime  
-- Select * FROM #Downtimes Where Class = 1 AND Shift = 3 Order by PU_Id,Start_Time   
-- Select * FROM #TESTS  
-- Select ColType,Uptime,Downtime,ProdTime,TotalProdTime,'->',* FROM #InvertedSummary  
----------------------------------------------------------------------------  
-- OUTPUT RESULT SETS For REPORT:  
----------------------------------------------------------------------------  
-- Testing FO-00806
-- Select id, groupby, coltype, TotalDowntime, Downtime, ProdTime, DowntimeUnplannedPerc FROM #InvertedSummary order by id  
 --Select * FROM #Summary   
-- select * FROM #InvertedSummary
----------------------------------------------------------------------------  
-- OUTPUT RESULT SETS For REPORT: Result Set 1 For header  
----------------------------------------------------------------------------  
If @OutputType <> 'KPIS' AND @OutputType <> 'Scraps'
BEGIN
	Select  
	 @StartDateTime                         StartDateTime,  
	 @EndDateTime							EndDateTime,  
	 @CompanyName							CompanyName,  
	 @SiteName								SiteName,  
	 NULL									PeriodInCompleteFlag,  
	 SUBString(@ProdCodeList, 1, 50)		Product,  
	 SUBString(@CrewDESCList, 1, 25)		CrewDESC,  
	 SUBString(@ShiftDESCList, 1, 10)		ShiftDESC,  
	 SUBString(@PLStatusDESCList, 1, 100)	LineStatusDESC,  
	 SUBString(@PLDESCList, 1, 100)			LineDESC,  
	 SUBString(@lblPlant, 1, 25)			Plant,  
	 @lblStartDate							StartDate,  
	 @lblShift								Shift,  
	 @lblProductCode						ProductCode,  
	 @lblLine								Line,  
	 @lblEndDate							EndDate,  
	 @lblCrew								Crew,  
	 @lblProductionStatus					LineStatus,  
	 @lblTop5Downtime						Top5Downtime,  
	 @lblTop5Stops							Top5Stops,  
	 @lblTop5Rejects						Top5Rejects,  
	 SUBString(@lblSecurity,1, 500)			Security  
 END 
----------------------------------------------------------------------------  
-- Restore the original settings to check if RptMajor = RptMinor  
----------------------------------------------------------------------------  
Set @RPTMajorGroupBy = @RPTMajorGroupByOld  
Set @RPTMinorGroupBy  = @RPTMinorGroupByOld  
----------------------------------------------------------------------------  
-- OUTPUT RESULT SETS FOR REPORT: Result Set 2 For Summary  
----------------------------------------------------------------------------  
If @RPTMajorGroupBy = @RPTMinorGroupBy  
Begin  
Set @i = 1  
Set @SQLString = 'UPDATE #Summary Set '   
  
While @i <= @ColNum  
begin  
        set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ' = ''' + '' + ''' ,'  
 set @i = @i + 1  
end  
set @SQLString = @SQLSTring + ' Null02 = ''' + @RPTMajorGroupBy + ''',Aggregate = ''' + '' + ''' WHERE GroupField = ''' + 'Major' + ''''  
Exec (@SQLString)  
End  
  
Set @i = 1  
Set @SQLString = 'Select SortOrder,Label,null01,null02,'   
  
While @i <= @ColNum  
begin  
        set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ','  
 set @i = @i + 1  
end  
set @SQLString = @SQLSTring + 'AGGregate,EmptyCol FROM #Summary'          
  
-- 
--select 'Summary: ' +  @SQLString 
--select '#Production',* from #Production where PU_Id = 754 ORDER BY pu_id, StartTIME 

If @OutputType <> 'KPIS' AND @OutputType <> 'Scraps'
BEGIN
	exec(@SQLString)  
END

IF	@OutputType = 'KPIS'
BEGIN
	----------------------------------------------------------------------------  
	-- UCC Pilot output 
	-- AJ20151103
	----------------------------------------------------------------------------  
	INSERT	@tOutput	(PRLossPDT, PRLossUDT, PR, StopsE, CenterlineOut, MachineScrap, NetProduction,
			StopsP, ScheduleTime, StopsU, StopsUD,CenterlineComplete, Stops, Scrap, UPPR)
			VALUES (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

	UPDATE	T
			SET	T.PR	= COALESCE(CONVERT(FLOAT, REPLACE(S.[Aggregate],'%','')), 0) 
				FROM	@tOutput T
				JOIN	#Summary S
				ON		S.Label = 'PR using Product Count'
	
	UPDATE	T
			SET	T.Scrap	= COALESCE(CONVERT(FLOAT, REPLACE(S.[Aggregate],'%','')), 0) 
				FROM	@tOutput T
				JOIN	#Summary S
				ON		S.Label = 'Scrap %'		
	
	UPDATE	T
			SET	T.NetProduction	= COALESCE(CONVERT(FLOAT, REPLACE(S.[Aggregate],'%','')), 0)
				FROM	@tOutput T
				JOIN	#Summary S
				ON		S.Label = 'Good Product'
				

	UPDATE	T
			SET	T.Stops	= COALESCE(CONVERT(INT, CONVERT(FLOAT, REPLACE(S.[Aggregate],'%',''))), 0)  
				FROM	@tOutput T
				JOIN	#Summary S
				ON		S.Label = 'Line Stops'
	
	UPDATE	T
			SET	T.StopsU	= COALESCE(CONVERT(INT, CONVERT(FLOAT, REPLACE(S.[Aggregate],'%',''))), 0)  
				FROM	@tOutput T
				JOIN	#Summary S
				ON		S.Label = 'Line Stops (Unplanned)'

	UPDATE	T
			SET	T.UPPR	= COALESCE(CONVERT(FLOAT, CONVERT(FLOAT, REPLACE(S.[Aggregate],'%',''))), 0)  
				FROM	@tOutput T
				JOIN	#Summary S
				ON		S.Label = 'Downtime (Unplanned) %'

	SELECT	PRLossPDT			PRLossPDT,
			PRLossUDT			PRLossUDT,
			PR					PR,
			StopsE				StopsE,
			CenterlineOut		CenterlineOut,
			MachineScrap		MachineScrap,
			NetProduction		NetProduction,
			StopsP				StopsP,
			ScheduleTime		ScheduleTime,
			StopsU				StopsU,
			StopsUD				StopsUD,
			CenterlineComplete	CenterlineComplete,
			Stops				Stops,
			Scrap				Scrap,
			UPPR				UPPR
			FROM	@tOutput
END
				


----------------------------------------------------------------------------  
-- OUTPUT RESULT SETS FOR REPORT: Result Set 3 For Top 5 Downtime  
----------------------------------------------------------------------------  
If @OutputType <> 'KPIS' AND @OutputType <> 'Scraps'
BEGIN

	If @RPTMajorGroupBy = @RPTMinorGroupBy  
	Begin  
	Set @i = 1  
	Set @SQLString = 'UPDATE #Top5Downtime Set '   
	  
	While @i <= @ColNum  
	begin  
			set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ' = ''' + '' + ''' ,'  
	 set @i = @i + 1  
	end  
	set @SQLString = @SQLSTring + ' Stops = ''' + @RPTMajorGroupBy + ''',Aggregate = ''' + '' + ''' WHERE GroupField = ''' + 'Major' + ''''  
	Exec (@SQLString)  
	End  
	  
	Set @i = 1  
	Set @SQLString = 'Select SortOrder,DESC01,DESC02,stops,'   
	While @i <= @ColNum  
	begin  
	  set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ','  
	  set @i = @i + 1  
	end  
	  set @SQLString = @SQLSTring + 'AGGregate,EmptyCol FROM #Top5Downtime'  
	  
	exec(@SQLString)  
	--Select * FROM #Top5Downtime  
	----------------------------------------------------------------------------  
	-- OUTPUT RESULT SETS FOR REPORT: Result Set 4 For Top 5 Stops  
	----------------------------------------------------------------------------  
	If @RPTMajorGroupBy = @RPTMinorGroupBy  
	Begin  
	Set @i = 1  
	Set @SQLString = 'UPDATE #Top5Stops Set '   
	  
	While @i <= @ColNum  
	begin  
			set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ' = ''' + '' + ''' ,'  
	 set @i = @i + 1  
	end  
	set @SQLString = @SQLSTring + ' Downtime = ''' + @RPTMajorGroupBy + ''', Aggregate = ''' + '' + ''' WHERE GroupField = ''' + 'Major' + ''''  
	Exec (@SQLString)  
	End  
	  
	Set @i = 1  
	Set @SQLString = 'Select SortOrder,DESC01,DESC02,downtime,'   
	While @i <= @ColNum  
	begin   
	  set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ','  
	  set @i = @i + 1  
	end  
	  set @SQLString = @SQLSTring + 'AGGregate,EmptyCol FROM #Top5Stops'  
	  
	exec(@SQLString)  
	  
	--Select * FROM #Top5Stops   
END
----------------------------------------------------------------------------  
-- OUTPUT RESULT SETS FOR REPORT: Result Set 5 For Top 5 Rejects  
----------------------------------------------------------------------------  
If @RPTMajorGroupBy = @RPTMinorGroupBy  
Begin  
Set @i = 1  
Set @SQLString = 'UPDATE #Top5Rejects Set '   
  
While @i <= @ColNum  
begin  
        set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ' = ''' + '' + ''' ,'  
 set @i = @i + 1  
end  
set @SQLString = @SQLSTring + ' Events = ''' + @RPTMajorGroupBy + ''', Aggregate = ''' + '' + ''' WHERE GroupField = ''' + 'Major' + ''''  
Exec (@SQLString)  
End  

If @OutputType <> 'KPIS' AND @OutputType <> 'Scraps'
BEGIN
	Set @i = 1  
	Set @SQLString = 'Select SortOrder,DESC01,DESC02,events,'   
	While @i <= @ColNum  
	begin  
	  set @SQLString = @SQLString + 'Value' + convert(varchar,@i) + ','  
	  set @i = @i + 1  
	end  
	set @SQLString = @SQLSTring + 'AGGregate,EmptyCol FROM #Top5Rejects'  

	exec(@SQLString)  
 END
 
IF	@OutputType = 'SCRAPS'
BEGIN		
SELECT TOP 5	SortOrder, Desc01, CONVERT(INT, CONVERT(FLOAT, Events)) Events
		FROM	#Top5Rejects 
		WHERE	SortOrder > 3  and not Desc01 is null
		ORDER 	BY		CONVERT(FLOAT,EVENTS) DESC
END

 

----------------------------------------------------------------------------  
-- OUTPUT RESULT SETS FOR REPORT: Result Set 7 For Equations  
----------------------------------------------------------------------------  
If @OutputType <> 'KPIS' AND @OutputType <> 'Scraps'
BEGIN
	UPDATE #Equations Set Class = Class + ','  
	  
	Declare   
	 @ClassDesc as nvarchar(50),  
	 @iClass as int  
	  
	Set @ClassNo = 20 -- (Select Max(Class) FROM @Class)  
	  
	Set @iClass = 1  
	  
	While @iClass < @ClassNo + 1  
	Begin  
	  
	Set @ClassList = ''  
	  
	Declare cUnits Cursor For (Select PuDesc FROM @Class WHERE Class = @iClass)  
	Open cUnits  
	  
	Fetch Next FROM cUnits Into @ClassDesc  
	  
	While @@Fetch_Status = 0   
	Begin  
	 Set @ClassList = @ClassList + @ClassDesc + ';'  
	 Fetch Next FROM cUnits Into @ClassDesc  
	End  
	  
	Close cUnits  
	Deallocate cUnits  
	  
	Set @SQLString = 'UPDATE #Equations Set Class = Replace(Class,''' + CONVERT(varchar,@iClass)+ ','+''',''' + @ClassList + ''')'  
	Exec (@SQLString)  
	  
	-- print 'Cursor de Clases ->' + @SQLString  
	  
	Set @iClass = @iClass + 1  
	End  
	  
	-- Select * FROM #Equations  
	  
	Insert @RptEqns (VariableName, Equation) Values ('Variable Name','Equation')  
	Insert @RptEqns (VariableName, Equation) Values ('ACP Stops','Count of Packer Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('ACP Stops/Day','ACP Stops*1440/ (Uptime-Downtime)')  
	Insert @RptEqns (VariableName, Equation) Values ('Area 4 Loss','(Good Product - (Total Cases * Product per Case)) / Total Product')  
	Insert @RptEqns (VariableName, Equation) Values ('Availability','Uptime / (Uptime + Downtime)')  
	Insert @RptEqns (VariableName, Equation) Values ('CU','SUM(Good product / Ideal Speed) / Calendar Time  ')  
	Insert @RptEqns (VariableName, Equation) Select 'CaseCounter', 'Sum of ( Count of Product ) FROM ' + Class  FROM #Equations WHERE Variable = 'TotalPads'  
	Insert @RptEqns (VariableName, Equation) Values ('Down/MSU','Sum of Downtime / MSU')  
	Insert @RptEqns (VariableName, Equation) Select 'Downtime', Operator + ' of ( # of Stops with 3rd level FMECA edited ) FROM ' + Class  FROM #Equations WHERE Variable = 'Downtime'  
	Insert @RptEqns (VariableName, Equation) Select 'Downtime (Unplanned)', Operator + ' of ( # of Unplanned Stops with 3rd level FMECA edited ) FROM ' + Class  FROM #Equations WHERE Variable = 'Downtime'  
	Insert @RptEqns (VariableName, Equation) Values ('Downtime (Unplanned) %','Unplanned Downtime / Line Status Scheduled Time')  
	Insert @RptEqns (VariableName, Equation) Values ('Downtime Scrap','Converter Downtime Scrap in Pads')  
	Insert @RptEqns (VariableName, Equation) Values ('Downtime Scrap %','Downtime Scrap / Total Product in %')  
	Insert @RptEqns (VariableName, Equation) Select 'Edited Stops', Operator + ' of Downtimes FROM ' + Class  FROM #Equations WHERE Variable = 'NumEdits'  
	Insert @RptEqns (VariableName, Equation) Values ('Edited Stops%','% of Stops with 3rd level FMECA edited')  
	Insert @RptEqns (VariableName, Equation) Values ('Edited Stops Reason n' ,'Stops with n level of FMECA edited')  
	Insert @RptEqns (VariableName, Equation) Values ('Edited Stops Reason n %','% of Stops with n level of FMECA edited')  
	Insert @RptEqns (VariableName, Equation) Values ('Failed Splices','Count of Failed Splices')  
	Insert @RptEqns (VariableName, Equation) Values ('False Starts (0)','Count of Zero Ups')  
	Insert @RptEqns (VariableName, Equation) Values ('False Starts % (0)','False Starts (Zero Ups) / Line Stops (not filtered)')  
	Insert @RptEqns (VariableName, Equation) Select 'False Starts T', Operator + ' of (False Starts (Uptime <= 2) / Line Stops (not filtered)) FROM ' + Class  FROM #Equations WHERE Variable = 'FalseStartsT'  
	Insert @RptEqns (VariableName, Equation) Values ('False Starts % (T)','False Starts (Up time<=2) / Line Stops (not filtered)')  
	Insert @RptEqns (VariableName, Equation) Select 'Good Product',Operator + ' of ( Count of Good Product ) FROM ' + Class  FROM #Equations WHERE Variable = 'GoodPads'  
	Insert @RptEqns (VariableName, Equation) Select 'Ideal Speed', Operator + ' of Ideal Speed FROM ' + Class  FROM #Equations WHERE Variable = 'IdealSpeed'  
	Insert @RptEqns (VariableName, Equation) Values ('Line Speed','(Total Product - DowntimeScrap) / Uptime')  
	Insert @RptEqns (VariableName, Equation) Select 'Line Status Schedule Time', Operator + ' of ( Scheduled Time FROM STLS ) FROM ' + Class FROM #Equations WHERE Variable = 'ProdTime'  
	Insert @RptEqns (VariableName, Equation) Select 'Line Stops', Operator + ' of ( Count of Converter Stops ) FROM ' + Class  FROM #Equations WHERE Variable = 'LineStops'  
	Insert @RptEqns (VariableName, Equation) Select 'Line Stops (unplanned)', Operator + ' of ( Count of Unplanned Converter Stops ) FROM ' + Class  FROM #Equations WHERE Variable = 'LineStops'
	Insert @RptEqns (VariableName, Equation) Values ('MSU','Good Product / ProdPerStat / 1000')  
	Insert @RptEqns (VariableName, Equation) Values ('MTBF','Uptime / Unplanned Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('MTBS','Uptime / Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('MTTR','Downtime / Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('MTTR (unplanned)','Unplanned Downtime / Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('PR Using Avaiability','(Availability * (   1- (  Running Scrap / (Total Product - Downtime Scrap)  )   ) ')  
	Insert @RptEqns (VariableName, Equation) Values ('PR','Good Product * 100 / (Scheduled Time * Target Speed)  ')  
	Insert @RptEqns (VariableName, Equation) Values ('R(0)','Stops > 0 / Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('R(T)','Stops > T / Stops')  
	Insert @RptEqns (VariableName, Equation) Values ('RU','SUM(Good product / Ideal Speed) / SUM(Good product / Target Speed)')  
	Insert @RptEqns (VariableName, Equation) Values ('Real Downtime','Total Downtime with All shifts, All Teams, All Line Status, All Products')  
	Insert @RptEqns (VariableName, Equation) Values ('Real Uptime','Total Uptime with All shifts, All Teams, All Line Status, All Products')  
	Insert @RptEqns (VariableName, Equation) Values ('Rejected Product','Downtime Scrap  + Running Scrap')  
	Insert @RptEqns (VariableName, Equation) Select 'Repair Time > T', Operator + ' of ( Count Stops > T ) FROM ' + Class  FROM #Equations WHERE Variable = 'RepairTimeT'  
	Insert @RptEqns (VariableName, Equation) Values ('Run Efficiency','SUM(Good product / Target Speed) / (Line Status Scheduled Time - Planned Downtime)')  
	Insert @RptEqns (VariableName, Equation) Values ('Running Scrap','Converter Running Scrap in Pads')  
	Insert @RptEqns (VariableName, Equation) Values ('Running Scrap %','Running Scrap / Total Product')  
	Insert @RptEqns (VariableName, Equation) Values ('SU',' Line Status Scheduled Time / Calendar time')  
	Insert @RptEqns (VariableName, Equation) Select 'Total Scrap', Operator + ' of Total Scrap FROM ' + Class FROM #Equations WHERE Variable = 'TotalScrap'  
	Insert @RptEqns (VariableName, Equation) Values ('Converter Scrap %','Total Scrap / Total Product')  
	Insert @RptEqns (VariableName, Equation) Values ('STNU','Staffed Time Not Used')  
	Insert @RptEqns (VariableName, Equation) Values ('Stops Per Day','Line Stops * 1440 / (Uptime + Downtime)')  
	Insert @RptEqns (VariableName, Equation) Values ('Stops/MSU','Count of Stops / MSU')  
	Insert @RptEqns (VariableName, Equation) Select 'Success Rate', Operator + ' of ( Succesful Splices / Total Splices ) FROM ' + Class FROM #Equations WHERE Variable = 'SuccessRate'  
	Insert @RptEqns (VariableName, Equation) Values ('Suc. Splices','Count of Good Splices')  
	Insert @RptEqns (VariableName, Equation) Select 'Survival Rate', Operator + ' of ( Count of Uptime >' + CONVERT(varchar,@RPTDowntimesurvivalRate) + ' ) FROM ' + Class  FROM #Equations WHERE Variable = 'SurvivalRate'  
	Insert @RptEqns (VariableName, Equation) Values ('Survival Rate %','Survival Rate / (Scheduled Time / Time setpoint (default = 230))')  
	Insert @RptEqns (VariableName, Equation) Select 'Target Speed', Operator + ' of Target Speed FROM ' + Class  FROM #Equations WHERE Variable = 'TargetSpeed'  
	Insert @RptEqns (VariableName, Equation) Select 'Total Product', Operator + ' of ( Count of Product ) FROM ' + Class  FROM #Equations WHERE Variable = 'TotalPads'  
	Insert @RptEqns (VariableName, Equation) Select 'Total Splices', Operator + ' of ( Count of Total Splices ) FROM ' + Class FROM #Equations WHERE Variable = 'TotalSplices'  
	Insert @RptEqns (VariableName, Equation) Select 'Uptime', Operator + ' of ( Production Time - Downtime ) FROM ' + Class  FROM #Equations WHERE Variable = 'Uptime'  
END
-- Select * FROM #Equations  
-- Select * FROM @RptEqns --order by VariableName  
--  
----------------------------------------------------------------------------  
-- Drop Temporary All Tables:  
 --select * FROM #PLIDList  
-- select '#Production',* from #Production where PU_Id = 754 ORDER BY pu_id, StartTIME 
-- SELECT '#CrewDescList ', * FROM #CrewDescList  
-- SELECT '#PLStatusDESCList ', * FROM #PLStatusDESCList  
----------------------------------------------------------------------------  
--Print convert(varchar(25), getdate(), 120) + ' Finshed SP'  
    
DROP TABLE #Timed_Event_Detail_History  
DROP TABLE #PLIDList   
DROP TABLE #ShiftDESCList  
DROP TABLE #CrewDESCList   
DROP TABLE #PLStatusDESCList  
DROP TABLE #Summary  
DROP TABLE #Top5Downtime  
DROP TABLE #Top5Stops  
DROP TABLE #Top5Rejects  
DROP TABLE #Splices  
DROP TABLE #Rejects  
DROP TABLE #Downtimes  
DROP TABLE #Production  
DROP TABLE #InvertedSummary  
DROP TABLE #Temporary  
DROP TABLE #TemporaryFloat
DROP TABLE #FlexParam  
DROP TABLE #Equations  
DROP TABLE #ReasonsToExclude  
DROP TABLE #ac_Top5Downtimes  
DROP TABLE #ac_Top5Stops  
DROP TABLE #ac_Top5Rejects  
DROP TABLE #Temp_LinesParam  
DROP TABLE #Temp_ColumnVisibility  
DROP TABLE #Params  
DROP TABLE #Temp_Uptime  
DROP TABLE #Local_PG_StartEndTime
DROP TABLE #Event_Detail_History

  
  
RETURN  
GO

GRANT EXECUTE ON splocal_RptDPR TO OPDBManager 
GRANT EXECUTE ON spLocal_DPRFilter_BuildDictionary TO OPDBManager 
GO