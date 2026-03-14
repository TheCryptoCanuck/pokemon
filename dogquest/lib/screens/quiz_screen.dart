import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../helpers/ui_helpers.dart';
import '../models/dog.dart';
import '../services/kennel_service.dart';
import '../services/dog_service.dart';
import '../services/player_service.dart';
import '../services/seasonal_event_service.dart';
import '../widgets/network_dog_image.dart';

/// A quiz question with one correct answer and three distractors.
class QuizQuestion {
  final Dog correctDog;
  final List<Dog> options; // 4 options, one is correct
  final QuizType type;
  bool hintUsed = false;

  QuizQuestion({
    required this.correctDog,
    required this.options,
    required this.type,
  });

  int get xpValue {
    return switch (type) {
      QuizType.nameFromPhoto => 15,
      QuizType.habitatFromName => 20,
      QuizType.scientificFromCommon => 30,
    };
  }

  String get difficultyLabel {
    return switch (type) {
      QuizType.nameFromPhoto => 'Easy',
      QuizType.habitatFromName => 'Medium',
      QuizType.scientificFromCommon => 'Hard',
    };
  }

  Color get difficultyColor {
    return switch (type) {
      QuizType.nameFromPhoto => Colors.green,
      QuizType.habitatFromName => Colors.orange,
      QuizType.scientificFromCommon => Colors.red,
    };
  }
}

enum QuizType { nameFromPhoto, habitatFromName, scientificFromCommon }

enum QuizDifficulty {
  beginner,
  normal,
  expert;

  String get label => switch (this) {
    QuizDifficulty.beginner => 'Beginner',
    QuizDifficulty.normal => 'Normal',
    QuizDifficulty.expert => 'Expert',
  };

  String get description => switch (this) {
    QuizDifficulty.beginner => 'Common breeds only, mostly visual questions',
    QuizDifficulty.normal => 'Adapts to your level automatically',
    QuizDifficulty.expert => 'All breeds, all question types, fewer lifelines',
  };

  String get emoji => switch (this) {
    QuizDifficulty.beginner => '🐶',
    QuizDifficulty.normal => '🐕',
    QuizDifficulty.expert => '🏆',
  };

  Color get color => switch (this) {
    QuizDifficulty.beginner => Colors.green,
    QuizDifficulty.normal => Colors.amber,
    QuizDifficulty.expert => Colors.red,
  };

  double get xpMultiplier => switch (this) {
    QuizDifficulty.beginner => 0.75,
    QuizDifficulty.normal => 1.0,
    QuizDifficulty.expert => 1.5,
  };
}

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _rng = Random();
  List<QuizQuestion>? _questions;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _quizComplete = false;
  QuizDifficulty? _selectedDifficulty;

  // New: streak counter, XP tracking, lifelines
  int _streakCount = 0;
  int _bestStreak = 0;
  int _totalXpEarned = 0;
  int _hintsRemaining = 2;
  int _fiftyfiftyRemaining = 1;
  final Set<int> _eliminatedOptions = {};
  bool _showXpToast = false;
  int _lastXpAwarded = 0;
  // Track answers for review
  final List<int?> _userAnswers = [];

  static const int _totalQuestions = 10;

  void _startQuiz(QuizDifficulty difficulty) {
    setState(() {
      _selectedDifficulty = difficulty;
      _generateQuiz(difficulty);
    });
  }

  void _generateQuiz(QuizDifficulty difficulty) {
    final dogSvc = ref.read(dogServiceProvider);
    final playerState = ref.read(playerProvider);
    final kennelCount = ref.read(kennelServiceProvider).all.length;

    List<Dog> questionPool;
    switch (difficulty) {
      case QuizDifficulty.beginner:
        // Only common dogs
        questionPool = dogSvc.filter(rarity: Rarity.common);
        if (questionPool.length < 20) questionPool = dogSvc.all;
        break;
      case QuizDifficulty.normal:
        // Adaptive based on player progress
        if (kennelCount < 10 || playerState.level < 3) {
          questionPool = dogSvc.filter(rarity: Rarity.common);
          if (questionPool.length < 20) questionPool = dogSvc.all;
        } else if (kennelCount < 30 || playerState.level < 8) {
          questionPool = dogSvc.all
              .where((b) => b.rarity == Rarity.common || b.rarity == Rarity.uncommon)
              .toList();
          if (questionPool.length < 20) questionPool = dogSvc.all;
        } else {
          questionPool = dogSvc.all;
        }
        break;
      case QuizDifficulty.expert:
        // All dogs, including rare + legendary
        questionPool = dogSvc.all;
        break;
    }

    // Lifeline counts based on difficulty
    _hintsRemaining = switch (difficulty) {
      QuizDifficulty.beginner => 3,
      QuizDifficulty.normal => 2,
      QuizDifficulty.expert => 1,
    };
    _fiftyfiftyRemaining = switch (difficulty) {
      QuizDifficulty.beginner => 2,
      QuizDifficulty.normal => 1,
      QuizDifficulty.expert => 0,
    };

    // Effective level for question type weighting
    final effectiveLevel = switch (difficulty) {
      QuizDifficulty.beginner => 1,
      QuizDifficulty.normal => playerState.level,
      QuizDifficulty.expert => 20,
    };

    _questions = List.generate(_totalQuestions, (_) => _makeQuestion(questionPool, effectiveLevel));
    _currentIndex = 0;
    _score = 0;
    _selectedOption = null;
    _answered = false;
    _quizComplete = false;
    _streakCount = 0;
    _bestStreak = 0;
    _totalXpEarned = 0;
    _eliminatedOptions.clear();
    _showXpToast = false;
    _userAnswers.clear();
  }

  QuizQuestion _makeQuestion(List<Dog> questionPool, int playerLevel) {
    // Weight question types by difficulty — beginners get more visual questions
    QuizType type;
    final roll = _rng.nextDouble();
    if (playerLevel < 5) {
      // Beginners: 70% visual, 25% habitat, 5% scientific
      if (roll < 0.70) {
        type = QuizType.nameFromPhoto;
      } else if (roll < 0.95) {
        type = QuizType.habitatFromName;
      } else {
        type = QuizType.scientificFromCommon;
      }
    } else if (playerLevel < 15) {
      // Intermediate: 40% visual, 35% habitat, 25% scientific
      if (roll < 0.40) {
        type = QuizType.nameFromPhoto;
      } else if (roll < 0.75) {
        type = QuizType.habitatFromName;
      } else {
        type = QuizType.scientificFromCommon;
      }
    } else {
      // Expert: equal distribution
      type = QuizType.values[_rng.nextInt(QuizType.values.length)];
    }

    final correct = questionPool[_rng.nextInt(questionPool.length)];

    // Smart distractors: prefer dogs from same habitat for visual questions
    final distractors = <Dog>[];

    if (type == QuizType.nameFromPhoto) {
      // Try to pick dogs that look similar (same habitat/family)
      final similar = questionPool
          .where((b) => b.name != correct.name && b.habitat == correct.habitat)
          .toList();
      similar.shuffle(_rng);
      for (final b in similar.take(2)) {
        if (!distractors.any((d) => d.name == b.name)) {
          distractors.add(b);
        }
      }
    }

    // Fill remaining distractors randomly
    while (distractors.length < 3) {
      final candidate = questionPool[_rng.nextInt(questionPool.length)];
      if (candidate.name != correct.name &&
          !distractors.any((d) => d.name == candidate.name)) {
        distractors.add(candidate);
      }
    }

    final options = [...distractors, correct]..shuffle(_rng);
    return QuizQuestion(correctDog: correct, options: options, type: type);
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    final q = _questions![_currentIndex];
    final isCorrect = q.options[index].name == q.correctDog.name;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streakCount++;
      if (_streakCount > _bestStreak) _bestStreak = _streakCount;

      // Calculate XP for this question
      int xp = q.xpValue;
      if (_streakCount >= 3) xp += 5; // Streak bonus
      _totalXpEarned += xp;
      _lastXpAwarded = xp;
    } else {
      HapticFeedback.lightImpact();
      _streakCount = 0;
      _lastXpAwarded = 0;
    }

    setState(() {
      _selectedOption = index;
      _answered = true;
      _userAnswers.add(index);
      if (isCorrect) {
        _showXpToast = true;
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) setState(() => _showXpToast = false);
        });
      }
    });
  }

  void _useHint() {
    if (_hintsRemaining <= 0 || _answered) return;
    final q = _questions![_currentIndex];
    String hint;

    switch (q.type) {
      case QuizType.habitatFromName:
        final words = q.correctDog.habitat.split(' ');
        hint = 'Hint: Starts with "${words.first}..."';
        break;
      case QuizType.scientificFromCommon:
        hint = 'Hint: Genus starts with "${q.correctDog.scientificName[0]}"';
        break;
      case QuizType.nameFromPhoto:
        hint = 'Hint: It\'s a ${q.correctDog.rarity.label.toLowerCase()} dog';
        break;
    }

    q.hintUsed = true;
    _hintsRemaining--;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hint, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.amber.shade800,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
    setState(() {});
  }

  void _useFiftyFifty() {
    if (_fiftyfiftyRemaining <= 0 || _answered) return;
    final q = _questions![_currentIndex];
    _fiftyfiftyRemaining--;

    // Find indices of wrong answers
    final wrongIndices = <int>[];
    for (int i = 0; i < q.options.length; i++) {
      if (q.options[i].name != q.correctDog.name) {
        wrongIndices.add(i);
      }
    }
    wrongIndices.shuffle(_rng);
    // Eliminate 2 wrong answers
    setState(() {
      _eliminatedOptions.addAll(wrongIndices.take(2));
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= _totalQuestions) {
      setState(() => _quizComplete = true);
      // Award XP with seasonal + difficulty multiplier
      final seasonalMultiplier = ref.read(seasonalEventServiceProvider).currentXpMultiplier;
      final diffMultiplier = _selectedDifficulty?.xpMultiplier ?? 1.0;
      final totalXp = (_totalXpEarned * seasonalMultiplier * diffMultiplier).round();
      if (totalXp > 0) {
        final playerNotifier = ref.read(playerProvider.notifier);
        final dummyDog = Dog(
          name: 'Quiz Bonus',
          scientificName: '',
          imageUrl: '',
          audioUrl: '',
          lore: '',
          habitat: '',
          conservationStatus: '',
          rarity: Rarity.common,
          baseXp: totalXp,
        );
        playerNotifier.addXpForDog(dummyDog, 0);
      }
      // Record quiz completion and check achievements
      final quizAchievements = ref.read(playerProvider.notifier).recordQuiz(_score, _totalQuestions);
      for (final key in quizAchievements) {
        final a = achievements[key];
        if (a == null || !mounted) continue;
        showAchievementSnackBar(context, a);
      }
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _answered = false;
      _eliminatedOptions.clear();
    });
  }

  Widget _buildModeSelector() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧠', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('Dog Quiz',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 4),
            const Text('Test your dog breed knowledge!',
                style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Choose Difficulty',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            ...QuizDifficulty.values.map((diff) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _startQuiz(diff),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: diff.color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: diff.color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Text(diff.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(diff.label,
                                    style: TextStyle(color: diff.color, fontSize: 17, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: diff.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${(diff.xpMultiplier * 100).round()}% XP',
                                      style: TextStyle(color: diff.color, fontSize: 10, fontWeight: FontWeight.w600)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(diff.description,
                                style: const TextStyle(color: Colors.white38, fontSize: 12, height: 1.3)),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: diff.color.withValues(alpha: 0.5), size: 16),
                    ],
                  ),
                ),
              ),
            )),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_questions == null) return _buildModeSelector();
    if (_quizComplete) return _buildResults();

    final q = _questions![_currentIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Progress bar
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_currentIndex + 1) / _totalQuestions,
                    minHeight: 8,
                    backgroundColor: bgCard,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${_currentIndex + 1}/$_totalQuestions',
                  style: const TextStyle(color: Colors.white54)),
            ],
          ),
          const SizedBox(height: 8),
          // Score + streak + difficulty badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 18),
              Text(' $_score correct',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              if (_streakCount >= 2) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text('🔥 ${_streakCount}x streak',
                      style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: q.difficultyColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: q.difficultyColor.withValues(alpha: 0.3)),
                ),
                child: Text(q.difficultyLabel,
                    style: TextStyle(color: q.difficultyColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Question
          _buildQuestion(q),
          const SizedBox(height: 16),

          // Lifeline buttons (before answering)
          if (!_answered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LifelineButton(
                  icon: Icons.lightbulb_outline,
                  label: 'Hint',
                  remaining: _hintsRemaining,
                  onTap: _hintsRemaining > 0 ? _useHint : null,
                ),
                const SizedBox(width: 12),
                _LifelineButton(
                  icon: Icons.filter_2,
                  label: '50/50',
                  remaining: _fiftyfiftyRemaining,
                  onTap: _fiftyfiftyRemaining > 0 ? _useFiftyFifty : null,
                ),
              ],
            ),
          if (!_answered) const SizedBox(height: 12),

          // XP toast overlay
          if (_showXpToast)
            Text('+$_lastXpAwarded XP${_streakCount >= 3 ? ' (streak bonus!)' : ''}',
                style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold))
                .animate().fadeIn().slideY(begin: 0.3).then().fadeOut(delay: 800.ms),

          // Options
          ...List.generate(q.options.length, (i) => _buildOption(q, i)),

          // Fun fact after answering
          if (_answered) ...[
            const SizedBox(height: 12),
            _buildFunFact(q),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _nextQuestion,
              child: Text(_currentIndex + 1 >= _totalQuestions ? 'See Results' : 'Next'),
            ).animate().fadeIn().slideY(begin: 0.2),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion(QuizQuestion q) {
    switch (q.type) {
      case QuizType.nameFromPhoto:
        return Column(
          children: [
            const Text('Which dog is this?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NetworkDogImage(url: q.correctDog.imageUrl, height: 200),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          ],
        );
      case QuizType.habitatFromName:
        return Column(
          children: [
            const Text('Where does this dog live?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            // Show dog image for context
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetworkDogImage(url: q.correctDog.imageUrl, height: 120),
            ),
            const SizedBox(height: 8),
            Text(q.correctDog.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
            Text(q.correctDog.scientificName,
                style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic, fontSize: 13)),
          ],
        );
      case QuizType.scientificFromCommon:
        return Column(
          children: [
            const Text('What is the scientific name for...',
                style: TextStyle(fontSize: 16, color: Colors.white54)),
            const SizedBox(height: 12),
            // Show dog image for context
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetworkDogImage(url: q.correctDog.imageUrl, height: 120),
            ),
            const SizedBox(height: 8),
            Text(q.correctDog.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        );
    }
  }

  Widget _buildFunFact(QuizQuestion q) {
    final dog = q.correctDog;
    // Pick a relevant fact based on question type
    String fact;
    switch (q.type) {
      case QuizType.nameFromPhoto:
        fact = '${dog.name} is a ${dog.rarity.label.toLowerCase()} dog found in ${dog.habitat.toLowerCase()}.';
        break;
      case QuizType.habitatFromName:
        fact = 'The ${dog.name} (${dog.scientificName}) lives in ${dog.habitat.toLowerCase()}.';
        break;
      case QuizType.scientificFromCommon:
        fact = '${dog.name} = ${dog.scientificName}. Conservation: ${dog.conservationStatus}.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(fact,
                style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildOption(QuizQuestion q, int index) {
    // Hide eliminated options (50/50)
    if (_eliminatedOptions.contains(index)) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          child: const Row(
            children: [
              Expanded(
                child: Text('—',
                    style: TextStyle(color: Colors.white12, fontSize: 16),
                    textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      );
    }

    final dog = q.options[index];
    final isCorrect = dog.name == q.correctDog.name;
    final isSelected = _selectedOption == index;

    Color borderColor = Colors.white12;
    Color bgColor = bgCard;
    IconData? trailingIcon;
    Color? iconColor;

    if (_answered) {
      if (isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.12);
        trailingIcon = Icons.check_circle;
        iconColor = Colors.green;
      } else if (isSelected && !isCorrect) {
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.12);
        trailingIcon = Icons.cancel;
        iconColor = Colors.red;
      }
    } else if (isSelected) {
      borderColor = Colors.amber;
    }

    String optionText;
    switch (q.type) {
      case QuizType.nameFromPhoto:
        optionText = dog.name;
        break;
      case QuizType.habitatFromName:
        optionText = dog.habitat;
        break;
      case QuizType.scientificFromCommon:
        optionText = dog.scientificName;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _selectAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: isSelected || (_answered && isCorrect) ? 2 : 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(optionText,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      fontStyle: q.type == QuizType.scientificFromCommon ? FontStyle.italic : FontStyle.normal,
                    )),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: iconColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final seasonalMultiplier = ref.read(seasonalEventServiceProvider).currentXpMultiplier;
    final diffMultiplier = _selectedDifficulty?.xpMultiplier ?? 1.0;
    final totalXp = (_totalXpEarned * seasonalMultiplier * diffMultiplier).round();
    final percentage = (_score / _totalQuestions * 100).round();
    String grade;
    String emoji;
    if (percentage >= 90) {
      grade = 'Dog Expert!';
      emoji = '🏆';
    } else if (percentage >= 70) {
      grade = 'Expert Doger!';
      emoji = '🌟';
    } else if (percentage >= 50) {
      grade = 'Getting There!';
      emoji = '📚';
    } else {
      grade = 'Keep Learning!';
      emoji = '🐾';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64))
                .animate().fadeIn().scale(),
            const SizedBox(height: 16),
            Text(grade,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.amber))
                .animate().fadeIn(delay: 200.ms),
            if (_selectedDifficulty != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedDifficulty!.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _selectedDifficulty!.color.withValues(alpha: 0.3)),
                ),
                child: Text('${_selectedDifficulty!.emoji} ${_selectedDifficulty!.label} Mode',
                    style: TextStyle(color: _selectedDifficulty!.color, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 8),
            // Score prominently displayed
            Text('$_score / $_totalQuestions',
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w800, color: Colors.white))
                .animate().fadeIn(delay: 300.ms),
            const Text('correct', style: TextStyle(color: Colors.white54, fontSize: 14)),
            const SizedBox(height: 16),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ResultStat(icon: Icons.bolt, value: '+$totalXp', label: 'XP', color: Colors.amber),
                const SizedBox(width: 24),
                _ResultStat(icon: Icons.local_fire_department, value: '${_bestStreak}x', label: 'Best Streak', color: Colors.orange),
              ],
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            // Review answers button
            OutlinedButton.icon(
              onPressed: () => _showReview(context),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Review Answers'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ).animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => setState(() => _generateQuiz(_selectedDifficulty!)),
              child: const Text('Play Again'),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() {
                _questions = null;
                _selectedDifficulty = null;
              }),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.amber),
              child: const Text('Change Difficulty'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white54),
              child: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Text('Quiz Review', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _questions!.length,
                itemBuilder: (_, i) {
                  final q = _questions![i];
                  final userAnswer = i < _userAnswers.length ? _userAnswers[i] : null;
                  final wasCorrect = userAnswer != null &&
                      q.options[userAnswer].name == q.correctDog.name;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: wasCorrect
                          ? Colors.green.withValues(alpha: 0.08)
                          : Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: wasCorrect
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.red.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              wasCorrect ? Icons.check_circle : Icons.cancel,
                              color: wasCorrect ? Colors.green : Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text('Q${i + 1}',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: q.difficultyColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(q.difficultyLabel,
                                  style: TextStyle(color: q.difficultyColor, fontSize: 10)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Answer: ${q.correctDog.name}',
                            style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (!wasCorrect && userAnswer != null)
                          Text('You chose: ${q.options[userAnswer].name}',
                              style: const TextStyle(color: Colors.red, fontSize: 12)),
                        Text('${q.correctDog.scientificName} — ${q.correctDog.habitat}',
                            style: const TextStyle(color: Colors.white38, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _LifelineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int remaining;
  final VoidCallback? onTap;

  const _LifelineButton({
    required this.icon,
    required this.label,
    required this.remaining,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && remaining > 0;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled
              ? Colors.amber.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: enabled
                ? Colors.amber.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: enabled ? Colors.amber : Colors.white24),
            const SizedBox(width: 6),
            Text('$label ($remaining)',
                style: TextStyle(
                  color: enabled ? Colors.amber : Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

class _ResultStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _ResultStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}
