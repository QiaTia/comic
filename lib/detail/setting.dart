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
  var langIndex = 0;
  @override
  void initState() {
    switch (set.currentLanguage.value) {
      case 'ja':
        {
          langIndex = 3;
          break;
        }
      case 'en':
        {
          langIndex = 2;
          break;
        }
      case 'zh':
        {
          langIndex = 1;
          break;
        }
    }
    super.initState();
  }

  /// 设置语言
  void setLange(int index) {
    var lang = Get.locale?.languageCode ?? 'zh';
    switch (index) {
      case 3:
        {
          lang = 'ja';
          break;
        }
      case 2:
        {
          lang = 'en';
          break;
        }
      case 1:
        {
          lang = 'zh';
          break;
        }
    }
    set.setLanguage(lang);
  }

  /// 设置主题样式
  void setThemeMode(int themeIndex) {
    switch (themeIndex) {
      case 1:
        {
          set.setThemeMode(false);
          break;
        }
      case 2:
        {
          set.setThemeMode(true);
          break;
        }
      default:
        {
          set.setThemeMode(
              MediaQuery.of(context).platformBrightness == Brightness.dark);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('setting'.tr),
      ),
      body: ListView(
        children: [
          LabelRadio(
            list: ['follow'.tr, 'light'.tr, 'dark'.tr],
            label: 'themeMode'.tr,
            onChanged: (index) {
              setThemeMode(index);
            },
            value: set.isDark.value ? 2 : 1,
          ),
          const Divider(),
          LabelRadio(
              list: themeList.map((el) => el.value.toString()).toList(),
              value: set.themeIndex.value,
              label: 'themeStyle'.tr,
              onChanged: (val) {
                set.setThemeIndex(val);
              }),
          const Divider(),
          LabelRadio(
            list: ['follow'.tr, '中文', 'English', '日本語'],
            value: langIndex,
            label: 'language'.tr,
            onChanged: (val) {
              setLange(val);
            },
          ),
        ],
      ),
    );
  }
}

/// 单选框
class LabelRadio extends StatefulWidget {
  /// 默认选择项目
  final int value;

  /// 选项列表
  final List<String> list;

  /// 选中回调
  final void Function(int)? onChanged;

  /// 描述说明
  final String label;

  const LabelRadio(
      {super.key,
      this.value = 0,
      required this.list,
      this.onChanged,
      required this.label});
  @override
  State<LabelRadio> createState() => _LabelRadio();
}

class _LabelRadio extends State<LabelRadio> {
  late String _value;
  @override
  void initState() {
    super.initState();
    _value = widget.list[widget.value]; // 将初始化移到 initState 中
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
          (title) => RadioListTile<String>(
            title: Text(title),
            value: title,
            groupValue: _value,
            onChanged: (value) {
              setState(() {
                _value = value!;
              });
              widget.onChanged?.call(widget.list.indexOf(value!));
            },
          ),
        )
        .toList());
    return Column(children: children);
  }
}
