toolset="clang++-14"
toolset_cc="clang-14"
generator="Unix Makefiles"
with_essential_client_modules=1
with_common_modules=1
with_pfm=0
with_core_pfm_modules=1
with_all_pfm_modules=0
with_vr=0
modules=0
build=1

arg_to_bool () {
    if [ "$1" = true ] || [ "$1" = "TRUE" ] || [ "$1" = 1 ] || [ "$1" = "on" ] || [ "$1" = "ON" ] || [ "$1" = "enabled" ] || [ "$1" = "ENABLED" ]; then
        return 1
    else
        return 0
    fi
}

print_hmsg () {
    GREEN='\033[0;32m'
    NC='\033[0m' # No Color
    printf "${GREEN}$1${NC}\n"
}

for i in "$@"; do
  case $i in
    -t=*|--toolset=*)
      toolset="${i#*=}"
      shift # past argument=value
      ;;
    -c=*|--toolset_cc=*)
      toolset_cc="${i#*=}"
      shift # past argument=value
      ;;
    -g=*|--generator=*)
      arg_to_bool "${i#*=}"
      generator=$?
      shift # past argument=value
      ;;
    --with_essential_client_modules=*)
      arg_to_bool "${i#*=}"
      with_essential_client_modules=$?
      shift # past argument=value
      ;;
    --with_essential_client_modules)
      with_essential_client_modules=1
      shift # past argument with no value
      ;;
    --with_common_modules=*)
      arg_to_bool "${i#*=}"
      with_common_modules=$?
      shift # past argument=value
      ;;
    --with_common_modules)
      with_common_modules=1
      shift # past argument with no value
      ;;
    --with_pfm=*)
      arg_to_bool "${i#*=}"
      with_pfm=$?
      shift # past argument=value
      ;;
    --with_pfm)
      with_pfm=1
      shift # past argument with no value
      ;;
    --with_core_pfm_modules=*)
      arg_to_bool "${i#*=}"
      with_core_pfm_modules=$?
      shift # past argument=value
      ;;
    --with_core_pfm_modules)
      with_core_pfm_modules=1
      shift # past argument with no value
      ;;
    --with_all_pfm_modules=*)
      arg_to_bool "${i#*=}"
      with_all_pfm_modules=$?
      shift # past argument=value
      ;;
    --with_all_pfm_modules)
      with_all_pfm_modules=1
      shift # past argument with no value
      ;;
    --with_vr=*)
      arg_to_bool "${i#*=}"
      with_vr=$?
      shift # past argument=value
      ;;
    --with_vr)
      with_vr=1
      shift # past argument with no value
      ;;
    --modules=*)
      modules="${i#*=}"
      shift # past argument=value
      ;;
    -*|--*)
      echo "Unknown option $i"
      exit 1
      ;;
    *)
      ;;
  esac
done

strindex() { 
  x="${1%%"$2"*}"
  [[ "$x" = "$1" ]] && return -1 || return "${#x}"
}

validate_result() {
    resultCode=$?
    if [ ! $resultCode -eq 0 ]; then
        RED='\033[0;31m'
        NC='\033[0m' # No Color
        printf "${RED}Critical failure detected, execution will halt!${NC}\n"
        exit 1
    fi
}

# Linux
export CC="$toolset_cc"
export CXX="$toolset"
#

buildConfig="RelWithDebInfo"
root="$PWD"

if [ ! -d "$PWD/deps" ]; then
	mkdir deps
fi

cd deps

deps="$PWD"
# Get zlib
zlibRoot="$PWD/zlib-1.2.8"
if [ ! -d "$zlibRoot" ]; then
	echo "zlib not found. Downloading..."
	git clone https://github.com/fmrico/zlib-1.2.8.git
	echo "Done!"
fi

cd zlib-1.2.8

# Build zlib
echo "Building zlib..."
if [ ! -d "$PWD/build" ]; then
	mkdir build
fi
cd build
cmake .. -G "$generator"
cmake --build "." --config "$buildConfig"
cp zconf.h ../
cd ../..
echo "Done!"

if [ ! -d "$PWD/boost_1_78_0" ]; then
	echo "boost not found. Downloading..."
	wget https://boostorg.jfrog.io/artifactory/main/release/1.78.0/source/boost_1_78_0.zip
	echo "Done!"

	# Extract Boost
	echo "Extracting boost..."
	7z x "$PWD/boost_1_78_0.zip"

	rm boost_1_78_0.zip
	echo "Done!"
fi

cd boost_1_78_0

# Build Boost
echo "Building boost..."
./bootstrap.sh
./b2 address-model=64 stage variant=release link=shared runtime-link=shared -j3
./b2 address-model=64 stage variant=release link=static runtime-link=shared -j3
echo "Done!"

ZLIB_SOURCE="$PWD/../zlib-1.2.8"
ZLIB_INCLUDE="$PWD/../zlib-1.2.8"
ZLIB_LIBPATH="$PWD/../zlib-1.2.8/build"
echo "Building boost zlib libraries..."
./b2 address-model=64 stage variant=release link=shared runtime-link=shared --with-iostreams -sZLIB_SOURCE="$ZLIB_SOURCE" -sZLIB_INCLUDE="$ZLIB_INCLUDE" -sZLIB_LIBPATH="$ZLIB_LIBPATH"
./b2 address-model=64 stage variant=release link=static runtime-link=shared --with-iostreams -sZLIB_SOURCE="$ZLIB_SOURCE" -sZLIB_INCLUDE="$ZLIB_INCLUDE" -sZLIB_LIBPATH="$ZLIB_LIBPATH"
cd ../
echo "Done!"

cd ../

# Build LuaJIT
echo "Building LuaJIT..."
cd third_party_libs/luajit/src
make
cd ../../../
echo "Done!"

# Download GeometricTools
echo "Downloading GeometricTools..."
cd deps
git clone https://github.com/davideberly/GeometricTools
cd GeometricTools
git reset --hard bd7a27d18ac9f31641b4e1246764fe30816fae74
cd ../../
echo "Done!"

# Download SPIRV-Tools
echo "Downloading SPIRV-Tools..."
cd deps
git clone https://github.com/KhronosGroup/SPIRV-Tools.git
cd SPIRV-Tools
git reset --hard 7826e19
cd ../../
echo "Done!"

# Download SPIRV-Headers
echo "Downloading SPIRV-Headers..."
cd deps
cd SPIRV-Tools/external
git clone https://github.com/KhronosGroup/SPIRV-Headers
cd SPIRV-Headers
git reset --hard 85a1ed2
cd ../../
cd ../../
echo "Done!"

# Download modules
echo "Downloading modules..."
cd modules

# TODO: Allow defining custom modules via arguments
modules=()
if [ $with_essential_client_modules -eq 1 ]; then
    modules+=( "pr_prosper_vulkan:\"https://github.com/Silverlan/pr_prosper_vulkan.git\"" )
fi

if [ $with_common_modules -eq 1 ]; then
	modules+=( "pr_bullet:\"https://github.com/Silverlan/pr_bullet.git\"" )
	modules+=( "pr_audio_soloud:\"https://github.com/Silverlan/pr_soloud.git\"" )
fi

if [ $with_pfm -eq 1 ]; then
	if [ $with_core_pfm_modules -eq 1 ] || [ $with_all_pfm_modules -eq 1 ]; then
		modules+=( "pr_curl:https://github.com/Silverlan/pr_curl.git" )
		modules+=( "pr_dmx:https://github.com/Silverlan/pr_dmx.git" )
	fi
	if [ $with_all_pfm_modules -eq 1 ]; then
		modules+=( "pr_chromium:https://github.com/Silverlan/pr_chromium.git" )
		modules+=( "pr_unirender:https://github.com/Silverlan/pr_cycles.git" )
		modules+=( "pr_curl:https://github.com/Silverlan/pr_curl.git" )
		modules+=( "pr_dmx:https://github.com/Silverlan/pr_dmx.git" )
		modules+=( "pr_xatlas:https://github.com/Silverlan/pr_xatlas.git" )
	fi
fi

if [ $with_vr -eq 1 ]; then
	modules+=( "pr_openvr:https://github.com/Silverlan/pr_openvr.git" )
fi

moduleList=""
cmakeArgs=""
for module in "${modules[@]}"
do
    strindex "$module" ":"
    index=$?
    moduleName=${module:0:$index}
    moduleUrl=${module:$index +1:${#module}}
    moduleDir="$PWD/$moduleName/"

    # Remove quotes
    moduleUrl=$(echo "$moduleUrl" | sed "s/\"//g")

    if [ ! -d "$moduleDir" ]; then
		echo "Downloading module '$moduleName'..."
		git clone "$moduleUrl" --recurse-submodules $moduleName
		echo "Done!"
    else
		echo "Updating module '$moduleName'..."
		git pull
		echo "Done!"
	fi

    if [ -f "$moduleDir/build_scripts/setup_linux.sh" ]; then
		echo "Executing module setup script..."
		curDir=$PWD
        source "$PWD/$moduleName/build_scripts/setup_linux.sh"
		cd $curDir
		echo "Done!"
	fi

	moduleList="$moduleList $moduleName"
done

cd ..
echo "Done!"

# Configure
echo "Configuring Pragma..."
if [ ! -d "$PWD/build" ]; then
	mkdir build
fi
rootDir=$PWD
cd build
installDir="$PWD/install"
echo "Additional CMake args: $cmakeArgs"

cmake .. -G "$generator" \
	-DDEPENDENCY_BOOST_INCLUDE="$rootDir/deps/boost_1_78_0" \
	-DDEPENDENCY_BOOST_LIBRARY_LOCATION="$rootDir/deps/boost_1_78_0/stage/lib" \
	-DDEPENDENCY_BOOST_CHRONO_LIBRARY="$rootDir/deps/boost_1_78_0/stage/lib/boost_chrono.a" \
	-DDEPENDENCY_BOOST_DATE_TIME_LIBRARY="$rootDir/deps/boost_1_78_0/stage/lib/boost_date_time.a" \
	-DDEPENDENCY_BOOST_REGEX_LIBRARY="$rootDir/deps/boost_1_78_0/stage/lib/boost_regex.a" \
	-DDEPENDENCY_BOOST_SYSTEM_LIBRARY="$rootDir/deps/boost_1_78_0/stage/lib/boost_system.a" \
	-DDEPENDENCY_BOOST_THREAD_LIBRARY="$rootDir/deps/boost_1_78_0/stage/lib/boost_thread.a" \
	-DDEPENDENCY_GEOMETRIC_TOOLS_INCLUDE="$rootDir/deps/GeometricTools/GTE" \
	-DDEPENDENCY_LIBZIP_CONF_INCLUDE="$rootDir/build/third_party_libs/libzip" \
	-DCMAKE_INSTALL_PREFIX:PATH="$installDir" \
    -DDEPENDENCY_SPIRV_TOOLS_DIR="$deps/SPIRV-Tools" \
    -DDEPENDENCY_VULKAN_LIBRARY="/lib/x86_64-linux-gnu/libvulkan.so"

print_hmsg "Done!"

print_hmsg "Build files have been written to \"$PWD/build\"."

curDir="$PWD"
if [ $with_pfm -eq 1 ]; then
	print_hmsg "Downloading PFM addon..."
  mkdir -p "$installDir/addons"
	cd "$installDir/addons"
  if [ ! -d "$installDir/addons/pfm" ]; then
		git clone "https://github.com/Silverlan/pfm.git"
		validate_result
  else
		print_hmsg "Updating PFM..."
		git pull
		validate_result
  fi
	print_hmsg "Done!"
fi

if [ $with_vr -eq 1 ]; then
	print_hmsg "Downloading VR addon..."
  mkdir -p "$installDir/addons"
	cd "$installDir/addons"
  if [ ! -d "$installDir/addons/virtual_reality" ]; then
		git clone "https://github.com/Silverlan/PragmaVR.git" virtual_reality
		validate_result
  else
		print_hmsg "Updating VR..."
		git pull
		validate_result
  fi
	print_hmsg "Done!"
fi
cd $curDir

if [ $build -eq 1 ]; then
	print_hmsg "Building Pragma..."
	targets="pragma-install-full $moduleList"
	if [ $with_pfm -eq 1 ]; then
	  targets="$targets pfm"
	fi
	targets="$targets pragma-install"

	cmakeBuild="cmake --build \".\" --config \"$buildConfig\" --target $targets"
	echo "Running build command:"
	echo "$cmakeBuild"
  eval "$cmakeBuild"
	validate_result

	print_hmsg "Build Successful! Pragma has been installed to \"$installDir\"."
	print_hmsg "If you make any changes to the core source code, you can build the \"pragma-install\" target to compile the changes and re-install the binaries automatically."
	print_hmsg "If you make any changes to a module, you will have to build the module target first, and then build \"pragma-install\"."
	print_hmsg ""
fi


# cmake --build "." --config $buildConfig --target pragma-install-full
# cmake --build "." --config "RelWithDebInfo" --target pragma-install-full

#if($false){
#if(![System.IO.Directory]::Exists("$pwd/deps")){
#	mkdir deps
#}
#cd deps

