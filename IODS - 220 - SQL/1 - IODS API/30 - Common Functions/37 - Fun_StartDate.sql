-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script													--	
--						This Script will create the FUN_StartDate function in Auto_Auto_opsDataStore					--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4												--	
-------------------------------------------------------------------------------------------------------------
-- 1.00 xxxx-xx-xx		Arido Software.			Initial Development											--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Object:  UserDefinedFunction [dbo].[FUN_StartDate]    Script Date: 28/04/2017 12:38:38 p.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

----------------------------------------------------------------------------------------------------------------------
-- DROP Function
----------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'FUN_StartDate' AND Routine_Type = 'FUNCTION')
BEGIN
	DROP FUNCTION [dbo].[FUN_StartDate]
END
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'FUN_StartDate',
		@Version	= '1.00'  


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
GO
--=====================================================================================================================

CREATE FUNCTION [dbo].[FUN_StartDate](@inLine AS Varchar(10),@InDate AS DateTime)
RETURNS DateTime
AS
BEGIN
DECLARE @Date DateTime

SELECT @Date=CONVERT(DateTime,CONVERT(NVARCHAR(10),@InDate,121)+' '+ShiftStartTime) FROM dbo.Line_Dimension Where LIneDesc=@InLine

IF @Date>@InDate
	SELECT @Date = @Date - 1

RETURN @Date
END



GO


