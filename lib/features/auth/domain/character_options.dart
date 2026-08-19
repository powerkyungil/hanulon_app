abstract final class CharacterOptions {
  static const classesByOccupation = <String, List<String>>{
    '워리어': <String>['디펜더', '버서커', '썬더브링어', '프로스트 본'],
    '로그': <String>['스나이퍼', '어쌔신', '헌트리스'],
    '소서리스': <String>['아크 메이지', '다크 위저드', '인챈트리스', '알케미스트'],
    '프리스트': <String>['세인트', '팔라딘', '바드', '새크리파이스'],
    '실드 메이든': <String>['발키리', '액슬러', '디스트로이어'],
  };

  static List<String> get allMainClasses =>
      classesByOccupation.values.expand((items) => items).toList();

  static const equipmentParts = <String>[
    '무기',
    '보조무기',
    '투구',
    '갑옷',
    '장갑',
    '각반',
    '신발',
    '망토',
    '목걸이',
    '귀걸이',
    '팔찌',
    '반지',
    '벨트',
  ];

  static const equipmentGrades = <String, String>{
    'none': '일반',
    'hero': '영웅',
    'legend': '전설',
    'mythic': '신화',
  };

  static const skillNames = <String>[
    '영웅 1',
    '영웅 2',
    '영웅 3',
    '영웅 4',
    '전설 1',
    '전설 2',
  ];

  static const skillLevels = <String>[
    'X',
    '0강',
    '1강',
    '2강',
    '3강',
    '4강',
    '5강',
    '6강',
    '7강',
    '8강',
    '9강',
    '10강',
  ];
}
