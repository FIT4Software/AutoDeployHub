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
		@SP_Name	= 'spCmnSaveEditiODSDefinitions',
		@Inputs		= 6, 
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
				
DROP PROCEDURE [dbo].[spCmnSaveEditiODSDefinitions]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO
-----------------------------------------------------------------------------------------------------------------------
-- Stored Procedure: spCmnSaveEditiODSDefinitions
-----------------------------------------------------------------------------------------------------------------------
-- Author				: Gonzalo Luc - Arido Software
-- Date created			: 2018-05-28
-- Version 				: 1
-- SP Type				: Report Stored Procedure
-- Caller				: Report
-- Description			: This stored procedure saves and edit definitions for iODS reports
--  -----------					---------
	
-- Editor tab spacing	: 4 
-- --------------------------------------------------------------------------------------------------------------------
-- --------------------------------------------------------------------------------------------------------------------
-- EDIT HISTORY:
-- --------------------------------------------------------------------------------------------------------------------
-- ========	====	  		====					=====
-- 1.0		2018-05-28		Gonzalo Luc     		Initial Release
-- 1.1		2019-10-10		Damian Campana     		Set Local parameter when update definition
--=====================================================================================================================
CREATE PROCEDURE [dbo].[spCmnSaveEditiODSDefinitions]
-- --------------------------------------------------------------------------------------------------------------------
-- Report Parameters
--=====================================================================================================================
--DECLARE	
		@strReportTypeId	NVARCHAR(200)		,		-- Report name
		@strDefinitionId	NVARCHAR(200)		,		-- Definition id
		@strdefinitionName	NVARCHAR(200)		,		-- Definition name
		@strdefinitionValue NVARCHAR(MAX)		,		-- Definition value
		@bitLocal			BIT					,		-- Local or Global definition
		@strUserName		NVARCHAR(50)				-- User name

-----------------------------------------------------------------------------------------------------------------------	
--WITH ENCRYPTION
AS
SET NOCOUNT ON

---------------------------------------------------------------------------------------------------
DECLARE

--Error Variables
@ErrorMessage			NVARCHAR(4000),
@ErrorSeverity			INT,
@ErrorState				INT
--=================================================================================================
IF @strDefinitionId = ''
BEGIN
	---------------------------------------------------------------------------------------------------
	-- Insert New Definition
	---------------------------------------------------------------------------------------------------
	BEGIN TRY
		INSERT INTO dbo.ReportDefinition(User_Name,Value,Def_Name,Local,ReportTypeId) 
		VALUES (@strUserName, @strdefinitionValue, @strdefinitionName, @bitLocal, @strReportTypeId)
		
	END TRY
	BEGIN CATCH

		SELECT @ErrorMessage = 'Sql Error',
			   @ErrorSeverity = 16,
			   @ErrorState = 1;

		RAISERROR (@ErrorMessage, -- Message text.
				   @ErrorSeverity, -- Severity.
				   @ErrorState) -- State.
		ROLLBACK
		RETURN

	END CATCH
	SET NOCOUNT OFF
	

END
ELSE
BEGIN
	---------------------------------------------------------------------------------------------------
	-- Update Parameter values
	---------------------------------------------------------------------------------------------------
	BEGIN TRY
		
		UPDATE  dbo.ReportDefinition SET Value = @strdefinitionValue, Local = @bitLocal, Def_Name = @strdefinitionName WHERE Def_Id = @strDefinitionId
		
	END TRY
	BEGIN CATCH
		SELECT @ErrorMessage = 'Sql Error',
			   @ErrorSeverity = 16,
			   @ErrorState = 1;

		RAISERROR (@ErrorMessage, -- Message text.
				   @ErrorSeverity, -- Severity.
				   @ErrorState) -- State.
		ROLLBACK
		RETURN

	END CATCH
	SET NOCOUNT OFF
	
END
GO
GRANT EXECUTE ON [dbo].[spCmnSaveEditiODSDefinitions] TO [OPDBWriter]
GO
