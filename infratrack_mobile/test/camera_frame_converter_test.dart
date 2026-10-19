import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/camera_frame_converter.dart';

CameraImage _cameraImage({
  required int format,
  required int width,
  required int height,
  required List<Map<String, Object>> planes,
}) =>
    // camera_platform_interface is intentionally kept out of direct app deps.
    // ignore: deprecated_member_use
    CameraImage.fromPlatformData({
      'format': format,
      'width': width,
      'height': height,
      'planes': planes
          .map(
            (plane) => {
              'bytes': plane['bytes'],
              'bytesPerRow': plane['bytesPerRow'],
              'bytesPerPixel': plane['bytesPerPixel'],
            },
          )
          .toList(),
    });

Map<String, Object> _plane(
  List<int> bytes, {
  required int bytesPerRow,
  required int bytesPerPixel,
}) => {
  'bytes': Uint8List.fromList(bytes),
  'bytesPerRow': bytesPerRow,
  'bytesPerPixel': bytesPerPixel,
};

void main() {
  final originalPlatform = debugDefaultTargetPlatformOverride;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = originalPlatform;
  });

  test('converts padded YUV420 planes to RGBA pixels', () {
    final image = _cameraImage(
      format: 35,
      width: 2,
      height: 2,
      planes: [
        _plane(
          [235, 235, 0, 0, 235, 235, 0, 0],
          bytesPerRow: 4,
          bytesPerPixel: 1,
        ),
        _plane([128, 0], bytesPerRow: 2, bytesPerPixel: 2),
        _plane([128, 0], bytesPerRow: 2, bytesPerPixel: 2),
      ],
    );

    final rgba = CameraFrameConverter.toRgba(image);

    expect(rgba, isNotNull);
    expect(rgba, everyElement(255));
  });

  test('converts an NV21 frame to RGBA pixels', () {
    final image = _cameraImage(
      format: 17,
      width: 2,
      height: 2,
      planes: [
        _plane(
          [235, 235, 235, 235, 128, 128],
          bytesPerRow: 2,
          bytesPerPixel: 1,
        ),
      ],
    );

    final rgba = CameraFrameConverter.toRgba(image);

    expect(rgba, isNotNull);
    expect(rgba, everyElement(255));
  });

  test('writes encoded PNG bytes for ML Kit file-path input', () async {
    final image = _cameraImage(
      format: 35,
      width: 2,
      height: 2,
      planes: [
        _plane([235, 235, 235, 235], bytesPerRow: 2, bytesPerPixel: 1),
        _plane([128], bytesPerRow: 1, bytesPerPixel: 1),
        _plane([128], bytesPerRow: 1, bytesPerPixel: 1),
      ],
    );
    final destination = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'infratrack_converter_test_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    try {
      final png = await CameraFrameConverter.writePng(image, destination);

      expect(png, destination);
      expect(await png!.exists(), isTrue);
      expect(await png.length(), greaterThan(8));
      expect(
        (await png.openRead(0, 8).fold<List<int>>([], (bytes, chunk) {
          bytes.addAll(chunk);
          return bytes;
        })),
        [137, 80, 78, 71, 13, 10, 26, 10],
      );
    } finally {
      if (await destination.exists()) await destination.delete();
    }
  });

  test('rotates the encoded PNG to the requested image orientation', () async {
    final image = _cameraImage(
      format: 35,
      width: 4,
      height: 2,
      planes: [
        _plane(
          [235, 235, 235, 235, 235, 235, 235, 235],
          bytesPerRow: 4,
          bytesPerPixel: 1,
        ),
        _plane([128, 128], bytesPerRow: 2, bytesPerPixel: 1),
        _plane([128, 128], bytesPerRow: 2, bytesPerPixel: 1),
      ],
    );
    final destination = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'infratrack_rotation_test_${DateTime.now().microsecondsSinceEpoch}.png',
    );

    try {
      await CameraFrameConverter.writePng(
        image,
        destination,
        rotationDegrees: 90,
      );
      final codec = await ui.instantiateImageCodec(
        await destination.readAsBytes(),
      );
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, 2);
        expect(frame.image.height, 4);
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    } finally {
      if (await destination.exists()) await destination.delete();
    }
  });

  test('rejects incomplete YUV420 buffers', () {
    final image = _cameraImage(
      format: 35,
      width: 2,
      height: 2,
      planes: [
        _plane([235], bytesPerRow: 2, bytesPerPixel: 1),
        _plane([128], bytesPerRow: 1, bytesPerPixel: 1),
        _plane([128], bytesPerRow: 1, bytesPerPixel: 1),
      ],
    );

    expect(CameraFrameConverter.toRgba(image), isNull);
  });
}
