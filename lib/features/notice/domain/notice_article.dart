class NoticeArticle {
  const NoticeArticle({
    required this.id,
    required this.title,
    required this.content,
    required this.color,
    required this.updatedAt,
    this.sortOrder = 0,
  });

  final int id;
  final String title;
  final String content;
  final String color;
  final DateTime? updatedAt;
  final int sortOrder;

  List<NoticeSection> get sections => NoticeSection.parse(content);
}

enum NoticeArticleType { rule, priceGuide }

class NoticeArticleInput {
  const NoticeArticleInput({
    required this.title,
    required this.content,
    required this.color,
  });

  final String title;
  final String content;
  final String color;

  Map<String, String> toJson() => <String, String>{
    'title': title.trim(),
    'content': content.trim(),
    'color': color,
  };
}

class NoticeSection {
  const NoticeSection({required this.title, required this.rows});

  final String title;
  final List<NoticeRow> rows;

  static List<NoticeSection> parse(String content) {
    final sections = <String, List<NoticeRow>>{};
    for (final rawLine in content.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final parts = line.split('>').map((part) => part.trim()).toList();
      if (parts.length < 3) continue;
      final section = parts.length >= 4 ? parts[1] : parts[0];
      final key = parts.length >= 4 ? parts[2] : parts[1];
      final value = _decode(
        (parts.length >= 4 ? parts.sublist(3) : parts.sublist(2)).join(' > '),
      );
      sections
          .putIfAbsent(section.isEmpty ? '안내' : section, () => <NoticeRow>[])
          .add(NoticeRow(label: key, value: value));
    }
    if (sections.isEmpty && content.trim().isNotEmpty) {
      return <NoticeSection>[
        NoticeSection(
          title: '안내',
          rows: <NoticeRow>[NoticeRow(label: '', value: content.trim())],
        ),
      ];
    }
    return sections.entries
        .map((entry) => NoticeSection(title: entry.key, rows: entry.value))
        .toList();
  }

  static String _decode(String value) {
    const marker = '\u0000';
    return value
        .replaceAll(r'\\', marker)
        .replaceAll(r'\n', '\n')
        .replaceAll(marker, r'\');
  }

  static String encode(String value) {
    return value.replaceAll(r'\', r'\\').replaceAll('\n', r'\n');
  }

  static String buildContent(List<NoticeSection> sections) {
    return sections
        .expand(
          (section) => section.rows.map(
            (row) =>
                '${section.title.trim()} > ${row.label.trim()} > '
                '${encode(row.value.trim())}',
          ),
        )
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
  }
}

class NoticeRow {
  const NoticeRow({required this.label, required this.value});

  final String label;
  final String value;
}
