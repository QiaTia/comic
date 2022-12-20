import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HistorytItem {
  // HistorytItem(this.id, this.title, this.image, this.creatAt);
  final String id;
  final String title;
  final String image;
  final String creatAt;

  HistorytItem(Map<String, dynamic> json)
      : title = json['title'],
        id = json['id'],
        creatAt = json['creat_at'],
        image = json['image'];

  Map<String, dynamic> toJson() =>
      {'title': title, 'id': id, 'image': image, 'creat_at': creatAt};
}

class Storage {
  SharedPreferences? prefs;
  late String _storageKey;
  Storage([key = 'history']) {
    _storageKey = key;
    SharedPreferences.getInstance().then((value) => {prefs = value});
  }
  Future<SharedPreferences> _initInstance() async {
    prefs ??= await SharedPreferences.getInstance();
    return prefs!;
  }

  Future<List<String>> _getList() async {
    return (await _initInstance()).getStringList(_storageKey) ?? [];
  }

  Future<void> save(String id, String title, String image) async {
    var list = await getList();
    var fIndex = list.indexWhere((element) => element.id == id);
    var newItem = HistorytItem({
      'id': id,
      'title': title,
      'image': image,
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

  Future<List<HistorytItem>> getList() async {
    var list = await _getList();
    return list.map((e) => HistorytItem(json.decode(e))).toList();
  }

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
