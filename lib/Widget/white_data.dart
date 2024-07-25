import 'package:flutter/material.dart';
import 'package:get/get.dart';

class WhiteData extends StatelessWidget {
  final Color color = Color(0xFFAAAAAA);
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(color: color, size: 150, Icons.layers_clear_outlined),
      const Padding(padding: EdgeInsets.symmetric(vertical: 8)),
      Text("404".tr, style: TextStyle(fontSize: 18, color: color))
    ]));
  }
}
