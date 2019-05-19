libbaresip-android
==================

This project shows how to build libbaresip for Android using Android NDK
r19 or later that only support clang.  Resulting libbaresip can be used
in Baresip based Android (Studio) applications.

Currently supported NDKs:

| NDK  | Supported  |
|------|------------|
| r19  | Yes        |
| r18  | No         |
| ...  | No         |

## Step 0 - download Android NDK

Download and unzip Android NDK for Linux from:
```
https://developer.android.com/ndk/downloads/
```
or use ndk-bundle that comes with Android Studio 3.3.x Sdk (tested).

## Step 1 - clone libbaresip-android

Clone libbaresip-android repository:
```
$ git clone https://github.com/juha-g/libbaresip-android.git
```
This creates libbaresip-android directory containing Makefile.

## Step 2 - edit Makefile

Go to ./libbaresip-android directory and edit Makefile. You need to set
(or check) the variables listed in VALUES TO CONFIGURE section.

## Step 3 - download source code

Download source code to ./libbaresip-android directory:
```
$ make download-sources
```
This will also patch reg.c as needed by baresip-studio project.

After that you should have in libbaresip-android directory a layout like
this:
```
    baresip/
    openssl/
    re/
    rem/
    opus/
    g7221/
    zrtp/
```

## Step 4 - build and install libraries

You can build and install the libraries only for a selected architecture
with command:
```
$ make install ANDROID_TARGET_ARCH=$ARCH
```
by replacing $ARCH with armeabi-v7a or arm64-v8a.

Or you can build and install the libraries for all architectures with
command:
```
$ make install-all
```
