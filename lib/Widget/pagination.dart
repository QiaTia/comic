import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
                      .showSnackBar(const SnackBar(content: Text('已经是第一页了!')));
                  return;
                }
                /** 上一页 */
                widget.onChange!(widget.current - 1);
              },
              child: const Text('上一页'),
            ),
            const Padding(padding: EdgeInsets.all(8)),
            SizedBox(
              width: 58,
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
                  hintText: '${widget.current} / ${widget.total}',
                ),
                onSubmitted: (value) {
                  if (value.isEmpty) return;
                  var targetPage = int.parse(value);
                  if (targetPage > widget.total) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('只有${widget.total}页!')));
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
              child: const Text("下一页"),
              onPressed: () {
                if (widget.current >= widget.total) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('已经是最后一页了!')));
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
