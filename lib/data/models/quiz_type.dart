enum QuizType { image, question, pass, liar, fly, reaction }

QuizType? resolveQuizType(int id) {
  return switch (id) {
    1 || 3 || 10 => QuizType.image,
    2 ||
    11 ||
    12 ||
    13 ||
    14 ||
    15 ||
    16 ||
    17 ||
    61 ||
    70 => QuizType.question,
    21 || 22 || 23 || 29 || 31 || 32 || 40 => QuizType.pass,
    41 || 42 || 43 || 44 || 45 || 46 || 59 => QuizType.liar,
    80 => QuizType.fly,
    100 => QuizType.reaction,
    _ => null,
  };
}
