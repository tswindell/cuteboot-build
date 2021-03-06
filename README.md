# Introduction

The cuteboot project aims to provide the ability to replace any normal Android based software installation, with a Qt based platform and user interface. Given a device running Android, and, the factory installed boot.img for your device. You will be able to replace the Android application stack, with a Qt based solution.

# Prerequisites

* An Android device you'd like to "infect" :)
* A repo-checked out Android source tree matching your target device. (Or well enough, i.e. same AOSP version/build)
* A repo-checked out cuteboot manifest (see github.com/cuteboot/manifest)

# Building

## Android Sources

To build the Qt platform adaptation, we need parts of the Android tree which we link against or use. In order for Qt to be able to integrate with the device hardware successfully, we have to build identical, or at least API & ABI compatible versions of these Android components. This is why it is important that you've checked out the correct Android source branch.

From within the Android sources:
```
$ . build/envsetup.sh
$ lunch (and select something suitable to your device (TBD: how?), e.g. aosp-arm-eng)
$ pushd system/core
$ patch -p1 < $CUTEBOOT_PATH/build/aosp-patches/aosp501-system-core-init-noselinux.patch (TBD: would be nice to script this)
$ popd
$ make -j14 libc libstlport liblog libz libm libdl libui libgui libutils libcutils libEGL libGLESv2 make_ext4fs init mkbootimg su
```

## Cuteboot Platform & Support

You will need to build the base Qt libraries and various supporting libs and tools which compose the platform. This part of the installation is not device dependant, though these parts are built to match the device's CPU architecture.

This should be done from within your cuteboot sources:
```
$ . build/cbenv.sh
$ cb_select arm
$ make -j14
```

## Qt Platform Adaptation

Now we build the Qt platform adaptation using the Android build we performed earlier. This part of the platform *is* device dependant, in so much as it is built against the specific Android version for your device.

This should be done from within your cuteboot sources:

```
$ make hwdep
```

## Cuteboot Image

To be able to infect the device with the Qt platform and framework we've just built, we need to generate a flashable image. This image is flashed onto a devices cache partition.

(*Note: By flashing this image to the device, you make the device incapable of booting back to Android without erasing the cache partition.*)

To create the cuteboot platform image, from inside the cuteboot sources run:

```
$ make cuteboot.img
```

Once this is completed, you should have a fancy sparse image you can flash to your device with:

```
$ fastboot flash cache cuteboot.img
```

## Device "boot.img" Modification

Grab a boot.img matching the currently installed software on the device.
This can be done on a rooted device with extraction of the boot partition
usually, or through factory image with a bit of luck.

Unpack it with build/split_bootimg.pl and note the name of the ramdisk.gz

```
$ mkdir -p ramdisk
$ cd ramdisk
$ gzip -dc ../the-ramdisk.gz | cpio -idv
```

edit default.prop:

* make sure ro.secure=0
* make sure ro.debuggable=1
* switch ro.zygote to be =cuteboot  (so it doesn't try to start dalvik) 
* make sure ro.adb.secure=0 and is there
* add persist.sys.usb.config=mtp,adb

find any fstab files:

* make /cache partition mount on /usr instead
* make sure /usr doesn't have nosuid, or ro, or nodev

open init.rc:

* disable bootanimation service like this:

```
#service bootanim /system/bin/bootanimation
#    class core
#    user graphics
#    group graphics audio
#    disabled
#    oneshot
```

copy build/init.cuteboot.rc to same location as init.rc is in

```
$ chmod 0750 init.cuteboot.rc
```

Copy $ANDROID_PRODUCT_OUT/root/init on top of init (this disables selinux which is a PITA)

re-make the ramdisk like this:

```
$ find . -print |cpio -H newc -o |gzip -9 > ../the-ramdisk.gz
```

and re-make the boot.img using the instructions split_bootimg.pl gave

# Installing

## Flashing device with fastboot

```
$ fastboot oem unlock
$ fastboot flash cache cuteboot.img
$ fastboot boot boot.img 
```

## adb'ing in

```
$ adb shell
```

run /usr/bin/su to make sure you can get root privileges

## trying out cuteboot

* download http://qtl.me/minimer3.tar.gz
* untar it

```
$ adb push minimer /usr/tmp
$ adb shell
```

```
$ /usr/bin/su
$ cd /usr/tmp
$ QT_QPA_PLATFORM=eglfs QT_QPA_GENERIC_PLUGINS=EvdevTouch QT_QPA_FONTDIR=/system/fonts LD_LIBRARY_PATH=/usr/lib:/system/lib:/vendor/lib QT_QPA_EGLFS_INTEGRATION=eglfs_surfaceflinger QT_QPA_EGLFS_HIDECURSOR=1 QT_QPA_EGLFS_DEBUG=1 QT_DEBUG_PLUGINS=1 /usr/lib/qt5/bin/qmlscene main.qml
```

If you're lucky, you should now see a spinning blue image.

