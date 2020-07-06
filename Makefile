# -------------------- VALUES TO CONFIGURE --------------------

# Path to your Android NDK (must be r19 or higher)
# Only tested with the one that is included in Android Sdk
NDK_PATH  :=  /opt/Android/Sdk/ndk-bundle

# Android API level
API_LEVEL := 24

# Set default from following values: [armeabi-v7a, arm64-v8a]
ANDROID_TARGET_ARCH := arm64-v8a

# Directory where libraries and include files are instelled
OUTPUT_DIR := /usr/src/baresip-studio/distribution.video

# -------------------- GENERATED VALUES --------------------

ifeq ($(ANDROID_TARGET_ARCH), armeabi-v7a)
	TARGET       := arm-linux-androideabi
	CLANG_TARGET := armv7a-linux-androideabi
	ARCH         := arm
	OPENSSL_ARCH := android-arm
	VPX_TARGET   := armv7-android-gcc
	DISABLE_NEON := --disable-neon
	FFMPEG_ARCH  := arm
	MARCH        := armv7-a
else
	TARGET       := aarch64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := arm
	OPENSSL_ARCH := android-arm64
	VPX_TARGET   := arm64-android-gcc
	DISABLE_NEON :=
	FFMPEG_ARCH  := aarch64
	MARCH        := armv8-a
endif

PLATFORM	:= android-$(API_LEVEL)

OS		:= $(shell uname -s | tr "[A-Z]" "[a-z]")
ifeq ($(OS),linux)
	HOST_OS   := linux-x86_64
endif
ifeq ($(OS),darwin)
	HOST_OS   := darwin-x86_64
endif

CPU_COUNT	:= $(shell nproc)
PWD		:= $(shell pwd)

# Toolchain and sysroot
TOOLCHAIN	:= $(NDK_PATH)/toolchains/llvm/prebuilt/linux-x86_64
SYSROOT		:= $(TOOLCHAIN)/sysroot
PKG_CONFIG_LIBDIR := $(NDK_PATH)/prebuilt/linux-x86_64/lib/pkgconfig

# Toolchain tools
PATH	:= $(TOOLCHAIN)/bin:/usr/bin:/bin
AR	:= $(TARGET)-ar
AS	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CC	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CXX	:= $(CLANG_TARGET)$(API_LEVEL)-clang++
LD	:= $(TARGET)-ld
RANLIB	:= $(TARGET)-ranlib
STRIP	:= $(TARGET)-strip

# Compiler and Linker Flags for re, rem, and baresip
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT)/usr/include -fPIE -fPIC

CFLAGS := $(COMMON_CFLAGS) \
	-I$(PWD)/openssl/include \
	-I$(PWD)/opus/include_opus \
	-I$(PWD)/g7221/src \
	-I$(PWD)/spandsp/src \
	-I$(PWD)/tiff/libtiff \
	-I$(PWD)/ilbc \
	-I$(PWD)/amr/include \
	-I$(PWD)/webrtc/include \
	-I$(PWD)/zrtp/include \
	-I$(PWD)/zrtp/third_party/bnlib \
	-I$(PWD)/zrtp/third_party/bgaes \
	-I$(PWD)/vpx \
	-I$(PWD)/ffmpeg \
	-march=$(MARCH)

LFLAGS := -L$(SYSROOT)/usr/lib/ \
	-L$(PWD)/openssl \
	-L$(PWD)/opus/.libs \
	-L$(PWD)/g7221/src/.libs \
	-L$(PWD)/spandsp/src/.libs \
	-L$(PWD)/amr/lib \
	-L$(PWD)/ffmpeg/libavformat \
	-L$(PWD)/ffmpeg/libavcodec \
	-L$(PWD)/ffmpeg/libswresample \
	-L$(PWD)/ffmpeg/libavutil \
	-L$(PWD)/ffmpeg/libavdevice \
	-L$(PWD)/ffmpeg/libavfilter \
	-L$(PWD)/ffmpeg/libswscale \
	-L$(PWD)/ffmpeg/libpostproc \
	-L$(PWD)/ilbc \
	-L$(PWD)/zrtp \
	-L$(PWD)/zrtp/third_party/bnlib \
	-fPIE -pie

COMMON_FLAGS := \
	EXTRA_CFLAGS="$(CFLAGS) -DANDROID" \
	EXTRA_CXXFLAGS="$(CFLAGS) -DANDROID -DHAVE_PTHREAD" \
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
	OS=$(OS) \
	ARCH=$(ARCH) \
	USE_OPENSSL=yes \
	USE_OPENSSL_DTLS=yes \
	USE_OPENSSL_SRTP=yes \
	ANDROID=yes \
	RELEASE=1

OPENSSL_FLAGS := -D__ANDROID_API__=$(API_LEVEL)

EXTRA_MODULES := webrtc_aec opensles dtls_srtp opus ilbc g711 g722 \
	g7221 g726 amr zrtp stun turn ice presence contact mwi account natpmp \
	srtp uuid debug_cmd avcodec avformat vp8 vp9 selfview

default:
	make libbaresip ANDROID_TARGET_ARCH=$(ANDROID_TARGET_ARCH)

.PHONY: openssl
openssl:
	-make distclean -C openssl
	cd openssl && \
	CC=clang ANDROID_NDK=$(NDK_PATH) PATH=$(PATH) ./Configure $(OPENSSL_ARCH) no-shared $(OPENSSL_FLAGS) && \
	CC=clang ANDROID_NDK=$(NDK_PATH) PATH=$(PATH) make build_libs

.PHONY: install-openssl
install-openssl: openssl
	rm -rf $(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)
	cp openssl/libcrypto.a \
		$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)
	cp openssl/libssl.a \
		$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)

.PHONY: opus
opus:
	-make distclean -C opus
	cd opus && \
	rm -rf include_opus && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared --disable-doc --disable-extra-programs CFLAGS="$(COMMON_CFLAGS)" && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	mkdir include_opus && \
	mkdir include_opus/opus && \
	cp include/* include_opus/opus

.PHONY: install-opus
install-opus: opus
	rm -rf $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)
	cp opus/.libs/libopus.a $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)

.PHONY: tiff
tiff:
	-make distclean -C tiff
	cd tiff && \
	./autogen.sh && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes ./configure --host=arm-linux --disable-shared CFLAGS="$(COMMON_CFLAGS)" && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make

.PHONY: spandsp
spandsp: tiff
	-make distclean -C spandsp
	cd spandsp && \
	touch configure.ac aclocal.m4 configure Makefile.am Makefile.in && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes ./configure --host=arm-linux --enable-builtin-tiff --disable-shared CFLAGS="$(COMMON_CFLAGS)" && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make

.PHONY: install-spandsp
install-spandsp: spandsp
	rm -rf $(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)
	cp spandsp/src/.libs/libspandsp.a $(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)

.PHONY: g7221
g7221:
	-make distclean -C g7221
	cd g7221 && \
	libtoolize --force && \
	autoreconf --install && \
	autoconf && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(BIN):$(PATH) \
	ac_cv_func_malloc_0_nonnull=yes \
	./configure --host=$(TARGET) --disable-shared CFLAGS="-fPIC" && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(BIN):$(PATH) \
	make

.PHONY: install-g7221
install-g7221: g7221
	rm -rf $(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)
	cp g7221/src/.libs/libg722_1.a $(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)

.PHONY: ilbc
ilbc:
	make clean -C ilbc
	cd ilbc && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
	make

.PHONY: install-ilbc
install-ilbc: ilbc
	rm -rf $(OUTPUT_DIR)/ilbc/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/ilbc/lib/$(ANDROID_TARGET_ARCH)
	cp ilbc/libilbc.a $(OUTPUT_DIR)/ilbc/lib/$(ANDROID_TARGET_ARCH)

.PHONY: amr
amr: 
	-make distclean -C amr
	cd amr && \
	rm -rf lib include && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CXXFLAGS=-fPIC --prefix=$(PWD)/amr && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	make install

.PHONY: install-amr
install-amr: amr
	rm -rf $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)
	cp amr/amrnb/.libs/libopencore-amrnb.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrnb.a
#	cp amr/amrwb/.libs/libopencore-amrwb.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrwb.a

.PHONY: webrtc
webrtc:
	cd webrtc && \
	rm -rf obj && \
	$(NDK_PATH)/ndk-build APP_PLATFORM=android-$(API_LEVEL)

.PHONY: install-webrtc
install-webrtc: webrtc
	rm -rf $(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)
	cp webrtc/obj/local/$(ANDROID_TARGET_ARCH)/libwebrtc.a $(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)

.PHONY: zrtp
zrtp:
	-make distclean -C zrtp
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

install-zrtp: zrtp
	rm -rf $(OUTPUT_DIR)/bn/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/bn/lib/$(ANDROID_TARGET_ARCH)
	cp zrtp/third_party/bnlib/libbn.a $(OUTPUT_DIR)/bn/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/zrtp/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/zrtp/lib/$(ANDROID_TARGET_ARCH)
	cp zrtp/libzrtp.a $(OUTPUT_DIR)/zrtp/lib/$(ANDROID_TARGET_ARCH)

.PHONY: vpx
vpx:
	rm -rf vpx/build_tmp && \
	mkdir vpx/build_tmp && \
	cd vpx/build_tmp && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX="$(CXX) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) STRIP=$(STRIP) \
	../configure \
	--target=$(VPX_TARGET) \
	--enable-libs \
	--enable-pic \
	--enable-better-hw-compatibility \
	$(DISABLE_NEON) \
	--enable-vp8 \
	--enable-vp9 \
	--enable-realtime-only \
	--enable-small \
	--disable-examples \
	--disable-tools \
	--disable-docs \
	--disable-unit-tests \
	--disable-decode-perf-tests \
	--disable-encode-perf-tests \
	--disable-codec-srcs \
	--disable-debug-libs \
	--disable-debug \
	--disable-gprof \
	--disable-gcov \
	--disable-ccache \
	--disable-install-bins \
	--disable-install-srcs \
	--disable-install-docs && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) STRIP=$(STRIP) \
	make -j$(CPU_COUNT)

.PHONY: install-vpx
install-vpx: vpx
	rm -rf $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	cp vpx/build_tmp/libvpx.a $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)

.PHONY: x264
x264:
	-make distclean -C x264
	cd x264 && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
	PREFIX=$(PWD)/android/arm \
	./configure --host=$(TARGET) \
	--enable-static \
	--enable-strip \
	--disable-cli \
	--disable-avs \
	--disable-gpac \
	--disable-lsmash \
	--enable-pic && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(BIN):$(PATH) \
	make -j$(CPU_COUNT)

.PHONY: ffmpeg
ffmpeg: vpx x264
	-make distclean -C ffmpeg
	cd ffmpeg && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
	PREFIX=$(PWD)/android/arm \
	./configure \
	--target-os=android \
	--arch=$(FFMPEG_ARCH) \
	--disable-everything \
	--enable-cross-compile \
	--enable-jni \
	--enable-libx264 \
	--enable-libvpx \
	--enable-encoder=libx264 \
	--enable-decoder=h264 \
	--enable-encoder=libvpx_vp8 \
	--enable-decoder=vp8 \
	--enable-encoder=libvpx_vp9 \
	--enable-decoder=vp9 \
	--enable-decoder=rawvideo \
	--enable-indev=android_camera \
	--enable-small \
	--enable-gpl \
	--disable-programs \
	--disable-doc \
	--disable-debug \
	--extra-cflags="-I$(PWD)/x264 -I$(PWD)/vpx" \
	--extra-ldflags="-L$(PWD)/x264 -L$(PWD)/vpx/build_tmp" \
	--cc=$(CC) \
	--strip=$(STRIP) && \
	CC="$(CC) --sysroot $(SYSROOT) --extra-cflags=-fno-integrated-as" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) \
	make -j$(CPU_COUNT)

install-ffmpeg: ffmpeg
	rm -rf $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	cp vpx/build_tmp/libvpx.a $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	cp x264/libx264.a $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/ffmpeg/include/libavcodec
	cp ffmpeg/libavcodec/libavcodec.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libavcodec/jni.h $(OUTPUT_DIR)/ffmpeg/include/libavcodec
	cp ffmpeg/libavutil/libavutil.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libswresample/libswresample.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libavformat/libavformat.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libavdevice/libavdevice.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libavfilter/libavfilter.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libswscale/libswscale.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg/libpostproc/libpostproc.a $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)

libre.a: Makefile
	make distclean -C re
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) make $@ -C re $(COMMON_FLAGS)

librem.a: Makefile libre.a
	make distclean -C rem
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) make $@ -C rem $(COMMON_FLAGS)

libbaresip: Makefile openssl opus amr spandsp g7221 ilbc webrtc zrtp ffmpeg librem.a libre.a
	make distclean -C baresip
	PKG_CONFIG_LIBDIR=$(PKG_CONFIG_LIBDIR) PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) CXX=$(CXX) \
	make libbaresip.a -C baresip $(COMMON_FLAGS) STATIC=1 AMR_PATH=$(PWD)/amr LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem MOD_AUTODETECT= BASIC_MODULES=no EXTRA_MODULES="$(EXTRA_MODULES)"

install-libbaresip: Makefile libbaresip
	rm -rf $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	cp re/libre.a $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	cp rem/librem.a $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	cp baresip/libbaresip.a $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/re/include
	mkdir -p $(OUTPUT_DIR)/re/include
	cp re/include/* $(OUTPUT_DIR)/re/include
	rm -rf $(OUTPUT_DIR)/rem/include
	mkdir $(OUTPUT_DIR)/rem/include
	cp rem/include/* $(OUTPUT_DIR)/rem/include
	rm -rf $(OUTPUT_DIR)/baresip/include
	mkdir $(OUTPUT_DIR)/baresip/include
	cp baresip/include/baresip.h $(OUTPUT_DIR)/baresip/include

install-all-libbaresip:
	make install-libbaresip ANDROID_TARGET_ARCH=armeabi-v7a
	make install-libbaresip ANDROID_TARGET_ARCH=arm64-v8a

install: install-openssl install-opus install-spandsp install-g7221 \
	install-ilbc install-amr install-webrtc install-zrtp \
	install-ffmpeg install-libbaresip

install-all:
	make install ANDROID_TARGET_ARCH=armeabi-v7a
	make install ANDROID_TARGET_ARCH=arm64-v8a

.PHONY: download-sources
download-sources:
	rm -fr baresip re rem openssl opus* tiff spandsp g7221 ilbc amr webrtc \
	master.zip libzrtp-master zrtp
	git clone https://github.com/baresip/baresip.git
	git clone https://github.com/creytiv/rem.git
	git clone https://github.com/creytiv/re.git
	git clone https://github.com/openssl/openssl.git -b OpenSSL_1_1_1-stable openssl
	wget https://downloads.xiph.org/releases/opus/opus-1.3.1.tar.gz
	tar zxf opus-1.3.1.tar.gz
	rm opus-1.3.1.tar.gz
	mv opus-1.3.1 opus
	git clone https://gitlab.com/libtiff/libtiff.git -b v4.0.10 --single-branch tiff
	git clone https://github.com/juha-h/spandsp.git -b 1.0 --single-branch spandsp
	git clone https://github.com/juha-h/libg7221.git -b 2.0 --single-branch g7221
	git clone https://github.com/juha-h/libilbc.git -b 1.0 --single-branch ilbc
	wget https://sourceforge.net/projects/opencore-amr/files/opencore-amr/opencore-amr-0.1.5.tar.gz
	tar zxf opencore-amr-0.1.5.tar.gz
	rm opencore-amr-0.1.5.tar.gz
	mv opencore-amr-0.1.5 amr
	git clone https://github.com/juha-h/libwebrtc.git -b 2.0 --single-branch webrtc
	git clone https://github.com/juha-h/libzrtp.git -b 1.0 --single-branch zrtp
	git clone https://github.com/webmproject/libvpx -b v1.8.2 --single-branch vpx
	git clone https://code.videolan.org/videolan/x264.git -b stable --single-branch x264
	git clone https://github.com/FFmpeg/FFmpeg.git -b release/4.2 --single-branch ffmpeg
	patch -d ffmpeg -p1 < ffmpeg-patch
	patch -d re -p1 < re-patch
	patch -d baresip -p1 < baresip-patch

clean:
	make distclean -C baresip
	make distclean -C rem
	make distclean -C re
	-make distclean -C openssl
	-make distclean -C opus
	-make distclean -C tiff
	-make distclean -C spandsp
	-make distclean -C g7221
	make clean -C ilbc
	-make distclean -C amr
	rm -rf webrtc/obj
	-make distclean -C zrtp
	rm -rf vpx/build_tmp
	-make distclean -C x264
	-make distclean -C ffmpeg
