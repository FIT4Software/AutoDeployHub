USE [AutoDeployHubDB]
GO

-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the UDP_Dimension table in AutoDeployHubDB							--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0 2018-04-20		Carreño Maximiliano.	Initial Development												--
-- 1.1 2018-06-29		Issa Luana.				Split Original Script by Table									--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Table [dbo].[UDP_Dimension]  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'UDP_Dimension') AND type = 'U')
BEGIN
	CREATE TABLE [dbo].[UDP_Dimension](
		[UDPIdx] [int] NOT NULL,
		[TableId] [int] NOT NULL,
		[TableName] [varchar](200) NOT NULL,
		[UDPName] [varchar](500) NOT NULL,
		[DataType] [varchar](50) NOT NULL,
	 CONSTRAINT [UDP_Dimension_pk] PRIMARY KEY CLUSTERED 
	(
		[UDPIdx] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END
ELSE
BEGIN
	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns where Table_Name='UDP_Dimension'
END
GO
SET ANSI_PADDING OFF
GO
