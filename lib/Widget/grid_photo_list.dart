import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utlis/api.dart';

class GridPhotoList extends StatefulWidget {
  const GridPhotoList({Key? key, required this.list}) : super(key: key);
  final List<ChapterItemProp> list;
  @override
  State<GridPhotoList> createState() => __GridPhotoList();
}

class __GridPhotoList extends State<GridPhotoList> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
      var crossAxisCount = constraints.maxWidth /
          175; // constraints.maxWidth > constraints.maxHeight ? 4 : 2;
      return GridView.count(
        restorationId: 'grid_view_demo_grid_offset',
        crossAxisCount: crossAxisCount > 5 ? 5 : crossAxisCount.toInt(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        childAspectRatio: 1,
        children: widget.list.map<Widget>((item) {
          return _GridPhotoItem(
            item: item,
          );
        }).toList(),
      );
    });
  }
}

class _GridPhotoItem extends StatelessWidget {
  const _GridPhotoItem({
    Key? key,
    required this.item,
  }) : super(key: key);

  final ChapterItemProp item;

  @override
  Widget build(BuildContext context) {
    final Widget image = Material(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: item.image,
        fit: BoxFit.cover,
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );

    return InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/detail', arguments: item.id);
        },
        child: GridTile(
          footer: Material(
            color: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: GridTileBar(
              backgroundColor: Colors.black45,
              title: _GridTitleText(item.title),
              // subtitle: _GridTitleText(item.title),
            ),
          ),
          child: image,
        ));
  }
}

class _GridTitleText extends StatelessWidget {
  const _GridTitleText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}
