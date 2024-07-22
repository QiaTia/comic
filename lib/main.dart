import 'package:comic/detail/about.dart';
import 'package:comic/detail/setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'detail/detail.dart';
import 'detail/chapter.dart';
import 'detail/search.dart';
import 'detail/history.dart';
import './Widget/route_animation.dart';
import 'utlis/api.dart';
import 'package:get/get.dart';
import './models/setting.dart';

void main() async {
  Get.put(SetController());
  await SetController().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'R18 Comic',
      debugShowCheckedModeBanner: false,
      routes: {
        "/": (context) => const MyHomePage(title: 'R18 Comic'),
        "/chapter": (context) =>
            ComicChapter(id: ModalRoute.of(context)!.settings.arguments as int),
        "/detail": (context) {
          var routeArguments =
              ModalRoute.of(context)!.settings.arguments as ChapterItemProp;
          return ComicDetail(options: routeArguments);
        }
      },
      theme: ThemeData(colorSchemeSeed: Colors.amber),
      darkTheme: ThemeData.dark(),
    );
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
  final List tabs = ["同人志", "CosPlay", "单行本", "韩漫"];
  @override
  void initState() {
    super.initState();
    // httpService
    //     .get('/content-9d9a75db16285991acd0dbc7146de795-1.html')
    //     .then((data) {
    //   print(data['data'] ?? '');
    // });

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Center(child: Text('再次按下以关闭应用程序')),
            duration: Duration(seconds: 4),
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
        onPopInvoked: (didPop) async {
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
                      case 'Setting':
                        {
                          Navigator.push(
                              context, FadeRoute(page: const SettingPage()));
                          break;
                        }
                      case 'About':
                        {
                          Navigator.push(
                              context, FadeRoute(page: const AboutPage()));
                          break;
                        }
                    }
                    if (val == '') {}
                  },
                  itemBuilder: (context) => ['Setting', 'About']
                      .map((name) => PopupMenuItem(
                            value: name,
                            child: Text(name),
                          ))
                      .toList()),
              actions: [
                IconButton(
                    tooltip: 'History',
                    onPressed: () {
                      Navigator.push(
                          context, FadeRoute(page: const ComicHistory()));
                    },
                    icon: const Icon(Icons.history)),
                IconButton(
                    tooltip: 'Search',
                    onPressed: () {
                      Navigator.push(
                          context, FadeRoute(page: const SearchPage()));
                    },
                    icon: const Icon(Icons.search)),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8))
              ],
              bottom: TabBar(
                controller: _tabController,
                indicatorColor: Colors.amber,
                labelColor: Colors.black87,
                tabs: tabs.map((e) => Tab(text: e)).toList(),
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
