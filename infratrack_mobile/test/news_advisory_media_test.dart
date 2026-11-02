import 'package:flutter_test/flutter_test.dart';
import 'package:infatrack/main.dart';

void main() {
  test('video advisory media is identified by kind or file extension', () {
    expect(isVideoAdvisoryMedia('video', 'https://example.test/ad'), isTrue);
    expect(isVideoAdvisoryMedia(' Video ', 'https://example.test/ad'), isTrue);
    expect(
      isVideoAdvisoryMedia(null, 'https://example.test/ad.mp4?download=1'),
      isTrue,
    );
    expect(
      isVideoAdvisoryMedia('photo', 'https://example.test/ad.jpg'),
      isFalse,
    );
  });

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

  test(
    'news carousel uses only featured image advisories and caps at five',
    () {
      final advisories = [
        {
          'id': 1,
          'featured_in_news': 0,
          'media_kind': 'photo',
          'media_url': 'https://example.test/unfeatured.jpg',
        },
        {
          'id': 2,
          'featured_in_news': 1,
          'media_kind': 'photo',
          'media_url': 'https://example.test/2.jpg',
        },
        {
          'id': 3,
          'featured_in_news': true,
          'media_kind': 'gif',
          'media_url': 'https://example.test/3.gif',
        },
        {
          'id': 4,
          'featured_in_news': true,
          'media_kind': 'video',
          'media_url': 'https://example.test/4.mp4',
        },
        for (var id = 5; id <= 8; id++)
          {
            'id': id,
            'featured_in_news': true,
            'media_kind': 'photo',
            'media_url': 'https://example.test/$id.jpg',
          },
      ];

      final featured = featuredNewsCarouselAdvisories(advisories);

      expect(featured.map((advisory) => advisory['id']), [2, 3, 5, 6, 7]);
    },
  );
}
