Function YarnGetMSI {
    Param([String]$1, [String]$2)

    Write-Host "> Downloading Microsoft Installer..." -ForegroundColor Cyan

    If ($1 -eq "--nightly") {
        $url = "https://nightly.yarnpkg.com/latest.msi"
    }
    ElseIf ($1 -eq "--rc") {
        $url = "https://yarnpkg.com/latest-rc.msi"
    }
    ElseIf ($1 -eq "--version") {
        # Validate that the version matches MAJOR.MINOR.PATCH to avoid garbage-in/garbage-out behavior
        $version = $2
        If ($version -match "^[0-9]+\.[0-9]+\.[0-9]+$") {
            $url = "https://yarnpkg.com/downloads/$version/yarn-$version.msi"
        }
        Else {
            Write-Host "> Version number must match MAJOR.MINOR.PATCH." -ForegroundColor Red
            exit 1
        }
    }
    Else {
        $url = "https://yarnpkg.com/latest.msi"
    }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        (New-Object Net.WebClient).DownloadFile($url, "$env:temp\yarn.msi")

        # Authentication code signature verification
        YarnVerifyIntegrity
    }
    catch [System.Net.WebException] {
        Write-Host "> Failed to download $url." -ForegroundColor Red
        exit 1
    }
    catch [System.IO.IOException] {
        Write-Host "> Failed to write to 'temp' directory." -ForegroundColor Red
        exit 1
    }
    catch {
        Write-Error $_.Exception.Message
        exit 1
    }
}

Function YarnVerifyIntegrity {
    Write-Host "> Verifying integrity..." -ForegroundColor Cyan
    $thumbprint = (Get-AuthenticodeSignature $env:temp\yarn.msi).SignerCertificate.Thumbprint
    
    $index = 0
    If ([System.Version]$specifiedVersion -lt [System.Version]"1.22.0") {
        $index++
    }

    If ($thumbprint -eq $authCodeSigns[$index]) {
        Write-Host "> AuthCode signature looks good." -ForegroundColor Green
    }
    Else {
        Write-Host "> AuthCode signature for this Yarn release is invalid! This is BAD and may mean the release has been tampered with. It is strongly recommended that you report this to the Yarn developers." -ForegroundColor Red
        YarnVerifyOrQuit "> Do you really want to continue?"
    }
}

Function YarnVerifyOrQuit {
    Param([String]$1)

    $reply = Read-Host -Prompt "$1 [y/N] "
    Write-Output ""

    If (!($reply -match "^[Yy]$")) {
        Write-Host "> Aborting" -ForegroundColor Red
        exit 1
    }
}

Function YarnInstallMSI {
    Write-Host "> Installing to $programFilesDir\Yarn..." -ForegroundColor Cyan
    cmd /c start /wait msiexec.exe /i $env:temp\yarn.msi /quiet /qn /norestart /log install.log

    if (!(Test-Path -Path "$programFilesDir\Yarn\bin\yarn" -PathType Leaf)) {
        Write-Host "> Installation failed. See the 'install.log' file for more info." -ForegroundColor Red
        exit 1
    }

    $version = cmd /c $programFilesDir\Yarn\bin\yarn --version 2>> install.log

    If (!$version) {
        Write-Host "> Yarn was installed, but doesn't seem to be working :(." -ForegroundColor Red
        exit 1
    }

    Write-Host "> Successfully installed Yarn $version! Please open another shell where the 'yarn' command will now be available." -ForegroundColor Green
}

Function YarnInstall {
    Param([String]$1, [String]$2)

    Write-Host "Installing Yarn!" -ForegroundColor White

    If (Test-Path -Path "$programFilesDir\Yarn" -PathType Container) {
        $latestUrl
        $specifiedVersion
        $latestVersion
        $versionType

        If ($1 -eq "--nightly") {
            $latestUrl = "https://nightly.yarnpkg.com/latest-msi-version"
            $specifiedVersion = (Invoke-WebRequest -UseBasicParsing -Uri $latestUrl).Content -replace "\n", ""
            $versionType = "nightly"
        }
        ElseIf ($1 -eq "--rc") {
            $latestUrl = "https://yarnpkg.com/latest-rc-version"
            $specifiedVersion = (Invoke-WebRequest -UseBasicParsing -Uri $latestUrl).Content -replace "\n", ""
            $versionType = "rc"
        }
        Else {
            $latestUrl = "https://yarnpkg.com/latest-version"
            $latestVersion = (Invoke-WebRequest -UseBasicParsing -Uri $latestUrl).Content -replace "\n", ""
            If ($1 -eq "--version") {
                $specifiedVersion = $2
                $versionType = "specified"
            }
            Else {
                $specifiedVersion = $latestVersion
                $versionType = "latest"
            }
        }

        try {
            $yarnVersion = yarn -v
            $yarnAltVersion = yarn --version
        }
        catch {
            Write-Error $_.Exception.Message
            exit 1
        }

        If ([System.Version]$specifiedVersion -eq [System.Version]$yarnVersion -or [System.Version]$specifiedVersion -eq [System.Version]$yarnAltVersion) {
            Write-Host "> Yarn is already at the $specifiedVersion version." -ForegroundColor Green
            exit 0
        }
        ElseIf ([System.Version]$specifiedVersion -gt [System.Version]$latestVersion -and $versionType -ne "nightly") {
            Write-Host "> $specifiedVersion has not been released yet. Check back later." -ForegroundColor Yellow
            exit 0
        }
        ElseIf ([System.Version]$specifiedVersion -lt [System.Version]$yarnVersion -or [System.Version]$specifiedVersion -lt [System.Version]$yarnAltVersion) {
            Write-Host "> A newer Yarn version ($yarnAltVersion) is already installed." -ForegroundColor Yellow
            exit 0
        }
        Else {
            Write-Host "> $yarnAltVersion is already installed. Installing specified version: $specifiedVersion." -ForegroundColor Yellow
        }
    }

    YarnGetMSI $1 $2
    YarnInstallMSI
}

# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
# # Get the security principal for the Administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator

If ($myWindowsPrincipal.IsInRole($adminRole)) {
    $programFilesDir = (${env:ProgramFiles(x86)}, $null -ne ${env:ProgramFiles})[0]
    [string[]]$authCodeSigns = 
        "795D68C6828BD3D21B36EB15F7A31EE5873EBE8F",
        "AF764E1EA56C762617BDC757C8B0F3780A0CF5F9"

    YarnInstall $args[0] $args[1]
}
Else {
    Write-Host "> You do not have sufficient privileges to complete this installation for all users of the machine." -ForegroundColor Red
    Write-Host "> Log on as administrator and then retry this installation." -ForegroundColor Red
}
