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

If needed, adjust Makefile variables NDK_PATH, STUDIO_PATH
(optional path to your Android Studio project), and API_LEVEL.

## Step 1 - download source code

Create a directory for libbaresip-android and download the source
code there:
```
$ git clone https://github.com/alfredh/baresip.git
$ git clone https://github.com/creytiv/rem.git
$ git clone https://github.com/creytiv/re.git
$ git clone https://github.com/openssl/openssl.git
# Optionally opus and/or zrtp
$ wget http://downloads.xiph.org/releases/opus/opus-1.1.3.tar.gz
$ wget https://github.com/juha-h/libzrtp/archive/master.zip
```

## Step 2 - unpack source code

Unpack packed source code and create symlinks:

```
$ tar zxf opus-1.1.3.tar.gz
$ ln -s opus-1.1.3 opus
$ unzip master.zip
$ ln -s libzrtp-master zrtp
```
After that you should have a layout like this:
```
    baresip/
    openssl/
    re/
    rem/
    opus/ (optional)
    zrtp/ (optional)
```

## Step 3 - create standalone toolchain
```
$ make toolchain
```

## Step 4 - build openssl
```
$ make openssl
```

## Step 5 - build opus (optional) and zrtp (optional)

```
$ make opus
$ make zrtp
```

## Step 6 - build libbaresip
```
$ make libbaresip
```

## Step 7 - install results to your Android Studio project (optional)

```
$ make install-openssl
$ make install-opus # optional
$ make install-zrtp # optional
$ make install-libbaresip
```

Alternatively, instead of individual Steps 1-7, after Step 0:
```
$ make download-sources
$ make all
$ make install-all
```
