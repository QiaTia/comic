import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utlis/image.dart';

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
    return Scaffold(
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
                  imageProvider: CachedNetworkImageProvider(widget.list[index]),
                  heroAttributes: widget.heroTag.isNotEmpty
                      ? PhotoViewHeroAttributes(tag: widget.heroTag)
                      : null,
                );
              },
              itemCount: widget.list.length,
              backgroundDecoration: null,
              pageController: widget.pageController,
              enableRotation: true,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                });
              },
            ),
          ),
          Positioned(
            //图片index显示
            bottom: 10,
            width: MediaQuery.of(context).size.width,
            child: Center(
              child: Text("${currentIndex + 1}/${widget.list.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
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
                var promise =
                    await ImageUtil.saveImage(widget.list[widget.index]);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                  promise ? "Sucess!" : "Fail!",
                  style: TextStyle(
                      color: promise ? Colors.white : const Color(0xFFFF4081)),
                )));
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
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
