#!/usr/bin/env bash

set -e
set -x

cd public/tests
cordova platform add android@11.0.0
cd platforms/android/app/src
ln -sf ../../../../platform_test_files/android/androidTest/ .
cd ..
cp ../../../platform_test_files/android/google-services.json .
cp ../../../platform_test_files/android/build-extras.gradle .
cp ../../../platform_test_files/android/Application.java src/main/java/com/swrve/cordova/tests
cp ../../../platform_test_files/android/AndroidManifest.xml src/main
