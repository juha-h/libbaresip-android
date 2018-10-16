#
# Makefile
#
# Copyright (C) 2014 Creytiv.com and 2018 TutPro Inc.
#

# Paths to your Android SDK/NDK
NDK_PATH  := /usr/local/android-ndk-r18b
PROJECT_PATH := /usr/src/baresip-studio

# Android API level:
API_LEVEL := 21

PLATFORM  := android-$(API_LEVEL)

#
# Target architecture
#
TARGET    := arm-linux-androideabi

OS        := $(shell uname -s | tr "[A-Z]" "[a-z]")
HOST_OS   := linux-x86_64

# NDK tools
SYSROOT   := $(NDK_PATH)/platforms/$(PLATFORM)/arch-arm
SYSROOT_INC   := $(NDK_PATH)/sysroot
BIN       := $(NDK_PATH)/toolchains/$(TARGET)-4.9/prebuilt/$(HOST_OS)/bin
CLANG_BIN := $(NDK_PATH)/toolchains/llvm/prebuilt/$(HOST_OS)/bin
PWD       := $(shell pwd)

# Toolchain tools
PATH	  := $(PWD)/toolchain/bin:/usr/bin:/bin
AR	  := $(TARGET)-ar
AS	  := $(TARGET)-clang
CC	  := $(TARGET)-clang
CXX	  := $(TARGET)-clang++
LD	  := $(TARGET)-ld
STRIP	  := $(TARGET)-strip

# Compiler and Linker Flags
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT_INC)/usr/include/ \
	-isystem $(SYSROOT_INC)/usr/include/$(TARGET) \
	-fPIE -fPIC \

CFLAGS := $(COMMON_CFLAGS) \
	-D__ANDROID_API__=$(API_LEVEL) \
	-I$(PWD)/openssl/include \
	-I$(PWD)/opus/include_opus \
	-I$(PWD)/zrtp/include \
	-I$(PWD)/zrtp/third_party/bnlib \
	-I$(PWD)/zrtp/third_party/bgaes \
	-march=armv7-a \
	-target $(TARGET)

LFLAGS := -L$(SYSROOT)/usr/lib/ \
	-L$(PWD)/openssl \
	-L$(PWD)/opus/.libs \
	-L$(PWD)/zrtp \
	-L$(PWD)/zrtp/third_party/bnlib \
	-fPIE -pie \
	--sysroot=$(NDK_PATH)/platforms/$(PLATFORM)/arch-arm

COMMON_FLAGS := CC=$(CC) \
	CXX=$(CXX) \
	RANLIB=$(RANLIB) \
	AR=$(AR) \
	EXTRA_CFLAGS="$(CFLAGS) -DANDROID" \
	EXTRA_CXXFLAGS="$(CFLAGS) -DANDROID" \
	EXTRA_LFLAGS="$(LFLAGS)" \
	SYSROOT=$(SYSROOT_INC)/usr \
	SYSROOT_ALT=$(SYSROOT)/usr \
	HAVE_INTTYPES_H=1 \
	HAVE_GETOPT=1 \
	HAVE_LIBRESOLV= \
	HAVE_RESOLV= \
	HAVE_PTHREAD=1 \
	HAVE_PTHREAD_RWLOCK=1 \
	HAVE_LIBPTHREAD= \
	HAVE_INET_PTON=1 \
	HAVE_INET6=1 \
	HAVE_GETIFADDRS= \
	PEDANTIC= \
	OS=$(OS) ARCH=arm \
	USE_OPENSSL=yes \
	USE_OPENSSL_DTLS=yes \
	USE_OPENSSL_SRTP=yes \
	ANDROID=yes

EXTRA_MODULES := g711 stdio opensles dtls_srtp echo aubridge

ifneq ("$(wildcard $(PWD)/opus)","")
	EXTRA_MODULES := $(EXTRA_MODULES) opus
endif

ifneq ("$(wildcard $(PWD)/zrtp)","")
	EXTRA_MODULES := $(EXTRA_MODULES) zrtp
endif

default:	libbaresip

libre.a: Makefile
	@rm -f re/libre.*
	PATH=$(PATH) make $@ -C re $(COMMON_FLAGS)

librem.a:	Makefile libre.a
	@rm -f rem/librem.*
	PATH=$(PATH) make $@ -C rem $(COMMON_FLAGS)

libbaresip:	Makefile librem.a libre.a
	@rm -f baresip/baresip baresip/src/static.c
	PKG_CONFIG_LIBDIR="$(SYSROOT)/usr/lib/pkgconfig" \
	PATH=$(PATH) make libbaresip.a -C baresip $(COMMON_FLAGS) STATIC=1 \
		LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem \
	        MOD_AUTODETECT= \
		EXTRA_MODULES="$(EXTRA_MODULES)"

ifneq ("$(wildcard $(PWD)/baresip/libbaresip.a)","")
install-libbaresip:
	cp $(PWD)/re/libre.a $(PROJECT_PATH)/distribution/re/lib/armeabi-v7a
	cp $(PWD)/re/include/* $(PROJECT_PATH)/distribution/re/include
	cp $(PWD)/rem/librem.a $(PROJECT_PATH)/distribution/rem/lib/armeabi-v7a
	cp $(PWD)/rem/include/* $(PROJECT_PATH)/distribution/rem/include
	cp $(PWD)/baresip/libbaresip.a $(PROJECT_PATH)/distribution/baresip/lib/armeabi-v7a
	cp $(PWD)/baresip/include/baresip.h $(PROJECT_PATH)/distribution/baresip/include
endif

clean:
	make distclean -C baresip
	make distclean -C rem
	make distclean -C re
	-make distclean -C openssl
	-make distclean -C opus
	-make distclean -C zrtp

.PHONY: toolchain
toolchain:
	rm -rf toolchain && \
	$(NDK_PATH)/build/tools/make_standalone_toolchain.py --arch arm \
	--api $(API_LEVEL) --install-dir ./toolchain

# OPENSSL does not support standalone toolchains
OPENSSL_FLAGS := \
	no-shared \
	-D__ANDROID_API__=$(API_LEVEL) \
	-I$(SYSROOT_INC)/usr/include \
	-I$(SYSROOT_INC)/usr/include/$(TARGET)

.PHONY: openssl
openssl:
	cd openssl && \
		CC=clang RANLIB=$(BIN)/$(TARGET)-ranlib \
		AR=$(BIN)/$(TARGET)-ar \
		ANDROID_NDK=$(NDK_PATH) \
		PATH=$(CLANG_BIN):$(BIN):/usr/bin:/bin \
		./Configure android-arm $(OPENSSL_FLAGS) && \
		CC=clang RANLIB=$(BIN)/$(TARGET)-ranlib \
		AR=$(BIN)/$(TARGET)-ar \
		ANDROID_NDK=$(NDK_PATH) \
		PATH=$(CLANG_BIN):$(BIN):/usr/bin:/bin \
		make build_libs

ifneq ("$(wildcard $(PWD)/openssl/libssl.a)","")
install-openssl:
	cp $(PWD)/openssl/libcrypto.a $(PROJECT_PATH)/distribution/openssl/lib/armeabi-v7a
	cp $(PWD)/openssl/libssl.a $(PROJECT_PATH)/distribution/openssl/lib/armeabi-v7a
endif

.PHONY: opus
opus:
	cd opus && \
		rm -rf include_opus && \
		CC="$(CC) --sysroot $(SYSROOT)" \
		RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
		./configure --host=$(TARGET) --disable-shared CFLAGS="$(COMMON_CFLAGS)" && \
		CC="$(CC) --sysroot $(SYSROOT)" \
		RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
		make && \
		mkdir include_opus && \
		mkdir include_opus/opus && \
		cp include/* include_opus/opus

ifneq ("$(wildcard $(PWD)/opus/.libs/libopus.a)","")
install-opus:
	cp $(PWD)/opus/.libs/libopus.a $(PROJECT_PATH)/distribution/opus/lib/armeabi-v7a
endif

.PHONY: zrtp
zrtp:
	cd zrtp && \
		./bootstrap.sh && \
		CC="$(CC) --sysroot $(SYSROOT)" \
		RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
		./configure --host=$(TARGET) CFLAGS="$(COMMON_CFLAGS)" && \
		cd third_party/bnlib/ && \
		CC="$(CC) --sysroot $(SYSROOT)" \
		RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
		./configure --host=$(TARGET) CFLAGS="$(COMMON_CFLAGS)" && \
		cd ../.. && \
		CC="$(CC) --sysroot $(SYSROOT)" \
		RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
		make

ifneq ("$(wildcard $(PWD)/zrtp/libzrtp.a)","")
install-zrtp:
	cp $(PWD)/zrtp/third_party/bnlib/libbn.a $(PROJECT_PATH)/distribution/bn/lib/armeabi-v7a
	cp $(PWD)/zrtp/libzrtp.a $(PROJECT_PATH)/distribution/zrtp/lib/armeabi-v7a
endif

dump:
	@echo "NDK_PATH = $(NDK_PATH)"
	@echo "PROJECT_PATH = $(PROJECT_PATH)"
