import 'package:flutter/material.dart';
import '../utlis/api.dart';

class ComicChapter extends StatefulWidget {
  const ComicChapter(
      {super.key, this.currentPage = 1, this.currentTag = 0, required this.id});

  final int id;
  final int currentPage;
  final int currentTag;

  @override
  State<ComicChapter> createState() => _ComicChapter();
}

class _ComicChapter extends State<ComicChapter> {
  String name = '';
  List<String> tags = [];
  int totalPage = 0;
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

  @override
  void initState() {
    super.initState();
    apiServer
        .getChapter(widget.id, widget.currentPage, widget.currentTag)
        .then((result) {
      setChapterData(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(name),
        ),
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
                  Expanded(
                      child: GridView.count(
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
                  )),
                  const Padding(padding: EdgeInsets.all(8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: widget.currentPage == 1
                                ? const Color(0xFFF9F9F9)
                                : null),
                        onPressed: () {
                          /** 上一页 */
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ComicChapter(
                                        id: widget.id,
                                        currentPage: widget.currentPage - 1,
                                      )));
                        },
                        child: const Text('上一页'),
                      ),
                      const Padding(padding: EdgeInsets.all(8)),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: widget.currentPage == totalPage
                                ? const Color(0xFFF9F9F9)
                                : null),
                        child: const Text("下一页"),
                        onPressed: () {
                          /** 下一页 */
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => ComicChapter(
                                        id: widget.id,
                                        currentPage: widget.currentPage + 1,
                                      )));
                          // Navigator.replace(
                          //   context,
                          //   oldRoute: MaterialPageRoute(builder: (context) {
                          //     return ComicChapter(
                          //       id: widget.id,
                          //       currentPage: widget.currentPage,
                          //       currentTag: widget.currentTag,
                          //     );
                          //   }),
                          //   newRoute: MaterialPageRoute(builder: (context) {
                          //     return ComicChapter(
                          //       id: widget.id,
                          //       currentPage: widget.currentPage + 1,
                          //     );
                          //   }),
                          // );
                        },
                      )
                    ],
                  ),
                  const Padding(padding: EdgeInsets.all(8)),
                ],
              ));
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
