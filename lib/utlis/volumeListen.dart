import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class VolumeListen extends StatefulWidget {
  /// 监听安卓手机音量键
  ///
  /// [child] 监听的组件
  ///
  /// [onKeyEvent] 音量键事件回调
  const VolumeListen({super.key, required this.child, this.onKeyEvent});

  final Widget child;
  final Function(LogicalKeyboardKey logicalKey)? onKeyEvent;
  @override
  _VolumelistenState createState() => _VolumelistenState();
}

class _VolumelistenState extends State<VolumeListen> {
  // 仅支持安卓
  // 监听后会拦截安卓手机音量键
  // event可能为DOWN/UP
  var _volumeListenCount = 0;

  void _onVolumeEvent(dynamic args) {
    if (widget.onKeyEvent == null || args is! String) return;
    if (args == 'UP') {
      widget.onKeyEvent!(LogicalKeyboardKey.audioVolumeUp);
    } else if (args == 'DOWN') {
      widget.onKeyEvent!(LogicalKeyboardKey.audioVolumeDown);
    }
  }

  EventChannel volumeButtonChannel = const EventChannel("volume_button");
  StreamSubscription? volumeS;
  // 添加监听
  void addVolumeListen() {
    _volumeListenCount++;
    if (_volumeListenCount == 1) {
      volumeS =
          volumeButtonChannel.receiveBroadcastStream().listen(_onVolumeEvent);
    }
  }

  // 移除监听
  void delVolumeListen() {
    _volumeListenCount--;
    if (_volumeListenCount == 0) {
      volumeS?.cancel();
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      delVolumeListen();
    }
    super.dispose();
  }

  @override
  void initState() {
    if (Platform.isAndroid) {
      addVolumeListen();
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (widget.onKeyEvent != null) widget.onKeyEvent!(event.logicalKey);
      },
      child: widget.child,
    );
  }
}
