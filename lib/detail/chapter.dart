import 'package:flutter/material.dart';
import '../utlis/api.dart';

class ComicChapter extends StatefulWidget {
  const ComicChapter({super.key, required this.id});

  final int id;

  @override
  State<ComicChapter> createState() => _ComicChapter();
}

class _ComicChapter extends State<ComicChapter> {
  String name = '';
  List<String> tags = [];
  int currentPage = 1;
  int currentTag = 0;
  int totalPage = 0;
  List<ChapterItemProp> list = [];

  void setChapterData(ChapterProp result) {
    setState(() {
      name = result.name;
      currentPage = result.currentPage;
      totalPage = result.totalPage;
      tags = result.tags;
      list = result.list;
    });
  }

  @override
  void initState() {
    super.initState();
    apiServer.getChapter(widget.id, currentPage, currentTag).then((result) {
      setChapterData(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("demoGridListsTitle"),
      ),
      body: GridView.count(
        restorationId: 'grid_view_demo_grid_offset',
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        padding: const EdgeInsets.all(8),
        childAspectRatio: 1,
        children: list.map<Widget>((item) {
          return _GridDemoPhotoItem(
            item: item,
          );
        }).toList(),
      ),
    );
  }
}

class _GridDemoPhotoItem extends StatelessWidget {
  const _GridDemoPhotoItem({
    Key? key,
    required this.item,
  }) : super(key: key);

  final ChapterItemProp item;

  get arguments => null;

  @override
  Widget build(BuildContext context) {
    final Widget image = Material(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        item.image,
        fit: BoxFit.cover,
      ),
    );

    return InkWell(
        onTap: () {
          Navigator.pushNamed(context, 'detail', arguments: item);
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
              // subtitle: _GridTitleText(photo.subtitle),
            ),
          ),
          child: image,
        ));
  }
}

/// Allow the text size to shrink to fit in the space
class _GridTitleText extends StatelessWidget {
  const _GridTitleText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text(text),
    );
  }
}
