import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Widget/route_animation.dart';
import '../utlis/api.dart';
import '../utlis/request.dart';
import './gallery.dart';
import 'package:flutter/services.dart';
// Obtain shared preferences.

class ComicDetail extends StatefulWidget {
  const ComicDetail({super.key, this.page = 1, required this.id});

  final String id;
  final int page;
  @override
  State<ComicDetail> createState() => _ComicDetail();
}

class _Photo {
  _Photo({
    required this.url,
    required this.title,
  });

  final String url;
  final String title;
}

class _ComicDetail extends State<ComicDetail> {
  final List<_Photo> _photos = [];
  String title = "";
  bool isLoading = true;
  bool isAppBar = true;

  void addItem(String url) {
    setState(() {
      _photos.add(_Photo(url: url, title: ""));
    });
  }

  void setTitle(String val) {
    setState(() {
      title = val;
      isLoading = false;
    });
  }

  void setAppBar() {
    setState(() {
      isAppBar = !isAppBar;
    });
    systemUiMode(isAppBar);
  }

  void systemUiMode([bool visible = false]) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
        overlays: visible ? [SystemUiOverlay.top, SystemUiOverlay.bottom] : []);
  }

  @override
  void initState() {
    super.initState();
    apiServer.getDetail(widget.id, widget.page).then((result) {
      setTitle(result.title!);
      for (var element in result.data) {
        addItem(element);
      }
      setAppBar();
    });
  }

  @override
  void dispose() {
    super.dispose();
    systemUiMode(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: isAppBar
            ? AppBar(
                title: Text(title),
              )
            : null,
        body: isLoading
            ? Center(
                child: Column(children: const [
                  Padding(padding: EdgeInsets.all(80)),
                  CircularProgressIndicator(),
                  Padding(padding: EdgeInsets.all(8)),
                  Text("数据加载中!")
                ]),
              )
            : Stack(children: [
                // AbsorbPointer
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTapDown: (detail) {},
                    child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.4,
                        height: MediaQuery.of(context).size.height / 3,
                        child: Container(
                            color: isAppBar
                                ? Colors.black45
                                : const Color.fromARGB(0, 255, 255, 255),
                            child: Center(
                              child: Text('Next',
                                  style: TextStyle(
                                      color: isAppBar
                                          ? Colors.white
                                          : const Color.fromARGB(
                                              0, 255, 255, 255),
                                      fontSize: 28),
                                  textAlign: TextAlign.center),
                            ))),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: () {
                      print('Last!');
                    },
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.4,
                      height: MediaQuery.of(context).size.height / 3,
                      child: isAppBar
                          ? Container(
                              color: Colors.black45,
                              child: const Center(
                                child: Text('Last',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 28),
                                    textAlign: TextAlign.center),
                              ))
                          : null,
                    ),
                  ),
                ),

                Positioned(
                    child: Column(
                  children: [
                    Expanded(
                        flex: 1,
                        child: _PhotoList(list: _photos, onTap: setAppBar))
                  ],
                )),
              ]));
  }
}

class _PhotoList extends StatefulWidget {
  _PhotoList({required this.list, this.onTap});
  final _ListPhotoItemTap? onTap;

  List<_Photo> list;
  @override
  State<StatefulWidget> createState() => __PhotoListWidget();
}

class __PhotoListWidget extends State<_PhotoList> {
  static const loadingTag = "##loading##"; //表尾标记
  final _list = <_Photo>[_Photo(title: loadingTag, url: '')];
  final ScrollController _controller = ScrollController();
  void _retrieveData() {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      setState(() {
        int start = _list.length - 1;
        //重新构建列表
        _list.insertAll(
          start,
          widget.list.sublist(
              start,
              start + 10 > widget.list.length - 1
                  ? widget.list.length - 1
                  : start + 10),
        );
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _retrieveData();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
        physics: const ClampingScrollPhysics(), //去掉弹性,
        // padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _list.length,
        controller: _controller,
        cacheExtent: 5,
        itemBuilder: (context, index) {
          //如果到了表尾
          if (_list[index].title == loadingTag) {
            //不足100条，继续获取数据
            if (_list.length - 1 < widget.list.length - 1) {
              //获取数据
              _retrieveData();
              //加载时显示loading
              return Container(
                padding: const EdgeInsets.all(16.0),
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24.0,
                  height: 24.0,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              );
            } else {
              //已经加载了100条数据，不再获取数据。
              return Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: const Text(
                  "已经看完咯!",
                  style: TextStyle(color: Colors.grey),
                ),
              );
            }
          }
          return _ListPhotoItem(
            item: _list[index],
            onTap: () {
              widget.onTap!();
            },
            onLongPress: () {
              // Todo 点击查看大图
              Navigator.of(context).push(FadeRoute(
                  page: GalleryList(
                list: widget.list.map((e) => e.url).toList(),
                index: index,
              )));
            },
          );
        });
  }
}

typedef _ListPhotoItemTap = void Function();

class _ListPhotoItem extends StatelessWidget {
  const _ListPhotoItem(
      {Key? key, required this.item, this.onTap, this.onLongPress})
      : super(key: key);
  final _Photo item;
  final _ListPhotoItemTap? onTap;
  final _ListPhotoItemTap? onLongPress;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return InkWell(
        child: Container(
            width: constraints.maxWidth,
            constraints: const BoxConstraints(minHeight: 150),
            child: Center(
              child: CachedNetworkImage(
                imageUrl: item.url,
                httpHeaders: imageHeader,
                fit: BoxFit.fitWidth,
                progressIndicatorBuilder: (context, url, downloadProgress) =>
                    CircularProgressIndicator(value: downloadProgress.progress),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
            )),
        // Image.network(
        //   item.url,
        //   width: constraints.maxWidth,
        //   fit: BoxFit.fitWidth,
        // ),
        onLongPress: () {
          onLongPress!();
        },
        onTap: () {
          onTap!();
        },
      );
    });
  }
}
