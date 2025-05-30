import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../utils/historyStorage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'detail.dart';
import '../../utils/api.dart';

class ComicHistory extends StatefulWidget {
  const ComicHistory({super.key});
  @override
  State<ComicHistory> createState() => _ComicHistory();
}

class _ComicHistory extends State<ComicHistory> {
  List<HistoryItem> list = [];
  final ScrollController _controller = ScrollController();
  @override
  void initState() {
    super.initState();
    /// 初始化历史记录
    // syncData();
    historyStorage.getList().then((value) {
      setState(() {
        list = value.reversed.toList();
      });
    });
  }

  /// 同步数据
  void syncData() {
    setState(() {
      list = historyStorage.historyList.reversed.toList();
    });
  }
  /// 删所有历史记录
  void onRemoveAll() async {
   await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('deleteTip'.tr),
        actions: [
          TextButton(
            onPressed: () async {
              await historyStorage.clear();
              setState(() {
                list = [];
              });
              Get.back();
              },
            child: Text('deleteTipConfirm'.tr,
                style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // 关闭对话框
            },
            child: Text('deleteTipCancel'.tr),
          )
        ],
      ),
    );
  }
  /// 删除历史记录
  void onDelete(HistoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('deleteTheTip'.tr),
        content: Text(item.title),
        actions: [
          TextButton(
            onPressed: () async {
              await historyStorage.removeItem(item.id);
              syncData();
              Get.back();
            },
            child: Text('deleteTipConfirm'.tr,
                style: const TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Get.back();
              // 关闭对话框
            },
            child: Text('deleteTipCancel'.tr),
          )
        ],
      ),
    );
  }
  /// 去历史记录详情
  void onDetail(HistoryItem item) async {
    var nextPage = ComicDetail(
      list: item.list,
      initIndex: item.index ?? 0,
      options: ChapterItemProp(
          id: item.id, title: item.title, image: item.image),
    );
    await Navigator.of(context).push(MaterialPageRoute(builder: (content) => nextPage));
    /// 回来之后同步下数据
    syncData();
    // Navigator.pushNamed(context, '/detail', arguments: item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('history'.tr),
        actions: [
          IconButton(
              onPressed: onRemoveAll,
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
                      onTap: () => onDetail(list[index]),
                      onLongPress: () => onDelete(list[index]),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      title: Text(list[index].title),
                      subtitle: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(list[index].createdAt,
                              style: const TextStyle(color: Colors.grey)),
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
