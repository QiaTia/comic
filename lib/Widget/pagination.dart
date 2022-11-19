import 'package:flutter/material.dart';

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
