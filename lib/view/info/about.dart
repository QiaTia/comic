import 'package:flutter/material.dart';
import 'package:get/get.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPage();
}

class _AboutPage extends State<AboutPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('about'.tr),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child:
                Text('name'.tr, style: Theme.of(context).textTheme.titleLarge),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Padding(
                  padding: EdgeInsets.symmetric(
                horizontal: 4,
              )),
              Text('contentOrigin'.tr)
            ],
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.link_outlined),
              Padding(
                  padding: EdgeInsets.symmetric(
                horizontal: 4,
              )),
              Text('https://github.com/qiatia/comic')
            ],
          ),
        ],
      ),
    );
  }
}
