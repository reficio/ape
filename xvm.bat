@echo off
setlocal enableextensions enabledelayedexpansion

:SETUP
set APE_VERSION=master

set SCRIPT_PATH=%~dpnx0
set SCRIPT_PATH=%SCRIPT_PATH:\=/%
set APE_HOME=%USERPROFILE%/.ape
set APE_HOME=%APE_HOME:\=/%
set PERL_HOME=%APE_HOME%/perl
set PERL_EXEC=%PERL_HOME%/perl/bin/perl.exe

set DOWNLOADS=%APE_HOME%/downloads
set USER_AGENT=Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)

rem source:
set SRC=%DOWNLOADS%\%APE_VERSION%.zip
set SRC_URL=https://github.com/reficio/ape/archive/%APE_VERSION%.zip
set SRC_HOME=%APE_HOME%\source

rem scripts:
set DOWNLOADER=%DOWNLOADS%/download.vbs
set WGET=%DOWNLOADS%/wget.exe
set UNZIPPER=%DOWNLOADS%/unzip.exe
set PERL_ZIP=%DOWNLOADS%/perl.zip

rem to-download:
set WGET_URL=http://users.ugent.be/~bpuype/wget/wget.exe
set UNZIP_URL=http://stahlworks.com/dev/unzip.exe
set PERL_URL=http://strawberryperl.com/download/5.18.1.1/strawberry-perl-5.18.1.1-32bit.zip
set LOG_FILE=ape.log

:CONSTANTS
rem there have to be TWO EMPTY LINES after this declaration!!!
rem -----------------------------------------------------------
set N=^


rem -----------------------------------------------------------
	
:CHECKFORSWITCHES
IF '%1'=='/h' GOTO USAGE 
IF '%1'=='/?' GOTO USAGE
if '%1'=='/install' GOTO INSTALL
IF '%1'=='/uninstall' GOTO UNINSTALL
IF '%1'=='/64' GOTO VERSION64
IF '%1'=='/nocache' GOTO NOCACHE
IF '%1'=='/user-agent' GOTO AGENT
IF '%1'=='/proxy' GOTO PROXY
IF '%1'=='' (GOTO BEGIN) ELSE (GOTO BADSYNTAX)
REM Done checking command line for switches
GOTO BEGIN

	:VERSION64
	SET CYGWIN_VERSION=x86_64
	SHIFT
	GOTO CHECKFORSWITCHES

	:NOCACHE
	SET NOCACHE=true
	SHIFT
	GOTO CHECKFORSWITCHES

	:PROXY
	set line=%2
		set i=0
		rem fetch proxy tokens to an array
		:PROXYTOKEN
		for /f "tokens=1* delims=:" %%a in ("!line!") do (		
			set array[!i!]=%%a
			set /A i+=1	
			set line=%%b
			if not "%line%" == "" goto :PROXYTOKEN
		)
		rem parse and validate proxy tokens
		if [%array[0]%] NEQ  [] (
			if [%array[1]%] == [] (GOTO :BADSYNTAX)
			set PROXY=%array[0]%:%array[1]%
			set PROXY_HOST=%array[0]%
			set PROXY_PORT=%array[1]%
		)
		if [%array[2]%] NEQ  [] (
			if [%array[3]%] == [] (GOTO :BADSYNTAX)
			set PROXY_USER=%array[2]%
			set PROXY_PASS=%array[3]%
		)
	SHIFT
	SHIFT
	GOTO CHECKFORSWITCHES
	
	:AGENT
	set USER_AGENT=%~2
	SHIFT
	SHIFT	
	GOTO CHECKFORSWITCHES
		
:BEGIN

:INSTALL
if %ERRORLEVEL% NEQ 0 (GOTO ERROR)	
ECHO [ape] Installing ape version [%APE_VERSION%]

if not exist "%APE_HOME%" (mkdir "%APE_HOME%" || goto :ERROR)
if not exist "%DOWNLOADS%" (mkdir "%DOWNLOADS%" || goto :ERROR)
if not exist "%PERL_HOME%" (mkdir "%PERL_HOME%" || goto :ERROR)


if '%NOCACHE%'=='true' (
 	ECHO [ape] Forcing download as /nocache switch specified
 	del /F /Q "%DOWNLOADS%\*.*" || goto :ERROR
)

rem ---------------------------------
rem EMBEEDED VBS TRICK - DOWNLOAD.VBS
rem ---------------------------------
set DOWNLOAD_VBS=^
	strLink = Wscript.Arguments(0)!N!^
	strSaveName = Mid(strLink, InStrRev(strLink,"/") + 1, Len(strLink)) !N!^
	strSaveTo = Wscript.Arguments(1) ^& "\" ^& strSaveName !N!^
	WScript.StdOut.Write "[ape] Downloading " ^& strLink ^& " "!N!^
	Set objHTTP = Nothing !N!^
	If ((WScript.Arguments.Count ^>= 4) And (Len(WScript.Arguments(3)) ^> 0)) Then !N!^
		Set objHTTP = CreateObject("Msxml2.ServerXMLHTTP.6.0") !N!^
	Else !N!^
		Set objHTTP = CreateObject("Msxml2.ServerXMLHTTP.3.0") !N!^
	End If !N!^
	objHTTP.setTimeouts 120000, 120000, 120000, 120000 !N!^
	objHTTP.open "GET", strLink, False !N!^
	If (Len(WScript.Arguments(2)) ^> 0) Then!N!^
	  objHTTP.setRequestHeader "User-Agent", Wscript.Arguments(2) !N!^
	End If !N!^
	If ((WScript.Arguments.Count ^>= 4) And (Len(WScript.Arguments(3)) ^> 0)) Then !N!^
		objHTTP.setProxy 2, Wscript.Arguments(3), "" !N!^
	End If!N!^
	If ((WScript.Arguments.Count = 6) And (Len(WScript.Arguments(3)) ^> 0)) Then !N!^
		If ((Len(WScript.Arguments(4)) ^> 0) And (Len(WScript.Arguments(5)) ^> 0)) Then !N!^
			objHTTP.setProxyCredentials Wscript.Arguments(4), Wscript.Arguments(5) !N!^
		End If!N!^
	End If!N!^
	objHTTP.send!N!^
	Set objFSO = CreateObject("Scripting.FileSystemObject")!N!^
	If objFSO.FileExists(strSaveTo) Then!N!^
	  objFSO.DeleteFile(strSaveTo)!N!^
	End If!N!^
	If objHTTP.Status = 200 Then!N!^
	  Dim objStream!N!^
	  Set objStream = CreateObject("ADODB.Stream")!N!^
	  With objStream!N!^
		.Type = 1 'adTypeBinary!N!^
		.Open!N!^
		.Write objHTTP.responseBody!N!^
		.SaveToFile strSaveTo!N!^
		.Close!N!^
	  End With!N!^
	  set objStream = Nothing!N!^
	End If!N!^
	If objFSO.FileExists(strSaveTo) Then!N!^
	  WScript.Echo "[OK]" !N!^
	Else !N!^
		WScript.Echo "[FAILED]" !N!^
	End If
		
echo !DOWNLOAD_VBS! > "%DOWNLOADER%" || goto :ERROR

:: download wget.exe
if not exist "%WGET%" (
	cscript //Nologo "%DOWNLOADER%" "%WGET_URL%" "%DOWNLOADS%" "%USER_AGENT%" "%PROXY%" "%PROXY_USER%" "%PROXY_PASS%"
	if not exist "%WGET%" (GOTO ERROR)
)
	
:: download unzip.exe
if not exist "%UNZIPPER%" (
	cscript //Nologo "%DOWNLOADER%" "%UNZIP_URL%" "%DOWNLOADS%" "%USER_AGENT%" "%PROXY%" "%PROXY_USER%" "%PROXY_PASS%"
	if not exist "%UNZIPPER%" (GOTO ERROR)
)

:: download compressed perl binaries
if not exist "%PERL_ZIP%" (
	%WGET% --no-check-certificate "%PERL_URL%" -O "%PERL_ZIP%" -U "%USER_AGENT%"
	if not exist "%PERL_ZIP%" (GOTO ERROR)
)

:: unzip perl binaries
if not exist "%PERL_EXEC%" (
	ECHO [ape] Extracting perl
	"%UNZIPPER%" -q -o "%PERL_ZIP%" -d "%PERL_HOME%" > %LOG_FILE%
)
if not exist "%PERL_EXEC%" (GOTO ERROR)

:: check if perl works
ECHO [ape] Checking if perl works
"%PERL_EXEC%" --version > %LOG_FILE% || goto :ERROR
	
:: download ape perl sources
if not exist "%SRC%" (
	echo [ape] Downloading ape sources
	cscript //Nologo "%DOWNLOADER%" "%SRC_URL%" "%DOWNLOADS%" "%USER_AGENT%" "%PROXY%" "%PROXY_USER%" "%PROXY_PASS%"
	if not exist "%SRC%" (GOTO ERROR)
)

if exist "%SRC_HOME%" (
	RD /S /Q "%SRC_HOME%" || goto :ERROR
)
mkdir "%SRC_HOME%"

ECHO [ape] Extracting ape source
"%UNZIPPER%" -o "%SRC%" -d "%SRC_HOME%" > %LOG_FILE%
if not exist "%SRC_HOME%/*.*" (GOTO ERROR)
	

"%PERL_EXEC%" "%SRC_HOME%\ape-%APE_VERSION%\ape.pl"
	
:: --------------------------------------------------------------------------
rem ECHO [babun] Setting path
rem cscript //Nologo "%PATH_SETTER%" "%SRC_HOME%\babun-%BABUN_VERSION%"

:RUN
ECHO [ape] Starting ape

GOTO END

:UNINSTALL
ECHO [ape] Uninstalling...
if not exist "%APE_HOME%" (
	echo [ape] Not installed
	GOTO END
) 
if exist "%PATHUNSETTER%" (
	echo [ape] Removing path...
	cscript //Nologo "%PATH_UNSETTER%" "%SRC_HOME%\babun-%BABUN_VERSION%" || goto :ERROR
)
echo [ape] Deleting files...
RD /S /Q "%APE_HOME%" || goto :ERROR
if exist "%USERPROFILE%\Desktop\babun.lnk" (
  del "%USERPROFILE%\Desktop\babun.lnk" || goto :ERROR
)
GOTO END

:BADSYNTAX
ECHO Usage: ape.bat [/h] [/nocache] [/proxy=host:port[:user:pass]] [/64] [/uninstall]
GOTO END

:USAGE
ECHO.
ECHO    Syntax:
ECHO		ape	[/h] [/?] [/64] [/nocache] [/install] [/uninstall]
ECHO			[/proxy=host:port[:user:pass]] [/user-agent=agent-string]  !N!
ECHO    Default behavior if no option passed:
ECHO   	* install -^> if babun IS NOT installed
ECHO   	* start -^> if babun IS installed
ECHO.
ECHO    Options:
ECHO 	'/?' or '/h' 	Displays the help text
ECHO 	'/nocache'	Forces download even if files are downloaded
ECHO 	'/64'		Marks to download the 64-bit version of Cygwin (NOT RECOMMENDED) 
ECHO 	'/install'	Installs babun; forces the reinstallation even if already installed  
ECHO 	'/uninstall'	Uninstalls babun; option is exclusive, others are ignored  
ECHO 	'/user-agent=agent-string'	Identify as agent-string to the http server
ECHO 	'/proxy=host:port[user:pass]'	Enables HTTP proxy host:port 
ECHO.
ECHO    For example: 
ECHO 	ape /? 
ECHO 	ape /nocache /proxy=test.com:80 /install 
ECHO 	ape /install /user-agent="Mozilla/5.0 (Windows NT 6.1; rv:6.0)" 
ECHO.
GOTO END

:ERROR
ECHO [ape] Terminating due to ERROR #%errorlevel%
EXIT /b %errorlevel%

:END
