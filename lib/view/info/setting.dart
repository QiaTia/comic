import 'package:comic/widget/animation/animation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../models/setting.dart';
import '../../utils/cloudflare.dart';
import '../../utils/cloudflare_solver.dart';
import '../../utils/cloudflare_bridge.dart';
import '../../utils/turnstile_solver.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _Setting();
}

class _Setting extends State<SettingPage> {
  final SetController set = Get.find();

  /// 是否已导入可用的 cf_clearance（用于 UI 状态展示）。
  bool _hasClearance = false;

  /// 打码平台配置（自动解 Turnstile）。
  bool _captchaEnabled = false;
  String _captchaProvider = '2captcha';
  final TextEditingController _captchaKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshClearance();
    _captchaEnabled = CaptchaSettings.instance.enabled;
    _captchaProvider = CaptchaSettings.instance.provider;
    _captchaKeyController.text = CaptchaSettings.instance.apiKey;
  }

  void _refreshClearance() {
    setState(() {
      _hasClearance =
          CloudflareCookieJar.instance.hasClearanceFor(TargetHostResolver.host);
    });
  }

  /// 从真实浏览器导入 cf_clearance 的旁路：
  /// WebView 在该 IDN 域名下无法完成 Cloudflare Turnstile（渲染进程崩溃），
  /// 因此允许用户在桌面浏览器通过验证后，把 cookie 复制进来直接绕过。
  Future<void> _importCloudflareCookie() async {
    final controller = TextEditingController();
    final uaController = TextEditingController(
      text: CloudflareCookieJar.instance.userAgentFor(TargetHostResolver.host) ??
          kBrowserUserAgent,
    );
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: Text('cfImport'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'cfImportHelp'.tr,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'cfImportCookieLabel'.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 3,
                autofocus: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: uaController,
                decoration: InputDecoration(
                  labelText: 'cfImportUaLabel'.tr,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('cancel'.tr),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('cfImportConfirm'.tr),
          ),
        ],
      ),
    );

    if (ok != true) return;
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      Get.snackbar('tip'.tr, 'cfImportEmpty'.tr);
      return;
    }

    final cookies = CloudflareCookieJar.parseRawCookie(raw);
    if (cookies.isEmpty) {
      Get.snackbar('notice'.tr, 'cfImportNoCookie'.tr);
      return;
    }

    // 1) 持久化到 cookie jar（供图片请求等 Dart 侧复用）
    await CloudflareCookieJar.instance
        .importFromRawCookie(TargetHostResolver.host, raw);
    // 2) 注入常驻桥接 WebView（同步 UA），使其无需走 Turnstile 即可直接桥接取数
    await CloudflareBridge.instance.injectImport(TargetHostResolver.host,
        cookies,
        userAgent: uaController.text);
    // 3) 导入后清除“验证失败 host”记录，让下一个请求重新尝试（携带导入的 cookie）。
    CloudflareSolver.clearFailedHosts();
    _refreshClearance();

    if (!cookies.containsKey('cf_clearance')) {
      Get.snackbar('notice'.tr, 'cfImportNoClearance'.tr);
      return;
    }

    // 4) 立即经桥接 WebView 实测一次首页，确认导入的 cookie 真的可用
    //    （过期的 cookie 会被 Cloudflare 重新挑战，fetchHtml 会返回 null 并
    //    自动把桥接降级回未就绪态）。避免用户导入后还要自己猜有没有生效。
    Get.snackbar('importing'.tr, 'cfImportVerifyingBody'.tr);
    final probe = await CloudflareBridge.instance
        .fetchHtml('https://${TargetHostResolver.host}/');
    if (probe != null && probe.isNotEmpty) {
      Get.snackbar('success'.tr, 'cfImportOkBody'.tr);
    } else {
      Get.snackbar('invalidImport'.tr, 'cfImportBadBody'.tr);
    }
  }


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
          const Divider(),
          // ===== 打码平台自动解 Turnstile =====
          // 目标站是 IDN 域名，纯 WebView 无法完成 Cloudflare 交互式 Turnstile
          // （渲染进程崩溃）。配置打码平台 API Key 后，验证流程会在 managed
          // 挑战卡住时自动调用平台解出 token 并回填，免手动导入、全自动。
          ExpansionTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text('cfAutoSolve'.tr),
            subtitle: Text(_captchaEnabled
                ? 'cfAutoSolveOn'.trParams({
                    'p': _captchaProvider == 'anticaptcha'
                        ? 'Anti-Captcha'
                        : '2Captcha'
                  })
                : 'cfAutoSolveOff'.tr),
            initiallyExpanded: _captchaEnabled,
            children: [
              SwitchListTile(
                title: Text('cfAutoSolveEnable'.tr),
                subtitle: Text('cfAutoSolveEnableSub'.tr),
                value: _captchaEnabled,
                onChanged: (v) async {
                  setState(() => _captchaEnabled = v);
                  await CaptchaSettings.instance
                      .set(enabled: v, apiKey: _captchaKeyController.text);
                  CloudflareSolver.clearFailedHosts();
                },
              ),
              ListTile(
                title: Text('cfProvider'.tr),
                trailing: DropdownButton<String>(
                  value: _captchaProvider,
                  items: const [
                    DropdownMenuItem(
                        value: '2captcha', child: Text('2Captcha')),
                    DropdownMenuItem(
                        value: 'anticaptcha', child: Text('Anti-Captcha')),
                  ],
                  onChanged: (v) async {
                    if (v == null) return;
                    setState(() => _captchaProvider = v!);
                    await CaptchaSettings.instance.set(provider: v!);
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _captchaKeyController,
                  decoration: InputDecoration(
                    labelText: 'API Key',
                    hintText: 'cfApiKeyHint'.tr,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  obscureText: true,
                  onChanged: (v) async {
                    await CaptchaSettings.instance.set(apiKey: v.trim());
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'cfAutoSolveNote'.tr,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text('cfClearCache'.tr),
            subtitle: Text('cfClearCacheSub'.tr),
            onTap: () async {
              await CloudflareCookieJar.instance.clear();
              // 同步重置常驻桥接 WebView（含清空平台 cookie 仓库），
              // 否则旧的 cf_clearance 仍残留在 WebView 里，“清除”实际无效。
              await CloudflareBridge.instance.reset();
              CloudflareSolver.clearFailedHosts();
              _refreshClearance();
              Get.snackbar('tip'.tr, 'cfClearDone'.tr);
            },
          ),
          ListTile(
            leading: Icon(
              _hasClearance
                  ? Icons.check_circle_outline
                  : Icons.login_outlined,
              color: _hasClearance ? Colors.green : null,
            ),
            title: Text('cfImport'.tr),
            subtitle: Text(_hasClearance
                ? 'cfImportedSub'.tr
                : 'cfNotImportedSub'.tr),
            onTap: _importCloudflareCookie,
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
