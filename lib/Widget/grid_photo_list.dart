import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:layout/layout.dart';
import '../utils/api.dart';
import '../utils/request.dart';

class GridPhotoList extends StatefulWidget {
  const GridPhotoList({Key? key, required this.list}) : super(key: key);
  final List<ChapterItemProp> list;
  @override
  State<GridPhotoList> createState() => __GridPhotoList();
}

class __GridPhotoList extends State<GridPhotoList> {
  @override
  Widget build(BuildContext context) {
    /// 计算间距
    final double padding = context.layout.value(
      xs: 8,  // sm value will be like xs 0.0
      md: 12, // lg value will be like md 24.0
      xl: 14
    );
    /// 计算列数
    final int crossAxisCount = context.layout.value(
      xs: 2,
      sm: 3,
      md: 4,
      lg: 6,
    );
    return GridView.count(
      restorationId: 'grid_view_demo_grid_offset',
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: padding,
      crossAxisSpacing: padding,
      padding: EdgeInsets.all(padding),
      childAspectRatio: 1,
      children: widget.list
        .map((item) => _GridPhotoItem(item: item)).toList(),
    );
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
        httpHeaders: imageHeader,
        fit: BoxFit.cover,
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );

    return InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/detail', arguments: item);
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
