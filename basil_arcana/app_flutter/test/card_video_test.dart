import 'package:flutter_test/flutter_test.dart';

import 'package:basil_arcana/data/models/card_video.dart';

void main() {
  test('resolveCardVideoAsset honors manifest set', () {
    const assets = {
      'assets/cards/video/fool.mp4',
      'assets/cards/video/wands_king.mp4',
    };

    expect(
      resolveCardVideoAsset('major_00_fool', availableAssets: assets),
      'assets/cards/video/fool.mp4',
    );
    expect(
      resolveCardVideoAsset('wands_01_king', availableAssets: assets),
      'assets/cards/video/wands_king.mp4',
    );
    expect(
      resolveCardVideoAsset('cups_00_knight', availableAssets: assets),
      isNull,
    );
  });

  test('normalizeVideoFileName enforces lowercase mp4', () {
    expect(normalizeVideoFileName('Wheel Of Fortune'), 'wheel_of_fortune.mp4');
    expect(normalizeVideoFileName('fool.MP4'), 'fool.mp4');
  });
}
