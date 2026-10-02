class PassState {
  final int passCount;
  final List<String> passedWords;
  final List<String> correctWords;
  final bool didDrink;
  final int itemCount;

  PassState({
    this.passCount = 3,
    this.passedWords = const [],
    this.correctWords = const [],
    this.didDrink = false,
    this.itemCount = 30,
  });

  copyWith({
    int? passCount,
    List<String>? passedWords,
    List<String>? correctWords,
    bool? didDrink,
    int? itemCount,
  }) {
    return PassState(
      passCount: passCount ?? this.passCount,
      passedWords: passedWords ?? this.passedWords,
      correctWords: correctWords ?? this.correctWords,
      didDrink: didDrink ?? this.didDrink,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}
