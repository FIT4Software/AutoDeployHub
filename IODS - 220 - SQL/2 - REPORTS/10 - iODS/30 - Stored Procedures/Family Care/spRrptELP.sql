USE [Auto_opsDataStore]
GO

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
		@SP_Name	= 'spRptELP',
		@Inputs		= 5, 
		@Version	= '1.0.18'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
IF (SELECT COUNT(*) 
		FROM dbo.AppVersions 
		WHERE App_Name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version,
			Modified_On = GETDATE() 
		WHERE App_Name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_Name,
		App_version,
		Modified_On )
	VALUES (	
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
				
DROP PROCEDURE [dbo].[spRptELP]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptELP
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Facundo Sosa - Arido Software
-- Date created			: 2018-10-22
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for ELP Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
--	2018-10-19	v1.0.0		Facundo Sosa 		*Initial development
--							 					Add ELP data grouped by Line and Line/Paper Source
--	2018-10-19	v1.0.1		Facundo Sosa 		Add NPT Status list variable
--												Add	ELP data grouped by Line/Paper Source/UWS 
--	2019-01-08	v1.0.2		Facundo Sosa 		Clean 'TT ' in Line Names
--	2019-03-08	v1.0.3		Facundo Sosa 		Clean 'PP ' in Line Names
--  2019-07-12  v1.0.4		Damian Campana		Add parameters StartTime & EndTime for Filter <User Defined>
--	2019-07-31	v1.0.5		Gustavo Conde		Add UWS GPRID fields to output (parentUWS)
--	2019-08-05	v1.0.6		Pablo Galanzini		Add check by deleteFlag in Ops tables. (Defect Panaya #821)
--	2019-08-13	v1.0.7		Gustavo Conde		Fix 'Paper (ELP' filtering on OpsDB_DowntimeUptime_Data queries 
--	2019-10-11	v1.0.8		Pablo Galanzini		Fix 'Runtime' when PaperRunBy is 'NoAssignedPRID'
--  2019-10-30	v1.0.9		Gonzalo Luc			Fix Fresh, Storage and Total ELP% in summary grid.
--	2019-11-04	v1.0.10		Pablo Galanzini		Fix PaperRuntime in Converters and Paper Machines
--	2020-03-10	v1.0.11		Pablo Galanzini		Fix many KPIs related to PRB0062698 - PRB0065717 (INC5082334 INC4706340 INC4692725 INC4248156 INC4178785 INC5343197)
--	2020-07-07	v1.0.12		Pablo Galanzini		Add PM data in Trend data
--	2020-11-11	v1.0.13		Pablo Galanzini		Fix a bug when the Converting use paper from intermedia line. (PRB0075968 - INC6914732)
--	2020-11-24	v1.0.14		Pablo Galanzini		PRB0076360: ELP Report is missing a filter to avoid the 'NoAssignedPRID' in the Totals
--	2020-12-01	v1.0.15		Pablo Galanzini		FO-04637: Code Change to ELP calculations. ELP calculation will be changed to 
--												(ELP Downtime + ELP Rateloss Downtime) / Paper Runtime. This change will be applied to Fresh, Storage, and Total ELP at all levels of aggregation.
--	2021-01-27				Pablo Galanzini		PRB0078507 - INC7418859: GREEN BAY PLANT - HTML5 Reports: CVTG and PM total ELP do not match
--												Fix a issue for Cause Pivot in Cape-FC
--	2021-01-29				Pablo Galanzini		PRB0078639 - INC7457514: ELP Report Trend Chart has changed. It was fixed.
--	2021-04-06	v1.0.16		Pablo Galanzini		PRB0080896: ELP Summary & Pivot do not match.  Pivot is correct.
--	2021-04-14				Pablo Galanzini		Enlarge the size of the parameter @NPTStatusList to Max to can fit all Line Status in the options of the ELP Report
--	2021-05-20	v1.0.17		Pablo Galanzini		Fix GrandParentPRID only in Green Bay when it has a data wrong 
--												(Ex: GrandParentPRID = 22.85, it must be '13d030b014' --> PM + Team + PMNumberOFF + RoollPosition + JulianDay)
--												Green Bay: ELP Number can be combined on PMs for Combiners and Rewinders (INC8195034 - PRB0082558)
--	2021-06-23	v1.0.18		Pablo Galanzini		The values of 'Paper Runtime' in the tab 'Cause Pivot' will be taken from 'Paper Runtime' in the tab of summary for PMs (PRB0079858)
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================
CREATE PROCEDURE [dbo].[spRptELP]
--DECLARE
	 @strLineId				NVARCHAR(MAX)	
	,@intTimeOption			INT			
	,@NPTStatusList			NVARCHAR(MAX)	= 'All'
	,@dtmStartTime			DATETIME		= NULL
	,@dtmEndTime			DATETIME		= NULL

--WITH ENCRYPTION 
AS
SET NOCOUNT ON

-- --------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------
--	test Lab0018
-- exec [dbo].[spRptELP] '178,216,219,124,124,81,222,83,21,54,23,22', -1, 'All','2020-10-01 06:30:00.0','2020-10-10 06:30:00.0'

-- Old SP
-- Definitions:	select * from report_definitions where report_name like '%ELP%'  
 --EXEC [dbo].[spLocal_RptCvtgELP] '2019-10-29 06:30:00.000', '2019-10-30 13:30:00.000', 'RptCvtgELP_FC04'

-----------------------------------------------------------------------------------
--	DECLARE VARIABLES
-----------------------------------------------------------------------------------
DECLARE
		 @strTimeOption			NVARCHAR(50)
		,@index					INT
		,@StartTimeAux			DATETIME
		,@EndTimeAux			DATETIME
		,@PUIdAux				INT
		,@PLIdAux				INT
		,@dtmProdDayStartAux	DATETIME
		,@i						INT				
		,@j						INT
		,@PUDescAux				NVARCHAR(255)
		,@PLDescAux				NVARCHAR(255)
		,@VSIdAux				INT
		,@VSDescAux				NVARCHAR(255)

-----------------------------------------------------------------------------------
--	DECLARE LOCAL TABLES
-----------------------------------------------------------------------------------
DECLARE @Lines TABLE (		
		RcdIdx				INT IDENTITY,	
		site				NVARCHAR(50),	
		PLId				INT,
		LineDesc			NVARCHAR(50),	
		DeptId				INT,
		DeptDesc			NVARCHAR(50),  -- For Gen IV: Cvtg Tissue/Towel
		IsGenIV				INT DEFAULT 0,
		ShiftStartTime		NVARCHAR(50),	
		StartTime			DATETIME,
		EndTime				DATETIME
)

DECLARE @PMDataCVTG Table (
		RcdIdx				INT IDENTITY,	
		PaperSource			NVARCHAR(50),
		CVTGs				INT)

DECLARE @RawData Table (
		RcdIdx				INT ,	
		PLId				INT,
		PLDesc				NVARCHAR(50),
		PaperSource			NVARCHAR(50),
		PaperSourcePM		NVARCHAR(50),
		PaperRunBy			NVARCHAR(50),
		ParentPLId			INT,
		PM					NVARCHAR(50),
		INTR				NVARCHAR(50),
		UWS					NVARCHAR(50),
		InputOrder			INT,
		ParentPRID			NVARCHAR(50),
		ParentPM			NVARCHAR(50),
		ParentPUDesc		NVARCHAR(50),
		ParentTeam			NVARCHAR(15),
		ParentRollTimestamp	DATETIME,
		ParentRollAge		FLOAT,
		GrandParentFIXED	INT DEFAULT 0,
		GrandParentPRID		NVARCHAR(50),
		GrandParentPM		NVARCHAR(50),
		GrandParentTeam		NVARCHAR(15),
		ProdDesc			NVARCHAR(255),
		EventId				INT,
		SourceId			INT,
		NPTStatus			NVARCHAR(50),
		--
		PRConvStartTime					DATETIME,
		PRConvEndTime					DATETIME,
		PaperRuntime					FLOAT	DEFAULT 0,
		TotalStops						INT		DEFAULT 0,
		TotalRuntime					FLOAT	DEFAULT 0,
		TotalDowntime					FLOAT	DEFAULT 0,
		TotalRateLossDT					FLOAT	DEFAULT 0,
		TotalRolls						INT		DEFAULT 0,
		FreshRolls						INT		DEFAULT 0,
		StorageRolls					INT		DEFAULT 0,
		TotalScheduledDT				FLOAT	DEFAULT 0,
		--
		StartTimeLinePS					DATETIME,
		EndTimeLinePS					DATETIME,
		TotalRuntimeLinePS				FLOAT	DEFAULT 0,
		TotalDowntimeLinePS				FLOAT	DEFAULT 0,
		TotalRateLossDTLinePS			FLOAT	DEFAULT 0,
		TotalFreshStopsLinePS			INT		DEFAULT 0,
		TotalFreshDowntimeLinePS		FLOAT	DEFAULT 0,
		TotalFreshRateLossDTLinePS		FLOAT	DEFAULT 0,
		TotalFreshRuntimeLinePS			FLOAT	DEFAULT 0,
		TotalStorageStopsLinePS			INT		DEFAULT 0,
		TotalStorageDowntimeLinePS		FLOAT	DEFAULT 0,
		TotalStorageRateLossDTLinePS	FLOAT	DEFAULT 0,
		TotalStorageRuntimeLinePS		FLOAT	DEFAULT 0,
		TotalScheduledDTLinePS			FLOAT	DEFAULT 0,
		TotalFreshScheduledDTLinePS		FLOAT	DEFAULT 0,
		TotalStorageScheduledDTLinePS	FLOAT	DEFAULT 0,
		TotalStopsLinePS				INT,
		--	Line grouping columns
		StartTimeLine					DATETIME,
		EndTimeLine						DATETIME,
		TotalRuntimeLine				FLOAT,
		TotalStopsLine					INT,
		TotalDowntimeLine				FLOAT,
		TotalRateLossDTLine				FLOAT,
		TotalScheduledDTLine			FLOAT,
		TotalFreshRuntimeLine			FLOAT,
		TotalFreshStopsLine				INT,
		TotalFreshDowntimeLine			FLOAT,
		TotalFreshRateLossDTLine		FLOAT,
		TotalFreshScheduledDTLine		FLOAT,
		TotalStorageRuntimeLine			FLOAT,
		TotalStorageStopsLine			INT,
		TotalStorageDowntimeLine		FLOAT,
		TotalStorageRateLossDTLine		FLOAT,
		TotalStorageScheduledDTLine		FLOAT
		--	PMRunBy grouping columns
		--StartTimePMRunBy				DATETIME,
		--EndTimePMRunBy					DATETIME,
		--TotalRuntimePMRunBy				FLOAT,
		--TotalStopsPMRunBy				INT,
		--TotalDowntimePMRunBy			FLOAT,
		--TotalRateLossDTPMRunBy			FLOAT,
		--TotalScheduledDTPMRunBy			FLOAT,
		--TotalFreshRuntimePMRunBy		FLOAT,
		--TotalFreshStopsPMRunBy			INT,
		--TotalFreshDowntimePMRunBy		FLOAT,
		--TotalFreshRateLossDTPMRunBy		FLOAT,
		--TotalFreshScheduledDTPMRunBy	FLOAT,
		--TotalStorageRuntimePMRunBy		FLOAT,
		--TotalStorageStopsPMRunBy		INT,
		--TotalStorageDowntimePMRunBy		FLOAT,
		--TotalStorageRateLossDTPMRunBy	FLOAT,
		--TotalStorageScheduledDTPMRunBy	FLOAT
)

DECLARE @RawDataNoAssigned Table (
		RcdIdx				INT ,	
		PLId				INT,
		PLDesc				NVARCHAR(50),
		ParentPLId			INT,
		PM					NVARCHAR(50),
		InputOrder			INT,
		ParentPRID			NVARCHAR(50),
		NPTStatus			NVARCHAR(50),
		PRConvStartTime		DATETIME,
		PRConvEndTime		DATETIME,
		PaperRuntime		FLOAT	DEFAULT 0,
		ScheduledDT			FLOAT	DEFAULT 0		
		)

DECLARE @Summary TABLE	(
		Type								NVARCHAR(10),
		Orden								INT,
		Grouping							NVARCHAR(50),
		PLDesc								NVARCHAR(50),
		PaperLine							NVARCHAR(50),
		UWS									NVARCHAR(50),
		Runtime								FLOAT	DEFAULT 0, 
		PaperStops							INT		DEFAULT 0,
		DTDueToStops						FLOAT	DEFAULT 0,
		EffDTRateLoss						FLOAT	DEFAULT 0,
		TotalPaperDT						FLOAT	DEFAULT 0,
		FreshPaperStops						FLOAT	DEFAULT 0,
		FreshPaperDT						FLOAT	DEFAULT 0,
		FreshPaperRuntime					FLOAT	DEFAULT 0,
		FreshRollsRan						INT		DEFAULT 0,
		StoragePaperStops					FLOAT	DEFAULT 0,
		StoragePaperDT						FLOAT	DEFAULT 0,
		StoragePaperRuntime					FLOAT	DEFAULT 0,
		StorageRollsRan						INT		DEFAULT 0,
		TotalRollsRan						INT		DEFAULT 0,
		FreshELP							FLOAT	DEFAULT 0,
		StorageELP							FLOAT	DEFAULT 0,
		TotalELP							FLOAT
	) 

DECLARE @CausePivot TABLE	(
		Type								NVARCHAR(10),
		Grouping							NVARCHAR(50),
		PLDesc								NVARCHAR(50),
		PaperLine							NVARCHAR(50),
		UWS									NVARCHAR(50),
		Cause								NVARCHAR(500),
		Runtime								FLOAT	DEFAULT 0, 
		PaperStops							INT		DEFAULT 0,
		DTDueToStops						FLOAT	DEFAULT 0,
		EffDTRateLoss						FLOAT	DEFAULT 0,
		TotalPaperDT						FLOAT	DEFAULT 0,
		FreshPaperStops						FLOAT	DEFAULT 0,
		FreshPaperDT						FLOAT	DEFAULT 0,
		FreshEffDTRateLoss					FLOAT	DEFAULT 0,
		FreshPaperRuntime					FLOAT	DEFAULT 0,
		FreshRollsRan						INT		DEFAULT 0,
		StoragePaperStops					FLOAT	DEFAULT 0,
		StoragePaperDT						FLOAT	DEFAULT 0,
		StorageEffDTRateLoss				FLOAT	DEFAULT 0,
		StoragePaperRuntime					FLOAT	DEFAULT 0,
		StorageRollsRan						INT		DEFAULT 0,
		TotalRollsRan						INT		DEFAULT 0,
		FreshELP							FLOAT	DEFAULT 0,
		StorageELP							FLOAT	DEFAULT 0,
		TotalELP							FLOAT	DEFAULT 0,
		ScheduledDT							FLOAT	DEFAULT 0,
		FreshSchedDT						FLOAT	DEFAULT 0,
		StorageSchedDT						FLOAT
	) 

DECLARE @PRSummaryLinePS TABLE (
		CvtgPLID							INT,
		ParentPLId							INT,
		PaperSource							NVARCHAR(50),
		PaperSourcePM						NVARCHAR(50),
		PM									VARCHAR(20),
		Runtime								FLOAT	DEFAULT 0, 
		ScheduledDT							FLOAT	DEFAULT 0, 
		ELPStops							INT		DEFAULT 0,
		ELPDowntime							FLOAT	DEFAULT 0, 
		RLELPDowntime						FLOAT	DEFAULT 0, 
		FreshStops							INT		DEFAULT 0,
		FreshDT								FLOAT	DEFAULT 0, 
		FreshRLELPDT						FLOAT	DEFAULT 0,
		FreshRuntime						FLOAT	DEFAULT 0, 
		FreshRolls							INT		DEFAULT 0,
		StorageStops						INT		DEFAULT 0,
		StorageDT							FLOAT	DEFAULT 0, 
		StorageRLELPDT						FLOAT	DEFAULT 0,
		StorageRolls						INT		DEFAULT 0,
		StorageRuntime						FLOAT	DEFAULT 0, 
		FreshSchedDT						FLOAT	DEFAULT 0, 
		StorageSchedDT						FLOAT	DEFAULT 0, 
		TotalRolls							INT		DEFAULT 0
		) 

DECLARE @PRSummaryUWS TABLE	(
		CvtgPLID							INT,
		PLDesc								NVARCHAR(50),
		PaperSource							NVARCHAR(50),
		PaperSourcePM						NVARCHAR(50),
		PaperRunBy							NVARCHAR(50),
		ParentPLID							INT,
		PaperMachine						NVARCHAR(50),
		INTR								NVARCHAR(50),	
		UWS									NVARCHAR(50),
		InputOrder							INT		DEFAULT 0,	
		Runtime								FLOAT	DEFAULT 0, 
		ScheduledDT							FLOAT	DEFAULT 0, 
		--
		TotalRuntime						FLOAT	DEFAULT 0,				
		TotalScheduledDT					FLOAT	DEFAULT 0,
		--
		ELPStops							INT		DEFAULT 0,
		ELPDowntime							FLOAT	DEFAULT 0, 
		RLELPDowntime						FLOAT	DEFAULT 0, 
		FreshStops							INT		DEFAULT 0,
		FreshDT								FLOAT	DEFAULT 0, 
		FreshRLELPDT						FLOAT	DEFAULT 0,
		FreshRuntime						FLOAT	DEFAULT 0, 
		FreshSchedDT						FLOAT	DEFAULT 0, 
		FreshRolls							INT		DEFAULT 0,
		StorageStops						INT		DEFAULT 0,
		StorageDT							FLOAT	DEFAULT 0, 
		StorageRLELPDT						FLOAT	DEFAULT 0,
		StorageRolls						INT		DEFAULT 0,
		StorageRuntime						FLOAT	DEFAULT 0, 
		StorageSchedDT						FLOAT	DEFAULT 0, 
		TotalRolls							INT		DEFAULT 0
	) 

DECLARE @TrendsData TABLE (
		PM_PLID								INT,
		PM_PLDesc							NVARCHAR(50),
		PLID								INT,
		PLDesc								NVARCHAR(50),
		Date								DATETIME,
		Runtime								FLOAT	DEFAULT 0, 
		ELPStops							INT		DEFAULT 0,
		ELPDowntime							FLOAT	DEFAULT 0, 
		RLELPDowntime						FLOAT	DEFAULT 0, 
		FreshStops							INT		DEFAULT 0,		--	Fresh Stops section
		FreshDT								FLOAT	DEFAULT 0, 
		FreshRLELPDT						FLOAT	DEFAULT 0,
		FreshRuntime						FLOAT	DEFAULT 0, 
		StorageStops						INT		DEFAULT 0,		--	Storage Stops section
		StorageDT							FLOAT	DEFAULT 0, 
		StorageRLELPDT						FLOAT	DEFAULT 0,
		StorageRuntime						FLOAT	DEFAULT 0, 
		ScheduledDT							FLOAT	DEFAULT 0,		--	Scheduled Stops section
		FreshSchedDT						FLOAT	DEFAULT 0, 
		StorageSchedDT						FLOAT	DEFAULT 0
	)

DECLARE @PRSummaryPMRunByCause	TABLE	(
		PLID								INT,
		Cause								NVARCHAR(500),
		PaperRunBy							NVARCHAR(20),
		PaperMachine						NVARCHAR(16),
		PaperSource							NVARCHAR(50),
		Runtime								FLOAT	DEFAULT 0, 
		ELPStops							INT		DEFAULT 0,
		ELPDowntime							FLOAT	DEFAULT 0, 
		RLELPDowntime						FLOAT	DEFAULT 0, 
		FreshStops							INT		DEFAULT 0,
		FreshDT								FLOAT	DEFAULT 0, 
		FreshRLELPDT						FLOAT	DEFAULT 0,
		FreshRuntime						FLOAT	DEFAULT 0, 
		StorageStops						INT		DEFAULT 0,
		StorageDT							FLOAT	DEFAULT 0, 
		StorageRLELPDT						FLOAT	DEFAULT 0,
		StorageRuntime						FLOAT	DEFAULT 0, 
		ScheduledDT							FLOAT	DEFAULT 0, 
		FreshSchedDT						FLOAT	DEFAULT 0, 
		StorageSchedDT						FLOAT	DEFAULT 0, 
		TotalRolls							INT		DEFAULT 0,
		FreshRolls							INT		DEFAULT 0,
		StorageRolls						INT		DEFAULT 0
	)

DECLARE @ELPStops TABLE	(
		TEDetId							INT,
		StartTime						DATETIME,
		EndTime							DATETIME,
		PLId							INT	,
		PLDesc							NVARCHAR(50),
		PUId							INT	,
		PuDesc							NVARCHAR(50),
		Reason2							NVARCHAR(100),
		ParentPLId						INT,
		PaperSource						NVARCHAR(50),
		PM								NVARCHAR(25),
		Duration						FLOAT	DEFAULT 0,
		RateLoss						FLOAT	DEFAULT 0,
		Stop							INT		DEFAULT 0, 
		Fresh							INT DEFAULT 0, 
		MinorStop						INT		DEFAULT 0, 
		Comments						NVARCHAR(1000),
		UWS1							NVARCHAR(50),
		ParentUWS1						NVARCHAR(25),
		UWS2							NVARCHAR(25),
		ParentUWS2						NVARCHAR(25),
		UWS3							NVARCHAR(25),
		ParentUWS3						NVARCHAR(25),
		UWS4							NVARCHAR(25),
		ParentUWS4						NVARCHAR(25),
		Reason1Category					NVARCHAR(500),
		Reason2Category					NVARCHAR(500)
	) 

DECLARE @ProdDay TABLE (
		RcdIdx						INT IDENTITY	,	
		ProdDayId					INT				,					
		PLId						INT				,
		PLDesc						NVARCHAR(255)	,
		ProdDay						DATETIME		,
		StartTime					DATETIME		,
		EndTime						DATETIME		)

-----------------------------------------------------------------------------------
--	GET Lines, Start AND End Time
-----------------------------------------------------------------------------------
INSERT INTO @Lines(PLId)
	SELECT String FROM fnLocal_Split(@strLineId,',')

DELETE L
	FROM @Lines L
	WHERE L.PLId IN (SELECT L.PLId FROM @Lines L2 WHERE L.PLId = L2.PLId AND L.RcdIdx > L2.RcdIdx)

--Set the Start & End Time
IF @intTimeOption = -1
BEGIN
	UPDATE l 
		SET	l.StartTime		= @dtmStartTime, 
			l.EndTime		= @dtmEndTime, 
			l.ShiftStartTime= ld.ShiftStartTime,
			l.LineDesc		= ld.LineDesc -- REPLACE(REPLACE(ld.LineDesc,'TT ', ''),'PP ','')
		FROM @Lines l
		JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON l.PLId = ld.plid
END
ELSE
BEGIN
	SELECT @strTimeOption = DateDesc 
		FROM [dbo].[DATE_DIMENSION] (NOLOCK)
		WHERE DateId = @intTimeOption
	
	--select * from dbo.fnGetStartEndTimeiODS(@strTimeOption, 124) 

	UPDATE l 
		SET	l.StartTime		= f.dtmStartTime, 
			l.EndTime		= f.dtmEndTime, 
			l.ShiftStartTime= ld.ShiftStartTime,
			l.LineDesc		= ld.LineDesc --REPLACE(REPLACE(ld.LineDesc,'TT ', ''),'PP ','')
		FROM @Lines l
		JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON l.plid = ld.plid
		OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption, ld.PLId) f
END

UPDATE L
	SET site		= ld.SiteId,
		DeptId		= ld.deptid,
		DeptDesc	= ld.deptdesc	-- For Gen IV: Cvtg Tissue/Towel
	FROM @Lines l
	JOIN dbo.LINE_DIMENSION ld (NOLOCK) ON l.plid = ld.plid

UPDATE L
	SET IsGenIV = 1
	FROM @Lines l
	WHERE l.DeptDesc like '%Cvtg Tissue/Towel%'

SELECT	@dtmStartTime	= l.starttime, 
		@dtmEndTime		= l.endtime
	FROM @Lines l

--select * from dbo.fnGetStartEndTimeiODS(@strTimeOption,20) f
--select @strTimeOption, @dtmStartTime, @dtmEndTime, DATEDIFF(mi, @dtmStartTime , @dtmEndTime) minutes
--return
 
---------------------------------------------------------------------------------------------------
-- Build Production Day time slices
---------------------------------------------------------------------------------------------------
SET @index = 1
SET @i = 1 --RcdIdx
SELECT @j = COUNT(*) FROM @Lines 

WHILE (@i <= @j)
BEGIN
	SELECT	@StartTimeAux = StartTime	,
			@EndTimeAux = EndTime		,
			@PLIdAux = PLId				,
			@PLDescAux = LineDesc		
		FROM @Lines WHERE RcdIdx = @i

	--SELECT 'CHECK', @StartTimeAux,@EndTimeAux,@PLIdAux,@PLDescAux

	IF(@PLIdAux IS NOT NULL)
	BEGIN
		SET @dtmProdDayStartAux = @StartTimeAux --It already has the start of day
		SET @index = 0

		WHILE (	@dtmProdDayStartAux < @EndTimeAux)--@dtmEndTime )
		BEGIN		
			
			--SELECT 'CHECK2', @PLIdAux, @dtmProdDayStartAux, @EndTimeAux

			INSERT INTO @ProdDay (		
						ProdDayId		,
						StartTime		,
						EndTime			,
						ProdDay			,
						PLId			,
						PLDesc			)
				SELECT	@index			,
						@dtmProdDayStartAux,
						DATEADD(hh,24,@dtmProdDayStartAux),
						CONVERT(VARCHAR(10), @dtmProdDayStartAux, 120),
						@PLIdAux			,
						@PLDescAux
					-- PRB0078639 - INC7457514: ELP Report Trend Chart has changed. It was fixed.
					--WHERE @PLIdAux NOT IN (SELECT PLId FROM @ProdDay WHERE @PLIdAux = PLId AND PRODDAY = CONVERT(VARCHAR(10), @dtmProdDayStartAux, 120))
						
			SET @index = @index + 1
			SET @dtmProdDayStartAux = DATEADD(DAY, 1, @dtmProdDayStartAux)
		END			
	END

	SET @i = @i+1
END

-----------------------------------------------------------------------------------
--	GET ELP Stops
-----------------------------------------------------------------------------------
INSERT INTO @ELPStops(
			PLId		,
			PLDesc		,
			PUId		,
			PuDesc		,
			Reason2		,
			Reason1Category,
			Reason2Category,
			Duration	,
			Stop		,
			MinorStop	,
			Comments	,
			RateLoss	,
			StartTime	,
			EndTime		,
			TEDetId		)
	SELECT	
			d.PLId		,
			REPLACE(REPLACE(d.PLDesc,'TT ', ''), 'PP ',''),
			d.PuId		,
			d.PuDesc,
			d.Reason2, 
			d.Reason1Category,
			d.Reason2Category,
			CASE WHEN d.Location NOT LIKE '%Rate Loss%' THEN d.Duration ELSE 0 END 'Duration', 
			ISNULL(d.StopsELP,0) 'Stop',
			d.MinorStop, 
			d.Comments,
			ISNULL(d.RawRateloss, 0 )/60 'Rateloss',
			d.StartTime,
			d.EndTime, 
			d.TEDetId
	  FROM dbo.OpsDB_DowntimeUptime_Data	d	WITH(NOLOCK)
	  JOIN @Lines							l	ON d.PLId = l.PLId 
												AND d.StartTime <= l.EndTime 
												AND d.EndTime > l.StartTime
	  WHERE d.DeleteFlag = 0
			AND d.IsContraint = 1
			AND (d.Reason2Category like '%Category:Paper (ELP)%' OR d.Reason1Category like '%Category:Paper (ELP)%')
	  --GROUP BY TEDetId, Comments, d.plid, PLDesc, puid, PuDesc, 
			--Reason2, Reason1Category, Reason2Category, Location

-----------------------------------------------------------------------------------------------------------------------
-- Get ELP Raw Data.
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @RawData (
			RcdIdx				,
			PLId				,
			PLDesc				,
			PaperRunBy			,
			ParentPLId			,
			PM					,
			PaperSource			,
			PaperSourcePM		,
			INTR				,
			UWS					,
			EventId				,
			SourceId			,
			ParentPRID			,
			ParentPM			,
			ParentPUDesc		,
			ParentTeam			,
			ParentRollTimestamp	,
			ParentRollAge		,
			GrandParentPRID		,
			GrandParentPM		,
			GrandParentTeam		,
			ProdDesc			,
			InputOrder			,
			TotalStops			,
			TotalDowntime		,
			TotalRateLossDT		,
			TotalRolls			,
			FreshRolls			,
			StorageRolls		,
			TotalScheduledDT	,
			PaperRuntime		,
			PRConvStartTime		,
			PRConvEndTime		,
			--
			StartTimeLinePS		,
			EndTimeLinePS		,
			TotalRuntime		,
			TotalRuntimeLinePS	,
			NPTStatus,
			TotalDowntimeLinePS	,
			TotalRateLossDTLinePS,
			TotalFreshStopsLinePS,
			TotalFreshDowntimeLinePS,
			TotalFreshRateLossDTLinePS,
			TotalFreshRuntimeLinePS,
			TotalStorageStopsLinePS,
			TotalStorageDowntimeLinePS,
			TotalStorageRateLossDTLinePS,
			TotalStorageRuntimeLinePS,
			TotalScheduledDTLinePS,
			TotalFreshScheduledDTLinePS,
			TotalStorageScheduledDTLinePS,
			TotalStopsLinePS,
			--	Line grouping columns
			StartTimeLine				,
			EndTimeLine					,
			TotalRuntimeLine			,
			TotalStopsLine				,
			TotalDowntimeLine			,
			TotalRateLossDTLine			,
			TotalScheduledDTLine		,
			TotalFreshRuntimeLine		,
			TotalFreshStopsLine			,
			TotalFreshDowntimeLine		,
			TotalFreshRateLossDTLine	,
			TotalFreshScheduledDTLine	,
			TotalStorageRuntimeLine		,
			TotalStorageStopsLine		,
			TotalStorageDowntimeLine	,
			TotalStorageRateLossDTLine	,
			TotalStorageScheduledDTLine	
			--	PMRunBy grouping columns
			--StartTimePMRunBy			,
			--EndTimePMRunBy				,
			--TotalRuntimePMRunBy			,
			--TotalStopsPMRunBy			,
			--TotalDowntimePMRunBy		,
			--TotalRateLossDTPMRunBy		,
			--TotalScheduledDTPMRunBy		,
			--TotalFreshRuntimePMRunBy	,
			--TotalFreshStopsPMRunBy		,
			--TotalFreshDowntimePMRunBy	,
			--TotalFreshRateLossDTPMRunBy	,
			--TotalFreshScheduledDTPMRunBy	,
			--TotalStorageRuntimePMRunBy	,
			--TotalStorageStopsPMRunBy	,
			--TotalStorageDowntimePMRunBy	,
			--TotalStorageRateLossDTPMRunBy	,
			--TotalStorageScheduledDTPMRunBy	
			)
	SELECT  
			e.RcdIdx			,
			e.PLId				, 
			REPLACE(REPLACE(PLDesc,'TT ', ''), 'PP ',''),
			PaperRunBy			,
			ParentPLId			,
			PM					,
			PaperSource			,
			PaperSource			,
			INTR				,
			UWS					,
			EventId				,
			SourceId			,
			ParentPRID			,
			ParentPM			,
			ParentPUDesc		,
			ParentTeam			,
			ParentRollTimestamp	,
			ParentRollAge		,
			GrandParentPRID		,
			GrandParentPM		,
			GrandParentTeam		,
			ProdDesc			,
			InputOrder			,
			TotalStops			,
			TotalDowntime		,
			TotalRateLossDT		,
			TotalRolls			,
			FreshRolls			,
			StorageRolls		,
			TotalScheduledDT	,
			PaperRuntime		,
			CASE WHEN PRConvStartTime < l.StartTime
					THEN l.StartTime ELSE PRConvStartTime END,
			CASE WHEN PRConvEndTime > l.EndTime
					THEN l.EndTime ELSE PRConvEndTime END,
			--PRConvStartTime		,
			--PRConvEndTime		,
			--
			CASE WHEN StartTimeLinePS < l.StartTime
					THEN l.StartTime ELSE StartTimeLinePS END,
			CASE WHEN EndTimeLinePS > l.EndTime
					THEN l.EndTime ELSE EndTimeLinePS END,
			--StartTimeLinePS		,
			--EndTimeLinePS		,
			TotalRuntime		,
			TotalRuntimeLinePS	,
			NPTStatus,
			TotalDowntimeLinePS	,
			TotalRateLossDTLinePS,
			TotalFreshStopsLinePS,
			TotalFreshDowntimeLinePS,
			TotalFreshRateLossDTLinePS,
			TotalFreshRuntimeLinePS,
			TotalStorageStopsLinePS,
			TotalStorageDowntimeLinePS,
			TotalStorageRateLossDTLinePS,
			TotalStorageRuntimeLinePS,
			TotalScheduledDTLinePS,
			TotalFreshScheduledDTLinePS,
			TotalStorageScheduledDTLinePS,
			TotalStopsLinePS,
			--	Line grouping columns
			StartTimeLine				,
			EndTimeLine					,
			TotalRuntimeLine			,
			TotalStopsLine				,
			TotalDowntimeLine			,
			TotalRateLossDTLine			,
			TotalScheduledDTLine		,
			TotalFreshRuntimeLine		,
			TotalFreshStopsLine			,
			TotalFreshDowntimeLine		,
			TotalFreshRateLossDTLine	,
			TotalFreshScheduledDTLine	,
			TotalStorageRuntimeLine		,
			TotalStorageStopsLine		,
			TotalStorageDowntimeLine	,
			TotalStorageRateLossDTLine	,
			TotalStorageScheduledDTLine	
			--	PMRunBy grouping columns
			--StartTimePMRunBy			,
			--EndTimePMRunBy				,
			--TotalRuntimePMRunBy			,
			--TotalStopsPMRunBy			,
			--TotalDowntimePMRunBy		,
			--TotalRateLossDTPMRunBy		,
			--TotalScheduledDTPMRunBy		,
			--TotalFreshRuntimePMRunBy	,
			--TotalFreshStopsPMRunBy		,
			--TotalFreshDowntimePMRunBy	,
			--TotalFreshRateLossDTPMRunBy	,
			--TotalFreshScheduledDTPMRunBy,
			--TotalStorageRuntimePMRunBy	,
			--TotalStorageStopsPMRunBy	,
			--TotalStorageDowntimePMRunBy	,
			--TotalStorageRateLossDTPMRunBy,
			--TotalStorageScheduledDTPMRunBy	
		FROM dbo.OpsDB_ELP_Data e	WITH(NOLOCK)
		JOIN @Lines				l	ON e.PLId = l.PLId
									AND e.PRConvStartTime < l.EndTime 
									AND e.PRConvEndTime > l.StartTime
		WHERE e.deleteFlag = 0
			AND (CHARINDEX('|' + NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')
		order by e.PRConvStartTime

--select DISTINCT '@RawData', plid, pldesc, r.PaperSource, PaperSourcePM, r.paperrunby, r.ParentPLId, pm, intr
--	FROM @RawData	r	
--	--where PaperSource <> PaperSourcePM
--	order by r.plid, r.pldesc, r.PaperSource, r.paperrunby, r.ParentPLId, r.pm
--return
-----------------------------------------------------------------------------------------------------------------------
INSERT INTO @RawDataNoAssigned
	SELECT --'OpsDB_ELP_Data', 
			e.RcdIdx			,	
			e.PLId				,
			PLDesc				,
			ParentPLId			,
			PM					,
			InputOrder			,
			ParentPRID			,
			NPTStatus			,
			CASE WHEN PRConvStartTime < l.StartTime THEN l.StartTime ELSE PRConvStartTime END,
			CASE WHEN PRConvEndTime	> l.EndTime THEN l.EndTime ELSE PRConvEndTime END,
			e.PaperRuntime,
			e.TotalScheduledDT
			FROM @RawData			e
			JOIN @Lines				l	ON e.PLId = l.PLId
										AND e.PRConvStartTime <= l.EndTime 
										AND e.PRConvEndTime > l.StartTime


--SELECT '@RawDataNoAssigned', PaperRuntime/60.0 Runtime, * FROM @RawDataNoAssigned
--	ORDER BY PRConvStartTime, PRConvEndTime

----------------------------------------------------------------------------------------------------------------------
DELETE r
	FROM @RawDataNoAssigned r
	WHERE EXISTS (SELECT * FROM @RawDataNoAssigned r1
					WHERE r1.RcdIdx <> r.RcdIdx
						AND r1.PLId = r.plid
						AND r1.PM NOT LIKE 'NoAssignedPRID'
						--AND r.PRConvStartTime < r1.PRConvEndTime 
						--AND r.PRConvEndTime > r1.PRConvStartTime)
						AND r.PRConvStartTime >= r1.PRConvStartTime
						AND r.PRConvEndTime <= r1.PRConvEndTime)
	AND r.PM LIKE 'NoAssignedPRID'

----------------------------------------------------------------------------------------------------------------------
UPDATE r
	SET r.PRConvStartTime = ISNULL((SELECT MAX(r1.PRConvEndTime) FROM @RawDataNoAssigned r1
									WHERE r1.RcdIdx <> r.RcdIdx
									AND r1.PLId = r.plid
									AND r.PRConvStartTime >= r1.PRConvStartTime), l.starttime) 
	FROM @RawDataNoAssigned r
	JOIN @Lines				l	ON r.PLId = l.PLId
	WHERE r.PM LIKE 'NoAssignedPRID'
	
UPDATE r
	SET r.PRConvEndTime = ISNULL((SELECT MIN(r1.PRConvStartTime) FROM @RawDataNoAssigned r1
									WHERE r1.RcdIdx <> r.RcdIdx
									AND r1.PLId = r.plid
									AND r.PRConvStartTime < r1.PRConvStartTime), l.EndTime)
	FROM @RawDataNoAssigned r
	JOIN @Lines				l	ON r.PLId = l.PLId
	WHERE r.PM LIKE 'NoAssignedPRID'

UPDATE @RawDataNoAssigned
	SET PaperRuntime = DATEDIFF(ss, PRConvStartTime, PRConvEndTime)
	
--SELECT '@RawDataNoAssigned', PaperRuntime/60.0 Runtime, * FROM @RawDataNoAssigned
--	where ParentPLId is NULL
--	ORDER BY PRConvStartTime, PRConvEndTime
--return

----------------------------------------------------------------------------------------------------------------------
UPDATE r
	SET StartTimeLinePS = EndTimeLinePS
	FROM @RawData r
	WHERE StartTimeLinePS > EndTimeLinePS

UPDATE r
	SET PaperRuntime = DATEDIFF(SS, PRConvStartTime, PRConvEndTime)
		--, TotalRuntime = DATEDIFF(SS, PRConvStartTime, PRConvEndTime)
		--
		, TotalRuntimeLinePS = DATEDIFF(SS, StartTimeLinePS, EndTimeLinePS)
		, TotalFreshRuntimeLinePS = CASE WHEN TotalFreshRuntimeLinePS > DATEDIFF(SS, StartTimeLinePS, EndTimeLinePS) 
										THEN DATEDIFF(SS, StartTimeLinePS, EndTimeLinePS)
										ELSE TotalFreshRuntimeLinePS END
		, TotalStorageRuntimeLinePS = CASE WHEN TotalStorageRuntimeLinePS > DATEDIFF(SS, StartTimeLinePS, EndTimeLinePS) 
										THEN DATEDIFF(SS, StartTimeLinePS, EndTimeLinePS)
										ELSE TotalStorageRuntimeLinePS END
	FROM @RawData r
	
UPDATE r
	SET TotalScheduledDT = PaperRuntime
	FROM @RawData r
	WHERE TotalScheduledDT > PaperRuntime

UPDATE r
	SET TotalScheduledDTLinePS = TotalRuntimeLinePS
	FROM @RawData r
	WHERE TotalScheduledDTLinePS > TotalRuntimeLinePS

UPDATE r
	SET TotalFreshScheduledDTLinePS = TotalRuntimeLinePS
	FROM @RawData r
	WHERE TotalFreshScheduledDTLinePS > TotalRuntimeLinePS

UPDATE r
	SET TotalStorageScheduledDTLinePS = TotalRuntimeLinePS
	FROM @RawData r
	WHERE TotalStorageScheduledDTLinePS > TotalRuntimeLinePS

------------------------------------------------------------------------------------------------------------------
--	Adjust TotalRuntimeLinePS = O when it's overlaped
------------------------------------------------------------------------------------------------------------------
--SELECT 'adjust-1', r.RcdIdx, r.PLId, r.StartTimeLinePS, r.EndTimeLinePS, r.TotalRuntimeLinePS, *
UPDATE r SET r.TotalRuntimeLinePS = 0
	FROM @RawData r
	WHERE r.PM NOT LIKE 'NoAssignedPRID'
		AND r.TotalRuntimeLinePS > 0
		AND EXISTS (SELECT TOP 1 * FROM @RawData r1 
						WHERE r1.RcdIdx <> r.RcdIdx
						AND r1.PLId = r.plid
						AND r1.ParentPLId = r.ParentPLId
						AND r.StartTimeLinePS >= r1.StartTimeLinePS
						AND r.EndTimeLinePS <= r1.EndTimeLinePS)

--SELECT 'adjust-2', r.RcdIdx, r.PLId, r.StartTimeLinePS, r.EndTimeLinePS, r.TotalRuntimeLinePS, *
UPDATE r SET r.TotalRuntimeLinePS = 0
	FROM @RawData r
	WHERE r.PM NOT LIKE 'NoAssignedPRID'
		AND r.TotalRuntimeLinePS > 0
		AND EXISTS (SELECT TOP 1 * FROM @RawData r1 
						WHERE r1.RcdIdx <> r.RcdIdx
						AND r1.PLId = r.plid
						AND r1.ParentPLId <> r.ParentPLId
						AND r.StartTimeLinePS >= r1.StartTimeLinePS
						AND r.EndTimeLinePS <= r1.EndTimeLinePS)

------------------------------------------------------------------------------------------------------------------
UPDATE e
	SET e.UWS1 = r.ParentPRID, 
		e.parentUWS1 = ISNULL(r.GrandParentPRID,'NoAssignedPRID')
	FROM @RawData	r
	JOIN @ELPStops	e	ON	e.PLId = r.PLId
						AND e.StartTime >= r.PRConvStartTime 
						AND e.StartTime < r.PRConvEndTime
						AND r.InputOrder = 1
	
UPDATE e
	SET e.UWS2 = r.ParentPRID, 
		e.parentUWS2 = ISNULL(r.GrandParentPRID,'NoAssignedPRID')
	FROM @RawData	r
	JOIN @ELPStops	e	ON	e.PLId = r.PLId
						AND e.StartTime >= r.PRConvStartTime 
						AND e.StartTime < r.PRConvEndTime
						AND r.InputOrder = 2

UPDATE e
	SET e.UWS3 = r.ParentPRID, 
		e.parentUWS3 = ISNULL(r.GrandParentPRID,'NoAssignedPRID')
	FROM @RawData	r
	JOIN @ELPStops	e	ON	e.PLId = r.PLId
						AND e.StartTime >= r.PRConvStartTime 
						AND e.StartTime < r.PRConvEndTime
						AND r.InputOrder = 3

UPDATE e
	SET e.UWS4 = r.ParentPRID, 
		e.parentUWS4 = ISNULL(r.GrandParentPRID,'NoAssignedPRID')
	FROM @RawData	r
	JOIN @ELPStops	e	ON	e.PLId = r.PLId
						AND e.StartTime >= r.PRConvStartTime 
						AND e.StartTime < r.PRConvEndTime
						AND r.InputOrder = 4


------------------------------------------------------------------------------------------------------------------
UPDATE r
	SET TotalStops = ISNULL((SELECT SUM(e.Stop) FROM @ELPStops e
								WHERE r.PLID = e.PLID 
									AND e.StartTime >= r.PRConvStartTime
									AND e.StartTime < r.PRConvEndTime), 0)
	FROM @RawData r

UPDATE r
	SET TotalStopsLinePS = ISNULL((SELECT SUM(e.Stop) FROM @ELPStops e
									WHERE r.PLDesc = e.PLDesc 
										AND e.StartTime >= r.StartTimeLinePS
										AND e.StartTime < r.EndTimeLinePS), 0)
	FROM @RawData r

------------------------------------------------------------------------------------------------------------------
UPDATE @ELPStops
	SET PM = CASE WHEN ISNULL(UWS1,'NoAssignedPRID') <> 'NoAssignedPRID' 
					THEN LEFT(UWS1,2)
				WHEN ISNULL(UWS1,'NoAssignedPRID') = 'NoAssignedPRID' 
					AND ISNULL(UWS2,'NoAssignedPRID') <> 'NoAssignedPRID' 
					THEN LEFT(UWS2,2)					
				WHEN ISNULL(UWS1,'NoAssignedPRID') = 'NoAssignedPRID' 
					AND ISNULL(UWS2,'NoAssignedPRID') = 'NoAssignedPRID' 
					AND ISNULL(UWS3,'NoAssignedPRID') <> 'NoAssignedPRID' 
					THEN LEFT(UWS3,2)					
				WHEN ISNULL(UWS1,'NoAssignedPRID') = 'NoAssignedPRID' 
					AND ISNULL(UWS2,'NoAssignedPRID') = 'NoAssignedPRID' 
					AND ISNULL(UWS3,'NoAssignedPRID') = 'NoAssignedPRID' 
					AND ISNULL(UWS4,'NoAssignedPRID') <> 'NoAssignedPRID' 
					THEN LEFT(UWS4,2)					
				ELSE 'NoAssignedPRID'
			END

------------------------------------------------------------------------------------------------------------------
--select 'UWS NoAssignedPRID', e.TEDetId, e.PLId, e.comments, r.PRConvStartTime, e.StartTime, r.PRConvEndTime,  r.InputOrder, r.ParentPRID, r.GrandParentPRID
--	FROM @RawData	r
--	JOIN @ELPStops	e	ON	e.PLId = r.PLId
--						AND e.StartTime >= r.PRConvStartTime 
--						AND e.StartTime < r.PRConvEndTime
--	WHERE UWS1 LIKE 'NoAssignedPRID' AND UWS2 LIKE 'NoAssignedPRID' AND UWS3 LIKE 'NoAssignedPRID' AND UWS4 LIKE 'NoAssignedPRID'

--UPDATE r SET r.UWS1 = UPPER(LEFT(r.Comments,50)), r.PM = e.PM
----select distinct e.PM, UPPER(LEFT(r.comments, 2)), r.*
--	FROM @ELPStops	r
--	JOIN (SELECT DISTINCT PLId, TEDetId, pm, Comments FROM @ELPStops) e 
--				ON e.PLId = r.PLId
--				AND e.TEDetId <> r.TEDetId
--				AND e.PM = UPPER(LEFT(r.comments, 2))
--	WHERE r.UWS1 LIKE 'NoAssignedPRID' AND r.UWS2 LIKE 'NoAssignedPRID' AND r.UWS3 LIKE 'NoAssignedPRID' AND r.UWS4 LIKE 'NoAssignedPRID'

------------------------------------------------------------------------------------------------------------------
UPDATE e
	SET e.ParentPLId = (SELECT TOP 1 r.ParentPLId FROM @RawData r WHERE r.ParentPRID = e.UWS1)
	FROM @ELPStops e
	WHERE e.ParentPLId IS NULL
		AND e.PM <> 'NoAssignedPRID'	

UPDATE e
	SET e.ParentPLId = (SELECT TOP 1 r.ParentPLId FROM @RawData r WHERE r.ParentPRID = e.UWS2)
	FROM @ELPStops e
	WHERE e.ParentPLId IS NULL
		AND e.PM <> 'NoAssignedPRID'	

UPDATE e
	SET e.ParentPLId = (SELECT TOP 1 r.ParentPLId FROM @RawData r WHERE r.ParentPRID = e.UWS3)
	FROM @ELPStops e
	WHERE e.ParentPLId IS NULL
		AND e.PM <> 'NoAssignedPRID'	

UPDATE e
	SET e.ParentPLId = (SELECT TOP 1 r.ParentPLId FROM @RawData r WHERE r.ParentPRID = e.UWS4)
	FROM @ELPStops e
	WHERE e.ParentPLId IS NULL
		AND e.PM <> 'NoAssignedPRID'	

--UPDATE e
--	SET e.ParentPLId = (SELECT TOP 1 r.ParentPLId FROM @RawData r WHERE '%' + r.PM + '%' LIKE e.PM)
--	FROM @ELPStops e
--	WHERE e.ParentPLId IS NULL
--		AND e.PM <> 'NoAssignedPRID'

------------------------------------------------------------------------------------------------------------------
--	Added in v1.0.13 
--	PRB0080896: ELP Summary & Pivot do not match. Fixed set correctly using the same ParentPLId between both tables
------------------------------------------------------------------------------------------------------------------
UPDATE e
	SET e.PaperSource = (SELECT TOP 1 r.PaperSource FROM @RawData r 
							WHERE r.PLId = e.plid AND e.StartTime >= r.PRConvStartTime 
								AND e.StartTime < r.PRConvEndTime
								-- PRB0080896
								AND r.ParentPLId = e.ParentPLId
								AND r.PaperSource <> 'NoAssignedPRID')
	FROM @ELPStops e
	WHERE e.PaperSource IS NULL

UPDATE e
	SET e.PaperSource = 'NoAssignedPRID'
	FROM @ELPStops e
	WHERE e.PaperSource IS NULL
	
------------------------------------------------------------------------------------------------------------------
UPDATE e
	SET e.Fresh = (CASE WHEN r.ParentRollAge <= 1 THEN 1 ELSE 0 END)
	FROM @RawData	r	
	JOIN @ELPStops	e ON r.PLID = e.PLID
							AND (e.StartTime <= r.PRConvEndTime AND e.EndTime >= r.PRConvStartTime)
	WHERE r.PM NOT LIKE 'NoAssignedPRID'

------------------------------------------------------------------------------------------------------------------
--	Change invalid data in RawData
------------------------------------------------------------------------------------------------------------------
UPDATE @RawData
	SET PaperSource	= 'NoAssignedPRID',
		PaperSourcePM = 'NoAssignedPRID',
		PaperRunBy = 'NoAssignedPRID', 
		ParentPLId	= NULL, 
		PM = 'NoAssignedPRID',
		ParentPRID = 'NoAssignedPRID',
		ParentPM = NULL, 
		ParentPUDesc = NULL, 
		ParentTeam = NULL, 
		ParentRollTimestamp = NULL, 	
		ParentRollAge = NULL, 
		GrandParentPRID = 'NoAssignedPRID',
		EventId	= NULL,
		SourceId = NULL
	WHERE ParentPLId NOT IN (SELECT plid FROM Auto_opsDataStore.dbo.LINE_DIMENSION)

------------------------------------------------------------------------------------------------------------------
UPDATE @RawData
	SET ParentPM = LEFT(ParentPRID,2)					
	WHERE ParentPRID <> 'NoAssignedPRID'

------------------------------------------------------------------------------------------------------------------
UPDATE @ELPStops
	SET ParentPLId = -1
	WHERE PM LIKE 'NoAssignedPRID'

----------------------------------------------------------------------------------------------------
--select '@Lines', *, DATEDIFF(MI, @dtmStartTime , @dtmEndTime) minutes, @NPTStatusList NPTStatusList from @Lines order by linedesc
--select '@ELPStops', * from @ELPStops order by TEDetId, stop desc, PLDESC, PM, starttime
--select '@ELPStops', pldesc, PuDesc, pm, SUM(stop) elpstops, SUM(duration) duration, SUM(rateloss) rateloss, sum(fresh) freshStops
--	from @ELPStops 
--	--where PuDesc like '%Converter Reliability%' 
--	group by pldesc, PuDesc, PM
--select '@ELPStops', 'ALLs' as 'pldesc', SUM(stop) elpstops, SUM(duration) duration, SUM(rateloss) rateloss, sum(fresh) freshStops
--	from @ELPStops 
--return

--SELECT D.LineId, D.LineDesc, D.PLId, D.DeptId, D.DeptDesc, LTRIM(RTRIM(RIGHT(D.LineDesc,2)))
--	FROM dbo.LINE_DIMENSION D
--	WHERE DeptDesc LIKE 'Pmkg'

--select DISTINCT '@RawData', * FROM @RawData	r

----------------------------------------------------------------------------------------------------
-- Fix data of GrandParent if they are wrong (v1.0.17)
----------------------------------------------------------------------------------------------------
IF ((SELECT COUNT(*) FROM @Lines WHERE site LIKE 'Green Bay') > 0)
BEGIN

	--select top 100 '@RawData NO GrandParentPM', r.PRConvStartTime, r.PRConvEndTime, r.PLId, r.ParentPRID, r.ParentPM, r.GrandParentPRID, r.GrandParentPM, r.GrandParentTeam, R.PaperSource, r.ParentPLId
	--	FROM @RawData	r	
	--	WHERE r.GrandParentPM NOT IN (SELECT LTRIM(RTRIM(RIGHT(D.LineDesc,2)))
	--									FROM dbo.LINE_DIMENSION D
	--									WHERE DeptDesc LIKE 'Pmkg')
	--	order by r.PRConvStartTime, r.PRConvEndTime

	UPDATE r
		SET r.GrandParentPRID	= J.GrandParentPRID, 
			r.GrandParentPM		= J.GrandParentPM, 
			r.GrandParentTeam	= j.GrandParentTeam, 
			r.PaperSource		= j.PaperSource, 
			r.ParentPLId		= j.ParentPLId,
			r.PM				= j.PM,
			r.GrandParentFIXED	= 1
	--select TOP 1 r.PLId, r.ParentPM, r.ParentPRID, r.PRConvStartTime, r.PRConvEndTime, r.GrandParentPRID
	--	--, RIGHT(r.ParentPRID, 4), RIGHT(j.ParentPRID, 4)
	--	--, r.GrandParentPM, r.GrandParentTeam, r.PaperSource, r.ParentPLId, r.PM
	--	, 'JOIN -->' msg, 
	--	j.PLId, j.ParentPM, j.ParentPRID, j.PRConvStartTime, j.PRConvEndTime,j.GrandParentPRID
	--	--, j.GrandParentPM, j.GrandParentTeam, j.PaperSource, j.ParentPLId, j.PM
		FROM @RawData	r	
		JOIN @RawData	j	ON r.PLId = j.PLId
							AND r.ParentPM = j.ParentPM
							AND r.ParentPRID <> j.ParentPRID
							-- Compare Julian Date: the first number (1) is the last digit of year 2021, and the 122 is the day of the year counting from 1 on Jan 1st to 365 on Dec 31st 
							AND RIGHT(r.ParentPRID, 4) = RIGHT(j.ParentPRID, 4)
							AND r.PRConvStartTime <= j.PRConvEndTime
		WHERE r.GrandParentPM IS NOT NULL
			AND r.ParentPRID NOT LIKE 'NoAssignedPRID'
			AND r.GrandParentPM NOT IN (SELECT LTRIM(RTRIM(RIGHT(D.LineDesc,2)))
										FROM dbo.LINE_DIMENSION D
										WHERE DeptDesc LIKE 'Pmkg')
			AND j.GrandParentPM IS NOT NULL
			AND j.ParentPRID NOT LIKE 'NoAssignedPRID'
			AND j.GrandParentPM IN (SELECT LTRIM(RTRIM(RIGHT(D.LineDesc,2)))
										FROM dbo.LINE_DIMENSION D
										WHERE DeptDesc LIKE 'Pmkg')

	--select 'rows FIXED', @@ROWCOUNT 
	--SELECT '@RawData SIMIL GrandParentPM', r.PRConvStartTime, r.PRConvEndTime, r.PLId, r.ParentPRID, r.ParentPM, GrandParentFIXED,  r.GrandParentPRID, r.GrandParentPM, r.GrandParentTeam, R.PaperSource, r.ParentPLId, *
	--	FROM @RawData R
	--	WHERE r.ParentPRID LIKE '%CW%1062%' 
	--		and r.ParentPRID NOT LIKE 'NoAssignedPRID'
	--	order by r.PRConvStartTime

	-- Set some fields to use in the output
	UPDATE r
		SET PaperSourcePM = REPLACE(REPLACE((SELECT TOP 1 LINEDESC FROM dbo.line_dimension l WITH(NOLOCK) 
								WHERE l.LINEDESC LIKE '%' + r.PM + '%' AND l.DeptDesc LIKE 'PMKG'),'TT ', ''), 'PP ','')
		FROM @RawData	r	
		WHERE r.PaperSource NOT LIKE 'NoAssignedPRID'	
			AND r.Intr IS NOT NULL

END

----------------------------------------------------------------------------------------------------
INSERT INTO @PMDataCVTG
SELECT COALESCE(PaperSourcePM, PaperSource), COUNT(DISTINCT plid) 
	FROM @RawData	r	
	WHERE ParentPRID NOT LIKE 'NoAssignedPRID'
	GROUP BY COALESCE(PaperSourcePM, PaperSource)
	ORDER BY COALESCE(PaperSourcePM, PaperSource)

--SELECT '@PMDataCVTG', * FROM @PMDataCVTG

--select DISTINCT '@RawData', plid, pldesc, r.PaperSource, PaperSourcePM, r.paperrunby, r.ParentPLId, pm, intr
--	FROM @RawData	r	
--	--where PaperSource <> PaperSourcePM
--	order by r.plid, r.pldesc, r.PaperSource, r.paperrunby, r.ParentPLId, r.pm
--return

----------------------------------------------------------------------------------------------------
INSERT INTO @PRSummaryUWS(
			CvtgPLID, 
 			PaperSource,	
			PaperRunBy,		
			PaperSourcePM,
 			PaperMachine,
			INTR,	
			ParentPLID,		
			InputOrder,		
			UWS,
			--
			ScheduledDT,
			FreshSchedDT,
			StorageSchedDT,
			--
			TotalRuntime,
			TotalScheduledDT,
			--
			Runtime,
			FreshRuntime,
			StorageRuntime,
			--
			TotalRolls,	
			FreshRolls,
			StorageRolls)	
	SELECT 	
			pl.PLID,
			r.PaperSource,
			r.PaperRunBy,
			r.PaperSourcePM,
			r.PM,
			r.INTR,
			ISNULL(r.ParentPLId, -1),
			r.InputOrder,
			r.UWS,
			SUM(r.TotalScheduledDTLine),	
			SUM(r.TotalFreshScheduledDTLine),
			SUM(r.TotalStorageScheduledDTLine),
			--
			SUM(r.TotalRuntime) TotalRuntime, 
			SUM(r.TotalScheduledDT) TotalScheduledDT,	
			-- jpg
			SUM(r.TotalRuntimeLinePS) TotalRuntimeLinePS,
			SUM(r.TotalFreshRuntimeLinePS) TotalFreshRuntimeLinePS,
			SUM(r.TotalStorageRuntimeLinePS) TotalStorageRuntimeLinePS,
			--
			--SUM(r.TotalRuntimeLine) TotalRuntimeLine,
			--SUM(r.TotalFreshRuntimeLine) TotalFreshRuntimeLine,
			--SUM(r.TotalStorageRuntimeLine) TotalStorageRuntimeLine,
			--
			SUM(r.TotalRolls),	
			SUM(r.FreshRolls),
			SUM(r.StorageRolls)--,
		FROM @Lines			pl	
		JOIN @RawData		r	ON r.PLID = pl.PLID
		--LEFT JOIN @ELPStops	e	ON r.PLID = e.PLID
		--						AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
		--						AND e.StartTime >= r.StartTimeLinePS
		--						AND e.StartTime < r.EndTimeLinePS 
								--AND e.StartTime <= r.EndTimeLinePS 
								--AND e.EndTime > r.StartTimeLinePS
		WHERE (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')
		GROUP BY pl.PLID, r.UWS, r.PM, r.InputOrder, r.ParentPLId, 
			r.PaperSource, r.PaperRunBy, r.PaperSourcePM, 
			r.INTR, r.NPTStatus
				
UPDATE p
	SET p.ELPStops = ISNULL((SELECT SUM(ISNULL(e.Stop, 0)) 
								FROM @ELPStops	e		
								JOIN @RawData	r	ON r.PLID = e.PLID
													AND ISNULL(r.ParentPLId,-1) = ISNULL(e.ParentPLId, -1)
								WHERE p.CvtgPLID = r.PLID
									AND ISNULL(p.ParentPLID,-1) = ISNULL(r.ParentPLID,-1)
									AND p.PaperSource = r.PaperSource
									AND p.PaperRunBy = r.PaperRunBy
									AND p.PaperSourcePM = r.PaperSourcePM
									AND p.PaperMachine = r.PM
									AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
									AND p.InputOrder = r.InputOrder
									AND p.UWS = r.UWS
									AND e.StartTime >= r.StartTimeLinePS
									AND e.StartTime < r.EndTimeLinePS), 0)
		, p.ELPDowntime = ISNULL((SELECT SUM(ISNULL(e.Duration, 0))
									FROM @ELPStops	e		
									JOIN @RawData	r	ON r.PLID = e.PLID
														AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
									WHERE p.CvtgPLID = r.PLID
										AND p.PaperSource = r.PaperSource
										AND p.PaperRunBy = r.PaperRunBy
										AND p.PaperSourcePM = r.PaperSourcePM
										AND p.PaperMachine = r.PM
										AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
										AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
										AND p.InputOrder = r.InputOrder
										AND p.UWS = r.UWS
										AND e.StartTime >= r.StartTimeLinePS
										AND e.StartTime < r.EndTimeLinePS), 0)
		, p.RLELPDowntime = ISNULL((SELECT SUM(ISNULL(e.RateLoss, 0)) 
									FROM @ELPStops	e		
									JOIN @RawData	r	ON r.PLID = e.PLID
														AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
									WHERE p.CvtgPLID = r.PLID
										AND p.PaperSource = r.PaperSource
										AND p.PaperRunBy = r.PaperRunBy
										AND p.PaperSourcePM = r.PaperSourcePM
										AND p.PaperMachine = r.PM
										AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
										AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
										AND p.InputOrder = r.InputOrder
										AND p.UWS = r.UWS
										AND e.StartTime >= r.StartTimeLinePS
										AND e.StartTime < r.EndTimeLinePS), 0)
		, p.FreshStops = ISNULL((SELECT SUM(ISNULL(e.Stop, 0))
									FROM @ELPStops	e		
									JOIN @RawData	r	ON r.PLID = e.PLID
														AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
									WHERE p.CvtgPLID = r.PLID
										AND p.PaperSource = r.PaperSource
										AND p.PaperRunBy = r.PaperRunBy
										AND p.PaperSourcePM = r.PaperSourcePM
										AND p.PaperMachine = r.PM
										AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
										AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
										AND p.InputOrder = r.InputOrder
										AND p.UWS = r.UWS
										AND r.ParentRollAge <= 1 AND r.PaperRunBy <> 'NoAssignedPRID' 
										AND e.StartTime >= r.StartTimeLinePS
										AND e.StartTime < r.EndTimeLinePS), 0)
		, p.FreshDT = ISNULL((SELECT SUM(ISNULL(e.Duration, 0))
									FROM @ELPStops	e		
									JOIN @RawData	r	ON r.PLID = e.PLID
														AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
									WHERE p.CvtgPLID = r.PLID
										AND p.PaperSource = r.PaperSource
										AND p.PaperRunBy = r.PaperRunBy
										AND p.PaperSourcePM = r.PaperSourcePM
										AND p.PaperMachine = r.PM
										AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
										AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
										AND p.InputOrder = r.InputOrder
										AND p.UWS = r.UWS
										AND r.ParentRollAge <= 1 AND r.PaperRunBy <> 'NoAssignedPRID' 
										AND e.StartTime >= r.StartTimeLinePS
										AND e.StartTime < r.EndTimeLinePS), 0)
		, p.FreshRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss, 0))
										FROM @ELPStops	e		
										JOIN @RawData	r	ON r.PLID = e.PLID
															AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
										WHERE p.CvtgPLID = r.PLID
											AND p.PaperSource = r.PaperSource
											AND p.PaperRunBy = r.PaperRunBy
											AND p.PaperSourcePM = r.PaperSourcePM
											AND p.PaperMachine = r.PM
											AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
											AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
											AND p.InputOrder = r.InputOrder
											AND p.UWS = r.UWS
											AND r.ParentRollAge <= 1 AND r.PaperRunBy <> 'NoAssignedPRID' 
											AND e.StartTime >= r.StartTimeLinePS
											AND e.StartTime < r.EndTimeLinePS), 0)
		, p.StorageStops = ISNULL((SELECT SUM(ISNULL(e.Stop, 0))
										FROM @ELPStops	e		
										JOIN @RawData	r	ON r.PLID = e.PLID
															AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
										WHERE p.CvtgPLID = r.PLID
											AND p.PaperSource = r.PaperSource
											AND p.PaperRunBy = r.PaperRunBy
											AND p.PaperSourcePM = r.PaperSourcePM
											AND p.PaperMachine = r.PM
											AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
											AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
											AND p.InputOrder = r.InputOrder
											AND p.UWS = r.UWS
											AND r.ParentRollAge > 1 AND r.PaperRunBy <> 'NoAssignedPRID' 
											AND e.StartTime >= r.StartTimeLinePS
											AND e.StartTime < r.EndTimeLinePS), 0)
		, p.StorageDT	= ISNULL((SELECT SUM(ISNULL(e.Duration, 0))
										FROM @ELPStops	e		
										JOIN @RawData	r	ON r.PLID = e.PLID
															AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
										WHERE p.CvtgPLID = r.PLID
											AND p.PaperSource = r.PaperSource
											AND p.PaperRunBy = r.PaperRunBy
											AND p.PaperSourcePM = r.PaperSourcePM
											AND p.PaperMachine = r.PM
											AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
											AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
											AND p.InputOrder = r.InputOrder
											AND p.UWS = r.UWS
											AND r.ParentRollAge > 1 AND r.PaperRunBy <> 'NoAssignedPRID' 
											AND e.StartTime >= r.StartTimeLinePS
											AND e.StartTime < r.EndTimeLinePS), 0)
		, p.StorageRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss, 0))
										FROM @ELPStops	e		
										JOIN @RawData	r	ON r.PLID = e.PLID
															AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
										WHERE p.CvtgPLID = r.PLID
											AND p.PaperSource = r.PaperSource
											AND p.PaperRunBy = r.PaperRunBy
											AND p.PaperSourcePM = r.PaperSourcePM
											AND p.PaperMachine = r.PM
											AND ISNULL(p.INTR,'') = ISNULL(r.INTR,'')
											AND ISNULL(p.ParentPLID,0) = ISNULL(r.ParentPLID,0)
											AND p.InputOrder = r.InputOrder
											AND p.UWS = r.UWS
											AND r.ParentRollAge > 1 AND r.PaperRunBy <> 'NoAssignedPRID' 
											AND e.StartTime >= r.StartTimeLinePS
											AND e.StartTime < r.EndTimeLinePS), 0)
	FROM @PRSummaryUWS	p

----------------------------------------------------------------------------------------------------
--select '@PRSummaryUWS', * from @PRSummaryUWS 
--	order by PaperSource, PaperRunBy
--RETURN

----------------------------------------------------------------------------------------------------
INSERT INTO @PRSummaryLinePS (
			CvtgPLID, 
			ParentPLId,
 			PaperSource,	
			PaperSourcePM,
			PM,
			ScheduledDT,
			FreshSchedDT,
			StorageSchedDT,
			Runtime,
			FreshRuntime,
			StorageRuntime,
			TotalRolls,	
			FreshRolls,
			StorageRolls )	
	SELECT 	
			pl.PLID,
			r.ParentPLId,
			r.PaperSource,
			r.PaperSourcePM,
			r.ParentPM,
			--
			SUM(r.TotalScheduledDTLinePS),	
			SUM(r.TotalFreshScheduledDTLinePS),	
			SUM(r.TotalStorageScheduledDTLinePS),
			--
			SUM(r.TotalRuntimeLinePS),
			SUM(r.TotalFreshRuntimeLinePS),
			SUM(r.TotalStorageRuntimeLinePS),
			--
			-- TotalRuntimePMRunBy	TotalStopsPMRunBy	TotalDowntimePMRunBy	TotalRateLossDTPMRunBy	TotalScheduledDTPMRunBy	TotalFreshRuntimePMRunBy	TotalFreshStopsPMRunBy	TotalFreshDowntimePMRunBy	TotalFreshRateLossDTPMRunBy	TotalFreshScheduledDTPMRunBy	TotalStorageRuntimePMRunBy	TotalStorageStopsPMRunBy	TotalStorageDowntimePMRunBy	TotalStorageRateLossDTPMRunBy	TotalStorageScheduledDTPMRunBy
			SUM(r.TotalRolls),	
			SUM(r.FreshRolls),
			SUM(r.StorageRolls)--,
			--SUM(r.TotalScheduledDTPMRunBy),	
			--SUM(r.TotalFreshScheduledDTPMRunBy),	
			--SUM(r.TotalStorageScheduledDTPMRunBy),
			--
			--SUM(r.TotalRuntime), 
			--
			--SUM(r.TotalRuntimePMRunBy),
			--SUM(r.TotalFreshRuntimePMRunBy),
			--SUM(r.TotalStorageRuntimePMRunBy),
			--
		FROM @Lines			pl 
		JOIN @RawData		r	ON r.PLID = pl.PLID
		WHERE (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')
			--AND r.TotalRuntimeLinePS > 0 
		GROUP BY pl.PLID, r.PaperSource, r.PaperSourcePM, r.ParentPLId, r.ParentPM
		
----------------------------------------------------------------------------------------------------
--select 'update', p.Runtime, p.ScheduledDT, p.FreshRuntime, p.FreshSchedDT, p.StorageRuntime, p.StorageSchedDT, *
--	FROM @PRSummaryLinePS	p
--	WHERE p.Runtime < p.ScheduledDT
--		OR p.FreshRuntime < p.FreshSchedDT
--		OR p.StorageRuntime < p.StorageSchedDT

----------------------------------------------------------------------------------------------------
UPDATE p
	SET p.Runtime		= (SELECT SUM(r.TotalRuntimeLine) FROM 	@RawData	r	
								WHERE r.PLID = pl.PLID
								AND ISNULL(r.ParentPLId,-1) = ISNULL(p.ParentPLId, -1)
								AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')),
		p.ScheduledDT	= (SELECT SUM(r.TotalScheduledDTLine) FROM 	@RawData	r	
								WHERE r.PLID = pl.PLID
								AND ISNULL(r.ParentPLId,-1) = ISNULL(p.ParentPLId, -1)
								AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All'))
	FROM @PRSummaryLinePS	p
	JOIN @Lines				pl	ON p.CvtgPLID = pl.PLId
	WHERE p.Runtime < p.ScheduledDT

UPDATE p
	SET p.FreshRuntime	= (SELECT SUM(r.TotalFreshRuntimeLine) FROM 	@RawData	r	
								WHERE r.PLID = pl.PLID
								AND ISNULL(r.ParentPLId,-1) = ISNULL(p.ParentPLId, -1)
								AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')),
		p.FreshSchedDT	= (SELECT SUM(r.TotalFreshScheduledDTLine) FROM 	@RawData	r	
								WHERE r.PLID = pl.PLID
								AND ISNULL(r.ParentPLId,-1) = ISNULL(p.ParentPLId, -1)
								AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All'))
	FROM @PRSummaryLinePS	p
	JOIN @Lines				pl	ON p.CvtgPLID = pl.PLId
	WHERE p.FreshRuntime < p.FreshSchedDT

UPDATE p
	SET p.StorageRuntime= (SELECT SUM(r.TotalStorageRuntimeLine) FROM 	@RawData	r	
								WHERE r.PLID = pl.PLID
								AND ISNULL(r.ParentPLId,-1) = ISNULL(p.ParentPLId, -1)
								AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')),
		p.StorageSchedDT= (SELECT SUM(r.TotalStorageScheduledDTLine) FROM 	@RawData	r	
								WHERE r.PLID = pl.PLID
								AND ISNULL(r.ParentPLId,-1) = ISNULL(p.ParentPLId, -1)
								AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All'))
	FROM @PRSummaryLinePS	p
	JOIN @Lines				pl	ON p.CvtgPLID = pl.PLId
	WHERE p.StorageRuntime < p.StorageSchedDT

----------------------------------------------------------------------------------------------------
UPDATE p
	SET p.ELPStops = ISNULL((SELECT SUM(ISNULL(e.Stop, 0)) 
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)), 0)
		, p.ELPDowntime = ISNULL((SELECT SUM(ISNULL(e.Duration, 0))
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)), 0)
		, p.RLELPDowntime = ISNULL((SELECT SUM(ISNULL(e.RateLoss, 0)) 
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)), 0)
		, p.FreshStops = ISNULL((SELECT SUM(ISNULL(e.Stop, 0))
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
								AND e.PaperSource = p.PaperSource
								AND e.Fresh = 1), 0)
		, p.FreshDT = ISNULL((SELECT SUM(ISNULL(e.Duration, 0))
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
								AND e.Fresh = 1), 0)
		, p.FreshRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss, 0))
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
								AND e.Fresh = 1), 0)
		, p.StorageStops = ISNULL((SELECT SUM(ISNULL(e.Stop, 0))
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
								AND e.Fresh = 0), 0)
		, p.StorageDT	= ISNULL((SELECT SUM(ISNULL(e.Duration, 0))
							FROM @ELPStops	e		
							WHERE p.CvtgPLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
								AND e.Fresh = 0), 0)
		, p.StorageRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss, 0))
								FROM @ELPStops	e		
								WHERE p.CvtgPLID = e.PLID
									AND e.PaperSource = p.PaperSource
									AND ISNULL(p.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
									AND e.Fresh = 0), 0)
	FROM @PRSummaryLinePS	p
						
--select '@PRSummaryLinePS', * from @PRSummaryLinePS
--	where PM is not null
--	order by PaperSourcePM
--return
	
----------------------------------------------------------------------------------------------------
INSERT INTO @TrendsData (
			PM_PLID					,
			PM_PLDesc				,
			PLid					,
			PLDesc					,			
			Date					,			
			Runtime					,			
			[FreshRuntime]			,
			[StorageRuntime]		,
			ScheduledDT				,
			FreshSchedDT			,
			StorageSchedDT			)
	SELECT  
			r.ParentPLId			,
			r.ParentPM				,
			--r.PM					,
			r.PLid					,
			r.PLDesc				,
			p.ProdDay				, 
			SUM(r.TotalRuntimeLinePS),
			SUM(r.TotalFreshRuntimeLinePS),
			SUM(r.TotalStorageRuntimeLinePS),
			SUM(r.TotalScheduledDTLinePS),	
			SUM(r.TotalFreshScheduledDTLinePS),	
			SUM(r.TotalStorageScheduledDTLinePS)
		FROM @Lines			pl 
		JOIN @RawData		r	ON r.PLID = pl.PLID
								AND r.StartTimeLinePS < pl.EndTime 
								AND r.EndTimeLinePS > pl.StartTime
		JOIN @ProdDay		p	ON r.plid = p.plid
								AND r.StartTimeLinePS < p.EndTime 
								AND r.EndTimeLinePS > p.StartTime
		WHERE r.PaperSource NOT LIKE 'NoAssignedPRID'
			--AND r.TotalRuntimeLinePS > 0
			AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')
		GROUP BY r.PLid, ProdDay, r.PLDesc, 
			r.ParentPLId, r.ParentPM	
		ORDER BY p.ProdDay, r.PLDesc

----------------------------------------------------------------------------------------------------
INSERT INTO @TrendsData (
			PM_PLID				,
			PM_PLDesc			,
			PLid				,
			PLDesc				,			
			Date				,			
			Runtime				,		
			ScheduledDT			)			
	SELECT  
			--'@TrendsData - NoAssignedPRID',
			-1					,
			r.PM				,
			r.PLid				,
			r.PLDesc			,
			p.ProdDay			, 
			SUM(r.PaperRuntime)	,
			SUM(r.ScheduledDT)
		FROM @Lines					pl 
		JOIN @RawDataNoAssigned		r	ON r.PLID = pl.PLID
										AND r.PRConvStartTime < pl.EndTime 
										AND r.PRConvEndTime > pl.StartTime
		JOIN @ProdDay				p	ON r.plid = p.plid
										AND r.PRConvStartTime < p.EndTime 
										AND r.PRConvEndTime > p.StartTime
		WHERE r.PaperRuntime > 0
			AND r.PM LIKE 'NoAssignedPRID'
			AND (CHARINDEX('|' + r.NPTStatus + '|', '|' + @NPTStatusList + '|') > 0 OR @NPTStatusList = 'All')
		GROUP BY r.PLid, ProdDay, r.PLDesc, 
			r.ParentPLId, r.PM	
		ORDER BY p.ProdDay, r.PLDesc

----------------------------------------------------------------------------------------------------
UPDATE	p
	SET p.ELPStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
						FROM @ELPStops	e 
						WHERE p.PLID = e.PLID
							AND p.PM_PLID = e.ParentPLId
							AND e.starttime >= t.starttime
							AND e.starttime < t.endtime), 0)
		, p.ELPDowntime = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
							AND p.PM_PLID = e.ParentPLId
							AND e.starttime >= t.starttime
							AND e.starttime < t.endtime), 0)
		, p.RLELPDowntime = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
								AND p.PM_PLID = e.ParentPLId
								AND e.starttime >= t.starttime
								AND e.starttime < t.endtime), 0)
	FROM @TrendsData	p
	JOIN @ProdDay		t	ON t.ProdDay = p.date
	
UPDATE	p
	SET p.FreshStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND p.PM_PLID = e.ParentPLId
									AND e.starttime >= t.starttime
									AND e.starttime < t.endtime
									AND e.Fresh = 1), 0)
		, p.FreshDT = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
								AND p.PM_PLID = e.ParentPLId
								AND e.starttime >= t.starttime
								AND e.starttime < t.endtime
								AND e.Fresh = 1), 0)
		, p.FreshRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND p.PM_PLID = e.ParentPLId
									AND e.starttime >= t.starttime
									AND e.starttime < t.endtime
									AND e.Fresh = 1), 0)
	FROM @TrendsData	p
	JOIN @ProdDay		t	ON t.ProdDay = p.date
	WHERE p.PM_PLID <> -1

----StorageStops	StorageDT	StorageRLELPDT
UPDATE	p
	SET p.StorageStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND p.PM_PLID = e.ParentPLId
									AND e.starttime >= t.starttime
									AND e.starttime < t.endtime
									AND e.Fresh = 0), 0)
		, p.StorageDT = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
								AND p.PM_PLID = e.ParentPLId
								AND e.starttime >= t.starttime
								AND e.starttime < t.endtime
								AND e.Fresh = 0), 0)
		, p.StorageRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND p.PM_PLID = e.ParentPLId
									AND e.starttime >= t.starttime
									AND e.starttime < t.endtime
									AND e.Fresh = 0), 0)
	FROM @TrendsData	p
	JOIN @ProdDay		t	ON t.ProdDay = p.date
	WHERE p.PM_PLID <> -1
	
----------------------------------------------------------------------------------------------------
INSERT INTO @TrendsData (
			PM_PLID					,
			PM_PLDesc				,
			PLid					,
			PLDesc					,			
			Date					,			
			Runtime					,			
			FreshRuntime			,			
			StorageRuntime			,			
			ScheduledDT				,			
			FreshSchedDT			,			
			StorageSchedDT			,
			ELPStops				,
			ELPDowntime				,
			RLELPDowntime			,
			FreshStops				,
			FreshDT					,
			FreshRLELPDT			,
			StorageStops			,
			StorageDT				,
			StorageRLELPDT			)			
	SELECT  
			-2						,
			'All'					,
			r.PLid					,
			r.PLDesc				,
			r.Date					, 
			SUM(r.Runtime),
			SUM(r.FreshRuntime)		,
			SUM(r.StorageRuntime)	,
			SUM(r.ScheduledDT)		,	
			SUM(r.FreshSchedDT)		,	
			SUM(r.StorageSchedDT)	,
			SUM(r.ELPStops)			,
			SUM(r.ELPDowntime)		,
			SUM(r.RLELPDowntime)	,
			SUM(r.FreshStops)		,
			SUM(r.FreshDT)			,
			SUM(r.FreshRLELPDT)		,
			SUM(r.StorageStops)		,
			SUM(r.StorageDT)		,
			SUM(r.StorageRLELPDT)	
		FROM @TrendsData r
		GROUP BY r.PLid, Date, r.PLDesc

----------------------------------------------------------------------------------------------------
-- Fix the Runtimes in Trends
----------------------------------------------------------------------------------------------------
UPDATE @TrendsData
	SET 
		FreshRuntime = (1440*60) * (FreshRuntime/(FreshRuntime + StorageRuntime)) , 
		StorageRuntime = (1440*60) * (StorageRuntime/(FreshRuntime + StorageRuntime)) 
	FROM @TrendsData
	WHERE (FreshRuntime + StorageRuntime) > (1440*60)
		AND PM_PLDEsc = 'All'
	
UPDATE @TrendsData
	SET Runtime = FreshRuntime + StorageRuntime
	WHERE Runtime > (1440*60)
		AND PM_PLDEsc = 'All'

--SELECT Date, SUM(t1.Runtime) FROM @TrendsData t1
--			WHERE t1.PM_PLDesc <> 'All'
--			AND 'NoAssignedPRID' <> t1.PM_PLDesc
--	group by Date

--SELECT * 
DELETE t
	FROM @TrendsData t
	WHERE t.PM_PLDesc = 'NoAssignedPRID'
	AND ELPStops = 0 AND ELPDowntime = 0 AND RLELPDowntime = 0 
	AND (SELECT SUM(t1.Runtime) FROM @TrendsData t1
			WHERE t.plid = t1.plid
			AND t.date = t1.Date
			AND t1.PM_PLDesc <> 'All'
			AND t.PM_PLDesc <> t1.PM_PLDesc) >= (1440*60)

----------------------------------------------------------------------------------------------------
--SELECT '@ProdDay', * FROM @ProdDay 
--select '@TrendsData', * from @TrendsData t
--	ORDER BY date ASC, PLDesc, PM_PLID 
--return

----------------------------------------------------------------------------------------------------
--Cause
----------------------------------------------------------------------------------------------------
INSERT INTO @PRSummaryPMRunByCause(
		PLID, 
		PaperRunBy,		
 		PaperMachine,
		PaperSource,
		Cause,
		Runtime,
		FreshRuntime,
		StorageRuntime,
		ScheduledDT,
		FreshSchedDT,
		StorageSchedDT,
		TotalRolls,	
		FreshRolls,
		StorageRolls)
	SELECT 
		r.PLID, 
		r.PaperRunBy,
		r.PM AS PaperMachine,
		e.PaperSource,
		e.Reason2, 
		SUM(r.TotalRuntimeLinePS) / 60.0  RuntimePS,
		SUM(CASE WHEN ParentRollAge <= 1 THEN r.TotalRuntimeLinePS / 60.0 ELSE 0 END) FreshRuntime,
		SUM(CASE WHEN ParentRollAge > 1 THEN r.TotalRuntimeLinePS / 60.0 ELSE 0 END) StorageRuntime,
		SUM(r.TotalScheduledDTLinePS) TotalScheduledDT,
		SUM(CASE WHEN ParentRollAge <= 1 THEN r.TotalScheduledDTLinePS / 60.0 ELSE 0 END) AS FreshSchedDT  ,
		SUM(CASE WHEN ParentRollAge > 1 THEN r.TotalScheduledDTLinePS / 60.0 ELSE 0 END) AS StorageSchedDT,
		SUM(r.TotalRolls) TotalRolls,	
		SUM(r.FreshRolls) FreshRolls,
		SUM(r.StorageRolls) StorageRolls
	FROM @RawData	r	
	JOIN @ELPStops	e	ON r.PLID = e.PLID
						AND ISNULL(r.ParentPLId,0) = ISNULL(e.ParentPLId, 0)
						AND (e.StartTime >= r.StartTimeLinePS AND e.StartTime < r.EndTimeLinePS)
						AND (r.StartTimeLinePS < e.EndTime AND r.EndTimeLinePS >= e.StartTime)
	WHERE r.PM IS NOT NULL
	GROUP BY r.PLID, r.PaperRunBy, r.PM, e.Reason2, e.PaperSource
	ORDER BY r.PaperRunBy, r.PM, e.Reason2

UPDATE	p
	SET p.ELPStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
						FROM @ELPStops	e 
						WHERE p.PLID = e.PLID
							AND p.Cause = e.Reason2
							AND e.PaperSource = p.PaperSource
							--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
							--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
							), 0)
		, p.ELPDowntime = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
								AND p.Cause = e.Reason2
								AND e.PaperSource = p.PaperSource
								--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
								--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
									), 0)
		, p.RLELPDowntime = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND p.Cause = e.Reason2
									AND e.PaperSource = p.PaperSource
									--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
									--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
										), 0)
	FROM @PRSummaryPMRunByCause p
	WHERE PaperMachine NOT LIKE 'NoAssignedPRID'
	
UPDATE	p
	SET p.ELPStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
						FROM @ELPStops	e 
						WHERE p.PLID = e.PLID
							AND e.PaperSource = p.PaperSource
							AND p.Cause = e.Reason2
							AND (p.PaperMachine LIKE e.PM )), 0)
		, p.ELPDowntime = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
								AND e.PaperSource = p.PaperSource
								AND p.Cause = e.Reason2
								AND (p.PaperMachine LIKE e.PM )), 0)
		, p.RLELPDowntime = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND e.PaperSource = p.PaperSource
									AND p.Cause = e.Reason2
									AND (p.PaperMachine LIKE e.PM )), 0)
	FROM @PRSummaryPMRunByCause p
	WHERE p.PaperMachine LIKE 'NoAssignedPRID'
	
UPDATE	p
	SET p.FreshStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND e.Fresh = 1
									AND e.PaperSource = p.PaperSource
									AND p.Cause = e.Reason2
									--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
									--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
									), 0)
		, p.FreshDT = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
								AND e.Fresh = 1
								AND e.PaperSource = p.PaperSource
								AND p.Cause = e.Reason2
								--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
								--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
								), 0)
		, p.FreshRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND e.Fresh = 1
									AND e.PaperSource = p.PaperSource
									AND p.Cause = e.Reason2
									--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
									--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
									), 0)
	FROM @PRSummaryPMRunByCause p
	WHERE PaperRunBy <> 'NoAssignedPRID'

----StorageStops	StorageDT	StorageRLELPDT
UPDATE	p
	SET p.StorageStops = ISNULL((SELECT SUM(ISNULL(e.Stop,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND e.Fresh = 0
									AND e.PaperSource = p.PaperSource
									AND p.Cause = e.Reason2
									--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
									--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
									), 0)
		, p.StorageDT = ISNULL((SELECT SUM(ISNULL(e.duration,0))  
							FROM @ELPStops	e 
							WHERE p.PLID = e.PLID
									AND e.Fresh = 0
									AND e.PaperSource = p.PaperSource
									AND p.Cause = e.Reason2
									--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
									--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
									), 0)
		, p.StorageRLELPDT = ISNULL((SELECT SUM(ISNULL(e.RateLoss,0))  
								FROM @ELPStops	e 
								WHERE p.PLID = e.PLID
									AND e.PaperSource = p.PaperSource
									AND e.Fresh = 0
									AND p.Cause = e.Reason2
									--AND (p.PaperMachine LIKE '%'+ e.PM + '%'
									--	OR p.PaperRunBy LIKE '%'+ e.PM + '%')
									), 0)
	FROM @PRSummaryPMRunByCause p
	WHERE PaperRunBy <> 'NoAssignedPRID'

----------------------------------------------------------------------------------------------------
--select '@PRSummaryPMRunByCause', SUM(Runtime) Runtime, SUM(ELPStops) ELPStops, SUM(ELPDowntime) ELPDowntime, SUM(RLELPDowntime) RLELPDowntime
--	from @PRSummaryPMRunByCause
--select '@PRSummaryPMRunByCause', Cause, SUM(Runtime) Runtime, SUM(ELPStops) ELPStops, SUM(ELPDowntime) ELPDowntime, SUM(RLELPDowntime) RLELPDowntime
--	from @PRSummaryPMRunByCause
--	--where ELPStops > 0
--	GROUP BY Cause
--return

-----------------------------------------------------------------------------------
--	CALCULATE AND INSERT DATA IN OUTPUT @PRSummary TABLE
-----------------------------------------------------------------------------------
--Converting
INSERT INTO @Summary
SELECT	'CVTG',
		1,
		'Line-PaperSource-UWS',
		pl.LineDesc																	[Line],
		prs.PaperSourcePM															[Paper Source],
		--prs.PaperSource																[Paper Source],
		prs.UWS																		[UWS],
		-- FO-04637
		(CASE WHEN (SUM(COALESCE(prs.TotalRuntime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
					--AND pl.LineDesc LIKE 'PP FF%'	
					THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)))
				ELSE SUM((COALESCE(prs.TotalRuntime, 0.0)))
		END) / 60.0																	[Paper Runtime],	
		--sUM(COALESCE(prs.ScheduledDT, 0.0))/60.0 ScheduledDT, 
		--(CASE	
		--		WHEN (SUM(COALESCE(prs.TotalRuntime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
		--			--AND pl.LineDesc LIKE 'PP FF%'	
		--			THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) - SUM(COALESCE(prs.ScheduledDT, 0.0)))
		--		ELSE SUM((COALESCE(prs.TotalRuntime, 0.0)) - COALESCE(prs.ScheduledDT, 0.0))
		--END) / 60.0																	[Old Paper Runtime],	
		--
		SUM(COALESCE(prs.ELPStops, 0))												[Paper Stops],
		SUM(CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))							[DT due to Stops],
		SUM(COALESCE(prs.RLELPDowntime, 0.0))										[Eff. DT (Rate Loss)],
		SUM((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0))) 
			+ (COALESCE(prs.RLELPDowntime, 0.0)))									[Total Paper DT],
		-- Fresh data
		SUM(CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  
			THEN 0 ELSE prs.FreshStops END))										[Fresh Paper Stops],
		SUM(CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
			ELSE (COALESCE(prs.FreshDT, 0.0) + COALESCE(prs.FreshRLELPDT, 0.0)) 
			END))																	[FreshPaperDT],
		-- FO-04637
		SUM(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
				ELSE (COALESCE(prs.FreshRuntime, 0.0)) / 60.0 END) 					[Fresh Paper Runtime],
		--
		--SUM(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE 
		--	(COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0)) / 60.0 END) 	[Old Fresh Paper Runtime],
		SUM(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  
			THEN 0 ELSE COALESCE(prs.FreshRolls, 0) END)							[Fresh Rolls Ran],
		-- Storage data
		SUM(CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
			ELSE COALESCE(prs.StorageStops, 0) END))								[Storage Paper Stops],
		SUM(CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
			ELSE  
			(COALESCE(prs.StorageDT, 0.0) + COALESCE(prs.StorageRLELPDT, 0.0)) END))[StoragePaperDT],
		-- FO-04637
		SUM((CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE 
			COALESCE(prs.StorageRuntime, 0.0) END) / 60.0)							[Storage Paper Runtime],
		--SUM((CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE 
		--	COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0) 
		--	END) / 60.0)															[OLd Storage Paper Runtime],
		--
		SUM(COALESCE(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  
			THEN 0 ELSE prs.StorageRolls END, 0))									[Storage Rolls Ran],
		SUM(COALESCE(prs.TotalRolls, 0))											[Total Rolls Ran],
		--FO-04637
		CASE WHEN prs.PaperSourcePM LIKE 'NoAssignedPRID'  THEN 0 
			ELSE CASE WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0))) / 60.0) > 0.0
						THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
							(SUM(COALESCE(prs.FreshRuntime, 0.0))/60.0))
						ELSE 0.0
			END 
		END																			[Fresh ELP%],
		--
		--CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
		--	ELSE CASE WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))) / 60.0) > 0.0
		--				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
		--					(SUM(COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))/60.0))
		--				ELSE 0.0
		--	END 
		--END																			[OLd Fresh ELP%],
		-- FO-04637
		CASE WHEN prs.PaperSourcePM LIKE 'NoAssignedPRID'  THEN 0 
			ELSE CASE 
				WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0))) / 60.0) > 0.0 
				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
					(SUM(COALESCE(prs.StorageRuntime, 0.0))/60.0))
				ELSE 0.0 END
		END																			[Storage ELP%],
		--
		--CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
		--	ELSE CASE 
		--		WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))) / 60.0) > 0.0 
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
		--			(SUM(COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))/60.0))
		--		ELSE 0.0 END
		--END																			[Old Storage ELP%],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0))) / 60.0) > 0.0
				THEN CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
							--AND pl.LineDesc LIKE 'PP FF%'
						THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
								(((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)))/60.0))

						ELSE (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
							(SUM(COALESCE(prs.Runtime, 0.0))/60.0))
					END
			ELSE 0.0	END															[Total ELP%]
		--
		--, CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))) / 60.0) > 0.0
		--		THEN CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
		--					--AND pl.LineDesc LIKE 'PP FF%'
		--				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--						(((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) - (SUM(COALESCE(prs.ScheduledDT, 0.0))))/60.0))

		--				ELSE (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--					(SUM(COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))/60.0))
		--			END
		--	ELSE 0.0	END															[Old Total ELP%]
	FROM @PRSummaryUWS	prs
	JOIN @Lines			pl	ON prs.CvtgPLID = pl.PLID
	GROUP BY pl.LineDesc, prs.PaperSourcePM, prs.UWS
	ORDER BY pl.LineDesc, prs.PaperSourcePM, prs.UWS	
		
INSERT INTO @Summary
SELECT	'CVTG',
		2,
		'Line-PaperSource',
		pl.LineDesc	 																[Line],
		--prs.PaperSource																[Paper Source],
		prs.PaperSourcePM															[Paper Source],
		''																			[UWS],
		-- FO-04637
		(CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
					AND pl.LineDesc LIKE 'PP FF%'		
				THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)))
				ELSE SUM((COALESCE(prs.Runtime, 0.0))) 
			END ) / 60.0															[Paper Runtime],						
		-- 
		--(CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
		--			AND pl.LineDesc LIKE 'PP FF%'		
		--		THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) - SUM(COALESCE(prs.ScheduledDT, 0.0)))
		--		ELSE SUM((COALESCE(prs.Runtime, 0.0)) - COALESCE(prs.ScheduledDT, 0.0)) 
		--	END ) / 60.0															[Old Paper Runtime],						
		--SUM((COALESCE(prs.Runtime, 0.0)) - COALESCE(prs.ScheduledDT, 0.0)) / 60.0	[Paper Runtime], 
		SUM(COALESCE(prs.ELPStops, 0))												[Paper Stops],
		SUM(CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))							[DT due to Stops],
		SUM(COALESCE(prs.RLELPDowntime, 0.0))										[Eff. DT (Rate Loss)],
		SUM((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0))) 
			+ (COALESCE(prs.RLELPDowntime, 0.0)))									[Total Paper DT],
		SUM(CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID' 
								THEN 0 ELSE prs.FreshStops END))					[Fresh Paper Stops],
		SUM((CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID' THEN 0 
			ELSE ((COALESCE(prs.FreshDT, 0.0) + COALESCE(prs.FreshRLELPDT, 0.0))) END)))	[Fresh Paper DT],
		-- FO-04637
		SUM((CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID' 
				THEN 0 ELSE (COALESCE(prs.FreshRuntime, 0.0) ) / 60.0 END))			[Fresh Paper Runtime],
		--SUM((CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID' 
		--		THEN 0 ELSE (COALESCE(prs.FreshRuntime, 0.0) 
		--				- COALESCE(prs.FreshSchedDT, 0.0)) / 60.0 END))				[Old Fresh Paper Runtime],
		--
		SUM(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID' 
						THEN 0 ELSE COALESCE(prs.FreshRolls, 0) END) 				[Fresh Rolls Ran],
		SUM(CONVERT(FLOAT, COALESCE(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID' 
										THEN 0 ELSE prs.StorageStops END, 0)))		[Storage Paper Stops],
		SUM((CONVERT(FLOAT, CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE 
			(COALESCE(prs.StorageDT, 0.0) + COALESCE(prs.StorageRLELPDT, 0.0)) END)))	[Storage Paper DT],
		-- FO-04637
		SUM(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE 
			((COALESCE(prs.StorageRuntime, 0.0)) / 60.0) END)						[Storage Paper Runtime],
		--SUM(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE 
		--	((COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0)) / 60.0) END)	[OLd Storage Paper Runtime],
		-- 
		SUM(COALESCE(CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 ELSE prs.StorageRolls END, 0))	[Storage Rolls Ran],
		SUM(COALESCE(prs.TotalRolls, 0))											[Total Rolls Ran],
		-- FO-04637
		CASE WHEN prs.PaperSourcePM LIKE 'NoAssignedPRID'  THEN 0 
			ELSE CASE 
				WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0)))) > 0.0
					THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
						(SUM(COALESCE(prs.FreshRuntime, 0.0))/60.0))
				ELSE 0.0 
			END
		END																			[Fresh ELP%],
		--
		--CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
		--	ELSE CASE 
		--		WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0)))) > 0.0
		--			THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
		--				(SUM(COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))/60.0))
		--		ELSE 0.0 
		--	END
		--END																			[Old Fresh ELP%],
		-- FO-04637
		CASE WHEN prs.PaperSourcePM LIKE 'NoAssignedPRID'  THEN 0 
			ELSE CASE 
				WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) )) / 60.0) > 0.0 
					THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
						(SUM(COALESCE(prs.StorageRuntime, 0.0))/60.0))
				ELSE 0.0 END END													[Storage ELP%],
		--CASE WHEN prs.PaperSource LIKE 'NoAssignedPRID'  THEN 0 
		--	ELSE CASE 
		--		WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))) / 60.0) > 0.0 
		--			THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
		--				(SUM(COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))/60.0))
		--		ELSE 0.0 END END													[Old Storage ELP%],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0))) / 60.0) > 0.0
				THEN CASE WHEN SUM(COALESCE(prs.Runtime, 0.0)) / 60.0 > 0
									--AND pl.LineDesc LIKE 'PP FF%'
						THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
							(SUM(COALESCE(prs.Runtime, 0.0)) / 60.0))
						ELSE 0 END
				ELSE 0.0	END														[Total ELP%]
		--
		--, CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))) / 60.0) > 0.0
		--		THEN CASE WHEN SUM(COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0)) / 60.0 > 0
		--							--AND pl.LineDesc LIKE 'PP FF%'
		--				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--					(SUM(COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0)) / 60.0))
		--				ELSE 0 END
		--		ELSE 0.0	END														[Old Total ELP%]
	FROM @PRSummaryLinePS	prs
	LEFT JOIN @Lines		pl ON prs.CvtgPLID = pl.PLID
	GROUP BY pl.LineDesc, prs.PaperSourcePM
	ORDER BY pl.LineDesc, prs.PaperSourcePM	
	OPTION (KEEP PLAN)

-- 
INSERT INTO @Summary
SELECT	'CVTG' Type,
		3,
		'Line' Grouping,
		PlDesc,
		'' PaperLine,
		'' UWS,
		--SUM(Runtime),
		(CASE WHEN (SUM(Runtime) > DATEDIFF(mi, @dtmStartTime , @dtmEndTime))
				THEN DATEDIFF(mi, @dtmStartTime , @dtmEndTime)
				ELSE SUM(Runtime) END),						
		SUM(PaperStops),
		SUM(DTDueToStops),
		SUM(EffDTRateLoss),
		SUM(TotalPaperDT),
		SUM(FreshPaperStops), 
		SUM(FreshPaperDT),
		--SUM(FreshPaperRuntime),
		(CASE WHEN (SUM(FreshPaperRuntime) > DATEDIFF(mi, @dtmStartTime , @dtmEndTime))
				THEN DATEDIFF(mi, @dtmStartTime , @dtmEndTime)
				ELSE SUM(FreshPaperRuntime) END),						
		SUM(FreshRollsRan),
		SUM(StoragePaperStops),
		SUM(StoragePaperDT), 
		--SUM(StoragePaperRuntime),
		(CASE WHEN (SUM(StoragePaperRuntime) > DATEDIFF(mi, @dtmStartTime , @dtmEndTime))
				THEN DATEDIFF(mi, @dtmStartTime , @dtmEndTime)
				ELSE SUM(StoragePaperRuntime) END),						
		SUM(StorageRollsRan), 
		SUM(TotalRollsRan), 
		SUM(FreshELP), 
		SUM(StorageELP),
		SUM(TotalELP)
	FROM @Summary	pr
	JOIN @Lines		l	ON pr.pldesc = l.LineDesc 
	WHERE Type = 'CVTG'
		AND Grouping = 'Line-PaperSource'
		AND (pr.PaperLine <> 'NoAssignedPRID')
			--OR l.IsGenIV <> 1) -- No GenIV
	GROUP BY PlDesc
	
-- Update Rolls
UPDATE pr
	SET StorageRollsRan = ISNULL((SELECT SUM(StorageRollsRan) 
								FROM @Summary		r
								WHERE r.Type		= pr.Type
									AND r.Grouping	= 'Line-PaperSource'
									AND r.PLDesc	= pr.PLDesc
								GROUP BY r.Type, r.Grouping, r.PLDesc), 0)
	FROM @Summary	pr
	WHERE Type = 'CVTG'
		AND Grouping = 'Line'
	
UPDATE pr
	SET FreshRollsRan = ISNULL((SELECT SUM(FreshRollsRan) 
								FROM @Summary		r
								WHERE r.Type		= pr.Type
									AND r.Grouping	= 'Line-PaperSource'
									AND r.PLDesc	= pr.PLDesc
								GROUP BY r.Type, r.Grouping, r.PLDesc), 0)
	FROM @Summary	pr
	WHERE Type = 'CVTG'
		AND Grouping = 'Line'
	
UPDATE pr
	SET TotalRollsRan = StorageRollsRan + FreshRollsRan
						--ISNULL((SELECT SUM(TotalRollsRan) 
						--		FROM @Summary		r
						--		WHERE r.Type		= pr.Type
						--			AND r.Grouping	= 'Line-PaperSource'
						--			AND r.PLDesc	= pr.PLDesc
						--		GROUP BY r.Type, r.Grouping), 0)
	FROM @Summary	pr
	WHERE Type = 'CVTG'
		AND Grouping = 'Line'
		
--		
INSERT INTO @Summary (
			Type			
			,Orden
			,Grouping			
			,PLDesc				
			,PaperLine			
			,UWS					
			,Runtime				
			,PaperStops			
			,DTDueToStops		
			,EffDTRateLoss		
			,TotalPaperDT		
			,FreshPaperStops		
			,FreshPaperDT		
			,FreshPaperRuntime	
			,FreshRollsRan		
			,StoragePaperStops	
			,StoragePaperDT		
			,StoragePaperRuntime	
			,StorageRollsRan		
			,TotalRollsRan			)
	SELECT 	'CVTG',
			4,
			'overall-totals',
			'',
			''					,
			'Totals'									,
			SUM(Runtime)						, 
			SUM(PaperStops	)						,
			SUM(DTDueToStops	)					,
			SUM(EffDTRateLoss	)					,
			SUM(TotalPaperDT	)					,
			SUM(FreshPaperStops	)					,
			SUM(FreshPaperDT	)					,
			SUM(FreshPaperRuntime)					,
			SUM(FreshRollsRan	)					,
			SUM(StoragePaperStops	)				,
			SUM(StoragePaperDT	)					,
			SUM(StoragePaperRuntime)					,
			SUM(StorageRollsRan	)					,
			SUM(TotalRollsRan	)					
			--SUM(FreshELP		)					,
			--SUM(StorageELP	)						,
			--SUM(TotalELP	)						
		FROM @Summary
		WHERE Type = 'CVTG'
		AND Grouping = 'Line'

--SELECT '@Summary', * FROM @Summary
--	WHERE Type = 'CVTG' AND Grouping LIKE 'Line'
	--AND TotalELP>0
--RETURN

--PM
INSERT INTO @Summary
SELECT	'PM',
		1,
		'Line-PaperRunBy-UWS',
		prs.PaperSourcePM																[Paper Machine],
		--prs.PaperSource																[Paper Machine],
		pl.linedesc																	[Paper Run By],
		prs.UWS																		[UWS],
		-- FO-04637
		(CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
					--AND pl.linedesc LIKE 'PP FF%'	
				THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)))
				ELSE SUM((COALESCE(prs.Runtime, 0.0)))END) / 60.0					[Paper Runtime],		
		
		--SUM(COALESCE(prs.ScheduledDT, 0.0))/60.0									ScheduledDT,
		--(CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
		--			--AND pl.LineDesc LIKE 'PP FF%'		
		--		THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) - SUM(COALESCE(prs.ScheduledDT, 0.0)))
		--		ELSE SUM((COALESCE(prs.Runtime, 0.0)) - COALESCE(prs.ScheduledDT, 0.0)) 
		--	END ) / 60.0															[Old Paper Runtime],						
		-- INC6205503
		--SUM(prs.TotalRuntime)/60.0													PaperRuntimeNew, 
		--
		SUM(COALESCE(prs.ELPStops, 0))												[Paper Stops],
		SUM(CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))							[DT due to Stops],
		SUM(COALESCE(prs.RLELPDowntime, 0.0))										[Eff. DT (Rate Loss)],
		SUM((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0))) 
			+ (COALESCE(prs.RLELPDowntime, 0.0)))									[Total Paper DT],
		SUM(CONVERT(FLOAT, prs.FreshStops))											[Fresh Paper Stops],
		SUM((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0))) 
			+ (COALESCE(prs.FreshRLELPDT, 0.0))) 									[Fresh Paper DT],
		-- FO-04637
		SUM((COALESCE(prs.FreshRuntime, 0.0))) / 60.0								[Fresh Paper Runtime],
		--SUM((COALESCE(prs.FreshRuntime, 0.0)) - 
		--	COALESCE(prs.FreshSchedDT, 0.0)) / 60.0									[Old Fresh Paper Runtime],
		--
		SUM(COALESCE(prs.FreshRolls, 0))											[Fresh Rolls Ran],
		SUM(CONVERT(FLOAT, COALESCE(prs.StorageStops, 0)))							[Storage Paper Stops],
		SUM((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0))) 
			+ (COALESCE(prs.StorageRLELPDT, 0.0)))									[Storage Paper DT],
		-- FO-04637
		SUM((COALESCE(prs.StorageRuntime, 0.0))) / 60.0								[Storage Paper Runtime],
		--SUM((COALESCE(prs.StorageRuntime, 0.0)) 
		--	- COALESCE(prs.StorageSchedDT, 0.0)) / 60.0								[Old Storage Paper Runtime],
		--
		SUM(COALESCE(prs.StorageRolls, 0))											[Storage Rolls Ran],
		SUM(COALESCE(prs.TotalRolls, 0))											[Total Rolls Ran], 
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0)))) > 0.0 
				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
					(SUM(COALESCE(prs.FreshRuntime, 0.0))/60.0))
			ELSE 0.0 END															[Fresh ELP%],
		--
		--CASE WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0)))) > 0.0 
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
		--			(SUM(COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))/60.0))
		--	ELSE 0.0 END															[Old Fresh ELP%],
		--
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0))) / 60.0) > 0.0 
				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
					(SUM(COALESCE(prs.StorageRuntime, 0.0))/60.0))
			ELSE 0.0 END															[Storage ELP%],
		-- 
		--CASE WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))) / 60.0) > 0.0 
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
		--			(SUM(COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))/60.0))
		--	ELSE 0.0 END															[Old Storage ELP%],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0))) / 60.0) > 0.0 
				THEN CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
							--AND pl.linedesc LIKE 'PP FF%' 
						THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
								(((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) )/60.0))
						ELSE (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
							(SUM(COALESCE(prs.Runtime, 0.0))/60.0))
						END
				ELSE 0.0 END														[Total ELP%]
		--, CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))) / 60.0) > 0.0 
		--		THEN CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
		--					--AND pl.linedesc LIKE 'PP FF%' 
		--				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--						(((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) - (SUM(COALESCE(prs.ScheduledDT, 0.0))))/60.0))
		--				ELSE (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--					(SUM(COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))/60.0))
		--				END
		--		ELSE 0.0 END														[Old Total ELP%]
	FROM @PRSummaryUWS prs
	LEFT JOIN @Lines pl ON prs.CvtgPLID = pl.PLID
	GROUP BY prs.PaperSourcePM, pl.linedesc, prs.UWS
	ORDER BY prs.PaperSourcePM, pl.linedesc, prs.UWS

INSERT INTO @Summary
SELECT	'PM',
		2,
		'Line-PaperRunBy',
		prs.PaperSourcePM															[Paper Machine],
		--prs.PaperSource																[Paper Machine],
		pl.linedesc																	[Paper Run By],
		''																			[UWS],
		-- FO-04637
		(CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime))
					--AND pl.linedesc LIKE 'PP FF%'	
				THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)))
				ELSE SUM((COALESCE(prs.Runtime, 0.0)))END) / 60.0					[Paper Runtime],						
		--SUM(COALESCE(prs.ScheduledDT, 0.0))/60.0									ScheduledDT,
		--(CASE 
		--	WHEN (SUM(COALESCE(prs.Runtime, 0.0)) > DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
		--		--AND pl.linedesc LIKE 'PP FF%' 
		--		THEN ((DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) - SUM(COALESCE(prs.ScheduledDT, 0.0)))
		--	ELSE SUM((COALESCE(prs.Runtime, 0.0))) 
		--	END) / 60.0																[Old Paper Runtime],						
		--
		SUM(COALESCE(prs.ELPStops, 0))												[Paper Stops],
		SUM(CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))							[DT due to Stops],
		SUM(COALESCE(prs.RLELPDowntime, 0.0))										[Eff. DT (Rate Loss)],
		SUM((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)) ) 
			+ (COALESCE(prs.RLELPDowntime, 0.0)))									[Total Paper DT],
		SUM(CONVERT(FLOAT, prs.FreshStops))											[Fresh Paper Stops],
		SUM((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0))) 
			+ (COALESCE(prs.FreshRLELPDT, 0.0)))									[Fresh Paper DT],
		-- FO-04637
		SUM((COALESCE(prs.FreshRuntime, 0.0)) ) / 60.0								[Fresh Paper Runtime],
		--SUM((COALESCE(prs.FreshRuntime, 0.0)) 
			--- COALESCE(prs.FreshSchedDT, 0.0)) / 60.0								[Old Fresh Paper Runtime],
		SUM(COALESCE(prs.FreshRolls, 0))											[Fresh Rolls Ran],
		SUM(CONVERT(FLOAT, COALESCE(prs.StorageStops, 0)))							[Storage Paper Stops],
		SUM((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0))) 
			+ (COALESCE(prs.StorageRLELPDT, 0.0)))									[Storage Paper DT],
		-- FO-04637
		SUM((COALESCE(prs.StorageRuntime, 0.0))) / 60.0								[Storage Paper Runtime],
		--SUM((COALESCE(prs.StorageRuntime, 0.0)) 
		--	- COALESCE(prs.StorageSchedDT, 0.0)) / 60.0								[Old Storage Paper Runtime],
		--
		SUM(COALESCE(prs.StorageRolls, 0))											[Storage Rolls Ran],
		SUM(COALESCE(prs.TotalRolls, 0))											[Total Rolls Ran],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0))) / 60.0) > 0.0
				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
				(SUM(COALESCE(prs.FreshRuntime, 0.0))/60.0))
			ELSE 0.0 END															[Fresh ELP%],
		--
		--CASE WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))) / 60.0) > 0.0
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
		--		(SUM(COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))/60.0))
		--	ELSE 0.0 END															[Old Fresh ELP%],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0))) / 60.0) > 0.0 
				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
					(SUM(COALESCE(prs.StorageRuntime, 0.0))/60.0))
				ELSE 0.0 END														[Storage ELP%],
		-- 
		--CASE WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))) / 60.0) > 0.0 
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
		--			(SUM(COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))/60.0))
		--		ELSE 0.0 END														[Old Storage ELP%],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0))) / 60.0) > 0.0 
			THEN CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) < DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
							--AND pl.LineDesc LIKE 'PP FF%' 
						THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
							(SUM(COALESCE(prs.Runtime, 0.0))/60.0))
						ELSE (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
							(DATEDIFF(ss, @dtmStartTime , @dtmEndTime)/60.0))
						END
			ELSE 0.0 END															[Total ELP%]
		--, CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))) / 60.0) > 0.0 
		--	THEN CASE WHEN (SUM(COALESCE(prs.Runtime, 0.0)) < DATEDIFF(ss, @dtmStartTime , @dtmEndTime)) 
		--					--AND pl.LineDesc LIKE 'PP FF%' 
		--				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--					(SUM(COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))/60.0))
		--				ELSE (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) / 
		--					(DATEDIFF(ss, @dtmStartTime , @dtmEndTime)/60.0))
		--				END
		--	ELSE 0.0	END															[Old Total ELP%]
	FROM @PRSummaryLinePS prs
	LEFT JOIN @Lines pl ON prs.CvtgPLID = pl.PLID
	GROUP BY pl.LineDesc, prs.PaperSourcePM
	ORDER BY pl.LineDesc, prs.PaperSourcePM
	OPTION (KEEP PLAN)
	
-- Update Rolls
UPDATE pr
	SET StorageRollsRan = ISNULL((SELECT SUM(StorageRollsRan) 
								FROM @Summary		r
								WHERE r.Type		= pr.Type
									AND r.Grouping	= 'Line-PaperRunBy-UWS'
									AND r.PLDesc	= pr.PLDesc
									AND r.PaperLine = pr.PaperLine
								GROUP BY r.Type, r.Grouping, r.PLDesc, r.PaperLine), 0)
	FROM @Summary	pr
	WHERE pr.PaperLine <> 'NoAssignedPRID'
		AND Type = 'PM'
		AND Grouping = 'Line-PaperRunBy'
	
UPDATE pr
	SET FreshRollsRan = ISNULL((SELECT SUM(FreshRollsRan) 
								FROM @Summary		r
								WHERE r.Type		= pr.Type
									AND r.Grouping	= 'Line-PaperRunBy-UWS'
									AND r.PLDesc	= pr.PLDesc
									AND r.PaperLine = pr.PaperLine
								GROUP BY r.Type, r.Grouping, r.PLDesc, r.PaperLine), 0)
	FROM @Summary	pr
	WHERE pr.PaperLine <> 'NoAssignedPRID'
		AND Type = 'PM'
		AND Grouping = 'Line-PaperRunBy'
	
UPDATE pr
	SET TotalRollsRan = StorageRollsRan + FreshRollsRan
						--ISNULL((SELECT SUM(TotalRollsRan) 
						--		FROM @Summary		r
						--		WHERE r.Type		= pr.Type
						--			AND r.Grouping	= 'Line-PaperRunBy-UWS'
						--			AND r.PLDesc	= pr.PLDesc
						--			AND r.PaperLine = pr.PaperLine
						--		GROUP BY r.Type, r.Grouping, r.PLDesc, r.PaperLine), 0)
	FROM @Summary	pr
	WHERE Type = 'PM'
		AND Grouping = 'Line-PaperRunBy'
		--AND pr.PaperLine <> 'NoAssignedPRID'

----------------------------------------------------------------------------------------------------
INSERT INTO @Summary
SELECT	'PM' Type,
		3,
		'Line' Grouping,
		pr.PLDesc ,
		'' PaperLine,
		'' UWS,
		(CASE WHEN (SUM(Runtime) > (DATEDIFF(mi, @dtmStartTime , @dtmEndTime) * pdc.CVTGs))
				THEN DATEDIFF(mi, @dtmStartTime , @dtmEndTime) * pdc.CVTGs
				ELSE SUM(Runtime) END),						
		SUM(PaperStops),
		SUM(DTDueToStops),
		SUM(EffDTRateLoss),
		SUM(TotalPaperDT),
		SUM(FreshPaperStops), 
		SUM(FreshPaperDT),
		(CASE WHEN (SUM(FreshPaperRuntime) > (DATEDIFF(mi, @dtmStartTime , @dtmEndTime) * pdc.CVTGs))
				THEN DATEDIFF(mi, @dtmStartTime , @dtmEndTime) * pdc.CVTGs
				ELSE SUM(FreshPaperRuntime) END),						
		SUM(FreshRollsRan),
		SUM(StoragePaperStops),
		SUM(StoragePaperDT), 
		(CASE WHEN (SUM(StoragePaperRuntime) > (DATEDIFF(mi, @dtmStartTime , @dtmEndTime) * pdc.CVTGs))
				THEN DATEDIFF(mi, @dtmStartTime , @dtmEndTime) * pdc.CVTGs
				ELSE SUM(StoragePaperRuntime) END),						
		SUM(StorageRollsRan), 
		SUM(TotalRollsRan), 
		SUM(FreshELP), 
		SUM(StorageELP),
		SUM(TotalELP)
	FROM @Summary		pr
	JOIN @Lines			l	ON pr.PaperLine = l.LineDesc 
	JOIN @PMDataCVTG	pdc ON pr.pldesc = pdc.papersource
	WHERE Type = 'PM'
		AND Grouping = 'Line-PaperRunBy'
		AND (pr.PaperLine <> 'NoAssignedPRID' OR l.IsGenIV <> 1) -- No GenIV
	GROUP BY pr.PlDesc
		, pdc.CVTGs
			
--SELECT '@Summary', * FROM @Summary WHERE Type = 'PM'
--RETURN

-- Update Rolls
UPDATE pr
	SET StorageRollsRan = ISNULL((SELECT SUM(StorageRollsRan) 
								FROM @Summary		r
								WHERE r.Type		= pr.Type
									AND r.Grouping	= 'Line-PaperRunBy'
									AND r.PLDesc	= pr.PLDesc
								GROUP BY r.Type, r.Grouping, r.PLDesc), 0)
	FROM @Summary	pr
	WHERE Type = 'PM'
		AND Grouping = 'Line'

UPDATE pr
	SET FreshRollsRan = ISNULL((SELECT SUM(FreshRollsRan) 
								FROM @Summary		r
								WHERE r.Type		= pr.Type
									AND r.Grouping	= 'Line-PaperRunBy'
									AND r.PLDesc	= pr.PLDesc
								GROUP BY r.Type, r.Grouping, r.PLDesc), 0)
	FROM @Summary	pr
	WHERE Type = 'PM'
		AND Grouping = 'Line'
	
UPDATE pr
	SET TotalRollsRan = StorageRollsRan + FreshRollsRan
						--ISNULL((SELECT SUM(TotalRollsRan) 
						--		FROM @Summary		r
						--		WHERE r.Type		= pr.Type
						--			AND r.Grouping	= 'Line-PaperRunBy'
						--			AND (r.PLDesc	= pr.PLDesc)
						--		GROUP BY r.Type, r.Grouping, r.PLDesc), 0)
	FROM @Summary	pr
	WHERE Type = 'PM'
		AND Grouping = 'Line'

--UPDATE pr
--	SET TotalRollsRan = TotalRollsRan + ISNULL((SELECT SUM(TotalRollsRan) 
--								FROM @Summary		r
--								WHERE r.Type		= pr.Type
--									AND r.Grouping	= 'Line-PaperRunBy'
--									AND (r.PLDesc LIKE 'NoAssignedPRID')
--								GROUP BY r.Type, r.Grouping, r.PLDesc), 0)
--	FROM @Summary	pr
--	WHERE Type = 'PM'
--		AND Grouping = 'Line'
				
--Update FreshELP AND StorageELP not using 'NoAssignedPRID'
UPDATE @Summary
	SET FreshELP = CASE WHEN pr.PaperLine LIKE 'NoAssignedPRID'  THEN 0 
					ELSE 
						CASE 
						WHEN pr.FreshPaperRuntime > 0.0
							THEN pr.FreshPaperDT / pr.FreshPaperRuntime
						ELSE 0.0 END
					END
	FROM @Summary	pr
	WHERE Type = 'PM'
		AND Grouping = 'Line'
	
UPDATE @Summary
	SET StorageELP = CASE WHEN pr.PaperLine LIKE 'NoAssignedPRID'  THEN 0 
					ELSE 
						CASE 
						WHEN pr.StoragePaperRuntime > 0.0
							THEN pr.StoragePaperDT / pr.StoragePaperRuntime
						ELSE 0.0 END
					END
	FROM @Summary	pr
	WHERE Type = 'PM'
		AND Grouping = 'Line'

INSERT INTO @Summary(
			Type				
			,Orden
			,Grouping			
			,PLDesc				
			,PaperLine			
			,UWS					
			,Runtime				
			,PaperStops			
			,DTDueToStops		
			,EffDTRateLoss		
			,TotalPaperDT		
			,FreshPaperStops		
			,FreshPaperDT		
			,FreshPaperRuntime	
			,FreshRollsRan		
			,StoragePaperStops	
			,StoragePaperDT		
			,StoragePaperRuntime	
			,StorageRollsRan		
			,TotalRollsRan		)
	SELECT 	'PM',
			4,
			'overall-totals',
			'',
			''					,
			'Totals'									,
			SUM(Runtime)						, 
			SUM(PaperStops	)						,
			SUM(DTDueToStops	)					,
			SUM(EffDTRateLoss	)					,
			SUM(TotalPaperDT	)					,
			SUM(FreshPaperStops	)					,
			SUM(FreshPaperDT	)					,
			SUM(FreshPaperRuntime)					,
			SUM(FreshRollsRan	)					,
			SUM(StoragePaperStops	)				,
			SUM(StoragePaperDT	)					,
			SUM(StoragePaperRuntime)					,
			SUM(StorageRollsRan	)					,
			SUM(TotalRollsRan	)					
			--SUM(FreshELP		)					,
			--SUM(StorageELP	)						,
			--SUM(TotalELP	)						
	FROM @Summary
	WHERE Type = 'PM'
	AND Grouping = 'Line'

UPDATE s
	SET TotalELP = CASE WHEN Runtime > 0 THEN TotalPaperDT / Runtime ELSE 0 END, 
		FreshELP = CASE WHEN FreshPaperRuntime > 0 THEN FreshPaperDT / FreshPaperRuntime ELSE 0 END, 
		StorageELP = CASE WHEN StoragePaperRuntime > 0 THEN StoragePaperDT / StoragePaperRuntime ELSE 0 END
	FROM @Summary s
	--WHERE (s.Grouping = 'overall-totals' OR s.Grouping = 'Line')
	--AND s.Type = 'PM'
	
--select '@Summary', * from @Summary
--	WHERE Type = 'PM' 
--	--AND Grouping = 'Line'
--	order by orden, PLDesc, PaperLine, uws
--RETURN

----------------------------------------------------------------------------------------------------

--Causes
INSERT INTO @CausePivot
	SELECT	'CAUSE',
			'Line-Cause-PaperRunBy',
			prs.PaperMachine															[Paper Machine],	
			prs.PaperRunBy																[Paper Run By],
			''																			[UWS], 
			prs.Cause																	[Cause],
			SUM(COALESCE(prs.Runtime, 0.0))												[Runtime],					
			SUM(COALESCE(prs.ELPStops, 0))												[Paper Stops],
			SUM(CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))							[DT due to Stops],
			SUM(COALESCE(prs.RLELPDowntime, 0.0))										[Eff. DT (Rate Loss)],
			SUM((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0))) 
				+ (COALESCE(prs.RLELPDowntime, 0.0)))									[Total Paper DT],
			SUM(CONVERT(FLOAT, prs.FreshStops))											[Fresh Paper Stops],
			SUM((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0))))							[Fresh Paper DT],
			SUM((CONVERT(FLOAT, COALESCE(prs.FreshRLELPDT, 0.0))))						[Fresh Eff. DT (Rate Loss)],
			SUM(COALESCE(prs.FreshRuntime, 0.0))										[Fresh Paper Runtime],
			SUM(COALESCE(prs.FreshRolls, 0))											[Fresh Rolls Ran],
			SUM(CONVERT(FLOAT, COALESCE(prs.StorageStops, 0)))							[Storage Paper Stops],
			SUM((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0))))							[Storage Paper DT],
			SUM((CONVERT(FLOAT, COALESCE(prs.StorageRLELPDT, 0.0))))					[Fresh Eff. DT (Rate Loss)],
			SUM(COALESCE(prs.StorageRuntime, 0.0))										[Storage Paper Runtime],
			SUM(COALESCE(prs.StorageRolls, 0))											[Storage Rolls Ran],
			SUM(COALESCE(prs.TotalRolls, 0))											[Total Rolls Ran],
			-- FO-04637
			CASE 
				WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0)))) > 0.0
					THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
					(SUM(COALESCE(prs.FreshRuntime, 0.0))))
				ELSE 0.0 
			END																			[Fresh ELP%],
			--CASE 
			--	WHEN (SUM((COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0)))) > 0.0
			--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.FreshDT, 0.0)))) + COALESCE(prs.FreshRLELPDT, 0.0)) / 
			--		(SUM(COALESCE(prs.FreshRuntime, 0.0) - COALESCE(prs.FreshSchedDT, 0.0))))
			--	ELSE 0.0 
			--END																			[Old Fresh ELP%],
			-- FO-04637
			CASE 
				WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) ))) > 0.0 
					THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
					(SUM(COALESCE(prs.StorageRuntime, 0.0) )))
					ELSE 0.0 
			END																			[Storage ELP%],
			--CASE 
			--	WHEN (SUM((COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0)))) > 0.0 
			--		THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.StorageDT, 0.0)))) + COALESCE(prs.StorageRLELPDT, 0.0)) / 
			--		(SUM(COALESCE(prs.StorageRuntime, 0.0) - COALESCE(prs.StorageSchedDT, 0.0))))
			--		ELSE 0.0 
			--END																			[Old Storage ELP%],
			-- FO-04637
			CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0)))) > 0.0 
				THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) 
					/ (SUM(COALESCE(prs.Runtime, 0.0))))-- 
				ELSE 0.0 END															[Total ELP%],
			--CASE WHEN (SUM((COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0)))) > 0.0 
			--	THEN (SUM(((CONVERT(FLOAT, COALESCE(prs.ELPDowntime, 0.0)))) + COALESCE(prs.RLELPDowntime, 0.0)) 
			--		/ (SUM(COALESCE(prs.Runtime, 0.0) - COALESCE(prs.ScheduledDT, 0.0))))-- 
			--	ELSE 0.0 END															[Old Total ELP%],
			SUM(ScheduledDT)/60.0														ScheduledDT,
			SUM(FreshSchedDT)/60.0														FreshSchedDT,
			SUM(StorageSchedDT)/60.0													StorageSchedDT
		FROM @PRSummaryPMRunByCause prs
		JOIN @Lines					l	ON prs.PLID = l.PLId
										-- prs.PaperRunBy = l.LineDesc
		GROUP BY prs.Cause, prs.PaperMachine, prs.PaperRunBy, l.StartTime, l.EndTime
		ORDER BY prs.Cause, prs.PaperMachine, prs.PaperRunBy

-- Update runtime (PRB0079858)
UPDATE c 
	SET c.Runtime				= s.runtime,
		c.FreshPaperRuntime		= s.FreshPaperRuntime,
		c.StoragePaperRuntime	= s.StoragePaperRuntime
	FROM @Summary		s
	JOIN @CausePivot	c	ON s.PLDesc	= c.PLDesc
							AND REPLACE(REPLACE(s.PaperLine,'TT ', ''),'PP ','') = REPLACE(REPLACE(c.PaperLine,'TT ', ''),'PP ','')
	WHERE s.Type = 'PM' 
	AND s.Grouping = 'Line-PaperRunBy'

-- Update ELPs 	
UPDATE @CausePivot
	SET TotalELP = CASE WHEN Runtime > 0 THEN TotalPaperDT / Runtime ELSE 0 END, 
		FreshELP = CASE WHEN FreshPaperRuntime > 0 THEN FreshPaperDT / FreshPaperRuntime ELSE 0 END, 
		StorageELP = CASE WHEN StoragePaperRuntime > 0 THEN StoragePaperDT / StoragePaperRuntime ELSE 0 END

--select '@CausePivot', * from @CausePivot prs
--return

-----------------------------------------------------------------------------------
--SELECT 'Output. '
-----------------------------------------------------------------------------------
--CVTG Output
-----------------------------------------------------------------------------------
SELECT	type,
		Grouping, 
		PLDesc, 
		PaperLine, 
		UWS,
		Runtime					, 
		PaperStops				,
		DTDueToStops			,
		EffDTRateLoss			,
		TotalPaperDT			,
		FreshPaperStops			,
		FreshPaperDT			,
		FreshPaperRuntime		,
		FreshRollsRan			,
		StoragePaperStops		,
		StoragePaperDT			,
		StoragePaperRuntime		,
		StorageRollsRan			,
		TotalRollsRan			,
		FreshELP				,
		StorageELP				,
		TotalELP				
	FROM @Summary 
	WHERE type = 'CVTG'
	ORDER BY type, orden, PLDesc, PaperLine, UWS


-----------------------------------------------------------------------------------
--PM Output
-----------------------------------------------------------------------------------
SELECT type,
		Grouping, 
		PLDesc, 
		PaperLine, 
		UWS,
		Runtime					, 
		PaperStops				,
		DTDueToStops			,
		EffDTRateLoss			,
		TotalPaperDT			,
		FreshPaperStops			,
		FreshPaperDT			,
		FreshPaperRuntime		,
		FreshRollsRan			,
		StoragePaperStops		,
		StoragePaperDT			,
		StoragePaperRuntime		,
		StorageRollsRan			,
		TotalRollsRan			,
		FreshELP				,
		StorageELP				,
		TotalELP				
	FROM @Summary 
	WHERE type = 'PM' 
	AND PLDesc IS NOT NULL
	ORDER BY type, orden, PLDesc, PaperLine, UWS

-----------------------------------------------------------------------------------
--Cause Summary Output
-----------------------------------------------------------------------------------
SELECT * FROM @CausePivot
	ORDER BY PLDesc, PaperLine, UWS, Cause
--return

-----------------------------------------------------------------------------------
--Trends Output
-----------------------------------------------------------------------------------
--SELECT	
--		prs.PLDesc [Line],
--		prs.Date,	
--		CASE 
--			WHEN (SUM((COALESCE(FreshRuntime, 0.0) - COALESCE(FreshSchedDT, 0.0))) / 60.0) > 0.0
--				THEN (SUM(((CONVERT(FLOAT, COALESCE(FreshDT, 0.0)))) + COALESCE(FreshRLELPDT, 0.0)) / 
--					(SUM(COALESCE(FreshRuntime, 0.0) - COALESCE(FreshSchedDT, 0.0))/60.0))
--			ELSE 0.0 
--		END																			[FreshELP],

--		CASE 
--			WHEN (SUM((COALESCE(StorageRuntime, 0.0) - COALESCE(StorageSchedDT, 0.0))) / 60.0) > 0.0 
--				THEN (SUM(((CONVERT(FLOAT, COALESCE(StorageDT, 0.0)))) + COALESCE(StorageRLELPDT, 0.0)) / 
--					(SUM(COALESCE(StorageRuntime, 0.0) - COALESCE(StorageSchedDT, 0.0))/60.0))
--			ELSE 0.0 
--		END																			[StorageELP],

--		CASE 
--			WHEN (SUM((COALESCE(Runtime, 0.0) - COALESCE(ScheduledDT, 0.0))) / 60.0) > 0.0
--				THEN
--							(SUM(((CONVERT(FLOAT, COALESCE(ELPDowntime, 0.0)))) + COALESCE(RLELPDowntime, 0.0)/60.0) / 
--							(SUM(COALESCE(Runtime, 0.0) - COALESCE(ScheduledDT, 0.0))/60.0))
--				ELSE 0.0
--		END																			[TotalELP],
--		SUM(ISNULL(ELPStops, 0)) [Stops]
--	FROM @TrendsDataOld prs
--	GROUP BY prs.Date, prs.PLDesc

SELECT -- 'NewTrend', 
		prs.PM_PLID,
		prs.PM_PLDesc	[PaperMachine],
		prs.PLId,
		prs.PLDesc		[Line],
		prs.Date,	
		-- FO-04637
		CASE WHEN (SUM((COALESCE(FreshRuntime, 0.0) )) / 60.0) > 0.0
				THEN (SUM(((CONVERT(FLOAT, COALESCE(FreshDT, 0.0)))) + COALESCE(FreshRLELPDT, 0.0)) / 
					(SUM(COALESCE(FreshRuntime, 0.0) )/60.0))
			ELSE 0.0 END															[FreshELP],
		--CASE WHEN (SUM((COALESCE(FreshRuntime, 0.0) - COALESCE(FreshSchedDT, 0.0))) / 60.0) > 0.0
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(FreshDT, 0.0)))) + COALESCE(FreshRLELPDT, 0.0)) / 
		--			(SUM(COALESCE(FreshRuntime, 0.0) - COALESCE(FreshSchedDT, 0.0))/60.0))
		--	ELSE 0.0 END															[Old FreshELP],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(StorageRuntime, 0.0) )) / 60.0) > 0.0 
				THEN (SUM(((CONVERT(FLOAT, COALESCE(StorageDT, 0.0)))) + COALESCE(StorageRLELPDT, 0.0)) / 
					(SUM(COALESCE(StorageRuntime, 0.0) )/60.0))
			ELSE 0.0 END															[StorageELP],
		--CASE WHEN (SUM((COALESCE(StorageRuntime, 0.0) - COALESCE(StorageSchedDT, 0.0))) / 60.0) > 0.0 
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(StorageDT, 0.0)))) + COALESCE(StorageRLELPDT, 0.0)) / 
		--			(SUM(COALESCE(StorageRuntime, 0.0) - COALESCE(StorageSchedDT, 0.0))/60.0))
		--	ELSE 0.0 END															[Old StorageELP],
		-- FO-04637
		CASE WHEN (SUM((COALESCE(Runtime, 0.0))) / 60.0) > 0.0
				THEN (SUM(((CONVERT(FLOAT, COALESCE(ELPDowntime, 0.0)))) + COALESCE(RLELPDowntime, 0.0)/60.0) / 
					(SUM(COALESCE(Runtime, 0.0) )/60.0))
				ELSE 0.0	END														[TotalELP],
		--CASE WHEN (SUM((COALESCE(Runtime, 0.0) - COALESCE(ScheduledDT, 0.0))) / 60.0) > 0.0
		--		THEN (SUM(((CONVERT(FLOAT, COALESCE(ELPDowntime, 0.0)))) + COALESCE(RLELPDowntime, 0.0)/60.0) / 
		--			(SUM(COALESCE(Runtime, 0.0) - COALESCE(ScheduledDT, 0.0))/60.0))
		--		ELSE 0.0	END														[Old TotalELP],
		SUM(ISNULL(ELPStops, 0)) [Stops]
	FROM @TrendsData prs
	GROUP BY prs.PLId, prs.PLDesc, prs.Date, prs.PM_PLDesc, prs.PM_PLID
	ORDER BY date ASC, prs.PM_PLID DESC, prs.PLDesc desc

-----------------------------------------------------------------------------------
--	Stops AND Downtime output section
-----------------------------------------------------------------------------------
SELECT	TEDetId,
		StartTime,
		EndTime,
		PM, 
		PLId,
		PLDesc, 
		PUId, 
		PuDesc,
		Reason2,
		Duration,
		Stop,
		Fresh,
		MinorStop,
		Comments,
		RateLoss,
		UWS1, 
		ParentUWS1,
		UWS2, 
		ParentUWS2,
		UWS3,
		ParentUWS3,
		UWS4,
		ParentUWS4
	FROM @ELPStops
	ORDER BY TEDetId

-----------------------------------------------------------------------------------
--	Raw Data output section
-----------------------------------------------------------------------------------
SELECT EventID								[EventID],
	SourceID								[SourceID],
	UWS										[UWS],
	InputOrder								[InputOrder],
	PRConvStartTime							[PRoll Conv StartTime],
	PRConvEndTime							[PRoll Conv EndTime],
	ParentPRID								[PRID],
	ParentPM								[PRoll Made By],
	ISNULL(ParentTeam, '')					[Parent Team],
	ISNULL(ParentRollTimestamp, '')			[PRoll TimeStamp],					
	ISNULL(ParentRollAge, '')				[PRoll Age (days)],
	ISNULL(TotalStops, 0)					[Total Stops],
	ISNULL(TotalDowntime, 0)/60.0			[ELP DT (min)],
	ISNULL(TotalRateLossDT, 0)/60.0			[ELP Rate Loss Eff DT (min)],
	ISNULL(TotalRuntime, 0)/60.0			[Raw PRoll Runtime (min)],
	ISNULL(TotalScheduledDT, 0)/60.0		[Scheduled DT (min)],
	ISNULL(TotalRuntime-TotalScheduledDT, 0)/60.0	[Paper Runtime (min)],
	NPTStatus								[NPT Status],
	ISNULL(GrandParentPRID, '')				[GPRID],
	ISNULL(GrandParentPM, '')				[GRoll Made By],
	ISNULL(GrandParentTeam, '')				[GParent Team],
	ISNULL(ParentPUDesc, '')				[Source Event PUDesc],
	ISNULL(ProdDesc, '')					[Cvtg Product]
FROM @RawData
	--WHERE TotalStops > 0
ORDER BY UWS, PRConvStartTime, PRConvEndTime

-----------------------------------------------------------------------------------
--	Time Preview
-----------------------------------------------------------------------------------
SELECT
		 RcdIdx		
		,PLId		
		,LineDesc		
		,CONVERT(VARCHAR, StartTime, 120)	AS StartTime	
		,CONVERT(VARCHAR, EndTime, 120)		AS EndTime	
		,CONVERT(VARCHAR, GETDATE(), 120)	AS RunTime
	FROM @Lines

RETURN
GO

GRANT  EXECUTE  ON [dbo].[spRptELP]  TO OpDBWriter
GO
