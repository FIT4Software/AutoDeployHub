USE [master]
GO

--------------------------------------------------------------------------------------------------------------
-- 										OPS Database Script													--	
--								This Script creates the Auto_opsDataStore database								--
--------------------------------------------------------------------------------------------------------------
-- 										SET TAB SPACING TO 4												--	
--------------------------------------------------------------------------------------------------------------
-- Arido Software.					Initial Development
-- Arido Software.					Carreno Maximiliano	Remove code if the DB exist
-- 2022-04-13	Mauro Pasetti		AUTHORIZATION to [sa]
--------------------------------------------------------------------------------------------------------------

IF NOT EXISTS (SELECT * FROM master.dbo.sysdatabases WHERE name = N'Auto_opsDataStore')
BEGIN
	--CREATE NEW Data Base
	CREATE DATABASE [Auto_opsDataStore]
	ALTER DATABASE [Auto_opsDataStore] SET RECOVERY SIMPLE
	ALTER AUTHORIZATION ON DATABASE::[Auto_opsDataStore] TO [sa]
END
GO
