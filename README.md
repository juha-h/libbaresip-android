libbaresip-android
==================

This project shows how to build libbaresip for Android on Debian 13 using Android NDK. Resulting libbaresip can be used in Baresip based Android (Studio) applications.

## Step 0 - prerequisites

Download and unzip Android NDK for Linux from:
```
https://developer.android.com/ndk/downloads
```
or use NDK that comes with Android Studio.  NDK version must match ndkVersion in baresip-studio/app/build.gradle.

Install the following Debian packages:

apt install wget cmake make libtool m4 automake pkg-config

## Step 1 - clone libbaresip-android

Clone libbaresip-android repository:
```
$ git clone https://github.com/juha-h/libbaresip-android.git
```
This creates libbaresip-android directory containing Makefile.

Go to libbaresip-android directory and checkout video branch.

## Step 2 - edit Makefile

You need to set (or check) the variables listed in VALUES TO CONFIGURE section.

## Step 3 - download source code

Download source code:
```
$ make download-sources
```
This will also patch re and ffmpeg-kit as needed by baresip-studio project.

After that you should have in libbaresip-android directory these source directories:
```
    amr
    aom
    baresip
    bcg729
    codec2
    ffmpeg-android-maker
    g722
    g7221
    libyuv
    openssl
    opus
    png
    re
    sndfile
    vo-amrwbenc
    zrtpcpp
```

## Step 4 - build and install libraries

Build and install the libraries only for a selected architecture with command:
```
$ make libbaresip ANDROID_TARGET_ARCH=$ARCH
```
by replacing $ARCH with armeabi-v7a, arm64-v8a, or x86_64.

Or you can build and install the libraries for armeabi-v7a and arm64-v8a architectures with command:
```
$ make all
```
and also for x86_64 architecture with command:
```
$ make debug
```
