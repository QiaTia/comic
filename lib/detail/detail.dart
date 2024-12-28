import 'dart:async';
import 'dart:io';

import 'package:comic/utlis/storage.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../Widget/route_animation.dart';
import '../utlis/api.dart';
import '../utlis/request.dart';
import './gallery.dart';
import 'package:flutter/services.dart';
import 'package:event/event.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
// Obtain shared preferences.

class ComicDetail extends StatefulWidget {
  const ComicDetail(
      {super.key,
      this.page = 1,
      this.initIndex = 0,
      required this.options,
      this.list});
  final ChapterItemProp options;
  final int page;
  final int initIndex;
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
  bool isAppBar = true;
  int currentPage = 0;
  final ScrollOffsetController _controller = ScrollOffsetController();
  final ItemScrollController itemScrollController = ItemScrollController();

  /// 更新当前页数
  void setCurrentIndex(int page) {
    setState(() {
      currentPage = page;
    });
  }

  void addItem(String url) {
    setState(() {
      _photos.add(_Photo(url: url, title: ""));
    });
  }

  void setTitle(String val) {
    setState(() {
      title = val;
    });
  }

  /// 是否展示头部标题栏
  void setAppBar() {
    setState(() {
      isAppBar = !isAppBar;
    });
    systemUiMode(isAppBar);
  }

  void systemUiMode([bool visible = false]) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge,
        overlays: visible ? [SystemUiOverlay.top, SystemUiOverlay.bottom] : []);
  }

  /// 跳转到指定
  void jump([bool? isNext]) {
    var screenHight = MediaQuery.of(context).size.height * 0.8;
    var target = isNext != null && isNext ? screenHight : -screenHight;
    _controller.animateScroll(
        offset: target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.linear);
  }

  @override
  void initState() {
    super.initState();
    // if (currentVolumeKeyControl()) addVolumeListen();

    if (widget.list != null) {
      for (var element in widget.list!) {
        addItem(element);
      }
      Future.delayed(const Duration(milliseconds: 800), () {
        //延时执行的代码
        // print("3秒后执行");
        itemScrollController.jumpTo(index: widget.initIndex);
      });
    } else {
      apiServer.getDetail(widget.options.id, widget.page).then((result) {
        for (var element in result.data) {
          addItem(element);
        }
        historyStorage.save(
            id: widget.options.id,
            title: result.title!,
            image: widget.options.image,
            images: result.data,
            index: widget.initIndex);
      });
    }
    setTitle(widget.options.title);
    setAppBar();
  }

  @override
  void dispose() {
    // delVolumeListen();
    systemUiMode(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    var controlleWidth = screenSize.width * 0.4,
        controllerBottom = (screenSize.height / 3) * 2;
    return readerKeyboardHolder(Scaffold(
        appBar: isAppBar
            ? AppBar(
                title: Text(title),
                actions: [
                  SizedBox(
                    width: 98,
                    child: TextField(
                      textAlignVertical: TextAlignVertical.center,
                      textAlign: TextAlign.center,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9]')) //设置只允许输入数字
                      ],
                      textInputAction: TextInputAction.go,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: '$currentPage / ${_photos.length}',
                      ),
                      onSubmitted: (value) {
                        if (value.isEmpty) return;
                        var targetPage = int.parse(value);
                        if (targetPage > _photos.length) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('tipEmpty!'.tr)));
                          return;
                        }
                        itemScrollController.jumpTo(index: targetPage);
                        // widget.onChange!(targetPage);
                      },
                    ),
                  ),
                ],
              )
            : null,
        body: _photos.isEmpty
            ? Center(
                child: Column(children: [
                  const Padding(padding: EdgeInsets.all(80)),
                  const CircularProgressIndicator(),
                  const Padding(padding: EdgeInsets.all(8)),
                  Text("loading".tr)
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
                            id: widget.options.id,
                            initIndex: widget.initIndex,
                            controller: _controller,
                            setCurrentIndex: setCurrentIndex,
                            itemScrollController: itemScrollController,
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
                    string: 'nextPage'.tr,
                    onTapDown: () {
                      setAppBar();
                      jump();
                    },
                    position: PositionType.rightBottom),
                _ButtonMask(
                    show: isAppBar,
                    string: 'prePage'.tr,
                    onTapDown: () {
                      setAppBar();
                      jump(true);
                    },
                    position: PositionType.leftBottom)
              ])));
  }
}

class _PhotoList extends StatefulWidget {
  _PhotoList(
      {required this.list,
      this.controller,
      this.initIndex = 0,
      required this.id,
      this.setCurrentIndex,
      this.itemScrollController,
      this.onTapDown});
  final _ListPhotoItemonTapDown? onTapDown;
  final ScrollOffsetController? controller;
  final ItemScrollController? itemScrollController;
  void Function(int page)? setCurrentIndex;
  final String id;
  final int initIndex;
  List<_Photo> list;
  @override
  State<StatefulWidget> createState() => __PhotoListWidget();
}

class __PhotoListWidget extends State<_PhotoList> {
  static const loadingTag = "##loading##"; //表尾标记
  final _list = <_Photo>[_Photo(title: loadingTag, url: '')];
  final ItemPositionsListener itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollOffsetListener scrollOffsetListener =
      ScrollOffsetListener.create();

  /// 动态拼装列表
  void _retrieveData() {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      setState(() {
        int start = _list.length - 1;
        //重新构建列表
        _list.insertAll(
          start,
          widget.list.sublist(
              start,
              start + 10 > widget.list.length
                  ? widget.list.length
                  : start + 10),
        );
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _retrieveData();
    itemPositionsListener.itemPositions.addListener(_onListCurrentChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.initIndex > 0) {
      // sleep(const Duration(seconds: 1));
      // widget.itemScrollController?.jumpTo(index: 1);
    }
  }

  @override
  void dispose() {
    itemPositionsListener.itemPositions.removeListener(_onListCurrentChange);
    super.dispose();
  }

  void _onListCurrentChange() {
    var to = itemPositionsListener.itemPositions.value.first.index;
    // historyStorage.saveIndex(id: widget.id, index: to);
    // 包含一个下一章, 假设5张图片 0,1,2,3,4 length=5, 下一章=5
    if (to >= 0 && to < widget.list.length) {
      widget.setCurrentIndex!(to);
      historyStorage.saveIndex(id: widget.id, index: to);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
        physics: const ClampingScrollPhysics(), //去掉弹性,
        // padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _list.length,
        initialScrollIndex: widget.initIndex,
        itemScrollController: widget.itemScrollController,
        scrollOffsetController: widget.controller,
        itemPositionsListener: itemPositionsListener,
        scrollOffsetListener: scrollOffsetListener,
        // cacheExtent: 1280,
        minCacheExtent: 1280,
        // restorationId: widget.rid,
        itemBuilder: (context, index) {
          //如果到了表尾
          if (_list[index].title == loadingTag) {
            //未渲染完成，继续获取数据
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
            onLongPress: () async {
              // Todo 点击查看大图
              int result = await Navigator.of(context).push(FadeRoute(
                  page: GalleryList(
                list: widget.list.map((e) => e.url).toList(),
                index: index,
              )));
              // 同步查看位置
              widget.itemScrollController?.jumpTo(index: result);
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
      onTapDown,
      this.position = PositionType.rightBottom});
  final bool show;
  String string;
  void Function()? onTapDown;
  PositionType position;
  @override
  Widget build(BuildContext context) {
    dynamic left, bottom, right, top;
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
      child: show
          ? InkWell(
              onTap: () {
                if (onTapDown != null) onTapDown!();
              },
              child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.4,
                  height: MediaQuery.of(context).size.height / 3,
                  child: Container(
                      color: Colors.black45,
                      child: Center(
                        child: Text(string,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 28),
                            textAlign: TextAlign.center),
                      ))))
          : const SizedBox(),
    );
  }
}

////////////////////////////////

// 仅支持安卓
// 监听后会拦截安卓手机音量键
// 仅最后一次监听生效
// event可能为DOWN/UP

var _volumeListenCount = 0;

void _onVolumeEvent(dynamic args) {
  _readerControllerEvent.broadcast(_ReaderControllerEventArgs("$args"));
}

EventChannel volumeButtonChannel = const EventChannel("volume_button");
StreamSubscription? volumeS;

void addVolumeListen() {
  _volumeListenCount++;
  if (_volumeListenCount == 1) {
    volumeS =
        volumeButtonChannel.receiveBroadcastStream().listen(_onVolumeEvent);
  }
}

void delVolumeListen() {
  _volumeListenCount--;
  if (_volumeListenCount == 0) {
    volumeS?.cancel();
  }
}

Widget readerKeyboardHolder(Widget widget) {
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    widget = RawKeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.isKeyPressed(LogicalKeyboardKey.arrowUp)) {
            _readerControllerEvent.broadcast(_ReaderControllerEventArgs("UP"));
          }
          if (event.isKeyPressed(LogicalKeyboardKey.arrowDown)) {
            _readerControllerEvent
                .broadcast(_ReaderControllerEventArgs("DOWN"));
          }
        }
      },
      child: widget,
    );
  }
  return widget;
}

////////////////////////////////

Event<_ReaderControllerEventArgs> _readerControllerEvent =
    Event<_ReaderControllerEventArgs>();

class _ReaderControllerEventArgs extends EventArgs {
  final String key;

  _ReaderControllerEventArgs(this.key);
}
