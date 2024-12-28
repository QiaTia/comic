import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/setting.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _Setting();
}

class _Setting extends State<SettingPage> {
  final SetController set = Get.find();

  /// 设置语言
  void setLange(String str) {
    if (str == '') {
      var code = Get.deviceLocale?.languageCode;
      if (code != '') set.setLanguage(code!);
    } else {
      set.setLanguage(str);
    }
  }

  /// 设置主题样式
  void setThemeMode(int themeIndex) {
    switch (themeIndex) {
      case 1:
        {
          set.setThemeMode(ThemeMode.light);
          break;
        }
      case 2:
        {
          set.setThemeMode(ThemeMode.dark);
          break;
        }
      default:
        {
          set.setThemeMode(ThemeMode.system);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    var i = 0;
    return Scaffold(
      appBar: AppBar(
        title: Text('setting'.tr),
      ),
      body: ListView(
        children: [
          LabelRadio<ThemeMode>(
            list: [
              ('follow'.tr, ThemeMode.system),
              ('light'.tr, ThemeMode.light),
              ('dark'.tr, ThemeMode.dark)
            ],
            label: 'themeMode'.tr,
            value: set.themeMode.value,
            onChanged: (p0) {
              set.setThemeMode(p0 as ThemeMode);
            },
            // value: set.themeMode.value,
          ),
          const Divider(),
          LabelRadio<int>(
              list: themeList.map((el) => (el.value.toString(), i++)).toList(),
              value: set.themeIndex.value,
              label: 'themeStyle'.tr,
              onChanged: (val) {
                set.setThemeIndex(val as int);
              }),
          const Divider(),
          LabelRadio<String>(
            list: [
              ('follow'.tr, ''),
              ('中文', 'zh'),
              ('English', 'en'),
              ('日本語', 'ja')
            ],
            value: set.currentLanguage.value,
            label: 'language'.tr,
            onChanged: (val) {
              setLange(val as String);
            },
          ),
        ],
      ),
    );
  }
}

/// 单选框
class LabelRadio<T> extends StatefulWidget {
  /// 默认选择项目
  final T value;

  /// 选项列表
  final List<(String, T)> list;

  /// 选中回调
  final void Function(dynamic)? onChanged;

  /// 描述说明
  final String label;

  const LabelRadio(
      {super.key,
      required this.value,
      required this.list,
      this.onChanged,
      required this.label});
  @override
  State<LabelRadio> createState() => _LabelRadio<T>();
}

class _LabelRadio<T> extends State<LabelRadio> {
  late T _value;
  @override
  void initState() {
    _value = widget.value;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    var children = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      )
    ];
    children.addAll(widget.list
        .map(
          (item) => RadioListTile<T>(
            title: Text(item.$1),
            value: item.$2,
            groupValue: _value,
            onChanged: (value) {
              setState(() {
                _value = item.$2;
              });
              print(item.$2);
              if (widget.onChanged != null) widget.onChanged!(item.$2);
            },
          ),
        )
        .toList());
    return Column(children: children);
  }
}
