import 'package:comic/utlis/storage.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Widget/route_animation.dart';
import '../utlis/api.dart';
import '../utlis/request.dart';
import './gallery.dart';
import 'package:flutter/services.dart';
// Obtain shared preferences.

class ComicDetail extends StatefulWidget {
  const ComicDetail(
      {super.key, this.page = 1, required this.options, this.list});
  final ChapterItemProp options;
  final int page;
  final List<String>? list;
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
  final ScrollController _controller = ScrollController();

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

  void jump([bool? isNext]) {
    var screenHight = MediaQuery.of(context).size.height * 0.8;
    var target = isNext != null && isNext ? screenHight : -screenHight;
    _controller.animateTo(_controller.offset + target,
        duration: const Duration(milliseconds: 300), curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    if (widget.list != null) {
      for (var element in widget.list!) {
        addItem(element);
      }
    } else {
      apiServer.getDetail(widget.options.id, widget.page).then((result) {
        for (var element in result.data) {
          addItem(element);
        }
        historyStorage.save(widget.options.id, result.title!,
            widget.options.image, result.data);
      });
    }
    setTitle(widget.options.title);
    setAppBar();
  }

  @override
  void dispose() {
    super.dispose();
    systemUiMode(true);
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    var controlleWidth = screenSize.width * 0.4,
        controllerBottom = (screenSize.height / 3) * 2;
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
            : Stack(clipBehavior: Clip.none, children: [
                Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: SizedBox(
                        width: screenSize.width,
                        height: screenSize.height,
                        child: _PhotoList(
                            list: _photos,
                            controller: _controller,
                            onTapDown: ((detail) {
                              var dy = detail.globalPosition.dy,
                                  dx = detail.globalPosition.dx;
                              if (dx < controlleWidth &&
                                  dy > controllerBottom) {
                                jump();
                              } else if (dx > screenSize.width * 0.6 &&
                                  dy > controllerBottom) {
                                jump(true);
                              } else {
                                setAppBar();
                              }
                            })))),
                _ButtonMask(
                    show: isAppBar,
                    string: 'Next',
                    position: PositionType.rightBottom),
                _ButtonMask(
                    show: isAppBar,
                    string: 'Last',
                    position: PositionType.leftBottom)
              ]));
  }
}

class _PhotoList extends StatefulWidget {
  _PhotoList({required this.list, this.onTapDown, this.controller});
  final _ListPhotoItemonTapDown? onTapDown;
  final ScrollController? controller;
  List<_Photo> list;
  @override
  State<StatefulWidget> createState() => __PhotoListWidget();
}

class __PhotoListWidget extends State<_PhotoList> {
  static const loadingTag = "##loading##"; //表尾标记
  final _list = <_Photo>[_Photo(title: loadingTag, url: '')];
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
        controller: widget.controller,
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
            onTapDown: widget.onTapDown,
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
typedef _ListPhotoItemonTapDown = void Function(TapDownDetails detail);

class _ListPhotoItem extends StatelessWidget {
  const _ListPhotoItem(
      {Key? key, required this.item, this.onTapDown, this.onLongPress})
      : super(key: key);
  final _Photo item;
  final _ListPhotoItemTap? onLongPress;
  final _ListPhotoItemonTapDown? onTapDown;
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      return InkWell(
        onLongPress: () {
          if (onLongPress != null) onLongPress!();
        },
        onTapDown: onTapDown,
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
      );
    });
  }
}

enum PositionType { rightBottom, leftBottom, leftTop, rightTop }

class _ButtonMask extends StatelessWidget {
  _ButtonMask(
      {required this.show,
      required this.string,
      this.position = PositionType.rightBottom});
  final bool show;
  String string;
  PositionType position;
  @override
  Widget build(BuildContext context) {
    dynamic left = null, bottom = null, right = null, top = null;
    switch (position) {
      case PositionType.leftBottom:
        {
          left = 0.0;
          bottom = 0.0;
          break;
        }
      case PositionType.rightBottom:
        {
          right = 0.0;
          bottom = 0.0;
          break;
        }
      case PositionType.leftTop:
        {
          top = 0.0;
          left = 0.0;
          break;
        }
      case PositionType.rightTop:
        {
          top = 0.0;
          right = 0.0;
          break;
        }
    }
    return Positioned(
      left: left,
      bottom: bottom,
      right: right,
      top: top,
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        height: MediaQuery.of(context).size.height / 3,
        child: show
            ? Container(
                color: Colors.black45,
                child: Center(
                  child: Text(string,
                      style: const TextStyle(color: Colors.white, fontSize: 28),
                      textAlign: TextAlign.center),
                ))
            : null,
      ),
    );
  }
}
