
----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptPPMVAS',
		@Inputs		= 24, 
		@Version	= '1.3.4'  

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
----===================================================================================================================== 


----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
			FROM	Information_schema.Routines
			WHERE	Specific_schema = 'dbo'
				AND	Specific_Name = @SP_Name
				AND	Routine_Type = 'PROCEDURE' )
				
DROP PROCEDURE [dbo].[spLocal_RptPPMVAS]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-------------------------------------------------------------------------------------------------------------------------
---- PPM / VAS Report
----
---- 2018-08-17		Martin Casalis						Arido Software
-------------------------------------------------------------------------------------------------------------------------

---- 	----------Based on v6.0-----------
---- 	---Reference for other versions---
---- 	legacy excel FC		=> iODS v1.0.x
---- 	legacy excel v5.2 	=> iODS v1.1.x
---- 	legacy excel v5.4 	=> iODS v1.2.x
---- 	legacy excel v6.0 	=> iODS v1.3.x
----	----------------------------------

-------------------------------------------------------------------------------------------------------------------------
---- EDIT HISTORY: 
-------------------------------------------------------------------------------------------------------------------------
---- ========		====	  		====					=====
---- 1.3			2018-08-17		Martin Casalis			Initial Release
---- 1.3.1			2019-09-25		Facundo sosa			Create Version based on 6.0.
---- 1.3.2			2020-10-06		Santiago Gimenez		Remove reference to Local_PG_LineStatus
---- 1.3.3			2021-08-20		Gonzalo Luc				Fix on filling the gaps with PR In: Line Normal
---- 1.3.4			2021-12-14		Marcos Brito			Performance change when fetching the tests.
		
----=====================================================================================================================

--------------------------------------------------[Creation Of SP]-------------------------------------------------------
CREATE	PROCEDURE	[dbo].[spLocal_RptPPMVAS]
--DECLARE

	@p_vchRptTimeOption					VARCHAR(400)		= NULL			,
	@p_vchRptStartDateTime				VARCHAR(400)		= NULL			,
	@p_vchRptEndDateTime				VARCHAR(400)		= NULL			,
	@p_vchRptLayoutOption				VARCHAR(400)		= NULL			,														
	@p_vchRptPLIdList					VARCHAR(400)    	= NULL			,
	@p_vchRptProdIdList					VARCHAR(400)		= NULL			,
	@p_vchRptProductGrpIdList			VARCHAR(MAX)		= NULL			,
	@p_vchRptPUIdList					VARCHAR(400)		= NULL			,
	@p_vchRptTeamList					VARCHAR(MAX)		= NULL			,
	@p_vchRptShiftList					VARCHAR(MAX)		= NULL			,
	@p_vchRptLineStatusList				VARCHAR(MAX)		= NULL			,
	@p_vchRptMajorGroup					VARCHAR(400)		= NULL			,
	@p_vchRptMinorGroup					VARCHAR(400)		= NULL			,
	@p_vchRptWeightSpecs				BIT									,
	@p_vchRptDataValidation				BIT									,
	@p_vchRptHistorical					BIT									,
	@p_vchRptGenealogy					BIT									,
	@p_vchRptVisibility					BIT									,
	@p_vchRptVarIdList					VARCHAR(MAX)		= NULL			,
	@p_intRptWithDataValidationExtended INT					= 0				,
	@p_vchRptVariableExclusionPrefix	VARCHAR(50)			= 'z_obs'		,
	@p_intRptPercentConfidenceAnalysis	INT					= 0				,
	@p_intRptPercentConfidencePercent	INT					= 95			,
	@p_vchRptCriticality				VARCHAR(50)			= 1	

--WITH ENCRYPTION 
AS


--=====================================================================================================================
-- Testing statements
-----------------------------------------------------------------------------------------------------------------------
 --SELECT	
	--	@p_vchRptTimeOption			=	2,
	--	@p_vchRptStartDateTime		=	null				,  
	--	@p_vchRptEndDateTime  		=	null				,  
	--	@p_vchRptLayoutOption 		=	'NormPPM'					,
	--	@p_vchRptPLIdList			=	'61|60|108|59',--|62',
	--	@p_vchRptProdIdList			=	null,
	--	@p_vchRptProductGrpIdList	=	null,
	--	@p_vchRptPUIdList			=	''	,
	--	@p_vchRptTeamList			=	'',
	--	@p_vchRptShiftList			=	'',
	--	@p_vchRptLineStatusList		=	'28211^PR In:E.O. Shippable|28210^PR In:Produktion|28212^PR In:Qualifikation|28213^PR In:Werk Projekt|28215^PR Out:E.O. Non-Shippable|28216^PR Out:externes Projekt|28214^PR Out:Linie nicht besetz|28217^PR Out:STNU',
	--	@p_vchRptMajorGroup			=	'PLId',
	--	@p_vchRptMinorGroup			=	'ProductGrpId',
	--	@p_vchRptWeightSpecs		=	0,	
	--	@p_vchRptDataValidation		=	0,	
	--	@p_vchRptHistorical			=	1,	
	--	@p_vchRptGenealogy			=	0,	
	--	@p_vchRptVisibility			=	0,
	--	@p_intRptWithDataValidationExtended =	0,
	--	@p_vchRptVariableExclusionPrefix	=	'z_obs',
	--	@p_intRptPercentConfidenceAnalysis	=	0,
	--	@p_intRptPercentConfidencePercent	=	95,
	--	@p_vchRptCriticality				=	1

	----	@p_vchRptTimeOption			= 1,
	----	@p_vchRptStartDateTime		= null,
	----	@p_vchRptEndDateTime		= null,
	----	@p_vchRptLayoutOption		= 'NormPPM',
	----	@p_vchRptPLIdList			= '14',
	----	@p_vchRptProdIdList			= null,
	----	@p_vchRptProductGrpIdList	= null,
	----	@p_vchRptPUIdList			= '106|199|209|107|206|108|109|110|140',
	----	@p_vchRptTeamList			= 'L10 Central|L10 Team A|L10 Team B|L10 Team D|L10 Team X|L10 Team Y|L10 Team Z|L11 Team A|L11 Team D|L11 Team X|L11 Team Z|Offline Team Y|X|Y|Z',
	----	@p_vchRptShiftList			= null,--'1|2|3',
	----	@p_vchRptLineStatusList		= null,
	----	@p_vchRptMajorGroup			= 'PLId',
	----	@p_vchRptMinorGroup			= 'ProductGrpId',
	----	@p_vchRptWeightSpecs		= 0,
	----	@p_vchRptDataValidation		= 0,
	----	@p_vchRptHistorical			= 0,
	----	@p_vchRptGenealogy			= 0,
	----	@p_vchRptVisibility			= 1

	----EXEC dbo.[spLocal_RptPPMVAS]
	----		1,						--@p_vchRptTimeOption			
	----		null,					--@p_vchRptStartDateTime		
	----		null,					--@p_vchRptEndDateTime		
	----		'NormPPM',				--@p_vchRptLayoutOption		
	----		'14',					--@p_vchRptPLIdList			
	----		NULL,					--@p_vchRptProdIdList			
	----		NULL,					--@p_vchRptProductGrpIdList	
	----		'106|199|209|107|206|108|109|110|140',					--@p_vchRptPUIdList			
	----		'L10 Central|L10 Team A|L10 Team B|L10 Team D|L10 Team X|L10 Team Y|L10 Team Z|L11 Team A|L11 Team D|L11 Team X|L11 Team Z|Offline Team Y|X|Y|Z',					--@p_vchRptTeamList			
	----		'1|2|3',					--@p_vchRptShiftList	
	----		'PR In:Qualification',					--@p_vchRptLineStatusList		
	----		'PLId',					--@p_vchRptMajorGroup			
	----		'ProductGrpId',			--@p_vchRptMinorGroup			
	----		0,						--@p_vchRptWeightSpecs		
	----		0,						--@p_vchRptDataValidation		
	----		0,						--@p_vchRptHistorical					
	----		0,						--@p_vchRptGenealogy					
	----		1						--@p_vchRptVisibility		
--=====================================================================================================================			
									
	
--=====================================================================================================================
SET NOCOUNT ON
--=====================================================================================================================
DECLARE	@dtmTempDate		DATETIME	,
		@intSecNumber		INT			,
		@intSubSecNumber	INT			,
		@intPRINTFlag		INT			,
		@ReportName			NVARCHAR(20),
		@p_vchRptName		VARCHAR(400),
		@idx				INT --index to fill npt gaps by Unit 
-----------------------------------------------------------------------------------------------------------------------
-- INITIALIZE Values
-----------------------------------------------------------------------------------------------------------------------
SET		@dtmTempDate 	= GETDATE()
SET		@intPRINTFlag 	= 1				-- Options: 1 = YES; 0 = NO
SET		@intSecNumber	= 1
SET		@ReportName		= 'PPM/VAS Report'
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT 'SP START ' + CONVERT(VARCHAR(50), GETDATE(), 121)
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION: ' + CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PREPARE SP'
--=====================================================================================================================
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' DECLARE Variables and Temp Tables'
--=====================================================================================================================
-----------------------------------------------------------------------------------------------------------------------
-- Report parameters
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@intRptOwnerId							INT,
		@intTimeOption							INT,
		@intRptShiftLength						INT,
		@dtmRptShiftStart						DATETIME,
		@vchRptTitle							VARCHAR(1000),
		@vchRptPLIdList							VARCHAR(7000),
		@vchRptProdIdList						VARCHAR(7000),
		@vchRptProductGrpIdList					VARCHAR(7000),
		@vchRptSortOrderVarIdList				VARCHAR(8000),
		@vchRptCrewDescList						VARCHAR(7000),
		@vchRptShiftDescList					VARCHAR(7000),
		@vchRptPLStatusIdList					VARCHAR(7000),
		@vchRptVariableExclusionPrefix			VARCHAR(50),
		@vchRptProdVarTestName					VARCHAR(50),
	 	@vchRptMajorGroupBy						VARCHAR(50),
	 	@vchRptMinorGroupBy						VARCHAR(50),
		@intRptWithDataValidation				INT,
		@intRptWithDataValidationExtended		INT,
		@intRptWeightSpecChanges				INT,
		@intRptVariableVisibility				INT,
		@intRptPercentConfidenceAnalysis		INT,
		@intRptPercentConfidencePercent			INT,
		@intRptSampleLessThanAdjustment			INT,
		@intRptSampleLessThanMINSampleCOUNTPQM	INT,
		@intRptSampleLessThanMINSampleCOUNTATT	INT,
		@intRptSampleLessThanMINReportingDays	INT,
		@intRptVolumeWeightOption				INT,
		@intRptUseLocalPGLineStatusTable		INT,
		@intRptReportingPeriod					INT,
		@vchRptCriticality						VARCHAR(50),
		@intRptPrecision						INT,
		@intEnableVirtualZero					INT
--Obsolete:
--@vchRptPUSearchStrQuality				VARCHAR(7000),
--@vchRptPUSearchStrProduction			VARCHAR(25),
--@vchRptDefaultPUGDescList				VARCHAR(4000),
--@vchRptMeasurableAttributesPUGDescList	VARCHAR(4000),
-----------------------------------------------------------------------------------------------------------------------
--	OTHER variables
--	Note: @c_.... means it is a cursor variable
-----------------------------------------------------------------------------------------------------------------------
--	INTEGERS
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@i										INT,
		@j										INT,
		@intErrorCode							INT,
		@intMAXRcdIdx							INT,
		@intProdLineId							INT,
		@intPeriodIncompleteFlag				INT,
		@intDataTypeId							INT,
		@intSpecSetting							INT,
		@intTableId								INT,
		@intTableFieldId						INT,
		@intPUId								INT,
		@intBitAND								INT,
		@intDescCOUNT							INT,
		@intMajorGroupId						INT,
		@intMinorGroupId						INT,
		@intPLId								INT,
		@intPUGId								INT,
		@intProductGrpId						INT,
		@intProdId								INT,
		@intCalcPPMId							INT,
		@intRcdCOUNT							INT,
		@intFormulaId							INT,
		@intMAXMajorGroupId						INT,
		@intMAXMinorGroupId						INT,
		@intMAXPPMId							INT,
		@intResultRank							INT,
		@intDegOfFreedom						INT,
		@intTestCount							INT,
		@intMaxInterval							INT,
		@intTimeSliceLookUpRcdIdx				INT,
		@intTimeSliceLookUpCOUNT				INT,
		@intTimeSliceProdId						INT,
		@intQualityPUId							INT,
		@intTestCountCurrent					INT,
		@intIncludePool							INT,
		@intTestCountMissing					INT,
		@intHistTestCountAfterFilter			INT,
		@intHistTestCountBeforeFilter			INT,
		@intHistTestCount						INT,
		@intTestCountHist						INT,
		@intConvertingPUId						INT,	
		@intConvertingPLId						INT,
		@intSheetTypeId		 		 			INT,
		@intSheetId								INT,
		@intEventSubtypeId						INT,
		@intSamplePUId							INT,
		@intIsNumericDataType					INT,
		@intVarId								INT,
		@intIsNonNormal							INT,
		@intTimeSliceId							INT,
		@intSpecTestFreq						INT,
		@intTestFreq							INT,
		@intMAXTimeSliceId						INT,
		@intProductionVarId						INT,
		@intProductionType						INT,
		@intTestCountResultNOTNULL				INT,
		@intTestCountResultNULL					INT,
		@intTestCountTotal						INT,
		@intTestVarId							INT,
		@intIsOfflineQuality					INT,
		@intTimeSlicePUId						INT,
		@intTestFail							INT,
		@intMaxSliceCount						INT,
		@intInitialCalcPPMId					INT,
		@intIsTAMUVariable						INT,
		@intUseRptRunTime						INT,
		@intUseRptGenealogy						INT,		-- Options: 0 = No; 1 = Yes
		-- ACA pgalanzi
		@intMaxGroup							INT,
        -- NPT --
		@intCurIdx								INT,
		@intLastIdx								INT
-----------------------------------------------------------------------------------------------------------------------
--	FLOAT
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@ConstantPI								FLOAT,
		@ConstantE								FLOAT,
		@ConstantP								FLOAT,
		@ConstantB1								FLOAT,
		@ConstantB2								FLOAT,
		@ConstantB3								FLOAT,
		@ConstantB4								FLOAT,
		@ConstantB5								FLOAT,
		@ConstantErrorX							FLOAT,
		@ConstantStDevMultiplier				FLOAT,
		@fltVarR25Rank							FLOAT,
		@fltVarR75Rank							FLOAT,
		@flth									FLOAT,
		@fltResult								FLOAT,
		@fltPreviousValue 						FLOAT,
		@fltNextValue 							FLOAT,
		@fltValue								FLOAT,
		@fltAdjustedh							FLOAT,
		@fltAdjustedh1							FLOAT,		
		@fltAdjustedh2							FLOAT,
		@fltTestAvg								FLOAT,
		@fltTestStDev							FLOAT,
		@fltIntervalEnd1						FLOAT,
		@fltIntervalBegin1						FLOAT,
		@fltIntervalBegin2						FLOAT,
		@fltIntervalEnd2						FLOAT,
		@fltProductionCount						FLOAT,
		@fltTestMin								FLOAT,
		@fltTestMax								FLOAT
-----------------------------------------------------------------------------------------------------------------------
--	VARCHARS
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@vchTimeOption							VARCHAR(50),
		@vchErrorMsg							VARCHAR(1000),
		@vchWarningMsg							VARCHAR(500),
		@vchCompanyName							VARCHAR(50),
	 	@vchSiteName							VARCHAR(50),
	 	@vchRptOwnerDesc						VARCHAR(50),
		@vchPLList								VARCHAR(1000),
		@vchPUList								VARCHAR(1000),
		@vchProductList							VARCHAR(1000),
		@vchProductGroupList					VARCHAR(1000),
		@vchRptPUIdList							VARCHAR(1000),
		@vchPLStatusList						VARCHAR(1000),
		@vchUDPDescLineStatusPUId				VARCHAR(25),
		@vchUDPDescDefaultQProdGrps				VARCHAR(25),
		@vchUDPDescIsNonNormal					VARCHAR(25),
		@vchUDPDescReportable					VARCHAR(25),
		@vchUDPDescTzFlag						VARCHAR(25),
		@vchUDPDescIsAtt						VARCHAR(25),
		@vchUDPDescSPCParent					VARCHAR(25),
		@vchUDPDescCriticality					VARCHAR(25),
		@vchUDPDescIsConvertingLine				VARCHAR(25),
		@vchUDPDescIsOfflineQuality				VARCHAR(25),
		@vchPUDesc								VARCHAR(50),
		@vchMajorGroupDesc						VARCHAR(100),
		@vchVarGroupId							VARCHAR(100),
		@vchUEL									VARCHAR(50),
		@vchUSL									VARCHAR(50),
		@vchUTL									VARCHAR(50),
		@vchTarget								VARCHAR(50),
		@vchLTL									VARCHAR(50),
		@vchLSL									VARCHAR(50),
		@vchLEL									VARCHAR(50),
		@vchTempString							VARCHAR(25),
		@vchIncludeField						VARCHAR(25),
		@vchCr									VARCHAR(600),		
		@vchTz1									VARCHAR(600),
		@vchCpk									VARCHAR(600),
		@vchCalcCpk								VARCHAR(600),
		@vchTz2									VARCHAR(600),
		@vchInfinityFlagCr						VARCHAR(600),
		@vchInfinityFlagTz1						VARCHAR(600),
		@vchInfinityFlagTz2						VARCHAR(600),
		@vchInfinityFlagCpk						VARCHAR(600),
		@vchMCCr								VARCHAR(600),
		@vchMCTz								VARCHAR(600),
		@vchMCCpk								VARCHAR(600),
		@vchFieldListSUMmary					VARCHAR(8000),
		@vchFieldListSUMmaryProd				VARCHAR(8000),
		@vchFieldListDetail						VARCHAR(8000),
		@vchFieldListForTotal					VARCHAR(8000),	
		@vchFieldListForTotalProd				VARCHAR(8000),		
		@vchEventSubTypeDesc					VARCHAR(100) ,	
		@vchSpecVersion							VARCHAR(35)	 ,
		@vchSP_name								VARCHAR(100) ,
		@vchRT_xlt								VARCHAR(100) ,
		@vchAppVersion							VARCHAR(100) ,
		@vchRTVersion							VARCHAR(100) ,
		---------------------------------------------------------------------------------------------------------------
		@ConTimeSliceEliminationReason1			VARCHAR(500),
		@ConTimeSliceEliminationReason2			VARCHAR(500),
		@ConTimeSliceEliminationReason3			VARCHAR(500),
		@ConTimeSliceEliminationReason4			VARCHAR(500),
		@ConTimeSliceEliminationReason5			VARCHAR(500),
		@ConTimeSliceEliminationReason6			VARCHAR(500),
		@ConTimeSliceEliminationReason7			VARCHAR(500),
        -- NPT --
		@vchLineNormalDesc						VARCHAR(20) = 'PR In: Line Normal'

-----------------------------------------------------------------------------------------------------------------------
--	nVARCHARS
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@nvchSQLCommand							nVARCHAR(4000),
		@nvchSQLCommand1 						nVARCHAR(1000),
		@nvchSQLCommand2 						nVARCHAR(1000),
		@nvchSQLCommand3 						nVARCHAR(1000),
		@nvchSQLCommand4 						nVARCHAR(1000),
		@nvchSQLCommand5 						nVARCHAR(1000)
-----------------------------------------------------------------------------------------------------------------------
--	DATETIME
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@dtmNow									DATETIME,
		@dtmMinTimeSliceStart					DATETIME,
		@dtmEndDateTime							DATETIME,
		@dtmMaxSearchDate						DATETIME,
		@dtmTimeSliceStart						DATETIME,
		@dtmTimeSliceEnd						DATETIME,
		-- NPT --
		@dtmNextStartTime						DATETIME,
		@dtmLastEndTime							DATETIME
-----------------------------------------------------------------------------------------------------------------------
--	TABLE VARIABLES
-----------------------------------------------------------------------------------------------------------------------
DECLARE 
		@tblTimeOption		TABLE (
		PLId				INT		,
		StartDate			DATETIME,
		EndDate				DATETIME)
-----------------------------------------------------------------------------------------------------------------------
-- This temporary table will hold variables that have samples only
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblPUIdwithSamples TABLE (
		PUId				INT,
		PLId				INT		)
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Production Lines
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListPLFilter	TABLE (
		RcdIdx				INT	Identity (1, 1),
		PLId				INT			,
		ActivePPath			INT			DEFAULT 0, -- 0 - No Prod Path Active 1 - Prod Path Active
		CountOfPaths		INT			DEFAULT 0, -- Count of Execution Paths configured on one Line
		IsFamilyCareLine	INT			DEFAULT 0, -- If this is a Family Care bussiness then get the production from the Converter Production PU
		PLDesc				VARCHAR(50)	)
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Products
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListProductFilter	TABLE (
		RcdIdx					INT	Identity (1, 1),
		ProductGrpId			INT			,
		ProdId					INT			,
		ProdCode				VARCHAR(50) )
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblTempPadCOUNT		TABLE (
		MajorGroupId			INT			,
		PUGId					INT			,
		VarGroupId				VARCHAR(100),	
		SUMVolumeCount			FLOAT		)
-----------------------------------------------------------------------------------------------------------------------
-- Time slice look-up table for Sample < logic
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblValidTimeSlicesLookUp 	TABLE (
		RcdIdx						INT Identity(1,1),
		CalcPPMId					INT				,
		RunId						INT				,
		VarId						INT				,
		MajorGroupId				INT				,
		MinorGroupId				INT				,
		PLId						INT				,
		QualityPUId					INT				,
		ProdId						INT				,
		ProductGrpId				INT				,
		PLStatusId					INT				,
		TimeSliceStart				DATETIME		,
		TimeSliceEnd				DATETIME		,
		TargetRangeSpecId			INT				,
		CharId						INT				,	
		LEL							VARCHAR(50)		,
		LSL							VARCHAR(50)		,
		LTL							VARCHAR(50)		,	-- Lower Target Limit
		Target						VARCHAR(50)		,
		UTL							VARCHAR(50)		,	-- Upper Target Limit
		USL							VARCHAR(50)		,
		UEL							VARCHAR(50)		,
		SpecVersion					VARCHAR(35)		,
		SpecVersionTR				VARCHAR(35)		)
---------------------------------------------------------------------------------------------------
DECLARE	@tblVASRptVarAttributesFinalRS	TABLE	(
		Border1						INT			,
		MajorGroupId				INT			,
		-- PUGId						INT			,
		PUGDesc						VARCHAR(100),
		VarDesc						VARCHAR(100),
		CalcPPMAoolContribution		FLOAT		,	-- Weighted SUM
		ObsUCIPPMContribution		FLOAT		,
--		DummyCol6					BIT			, -- commented out because of Vz column
--		DummyCol7					BIT			,
		DummyCol8					BIT			,
		DummyCol9					BIT			,
		PassesVirtualZero			FLOAT		, -- PassesVirtualZero
		PercentTarget				FLOAT		, -- PassesVZContribution
		TotalPPM					FLOAT		,
		SampleCOUNT					INT			,
		DefectCOUNT					INT			,
		LSL							FLOAT		,
		DummyCol14					BIT			,
		Target						VARCHAR(100),
		DummyCol16					BIT			,								
		USL							FLOAT		,								
		TestMIN						FLOAT		,								
		TestMAX						FLOAT		,
		TestAvg						FLOAT		,
		TestStDev					FLOAT		,
		DummyCol22					BIT			,
		DummyCol23					BIT			,
		DummyCol24					BIT			,
		DummyCol25					BIT			,
		DummyCol26					BIT			,
		DummyCol27					BIT			,
		SubGroupSize				INT			,
		SpecVersion					VARCHAR(50)	,
		Border2						INT			)
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Product Groups
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblListProductGroupsFilter TABLE (
		RcdIdx						INT	Identity (1, 1),
		ProductGrpId				INT			,
		ProductGrpDesc				VARCHAR(100))

-----------------------------------------------------------------------------------------------------------------------
--	This table will be used to take care of the Minor Volume for Offline Quality variable when multiple Spec Changes 
--	are done for same MajorMinor Grouping
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblOffLineVolume 			TABLE (
				MajorGroupId		INT,
				MinorGroupId		INT,
				PLId				INT,
				VarGroupId			VARCHAR(50),
				ProductGrpId		INT,
				TotalVolumeCount	FLOAT	)

-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Production Units
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblListPUFilter 			TABLE (
		RcdIdx						INT	Identity (1, 1),
		PLId						INT,
		PUId						INT,
		PUDesc						VARCHAR(50),
		ProductionType				INT,
		ProductionVarId				INT,
		IsProductionPoint			INT,	-- Options 1 = yes; 0 = no -- default is 1
		ProductionPointPUId			INT,
		LineStatusPUId				INT,
		IsConvertingLine			INT DEFAULT 0	,
		HoldSamples					INT DEFAULT 0  )   -- 1 = Hold the original samples 0 = No samples
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Crew
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListCrewFilter 			TABLE (
		RcdIdx						INT	Identity (1, 1),
		CrewDesc					VARCHAR(50) )
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Shift
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListShiftFilter 		TABLE (
		RcdIdx						INT	Identity (1, 1),
		ShiftDesc 					VARCHAR(50) )
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Line Status
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListPLStatusFilter 		TABLE (
		RcdIdx						INT	Identity (1, 1),
		PLStatusDesc 				VARCHAR(50)	,
		PLStatusDescSite			VARCHAR(50)	,
		PLStatusId					INT )
-----------------------------------------------------------------------------------------------------------------------
--	Quality PU temp table
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblQualityPUIdTemp 		TABLE (
		RcdIdx						INT	Identity(1,1),
 		QualityPUId					INT)
-----------------------------------------------------------------------------------------------------------------------
--	Major Group temp table
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblPLTemp 					TABLE (
 		MajorGroupId				INT)
-----------------------------------------------------------------------------------------------------------------------
--	Variable and target range temp table
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblVarIdTemp				TABLE (
		RcdIdx						INT	Identity(1,1),
		VarId						INT,
		TargetRangeSpecId			INT,
		CharId						INT)
-----------------------------------------------------------------------------------------------------------------------
--	List of Sample Id's
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblSampleList	TABLE (
		RcdIdx		INT	Identity(1,1),
		SampleId	INT)
-----------------------------------------------------------------------------------------------------------------------
--	List of Source Machines feeding the converting lines 
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblSourcePUList	TABLE (
		RcdIdx		INT	Identity(1,1),
		SourcePUId	INT)

-----------------------------------------------------------------------------------------------------------------------
--	Temporary table to hold results for StDev calculated when weighting by spec change.
-----------------------------------------------------------------------------------------------------------------------
DECLARE @VASTestValues		TABLE(
			CalcPPMId		INT			,
			Result			NVARCHAR(25),
			TestAvg			FLOAT		,
			TestSquaredDev	FLOAT			)
-----------------------------------------------------------------------------------------------------------------------
--	Final result set for VAS
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblVASRptVarStatisticsFinalRS	TABLE	(
		Border1						INT,
		MajorGroupId				INT,
		PUGDesc						VARCHAR(100),
		VarDesc						VARCHAR(100),
		CalcPPMAoolContribution		FLOAT,	-- Weighted SUM
		CalcPPMPoolActual			FLOAT,	-- Will hold the ObsUCIPPMContribution	if VZ Enabled
		CalcPPMPoolContribution		FLOAT,	-- Weighted SUM
		CalcUCIPPM					FLOAT,	-- To hold the UCI PPM if VzEnabled 
		MetCritActual				FLOAT,
		MetCritPPass				FLOAT,	-- PassesVirtualZero
		TotalPPM					FLOAT,  -- PassesVZContribution
		SampleCOUNT					INT,
		DefectCOUNT					INT,
		LSL							FLOAT,
		LTL							FLOAT,
		Target						FLOAT,
		UTL							FLOAT,
		USL							FLOAT,
		TestMIN						FLOAT,								
		TestMAX						FLOAT,								
		TestAvg						FLOAT,								
		TestStDev					FLOAT,
		Tz							FLOAT,
		Cr							FLOAT,
		CpK							FLOAT,
		MetCritTz					FLOAT,
		MetCritCr					FLOAT,
		MetCritCpK					FLOAT,
		SubGroupSize				INT,
		SpecVersion					VARCHAR(50),
		Border2						INT )	
---------------------------------------------------------------------------------------------------
-- Raw data for non-normal distributions i.e. Extended_Info = "Norm = N"
---------------------------------------------------------------------------------------------------
DECLARE	@tblCalcPPMRawDataTemp 	TABLE (	
		RcdId						INT			,
		CalcPPMId					INT			,
		VarGroupId					VARCHAR(100),
		ResultRank					INT			,
		Result						FLOAT		,
		HistTestFlag				INT			,
		ResultTimeStamp				DATETIME	,
		h							FLOAT		,
		Adjustedh					FLOAT		)
---------------------------------------------------------------------------------------------------
--	VAS report SUMmary
---------------------------------------------------------------------------------------------------
DECLARE	@tblVASRptSUMmary	TABLE	(
		RcdOrder					INT Identity (1, 1),
		Border1						INT,
		MajorGroupId				INT,
		DummyCol3					INT,
		PUGDesc						VARCHAR(100),
		CalcPPMAoolContribution		FLOAT,	-- Weighted SUM
		ObsUCIPPMContribution		FLOAT,  -- If the report has the Vz Enabled
		DummyCol6					BIT,			
		CalcPPMPoolContribution		FLOAT,	-- Weighted SUM
		CalcUCIPPMContribution		FLOAT,	-- If the report has the Vz Enabled
		DummyCol8					BIT,	
		MetCritPPass				FLOAT,
		DummyCol12					BIT,
		TotalPPM					FLOAT,
		TotalSampleCOUNT			INT,
		TotalDefectCOUNT			INT,
		DummyCol13					BIT,
		DummyCol14					BIT,
		DummyCol15					BIT,
		DummyCol16					BIT,								
		DummyCol17					BIT,								
		DummyCol18					BIT,								
		DummyCol19					BIT,
		DummyCol20					BIT,
		DummyCol21					BIT,
		DummyCol22					BIT,
		DummyCol23					BIT,
		DummyCol24					BIT,
		DummyCol25					BIT,
		DummyCol26					BIT,
		DummyCol27					BIT,
		DummyCol28					BIT,
		DummyCol29					BIT,
		Border2						INT)
---------------------------------------------------------------------------------------------------
-- Temporary table that holds the test avg for CalcPPMId's that have historical values
---------------------------------------------------------------------------------------------------
DECLARE	@tblTestAvgTemp	TABLE	(
		CalcPPMId					INT,
		TestAvg						FLOAT)	
---------------------------------------------------------------------------------------------------
--	Historical data 
---------------------------------------------------------------------------------------------------
DECLARE	@tblHistDataStats TABLE (
		CalcPPMId					INT		,
		TestAvg						FLOAT	,
		TestStDev					FLOAT	,
		TestFail					INT		,
		TestCountHist				INT		,		-- Historical test COUNT when TestCountReal < sample < criteria
		TestMin						FLOAT	,
		TestMax						FLOAT	,
		TestSUMSquaredDev			FLOAT	)
---------------------------------------------------------------------------------------------------
--	List of timeslices that have offline quality data
---------------------------------------------------------------------------------------------------
DECLARE	@tblOfflineQualityTimeSliceList TABLE(
		RcdIdx			INT	IDENTITY (1, 1),
		TimeSliceId		INT			,
		TimeSliceStart	DATETIME	,
		TimeSliceEnd	DATETIME	,
		SamplePUId		INT			,
		VarId			INT			)
---------------------------------------------------------------------------------------------------
--	VAS Report SUMmary Final Result Set
---------------------------------------------------------------------------------------------------
DECLARE	@tblVASRptSUMmaryFinalRS	TABLE	(
		Border1						INT,
		MajorGroupId				INT,
		DummyCol3					INT,
		PUGDesc						VARCHAR(100),
		CalcPPMAoolContribution		FLOAT,	-- Weighted SUM
		ObsUCIPPMContribution		FLOAT,
		-- DummyCol6					BIT, Commented out because of VzM enhancement	
		CalcPPMPoolContribution		FLOAT,	-- Weighted SUM
		CalcUCIPPMContribution		FLOAT,
		DummyCol8					BIT, -- Commented out because of VzM enhancement	
		MetCritPPass				FLOAT,
		TotalPPM					FLOAT,
		TotalSampleCOUNT			INT,
		TotalDefectCOUNT			INT,
		DummyCol13					BIT,
		DummyCol14					BIT,
		DummyCol15					BIT,
		DummyCol16					BIT,								
		DummyCol17					BIT,								
		DummyCol18					BIT,								
		DummyCol19					BIT,
		DummyCol20					BIT,
		DummyCol21					BIT,
		DummyCol22					BIT,
		DummyCol23					BIT,
		DummyCol24					BIT,
		DummyCol25					BIT,
		DummyCol26					BIT,
		DummyCol27					BIT,
		DummyCol28					BIT,
		DummyCol29					BIT,
		Border2						INT)
-----------------------------------------------------------------------------------------------------------------------
-- List of CalcPPM Id's
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblCalcPPMIdTemp TABLE (
		RcdIdx						INT	Identity(1,1),
 		CalcPPMId					INT)
-----------------------------------------------------------------------------------------------------------------------
-- List of TimeSliceProdId's
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblProdIdTemp TABLE (
		RcdIdx						INT	Identity(1,1),
 		TimeSliceProdId				INT)
-----------------------------------------------------------------------------------------------------------------------
-- This table holds the list of time slices that are valid for the reporting period and the filters selected
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblValidTimeSlices	TABLE (
		TimeSliceId						INT	Identity(1, 1),
		VarId							INT			,
		MajorGroupId					INT			,
		MinorGroupId					INT			,
		PLId							INT			,
		PUId							INT			,
		ProdId							INT			,
		ProductGrpId					INT			,
		PLStatusId						INT			,
		ShiftDesc						VARCHAR(50)	,
		CrewDesc						VARCHAR(50)	,
		TimeSliceStart					DATETIME	,
		TimeSliceEnd					DATETIME	,
		OverlapFlagLineStatus			INT			,
		OverlapFlagShift				INT			,
		OverlapSequence 				INT			,
		OverlapRcdFlag					INT			,
		SplitLineStatusFlag				INT			,
		SplitShiftFlag					INT			,
		SplitSpecChangeFlag				INT			,
		ActivePathId					INT			,
		PO								VARCHAR(50) 
		)
-----------------------------------------------------------------------------------------------------------------------
-- Table to get the display configuration
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblDisplayConfiguration	TABLE		(
		RcdIdx						INT	Identity(1,1),
		DisplayTemplateId			INT			,
		DisplayInstanceId			INT			,
		DisplayOptionId				INT			,
		DisplayOptionDesc			VARCHAR(50)	,
		DisplayOptionDefault		VARCHAR(100),
		DisplayOptionValue			VARCHAR(100))
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblSheetTable				TABLE		(
		RcdIdx						INT	Identity(1,1),
		SheetId						INT, 
		SheetDesc					VARCHAR(100))
-----------------------------------------------------------------------------------------------------------------------
--	Returns the filter criteria selected for the report when an error is enCOUNTered
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblErrorCriteria	TABLE	(
		ErrorCategory				VARCHAR(500),
		Comment1					VARCHAR(1000), 
		Comment2					VARCHAR(5000))
-----------------------------------------------------------------------------------------------------------------------
--	Non-Normal Values
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblNonNormalPPMValuesTemp TABLE (
		CalcPPMId					INT		,
		ZLower						FLOAT	,
		ZUpper						FLOAT	,
		CalcPPMPoolActual			FLOAT	)
-----------------------------------------------------------------------------------------------------------------------
--	Holds the list of valid line status 
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblSchedLineStatus	TABLE ( 
        Idx                         INT IDENTITY(1,1),
		PLStatusSchedId				INT		,
		PLStatusStart				DATETIME,
		PLStatusEnd					DATETIME,
		PLStatusId					INT		,
		PLId						INT		,
		LineStatusPUId				INT		,
		Processed					INT DEFAULT 0)
-----------------------------------------------------------------------------------------------------------------------
--	List of spec changes that overlap times slices for variable that have a spec activation of inmediate
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblSpecChangeOverlapList	TABLE (
		SpecChangeId				INT Identity(1,1),
		ProdId						INT		,
		VarId						INT		,
		SpecChangeStart				DATETIME,
		SpecChangeEnd				DATETIME)
-----------------------------------------------------------------------------------------------------------------------
--	Temporary Intermediate table
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblTimeSliceProductionTemp TABLE (
		TimeSliceId						INT,
		TimeSliceVolumeCountVarId		INT,
		TimeSliceVolumeCountVariable	FLOAT,
		TimeSliceVolumeCountEvent		FLOAT,
		TestCountResultNOTNULL			INT,
		TestCountResultNULL				INT)
-----------------------------------------------------------------------------------------------------------------------
--	Bad data list
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblBadDataList	TABLE (
		VarId						INT			,
		VarDesc						VARCHAR(100),
		Result						VARCHAR(50)	,
		ResultTimeStamp 			VARCHAR(30)	)
-----------------------------------------------------------------------------------------------------------------------
--	VAR Report variable statistics
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblVASRptVarStatistics	TABLE	(
		Border1						INT,
		MajorGroupId				INT,
		PUGId						INT,
		PUGDesc						VARCHAR(100),
		VarGroupId					VARCHAR(100),
		VarDesc						VARCHAR(100),
		CalcPPMAoolContribution		FLOAT,	-- Weighted SUM
		CalcPPMPoolActual			FLOAT,	--	SUM
		CalcPPMPoolContribution		FLOAT,	-- Weighted SUM
		ObsUCIPPMContribution		FLOAT,
		CalcUCIPPM					FLOAT,
		CalcUCIPPMContribution		FLOAT,
		MetCritActual				FLOAT, -- PassesVirtualZero
		MetCritPPass				FLOAT, -- PassesVzContribution
		TotalPPM					FLOAT,
		SampleCOUNT					INT,
		DefectCOUNT					INT,
		LSL							FLOAT,
		LTL							FLOAT,
		Target						FLOAT,
		UTL							FLOAT,
		USL							FLOAT,
		TestMIN						FLOAT,								
		TestMAX						FLOAT,								
		TestAvg						FLOAT,								
		TestStDev					FLOAT,
		Tz							FLOAT,
		Cr							FLOAT,
		CpK							FLOAT,
		MetCritTz					FLOAT,
		MetCritCr					FLOAT,
		MetCritCpK					FLOAT,
		SubGroupSize				INT,
		SpecVersion					VARCHAR(50),
		CalcCpK						FLOAT,
		SUMMetCritActual			FLOAT,	--	SUM(VolumeCount * MetCritActual) 	or SUM(TestCount * MetCritActual)
		SUMTestAvg					FLOAT,	--	SUM(VolumeCount * TestAvg)			or SUM(TestCount * TestAvg)
		SUMTestStDev				FLOAT,	--	SUM(VolumeCount * TestStDev)		or SUM(TestCount * TestStDev)
		SUMTz						FLOAT,	--	SUM(VolumeCount * Tz)				or SUM(TestCount * Tz)
		SUMCr						FLOAT,	--	SUM(VolumeCount * Cr)				or SUM(TestCount * Cr)
		SUMCpK						FLOAT,	--	SUM(VolumeCount * CpK)				or SUM(TestCount * CpK)
		SUMMCTz						FLOAT,	--	SUM(VolumeCount * MCTz)				or SUM(TestCount * MCTz)
		SUMMCCr						FLOAT,	--	SUM(VolumeCount * MCCr)				or SUM(TestCount * MCCr)
		SUMMCCpK					FLOAT,	--	SUM(VolumeCount * MCCpK)			or SUM(TestCount * MCCpK)
		SUMCalcCpK					FLOAT,	--	SUM(VolumeCount * CalcCpK)			or SUM(TestCount * CalcCpK)
		SUMVolumeCount				FLOAT,
		MetCritPPassTemp			FLOAT,	--	(CONVERT(FLOAT, cp.MetCritActual) * cp.TestCount) or (CONVERT(FLOAT, cp.MetCritActual) * cp.TestCount)
		MinorGroupVolumeCountTemp	FLOAT,	--	mi.MinorGroupVolumeCount
		Border2						INT)
-----------------------------------------------------------------------------------------------------------------------
--	Obsolete columns:
--	SUMTestCount			FLOAT,
--	MinorGroupTestCountTemp	FLOAT,	--	mi.MinorGroupTestCount
-----------------------------------------------------------------------------------------------------------------------
--	Test COUNT for time slices that do not have a test COUNT and logic needs to look for test inside the MAXim look-up
--	radius
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblValidTimeSlicesTestCount TABLE (
		TimeSliceId					INT,
		TestCountResultNOTNULL 		INT,
		TestCountResultNULL			INT,
		MSRTestCountResultNOTNULL	INT,
		MSRTestCountResultNULL		INT)
-----------------------------------------------------------------------------------------------------------------------
-- Note: the ChiSquareCritcalValues table is a look-up table of critical values that determines 
-- the maximun value of ChiSquare for a 0.05 probability and a given degree of freedom
-- if the ChiSquareValue < than the ChiSquareCriticalValue then the data can be classified as normal
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblChiSquareCriticalValues TABLE ( 
		DegOfFreedom				INT		,
		ChiSquareCriticalValue		FLOAT	)
-----------------------------------------------------------------------------------------------------------------------
--	Interim table used in the search of the closest test value inside the MAXimum sampling radius
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblTempTests	TABLE (
		VarId			INT		,
		TimeSliceId		INT		,
		ResultON		DATETIME)
-----------------------------------------------------------------------------------------------------------------------
--	Holds temporary list of times slices 
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblTimeSliceTemp TABLE(
		RcdIdx				INT	IDENTITY(1,1),
		TimeSliceId			INT,
		TimeSlicePUId		INT,
		VarId				INT,
		TimeSliceStart		DATETIME,
		TimeSliceEnd		DATETIME,
		LSL					VARCHAR(50),
		Target				VARCHAR(50),
		USL					VARCHAR(50),
		IsOfflineQuality	INT)
-----------------------------------------------------------------------------------------------------------------------
--	Holds temporary test results
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblTestResultsTemp TABLE(
		TimeSliceId	INT			,
		VarId		INT			,
		Result		VARCHAR(50)	,
		LSL			VARCHAR(50)	,
		Target		VARCHAR(50)	,
		USL			VARCHAR(50)	)

-----------------------------------------------------------------------------------------------------------------------
--	Holds Production Plan and PathId for all the Production Paths
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblProdPlanPath  TABLE ( 
		PathId					INT				,	
		PLId					INT				,
		PUId					INT				,
		SourcePLId				INT				,
		PathDesc				NVARCHAR(300)   ,
		IsProductionPoint		INT				,
		ProductionVarId			INT				)

-----------------------------------------------------------------------------------------------------------------------
--	Holds Production Plan and PathId for all the active production plans during the report window 
-----------------------------------------------------------------------------------------------------------------------
DECLARE @tblProdPlanActive  TABLE ( 	
		PLId					INT				,
		PUId					INT				,
		PPId					INT				,
		PPSStartTime			DATETIME		,
		PPSEndTime				DATETIME		,
		PathId					INT				,
		ProdId					INT				,
		ProductGrpId			INT				,
		PO						VARCHAR(50))
-----------------------------------------------------------------------------------------------------------------------
--	Temporary table to collect intermediate values
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#TempValue', 'U') IS NOT NULL  DROP TABLE #TempValue
CREATE TABLE 	#TempValue	(
				RcdIdx		INT			IDENTITY(1,1),
				VarGroupId	VARCHAR(100),
				ValueINT	INT			,
				ValueFLOAT	FLOAT 		)	
-----------------------------------------------------------------------------------------------------------------------
--	Temporary table to collect intermediate values
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#TempValue2', 'U') IS NOT NULL  DROP TABLE #TempValue2
CREATE TABLE 	#TempValue2	(
				RcdIdx				INT			IDENTITY(1,1),
				ValueINT			INT			,
				ValueFLOAT			FLOAT 		)
-----------------------------------------------------------------------------------------------------------------------
--	Temporary table to collect intermediate values for Chi Squared 
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblChiSquareTemp TABLE (
		CalcPPMId					INT,
 		ChiSquarePPMSlice			FLOAT)  -- SUM(ChiSquareBin)	
-----------------------------------------------------------------------------------------------------------------------
--	Temporary table used to look for repeating major group description 
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblMajorGroupTemp TABLE (
		RcdIdx			INT	IDENTITY (1,1),
 		MajorGroupDesc	VARCHAR(100),
 		DescCOUNT		INT)
-----------------------------------------------------------------------------------------------------------------------
--	Temporary table used to COUNT SPC child variables
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListDataSourceTemp	TABLE (
		PLId			INT			,
		VarGroupId		VARCHAR(100),
		VarCount 		INT			)
-----------------------------------------------------------------------------------------------------------------------
--	List of PU's that belong to a converting line
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListConvertingPUTemp	TABLE (
		RcdIdx						INT	IDENTITY (1,1),
		PLId						INT,
		PUId						INT	)
-----------------------------------------------------------------------------------------------------------------------
-- 	List of event subtypes
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblListEventSubTypes	TABLE	(
		RcdIdx			INT	IDENTITY (1,1),
		EventSubTypeId	INT)
-----------------------------------------------------------------------------------------------------------------------
--	Interim table used to calculate the volume COUNT for the CalcPPM slices
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblVarProductionInterim2 TABLE (
		RcdId						INT	Identity(1, 1),
		MajorGroupId				INT			,
		MinorGroupId				INT			,
		IsNumericDataType			INT			,
		PLId						INT			,
		PUGId						INT			,
		ProductGrpId				INT			,
		PO							VARCHAR(50)	,
		VarGroupId					VARCHAR(100), 
		LEL							VARCHAR(50)	,
		LSL							VARCHAR(50)	,
		Target						VARCHAR(50)	,
		USL							VARCHAR(50)	,
		UEL							VARCHAR(50)	,
		LTL							VARCHAR(50)	,
		UTL							VARCHAR(50)	,
		SpecVersion					VARCHAR(35)	,
		VolumeCount					FLOAT		,
		StatusLEL					VARCHAR(50) ,
		StatusLSL					VARCHAR(50) ,
		StatusLTL					VARCHAR(50) ,
		StatusTarget				VARCHAR(50) ,
		StatusUTL					VARCHAR(50) ,
		StatusUSL					VARCHAR(50) ,
		StatusUEL					VARCHAR(50) ,
		StatusSpecVersion			VARCHAR(35) )
-----------------------------------------------------------------------------------------------------------------------
--	RS1: Miscellaneous information
--	This table holds information required to prepare the report header, error messages and any other loose information 
-- 	required to generate the report
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblMiscInfo TABLE (
		CompanyName					VARCHAR(50)		,
		SiteName					VARCHAR(50)		,
		RptTitle					VARCHAR(255)	,
		RptOwnerDesc				VARCHAR(50)		,
		RptStartDateTime 			VARCHAR(25)		,
		RptEndDateTime				VARCHAR(25)		,
		PeriodIncompleteFlag		INT				,
		FilterPL					VARCHAR(1000)	,
		FilterPU					VARCHAR(1000)	,
		FilterShift					VARCHAR(1000)		,
		FilterCrew					VARCHAR(1000)		,
		FilterPLStatus				VARCHAR(1000)	,
		FilterProduct				VARCHAR(1000)	,
		FilterProductGroup			VARCHAR(1000)	,
		MajorGroupBy				VARCHAR(50)		,
		MinorGroupBy				VARCHAR(50)		,
		WithDataValidation			INT				,
		WithDataValidationExtended	INT				,
		WeightSpecChanges			INT				,
		SpecSetting					INT				,
		ColPrecision				INT				,
		ErrorCode					INT				,
		ErrorMsg					VARCHAR(1000)	,
		WarningMsg					VARCHAR(500)	,
		EmptyRcdSet					VARCHAR(5) DEFAULT 0 ,	-- 0 = NO, 1 = YES
		AppVersion					VARCHAR(100)		,			-- From AppVersion
		RTVersion					VARCHAR(100)		,
		VzEnabled					INT DEFAULT 0 )			-- From Report_Types
-----------------------------------------------------------------------------------------------------------------------
--	RS: CalcPPMRawData holds Non-Normal raw data
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblCalcPPMRawData TABLE (	
		RcdId						INT Identity (1,1),
		CalcPPMId					INT				,
		MajorGroupId				INT				,
		MinorGroupId				INT				,
		VarGroupId					VARCHAR(100)	,
		ResultRank					INT				,
		Result						FLOAT			,
		ResultTimeStamp				DATETIME		,
		HistTestFlag				INT				,	-- 1 = historical test, 0 = real test
		h							FLOAT			,
		Adjustedh					FLOAT			,
		LEL							VARCHAR(50)		, 	-- Lower Entry Limit
		LSL							VARCHAR(50)		,	-- Lower Reject Limit
		Target						VARCHAR(50)		,	
		TargetRpt					VARCHAR(50)		,	
		USL							VARCHAR(50)		,	-- Upper Reject Limit
		UEL							VARCHAR(50)		, 	-- Upper Entry Limit
		LTL							VARCHAR(50)		,	-- Lower Target Limit
		UTL							VARCHAR(50)		,	-- Upper Target Limit
		SpecVersion					VARCHAR(35)		,
		MAXZ						FLOAT			,
		MINZ						FLOAT			,
		MAXT						FLOAT			,
		MINT						FLOAT			,
		NormMAX						FLOAT			,
		NormMIN						FLOAT			,
		NormFactor					FLOAT			,
		TempXl						FLOAT			,
		TempXu						FLOAT			,
		TempTl						FLOAT			,
		TempTu						FLOAT			,
		ZLower						FLOAT			,
		ZUpper						FLOAT			,
		TestCount					INT	DEFAULT 1	,
		TestFail					INT				)
-----------------------------------------------------------------------------------------------------------------------
--	RS:	Distribution factors for Non-Normal Raw Data
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblDistributionFactorCalc	TABLE (
		CalcPPMId					INT			,
		MajorGroupId				INT			,
		MinorGroupId				INT			,
		VarGroupId					VARCHAR(100),
		VarStDev					FLOAT		,
		VarTestCount				INT			,
		VarR25Rank					FLOAT		,
		VarR75Rank					FLOAT		,
		VarR25Value1				FLOAT		,
		VarR25Value2				FLOAT		,
		VarR25Value					FLOAT		,
		VarR75Value1				FLOAT		,
		VarR75Value2				FLOAT		,
		VarR75Value					FLOAT		,
		r							FLOAT		,
		h							FLOAT	 	)
-----------------------------------------------------------------------------------------------------------------------
--	RS:	Percent confidence for ChiSquare calculations
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblPercentConfidence TABLE (
		CalcPPMId					INT		,
		IntervalNumber				INT		,
		IntervalBegin				FLOAT	,
		IntervalEnd					FLOAT	,
		ObservedCOUNT				INT	DEFAULT 0,
		ExpectedCOUNT				FLOAT	,
		ChiSquareBin				FLOAT	)	-- ((ObservedCOUNT-ExpectedCOUNT)^2)/ExpectedCOUNT
-----------------------------------------------------------------------------------------------------------------------
--	Temp Tables
-----------------------------------------------------------------------------------------------------------------------
-- Temporary table used to parse the strings
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#TempCalcPPMRawData', 'U') IS NOT NULL  DROP TABLE #TempCalcPPMRawData
CREATE TABLE   #TempCalcPPMRawData (	-- Raw data for non-normal distributions i.e. Extended_Info = "Norm = N"
					ResultRank		INT IDENTITY(1,1),
					CalcPPMId		INT,
					MajorGroupId	INT,
					MinorGroupId	INT,
					VarGroupId		VARCHAR(100),
					Result			VARCHAR(25)	,
					ResultTimeStamp DATETIME,
					HistTestFlag	INT,
					LEL				VARCHAR(50),
					LSL				VARCHAR(50),
					Target			VARCHAR(50),
					USL				VARCHAR(50),
					UEL				VARCHAR(50),
					LTL				VARCHAR(50),
					UTL				VARCHAR(50),
					SpecVersion		DATETIME,
					SpecVersionTR 	DATETIME		)

IF OBJECT_ID('tempdb.dbo.#TempTable', 'U') IS NOT NULL  DROP TABLE #TempTable
CREATE TABLE	#TempTable	(
				RcdIdx				INT	Identity (1,1),
				RcdId				INT,
				SortOrder			INT,
				ValueINT			INT,
				ValueVCH50			VARCHAR(50))
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#NonNormalValuesTemp2', 'U') IS NOT NULL  DROP TABLE #NonNormalValuesTemp2 
CREATE TABLE	#NonNormalValuesTemp2(
	CalcPPMId			INT			,		
	VarId				INT			,
	VarGroupId			VARCHAR(100),
	Result				VARCHAR(25)	,
	ResultON			DATETIME	,
	TestSquaredDev		FLOAT		,
	TimeSliceProdId		INT			,
	TimeSliceStart		DATETIME	,
	TimeSliceEnd		DATETIME	,
	QualityPUId			INT			,
	PLStatusId			INT			,
	HistTestFlag		INT			,	-- Flag 1 = historical test result, 0 = real test result
	LEL					VARCHAR(50)	,
	LSL					VARCHAR(50)	,
	LTL					VARCHAR(50)	,
	Target				VARCHAR(50)	,
	UTL					VARCHAR(50)	,
	USL					VARCHAR(50)	,
	UEL					VARCHAR(50)	,
	TargetRangeSpecId	INT			,
	CharId				INT			)
-----------------------------------------------------------------------------------------------------------------------
-- This table holds the list of variables selected for the report
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ListDataSource', 'U') IS NOT NULL  DROP TABLE #ListDataSource
CREATE TABLE	#ListDataSource (
				SortOrder			INT	Identity (1,1),
				PLId				INT			,
				VarMasterPUId		INT			,
				VarPUId				INT			,
				VarPUIdDesc			VARCHAR(50)	,
				VarPUIdSource		INT			,
				VarPUIdSourceDesc	VARCHAR(50)	,
				PUGId				INT			,
				VarId				INT			,
				VarTestName			VARCHAR(100),
				VarGroupId			VARCHAR(100),
				VarDataTypeId		INT			,
				VarDesc				VARCHAR(100),
				VarDescRpt			VARCHAR(100),
				SPCParentVarId		INT			,		--	Var_Id of the SPC parent
				SPCCalcId			INT			,		--	SPC_Calculation_Type_Id from dbo.SPC_Calculation_Types this Id indentifies the
														--	type of SPC calculation. This type id is assigned to the SPC parent varible
				SPCVarTypeId		INT			,		--	SPC_Group_Variable_Type_Id from dbo.SPC_Group_Variable_Types this Id indentifies the
														--	type of individual variables that make up the SPC calculation.
				IsNonNormal			INT	DEFAULT 0	,	-- Options: 1 = YES; 0 = NO
				IsReportable		INT	DEFAULT 1	,	-- Options: 1 = YES; 0 = NO
				TzFlag				INT	DEFAULT 1	,	-- Options: 1 = YES include Target Value; 0 = NO set target valued to NULL
				IsAtt				INT			,		-- Options: 1 = attributes of type text
														-- 			2 = numeric variables that need to be treated as attributes
														--				but also need to display statistical values on the VAS report
														--			3 = numeric variable that need to be treated as attributes but 
														--				do not require statistical values on the VAS report
				VarCount			INT			,
				ExtendedTestFreq	INT			,
				SamplingInterval	INT			,
				VarEventType		INT			,
				VarEventSubTypeId	INT			,
				VarSpecActivation	INT			,
				IsNumericDataType	INT DEFAULT 0,		-- Options 1 - data type is in 1,2,6,7	0 - all other datatypes
				IsTAMUVariable		INT DEFAULT 0,      -- Options 0 - If NonNumeric and only Target Specification 1 - NonNumeric and LSL and USL.
				RptSPCParent		INT	DEFAULT	0, 		-- Options: 1 = the code should report the values for the parent
														-- 		  : 0 = the code should report the values for the children  	
				Criticality			INT DEFAULT 1,
				IsOfflineQuality	INT	DEFAULT 0)

-- 	OBSOLETE Fields:
--	TargetRangeSpecId	INT			, 	-- From User_Defined2 Field in dbo.Variables_Base
--	RptValue			VARCHAR(5)	,	-- this field was replaced by IsReportable
-----------------------------------------------------------------------------------------------------------------------
--	FILTER: Data Source (Variables)
--	NOTE: this is a temp table because we need an index on Var_Desc to make the variable search faster
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ListDataSourceFilter', 'U') IS NOT NULL  DROP TABLE #ListDataSourceFilter
CREATE TABLE	#ListDataSourceFilter (
				RcdIdx				INT	Identity (1, 1),
				SortOrder			INT,
				VarId				INT,
				VarDesc				VARCHAR(100) )
-----------------------------------------------------------------------------------------------------------------------
--	This table is a formula look-up for met criteria formulas
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MCFormulaLookUp', 'U') IS NOT NULL  DROP TABLE #MCFormulaLookUp
CREATE TABLE	#MCFormulaLookUp (
				MCFormulaId			INT Identity(1,1),
				MCUSL				INT,
				MCLSL				INT,
				MCTarget			INT,
				MCTargetRange		INT,
				MCSymmetricSpecs	INT,
				Cr					VARCHAR(600),
				Tz1					VARCHAR(600),
				Tz2					VARCHAR(600),
				Cpk					VARCHAR(600),
				MCCr				VARCHAR(600),
				MCTz				VARCHAR(600),
				MCCpk				VARCHAR(600),
				CalcCpk				VARCHAR(600),
				InfinityFlagCr		VARCHAR(600),
				InfinityFlagTz1		VARCHAR(600),
				InfinityFlagTz2		VARCHAR(600),
				InfinityFlagCpk		VARCHAR(600) )
-----------------------------------------------------------------------------------------------------------------------
--	This table holds the list of time slices that are valid for the reporting period and the filters selected and the
--	variables selected.
--	The variables must be included to get the specs and the spec changes for the variables that have a spec change of
--	inmediate
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ValidVarTimeSlices', 'U') IS NOT NULL  DROP TABLE #ValidVarTimeSlices
CREATE TABLE	#ValidVarTimeSlices (
				TimeSliceId							INT	Identity (1, 1)	PRIMARY KEY,
				CalcPPMId							INT					,
				VarId								INT					,
				VarSpecActivation					INT					,
				MajorGroupId						INT					,
				MinorGroupId						INT					,
				PLId								INT					,
				PUId								INT					,
				PUGId								INT					,
				VarGroupId							VARCHAR(100)		,
				SourcePUId							INT					,
				ProdId								INT					,
				SourceProdId						INT					,
				ProductGrpId						INT					,
				PLStatusId							INT					,
				ShiftDesc							VARCHAR(50)			,
				CrewDesc							VARCHAR(50)			,
				TimeSliceStart						DATETIME			,
				TimeSliceEnd						DATETIME			,
				TimeSliceVolumeCount				FLOAT DEFAULT 0.0	,
				TimeSliceProductionType				INT					,	
				TimeSliceVolumeCountVarId			INT					,
				TimeSliceVolumeCountVariable		FLOAT DEFAULT 0.0	,
				TimeSliceVolumeCountMSUConvFactor	FLOAT DEFAULT 1.0	,	-- Conversion Factor converts TimeSliceVolumeCountVariable to MSU
																			-- Conversion Factor is the Target Limit of the Spec variable associated
																			-- with the Production_Variable from dbo.Prod_Units_Base
				TimeSliceVolumeCountEvent			FLOAT DEFAULT 0.0	,
				TestCountResultNOTNULL				INT				,		-- Added to eliMINate slices where test COUNT = 0 
				TestCountResultNULL					INT				,
				TestCountTotal						INT				,
				SpecTestFreq						INT				,
				TestFreq							INT				,
				SamplingInterval					INT				,
				MAXSamplingRadiusStart				DATETIME		,
				MAXSamplingRadiusEnd				DATETIME		,
				MSRTestCountResultNOTNULL			INT				,
				MSRTestCountResultNULL				INT				,
				TestValue1							VARCHAR(100)	,
				TestValue1TimeStamp					DATETIME		,
				DateDiff1InSec						INT				,			
				TestValue2							VARCHAR(100)	,
				TestValue2TimeStamp					DATETIME		,
				DateDiff2InSec						INT				,	
				ClosestTestValue					VARCHAR(100)	,
				ClosestTestValueTimeStamp			DATETIME		,
				LEL									VARCHAR(50)		,
				LSL									VARCHAR(50)		,
				LTL									VARCHAR(50)		,	-- Lower Target Limit
				Target								VARCHAR(50)		,
				UTL									VARCHAR(50)		,	-- Upper Target Limit
				USL									VARCHAR(50)		,
				UEL									VARCHAR(50)		,
				SpecVersion							VARCHAR(35)		,
				TimeSliceEliminationFlag			INT	DEFAULT 0	,	-- 0 = No, 1 = Yes
				TimeSliceEliminationReason			VARCHAR(1000)	,	
				IsOfflineQuality					INT	DEFAULT 0	,
				OverlapFlagLineStatus				INT DEFAULT 0	,	-- The overlap fields are used in the logic that splits records
				OverlapFlagShift					INT DEFAULT 0	,	-- accross shifts, line status and spec boundaries.
				OverlapFlagSpecChange				INT DEFAULT 0	,	-- The fields are zeroed out after the records are split.
				OverlapSequence 					INT				,
				OverlapRcdFlag						INT	DEFAULT 0	,
				SplitLineStatusFlag					INT DEFAULT 0	,	-- Used for debugging only: marks records that have been split at line status boundaries
				SplitShiftFlag						INT DEFAULT 0	,	-- Used for debugging only: marks records that have been split at shift boundaries
				SplitSpecChangeFlag					INT DEFAULT 0	,
				PathId								INT				,
				PO									VARCHAR(50)		)	

-- OBSOLETE Fields:
--	QualityPUId	INT				,
--	SpecVersionTR	VARCHAR(35)		,	-- replaced by control limits on proficy 4.0
--	TargetRangeSpecId					INT				,
--	CharId								INT				,	
-----------------------------------------------------------------------------------------------------------------------
--	CAPTURES the MajorMinorGroupVolumeCount
--  Redesign this : split into major and minor tables.
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#ExcelVolumeCheck', 'U') IS NOT NULL  DROP TABLE #ExcelVolumeCheck
CREATE TABLE	#ExcelVolumeCheck	(
				TimeSliceId						INT IDENTITY(1,1),
				PLId							INT,
				PLDesc							VARCHAR(50),
				ProdId							INT,
				ProductGrpId					INT,
				PUId							INT,
				PUDesc							VARCHAR(100),
				TimeSliceStart					DATETIME,
				TimeSliceEnd					DATETIME,				
				ProductionVarId					INT,
				Volume							FLOAT,
				MSUConversionFactor				FLOAT,
				TotalVolume						FLOAT
)

IF OBJECT_ID('tempdb.dbo.#MajorMinorVolumeCount', 'U') IS NOT NULL  DROP TABLE #MajorMinorVolumeCount
CREATE TABLE	#MajorMinorVolumeCount	(
				MajorGroupId					INT				,	
				MinorGroupId					INT				,
				TimeSliceId						INT				,
				TimeSliceStart					DATETIME		,
				TimeSliceEnd					DATETIME		,
				PLId							INT				,
				PLDesc							VARCHAR(50)		,
				ProdId							INT				,
				ProductGrpId					INT				,
				PUId							INT				,
				PathId							INT				,
				PO								VARCHAR(50)		,
--				PODesc							VARCHAR(50)		,
				PathDesc						VARCHAR(200)	,
				ActivePathId					INT				,
				PUDesc							VARCHAR(100)	,
				ProductionCountVariable			FLOAT			,
				ProductionCountEvent			FLOAT			,
				TestCount						FLOAT			,
				MajorMinorVolumeCount			FLOAT			,			-- CAN be either Variable Production, Event Production or test COUNT
				CountsForMajor					INT  DEFAULT 1	)	
				
IF OBJECT_ID('tempdb.dbo.#MajorVolumeCount', 'U') IS NOT NULL  DROP TABLE #MajorVolumeCount
CREATE TABLE	#MajorVolumeCount	(
				MajorGroupId					INT,	
				MinorGroupId					INT,
				TimeSliceId						INT,
				TimeSliceStart					DATETIME,
				TimeSliceEnd					DATETIME,
				PLId							INT,
				PLDesc							VARCHAR(50),
				PUId							INT,
				PUDesc							VARCHAR(100),
				ProdId							INT,
				ProductGrpId					INT,
				ProductionCountVarId			INT,
				ProductionCountVariable			FLOAT,
				ProductionCountMSUConvFactor	FLOAT DEFAULT 1.0,
				ProductionCountEvent			FLOAT,
				TestCount						FLOAT,
				MajorMinorVolumeCount			FLOAT)

-----------------------------------------------------------------------------------------------------------------------
--	Table used to calculate Met Criteria PPass Avg
-----------------------------------------------------------------------------------------------------------------------
DECLARE			@tblMetCritPPassAvg	TABLE (
				MajorGroupId	INT			,
				MinorGroupId	INT			,
				PUGDesc			VarChar(100),
				MetCritPPass	FLOAT 		)
-----------------------------------------------------------------------------------------------------------------------
--	RS2: Major group info
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MajorGroupList', 'U') IS NOT NULL  DROP TABLE #MajorGroupList
CREATE TABLE	#MajorGroupList (
				MajorGroupId			INT Identity(1, 1),
				PLId					INT,
				PUId					INT,
				PUDesc					VARCHAR(100),
				ProdId					INT,
				ProductGrpId			INT,
				PLDesc					VARCHAR(100),
				ProdCode				VARCHAR(100),
				ProductGrpDesc			VARCHAR(100),
				MajorGroupVolumeCount 	FLOAT,
				MajorGroupDesc			VARCHAR(100))

-----------------------------------------------------------------------------------------------------------------------
--	RS2: Minor group info
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#MinorGroupList', 'U') IS NOT NULL  DROP TABLE #MinorGroupList
CREATE TABLE	#MinorGroupList (
				MajorGroupId			INT,
				MinorGroupId			INT Identity(1, 1),
				-- PUGId					INT,
				MinorGroupColId			INT,
				PLId 					INT,
				PathId					INT,
				PathDesc				VARCHAR(100),
				PO						VARCHAR(50),
--				PODesc					VARCHAR(50),
				ProdId					INT,
				PUId					INT,				
				ProductGrpId			INT,
				PUDesc					VARCHAR(100),
				PLDesc					VARCHAR(100),
				ProdCode				VARCHAR(100),
				ProductGrpDesc			VARCHAR(100),
				MinorGroupVolumeCount	FLOAT,
				MinorGroupMetCritCOUNT	INT)

--	MinorGroupTestCount		INT) OBSOLETE Field
-----------------------------------------------------------------------------------------------------------------------
--	RS6: Calc PPM and Met Criteria Raw Data
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#CalcPPM', 'U') IS NOT NULL  DROP TABLE #CalcPPM
CREATE TABLE	#CalcPPM (
				CalcPPMId					INT	Identity(1, 1) PRIMARY KEY,
				MajorGroupId				INT,
				MinorGroupId				INT,
				PLId						INT,				-- Major/Minor group by field
				ProductGrpId				INT,				-- Major/Minor group by field
				ProdId						INT,				-- Major/Minor Group by field
				PODesc						VARCHAR(50),		-- Process Order
				SpecVersion					VARCHAR(35),		-- Used for spec change weighting
				SpecChange					INT,		
				VolumeCount					FLOAT,				-- SUM of pads produced during the time slices the tests were made
				VarCount					FLOAT,				-- Number of variables that have the same test name
				PUGId						INT,				-- Filter
				VarGroupId					VARCHAR(100),		-- Test Name or VarId
				VarDescRpt					VARCHAR(100),		-- COALESCE between TestName and VarDesc
				IsNonNormal					INT,
				SampleLessThanFlag			INT DEFAULT 0,		-- Flags records that do not meet the miMINum sample COUNT for a MIN reporting period
				HistDataNotFoundFlag		INT DEFAULT 0,		-- Flags records that do not enough historical data to meet the sample < criteria
				TestAvg						FLOAT,
				TestStDev					FLOAT,
				TestSUMSquaredDev			FLOAT,				-- For VAS report only
				TestFail					INT,
				TestCount					INT,				-- TestCount = TestCountReal + TestCountHist 
				TestCountReal				INT,				
				TestCountHist				INT DEFAULT 0,		-- Historical test COUNT when TestCountReal < sample < criteria
				TestMIN						FLOAT,
				TestMAX						FLOAT,
				LEL							VARCHAR(50)	,
				LSL							VARCHAR(50)	,
				Target						VARCHAR(50)	,
				TargetRpt					VARCHAR(50)	,
				USL							VARCHAR(50)	,
				UEL							VARCHAR(50)	,
				LTL							VARCHAR(50)	,	-- Lower Target Limit
				UTL							VARCHAR(50)	,	-- Upper Target Limit
				CPL							FLOAT		,
				CPU							FLOAT		,
				ExpectedTarget				INT			,
				DegOfFreedom				INT			,
				ChiSquarePPMSlice			FLOAT		,	-- SUM of ChiSquareBin
				ChiSquareCriticalValue		FLOAT		,	-- From look-up table @tblChiSquareCriticalValues
				IsNonNormalReclassification	VARCHAR(50)	,	
				TempXl						FLOAT,
				TempXu						FLOAT,
				TempTl						FLOAT,
				TempTu						FLOAT,
				ZLower						FLOAT,
				ZUpper						FLOAT,
				ObsUCIPPM					NUMERIC(18,0),
				ObsUCIPPMContribution		FLOAT,
				CalcUCIPPM					NUMERIC(18,0),
				CalcUCIPPMContribution		FLOAT,
				CalcPPMAoolActual			FLOAT,
				CalcPPMAoolContribution		FLOAT,
				CalcPPMPoolActual			FLOAT,
				CalcPPMPoolContribution		FLOAT,
				IncludeAool					INT,				-- Flags which values should be included in the SUMmary section total for Att Options: 1 - yes; 0 - no
				IncludePool					INT,				-- Flags which values should be included in the SUMmary section total for PQM Options: 1 - yes; 0 - no
				MCUSL						INT DEFAULT 0,		-- Options 1: USL is present 0: USL is not present
				MCLSL						INT DEFAULT 0,  	-- Options 1: LSL is present 0: LSL is not present
				MCTarget					INT DEFAULT 0,  	-- Options 1: Target is present 0: Target is not present
				MCTargetRange				INT DEFAULT 0,		-- Options 1: yes 0: no
				MCSymmetricSpecs			INT DEFAULT 0,		-- Options 1: yes 0: no
				MCFormulaId					INT,
				Cr							DECIMAL(38,5),		-- Capability ratio. 
				Tz							DECIMAL(38,1),		-- Target Z. 
				Cpk							DECIMAL(38,5),		-- Capability index
				InfinityFlagTz				BIT	DEFAULT 0,
				InfinityFlagCpk				BIT	DEFAULT 0,
				InfinityFlagCr				BIT	DEFAULT 0,
				MCCr						INT,				-- Options 1: yes 0: no value met MCCr 	criteria in formula table
				MCTz						INT,				-- Options 1: yes 0: no value met MCTz 	criteria in formula table
				MCCpk						INT,				-- Options 1: yes 0: no value met MCCpk 	criteria in formula table
				MetCritActual				INT, 				-- Options 1: yes 0: no If MCCr = 1, MCTz = 1 and MCCpk = 1 then 1 else 0
				MetCritContribution			FLOAT,
				CalcCpk						DECIMAL(38,5),
				MetCritVarCountByProdGroup	INT,	-- In this column Cpk is calculated when possible. Not used for met criteria evaluation.
				StatusLEL					VARCHAR(50) ,
				StatusLSL					VARCHAR(50) ,
				StatusLTL					VARCHAR(50) ,
				StatusTarget				VARCHAR(50) ,
				StatusUTL					VARCHAR(50) ,
				StatusUSL					VARCHAR(50) ,
				StatusUEL					VARCHAR(50) ,
				StatusSpecVersion			VARCHAR(35) ,
				MajorGroupVolumeCount		FLOAT		,	-- ON VAS report only
				MinorGroupVolumeCount		FLOAt		,   -- ON VAS report only
				IsNumericDataType			INT			,	
				IsAtt						INT			,	
				SUMVolumeCount				FLOAT		,	-- ON VAS report only
				IsOfflineQuality			INT			,
				PassesVirtualZero			INT			DEFAULT 0,
				PassesVZContribution		FLOAT		)

--	OBSOLETE:
--	StatusSpecVersionTR			VARCHAR(35) ,
--	TargetRangeSpecId			INT,			--	IN PPM30 the Target range specs came from the dbo.Active_Specs table
												--	In PPM40 the target range are the control specs in dbo.Var_Specs table 
--	CharId						INT,			-- Only required when variable has target ranges
--	SpecVersionTR				VARCHAR(35),	-- Not Used for spec change weighting
--	MajorGroupTestCount			INT			,	-- ON VAS report only
-----------------------------------------------------------------------------------------------------------------------
-- RS:	the HistoricalDataValues table of real and historical data values for CalPPMId's that 
-- 		do not meet the MINimum sample COUNT for a given reporting period
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#HistoricalDataValues', 'U') IS NOT NULL  DROP TABLE #HistoricalDataValues
CREATE TABLE	#HistoricalDataValues (
				CalcPPMId					INT			,		
				VarId						INT			,
				VarGroupId					VARCHAR(100),
				Result						VARCHAR(25)	,
				ResultON					DATETIME	,
				TestSquaredDev				FLOAT		,
				TimeSliceProdId				INT			,
				TimeSliceStart				DATETIME	,
				TimeSliceEnd				DATETIME	,
				QualityPUId					INT			,
				PLStatusId					INT			,
				HistTestFlag				INT			,	-- Flag 1 = historical test result, 0 = real test result
				LEL							VARCHAR(50)	,
				LSL							VARCHAR(50)	,
				LTL							VARCHAR(50)	,
				Target						VARCHAR(50)	,
				UTL							VARCHAR(50)	,
				USL							VARCHAR(50)	,
				UEL							VARCHAR(50)	,
				TargetRangeSpecId			INT			,
				CharId						INT			)
-----------------------------------------------------------------------------------------------------------------------
--	Support table for historical data values logic
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#HistoricalDataValuesTemp1', 'U') IS NOT NULL  DROP TABLE #HistoricalDataValuesTemp1
CREATE TABLE	#HistoricalDataValuesTemp1 (
				CalcPPMId					INT			,		
				VarId						INT			,
				VarGroupId					VARCHAR(100),
				Result						VARCHAR(25)	,
				ResultON					DATETIME	,
				TestSquaredDev				FLOAT		,
				TimeSliceProdId				INT			,
				TimeSliceStart				DATETIME	,
				TimeSliceEnd				DATETIME	,
				QualityPUId					INT			,	
				PLStatusId					INT			,
				HistTestFlag				INT			,	-- Flag 1 = historical test result, 0 = real test result
				LEL							VARCHAR(50)	,
				LSL							VARCHAR(50)	,
				LTL							VARCHAR(50)	,
				Target						VARCHAR(50)	,
				UTL							VARCHAR(50)	,
				USL							VARCHAR(50)	,
				UEL							VARCHAR(50)	,
				TargetRangeSpecId			INT			,
				CharId						INT			)
-----------------------------------------------------------------------------------------------------------------------
--	Intermediate table to determine filter criteria
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblFilterCriteria	TABLE	(
		Parameter							VARCHAR(100)	, 
		Value								VARCHAR(7000) 	)
-----------------------------------------------------------------------------------------------------------------------
--	Support table for historical data values logic
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#HistoricalDataValuesTemp2', 'U') IS NOT NULL  DROP TABLE #HistoricalDataValuesTemp2
CREATE TABLE	#HistoricalDataValuesTemp2 (
				CalcPPMId					INT			,		
				VarId						INT			,
				VarGroupId					VARCHAR(100),
				Result						VARCHAR(25)	,
				ResultON					DATETIME	,
				TestSquaredDev				FLOAT		,
				TimeSliceProdId				INT			,
				TimeSliceStart				DATETIME	,
				TimeSliceEnd				DATETIME	,
				QualityPUId					INT			,	
				PLStatusId					INT			,
				HistTestFlag				INT			,	-- Flag 1 = historical test result, 0 = real test result
				LEL							VARCHAR(50)	,
				LSL							VARCHAR(50)	,
				LTL							VARCHAR(50)	,
				Target						VARCHAR(50)	,
				UTL							VARCHAR(50)	,
				USL							VARCHAR(50)	,
				UEL							VARCHAR(50)	,
				TargetRangeSpecId			INT			,
				CharId						INT			)
-----------------------------------------------------------------------------------------------------------------------
--	Interim table for NORMPPM Surmmary section result set
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FinalResultSetSUMmaryInterim', 'U') IS NOT NULL  DROP TABLE #FinalResultSetSUMmaryInterim
CREATE TABLE	#FinalResultSetSUMmaryInterim (
				MajorGroupId				INT,
				MinorGroupId				INT,
			 	PLId						INT,
				PUGDesc						VARCHAR(100),
				IncludeInSUM				INT,
				CalcPPM						FLOAT,
				CalcUCIPPM					FLOAT,
				CalcPPMWeighted				FLOAT,
				CalcUCIPPMWeighted			FLOAT,
				MetCritPPass				FLOAT, 
				MinorGroupVolumeCount		FLOAT,
				MajorGroupVolumeCount		FLOAT,
				MinorGroupMetCritCOUNT		INT )
-- 	OBSOLETE	
--	MinorGroupTestCount		INT,
-----------------------------------------------------------------------------------------------------------------------
--	RS:	Result set for NORMPPM SUMmary Section
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#FinalResultSetSUMmary', 'U') IS NOT NULL  DROP TABLE #FinalResultSetSUMmary
CREATE TABLE	#FinalResultSetSUMmary (
				Border1			INT,
				MajorGroupId	INT,
				SpecVersion		VARCHAR(35),	-- This field is not required in the SUMmary section, but is used to line the result set up
				PUGDesc			VARCHAR(100),
				IncludeInSUM	INT,				-- Options: 1 = yes, 2 = no
CalcPPM1		FLOAT,	CalcUCIPPM1	FLOAT,	MetCritPPass1		FLOAT,	CalcPPM2	FLOAT,	CalcUCIPPM2	FLOAT,	MetCritPPass2	FLOAT,
CalcPPM3		FLOAT,	CalcUCIPPM3	FLOAT,	MetCritPPass3		FLOAT,	CalcPPM4	FLOAT,	CalcUCIPPM4	FLOAT,	MetCritPPass4	FLOAT,
CalcPPM5		FLOAT,	CalcUCIPPM5	FLOAT,	MetCritPPass5		FLOAT,	CalcPPM6	FLOAT,	CalcUCIPPM6	FLOAT,	MetCritPPass6	FLOAT,
CalcPPM7		FLOAT,	CalcUCIPPM7	FLOAT,	MetCritPPass7		FLOAT,	CalcPPM8	FLOAT,	CalcUCIPPM8	FLOAT,	MetCritPPass8	FLOAT,
CalcPPM9		FLOAT,	CalcUCIPPM9	FLOAT,	MetCritPPass9		FLOAT,	CalcPPM10	FLOAT,	CalcUCIPPM10	FLOAT,	MetCritPPass10	FLOAT,
CalcPPM11		FLOAT,	CalcUCIPPM11	FLOAT,	MetCritPPass11		FLOAT,	CalcPPM12	FLOAT,	CalcUCIPPM12	FLOAT,	MetCritPPass12	FLOAT,
CalcPPM13		FLOAT,	CalcUCIPPM13	FLOAT,	MetCritPPass13		FLOAT,	CalcPPM14	FLOAT,	CalcUCIPPM14	FLOAT,	MetCritPPass14	FLOAT,
CalcPPM15		FLOAT,	CalcUCIPPM15	FLOAT,	MetCritPPass15		FLOAT,	CalcPPM16	FLOAT,	CalcUCIPPM16	FLOAT,	MetCritPPass16	FLOAT,
CalcPPM17		FLOAT,	CalcUCIPPM17	FLOAT,	MetCritPPass17		FLOAT,	CalcPPM18	FLOAT,	CalcUCIPPM18	FLOAT,	MetCritPPass18	FLOAT,
CalcPPM19		FLOAT,	CalcUCIPPM19	FLOAT,	MetCritPPass19		FLOAT,	CalcPPM20	FLOAT,	CalcUCIPPM20	FLOAT,	MetCritPPass20	FLOAT,
CalcPPM21		FLOAT,	CalcUCIPPM21	FLOAT,	MetCritPPass21		FLOAT,	CalcPPM22	FLOAT,	CalcUCIPPM22	FLOAT,	MetCritPPass22	FLOAT,
CalcPPM23		FLOAT,	CalcUCIPPM23	FLOAT,	MetCritPPass23		FLOAT,	CalcPPM24	FLOAT,	CalcUCIPPM24	FLOAT,	MetCritPPass24	FLOAT,
CalcPPM25		FLOAT,	CalcUCIPPM25	FLOAT,	MetCritPPass25		FLOAT,	CalcPPM26	FLOAT,	CalcUCIPPM26	FLOAT,	MetCritPPass26	FLOAT,
CalcPPM27		FLOAT,	CalcUCIPPM27	FLOAT,	MetCritPPass27		FLOAT,	CalcPPM28	FLOAT,	CalcUCIPPM28	FLOAT,	MetCritPPass28	FLOAT,
CalcPPM29		FLOAT,	CalcUCIPPM29	FLOAT,	MetCritPPass29		FLOAT,	CalcPPM30	FLOAT,	CalcUCIPPM30	FLOAT,	MetCritPPass30	FLOAT,
CalcPPM31		FLOAT,	CalcUCIPPM31	FLOAT,	MetCritPPass31		FLOAT,	CalcPPM32	FLOAT,	CalcUCIPPM32	FLOAT,	MetCritPPass32	FLOAT,
CalcPPM33		FLOAT,	CalcUCIPPM33	FLOAT,	MetCritPPass33		FLOAT,	CalcPPM34	FLOAT,	CalcUCIPPM34	FLOAT,	MetCritPPass34	FLOAT,
CalcPPM35		FLOAT,	CalcUCIPPM35	FLOAT,	MetCritPPass35		FLOAT,	CalcPPM36	FLOAT,	CalcUCIPPM36	FLOAT,	MetCritPPass36	FLOAT,
CalcPPM37		FLOAT,	CalcUCIPPM37	FLOAT,	MetCritPPass37		FLOAT,	CalcPPM38	FLOAT,	CalcUCIPPM38	FLOAT,	MetCritPPass38	FLOAT,
CalcPPM39		FLOAT,	CalcUCIPPM39	FLOAT,	MetCritPPass39		FLOAT,	CalcPPM40	FLOAT,	CalcUCIPPM40	FLOAT,	MetCritPPass40	FLOAT,
CalcPPM41		FLOAT,	CalcUCIPPM41	FLOAT,	MetCritPPass41		FLOAT,	CalcPPM42	FLOAT,	CalcUCIPPM42	FLOAT,	MetCritPPass42	FLOAT,
CalcPPM43		FLOAT,	CalcUCIPPM43	FLOAT,	MetCritPPass43		FLOAT,	CalcPPM44	FLOAT,	CalcUCIPPM44	FLOAT,	MetCritPPass44	FLOAT,
CalcPPM45		FLOAT,	CalcUCIPPM45	FLOAT,	MetCritPPass45		FLOAT,	CalcPPM46	FLOAT,	CalcUCIPPM46	FLOAT,	MetCritPPass46	FLOAT,
CalcPPM47		FLOAT,	CalcUCIPPM47	FLOAT,	MetCritPPass47		FLOAT,	CalcPPM48	FLOAT,	CalcUCIPPM48	FLOAT,	MetCritPPass48	FLOAT,
CalcPPM49		FLOAT,	CalcUCIPPM49	FLOAT,	MetCritPPass49		FLOAT,	CalcPPM50	FLOAT,	CalcUCIPPM50	FLOAT,	MetCritPPass50	FLOAT,
CalcPPM51		FLOAT,	CalcUCIPPM51	FLOAT,	MetCritPPass51		FLOAT,	CalcPPM52	FLOAT,	CalcUCIPPM52	FLOAT,	MetCritPPass52	FLOAT,
CalcPPM53		FLOAT,	CalcUCIPPM53	FLOAT,	MetCritPPass53		FLOAT,	CalcPPM54	FLOAT,	CalcUCIPPM54	FLOAT,	MetCritPPass54	FLOAT,
CalcPPM55		FLOAT,	CalcUCIPPM55	FLOAT,	MetCritPPass55		FLOAT,	CalcPPM56	FLOAT,	CalcUCIPPM56	FLOAT,	MetCritPPass56	FLOAT,
CalcPPM57		FLOAT,	CalcUCIPPM57	FLOAT,	MetCritPPass57		FLOAT,	CalcPPM58	FLOAT,	CalcUCIPPM58	FLOAT,	MetCritPPass58	FLOAT,
CalcPPM59		FLOAT,	CalcUCIPPM59	FLOAT,	MetCritPPass59		FLOAT,	CalcPPM60	FLOAT,	CalcUCIPPM60	FLOAT,	MetCritPPass60	FLOAT,
CalcPPM61		FLOAT,	CalcUCIPPM61	FLOAT,	MetCritPPass61		FLOAT,	CalcPPM62	FLOAT,	CalcUCIPPM62	FLOAT,	MetCritPPass62	FLOAT,
CalcPPM63		FLOAT,	CalcUCIPPM63	FLOAT,	MetCritPPass63		FLOAT,	CalcPPM64	FLOAT,	CalcUCIPPM64	FLOAT,	MetCritPPass64	FLOAT,
CalcPPM65		FLOAT,	CalcUCIPPM65	FLOAT,	MetCritPPass65		FLOAT,	CalcPPM66	FLOAT,	CalcUCIPPM66	FLOAT,	MetCritPPass66	FLOAT,
CalcPPM67		FLOAT,	CalcUCIPPM67	FLOAT,	MetCritPPass67		FLOAT,	CalcPPM68	FLOAT,	CalcUCIPPM68	FLOAT,	MetCritPPass68	FLOAT,
CalcPPM69		FLOAT,	CalcUCIPPM69	FLOAT,	MetCritPPass69		FLOAT,	CalcPPM70	FLOAT,	CalcUCIPPM70	FLOAT,	MetCritPPass70	FLOAT,
CalcPPM71		FLOAT,	CalcUCIPPM71	FLOAT,	MetCritPPass71		FLOAT,	CalcPPM72	FLOAT,	CalcUCIPPM72	FLOAT,	MetCritPPass72	FLOAT,
CalcPPM73		FLOAT,	CalcUCIPPM73	FLOAT,	MetCritPPass73		FLOAT,	CalcPPM74	FLOAT,	CalcUCIPPM74	FLOAT,	MetCritPPass74	FLOAT,
CalcPPM75		FLOAT,	CalcUCIPPM75	FLOAT,	MetCritPPass75		FLOAT,	CalcPPM76	FLOAT,	CalcUCIPPM76	FLOAT,	MetCritPPass76	FLOAT,
CalcPPM77		FLOAT,	CalcUCIPPM77	FLOAT,	MetCritPPass77		FLOAT,	CalcPPM78	FLOAT,	CalcUCIPPM78	FLOAT,	MetCritPPass78	FLOAT,
CalcPPM79		FLOAT,	CalcUCIPPM79	FLOAT,	MetCritPPass79		FLOAT,	CalcPPM80	FLOAT,	CalcUCIPPM80	FLOAT,	MetCritPPass80	FLOAT,
CalcPPM81		FLOAT,	CalcUCIPPM81	FLOAT,	MetCritPPass81		FLOAT,	CalcPPM82	FLOAT,	CalcUCIPPM82	FLOAT,	MetCritPPass82	FLOAT,
CalcPPM83		FLOAT,	CalcUCIPPM83	FLOAT,	MetCritPPass83		FLOAT,	CalcPPM84	FLOAT,	CalcUCIPPM84	FLOAT,	MetCritPPass84	FLOAT,
CalcPPM85		FLOAT,	CalcUCIPPM85	FLOAT,	MetCritPPass85		FLOAT,	CalcPPM86	FLOAT,	CalcUCIPPM86	FLOAT,	MetCritPPass86	FLOAT,
CalcPPM87		FLOAT,	CalcUCIPPM87	FLOAT,	MetCritPPass87		FLOAT,	CalcPPM88	FLOAT,	CalcUCIPPM88	FLOAT,	MetCritPPass88	FLOAT,
CalcPPM89		FLOAT,	CalcUCIPPM89	FLOAT,	MetCritPPass89		FLOAT,	CalcPPM90	FLOAT,	CalcUCIPPM90	FLOAT,	MetCritPPass90	FLOAT,
--
				TotalPPM		FLOAT,	TotalMetCritPPass	FLOAT,	Border2			INT )
-----------------------------------------------------------------------------------------------------------------------
--	Interim table for NORMPPM Detail section result set
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#NormPPMRptFinalResultSetDetailInterim', 'U') IS NOT NULL  DROP TABLE #NormPPMRptFinalResultSetDetailInterim
CREATE TABLE	#NormPPMRptFinalResultSetDetailInterim (
				MajorGroupId			INT,
				MinorGroupId			INT,
				PLId					INT,
				SpecVersion				VARCHAR(35),
				PUGId					INT,
				PUGDesc					VARCHAR(100),
				IncludeInSUM			INT,
				VarDesc					VARCHAR(100),
				CalcPPM					FLOAT,
				CalcUCIPPM				FLOAT,
				CalcPPMWeighted			FLOAT,
				MinorGroupVolumeCount	FLOAT,	
				MajorGroupVolumeCount	FLOAT,
				MetCrit					FLOAT,
				MetCritContribution		FLOAT,
				MinorGroupMetCritCOUNT	INT,
				VarVolumeCount			FLOAT)				
--	OBSOLETE
--MinorGroupTestCount		FLOAT,	
--MajorGroupTestCount		FLOAT,
--VarTestCount			FLOAT )

-----------------------------------------------------------------------------------------------------------------------
--	Temp table to hold the Start End Time
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#Local_PG_StartEndTime', 'U') IS NOT NULL  DROP TABLE #Local_PG_StartEndTime
CREATE TABLE	#Local_PG_StartEndTime (
					rptStartTime			VARCHAR(25),
					rptEndTime				VARCHAR(25)  )
					
-----------------------------------------------------------------------------------------------------------------------
--	VAS report variable attributes
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblVASRptVarAttributes	TABLE	(
		Border1							INT,
		MajorGroupId					INT,
		VarGroupId						VARCHAR(100),
		PUGId							INT,
		PUGDesc							VARCHAR(100),
		VarDesc							VARCHAR(100),
		CalcPPMAoolContribution			FLOAT,	-- Weighted SUM
		ObsUCIPPMContribution			FLOAT,
		-- DummyCol6						BIT, Comented out because of VzM enhancement
		DummyCol7						BIT,
		DummyCol8						BIT,
		PassesVirtualZero				FLOAT,
		PassesVZContribution			FLOAT,
		PercentTarget					FLOAT,
		TotalPPM						FLOAT,
		UCIPPM							FLOAT,
		SampleCOUNT						INT,
		DefectCOUNT						INT,
		LSL								FLOAT,
		DummyCol14						BIT,
		Target							VARCHAR(100),
		DummyCol16						BIT,								
		USL								FLOAT,								
		TestMIN							FLOAT,								
		TestMAX							FLOAT,
		TestAvg							FLOAT,
		TestStDev						FLOAT,
		DummyCol22						BIT,
		DummyCol23						BIT,
		DummyCol24						BIT,
		DummyCol25						BIT,
		DummyCol26						BIT,
		DummyCol27						BIT,
		SubGroupSize					INT,
		SpecVersion						VARCHAR(50),
		Border2							INT,
		SUMTestAvg						FLOAT,	--	SUM(VolumeCount * TestAvg)
		SUMTestStDev					FLOAT,	--	SUM(VolumeCount * TestStDev))
		SUMVolumeCount					FLOAT	,
		TotalSampleCount				INT	)
-----------------------------------------------------------------------------------------------------------------------
--	Met Criteria intermediate table
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblMetCritVarDescByProdGroup	TABLE (
		MajorGroupId					INT,
		MinorGroupId					INT,
		PUGDesc							NVARCHAR(100),
		ProductGrpId					INT,
		VarDescRpt						VARCHAR(100))
-----------------------------------------------------------------------------------------------------------------------
--	Met Criteria intermediate table
-----------------------------------------------------------------------------------------------------------------------
DECLARE	@tblMetCritVarCountByProdGroup	TABLE (
		MajorGroupId					INT	,
		MinorGroupId					INT	,
		PUGDesc							NVARCHAR(100),
		ProductGrpId					INT	,
		MetCritVarCountByProdGroup		INT )

-----------------------------------------------------------------------------------------------------------------------
--	To temporary hold the TestCount when weighting turns into test count
-----------------------------------------------------------------------------------------------------------------------
DECLARE @TempMajorGroupVolumeCount TABLE ( 
		MajorGroupid					INT, 
		PUGId							INT, 
		PUGDesc							NVARCHAR(100),
		TempMajorGroupSampCountAttr		FLOAT,
		TempMajorGroupSampCountVar		FLOAT)
-----------------------------------------------------------------------------------------------------------------------
--	To temporary hold the MinorGrouping TestCount when weighting turns into test count
-----------------------------------------------------------------------------------------------------------------------
DECLARE @TempMinorGroupVolumeCount TABLE ( 
		MajorGroupid					INT, 
		MinorGroupId					INT,
		PUGId							INT, 
		PUGDesc							NVARCHAR(100),
		TempMajorGroupSampCountAttr		FLOAT,
		TempMajorGroupSampCountVar		FLOAT)

--

DECLARE @SUMTimeSliceVolumeCount TABLE (
		SUMTimeSliceVolumeCount		FLOAT,
		SUMTimeSliceTestCount		FLOAT	)
-----------------------------------------------------------------------------------------------------------------------
--	RS:	Result set for NORMPPM Detail Section
-----------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#NormPPMRptFinalResultSetDetail', 'U') IS NOT NULL  DROP TABLE #NormPPMRptFinalResultSetDetail
CREATE TABLE	#NormPPMRptFinalResultSetDetail (
				Border1			INT,
				MajorGroupId	INT,
				SpecVersion		VARCHAR(35),
				PUGDesc			VARCHAR(100),
				VarDesc			VARCHAR(100),
				IncludeInSUM	INT,
CalcPPM1		FLOAT,	CalcUCIPPM1	FLOAT,	MetCrit1		FLOAT,	CalcPPM2	FLOAT,	CalcUCIPPM2	FLOAT,	MetCrit2	FLOAT,
CalcPPM3		FLOAT,	CalcUCIPPM3	FLOAT,	MetCrit3		FLOAT,	CalcPPM4	FLOAT,	CalcUCIPPM4	FLOAT,	MetCrit4	FLOAT,
CalcPPM5		FLOAT,	CalcUCIPPM5	FLOAT,	MetCrit5		FLOAT,	CalcPPM6	FLOAT,	CalcUCIPPM6	FLOAT,	MetCrit6	FLOAT,
CalcPPM7		FLOAT,	CalcUCIPPM7	FLOAT,	MetCrit7		FLOAT,	CalcPPM8	FLOAT,	CalcUCIPPM8	FLOAT,	MetCrit8	FLOAT,
CalcPPM9		FLOAT,	CalcUCIPPM9	FLOAT,	MetCrit9		FLOAT,	CalcPPM10	FLOAT,	CalcUCIPPM10	FLOAT,	MetCrit10	FLOAT,
CalcPPM11		FLOAT,	CalcUCIPPM11	FLOAT,	MetCrit11		FLOAT,	CalcPPM12	FLOAT,	CalcUCIPPM12	FLOAT,	MetCrit12	FLOAT,
CalcPPM13		FLOAT,	CalcUCIPPM13	FLOAT,	MetCrit13		FLOAT,	CalcPPM14	FLOAT,	CalcUCIPPM14	FLOAT,	MetCrit14	FLOAT,
CalcPPM15		FLOAT,	CalcUCIPPM15	FLOAT,	MetCrit15		FLOAT,	CalcPPM16	FLOAT,	CalcUCIPPM16	FLOAT,	MetCrit16	FLOAT,
CalcPPM17		FLOAT,	CalcUCIPPM17	FLOAT,	MetCrit17		FLOAT,	CalcPPM18	FLOAT,	CalcUCIPPM18	FLOAT,	MetCrit18	FLOAT,
CalcPPM19		FLOAT,	CalcUCIPPM19	FLOAT,	MetCrit19		FLOAT,	CalcPPM20	FLOAT,	CalcUCIPPM20	FLOAT,	MetCrit20	FLOAT,
CalcPPM21		FLOAT,	CalcUCIPPM21	FLOAT,	MetCrit21		FLOAT,	CalcPPM22	FLOAT,	CalcUCIPPM22	FLOAT,	MetCrit22	FLOAT,
CalcPPM23		FLOAT,	CalcUCIPPM23	FLOAT,	MetCrit23		FLOAT,	CalcPPM24	FLOAT,	CalcUCIPPM24	FLOAT,	MetCrit24	FLOAT,
CalcPPM25		FLOAT,	CalcUCIPPM25	FLOAT,	MetCrit25		FLOAT,	CalcPPM26	FLOAT,	CalcUCIPPM26	FLOAT,	MetCrit26	FLOAT,
CalcPPM27		FLOAT,	CalcUCIPPM27	FLOAT,	MetCrit27		FLOAT,	CalcPPM28	FLOAT,	CalcUCIPPM28	FLOAT,	MetCrit28	FLOAT,
CalcPPM29		FLOAT,	CalcUCIPPM29	FLOAT,	MetCrit29		FLOAT,	CalcPPM30	FLOAT,	CalcUCIPPM30	FLOAT,	MetCrit30	FLOAT,
CalcPPM31		FLOAT,	CalcUCIPPM31	FLOAT,	MetCrit31		FLOAT,	CalcPPM32	FLOAT,	CalcUCIPPM32	FLOAT,	MetCrit32	FLOAT,
CalcPPM33		FLOAT,	CalcUCIPPM33	FLOAT,	MetCrit33		FLOAT,	CalcPPM34	FLOAT,	CalcUCIPPM34	FLOAT,	MetCrit34	FLOAT,
CalcPPM35		FLOAT,	CalcUCIPPM35	FLOAT,	MetCrit35		FLOAT,	CalcPPM36	FLOAT,	CalcUCIPPM36	FLOAT,	MetCrit36	FLOAT,
CalcPPM37		FLOAT,	CalcUCIPPM37	FLOAT,	MetCrit37		FLOAT,	CalcPPM38	FLOAT,	CalcUCIPPM38	FLOAT,	MetCrit38	FLOAT,
CalcPPM39		FLOAT,	CalcUCIPPM39	FLOAT,	MetCrit39		FLOAT,	CalcPPM40	FLOAT,	CalcUCIPPM40	FLOAT,	MetCrit40	FLOAT,
CalcPPM41		FLOAT,	CalcUCIPPM41	FLOAT,	MetCrit41		FLOAT,	CalcPPM42	FLOAT,	CalcUCIPPM42	FLOAT,	MetCrit42	FLOAT,
CalcPPM43		FLOAT,	CalcUCIPPM43	FLOAT,	MetCrit43		FLOAT,	CalcPPM44	FLOAT,	CalcUCIPPM44	FLOAT,	MetCrit44	FLOAT,
CalcPPM45		FLOAT,	CalcUCIPPM45	FLOAT,	MetCrit45		FLOAT,	CalcPPM46	FLOAT,	CalcUCIPPM46	FLOAT,	MetCrit46	FLOAT,
CalcPPM47		FLOAT,	CalcUCIPPM47	FLOAT,	MetCrit47		FLOAT,	CalcPPM48	FLOAT,	CalcUCIPPM48	FLOAT,	MetCrit48	FLOAT,
CalcPPM49		FLOAT,	CalcUCIPPM49	FLOAT,	MetCrit49		FLOAT,	CalcPPM50	FLOAT,	CalcUCIPPM50	FLOAT,	MetCrit50	FLOAT,
CalcPPM51		FLOAT,	CalcUCIPPM51	FLOAT,	MetCrit51		FLOAT,	CalcPPM52	FLOAT,	CalcUCIPPM52	FLOAT,	MetCrit52	FLOAT,
CalcPPM53		FLOAT,	CalcUCIPPM53	FLOAT,	MetCrit53		FLOAT,	CalcPPM54	FLOAT,	CalcUCIPPM54	FLOAT,	MetCrit54	FLOAT,
CalcPPM55		FLOAT,	CalcUCIPPM55	FLOAT,	MetCrit55		FLOAT,	CalcPPM56	FLOAT,	CalcUCIPPM56	FLOAT,	MetCrit56	FLOAT,
CalcPPM57		FLOAT,	CalcUCIPPM57	FLOAT,	MetCrit57		FLOAT,	CalcPPM58	FLOAT,	CalcUCIPPM58	FLOAT,	MetCrit58	FLOAT,
CalcPPM59		FLOAT,	CalcUCIPPM59	FLOAT,	MetCrit59		FLOAT,	CalcPPM60	FLOAT,	CalcUCIPPM60	FLOAT,	MetCrit60	FLOAT,
CalcPPM61		FLOAT,	CalcUCIPPM61	FLOAT,	MetCrit61 		FLOAT,	CalcPPM62	FLOAT,	CalcUCIPPM62	FLOAT,	MetCrit62   FLOAT,	
CalcPPM63		FLOAT,	CalcUCIPPM63	FLOAT,	MetCrit63 		FLOAT,	CalcPPM64	FLOAT,	CalcUCIPPM64	FLOAT,	MetCrit64 FLOAT,	
CalcPPM65		FLOAT,	CalcUCIPPM65	FLOAT,	MetCrit65 		FLOAT,	CalcPPM66	FLOAT,	CalcUCIPPM66	FLOAT,	MetCrit66 FLOAT,	
CalcPPM67		FLOAT,	CalcUCIPPM67	FLOAT,	MetCrit67 		FLOAT,	CalcPPM68	FLOAT,	CalcUCIPPM68	FLOAT,	MetCrit68 FLOAT,	
CalcPPM69		FLOAT,	CalcUCIPPM69	FLOAT,	MetCrit69 		FLOAT,	CalcPPM70	FLOAT,	CalcUCIPPM70	FLOAT,	MetCrit70 FLOAT,	
CalcPPM71		FLOAT,	CalcUCIPPM71	FLOAT,	MetCrit71 		FLOAT,	CalcPPM72	FLOAT,	CalcUCIPPM72	FLOAT,	MetCrit72 FLOAT,	
CalcPPM73		FLOAT,	CalcUCIPPM73	FLOAT,	MetCrit73 		FLOAT,	CalcPPM74	FLOAT,	CalcUCIPPM74	FLOAT,	MetCrit74 FLOAT,	
CalcPPM75		FLOAT,	CalcUCIPPM75	FLOAT,	MetCrit75 		FLOAT,	CalcPPM76	FLOAT,	CalcUCIPPM76	FLOAT,	MetCrit76 FLOAT,	
CalcPPM77		FLOAT,	CalcUCIPPM77	FLOAT,	MetCrit77 		FLOAT,	CalcPPM78	FLOAT,	CalcUCIPPM78	FLOAT,	MetCrit78 FLOAT,	
CalcPPM79		FLOAT,	CalcUCIPPM79	FLOAT,	MetCrit79 		FLOAT,	CalcPPM80	FLOAT,	CalcUCIPPM80	FLOAT,	MetCrit80 FLOAT,	
CalcPPM81		FLOAT,	CalcUCIPPM81	FLOAT,	MetCrit81 		FLOAT,	CalcPPM82	FLOAT,	CalcUCIPPM82	FLOAT,	MetCrit82 FLOAT,	
CalcPPM83		FLOAT,	CalcUCIPPM83	FLOAT,	MetCrit83 		FLOAT,	CalcPPM84	FLOAT,	CalcUCIPPM84	FLOAT,	MetCrit84 FLOAT,	
CalcPPM85		FLOAT,	CalcUCIPPM85	FLOAT,	MetCrit85 		FLOAT,	CalcPPM86	FLOAT,	CalcUCIPPM86	FLOAT,	MetCrit86 FLOAT,	
CalcPPM87		FLOAT,	CalcUCIPPM87	FLOAT,	MetCrit87 		FLOAT,	CalcPPM88	FLOAT,	CalcUCIPPM88	FLOAT,	MetCrit88 FLOAT,	
CalcPPM89		FLOAT,	CalcUCIPPM89	FLOAT,	MetCrit89 		FLOAT,	CalcPPM90	FLOAT,	CalcUCIPPM90	FLOAT,	MetCrit90 FLOAT,	
--
				TotalPPM		FLOAT,	TotalMetCrit	FLOAT,	Border2		INT )
-----------------------------------------------------------------------------------------------------------------------
--	Table Indexes
-----------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX ListDataSourceVarId_Idx 
ON #ListDataSource (VarId) 
-----------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX ListDataSourceFilterVarDesc_Idx 
ON #ListDataSourceFilter (VarDesc) 
-----------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx
ON #ValidVarTimeSlices (TimeSliceId, VarId, TimeSliceStart, TimeSliceEnd, PLId, ProdId) 
-----------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX ValidVarTimeSlices_CalcPPMId_Idx
ON #ValidVarTimeSlices (CalcPPMId) 
-----------------------------------------------------------------------------------------------------------------------
CREATE NONCLUSTERED INDEX CalcPPM_FormulaId_Idx
ON #CalcPPM (MCFormulaId)
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VALIDATE SP Paramters'
--=====================================================================================================================
IF	LEN(COALESCE(@p_vchRptLayoutOption, '')) = 0
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode = 1,
			@vchErrorMsg = 'Report layout has not been specified, it should be NormPPM or VASReport'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO FINISHError
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INITIALIZE variables'
--=====================================================================================================================
--	INITIALEZE VARIABLES
-----------------------------------------------------------------------------------------------------------------------
--	Error Message
-----------------------------------------------------------------------------------------------------------------------
SELECT	@intErrorCode 	= 0,
		@vchErrorMsg 	= ''
-----------------------------------------------------------------------------------------------------------------------
--	UDP field names
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchUDPDescLineStatusPUId	=	'LineStatusPUId',
		@vchUDPDescDefaultQProdGrps	=	'DefaultQProdGrps',
		@vchUDPDescIsNonNormal		=	'Is NonNormal',
		@vchUDPDescReportable		=	'Reportable',
		@vchUDPDescTzFlag			=	'TzFlag',
		@vchUDPDescIsAtt			=	'Is Attribute',
		@vchUDPDescSPCParent		= 	'RptSPCParent',
		@vchUDPDescCriticality		= 	'Criticality',
		@vchUDPDescIsConvertingLine	= 	'IsConvertingLine',
		@vchUDPDescIsOfflineQuality	=	'IsOfflineQuality'
-----------------------------------------------------------------------------------------------------------------------
--	INITIALEZE Report Values
-----------------------------------------------------------------------------------------------------------------------		
SELECT	@vchRptPUIdList 			= '',
		@intRptVolumeWeightOption	= 0,
		@intRptWeightSpecChanges 	= 1
-----------------------------------------------------------------------------------------------------------------------
--	INITIALEZE PPM formula constants
-----------------------------------------------------------------------------------------------------------------------
SET	@dtmNow 		= CONVERT(VARCHAR(25), GETDATE(), 121)
SET	@ConstantPI 	= PI()
SET	@ConstantE 		= EXP(1)
SET	@ConstantP 		= 0.2316419
SET	@ConstantB1 	= 0.319381530
SET	@ConstantB2 	= -0.356563782
SET	@ConstantB3 	= 1.781477937
SET	@ConstantB4 	= -1.821255978
SET	@ConstantB5 	= 1.330274429
SET	@ConstantErrorX = 0
-----------------------------------------------------------------------------------------------------------------------
--	INITIALIZE ChiSquare constants
-----------------------------------------------------------------------------------------------------------------------
SET	@ConstantStDevMultiplier	=	0.3	-- Multiplier used to calculate bin range
-----------------------------------------------------------------------------------------------------------------------
--	INITIALIZE Time Slice eliMINiation reasons
-----------------------------------------------------------------------------------------------------------------------
SET	@ConTimeSliceEliminationReason1	=	'TestCountResultNOTNULL = 0 and TestCounResultNULL > 0'
SET	@ConTimeSliceEliminationReason2	=	'Test Frequency = 0 and TestCountResultNOTNull IS NULL and TestCountResultNULL IS NULL'		
SET	@ConTimeSliceEliminationReason3	=	'Sampling Interval IS NULL'
SET	@ConTimeSliceEliminationReason4	=	'TestCountResultNOTNULL IS NULL and TestCounResultNULL IS NULL Sampling Interval IS 0; this means that the MAXSamplingRadius = TimeSlicePeriod and there are no tests available during this period'
SET	@ConTimeSliceEliminationReason5	=	'No valid tests in MAXimum Sampling Radius; MSRTestCountResultNOTNULL = 0 and MSRTestCountResultNULL > 0'	
SET	@ConTimeSliceEliminationReason6	=	'No valid tests in MAXimum Sampling Radius; MSRTestCountResultNOTNULL IS NULL and MSRTestCountResultNULL IS NULL'	
SET	@ConTimeSliceEliminationReason7	=	'Production COUNT IS NULL'	
-----------------------------------------------------------------------------------------------------------------------
--	INITIALIZE Maximun Group
-----------------------------------------------------------------------------------------------------------------------
SET @intMaxGroup	= 50
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Site Parameters'
--=====================================================================================================================
--	GET Site Parameters
-----------------------------------------------------------------------------------------------------------------------
--	GET	Company Name from dbo.Site_Parameters table
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchCompanyName = COALESCE(Value, 'Company Name')
FROM 	dbo.Site_Parameters	WITH(NOLOCK)
WHERE 	Parm_Id = 11
-----------------------------------------------------------------------------------------------------------------------
--	GET	Site Name from dbo.Site_Parameters table
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchSiteName = COALESCE(Value, 'Site Name')
FROM 	dbo.Site_Parameters	WITH (NOLOCK)
WHERE 	Parm_Id = 12
-----------------------------------------------------------------------------------------------------------------------
-- GET spec setting from dbo.Site_Parameters table
-- IF @intSpecSetting = 1 then limit analysis is >
-- ELSE limit analysis is >=
-----------------------------------------------------------------------------------------------------------------------
SELECT 	@intSpecSetting = COALESCE(Value, 1) 
FROM	dbo.Site_Parameters WITH (NOLOCK)
WHERE 	Parm_Id = 13
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Report Parameter Values'


--=====================================================================================================================
--	GET Report Parameter Values
-----------------------------------------------------------------------------------------------------------------------
-- Parameters from Landing Page
-----------------------------------------------------------------------------------------------------------------------
	SELECT	@intRptOwnerId							= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'intRptOwnerId')									, 1)				
	SELECT	@vchRptSortOrderVarIdList				= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'strRptSortOrderVarIdList')							, '')				
	SELECT	@dtmRptShiftStart						= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_StartShift')								, '6:30:00')		
	SELECT	@intRptShiftLength						= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_ShiftLength')								, 8)				
	SELECT	@vchRptProdVarTestName					= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_strRptProdVarTestName')					, 'ProductionCNT')	
	SELECT	@intUseRptRunTime						= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intUseRptRunTime')						, 0)				
	SELECT	@intEnableVirtualZero					= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intEnableVirtualZero')					, 0)				
	SELECT	@intRptSampleLessThanMINSampleCOUNTPQM	= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intRptSampleLessThanMINSampleCOUNTPQM')	, 20)				
	SELECT	@intRptSampleLessThanMINSampleCOUNTATT	= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intRptSampleLessThanMINSampleCOUNTATT')	, 20)				
	SELECT	@intRptSampleLessThanMINReportingDays	= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intRptSampleLessThanMINReportingDays')	, 2)				
	SELECT	@intRptUseLocalPGLineStatusTable		= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intRptUseLocalPGLineStatusTable')			, 1)				
	SELECT	@intRptPrecision						= ISNULL([OpsDataStore].[dbo].[fnRptGetParameterValue] (@ReportName,'Local_PG_intRptPrecision')							, 2)				

	SET	@intRptWithDataValidationExtended		= @p_intRptWithDataValidationExtended		
	SET	@vchRptVariableExclusionPrefix			= @p_vchRptVariableExclusionPrefix				
	SET	@intRptPercentConfidenceAnalysis		= @p_intRptPercentConfidenceAnalysis			
	SET	@intRptPercentConfidencePercent			= @p_intRptPercentConfidencePercent			
	SET	@vchRptCriticality						= @p_vchRptCriticality				
-----------------------------------------------------------------------------------------------------------------------
-- Parameters from Filters Page
-----------------------------------------------------------------------------------------------------------------------	
	SET		@vchRptPLIdList							= ISNULL(@p_vchRptPLIdList,@vchRptPLIdList)
	SET		@vchRptProdIdList						= ISNULL(@p_vchRptProdIdList,@vchRptProdIdList)
	SET		@vchRptPUIdList							= ISNULL(@p_vchRptPUIdList,@vchRptPUIdList)
	SET		@intTimeOption							= @p_vchRptTimeOption
	SET		@vchRptCrewDescList						= @p_vchRptTeamList
	SET		@vchRptShiftDescList					= @p_vchRptShiftList
	SET		@vchRptPLStatusIdList					= @p_vchRptLineStatusList
	SET		@vchRptMajorGroupBy						= @p_vchRptMajorGroup
	SET		@vchRptMinorGroupBy						= @p_vchRptMinorGroup
	SET		@intRptWeightSpecChanges				= @p_vchRptWeightSpecs
	SET		@intRptWithDataValidation				= @p_vchRptDataValidation
	SET		@intRptVariableVisibility				= @p_vchRptVisibility
	SET		@intRptSampleLessThanAdjustment			= @p_vchRptHistorical
	SET		@intUseRptGenealogy						= @p_vchRptGenealogy
	
	--This is for emulating truncate made by spCmn_GetReportParameterValue on legacy excel reports
	SET		@vchRptSortOrderVarIdList				= SUBSTRING(@p_vchRptVarIdList,0,4001)
	SET		@vchRptProductGrpIdList					= SUBSTRING(ISNULL(@p_vchRptProductGrpIdList,@vchRptProductGrpIdList),0,4001)
						

-------------------------------------------------------------------------------------------------------------------
-- Time Options
-------------------------------------------------------------------------------------------------------------------
	SELECT @vchTimeOption = CASE @intTimeOption
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
		SELECT	@p_vchRptStartDateTime = dtmStartTime ,
				@p_vchRptEndDateTime = dtmEndTime
		FROM [dbo].[fnLocal_RptStartEndTime](@vchTimeOption)

	END

-------------------------------------------------------------------------------------------------------------------
-- UPDATE local table and get production line description
-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListPLFilter	(
				PLId	,
				PLDesc	)
	SELECT		tt.ValueINT,
				pl.PL_Desc
	FROM	#TempTable	tt
		JOIN	dbo.Prod_Lines_Base	pl WITH(NOLOCK)	ON	tt.ValueINT = pl.PL_Id
	ORDER BY 	pl.PL_Desc	-- so production line filter shows up in alphabetical order on the report header										
														
	--SELECT
	--		@intRptOwnerId						  	'intRptOwnerId'								,
	--		@intRptWithDataValidation			  	'intRptWithDataValidation',
	--		@intRptWithDataValidationExtended	  	'intRptWithDataValidationExtended'				,
	--		@intTimeOption						  	'TimeOption'								,
	--		@intRptVariableVisibility			  	'Local_PG_intRptNormalizedPPMVariableVisibility',
	--		@intRptVariableVisibility			  	'intRptVariableVisibility',
	--		@vchRptTitle							'strRptTitle', 
	--		@vchRptPLIdList						  	'strRptPLIdList',
	--		@vchRptProdIdList					  	'strRptProdIdList',
	--		@vchRptProductGrpIdList				  	'strRptProductGrpIdList',
	--		@vchRptPUIdList						  	'strRptPUIdList',
	--		@vchRptSortOrderVarIdList			  	'strRptSortOrderVarIdList',
	--		@vchRptVariableExclusionPrefix		  	'Local_PG_strRptVariableExclusionPrefix',
	--		@vchRptCrewDescList					  	'Local_PG_strTeamsByName',
	--		@vchRptShiftDescList					'Local_PG_strShifts1', 
	--		@vchRptPLStatusIdList				  	'Local_PG_strLineStatusId1',
	--		@dtmRptShiftStart					  	'Local_PG_StartShift',
	--		@intRptShiftLength					  	'Local_PG_ShiftLength',
	--		@vchRptMajorGroupBy					  	'Local_PG_strRptNormalizedPPMMajorGroupBy',
	--		@vchRptMinorGroupBy					  	'Local_PG_strRptNormalizedPPMMinorGroupBy',
	--		@vchRptProdVarTestName				  	'Local_PG_strRptProdVarTestName',
	--		@intRptWeightSpecChanges				'Local_PG_intRptNormalizedPPMWeightSpecChanges', 
	--		@intRptWeightSpecChanges				'intRptWeightSpecChanges', 
	--		@intRptPercentConfidenceAnalysis		'Local_PG_intRptPercentConfidenceAnalysis', 
	--		@intRptPercentConfidencePercent		  	'Local_PG_intRptPercentConfidencePercent',
	--		@intRptSampleLessThanAdjustment		  	'Local_PG_intRptSampleLessThanAdjustment',
	--		@intRptSampleLessThanMINSampleCOUNTPQM 	'Local_PG_intRptSampleLessThanMINSampleCOUNTPQM',
	--		@intRptSampleLessThanMINSampleCOUNTATT 	'Local_PG_intRptSampleLessThanMINSampleCOUNTATT',
	--		@intRptSampleLessThanMINReportingDays  	'Local_PG_intRptSampleLessThanMINReportingDays',
	--		@intRptUseLocalPGLineStatusTable		'Local_PG_intRptUseLocalPGLineStatusTable', 
	--		@vchRptCriticality					  	'Local_PG_strRptCriticality',
	--		@intRptPrecision						'Local_PG_intRptPrecision', 
	--		@intUseRptRunTime					  	'Local_PG_intUseRptRunTime',
	--		@intUseRptGenealogy					  	'Local_PG_intEnableGenealogy',
	--		@intEnableVirtualZero				  	'Local_PG_intEnableVirtualZero'


-----------------------------------------------------------------------------------------------------------
-- Search Version in AppVersions and Report_types
-----------------------------------------------------------------------------------------------------------
SET @vchSP_name	= 'spLocal_RptPPMVAS'
SET @vchRT_xlt	= 'LocalRptNormPPM40.xlt'
-----------------------------------------------------------------------------------------------------------
-- Search Version in AppVersions
-----------------------------------------------------------------------------------------------------------
SELECT @vchAppVersion = App_Version FROM AppVersions WHERE app_name like '%' + @vchSP_name + '%'
-----------------------------------------------------------------------------------------------------------
-- Search Version in Report_Types
-----------------------------------------------------------------------------------------------------------
SELECT @vchRTVersion = version FROM report_types WHERE template_path like '%' + @vchRT_xlt + '%'

-----------------------------------------------------------------------------------------------------------------------
--	Get the Start Time and End Time from the Time Option to avoid issued with Report_Relative_Dates table
--  Just do it for Baby Care sites.
-----------------------------------------------------------------------------------------------------------------------

-- FROM TESTING PURPOSES ON 2010-JAN-31 @intRptWithDataValidationExtended WILL BE ALWAYS TRUE ON THIS SP
-- SET @intRptWithDataValidation = 1
-- SET @intRptWithDataValidationExtended = 1

-- Those parameters @intRptWithDataValidation and @intRptWithDataValidationExtended work together
IF @intRptWithDataValidation = 0 
BEGIN
	SET @intRptWithDataValidationExtended = 0
END

-- If the Virtual Zero option is enabled then the have to look back for 6000 Attributes samples
IF @intEnableVirtualZero = 1
BEGIN
	SET @intRptSampleLessThanMINSampleCOUNTATT = 6000
END
-----------------------------------------------------------------------------------------------------------------------
--	Get the Start Time and End Time from the Time Option to avoid issued with Report_Relative_Dates table
--  Just do it for Baby Care sites.
-----------------------------------------------------------------------------------------------------------------------
-- SELECT '@intEnableVirtualZero',@intEnableVirtualZero

IF @intUseRptRunTime = 1 

BEGIN

			INSERT INTO #Local_PG_StartEndTime (
						rptStartTime,
						rptEndTime				)
			EXEC dbo.spLocal_RptRunTime @intTimeOption,@intRptShiftLength ,@dtmRptShiftStart,@p_vchRptStartDateTime,@p_vchRptEndDateTime
			
			SELECT   	@p_vchRptStartDateTime 	= CONVERT(DATETIME,rptStartTime)		,
						@p_vchRptEndDateTime	= CONVERT(DATETIME,rptEndTime)
			FROM 		#Local_PG_StartEndTime
			
END
-----------------------------------------------------------------------------------------------------------------------
--	Calculate the Reporting Period
-----------------------------------------------------------------------------------------------------------------------
SET @intRptReportingPeriod = DATEDIFF (dd,@p_vchRptStartDateTime,@p_vchRptEndDateTime)
-----------------------------------------------------------------------------------------------------------------------
--	Note: IF RptLayoutOption = VASReport THEN MajorGroup = MinorGroup
-----------------------------------------------------------------------------------------------------------------------

IF	@p_vchRptLayoutOption = 'VASReport'
BEGIN
	--EXEC	spCmn_GetReportParameterValue 	@p_vchRptName, 'Local_PG_strRptVariableStatisticMajorGroupBy'	, 'None', @vchRptMajorGroupBy OUTPUT
	---- EXEC	spCmn_GetReportParameterValue 	@p_vchRptName, 'intRptVariableVisibility'						, 0		, @intRptVariableVisibility OUTPUT
	---- FO-00863 : Make sure all VASReport and NormPPM report layout uses the same parameter for Variable Visibility.
	--EXEC	spCmn_GetReportParameterValue 	@p_vchRptName, 'Local_PG_intRptNormalizedPPMVariableVisibility'	, 1						, @intRptVariableVisibility OUTPUT
	-------------------------------------------------------------------------------------------------------------------
	--	Default major group to 'PLId|ProductGrpId'
	-------------------------------------------------------------------------------------------------------------------
	IF	LEN(COALESCE(@vchRptMajorGroupBy, '')) = 0
	BEGIN
		SET	@vchRptMajorGroupBy = 'PLId|ProductGrpId'	
	END
	-------------------------------------------------------------------------------------------------------------------
	--	Make major group = Minor group
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchRptMinorGroupBy = @vchRptMajorGroupBy
END

-----------------------------------------------------------------------------------------------------------------------
-- CHECK report parameters
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT 	'	-->	RptName: ' 								+ COALESCE(@p_vchRptName, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptStartDateTime: ' 					+ COALESCE(@p_vchRptStartDateTime, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptEndDateTime: ' 						+ COALESCE(@p_vchRptEndDateTime, '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptOwnerId: ' 							+ CONVERT(VARCHAR(25), @intRptOwnerId)
IF @intPRINTFlag = 1	PRINT	'	-->	RptWithDataValidation: ' 				+ COALESCE(CONVERT(VARCHAR(25), @intRptWithDataValidation), '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptWithDataValidationExtended: ' 		+ COALESCE(CONVERT(VARCHAR(25), @intRptWithDataValidationExtended), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptVariableVisibility: ' 				+ COALESCE(CONVERT(VARCHAR(25), @intRptVariableVisibility), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptWeightSpecChanges: ' 				+ COALESCE(CONVERT(VARCHAR(25), @intRptWeightSpecChanges), '')
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT 	'	-->	RptTitle: ' 							+ COALESCE(@vchRptTitle, '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptPLIdList: ' 							+ COALESCE(@vchRptPLIdList, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptProdIdList: ' 						+ COALESCE(@vchRptProdIdList, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptProductGrpIdList: ' 					+ COALESCE(@vchRptProductGrpIdList, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptPUIdList: ' 							+ COALESCE(@vchRptPUIdList, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptSortOrderVarIdList: ' 				+ COALESCE(@vchRptSortOrderVarIdList, '')
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT 	'	-->	RptVariableExclusionPrefix: ' 			+ COALESCE(@vchRptVariableExclusionPrefix, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptCrewDescList: ' 						+ COALESCE(@vchRptCrewDescList, '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptShiftDescList: ' 					+ COALESCE(@vchRptShiftDescList, '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptPLStatusIdList: '					+ COALESCE(@vchRptPLStatusIdList, '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptshiftStart: ' 						+ CONVERT(VARCHAR(25), COALESCE(@dtmRptShiftStart, ''), 120)
IF @intPRINTFlag = 1	PRINT	'	-->	RptShiftLength: ' 						+ CONVERT(VARCHAR(25), COALESCE(@intRptShiftLength, ''))
IF @intPRINTFlag = 1	PRINT	'	-->	RptMajorGroupBy: ' 						+ COALESCE(@vchRptMajorGroupBy, '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptMinorGroupBy: ' 						+ COALESCE(@vchRptMinorGroupBy, '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptProdVarTestName: ' 					+ COALESCE(@vchRptProdVarTestName, '')
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT 	'	-->	RptWeightSpecChanges: '					+ COALESCE(CONVERT(VARCHAR(25), @intRptWeightSpecChanges), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptPercentConfidenceAnalysis: '			+ COALESCE(CONVERT(VARCHAR(25), @intRptPercentConfidenceAnalysis), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptPercentConfidencePercent: ' 			+ COALESCE(CONVERT(VARCHAR(25), @intRptPercentConfidencePercent), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptSampleLessThanAdjustment: ' 			+ COALESCE(CONVERT(VARCHAR(25), @intRptSampleLessThanAdjustment), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptSampleLessThanMINSampleCOUNTPQM: ' 	+ COALESCE(CONVERT(VARCHAR(25), @intRptSampleLessThanMINSampleCOUNTPQM), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptSampleLessThanMINSampleCOUNTATT: ' 	+ COALESCE(CONVERT(VARCHAR(25), @intRptSampleLessThanMINSampleCOUNTATT), '')
IF @intPRINTFlag = 1	PRINT 	'	-->	RptSampleLessThanMINReportingDays: ' 	+ COALESCE(CONVERT(VARCHAR(25), @intRptSampleLessThanMINReportingDays), '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptCriticality: '						+ COALESCE(CONVERT(VARCHAR(25), @vchRptCriticality), '')
IF @intPRINTFlag = 1	PRINT	'	-->	RptPrecision: '							+ COALESCE(CONVERT(VARCHAR(25), @intRptPrecision), '')

-- OBSOLETE parameters:
-- IF @intPRINTFlag = 1	PRINT	'	-->	RptPUSearchStrQuality: ' 				+ COALESCE(@vchRptPUSearchStrQuality, '')				OBSOLETE: variables have been re-organized in the plant model
-- IF @intPRINTFlag = 1	PRINT	'	-->	RptPUSearchStrProduction: ' 			+ COALESCE(@vchRptPUSearchStrProduction, '')			OBSOLETE: production variable is now under each PU
-- IF @intPRINTFlag = 1	PRINT 	'	-->	RptDefaultPUGDescList: ' 				+ COALESCE(@vchRptDefaultPUGDescList, '')				OBSOLETE: replaced by a UDP
-- IF @intPRINTFlag = 1	PRINT 	'	-->	RptMeasureableAttributesPUGDescList: ' 	+ COALESCE(@vchRptMeasurableAttributesPUGDescList, '') 	OBSOLETE: replaced by a UDP
-- IF @intPRINTFlag = 1	PRINT 	'	-->	RptVolumnWeightOption: ' 				+ COALESCE(CONVERT(VARCHAR(25), @intRptVolumeWeightOption), '')
-- IF @intPRINTFlag = 1	PRINT 	'	-->	RptUseLocalPGLineStatusTable: ' 		+ COALESCE(CONVERT(VARCHAR(25), @intRptUseLocalPGLineStatusTable), '')
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VALIDATE Report Parameters Values'
--=====================================================================================================================
--	VALIDATE Report Parameters Value
-----------------------------------------------------------------------------------------------------------------------
--	GET	Report Owner user name from dbo.Users_Base table
--	Report owner is the person responsible for the content of the report
--	i.e. the person who people call when that data looks wrong
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchRptOwnerDesc = UserName
FROM	dbo.Users_Base	WITH (NOLOCK)
WHERE	User_Id = @intRptOwnerId
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Production Line
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptPLIdList = '!NULL'
BEGIN	
	SET	@vchRptPLIdList = ''
END
ELSE
BEGIN
	SET	@vchRptPLIdList	= COALESCE(@vchRptPLIdList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Product
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptProdIdList = '!NULL'
BEGIN
	SET	@vchRptProdIdList = ''
END
ELSE
BEGIN
	SET	@vchRptProdIdList = COALESCE(@vchRptProdIdList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Product Group
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptProductGrpIdList = '!NULL'
BEGIN
	SET	@vchRptProductGrpIdList = ''
END
ELSE
BEGIN
	SET	@vchRptProductGrpIdList = COALESCE(@vchRptProductGrpIdList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Product UDP's
-----------------------------------------------------------------------------------------------------------------------
-- TODO
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Production Unit
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptPUIdList = '!NULL' OR LEN(RTRIM(LTRIM(@vchRptPUIdList))) = 0
BEGIN
	SET	@vchRptPUIdList = ''
END
ELSE
BEGIN
	SET	@vchRptPUIdList	= COALESCE(@vchRptPUIdList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Data Source Selection (Variables)
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptSortOrderVarIdList = '!NULL'
BEGIN
	SET	@vchRptSortOrderVarIdList = ''
END
ELSE
BEGIN
	SET	@vchRptSortOrderVarIdList	= COALESCE(@vchRptSortOrderVarIdList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Crew
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptCrewDescList = 'All'
BEGIN
	SET	@vchRptCrewDescList = ''
END
ELSE
BEGIN
	SET	@vchRptCrewDescList	= COALESCE(@vchRptCrewDescList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Shift
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptShiftDescList = 'All'
BEGIN
	SET	@vchRptShiftDescList = ''
END
ELSE
BEGIN
	SET	@vchRptShiftDescList	= COALESCE(@vchRptShiftDescList, '')
END
-----------------------------------------------------------------------------------------------------------------------
-- FILTER: Line Status
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptPLStatusIdList = 'All'
BEGIN
	SET	@vchRptPLStatusIdList = ''
END
ELSE
BEGIN
	SET	@vchRptPLStatusIdList	= COALESCE(@vchRptPLStatusIdList, '')
END
-----------------------------------------------------------------------------------------------------------------------
--	INITIALIZE FILTER CRITERIA
--	Note: this table is used show the user the filter conditions that where in placed when an error was trapped
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: strRptPLIdList'							, 'ReportParameterValue: ' + @vchRptPLIdList
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: strRptProdIdList'						, 'ReportParameterValue: ' + @vchRptProdIdList	
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: strRptProductGrpIdList'					, 'ReportParameterValue: ' + @vchRptProductGrpIdList	

INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: strRptPUIdList'							, 'ReportParameterValue: ' + @vchRptPUIdList
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: strRptSortOrderVarIdList'				, 'ReportParameterValue: ' + @vchRptSortOrderVarIdList 
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: Local_PG_strRptVariableExclusionPrefix'	, 'ReportParameterValue: ' + @vchRptVariableExclusionPrefix 
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: Local_PG_strTeamsByName'					, 'ReportParameterValue: ' + @vchRptCrewDescList
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: Local_PG_strShifts1'						, 'ReportParameterValue: ' + @vchRptShiftDescList 
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: Local_PG_strLineStatusId1'				, 'ReportParameterValue: ' + @vchRptPLStatusIdList  
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: Local_PG_strRptProdVarTestName'			, 'ReportParameterValue: ' + @vchRptProdVarTestName 
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: Start_Date'								, 'ReportParameterValue: ' + @p_vchRptStartDateTime
INSERT INTO	@tblErrorCriteria(ErrorCategory, Comment1, Comment2)	SELECT	'Report Filter', 'ReportParameter: End_Date'								, 'ReportParameterValue: ' + @p_vchRptEndDateTime		
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INITIALIZE ChiSquare Look-Up tables'
--=====================================================================================================================
--	INITIALIZE ChiSquare Look-Up tables
-----------------------------------------------------------------------------------------------------------------------
-- Note: the critical values were obtained by using the CHIINV(Probability, DegOfFreedom) function 
-- in Excel. With the probability = 0.05 (95% confidence)
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptPercentConfidencePercent = 95
BEGIN
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	1	, 	3.841459149)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	2	, 	5.991464547)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	3	, 	7.814727764)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	4	, 	9.487729037)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	5	,	11.07049775)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	6	, 	12.59158724)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	7	, 	14.06714043)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	8	, 	15.50731306)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	9	, 	16.91897762)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	10	, 	18.30703805)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	11	, 	19.67513757)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	12	, 	21.02606982)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	13	, 	22.3620325)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	14	, 	23.68479131)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	15	, 	24.99579013)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	16	, 	26.29622761)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	17	, 	27.58711164)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	18	, 	28.86929943)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	19	, 	30.14352721)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	20	, 	31.41043286)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	21	, 	32.67057337)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	22	, 	33.92443852)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	23	, 	35.17246163)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	24	, 	36.4150285)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	25	, 	37.65248413)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	26	, 	38.88513865)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	27	, 	40.11327205)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	28	, 	41.33713813)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	29	, 	42.55696777)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	30	, 	43.77297178)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	31	, 	44.98534322)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	32	, 	46.19425944)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	33	, 	47.39988381)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	34	, 	48.60236738)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	35	, 	49.80184958)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	36	, 	50.99846018)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	37	, 	52.19231975)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	38	, 	53.38354065)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	39	, 	54.5722278)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	40	, 	55.75847932)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	41	, 	56.9423872)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	42	, 	58.12403775)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	43	, 	59.3035121)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	44	, 	60.48088667)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	45	, 	61.65623348)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	46	, 	62.82962054)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	47	, 	64.00111212)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	48	, 	65.17076907)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	49	, 	66.33864905)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	50	, 	67.50480652)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	51	, 	68.66929388)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	52	, 	69.83216031)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	53	, 	70.99345279)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	54	, 	72.15321612)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	55	, 	73.31149298)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	56	, 	74.4683241)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	57	, 	75.6237484)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	58	, 	76.77780308)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	59	, 	77.93052372)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	60	, 	79.08194439)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	61	, 	80.23209774)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	62	, 	81.38101507)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	63	, 	82.52872641)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	64	, 	83.6752606)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	65	, 	84.82064534)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	66	, 	85.96490727)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	67	, 	87.108072)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	68	, 	88.25016421)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	69	, 	89.39120764)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	70	, 	90.53122518)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	71	, 	91.6702389)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	72	, 	92.80827009)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	73	, 	93.94533966)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	74	, 	95.08146673)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	75	, 	96.21667082)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	76	, 	97.35097045)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	77	, 	98.48438354)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	78	, 	99.61692741)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	79	, 	100.7486188)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	80	, 	101.8794741)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	81	, 	103.0095088)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	82	, 	104.1387383)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	83	, 	105.2671774)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	84	, 	106.3948404)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	85	, 	107.5217411)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	86	, 	108.6478931)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	87	, 	109.7733095)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	88	, 	110.898003)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	89	, 	112.0219859)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	90	, 	113.1452703)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	91	, 	114.2678679)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	92	, 	115.3897899)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	93	, 	116.5110475)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	94	, 	117.6316514)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	95	, 	118.751612)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	96	, 	119.8709396)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	97	, 	120.989644)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	98	, 	122.1077349)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	99	, 	123.2252218)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	100	, 	124.3421137)
END
-----------------------------------------------------------------------------------------------------------------------
-- Note: the critical values were obtained by using the CHIINV(Probability, DegOfFreedom) function 
-- in Excel. With the probability = 0.20 (80% confidence)
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptPercentConfidencePercent = 80
BEGIN
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	1	, 	1.642375062)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	2	, 	3.218875825)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	3	, 	4.641627502)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	4	, 	5.988616694)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	5	,	7.289276183)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	6	, 	8.558059721)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	7	, 	9.803249854)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	8	, 	11.03009143)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	9	, 	12.24214549)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	10	, 	13.441957585)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	11	, 	14.63142049)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	12	, 	15.81198622)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	13	, 	16.98479702)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	14	, 	18.15077056)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	15	, 	19.31065711)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	16	, 	20.46507929)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	17	, 	21.61456054)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	18	, 	22.75954582)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	19	, 	23.90041722)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	20	, 	25.03750563)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	21	, 	26.17109991)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	22	, 	27.30145403)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	23	, 	28.42879253)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	24	, 	29.55331525)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	25	, 	30.67520091)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	26	, 	31.79461015)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	27	, 	32.91168775)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	28	, 	34.02656523)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	29	, 	35.1393618)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	30	, 	36.25018677)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	31	, 	37.35913986)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	32	, 	38.46631278)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	33	, 	39.57178996)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	34	, 	40.67564938)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	35	, 	41.77796322)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	36	, 	42.87879847)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	37	, 	43.97821737)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	38	, 	45.07627797)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	39	, 	46.1730347)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	40	, 	47.26853774)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	41	, 	48.36283478)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	42	, 	49.45597036)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	43	, 	50.54798635)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	44	, 	51.63892217)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	45	, 	52.72881496)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	46	, 	53.81769981)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	47	, 	54.90560987)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	48	, 	55.99257651)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	49	, 	57.07862945)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	50	, 	58.16379654)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	51	, 	59.2481052)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	52	, 	60.33158059)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	53	, 	61.41424693)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	54	, 	62.49612729)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	55	, 	63.57724367)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	56	, 	64.65761705)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	57	, 	65.73726747)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	58	, 	66.8162141)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	59	, 	67.89447526)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	60	, 	68.97206851)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	61	, 	70.04901064)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	62	, 	71.12531778)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	63	, 	72.20100539)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	64	, 	73.27608878)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	65	, 	74.35058134)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	66	, 	75.4244972)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	67	, 	76.49784953)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	68	, 	77.57065104)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	69	, 	78.64291394)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	70	, 	79.71465002)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	71	, 	80.78587063)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	72	, 	81.85658672)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	73	, 	82.92680886)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	74	, 	83.99654726)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	75	, 	85.065811782)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	76	, 	86.13461195)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	77	, 	87.20295699)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	78	, 	88.2708558)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	79	, 	89.33831701)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	80	, 	90.40534898)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	81	, 	91.4719598)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	82	, 	92.53815665)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	83	, 	93.60394836)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	84	, 	94.66934173)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	85	, 	95.73434389)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	86	, 	96.79896178)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	87	, 	97.86320214)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	88	, 	98.92707151)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	89	, 	99.99057624)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	90	, 	101.05372253)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	91	, 	102.1165163)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	92	, 	103.17896359)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	93	, 	104.2410697)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	94	, 	105.3028405)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	95	, 	106.3642812)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	96	, 	107.4253971)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	97	, 	108.4861933)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	98	, 	109.5466748)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	99	, 	110.6068463)
	INSERT INTO	@tblChiSquareCriticalValues (DegOfFreedom,	ChiSquareCriticalValue)	VALUES (	100	, 	111.6667126)
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INSERT Met Criteria Formulas into Look-up table (#MCFormulaLookUp)'
--=====================================================================================================================
--	INSERT Met Criteria Formulas into Look-up table (#MCFormulaLookUp)
-----------------------------------------------------------------------------------------------------------------------
-- Prepare Tables: formula look-up
-----------------------------------------------------------------------------------------------------------------------
SELECT	@i = 1
WHILE	@i <= 13
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Initialize variables
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	SELECT	@nvchSQLCommand2 = ''
	-------------------------------------------------------------------------------------------------------------------
	-- 	Add formulas to temp table
	-------------------------------------------------------------------------------------------------------------------
	IF	@i = 1
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 1
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	1	1		0				1
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT	1, 1, 1, 0, 1, '
										+				'''CASE 	WHEN	(CONVERT(DECIMAL(20,10), USL) - CONVERT(DECIMAL(20,10), LSL)) > 0 '
										+				'			THEN	(6 * TestStDev)/(CONVERT(DECIMAL(20,10), USL) - CONVERT(DECIMAL(20,10), CONVERT(DECIMAL(20, 10), LSL))) '
										+				'			WHEN	(CONVERT(DECIMAL(20,10), USL) - CONVERT(DECIMAL(20,10), LSL)) = 0 AND TestStDev = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE 	WHEN 	TestAvg <= (CONVERT(FLOAT, Target) + (0.042 * (CONVERT(DECIMAL(20,10), USL) - CONVERT(DECIMAL(20, 10), LSL)))) AND TestAvg >= (CONVERT(DECIMAL(20, 10), Target) - (0.042 * (CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), LSL)))) '
										+				'			THEN 	0 '
										+				'			WHEN	TestAvg > (CONVERT(FLOAT, Target) + (0.042 * (CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), LSL)))) '
										+				'			THEN	1 ' 
										+				'			ELSE 	-1 '
										+				'	END'', '
										+				'''CASE	WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(FLOAT, Target))/TestStDev '
										+				'			WHEN	(TestAvg - CONVERT(FLOAT, Target)) = 0 AND	TestStDev = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	Null, '
										+				'''CASE 	WHEN 	Cr <= 0.75 '
										+				'			THEN 	1 ' 
										+				'			WHEN	InfinityFlagCr = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 ' 
										+				'	END'', '
										+				'''CASE 	WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 ' 
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 ' 
										+				'	END '', '
										+				'	1, '
										+				'''CASE 	WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'	     					THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'		 					ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0	AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0	AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE		WHEN	(CONVERT(DECIMAL(20,10), USL) - CONVERT(DECIMAL(20,10), LSL)) = 0 AND TestStDev > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0 '
	END
	ELSE	IF	@i = 2
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 2
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	1	1		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 1, 1, 0, 0, '
										+				'	Null, '
										+				'''CASE		WHEN	TestStDev > 0.00 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20,10), Target))/ TestStDev '
										+				'			WHEN	(CONVERT(DECIMAL(20,10),TestStDev)) = 0 AND (CONVERT(DECIMAL(20,10),TestAvg) - CONVERT(DECIMAL(20,10), Target)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0.00 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20,10), Target))/CONVERT(DECIMAL(20,10),TestStDev) '
										+				'			WHEN	(CONVERT(DECIMAL(20,10),TestStDev)) = 0 AND (TestAvg - CONVERT(DECIMAL(20,10), Target)) = 0 '
										+				'			THEN	0 '
										+				'		ELSE	0 '
										+				'	END'', '
										+				'''CASE 	WHEN	TestStDev > 0.00 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'	     					THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'		 					ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'		ELSE	0 '
										+				'	END'', '
										+				'	1, '
										+				'''CASE		WHEN Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 ' 
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE 	0 '
										+				'	END'', '
										+				'''CASE		WHEN	Cpk >= 1.33 ' 
										+				'			THEN	1 ' 
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN 	1 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE 	WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'	     					THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'		 					ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	0,	'
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				'''CASE		WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 3
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 3
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	0	1		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 0, 1, 0, 0, '
										+				'''CASE		WHEN	(CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	(3 * TestStDev)/(CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)) '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE 	WHEN 	TestAvg <= (CONVERT(FLOAT, Target) + (0.084 * (CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)))) AND TestAvg >= (CONVERT(FLOAT, Target) - (0.084 * (CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)))) '
										+				'			THEN 	0 '
										+				'			WHEN	TestAvg > (Target + (0.084 * (CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)))) '
										+				'			THEN	1 ' 
										+				'			ELSE 	-1 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(FLOAT, Target))/TestStDev '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN 	0 '
										+				'	END'', '
										+				'	Null, '
										+				'''CASE		WHEN	Cr <= 0.75 ' 
										+				'			THEN	1 ' 
										+				'			WHEN	InfinityFlagCr = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'	1, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(CONVERT(DECIMAL(20, 10), USL) - TestAvg)/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND	(CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE		WHEN	(CONVERT(DECIMAL(20, 10), USL) - CONVERT(FLOAT, Target)) = 0 AND TestStDev > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0 '
	END
	ELSE	IF	@i = 4
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 4
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	0	1	1		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	0, 1, 1, 0, 0, '
										+				'''CASE		WHEN	(CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)) > 0'
										+				'			THEN	(3 * TestStDev)/(CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)) '
										+				'			WHEN	TestStDev = 0 AND	(CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE 	WHEN 	TestAvg <= (CONVERT(FLOAT, Target) + (0.084 * (CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)))) AND TestAvg >= (CONVERT(FLOAT, Target) - (0.084 * (CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)))) '
										+				'			THEN 	0 '
										+				'			WHEN	TestAvg > (CONVERT(FLOAT, Target) + (0.084 * (CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)))) '
										+				'			THEN	1 ' 
										+				'			ELSE 	-1 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(FLOAT, Target))/TestStDev '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	Null, '
										+				'''CASE		WHEN	Cr <= 0.75 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCr = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'			END'', '
										+				'1, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20, 10), LSL))/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'''CASE		WHEN	(CONVERT(FLOAT, Target) - CONVERT(DECIMAL(20, 10), LSL)) = 0 AND TestStDev > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0'
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0 '
	END
	ELSE	IF	@i = 5
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 5
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	0	0	1		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	0, 0, 1, 0, 0, '
										+				'	Null, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(FLOAT, Target))/TestStDev '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(FLOAT, Target))/TestStDev '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'	Null, '
										+				'	1, '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'			END'', '
										+				'	1, '
										+				'	Null, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(FLOAT, Target)) = 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '', '
										+				' 	0 '
	END
	ELSE	IF	@i = 6
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 6
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	0	0		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 0, 0, 0, 0, '
										+				'	Null, '
										+				'	Null, '
										+				'	Null, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(CONVERT(DECIMAL(20, 10), USL) - TestAvg)/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'	1, '
										+				'	1, '
										+				'''CASE 	WHEN 	Cpk >= 1.33 ' 
										+				'			THEN	1 ' 
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'			END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(CONVERT(DECIMAL(20, 10), USL) - TestAvg)/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 7
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 7
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	0	1	0		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	0, 1, 0, 0, 0, '
										+				'	Null, '
										+				'	Null, '
										+				'	Null, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20, 10), LSL))/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	1, '
										+				'	1, '
										+				'''CASE		WHEN	Cpk >= 1.33 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20, 10), LSL))/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 8
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 8
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	1	0		0				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 1, 0, 0, 0, '
										+				'	Null, '
										+				'	Null, '
										+				'	Null, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'							THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'							ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	1, '
										+				'	1, '
										+				'''CASE		WHEN	Cpk >= 1.33 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'			END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'							THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'							ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 9
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 9
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	1	0		1				1
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 1, 0, 1, 1, '
										+				'''CASE		WHEN	(CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), LSL)) > 0 '
										+				'			THEN	6 * TestStDev/(CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), LSL)) '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				' 	Null, '
										+				'''CASE		WHEN	Cr <= 0.75 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCr = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'',  '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'',  '
										+				'	1, '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'							THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'							ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'''CASE		WHEN	(CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), LSL)) = 0 AND TestStDev > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'	0, '
										+				'	0, '
										+				'	0 '
	END
	ELSE	IF	@i = 10
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 10
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	1	0		1				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 1, 0, 1, 0, '
										+				'	Null, '
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'							THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'							ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	1, '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'',  '
										+				'''CASE		WHEN	Cpk >= 1.33 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	CASE	WHEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) < ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'							THEN ((CONVERT(DECIMAL(20, 10), USL) - TestAvg) / (3 * TestStDev)) '
										+				'							ELSE ((TestAvg - CONVERT(DECIMAL(20, 10), LSL)) / (3 * TestStDev)) '
										+				'					END '
										+				'			WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (CONVERT(DECIMAL(20, 10), USL) - TestAvg) > 0 '
										+				'			THEN	1 '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 11
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 11
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	1	0	0		1				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	1, 0, 0, 1, 0, '
										+				'	Null, '
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(CONVERT(DECIMAL(20, 10), USL) - TestAvg)/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND	(CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	1, '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'',  '
										+				'''CASE		WHEN	Cpk >= 1.33 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(CONVERT(DECIMAL(20, 10), USL) - TestAvg)/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND	(CONVERT(DECIMAL(20, 10), USL) - TestAvg) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND	(CONVERT(DECIMAL(20, 10), USL) - TestAvg) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 12
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 12
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	0	1	0		1				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	0, 1, 0, 1, 0, '
										+				'	Null, '
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20, 10), LSL))/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'			END'', '
										+				'	1, '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'',  '
										+				'''CASE		WHEN	Cpk >= 1.33 '
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagCpk = 1 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END'', '
										+				'''CASE		WHEN	TestStDev > 0 '
										+				'			THEN	(TestAvg - CONVERT(DECIMAL(20, 10), LSL))/(3 * TestStDev) '
										+				'			WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) = 0 '
										+				'			THEN	0 '
										+				'	END'', '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'''CASE		WHEN	TestStDev = 0 AND (TestAvg - CONVERT(DECIMAL(20, 10), LSL)) > 0 '
										+				'			THEN	1 '
										+				'			ELSE	0 '
										+				'	END '' '
	END
	ELSE	IF	@i = 13
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Formula 13
		--	Business Rule for formula:
		--	USL	LSL	Target	MCTargetRange	SymetricSpecs
		--	0	0	0		1				0
		--	WHERE	1 = YES and 0 = NO
		---------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = 	'	SELECT 	0, 0, 0, 1, 0, '
										+				'	Null, '
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'''CASE		WHEN	TestAvg <= CONVERT(DECIMAL(20, 10), LTL) '
										+				'			THEN	-1	'
										+				'			WHEN	TestAvg >= CONVERT(DECIMAL(20, 10), UTL) '
										+				'			THEN	1 	'
										+				'			ELSE	0  '
										+				'	END'',	'
										+				'	Null, '
										+				'	1, '
										+				'''CASE		WHEN	Tz >= -0.5 AND Tz <= 0.5 ' 
										+				'			THEN	1 '
										+				'			WHEN	InfinityFlagTz = 1 '
										+				'			THEN	0 '
										+				'			ELSE	0 '
										+				'	END'',  '
										+				'	1, '
										+				'	Null, '
										+				'	0, '
										+				'	0, '
										+				'	0, '
										+				'  	0 '
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand = ''
	END
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE formula look-up table
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#MCFormulaLookUp 	(
				MCUSL,	
				MCLSL,	
				MCTarget	,	
				MCTargetRange,
				MCSymmetricSpecs,	
				Cr,	
				Tz1, 
				Tz2, 
				Cpk, 
				MCCr, 
				MCTz, 
				MCCpk,
				CalcCpk,
				InfinityFlagCr, 
				InfinityFlagTz1, 
				InfinityFlagTz2, 
				InfinityFlagCpk )
	EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT COUNTer
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@i = @i + 1
END
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET REPORT FILTERS'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
--=====================================================================================================================
--	GET Report Filters
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Production Lines'
--=====================================================================================================================
--	PRODUCTION LINE
--	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "FilterProdLines.asp"
--	Report Parameter: strRptPLIdList
--	Report Parameter Format: | delimited list of PL_Id's from the dbo.Prod_Lines_Base table
--	Default value is '!NULL' which means include ALL production lines
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptPLIdList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#TempTable (
				RcdId, 
				ValueINT)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptPLIdList,
			@PRMFieldDelimiter = NULL,
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'INT'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get production line description
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListPLFilter	(
				PLId	,
				PLDesc	)
	SELECT		tt.ValueINT,
				pl.PL_Desc
	FROM	#TempTable	tt
		JOIN	dbo.Prod_Lines_Base	pl WITH(NOLOCK)	ON	tt.ValueINT = pl.PL_Id
	ORDER BY 	pl.PL_Desc	-- so production line filter shows up in alphabetical order on the report header										
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Product Group'
--=====================================================================================================================
--	PRODUCT GROUP
--	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "FilterProductGroups.asp"
--	Report Parameter: strRptProductGrpIdList
--	Report Parameter Format: '|' delimited list of Prod_Id's from the dbo.Products_Base table
--	Default value is '!NULL' which means include ALL products
-----------------------------------------------------------------------------------------------------------------------

TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptProductGrpIdList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------

	INSERT INTO	#TempTable (
				RcdId, 
				ValueVCH50)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptProductGrpIdList,
			@PRMFieldDelimiter = NULL,
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'VARCHAR(50)'

	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get product group description
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListProductGroupsFilter	(
				ProductGrpId	,
				ProductGrpDesc	)
	SELECT	pg.Product_Grp_Id,
			tt.ValueVCH50
	FROM	#TempTable	tt
		JOIN	dbo.Product_Groups	pg	WITH(NOLOCK) ON	tt.ValueVCH50 = pg.Product_Grp_Desc
	ORDER BY	pg.Product_Grp_Desc	-- so product group filter shows up in alphabetical order on the report header

	-------------------------------------------------------------------------------------------------------------------
	-- GET all the products in the selected product groups
	-------------------------------------------------------------------------------------------------------------------
	IF	LEN(@vchRptProdIdList) = 0
	BEGIN
		INSERT INTO	@tblListProductFilter (
					ProductGrpId,
					ProdId		,
					ProdCode	)
		SELECT	flpg.ProductGrpId,
				pgd.Prod_Id,
				p.Prod_Code
		FROM	@tblListProductGroupsFilter	flpg
			JOIN	dbo.Product_Group_Data	pgd	WITH (NOLOCK)
												ON	flpg.ProductGrpId = pgd.Product_Grp_Id
			JOIN	dbo.Products_Base	p			WITH (NOLOCK)
												ON pgd.Prod_Id = p.Prod_Id
	END
END


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Product'
--=====================================================================================================================
--	PRODUCT
--	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "FilterProducts.asp"
--	Report Parameter: strRptProdIdList
--	Report Parameter Format: | delimited list of Prod_Id's from the dbo.Products_Base table
--	Default value is '!NULL' which means include ALL products
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptProdIdList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#TempTable (
				RcdId, 
				ValueINT)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptProdIdList,
			@PRMFieldDelimiter = NULL,
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'INT'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get production line description
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListProductFilter	(
				ProdId		,
				ProdCode	)
	SELECT		tt.ValueINT,
				p.Prod_Code
	FROM	#TempTable	tt
		JOIN	dbo.Products_Base	p	WITH (NOLOCK)
									ON	tt.ValueINT = p.Prod_Id
	ORDER BY 	p.Prod_Code	-- so production code filter shows up in alphabetical order on the report header
	-------------------------------------------------------------------------------------------------------------------
	--	UPDATE product group
	-------------------------------------------------------------------------------------------------------------------
	IF	EXISTS	(	SELECT	ProductGrpId
					FROM	@tblListProductGroupsFilter)
	BEGIN
		UPDATE	pf
			SET	ProductGrpId = Product_Grp_Id
		FROM	@tblListProductFilter		pf
		JOIN	dbo.Product_Group_Data		pgd	WITH (NOLOCK)
												ON	pf.ProdId = pgd.Prod_Id
		JOIN	@tblListProductGroupsFilter	pgf	ON	pgd.Product_Grp_Id = pgf.ProductGrpId
	END
	ELSE
	BEGIN
		UPDATE	pf
			SET	ProductGrpId = Product_Grp_Id
		FROM	@tblListProductFilter	pf
		JOIN	dbo.Product_Group_Data	pgd	WITH (NOLOCK)
											ON	pf.ProdId = pgd.Prod_Id
	END
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter Product UDPs (TODO ... NOT Defined Yet)'
--=====================================================================================================================
-----------------------------------------------------------------------------------------------------------------------
--	PRODUCT UDP'S
-- TO COME .... NOT DEFINED YET
-----------------------------------------------------------------------------------------------------------------------
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Production Unit'
--=====================================================================================================================
--	PRODUCTION UNIT
-- 	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "FilterProdUnits.asp"
--	Report Parameter: strRptPUIdList
--	Report Parameter Format: '|' delimited list of PU_Id's from the dbo.Prod_Units_Base table
--	Default value is '!NULL' which means include ALL Production Units
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptPUIdList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#TempTable (
				RcdId, 
				ValueINT)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptPUIdList,
			@PRMFieldDelimiter = NULL,
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'INT'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get production unit list
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListPUFilter	(
				PUId	)
	SELECT		tt.ValueINT
	FROM	#TempTable	tt
END

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Data Source Selection'
--=====================================================================================================================
--	DATA SOURCE SELECTION (User defined)
-- 	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "DataSourceSelection.asp"
--	Report Parameter: strRptSortOrderVarIdList
--	Report Parameter Format: SortOrder~VarId| e.g. 1~1234|2~4365|3~567...
--	Default value is '!NULL' which means include ALL products
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptSortOrderVarIdList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT	#TempTable (RcdId, SortOrder, ValueINT)
		EXEC	spCmn_ReportCollectionParsing
				@PRMCollectionString = @vchRptSortOrderVarIdList,
				@PRMFieldDelimiter = '~',
				@PRMRecordDelimiter = '|',
				@PRMDataType01 = 'INT',	
				@PRMDataType02 = 'INT'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get Variable list
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#ListDataSourceFilter (
				SortOrder	,
				VarId		,
				VarDesc		)
	SELECT	SortOrder,
			ValueINT,
			Var_Desc
	FROM	#TempTable 	tt
		JOIN	dbo.Variables_Base	v	WITH (NOLOCK)
									ON	tt.ValueINT = v.Var_Id
	WHERE	PU_Id > 0	-- deleted variables have PU_Id = 0
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Team'
--=====================================================================================================================
--	TEAM (User defined)
-- 	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "Local_PG_STLSelection.asp"
--	Report Parameter: Local_PG_strTeamsByName
--	Report Parameter Format: ',' delimited list of Crew_Desc's from the dbo.Crew_Schedule table
--	Default value is 'All' which means include ALL Crews
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptCrewDescList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT	#TempTable (RcdId, ValueVCH50)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptCrewDescList,
			@PRMFieldDelimiter = NULL,
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'VARCHAR(50)'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get Crew list
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListCrewFilter (
				CrewDesc)
	SELECT	ValueVCH50
	FROM	#TempTable 	tt
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Shift'
--=====================================================================================================================
--	SHIFT (User defined)
-- 	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "Local_PG_STLSelection.asp"
--	Report Parameter: Local_PG_strShifts1
--	Report Parameter Format: ',' delimited list of Shift_Desc's from the dbo.Crew_Schedule table
--	Default value is 'All' which means include ALL products
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptShiftDescList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT	#TempTable (RcdId, ValueVCH50)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptShiftDescList,
			@PRMFieldDelimiter = NULL,
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'VARCHAR(50)'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get Shift list
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListShiftFilter (
				ShiftDesc)
	SELECT	ValueVCH50
	FROM	#TempTable 	tt
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Filter - Line Status'
--=====================================================================================================================
--	Line Status (User defined)
-- 	Business Rule:
--	This is an optional parameter therefore it can be NULL
-- 	Web Page used to select Production Lines: "Local_PG_STLSelection.asp"
--	Report Parameter: Local_PG_strLineStatusId1
--	Report Parameter Format: LineStatusId^LineStatusDesc, ... 
-- 	Note: the line status desc comes from dbo.Phrases table
--	Default value is 'All' which means include ALL Line status
-----------------------------------------------------------------------------------------------------------------------
TRUNCATE TABLE	#TempTable
IF	LEN(@vchRptPLStatusIdList) > 0 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	-- PARSE string
	-------------------------------------------------------------------------------------------------------------------
	INSERT	#TempTable (RcdId, ValueINT, ValueVCH50)
	EXEC	spCmn_ReportCollectionParsing
			@PRMCollectionString = @vchRptPLStatusIdList,
			@PRMFieldDelimiter = '^',
			@PRMRecordDelimiter = '|',	
			@PRMDataType01 = 'INT',
			@PRMDataType02 = 'VARCHAR(50)'

	-------------------------------------------------------------------------------------------------------------------
	-- GET the data_type_id that will identify which phrases in the dbo.Phrase table correspond to a line status 
	-- description.
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intDataTypeId = Tree_Name_Id
	FROM	dbo.Event_Reason_Tree	WITH (NOLOCK)
	WHERE	Tree_Name = 'Non-Productive Time'
	-------------------------------------------------------------------------------------------------------------------
	-- UPDATE local table and get Variable list
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblListPLStatusFilter (
				PLStatusDesc 	,
				PLStatusDescSite,
				PLStatusId		)
	SELECT	ValueVCH50,
			r.Event_Reason_Name,
			r.Event_Reason_Id
	FROM	#TempTable	tt
		JOIN	dbo.Event_Reasons	r	WITH (NOLOCK)
								ON	tt.ValueINT = r.Event_Reason_Id
		JOIN	dbo.Event_Reason_Tree_Data d WITH (NOLOCK)
								ON	r.Event_Reason_Id = d.Event_Reason_Id
								AND d.Tree_Name_Id = @intDataTypeId	
						
	SELECT TOP 1 @vchLineNormalDesc = Event_Reason_Name 
	FROM	dbo.Event_Reasons r WITH (NOLOCK)
		JOIN	dbo.Event_Reason_Tree_Data d WITH (NOLOCK) 
								ON r.Event_Reason_Id = d.Event_Reason_Id
								AND d.Tree_Name_Id = @intDataTypeId
	WHERE	Event_Reason_Name LIKE '%PR%In%:%Line%Normal%'
END


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Production Unit when Filter in NULL'
--=====================================================================================================================
--	GET PRODUCTION UNITS
--	This section of code gets the list of production units that are valid for the report when the user has NOT selected
--	which production units to use.
--	a.	IF Production Unit Filter is NOT NULL return the Production Units selected by the user
--		>> DONT DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units
--	b. 	IF Production Line is selected but Production Unit IS NULL 
--		THEN return ALL Production Units that belong to the selected Production Lines 
--		AND	include the default Variable Groups
--      >> DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units
-- 		OR the Variables Selected
--		>> DONT DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units
--	c.	IF	Production Line is NULL
--		AND	Product IS NOT NULL
--		THEN return all production Units and Lines that made that product
--		>> DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units
--	d.	IF	Production Line is NULL
--		AND	Product Group IS NOT NULL
--		THEN return all Production Units and Lines that made the products in the product group
--		>> DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units
--	e.	IF Production Line IN NULL
--		AND Product IS NULL
--		AND Product Group NULL
--		AND	Default Variable Groups IS NOT NULL
--		THEN return all the Production Units and Lines that have the default variable groups
--		>> DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units
--	f.	IF Production Line IN NULL
--		AND Product IS NULL
--		AND Product Group NULL
--		AND	Data Source Selection IS NOT NULL
--		THEN return all the Production Units and Lines for that have the selected variables		
--		>> DONT DELETE UNITS NOT IN Active PrdExec_Path - > PrdExec_Path_Units	
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
--	a.	IF Production Unit Filter is NOT NULL return the Production Units selected by the user
-----------------------------------------------------------------------------------------------------------------------

IF	NOT EXISTS (	SELECT	RcdIdx	
					FROM	@tblListPUFilter)
BEGIN	
	-------------------------------------------------------------------------------------------------------------------
	--	b. 	IF Production Line is selected but Production Unit IS NULL 
	--		THEN return ALL Production Units that belong to the selected Production Lines 
	--		AND	include the default Variable Groups
	-- 		OR the Variables Selected
	-------------------------------------------------------------------------------------------------------------------
	IF	EXISTS	(	SELECT	RcdIdx
					FROM	@tblListPLFilter)
	BEGIN
		IF	EXISTS	(	SELECT	VarId
						FROM	#ListDataSourceFilter)
		BEGIN
	 		INSERT INTO	@tblListPUFilter (
						PLId,
	 					PUId,
						HoldSamples)
	 		SELECT	PL_Id,
					PU_Id,
					1
	 		FROM	dbo.Prod_Units_Base	pu				WITH (NOLOCK)	
	 			JOIN	@tblListPLFilter	lplf	ON	lplf.PLId = pu.PL_Id
		END
		ELSE
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
			------------------------------------------------------------------------------------------------------------	
			-- GET Production Units
			------------------------------------------------------------------------------------------------------------	
			INSERT INTO	@tblListPUFilter (
						PLId,
						PUId,
						HoldSamples)
			SELECT 	DISTINCT
					pu.PL_Id,
					pu.PU_Id,
					1
			FROM	dbo.Prod_Units_Base			pu		WITH (NOLOCK)	
	 			JOIN	@tblListPLFilter	lplf	ON	lplf.PLId = pu.PL_Id
				JOIN	dbo.PU_Groups		pg		WITH (NOLOCK)
													ON	pu.PU_Id = pg.PU_Id
				JOIN	dbo.Table_Fields_Values	tfv	WITH (NOLOCK)
													ON	tfv.KeyId = pg.PUG_Id
			WHERE	tfv.TableId = @intTableId
				AND	tfv.Table_Field_Id = @intTableFieldId
				AND	tfv.Value = 'Yes'
				AND	pg.PU_Id > 0

		END
	END
	ELSE
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	c.	IF	Production Line is NULL
		--		AND	Product OR Product Group IS NOT NULL
		--		THEN return all production Units and Lines that made that product
		---------------------------------------------------------------------------------------------------------------
		IF	EXISTS	(	SELECT	RcdIdx
						FROM	@tblListProductFilter)
		BEGIN
			INSERT INTO	@tblListPUFilter (
						PUId,
						PLId,
						HoldSamples)
			SELECT 	DISTINCT
					ps.PU_Id,
					PL_Id,
					1
			FROM	dbo.Production_Starts	ps		WITH (NOLOCK)	
				JOIN    dbo.Prod_Units_Base      pu      WITH (NOLOCK)
													ON  pu.PU_Id = ps.PU_Id
				JOIN	@tblListProductFilter	lpf	ON	lpf.ProdId = ps.Prod_Id
														AND	Start_Time <=	@p_vchRptEndDateTime
														AND	(End_Time >	@p_vchRptStartDateTime
															OR	End_Time IS NULL)
			WHERE	ps.PU_Id > 0
			-----------------------------------------------------------------------------------------------------------
			--	 GET the list of production lines to display on the report header
			-----------------------------------------------------------------------------------------------------------
			INSERT INTO	@tblListPLFilter	(
		 				PLId	,
		 				PLDesc	)
		 	SELECT	DISTINCT
					pl.PL_Id,
		 			pl.PL_Desc
		 	FROM	@tblListPUFilter	lpuf
				JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)
											ON	lpuf.PUId = pu.PU_Id
		 		JOIN	dbo.Prod_Lines_Base	pl	WITH (NOLOCK)
											ON	pl.PL_Id = pu.PL_Id
		 	ORDER BY 	pl.PL_Desc	-- so production line filter shows up in alphabetical order on the report header

		END
		ELSE
		BEGIN
			-----------------------------------------------------------------------------------------------------------
			--	e.	IF Production Line IS NULL
			--		AND Product IS NULL
			--		AND Product Group NULL
			--		AND	Default Variable Groups IS NOT NULL
			--		THEN return all the Production Units and Lines that have the default variable groups
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
			------------------------------------------------------------------------------------------------------------	
			-- GET Production Units
			------------------------------------------------------------------------------------------------------------	
			INSERT INTO	@tblListPUFilter (
						PLId,
						PUId,
						HoldSamples )
			SELECT 	DISTINCT
					pu.PL_Id,
					pu.PU_Id,
					1
			FROM	dbo.Prod_Units_Base			pu		WITH (NOLOCK)	
	 			JOIN	@tblListPLFilter	lplf	ON	lplf.PLId = pu.PL_Id
				JOIN	dbo.PU_Groups		pg		WITH (NOLOCK)
													ON	pu.PU_Id = pg.PU_Id
				JOIN	dbo.Table_Fields_Values	tfv	WITH (NOLOCK)
													ON	tfv.KeyId = pg.PUG_Id
			WHERE	tfv.TableId = @intTableId
				AND	tfv.Table_Field_Id = @intTableFieldId
				AND	tfv.Value = 'Yes'
				AND	pg.PU_Id > 0

		END
	END
END

------------------------------------------------------------------------------------------------------------	
-- As we are going to use the @tblListPLFilter for getting the active PrdExec_Path, we have to ensure that 
-- it is always populated.
------------------------------------------------------------------------------------------------------------	
IF NOT EXISTS ( SELECT * FROM @tblListPLFilter)
BEGIN
			INSERT INTO	@tblListPLFilter	(
		 				PLId		,
		 				PLDesc		)
		 	SELECT	DISTINCT
						pl.PL_Id	,
		 				pl.PL_Desc
		 	FROM	@tblListPUFilter	lpuf
				JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)
											ON	lpuf.PUId = pu.PU_Id
		 		JOIN	dbo.Prod_Lines_Base	pl	WITH (NOLOCK)
											ON	pl.PL_Id = pu.PL_Id
			WHERE pl.PL_Id NOT IN ( SELECT PLId FROM @tblListPLFilter)
		 	ORDER BY 	pl.PL_Desc	-- so production line filter shows up in alphabetical order on the report header
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Production Source'
--=====================================================================================================================
--	Business Rule:
--	Production variables will be under each production unit.
--	Production can come from two places:
--	a.	Event_Details.Initial_Dimension_X
--	b.	Variable
--	The Production_Type field in the dbo.Prod_Units_Base identifies the production source and the Production_Variable
--	field identifies the Production Variable Id when the Production Source is a Variable
--	If Production_Type = 1 Production comes from a variable
--	c. If production source has not been configured then test COUNT will be used for volume weighting
--  NOTE: the production variable will be indetified by the test name "ProductionCNT". This variable will record the
--	production in MSU's. 
--  The reason this change was requested is because production can be recorded in many different eng units along the
--  production path. Because of this it will become quite complex for the sp to manage all the conversions to MSU.
--  NOTE: We have reverted back to using the Production_Variable from dbo.Production, more logic will be added to 
--  convert this production value to MSU. The conversion to MSU will be done using the conversion factor on the spec 
--  variable.
--	The variable PU has to come from the PU that is that production point in a execution path. For each PL in the
--	report the code must do the following to find the production point
--	1. Get Execution Path for the PL
--	2. Find the PU that is the production point for the execution path
--	3. Get the variable associated with the production point from the Prod_Units table.
DECLARE @tblPUOriginalSamples TABLE	(
					PLId			INT,
					PUId			INT  )

INSERT INTO @tblPUOriginalSamples  (PLId	,
									PUId	)
SELECT								PLId	,
									PUId	
FROM		@tblListPUFilter
WHERE       HoldSamples = 1

-- SELECT '@tblPUOriginalSamples',* FROM @tblPUOriginalSamples
-- SELECT 'Before. @tblListPUFilter',pu.PU_Desc,puf.* FROM @tblListPUFilter   puf JOIN dbo.Prod_Units_Base		pu    ON  puf.PUId = pu.PU_Id
-----------------------------------------------------------------------------------------------------------------------
--	Get the Production Plan and PathId for all the active production plans for the Lines selected during the 
--  report window 
--  Information Added on 2010-Feb-27 :
--  The Table @tblProdPlanPath has the ACTIVE PATH !
-----------------------------------------------------------------------------------------------------------------------
INSERT  @tblProdPlanPath 
				( 	PLId					,
					PUId					,
					PathId					,
					PathDesc				,
					IsProductionPoint		,
					ProductionVarId			)
SELECT  pep.PL_Id		,
		pepu.PU_Id		,
		pep.Path_Id		,
		pep.Path_Desc	,
		pepu.Is_Production_Point,
		pu.Production_Variable
FROM    dbo.PrdExec_Paths			 pep	WITH(NOLOCK)
JOIN    dbo.PrdExec_Path_Units		 pepu	WITH(NOLOCK)	ON		pep.Path_Id = pepu.Path_Id
JOIN    dbo.Prod_Units_Base			 pu		WITH(NOLOCK)	ON		pu.PU_Id	= pepu.PU_Id
WHERE   pep.PL_Id IN (SELECT PLId FROM @tblListPLFilter)

-- What PL_Id the Prod Unit involved in the Path belongs to:
UPDATE	@tblProdPlanPath 
	SET SourcePLId = PL_Id
FROM	@tblProdPlanPath		pp
JOIN	dbo.Prod_Units_Base		pu	WITH(NOLOCK) ON pp.PUId = pu.PU_Id


--=================================================================================================================
-- 2011-Feb
-- Fill the Production Plan table, this will be used later if the Report is grouped by PO 
--=================================================================================================================
INSERT INTO @tblProdPlanActive  ( 	
					PLId					,
					PUId					,
					PPId					,
					PPSStartTime			,
					PPSEndTime				,
					PathId					,
					ProdId					,
					ProductGrpId			,
					PO						)
SELECT  			pep.PL_Id				,	
					pu.PU_Id				,
					pp.PP_Id				,
					(CASE WHEN pps.Start_Time < @p_vchRptStartDateTime THEN @p_vchRptStartDateTime ELSE pps.Start_Time END)		,
					(CASE WHEN (pps.End_Time > @p_vchRptEndDateTime OR pps.End_Time IS NULL) THEN @p_vchRptEndDateTime ELSE pps.End_Time END)			,
					pp.Path_Id				,
					pp.Prod_Id,
					pgd.Product_Grp_Id,
					pp.Process_Order
FROM 	dbo.Production_Plan_Starts   pps	WITH(NOLOCK)
JOIN    dbo.Production_Plan			 pp     WITH(NOLOCK)
											ON  pp.PP_Id = pps.PP_Id
JOIN    dbo.Prod_Units_Base			     pu		WITH(NOLOCK)
											ON  pps.PU_Id = pu.PU_Id
JOIN    dbo.PrdExec_Paths			 pep	WITH(NOLOCK)
											ON  pep.Path_Id = pp.Path_Id
JOIN    dbo.Product_Group_Data		 pgd	WITH(NOLOCK)
											ON  pgd.Prod_Id = pp.Prod_Id
WHERE  		(pps.End_Time >= @p_vchRptStartDateTime OR pps.End_Time IS NULL) 
                AND ((pps.End_Time >= @p_vchRptStartDateTime AND pps.End_Time < @p_vchRptEndDateTime)
                    OR (pps.Start_Time >= @p_vchRptStartDateTime AND pps.Start_Time < @p_vchRptEndDateTime))
			AND pep.PL_Id IN (SELECT PLId FROM @tblListPLFilter)

-----------------------------------------------------------------------------------------------------------------------
-- Flag the Lines that have an Active Production Path and the ones that does not :
-----------------------------------------------------------------------------------------------------------------------
UPDATE @tblListPLFilter
	SET ActivePPath = pp.PathId
FROM   @tblListPLFilter pl
JOIN   @tblProdPlanPath pp	ON	pl.PLId = pp.PLId
-----------------------------------------------------------------------------------------------------------------------
-- Count the Execution Paths configured on the Line
-----------------------------------------------------------------------------------------------------------------------
UPDATE @tblListPLFilter
	SET CountOfPaths = (SELECT DISTINCT COUNT(Path_Id) FROM dbo.PrdExec_Paths WITH(NOLOCK) WHERE PL_Id = pl.PLId)
FROM   @tblListPLFilter pl
-----------------------------------------------------------------------------------------------------------------------
-- By now we have on the @tblListPUFilter only the Production Units that have the DefaultPUG UDP Configured. 
-- The following logic if built to meet the bussiness rules :
-- 1. If the Line has only one Production Path then add all the Production Units to the @tblListPUFilter table
-- 2. If the Line has more than one Production Path then only add the Production Units that belong to the Active
--    Production Path to the @tblListPUFilter table.
-----------------------------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------
-- Before Applying the Rules, clean the @tblListPUFilter table
-----------------------------------------------------------------------------------------------------------------------
DELETE FROM @tblListPUFilter
-----------------------------------------------------------------------------------------------------------------------
-- Rule 1. For the Lines that do not have Active Production Path then insert everything that is on the execution Path 
--		   If no production path at all then insert all the Production Units from that Line
-----------------------------------------------------------------------------------------------------------------------

-- Only One Production Path
INSERT INTO @tblListPUFilter (
 								PLId,
 								PUId)
SELECT  DISTINCT 				pep.PL_Id	,
								pepu.PU_Id
FROM 	dbo.PrdExec_Paths 	   pep		WITH (NOLOCK) 
JOIN	dbo.PrdExec_Path_Units pepu		WITH (NOLOCK)
										ON	pep.Path_Id = pepu.Path_Id
JOIN    @tblListPLFilter	   pl		ON	pl.PLId		= pep.PL_Id
WHERE   CountOfPaths = 1
 -- No Production Paht at all
INSERT INTO @tblListPUFilter (
 								PLId,
 								PUId)
SELECT							PL_Id,
								PU_Id
FROM  dbo.Prod_Units_Base	pu	WITH(NOLOCK)
JOIN  @tblListPLFilter	   pl		ON	pl.PLId		= pu.PL_Id	
WHERE   CountOfPaths = 0

-----------------------------------------------------------------------------------------------------------------------
-- Rule 2. For the Lines that have Active Production Path insert whatever is on the Execution Path. And get rid of everything that was there before.
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @tblListPUFilter (
 								PLId,
 								PUId)
SELECT  DISTINCT 				pep.PL_Id	,
								pepu.PU_Id	
FROM 	dbo.PrdExec_Paths 	   pep		WITH (NOLOCK) 
JOIN	dbo.PrdExec_Path_Units pepu		WITH (NOLOCK)
										ON	pep.Path_Id = pepu.Path_Id
JOIN    @tblProdPlanPath 	   ppp		ON  pep.Path_Id	= ppp.PathId
JOIN    @tblListPLFilter	   pl		ON	pl.PLId		= ppp.PLId
WHERE   ActivePPath <> 0
AND		CountOfPaths > 1

-----------------------------------------------------------------------------------------------------------------------
-- Rule 3. The production units that originaly hold the samples have to be added to the List with two watchouts :
--		   1. If they are not in the current list, they never have to be turned into Production Points
--		   2. If they are currently in the list, then if they are production points let them be.
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @tblListPUFilter (
 								PLId,
 								PUId,
								HoldSamples)
SELECT							PLId,
 								PUId,
								1
FROM		@tblPUOriginalSamples
WHERE       PUId NOT IN (SELECT PUId FROM @tblListPUFilter)
-----------------------------------------------------------------------------------------------------------------------
--	Update the PLId
-----------------------------------------------------------------------------------------------------------------------
UPDATE	lpuf
SET	PLId = pu.PL_Id,
	PUDesc = pu.PU_Desc
FROM	@tblListPUFilter	lpuf
	JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)
								ON	lpuf.PUId = pu.PU_Id
WHERE PLId IS NULL
-----------------------------------------------------------------------------------------------------------------------
--	Update the PUDesc
-----------------------------------------------------------------------------------------------------------------------
UPDATE	lpuf
SET PUDesc = pu.PU_Desc
FROM	@tblListPUFilter	lpuf
	JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)
								ON	lpuf.PUId = pu.PU_Id
-----------------------------------------------------------------------------------------------------------------------
--	Comment this out for FAMILY CARE !
--  This has to be done per Line !!
-----------------------------------------------------------------------------------------------------------------------
UPDATE @tblListPLFilter
	SET IsFamilyCareLine = 1
FROM  @tblListPLFilter   lpl
JOIN  dbo.Prod_Lines_Base	 pl	WITH(NOLOCK)	ON		pl.PL_Id   = lpl.PLId
JOIN  dbo.Departments_Base	 d	WITH(NOLOCK)	ON		pl.Dept_Id = d.Dept_Id
WHERE d.Extended_Info    LIKE	'Category=FamCare;'
--=============================================================================================================================
-------------------------------------------------------------------------------------------------------------------------------
-- WE have to do this for all the lines now, given that we could potentially use the ProductionVarId for one Production Unit
-- no matter if it is a production point or not.
-- 2010-07-01 : Split the update in order to deal with Production Units that are in more than one Production Path and for some
-- reason they are not consistenly Production Points.
-------------------------------------------------------------------------------------------------------------------------------
UPDATE	lpuf
			SET	ProductionType 		= Production_Type,
				ProductionVarId 	= Production_Variable
FROM	@tblListPUFilter	lpuf
JOIN    @tblListPLFilter	pl		ON	lpuf.PLId = pl.PLId
JOIN	dbo.Prod_Units_Base pu		WITH (NOLOCK)
									ON	pu.PU_Id = lpuf.PUId
										

-- All Production Units have to be updated :
UPDATE	lpuf
			SET	-- ProductionType 		= Production_Type,
				-- ProductionVarId 	= Production_Variable,
				ProductionPointPUId = pepu.PU_Id,
				IsProductionPoint 	= pepu.Is_Production_Point
FROM	@tblListPUFilter	lpuf
JOIN    @tblListPLFilter		pl		ON	lpuf.PLId = pl.PLId
JOIN	dbo.PrdExec_Paths		pep		WITH (NOLOCK)
										ON	pl.PLId = pep.PL_Id
JOIN	dbo.PrdExec_Path_Units pepu		WITH (NOLOCK)
										ON	pep.Path_Id = pepu.Path_Id
JOIN	dbo.Prod_Units_Base pu				WITH (NOLOCK)
										ON	pu.PU_Id = lpuf.PUId
										AND pepu.PU_Id = lpuf.PUId
WHERE	pepu.Is_Production_Point		= 1

--=============================================================================================================================
--SELECT '@tblListPUFilter',*		FROM	@tblListPUFilter puf 
--SELECT '@tblProdPlanPath ',pp.*,pu.PU_Desc	FROM	@tblProdPlanPath pp JOIN Prod_Units pu ON pp.PUId = pu.PU_Id WHERE PathId = 58
--SELECT '@tblListPLFilter',*		FROM	@tblListPLFilter
--SELECT '@tblProdPlanActive',*	FROM	@tblProdPlanActive WHERE PathId = 58 ORDER BY PLId, PPSStartTime

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Identify Converting lines'
--=====================================================================================================================
--	This section of code identifies lines and units that belong to converting lines
--	Business Rule:
--	If a line/Unit is a converting line then the report needs to get the variables from the paper machine that feed
--	the converter.
-----------------------------------------------------------------------------------------------------------------------
--	Get Field Id
-----------------------------------------------------------------------------------------------------------------------
SET @intTableFieldId = NULL

SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescIsConvertingLine
-----------------------------------------------------------------------------------------------------------------------
--	Get Field Value
-----------------------------------------------------------------------------------------------------------------------
UPDATE	@tblListPUFilter
	SET	IsConvertingLine = Value
FROM	@tblListPUFilter	puf
	JOIN	dbo.Table_Fields_Values	tfv	WITH(NOLOCK) ON	puf.PLId = tfv.KeyId
WHERE	tfv.Table_Field_Id = @intTableFieldId

-- Debugg Section for Production Path :
-- SELECT '#Paths Line',PL_Id,COUNT(Path_Id) FROM dbo.PrdExec_Paths	pp
-- JOIN @tblListPLFilter  pl		ON	pp.PL_Id = pl.PLId GROUP BY PL_Id
-- SELECT '@tblListPUFilter',* FROM @tblListPUFilter ORDER BY PLId
-- SELECT '@tblProdPlanPath',* FROM @tblProdPlanPath ORDER BY PLId, PathId -- WHERE PLId = 108
-- SELECT '@tblListPLFilter',* FROM @tblListPLFilter

-----------------------------------------------------------------------------------------------------------------------
--	c. If production source has not been configured then test COUNT will be used for volume weighting
-----------------------------------------------------------------------------------------------------------------------
IF	NOT EXISTS (	SELECT	ProductionType
					FROM	@tblListPUFilter
					WHERE	ProductionType >= 0)
	AND	@intRptVolumeWeightOption = 0	--	volume weighting using production COUNT
BEGIN
	SET	@intRptVolumeWeightOption = 1 	-- 	volume weighting using test COUNT
	IF @intPRINTFlag = 1	
	BEGIN
		PRINT	'	Volume weighting option has been changed to test COUNT because dbo.Prod_Units_Base.Production_Type IS NULL'
	END
END
-----------------------------------------------------------------------------------------------------------------------
--	e. 	If IsProductinPoint = 0 on all selected production units, then test COUNT is used for volume weighting
-----------------------------------------------------------------------------------------------------------------------
IF	(	SELECT	SUM(IsProductionPoint)
		FROM	@tblListPUFilter) = 0
AND	@intRptVolumeWeightOption = 0
BEGIN
	SET	@intRptVolumeWeightOption = 1 -- volume weighting using test COUNT
	IF @intPRINTFlag = 1	PRINT	'	Volume weighting option has been change to test COUNT because all PUs have IsProductionPoint = 0'
END

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Line Status PUId'
--=====================================================================================================================
--	LINE STATUS
--	New sites will not be using the Local_PG_Line_Status table, there is a new local table in the works that is
-- 	supposed to be a lcoal line status equivalent table and is in currently targeted to be availabe in Plant Apps. 4.3
--	If the table meets P&G requirements it will replace the Local_PG_LineStatus table.
--	In the meantime the report type parameter @intRptUseLocalPGLineStatusTable will flag which sites require the use
--	of Local_PG_LineStatus and which don't. NOTE: THIS TABLE WILL NOT BE AVAILABLE FOR A WHILE

--	If the new table is NOT available when sites that have a requirement for Local_PG_Line_Status get upgraded to 
--	Plant Apps 4.x, the logic will look for the line status on its PUId, if no line status is associated with the PU
-- 	it will look for the LineStatus PUId on a UDP associated with the PU. The name of the UPD is "LineStatusPUId"
-----------------------------------------------------------------------------------------------------------------------
--	Look for Line Status on NonProductive_Detail for given PU
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lpu
	SET	LineStatusPUId = PUId
FROM	@tblListPUFilter	lpu
JOIN	dbo.NonProductive_Detail	ls	WITH (NOLOCK)
										ON	lpu.PUId = ls.PU_Id 

-------------------------------------------------------------------------------------------------------------------	
--	IF a production unit does not have line status configured on itself look for the UPD value for LineStatusPUId
--	on the PU
-------------------------------------------------------------------------------------------------------------------	
IF EXISTS (	SELECT 	PLId
		 	FROM 	@tblListPUFilter
			WHERE	LineStatusPUId IS NULL)
BEGIN
	-------------------------------------------------------------------------------------------------------------------	
	--	GET table Id for Prod_Units
	-------------------------------------------------------------------------------------------------------------------	
	SELECT	@intTableId = TableId
	FROM	dbo.Tables	WITH (NOLOCK)	
	WHERE	TableName = 'Prod_Units'
	-------------------------------------------------------------------------------------------------------------------	
	--	GET table field Id for DefaultQProdGrps
	-------------------------------------------------------------------------------------------------------------------	
	SELECT	@intTableFieldId = Table_Field_Id
	FROM	dbo.Table_Fields	WITH (NOLOCK)
	WHERE	Table_Field_Desc = @vchUDPDescLineStatusPUId
	-------------------------------------------------------------------------------------------------------------------	
	--	GET Line status PUId
	-------------------------------------------------------------------------------------------------------------------	
	UPDATE	lpuf
	SET		LineStatusPUId = Value
	FROM	@tblListPUFilter	lpuf
		JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
												ON	lpuf.PUId = tfv.KeyId 
	WHERE	tfv.TableId = @intTableId
		AND	tfv.Table_Field_Id = @intTableFieldId	
		AND	LineStatusPUId IS NULL
END	

--======================================================================================================================
-- THIS SECTION IS ONLY FOR BUILDING TESTING SCENARIO !!!
-- We are emulating here different cases of Voluming 
------------------------------------------------------------------------------------------------------------------------
--======================================================================================================================
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' DATA SOURCE'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
--=====================================================================================================================
--	DATA SOURCE
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Variables'
--=====================================================================================================================
--	GET VARIABLES 
--	Business Rule:
--	a.	IF a list of variables is selected return all variables that match the variable description
--	b.	ELSE return all variables that belong the to default variable groups
--		The production groups will be identified by a UDP on the PU_Groups table
--		Table = PU_Groups
--		Table_Fields = DefaultQProdGrps of type numeric
--		Table_Field_Values has a record for each PUG_Id that should be included in the DefaultQProdGrpss
--		Business Rule: if DefaultQProdGrps = 1 include variable group in PPM report ELSE do not include
-----------------------------------------------------------------------------------------------------------------------
--	a.	IF a list of variables is selected return all variables that match the variable description
-----------------------------------------------------------------------------------------------------------------------

IF	EXISTS	(	SELECT	VarId
				FROM	#ListDataSourceFilter)
BEGIN
	INSERT INTO	#ListDataSource (
				PLId,
				VarId,
				SPCParentVarId,
				SPCCalcId,		
				SPCVarTypeId,
				VarMasterPUId,
				VarPUId,
				PUGId,
				VarDataTypeId,
				VarDesc,
				VarTestName,
				VarEventType,
				VarEventSubTypeId,
				IsAtt,	-- default value
				ExtendedTestFreq,
				SamplingInterval,
				VarSpecActivation )	
	SELECT	DISTINCT
			p.PL_Id,
			v.Var_Id,
			v.PVar_Id,
			v.SPC_Calculation_Type_Id,
			v.SPC_Group_Variable_Type_Id,
			COALESCE(p.Master_Unit, p.PU_Id),
			v.PU_Id,
			v.PUG_Id,
			v.Data_Type_Id,
			v.Var_Desc,
			v.Test_Name,
			v.Event_Type,
			v.Event_SubType_Id,
			CASE	WHEN	v.Data_Type_Id IN (1, 2, 6, 7)
					THEN	0
					ELSE	1
					END,
			v.Extended_Test_Freq,
			COALESCE(v.Sampling_Interval,0),
			v.SA_Id	
	FROM	#ListDataSourceFilter	ldsf	WITH (INDEX(ListDataSourceFilterVarDesc_Idx), NOLOCK)
		JOIN	dbo.Variables_Base 		v		WITH (NOLOCK) 
											ON ldsf.VarDesc = v.Var_Desc	-- have to join on var_desc because the report needs to 
																			-- retrieve variables from all prod units
		JOIN	@tblListPUFilter	lpuf	ON	lpuf.PUId = v.PU_Id
		JOIN	dbo.Prod_Units_Base		p		WITH (NOLOCK)
											ON	lpuf.PUId = p.PU_Id 
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
	-------------------------------------------------------------------------------------------------------------------	
	--	GET table field Id for DefaultQProdGrps
	-------------------------------------------------------------------------------------------------------------------	
	SELECT	@intTableFieldId = Table_Field_Id
	FROM	dbo.Table_Fields	WITH (NOLOCK)
	WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps

	-------------------------------------------------------------------------------------------------------------------		
	--	GET all the variables that belong to the default PU_Groups
	-------------------------------------------------------------------------------------------------------------------	
	INSERT INTO	#ListDataSource (
				PLId,
				VarId,
				SPCParentVarId,
				SPCCalcId,		
				SPCVarTypeId,
				VarMasterPUId,
				VarPUId,
				PUGId,
				VarDataTypeId,
				VarDesc,
				VarTestName,
				VarEventType,
				VarEventSubTypeId,
				IsAtt ,		-- default value
				ExtendedTestFreq,
				SamplingInterval,
				VarSpecActivation)
	SELECT	DISTINCT
			p.PL_Id,
			v.Var_Id,
			v.PVar_Id,
			v.SPC_Calculation_Type_Id,
			v.SPC_Group_Variable_Type_Id,
			COALESCE(p.Master_Unit, p.PU_Id),
			v.PU_Id,
			v.PUG_Id,
			v.Data_Type_Id,
			v.Var_Desc,
			v.Test_Name,
			v.Event_Type,
			v.Event_SubType_Id,
			CASE	WHEN	v.Data_Type_Id IN (1, 2, 6, 7)
					THEN	0
					ELSE	1
					END,
			v.Extended_Test_Freq,
			COALESCE(v.Sampling_Interval,0),
			v.SA_Id		
	FROM	dbo.Variables_Base	v				WITH (NOLOCK) 
		JOIN	dbo.PU_Groups	pg				WITH (NOLOCK)
												ON	pg.PUG_Id = v.PUG_Id
		JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
												ON	tfv.KeyId = pg.PUG_Id
		JOIN	@tblListPUFilter	lpuf		ON	lpuf.PUId = v.PU_Id
		JOIN	dbo.Prod_Units_Base		p		WITH (NOLOCK)
												ON	lpuf.PUId = p.PU_Id 
	WHERE	tfv.TableId = @intTableId
		AND	tfv.Table_Field_Id = @intTableFieldId
		AND	tfv.Value = 'Yes'
END

--=====================================================================================================================
-- Check if use Genealogy: Get Paper Machine Offline Quality Variables for Converting Lines (Options: 0 = No; 1 = Yes)
--=====================================================================================================================
IF @intUseRptGenealogy = 1
BEGIN
	--=====================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Paper Machine Offline Quality Variables for Converting Lines'
	--=====================================================================================================================
	--	GET Paper Machine Offline Quality Variables for Converting Lines
	--	Business Rule: if the user has selected a PU that belongs to a converting line, then the logic must go to the paper
	--	machine and pull all the variables for the PM Offline Quality into the report.
	-----------------------------------------------------------------------------------------------------------------------
	DELETE	@tblListEventSubTypes
	-----------------------------------------------------------------------------------------------------------------------
	--	GET table Id for PU_Groups
	-----------------------------------------------------------------------------------------------------------------------	
	SELECT	@intTableId = TableId
	FROM	dbo.Tables	WITH (NOLOCK)	
	WHERE	TableName = 'Event_SubTypes'
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

	-----------------------------------------------------------------------------------------------------------------------
	IF	EXISTS	(	SELECT	PUId
					FROM	@tblListPUFilter
					WHERE	IsConvertingLine = 1)
	BEGIN
		-------------------------------------------------------------------------------------------------------------------
		--	Get the list of converting PU's
		-------------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblListConvertingPUTemp	(
				PLId,
				PUId	)
		SELECT	PLId,
				PUId
		FROM	@tblListPUFilter
		WHERE	IsConvertingLine = 1
		-------------------------------------------------------------------------------------------------------------------
		--	Initialize Variables
		-------------------------------------------------------------------------------------------------------------------
		SELECT	@i = 1,
				@intMaxRcdIdx = MAX(RcdIdx)
		FROM	@tblListConvertingPUTemp

		-- SELECT '@tblListConvertingPUTemp',* FROM @tblListConvertingPUTemp	
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
						SampleId)
			SELECT	UDE_Id
			FROM	dbo.User_Defined_Events		ude	WITH (NOLOCK)
			JOIN	@tblListEventSubTypes	est	ON	est.EventSubTypeId = ude.Event_SubType_Id
			WHERE	ude.PU_Id = @intConvertingPUId
				AND	End_Time >= @p_vchRptStartDateTime
				AND	End_Time < 	@p_vchRptEndDateTime
			---------------------------------------------------------------------------------------------------------------
			--	Get the source machines (PU's)
			---------------------------------------------------------------------------------------------------------------
			DELETE	@tblSourcePUList

			INSERT INTO	@tblSourcePUList	(
						SourcePUId	)
			SELECT DISTINCT ude.PU_Id
			FROM	dbo.User_Defined_Events ude WITH(NOLOCK)
			JOIN	@tblSampleList	sl	ON	sl.SampleId = ude.Parent_UDE_ID

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
			---------------------------------------------------------------------------------------------------------------
			--	GET table field Id for DefaultQProdGrps
			---------------------------------------------------------------------------------------------------------------	
			SELECT	@intTableFieldId = Table_Field_Id
			FROM	dbo.Table_Fields	WITH (NOLOCK)
			WHERE	Table_Field_Desc = @vchUDPDescDefaultQProdGrps

			-- SELECT @intConvertingPLId,'@tblSourcePUList',* FROM @tblSourcePUList
			---------------------------------------------------------------------------------------------------------------		
			--	GET all the variables that belong to the default PU_Groups
			---------------------------------------------------------------------------------------------------------------	
			INSERT INTO	#ListDataSource (
					PLId,
					VarId,
					SPCParentVarId,
					SPCCalcId,		
					SPCVarTypeId,
					VarPUId,
					VarPUIdSource,
					PUGId,
					VarDataTypeId,
					VarDesc,
					VarTestName,
					VarEventType,
					VarEventSubTypeId,
					IsAtt ,		-- default value
					ExtendedTestFreq,
					SamplingInterval,
					VarSpecActivation,
					IsOfflineQuality)
			SELECT	DISTINCT
					@intConvertingPLId,
					v.Var_Id,
					v.PVar_Id,
					v.SPC_Calculation_Type_Id,
					v.SPC_Group_Variable_Type_Id,
					@intConvertingPUId,
					v.PU_Id,
					v.PUG_Id,
					v.Data_Type_Id,
					v.Var_Desc,
					v.Test_Name,
					v.Event_Type,
					v.Event_SubType_Id,
					CASE	WHEN	v.Data_Type_Id IN (1, 2, 6, 7)
							THEN	0
							ELSE	1
							END,
					v.Extended_Test_Freq,
					COALESCE(v.Sampling_Interval,0),
					v.SA_Id,
					1		
			FROM	dbo.Variables_Base	v			WITH (NOLOCK) 
			JOIN	dbo.PU_Groups	pg				WITH (NOLOCK)
													ON	pg.PUG_Id = v.PUG_Id
			JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
													ON	tfv.KeyId = pg.PUG_Id
			JOIN	@tblSourcePUList	lpuf		ON	lpuf.SourcePUId = v.PU_Id
			WHERE	tfv.TableId = @intTableId
				AND	tfv.Table_Field_Id = @intTableFieldId
				AND	tfv.Value = 'Yes'		
			--	AND v.Var_Id NOT IN (SELECT VarId FROM #ListDataSource)		
			---------------------------------------------------------------------------------------------------------------
			--	New Bussiness Rule :
			--  If there is a List of Variables Selected and those variables matches the Var_Desc for OffLine Quality Units
			--  Variables, then get them; no matter if they belong to the @vchUDPDescDefaultQProdGrps
			---------------------------------------------------------------------------------------------------------------
			
			INSERT INTO	#ListDataSource (
					PLId,
					VarId,
					SPCParentVarId,
					SPCCalcId,		
					SPCVarTypeId,
					VarPUId,
					VarPUIdSource,
					PUGId,
					VarDataTypeId,
					VarDesc,
					VarTestName,
					VarEventType,
					VarEventSubTypeId,
					IsAtt ,		-- default value
					ExtendedTestFreq,
					SamplingInterval,
					VarSpecActivation,
					IsOfflineQuality)
			SELECT	DISTINCT
					@intConvertingPLId,
					v.Var_Id,
					v.PVar_Id,
					v.SPC_Calculation_Type_Id,
					v.SPC_Group_Variable_Type_Id,
					@intConvertingPUId,
					v.PU_Id,
					v.PUG_Id,
					v.Data_Type_Id,
					v.Var_Desc,
					v.Test_Name,
					v.Event_Type,
					v.Event_SubType_Id,
					CASE	WHEN	v.Data_Type_Id IN (1, 2, 6, 7)
						THEN	0
						ELSE	1
						END,
					v.Extended_Test_Freq,
					COALESCE(v.Sampling_Interval,0),
					v.SA_Id,
					1		
			FROM	dbo.Variables_Base	v			WITH (NOLOCK) 
			JOIN	@tblSourcePUList	lpuf		ON	lpuf.SourcePUId = v.PU_Id
			JOIN    #ListDataSourceFilter	ldsf	WITH (INDEX(ListDataSourceFilterVarDesc_Idx), NOLOCK)
													ON ldsf.VarDesc = v.Var_Desc	

			DELETE @tblSampleList	
			---------------------------------------------------------------------------------------------------------------
			--	INCREMENT COUNTER
			---------------------------------------------------------------------------------------------------------------
			SET	@i = @i + 1
		END
	END
END	-- IF @intUseRptGenealogy = 1



--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UPDATE TestName for SPC variables'
--=====================================================================================================================
--	UPDATE TestName FOR SPC VARIABLES
--	Business Rule:
--	a.	SPC variables consist of a SPC Parent and many children, the children can be of type autolog or they can be
--		pre-defined calculations. For the PPM report we are only interested in the SPC children that have the autolog 
--		datatype
--		e.g.
--		SPC Variable
--		SPC Variable 01
--		SPC Variable 02
--		SPC Variable 03
--		The SPC children need to be analyzed individually and rolled up into one using the parent name. In the previos
--		version of NormPPM we were using test names to combine variables. 
--		For logic simplicity we will make the test name = SPC parent var desc. 
--		This will allow us to continue to support both test name and SPC and will allow us to use the old logic to 
--		analyse SPC variables.
-----------------------------------------------------------------------------------------------------------------------
UPDATE	lds
SET	VarTestName = v.Var_Desc
FROM	#ListDataSource	lds	WITH (NOLOCK)
	JOIN	dbo.Variables_Base	v	WITH (NOLOCK)
								ON	v.Var_Id = SPCParentVarId 
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Varible UPDs '
--=====================================================================================================================
--	VARIABLE UPDs
--	Business Rule:
--	If a UDP is 
--	a. Reportable	:	Identifies which variables should be included in the report
--						Options	1 = YES; 0 = NO
--						If value is 0 variable is eliMINated from the report
--						Default is 1
--	b. IsNonNormal	:	Identifies Non-normal variables	
--						Options 1 = YES; 0 = NO	
--						Default is 0
--	c. TzFlag		:	Identifies which variables should not use the Target Specification in the calculation of MC
-- 						Options: 1 = YES include Target Value; 0 = NO set target valued to NULL
--						Default = 1
--	d. IsAtt		:	Identifies which variables should be treated as measurable attributes
-- 						Options: 	1 = attributes of type text
-- 									2 = numeric variables that need to be treated as attribute
--										but also need to display statistical values on the VAS report
--									3 = numeric variable that need to be treated as attributes but 
--										do not require statistical values on the VAS report
--	e. RptSPCParent	: 	If this UDP is 1 then the code should report the values for the parent. 
--						If the UDP is NULL or 0 then the code should report the values for the children.
--						Default = 0
--  f. Criticality	:	Identifies the variables criticality
-----------------------------------------------------------------------------------------------------------------------	
--	GET table Id for Variables
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableId = TableId
FROM	dbo.Tables	WITH (NOLOCK)	
WHERE	TableName = 'Variables'
-----------------------------------------------------------------------------------------------------------------------	
--	a. Rpt			:	Identifies which variables should be included in the report
--						Options	1 = YES; 0 = NO
--						If value is 0 variable is eliMINated from the report
--						NOTE1:	SPC presents a special case, P&G has set the SPC children to not report, because they 
--								want to report on the average instead of the raw data.
--								The report has been designed to work with raw data so to avoid the eliMINation of the
--								children we will look at the reportability of the parent. If the parent is reportable
--								we include the children, else we don't 
--						NOTE2:	RptSPCParent = 1 will override NOTE1 later in the code 
-----------------------------------------------------------------------------------------------------------------------	
--	GET table field Id for Reportable UDP
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescReportable
-----------------------------------------------------------------------------------------------------------------------	
--	GET the value of Rpt
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds
SET	IsReportable = CASE	WHEN	Value = 'No'	THEN	0
						ELSE	1	
						END
FROM	#ListDataSource	lds
	JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
											ON	tfv.KeyId = lds.VarId
WHERE	tfv.TableId = @intTableId
	AND	tfv.Table_Field_Id = @intTableFieldId
	AND	lds.SPCParentVarId IS NULL
-----------------------------------------------------------------------------------------------------------------------	
--	If the parent is not reportable then set the children to be non-reportable as well
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds2
SET	IsReportable = lds1.IsReportable -- lds2.IsReportable
FROM	#ListDataSource	lds1
	JOIN	#ListDataSource	lds2	WITH (NOLOCK)
									ON	lds1.VarId = lds2.SPCParentVarId
WHERE	lds1.SPCParentVarId IS NULL
-----------------------------------------------------------------------------------------------------------------------	
--	b. IsNonNormal	:	Identifies Non-normal variables	
--						Options 1 = YES; 0 = NO	
-----------------------------------------------------------------------------------------------------------------------	
--	GET table field Id for NonNormal
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescIsNonNormal
-----------------------------------------------------------------------------------------------------------------------	
--	GET the value of NonNormal
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds
SET	IsNonNormal = CASE	WHEN	Value = 'Yes'	
						THEN	1
						ELSE	0
						END
FROM	#ListDataSource	lds
	JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
											ON	tfv.KeyId = lds.VarId
WHERE	tfv.TableId = @intTableId
	AND	tfv.Table_Field_Id = @intTableFieldId
-----------------------------------------------------------------------------------------------------------------------	
--	c. Tz			:	Identifies which variables should not use the Target Specification in the calculation of MC
--						Options	1 = YES; 0 = NO
-----------------------------------------------------------------------------------------------------------------------	
--	GET table field Id for Tz
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescTzFlag
-----------------------------------------------------------------------------------------------------------------------	
--	GET the value of Tz
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds
	SET	TzFlag = CASE	WHEN	Value = 'No'	THEN	0
						ELSE	1	
						END
FROM	#ListDataSource	lds
	JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
											ON	tfv.KeyId = lds.VarId
WHERE	tfv.TableId = @intTableId
	AND	tfv.Table_Field_Id = @intTableFieldId	

-----------------------------------------------------------------------------------------------------------------------	
--	d. IsAtt		:	Identifies which variables should be treated as measurable attributes
-- 						Options: 	1 = attributes of type text
-- 									2 = numeric variables that need to be treated as attribute
--										but also need to display statistical values on the VAS report
--									3 = numeric variable that need to be treated as attributes but 
--										do not require statistical values on the VAS report
--	Default values: if data type is numeric 0 else 1
--	these default values were set in the previous query that gets the list of variables
-----------------------------------------------------------------------------------------------------------------------	
--	GET table field Id for IsAtt
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescIsAtt
-----------------------------------------------------------------------------------------------------------------------	
--	GET the value of IsAtt
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds
SET	IsAtt = CASE	WHEN	Value = 'No'	THEN	0
						ELSE	1	
						END
FROM	#ListDataSource	lds
	JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
											ON	tfv.KeyId = lds.VarId
WHERE	tfv.TableId = @intTableId
	AND	tfv.Table_Field_Id = @intTableFieldId	


--=====================================================================================================================
--	e. RptSPCParent: 	If this UDP is 1 then the code should report the values for the parent. 
--						If the UDP is NULL or 0 then the code should report the values for the children.
-----------------------------------------------------------------------------------------------------------------------
--	GET table field Id for RptSPCParent
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescSPCParent
-----------------------------------------------------------------------------------------------------------------------	
--	GET the value of RptSPCParent
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds
SET	RptSPCParent = CASE	WHEN	Value = 'No'	THEN	0
						ELSE	1	
						END
FROM	#ListDataSource	lds
	JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
											ON	tfv.KeyId = lds.VarId
WHERE	tfv.TableId = @intTableId
	AND	tfv.Table_Field_Id = @intTableFieldId
	AND	lds.SPCParentVarId IS NULL
-----------------------------------------------------------------------------------------------------------------------
--	IF	RptSPCParent <> 1 make IsReportable = 0 for SPCParent
-----------------------------------------------------------------------------------------------------------------------
UPDATE	lds
	SET	IsReportable = 0
FROM	#ListDataSource lds
WHERE	RptSPCParent = 0
	AND	VarId IN (	SELECT	DISTINCT 
 							SPCParentVarId
 					FROM	#ListDataSource)
-----------------------------------------------------------------------------------------------------------------------	
--	IF	RptSPCParent = 1 make IsReportable = 0 for SPCChildren
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds2
SET	IsReportable = 0
FROM	#ListDataSource	lds1
	JOIN	#ListDataSource	lds2	WITH (NOLOCK)
									ON	lds1.VarId = lds2.SPCParentVarId
WHERE	lds1.SPCParentVarId IS NULL
	AND	lds1.RptSPCParent = 1


-----------------------------------------------------------------------------------------------------------------------	
--	f. Criticality	:	Identifies variables criticality can be a value from 1-4	
-----------------------------------------------------------------------------------------------------------------------	
--	GET table field Id for Criticality
-----------------------------------------------------------------------------------------------------------------------	
SELECT	@intTableFieldId = Table_Field_Id
FROM	dbo.Table_Fields	WITH (NOLOCK)
WHERE	Table_Field_Desc = @vchUDPDescCriticality
-----------------------------------------------------------------------------------------------------------------------	
--	GET the value for Criticality
-----------------------------------------------------------------------------------------------------------------------	
UPDATE	lds
SET	Criticality = CASE	WHEN	Value = 'No'	THEN	0
						ELSE	1	
						END
FROM	#ListDataSource	lds
	JOIN	dbo.Table_Fields_Values	tfv		WITH (NOLOCK)
											ON	tfv.KeyId = lds.VarId
WHERE	tfv.TableId = @intTableId
	AND	tfv.Table_Field_Id = @intTableFieldId
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' APPLY Variable Filters'
--=====================================================================================================================
--	VARIABLE FILTERS
--	Business Rule:
--	a.	Eliminate all variables where IsReportable = 0
--	b.	Eliminate all variables Where Calculation_Name IN (''Average_Flex'', ''Range_Flex'')'
--	c.	EliMINate all variables that starts with a pre_defined prefix
--	d.	EliMINate all variables that have a data type of logial or string
--	e.	EliMINate all SPC Calculations, i.e. WHERE SPCVarTypeId > 1
--		1 = individual
--	f.  Eliminate all variables where Criticality <> @vchRptCriticality
-----------------------------------------------------------------------------------------------------------------------	
--	a.	Eliminate all variables where IsReportable = 0
-----------------------------------------------------------------------------------------------------------------------	
DELETE	#ListDataSource
WHERE	IsReportable = 0
-----------------------------------------------------------------------------------------------------------------------	
--	b.	Eliminate all variables Where Calculation_Name IN (''Average_Flex'', ''Range_Flex'')'
-----------------------------------------------------------------------------------------------------------------------	
DELETE	ls
FROM	#ListDataSource ls
	JOIN	dbo.Variables_Base	v	WITH (NOLOCK)
								ON	v.Var_Id = ls.VarId
	JOIN	dbo.Calculations	c	WITH (NOLOCK)
									ON v.Calculation_Id = c.Calculation_Id
WHERE	c.Calculation_Name IN ('Average_Flex', 'Range_Flex')
	OR	(c.Calculation_Name LIKE 'MSI%'								-- Error #1
		 AND c.Calculation_Name NOT LIKE 'MSI_Calc_Average')		-- Error #1
-----------------------------------------------------------------------------------------------------------------------
--	c.	EliMINate all variables that starts with a pre_defined prefix
-----------------------------------------------------------------------------------------------------------------------
DELETE	#ListDataSource
WHERE	VarDesc LIKE	@vchRptVariableExclusionPrefix + '%'
-----------------------------------------------------------------------------------------------------------------------
--	d.	EliMINate all variables that have a data type of logical or string
-----------------------------------------------------------------------------------------------------------------------
DELETE	#ListDataSource
WHERE	VarDataTypeId IN (3, 4)
-----------------------------------------------------------------------------------------------------------------------
--	e.	EliMINate all SPC Calculations
-----------------------------------------------------------------------------------------------------------------------
DELETE	#ListDataSource
WHERE	SPCVarTypeId > 1
	AND	SPCCalcId IS NOT NULL
	AND	SPCParentVarId IS NOT NULL
-----------------------------------------------------------------------------------------------------------------------
--	f.	EliMINate Criticality
-----------------------------------------------------------------------------------------------------------------------
SELECT	@nvchSQLCommand	=	'DELETE	#ListDataSource '
						+	'WHERE	Criticality NOT IN (' + @vchRptCriticality + ')'

EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UPDATE VarGroupId, VarDescRpt, IsNumericDataType'
--=====================================================================================================================
--	UPDATE VarGroupId, VarDescRpt, IsNumericDataType
--	a.	VarGroupId = this column deterMINes whether the variable is grouped by VarId or TestName
--	b.	VarDescRpt = is the variable description that will be shown on the report
--	c.	IsNumericDataType = flags the variables that have a numeric datatype
-----------------------------------------------------------------------------------------------------------------------
UPDATE	#ListDataSource
SET	VarGroupId 			= 	CASE	WHEN	LEN(LTRIM(RTRIM(ISNULL(VarTestName, '')))) > 0 
									THEN	LTRIM(RTRIM(VarTestName))
									ELSE	CONVERT(VARCHAR(100), VarId)
									END,
	VarDescRpt			= 	CASE	WHEN	LEN(LTRIM(RTRIM(ISNULL(VarTestName, '')))) > 0 
									THEN	LTRIM(RTRIM(VarTestName))
									ELSE	LTRIM(RTRIM(VarDesc))
									END,
	IsNumericDataType	=	CASE	WHEN	VarDataTypeId	=	1	THEN	1
									WHEN	VarDataTypeId	=	2	THEN	1
									WHEN	VarDataTypeId	=	6	THEN	1
									WHEN	VarDataTypeId	=	7	THEN	1
									ELSE	0
									END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UPDATE VarCount'
--=====================================================================================================================
--		UPDATE VarCount (SPC child variables)
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblListDataSourceTemp (
			PLId,
			VarGroupId,
			VarCount )
SELECT	PLId,
		VarGroupId,
		COUNT(VarId)
FROM	#ListDataSource
GROUP BY	PLId, VarGroupId
-----------------------------------------------------------------------------------------------------------------------
UPDATE	ds
SET		VarCount = dst.VarCount
FROM	#ListDataSource			ds
	INNER	JOIN	@tblListDataSourceTemp	dst	ON	ds.VarGroupId = dst.VarGroupId	
											AND	ds.PLId = dst.PLId
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VALID TIME SLICES'

--=====================================================================================================================
--	VALID TIME SLICES:
--	Business Rule:
--	a. GET all the product runs for the reporting period when there is a product filter
--	b. GET all the product runs for the reporting period when there is no product filter
--	c. SPLIT overlapping line status and apply line status filter
--	d. SPLIT overlapping shifts and apply shift filter
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET all the product runs for the reporting period'
--=====================================================================================================================
--  1. If the report is not grouped by PO then :
--	a. GET all the product runs for the reporting period when there is a product filter
-----------------------------------------------------------------------------------------------------------------------
IF @vchRptMinorGroupBy <> 'PO'
BEGIN
IF	EXISTS	(	SELECT	RcdIdx
				FROM	@tblListProductFilter)
BEGIN
	INSERT INTO	@tblValidTimeSlices	(
				PLId				,
				PUId				,
				ProdId				,
				ProductGrpId		,
				TimeSliceStart		,
				TimeSliceEnd		)
	-- The PLId should be the one that owns the Execution Path, despite the PUId does not belong to it, 
	-- that prevents to unexpected Lines to show up in the Report.
	-- pu.PL_Id,
	SELECT	puf.PLId,
			puf.PUId,
			ps.Prod_Id,
			pf.ProductGrpId,
			CASE	WHEN	ps.Start_Time < CONVERT(DATETIME, @p_vchRptStartDateTime)
					THEN	@p_vchRptStartDateTime
					ELSE	ps.Start_Time
					END, 
			CASE	WHEN	ps.End_Time > CONVERT(DATETIME, @p_vchRptEndDateTime)
					THEN	@p_vchRptEndDateTime
					ELSE	COALESCE(ps.End_Time, @p_vchRptEndDateTime)
					END 
	FROM	dbo.Production_Starts ps		WITH (NOLOCK) 		
		JOIN	@tblListPUFilter puf		ON	puf.PUId = ps.PU_Id
		JOIN	@tblListProductFilter pf	ON	pf.ProdId = ps.Prod_Id
		JOIN	dbo.Prod_Units_Base	pu			WITH (NOLOCK)	
											ON	puf.PUId = pu.PU_Id
	WHERE	ps.Start_Time <= @p_vchRptEndDateTime
		AND	(ps.End_Time > @p_vchRptStartDateTime
			OR	ps.End_Time IS NULL)	
END
ELSE
BEGIN
	-----------------------------------------------------------------------------------------------------------------------
	--	b. GET all the product runs for the reporting period when there is no product filter
	-----------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblValidTimeSlices	(
				PLId				,
				PUId				,
				ProdId				,
				ProductGrpId		,
				TimeSliceStart		,
				TimeSliceEnd		)
	-- The PLId should be the one that owns the Execution Path, despite the PUId does not belong to it, 
	-- that prevents to unexpected Lines to show up in the Report.
	-- pu.PL_Id,
	SELECT	puf.PLId,
			puf.PUId,
			ps.Prod_Id,
			pg.Product_Grp_Id,
			CASE	WHEN	ps.Start_Time < CONVERT(DATETIME, @p_vchRptStartDateTime)
					THEN	@p_vchRptStartDateTime
					ELSE	ps.Start_Time
					END, 
			CASE	WHEN	ps.End_Time > CONVERT(DATETIME, @p_vchRptEndDateTime)
					THEN	@p_vchRptEndDateTime
					ELSE	COALESCE(ps.End_Time, @p_vchRptEndDateTime)
					END 
	FROM	dbo.Production_Starts ps		WITH (NOLOCK) 		
		JOIN	@tblListPUFilter puf		ON	puf.PUId = ps.PU_Id
		JOIN	dbo.Product_Group_Data pg	WITH (NOLOCK)
											ON	ps.Prod_Id = pg.Prod_Id 
		JOIN	dbo.Prod_Units_Base	pu			WITH (NOLOCK)	
											ON	puf.PUId = pu.PU_Id
	WHERE	ps.Start_Time <= @p_vchRptEndDateTime
		AND	(ps.End_Time > @p_vchRptStartDateTime
			OR	ps.End_Time IS NULL)	
END
END
--=====================================================================================================================
--  2. If the report IS GROUPED by PO then :
--	a. GET all the product runs for the reporting period when there is a product filter
-----------------------------------------------------------------------------------------------------------------------
IF @vchRptMinorGroupBy = 'PO'
BEGIN
	IF	EXISTS	(	SELECT	RcdIdx
					FROM	@tblListProductFilter)
	BEGIN
		INSERT INTO @tblValidTimeSlices	(
					PLId				,
					PUId				,
					ProdId				,
					ProductGrpId		,
					TimeSliceStart		,
					TimeSliceEnd		,
					PO					)
		-- The PLId should be the one that owns the Execution Path, despite the PUId does not belong to it, 
		-- that prevents to unexpected Lines to show up in the Report.
		-- pu.PL_Id,
		SELECT	puf.PLId			,
				puf.PUId			,
				ppa.ProdId			,
				pf.ProductGrpId		,
				ppa.PPSStartTime	, 
				ppa.PPSEndTime		,
				ppa.PO				
		FROM	@tblProdPlanActive ppa					
			JOIN	@tblListPUFilter puf		ON	puf.PUId = ppa.PUId
			JOIN	@tblListProductFilter pf	ON	pf.ProdId = ppa.ProdId
												AND pf.ProductGrpId = ppa.ProductGrpId
			JOIN	dbo.Prod_Units_Base	pu			WITH (NOLOCK)	
												ON	puf.PUId = pu.PU_Id
				
	END
	ELSE
	BEGIN
	-----------------------------------------------------------------------------------------------------------------------
	--	b. GET all the product runs for the reporting period when there is no product filter
	-----------------------------------------------------------------------------------------------------------------------
		INSERT INTO @tblValidTimeSlices	(
					PLId				,
					PUId				,
					ProdId				,
					ProductGrpId		,
					TimeSliceStart		,
					TimeSliceEnd		,
					PO					)
		-- The PLId should be the one that owns the Execution Path, despite the PUId does not belong to it, 
		-- that prevents to unexpected Lines to show up in the Report.
		-- pu.PL_Id,
		SELECT	puf.PLId,
				puf.PUId,
				ppa.ProdId,
				pg.Product_Grp_Id,
				ppa.PPSStartTime, 
				ppa.PPSEndTime,
				ppa.PO		
		FROM	@tblProdPlanActive ppa				
			JOIN	@tblListPUFilter puf		ON	puf.PUId = ppa.PUId
			JOIN	dbo.Product_Group_Data pg	WITH (NOLOCK)
												ON	ppa.ProdId = pg.Prod_Id 
			JOIN	dbo.Prod_Units_Base	pu			WITH (NOLOCK)	
												ON	puf.PUId = pu.PU_Id

	END
END
-----------------------------------------------------------------------------------------------------------------------
--	RETURN an error if no slices found
-----------------------------------------------------------------------------------------------------------------------
IF	NOT EXISTS	(	SELECT	TimeSliceId
					FROM	@tblValidTimeSlices)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode = 1,
			@vchErrorMsg = 'NO time slices were found for product filter selected.'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO FINISHError
END	

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' SPLIT overlapping line status and apply line status filter if required'
--=====================================================================================================================
--	c.	SPLIT OVERLAPPING LINE STATUS AND APPLY LINE STATUS FILTER IF REQUIRED
--		c-1.	GET the list of line status 
--				Note:	new sites will not be using the dbo.Local_PG_LineStatus table, there is a new local table in the 
--						works that is supposed to be a local lines status equivalent table and is currently targeted
--						to be available in Plant Apps 4.3. If the table meets P&G requirements it will replace 
--						dbo.Local_PG_Line_Status table
--						The report type parameter Local_PG_intRptUseLocalPGLineStatusTable will identify which site 
--						will still be using the dbo.Local_PG_Line_Status
--						If the new table is NOT available when sites that have a requirement for the local line status
--						table get upgraded to Plant Apps 4.x then the logic will look for the line status PU_Id in a
--						UDP field in the dbo.Prod_Units_Base table.
--		c-2.	GET the line status for the time slice
--		c-3.	FLAG time slices that overlapping line statuses
--		c-4.	SPLIT overlapping line status

-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT	RcdIdx 
				FROM	@tblListPLStatusFilter) 
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	c-1.	GET the list of valid line status for the reporting period
	-------------------------------------------------------------------------------------------------------------------
	IF	@intRptUseLocalPGLineStatusTable = 1
	BEGIN

        INSERT INTO	@tblSchedLineStatus (
					PLStatusSchedId		, 
					PLStatusStart		,
					PLStatusEnd			, 
					PLStatusId			, 
					LineStatusPUId		, 
					PLId				,
					Processed)

			SELECT	NPDet_Id			,
					Start_Time			,
					End_Time			,
					n.Reason_Level1		,
					lp.PUId				,
					lp.PLId				,
					0
			FROM	@tblListPUFilter lp
			JOIN	dbo.NonProductive_Detail n	WITH (NOLOCK) 
													ON	lp.LineStatusPUId = n.PU_Id
													AND	((n.Start_Time < @p_vchRptStartDateTime AND n.End_Time > @p_vchRptStartDateTime AND n.End_Time < @p_vchRptEndDateTime) OR (n.Start_Time >= @p_vchRptStartDateTime AND n.End_Time <= @p_vchRptEndDateTime) OR (n.Start_Time < @p_vchRptEndDateTime AND n.Start_Time > @p_vchRptStartDateTime AND n.End_Time > @p_vchRptEndDateTime))		


		SET @idx = (SELECT MIN(RcdIdx) FROM @tblListPUFilter)
		WHILE @idx <= (SELECT MAX(RcdIdx) FROM @tblListPUFilter)
		BEGIN
			IF(SELECT COUNT(*) FROM @tblSchedLineStatus where LineStatusPUId = (select PUId FROM @tblListPUFilter WHERE RcdIdx = @idx)) = 0
			BEGIN


				INSERT INTO @tblSchedLineStatus(
							LineStatusPUId,
							PLId,
							PLStatusStart,
							PLStatusEnd,
							PLStatusId,
							Processed
							)
				SELECT
							PUId,
							PLId,
							@p_vchRptStartDateTime,
							@p_vchRptEndDateTime,
							(SELECT Event_Reason_Id FROM dbo.Event_Reasons WHERE Event_Reason_Name = @vchLineNormalDesc),
							1
				FROM	@tblListPUFilter
			END
	
			WHILE (SELECT COUNT(Processed) FROM @tblSchedLineStatus WHERE Processed = 0 AND LineStatusPUId = (select PUId FROM @tblListPUFilter WHERE RcdIdx = @idx)) > 0
				BEGIN
					
					SELECT TOP 1 
						@intCurIdx		= ls.Idx
					FROM @tblSchedLineStatus ls
					JOIN @tblListPUFilter pl ON ls.LineStatusPUId = pl.PUId
					WHERE ls.Processed = 0
			
	
					SELECT	
						@dtmLastEndTime = PLStatusEnd
					FROM	@tblSchedLineStatus ls
					JOIN @tblListPUFilter pl ON ls.LineStatusPUId = pl.PUId
					WHERE	Idx = @intLastIdx

					IF @dtmLastEndTime IS NULL
					BEGIN
						SET @dtmLastEndTime = @p_vchRptStartDateTime
					END


					IF @dtmNextStartTime IS NULL
					BEGIN
						SET @dtmNextStartTime = @p_vchRptEndDateTime
					END

					SELECT			@dtmNextStartTime = ls.PLStatusStart
					FROM	@tblSchedLineStatus ls
					JOIN @tblListPUFilter pl ON ls.LineStatusPUId = pl.PUId
					WHERE	Idx = @intCurIdx

					INSERT INTO @tblSchedLineStatus(
									LineStatusPUId,
									PLId,
									PLStatusStart,
									PLStatusEnd,
									PLStatusId,
									Processed
									)
						SELECT
									PUId,
									PLId,
									@dtmLastEndTime,
									@dtmNextStartTime,
									(SELECT Event_Reason_Id FROM dbo.Event_Reasons WHERE Event_Reason_Name = @vchLineNormalDesc),
									1
						FROM	@tblListPUFilter
						WHERE RcdIdx = @idx

					UPDATE	n
						SET		Processed = 1
						FROM	@tblSchedLineStatus n
						WHERE	Idx = @intCurIdx

					SET @intLastIdx = @intCurIdx
				END
				SET @intLastIdx = NULL
				SET @dtmLastEndTime = NULL
				SET @dtmNextStartTime = NULL
				SET @idx = @idx + 1
		END
	END
	--DELETE records that has equal starttime and endtime
	DELETE FROM @tblSchedLineStatus WHERE PLStatusStart = PLStatusEnd
	--********************************************************************
	-- ENSURE IT HAS A LINE STATUS TO THE END OF SCOPE
	--********************************************************************
	IF(SELECT MAX(PLStatusEnd) FROM @tblSchedLineStatus) <> @p_vchRptEndDateTime
	BEGIN
		SELECT	@dtmLastEndTime	= MAX(PLStatusEnd),
				@dtmNextStartTime	= @p_vchRptEndDateTime
		FROM @tblSchedLineStatus

		INSERT INTO @tblSchedLineStatus(
							LineStatusPUId,
							PLId,
							PLStatusStart,
							PLStatusEnd,
							PLStatusId,
							Processed
							)
				SELECT
							PUId,
							PLId,
							@dtmLastEndTime,
							@dtmNextStartTime,
							(SELECT Event_Reason_Id FROM dbo.Event_Reasons WHERE Event_Reason_Name = @vchLineNormalDesc),
							1
				FROM	@tblListPUFilter

	END

	-------------------------------------------------------------------------------------------------------------------
	--	c-2.	GET the line status for the time slice
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET	vt.PLStatusId = rl.PLStatusId
	FROM	@tblValidTimeSlices	vt 
		JOIN	@tblSchedLineStatus rl	ON 	vt.PLId = rl.PLId
	WHERE	vt.TimeSliceStart >= rl.PLStatusStart
		AND	vt.TimeSliceStart < rl.PLStatusEnd	
	-------------------------------------------------------------------------------------------------------------------
	--	c-3.	FLAG time slices that overlapping line statuses
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET	OverlapFlagLineStatus = rl.PLStatusSchedId,
		OverlapSequence = 1,
		OverlapRcdFlag = 1,
		SplitLineStatusFlag = 1
	FROM	@tblValidTimeSlices vt 
		JOIN	@tblSchedLineStatus rl ON vt.PLId = rl.PLId
	WHERE	vt.TimeSliceStart < rl.PLStatusStart
		AND	vt.TimeSliceEnd > rl.PLStatusStart
	-------------------------------------------------------------------------------------------------------------------
	--	c-4.	SPLIT overlapping line status
	--			by looping through the flagged records
	-------------------------------------------------------------------------------------------------------------------
	SET	@j = 1
	WHILE	@j <= 1000 
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Make a copy of the overlapping record and insert into the @tblValidTimeSlices table
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblValidTimeSlices (
					PLId,
					PUId,
					ProdId,
					ProductGrpId,
					ShiftDesc,
					CrewDesc,
					TimeSliceStart,
					TimeSliceEnd,
					OverlapFlagLineStatus,
					OverlapSequence,
					OverlapRcdFlag,
					SplitLineStatusFlag,
					PO )
		SELECT	PLId,
				PUId,
				ProdId,
				ProductGrpId,
				ShiftDesc,
				CrewDesc,
				TimeSliceStart,
				TimeSliceEnd,
				OverlapFlagLineStatus,
				2,
				1,
				1,
				PO
		FROM	@tblValidTimeSlices
		WHERE	OverlapFlagLineStatus > 0
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE the TimeSliceEnd of the first record
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	TimeSliceEnd = rl.PLStatusStart
		FROM	@tblValidTimeSlices vt
			JOIN	@tblSchedLineStatus rl 	ON 	vt.PLId = rl.PLId
												AND vt.OverlapFlagLineStatus = rl.PLStatusSchedId
												AND	vt.OverlapSequence = 1
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE the TimeSliceStart of the second record
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	TimeSliceStart 	= rl.PLStatusStart,
				PLStatusId 	= rl.PLStatusId
		FROM	@tblValidTimeSlices vt
			JOIN	@tblSchedLineStatus rl 	ON 	vt.PLId = rl.PLId
												AND vt.OverlapFlagLineStatus = rl.PLStatusSchedId
												AND	vt.OverlapSequence = 2
		---------------------------------------------------------------------------------------------------------------
		--	RESET the OverlapFlagLineStatus back to 0 
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	vt.OverlapFlagLineStatus = 0,
			vt.OverlapSequence = 0
		FROM	@tblValidTimeSlices vt
		WHERE	vt.OverlapFlagLineStatus > 0
		---------------------------------------------------------------------------------------------------------------
		--	MARK the new set of batches for splitting
		--	NOTE: a time slice may have to be split more than once
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	OverlapFlagLineStatus 	= rl.PLStatusSchedId,
			OverlapSequence 		= 1,
			SplitLineStatusFlag 	= 1
		FROM	@tblValidTimeSlices vt 
			JOIN	@tblSchedLineStatus rl ON vt.PLId = rl.PLId
		WHERE	vt.TimeSliceStart < rl.PLStatusStart
			AND	vt.TimeSliceEnd	> rl.PLStatusStart
			AND	vt.OverlapRcdFlag = 1
		---------------------------------------------------------------------------------------------------------------
		--	RESET the OverlapRcdFlag back to 0 on records that do not require further splitting
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET		OverlapRcdFlag = 0 
		FROM	@tblValidTimeSlices vt
		WHERE	vt.OverlapFlagLineStatus = 0
		---------------------------------------------------------------------------------------------------------------
		--	CHECK for if more records require splitting 
		--	IF they are loop again if they are not break out of the loop
		---------------------------------------------------------------------------------------------------------------
		IF	NOT	EXISTS	(	SELECT 	OverlapFlagLineStatus
						FROM	@tblValidTimeSlices
						WHERE	OverlapFlagLineStatus > 0)
		BEGIN
			BREAK		
		END
		---------------------------------------------------------------------------------------------------------------
		--	INCREMENT Loop COUNTer
		---------------------------------------------------------------------------------------------------------------
		SELECT	@j = @j + 1
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'WHILE Loop COUNT (Line Status): ' + CONVERT(VarChar, @j)
	-------------------------------------------------------------------------------------------------------------------
	--	APPLY LINE STATUS FILTER
	-------------------------------------------------------------------------------------------------------------------
	DELETE	vt
	FROM	@tblValidTimeSlices	vt 
		LEFT JOIN	@tblListPLStatusFilter 	ls ON 	vt.PLStatusId = ls.PLStatusId
	WHERE	ls.PLStatusId IS NULL
END

-----------------------------------------------------------------------------------------------------------------------
--	RETURN an error if no slices found
-----------------------------------------------------------------------------------------------------------------------
IF	NOT EXISTS	(	SELECT	TimeSliceId
					FROM	@tblValidTimeSlices)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode = 1,
			@vchErrorMsg = 'NO time slices were found for line status filter selected.'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO	FINISHError
END	
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' SPLIT overlapping shift and apply shift filter if required'
--=====================================================================================================================
--	d.	SPLIT OVERLAPPING SHIFTS AND APPLY SHIFT FILTER IF REQUIRED
--		d-1.	In Plant Apps 4.x there will be a dbo.Crew_Schedule configured for each PU, if no Crew schedule is found 
--				the report will return an error.
--		d-2.	GET the shift and crew for the time slice
--		d-3.	CHECK to see if there are any time slices with NULL Shifts and Crews
--		d-4.	FLAG time slices that have overlapping shifts
--		d-5.	SPLIT overlapping shifts
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT	RcdIdx 
				FROM	@tblListShiftFilter)  
	OR EXISTS	(	SELECT	RcdIdx 
					FROM	@tblListCrewFilter)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	d-2.	GET the shift and crew for the time slice
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET	vt.ShiftDesc	= cs.Shift_Desc,
		vt.CrewDesc		= cs.Crew_Desc
	FROM	@tblValidTimeSlices	vt 
		JOIN	dbo.Crew_Schedule cs WITH (NOLOCK) ON vt.PUId = cs.PU_Id
	WHERE	vt.TimeSliceStart >= cs.Start_Time
		AND	vt.TimeSliceStart <  cs.End_Time
	-------------------------------------------------------------------------------------------------------------------
	--	d-3.	CHECK to see if there are any time slices with NULL Shifts and Crews
	-------------------------------------------------------------------------------------------------------------------
	IF	EXISTS	(	SELECT	ShiftDesc
					FROM	@tblValidTimeSlices
					WHERE	ShiftDesc IS NULL)
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	GET the list of PUId's that do not have a crew schedule configured
		---------------------------------------------------------------------------------------------------------------
		TRUNCATE TABLE	#TempTable	
		INSERT INTO	#TempTable (
					ValueINT)
		SELECT	DISTINCT
				PUId
		FROM	@tblValidTimeSlices
		WHERE	ShiftDesc IS NULL

		---------------------------------------------------------------------------------------------------------------
		--	INSERT List into @tblErrorCriteria 
		--	FIND the MIN and MAX RcdIdx
		---------------------------------------------------------------------------------------------------------------
		SELECT	@i = MIN(RcdIdx),
				@intMAXRcdIdx = MAX(RcdIdx)
		FROM	#TempTable

		---------------------------------------------------------------------------------------------------------------
		--	LOOP through #TempTable and add a record to @tblErrorCriteria for each PU that is missins a crew schedule
		---------------------------------------------------------------------------------------------------------------
		WHILE	@i <= @intMAXRcdIdx
		BEGIN
			-----------------------------------------------------------------------------------------------------------
			--	GET	PUId from #TempTable
			-----------------------------------------------------------------------------------------------------------
			SELECT	@intPUId = ValueINT
			FROM	#TempTable
			WHERE	RcdIdx = @i
			-----------------------------------------------------------------------------------------------------------
			--	GET	the corresponding PU_Desc from the dbo.Prod_Units_Base table
			-----------------------------------------------------------------------------------------------------------
			SELECT	@vchPUDesc = PU_Desc
			FROM	dbo.Prod_Units_Base	WITH (NOLOCK)
			WHERE	PU_Id = @intPUId
			-----------------------------------------------------------------------------------------------------------
			--	INSERT record into @tblErrorCriteria
			-----------------------------------------------------------------------------------------------------------
			INSERT INTO	@tblErrorCriteria(
						ErrorCategory, 
						Comment1, 
						Comment2)	
			SELECT	'MISSING Configuration', 
					'No Crew Schedule found in dbo.Crew_Schedule', 
					'PU: ' + @vchPUDesc + '(PUId = ' + CONVERT(VARCHAR(50), @intPUId) + ')'
			-----------------------------------------------------------------------------------------------------------
			--	INCREMENT COUNTer
			-----------------------------------------------------------------------------------------------------------
			SET	@i = @i + 1
		END	
		---------------------------------------------------------------------------------------------------------------
		--	CATCH Error
		---------------------------------------------------------------------------------------------------------------
		SELECT	@intErrorCode = 1,
				@vchErrorMsg = 'Missing crew schedule configuration'
		---------------------------------------------------------------------------------------------------------------
		--	PRINT Error
		---------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
		---------------------------------------------------------------------------------------------------------------
		--	STOP sp execution
		---------------------------------------------------------------------------------------------------------------
		GOTO	FINISHError
	END
	-------------------------------------------------------------------------------------------------------------------
	--	d-4.	FLAG time slices that have overlapping shifts
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET	OverlapFlagShift 	= cs.CS_Id,
		OverlapSequence 	= 1,
		OverlapRcdFlag 		= 1,
		SplitShiftFlag 		= 1
	FROM	@tblValidTimeSlices vt 
		JOIN	dbo.Crew_Schedule cs 	WITH (NOLOCK)
										ON vt.PUId = cs.PU_Id
	WHERE	vt.TimeSliceStart < cs.Start_Time
		AND	vt.TimeSliceEnd > cs.Start_Time
	-------------------------------------------------------------------------------------------------------------------
	--	d-5.	SPLIT overlapping shifts
	--			by looping through the flagged records
	-------------------------------------------------------------------------------------------------------------------
	SET	@j = 1
	WHILE	@j <= 1000 
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Make a copy of the overlapping record and insert into the @tblValidTimeSlices table
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblValidTimeSlices (
					PLId,
					PUId,
					ProdId,
					ProductGrpId,
					PLStatusId,
					TimeSliceStart,
					TimeSliceEnd,
					OverlapFlagShift,
					OverlapSequence,
					OverlapRcdFlag,
					SplitShiftFlag,
					PO )
		SELECT	PLId,
				PUId,
				ProdId,
				ProductGrpId,
				PLStatusId,
				TimeSliceStart,
				TimeSliceEnd,
				OverlapFlagShift,
				2,
				1,
				1,
				PO
		FROM	@tblValidTimeSlices
		WHERE	OverlapFlagShift > 0
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE the TimeSliceEnd of the first record
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	TimeSliceEnd = cs.Start_Time
		FROM	@tblValidTimeSlices vt
			JOIN	dbo.Crew_Schedule cs 	WITH (NOLOCK)
											ON vt.PUId = cs.PU_Id
												AND vt.OverlapFlagShift = cs.CS_Id
												AND	vt.OverlapSequence = 1
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE the TimeSliceStart of the first record
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	TimeSliceStart	= cs.Start_Time,
			CrewDesc 		= cs.Crew_Desc,
			ShiftDesc		= cs.Shift_Desc
		FROM	@tblValidTimeSlices vt
			JOIN	dbo.Crew_Schedule cs 	WITH (NOLOCK)
											ON vt.PUId = cs.PU_Id
												AND vt.OverlapFlagShift = cs.CS_Id
												AND	vt.OverlapSequence = 2
		---------------------------------------------------------------------------------------------------------------
		--	RESET the OverlapFlagLineStatus back to 0 
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	vt.OverlapFlagShift = 0,
			vt.OverlapSequence = 0
		FROM	@tblValidTimeSlices vt
		WHERE	vt.OverlapFlagShift > 0
		---------------------------------------------------------------------------------------------------------------
		--	MARK the new set of batches for splitting
		--	NOTE: a time slice may have to be split more than once
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	OverlapFlagShift = cs.CS_Id,
			OverlapSequence = 1,
			SplitShiftFlag = 1
		FROM	@tblValidTimeSlices vt 
			JOIN	dbo.Crew_Schedule cs WITH (NOLOCK) ON vt.PUId = cs.PU_Id
		WHERE	vt.TimeSliceStart < cs.Start_Time
			AND	vt.TimeSliceEnd	> cs.Start_Time
			AND	vt.OverlapRcdFlag = 1
		---------------------------------------------------------------------------------------------------------------
		--	RESET the OverlapRcdFlag back to 0 on records that do not require further splitting
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	OverlapRcdFlag = 0 
		FROM	@tblValidTimeSlices vt
		WHERE	vt.OverlapFlagShift = 0
		---------------------------------------------------------------------------------------------------------------
		--	CHECK for if more records require splitting 
		--	IF there are loop again if there are not break out of the loop
		---------------------------------------------------------------------------------------------------------------
		IF	NOT EXISTS	(	SELECT 	OverlapFlagShift
							FROM	@tblValidTimeSlices
							WHERE	OverlapFlagShift > 0)
		BEGIN
			BREAK		
		END
		---------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTer
		---------------------------------------------------------------------------------------------------------------
		SELECT	@j = @j + 1
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'WHILE Loop COUNT (Shift/Crew): ' + CONVERT(VarChar, @j)
	-------------------------------------------------------------------------------------------------------------------
	--	APPLY SHIFT FILTER
	-------------------------------------------------------------------------------------------------------------------
	IF	EXISTS	(	SELECT	RcdIdx
					FROM	@tblListShiftFilter)
	BEGIN
		DELETE	vt
		FROM	@tblValidTimeSlices	vt 
			LEFT JOIN	@tblListShiftFilter lsf ON vt.ShiftDesc = lsf.ShiftDesc
		WHERE	lsf.ShiftDesc IS NULL
	END
	-------------------------------------------------------------------------------------------------------------------
	--	APPLY CREW FILTER
	-------------------------------------------------------------------------------------------------------------------
	IF	EXISTS	(	SELECT	RcdIdx
					FROM	@tblListCrewFilter)
	BEGIN
		DELETE	vt
		FROM	@tblValidTimeSlices	vt 
			LEFT JOIN	@tblListCrewFilter lcf ON vt.CrewDesc = lcf.CrewDesc
		WHERE	lcf.CrewDesc IS NULL
	END
END
-----------------------------------------------------------------------------------------------------------------------
--	RETURN an error if no slices found
-----------------------------------------------------------------------------------------------------------------------
IF	NOT EXISTS	(	SELECT	TimeSliceId
					FROM	@tblValidTimeSlices)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode = 1,
			@vchErrorMsg = 'NO time slices were found for shift/team filter selected.'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO	FINISHError
END	
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET MajorMinor Volume COUNT (could be Production or Test COUNT)'
--=====================================================================================================================
--=====================================================================================================================
-- Before calculating the volume for Major and Minor grouping we have to update the PathId column
-- in order to determine what TimeSlice has an Active Production Path. Then :
-- 1. If a TimeSlice drop into an Active Process order time slice then use the Active Path information to calculate 
--	  the volume
-- 2. No Path Active then use the Production Points for this line to calculate the Volume.
-----------------------------------------------------------------------------------------------------------------------
--DECLARE @tblTSlicePathId TABLE	(
--							TimeSliceId			INT,
--							ActivePathId		INT )
--
----INSERT INTO @tblTSlicePathId	(
----							TimeSliceId			,
----							ActivePathId				)
--SELECT						DISTINCT
--							ts.PLId					,
--							ts.TimeSliceStart		,
--							ts.TimeSliceEnd			,
--							ppa.PathId		
--FROM @tblValidTimeSlices	ts
--JOIN @tblProdPlanActive		ppa  ON ts.PLId = ppa.PLId
--								 AND ppa.PPSStartTime >= ts.TimeSliceStart
--								 AND ppa.PPSStartTime < ts.TimeSliceEnd
--JOIN @tblProdPlanPath		pp	 ON  pp.PathId = ppa.PathId
--WHERE pp.IsProductionPoint = 1

UPDATE @tblValidTimeSlices
	SET ActivePathId = ppa.PathId
FROM @tblValidTimeSlices	ts
JOIN @tblProdPlanActive		ppa  ON ts.PLId = ppa.PLId
--								 AND ts.TimeSliceStart >= ppa.PPSStartTime
--								 AND ts.TimeSliceStart < ppa.PPSEndTime
								 -- 2010-08-30 Changed the way in wich we check if the PO run drops in a Time Slice:
								 AND ppa.PPSStartTime >= ts.TimeSliceStart
								 AND ppa.PPSStartTime < ts.TimeSliceEnd
JOIN @tblProdPlanPath		pp	 ON  pp.PathId = ppa.PathId
WHERE 
-- 2010-08-30 Commented out the following line, we will not check anymore if the Path has production Points that belongs to a different Line.
pp.PLId = pp.SourcePLId AND
pp.IsProductionPoint = 1

-- If PathId = -1 it means that there was an Active Production Plan but the Production Point belongs to a 
-- different Production Line (this is a business rule that only applies to Family Care) NOT ANYMORE

-- 2010-08-30 We will keep this in case we still dont find an Active Path for any Time Slice and we will try to get the Volume from the Unit that holds the 
-- sample.
UPDATE @tblValidTimeSlices
	SET ActivePathId = -1
FROM @tblValidTimeSlices	ts
JOIN @tblListPLFilter		pl	ON	ts.PLId = pl.PLId
WHERE  IsFamilyCareLine = 1
AND    ActivePathId IS NULL

--SELECT '@tblProdPlanActive',* FROM @tblProdPlanActive WHERE PUId IN (2689,1464,1570) ORDER BY PPSStartTime
--SELECT '@tblProdPlanPath',* FROM @tblProdPlanPath
--SELECT '@tblValidTimeSlices',* FROM @tblValidTimeSlices

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' COMBINE variables and time slices'
--=====================================================================================================================
--	COMBINE VarId's and Time Slices
--	Business Rule:
--	Each variable has a different set of specs; It is necessary to get the specs for each time slices to be able to 
--	combine like spec values later in the code.
-----------------------------------------------------------------------------------------------------------------------

INSERT INTO	#ValidVarTimeSlices (
			VarId					,
			VarSpecActivation		,
			SamplingInterval		,
			PLId					,
			PUId					,
			PUGId					,
			VarGroupId				,
			SourcePUId				,
			ProdId					,
			ProductGrpId			,
			PLStatusId				,
			ShiftDesc				,
			CrewDesc				,
			TimeSliceStart			,
			TimeSliceEnd			,
--			TimeSliceVolumeCountVarId,
--			TimeSliceProductionType	,
			IsOfflineQuality		,
			OverlapFlagLineStatus	,
			OverlapFlagShift		,
			OverlapSequence 		,
			OverlapRcdFlag			,
			SplitLineStatusFlag		,
			SplitShiftFlag			,
				PathId					,
				PO					)
SELECT	ld.VarId			,
		ld.VarSpecActivation,
		ld.SamplingInterval	,
		vt.PLId				,
		vt.PUId				,
		ld.PUGId			,
		ld.VarGroupId		,
		ld.VarPUIdSource	,
		vt.ProdId			,
		vt.ProductGrpId		,
		vt.PLStatusId		,
		vt.ShiftDesc		,
		vt.CrewDesc			,
		vt.TimeSliceStart	,
		vt.TimeSliceEnd		,
--		vt.TimeSliceVolumeCountVarId,
--		vt.TimeSliceProductionType,
		ld.IsOfflineQuality	,
		vt.OverlapFlagLineStatus,
		vt.OverlapFlagShift	,
		vt.OverlapSequence	,
		vt.OverlapRcdFlag	,
		vt.SplitLineStatusFlag,
		vt.SplitShiftFlag,
				vt.ActivePathId,
				vt.PO
FROM	#ListDataSource	ld	
	JOIN	@tblValidTimeSlices	vt	ON	ld.PLId = vt.PLId
									AND	ld.VarPUId = vt.PUId
-----------------------------------------------------------------------------------------------------------------------
DELETE		#ValidVarTimeSlices
	WHERE	VarId IS NULL
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' SPLIT overlapping spec changes when spec change is inmediate'
--=====================================================================================================================
--	SPLIT OVERLAPPING SPEC CHANGES WHEN SPEC CHANGE IS INMEDIATE
--	Business Rule:
--	a.	GET the list of spec changes that overlap time slices for variables that have a spec activation = inmediate
--		(SA_Id = 1)
--	b.	FLAG time slices that have overlapping specs
--	c.	SPLIT times slices that have overlapping specs
--	NOTE: target range on active specs has been eliMINated and replace control limits; this means that we only have to
--	check for overlapping spec changes once. The PPM 3.0 version had to check for regular specs in the var_specs table
--	and target range specs in the active_specs table
-----------------------------------------------------------------------------------------------------------------------
--	a .	GET the list of spec changes that overlap time slices for variables that have a spec activation = inmediate
--		(SA_Id = 1)
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblSpecChangeOverlapList (
			ProdId,
			VarId,
			SpecChangeStart,
			SpecChangeEnd )
SELECT	vt.ProdId,
		vs.Var_Id,
		vs.Effective_Date,
		vs.Expiration_Date
FROM	#ValidVarTimeSlices	vt	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
								ON	vt.ProdId = vs.Prod_Id
								AND	vt.VarId = vs.Var_Id
								AND	vs.Effective_Date > vt.TimeSliceStart
								AND	vs.Effective_Date <	vt.TimeSliceEnd
WHERE	VarSpecActivation = 1
GROUP BY	vt.ProdId, vs.Var_Id, vs.Effective_Date, vs.Expiration_Date
-----------------------------------------------------------------------------------------------------------------------
--	b.	FLAG time slices that have overlapping specs
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT ProdId 
				FROM @tblSpecChangeOverlapList)
BEGIN
	UPDATE	vt
	SET	vt.OverlapFlagSpecChange 	= sc.SpecChangeId,
		vt.OverlapSequence			= 1,
		vt.OverlapRcdFlag			= 1,
		vt.SplitSpecChangeFlag 		= 1
	FROM	#ValidVarTimeSlices 	vt	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))	
		JOIN	@tblSpecChangeOverlapList	sc	ON	vt.ProdId = sc.ProdId
												AND	vt.VarId = sc.VarId
	WHERE	vt.TimeSliceStart 	<	sc.SpecChangeStart
		AND	vt.TimeSliceEnd		>	sc.SpecChangeStart
	-------------------------------------------------------------------------------------------------------------------
	--	c.	SPLIT overlapping specs changes
	--		by looping through the flagged records
	-------------------------------------------------------------------------------------------------------------------
	SET	@j = 1
	WHILE	@j <= 1000
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Make a copy of the overlapping record and insert into the #ValidVarTimeSlices table
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	#ValidVarTimeSlices (
					VarId,
					VarSpecActivation,
					SamplingInterval,
					PLId,
					PUId,
					PUGId,
					VarGroupId,
					SourcePUId,
					ProdId,
					ProductGrpId,
					PLStatusId,
					ShiftDesc,
					CrewDesc,
					TimeSliceStart,
					TimeSliceEnd,
					TimeSliceVolumeCountVarId,
					TimeSliceProductionType,
					IsOfflineQuality,
					OverlapFlagSpecChange,
					OverlapSequence,
					OverlapRcdFlag,
					SplitSpecChangeFlag		,
					PathId		,
					PO			)
		SELECT	VarId,
				VarSpecActivation,
				SamplingInterval,
				PLId,
				PUId,
				PUGId,
				VarGroupId,
				SourcePUId,
				ProdId,
				ProductGrpId,
				PLStatusId,
				ShiftDesc,
				CrewDesc,
				TimeSliceStart,
				TimeSliceEnd,
				TimeSliceVolumeCountVarId,
				TimeSliceProductionType,
				IsOfflineQuality,
				OverlapFlagSpecChange,
				2,
				1,
				1,
				PathId,
				PO
		FROM	#ValidVarTimeSlices
		WHERE	OverlapFlagSpecChange > 0
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE the TimeSliceEnd of the first record
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt 
		SET	TimeSliceEnd = SpecChangeStart
		FROM	#ValidVarTimeSlices	vt
			JOIN	@tblSpecChangeOverlapList sc	ON	vt.OverlapFlagSpecChange = sc.SpecChangeId  
														AND	OverlapSequence = 1
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE the TimeSliceStart of the first record
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	TimeSliceStart = SpecChangeStart
		FROM	#ValidVarTimeSlices	vt
			JOIN	@tblSpecChangeOverlapList sc	ON	vt.OverlapFlagSpecChange = sc.SpecChangeId  
														AND	OverlapSequence = 2
		---------------------------------------------------------------------------------------------------------------
		--	RESET the OverlapFlagLineStatus back to 0 
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#ValidVarTimeSlices
		SET	OverlapFlagSpecChange = 0,
			OverlapSequence = 0
		WHERE	OverlapFlagSpecChange > 0
		---------------------------------------------------------------------------------------------------------------
		--	MARK the new set of batches for splitting
		--	NOTE: a time slice may have to be split more than once
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vt
		SET	vt.OverlapFlagSpecChange = sc.SpecChangeId,
			vt.OverlapSequence = 1,
			vt.OverlapRcdFlag = 1,
			vt.SplitSpecChangeFlag = 1
		FROM	#ValidVarTimeSlices vt	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
			JOIN	@tblSpecChangeOverlapList	sc	ON	vt.ProdId = sc.ProdId
														AND	vt.VarId = sc.VarId															
		WHERE	vt.TimeSliceStart <	sc.SpecChangeStart
			AND	vt.TimeSliceEnd	>	sc.SpecChangeStart
			AND	vt.OverlapRcdFlag = 1
		---------------------------------------------------------------------------------------------------------------
		--	RESET the OverlapRcdFlag back to 0 on records that do not require further splitting
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#ValidVarTimeSlices
			SET	OverlapRcdFlag = 0
		WHERE	OverlapFlagSpecChange = 0
		---------------------------------------------------------------------------------------------------------------
		--	CHECK for if more records require splitting 
		--	IF there are loop again if there are not break out of the loop
		---------------------------------------------------------------------------------------------------------------
		IF	NOT EXISTS	(	SELECT 	OverlapFlagSpecChange
							FROM	#ValidVarTimeSlices
							WHERE	OverlapFlagSpecChange > 0)
		BEGIN
			BREAK		
		END
		---------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTer
		---------------------------------------------------------------------------------------------------------------
		SELECT	@j = @j + 1
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'WHILE Loop COUNT (SpecChange): ' + CONVERT(VarChar, @j)
	-------------------------------------------------------------------------------------------------------------------
END


--=====================================================================================================================
--  #MajorMinorVolumeCount !!
--	PRODUCTION: GET MajorMinor Volume COUNT (COULD BE PRODUCTION OR TEST COUNT)
--	Business Rule:
--	a.	Look for the production source in dbo.Prod_Units_Base.Production_Type
--	b.	If dbo.Prod_Units_Base.Production_Type = 1 then the production source is a variable and the variable will be 
--		identified in dbo.Prod_Units_Base.Production_Variable
--		Only include pu's that have IsProductionPoint = 1
--	c.	If dbo.Prod_Units_Base.Production_Type = 2 then the production source comes from dbo.Events.Initial_Dimension_X
--	d.	If dbo.Prod_Units_Base.Production_Type IS NULL then the logic will use the test COUNT for volume weighting
--		NOTE: this is will done later in the code after the time slices and variables are combined
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 0
BEGIN
--	SELECT '@vchRptMinorGroupBy',@vchRptMinorGroupBy,'@vchRptMajorGroupBy',@vchRptMajorGroupBy
	-------------------------------------------------------------------------------------------------------------------
	--	b.	If dbo.Prod_Units_Base.Production_Type = 1 then the production source is a variable and the variable will be 
	--		identified in dbo.Prod_Units_Base.Production_Variable
	--		Only include pu's that have IsProductionPoint = 1
	--  NOTE : If the Line has two producion points ( that means two variables where to take the production from)
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO @tblPUIdwithSamples (
							PUId		,
							PLId	)
	SELECT DISTINCT			PUId		,
							PLId	
	FROM 					#ValidVarTimeSlices

--	 SELECT '@tblPUIdwithSamples',pu_desc,puws.* 
--	 FROM @tblPUIdwithSamples   puws
--				JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)
--										ON pu.PU_Id = puws.PUId

	IF CHARINDEX('PUId', @vchRptMinorGroupBy) > 0 OR CHARINDEX('PUId', @vchRptMajorGroupBy) > 0 
	BEGIN
					INSERT INTO	#MajorMinorVolumeCount (				
											PLId					,
											PLDesc					,
											ProdId					,
											PUId					,
											PUDesc					,
											ProductGrpId			,
											TimeSliceStart			,
											TimeSliceEnd			,
											ActivePathId		)
					SELECT		DISTINCT	tvt.PLId					,
											pl.PL_Desc					,
											tvt.ProdId					,
											tvt.PUId					,
											pu.PU_Desc					,
											tvt.ProductGrpId			,
											tvt.TimeSliceStart			,
											tvt.TimeSliceEnd			,
											tvt.ActivePathId			
					FROM    @tblValidTimeSlices tvt
							JOIN	@tblPUIdwithSamples puws ON puws.PUId = tvt.PUId	
															 AND  tvt.PLId = puws.PLId  -- 20100902	
							JOIN    @tblListPUFilter puf ON puws.PUId = puf.PUId
							JOIN 	dbo.Prod_Lines_Base	pl WITH (NOLOCK)
														ON puws.PLId = pl.PL_Id
							JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)
														ON pu.PU_Id = puws.PUId
	END
	ELSE IF CHARINDEX('PathId', @vchRptMinorGroupBy) > 0
	BEGIN
					INSERT INTO	#MajorMinorVolumeCount (				
											PLId					,
											PathId					,
											PathDesc				,
											PLDesc					,
											ProdId					,
											ProductGrpId			,
											TimeSliceStart			,
											TimeSliceEnd			,
											ActivePathId		)
					SELECT		DISTINCT	tvt.PLId					,
											pp.PathId					,
											pp.PathDesc					,
											pl.PL_Desc					,
											tvt.ProdId					,
											tvt.ProductGrpId			,
											tvt.TimeSliceStart			,
											tvt.TimeSliceEnd			,
											NULL -- tvt.ActivePathId			
					FROM    @tblValidTimeSlices tvt	
					JOIN	@tblPUIdwithSamples puws ON puws.PUId = tvt.PUId	
															 AND  tvt.PLId = puws.PLId  -- 20100902	
					JOIN	@tblProdPlanPath    pp	   ON   -- tvt.PUId = pp.PUId AND 
													   tvt.PLId = pp.PLId
					JOIN 	dbo.Prod_Lines_Base	pl WITH (NOLOCK)
													   ON tvt.PLId = pl.PL_Id

	END
	ELSE
	BEGIN

					INSERT INTO	#MajorMinorVolumeCount (				
											PLId					,
											PLDesc					,
											ProdId					,
											PO						,
											ProductGrpId			,
											TimeSliceStart			,
											TimeSliceEnd			,
											ActivePathId		)
					SELECT		DISTINCT	tvt.PLId					,
											pl.PL_Desc					,
											tvt.ProdId					,
											tvt.PO						,
											tvt.ProductGrpId			,
											tvt.TimeSliceStart			,
											tvt.TimeSliceEnd			,
											tvt.ActivePathId			
					FROM    @tblValidTimeSlices tvt	
					JOIN	@tblPUIdwithSamples puws ON puws.PUId = tvt.PUId	
													 AND puws.PLId = tvt.PLId -- 20100811
					JOIN 	dbo.Prod_Lines_Base	pl WITH (NOLOCK)
														ON tvt.PLId = pl.PL_Id

	END
	--------------------------------------------------------------------------------------------------------------------------------
	-- Volume Calculation for #MajorMinorVolumeCount	!!
	-- When the report has a Minor Group as PUId, then the JOIN has to be done by PUId in order to consider for each Production Unit
	-- only the Production Point that belongs to itself.
	IF CHARINDEX('PUId', @vchRptMinorGroupBy) > 0
	BEGIN
				-- Bussines Rule : each Prod Unit that has its own Production VarId drives it's volume by it's own variable
				UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> mm.TimeSliceStart
																						AND	t.Result_On <= mm.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	mm.ProdId = vs.Prod_ID
																						AND (t.Result_On > vs.Effective_Date AND 
																						(t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
													WHERE	mm.PUId = lp.PUId AND
													mm.PLId = lp.PLId
													),
					    CountsForMajor	= (CASE lp.IsProductionPoint WHEN 1 THEN 1 ELSE 0 END)
				FROM #MajorMinorVolumeCount mm
				JOIN @tblListPUFilter		lp		ON		lp.PLId = mm.PLId
															AND lp.PUId = mm.PUId
				WHERE ProductionVarId IS NOT NULL

				UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																						AND	t.Result_On <= vts.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	vts.ProdId = vs.Prod_ID
																						
													WHERE	vts.PUId = lp.PUId AND
													vts.PLId = lp.PLId
													AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
													)
				FROM 	#ValidVarTimeSlices		vts
				JOIN @tblListPUFilter		lp		ON		lp.PLId = vts.PLId
															AND lp.PUId = vts.PUId
				WHERE ProductionVarId IS NOT NULL

				-- Bussines Rule : for the Prod Units that does not have their own Production Var Id, the have to use the 
				-- Execution Path IsProduction Point.
			    UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> mm.TimeSliceStart
																						AND	t.Result_On <= mm.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	mm.ProdId = vs.Prod_ID
																						AND (t.Result_On > vs.Effective_Date AND 
																						(t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
													WHERE lp.IsProductionPoint = 1	AND
													mm.PLId = lp.PLId													
													),
					    CountsForMajor	= 0
				FROM #MajorMinorVolumeCount mm
				JOIN @tblListPUFilter		lp		ON		lp.PLId = mm.PLId
															AND lp.PUId = mm.PUId
				WHERE ProductionVarId IS NULL		

				UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																						AND	t.Result_On <= vts.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	vts.ProdId = vs.Prod_ID
																						
													WHERE lp.IsProductionPoint = 1	AND
													vts.PLId = lp.PLId				
													AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
													)
				FROM 	#ValidVarTimeSlices		vts
				JOIN @tblListPUFilter		lp		ON		lp.PLId = vts.PLId
															AND lp.PUId = vts.PUId
				WHERE ProductionVarId IS NULL		
				-- For the major volume count, only the Production Units that are Production Points on the Execution Path, counts for
				-- production volume.
	END
	-- If the Report is grouped by Path then use the Path information to get the Volume.
	ELSE IF @vchRptMinorGroupBy = 'PathId'
	BEGIN
			UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
														FROM    @tblProdPlanPath  pp
														JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> mm.TimeSliceStart
																							AND	t.Result_On <= mm.TimeSliceEnd
																							AND	t.Var_Id = pp.ProductionVarId
											 												AND	Canceled = 0
											 												AND	ISNumeric(Result) = 1 
														LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																							ON	pp.ProductionVarId = vs.Var_Id
																							AND	mm.ProdId = vs.Prod_ID
																							AND (t.Result_On > vs.Effective_Date AND 
																						    (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
														WHERE mm.PLId =	pp.PLId	AND
														mm.PathId = pp.PathId AND
														pp.IsProductionPoint = 1
 														)
			FROM #MajorMinorVolumeCount mm


			UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
														FROM    @tblProdPlanPath  pp
														JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																							AND	t.Result_On <= vts.TimeSliceEnd
																							AND	t.Var_Id = pp.ProductionVarId
											 												AND	Canceled = 0
											 												AND	ISNumeric(Result) = 1 
														LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																							ON	pp.ProductionVarId = vs.Var_Id
																							AND	vts.ProdId = vs.Prod_ID
																							
														WHERE vts.PLId	=	pp.PLId	AND
														vts.PathId = pp.PathId AND
														pp.IsProductionPoint = 1
														AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
 														)
				FROM 	#ValidVarTimeSlices		vts
	END
	ELSE IF @vchRptMinorGroupBy = 'PO'
	BEGIN
				-- If the Report is grouped by PO then calculate volume in the regular way
				-- Use the Production Point for that Line 
				UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> mm.TimeSliceStart
																						AND	t.Result_On <= mm.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	mm.ProdId = vs.Prod_ID
																						AND (t.Result_On > vs.Effective_Date AND 
																						(t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
													WHERE	mm.PLId	=	lp.PLId AND
													lp.IsProductionPoint = 1												
													)
				FROM #MajorMinorVolumeCount mm

				UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																						AND	t.Result_On <= vts.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	vts.ProdId = vs.Prod_ID
																						
													WHERE	vts.PLId	=	lp.PLId AND
													lp.IsProductionPoint = 1	
													AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
													)
				FROM #ValidVarTimeSlices vts
	END
	ELSE
	BEGIN
				-- If the Time Slice does not have an Active Production Path:
				-- Use the Production Point for that Line 
				UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> mm.TimeSliceStart
																						AND	t.Result_On <= mm.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	mm.ProdId = vs.Prod_ID
																						AND (t.Result_On > vs.Effective_Date AND 
																						(t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
													WHERE	mm.PLId	=	lp.PLId AND
													lp.IsProductionPoint = 1												
													)
				FROM #MajorMinorVolumeCount mm
				WHERE ActivePathId IS NULL

				UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblListPUFilter lp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																						AND	t.Result_On <= vts.TimeSliceEnd
																						AND	t.Var_Id = lp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	lp.ProductionVarId = vs.Var_Id
																						AND	vts.ProdId = vs.Prod_ID
																						
													WHERE	vts.PLId	=	lp.PLId AND
													lp.IsProductionPoint = 1	
													-- ## NEW
													AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
													-- ##
													)
				FROM #ValidVarTimeSlices vts
				WHERE PathId IS NULL

				-- If the Time Slice DOES have an Active Production Path, use the Path information to calculate the volume

				UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblProdPlanPath  pp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> mm.TimeSliceStart
																						AND	t.Result_On <= mm.TimeSliceEnd
																						AND	t.Var_Id = pp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	pp.ProductionVarId = vs.Var_Id
																						AND	mm.ProdId = vs.Prod_ID
																						AND (t.Result_On > vs.Effective_Date AND 
																						(t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
													WHERE mm.PLId	=	pp.PLId	AND
--													vts.PathId = pp.PathId AND
													pp.PathId IN -- (76,77) AND
																 (SELECT PathId FROM @tblProdPlanActive WHERE PLId = mm.PLId 
																										AND   PUId = pp.PUId
																										AND	  PPSStartTime > = mm.TimeSliceStart
																										AND   PPSStartTime < mm.TimeSliceEnd)
													AND pp.IsProductionPoint = 1
 													)
				FROM #MajorMinorVolumeCount mm
				WHERE ActivePathId IS NOT NULL

				UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
													FROM    @tblProdPlanPath  pp
													JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																						AND	t.Result_On <= vts.TimeSliceEnd
																						AND	t.Var_Id = pp.ProductionVarId
											 											AND	Canceled = 0
											 											AND	ISNumeric(Result) = 1 
													LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																						ON	pp.ProductionVarId = vs.Var_Id
																						AND	vts.ProdId = vs.Prod_ID
																						
													WHERE vts.PLId	=	pp.PLId	AND
--													vts.PathId = pp.PathId AND
													pp.PathId IN -- (76,77) AND
																 (SELECT PathId FROM @tblProdPlanActive WHERE PLId = vts.PLId 
																										AND   PUId = pp.PUId
																										AND	  PPSStartTime > = vts.TimeSliceStart
																										AND   PPSStartTime < vts.TimeSliceEnd)
													AND pp.IsProductionPoint = 1
													-- ## NEW
													AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
													-- ## 
 													)
				FROM #ValidVarTimeSlices vts
				WHERE PathId IS NOT NULL

				-- If the Time Slice DOES have an Active Production Path, but the Production Point does not belong to the Line then 
				-- the Production Unit that holds the sample should have the Volume (Family Care specific).
				-- 2010-05-11 Only include Production Units that have samples.
				UPDATE  #MajorMinorVolumeCount						
					SET MajorMinorVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
														FROM    dbo.Prod_Units_Base	pu WITH(NOLOCK)	
														JOIN    @tblValidTimeSlices vts		ON  pu.PU_Id = vts.PUId															
														JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																							AND	t.Result_On <= vts.TimeSliceEnd
																							AND	t.Var_Id = pu.Production_Variable
											 												AND	Canceled = 0
											 												AND	ISNumeric(Result) = 1 
														LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																							ON	pu.Production_Variable = vs.Var_Id
																							AND	vts.ProdId = vs.Prod_ID
																							AND (t.Result_On > vs.Effective_Date AND 
																						    (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL))
														WHERE 
														mm.ProdId = vts.ProdId					AND
														mm.ProductGrpId = vts.ProductGrpId		AND	
														mm.TimeSliceStart = vts.TimeSliceStart	AND
														mm.TimeSliceEnd	= vts.TimeSliceEnd		AND									
														mm.PLId = vts.PLId						AND
														pu.PU_Id IN (SELECT DISTINCT VarPUId FROM #ListDataSource))
				FROM #MajorMinorVolumeCount mm
				WHERE ActivePathId = -1 

				UPDATE #ValidVarTimeSlices
							SET TimeSliceVolumeCount = (SELECT	SUM(CONVERT(FLOAT,t.Result) * ISNULL(CONVERT(FLOAT,vs.Target),1000.0) / 1000.0)
														FROM    dbo.Prod_Units_Base	pu WITH(NOLOCK)	
														JOIN    #ValidVarTimeSlices vts		ON  pu.PU_Id = vts.PUId															
														JOIN	dbo.Tests t WITH (NOLOCK)	ON	t.Result_On	> vts.TimeSliceStart
																							AND	t.Result_On <= vts.TimeSliceEnd
																							AND	t.Var_Id = pu.Production_Variable
											 												AND	Canceled = 0
											 												AND	ISNumeric(Result) = 1 
														LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
																							ON	pu.Production_Variable = vs.Var_Id
																							AND	vts.ProdId = vs.Prod_ID
																							
														WHERE vts.TimeSliceId = vvts.TimeSliceId
														AND ((t.Result_On > vs.Effective_Date AND (t.Result_On <= vs.Expiration_Date OR vs.Expiration_Date IS NULL)) OR vs.Effective_Date IS NULL)
																							
																							)
				FROM #ValidVarTimeSlices vvts
				WHERE PathId = -1 
	END
	--
	--
	UPDATE  #MajorMinorVolumeCount						
		SET MajorMinorVolumeCount = ISNULL(MajorMinorVolumeCount,0)
	--=====================================================================================================================
	-- To avoid Volume inflation when several production units contain variables, split the Major and Minor grouping in
	-- sepparate tables.
	-- FRio : 2009-09-18
	-- Only include in the #MajorVolumeCount the Volume from PU's that are flagged as ProductionPoints.
	IF CHARINDEX(@vchRptMajorGroupBy,'PUId') > 0
	BEGIN

				INSERT INTO 		#MajorVolumeCount (
									PLId							,
									PUId							,
									ProdId							,
									ProductGrpId					,
									TimeSliceStart					,
									TimeSliceEnd					,
									MajorMinorVolumeCount			)
				SELECT				
									PLId							,
									PUId							,
									ProdId							,
									ProductGrpId					,
									TimeSliceStart					,
									TimeSliceEnd					,
									MajorMinorVolumeCount	
				FROM    			#MajorMinorVolumeCount

	END
	ELSE
	BEGIN
	INSERT INTO 		#MajorVolumeCount (
						PLId							,
						ProdId							,
						ProductGrpId					,
						TimeSliceStart					,
						TimeSliceEnd					,
						MajorMinorVolumeCount			)
	SELECT				DISTINCT 
						PLId							,
						ProdId							,
						ProductGrpId					,
						TimeSliceStart					,
						TimeSliceEnd					,
						-- SUM(ISNULL(MajorMinorVolumeCount,0))	
						MajorMinorVolumeCount	
	FROM    			#MajorMinorVolumeCount
--	GROUP BY			PLId,ProdId,ProductGrpId
	WHERE				CountsForMajor = 1
	END

END
--
--
--SELECT '@tblListPUFilter',* FROM @tblListPUFilter ORDER BY PLId
--SELECT '@tblValidTimeSlices'	,* FROM @tblValidTimeSlices ORDER BY PUId, TimeSliceStart
--SELECT '#MajorMinorVolumeCount'	,* FROM #MajorMinorVolumeCount ORDER BY PathId,PathDesc, TimeSliceStart
--SELECT '#MajorVolumeCount'		,* FROM #MajorVolumeCount ORDER BY PLId, TimeSliceStart

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' LOOP Trough Time Slices and Get Test Count'
--=====================================================================================================================
--	LOOP Trough Time Slices and Get Production Count and Test Count
--	Note: changed this section of code to use functions because the test counts where incorrect
--	a.	GET Production Count when Production comes from a variable
--	b.	GET Production Count when Production comes from event initial dimension x
--	c.	GET TimeSlice Test Count
--	x.	UPDATE time slice
-----------------------------------------------------------------------------------------------------------------------
--	Initialize variable
-----------------------------------------------------------------------------------------------------------------------
SELECT	@i					= 1,
		@intMaxTimeSliceId 	= MAX(TimeSliceId)
FROM	#ValidVarTimeSlices
-----------------------------------------------------------------------------------------------------------------------
--	LOOP through time slices
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMaxTimeSliceId
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Initialize variables
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@fltProductionCount 		= NULL,
			@intTestCountResultNOTNULL 	= 0,
			@intTestCountResultNULL 	= 0,
			@intTestCountTotal		 	= 0,
			@intTimeSliceId 			= 0,
			@intProductionVarId 		= 0,
			@intProductionType			= 0,
			@intTestVarId				= 0,
			@intIsOfflineQuality		= 0,
			@intTimeSlicePUId			= 0,
			@dtmTimeSliceStart			= NULL,
			@dtmTimeSliceEnd			= NULL
	-------------------------------------------------------------------------------------------------------------------
	--	Get Time Slice values
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intTimeSliceId 		= TimeSliceId,
			@intProductionVarId 	= TimeSliceVolumeCountVarId,
			@intTestVarId			= VarId,
			@intProductionType		= TimeSliceProductionType,
			@intIsOfflineQuality	= IsOfflineQuality,
			@intTimeSlicePUId		= PUId,
			@dtmTimeSliceStart		= TimeSliceStart,
			@dtmTimeSliceEnd		= TimeSliceEnd
	FROM	#ValidVarTimeSlices
	WHERE	TimeSliceId = @i

	-------------------------------------------------------------------------------------------------------------------
	--	c.	GET TimeSlice Test Count
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intTestCountResultNOTNULL 	= TestCountResultNOTNULL	,
			@intTestCountResultNULL		= TestCountResultNULL		,
			@intTestCountTotal			= TestCountTotal
	FROM	dbo.fnLocal_NormPPM_GetTimeSliceTestCount (@intTestVarId, @intTimeSlicePUId, @intIsOfflineQuality, @dtmTimeSliceStart, @dtmTimeSliceEnd)
	-------------------------------------------------------------------------------------------------------------------
	--	x.	UPDATE time slice
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#ValidVarTimeSlices
		SET	-- TimeSliceVolumeCountVariable	= @fltProductionCount,
			TestCountResultNOTNULL			= @intTestCountResultNOTNULL,
			TestCountResultNULL				= @intTestCountResultNULL,
			TestCountTotal					= @intTestCountTotal
	WHERE	TimeSliceId = @intTimeSliceId
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT counter
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END

--===================================================================================== ================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET TimeSlice Volume COUNT for volume weighting'
--=====================================================================================================================

-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 0
BEGIN

	-------------------------------------------------------------------------------------------------------------------
	--	UPDATE	TimeSliceVolumeCount = COALESCE(TimeSliceVolumeCountVariable, TimeSliceVolumeCountEvent)
	-------------------------------------------------------------------------------------------------------------------
 	UPDATE	#ValidVarTimeSlices
		SET	TimeSliceVolumeCountVariable = TimeSliceVolumeCount
 		-- SET	TimeSliceVolumeCount = COALESCE((TimeSliceVolumeCountVariable * TimeSliceVolumeCountMSUConvFactor), TimeSliceVolumeCountEvent)	
	-------------------------------------------------------------------------------------------------------------------
	--	CHECK for NULL Production COUNT and use test COUNT if Production COUNT is NULL
	-------------------------------------------------------------------------------------------------------------------


	INSERT INTO	@SUMTimeSliceVolumeCount
		SELECT SUM(TimeSliceVolumeCount),SUM(TestCountTotal)
				FROM	#ValidVarTimeSlices
				GROUP BY PLId
	

	IF	EXISTS(SELECT	SUMTimeSliceVolumeCount
				FROM	@SUMTimeSliceVolumeCount
				WHERE	ISNULL(SUMTimeSliceVolumeCount,0) = 0
				AND		SUMTimeSliceTestCount	<> 0)
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Change volume weight option to 1
		---------------------------------------------------------------------------------------------------------------
		SET	@intRptVolumeWeightOption = 1 -- Volumen weight using test COUNT
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE TimeSliceVolume COUNT with test COUNT
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#ValidVarTimeSlices
			SET	TimeSliceVolumeCount = TestCountTotal
		---------------------------------------------------------------------------------------------------------------
		--	PRINT Message
		---------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT	'	Production COUNT = 0 Volume weight option has been switched to use Test COUNT' 
	END
END
ELSE
BEGIN

	-------------------------------------------------------------------------------------------------------------------
	--	UPDATE TimeSliceVolume COUNT with test COUNT
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#ValidVarTimeSlices
		SET	TimeSliceVolumeCount = TestCountTotal

END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Time Slice specs'
--=====================================================================================================================
--	GET TIME SLICE SPECS
--	a.	Update spec limits, spec versions and test frequency for non-numeric variables
--	b.	Update spec limits, spec versions and test frequency for normal numeric variables (Norm=Y)
--	c.	Update spec limits, spec versions and test frequency for non-normal numeric variables (Norm=N)
--	d.	Update spec limits, spec versions and test frequency for offline quality variables
-- 	NOTE:	Update of Spec limits has been change to use the TimeSliceStart field to deterMINe SpecVersion
-- 			instead of TestValue. The reason for this switch was to ensure that the same spec version 
-- 			were calculated by both the #CalcPPM logic and the #ValidTimeSlice logic. The problem with
-- 			disimilar spec version arouse when ClosetTestValues did not have specs.
-----------------------------------------------------------------------------------------------------------------------
--	a.	Update specs limits and spec versions for non-numeric variables
-----------------------------------------------------------------------------------------------------------------------
UPDATE	vt
SET	LSL				= vs.L_Reject,
	Target 			= vs.Target,
	USL				= vs.U_Reject,
	SpecVersion		= CONVERT(VARCHAR(35), vs.Effective_Date, 121),
	SpecTestFreq 	= vs.Test_Freq,
	TestFreq 		= ISNULL(COALESCE(vs.Test_Freq, ld.ExtendedTestFreq),0) -- Avoid TestFreq been NULL
																			-- Causes obsolete variables to show.
FROM	#ValidVarTimeSlices vt 		WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
	JOIN	#ListDataSource	ld		ON 	vt.PLId =  ld.PLId
										AND	vt.VarId = ld.VarId							
	LEFT JOIN	dbo.Var_Specs vs	WITH (NOLOCK)
									ON 	vt.VarId =  vs.Var_Id
										AND	vt.ProdId = vs.Prod_Id
										AND	vt.TimeSliceStart >= vs.Effective_Date
										AND	(vt.TimeSliceStart <  vs.Expiration_Date 
										OR 	vs.Expiration_Date IS NULL)
WHERE	ld.IsNumericDataType = 0
	AND	ld.IsOfflineQuality = 0
	AND	vt.TimeSliceEliminationFlag	= 0
-----------------------------------------------------------------------------------------------------------------------
--	a.1	Check for TAMU Site Logic
-----------------------------------------------------------------------------------------------------------------------

UPDATE	ld
		SET IsTAMUVariable = 1
FROM	#ValidVarTimeSlices vt 		WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
JOIN	#ListDataSource	ld		ON 	vt.PLId =  ld.PLId
										AND	vt.VarId = ld.VarId			
WHERE   (LSL IS NOT NULL
		 OR USL IS NOT NULL)
AND	ld.IsNumericDataType = 0
AND	ld.IsOfflineQuality = 0

-----------------------------------------------------------------------------------------------------------------------
--	b.	Update specs limits and spec versions for normal numeric variables (UDP IsNonNormal=0)
-----------------------------------------------------------------------------------------------------------------------
UPDATE		vt
	SET		LSL				= vs.L_Reject,		
			Target			= vs.Target,
			USL				= vs.U_Reject,
			LTL				= vs.L_User,
			UTL				= vs.U_User,
			SpecVersion		= CONVERT(VARCHAR(25), vs.Effective_Date, 121),
			SpecTestFreq 	= vs.Test_Freq,
			TestFreq 		= COALESCE(vs.Test_Freq, ld.ExtendedTestFreq)
FROM		#ValidVarTimeSlices vt 	WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
	JOIN	#ListDataSource	ld		ON 	vt.PLId = ld.PLId
										AND	vt.VarId = ld.VarId
	LEFT JOIN	dbo.Var_Specs vs 	WITH (NOLOCK)
									ON 	vt.VarId = 	vs.Var_Id
										AND	vt.ProdId = vs.Prod_Id
										AND	vt.TimeSliceStart >= vs.Effective_Date
										AND	(vt.TimeSliceStart < vs.Expiration_Date 
										OR vs.Expiration_Date IS NULL)
WHERE	ld.IsNumericDataType = 1
	AND	ld.IsNonNormal = 0
	AND	ld.IsOfflineQuality = 0
	AND	vt.TimeSliceEliminationFlag	= 0

-----------------------------------------------------------------------------------------------------------------------
--	c.	Update specs limits and spec versions for non-normal numeric variables (UDP IsNonNormal=1)
-----------------------------------------------------------------------------------------------------------------------
UPDATE	vt
SET		LEL				= COALESCE(vs.L_Entry, '1.0e-300'),			
		LSL				= vs.L_Reject,		
		Target			= vs.Target,
		USL				= vs.U_Reject,
		UEL				= COALESCE(vs.U_Entry, '1.0e+300'),		
		LTL				= vs.L_User,
		UTL				= vs.U_User,
		SpecVersion		= CONVERT(VARCHAR(35), vs.Effective_Date, 121),
		SpecTestFreq 	= vs.Test_Freq,
		TestFreq 		= COALESCE(vs.Test_Freq, ld.ExtendedTestFreq)
FROM	#ValidVarTimeSlices vt 		WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
	JOIN	#ListDataSource	ld		ON 	vt.PLId = ld.PLId
										AND	vt.VarId = ld.VarId
	LEFT JOIN	dbo.Var_Specs vs	WITH (NOLOCK)
									ON 	vt.VarId = 	vs.Var_Id
										AND	vt.ProdId = vs.Prod_Id
										AND	vt.TimeSliceStart >= vs.Effective_Date
										AND	(vt.TimeSliceStart < vs.Expiration_Date 
										OR vs.Expiration_Date IS NULL)
WHERE	ld.IsNumericDataType = 1
	AND	ld.IsNonNormal = 1
	AND	ld.IsOfflineQuality = 0
	AND	vt.TimeSliceEliminationFlag	= 0



-----------------------------------------------------------------------------------------------------------------------
--	d.	Update spec limits, spec versions and test frequency for offline quality variables
--		Business Rules:
--		For offline quality variables the code must trace back to the production event and use the EventTimeStamp
--		to figure out the product and the specs
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @tblOfflineQualityTimeSliceList ( 
			TimeSliceId		,
			TimeSliceStart	,
			TimeSliceEnd	,
			SamplePUId		,
			VarId			)
SELECT	TimeSliceId		,
		TimeSliceStart	,
		TimeSliceEnd	,
		PUId			,
		VarId			
FROM	#ValidVarTimeSlices vt 	-- WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
	WHERE	IsOfflineQuality = 1
-----------------------------------------------------------------------------------------------------------------------
--	Loop through the slices and find the source product and specs
-----------------------------------------------------------------------------------------------------------------------
--	INITIALIZE Variables
-----------------------------------------------------------------------------------------------------------------------
SELECT	@i = 1,
		@intMaxRcdIdx = MAX(RcdIdx)
FROM	@tblOfflineQualityTimeSliceList
-----------------------------------------------------------------------------------------------------------------------
--	LOOP
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMaxRcdIdx
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	INITIALIZE LOOP Variables
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intTimeSliceId			= TimeSliceId		,
			@dtmTimeSliceStart		= TimeSliceStart	,
			@dtmTimeSliceEnd		= TimeSliceEnd		,
			@intSamplePUId			= SamplePUId		,
			@intVarId				= VarId					
	FROM	@tblOfflineQualityTimeSliceList	
	WHERE	RcdIdx = @i
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intIsNumericDataType	= IsNumericDataType	,
			@intIsNonNormal			= IsNonNormal			
	FROM	#ListDataSource
	WHERE	VarId = @intVarId
	-------------------------------------------------------------------------------------------------------------------
	--	CALL Function to get the product that was running on the source PU for the variable
	--	NOTE: the  product and specs come from the production event not the UDE event. The time stamp used to look for
	--	product and specs in the EventTimeStamp
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intProdId			= 0		,
			@vchLEL				= NULL	,
			@vchLSL				= NULL	,
			@vchTarget			= NULL	,
			@vchUSL				= NULL	,
			@vchUEL				= NULL	,
			@vchLTL				= NULL	,
			@vchUTL				= NULL	,
			@vchSpecVersion		= NULL	,
			@intSpecTestFreq 	= 0		,
			@intTestFreq 		= 0		,
			@intErrorCode		= NULL	,
			@vchErrorMsg		= NULL	 
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intProdId			= ProdId		,
			@vchLEL				= LEL			,
			@vchLSL				= LSL			,
			@vchTarget			= Target		,
			@vchUSL				= USL			,
			@vchUEL				= UEL			,
			@vchLTL				= LTL			,
			@vchUTL				= UTL			,
			@vchSpecVersion		= SpecVersion	,
			@intSpecTestFreq 	= SpecTestFreq	,
			@intTestFreq 		= TestFreq		,
			@intErrorCode		= ErrorCode		,
			@vchErrorMsg		= ErrorMsg	 
	FROM	fnLocal_NormPPM_GetOfflineQualitySpecs (@intSamplePUId, @intVarId, @dtmTimeSliceStart, @dtmTimeSliceEnd)
	-------------------------------------------------------------------------------------------------------------------
	--	UPDATE	non-numeric variables
	-------------------------------------------------------------------------------------------------------------------
	IF	(	@intIsNumericDataType	= 0	
		AND @intIsNonNormal			= 0)			
	BEGIN
		UPDATE	vt
			SET	SourceProdId    = @intProdId		,
				Target 			= @vchTarget		,
			 	SpecVersion		= @vchSpecVersion	,
			 	SpecTestFreq 	= @intSpecTestFreq	,
			 	TestFreq 		= @intTestFreq
		 FROM	#ValidVarTimeSlices vt 		-- WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		 WHERE	vt.TimeSliceId = @intTimeSliceId
	END
	-------------------------------------------------------------------------------------------------------------------
	--	UPDATE	numeric normal variables
	-------------------------------------------------------------------------------------------------------------------
	IF	(	@intIsNumericDataType 	= 1	
		AND @intIsNonNormal			= 0)	
	BEGIN
		UPDATE	vt
			SET	SourceProdId	= @intProdId		,
				LSL				= @vchLSL			,		
				Target			= @vchTarget		,
				USL				= @vchUSL			,
				LTL				= @vchLTL			,
				UTL				= @vchUTL			,
				SpecVersion		= @vchSpecVersion	,
				SpecTestFreq 	= @intSpecTestFreq	,
				TestFreq 		= @intTestFreq
		FROM	#ValidVarTimeSlices vt 	-- WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		WHERE	vt.TimeSliceId = @intTimeSliceId
	END
	-------------------------------------------------------------------------------------------------------------------
	--	UPDATE	numeric non-normal variables
	-------------------------------------------------------------------------------------------------------------------
	IF	(	@intIsNumericDataType 	= 1	
		AND @intIsNonNormal			= 1)	
	BEGIN
		UPDATE	vt
		SET		SourceProdId	= @intProdId		,
				LEL				= COALESCE(@vchLEL, '1.0e-300'),			
				LSL				= @vchLSL			,		
				Target			= @vchTarget		,
				USL				= @vchUSL			,
				UEL				= COALESCE(@vchUEL, '1.0e+300'),		
				LTL				= @vchLTL			,
				UTL				= @vchUTL			,
				SpecVersion		= @vchSpecVersion	,
				SpecTestFreq 	= @intSpecTestFreq	,
				TestFreq 		= @intTestFreq
		FROM	#ValidVarTimeSlices vt 	-- WITH (INDEX (ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		WHERE	vt.TimeSliceId = @intTimeSliceId
	END
	-------------------------------------------------------------------------------------------------------------------
	--	INITIALIZE COUNTER
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FLAG time slices that meet eliMINation criteria'
--=====================================================================================================================
--	FLAG TIME SLICES THAT MEET ELIMINATION CRITERIA
--	a.	EliMINate Slices where production COUNT is NULL if volume weighting is set to production COUNT
--	b.	EliMINate Slices where TestCountResultNOTNULL = 0 and TestCountResultNULL > 0 
--	c.	EliMINate Slices where TestFreq = 0 AND TestCountResultNOTNULL IS NULL AND TestCountResultNULL IS NULL
--	d.	EliMINate Slices where Sampling Interval IS NULL 	
--	e.	EliMINate time slides where TestCountResultNOTNULL = 0, TestCountResultNULL = 0 AND SamplingInterval = 0
-----------------------------------------------------------------------------------------------------------------------
--	a.	EliMINinate Slices where production COUNT is NULL if volume weighting is set to production COUNT
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 0
BEGIN
	UPDATE		vt
	SET		TimeSliceEliminationFlag	=	1,
			TimeSliceEliminationReason	=	@ConTimeSliceEliminationReason7
	FROM	#ValidVarTimeSlices	vt
	WHERE	vt.TimeSliceVolumeCount IS NULL
		AND	vt.TimeSliceEliminationFlag = 0
END
-----------------------------------------------------------------------------------------------------------------------
--	b.	EliMINate Slices where TestCountResultNOTNULL = 0 and TestCountResultNULL > 0 
-----------------------------------------------------------------------------------------------------------------------
UPDATE	vt
SET		TimeSliceEliminationFlag	= 1,
		TimeSliceEliminationReason	= @ConTimeSliceEliminationReason1
FROM	#ValidVarTimeSlices	vt
WHERE	vt.TestCountResultNOTNULL 	= 0
	AND	vt.TestCountResultNULL		> 0
	AND	vt.TimeSliceEliminationFlag = 0
-----------------------------------------------------------------------------------------------------------------------
--	c.	EliMINate Slices where TestFreq = 0 AND TestCountResultNOTNULL IS NULL AND TestCountResultNULL IS NULL
-----------------------------------------------------------------------------------------------------------------------
  UPDATE	vt
  SET		TimeSliceEliminationFlag	=	1,
		TimeSliceEliminationReason	=	@ConTimeSliceEliminationReason2
  FROM	#ValidVarTimeSlices	vt
  WHERE	vt.TestFreq = 0
	AND	vt.TestCountResultNOTNULL 	IS NULL
	AND	vt.TestCountResultNULL 		IS NULL
	AND	vt.TimeSliceEliminationFlag = 0
-----------------------------------------------------------------------------------------------------------------------
--	d.	EliMINate Slices where Sampling Interval IS NULL 
-----------------------------------------------------------------------------------------------------------------------
UPDATE	vt
SET		TimeSliceEliminationFlag	=	1,
		TimeSliceEliminationReason	=	@ConTimeSliceEliminationReason3
FROM	#ValidVarTimeSlices	vt
WHERE	vt.SamplingInterval IS NULL
	AND	vt.TimeSliceEliminationFlag = 0
-----------------------------------------------------------------------------------------------------------------------
--	e.	EliMINate time slides where TestCountResultNOTNULL = 0, TestCountResultNULL = 0 AND SamplingInterval = 0
--		NOTE: these time slices are eliMINated because MAXSamplingInterval = TimeSliceInterval and
-- 		there are no test available during that interval
-----------------------------------------------------------------------------------------------------------------------
UPDATE	vt
SET		TimeSliceEliminationFlag	=	1,
		TimeSliceEliminationReason	=	@ConTimeSliceEliminationReason4
FROM	#ValidVarTimeSlices	vt
WHERE	vt.TestCountResultNOTNULL IS NULL
	AND	vt.TestCountResultNULL IS NULL
	AND	vt.TestFreq > 0
	AND	vt.SamplingInterval = 0
	AND	vt.TimeSliceEliminationFlag = 0


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' SELECT time slices that need further analysis'
--=====================================================================================================================
--	SELECT TIME SLICES THAT NEED FURTHER ANALYSIS
--	a.	CALCULATE the MAXimum sampling radius	
--	b.	COUNT number of tests in sampling radius
--	c.	UPDATE Test COUNT for Each Time Slice
--	d.	ELIMINATE Time Sliced where MSRTestCountResultNOTNULL = 0 AND MSRTestCountResultNULL > 0
--	e.	ELIMINATE Time Sliced where MSRTestCountResultNOTNULL IS NULL AND MSRTestCountResultNULL IS NULL 
--	f.	FIND closest test value to the left of the time slice
--	g.	FIND closest test value to the right of the time slice
--	h.	UPDATE closest test value when TestValue1 is NOT NULL and TestValue2 is NOT NULL
-- 	i.	UPDATE closest test value when TestValue1 is NOT NULL and TestValue2 is NULL
-- 	j.	UPDATE closest test value when TestValue1 is NULL and TestValue2 is NOT NULL
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT	TimeSliceId
				FROM	#ValidVarTimeSlices
				WHERE	TestCountResultNOTNULL 	IS NULL
					AND	TestCountResultNULL		IS NULL
					AND	TestFreq > 0
					AND	TimeSliceEliminationFlag = 0 )
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	a.	CALCULATE the MAXimum sampling radius	
	-- 		NOTE: Note: sampling interval and extended_test_freq are set at the variable level and are 
	-- 		not product specific. Test_freq is set at the var_specs level and is product specific. 
	-- 		Because of this sampling interval is often set to 60 MIN multiplied by the test_freq to 
	-- 		deterMINe the sampling interval for a given product.
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET		MAXSamplingRadiusStart 	= 	DATEADD(MINUTE, (-vt.SamplingInterval * vt.TestFreq), vt.TimeSliceStart),
			MAXSamplingRadiusEnd	=	DATEADD(MINUTE, ( vt.SamplingInterval * vt.TestFreq), vt.TimeSliceEnd)
	FROM	#ValidVarTimeSlices	vt		
	WHERE	vt.TestCountResultNOTNULL IS NULL
		AND	vt.TestCountResultNULL IS NULL
		AND	vt.TestFreq > 0
		AND	vt.TimeSliceEliminationFlag = 0
	-------------------------------------------------------------------------------------------------------------------
	--	b.	COUNT number of tests in sampling radius
	-------------------------------------------------------------------------------------------------------------------
 	DELETE		@tblValidTimeSlicesTestCount
 	INSERT INTO	@tblValidTimeSlicesTestCount (
 				TimeSliceId					,
 				MSRTestCountResultNOTNULL	,
 				MSRTestCountResultNULL		)
 	SELECT	TimeSliceId,
			SUM(	CASE	WHEN	t.Result IS NOT NULL
							THEN	1
							ELSE	0
							END),
			SUM(	CASE	WHEN	t.Result IS NULL
							THEN	1
							ELSE	0
			END)
	FROM	#ValidVarTimeSlices	vt	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		JOIN	#ListDataSource		ds	ON 	vt.VarId = ds.VarId
		JOIN	dbo.Tests			t	WITH (NOLOCK)
										ON	t.Result_On	>= vt.MAXSamplingRadiusStart
											AND	t.Result_On < vt.MAXSamplingRadiusEnd
											AND	t.Var_Id = ds.VarId
 	GROUP BY	vt.TimeSliceId
	-------------------------------------------------------------------------------------------------------------------
	--	c.	UPDATE Test COUNT for Each Time Slice
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET		vt.MSRTestCountResultNOTNULL = vtstc.MSRTestCountResultNOTNULL,
			vt.MSRTestCountResultNULL = vtstc.MSRTestCountResultNULL
	FROM	#ValidVarTimeSlices	vt	-- WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		JOIN	@tblValidTimeSlicesTestCount vtstc	ON	vt.TimeSliceId = vtstc.TimeSliceId
	-------------------------------------------------------------------------------------------------------------------
	--	d.	ELIMINATE Time Sliced where MSRTestCountResultNOTNULL = 0 AND MSRTestCountResultNULL > 0
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET		TimeSliceEliminationFlag = 1,
			TimeSliceEliminationReason = @ConTimeSliceEliminationReason5
	FROM	#ValidVarTimeSlices	vt
	WHERE	vt.MSRTestCountResultNOTNULL = 0
		AND	vt.MSRTestCountResultNULL > 0
		AND	vt.TestCountResultNOTNULL IS NULL
		AND	vt.TestCountResultNULL IS NULL
		AND	vt.TestFreq > 0
		AND	vt.TimeSliceEliminationFlag = 0
	-------------------------------------------------------------------------------------------------------------------
	--	e.	ELIMINATE Time Sliced where MSRTestCountResultNOTNULL IS NULL AND MSRTestCountResultNULL IS NULL 
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET	TimeSliceEliminationFlag = 1,
		TimeSliceEliminationReason = @ConTimeSliceEliminationReason6
	FROM	#ValidVarTimeSlices	vt
	WHERE	vt.MSRTestCountResultNOTNULL IS NULL
		AND	vt.MSRTestCountResultNULL IS NULL
		AND	vt.TestCountResultNOTNULL IS NULL
		AND	vt.TestCountResultNULL IS NULL
		AND	vt.TestFreq > 0
		AND	vt.TimeSliceEliminationFlag = 0
	-------------------------------------------------------------------------------------------------------------------
	--	f.	FIND closest test value to the left of the time slice
	-------------------------------------------------------------------------------------------------------------------
	DELETE	@tblTempTests
	INSERT INTO	@tblTempTests (
				VarId,
				TimeSliceId,
				ResultOn)
	SELECT	vt.VarId,
			vt.TimeSliceId,
			MAX(t.Result_On)
	FROM	#ValidVarTimeSlices	vt
		JOIN	dbo.Tests t	WITH (NOLOCK)
							ON	vt.VarId =	t.Var_Id
								AND	t.Result_On >= vt.MAXSamplingRadiusStart
								AND	t.Result_On < vt.TimeSliceStart
								AND	t.Result IS NOT NULL
								AND	MSRTestCountResultNOTNULL > 0
	GROUP BY	vt.VarId, vt.TimeSliceId
	-----------------------------------------------------------------------------------------------
	UPDATE	vt
	SET	TestValue1			=	t.Result,
		TestValue1TimeStamp	=	tt.ResultOn,
		DateDiff1InSec		=	DATEDIFF(SECOND, tt.ResultOn, vt.TimeSliceStart)
	FROM	@tblTempTests		tt
		JOIN	#ValidVarTimeSlices	vt	ON	tt.TimeSliceId = vt.TimeSliceId
		JOIN	dbo.Tests			t	WITH (NOLOCK)
										ON	vt.VarId	=	t.Var_Id
											AND	tt.ResultON	=	t.Result_On
	-------------------------------------------------------------------------------------------------------------------
	--	g.	FIND closest test value to the right of the time slice
	-------------------------------------------------------------------------------------------------------------------
	DELETE	@tblTempTests
	INSERT INTO	@tblTempTests (
				VarId,
				TimeSliceId,
				ResultOn)
	SELECT	vt.VarId,
			vt.TimeSliceId,
			MIN(t.Result_On)
	FROM	#ValidVarTimeSlices	vt	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		JOIN	dbo.Tests			t	WITH (NOLOCK)
										ON	vt.VarId = t.Var_Id
											AND	t.Result_On < vt.MAXSamplingRadiusEnd
											AND	t.Result_On >= vt.TimeSliceEnd
											AND	t.Result IS NOT NULL
											AND	MSRTestCountResultNOTNULL > 0
	GROUP BY	vt.VarId, vt.TimeSliceId
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	vt
	SET		TestValue2			=	t.Result,
			TestValue2TimeStamp	=	tt.ResultOn,
			DateDiff2InSec		=	DATEDIFF(SECOND, vt.TimeSliceStart, tt.ResultOn)
	FROM	@tblTempTests		tt
		JOIN	#ValidVarTimeSlices	vt	-- WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
										ON	tt.TimeSliceId = vt.TimeSliceId
		JOIN	dbo.Tests			t	WITH (NOLOCK)
										ON	vt.VarId = t.Var_Id
											AND	tt.ResultON	= t.Result_On
	-------------------------------------------------------------------------------------------------------------------
	--	h.	UPDATE closest test value when TestValue1 is NOT NULL and TestValue2 is NOT NULL
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#ValidVarTimeSlices
	SET		ClosestTestValue			=	CASE	WHEN	DateDiff1InSec	>	DateDiff2InSec
													THEN	TestValue2
													ELSE	TestValue1
													END,
			ClosestTestValueTimeStamp	=	CASE	WHEN	DateDiff1InSec	>	DateDiff2InSec
													THEN	TestValue2TimeStamp
													ELSE	TestValue1TimeStamp
													END
	WHERE	MSRTestCountResultNOTNULL	> 0
		AND		TestValue1 IS NOT NULL
		AND		TestValue2 IS NOT NULL
	-------------------------------------------------------------------------------------------------------------------
	--	i.	UPDATE closest test value when TestValue1 is NOT NULL and TestValue2 is NULL
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#ValidVarTimeSlices
	SET		ClosestTestValue			=	TestValue1,
			ClosestTestValueTimeStamp	=	TestValue1TimeStamp
	WHERE	MSRTestCountResultNOTNULL	> 0
		AND		TestValue2 IS NULL
	-------------------------------------------------------------------------------------------------------------------
	--	j.	UPDATE closest test value when TestValue1 is NULL and TestValue2 is NOT NULL
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#ValidVarTimeSlices
	SET		ClosestTestValue			=	TestValue2,
			ClosestTestValueTimeStamp	=	TestValue2TimeStamp
	WHERE	MSRTestCountResultNOTNULL	> 0
		AND		TestValue1 IS NULL
END


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CHECK for bad test data (where test data like "%,%" '
--=====================================================================================================================
--	CHECK FOR BAD TEST DATA (where test data like "%,%")
--	EnCOUNTered this situation a some sites, if bad data is found the PPM calculations will crash
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblBadDataList (
			VarId,
			VarDesc,
			Result,
			ResultTimeStamp )
SELECT	ds.VarId,
		ds.VarDesc,
		t1.Result,
		CONVERT(VARCHAR(35), t1.Result_On, 121)
FROM	#ValidVarTimeSlices	vt 
	JOIN	#ListDataSource		ds	ON 	vt.VarId = ds.VarId
	JOIN	dbo.Tests			t1	WITH (NOLOCK)
									ON	t1.Result_On >=	vt.TimeSliceStart
										AND	t1.Result_On <	vt.TimeSliceEnd
										AND	t1.Var_Id = ds.VarId
WHERE	ds.VarDataTypeId IN (2, 7)
	AND	t1.Result LIKE '%,%'
	AND	vt.TimeSliceEliminationFlag = 0
-----------------------------------------------------------------------------------------------------------------------
--	RETURN AN ERROR IF BAD DATA IS FOUND
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT	VarId
				FROM	@tblBadDataList)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode = 2,
			@vchErrorMsg = 'BAD Data found.'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO	FINISHError
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET MajorMinor Test COUNT when volumn weight option is test COUNT'
--=====================================================================================================================
--	GET MajorMinor TEST COUNT WHEN VOLUME WEIGHT OPTION IS TEST COUNT
-- TODO: this needs to be modified to only look for distinct time stamps.
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 1
BEGIN

		-- Just in case the Line had some Volume
		DELETE FROM #MajorMinorVolumeCount
		DELETE FROM #MajorVolumeCount
		-- This makes no sense so far
		INSERT INTO	#MajorMinorVolumeCount (	
					TimeSliceId,
					PLId,
					PLDesc,
					PUId,
					PUDesc,
					ProductGrpId,
					ProdId,
					TestCount)
			SELECT	vt.TimeSliceId,
				vt.PLId,
				pl.PL_Desc,
				vt.PUId,
				pu.PU_Desc,
				vt.ProductGrpId,
				vt.ProdId,
				SUM(CONVERT(FLOAT, TestCountTotal))
		FROM	#ValidVarTimeSlices	vt
			JOIN dbo.Prod_Lines_Base	pl	WITH(NOLOCK)
									ON vt.PLId = pl.PL_Id
			JOIN dbo.Prod_Units_Base pu	WITH(NOLOCK)
									ON pu.PU_Id = vt.PUId
			GROUP BY	vt.TimeSliceId, vt.PLId, pl.PL_Desc, vt.ProductGrpId, vt.ProdId, vt.PUId, pu.PU_Desc

		UPDATE	#MajorMinorVolumeCount
				SET	MajorMinorVolumeCount = TestCount
		-- Here, by each combination the TestCount should be
		-- MAX(Attr) + MAX(Var)
		INSERT INTO #MajorVolumeCount (
						TimeSliceStart					,
						TimeSliceEnd					,
						PLId							,
						PLDesc							,
						ProdId							,
						ProductGrpId					,
						ProductionCountVariable			,
						ProductionCountEvent			,
						TestCount						,
						MajorMinorVolumeCount			)
		SELECT	DISTINCT
						TimeSliceStart					,
						TimeSliceEnd					,
						mmvc.PLId						,
						PLDesc							,
						ProdId							,
						ProductGrpId					,
						ProductionCountVariable			,
						ProductionCountEvent			,
						TestCount						,
						MajorMinorVolumeCount			 
		FROM    #MajorMinorVolumeCount mmvc

-- SELECT '#MajorMinorVolumeCount',* FROM #MajorMinorVolumeCount
-- SELECT '#MajorVolumeCount',* FROM #MajorVolumeCount

END	


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET MajorMinor Production COUNT for volume weighting'
--=====================================================================================================================
--	GET MajorMinor PRODUCTION COUNT FOR VOLUME WEIGHTING
--  This has been eliminated.
--  We will only leave the Options when the volume weight turns to samplecount.
-----------------------------------------------------------------------------------------------------------------------

IF	@intRptVolumeWeightOption =  1
BEGIN
	UPDATE	#MajorMinorVolumeCount
		SET	MajorMinorVolumeCount = TestCount
END
--=====================================================================================================================
--------------------------------------------------------------------------------------------------------------------------------
-- If the parameter used to give an extra Sheet witht the Raw data used to calculate the volume is set to 1
-- then build the Raw Data into the #ExcelVolumeCheck temporary table
--------------------------------------------------------------------------------------------------------------------------------	
IF	(@intRptWithDataValidationExtended = 1) AND 	(@intRptVolumeWeightOption = 0)
BEGIN  
	INSERT INTO #ExcelVolumeCheck	(
				TimeSliceStart					,
				TimeSliceEnd					,
				PLId							,
				PLDesc							,
				ProdId							,
				ProductGrpId					,
				PUId							,
				PUDesc							,
				ProductionVarId					)
	SELECT	
				TimeSliceStart					,
				TimeSliceEnd					,
				lp.PLId							,
				PLDesc							,
				ProdId							,
				ProductGrpId					,
				PUId							,
				PUDesc							,
				lp.ProductionVarId
				FROM    #MajorMinorVolumeCount		mm	--			ON 	mm.PLId = lp.PLId
				JOIN    (SELECT PLId, ProductionVarId FROM @tblListPUFilter 
							WHERE   IsProductionPoint = 1
							AND     ProductionVarId IS NOT NULL)	lp	ON 	mm.PLId = lp.PLId


				UPDATE #ExcelVolumeCheck
						SET Volume		= (SELECT SUM(CONVERT(FLOAT,t.Result))				
										   FROM	dbo.Tests t WITH (NOLOCK)	
										   WHERE	t.Result_On	> ex.TimeSliceStart
														AND	t.Result_On <= ex.TimeSliceEnd
														AND	t.Var_Id = ex.ProductionVarId
						 								AND	Canceled = 0
						 								AND	ISNumeric(Result) = 1) 
				FROM   #ExcelVolumeCheck ex

				UPDATE #ExcelVolumeCheck
						SET MSUConversionFactor	= 	ISNULL(CONVERT(FLOAT,vs.Target),1.0)
				FROM   #ExcelVolumeCheck ex
				LEFT	JOIN	dbo.Var_Specs	vs	WITH (NOLOCK)
														ON	ex.ProductionVarId = vs.Var_Id
														AND	ex.ProdId = vs.Prod_ID
														AND vs.Expiration_Date IS NULL

				UPDATE #ExcelVolumeCheck
						SET TotalVolume = ISNULL(Volume,0.0) * ISNULL(MSUConversionFactor,1.0)

				-- SELECT '#ExcelVolumeCheck',* FROM #ExcelVolumeCheck

END
-- End of Debugging to Excel
--------------------------------------------------------------------------------------------------------------------------------

--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' MAJOR GROUP INFO'
--=====================================================================================================================
--	MAJOR GROUP INFO
-- 	a.	CALCULATE production for Production Major Group
-- 	b.	ASSIGN major group id's to the time slices
--	c.	Check for Major Groups with repeating names
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Calculate production for Production Major Group'
--=====================================================================================================================
-- 	a.	Calculate production for Production Major Group
-----------------------------------------------------------------------------------------------------------------------
SET	@nvchSQLCommand  = ''
SET	@nvchSQLCommand1 = ''
SET	@nvchSQLCommand2 = ''
SET	@nvchSQLCommand3 = ''
SET	@nvchSQLCommand4 = ''
SET	@nvchSQLCommand5 = ''

--=====================================================================================================================
-- BUILDING TESTING SCENARIO
-----------------------------------------------------------------------------------------------------------------------
-- When the Weighting turns to Test Count then it should be aggregated by PUG; and get the MAX test count on that Group
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'NONE' 
BEGIN
				INSERT INTO	#MajorGroupList	(
							MajorGroupVolumeCount )
				SELECT	SUM(MajorMinorVolumeCount)
				FROM	#MajorVolumeCount mm
END
ELSE
BEGIN
		SET	@nvchSQLCommand1 = 'INSERT INTO	#MajorGroupList ( '
		SET	@nvchSQLCommand2 = 'SELECT '
		SET	@nvchSQLCommand3 = 'FROM	#MajorVolumeCount	mmvc ' 
		SET	@nvchSQLCommand4 = 'GROUP BY '
		SET	@nvchSQLCommand5 = 'ORDER BY '
		-------------------------------------------------------------------------------------------------------------------
		IF	CHARINDEX('PLId', @vchRptMajorGroupBy) > 0 
		BEGIN
				SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'PLId, PLDesc, '
				SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'mmvc.PLId, pl.PL_Desc, '
				SET	@nvchSQLCommand3 = @nvchSQLCommand3 + 'JOIN dbo.Prod_Lines_Base pl	WITH (NOLOCK) ON mmvc.PLId = pl.PL_Id	'
				SET	@nvchSQLCommand4 = @nvchSQLCommand4 + 'mmvc.PLId, pl.PL_Desc, '
				SET	@nvchSQLCommand5 = @nvchSQLCommand5 + 'pl.PL_Desc, '
		END
		-------------------------------------------------------------------------------------------------------------------
		IF	CHARINDEX('ProductGrpId', @vchRptMajorGroupBy) > 0 
		BEGIN
				SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ProductGrpId, ProductGrpDesc, '
				SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'mmvc.ProductGrpId, gp.Product_Grp_Desc, '
				SET	@nvchSQLCommand3 = @nvchSQLCommand3 + 'JOIN	dbo.Product_Groups gp WITH (NOLOCK) ON mmvc.ProductGrpId = gp.Product_Grp_Id '
				SET	@nvchSQLCommand4 = @nvchSQLCommand4 + 'mmvc.ProductGrpId, gp.Product_Grp_Desc, '
				SET	@nvchSQLCommand5 = @nvchSQLCommand5 + 'gp.Product_Grp_Desc, '
		END
		-------------------------------------------------------------------------------------------------------------------
		IF	CHARINDEX('ProdId', @vchRptMajorGroupBy) > 0 
		BEGIN
				SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ProdId, ProdCode, '
				SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'mmvc.ProdId, p.Prod_Code, '
				SET	@nvchSQLCommand3 = @nvchSQLCommand3 + 'JOIN	dbo.Products_Base p WITH (NOLOCK) ON mmvc.ProdId = p.Prod_Id '
				SET	@nvchSQLCommand4 = @nvchSQLCommand4 + 'mmvc.ProdId, p.Prod_Code, '
				SET	@nvchSQLCommand5 = @nvchSQLCommand5 + 'p.Prod_Code, '
		END
		-------------------------------------------------------------------------------------------------------------------
		IF	CHARINDEX('PUId', @vchRptMajorGroupBy) > 0 
		BEGIN
				SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'mmvc.PUId, PUDesc, '
				SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'mmvc.PUId, pu.PU_Desc, '
				SET	@nvchSQLCommand3 = @nvchSQLCommand3 + 'JOIN	dbo.Prod_Units_Base pu WITH (NOLOCK) ON mmvc.PUId = pu.PU_Id '
				SET	@nvchSQLCommand4 = @nvchSQLCommand4 + 'mmvc.PUId, pu.PU_Desc, '
				SET	@nvchSQLCommand5 = @nvchSQLCommand5 + 'mmvc.PUId, '
		END
		-------------------------------------------------------------------------------------------------------------------
		SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'MajorGroupVolumeCount )'
		SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'SUM(MajorMinorVolumeCount) '
		SET	@nvchSQLCommand4 = LTRIM(RTRIM(@nvchSQLCommand4))
		SET	@nvchSQLCommand4 = SUBSTRING(@nvchSQLCommand4, 1, LEN(@nvchSQLCommand4) - 1)
		SET	@nvchSQLCommand5 = LTRIM(RTRIM(@nvchSQLCommand5))
		SET	@nvchSQLCommand5 = SUBSTRING(@nvchSQLCommand5, 1, LEN(@nvchSQLCommand5) - 1)
		-------------------------------------------------------------------------------------------------------------------
		--	Assemble SQL statement
		-------------------------------------------------------------------------------------------------------------------
		SET	@nvchSQLCommand = @nvchSQLCommand1 + ' ' + @nvchSQLCommand2 + ' ' + @nvchSQLCommand3 + ' ' + @nvchSQLCommand4 + ' ' + @nvchSQLCommand5
		-------------------------------------------------------------------------------------------------------------------
		--	PRINT SQL statement
		-------------------------------------------------------------------------------------------------------------------
		-- IF @intPRINTFlag = 1	  PRINT	'MajorGroupBy = ' + @nvchSQLCommand
		-------------------------------------------------------------------------------------------------------------------
		--	EXECUTE SQL statement
		-------------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
END


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ASSIGN major group ids to the time slices'
--=====================================================================================================================
-- 	b.	ASSIGN major group id's to the time slices
--		NOTE:	the reason why we update both #ValidVarTimeSlices and #MajorMinorVolumeCount is because the valid time 
--				slices is a cartesian product between variables and time slices and the major/Minor volume COUNT looks
--				only at the master list of time slices before the cartesian product. This is done this way to prevent
--				duplication of production COUNT
-----------------------------------------------------------------------------------------------------------------------
--		INITIALIZE variables
-----------------------------------------------------------------------------------------------------------------------
SET	@nvchSQLCommand1 = ''
SET	@nvchSQLCommand2 = ''
-----------------------------------------------------------------------------------------------------------------------
--		Major Group Id = NONE
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'None'
BEGIN
	UPDATE	#ValidVarTimeSlices
		SET	MajorGroupId = 1
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#MajorMinorVolumeCount
		SET	MajorGroupId = 1	
END
ELSE
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--		Major Group Id <> NONE
	-------------------------------------------------------------------------------------------------------------------
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE statement to update #ValidVarTimeSlices
	-------------------------------------------------------------------------------------------------------------------
	SET	@nvchSQLCommand1 =	'	UPDATE	vt '
			+ 				' 	SET 	vt.MajorGroupId = ma.MajorGroupId '
			+				'	FROM	#ValidVarTimeSlices 	vt WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))'
			+				'	JOIN	#MajorGroupList	ma ON '
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE statement to update #MajorMinorVolumeCount
	-------------------------------------------------------------------------------------------------------------------
	SET	@nvchSQLCommand2 = 	'	UPDATE	mm '
			+ 				' 	SET 	mm.MajorGroupId = ma.MajorGroupId '
			+				'	FROM	#MajorMinorVolumeCount	mm '
			+				'	JOIN	#MajorGroupList		ma ON '
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE statement when Major Group include PLId
	-------------------------------------------------------------------------------------------------------------------
	SET	@intBitAND = 0
	IF	CHARINDEX('PLId', @vchRptMajorGroupBy) > 0 
	BEGIN
		SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ma.PLId = vt.PLId '
		SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'ma.PLId = mm.PLId '
		SET	@intBitAND = 1
	END
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE statement when Major Group include Production Unit ID
	-------------------------------------------------------------------------------------------------------------------
	-- Fized: 5.1	2015-01-16	Pablo Galanzini	 Fix a bug when the Major is used with two or more Majors. (the variable @intBitAND was wrong set)
	--SET	@intBitAND = 0
	IF	CHARINDEX('PUId', @vchRptMajorGroupBy) > 0 
	BEGIN
		SET	@nvchSQLCommand1 = @nvchSQLCommand1 + ' ma.PUId = vt.PUId '
		SET	@nvchSQLCommand2 = @nvchSQLCommand2 + ' ma.PUId = mm.PUId '
		SET	@intBitAND = 1
	END
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE statement when Major Group include ProductGrpId
	-------------------------------------------------------------------------------------------------------------------
	IF	CHARINDEX('ProductGrpId', @vchRptMajorGroupBy) > 0 
	BEGIN
		IF	@intBitAND = 1
		BEGIN
			SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'AND ma.ProductGrpId = vt.ProductGrpId '
			SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'AND ma.ProductGrpId = mm.ProductGrpId '
		END
		ELSE
		BEGIN
			SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ma.ProductGrpId = vt.ProductGrpId '
			SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'ma.ProductGrpId = mm.ProductGrpId '
			SET	@intBitAND = 1
		END
	END
	-------------------------------------------------------------------------------------------------------------------
	--	PREPARE statement when Major Group include ProdId
	-------------------------------------------------------------------------------------------------------------------
	IF	CHARINDEX('ProdId', @vchRptMajorGroupBy) > 0 
	BEGIN
		IF	@intBitAND = 1
		BEGIN
			SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'AND ma.ProdId = vt.ProdId '
			SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'AND ma.ProdId = mm.ProdId '
		END
		ELSE
		BEGIN
			SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ma.ProdId = vt.ProdId '
			SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'ma.ProdId = mm.ProdId '
			SET	@intBitAND = 1
		END
	END
END
-----------------------------------------------------------------------------------------------------------------------
--		EXECUTE DYNAMIC SQL
-----------------------------------------------------------------------------------------------------------------------
EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand1
EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand2
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CHECK for Major Groups with repeating names'
--=====================================================================================================================
--	c.	Check for Major Groups with repeating names
--		NOTE: there is a limit in Excel of ~ 30 characters for a tab name, when we truncate the major group desc to
--		30 characters it is possible to get a major group desc that repeates itself.
--		This section of code acCOUNTs for repeating name and adds a (x) to the name to make it unique. x = a sequence
--		number
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'None'
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'None'
BEGIN
	UPDATE	#MajorGroupList
		SET	MajorGroupDesc = 'All'
END

-----------------------------------------------------------------------------------------------------------------------
-- NOTE : The MajorGroupDesc will be used later to set the SheetNames, and it should not exceed 50 characters !!!!!!!!!
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'PLId
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'PLId'
BEGIN
	UPDATE	#MajorGroupList
		SET	MajorGroupDesc = PLDesc
END
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'PUId
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'PUId'
BEGIN
	UPDATE	#MajorGroupList
		SET	MajorGroupDesc = PUDesc
END
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'ProductGrpId
--  Bath Tissue:Charmin Ultra Stro
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'ProductGrpId'
BEGIN
	UPDATE	#MajorGroupList
		SET	MajorGroupDesc = CASE	WHEN	LEN(ProductGrpDesc)	>	30
									THEN	SUBSTRING(ProductGrpDesc, 1, 27)
									ELSE	ProductGrpDesc
							 END
END
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'ProdId
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'ProdId'
BEGIN
	UPDATE	#MajorGroupList
		SET	MajorGroupDesc = ProdCode
END
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'PLId|ProductGrpId'
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'PLId|ProductGrpId'
BEGIN
	UPDATE	#MajorGroupList
	SET	MajorGroupDesc =	CASE	WHEN	LEN(PLDesc + '(' + ProductGrpDesc + ')')	>	30
									THEN	SUBSTRING(PLDesc + '(' + ProductGrpDesc, 1, 27)
									ELSE	PLDesc + '(' + ProductGrpDesc + ')'
									END
END
-----------------------------------------------------------------------------------------------------------------------
--	Major group desc when @vchRptMajorGroupBy = 'PLId|PLDesc|ProductGrpId'
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'PLId|PLDesc|ProductGrpId'
BEGIN
	UPDATE	#MajorGroupList
	SET	MajorGroupDesc =	CASE	WHEN	LEN(PLDesc + '(' + ProductGrpDesc + ')')	>	30
									THEN	SUBSTRING(PLDesc + '(' + ProductGrpDesc, 1, 27)
									ELSE	PLDesc + '(' + ProductGrpDesc + ')'
									END
END

-----------------------------------------------------------------------------------------------------------------------
--	Look for repeating names
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblMajorGroupTemp (
 			MajorGroupDesc,
 			DescCOUNT)
SELECT	MajorGroupDesc,
		COUNT(MajorGroupDesc)
FROM	#MajorGroupList
GROUP BY	MajorGroupDesc

-----------------------------------------------------------------------------------------------------------------------
--	IF repeating names exists loop through temp table and make them unique
--	ELSE continue
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT	DescCOUNT
				FROM	@tblMajorGroupTemp
				WHERE	DescCOUNT > 1)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	INITIALIZE variables
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@i = 1,
			@intMAXRcdIdx = MAX(RcdIdx)
	FROM	@tblMajorGroupTemp
	-------------------------------------------------------------------------------------------------------------------
	--	LOOP through table records
	-------------------------------------------------------------------------------------------------------------------
	WHILE	@i <= @intMAXRcdIdx
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	CHECK DescCOUNT
		---------------------------------------------------------------------------------------------------------------		
		SELECT	@intDescCOUNT = DescCOUNT,
				@vchMajorGroupDesc = MajorGroupDesc
		FROM	@tblMajorGroupTemp
		WHERE	RcdIdx = @i
		---------------------------------------------------------------------------------------------------------------
		--	IF	DescCOUNT > 1 THEN 
		--	a.	Clear table and reset identity field
		--	b.	GET list of Major Group Id's that share the major group desc
		--	c.	UPDATE major group desc
		---------------------------------------------------------------------------------------------------------------
		IF	@intDescCOUNT > 1
		BEGIN
			-----------------------------------------------------------------------------------------------------------
			--	a.	Clear table and reset identity field
			-----------------------------------------------------------------------------------------------------------
			TRUNCATE TABLE	#TempValue
			-- SET IDENTITY_INSERT #TempValue ON
			-- INSERT INTO	#TempValue	(
			--			RcdIdx)
			-- VALUES	(0)
			-- SET IDENTITY_INSERT #TempValue OFF
			-----------------------------------------------------------------------------------------------------------
			--	b.	GET list of Major Group Id's that share the major group desc
			-----------------------------------------------------------------------------------------------------------
			INSERT INTO	#TempValue	(
						ValueINT)	
			SELECT	MajorGroupId
			FROM	#MajorGroupList WITH (NOLOCK)
		 	WHERE	MajorGroupDesc = @vchMajorGroupDesc
			-----------------------------------------------------------------------------------------------------------
			--	c.	UPDATE major group desc
			-----------------------------------------------------------------------------------------------------------
			UPDATE	mg
				SET	MajorGroupDesc = MajorGroupDesc + ' (' + CONVERT(VARCHAR(25), RcdIdx) + ')'
			FROM	#MajorGroupList	mg	WITH (NOLOCK)
				JOIN	#TempValue	tv	ON	mg.MajorGroupId = tv.ValueINT
			WHERE	tv.RcdIdx > 0

		END
		---------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTer
		---------------------------------------------------------------------------------------------------------------
		SET	@i = @i + 1
	END
END

--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' MINOR GROUP INFO'
--=====================================================================================================================
--	Minor GROUP INFO
-- 	a.	Calculate production by production Minor Group
-- 	b.	ASSIGN Minor group id's to the time slices
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Calculate production for Production Minor Group'
--=====================================================================================================================
-- 	a.	Calculate production for Production Minor Group
-----------------------------------------------------------------------------------------------------------------------
SET	@nvchSQLCommand  = ''
SET	@nvchSQLCommand1 = ''
SET	@nvchSQLCommand2 = ''
SET	@nvchSQLCommand3 = ''
SET	@nvchSQLCommand1 = 'INSERT INTO	#MinorGroupList ( MajorGroupId, '
-- ACA pgalanzi
SET	@nvchSQLCommand2 = 'SELECT TOP '+ CONVERT(VARCHAR, @intMaxGroup) +' MajorGroupId, '
-- SET	@nvchSQLCommand2 = 'SELECT MajorGroupId, '
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string if Major or Minor include Production Line
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PLId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('PLId', @vchRptMinorGroupBy) > 0
BEGIN
	SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'PLId, PLDesc, '
	SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'PLId, PLDesc, '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string if Major or Minor include Product Group
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('ProductGrpId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('ProductGrpId', @vchRptMinorGroupBy) > 0
BEGIN
	SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ProductGrpId, '
	SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'ProductGrpId, '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string if Major or Minor include Product 
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('ProdId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('ProdId', @vchRptMinorGroupBy) > 0
BEGIN
	SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'ProdId, '
	SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'ProdId, '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string if Major or Minor include Production Unit
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PUId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('PUId', @vchRptMinorGroupBy) > 0
BEGIN
	SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'PUId, PUDesc, '
	SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'PUId, PUDesc, '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string if Major or Minor include Production Path
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PathId', @vchRptMinorGroupBy) > 0
BEGIN
	SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'PathId, PathDesc, '
	SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'PathId, PathDesc, '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string if Major or Minor include PROCESS ORDER
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PO', @vchRptMinorGroupBy) > 0
BEGIN
	SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'PO, '
	SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'PO, '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string to include the fields for production
-----------------------------------------------------------------------------------------------------------------------
SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'MinorGroupVolumeCount ) '
SET	@nvchSQLCommand2 = @nvchSQLCommand2 + 'SUM(MajorMinorVolumeCount) '
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string FROM clause when Major Group = Minor Group of Major Group is NONE
-----------------------------------------------------------------------------------------------------------------------
IF	@vchRptMajorGroupBy = 'None' 
	OR (@vchRptMajorGroupBy = @vchRptMinorGroupBy)
BEGIN
	IF	@vchRptMinorGroupBy = 'None'
	BEGIN
		SET	@nvchSQLCommand3 =	'	FROM	#MajorMinorVolumeCount ' 
						+		'	GROUP BY	MajorGroupId'
	END
	ELSE
	BEGIN
		SET	@nvchSQLCommand3 =	'	FROM	#MajorMinorVolumeCount ' 
						+		'	GROUP BY	MajorGroupId, ' + REPLACE(@vchRptMinorGroupBy, '|', ',')
	END
END
ELSE
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE SQL string FROM clause when Major Group <> Minor Group of Major Group is not NONE
-----------------------------------------------------------------------------------------------------------------------
BEGIN
	SET	@nvchSQLCommand3 =	'	FROM	#MajorMinorVolumeCount ' 
						+	'	GROUP BY	MajorGroupId, ' + REPLACE(@vchRptMajorGroupBy, '|', ',') + ', ' + REPLACE(@vchRptMinorGroupBy, '|', ',')
END

-----------------------------------------------------------------------------------------------------------------------
--	EXECUTE SQL string 
-----------------------------------------------------------------------------------------------------------------------
SET	@nvchSQLCommand = @nvchSQLCommand1 + ' ' + @nvchSQLCommand2 + ' ' + @nvchSQLCommand3
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PLId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('PLId', @vchRptMinorGroupBy) > 0
BEGIN
	SET @nvchSQLCommand = @nvchSQLCommand + ', PLDesc'
END
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PUId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('PUId', @vchRptMinorGroupBy) > 0
BEGIN
	SET @nvchSQLCommand = @nvchSQLCommand + ', PUDesc'
END
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PathId', @vchRptMinorGroupBy) > 0
BEGIN
	SET @nvchSQLCommand = @nvchSQLCommand + ', PathDesc'
END
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PO', @vchRptMinorGroupBy) > 0
BEGIN
	SET @nvchSQLCommand = @nvchSQLCommand + ', PO '
END
-----------------------------------------------------------------------------------------------------------------------
--	Added ORDER BY Statement
-----------------------------------------------------------------------------------------------------------------------
IF @vchRptMinorGroupBy <> 'None'
BEGIN
	SET @nvchSQLCommand = @nvchSQLCommand + '	ORDER BY	MajorGroupId, ' + REPLACE(@vchRptMinorGroupBy, '|', ',')
END
-----------------------------------------------------------------------------------------------------------------------
--	PRINT	SQLcommand
-----------------------------------------------------------------------------------------------------------------------
PRINT 'MinorGroupBy = ' + @nvchSQLCommand
-----------------------------------------------------------------------------------------------------------------------
EXECUTE sp_ExecuteSQL @nvchSQLCommand
-----------------------------------------------------------------------------------------------------------------------
-- If we have detected that the Production Unit does not have volume at all from its Production Variable assign volume 
-- equal to the Major Volume count only if that PUId has samples on the Time Slices.

IF	(CHARINDEX('PUId', @vchRptMajorGroupBy) > 0 
	OR CHARINDEX('PUId', @vchRptMinorGroupBy) > 0)
	AND @intRptVolumeWeightOption = 0
BEGIN
	UPDATE #MinorGroupList
		SET MinorGroupVolumeCount = MajorGroupVolumeCount
	FROM #MajorGroupList magl
	JOIN #MinorGroupList migl ON migl.MajorGroupId = magl.MajorGroupId
	WHERE MinorGroupVolumeCount = 0
	AND   magl.PUId IN (SELECT PUId FROM #ValidVarTimeSlices WHERE TimeSliceEliminationFlag = 0)
END

-----------------------------------------------------------------------------------------------------------------------
--	UPDATE Product Group Desc
-----------------------------------------------------------------------------------------------------------------------
UPDATE	mi
SET	ProductGrpDesc = pg.Product_Grp_Desc
FROM	#MinorGroupList	mi
JOIN	dbo.Product_Groups	pg	WITH (NOLOCK)
								ON	mi.ProductGrpId = pg.Product_Grp_Id
-----------------------------------------------------------------------------------------------------------------------
--	UPDATE Product Code
-----------------------------------------------------------------------------------------------------------------------
UPDATE	mi
SET	ProdCode = Prod_Code
FROM	#MinorGroupList	mi
JOIN	dbo.Products_Base	p	WITH (NOLOCK)
							ON	mi.ProdId = p.Prod_Id

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ASSIGN Minor group ids to the time slices'
--=====================================================================================================================
-- 	b.	ASSIGN Minor group id's to the time slices
-----------------------------------------------------------------------------------------------------------------------
SET	@nvchSQLCommand =	''
SET	@nvchSQLCommand = 	'	UPDATE	vt '
		+ 				' 	SET 	vt.MinorGroupId = mi.MinorGroupId '
		+				'	FROM	#ValidVarTimeSlices	vt '
		+				'	JOIN	#MinorGroupList	mi ON mi.MajorGroupId = vt.MajorGroupId '
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE statement when Minor Group includes PLId
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PLId', @vchRptMinorGroupBy) > 0 
BEGIN
	SET	@nvchSQLCommand = @nvchSQLCommand + 'AND mi.PLId = vt.PLId '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE statement when Minor Group includes ProductGrpId
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('ProductGrpId', @vchRptMinorGroupBy) > 0 
BEGIN
	SET	@nvchSQLCommand = @nvchSQLCommand + 'AND mi.ProductGrpId = vt.ProductGrpId '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE statement when Minor Group includes ProductGrpId
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('ProdId', @vchRptMinorGroupBy) > 0 
BEGIN
	SET	@nvchSQLCommand = @nvchSQLCommand + 'AND mi.ProdId = vt.ProdId '
END
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE statement when Minor Group includes ProductUnit
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PUId', @vchRptMinorGroupBy) > 0 
BEGIN
	SET	@nvchSQLCommand = @nvchSQLCommand + 'AND mi.PUId = vt.PUId '
END
----------------------------------------------------------------------------------------------------------------------
--	PREPARE statement when Minor Group includes Path
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PathId', @vchRptMinorGroupBy) > 0 
BEGIN
	SET	@nvchSQLCommand = @nvchSQLCommand + 'AND mi.PathId = vt.PathId '
END
----------------------------------------------------------------------------------------------------------------------
--	PREPARE statement when Minor Group includes Path
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('PO', @vchRptMinorGroupBy) > 0 
BEGIN
	SET	@nvchSQLCommand = @nvchSQLCommand + 'AND mi.PO = vt.PO '
END
-----------------------------------------------------------------------------------------------------------------------
--	PRINT SQL statement
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	@nvchSQLCommand
-----------------------------------------------------------------------------------------------------------------------
--	EXECUTE SQL statement
-----------------------------------------------------------------------------------------------------------------------
EXECUTE sp_ExecuteSQL 	@nvchSQLCommand
-- 
--SELECT '#MajorGroupList',* FROM #MajorGroupList
--SELECT '#MinorGroupList',* FROM #MinorGroupList
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' RAW DATA - CalcPPMSlices'
--=====================================================================================================================
--	RAW DATA
--	Business Rule:
--	a.	CalcPPMSlices - NON-NUMERIC DATA
--	b.	CalcPPMSlices - NUMERIC DATA
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CalcPPMSlices - NON-NUMERIC DATA'
--=====================================================================================================================
--	a.	CalcPPMSlices - NON-NUMERIC DATA
--  FRio : added a new column IsOfflineQuality; this column will be set to :
--  0 - The Variable does not belong from the genealogy with the Paper Machines
--  1 - The Variable belongs from the Paper Machines.
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('ProdId', @vchRptMinorGroupBy, 1) > 0
BEGIN
	INSERT INTO	#CalcPPM (
				MajorGroupId,
				MinorGroupId,
				PLId,
				PUGId,
				ProductGrpId,
				ProdId,
				VarGroupId, 
				VarDescRpt,
				IsNonNormal,
				LSL,
				Target,
				USL,
				TargetRpt,
				SpecVersion,
				TestCount,
				TestCountReal,
				IncludeAool,
				IsAtt,
				IsNumericDataType,
				VarCount,
				IsOfflineQuality,
				PODesc)
	SELECT	vt.MajorGroupId,
			vt.MinorGroupId,
			ld.PLId,
			ld.PUGId,
			vt.ProductGrpId,
			vt.ProdId,
			ld.VarGroupId, 
			ld.VarDescRpt,
			ld.IsNonNormal,
			vt.LSL,
			vt.Target,
			vt.USL,
			vt.Target,
			CONVERT(VARCHAR(35), MAX(CONVERT(DATETIME, vt.SpecVersion)), 121),	
			SUM(TestCountResultNOTNULL),
			SUM(TestCountResultNOTNULL),
			1,
			ld.IsAtt,
			ld.IsNumericDataType,
			ld.VarCount,
			ISNULL(ld.IsOfflineQuality,0),				-- martin 2010-01-28
			vt.PO										-- Pablo Galanzini 2011-02-24
	FROM			#ValidVarTimeSlices vt 	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		INNER JOIN	#ListDataSource		ld	ON	vt.VarId = ld.VarId
												AND ld.PLId = vt.PLId
	WHERE	ld.IsNumericDataType = 0
		AND	vt.TimeSliceEliminationFlag = 0
	GROUP BY	vt.MajorGroupId, vt. MinorGroupId, ld.PLId, ld.PUGId, ld.TzFlag, 
				vt.ProductGrpId, vt.ProdId, vt.Target, ld.IsNonNormal, vt.LSL, vt.USL,
				ld.VarGroupId, ld.VarTestName, ld.VarDescRpt, ld.VarCount, ld.IsAtt, 
				ld.IsNumericDataType, ld.IsOfflineQuality, vt.PO
	ORDER BY	vt.MajorGroupId, vt.MinorGroupId, ld.PLId, ld.PUGId,
				vt.ProductGrpId, ld.VarGroupId, vt.Target, vt.PO
END
ELSE
BEGIN
	INSERT INTO	#CalcPPM (
				MajorGroupId,
				MinorGroupId,
				PLId,
				PUGId,
				ProductGrpId,
				ProdId,
				VarGroupId, 
				VarDescRpt,
				IsNonNormal,
				LSL,
				Target,
				USL,
				TargetRpt,
				SpecVersion,
				TestCount,
				TestCountReal,
				IncludeAool,
				IsAtt,
				IsNumericDataType,
				VarCount,
				IsOfflineQuality,
				PODesc)
	SELECT	vt.MajorGroupId,
			vt.MinorGroupId,
			vt.PLId,
			vt.PUGId,
			vt.ProductGrpId,
			NULL,
			vt.VarGroupId, 
			ld.VarDescRpt,
			ld.IsNonNormal,
			vt.LSL,
			vt.Target,
			vt.USL,
			vt.Target,
			CONVERT(VARCHAR(35), MAX(CONVERT(DATETIME, vt.SpecVersion)), 121),	
			SUM(vt.TestCountResultNOTNULL),
			SUM(vt.TestCountResultNOTNULL),
			1,
			ld.IsAtt,
			ld.IsNumericDataType,
			ld.VarCount,
			ISNULL(ld.IsOfflineQuality,0),				-- martin 2010-01-28
			vt.PO										-- Pablo Galanzini 2011-02-24
	FROM			#ValidVarTimeSlices vt 	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		INNER JOIN	#ListDataSource		ld	ON	vt.VarId = ld.VarId
												AND ld.PLId = vt.PLId
	WHERE	ld.IsNumericDataType = 0
		AND	vt.TimeSliceEliminationFlag = 0
	GROUP BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, vt.PUGId, ld.TzFlag, 
				vt.ProductGrpId, vt.Target, ld.IsNonNormal, vt.LSL, vt.USL,
				vt.VarGroupId, ld.VarTestName, ld.VarDescRpt, ld.VarCount, ld.IsAtt, 
				ld.IsNumericDataType, ld.IsOfflineQuality, vt.PO
	ORDER BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, vt.PUGId,
				vt.ProductGrpId, vt.VarGroupId, vt.Target
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CalcPPMSlices - NON-NUMERIC DATA'
--=====================================================================================================================
--	b.	CalcPPMSlices - NUMERIC DATA
-----------------------------------------------------------------------------------------------------------------------
IF	CHARINDEX('ProdId', @vchRptMinorGroupBy, 1) > 0
BEGIN
	INSERT INTO	#CalcPPM (
				MajorGroupId,
				MinorGroupId,
				PLId,
				PUGId,
				ProductGrpId,
				ProdId,
				VarGroupId, 
				VarDescRpt,
				IsNonNormal,
				TestCount,
				TestCountReal,
				LEL,
				LSL,
				LTL,
				Target,
				TargetRpt,
				UTL,
				USL,
				UEL,
				SpecVersion,
				IncludeAool,
				IncludePool,
				IsAtt,
				IsNumericDataType,
				VarCount,
				IsOfflineQuality,
				PODesc )
	SELECT	vt.MajorGroupId,
			vt.MinorGroupId,
			vt.PLId,
			vt.PUGId,
			vt.ProductGrpId,
			vt.ProdId,
			vt.VarGroupId,
			ld.VarDescRpt,
			ld.IsNonNormal,
			SUM(vt.TestCountResultNOTNULL),
			SUM(vt.TestCountResultNOTNULL),
			vt.LEL,
			vt.LSL,
			vt.LTL,
			vt.Target,
			vt.Target,
			vt.UTL,
			vt.USL,
			vt.UEL,
			CONVERT(VARCHAR(35), MAX(CONVERT(DATETIME, vt.SpecVersion)), 121),	
			CASE	WHEN	ld.IsAtt = 1
					THEN	1
					ELSE 	0
					END,
			CASE	WHEN	ld.IsAtt = 1
					THEN	0
					ELSE	1
					END,
			ld.IsAtt,
			ld.IsNumericDataType,
			ld.VarCount,
			ISNULL(ld.IsOfflineQuality,0),
			vt.PO										-- Pablo Galanzini 2011-02-24
	FROM	#ValidVarTimeSlices vt 	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		JOIN	#ListDataSource	ld	ON 	ld.VarId = vt.VarId
										AND ld.PLId = vt.PLId
	WHERE	ld.IsNumericDataType = 1
		AND	vt.TimeSliceEliminationFlag = 0
	GROUP BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, vt.PUGId, ld.TzFlag, 
				vt.VarGroupId, ld.VarTestName, ld.VarCount, ld.VarDescRpt, ld.IsNonNormal,
				vt.ProductGrpId, vt.ProdId, ld.IsAtt, ld.IsNumericDataType, 
				vt.UEL, vt.USL, vt.UTL, vt.Target, vt.LTL, vt.LSL, vt.LEL,
				ld.IsOfflineQuality, vt.PO
	ORDER BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, vt.PUGId,
				vt.ProductGrpId, vt.VarGroupId, 
				vt.UEL, vt.USL, vt.UTL, vt.Target, vt.LTL, vt.LSL, vt.LEL
END
ELSE
BEGIN
	INSERT INTO	#CalcPPM (
				MajorGroupId,
				MinorGroupId,
				PLId,
				PUGId,
				ProductGrpId,
				ProdId,
				VarGroupId, 
				VarDescRpt,
				IsNonNormal,
				TestCount,
				TestCountReal,
				LEL,
				LSL,
				LTL,
				Target,
				TargetRpt,
				UTL,
				USL,
				UEL,
				SpecVersion,
				IncludeAool,
				IncludePool,
				IsAtt,
				IsNumericDataType,
				VarCount,
				IsOfflineQuality,
				PODesc)
	SELECT	vt.MajorGroupId,
			vt.MinorGroupId,
			vt.PLId,
			vt.PUGId,
			vt.ProductGrpId,
			NULL,
			vt.VarGroupId,
			ld.VarDescRpt,
			ld.IsNonNormal,
			SUM(vt.TestCountResultNOTNULL),
			SUM(vt.TestCountResultNOTNULL),
			vt.LEL,
			vt.LSL,
			vt.LTL,
			CONVERT(VARCHAR(50), vt.Target),
			CONVERT(VARCHAR(50), vt.Target),
			vt.UTL,
			vt.USL,
			vt.UEL,
			CONVERT(VARCHAR(35), MAX(CONVERT(DATETIME, vt.SpecVersion)), 121),	
			CASE	WHEN	ld.IsAtt = 1
					THEN	1
					ELSE 	0
					END,
			CASE	WHEN	ld.IsAtt = 1
					THEN	0
					ELSE	1
					END,
			ld.IsAtt,
			ld.IsNumericDataType,
			ld.VarCount,
			ISNULL(ld.IsOfflineQuality,0),				-- martin 2010-01-28
			vt.PO										-- Pablo Galanzini 2011-02-24
	FROM	#ValidVarTimeSlices vt 	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
		JOIN	#ListDataSource	ld	ON 	ld.VarId = vt.VarId
										AND ld.PLId = vt.PLId			-- martin
	WHERE	ld.IsNumericDataType = 1
		AND	vt.TimeSliceEliminationFlag = 0
	GROUP BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, vt.PUGId, ld.TzFlag, 
				vt.VarGroupId, ld.VarTestName, ld.VarCount, ld.VarDescRpt, ld.IsNonNormal,
				vt.ProductGrpId, ld.IsAtt, ld.IsNumericDataType,
				vt.UEL, vt.USL, vt.UTL, vt.Target, vt.LTL, vt.LSL, vt.LEL,
				ld.IsOfflineQuality, vt.PO
	ORDER BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, vt.PUGId,
				vt.ProductGrpId, vt.VarGroupId, 
				vt.UEL, vt.USL, vt.UTL, vt.Target, vt.LTL, vt.LSL, vt.LEL
END

-- martin
UPDATE #CalcPPM
	SET SpecChange = (SELECT COUNT(cp1.SpecVersion) FROM #CalcPPM cp1
						JOIN #CalcPPM cp2 ON	cp1.VarGroupId = cp2.VarGroupId
												AND cp1.PLId = cp2.PLId
												AND	cp1.ProductGrpId = cp2.ProductGrpId
						WHERE cp.CalcPPMId = cp1.CalcPPMId
						GROUP BY cp1.VarDescRpt,cp1.PLId,cp1.ProductGrpId)
FROM #CalcPPM cp

UPDATE #CalcPPM
	SET SpecChange = (CASE	WHEN SpecChange > 1 THEN 1
							ELSE 0
							END	)

-- Error #1
--select * 
--FROM	#ValidVarTimeSlices vt 	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))
--		JOIN	#ListDataSource	ld	ON 	ld.VarId = vt.VarId
--										AND ld.PLId = vt.PLId
--where ld.VarTestName like 'V046-Subgroup individual'
--
--select '#ListDataSource',* from #ListDataSource
--where VarTestName like 'V046-Subgroup individual'
--
--select '#CalcPPM',podesc, * from #CalcPPM
--where VarDescRpt like 'V046-Subgroup individual'
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' RAW DATA - GET Test Aggregates'
--=====================================================================================================================
--	RAW DATA - GET Test Aggregates
--	Business Rule:
--	a.	Update CalcPPMId field in #ValidVarTimeSlices
--	b.	Get list of time slices for the CalcPPMId
-- 	c.	Test Agg - NON-Numeric
--	d.	Test Agg - Numeric
--=====================================================================================================================
--	GET list of CalcPPMId's
--=====================================================================================================================
TRUNCATE TABLE	#TempTable
INSERT INTO	#TempTable	(
			ValueINT)
SELECT	CalcPPMId
FROM	#CalcPPM
-----------------------------------------------------------------------------------------------------------------------
--	INITIALIZE variables
-----------------------------------------------------------------------------------------------------------------------
SELECT	@i 				= MIN(RcdIdx),
		@intMAXRcdIdx 	= MAX(RcdIdx)
FROM	#TempTable
-----------------------------------------------------------------------------------------------------------------------
--	LOOP through CalcPPMId's
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMAXRcdIdx
BEGIN
	--=================================================================================================================
	--	a.	UPDATE CalcPPMId field in #ValidVarTimeSlices
	--=================================================================================================================
	--	GET	CalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intCalcPPMId = ValueINT
	FROM	#TempTable
	WHERE	RcdIdx = @i
	-------------------------------------------------------------------------------------------------------------------
	--	GET	CalcPPMId INFO
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intMajorGroupId	= MajorGroupId		,
			@intMinorGroupId	= MinorGroupId		,
			@intPLId			= PLId				,
			@intPUGId			= PUGId				,
			@intProductGrpId	= ProductGrpId		,
			@intProdId			= ProdId			,
			@vchVarGroupId		= VarGroupId		,
			@vchUEL				= COALESCE(UEL		, '9.9e-100'),	-- COALESCE done to simplify the dynamic sql logic			
			@vchUSL				= COALESCE(USL		, '9.9e-100'),	
			@vchUTL				= COALESCE(UTL		, '9.9e-100'),	
			@vchTarget			= COALESCE(Target	, '9.9e-100'),	
			@vchLTL				= COALESCE(LTL		, '9.9e-100'),	
			@vchLSL				= COALESCE(LSL		, '9.9e-100'),	
			@vchLEL				= COALESCE(LEL		, '9.9e-100')
	FROM	#CalcPPM
	WHERE	CalcPPMId = @intCalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	--	BUILD UPDATE Statement
	-------------------------------------------------------------------------------------------------------------------
	SELECT 	@nvchSQLCommand = 	''
	SELECT	@nvchSQLCommand =	'	UPDATE	vt ' 
							+	'	SET	CalcPPMId = ' + CONVERT(VARCHAR(50), @intCalcPPMId) 
							+	'	FROM	#ValidVarTimeSlices vt 	WITH (INDEX(ValidVarTimeSlices_PLId_ProdId_VarId_TimeSlicePeriod_Idx))'
							+	'		JOIN	#ListDataSource		ld	ON	vt.VarId = ld.VarId 								'
							+	'	WHERE 	vt.MajorGroupId = ' 	+ CONVERT(VARCHAR(50), @intMajorGroupId)
	 						+	'		AND	vt.MinorGroupId = ' 	+ CONVERT(VARCHAR(50), @intMinorGroupId)
	 						+	'		AND	vt.PLId 		= ' 	+ CONVERT(VARCHAR(50), @intPLId)	
							+	'		AND	ld.PUGId		= ' 	+ CONVERT(VARCHAR(50), @intPUGId)	
	 						+	'		AND	vt.ProductGrpId = ' 	+ CONVERT(VARCHAR(50), @intProductGrpId)
	 						+	'		AND	ld.VarGroupId 	= ''' 	+ REPLACE(CONVERT(VARCHAR(100), @vchVarGroupId),'''','''''') + ''''							
	-------------------------------------------------------------------------------------------------------------------
	--	If minor group include ProdId
	-------------------------------------------------------------------------------------------------------------------
	IF	CHARINDEX('ProdId', @vchRptMinorGroupBy, 1) > 0
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + '	AND	vt.ProdId = ' + CONVERT(VARCHAR(50), @intProdId)
	END
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for LEL
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchLEL = '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND vt.LEL IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND vt.LEL = ''' + @vchLEL + ''''
	END
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for LSL
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchLSL = '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND LSL IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND LSL = ''' + CONVERT(VARCHAR(50), @vchLSL) + ''''
	END
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for LTL
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchLTL = '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND LTL IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND LTL = ''' + CONVERT(VARCHAR(50), @vchLTL) + ''''
	END
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for Target
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchTarget = '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND Target IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND Target = ''' + CONVERT(VARCHAR(50), @vchTarget) + ''''
	END
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for UTL
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchUTL  = '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND UTL IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND UTL = ''' + CONVERT(VARCHAR(50), @vchUTL) + ''''
	END	
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for USL
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchUSL =  '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND USL IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND USL = ''' + CONVERT(VARCHAR(50), @vchUSL) + ''''
	END	
	-------------------------------------------------------------------------------------------------------------------
	--	ADD JOIN condition for UEL
	-------------------------------------------------------------------------------------------------------------------
	IF	@vchUEL =  '9.9e-100'
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND UEL IS NULL'
	END
	ELSE
	BEGIN
		SELECT	@nvchSQLCommand =	@nvchSQLCommand + ' AND UEL = ''' + CONVERT(VARCHAR(50), @vchUEL) + ''''
	END	
	-------------------------------------------------------------------------------------------------------------------
	--	EXECUTE SQL
	--	Note: did not use sp_ExecuteSQL because it did not seem to work with the NULL values
	-------------------------------------------------------------------------------------------------------------------
	EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
	--=================================================================================================================
	-- 	b.	Get list of time slices for the CalcPPMId
	--=================================================================================================================
	DELETE	@tblTimeSliceTemp
	INSERT INTO	@tblTimeSliceTemp (
				TimeSliceId		,
				TimeSlicePUId	,
				VarId			,
				TimeSliceStart	,
				TimeSliceEnd	,
				LSL				,
				Target			,
				USL				,
				IsOfflineQuality)
	SELECT	TimeSliceId		,
			PUId			,
			VarId			,
			TimeSliceStart	,
			TimeSliceEnd	,
			LSL				,
			Target			,
			USL				,
			IsOfflineQuality
	FROM	#ValidVarTimeSlices
	WHERE	CalcPPMId = @intCalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	--	LOOP Through slices and get test results
	-------------------------------------------------------------------------------------------------------------------
	--	Initialize Loop Variables, have to be the Minimun RcdIdx value vs 1.
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@j = MIN(RcdIdx),
			@intMaxSliceCount = MAX(RcdIdx)
	FROM	@tblTimeSliceTemp

	-------------------------------------------------------------------------------------------------------------------
	--	CLEAN the @tblTestResultsTemp before going into the loop to avoid errors counting failed tests
	-------------------------------------------------------------------------------------------------------------------
	DELETE	@tblTestResultsTemp

	SELECT @intIsTAMUVariable = 0
	-------------------------------------------------------------------------------------------------------------------
	--	LOOP through time slices
	-------------------------------------------------------------------------------------------------------------------
	WHILE	@j <= @intMaxSliceCount
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Get time slice parameters
		---------------------------------------------------------------------------------------------------------------
		SELECT	@intTimeSliceId			= TimeSliceId		,
				@intSamplePUId			= TimeSlicePUId		,
				@intIsOfflineQuality	= IsOfflineQuality	,
				@intVarId				= VarId				,
				@dtmTimeSliceStart 		= TimeSliceStart	,
				@dtmTimeSliceEnd		= TimeSliceEnd		,
				@vchLSL					= LSL				,
				@vchTarget				= Target			,
				@vchUSL					= USL
		FROM	@tblTimeSliceTemp
		WHERE	RcdIdx = @j

		---------------------------------------------------------------------------------------------------------------
		--	Check if the Variable is TAMU
		---------------------------------------------------------------------------------------------------------------
		SELECT @intIsTAMUVariable = IsTAMUVariable
		FROM   #ListDataSource
		WHERE  VarId = @intVarId
		---------------------------------------------------------------------------------------------------------------
		--	Get time slice test results
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblTestResultsTemp (
					TimeSliceId	,
					VarId		,
					Result		,
					LSL			,
					Target		,
					USL			)
		SELECT	@intTimeSliceId	,
				@intVarId		,
				Result			,
				@vchLSL			,
				@vchTarget		,
				@vchUSL			
		FROM	dbo.fnLocal_NormPPM_GetTimeSliceTests (@intVarId, @intSamplePUId, @intIsOfflineQuality, @dtmTimeSliceStart, @dtmTimeSliceEnd)
		---------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTER
		---------------------------------------------------------------------------------------------------------------
		SET	@j = @j + 1
	END
	-------------------------------------------------------------------------------------------------------------------
	--	Get IsNumericDataType value
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intIsNumericDataType = IsNumericDataType
	FROM	#CalcPPM
	WHERE	CalcPPMId = @intCalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	--	Initialize Variables
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intTestFail 	= NULL,
			@fltTestMin		= NULL,
			@fltTestMax		= NULL,
			@fltTestAvg		= NULL,
			@fltTestStDev	= NULL
	-------------------------------------------------------------------------------------------------------------------
	--	CALCULATE Test Aggregates
	-------------------------------------------------------------------------------------------------------------------
	IF	@intIsNumericDataType = 0
	BEGIN
		-- If is not numeric and not TAMU Variable
		IF @intIsTAMUVariable = 0 		
		BEGIN
				SELECT	@intTestFail = COUNT(Result)
				FROM	@tblTestResultsTemp
				WHERE	Result <> Target		
		END
		ELSE
		BEGIN
				-- It is a TAMU Variable
				-- PRINT 'It is a TAMU Variable ' + CONVERT(VARCHAR,@intVarId)
				SELECT	@intTestFail = COUNT(Result)
				FROM	@tblTestResultsTemp
				WHERE	(Result = USL
						OR Result = LSL)
		END
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE Test Fail in #CalcPPM
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#CalcPPM
			SET	TestFail = @intTestFail
		WHERE	CalcPPMId = @intCalcPPMId
	END
	ELSE
	BEGIN
		IF	@intSpecSetting = 1
		BEGIN
			SELECT	@intTestFail 	= SUM(CASE	WHEN 	CONVERT(FLOAT, Result) < COALESCE(CONVERT(FLOAT, LSL), -999999999.)
													OR	CONVERT(FLOAT, Result) > COALESCE(CONVERT(FLOAT, USL), 999999999.) 
												THEN 1
												ELSE 0 
												END ),
					@fltTestMin		= MIN(CONVERT(FLOAT, Result)),
					@fltTestMax		= MAX(CONVERT(FLOAT, Result)),
					@fltTestAvg		= AVG(CONVERT(FLOAT, Result)),
					@fltTestStDev	= STDev(CONVERT(FLOAT, Result))	
			FROM	@tblTestResultsTemp
			WHERE	ISNUMERIC(Result) = 1
				AND	Result <> '.'
				AND	Result <> '-'
		END
		ELSE
		BEGIN
			SELECT	@intTestFail 	= SUM(CASE	WHEN 	CONVERT(FLOAT, Result) <= COALESCE(CONVERT(FLOAT, LSL), -999999999.)
													OR	CONVERT(FLOAT, Result) >= COALESCE(CONVERT(FLOAT, USL), 999999999.) 
												THEN 1
												ELSE 0 
												END ),
					@fltTestMin		= MIN(CONVERT(FLOAT, Result)),
					@fltTestMax		= MAX(CONVERT(FLOAT, Result)),
					@fltTestAvg		= AVG(CONVERT(FLOAT, Result)),
					@fltTestStDev	= STDev(CONVERT(FLOAT, Result))	
			FROM	@tblTestResultsTemp
			WHERE	ISNUMERIC(Result) = 1
				AND	Result <> '.'
				AND	Result <> '-'
		END
		---------------------------------------------------------------------------------------------------------------
		--	UPDATE Test Fail in #CalcPPM
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#CalcPPM
			SET	TestFail	= @intTestFail,
				TestMin  	= @fltTestMin,
				TestMax		= @fltTestMax,
				TestAvg		= @fltTestAvg,
				TestStDev	= @fltTestStDev
		WHERE	CalcPPMId 	= @intCalcPPMId
	END
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT COUNTER
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Delete Records where Test COUNT = 0 OR 1'
--=====================================================================================================================
--	DELETE Records where Test COUNT = 0
--	IF	all records have test COUNT = 0 return an error
--	ELSE delete all records where test COUNT = 0 OR 1
-----------------------------------------------------------------------------------------------------------------------

IF	(	SELECT	SUM(ISNULL(TestCount, 0)) 
		FROM	#CalcPPM ) = 0
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode 	= 5,
			@vchErrorMsg 	= 'NO DATA WAS RETURNED BECAUSE THE TEST COUNT IS 0 EVERYWHERE! PLEASE CHECK THE CONFIGURATION OF THE PRODUCTION VARIABLE'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO	FINISHError
END
ELSE
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	DELETE records where test COUNT = 0
	-------------------------------------------------------------------------------------------------------------------
	DELETE	#CalcPPM
	WHERE	TestCount = 0 OR TestCount IS NULL
	-------------------------------------------------------------------------------------------------------------------
	--	DELETE records where test COUNT = 1
	-------------------------------------------------------------------------------------------------------------------
	DELETE	#CalcPPM
	WHERE	TestCount = 1
    -------------------------------------------------------------------------------------------------------------------
	--	CHECK for empty recordset
	-------------------------------------------------------------------------------------------------------------------
	IF NOT EXISTS	(	SELECT	CalcPPMId
						FROM	#CalcPPM )
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	CATCH Error
		---------------------------------------------------------------------------------------------------------------
		SELECT	@intErrorCode 	= 5,
				@vchErrorMsg 	= 'NO DATA WAS RETURNED BECAUSE THE TEST COUNT IS 0 OR 1 EVERYWHERE! PLEASE CHECK THE CONFIGURATION OF THE PRODUCTION VARIABLE'
		---------------------------------------------------------------------------------------------------------------
		--	PRINT Error
		---------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
		---------------------------------------------------------------------------------------------------------------
		--	STOP sp execution
		---------------------------------------------------------------------------------------------------------------
		GOTO	FINISHError
	END
END



--=====================================================================================================================
-- Calculate squared deviation for data where sample < flag = 0 or no historical data has been 
-- found
--=====================================================================================================================
IF @p_vchRptLayoutOption 		=	'VASReport' 
BEGIN

	INSERT INTO	@VASTestValues (
				CalcPPMId	,
				Result		)
		SELECT	cp.CalcPPMId,
				t1.Result
		FROM	#ValidVarTimeSlices	vts	
		JOIN	#CalcPPM			cp	ON	cp.CalcPPMId = vts.CalcPPMId
										AND	cp.HistDataNotFoundFlag = 1
		JOIN	#ListDataSource		lds	ON	vts.VarId = lds.VarId
										AND	lds.IsNumericDataType = 1
		JOIN	dbo.Tests			t1	WITH (NOLOCK)
										ON	t1.Result_On	>=	vts.TimeSliceStart
										AND	t1.Result_On 	<	vts.TimeSliceEnd
										AND	t1.Var_Id 		= 	lds.VarId

	INSERT INTO	@VASTestValues (
				CalcPPMId,
				Result)
		SELECT	cp.CalcPPMId,
				t1.Result
		FROM	#ValidVarTimeSlices	vts	
		JOIN	#CalcPPM			cp	ON	cp.CalcPPMId = vts.CalcPPMId
										AND	cp.SampleLessThanFlag = 0
		JOIN	#ListDataSource		lds	ON	vts.VarId = lds.VarId
										AND	lds.IsNumericDataType = 1
		JOIN	dbo.Tests			t1	WITH (NOLOCK)
										ON	t1.Result_On	>=	vts.TimeSliceStart
										AND	t1.Result_On 	<	vts.TimeSliceEnd
										AND	t1.Var_Id 		= 	lds.VarId
	---------------------------------------------------------------------------------------------------
	-- Delete any test values that are NULL
	---------------------------------------------------------------------------------------------------
	DELETE FROM @VASTestValues WHERE Result IS NULL

	---------------------------------------------------------------------------------------------------
	-- Update Test Avg
	---------------------------------------------------------------------------------------------------
	UPDATE	vstv
		SET	vstv.TestAvg = cp.TestAvg
		FROM 	@VASTestValues	vstv
		JOIN	#CalcPPM				cp	ON	cp.CalcPPMId = vstv.CalcPPMId

	---------------------------------------------------------------------------------------------------
	-- Calculate Test Squared Dev
	---------------------------------------------------------------------------------------------------
	UPDATE	vstv
		SET	vstv.TestSquaredDev = POWER((Result-TestAvg),2)
		FROM 	@VASTestValues	vstv
	WHERE ISNUMERIC(Result)=1

	UPDATE	cp
		SET	cp.TestSUMSquaredDev = (SELECT SUM(vts.TestSquaredDev)
									FROM @VASTestValues  vts WHERE vts.CalcPPMId = cp.CalcPPMId )
	FROM 	#CalcPPM cp

END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Flag records that meet criteria for Sample < Adjustment'
--=====================================================================================================================
--	Flag records that meet criteria for Sample < Adjustment
-----------------------------------------------------------------------------------------------------------------------
-- IF @RptSampleLessThanAdjustment = 1 and Reporting Period = @RptSampleLessThanMINReportingDays
-- then flag records that meet criteria for sample < adjustment
-----------------------------------------------------------------------------------------------------------------------
-- select @intRptSampleLessThanAdjustment .@intRptReportingPeriod ,@intRptSampleLessThanMINReportingDays

IF	(@intRptSampleLessThanAdjustment = 1
AND	@intRptReportingPeriod >= @intRptSampleLessThanMINReportingDays)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT 	'			.	Flag data that meets criteria for sample < ' + CONVERT(VARCHAR, @intRptSampleLessThanMINSampleCOUNTPQM)
	IF @intPRINTFlag = 1	PRINT 	'				and Reporting Period >= ' + CONVERT(VARCHAR, @intRptSampleLessThanMINReportingDays)
	-------------------------------------------------------------------------------------------------------------------
	-- Flag numeric CalcPPMId's
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cp
	SET	cp.SampleLessThanFlag = 1
	FROM	#CalcPPM		cp
	WHERE	cp.TestCountReal < @intRptSampleLessThanMINSampleCOUNTPQM
		AND		cp.IncludePool = 1
	-------------------------------------------------------------------------------------------------------------------
	-- Flag attribute CalcPPMId's
	-- Numeric Attributes
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cp
	SET	cp.SampleLessThanFlag = 1
	FROM	#CalcPPM		cp
	WHERE	cp.TestCountReal < @intRptSampleLessThanMINSampleCOUNTATT
		AND		cp.IncludePool = 0	

	-- Non Numeric Attributes
	-- 20100223 it was not including the Attributes 
	UPDATE	cp
	SET	cp.SampleLessThanFlag = 1
	FROM	#CalcPPM		cp
	WHERE	cp.TestCountReal < @intRptSampleLessThanMINSampleCOUNTATT
		AND		cp.IncludeAool = 1	
	-------------------------------------------------------------------------------------------------------------------

END
ELSE
BEGIN
	PRINT '			.	NOTE: SAMPLE LESS THAN ADJUSTMENT LOGIC HAS BEEN TURNED OFF!!!!!'
END

-- SELECT IncludePool, IncludeAool,SampleLessThanFlag,* FROM #CalcPPM 

--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' RAW DATA - NON-NORMAL'
--=====================================================================================================================
--	RAW DATA - NON-NORMAL
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Non-Normal Raw Data'
--=====================================================================================================================
--	GET Non-Normal Raw Data
-----------------------------------------------------------------------------------------------------------------------
-- The non-normal data is extracted at this point to classify it by CalcPPM Id since percent
-- confidence is done on each record in the "Data Validation" sheet
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT 	'			.	Get a list of all records in #CalcPPM WHERE NormType = N '
-----------------------------------------------------------------------------------------------------------------------
-- Note: @tblNonNormalList is a list of all records in #CalcPPM where NormType = N


-- TODO: replace code that gets tests with function call
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT 	'			.	Retrieve real data'
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (	SELECT	CalcPPMId
			FROM	#CalcPPM
			WHERE 	IsNonNormal = 1)
BEGIN
	INSERT INTO	#NonNormalValuesTemp2 (
				CalcPPMId			,		
				VarId				,
				VarGroupId			,
				Result				,
				ResultON			,
				TimeSliceProdId		,
				TimeSliceStart		,
				TimeSliceEnd		,				
				PLStatusId			,
				HistTestFlag		,
				LEL					,
				LSL					,
				LTL					,
				Target				,
				UTL					,
				USL					,
				UEL					)
	SELECT		cp.CalcPPMId			,
				vt.VarId				,
				cp.VarGroupId			,
				t1.Result				,
				t1.Result_On			,
				vt.ProdId				,
				vt.TimeSliceStart		,
				vt.TimeSliceEnd	 		,
				vt.PLStatusId			,
				0						,
				vt.LEL					,
				vt.LSL					,
				vt.LTL					,
				vt.Target				,
				vt.UTL					,
				vt.USL					,
				vt.UEL					
	FROM	#CalcPPM			cp	
		JOIN	#ValidVarTimeSlices 	vt 	WITH (INDEX (ValidVarTimeSlices_CalcPPMId_Idx)) 
											ON	cp.CalcPPMId = vt.CalcPPMId
											AND	cp.IsNonNormal = 1
		JOIN	#ListDataSource		ld	ON	vt.VarId = ld.VarId 				
	LEFT	JOIN	dbo.Tests 	t1 	WITH (NOLOCK)							
									ON 	vt.VarId = t1.Var_Id				
										AND	vt.TimeSliceEliminationFlag = 0		
										AND	t1.Result_On >= vt.TimeSliceStart	
										AND	t1.Result_On < 	vt.TimeSliceEnd		
										AND	t1.Canceled = 0						
	------------------------------------------------------------------------------------------------------------------
	-- Note: did not use sp_ExecuteSQL because it did not seem to work with the NULL values
	------------------------------------------------------------------------------------------------------------------
	EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
	------------------------------------------------------------------------------------------------------------------
	-- Eliminate NULL test values
	------------------------------------------------------------------------------------------------------------------
	DELETE	#NonNormalValuesTemp2
	WHERE	Result IS NULL
END
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' HISTORICAL DATA RETRIEVAL OPTION'
--=====================================================================================================================
-- Business Rule:
-- If @RptSampleLessThanAdjustment = 1 and the reporting period
-- is equal to @RptSampleLessThanMinReportingDays then look back in history for data
-- 1. update #CalcPPM and flag the records that have a TestCountReal that is < than @RptSampleLessThanMinSampleCOUNTPQM or 
--	  @RptSampleLessThanMinSampleCOUNTATT
-- 2. populate @tblSampleLessThanList will all the records in #CalcPPM that have a SampleLessThanFlag = 1
-- 3. retrive the real test values by looping through all the records in @tblSampleLessThanList and finding the
--    matching time slices in #ValidVarTimeSlices. Real test values are inserted into #HistoricalDataValues and 
--    and flag by setting HistTestFlag = 0   
-- 4. retrieve the historical test values
--    select disctinc CalcPPMId from #HistoricalDataValues
--	  for each CalcPPMId get a list of valid time slices to search for historical data up to a max of 365 days
--    the valid time slices will match the product group and quality pu_id of the CalcPPMId
-- 5. Loop through each time slice 
--	  retrieve the historical data
--	  get the line status of each test result
--	  apply line status filter
--	  get the specs for each test 
--    apply spec filter, ie. only select data that matches the specs of the CalcPPMId
--	  if @RptSampleLessThanMinSampleCOUNTPQM is met BREAK otherwise check next time slice
-- 6. Update #CalcPPM
--    HistDataNotFoundFlag
--    TestFail
--    TestCount
--	  TestCountHist
--    TestMin
--    TestMax
--    TestAvg
--    TestStDev
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
IF	(@intRptSampleLessThanAdjustment = 1
AND	@intRptReportingPeriod >= @intRptSampleLessThanMinReportingDays)
BEGIN
	------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT 	'			.	Retrieve real data'
	------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#HistoricalDataValues (
				CalcPPMId			,		
				VarId				,
				VarGroupId			,
				Result				,
				ResultON			,
				TimeSliceProdId		,
				TimeSliceStart		,
				TimeSliceEnd		,
				PLStatusId			,
				HistTestFlag		,
				LEL					,
				LSL					,
				LTL					,
				Target				,
				UTL					,
				USL					,
				UEL					,
				QualityPUId			)

--	Obsolete fields:
--	QualityPUId			,
--	TargetRangeSpecId	,
--	CharId				)

	SELECT		DISTINCT
				cp.CalcPPMId,
				vt.VarId				,
				cp.VarGroupId			,
	 			t1.Result				,
				t1.Result_ON			,
				vt.ProdId				,
				vt.TimeSliceStart		,
				vt.TimeSliceEnd	 		,
				vt.PLStatusId			,
				0						,
				vt.LEL					,
				vt.LSL					,
				vt.LTL					,
				vt.Target				,
				vt.UTL					,
				vt.USL					,
				vt.UEL					,
				vt.PUId						
	FROM	#CalcPPM			cp
		JOIN	#ValidVarTimeSlices 	vt 	WITH (INDEX (ValidVarTimeSlices_CalcPPMId_Idx)) 
									ON	cp.CalcPPMId = vt.CalcPPMId
										AND	SampleLessThanFlag = 1
										AND	IsNonNormal = 0
		JOIN	#ListDataSource		ld	ON	vt.VarId = ld.VarId 				
		LEFT	JOIN	dbo.Tests 	t1 	WITH (NOLOCK)							
									ON 	vt.VarId = t1.Var_Id				
										AND	vt.TimeSliceEliminationFlag = 0		
										AND	t1.Result_On >= vt.TimeSliceStart	
										AND	t1.Result_On < 	vt.TimeSliceEnd		
										AND	t1.Canceled = 0		
	
	------------------------------------------------------------------------------------------------------------------
	-- Eliminate NULL test values
	------------------------------------------------------------------------------------------------------------------
	DELETE	#HistoricalDataValues
	WHERE	Result IS NULL
	------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT 	'			.	Retrieve historical data'
	------------------------------------------------------------------------------------------------------------------
	-- Loop through the CalcPPMId to find the historical values
	------------------------------------------------------------------------------------------------------------------
	DELETE	@tblCalcPPMIdTemp
	INSERT INTO	@tblCalcPPMIdTemp (
				CalcPPMId)
		SELECT	DISTINCT
				CalcPPMId
			FROM	#HistoricalDataValues

	------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT 	'				Loop through CalcPPMId list'
	------------------------------------------------------------------------------------------------------------------
	SET	@i = 1
	SELECT	@intRcdCOUNT = MAX(RcdIdx) FROM @tblCalcPPMIdTemp
	WHILE @i <= @intRcdCOUNT	
	BEGIN
		
		--------------------------------------------------------------------------------------------------------------
		-- Get the CalcPPMId of interest
		--------------------------------------------------------------------------------------------------------------
		SELECT	@intCalcPPMId	= CalcPPMId
		FROM	@tblCalcPPMIdTemp
		WHERE	RcdIdx = @i
		--------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT 	'				--> @i = ' + 	CONVERT(VARCHAR(50), @i) + ' @intCalcPPMId = ' + 	CONVERT(VARCHAR(50), @intCalcPPMId)
		--------------------------------------------------------------------------------------------------------------
		-- Get the min time slice start time
		--------------------------------------------------------------------------------------------------------------
		SELECT	@dtmMinTimeSliceStart	= MIN(TimeSliceStart)
		FROM	#HistoricalDataValues
		WHERE	CalcPPMId = @intCalcPPMId
		--------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT 	'				@dtmMinTimeSliceStart = ' + 	CONVERT(VARCHAR(50), @dtmMinTimeSliceStart, 121)
		--------------------------------------------------------------------------------------------------------------
		-- Get the list of valid product id's for this CalcPPMId
		--------------------------------------------------------------------------------------------------------------
		DELETE	@tblProdIdTemp
		INSERT INTO	@tblProdIdTemp (
			 		TimeSliceProdId	)
		SELECT	DISTINCT
				TimeSliceProdId
		FROM 	#HistoricalDataValues
		WHERE	CalcPPMId = @intCalcPPMId
		--------------------------------------------------------------------------------------------------------------
		-- Get the list of valid quality pu id's for this CalcPPMId
		--------------------------------------------------------------------------------------------------------------
		DELETE	@tblQualityPUIdTemp
		INSERT INTO	@tblQualityPUIdTemp (
			 		QualityPUId	)
		SELECT	DISTINCT
				QualityPUId
		FROM 	#HistoricalDataValues
		WHERE	CalcPPMId = @intCalcPPMId
		--------------------------------------------------------------------------------------------------------------
		-- Get the list of valid quality pu id's for this CalcPPMId
		--------------------------------------------------------------------------------------------------------------
		DELETE	@tblVarIdTemp
		INSERT INTO	@tblVarIdTemp (
			 		VarId,
					TargetRangeSpecId,
					CharId	)
		SELECT	DISTINCT
				VarId,
				TargetRangeSpecId,
				CharId
		FROM 	#HistoricalDataValues
		WHERE	CalcPPMId = @intCalcPPMId
		--------------------------------------------------------------------------------------------------------------
		-- Get the next available time slice to search
		--------------------------------------------------------------------------------------------------------------
		SET	@dtmMaxSearchDate = DATEADD(DAY, -365, @p_vchRptEndDateTime ) --@dtmEndDateTime)
		--------------------------------------------------------------------------------------------------------------

		DELETE	@tblValidTimeSlicesLookUp
		INSERT INTO	@tblValidTimeSlicesLookUp (
					CalcPPMId		,
					RunId			,
					QualityPUId		,
					ProdId			,
					TimeSliceStart	,
					TimeSliceEnd	)
		SELECT		@intCalcPPMId	,
					Start_Id		,
					PU_Id			,
					Prod_Id			,
					CASE	WHEN	Start_Time	< @dtmMaxSearchDate	
							THEN	@dtmMaxSearchDate
							ELSE	Start_Time
					END,
					CASE	WHEN	End_Time	> @dtmMinTimeSliceStart
							THEN	@dtmMinTimeSliceStart
							ELSE	End_Time
					END
		FROM	dbo.Production_Starts	ps	WITH (NOLOCK)
			JOIN	@tblProdIdTemp			pt	ON	ps.Prod_Id 	= pt.TimeSliceProdId
			JOIN	@tblQualityPUIdTemp		qt	ON	ps.PU_Id	= qt.QualityPUId
		WHERE	Start_Time 	< @dtmMinTimeSliceStart			
			AND		End_Time 	> @dtmMaxSearchDate
		ORDER BY	Start_Time DESC

		--------------------------------------------------------------------------------------------------------------
		-- Retrive historical data
		--------------------------------------------------------------------------------------------------------------
		SELECT	@intTimeSliceLookUpRcdIdx = MIN(RcdIdx)
		FROM	@tblValidTimeSlicesLookUp
		--------------------------------------------------------------------------------------------------------------
		SELECT	@intTimeSliceLookUpCOUNT = MAX(RcdIdx)
		FROM	@tblValidTimeSlicesLookUp
		--------------------------------------------------------------------------------------------------------------
		WHILE	@intTimeSliceLookUpRcdIdx <= @intTimeSliceLookUpCOUNT
		BEGIN
 			SELECT	@dtmTimeSliceStart 	= TimeSliceStart,
 					@dtmTimeSliceEnd 	= TimeSliceEnd,
 					@intTimeSliceProdId	= ProdId,
 					@intQualityPUId		= QualityPUId
			FROM 	@tblValidTimeSlicesLookUp
			WHERE	RcdIdx = @intTimeSliceLookUpRcdIdx
			----------------------------------------------------------------------------------------------------------
			IF @intPRINTFlag = 1	PRINT 	'				@intTimeSliceLookUpRcdIdx = ' + 	CONVERT(VARCHAR(50), @intTimeSliceLookUpRcdIdx)
			IF @intPRINTFlag = 1	PRINT 	'				@c_dtmTimeSliceStart = ' + 	CONVERT(VARCHAR(50), @dtmTimeSliceStart, 121)
			IF @intPRINTFlag = 1	PRINT 	'				@c_dtmTimeSliceEnd = ' + 	CONVERT(VARCHAR(50), @dtmTimeSliceEnd, 121)
			IF @intPRINTFlag = 1	PRINT 	'				@c_intTimeSliceProdId = ' + 	CONVERT(VARCHAR(50), @intTimeSliceProdId)
			IF @intPRINTFlag = 1	PRINT 	'				@c_intQualityPUId = ' + 	CONVERT(VARCHAR(50), @intQualityPUId)
			----------------------------------------------------------------------------------------------------------
			-- Get current test COUNT
			----------------------------------------------------------------------------------------------------------
			SELECT	@intTestCountCurrent = COUNT(Result)
			FROM 	#HistoricalDataValues
			WHERE	CalcPPMId = @intCalcPPMId
			----------------------------------------------------------------------------------------------------------
			SELECT	@intIncludePool = ISNULL(IncludePool,0)
			FROM	#CalcPPM
			WHERE	CalcPPMId = @intCalcPPMId
			----------------------------------------------------------------------------------------------------------
			-- Calculate missing test COUNT
			----------------------------------------------------------------------------------------------------------
			IF	(@intIncludePool = 1)
			BEGIN	
				SET	@intTestCountMissing = 	@intRptSampleLessThanMinSampleCOUNTPQM - @intTestCountCurrent
			END
			ELSE
			BEGIN
				SET	@intTestCountMissing = 	@intRptSampleLessThanMinSampleCOUNTATT - @intTestCountCurrent
			END
			----------------------------------------------------------------------------------------------------------
			IF @intPRINTFlag = 1	PRINT 	'				@intTestCountCurrent = ' + 	CONVERT(VARCHAR(50), @intTestCountCurrent)
			IF @intPRINTFlag = 1 	PRINT 	'				@intTestCountMissing = ' + 	CONVERT(VARCHAR(50), @intTestCountMissing)
			----------------------------------------------------------------------------------------------------------
			TRUNCATE TABLE	#HistoricalDataValuesTemp1
			----------------------------------------------------------------------------------------------------------
			-- Apply Line Status Filter
			----------------------------------------------------------------------------------------------------------
 			/*
			IF	(SELECT	COUNT(*) FROM #FilterListPLStatus) > 0
 			BEGIN
 				INSERT INTO	#HistoricalDataValuesTemp1 (
 	 						CalcPPMId			,		
 	 						VarId				,
 	 						VarGroupId			,
 	 						Result				,
 	 						ResultON			,
 	 						TimeSliceProdId		,
 	 						TimeSliceStart		,
 	 						TimeSliceEnd		,
 	 						QualityPUId			,
 	 						HistTestFlag	,
 							TargetRangeSpecId	,
 							CharId				) 
	 			SELECT		@intCalcPPMId			,		
							vt.VarId				,
	 						lds.VarGroupId			,
	 					 	t1.Result				,
	 						t1.Result_ON			,
	 						@intTimeSliceProdId	,
	 						@dtmTimeSliceStart	,
	 						@dtmTimeSliceEnd	 	,
	 						@intQualityPUId		,
	 						1						,
							vt.TargetRangeSpecId	,
							vt.CharId					 
	 			FROM	@tblVarIdTemp	vt
	 					JOIN	#ListDataSource	lds	ON 	vt.VarId 	= lds.VarId
	 					JOIN	dbo.Tests 		t1 	WITH (NOLOCK)							
													ON 	vt.VarId 	 = 	t1.Var_Id				
														AND	t1.Result_On >= @dtmTimeSliceStart
														AND	t1.Result_On < 	@dtmTimeSliceEnd
														AND	t1.Canceled  = 	0				
				------------------------------------------------------------------------------------------------------
				-- DELETE Null results
				------------------------------------------------------------------------------------------------------
				DELETE	#HistoricalDataValuesTemp1
				WHERE	Result IS NULL
				------------------------------------------------------------------------------------------------------
				SELECT	@intHistTestCountBeforeFilter =	COUNT(*) FROM #HistoricalDataValuesTemp1
				------------------------------------------------------------------------------------------------------
				IF @intPRINTFlag = 1	PRINT 	'				Historical Sample COUNT Before Filter = ' + CONVERT(VARCHAR(50), @intHistTestCountBeforeFilter)
				IF @intPRINTFlag = 1	PRINT 	'				Apply line status filter' 
				------------------------------------------------------------------------------------------------------
				UPDATE	hdvt
				SET	PLStatusId = ls.Line_Status_Id
				FROM	#HistoricalDataValuesTemp1	hdvt
					JOIN	#ListPU						lp	ON	lp.QualityPUId 	= hdvt.QualityPUId
					JOIN	dbo.Local_PG_Line_Status	ls	WITH (NOLOCK)
															ON	lp.LineStatusPUId 	=  ls.Unit_Id
																AND	hdvt.ResultOn 		>= ls.Start_DateTime
																AND	hdvt.ResultOn 		<  ls.End_DateTime
				------------------------------------------------------------------------------------------------------
				DELETE	#HistoricalDataValuesTemp1	
				WHERE	NOT EXISTS (	SELECT 	PLStatusId 
										FROM 	#FilterListPLStatus	flp
										WHERE	#HistoricalDataValuesTemp1.PLStatusId = flp.PLStatusId)
				------------------------------------------------------------------------------------------------------
				SELECT	@intHistTestCountAfterFilter = COUNT(*) FROM #HistoricalDataValuesTemp1
				------------------------------------------------------------------------------------------------------
				IF @intPRINTFlag = 1	PRINT 	'				Historical Sample COUNT After Line Status Filter = ' + CONVERT(VARCHAR(50), @intHistTestCountAfterFilter)
				------------------------------------------------------------------------------------------------------
 			END
			ELSE
			BEGIN */
	 			INSERT INTO	#HistoricalDataValuesTemp1 (
	 						CalcPPMId			,		
	 						VarId				,
	 						VarGroupId			,
	 						Result				,
	 						ResultON			,
	 						TimeSliceProdId		,
	 						TimeSliceStart		,
	 						TimeSliceEnd		,
	 						QualityPUId			,
	 						HistTestFlag	,
							TargetRangeSpecId	,
							CharId				) 	
	 			SELECT		@intCalcPPMId			,		
							vt.VarId				,
	 						lds.VarGroupId			,
	 					 	t1.Result				,
	 						t1.Result_ON			,
	 						@intTimeSliceProdId	,
	 						@dtmTimeSliceStart	,
	 						@dtmTimeSliceEnd	 	,
	 						@intQualityPUId		,
	 						1						,				 
							vt.TargetRangeSpecId	,
							vt.CharId					 	
				FROM	@tblVarIdTemp	vt
 					JOIN	#ListDataSource	lds	ON vt.VarId = lds.VarId
 					JOIN	dbo.Tests 		t1 	WITH (NOLOCK)							
												ON 	vt.VarId 	 = 	t1.Var_Id				
													AND	t1.Result_On >= @dtmTimeSliceStart
													AND	t1.Result_On < 	@dtmTimeSliceEnd
													AND	t1.Canceled  = 	0						
				------------------------------------------------------------------------------------------------------
				-- DELETE Null results
				------------------------------------------------------------------------------------------------------
				DELETE	#HistoricalDataValuesTemp1
					WHERE	Result IS NULL
				------------------------------------------------------------------------------------------------------
				IF @intPRINTFlag = 1	PRINT 	'				No Line Status Filter for this CalcPPMId' 
				------------------------------------------------------------------------------------------------------
			-- END

			----------------------------------------------------------------------------------------------------------
			-- Update Specs for historical data that is normal 
			----------------------------------------------------------------------------------------------------------
			UPDATE	hdvt
			SET	LTL		=   vs.L_user	,
				LSL		=	vs.L_Reject	,		
				Target	=	vs.Target	,
				USL		=	vs.U_Reject	,
				UTL		=   vs.U_User
			FROM		#HistoricalDataValuesTemp1	hdvt
				JOIN		#ListDataSource				ls	ON	hdvt.VarId = ls.VarId
				LEFT JOIN	dbo.Var_Specs 				vs 	WITH (NOLOCK)
															ON 	hdvt.VarId 				=  vs.Var_Id
																AND	hdvt.TimeSliceProdId 	=  vs.Prod_Id
																AND	hdvt.ResultOn 			>= vs.Effective_Date
																AND	(hdvt.ResultOn 			<  vs.Expiration_Date 
																	OR 	vs.Expiration_Date IS NULL)			
			WHERE	ls.IsNonNormal = 0

			----------------------------------------------------------------------------------------------------------
			-- Update Specs for historical data that is normal 
			-- NOTE: this portion of code updates the specs for time slices that have been
			-- re-classified from non-normal to normal
			----------------------------------------------------------------------------------------------------------
			UPDATE	hdvt
			SET	LTL		=	vs.L_User						,
				LEL		=	COALESCE(vs.L_Entry, '1.0e-300'),		
				LSL		=	vs.L_Reject	,		
				Target	=	vs.Target	,
				USL		=	vs.U_Reject	,
				UEL		=	COALESCE(vs.U_Entry, '1.0e+300') ,
				UTL		=	vs.U_User
			FROM		#HistoricalDataValuesTemp1	hdvt
				JOIN		#ListDataSource			ls	ON	hdvt.VarId = ls.VarId
				LEFT JOIN	dbo.Var_Specs 			vs 	WITH (NOLOCK)
														ON 	hdvt.VarId 				=  vs.Var_Id
															AND	hdvt.TimeSliceProdId 	=  vs.Prod_Id
															AND	hdvt.ResultOn 			>= vs.Effective_Date
															AND	(hdvt.ResultOn 			<  vs.Expiration_Date 
																OR 	vs.Expiration_Date IS NULL)			
			WHERE	ls.IsNonNormal = 1

			----------------------------------------------------------------------------------------------------------
			-- Filter out historical data that does not have the same specs
			----------------------------------------------------------------------------------------------------------
			SELECT	@vchLEL		= COALESCE(LEL		, '9.9e-100'),
					@vchLSL		= COALESCE(LSL		, '9.9e-100'),
					@vchLTL		= COALESCE(LTL		, '9.9e-100'),
					@vchTarget	= COALESCE(Target	, '9.9e-100'),
					@vchUTL		= COALESCE(UTL		, '9.9e-100'),
					@vchUSL		= COALESCE(USL		, '9.9e-100'),
					@vchUEL		= COALESCE(UEL		, '9.9e-100')
			FROM	#CalcPPM
			WHERE	CalcPPMId = @intCalcPPMId
			----------------------------------------------------------------------------------------------------------
			SET	@nvchSQLCommand	=	'	SELECT	* '
							+		'		FROM	#HistoricalDataValuesTemp1	'
							+		'		WHERE	CalcPPMId = ' + CONVERT(VARCHAR(50), @intCalcPPMId)
			----------------------------------------------------------------------------------------------------------
			
			IF	@vchLEL = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	LEL IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	LEL = ''' + @vchLEL + ''' '
			END
			----------------------------------------------------------------------------------------------------------
			IF	@vchLSL = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	LSL IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	LSL = ''' + @vchLSL + ''' '
			END
			----------------------------------------------------------------------------------------------------------

			IF	@vchLTL = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	LTL IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	LTL = ''' + @vchLTL + ''' '
			END
			----------------------------------------------------------------------------------------------------------
			IF	@vchTarget = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	Target IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	Target = ''' + @vchTarget + ''' '
			END
			----------------------------------------------------------------------------------------------------------
			IF	@vchUTL = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	UTL IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	UTL = ''' + @vchUTL + ''' '
			END

			----------------------------------------------------------------------------------------------------------
			IF	@vchUSL = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	USL IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	USL = ''' + @vchUSL + ''' '
			END
			----------------------------------------------------------------------------------------------------------
			IF	@vchUEL = '9.9e-100'
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	UEL IS NULL '
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = @nvchSQLCommand	+	'			AND	UEL = ''' + @vchUEL + ''' '
			END
			
			----------------------------------------------------------------------------------------------------------
			IF @intPRINTFlag = 1	PRINT 	'				@vchrSQLCommand = ' + @nvchSQLCommand
			----------------------------------------------------------------------------------------------------------
			TRUNCATE TABLE	#HistoricalDataValuesTemp2
			INSERT INTO	#HistoricalDataValuesTemp2
			----------------------------------------------------------------------------------------------------------
			-- Execute Command
			----------------------------------------------------------------------------------------------------------
			EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand

			-- IF @intCalcPPMId = 12
			-- BEGIN
			--		SELECT '#CalcPPM',CalcPPMId,LEL,LSL,LTL,Target,UTL,USL,UEL,* FROM	#CalcPPM WHERE	CalcPPMId = @intCalcPPMId
			--		SELECT '#HistoricalDataValuesTemp1',CalcPPMId,LEL,LSL,LTL,Target,UTL,USL,UEL,* FROM #HistoricalDataValuesTemp1 WHERE CalcPPMId = @intCalcPPMId
			-- END
			----------------------------------------------------------------------------------------------------------
			SELECT	@intHistTestCount = COUNT(*) FROM #HistoricalDataValuesTemp2
			----------------------------------------------------------------------------------------------------------
			IF @intPRINTFlag = 1	PRINT 	'				Historical Sample COUNT After Spec Filter = ' + CONVERT(VARCHAR(50), @intHistTestCount)
			----------------------------------------------------------------------------------------------------------
			-- Add historical data to #HistoricalDataValues
			----------------------------------------------------------------------------------------------------------
			SELECT	@intTestCountHist = COUNT(Result)
				FROM #HistoricalDataValuesTemp2
			----------------------------------------------------------------------------------------------------------
			-- 20100219 @intTestCountMissing should be > 0
			IF	(@intTestCountHist >= @intTestCountMissing) AND (@intTestCountMissing > 0)
			BEGIN
				SET	@nvchSQLCommand =	'	SELECT	TOP ' + CONVERT(VARCHAR, @intTestCountMissing) 
								+		'			*	'
								+		'		FROM	#HistoricalDataValuesTemp2 	'
								+		'	ORDER BY 	ResultOn DESC				'
				------------------------------------------------------------------------------------------------------
				-- PRINT 	'				@vchrSQLCommand = ' + 	@nvchSQLCommand			
				------------------------------------------------------------------------------------------------------
				INSERT INTO	#HistoricalDataValues
				------------------------------------------------------------------------------------------------------				
				EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
			END
			ELSE
			BEGIN
				INSERT INTO	#HistoricalDataValues 
	 				SELECT	*	 
	 					FROM	#HistoricalDataValuesTemp2
			END		
			----------------------------------------------------------------------------------------------------------
			-- Break out of the loop as soon as the min amount of samples has been found
			----------------------------------------------------------------------------------------------------------
			SELECT	@intTestCount = COUNT(Result)
			FROM	#HistoricalDataValues
			WHERE	CalcPPMId = @intCalcPPMId
			----------------------------------------------------------------------------------------------------------
			IF	(@intIncludePool = 1)
			BEGIN
				IF	(	SELECT	COUNT(Result)
							FROM	#HistoricalDataValues
							WHERE	CalcPPMId = @intCalcPPMId) >= @intRptSampleLessThanMinSampleCOUNTPQM
				BEGIN
					---------------------------------------------------------------------------------------------------
					IF @intPRINTFlag = 1	PRINT 	'				Min Sample COUNT has been met'
					---------------------------------------------------------------------------------------------------
					BREAK
				END
			END
			ELSE
			BEGIN
				IF	(	SELECT	COUNT(Result)
							FROM	#HistoricalDataValues
							WHERE	CalcPPMId = @intCalcPPMId) >= @intRptSampleLessThanMinSampleCOUNTATT
				BEGIN
					---------------------------------------------------------------------------------------------------
					IF @intPRINTFlag = 1	PRINT 	'				Min Sample COUNT has been met'
					---------------------------------------------------------------------------------------------------
					BREAK
				END
			END
			-----------------------------------------------------------------------------------------------------------
			SET	@intTimeSliceLookUpRcdIdx = @intTimeSliceLookUpRcdIdx + 1
		END
 		---------------------------------------------------------------------------------------------------------------
		SET	@i = @i + 1
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT 	'			.	Update #CalcPPM with historical data values'
	-------------------------------------------------------------------------------------------------------------------
	-- 	Update the following fields in #CalcPPM
	--    HistDataNotFoundFlag
	--    TestFail
	--    TestCount
	--	  TestCountHist
	--    TestMin
	--    TestMax
	--    TestAvg
	--    TestStDev
	-------------------------------------------------------------------------------------------------------------------
	-- Calculate Squared Dev on CalcPPMId's that have historical data
	-------------------------------------------------------------------------------------------------------------------
	DELETE	@tblTestAvgTemp
	INSERT INTO	@tblTestAvgTemp	(
				CalcPPMId	,
				TestAvg		)
	SELECT	hdv.CalcPPMId	,
			AVG(CONVERT(FLOAT, hdv.Result))
	FROM	#HistoricalDataValues	hdv
	WHERE   ISNUMERIC(hdv.Result) = 1
	--	JOIN	#ListDataSource			lds	ON 	hdv.VarId = lds.VarId
	--									AND	lds.IsNumericDataType = 1
	GROUP BY	CalcPPMId		
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	hdv
		SET	TestSquaredDev = POWER((CONVERT(FLOAT, Result) - TestAvg), 2)
	FROM	#HistoricalDataValues	hdv
	JOIN	@tblTestAvgTemp			tat	ON	tat.CalcPPMId = hdv.CalcPPMId
	WHERE 	ISNUMERIC(hdv.Result) = 1
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT 	'			.	Update #CalcPPM with historical data values'
	-------------------------------------------------------------------------------------------------------------------
	-- 	Update the following fields in #CalcPPM
	--    HistDataNotFoundFlag
	--    TestFail
	--    TestCount
	--	  TestCountHist
	--    TestMin
	--    TestMax
	--    TestAvg
	--    TestStDev
	--	  TestSquaredDev
	-------------------------------------------------------------------------------------------------------------------
	-- Update numeric CalcPPMId's
	-------------------------------------------------------------------------------------------------------------------
	DELETE	@tblHistDataStats
	INSERT INTO	@tblHistDataStats (
				CalcPPMId		,
				TestAvg			,
				TestStDev		,
				TestFail		,
				TestCountHist	,		
				TestMin			,
				TestMax			,
				TestSUMSquaredDev)	
	SELECT	CalcPPMId		,
			AVG(CONVERT(FLOAT, hdv.Result)),
			STDEV(CONVERT(FLOAT, hdv.Result)),
			SUM(CASE	WHEN 	CONVERT(FLOAT, hdv.Result) < COALESCE(CONVERT(FLOAT, hdv.LSL), -999999999.)
						OR		CONVERT(FLOAT, hdv.Result) > COALESCE(CONVERT(FLOAT, hdv.USL), 999999999.) 
						THEN 1
						ELSE 0 
				END ),
			SUM(hdv.HistTestFlag)			,
			MIN(CONVERT(FLOAT, hdv.Result))	,
			MAX(CONVERT(FLOAT, hdv.Result))	,
			SUM(TestSquaredDev)
	FROM	#HistoricalDataValues	hdv
	WHERE   ISNUMERIC(hdv.Result) = 1
	--	JOIN	#ListDataSource			lds	ON 	hdv.VarId = lds.VarId
	--										AND	lds.IsNumericDataType = 1
	GROUP BY	CalcPPMId		

	-------------------------------------------------------------------------------------------------------------------
	-- Update non-numeric CalcPPMId's
	-------------------------------------------------------------------------------------------------------------------

	INSERT INTO	@tblHistDataStats (
				CalcPPMId		,
				TestFail		,
				TestCountHist	)
		SELECT	hdv.CalcPPMId	,
				SUM(CASE	WHEN hdv.Result <> hdv.Target 
							THEN 1
							ELSE 0 END),
				SUM(hdv.HistTestFlag)
			FROM	#HistoricalDataValues	hdv
		WHERE   ISNUMERIC(hdv.Result) = 0
			-- JOIN	#ListDataSource			lds	ON 	hdv.VarId = lds.VarId
			--									AND	lds.IsNumericDataType = 0
		GROUP BY	CalcPPMId
	-- SELECT '@tblHistDataStats',* FROM @tblHistDataStats ORDER BY CalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	-- Update stast for CalcPPMId's that use historical data
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cp
	SET	cp.TestAvg				= hds.TestAvg	,
		cp.TestStDev			= hds.TestStDev	,
		cp.TestFail				= cp.TestFail	,	-- + hds.TestFail	, -- 20100219
		cp.TestCountHist		= hds.TestCountHist,
		cp.TestMin				= hds.TestMin	,
		cp.TestMax				= hds.TestMax	,
		cp.TestSUMSquaredDev	= hds.TestSUMSquaredDev
	FROM	#CalcPPM			cp	
		JOIN	@tblHistDataStats	hds	ON	cp.CalcPPMId = hds.CalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	-- Update test COUNT
	-------------------------------------------------------------------------------------------------------------------
	
	UPDATE	#CalcPPM
	SET		TestCount = TestCountReal + TestCountHist
	WHERE	SampleLessThanFlag = 1	

	-------------------------------------------------------------------------------------------------------------------
	-- Flag records where no historical data was found
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM
	SET	HistDataNotFoundFlag =	CASE	WHEN	TestCount < @intRptSampleLessThanMinSampleCOUNTPQM
										THEN	1
										ELSE	0
								END
	WHERE	SampleLessThanFlag = 1
		AND		IncludePool = 1
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM
	SET	HistDataNotFoundFlag =	CASE	WHEN	TestCount < @intRptSampleLessThanMinSampleCOUNTATT
										THEN	1
										ELSE	0
								END
	WHERE	SampleLessThanFlag = 1
		AND		IncludePool = 0
		UPDATE	#CalcPPM
	-------------------------------------------------------------------------------------------------------------------
	SET	HistDataNotFoundFlag =	CASE	WHEN	TestCount < @intRptSampleLessThanMinSampleCOUNTATT
										THEN	1
										ELSE	0
								END
	WHERE	SampleLessThanFlag = 1
		AND		IncludeAool = 1
END				
ELSE
BEGIN
	IF @intPRINTFlag = 1	PRINT '			.	NOTE: SAMPLE LESS THAN ADJUSTMENT LOGIC HAS BEEN TURNED OFF!!!!!'
END


--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CHI SQUARE ANALYSIS OPTION'
--=====================================================================================================================
-- Note: the source of the test COUNT ranges for the degrees of freedom is the
-- "Quality_Variable_Non-Normal_V7_20050804.xls" spreadsheet
-----------------------------------------------------------------------------------------------------------------------
-- Percent confidence business rule:
-- 1. Calculate the degrees of freedom 
-- 2. Number of bins = degrees of freedom
-- 3. Calculate the bin range. Since it is difficult to approximate the NORMINV function from EXCEL
--    the bin range is = to 0.3*StDev. 
--	  If the bin COUNT is odd the StDev is in the middle of the middle interval
-- 	  If the bin COUNT is even the StDev is at the end and begining of the two middle intervals
-- 4. Calculate the observed frequency
-- 5. Calculate the expected frequency (TestCount/DegOfFreedom)
-- 6. Calculate the term value for each bin (Observed - Expected)^2/Expected
-- 7. Calculate the ChiDist value = SUM(Term values)
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptPercentConfidenceAnalysis = 0
BEGIN
	IF @intPrintFlag = 1 PRINT '			.	NOTE: PERCENT CONFIDENCE ANALISYS IS TURNED OFF!!!!!'
END
ELSE
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM
		SET	ExpectedTarget =	CASE	WHEN	TestCount < 30
										THEN	5
										ELSE	FLOOR((TestCount * 1.0) / 5.0)
								END
		WHERE	IsNonNormal = 1
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM
		SET	ExpectedTarget = 20
		WHERE	IsNonNormal = 1
		AND		ExpectedTarget 	> 	20
		AND		TestCount 		>= 	30
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM
		SET		DegOfFreedom = 	CASE	WHEN 	FLOOR((TestCount * 1.0) / (ExpectedTarget * 1.0)) < 3
										THEN	3
										ELSE	FLOOR((TestCount * 1.0) / (ExpectedTarget * 1.0))
								END
		WHERE	IsNonNormal = 1
	-------------------------------------------------------------------------------------------------------------------
	-- Get bin ranges and observed COUNT
	-------------------------------------------------------------------------------------------------------------------
	DELETE #TempValue 
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO #TempValue (ValueINT)
	SELECT CalcPPMId
	FROM #CalcPPM
	WHERE DegOfFreedom > 0
	-------------------------------------------------------------------------------------------------------------------
	SELECT @j = 1,
		   @intMaxPPMId = MAX(RcdIdx)
	FROM #TempValue
	-------------------------------------------------------------------------------------------------------------------
	WHILE @j <= @intMaxPPMId
	BEGIN		
		SELECT	@intCalcPPMId = cp.CalcPPMId,
			   	@intDegOfFreedom = cp.DegOfFreedom,
				@fltTestAvg = cp.TestAvg,
				@fltTestStDev = cp.TestStDev,
				@intTestCount = cp.TestCount
		FROM #TempValue tp
			JOIN #CalcPPM cp ON tp.ValueINT = cp.CalcPPMId
		WHERE tp.RcdIdx = @j
		---------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT '			.	Prepare the Bins For CaclPPMId = ' + CONVERT(VARCHAR, @intCalcPPMId)
		---------------------------------------------------------------------------------------------------------------
		SET	@i = 1
		WHILE	@i <= @intDegOfFreedom
		BEGIN
			IF	@i = 1
			BEGIN
				--------------------------------------------------------------------------------------------------------
				-- Get First Interval
				--------------------------------------------------------------------------------------------------------
				IF	@intDegOfFreedom%2 = 0
				BEGIN
					SET	@fltIntervalEnd1   	= (@fltTestAvg - (@fltTestStDev * 0.3) * (@intDegOfFreedom / 2))
				END
				ELSE
				BEGIN
					SET	@fltIntervalEnd1   	= (@fltTestAvg - (@fltTestStDev * 0.3) * ((@intDegOfFreedom / 2) - 0.5))
				END
				--------------------------------------------------------------------------------------------------------
				SET	@fltIntervalBegin1 	= 1.0e-300
				SET	@fltIntervalBegin2	= @fltIntervalEnd1
				SET	@fltIntervalEnd2	= @fltIntervalEnd1 + (@fltTestStDev * 0.3)
			END
			ELSE IF	@i = @intDegOfFreedom
			BEGIN
				--------------------------------------------------------------------------------------------------------
				-- Get Last Interval
				--------------------------------------------------------------------------------------------------------
				SET	@fltIntervalEnd1	= 1.0e+300
				SET	@fltIntervalBegin1 	= @fltIntervalBegin2
			END
			ELSE
			BEGIN
				--------------------------------------------------------------------------------------------------------
				-- Get Intermediate Intervals
				--------------------------------------------------------------------------------------------------------
				SET	@fltIntervalBegin1 	= @fltIntervalBegin2	
				SET	@fltIntervalEnd1 	= @fltIntervalEnd2
				SET	@fltIntervalBegin2 	= @fltIntervalEnd1	
				SET	@fltIntervalEnd2 	= @fltIntervalEnd1 + (@fltTestStDev * 0.3)
			END
			------------------------------------------------------------------------------------------------------------
			-- Add intervals to table					
			------------------------------------------------------------------------------------------------------------
			INSERT INTO	@tblPercentConfidence	(
						CalcPPMId		,
						IntervalNumber	,
						IntervalBegin	,
						IntervalEnd		,
						ExpectedCOUNT	)
				--------------------------------------------------------------------------------------------------------
				SELECT	@intCalcPPMId		,
						@i					,
						@fltIntervalBegin1	,
						@fltIntervalEnd1	,
						(@intTestCount * 1.0)/(@intDegOfFreedom * 1.0)
				--------------------------------------------------------------------------------------------------------
			SET	@i = @i + 1
		END
		----------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT '			.	Get the observed COUNT ' 
		----------------------------------------------------------------------------------------------------------------
		SELECT	@intMaxInterval = Max(IntervalNumber)
		FROM	@tblPercentConfidence	
		WHERE	CalcPPMId = @intCalcPPMId
		----------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT '			.	@CalcPPMId = ' + CONVERT(VARCHAR, @intCalcPPMId) 
		----------------------------------------------------------------------------------------------------------------		
		DELETE #TempValue2
		----------------------------------------------------------------------------------------------------------------
		INSERT INTO #TempValue2 (ValueINT)
		SELECT CalcPPMId
		FROM #NonNormalValuesTemp2
		----------------------------------------------------------------------------------------------------------------
		SELECT 	@intRcdCOUNT = 1,
				@intMAXRcdIdx = MAX(RcdIdx)
		FROM #TempValue2
		----------------------------------------------------------------------------------------------------------------
		WHILE @intRcdCOUNT <= @intMAXRcdIdx
		BEGIN	
			SELECT @fltResult = nv.result
			FROM #TempValue2 tp
				JOIN #NonNormalValuesTemp2 nv ON tp.ValueInt = nv.CalcPPMId
			WHERE tp.RcdIdx = @intRcdCOUNT
			------------------------------------------------------------------------------------------------------------
			SET	@i = 1 
			WHILE @i <= @intMaxInterval
			BEGIN 
				--------------------------------------------------------------------------------------------------------
				-- Get the IntervalBegin Value
				--------------------------------------------------------------------------------------------------------
				SELECT	@fltIntervalBegin1 = IntervalBegin
				FROM	@tblPercentConfidence
				WHERE	CalcPPMId = @intCalcPPMId
					AND		IntervalNumber = @i
				--------------------------------------------------------------------------------------------------------
				-- Get the IntervalEnd Value
				--------------------------------------------------------------------------------------------------------
				SELECT	@fltIntervalEnd1 = IntervalEnd
				FROM	@tblPercentConfidence
				WHERE	CalcPPMId = @intCalcPPMId
					AND		IntervalNumber = @i
				--------------------------------------------------------------------------------------------------------
				-- Update the observed COUNT when the value falls inside and interval
				--------------------------------------------------------------------------------------------------------
				IF	@fltResult >= @fltIntervalBegin1
					AND	@fltResult <  @fltIntervalEnd1
				BEGIN
					UPDATE	@tblPercentConfidence
						SET		ObservedCOUNT = ObservedCOUNT + 1
						WHERE	CalcPPMId = @intCalcPPMId
							AND		IntervalNumber = @i
				END
				SET	@i = @i + 1
			END
			-----------------------------------------------------------------------------------------------------------
			-- Increment COUNTer 
			-----------------------------------------------------------------------------------------------------------
			SET @intRcdCOUNT = @intRcdCOUNT + 1
		END		
		---------------------------------------------------------------------------------------------------------------
		-- Increment COUNTer
		---------------------------------------------------------------------------------------------------------------
		SET @j = @j + 1
	END	
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT '			.	Get the bin chi squared values'
	-------------------------------------------------------------------------------------------------------------------
	-- Business Rule: if ObservedCOUNT < 5 apply YATES Correction
	-- ((O - E) - 0.5)^2 / E
	-- Yates? correction punishes low cell COUNTs, which suggest a non-rigorous sampling. 
	-- To apply the correction, if any cell in the table has a value of less than 5, subtract .5 
	-- from every O ? E value before squaring it and dividing by E
	-- Reference: http://www.everything2.com/index.pl?node_id=779493
	-------------------------------------------------------------------------------------------------------------------
 	UPDATE	@tblPercentConfidence
 		SET		ChiSquareBin =	CASE	WHEN	ObservedCOUNT < 5	
 										THEN	(ABS(ObservedCOUNT - ExpectedCOUNT) - 0.5) * (ABS(ObservedCOUNT - ExpectedCOUNT) - 0.5) / ExpectedCOUNT
 										ELSE	(ObservedCOUNT - ExpectedCOUNT) * (ObservedCOUNT - ExpectedCOUNT) / ExpectedCOUNT
 								END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT '			.	Get the chi square values for the ppm slice'
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblChiSquareTemp (
				CalcPPMId			,
				ChiSquarePPMSlice	)
	SELECT		CalcPPMId	,
				SUM(ChiSquareBin)
	FROM		@tblPercentConfidence
	GROUP BY	CalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT '			.	Update ChiSquarePPMSlice on @tblCalcPPMInterim'
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cpi
	SET	cpi.ChiSquarePPMSlice = cst.ChiSquarePPMSlice
	FROM	@tblChiSquareTemp	cst
		JOIN	#CalcPPM			cpi	ON	cst.CalcPPMId = cpi.CalcPPMId
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT '			.	Update ChiSquareCriticalValue on @tblCalcPPMInterim'
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cpi
	SET	cpi.ChiSquareCriticalValue = cscv.ChiSquareCriticalValue
	FROM	#CalcPPM					cpi
		JOIN	@tblChiSquareCriticalValues	cscv	ON	cscv.DegOfFreedom = cpi.DegOfFreedom
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT '			.	Update NormTypeReclasification on @tblCalcPPMInterim'
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cpi
	SET		IsNonNormalReclassification = 	CASE	WHEN	ChiSquarePPMSlice	<=	ChiSquareCriticalValue
											THEN	0
											ELSE	1
										END
	FROM	#CalcPPM	cpi
	WHERE	IsNonNormal = 1
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cpi
	SET	IsNonNormal = 	0
	FROM	#CalcPPM	cpi
	WHERE	IsNonNormalReclassification = 0
END
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
-- IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
-- IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
-- IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
-- IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' SAMPLE < LOGIC'
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE NORMAL DATA PPM'
--=====================================================================================================================
--	CALCULATE NORMAL DATA PPM
--	a.	CHECK for bad spec data
--	b.	CALCULATE PPM AOOL
--	c.	CALCULATE Intermediate Values of NormSDist for Normal Variables 
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE PPM AOOL'
--=====================================================================================================================
--	a.	CHECK for bad spec data
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(	SELECT	MajorGroupId
				FROM	#CalcPPM
				WHERE	LEL		LIKE 	'%,%'
					OR	LSL		LIKE 	'%,%'
					OR	LTL		LIKE	'%,%'
					OR	Target	LIKE	'%,%'
					OR	UTL		LIKE	'%,%'
					OR	USL		LIKE	'%,%'
					OR	UEL		LIKE	'%,%')
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	CATCH Error
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@intErrorCode 	= 8,
			@vchErrorMsg 	= 'BAD Spec Data Found'
	-------------------------------------------------------------------------------------------------------------------
	--	PRINT Error
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	--	STOP sp execution
	-------------------------------------------------------------------------------------------------------------------
	GOTO	FINISHError
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE PPM AOOL'
--=====================================================================================================================
--	b.	CALCULATE PPM AOOL
-----------------------------------------------------------------------------------------------------------------------
UPDATE	#CalcPPM
	SET	CalcPPMAoolActual = 1000000.0 * ((TestFail * 1.0)/(TestCount * 1.0))
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Intermediate Values of NormSDist for Normal Variables '
--=====================================================================================================================
--	c.	CALCULATE Intermediate Values of NormSDist for Normal Variables
-----------------------------------------------------------------------------------------------------------------------
--		TempXl and TempXu
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		TempXl = ABS((TestAvg - CONVERT(DECIMAL(20, 10), LSL))) / TestStDev,
		TempXu = ABS((CONVERT(DECIMAL(20, 10), USL) - TestAvg)) / TestStDev
FROM	#CalcPPM	cp
	JOIN	#ListDataSource	ld	ON	ld.VarGroupId = cp.VarGroupId
WHERE	ld.IsNumericDataType = 1
	AND	cp.IsNonNormal = 0
	AND	cp.TestStDev > 0.0
	AND	ld.IsAtt = 0
-----------------------------------------------------------------------------------------------------------------------
--		TempTl and TempTu
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		TempTl = 1 / (1 + @ConstantP * TempXl),
		TempTu = 1 / (1 + @ConstantP * TempXu)
FROM	#CalcPPM	cp
	JOIN	#ListDataSource	ld	ON	ld.VarGroupId = cp.VarGroupId
WHERE	ld.IsNumericDataType = 1
	AND	cp.IsNonNormal = 0
	AND	ld.IsAtt = 0
-----------------------------------------------------------------------------------------------------------------------
--		ZLower and ZUpper
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		ZLower = 1000000.0 	*  	(1
							- 	(1
							- 	(POWER(@ConstantE, -POWER(TempXl, 2) / 2) / SQRT(2 * @ConstantPI))
							* 	(@ConstantB1 * TempTl
							+  	@ConstantB2 * POWER(TempTl, 2)
							+  	@ConstantB3 * POWER(TempTl, 3)
							+  	@ConstantB4 * POWER(TempTl, 4)
							+  	@ConstantB5 * POWER(TempTl, 5) )
							+  	@ConstantErrorX )),
		ZUpper = 1000000.0 	*   (1
							- 	(1
							- 	(POWER(@ConstantE, -POWER(TempXu, 2) / 2) / SQRT(2 * @ConstantPI))
							* 	(@ConstantB1 * TempTu
							+ 	@ConstantB2 * POWER(TempTu, 2)
							+ 	@ConstantB3 * POWER(TempTu, 3)
							+ 	@ConstantB4 * POWER(TempTu, 4)
							+ 	@ConstantB5 * POWER(TempTu, 5) )
							+ 	@ConstantErrorX ))
FROM	#CalcPPM	cp
	JOIN	#ListDataSource	ld	ON	ld.VarGroupId = cp.VarGroupId
WHERE	ld.IsNumericDataType = 1
	AND	cp.IsNonNormal = 0
	AND	ld.IsAtt = 0
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE POOL PPM '
--=====================================================================================================================
--	CALCULATE POOL PPM
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		CalcPPMPoolActual = ISNULL(ZLower, 0) + ISNULL(ZUpper, 0)
FROM	#CalcPPM			cp
JOIN	#ListDataSource		ld		ON	ld.VarGroupId = cp.VarGroupId
WHERE	ld.IsNumericDataType = 1
		AND	cp.IsNonNormal = 0
		AND	ld.IsAtt = 0

--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE NON-NORMAL DATA PPM'
--=====================================================================================================================
-- CalcPPM (N): for numeric data that has a non-normal distribution (NormType = 'N')
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'		.	CalcPPM (N) - ' + CONVERT(VarChar(50), GetDate(), 121) + ' Open Transactions: ' + CONVERT(VARCHAR, @@TRANCOUNT) -- debug
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (	SELECT	CalcPPMId
			FROM	#CalcPPM
			WHERE 	IsNonNormal = 1)
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'			MajorGroupId: ' + CONVERT(VarChar, @intMajorGroupId) + ' MinorGroupId: ' + CONVERT(VarChar, @intMinorGroupId)
	-------------------------------------------------------------------------------------------------------------------
	DELETE #TempValue
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO #TempValue(ValueINT)
	SELECT CalcPPMId
	FROM	#CalcPPM
	WHERE	IsNonNormal = 1 
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@j = 1,
			@intMAXPPMId = MAX(RcdIdx)	
	FROM	#TempValue	
	-------------------------------------------------------------------------------------------------------------------
	WHILE	@j <= @intMAXPPMId	
	BEGIN
		SELECT @intCalcPPMId = ValueINT
		FROM #TempValue
		WHERE RcdIdx = @j
		---------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1	PRINT	'				CalcPPMId - ' + CONVERT(VarChar, @intCalcPPMId) 
		---------------------------------------------------------------------------------------------------------------
		TRUNCATE TABLE	#TempCalcPPMRawData
		---------------------------------------------------------------------------------------------------------------
		-- CalcPPM (N): RESET IDENTITY
		---------------------------------------------------------------------------------------------------------------
		SET IDENTITY_INSERT #TempCalcPPMRawData ON
		INSERT INTO	#TempCalcPPMRawData (
					ResultRank)
			VALUES	(0)
		SET IDENTITY_INSERT #TempCalcPPMRawData OFF
		---------------------------------------------------------------------------------------------------------------
		-- CalcPPM (N): Get raw values for variables with 
		--	NormType = "N"	and TargetRangeSpecId > 0
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	#TempCalcPPMRawData (	-- Raw data for non-normal distributions i.e. Extended_Info = "Norm = N"
					CalcPPMId,
					MajorGroupId,
					MinorGroupId,
					VarGroupId,
					Result,
					ResultTimeStamp,
					HistTestFlag,
					LEL,
					LSL,
					Target,
					USL,
					UEL,
					LTL,
					UTL,
					SpecVersion )
		SELECT		cpi.CalcPPMId,
					cpi.MajorGroupId,
					cpi.MinorGroupId,
					cpi.VarGroupId,
					nnv.Result,
					nnv.ResultOn,
					nnv.HistTestFlag,
					cpi.LEL,
					cpi.LSL,
					cpi.Target,
					cpi.USL,
					cpi.UEL,
					cpi.LTL,
					cpi.UTL,
					cpi.SpecVersion
		FROM	#CalcPPM				cpi
			JOIN	#NonNormalValuesTemp2	nnv	ON	cpi.CalcPPMId = nnv.CalcPPMId
		WHERE	cpi.CalcPPMId	=	@intCalcPPMId
		ORDER BY	nnv.Result, nnv.ResultOn
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO		@tblCalcPPMRawData (	
						CalcPPMId	,
						MajorGroupId,
						MinorGroupId,
						VarGroupId,
						Result,
						ResultRank,
						ResultTimeStamp,
						HistTestFlag,
						LEL,
						LSL,
						Target,
						USL,
						UEL,
						LTL,
						UTL,
						SpecVersion )
		SELECT			CalcPPMId	,
						MajorGroupId,
						MinorGroupId,
						VarGroupId,
						Result,
						ResultRank,
						ResultTimeStamp,
						HistTestFlag,
						LEL,
						LSL,
						Target,
						USL,
						UEL,
						LTL,
						UTL,
						SpecVersion
		FROM	#TempCalcPPMRawData
		WHERE	ResultRank > 0
		AND ISNUMERIC(Result) = 1				-- martin
		---------------------------------------------------------------------------------------------------------------
		-- Increment COUNTer
		---------------------------------------------------------------------------------------------------------------
		SET @j = @j + 1
	END											
END
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): caculate h'
-----------------------------------------------------------------------------------------------------------------------
-- h = 0.9 * (min(StDev, r/1.34) * (TestCount^(-0.2))
-- r = R75-R25
-- If r = 0 then use StDev
-- R75 = Percentile(RawData, 0.75)
-- R25 = Percentile(RawData, 0.25)
-- Note: procedure for calculating a percentile
-- 1) Percentiles are values that divide a set of observations into 100 equal parts
-- 2) rank data in increasing order of magnitude
-- 3) find the rank that corrresponds to the desired percentile e.g. (85/100) * TestCount
-- 4) e.g. table with 8 values
-- --------------
-- | Rank| value|
-- --------------
-- | 1   |  10  |
-- | 2   |	11	|
-- | 3   |  12  |
-- | 4   |  15  |
-- | 5   |	15	|
-- | 6   |  18  |
-- | 7   |  20  |
-- | 8   |	21	|
-- --------------
-- Rank for R25 = 2 Since 2 is a whole number the value that corresponds to R25 = (11 + 10 / 2) = 10.5 (ranks 1 and 2)
-- Rank for R40 = 3.2 Since 3.2 is a fraction then the value that correponds to R45 = 15 (rank 4)
-- i.e. then the rank is a fractional it is customary to use the next highest whole number to find the
-- required percentile.
-- Source: Introduction to Statistics (third edition by Ronald E. Walpole)
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblDistributionFactorCalc (
			CalcPPMId	,
			MajorGroupId,
			MinorGroupId,
			VarGroupId	,
			VarStDev	,
			VarTestCount,
			VarR25Rank	,
			VarR75Rank	)
SELECT		CalcPPMId			,
			MajorGroupId		,
			MinorGroupId		,
			VarGroupId			,
			StDev(Result)		,
			COUNT(Result)		,
			0.25 * COUNT(Result),
			0.75 * COUNT(Result)
FROM		@tblCalcPPMRawData
GROUP BY	CalcPPMId, MajorGroupId, MinorGroupId, VarGroupId
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): get the ranked values'
-----------------------------------------------------------------------------------------------------------------------
DELETE #TempValue
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #TempValue(ValueINT)
SELECT CalcPPMId
FROM @tblDistributionFactorCalc
-----------------------------------------------------------------------------------------------------------------------
SELECT	@j = 1,
		@intMAXPPMId = MAX(RcdIdx)	
FROM	#TempValue	
-----------------------------------------------------------------------------------------------------------------------
WHILE @j <= @intMAXPPMId
BEGIN
	SELECT	@intCalcPPMId 	= df.CalcPPMId,
			@fltVarR25Rank	= df.VarR25Rank,
			@fltVarR75Rank 	= df.VarR75Rank
	FROM #TempValue tp
		JOIN @tblDistributionFactorCalc df ON tp.ValueINT = df.CalcPPMId
	WHERE tp.RcdIdx = @j
	-------------------------------------------------------------------------------------------------------------------
	IF	CONVERT(INT, @fltVarR25Rank) < @fltVarR25Rank
	BEGIN
		UPDATE		@tblDistributionFactorCalc 
		SET		VarR25Value2 = Result
		FROM	@tblCalcPPMRawData			cp	
			JOIN	@tblDistributionFactorCalc 	df	ON	df.VarGroupId = cp.VarGroupId
		WHERE	df.CalcPPMId 	= @intCalcPPMId
			AND		cp.ResultRank 	= CONVERT(INT, @fltVarR25Rank) + 1
	END
	ELSE
	BEGIN
		UPDATE	@tblDistributionFactorCalc 
		SET			VarR25Value2 = Result
		FROM		@tblCalcPPMRawData			cp	
			JOIN	@tblDistributionFactorCalc 	df	ON	df.VarGroupId = cp.VarGroupId
		WHERE		df.CalcPPMId 	= @intCalcPPMId
			AND		cp.ResultRank 	= @fltVarR25Rank
		---------------------------------------------------------------------------------------------------------------
		UPDATE		@tblDistributionFactorCalc 
		SET		VarR25Value1 = Result
		FROM	@tblCalcPPMRawData			cp	
			JOIN	@tblDistributionFactorCalc 	df	ON	df.VarGroupId = cp.VarGroupId
		WHERE	df.CalcPPMId 	= @intCalcPPMId
			AND		cp.ResultRank 	= @fltVarR25Rank - 1
	END
	-------------------------------------------------------------------------------------------------------------------
	IF	CONVERT(Int, @fltVarR75Rank) < @fltVarR75Rank
	BEGIN
		UPDATE		@tblDistributionFactorCalc 
		SET		VarR75Value2 = Result
		FROM	@tblCalcPPMRawData			cp	
			JOIN	@tblDistributionFactorCalc 	df	ON	df.VarGroupId = cp.VarGroupId
		WHERE	df.CalcPPMId 	= @intCalcPPMId
			AND		cp.ResultRank 	= CONVERT(Int, @fltVarR75Rank) + 1
	END
	ELSE
	BEGIN
		UPDATE		@tblDistributionFactorCalc 
		SET		VarR75Value2 = Result
		FROM	@tblCalcPPMRawData			cp 
			JOIN	@tblDistributionFactorCalc 	df	ON	df.VarGroupId = cp.VarGroupId
		WHERE	df.CalcPPMId	= @intCalcPPMId
			AND		cp.ResultRank 	= @fltVarR75Rank
		---------------------------------------------------------------------------------------------------------------
		UPDATE		@tblDistributionFactorCalc 
		SET		VarR75Value1 = Result
		FROM	@tblCalcPPMRawData			cp	
			JOIN	@tblDistributionFactorCalc 	df	ON	df.VarGroupId = cp.VarGroupId
		WHERE	df.CalcPPMId 	= @intCalcPPMId
			AND		cp.ResultRank 	= @fltVarR75Rank - 1
	END
   	-------------------------------------------------------------------------------------------------------------------	
	-- Increment COUNTer
   	-------------------------------------------------------------------------------------------------------------------
	SET @j = @j + 1
END
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): get the average of the ranked values where applicable'
-----------------------------------------------------------------------------------------------------------------------
UPDATE	@tblDistributionFactorCalc
SET		VarR25Value = (COALESCE(VarR25Value1, VarR25Value2) + VarR25Value2)/2,
		VarR75Value = (COALESCE(VarR75Value1, VarR75Value2) + VarR75Value2)/2
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate r'
-----------------------------------------------------------------------------------------------------------------------
UPDATE	@tblDistributionFactorCalc
SET		r = VarR75Value - VarR25Value
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate h'
-----------------------------------------------------------------------------------------------------------------------
UPDATE	@tblDistributionFactorCalc
SET		h = CASE	WHEN	r = 0	
						THEN	0.9 * (VarStDev * Power(CONVERT(FLOAT, VarTestCount), -0.2))
					WHEN	VarStDev <	(r / 1.34) 
						THEN	0.9 * (VarStDev * Power(CONVERT(FLOAT, VarTestCount), -0.2))
					ELSE	0.9 * ((r / 1.34) * Power(CONVERT(FLOAT, VarTestCount), -0.2))
					END
WHERE	VarTestCount > 1
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): update h in Raw Data table'
-----------------------------------------------------------------------------------------------------------------------
UPDATE	rd
SET		rd.h = df.h
FROM	@tblCalcPPMRawData				rd 
	JOIN	@tblDistributionFactorCalc	df	ON	df.CalcPPMId = rd.CalcPPMId
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate Adjusted h in Raw Data table'
-----------------------------------------------------------------------------------------------------------------------
-- CalcPPM (N): calculate adjusted h in Raw Data table
-- If value - previous value > current h then
-- h = value - previous value
-- else if
-- next value - value > h then
-- h = next value - value
-- else h
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): Adjh1Cursor'
-----------------------------------------------------------------------------------------------------------------------
DELETE #TempValue
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO #TempValue(ValueINT)
SELECT CalcPPMId
FROM @tblDistributionFactorCalc
-----------------------------------------------------------------------------------------------------------------------
SELECT	@j = 1,
		@intMAXPPMId = MAX(RcdIdx)	
FROM	#TempValue	
-----------------------------------------------------------------------------------------------------------------------
WHILE @j <= @intMAXPPMId
BEGIN
	SELECT	@intCalcPPMId 	= df.CalcPPMId,
			@flth			= df.h
	FROM #TempValue tp
		JOIN @tblDistributionFactorCalc df ON tp.ValueINT = df.CalcPPMId
	WHERE tp.RcdIdx = @j
	-------------------------------------------------------------------------------------------------------------------
	IF	(	SELECT	COUNT(DISTINCT Result)
			FROM	@tblCalcPPMRawData
			WHERE	CalcPPMId = @intCalcPPMId ) > 1
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		-- IF @intPRINTFlag = 1	PRINT	'				CalcPPMId = ' + CONVERT(VARCHAR(100), @intCalcPPMId) + '; ' + 'h = ' + CONVERT(VARCHAR(50), @flth )
		---------------------------------------------------------------------------------------------------------------
		-- Clear @tblCalcPPMRawDataTemp
		---------------------------------------------------------------------------------------------------------------
		DELETE	@tblCalcPPMRawDataTemp
		---------------------------------------------------------------------------------------------------------------
		-- Insert data sub-set into @tblCalcPPMRawDataTemp
		-- This was done to improve performance in this section of code
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblCalcPPMRawDataTemp (	
					RcdId				,
					CalcPPMId			,
					VarGroupId			,
					ResultRank			,
					Result				,
					ResultTimeStamp		,
					h					,
					Adjustedh			)
		SELECT	RcdId				,
				CalcPPMId			,
				VarGroupId			,
				ResultRank			,
				Result				,
				ResultTimeStamp		,
				h					,
				Adjustedh			
		FROM	@tblCalcPPMRawData
		WHERE	CalcPPMId = @intCalcPPMId		
		---------------------------------------------------------------------------------------------------------------
		DELETE #TempValue2
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO #TempValue2 (ValueINT, ValueFLOAT)
		SELECT	Result,
				ResultRank
		FROM	@tblCalcPPMRawDataTemp
		ORDER BY ResultRank
		---------------------------------------------------------------------------------------------------------------
		SELECT @i = 1,
			   @intMAXRcdIdx = MAX(RcdIdx)	
		FROM #TempValue2
		---------------------------------------------------------------------------------------------------------------
		WHERE @i <= @intMAXRcdIdx
		BEGIN
			SELECT	@fltResult = ValueFLOAT,
					@intResultRank = ValueINT
			FROM #TempValue2
			WHERE RcdIdx = @i
			-----------------------------------------------------------------------------------------------------------
			-- Re-set variable values
			-----------------------------------------------------------------------------------------------------------
			SET	@fltPreviousValue 	= Null
			SET	@fltNextValue 		= Null
			-----------------------------------------------------------------------------------------------------------
			-- Previous value
			-----------------------------------------------------------------------------------------------------------
			IF NOT EXISTS (	SELECT	ResultRank
							FROM 	@tblCalcPPMRawDataTemp 
							WHERE	CalcPPMId 	= @intCalcPPMId
								AND	ResultRank 	= @intResultRank - 1)
			BEGIN
				SET	@fltPreviousValue = NULL
			END
			ELSE
			BEGIN
				SELECT		@fltPreviousValue = Result
				FROM	@tblCalcPPMRawDataTemp 
				WHERE	CalcPPMId 	= @intCalcPPMId
					AND	ResultRank 	= @intResultRank - 1
			END
			-----------------------------------------------------------------------------------------------------------
			-- Value
			-----------------------------------------------------------------------------------------------------------
			SELECT		@fltValue = Result
			FROM	@tblCalcPPMRawDataTemp 
			WHERE	CalcPPMId	= @intCalcPPMId
				AND	ResultRank 	= @intResultRank
			-----------------------------------------------------------------------------------------------------------
			-- Next value
			-----------------------------------------------------------------------------------------------------------
			IF NOT EXISTS (	SELECT	ResultRank
							FROM 	@tblCalcPPMRawDataTemp 
							WHERE	CalcPPMId 	= @intCalcPPMId
								AND	ResultRank 	= @intResultRank + 1) 
			BEGIN
				SET	@fltNextValue = NULL
			END
			ELSE
			BEGIN
				SELECT		@fltNextValue = Result
				FROM	@tblCalcPPMRawDataTemp 
				WHERE	CalcPPMId 	= @intCalcPPMId
					AND	ResultRank 	= @intResultRank + 1
			END
			-----------------------------------------------------------------------------------------------------------
			-- Adjusted h
			-----------------------------------------------------------------------------------------------------------
			IF NOT EXISTS (	SELECT	ResultRank
								FROM 	@tblCalcPPMRawDataTemp 
								WHERE	CalcPPMId = @intCalcPPMId
								AND		ResultRank = @intResultRank - 1)
			BEGIN		
				-------------------------------------------------------------------------------------------------------
				-- Adjusted h for first value
				-------------------------------------------------------------------------------------------------------
				IF 	@fltNextValue - @fltValue > @flth
				BEGIN
					SELECT	@fltAdjustedh = @fltNextValue - @fltValue
				END
				ELSE
				BEGIN
					SELECT	@fltAdjustedh = @flth
				END
			END
			ELSE IF NOT EXISTS (SELECT	ResultRank
								FROM 	@tblCalcPPMRawDataTemp 
								WHERE	CalcPPMId	= @intCalcPPMId
									AND	ResultRank 	= @intResultRank + 1)
			BEGIN
				-------------------------------------------------------------------------------------------------------
				-- Adjusted h for last value
				-------------------------------------------------------------------------------------------------------
				IF	@fltValue - @fltPreviousValue > @flth
				BEGIN
					SELECT	@fltAdjustedh = @fltValue - @fltPreviousValue
				END									
				ELSE
				BEGIN
					SELECT	@fltAdjustedh = @flth
				END
			END
			ELSE
			BEGIN
				-------------------------------------------------------------------------------------------------------
				-- Adjusted h for all other values
				-------------------------------------------------------------------------------------------------------
				IF	@fltValue - @fltPreviousValue > @flth
				BEGIN
					SET	@fltAdjustedh1 = @fltValue - @fltPreviousValue
				END	
				ELSE
				BEGIN
					SET	@fltAdjustedh1 = @flth
				END	
				-------------------------------------------------------------------------------------------------------
				IF	@fltNextValue - @fltValue > @flth
				BEGIN
					SET	@fltAdjustedh2 = @fltNextValue - @fltValue
				END
				ELSE
				BEGIN
					SET	@fltAdjustedh2 = @flth
				END
				-------------------------------------------------------------------------------------------------------
				IF	@fltAdjustedh1 > @fltAdjustedh2
				BEGIN
					SET	@fltAdjustedh = @fltAdjustedh1
				END
				ELSE
				BEGIN
					SET	@fltAdjustedh = @fltAdjustedh2
				END
			END		
			------------------------------------------------------------------------------------------------------------
			-- UPDATE Adjusted h
			------------------------------------------------------------------------------------------------------------
			UPDATE	cp
			SET		Adjustedh = @fltAdjustedh 
			FROM	@tblCalcPPMRawDataTemp cp 
			WHERE	CalcPPMId 	= @intCalcPPMId
				AND	ResultRank 	= @intResultRank
			------------------------------------------------------------------------------------------------------------
			-- Increment COUNTer
			------------------------------------------------------------------------------------------------------------
			SET @i = @i + 1
		END
		----------------------------------------------------------------------------------------------------------------
		-- UPDATE Main table @tblCalcPPMRawDataTemp
		----------------------------------------------------------------------------------------------------------------
		UPDATE	cprd
			SET	cprd.Adjustedh = cprdt.Adjustedh
			FROM	@tblCalcPPMRawDataTemp	cprdt
			JOIN	@tblCalcPPMRawData		cprd	ON	cprdt.RcdId = cprd.RcdId
	END
	ELSE
	BEGIN
		UPDATE		@tblCalcPPMRawData
			SET		Adjustedh 	= @flth
			WHERE	CalcPPMId 	= @intCalcPPMId
	END
	--------------------------------------------------------------------------------------------------------------------
	--Increment COUNTer
	--------------------------------------------------------------------------------------------------------------------
	SET @j = @j + 1
END
------------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate Max Z and Min Z'
------------------------------------------------------------------------------------------------------------------------
-- Check for constraints on entry limits
------------------------------------------------------------------------------------------------------------------------
UPDATE	@tblCalcPPMRawData
SET		MaxZ = 	CASE	WHEN	UEL = '1.0e+300'
						THEN	8.0
						WHEN	((CONVERT(DECIMAL(20,10), UEL) - Result) / Adjustedh) > 8.0
						THEN 	8.0
						ELSE	(CONVERT(DECIMAL(20,10), UEL) - Result) / Adjustedh
				END,
		MinZ = 	CASE	WHEN	LEL = '1.0e-300'
						THEN	-8.0
						WHEN	((CONVERT(DECIMAL(20,10), LEL) - Result) / Adjustedh) < -8.0
						THEN 	-8.0
						ELSE	(CONVERT(DECIMAL(20,10), LEL) - Result) / Adjustedh
				END
WHERE	Adjustedh > 0
------------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate TempXl and TempXu using spec limits'
------------------------------------------------------------------------------------------------------------------------
UPDATE	@tblCalcPPMRawData
SET		TempXl = ABS(Result - CONVERT(DECIMAL(20, 10), LSL))/Adjustedh,
		TempXu = ABS(CONVERT(DECIMAL(20,10), USL) - Result) /Adjustedh
WHERE	Adjustedh > 0
------------------------------------------------------------------------------------------------------------------------		
UPDATE	@tblCalcPPMRawData
SET		TempXl = ABS(Result - CONVERT(DECIMAL(20, 10), LSL)),
		TempXu = ABS(CONVERT(DECIMAL(20,10), USL) - Result)
WHERE	Adjustedh = 0
------------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate the intermediate values of the NormSDist equations'
------------------------------------------------------------------------------------------------------------------------
UPDATE	@tblCalcPPMRawData
SET	TempTl 	= 	CASE 	WHEN	TempXl <> 0 
						THEN	1 / (1 + @ConstantP * TempXl)
						ELSE    1
				END,
	TempTu	= 	CASE 	WHEN 	TempXu <> 0 
						THEN	1 / (1 + @ConstantP * TempXu)
						ELSE	1
				END,
	MinT 	= 	CASE 	WHEN 	ABS(MinZ) > 0 
						THEN	1 / (1 + @ConstantP * ABS(MinZ))
				END,
	MaxT 	= 	CASE 	WHEN 	ABS(MaxZ) > 0 
						THEN	1 / (1 + @ConstantP * ABS(MaxZ))
				END
------------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate the normalization factor'
------------------------------------------------------------------------------------------------------------------------
-- Note: The objective here is to normalize the data, therefore we are looking at the entire normal
-- curve. 1-(...... looks only at the outer areas of the normal curve
------------------------------------------------------------------------------------------------------------------------
UPDATE		cp
SET		NormMin =  CASE	WHEN	MinZ < 0 
						THEN	  ((POWER(@ConstantE, -POWER(ABS(MinZ), 2) / 2) / SQRT(2 * @ConstantPI))
								* (@ConstantB1 * MinT
								+  @ConstantB2 * POWER(MinT, 2)
								+  @ConstantB3 * POWER(MinT, 3)
								+  @ConstantB4 * POWER(MinT, 4)
								+  @ConstantB5 * POWER(MinT, 5) )
								+  @ConstantErrorX )
						ELSE	  (1
								- (POWER(@ConstantE, -POWER(ABS(MinZ), 2) / 2) / SQRT(2 * @ConstantPI))
								* (@ConstantB1 * MinT
								+  @ConstantB2 * POWER(MinT, 2)
								+  @ConstantB3 * POWER(MinT, 3)
								+  @ConstantB4 * POWER(MinT, 4)
								+  @ConstantB5 * POWER(MinT, 5) )
								+  @ConstantErrorX )
						END,
		NormMax =  CASE	WHEN	MaxZ < 0
						THEN	  ((POWER(@ConstantE, -POWER(ABS(MaxZ), 2) / 2) / SQRT(2 * @ConstantPI))
								* (@ConstantB1 * MaxT
								+  @ConstantB2 * POWER(MaxT, 2)
								+  @ConstantB3 * POWER(MaxT, 3)
								+  @ConstantB4 * POWER(MaxT, 4)
								+  @ConstantB5 * POWER(MaxT, 5) )
								+  @ConstantErrorX )
						ELSE	  (1
								- (POWER(@ConstantE, -POWER(ABS(MaxZ), 2) / 2) / SQRT(2 * @ConstantPI))
								* (@ConstantB1 * MaxT
								+  @ConstantB2 * POWER(MaxT, 2)
								+  @ConstantB3 * POWER(MaxT, 3)
								+  @ConstantB4 * POWER(MaxT, 4)
								+  @ConstantB5 * POWER(MaxT, 5) )
								+  @ConstantErrorX )
						END
FROM	@tblCalcPPMRawData	cp
------------------------------------------------------------------------------------------------------------------------
UPDATE	@tblCalcPPMRawData
SET		NormFactor = NormMax - NormMin
------------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'			CalcPPM (N): calculate ZLower and ZUpper for each sample'
------------------------------------------------------------------------------------------------------------------------
UPDATE		cp
SET		ZLower = CASE	WHEN	(ISNULL(NormFactor,0)	<> 0)
						THEN	1000000		* 	   (1
												 - (1
												 - ((POWER(@ConstantE, -POWER(TempXl, 2) / 2) / SQRT(2 * @ConstantPI))
												 * (@ConstantB1 * TempTl
												 +  @ConstantB2 * POWER(TempTl, 2)
												 +  @ConstantB3 * POWER(TempTl, 3)
												 +  @ConstantB4 * POWER(TempTl, 4)
												 +  @ConstantB5 * POWER(TempTl, 5) )
												 +  @ConstantErrorX )))/NormFactor
						ELSE	1000000		* 	   (1 
												 - (1
												 - (POWER(@ConstantE, -POWER(TempXl, 2) / 2) / SQRT(2 * @ConstantPI))
												 * (@ConstantB1 * TempTl
												 +  @ConstantB2 * POWER(TempTl, 2)
												 +  @ConstantB3 * POWER(TempTl, 3)
												 +  @ConstantB4 * POWER(TempTl, 4)
												 +  @ConstantB5 * POWER(TempTl, 5) )
												 +  @ConstantErrorX ))
						END,
		ZUpper = CASE	WHEN	(ISNULL(NormFactor,0)	<> 0)
						THEN	1000000		* 	   (1
												 - (1
												 - ((POWER(@ConstantE, -POWER(TempXu, 2) / 2) / SQRT(2 * @ConstantPI))
												 * (@ConstantB1 * TempTu
												 +  @ConstantB2 * POWER(TempTu, 2)
												 +  @ConstantB3 * POWER(TempTu, 3)
												 +  @ConstantB4 * POWER(TempTu, 4)
												 +  @ConstantB5 * POWER(TempTu, 5) )
												 +  @ConstantErrorX )))/NormFactor
						ELSE	1000000		* 	   (1
												 - (1
												 - (POWER(@ConstantE, -POWER(TempXu, 2) / 2) / SQRT(2 * @ConstantPI))
												 * (@ConstantB1 * TempTu
												 +  @ConstantB2 * POWER(TempTu, 2)
												 +  @ConstantB3 * POWER(TempTu, 3)
												 +  @ConstantB4 * POWER(TempTu, 4)
												 +  @ConstantB5 * POWER(TempTu, 5) )
												 +  @ConstantErrorX ))
						END
FROM	@tblCalcPPMRawData	cp
------------------------------------------------------------------------------------------------------------------------
-- CalcPPM (N): calculate test fail
------------------------------------------------------------------------------------------------------------------------
IF	@intSpecSetting = 1 
BEGIN
	UPDATE	cp
	SET		TestFail	=	CASE	WHEN	CONVERT(FLOAT, Result) < COALESCE(CONVERT(DECIMAL(20, 10), LSL), -999999999.)
									OR 		CONVERT(FLOAT, Result) > COALESCE(CONVERT(DECIMAL(20, 10), USL), 999999999.) 
									THEN 1
									ELSE 0 
							END
	FROM	@tblCalcPPMRawData	cp
END
ELSE
BEGIN
	UPDATE		cp
	SET		TestFail	=	CASE	WHEN	CONVERT(FLOAT, Result) <= COALESCE(CONVERT(DECIMAL(20, 10), LSL), -999999999.)
									OR 		CONVERT(FLOAT, Result) >= COALESCE(CONVERT(DECIMAL(20, 10), USL), 999999999.) 
									THEN 1
									ELSE 0 
							END
	FROM	@tblCalcPPMRawData	cp
END

--======================================================================================================================
IF @intPRINTFlag = 1	PRINT 'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GetDate())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GetDate()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '--------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT	'	-	Add Norm = N variables to the #CalcPPM table '
------------------------------------------------------------------------------------------------------------------------
-- CalcPPM: Add the Norm = N PPM values to #CalcPPM table
------------------------------------------------------------------------------------------------------------------------
INSERT INTO	@tblNonNormalPPMValuesTemp (
			CalcPPMId			,
			ZLower				,
			ZUpper				,
			CalcPPMPoolActual	)
SELECT		CalcPPMId								,
			SUM(ISNULL(ZLower, 0))/COUNT(Result)	,
			SUM(ISNULL(ZUpper, 0))/COUNT(Result)	,
			(SUM(ISNULL(ZLower, 0)) + SUM(ISNULL(ZUpper, 0)))/COUNT(Result)
FROM		@tblCalcPPMRawData
GROUP BY	CalcPPMId

------------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET	cp.ZLower				=	nnv.ZLower,
	cp.ZUpper				=	nnv.ZUpper,	
	cp.CalcPPMPoolActual	=	nnv.CalcPPMPoolActual
FROM	#CalcPPM					cp	
	JOIN	@tblNonNormalPPMValuesTemp	nnv	ON	cp.CalcPPMId = nnv.CalcPPMId
------------------------------------------------------------------------------------------------------------------------
-- Fix from Validation : if all samples are defects then CalcPPMPoolActual = 1000000
------------------------------------------------------------------------------------------------------------------------
UPDATE  cp
SET	    cp.CalcPPMPoolActual	=	1000000
FROM	#CalcPPM					cp	
WHERE   (cp.TestFail = cp.TestCount) and cp.TestCount > 0
------------------------------------------------------------------------------------------------------------------------
PRINT '			.	Check for empty recordset'
------------------------------------------------------------------------------------------------------------------------
IF	(	SELECT 		COUNT(*) 
			FROM	#CalcPPM ) = 0
BEGIN
	SELECT 5 ErrorCode, * FROM	@tblFilterCriteria
	-- RETURN 5
END
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE VARIABLE VOLUME COUNT'
--=====================================================================================================================
--	CALCULATE VARIABLE VOLUME COUNT
--	NOTE: this is done here and not in the Raw Data section to simplify the logic and only do the volume calculation
--		  once instead of 3 times. Once for Attributes, once for Normal data and once for non-normal data. 
--	a.	Calculate CalcPPM Volume and put into a temporary table
--	b.	Identify Spec Scenarious for #CalcPPM
--	c.	Identify Spec Scenarious for @tblVarProductionInterim2
--	d.	UPDATE	VolumeCount on #CalcPPM
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE CalcPPM Volume and put into a temporary table'
--=====================================================================================================================
--	a.	CALCULATE CalcPPM Volume and put into a temporary table
-- 		Note: do not need to delete slices where test COUNT = 0 and test COUNT = 1 from this table
-- 		The slices have been dropped from the #CalcPPM table
--		Note: if volume COUNT is production then time slice volume / var COUNT, else
--		Volume COUNT = Test COUNT
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 0 -- Production COUNT
BEGIN
	INSERT INTO	@tblVarProductionInterim2 (
				MajorGroupId	,
				MinorGroupId	,
				IsNumericDataType,
				PLId			,
				PUGId			,
				ProductGrpId	,
				PO				,
				VarGroupId		, 
				LEL				,
				LSL				,
				Target			,
				USL				,
				UEL				,
				LTL				,
				UTL				,
				SpecVersion		,
				VolumeCount		)
	SELECT	vt.MajorGroupId,
			vt.MinorGroupId,
			ld.IsNumericDataType,
			vt.PLId,
			ld.PUGId,
			vt.ProductGrpId,
			vt.PO,
			ld.VarGroupId,
			LEL,			
			LSL,			
			Target,		
			USL,			
			UEL,			
			LTL,			
			UTL,			
			CONVERT(VARCHAR(35), MAX(CONVERT(DATETIME, vt.SpecVersion)), 121),
			SUM(vt.TimeSliceVolumeCount) / ld.VarCount
	FROM		#ValidVarTimeSlices	vt
	INNER JOIN	#ListDataSource		ld	ON vt.VarId =	ld.VarId	
										   AND vt.PLId = ld.PLId
	WHERE 		vt.TimeSliceEliminationFlag = 0
	GROUP BY	vt.MajorGroupId, vt.MinorGroupId, vt.PLId, ld.PUGId, 
				vt.ProductGrpId, vt.PO, ld.VarGroupId, ld.VarCount,
				vt.LEL, vt.LSL, vt.Target, vt.USL, vt.UEL, vt.LTL, vt.UTL		,
				ld.IsNumericDataType

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Identify Spec Scenarious for CalcPPM'
	--=================================================================================================================
	--	b.	Identify Spec Scenarious for CalcPPM
	-- 		NOTE:	Some sites have the same spec version but different spec value on their time slices
	-- 		Because of this the join that adds that updated volume COUNT to #CalcPPM must include the spec values
	-- 		Because some spec values can be NULL the updates have been broken down into scenarios
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM	
	SET	StatusLEL			=	CASE	WHEN	LEL IS NOT NULL
										THEN	LTRIM(RTRIM(LEL))
										ELSE	'x'
										END,
		StatusLSL			=	CASE	WHEN	LSL IS NOT NULL
				 						THEN	LTRIM(RTRIM(LSL))
										ELSE	'x'
										END,
		StatusLTL			=	CASE	WHEN	LTL IS NOT NULL
				 						THEN	LTRIM(RTRIM(LTL))
										ELSE	'x'
				 						END,
		StatusTarget		=	CASE	WHEN	Target IS NOT NULL
										THEN	LTRIM(RTRIM(Target))
										ELSE	'x'
				 						END,
		StatusUTL			=	CASE	WHEN	UTL IS NOT NULL
										THEN	LTRIM(RTRIM(UTL))
										ELSE	'x'
				 						END,
		StatusUSL			=	CASE	WHEN	USL IS NOT NULL
				 						THEN	LTRIM(RTRIM(USL))
										ELSE	'x'
				 						END,
		StatusUEL			=	CASE	WHEN	UEL IS NOT NULL
				 						THEN	LTRIM(RTRIM(UEL))
										ELSE	'x'
				 						END,
		StatusSpecVersion	=	CASE	WHEN	SpecVersion IS NOT NULL
				 						AND		LEN(LTrim(RTrim(SpecVersion))) > 0
										THEN	LTRIM(RTRIM(SpecVersion))
										ELSE	'x'
				 						END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Identify Spec Scenarious for @tblVarProductionInterim2	'
	--=================================================================================================================
	UPDATE	@tblVarProductionInterim2	
	SET	StatusLEL			=	CASE	WHEN	LEL IS NOT NULL
										THEN	LTRIM(RTRIM(LEL))
										ELSE	'x'
										END,
		StatusLSL			=	CASE	WHEN	LSL IS NOT NULL
				 						THEN	LTRIM(RTRIM(LSL))
										ELSE	'x'
										END,
		StatusLTL			=	CASE	WHEN	LTL IS NOT NULL
				 						THEN	LTRIM(RTRIM(LTL))
										ELSE	'x'
				 						END,
		StatusTarget		=	CASE	WHEN	Target IS NOT NULL
										THEN	LTRIM(RTRIM(Target))
										ELSE	'x'
				 						END,
		StatusUTL			=	CASE	WHEN	UTL IS NOT NULL
										THEN	LTRIM(RTRIM(UTL))
										ELSE	'x'
				 						END,
		StatusUSL			=	CASE	WHEN	USL IS NOT NULL
				 						THEN	LTRIM(RTRIM(USL))
										ELSE	'x'
				 						END,
		StatusUEL			=	CASE	WHEN	UEL IS NOT NULL
				 						THEN	LTRIM(RTRIM(UEL))
										ELSE	'x'
				 						END,
		StatusSpecVersion	=	CASE	WHEN	SpecVersion IS NOT NULL
				 							AND	LEN(LTrim(RTrim(SpecVersion))) > 0
										THEN	LTRIM(RTRIM(SpecVersion))
										ELSE	'x'
				 						END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UPDATE	VolumeCount on #CalcPPM	'
	--=================================================================================================================
	--	d.	UPDATE	VolumeCount on #CalcPPM
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	cp
	SET		cp.VolumeCount = vpi.VolumeCount
	FROM	#CalcPPM					cp
		JOIN	@tblVarProductionInterim2	vpi	
											ON	vpi.PLId				= 	cp.PLId														
											AND	vpi.PUGId 				= 	cp.PUGId													
											AND	vpi.ProductGrpId		=	cp.ProductGrpId													
											AND	ISNULL(0,vpi.PO)		=	ISNULL(0,cp.PODesc)													
											AND	vpi.VarGroupId			=	cp.VarGroupId	
											AND	vpi.StatusLEL			=	cp.StatusLEL
											AND	vpi.StatusLSL			=	cp.StatusLSL
											AND	vpi.StatusLTL			=	cp.StatusLTL
											AND	vpi.StatusTarget		=	cp.StatusTarget
											AND	vpi.StatusUTL			=	cp.StatusUTL
											AND	vpi.StatusUSL			=	cp.StatusUSL
											AND	vpi.StatusUEL			=	cp.StatusUEL
											AND	vpi.StatusSpecVersion	=	cp.StatusSpecVersion
											AND vpi.IsNumericDataType   =   cp.IsNumericDataType
END
ELSE
BEGIN
	-- FRRio On 2009-03-06 Turn all into Test Count
	UPDATE	cp
		SET		cp.VolumeCount 				= cp.TestCount		
		FROM	#CalcPPM	cp
END

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET SUMVolumeCount for a VarGroupId'
--=====================================================================================================================
--	This is the SUM of the volume COUNT per variable group. This number is used in some of the VAS statistics and
--	to calculate MetCritContribution when using test COUNT for volume COUNT
-----------------------------------------------------------------------------------------------------------------------
DELETE		@tblTempPadCOUNT

IF	@intRptVolumeWeightOption = 0 -- Production COUNT
BEGIN
			INSERT INTO	@tblTempPadCOUNT	(
						MajorGroupId,
						PUGId,
						VarGroupId,	
						SUMVolumeCount)
			SELECT	MajorGroupId,
					PUGId,
					VarGroupId,
					SUM(CONVERT(FLOAT, VolumeCount))
			FROM	#CalcPPM
			WHERE	IsAtt = 0
			GROUP BY	MajorGroupId, PUGId, VarGroupId


			-----------------------------------------------------------------------------------------------------------------------
			--	Update SUMVolumeCount on #CalcPPM
			-----------------------------------------------------------------------------------------------------------------------
			UPDATE	cp
			SET		cp.SUMVolumeCount = tpc.SUMVolumeCount
			FROM	#CalcPPM	cp
				JOIN	@tblTempPadCOUNT	tpc	ON	cp.MajorGroupId 	= tpc.MajorGroupId
													AND	cp.PUGId		= tpc.PUGId
													AND	cp.VarGroupId 	= tpc.VarGroupId

END
ELSE
BEGIN
				-----------------------------------------------------------------------------------------------------------------------
				--	Update SUMVolumeCount on #CalcPPM
				--  Turned to TestCount when no volume
				-----------------------------------------------------------------------------------------------------------------------
				UPDATE	cp
						SET		cp.SUMVolumeCount = cp.VolumeCount
				FROM	#CalcPPM	cp
END


--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE MET CRITERIA'
--=====================================================================================================================
--	a.	Get formula id for met criteria
--	b.	Calculate and evaluate Cr, Tz and Cpk
--	c.	CALCULATE Met Criteria for Normal data
--	d.	CALCULATE Met Criteria for Non-Normal data
--	e.	CALCULATE Met Criteria COUNT by product group
--	f.	CALCULATE Met Criteria contribution
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' GET Formula Id for Met Criteria'
--=====================================================================================================================
--	a.	Get formula id for met criteria
-- 		Business rule: when Target is Null or TzFlag = N MCTarget = 0
-----------------------------------------------------------------------------------------------------------------------
--	SET MCUSL = 1 when USL limit IS NOT NULL
-----------------------------------------------------------------------------------------------------------------------
UPDATE	#CalcPPM
SET		MCUSL	=	1
WHERE	USL IS NOT NULL
	AND	IncludePool = 1
-----------------------------------------------------------------------------------------------------------------------
--	SET MCLSL = 1 when LSL limit IS NOT NULL
-----------------------------------------------------------------------------------------------------------------------
UPDATE	#CalcPPM
SET		MCLSL = 1
WHERE	LSL IS NOT NULL
	AND	IncludePool = 1
-----------------------------------------------------------------------------------------------------------------------
--	SET MCTarget = 1 when TzFlag = 1 AND Target IS NOT NULL and Target Range IS NULL
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		MCTarget = 1
FROM	#CalcPPM			cp
	JOIN	#ListDataSource	ds	ON	cp.VarGroupId = ds.VarGroupId
WHERE	ds.TzFlag = 1
	AND	IncludePool = 1
	AND	cp.Target IS NOT NULL
	AND	cp.LTL IS NULL
	AND	cp.UTL IS NULL
-----------------------------------------------------------------------------------------------------------------------
--	SET MCTargetRange = 1 WHEN LTL and UTL are NOT NULL
-----------------------------------------------------------------------------------------------------------------------
-- 2010-05-12 If the Target Range is one sided then set the MCTargetRange flag to 1:
UPDATE	#CalcPPM
SET		MCTargetRange = 1
WHERE	(LTL IS NOT NULL	-- AND	
	OR  UTL IS NOT NULL)
	AND	IncludePool = 1
-----------------------------------------------------------------------------------------------------------------------
--	Flag symmetric specs when Target IS NOT NULL. ie. USL - Target = Target - LSL 
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
-- SET	MCSymmetricSpecs 	= 	CASE	WHEN	(CONVERT(FLOAT, USL) - CONVERT(FLOAT, Target)) = (CONVERT(FLOAT, Target) - CONVERT(FLOAT, LSL))
SET	MCSymmetricSpecs 	= 	CASE	WHEN	(CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), Target)) = (CONVERT(DECIMAL(20, 10), Target) - CONVERT(DECIMAL(20, 10), LSL)) --CR#F0-1663
									THEN	1
									ELSE 	0
							END		
FROM	#CalcPPM			cp
	JOIN	#ListDataSource	ds	ON cp.VarGroupId = ds.VarGroupId
WHERE	cp.IncludePool = 1
	AND	ds.TzFlag = 1
	AND	cp.USL		IS NOT NULL
 	AND	cp.Target 	IS NOT NULL
 	AND	cp.LSL		IS NOT NULL
	AND	cp.LTL 		IS NULL
	AND	cp.UTL 		IS NULL
--	OBSOLETE condition
--AND		ds.TargetRangeSpecId = 0
-----------------------------------------------------------------------------------------------------------------------
--	Flag symmetric specs when Target IS NULL. ie. USL - Target = Target - LSL 
-----------------------------------------------------------------------------------------------------------------------
UPDATE	#CalcPPM
-- SET	MCSymmetricSpecs 	= 	Case	WHEN	(CONVERT(FLOAT, USL) - CONVERT(FLOAT, UTL)) = (CONVERT(FLOAT, LTL) - CONVERT(FLOAT, LSL))
SET	MCSymmetricSpecs 	= 	Case	WHEN	(CONVERT(DECIMAL(20, 10), USL) - CONVERT(DECIMAL(20, 10), UTL)) = (CONVERT(DECIMAL(20, 10), LTL) - CONVERT(DECIMAL(20, 10), LSL)) --CR#F0-1663

									THEN	1
									ELSE 	0
							END		
FROM	#CalcPPM		cp
	JOIN	#ListDataSource	ds	ON	cp.VarGroupId = ds.VarGroupId
WHERE	IncludePool = 1
	 AND	USL	IS NOT NULL
	 AND	LSL	IS NOT NULL
	 AND	UTL	IS NOT NULL
	 AND	LTL	IS NOT NULL

--	OBSOLETE condition
--AND		ds.TargetRangeSpecId = 0
-----------------------------------------------------------------------------------------------------------------------
-- GET formula ID based on the limit criteria
-----------------------------------------------------------------------------------------------------------------------

UPDATE	cp
SET		cp.MCFormulaId = fl.MCFormulaId
FROM	#CalcPPM				cp
	JOIN	#MCFormulaLookUp 	fl 	ON 	fl.MCUSL 				= cp.MCUSL
										AND	fl.MCLSL 			= cp.MCLSL
										AND	fl.MCTarget 		= cp.MCTarget
										AND	fl.MCTargetRange 	= cp.MCTargetRange
										AND	fl.MCSymmetricSpecs	= cp.MCSymmetricSpecs

-- Error #2
--select 'MCFormulaId',cp.MCFormulaId,
--		fl.MCUSL,
--		cp.MCUSL,
--		fl.MCLSL,
--		cp.MCLSL,
--		fl.MCTarget,
--		cp.MCTarget,
--		fl.MCTargetRange,
--		fl.MCTargetRange,
--		fl.MCSymmetricSpecs,
--		cp.MCSymmetricSpecs,
--*
--FROM	#CalcPPM				cp
--	JOIN	#MCFormulaLookUp 	fl 	ON 	fl.MCUSL 				= cp.MCUSL
--										AND	fl.MCLSL 			= cp.MCLSL
--										AND	fl.MCTarget 		= cp.MCTarget
--										AND	fl.MCTargetRange 	= cp.MCTargetRange
--										AND	fl.MCSymmetricSpecs	= cp.MCSymmetricSpecs
--where varDescRpt like 'V048-TGT defined not reported'

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE and evaluate Cr, Tz and Cpk'
--=====================================================================================================================
--	b.	Calculate and evaluate Cr, Tz and Cpk
-- 		Note: Cr and Cpk are not calculated for Non-Normal data. 
-----------------------------------------------------------------------------------------------------------------------
SELECT	@intRcdCOUNT = MAX(MCFormulaId),
	  	@i = 1	
FROM	#MCFormulaLookUp

-----------------------------------------------------------------------------------------------------------------------
WHILE @i <= @intRcdCOUNT
BEGIN
	SELECT	@intFormulaId = @i
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1 PRINT 	'		.	Formula ID = ' + CONVERT(VARCHAR(50), @intFormulaId)
	IF @intPRINTFlag = 1 PRINT	'		.	Cr '
	-------------------------------------------------------------------------------------------------------------------
	--	GET corresponding formula string for Cr from #MCFormulaLookUp
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchCr = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT		@vchCr = ISNULL(Cr, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	--	Calculate Cr on #CalcPPM
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchCr) > 0
	BEGIN		
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	Cr = ' + @vchCr
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
						+			'	AND		IsNonNormal	= 0'
		---------------------------------------------------------------------------------------------------------------
		IF @intPRINTFlag = 1 PRINT @nvchSQLCommand
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT', 
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	Tz'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchTz1 = ''
	SET	@vchTz2 = ''	
	-------------------------------------------------------------------------------------------------------------------
	SELECT		@vchTz1 = ISNULL(Tz1, ''),
				@vchTz2 = ISNULL(Tz2, '')
		FROM	#MCFormulaLookUp
		WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchTz1) > 0 AND LEN(@vchTz2) > 0
	BEGIN
 		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	Tz = 	CASE	WHEN Cr <= 0.5 '
						+ 			'						THEN ' + @vchTz1 
						+			'						WHEN Cr > 0.5 '
						+			'						THEN ' + @vchTz2
						+			'						ELSE ' + @vchTz1
						+			'				END ' 
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
		----------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END		
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	Cpk'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchCpk = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@vchCpk = ISNULL(Cpk, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchCpk) > 0
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	Cpk = ' + @vchCpk
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
--						+			'	AND		TestStDev > 0 '
						+			'	AND		IsNonNormal	= 0'
		---------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	CalcCpk'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchCalcCpk = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@vchCalcCpk = ISNULL(CalcCpk, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchCalcCpk) > 0				
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	CalcCpk = ' + @vchCalcCpk
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
						+			'	AND		TestStDev > 0 '
						+			'	AND		IsNonNormal	= 0'
		----------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	InfinityFlagCr'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchInfinityFlagCr = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@vchInfinityFlagCr = ISNULL(InfinityFlagCr, '')
		FROM	#MCFormulaLookUp
		WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchInfinityFlagCr) > 0				
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	InfinityFlagCr = ' + @vchInfinityFlagCr
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
						+			'	AND		IsNonNormal	= 0'
		---------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	InfinityFlagTz'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchInfinityFlagTz1 = ''
	SET	@vchInfinityFlagTz2 = ''	
	-------------------------------------------------------------------------------------------------------------------
	SELECT		@vchInfinityFlagTz1 = ISNULL(InfinityFlagTz1, ''),
				@vchInfinityFlagTz2 = ISNULL(InfinityFlagTz2, '')
	FROM		#MCFormulaLookUp
	WHERE		MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchInfinityFlagTz1) > 0 AND LEN(@vchInfinityFlagTz2) > 0
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
								+			'	SET	InfinityFlagTz = 	CASE	WHEN Cr <= 0.5 '
								+ 			'									THEN ' + @vchInfinityFlagTz1 + ' '
								+			'									WHEN Cr > 0.5 '
								+			'									THEN ' + @vchInfinityFlagTz2 + ' '
								+			'									ELSE ' + @vchInfinityFlagTz1 + ' '
								+			'							END ' 
								+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
								+			'	WHERE	MCFormulaId = @PrmFormulaId'
		---------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	InfinityFlagCpk'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchInfinityFlagCpk = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@vchInfinityFlagCpk = ISNULL(InfinityFlagCpk, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchInfinityFlagCpk) > 0				
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	InfinityFlagCpk = ' + @vchInfinityFlagCpk
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
						+			'	AND		IsNonNormal	= 0'
		--------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'	-	Met Criteria Evaluation'
	IF @intPRINTFlag = 1	PRINT	'		.	Cr'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchMCCr = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT		@vchMCCr = ISNULL(MCCr, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchMCCr) > 0
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	MCCr = ' + @vchMCCr
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId' 
						+			'	AND		IsNonNormal	= 0'
		---------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	Tz'
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchMCTz = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT		@vchMCTz = ISNULL(MCTz, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchMCTz) > 0
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	MCTz = ' + @vchMCTz
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
		--------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END
	-------------------------------------------------------------------------------------------------------------------
	IF @intPRINTFlag = 1	PRINT	'		.	Cpk '
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchMCCpk = ''
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@vchMCCpk = ISNULL(MCCpk, '')
	FROM	#MCFormulaLookUp
	WHERE	MCFormulaId = @intFormulaId
	-------------------------------------------------------------------------------------------------------------------
	SELECT	@nvchSQLCommand = ''
	IF LEN(@vchMCCpk) > 0
	BEGIN
		SELECT	@nvchSQLCommand =	'UPDATE	cp '
						+			'	SET	MCCpk = ' + @vchMCCpk
						+			'	FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))'
						+			'	WHERE	MCFormulaId = @PrmFormulaId'
						+			'	AND		IsNonNormal	= 0'
		---------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
								N'@PrmFormulaId	INT',
								@intFormulaId
	END	
	-------------------------------------------------------------------------------------------------------------------
	--	Increment COUNTer
	-------------------------------------------------------------------------------------------------------------------
	SET @i = @i + 1
END


--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Met Criteria for normal data'
--=====================================================================================================================
--	c.	CALCULATE Met Criteria for Normal data
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET	cp.MetCritActual = 	CASE	WHEN	MCCr + MCTz + MCCpk = 3
								THEN	1
								ELSE	0
						END
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId > 0
 	AND		IsNonNormal = 0

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Met Criteria for Non-normal data'
--=====================================================================================================================
--	d.	CALCULATE Met Criteria for Non-Normal data
-----------------------------------------------------------------------------------------------------------------------
IF @intPRINTFlag = 1	PRINT	'	.	Met Criteria for Non-Normal Data'
-----------------------------------------------------------------------------------------------------------------------
-- Business rule: 
-- If Target IS NULL
--		Check CalcPPMPoolActual
--		IF	CalcPPMPoolActual <= 233 THEN MC = 1 ELSE MC = 0
-- If Target IS NOT NULL
--		Check Tz value 
--		If MCTz = 1 THEN Check CalcPPMPoolActual
--			IF	CalcPPMPoolActual <= 233 THEN MC = 1 ELSE MC = 0
--		If MCTz = 0 THEN MC = 0
-----------------------------------------------------------------------------------------------------------------------
-- MC for non-normal data with Target = Null
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		cp.MetCritActual = 	CASE	WHEN	CalcPPMPoolActual	<= 	233.00
									THEN	1.0
									ELSE	0.0
							END
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId 	> 	0
	AND		IsNonNormal		= 1
	AND		MCTarget		= 0
	AND		MCTargetRange	= 0
-----------------------------------------------------------------------------------------------------------------------
-- MC for non-normal data when Target IS NOT Null and MCTz = 1
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET	cp.MetCritActual = 	CASE	WHEN	CalcPPMPoolActual	<= 	233.00
								THEN	1.0
								ELSE	0.0
						END
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId > 	0
	AND		IsNonNormal		= 1
	AND		MCTz		=	1
	AND		MCTarget	= 	1
-----------------------------------------------------------------------------------------------------------------------
-- MC for non-normal data when Target IS NULL but Target Range is NOT NULL and MCTz = 1
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET	cp.MetCritActual = 	CASE	WHEN	CalcPPMPoolActual	<= 	233.00
								THEN	1.0
								ELSE	0.0
						END
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId 	> 	0
	AND		IsNonNormal		= 1
	AND		MCTz			=	1
	AND		MCTargetRange	= 	1
-----------------------------------------------------------------------------------------------------------------------
-- MC for non-normal data when Target IS NOT Null and MCTz = 0
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET	cp.MetCritActual = 	0.0
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId > 	0
	AND	IsNonNormal	= 1
	AND	MCTarget	=	1
	AND	MCTz		=	0
-----------------------------------------------------------------------------------------------------------------------
-- MC for non-normal data when Target IS Null Target Range IS NOT NULL and MCTz = 0
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET	cp.MetCritActual = 	0.0
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId 	> 	0
	AND		IsNonNormal		= 1
	AND		MCTargetRange	=	1
	AND 	MCTz			=	0
-----------------------------------------------------------------------------------------------------------------------
-- Met Criteria: delete MCCr, MCTz and MCCpk values where they do not apply
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		MCCr = Null
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId IN (2, 5, 6, 7, 8, 10, 11, 12, 13)
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		MCTz = Null
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId IN (6, 7, 8)
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		MCCpk = Null
FROM	#CalcPPM	cp	WITH (INDEX(CalcPPM_FormulaId_Idx))
WHERE	MCFormulaId IN (1, 3, 4, 5, 9, 13)
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Met Criteria COUNT by product group'
--=====================================================================================================================
--	e.	CALCULATE Met Criteria COUNT by product group
-----------------------------------------------------------------------------------------------------------------------
-- CalcPPM: RSInterimDetail - Calculate Met Crit COUNT
-- Note: this section used to return a met criteria COUNT by product
-- it was changed to return a met criteria COUNT by product group
-- FRio 2010-06-24 8:00:00PM Modified, added PUGDesc if not it could potentially fail.
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @tblMetCritVarDescByProdGroup (
			MajorGroupId,
			MinorGroupId,
			PUGDesc,
			ProductGrpId,
			VarDescRpt )
SELECT		cp.MajorGroupId,
			cp.MinorGroupId,
			pug.PUG_Desc,
			cp.ProductGrpId,
			cp.VarDescRpt
FROM		#CalcPPM				cp
JOIN		dbo.PU_Groups			pug		WITH(NOLOCK)	ON cp.PUGId = pug.PUG_Id
WHERE		cp.MetCritActual IS NOT NULL
GROUP BY	cp.MajorGroupId, cp.MinorGroupId, cp.ProductGrpId, cp.VarDescRpt, pug.PUG_Desc


-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @tblMetCritVarCountByProdGroup (
			MajorGroupId,
			MinorGroupId,
			PUGDesc,
			ProductGrpId,
			MetCritVarCountByProdGroup )
SELECT		MajorGroupId,
			MinorGroupId,
			PUGDesc,
			ProductGrpId,
			COUNT(VarDescRpt)
FROM		@tblMetCritVarDescByProdGroup
GROUP BY	MajorGroupId, MinorGroupId, ProductGrpId, PUGDesc

-----------------------------------------------------------------------------------------------------------------------
UPDATE		cp
SET		cp.MetCritVarCountByProdGroup = mc.MetCritVarCountByProdGroup
FROM	#CalcPPM 						cp
JOIN		dbo.PU_Groups				pug		WITH (NOLOCK)
												ON cp.PUGId = pug.PUG_Id
	JOIN	@tblMetCritVarCountByProdGroup	mc	ON	cp.MajorGroupId = mc.MajorGroupId
											AND	cp.MinorGroupId 	= mc.MinorGroupId
											AND	cp.ProductGrpId		= mc.ProductGrpId
											AND pug.PUG_Desc		= mc.PUGDesc
WHERE	cp.MetCritActual IS NOT NULL

--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Met Criteria contribution'
--=====================================================================================================================
-- Update the MajorGroupVolumeCount and MinorGroupVolumeCount
--=====================================================================================================================
IF	@intRptVolumeWeightOption = 0 -- Production COUNT
BEGIN
			UPDATE  #CalcPPM
					SET MajorGroupVolumeCount = ma.MajorGroupVolumeCount,
						MinorGroupVolumeCount = mi.MinorGroupVolumeCount
			FROM 	#CalcPPM		cp
			JOIN	#MajorGroupList	ma	ON	cp.MajorGroupId = ma.MajorGroupId
			JOIN	#MinorGroupList	mi	ON	cp.MinorGroupId = mi.MinorGroupId

END
ELSE
BEGIN
			---------------------------------------------------------------------------------------------------------------------------------------
			-- Bussiness Rule :
			-- When the report turns to Test Count weighting, the Volume should be calculated :
			-- MAX(Attributes count) + SUM(Variables count)						martin
			---------------------------------------------------------------------------------------------------------------------------------------
			-- SELECT 'Here .. '
			-- a. Use a temporary table to aggregate Attributes :
			INSERT INTO   @TempMajorGroupVolumeCount ( MajorGroupid, 
								PUGId, 
								PUGDesc,
								TempMajorGroupSampCountAttr)
			SELECT cp.MajorGroupId,cp.PUGId,pug.PUG_Desc + '(Att)',MAX(ISNULL(VolumeCount,0))
			FROM   #CalcPPM 		cp
			JOIN   dbo.PU_Groups    pug		WITH (NOLOCK)
											ON	cp.PUGId = pug.PUG_Id
			WHERE  cp.IsAtt = 1
			GROUP  BY cp.MajorGroupId,cp.PUGId,pug.PUG_Desc
			--
			INSERT INTO   @TempMinorGroupVolumeCount ( MajorGroupid,
								MinorGroupid, 
								PUGId, 
								PUGDesc,
								TempMajorGroupSampCountAttr)
			SELECT cp.MajorGroupId,cp.MinorGroupId,cp.PUGId,pug.PUG_Desc + '(Att)',MAX(ISNULL(VolumeCount,0))
			FROM   #CalcPPM 		cp
			JOIN   dbo.PU_Groups    pug		WITH (NOLOCK)
											ON	cp.PUGId = pug.PUG_Id
			WHERE  cp.IsAtt = 1
			GROUP  BY cp.MajorGroupId,cp.MinorGroupId,cp.PUGId,pug.PUG_Desc

			-- b. Use a temporary table to aggregate Variables :
			INSERT INTO   @TempMajorGroupVolumeCount ( MajorGroupid, 
								PUGId, 
								PUGDesc,
								TempMajorGroupSampCountVar)			
			SELECT cp.MajorGroupId,cp.PUGId,pug.PUG_Desc + ' (#)',MAX(ISNULL(VolumeCount,0))
			FROM   #CalcPPM 		cp
			JOIN   dbo.PU_Groups    pug		WITH (NOLOCK)
											ON	cp.PUGId = pug.PUG_Id
			WHERE  cp.IsAtt = 0
			GROUP  BY cp.MajorGroupId,cp.PUGId,pug.PUG_Desc		
	--
			INSERT INTO   @TempMinorGroupVolumeCount ( MajorGroupid, 
								MinorGroupId,
								PUGId, 
								PUGDesc,
								TempMajorGroupSampCountVar)			
			SELECT cp.MajorGroupId,cp.MinorGroupId,cp.PUGId,pug.PUG_Desc + ' (#)',MAX	(ISNULL(VolumeCount,0))
			FROM   #CalcPPM 		cp
			JOIN   dbo.PU_Groups    pug		WITH (NOLOCK)
											ON	cp.PUGId = pug.PUG_Id
			WHERE  cp.IsAtt = 0
			GROUP  BY cp.MajorGroupId,cp.MinorGroupId,cp.PUGId,pug.PUG_Desc

			

-- Sunday
-- select '@TempMinorGroupVolumeCount',* from @TempMinorGroupVolumeCount order by MajorGroupid,MinorGroupId
-- select '@TempMajorGroupVolumeCount',* from @TempMajorGroupVolumeCount order by MajorGroupid

			-- c. Do the math to calculate the Volume Count :
			UPDATE  #CalcPPM
					SET MajorGroupVolumeCount = (SELECT MAX(ISNULL(TempMajorGroupSampCountAttr,0)) + MAX(ISNULL(TempMajorGroupSampCountVar,0))
												 FROM   @TempMajorGroupVolumeCount
												 WHERE  MajorGroupId = cp.MajorGroupId),
						MinorGroupVolumeCount = (SELECT MAX(ISNULL(TempMajorGroupSampCountAttr,0)) + MAX(ISNULL(TempMajorGroupSampCountVar,0))
												 FROM   @TempMinorGroupVolumeCount
												 WHERE  MajorGroupId = cp.MajorGroupId
												 AND    MinorGroupId = cp.MinorGroupId)-- cp.VolumeCount
			FROM 	#CalcPPM		cp
			JOIN	#MajorGroupList	ma	ON	cp.MajorGroupId = ma.MajorGroupId


			-- d. Make the MajorGroupVolumeCount = new math
			UPDATE  #MajorGroupList
					SET MajorGroupVolumeCount = (SELECT MAX(ISNULL(TempMajorGroupSampCountAttr,0)) + MAX(ISNULL(TempMajorGroupSampCountVar,0))
												 FROM   @TempMajorGroupVolumeCount
												 WHERE  MajorGroupId = ma.MajorGroupId)
			FROM 	#MajorGroupList	ma	

			-- e. As minor group now is the single Test Count of the slices, and several rows could not be added
			-- because would cause the report to fail, then make it = the MajorGroupVolumeCount
			UPDATE  #MinorGroupList
					SET MinorGroupVolumeCount  = (SELECT MAX(ISNULL(TempMajorGroupSampCountAttr,0)) + MAX(ISNULL(TempMajorGroupSampCountVar,0))
													 FROM   @TempMinorGroupVolumeCount
													 WHERE  MajorGroupId = mi.MajorGroupId
															AND MinorGroupId = mi.MinorGroupId)
			FROM 	#MinorGroupList	mi
			-- JOIN    #MajorGroupList	ma  ON	mi.MajorGroupId = ma.MajorGroupId			

END

--=====================================================================================================================
--	f.	CALCULATE Met Criteria contribution
--  Get rid of the JOIN to MinorGrouping
-----------------------------------------------------------------------------------------------------------------------
UPDATE	cp
SET		cp.MetCritContribution	= (cp.MetCritActual * cp.VolumeCount * 1.0) / (cp.MinorGroupVolumeCount * 1.0)/ (cp.MetCritVarCountByProdGroup * 1.0)
FROM	#CalcPPM		cp
WHERE	
	cp.MinorGroupVolumeCount > 0.0 
	AND 	cp.MetCritVarCountByProdGroup > 0.0
	AND		cp.MetCritActual IS NOT NULL

--=====================================================================================================================
--	a.	CALCULATE PPM contribution
--  
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 0 -- Production COUNT
BEGIN
	UPDATE	cp
	SET		cp.CalcPPMAoolContribution	=	CASE	WHEN	cp.MinorGroupVolumeCount > 0.0 -- mi.MinorGroupVolumeCount > 0.0 		
													THEN	(cp.VolumeCount * cp.CalcPPMAoolActual) / (cp.MinorGroupVolumeCount * 1.0) -- (mi.MinorGroupVolumeCount * 1.0)
		 											ELSE	0.0
													END, 
			cp.CalcPPMPoolContribution	=	CASE	WHEN	cp.MinorGroupVolumeCount > 0.0  -- mi.MinorGroupVolumeCount > 0.0 		
													THEN	(cp.VolumeCount * cp.CalcPPMPoolActual) / (cp.MinorGroupVolumeCount * 1.0) -- (mi.MinorGroupVolumeCount * 1.0)
		 											ELSE	0.0
													END
	FROM	#CalcPPM		cp

END
ELSE
BEGIN
	UPDATE	cp
	SET		cp.CalcPPMAoolContribution	=	cp.CalcPPMAoolActual	, 
			cp.CalcPPMPoolContribution	=	cp.CalcPPMPoolActual
	FROM	#CalcPPM		cp
END

--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UCI PPM'
--=====================================================================================================================

-- Check if DQI data base exists
/* martin
IF DB_ID('DQI') IS NOT NULL
BEGIN
	-----------------------------------------------------------------------------------------------------------------------
	-- Calculated UCI PPM for Variables :
	-----------------------------------------------------------------------------------------------------------------------
	UPDATE 	#CalcPPM
			SET 
						CPL = (TestAvg - LSL) / (3 * TestStDev)	,
						CPU = (USL - TestAvg) / (3 * TestStDev) 
	WHERE	TestCount > 0
	AND		TestStDev > 0
	-- 
	UPDATE 	#CalcPPM
			SET CalcUCIPPM = CONVERT(FLOAT,1000000 * (ISNULL([DQI].dbo.fnLocal_PG_KLookUp(TestCount, 3.00 * CPL),0) + ISNULL([DQI].dbo.fnLocal_PG_KLookUp(TestCount,3.00 * CPU),0)))
	WHERE	TestCount > 0
	AND		TestStDev > 0

	-- SELECT '#CalcPPM',CalcUCIPPM,TestCount,TestStDev,* FROM #CalcPPM WHERE VarGroupId = 215 ORDER BY ProdId
	-----------------------------------------------------------------------------------------------------------------------
	-- Observed UCI PPM for Attributes :
	-----------------------------------------------------------------------------------------------------------------------
	UPDATE	#CalcPPM
		SET		ObsUCIPPM = 1000000*(1/(1+((TestCount - TestFail)/((TestFail+1) * [DQI].dbo.fnLocal_PG_ObsUCIPPM(TestFail, TestCount)))))
	WHERE (LSL IS NOT NULL
		  OR USL IS NOT NULL)
	AND   IsAtt = 0

	UPDATE	#CalcPPM
		SET		ObsUCIPPM = 1000000*(1/(1+((TestCount - TestFail)/((TestFail+1) * [DQI].dbo.fnLocal_PG_ObsUCIPPM(TestFail, TestCount)))))
	WHERE IsAtt = 1
END
*/
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VIRTUAL ZERO'
--=====================================================================================================================
-- Set passes virtual zero for Variables:
UPDATE	#CalcPPM
	SET		PassesVirtualZero = 1
WHERE	IsAtt = 0
AND	   ((TestCount >= 20 AND (Cpk IS NULL OR Cpk >= 1.62) AND Cr <= 0.61 AND (Tz >= -0.25 AND Tz <= 0.25)) OR
			(TestCount >= 20 AND (Cpk IS NULL OR Cpk >= 1.62) AND Cr <= 0.59 AND (Tz >= -0.25 AND Tz <= 0.25)) OR
			(TestCount >= 30 AND (Cpk IS NULL OR Cpk >= 1.51) AND Cr <= 0.65 AND (Tz >= -0.25 AND Tz <= 0.25)) OR
			(TestCount >= 30 AND (Cpk IS NULL OR Cpk >= 1.51) AND Cr <= 0.63 AND (Tz >= -0.25 AND Tz <= 0.25)) OR
			(TestCount >= 100 AND (Cpk IS NULL OR Cpk >= 1.33) AND Cr <= 0.74 AND (Tz >= -0.25 AND Tz <= 0.25)) OR
			(TestCount >= 100 AND (Cpk IS NULL OR Cpk >= 1.33) AND Cr <= 0.70 AND (Tz >= -0.25 AND Tz <= 0.25)))
AND		CalcUCIPPM IS NULL

UPDATE	#CalcPPM
	SET		PassesVirtualZero = 1
WHERE	IsAtt = 0
AND		CalcUCIPPM <= 500

UPDATE	#CalcPPM
	SET		PassesVirtualZero = 0
WHERE   IsAtt = 0
AND     (TestCount = 1 OR TestCount = 2 OR (TestCount > 2 AND TestCount < 20))


UPDATE	#CalcPPM
	SET		PassesVirtualZero = 0
WHERE   IsAtt = 0
AND     (TestCount = TestFail)

-- Set passes virtual zero for Attributes:
UPDATE	#CalcPPM
	SET		PassesVirtualZero = 1
WHERE	IsAtt = 1
AND		TestCount >= 6000
AND		ObsUCIPPM <= 500

--=====================================================================================================================
-- Calculate the Contributions
-----------------------------------------------------------------------------------------------------------------------
IF	@intRptVolumeWeightOption = 0 -- Production COUNT
BEGIN
		IF @intEnableVirtualZero = 1 
		BEGIN
				UPDATE	cp
					SET		cp.CalcUCIPPMContribution	=	CASE	WHEN	cp.MinorGroupVolumeCount > 0.0 		
																	THEN	(cp.VolumeCount * cp.CalcUCIPPM * 1.0) / (cp.MinorGroupVolumeCount * 1.0) 
		 															ELSE	0.0
																	END, 
							cp.ObsUCIPPMContribution	=	CASE	WHEN	cp.MinorGroupVolumeCount > 0.0  		
																	THEN	(cp.VolumeCount * cp.ObsUCIPPM * 1.0) / (cp.MinorGroupVolumeCount * 1.0) 
		 															ELSE	0.0
																	END,
							cp.PassesVzContribution		=	CASE	WHEN	cp.MinorGroupVolumeCount > 0.0  		
																	THEN	(cp.VolumeCount * cp.PassesVirtualZero) / (cp.MinorGroupVolumeCount * 1.0) 
		 															ELSE	0.0
																	END
					FROM	#CalcPPM		cp
		END
END
ELSE
BEGIN
	IF @intEnableVirtualZero = 1
	BEGIN
			UPDATE	cp
			SET		cp.CalcUCIPPMContribution	=	cp.CalcUCIPPM	, 
					cp.ObsUCIPPMContribution	=	cp.ObsUCIPPM	,
					cp.PassesVzContribution		=   cp.PassesVirtualZero 
			FROM	#CalcPPM		cp
	END
END
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Q FACTOR ---- TO COME'
--=====================================================================================================================
--	NOT STARTED YET
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	PRINT ' NormPPMReport'
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
--=====================================================================================================================
--	END OF COMMON CODE
--=====================================================================================================================
IF	@p_vchRptLayoutOption = 'NormPPM'
BEGIN
	--=================================================================================================================
	IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
	IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
	IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
	IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
	IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PREPARE NORMPPM INTERIM RESULT SETS'
	--=================================================================================================================
	--	PREPARE NORMPPM SUMMARY AND DETAIL RESULT SETS 
	--	b.	CALCULATE Aool and Pool PPM values for Detail Section
	--	c.	UPDATE PUGDesc for PUG's that can be both numeric and non-numeric
	--	d.	CALCULATE PPM Volume Weighted Values
	--	e.	CALCULATE Major Group Totals
	--	f.	CALCULATE the SUM of PPM for the SUMary Section
	--	g.	CALCULATE Total Met Crit PPass Avg
	--	h.	CALCULATE Volume Weighted PPM
	--	i.	CALCULATE Total PPM accross lines
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Aool and Pool PPM values for Detail Section'
	--=================================================================================================================
	--	b.	CALCULATE Aool and Pool PPM values for SUMmary Section
	--		The SUMmary section of the PPM report shows the PPM values grouped by production group
	--		Business Rule:
	--		If a production group only has attributes we show only Aool PPM
	--		If a production group has both numeric and attributes then we show an Aool PPM and a Pool PPM 
	--		If a production group has both Aool and Pool values only the Aool values for the numeric variables are
	--		NOT include in the Total PPM
	-------------------------------------------------------------------------------------------------------------------
	--	INITIALIZE variables
	-------------------------------------------------------------------------------------------------------------------
	SET	@nvchSQLCommand  = ''
	SET	@nvchSQLCommand1 = ''
	SET	@nvchSQLCommand2 = ''
	SET	@nvchSQLCommand3 = ''
	SET	@i = 1
	-------------------------------------------------------------------------------------------------------------------
	--	LOOP through data and calculate a value for Aool and Pool PPM
	-------------------------------------------------------------------------------------------------------------------
	WHILE	@i <= 2
	BEGIN
		----------------------------------------------------------------------------------------------------------------
		--	SELECT	Prefix for PUG DESC
		----------------------------------------------------------------------------------------------------------------
		SELECT	@vchTempString = 	CASE	WHEN	@i = 1
											THEN	'Aool '
											WHEN	@i = 2
											THEN	'Pool '
											END
		----------------------------------------------------------------------------------------------------------------
		--	Numeric variables have both Aool and Pool, for these variables only Pool portion is included in the 
		--	SUM for Total PPM
		----------------------------------------------------------------------------------------------------------------
		SELECT	@vchIncludeField =	CASE	WHEN	@i = 1
											THEN	'IncludeAool'
											WHEN	@i = 2
											THEN	'IncludePool'
											END
		----------------------------------------------------------------------------------------------------------------
		--	 Assemble INSERT statement
		----------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand =	'INSERT INTO	#NormPPMRptFinalResultSetDetailInterim ( '
							+		'					MajorGroupId, 	'
							+		'					MinorGroupId, 	'
							+		'					SpecVersion, 	'
							+		'					PUGDesc, 		'
							+		'					IncludeInSUM, 	'
							+		'					VarDesc, 		'
							+		'					CalcPPM, 		'
							+		'					CalcUCIPPM, 		'
							+		'					MinorGroupVolumeCount	, '
							+		'					MajorGroupVolumeCount	, '
							+		'					MetCrit, '
							+		'					MetCritContribution, '
							+		'					VarVolumeCount)'
		----------------------------------------------------------------------------------------------------------------
		--	ASSEMBLE SELECT statement
		----------------------------------------------------------------------------------------------------------------
		SET	@nvchSQLCommand1 = 		'		SELECT 	cp.MajorGroupId, '
							+		'				cp.MinorGroupId, '
		----------------------------------------------------------------------------------------------------------------

		IF	@intRptWeightSpecChanges = 1
		BEGIN 
			SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'Null, '
		END
		ELSE
		BEGIN 
			SET	@nvchSQLCommand1 = @nvchSQLCommand1 + 'cp.SpecVersion, '
		END
		
		----------------------------------------------------------------------------------------------------------------
		--	SQL statement is option is Aool
		----------------------------------------------------------------------------------------------------------------
		IF	@vchTempString = 'Aool'
		BEGIN
			SELECT	@nvchSQLCommand2 = 	
										'''' + @vchTempString + ''' + pg.PUG_Desc, '
								+		'cp.' + @vchIncludeField + ', '
								+		'cp.VarDescRpt, '
								+		'SUM(cp.CalcPPMAoolContribution), '
								+		'SUM(cp.ObsUCIPPMContribution)	,'
								+		'mi.MinorGroupVolumeCount	, '
								+		'ma.MajorGroupVolumeCount	, '
								+		'(CASE WHEN ' + CONVERT(VARCHAR,@intEnableVirtualZero) + ' = 1 THEN SUM(cp.PassesVirtualZero) ELSE NULL END) , '
								+		'(CASE WHEN ' + CONVERT(VARCHAR,@intEnableVirtualZero) + ' = 1 THEN SUM(cp.PassesVirtualZero) ELSE NULL END), '
								+		'SUM(cp.VolumeCount)   '
								+		'		FROM	#CalcPPM		cp '
								+		'		JOIN	dbo.PU_Groups	pg	WITH (NOLOCK) ON 	cp.PUGId = pg.PUG_Id '
								+		'		JOIN	#MinorGroupList	mi	ON 	mi.MinorGroupId = cp.MinorGroupId '
								+		'		JOIN	#MajorGroupList	ma	ON 	ma.MajorGroupId = cp.MajorGroupId '
		END
		ELSE
		----------------------------------------------------------------------------------------------------------------
		--	SQL statement is option is Pool
		----------------------------------------------------------------------------------------------------------------
		BEGIN
			SELECT	@nvchSQLCommand2 = 	
										'''' + @vchTempString + ''' + pg.PUG_Desc, '
								+		'cp.' + @vchIncludeField + ', '
								+		'cp.VarDescRpt, '
								+		'SUM(cp.CalcPPMPoolContribution), '
								+		'SUM(cp.CalcUCIPPM) , '
								+		'mi.MinorGroupVolumeCount	, '
								+		'ma.MajorGroupVolumeCount	, '
			------------------------------------------------------------------------------------------------------------
			IF @intEnableVirtualZero = 1 
			BEGIN
					SELECT	@nvchSQLCommand2 =	@nvchSQLCommand2 + ' '
										+		'(CASE	WHEN	SUM(cp.VolumeCount) <> 0.0 '
										+		'		THEN 	SUM(cp.VolumeCount * CONVERT(FLOAT, cp.PassesVirtualZero)) / SUM(cp.VolumeCount * 1.0) '
										+		'		ELSE	0.0 '
										+		'		END), '
			END
			ELSE
			BEGIN
					SELECT	@nvchSQLCommand2 =	@nvchSQLCommand2 + ' '
										+		'(CASE	WHEN	SUM(cp.VolumeCount) <> 0.0 '
										+		'		THEN    SUM(cp.VolumeCount * CONVERT(FLOAT, cp.MetCritActual)) / SUM(cp.VolumeCount * 1.0) '
										+		'		ELSE	0.0 '
										+		'		END), '
			END
			------------------------------------------------------------------------------------------------------------
			SELECT	@nvchSQLCommand2 =	@nvchSQLCommand2 + ' '
								+		'(CASE WHEN ' + CONVERT(VARCHAR,@intEnableVirtualZero) + ' = 1 THEN SUM(cp.PassesVirtualZero) ELSE SUM(cp.MetCritContribution) END), '
								+		'SUM(cp.VolumeCount) '
								+		'		FROM	#CalcPPM			cp '
								+		'		JOIN	dbo.PU_Groups		pg	WITH (NOLOCK) ON 	cp.PUGId = pg.PUG_Id '
								+		'		JOIN	#MinorGroupList	mi	ON 	mi.MinorGroupId = cp.MinorGroupId'
								+		'		JOIN	#MajorGroupList	ma	ON 	ma.MajorGroupId = cp.MajorGroupId '
		END		
		----------------------------------------------------------------------------------------------------------------
		-- Note: the order of the group by matters this is why the @RptMajorGroupBy 
		-- parameter is analyzed first and the @RptMinorGroupBy parameter second
		----------------------------------------------------------------------------------------------------------------
		SET	@nvchSQLCommand3 = ' GROUP BY cp.MajorGroupId, cp.MinorGroupId, '
		----------------------------------------------------------------------------------------------------------------
		IF	@intRptWeightSpecChanges = 1
		BEGIN
			SET	@nvchSQLCommand3 = @nvchSQLCommand3 + ' mi.MinorGroupVolumeCount, ma.MajorGroupVolumeCount, pg.PUG_Desc, cp.VarDescRpt, cp.' + @vchIncludeField
		END
		ELSE
		BEGIN
			SET	@nvchSQLCommand3 = @nvchSQLCommand3 + ' mi.MinorGroupVolumeCount, ma.MajorGroupVolumeCount, cp.SpecVersion, pg.PUG_Desc, cp.VarDescRpt, cp.' + @vchIncludeField
		END
		----------------------------------------------------------------------------------------------------------------
		--	ASSEMBLE the final SQL statement
		----------------------------------------------------------------------------------------------------------------
		SELECT	@nvchSQLCommand = CASE	WHEN 	@i = 1 
										THEN	@nvchSQLCommand + @nvchSQLCommand1 + @nvchSQLCommand2 +  @nvchSQLCommand3
										WHEN	@i = 2
										THEN	@nvchSQLCommand + @nvchSQLCommand1 + @nvchSQLCommand2 + ' WHERE CalcPPMPoolActual IS NOT NULL ' + @nvchSQLCommand3
										END
		----------------------------------------------------------------------------------------------------------------
		--	PRINT the final SQL statement debug only
		----------------------------------------------------------------------------------------------------------------
		PRINT '(' + CONVERT(VARCHAR(25), @i) + ') ' + @nvchSQLCommand 
		----------------------------------------------------------------------------------------------------------------
		--	EXECUTE the final SQL statement
		----------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@nvchSQLCommand
		----------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTer
		----------------------------------------------------------------------------------------------------------------
		SET	@i = @i + 1
	END			

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Aool and Pool PPM values for Detail Section'
	--=================================================================================================================
	--	c.	Update PUGDesc for PUG's that can be both numeric and non-numeric
	--		A request was made by P&G to flag which portion of the Aool was numeric and which was attribute 
	--		so we added a (#) for numeric and (Att) for attribute
	-------------------------------------------------------------------------------------------------------------------
	--	Flag Numeric Aool
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	frsdi
	SET		PUGDesc = PUGDesc + ' (#)'
	FROM	#NormPPMRptFinalResultSetDetailInterim	frsdi
	WHERE	IncludeInSUM = 0	
		AND	PUGDesc LIKE 'Aool%'
	-------------------------------------------------------------------------------------------------------------------
	--	Flag Attribute Aool	
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	frsdi
	SET		PUGDesc = PUGDesc + ' (Att)'
	FROM	#NormPPMRptFinalResultSetDetailInterim	frsdi
	WHERE	IncludeInSUM = 1
		AND	PUGDesc LIKE 'Aool%'	
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE PPM Weighted Total'
	--=================================================================================================================
	--	d.	CALCULATE PPM Weighted Total accross lines
	-------------------------------------------------------------------------------------------------------------------
	IF @intEnableVirtualZero = 0 
	BEGIN
			UPDATE	fr
			SET		CalcPPMWeighted =	CASE	WHEN	fr.MajorGroupVolumeCount > 0.0 -- ma.MajorGroupVolumeCount > 0.0
												THEN	(fr.CalcPPM * fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount * 1.0) -- (ma.MajorGroupVolumeCount * 1.0)
												ELSE	0.0
												END  
			FROM	#NormPPMRptFinalResultSetDetailInterim 	fr
			JOIN	#MajorGroupList				ma	ON ma.MajorGroupId = fr.MajorGroupId
	END
	ELSE
	BEGIN
			UPDATE	fr
			SET		CalcPPMWeighted =	CASE	WHEN	fr.MajorGroupVolumeCount > 0.0 -- ma.MajorGroupVolumeCount > 0.0
												THEN	(fr.CalcUCIPPM * fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount * 1.0) -- (ma.MajorGroupVolumeCount * 1.0)
												ELSE	0.0
												END  
			FROM	#NormPPMRptFinalResultSetDetailInterim 	fr
			JOIN	#MajorGroupList				ma	ON ma.MajorGroupId = fr.MajorGroupId
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Major Group Totals'
	--=================================================================================================================
	--	e.	CALCULATE Major Group Totals
	-- 		Note: this section used to return a met criteria COUNT by product
	-- 		it was changed to return a met criteria COUNT by product group
	-- 		RP SlimSoft 20041205
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	#NormPPMRptFinalResultSetDetailInterim (
				MajorGroupId,
				PLId,
				PUGDesc,
				VarDesc,
				SpecVersion,
				CalcPPM,
				MetCrit,
				IncludeInSUM )
	SELECT	fr.MajorGroupId,
			-1,
			fr.PUGDesc,
			fr.VarDesc,
			fr.SpecVersion,
			SUM(fr.CalcPPMWeighted),
			(CASE WHEN @intRptVolumeWeightOption = 0 THEN
				 SUM(((fr.VarVolumeCount * 1.0) * (fr.MetCrit * 1.0) / (fr.MinorGroupVolumeCount * 1.0)) * ((fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount)))
				 ELSE AVG(fr.MetCrit)
			END),   -- (#IM00027249)
			IncludeInSUM
	FROM	#NormPPMRptFinalResultSetDetailInterim 	fr
	WHERE	fr.MinorGroupVolumeCount > 0
	GROUP BY	fr.MajorGroupId, fr.PUGDesc, fr.VarDesc, fr.SpecVersion, IncludeInSUM	

	-- SELECT '#NormPPMRptFinalResultSetDetailInterim',* FROM #NormPPMRptFinalResultSetDetailInterim
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE the SUM of PPM for the SUMmary Section'
	--=================================================================================================================
	--	f.	CALCULATE the SUM of PPM for the SUMary Section
	--	20090406 SUM(MinorGroupVolumeCount)
	-------------------------------------------------------------------------------------------------------------------	
	-- SELECT '#NormPPMRptFinalResultSetDetailInterim >>',* FROM #NormPPMRptFinalResultSetDetailInterim WHERE MajorGroupId = 2 AND MinorGroupId = 6

	INSERT INTO	#FinalResultSetSUMmaryInterim ( 
				MajorGroupId,
				MinorGroupId,
				PUGDesc, 
				IncludeInSUM, 
				CalcPPM		,
				CalcUCIPPM
				)
	SELECT	MajorGroupId,
			MinorGroupId,
			PUGDesc,
			IncludeInSUM, 
			SUM(CalcPPM) ,
			SUM(CalcUCIPPM)
	FROM	#NormPPMRptFinalResultSetDetailInterim 
	WHERE	PLId IS NULL	
	GROUP BY	MajorGroupId, MinorGroupId, 
				PUGDesc, IncludeInSUM	

	-- 
	UPDATE #FinalResultSetSUMmaryInterim 
			SET MajorGroupVolumeCount = magl.MajorGroupVolumeCount
	FROM   #FinalResultSetSUMmaryInterim rsi
	JOIN   #MajorGroupList				 magl	ON  rsi.MajorGroupId = magl.MajorGroupId

	UPDATE #FinalResultSetSUMmaryInterim 
			SET MinorGroupVolumeCount = migl.MinorGroupVolumeCount
	FROM   #FinalResultSetSUMmaryInterim rsi
	JOIN   #MinorGroupList				 migl	ON  rsi.MajorGroupId = migl.MajorGroupId
												AND rsi.MinorGroupId = migl.MinorGroupId
    --=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Total Met Crit PPass Avg -- TODO AFTER MET CRITERIA LOGIC IS ADDED'
	--=================================================================================================================
	--	g.	CALCULATE Total Met Crit PPass Avg	
	--		First calculate the MetCrit Contribution using a weighted volume
	-------------------------------------------------------------------------------------------------------------------
	IF @intEnableVirtualZero = 1 
	BEGIN
		
		UPDATE		cp
			SET		cp.PassesVzContribution	=	 (cp.PassesVirtualZero * cp.VolumeCount * 1.0) / (cp.MinorGroupVolumeCount * 1.0)/ (cp.MetCritVarCountByProdGroup * 1.0)												
  		FROM	#CalcPPM		cp
		WHERE 	cp.MinorGroupVolumeCount 		> 0.0  
			AND 	cp.MetCritVarCountByProdGroup 	> 0.0
			AND		cp.PassesVirtualZero IS NOT NULL	

	END
	ELSE
	BEGIN

		UPDATE		cp
			SET		cp.MetCritContribution	=	(cp.MetCritActual * cp.VolumeCount * 1.0) / (cp.MinorGroupVolumeCount * 1.0)/ (cp.MetCritVarCountByProdGroup * 1.0)								
  		FROM	#CalcPPM		cp
		WHERE 	cp.MinorGroupVolumeCount 		> 0.0  
			AND 	cp.MetCritVarCountByProdGroup 	> 0.0
			AND		cp.MetCritActual IS NOT NULL	
	END
	-------------------------------------------------------------------------------------------------------------------
	--	The PPass is the SUM of the MetContribution 
	-------------------------------------------------------------------------------------------------------------------
	IF @intEnableVirtualZero = 0 
	BEGIN
		IF @intRptVolumeWeightOption = 0 
		BEGIN
		INSERT INTO	@tblMetCritPPassAvg (
	 					MajorGroupId,
	 					MinorGroupId,
	 					PUGDesc,
	 					MetCritPPass )
 			SELECT	cp.MajorGroupId,
 					cp.MinorGroupId,
 					'Pool ' + pg.PUG_Desc,
					SUM(cp.MetCritContribution)
			FROM	#CalcPPM		cp
				JOIN	#MinorGroupList	mi 	ON 	cp.MajorGroupId = mi.MajorGroupId
												AND	cp.MinorGroupId = mi.MinorGroupId
				JOIN	dbo.PU_Groups 	pg 	WITH (NOLOCK)
									ON 	cp.PUGId = pg.PUG_Id
			WHERE	cp.MetCritActual IS NOT NULL
 			GROUP BY	cp.MajorGroupId, cp.MinorGroupId, pg.PUG_Desc
		END
		ELSE
		BEGIN

			--=================================================================================================================================
			-- VMC Calc Change: FRio/PGalanzini (Ver 5.0)
			-- Now it is going to be the AVG vs the weigted volume if the report turns to Sample Count
			--=================================================================================================================================
			/*
			INSERT INTO	@tblMetCritPPassAvg (
	 					MajorGroupId,
	 					MinorGroupId,
	 					PUGDesc,
	 					MetCritPPass )
 			SELECT	
					cp.MajorGroupId,
 					cp.MinorGroupId,
 					'Pool ' + pg.PUG_Desc,
					SUM(cp.MetCritActual * cp.VolumeCount / cp.MajorGroupVolumeCount) / COUNT(DISTINCT cp.VarDescRpt) 
			FROM	#CalcPPM		cp
				JOIN	#MinorGroupList	mi 	ON 	cp.MajorGroupId = mi.MajorGroupId
											AND	cp.MinorGroupId = mi.MinorGroupId
				JOIN	dbo.PU_Groups	pg 	WITH (NOLOCK) ON cp.PUGId = pg.PUG_Id
				WHERE	cp.MetCritActual IS NOT NULL
				GROUP BY	cp.MajorGroupId, cp.MinorGroupId, pg.PUG_Desc
			*/
			-- 2019-04-19 FO-03934
			INSERT INTO	@tblMetCritPPassAvg (
	 						MajorGroupId,
	 						MinorGroupId,
	 						PUGDesc,
	 						MetCritPPass )
 				SELECT	
						cp.MajorGroupId,
 						cp.MinorGroupId,
 						'Pool ' + pg.PUG_Desc,
						AVG(CONVERT(FLOAT,cp.MetCritActual))	-- AVG(cp.MetCritContribution)
				FROM	#CalcPPM		cp
					JOIN	#MinorGroupList	mi 	ON 	cp.MajorGroupId = mi.MajorGroupId
													AND	cp.MinorGroupId = mi.MinorGroupId
					JOIN	dbo.PU_Groups 	pg 	WITH (NOLOCK)
										ON 	cp.PUGId = pg.PUG_Id
				WHERE	cp.MetCritActual IS NOT NULL
 				GROUP BY	cp.MajorGroupId, cp.MinorGroupId, pg.PUG_Desc

				--SELECT '@tblMetCritPPassAvg >>>',*, MetCritPPass AS 'MetCritPPass (VMC)'
				--	FROM @tblMetCritPPassAvg


		END
	END
	ELSE
	BEGIN

		  IF @intRptVolumeWeightOption = 0 
		  BEGIN
			INSERT INTO	@tblMetCritPPassAvg (
	 					MajorGroupId,
	 					MinorGroupId,
	 					PUGDesc,
	 					MetCritPPass )
			SELECT	MajorGroupId,
					MinorGroupId,
					PUGDesc,
					SUM(MetCrit)/COUNT(MetCrit)
			FROM	#NormPPMRptFinalResultSetDetailInterim 
			WHERE PLId IS NULL
			AND IncludeInSum = 1
			GROUP BY MajorGroupId,
					MinorGroupId,
					PUGDesc
		  END
		  ELSE
		  BEGIN
			INSERT INTO	@tblMetCritPPassAvg (
	 					MajorGroupId,
	 					MinorGroupId,
	 					PUGDesc,
	 					MetCritPPass )
			SELECT  
					MajorGroupId,
					MinorGroupId,
					PUGDesc,
					AVG(CONVERT(FLOAT,MetCrit))
			FROM	#NormPPMRptFinalResultSetDetailInterim 
			WHERE PLId IS NULL
			AND IncludeInSum = 1
			AND MetCrit IS NOT NULL
			GROUP BY MajorGroupId,
					MinorGroupId,
					PUGDesc
		  END
	END


	-------------------------------------------------------------------------------------------------------------------
	--	Update value in #FinalResultSetSUMmaryInterim
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	fd 
		SET	fd.MetCritPPass = mc.MetCritPPass
	FROM	#FinalResultSetSUMmaryInterim 	fd
		JOIN	@tblMetCritPPassAvg			mc	ON	fd.MajorGroupId 	= mc.MajorGroupId
													AND	fd.MinorGroupId = mc.MinorGroupId
													AND	fd.PUGDesc 		= mc.PUGDesc
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Volume Weighted PPM'
	--=================================================================================================================
	--	h.	CALCULATE Volume Weighted PPM
	-------------------------------------------------------------------------------------------------------------------
	UPDATE	fr
	SET	CalcPPMWeighted	=	(fr.CalcPPM * fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount * 1.0), 
		CalcUCIPPMWeighted	=	(fr.CalcUCIPPM * fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount * 1.0) 
	FROM	#FinalResultSetSUMmaryInterim	fr
		JOIN	#MajorGroupList ma	ON ma.MajorGroupId = fr.MajorGroupId
	WHERE	ma.MajorGroupVolumeCount > 0

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' CALCULATE Total PPM accross lines'
	--=================================================================================================================
	--	i.	CALCULATE Total PPM accross lines
	-------------------------------------------------------------------------------------------------------------------	
	IF @intRptVolumeWeightOption = 0
	BEGIN
			INSERT INTO	#FinalResultSetSUMmaryInterim (
						MajorGroupId,
						PLId,
						PUGDesc,
						CalcPPM,
						CalcUCIPPM,
						MetCritPPass )
			SELECT	fr.MajorGroupId,
					-1,
					fr.PUGDesc,
					SUM(CalcPPMWeighted),
					SUM(CalcUCIPPMWeighted),
 					CASE	WHEN	SUM(fr.MajorGroupVolumeCount) > 0
 							THEN	SUM((fr.MetCritPPass * fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount * 1.0)) -- (ma.MajorGroupVolumeCount * 1.0))
 							END as MetCritPPass
			FROM	#FinalResultSetSUMmaryInterim	fr
			JOIN	#MajorGroupList	ma	ON ma.MajorGroupId = fr.MajorGroupId
			GROUP BY	fr.MajorGroupId, ma.MajorGroupVolumeCount, fr.PUGDesc

/*
			select 'a', fr.MajorGroupId, -1, fr.PUGDesc, SUM(CalcPPMWeighted), SUM(CalcUCIPPMWeighted),
 					CASE	WHEN	SUM(fr.MajorGroupVolumeCount) > 0
 							THEN	SUM((fr.MetCritPPass * fr.MinorGroupVolumeCount * 1.0) / (fr.MajorGroupVolumeCount * 1.0)) -- (ma.MajorGroupVolumeCount * 1.0))
 							END
			FROM	#FinalResultSetSUMmaryInterim	fr
			JOIN	#MajorGroupList	ma	ON ma.MajorGroupId = fr.MajorGroupId
			GROUP BY	fr.MajorGroupId, ma.MajorGroupVolumeCount, fr.PUGDesc

			SELECT '#FinalResultSetSUMmaryInterim-1',* 
				FROM #FinalResultSetSUMmaryInterim fr
				where	fr.PLId is null
				and		fr.MajorGroupId = 1
			select '#MajorGroupList', * from #MajorGroupList
*/
	END
	ELSE
	BEGIN   -- (#IM00027249)
			INSERT INTO	#FinalResultSetSUMmaryInterim (
						MajorGroupId,
						PLId,
						PUGDesc,
						CalcPPM,
						CalcUCIPPM,
						MetCritPPass )
			SELECT	fr.MajorGroupId,
					-1,
					fr.PUGDesc,
					SUM(CalcPPMWeighted),
					SUM(CalcUCIPPMWeighted),
 					AVG(fr.MetCritPPass)		
			FROM	#FinalResultSetSUMmaryInterim	fr
			JOIN	#MajorGroupList	ma	ON ma.MajorGroupId = fr.MajorGroupId
			GROUP BY	fr.MajorGroupId, ma.MajorGroupVolumeCount, fr.PUGDesc
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
	IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
	IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
	IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
	IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PREPARE NORMPPM REPORT RESULT SETS'
	--=================================================================================================================
	--	PREPARE NORMPPM REPORT SUMMARY RESULT SET AND SHELL FOR DETAIL RESULT SET
	--	a.	INSERT shell for report SUMmary labels
	--	b.	ONLY return variables with defects
	--	c.	INSERT shell for report detail labels
	--	d.	UPDATE a column for each Minor group
	--	e.	Final Result Set SUMmary - calculate PPM  Minor group totals
	--	f.	Add Major Groups that do not have data
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INSERT shell for report SUMmary labels'
	--=================================================================================================================
	--	a.	INSERT shell for report SUMmary labels
	-------------------------------------------------------------------------------------------------------------------	
	INSERT INTO	#FinalResultSetSUMmary (
				MajorGroupId,
				PUGDesc,
				IncludeInSUM )
	SELECT	MajorGroupId,
			PUGDesc,
			IncludeInSUM
	FROM	#FinalResultSetSUMmaryInterim
	WHERE	PLId IS NULL
	GROUP BY	MajorGroupId, PUGDesc, IncludeInSUM	
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ONLY return variables with defects'
	--=================================================================================================================
	--	b.	ONLY return variables with defects
	-------------------------------------------------------------------------------------------------------------------	
	IF	@intRptVariableVisibility = 1	
	BEGIN
		DELETE	
		FROM	#NormPPMRptFinalResultSetDetailInterim 
		WHERE	ISNULL(ROUND(CalcPPM, 0), 0) = 0
			AND	MetCrit IS NULL
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' INSERT shell for report detail labels'
	--=================================================================================================================
	--	c.	INSERT shell for report detail labels
	-------------------------------------------------------------------------------------------------------------------	
	INSERT INTO	#NormPPMRptFinalResultSetDetail (
				MajorGroupId,
				SpecVersion,
				PUGDesc,
				VarDesc,
				IncludeInSUM )
	SELECT	MajorGroupId,
			SpecVersion,
			PUGDesc,
			VarDesc,
			IncludeInSUM
	FROM	#NormPPMRptFinalResultSetDetailInterim
	WHERE	PLId IS NULL
	GROUP BY	MajorGroupId, SpecVersion, PUGDesc, VarDesc, IncludeInSUM	
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' UPDATE a column for each Minor group'
	--=================================================================================================================
	--	d.	UPDATE a column for each Minor group
	-------------------------------------------------------------------------------------------------------------------	
	SET	@vchFieldListSUMmary = ''
	SET @vchFieldListSUMmaryProd = ''
	SET	@vchFieldListDetail = ''
	SET	@vchFieldListForTotal = ''
	SET @vchFieldListForTotalProd = ''
	-------------------------------------------------------------------------------------------------------------------	
	--		Initialize variables
	-------------------------------------------------------------------------------------------------------------------	
	SELECT	@j = 1,
			@intMajorGroupId = 1,
			@intMAXMajorGroupId = MAX(MajorGroupId)
	FROM	#MajorGroupList
	-------------------------------------------------------------------------------------------------------------------
	--		MajorGroupCursor	
	-------------------------------------------------------------------------------------------------------------------
	WHILE	@intMajorGroupId <= @intMAXMajorGroupId
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Initialize variables
		---------------------------------------------------------------------------------------------------------------
		SELECT	@i = 1,
				@intMinorGroupId = MIN(MinorGroupId),
				@intMAXMinorGroupId = MAX(MinorGroupId)
		FROM	#MinorGroupList
		WHERE	MajorGroupId = @intMajorGroupId
		---------------------------------------------------------------------------------------------------------------
		-- For each major group Insert a new Prod Line COUNT row
		---------------------------------------------------------------------------------------------------------------
		--	2010-10-25 : 
		--	Fixed issue raised at CAI, the total sample count should be the partial SUM
		--  of the Minor Grouping

		INSERT INTO #FinalResultSetSUMmary (				
					MajorGroupId, 
					PUGDesc, 
					TotalPPM)
		SELECT 	ma.MajorGroupId,
				--'TotalProdCOUNT',
				(SELECT CASE @intRptVolumeWeightOption	WHEN 1 THEN 'TotalSampleCOUNT'
														ELSE 'TotalProdCOUNT' END),
				-- MajorGroupVolumeCount
				SUM(MinorGroupVolumeCount)
		FROM #MajorGroupList ma
		JOIN #MinorGroupList mi ON ma.MajorGroupId = mi.MajorGroupId
		WHERE ma.MajorGroupId = @intMajorGroupId
		GROUP BY ma.MajorGroupId

		---------------------------------------------------------------------------------------------------------------
		--	MinorGroupCursor	
		--  When the column count is @i > 90 then make @intMinorGroupId = @intMAXMinorGroupId + 1
		---------------------------------------------------------------------------------------------------------------
		WHILE	@intMinorGroupId <= @intMAXMinorGroupId
		BEGIN
			-----------------------------------------------------------------------------------------------------------
			--	Final Result Set SUMmary Minor Groups
			--  Should change to ' = f2.CalcPPMWeighted, '?
			-----------------------------------------------------------------------------------------------------------
			SET	@nvchSQLCommand ='	UPDATE	f1 '
						+		'		SET		f1.CalcPPM' + CONVERT(VARCHAR(25), @i) +  ' = f2.CalcPPM, '
						+		'				f1.CalcUCIPPM' + CONVERT(VARCHAR(25), @i) +  ' = f2.CalcUCIPPM, '
						+		'				f1.MetCritPPass' + CONVERT(VARCHAR(25), @i) + ' = f2.MetCritPPass '
						+		'		FROM	#FinalResultSetSUMmary			f1 '
						+		'		JOIN	#FinalResultSetSUMmaryInterim	f2	ON		f1.PUGDesc 	= f2.PUGDesc '
						+		'															AND	f1.MajorGroupId = f2.MajorGroupId '
						+		'		WHERE	f2.MajorGroupId = @PrmMajorGroupId'
						+		'		AND	f2.MinorGroupId = @PrmMinorGroupId'
			-----------------------------------------------------------------------------------------------------------
			--	EXECUTE SQL
			-----------------------------------------------------------------------------------------------------------
			EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
									N'@PrmMajorGroupId INT, @PrmMinorGroupId INT',
									@intMajorGroupId, @intMinorGroupId
			-----------------------------------------------------------------------------------------------------------
			--	Final Result Set SUMmary Minor Groups
			-----------------------------------------------------------------------------------------------------------
			SET	@nvchSQLCommand ='	UPDATE	f1 '
						+		'		SET	f1.CalcPPM' + CONVERT(VARCHAR(25), @i) + ' = f2.MinorGroupVolumeCount '
						+		'		FROM	#FinalResultSetSUMmary			f1 '	
						+		'			JOIN #MinorGroupList	f2	ON 	f2.MajorGroupId = f1.MajorGroupId '					
						+		'										AND f2.MinorGroupId = @PrmMinorGroupId '
						+		'		WHERE	f1.MajorGroupId = @PrmMajorGroupId'
						+		'		AND	f2.MinorGroupId = @PrmMinorGroupId'
						+		'		AND (f1.PugDesc = ''TotalProdCOUNT'' OR f1.PugDesc = ''TotalSampleCOUNT'')'
			-----------------------------------------------------------------------------------------------------------
			--	EXECUTE SQL
			-----------------------------------------------------------------------------------------------------------
			EXECUTE sp_ExecuteSQL 	@nvchSQLCommand, 
									N'@PrmMajorGroupId INT, @PrmMinorGroupId INT',
									@intMajorGroupId, @intMinorGroupId
			-----------------------------------------------------------------------------------------------------------
			--	Assemble final select statement for SUMmary
			-----------------------------------------------------------------------------------------------------------
			IF	@j <= @i
			BEGIN
				SET	@vchFieldListSUMmary 		= @vchFieldListSUMmary 	+ ', CalcPPM' 		+ CONVERT(VARCHAR(25), @j) + ', MetCritPPass' + CONVERT(VARCHAR(25), @j)
				SET @vchFieldListSUMmaryProd 	= @vchFieldListSUMmaryProd + ', CalcPPM' 		+ CONVERT(VARCHAR(25), @j)
				SET	@vchFieldListForTotal 		= @vchFieldListForTotal + ', SUM(CalcPPM' + CONVERT(VARCHAR(25), @j) + '), NULL'
				SET @vchFieldListForTotalProd	= @vchFieldListForTotalProd + ', SUM(mi' + CONVERT(VARCHAR(25), @j) + '.MinorGroupVolumeCount)'
			END
			-----------------------------------------------------------------------------------------------------------
			-- Final Result Set Detail
			-----------------------------------------------------------------------------------------------------------
			IF	@intRptWeightSpecChanges = 1
			BEGIN
				SET	@nvchSQLCommand ='	UPDATE	f1 '
							+		'		SET		f1.CalcPPM' + CONVERT(VARCHAR(25), @i) + ' = f2.CalcPPM, '
							+		'				f1.CalcUCIPPM' + CONVERT(VARCHAR(25), @i) + ' = f2.CalcUCIPPM, '
							+		'				f1.MetCrit' + CONVERT(VARCHAR(25), @i) + ' = f2.MetCrit  '
							+		'		FROM	#NormPPMRptFinalResultSetDetail			f1 '
							+		'		JOIN	#NormPPMRptFinalResultSetDetailInterim	f2	ON	f1.PUGDesc      = f2.PUGDesc '
							+		'													AND	f1.VarDesc      = f2.VarDesc '
							+		'													AND	f1.MajorGroupId = f2.MajorGroupId '
							+		'		WHERE	f2.MajorGroupId = @PrmMajorGroupId'
							+		'		AND		f2.MinorGroupId = @PrmMinorGroupId'
				-------------------------------------------------------------------------------------------------------
				--	EXECUTE SQL
				-------------------------------------------------------------------------------------------------------
				EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
										N'@PrmMajorGroupId INT, @PrmMinorGroupId INT',
										@intMajorGroupId, @intMinorGroupId
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand ='	UPDATE	f1 '
							+		'		SET		f1.CalcPPM' + CONVERT(VARCHAR(25), @i) + ' = f2.CalcPPM, '
							+		'				f1.CalcUCIPPM' + CONVERT(VARCHAR(25), @i) + ' = f2.CalcUCIPPM, '
							+		'				f1.MetCrit' + CONVERT(VARCHAR(25), @i) + ' = f2.MetCrit  '
							+		'		FROM	#NormPPMRptFinalResultSetDetail			f1 ' 
							+		'		JOIN	#NormPPMRptFinalResultSetDetailInterim	f2	ON	f1.PUGDesc 		= f2.PUGDesc '
							+		'													AND	f1.VarDesc 		= f2.VarDesc '
							+		'													AND	f1.SpecVersion  = f2.SpecVersion '
							+		'													AND	f1.MajorGroupId = f2.MajorGroupId '
							+		'		WHERE	f2.MajorGroupId = @PrmMajorGroupId'
							+		'		AND		f2.MinorGroupId = @PrmMinorGroupId'
				-------------------------------------------------------------------------------------------------------
				--	EXECUTE SQL
				-------------------------------------------------------------------------------------------------------
				EXECUTE sp_ExecuteSQL 	@nvchSQLCommand,
										N'@PrmMajorGroupId INT, @PrmMinorGroupId INT',
										@intMajorGroupId, @intMinorGroupId
			END
			-----------------------------------------------------------------------------------------------------------
			-- Assemble final select statement for detail
			-----------------------------------------------------------------------------------------------------------
			IF	@j = @i
			BEGIN
				SET	@vchFieldListDetail = @vchFieldListDetail + ', CalcPPM' + CONVERT(VarChar, @j) + ', MetCrit' + CONVERT(VarChar, @j)
			END
			-----------------------------------------------------------------------------------------------------------
			-- Update Minor Group Column Number
			-----------------------------------------------------------------------------------------------------------
			UPDATE	#MinorGroupList
			SET		MinorGroupColId = @i
			WHERE	MajorGroupId 	= @intMajorGroupId
				AND	MinorGroupId 	= @intMinorGroupId
			-----------------------------------------------------------------------------------------------------------
			--	INCREMENT COUNTER
			-----------------------------------------------------------------------------------------------------------
			SET @intMinorGroupId = @intMinorGroupId + 1
			-----------------------------------------------------------------------------------------------------------
			--	INCREMENT COLUMN IDENTIFIER
			-----------------------------------------------------------------------------------------------------------			
			SET	@i = @i + 1
			-----------------------------------------------------------------------------------------------------------	
			--	Check that we do not exceed the MAX Grouping options, @intMinorGroupId = @intMAXMinorGroupId + 1
			--  20090415
			-----------------------------------------------------------------------------------------------------------			
			-- pgalanzi
--			IF @i > 50
			IF @i > @intMaxGroup 
			BEGIN
				SET @intMinorGroupId = @intMAXMinorGroupId + 1
				SET @vchWarningMsg = 'The Grouping Option selected for this report exceeds the Maximun, so information maybe incomplete!'
			END
			-----------------------------------------------------------------------------------------------------------	
			--	REQUIRED CODE
			-----------------------------------------------------------------------------------------------------------			
			IF	@j <= @i
			BEGIN
				SET	@j = @j + 1
			END		
		END		
		---------------------------------------------------------------------------------------------------------------
		--	Final Result Set SUMmary Total Column
		---------------------------------------------------------------------------------------------------------------
		UPDATE	fr
		SET		TotalPPM	 		= (CASE WHEN @intEnableVirtualZero = 1 THEN CalcUCIPPM ELSE CalcPPM END),
				TotalMetCritPPass 	= MetCritPPass
		FROM	#FinalResultSetSUMmary				fr
			JOIN	#FinalResultSetSUMmaryInterim	fi	ON 	fr.MajorGroupId	= fi.MajorGroupId
															AND	fr.PUGDesc 		= fi.PUGDesc
		WHERE	fi.PLId 		= -1
			AND	fi.MajorGroupId = @intMajorGroupId

		---------------------------------------------------------------------------------------------------------------
		-- Final Result Set Detail Total Column
		---------------------------------------------------------------------------------------------------------------
		IF	@intRptWeightSpecChanges = 1
		BEGIN
			UPDATE	fr
			SET		TotalPPM		= CalcPPM,
					TotalMetCrit 	= MetCrit
			FROM	#NormPPMRptFinalResultSetDetail			fr
				JOIN	#NormPPMRptFinalResultSetDetailInterim	fi	ON 	fr.MajorGroupId	= fi.MajorGroupId
																AND	fr.PUGDesc 		= fi.PUGDesc
																AND	fr.VarDesc		= fi.VarDesc
			WHERE	fi.PLId 		= -1
				AND	fi.MajorGroupId = @intMajorGroupId
		END
		ELSE
		BEGIN
			UPDATE	fr
			SET		TotalPPM	 = CalcPPM,
					TotalMetCrit = MetCrit
			FROM	#NormPPMRptFinalResultSetDetail				fr
				JOIN	#NormPPMRptFinalResultSetDetailInterim	fi	ON 	fr.MajorGroupId	= fi.MajorGroupId
																AND	fr.PUGDesc 		= fi.PUGDesc
																AND	fr.VarDesc		= fi.VarDesc
																AND	fr.SpecVersion	= fi.SpecVersion
			WHERE	fi.PLId 		= -1
				AND	fi.MajorGroupId = @intMajorGroupId
		END
		
		---------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTER
		---------------------------------------------------------------------------------------------------------------
		SET @intMajorGroupId = @intMajorGroupId + 1
	END	

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Final Result Set SUMmary - calculate PPM Minor group totals'
	--=================================================================================================================
	--	e.	Final Result Set SUMmary - calculate PPM  Minor group totals
	-------------------------------------------------------------------------------------------------------------------	
	SELECT	@j = 1,
			@i = MAX(MinorGroupId)
	FROM	#MinorGroupList

	--=================================================================================================================
	--	If @i is greater than the MAX grouping size then make it the MAXgroupingsize
	-------------------------------------------------------------------------------------------------------------------	

	-- pgalanzi
	-- IF @i > 50
	IF @i > @intMaxGroup 
	BEGIN
--		SET @i = 50
		SET @i = @intMaxGroup
		SET @vchWarningMsg = 'The Grouping Option selected for this report exceeds the Maximun, so information maybe incomplete!'
	END
	

	SET	@vchFieldListSUMmary = ''
	SET	@vchFieldListForTotal = ''
	SET	@vchFieldListDetail = '' 

	WHILE	@j <= @i
			BEGIN
				IF @intEnableVirtualZero = 1
				BEGIN
					SET	@vchFieldListForTotal 		= @vchFieldListForTotal + ', SUM(CalcPPM' + CONVERT(VARCHAR(25), @j) + '), SUM(CalcUCIPPM' + CONVERT(VarChar, @j) + '), NULL'		
			 		SET	@vchFieldListDetail 		= @vchFieldListDetail + ', CalcPPM' + CONVERT(VarChar, @j) + ', CalcUCIPPM' + CONVERT(VarChar, @j) + ', MetCrit' + CONVERT(VarChar, @j)	
					SET	@vchFieldListSUMmary 		= @vchFieldListSUMmary 	+ ', CalcPPM' + CONVERT(VARCHAR(25), @j) + ', CalcUCIPPM' + CONVERT(VARCHAR(25), @j) + ', MetCritPPass' + CONVERT(VARCHAR(25), @j)	
				END
				ELSE
				BEGIN
					SET	@vchFieldListForTotal 		= @vchFieldListForTotal + ', SUM(CalcPPM' + CONVERT(VARCHAR(25), @j) + '), NULL'		
					SET	@vchFieldListSUMmary 		= @vchFieldListSUMmary 	+ ', CalcPPM' 		+ CONVERT(VARCHAR(25), @j) + ', MetCritPPass' + CONVERT(VARCHAR(25), @j)	
					SET	@vchFieldListDetail 		= @vchFieldListDetail + ', CalcPPM' + CONVERT(VarChar, @j) + ', MetCrit' + CONVERT(VarChar, @j)	
				END
				SET @j = @j + 1				
			END
	-------------------------------------------------------------------------------------------------------------------	

	IF LEN(@vchFieldListSUMmary) > 0
	BEGIN
		SET	@nvchSQLCommand = 	''
		SET	@nvchSQLCommand = 	'	INSERT INTO	#FinalResultSetSUMmary ('
					+			'					MajorGroupId, '
					+			'					PUGDesc, '
					+								SUBSTRING(@vchFieldListSUMmary, 3, LEN(@vchFieldListSUMmary)) + ', TotalPPM)'
					+			'	SELECT		MajorGroupId, '
					+			'				''TotalPPM'', '
					+							SUBSTRING(@vchFieldListForTotal, 3, LEN(@vchFieldListForTotal)) + ', SUM(TotalPPM) '
					+			'	FROM		#FinalResultSetSUMmary'
					+			'	WHERE		IncludeInSUM = 1 '
					+			'	GROUP BY	MajorGroupId '
		---------------------------------------------------------------------------------------------------------------
		--	EXECUTE SQL
		---------------------------------------------------------------------------------------------------------------
		EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand			
	END	

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' Add Major Groups that do not have data to SUMmary result set'
	--=================================================================================================================
	--	f.	ADD Major Groups that do not have data to SUMmary result set
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblPLTemp (
				MajorGroupId)
	SELECT		MajorGroupId	
	FROM		#MajorGroupList
	WHERE		MajorGroupId NOT IN	(	SELECT	MajorGroupId
										FROM	#FinalResultSetSUMmary)
	-------------------------------------------------------------------------------------------------------------------
	IF	(SELECT	COUNT(*)
			FROM	@tblPLTemp) > 0
	BEGIN
		INSERT INTO	#FinalResultSetSUMmary (
					MajorGroupId,
					PUGDesc)
		SELECT		MajorGroupId,
					'<<NO DATA>>'
		FROM		@tblPLTemp		
	END		
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ADD Major Groups that do not have data to detail result set'
	--=================================================================================================================
	--	f.	ADD Major Groups that do not have data to detail result set
	-------------------------------------------------------------------------------------------------------------------	
	INSERT INTO	@tblPLTemp (
				MajorGroupId)
	SELECT		MajorGroupId	
	FROM		#MinorGroupList
	WHERE		MajorGroupId NOT IN	(	SELECT		MajorGroupId
										FROM	#NormPPMRptFinalResultSetDetail)
	-------------------------------------------------------------------------------------------------------------------
	IF	(	SELECT	COUNT(*)
			FROM	@tblPLTemp) > 0
	BEGIN
		INSERT INTO	#NormPPMRptFinalResultSetDetail (
					MajorGroupId)
		SELECT		MajorGroupId
		FROM		@tblPLTemp		
	END	

END
ELSE IF	@p_vchRptLayoutOption = 'VASReport'
BEGIN

	--=================================================================================================================
	IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
	IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
	IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
	IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
	IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PREPARE VAS SUMMARY AND DETAIL RESULT SETS'
	--=================================================================================================================
	--	PREPARE VAS SUMMARY AND DETAIL RESULT SETS
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VAS: populate table for regular attributes'
	--=================================================================================================================
	-- Variable Attributes: populate table for regular attributes				-- martin
	-------------------------------------------------------------------------------------------------------------------
	IF	@intRptWeightSpecChanges = 1
	BEGIN
		INSERT INTO	@tblVASRptVarAttributes	(
					MajorGroupId,
					PUGDesc,
					VarDesc,
					CalcPPMAoolContribution,
					ObsUCIPPMContribution,
					TotalPPM,
					PassesVirtualZero,
					PercentTarget,	
					SampleCOUNT,
					DefectCOUNT,
					SubGroupSize)
		SELECT	cp.MajorGroupId,
				pg.PUG_Desc + '(Att)',
				cp.VarDescRpt,
				SUM(cp.CalcPPMAoolContribution),
				SUM(cp.ObsUCIPPMContribution),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(cp.ObsUCIPPMContribution) ELSE SUM(cp.CalcPPMAoolContribution) END),
				SUM(PassesVirtualZero),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(PassesVZContribution) ELSE NULL END),
				SUM(cp.TestCount),
				SUM(cp.TestFail),
				cp.VarCount
		FROM	#CalcPPM			cp
			JOIN	dbo.PU_Groups	pg	WITH (NOLOCK)
										ON	cp.PUGId = pg.PUG_Id
			JOIN	#MajorGroupList	ma 	ON 	cp.MajorGroupId = 	ma.MajorGroupId			
		WHERE	cp.IsAtt = 1
			AND cp.IsNumericDataType = 0
		GROUP BY	cp.MajorGroupId, -- cp.VarGroupId, 
					cp.VarDescRpt, pg.PUG_Desc, cp.VarCount, cp.MajorGroupVolumeCount -- , SpecChange


		-- Only if weighting by Test Count
		IF @intRptVolumeWeightOption = 1 -- Volumen weight using test COUNT
		BEGIN
				UPDATE @tblVASRptVarAttributes
					SET SUMVolumeCount = (SELECT MAX(SampleCount) 
											FROM @tblVASRptVarAttributes
											WHERE MajorGroupId = tatt.MajorGroupId
											AND   PUGDesc 	   = tatt.PUGDesc  ) 
				FROM  @tblVASRptVarAttributes   tatt
		END
	END
	ELSE
	BEGIN				
		INSERT INTO	@tblVASRptVarAttributes	(
					MajorGroupId,
					PUGDesc,
					VarGroupId,
					VarDesc,
					CalcPPMAoolContribution,
					ObsUCIPPMContribution,
					TotalPPM,
					PassesVirtualZero,
					PercentTarget,	
					SampleCOUNT,
					DefectCOUNT,
					SubGroupSize,	
					SpecVersion	)
		SELECT		cp.MajorGroupId,
					pg.PUG_Desc + '(Att)',
					cp.VarGroupId,
					cp.VarDescRpt,
					SUM(cp.CalcPPMAoolContribution),
					SUM(cp.ObsUCIPPMContribution) ,
					(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(cp.ObsUCIPPMContribution) ELSE SUM(cp.CalcPPMAoolContribution) END) ,
					SUM(PassesVirtualZero),
					(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(PassesVZContribution) ELSE NULL END),
					--SUM(cp.CalcPPMAoolContribution),
					--SUM(cp.CalcPPMAoolContribution),
					SUM(cp.TestCount),
					SUM(cp.TestFail),
					cp.VarCount,
					cp.SpecVersion
		FROM	#CalcPPM		cp
			JOIN	dbo.PU_Groups	pg	WITH (NOLOCK)
										ON	cp.PUGId = pg.PUG_Id
			JOIN	#MajorGroupList	ma 	ON 	cp.MajorGroupId = ma.MajorGroupId		
		WHERE	cp.IsAtt = 1
			AND cp.IsNumericDataType = 0
		GROUP BY	cp.MajorGroupId, pg.PUG_Desc, cp.VarGroupId, cp.VarDescRpt, cp.SpecVersion, cp.VarCount, cp.MajorGroupVolumeCount -- , SpecChange			

		-- Only if weighting by Test Count
		IF @intRptVolumeWeightOption = 1 -- Volumen weight using test COUNT
		BEGIN
				UPDATE @tblVASRptVarAttributes
					SET SUMVolumeCount = (SELECT MAX(SampleCount) 
											FROM @tblVASRptVarAttributes
											WHERE MajorGroupId = tatt.MajorGroupId
											AND   PUGDesc 	   = tatt.PUGDesc  ) 
				FROM  @tblVASRptVarAttributes   tatt
		END

	END
	
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VAS: populate table for measurable attributes'
	--=================================================================================================================
	--	Variable Attributes: populate table for measurable attributes
	--	Business rule: measurable attributes are numeric variables that are treated as attributes. In VAS MIN, MAX
	--	Avg and StDev are reported for this variables
	-------------------------------------------------------------------------------------------------------------------

	IF	@intRptWeightSpecChanges = 1
	BEGIN
	 	INSERT INTO	@tblVASRptVarAttributes	(
 					MajorGroupId,
 					PUGDesc,
 					VarDesc,
 					CalcPPMAoolContribution,
					ObsUCIPPMContribution,
 					TotalPPM,
					PassesVirtualZero,
					PercentTarget,	
 					SampleCOUNT,
 					DefectCOUNT,
 					SubGroupSize,
 					TestMIN,
 					TestMAX,
 					SUMTestAvg,
					TestStDev,
 					SUMVolumeCount)
		SELECT	cp.MajorGroupId,
				pg.PUG_Desc + '(Att)',
				cp.VarDescRpt,
				SUM(cp.CalcPPMAoolContribution),
				SUM(cp.ObsUCIPPMContribution) ,
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(ObsUCIPPMContribution) ELSE SUM(cp.CalcPPMAoolContribution) END),
				-- SUM(cp.CalcPPMAoolContribution),
				-- SUM(cp.CalcPPMAoolContribution),
				SUM(PassesVirtualZero),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(PassesVZContribution) ELSE NULL END),
				SUM(cp.TestCount),
				SUM(cp.TestFail),
				cp.VarCount	,
				NULL		,	-- MIN(cp.TestMIN),
				NULL		,	-- MAX(cp.TestMAX),
				SUM(cp.VolumeCount * CONVERT(FLOAT, COALESCE(cp.TestAvg, 0))),
				SQRT(SUM(cp.TestSUMSquaredDev)/(SUM(cp.TestCount) - 1)), 
				SUM(cp.VolumeCount)		
		FROM	#CalcPPM			cp
			JOIN	dbo.PU_Groups	pg	WITH (NOLOCK)
										ON	cp.PUGId 		= 	pg.PUG_Id
			JOIN	#MajorGroupList	ma 	ON 	cp.MajorGroupId = 	ma.MajorGroupId
		WHERE	cp.IsAtt = 1
			AND cp.IsNumericDataType = 1
		GROUP BY	cp.MajorGroupId, -- cp.VarGroupId, 
		cp.VarDescRpt, pg.PUG_Desc, cp.VarCount, cp.MajorGroupVolumeCount -- , SpecChange

		-- Only if weighting by Test Count
		IF @intRptVolumeWeightOption = 1 -- Volumen weight using test COUNT
		BEGIN
				UPDATE @tblVASRptVarAttributes
					SET SUMVolumeCount = (SELECT MAX(SampleCount) 
											FROM @tblVASRptVarAttributes
											WHERE MajorGroupId = tatt.MajorGroupId
											AND   PUGDesc 	   = tatt.PUGDesc  ) 
				FROM  @tblVASRptVarAttributes   tatt
		END
		---------------------------------------------------------------------------------------------------------------	
		--	 Calculate test average
		---------------------------------------------------------------------------------------------------------------
		UPDATE	@tblVASRptVarAttributes
			SET	TestAvg	= SUMTestAvg / SUMVolumeCount
		FROM	@tblVASRptVarAttributes
		WHERE	SUMVolumeCount > 0

	END
	ELSE
	BEGIN		
		INSERT INTO	@tblVASRptVarAttributes	(
					MajorGroupId,
					PUGId,
					PUGDesc,
					VarGroupId,
					VarDesc,
					CalcPPMAoolContribution,
					ObsUCIPPMContribution,
					TotalPPM,
					PassesVirtualZero,
					PercentTarget,	
					SampleCOUNT,
					DefectCOUNT,
					SubGroupSize,	
					SpecVersion,
					TestMIN,
					TestMAX,
					LSL,
					Target,
					USL,
					TestAvg,
					TestStDev )
		SELECT	cp.MajorGroupId,
				cp.PUGId,
				pg.PUG_Desc + '(Att)',
				cp.VarGroupId,
				cp.VarDescRpt,
				cp.CalcPPMAoolContribution ,
				cp.ObsUCIPPMContribution	,
				(CASE WHEN @intEnableVirtualZero = 1 THEN cp.ObsUCIPPMContribution ELSE cp.CalcPPMAoolContribution END) ,
				cp.PassesVirtualZero,
				(CASE WHEN @intEnableVirtualZero = 1 THEN cp.PassesVZContribution ELSE NULL END),
				cp.TestCount,
				cp.TestFail,
				cp.VarCount,
				cp.SpecVersion,
				cp.TestMIN,
				cp.TestMAX,
				cp.LSL,
				cp.TargetRpt,
				cp.USL,
				CONVERT(FLOAT, COALESCE(cp.TestAvg, 0)),
				CONVERT(FLOAT, COALESCE(cp.TestStDev, 0))
		FROM	#CalcPPM			cp
			JOIN	dbo.PU_Groups	pg	WITH (NOLOCK)
										ON	cp.PUGId = pg.PUG_Id
			JOIN	#MajorGroupList	ma 	ON 	cp.MajorGroupId = ma.MajorGroupId
		WHERE	cp.IsAtt = 1	
			AND cp.IsNumericDataType = 1	
		
		-- Only if weighting by Test Count
		IF @intRptVolumeWeightOption = 1 -- Volumen weight using test COUNT
		BEGIN
			UPDATE @tblVASRptVarAttributes
				SET SUMVolumeCount = (SELECT MAX(SampleCount) 
										FROM @tblVASRptVarAttributes
										WHERE MajorGroupId = tatt.MajorGroupId
										AND   PUGDesc 	   = tatt.PUGDesc  ) 
			FROM  @tblVASRptVarAttributes   tatt
		END


		---------------------------------------------------------------------------------------------------------------	
		--	 Calculate test average
		---------------------------------------------------------------------------------------------------------------
		UPDATE	@tblVASRptVarAttributes
			SET	TestAvg	= SUMTestAvg / SUMVolumeCount
		FROM	@tblVASRptVarAttributes
		WHERE	SUMVolumeCount > 0

		---------------------------------------------------------------------------------------------------------------
		--	Get Limits
		---------------------------------------------------------------------------------------------------------------	
		UPDATE		@tblVASRptVarAttributes
			SET		LSL 	= cp.LSL,
					Target 	= CONVERT(FLOAT, cp.TargetRpt),
					USL 	= cp.USL
		FROM	@tblVASRptVarAttributes 	vs
			JOIN	#CalcPPM			cp	ON	vs.VarGroupId = cp.VarGroupId
												AND	vs.MajorGroupId = cp.MajorGroupId
		WHERE	cp.IsAtt = 1
			AND cp.IsNumericDataType = 1

	END


	-------------------------------------------------------------------------------------------------------------------
	-- Calculate the % Target for Attributes
	-------------------------------------------------------------------------------------------------------------------	
	IF @intEnableVirtualZero = 0 
	BEGIN
		UPDATE	@tblVASRptVarAttributes
				SET	PercentTarget = (CONVERT(FLOAT,SampleCount) - CONVERT(FLOAT,DefectCount)) / CONVERT(FLOAT,SampleCount)				
	END

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' VAS: populate table for Variable Statistics'
	--=================================================================================================================
	--	Variable Statistics: populate table
	--	a.	Get Aggregates for VarGroupId
	--	b.	Get Weighted Aggregates for VarGroupId
	--	c.	Get Spec Limits
	-------------------------------------------------------------------------------------------------------------------

	IF	@intRptWeightSpecChanges = 1
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	a	Get Aggregates for VarGroupId       -- martin
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblVASRptVarStatistics	(
					MajorGroupId,
					PUGDesc,
					VarDesc,
					CalcPPMAoolContribution,
					CalcPPMPoolActual,
					CalcPPMPoolContribution,
					ObsUCIPPMContribution		,
					CalcUCIPPM			,
					CalcUCIPPMContribution		,
					SUMMetCritActual,
					TotalPPM,
					SampleCOUNT,
					DefectCOUNT,
					TestMIN,
					TestMAX,
					SUMTestAvg,
					TestStDev,
					SUMTz,
					SUMCr,
					SUMCpK,
					SUMMCTz,
					SUMMCCr,
					SUMMCCpK,
					SubGroupSize,
					SpecVersion,
					SUMCalcCpK,
					SUMVolumeCount )
		SELECT	cp.MajorGroupId,
				pg.PUG_Desc + ' (#)',
				cp.VarDescRpt,
				SUM(cp.CalcPPMAoolContribution),
				SUM(cp.CalcPPMPoolActual) ,
				SUM(cp.CalcPPMPoolContribution) ,
				SUM(ObsUCIPPMContribution) ,
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPMContribution) ELSE NULL END) ,
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPMContribution) ELSE NULL END),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(cp.VolumeCount * cp.PassesVirtualZero) --cp.PassesVzContribution
					ELSE SUM(cp.VolumeCount * CONVERT(FLOAT, cp.MetCritActual)) END), --/ cp.MinorGroupVolumeCount) * cp.VolumeCount) END),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPMContribution) ELSE SUM(cp.CalcPPMPoolContribution) END),
				SUM(TestCount),
				SUM(TestFail),
				MIN(TestMIN),
				MAX(TestMAX),
				SUM(cp.VolumeCount * CONVERT(FLOAT, cp.TestAvg))	,
				SQRT(SUM(cp.TestSUMSquaredDev)/(SUM(cp.TestCount) - 1)), 
				SUM((cp.VolumeCount * CONVERT(FLOAT, cp.Tz))) 		,
				SUM((cp.VolumeCount * CONVERT(FLOAT, cp.Cr))) 		,
				SUM((cp.VolumeCount * CONVERT(FLOAT, cp.CpK))) 		,
				SUM((cp.VolumeCount * CONVERT(FLOAT, cp.MCTz))) 	,
				SUM((cp.VolumeCount * CONVERT(FLOAT, cp.MCCr))) 	,
				SUM((cp.VolumeCount * CONVERT(FLOAT, cp.MCCpK))) 	,
				cp.VarCount,
				NULL,
				SUM(cp.VolumeCount * CONVERT(FLOAT, cp.CalcCpK)), 	
				SUM(cp.VolumeCount)
			FROM	#CalcPPM				cp
				JOIN	dbo.PU_Groups		pg	WITH (NOLOCK) 
												ON	cp.PUGId = pg.PUG_Id
				JOIN	#MajorGroupList		ma 	ON 	cp.MajorGroupId = ma.MajorGroupId
			WHERE	cp.IsAtt 		= 0
			GROUP BY	cp.MajorGroupId, pg.PUG_Desc, --cp.VarGroupId, 
						cp.VarDescRpt, cp.VarCount, cp.MajorGroupVolumeCount -- , cp.SpecChange

		---------------------------------------------------------------------------------------------------------------
		--	b.	Get Weighted Aggregates for VarGroupId
		---------------------------------------------------------------------------------------------------------------
		UPDATE		@tblVASRptVarStatistics
			SET		MetCritActual			=	SUMMetCritActual	/ SUMVolumeCount,
					MetCritPPass			=	SUMMetCritActual 	/ SUMVolumeCount,
					TestAvg					=	SUMTestAvg 			/ SUMVolumeCount,
					Tz						=	SUMTz 				/ SUMVolumeCount,
					Cr						=	SUMCr 				/ SUMVolumeCount,
					Cpk						=	SUMCpk				/ SUMVolumeCount,
					MetCritTz				=	SUMMCTz 			/ SUMVolumeCount,
					MetCritCr				=	SUMMCCr	 			/ SUMVolumeCount,
					MetCritCpk				=	SUMMCCpK 			/ SUMVolumeCount,
					CalcCpk					=	SUMCalcCpK 			/ SUMVolumeCount
					-- CalcUCIPPM				=   CalcUCIPPM			/ SUMVolumeCount
			FROM	@tblVASRptVarStatistics
			WHERE	SUMVolumeCount > 0
		---------------------------------------------------------------------------------------------------------------
		--	c.	Get Spec Limits		
		---------------------------------------------------------------------------------------------------------------
		UPDATE		@tblVASRptVarStatistics
			SET		LSL 	= cp.LSL,
					Target 	= cp.TargetRpt,
					USL 	= cp.USL
			FROM	@tblVASRptVarStatistics 	vs
			JOIN	#CalcPPM				cp	ON	vs.VarGroupId 	= cp.VarGroupId
												AND	vs.MajorGroupId = cp.MajorGroupId
	END
	ELSE
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	a.	Get slices from #CalcPPM
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblVASRptVarStatistics	(
					MajorGroupId,
					PUGDesc,
					VarDesc,
					CalcPPMAoolContribution,
					CalcPPMPoolActual,
					CalcPPMPoolContribution,	
					ObsUCIPPMContribution		,
					CalcUCIPPM			,
					CalcUCIPPMContribution		,	
					MetCritActual,
					MetCritPPassTemp,
					MinorGroupVolumeCountTemp,
					TotalPPM,
					SampleCOUNT,
					DefectCOUNT,
					LSL,
					Target,
					USL,
					LTL,
					UTL,
					TestMIN,
					TestMAX,
					TestAvg,
					TestStDev,
					Tz,
					Cr,
					CpK,
					MetCritTz,
					MetCritCr,
					MetCritCpK,
					SubGroupSize,
					SpecVersion,
					CalcCpK)
		SELECT	cp.MajorGroupId,
				pg.PUG_Desc + ' (#)',
				cp.VarDescRpt,
				SUM(cp.CalcPPMAoolContribution),
				SUM(cp.CalcPPMPoolActual) ,
				SUM(cp.CalcPPMPoolContribution) ,
				SUM(ObsUCIPPMContribution) ,
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPM) ELSE NULL END) ,
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPMContribution) ELSE NULL END) ,
				--cp.CalcPPMAoolContribution,				
				--cp.CalcPPMPoolActual,
				--cp.CalcPPMPoolContribution,
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(cp.PassesVirtualZero) ELSE SUM(CONVERT(FLOAT, cp.MetCritActual)) END),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CONVERT(FLOAT, cp.PassesVZContribution)) * SUM(cp.VolumeCount) 
											ELSE SUM(CONVERT(FLOAT, ISNULL(cp.MetCritActual,0))) * SUM(cp.VolumeCount) END),
				SUM(cp.MinorGroupVolumeCount),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPM) ELSE SUM(cp.CalcPPMPoolContribution) END),
				SUM(TestCount),
				SUM(TestFail),
 				LSL,
				TargetRpt,
				USL,
				LTL,
				UTL,
				TestMIN,
				TestMAX,
				CONVERT(FLOAT, cp.TestAvg),
				CONVERT(FLOAT, cp.TestStDev),
				CONVERT(FLOAT, cp.Tz),
				CONVERT(FLOAT, cp.Cr),
				CONVERT(FLOAT, cp.CpK),
				CONVERT(FLOAT, cp.MCTz),
				CONVERT(FLOAT, cp.MCCr),
				CONVERT(FLOAT, cp.MCCpK),
				cp.VarCount,
				cp.SpecVersion,
				CONVERT(FLOAT, cp.CalcCpK)	
		FROM	#CalcPPM				cp
			JOIN	dbo.PU_Groups		pg	WITH (NOLOCK)
											ON	cp.PUGId = pg.PUG_Id
			JOIN	#MajorGroupList		ma 	ON 	cp.MajorGroupId = ma.MajorGroupId
		WHERE	cp.IsAtt = 0
		GROUP BY	cp.MajorGroupId, pg.PUG_Desc, --cp.VarGroupId, 
				cp.VarDescRpt, cp.VarCount, LSL,
				TargetRpt,USL,LTL,	UTL,TestMIN,
				TestMAX, cp.TestAvg, cp.TestStDev,
				cp.Tz, cp.Cr,cp.CpK, cp.MCTz, cp.MCCr,cp.MCCpK,cp.VarCount,
				cp.SpecVersion, cp.CalcCpK	
		---------------------------------------------------------------------------------------------------------------
		-- Note: given the current default value for Major Grouping : PLId|ProdGrpId. The final result 
		-- set does not need to be grouped. I have removed the code that does the weighting to prevent 
		-- a div by zero. RP 27-Jun-2005
		---------------------------------------------------------------------------------------------------------------
		UPDATE	@tblVASRptVarStatistics
			SET	MetCritPPass = MetCritPPassTemp / MinorGroupVolumeCountTemp
			WHERE	MinorGroupVolumeCountTemp > 0

	END
END


-- MetCriteria Troubleshooting
-- SELECT '@tblVASRptVarStatistics',SUMMetCritActual, SUMVolumeCount,* FROM @tblVASRptVarStatistics
-- SELECT '#NormPPMRptFinalResultSetDetailInterim',* FROM #NormPPMRptFinalResultSetDetailInterim WHERE PUGDesc = 'Pool Logical' 
-- SELECT '#NormPPMRptFinalResultSetDetail',* FROM #NormPPMRptFinalResultSetDetail WHERE PUGDesc = 'Pool Logical' 
-- SELECT * FROM #FinalResultSetSUMmaryInterim

--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' PREPARE MISCELLANEOUS INFORMATION RESULT SET'
--=====================================================================================================================
--	PREPARE: Misc Info
--	a.	FILTER - Production Lines: GET Production line descriptions
--	b.	FILTER - Production Units: GET Production Unit descriptions
--	c.	FILTER - Product: GET Product code 
--	d.	FILTER - Product Group: GET Product Group Descriptions 
--	e.	FILTER - Production Status: GET Production Status descriptions
--	f.	FILTER - Shift: GET Shift descriptions
--	g.	FILTER - Team: GET Team descriptions
--	h.	COUNT recordsets
--	i.	POPULATE #MiscInfo Table
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Production Lines: GET Production line descriptions'
--=====================================================================================================================
--	a.	FILTER - Production Lines: GET Production line descriptions
-----------------------------------------------------------------------------------------------------------------------	
--	GET the MAXimum number of production lines
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchPLList = '',
		@i = 1,
		@intMAXRcdIdx = MAX(RcdIdx)
FROM	@tblListPLFilter
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE a string that concatenates a string with the list of selected production lines
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMAXRcdIdx
BEGIN
	SELECT	@vchPLList = @vchPLList + ', ' + PLDesc
	FROM	@tblListPLFilter
	WHERE	RcdIdx = @i
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT COUNTer
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END
-----------------------------------------------------------------------------------------------------------------------
--	TRIM off the extra , 
-----------------------------------------------------------------------------------------------------------------------
IF	@intMAXRcdIdx > 0
BEGIN
	SET	@vchPLList = LTRIM(RTRIM(SUBSTRING(@vchPLList, 2, LEN(@vchPLList))))
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Production Units: GET Production Unit descriptions'
--=====================================================================================================================
--	b.	FILTER - Production Units: GET Production Unit descriptions
-----------------------------------------------------------------------------------------------------------------------	
--	GET the MAXimum number of production Units
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchPUList = '',
		@i = 1,
		@intMAXRcdIdx = MAX(RcdIdx)
FROM	@tblListPUFilter
-----------------------------------------------------------------------------------------------------------------------
--	Get the PUDesc
-----------------------------------------------------------------------------------------------------------------------
UPDATE	lpu
	SET	PUDesc = PU_Desc
FROM	@tblListPUFilter	lpu
	JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK) ON	lpu.PUId = pu.PU_Id
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE a string that concatenates a string with the list of selected production Units
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMAXRcdIdx
BEGIN
	SELECT	@vchPUList = @vchPUList + ', ' + PUDesc
	FROM	@tblListPUFilter
	WHERE	RcdIdx = @i
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT COUNTer
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END
-----------------------------------------------------------------------------------------------------------------------
--	TRIM off the extra , 
-----------------------------------------------------------------------------------------------------------------------
IF	@intMAXRcdIdx > 0
BEGIN
	SET	@vchPUList = LTRIM(RTRIM(SUBSTRING(@vchPUList, 2, LEN(@vchPUList))))
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Product: GET Product code '
--=====================================================================================================================
--	c.	FILTER - Product: GET Product code 
-----------------------------------------------------------------------------------------------------------------------	
--	GET the MAXimum number of products
-----------------------------------------------------------------------------------------------------------------------
IF	LEN(@vchRptProdIdList) > 0
BEGIN
	SELECT	@vchProductList = '',
			@i = 1,
			@intMAXRcdIdx = MAX(RcdIdx)
	FROM	@tblListProductFilter
	-----------------------------------------------------------------------------------------------------------------------
	--	PREPARE a string that concatenates a string with the list of selected production lines
	-----------------------------------------------------------------------------------------------------------------------
	WHILE	@i <= @intMAXRcdIdx
	BEGIN
		SELECT	@vchProductList = @vchProductList + ', ' + ProdCode
		FROM	@tblListProductFilter
		WHERE	RcdIdx = @i
		-------------------------------------------------------------------------------------------------------------------
		--	INCREMENT COUNTer
		-------------------------------------------------------------------------------------------------------------------
		SET	@i = @i + 1
	END
	-----------------------------------------------------------------------------------------------------------------------
	--	TRIM off the extra , 
	-----------------------------------------------------------------------------------------------------------------------
	IF	@intMAXRcdIdx > 0
	BEGIN
		SET	@vchProductList = LTRIM(RTRIM(SUBSTRING(@vchProductList, 2, LEN(@vchProductList))))
	END
END
ELSE
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Default to ALL
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchProductList = 'ALL'
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Product Group: GET Product Group Descriptions  '
--=====================================================================================================================
--	d.	FILTER - Product Group: GET Product Group Descriptions 
-----------------------------------------------------------------------------------------------------------------------
--	GET the MAXimum number of product groups
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchProductGroupList = '',
		@i = 1,
		@intMAXRcdIdx = MAX(RcdIdx)
FROM	@tblListProductGroupsFilter
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE a string that concatenates a string with the list of selected product groups
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMAXRcdIdx
BEGIN
	SELECT	@vchProductGroupList = @vchProductGroupList + ', ' + ProductGrpDesc
	FROM	@tblListProductGroupsFilter
	WHERE	RcdIdx = @i
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT COUNTer
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END
-----------------------------------------------------------------------------------------------------------------------
--	TRIM off the extra , 
-----------------------------------------------------------------------------------------------------------------------
IF	@intMAXRcdIdx > 0
BEGIN
	SET	@vchProductGroupList = LTRIM(RTRIM(SUBSTRING(@vchProductGroupList, 2, LEN(@vchProductGroupList))))
END
ELSE
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Default to ALL
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchProductGroupList = 'ALL'
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Production Status: GET Production Status descriptions'
--=====================================================================================================================
--	e.	FILTER - Production Status: GET Production Status descriptions
-----------------------------------------------------------------------------------------------------------------------
SELECT	@vchPLStatusList = '',
		@i = 1,
		@intMAXRcdIdx = MAX(RcdIdx)
FROM	@tblListPLStatusFilter
-----------------------------------------------------------------------------------------------------------------------
--	PREPARE a string that concatenates a string with the list of selected product groups
-----------------------------------------------------------------------------------------------------------------------
WHILE	@i <= @intMAXRcdIdx
BEGIN
	SELECT	@vchPLStatusList = @vchPLStatusList + ', ' + PLStatusDescSite
	FROM	@tblListPLStatusFilter
	WHERE	RcdIdx = @i
	-------------------------------------------------------------------------------------------------------------------
	--	INCREMENT COUNTer
	-------------------------------------------------------------------------------------------------------------------
	SET	@i = @i + 1
END
-----------------------------------------------------------------------------------------------------------------------
--	TRIM off the extra , 
-----------------------------------------------------------------------------------------------------------------------
IF	@intMAXRcdIdx > 0
BEGIN
	SET	@vchPLStatusList = LTRIM(RTRIM(SUBSTRING(@vchPLStatusList, 2, LEN(@vchPLStatusList))))
END
ELSE
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Default to ALL
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchPLStatusList = 'ALL'
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Shift: GET Shift descriptions'
--=====================================================================================================================
--	f.	FILTER - Shift: GET Shift descriptions
--		Business Rule:
--		IF	@vchRptShiftDescList = '' THEN the defaul is all ELSE the shift filter is equal to what the user picked
-----------------------------------------------------------------------------------------------------------------------
IF	LEN(@vchRptShiftDescList) = 0
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Default to ALL
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchRptShiftDescList = 'ALL'
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' FILTER - Crea: GET Crew descriptions'
--=====================================================================================================================
--	g.	FILTER - Crew: GET Crew descriptions
--		Business Rule:
--		IF	@vchRptCrewDescList = '' THEN the defaul is all ELSE the shift filter is equal to what the user picked
-----------------------------------------------------------------------------------------------------------------------
IF	LEN(@vchRptCrewDescList) = 0
BEGIN
	-------------------------------------------------------------------------------------------------------------------
	--	Default to ALL
	-------------------------------------------------------------------------------------------------------------------
	SET	@vchRptCrewDescList = 'ALL'
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' COUNT Recodsets'
--=====================================================================================================================
--	h.	COUNT recordsets
-----------------------------------------------------------------------------------------------------------------------
IF	EXISTS	(SELECT	CalcPPMId
			 FROM	#CalcPPM)
BEGIN
	SET	@intRcdCOUNT = 1
END
ELSE
BEGIN
	SET	@intRcdCOUNT = 0
END
--=====================================================================================================================
IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' POPULATE #Misc Info Table'
--=====================================================================================================================
--	i.	POPULATE #Misc Info Table
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @tblMiscInfo (
		CompanyName,
		SiteName,
		RptOwnerDesc,
		RptTitle,
		RptStartDateTime,
		RptEndDateTime,
		PeriodIncompleteFlag,
		FilterPL,
		FilterPU,
		FilterProduct,
		FilterProductGroup,
		FilterCrew,
		FilterShift,
		FilterPLStatus,
		MajorGroupBy,
		MinorGroupBy,
		WithDataValidation,
		WithDataValidationExtended,
		WeightSpecChanges,
		SpecSetting,
		EmptyRcdSet,
		ColPrecision,
		ErrorMsg,
		WarningMsg,
		-- Add for search Version
		AppVersion,
		RTVersion ,
		VzEnabled	)
SELECT @vchCompanyName,
		@vchSiteName,
		@vchRptOwnerDesc,
		@vchRptTitle,
		@p_vchRptStartDateTime,
		@p_vchRptEndDateTime,
		@intPeriodIncompleteFlag,
		@vchPLList,
		@vchPUList,
		@vchProductList,
		@vchProductGroupList,
		@vchRptCrewDescList,
		@vchRptShiftDescList,
		@vchPLStatusList,
		@vchRptMajorGroupBy,
		@vchRptMinorGroupBy,
		@intRptWithDataValidation,
		@intRptWithDataValidationExtended,
		@intRptWeightSpecChanges,
		@intSpecSetting,
		CASE WHEN @intRcdCOUNT > 0
		THEN 'No'
		ELSE 'Yes'
		END,
		@intRptPrecision,
		@vchErrorMsg,
		@vchWarningMsg,
		-- Add for search Version
		@vchAppVersion,
		@vchRTVersion,
		@intEnableVirtualZero 


--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT	'END SECTION : ' + CONVERT(VARCHAR, @intSecNumber) + ' - TOTAL TIME (sec): ' + CONVERT(VARCHAR, DateDiff(Second, @dtmTempDate, GETDATE())) 
IF @intPRINTFlag = 1	SET	@dtmTempDate 	= GETDATE()
IF @intPRINTFlag = 1	SET	@intSecNumber 	= @intSecNumber + 1
IF @intPRINTFlag = 1	PRINT '-----------------------------------------------------------------------------------------------------------------------'
IF @intPRINTFlag = 1	SET	@intSubSecNumber = 0
IF @intPRINTFlag = 1	PRINT 'START SECTION : '+	CONVERT(VARCHAR, @intSecNumber)
IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' RETURN RESULT SETS'
--=====================================================================================================================
-- CHECK FOR ERRORS
-----------------------------------------------------------------------------------------------------------------------
FINISHError:
-----------------------------------------------------------------------------------------------------------------------
IF	@intErrorCode > 0
BEGIN
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Miscellaneous information'
	--=================================================================================================================
	--	PREPARE: Error Output
	-------------------------------------------------------------------------------------------------------------------
	INSERT INTO	@tblMiscInfo (
				ErrorCode,
				ErrorMsg)
	SELECT	@intErrorCode,
			@vchErrorMsg
	-------------------------------------------------------------------------------------------------------------------
	SELECT * FROM	@tblMiscInfo	
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Filter Criteria'
	--=================================================================================================================
	--	PREPARE: Error Output
	-------------------------------------------------------------------------------------------------------------------
	IF	@intErrorCode = 1
	BEGIN
		SELECT * FROM @tblErrorCriteria	
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> BAD Data'
	--=================================================================================================================
	--	PREPARE: Error Output
	-------------------------------------------------------------------------------------------------------------------
	IF	@intErrorCode = 2
	BEGIN
		SELECT * FROM @tblBadDataList	
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> BAD Spec Data'
	--=================================================================================================================
	--	PREPARE: Error Output
	-------------------------------------------------------------------------------------------------------------------
	IF	@intErrorCode = 8
	BEGIN
	SELECT * FROM	#CalcPPM
					WHERE	LEL		LIKE 	'%,%'
						OR	LSL		LIKE 	'%,%'
						OR	LTL		LIKE	'%,%'
						OR	Target	LIKE	'%,%'
						OR	UTL		LIKE	'%,%'
						OR	USL		LIKE	'%,%'
						OR	UEL		LIKE	'%,%'
	END
END
ELSE
BEGIN
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> MiscInfo'
	--=================================================================================================================
	SELECT * FROM	@tblMiscInfo	
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> MajorGroupBy'
	--=================================================================================================================
	SELECT * FROM	#MajorGroupList
	--=================================================================================================================
	--	NORMPPM REPORT RESULT SETS
	--=================================================================================================================
	IF	@p_vchRptLayoutOption	= 'NormPPM'
	BEGIN
		--=============================================================================================================
		IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
		IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> MinorGroupBy'
		--=============================================================================================================
		SELECT * FROM	#MinorGroupList
		ORDER BY MajorGroupid, MinorGroupColId
		--=============================================================================================================
		IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
		IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Report SUMmary Section NormPPM'
		--=============================================================================================================
		--	Report SUMmary Section NormPPM
		---------------------------------------------------------------------------------------------------------------			
		IF LEN(@vchFieldListSUMmary) > 0
		BEGIN
			IF	@intRptWeightSpecChanges = 1
			BEGIN
				SET	@nvchSQLCommand = 	'	SELECT 		Border1, '
								+		'				MajorGroupId, '
								+		'				Null DummyCol, '
								+		'				PugDesc, '
								+						SUBSTRING(@vchFieldListSUMmary, 3, LEN(@vchFieldListSUMmary)) + ', '
								+		'				TotalPPM, '
								+		'				TotalMetCritPPass, '
								+		'				Border2 '
								+		'		FROM	#FinalResultSetSUMmary '
								+		'	ORDER BY	MajorGroupId, PUGDesc '
				-------------------------------------------------------------------------------------------------------
				--	EXECUTE SQL
				-------------------------------------------------------------------------------------------------------
				EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = 	'	SELECT 	Border1, '
								+		'				MajorGroupId, '
								+		'				Null DummyCol, '
								+		'				PugDesc, '
								+						SUBSTRING(@vchFieldListSUMmary, 3, LEN(@vchFieldListSUMmary)) + ', '
								+		'				TotalPPM, '
								+		'				TotalMetCritPPass, '
								+		'				SpecVersion, '
								+		'				Border2 '
								+		'		FROM	#FinalResultSetSUMmary '
								+		'	ORDER BY	MajorGroupId, PUGDesc '
				-------------------------------------------------------------------------------------------------------
				--	EXECUTE SQL
				-------------------------------------------------------------------------------------------------------
				EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
			END		
		END		
		--=============================================================================================================
		IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
		IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Report Detail Section NormPPM'
		--=============================================================================================================
		--	Return #NormPPMRptFinalResultSetDetail
		---------------------------------------------------------------------------------------------------------------	
		IF LEN (@vchFieldListDetail) > 0
			BEGIN
			IF	@intRptWeightSpecChanges = 1
			BEGIN

				SET	@nvchSQLCommand = 	'		SELECT 	Border1		, '
								+		'				MajorGroupId, '
								+		'				PugDesc		, '
								+		'				VarDesc		, '
								+						SUBSTRING(@vchFieldListDetail, 3, LEN(@vchFieldListDetail)) + ', '
								+		'				TotalPPM	, '
								+		'				TotalMetCrit, '
								+		'				Border2 	  '
								+		'		FROM	#NormPPMRptFinalResultSetDetail '
								+		'	ORDER BY	MajorGroupId, PUGDesc, VarDesc '
				-------------------------------------------------------------------------------------------------------
				--	EXECUTE SQL
				-------------------------------------------------------------------------------------------------------
				EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
			END
			ELSE
			BEGIN
				SET	@nvchSQLCommand = 	'		SELECT 	Border1, '
								+		'				MajorGroupId, '
								+		'				PugDesc, '
								+		'				VarDesc, '
								+						SUBSTRING(@vchFieldListDetail, 3, LEN(@vchFieldListDetail)) + ', '
								+		'				TotalPPM, '
								+		'				TotalMetCrit, '
								+		'				SpecVersion, '
								+		'				Border2 '
								+		'		FROM	#NormPPMRptFinalResultSetDetail '
								+		'	ORDER BY	MajorGroupId, PUGDesc, VarDesc, SpecVersion '
				-------------------------------------------------------------------------------------------------------
				--	EXECUTE SQL
				-------------------------------------------------------------------------------------------------------
				EXECUTE sp_ExecuteSQL 	@SQLString = @nvchSQLCommand
			END
		END
	END
	ELSE IF @p_vchRptLayoutOption	= 'VASReport'
	BEGIN 
		--=============================================================================================================
		--	VAS REPORT RESULT SETS
		--=============================================================================================================
		--=============================================================================================================
		IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
		IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Report SUMmary Section'
		--=============================================================================================================
		--	Prepare SUMmary result set
		--	a. Get SUMmary values for Aool PPM
		--	b. Get SUMmary values for Pool PPM
		--	c. Get SUMmary Total PPM
		--	d. Calculate MetCrit PPass
		--	e. Add Met Crit PPass to VAS SUMmary
		--	f.	Loop through Major Groups and Prepare Final Result set for VAS SUMmary
		---------------------------------------------------------------------------------------------------------------	
		--	a. Get SUMmary values for Aool PPM
		---------------------------------------------------------------------------------------------------------------	
		INSERT INTO	@tblVASRptSUMmary	(
					MajorGroupId,
					PUGDesc,
					CalcPPMAoolContribution,
					ObsUCIPPMContribution,
					TotalPPM,
					TotalSampleCOUNT,
					TotalDefectCOUNT )
		SELECT	vas.MajorGroupId,
				vas.PUGDesc,
				SUM(CalcPPMAoolContribution),
				SUM(ObsUCIPPMContribution),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(ObsUCIPPMContribution) ELSE SUM(CalcPPMAoolContribution) END),
				-- CONVERT(INTEGER, ROUND((SUM(SampleCOUNT) * 1.0)/(COUNT(VarGroupId) * 1.0), 0)),
				MAX (SampleCount) ,--(SUMVolumeCount),
				SUM(DefectCOUNT)
		FROM	@tblVASRptVarAttributes			vas
		GROUP BY	vas.MajorGroupId, vas.PUGDesc
	 	ORDER BY 	vas.PUGDesc

		---------------------------------------------------------------------------------------------------------------	
		--	b. Get SUMmary values for Pool PPM
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblVASRptSUMmary	(
					MajorGroupId,
					PUGDesc,
					CalcPPMAoolContribution,
					CalcPPMPoolContribution,
					CalcUCIPPMContribution,
					ObsUCIPPMContribution,
					TotalPPM,
					TotalSampleCOUNT,
					TotalDefectCOUNT )
		SELECT	vas.MajorGroupId,
				vas.PUGDesc,
				SUM(CalcPPMAoolContribution),
				SUM(CalcPPMPoolContribution),
				SUM(CalcUCIPPMContribution),
				SUM(ObsUCIPPMContribution),
				(CASE WHEN @intEnableVirtualZero = 1 THEN SUM(CalcUCIPPMContribution) ELSE SUM(CalcPPMPoolContribution) END),
				MAX(SampleCOUNT),					-- FO-00800
				SUM(DefectCOUNT)
		FROM	@tblVASRptVarStatistics			vas
		GROUP BY	vas.MajorGroupId, vas.PUGDesc
		ORDER BY 	vas.PUGDesc	

--		UPDATE @tblVASRptSUMmary
--				SET TotalSampleCount = (select SUM(ISNULL(TempMajorGroupSampCountAttr,0) + ISNULL(TempMajorGroupSampCountVar,0))
--										FROM @TempMajorGroupVolumeCount		sc		WHERE	vas.MajorGroupId = sc.MajorGroupId
--														AND vas.PUGDesc = sc.PUGDesc)
--		FROM @tblVASRptSUMmary vas



		---------------------------------------------------------------------------------------------------------------
		--	b. Get SUMmary Total PPM
		---------------------------------------------------------------------------------------------------------------
		INSERT INTO	@tblVASRptSUMmary	(
					MajorGroupId,
					PUGDesc,
					CalcPPMAoolContribution,
					CalcPPMPoolContribution,
					CalcUCIPPMContribution,
					ObsUCIPPMContribution,
					TotalPPM,
					TotalSampleCOUNT,
					TotalDefectCOUNT )
		SELECT	vas.MajorGroupId,
				'SUMmaryTotal',
				SUM(CalcPPMAoolContribution),
				SUM(CalcPPMPoolContribution),
				SUM(CalcUCIPPMContribution),
				SUM(ObsUCIPPMContribution),
				SUM(TotalPPM),
				SUM(TotalSampleCOUNT),
				SUM(TotalDefectCOUNT)
		FROM	@tblVASRptSUMmary	vas
		GROUP BY	vas.MajorGroupId

--		2010-10-22 : Comented out, this seems to be causing an issue in the VAS
--		UPDATE  @tblVASRptSUMmary
--			SET TotalSampleCOUNT = (SELECT MajorGroupVolumeCount
--									FROM   #MajorGroupList	 		
--									WHERE  MajorGroupId = vas.MajorGroupId )
--		FROM @tblVASRptSUMmary vas
--		WHERE PUGDesc = 'SUMmaryTotal'
		---------------------------------------------------------------------------------------------------------------
		--	c. Get SUMmary Total Production
		---------------------------------------------------------------------------------------------------------------
		IF @intRptVolumeWeightOption = 0
		BEGIN
			INSERT INTO	@tblVASRptSUMmary	(
						MajorGroupId,
						PUGDesc,
						CalcPPMAoolContribution	
											)
			SELECT	mgl.MajorGroupId,
					'TotalProdCOUNT',
					MajorGroupVolumeCount
			FROM	#MajorGroupList mgl
			JOIN	@tblVASRptSUMmary vs ON mgl.MajorGroupId = vs.MajorGroupId
			GROUP BY	mgl.MajorGroupId,MajorGroupVolumeCount
		END
		ELSE
		BEGIN

			INSERT INTO	@tblVASRptSUMmary	(
						MajorGroupId,
						PUGDesc,
						CalcPPMAoolContribution	)
			SELECT	mgl.MajorGroupId,
					'TotalSampleCOUNT',
					MajorGroupVolumeCount
					-- TotalSampleCOUNT
			FROM	#MajorGroupList mgl
			JOIN	@tblVASRptSUMmary vs ON mgl.MajorGroupId = vs.MajorGroupId
			GROUP BY	mgl.MajorGroupId,MajorGroupVolumeCount
			-- FROM	@tblVASRptSUMmary
			-- WHERE PUGDesc LIKE 'SUMmaryTotal'
			-- GROUP BY	MajorGroupId,TotalSampleCOUNT
		END
		---------------------------------------------------------------------------------------------------------------
		--	d. Calculate MetCrit PPass
		--  Do the same that for PPM Report
		---------------------------------------------------------------------------------------------------------------
		IF @intEnableVirtualZero = 0
		BEGIN
			-- If it has Volume
			IF @intRptVolumeWeightOption = 0
			BEGIN
					INSERT INTO	@tblMetCritPPassAvg (
										MajorGroupId,
										PUGDesc,
										MetCritPPass )
							SELECT		cp.MajorGroupId,
										pg.PUG_Desc + ' (#)',
										SUM((cp.MetCritActual * cp.VolumeCount) / ma.MajorGroupVolumeCount / cp.MetCritVarCountByProdGroup)
							FROM	#CalcPPM		cp
								JOIN	#MajorGroupList	ma	ON 	cp.MajorGroupId = ma.MajorGroupId
								JOIN	dbo.PU_Groups 	pg	WITH (NOLOCK)
															ON 	cp.PUGId = pg.PUG_Id
							WHERE	cp.MetCritActual IS NOT NULL
								AND	ma.MajorGroupVolumeCount		> 0
								AND	cp.MetCritVarCountByProdGroup	> 0
							GROUP BY	cp.MajorGroupId, pg.PUG_Desc
			END
			ELSE
			BEGIN
					INSERT INTO	@tblMetCritPPassAvg (
										MajorGroupId,
										PUGDesc,
										MetCritPPass )
							SELECT		cp.MajorGroupId,
										pg.PUG_Desc + ' (#)',
										AVG(CONVERT(FLOAT,cp.MetCritActual))
							FROM	#CalcPPM		cp
								JOIN	#MajorGroupList	ma	ON 	cp.MajorGroupId = ma.MajorGroupId
								JOIN	dbo.PU_Groups 	pg	WITH (NOLOCK)
															ON 	cp.PUGId = pg.PUG_Id
							WHERE	cp.MetCritActual IS NOT NULL
								AND	ma.MajorGroupVolumeCount		> 0
								AND	cp.MetCritVarCountByProdGroup	> 0
							GROUP BY	cp.MajorGroupId, pg.PUG_Desc
			END	
		END
		ELSE
		BEGIN
			-- If it has Volume
			IF @intRptVolumeWeightOption = 0
			BEGIN
					INSERT INTO	@tblMetCritPPassAvg (
								MajorGroupId,
								PUGDesc,
								MetCritPPass )
					SELECT		MajorGroupId,
								PUGDesc ,
								SUM(PassesVirtualZero) /COUNT(*)							
					FROM	@tblVASRptVarAttributes
					GROUP BY    MajorGroupId,
								PUGDesc

					INSERT INTO	@tblMetCritPPassAvg (
								MajorGroupId,
								PUGDesc,
								MetCritPPass )					
					SELECT		MajorGroupId,
								PUGDesc ,
								SUM(MetCritActual) /COUNT(*)		
					FROM        @tblVASRptVarStatistics
					GROUP BY    MajorGroupId,
								PUGDesc
			END
			ELSE
			BEGIN
					-- And Sample Count
					INSERT INTO	@tblMetCritPPassAvg (
								MajorGroupId,
								PUGDesc,
								MetCritPPass )
					SELECT		MajorGroupId	,
								PUGDesc			,
								AVG(PassesVirtualZero)							
					FROM	@tblVASRptVarAttributes
					GROUP BY    MajorGroupId,
								PUGDesc

					INSERT INTO	@tblMetCritPPassAvg (
								MajorGroupId,
								PUGDesc,
								MetCritPPass )					
					SELECT		MajorGroupId	,
								PUGDesc			,
								AVG(MetCritActual)	
					FROM        @tblVASRptVarStatistics
					GROUP BY    MajorGroupId,
								PUGDesc
			END
		END

		--	SELECT '@tblVASRptVarAttributes',* FROM @tblVASRptVarAttributes
		--	SELECT '@tblVASRptVarStatistics',* FROM @tblVASRptVarStatistics
		---------------------------------------------------------------------------------------------------------------
		--	e. Add Met Crit PPass to VAS SUMmary
		---------------------------------------------------------------------------------------------------------------
		UPDATE	vs 
			SET	vs.MetCritPPass = mc.MetCritPPass
		FROM	@tblVASRptSUMmary 		vs
			JOIN	@tblMetCritPPassAvg	mc	ON	vs.MajorGroupId = mc.MajorGroupId
											AND	vs.PUGDesc 		= mc.PUGDesc	
		---------------------------------------------------------------------------------------------------------------
		--	f.	Loop through Major Groups and Prepare Final Result set for VAS SUMmary
		---------------------------------------------------------------------------------------------------------------
		--		Initialize variables
		---------------------------------------------------------------------------------------------------------------
		SELECT	@j = 1,
				@intMajorGroupId = 1,
				@intMAXMajorGroupId = MAX(MajorGroupId)
		FROM	#MajorGroupList
		---------------------------------------------------------------------------------------------------------------
		--		Loop through Major Groups
		---------------------------------------------------------------------------------------------------------------
		WHILE	@j <= @intMAXMajorGroupId
		BEGIN
			-----------------------------------------------------------------------------------------------------------
			--	Get MajorGroupId
			-----------------------------------------------------------------------------------------------------------
			SELECT	@intMajorGroupId = MajorGroupId				
			FROM	#MajorGroupList
			WHERE	MajorGroupId = @j
			-----------------------------------------------------------------------------------------------------------
			--	Get Record COUNT
			-----------------------------------------------------------------------------------------------------------
			SELECT		@i = 0
			SELECT		@i = COUNT(*) 
				FROM 	@tblVASRptSUMmary
				WHERE	MajorGroupId = @intMajorGroupId
			-----------------------------------------------------------------------------------------------------------
			--	Add records to VAS SUMmary final result set
			-----------------------------------------------------------------------------------------------------------
			IF	@i > 0
			BEGIN
			INSERT INTO	@tblVASRptSUMmaryFinalRS (
						Border1					,
						MajorGroupId			,
						DummyCol3				,
						PUGDesc					,
						CalcPPMAoolContribution	,	-- Weighted SUM
						ObsUCIPPMContribution		,						
						--DummyCol6				,
						CalcPPMPoolContribution	,	-- Weighted SUM
						CalcUCIPPMContribution		,
						DummyCol8 	,	
						MetCritPPass			,
						TotalPPM				,
						TotalSampleCOUNT		,
						TotalDefectCOUNT		,
						DummyCol13				,
						DummyCol14				,
						DummyCol15				,
						DummyCol16				,								
						DummyCol17				,								
						DummyCol18				,								
						DummyCol19				,
						DummyCol20				,
						DummyCol21				,
						DummyCol22				,
						DummyCol23				,
						DummyCol24				,
						DummyCol25				,
						DummyCol26				,
						DummyCol27				,
						DummyCol28				,
						DummyCol29				,
						Border2					)
			SELECT		Border1,
						MajorGroupId,
						DummyCol3,
						PUGDesc,
						CalcPPMAoolContribution,
						ObsUCIPPMContribution		,
						--DummyCol6,
						CalcPPMPoolContribution,
						CalcUCIPPMContribution		,
						DummyCol8,
						MetCritPPass,
						TotalPPM,
						TotalSampleCOUNT,
						TotalDefectCOUNT,
						DummyCol13,
						DummyCol14,
						DummyCol15,
						DummyCol16,
						DummyCol17,
						DummyCol18,
						DummyCol19,
						DummyCol20,
						DummyCol21,
						DummyCol22,
						DummyCol23,
						DummyCol24,
						DummyCol25,
						DummyCol26,
						DummyCol27,
						DummyCol28,
						DummyCol29,
						Border2
				FROM	@tblVASRptSUMmary
				WHERE	MajorGroupId = @intMajorGroupId
			END
			ELSE
			BEGIN
				INSERT INTO	@tblVASRptSUMmaryFinalRS (
								MajorGroupId	,
								PUGDesc			)
					SELECT		@intMajorGroupId,
								PUGDesc
						FROM	@tblVASRptSUMmary
					GROUP BY	PUGDesc
			END
			-----------------------------------------------------------------------------------------------------------
			--	Increment COUNTer
			-----------------------------------------------------------------------------------------------------------
			SET	@j = @j + 1
		END
		---------------------------------------------------------------------------------------------------------------
		-- Return Result Set
		---------------------------------------------------------------------------------------------------------------	
		SELECT * FROM @tblVASRptSUMmaryFinalRS
		--=============================================================================================================
		IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
		IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Report Attribute Section'
		--=============================================================================================================
		-- RS4: Only return variables with defects
		---------------------------------------------------------------------------------------------------------------		
		IF	@intRptVariableVisibility = 1	
		BEGIN
			DELETE	
				FROM	@tblVASRptVarAttributes 
				WHERE	ISNULL(ROUND(CalcPPMAoolContribution, 0), 0) = 0
		END
		---------------------------------------------------------------------------------------------------------------		
		-- All Variable Attributes
		---------------------------------------------------------------------------------------------------------------		
		SELECT	@j = 1,
				@intMajorGroupId = 1,
				@intMAXMajorGroupId = MAX(MajorGroupId)
		FROM	#MajorGroupList
		---------------------------------------------------------------------------------------------------------------		
		WHILE	@j <= @intMAXMajorGroupId
		BEGIN
			SELECT	@intMajorGroupId = MajorGroupId				
			FROM	#MajorGroupList
			WHERE	MajorGroupId = @j
			-----------------------------------------------------------------------------------------------------------		
			SELECT		@i = 0
			SELECT		@i = COUNT(*) 
				FROM 	@tblVASRptVarAttributes
				WHERE	MajorGroupId = @intMajorGroupId
			-----------------------------------------------------------------------------------------------------------
			-- IF @intPRINTFlag = 1	PRINT	'		@intMajorGroupId = ' + CONVERT(VARCHAR, @intMajorGroupId)
			-- IF @intPRINTFlag = 1	PRINT	'		Record COUNT = ' + CONVERT(VARCHAR, @i)
			-----------------------------------------------------------------------------------------------------------

			IF	@i > 0
			BEGIN
				INSERT INTO	@tblVASRptVarAttributesFinalRS	(
							Border1					,
							MajorGroupId			,
							PUGDesc					,
							VarDesc					,
							CalcPPMAoolContribution	,	
							ObsUCIPPMContribution		,
							-- DummyCol6				,
--							DummyCol7				,
							DummyCol8				,
							PassesVirtualZero		,
							PercentTarget			,
							TotalPPM				,
							SampleCOUNT				,
							DefectCOUNT				,
							LSL						,
							DummyCol14				,
							Target					,
							DummyCol16				,								
							USL						,								
							TestMIN					,								
							TEstMAX					,
							TestAvg					,
							TestStDev				,
							DummyCol22				,
							DummyCol23				,
							DummyCol24				,
							DummyCol25				,
							DummyCol26				,
							DummyCol27				,
							SubGroupSize			,
							SpecVersion				,
							Border2					)	
				SELECT		Border1,
							MajorGroupId,
							PUGDesc,
							VarDesc,
							CalcPPMAoolContribution,
							ObsUCIPPMContribution		,
							-- DummyCol6,
--							DummyCol7,
							DummyCol8,
							(CASE WHEN @intEnableVirtualZero = 1 THEN PassesVirtualZero ELSE NULL END)	,
							PercentTarget,
							--(CASE WHEN @intEnableVirtualZero = 1 THEN PassesVirtualZero ELSE PercentTarget END)	,
							TotalPPM		,
							SampleCOUNT		,
							DefectCOUNT		,
							LSL				,
							DummyCol14		,
							Target			,
							DummyCol16		,
							USL				,
							TestMIN			,
							TestMAX			,
							TestAvg			,
							TestStDev		,
							DummyCol22		,
							DummyCol23		,
							DummyCol24		,
							DummyCol25		,
							DummyCol26		,
							DummyCol27		,
							SubGroupSize	,
							SpecVersion		,
							Border2
					FROM	@tblVASRptVarAttributes
					WHERE	MajorGroupId = @intMajorGroupId
			END
			ELSE
			BEGIN
				INSERT INTO	@tblVASRptVarAttributesFinalRS (
							MajorGroupId,
							VarDesc )
				SELECT	MajorGroupId,
							CASE	WHEN	@intRptVariableVisibility = 1
									THEN	'<< NO VARIABLES WITH DEFECTS >>'
									ELSE	'<< NO DATA >>'
									END
				FROM	#MajorGroupList
				WHERE	MajorGroupId = @intMajorGroupId
			END
			-----------------------------------------------------------------------------------------------------------
			--	INCREMENT COUNTer
			-----------------------------------------------------------------------------------------------------------
			SET @j = @j + 1
		END
		---------------------------------------------------------------------------------------------------------------
		--	Return resultset
		---------------------------------------------------------------------------------------------------------------

		SELECT	*	
		FROM		@tblVASRptVarAttributesFinalRS
		ORDER BY	PugDesc, VarDesc
		--=============================================================================================================
		IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
		IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Report Statistic Section'
		--=============================================================================================================
		PRINT '		.	RS5: Report Variable Statistics ' 
		---------------------------------------------------------------------------------------------------------------
		-- RS5: Report Variable Statistics 
		-- - Only return variables with defects
		---------------------------------------------------------------------------------------------------------------
		IF	@intRptVariableVisibility = 1	
		BEGIN
			DELETE	
			FROM	@tblVASRptVarStatistics 
			WHERE	ISNULL(Round(CalcPPMPoolActual, 0), 0) = 0
				AND		MetCritActual IS NULL
		END		
		---------------------------------------------------------------------------------------------------------------		
		SELECT	@j = 1,
				@intMajorGroupId = 1,
				@intMAXMajorGroupId = MAX(MajorGroupId)
		FROM	#MajorGroupList
		---------------------------------------------------------------------------------------------------------------
		WHILE	@j <= @intMAXMajorGroupId
		BEGIN
			SELECT	@intMajorGroupId = MajorGroupId				
			FROM	#MajorGroupList
			WHERE	MajorGroupId = @j
			-----------------------------------------------------------------------------------------------------------
			SELECT		@i = 0
			SELECT		@i = COUNT(*) 
				FROM 	@tblVASRptVarStatistics
				WHERE	MajorGroupId = @intMajorGroupId
			-----------------------------------------------------------------------------------------------------------
			IF @intPRINTFlag = 1	PRINT	'		@intMajorGroupId = ' + CONVERT(VARCHAR, @intMajorGroupId)
			IF @intPRINTFlag = 1	PRINT	'		Record COUNT = ' + CONVERT(VARCHAR, @i)
			-----------------------------------------------------------------------------------------------------------
			-- CalcPPMAoolContribution		FLOAT,	-- Weighted SUM
			-- CalcPPMPoolActual			FLOAT,	-- Will hold the ObsUCIPPMContribution	if VZ Enabled
			-- CalcPPMPoolContribution		FLOAT,	-- Weighted SUM
			-- CalcUCIPPM					FLOAT,	-- To hold the UCI PPM if VzEnabled 

			IF	@i > 0
			BEGIN
				IF	@intRptWeightSpecChanges = 1 
				BEGIN
					INSERT INTO	@tblVASRptVarStatisticsFinalRS (
								Border1,
								MajorGroupId,
								PUGDesc,
								VarDesc,
								CalcPPMAoolContribution,
								CalcPPMPoolActual,
								CalcPPMPoolContribution,
								CalcUCIPPM			,
								MetCritActual,
								MetCritPPass,
								TotalPPM,
								SampleCOUNT,
								DefectCOUNT,
								LSL,
								LTL,
								Target,
								UTL,
								USL,
								TestMIN,
								TestMAX,
								TestAvg,
								TestStDev,
								Tz,
								Cr,
								Cpk,
								MetCritTz,
								MetCritCr,
								MetCritCpk,
								SubGroupSize,
								SpecVersion,
								Border2)
					SELECT		Border1,
								MajorGroupId,
								PUGDesc,
								VarDesc,
								CalcPPMAoolContribution,
								(CASE WHEN @intEnableVirtualZero = 1 THEN ObsUCIPPMContribution ELSE CalcPPMPoolActual END),
								CalcPPMPoolContribution,
								CalcUCIPPM			,
								MetCritActual	,
								MetCritPPass,
								TotalPPM,
								SampleCOUNT,
								DefectCOUNT,
								LSL,
								LTL,
								Target,
								UTL,
								USL,
								TestMIN,
								TestMAX,
								TestAvg,
								TestStDev,
								Tz,
								Cr,
								COALESCE(Cpk, CalcCpk),
								MetCritTz,
								MetCritCr,
								MetCritCpk,
								SubGroupSize,
								Null,
								Border2 	
					FROM		@tblVASRptVarStatistics
					WHERE		MajorGroupId = @intMajorGroupId
					ORDER BY 	PUGDesc, VarDesc
				END
				ELSE
				BEGIN
					INSERT INTO	@tblVASRptVarStatisticsFinalRS (
								Border1,
								MajorGroupId,
								PUGDesc,
								VarDesc,
								CalcPPMAoolContribution,
								CalcPPMPoolActual,
								CalcPPMPoolContribution,
								CalcUCIPPM			,
								MetCritActual,
								MetCritPPass,
								TotalPPM,
								SampleCOUNT,
								DefectCOUNT,
								LSL,
								LTL,
								Target,
								UTL,
								USL,
								TestMIN,
								TestMAX,
								TestAvg,
								TestStDev,
								Tz,
								Cr,
								Cpk,
								MetCritTz,
								MetCritCr,
								MetCritCpk,
								SubGroupSize,
								SpecVersion,
								Border2)
					SELECT		Border1,
								MajorGroupId,
								PUGDesc,
								VarDesc,
								CalcPPMAoolContribution,
								(CASE WHEN @intEnableVirtualZero = 1 THEN ObsUCIPPMContribution ELSE CalcPPMPoolActual END),
								CalcPPMPoolContribution,
								CalcUCIPPM			,
								MetCritActual,
								MetCritPPass,
								TotalPPM,
								SampleCOUNT,
								DefectCOUNT,
								LSL,
								LTL,
								Target,
								UTL,
								USL,
								TestMIN,
								TestMAX,
								TestAvg,
								TestStDev,
								Tz,
								Cr,
								COALESCE(Cpk, CalcCpk),
								MetCritTz,
								MetCritCr,
								MetCritCpk,
								SubGroupSize,
								SpecVersion,
								Border2 	
					FROM	@tblVASRptVarStatistics
					WHERE	MajorGroupId = @intMajorGroupId
					ORDER BY 	PUGDesc, VarDesc
				END
			END
			ELSE
			BEGIN
				INSERT INTO		@tblVASRptVarStatisticsFinalRS (
								MajorGroupId,
								VarDesc )
					SELECT		MajorGroupId,
								'<< NO DATA >>'
						FROM	#MajorGroupList
						WHERE	MajorGroupId = @intMajorGroupId						
			END
			-----------------------------------------------------------------------------------------------------------
			--	Increment COUNTer
			-----------------------------------------------------------------------------------------------------------		
			SET @j = @j + 1
		END
		---------------------------------------------------------------------------------------------------------------
		--	Return resultset
		---------------------------------------------------------------------------------------------------------------
		SELECT * FROM @tblVASRptVarStatisticsFinalRS
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Data Validation'
	--=================================================================================================================
	IF	@intRptWithDataValidation = 1
	BEGIN
		IF	CHARINDEX('ProdId', @vchRptMinorGroupBy) > 0 
		BEGIN
			SELECT	DISTINCT
					cp.CalcPPMId		,
					cp.MajorGroupId		,
					cp.MinorGroupId		,
					cp.PLId				,
					pl.PL_Desc PLDesc	,
					cp.PUGId			,
					pg.PUG_Desc PUGDesc	,
					cp.ProductGrpId		,
					pd.Product_Grp_Desc ProductGrpDesc,
					cp.ProdId			,
					p.Prod_Code			ProductCode,				
					cp.PODesc			PO,
					cp.VarGroupId		,
					cp.VarDescRpt		,
					cp.IsOffLineQuality ,
					cp.LEL				,
					cp.LSL				,
					CASE	WHEN	ds.TzFlag = 1
							THEN	cp.Target		
							ELSE	NULL
							END	Target	,		
					cp.TargetRpt		,
					cp.USL				,
					cp.UEL				,
					cp.LTL				,	-- Lower target limit
					cp.UTL				,	-- Upper target limit
					cp.ExpectedTarget	,
					cp.DegOfFreedom				,
					cp.ChiSquarePPMSlice		,	-- SUM of ChiSquareBin
					cp.ChiSquareCriticalValue	,	-- From look-up table @tblChiSquareCriticalValues
					cp.IsNonNormal,
					cp.IsNonNormalReclassification	,
					ds.TzFlag			,
					cp.SpecVersion		,
					cp.CalcPPMAoolActual,
					cp.CalcPPMAoolContribution	,
					cp.CalcPPMPoolActual		,
					cp.CalcPPMPoolContribution	, 
					cp.MetCritActual		,
					cp.MetCritContribution	,
					cp.VolumeCount				,
					mi.MinorGroupVolumeCount	,
					ma.MajorGroupVolumeCount	,
					cp.SUMVolumeCount			,
					cp.VarCount				,
					cp.MetCritVarCountByProdGroup,
					cp.SampleLessThanFlag	,
					cp.HistDataNotFoundFlag	,
					cp.IncludePool			,
					cp.TestFail				,
					cp.TestCount			,
					cp.TestCountReal		,
					cp.TestCountHist		,
					cp.TestMIN				,
					cp.TestMAX				,
					cp.TestAvg				,
					cp.TestStDev			,
					cp.TempXl				,
					cp.TempXu				,
					cp.TempTl				,
					cp.TempTu				,
					cp.ZLower				,
					cp.ZUpper				,
					cp.MCUSL				,
					cp.MCLSL				,
					cp.MCTarget				,
					cp.MCTargetRange		,
					cp.MCSymmetricSpecs		,
					cp.MCFormulaId			,
					CASE	WHEN	cp.InfinityFlagCr = 1
							THEN	'8'
							WHEN	cp.IsNonNormal = 1
							THEN	'N/A'
							ELSE	CONVERT(VARCHAR(50), cp.Cr)
					END	Cr					,
					cp.MCCr					,
					CASE	WHEN	cp.InfinityFlagTz = 1
							THEN	'8'
							ELSE	CONVERT(VARCHAR(50), cp.Tz)
					END	Tz					,
					cp.MCTz					,
					CASE	WHEN	cp.InfinityFlagCpk = 1
							THEN	'8'
							WHEN	cp.IsNonNormal = 1 -- 0
							THEN	'N/A'
							ELSE	CONVERT(VARCHAR(50), cp.Cpk)
					END	Cpk					,
					cp.MCCpk				,
					cp.CalcCpk			
			FROM	#CalcPPM				cp
				JOIN	dbo.PU_Groups 		pg 	WITH (NOLOCK)
												ON 	pg.PUG_Id 		= cp.PUGId
				JOIN	dbo.Prod_Lines_Base		pl	WITH (NOLOCK)
												ON	pl.PL_Id		= cp.PLId
				JOIN	dbo.Product_Groups	pd	WITH (NOLOCK)
												ON	cp.ProductGrpId = pd.Product_Grp_Id
				JOIN	dbo.Products_Base		p	WITH (NOLOCK)
												ON	cp.ProdId 		= p.Prod_Id
				JOIN	#MinorGroupList		mi 	ON	mi.MinorGroupId = cp.MinorGroupId
				JOIN	#MajorGroupList		ma 	ON	ma.MajorGroupId = cp.MajorGroupId
				JOIN	#ListDataSource		ds 	ON	ds.VarGroupId	= cp.VarGroupId
			ORDER BY	cp.PLId, pg.PUG_Desc, cp.VarGroupId, cp.VarDescRpt
		END
		ELSE
		BEGIN
			SELECT	DISTINCT 
					cp.CalcPPMId		,
					cp.MajorGroupId		,
					cp.MinorGroupId		,
					cp.PLId				,
					pl.PL_Desc PLDesc	,
					cp.PUGId			,
					pg.PUG_Desc PUGDesc	,
					cp.ProductGrpId		,
					pd.Product_Grp_Desc ProductGrpDesc,
					cp.PODesc			PO,
					cp.VarGroupId		,
					cp.VarDescRpt		,
					cp.IsOffLineQuality ,
					cp.LEL				,
					cp.LSL				,
					CASE	WHEN	ds.TzFlag = 1
							THEN	cp.Target		
							ELSE	NULL
							END	Target	,		
					cp.TargetRpt		,
					cp.USL				,
					cp.UEL				,
					cp.LTL				,	-- Lower target limit
					cp.UTL				,	-- Upper target limit
					cp.ExpectedTarget	,
					cp.DegOfFreedom				,
					cp.ChiSquarePPMSlice		,	-- SUM of ChiSquareBin
					cp.ChiSquareCriticalValue	,	-- From look-up table @tblChiSquareCriticalValues
					cp.IsNonNormal,
					cp.IsNonNormalReclassification	,
					ds.TzFlag			,
					cp.SpecVersion		,
					cp.CalcPPMAoolActual,
					cp.CalcPPMAoolContribution	,
					cp.CalcPPMPoolActual		,
					cp.CalcPPMPoolContribution	, 
					cp.MetCritActual		,
					cp.MetCritContribution	,
					cp.VolumeCount				,
					-- mi.MinorGroupVolumeCount	,
					-- ma.MajorGroupVolumeCount	,
					cp.MinorGroupVolumeCount	,
					cp.MajorGroupVolumeCount	,
					cp.SUMVolumeCount			,
					cp.VarCount				,
					cp.MetCritVarCountByProdGroup,
					cp.SampleLessThanFlag	,
					cp.HistDataNotFoundFlag	,
					cp.IncludePool			,
					cp.TestFail				,
					cp.TestCount			,
					cp.TestCountReal		,
					cp.TestCountHist		,
					cp.TestMIN				,
					cp.TestMAX				,
					cp.TestAvg				,
					cp.TestStDev			,
					cp.TempXl				,
					cp.TempXu				,
					cp.TempTl				,
					cp.TempTu				,
					cp.ZLower				,
					cp.ZUpper				,
					cp.MCUSL				,
					cp.MCLSL				,
					cp.MCTarget				,
					cp.MCTargetRange		,
					cp.MCSymmetricSpecs		,
					cp.MCFormulaId			,
					CASE	WHEN	cp.InfinityFlagCr = 1
							THEN	'8'
							WHEN	cp.IsNonNormal = 1
							THEN	'N/A'
							ELSE	CONVERT(VARCHAR(50), cp.Cr)
					END	Cr					,
					cp.MCCr					,
					CASE	WHEN	cp.InfinityFlagTz = 1
							THEN	'8'
							ELSE	CONVERT(VARCHAR(50), cp.Tz)
					END	Tz					,
					cp.MCTz					,
					CASE	WHEN	cp.InfinityFlagCpk = 1
							THEN	'8'
							WHEN	cp.IsNonNormal = 1 --0
							THEN	'N/A'
							ELSE	CONVERT(VARCHAR(50), cp.Cpk)
					END	Cpk					,
					cp.MCCpk				,
					cp.CalcCpk			
			FROM	#CalcPPM				cp
				JOIN	dbo.PU_Groups 		pg 	WITH (NOLOCK)
												ON 	pg.PUG_Id 		= cp.PUGId
				JOIN	dbo.Prod_Lines_Base		pl	WITH (NOLOCK)
												ON	pl.PL_Id		= cp.PLId
				JOIN	dbo.Product_Groups	pd	WITH (NOLOCK)
												ON	cp.ProductGrpId = pd.Product_Grp_Id
				JOIN	#MinorGroupList		mi 	ON	mi.MinorGroupId = cp.MinorGroupId
				JOIN	#MajorGroupList		ma 	ON	ma.MajorGroupId = cp.MajorGroupId
				JOIN	#ListDataSource		ds 	ON	ds.VarGroupId	= cp.VarGroupId
			ORDER BY	cp.PLId, pg.PUG_Desc, cp.VarGroupId, cp.VarDescRpt
		END
	END	

	-- OBSOLETE FIELDS
	--cp.TargetRangeSpecId,
	--cp.CharId			,
	--cp.SpecVersionTR	,
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Data Validation Non-Normal Raw Data'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN
		IF	NOT	EXISTS	(	SELECT	CalcPPMId
							FROM	@tblCalcPPMRawData)
		BEGIN
			INSERT INTO	@tblCalcPPMRawData (
						MajorGroupId)
				VALUES	(0)
		END
		---------------------------------------------------------------------------------------------------------------
		SELECT	CalcPPMId		,
				MajorGroupId	,
				MinorGroupId	,
				VarGroupId		,
				ResultRank		,
				Result			,
				ResultTimeStamp	,
				HistTestFlag	,
				h				,
				Adjustedh		,
				LEL				, 	-- Lower Entry Limit
				LSL				,	-- Lower Reject Limit
				Target			,	
				USL				,	-- Upper Reject Limit
				UEL				, 	-- Upper Entry Limit
				LTL				,	-- Lower Target Limit
				UTL				,	-- Upper Target Limit
				SpecVersion		,
				MAXZ			,
				MINZ			,
				MAXT			,
				MINT			,
				NormMAX			,
				NormMIN			,
				NormFactor		,
				TempXl			,
				TempXu			,
				TempTl			,
				TempTu			,
				ZLower			,
				ZUpper			
		FROM	@tblCalcPPMRawData 

	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Non-Normal Distribution Factors'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN
		IF	NOT	EXISTS (	SELECT	MajorGroupId
							FROM	@tblDistributionFactorCalc)
		BEGIN
			INSERT INTO	@tblDistributionFactorCalc (
						MajorGroupId)
			VALUES	(0)
		END
		----------------------------------------------------------------------------------------------------------------
		SELECT	MajorGroupId	,
				MinorGroupId	,
				VarGroupId		,
				VarStDev		,
				VarTestCount	,
				VarR25Rank		,
				VarR75Rank		,
				VarR25Value1	,
				VarR25Value2	,
				VarR25Value		,
				VarR75Value1	,
				VarR75Value2	,
				VarR75Value		,
				r				,
				h				 
		FROM	@tblDistributionFactorCalc 
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> ValidTimeSlices'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN
		SELECT	TimeSliceId						,
				CalcPPMId						,
				VarId							,
				VarSpecActivation				,
				MajorGroupId					,
				MinorGroupId					,
				PLId							,
				PUId							,
				PUGId							,
				PO								,
				VarGroupId						,
				SourcePUId						,
				ProdId							,
				SourceProdId					,
				ProductGrpId					,
				PLStatusId						,
				ShiftDesc						,
				CrewDesc						,
				CONVERT(VARCHAR(25), TimeSliceStart, 120)	TimeSliceStart,
				CONVERT(VARCHAR(25), TimeSliceEnd, 120)		TimeSliceEnd,
				TimeSliceVolumeCount				,	
				TimeSliceProductionType				,
				TimeSliceVolumeCountVarId			,
				TimeSliceVolumeCountVariable		,
				TimeSliceVolumeCountMSUConvFactor	,
				TimeSliceVolumeCountEvent		,
				TestCountResultNOTNULL			,	-- Added to eliMINate slices where test COUNT = 0 
				TestCountResultNULL				,
				TestCountTotal					,
				SpecTestFreq					,
				TestFreq						,
				SamplingInterval				,
				CONVERT(VARCHAR(25), MAXSamplingRadiusStart, 120)	MAXSamplingRadiusStart,
				CONVERT(VARCHAR(25), MAXSamplingRadiusEnd, 120)		MAXSamplingRadiusEnd,
				MSRTestCountResultNOTNULL		,
				MSRTestCountResultNULL			,
				TestValue1						,
				CONVERT(VARCHAR(25), TestValue1TimeStamp, 120)	TestValue1TimeStamp,
				DateDiff1InSec					,			
				TestValue2						,
				CONVERT(VARCHAR(25), TestValue2TimeStamp, 120)	TestValue2TimeStamp,
				DateDiff2InSec					,	
				ClosestTestValue				,
				CONVERT(VARCHAR(25), ClosestTestValueTimeStamp, 120)	ClosestTestValueTimeStamp,
				LEL								,
				LSL								,
				Target							,
				USL								,
				UEL								,
				LTL								,	-- Lower Target Limit
				UTL								,	-- Upper Target Limit
				SpecVersion						,
				IsOfflineQuality				,	-- Flags records that are offline quality
				TimeSliceEliminationFlag		,	-- 0 = No, 1 = Yes
				TimeSliceEliminationReason		,	
				SplitLineStatusFlag				,	-- Used for debugging only: marks records that have been split at line status boundaries
				SplitShiftFlag					,	-- Used for debugging only: marks records that have been split at shift boundaries
				SplitSpecChangeFlag					-- Used for debugging only: marks records that have been split at spec change boundaries
		FROM	#ValidVarTimeSlices

	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> ListDataSource'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN
		---------------------------------------------------------------------------------------------------------------
		--	Get Variable PU Desc
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#ListDataSource
			SET	VarPUIdDesc = PU_Desc
		FROM	#ListDataSource	lds
		JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)	
									ON	lds.VarPUId = pu.PU_Id
		---------------------------------------------------------------------------------------------------------------
		--	Get Variable Source PU Desc (Offline Quality Source)
		---------------------------------------------------------------------------------------------------------------
		UPDATE	#ListDataSource
			SET	VarPUIdSourceDesc = PU_Desc
		FROM	#ListDataSource	lds
		JOIN	dbo.Prod_Units_Base	pu	WITH (NOLOCK)	
									ON	lds.VarPUIdSource = pu.PU_Id
		---------------------------------------------------------------------------------------------------------------
		--	Return Data Source list
		---------------------------------------------------------------------------------------------------------------
		SELECT	* 
		FROM	#ListDataSource
		ORDER BY VarDesc
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> ChiSquareCalculations'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN
		IF NOT EXISTS	(	SELECT	CalcPPMId
							FROM	@tblPercentConfidence)
		BEGIN
			INSERT INTO	@tblPercentConfidence (
						CalcPPMId)
			VALUES	(0)
		END
		---------------------------------------------------------------------------------------------------------------
		SELECT	*
		FROM	@tblPercentConfidence 
	END
	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Historical Data for Sample < logic'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN
		IF	NOT	EXISTS	(	SELECT	CalcPPMId
							FROM	#HistoricalDataValues)
		BEGIN
			INSERT INTO	#HistoricalDataValues (
						CalcPPMId)
			VALUES	(0)
		END
		---------------------------------------------------------------------------------------------------------------
		SELECT	CalcPPMId			,		
				VarId				,
				VarGroupId			,
				Result				,
				CONVERT(VARCHAR(50), ResultOn, 121) ResultOn,
				TimeSliceProdId		,
				CONVERT(VARCHAR(35), TimeSliceStart	, 121) TimeSliceStart	,
				CONVERT(VARCHAR(35), TimeSliceEnd	, 121) TimeSliceEnd		,
				QualityPUId			,
				PLStatusId			,
				HistTestFlag		,
				LEL					,
				LSL					,
				LTL					,
				Target				,
				UTL					,
				USL					,
				UEL					,
				CharId				
		FROM 	#HistoricalDataValues
		ORDER BY CalcPPMId ASC, ResultOn DESC
	END

	--=================================================================================================================
	IF @intPRINTFlag = 1	SET	@intSubSecNumber = @intSubSecNumber + 1
	IF @intPRINTFlag = 1	PRINT CONVERT(VARCHAR(25), @intSecNumber) + '.' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' ResultSet' + CONVERT(VARCHAR(25), @intSubSecNumber) + ' >>> Raw Data Used for Volume Calculation'
	--=================================================================================================================
	IF	@intRptWithDataValidationExtended = 1
	BEGIN	
		IF	@intRptVolumeWeightOption = 0
		BEGIN
			SELECT * FROM #ExcelVolumeCheck
			ORDER BY 	PLId			,
						PUId			,
						ProductGrpId	,
						ProdId			,
						TimeSliceStart			
		END
		ELSE
		BEGIN
			SELECT	DISTINCT 
					cp.CalcPPMId		,
					cp.MajorGroupId		,
					cp.MinorGroupId		,
					cp.PLId				,
					pl.PL_Desc PLDesc	,
					cp.PUGId			,
					pg.PUG_Desc PUGDesc	,
					cp.ProductGrpId		,
					pd.Product_Grp_Desc ProductGrpDesc,
					cp.PODesc			PO,
					cp.VarGroupId		,
					cp.VarDescRpt		,
					cp.IsOfflineQuality			,
					cp.IsAtt	IsAttribute		,
					cp.VolumeCount				,
					cp.MinorGroupVolumeCount	,
					cp.MajorGroupVolumeCount						
			FROM	#CalcPPM				cp
				JOIN	dbo.PU_Groups 		pg 	WITH (NOLOCK)
												ON 	pg.PUG_Id 		= cp.PUGId
				JOIN	dbo.Prod_Lines_Base		pl	WITH (NOLOCK)
												ON	pl.PL_Id		= cp.PLId
				JOIN	dbo.Product_Groups	pd	WITH (NOLOCK)
												ON	cp.ProductGrpId = pd.Product_Grp_Id
				JOIN	#ListDataSource		ds 	ON	ds.VarGroupId	= cp.VarGroupId
			ORDER BY	cp.PLId, pg.PUG_Desc, cp.VarGroupId, cp.VarDescRpt

		END
	END

END
--=====================================================================================================================
--	DEBUGGIN SECTION: COMMENT BEFORE INSTALLATION
--====================================================================================================================
--	Filter tables
-----------------------------------------------------------------------------------------------------------------------
-- SELECT '#MajorGroupList'							, * FROM	#MajorGroupList
-- SELECT '#MinorGroupList'							, * FROM	#MinorGroupList
-- SELECT '#MCFormulaLookUp'						, * FROM	#MCFormulaLookUp ORDER BY MCFormulaId
-- SELECT '@tblListPLFilter'						, * FROM 	@tblListPLFilter	
-- SELECT '@tblListPUFilter'						, * FROM	@tblListPUFilter	ORDER BY PLId, PUId
-- SELECT '@tblListProductFilter'					, * FROM	@tblListProductFilter
-- SELECT '@tblListProductGroupsFilter'				, * FROM	@tblListProductGroupsFilter
-- SELECT '#ListDataSourceFilter'					, * FROM 	#ListDataSourceFilter
-- SELECT '#ListDataSource'							, * FROM	#ListDataSource WHERE VarId IN (188,189,190,185,186,187)
-- SELECT '#ValidVarTimeSlices'						,* FROM 	#ValidVarTimeSlices vts WHERE VarId = 25950
-- SELECT '#ValidVarTimeSlices'						,* FROM 	#ValidVarTimeSlices vts WHERE TimeSliceEliminationFlag = 1
-- SELECT Var_Desc,SPC_Calculation_Type_Id,* FROM Variables WHERE Var_Id IN (188,189,190,185,186,187)
-- SELECT * FROM SPC_Calculation_Types
-- SELECT '@tblListCrewFilter'						, * FROM 	@tblListCrewFilter
-- SELECT '@tblListShiftFilter'						, * FROM 	@tblListShiftFilter
-- SELECT '@tblListPLStatusFilter'					, * FROM 	@tblListPLStatusFilter
-- SELECT '@tblValidTimeSlices'						, * FROM 	@tblValidTimeSlices	ORDER BY PLId, PUId, ProdId, ProductGrpId
-- SELECT DISTINCT '@tblProdPlanPath'				, *	FROM 	@tblProdPlanPath ORDER BY PUId,PPSStartTime
-- SELECT '@tblSchedLineStatus'						, * FROM 	@tblSchedLineStatus
-- SELECT '@tblSpecChangeOverlapList'				, * FROM	@tblSpecChangeOverlapList 
-- SELECT '#MajorMinorVolumeCount'					, * FROM	#MajorMinorVolumeCount
-- SELECT '@tblValidTimeSlicesTestCount'			, * FROM	@tblValidTimeSlicesTestCount
-- SELECT '@tblMajorGroupTemp'						, * FROM	@tblMajorGroupTemp
-- SELECT '@tblVarProductionInterim2'				, * FROM	@tblVarProductionInterim2
--SELECT '#CalcPPM',TestSUMSquaredDev,TestCount, TestStDev,* FROM	#CalcPPM 
--SELECT '#CalcPPM',CalcUCIPPM,* FROM	#CalcPPM cp WHERE VarDescRpt LIKE 'L006%' ORDER BY VarDescRpt
-- SELECT '#CalcPPM',Cr,MCFormulaId,* FROM	#CalcPPM cp WHERE VarDescRpt LIKE 'V041%' ORDER BY VarDescRpt
-- SELECT '#CalcPPM',Cr,MCFormulaId,* FROM	#CalcPPM cp WHERE VarDescRpt LIKE 'V071%' ORDER BY VarDescRpt
-- SELECT '#NormPPMRptFinalResultSetDetailInterim'	, * FROM	#NormPPMRptFinalResultSetDetailInterim 
-- SELECT '#FinalResultSetSUMmaryInterim'			, * FROM	#FinalResultSetSUMmaryInterim
-- SELECT '#NormPPMRptFinalResultSetDetail'			, TotalPPM, TotalMetCrit,* FROM 	#NormPPMRptFinalResultSetDetail 
-- WHERE VarDesc = 'Fac Basis Weight' and PUGDesc = 'Aool Finished Product Quality High (#)'
-- SELECT '@tblListPUFilter'						,* 	FROM	@tblListPUFilter 
-- SELECT '@tblListPLFilter'						,* 	FROM	@tblListPLFilter 
-- SELECT '#ListDataSourceFilter'					,* 	FROM	#ListDataSourceFilter
--=====================================================================================================================
-- Drop tables
--=====================================================================================================================
DROP TABLE	#TempTable	
DROP TABLE	#ListDataSource
DROP TABLE	#ListDataSourceFilter 
DROP TABLE	#MCFormulaLookUp
DROP TABLE	#ValidVarTimeSlices
DROP TABLE	#MajorMinorVolumeCount
DROP TABLE	#MajorGroupList 
DROP TABLE	#MinorGroupList
DROP TABLE	#CalcPPM
DROP TABLE	#HistoricalDataValues
DROP TABLE	#HistoricalDataValuesTemp1
DROP TABLE	#HistoricalDataValuesTemp2
DROP TABLE	#FinalResultSetSUMmaryInterim 
DROP TABLE	#FinalResultSetSUMmary
DROP TABLE  #NonNormalValuesTemp2
DROP TABLE	#NormPPMRptFinalResultSetDetailInterim 
DROP TABLE	#NormPPMRptFinalResultSetDetail
DROP TABLE	#TempValue
DROP TABLE	#TempValue2	
DROP TABLE  #Local_PG_StartEndTime
DROP TABLE  #TempCalcPPMRawData
DROP TABLE  #MajorVolumeCount
DROP TABLE  #ExcelVolumeCheck
--=====================================================================================================================
IF @intPRINTFlag = 1	PRINT 'SP END ' + CONVERT(VARCHAR(50), GETDATE(), 121)
--=====================================================================================================================
SET NOCOUNT OFF
--=====================================================================================================================

GO
GRANT EXECUTE ON [dbo].[spLocal_RptPPMVAS] TO OPDBmanager
GRANT EXECUTE ON [dbo].[spCmn_ReportCollectionParsing] TO OPDBManager 
GRANT EXECUTE ON [dbo].[spLocal_RptRunTime] TO OPDBManager
GRANT EXECUTE ON [dbo].[spLocal_RptPPMVAS] TO RptUser