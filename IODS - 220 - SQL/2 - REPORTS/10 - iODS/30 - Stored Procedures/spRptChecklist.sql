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
		@SP_Name	= 'spRptChecklist',
		@Inputs		= 5, 
		@Version	= '1.0'  

--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================

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
		App_name,
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
				
DROP PROCEDURE [dbo].[spRptChecklist]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
/****** Object:  StoredProcedure [dbo].[spRptChecklist]    Script Date: 11/12/2018 8:14:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptCheckList
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Luciano Casini - Arido Software
-- Date created			: 2018-07-04
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for the Check List Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-07-04		Luciano Casini    		Initial Release
-- 1.1		2018-07-20		Luciano Casini			Add filter by Productions Units
-- 1.2		2018-12-20		Facundo Sosa				Replace Concat fn
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptChecklist]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE
	 @prodLineId	INT				= NULL
	,@workCellId	NVARCHAR(MAX)	= ''
	,@timeOption	INT				= NULL
	,@prodStatus	VARCHAR(20)		= 'All'
	,@teams			NVARCHAR(MAX)	= ''
	,@sheets		NVARCHAR(MAX)	= ''
	,@hse			BIT				= NULL
	,@qFactorOnly	BIT				= NULL
	,@groupBy		VARCHAR(20)		= NULL --workcell or line
	,@startTime		DATETIME		= NULL
	,@endTime		DATETIME		= NULL
--WITH ENCRYPTION
AS
SET NOCOUNT ON
-- --------------------------------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------------------------------
-- DEBUG	
-- --------------------------------------------------------------------------------------------------------------------

--SELECT
--	 @prodLineId  	= 2
--	,@workCellId	= 2
--	,@timeOption	= 1
--	,@prodStatus	= 'All'
--	,@teams			= ''
--	,@sheets		= ''
--	,@hse			= 1
--	,@qFactorOnly	= 0
--	,@groupBy		= 'workcell'
	
-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE
--	@startTime		DATETIME		= NULL
--	,@endTime		DATETIME		= NULL

	DECLARE 
		 @strPLDesc				VARCHAR(200),
		 @strTimeOption			VARCHAR(50)
		
	DECLARE 
		 @tbl_TimeOption		TABLE (startDate DATETIME, endDate DATETIME)


	
	DECLARE	@UDPData TABLE(
					UDPName						NVARCHAR(255),
					VarId						INT,
					Value						NVARCHAR(50)
					)

	DECLARE	@ChecklistData TABLE(
					VarDesc						NVARCHAR(255),
					VarId						INT,
					DeptDesc					NVARCHAR(255),
					DeptId						INT	,
					PLDesc						NVARCHAR(255),
					PLId						INT	,
					PUDesc						NVARCHAR(255),
					PUId						INT	,	
					TeamDesc					NVARCHAR(255),
					ShiftDesc					NVARCHAR(255),
					LineStatus					NVARCHAR(50),
					ResultOn					DATETIME,
					EntryOn						DATETIME,
					Result						NVARCHAR(50),
					Defect						NVARCHAR(50),
					LReject						NVARCHAR(25),
					Target						NVARCHAR(25),
					UReject						NVARCHAR(25),
					ProductDesc					NVARCHAR(255),
					ProdCode					NVARCHAR(25),
					HSE							BIT,
					QFactor						BIT,
					UDP_Dimension_UDPIdx		INT,
					Checked						INT								
					)
	DECLARE	@AlarmsData TABLE(
					AlarmId						INT,
					AlarmDesc					NVARCHAR(255),
					StartTime					DATETIME	,
					EndTime						DATETIME,
					Status						NVARCHAR(255),
					PLDesc						NVARCHAR(255),
					PUDesc						NVARCHAR(255),
					Result						NVARCHAR(50),
					LReject						NVARCHAR(25),
					Target						NVARCHAR(25),
					UReject						NVARCHAR(25),
					VarId						INT			,
					TeamDesc					NVARCHAR(255),
					DeptDesc					NVARCHAR(255)
					)
-- --------------------------------------------------------------------------------------------------------------------
-- Get Start time & End time
-- --------------------------------------------------------------------------------------------------------------------
IF(	@startTime IS NULL AND @endTime IS NULL)
BEGIN
	SELECT @strTimeOption = DateDesc 
	FROM [dbo].[DATE_DIMENSION] 
	WHERE DateId = @timeOption
	
	IF @groupBy = 'workcell'
	BEGIN
		SELECT TOP 1 @strPLDesc	= PLId FROM [dbo].[OpsDB_DowntimeUptime_Data] WHERE PUId = @workCellId
	END
	ELSE
	BEGIN
		SELECT TOP 1 @strPLDesc	= PLId FROM [dbo].[OpsDB_DowntimeUptime_Data] WHERE PLId = @prodLineId
	END

	INSERT INTO	@tbl_TimeOption EXEC [dbo].[spLocal_GetDateFromTimeOption] @strTimeOption, @strPLDesc
	SELECT		@startTime = startDate, @endTime = endDate FROM @tbl_TimeOption
END


-- --------------------------------------------------------------------------------------------------------------------
-- GET Checklist Data
-- --------------------------------------------------------------------------------------------------------------------
	INSERT INTO @ChecklistData
	SELECT 			v.VarDesc					,
					v.VarId						,
					DeptDesc					,
					DeptId						,
					PLDesc						,
					PLId						,
					PUDESC						,
					PUId						,	
					ISNULL(TeamDesc, '-') 'TeamDesc',
					ShiftDesc					,
					LineStatus					,
					ResultOn					,
					EntryOn						,
					Result						,
					Defect						,
					LReject						,
					Target						,
					UReject						,
					ProdDesc					,
					ProdCode					,
					0							,
					0							,
					u.UDP_Dimension_UDPIdx		,
					CASE WHEN Result IS NULL THEN 0 ELSE 1 END 'Checked'
	 FROM	
			dbo.OpsDB_VariablesTasks_RawData v JOIN
			dbo.FACT_UDPs u ON v.Fact_UDPs_Idx = u.idx
	 WHERE u.Value = 'Checklist'
			AND ((@groupBy='workcell' AND PUId=CASE WHEN @groupBy='workcell' THEN @workCellId ELSE 0 END) 
				OR (@groupBy='line' 
					AND PLId=@prodLineId 
					AND (PUId IN(SELECT String FROM dbo.fnLocal_Split(@workCellId, ',')) OR @workCellId = '')
				)
			)
			AND (LineStatus LIKE '%' + @prodStatus + '%' OR @prodStatus = 'All')
			AND ResultOn >= @startTime AND ResultOn <= @endTime
			--AND (TeamDesc IN(SELECT String FROM dbo.fnLocal_Split(@teams, ',')) OR @teams = '')
			AND (SheetDesc IN(SELECT String FROM dbo.fnLocal_Split(@sheets, ',')) OR @sheets = '')

	IF(@teams <> '')
	BEGIN
		DELETE FROM @ChecklistData
		WHERE TeamDesc NOT IN (SELECT String FROM dbo.fnLocal_Split(@teams, ','))
	END

	INSERT INTO @UDPData
	SELECT DISTINCT UDPName, u.VarId, Value FROM dbo.FACT_UDPs u
	JOIN dbo.UDP_Dimension d ON u.UDP_Dimension_UDPIdx = d.UDPIdx
	JOIN @ChecklistData c ON u.VarId = c.VarId
	WHERE (d.UDPName = 'Q-Factor Type' 
			OR d.UDPName = 'HSE Flag')
			AND Value = '1'
			AND u.ExpirationDate IS NULL

	UPDATE c
		SET HSE = 1
	FROM @ChecklistData c
	JOIN @UDPData u ON c.VarId = u.VarId
	WHERE u.UDPName = 'HSE Flag' 
		

	UPDATE c
		SET QFactor = 1
	FROM @ChecklistData c
	JOIN @UDPData u ON c.VarId = u.VarId
	WHERE u.UDPName = 'Q-Factor Type' 
		

	IF(@hse = 1)
	BEGIN
		DELETE FROM @ChecklistData WHERE HSE=0
	END

	IF(@qFactorOnly = 1)
	BEGIN
		DELETE FROM @ChecklistData WHERE QFactor=0
	END

	

-- --------------------------------------------------------------------------------------------------------------------
-- GET Alarms Data
-- --------------------------------------------------------------------------------------------------------------------
INSERT INTO @AlarmsData
SELECT	AlarmId,
		AlarmDesc,
	   	StartTime,
		EndTime,
		CASE WHEN EndTime IS NULL THEN 'Open' ELSE 'Closed' END 'Status',
		a.PLDesc,
		a.PUDesc,
		StartValue 'Result',
		a.LReject,
		a.Target,
		a.UReject,
		a.VarId,
		c.TeamDesc,
		c.DeptDesc
FROM [dbo].[OpsDB_Alarms_RawData] a
JOIN @ChecklistData c ON a.VarId = c.VarId AND a.StartTime = c.ResultOn
WHERE StartTime >= @startTime AND StartTime <= @endTime

-- --------------------------------------------------------------------------------------------------------------------
--  Result set 1. KPI's
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE
	@Result			FLOAT,
	@TotalResults	FLOAT,
	@TotalInSpec	FLOAT,
	@Completion		FLOAT,
	@Compliance		FLOAT,
	@OutOfSpec		NVARCHAR(20),
	@DueChecks		NVARCHAR(20)
	
	SET @Result = (SELECT COUNT(*) FROM @ChecklistData WHERE Result IS NOT NULL)
	SET @TotalResults = (SELECT COUNT(*) FROM @ChecklistData)
	SET @TotalInSpec = (SELECT COUNT(Defect) FROM @ChecklistData WHERE Defect=0 AND Result IS NOT NULL)

	SET @Completion = (SELECT ROUND(@Result/NULLIF(@TotalResults, 0),2))
	SET @Compliance = (SELECT ROUND(@TotalInSpec/NULLIF(@Result, 0), 2))
	SET @OutOfSpec = (SELECT COUNT(Defect) FROM @ChecklistData WHERE Defect=1)
	SET @DueChecks = (SELECT COUNT(*) FROM @ChecklistData WHERE Result IS NULL)

	SELECT @Completion 'Completion', @Compliance 'Compliance', @OutOfSpec 'Out of Spec', @DueChecks 'Due Checks'
-- --------------------------------------------------------------------------------------------------------------------
--  Result set 2. Checklist data
-- --------------------------------------------------------------------------------------------------------------------

	SELECT * FROM @ChecklistData


-- --------------------------------------------------------------------------------------------------------------------
--  Result set 3. Alarms data
-- --------------------------------------------------------------------------------------------------------------------

	SELECT * FROM @AlarmsData order by StartTime

-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------
	/*
	EXEC [dbo].[spRptChecklist] 53, 737, 4, 'All', '', '', 0, 0, 'line'
	
	 @prodLineId	INT				= NULL
	,@workCellId	INT				= NULL
	,@timeOption	INT				= NULL
	,@prodStatus	VARCHAR(20)		= NULL
	,@teams			NVARCHAR(MAX)	= NULL
	,@sheets		NVARCHAR(MAX)	= NULL
	,@hse			BIT				= NULL
	,@qFactorOnly	BIT				= NULL
	,@groupBy		VARCHAR(20)		= NULL --workcell or line
	*/
