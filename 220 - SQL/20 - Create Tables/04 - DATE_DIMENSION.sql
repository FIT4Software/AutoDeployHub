-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the DATE_DIMENSION table in AutoDeployHubDB						--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0 2018-04-20		Carreño Maximiliano.	Initial Development												--
-- 1.1 2018-06-29		Issa Luana.				Split Original Script by Table									--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Table [dbo].[DATE_DIMENSION]******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'DATE_DIMENSION') AND type = 'U')
BEGIN
	CREATE TABLE [dbo].[DATE_DIMENSION](
		[DateId] [int] NOT NULL,
		[DateDesc] [nvarchar](200) NULL,
		[RelativeStartTime] [nvarchar](500) NULL,
		[RelativeEndTime] [nvarchar](500) NULL,
	 CONSTRAINT [PK_DATE_DIMENSION] PRIMARY KEY CLUSTERED 
	(
		[DateId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END
ELSE
BEGIN
	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns where Table_Name='DATE_DIMENSION'
END
GO
