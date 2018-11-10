libbaresip-android
==================

This project shows how to build libbaresip for Android using Android NDK
r18 or later that only support clang.  Resulting libbaresip can be used
in Baresip based Android applications.

Currently supported NDKs:

| NDK  | Supported  |
|------|------------|
| r18  | Yes        |
| r17  | No         |
| ...  | No         |

## Step 0 - download Android NDK

Download and unzip Android NDK for Linux from:
```
https://developer.android.com/ndk/downloads/
```
or use ndk-bundle that comes with Andoid SDK.

## Step 1 - clone libbaresip-android

Clone libbaresip-android repository:
```
$ git clone https://github.com/juha-g/libbaresip-android.git
```
This creates libbaresip-android directory containing Makefile.  
If needed, adjust Makefile variables NDK_PATH, API_LEVEL, and
STUDIO_PATH (optional path to your Android Studio project).

## Step 2 - download source code

Download source code in directory you created for libbaresip-android:
```
$ git clone https://github.com/alfredh/baresip.git
$ git clone https://github.com/creytiv/rem.git
$ git clone https://github.com/creytiv/re.git
$ git clone https://github.com/openssl/openssl.git
# Optionally opus and/or zrtp
$ wget http://downloads.xiph.org/releases/opus/opus-1.1.3.tar.gz
$ wget https://github.com/juha-h/libzrtp/archive/master.zip
```

## Step 3 - unpack source code

Unpack packed source code and create symlinks:

```
$ tar zxf opus-1.1.3.tar.gz
$ ln -s opus-1.1.3 opus
$ unzip master.zip
$ ln -s libzrtp-master zrtp
```
After that you should have in libbaresip-android directory a layout like
this:
```
    baresip/
    openssl/
    re/
    rem/
    opus/ (optional)
    zrtp/ (optional)
```

## Step 4 - create standalone toolchain
```
$ make toolchain
```

## Step 5 - build openssl
```
$ make openssl
```

## Step 6 - build opus (optional) and zrtp (optional)

```
$ make opus
$ make zrtp
```

## Step 7 - build libbaresip
```
$ make libbaresip
```

## Step 8 - install results to your Android Studio project (optional)

```
$ make install-openssl
$ make install-opus # optional
$ make install-zrtp # optional
$ make install-libbaresip
```

Alternatively, instead of steps 2-8, after Steps 0 and 1:
```
$ make download-sources
$ make all
$ make install-all
```
This will also patch reg.c as needed by baresip-studio project.
