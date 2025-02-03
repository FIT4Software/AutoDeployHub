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
	@SP_Name	= 'spRptAlarms',
	@Inputs		= 5,
	@Version	= '1.4'

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
	INSERT INTO dbo.AppVersions
		(
		App_name,
		App_version,
		Modified_On )
	VALUES
		(
			@SP_Name,
			@Version,
			GETDATE())
END

--===================================================================================================================== 
----------------------------------------------------------------------------------------------------------------------
-- DROP StoredProcedure
----------------------------------------------------------------------------------------------------------------------
IF EXISTS ( SELECT 1
FROM Information_schema.Routines
WHERE	Specific_schema = 'dbo'
	AND Specific_Name = @SP_Name
	AND Routine_Type = 'PROCEDURE' )
				
DROP PROCEDURE [dbo].[spRptAlarms]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptAlarms
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Ivan Corica - Arido Software
-- Date created			: 2021-03-24
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides the data for Alarms Report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2021-03-24		Ivan Corica     		Initial Release
-- 1.1		2021-03-31		Ivan Corica				Add timeOption 
-- 1.2		2021-07-22		Gonzalo Luc				Add SET COLLATION as DEFAULT
-- 1.3		2021-08-23		Gonzalo Luc				Fix desc field size to 255
-- 1.4		2021-09-02		Gonzalo Luc				Add linedesc to filter alarms to avoid units from other lines.
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptAlarms]
-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE 
		@prodLineId					NVARCHAR(2000)
		,@timeOption				INT		
		,@dtmStartTime				DATETIME			= NULL
		,@dtmEndTime				DATETIME			= NULL
		,@alarmType					NVARCHAR(20)		= NULL

--WITH ENCRYPTION
AS
SET NOCOUNT ON
----------------------------------------------------------------------------------------------------------------------
-- Report Test
----------------------------------------------------------------------------------------------------------------------
	--SELECT @prodLineId			= '646'--, 59, 61'
	--,@TimeOption				=	1
	--,@dtmStartTime				= ''--'2020-05-22 00:00:00'
	--,@dtmEndTime				= ''--'2021-03-18 06:00:00'--'2020-06-30 00:00:00' 
	--,@AlarmType					= ''

----------------------------------------------------------------------------------------------------------------------
-- Variables 
----------------------------------------------------------------------------------------------------------------------
DECLARE	
		@strTimeOption		NVARCHAR(100)
--------------------------------------------------------------------------------------------------------------------------
--TABLES
--------------------------------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#IDs', 'U') IS NOT NULL  DROP TABLE #IDs
CREATE TABLE #IDs
			(RcdIdx				INT
			 ,PLDesc 			NVARCHAR(255) COLLATE DATABASE_DEFAULT
			 ,PLid  			INT
			 ,PUID  			NVARCHAR(255) COLLATE DATABASE_DEFAULT
			 ,PUDesc 			NVARCHAR(255) COLLATE DATABASE_DEFAULT
			 ,StartTime			DATETIME
			 ,EndTime			DATETIME
			 ,ConvId			INT)

--------------------------------------------------------------------------------------------------------------------------------
--IF SELECT ALL ALARMS TYPE
--------------------------------------------------------------------------------------------------------------------------------
IF @AlarmType = '' OR @AlarmType IS NULL
BEGIN
	SELECT @AlarmType = 'CL,QA'
END
--------------------------------------------------------------------------------------------------------------------------
--FILL TABLE
--------------------------------------------------------------------------------------------------------------------------
--PU_ID, PL_ID, PL_Desc
INSERT INTO #IDs(PUID, PLID, PLDesc, PUDesc)
SELECT wc.PUId, wc.PLID, ld.LineDesc, wc.PUDesc
FROM dbo.LINE_DIMENSION ld WITH(NOLOCK)
JOIN dbo.WorkCell_Dimension wc WITH(NOLOCK) ON wc.PLId = ld.PLId
WHERE wc.PLId IN (SELECT String FROM fnLocal_Split(@prodLineId,','))
AND wc.PUDesc NOT LIKE 'Z_OB%'
--------------------------------------------------------------------------------------------------------------------------
--ConvId
Update #IDs
Set ConvId = (Select distinct w.PUID from WorkCell_Dimension w WITH(NOLOCK)
			  where w.PUDesc = #IDs.PLDesc + ' Converter' and w.PLId = #IDs.PLId)

--------------------------------------------------------------------------------------------------------------------------------
--Update Start and End time
--------------------------------------------------------------------------------------------------------------------------------
IF @timeOption > 0
BEGIN
	--Update start time and end time if a time option is selected
	SELECT @strTimeOption = DateDesc
	FROM [dbo].[DATE_DIMENSION] WITH(NOLOCK)
	WHERE DateId = @timeOption

	UPDATE ids 
			SET	ids.StartTime = f.dtmStartTime, ids.EndTime =	f.dtmEndTime
			FROM #IDs ids
			OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,ids.plid) f

	--Select first startTime and las endTime for all lines
	SELECT @dtmStartTime = MIN(ids.StartTime), @dtmEndTime = MAX(ids.EndTime)
	FROM #IDs ids
END
--------------------------------------------------------------------------------------------------------------------------
--All alarms
--------------------------------------------------------------------------------------------------------------------------
IF((@dtmStartTime IS NULL OR @dtmStartTime = '') AND (@dtmEndTime IS NULL OR @dtmEndTime = ''))
BEGIN
--Start and End dates for all allarms
	SELECT @dtmStartTime =	MIN(a.StartTime), @dtmEndTime = Max(a.EndTime)
	FROM #IDs ids
	JOIN OpsDB_Alarms_RawData a WITH(NOLOCK) ON a.PUDesc = ids.PUDesc


	SELECT ids.PLId,al.PLDesc, al.PUDesc, al.VarDesc, fudp.VarId, fudp.Value, fudp.EffectiveDate, fudp.ExpirationDate, al.AlarmDesc, al.AlarmTemplate, al.StartTime, al.EndTime, al.StartValue, al.EndValue, al.ModifiedOn, al.UserName,al.EventTypeDesc,al.ProdCode,al.ProdDesc,al.LReject,al.Target,al.UReject,al.AlarmId,al.MaxValue,al.MinValue,al.Action1,al.Cause1,CONVERT(VARCHAR, @dtmStartTime, 120) 'rptStartTime', CONVERT(VARCHAR, @dtmEndTime, 120) 'rptEndTime'
	FROM #IDs ids
	JOIN OpsDB_Alarms_RawData al WITH(NOLOCK) ON al.PUDesc = ids.PUDesc
												AND al.PLDesc = ids.PLDesc
												AND al.StartTime >= @dtmStartTime 
												AND (al.EndTime IS NULL OR al.EndTime <= @dtmEndTime)
												AND al.DeleteFlag = 0
	JOIN FACT_UDPs fudp WITH(NOLOCK) ON fudp.VarId = al.VarId
	WHERE (al.Action1 IS NULL OR al.Action1 NOT LIKE '%Tym%' OR al.Action1 NOT LIKE '%Temp%')
	AND (al.Cause1 IS NULL OR al.Cause1 NOT LIKE '%Tym%' OR al.Cause1 NOT LIKE '%Temp%')
	AND fudp.Value IN (SELECT String FROM fnLocal_Split(@AlarmType,','))
	AND (fudp.ExpirationDate IS NULL)
	ORDER BY al.PLDesc, al.PUDesc, al.StartTime DESC, al.VarDesc

END
--------------------------------------------------------------------------------------------------------------------------
--Open alarms
--------------------------------------------------------------------------------------------------------------------------
ELSE IF((@dtmStartTime IS NOT NULL) AND (@dtmEndTime IS NULL OR @dtmEndTime = ''))
BEGIN
	SELECT ids.PLId,al.PLDesc, al.PUDesc, al.VarDesc, fudp.VarId, fudp.Value, fudp.EffectiveDate, fudp.ExpirationDate, al.AlarmDesc, al.AlarmTemplate, al.StartTime, al.EndTime, al.StartValue, al.EndValue, al.ModifiedOn, al.UserName,al.EventTypeDesc,al.ProdCode,al.ProdDesc,al.LReject,al.Target,al.UReject,al.AlarmId,al.MaxValue,al.MinValue,al.Action1,al.Cause1,CONVERT(VARCHAR, @dtmStartTime, 120) 'rptStartTime', CONVERT(VARCHAR, @dtmEndTime, 120) 'rptEndTime'
	FROM #IDs ids
	JOIN OpsDB_Alarms_RawData al WITH(NOLOCK) ON al.PUDesc = ids.PUDesc 
												AND al.PLDesc = ids.PLDesc
												AND al.StartTime >= @dtmStartTime 
												AND al.EndTime IS NULL
												AND al.DeleteFlag = 0
	JOIN FACT_UDPs fudp WITH(NOLOCK) ON fudp.VarId = al.VarId
	WHERE (al.Action1 IS NULL OR al.Action1 NOT LIKE '%Tym%' OR al.Action1 NOT LIKE '%Temp%')
	AND (al.Cause1 IS NULL OR al.Cause1 NOT LIKE '%Tym%' OR al.Cause1 NOT LIKE '%Temp%')
	AND fudp.Value IN (SELECT String FROM fnLocal_Split(@AlarmType,','))
	AND (fudp.ExpirationDate IS NULL) 
	ORDER BY PLDesc, PUDesc, al.StartTime DESC, al.VarDesc

END
--------------------------------------------------------------------------------------------------------------------------
--All Alarms filtered by start & end time
--------------------------------------------------------------------------------------------------------------------------
ELSE
BEGIN
	SELECT ids.PLId,al.PLDesc, al.PUDesc, al.VarDesc, fudp.VarId, fudp.Value, fudp.EffectiveDate, fudp.ExpirationDate, al.AlarmDesc, al.AlarmTemplate, al.StartTime, al.EndTime, al.StartValue, al.EndValue, al.ModifiedOn, al.UserName,al.EventTypeDesc,al.ProdCode,al.ProdDesc,al.LReject,al.Target,al.UReject,al.AlarmId,al.MaxValue,al.MinValue,al.Action1,al.Cause1,CONVERT(VARCHAR, @dtmStartTime, 120) 'rptStartTime', CONVERT(VARCHAR, @dtmEndTime, 120) 'rptEndTime'
	FROM #IDs ids
	JOIN OpsDB_Alarms_RawData al WITH(NOLOCK) ON al.PUDesc = ids.PUDesc 
												AND al.PLDesc = ids.PLDesc
												AND (al.StartTime >= @dtmStartTime AND al.StartTime <= @dtmEndTime)
												--AND (al.EndTime > @dtmEndTime OR al.EndTime IS NULL)
												AND al.DeleteFlag = 0
	JOIN FACT_UDPs fudp WITH(NOLOCK) ON fudp.VarId = al.VarId
	WHERE (al.Action1 IS NULL OR al.Action1 NOT LIKE '%Tym%' OR al.Action1 NOT LIKE '%Temp%')
	AND (al.Cause1 IS NULL OR al.Cause1 NOT LIKE '%Tym%' OR al.Cause1 NOT LIKE '%Temp%')
	AND fudp.Value IN (SELECT String FROM fnLocal_Split(@AlarmType,','))
	AND (fudp.ExpirationDate IS NULL) --ver condicion de exp date
	ORDER BY al.PLDesc, al.PUDesc, al.StartTime DESC, al.VarDesc

END


--------------------------------------------------------------------------------------------------------------------------
--Drops
--------------------------------------------------------------------------------------------------------------------------
Drop Table #IDs

GO
