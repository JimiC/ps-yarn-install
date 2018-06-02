# ps-yarn-install

PowerShell script to install `Yarn` on Windows, similar to the `Bash` script already available at `https://yarnpkg.com/install.sh`. [View source on GitHub](https://github.com/yarnpkg/website/blob/master/install.sh).

The purpose of creating this script is to be used on a `Windows` environment `CI`, like [AppVeyor](https://ci.appveyor.com).

## Installation Script

You can install `Yarn` by running the following code in your terminal:

`curl -o $env:temp\install.ps1 https://raw.githubusercontent.com/JimiC/ps-yarn-install/master/install.ps1 | powershell $env:temp\install.ps1`

The installation process includes verifying an `AuthCode` signature.

You can also specify a version by running the following code in your terminal:

`curl -o $env:temp\install.ps1 https://raw.githubusercontent.com/JimiC/ps-yarn-install/master/install.ps1 | powershell $env:temp\install.ps1 --version [version]`
