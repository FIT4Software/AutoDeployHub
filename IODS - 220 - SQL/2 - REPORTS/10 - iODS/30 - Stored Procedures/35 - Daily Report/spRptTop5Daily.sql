use Auto_opsDataStore
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
		@SP_Name	= 'spRptTop5Daily',
		@Inputs		= 7, 
		@Version	= '1.4'  

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
				
DROP PROCEDURE [dbo].[spRptTop5Daily]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spRptTop5Daily
-- --------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-08-07
-- Version 				: 1.0
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure provides Top 5 data for daily report.
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- 1.0		2018-08-07		Gonzalo Luc     		Initial Release
-- 1.1		2019-10-04		Gonzalo Luc				Added User Defined.
-- 1.2		2019-12-17		Gonzalo Luc				Updated query for special case when a unit belong's to more than 1 line
-- 1.3		2021-03-30		Gonzalo Luc				Fix @Equipment table update for worcells (grooming configuration)
-- 1.4		2021-06-29		Gonzalo Luc				Fix scrap manual/automatic use the correct column on the reject table.
-- --------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================

CREATE PROCEDURE [dbo].[spRptTop5Daily]

-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
-- --------------------------------------------------------------------------------------------------------------------
--DECLARE
	 @prodLineId				VARCHAR(MAX)	= NULL
	,@workCellId				VARCHAR(MAX)	= NULL
	,@timeOption				INT				= NULL
	,@excludeNPT				INT				= NULL
	,@groupBy					NVARCHAR(50)	= NULL
	,@bShowTop5Downtimes		NVARCHAR(10)	
	,@bShowTop5Stops			NVARCHAR(10)	
	,@bShowTop5Scrap			NVARCHAR(10)	
	,@strDTGrouping				NVARCHAR(20)	
	,@strDTType					NVARCHAR(20)	
	,@strStopsGrouping			NVARCHAR(20)	
	,@strStopsType				NVARCHAR(20)	
	,@strScrapGrouping			NVARCHAR(20)	
	,@strScrapType				NVARCHAR(20)
	,@startTime					DATETIME
	,@endTime					DATETIME

--WITH ENCRYPTION
AS
SET NOCOUNT ON
-- --------------------------------------------------------------------------------------------------------------------

-- --------------------------------------------------------------------------------------------------------------------
-- Variables
-- --------------------------------------------------------------------------------------------------------------------
	DECLARE 
		 @PLId					INT
		,@strTimeOption			VARCHAR(50)
		,@strNPT				VARCHAR(50)
		,@index					INT
		,@maxIndex				INT
		,@i						INT
		

	DECLARE 
		 @tbl_TimeOption		TABLE (startDate DATETIME, endDate DATETIME)

	
-- --------------------------------------------------------------------------------------------------------------------
-- Report Test
-- --------------------------------------------------------------------------------------------------------------------
	--SELECT  
	--	 @prodLineId			= '22'
	--	,@workCellId			= ''
	--	,@timeOption			= 1
	--	,@excludeNPT			= 0
	--	,@groupBy				= 'line'
	--	,@bShowTop5Downtimes	= 0
	--	,@bShowTop5Stops		= 0
	--	,@bShowTop5Scrap		= 1
	--	,@strDTGrouping			= 'reason'				
	--	,@strDTType				= 'Planned,UnPlanned'	
	--	,@strStopsGrouping		= 'location'				
	--	,@strStopsType			= 'Planned,UnPlanned'			
	--	,@strScrapGrouping		= 'Reason'				
	--	,@strScrapType			= 'Automatic,Manual'
	--	,@startTime				= '2019-10-01 06:00:00'
	--	,@endTime				= '2019-10-04 06:00:00'

---------------------------------------------------------------------------------------------------
DECLARE @Equipment TABLE (
		RcdIdx						INT IDENTITY	,						
		PUId						INT				,
		PUDesc						NVARCHAR(255)	,
		PLId						INT				,
		PLDesc						NVARCHAR(255)	,
		VSId						INT				,
		ValueStreamDesc				NVARCHAR(255)	,
		StartTime					DATETIME		,
		EndTime						DATETIME		)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#DowntimeRawData', 'U') IS NOT NULL  DROP TABLE #DowntimeRawData
CREATE TABLE #DowntimeRawData	(
		RcdIdx						INT IDENTITY	,
		Duration					FLOAT			,
		PUId						INT				,			
		PUDesc						NVARCHAR(255)	,
		Fault						NVARCHAR(255)	,
		Location					NVARCHAR(255)	,
		Reason						NVARCHAR(255)	,
		isStop						BIT				,
		Planned						BIT				)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#DowntimeTop5', 'U') IS NOT NULL  DROP TABLE #DowntimeTop5
CREATE TABLE #DowntimeTop5	(
		RcdIdx						INT IDENTITY	,
		Duration					FLOAT			,
		PUId						INT				,			
		PUDesc						NVARCHAR(255)	,
		Fault						NVARCHAR(255)	,
		Location					NVARCHAR(255)	,
		Reason						NVARCHAR(255)	,
		IsStop						BIT				,
		Planned						BIT				)
---------------------------------------------------------------------------------------------------
IF OBJECT_ID('tempdb.dbo.#StopsTop5', 'U') IS NOT NULL  DROP TABLE #StopsTop5
CREATE TABLE #StopsTop5	(
		RcdIdx						INT IDENTITY	,
		Duration					FLOAT			,	
		PUId						INT				,		
		PUDesc						NVARCHAR(255)	,
		Fault						NVARCHAR(255)	,
		Location					NVARCHAR(255)	,
		Reason						NVARCHAR(255)	,
		IsStop						BIT				,
		Planned						BIT				)
---------------------------------------------------------------------------------------------------	
IF OBJECT_ID('tempdb.dbo.#ScrapTop5', 'U') IS NOT NULL  DROP TABLE #ScrapTop5
CREATE TABLE #ScrapTop5	(
		RcdIdx						INT IDENTITY	,
		Amount						FLOAT			,	
		PLId						INT				,
		PUId						INT				,		
		PUDesc						NVARCHAR(255)	,
		Fault						NVARCHAR(255)	,
		Location					NVARCHAR(255)	,
		Reason						NVARCHAR(255)	,
		ManualWaste					INT				,
		Timest						DATETIME		)
---------------------------------------------------------------------------------------------------	
IF OBJECT_ID('tempdb.dbo.#Top5', 'U') IS NOT NULL  DROP TABLE #Top5
CREATE TABLE #Top5	(
		RcdId						INT IDENTITY	,
		GroupBy						NVARCHAR(255)	,
		Value						FLOAT			)
---------------------------------------------------------------------------------------------------	
DECLARE @Output	TABLE(
		Equipment					NVARCHAR(255)	,
		PUId						INT				,
		Position					NVARCHAR(255)	,
		GroupBy						NVARCHAR(255)	,
		Value						FLOAT			)
---------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- Get Equipment Info
-- --------------------------------------------------------------------------------------------------------------------
IF NOT @groupBy = 'Line'
BEGIN
	INSERT INTO @Equipment(
			PUId)
			SELECT String FROM fnLocal_Split(@workCellId,',')

	UPDATE e
		SET PLId = (SELECT PLId FROM dbo.Workcell_Dimension w (NOLOCK) WHERE w.PUId = e.PUId AND PLId IN (SELECT String FROM fnLocal_Split(@prodLineId,',')))
	FROM @Equipment e
END
ELSE
BEGIN
	INSERT INTO @Equipment(
			PUId,
			PLID)
			SELECT PUId, PLID
			FROM dbo.Workcell_Dimension (NOLOCK)
			WHERE PLId IN (SELECT String FROM fnLocal_Split(@prodLineId,','))
END		
-- --------------------------------------------------------------------------------------------------------------------
-- Validation for MTD when It's the 1 Day of the month
-- --------------------------------------------------------------------------------------------------------------------
IF @timeOption = 5 AND ((SELECT DAY(GETDATE())) = 1)
BEGIN
	SET @timeOption = 6
END
-- --------------------------------------------------------------------------------------------------------------------
-- Update @Equipment table with all the needed values
-- --------------------------------------------------------------------------------------------------------------------

--update plid, VSId and pudesc 
UPDATE e
	SET PLID = (SELECT PLID FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId AND e.PLID = PLID),
		PUDesc = (SELECT PUDesc FROM dbo.WorkCell_Dimension WHERE PUId = e.PUId AND e.PLID = PLID)
FROM @Equipment e
--update the Start and End Time 
UPDATE e 
		SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
		FROM @Equipment e 
		OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f

IF @timeOption > 0
BEGIN
	--Update start time and end time if a time option is selected
	SELECT @strTimeOption = DateDesc 
	FROM [dbo].[DATE_DIMENSION] (NOLOCK)
	WHERE DateId = @timeOption

	UPDATE e 
			SET	e.StartTime = f.dtmStartTime, e.EndTime =	f.dtmEndTime
			FROM @Equipment e 
			OUTER APPLY dbo.fnGetStartEndTimeiODS(@strTimeOption,e.plid) f
END
ELSE
BEGIN
	--update the Start and End Time from input parameters (user defined selected on report)
	UPDATE e 
			SET	e.StartTime = @startTime, e.EndTime = @endTime
	FROM @Equipment e
			
END
-- --------------------------------------------------------------------------------------------------------------------
-- Get NPT
-- --------------------------------------------------------------------------------------------------------------------
	SELECT			@strNPT = (SELECT CASE @excludeNPT WHEN 1 THEN 'PR In:' ELSE 'PR' END)
--SELECT '@Equipment',* from @Equipment

-- --------------------------------------------------------------------------------------------------------------------
-- Downtime Details
-- --------------------------------------------------------------------------------------------------------------------
	INSERT INTO #DowntimeRawData(
			 Duration
			,PUId
			,PUDesc
			,Fault
			,Location
			,Reason
			,IsStop
			,Planned)
	SELECT		
		 od.Duration			
		,od.PUId	
		,od.PUDesc			
		,od.Fault			
		,od.Location		
		,od.Reason1			
		,DTStatus	
		,Planned
	FROM @Equipment e
	JOIN [dbo].[OpsDB_DowntimeUptime_Data]	od (NOLOCK) ON od.PUId = e.PUId
	WHERE 1=1
	AND od.PUId	= e.PUId
	AND (od.LineStatus	LIKE '%' + @strNPT + '%')
	AND od.StartTime >= e.StartTime
	AND od.EndTime <= e.EndTime
	AND od.DeleteFlag		= 0
	ORDER BY od.PUDesc
			--,ProductionDay
			,od.StartTime

--SELECT '#DowntimeRawData',* from #DowntimeRawData

 ----------------------------------------------------------------------------------------------------------------------
 --Downtime TOP 5 
 ----------------------------------------------------------------------------------------------------------------------
IF (@bShowTop5Downtimes = 1)
BEGIN
	INSERT INTO #DowntimeTop5(
			 Duration
			,PUId
			,PUDesc
			,Fault
			,Location
			,Reason
			,IsStop
			,Planned)
	SELECT		
			 Duration		
			,PUId
			,PUDesc			
			,Fault			
			,Location		
			,Reason		
			,IsStop			
			,Planned
	FROM #DowntimeRawData 
	ORDER BY PUDesc
	
	-------------------------------------------------------------------------------------------------
	-- Apply Planned/Unplanned filter
	-------------------------------------------------------------------------------------------------
	IF UPPER(@strDTType) = 'PLANNED'
	DELETE FROM #DowntimeTop5 WHERE Planned = 0
	ELSE IF UPPER(@strDTType) = 'UNPLANNED'
	DELETE FROM #DowntimeTop5 WHERE Planned = 1

	SET @index = 1
		SELECT @maxIndex = COUNT(*) FROM @Equipment

		WHILE @index <= @maxIndex
		BEGIN
			TRUNCATE TABLE #Top5
			
			IF @strDTGrouping = 'Location'
		
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(dt.Location,''), SUM(dt.Duration)							
					FROM #DowntimeTop5	dt	
					JOIN @Equipment		e ON e.PUId  = dt.PUId
					WHERE	e.RcdIdx = @index
					GROUP BY dt.Location
					ORDER BY SUM(dt.Duration) DESC
									
			ELSE IF @strDTGrouping = 'Reason'
		
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(dt.Reason,''), SUM(dt.Duration)							
					FROM #DowntimeTop5	dt	
					JOIN @Equipment		e ON e.PUId  = dt.PUId
					WHERE	e.RcdIdx = @index
					GROUP BY dt.Reason
					ORDER BY SUM(dt.Duration) DESC
				
			ELSE
		
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(dt.Fault,''), SUM(dt.Duration)							
					FROM #DowntimeTop5	dt	
					JOIN @Equipment		e ON e.PUId  = dt.PUId
					WHERE	e.RcdIdx = @index
					GROUP BY dt.Fault
					ORDER BY SUM(dt.Duration) DESC
			
			SELECT @i = MAX(RcdId) + 1 FROM #Top5 
			WHILE @i <= 5 BEGIN INSERT INTO #Top5 SELECT TOP 1 '',NULL FROM #Top5 SET @i = @i + 1 END
			
			IF NOT EXISTS (SELECT * FROM #Top5)
			BEGIN
				SET @i = 1
				WHILE 
					@i <= 5 
					BEGIN 
					INSERT INTO #Top5 
					VALUES(NULL,NULL) 
					SET @i = @i + 1 
				END
			END

			INSERT INTO @Output
			SELECT e.PUDesc, e.PUId, t5.RcdId, t5.GroupBy,t5.Value
			FROM @Equipment e
			JOIN #Top5 t5 ON e.RcdIdx = @index
			ORDER BY t5.Value DESC

			--select '#Top5',* from #Top5
			SET @index = @index + 1
		END	
END

SELECT Equipment,Position,GroupBy,Value FROM @Output ORDER BY PUId, Position

--	Empty temporal tables
TRUNCATE TABLE #Top5
DELETE FROM @Output

 ----------------------------------------------------------------------------------------------------------------------
 --Stops TOP 5 
 ----------------------------------------------------------------------------------------------------------------------
IF (@bShowTop5Stops = 1)
BEGIN
	INSERT INTO #StopsTop5(
			 Duration
			,PUId
			,PUDesc
			,Fault
			,Location
			,Reason
			,IsStop
			,Planned)
	SELECT		
			 Duration		
			,PUId
			,PUDesc			
			,Fault			
			,Location		
			,Reason		
			,IsStop			
			,Planned
	FROM #DowntimeRawData 
	WHERE IsStop = 1
	ORDER BY PUDesc

	-------------------------------------------------------------------------------------------------
	-- Apply Planned/Unplanned filter
	-------------------------------------------------------------------------------------------------
	IF UPPER(@strStopsType) = 'PLANNED'
	DELETE FROM #StopsTop5 WHERE Planned = 0
	ELSE IF UPPER(@strStopsType) = 'UNPLANNED'
	DELETE FROM #StopsTop5 WHERE Planned = 1

	SET @index = 1
		SELECT @maxIndex = COUNT(*) FROM @Equipment

		WHILE @index <= @maxIndex
		BEGIN
			TRUNCATE TABLE #Top5
			
			IF @strStopsGrouping = 'Location'
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(ds.Location,''), COUNT(ds.isStop)							
					FROM #StopsTop5	ds	
					JOIN @Equipment		e ON e.PUId  = ds.PUId
					WHERE	e.RcdIdx = @index
						AND ds.isStop = 1
					GROUP BY ds.Location
					ORDER BY COUNT(ds.isStop) DESC
					
			ELSE IF @strStopsGrouping = 'Reason'
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(ds.Reason,''), COUNT(ds.isStop)							
					FROM #StopsTop5	ds	
					JOIN @Equipment		e ON e.PUId  = ds.PUId
					WHERE	e.RcdIdx = @index
						AND ds.isStop = 1
					GROUP BY ds.Reason
					ORDER BY COUNT(ds.isStop) DESC
			ELSE
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(ds.Fault,''), COUNT(ds.isStop)							
					FROM #StopsTop5	ds	
					JOIN @Equipment		e ON e.PUId  = ds.PUId
					WHERE	e.RcdIdx = @index
						AND ds.isStop = 1
					GROUP BY ds.Fault
					ORDER BY COUNT(ds.isStop) DESC

			SELECT @i = MAX(RcdId) + 1 FROM #Top5 
			WHILE @i <= 5 BEGIN INSERT INTO #Top5 SELECT TOP 1 '',NULL FROM #Top5 SET @i = @i + 1 END
			
			IF NOT EXISTS (SELECT * FROM #Top5)
			BEGIN
				SET @i = 1
				WHILE 
					@i <= 5 
					BEGIN 
					INSERT INTO #Top5 
					VALUES(NULL,NULL) 
					SET @i = @i + 1 
				END
			END

			INSERT INTO @Output
			SELECT e.PUDesc, e.PUId, t5.RcdId, t5.GroupBy,t5.Value
			FROM @Equipment e
			JOIN #Top5 t5 ON e.RcdIdx = @index
			ORDER BY t5.Value DESC

			SET @index = @index + 1
		END	
END
SELECT Equipment,Position,GroupBy,Value FROM @Output ORDER BY PUId, Position

--	Empty temporal tables
TRUNCATE TABLE #Top5
DELETE FROM @Output
 ----------------------------------------------------------------------------------------------------------------------
 --Scrap TOP 5
 ----------------------------------------------------------------------------------------------------------------------
IF (@bShowTop5Scrap = 1)
BEGIN
	INSERT INTO #ScrapTop5(
			 Amount
			,PLId
			,PUId
			,PUDesc
			,Fault
			,Location
			,Reason
			,ManualWaste
			,Timest)
	SELECT		
			 rd.Amount
			,rd.PLId		
			,rd.PUId
			,rd.PUDesc			
			,rd.Fault			
			,rd.Location		
			,rd.Reason1
			,rd.ManualWaste	
			,rd.Timestamp
	FROM @Equipment e
	JOIN [dbo].[OpsDB_Reject_Data]			rd (NOLOCK) ON rd.PUId = e.PUId
	WHERE 1=1
	AND rd.Timestamp	> e.StartTime
	AND rd.Timestamp	<= e.EndTime
	ORDER BY rd.PUDesc
			,rd.Timestamp

	IF @excludeNPT = 1
	BEGIN
		DELETE s
		FROM #ScrapTop5 s
		JOIN dbo.OpsDB_Production_Data pd (NOLOCK) ON s.PUId = pd.PUId
																AND s.Timest	> pd.StartTime
																AND s.Timest	<= pd.EndTime
		WHERE pd.LineStatus NOT LIKE '%' + @strNPT + '%' 
	END
	-------------------------------------------------------------------------------------------------
	-- Apply Planned/Unplanned filter
	-------------------------------------------------------------------------------------------------
	IF @strScrapType = 'Manual'
		DELETE FROM #ScrapTop5 WHERE ManualWaste = 0
	ELSE IF @strScrapType = 'Automatic'
		DELETE FROM #ScrapTop5 WHERE ManualWaste = 1

	SET @index = 1
		SELECT @maxIndex = COUNT(*) FROM @Equipment

		WHILE @index <= @maxIndex
		BEGIN
			TRUNCATE TABLE #Top5
			
			IF @strScrapGrouping = 'Location'
		
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(st.Location,''), SUM(st.Amount)							
					FROM #ScrapTop5	st	
					JOIN @Equipment		e ON e.PUId  = st.PUId
					WHERE	e.RcdIdx = @index
					GROUP BY st.Location
					ORDER BY SUM(st.Amount) DESC
									
			ELSE IF @strScrapGrouping = 'Reason'
		
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(st.Reason,''), SUM(st.Amount)							
					FROM #ScrapTop5	st	
					JOIN @Equipment		e ON e.PUId  = st.PUId
					WHERE	e.RcdIdx = @index
					GROUP BY st.Reason
					ORDER BY SUM(st.Amount) DESC
				
			ELSE
		
					INSERT INTO #Top5
					SELECT TOP 5 ISNULL(st.Fault,''), SUM(st.Amount)							
					FROM #ScrapTop5	st	
					JOIN @Equipment		e ON e.PUId  = st.PUId
					WHERE	e.RcdIdx = @index
					GROUP BY st.Fault
					ORDER BY SUM(st.Amount) DESC
			
			SELECT @i = MAX(RcdId) + 1 FROM #Top5 
			WHILE @i <= 5 BEGIN INSERT INTO #Top5 SELECT TOP 1 '',NULL FROM #Top5 SET @i = @i + 1 END
			
			IF NOT EXISTS (SELECT * FROM #Top5)
			BEGIN
				SET @i = 1
				WHILE 
					@i <= 5 
					BEGIN 
					INSERT INTO #Top5 
					VALUES(NULL,NULL) 
					SET @i = @i + 1 
				END
			END

			INSERT INTO @Output
			SELECT e.PUDesc, e.PUId, t5.RcdId, t5.GroupBy,t5.Value
			FROM @Equipment e
			JOIN #Top5 t5 ON e.RcdIdx = @index
			ORDER BY t5.Value DESC

			--select '#Top5',* from #Top5
			SET @index = @index + 1
		END	
END

SELECT Equipment,Position,GroupBy,Value FROM @Output ORDER BY PUId, Position

DROP TABLE #Top5
DROP TABLE #DowntimeRawData
DROP TABLE #DowntimeTop5
DROP TABLE #StopsTop5
DROP TABLE #ScrapTop5
GO
GRANT  EXECUTE  ON [dbo].[spRptTop5Daily]  TO OpDBWriter
GO