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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setting'),
      ),
      body: ListView(
        children: [
          LabelRadio(
            list: const ['跟随系统', '亮色', '暗色'],
            label: '主题样式',
            onChanged: (index) {
              switch (index) {
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
                    set.setThemeMode(Get.isDarkMode);
                  }
              }
            },
            value: set.isDark.value ? 2 : 1,
          ),
          const Divider(),
          LabelRadio(
              list: themeList.map((el) => el.toString()).toList(),
              value: set.themeIndex.value,
              label: '主题颜色',
              onChanged: (val) {
                set.setThemeIndex(val);
              }),
          const Divider(),
          const LabelRadio(
            list: ['跟随系统', '中文', 'English'],
            value: 1,
            label: '语言',
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
