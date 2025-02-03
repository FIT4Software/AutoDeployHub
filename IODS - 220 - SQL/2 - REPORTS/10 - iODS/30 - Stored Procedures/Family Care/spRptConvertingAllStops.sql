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
		@SP_Name	= 'spRptConvertingAllStops',
		@Inputs		= 5, 
		@Version	= '1.2'  

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
				
DROP PROCEDURE [dbo].[spRptConvertingAllStops]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptConvertingAllStops
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Damian Campana - Arido Software
-- Date created			: 2018-10-22
-- Version 				: 1.2
-- SP Type				: Report Stored Procedure
-- Caller				: Stored Procedure
-- Description			: This stored procedure provides the data for All the stops.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-10-22		Damian Campana     		Initial Release
-- 1.1		2019-07-10		Damian Campana			Add StartTime & EndTime parameters for filter <User Defined>
-- 1.2		2020-09-05		Pablo Galanzini			Add new fields used for Rate Loss (EffectiveDowntime, LineActualSpeed and RateLossPRID)
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================
CREATE PROCEDURE [dbo].[spRptConvertingAllStops]
--DECLARE
	 @strLineId			NVARCHAR(MAX)
	,@timeOption		INT
	,@strNPT			NVARCHAR(MAX) 	= ''
	,@dtmStartTime		DATETIME		= NULL
	,@dtmEndTime		DATETIME		= NULL

--WITH ENCRYPTION
AS
SET NOCOUNT ON

---------------------------------------------------------------------------------------------------
--VARIABLES
---------------------------------------------------------------------------------------------------
DECLARE
		@i							INT
---------------------------------------------------------------------------------------------------
DECLARE @Equipment TABLE (
		 RcdIdx						INT IDENTITY							
		,PLId						INT		
		,PUId						INT		
		,StartTime					DATETIME		
		,EndTime					DATETIME		)

---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#DowntimeDetails', 'U') IS NOT NULL  DROP TABLE #DowntimeDetails
	CREATE TABLE #DowntimeDetails(
		  RcdIdx					INT IDENTITY
		 ,StartTime					DATETIME
		 ,EndTime					DATETIME
		 ,StartTimeUTC				DATETIME
		 ,EndTimeUTC				DATETIME
		 ,Duration					DECIMAL(12,3)
		 ,Total_Uptime				FLOAT
		 ,Uptime					DECIMAL(12,3)
		 ,ParentDTId				INT
		 ,Fault						NVARCHAR(100)
		 ,FaultCode					NVARCHAR(30)
		 ,Reason1Id					INT
		 ,Reason1					NVARCHAR(100)
		 ,Reason1Code				NVARCHAR(30)
		 ,Reason1Category			NVARCHAR(500)
		 ,Reason2Id					INT
		 ,Reason2					NVARCHAR(100)
		 ,Reason2Code				NVARCHAR(30)
		 ,Reason2Category			NVARCHAR(500)
		 ,Reason3Id					INT
		 ,Reason3					NVARCHAR(100)
		 ,Reason3Code				NVARCHAR(30)
		 ,Reason3Category			NVARCHAR(500)
		 ,Reason4Id					INT
		 ,Reason4					NVARCHAR(100)
		 ,Reason4Code				NVARCHAR(30)
		 ,Reason4Category			NVARCHAR(500)
		 ,Action1					NVARCHAR(100)
		 ,Action1Code				NVARCHAR(30)
		 ,Action2					NVARCHAR(100)
		 ,Action2Code				NVARCHAR(30)
		 ,Action3					NVARCHAR(100)
		 ,Action3Code				NVARCHAR(30)
		 ,Action4					NVARCHAR(100)
		 ,Action4Code				NVARCHAR(30)
		 ,Planned					BIT
		 ,Location					NVARCHAR(100)
		 ,ProdDesc					NVARCHAR(225)
		 ,ProdCode					NVARCHAR(25)
		 ,ProdFam					NVARCHAR(100)
		 ,ProdGroup					NVARCHAR(100)
		 ,ProcessOrder				NVARCHAR(50)
		 ,TeamDesc					NVARCHAR(25)
		 ,ShiftDesc					NVARCHAR(25)
		 ,LineStatus				NVARCHAR(50)
		 ,DTStatus					INT
		 ,Comments					NVARCHAR(1000)
		 ,MainComments				NVARCHAR(1000)
		 ,PLDesc					NVARCHAR(100)
		 ,PUDesc					NVARCHAR(200)
		 ,PUID						INT
		 ,PLID						INT
		 ,BreakDown					BIT
		 ,ProcFailure				BIT
		 ,TransferFlag				INT
		 ,DeleteFlag				BIT
		 ,Site						NVARCHAR(50)
		 ,TEDetId					INT
		 ,Ts						DATETIME
		 ,IsContraint				BIT
		 ,ProductionDay				DATE
		 ,IsStarved					BIT
		 ,IsBlocked					BIT
		 ,ManualStops				BIT
		 ,MinorStop					INT
		 ,MajorStop					INT
		 ,ZoneDesc					NVARCHAR(255)
		 ,ZoneGrpDesc				NVARCHAR(255)
		 ,LineGroup					NVARCHAR(255)
		 ,StopsEquipFails			INT
		 ,StopsELP					INT
		 ,StopsScheduled			INT
		 ,StopsUnscheduled			INT
		 ,StopsUnscheduledInternal	INT
		 ,StopsUnscheduledBS		INT
		 ,StopsBlockedStarved		INT
		 ,ERTD_ID					INT
		 ,RawRateloss				FLOAT
		 ,RateLossRatio				FLOAT
		 -- Rate Loss
		,EffectiveDowntime			FLOAT NULL
		,LineActualSpeed			FLOAT NULL
		,RateLossPRID				NVARCHAR(50) NULL
		)
-- --------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO @Equipment(PLId) 
	SELECT		String 
	FROM dbo.fnLocal_Split(@strLineId, ',')

	IF @timeOption = -1
	BEGIN
		UPDATE  e
		SET	e.StartTime = @dtmStartTime, e.EndTime = @dtmEndTime
		FROM	@Equipment e  
	END
	ELSE
	BEGIN
		UPDATE	e 
		SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
		FROM	@Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS((SELECT DateDesc 
											   FROM	[dbo].[DATE_DIMENSION]
											   WHERE DateId = @timeOption),e.plid) f
	END
	
--select '@Equipment', * from @Equipment

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Fill downtime details data
-- -----------------------------------------------------------------------------------------------------------------------------
INSERT INTO #DowntimeDetails(
		 StartTime
		,EndTime
		,StartTimeUTC
		,EndTimeUTC
		,Duration
		,Total_Uptime
		,Uptime
		-- Rate Loss
		,EffectiveDowntime
		,LineActualSpeed	
		,RateLossPRID				
		--
		,Fault
		,FaultCode
		,Reason1Id
		,Reason1
		,Reason1Code
		,Reason1Category
		,Reason2Id
		,Reason2
		,Reason2Code
		,Reason2Category
		,Reason3Id
		,Reason3
		,Reason3Code
		,Reason3Category
		,Reason4Id
		,Reason4
		,Reason4Code
		,Reason4Category
		,Action1
		,Action1Code
		,Action2
		,Action2Code
		,Action3
		,Action3Code
		,Action4
		,Action4Code
		,Planned
		,Location
		,ProdDesc
		,ProdCode
		,ProdFam
		,ProdGroup
		,ProcessOrder
		,TeamDesc
		,ShiftDesc
		,LineStatus
		,DTStatus
		,Comments
		,MainComments
		,PLDesc
		,PUDesc
		,PUID
		,PLID
		,BreakDown
		,ProcFailure
		,TransferFlag
		,DeleteFlag
		,Site
		,TEDetId
		,Ts
		,IsContraint
		,ProductionDay
		,IsStarved
		,IsBlocked
		,ManualStops
		,MinorStop
		,MajorStop
		,ZoneDesc
		,ZoneGrpDesc
		,LineGroup
		,StopsEquipFails
		,StopsELP
		,StopsScheduled
		,StopsUnscheduled
		,StopsUnscheduledInternal
		,StopsUnscheduledBS
		,StopsBlockedStarved
		,ERTD_ID
		,RawRateloss
		,RateLossRatio
		)
	SELECT 
		 dud.StartTime
		,dud.EndTime
		,dud.StartTimeUTC
		,dud.EndTimeUTC
		,dud.Duration
		,dud.Total_Uptime
		,dud.Uptime
		-- Rate Loss
		,dud.EffectiveDowntime
		,dud.LineActualSpeed	
		,dud.RateLossPRID				
		--
		,dud.Fault
		,dud.FaultCode
		,dud.Reason1Id
		,dud.Reason1
		,dud.Reason1Code
		,dud.Reason1Category
		,dud.Reason2Id
		,dud.Reason2
		,dud.Reason2Code
		,dud.Reason2Category
		,dud.Reason3Id
		,dud.Reason3
		,dud.Reason3Code
		,dud.Reason3Category
		,dud.Reason4Id
		,dud.Reason4
		,dud.Reason4Code
		,dud.Reason4Category
		,dud.Action1
		,dud.Action1Code
		,dud.Action2
		,dud.Action2Code
		,dud.Action3
		,dud.Action3Code
		,dud.Action4
		,dud.Action4Code
		,dud.Planned
		,dud.Location
		,dud.ProdDesc
		,dud.ProdCode
		,dud.ProdFam
		,dud.ProdGroup
		,dud.ProcessOrder
		,dud.TeamDesc
		,dud.ShiftDesc
		,dud.LineStatus
		,dud.DTStatus
		,dud.Comments
		,dud.MainComments
		,dud.PLDesc
		,dud.PUDesc
		,dud.PUID
		,dud.PLID
		,dud.BreakDown
		,dud.ProcFailure
		,dud.TransferFlag
		,dud.DeleteFlag
		,dud.Site
		,dud.TEDetId
		,dud.Ts
		,dud.IsContraint
		,dud.ProductionDay
		,dud.IsStarved
		,dud.IsBlocked
		,dud.ManualStops
		,dud.MinorStop
		,dud.MajorStop
		,dud.ZoneDesc
		,dud.ZoneGrpDesc
		,dud.LineGroup
		,dud.StopsEquipFails
		,dud.StopsELP
		,dud.StopsScheduled
		,dud.StopsUnscheduled
		,dud.StopsUnscheduledInternal
		,dud.StopsUnscheduledBS
		,dud.StopsBlockedStarved
		,dud.ERTD_ID
		,dud.RawRateloss
		,dud.RateLossRatio
	FROM [dbo].[OpsDB_DowntimeUptime_Data]	dud WITH(NOLOCK)
	LEFT JOIN @Equipment					e	ON e.PLID = dud.PLID 
	WHERE	dud.StartTime >= e.StartTime AND (dud.StartTime <= e.EndTime OR dud.EndTime <= e.EndTime)
        AND dud.DeleteFlag = 0
		AND (dud.LineStatus IN (SELECT String FROM fnLocal_Split(@strNPT,',')) OR @strNPT = '')
    ORDER BY dud.PLDesc, dud.PUDesc, dud.StartTime DESC

--select '#DowntimeDetails', * from #DowntimeDetails

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Update Parent DT Id
-- -----------------------------------------------------------------------------------------------------------------------------
UPDATE		d 
	SET		ParentDTId = ted.TEDetId 
FROM 	#DowntimeDetails d 
JOIN dbo.OpsDB_DowntimeUptime_Data ted WITH(NOLOCK) ON		d.PUid = ted.PUId
										AND d.StartTime = ted.EndTime
										AND d.TEDetId <> ted.TEDetId
WHERE ted.DeleteFlag = 0										
SET @i = 1
WHILE EXISTS (SELECT * FROM #DowntimeDetails dd
				JOIN #DowntimeDetails dd2  ON dd.ParentDTId <> dd2.ParentDTId
				AND dd.StartTime = dd2.EndTime
				AND dd.Uptime = 0) AND @i < 100
BEGIN
	UPDATE		dd 
	SET		dd.ParentDTId = dd2.ParentDTId 
	FROM #DowntimeDetails dd
	JOIN #DowntimeDetails dd2  ON dd.ParentDTId <> dd2.ParentDTId
	AND dd.StartTime = dd2.EndTime
	--AND dd.ParentDTId IS NULL
	SET @i = @i + 1 
END
---------------------------------------------------------------------------------------------------
-- Update ParentId for the splitted records.
---------------------------------------------------------------------------------------------------
--UPDATE #DowntimeDetails
--	SET		ParentDTId = ted.TEDetId
--FROM #DowntimeDetails dd
--JOIN dbo.OpsDB_DowntimeUptime_Data ted WITH(NOLOCK) ON dd.TEDetId = ted.TEDetId
--													AND dd.PUId = ted.PUId
--LEFT JOIN @Equipment					e	ON e.PLID = dd.PLID 
--WHERE	dd.StartTime = e.StartTime
--AND     ted.StartTime < e.StartTime
--AND     dd.ParentDTId IS NULL	

---------------------------------------------------------------------------------------------------
-- Update ParentId for the iODS splitted records.
---------------------------------------------------------------------------------------------------
UPDATE dd
	SET		ParentDTId = dd2.TEDetId
FROM #DowntimeDetails dd
JOIN #DowntimeDetails dd2  ON dd.TEDetId = dd2.TEDetId
AND dd.ParentDTId IS NULL
AND dd.TEDetId <> 0 

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Get data
-- -----------------------------------------------------------------------------------------------------------------------------
SELECT 
         dud.PLID
        ,dud.PUID
        ,dud.ProdCode
        ,dud.ProdDesc												AS 'Product'
        ,dud.PLDesc													AS 'ProductionLine'
        ,dud.PUDesc													AS 'MasterUnit'
        ,dud.PUDesc													AS 'Equipment'
		,dud.TeamDesc												AS 'Team'
		,dud.ShiftDesc												AS 'Shift'
        ,dud.Location												AS 'Location'
        ,dud.Fault													AS 'Fault'
		,SUBSTRING (
			 Reason2Category
			,CHARINDEX ('Category:', Reason2Category) + LEN ('Category:')
			,ISNULL (
				NULLIF (
					CHARINDEX ('|',
						SUBSTRING (
							 Reason2Category
							,CHARINDEX ('Category:', Reason2Category) + LEN ('Category:')
							,LEN (Reason2Category)
						)
					) -1
					, -1
				)
				,LEN (Reason2Category)
			 )
		 )															AS 'Category'
		,SUBSTRING (
			 Reason2Category
			,CHARINDEX ('GroupCause:', Reason2Category) + LEN ('GroupCause:')
			,ISNULL (
				NULLIF (
					CHARINDEX ('|',
						SUBSTRING (
							 Reason2Category
							,CHARINDEX ('GroupCause:', Reason2Category) + LEN ('GroupCause:')
							,LEN (Reason2Category)
						)
					) -1
					, -1
				)
				,LEN (Reason2Category)
			 )
		 )															AS 'GroupCause'
		,SUBSTRING (
			 Reason2Category
			,CHARINDEX ('Schedule:', Reason2Category) + LEN ('Schedule:')
			,ISNULL (
				NULLIF (
					CHARINDEX ('|',
						SUBSTRING (
							 Reason2Category
							,CHARINDEX ('Schedule:', Reason2Category) + LEN ('Schedule:')
							,LEN (Reason2Category)
						)
					) -1
					, -1
				)
				,LEN (Reason2Category)
			 )
		 )															AS 'Schedule'
		,SUBSTRING (
			 Reason2Category
			,CHARINDEX ('Subsystem:', Reason2Category) + LEN ('Subsystem:')
			,ISNULL (
				NULLIF (
					CHARINDEX ('|',
						SUBSTRING (
							 Reason2Category
							,CHARINDEX ('Subsystem:', Reason2Category) + LEN ('Subsystem:')
							,LEN (Reason2Category)
						)
					) -1
					, -1
				)
				,LEN (Reason2Category)
			 )
		 )															AS 'Subsystem'
        ,dud.Reason1												AS 'FailureMode'
        ,dud.Reason2												AS 'FailureModeCause'
		,dud.Reason1Category										AS 'Reason1Category'
        ,dud.Reason2Category										AS 'Reason2Category'
        ,dud.LineStatus												AS 'LineStatus'
        ,IIF (Location LIKE '%Rate%Loss%', 0, dud.DTStatus)			AS 'TotalStops'
        ,IIF (Location LIKE '%Rate%Loss%', 0, dud.MinorStop)		AS 'MinorStops'
        ,ISNULL(StopsEquipFails, 0)									AS 'EquipmentFailures'
        ,ISNULL(ProcFailure, 0)										AS 'ProcessFailures'
		,CASE
			WHEN		dud.DTStatus = 1 
			THEN	
				CASE
					WHEN Reason1Id IS NOT NULL AND Reason2Id IS NOT NULL
					THEN						
						(ISNULL((SELECT COUNT(DISTINCT Reason2) FROM #DowntimeDetails WHERE dud.TEDetId = ParentDTId GROUP BY ParentDTId),0))
					ELSE
						1
					END
			ELSE	0
		 END														AS 'TotalCauses'
		,CASE
			WHEN		Location NOT LIKE '%Rate%Loss%'
					AND TEDetId IS NOT NULL
			THEN	dud.Duration
			ELSE	0
		 END														AS 'EventDowntime'
		,CASE
			WHEN		Location NOT LIKE '%Rate%Loss%'
					AND dud.StartTime >= e.StartTime 
					AND (dud.StartTime < e.EndTime OR dud.EndTime < e.EndTime)
					AND TEDetId IS NOT NULL
			THEN	dud.Duration
			ELSE	0
		 END														AS 'SplitDowntime' --Reporting Downtime
		 ,CASE
			WHEN		StopsUnscheduled = 1
					--AND dud.StartTime >= e.StartTime 
					--AND (dud.StartTime < e.EndTime OR dud.EndTime < e.EndTime)
					--AND TEDetId IS NOT NULL
			THEN	dud.Duration
			ELSE	0
		 END														AS 'UnscheduledSplitDowntime'
        ,IIF (Location LIKE '%Rate%Loss%' 
				AND dud.TEDetId != 0 
				AND dud.TEDetId IS NOT NULL, 0, dud.Total_Uptime)	AS 'EventUptime'
		,CASE
			WHEN		dud.PUDesc NOT LIKE '%Rate%Loss%'
					AND dud.StartTime > e.StartTime 
					AND (dud.StartTime <= e.EndTime OR dud.EndTime <= e.EndTime)
					AND TEDetId IS NOT NULL
			THEN	dud.Uptime
			ELSE	0
		 END														AS 'SplitUptime' --Reporting Uptime
        ,CASE
            WHEN		Total_Uptime < 2 
					AND DTStatus = 1
					AND PUDesc NOT LIKE '%Rate%Loss%'
            THEN	1 
            ELSE	0
         END														AS 'StopsWithUptime2Min'
        ,IIF (dud.Location LIKE '%Rate%Loss%', 1, 0)				AS 'RateLossEvents'
        --,IIF (dud.RawRateLoss > 0.0, dud.RawRateLoss/60, 0)			AS 'RawRateLoss'
        ,IIF (dud.EffectiveDowntime > 0.0, dud.EffectiveDowntime, 0)AS 'RateLossEffectiveDowntime'
        ,IIF (dud.LineActualSpeed > 0.0, dud.LineActualSpeed, 0)	AS 'LineActualSpeed'
		,IIF (dud.Location LIKE '%Rate%Loss%', dud.RateLossPRID, '')AS 'RateLossPRID'
		,CASE
            WHEN		Location NOT LIKE '%Rate%Loss%' 
					AND IsStarved = 1
					AND IsBlocked = 1
					AND StopsBlockedStarved = 1
            THEN	1 
            ELSE	0
         END														AS 'TotalBlockedStarved'
        ,CASE 
            WHEN		StopsEquipFails = 1
					AND Duration >= 10
                    AND Duration <= 30
            THEN	1 
            ELSE	0
         END														AS 'MinorEquipmentFailures'
        ,CASE 
            WHEN		StopsEquipFails = 1
					AND Duration >  30
                    AND Duration <= 120
            THEN	1 
            ELSE	0
         END														AS 'ModerateEquipmentFailures'
        ,CASE 
            WHEN		StopsEquipFails = 1
					AND Duration >  120
            THEN	1 
            ELSE	0
		 END														AS 'MajorEquipmentFailures'
        ,CASE 
            WHEN        ProcFailure = 1
                    AND Duration >= 10
                    AND Duration <= 30
            THEN	1 
            ELSE	0
		 END														AS 'MinorProcessFailures'
        ,CASE 
            WHEN        ProcFailure = 1
                    AND Duration >  30
                    AND Duration <= 120
            THEN	1 
            ELSE	0
         END														AS 'ModerateProcessFailures'
        ,CASE 
            WHEN        ProcFailure = 1
                    AND Duration >  120
            THEN	1 
            ELSE	0
         END														AS 'MajorProcessFailures'
    FROM #DowntimeDetails	dud 
	LEFT JOIN @Equipment					e	ON e.PLID = dud.PLID 
	-- test of Rate Loss Units
	--where IIF (Location LIKE '%Rate%Loss%', 1, 0) = 1
    ORDER BY dud.PLDesc, dud.PUDesc


DROP TABLE #DowntimeDetails
GO

GRANT  EXECUTE  ON [dbo].[spRptConvertingAllStops]  TO OpDBWriter
GO