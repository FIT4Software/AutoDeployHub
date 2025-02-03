

-----------------------------------------------------------------------------------------------------------------------
-- Drop Function
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (
			SELECT * FROM dbo.sysobjects 
				WHERE Id = OBJECT_ID(N'[dbo].[spLocal_CmnRptDDSStartEndTime]') 
				AND OBJECTPROPERTY(id, N'IsProcedure') = 1					
			)
DROP PROCEDURE [dbo].[spLocal_CmnRptDDSStartEndTime]


GO

-----------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spLocal_CmnRptDDSStartEndTime
-----------------------------------------------------------------------------------------------------------------------
-- ====================================================================================================================
-- Author:		Martin Casalis - Arido Software
-- Create date: 2014-03-31
-- Description:	This stored procedure calls the function fnLocal_DDSStartEndTime and it is used by SSRS to get relative dates
-- ====================================================================================================================
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- =====	====	  		====				=====
-- 1.0		2014-03-31		Martin Casalis    	Initial Release
-- 1.1		2015-06-26		Martin Casalis		FO-02211: For all DMO project reports remove the database reference from all code
-- ====================================================================================================================
CREATE PROCEDURE [dbo].[spLocal_CmnRptDDSStartEndTime]
--DECLARE	
		@vchTimeOption			VARCHAR(50)
---------------------------------------------------------------------------------------------------	
--WITH ENCRYPTION
AS
---------------------------------------------------------------------------------------------------
--	Test Statements
	--SELECT @vchTimeOption = 'LastWeek'
---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
-- DATETIME Variables
---------------------------------------------------------------------------------------------------
DECLARE
		@dtmStartTime			DATETIME		,
		@dtmEndTime				DATETIME
---------------------------------------------------------------------------------------------------
-- Get the Start and End Time for the Report
---------------------------------------------------------------------------------------------------
SELECT  @dtmStartTime	= dtmStartTime	,
		@dtmEndTime		= dtmEndTime
FROM	dbo.fnLocal_DDSStartEndTime ( @vchTimeOption )


SELECT
		@dtmStartTime	AS	'StartTime'	,
		@dtmEndTime		AS  'EndTime'
				

-- ====================================================================================================================

SET NOCOUNT OFF
GO
GRANT EXECUTE ON [dbo].[spLocal_CmnRptDDSStartEndTime] TO [SSRSDDSUser] As [dbo]
GO