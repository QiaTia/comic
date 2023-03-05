import 'package:flutter/material.dart';

class FadeRoute extends PageRouteBuilder {
  final Widget page;
  FadeRoute({required this.page})
      : super(
            pageBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
            ) =>
                page,
            transitionsBuilder: (
              BuildContext context,
              Animation<double> animation,
              Animation<double> secondaryAnimation,
              Widget child,
            ) {
              // const begin = Offset(0.5, 0.5);
              // const end = Offset.zero;

              // final tween = Tween(begin: begin, end: end);
              final curvedAnimation = CurvedAnimation(
                parent: animation,
                curve: Curves.fastOutSlowIn,
              );
              return ScaleTransition(
                scale: Tween(begin: 0.0, end: 1.0).animate(curvedAnimation),
                child: child,
              );
            });
}
