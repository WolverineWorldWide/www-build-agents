# WWW Build Agents

## Bitbucket Windows Runners

_Note: This is an ongoing experiment into making this as repeatable as possible. Yes, I know that Powershell DSC (Desired State Configuration) exists and is awesome, but I was too inexperienced at the time and so reverted back to the old fashioned way. Here are my notes:_

### Visual Studio Project/Solution Prerequisites

If any projects are targeting .Net Framework 4.5, you'll need to upgrade them to reference 4.5.2. See commit af44b10a6aba7c20848d2d47c24b63c4394c0ed3. I have been [led to believe](https://developercommunity.visualstudio.com/t/the-reference-assemblies-for-netframeworkversionv4-1/1660771) that the 4.5 target simply isn't a thing that can be supported, and that we must upgrade to 4.5.2. We'll see what happens when we actually try to run the applications.

### Nuget Prerequisites

Some of these Wolverine projects require some legacy nuget packages from old CQL days. These projects are more or less abandoned, so we are including the compiled nuget packages directly in whatever projects need them, moving forward. Basically, I have omitted `nuget.cqlcorp.local` on the temp build server via the hosts file (this is while testing at CQL; you don't need to do this if you're working on a permanent Azure server), and then run the build, find out what `Cql*` packages it fails to find, then pull them down from within CQL's VPN so and put them in `legacy-cql-nuget-packages` folder in the root of the repository, and change/add the `nuget.cqlcorp.local` reference in the repo's root `NuGet.config` file to point to `./legacy-cql-nuget-packages` (under `/configuration/packageSoures`).

### Build Server Setup

All this setup stuff should be performed in Powershell as an Administrator

```powershell
Set-ExecutionPolicy RemoteSigned

# Install Chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Prerequisites for Windows Runners
choco install -y git
choco install -y git-lfs.install
choco install -y openjdk11
choco install -y dotnetfx --pre

# Some nuget (old nuget.exe) things were still failing until we forced the LongPathsEnabled registry setting, so yes, we still need to do this
New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
git config --system core.longpaths true

# Used to ease installation of build agent runner as Windows Service
choco install -y nssm

# Needed for WWW Builds
choco install -y nvs
choco install -y nuget.commandline
choco install -y visualstudio2019buildtools
choco install -y visualstudio2019testagent
choco install -y netfx-4.5.1-devpack
choco install -y netfx-4.5.2-devpack
choco install -y netfx-4.6.1-devpack
choco install -y netfx-4.6.2-devpack
choco install -y webdeploy

# Optional sql server for WWW PIM Tests
choco install -y sql-server-2019
choco install -y sql-server-management-studio
```

NOTE: For PIM db tests to run, you need to install the MS Access Redistributable from [here](https://www.microsoft.com/en-us/download/confirmation.aspx?id=13255). I tried the choco version (made2010) but it did not work, so I did this with the old school installer and it worked.

Please make sure you restart before installing a runner. Chocolatey mentions to run `refreshenv` but neglects to inform you it won't work as expected in Powershell.

There are some old timey Visual Studio files we have to manually place on the server. See the
`Web` and `WebApplication` directories in this repo at `resources/VisualStudioTargets/` and copy the folders to the server at:

```
C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Microsoft\VisualStudio\v16.0\
```

_NOTE: You will need to do the above for each version of msbuild you have on the server. Be mindful of the `v16.0` which changes per msbuild version!_

There are some common build tools in the `common` folder. Put that in the `c:\build-runner\common` directory on the build server, and make sure you change to the correct password (find/replace PASSWORD). This is how dev deployments will be able to stop and start the job scheduler.

It is best to make an alias for build/test tools with version intact, so let's maintain a file at `$PSHOME\profile.ps1` with the following contents (add more to this as needed):

```powershell
# These aliases will be available to any job. Add more as needed.
Set-Alias -Scope Global -Name msbuild2019 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\msbuild.exe"
Set-Alias -Scope Global -Name vstest2019 -Value "C:\Program Files (x86)\Microsoft Visual Studio\2019\TestAgent\Common7\IDE\Extensions\TestPlatform\vstest.console.exe"

$env:PATH = 'c:\build-runner\common;' + $env:PATH

# Explicitly set the nuget package cache when running as LocalSystem account because sometimes it gets confused between 32 and 64 bit environments
$env:NUGET_PACKAGES="C:\build-runner\nuget-package-cache"
```
Now you can set up the build runner in the Bitbucket admin!

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

