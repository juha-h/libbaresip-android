# -------------------- VALUES TO CONFIGURE --------------------

# Path to Android SDK
SDK_PATH := /opt/Android

# Path to Android NDK
# NDK version must match ndkVersion in app/build.gradle.kts
NDK_PATH  := /opt/Android/ndk/$(shell sed -n '/ndkVersion/p' /usr/src/baresip-studio/app/build.gradle.kts | sed 's/[^0-9.]*//g')

# Android API level
API_LEVEL := 28

# Set default from following values: [armeabi-v7a, arm64-v8a, x86_64]
ANDROID_TARGET_ARCH := arm64-v8a

# Directory where libraries and include files are installed
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
else
ifeq ($(ANDROID_TARGET_ARCH), arm64-v8a)
	TARGET       := aarch64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := arm
	OPENSSL_ARCH := android-arm64
	MARCH        := armv8-a
else
ifeq ($(ANDROID_TARGET_ARCH), x86_64)
	TARGET       := x86_64-linux-android
	CLANG_TARGET := $(TARGET)
	ARCH         := x86
	OPENSSL_ARCH := android-x86_64
	MARCH        := x86-64
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

# Android cmake flags
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

MODULES := "augain;aaudio;dtls_srtp;opus;g711;libg722;g7221;codec2;amr;gzrtp;stun;turn;ice;presence;mwi;account;natpmp;srtp;uuid;sndfile;debug_cmd;avcodec;avformat;vp8;vp9;selfview;av1;snapshot"

APP_MODULES := "g729"

default: all

.PHONY: amr
amr:
	cd amr && \
	rm -rf lib include && \
	autoreconf --install && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CXXFLAGS="-fPIC -O3" --prefix=$(PWD)/amr && \
	make clean && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make && \
	make install
	cd vo-amrwbenc && \
	rm -rf include && \
	autoreconf --install && \
	CC="$(CC) --sysroot $(SYSROOT)" CXX=$(CXX) CC=$(CC) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared CFLAGS="-fPIC -O3" CXXFLAGS="-fPIC -O3" --prefix=$(PWD)/vo-amrwbenc && \
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
	rm -rf build && mkdir build && cd build && \
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

.PHONY: g722
g722:
	cd g722 && \
	rm -rf build && mkdir build && cd build && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	cmake --build . -j$(CPU_COUNT) && \
	rm -rf $(OUTPUT_DIR)/g722/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/g722/lib/$(ANDROID_TARGET_ARCH)
	cp g722/build/libg722.a $(OUTPUT_DIR)/g722/lib/$(ANDROID_TARGET_ARCH)

.PHONY: g7221
g7221:
	-make distclean -C g7221
	cd g7221 && \
	./autogen.sh && \
	CC="$(CC) --sysroot $(SYSROOT)" \
	RANLIB=$(RANLIB) AR=$(AR) PATH=$(BIN):$(PATH) \
	ac_cv_func_malloc_0_nonnull=yes \
	./configure --build=x86_64 --host=$(TARGET) --disable-shared CFLAGS="-fPIC -O3" && \
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
	ANDROID_NDK_ROOT=$(NDK_PATH) PATH=$(PATH) ./Configure $(OPENSSL_ARCH) -U__ANDROID_API__ -D__ANDROID_API__=$(API_LEVEL) no-apps no-asm no-docs no-engine no-gost no-legacy no-shared no-ssl no-tests no-zlib && \
	make -j$(CPU_COUNT) && \
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
	./autogen.sh && \
	CC="$(CC) --sysroot $(SYSROOT)" CC=$(CC) RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) ./configure --host=$(TARGET) --disable-shared --disable-doc --disable-extra-programs CFLAGS="-fPIC -O3" && \
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

.PHONY: png
png:
	echo "CC = $(CC)"
	- make distclean -C png
	cd png && \
	NDK=$(NDK_PATH) \
	API=$(API_LEVEL) \
	CC=$(TOOLCHAIN)/bin/$(CLANG_TARGET)$(API_LEVEL)-clang \
	./configure --host $(TARGET) --prefix=$(PWD)/png/output/$(ANDROID_TARGET_ARCH) --enable-pic --enable-shared=no CFLAGS="-O3" && \
	make -j$(CPU_COUNT)
	mv png/.libs/libpng16.a png/.libs/libpng.a
	rm -rf $(OUTPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)
	cp png/.libs/libpng.a $(OUTPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)/libpng.a

.PHONY: ffmpeg
ffmpeg:
	cd ffmpeg-android-maker && \
	ANDROID_SDK_HOME=$(SDK_PATH) \
	ANDROID_NDK_HOME=$(NDK_PATH) \
	./ffmpeg-android-maker.sh --target-abis=$(ANDROID_TARGET_ARCH) --android-api-level=$(API_LEVEL) --enable-libvpx --enable-libaom --enable-libx264 --enable-libx265
	rm -rf $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/lib/libx264.a $(OUTPUT_DIR)/x264/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/x264/include
	mkdir -p $(OUTPUT_DIR)/x264/include
	cp -r ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/include/x264*.h $(OUTPUT_DIR)/x264/include
	rm -rf $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/lib/libx265.a $(OUTPUT_DIR)/x265/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/lib/libaom.a $(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/aom/include
	mkdir -p $(OUTPUT_DIR)/aom/include
	cp -r ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/include/aom $(OUTPUT_DIR)/aom/include
	rm -rf $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/lib/libvpx.a $(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/vpx/include/
	mkdir -p $(OUTPUT_DIR)/vpx/include
	cp -r ffmpeg-android-maker/build/external/$(ANDROID_TARGET_ARCH)/include/vpx $(OUTPUT_DIR)/vpx/include
	rm -rf $(OUTPUT_DIR)/ffmpeg/include
	mkdir -p $(OUTPUT_DIR)/ffmpeg/include
	cp -r ffmpeg-android-maker/build/ffmpeg/$(ANDROID_TARGET_ARCH)/include/* $(OUTPUT_DIR)/ffmpeg/include
	rm -rf $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)
	cp ffmpeg-android-maker/output/lib/$(ANDROID_TARGET_ARCH)/*.so $(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)

.PHONY: libyuv
libyuv:
	cd libyuv && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	make -j$(CPU_COUNT)
	rm -rf $(OUTPUT_DIR)/libyuv/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/libyuv/lib/$(ANDROID_TARGET_ARCH)
	cp libyuv/build/libyuv.a $(OUTPUT_DIR)/libyuv/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/libyuv/include
	mkdir -p $(OUTPUT_DIR)/libyuv/include
	cp -r libyuv/include/* $(OUTPUT_DIR)/libyuv/include

libre.a: Makefile
	cd re && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(NDK_PATH);$(PWD)/openssl" \
		-DOPENSSL_VERSION_MAJOR=3 \
		-DOPENSSL_ROOT_DIR=$(PWD)/openssl && \
	cmake --build . --target re -j$(CPU_COUNT)

libbaresip: Makefile amr g729 codec2 g722 g7221 gzrtp openssl opus sndfile png ffmpeg libyuv libre.a
	cd baresip && \
	rm -rf build && rm -rf .cache && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(PWD)/amr;$(PWD)/vo-amrwbenc;$(PWD)/openssl" \
		-DSTATIC=ON \
		-DFFMPEG_avcodec_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libavcodec.so \
		-DFFMPEG_avcodec_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DFFMPEG_avfilter_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libavfilter.so \
		-DFFMPEG_avfilter_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DFFMPEG_avformat_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libavformat.so \
		-DFFMPEG_avformat_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DFFMPEG_swscale_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libswscale.so \
		-DFFMPEG_swscale_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DFFMPEG_swresample_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libswresample.so \
		-DFFMPEG_swresample_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DFFMPEG_avdevice_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libavdevice.so \
		-DFFMPEG_avdevice_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DFFMPEG_avutil_LIBRARY=$(OUTPUT_DIR)/ffmpeg/lib/$(ANDROID_TARGET_ARCH)/libavutil.so \
		-DFFMPEG_avutil_INCLUDE_DIR=$(OUTPUT_DIR)/ffmpeg/include \
		-DVPX_INCLUDE_DIR=$(OUTPUT_DIR)/vpx/include \
		-DVPX_LIBRARY=$(OUTPUT_DIR)/vpx/lib/$(ANDROID_TARGET_ARCH)/libvpx.a \
		-DAOM_INCLUDE_DIR=$(OUTPUT_DIR)/aom/include \
		-DAOM_LIBRARY=$(OUTPUT_DIR)/aom/lib/$(ANDROID_TARGET_ARCH)/libaom.a \
		-DPNG_INCLUDE_DIR=$(PWD)/png \
		-DPNG_LIBRARY=$(OUPUT_DIR)/png/lib/$(ANDROID_TARGET_ARCH)/libpng.a \
		-DAAUDIO_INCLUDE_DIR=${TOOLCHAIN}/sysroot/usr/include \
		-DAAUDIO_LIBRARY=${TOOLCHAIN}/sysroot/usr/lib/$(TARGET)/$(API_LEVEL)/libaaudio.so \
		-Dre_DIR=$(PWD)/re/cmake \
		-DRE_LIBRARY=$(PWD)/re/build/libre.a \
		-DRE_INCLUDE_DIR=$(PWD)/re/include \
		-DOPENSSL_ROOT_DIR=$(PWD)/openssl \
		-DG729_INCLUDE_DIR=$(PWD)/bcg729/include \
		-DOPUS_INCLUDE_DIR=$(PWD)/opus/include_opus \
		-DOPUS_LIBRARY=$(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)/libopus.a \
		-DCODEC2_INCLUDE_DIR=$(PWD)/codec2/build \
		-DCODEC2_LIBRARY=$(OUTPUT_DIR)/codec2/lib/$(ANDROID_TARGET_ARCH)/libcodec2.a \
		-DLIBG722_INCLUDE_DIR=$(PWD)/g722 \
		-DLIBG722_LIBRARY=$(OUTPUT_DIR)/g722/lib/$(ANDROID_TARGET_ARCH)/libg722.a \
		-DG7221_INCLUDE_DIR=$(PWD)/g7221/src/g722_1 \
		-DG7221_LIBRARY=$(OUTPUT_DIR)/g7221/lib/$(ANDROID_TARGET_ARCH)/libg722_1.a \
		-DGZRTP_INCLUDE_DIR=$(PWD)/zrtpcpp \
		-DGZRTP_LIBRARY="$(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)/libzrtpcppcore.a" \
		-DSNDFILE_INCLUDE_DIR="$(PWD)/sndfile/include" \
		-DSNDFILE_LIBRARIES="$(OUTPUT_DIR)/sndfile/lib/$(ANDROID_TARGET_ARCH)/libsndfile.a" \
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
	make libbaresip ANDROID_TARGET_ARCH=arm64-v8a
	make libbaresip ANDROID_TARGET_ARCH=armeabi-v7a

debug:	all
	make libbaresip ANDROID_TARGET_ARCH=x86_64

.PHONY: download-sources
download-sources:
	rm -fr amr baresip bcg729 codec2 g722 g7221 openssl opus \
		re sndfile vo-amrwbenc zrtpcpp png ffmpeg-android-maker libyuv
	git clone https://git.code.sf.net/p/opencore-amr/code -b v0.1.6 --single-branch amr
	git clone https://github.com/baresip/baresip.git
	git clone https://github.com/BelledonneCommunications/bcg729.git -b release/1.1.1 --single-branch
	git clone https://github.com/drowe67/codec2.git -b 1.2.0 --single-branch
	git clone https://github.com/sippy/libg722.git -b v1.2.2 --single-branch g722
	git clone https://github.com/freeswitch/libg7221.git -b master --single-branch g7221
	git clone https://github.com/openssl/openssl.git -b openssl-3.5 --single-branch openssl
	git clone https://github.com/xiph/opus.git -b v1.4 --single-branch
	git clone https://github.com/baresip/re.git
	git clone https://github.com/juha-h/libsndfile.git -b master --single-branch sndfile
	git clone https://git.code.sf.net/p/opencore-amr/vo-amrwbenc --single-branch vo-amrwbenc
	git clone https://github.com/juha-h/ZRTPCPP.git -b master --single-branch zrtpcpp
	git clone https://github.com/pnggroup/libpng.git -b v1.6.48 --single-branch png
	git clone https://github.com/Javernaut/ffmpeg-android-maker.git -b master --single-branch
	git clone https://chromium.googlesource.com/libyuv/libyuv
	patch -d g7221 -p1 < g7221-patch
	patch -d re -p1 < re-patch
	patch -d ffmpeg-android-maker -p1 < ffmpeg-android-maker.patch

clean:
	-make distclean -C amr
	make distclean -C baresip
	rm -rf codec2/build
	rm -rf g722/build
	-make distclean -C g7221
	-make clean -C bcg729
	-make distclean -C openssl
	-make distclean -C opus
	make distclean -C re
	rm -rf sndfile/build
	rm -rf zrtpcpp/build
	make distclean -C png
	rm -rf ffmpeg-android-maker/build
	rm -rf ffmpeg-android-maker/stats
	rm -rf ffmpeg-android-maker/output
