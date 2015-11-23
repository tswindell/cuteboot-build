

CUTEBOOT_BUILD_TOP=$(PWD)

all: sysroot subdirs qmlscene bin/aidl_cpp

SUBDIRS = qtbase qtdeclarative qtmultimedia

.PHONY: subdirs $(SUBDIRS)

subdirs: $(SUBDIRS)

sysroot:
	mkdir -p sysroot/aosp
	mkdir -p sysroot/usr/include
	mkdir -p sysroot/usr/lib
	cp -ar prebuilts/ndk/$(ANDROID_NDK)/platforms/android-$(ANDROID_API_LEVEL)/arch-$(ARCH)/usr/* sysroot/aosp
	cp sysroot/aosp/lib/crt*.o sysroot/usr/lib
	rm -f sysroot/aosp/include/android/*
	# Needed for cdefs.h
	cp prebuilts/ndk/$(ANDROID_NDK)/platforms/android-$(ANDROID_API_LEVEL)/arch-$(ARCH)/usr/include/android/api-level.h sysroot/aosp/include/android/
	# Needed for EGL headers
	cp prebuilts/ndk/$(ANDROID_NDK)/platforms/android-$(ANDROID_API_LEVEL)/arch-$(ARCH)/usr/include/android/native_window.h sysroot/aosp/include/android/
	# Needed for native_window.h
	cp prebuilts/ndk/$(ANDROID_NDK)/platforms/android-$(ANDROID_API_LEVEL)/arch-$(ARCH)/usr/include/android/rect.h sysroot/aosp/include/android/
	# Needed for qt logging
	cp prebuilts/ndk/$(ANDROID_NDK)/platforms/android-$(ANDROID_API_LEVEL)/arch-$(ARCH)/usr/include/android/log.h sysroot/aosp/include/android/
	rm -f sysroot/aosp/lib/libandroid.so
	rm -f sysroot/aosp/lib/libjnigraphics.so
	mkdir -p sysroot/usr/include/gnu-libstdc++/libs
	mkdir -p sysroot/usr/include/gnu-libstdc++/include
	mkdir -p sysroot/usr/lib/gnu-libstdc++
	cp -ar prebuilts/ndk/$(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/$(GCC_VERSION)/libs/$(ANDROID_ABI)/libgnu* sysroot/usr/lib/gnu-libstdc++
	cp -ar prebuilts/ndk/$(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/$(GCC_VERSION)/libs/$(ANDROID_ABI)/libsupc* sysroot/usr/lib/gnu-libstdc++
	cp -ar prebuilts/ndk/$(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/$(GCC_VERSION)/libs/$(ANDROID_ABI)/include/* sysroot/usr/include/gnu-libstdc++/libs/
	cp -ar prebuilts/ndk/$(ANDROID_NDK)/sources/cxx-stl/gnu-libstdc++/$(GCC_VERSION)/include/* sysroot/usr/include/gnu-libstdc++/include
	mkdir -p sysroot/usr/lib/pkgconfig
	mkdir -p sysroot/usr/share/pkgconfig
	mkdir -p sysroot/usr/bin

qtbase: configure-qtbase 
	$(MAKE) -C qtbase-build

	$(MAKE) -C qtbase-build install
	# Fix wrong path in prl files
	find $(PWD)/sysroot/usr/lib -type f -name 'libQt5*.prl' -exec sed -i -e "/^QMAKE_PRL_BUILD_DIR/d;s/\(QMAKE_PRL_LIBS =\).*/\1/" {} \;

configure-qtbase: sysroot
	mkdir -p qtbase-build
	cd qtbase-build; ../qtbase/configure -no-dbus -no-strip -prefix /usr/lib/qt5 -headerdir /usr/include/qt5 -docdir /usr/share/doc/qt5 -hostprefix $(PWD) -opensource -confirm-license -xplatform linux-cuteboot -device-option CROSS_COMPILE=$(CROSS_COMPILE) -device-option "CUTEBOOT_CFLAGS=$(CUTEBOOT_CFLAGS)" -libdir /usr/lib -nomake examples -nomake tests -sysroot $(PWD)/sysroot -no-largefile -v

qtdeclarative: configure-qtdeclarative
	$(MAKE) -C $@
	$(MAKE) -C $@ install

configure-qtdeclarative: sysroot qtbase
	cd qtdeclarative; ../bin/qmake "CONFIG += debug"

qmlscene: configure-qmlscene
	$(MAKE) -C qtdeclarative/tools/qmlscene
	$(MAKE) -C qtdeclarative/tools/qmlscene install

configure-qmlscene: qtdeclarative
	cd qtdeclarative/tools/qmlscene; $(PWD)/bin/qmake "CONFIG += debug"

qtmultimedia: configure-qtmultimedia
	$(MAKE) -C $@
	$(MAKE) -C $@ install

configure-qtmultimedia: sysroot qtbase qtdeclarative
	cd qtmultimedia; ../bin/qmake "CONFIG += debug"


eglfs_surfaceflinger: configure-eglfs_surfaceflinger
	$(MAKE) -C qtbase/src/plugins/platforms/eglfs/deviceintegration/eglfs_surfaceflinger
	$(MAKE) -C qtbase/src/plugins/platforms/eglfs/deviceintegration/eglfs_surfaceflinger install


configure-eglfs_surfaceflinger: qtbase
	cd qtbase/src/plugins/platforms/eglfs/deviceintegration/eglfs_surfaceflinger; $(PWD)/bin/qmake -spec unsupported/android-g++ "CONFIG += debug"	

sysroot/usr/lib/libcutebinder.so:	
	$(MAKE) -C libcutebinder -f Makefile.stubs CUTEBOOT_BUILD_TOP=$(CUTEBOOT_BUILD_TOP)
	cd libcutebinder; $(PWD)/bin/qmake -spec unsupported/android-g++ "CONFIG += debug"
	$(MAKE) -C libcutebinder
	$(MAKE) -C libcutebinder install

sysroot/usr/bin/cutesystemserver: sysroot/usr/lib/libcutebinder.so
	cd cutesystemserver; $(PWD)/bin/qmake -spec unsupported/android-g++ "CONFIG += debug"
	$(MAKE) -C cutesystemserver
	$(MAKE) -C cutesystemserver install

hwdep: eglfs_surfaceflinger sysroot/usr/lib/libcutebinder.so sysroot/usr/bin/cutesystemserver 

bin/aidl_cpp:
	cd aidl_cpp ; \
	$(PWD)/prebuilts/misc/linux-x86/flex/flex-2.5.39 aidl_language_l.l ; \
	$(PWD)/prebuilts/misc/linux-x86/bison/bison --defines=aidl_language_y.hpp --output=aidl_language_y.cpp aidl_language_y.y ; \
	g++ -o aidl_cpp \
			*.cpp lex.yy.c -I. ; \
	mkdir -p $(PWD)/bin ; \
	cp aidl_cpp $(PWD)/bin

cuteboot.img-deps: sysroot
	# Clean build directories
	rm -rf img img-symbols
	mkdir -p img img-symbols
	mkdir -p img/usr/bin
	install -m 777 -d img/usr/tmp
	
	# Copy sysroot content to build directory.
	cp -ar sysroot/* img
	cp img/usr/lib/gnu-libstdc++/libgnustl_shared.so img/usr/lib/
	
	# Remove bits provided by HW adaptation stack
	rm -rf img/aosp
	rm -rf img/usr/include
	rm -rf img/usr/lib/*.a
	rm -rf img/usr/lib/*.o
	rm -rf img/usr/lib/*.la
	rm -rf img/usr/lib/*.prl
	rm -rf img/usr/lib/gnu-libstdc++
	rm -rf img/usr/lib/*android-dependencies.xml
	rm -rf img/usr/lib/pkgconfig
	rm -rf img/usr/lib/cmake
	rm -rf img/usr/share/m4
	rm -rf img/usr/share/gtk-doc
	rm -rf img/usr/share/aclocal*
	rm -rf img/usr/share/gettext
	rm -rf img/usr/share/emacs
	rm -rf img/usr/share/doc
	rm -rf img/usr/share/man
	rm -rf img/usr/share/info
	
	# Copy build contents for debug
	cp -ar img img-symbols
	STRIP=$(CROSS_COMPILE)strip build/strip-shared img
	STRIP=$(CROSS_COMPILE)strip build/strip-executables img
	
	# Install executables
	install -m 4755 $(ANDROID_PRODUCT_OUT)/system/xbin/su img/usr/bin
	du -s -h img
	du -s -h img-symbols

cuteboot.img: cuteboot.img-deps
	rm -f $@
	$(ANDROID_HOST_OUT)/bin/make_ext4fs -l 200M -s $@ img/usr
	du -s -h $@

cuteboot-nosparse.img: cuteboot.img-deps
	rm -f $@
	$(ANDROID_HOST_OUT)/bin/make_ext4fs -l 200M $@ img/usr
	du -s -h $@

