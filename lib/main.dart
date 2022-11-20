import 'package:flutter/material.dart';
import 'detail/detail.dart';
import 'detail/chapter.dart';
import 'detail/search.dart';
import './Widget/route_animation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    var brightness = Theme.of(context).brightness;
    return MaterialApp(
      title: 'R18 Comic',
      debugShowCheckedModeBanner: false,
      routes: {
        "/": (context) => const MyHomePage(title: 'R18 Comic'),
        "/chapter": (context, {arguments}) => ComicChapter(
            id: int.parse(
                ModalRoute.of(context)!.settings.arguments.toString())),
        "/detail": (context) {
          return ComicDetail(
              id: ModalRoute.of(context)!.settings.arguments.toString());
        }
      },
      theme: ThemeData(
          // This is the theme of your application.
          //
          // Try running your application with "flutter run". You'll see the
          // application has a blue toolbar. Then, without quitting the app, try
          // changing the primarySwatch below to Colors.green and then invoke
          // "hot reload" (press "r" in the console where you ran "flutter run",
          // or simply save your changes to "hot reload" in a Flutter IDE).
          // Notice that the counter didn't reset back to zero; the application
          // is not restarted.
          primaryColor: Colors.amber,
          primarySwatch: Colors.amber,
          brightness: brightness),
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
  List tabs = ["CosPlay", "日漫", "韩漫"];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
                tooltip: 'Search',
                onPressed: () {
                  Navigator.push(context, FadeRoute(page: SearchPage()));
                },
                icon: const Icon(Icons.search)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8))
          ],
          bottom: TabBar(
            controller: _tabController,
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
                    id: (i + -3).abs(),
                  )))
              .toList(),
        ));
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
