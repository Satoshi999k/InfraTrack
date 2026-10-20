import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/main.dart';

void main() {
  test('rotating advisory media accepts images and GIFs only', () {
    expect(
      isRotatingAdvisoryMedia('gif', 'https://example.test/ad.gif'),
      isTrue,
    );
    expect(
      isRotatingAdvisoryMedia('photo', 'https://example.test/ad.jpg'),
      isTrue,
    );
    expect(
      isRotatingAdvisoryMedia('image', 'https://example.test/ad.webp'),
      isTrue,
    );
    expect(
      isRotatingAdvisoryMedia('video', 'https://example.test/ad.mp4'),
      isFalse,
    );
    expect(
      isRotatingAdvisoryMedia('photo', 'https://example.test/ad.mp4'),
      isFalse,
    );
    expect(
      isRotatingAdvisoryMedia(null, 'https://example.test/ad.mov'),
      isFalse,
    );
    expect(
      isRotatingAdvisoryMedia(null, 'https://example.test/document.pdf'),
      isFalse,
    );
    expect(isRotatingAdvisoryMedia('gif', null), isFalse);
  });
}
