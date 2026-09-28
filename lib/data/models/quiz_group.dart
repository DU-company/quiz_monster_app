enum QuizGroup { guess, liar, continuation, charades, speed, other }

QuizGroup resolveQuizGroup(int id) {
  return switch (id) {
    1 || 2 || 3 || 10 => QuizGroup.guess,
    41 || 42 || 43 || 44 || 45 || 46 || 59 => QuizGroup.liar,
    11 || 12 || 13 || 14 || 15 || 16 || 17 => QuizGroup.continuation,
    21 || 22 || 23 || 29 => QuizGroup.charades,
    31 || 32 || 40 => QuizGroup.speed,
    _ => QuizGroup.other,
  };
}
