; ============================================================================
;  Inno Setup script of the Windows installer.
;
;  This script installs the standalone application, the plugin formats and the
;  plugin's standalone application from a
;  staging directory that packaging\windows\build_installer.ps1 populates from
;  the CMake build tree. All product naming (name, slug, company, URL,
;  description) is inherited from CMakeLists.txt and passed in as defines by
;  that helper, so nothing is duplicated here. The helper also passes the
;  staging path and the Have* defines (one per format that was actually built):
;
;    iscc packaging\windows\installer.iss ^
;         /DMyAppId=<guid> ^
;         /DMyAppName="<product name>" /DMyAppSlug=<product-name> ^
;         /DMyCompany="<company>" /DMyAppURL=<url> /DMyAppDescription="<text>" ^
;         /DMyAppExeName="<app product name>" /DMyPluginName="<plugin product name>" ^
;         /DMyAppVersion=1.0.0 ^
;         /DStageDir=C:\path\to\dist\win-stage ^
;         /DOutputDir=C:\path\to\dist ^
;         /DIconFile=C:\path\to\assets\app-icon.ico ^
;         /DHaveApp=1 /DHaveVst3=1 /DHaveClap=1 /DHaveLv2=1 /DHaveAax=1 /DHaveStandalone=1
;
;  Run it through packaging\windows\build_installer.ps1 rather than by hand.
; ============================================================================

; Everything below comes from CMakeLists.txt via build_installer.ps1 - never
; hardcode a fallback here, or the two would drift apart.
#ifndef MyAppId
  #error MyAppId is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyAppName
  #error MyAppName is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyAppSlug
  #error MyAppSlug is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyAppVersion
  #error MyAppVersion is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyCompany
  #error MyCompany is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyAppURL
  #error MyAppURL is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyAppDescription
  #error MyAppDescription is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyAppExeName
  #error MyAppExeName is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef MyPluginName
  #error MyPluginName is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef StageDir
  #error StageDir is not defined - run packaging\windows\build_installer.ps1
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif
#ifndef IconFile
  #define IconFile "..\..\assets\app-icon.ico"
#endif

[Setup]
AppId={#MyAppId}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyCompany}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppComments={#MyAppDescription}
VersionInfoDescription={#MyAppDescription}
DefaultDirName={autopf}\{#MyCompany}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#MyAppSlug}-{#MyAppVersion}-windows-x64
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
SetupIconFile={#IconFile}
WizardStyle=modern

[Types]
Name: "full"; Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
#ifdef HaveApp
Name: "app";        Description: "{#MyAppExeName} application";     Types: full custom
#endif
#ifdef HaveVst3
Name: "vst3";       Description: "VST3 plugin";            Types: full custom
#endif
#ifdef HaveClap
Name: "clap";       Description: "CLAP plugin";            Types: full custom
#endif
#ifdef HaveLv2
Name: "lv2";        Description: "LV2 plugin";             Types: full custom
#endif
#ifdef HaveAax
Name: "aax";        Description: "AAX plugin";             Types: full custom
#endif
#ifdef HaveStandalone
Name: "standalone"; Description: "{#MyPluginName} standalone application"; Types: full custom
#endif

[Files]
#ifdef HaveApp
Source: "{#StageDir}\App\*"; DestDir: "{app}"; \
    Flags: ignoreversion; Components: app
#endif
#ifdef HaveVst3
; VST3 is a single "<name>.vst3" DLL (or a bundle folder); install it into the
; shared VST3 directory read by every host.
Source: "{#StageDir}\VST3\*"; DestDir: "{commoncf64}\VST3"; \
    Flags: recursesubdirs createallsubdirs ignoreversion; Components: vst3
#endif
#ifdef HaveClap
Source: "{#StageDir}\CLAP\*"; DestDir: "{commoncf64}\CLAP"; \
    Flags: ignoreversion; Components: clap
#endif
#ifdef HaveLv2
Source: "{#StageDir}\LV2\*"; DestDir: "{commoncf64}\LV2"; \
    Flags: recursesubdirs createallsubdirs ignoreversion; Components: lv2
#endif
#ifdef HaveAax
; AAX is a "<name>.aaxplugin" bundle folder installed into the Avid plug-ins
; directory read by Pro Tools.
Source: "{#StageDir}\AAX\*"; DestDir: "{commoncf64}\Avid\Audio\Plug-Ins"; \
    Flags: recursesubdirs createallsubdirs ignoreversion; Components: aax
#endif
#ifdef HaveStandalone
Source: "{#StageDir}\Standalone\*"; DestDir: "{app}"; \
    Flags: ignoreversion; Components: standalone
#endif

[Icons]
#ifdef HaveApp
Name: "{group}\{#MyAppExeName}"; Filename: "{app}\{#MyAppExeName}.exe"; Components: app
#endif
#ifdef HaveStandalone
Name: "{group}\{#MyPluginName}"; Filename: "{app}\{#MyPluginName}.exe"; Components: standalone
#endif
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"

[Run]
#ifdef HaveApp
Filename: "{app}\{#MyAppExeName}.exe"; Description: "Launch {#MyAppExeName}"; \
    Flags: nowait postinstall skipifsilent unchecked; Components: app
#endif
#ifdef HaveStandalone
Filename: "{app}\{#MyPluginName}.exe"; Description: "Launch {#MyPluginName}"; \
    Flags: nowait postinstall skipifsilent unchecked; Components: standalone
#endif
