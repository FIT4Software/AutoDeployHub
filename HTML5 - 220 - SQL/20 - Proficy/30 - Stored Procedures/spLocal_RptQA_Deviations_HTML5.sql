SET QUOTED_IDENTIFIER ON 
GO
SET ANSI_NULLS ON 
GO

-----------------------------------------------------------------------------------------------------------------------
-- Delete Procedure
-----------------------------------------------------------------------------------------------------------------------
IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = OBJECT_ID(N'[dbo].[spLocal_RptQA_Deviations_HTML5]') 
	AND OBJECTPROPERTY(id, N'IsProcedure') = 1)
BEGIN
	DROP PROCEDURE [dbo].[spLocal_RptQA_Deviations_HTML5]
END
GO

----------------------------------------------------------------------------------------------------------------------
-- Prototype Definition
----------------------------------------------------------------------------------------------------------------------
DECLARE @SP_Name	NVARCHAR(200),
		@Inputs		INT,
		@Version	NVARCHAR(20),
		@AppId		INT

SELECT
		@SP_Name	= 'spLocal_RptQA_Deviations_HTML5',
		@Inputs		= 5, 
		@Version	= '1.6'

--=====================================================================================================================
--	Update Table AppVersions
--=====================================================================================================================
SELECT @AppId = MAX(App_Id) + 1 
		FROM dbo.AppVersions WITH(NOLOCK)

IF (SELECT COUNT(*) 
		FROM dbo.AppVersions WITH(NOLOCK)
		WHERE app_name like @SP_Name) > 0
BEGIN
	UPDATE dbo.AppVersions 
		SET app_version = @Version,
			Modified_On = GETDATE() 
		WHERE app_name like @SP_Name
END
ELSE
BEGIN
	INSERT INTO dbo.AppVersions (
		App_Id,
		App_name,
		App_version,
		Modified_On)
	VALUES (
		@AppId, 
		@SP_Name,
		@Version,
		GETDATE())
END

GO

---------------------------------------------------------------------------------------------------------------------------------------------------
-- 													Modification History															             --	
---------------------------------------------------------------------------------------------------------------------------------------------------
--	1.3		2010-04-05		Pablo Galanzini		Add version in report footer from table AppVersions
--  1.4		2016-05-16		Namrata Kumar		FO-02057 To get correct names of attributes and variables in the report
--	1.5		2019-07-10		Damian Campana		Adapt stored procedure to use with the report of <HTML5 Quality Deviation>
--  1.6		2019-08-28		Damian Campana		Capability to filter with the time option 'Last Week'
---------------------------------------------------------------------------------------------------------------------------------------------------
-- 14-Jun-2007 Change the way to get the Crew_Schedule to reduce the amount of Reads
-- 31-Jan-2007 Avoid NULL Results from the Tests table, they are causing formatting issues.
-- 27-Jun-2006 Increase the Scrap column to 15 chars
-- 28-Oct-2005 Created by FRio
-- SP that calculates variables deviations, also shows a team summary at the top

CREATE PROCEDURE [dbo].[spLocal_RptQA_Deviations_HTML5]
-- Declare
        @intTimeOption              as int,
        @strRptStartDate            as datetime,
        @strRptEndDate              as datetime,
        @intPL_id                   as int,
        @strRptShowTeam             as bit
--WITH ENCRYPTION 
AS

-- select * from report_definitions where report_name like '%deviation%'
-- Exec [dbo].[spLocal_RptQA_Deviations_HTML5] 1, null, null, 59, 0
-- select pu_desc, * from prod_units
---------------------------------------------------------------------------------------------------------------
-- Temporary Tables used by the SP
---------------------------------------------------------------------------------------------------------------
Create Table #Deviations(
								id_dev                    int identity,
								Grouping_Option           nvarchar(200),
								Pu_Id                     int,
								Result_On                 datetime,
								Start_Time                datetime,
								VarDesc                   nvarchar(200),
								DevRule                   nvarchar(200),
								Team                      nvarchar(50),
								Scrap                     nvarchar(150),
								Location                  nvarchar(50),
								DeviationStatus           nvarchar(100),
								IssueDescription          nvarchar(100),
								AdjustementDescription    nvarchar(250),
								Comments                  nvarchar(2500),
								Orderby                   int
								)

Create Table #Summary	(
								Grouping_Option           nvarchar(100),
								DeviationStatus           nvarchar(100),
								Team1                     nvarchar(30),
								Team2                     nvarchar(30),
								Team3                     nvarchar(30),
								Team4                     nvarchar(30),
								Team5                     nvarchar(30),
								Team6                     nvarchar(30),
								Team7                     nvarchar(30),
								Team8                     nvarchar(30),
								Total                     nvarchar(30)
)

Declare @Temp_language_data Table	(
								Prompt_Number varchar(20), 
								Prompt_String varchar(200),
								language_id int)

Declare @Crew_Schedule Table (
								PU_Id						INT,
								StartDate					DATETIME,
								EndDate						DATETIME,
								Crew_Desc					NVARCHAR(20))

---------------------------------------------------------------------------------------------------------------
-- Test Data
-- exec spLocal_RptQA_Deviations_HTML5 1, null, null, 59, 0

---------------------------------------------------------------------------------------------------------------
-- select * from prod_units where pu_desc like '%DIMR112 Quality%'

-- Get Report Parameters
---------------------------------------------------------------------------------------------------------------
DECLARE @QUnit VARCHAR(255)
DECLARE @PU_id INT

SELECT  @QUnit = ISNULL(OpsDataStore.[dbo].[fnRptGetParameterValue] ('Q Deviation Report','@QualityUnit'),'Quality')
SELECT  @PU_id = PU_Id FROM Prod_Units_Base WITH(NOLOCK) WHERE PU_Desc = (SELECT PL_Desc + ' ' + @QUnit FROM Prod_Lines_Base WHERE PL_Id = @intPL_id)

DECLARE

        @STLSUnit                	INT,
        @j                       	INT,
        @intActiveLanguageID     	INT,
        @noDeviation		     	VARCHAR(30), 
        @Open		             	VARCHAR(30), 
        @Closed	                 	VARCHAR(30),
		-- Add for search Version
		@vchAppVersion				VARCHAR(10)	,
		@vchRTVersion				VARCHAR(10)	,
		@vchSP_name					VARCHAR(50)	,
		@vchRT_xlt					VARCHAR(50)	

---------------------------------------------------------------------------------------------------------------
-- Time Options
---------------------------------------------------------------------------------------------------------------
DECLARE @vchTimeOption   VARCHAR(50)
SELECT  @vchTimeOption = CASE @intTimeOption
                            WHEN	1	THEN	'Last3Days'	
                            WHEN	2	THEN	'Yesterday'
                            WHEN	3	THEN	'Last7Days'
                            WHEN	4	THEN	'Last30Days'
                            WHEN	5	THEN	'MonthToDate'
                            WHEN	6	THEN	'LastMonth'
                            WHEN	7	THEN	'Last3Months'
                            WHEN	8	THEN	'LastShift'
                            WHEN	9	THEN	'CurrentShift'
                            WHEN	10	THEN	'Shift'
                            WHEN	11	THEN	'Today'
							WHEN	12	THEN	'LastWeek'
                         END


	IF @vchTimeOption IS NOT NULL
	BEGIN
		SELECT	@strRptStartDate = dtmStartTime,
				@strRptEndDate = dtmEndTime
		FROM [dbo].[fnLocal_DDSStartEndTime](@vchTimeOption)

	END


-----------------------------------------------------------------------------------------------------------
-- Search Version in AppVersions and Report_types
-----------------------------------------------------------------------------------------------------------
SET @vchSP_name	= 'spLocal_RptQA_Deviations_HTML5'
SET @vchRT_xlt	= 'QA_Deviation.xlt'
-----------------------------------------------------------------------------------------------------------
-- Search Version in AppVersions
-----------------------------------------------------------------------------------------------------------
SELECT @vchAppVersion = App_Version FROM AppVersions WHERE app_name like '%' + @vchSP_name + '%'
-----------------------------------------------------------------------------------------------------------
-- Search Version in Report_Types
-----------------------------------------------------------------------------------------------------------
SELECT @vchRTVersion = version FROM Report_Types WHERE template_path like '%' + @vchRT_xlt + '%'


---------------------------------------------------------------------------------------------------------------
-- Get Prompt Labels
Declare
        @lblDevOpen         as nvarchar(200),
        @lblDevClose        as nvarchar(200),
        @lblNoDev         	as nvarchar(200),
        @lblTeamSummary     as nvarchar(200),
        @lblAttr         	as nvarchar(200),
        @lblVar         	as nvarchar(200),
        @lblDevStatus 		as nvarchar(200)
          
Set     @lblDevOpen         = 'Deviation Open'
Set     @lblDevClose        = 'Deviation Closed'
Set     @lblNoDev           = 'No Deviation'
Set     @lblTeamSummary     = 'Team Summary'   
Set     @lblAttr            = 'Attribute Data'
Set     @lblVar             = 'Variable Data'
Set     @lblDevStatus       = 'Deviation Status'

        
Insert Into @Temp_language_data(Prompt_Number, Prompt_String,language_id )
Select Prompt_Number, Prompt_String,language_id
From dbo.Language_Data WITH(NOLOCK)
Where Prompt_Number between '99816001' and '99817000'
and Prompt_String > ''

Declare 
       @Owner       as nvarchar(50),
       @LocalRPTLanguage as int

Select @LocalRPTLanguage = up.value 
From dbo.Users_Base u WITH(NOLOCK)
Join dbo.User_Parameters up WITH(NOLOCK) on up.user_id = u.user_id
Join dbo.Parameters p WITH(NOLOCK) on p.parm_id = up.parm_id
Where u.UserName = @Owner and p.Parm_Id = 8


Select @lblDevOpen  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblDevOpen ) and language_id = @LocalRPTLanguage
Select @lblDevClose  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblDevClose ) and language_id = @LocalRPTLanguage
Select @lblNoDev  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblNoDev ) and language_id = @LocalRPTLanguage
Select @lblTeamSummary  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblTeamSummary ) and language_id = @LocalRPTLanguage
Select @lblAttr  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblAttr ) and language_id = @LocalRPTLanguage
Select @lblVar  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblVar ) and language_id = @LocalRPTLanguage
Select @lblDevStatus  =  prompt_string from @Temp_language_data where prompt_number = (select max(prompt_number) from @Temp_language_data where prompt_string = @lblDevStatus ) and language_id = @LocalRPTLanguage

-- Select @lblDevOpen,@lblDevClose,@lblNoDev,@lblTeamSummary,@lblAttr,@lblVar
----------------------------------------------------------------------------------------------------------------
-- Find Texts for No Deviation, Deviation Open, Deviation Closed
----------------------------------------------------------------------------------------------------------------

select @intActiveLanguageID = language_id from Local_PG_Languages WITH(NOLOCK) where is_active = 1
-- select language_id from Local_PG_Languages where is_active = 1
-- select translated_text from Local_PG_Translations where language_id = @intActiveLanguageID and global_text = 'No Deviation'

select  @noDeviation = translated_text from Local_PG_Translations WITH(NOLOCK) where language_id = @intActiveLanguageID and global_text = 'No Deviation'
select  @Open = translated_text from Local_PG_Translations WITH(NOLOCK) where language_id = @intActiveLanguageID and global_text = 'Open'
select  @Closed = translated_text from Local_PG_Translations WITH(NOLOCK) where language_id = @intActiveLanguageID and global_text Like '%Closed%'


Select @STLSUnit = (Case 
        WHEN (CharIndex('STLS=',Extended_Info, 1)) > 0 THEN Substring(Extended_Info,(CharIndex('STLS=',Extended_Info,1) + 5), 
       Case    
        WHEN (CharIndex(';',Extended_Info,CharIndex('STLS=', Extended_Info, 1))) > 0 
            THEN (CharIndex(';', Extended_Info,CharIndex('STLS=', Extended_Info, 1)) - (CharIndex('STLS=', Extended_Info, 1) + 5)) 
            ELSE    Len(Extended_Info)    
        END)
        End)
        From Prod_Units_Base WITH(NOLOCK) where pu_id = @pu_id
   
--   
Select distinct v.pu_id,v.Var_ID, v.Var_Desc, V.Extended_Info 
Into #Temp_Attributes
From dbo.Variables_Base v WITH(NOLOCK)
Join dbo.PU_Groups pug WITH(NOLOCK)  on v.PUG_ID=pug.PUG_ID 
join dbo.Prod_Units_Base pu WITH(NOLOCK) on v.PU_ID = pu.PU_ID 
And (pug.PUG_DESC = 'QA Reestablish' Or pug.PUG_DESC = 'QA Reevaluation')
And v.var_Desc not like 'zpv_%'
And v.Extended_Info Is Not NULL 
Where pu.pu_id = @pu_id

Select distinct v.pu_id,v.Var_ID, v.Var_Desc, v.Extended_Info 
Into #Temp_Variables
From dbo.Variables_Base v WITH(NOLOCK)
Join dbo.PU_Groups pug WITH(NOLOCK)  on v.PUG_ID=pug.PUG_ID 
join dbo.Prod_Units_Base pu WITH(NOLOCK) on v.PU_ID = pu.PU_ID 
And (pug.PUG_DESC = 'QV Reestablish' Or pug.PUG_DESC = 'QV Reevaluation')
And v.var_Desc not like 'zpv_%'
And v.Extended_Info Is Not NULL 
Where pu.pu_id = @pu_id

-------------------------------------------------------------------------------------------------------------------
-- Processing Attribute Data
-------------------------------------------------------------------------------------------------------------------
Insert Into #Deviations (Grouping_Option,OrderBy)
Values ('Label_'+@lblAttr,1)

If Exists (Select *
    From dbo.Tests t WITH(NOLOCK) 
    Join #Temp_Attributes v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('ATTRFAIL', 'OOSRV')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate
	And Result IS NOT NULL)

Begin
    Insert Into #Deviations (Grouping_Option,Pu_id,Result_On,DevRule,Comments,OrderBy)
    Select 'Attribute',v.pu_id,t.Result_On,t.Result, convert(varchar,cs.Comment_Text),1
    From dbo.Tests t WITH(NOLOCK) 
    Join #Temp_Attributes v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('ATTRFAIL', 'OOSRV')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate 
	And t.Result IS NOT NULL
    Order By Result_On
End
Else
Begin
    Insert Into #Deviations (Grouping_Option,VarDesc,OrderBy)
    Values ('Attribute','No Variables',1)
End

Update #Deviations
    Set VarDesc = t.Result, 
		Comments = Comments + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK) 
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('ATTRNAME','OOSNAME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

Update #Deviations
    Set VarDesc = IsNull(VarDesc,'') + IsNull(t.Result,''), 
		Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('ATTRNAME2','OOSNAME2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

Update #Deviations
    Set Start_Time = t.Result, 
		Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK) 
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('ATTRTIME','OOSTIME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

Update #Deviations
    Set Scrap = t.Result, 
		Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK) 
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=ATTRSCRAP','RPT=VARSCRAP')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

Update #Deviations
    Set DeviationStatus = t.Result, 
		Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=OOSSTAT', 'RPT=OOSSTAT')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

Update #Deviations
    Set IssueDescription = t.Result, 
		Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK) 
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment1')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

Update #Deviations
    Set AdjustementDescription = t.Result, 
		Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'Attribute'
And t.Result IS NOT NULL

-------------------------------------------------------------------------------------------------------------------
-- Processing QA Reevaluation Data
-------------------------------------------------------------------------------------------------------------------
Insert Into #Deviations (Grouping_Option,OrderBy)
Select 'Label_'+Sheet_desc,2 From dbo.Sheets s WITH(NOLOCK)
Join dbo.Sheet_Variables sv WITH(NOLOCK) on sv.sheet_id = s.sheet_id 
Where sv.Var_ID In (Select Var_Id 
From #Temp_Attributes  Where Extended_Info In ('QA-REEVAL-TIME'))
Group By Sheet_Desc

If Exists (Select * From dbo.Tests t WITH(NOLOCK)
                Join #Temp_Attributes v on v.var_id = t.var_id
                Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
                Where v.Extended_Info In ('QA-REEVAL-TIME')
                And Result_On > @strRptStartDate 
                And Result_On < @strRptEndDate
				And Result IS NOT NULL)
Begin
    Insert Into #Deviations (Grouping_Option,Pu_id,Result_On,DevRule,Start_Time,Comments,Orderby)
    Select 'QA Reevaluation',v.pu_id,t.Result_On,'',t.Result, convert(varchar,cs.Comment_Text),2
    From dbo.Tests t WITH(NOLOCK)
    Join #Temp_Attributes v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('QA-REEVAL-TIME')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate 
	And t.Result IS NOT NULL
End
Else
Begin
    Insert Into #Deviations (Grouping_Option,VarDesc,OrderBy)
    Values ('QA Reevaluation','No Variables',2)
End

Update #Deviations
    Set VarDesc = t.Result, Comments = Comments + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('QA-REEVAL-NAME','REEVALNAME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'QA Reevaluation'
And t.Result IS NOT NULL

Update #Deviations
    Set VarDesc = IsNull(VarDesc,'') + IsNull(t.Result,''), Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('QA-REEVAL-NAME2', 'REEVALNAME2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'QA Reevaluation'
And t.Result IS NOT NULL

Update #Deviations
    Set DeviationStatus = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=STATREEVA')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'QA Reevaluation'
And t.Result IS NOT NULL

Update #Deviations
    Set IssueDescription = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment1')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'QA Reevaluation'
And t.Result IS NOT NULL

Update #Deviations
    Set AdjustementDescription = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Attributes v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And d.Grouping_Option = 'QA Reevaluation'
And t.Result IS NOT NULL

-------------------------------------------------------------------------------------------------------------------
-- Processing Variables Data
-------------------------------------------------------------------------------------------------------------------
Insert Into #Deviations (Grouping_Option,OrderBy)
Values ('Label_'+@lblVar,3)

If Exists (    Select 'Variable',v.pu_id,t.Result_On,t.Result, convert(varchar,cs.Comment_Text),3
    From dbo.Tests t WITH(NOLOCK)
    Join #Temp_Variables v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('ATTRFAIL', 'OOSRV')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate
	And Result IS NOT NULL)
Begin
    Insert Into #Deviations (Grouping_Option,Pu_id,Result_On,DevRule,Comments,OrderBy)
    Select 'Variable',v.pu_id,t.Result_On,t.Result, convert(varchar,cs.Comment_Text),3
    From dbo.Tests t WITH(NOLOCK)
    Join #Temp_Variables v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('ATTRFAIL', 'OOSRV')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate 
	And t.Result IS NOT NULL
    Order By Result_On
End
Else
Begin    
    Insert Into #Deviations(Grouping_Option,VarDesc,OrderBy)
    Values ('Variable','No Variables',3)
End

Update #Deviations
    Set VarDesc = t.Result, Comments = Comments + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('ATTRNAME','OOSNAME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

Update #Deviations
    Set VarDesc = IsNull(VarDesc,'') + IsNull(t.Result,''), Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('ATTRNAME2','OOSNAME2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

Update #Deviations
    Set Start_Time = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('ATTRTIME','OOSTIME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

Update #Deviations
    Set Scrap = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=ATTRSCRAP','RPT=VARSCRAP')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

Update #Deviations
    Set DeviationStatus = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=OOSSTAT', 'RPT=OOSSTAT')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

Update #Deviations
    Set IssueDescription = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment1')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

Update #Deviations
    Set AdjustementDescription = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'Variable'

-------------------------------------------------------------------------------------------------------------------
-- Processing QV Reevaluation Data
-------------------------------------------------------------------------------------------------------------------
Insert Into #Deviations (Grouping_Option,OrderBy)
Select 'Label_'+Sheet_desc,4 From dbo.Sheets s WITH(NOLOCK)
Join dbo.Sheet_Variables sv on sv.sheet_id = s.sheet_id 
Where sv.Var_ID In (Select Var_Id From #Temp_Variables Where Extended_Info In ('REEVALRV'))
--and Sheet_Desc Like '%Reev%'
Group By Sheet_Desc

If Exists (Select *
    From dbo.Tests t WITH(NOLOCK)
    Join #Temp_Variables v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('REEVALRV')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate
	And t.Result IS NOT NULL)
Begin
    Insert Into #Deviations (Grouping_Option,Pu_id,Result_On,DevRule,Comments,OrderBy)
    Select 'QV Reevaluation',v.pu_id,t.Result_On,t.Result, convert(varchar,cs.Comment_Text),4
    From dbo.Tests t WITH(NOLOCK)
    Join #Temp_Variables v on v.var_id = t.var_id
    Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
    Where v.Extended_Info In ('REEVALRV')
    And Result_On > @strRptStartDate 
    And Result_On < @strRptEndDate 
	And t.Result IS NOT NULL
    Order By Result_On
End
Else
Begin
    Insert Into #Deviations(Grouping_Option,VarDesc,OrderBy)
    Values ('QV Reevaluation','No Variables',4)
End

Update #Deviations
    Set VarDesc = t.Result, Comments = Comments + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('REEVALNAME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

Update #Deviations
    Set VarDesc = IsNull(VarDesc,'') + IsNull(t.Result,''), Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('REEVALNAME2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

Update #Deviations
    Set Start_Time = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('REEVALTIME')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

Update #Deviations
    Set Scrap = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=VARREEVSCRAP')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

Update #Deviations
    Set DeviationStatus = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=STATREEVV')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

Update #Deviations
    Set IssueDescription = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment1')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

Update #Deviations
    Set AdjustementDescription = t.Result, Comments = IsNull(Comments,'') + ' ' + convert(varchar,cs.Comment_Text)
From dbo.Tests t WITH(NOLOCK)
Join #Temp_Variables v on v.var_id = t.var_id
Join #Deviations d on d.Result_On = t.Result_On and d.Pu_id = v.pu_id
Left Join dbo.Comments cs WITH(NOLOCK) ON t.Comment_ID = cs.Comment_ID 
Where v.Extended_Info In ('RPT=Comment2')
And t.Result_On > @strRptStartDate 
And t.Result_On < @strRptEndDate 
And t.Result IS NOT NULL
AND d.Grouping_Option = 'QV Reevaluation'

-------------------------------------------------------------------------------------------------------------------
-- Update Team Column
-------------------------------------------------------------------------------------------------------------------

INSERT INTO @Crew_Schedule (PU_Id,StartDate, EndDate, Crew_Desc)
SELECT PU_Id, Start_Time, End_Time, Crew_Desc
FROM dbo.Crew_Schedule cs WITH(NOLOCK)
WHERE PU_Id = @STLSUnit 
--AND Start_Time >= @strRptStartDate AND Start_Time <= @strRptEndDate
AND Start_Time < @strRptEndDate AND End_Time > @strRptStartDate 

Update #Deviations
    Set Team = sched.Crew_Desc 
From @Crew_Schedule sched 
Join #Deviations d on sched.pu_id = @STLSUnit
where sched.StartDate <= d.Start_Time
and sched.EndDate > d.Start_Time

-------------------------------------------------------------------------------------------------------------------
-- Build Summary Section 
-------------------------------------------------------------------------------------------------------------------
Declare
        @teamId as int,
        @teamname as varchar(10),
        @SQLString as varchar(1000),
        @teamCount as int,
        @i as int

Insert Into #Summary (Team4) Values(@lblAttr)
Insert Into #Summary (Grouping_Option,DeviationStatus,Total) Values('Attributes',@lblDevStatus,'Total')
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('a',@Open)
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('a',@Closed)
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('a',@NoDeviation)
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('a',@lblTeamSummary)


Select distinct d.Team,ND.NoDev,CD.ClosedDev,OD.OpenDev 
Into #Temp_Summary_Attr
From #Deviations d
Left Join (Select Team,Count(*) as NoDev From #Deviations     
            Where Grouping_Option = 'Attribute'
            and DeviationStatus = @noDeviation 
            Group By Team) as ND on ND.Team = d.Team
Left Join (Select Team,Count(*) as ClosedDev From #Deviations     
            Where Grouping_Option = 'Attribute'
            and DeviationStatus = @Closed 
            Group By Team) as CD on CD.Team = d.Team
Left Join (Select Team,Count(*) as OpenDev From #Deviations     
            Where Grouping_Option = 'Attribute'
            and DeviationStatus = @Open 
            Group By Team) as OD on OD.Team = d.Team
Where d.Team Is Not NULL

Select @teamCount = Count(Team) From #Temp_Summary_Attr
Select @teamname = Min(Team) From #Temp_Summary_Attr

Set @j = 1
While @j <= @teamCount
Begin  

   Set @SQLString = 'Update #Summary ' +
        ' Set Team' + convert(varchar,@j) + ' = ''' + @teamName + '''' +
   'Where Grouping_Option = '''+ 'Attributes' + ''''

   Exec (@SQLString)

   Select @teamname = Min(Team) From #Temp_Summary_Attr Where Team > @teamName
   Set @j = @j + 1
           
End

-- VARIABLES
Insert Into #Summary(Team4) Values(@lblVar)
Insert Into #Summary (Grouping_Option,DeviationStatus,Team1,Team2,Team3,Team4,Team5,Team6,Team7,Team8,Total)
Select 'Variables',DeviationStatus,Team1,Team2,Team3,Team4,Team5,Team6,Team7,Team8,Total 
From #Summary Where Grouping_Option = 'Attributes'
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('v',@Open)
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('v',@Closed)
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('v',@NoDeviation)
Insert Into #Summary (Grouping_Option,DeviationStatus) Values('v',@lblTeamSummary)

Select distinct d.Team,ND.NoDev,CD.ClosedDev,OD.OpenDev 
Into #Temp_Summary_Vars
From #Deviations d
Left Join (Select Team,Count(*) as NoDev From #Deviations     
            Where Grouping_Option = 'Variable'
            and DeviationStatus = @noDeviation 
            Group By Team) as ND on ND.Team = d.Team
Left Join (Select Team,Count(*) as ClosedDev From #Deviations     
            Where Grouping_Option = 'Variable'
            and DeviationStatus = @Closed 
            Group By Team) as CD on CD.Team = d.Team
Left Join (Select Team,Count(*) as OpenDev From #Deviations     
            Where Grouping_Option = 'Variable'
            and DeviationStatus = @Open
            Group By Team) as OD on OD.Team = d.Team
Where d.Team Is Not NULL


----------------------------------------------------------------------------------------------------------------
Declare 
        @tableName as varchar(100),
        @letter    as varchar(1)

Set @i = 1
Set @j = 1

While @i <= 2
Begin

Select @tablename = (case @i when 1 then '#Temp_Summary_Attr' else '#Temp_Summary_Vars' end),
       @letter = (case @i when 1 then 'a' else 'v' end)
    
    While @j <= @teamCount
    Begin
        -- No Deviations
        Set @SQLString = 'Update #Summary ' +
            ' Set Team' + convert(varchar,@j) +'= (Select NoDev From ' + @tablename +
                                    ' Where Team = (Select Team'+ convert(varchar,@j) +' From #Summary ' +
                                                         ' Where DeviationStatus = '''+ @lblDevStatus + '''' +
                                                         ' and Grouping_Option = ''' + 'Attributes' + ''')) ' +
        'From #Summary ' +
        'Where DeviationStatus = ''' + @NoDeviation + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)
    
        -- Closed Deviations
        Set @SQLString = 'Update #Summary ' +
            ' Set Team' + convert(varchar,@j) +'= (Select ClosedDev From ' + @tablename +
                                    ' Where Team = (Select Team'+ convert(varchar,@j) +' From #Summary ' +
                                                         ' Where DeviationStatus = '''+ @lblDevStatus + '''' +
                                                         ' and Grouping_Option = ''' + 'Attributes' + ''')) ' +
        'From #Summary ' +
        'Where DeviationStatus = ''' + @Closed + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
        print @SQLString
        Exec (@SQLString)
    
        -- Open Deviations
        Set @SQLString = 'Update #Summary ' +
            ' Set Team' + convert(varchar,@j) +'= (Select OpenDev From ' + @tablename +
                                    ' Where Team = (Select Team'+ convert(varchar,@j) +' From #Summary ' +
                                                         ' Where DeviationStatus = '''+ @lblDevStatus + '''' +
                                                         ' and Grouping_Option = ''' + 'Attributes' + ''')) ' +
        'From #Summary ' +
        'Where DeviationStatus = ''' + @Open + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)
        
        -- Team Summary
        Set @SQLString = 'Update #Summary ' +
            ' Set Team' + convert(varchar,@j) +'= (Select Sum(IsNull(OpenDev,0))+Sum(IsNull(ClosedDev,0))+Sum(IsNull(NoDev,0)) From ' + @tablename +
                                    ' Where Team = (Select Team'+ convert(varchar,@j) +' From #Summary ' +
                                                         ' Where DeviationStatus = '''+ @lblDevStatus + '''' +
                                                         ' and Grouping_Option = ''' + 'Attributes' + ''')) ' +
        'From #Summary ' +
        'Where DeviationStatus = ''' + @lblTeamSummary + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)
    
        Set @j = @j + 1
    End
    
        -- No Deviations
        Set @SQLString = 'Update #Summary ' +
            ' Set Total = (Select Sum(NoDev) From ' + @tablename + ')' +
        'From #Summary ' +
        'Where DeviationStatus = ''' + @NoDeviation + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)
    
        -- Closed Deviations
        Set @SQLString = 'Update #Summary ' +
            ' Set Total = (Select Sum(ClosedDev) From ' + @tablename + ')' +                            
        'From #Summary ' +
        'Where DeviationStatus = ''' + @Closed + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)
    
        -- Open Deviations
        Set @SQLString = 'Update #Summary ' +
            ' Set Total = (Select Sum(OpenDev) From ' + @tablename + ')' +                             
        'From #Summary ' +
        'Where DeviationStatus = ''' + @Open + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)
        
        -- Team Summary
        Set @SQLString = 'Update #Summary ' +
            ' Set Total = (Select Sum(IsNull(OpenDev,0))+Sum(IsNull(ClosedDev,0))+Sum(IsNull(NoDev,0)) From ' + @tablename + ')' +                         
        'From #Summary ' +
        'Where DeviationStatus = ''' + @lblTeamSummary + '''' +
        ' and Grouping_Option = ''' + @letter + ''''
    
        Exec (@SQLString)

Set @i = @i + 1
Set @j = 1
End


Update #Deviations
    Set 
        Scrap = Grouping_Option
Where VarDesc Is NULL 

If @strRptShowTeam = 'FALSE'
Begin
  Update #Summary
        Set Team1 = Total, Team2 = '', Team3 = '',Team4 = '', Team5 = '', Team6 = '',Team7 = '', Team8 = '',Total = ''
  Update #Summary
        Set DeviationStatus = 'Total'
  Where DeviationStatus = 'Team Summary'
End

Select DeviationStatus,Team1,Team2,Team3,Team4,Team5,Team6,Team7,Team8,Total From #Summary
-- Select * From #Summary

Select VarDesc,DevRule,Start_Time,Team,Scrap,Location,DeviationStatus,IssueDescription,AdjustementDescription,Comments
	From #Deviations order by orderby,id_dev

SELECT 'Deviation ' AS Report, @vchAppVersion AS AppVersion, @vchRTVersion AS RTVersion

Drop Table #Temp_Attributes
Drop Table #Temp_Variables
Drop Table #Deviations 
Drop Table #Summary
Drop Table #Temp_Summary_Attr
Drop Table #Temp_Summary_Vars
       
Return

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

GRANT  EXECUTE  ON [dbo].[spLocal_RptQA_Deviations_HTML5] TO OPDBManager
GO
