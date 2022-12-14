import 'package:flutter/material.dart';
import '../utlis/storage.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
                      ElevatedButton(
                        onPressed: () async {
                          await historyStorage.clear();
                          setState(() {
                            list = [];
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('删除'),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
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
                      onTap: () {
                        var item = list[index];
                        historyStorage.save(item.id, item.title, item.image);
                        Navigator.pushNamed(context, '/detail',
                            arguments: item.id);
                      },
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text(list[index].title),
                      subtitle: Text(list[index].creatAt),
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
