# libbaresip-android
==================

This project shows how to build and install libraries needed by the [baresip Android application](https://github.com/juha-h/baresip-studio) on Debian 13 using Android NDK.

## Prerequisites

Install the following Debian packages:

```sh
apt install wget cmake make libtool m4 automake pkg-config unzip
```

Download and unzip the Android NDK for Linux from <https://developer.android.com/ndk/downloads>, or use the NDK that comes with Android Studio. The NDK version must match `ndkVersion` in the baresip-studio Gradle configuration.

## Get the sources

Clone this repository, then download and patch the required dependency sources:

```sh
git clone https://github.com/juha-h/libbaresip-android.git
cd libbaresip-android
cmake -S . -B build
cmake --build build --target download-sources
```

The source checkout needs the dependency directories populated by `download-sources` before building.

## Configure and build

The new CMake entry point is a transitional frontend: it exposes the top-level build targets, while the existing Makefile still runs the dependency-specific build recipes. This keeps the current behavior intact as those recipes are migrated incrementally.

Configure the Android ABI, API level, and (optionally) NDK and distribution paths:

```sh
cmake -S . -B build \
  -DANDROID_TARGET_ARCH=arm64-v8a \
  -DAPI_LEVEL=28 \
  -DNDK_PATH=/path/to/android-ndk \
  -DOUTPUT_DIR=/path/to/distribution
```

Build one ABI:

```sh
cmake --build build --target libbaresip
```

Choose `armeabi-v7a`, `arm64-v8a`, or `x86_64` for `ANDROID_TARGET_ARCH`. To build the standard ABIs (armeabi-v7a and arm64-v8a), or include x86_64, use:

```sh
cmake --build build --target all_abis
cmake --build build --target debug_abis
```

The previous Makefile commands remain available during this transition. In particular, `make download-sources`, `make libbaresip ANDROID_TARGET_ARCH=$ARCH`, `make all`, and `make debug` still work.
