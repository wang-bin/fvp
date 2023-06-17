import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fvp/fvp.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _fvpPlugin = Fvp();
  int? _textureId;
  String? _mdkVersion;

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    int textureId = await _fvpPlugin.createTexture();
    int v = _fvpPlugin.getMdkVersion();
    _mdkVersion = '${(v >> 16) & 0xff}.${(v >> 8) & 0xff}.${v & 0xff}';

    print('textureId: $_textureId. mdk: $_mdkVersion');
    setState(() {
      _textureId = textureId;
    });
  }

  @override
  Widget build(BuildContext context) {
    print('build textureId: $_textureId');
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Flutter Video Player based on libmdk$_mdkVersion. textureId: $_textureId'),
        ),
        body: Center(
          child: AspectRatio(
            aspectRatio: 16.0/9.0,
            child: _textureId == null ? null : Texture(
                  textureId: _textureId!,
                  filterQuality: FilterQuality.high,
                ),
          )
        ),
      ),
    );
  }
}
