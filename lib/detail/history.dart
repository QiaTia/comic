import 'package:flutter/material.dart';
import '../utlis/storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail.dart';
import '../utlis/api.dart';

class ComicHistory extends StatefulWidget {
  const ComicHistory({super.key});
  @override
  State<ComicHistory> createState() => _ComicHistory();
}

class _ComicHistory extends State<ComicHistory> {
  List<HistorytItem> list = [];
  final ScrollController _controller = ScrollController();
  @override
  void initState() {
    super.initState();
    historyStorage.getList().then((value) {
      setState(() {
        list = value.reversed.toList();
      });
    });
  }

  void onDetail(HistorytItem item, BuildContext content) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (content) => ComicDetail(
              list: item.list,
              initIndex: item.index ?? 0,
              options: ChapterItemProp(
                  id: item.id, title: item.title, image: item.image),
            )));
    // Navigator.pushNamed(context, '/detail', arguments: item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('浏览历史'),
        actions: [
          IconButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('确认清除所有记录？'),
                    actions: [
                      TextButton(
                        onPressed: () async {
                          var navitator = Navigator.of(context);
                          await historyStorage.clear();
                          setState(() {
                            list = [];
                          });
                          navitator.pop();
                        },
                        child: const Text('删除',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('算了'),
                      )
                    ],
                  ),
                );
              },
              tooltip: '清除所有记录',
              icon: const Icon(Icons.clear_all_outlined))
        ],
      ),
      body: list.isNotEmpty
          ? ListView.builder(
              controller: _controller,
              padding: const EdgeInsets.all(8),
              itemBuilder: (context, index) => index == list.length
                  ? Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text('已经没有啦！',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListTile(
                      onTap: () => onDetail(list[index], context),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text(list[index].title),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(list[index].creatAt),
                          Text(
                              "${list[index].index}/${list[index].list.length}",
                              style: const TextStyle(color: Colors.grey))
                        ],
                      ),
                      leading: CachedNetworkImage(
                        imageUrl: list[index].image,
                        fit: BoxFit.cover,
                        progressIndicatorBuilder:
                            (context, url, downloadProgress) =>
                                CircularProgressIndicator(
                                    value: downloadProgress.progress),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
              itemCount: list.length + 1)
          : Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text('还没有记录哟！'),
            ),
    );
  }
}
