import 'dart:async';

import 'package:comic/view/info/about.dart';
import 'package:comic/view/info/setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'view/detail/detail.dart';
import 'view/detail/chapter.dart';
import 'view/detail/search.dart';
import 'view/detail/history.dart';
import 'utils/api.dart';
import 'utils/cloudflare.dart';
import 'utils/cloudflare_bridge.dart';
import 'utils/turnstile_solver.dart';
import 'utils/local_proxy.dart';
import 'package:get/get.dart';
import './models/setting.dart';
import './i18n/main.dart';
import 'package:layout/layout.dart';

const appName = 'R18 Comic';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(SetController());
  // 本地 CONNECT 代理：部分 ROM（realme/OPPO）的 HTTPDNS 会劫持 App 进程对
  // punycode 域名的解析（Failed host lookup），请求层 findProxy 会指向它。
  await CfLocalProxy.start();
  // 解析当前可用的目标域名（该站域名轮换频繁，旧域名会停止 DNS 解析），
  // 必须在 runApp 之前完成，请求层依赖它拼 URL。
  await TargetHostResolver.init();
  // 恢复已保存的 Cloudflare 验证 cookie，避免每次启动都重新验证
  await CloudflareCookieJar.instance.init();
  // 恢复打码平台配置（自动解 Turnstile 用），未配置时自动降级回 managed 流程
  await CaptchaSettings.instance.init();
  // 启动后台预热：隐藏 WebView 静默尝试通过 managed 挑战，
  // 成功则首页数据直接加载（无验证页闪现）；失败不弹 UI，
  // 由用户手动重试时再走带 UI 的验证。
  unawaited(CloudflareBridge.instance
      .prewarm(Uri.parse('https://${TargetHostResolver.host}/')));
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return Layout(child: GetMaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      // 常驻 WebView 桥接层放在 builder 内：此处已有 MaterialApp 提供的
      // Directionality/Theme，避免把 Stack 包在 GetMaterialApp 外层导致
      // “No Directionality widget found” 的构建崩溃（会让整个 App 渲染不出来）。
      builder: (context, child) =>
          CloudflareBridgeOverlay(child: child ?? const SizedBox.shrink()),
      routes: {
        "/": (context) => const MyHomePage(title: appName),
        "/chapter": (context) =>
            ComicChapter(id: ModalRoute.of(context)!.settings.arguments as int),
        "/detail": (context) {
          var routeArguments =
              ModalRoute.of(context)!.settings.arguments as ChapterItemProp;
          return ComicDetail(options: routeArguments);
        },
      },
      theme: ThemeData(colorSchemeSeed: Colors.amber),
      darkTheme: ThemeData.dark(),
      translations: Messages(), // your translations
      fallbackLocale: const Locale('zh'),
    ));
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? currentBackPressTime;
  List<String> tabs = ["doujinshi", "CosPlay", "offprint", "korea"];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    // 返回键退出
    bool closeOnConfirm() {
      if (!mounted) return false;
      DateTime now = DateTime.now();
      // 物理键，两次间隔大于4秒, 退出请求无效
      if (currentBackPressTime == null ||
          now.difference(currentBackPressTime!) > const Duration(seconds: 4)) {
        currentBackPressTime = now;
        // 用当前 BuildContext 的 ScaffoldMessenger，避免 GetX 全局 Overlay 在路由返回时找不到
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('conirmExitApp'.tr),
            duration: const Duration(seconds: 4),
          ),
        );
        return false;
      }
      // 退出请求有效
      currentBackPressTime = null;
      return true;
    }

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) {
            return;
          }
          if (closeOnConfirm()) {
            // 系统级别导航栈 退出程序
            SystemNavigator.pop();
          }
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              leading: PopupMenuButton<String>(
                  onSelected: (val) {
                    switch (val) {
                      case 'setting':
                        {
                          Get.to(() => const SettingPage(), transition: Transition.zoom);
                          break;
                        }
                      case 'about':
                        {
                          Get.to(() => const AboutPage(), transition: Transition.zoom);
                          break;
                        }
                      case 'dome':
                        {
                          Get.toNamed('/volume');
                          break;
                        }
                    }
                  },
                  itemBuilder: (context) => ['setting', 'about']
                      .map((name) => PopupMenuItem(
                            value: name,
                            child: Text(name.tr),
                          ))
                      .toList()),
              actions: [
                IconButton(
                    tooltip: 'History',
                    onPressed: () {
                      Get.to(() => const ComicHistory(), transition: Transition.zoom);
                    },
                    icon: const Icon(Icons.history)),
                IconButton(
                    tooltip: 'Search',
                    onPressed: () {
                      Get.to(() => const SearchPage(), transition: Transition.zoom);
                    },
                    icon: const Icon(Icons.search)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8))
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.black87,
                tabs: tabs.map((e) => Tab(text: e.tr)).toList(),
              ),
            ),
            body: TabBarView(
              //构建
              controller: _tabController,
              children: tabs
                  .asMap()
                  .keys
                  .map((i) => KeepAliveWrapper(
                          child: ComicChapter(
                        id: (i + -4).abs(),
                      )))
                  .toList(),
            )));
  }

  @override
  void dispose() {
    // 释放资源
    _tabController.dispose();
    super.dispose();
  }
}

class KeepAliveWrapper extends StatefulWidget {
  const KeepAliveWrapper({
    Key? key,
    this.keepAlive = true,
    required this.child,
  }) : super(key: key);
  final bool keepAlive;
  final Widget child;

  @override
  _KeepAliveWrapperState createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }

  @override
  void didUpdateWidget(covariant KeepAliveWrapper oldWidget) {
    if (oldWidget.keepAlive != widget.keepAlive) {
      // keepAlive 状态需要更新，实现在 AutomaticKeepAliveClientMixin 中
      updateKeepAlive();
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  bool get wantKeepAlive => widget.keepAlive;
}

/// 常驻 WebView 桥接层。
///
/// 始终挂载一个隐藏的 WebView（保持会话存活），当 [CloudflareBridge.verifying] 为真时
/// 以全屏验证页形式展现，供用户手动完成 Cloudflare 人机验证。验证通过后该 WebView
/// 退回隐藏态但仍保持挂载，后续所有 API 请求都通过它取数（共享 TLS 指纹 + cf_clearance）。
class CloudflareBridgeOverlay extends StatefulWidget {
  final Widget child;
  const CloudflareBridgeOverlay({super.key, required this.child});

  @override
  State<CloudflareBridgeOverlay> createState() => _CloudflareBridgeOverlayState();
}

class _CloudflareBridgeOverlayState extends State<CloudflareBridgeOverlay> {
  final _bridge = CloudflareBridge.instance;

  @override
  void initState() {
    super.initState();
    // 只为验证页的显隐注册监听（低频）；状态小条用 AnimatedBuilder 局部重建，
    // 避免每次 bridge notifyListeners 都重建整个 Overlay Stack。
    _bridge.addListener(_onBridgeChanged);
  }

  void _onBridgeChanged() {
    // 只有验证页显隐变化才需要重建 Stack（低频）。
    // bridge 取数过程中的 notify（lastFetchLen 等）只影响状态小条，
    // 由 AnimatedBuilder 局部消费，这里直接忽略。
    // 用 uiVisible（而非 verifying）：启动预热是静默验证（verifying=true
    // 但不弹 UI），不能让验证页闪现。
    if (!mounted) return;
    if (_lastUiVisible == _bridge.uiVisible) return;
    _lastUiVisible = _bridge.uiVisible;
    setState(() {});
  }

  bool _lastUiVisible = false;

  @override
  void dispose() {
    _bridge.removeListener(_onBridgeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // 常驻 WebView：仅非静默验证（用户手动重试/手动验证）时展示；
        // 启动预热等静默验证在后台无头运行，不闪 UI。
        // maintainState 保证隐藏时也保持挂载（会话/cookie 不丢失）。
        Visibility(
          visible: _bridge.uiVisible,
          maintainState: true,
          maintainAnimation: true,
          child: Scaffold(
            appBar: AppBar(
              title: Text('cfVerifyTitle'.tr),
              leading: IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'cancel'.tr,
                onPressed: () => _bridge.cancel(),
              ),
            ),
            body: WebViewWidget(controller: _bridge.controller),
          ),
        ),
        // 验证通过后的状态小条：AnimatedBuilder 只重建这个小区域，
        // bridge 高频 notify（取数字节数等）不再触发整页 rebuild。
        Positioned(
          left: 8,
          right: 8,
          bottom: 8,
          child: AnimatedBuilder(
            animation: _bridge,
            builder: (context, _) {
              if (!_bridge.ready) return const SizedBox.shrink();
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _bridge.lastError == null
                      ? Colors.green.withOpacity(0.92)
                      : Colors.orange.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _bridge.lastError == null
                      ? 'cfReady'.tr +
                          (_bridge.lastFetchLen != null
                              ? 'cfLastBytes'
                                  .trParams({'n': '${_bridge.lastFetchLen}'})
                              : '')
                      : 'cfBridgeError'
                          .trParams({'e': '${_bridge.lastError}'}),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
