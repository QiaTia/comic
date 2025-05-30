import 'package:comic/view/info/about.dart';
import 'package:comic/view/info/setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'view/detail/detail.dart';
import 'view/detail/chapter.dart';
import 'view/detail/search.dart';
import 'view/detail/history.dart';
import 'utils/api.dart';
import 'package:get/get.dart';
import './models/setting.dart';
import './i18n/main.dart';
import 'package:layout/layout.dart';

const appName = 'R18 Comic';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Get.put(SetController());
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
      DateTime now = DateTime.now();
      // 物理键，两次间隔大于4秒, 退出请求无效
      if (currentBackPressTime == null ||
          now.difference(currentBackPressTime!) > const Duration(seconds: 4)) {
        currentBackPressTime = now;
        Get.showSnackbar(GetSnackBar(
          message: 'conirmExitApp'.tr,
          duration: const Duration(seconds: 4),
        ));
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
