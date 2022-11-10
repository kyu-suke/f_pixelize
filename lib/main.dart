import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const <Widget>[
              Pixel(),
            ],
          ),
        ),
      ),
    );
  }
}

class Pixel extends StatefulWidget {
  const Pixel({super.key});

  @override
  State<Pixel> createState() => _PixelState();
}

class _PixelState extends State<Pixel> {
  final String _imagePath = "assets/sample.jpg";
  double _sliderBlockSize = 10;
  int _blockSize = 0;

  void _changeSlider(double e) => setState(() {
        _sliderBlockSize = e;
      });

  @override
  void initState() {
    super.initState();
    _blockSize = _sliderBlockSize.toInt();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 500,
                child: Image.asset(
                  _imagePath,
                ),
              ),
              Pixelize(
                imagePath: _imagePath,
                blockSize: _blockSize,
              ),
            ],
          ),
        ),
        Row(
          children: [
            Column(
              children: <Widget>[
                Text("block size: ${_sliderBlockSize.toInt()}"),
                SizedBox(
                  width: 500,
                  child: Slider(
                    label: '${_sliderBlockSize.toInt()}',
                    min: 1,
                    max: 100,
                    value: _sliderBlockSize,
                    divisions: 100,
                    onChanged: _changeSlider,
                  ),
                )
              ],
            ),
            ElevatedButton(
              onPressed: () async {
                setState(() {
                  _blockSize = _sliderBlockSize.toInt();
                });
              },
              child: const Text('convert'),
            ),
          ],
        ),
      ],
    );
  }
}

class BlockOffset {
  BlockOffset(this.start, this.end);

  Offset start;
  Offset end;

  Offset get leftTop => start;

  Offset get rightTop => Offset(end.dx, start.dy);

  Offset get leftBottom => Offset(start.dx, end.dy);

  Offset get rightBottom => end;
}

class Pixelize extends StatefulWidget {
  const Pixelize({
    super.key,
    required this.imagePath,
    required this.blockSize,
  });

  final String imagePath;
  final int blockSize;

  @override
  State<Pixelize> createState() => _PixelizeState();
}

class _PixelizeState extends State<Pixelize> {
  int _imageWidth = 0;
  int _imageHeight = 0;

  ByteData? _imageBytes;
  List<BlockOffset> _blocks = [];

  List<BlockOffset> getBlockList(double width, double height, int blockSize) {
    List<BlockOffset> blocks = [];
    for (double y = 1; y <= height; y += blockSize) {
      final double endY = y + blockSize > height ? height : y + blockSize;

      for (double x = 1; x <= width; x += blockSize) {
        final endX = x + blockSize > width ? width : x + blockSize;
        blocks.add(BlockOffset(Offset(x, y), Offset(endX, endY)));
      }
    }
    return blocks;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Image.asset(widget.imagePath)
        .image
        .resolve(const ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) async {
      final blockList = getBlockList(info.image.width.toDouble(),
          info.image.height.toDouble(), widget.blockSize);
      _blocks = blockList;
      _imageWidth = info.image.width;
      _imageHeight = info.image.height;
      _imageBytes = await info.image.toByteData(format: ui.ImageByteFormat.png);
    }));

    return Container(
      child: _imageBytes == null
          ? null
          : CustomPaint(
              size: Size(_imageWidth.toDouble(), _imageHeight.toDouble()),
              painter:
                  _SamplePainter(blocks: _blocks, imageBytes: _imageBytes!),
            ),
    );
  }
}

class _SamplePainter extends CustomPainter {
  _SamplePainter({required this.blocks, required imageBytes}) {
    _image = img.decodeImage(imageBytes.buffer.asUint8List())!;
  }

  final List<BlockOffset> blocks;
  late final img.Image _image;

  num _getColorDistance(Color color1, Color color2) {
    return pow(color2.red - color1.red, 2) +
        pow(color2.green - color1.green, 2) +
        pow(color2.blue - color1.blue, 2);
  }

  num _getColorDistanceAbs(Offset offset1, Offset offset2) {
    return _getColorDistance(
            _getColorAtOffset(offset1), _getColorAtOffset(offset2))
        .abs();
  }

  Color _getColorAtOffset(Offset offset) {
    return Color(_getHex(offset));
  }

  int _getHex(Offset offset) {
    return _abgrToArgb(
        _image.getPixelSafe(offset.dx.toInt(), offset.dy.toInt()));
  }

  int _abgrToArgb(int argbColor) {
    int r = (argbColor >> 16) & 0xFF;
    int b = argbColor & 0xFF;
    return (argbColor & 0xFF00FF00) | (b << 16) | r;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    for (var b in blocks) {
      List<Offset> uList = [];
      List<Offset> vList = [];
      Offset u = Offset.zero;
      Offset v = Offset.zero;

      if (_getColorDistanceAbs(b.leftTop, b.rightBottom) >
          _getColorDistanceAbs(b.rightTop, b.leftBottom)) {
        u = b.leftTop;
        v = b.rightBottom;
      } else {
        u = b.rightTop;
        v = b.leftBottom;
      }

      for (var y = b.start.dy; y <= b.end.dy; y++) {
        for (var x = b.start.dx; x <= b.end.dx; x++) {
          if (_getColorDistanceAbs(Offset(x, y), u) >
              _getColorDistanceAbs(Offset(x, y), v)) {
            vList.add(Offset(x, y));
          } else {
            uList.add(Offset(x, y));
          }
        }
      }

      final List<Offset> majoList = uList.length > vList.length ? uList : vList;

      final Map<String, int> sumColor =
          majoList.fold({"a": 0, "r": 0, "g": 0, "b": 0}, (p, e) {
        final color = _getColorAtOffset(e);
        return {
          "a": (p["a"] as int) + color.alpha,
          "r": (p["r"] as int) + color.red,
          "g": (p["g"] as int) + color.green,
          "b": (p["b"] as int) + color.blue
        };
      });

      paint.color = Color.fromARGB(
          (sumColor["a"] as int) ~/ majoList.length,
          (sumColor["r"] as int) ~/ majoList.length,
          (sumColor["g"] as int) ~/ majoList.length,
          (sumColor["b"] as int) ~/ majoList.length);

      canvas.drawRect(
          Rect.fromPoints(Offset(b.start.dx, b.start.dy),
              Offset(b.end.dx.toDouble(), b.end.dy)),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
