import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:dogquest/constants.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/quiz_engine.dart';
import 'package:dogquest/widgets/network_dog_image.dart';

/// Main question content area: image, options, lifelines, clue, compare, fun fact.
class QuizQuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final bool answered;
  final int? selectedOption;
  final Set<int> eliminatedOptions;
  final int streakCount;
  final int lastXpAwarded;
  final bool showXpToast;
  final int hintsRemaining;
  final int fiftyfiftyRemaining;
  final bool isLastQuestion;
  final AnimationController silhouetteRevealController;
  final QuizEngine engine;
  final VoidCallback onNext;
  final ValueChanged<int> onSelectAnswer;
  final VoidCallback onUseHint;
  final VoidCallback onUseFiftyFifty;

  const QuizQuestionCard({
    super.key,
    required this.question,
    required this.answered,
    required this.selectedOption,
    required this.eliminatedOptions,
    required this.streakCount,
    required this.lastXpAwarded,
    required this.showXpToast,
    required this.hintsRemaining,
    required this.fiftyfiftyRemaining,
    required this.isLastQuestion,
    required this.silhouetteRevealController,
    required this.engine,
    required this.onNext,
    required this.onSelectAnswer,
    required this.onUseHint,
    required this.onUseFiftyFifty,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;
    final isSilhouette = q.type == QuizType.silhouetteRound;
    final isPhotoGrid =
        q.type == QuizType.photoFromName || q.type == QuizType.oddOneOut;
    final isCompare = q.type == QuizType.compareBreeds;
    final isClue = q.type == QuizType.breedFromClue;
    final showImage = !isPhotoGrid &&
        !isCompare &&
        !isClue &&
        q.type != QuizType.photoFromName;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        children: [
          // Streak badge — imported from quiz_streak_bonus.dart but inlined
          // to keep the scroll content as one widget tree
          if (streakCount >= 3)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: Colors.orange.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('\u{1F525}', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 4),
                  Text(
                    '$streakCount streak!',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ).animate().scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                  duration: 400.ms,
                ),

          // Question type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: q.type.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  q.type.icon,
                  size: 12,
                  color: q.type.color.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  q.type.label,
                  style: TextStyle(
                    color: q.type.color.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Question prompt
          Text(
            q.type.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 16),

          // Image card
          if (showImage) _buildImageCard(q, isSilhouette),

          // Breed name (for photoFromName)
          if (q.type == QuizType.photoFromName)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                q.correctDog.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: accent,
                ),
              ),
            ),
          if (q.type == QuizType.oddOneOut)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Find the breed that doesn\'t belong!',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Clue text (for breedFromClue)
          if (isClue && q.clueText != null) _buildClueCard(q.clueText!),

          // Compare breeds (side by side photos)
          if (isCompare) _buildCompareCard(q),

          // Lifelines
          if (!answered)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLifeline(
                    Icons.lightbulb_outline,
                    'Hint',
                    hintsRemaining,
                    onUseHint,
                  ),
                  const SizedBox(width: 10),
                  _buildLifeline(
                    Icons.filter_2,
                    '50/50',
                    fiftyfiftyRemaining,
                    onUseFiftyFifty,
                  ),
                ],
              ),
            ),

          // XP toast
          if (showXpToast)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
              ),
              child: Text(
                '+$lastXpAwarded XP${streakCount >= 3 ? ' \u{1F525}' : ''}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
                .animate()
                .fadeIn()
                .slideY(begin: 0.3, duration: 300.ms)
                .then()
                .fadeOut(delay: 1000.ms),

          // Options
          if (isPhotoGrid)
            _buildPhotoOptions(q)
          else if (!isCompare)
            ...List.generate(q.options.length, (i) => _buildTextOption(q, i)),

          // Post-answer
          if (answered) ...[
            // Reveal breed photo for breedFromClue after answering
            if (isClue) ...[
              const SizedBox(height: 12),
              _buildImageCard(q, false),
            ],
            const SizedBox(height: 14),
            _buildFunFact(q),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: bgDeep,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                child: Text(isLastQuestion ? 'See Results' : 'Continue'),
              ),
            ).animate().fadeIn(delay: 200.ms),
          ],
        ],
      ),
    );
  }

  // ─── Image Card ───────────────────────────────────────────────────────────

  Widget _buildImageCard(QuizQuestion q, bool isSilhouette) {
    final showName = q.type == QuizType.sizeFromPhoto ||
        q.type == QuizType.lifespanGuess ||
        q.type == QuizType.traitMatch ||
        q.type == QuizType.groupFromBreed ||
        q.type == QuizType.exerciseFromPhoto ||
        q.type == QuizType.weightGuess ||
        q.type == QuizType.originFromBreed;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            isSilhouette
                ? AnimatedBuilder(
                    animation: silhouetteRevealController,
                    builder: (_, child) {
                      final revealColor = Color.lerp(
                        const Color(0xFF4A4A6E),
                        Colors.white,
                        answered ? silhouetteRevealController.value : 0.0,
                      )!;
                      return ColorFiltered(
                        colorFilter:
                            ColorFilter.mode(revealColor, BlendMode.modulate),
                        child: child,
                      );
                    },
                    child: NetworkDogImage(
                      url: q.correctDog.imageUrl,
                      height: 220,
                    ),
                  )
                : NetworkDogImage(
                    url: q.correctDog.imageUrl,
                    height: showName ? 180 : 220,
                  ),
            // Bottom gradient with name
            if (showName)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 30, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                  child: Text(
                    q.correctDog.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  // ─── Photo Grid ───────────────────────────────────────────────────────────

  Widget _buildPhotoOptions(QuizQuestion q) {
    final dogs = q.photoDogs ?? [];
    if (dogs.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.85,
      children: List.generate(dogs.length, (i) {
        if (eliminatedOptions.contains(i)) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
            ),
          );
        }
        final isCorrect = i == q.correctIndex;
        final isSelected = selectedOption == i;

        Color borderColor = Colors.white.withValues(alpha: 0.06);
        double borderWidth = 1.5;
        if (answered && isCorrect) {
          borderColor = Colors.green;
          borderWidth = 3;
        } else if (answered && isSelected) {
          borderColor = Colors.red;
          borderWidth = 3;
        }

        return Semantics(
          button: true,
          label: q.type == QuizType.photoFromName && !answered
              ? 'Photo option ${i + 1}'
              : 'Photo of ${dogs[i].name}',
          child: GestureDetector(
            onTap: answered ? null : () => onSelectAnswer(i),
            child: AnimatedContainer(
              duration: 300.ms,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: answered && isCorrect
                    ? [
                        BoxShadow(
                          color: Colors.green.withValues(alpha: 0.2),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkDogImage(url: dogs[i].imageUrl, height: 160),
                    // Name at bottom
                    if (q.type != QuizType.photoFromName || answered)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 8,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.85),
                              ],
                            ),
                          ),
                          child: Text(
                            dogs[i].name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    // Result icon
                    if (answered && (isCorrect || isSelected))
                      Container(
                        color: (isCorrect ? Colors.green : Colors.red)
                            .withValues(alpha: 0.3),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.4),
                            ),
                            child: Icon(
                              isCorrect
                                  ? Icons.check_rounded
                                  : Icons.close_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─── Text Options ─────────────────────────────────────────────────────────

  Widget _buildTextOption(QuizQuestion q, int index) {
    if (eliminatedOptions.contains(index)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }

    final isCorrect = index == q.correctIndex;
    final isSelected = selectedOption == index;

    Color bg = bgCard;
    Color border = Colors.white.withValues(alpha: 0.06);
    Color textColor = Colors.white;
    IconData? icon;
    Color? iconBg;

    if (answered) {
      if (isCorrect) {
        bg = const Color(0xFF1A3A2A);
        border = Colors.green;
        textColor = Colors.green.shade200;
        icon = Icons.check_rounded;
        iconBg = Colors.green.withValues(alpha: 0.2);
      } else if (isSelected) {
        bg = const Color(0xFF3A1A1A);
        border = Colors.red;
        textColor = Colors.red.shade200;
        icon = Icons.close_rounded;
        iconBg = Colors.red.withValues(alpha: 0.2);
      }
    }

    final text = q.options[index];
    final displayText = q.type == QuizType.sizeFromPhoto
        ? '${text[0].toUpperCase()}${text.substring(1)}'
        : text;
    final letter = String.fromCharCode(65 + index);

    final semanticState = answered
        ? (isCorrect ? ', correct answer' : (isSelected ? ', incorrect' : ''))
        : '';

    Widget tile = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: 'Option ${index + 1}: $displayText$semanticState',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: answered ? null : () => onSelectAnswer(index),
            borderRadius: BorderRadius.circular(16),
            splashColor: accent.withValues(alpha: 0.08),
            child: AnimatedContainer(
              duration: 250.ms,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: border,
                  width: answered && (isCorrect || isSelected) ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: iconBg ?? Colors.white.withValues(alpha: 0.04),
                    ),
                    child: Center(
                      child: icon != null
                          ? Icon(
                              icon,
                              size: 18,
                              color: isCorrect ? Colors.green : Colors.red,
                            )
                          : Text(
                              letter,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.3),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayText,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (answered && isCorrect) {
      tile = tile
          .animate()
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.02, 1.02),
            duration: 150.ms,
          )
          .then()
          .scale(end: const Offset(1.0, 1.0), duration: 150.ms);
    } else if (answered && isSelected && !isCorrect) {
      tile = tile
          .animate()
          .shake(hz: 5, offset: const Offset(4, 0), duration: 350.ms);
    }

    return tile;
  }

  Widget _buildLifeline(
    IconData icon,
    String label,
    int count,
    VoidCallback action,
  ) {
    final enabled = count > 0;
    return Semantics(
      button: true,
      label: '$label, $count remaining',
      child: GestureDetector(
        onTap: enabled ? action : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.08)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color:
                  enabled ? accent.withValues(alpha: 0.15) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: enabled ? accent : Colors.white24),
              const SizedBox(width: 5),
              Text(
                '$label ($count)',
                style: TextStyle(
                  color:
                      enabled ? accent.withValues(alpha: 0.7) : Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Fun Fact ─────────────────────────────────────────────────────────────

  Widget _buildFunFact(QuizQuestion q) {
    final fact = engine.getFunFact(q);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome,
            color: accent.withValues(alpha: 0.5),
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fact,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  // ─── Clue Card (breedFromClue) ──────────────────────────────────────────

  Widget _buildClueCard(String clue) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.auto_stories,
            color: accent.withValues(alpha: 0.6),
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            '\u{201C}$clue\u{201D}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.95, 0.95),
          duration: 400.ms,
          curve: Curves.easeOut,
        );
  }

  // ─── Compare Card (compareBreeds) ───────────────────────────────────────

  Widget _buildCompareCard(QuizQuestion q) {
    final dogs = q.photoDogs ?? [];
    if (dogs.length < 2) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: _buildComparisonDog(dogs[0], 0, q)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.purple.withValues(alpha: 0.15),
                    border:
                        Border.all(color: Colors.purple.withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    'VS',
                    style: TextStyle(
                      color: Colors.purple,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildComparisonDog(dogs[1], 1, q)),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildComparisonDog(Dog dog, int index, QuizQuestion q) {
    final isCorrect = answered && dog.name == q.correctDog.name;
    final isWrong =
        answered && selectedOption == index && dog.name != q.correctDog.name;

    Color borderColor = Colors.white.withValues(alpha: 0.08);
    if (isCorrect) borderColor = Colors.green;
    if (isWrong) borderColor = Colors.red;

    return GestureDetector(
      onTap: answered ? null : () => onSelectAnswer(index),
      child: AnimatedContainer(
        duration: 300.ms,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: answered ? 2.5 : 1.5),
          boxShadow: isCorrect
              ? [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.2),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(
            children: [
              NetworkDogImage(url: dog.imageUrl, height: 140),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                color: bgCard,
                child: Column(
                  children: [
                    Text(
                      dog.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dog.sizeCategory,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                    if (answered)
                      Text(
                        dog.lifespan.isEmpty ? '~12 years' : dog.lifespan,
                        style: TextStyle(
                          color: isCorrect
                              ? Colors.green.shade300
                              : Colors.white.withValues(alpha: 0.4),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              if (answered && (isCorrect || isWrong))
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  color: (isCorrect ? Colors.green : Colors.red)
                      .withValues(alpha: 0.15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isCorrect ? Icons.check_rounded : Icons.close_rounded,
                        size: 14,
                        color: isCorrect ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCorrect ? 'Longer!' : 'Shorter',
                        style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
