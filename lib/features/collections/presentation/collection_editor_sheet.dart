import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/item_collection.dart';

Future<CollectionInput?> showCollectionEditorSheet(
  BuildContext context, {
  ItemCollection? collection,
}) {
  return showModalBottomSheet<CollectionInput>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: .94,
      child: _CollectionEditor(collection: collection),
    ),
  );
}

class _CollectionEditor extends StatefulWidget {
  const _CollectionEditor({this.collection});

  final ItemCollection? collection;

  @override
  State<_CollectionEditor> createState() => _CollectionEditorState();
}

class _CollectionEditorState extends State<_CollectionEditor> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late List<_ItemDraft> _items;
  String? _contentError;

  @override
  void initState() {
    super.initState();
    _name = widget.collection?.name ?? '';
    _items =
        widget.collection?.items
            .map(
              (item) => _ItemDraft(
                id: item.id,
                part: item.part,
                enchantment: item.enchantment,
              ),
            )
            .toList() ??
        <_ItemDraft>[_ItemDraft()];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(widget.collection == null ? '컬렉션 추가' : '컬렉션 수정'),
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
              initialValue: _name,
              decoration: const InputDecoration(
                labelText: '컬렉션 이름',
                hintText: '예: 전설 방어구',
              ),
              onChanged: (value) => _name = value,
              validator: (value) => value == null || value.trim().isEmpty
                  ? '컬렉션 이름을 입력해 주세요.'
                  : null,
            ),
            const SizedBox(height: AppSpacing.space6),
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('아이템 목록', style: AppTextStyles.sectionTitle),
                ),
                TextButton.icon(
                  onPressed: () => setState(() => _items.add(_ItemDraft())),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('아이템 추가'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.space2),
            ...List<Widget>.generate(_items.length, (index) {
              final item = _items[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.space3),
                child: AppCard(
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text('${index + 1}', style: AppTextStyles.bodyStrong),
                          const Spacer(),
                          IconButton(
                            onPressed: index == 0
                                ? null
                                : () => _move(index, -1),
                            tooltip: '위로 이동',
                            icon: const Icon(Icons.arrow_upward_rounded),
                          ),
                          IconButton(
                            onPressed: index == _items.length - 1
                                ? null
                                : () => _move(index, 1),
                            tooltip: '아래로 이동',
                            icon: const Icon(Icons.arrow_downward_rounded),
                          ),
                          IconButton(
                            onPressed: _items.length == 1
                                ? null
                                : () => setState(() => _items.removeAt(index)),
                            tooltip: '아이템 삭제',
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      TextFormField(
                        key: ValueKey('part-$index-${item.hashCode}'),
                        initialValue: item.part,
                        decoration: const InputDecoration(
                          labelText: '부위 / 아이템',
                          hintText: '예: 발키리 갑옷',
                        ),
                        onChanged: (value) => item.part = value,
                      ),
                      const SizedBox(height: AppSpacing.space3),
                      TextFormField(
                        key: ValueKey('enchant-$index-${item.hashCode}'),
                        initialValue: item.enchantment,
                        decoration: const InputDecoration(
                          labelText: '강화 상태',
                          hintText: '예: 강화 7',
                        ),
                        onChanged: (value) => item.enchantment = value,
                      ),
                    ],
                  ),
                ),
              );
            }),
            if (_contentError != null) ...<Widget>[
              const SizedBox(height: AppSpacing.space2),
              Text(
                _contentError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.space5),
            FilledButton(
              onPressed: _submit,
              child: Text(widget.collection == null ? '컬렉션 등록' : '변경사항 저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _move(int index, int offset) {
    setState(() {
      final item = _items.removeAt(index);
      _items.insert(index + offset, item);
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final items = _items
        .where(
          (item) =>
              item.part.trim().isNotEmpty && item.enchantment.trim().isNotEmpty,
        )
        .map(
          (item) => CollectionItemInput(
            id: item.id,
            part: item.part,
            enchantment: _normalizedEnchantment(item.enchantment),
          ),
        )
        .toList();
    if (items.isEmpty) {
      setState(() => _contentError = '부위와 강화 상태를 입력한 아이템이 필요합니다.');
      return;
    }
    Navigator.of(context).pop(CollectionInput(name: _name, items: items));
  }

  static String _normalizedEnchantment(String value) {
    final trimmed = value.trim();
    return int.tryParse(trimmed) == null ? trimmed : '강화 $trimmed';
  }
}

class _ItemDraft {
  _ItemDraft({this.id, this.part = '', this.enchantment = ''});

  final int? id;
  String part;
  String enchantment;
}
