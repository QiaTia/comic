import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

const themeList = [
  Colors.amber,
  Colors.blue,
  Colors.green,
  Colors.red,
  Colors.purple,
  Colors.pink,
  Colors.deepPurple,
  Colors.deepOrange,
  Colors.brown,
  Colors.cyan,
  Colors.teal,
  Colors.lime,
  Colors.yellow,
  Colors.orange,
  Colors.indigo,
];

const langList = ['中文', 'English', '日本語'];

///  深色模式存储
const _themeMode = '__theme_mode';

/// 当前主题颜色存储
const _themeIndex = '_theme_index';

/// 当前主题颜色存储
const _currentLanguage = '_current_language';

class SetController extends GetxController {
  /// 主题颜色
  var themeIndex = 0.obs;

  /// 是否深色模式
  var themeMode = ThemeMode.system.obs;

  /// 语言
  var currentLanguage = ''.obs;

  /// 设置主题颜色
  setThemeIndex(int i) async {
    if (i > themeList.length) return;
    themeIndex.value = i;
    Get.changeTheme(ThemeData(colorSchemeSeed: themeList[i]));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(_themeIndex, i);
  }

  /// 设置是否深色模式
  setThemeMode(ThemeMode theme) async {
    themeMode.value = theme;
    Get.changeThemeMode(theme);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(_themeMode, theme.toString());
  }

  /// 从系统读取当前是否深色模式
  readThemeMode(SharedPreferences prefs) {
    var theme = ThemeMode.system;
    var local = prefs.getString(_themeMode);
    if (local != null) {
      theme = ThemeMode.values.firstWhere((e) => e.toString() == local);
    } else if (Get.context != null) {
      theme =
          (MediaQuery.of(Get.context!).platformBrightness == Brightness.light)
              ? ThemeMode.light
              : ThemeMode.dark;
    }
    setThemeMode(theme);
  }

  /// 从缓存读取当前主题颜色主键
  readThemeIndex(SharedPreferences prefs) {
    themeIndex.value = prefs.getInt(_themeIndex) ?? 0;
    setThemeIndex(themeIndex.value);
  }

  /// 设置语言
  setLanguage(String language) async {
    currentLanguage.value = language;
    Get.updateLocale(Locale(language));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(_currentLanguage, language);
  }

  /// 从缓存或系统读取当前语言
  readLanguage(SharedPreferences prefs) {
    var lang = prefs.getString(_currentLanguage) ??
        Get.deviceLocale?.languageCode ??
        'zh';
    setLanguage(lang);
  }

  /// 数据初始化
  @override
  onInit() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    readThemeMode(prefs);
    readThemeIndex(prefs);
    readLanguage(prefs);
    super.onInit();
  }
}
