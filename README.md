libbaresip-android
==================

This project shows how to build libbaresip for Android on Debian 12 using Android NDK. Resulting libbaresip can be used in Baresip based Android (Studio) applications.

## Step 0 - prerequisites

Download and unzip Android NDK for Linux from:
```
https://developer.android.com/ndk/downloads
```
or use NDK (r25b or newer) that comes with Android Studio.

Install the following Debian packages:
```
apt install wget make libtool m4 automake pkg-config
apt install -t bullseye-backports cmake
```
## Step 1 - clone libbaresip-android

Clone libbaresip-android repository:
```
$ git clone https://github.com/juha-h/libbaresip-android.git
```
This creates libbaresip-android directory containing Makefile.

Go to libbaresip-android directory and checkout master branch.

## Step 2 - edit Makefile

You need to set (or check) the variables listed in VALUES TO CONFIGURE section.

## Step 3 - download source code

Download source code:
```
$ make download-sources
```
This will also patch re and baresip as needed by baresip-studio project.

After that you should have in libbaresip-android directory these source directories:
```
    abseil-cpp
    amr
    baresip
    bcg729
    codec2
    g7221
    openssl
    opus
    re
    sndfile
    spandsp
    tiff
    vo-amrwbenc
    webrtc
    zrtpcpp
```

## Step 4 - build and install libraries

Build and install the libraries only for a selected architecture with command:
```
$ make libbaresip ANDROID_TARGET_ARCH=$ARCH
```
by replacing $ARCH with armeabi-v7a or arm64-v8a.

Or you can build and install the libraries for all architectures with command:
```
$ make all
```
