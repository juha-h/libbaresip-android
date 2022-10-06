libbaresip-android
==================

This project shows how to build libbaresip for Android on Debian 11 using Android NDK. Resulting libbaresip can be used in Baresip based Android (Studio) applications.

## Step 0 - prerequisites

Download and unzip Android NDK r25 for Linux from:
```
https://dl.google.com/android/repository/android-ndk-r25-linux.zip
```
or use NDK r25 that comes with Android Studio.

Install libtool and upgrade cmake from bullseye-backports (it needs to be 3.19 or higher). 

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

Download source code to ./libbaresip-android directory:
```
$ make download-sources
```
This will also patch re, baresip, and ffmpeg-kit as needed by baresip-studio project.

After that you should have in libbaresip-android directory these source directories:
```
    abseil-cpp
    amr
    baresip
    bcg729
    ffmpeg-kit
    g7221
    gsm
    openssl
    opus
    re
    rem
    spandsp
    tiff
    vo-amrwbenc
    webrtc
    ZRTPCPP
```

## Step 4 - build and install libraries

Build and install the libraries only for a selected architecture with command:
```
$ make install ANDROID_TARGET_ARCH=$ARCH
```
by replacing $ARCH with armeabi-v7a or arm64-v8a.

Or you can build and install the libraries for all architectures with command:
```
$ make install-all
```
