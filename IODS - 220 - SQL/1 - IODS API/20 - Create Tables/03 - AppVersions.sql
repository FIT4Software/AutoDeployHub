-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the AppVersions table in Auto_Auto_opsDataStore							--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0 2018-04-20		Carreño Maximiliano.	Initial Development												--
-- 1.1 2018-06-29		Issa Luana.				Split Original Script by Table									--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Table [dbo].[AppVersions]******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'AppVersions') AND type = 'U')
BEGIN
	CREATE TABLE [dbo].[AppVersions](
		[App_Id] [int] IDENTITY(1,1) NOT NULL,
		[App_Name] [varchar](100) NOT NULL,
		[App_Version] [varchar](25) NOT NULL,
		[Modified_On] [datetime] NOT NULL
	) ON [PRIMARY]
END
ELSE
BEGIN

	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns where Table_Name='AppVersions'

END
GO
SET ANSI_PADDING OFF
GO
