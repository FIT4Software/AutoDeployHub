USE [master]
GO

--------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script													--	
--								This Script creates the OpsDataTest database								--
--------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4												--	
--------------------------------------------------------------------------------------------------------------
-- Arido Software.					Initial Development
-- Arido Software.					Carreno Maximiliano	Remove code if the DB exist
-- 2022-04-13	Mauro Pasetti		AUTHORIZATION to [sa]
--------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT * FROM master.dbo.sysdatabases WHERE name = N'OpsDataTest')
BEGIN
	--CREATE NEW Data Base
	CREATE DATABASE [OpsDataTest]
	ALTER DATABASE [OpsDataTest] SET RECOVERY SIMPLE
	ALTER AUTHORIZATION ON DATABASE::[OpsDataTest] TO [sa]
END
GO
