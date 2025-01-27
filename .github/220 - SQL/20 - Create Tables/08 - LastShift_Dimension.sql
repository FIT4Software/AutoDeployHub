USE [AutoDeployHubDB]
GO

-------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script														--	
--						This Script will create the LastShift_Dimension table in AutoDeployHubDB					--
-------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4													--	
-------------------------------------------------------------------------------------------------------------
-- 1.0 2018-04-20		Carreño Maximiliano.	Initial Development												--
-- 1.1 2018-06-29		Issa Luana.				Split Original Script by Table									--
-------------------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------------------

/******  Table [dbo].[LastShift_Dimension]  ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = object_id(N'LastShift_Dimension') AND type = 'U')
BEGIN

	CREATE TABLE [dbo].[LastShift_Dimension](
		[LineId] [int] NOT NULL,
		[WorkCellid] [int] NOT NULL,
		[Starttime] [datetime] NOT NULL,
		[Endtime] [datetime] NOT NULL,
		[PLdesc] [nchar](50) NULL,
		[PUDesc] [nchar](50) NULL,
		[Dateid] [int] NULL,
		[Datedesc] [nchar](50) NULL,
		[LastDate] [datetime] NULL,
	 CONSTRAINT [PK_LastShift_Dimension_1] PRIMARY KEY CLUSTERED 
	(
		[LineId] ASC,
		[WorkCellid] ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
	) ON [PRIMARY]

END
ELSE 
BEGIN
	--UPDATE AND CHANGES

	--FO-3460

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'WorkCellid' AND Object_ID = Object_ID(N'dbo.LastShift_Dimension'))
	BEGIN
		ALTER TABLE dbo.LastShift_Dimension ADD [WorkCellid] [int] NOT NULL DEFAULT 0;

		DECLARE @sql NVARCHAR(MAX) = N'';

		select @sql += 'ALTER TABLE dbo.LastShift_Dimension DROP CONSTRAINT ' +  name + ';'
		from sys.all_objects pk with(nolock) 
		where pk.parent_object_id in (
			select tb.object_id from sys.all_objects tb with(nolock) where tb.name='LastShift_Dimension') 
		and type='PK' 

		EXEC sp_executesql @sql;

		ALTER TABLE dbo.LastShift_Dimension
		ADD CONSTRAINT [PK_LastShift_Dimension] PRIMARY KEY CLUSTERED (
			[LineId] ASC, [WorkCellid] ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]

		DELETE dbo.LastShift_Dimension
	END

	IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'Linedesc' AND Object_ID = Object_ID(N'dbo.LastShift_Dimension'))
	BEGIN
		EXEC sp_rename 'LastShift_Dimension.Linedesc', 'PLdesc', 'COLUMN';
	END

	IF NOT EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'PUDesc' AND Object_ID = Object_ID(N'dbo.LastShift_Dimension'))
	BEGIN
		ALTER TABLE dbo.LastShift_Dimension ADD [PUDesc] [nchar](50) NULL;
	END

	SELECT 'This table already exists in the database'
	select Column_Name, Data_Type, Character_Maximum_Length, IS_NULLABLE, columnproperty(object_id(TABLE_NAME),Column_Name,'IsIdentity') as 'IDENTITY' from INFORMATION_SCHEMA.Columns where Table_Name='LastShift_Dimension'
END
