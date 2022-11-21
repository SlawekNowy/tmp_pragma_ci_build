param (
    [string]$toolset = "msvc-14.2",
    [string]$generator = "Visual Studio 17 2022",
    [string]$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat",
    [switch]$with_essential_client_modules = $true,
    [switch]$with_common_modules = $true,
    [switch]$with_pfm = $false,
    [switch]$with_core_pfm_modules = $true,
    [switch]$with_all_pfm_modules = $false,
    [switch]$with_vr = $false,
    [switch]$build = $true,
    [string]$build_directory = "build",
    [string]$deps_directory = "deps",
    [switch]$help = $false,
    [string[]]$modules = @()
)

$ErrorActionPreference="Stop"

Function display_help() {
    Write-Host "This script will download and setup all of the required dependencies for building Pragma."
    Write-Host "Usage: ./build_scripts/build_windows.ps1 [option...]"
    Write-Host ""

    Write-Host "   -toolset                          The toolset to use. Default: " -NoNewline
    Write-Host "`"msvc-14.2`""

    Write-Host "   -generator                        The generator to use. Default: " -NoNewline
    Write-Host "`"Visual Studio 17 2022`""

    Write-Host "   -vcvars                           Path to vcvars64.bat. Default: " -NoNewline
    Write-Host "`"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat`""

    Write-Host "   -with_essential_client_modules    Include essential modules required to run Pragma. Default: " -NoNewline
    Write-Host "true" -ForegroundColor Green

    Write-Host "   -with_common_modules              Include non-essential but commonly used modules (e.g. audio and physics modules). Default: " -NoNewline
    Write-Host "true" -ForegroundColor Green

    Write-Host "   -with_pfm                         Include the Pragma Filmmaker. Default: " -NoNewline
    Write-Host "false" -ForegroundColor Red

    Write-Host "   -with_core_pfm_modules            Include essential PFM modules. Default: " -NoNewline
    Write-Host "true" -ForegroundColor Green

    Write-Host "   -with_all_pfm_modules             Include non-essential PFM modules (e.g. chromium and cycles). Default: " -NoNewline
    Write-Host "false" -ForegroundColor Red

    Write-Host "   -with_vr                          Include Virtual Reality support. Default: " -NoNewline
    Write-Host "false" -ForegroundColor Red

    Write-Host "   -build                            Build Pragma after configurating and generating build files. Default: " -NoNewline
    Write-Host "true" -ForegroundColor Green

    Write-Host "   -build_directory                  Directory to write the build files to. Default: " -NoNewline
    Write-Host "build"

    Write-Host "   -deps_directory                   Directory to write the dependency files to. Default: " -NoNewline
    Write-Host "deps"

    Write-Host "   -help                             Display this help"
    Write-Host "   -modules                          Custom modules to install. Usage example: " -NoNewLine
    Write-Host "-modules pr_prosper_vulkan:`"https://github.com/Silverlan/pr_prosper_vulkan.git`",pr_bullet:`"https://github.com/Silverlan/pr_bullet.git`"" -ForegroundColor Gray
    Write-Host ""

    Write-Host "Examples:"
    Write-Host "- Build Pragma for Visual Studio 2022:"
    Write-Host "./build_scripts/build_windows.ps1 -toolset `"msvc-14.2`" -generator `"Visual Studio 17 2022`" -vcvars `"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "- Build Pragma with PFM and VR support for Visual Studio 2022:"
    Write-Host "./build_scripts/build_windows.ps1 -with_pfm -with_all_pfm_modules -with_vr -toolset `"msvc-14.2`" -generator `"Visual Studio 17 2022`" -vcvars `"C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat`"" -ForegroundColor Gray
    Exit 1
}

if($help){
    display_help
    Exit 0
}

$buildConfig="RelWithDebInfo"
$root="$PWD"
$buildDir="$build_directory"
$depsDir="$deps_directory"

if(![System.IO.Path]::IsPathRooted("$buildDir")){
    $buildDir="$PWD/$buildDir"
}
if(![System.IO.Path]::IsPathRooted("$depsDir")){
    $depsDir="$PWD/$depsDir"
}

[System.IO.Directory]::CreateDirectory("$buildDir")
[System.IO.Directory]::CreateDirectory("$depsDir")

Function print_hmsg($msg)
{
    Write-Host "$msg" -ForegroundColor Green
}

print_hmsg "Set build dir to `"$buildDir`"."
print_hmsg "Set deps dir to `"$depsDir`"."

Function validate_result()
{
    if (-not $?) {throw "Critical failure detected, execution will halt!"}
}

# Initialize VS env variables
& $PSScriptRoot\Windows\Invoke-Environment 'call "$vcvars"'
validate_result
Write-Host "`nVisual Studio Command Prompt variables set." -ForegroundColor Yellow
#

cd $depsDir

$deps="$depsDir"
# Get zlib
$zlibRoot="$PWD/zlib-1.2.8"
if(![System.IO.Directory]::Exists("$zlibRoot")){
    print_hmsg "zlib not found. Downloading..."
    git clone "https://github.com/fmrico/zlib-1.2.8.git"
    validate_result
    print_hmsg "Done!"
}

cd zlib-1.2.8

# Build zlib
print_hmsg "Building zlib..."
if(![System.IO.Directory]::Exists("$PWD/build")){
    mkdir build
}
cd build
cmake .. -G $generator
validate_result
cmake --build "." --config "$buildConfig"
validate_result
cp zconf.h ../
cd ../..
print_hmsg "Done!"

$boostRoot="$PWD/boost"
if(![System.IO.Directory]::Exists("$boostRoot")){
    print_hmsg "boost not found. Downloading..."
    git clone "https://github.com/ClausKlein/boost-cmake.git" boost
    validate_result
    print_hmsg "Done!"
}

cd boost

# Build Boost
$ZLIB_SOURCE="$PWD/../zlib-1.2.8"
$ZLIB_INCLUDE="$PWD/../zlib-1.2.8"
$ZLIB_LIBPATH="$PWD/../zlib-1.2.8/build/$buildConfig"
print_hmsg "Building boost..."
[System.IO.Directory]::CreateDirectory("$PWD/build")
cd build
cmake .. -G "$generator" -DBOOST_DISABLE_TESTS=ON -DZLIB_INCLUDE_DIR="$ZLIB_INCLUDE" -DZLIB_LIBRARY="$ZLIB_LIBPATH"
validate_result
cmake --build "." --config "Release"
validate_result
print_hmsg "Done!"
cd ../../

cd ../

# Build LuaJIT
print_hmsg "Building LuaJIT..."
cd $deps
[System.IO.Directory]::CreateDirectory("$PWD/luajit_build")
cd luajit_build
cmake ../../third_party_libs/luajit -G "$generator"
validate_result
cmake --build "." --config "Release"
validate_result
$luaJitLib="$PWD/src/Release/luajit.lib"
print_hmsg "Done!"

# Download GeometricTools
cd $deps
$geometricToolsRoot="$PWD/GeometricTools"
if(![System.IO.Directory]::Exists("$geometricToolsRoot")){
    print_hmsg "GeometricTools not found. Downloading..."
    git clone "https://github.com/davideberly/GeometricTools"
    validate_result
}
cd GeometricTools
git reset --hard bd7a27d18ac9f31641b4e1246764fe30816fae74
validate_result
cd ../../
print_hmsg "Done!"
#}
# Download modules
print_hmsg "Downloading modules..."
cd modules

if($with_essential_client_modules) {
    $modules += "pr_prosper_vulkan:`"https://github.com/Silverlan/pr_prosper_vulkan.git`""
}

if($with_common_modules) {
    $modules += "pr_bullet:`"https://github.com/Silverlan/pr_bullet.git`""
    $modules += "pr_audio_soloud:`"https://github.com/Silverlan/pr_soloud.git`""
}

if($with_pfm) {
    if($with_core_pfm_modules -Or $with_all_pfm_modules) {
        $modules += "pr_curl:https://github.com/Silverlan/pr_curl.git"
        $modules += "pr_dmx:https://github.com/Silverlan/pr_dmx.git"
    }
    if($with_all_pfm_modules) {
        $modules += "pr_chromium:https://github.com/Silverlan/pr_chromium.git"
        $modules += "pr_unirender:https://github.com/Silverlan/pr_cycles.git"
        $modules += "pr_curl:https://github.com/Silverlan/pr_curl.git"
        $modules += "pr_dmx:https://github.com/Silverlan/pr_dmx.git"
        $modules += "pr_xatlas:https://github.com/Silverlan/pr_xatlas.git"
    }
}

if($with_vr) {
    $modules += "pr_openvr:https://github.com/Silverlan/pr_openvr.git"
}

$moduleList=""
$global:cmakeArgs=""
foreach ( $module in $modules )
{
    $index=$module.IndexOf(":")
    $components=$module.Split(":")
    $moduleName=$module.SubString(0,$index)
    $moduleUrl=$module.SubString($index +1)
    $moduleDir="$PWD/$moduleName/"
    if(![System.IO.Directory]::Exists("$moduleDir")){
        print_hmsg "Downloading module '$moduleName'..."
        git clone "$moduleUrl" --recurse-submodules $moduleName
        validate_result
        print_hmsg "Done!"
    }
    else{
        print_hmsg "Updating module '$moduleName'..."
        git pull
        validate_result
        print_hmsg "Done!"
    }
    
    if([System.IO.File]::Exists("$moduleDir/build_scripts/setup_windows.ps1")){
        print_hmsg "Executing module setup script..."
        $curDir=$PWD
        & "$PWD/$moduleName/build_scripts/setup_windows.ps1"
        validate_result
        cd $curDir
        print_hmsg "Done!"
    }

    $moduleList += " "
    $moduleList += $moduleName
}

cd ..
print_hmsg "Done!"

#if($false){
# Configure
print_hmsg "Configuring Pragma..."
$rootDir=$PWD
cd $buildDir
$installDir="$PWD/install"
print_hmsg "Additional CMake args: $cmakeArgs"

$cmdCmake="cmake .. -G `"$generator`" ```
    -DDEPENDENCY_BOOST_INCLUDE=`"$boostRoot/build/_deps/boost-src`" ```
    -DDEPENDENCY_BOOST_LIBRARY_LOCATION=`"$boostRoot/build/lib/Release`" ```
    -DDEPENDENCY_BOOST_CHRONO_LIBRARY=`"$boostRoot/build/lib/Release/boost_chrono.lib`" ```
    -DDEPENDENCY_BOOST_DATE_TIME_LIBRARY=`"$boostRoot/build/lib/Release/boost_date_time.lib`" ```
    -DDEPENDENCY_BOOST_REGEX_LIBRARY=`"$boostRoot/build/lib/Release/boost_regex.lib`" ```
    -DDEPENDENCY_BOOST_SYSTEM_LIBRARY=`"$boostRoot/build/lib/Release/boost_system.lib`" ```
    -DDEPENDENCY_BOOST_THREAD_LIBRARY=`"$boostRoot/build/lib/Release/boost_thread.lib`" ```
    -DDEPENDENCY_GEOMETRIC_TOOLS_INCLUDE=`"$depsDir/GeometricTools/GTE`" ```
    -DDEPENDENCY_LIBZIP_CONF_INCLUDE=`"$rootDir/build/third_party_libs/libzip`" ```
    -DDEPENDENCY_LUAJIT_LIBRARY=`"$luaJitLib`" ```
    -DCMAKE_INSTALL_PREFIX:PATH=`"$installDir`" ```
"
$cmdCmake += $global:cmakeArgs

iex $cmdCmake
validate_result

print_hmsg "Done!"

print_hmsg "Build files have been written to \"$buildDir\"."

$curDir=$PWD
if($with_pfm) {
    print_hmsg "Downloading PFM addon..."
    [System.IO.Directory]::CreateDirectory("$installDir/addons")
    cd "$installDir/addons"
    if(![System.IO.Directory]::Exists("$installDir/addons/pfm")){
        git clone "https://github.com/Silverlan/pfm.git"
        validate_result
    } else {
        print_hmsg "Updating PFM..."
        git pull
        validate_result
        print_hmsg "Done!"
    }
    print_hmsg "Done!"
}

if($with_vr) {
    print_hmsg "Downloading VR addon..."
    [System.IO.Directory]::CreateDirectory("$installDir/addons")
    cd "$installDir/addons"
    if(![System.IO.Directory]::Exists("$installDir/addons/virtual_reality")){
        git clone "https://github.com/Silverlan/PragmaVR.git" virtual_reality
        validate_result
    } else {
        print_hmsg "Updating VR..."
        git pull
        validate_result
        print_hmsg "Done!"
    }
    print_hmsg "Done!"
}
cd $curDir

echo "BUILD VALUE: $build"
if($build) {
    print_hmsg "Building Pragma..."
    $targets="pragma-install-full $moduleList"
    if($with_pfm) {
        $targets+=" pfm"
    }
    $targets+=" pragma-install"

    $cmakeBuild="cmake --build `".`" --config `"$buildConfig`" --target $targets"
    echo "Running build command:"
    echo "$cmakeBuild"
    iex $cmakeBuild
    validate_result

    print_hmsg "Build Successful! Pragma has been installed to `"$installDir`"."
    print_hmsg "If you make any changes to the core source code, you can build the `"pragma-install`" target to compile the changes and re-install the binaries automatically."
    print_hmsg "If you make any changes to a module, you will have to build the module target first, and then build `"pragma-install`"."
    print_hmsg ""
}

print_hmsg "All actions have been completed! Please make sure to re-run this script every time you pull any changes from the repository, and after adding any new modules."

cd $root
