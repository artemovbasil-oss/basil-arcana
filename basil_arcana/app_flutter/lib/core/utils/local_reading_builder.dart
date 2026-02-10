import '../../data/models/ai_result_model.dart';
import '../../data/models/drawn_card_model.dart';
import '../../data/models/spread_model.dart';
import '../../data/models/app_enums.dart';

class LocalReadingBuilder {
  const LocalReadingBuilder();

  AiResultModel build({
    required String question,
    required SpreadModel spread,
    required SpreadType spreadType,
    required List<DrawnCardModel> drawnCards,
  }) {
    final sections = <AiSectionModel>[];
    for (final drawn in drawnCards) {
      sections.add(
        AiSectionModel(
          positionId: drawn.positionId,
          title: drawn.positionTitle,
          text: _sectionText(drawn),
        ),
      );
    }

    final tldr = spreadType == SpreadType.one
        ? _singleCardSummary(question: question, cards: drawnCards)
        : _multiCardSummary(question: question, cards: drawnCards);

    final why = _buildWhy(spread, drawnCards);
    final action = _buildAction(drawnCards);
    final fullText = [
      tldr,
      ...sections.map((section) => section.text),
      why,
      action,
    ].where((line) => line.trim().isNotEmpty).join('\n\n');

    return AiResultModel(
      tldr: tldr,
      sections: sections,
      why: why,
      action: action,
      fullText: fullText,
      detailsText: '',
      requestId: null,
    );
  }

  String _singleCardSummary({
    required String question,
    required List<DrawnCardModel> cards,
  }) {
    final card = cards.isNotEmpty ? cards.first : null;
    final focus = question.trim().isEmpty ? 'your current energy' : question;
    if (card == null) {
      return 'The cards point to steady progress around $focus.';
    }
    final meaning = _bestMeaning(card);
    return '${card.cardName} highlights $focus. $meaning';
  }

  String _multiCardSummary({
    required String question,
    required List<DrawnCardModel> cards,
  }) {
    final focus = question.trim().isEmpty ? 'your path right now' : question;
    if (cards.length < 3) {
      final names = cards.map((card) => card.cardName).join(', ');
      return 'This spread about $focus emphasizes $names.';
    }
    if (cards.length >= 5) {
      final names = cards.take(5).map((card) => card.cardName).join(', ');
      return 'Your five-card reading around $focus highlights $names, revealing layered influences and a practical direction.';
    }
    return 'Your three-card spread around $focus shows a movement from '
        '${cards[0].cardName} to ${cards[1].cardName}, leading into ${cards[2].cardName}.';
  }

  String _sectionText(DrawnCardModel drawn) {
    final base = _bestMeaning(drawn);
    final advice = _bestAdvice(drawn);
    if (advice.isEmpty) {
      return '${drawn.positionTitle}: $base';
    }
    return '${drawn.positionTitle}: $base Guidance: $advice';
  }

  String _buildWhy(SpreadModel spread, List<DrawnCardModel> cards) {
    final titles = spread.positions
        .map((position) => position.title)
        .where((title) => title.trim().isNotEmpty)
        .join(', ');
    final names = cards.map((card) => card.cardName).join(', ');
    return 'This interpretation blends the spread positions ($titles) with the cards drawn: $names.';
  }

  String _buildAction(List<DrawnCardModel> cards) {
    final suggestion = cards
        .map(_bestAdvice)
        .where((text) => text.trim().isNotEmpty)
        .take(2)
        .join(' ');
    if (suggestion.isNotEmpty) {
      return suggestion;
    }
    return 'Take one grounded step today, stay observant, and revisit this reading in a few days.';
  }

  String _bestMeaning(DrawnCardModel drawn) {
    final general = drawn.meaning.general.trim();
    if (general.isNotEmpty) {
      return general;
    }
    final light = drawn.meaning.light.trim();
    if (light.isNotEmpty) {
      return light;
    }
    if (drawn.keywords.isNotEmpty) {
      return '${drawn.cardName} reflects ${drawn.keywords.take(3).join(', ')}.';
    }
    return _fallbackByCardName(drawn.cardName);
  }

  String _bestAdvice(DrawnCardModel drawn) {
    final advice = drawn.meaning.advice.trim();
    if (advice.isNotEmpty) {
      return advice;
    }
    final shadow = drawn.meaning.shadow.trim();
    if (shadow.isNotEmpty) {
      return 'Watch for $shadow.';
    }
    return '';
  }

  String _fallbackByCardName(String cardName) {
    const fallbackMap = <String, String>{
      'The Fool':
          'a fresh start, trust in your next step, and openness to change',
      'The Magician': 'using your skills intentionally and acting with clarity',
      'The High Priestess': 'listening to intuition before making a final move',
      'The Empress': 'growth through care, creativity, and patience',
      'The Emperor': 'structure, boundaries, and committed leadership',
      'The Lovers': 'important choices aligned with your values',
      'The Hermit': 'reflection, inner guidance, and thoughtful pacing',
      'The Star': 'healing, hope, and steady renewal',
    };
    final mapped = fallbackMap[cardName];
    if (mapped != null) {
      return '$cardName suggests $mapped.';
    }
    return '$cardName points to a meaningful shift; stay balanced, observe patterns, and choose the next practical step.';
  }
}
