# -------------------- VALUES TO CONFIGURE --------------------

# Path to Android NDK
# NDK version must match ndkVersion in app/build.gradle
NDK_PATH  := /opt/Android/ndk/$(shell sed -n '/ndkVersion/p' /usr/src/baresip-studio/app/build.gradle | sed 's/[^0-9.]*//g')

# Android API level
API_LEVEL := 24

# Set default from following values: [armeabi-v7a, arm64-v8a, x86_64]
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
	MARCH        := armv7-a
	VPX_TARGET   := armv7-android-gcc
	AOM_TARGET_CPU   := armv7
	DISABLE_NEON := --disable-neon
	FFMPEG_LIB   := $(PWD)/ffmpeg-kit/prebuilt/android-arm
	FFMPEG_DIS   := --disable-arm64-v8a --disable-x86-64 
else
ifeq ($(ANDROID_TARGET_ARCH), arm64-v8a)
	TARGET       := aarch64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := arm
	OPENSSL_ARCH := android-arm64
	MARCH        := armv8-a
	VPX_TARGET   := arm64-android-gcc
	AOM_TARGET_CPU   := arm64
	DISABLE_NEON :=
	FFMPEG_LIB   := $(PWD)/ffmpeg-kit/prebuilt/android-arm64
	FFMPEG_DIS   := --disable-arm-v7a --disable-x86-64
else
ifeq ($(ANDROID_TARGET_ARCH), x86_64)
	TARGET       := x86_64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := x86
	OPENSSL_ARCH := android-x86_64
	MARCH        := x86-64
	VPX_TARGET   := x86_64-android-gcc
	AOM_TARGET_CPU   := x86_64
	DISABLE_NEON :=
	FFMPEG_LIB   := $(PWD)/ffmpeg-kit/prebuilt/android-x86_64
	FFMPEG_DIS   := --disable-arm-v7a --disable-arm64-v8a
else
	exit 1
endif
endif
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

# Compiler and Linker Flags for re and baresip
#
# NOTE: use -isystem to avoid warnings in system header files
COMMON_CFLAGS := -isystem $(SYSROOT)/usr/include -fPIE -fPIC -march=$(MARCH)

LFLAGS := -fPIE -pie

COMMON_FLAGS := \
	EXTRA_CFLAGS="$(COMMON_CFLAGS) -DANDROID" \
	EXTRA_CXXFLAGS="$(COMMON_CFLAGS) -DANDROID -DHAVE_PTHREAD" \
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
	USE_OPENSSL_SRTP=yes

CMAKE_ANDROID_FLAGS := \
	-DANDROID=ON \
	-DANDROID_PLATFORM=$(API_LEVEL) \
	-DCMAKE_SYSTEM_NAME=Android \
	-DCMAKE_SYSTEM_VERSION=$(API_LEVEL) \
	-DCMAKE_TOOLCHAIN_FILE=$(CMAKE_TOOLCHAIN_FILE) \
	-DANDROID_ABI=$(ANDROID_TARGET_ARCH) \
	-DCMAKE_ANDROID_ARCH_ABI=$(ANDROID_TARGET_ARCH) \
	-DCMAKE_SKIP_INSTALL_RPATH=ON \
	-DCMAKE_C_COMPILER=$(CC) \
	-DCMAKE_CXX_COMPILER=$(CXX) \
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON \
	-DCMAKE_BUILD_TYPE=Release

MODULES := "webrtc_aecm;opensles;dtls_srtp;opus;g711;g722;g7221;g726;codec2;amr;gzrtp;stun;turn;ice;presence;mwi;account;natpmp;srtp;uuid;sndfile;debug_cmd;avcodec;avformat;vp8;vp9;selfview;av1;snapshot"

APP_MODULES := "g729"

default: all

.PHONY: amr
amr:
	cd amr && \
	rm -rf lib include && \
	autoreconf --install && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CXXFLAGS=-fPIC --prefix=$(PWD)/amr && \
	make clean && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	make install
	cd vo-amrwbenc && \
	rm -rf include && \
	autoreconf --install && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) CC=$(CC) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CFLAGS=-fPIC CXXFLAGS=-fPIC --prefix=$(PWD)/vo-amrwbenc && \
	make clean && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	make install
	rm -rf $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH) 
	mkdir -p $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)
	cp amr/amrnb/.libs/libopencore-amrnb.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrnb.a
	cp amr/amrwb/.libs/libopencore-amrwb.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrwb.a
	cp vo-amrwbenc/.libs/libvo-amrwbenc.a $(OUTPUT_DIR)/amr/lib/$(ANDROID_TARGET_ARCH)/libamrwbenc.a

.PHONY: codec2
codec2:
	cd codec2 && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. -DBUILD_SHARED_LIBS=OFF $(CMAKE_ANDROID_FLAGS) && \
	cmake --build . --target codec2 -j$(CPU_COUNT) && \
	cp ../src/codec2.h codec2
	rm -rf $(OUTPUT_DIR)/codec2/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/codec2/lib/$(ANDROID_TARGET_ARCH)
	cp codec2/build/src/libcodec2.a $(OUTPUT_DIR)/codec2/lib/$(ANDROID_TARGET_ARCH)

.PHONY: g729
g729:
	-make clean -C bcg729
	cd  bcg729/build && \
	find . -maxdepth 1 ! -name CMakeLists.txt -type f -delete && \
	rm -rf build CMakeFiles include src && \
	cmake ..  $(CMAKE_ANDROID_FLAGS) && \
	cmake --build . --target bcg729-static -j$(CPU_COUNT)
	rm -rf $(OUTPUT_DIR)/g729/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/g729/lib/$(ANDROID_TARGET_ARCH)
	cp bcg729/build/src/libbcg729.a $(OUTPUT_DIR)/g729/lib/$(ANDROID_TARGET_ARCH)

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
	rm -rf $(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)
	cp g7221/src/.libs/libg722_1.a $(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)

.PHONY: gzrtp
gzrtp:
	cd zrtpcpp && \
	rm -rf build && \
	mkdir build && \
	cd build && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	sed -i -e 's/;-lpthread//' CMakeCache.txt && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	cmake --build . -j$(CPU_COUNT)
	rm -rf $(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)
	cp zrtpcpp/build/clients/no_client/libzrtpcppcore.a $(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)

.PHONY: openssl
openssl:
	-make distclean -C openssl
	cd openssl && \
	ANDROID_NDK_ROOT=$(NDK_PATH) PATH=$(PATH) ./Configure $(OPENSSL_ARCH) no-shared no-tests -U__ANDROID_API__ -D__ANDROID_API__=$(API_LEVEL) && \
	make build_libs
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
	mkdir -p include_opus/opus && \
	cp include/* include_opus/opus
	rm -rf $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)
	cp opus/.libs/libopus.a $(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)

.PHONY: sndfile
sndfile:
	cd sndfile && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	cmake --build . --target sndfile -j$(CPU_COUNT)
	rm -rf $(OUTPUT_DIR)/sndfile/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/sndfile/lib/$(ANDROID_TARGET_ARCH)
	cp sndfile/build/libsndfile.a $(OUTPUT_DIR)/sndfile/lib/$(ANDROID_TARGET_ARCH)

.PHONY: spandsp
spandsp: tiff
	-make distclean -C spandsp
	cd spandsp && \
	touch configure.ac aclocal.m4 configure Makefile.am Makefile.in && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes ./configure --host=arm-linux --enable-builtin-tiff --disable-shared CFLAGS="$(COMMON_CFLAGS)" && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make
	rm -rf $(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)
	cp spandsp/src/.libs/libspandsp.a $(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)

.PHONY: tiff
tiff:
	-make distclean -C tiff
	cd tiff && \
	./autogen.sh && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ac_cv_func_malloc_0_nonnull=yes ac_cv_func_realloc_0_nonnull=yes ./configure --host=arm-linux --disable-shared CFLAGS="$(COMMON_CFLAGS)" && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make

.PHONY: webrtc
webrtc:
	cd webrtc && \
	rm -rf obj && \
	$(NDK_PATH)/ndk-build APP_PLATFORM=android-$(API_LEVEL)
	rm -rf $(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)
	cp webrtc/obj/local/$(ANDROID_TARGET_ARCH)/libwebrtc.a $(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)

.PHONY: vpx
vpx:
	cd vpx && \
	rm -rf obj && \
	cd jni && \
	./libvpx/configure --target=$(VPX_TARGET) --as=yasm \
	--enable-external-build --enable-static --enable-realtime-only \
	--enable-vp8 --enable-vp9 --enable-vp9-highbitdepth \
	--enable-runtime-cpu-detect --enable-better-hw-compatibility \
	--enable-small --disable-neon-dotprod \
	--disable-examples --disable-debug --disable-gprof --disable-gcov \
	--disable-unit-tests --disable-tools --disable-docs --disable-webm-io \
	--disable-internal-stats --disable-debug-libs && \
	$(NDK_PATH)/ndk-build \
		APP_PLATFORM=$(PLATFORM) APP_ABI=$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	cp vpx/obj/local/$(ANDROID_TARGET_ARCH)/libvpx.a $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)

.PHONY: aom
aom:
	cd aom/build && \
	find . -mindepth 1 ! -regex '^./cmake\(/.*\)?' -delete && \
	cmake .. $(CMAKE_ANDROID_FLAGS)	-DAOM_TARGET_CPU=$(AOM_TARGET_CPU) \
		-DBUILD_SHARED_LIBS=OFF -DENABLE_DOCS=0 \
		-DENABLE_TESTS=0 -DENABLE_EXAMPLES=0 -DENABLE_TOOLS=0 && \
	cmake --build . -j$(CPU_COUNT)
	rm -rf $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	cp aom/build/libaom.a $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)

.PHONY: ffmpeg
ffmpeg:
	rm -rf $(FFMPEG_LIB) && \
	cd ffmpeg-kit && \
	ANDROID_SDK_ROOT=/foo/bar \
	ANDROID_NDK_ROOT=$(NDK_PATH) \
	./android.sh --enable-gpl --no-archive \
		$(FFMPEG_DIS) --disable-arm-v7a-neon --disable-x86 \
		--enable-android-media-codec \
		--enable-x264 --enable-x265 --enable-libpng --skip-ffmpeg-kit
	rm -rf $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/x264/lib/libx264.a $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	cp $(FFMPEG_LIB)/x265/lib/libx265.a $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
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

libre.a: Makefile
	cd re && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(NDK_PATH);$(PWD)/openssl" \
		-DOPENSSL_VERSION_MAJOR=3 \
		-DOPENSSL_ROOT_DIR=$(PWD)/openssl && \
	cmake --build . --target re -j$(CPU_COUNT)

libbaresip: Makefile amr g729 codec2 g7221 gzrtp openssl opus sndfile spandsp webrtc vpx aom ffmpeg libre.a
	cd baresip && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(PWD)/amr;$(PWD)/vo-amrwbenc;$(PWD)/openssl;$(FFMPEG_LIB)/ffmpeg;$(FFMPEG_LIB)/libpng" \
		-DSTATIC=ON \
		-Dre_DIR=$(PWD)/re/cmake \
		-DRE_LIBRARY=$(PWD)/re/build/libre.a \
		-DRE_INCLUDE_DIR=$(PWD)/re/include \
		-DOPENSSL_ROOT_DIR=$(PWD)/openssl \
		-DG729_INCLUDE_DIR=$(PWD)/bcg729/include \
		-DOPUS_INCLUDE_DIR=$(PWD)/opus/include_opus \
		-DOPUS_LIBRARY=$(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)/libopus.a \
		-DCODEC2_INCLUDE_DIR=$(PWD)/codec2/build \
		-DCODEC2_LIBRARY=$(OUTPUT_DIR)/codec2/lib/$(ANDROID_TARGET_ARCH)/libcodec2.a \
		-DSPANDSP_INCLUDE_DIR="$(PWD)/spandsp/src;$(PWD)/tiff/libtiff" \
		-DSPANDSP_LIBRARY=$(OUTPUT_DIR)/spandsp/lib/$(ANDROID_TARGET_ARCH)/libspandsp.a \
		-DWEBRTC_AECM_INCLUDE_DIR=$(PWD)/webrtc/include \
		-DWEBRTC_AECM_LIBRARY=$(OUTPUT_DIR)/webrtc/lib/$(ANDROID_TARGET_ARCH)/libwebrtc.a \
		-DG7221_INCLUDE_DIR=$(PWD)/g7221/src \
		-DG7221_LIBRARY=$(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)/libg722_1.a \
		-DGZRTP_INCLUDE_DIR=$(PWD)/zrtpcpp \
		-DGZRTP_LIBRARY="$(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)/libzrtpcppcore.a" \
		-DSNDFILE_INCLUDE_DIR="$(PWD)/sndfile/include" \
		-DSNDFILE_LIBRARIES="$(OUTPUT_DIR)/sndfile/lib/$(ANDROID_TARGET_ARCH)/libsndfile.a" \
		-DVPX_INCLUDE_DIR="$(PWD)/vpx/jni/libvpx" \
		-DVPX_LIBRARY="$(PWD)/vpx/local/$(ANDROID_TARGET_ARCH)/libvpx.a" \
		-DAOM_INCLUDE_DIR="$(PWD)/aom" \
		-DAOM_LIBRARY="$(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)/libaom.a" \
		-DCMAKE_C_COMPILER="clang" \
		-DCMAKE_CXX_COMPILER="clang++" \
		-DAPP_MODULES_DIR=$(PWD)/baresip-app-modules \
		-DAPP_MODULES=$(APP_MODULES) \
		-DMODULES=$(MODULES) && \
	cmake --build . --target baresip -j$(CPU_COUNT)
	rm -rf $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	cp re/build/libre.a $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	cp baresip/build/libbaresip.a $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/re/include
	mkdir -p $(OUTPUT_DIR)/re/include
	cp re/include/* $(OUTPUT_DIR)/re/include
	rm -rf $(OUTPUT_DIR)/re/cmake
	mkdir -p $(OUTPUT_DIR)/re/cmake
	cp re/cmake/re-config.cmake $(OUTPUT_DIR)/re/cmake
	rm -rf $(OUTPUT_DIR)/baresip/include
	mkdir $(OUTPUT_DIR)/baresip/include
	cp baresip/include/baresip.h $(OUTPUT_DIR)/baresip/include

all:
	make libbaresip ANDROID_TARGET_ARCH=armeabi-v7a
	make libbaresip ANDROID_TARGET_ARCH=arm64-v8a

.PHONY: download-sources
download-sources:
	rm -fr abseil-cpp amr baresip bcg729 codec2 g7221 openssl opus* \
		re sndfile spandsp tiff vo-amrwbenc webrtc zrtpcpp \
		vpx aom ffmpeg-kit
	git clone https://github.com/abseil/abseil-cpp.git -b lts_2024_01_16 --single-branch
	git clone https://git.code.sf.net/p/opencore-amr/code -b v0.1.6 --single-branch amr
	git clone https://github.com/baresip/baresip.git
	git clone https://github.com/BelledonneCommunications/bcg729.git -b release/1.1.1 --single-branch
	git clone https://github.com/drowe67/codec2.git -b 1.2.0 --single-branch
	git clone https://github.com/juha-h/libg7221.git -b master --single-branch g7221
	git clone https://github.com/openssl/openssl.git -b openssl-3.1.0 --single-branch openssl
	git clone https://github.com/xiph/opus.git -b v1.4 --single-branch
	git clone https://github.com/baresip/re.git
	git clone https://github.com/juha-h/libsndfile.git -b master --single-branch sndfile
	git clone https://github.com/juha-h/spandsp.git -b 1.0 --single-branch spandsp
	git clone https://gitlab.com/libtiff/libtiff.git -b v4.5.0 --single-branch tiff
	git clone https://github.com/juha-h/libwebrtc.git -b mobile --single-branch webrtc
	git clone https://git.code.sf.net/p/opencore-amr/vo-amrwbenc --single-branch vo-amrwbenc
	cp -r abseil-cpp/absl webrtc/jni/src/webrtc
	git clone https://github.com/juha-h/ZRTPCPP.git -b master --single-branch zrtpcpp
	patch -d re -p1 < re-patch
	git clone https://github.com/juha-h/libvpx-build.git -b master --single-branch vpx
	git clone https://github.com/webmproject/libvpx.git -b v1.14.0 -b v1.13.1 --single-branch vpx/jni/libvpx
	git clone https://aomedia.googlesource.com/aom -b v3.8.1 --single-branch
	git clone https://github.com/arthenica/ffmpeg-kit.git -b development --single-branch
	patch -d re -p1 < re-patch
	patch -d ffmpeg-kit -p1 < ffmpeg.sh-patch

clean:
	-make distclean -C amr
	make distclean -C baresip
	rm -rf codec2/build
	-make distclean -C g7221
	-make clean -C bcg729
	-make distclean -C openssl
	-make distclean -C opus
	make distclean -C re
	rm -rf sndfile/build
	-make distclean -C spandsp
	-make distclean -C tiff
	rm -rf webrtc/obj
	rm -rf zrtpcpp/build
	rm -rf vpx/obj
	find vpx/jni -not -name 'Android.mk' -not -name 'Application.mk' -delete
	find aom/build -mindepth 1 ! -regex '^aom/build/cmake\(/.*\)?' -delete
	rm -rf ffmpeg-kit/prebuilt
