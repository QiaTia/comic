import 'package:comic/widget/animation/animation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/setting.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _Setting();
}

class _Setting extends State<SettingPage> {
  final SetController set = Get.find();

  /// 设置语言
  void setLang(String str) {
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
              setLang(val as String);
            },
          ),
          const Divider(),
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
          // LabelRadio<int>(
          //     list: themeList.map((el) => (el.value.toString(), i++)).toList(),
          //     value: set.themeIndex.value,
          //     label: 'themeStyle'.tr,
          //     onChanged: (val) {
          //       set.setThemeIndex(val as int);
          //     }),
          Column(children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Text(
                    'themeStyle'.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                direction: Axis.horizontal,
                runSpacing: 16,
                spacing: 16,
                children: List.generate(themeList.length, (index) {
                  
                  final appMultipleThemeMode = ThemeData(colorSchemeSeed: themeList[index]);
                  final primaryColor = appMultipleThemeMode.colorScheme.primary;
                  return MultipleThemeCard(
                    key: Key(
                        'widget_multiple_theme_card_${appMultipleThemeMode.toString()}'),
                    selected: set.themeIndex.value == index,
                    child: Container(
                        alignment: Alignment.center, color: primaryColor),
                    onTap: () {
                      set.setThemeIndex(index);
                      // print('当前选择主题：${appMultipleThemeMode.toString()}');
                      // final applicationViewModel = context.read<ApplicationViewModel>();
                      // applicationViewModel.multipleThemeMode = appMultipleThemeMode;
                    },
                  );
                }),
              ),
            ),
          ]),
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

  /// 选中回调
  onSelect(T? val) {
    print(val);
    if (val == null) return;
    setState(() {
      _value = val;
    });
    if (widget.onChanged != null) widget.onChanged!(val);
  }

  @override
  Widget build(BuildContext context) {
    /// 单选框 Label
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

    /// 单选框列表
    children.addAll(widget.list
        .map(
          (item) => RadioListTile<T>(
            title: Text(item.$1),
            value: item.$2,
            groupValue: _value,
            onChanged: onSelect,
          ),
        )
        .toList());
    return Column(children: children);
  }
}

/// 多主题卡片
class MultipleThemeCard extends StatelessWidget {
  const MultipleThemeCard({
    super.key,
    this.child,
    this.selected,
    this.onTap, // dart format
  });

  /// 卡片内容
  final Widget? child;

  /// 是否选中
  final bool? selected;

  /// 点击触发
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Get.isDarkMode;
    // final isDark = AppTheme(context).isDarkMode;
    final isSelected = selected ?? false;
    final borderSelected =
        Border.all(width: 3, color: isDark ? Colors.white : Colors.black);
    final borderUnselected =
        Border.all(width: 3, color: isDark ? Colors.white12 : Colors.black12);
    final borderStyle = isSelected ? borderSelected : borderUnselected;

    return AnimatedPress(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Stack(
              alignment: AlignmentDirectional.bottomEnd,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    border: borderStyle,
                  ),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(50), child: child),
                ),
                Builder(
                  builder: (_) {
                    if (!isSelected) {
                      return const SizedBox();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(right: 12, bottom: 12),
                      child: Icon(
                        Icons.check,
                        // Remix.checkbox_circle_fill,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 主题模式卡片
// class ThemeCard extends StatelessWidget {
//   const ThemeCard({
//     super.key,
//     this.child,
//     this.title,
//     this.selected,
//     this.onTap, // dart format
//   });

//   /// 卡片内容
//   final Widget? child;

//   /// 卡片标题
//   final String? title;

//   /// 是否选中
//   final bool? selected;

//   /// 点击触发
//   final VoidCallback? onTap;

//   @override
//   Widget build(BuildContext context) {
//     final isDark = AppTheme(context).isDarkMode;
//     final isSelected = selected ?? false;
//     final borderSelected = Border.all(width: 3, color: isDark ? Colors.white : Colors.black);
//     final borderUnselected = Border.all(width: 3, color: isDark ? Colors.white12 : Colors.black12);
//     final borderStyle = isSelected ? borderSelected : borderUnselected;

//     return AnimatedPress(
//       child: GestureDetector(
//         onTap: onTap,
//         child: Column(
//           children: [
//             Stack(
//               alignment: AlignmentDirectional.bottomEnd,
//               children: [
//                 Container(
//                   width: 100,
//                   height: 72,
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(18),
//                     border: borderStyle,
//                   ),
//                   child: ClipRRect(
//                     borderRadius: BorderRadius.circular(14),
//                     child: ExcludeSemantics(child: child),
//                   ),
//                 ),
//                 Builder(
//                   builder: (_) {
//                     if (!isSelected) {
//                       return const SizedBox();
//                     }
//                     return Padding(
//                       padding: const EdgeInsets.only(right: 8, bottom: 8),
//                       child: Icon(
//                         Remix.checkbox_circle_fill,
//                         size: 20,
//                         color: isDark ? Colors.white : Colors.black,
//                       ),
//                     );
//                   },
//                 ),
//               ],
//             ),
//             Padding(
//               padding: const EdgeInsets.only(top: 4),
//               child: Text(
//                 title ?? '',
//                 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
