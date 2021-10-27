# -------------------- VALUES TO CONFIGURE --------------------

# Path to your Android NDK (must be r23 or higher)
# This one finds the latest from /opt/Android/ndk directory
NDK_PATH  :=  $(shell ls -d -1 /opt/Android/ndk/* | tail -1)

# Android API level
API_LEVEL := 24

# Set default from following values: [armeabi-v7a, arm64-v8a]
ANDROID_TARGET_ARCH := arm64-v8a

# Directory where libraries and include files are instelled
OUTPUT_DIR := /usr/src/baresip-studio/distribution.video

# -------------------- GENERATED VALUES --------------------

CPU_COUNT	:= $(shell nproc)
PWD		:= $(shell pwd)

ifeq ($(ANDROID_TARGET_ARCH), armeabi-v7a)
	TARGET       := arm-linux-androideabi
	CLANG_TARGET := armv7a-linux-androideabi
	ARCH         := arm
	OPENSSL_ARCH := android-arm
	VPX_TARGET   := armv7-android-gcc
	DISABLE_NEON := --disable-neon
	FFMPEG_ARCH  := arm
	MARCH        := armv7-a
	FFMPEG_LIB   := $(PWD)/ffmpeg-kit/prebuilt/android-arm
	FFMPEG_DIS   := --disable-arm64-v8a
else
	TARGET       := aarch64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := arm
	OPENSSL_ARCH := android-arm64
	VPX_TARGET   := arm64-android-gcc
	DISABLE_NEON :=
	FFMPEG_ARCH  := aarch64
	MARCH        := armv8-a
	FFMPEG_LIB   := $(PWD)/ffmpeg-kit/prebuilt/android-arm64
	FFMPEG_DIS   := --disable-arm-v7a
endif

PLATFORM	:= android-$(API_LEVEL)

OS		:= $(shell uname -s | tr "[A-Z]" "[a-z]")
ifeq ($(OS),linux)
	HOST_OS   := linux-x86_64
endif
ifeq ($(OS),darwin)
	HOST_OS   := darwin-x86_64
endif

# Toolchain and sysroot
TOOLCHAIN	:= $(NDK_PATH)/toolchains/llvm/prebuilt/$(HOST_OS)
CMAKE_TOOLCHAIN_FILE	:= $(NDK_PATH)/build/cmake/android.toolchain.cmake
SYSROOT		:= $(TOOLCHAIN)/sysroot
PKG_CONFIG_LIBDIR	:= $(NDK_PATH)/prebuilt/$(HOST_OS)/lib/pkgconfig

# Toolchain tools
PATH	:= $(TOOLCHAIN)/bin:/usr/bin:/bin
AR	:= llvm-ar
AS	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CC	:= $(CLANG_TARGET)$(API_LEVEL)-clang
CXX	:= $(CLANG_TARGET)$(API_LEVEL)-clang++
LD	:= ld.lld
RANLIB	:= llvm-ranlib
STRIP	:= llvm-strip

# Compiler and Linker Flags for re, rem, and baresip
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT)/usr/include -fPIE -fPIC

CFLAGS := $(COMMON_CFLAGS) \
	-I$(PWD)/openssl/include \
	-I$(PWD)/opus/include_opus \
	-I$(PWD)/g7221/src \
	-I$(PWD)/bcg729/include \
	-I$(PWD)/spandsp/src \
	-I$(PWD)/tiff/libtiff \
	-I$(PWD)/amr/include \
	-I$(PWD)/vo-amrwbenc/include \
	-I$(PWD)/webrtc/include \
	-I$(PWD)/zrtp/include \
	-I$(PWD)/zrtp/third_party/bnlib \
	-I$(PWD)/zrtp/third_party/bgaes \
	-I$(PWD)/ffmpeg-kit/src/libaom \
	-I$(PWD)/ffmpeg-kit/src/libvpx \
	-I$(PWD)/ffmpeg-kit/src/ffmpeg \
	-I$(PWD)/ffmpeg-kit/src/libpng \
	-march=$(MARCH)

LFLAGS := -L$(SYSROOT)/usr/lib/ \
	-L$(PWD)/openssl \
	-L$(PWD)/opus/.libs \
	-L$(PWD)/g7221/src/.libs \
	-L$(PWD)/spandsp/src/.libs \
	-L$(PWD)/amr/lib \
	-L$(PWD)/vo-amrwbenc/.libs \
	-L$(PWD)/bcg729/src \
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
	HAVE_GETIFADDRS=1 \
	PEDANTIC= \
	OS=$(OS) \
	ARCH=$(ARCH) \
	USE_OPENSSL=yes \
	USE_OPENSSL_DTLS=yes \
	USE_OPENSSL_SRTP=yes \
	ANDROID=yes \
	RELEASE=1

EXTRA_MODULES := webrtc_aecm opensles dtls_srtp opus g711 g722 \
	g7221 g726 g729 amr zrtp stun turn ice presence contact mwi account \
	natpmp srtp uuid debug_cmd avcodec avformat vp8 vp9 selfview av1 \
	snapshot

default:
	make libbaresip ANDROID_TARGET_ARCH=$(ANDROID_TARGET_ARCH)

.PHONY: openssl
openssl:
	-make distclean -C openssl
	cd openssl && \
	ANDROID_NDK_HOME=$(NDK_PATH) PATH=$(PATH) ./Configure $(OPENSSL_ARCH) no-shared -U__ANDROID_API__ -D__ANDROID_API__=$(API_LEVEL) && \
	make build_libs

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

.PHONY: g729
g729:
	-make clean -C bcg729
	cd  bcg729/build && \
	find . -maxdepth 1 ! -name CMakeLists.txt -type f -delete && \
	rm -rf build CMakeFiles include src && \
	cmake .. -DANDROID_ABI=${ANDROID_TARGET_ARCH} -DANDROID_PLATFORM=${API_LEVEL} \
		-DCMAKE_SYSTEM_NAME=Android -DCMAKE_SYSTEM_VERSION=$(API_LEVEL) \
		-DCMAKE_TOOLCHAIN_FILE=${CMAKE_TOOLCHAIN_FILE} \
		-DCMAKE_C_COMPILER=$(CC) -DCMAKE_SKIP_INSTALL_RPATH=ON && \
	make

.PHONY: install-g729
install-g729: g729
	rm -rf $(OUTPUT_DIR)/g729/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/g729/lib/$(ANDROID_TARGET_ARCH)
	cp bcg729/build/src/libbcg729.a $(OUTPUT_DIR)/g729/lib/$(ANDROID_TARGET_ARCH)

.PHONY: amr
amr: 
	cd amr && \
	rm -rf lib include && \
	autoreconf --install && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CXXFLAGS=-fPIC --prefix=$(PWD)/amr && \
	make clean && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	make install

.PHONY: vo-amrwbenc
vo-amrwbenc:
	cd vo-amrwbenc && \
	rm -rf include && \
	autoreconf --install && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) CC=$(CC) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CFLAGS=-fPIC CXXFLAGS=-fPIC --prefix=$(PWD)/vo-amrwbenc && \
	make clean && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	make install

.PHONY: install-amr
install-amr: amr vo-amrwbenc
	rm -rf $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)
	cp amr/amrnb/.libs/libopencore-amrnb.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrnb.a
	cp amr/amrwb/.libs/libopencore-amrwb.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrwb.a
	cp vo-amrwbenc/.libs/libvo-amrwbenc.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrwbenc.a

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

.PHONY: ffmpeg
ffmpeg:
	rm -rf $(FFMPEG_LIB) && \
	cd ffmpeg-kit && \
	ANDROID_SDK_ROOT=/foo/bar \
	ANDROID_NDK_ROOT=$(NDK_PATH) \
	./android.sh --enable-gpl --no-archive \
		$(FFMPEG_DIS) --disable-arm-v7a-neon --disable-x86 \
		--disable-x86-64 \
		--enable-libvpx --enable-x264 --enable-x265 --enable-libaom \
		--enable-libpng --skip-ffmpeg-kit

install-ffmpeg: ffmpeg
	rm -rf $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/libvpx/lib/libvpx.a $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/x264/lib/libx264.a $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/x265/lib/libx265.a $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/libaom/lib/libaom.a $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/libpng/lib/libpng.a $(OUTPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/cpu_features/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/cpu_features/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/cpu-features/lib/libcpu_features.a $(OUTPUT_DIR)/cpu_features/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/cpu-features/lib/libndk_compat.a $(OUTPUT_DIR)/cpu_features/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/ffmpeg/include/libavcodec
	cp $(PWD)/ffmpeg-kit/src/ffmpeg/libavcodec/jni.h $(OUTPUT_DIR)/ffmpeg/include/libavcodec
	cp $(FFMPEG_LIB)/ffmpeg/lib/libavcodec.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libavutil.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libswresample.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libavformat.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libavdevice.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libavfilter.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libswscale.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/ffmpeg/lib/libpostproc.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)

libre.a: Makefile
	make distclean -C re
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) make $@ -C re $(COMMON_FLAGS)

librem.a: Makefile libre.a
	make distclean -C rem
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) make $@ -C rem $(COMMON_FLAGS)

libbaresip: Makefile openssl opus amr spandsp g7221 g729 webrtc zrtp ffmpeg librem.a libre.a
	make distclean -C baresip
	PKG_CONFIG_LIBDIR=$(PKG_CONFIG_LIBDIR) PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) CC=$(CC) CXX=$(CXX) \
	make libbaresip.a -C baresip $(COMMON_FLAGS) STATIC=1 AMR_PATH=$(PWD)/amr AMRWBENC_PATH=$(PWD)/vo-amrwbenc LIBRE_SO=$(PWD)/re LIBREM_PATH=$(PWD)/rem MOD_AUTODETECT= BASIC_MODULES=no EXTRA_MODULES="$(EXTRA_MODULES)"

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
	install-g729 install-amr install-webrtc install-zrtp \
	install-ffmpeg install-libbaresip

install-all:
	make install ANDROID_TARGET_ARCH=armeabi-v7a
	make install ANDROID_TARGET_ARCH=arm64-v8a

.PHONY: download-sources
download-sources:
	rm -fr baresip re rem openssl opus* tiff spandsp g7221 bcg729 \
		amr vo-amrwbenc webrtc abseil-cpp master.zip libzrtp-master \
		zrtp ffmpeg-kit
	git clone https://github.com/baresip/baresip.git
	git clone https://github.com/baresip/rem.git
	git clone https://github.com/baresip/re.git
	git clone https://github.com/openssl/openssl.git -b OpenSSL_1_1_1-stable openssl
	wget https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.3.1.tar.gz
	tar zxf opus-1.3.1.tar.gz
	rm opus-1.3.1.tar.gz
	mv opus-1.3.1 opus
	git clone https://gitlab.com/libtiff/libtiff.git -b v4.0.10 --single-branch tiff
	git clone https://github.com/juha-h/spandsp.git -b 1.0 --single-branch spandsp
	git clone https://github.com/juha-h/libg7221.git -b 2.0 --single-branch g7221
	git clone https://github.com/BelledonneCommunications/bcg729.git -b release/1.1.1 --single-branch
	git clone https://github.com/juha-h/opencore-amr.git amr
	git clone https://github.com/juha-h/opencore-vo-amrwbenc.git vo-amrwbenc
	git clone https://github.com/juha-h/libwebrtc.git -b mobile --single-branch webrtc
	git clone https://github.com/abseil/abseil-cpp.git -b lts_2021_03_24 --single-branch
	cp -r abseil-cpp/absl webrtc/jni/src/webrtc
	git clone https://github.com/juha-h/libzrtp.git -b 1.0 --single-branch zrtp
	git clone https://github.com/tanersener/ffmpeg-kit.git -b main
	patch -d re -p1 < re-patch
	patch -d baresip -p1 < baresip-patch
	cp -r baresip-g729 baresip/modules/g729
	patch -d ffmpeg-kit -p1 < ffmpeg.sh-patch

clean:
	make distclean -C baresip
	make distclean -C rem
	make distclean -C re
	-make distclean -C openssl
	-make distclean -C opus
	-make distclean -C tiff
	-make distclean -C spandsp
	-make distclean -C g7221
	-make clean -C bcg729
	-make distclean -C amr
	rm -rf webrtc/obj
	-make distclean -C zrtp
	rm -rf ffmpeg-kit/prebuilt
