cmake_minimum_required(VERSION 3.18)

# This project orchestrates several third-party build systems. The top-level
# CMake project is intentionally host-native; Android cross-compilation is
# configured by the existing dependency recipes until those recipes are moved
# into CMake in a later step.
project(libbaresip_android_build NONE)

find_program(MAKE_EXECUTABLE NAMES gmake make REQUIRED)

set(ANDROID_TARGET_ARCH "arm64-v8a" CACHE STRING
    "Android ABI to build (armeabi-v7a, arm64-v8a, or x86_64)")
set_property(CACHE ANDROID_TARGET_ARCH PROPERTY STRINGS
    armeabi-v7a arm64-v8a x86_64)
set(API_LEVEL "28" CACHE STRING "Android API level")
set(NDK_PATH "" CACHE PATH "Android NDK path (empty uses the legacy Makefile default)")
set(OUTPUT_DIR "" CACHE PATH "Library distribution directory (empty uses the legacy Makefile default)")

set(_make_config_args
    "API_LEVEL=${API_LEVEL}"
)
if(NDK_PATH)
    list(APPEND _make_config_args "NDK_PATH=${NDK_PATH}")
endif()
if(OUTPUT_DIR)
    list(APPEND _make_config_args "OUTPUT_DIR=${OUTPUT_DIR}")
endif()

function(add_legacy_make_target cmake_target make_target abi)
    set(_args ${_make_config_args})
    if(NOT "${abi}" STREQUAL "")
        list(APPEND _args "ANDROID_TARGET_ARCH=${abi}")
    endif()
    add_custom_target(${cmake_target}
        COMMAND "${MAKE_EXECUTABLE}" -C "${CMAKE_CURRENT_SOURCE_DIR}"
                ${make_target} ${_args}
        USES_TERMINAL
        VERBATIM
    )
endfunction()

# Transitional targets keep the established per-dependency recipes working
# while CMake becomes the user-facing build entry point. The legacy Makefile
# remains the backend for now; subsequent migration can replace these targets
# with native CMake/custom commands without changing the documented commands.
add_legacy_make_target(download-sources download-sources "")
add_legacy_make_target(libbaresip libbaresip "${ANDROID_TARGET_ARCH}")

add_legacy_make_target(libbaresip_arm64 libbaresip arm64-v8a)
add_legacy_make_target(libbaresip_armv7 libbaresip armeabi-v7a)
add_legacy_make_target(libbaresip_x86_64 libbaresip x86_64)

add_custom_target(all_abis)
add_dependencies(all_abis libbaresip_arm64 libbaresip_armv7)

add_custom_target(debug_abis)
add_dependencies(debug_abis all_abis libbaresip_x86_64)

message(STATUS "Build frontend: CMake (legacy Makefile recipes)")
message(STATUS "Selected ABI: ${ANDROID_TARGET_ARCH}")
message(STATUS "Android API level: ${API_LEVEL}")
