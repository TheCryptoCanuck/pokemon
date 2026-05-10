import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dogquest/constants.dart';
import 'package:dogquest/helpers/game_helpers.dart';
import 'package:dogquest/helpers/ui_helpers.dart';
import 'package:dogquest/models/dog.dart';
import 'package:dogquest/services/kennel_service.dart';
import 'package:dogquest/services/dog_service.dart';
import 'package:dogquest/services/player_service.dart';
import 'package:dogquest/services/quiz_engine.dart';
import 'package:dogquest/services/dog_group_service.dart';
import 'package:dogquest/services/exam_service.dart';
import 'package:dogquest/services/analytics_service.dart';
import 'package:dogquest/services/seasonal_event_service.dart';
import 'package:dogquest/models/exam_result.dart';
import 'package:dogquest/widgets/network_dog_image.dart';

class QuizScreen extends ConsumerStatefulWidget {
  /// When both are non-null, the quiz runs in exam mode for a breed group.
  final String? examGroupId;
  final String? examTierName;

  const QuizScreen({super.key, this.examGroupId, this.examTierName});

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  final _rng = Random();
  late final QuizEngine _engine;
  List<QuizQuestion>? _questions;
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOption;
  bool _answered = false;
  bool _quizComplete = false;
  QuizDifficulty? _selectedDifficulty;

  int _streakCount = 0;
  int _bestStreak = 0;
  int _totalXpEarned = 0;
  int _hintsRemaining = 2;
  int _fiftyfiftyRemaining = 1;
  final Set<int> _eliminatedOptions = {};
  bool _showXpToast = false;
  int _lastXpAwarded = 0;
  final List<int?> _userAnswers = [];

  static const int _defaultQuestionCount = 10;

  /// Effective question count — exam tier overrides the default.
  int get _totalQuestions =>
      _isExamMode ? _examTier!.questionCount : _defaultQuestionCount;

  // ─── Exam mode state ─────────────────────────────────────────────────
  bool get _isExamMode => _examGroupId != null && _examTier != null;
  String? _examGroupId;
  ExamTier? _examTier;

  @override
  void initState() {
    super.initState();
    _engine = QuizEngine(_rng);

    // Parse exam params if provided.
    if (widget.examGroupId != null && widget.examTierName != null) {
      _examGroupId = widget.examGroupId;
      _examTier = ExamTier.values.byName(widget.examTierName!);
      // Auto-start exam after build.
      WidgetsBinding.instance.addPostFrameCallback((_) => _startExam());
    }
  }

  void _startExam() {
    if (_examGroupId == null || _examTier == null) return;
    setState(() {
      _selectedDifficulty = null; // not used in exam mode
      _generateExamQuiz(_examGroupId!, _examTier!);
    });
  }

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
        questionPool = dogSvc.filter(rarity: Rarity.common);
        if (questionPool.length < 20) questionPool = dogSvc.all;
        break;
      case QuizDifficulty.normal:
        if (kennelCount < 10 || playerState.level < 3) {
          questionPool = dogSvc.filter(rarity: Rarity.common);
          if (questionPool.length < 20) questionPool = dogSvc.all;
        } else if (kennelCount < 30 || playerState.level < 8) {
          questionPool = dogSvc.all
              .where(
                (b) => b.rarity == Rarity.common || b.rarity == Rarity.uncommon,
              )
              .toList();
          if (questionPool.length < 20) questionPool = dogSvc.all;
        } else {
          questionPool = dogSvc.all;
        }
        break;
      case QuizDifficulty.expert:
        questionPool = dogSvc.all;
        break;
    }

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

    final effectiveLevel = switch (difficulty) {
      QuizDifficulty.beginner => 1,
      QuizDifficulty.normal => playerState.level,
      QuizDifficulty.expert => 20,
    };

    final weightedPool = _engine.weightedTypes(effectiveLevel, difficulty);
    final usedBreeds = <String>{};
    final generated = <QuizQuestion>[];
    var attempts = 0;
    while (
        generated.length < _totalQuestions && attempts < _totalQuestions * 5) {
      attempts++;
      final type = weightedPool[_rng.nextInt(weightedPool.length)];
      final q = _engine.makeQuestionOfType(
        type,
        questionPool,
        effectiveLevel,
        difficulty,
      );
      if (usedBreeds.contains(q.correctDog.name) &&
          attempts < _totalQuestions * 4) {
        continue; // re-roll to avoid duplicate breed
      }
      usedBreeds.add(q.correctDog.name);
      generated.add(q);
    }
    _questions = generated;
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

  /// Generate a breed-group exam quiz. Breeds are filtered to the target group;
  /// distractors can come from any breed so questions remain solvable.
  void _generateExamQuiz(String groupId, ExamTier tier) {
    final dogSvc = ref.read(dogServiceProvider);
    final group = families.firstWhere((g) => g.id == groupId);

    // Filter breeds that belong to this group.
    final groupBreeds = dogSvc.all.where((b) => group.containsDog(b)).toList();

    // Fall back to all breeds if the group is too small (shouldn't happen).
    final questionPool = groupBreeds.length >= 4 ? groupBreeds : dogSvc.all;

    final totalQ = tier.questionCount;
    final weightedPool = _engine.weightedTypesForExam(tier);

    // Exam lifelines: bronze=2/1, silver=1/0, gold=0/0
    _hintsRemaining = switch (tier) {
      ExamTier.bronze => 2,
      ExamTier.silver => 1,
      ExamTier.gold => 0,
    };
    _fiftyfiftyRemaining = switch (tier) {
      ExamTier.bronze => 1,
      ExamTier.silver => 0,
      ExamTier.gold => 0,
    };

    final usedBreeds = <String>{};
    final generated = <QuizQuestion>[];
    var attempts = 0;
    while (generated.length < totalQ && attempts < totalQ * 5) {
      attempts++;
      final type = weightedPool[_rng.nextInt(weightedPool.length)];
      // Use group breeds for the correct answer, but allow full pool for
      // distractor variety via makeQuestionOfType's pool param.
      final q = _engine.makeQuestionOfType(
        type,
        questionPool,
        20, // treat exam as high-level for question generation
        QuizDifficulty.expert, // exam uses expert generation paths
      );
      if (usedBreeds.contains(q.correctDog.name) && attempts < totalQ * 4) {
        continue;
      }
      usedBreeds.add(q.correctDog.name);
      generated.add(q);
    }

    _questions = generated;
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

  void _selectAnswer(int index) {
    if (_answered) return;
    final q = _questions![_currentIndex];
    final isCorrect = index == q.correctIndex;

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      _score++;
      _streakCount++;
      if (_streakCount > _bestStreak) _bestStreak = _streakCount;

      int xp = q.type.xpValue;
      if (_streakCount >= 3) xp += 5;
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
    final hint = _engine.getHint(q);

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

    final wrongIndices = <int>[];
    for (int i = 0; i < q.options.length; i++) {
      if (i != q.correctIndex) wrongIndices.add(i);
    }
    wrongIndices.shuffle(_rng);
    setState(() {
      _eliminatedOptions.addAll(wrongIndices.take(2));
    });
  }

  void _nextQuestion() {
    if (_currentIndex + 1 >= _totalQuestions) {
      setState(() => _quizComplete = true);
      final seasonalMultiplier =
          ref.read(seasonalEventServiceProvider).currentXpMultiplier;
      final diffMultiplier = _selectedDifficulty?.xpMultiplier ?? 1.0;
      final totalXp =
          (_totalXpEarned * seasonalMultiplier * diffMultiplier).round();
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

      // Record exam result if in exam mode.
      if (_isExamMode) {
        final passed = _score / _totalQuestions >= _examTier!.passThreshold;
        final result = ExamResult(
          groupId: _examGroupId!,
          tier: _examTier!,
          score: _score,
          totalQuestions: _totalQuestions,
          passed: passed,
          timestamp: DateTime.now(),
        );
        ref.read(examServiceProvider).recordResult(result);
        ref.read(analyticsProvider).track('exam_attempted', {
          'group_id': _examGroupId!,
          'tier': _examTier!.name,
          'score': _score,
          'total': _totalQuestions,
          'percentage': (result.percentage * 100).round(),
          'passed': passed,
        });
        if (passed) {
          ref.read(analyticsProvider).track('exam_passed', {
            'group_id': _examGroupId!,
            'tier': _examTier!.name,
            'xp_multiplier': _examTier!.xpMultiplier,
          });
          // Check for Canine Scholar achievement.
          if (ref.read(examServiceProvider).isCanineScholar) {
            ref.read(analyticsProvider).track('canine_scholar_achieved', {});
          }
        }
      }

      final quizAchievements =
          ref.read(playerProvider.notifier).recordQuiz(_score, _totalQuestions);
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

  // ─── Build Methods ──────────────────────────────────────────────────────────

  Widget _buildModeSelector() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.quiz, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Dog Quiz',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Test your dog breed knowledge!',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 28),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose Difficulty',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...QuizDifficulty.values.map(
              (diff) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () => _startQuiz(diff),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: diff.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: diff.color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          diff.emoji,
                          style: const TextStyle(fontSize: 32),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    diff.label,
                                    style: TextStyle(
                                      color: diff.color,
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: diff.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${(diff.xpMultiplier * 100).round()}% XP',
                                      style: TextStyle(
                                        color: diff.color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                diff.description,
                                style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: diff.color.withValues(alpha: 0.5),
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
    return Scaffold(
      backgroundColor: bgDeep,
      body: SafeArea(
        child: _questions == null
            ? _buildModeSelector()
            : _quizComplete
                ? _buildResults()
                : _buildQuestionView(),
      ),
    );
  }

  Widget _buildQuestionView() {
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
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentIndex + 1}/$_totalQuestions',
                style: const TextStyle(color: Colors.white54),
              ),
            ],
          ),
          if (_isExamMode) ...[
            const SizedBox(height: 4),
            Text(
              '${_examTier!.emoji} ${families.firstWhere((g) => g.id == _examGroupId).name} — ${_examTier!.label} Exam',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          // Score + streak + type badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 18),
              Text(
                ' $_score correct',
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_streakCount >= 2) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '\u{1F525} ${_streakCount}x streak',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: q.type.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: q.type.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(q.type.icon, color: q.type.color, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      q.type.label,
                      style: TextStyle(
                        color: q.type.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Question
          _buildQuestion(q),
          const SizedBox(height: 16),

          // Lifeline buttons
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

          // XP toast
          if (_showXpToast)
            Text(
              '+$_lastXpAwarded XP${_streakCount >= 3 ? ' (streak bonus!)' : ''}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            )
                .animate()
                .fadeIn()
                .slideY(begin: 0.3)
                .then()
                .fadeOut(delay: 800.ms),

          // Options — photo grid for photoFromName / oddOneOut, text for rest
          if (q.type == QuizType.photoFromName || q.type == QuizType.oddOneOut)
            _buildPhotoOptions(q)
          else
            ...List.generate(q.options.length, (i) => _buildOption(q, i)),

          // Fun fact after answering
          if (_answered) ...[
            const SizedBox(height: 12),
            _buildFunFact(q),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _nextQuestion,
              child: Text(
                _currentIndex + 1 >= _totalQuestions ? 'See Results' : 'Next',
              ),
            ).animate().fadeIn().slideY(begin: 0.2),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestion(QuizQuestion q) {
    switch (q.type) {
      case QuizType.nameFromPhoto:
      case QuizType.silhouetteRound:
        return Column(
          children: [
            Text(
              q.type.prompt,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: q.type == QuizType.silhouetteRound
                  ? ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0xFF1A1A2E),
                        BlendMode.saturation,
                      ),
                      child: NetworkDogImage(
                        url: q.correctDog.imageUrl,
                        height: 200,
                      ),
                    )
                  : NetworkDogImage(url: q.correctDog.imageUrl, height: 200),
            ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95)),
          ],
        );

      case QuizType.photoFromName:
        return Column(
          children: [
            Text(
              q.type.prompt,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              q.correctDog.name,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        );

      case QuizType.breedFromClue:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(q.type.icon, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  q.type.prompt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
              ),
              child: Text(
                q.clueText ?? q.correctDog.lore,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        );

      case QuizType.compareBreeds:
        final dogs = q.photoDogs ?? [];
        return Column(
          children: [
            Text(
              q.clueText ?? q.type.prompt,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            if (dogs.length >= 2)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: NetworkDogImage(
                            url: dogs[0].imageUrl,
                            height: 120,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dogs[0].name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: NetworkDogImage(
                            url: dogs[1].imageUrl,
                            height: 120,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          dogs[1].name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        );

      case QuizType.oddOneOut:
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(q.type.icon, color: Colors.amber, size: 20),
                const SizedBox(width: 8),
                Text(
                  q.type.prompt,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'One breed doesn\'t match the others by size',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        );

      // Default: show photo + breed name + prompt
      default:
        return Column(
          children: [
            Text(
              q.type.prompt,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: NetworkDogImage(url: q.correctDog.imageUrl, height: 140),
            ),
            const SizedBox(height: 8),
            Text(
              q.correctDog.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildPhotoOptions(QuizQuestion q) {
    final dogs = q.photoDogs ?? [];
    if (dogs.isEmpty) {
      return Column(
        children: List.generate(q.options.length, (i) => _buildOption(q, i)),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: dogs.length,
      itemBuilder: (_, i) {
        if (_eliminatedOptions.contains(i)) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
            ),
            child: const Center(
              child: Text('—', style: TextStyle(color: Colors.white12)),
            ),
          );
        }

        final isCorrect = i == q.correctIndex;
        final isSelected = _selectedOption == i;

        Color borderColor = Colors.white12;
        Color bgColor = bgCard;
        if (_answered) {
          if (isCorrect) {
            borderColor = Colors.green;
            bgColor = Colors.green.withValues(alpha: 0.12);
          } else if (isSelected && !isCorrect) {
            borderColor = Colors.red;
            bgColor = Colors.red.withValues(alpha: 0.12);
          }
        } else if (isSelected) {
          borderColor = Colors.amber;
        }

        return GestureDetector(
          onTap: () => _selectAnswer(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: borderColor,
                width: isSelected || (_answered && isCorrect) ? 2 : 1.5,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(13),
                    ),
                    child: NetworkDogImage(
                      url: dogs[i].imageUrl,
                      height: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Text(
                    dogs[i].name,
                    style: TextStyle(
                      color:
                          _answered && isCorrect ? Colors.green : Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFunFact(QuizQuestion q) {
    final fact = _engine.getFunFact(q);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fact,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildOption(QuizQuestion q, int index) {
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
                child: Text(
                  '—',
                  style: TextStyle(color: Colors.white12, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isCorrect = index == q.correctIndex;
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
            border: Border.all(
              color: borderColor,
              width: isSelected || (_answered && isCorrect) ? 2 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  q.options[index],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
    final seasonalMultiplier =
        ref.read(seasonalEventServiceProvider).currentXpMultiplier;
    final diffMultiplier = _selectedDifficulty?.xpMultiplier ?? 1.0;
    final totalXp =
        (_totalXpEarned * seasonalMultiplier * diffMultiplier).round();
    final percentage = (_score / _totalQuestions * 100).round();
    String grade;
    String emoji;
    if (percentage == 100) {
      grade = 'Flawless!';
      emoji = '\u{1F451}';
    } else if (percentage >= 90) {
      grade = 'Dog Expert!';
      emoji = '\u{1F3C6}';
    } else if (percentage >= 70) {
      grade = 'Sharp Nose!';
      emoji = '\u{1F31F}';
    } else if (percentage >= 50) {
      grade = 'Good Boy!';
      emoji = '\u{1F4DA}';
    } else {
      grade = 'Keep Sniffing!';
      emoji = '\u{1F43E}';
    }

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 64))
                .animate()
                .fadeIn()
                .scale(),
            const SizedBox(height: 16),
            Text(
              grade,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.amber,
              ),
            ).animate().fadeIn(delay: 200.ms),
            if (_selectedDifficulty != null) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedDifficulty!.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedDifficulty!.color.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '${_selectedDifficulty!.emoji} ${_selectedDifficulty!.label} Mode',
                  style: TextStyle(
                    color: _selectedDifficulty!.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            // Exam pass/fail banner
            if (_isExamMode) ...[
              const SizedBox(height: 12),
              () {
                final passed =
                    _score / _totalQuestions >= _examTier!.passThreshold;
                final groupName =
                    families.firstWhere((g) => g.id == _examGroupId).name;
                return Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: passed
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: passed
                          ? Colors.green.withValues(alpha: 0.4)
                          : Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        passed
                            ? '${_examTier!.emoji} ${_examTier!.label} Certified!'
                            : 'Not yet — ${(_examTier!.passThreshold * 100).round()}% needed',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: passed ? Colors.green : Colors.red.shade300,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passed
                            ? '$groupName ${_examTier!.label} — ${_examTier!.xpMultiplier}x XP bonus unlocked!'
                            : 'You can retry in ${_examTier!.cooldown.inHours}h',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],
            const SizedBox(height: 16),
            // Percentage ring
            SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _score / _totalQuestions,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 70
                            ? Colors.green
                            : percentage >= 50
                                ? Colors.amber
                                : Colors.red,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_score/$_totalQuestions',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms)
                .scale(begin: const Offset(0.8, 0.8)),
            const SizedBox(height: 20),
            // Stats row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ResultStat(
                  icon: Icons.bolt,
                  value: '+$totalXp',
                  label: 'XP earned',
                  color: Colors.amber,
                ),
                const SizedBox(width: 24),
                _ResultStat(
                  icon: Icons.local_fire_department,
                  value: '${_bestStreak}x',
                  label: 'Best streak',
                  color: Colors.orange,
                ),
                const SizedBox(width: 24),
                _ResultStat(
                  icon: Icons.category,
                  value: '${_questions!.map((q) => q.type).toSet().length}',
                  label: 'Q types',
                  color: Colors.purple,
                ),
              ],
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showReview(context),
              icon: const Icon(Icons.visibility, size: 18),
              label: const Text('Review Answers'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white70),
            ).animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 16),
            if (_isExamMode) ...[
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber.withValues(alpha: 0.2),
                  foregroundColor: Colors.amber,
                ),
                child: const Text('Done'),
              ).animate().fadeIn(delay: 500.ms),
              // Prompt next tier if passed and there's one available.
              if (_score / _totalQuestions >= _examTier!.passThreshold &&
                  _examTier!.next != null) ...[
                const SizedBox(height: 8),
                () {
                  final next = _examTier!.next!;
                  return OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.pop(context);
                      Future.delayed(const Duration(milliseconds: 200), () {
                        if (!mounted) return;
                        context.push(
                          '/quiz?examGroup=$_examGroupId&examTier=${next.name}',
                        );
                      });
                    },
                    icon:
                        Text(next.emoji, style: const TextStyle(fontSize: 16)),
                    label: Text('Take ${next.label} Exam'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: switch (next) {
                        ExamTier.silver => examSilver,
                        ExamTier.gold => examGold,
                        _ => Colors.white70,
                      },
                    ),
                  );
                }(),
              ],
            ] else ...[
              ElevatedButton(
                onPressed: () =>
                    setState(() => _generateQuiz(_selectedDifficulty!)),
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
            ],
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
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Quiz Review',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _questions!.length,
                itemBuilder: (_, i) {
                  final q = _questions![i];
                  final userAnswer =
                      i < _userAnswers.length ? _userAnswers[i] : null;
                  final wasCorrect = userAnswer == q.correctIndex;
                  final correctAnswer = q.options[q.correctIndex];

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
                            Text(
                              'Q${i + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: q.type.color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    q.type.icon,
                                    color: q.type.color,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    q.type.label,
                                    style: TextStyle(
                                      color: q.type.color,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Answer: $correctAnswer',
                          style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (!wasCorrect && userAnswer != null)
                          Text(
                            'You chose: ${q.options[userAnswer]}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        Text(
                          q.correctDog.name,
                          style: const TextStyle(
                            color: Colors.white38,
                            fontSize: 11,
                          ),
                        ),
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
            Icon(
              icon,
              size: 16,
              color: enabled ? Colors.amber : Colors.white24,
            ),
            const SizedBox(width: 6),
            Text(
              '$label ($remaining)',
              style: TextStyle(
                color: enabled ? Colors.amber : Colors.white24,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
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
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }
}
