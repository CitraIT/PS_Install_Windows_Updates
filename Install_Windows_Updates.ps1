<#
# CITRA IT - EXCELÊNCIA EM TI
# SCRIPT PARA DOWNLOAD E INSTALAÇÃO DE ATUALIZAÇÕES DO WINDOWS
# AUTOR: Microsoft(c) - Adaptado do script encontrado no AdminCenter
# DATA: 01/10/2021
# Homologado para executar no Windows 10 ou Server 2012R2+
# EXAMPLO DE USO: Powershell -ExecutionPolicy ByPass -File C:\Scripts\Install_Windows_Updates.ps1
#>

$objServiceManager = New-Object -ComObject 'Microsoft.Update.ServiceManager';
$objSession = New-Object -ComObject 'Microsoft.Update.Session';
$objSearcher = $objSession.CreateUpdateSearcher();
$objSearcher.ServerSelection = 0;
$serviceName = 'Windows Update';
$search = 'IsInstalled = 0';
$objResults = $objSearcher.Search($search);
$Updates = $objResults.Updates;
$FoundUpdatesToDownload = $Updates.Count;

$NumberOfUpdate = 1;
$objCollectionDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl';
$updateCount = $FoundUpdatesToDownload;
Foreach($Update in $Updates)
{
    Write-Progress -Activity 'Downloading updates' -Status `"[$NumberOfUpdate/$updateCount]` $($Update.Title)`" -PercentComplete ([int]($NumberOfUpdate/$updateCount * 100));
    $NumberOfUpdate++;
    Write-Host `"Show` update` to` download:` $($Update.Title)`" ;
    Write-Host 'Accept Eula';
    $Update.AcceptEula();
    Write-Host 'Send update to download collection';
    $objCollectionTmp = New-Object -ComObject 'Microsoft.Update.UpdateColl';
    $objCollectionTmp.Add($Update) | Out-Null;

    $Downloader = $objSession.CreateUpdateDownloader();
    $Downloader.Updates = $objCollectionTmp;
    Try
    {
      Write-Host 'Try download update';
      $DownloadResult = $Downloader.Download();
    } <#End Try#>
    Catch
    {
      If($_ -match 'HRESULT: 0x80240044')
      {
        Write-Host 'Your security policy do not allow a non-administator identity to perform this task';
      } <#End If $_ -match 'HRESULT: 0x80240044'#>

      Return
    } <#End Catch#>

    Write-Host 'Check ResultCode';
    Switch -exact ($DownloadResult.ResultCode)
    {
      0   { $Status = 'NotStarted'; }
      1   { $Status = 'InProgress'; }
      2   { $Status = 'Downloaded'; }
      3   { $Status = 'DownloadedWithErrors'; }
      4   { $Status = 'Failed'; }
      5   { $Status = 'Aborted'; }
    } <#End Switch#>

    If($DownloadResult.ResultCode -eq 2)
    {
      Write-Host 'Downloaded then send update to next stage';
      $objCollectionDownload.Add($Update) | Out-Null;
    } <#End If $DownloadResult.ResultCode -eq 2#>
}

$ReadyUpdatesToInstall = $objCollectionDownload.count;
Write-Host `"Downloaded` [$ReadyUpdatesToInstall]` Updates` to` Install`" ;
If($ReadyUpdatesToInstall -eq 0)
{
	Return;
} <#End If $ReadyUpdatesToInstall -eq 0#>

$NeedsReboot = $false;
$NumberOfUpdate = 1;

<#install updates#>
Foreach($Update in $objCollectionDownload)
{
	Write-Progress -Activity 'Installing updates' -Status `"[$NumberOfUpdate/$ReadyUpdatesToInstall]` $($Update.Title)`" -PercentComplete ([int]($NumberOfUpdate/$ReadyUpdatesToInstall * 100));
	Write-Host 'Show update to install: $($Update.Title)';

	Write-Host 'Send update to install collection';
	$objCollectionTmp = New-Object -ComObject 'Microsoft.Update.UpdateColl';
	$objCollectionTmp.Add($Update) | Out-Null;

	$objInstaller = $objSession.CreateUpdateInstaller();
	$objInstaller.Updates = $objCollectionTmp;

	Try
	{
		Write-Host 'Try install update';
		$InstallResult = $objInstaller.Install();
	} <#End Try#>
	Catch
	{
		If($_ -match 'HRESULT: 0x80240044')
		{
			Write-Host 'Your security policy do not allow a non-administator identity to perform this task';
		} <#End If $_ -match 'HRESULT: 0x80240044'#>

		Return;
	} #End Catch

	If(!$NeedsReboot)
	{
		Write-Host 'Set instalation status RebootRequired';
		$NeedsReboot = $installResult.RebootRequired;
	} <#End If !$NeedsReboot#>
	$NumberOfUpdate++;
} <#End Foreach $Update in $objCollectionDownload#>

If($NeedsReboot){
	<#Restart almost immediately, given some seconds for this PSSession to complete.#>
	$waitTime = 5
    Shutdown -r -f -t $waitTime -c "SME installing Windows updates";
}