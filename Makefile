# -------------------- VALUES TO CONFIGURE --------------------

# Path to Android NDK
# NDK version must match ndkVersion in app/build.gradle
NDK_PATH  := /opt/Android/ndk/$(shell sed -n '/ndkVersion/p' /usr/src/baresip-studio/app/build.gradle | sed 's/[^0-9.]*//g')

# Android API level
API_LEVEL := 21

# Set default from following values: [armeabi-v7a, arm64-v8a, x86_64]
ANDROID_TARGET_ARCH := arm64-v8a

# Directory where libraries and include files are instelled
OUTPUT_DIR := /usr/src/baresip-studio/distribution

# -------------------- GENERATED VALUES --------------------

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

PWD		:= $(shell pwd)

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

MODULES := "webrtc_aecm;opensles;dtls_srtp;opus;g711;g722;g7221;g726;g729;gsm;amr;gzrtp;stun;turn;ice;presence;contact;mwi;account;natpmp;srtp;uuid;debug_cmd"

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
	mkdir -p include_opus/opus && \
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

.PHONY: gzrtp
gzrtp:
	cd ZRTPCPP && \
	rm -rf build && \
	mkdir build && \
	cd build && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	sed -i -e 's/;-lpthread//' CMakeCache.txt && \
	cmake .. $(CMAKE_ANDROID_FLAGS) && \
	CC="$(CC) --sysroot $(SYSROOT)" PATH=$(PATH) VERBOSE=1 make

install-gzrtp: gzrtp
	rm -rf $(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)
	cp ZRTPCPP/build/clients/no_client/libzrtpcppcore.a $(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)

.PHONY: gsm
gsm:
	make clean -C gsm && \
	cd gsm && \
	CC="$(CC) --sysroot $(SYSROOT)" RANLIB=$(RANLIB) AR=$(AR) PATH=$(PATH) make ./lib/libgsm.a $(COMMON_FLAGS)

install-gsm: gsm
	rm -rf $(OUTPUT_DIR)/gsm/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/gsm/lib/$(ANDROID_TARGET_ARCH)
	cp gsm/lib/libgsm.a $(OUTPUT_DIR)/gsm/lib/$(ANDROID_TARGET_ARCH)

libre.a: Makefile
	cd re && \
	rm -rf build && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		$(COMMON_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(NDK_PATH)" \
		-DOPENSSL_CRYPTO_LIBRARY=$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)/libcrypto.a \
		-DOPENSSL_SSL_LIBRARY=$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)/libssl.a \
		-DOPENSSL_INCLUDE_DIR=$(PWD)/openssl/include && \
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) VERBOSE=1 make $(COMMON_FLAGS)

librem.a: Makefile libre.a
	cd rem && \
	rm -rf build && mkdir build && cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		$(COMMON_FLAGS) \
		-Dre_DIR=$(PWD)/re/cmake \
		-DRE_LIBRARY=$(PWD)/re/build/libre.a \
		-DRE_INCLUDE_DIR=$(PWD)/re/include \
		-DOPENSSL_INCLUDE_DIR=$(PWD)/openssl/include && \
	PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) make $(COMMON_FLAGS)

libbaresip: Makefile openssl opus amr spandsp g7221 g729 webrtc gzrtp librem.a libre.a
	cd baresip && \
	rm -rf build && \
	mkdir build && \
	cd build && \
	cmake .. \
		$(CMAKE_ANDROID_FLAGS) \
		$(COMMON_FLAGS) \
		-DCMAKE_FIND_ROOT_PATH="$(PWD)/amr;$(PWD)/vo-amrwbenc" \
		-DSTATIC=ON \
		-Dre_DIR=$(PWD)/re/cmake \
		-DRE_LIBRARY=$(PWD)/re/build/libre.a \
		-DRE_INCLUDE_DIR=$(PWD)/re/include \
		-DREM_LIBRARY=$(PWD)/rem/build/librem.a \
		-DREM_INCLUDE_DIR=$(PWD)/rem/include \
		-DOPENSSL_INCLUDE_DIR=$(PWD)/openssl/include \
		-DOPENSSL_CRYPTO_LIBRARY=$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)/libcrypto.a \
		-DOPENSSL_SSL_LIBRARY=$(OUTPUT_DIR)/openssl/lib/$(ANDROID_TARGET_ARCH)/libssl.a \
		-DG729_INCLUDE_DIR=$(PWD)/bcg729/include \
		-DOPUS_INCLUDE_DIR=$(PWD)/opus/include_opus \
		-DOPUS_LIBRARY=$(OUTPUT_DIR)/opus/lib/$(ANDROID_TARGET_ARCH)/libopus.a \
		-DGSM_INCLUDE_DIR=$(PWD)/gsm/inc \
		-DSPANDSP_INCLUDE_DIRS="$(PWD)/spandsp/src;$(PWD)/tiff/libtiff" \
		-DWEBRTC_AECM_INCLUDE_DIRS=$(PWD)/webrtc/include \
		-DG7221_INCLUDE_DIRS=$(PWD)/g7221/src \
		-DGZRTP_INCLUDE_DIR="$(PWD)/ZRTPCPP" \
		-DGZRTP_LIBRARY="$(OUTPUT_DIR)/gzrtp/lib/$(ANDROID_TARGET_ARCH)/libzrtpcppcore.a" \
		-DGZRTP_INCLUDE_DIRS="$(PWD)/ZRTPCPP;$(PWD)/zZRTPCPP/zrtp;$(PWD)/ZRTPCPP/srtp" \
		-DCMAKE_C_COMPILER="clang" \
		-DCMAKE_CXX_COMPILER="clang++" \
		-DMODULES=$(MODULES) && \
	 PATH=$(PATH) RANLIB=$(RANLIB) AR=$(AR) make baresip $(COMMON_FLAGS)

install-libbaresip: Makefile libbaresip
	rm -rf $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	cp re/build/libre.a $(OUTPUT_DIR)/re/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	cp rem/build/librem.a $(OUTPUT_DIR)/rem/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	mkdir -p $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	cp baresip/build/libbaresip.a $(OUTPUT_DIR)/baresip/lib/$(ANDROID_TARGET_ARCH)
	rm -rf $(OUTPUT_DIR)/re/include
	mkdir -p $(OUTPUT_DIR)/re/include
	cp re/include/* $(OUTPUT_DIR)/re/include
	rm -rf $(OUTPUT_DIR)/rem/include
	mkdir $(OUTPUT_DIR)/rem/include
	cp rem/include/* $(OUTPUT_DIR)/rem/include
	rm -rf $(OUTPUT_DIR)/baresip/include
	mkdir $(OUTPUT_DIR)/baresip/include
	cp baresip/include/baresip.h $(OUTPUT_DIR)/baresip/include

install: install-openssl install-opus install-spandsp install-g7221 \
	install-g729 install-amr install-webrtc install-gzrtp install-gsm \
	install-libbaresip

install-all-libbaresip:
	make install-libbaresip ANDROID_TARGET_ARCH=armeabi-v7a
	make install-libbaresip ANDROID_TARGET_ARCH=arm64-v8a

.PHONY: install-all
install-all:
	make install ANDROID_TARGET_ARCH=armeabi-v7a
	make install ANDROID_TARGET_ARCH=arm64-v8a

.PHONY: download-sources
download-sources:
	rm -fr baresip re rem openssl opus* tiff spandsp g7221 bcg729 \
		amr vo-amrwbenc webrtc abseil-cpp ZRTPCCP gsm
	git clone https://github.com/baresip/baresip.git
	git clone https://github.com/baresip/rem.git
	git clone https://github.com/baresip/re.git
	git clone https://github.com/openssl/openssl.git -b OpenSSL_1_1_1-stable --single-branch openssl
	wget https://ftp.osuosl.org/pub/xiph/releases/opus/opus-1.3.1.tar.gz
	tar zxf opus-1.3.1.tar.gz
	rm opus-1.3.1.tar.gz
	mv opus-1.3.1 opus
	git clone https://gitlab.com/libtiff/libtiff.git -b v4.3.0 --single-branch tiff
	git clone https://github.com/juha-h/spandsp.git -b 1.0 --single-branch spandsp
	git clone https://github.com/juha-h/libg7221.git -b 2.0 --single-branch g7221
	git clone https://github.com/BelledonneCommunications/bcg729.git -b release/1.1.1 --single-branch
	git clone https://git.code.sf.net/p/opencore-amr/code -b v0.1.6 --single-branch amr
	git clone https://git.code.sf.net/p/opencore-amr/vo-amrwbenc --single-branch vo-amrwbenc
	git clone https://github.com/juha-h/libwebrtc.git -b mobile --single-branch webrtc
	git clone https://github.com/abseil/abseil-cpp.git -b lts_2021_11_02 --single-branch
	cp -r abseil-cpp/absl webrtc/jni/src/webrtc
	git clone https://github.com/juha-h/ZRTPCPP.git -b master --single-branch
	git clone https://github.com/juha-h/libgsm.git -b master --single-branch gsm
	patch -d re -p1 < re-patch
	cp -r baresip-g729 baresip/modules/g729
	cp -r baresip-gsm baresip/modules/gsm

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
	rm -rf ZRTPCPP/build
	-make clean -C gsm
