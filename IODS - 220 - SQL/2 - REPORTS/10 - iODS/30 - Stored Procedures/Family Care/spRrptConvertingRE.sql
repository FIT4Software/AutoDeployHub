USE [Auto_opsDataStore]
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
		@SP_Name	= 'spRrptConvertingRE',
		@Inputs		= 4, 
		@Version	= '1.1'  

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
				
DROP PROCEDURE [dbo].[spRrptConvertingRE]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRrptConvertingRE
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Damian Campana - Arido Software
-- Date created			: 2018-10-22
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for Converting RE Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-10-22		Damian Campana     		Initial Release
-- 1.1		2019-07-10		Damian Campana			Add parameters StartTime & EndTime for Filter <User Defined>
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================
CREATE PROCEDURE [dbo].[spRrptConvertingRE]
--DECLARE
	 @strLineId				VARCHAR(500)		= NULL
	,@timeOptionId			INT					= NULL
	,@dtmStartTime			DATETIME			= NULL
	,@dtmEndTime			DATETIME			= NULL

--WITH ENCRYPTION
AS
SET NOCOUNT ON

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Generate Table
-- -----------------------------------------------------------------------------------------------------------------------------
	DECLARE @Equipment						TABLE (
		 RcdIdx								INT IDENTITY							
		,PUId								INT				
		,PUDesc								NVARCHAR(255)	
		,PLId								INT				
		,PLDesc								NVARCHAR(255)	
		,StartTime							DATETIME		
		,EndTime							DATETIME		
	)

	DECLARE @tbl_AllStops					TABLE (
		 PLID								INT
		,PUID								INT
		,ProdCode							VARCHAR(100)
		,Product							VARCHAR(500)
		,ProductionLine						VARCHAR(500)
		,MasterUnit							VARCHAR(500)
		,Equipment							VARCHAR(500)
		,Team								VARCHAR(500)
		,Shift								VARCHAR(500)
		,Location							VARCHAR(500)
		,FaultDesc							VARCHAR(500)
		,Category							VARCHAR(500)
		,GroupCause							VARCHAR(500)
		,Schedule							VARCHAR(500)
		,Subsystem							VARCHAR(500)
		,FailureMode						VARCHAR(500)
		,FailureModeCause					VARCHAR(500)
		,Reason1Category					VARCHAR(500)
		,Reason2Category					VARCHAR(500)
		,LineStatus							VARCHAR(500)
		,TotalStops							INT
		,MinorStops							INT
		,EquipmentFailures					INT
		,ProcessFailures					INT
		,TotalCauses						INT
		,EventDowntime						DECIMAL(18,2)
		,SplitDowntime						DECIMAL(18,2)
		,UnscheduledSplitDowntime			DECIMAL(18,2)
		,EventUptime						DECIMAL(18,2)
		,SplitUptime						DECIMAL(18,2)
		,StopsWithUptime2Min				INT
		,RateLossEvents						INT
		,RateLossEffectiveDowntime			DECIMAL(18,2)
		,LineActualSpeed					DECIMAL(18,2)
		,RateLossPRID						VARCHAR(500)
		,TotalBlockedStarved				INT
		,MinorEquipmentFailures				INT
		,ModerateEquipmentFailures			INT
		,MajorEquipmentFailures				INT
		,MinorProcessFailures				INT
		,ModerateProcessFailures			INT
		,MajorProcessFailures				INT
	)

-- -----------------------------------------------------------------------------------------------------------------------------
-- Update @Equipment table with all the needed values
-- -----------------------------------------------------------------------------------------------------------------------------
	INSERT INTO @Equipment(PLId) 
	SELECT String FROM fnLocal_Split(@strLineId,',')

	UPDATE e
	SET PLDesc	= (SELECT LineDesc 
				   FROM dbo.LINE_DIMENSION ld
				   WHERE ld.PLId = e.PLId)
	FROM @Equipment e

	--Set the Start & End Time
	IF @timeOptionId = -1
	BEGIN
		UPDATE e 
		SET	 e.StartTime = @dtmStartTime, e.EndTime = @dtmEndTime
		FROM @Equipment e 
	END
	ELSE 
	BEGIN
		DECLARE @strTimeOption NVARCHAR(50) = (
				SELECT DateDesc 
				FROM [dbo].[DATE_DIMENSION] (NOLOCK)
				WHERE DateId = @timeOptionId
		)

		UPDATE e 
		SET	   e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
		FROM  @Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f
	END

-- =============================================================================================================================
-- =============================================================================================================================
	INSERT INTO @tbl_AllStops
	EXEC		[dbo].[spRptConvertingAllStops] @strLineId,@timeOptionId,'',@dtmStartTime,@dtmEndTime

-- =============================================================================================================================
-- >> Return all the result sets
-- =============================================================================================================================
-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #1. All Stops (tab)
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,MasterUnit
		,FaultDesc
		,Product
		,Team
		,Shift
		,Location
		,GroupCause
		,Category
		,Subsystem
		,Schedule
		,FailureMode
		,FailureModeCause
		,LineStatus
		,TotalStops
		,MinorStops
		,EquipmentFailures
		,ProcessFailures
		,TotalCauses
		,EventDowntime
		,SplitDowntime
		,UnscheduledSplitDowntime
		,EventUptime
		,SplitUptime
		,StopsWithUptime2Min
		,RateLossEvents
		,RateLossEffectiveDowntime
		,TotalBlockedStarved
		,MinorEquipmentFailures
		,ModerateEquipmentFailures
		,MajorEquipmentFailures
		,MinorProcessFailures
		,ModerateProcessFailures
		,MajorProcessFailures
	FROM @tbl_AllStops

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #2. Production Line (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #3. Equipment (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment										
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #4. Team (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment										
		,Team
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, Team

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #5. Product (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment										
		,Product
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, Product

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #6. Master Unit (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment											
		,MasterUnit											
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #7. Location (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment											
		,MasterUnit											
		,Location											
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit, Location

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #8. Category (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment											
		,MasterUnit											
		,Category
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit, Category

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #9. Subsystem (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment											
		,MasterUnit											
		,Subsystem
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit, Subsystem

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #10. Failure Mode (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment											
		,MasterUnit											
		,FailureMode
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit, FailureMode

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #11. Failure Mode Cause (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment											
		,MasterUnit											
		,FailureModeCause
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit, FailureModeCause

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #12. Fault Description (tab) 
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT 
		 ProductionLine
		,Equipment										
		,MasterUnit											
		,FaultDesc											
		,'TotalStops' = SUM(TotalStops)
		,'TotalCauses' = SUM(TotalCauses)
		,'ReportingDowntime' = SUM(SplitDowntime)
		,'ReportingUptime' = SUM(SplitUptime)
		,'StopsWithUptime2Min' = SUM(StopsWithUptime2Min)
		,'R2' = CONVERT(DECIMAL(18,2), 1 - (ISNULL(NULLIF(SUM(CONVERT(FLOAT,StopsWithUptime2Min)), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1)))
		,'Availability' = CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / (ISNULL(NULLIF(SUM(SplitUptime), 0), 1) + SUM(SplitDowntime)))
		,'MTBF'	= CONVERT(DECIMAL(18,2), ISNULL(NULLIF(SUM(SplitUptime), 0), 1) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
		,'MTTR'	= CONVERT(DECIMAL(18,2), SUM(SplitDowntime) / ISNULL(NULLIF(SUM(TotalStops), 0), 1))
	FROM @tbl_AllStops
	GROUP BY PLID, ProductionLine, Equipment, MasterUnit, FaultDesc

-- -----------------------------------------------------------------------------------------------------------------------------
-- >> Result Set #13. Time Preview
-- -----------------------------------------------------------------------------------------------------------------------------
	SELECT
		 RcdIdx		
		,PUId		
		,PUDesc		
		,PLId		
		,PLDesc		
		,CONVERT(VARCHAR, StartTime, 120)	AS StartTime	
		,CONVERT(VARCHAR, EndTime, 120)		AS EndTime	
		,CONVERT(VARCHAR, GETDATE(), 120)	AS RunTime
	FROM @Equipment

GO
GRANT  EXECUTE  ON [dbo].[spRrptConvertingRE]  TO OpDBWriter
GO