import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image.dart';

class GalleryList extends StatefulWidget {
  GalleryList(
      {super.key, required this.list, this.index = 0, this.heroTag = ''})
      : pageController = PageController(initialPage: index);
  final List<String> list;
  String heroTag;
  int index;
  final PageController pageController;

  @override
  State<StatefulWidget> createState() => _PhotoViewGalleryScreenState();
}

class _PhotoViewGalleryScreenState extends State<GalleryList> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.index;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) {
            return;
          }
          /// 关闭时返回当前图片索引
          Navigator.pop(context, currentIndex);
        },
        child: KeyboardListener(
            autofocus: true,
            focusNode: FocusNode(), // 焦点
            onKeyEvent: (event) {
              var keyLabel = event.logicalKey.debugName;
              print(event.logicalKey);
              if (currentIndex < widget.list.length - 1 &&
                  ['Arrow Down', 'Arrow Right', 'Space'].contains(keyLabel)) {
                // 下一页
                widget.pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.linear);
              } else if (currentIndex > 0 &&
                  ['Arrow Top', 'Arrow Up', 'Arrow Left'].contains(keyLabel)) {
                // 上一页
                widget.pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.linear);
              }
            },
            child: Scaffold(
              body: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0,
                    left: 0,
                    bottom: 0,
                    right: 0,
                    child: PhotoViewGallery.builder(
                      scrollPhysics: const BouncingScrollPhysics(),
                      builder: (BuildContext context, int index) {
                        return PhotoViewGalleryPageOptions(
                          imageProvider:
                              CachedNetworkImageProvider(widget.list[index]),
                          heroAttributes: widget.heroTag.isNotEmpty
                              ? PhotoViewHeroAttributes(tag: widget.heroTag)
                              : null,
                        );
                      },
                      itemCount: widget.list.length,
                      backgroundDecoration: null,
                      pageController: widget.pageController,
                      // enableRotation: true,
                      wantKeepAlive: true,
                      onPageChanged: (index) {
                        setState(() {
                          currentIndex = index;
                        });
                        /** 画廊提前缓存两张图片 */
                        if (widget.list[index + 1].isNotEmpty) {
                          CachedNetworkImageProvider(widget.list[index + 1]);
                        }
                        if (widget.list[index + 2].isNotEmpty) {
                          CachedNetworkImageProvider(widget.list[index + 2]);
                        }
                      },
                    ),
                  ),
                  Positioned(
                    //图片index显示
                    bottom: 10,
                    width: MediaQuery.of(context).size.width,
                    child: Center(
                      child: Text("${currentIndex + 1}/${widget.list.length}",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  Positioned(
                    //图片index显示
                    bottom: 10,
                    right: 10,
                    child: IconButton(
                      icon: const Icon(
                        Icons.download,
                        size: 30,
                        color: Colors.white,
                      ),
                      onPressed: () async {
                        var promise = await ImageUtil.saveImage(
                            widget.list[currentIndex]);
                          Get.snackbar( '提示', promise ? '保存成功' : '保存失败',
                            colorText: promise
                                ? Colors.white
                                : const Color(0xFFFF4081),
                          );
                      },
                    ),
                  ),
                  Positioned(
                    //右上角关闭按钮
                    right: 10,
                    top: MediaQuery.of(context).padding.top,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 30,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context, currentIndex);
                      },
                    ),
                  ),
                ],
              ),
            )));
  }
}
