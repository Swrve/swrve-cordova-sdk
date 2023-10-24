#!/usr/bin/env bash

set -e
set -x

cd public/tests
cordova platform add android@12.0.1
cd platforms/android/app/src
mkdir androidTest
cp -r ../../../../platform_test_files/android/androidTest/java ./androidTest/
cd ../
cp ../../../platform_test_files/android/google-services.json .
cp ../../../platform_test_files/android/build-extras.gradle .
cp ../../../platform_test_files/android/AndroidManifest.xml src/main

# TODO This test script originally didn't use hooks - but now uses some of the hooks. Migrate the above to hooks so they don't need copied.
# cp ../../../platform_test_files/android/Application.java src/main/java/com/swrve/cordova/tests