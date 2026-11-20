/// 20-level curriculum metadata (see docs/CURRICULUM.md §2).
class Level {
  const Level(this.no, this.grade, this.stage, this.wpm);
  final int no;
  final String grade;
  final String stage;
  final int wpm;
}

const levels = <Level>[
  Level(1, 'Pre-K', 'Little Ears', 75),
  Level(2, 'Pre-K/K', 'Little Ears', 85),
  Level(3, 'Kindergarten', 'Little Ears', 95),
  Level(4, 'Grade 1', 'Early Grades', 100),
  Level(5, 'Grade 1–2', 'Early Grades', 105),
  Level(6, 'Grade 2', 'Early Grades', 110),
  Level(7, 'Grade 3', 'Early Grades', 120),
  Level(8, 'Grade 4', 'Upper Elementary', 125),
  Level(9, 'Grade 5', 'Upper Elementary', 130),
  Level(10, 'Grade 5–6', 'Upper Elementary', 135),
  Level(11, 'Grade 6', 'Upper Elementary', 140),
  Level(12, 'Grade 7', 'Middle School', 145),
  Level(13, 'Grade 8', 'Middle School', 150),
  Level(14, 'Grade 9', 'Middle School', 155),
  Level(15, 'Grade 10', 'High School', 160),
  Level(16, 'Grade 11', 'High School', 165),
  Level(17, 'Grade 12', 'High School', 170),
  Level(18, 'Freshman', 'College', 175),
  Level(19, 'Sophomore–Junior', 'College', 185),
  Level(20, 'Senior', 'College', 195),
];
