import 'dart:typed_data';

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
