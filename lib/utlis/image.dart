/// 使用 File api
import 'dart:collection';
import 'dart:io';

import 'package:flutter/services.dart';

/// 使用 DefaultCacheManager 类
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// 授权管理
import 'package:permission_handler/permission_handler.dart';

/// 图片缓存管理
import 'package:cached_network_image/cached_network_image.dart';

/// 保存文件或图片到本地
import 'package:image_gallery_saver/image_gallery_saver.dart';

class ImageUtil {
  /// 保存图片到相册
  static Future<bool> saveImage(String imageUrl) async {
    try {
      if (imageUrl.isEmpty) throw '保存失败，图片不存在！';

      /// 权限检测
      PermissionStatus storageStatus = await Permission.storage.status;
      if (storageStatus != PermissionStatus.granted) {
        storageStatus = await Permission.storage.request();
        if (storageStatus != PermissionStatus.granted) {
          throw '无法存储图片，请先授权！';
        }
      }

      /// 保存的图片数据
      Uint8List imageBytes;

      /// 保存网络图片
      CachedNetworkImage image = CachedNetworkImage(imageUrl: imageUrl);
      print(image);
      BaseCacheManager manager = image.cacheManager ?? DefaultCacheManager();
      Map<String, String> headers = image.httpHeaders ?? {};
      File file = await manager.getSingleFile(
        image.imageUrl,
        headers: headers,
      );
      imageBytes = await file.readAsBytes();

      /// 保存图片
      final result = Map<String, dynamic>.from(
          await ImageGallerySaver.saveImage(imageBytes));
      if (!result.putIfAbsent('isSuccess', () => false)) return true;
      throw result;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
