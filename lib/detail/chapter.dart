import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Widget/grid_photo_list.dart';
import '../Widget/pagination.dart';
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
                child: Column(children: [
                  const Padding(padding: EdgeInsets.all(80)),
                  const CircularProgressIndicator(),
                  const Padding(padding: EdgeInsets.all(8)),
                  Text("loading".tr)
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
                  Expanded(child: GridPhotoList(list: list)),
                  Pagination(
                    current: currentPage,
                    total: totalPage,
                    onChange: (page) => getData(page: page),
                  )
                ],
              ));
  }
}
