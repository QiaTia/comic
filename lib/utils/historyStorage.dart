import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryItem {
  // HistoryItem(this.id, this.title, this.image, this.creatAt);
  final String id;
  final String title;
  final String image;
  final int? index;
  final List<String> list;
  final String createdAt;
  HistoryItem(Map<String, dynamic> json)
      : title = json['title'],
        id = json['id'],
        createdAt = json['created_at'] ?? json['creat_at'] ?? '',
        index = json['index'] ?? 0,
        list = (json['list'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        image = json['image'];

  Map<String, dynamic> toJson() => {
        'title': title,
        'id': id,
        'image': image,
        'created_at': createdAt,
        'list': list,
        'index': index,
      };
}

class Storage {
  SharedPreferences? pref;
  List<HistoryItem> historyList = [];
  final String _storageKey = 'history';
  /// 初始化 SharedPreferences 实例
  Storage() {
    _initInstance();
  }
  /// 获取 SharedPreferences 实例
  Future<SharedPreferences> _initInstance() async {
    if (pref != null) {
      return pref!;
    }
    pref = await SharedPreferences.getInstance();
    _getList();
    return pref!;
  }
  /// 获取存储的字符串列表
  Future<List<String>> _getList() async {
    return (await _initInstance()).getStringList(_storageKey) ?? [];
  }

  /// 保存项目到历史记录
  Future<void> save(
      {required String id,
      required String title,
      required String image,
      int? index = 0,
      required List<String> images}) async {
    var fIndex = historyList.indexWhere((element) => element.id == id);
    var newItem = HistoryItem({
      'id': id,
      'title': title,
      'image': image,
      'list': images,
      'created _at': _getCurrentDate(),
      'index': index,
    });
    // 存在提到首位
    if (fIndex != -1) {
      historyList.removeAt(fIndex);
    }
    historyList.add(newItem);
    await saveList();
  }
  /// 保存历史记录列表到本地
  Future<void> saveList() async {
    await (await _initInstance())
        .setStringList(_storageKey, historyList.map((e) => jsonEncode(e)).toList());
  }

  /// 获取序列化列表
  Future<List<HistoryItem>> getList() async {
    var list = await _getList();
    historyList = list.map((e) => HistoryItem(json.decode(e))).toList();
    return historyList;
  }
  /// 删除历史记录
  Future<void> removeItem(String id) {
    historyList.removeWhere((element) => element.id == id);
    return saveList();
  }

  /// 保存浏览记录
  Future<void> saveIndex({required String id, required int index}) {
    var item = historyList.lastWhere((element) => element.id == id);
    return save(
        id: id,
        title: item.title,
        image: item.image,
        images: item.list,
        index: index);
  }

  ///清除本地存储
  Future<void> clear() async {
    (await _initInstance()).remove(_storageKey);
    historyList = [];
  }
}

String _getCurrentDate() {
  var dateTime = DateTime.now();
  // var year = dateTime.year;
  // var month = dateTime.month;
  // var day = dateTime.day;

  return dateTime.toString().substring(0, 19);
}

Storage historyStorage = Storage();
