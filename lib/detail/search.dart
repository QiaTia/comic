import 'package:flutter/material.dart';
import '../Widget/grid_photo_list.dart';
import '../Widget/pagination.dart';
import '../Widget/white_data.dart';
import '../utlis/api.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<StatefulWidget> createState() => _SearchPage();
}

class _SearchPage extends State<StatefulWidget> {
  bool _isShowDelete = false;
  late TextEditingController _controller;
  String val = '';
  int totalPage = 1;
  int currentPage = 1;
  bool isLoading = false;
  List<ChapterItemProp> list = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  void _getData([String? value]) {
    setState(() {
      isLoading = true;
      if (value != null) {
        val = value;
        currentPage = 1;
      }
    });
    apiServer.getSearch(val, currentPage).then((data) {
      setState(() {
        list = data.list;
        totalPage = data.totalPage;
        isLoading = false;
      });
    });
  }

  void _getPageData(int page) {
    setState(() {
      currentPage = page;
    });
    _getData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 1.0), //灰色的一层边框
            color: Colors.white,
            borderRadius: const BorderRadius.all(Radius.circular(5.0)),
          ),
          alignment: Alignment.bottomCenter,
          height: 42,
          child: TextField(
              autofocus: true,
              controller: _controller,
              textAlignVertical: TextAlignVertical.bottom,
              onSubmitted: (value) {
                if (value.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please enter content !')));
                  return;
                }
                _getData(value);
              },
              onChanged: (value) {
                setState(() {
                  _isShowDelete = value.isNotEmpty && value != '';
                });
              },
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                  suffixIcon: _isShowDelete
                      ? IconButton(
                          onPressed: () {
                            _controller.text = '';
                          },
                          icon: const Icon(
                            Icons.cancel,
                            color: Color(0xFFC8C8C8),
                            size: 20,
                          ))
                      : null,
                  prefixIcon: const Icon(Icons.search),
                  hintText: "Please enter!")),
        ),
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
          : list.length > 1
              ? Column(
                  children: [
                    Expanded(child: GridPhotoList(list: list)),
                    Pagination(
                      current: currentPage,
                      total: totalPage,
                      onChange: _getPageData,
                    )
                  ],
                )
              : WhiteData(),
    );
  }

  @override
  dispose() {
    super.dispose();
    _controller.dispose();
  }
}
