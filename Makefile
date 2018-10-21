#
# Makefile
#
# Copyright (C) 2014 Creytiv.com and 2018 TutPro Inc.
#

# Paths to your Android SDK/NDK
NDK_PATH  := /usr/local/android-ndk-r18b
#NDK_PATH   := /usr/local/Android/Sdk/ndk-bundle
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
PWD       := $(shell pwd)

# Toolchain and sysroot
TOOLCHAIN := $(PWD)/toolchain
SYSROOT   := $(TOOLCHAIN)/sysroot

# Toolchain tools
PATH	  := $(TOOLCHAIN)/bin:/usr/bin:/bin
AR	  := $(TARGET)-ar
AS	  := $(TARGET)-clang
CC	  := $(TARGET)-clang
CXX	  := $(TARGET)-clang++
LD	  := $(TARGET)-ld
STRIP	  := $(TARGET)-strip

# Compiler and Linker Flags for re, rem, and baresip
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT)/usr/include -fPIE -fPIC

CFLAGS := $(COMMON_CFLAGS) \
	-I$(PWD)/openssl/include \
	-I$(PWD)/opus/include_opus \
	-I$(PWD)/zrtp/include \
	-I$(PWD)/zrtp/third_party/bnlib \
	-I$(PWD)/zrtp/third_party/bgaes \
	-march=armv7-a

LFLAGS := -L$(SYSROOT)/usr/lib/ \
	-L$(PWD)/openssl \
	-L$(PWD)/opus/.libs \
	-L$(PWD)/zrtp \
	-L$(PWD)/zrtp/third_party/bnlib \
	-fPIE -pie

COMMON_FLAGS := \
	EXTRA_CFLAGS="$(CFLAGS) -DANDROID" \
	EXTRA_CXXFLAGS="$(CFLAGS) -DANDROID" \
	EXTRA_LFLAGS="$(LFLAGS)" \
	SYSROOT=$(SYSROOT)/usr \
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

all:	toolchain openssl opus zrtp libbaresip

default:	libbaresip

.PHONY: toolchain
toolchain:
	rm -rf $(TOOLCHAIN) && \
	$(NDK_PATH)/build/tools/make_standalone_toolchain.py --arch arm \
		--api $(API_LEVEL) --install-dir $(TOOLCHAIN)

.PHONY: openssl
openssl:
	cd openssl && \
	CC=clang ANDROID_NDK=$(TOOLCHAIN) PATH=$(PATH) \
	./Configure android-arm no-shared $(OPENSSL_FLAGS) && \
	CC=clang ANDROID_NDK=$(TOOLCHAIN) PATH=$(PATH) \
	make build_libs

ifneq ("$(wildcard $(PWD)/openssl/libssl.a)","")
install-openssl:
	cp $(PWD)/openssl/libcrypto.a \
		$(PROJECT_PATH)/distribution/openssl/lib/armeabi-v7a
	cp $(PWD)/openssl/libssl.a \
		$(PROJECT_PATH)/distribution/openssl/lib/armeabi-v7a
endif

.PHONY: opus
opus:
	cd opus && \
	rm -rf include_opus && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
	./configure --host=$(TARGET) --disable-shared \
		CFLAGS="$(COMMON_CFLAGS)" && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
	make && \
	mkdir include_opus && \
	mkdir include_opus/opus && \
	cp include/* include_opus/opus

ifneq ("$(wildcard $(PWD)/opus/.libs/libopus.a)","")
install-opus:
	cp $(PWD)/opus/.libs/libopus.a \
		$(PROJECT_PATH)/distribution/opus/lib/armeabi-v7a
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
	cp $(PWD)/zrtp/third_party/bnlib/libbn.a \
		$(PROJECT_PATH)/distribution/bn/lib/armeabi-v7a
	cp $(PWD)/zrtp/libzrtp.a \
		$(PROJECT_PATH)/distribution/zrtp/lib/armeabi-v7a
endif

libre.a: Makefile
	@rm -f re/libre.*
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) \
	make $@ -C re $(COMMON_FLAGS)

librem.a:	Makefile libre.a
	@rm -f rem/librem.*
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) \
	make $@ -C rem $(COMMON_FLAGS)

libbaresip:	Makefile librem.a libre.a
	@rm -f baresip/baresip baresip/src/static.c
	PKG_CONFIG_LIBDIR="$(SYSROOT)/usr/lib/pkgconfig" \
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) \
	make libbaresip.a -C baresip $(COMMON_FLAGS) STATIC=1 \
		LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem \
	        MOD_AUTODETECT= EXTRA_MODULES="$(EXTRA_MODULES)"

ifneq ("$(wildcard $(PWD)/baresip/libbaresip.a)","")
install-libbaresip:
	cp $(PWD)/re/libre.a \
		$(PROJECT_PATH)/distribution/re/lib/armeabi-v7a
	cp $(PWD)/re/include/* \
		$(PROJECT_PATH)/distribution/re/include
	cp $(PWD)/rem/librem.a \
		$(PROJECT_PATH)/distribution/rem/lib/armeabi-v7a
	cp $(PWD)/rem/include/* \
		$(PROJECT_PATH)/distribution/rem/include
	cp $(PWD)/baresip/libbaresip.a \
		$(PROJECT_PATH)/distribution/baresip/lib/armeabi-v7a
	cp $(PWD)/baresip/include/baresip.h \
		$(PROJECT_PATH)/distribution/baresip/include
endif

install-all: install-openssl install-opus install-zrtp install-libbaresip

download-sources:
	rm -fr baresip re rem openssl opus* master.zip libzrtp-master zrtp
	git clone https://github.com/alfredh/baresip.git
	git clone https://github.com/creytiv/rem.git
	git clone https://github.com/creytiv/re.git
	git clone https://github.com/openssl/openssl.git
	wget http://downloads.xiph.org/releases/opus/opus-1.1.3.tar.gz
	wget https://github.com/juha-h/libzrtp/archive/master.zip
	tar zxf opus-1.1.3.tar.gz
	ln -s opus-1.1.3 opus
	unzip master.zip
	ln -s libzrtp-master zrtp
	patch -p0 < reg.c-patch

clean:
	make distclean -C baresip
	make distclean -C rem
	make distclean -C re
	-make distclean -C openssl
	-make distclean -C opus
	-make distclean -C zrtp
