
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--======================================================================================================================================
-- Check if the store procedure already exists in the Data Base
--======================================================================================================================================
IF	EXISTS(SELECT * FROM dbo.SYSOBJECTS WHERE Id = OBJECT_ID(N'[dbo].[spLocal_RptVariablesDetails]')
	AND OBJECTPROPERTY(Id, N'ISPROCEDURE') = 1)
BEGIN
	DROP PROCEDURE [dbo].[spLocal_RptVariablesDetails]
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
		@SP_Name	= 'spLocal_RptVariablesDetails',
		@Inputs		= 13,		-- Put the number of inputs here for support purposes
		@Version	= '1.6'		-- Number should match version manager, no exceptions.

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
-- Stored Procedure: spLocal_RptVariablesDetails
----------------------------------------------------------------------------------------------------------------------------------------
-- Author				: <Fernando Rios, Arido Software>
-- Date created			: 2005?
-- Version 				: Version 2.0
-- SP Type				: Report
-- Caller				: Report template (Excel)
-- Description			: Returns result set used by QA Variables Details report.
-- Editor tab spacing	: 4 <for devlopers so they can set visual studio correctly>
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
----------------------------------------------------------------------------------------------------------------------------------------
-- Revision		Date			Who					What  
----------------------------------------------------------------------------------------------------------------------------------------
-- 1.0			2019-03-11		Damian Campana		Initial Release
-- 1.1			2019-08-28		Damian Campana		Capability to filter with the time option 'Last Week'
-- 1.2			2019-10-17		Damian Campana		Check when result is not numeric
-- 1.3			2019-10-22		Federico Vicente	Change inVariablesList to NVARCHAR(MAX)
-- 1.4			2020-02-26		Gonzalo Luc			Fix variables, the variables were inserted x times depending on the lines selected. causing duplicated test records.
-- 1.5			2020-10-02		Namrata Kumar		FO-04265 Make it compatible with NPT 
-- 1.6			2021-07-27		Namrata Kumar		FO-04265 Add default status
----------------------------------------------------------------------------------------------------------------------------------------  
-- Report parameters :  
----------------------------------------------------------------------------------------------------------------------------------------  
CREATE PROCEDURE [dbo].[spLocal_RptVariablesDetails]
--DECLARE
		 @inTimeOption			INT					= NULL
		,@inPLIdList			NVARCHAR(200)		= NULL
		,@inProductGroup		NVARCHAR(1250)		= '!Null'	--List of ProductGrpIds from Product_Groups table to be included in the report.
		,@inProductId			NVARCHAR(1250)		= '!Null'		
		,@inShiftDesc			NVARCHAR(250)		= 'All'		--Shift Filter. Options: All or a ',' delimited list of Shift_Desc from Crew_Schedule table.
		,@inCrewDesc			NVARCHAR(250)		= 'All'		--Crew filter. Options: All or a ',' delimited list of Crew_Desc from the Crew_Schedule table.	
		,@inLineStatus			NVARCHAR(250)		= 'All'		--Line Status Filter. Options All or ',' delimited list of Phrase_Value from the Phrase table.
		,@inVariablesList		NVARCHAR(MAX)		= NULL		
		,@inMajorGroupBy		INT					= 0			--0: Product Group, 1: None, 2: PO, 3: Line.
		,@inStartDateTime		DATETIME			= NULL
		,@inEndDateTime			DATETIME			= NULL
		,@inShowOOSOnly			NVARCHAR(50)		= 'FALSE'	--If TRUE then show only variables out of specification, if FALSE will show all variables.
		,@inIncludeGenealogy	INT					= 1			--This parameter is used to enable or disable the PaperMachine genealogy. Options: 0 = No; 1 = Yes

--WITH ENCRYPTION 
AS
----------------------------------------------------------------------------------------------------------------------------------------
-- TEST values
----------------------------------------------------------------------------------------------------------------------------------------
--SELECT --EXEC [dbo].[spLocal_RptVariablesDetails]
-- @inTimeOption	=	2
--,@inPLIdList	=	'56,59,61'
--,@inProductGroup	= null
--,@inProductId		= null
--,@inShiftDesc		= 'All'
--,@inCrewDesc		= 'All'
--,@inLineStatus		= 'All'
--,@inVariablesList	= '111263,83832,78479,78480,111264,83833,111265,83834,78481,110998,67176,76056,111168,68123,76060,111169,68124,76061,111156,67513,76058,111157,67514,76059,111414,67452,76222,111429,83778,78421,111430,83779,78422,111413,67451,76220,111415,67453,76224,111428,67460,76086,111403,67435,76188,111380,67060,76189,111495,67445,76208,111464,67070,76209'
--,@inMajorGroupBy	= 0
--,@inStartDateTime	= null
--,@inEndDateTime		=  null
--,@inShowOOSOnly		= 'FALSE'
--,@inIncludeGenealogy = 0
----------------------------------------------------------------------------------------------------------------------------------------
-- Set old variables with the input parameters
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE
		 @var_List              NVARCHAR(MAX)		= @inVariablesList
		,@TimeOption			INT					= @inTimeOption	
		,@in_ShIFtDesc          VARCHAR(250)		= @inShiftDesc	
		,@in_CrewDesc           VARCHAR(250)		= @inCrewDesc	
		,@in_LineStatus         VARCHAR(250)		= @inLineStatus	
		,@ShowOOSOnly			NVARCHAR(50)		= @inShowOOSOnly
		,@PLIDList              NVARCHAR(200)		= @inPLIdList	
		,@in_ProductID          VARCHAR(1250)		= @inProductId	
		,@in_ProductGroup       VARCHAR(1250)		= @inProductGroup
		,@int_RptGroupBy		INT					= @inMajorGroupBy
		,@PLDescList			NVARCHAR(500)		= NULL
		,@intUseRptGenealogy	INT					= @inIncludeGenealogy
		,@in_StartTime			DATETIME			= NULL				
		,@in_EndTime			DATETIME			= NULL				

----------------------------------------------------------------------------------------------------------------------------------------

SET NOCOUNT ON


----------------------------------------------------------------------------------------------------------------------------------------
-- SET STATISTICS IO OFF
----------------------------------------------------------------------------------------------------------------------------------------
PRINT	'	- Create temporary tables '
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #PLIDList  (
							RCDID					 INT			,							
							PL_ID					 INT			,
							PL_Desc					 NVARCHAR(200)	,
							HasPrdPath				 NVARCHAR(3)	,
							in_StartTime			 DATETIME		,
							in_EndTime				 DATETIME 			)

----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #ProdUnitPrdPath		(	
							PU_Id						INT			,
							PU_Desc						VARCHAR(200),	
							PL_Id						INT			,
							Path_Id						INT			,
							Unit_Order					INT,
							Class						INT,
							IsConvertingUnit			INT DEFAULT 0,
							-- STLSUnit					INT -- In CASE is not using PrdUnitPath
)
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #Var_IDs       (	
							RCDID   					INT,
			             	Var_ID  					INT,
							PVarId						INT DEFAULT NULL,
			                Var_Desc 					NVARCHAR(255),
			                PUG_Id  					INT,
			            	Data_Type_id 				INT,
			            	PLID 						INT,
			            	PLDESC 						VARCHAR(50),	
							SourcePUId					INT,
			            	SourcePUDesc				VARCHAR(50),
			            	PUId	 					INT,
							VarDataTypeId				INT,
							IsReportable				INT	DEFAULT 1,	-- Options: 1 = YES; 0 = NO
							IsConverting				INT DEFAULT 0,	-- Options: 1 = YES; 0 = NO
							EventSubtypeId				INT,
							RptSPCParent				INT	DEFAULT	0, 	-- Options: 1 = the code should report the values for the parent
																		-- 		  : 0 = the code should report the values for the children
							)
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #Prod_IDs		(
		                     RCDID   					INT,
		                     Prod_id  					INT,
		                     Prod_Desc 					VARCHAR(100),
		                     Prod_Group_Desc 			VARCHAR(50)
							)
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #Product_Group_Data(
		                     RCDID   					INT,
		                     Product_Grp_id  			INT	
							)
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #All_Variables     (	
							Var_ID 						INT				,
		                    Var_Desc 					NVARCHAR(255)	,
							PL_Id						INT				,
							PL_Desc						NVARCHAR(200)	,
		                    Pu_Id   					INT				,
							SourcePU_Id					INT				,
		                    Pug_Desc 					NVARCHAR(150)	,
		                	Result_on 					DATETIME		NULL,
		                    Entry_on 					DATETIME		NULL,
		                    Entry_By 					NVARCHAR(150)	,
		                	Result 						VARCHAR(50)		,
		                	L_Reject 					VARCHAR(25)		, 
		                	L_Warning 					VARCHAR(25)		, -- shifted L_Control
		                	L_User 						VARCHAR(25)		, -- Now will hold the Target Low
							L_Control					VARCHAR(25)     , -- L_Warning ( again)
		                	Target 						VARCHAR(25)		,
							U_Control					VARCHAR(25)		, -- U_Warning ( again)
		                	U_User 						VARCHAR(25)		, -- Now will hold the Target High
		                	U_Warning 					VARCHAR(25)		, -- shifted U_Control
		                	U_Reject 					VARCHAR(25)		,
		                	Include_Result 				VARCHAR(10)		,
		                	Include_Crew 				VARCHAR(10)		,
		                	Include_ShIFt 				VARCHAR(10)		,
		                	Include_LineStatus 			VARCHAR(10)		,
		                	Crew						VARCHAR(10)		,
		                	ShIFt 						VARCHAR(10)		,
		                	LineStatus					VARCHAR(50)	 	,
							PO							VARCHAR(15)		,
		                	STLSUnit 					INT				,
		                	Prod_ID 					INT				,
		                	Prod_Desc					VARCHAR(100)		,
		                    Prod_Group          		VARCHAR(75)		,
							SourceProd_Id				INT				,
		                    -- UD2_Spec_Id         		INT				, This field is obsoleted
		                    -- Tgt_high            		VARCHAR(25)		, This field is obsoleted, replaced by the U_User
		                    -- Tgt_low             		VARCHAR(25)		, This field is obsoleted, replaced by the L_User
							TestCount					INT				,
							Comment_Id					INT				,
							CommentDesc					NVARCHAR(1000)	,
							InSpec						VARCHAR(3)		,
							SummaryRow					VARCHAR(3)		,
							Defect						INT				,
							ProdGrouping				VARCHAR(150)	,
							Order_None 					NVARCHAR(255)	,
							NonNumericFlag				INT				, -- 0 if Numeric 1 if Non Numeric
							IsTAMUVariable				INT	DEFAULT 0	, -- If Numeric = 0 and L_Reject or U_Reject Exists then 1 Else = 0
							Event_Num					NVARCHAR(100)	,
							SourceTime					DATETIME		,
							Temp_Var_Desc 				NVARCHAR(255)	
							)
----------------------------------------------------------------------------------------------------------------------------------------
Create Table #ListDefaultPUGDesc (
		                    RcdId 						INT				, 
		                    PUGDesc 					VARCHAR(100))
----------------------------------------------------------------------------------------------------------------------------------------
Create Table #Production_Starts  (
					 		Pu_id						INT				,
							Start_Time					DATETIME		,
							END_Time					DATETIME		,
							Prod_Id						INT			) 
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE  #Crew_Schedule  	 (
						   Start_Time				DATETIME			,
						   END_Time					DATETIME			,
						   Pu_id						INT				,
						   Crew_Desc					VARCHAR(100)	,
						   ShIFt_Desc				VARCHAR(100))
----------------------------------------------------------------------------------------------------------------------------------------
--CREATE TABLE #Local_PG_Line_Status (
--							Start_DATETIME			DATETIME			,
--							END_DATETIME			DATETIME			,
--							Unit_id					INT					,
--							LineStatus				VARCHAR(300))

CREATE TABLE #NPT_Status (
							Start_DATETIME			DATETIME			,
							END_DATETIME			DATETIME			,
							Unit_id					INT					,
							LineStatus				VARCHAR(300))
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #Temp_Dates (
							StartDate        datetime,
							EndDate          datetime)
----------------------------------------------------------------------------------------------------------------------------------------
CREATE TABLE #POs	(
							PU_Id					INT,
							Fore_Start_Date			DATETIME,
							Fore_End_Date			DATETIME,
							Prod_Id					INT,
							PO						VARCHAR(15))
--							ECR#EM-00050
--							PO						INT)


----------------------------------------------------------------------------------------------------------------------------------------
-- Variable tables
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE @PO_Sheets	TABLE 
					(		PO						VARCHAR(15) 		)
--					ECR#EM-00050
--					(		PO						INT			)

DECLARE @ProdGroup_Sheet TABLE
					(		ProdGroup_Desc			NVARCHAR(200))

DECLARE	@tblListEventSubTypes	TABLE	(
							RcdIdx			INT	IDENTITY (1,1),
							EventSubTypeId	INT					)

DECLARE	@tblListConvertingPUTemp	TABLE (
							RcdIdx						INT	IDENTITY (1,1),
							PLId						INT,
							PUId						INT		)

----------------------------------------------------------------------------------------------------------------------------------------
--	List of Sample Id's
----------------------------------------------------------------------------------------------------------------------------------------

DECLARE	@tblSampleList	TABLE (
							RcdIdx						INT	Identity(1,1),
							ConvertingPUId				INT,
							SampleId					INT,
							EndTime						DATETIME,
							EventNum					NVARCHAR(100),
							EventSubtypeId				INT,
							ConvertingSample			INT DEFAULT	1,
							SourcePUId					INT,
							SourceTime					DATETIME,
							SampleDesc					NVARCHAR(100)	)

----------------------------------------------------------------------------------------------------------------------------------------
--	List of Sample Id's
----------------------------------------------------------------------------------------------------------------------------------------

DECLARE	@tblOffLineSampleList	TABLE (
							RcdIdx						INT	Identity(1,1),
							ConvertingPUId				INT,
							PUId						INT,
							SampleId					INT,
							EndTime						DATETIME,
							SourceTime					DATETIME,
							EventNum					NVARCHAR(100),
							EventSubtypeId				INT,
							SampleDesc					NVARCHAR(100)	)
----------------------------------------------------------------------------------------------------------------------------------------
--	List of Source Machines feeding the converting lines 
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE	@tblSourcePUList	TABLE (
		RcdIdx		INT	Identity(1,1),
		SourcePUId	INT)

----------------------------------------------------------------------------------------------------------------------------------------
-- DECLARE Variables that will be used by the sp
----------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------
-- INTEGERS
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE
			   @AS_id                  				INT				,
			   @variable_id            				INT				,
			   @variable_index         				INT				,
			   @i                      				INT				,
			   @intPeriodIncompleteFlag				INT				,
			   @Var_Id								INT			 	,
			   @intTableId							INT				,
			   @intTableFieldId						INT				,
			   @intMaxRcdIdx 						INT				,
			   @intConvertingPUId 					INT				,
			   @intConvertingPLId					INT				,
			   @intApplyIsReportableUDP				INT					-- 0 = No ( Variables source comes from Web Page)
																		-- 1 = Yes ( Variables source dont comes from Web Page)
----------------------------------------------------------------------------------------------------------------------------------------
-- DATETIMES
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE
			   @maxtimestatus          				DATETIME		,
			   @MinTime                				DATETIME		,
			   @Result_Time            				DATETIME		,	
			   @vchTimeOption						NVARCHAR(50)

----------------------------------------------------------------------------------------------------------------------------------------
-- VARCHARS
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE
			   @crew_desc              				VARCHAR(30)		,
			   @include_crew           				VARCHAR(3)		,
			   @include_linestatus     				VARCHAR(3)		,
			   @include_month          				VARCHAR(3)		,
			   @include_result         				VARCHAR(3)		,
			   @include_shIFt          				VARCHAR(3)		,
			   @line_status            				VARCHAR(30)		,
			   @result                 				VARCHAR(25)		,
			   @shIFt_desc             				VARCHAR(30)		,
			   @variable_desc          				VARCHAR(50)		,
			   @ls                     				VARCHAR (25)	,
			   @lc                     				VARCHAR (25)	,
			   @lw                     				VARCHAR (25)	,
			   @target                 				VARCHAR (25)	,
			   @uw                     				VARCHAR (25)	,
			   @uc                     				VARCHAR (25)	,
			   @us                     				VARCHAR (25)	,
			   @SQLString              				NVARCHAR(4000)	,
			   @RptDefaultPUGDescList  				NVARCHAR(1000)	,
			   @PASs				   				NVARCHAR(50)	,
			   @Fail				   				NVARCHAR(50)	,
			   @DBVersiON							NVARCHAR(10) 	,
			   @strQualityUnit						NVARCHAR(50) 	,
   			   @ReportType							NVARCHAR(20)	,
			   @vchUDPDescReportable				VARCHAR(25)		,
			   @vchUDPDescSPCParent					VARCHAR(25)		,
			   @vchUDPDescDefaultQProdGrps			VARCHAR(25)		,
			   @vchUDPDescIsConvertingLine			VARCHAR(25)		,
			   @vchUDPDescIsOfflineQuality			VARCHAR(25)		,
				-- Add for search Version
				@vchAppVersion						VARCHAR(10)		,
				@vchRTVersion						VARCHAR(10)		,
				@vchSP_name							VARCHAR(50)		,
				@vchRT_xlt							VARCHAR(50)	

----------------------------------------------------------------------------------------------------------------------------------------
--	UDP field names
----------------------------------------------------------------------------------------------------------------------------------------
SELECT	
		@vchUDPDescReportable		=	'Reportable',
		@vchUDPDescSPCParent		= 	'RptSPCParent',
		@vchUDPDescDefaultQProdGrps	=	'DefaultQProdGrps',
		@vchUDPDescIsConvertingLine	= 	'IsConvertingLine',
		@vchUDPDescIsOfflineQuality	=	'IsOfflineQuality'

----------------------------------------------------------------------------------------------------------------------------------------
-- Init Temporay tables, done to minimize recompiles
----------------------------------------------------------------------------------------------------------------------------------------
SET @i = (SELECT	Count(*) FROM 	 #Var_Ids)
SET @i = (SELECT	Count(*) FROM 	 #Prod_Ids)
SET @i = (SELECT	Count(*) FROM 	 #All_Variables)
SET @i = (SELECT	Count(*) FROM 	 #ListDefaultPUGDesc)
SET @i = (SELECT	Count(*) FROM 	 #Production_Starts)
SET @i = (SELECT	Count(*) FROM 	 #PLIDList)
SET @i = (SELECT	Count(*) FROM 	 #Crew_Schedule)
SET @i = (SELECT	Count(*) FROM 	 #NPT_Status)
SET @i = (SELECT	Count(*) FROM 	 #Product_Group_Data)
SET @i = (SELECT	Count(*) FROM 	 #ProdUnitPrdPath)

-----------------------------------------------------------------------------------------------------------------------
-- Retrive parameter values FROM report definition 
-----------------------------------------------------------------------------------------------------------------------
SELECT @ReportType = 'Details'

----------------------------------------------------------------------------------------------------------------------------------------
-- Primary Key of Product (or can be NULL IF @in_ProductGroup IS populated)	   
-- Primary Key of Product Group (or can be NULL IF @in_ProductID IS populated)
----------------------------------------------------------------------------------------------------------------------------------------
  
SET @in_ProductID           = ISNULL(@in_ProductID,'!NULL')        
SET @in_ProductGroup        = ISNULL(@in_ProductGroup,'!NULL')     
  
----------------------------------------------------------------------------------------------------------------------------------------
-- GET Proficy Version
----------------------------------------------------------------------------------------------------------------------------------------
IF	(	SELECT		IsNumeric(App_Version)
				FROM	dbo.AppVersions WITH(NOLOCK)
				WHERE	App_Id = 2) = 1
BEGIN
		SELECT		@DBVersiON = Convert(Float, App_Version)
			FROM	dbo.AppVersions WITH(NOLOCK)
			WHERE	App_Id = 2
END
ELSE
BEGIN
		SELECT	@DBVersiON = 1.0
END

----------------------------------------------------------------------------------------------------------------------------------------
-- Time Options
----------------------------------------------------------------------------------------------------------------------------------------
	IF @TimeOption = -1 
	BEGIN 
		SELECT @in_StartTime = @inStartDateTime ,@in_EndTime = @inEndDateTime  
	END
	ELSE
	BEGIN
		SELECT @vchTimeOption = 
			CASE @TimeOption
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
			SELECT	@in_StartTime = dtmStartTime,
					@in_EndTime = dtmEndTime
			FROM [dbo].[fnLocal_DDSStartEndTime](@vchTimeOption)

		END
	END

----------------------------------------------------------------------------------------------------------------------------------------
-- GET SITE
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE				@Plant			NVARCHAR(200)

SELECT @Plant =  COALESCE(Value, 'Site Name')
	FROM 	dbo.Site_Parameters WITH(NOLOCK)
	WHERE 	Parm_Id = 12

----------------------------------------------------------------------------------------------------------------------------------------
-- Getting ProdId
----------------------------------------------------------------------------------------------------------------------------------------
IF (@in_ProductGroup <> '0')
BEGIN
                    INSERT #Product_Group_Data (RCDID, Product_Grp_Id)
                	EXEC SPCMN_ReportCollectionParsing
                	@PRMCollectionString = @in_ProductGroup, @PRMFieldDelimiter = NULL, @PRMRecordDelimiter = '|',	
                	@PRMDataType01 = 'INT'	
END


IF EXISTS (SELECT * FROM #Product_Group_Data WHERE Product_Grp_Id > 0)
	BEGIN

        INSERT INTO #Prod_IDs (Prod_id)
        SELECT Distinct Prod_Id
    	FROM dbo.Product_Group_Data WITH(NOLOCK)
    	WHERE Product_Grp_Id IN (SELECT Product_Grp_Id FROM #Product_Group_Data WHERE Product_Grp_Id > 0)

	END
ELSE
	BEGIN
            IF (@in_ProductID <> '0')
            BEGIN
                    INSERT #Prod_IDs (RCDID, Prod_id)
                	EXEC SPCMN_ReportCollectionParsing
                	@PRMCollectionString = @in_ProductID, @PRMFieldDelimiter = NULL, @PRMRecordDelimiter = '|',	
                	@PRMDataType01 = 'INT'	
            END            
	END

----------------------------------------------------------------------------------------------------------------------------------------
-- Get Line List, get Production Path Units and Slave Units
----------------------------------------------------------------------------------------------------------------------------------------

IF	LEN(IsNull(@PLIdList, '')) > 0 AND @PLIdList <> '!NULL'  
BEGIN
			INSERT INTO #PLIDList(RCDID, PL_Id)
			EXEC SPCMN_ReportCollectionParsing
					@PRMCollectionString = @PLIDList, @PRMFieldDelimiter = null, @PRMRecordDelimiter = ',',	
					@PRMDataType01 = 'INT'

			UPDATE #PLIDList 
					SET in_StartTime = @in_StartTime,
						in_EndTime	 = @in_EndTime


			IF NOT EXISTS (SELECT * FROM #Prod_Ids)
			BEGIN
				-- This means that no Product Group Filtering
				-- 
				INSERT #Prod_IDs (Prod_id)
				SELECT DISTINCT ps.Prod_Id 
				FROM dbo.Production_Starts ps WITH(NOLOCK)				
				JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.PU_Id = ps.PU_Id
				JOIN #PLIDList pl ON pl.PL_ID = pu.PL_Id
				WHERE ps.Start_Time <= @in_EndTime
				   	AND (ps.End_Time > @in_StartTime OR ps.End_Time IS NULL)
					AND Prod_Id > 1
			END

END
ELSE
BEGIN
		IF EXISTS(SELECT * FROM #Prod_Ids)
		BEGIN
				
				INSERT INTO #PLIDList(PL_Id,in_StartTime, in_EndTime )
				SELECT pu.PL_ID,MIN(ISNULL(Start_Time,@in_StartTime)),MAX(ISNULL(End_Time,@in_EndTime)) 
				FROM dbo.Production_Starts ps WITH(NOLOCK)
				JOIN #Prod_Ids prod ON ps.Prod_Id = prod.Prod_Id
				JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.PU_Id = ps.PU_Id
				WHERE pu.PL_Id > 0 
				AND   ps.Start_Time <= @in_EndTime
			    	AND (ps.End_Time > @in_StartTime OR ps.End_Time IS NULL)
				GROUP BY pu.PL_Id		

				UPDATE #PLIDList
					SET 	in_StartTime = (CASE WHEN in_StartTime < @in_StartTime THEN @in_StartTime 
												 ELSE in_StartTime END ),
							in_EndTime = (CASE WHEN in_EndTime > @in_EndTime THEN @in_EndTime 
												 ELSE in_EndTime END)
		

		END
		ELSE
		BEGIN
				INSERT INTO #PLIDList(PL_Id, in_StartTime, in_EndTime)
				SELECT PL_Id , @in_StartTime, @in_EndTime
				FROM dbo.Prod_Lines_Base WITH(NOLOCK)
				WHERE PL_Id > 0

				-- Now get Products cause this means that no products
				INSERT #Prod_IDs (Prod_id)
				SELECT DISTINCT ps.Prod_Id 
				FROM dbo.Production_Starts ps WITH(NOLOCK)				
				JOIN dbo.Prod_Units_Base pu WITH(NOLOCK) ON pu.PU_Id = ps.PU_Id
				JOIN #PLIDList pl ON pl.PL_ID = pu.PL_Id
				WHERE ps.Start_Time <= @in_EndTime
			    AND (ps.End_Time > @in_StartTime OR ps.End_Time IS NULL)
				AND ps.Prod_Id > 1


		END
END

----------------------------------------------------------------------------------------------------------------------------------------
PrINT 'Getting #Var_Ids'
----------------------------------------------------------------------------------------------------------------------------------------
-- IF variable list IS empty then get variables FROM the PUG List
-- SELECT @Var_List
----------------------------------------------------------------------------------------------------------------------------------------
--	Set the Flag to apply the IsReportable UDP to TRUE
----------------------------------------------------------------------------------------------------------------------------------------
SET  @intApplyIsReportableUDP	= 1 	-- Yes

----------------------------------------------------------------------------------------------------------------------------------------
--	a.	IF a list of variables is selected return all variables that match the variable description
----------------------------------------------------------------------------------------------------------------------------------------
IF @Var_List > ''
    BEGIN
            INSERT #Var_IDs (RCDID, var_id)
            EXEC SPCMN_ReportCollectionParsing
            @PRMCollectionString = @var_List, @PRMFieldDelimiter = NULL,
            @PRMRecordDelimiter = ',', @PRMDataType01 = 'INT'	
	
			-----------------------------------------------------------------------------------------------------------------------
			--	Set the Flag to apply the IsReportable UDP to FALSE - Report will show all selected variables, no matter if they 
			--  are Reportable or Not.
			-----------------------------------------------------------------------------------------------------------------------
			SET 	@intApplyIsReportableUDP	= 0 	-- No

    END
ELSE
    BEGIN
			-------------------------------------------------------------------------------------------------------------------
			--	b.	ELSE return all variables that belong the to default variable groups
			--		The production groups will be identified by a UDP on the PU_Groups table
			--		Table = PU_Groups 
			--		Table_Fields = DefaultQProdGrps of type numeric
			--		Table_Field_Values has a record for each PUG_Id that should be included in the DefaultQProdGrpss
			--		Business Rule: if DefaultQProdGrps = 1 include variable group in PPM report ELSE do not include
			-------------------------------------------------------------------------------------------------------------------
			--	GET table Id for PU_Groups
			-------------------------------------------------------------------------------------------------------------------	
			SELECT	@intTableId = TableId
			FROM	dbo.Tables	WITH (NOLOCK)	
			WHERE	TableName = 'PU_Groups'

			SELECT	@intTableFieldId = 0
			-------------------------------------------------------------------------------------------------------------------	
			--	GET table field Id for DefaultQProdGrps
			-------------------------------------------------------------------------------------------------------------------	
			SELECT	@intTableFieldId = Table_Field_Id
			FROM	dbo.Table_Fields	WITH (NOLOCK)
			WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps
    

			INSERT INTO #Var_Ids (
									Var_Id)
			SELECT 					DISTINCT 		v.Var_Id
            FROM dbo.Variables_Base  v  			WITH(NOLOCK)
			JOIN dbo.Prod_Units_Base pu 			WITH(NOLOCK) 
													ON pu.PU_Id = v.PU_Id
			JOIN #PLIdList      pl  				ON pl.PL_Id = pu.PL_Id
            JOIN dbo.PU_Groups PUG  				WITH(NOLOCK) 
													ON pug.pug_id = v.pug_id
			JOIN dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
													ON	tfv.KeyId = pug.PUG_Id
            WHERE 	tfv.TableId = @intTableId
					AND	tfv.Table_Field_Id = @intTableFieldId
					AND	tfv.Value = 'Yes'
					AND	pug.PU_Id > 0
					-- FO-00661: Should exclude only using prefix 
					-- AND v.Var_Desc NOT LIKE 'z_obs%'
    END

----------------------------------------------------------------------------------------------------------------------------------------
-- GET LINES AND PRODUCTION UNITS FROM PRODUCTION PATH
----------------------------------------------------------------------------------------------------------------------------------------
IF EXISTS (SELECT * FROM #PLIDList)
BEGIN
			-- 		IF Production Line is selected but Production Unit IS NULL 
			--		THEN return ALL Production Units that belong to the selected Production Lines 
			--		AND	include the default Variable Groups
			-- 		OR the Variables Selected

			-----------------------------------------------------------------------------------------------------------
			--	GET table Id for PU_Groups
			-----------------------------------------------------------------------------------------------------------
			SELECT	@intTableId = TableId
			FROM	dbo.Tables	WITH (NOLOCK)	
			WHERE	TableName = 'PU_Groups'


			SELECT	@intTableFieldId = 0
			------------------------------------------------------------------------------------------------------------	
			--	GET table field Id for DefaultQProdGrps
			------------------------------------------------------------------------------------------------------------
			SELECT	@intTableFieldId = Table_Field_Id
			FROM	dbo.Table_Fields	WITH (NOLOCK)
			WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps

			------------------------------------------------------------------------------------------------------------	
			-- GET Production Units
			------------------------------------------------------------------------------------------------------------	
			INSERT INTO #ProdUnitPrdPath (
					PU_Id	,
					PL_Id	)
			SELECT 	DISTINCT
					pu.PU_Id,
					pu.PL_Id
			FROM	dbo.Prod_Units_Base			pu		WITH (NOLOCK)	
	 			JOIN	#PLIDList	pl				ON	pl.PL_Id = pu.PL_Id
				JOIN	dbo.PU_Groups		pg		WITH (NOLOCK)
													ON	pu.PU_Id = pg.PU_Id
				JOIN	dbo.Table_Fields_Values	tfv	WITH (NOLOCK)
													ON	tfv.KeyId = pg.PUG_Id
			WHERE	tfv.TableId = @intTableId
				AND	tfv.Table_Field_Id = @intTableFieldId
				AND	tfv.Value = 'Yes'
				AND	pg.PU_Id > 0						

			SELECT	@intTableFieldId = 0
			-----------------------------------------------------------------------------------------------------------------------
			--  Find the Lines Tagged as Converters from the UDPs
			--	Get Field Id
			-----------------------------------------------------------------------------------------------------------------------
			SELECT	@intTableFieldId = Table_Field_Id
			FROM	dbo.Table_Fields   WITH (NOLOCK)
			WHERE	Table_Field_Desc = @vchUDPDescIsConvertingLine
			-----------------------------------------------------------------------------------------------------------------------
			-- For Baby Fem we are using STLS
			-- Now use UDP vs Extended_Info so will get the information from 
			-----------------------------------------------------------------------------------------------------------------------

			UPDATE #ProdUnitPrdPath
				SET IsConvertingUnit = tfv.Value
			FROM 	#ProdUnitPrdPath pupp
			JOIN 	dbo.Prod_Units_Base pu 		WITH(NOLOCK) 		ON 		pu.PU_id = pupp.PU_Id
			JOIN 	#PLIDList pl 								ON 		pupp.PL_Id = pl.PL_Id
			JOIN	dbo.Table_Fields_Values	tfv	WITH(NOLOCK)	ON		pl.PL_Id = tfv.KeyId
			WHERE 	tfv.Table_Field_Id = @intTableFieldId

			-------------------------------------------------------------------------------------------------------
			-- Update PU_Description and Path_Id
			-------------------------------------------------------------------------------------------------------
			UPDATE #ProdUnitPrdPath
					SET PU_Desc = pu.PU_Desc, 
						Path_Id = pepu.Path_id
				FROM #ProdUnitPrdPath pupp
				JOIN dbo.Prod_Units_Base pu  WITH(NOLOCK)	
													ON 	pupp.PU_Id = pu.PU_Id
				JOIN dbo.PrdExec_Path_Units pepu WITH(NOLOCK)
													ON 	pepu.PU_Id = pu.PU_Id
				join dbo.PrdExec_Paths pep WITH(NOLOCK)
													ON 	pep.Path_Id = pepu.Path_Id

END



----------------------------------------------------------------------------------------------------------------------------------------
PrINT 'Get Process Orders'
----------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO		#POs	(
				PU_Id,
				Fore_Start_Date,
				Fore_End_Date,
				Prod_Id,
				PO			)
SELECT 			
				pu.PU_Id				,
				pps.Start_Time			,
				pps.End_Time			,
				pp.Prod_Id				,
				pp.Process_Order
FROM dbo.Production_Plan_Starts pps WITH(NOLOCK)
JOIN dbo.Production_Plan pp 		WITH(NOLOCK)	ON pp.PP_Id = pps.PP_Id
JOIN #ProdUnitPrdPath  pupp							ON pupp.Path_id	=	pp.Path_Id
JOIN dbo.Prod_Units_Base pu 		WITH(NOLOCK)	ON pu.Pu_Id 	= 	pupp.Pu_Id 
WHERE 	pps.Start_Time > @in_StartTime
		AND pps.Start_Time < @in_EndTime
		AND pp.Process_Order LIKE '%[0-9]%' 
		AND	pp.Process_Order NOT LIKE '%[a-zA-Z]%'
		AND pp.Process_Order NOT LIKE '%-%'
		AND pp.Process_Order NOT LIKE '%/%'
ORDER BY pps.Start_Time 

----------------------------------------------------------------------------------------------------------------------------------------
PrINT 'Get PASs/Fail phrASes FROM Data Types'
----------------------------------------------------------------------------------------------------------------------------------------
-- Get 'PASs' data type
SELECT @PASs = ISNULL(PhrASe_Value,'PASS') 
FROM dbo.Phrase WITH(NOLOCK)
WHERE Data_Type_Id = 
		(SELECT Data_Type_Id FROM dbo.Data_Type WITH(NOLOCK)
			WHERE Data_Type_Desc Like 'PASSFail')
AND PhrASe_Order = 1

-- Get 'Fail' data type
SELECT @Fail = ISNULL(PhrASe_Value,'Fail') FROM dbo.Phrase  WITH(NOLOCK)
	WHERE Data_Type_Id = 
		(SELECT Data_Type_Id FROM dbo.Data_Type  WITH(NOLOCK)
			WHERE Data_Type_Desc Like 'PASsFail')
AND PhrASe_Order = 2

SELECT 	@Pass = ISNULL(@Pass,'PASS'), 
		@Fail = ISNULL(@Fail,'FAIL')
 
----------------------------------------------------------------------------------------------------------------------------------------
PrINT 'Getting the SpecificationSetting parameter'
----------------------------------------------------------------------------------------------------------------------------------------
-- GET spec setting from dbo.Site_Parameters table
-- IF @greater_equal	 = 1 then limit analysis is >
-- ELSE limit analysis is >=
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE 
				@greater_equal				INT

SELECT @greater_equal = value 
FROM dbo.Site_Parameters sp  WITH(NOLOCK)
JOIN dbo.Parameters p  WITH(NOLOCK) ON sp.parm_id = p.parm_id
		WHERE Parm_Name like '%SpecIFicationSetting%'

----------------------------------------------------------------------------------------------------------------------------------------
-- INSERT Child Variables from Master Variables
-- 1. ONLY IF THEY ARE REPORTABLE !
-- 2. If child variables exists, then delete parent variable.
----------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO #Var_Ids ( 
						Var_Id		,
						PVarId 		)
SELECT 					v.Var_Id 	,
						v.PVar_Id
FROM 	#Var_IDs 		vids
JOIN	dbo.Variables_Base 	v 		WITH(NOLOCK)
								ON v.PVar_Id = vids.Var_Id	
WHERE 	vids.Var_Id NOT IN (SELECT Var_Id FROM #Var_Ids)

----------------------------------------------------------------------------------------------------------------------------------------
-- Check if use Genealogy: Get Paper Machine Offline Quality Variables for Converting Lines (Options: 0 = No; 1 = Yes)
----------------------------------------------------------------------------------------------------------------------------------------
IF @intUseRptGenealogy = 1
BEGIN
	-----------------------------------------------------------------------------------------------------------------------
	-- Go upstream for genelalogy and get linked lines from User Defined Events
	-----------------------------------------------------------------------------------------------------------------------
	--=====================================================================================================================
	--	GET Paper Machine Offline Quality Variables for Converting Lines
	--	Business Rule: if the user has selected a PU that belongs to a converting line, then the logic must go to the paper
	--	machine and pull all the variables for the PM Offline Quality into the report.
	-----------------------------------------------------------------------------------------------------------------------
	--	GET table Id for PU_Groups
	-----------------------------------------------------------------------------------------------------------------------	
	SELECT	@intTableId = TableId
	FROM	dbo.Tables	WITH (NOLOCK)	
	WHERE	TableName = 'Event_SubTypes'

	SELECT	@intTableFieldId = 0
	-----------------------------------------------------------------------------------------------------------------------	
	--	GET table field Id for DefaultQProdGrps
	-----------------------------------------------------------------------------------------------------------------------	
	SELECT	@intTableFieldId = Table_Field_Id
	FROM	dbo.Table_Fields	WITH (NOLOCK)
	WHERE	Table_Field_Desc = @vchUDPDescIsOfflineQuality
	-----------------------------------------------------------------------------------------------------------------------
	--	Get list of event subtypes
	-----------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListEventSubTypes (
				EventSubTypeId)
	SELECT	Event_SubType_Id
	FROM	dbo.Event_SubTypes		es	WITH (NOLOCK)
	JOIN	dbo.Table_Fields_Values	tfv	WITH (NOLOCK)
										ON	tfv.KeyId = es.Event_SubType_Id
	WHERE	tfv.TableId = @intTableId
			AND	tfv.Table_Field_Id = @intTableFieldId
			AND	tfv.Value = 'Yes'

	IF  EXISTS  (	SELECT *
					FROM   #ProdUnitPrdPath
					WHERE  IsConvertingUnit = 1)
	BEGIN
				-------------------------------------------------------------------------------------------------------------------
				--	Get the list of converting PU's
				-------------------------------------------------------------------------------------------------------------------
				INSERT INTO	@tblListConvertingPUTemp	(
							PLId,
							PUId	)
				SELECT	PL_Id,
						PU_Id
				FROM	#ProdUnitPrdPath
				WHERE	IsConvertingUnit = 1

		-------------------------------------------------------------------------------------------------------------------
		--	Initialize Variables
		-------------------------------------------------------------------------------------------------------------------
		SELECT	@i = 1,
				@intMaxRcdIdx = MAX(RcdIdx)
		FROM	@tblListConvertingPUTemp
		-------------------------------------------------------------------------------------------------------------------
		--	Loop through converting PU's and get the paper machine variables
		-------------------------------------------------------------------------------------------------------------------
		WHILE	@i <= @intMaxRcdIdx
		BEGIN
			---------------------------------------------------------------------------------------------------------------
			--	Get PU to search
			---------------------------------------------------------------------------------------------------------------
			SELECT	@intConvertingPUId = PUId,
					@intConvertingPLId = PLId
			FROM	@tblListConvertingPUTemp
			WHERE	RcdIdx = @i		
			---------------------------------------------------------------------------------------------------------------
			--	GET a List of all the Samples (UDE's) on that converting PU
			---------------------------------------------------------------------------------------------------------------
			INSERT INTO	@tblSampleList (
						SampleId, EndTime, EventSubtypeID)
			SELECT	UDE_Id, End_Time, ude.Event_Subtype_Id
			FROM	dbo.User_Defined_Events			ude	WITH (NOLOCK)
				JOIN		@tblListEventSubTypes	est	ON	est.EventSubTypeId = ude.Event_SubType_Id
			WHERE	ude.PU_Id = @intConvertingPUId
					AND	End_Time >= @in_StartTime
					AND	End_Time < 	@in_EndTime

			---------------------------------------------------------------------------------------------------------------
			--	Get the source machines (PU's)
			---------------------------------------------------------------------------------------------------------------
			DELETE	@tblSourcePUList
			INSERT INTO	@tblSourcePUList	(
						SourcePUId			)
			SELECT DISTINCT ude.PU_Id
			FROM	dbo.User_Defined_Events ude WITH (NOLOCK)
				JOIN	@tblSampleList	sl	ON	sl.SampleId = ude.Parent_UDE_ID
			WHERE sl.ConvertingSample = 1

			---------------------------------------------------------------------------------------------------------------
			--	Get the variables for the source machines
			--	The variables will be in default production groups
			--	The production groups will be identified by a UDP on the PU_Groups table
			--	Table = PU_Groups 
			--	Table_Fields = DefaultQProdGrps of type numeric
			--	Table_Field_Values has a record for each PUG_Id that should be included in the DefaultQProdGrpss
			--	Business Rule: if DefaultQProdGrps = 1 include variable group in PPM report ELSE do not include
			---------------------------------------------------------------------------------------------------------------
			--	GET table Id for PU_Groups
			---------------------------------------------------------------------------------------------------------------
			SELECT	@intTableId = TableId
			FROM	dbo.Tables	WITH (NOLOCK)	
			WHERE	TableName = 'PU_Groups'

			SELECT	@intTableFieldId = 0
			---------------------------------------------------------------------------------------------------------------
			--	GET table field Id for DefaultQProdGrps
			---------------------------------------------------------------------------------------------------------------	
			SELECT	@intTableFieldId = Table_Field_Id
			FROM	dbo.Table_Fields	WITH (NOLOCK)
			WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps
			---------------------------------------------------------------------------------------------------------------		
			--	GET all the variables that belong to the default PU_Groups
			---------------------------------------------------------------------------------------------------------------	
			INSERT INTO #Var_IDs ( 
									Var_Id,
									PUId,
									PLId,
									EventSubTypeId,
									SourcePUId,
									SourcePUDesc,
									IsConverting	)
			SELECT  				v.Var_id, 
									@intConvertingPUId,
									@intConvertingPLId, 
									v.Event_Subtype_Id,
									pu.PU_Id	,
									pu.PU_Desc	,
									1
			FROM	dbo.Variables_Base			v	WITH (NOLOCK) 
			JOIN	@tblSourcePUList 		tpu		ON tpu.SourcePUId = v.PU_Id
			JOIN	dbo.Prod_Units_Base			pu	WITH (NOLOCK) 
													ON pu.PU_Id = v.PU_Id
			JOIN	dbo.PU_Groups			pg		WITH (NOLOCK)
													ON	pg.PUG_Id = v.PUG_Id
			JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
													ON	tfv.KeyId = pg.PUG_Id
			WHERE	tfv.TableId = @intTableId
				AND	tfv.Table_Field_Id = @intTableFieldId
				AND	tfv.Value = 'Yes'	

			---------------------------------------------------------------------------------------------------------------
			--	GET a List of all the Samples (UDE's) on source machines
			---------------------------------------------------------------------------------------------------------------	

			INSERT INTO	@tblOffLineSampleList 	(
								ConvertingPUId				,
								PUId						,
								SampleId					,
								EndTime						,	
								SourceTime					,						
								SampleDesc					,
								EventSubtypeId				,
								EventNum					)
			SELECT      @intConvertingPUId,
						ude2.PU_Id,
						ude2.UDE_Id,
						ude2.End_Time,
						ude.End_Time,
						ude2.UDE_Desc,
						ude.Event_Subtype_Id,
						e.Event_Num
			FROM	dbo.User_Defined_Events		ude		WITH (NOLOCK)
			JOIN    dbo.User_Defined_Events 	ude2    WITH (NOLOCK)
														ON  ude2.Parent_UDE_Id = ude.UDE_Id
			JOIN	@tblSampleList				sl		ON	sl.SampleId = ude.UDE_Id -- ude.Parent_UDE_ID
			JOIN	@tblListEventSubTypes	est			ON	est.EventSubTypeId = ude.Event_SubType_Id
			LEFT JOIN	dbo.Events				e 		WITH (NOLOCK)
														ON	e.event_id = ude2.event_id
			
			DELETE @tblSampleList
			---------------------------------------------------------------------------------------------------------------
			--	INCREMENT COUNTER
			---------------------------------------------------------------------------------------------------------------
			SET	@i = @i + 1
		END
	END
	-----------------------------------------------------------------------------------------------------------------------	
	--	Update Parent variables 
	-----------------------------------------------------------------------------------------------------------------------	
	UPDATE  #Var_Ids
			SET   PVarId = v.PVar_Id
	FROM    #Var_ids   vids
	JOIN    dbo.Variables_Base v WITH (NOLOCK)	ON    vids.Var_Id  = v.Var_Id

END	-- IF @intUseRptGenealogy = 1

----------------------------------------------------------------------------------------------------------------------------------------	
--	LOGIC To Include/Exclude Variables Starts Here
----------------------------------------------------------------------------------------------------------------------------------------	

----------------------------------------------------------------------------------------------------------------------------------------	
--	ALL the following IsReportable Logic will happen only if the @intApplyIsReportableUDP FLAG is set to TRUE
----------------------------------------------------------------------------------------------------------------------------------------	
IF @intApplyIsReportableUDP = 1
BEGIN
				-------------------------------------------------------------------------------------------------------
				--	GET table Id for Variables
				-------------------------------------------------------------------------------------------------------
				SELECT	@intTableId = TableId
				FROM	dbo.Tables	WITH (NOLOCK)	
				WHERE	TableName = 'Variables'
				
				SELECT	@intTableFieldId = 0
				-------------------------------------------------------------------------------------------------------
				--	GET table field Id for Reportable UDP
				-------------------------------------------------------------------------------------------------------
				SELECT	@intTableFieldId = Table_Field_Id
				FROM	dbo.Table_Fields	WITH (NOLOCK)
				WHERE	Table_Field_Desc = @vchUDPDescReportable
				-------------------------------------------------------------------------------------------------------
				--	a. Rpt			:	Identifies which variables should be included in the report
				--						Options	1 = YES; 0 = NO
				--						If value is 0 variable is eliMINated from the report
				--						NOTE1:	SPC presents a special case, P&G has set the SPC children to not report, 
				--								because they want to report on the average instead of the raw data.
				--								The report has been designed to work with raw data so to avoid the 
				--								elimination of the children we will look at the reportability of the 
				--								parent. If the parent is reportable	we include the children, else we 
				--								don't.
				--						NOTE2:	RptSPCParent = 1 will override NOTE1 later in the code 
				-------------------------------------------------------------------------------------------------------
				--	GET the value of Rpt
				-------------------------------------------------------------------------------------------------------
				UPDATE	vids
				SET	IsReportable = CASE	WHEN	Value = 'No'	THEN	0
										ELSE	1	
										END
				FROM	#Var_Ids	vids
					JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
															ON	tfv.KeyId = vids.Var_Id
				WHERE	tfv.TableId = @intTableId
					AND	tfv.Table_Field_Id = @intTableFieldId
					AND vids.PVarId IS NULL
				
				-------------------------------------------------------------------------------------------------------
				--	If the parent is not reportable then set the children to be non-reportable as well
				-------------------------------------------------------------------------------------------------------
				UPDATE	vids2
				SET	IsReportable = vids2.IsReportable
				FROM	#Var_Ids	vids1
					JOIN	#Var_Ids	vids2	WITH (NOLOCK)
													ON	vids1.Var_Id = vids2.PVarId
				WHERE	vids1.PVarId IS NULL
				
				SELECT	@intTableFieldId = 0
				-------------------------------------------------------------------------------------------------------
				--	GET table field Id for RptSPCParent
				-------------------------------------------------------------------------------------------------------
				SELECT	@intTableFieldId = Table_Field_Id
				FROM	dbo.Table_Fields	WITH (NOLOCK)
				WHERE	Table_Field_Desc = @vchUDPDescSPCParent
				
				
				UPDATE	vids
				SET		RptSPCParent    =   CASE	WHEN	Value = 'No'	THEN	0
													ELSE	1	
													END		
				FROM 	#Var_Ids		vids
				JOIN	dbo.Table_Fields_Values	tfv			WITH (NOLOCK)
															ON	tfv.KeyId = vids.Var_Id
				WHERE	tfv.TableId = @intTableId
					AND	tfv.Table_Field_Id = @intTableFieldId
				
				
				-------------------------------------------------------------------------------------------------------
				--	IF	RptSPCParent <> 1 make IsReportable = 0 for SPCParent
				-------------------------------------------------------------------------------------------------------
				UPDATE	vids
					SET	IsReportable = 0
				FROM	#Var_Ids vids
				WHERE	RptSPCParent = 0
					AND	Var_Id IN (	SELECT	DISTINCT 
				 							PVarId
				 					FROM	#Var_Ids)
				
				-------------------------------------------------------------------------------------------------------
				--	IF	RptSPCParent = 1 make IsReportable = 0 for SPCChildren
				-------------------------------------------------------------------------------------------------------
				UPDATE	vids2
				SET	IsReportable = 0
				FROM	#Var_Ids	vids1
					JOIN	#Var_Ids	vids2	WITH (NOLOCK)
													ON	vids1.Var_Id = vids2.PVarId
				WHERE	vids1.PVarId IS NULL
					AND	vids1.RptSPCParent = 1
				
								
END

----------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------
-- After getting all Variables update the all columns information
----------------------------------------------------------------------------------------------------------------------------------------
UPDATE #Var_IDs 
		  SET 		PUId			= CASE WHEN PUId IS NULL THEN v.PU_Id ELSE tv.PUId END	,
					PLID 			= pu.PL_ID			,
					Data_Type_id 	= V.Data_Type_id	, 
                    Var_Desc 		= V.Var_Desc		, 
					PUG_Id 			= V.Pug_Id			,
					VarDataTypeId   = v.Data_Type_Id 
FROM dbo.Variables_Base 	v 		WITH(NOLOCK)
JOIN dbo.Prod_Units_Base 	pu		WITH(NOLOCK)
									ON pu.PU_Id		=	v.PU_Id
JOIN #Var_IDs tv 					ON tv.var_id 	= 	v.var_id


-- testing 
-- delete from #Var_IDs where var_id not in (47252, 47305, 47306, 47307, 47308, 47309, 47310)

DELETE FROM #PLIDList
	WHERE PL_ID NOT IN (SELECT DISTINCT PLID FROM #Var_Ids)

----------------------------------------------------------------------------------------------------------------------------------------
-- Update the Production Line Description
----------------------------------------------------------------------------------------------------------------------------------------
				
UPDATE #PLIDList
	SET PL_Desc = PL.PL_Desc
FROM #PLIDList PLid
JOIN dbo.Prod_Lines_Base PL  WITH(NOLOCK) ON PL.PL_Id = PLid.PL_id

----------------------------------------------------------------------------------------------------------------------------------------
--                                 Main Processing                                     								   --
----------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------
-- Now that all the Product search steps are completed, update the Prod_Desc  
-- If the Prod_Group_List temp table is not empty then get rid of all the Prod_Ids that not belong to
-- that Product Groups
----------------------------------------------------------------------------------------------------------------------------------------

UPDATE #Prod_IDs 
            Set Prod_Desc = P.Prod_Desc + '(' + P.prod_code + ')' 
	FROM dbo.Products_Base P WITH(NOLOCK)
	JOIN #Prod_IDs TP ON TP.Prod_Id = P.Prod_ID
----------------------------------------------------------------------------------------------------------------------------------------
-- 								   Create AND Populate the Base Table
----------------------------------------------------------------------------------------------------------------------------------------
INSERT INTO #Production_Starts (PU_Id,
			Start_Time,
			END_Time,
			Prod_Id )
SELECT 		pu.Pu_id,
			Start_Time,
			END_Time,
			ps.Prod_Id 
FROM dbo.Prod_Units_Base pu				WITH(NOLOCK)
	JOIN dbo.Production_Starts 	ps 		WITH(NOLOCK)
										ON PS.PU_ID = PU.PU_id
	JOIN #Prod_IDs 				tpi 	ON ps.Prod_ID = tpi.Prod_id  
WHERE           ps.Start_Time <= @in_EndTime
			    AND (	ps.End_Time > @in_StartTime 
						OR ps.End_Time IS NULL		)		
ORDER BY pu.Pu_id,Start_Time


INSERT INTO #Production_Starts (PU_Id,
			Start_Time,
			END_Time,
			Prod_Id )
SELECT 		ps.Pu_id,
			Start_Time,
			END_Time,
			ps.Prod_Id 
FROM dbo.Production_Starts 	ps 		WITH(NOLOCK)
JOIN (	SELECT DISTINCT SourcePUId FROM #Var_IDs
		WHERE SourcePUId IS NOT NULL	) AS pu
		ON pu.SourcePUId = ps.PU_Id		
WHERE           ps.Start_Time <= @in_EndTime
			    AND (	ps.End_Time > @in_StartTime 
						OR ps.End_Time IS NULL		)		
ORDER BY pu.SourcePUId,Start_Time
----------------------------------------------------------------------------------------------------------------------------------------
-- Get all tests for Converting Unit
----------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO #All_Variables 
		(			Var_ID, 
					Var_Desc, 
					PL_ID,
					PL_Desc,
					Pu_Id,
					Pug_Desc,  
					Result_On,  
					Entry_on, 
					SourceTime,
					Entry_by,
					Result, 
					Include_Result, 
					Include_Crew, 
					Include_ShIFt, 
					Include_LineStatus,
					Prod_Id,
					Prod_Desc,
					Comment_Id,
					CommentDesc,
					SummaryRow,
					Defect		,
					Order_None,
					NonNumericFlag )
		
		SELECT 	
					vids.Var_id,
					vids.Var_Desc,
					vids.PLId,
					pl.PL_Desc,
					vids.PUId,
					pug.Pug_Desc,
					t.Result_On,
					t.Entry_On,
					t.Result_On,
					u.UserName,
					CONVERT(VARCHAR,T.Result),
			        'No ',
				    'Yes',
				    'Yes',
				    'Yes', 
					'',--Tpi.Prod_id,
					'',--Tpi.Prod_Desc,
					t.Comment_Id,
					CONVERT(NVARCHAR(1000),Comment_Text),
					'No',
					0	,
					Var_Desc,
					--	Flag for Non-Numeric variables
					CASE	WHEN	VarDataTypeId	=	1	THEN	0
							WHEN	VarDataTypeId	=	2	THEN	0
							WHEN	VarDataTypeId	=	6	THEN	0
							WHEN	VarDataTypeId	=	7	THEN	0
							ELSE	1
							END
FROM dbo.Tests 			t 				WITH(NOLOCK)
JOIN #Var_IDS 			vids 			ON vids.var_id = t.var_id
JOIN #PLIDList 			pl				ON vids.PLID = pl.PL_Id
JOIN dbo.PU_Groups 		pug 			WITH(NOLOCK)	
										ON vids.pug_id = pug.pug_id
JOIN dbo.Users_Base 			u 		WITH(NOLOCK)	
										ON t.Entry_by = u.user_id 
LEFT JOIN dbo.Comments 	c				WITH(NOLOCK)
										ON	c.Comment_Id = t.Comment_Id   
WHERE	T.Result_ON >= pl.in_StartTime 
		AND T.Result_on < pl.in_ENDTime 
		AND vids.IsConverting = 0
		AND T.Result IS not NULL 
		AND T.Result <> '' 
		AND vids.IsReportable = 1
		AND t.Canceled = 0

----------------------------------------------------------------------------------------------------------------------------------------
-- Get all tests for Source Unit
----------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO #All_Variables 
		(			Var_ID, 
					Var_Desc, 
					PL_ID,
					PL_Desc,
					Pu_Id,
					SourcePU_Id,
					Pug_Desc,  
					Result_On,  
					Entry_on,
					SourceTime,
					Entry_by,
					Result, 
					Include_Result, 
					Include_Crew, 
					Include_ShIFt, 
					Include_LineStatus,
					Prod_Id,
					Prod_Desc,
					Event_Num,
					Comment_Id,
					CommentDesc,
					SummaryRow,
					Defect		,
					Order_None,
					NonNumericFlag )

		SELECT  	
					vids.Var_id,
					vids.Var_Desc,
					vids.PLId,
					pl.PL_Desc + ' (' + vids.SourcePUDesc + ')',
					vids.PUId,
					vids.SourcePUId,
					pug.Pug_Desc,
					t.Result_On,
					t.Entry_On,
					tsl.SourceTime,
					u.UserName,
					CONVERT(VARCHAR,T.Result),		
			        'No ',
				    'Yes',
				    'Yes',
				    'Yes', 
					'',--Tpi.Prod_id,
					'',--Tpi.Prod_Desc,
					ISNULL(tsl.EventNum,'') + ' (' + LEFT(tsl.SampleDesc,10) + ')',
					t.Comment_Id,
					CONVERT(NVARCHAR(1000),Comment_Text),
					'No',
					0	,
					vids.Var_Desc,
					--	Flag for Non-Numeric variables
					CASE	WHEN	VarDataTypeId	=	1	THEN	0
							WHEN	VarDataTypeId	=	2	THEN	0
							WHEN	VarDataTypeId	=	6	THEN	0
							WHEN	VarDataTypeId	=	7	THEN	0
							ELSE	1
							END
FROM dbo.Tests 			t 				WITH(NOLOCK)
JOIN #Var_IDS 			vids 			ON vids.var_id = t.var_id
JOIN dbo.Variables_Base 		v		WITH(NOLOCK)
										ON v.var_id = vids.var_id
JOIN @tblOffLineSampleList 	tsl 		ON 	tsl.EndTime = t.Result_On
										AND tsl.EventSubtypeId = vids.EventSubtypeId
										AND v.PU_Id = tsl.PUId	
										AND vids.PUId = tsl.ConvertingPUId
JOIN dbo.Prod_Units_Base 	pu			WITH(NOLOCK)
										ON vids.PUID = pu.PU_Id
JOIN dbo.Prod_Lines_Base 	pl			WITH(NOLOCK)
										ON pu.PL_ID = pl.PL_Id
JOIN dbo.PU_Groups 		pug 	 		WITH(NOLOCK)	
										ON vids.pug_id = pug.pug_id
JOIN dbo.Users_Base 			u 		WITH(NOLOCK)	
										ON t.Entry_by = u.user_id 
LEFT JOIN dbo.Comments 	c		 		WITH(NOLOCK)
										ON	c.Comment_Id = t.Comment_Id   
WHERE	T.Result IS NOT NULL 
		AND T.Result <> '' 
		AND vids.IsReportable = 1
		AND vids.IsConverting = 1
		AND t.Canceled = 0

----------------------------------------------------------------------------------------------------------------------------------------
--	Update Order of Output for Variables Childs
----------------------------------------------------------------------------------------------------------------------------------------
UPDATE av
	SET Order_None = va.var_desc
	FROM #All_Variables av
	JOIN #Var_IDS 		v	ON av.var_id = v.var_id 
	JOIN dbo.variables_Base	va WITH (NOLOCK)	ON v.pvarid  = va.var_id
WHERE v.pvarid IS NOT NULL

----------------------------------------------------------------------------------------------------------------------------------------
--	Update Product information
----------------------------------------------------------------------------------------------------------------------------------------
-- Product Information from Converter
UPDATE #All_Variables
	SET Prod_Id			=	Tpi.Prod_Id,
		Prod_Desc		=	Tpi.Prod_Desc
FROM #All_Variables av
JOIN #Production_Starts ps     		   ON PS.Start_Time <= av.Result_On
   									   AND (PS.END_Time > av.Result_On OR PS.END_Time IS NULL) 
									   AND PS.PU_ID = av.PU_Id
JOIN #Prod_IDs tpi ON ps.Prod_ID = tpi.Prod_id   
WHERE av.SourcePU_Id IS NULL

-- Product Information from Converter for Paper Machine variables
UPDATE #All_Variables
	SET Prod_Id			=	Tpi.Prod_Id,
		Prod_Desc		=	Tpi.Prod_Desc
FROM #All_Variables av
JOIN #Production_Starts ps     		   ON PS.Start_Time <= av.SourceTime
   									   AND (PS.END_Time > av.SourceTime OR PS.END_Time IS NULL) 
									   AND PS.PU_ID = av.PU_Id
JOIN #Prod_IDs tpi ON ps.Prod_ID = tpi.Prod_id   
WHERE av.SourcePU_Id IS NOT NULL

-- Update Product Information for Paper Machines
UPDATE #All_Variables
	SET SourceProd_Id	=	ps.Prod_id
FROM #All_Variables av
JOIN #Production_Starts ps     		   ON PS.Start_Time <= av.Result_On
   									   AND (PS.END_Time > av.Result_On OR PS.END_Time IS NULL) 
									   AND PS.PU_ID = av.SourcePU_Id
WHERE av.SourcePU_Id IS NOT NULL

----------------------------------------------------------------------------------------------------------------------------------------
--	Delete Variables without products
----------------------------------------------------------------------------------------------------------------------------------------
DELETE FROM #All_Variables
	WHERE (	Prod_Id IS NULL 
			OR ( 	Prod_Id = 0
					AND SourceProd_id IS NULL)
			OR ( 	SourcePU_Id IS NOT NULL
					AND SourceProd_id IS NULL)
			)

----------------------------------------------------------------------------------------------------------------------------------------
--	Update Shift, Team and Line Status
----------------------------------------------------------------------------------------------------------------------------------------

INSERT INTO #Crew_Schedule (Start_Time,END_Time,Pu_id,Crew_Desc,ShIFt_Desc)
SELECT Start_Time,END_Time,Pu_id,Crew_Desc,ShIFt_Desc
FROM dbo.Crew_Schedule cs WITH(NOLOCK)
WHERE      CS.END_TIME <= @in_EndTime
		   AND (CS.END_TIME >= @in_StartTime or CS.END_TIME IS NULL)
           AND cs.pu_id IN (SELECT Distinct PUId FROM #Var_ids)

--INSERT INTO #Local_PG_Line_Status (Start_DATETIME,END_DATETIME,Unit_id,LineStatus)
--SELECT Start_DATETIME,END_DATETIME,Unit_id,PhrASe_Value AS LineStatus
--FROM dbo.Local_PG_Line_Status LPG WITH(NOLOCK)
--Left JOIN dbo.PhrASe phr  WITH(NOLOCK) ON lpg.Line_Status_ID = phr.PhrASe_ID
--WHERE   lpg.Unit_ID IN (SELECT Distinct PUId FROM #Var_ids)
--	AND lpg.Start_DATETIME <= @in_EndTime
--	AND (lpg.END_DATETIME >= @in_StartTime  or lpg.END_DATETIME IS NULL)

INSERT INTO #NPT_Status (Start_DATETIME,END_DATETIME,Unit_id,LineStatus)
SELECT Start_TIME,END_TIME,pu_id,event_reason_name AS LineStatus
FROM dbo.nonproductive_detail npd WITH(NOLOCK)
Left JOIN dbo.event_reasons er  WITH(NOLOCK) ON npd.reason_level1 = er.event_reason_id
WHERE   npd.pu_ID IN (SELECT Distinct PUId FROM #Var_ids)
	AND npd.Start_TIME <= @in_EndTime
	AND (npd.END_TIME >= @in_StartTime  or npd.END_TIME IS NULL)



--UPDATE #All_Variables
--       	SET Crew = cs.Crew_Desc,
--		    Shift = cs.ShIFt_Desc,
--		    LineStatus = lpg.LineStatus
--FROM #All_Variables av
--JOIN #Var_ids tv ON av.var_id = tv.var_id
--Left JOIN #Crew_Schedule cs ON tv.PUId = cs.pu_id 
--           AND CS.Start_TIME < av.Result_ON
--	   AND (CS.END_TIME > av.Result_ON or CS.END_TIME IS NULL)
--Left JOIN #Local_PG_Line_Status LPG ON tv.PUId = lpg.Unit_ID
--		AND av.Result_ON >= lpg.Start_DATETIME 
--		AND (av.Result_ON < lpg.END_DATETIME or lpg.END_DATETIME IS NULL)


UPDATE #All_Variables
       	SET Crew = cs.Crew_Desc,
		    Shift = cs.ShIFt_Desc,
		    LineStatus = npd.LineStatus
FROM #All_Variables av
JOIN #Var_ids tv ON av.var_id = tv.var_id
Left JOIN #Crew_Schedule cs ON tv.PUId = cs.pu_id 
           AND CS.Start_TIME < av.Result_ON
	   AND (CS.END_TIME > av.Result_ON or CS.END_TIME IS NULL)
Left JOIN #NPT_Status npd ON tv.PUId = npd.Unit_id
		AND av.Result_ON >= npd.Start_DATETIME 
		AND (av.Result_ON < npd.END_DATETIME or npd.END_DATETIME IS NULL)

UPDATE #All_Variables
SET LineStatus = 'PR In: Line Normal'
WHERE linestatus is NULL

----------------------------------------------------------------------------------------------------------------------------------------
-- If the Product Group Parameter IS Not Empty then fill it with data
-- If Product belongs to more than one Product Group then get the Top 1
----------------------------------------------------------------------------------------------------------------------------------------

UPDATE #All_Variables
            Set Prod_Group = PG.Product_Grp_Desc
	FROM #All_Variables av
    JOIN dbo.Product_Group_Data PGD  WITH(NOLOCK) ON PGD.Prod_id = Av.prod_id
    JOIN dbo.Product_Groups PG 		 WITH(NOLOCK) On PG.Product_Grp_Id = PGD.Product_Grp_Id
    JOIN #Product_Group_Data PGD2 	On PGD2.Product_Grp_Id = PGD.Product_Grp_Id

----------------------------------------------------------------------------------------------------------------------------------------
-- IF the Product Group Parameter IS Not Empty then get rid of all variables wich product does not belong to the 
-- Filtered Product Group other case fill it with the TOP 1
----------------------------------------------------------------------------------------------------------------------------------------
IF EXISTS(SELECT * FROM #Product_Group_Data)
BEGIN

	DELETE FROM #All_Variables
	WHERE Prod_Id NOT IN (
			SELECT Prod_Id FROM  dbo.Product_Group_Data PGD  WITH(NOLOCK)		
    		JOIN #Product_Group_Data PGD2 	ON PGD2.Product_Grp_Id = PGD.Product_Grp_Id)
	AND SourceProd_Id NOT IN (
			SELECT Prod_Id FROM  dbo.Product_Group_Data PGD  WITH(NOLOCK)		
    		JOIN #Product_Group_Data PGD2 	ON PGD2.Product_Grp_Id = PGD.Product_Grp_Id)

END
ELSE
BEGIN
-- IF not then get any product group
	UPDATE #All_Variables
            Set Prod_Group = (SELECT TOP 1 Product_Grp_Desc 
							  FROM dbo.Product_Group_Data PGD	WITH(NOLOCK)
    						  JOIN dbo.Product_Groups PG		WITH(NOLOCK) ON PG.Product_Grp_Id = PGD.Product_Grp_Id 
							  WHERE Prod_id = AV.Prod_Id
							  ORDER BY Product_Grp_Desc )
	FROM #All_Variables av
    WHERE Prod_Group IS NULL
END

----------------------------------------------------------------------------------------------------------------------------------------
-- Get Variable Specification
----------------------------------------------------------------------------------------------------------------------------------------
-- 20090506 New bussiness rules for Specs :
--

UPDATE #All_Variables
    SET L_Reject  = vs.L_Reject ,
		L_Warning = vs.L_Warning,
		L_User    = vs.L_User ,
		Target    = vs.Target ,
		U_User    = vs.U_User,
		U_Warning = vs.U_Warning,
		U_Reject  = vs.U_Reject ,
		L_Control = vs.L_Control,
		U_Control = vs.U_Control
FROM #All_Variables Av
JOIN #Var_Ids tv ON Av.Var_id = tv.var_id
JOIN dbo.Var_Specs VS  WITH(NOLOCK) ON VS.Var_ID = Av.Var_ID AND VS.Prod_Id = Av.Prod_id
	AND VS.Effective_Date < Av.Result_ON
	AND (VS.Expiration_Date > Av.Result_ON 
			OR VS.Expiration_Date IS NULL) 
WHERE Av.SourcePU_Id IS NULL

UPDATE #All_Variables
    SET L_Reject  = vs.L_Reject ,
		L_Warning = vs.L_Warning,
		L_User    = vs.L_User ,
		Target    = vs.Target ,
		U_User    = vs.U_User,
		U_Warning = vs.U_Warning,
		U_Reject  = vs.U_Reject ,
		L_Control = vs.L_Control,
		U_Control = vs.U_Control
FROM #All_Variables Av
JOIN #Var_Ids tv ON Av.Var_id = tv.var_id
JOIN dbo.Var_Specs VS  WITH(NOLOCK) ON VS.Var_ID = Av.Var_ID AND VS.Prod_Id = Av.SourceProd_id
	AND VS.Effective_Date < Av.Result_ON
	AND (VS.Expiration_Date > Av.Result_ON 
			OR VS.Expiration_Date IS NULL) 
WHERE Av.SourcePU_Id IS NOT NULL


----------------------------------------------------------------------------------------------------------------------------------------
--	Check for TAMU Site Logic
----------------------------------------------------------------------------------------------------------------------------------------
UPDATE	av
		SET IsTAMUVariable = 1
FROM	#All_Variables av 		
WHERE   (L_Reject IS NOT NULL
		 OR U_Reject IS NOT NULL)
AND		NonNumericFlag = 1

----------------------------------------------------------------------------------------------------------------------------------------
-- Update PROCESS ORDER Information
----------------------------------------------------------------------------------------------------------------------------------------
UPDATE #All_Variables
		SET PO = (CASE WHEN po.PO IS NULL THEN '<No PO>' ELSE po.PO END)
FROM #All_Variables av
		LEFT JOIN #POs			po	ON av.PU_Id	=	po.PU_Id
WHERE   av.Result_On >= po.Fore_Start_Date 
		AND Result_On < po.Fore_End_Date 

----------------------------------------------------------------------------------------------------------------------------------------
-- Determine IF this Test Result should be INcluded bASed ON the Team Criteria
----------------------------------------------------------------------------------------------------------------------------------------
IF (@in_CrewDesc <> 'ALL')
   BEGIN
	   UPDATE #All_Variables			
           SET INclude_Crew = 'No'
           WHERE CHARINDEX(','+crew+',', ','+@in_CrewDesc+',') = 0
   END

----------------------------------------------------------------------------------------------------------------------------------------
-- Determine IF this Test Result should be INcluded bASed ON the ShIFt Criteria
----------------------------------------------------------------------------------------------------------------------------------------
IF (@in_ShIFtDesc <> 'ALL')
    BEGIN
	UPDATE #All_Variables			
        SET INclude_Crew = 'No'
        WHERE CHARINDEX(','+ShIFt+',', ','+@in_ShIFtDesc+',') = 0
    END

----------------------------------------------------------------------------------------------------------------------------------------
-- Determine IF this Test Result should be INcluded bASed ON the Line Status Criteria
----------------------------------------------------------------------------------------------------------------------------------------
IF (@in_LineStatus <> 'ALL')
    BEGIN
        UPDATE #All_Variables
	SET INclude_Linestatus = 'No'
        WHERE CHARINDEX(','+LineStatus+',', ','+@in_LineStatus+',') = 0
    END

----------------------------------------------------------------------------------------------------------------------------------------
-- UPDATE the 'Include_Results' field bASed ON the prior three criteria
----------------------------------------------------------------------------------------------------------------------------------------
UPDATE #All_Variables
		SET 	INclude_Result = 	'Yes'
	WHERE INclude_Crew = 	'Yes' 
			AND INclude_shIFt = 	'Yes'
			AND INclude_linestatus ='Yes'


----------------------------------------------------------------------------------------------------------------------------------------
-- Set the upper limit to .9 for any attributes
----------------------------------------------------------------------------------------------------------------------------------------

UPDATE #All_Variables
	SET 	Result = 1
WHERE Result IS NULL

----------------------------------------------------------------------------------------------------------------------------------------
-- Convert data back to float (numeric) format for NUMERIC Variables
----------------------------------------------------------------------------------------------------------------------------------------

UPDATE #All_Variables
	SET 	Result 		= 	Convert(float, result),
			L_reject 	= 	Convert(float, l_reject),
			l_warning 	= 	Convert(float, l_warning),
			l_user 		= 	Convert(float, l_user),
			L_Control 	= 	CONVERT(FLOAT,L_Control),
			target 		= 	Convert(float, target),
			U_Control 	= 	CONVERT(FLOAT,U_Control),
			u_user 		= 	Convert(float, u_user),
			u_warning 	= 	Convert(float, u_warning),
			u_reject 	= 	Convert(float, u_reject)
	WHERE   NonNumericFlag = 0
			AND ISNumeric(l_reject) = 1
			AND ISNumeric(l_warning) = 1
			AND ISNumeric(l_user) = 1
			AND ISNumeric(target) = 1
			AND ISNumeric(u_user) = 1
			AND ISNumeric(u_warning) = 1
			AND ISNumeric(u_reject) = 1
			AND ISNumeric(U_Control) = 1
			AND ISNumeric(L_Control) = 1

----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- IF 'Details' REPORT THEN :
-- @int_RptGroupBy = 0 - Product Group
-- @int_RptGroupBy = 1 - None
-- @int_RptGroupBy = 2 - Process Order
-- @int_RptGroupBy = 3 - Line
-- IF 'Charting' REPORT THEN :
-- @int_RptGroupBy = 0 - Product Group
-- @int_RptGroupBy = 1 - None
----------------------------------------------------------------------------------------------------------------------------------------

IF @int_RptGroupBy = 0 
BEGIN
		UPDATE #All_Variables 
			SET TestCount = avProd.TestCount
		FROM #All_Variables av
		JOIN (SELECT Var_Id, Prod_Id, COUNT(*) AS TestCount
				FROM #All_Variables
				GROUP BY Var_Id, Prod_Id) AS avProd ON av.Var_Id = avProd.Var_Id AND av.Prod_Id = avProd.Prod_Id
END

IF @int_RptGroupBy = 2
BEGIN
		UPDATE #All_Variables 
			SET TestCount = avPO.TestCount
		FROM #All_Variables av
		JOIN (SELECT Var_Id, PO, COUNT(*) AS TestCount
				FROM #All_Variables
				GROUP BY Var_Id, PO) AS avPO ON av.Var_Id = avPO.Var_Id AND av.PO = avPO.PO

END

IF @int_RptGroupBy = 1
BEGIN
		UPDATE #All_Variables 
			SET TestCount = (SELECT Count(*)
							 FROM #All_Variables
							 WHERE Var_id = av.Var_Id)
		FROM #All_Variables av
END

IF @int_RptGroupBy = 3
BEGIN
		UPDATE #All_Variables 
			SET TestCount = 1
		FROM #All_Variables av
END

----------------------------------------------------------------------------------------------------------------------------------------
-- CALCULATE DEFECTS 
-- IF @greater_equal	 = 1 then limit analysis is >
-- ELSE limit analysis is >=
----------------------------------------------------------------------------------------------------------------------------------------
-- Calculate DEFECT for NUMERIC Variables
IF @greater_equal <> 1 -- then use <=
BEGIN

			UPDATE #All_Variables 
				SET Defect = (CASE WHEN CONVERT(FLOAT,Result) <= CONVERT(FLOAT,L_Reject) THEN 1 ELSE 0 END)			
			WHERE NonNumericFlag = 0
				  AND L_Reject IS NOT NULL	  

			UPDATE #All_Variables 
				SET Defect = (CASE WHEN CONVERT(FLOAT,Result) >= CONVERT(FLOAT,U_Reject) THEN 1 ELSE 0 END)
			WHERE NonNumericFlag = 0
				  AND U_Reject IS NOT NULL
				  AND Defect = 0
				  
END
ELSE
BEGIN
			UPDATE #All_Variables 
				SET Defect = (CASE WHEN CONVERT(FLOAT,Result) < CONVERT(FLOAT,L_Reject) THEN 1 ELSE 0 END)			
			WHERE NonNumericFlag = 0
				  AND L_Reject IS NOT NULL
				  

			UPDATE #All_Variables 
				SET Defect = (CASE WHEN CONVERT(FLOAT,Result) > CONVERT(FLOAT,U_Reject) THEN 1 ELSE 0 END)
			WHERE NonNumericFlag = 0
				  AND U_Reject IS NOT NULL
				  AND Defect = 0

END

-- Calculate DEFECT for NONNUMERIC Variables and NON TAMU

UPDATE #All_Variables 
		SET Defect = 1
WHERE NonNumericFlag = 1
	  AND Target <> Result
	  AND IsTAMUVariable = 0

-- Calculate DEFECT for NONNUMERIC Variables and TAMU

UPDATE #All_Variables 
		SET Defect = 1
WHERE NonNumericFlag = 1
	  AND (Result = L_Reject
		   OR Result = U_Reject)
	  AND IsTAMUVariable = 1

----------------------------------------------------------------------------------------------------------------------------------------
IF @ShowOOSOnly = 'TRUE'
BEGIN

			DELETE FROM #All_Variables
			WHERE (L_Reject IS NULL AND U_Reject IS NULL) 

			DELETE FROM #All_Variables
			WHERE defect = 0

END

----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------------
--	SUMMARY SECTION FOR EACH VARIABLE
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
-- IF 'Details' REPORT THEN :
-- @int_RptGroupBy = 0 - Product Group
-- @int_RptGroupBy = 1 - None
-- @int_RptGroupBy = 2 - Process Order
-- @int_RptGroupBy = 3 - Line
-- IF 'Charting' REPORT THEN :
-- @int_RptGroupBy = 0 - Product Group
-- @int_RptGroupBy = 1 - None
----------------------------------------------------------------------------------------------------------------------------------------

IF @int_RptGroupBy <> 1 AND @ReportType = 'Details'
BEGIN
		IF @int_RptGroupBy = 0
		BEGIN

					-- Insert Row Text AVG, MIN, MAX, etc.
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
--									L_Control	,	-- Holds the MAX
									L_User		,	-- Holds the Range
									Target		,	-- Holds the Defect
									U_Warning	,	-- Holds the StDev
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow  ,
									Order_None  ,
									Temp_Var_Desc
									)	
					SELECT 			--a.Var_Id,
									NULL, 	
									NULL,
									NULL,
									'',
									Prod_Group  ,
									DATEADD(mm,1,GETDATE()),
									'Average',
									'Min',
									'Max',
									'Range',
									'Defects',
									'StDev',
									'Yes',
									'Yes',
									Order_None,
									a.Var_Desc
					FROM #All_Variables a
					JOIN #Var_Ids v		ON a.var_desc = v.var_desc
					WHERE v.pVarId IS NULL
					AND Include_Result = 'Yes'
					GROUP BY a.Var_Desc,Prod_Group,Order_None

					-- Summary for Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,	-- Holds the StDev
--									L_Control	,	-- Holds the MAX
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc
									)	
					SELECT 			--a.Var_Id,
									NULL, 	
									NULL,
									NULL,
									'Variable Summary',
									Prod_Group  ,
									DATEADD(mm,2,GETDATE()),
									AVG(CONVERT(FLOAT,Result)),
									MIN(CONVERT(FLOAT,Result)),
									MAX(CONVERT(FLOAT,Result)),
									STDEV(CONVERT(FLOAT,Result)),
									'Yes'	,
									'Yes'	,
									Order_None,
									A.Var_Desc	
					FROM #All_Variables a
					JOIN #Var_Ids v		ON a.var_desc = v.var_desc
					WHERE SummaryRow = 'No' AND NonNumericFlag = 0 
						AND v.pVarId IS NULL
						AND Include_Result = 'Yes'
						AND ISNUMERIC(Result) = 1
					GROUP BY A.Var_Desc,Prod_Group,Order_None,NonNumericFlag

					-- Summary for Non Numeric Variables
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			--a.Var_Id,
									NULL, 	
									NULL,
									NULL,
									'Variable Summary',
									Prod_Group  ,
									DATEADD(mm,2,GETDATE()),
									'-',
									'-',
									'-',
									'-',
									'Yes'	,
									'Yes'	,
									Order_None,
									a.Var_Desc		
					FROM #All_Variables  a
					JOIN #Var_Ids v		ON a.var_desc = v.var_desc
					WHERE SummaryRow = 'No' AND NonNumericFlag = 1
						AND v.pVarId IS NULL
						AND Include_Result = 'Yes'
					GROUP BY a.Var_Desc,Prod_Group,Order_None,NonNumericFlag

					-- Insert Row Text AVG, MIN, MAX, etc.
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
--									L_Control	,	-- Holds the MAX
									L_User		,	-- Holds the Range
									Target		,	-- Holds the Defect
									U_Warning	,	-- Holds the StDev
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow ,
									Order_None ,
									Temp_Var_Desc)	
					SELECT 			--MAX(a.Var_Id),
									NULL, 	
									NULL,
									NULL,
									'',
									Prod_Group  ,
									DATEADD(mm,1,GETDATE()),
									'Average',
									'Min',
									'Max',
									'Range',
									'Defects',
									'StDev',
									'Yes',
									'Yes',
									Order_None,
									a.var_desc
					FROM	#All_Variables	a
					JOIN	#Var_Ids v		ON a.var_desc = v.var_desc
					JOIN	dbo.variables_Base	va WITH (NOLOCK)	ON v.pVarId = va.var_id 
					WHERE	v.pVarId IS NOT NULL
					GROUP BY -- v.pVarId, 
							a.var_desc,a.Prod_Group, a.Order_None

					-- Summary for Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,	-- Holds the StDev
--									L_Control	,	-- Holds the MAX
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			--MAX(a.Var_Id),
									NULL, 	
									NULL,
									NULL,
									'Variable Summary',
									Prod_Group  ,
									DATEADD(mm,2,GETDATE()),
									AVG(CONVERT(FLOAT,Result)),
									MIN(CONVERT(FLOAT,Result)),
									MAX(CONVERT(FLOAT,Result)),
									STDEV(CONVERT(FLOAT,Result)),
									'Yes'	,
									'Yes'	,
									Order_None,
									a.var_desc	
					FROM #All_Variables a
					JOIN #Var_Ids v		ON a.var_desc = v.var_desc
					WHERE SummaryRow = 'No' AND NonNumericFlag = 0 
						AND v.pVarId IS NOT NULL
						AND Include_Result = 'Yes'
						AND ISNUMERIC(Result) = 1
					GROUP BY a.var_desc, v.pVarId, Prod_Group, Order_None, NonNumericFlag

					-- Summary for Non Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,
									Include_Result,
									SummaryRow	,
									Order_None  , 
									Temp_Var_Desc)	
					SELECT 			--MAX(a.Var_Id),
									NULL, 	
									NULL,
									NULL,
									'Variable Summary',
									Prod_Group  ,
									DATEADD(mm,2,GETDATE()),
									'-',
									'-',
									'-',
									'-',
									'Yes'	,
									'Yes'	,
									Order_None,
									a.var_desc			
					FROM #All_Variables  a
					JOIN #Var_Ids v		ON a.var_desc = v.var_desc 
					WHERE SummaryRow = 'No' AND NonNumericFlag = 1
						AND v.pVarId IS NOT NULL
						AND Include_Result = 'Yes'
					GROUP BY a.var_desc, v.pVarId, Prod_Group, Order_None, NonNumericFlag

			END
			IF @int_RptGroupBy = 3
			BEGIN
					
					-- Insert Row Text AVG, MIN, MAX, etc.
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
--									L_Control	,	-- Holds the MAX
									L_User		,	-- Holds the Range
									Target		,	-- Holds the Defect
									U_Warning	,	-- Holds the StDev
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow ,
									Order_None ,
									Temp_Var_Desc)	
					SELECT 			--a.Var_Id,
									PL_Id, 	
									NULL,
									PL_Desc,
									'',
									NULL  ,
									DATEADD(mm,1,GETDATE()),
									'Average',
									'Min',
									'Max',
									'Range',
									'Defects',
									'StDev',
									'Yes',
									'Yes',
									Order_None,
									a.Var_Desc
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.Var_Desc = v.Var_Desc
					WHERE v.pVarId IS NULL
						AND Include_Result = 'Yes'
					GROUP BY a.Var_Desc,PL_Id,PL_Desc,Order_None
					
					-- Summary for Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,	-- Holds the StDev
--									L_Control	,	-- Holds the MAX
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			--a.Var_Id,
									PL_Id, 	
									NULL,
									PL_Desc,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									AVG(CONVERT(FLOAT,Result)),
									MIN(CONVERT(FLOAT,Result)),
									MAX(CONVERT(FLOAT,Result)),
									STDEV(CONVERT(FLOAT,Result)),
									'Yes'	,
									'Yes'	,
									Order_None,
									a.Var_Desc			
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.Var_Desc = v.Var_Desc
					WHERE v.pVarId IS NULL
						AND SummaryRow = 'No' AND NonNumericFlag = 0
						AND Include_Result = 'Yes'
						AND ISNUMERIC(Result) = 1
					GROUP BY a.Var_Desc,a.Var_Id,PL_Id,PL_Desc,Order_None
			
					--	Summary for Non Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			DISTINCT 
									--a.Var_Id,
									PL_Id, 	
									NULL,
									PL_Desc,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									'-',
									'-',
									'-',
									'-',
									'Yes'	,
									'Yes'	,
									Order_None,
									a.Var_Desc			
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.Var_Desc = v.Var_Desc
					WHERE v.pVarId IS NULL
						AND SummaryRow = 'No' AND NonNumericFlag = 1
						AND Include_Result = 'Yes'
					GROUP BY a.Var_Desc,a.Var_Id,PL_Id,PL_Desc,Order_None

					-- Insert Row Text AVG, MIN, MAX, etc.
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
--									L_Control	,	-- Holds the MAX
									L_User		,	-- Holds the Range
									Target		,	-- Holds the Defect
									U_Warning	,	-- Holds the StDev
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow ,
									Order_None ,
									Temp_Var_Desc)	
					SELECT 			--Max(a.var_id),
									a.PL_Id, 	
									NULL,
									a.PL_Desc,
									'',
									NULL  ,
									DATEADD(mm,1,GETDATE()),
									'Average',
									'Min',
									'Max',
									'Range',
									'Defects',
									'StDev',
									'Yes',
									'Yes',
									a.Order_None,
									a.Var_Desc
					FROM	#All_Variables a
					JOIN	#Var_Ids		v	ON a.Var_Desc = v.Var_Desc
					WHERE v.pVarId IS NOT NULL
						AND Include_Result = 'Yes'
					GROUP BY a.Var_Desc, v.pVarId, a.PL_Id, a.PL_Desc, a.Order_None

					-- Summary for Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,	-- Holds the StDev
--									L_Control	,	-- Holds the MAX
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow	,
									Order_None,
									Temp_Var_Desc)	
					SELECT 			--Max(a.var_id), 
									a.PL_Id, 	
									NULL,
									a.PL_Desc,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									AVG(CONVERT(FLOAT,Result)),
									MIN(CONVERT(FLOAT,Result)),
									MAX(CONVERT(FLOAT,Result)),
									STDEV(CONVERT(FLOAT,Result)),
									'Yes'	,
									'Yes'	,
									a.Order_None,
									a.Var_Desc			
					FROM	#All_Variables a
					JOIN	#Var_Ids		v	ON a.Var_Desc = v.Var_Desc
					WHERE v.pVarId IS NOT NULL
						AND SummaryRow = 'No' AND NonNumericFlag = 0
						AND Include_Result = 'Yes'
						AND ISNUMERIC(Result) = 1
					GROUP BY a.Var_Desc, v.pVarId, a.PL_Id, a.PL_Desc, a.Order_None
			
					-- Summary for Non Numeric Variables 
					INSERT INTO #All_Variables
									(--Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			--Max(a.var_id),
									a.PL_Id, 	
									NULL,
									a.PL_Desc,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									'-',
									'-',
									'-',
									'-',
									'Yes'	,
									'Yes'	,
									a.Order_None,
									a.Var_Desc
					FROM #All_Variables a
					JOIN	#Var_Ids		v	ON a.Var_Desc = v.Var_Desc
					WHERE v.pVarId IS NOT NULL
						AND SummaryRow = 'No' AND NonNumericFlag = 1
						AND Include_Result = 'Yes'
					GROUP BY a.Var_Desc, v.pVarId, a.PL_Id, a.PL_Desc, a.Order_None


			END

			IF @int_RptGroupBy = 2
			BEGIN

					-- Insert Row Text AVG, MIN, MAX, etc.
					INSERT INTO #All_Variables
									(Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
--									L_Control	,	-- Holds the MAX
									L_User		,	-- Holds the Range
									Target		,	-- Holds the Defect
									U_Warning	,	-- Holds the StDev
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow ,
									Order_None ,
									Temp_Var_Desc)	
					SELECT 			a.Var_Id,
									NULL, 	
									a.PO,
									NULL,
									'',
									NULL  ,
									DATEADD(mm,1,GETDATE()),
									'Average',
									'Min',
									'Max',
									'Range',
									'Defects',
									'StDev'	,
									'Yes',
									'Yes',
									a.Order_None,
									a.Var_Desc
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.var_id = v.var_id 
					WHERE v.pVarId IS NULL
					GROUP BY a.Var_Desc, a.Var_Id, a.PO, a.Order_None

					-- Summary for Numeric Variables 
					INSERT INTO #All_Variables
									(Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,	-- Holds the StDev
--									L_Control	,	-- Holds the MAX
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			a.Var_Id,
									NULL, 	
									a.PO, -- PO
									NULL,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									AVG(CONVERT(FLOAT,Result)),
									MIN(CONVERT(FLOAT,Result)),
									MAX(CONVERT(FLOAT,Result)),
									STDEV(CONVERT(FLOAT,Result)),
									'Yes'	,
									'Yes'	,
									a.Order_None,
									a.Var_Desc			
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.var_id = v.var_id 
					WHERE SummaryRow = 'No' 
					AND NonNumericFlag = 0
					AND	v.pVarId IS NULL
					AND ISNUMERIC(Result) = 1
					GROUP BY a.Var_Desc, a.Var_Id, a.PO, a.Order_None

					-- Summary for Non Numeric Variables
					INSERT INTO #All_Variables
									(Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			a.Var_Id,
									NULL, 	
									a.PO, -- PO
									NULL,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									'-',
									'-',
									'-',
									'-',
									'Yes'	,
									'Yes'	,
									a.Order_None,
									a.Var_Desc			
					FROM #All_Variables	a  
					JOIN #Var_Ids		v	ON a.var_id = v.var_id 
					WHERE SummaryRow = 'No' AND NonNumericFlag = 1
					AND	v.pVarId IS NULL
					GROUP BY a.Var_Desc, a.Var_Id, a.PO, a.Order_None

					-- Insert Row Text AVG, MIN, MAX, etc.
					INSERT INTO #All_Variables
									(Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
--									L_Control	,	-- Holds the MAX
									L_User		,	-- Holds the Range
									Target		,	-- Holds the Defect
									U_Warning	,	-- Holds the StDev
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow ,
									Order_None ,
									Temp_Var_Desc)	
					SELECT 			Max(a.var_id),
									NULL, 	
									a.PO,
									NULL,
									'',
									NULL  ,
									DATEADD(mm,1,GETDATE()),
									'Average',
									'Min',
									'Max',
									'Range',
									'Defects',
									'StDev'	,
									'Yes',
									'Yes',
									a.Order_None,
									a.Var_Desc
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.var_id = v.var_id 
					WHERE v.pVarId IS NOT NULL
					GROUP BY a.Var_Desc, v.pVarId, a.PO, a.Order_None

					-- Summary for Numeric Variables 
					INSERT INTO #All_Variables
									(Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,	-- Holds the StDev
--									L_Control	,	-- Holds the MAX
--									U_Control	,	-- Holds the StDev
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			Max(a.var_id),
									NULL, 	
									a.PO, -- PO
									NULL,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									AVG(CONVERT(FLOAT,Result)),
									MIN(CONVERT(FLOAT,Result)),
									MAX(CONVERT(FLOAT,Result)),
									STDEV(CONVERT(FLOAT,Result)),
									'Yes'	,
									'Yes'	,
									a.Order_None,
									a.Var_Desc			
					FROM #All_Variables a
					JOIN #Var_Ids		v	ON a.var_id = v.var_id 
					WHERE SummaryRow = 'No' 
					AND NonNumericFlag = 0
					AND	v.pVarId IS NOT NULL
					AND ISNUMERIC(Result) = 1
					GROUP BY a.Var_Desc, v.pVarId, a.PO, a.Order_None

					-- Summary for Non Numeric Variables
					INSERT INTO #All_Variables
									(Var_id		,
									PL_Id		,
									PO,
									PL_Desc		,
									Var_Desc	,
									Prod_Group  ,
									Result_On	,
									Result		,	-- Holds the AVG
									L_Reject	,	-- Holds the MIN
									L_Warning	,	-- Holds the MAX
									U_Warning	,
									Include_Result,
									SummaryRow	,
									Order_None  ,
									Temp_Var_Desc)	
					SELECT 			Max(a.var_id),
									NULL, 	
									a.PO, -- PO
									NULL,
									'Variable Summary',
									NULL  ,
									DATEADD(mm,2,GETDATE()),
									'-',
									'-',
									'-',
									'-',
									'Yes'	,
									'Yes'	,
									a.Order_None,
									a.Var_Desc			
					FROM #All_Variables	a  
					JOIN #Var_Ids		v	ON a.var_id = v.var_id 
					WHERE SummaryRow = 'No' AND NonNumericFlag = 1
					AND	v.pVarId IS NULL
					GROUP BY a.Var_Desc, v.pVarId, a.PO, a.Order_None

			END
END

IF @int_RptGroupBy = 1 AND @ReportType = 'Details'
BEGIN					
					
		-- Insert Row Text AVG, MIN, MAX, etc.
		INSERT INTO #All_Variables
					(Var_id		,
					PL_Id		,
					PL_Desc		,
					Var_Desc	,
					Result_On	,
					Result		,	-- Holds the AVG
					L_Reject	,	-- Holds the MIN
					L_Warning	,	-- Holds the MAX
--					L_Control	,	-- Holds the MAX
					L_User		,	-- Holds the Range
					Target		,	-- Holds the Defect
					U_Warning	,	-- Holds the StDev
--					U_Control	,	-- Holds the StDev
					Include_Result,
					SummaryRow ,
					Order_None ,
					Temp_Var_Desc)	
		SELECT 		0,
					'', 	
					'',
					'',
					DATEADD(mm,1,GETDATE()),
					'Average',
					'Min',
					'Max',
					'Range',
					'Defects',
					'StDev',
					'Yes',
					'Yes',
					Order_None,
					a.Var_Desc
			FROM #All_Variables a
			JOIN #Var_Ids		v	ON a.var_id = v.var_id 
			WHERE v.pVarId IS NULL
				AND Include_Result = 'Yes'
			GROUP BY a.Var_Desc,Order_None
					
		-- Summary for Numeric Variables
		INSERT INTO #All_Variables
					(Var_id		,
					PL_Id		,
					PL_Desc		,
					Var_Desc	,
					Result_On	,
					Result		,	-- Holds the AVG
					L_Reject	,	-- Holds the MIN
					L_Warning	,	-- Holds the MAX
					U_Warning	,	-- Holds the StDev
--					L_Control	,	-- Holds the MAX
--					U_Control	,	-- Holds the StDev
					Include_Result,
					SummaryRow	,
					Order_None  ,
					Temp_Var_Desc)	
		SELECT 		0,
					'', 	
					'',
					'Variable Summary',
					DATEADD(mm,2,GETDATE()),
					AVG(CONVERT(FLOAT,Result)),
					MIN(CONVERT(FLOAT,Result)),
					MAX(CONVERT(FLOAT,Result)),
					STDEV(CONVERT(FLOAT,Result)),
					'Yes'	,
					'Yes'	,
					A.Order_None,
					a.Var_Desc			
			FROM #All_Variables a
			JOIN #Var_Ids		v	ON a.var_id = v.var_id 
			WHERE a.SummaryRow = 'No' AND a.NonNumericFlag = 0
				AND	v.pVarId IS NULL
				AND Include_Result = 'Yes'
				AND ISNUMERIC(Result) = 1
			GROUP BY a.Var_Desc,A.Order_None

		-- Summary for Non Numeric Variables
		INSERT INTO #All_Variables
					(Var_id		,
					PL_Id		,
					PL_Desc		,
					Var_Desc	,
					Result_On	,
					Result		,	-- Holds the AVG
					L_Reject	,	-- Holds the MIN
					L_Warning	,	-- Holds the MAX
					U_Warning	,
					Include_Result,
					SummaryRow	,
					Order_None  ,
					Temp_Var_Desc)	
		SELECT 		0,
					'', 	
					'',
					'Variable Summary',
					DATEADD(mm,2,GETDATE()),
					'-',
					'-',
					'-',
					'-',
					'Yes'	,
					'Yes'	,
					a.Order_None,
					a.Var_Desc			
			FROM #All_Variables a
			JOIN #Var_Ids		v	ON a.var_id = v.var_id 
			WHERE a.SummaryRow = 'No' AND a.NonNumericFlag = 1
				AND	v.pVarId IS NULL
				AND Include_Result = 'Yes'
			GROUP BY a.Var_Desc,A.Order_None

		-- Insert Row Text AVG, MIN, MAX, etc.
		INSERT INTO #All_Variables
					(Var_id		,
					PL_Id		,
					PL_Desc		,
					Var_Desc	,
					Result_On	,
					Result		,	-- Holds the AVG
					L_Reject	,	-- Holds the MIN
					L_Warning	,	-- Holds the MAX
--					L_Control	,	-- Holds the MAX
					L_User		,	-- Holds the Range
					Target		,	-- Holds the Defect
					U_Warning	,	-- Holds the StDev
--					U_Control	,	-- Holds the StDev
					Include_Result,
					SummaryRow ,
					Order_None ,
					Temp_Var_Desc)	
		SELECT 		0,
					'', 	
					'',
					'',
					DATEADD(mm,1,GETDATE()),
					'Average',
					'Min',
					'Max',
					'Range',
					'Defects',
					'StDev',
					'Yes',
					'Yes',
					a.Order_None,
					a.Var_Desc
			FROM #All_Variables a
			JOIN #Var_Ids		v	ON a.var_id = v.var_id 
			WHERE v.pVarId IS NOT NULL
				AND Include_Result = 'Yes'
			GROUP BY a.Var_Desc,a.Order_None
					
		-- Summary for Numeric Variables
		INSERT INTO #All_Variables
					(Var_id		,
					PL_Id		,
					PL_Desc		,
					Var_Desc	,
					Result_On	,
					Result		,	-- Holds the AVG
					L_Reject	,	-- Holds the MIN
					L_Warning	,	-- Holds the MAX
					U_Warning	,	-- Holds the StDev
--					L_Control	,	-- Holds the MAX
--					U_Control	,	-- Holds the StDev
					Include_Result,
					SummaryRow	,
					Order_None  ,
					Temp_Var_Desc)	
		SELECT 		0,
					'', 	
					'',
					'Variable Summary',
					DATEADD(mm,2,GETDATE()),
					AVG(CONVERT(FLOAT,Result)),
					MIN(CONVERT(FLOAT,Result)),
					MAX(CONVERT(FLOAT,Result)),
					STDEV(CONVERT(FLOAT,Result)),
					'Yes'	,
					'Yes'	,
					A.Order_None,
					a.Var_Desc			
			FROM #All_Variables a
			JOIN #Var_Ids		v	ON a.var_id = v.var_id 
			WHERE a.SummaryRow = 'No' 
				AND a.NonNumericFlag = 0
				AND	v.pVarId IS NOT NULL
				AND Include_Result = 'Yes'
				AND ISNUMERIC(Result) = 1
			GROUP BY a.Var_Desc,A.Order_None

		-- Summary for Non Numeric Variables
		INSERT INTO #All_Variables
					(Var_id		,
					PL_Id		,
					PL_Desc		,
					Var_Desc	,
					Result_On	,
					Result		,	-- Holds the AVG
					L_Reject	,	-- Holds the MIN
					L_Warning	,	-- Holds the MAX
					U_Warning	,
					Include_Result,
					SummaryRow	,
					Order_None	,
					Temp_Var_Desc)	
		SELECT 		0,
					'', 	
					'',
					'Variable Summary',
					DATEADD(mm,2,GETDATE()),
					'-',
					'-',
					'-',
					'-',
					'Yes'	,
					'Yes'	,
					a.Order_None,
					a.Var_Desc
			FROM #All_Variables a
			JOIN #Var_Ids		v	ON a.var_id = v.var_id 
			WHERE a.SummaryRow = 'No' AND a.NonNumericFlag = 1
				AND	v.pVarId IS NOT NULL
				AND Include_Result = 'Yes'
			GROUP BY -- v.pVarId, 
				a.Var_Desc,A.Order_None

END


UPDATE #ALL_Variables
		SET L_User = CONVERT(FLOAT,L_Warning) - CONVERT(FLOAT,L_Reject)
WHERE SummaryRow = 'Yes' AND Var_Desc = 'Variable Summary'  AND NonNumericFlag = 0

----------------------------------------------------------------------------------------------------------------------------------------
-- Get the SUM of Defects according different grouping Options :
-- IF 'Details' REPORT THEN :
-- @int_RptGroupBy = 0 - Product Group
-- @int_RptGroupBy = 1 - None
-- @int_RptGroupBy = 2 - Process Order
-- @int_RptGroupBy = 3 - Line
----------------------------------------------------------------------------------------------------------------------------------------
-- 3) Line 
IF @int_RptGroupBy = 3 AND @ReportType = 'Details'
BEGIN
		UPDATE #ALL_Variables
				SET Target = (SELECT SUM(Defect) FROM #ALL_VAriables 
							   WHERE Order_None = AV.Order_None
								AND PL_Id = av.PL_Id
								AND SummaryRow = 'No'
								AND Include_Result = 'Yes')
		FROM #ALL_Variables AV
		WHERE SummaryRow = 'Yes' AND Var_Desc = 'Variable Summary'
END
-- 2) Process Order 
IF @int_RptGroupBy = 2 AND @ReportType = 'Details'
BEGIN
		UPDATE #ALL_Variables
				SET Target = (SELECT SUM(Defect) FROM #ALL_VAriables 
							  WHERE  Order_None = AV.Order_None
								AND PO = av.PO
								AND SummaryRow = 'No'
								AND Include_Result = 'Yes')
		FROM #ALL_Variables AV
		WHERE SummaryRow = 'Yes' AND Var_Desc = 'Variable Summary'
END

-- 1) None 
IF (@int_RptGroupBy = 1) AND @ReportType = 'Details'
BEGIN
		UPDATE #ALL_Variables
				SET Target = (SELECT SUM(Defect) FROM #ALL_VAriables 
							  WHERE Order_None = AV.Order_None
								AND SummaryRow = 'No' 
								AND Include_Result = 'Yes')
		FROM #ALL_Variables AV
		WHERE SummaryRow = 'Yes' AND Var_Desc = 'Variable Summary'
END
-- 0) Product Group 
IF (@int_RptGroupBy = 0) AND @ReportType = 'Details'
BEGIN
		UPDATE #ALL_Variables
				SET Target = (SELECT SUM(Defect) FROM #ALL_VAriables 
							  WHERE Order_None = AV.Order_None
							  AND Prod_Group = av.Prod_Group
							  AND SummaryRow = 'No') -- AND NonNumericFlag = 0)
		FROM #ALL_Variables AV
		WHERE SummaryRow = 'Yes' AND Var_Desc = 'Variable Summary'
END


----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------



IF @ReportType = 'Details'
BEGIN

		UPDATE #All_Variables
				SET Result = '-',
					L_Reject = '-',
					L_Warning = '-'
		FROM #All_Variables av
		JOIN #Var_Ids       vids	ON av.Order_None = vids.Var_Desc
		WHERE NonNumericFlag = 1
			  AND SummaryRow = 'Yes' AND av.Var_Desc = 'Variable Summary'
	
END

UPDATE #All_Variables
	Set Var_Desc = ''
WHERE SummaryRow = 'Yes' AND Var_Desc = 'Variable Summary'


UPDATE #All_Variables				
				SET ProdGrouping = (CASE @int_RptGroupBy 
														WHEN 0 THEN	Prod_Desc 
															   ELSE	Prod_Group
													 END)


----------------------------------------------------------------------------------------------------------------------------------------
-- 							THE OUTPUT RECORDSET										--
----------------------------------------------------------------------------------------------------------------------------------------
-- IF 'Details' REPORT THEN :
-- @int_RptGroupBy = 0 - Product Group
-- @int_RptGroupBy = 1 - None
-- @int_RptGroupBy = 2 - Process Order
-- @int_RptGroupBy = 3 - Line
----------------------------------------------------------------------------------------------------------------------------------------
-- IF Grouped By PO then DELETE all Variables without a valid PO
IF @int_RptGroupBy = 2
BEGIN

	DELETE FROM #All_Variables WHERE PO IS NULL
	 -- PO Header just show it one time :
	INSERT INTO #All_Variables (Var_Id,PL_Desc,Var_Desc,PO,Order_None,Include_Result,Result_On)
	SELECT 0,'Forecast Quantity ',STR(CONVERT(NVARCHAR,Forecast_Quantity),7,2),Process_Order,' a','Yes',NULL
	FROM dbo.Production_Plan WITH(NOLOCK) WHERE Process_Order IN (SELECT DISTINCT PO FROM #All_Variables)
	
	INSERT INTO #All_Variables (Var_Id,PL_Desc,Var_Desc,PO,Order_None,Include_Result,Result_On)
	SELECT 0,'Actual Good Quantity ',STR(CONVERT(NVARCHAR,Actual_Good_Quantity),7,2),Process_Order,' b','Yes',NULL
	FROM dbo.Production_Plan WITH(NOLOCK) WHERE Process_Order IN (SELECT DISTINCT PO FROM #All_Variables)

	INSERT INTO #All_Variables (Var_Id,PL_Desc,Var_Desc,PO,Order_None,Include_Result,Result_On)
	SELECT 0,'Batch Id ',CONVERT(NVARCHAR,Pattern_Code),Process_Order,' c','Yes',NULL
	FROM dbo.Production_Plan pp  WITH(NOLOCK)
	JOIN dbo.Production_Setup ps WITH(NOLOCK)			ON 		ps.pp_id = pp.pp_id 
	WHERE Process_Order IN (SELECT DISTINCT PO FROM #All_Variables)

	INSERT INTO #All_Variables (Var_Id,PL_Desc,Var_Desc,PO,Order_None,Include_Result,Result_On)
	SELECT 0,'Process Order Start Time ',CONVERT(VARCHAR,Actual_Start_Time,101) + ' ' + CONVERT(VARCHAR,Actual_Start_Time,108) ,Process_Order,' d','Yes',NULL
	FROM dbo.Production_Plan WITH(NOLOCK) WHERE Process_Order IN (SELECT DISTINCT PO FROM #All_Variables)

	INSERT INTO #All_Variables (Var_Id,PL_Desc,Var_Desc,PO,Order_None,Include_Result,Result_On)
	SELECT 0,'Process Order End Time ',CONVERT(VARCHAR,Actual_End_Time,101) + ' ' + CONVERT(VARCHAR,Actual_End_Time,108) ,
	Process_Order,' e','Yes',NULL
	FROM dbo.Production_Plan WITH(NOLOCK) WHERE Process_Order IN (SELECT DISTINCT PO FROM #All_Variables)

	INSERT INTO #All_Variables (Var_Id,PL_Desc,Var_Desc,PO,Order_None,Include_Result,Result_On)
	SELECT 0,'Production Status ',ProdStatus_Desc_Local,Process_Order,' f','Yes',NULL
	FROM dbo.Production_Plan pp    WITH(NOLOCK)
	JOIN dbo.Production_Status ps  WITH(NOLOCK)		ON		pp.pp_status_id = ps.ProdStatus_id
	WHERE Process_Order IN (SELECT DISTINCT PO FROM #All_Variables)

END
----------------------------------------------------------------------------------------------------------------------------------------

DECLARE
					@PLId				INT					,
					@PO					NVARCHAR(25)		,
					@ProdGroup			NVARCHAR(200)		,
					@ProdGroupLabel		NVARCHAR(200)		,
					@RECNo				INT					,
					@vRECNo				INT					,
					@LineDesc			NVARCHAR(200)		,
					@BrandCode			NVARCHAR(200)

UPDATE	#All_Variables
SET		Var_Desc	= Temp_Var_Desc
WHERE	Var_Desc	= ''

IF @ReportType = 'Details'
BEGIN		
	-- Check if there is data to show
	IF EXISTS (SELECT * FROM #All_Variables)
	BEGIN
		IF @int_RptGroupBy = 2
		BEGIN
				-- GROUP BY PROCESS ORDER
				INSERT INTO @PO_Sheets (PO)

				SELECT DISTINCT ISNULL(PO,0) FROM #All_Variables

								SELECT 				@PO 		= 	0		,
													@RECNo 		= 	0

								WHILE @RECNo < (SELECT COUNT(*) FROM @PO_Sheets)
								BEGIN
									 SELECT @PO = MIN(PO) FROM @PO_Sheets WHERE PO > @PO 

									 -- Sheet Header
									 SELECT				   (SELECT MIN(Fore_Start_Date) FROM #POs 
															WHERE PO = @PO )							AS		StartDate,
										        		   (SELECT MAX(Fore_End_Date) FROM #POs 
															WHERE PO = @PO )							AS		EndDate,
															@Plant			 							AS		Plant,
															@PLDescList									AS		Line,
															@in_ShiftDesc								AS		Shift,
															@in_CrewDesc								AS		Crew,
															@in_LineStatus								AS		LineStatus,
															'All'										AS		BrandCode,															
															@PO											AS		ProcessOrder,
															0											AS		VarCount	,
															(SELECT COUNT(*) FROM @PO_Sheets)			AS		LineCount	,
															'PO' + CONVERT(VARCHAR,@PO)					AS		SheetName	,
															@vchAppVersion								AS		AppVersion	,
															@vchRTVersion								AS		RTversion 
									
									 
									 -- Sheet Body
									 SELECT 				PL_Desc						,
															Var_Desc					,					-- Variable
															(CASE SummaryRow WHEN 'No' THEN	Result_On		-- REsultOn	
																					  ELSE  NULL
																					  END) AS ResultOn,
															Entry_On					,					-- EntryOn									
															Result						, 					-- Result
															L_Reject					, 					-- LSL
															L_Warning					, 				-- LCL
															-- L_Control					L_Warning,			-- Now it is ok, LCL ( but will keep the old alias for not to modify the template)
															Target						, 
															U_Warning					, 
															-- U_Control					U_Warning,			-- Now it is ok, UCL ( but will keep the old alias for not to modify the template)
															U_reject					,
															Prod_Desc 					,
															Prod_Group					,
															(CASE SummaryRow WHEN 'No' THEN PO ELSE '' END) PO	,
															Entry_By					,
															Event_Num			,
															CommentDesc					Comment_Id					
										FROM #All_Variables
										WHERE Include_Result = 'Yes'
											  AND PO = @PO				
										-- Fix Tkt #IM00688591 
										ORDER BY Order_None, Result_On, Var_Desc

									 SET @RECNo = @RECNo + 1									 
								END
								
		END

		IF @int_RptGroupBy = 0
		BEGIN
			-- Testing
			-- SELECT DISTINCT 'Prod_Group', dbo.fnLocal_ReplaceBadChars(Prod_Group) FROM #All_Variables
			-- GROUP BY PRODUCT GROUP
			INSERT INTO @ProdGroup_Sheet (ProdGroup_Desc)
			SELECT DISTINCT dbo.fnLocal_ReplaceBadChars(Prod_Group) FROM #All_Variables

								SELECT 				@ProdGroup		= 	''		,
													@RECNo 			= 	0		,
													@ProdGroupLabel	= 	''		

								WHILE @RECNo < (SELECT COUNT(*) FROM @ProdGroup_Sheet)
								BEGIN

									  SELECT @ProdGroup = MIN(ProdGroup_Desc) FROM @ProdGroup_Sheet WHERE ProdGroup_Desc > @ProdGroup 
									  SET @ProdGroupLabel	=  (SELECT CASE WHEN CHARINDEX(':',@ProdGroup) > 1 THEN REPLACE(@ProdGroup,':','-')
															    ELSE @ProdGroup END)	
																		
									  -- Sheet Header 
									  SELECT				@in_StartTime 								AS		StartDate,
										        			@in_EndTime 								AS		EndDate,
															@Plant			 							AS		Plant,
															@PLDescList									AS		Line,
															@in_ShiftDesc								AS		Shift,
															@in_CrewDesc								AS		Crew,
															@in_LineStatus								AS		LineStatus,
															@ProdGroup									AS		BrandCode,
															'All'										AS		ProcessOrder,
															0											AS		VarCount	,
															(SELECT COUNT(*) FROM @ProdGroup_Sheet)		AS		LineCount	,
															ISNULL(@ProdGroupLabel,'')					AS		SheetName	,
															@vchAppVersion								AS		AppVersion	,
															@vchRTVersion								AS		RTversion 

									 -- Sheet Body 
									 SELECT 				PL_Desc						,
															Var_Desc					,					-- Variable
															(CASE SummaryRow WHEN 'No' THEN	Result_On		-- REsultOn	
																					   ELSE  ''
																					   END) AS ResultOn,
															Entry_On					,					-- EntryOn									
															Result						, 					-- Result
															L_Reject					, 					-- LSL
															L_Warning					, 				-- LCL
															-- L_Control					L_Warning,			-- Now it is fine : LCL  (but will keep the old alias for not to modify the template)
															Target						, 
															U_Warning					, 
															-- U_Control    				U_Warning,			-- It is ok now : UCL  (but will keep the old alias for not to modify the template)
															U_reject					,
															Prod_Desc 					,
															Prod_Group					,	--(CASE SummaryRow WHEN 'No' THEN Prod_Group ELSE '' END) Prod_Group
															PO							,
															Entry_By					,
															Event_Num			,
															CommentDesc					Comment_Id					
									   FROM #All_Variables
									   WHERE Include_Result = 'Yes'
											AND dbo.fnLocal_ReplaceBadChars(Prod_Group) = @ProdGroup
									   ORDER BY Order_None, Result_On, Var_Desc

   									   SET @RECNo = @RECNo + 1
								
								END

		END

		IF @int_RptGroupBy = 3 
		BEGIN
			-- GROUP BY LINE
					SELECT 				@PLId 		= 	0		,
										@RECNo 		= 	0
						WHILE @RECNo < (SELECT COUNT(*) FROM #PLIDList)
						BEGIN
					
								SELECT @PLid = MIN (PL_ID) FROM #PLIDList WHERE PL_ID > @PLId
								SELECT @LineDesc = PL_Desc FROM #PLIDList WHERE PL_ID = @PLid	
						
								-- Header for the sheet
								SELECT				(SELECT in_StartTime FROM #PLIDList WHERE PL_ID = @PLId) AS	StartDate,
								        			(SELECT in_EndTime FROM #PLIDList WHERE PL_ID = @PLId) AS	EndDate,
													@Plant			 					AS		Plant		,
													@LineDesc							AS		Line		,
													@in_ShiftDesc						AS		Shift		,
													@in_CrewDesc						AS		Crew		,
													@in_LineStatus						AS		LineStatus	,
													(SELECT TOP 1 Prod_Group FROM #All_Variables 
													WHERE PL_ID = @PLId AND Prod_Group IS NOT NULL
																		ORDER BY Prod_Group
																		)				AS		BrandCode	,
													(SELECT TOP 1 PO FROM #All_Variables 
															WHERE PL_ID = @PLId AND PO IS NOT NULL
															ORDER BY PO)   						AS		ProcessOrder,
													0									AS		VarCount	,
													(SELECT COUNT(*) FROM #PLIDList)	AS		LineCount	,
													@LineDesc							AS		SheetName	,
													@vchAppVersion						AS		AppVersion	,
													@vchRTVersion						AS		RTversion 
						
								-- Body for the sheet
								SELECT 				PL_Desc						,
													Var_Desc					,					-- Variable
													(CASE SummaryRow WHEN 'No' THEN	Result_On		-- REsultOn	
																					   ELSE ''
																					   END) AS ResultOn,
													Entry_On					,					-- EntryOn									
													Result						, 					-- Result
													L_Reject					, 					-- LSL
													L_Warning				,	 				-- LCL
													--L_Control					L_Warning,			-- Lowel Control Limit
													Target						, 
													U_Warning				, 
													--U_Control 					U_Warning,			-- Upper Control Limit
													U_reject					,
													Prod_Desc 					,
													Prod_Group					,
													PO							,
													Entry_By					,
													Event_Num			,
													CommentDesc					Comment_Id					
								FROM #All_Variables
								WHERE Include_Result = 'Yes'
									  AND PL_Id = @PLId				
								ORDER BY Order_None, Result_On, Var_Desc
						
							SET @RECNo = @RECNo + 1
						
						END

			END

		IF @int_RptGroupBy = 1
		BEGIN
		-- All Variables in the same sheet.
										
										SELECT				@in_StartTime 								AS		StartDate,
										        			@in_EndTime 								AS		EndDate,
															@Plant			 							AS		Plant,
															@PLDescList									AS		Line,
															@in_ShiftDesc								AS		Shift,
															@in_CrewDesc								AS		Crew,
															@in_LineStatus								AS		LineStatus,
															'All'										AS		BrandCode,
															'All'										AS		ProcessOrder,
															0											AS		VarCount	,
															1											AS		LineCount	,
															''											AS		SheetName	,
															@vchAppVersion								AS		AppVersion	,
															@vchRTVersion								AS		RTversion 

										SELECT 				PL_Desc						, 
															Var_Desc					,					-- Variable
															(CASE SummaryRow WHEN 'No' THEN	Result_On		-- REsultOn	
																					  ELSE  ''
																					  END) AS ResultOn,
															Entry_On					,					-- EntryOn									
															Result						, 					-- Result
															L_Reject					, 					-- LSL
															L_Warning				, 					-- LCL
															--L_Control					L_Warning,			-- Lowe Control Limit
															Target						, 
															U_Warning				, 
															--U_Control					U_Warning,   		-- Upper Control Limit
															U_reject					,
															Prod_Desc 					,
															Prod_Group					,
															PO							,
															Entry_By					,
															Event_Num			,
															CommentDesc					Comment_Id					
										FROM #All_Variables
										WHERE Include_Result = 'Yes'		
										ORDER BY Order_None, Result_On, Var_desc

		END

	END -- IF EXISTS (SELECT * FROM #All_Variables)
	ELSE
	BEGIN

		SELECT				@in_StartTime 								AS		StartDate,
		        			@in_EndTime 								AS		EndDate,
							@Plant			 							AS		Plant,
							@PLDescList									AS		Line,
							@in_ShiftDesc								AS		Shift,
							@in_CrewDesc								AS		Crew,
							@in_LineStatus								AS		LineStatus,
							'All'										AS		BrandCode,
							'All'										AS		ProcessOrder,
							0											AS		VarCount	,
							1											AS		LineCount	,
							''											AS		SheetName	,
							@vchAppVersion								AS		AppVersion	,
							@vchRTVersion								AS		RTversion 

		SELECT 				''				PL_Desc						,
							'NO DATA'		Var_Desc					,					-- Variable
							''			 	ResultOn					,
							''				Entry_On					,					-- EntryOn									
							''				Result						, 					-- Result
							''				L_Reject					, 					-- LSL
							''				L_Warning					, 					-- LCL
							''				Target						, 
							''				U_Warning					, 
							''				U_reject					,
							''				Prod_Desc 					,
							''				Prod_Group					,
							''				PO							,
							''				Entry_By					,
							''				Comment_Id					
	END

END
ELSE
BEGIN
		-- Delete lines without variables
		delete from #PLIDList
			where PL_ID not in (select distinct pl_id FROM #All_Variables )

		SELECT 				@PLId 		= 	0		,
							@RECNo 		= 	0		
		
		WHILE @RECNo < (SELECT COUNT(*) FROM #PLIDList)
		
		BEGIN
				
				SELECT @PLid = MIN (PL_ID) FROM #PLIDList WHERE PL_ID > @PLId
				SELECT @LineDesc = PL_Desc FROM #PLIDList WHERE PL_ID = @PLid	
				
				SELECT				(SELECT in_StartTime FROM #PLIDList WHERE PL_ID = @PLId) AS	StartDate,
				        			(SELECT in_EndTime FROM #PLIDList WHERE PL_ID = @PLId) AS	EndDate,
									@Plant			 		AS		Plant,
									@LineDesc				AS		Line,
									@in_ShiftDesc			AS		Shift,
									@in_CrewDesc			AS		Crew,
									@in_LineStatus			AS		LineStatus,
									@BrandCode				AS 		BrandCode,
									(SELECT COUNT(*) FROM #PLIDList)					AS LineCount,
									(SELECT COUNT(DISTINCT Var_Id) FROM #All_Variables 
										WHERE Var_Desc IS NOT NULL
												AND Prod_Id IS NOT NULL
												AND PL_ID = @PLId
												AND Prod_Id <> 0 
												AND INclude_Result = 'Yes'
												AND SummaryRow = 'No'
												AND Var_Desc NOT LIKE '%zpv_%'
												AND Var_Id IS NOT NULL
												AND Var_Desc NOT LIKE '%Test Complet%'
												AND NonNumericFlag = 0
												AND Prod_Group is not null) AS VarCount,
									(CASE @int_RptGroupBy 
										WHEN 0 THEN	(SELECT COUNT(DISTINCT Prod_Group) FROM #All_Variables
														WHERE Prod_Id IS NOT NULL
															AND PL_ID = @PLId
															AND Prod_Id <> 0 
															AND INclude_Result = 'Yes'
															AND SummaryRow = 'No'
															AND Var_Desc NOT LIKE '%zpv_%'
															AND Var_Id IS NOT NULL
															AND Var_Desc NOT LIKE '%Test Complet%'
															AND NonNumericFlag = 0
															AND Prod_Group is not null) 
											   ELSE	(SELECT COUNT(DISTINCT Prod_Group) FROM #All_Variables
														WHERE Prod_Id IS NOT NULL
															AND PL_ID = @PLId
															AND Prod_Id <> 0 
															AND INclude_Result = 'Yes'
															AND SummaryRow = 'No'
															AND Var_Desc NOT LIKE '%zpv_%'
															AND Var_Id IS NOT NULL
															AND Var_Desc NOT LIKE '%Test Complet%'
															AND NonNumericFlag = 0
															AND Prod_Group is not null) 
									 END) AS ProdCount	,
									@vchAppVersion								AS		AppVersion	,
									@vchRTVersion								AS		RTversion 



--					IF @INT_RptGroupBy = 0 
					BEGIN
						SELECT 			Prod_Group			AS		Prod_Desc		, 
										Max(Result_on) 		as 		MaxResult
						FROM			#All_Variables
						WHERE			Prod_Id IS NOT NULL
										AND PL_ID = @PLId
										AND Prod_Id <> 0 
										AND INclude_Result = 'Yes'
										AND SummaryRow = 'No'
										AND Var_Desc NOT LIKE '%zpv_%'
										AND Var_Id IS NOT NULL
										AND Var_Desc NOT LIKE '%Test Complet%'
										AND NonNumericFlag = 0
										AND Prod_Group is not null
						GROUP BY 	Prod_Group
						ORDER BY 	Prod_Group 

						SELECT 		@vRECNo		=	0								,
									@Var_id		=	0	

						SELECT		Var_Id											,
									Prod_Group										,
									Var_Desc										,									
									CONVERT(DATETIME,Result_On) Result_On			,
									CONVERT(FLOAT,Result)		Result				,
									CONVERT(FLOAT,L_Reject)		L_Reject			,
									CONVERT(FLOAT,L_Control)	L_Warning			,
									CONVERT(FLOAT,L_Warning)	L_User				,
									CONVERT(FLOAT,Target)		Target				,
									CONVERT(FLOAT,U_Warning)	U_User				,
									CONVERT(FLOAT,U_Control)	U_Warning			,
									CONVERT(FLOAT,U_reject)		U_Reject			,
									CONVERT(FLOAT,L_User)		Tgt_Low				,
									CONVERT(FLOAT,U_User)		Tgt_High			,
									CONVERT(FLOAT,(SELECT count(*) FROM #All_Variables av 
													WHERE a.Var_Id = av.Var_Id 
													and a.Prod_Group = av.Prod_Group
													and av.INclude_Result = 'Yes'
									  				AND av.PL_Id = @PLId		
									  				AND av.SummaryRow = 'No'
									 				AND av.Var_Desc NOT LIKE '%zpv_%'
									  				AND av.Var_Id IS NOT NULL
									  				AND av.Var_Desc NOT LIKE '%Test Complet%'
									  				AND av.NonNumericFlag = 0
									  				AND av.Prod_Id <> 0)) 
																TestCount			,
									CONVERT(FLOAT,Defect)		Defect		
						FROM 		#All_Variables a
						WHERE 		INclude_Result = 'Yes'
									AND PL_Id = @PLId		
									AND SummaryRow = 'No'
									AND Var_Desc NOT LIKE '%zpv_%'
									AND Var_Id IS NOT NULL
									AND Var_Desc NOT LIKE '%Test Complet%'
									AND NonNumericFlag = 0
									AND Prod_Group is not null
									AND Prod_Id <> 0
						ORDER BY Var_Id,Prod_Group,Result_On

					END

--					ELSE


		SET @RECNo = @RECNo + 1

		END

END

----------------------------------------------------------------------------------------------------------------------------------------
-- Clean up
----------------------------------------------------------------------------------------------------------------------------------------
DROP TABLE #POs
DROP TABLE #PLIDList
DROP TABLE #Prod_Ids
DROP TABLE #Var_Ids
DROP TABLE #All_Variables
DROP TABLE #Production_Starts
DROP TABLE #Crew_Schedule
DROP TABLE #NPT_Status
DROP TABLE #ListDefaultPUGDesc
DROP TABLE #Product_Group_Data
DROP TABLE #ProdUnitPrdPath
DROP TABLE #Temp_Dates
----------------------------------------------------------------------------------------------------------------------------------------
-- PERMISSIONS / OVERHEAD
----------------------------------------------------------------------------------------------------------------------------------------
ErrorCode:
--
RETURN
GO

SET NOCOUNT OFF
GO


GRANT EXECUTE ON [dbo].[spLocal_RptVariablesDetails]	TO [OPDBManager]

GRANT EXECUTE ON [dbo].[spCmn_ReportCollectionParsing]	TO [OPDBManager]

GRANT EXECUTE ON [dbo].[fnLocal_ReplaceBadChars]		TO [OPDBManager]

GO