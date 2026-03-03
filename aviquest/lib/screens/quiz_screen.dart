import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants.dart';
import '../helpers/game_helpers.dart';
import '../models/bird.dart';
import '../services/bird_service.dart';
import '../services/player_service.dart';
import '../services/seasonal_event_service.dart';
import '../widgets/network_bird_image.dart';

/// A quiz question with one correct answer and three distractors.
class QuizQuestion {
  final Bird correctBird;
  final List<Bird> options; // 4 options, one is correct
  final QuizType type;

  const QuizQuestion({
    required this.correctBird,
    required this.options,
    required this.type,
  });
}

enum QuizType { nameFromPhoto, habitatFromName, scientificFromCommon }

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({super.key});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _rng = Random();
  late List<QuizQuestion> _questions;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _quizComplete = false;

  static const int _totalQuestions = 10;
  static const int _xpPerCorrect = 15;

  @override
  void initState() {
    super.initState();
    _generateQuiz();
  }

  void _generateQuiz() {
    final birdSvc = ref.read(birdServiceProvider);
    final allBirds = birdSvc.all;
    _questions = List.generate(_totalQuestions, (_) => _makeQuestion(allBirds));
    _currentIndex = 0;
    _score = 0;
    _selectedOption = null;
    _answered = false;
    _quizComplete = false;
  }

  QuizQuestion _makeQuestion(List<Bird> allBirds) {
    final type = QuizType.values[_rng.nextInt(QuizType.values.length)];
    final correct = allBirds[_rng.nextInt(allBirds.length)];

    // Pick 3 unique distractors
    final distractors = <Bird>[];
    while (distractors.length < 3) {
      final candidate = allBirds[_rng.nextInt(allBirds.length)];
      if (candidate.name != correct.name &&
          !distractors.any((d) => d.name == candidate.name)) {
        distractors.add(candidate);
      }
    }

    final options = [...distractors, correct]..shuffle(_rng);
    return QuizQuestion(correctBird: correct, options: options, type: type);
  }

  void _selectAnswer(int index) {
    if (_answered) return;
    HapticFeedback.lightImpact();
    setState(() {
      _selectedOption = index;
      _answered = true;
      if (_questions[_currentIndex].options[index].name ==
          _questions[_currentIndex].correctBird.name) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= _totalQuestions) {
      setState(() => _quizComplete = true);
      // Award XP with seasonal multiplier and streak bonus
      final seasonalMultiplier = ref.read(seasonalEventServiceProvider).currentXpMultiplier;
      final baseXp = _score * _xpPerCorrect;
      final totalXp = (baseXp * seasonalMultiplier).round();
      if (totalXp > 0) {
        final playerNotifier = ref.read(playerProvider.notifier);
        final dummyBird = Bird(
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
        playerNotifier.addXpForBird(dummyBird, 0);
      }
      // Record quiz completion and check achievements
      final quizAchievements = ref.read(playerProvider.notifier).recordQuiz(_score, _totalQuestions);
      for (final key in quizAchievements) {
        final a = achievements[key];
        if (a == null || !mounted) continue;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1A2F1F),
            duration: const Duration(seconds: 4),
            content: Row(children: [
              Text(a.$1, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Achievement Unlocked!', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                Text(a.$2, style: const TextStyle(color: Colors.white70)),
              ]),
            ]),
          ),
        );
      }
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _answered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizComplete) return _buildResults();

    final q = _questions[_currentIndex];
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
          const SizedBox(height: 12),
          // Score
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 18),
              Text(' $_score correct',
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          // Question
          _buildQuestion(q),
          const SizedBox(height: 20),
          // Options
          ...List.generate(q.options.length, (i) => _buildOption(q, i)),
          // Next button
          if (_answered) ...[
            const SizedBox(height: 20),
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
            const Text('Which bird is this?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: NetworkBirdImage(url: q.correctBird.imageUrl, height: 180),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          ],
        );
      case QuizType.habitatFromName:
        return Column(
          children: [
            Text('Where does the ${q.correctBird.name} live?',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(q.correctBird.scientificName,
                style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
          ],
        );
      case QuizType.scientificFromCommon:
        return Column(
          children: [
            const Text('What is the scientific name for...',
                style: TextStyle(fontSize: 16, color: Colors.white54)),
            const SizedBox(height: 8),
            Text(q.correctBird.name,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.amber)),
          ],
        );
    }
  }

  Widget _buildOption(QuizQuestion q, int index) {
    final bird = q.options[index];
    final isCorrect = bird.name == q.correctBird.name;
    final isSelected = _selectedOption == index;

    Color borderColor = Colors.white12;
    Color bgColor = bgCard;
    if (_answered) {
      if (isCorrect) {
        borderColor = Colors.green;
        bgColor = Colors.green.withOpacity(0.1);
      } else if (isSelected && !isCorrect) {
        borderColor = Colors.red;
        bgColor = Colors.red.withOpacity(0.1);
      }
    } else if (isSelected) {
      borderColor = Colors.amber;
    }

    String optionText;
    switch (q.type) {
      case QuizType.nameFromPhoto:
        optionText = bird.name;
        break;
      case QuizType.habitatFromName:
        optionText = bird.habitat;
        break;
      case QuizType.scientificFromCommon:
        optionText = bird.scientificName;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => _selectAnswer(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(optionText,
                    style: const TextStyle(color: Colors.white, fontSize: 15)),
              ),
              if (_answered && isCorrect)
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
              if (_answered && isSelected && !isCorrect)
                const Icon(Icons.cancel, color: Colors.red, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final seasonalMultiplier = ref.read(seasonalEventServiceProvider).currentXpMultiplier;
    final totalXp = (_score * _xpPerCorrect * seasonalMultiplier).round();
    final percentage = (_score / _totalQuestions * 100).round();
    String grade;
    String emoji;
    if (percentage >= 90) {
      grade = 'Ornithologist!';
      emoji = '🏆';
    } else if (percentage >= 70) {
      grade = 'Expert Birder!';
      emoji = '🌟';
    } else if (percentage >= 50) {
      grade = 'Getting There!';
      emoji = '📚';
    } else {
      grade = 'Keep Learning!';
      emoji = '🐣';
    }

    return Center(
      child: Padding(
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
            const SizedBox(height: 8),
            Text('$_score / $_totalQuestions correct',
                style: const TextStyle(fontSize: 18, color: Colors.white70))
                .animate().fadeIn(delay: 300.ms),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt, color: Colors.amber),
                Text(' +$totalXp XP earned',
                    style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => setState(() => _generateQuiz()),
              child: const Text('Play Again'),
            ).animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 12),
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
}
