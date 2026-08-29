import 'dart:async';
import 'package:comic/utils/historyStorage.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:get/get.dart';
import '../../widget/route_animation.dart';
import '../../utils/api.dart';
import '../../utils/request.dart';
import '../../utils/volumeListen.dart';
import 'gallery.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../../Widget/image/image-preloader.dart';
// Obtain shared preferences.
final _preloader = ImagePreloader();

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
  String coverUrl = '';
  // 是否展示头部标题栏
  bool isAppBar = true;
  // 当前页数
  RxInt currentPage = 0.obs;
  // 图片缓存中
  RxBool isImagePreloading = false.obs;
  // 图片缓存完成
  RxBool isImagePreloaded = false.obs;
  final ScrollOffsetController _controller = ScrollOffsetController();
  final ItemScrollController itemScrollController = ItemScrollController();

  /// 更新当前页数
  void setCurrentIndex(int page) {
    currentPage.value = page;
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

  void onPreload() async {
    if (isImagePreloading.value || isImagePreloaded.value) {
      Get.snackbar(title, "任务已经在进行中啦——");
      return;
    }
    final list = _photos.map((el) => el.url).toList();
    if (list.isEmpty) {
      Get.snackbar(title, "请等待⌛️图片列表完成 !");
      return;
    }
    isImagePreloading.value = true;
    await _preloader.preloadImages(list, context);
    isImagePreloaded.value = true;
  }
  /// 初始化内容
  void init() async {
    if (widget.list != null) {
      await Future.delayed(const Duration(seconds: 1));
      for (var element in widget.list!) {
        addItem(element);
      }
      // 定位到历史阅读位置由 _PhotoList 内部完成：
      // 固定延迟 jumpTo 会与图片异步加载竞态（占位 150px → 真实 2000px，
      // 上方内容增长把目标页顶出屏幕），需带稳定确认的重试机制。
    } else {
      var result = await apiServer.getDetail(widget.options.id, widget.page);
      for (var element in result.data) {
        addItem(element);
      }
      // 保存历史记录
      historyStorage.save(
          id: widget.options.id,
          title: result.title!,
          image: widget.options.image,
          images: result.data,
          index: widget.initIndex);
    }
  }

  @override
  void initState() {
    super.initState();
    setTitle(widget.options.title);
    setAppBar();
    init();
  }

  @override
  void dispose() {
    systemUiMode(true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var screenSize = MediaQuery.of(context).size;
    var controllerWidth = screenSize.width * 0.4,
        controllerBottom = (screenSize.height / 3) * 2;
    return VolumeListen(
        onKeyEvent: (logicalKey) {
          if (logicalKey == LogicalKeyboardKey.arrowUp ||
              logicalKey == LogicalKeyboardKey.audioVolumeDown) {
            jump(true);
          } else if (logicalKey == LogicalKeyboardKey.arrowDown ||
              logicalKey == LogicalKeyboardKey.audioVolumeUp) {
            jump();
          }
        },
        child: Scaffold(
            appBar: isAppBar ? AppBar(
                    title: Text(title),
                    actions: [
                      IconButton(
                        onPressed: onPreload,
                        icon: Obx(() => isImagePreloaded.value ? const Icon(Icons.download_done) : const Icon(Icons.download))),
                      SizedBox(
                        width: 98,
                        child:Obx(() => TextField(
                          textAlignVertical: TextAlignVertical.center,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9]')) //设置只允许输入数字
                          ],
                          textInputAction: TextInputAction.go,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '${currentPage.value} / ${_photos.length}',
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
                        )),
                      ),
                    ],
                  )
                : null,
            body: _photos.isEmpty
                ? Center(
                    child: Column(children: [
                      const Padding(padding: EdgeInsets.only(top: 40)),
                      Hero(
                        tag: widget.options.image,
                        child: CachedNetworkImage(
                          imageUrl: widget.options.image,
                          httpHeaders: imageHeadersFor(widget.options.image),
                          // 与列表项一致：限制解码宽度，避免全尺寸大图进内存
                          memCacheWidth: 720,
                          fit: BoxFit.cover,),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 40, bottom: 20),
                        child: CircularProgressIndicator(),
                      ),
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
                                  if (dx < controllerWidth &&
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
  final _ListPhotoItemTapDown? onTapDown;
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

  /// 初始定位是否已完成（完成后才允许把位置写入历史记录）。
  bool _initialJumpDone = false;

  /// 用户是否已手动滑动（滑动后立即放弃定位重试，尊重用户操作）。
  bool _userInteracted = false;

  /// 定位重试计数与连续稳定确认计数。
  int _jumpAttempts = 0;
  int _stableChecks = 0;
  Timer? _jumpRetryTimer;

  /// 动态拼装列表
  void _retrieveData() {
    Future.delayed(const Duration(milliseconds: 100)).then((e) {
      if (!mounted) return;
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
    _fillInitialBatch();
    itemPositionsListener.itemPositions.addListener(_onListCurrentChange);
    if (widget.initIndex > 0) {
      // 等首帧布局完成后再开始定位（图片此时还是占位高度，
      // 定位与纠偏由 _tryInitialJump 的重试循环负责）。
      _jumpRetryTimer = Timer(const Duration(milliseconds: 400), _tryInitialJump);
    } else {
      _initialJumpDone = true;
    }
  }

  /// 首批直接铺到 initIndex+10：jumpTo 要求索引在 itemCount 内，
  /// 原先首批只铺 10 项，initIndex > 10 时定位直接失效。
  void _fillInitialBatch() {
    final end = (widget.initIndex + 10) > widget.list.length
        ? widget.list.length
        : widget.initIndex + 10;
    _list.insertAll(0, widget.list.sublist(0, end));
  }

  /// 带稳定确认的初始定位。
  ///
  /// 图片异步加载导致 item 高度从占位 150px 涨到真实值，上方内容增长
  /// 会持续把锚定页顶出视口。策略：目标页未贴近视口顶部就重新 jumpTo；
  /// 已到位则继续观察（连续 3 次确认稳定才算完成）；用户手动滑动或
  /// 重试超限时放弃。完成前不写历史（避免错位 index 覆盖真实进度）。
  void _tryInitialJump() {
    if (!mounted || _initialJumpDone || _userInteracted) return;
    if (_jumpAttempts++ > 12) {
      _initialJumpDone = true;
      return;
    }
    ItemPosition? target;
    for (final p in itemPositionsListener.itemPositions.value) {
      if (p.index == widget.initIndex) {
        target = p;
        break;
      }
    }
    // itemLeadingEdge ∈ [0,1]（视口内），0 为顶部；负值表示在视口上方
    final aligned = target != null &&
        target.itemLeadingEdge > -0.05 &&
        target.itemLeadingEdge < 0.3;
    if (aligned) {
      if (++_stableChecks >= 3) {
        _initialJumpDone = true;
        return;
      }
    } else {
      _stableChecks = 0;
      widget.itemScrollController?.jumpTo(index: widget.initIndex);
    }
    _jumpRetryTimer = Timer(const Duration(milliseconds: 600), _tryInitialJump);
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
    _jumpRetryTimer?.cancel();
    itemPositionsListener.itemPositions.removeListener(_onListCurrentChange);
    super.dispose();
  }

  void _onListCurrentChange() {
    var to = itemPositionsListener.itemPositions.value.first.index;
    // historyStorage.saveIndex(id: widget.id, index: to);
    // 包含一个下一章, 假设5张图片 0,1,2,3,4 length=5, 下一章=5
    // 定位完成前不写历史：初始 jump 过程中视口短暂停在错误的页，
    // 会把错误 index 覆盖进历史记录（真实进度丢失的根因之一）。
    if (to >= 0 && to < widget.list.length) {
      widget.setCurrentIndex!(to);
      if (_initialJumpDone) {
        historyStorage.saveIndex(id: widget.id, index: to);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
        // 用户一旦触摸列表就放弃自动定位重试，尊重用户操作
        onPointerDown: (_) => _userInteracted = true,
        child: ScrollablePositionedList.builder(
        physics: const ClampingScrollPhysics(), //去掉弹性,
        // padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _list.length,
        initialScrollIndex: widget.initIndex,
        itemScrollController: widget.itemScrollController,
        scrollOffsetController: widget.controller,
        itemPositionsListener: itemPositionsListener,
        scrollOffsetListener: scrollOffsetListener,
        addAutomaticKeepAlives: true,
        /// 预加载一页半的内容
        minCacheExtent: MediaQuery.of(context).size.height * 1.4,
        // restorationId: widget.rid,
        itemBuilder: (context, index) {
          var next = index + 1;
          // 预先缓存下一张内容
          // 原条件 `_list.length < next` 恒为 false（next 最多等于 length），
          // 预加载分支从未执行。改为 next 在有效范围内且非表尾标记时预取。
          if (next < _list.length && _list[next].title != loadingTag) {
            _preloader.preloadImage(_list[next].url, context);
          }
          //如果到了表尾
          else if (_list[index].title == loadingTag) {
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
              // 点击查看大图
              // 注意：FadeRoute 是 Route 对象，GetX 的 Get.to() 只接受
              // Widget/页面构造函数，传 Route 会抛
              // "Unexpected format, you can only use widgets and widget
              // functions here"（长按无响应的根因）。必须走 Navigator.push。
              final result = await Navigator.of(context)
                  .push<int>(FadeRoute(page: GalleryList(
                list: widget.list.map((e) => e.url).toList(),
                index: index,
              )));
              // 同步查看位置（大图页 pop 返回当前索引；系统返回键等返回 null）
              if (result != null && result != index) {
                widget.itemScrollController?.jumpTo(index: result);
              }
            },
          );
        }));
  }
}

typedef _ListPhotoItemTap = void Function();
typedef _ListPhotoItemTapDown = void Function(TapDownDetails detail);

class _ListPhotoItem extends StatelessWidget {
  // 非 const 构造：_headers 是 late final（构造后惰性求值一次），
  // 与 const 构造不兼容；调用处本就不使用 const。
  _ListPhotoItem(
      {Key? key, required this.item, this.onTapDown, this.onLongPress})
      : super(key: key);
  final _Photo item;
  final _ListPhotoItemTap? onLongPress;
  final _ListPhotoItemTapDown? onTapDown;

  /// headers 只在构造时计算一次。此前每次 build 都调 imageHeadersFor()
  /// （Uri.parse + cookie 拼接 + Map 分配），下载进度每 tick 都会 rebuild
  /// item，滚动中高频执行造成 GC 压力。
  late final Map<String, String> _headers = imageHeadersFor(item.url);

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
                httpHeaders: _headers,
                // 内存解码降采样：漫画原图约 1200×1800，全尺寸解码每张
                // ~8.6MB RGBA，叠加 minCacheExtent 1.4 屏的预渲染区，
                // 解码缓存与 GPU 纹理压力直接表现为滚动掉帧。限制到
                // 2 倍物理屏宽，视觉无差异、内存降 60%+。
                memCacheWidth:
                    (MediaQuery.of(context).size.width *
                            MediaQuery.of(context).devicePixelRatio *
                            2)
                        .round(),
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
