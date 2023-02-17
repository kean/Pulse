ROOT="./.build/xcframeworks"

rm -rf $ROOT

for SDK in iphoneos iphonesimulator macosx appletvos appletvsimulator watchos watchsimulator
do
xcodebuild archive \
    -scheme PulseUI \
    -archivePath "$ROOT/pulse-$SDK.xcarchive" \
    -sdk $SDK \
    SKIP_INSTALL=NO \
    BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
    DEBUG_INFORMATION_FORMAT=DWARF
done

xcodebuild -create-xcframework \
    -framework "$ROOT/pulse-iphoneos.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-iphonesimulator.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -output "$ROOT/Pulse.xcframework"

xcodebuild -create-xcframework \
    -framework "$ROOT/pulse-iphoneos.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-iphonesimulator.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -output "$ROOT/PulseUI.xcframework"

cd $ROOT
zip -r -X pulse-xcframeworks-ios.zip *.xcframework
rm -rf *.xcframework
cd -

xcodebuild -create-xcframework \
    -framework "$ROOT/pulse-iphoneos.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-iphonesimulator.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-macosx.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-appletvos.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-appletvsimulator.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-watchos.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -framework "$ROOT/pulse-watchsimulator.xcarchive/Products/Library/Frameworks/Pulse.framework" \
    -output "$ROOT/Pulse.xcframework"

xcodebuild -create-xcframework \
    -framework "$ROOT/pulse-iphoneos.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-iphonesimulator.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-macosx.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-appletvos.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-appletvsimulator.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-watchos.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -framework "$ROOT/pulse-watchsimulator.xcarchive/Products/Library/Frameworks/PulseUI.framework" \
    -output "$ROOT/PulseUI.xcframework"

cd $ROOT
zip -r -X pulse-xcframeworks-all-platforms.zip *.xcframework
rm -rf *.xcframework
cd -

mv $ROOT/*.zip ./
