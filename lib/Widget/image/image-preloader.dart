import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pool/pool.dart';
import 'package:cached_network_image/cached_network_image.dart';

// 图片预加载状态枚举
enum ImagePreloadStatus {
  notStarted, // 未开始
  loading, // 加载中
  success, // 加载成功
  failed, // 加载失败
}

// 图片预加载结果数据类
class ImagePreloadResult {
  final String imageUrl; // 图片URL
  final ImagePreloadStatus status; // 当前加载状态
  final String? errorMessage; // 错误信息（失败时使用）
  final double progress; // 加载进度（0.0-1.0）

  ImagePreloadResult({
    required this.imageUrl,
    required this.status,
    this.errorMessage,
    this.progress = 0.0,
  });

  // 复制并更新属性的便捷方法
  ImagePreloadResult copyWith({
    String? imageUrl,
    ImagePreloadStatus? status,
    String? errorMessage,
    double? progress,
  }) {
    return ImagePreloadResult(
      imageUrl: imageUrl ?? this.imageUrl,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

// 图片预加载管理器（单例模式）
class ImagePreloader {
  // 单例实例
  static final ImagePreloader _instance = ImagePreloader._internal();

  factory ImagePreloader() => _instance;

  ImagePreloader._internal();

  // 存储图片加载状态的映射表
  final Map<String, ImagePreloadResult> _imageStatusMap = {};

  // 用于广播加载状态变化的StreamController
  final _imageStatusController =
      StreamController<ImagePreloadResult>.broadcast();

  // 暴露给外部的状态流
  Stream<ImagePreloadResult> get imageStatusStream =>
      _imageStatusController.stream;

  // 获取不可修改的已加载图片状态映射
  Map<String, ImagePreloadResult> get preloadedImages =>
      Map.unmodifiable(_imageStatusMap);

  // 核心方法：预加载单个图片
  Future<ImagePreloadResult> preloadImage(
    String imageUrl,
    BuildContext context, {
    ImageErrorListener? onError,
  }) async {
    // 如果图片已成功加载，直接返回缓存结果
    if (_imageStatusMap[imageUrl]?.status == ImagePreloadStatus.success) {
      return _imageStatusMap[imageUrl]!;
    }

    // 初始化加载状态
    final result = ImagePreloadResult(
      imageUrl: imageUrl,
      status: ImagePreloadStatus.loading,
    );
    _imageStatusMap[imageUrl] = result;
    _imageStatusController.add(result);

    try {
      // 非SVG图片处理
      // 根据URL类型创建对应的ImageProvider
      ImageProvider imageProvider;
      if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
        imageProvider = CachedNetworkImageProvider(imageUrl);
      } else {
        imageProvider = AssetImage(imageUrl);
      }

      final completer = Completer<ImagePreloadResult>();

      // 使用Flutter原生方法预加载图片
      await precacheImage(
        imageProvider,
        context,
        onError: (exception, stackTrace) {
          // 错误处理
          final errorResult = result.copyWith(
            status: ImagePreloadStatus.failed,
            errorMessage: exception.toString(),
          );
          _imageStatusMap[imageUrl] = errorResult;
          _imageStatusController.add(errorResult);

          // 调用自定义错误回调
          if (onError != null) {
            onError(exception, stackTrace);
          }

          // 完成Completer
          if (!completer.isCompleted) {
            completer.complete(errorResult);
          }
        },
      );

      // 成功处理
      if (!completer.isCompleted) {
        final successResult = result.copyWith(
          status: ImagePreloadStatus.success,
          progress: 1.0,
        );
        _imageStatusMap[imageUrl] = successResult;
        _imageStatusController.add(successResult);
        completer.complete(successResult);
      }

      return await completer.future;
    } catch (e) {
      // 异常处理
      final errorResult = result.copyWith(
        status: ImagePreloadStatus.failed,
        errorMessage: e.toString(),
      );
      _imageStatusMap[imageUrl] = errorResult;
      _imageStatusController.add(errorResult);
      return errorResult;
    }
  }

  // 批量预加载方法
  Future<List<ImagePreloadResult>> preloadImages(
    List<String> imageUrls,
    BuildContext context, {
    ImageErrorListener? onError,
    int concurrency = 5,
  }) async {
    final pool = Pool(concurrency);
    final results = <ImagePreloadResult>[];

    await Future.wait(
      imageUrls.map(
        (url) => pool.withResource(() async {
          final result = await preloadImage(url, context, onError: onError);
          results.add(result);
          return result;
        }),
      ),
    );

    return results;
  }
  // Future<List<ImagePreloadResult>> preloadImages(
  //     List<String> imageUrls,
  //     BuildContext context, {
  //       ImageErrorListener? onError,
  //     }) async {
  //   final futures = imageUrls.map(
  //         (url) => preloadImage(url, context, onError: onError),
  //   );
  //   return await Future.wait(futures);
  // }
  // Future<List<ImagePreloadResult>> preloadImages(
  //   List<String> imageUrls,
  //   BuildContext context, {
  //   ImageErrorListener? onError,
  //   int concurrency = 15,
  // }) async {
  //   final results = <ImagePreloadResult>[];
  //   final queue = Queue.from(imageUrls);
  //   final activeTasks = <Future<void>>[];
  //   final completed = Completer<void>();
  //
  //   void scheduleNext() {
  //     while (activeTasks.length < concurrency && queue.isNotEmpty) {
  //       final url = queue.removeFirst();
  //       late final Future<void> task;
  //       task = preloadImage(
  //         url,
  //         context,
  //         onError: onError,
  //       ).then((result) => results.add(result)).whenComplete(() {
  //         activeTasks.remove(task);
  //         scheduleNext();
  //       });
  //       activeTasks.add(task);
  //     }
  //
  //     if (activeTasks.isEmpty && queue.isEmpty) {
  //       completed.complete();
  //     }
  //   }
  //
  //   scheduleNext();
  //   await completed.future;
  //   return results;
  // }

  // 检查图片是否已预加载
  bool isImagePreloaded(String imageUrl) {
    return _imageStatusMap[imageUrl]?.status == ImagePreloadStatus.success;
  }

  // 获取指定图片的状态
  ImagePreloadResult? getImageStatus(String imageUrl) {
    return _imageStatusMap[imageUrl];
  }

  // 清除单个图片缓存
  void clearImage(String imageUrl) {
    _imageStatusMap.remove(imageUrl);
  }

  // 清除所有图片缓存
  void clearAllImages() {
    _imageStatusMap.clear();
  }

  // 释放资源
  void dispose() {
    _imageStatusController.close();
  }
}
