USE [OpsDataTest]
GO

-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the LINE_DIMENSION table in OpsDataTest						--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0	2018-04-20		Carreño Maximiliano.	Initial Development												--
-- 1.1	2018-06-29		Issa Luana.				Split Original Script by Table									--
-- 1.2	2018-04-20		Carreño Maximiliano.	Add StartOfWeek and StartOfQtr									--
-- 1.3	2019-02-04		Mrakovich Eduardo		FO-3634: Add LineDescGlobal field	
-- 1.4	2019-08-16		Martin Casalis			Added Week Start Time field
--		2019-10-01		Martin Casalis			Added IsActive field
--      2020-04-23		Anoop Joshi				Added column for category varchar(250)
--      2021-08-18		Mauro Pasetti			ADD Category field in Update Script
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/****** Table [dbo].[LINE_DIMENSION]  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'LINE_DIMENSION') AND type = 'U')
BEGIN
	CREATE TABLE [dbo].[LINE_DIMENSION](
		[LineId] [int] IDENTITY(0,1) NOT NULL,
		[LineDesc] [nvarchar](50) NULL,
		[LineDescGlobal][nvarchar](50) NULL,
		[SiteId] [nvarchar](200) NULL,
		[BUId] [nvarchar](200) NULL,
		[PlatformId] [nvarchar](200) NULL,
		[ShiftStartTime] [nvarchar](10) NULL,
		[WeekStartTime] [datetime] NULL,
		[StartOfProd] [datetime] NULL,
		[StartOfConst] [datetime] NULL,
		[PlantId] [nvarchar](20) NULL,
		[RegionId] [nvarchar](25) NULL,
		[InitiativeId] [nvarchar](15) NULL,
		[PLId] [int] NULL,
		[ConfigType] [nvarchar](50) NULL,
		[DeptId] [int] NULL,
		[DeptDesc] [nvarchar](50) NULL,
		[StartOfWeek] [varchar](20) NULL DEFAULT '010630',
		[StartOfQtr] [varchar](20) NULL DEFAULT '010630',
		[Category] [varchar](250),
		[IsActive] [bit] NOT NULL DEFAULT 1,
	 CONSTRAINT [PK_LINE_DIMENSION] PRIMARY KEY CLUSTERED 
	(
		[LineId] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]
END
ELSE
BEGIN
	--UPDATE CHANGES
	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'ConfigType' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [ConfigType] [nvarchar](50) NULL;
	END

	--FO-03460

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'DeptId' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [DeptId] [int] NULL;
	END

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'DeptDesc' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [DeptDesc] [nvarchar](50) NULL;
	END

	--FO-3561

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'StartOfWeek' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [StartOfWeek] [varchar](20) NULL DEFAULT '010630';
	END

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'StartOfQtr' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [StartOfQtr] [varchar](20) NULL DEFAULT '010630';
	END

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'WeekStartTime' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [WeekStartTime] [datetime] NULL;
	END

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'IsActive' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [IsActive] [bit] NOT NULL DEFAULT 1;
	END

	--FO-3634

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'LineDescGlobal' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
		begin
			IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'LineDescGlobal' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
				ALTER TABLE dbo.LINE_DIMENSION ADD [LineDescGlobal] [Nvarchar](50) NULL;
			DECLARE @DBNAME NVARCHAR(50)
			DECLARE @QUERY NVARCHAR(MAX)
			IF DB_NAME(DB_ID('GBDB'))='GBDB'
				SET @DBNAME='GBDB'
			ELSE
				SET @DBNAME='SOADB'

			SET @QUERY=N'Update l set l.LineDescGlobal = p.PL_Desc_Global From line_dimension l with(nolock) join '+@DBNAME+'.dbo.Prod_Lines_Base p with(nolock) on l.plid=p.PL_ID';
			EXEC sp_executesql @QUERY  
		end
	
	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns with(nolock) where Table_Name='LINE_DIMENSION'
	--UPDATE CHANGES
	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'Category' AND Object_ID = Object_ID(N'dbo.LINE_DIMENSION'))
	BEGIN
		ALTER TABLE dbo.LINE_DIMENSION ADD [Category] [varchar](250);
	END
END

GO
