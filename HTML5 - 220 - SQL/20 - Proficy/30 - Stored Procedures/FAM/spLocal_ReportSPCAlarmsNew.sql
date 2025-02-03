
USE [GBDB]
GO
DECLARE 
		@SPName			NVARCHAR(200),			--the name of the sp begin creted
		@Inputs			INT,					--the number of inputs
		@Version		NVARCHAR(20),			--the version number that matches version manager
		@AppId			INT						--the app_id of SOADB.dbo.appversions

SELECT
		@SPName		= 'spLocal_ReportSPCAlarmsNew',
		@Inputs		= 4,		                -- Put the number of inputs to the Stored Procedure
		@Version	= '3.1'		                -- Number should match version manager.
--=====================================================================================================================
--	Update table AppVersions
--=====================================================================================================================
IF (SELECT COUNT(*) 
		FROM [dbo].[AppVersions] WITH (NOLOCK)
		WHERE app_name LIKE @SPName) > 0
	BEGIN
		UPDATE [dbo].[AppVersions]
			SET app_version = @Version, Modified_On = GETDATE()
			WHERE app_name LIKE @SPName
	END
ELSE
	BEGIN
		SELECT @AppId = MAX(App_Id) + 1 
			FROM [dbo].[AppVersions] WITH (NOLOCK)
		INSERT INTO [dbo].[AppVersions]
		(
			App_Id,
			App_name,
			App_version
		)
		VALUES 
		(
			@AppId, 
			@SPName,
			@Version
		)
	END

-----------------------------------------------------------------------------------------------------------------------
-- Drop Stored Procedure
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (
			SELECT * FROM dbo.sysobjects 
				WHERE Id = OBJECT_ID(N'[dbo].[spLocal_ReportSPCAlarmsNew]') 
				AND OBJECTPROPERTY(id, N'IsProcedure') = 1					
			)
DROP PROCEDURE [dbo].[spLocal_ReportSPCAlarmsNew]
GO

/*
Stored Procedure:	spLocal_ReportSPCAlarmsNew
Author:			Fran Osorno
Date Created:		Jan. 25, 2005

Description:
=========
This procedure will return data for the SPC Alarms Report


INPUTS:
			@PL_Desc		VARCHAR(50),		--this is the Line desc
			@Start_Time		DATETIME,		--the report start time
			@End_Time		DATETIME		--the report end time

CALLED BY:  RptSPCAlarms..xlt (Excel/VBA Template)

CALLS:	dbo.fnLocal_GlblParseInfo

Rev		Change Date	Who	What
===	=========	====	=====
1		Jan. 25,2005		FGO		Placed into service
1.1		March 23,2005	FGO		Updated the code to handle SPC and All alarms
1.2		March 24,2005	FGo		Updated the look up for ScheduleUnit to handel both papermaking and converting lines
1.3		April 18,2006	FGO		Updated the code to do pmkg centerline template alarms
									added dbo to all objects
									Removed all _ from variable names
1.4		May 9, 2006		FGO		Updated to handle the addition of the actionreason trees
1.5   	 Nov 28, 2006	FGO		Changed all cause comments to action comments
1.6    	Oct 13, 2007		fgo		updated for Process Monitoring
1.7    	Oct 17, 2007		fgo		updated to return Production Group
2.0		May 16, 2008	fgo		major upgrade for RTT type reporting for FAM the @ReportType is RTT
									variables must be on an alarm template like Centerline Alarms or Process Monitoring Alarms and on a display like Qulaity RTT
									it will also report the last point in the window and verify if the data is out of limts and report it
									added language support
2.1		June 12, 2008	fgo		Added Display to all the resultsets for the @ReportType RTT
2.2		June 26, 2009 fgo		Updated the code to report all open alarms and all alarms opened within the report window
3.0		June 7, 2011	fgo		total update for FAM
		Oct 14 2016		fgo		updated for base tables
3.1   April 14, 2022   fgo		corrected the finding of the schedule unit as table filed values look to be incorrect and changed to the variables view to get the local description

*/

CREATE       PROCEDURE [dbo].[spLocal_ReportSPCAlarmsNew]
--code inputs
--declare 
	@PlDesc				varchar(50),	--the is ithe pl_desc_global
	@Start					datetime,			--this is the start time of the report window
	@End					datetime,			--this is the end time of the report window
	@ReportType		VARCHAR(50)		--this is the type of report SPC or ALL
	
with encryption
as
/*	
select
			@PLDesc				= 'FXBV021',
			@Start				= '6/3/11 06:50',
			@End				= '6/4/11 06:50'
*/			
--the internal code			
--the dimensions table
declare @Dimensions table (
	ID					int identity,			--the inentity of the table
	Dimension	varchar(100),		--the dimension 
	PUID			int,						--pu_id
	StartTime		datetime,				--start_time
	EndTime		datetime,				--end_Time
	value			varchar(100)		--value of the dimension
)
--table for paths
declare		@Paths table (
	PathID		int,							--the path id
	PLID			int							--the PLID
)
--table for path units
declare		@PathUnits table (
	PathID								int,		--the path_id
	PUID								int,		--the pu_id
	PLID									int,		--the pl_id
	Is_Production_Point		int		--the value of is_production_point
)
--table product runs by unit
declare @ProdsByUnit table (
	PUID			int,						--the pu_id
	ProdID			int,						--the prod_id
	StartTime		datetime,				--the Start_Time
	EndTime		datetime				--the End_Time
)
--the data for each unit, shift, product run during the time period
declare @LineStatusByUnit	 table (
	ID															int identity,		--the table identity
	PLID														int,					--the plid
	PUID													int,					--the puid
	LineStatus											varchar(25),	--the linestatus
	StartTime												datetime,			--the start time
	EndTime												datetime,			--the end time
	Team													varchar(10),	--this si the team of the shift
	ProdID													int,					--the prod_ID
	Downtime												float					--this is the downtime for the line
)
--the downtime for the line
declare @LineDowntime table (
	ID							int identity,			--this is the table identity
	PUID					int,						--the pu_id of the record
	StartTime				datetime,				--the starttime for the record of the report period
	EndTime				datetime,				--the endtime for the record of the report period
	Duration				real						--the downtime duration for the record of the report period
)
--the sheets to find all the variables to find
declare @Sheets table(
	ID							int identity,			--this is the table identity
	SheetID				int,						--this is the sheet id's for all the display to check variables for
	Interval				int						--this is the interval of the collection
)
--the variable to check
--declare #Variables table (
CREATE TABLE #Variables (
	ID							int identity,			--this is the table identity
	VARID					int,						--this is the varible ID
	Variable				varchar(50),		--this is the var_desc_local of rgbdb.dbo.variables
	Area						varchar(50),		--this is the pug_desc_local of the variable with ' Auto Data' and/or  ' Manual Data' removed from the description
	DataSource			varchar(25),		--this is the datasource
	Interval				int,						--this is the interval of the collection
	SheetID				int						--this is the Sheet_id

)
--VaribleData
--declare #VariableData table (
CREATE TABLE #VariableData (
	ID							int identity,			--this is the table identity
	VariableID			int,						--this is the ID field of #Variables
	LineStatusID		int,						--this is the ID field of @LineStatusByUnit
	ProdID					int,						--this is the prod_id
	ResultOn				datetime,				--the result_on of gbdb.dbo.tests
	Result					varchar(25),		--ths result of gbdb.dbo.tests
	URL						varchar(25),		--this is the URL of gbdb.dbo.var_specs
	[Target]				varchar(25),		--this is the target of gbdb.dbo.var_specs
	LRL						varchar(25),		--this is the LRL of gbdb.dbo.var_specs
	HasNoLimits			int default(0),		--1=no limits 0 = limits
	HasUpperLimit		int,						--1 = yes 0=No
	HasLowerLimit		int,						--1 = yes 0 =no
	HasBothLimits		int,						--1 =yes 0 = no
	InLimits				int default(0),		--1 = yes 0 = no
	Completed			int default(0)		--1 = yes 0 = no
)

--variable summary data
--declare #VariableSummary Table (
CREATE TABLE #VariableSummary (
	ID									int identity,			--the inentity of the table
	[Area]							varchar(50),		--this is the Area of the variable
	[Team]							varchar(10),		--this is the team
	[LineStatusID]				int,						--this is the ID of @LineStatusByUnit
	[Variable Type]			varchar(25),		--this is the type of collection manual or Auto
	[Percent Completed]	float,					--the percent completed
	[Percent Compliant]		float,					--the percent complaint
	[No Specification]		int						--the number of variables with no specificaitons
)
	DECLARE @AlarmData	TABLE(
		Machine						VARCHAR(100),
		Area								varchar(100),
		Display							varchar(100),
		[Alarm Template]			VARCHAR(100),
		Variable						VARCHAR(100),
		Team							VARCHAR(10),
		Shift 							VARCHAR(10),
		[Alarm Start]				DATETIME,
		[Alarm End]					DATETIME,
		[Alarm Result]				VARCHAR(25),
		Acknowledged				VARCHAR(50),
		[Acknowledged By]		VARCHAR(50),
		Comment						VARCHAR(400),
		[Action Taken]				varchar(100),
		[Is Alarm]						INT,
		[IS Acknowledged]		INT,
		[IS Commented]			INT,
		VarID							int,
		ProdID							int,
		LSL								varchar(25),
		[Target]						varchar(25),
		USL								varchar(25),
		PUID							int
		)
--@VariableArea this is used to complete the #Variablesumary table
declare @VariableArea table (
	ID				int identity,		--the table identity
	Area			varchar(50)		--this is the Area of the variable
	)
declare
	@PUID					int,						--this is the pu_id of the variable firing the calculation
	@TDT					float	,					--the total dowmtime for the line of the report window
	@TRecords			int,						--the number of records in the working table
	@WRecord			int,						--the working record
	@WStart				datetime,				--the StartTime of the Working Record
	@WEnd				datetime,				--the EndTIme of the Working Record
	@WHalfTime		float,					--this is half of the @LineSatusByUnit report Window for the working record
	@WDT					float	,					--this is the downtime of the @LineStatusByUnit working record
	@ProdID				int,						--this is the prod_id of the @LineStatusByUnit working record
	@LineStatusID		int,						--this is the LineStatus for the working record of @LineStatusByUnit
	@Result				float,					--this is the reuslt to update #VariableSummary
	@SchedulePUID	int,						--this is the schedule pu_id for the line
	@PLID					int,						--this is the pl_id of the line in question
	@TRecords1		int,						--the number of records in the working table
	@WRecord1		int,						--the working record
	@Area					varchar(50)			--the Area
--get @PLID
select @PLID = pl.pl_id from gbdb.dbo.prod_lines pl with(nolock) where coalesce(pl_desc_global,pl_desc_local) = @PLDesc

--get @PlDesc
	--select @PlDesc = coalesce(pl_desc_global,pl_desc_local) from gbdb.dbo.prod_lines with(nolock) where pl_id = @PLID
--get the paths
insert into @Paths (PathID,PLID) select pep.path_id,@PLID
	from gbdb.dbo.prdexec_paths pep with(nolock)
	where pep.pl_id = @PLID
--get the path units
insert into @PathUnits(PathID,PUID,IS_Production_Point,PLID) select path_id,pu_id,is_production_point,p.PLID from gbdb.dbo.prdexec_path_units ppu with(nolock) join @Paths p on p.pathid = ppu.path_id
--set all the production_starts records
insert into @ProdsByUnit(StartTime,EndTime,ProdID,PUID)
select 
	case 
		when ps.start_time< @Start then @Start
		else ps.start_time
	end,
	case
		when ps.end_time is null then @End
		when ps.end_time > @End then @End
		else ps.end_time
	end,
	ps.prod_id,ps.pu_id
	from gbdb.dbo.production_starts ps with(nolock)
		join @PathUnits pp on pp.puid = ps.pu_id 
	where ps.start_time<= @End and (ps.end_time >= @Start or ps.end_time is null)  
	order by ps.pu_id
--get the ProdID for @Dimensions
insert into @Dimensions(Dimension,PUID,StartTime,EndTime,Value)
	select 'ProdID',pu.puid,pu.starttime,pu.endtime,convert(varchar(100),pu.ProdID)
		from @ProdsByUnit pu
			join @PathUnits pp on pp.puid = pu.puid  and pp.Is_Production_Point =1

--get the LineStatus data for @Dimensions
insert into @Dimensions(Dimension,PUID,StartTime,EndTime,Value)
	select 'LineStatus',ls.Unit_Id,
		case 
			when ls.start_DateTime < @Start then @Start
			else ls.start_datetime
		end,
		case
			when ls.End_DateTime is null then @End
			else ls.end_datetime
		end,
		p.phrase_value
	from  gbdb.dbo.local_pg_line_status ls with(nolock)
		join gbdb.dbo.phrase p with(Nolock) on p.phrase_id = ls.line_status_id
		join @PathUnits pu on pu.puid =ls.unit_id
	where ls.Start_DateTime<= @End and (ls.End_datetime >= @Start or ls.end_datetime is null) and pu.Is_Production_Point =1
		and ls.update_status <> 'DELETE'  
--get all the shift data for @Dimensions
insert into @Dimensions(Dimension,PUID,StartTime,EndTime,Value)
	select 'Shift',cs.pu_id,cs.start_time,cs.end_time,cs.crew_desc
		from gbdb.dbo.crew_schedule cs with(nolock)
			join @PathUnits pu on pu.puid = cs.pu_id
		where cs.end_time <= @End and (cs.end_time >=@Start or cs.end_time is null)
--set the data for @LineStatusByUnit
insert into @LineStatusByUnit(PLID,PUID,StartTime)
select 	pu.PLID,d.PUID,d.StartTime
		from @PathUnits pu
			join @Dimensions d on d.puid = pu.puid
	group by pu.PLID,d.PUID,d.StartTime
	order by pu.PLID,d.PUID,d.StartTime		
--update the EndTime of @LineStatusByUnit
update d1 set
	EndTime =	
		(
		select top 1 StartTime
		from @LineStatusByUnit d2
		where d1.PUID = d2.PUID
		and d1.StartTime < d2.StartTime
		)
from @LineStatusByUnit d1
--Update the LineStatus of @LineStatusByUnit
update @LineStatusByUnit 
	set EndTime = @End
	where endtime is null
--Update the ProdID of @LineStatusByUnit
update ls 
set
	ProdID = 
		(
		select value
		from @Dimensions d 
		where d.PUID = ls.PUID
		and d.StartTime < ls.EndTime
		and (d.endtime > ls.StartTime)
		and d.Dimension = 'ProdID'
		)
from @LineStatusByUnit ls
--Update the Team of @LineStatusByUnit
update ls 
set
	Team = 
		(
		select value
		from @Dimensions d 
		where d.PUID = ls.PUID
		and d.StartTime < ls.EndTime
		and (d.endtime > ls.StartTime)
		and d.Dimension = 'Shift'
		)
from @LineStatusByUnit ls
--update the LineStatus of @LineStatusByUnit
update ls
set
	LineStatus = 
		(
		select value
		from @Dimensions d 
		where d.PUID = ls.PUID
		and d.StartTime < ls.EndTime
		and (d.endtime > ls.StartTime)
		and d.Dimension = 'LineStatus'
		)
from @LineStatusByUnit ls

--remove all records from 	@LineStatusByUnit where there is no line status
delete from @LineStatusByUnit where LineStatus is null
--get all the downtime for the window
insert into @LineDowntime(PUID,StartTime,EndTime)
select ted.pu_id,
		case
			when ted.start_time <= d.StartTime then d.StartTime
			else ted.start_time
		end,
		case
			when ted.end_time is null then d.EndTime
			else ted.end_time
		end
	from gbdb.dbo.timed_event_details ted with(nolock)
		join gbdb.dbo.event_configuration ec with(nolock) on ec.pu_id = ted.pu_id
		join gbdb.dbo.prod_units_base pu with(nolock) on pu.pu_id = ec.pu_id 
		join gbdb.dbo.event_types et with(nolock) on et.et_id = ec.et_id and et.et_desc = 'Downtime'
		join @LineStatusByUnit d on d.PLID = pu.pl_id 
	where (ted.start_time > d.StartTime and (ted.end_time <= d.EndTime or ted.end_time is null))
--set the durations of @LineDowntime
update @LineDowntime
	set Duration = (convert(float,EndTime) - convert(float,StartTime)) *1440
--set the downtime of@LineStatusByUnit
if (select count(*) from  @LineStatusByUnit) >0
	begin
		select @TRecords =max(id) from @LineStatusByUnit
		select @WRecord = 0
		while @WRecord < @TRecords
			begin
				select @WRecord = @WRecord + 1
				select 
					@WStart = StartTime,
					@WEnd	= EndTime
				from @LineStatusByUnit
				where ID = @WRecord
				select @TDT = sum(Duration) from @LineDowntime where StartTime >= @WStart and EndTime <= @WEnd
				update @LineStatusByUnit
						set Downtime = @TDT
					where ID = @WRecord
			end
	end
--get the sheets and variables
insert into @Sheets (SheetID,Interval)
select s.sheet_id,s.interval
	from gbdb.dbo.sheets s with(nolock)
		join gbdb.dbo.sheet_groups sg with(Nolock) on sg.sheet_group_id = s.sheet_group_id
		join gbdb.dbo.sheet_type st with(nolock) on st.sheet_type_id = s.sheet_type and sheet_type_desc not like '%Alarm%'
	where sg.sheet_group_desc_global like '%' + @PlDesc +'%' and sheet_desc_local like '%Process Monitoring%' and s.is_active = 1
--get the variables for @Sheets
insert into #Variables (VarID,DataSource,Interval,SheetID,Variable,Area)
select v.var_id,ds.ds_desc,v.sampling_interval,s.SheetID,v.var_desc_local,pug.pug_desc_local
	from gbdb.dbo.sheet_variables sv with(nolock)
		join gbdb.dbo.variables v with(nolock) on v.var_id = sv.var_id
		join gbdb.dbo.pu_groups pug with(nolock) on pug.pug_id = v.pug_id
		join gbdb.dbo.data_source ds with(nolock) on ds.ds_id = v.ds_id
		join @Sheets s on s.Sheetid = sv.sheet_id
update #Variables set Area = replace(Area,' Auto Data','')	
update #Variables set Area = replace(Area,' Manual Data','')	
--get all the variable data if the uptime is >=50% of the shift window
if (select count(*) from  @LineStatusByUnit) >0
	begin
		select @TRecords =max(id) from @LineStatusByUnit
		select @WRecord = 0
		while @WRecord < @TRecords
			begin
				select @WRecord = @WRecord + 1
				select @WHalfTime = ((convert(float,EndTime)-convert(float,StartTime))*1440)*convert(real,@ReportType)/100 , @WDT=  Downtime from @LineStatusByUnit where ID = @WRecord
				if @WHalfTime> @WDT
					begin
						select 
							@WStart = StartTime,
							@WEnd	= EndTime,
							@ProdID	=ProdID
						from @LineStatusByUnit
						where ID = @WRecord
						insert into #VariableData(VariableID,	LineStatusID,ResultOn,Result,ProdID)
							select v.ID,@WRecord,t.result_on,t.result,@ProdID
								from gbdb.dbo.tests t with(nolock)
									join #Variables v on v.VARID = t.var_id and v.Datasource = 'Autolog'
								where t.result_on > @WStart and  t.result_on <=@WEnd
						insert into #VariableData(VariableID,	LineStatusID,ResultOn,Result,ProdID)
							select v.ID,@WRecord,t.result_on,t.result,@ProdID
								from gbdb.dbo.tests t with(nolock)
									join #Variables v on v.VARID = t.var_id and v.Datasource = 'Historian'
								where (t.result_on > @WStart and  t.result_on <=@WEnd) and t.result is not null
					end
			end
	end
--update the specification of #VariableData
update vd
		set 
			URL			= vs.U_Reject,
			LRL			= vs.L_Reject,
			[Target]	= vs.target
	from gbdb.dbo.var_specs vs with(nolock)
		join #VariableData vd on  VD.ProdID = vs.prod_id
		join #Variables v on v.ID = VD.VariableID and v.VarID = vs.var_id
	where vs.effective_date <= VD.ResultOn and (vs.expiration_Date >= vd.ResultOn or vs.expiration_date is null)

--update #VariableData for limit data
update #VariableData
		set 
		HasUpperLimit = 
			case
				when URL is not null then 1
				else 0
			end,
		HasLowerLimit =
			case
				when LRL is not null then 1
				else 0
			end,
		HasBothLimits =
			case
				when URL is not null and LRL is not null then 1
				else 0
			end
--update #VariableData for inLimits and Completed
--for only lower Limits
	update #VariableData
		set InLimits = 1
			where (HasLowerLimit =1 and HasBothLimits = 0) and isnumeric(Result) =1 and convert(float,result) >= convert(float,LRL) 
--for only upper limit
	update #VariableData
		set InLimits = 1
			where (HasUpperLimit =1 and HasBothLimits = 0) and isnumeric(Result) =1 and convert(float,result) <= convert(float,URL)
--for both limits
	update #VariableData
		set InLimits = 1
			where (HasBothLimits = 1) and isnumeric(Result) =1 and ( convert(float,result) >= convert(float,LRL)  and convert(float,result) <= convert(float,URL))
--HasNoLimits
	update #VariableData
		set HasNoLimits = 1
			where (HasUpperLimit =0 and HasLowerLimit =0 and [Target] is null)
--if DataSource of #Variables = 'Autolog' result of #VariableData is not mull then set Completed = 1	
	update	vd
			set Completed	=1
		from #VariableData vd
			join #Variables v on v.ID = vd.VariableID
		where v.Datasource = 'AutoLog' and vd.result is not null		
--file @VariableArea
insert into @VariableArea (Area)
	select Area from #Variables group by Area
insert into @VariableArea (Area) values('Total')
--go through all the @VariableArea data to fill out #VariableSummary
if (select count(*) from @VariableArea) >0
	begin
		select @TRecords1 =max(id) from @VariableArea
		select @WRecord1 = 0
		while @WRecord1 < @TRecords1
			begin
				select @WRecord1 = @WRecord1 + 1
				select @Area = Area from @VariableArea where ID = @WRecord1
	
				--fill #VariableSummary
				insert into #VariableSummary(Team,Area,[Variable Type],[LineStatusID])
					select Team,@Area,'Manual',ID
						from @LineStatusByUnit
						
				if (select count(*) from  #VariableSummary) >0
					begin
						select @TRecords =max(id) from #VariableSummary
						select @WRecord = 0
						while @WRecord < @TRecords
							begin
								select @WRecord = @WRecord + 1
								select 
									@LineStatusID = LineStatusID
								from #VariableSummary
								where ID = @WRecord
								--update Percent Completed
								if @Area <> 'Total'
									begin
										select 
											@Result = round(((convert(real,sum(completed))/convert(real,Count(completed)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and vd.LineStatusID = @LineStatusID and v.Area = @Area
										update #VariableSummary set [Percent Completed] =@Result where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area
									end
								if @Area = 'Total'
									begin
										select 
											@Result = round(((convert(real,sum(completed))/convert(real,Count(completed)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and vd.LineStatusID = @LineStatusID
										update #VariableSummary set [Percent Completed] =@Result where ID = @WRecord and [Variable Type] = 'Manual'  and Area = @Area
									end

								--update Percent Compliant
								if @Area <> 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and vd.LineStatusID = @LineStatusID and vd.HasNoLimits = 0 and v.Area = @Area
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and vd.LineStatusID = @LineStatusID and v.area = @Area
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area
									end
								if @Area = 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and vd.LineStatusID = @LineStatusID and vd.HasNoLimits = 0 
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and vd.LineStatusID = @LineStatusID 
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area
									end
							end
					end
					insert into #VariableSummary(Team,Area,[Variable Type],[LineStatusID])
						select Team,@Area,'Auto',ID
							from @LineStatusByUnit
							
				if (select count(*) from  #VariableSummary) >0
					begin
						select @TRecords =max(id) from #VariableSummary
						select @WRecord = 0
						while @WRecord < @TRecords
							begin
								select @WRecord = @WRecord + 1
								select 
									@LineStatusID = LineStatusID
								from #VariableSummary
								where ID = @WRecord
								--update Percent Compliant
								if @Area <> 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian' and vd.LineStatusID = @LineStatusID and vd.HasNoLimits = 0 and v.Area = @Area
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian' and vd.LineStatusID = @LineStatusID and v.Area = @Area
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area
									end
								if @Area = 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian' and vd.LineStatusID = @LineStatusID and vd.HasNoLimits = 0
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian' and vd.LineStatusID = @LineStatusID
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area
									end

							end
					end
		end
--overall completion and compliance		
		select @TRecords1 =max(id) from @VariableArea
		select @WRecord1 = 0
		while @WRecord1 < @TRecords1
			begin
				select @WRecord1 = @WRecord1 + 1
				select @Area = Area from @VariableArea where ID = @WRecord1
	
				--fill #VariableSummary
				insert into #VariableSummary(Area,[Variable Type])
					select @Area,'Manual'
						
				if (select count(*) from  #VariableSummary) >0
					begin
						select @TRecords =max(id) from #VariableSummary
						select @WRecord = 0
						while @WRecord < @TRecords
							begin
								select @WRecord = @WRecord + 1
								--update Percent Completed
								if @Area <> 'Total'
									begin
										select 
											@Result = round(((convert(real,sum(completed))/convert(real,Count(completed)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and v.Area = @Area and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [Percent Completed] =@Result where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area and Team is null
									end
								if @Area = 'Total'
									begin
										select 
											@Result = round(((convert(real,sum(completed))/convert(real,Count(completed)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [Percent Completed] =@Result where ID = @WRecord and [Variable Type] = 'Manual'  and Area = @Area and Team is null
									end

								--update Percent Compliant
								if @Area <> 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog'  and vd.HasNoLimits = 0 and v.Area = @Area and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area and Team is null
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog'  and v.area = @Area and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area  and Team is null
									end
								if @Area = 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog'  and vd.HasNoLimits = 0  and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area  and Team is null
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'AutoLog' and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Manual' and Area = @Area and Team is null
									end
							end
					end
					insert into #VariableSummary(Area,[Variable Type])
						select @Area,'Auto'
							
				if (select count(*) from  #VariableSummary) >0
					begin
						select @TRecords =max(id) from #VariableSummary
						select @WRecord = 0
						while @WRecord < @TRecords
							begin
								select @WRecord = @WRecord + 1
								select 
									@LineStatusID = LineStatusID
								from #VariableSummary
								where ID = @WRecord
								--update Percent Compliant
								if @Area <> 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian'  and vd.HasNoLimits = 0 and v.Area = @Area and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area  and Team is null
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian'  and v.Area = @Area and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area  and Team is null
									end
								if @Area = 'Total'
									begin
										select 
											@Result = round(((convert(real,(count(HasNoLimits)-(count(InLimits)-sum(InLimits))))/convert(real,count(HasNoLimits)))*100),2)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian'  and vd.HasNoLimits = 0  and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [Percent Compliant] =@Result where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area  and Team is null
										--update No Specification
										select 
											@Result = sum(HasNoLimits)
										from #VariableData vd
											Join #Variables v on v.id = vd.VariableID
										where v.dataSource = 'Historian'  and (vd.ResultOn > @Start and vd.ResultOn <= @End)
										update #VariableSummary set [No Specification] =convert(int,@Result) where ID = @WRecord and [Variable Type] = 'Auto' and Area = @Area and Team is null
									end

							end
					end
		end	
--end of over all completion and compliance								
	end
										
--get the alarm data
INSERT INTO @AlarmData(Machine,Area,[Alarm Template],Variable,[Alarm Start],[Alarm End],[Alarm Result],Acknowledged,[Acknowledged By],Comment,[IS Alarm],[IS Acknowledged],[IS Commented],[Action Taken],Display,VarID,PUID)
	SELECT   @PLdesc,pug.pug_desc,AT_Desc, Var_Desc,start_time,
		CASE
			WHEN end_time IS NULL THEN @End
			ELSE End_time
		END,
		start_result,
		CASE	

			WHEN ack = 0 THEN 'Not Acknowledged'
			ELSE 'Acknowledged'
		END,
		CASE
			WHEN  u1.username IS NULL THEN 'Not Acknowledged'
			ELSE u1.username
		END,
		CASE
			WHEN comment_text is null THEN 'No Comment Entered'
			ELSE comment_text
		END,
		1,
		CASE
			WHEN ack = 0 THEN 0
			ELSE 1
		END,
		CASE
			WHEN (comment_text is null and a.action2 is null) THEN 0
			ELSE 1
		END,
		er.event_reason_name,
		s.sheet_desc_local,v.var_id,coalesce(pu.master_unit,pu.pu_id)
	 FROM gbdb.dbo.alarm_templates  Atemp with(nolock)
		LEFT JOIN gbdb.dbo.alarm_types  AType with(nolock) ON (AType.Alarm_Type_ID = ATemp.Alarm_Type_ID)
		LEFT JOIN gbdb.dbo.alarm_Template_Var_data  ATempVarD with(nolock) ON (ATempVarD.AT_ID = ATemp.AT_ID)
		LEFT JOIN gbdb.dbo.alarms a with(nolock) ON (a.atd_id = ATempVarD.atd_ID)
		LEFT JOIN gbdb.dbo.event_reasons er with(nolock) ON er.event_reason_id = a.action2
		LEFT JOIN gbdb.dbo.Variables_base  v with(nolock) ON (v.var_id = ATempVarD.var_id)
		left join gbdb.dbo.sheet_variables sv with(nolock) on sv.var_id = v.var_id
		left join gbdb.dbo.sheets s with(nolock) on s.sheet_id = sv.sheet_id
		LEFT JOIN gbdb.dbo.prod_units_base  pu with(nolock) ON (pu.pu_id = v.pu_id)
		left join gbdb.dbo.pu_groups pug with(nolock) on pug.pug_id = v.pug_id
		LEFT JOIN gbdb.dbo.prod_lines_base  pl with(nolock) ON (pl.pl_id = pu.pl_id)
		LEFT JOIN gbdb.dbo.users_base  u1 with(nolock) ON (u1.user_id = a.ack_by)
		LEFT JOIN gbdb.dbo.comments c with(nolock) ON (a.Cause_comment_id = c.comment_id)
	WHERE  ((Atemp.AT_desc =  right(@PLDesc,4) + ' Centerline Alarms' or
				Atemp.AT_desc =  @PLDesc + ' Process Monitoring Alarms')  and s.sheet_type in (1,2,16,25))
	and ((Start_Time >= @Start OR End_Time IS NULL) and start_Time <= @End)
	
/*update the team and Shift */
select  TOP 1 @SchedulePUID =tfv.value
	from gbdb.dbo.table_fields_values tfv with(nolock)
		join gbdb.dbo.table_fields tf with(nolock) on tf.table_field_id = tfv.table_field_id
		join gbdb.dbo.tables t with(nolock) on t.tableID = tfv.tableID and t.tableName = 'Prod_Units'
		join gbdb.dbo.prod_units_base pu with(nolock) on tfv.keyid = pu.pu_id and pu.pl_id=  @PLID
	where tf.table_field_desc like 'STLS_ST_MASTER_UNIT_ID'

	UPDATE AD
		SET team = crew_desc,
			shift = Shift_desc
		FROM gbdb.dbo.crew_schedule  cs with(nolock)
			LEFT JOIN @AlarmData AS AD ON (ad.[Alarm Start] >=cs.start_time and ad.[Alarm Start]<=cs.end_time and cs.pu_id =@schedulePUID)
--get the prodid for the alarms
update ad
		set ProdID = ps.prod_id
	from gbdb.dbo.production_starts ps with(nolock)
		join @AlarmData ad on ad.PUID=ps.pu_id
	where ad.[Alarm Start] >=ps.start_time  and (ad.[Alarm End] <= ps.end_time or ps.end_time is null) 
--update teh specs for the @ALarmData
update ad
		set LSL = L_reject,[Target] = vs.target,USL=vs.U_reject
	from gbdb.dbo.var_specs vs with(nolock)
		join @AlarmData ad on ad.VarID = vs.var_id and ad.ProdID = vs.prod_id
	where ad.[Alarm Start] >= vs.effective_date and (ad.[Alarm End] <= vs.expiration_date or vs.expiration_date is null)
		
--select * from @Dimensions
--select * from @LineStatusByUnit
--select * from @LineDowntime
--select * from @Sheets
--select * from #Variables
--select * from #VariableData --where  completed = 1
--select * from #VariableData vd join #Variables v on v.id = vd.VariableID where LineStatusID = 3 and DataSource = 'AutoLog'
select Machine,Area,Display,[Alarm Template],Variable,Team,Shift,[Alarm Start],	[Alarm End],[Alarm Result],LSL,[Target],USL,[Acknowledged By],Comment,[Action Taken],Acknowledged,	[Is Alarm],[IS Acknowledged],[IS Commented] from @AlarmData
select 	[Area],[Team],[Variable Type],[Percent Completed],[Percent Compliant],[No Specification] from #VariableSummary
DROP TABLE #VariableData
DROP TABLE #VariableSummary
DROP TABLE #Variables
GO
grant execute on spLocal_ReportSPCAlarmsNew to [OpDBManager]
GO
grant execute on spLocal_ReportSPCAlarmsNew to [comxclient]
GO
