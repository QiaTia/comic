import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
        title: Text('history'.tr),
        actions: [
          IconButton(
              onPressed: () async {
                await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('deleteTip'.tr),
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
                        child: Text('deleteTipConfirm'.tr,
                            style: const TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('deleteTipCancel'.tr),
                      )
                    ],
                  ),
                );
              },
              tooltip: 'clear'.tr,
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
                      child: Text('tipRecordEmpty'.tr,
                          style: const TextStyle(color: Colors.grey)),
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
              child: Text('tipEmptyRecord'.tr),
            ),
    );
  }
}
