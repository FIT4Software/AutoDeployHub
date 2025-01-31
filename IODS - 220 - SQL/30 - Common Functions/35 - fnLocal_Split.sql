-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script													--	
--						This Script will create the fnLocal_Split function in Auto_opsDataStore					--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4												--	
-------------------------------------------------------------------------------------------------------------
-- 1.00 xxxx-xx-xx		Arido Software.			Initial Development											--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Object:  UserDefinedFunction [dbo].[fnLocal_Split]    Script Date: 28/04/2017 12:33:33 p.m. ******/
SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

----------------------------------------------------------------------------------------------------------------------
-- DROP Function
----------------------------------------------------------------------------------------------------------------------

IF EXISTS (SELECT 1 FROM Information_schema.Routines WHERE Specific_schema = 'dbo' AND specific_name = 'fnLocal_Split' AND Routine_Type = 'FUNCTION')
BEGIN
	DROP FUNCTION [dbo].[fnLocal_Split]
END
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'fnLocal_Split',
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

-------------------------------------[Creation Of Function]--------------------------------------
CREATE FUNCTION [dbo].[fnLocal_Split](@String VARCHAR(8000), @Delimiter CHAR(1))
RETURNS @Strings TABLE([id] INT IDENTITY, String VARCHAR(8000))


/*
SQL Function			:		fnLocal_Split
Author					:		Stephane Turner (System Technologies for Industry Inc)
Date Created			:		07-May-2007
Function Type			:		Table-Valued
Editor Tab Spacing	:		3

Description:
===========
Returns a Table variable from a string containing a list of values separated by a delimiter.

CALLED BY				:  SP


Revision 			Date				Who							What
========			===========		==================		=================================================================================
1.1				04-June-2012	Namrata Kumar			Appversions corrected
1.0.0				07-May-2007		Stephane Turner			Creation


TEST CODE :
SELECT * FROM dbo.fnLocal_Split ('One, Two, Three, Four, Five', ',')

*/

AS
BEGIN
  
 WHILE(CHARINDEX(@Delimiter, @String) > 0)
	 BEGIN
		  INSERT INTO @Strings(String)
		  SELECT LTRIM(RTRIM(SUBSTRING(@String, 1, CHARINDEX(@Delimiter, @String) - 1)))
		 
		  SET @String = SUBSTRING(@String, CHARINDEX(@Delimiter, @String) + 1, LEN(@String))
	 END
 
 IF LEN(@String) > 0
	 BEGIN
		INSERT INTO @Strings(String) SELECT @String
	 END
 
 RETURN
END
 

GO


