import 'package:flutter/material.dart';
import '../utlis/api.dart';

class ComicChapter extends StatefulWidget {
  const ComicChapter(
      {super.key, this.page = 1, this.tag = 0, required this.id});

  final int id;
  final int page;
  final int tag;

  @override
  State<ComicChapter> createState() => _ComicChapter();
}

class _ComicChapter extends State<ComicChapter> {
  String name = '';
  List<String> tags = [];
  int totalPage = 1;
  int currentPage = 1;
  int currentTag = 0;
  bool isLoading = true;
  List<ChapterItemProp> list = [];

  void setChapterData(ChapterProp result) {
    setState(() {
      name = result.name;
      totalPage = result.totalPage;
      tags = result.tags;
      list = result.list;
      isLoading = false;
    });
  }

  void getData({int? page, int? tag}) {
    setState(() {
      if (page != null) currentPage = page;
      if (tag != null) currentTag = tag;
    });
    getChapter();
  }

  void getChapter() {
    setState(() {
      isLoading = true;
    });
    apiServer.getChapter(widget.id, currentPage, currentTag).then((result) {
      setChapterData(result);
    });
  }

  @override
  void initState() {
    super.initState();
    currentPage = widget.page;
    currentTag = widget.tag;
    getChapter();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        // appBar: AppBar(
        //   title: Text(name),
        // ),
        body: isLoading
            ? Center(
                child: Column(children: const [
                  Padding(padding: EdgeInsets.all(80)),
                  CircularProgressIndicator(),
                  Padding(padding: EdgeInsets.all(8)),
                  Text("数据加载中!")
                ]),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: SizedBox(
                      height: 32,
                      child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: tags.asMap().keys.map((i) {
                            if (currentTag == i) {
                              return ElevatedButton(
                                child: Text(tags[i]),
                                onPressed: () {},
                              );
                            } else {
                              return TextButton(
                                  onPressed: () {
                                    getData(tag: i, page: 1);
                                  },
                                  child: Text(tags[i]));
                            }
                          }).toList()),
                    ),
                  ),
                  Expanded(child: _GridPhotoList(list: list)),
                  const Padding(padding: EdgeInsets.all(8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: currentPage == 1
                                ? const Color(0xFFF9F9F9)
                                : null),
                        onPressed: () {
                          if (currentPage <= 1) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已经是第一页了!')));
                            return;
                          }
                          /** 上一页 */
                          getData(page: currentPage - 1);
                        },
                        child: const Text('上一页'),
                      ),
                      const Padding(padding: EdgeInsets.all(8)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: currentPage == totalPage
                                ? const Color(0xFFF9F9F9)
                                : null),
                        child: const Text("下一页"),
                        onPressed: () {
                          if (currentPage >= totalPage) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('已经是最后一页了!')));
                            return;
                          }
                          /** 下一页 */
                          getData(page: currentPage + 1);
                        },
                      )
                    ],
                  ),
                  const Padding(padding: EdgeInsets.all(8)),
                ],
              ));
  }
}

class _GridPhotoList extends StatefulWidget {
  const _GridPhotoList({Key? key, required this.list}) : super(key: key);
  final List<ChapterItemProp> list;
  @override
  State<_GridPhotoList> createState() => __GridPhotoList();
}

class __GridPhotoList extends State<_GridPhotoList> {
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
      child: Image.network(
        item.image,
        fit: BoxFit.cover,
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
              // title: _GridTitleText(item.title),
              subtitle: _GridTitleText(item.title),
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
    return Tooltip(
      message: text,
      child: Text(text, overflow: TextOverflow.ellipsis),
    );
  }
}
