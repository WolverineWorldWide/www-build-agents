# WWW Build Agents

## Bitbucket Windows Runners

_Note: This is an ongoing experiment into making this as repeatable as possible. Yes, I know that Powershell DSC (Desired State Configuration) exists and is awesome, but I was too inexperienced at the time and so reverted back to the old fashioned way. Here are my notes:_

All this setup stuff should be performed in Powershell as an Administrator

```powershell
Set-ExecutionPolicy RemoteSigned

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# You may have to force long path enabling here (I did, on my windows sandbox; haven't tried yet on the temp server)
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
git config --system core.longpaths true

# Prerequisites for Windows Runners
choco install -y git
choco install -y git-lfs.install
choco install -y openjdk11
choco install -y dotnetfx --pre

# Needed for WWW Builds
choco install -y nvs
choco install -y nuget.commandline
choco install -y visualstudio2019buildtools
choco install -y visualstudio2019testagent
choco install -y netfx-4.6.2-devpack

# HOLD UP: This 4.5.2 version will pop open a license screen.
# If you're sure you got past the license screen and still the agent isn't recognizing the 4.5.2 dev pack, maybe try installing from https://dotnet.microsoft.com/en-us/download/dotnet-framework/thank-you/net452-developer-pack-offline-installer
choco install -y netfx-4.5.2-devpack
```

Please make sure you restart before installing a runner. Chocolatey mentions to run `refreshenv` but neglects to inform you it won't work as expected in Powershell.

There are some old timey Visual Studio files we have to manually place on the server. See the
`resources/VisualStudioTargets/WebApplication` directory and copy its contents to the server at:

```
C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VisualStudio\v16.0\WebApplications\
```

_NOTE: You will need to do the above for each version of msbuild you have on the server. Be mindful of the `v16.0` which changes per msbuild version!_

It is best to make an alias for build/test tools with version intact, so this should be run in the same scope as the build runner:

```powershell
Set-Alias -Scope Global -Name msbuild2019 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\msbuild.exe"
Set-Alias -Scope Global -Name vstest2019 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\TestAgent\Common7\IDE\Extensions\TestPlatform\vstest.console.exe"
```

Now you can set up the build runner in the Bitbucket admin. The lousy instructions are for testing in the current console. In reality, we'll eventually use NSSM to set it up as a server. _TODO: Chad to provide more info_


