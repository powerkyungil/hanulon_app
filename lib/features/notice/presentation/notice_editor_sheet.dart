import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../app/theme/app_theme_palette.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/notice_article.dart';

Future<NoticeArticleInput?> showNoticeEditorSheet(
  BuildContext context, {
  required NoticeArticleType type,
  NoticeArticle? article,
}) {
  return showModalBottomSheet<NoticeArticleInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: .94,
      child: _NoticeEditor(type: type, article: article),
    ),
  );
}

class _NoticeEditor extends StatefulWidget {
  const _NoticeEditor({required this.type, this.article});

  final NoticeArticleType type;
  final NoticeArticle? article;

  @override
  State<_NoticeEditor> createState() => _NoticeEditorState();
}

class _NoticeEditorState extends State<_NoticeEditor> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late String _color;
  late String _intro;
  late String _footer;
  late List<_RuleDraft> _rules;
  late List<_PriceSectionDraft> _priceSections;
  String? _contentError;

  bool get _isRule => widget.type == NoticeArticleType.rule;

  @override
  void initState() {
    super.initState();
    final article = widget.article;
    _title = article?.title ?? (_isRule ? '길드 운영 내규' : '');
    _color = _normalizeColor(
      article?.color,
      _isRule ? _ruleColors : _priceColors,
    );
    _intro = '';
    _footer = '';
    _rules = <_RuleDraft>[];
    _priceSections = <_PriceSectionDraft>[];
    if (article != null) {
      _readArticle(article);
    }
    if (_isRule && _rules.isEmpty) {
      _rules.add(_RuleDraft());
    }
    if (!_isRule && _priceSections.isEmpty) {
      _priceSections.add(
        _PriceSectionDraft(rows: <_PriceRowDraft>[_PriceRowDraft()]),
      );
    }
  }

  void _readArticle(NoticeArticle article) {
    if (_isRule) {
      for (final section in article.sections) {
        if (section.title == '상단 안내') {
          _intro = section.rows.map((row) => row.value).join('\n\n');
        } else if (section.title == '마무리') {
          _footer = section.rows.map((row) => row.value).join('\n\n');
        } else {
          for (final row in section.rows) {
            _rules.add(
              _RuleDraft(
                title: section.title == '길드 내규' ? row.label : section.title,
                body: row.value,
              ),
            );
          }
        }
      }
      return;
    }

    _priceSections = article.sections
        .map(
          (section) => _PriceSectionDraft(
            name: section.title,
            rows: section.rows
                .map((row) => _PriceRowDraft(name: row.label, value: row.value))
                .toList(),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          '${widget.article == null ? '새로 등록' : '수정'} · '
          '${_isRule ? '길드룰' : '가격표'}',
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: '닫기',
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.space2,
            AppSpacing.screenHorizontal,
            MediaQuery.viewInsetsOf(context).bottom + AppSpacing.space8,
          ),
          children: <Widget>[
            TextFormField(
              initialValue: _title,
              decoration: const InputDecoration(labelText: '제목'),
              textInputAction: TextInputAction.next,
              onChanged: (value) => _title = value,
              validator: (value) =>
                  value == null || value.trim().isEmpty ? '제목을 입력해 주세요.' : null,
            ),
            const SizedBox(height: AppSpacing.space5),
            const Text('제목 색상', style: AppTextStyles.bodyStrong),
            const SizedBox(height: AppSpacing.space2),
            _ColorSelector(
              options: _isRule ? _ruleColors : _priceColors,
              selected: _color,
              onSelected: (value) => setState(() => _color = value),
            ),
            const SizedBox(height: AppSpacing.space6),
            if (_isRule) _buildRuleEditor() else _buildPriceEditor(),
            if (_contentError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space3),
              Text(
                _contentError!,
                style: AppTextStyles.label.copyWith(
                  color: context.appPalette.danger,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.space6),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.article == null ? '등록하기' : '변경사항 저장'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextFormField(
          initialValue: _intro,
          decoration: const InputDecoration(
            labelText: '상단 안내',
            hintText: '가입 동의, 운영 원칙 등 핵심 안내',
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 6,
          onChanged: (value) => _intro = value,
        ),
        const SizedBox(height: AppSpacing.space6),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('내규 섹션', style: AppTextStyles.sectionTitle),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _rules.add(_RuleDraft())),
              icon: const Icon(Icons.add_rounded),
              label: const Text('섹션 추가'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        ...List<Widget>.generate(_rules.length, (index) {
          final section = _rules[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: AppCard(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '섹션 ${index + 1}',
                          style: AppTextStyles.bodyStrong,
                        ),
                      ),
                      IconButton(
                        onPressed: _rules.length == 1
                            ? null
                            : () => setState(() => _rules.removeAt(index)),
                        tooltip: '섹션 삭제',
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  TextFormField(
                    key: ValueKey('rule-title-$index-${section.hashCode}'),
                    initialValue: section.title,
                    decoration: const InputDecoration(labelText: '섹션 제목'),
                    onChanged: (value) => section.title = value,
                  ),
                  const SizedBox(height: AppSpacing.space3),
                  TextFormField(
                    key: ValueKey('rule-body-$index-${section.hashCode}'),
                    initialValue: section.body,
                    decoration: const InputDecoration(
                      labelText: '본문',
                      alignLabelWithHint: true,
                    ),
                    minLines: 4,
                    maxLines: 10,
                    onChanged: (value) => section.body = value,
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.space3),
        TextFormField(
          initialValue: _footer,
          decoration: const InputDecoration(
            labelText: '마무리 문구 / 적용일',
            hintText: '예: 공지 즉시 적용',
            alignLabelWithHint: true,
          ),
          minLines: 3,
          maxLines: 6,
          onChanged: (value) => _footer = value,
        ),
      ],
    );
  }

  Widget _buildPriceEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: Text('가격 섹션', style: AppTextStyles.sectionTitle),
            ),
            TextButton.icon(
              onPressed: () => setState(
                () => _priceSections.add(
                  _PriceSectionDraft(rows: <_PriceRowDraft>[_PriceRowDraft()]),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('섹션 추가'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2),
        ...List<Widget>.generate(_priceSections.length, (sectionIndex) {
          final section = _priceSections[sectionIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.space3),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '섹션 ${sectionIndex + 1}',
                          style: AppTextStyles.bodyStrong,
                        ),
                      ),
                      IconButton(
                        onPressed: _priceSections.length == 1
                            ? null
                            : () => setState(
                                () => _priceSections.removeAt(sectionIndex),
                              ),
                        tooltip: '섹션 삭제',
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ),
                  TextFormField(
                    key: ValueKey(
                      'price-section-$sectionIndex-${section.hashCode}',
                    ),
                    initialValue: section.name,
                    decoration: const InputDecoration(
                      labelText: '섹션명',
                      hintText: '예: 전설 방어구',
                    ),
                    onChanged: (value) => section.name = value,
                  ),
                  const SizedBox(height: AppSpacing.space4),
                  ...List<Widget>.generate(section.rows.length, (rowIndex) {
                    final row = section.rows[rowIndex];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                'price-name-$rowIndex-${row.hashCode}',
                              ),
                              initialValue: row.name,
                              decoration: const InputDecoration(
                                labelText: '아이템',
                              ),
                              onChanged: (value) => row.name = value,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.space2),
                          Expanded(
                            child: TextFormField(
                              key: ValueKey(
                                'price-value-$rowIndex-${row.hashCode}',
                              ),
                              initialValue: row.value,
                              decoration: const InputDecoration(
                                labelText: '가격 / 비고',
                              ),
                              onChanged: (value) => row.value = value,
                            ),
                          ),
                          IconButton(
                            onPressed: section.rows.length == 1
                                ? null
                                : () => setState(
                                    () => section.rows.removeAt(rowIndex),
                                  ),
                            tooltip: '항목 삭제',
                            icon: const Icon(
                              Icons.remove_circle_outline_rounded,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => section.rows.add(_PriceRowDraft())),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('항목 추가'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final content = _isRule ? _buildRuleContent() : _buildPriceContent();
    if (content.isEmpty) {
      setState(() {
        _contentError = _isRule
            ? '상단 안내 또는 제목·본문 중 하나가 입력된 내규가 필요합니다.'
            : '섹션명, 아이템, 가격이 입력된 항목이 필요합니다.';
      });
      return;
    }
    Navigator.of(
      context,
    ).pop(NoticeArticleInput(title: _title, content: content, color: _color));
  }

  String _buildRuleContent() {
    final sections = <NoticeSection>[];
    if (_intro.trim().isNotEmpty) {
      sections.add(
        NoticeSection(
          title: '상단 안내',
          rows: <NoticeRow>[NoticeRow(label: '', value: _intro)],
        ),
      );
    }
    for (final rule in _rules) {
      if (rule.title.trim().isEmpty && rule.body.trim().isEmpty) continue;
      sections.add(
        NoticeSection(
          title: '길드 내규',
          rows: <NoticeRow>[NoticeRow(label: rule.title, value: rule.body)],
        ),
      );
    }
    if (_footer.trim().isNotEmpty) {
      sections.add(
        NoticeSection(
          title: '마무리',
          rows: <NoticeRow>[NoticeRow(label: '', value: _footer)],
        ),
      );
    }
    return NoticeSection.buildContent(sections);
  }

  String _buildPriceContent() {
    final sections = <NoticeSection>[];
    for (final section in _priceSections) {
      if (section.name.trim().isEmpty) continue;
      final rows = section.rows
          .where(
            (row) => row.name.trim().isNotEmpty && row.value.trim().isNotEmpty,
          )
          .map((row) => NoticeRow(label: row.name, value: row.value))
          .toList();
      if (rows.isNotEmpty) {
        sections.add(NoticeSection(title: section.name, rows: rows));
      }
    }
    return NoticeSection.buildContent(sections);
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<_ColorOption> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.space2,
      runSpacing: AppSpacing.space2,
      children: options.map((option) {
        final isSelected = option.hex.toLowerCase() == selected.toLowerCase();
        return ChoiceChip(
          selected: isSelected,
          onSelected: (_) => onSelected(option.hex),
          avatar: CircleAvatar(backgroundColor: option.color),
          label: Text(option.label),
        );
      }).toList(),
    );
  }
}

class _RuleDraft {
  _RuleDraft({this.title = '', this.body = ''});

  String title;
  String body;
}

class _PriceSectionDraft {
  _PriceSectionDraft({this.name = '', required this.rows});

  String name;
  final List<_PriceRowDraft> rows;
}

class _PriceRowDraft {
  _PriceRowDraft({this.name = '', this.value = ''});

  String name;
  String value;
}

class _ColorOption {
  const _ColorOption(this.hex, this.label, this.color);

  final String hex;
  final String label;
  final Color color;
}

String _normalizeColor(String? value, List<_ColorOption> options) {
  final normalized = value?.toLowerCase();
  if (normalized == '#a78bfa') return '#d946ef';
  if (normalized == '#facc15') return '#fbbf24';
  if (normalized == '#fb923c') return '#f43f5e';
  return options
      .firstWhere(
        (option) => option.hex.toLowerCase() == normalized,
        orElse: () => options.first,
      )
      .hex;
}

const _ruleColors = <_ColorOption>[
  _ColorOption('#f8fafc', '화이트', Color(0xFFF8FAFC)),
  _ColorOption('#94a3b8', '그레이', Color(0xFF94A3B8)),
  _ColorOption('#F2B705', '골드', Color(0xFFF2B705)),
  _ColorOption('#C9542B', '러스트', Color(0xFFC9542B)),
  _ColorOption('#ef4444', '레드', Color(0xFFEF4444)),
  _ColorOption('#f43f5e', '로즈', Color(0xFFF43F5E)),
  _ColorOption('#d946ef', '마젠타', Color(0xFFD946EF)),
  _ColorOption('#8b5cf6', '퍼플', Color(0xFF8B5CF6)),
  _ColorOption('#3b82f6', '블루', Color(0xFF3B82F6)),
  _ColorOption('#22d3ee', '시안', Color(0xFF22D3EE)),
  _ColorOption('#14b8a6', '틸', Color(0xFF14B8A6)),
  _ColorOption('#22c55e', '그린', Color(0xFF22C55E)),
];

const _priceColors = <_ColorOption>[
  _ColorOption('#f8fafc', '일반', Color(0xFFF8FAFC)),
  _ColorOption('#22c55e', '고급', Color(0xFF22C55E)),
  _ColorOption('#3b82f6', '희귀', Color(0xFF3B82F6)),
  _ColorOption('#d946ef', '영웅', Color(0xFFD946EF)),
  _ColorOption('#fbbf24', '전설', Color(0xFFFBBF24)),
  _ColorOption('#f43f5e', '신화', Color(0xFFF43F5E)),
  _ColorOption('#a3e635', '기타', Color(0xFFA3E635)),
];
