import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';

class CameraFrameConverter {
  const CameraFrameConverter._();

  static Uint8List? toRgba(CameraImage image) {
    if (image.width.isOdd || image.height.isOdd) return null;
    if (image.format.group == ImageFormatGroup.yuv420) {
      return _fromYuv420(image);
    }
    if (image.format.group == ImageFormatGroup.nv21) {
      return _fromNv21(image);
    }
    return null;
  }

  static Future<File?> writePng(
    CameraImage image,
    File destination, {
    int rotationDegrees = 0,
  }) async {
    final rgba = toRgba(image);
    if (rgba == null) return null;

    final normalizedRotation = ((rotationDegrees % 360) + 360) % 360;
    if (normalizedRotation != 0 &&
        normalizedRotation != 90 &&
        normalizedRotation != 180 &&
        normalizedRotation != 270) {
      return null;
    }
    final oriented = _rotateRgba(
      rgba,
      image.width,
      image.height,
      normalizedRotation,
    );
    final buffer = await ui.ImmutableBuffer.fromUint8List(oriented.$1);
    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: oriented.$2,
      height: oriented.$3,
      pixelFormat: ui.PixelFormat.rgba8888,
    );
    try {
      final codec = await descriptor.instantiateCodec();
      final frame = await codec.getNextFrame();
      try {
        final png = await frame.image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        if (png == null) {
          throw StateError('Could not encode camera frame as PNG.');
        }
        await destination.writeAsBytes(
          png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
          flush: true,
        );
        return destination;
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  static (Uint8List, int, int) _rotateRgba(
    Uint8List source,
    int width,
    int height,
    int rotation,
  ) {
    if (rotation == 0) return (source, width, height);

    final swapsDimensions = rotation == 90 || rotation == 270;
    final outputWidth = swapsDimensions ? height : width;
    final outputHeight = swapsDimensions ? width : height;
    final output = Uint8List(source.length);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final outputX = switch (rotation) {
          90 => height - 1 - y,
          180 => width - 1 - x,
          270 => y,
          _ => x,
        };
        final outputY = switch (rotation) {
          90 => x,
          180 => height - 1 - y,
          270 => width - 1 - x,
          _ => y,
        };
        final sourceOffset = (y * width + x) * 4;
        final outputOffset = (outputY * outputWidth + outputX) * 4;
        output.setRange(outputOffset, outputOffset + 4, source, sourceOffset);
      }
    }
    return (output, outputWidth, outputHeight);
  }

  static Uint8List? _fromYuv420(CameraImage image) {
    if (image.planes.length != 3) return null;

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final rgba = Uint8List(image.width * image.height * 4);

    for (var row = 0; row < image.height; row++) {
      final yRow = row * yPlane.bytesPerRow;
      if (yRow + image.width > yPlane.bytes.length) return null;
      for (var col = 0; col < image.width; col++) {
        final chromaRow = row ~/ 2;
        final chromaCol = col ~/ 2;
        final uIndex =
            chromaRow * uPlane.bytesPerRow +
            chromaCol * (uPlane.bytesPerPixel ?? 1);
        final vIndex =
            chromaRow * vPlane.bytesPerRow +
            chromaCol * (vPlane.bytesPerPixel ?? 1);
        if (uIndex >= uPlane.bytes.length || vIndex >= vPlane.bytes.length) {
          return null;
        }

        _writeRgba(
          rgba,
          (row * image.width + col) * 4,
          yPlane.bytes[yRow + col],
          uPlane.bytes[uIndex],
          vPlane.bytes[vIndex],
        );
      }
    }
    return rgba;
  }

  static Uint8List? _fromNv21(CameraImage image) {
    if (image.planes.length != 1) return null;

    final plane = image.planes.single;
    final rowStride = plane.bytesPerRow;
    if (rowStride < image.width) return null;

    final rgba = Uint8List(image.width * image.height * 4);
    final chromaStart = rowStride * image.height;
    for (var row = 0; row < image.height; row++) {
      final yRow = row * rowStride;
      final chromaRow = chromaStart + (row ~/ 2) * rowStride;
      for (var col = 0; col < image.width; col++) {
        final yIndex = yRow + col;
        final chromaIndex = chromaRow + (col & ~1);
        if (yIndex >= plane.bytes.length ||
            chromaIndex + 1 >= plane.bytes.length) {
          return null;
        }
        _writeRgba(
          rgba,
          (row * image.width + col) * 4,
          plane.bytes[yIndex],
          plane.bytes[chromaIndex + 1],
          plane.bytes[chromaIndex],
        );
      }
    }
    return rgba;
  }

  static void _writeRgba(Uint8List rgba, int pixel, int y, int u, int v) {
    final chromaU = u - 128;
    final chromaV = v - 128;
    final luma = y > 16 ? y - 16 : 0;
    rgba[pixel] = ((298 * luma + 409 * chromaV + 128) >> 8).clamp(0, 255);
    rgba[pixel + 1] = ((298 * luma - 100 * chromaU - 208 * chromaV + 128) >> 8)
        .clamp(0, 255);
    rgba[pixel + 2] = ((298 * luma + 516 * chromaU + 128) >> 8).clamp(0, 255);
    rgba[pixel + 3] = 255;
  }
}
