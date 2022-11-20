# R18 Comic 

A R18 Comic Flutter App project.
lean flutter & dart project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## debug run

| platform-name | platform-value |
|--|--|
| Windows (desktop) | windows |
| Edge (web) | edge |


```sh
flutter run $--target-platform
```

## build

Optimize package size where target platform!

```sh
flutter build apk --target-platform android-arm,android-arm64,android-x64 --split-per-abi
```
Optimize package size where confuse code !
```sh
flutter build apk --obfuscate --split-debug-info=debugInfo
```
Recommended
```sh
flutter build apk --obfuscate --split-debug-info=debugInfo --target-platform android-arm64 --split-per-abi
```