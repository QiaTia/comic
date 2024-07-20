import 'package:flutter/material.dart';

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
        title: const Text('Setting'),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ),
            child: Text('R18 Comic',
                style: Theme.of(context).textTheme.titleLarge),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                  padding: EdgeInsets.symmetric(
                horizontal: 4,
              )),
              Text('所有内容均来源网络')
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
