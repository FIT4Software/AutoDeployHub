USE [OpsDataTest]
GO

-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the WorkCell_Dimension table in OpsDataTest					--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0 2018-04-20		Carre�o Maximiliano.	Initial Development												--
-- 1.1 2018-06-29		Issa Luana.				Split Original Script by Table									--
-- 1.2 2018-11-20       Giraudi Daniela         Added class field
-- 1.3 2019-01-30		Mrakovich Eduardo		Add PUDescGlobal Fields
-- 1.4 2019-02-04		Mrakovich Eduardo		Add PLDescGlobal Fields
-- 1.5 2019-02-14       Giraudi Daniela         Added IsActiveDowntime field
-- 1.6 2022-05-04       Mauro Pasetti			ADD Indexes from "script create index in iODS"
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Table [dbo].[WorkCell_Dimension]******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'WorkCell_Dimension') AND type = 'U')
BEGIN
	CREATE TABLE [dbo].[WorkCell_Dimension](
		[PUDesc] [nvarchar](50) NOT NULL,
        [PUDescGlobal][Varchar](50) Null,
		[PUId] [int] NOT NULL,
		[WorkCellId] [int] IDENTITY(0,1) NOT NULL,
		[PLId] [int] NULL,
		[VSId] [int] NULL,
		[Class] [int] NULL,
		[IsActiveDowntime] [int] NOT NULL DEFAULT 1,
	 CONSTRAINT [PK_WorkCell_Dimension] PRIMARY KEY CLUSTERED 
	(
		[WorkCellId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END
ELSE
BEGIN
	--Special Lines
	IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'Class' AND Object_ID = Object_ID(N'dbo.WorkCell_Dimension'))
		ALTER TABLE dbo.WorkCell_Dimension ADD Class INT NULL;

	IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'IsActiveDowntime' AND Object_ID = Object_ID(N'dbo.WorkCell_Dimension'))
		ALTER TABLE dbo.WorkCell_Dimension ADD [IsActiveDowntime] [int] NOT NULL CONSTRAINT D_WorkCell_Dimension_IsActiveDowntime DEFAULT (1);
	
    --	FO-3634
	IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'PUDescGlobal' AND Object_ID = Object_ID(N'dbo.WorkCell_Dimension'))
		BEGIN
			IF NOT EXISTS(SELECT * FROM sys.columns WHERE Name = N'PUDescGlobal' AND Object_ID = Object_ID(N'dbo.WorkCell_Dimension'))
				ALTER TABLE dbo.WorkCell_Dimension ADD PUDescGlobal Varchar(50) NULL;
			DECLARE @DBNAME NVARCHAR(50)
			DECLARE @QUERY NVARCHAR(MAX)
			IF DB_NAME(DB_ID('GBDB'))='GBDB'
				SET @DBNAME='GBDB'
			ELSE
				SET @DBNAME='SOADB'

			SET @QUERY=N'Update w set w.PUDescGlobal = u.PU_Desc_Global From dbo.WorkCell_dimension w with(nolock) join '+@DBNAME+'.dbo.Prod_Units_Base u with(nolock) on w.puid=u.PU_ID';
			EXEC sp_executesql @QUERY  
		END
        
	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns where Table_Name='WorkCell_Dimension'
END
GO
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[WorkCell_Dimension]') AND name = N'IX_WorkCell_Dimension_PLId_PUId')
	CREATE NONCLUSTERED INDEX IX_WorkCell_Dimension_PLId_PUId
	ON [dbo].[WorkCell_Dimension] ([PLId] ASC,[PUId] ASC); 
GO