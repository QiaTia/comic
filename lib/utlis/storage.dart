import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistorytItem {
  // HistorytItem(this.id, this.title, this.image, this.creatAt);
  final String id;
  final String title;
  final String image;
  final List<String> list;
  final String creatAt;
  HistorytItem(Map<String, dynamic> json)
      : title = json['title'],
        id = json['id'],
        creatAt = json['creat_at'],
        list = (json['list'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList(),
        image = json['image'];

  Map<String, dynamic> toJson() => {
        'title': title,
        'id': id,
        'image': image,
        'creat_at': creatAt,
        'list': list
      };
}

class Storage {
  SharedPreferences? prefs;
  late String _storageKey;
  Storage([key = 'history']) {
    _storageKey = key;
    SharedPreferences.getInstance().then((value) => {prefs = value});
  }

  /// 初始化实列
  Future<SharedPreferences> _initInstance() async {
    prefs ??= await SharedPreferences.getInstance();
    return prefs!;
  }

  Future<List<String>> _getList() async {
    return (await _initInstance()).getStringList(_storageKey) ?? [];
  }

  /// 保存项目到历史记录
  Future<void> save(
      String id, String title, String image, List<String> images) async {
    var list = await getList();
    var fIndex = list.indexWhere((element) => element.id == id);
    var newItem = HistorytItem({
      'id': id,
      'title': title,
      'image': image,
      'list': images,
      'creat_at': _getCurretnDate()
    });
    if (fIndex == -1) {
      list.add(newItem);
    } else {
      list[fIndex] = newItem;
    }
    await (await _initInstance())
        .setStringList(_storageKey, list.map((e) => jsonEncode(e)).toList());
  }

  /// 获取序列化列表
  Future<List<HistorytItem>> getList() async {
    var list = await _getList();
    return list.map((e) => HistorytItem(json.decode(e))).toList();
  }

  ///清除本地存储
  Future<void> clear() async {
    (await _initInstance()).remove(_storageKey);
  }
}

String _getCurretnDate() {
  var dateTime = DateTime.now();
  // var year = dateTime.year;
  // var month = dateTime.month;
  // var day = dateTime.day;

  return dateTime.toString().substring(0, 19);
}

Storage historyStorage = Storage();
