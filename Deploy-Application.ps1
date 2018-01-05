﻿<#
.SYNOPSIS
	This script performs the installation or uninstallation of an application(s).
.DESCRIPTION
	The script is provided as a template to perform an install or uninstall of an application(s).
	The script either performs an "Install" deployment type or an "Uninstall" deployment type.
	The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.
	The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.
.PARAMETER DeploymentType
	The type of deployment to perform. Default is: Install.
.PARAMETER DeployMode
	Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.
.PARAMETER AllowRebootPassThru
	Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.
.PARAMETER TerminalServerMode
	Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Destkop Session Hosts/Citrix servers.
.PARAMETER DisableLogging
	Disables logging to file for the script. Default is: $false.
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"
.EXAMPLE
    powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"
.EXAMPLE
    Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"
.NOTES
	Toolkit Exit Code Ranges:
	60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
	69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
	70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1
.LINK
	http://psappdeploytoolkit.com
#>
[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}

	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = 'MSU Denver'
	[string]$appName = 'Profile Cleanup'
	[string]$appVersion = '2018.30'
	[string]$appArch = 'x64'
	[string]$appLang = 'EN'
	[string]$appRevision = '01'
	[string]$appScriptVersion = '1.0.0'
	[string]$appScriptDate = '01/04/2018'
	[string]$appScriptAuthor = 'Jordan Hamilton'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''

	##* Do not modify section below
	#region DoNotModify

	## Variables: Exit Code
	[int32]$mainExitCode = 0

	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.6.9'
	[string]$deployAppScriptDate = '02/12/2017'
	[hashtable]$deployAppScriptParameters = $psBoundParameters

	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}

	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================

	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		## Show Welcome Message, close applications if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
		Show-InstallationWelcome  -CheckDiskSpace -PersistPrompt

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Installation tasks here>
		$ProfileList = Get-ChildItem -Path "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\S-1-5-21-898*" -Force

		##*===============================================
		##* INSTALLATION
		##*===============================================
		[string]$installPhase = 'Installation'

		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}

		## <Perform Installation tasks here>
		ForEach ($ProfileSID in $ProfileList) {
			$ProfileImagePath = Get-RegistryKey -Key $ProfileSID -Value "ProfileImagePath"
			$Guid = Get-RegistryKey -Key $ProfileSID -Value "Guid"
			If ($ProfileImagePath -and $Guid) {
				Switch ($ProfileImagePath) {
					"${envUserProfile}" {Write-Log -Message "Skipping the current user's profile: ${envUserProfile}" -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\labtest" {Write-Log -Message "Skipping the labtest profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\generallab" {Write-Log -Message "Skipping the generallab profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\Level1" {Write-Log -Message "Skipping the Level1 profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\Level2" {Write-Log -Message "Skipping the Level2 profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\Testing" {Write-Log -Message "Skipping the Testing profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\accesstesting*" {Write-Log -Message "Skipping the accesstesting profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					"${envSystemDrive}\Users\registration*" {Write-Log -Message "Skipping the registration profile." -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$False; break}
					default {Write-Log -Message "Found user folder to remove: ${ProfileImagePath}" -Severity 1 -Source $deployAppScriptFriendlyName; $remove=$True}
				}
				If ($remove) {
					If (Test-Path -Path $ProfileImagePath -PathType 'Container') {
						Write-Log -Message "Removing user folder: ${ProfileImagePath}" -Severity 1 -Source $deployAppScriptFriendlyName
						#Remove-File -Path "${ProfileImagePath}\*" -Recurse
						#Remove-Folder -Path $ProfileImagePath
						Write-Log -Message "Removing user GUID from the registry: ${Guid}" -Severity 1 -Source $deployAppScriptFriendlyName
						#Remove-RegistryKey -Key "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGuid\${Guid}"
						Write-Log -Message "Removing user SID from the registry: ${ProfileSID}" -Severity 1 -Source $deployAppScriptFriendlyName
						#Remove-RegistryKey -Key "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\${ProfileSID}"
					} Else {
						Write-Log -Message "User folder ${ProfileImagePath} does not exist. Deleting user GUID and SID from the registry..." -Severity 2 -Source $deployAppScriptFriendlyName
						#Remove-RegistryKey -Key "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileGuid\${Guid}"
						#Remove-RegistryKey -Key "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\${ProfileSID}"
					}
				}
			} Else {
				Write-Log -Message "Unable to detect the folder location for this user. Skipping this profile." -Severity 2 -Source $deployAppScriptFriendlyName
			}
		}

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'

		## <Perform Post-Installation tasks here>
		$mainExitCode = 3010

		## Display a message at the end of the install
		#If (-not $useDefaultMsi) { Show-InstallationPrompt -Message "${appVendor} ${appName} ${appVersion} was installed successfully." -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'

		## Show Welcome Message, close applications with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60

		## Show Progress Message (with the default message)
		Show-InstallationProgress

		## <Perform Pre-Uninstallation tasks here>


		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'

		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}

		# <Perform Uninstallation tasks here>


		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'

		## <Perform Post-Uninstallation tasks here>


	}

	##*===============================================
	##* END SCRIPT BODY
	##*===============================================

	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}