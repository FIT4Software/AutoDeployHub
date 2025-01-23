USE [OpsDataTest]
GO

-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the PRODUCT_DIMENSION table in OpsDataTest						--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0 2018-04-20		Carreño Maximiliano.	Initial Development												--
-- 1.1 2018-06-29		Issa Luana.				Split Original Script by Table									--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/******  Table [dbo].[PRODUCT_DIMENSION]  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'PRODUCT_DIMENSION') AND type = 'U')
BEGIN
	CREATE TABLE [dbo].[PRODUCT_DIMENSION](
		[ProductId] [int] NOT NULL,
		[ProductDesc] [nvarchar](200) NULL,
		[ProdPlatform] [nvarchar](200) NULL,
		[Size] [nchar](10) NULL,
	 CONSTRAINT [PK_PRODUCT_DIMENSION] PRIMARY KEY CLUSTERED 
	(
		[ProductId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END
ELSE
BEGIN
	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns where Table_Name='PRODUCT_DIMENSION'
END
GO
