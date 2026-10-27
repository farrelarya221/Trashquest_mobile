import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/models/quest_challenge.dart';
import '../../services/supabase_service.dart';
import '../../services/sqlite_service.dart';

class WasteQuizView extends StatefulWidget {
  const WasteQuizView({super.key});

  @override
  State<WasteQuizView> createState() => _WasteQuizViewState();
}

class _WasteQuizViewState extends State<WasteQuizView> {
  late ConfettiController _confettiController;

  final List<QuizQuestion> _questions = const [
    QuizQuestion(
      id: 'qz-1',
      question: 'Kulit pisang, sisa sayur, dan ampas kopi termasuk dalam kategori sampah apa?',
      options: ['Organik', 'Anorganik', 'Limbah B3', 'Residu'],
      correctIndex: 0,
      explanation: 'Sampah hayati yang berasal dari sisa makhluk hidup tergolong sampah organik dan dapat dibuat pupuk kompos.',
    ),
    QuizQuestion(
      id: 'qz-2',
      question: 'Baterai bekas dan lampu neon yang rusak harus dimasukkan ke kategori apa?',
      options: ['Organik', 'Anorganik', 'Limbah B3', 'Residu'],
      correctIndex: 2,
      explanation: 'Baterai mengandung logam berat dan bahan kimia berbahaya sehingga tergolong Bahan Berbahaya dan Beracun (B3).',
    ),
    QuizQuestion(
      id: 'qz-3',
      question: 'Sebelum menyetorkan botol plastik PET ke Bank Sampah, apa langkah yang tepat?',
      options: [
        'Dibiarkan terisi air agar berat',
        'Kosongkan, bilas jika perlu, dan remas hingga pipih',
        'Dibakar sampai meleleh',
        'Campur langsung dengan sisa makanan',
      ],
      correctIndex: 1,
      explanation: 'Botol plastik harus dalam kondisi bersih, kering, dan dipipihkan untuk menghemat ruang tampung serta menjaga nilai daur ulang.',
    ),
    QuizQuestion(
      id: 'qz-4',
      question: 'Styrofoam wadah makanan sekali pakai umumnya masuk ke dalam kelompok mana?',
      options: ['Organik', 'Bahan Daur Ulang Mudah', 'Residu', 'Limbah Radioaktif'],
      correctIndex: 2,
      explanation: 'Styrofoam sangat sulit didaur ulang secara ekonomis dan terurai lebih dari 500 tahun, sehingga digolongkan sampah residu.',
    ),
  ];

  int _currentIndex = 0;
  int? _selectedOption;
  bool _hasAnswered = false;
  int _totalEarnedXp = 0;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _selectOption(int index) {
    if (_hasAnswered) return;

    setState(() {
      _selectedOption = index;
      _hasAnswered = true;
    });

    final current = _questions[_currentIndex];
    if (index == current.correctIndex) {
      _totalEarnedXp += current.rewardXp;
      SupabaseService.instance.addXp(current.rewardXp);
      SqliteService.instance.incrementQuestProgressByType(QuestType.quiz, amount: 1);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOption = null;
        _hasAnswered = false;
      });
    } else {
      _confettiController.play();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Stack(
        alignment: Alignment.center,
        children: [
          Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppSpacing.subtleShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    ),
                    child: const Icon(Icons.stars_rounded, color: Color(0xFF10B981), size: 48),
                  ),
                  const SizedBox(height: 18),
                  Text('Kuis Selesai!', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 8),
                  Text(
                    'Hebat! Kamu telah menuntaskan seluruh materi kuis pemilahan sampah.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.3), blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amberAccent, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          '+$_totalEarnedXp XP Didapatkan',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Kembali ke Quest', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: pi / 2,
              maxBlastForce: 15,
              minBlastForce: 5,
              numberOfParticles: 25,
              colors: const [Colors.amber, Colors.green, Colors.blue, Colors.orange],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _questions[_currentIndex];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Kuis Pilah Cerdas', style: AppTextStyles.titleMedium),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.star_rounded, size: 16, color: AppColors.accentDark),
                const SizedBox(width: 4),
                Text(
                  '+${current.rewardXp} XP',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.accentDark, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress Bar with Question Counter Pill
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (_currentIndex + 1) / _questions.length,
                        minHeight: 8,
                        backgroundColor: AppColors.borderLight,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${_currentIndex + 1} / ${_questions.length}',
                    style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Question Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border),
                  boxShadow: AppSpacing.subtleShadow,
                ),
                child: Text(
                  current.question,
                  style: AppTextStyles.titleMedium.copyWith(height: 1.45, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 20),

              // Options
              Expanded(
                child: ListView.builder(
                  itemCount: current.options.length,
                  itemBuilder: (context, idx) {
                    final isSelected = _selectedOption == idx;
                    final isCorrect = idx == current.correctIndex;

                    Color cardColor = AppColors.surface;
                    Color borderColor = AppColors.border;
                    Color textColor = AppColors.textPrimary;

                    if (_hasAnswered) {
                      if (isCorrect) {
                        cardColor = const Color(0xFFECFDF5);
                        borderColor = const Color(0xFF10B981);
                        textColor = const Color(0xFF065F46);
                      } else if (isSelected) {
                        cardColor = const Color(0xFFFEF2F2);
                        borderColor = const Color(0xFFEF4444);
                        textColor = const Color(0xFF991B1B);
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _selectOption(idx),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
                              width: isSelected || (_hasAnswered && isCorrect) ? 2.0 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: borderColor.withValues(alpha: 0.15),
                                ),
                                child: Center(
                                  child: Text(
                                    String.fromCharCode(65 + idx),
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  current.options[idx],
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: textColor,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (_hasAnswered && isCorrect)
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
                              if (_hasAnswered && isSelected && !isCorrect)
                                const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Feedback Explanation
              if (_hasAnswered) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_rounded, size: 20, color: Color(0xFF0EA5E9)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          current.explanation,
                          style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF334155), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _nextQuestion,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _currentIndex < _questions.length - 1 ? 'Pertanyaan Berikutnya →' : 'Selesaikan Kuis 🎉',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
