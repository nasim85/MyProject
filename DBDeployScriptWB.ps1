param([string]$DropLocation="",[string]$ConfigLocation="",[string]$BUILDNUMBER="",[string]$ENV="CI",[string] $DbList="1",[string] $ReportMailTo="ReportMailTo")
<#
$ApplicationPathRoot="C:\Users\300915\Desktop\RMTool\RMComp"
$BUILDNUMBER="DB-TestRMTran-CI_20151026.3"
$ENV="CI"
$DbList="15"
#>

#$DropLocation=$ApplicationPathRoot
#$ConfigLocation=$DropLocation+"\..\..\RMConfig\"
#$ConfigLocation="D:\RMConfig\"
$ScriptLocation=$ConfigLocation+"\"+ $BUILDNUMBER+"\"
#$DropLocation += "\"+$ComponentName
$SQLScriptPath="$DropLocation\ACH_DB_All\DailyBuildScript"
$buildNumber=$BUILDNUMBER
$isSuccessded="1"
$onErrorExit=$False


[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null
try
{
    Write-Verbose ("ENV=$ENV ,  buildNumber= $BUILDNUMBER , DropLocation=$DropLocation, ConfigLocation=$ConfigLocation, DBList=$DbList")
    Write-Host ("ENV=$ENV ,  buildNumber= $BUILDNUMBER , DropLocation=$DropLocation, ConfigLocation=$ConfigLocation, DBList=$DbList")
	
	try{
			Add-PSSnapin SqlServerCmdletSnapin100
			Add-PSSnapin SqlServerProviderSnapin100
		}
    Catch
       {
            Write-Verbose $_.Exception
            Write-Host $_.Exception
            LogFileGen -SummaryTxt ($_.Exception)
		}

###################### Global Variables ########################################
 $EnvConfigPath =""
 $LogPath =""
 $EnvDetailList =""
 ####### Out put Log File ########## 
 $LogPath = $DropLocation+"\Logs\"
 $LogFilePath =$LogPath + $buildNumber+"_Deployment_EventLog_Summary.txt"
 $DepSummaryCSV=$ConfigLocation+"\DeploymentSummary"+$buildNumber+"_"+ $ENV +".csv"
 ####### Create configuration file for deployement ##########
 $ConfigFilePath =$ConfigLocation+"ReleaseConfig.xml"

 $EnvConfigPath  = $DropLocation +"\DeploymentTools\EnvironmentConfig-"+$ENV+".csv"

 ###################### SQLPackage Load #########################################
 $SQLPkgPath="${env:ProgramFiles(x86)}\Microsoft SQL Server\120\DAC\bin\sqlpackage.exe"
 $TFS = "${env:ProgramFiles(x86)}\Microsoft Visual Studio 11.0\Common7\IDE\tf.exe"

#######Function for loging events and exceptions ####################################
 Function LogFileGen([string] $SummaryTxt )
 {  
        #Write-Host $SummaryTxt
        $SummaryTxt +" Time : "+$((Get-Date).ToString('yyyy,MM,dd hh:mm:ss')) |Out-File -FilePath $LogFilePath -Append 
        Write-Verbose $SummaryTxt 
  }

 ######## Validate log file path.#######################################################
    Try
    {
        If (!$(Test-Path -Path $LogPath)){New-Item -ItemType "directory" -Path $LogPath | Out-Null}
        If (!$(Test-Path -Path $ConfigLocation)){New-Item -ItemType "directory" -Path $ConfigLocation | Out-Null}
        If (!$(Test-Path -Path $ScriptLocation)){New-Item -ItemType "directory" -Path $ScriptLocation | Out-Null}
    }
    Catch
    {
        LogFileGen -SummaryTxt "Creating Log Folder : "$error
    }
 


 # Validate and read environment config details.=================================
@( 
     LogFileGen -SummaryTxt "Reading Environment Config file"

     if (Test-Path $EnvConfigPath ) 
     {
        $EnvDetailList= Import-Csv $EnvConfigPath  | Where-Object {$_.env -eq $Env}
             LogFileGen -SummaryTxt "Completed Reading Environment Config file "
     }
     Else { LogFileGen -SummaryTxt "Environment Config file Missing." }
 )


  # Create a data table for holding change script details.========================
@(            
    $DatabaseList=@()

    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "DNN30"; ExcOrder = "1"; ScriptFile=""}
	$DatabaseList+=New-Object PsObject -property @{  DatabaseName = "DNN"; ExcOrder = "1"; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "DNNStage"; ExcOrder = "2"  ; ScriptFile="" }
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "ClaimStatus"; ExcOrder = "3" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "CrossSiteYBFU"; ExcOrder = "4" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "Reference"; ExcOrder = "5" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "Global_AhtoDialer"; ExcOrder = "6" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "DataArchive"; ExcOrder = "7" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "ELIGIBILITY"; ExcOrder = "8" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "Accretive"; ExcOrder = "9" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "AccretiveLogs"; ExcOrder = "10" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "CrossSiteSupport"; ExcOrder = "11" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "Global_FCC_PreRegistration"; ExcOrder = "12" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "TranGLOBAL"; ExcOrder = "13" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "FileExchange"; ExcOrder = "14" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "Tran"; ExcOrder = "15" ; ScriptFile=""}
    $DatabaseList+=New-Object PsObject -property @{  DatabaseName = "AhCrossSite"; ExcOrder = "16" ; ScriptFile=""}
 
 )

  # get sql change scripts files from drop location
  @(
    LogFileGen -SummaryTxt "Reading SQL script file from the drop location"
    #Write-Verbose $SQLScriptPath
    $dtScriptList = Get-ChildItem $SQLScriptPath |  Where-Object {$_.name -match $buildNumber  -and $_.Extension -eq ".sql" }#|Select-Object -First 1
     
    if ($dtScriptList.Count -gt 0)
     {     
       foreach($script in $dtScriptList)
       {
           $DBNameString= Get-Content $script.FullName | select -First 100 | Where-Object { $_.Contains(":setvar DatabaseName") }
           $ScriptDBName=($DBNameString -split '"')[1]
           if($DbList -eq "15")
           {
                $ScriptDBName="Tran"
           }
           $listitem= $DatabaseList|Where-Object {$_.DatabaseName -eq $ScriptDBName}
		   if($listitem)
           {
           $listitem.ScriptFile=$script.FullName
		   }
           LogFileGen -SummaryTxt  "$script : updated in deployement list"
       }
     }
     else
     {
        LogFileGen -SummaryTxt ("No script file is found for that build number :- $buildNumber .")
     }
 
 )

    #get the last release deployement status
    @(

        [xml] $doc = Get-Content($ConfigFilePath)
        #$child = $doc.CreateElement("newElement")
        #$doc.DocumentElement.AppendChild($child)
        if(!($doc.ReleaseStatus.Build |Where-Object {$_.buildNumber -eq $BUILDNUMBER  -and $_.Env -eq $ENV}))
        {
            $bchild = $doc.CreateElement("Build")
            $bchild.SetAttribute(“buildNumber”,$BUILDNUMBER);
            $bchild.SetAttribute(“Status”,"New");
            $bchild.SetAttribute(“Env”,$ENV);
            #$doc.SelectSingleNode(("//ReleaseStatus").AppendChild($bchild))
            #$doc.ReleaseStatus.AppendChild($bchild)
            $doc.DocumentElement.AppendChild($bchild)
                
            $doc.Save($ConfigFilePath)
        }
        $buildNode= $doc.ReleaseStatus.Build |Where-Object {$_.buildNumber -eq $BUILDNUMBER  -and $_.Env -eq $ENV} #| Select-Object name
        $release= $buildNode.Database |Where-Object {$_.Status -eq "Succeeded"} #| Select-Object name

    )


  # Function for execute sql scripts. =======================================
       Function Execute-Sql{
           param($ServerName, $DbName, $ScriptFile,$excOrder)

           $LogFilePathD =$LogPath + $buildNumber+"_"+$ServerName.Replace("\" ,"-")+"_"+$DbName+"_Log.txt"
           try
           {
                [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null 
                LogFileGen -SummaryTxt ( "Deployment start for :- " + $DbName + " on Server :-" +$ServerName +" SQL Script file :-" + $ScriptFile)
                Invoke-Sqlcmd -ServerInstance "$ServerName" -InputFile "$ScriptFile" -ErrorAction 'Continue' -Database "$DbName" -OutputSqlErrors:$true -Verbose *>&1  |Out-File -FilePath $LogFilePathD 
                
                #############update the config file for deployment status###################################
                $child = $doc.CreateElement("Database")
                if($buildNode.Database |Where-Object {$_.Name -eq $DbName})
                { $child= $buildNode.Database |Where-Object {$_.Name -eq $DbName} } 
                $child.set_InnerText($DbName)
                $child.SetAttribute(“Name”,$DbName);
                $child.SetAttribute(“order”,$excOrder);
                $child.SetAttribute(“Status”,”Succeeded”);
                $scriptNameonly=split-path $ScriptFile -Leaf
                $child.SetAttribute(“ScriptFileName”,$scriptNameonly);
                #$doc.SelectSingleNode(("//ReleaseStatus/Build").AppendChild($child))
                #$doc.ReleaseStatus.Build.AppendChild($child)
				$buildNode.AppendChild($child)
                #$doc.DocumentElement.ReleaseStatus.Build.AppendChild($child)
                
                $doc.Save($ConfigFilePath)

                $now=Get-Date -format "MM/dd/yyyy HH:mm"
                $depStat= Import-CSV -Path $DepSummaryCSV | Where-Object {$_.SERVERNAME -ne ""}
                ForEach($item in  $depStat) 
                { 
                    if($item.SERVERNAME -eq $ServerName -and $item.DBNAME -eq $DbName) 
                    { 
						$item.Details = "";
                        $item.Status = "Succeeded";
                        $item.DeploymentDateTime = $now;
                    } 
                }
                $depStat | Select * | Export-CSV -Path $DepSummaryCSV -NoTypeInformation


                #$content="$buildNumber,$DbName,Succeded,$scriptNameonly"
                #Add-Content  -Path $DepSummaryCSV -Value $content
                #################################################################################
                
                $objectsDeploy= Get-Content -Path $LogFilePathD | Out-String 
                Write-Verbose $objectsDeploy
                Write-Host $objectsDeploy
                LogFileGen -SummaryTxt ( "Deployment Completed for : " +$DbName)

           }
           Catch
           {
                $_.Exception.ToString()|Out-File -FilePath $LogFilePathD -Append 
                $objectsDeploy= Get-Content -Path $LogFilePathD | Out-String 
                Write-Verbose $objectsDeploy
                Write-Host $objectsDeploy
                LogFileGen -SummaryTxt ( "Deployment Error in " +$DbName+ " Execute SQL Error : " +$_.Exception)

                $now=Get-Date -format "MM/dd/yyyy HH:mm"
                $depStat= Import-CSV -Path $DepSummaryCSV | Where-Object {$_.SERVERNAME -ne ""}
                ForEach($item in  $depStat) 
                { 
                    if($item.SERVERNAME -eq $ServerName -and $item.DBNAME -eq $DbName) 
                    { 
						$item.Details = $_.Exception;
                        $item.Status = "Failed";
                        $item.DeploymentDateTime = $now;
                    } 
                }
                $depStat | Select * | Export-CSV -Path $DepSummaryCSV -NoTypeInformation

                
                if($onErrorExit -eq $true)
                {
                  throw $_.Exception
                }
                else
                {
                    $global:isSuccessded="0"
                }

           }
        }




        Function sendMail()
{
				if($ReportMailTo)
				{
				$mailto  =  $ReportMailTo
				}
                $mailcc  = "nasimuddin@accretivehealth.com"
                $mailfrom= "ALM@accretivehealth.com"

                #SMTP server name
                $smtpServer = "smtpr.accretivehealth.local"
                $msg = new-object System.Net.Mail.MailMessage

                #Creating SMTP server object
                $smtp = new-object System.Net.Mail.SmtpClient($smtpServer)
                 
				$subject="DB Project Deployment report - $BUILDNUMBER"

                $att = new-object Net.Mail.Attachment($DepSummaryCSV)

                $msg.From = $mailfrom
                $msg.To.Add($mailto)
                $msg.CC.Add($mailcc)
                $msg.subject =  $subject
                $msg.body = "Hello </br></br></br> PFA deployement report for $BUILDNUMBER </br></br></br> Regards</br>ALM Team."
                $msg.IsBodyHTML = $true
                $msg.Attachments.Add($att)
             
                #Sending email
                $smtp.Send($msg)
                $att.Dispose()

}


  
  LogFileGen -SummaryTxt ( "=============================Deployment phase started Started..====================================") 

  #### Create deployement summary in csv format#####################
  If (!$(Test-Path -Path $DepSummaryCSV))
  {
    $csvHeader="BuildNumber,ENV,CLIENT,SERVERNAME,DBNAME,Status,DBScript,DeploymentDateTime,Details"
    $csvHeader| select 'BuildNumber','ENV','CLIENT','SERVERNAME', 'DBNAME','Status', 'DBScript','DeploymentDateTime','Details'| Export-Csv $DepSummaryCSV -NoTypeInformation
  }


  $EnvValueTran = $EnvDetailList|  Where-Object {$_.dbclass -eq 'Tran' -and $_.DBNAME -notin ($release.Name) -and $_.Replication -in ('Pub','None')}

  if($DbList -eq "15"){
  foreach($rel in $EnvValueTran)
  {
  $str=$rel.dbclass + "," + $rel.DBNAME + ","+ $rel.Replication 
  Write-Verbose $str
  Write-Host $str
  }}
  
<#
  Write-Verbose "Tran DB List List item count.."
  foreach($env in $EnvValueTran)
  {
  Write-Verbose $env.DBName
  Write-Verbose $env.SERVERNAME
  }

  Write-Verbose "DB List item count.."
  Write-Verbose $EnvValueTran|Measure-Object -line
#>

  foreach($db in $DatabaseList | where {$_.ScriptFile -ne "" -and ($_.DatabaseName -notin ($release.Name) -or ($EnvValueTran -ne $null -and $_.ExcOrder -eq '15')) -and $_.ExcOrder -in ($DbList -split ",")} )
  {

           $db
           Copy-Item $db.ScriptFile $ScriptLocation -Force

           #$now=Get-Date -format "dd-MMM-yyyy HH:mm"
           $scriptNameonly1=split-path $db.ScriptFile -Leaf
           if($db.ExcOrder -eq '15')
           {
           $EnvValue = $EnvDetailList|  Where-Object {$_.dbclass -eq $db.DatabaseName -and $_.DBNAME -notin ($release.Name) -and $_.Replication -in ('Pub','None')}
           }
           else{
           $EnvValue = $EnvDetailList|  Where-Object {$_.dbclass -eq $db.DatabaseName -and $_.Replication -in ('Pub','None')}#|Select-Object -First 1
           }

           $depSum=Import-Csv $DepSummaryCSV | Where-Object {$_.SERVERNAME -ne ""}
           if($depSum -ne $null  -and $EnvValue -ne $null){
               $depDiff=Compare-Object $EnvValue $depSum -Property SERVERNAME,DBNAME,CLIENT,ENV  | where-object {$_.SideIndicator -eq "<="}
           }
           else
           {
               $depDiff=$EnvValue
           }
           $depDiff | Select-Object @{Name='BuildNumber';Expression={$BUILDNUMBER}},'ENV','Client','SERVERNAME','DBNAME',@{Name='Status';Expression={'Pending'}},@{Name='DBScript';Expression={$scriptNameonly1}},@{Name='DeploymentDateTime';Expression={''}},@{Name='Details';Expression={''}}|Export-Csv $DepSummaryCSV -Append -NoTypeInformation -Force
           #$tmp=$EnvValue | select  $BUILDNUMBER,'Client','SERVERNAME','DBNAME','Status','DBScript','DeploymentDateTime'#| Export-Csv $DepSummaryCSV -Append -NoTypeInformation

           foreach($envDB in $EnvValue)
           {
               $content=Get-Content $db.ScriptFile
               $DBNameString= $content | select -First 100 | Where-Object { $_.Contains(":setvar DatabaseName") }
               $content=$content.Replace($DBNameString,':setvar DatabaseName "'+$envDB.DBName+'"')
               $content | Out-File $db.ScriptFile

               Execute-Sql -ServerName $envDB.SERVERNAME -DbName $envDB.DBName -ScriptFile $db.ScriptFile -excOrder $db.ExcOrder
           }
  }

  if($isSuccessded -eq "0")
  {
    throw "Deployment Error: Please check deployement report or logs for more details."
  }

  sendMail

}
Catch
{
    LogFileGen -SummaryTxt ( "Deployment Error : " +$_.Exception)
    Write-Verbose $_.Exception
	Write-Host $_.Exception
    sendMail
    throw $_.Exception
}

