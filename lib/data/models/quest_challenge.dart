/// Quest and challenge models for TrashQuest gamification
enum QuestType {
  sortWaste,
  scanWaste,
  quiz,
  visitWasteBank,
  pawToss,
}

class QuestChallenge {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final String difficulty;
  final int rewardXp;
  final int progress;
  final int target;
  final bool isCompleted;
  final bool isClaimed;

  const QuestChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    this.difficulty = 'Mudah',
    required this.rewardXp,
    this.progress = 0,
    required this.target,
    this.isCompleted = false,
    this.isClaimed = false,
  });

  double get progressRatio => target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

  QuestChallenge copyWith({
    String? id,
    String? title,
    String? description,
    QuestType? type,
    String? difficulty,
    int? rewardXp,
    int? progress,
    int? target,
    bool? isCompleted,
    bool? isClaimed,
  }) {
    return QuestChallenge(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      rewardXp: rewardXp ?? this.rewardXp,
      progress: progress ?? this.progress,
      target: target ?? this.target,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.name,
      'difficulty': difficulty,
      'reward_xp': rewardXp,
      'progress': progress,
      'target': target,
      'is_completed': (isCompleted || progress >= target) ? 1 : 0,
      'is_claimed': isClaimed ? 1 : 0,
    };
  }

  factory QuestChallenge.fromMap(Map<String, dynamic> map) {
    QuestType parsedType = QuestType.sortWaste;
    final typeStr = map['type']?.toString();
    if (typeStr == 'scanWaste') parsedType = QuestType.scanWaste;
    if (typeStr == 'quiz') parsedType = QuestType.quiz;
    if (typeStr == 'visitWasteBank') parsedType = QuestType.visitWasteBank;
    if (typeStr == 'pawToss') parsedType = QuestType.pawToss;

    final progressVal = (map['progress'] as num?)?.toInt() ?? 0;
    final targetVal = (map['target'] as num?)?.toInt() ?? 1;
    final completedFlag = map['is_completed'] == 1 || map['is_completed'] == true || progressVal >= targetVal;
    final claimedFlag = map['is_claimed'] == 1 || map['is_claimed'] == true;

    return QuestChallenge(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      type: parsedType,
      difficulty: map['difficulty']?.toString() ?? 'Mudah',
      rewardXp: (map['reward_xp'] as num?)?.toInt() ?? 50,
      progress: progressVal,
      target: targetVal,
      isCompleted: completedFlag,
      isClaimed: claimedFlag,
    );
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final int rewardXp;

  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.rewardXp = 10,
  });
}
