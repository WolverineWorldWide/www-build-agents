# WWW Build Agents

## Bitbucket Windows Runners

_Note: This is an ongoing experiment into making this as repeatable as possible. Yes, I know that Powershell DSC (Desired State Configuration) exists and is awesome, but I was too inexperienced at the time and so reverted back to the old fashioned way. Here are my notes:_

### Visual Studio Project/Solution Prerequisites

If any projects are targeting .Net Framework 4.5, you'll need to upgrade them to reference 4.5.2. See commit af44b10a6aba7c20848d2d47c24b63c4394c0ed3. I have been [led to believe](https://developercommunity.visualstudio.com/t/the-reference-assemblies-for-netframeworkversionv4-1/1660771) that the 4.5 target simply isn't a thing that can be supported, and that we must upgrade to 4.5.2. We'll see what happens when we actually try to run the applications.

### Build Server Setup

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

# Used to ease installation of build agent runner as Windows Service
choco install -y nssm

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
`Web` and `WebApplication` directories in this repo at `resources/VisualStudioTargets/` and copy the folders to the server at:

```
C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VisualStudio\v16.0\
```

_NOTE: You will need to do the above for each version of msbuild you have on the server. Be mindful of the `v16.0` which changes per msbuild version!_

It is best to make an alias for build/test tools with version intact, so let's maintain a file at `$PSHOME\profile.ps1` with the following contents (add more to this as needed):

```powershell
# These aliases will be available to any job. Add more as needed.
Set-Alias -Scope Global -Name msbuild2019 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\msbuild.exe"
Set-Alias -Scope Global -Name vstest2019 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\TestAgent\Common7\IDE\Extensions\TestPlatform\vstest.console.exe"

$env:NUGET_PACKAGES="C:\build-runner\nuget-package-cache"
```

Some of these Wolverine projects require some legacy nuget packages from old CQL days. These projects are more or less abandoned, so we are including the compiled nuget packages directly on the server.

1. Copy the folders underneath `./resources/NugetLegacyCqlPackages/` and put them on the server at `C:\build-runner\nuget-legacy-cql-packages\`.
2. Take the following XML and include it in the file `C:\build-runner\nuget.config` (this nuget.config file will be incorporated into each job because nuget searches up the directory tree for these files)

```xml
<?xml version="1.0" encoding="utf-8"?>
<configuration>
    <config>
        <add key="legacyCQLPackages" value="C:\build-runner\nuget-legacy-cql-packages" />
    </config>
    <packageRestore>
        <add key="enabled" value="True" />
    </packageRestore>
</configuration>
```

When you create a new Runner in Bitbucket, you get some copy/paste Powershell commands asking you to download the runner zip and another command for starting it up. Do all but the last command, and make sure the root of the build directory, unzipped, lives here:

    C:\build-runner\atlassian-bitbucket-pipelines-runner

We want to create a Windows Service to run this thing, so let's put the entry point inside `C:\build-runner\www-build-runner-entrypoint.ps1`. Use the following for the contents of that file, replacing that last commented-out section with the `.\start.ps1 ...` string that Bitbucket gave you:


```powershell
cd C:\build-runner\atlassian-bitbucket-pipelines-runner\bin

# TODO: This is where you paste the start.ps1 command from the Bitbucket UI (the one that starts with .\start.ps1 and contains all the runner command line parameters)
```

And now we can install that as a Windows Service and start it up.

```powershell
nssm install WwwBitbucketPipelinesRunner (Get-Command powershell).Source
nssm set WwwBitbucketPipelinesRunner AppParameters C:\build-runner\www-build-runner-entrypoint.ps1
nssm set WwwBitbucketPipelinesRunner DisplayName "WWW Bitbucket Pipelines Runner"
nssm set WwwBitbucketPipelinesRunner Description "Windows runner for Bitbucket Pipelines (Used for Wolverine World Wide builds)"
nssm set WwwBitbucketPipelinesRunner Start SERVICE_DELAYED_AUTO_START
nssm set WwwBitbucketPipelinesRunner AppExit Default Restart
nssm set WwwBitbucketPipelinesRunner AppRestartDelay 0
nssm start WwwBitbucketPipelinesRunner

```

Now you can set up the build runner in the Bitbucket admin. The lousy instructions are for testing in the current console. In reality, we'll eventually use NSSM to set it up as a server. _TODO: Chad to provide more info_


