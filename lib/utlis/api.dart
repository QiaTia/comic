import 'request.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

class APIServer {
  Future<ChapterProp> getChapter(int id, [int page = 1, int tag = 0]) async {
    final content = await httpService.get("/list-$id-$tag-$page.html");
    Document document =
        parse(content.putIfAbsent("data", () => "<html></html>"));
    /** 获取分类名称 */
    String name = document.querySelector('.content > .imenu')!.text.trim();
    /** 组合标签信息 */
    List<Element> tagsElement =
        document.querySelectorAll('.content > .sx >  a');
    List<String> tags = [];
    for (var element in tagsElement) {
      tags.add(element.text);
    }
    /** 获取分页列表 */
    List<Element> pageElement =
        document.querySelectorAll('.stui-page > li >  a');
    String pageTemp = pageElement.last.attributes['href']!.split('-').last;
    int totalPage = int.parse(
        pageTemp == 'javascript:void(0)' ? '1' : pageTemp.split(".").first);
    /** 数据列表获取 */
    List<ChapterItemProp> chapterList = [];
    List<Element> listElement =
        document.querySelectorAll('.content > .top-grids > .group > a');
    RegExp reg = RegExp(r"(?<=url\(\')\S+(?=\')");
    for (var element in listElement) {
      var link = element.attributes['href']!
          .split('-')[1]
          .replaceAll(RegExp('.html\$'), '');
      var title = element.querySelector('.topgrid-desc')!.text.trim();
      var imageTemp =
          element.querySelector('.top_grid > div')!.attributes['style']!;
      // print(imageTemp);
      var image = reg.allMatches(imageTemp).first[0]!;
      // print('$title name is $link !');
      chapterList.add(ChapterItemProp(
          title: title, id: link, image: httpService.completionUri(image)));
    }
    return ChapterProp(
        currentPage: page,
        name: name,
        list: chapterList,
        tags: tags,
        totalPage: totalPage);
  }

  Future<DetailProp> getDetail(String id, [int page = 1]) async {
    final content = await httpService.get("/content-$id-$page.html");
    // value.hashCode('data')
    Document document =
        parse(content.putIfAbsent("data", () => "<html></html>"));
    List<Element> images = document.querySelectorAll('.contentmh > li >  img');
    String? title = document.querySelector('.services-desc > h2')?.text;
    List<String> data = [];
    if (images.isNotEmpty) {
      for (var element in images) {
        var url = element.attributes['data-original']!;
        if (url.isNotEmpty) {
          data.add(httpService.completionUri(url));
        }
      }
    }
    return DetailProp(title: title, data: data);
    // .then((value) {
    //   // print(value.hashCode('data'));

    // });
  }

  Future<ChapterProp> getSearch(String val, [int page = 1]) async {
    final content = await httpService.get("/search.php?key=$val&p=$page");
    Document document =
        parse(content.putIfAbsent("data", () => "<html></html>"));
    /** 获取分类名称 */
    String name = '';
    /** 组合标签信息 */
    List<String> tags = [];
    /** 获取分页列表 */
    List<Element> pageElement =
        document.querySelectorAll('.stui-page > li >  a');
    String pageTemp = pageElement.last.attributes['href']!;
    int totalPage = int.parse(
        pageTemp == 'javascript:void(0)' ? '1' : pageTemp.split("=").last);
    /** 数据列表获取 */
    List<ChapterItemProp> chapterList = [];
    List<Element> listElement =
        document.querySelectorAll('.content > .top-grids > .group > a');
    RegExp reg = RegExp(r"(?<=url\(\')\S+(?=\')");
    for (var element in listElement) {
      var link = element.attributes['href']!.split('-')[1];
      var title = element.querySelector('.topgrid-desc')!.text.trim();
      var imageTemp =
          element.querySelector('.top_grid > div')!.attributes['style']!;
      // print(imageTemp);
      var image = reg.allMatches(imageTemp).first[0]!;
      // print('$title name is $link !');
      chapterList.add(ChapterItemProp(title: title, id: link, image: image));
    }
    return ChapterProp(
        currentPage: page,
        name: name,
        list: chapterList,
        tags: tags,
        totalPage: totalPage);
  }
}

class DetailProp {
  final List<String> data;
  final String? title;
  DetailProp({this.title, required this.data});
}

class ChapterProp {
  final String name;
  final List<String> tags;
  final List<ChapterItemProp> list;
  final int currentPage;
  final int totalPage;
  ChapterProp(
      {required this.name,
      required this.currentPage,
      required this.totalPage,
      required this.list,
      required this.tags});
}

class ChapterItemProp {
  final String title;
  final String id;
  final String image;
  ChapterItemProp({required this.title, required this.id, required this.image});
}

final APIServer apiServer = APIServer();
