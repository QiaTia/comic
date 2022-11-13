import 'package:flutter/material.dart';
import '../utlis/api.dart';

class ComicDetail extends StatefulWidget {
  const ComicDetail({super.key, this.page = 1, required this.id});

  final String id;
  final int page;
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
  bool isLoading = true;

  void addItem(String url) {
    setState(() {
      _photos.add(_Photo(url: url, title: ""));
    });
  }

  void setTitle(String val) {
    setState(() {
      title = val;
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    apiServer.getDetail(widget.id, widget.page).then((result) {
      setTitle(result.title!);
      for (var element in result.data) {
        addItem(element);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
            appBar: AppBar(
              title: Text(title),
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
                          flex: 1,
                          child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: _photos.length,
                              itemBuilder: (context, index) => _ListPhotoItem(
                                    item: _photos[index],
                                  )))
                    ],
                  )));
  }
}

class _ListPhotoItem extends StatelessWidget {
  const _ListPhotoItem({Key? key, required this.item}) : super(key: key);
  final _Photo item;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Image.network(
        item.url,
        fit: BoxFit.fitWidth,
      ),
      onTap: () {
        // Todo 点击查看大图
      },
    );
  }
}
