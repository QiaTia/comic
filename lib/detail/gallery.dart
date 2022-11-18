import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GalleryList extends StatefulWidget {
  const GalleryList({Key? key, required this.list}) : super(key: key);
  final List<String> list;

  @override
  State<StatefulWidget> createState() => _GalleryList();
}

class _GalleryList extends State<GalleryList> {
  @override
  Widget build(BuildContext context) {
    return PhotoViewGallery.builder(
      scrollPhysics: const BouncingScrollPhysics(),
      builder: (BuildContext context, int index) {
        return CachedNetworkImage(
                imageUrl: widget.list[index],
                imageBuilder: (context, imageProvider) {
                  return PhotoViewGalleryPageOptions(
                    initialScale: PhotoViewComputedScale.contained * 0.8,
                    imageProvider:imageProvider );
                );
      },
      itemCount: widget.list.length,
      loadingBuilder: (context, event) => Center(
        child: SizedBox(
          width: 20.0,
          height: 20.0,
          child: CircularProgressIndicator(
            value: event == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
      ),
    );
  }
}
