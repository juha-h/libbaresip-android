libbaresip-android
==================

This project shows how to build libbaresip for Android using Android NDK
r18 or later that only support clang.  Resulting libbaresip can be used
in Baresip based Android applications.

Supported NDKs

| NDK: | Supported: |
|------|------------|
| r18  | Yes        |
| r17  | No         |
| ...  | No         |

## Step 0 - download Android NDK

Download and unzip latest Android NDK for Linux from
```
https://developer.android.com/ndk/downloads/
```

## Step 1 - download source code

Create a directory for libbaresip-android and download the source
code there:
```
$ git clone https://github.com/alfredh/baresip.git
$ git clone https://github.com/creytiv/rem.git
$ git clone https://github.com/creytiv/re.git
$ wget https://www.openssl.org/source/openssl-1.1.1.tar.gz
# Optionally opus and/or zrtp
$ wget http://downloads.xiph.org/releases/opus/opus-1.1.3.tar.gz
$ wget https://github.com/juha-h/libzrtp/archive/master.zip
```

## Step 2 - unpack source code

Unpack packed source code and create symlinks:

```
$ tar zxf openssl-1.1.1.tar.gz
$ ln -s openssl-1.1.1 openssl
$ tar zxf opus-1.1.3.tar.gz
# Optionally
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

## Step 3 - adjust Makefile variables

Adjust Makefile variables NDK_PATH, STUDIO_PATH (optional path of
your Android Studio project), and API_LEVEL.

## Step 4 - create standalone toolchain
```
$ make toolchain
```

## Step 4 - build openssl
```
$ make openssl

## Step 5 - build opus (optional) and zrtp (optional)

```
$ make opus
$ make zrtp
```

## Step 5 - build libbaresip
```
$ make baresip.a
```

## Step 6 - install libraries and include files to your Android Studio
project (optional)

```
$ make install-openssl
$ make install-opus # optional
$ make install-zrtp # optional
$ make install libbaresip
```
