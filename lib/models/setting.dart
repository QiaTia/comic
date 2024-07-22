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

///  深色模式存储
const _themeMode = '_theme_mode';

/// 当前主题颜色存储
const _themeIndex = '_theme_index';

/// 当前主题颜色存储
const _currentLanguage = '_current_language';

class SetController extends GetxController {
  /// 主题颜色
  var themeIndex = 0.obs;

  /// 是否深色模式
  var isDark = false.obs;

  /// 语言
  var currentLanguage = 'zh'.obs;

  /// 设置主题颜色
  setThemeIndex(int i) async {
    if (i > themeList.length) return;
    themeIndex.value = i;
    Get.changeTheme(ThemeData(colorSchemeSeed: themeList[i]));
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setInt(_themeIndex, i);
  }

  /// 设置是否深色模式
  setThemeMode(bool dark) async {
    isDark.value = dark;
    Get.changeThemeMode(dark ? ThemeMode.dark : ThemeMode.light);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool(_themeMode, dark);
  }

  /// 从系统读取当前是否深色模式
  readThemeMode(SharedPreferences prefs) {
    isDark.value = prefs.getBool(_themeMode) ?? Get.isDarkMode;
    setThemeMode(isDark.value);
  }

  /// 从缓存读取当前主题颜色主键
  readThemeIndex(SharedPreferences prefs) {
    themeIndex.value = prefs.getInt(_themeIndex) ?? 0;
    setThemeIndex(themeIndex.value);
  }

  /// 设置语言
  setLanguage(String language) async {
    currentLanguage.value = language;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(_currentLanguage, language);
  }

  /// 从缓存或系统读取当前语言
  readLanguage(SharedPreferences prefs) {
    currentLanguage.value = prefs.getString(_currentLanguage) ?? 'zh';
    setLanguage(currentLanguage.value);
  }

  /// 数据初始化
  init() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    readThemeMode(prefs);
    readThemeIndex(prefs);
  }
}
