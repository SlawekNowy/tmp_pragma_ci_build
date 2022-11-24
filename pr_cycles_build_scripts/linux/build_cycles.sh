
# cycles
cd "$deps"
cyclesRoot="$deps/cycles"
if [ ! -d "$cyclesRoot" ]; then
	print_hmsg "cycles not found. Downloading..."
	git clone git://git.blender.org/cycles.git --recurse-submodules
	validate_result
fi
cd cycles

git reset --hard "b1882be6b1f2e27725ee672d87c5b6f8d6113eb1"
validate_result

print_hmsg "Done!"

print_hmsg "Downloading cycles dependencies..."
make update
validate_result

# Building the cycles executable causes build errors. We don't need it, but unfortunately cycles doesn't provide us with a
# way to disable it, so we'll have to make some changes to the CMake configuration file.
sed -i -e 's/if(WITH_CYCLES_STANDALONE)/if(false)/g' "$cyclesRoot/src/app/CMakeLists.txt"

print_hmsg "Build cycles"
mkdir -p $PWD/build
cd build

cmake .. -G "$generator" -DWITH_CYCLES_CUDA_BINARIES=ON -DWITH_CYCLES_DEVICE_OPTIX=ON -DWITH_CYCLES_DEVICE_CUDA=ON \
	-DZLIB_INCLUDE_DIR="$zlibRoot" -DZLIB_LIBRARY="$zlibRoot/build/libz.a"
validate_result
cmake --build "." --config "$buildConfig"
validate_result

print_hmsg "Done!"

cyclesDepsRoot="$deps/lib/win64_vc15"
cmakeArgs=" $cmakeArgs -DDEPENDENCY_CYCLES_INCLUDE=\"$deps/cycles/src\" "
cmakeArgs=" $cmakeArgs -DDEPENDENCY_CYCLES_ATOMIC_INCLUDE=\"$deps/cycles\third_party\atomic\" "
cmakeArgs=" $cmakeArgs -DDEPENDENCY_CYCLES_DEPENDENCIES_LOCATION=\"$cyclesDepsRoot\" "
cmakeArgs=" $cmakeArgs -DDEPENDENCY_CYCLES_LIBRARY_LOCATION=\"$cyclesRoot/build/lib/$buildConfig\" "

cmakeArgs=" $cmakeArgs -DDEPENDENCY_OPENEXR_INCLUDE=\"$cyclesDepsRoot/openexr/include\" "
#cmakeArgs=" $cmakeArgs -DDEPENDENCY_OPENEXR_UTIL_LIBRARY=\"$cyclesDepsRoot/openexr/lib/OpenEXRUtil_s.lib\" "
cmakeArgs=" $cmakeArgs -DDEPENDENCY_OPENEXR_IMATH_INCLUDE=\"$cyclesDepsRoot/imath/include\" "
#cmakeArgs=" $cmakeArgs -DDEPENDENCY_OPENEXR_IMATH_LIBRARY=\"$cyclesDepsRoot/imath/lib/Imath_s.lib\" "
#cmakeArgs=" $cmakeArgs -DDEPENDENCY_OPENEXR_ILMTHREAD_LIBRARY=\"$cyclesDepsRoot/openexr/lib/IlmThread_s.lib\" "
#cmakeArgs=" $cmakeArgs -DDEPENDENCY_OPENEXR_IEX_LIBRARY=\"$cyclesDepsRoot/openexr/lib/Iex_s.lib\" "

#cmakeArgs=" $cmakeArgs -DDEPENDENCY_JPEG_LIBRARY=\"$cyclesDepsRoot/jpeg/lib/libjpeg.lib\" "
#cmakeArgs=" $cmakeArgs -DDEPENDENCY_TIFF_LIBRARY=\"$deps/libtiff/build/libtiff/$buildConfig/tiff.lib\" "

