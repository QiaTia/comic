#!/bin/bash
# 打包并自定义文件名
flutter build apk --obfuscate --split-debug-info=debugInfo --target-platform android-arm64 --split-per-abi

# 读取版本号
VERSION=$(grep -o 'version: [0-9.]*' pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)

# 重命名
cp build/app/outputs/flutter-apk/app-arm64-v8a-release.apk build/app/outputs/flutter-apk/app-arm64-v8a_v${VERSION}-release.apk

# 提示
echo &#34;✅ 打包完成！文件路径：&#34;
echo &#34;build/app/outputs/flutter-apk/warm_todo_v${VERSION}-release.apk&#34;
