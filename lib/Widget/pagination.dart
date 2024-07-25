import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

import 'package:get/get.dart';

typedef ValueChanged = void Function(int page);

class Pagination extends StatefulWidget {
  Pagination({super.key, required this.current, this.total = 1, this.onChange});
  int current;
  int total;
  ValueChanged? onChange;
  @override
  State<StatefulWidget> createState() => _Pagination();
}

class _Pagination extends State<Pagination> {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      widget.current == 1 ? const Color(0xFFF9F9F9) : null),
              onPressed: () {
                if (widget.current <= 1) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('tipStart'.tr)));
                  return;
                }
                /** 上一页 */
                widget.onChange!(widget.current - 1);
              },
              child: Text('prePage'.tr),
            ),
            const Padding(padding: EdgeInsets.all(8)),
            SizedBox(
              width: 98,
              child: TextField(
                textAlignVertical: TextAlignVertical.center,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[0-9]')) //设置只允许输入数字
                ],
                textInputAction: TextInputAction.go,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText:
                      '${widget.current} / ${max(widget.total, widget.current)}',
                ),
                onSubmitted: (value) {
                  if (value.isEmpty) return;
                  var targetPage = int.parse(value);
                  if (targetPage > widget.total) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('tipEmpty'.tr)));
                    return;
                  }
                  widget.onChange!(targetPage);
                },
              ),
            ),
            const Padding(padding: EdgeInsets.all(8)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.current == widget.total
                      ? const Color(0xFFF9F9F9)
                      : null),
              child: Text("nextPage".tr),
              onPressed: () {
                if (widget.current >= widget.total) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('tipEnd'.tr)));
                  return;
                }
                /** 下一页 */
                widget.onChange!(widget.current + 1);
              },
            )
          ],
        ));
  }
}
