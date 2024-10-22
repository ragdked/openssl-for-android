#!/bin/sh
#android ndk 20
ANDROID_NDK=/home/dev/android-ndk-r20
OPENSSL_VERSION=1.1.1b

API_LEVEL=23

BUILD_DIR=/mnt/tmp/buildtmp/Qt/openssl_build
OUT_DIR=~/$OPENSSL_VERSION/openssl_libandroid

BUILD_TARGETS="armeabi armeabi-v7a arm64-v8a x86 x86_64"

if [ ! -d openssl-${OPENSSL_VERSION} ]
then
    if [ ! -f openssl-${OPENSSL_VERSION}.tar.gz ]
    then
        wget https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz || exit 128
    fi
    tar xzf openssl-${OPENSSL_VERSION}.tar.gz || exit 128
fi

cd openssl-${OPENSSL_VERSION} || exit 128


##### Prepare Files #####
sed -i 's/.*-mandroid.*//' Configurations/15-android.conf
patch -p1 -N <<EOP
--- old/Configurations/unix-Makefile.tmpl   2018-09-11 14:48:19.000000000 +0200
+++ new/Configurations/unix-Makefile.tmpl   2018-10-18 09:06:27.282007245 +0200
@@ -43,12 +43,17 @@
      # will return the name from shlib(\$libname) with any SO version number
      # removed.  On some systems, they may therefore return the exact same
      # string.
-     sub shlib {
+     sub shlib_simple {
          my \$lib = shift;
          return () if \$disabled{shared} || \$lib =~ /\\.a$/;
-         return \$unified_info{sharednames}->{\$lib}. \$shlibvariant. '\$(SHLIB_EXT)';
+
+         if (windowsdll()) {
+             return \$lib . '\$(SHLIB_EXT_IMPORT)';
+         }
+         return \$lib .  '\$(SHLIB_EXT_SIMPLE)';
      }
-     sub shlib_simple {
+     
+   sub shlib {
          my \$lib = shift;
          return () if \$disabled{shared} || \$lib =~ /\\.a$/;
EOP

##### remove output-directory #####
rm -rf $OUT_DIR

##### export ndk directory. Required by openssl-build-scripts #####
export ANDROID_NDK

##### build-function #####
build_the_thing() {
    TOOLCHAIN=$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64
    export PATH=$TOOLCHAIN/$TRIBLE/bin:$TOOLCHAIN/bin:"$PATH"
echo $PATH
    make clean
    #./Configure $SSL_TARGET $OPTIONS -fuse-ld="$TOOLCHAIN/$TRIBLE/bin/ld" "-gcc-toolchain $TOOLCHAIN" && \
    ./Configure $SSL_TARGET $OPTIONS -fuse-ld="$TOOLCHAIN/$TRIBLE/bin/ld" && \
    make && \
    make install DESTDIR=$DESTDIR || exit 128
}

##### set variables according to build-tagret #####
for build_target in $BUILD_TARGETS
do
    case $build_target in
    armeabi)
        TRIBLE="arm-linux-androideabi"
        TC_NAME="arm-linux-androideabi-4.9"
        #OPTIONS="--target=armv5te-linux-androideabi -mthumb -fPIC -latomic -D__ANDROID_API__=$API_LEVEL"
        OPTIONS="--target=armv5te-linux-androideabi -mthumb -fPIC -latomic -D__ANDROID_API__=$API_LEVEL"
        DESTDIR="/tmp/$BUILD_DIR/armeabi"
        SSL_TARGET="android-arm"
    ;;
    armeabi-v7a)
        TRIBLE="arm-linux-androideabi"
        TC_NAME="arm-linux-androideabi-4.9"
        OPTIONS="--target=armv7a-linux-androideabi -Wl,--fix-cortex-a8 -fPIC -D__ANDROID_API__=$API_LEVEL"
        DESTDIR="/tmp/$BUILD_DIR/armeabi-v7a"
        SSL_TARGET="android-arm"
    ;;
    x86)
        TRIBLE="i686-linux-android"
        TC_NAME="x86-4.9"
        OPTIONS="-fPIC -D__ANDROID_API__=${API_LEVEL}"
        DESTDIR="/tmp/$BUILD_DIR/x86"
        SSL_TARGET="android-x86"
    ;;
    x86_64)
        TRIBLE="x86_64-linux-android"
        TC_NAME="x86_64-4.9"
        OPTIONS="-fPIC -D__ANDROID_API__=${API_LEVEL}"
        DESTDIR="/tmp/$BUILD_DIR/x86_64"
        SSL_TARGET="android-x86_64"
    ;;
    arm64-v8a)
        TRIBLE="aarch64-linux-android"
        TC_NAME="aarch64-linux-android-4.9"
        OPTIONS="-fPIC -D__ANDROID_API__=${API_LEVEL}"
        DESTDIR="/tmp/$BUILD_DIR/arm64-v8a"
        SSL_TARGET="android-arm64"
    ;;
    esac

    rm -rf $DESTDIR
    build_the_thing
#### copy libraries and includes to output-directory #####
    mkdir -p $OUT_DIR/inc/$build_target
    cp -R $DESTDIR/usr/local/include/* $OUT_DIR/include/$build_target
    mkdir -p $OUT_DIR/lib/$build_target
    cp -R $DESTDIR/usr/local/lib/*.so $OUT_DIR/libs/$build_target
done

echo Success
