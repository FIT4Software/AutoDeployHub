USE [master]
GO

--------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script													--	
--								This Script creates the AutoDeployHubDB database								--
--------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4												--	
--------------------------------------------------------------------------------------------------------------
-- Arido Software.					Initial Development
-- Arido Software.					Carreno Maximiliano	Remove code if the DB exist
-- 2022-04-13	Mauro Pasetti		AUTHORIZATION to [sa]
--------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT * FROM master.dbo.sysdatabases WHERE name = N'AutoDeployHubDB')
BEGIN
	--CREATE NEW Data Base
	CREATE DATABASE [AutoDeployHubDB]
	ALTER DATABASE [AutoDeployHubDB] SET RECOVERY SIMPLE
	ALTER AUTHORIZATION ON DATABASE::[AutoDeployHubDB] TO [sa]
END
GO
