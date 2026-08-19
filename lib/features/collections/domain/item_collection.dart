class ItemCollection {
  const ItemCollection({
    required this.id,
    required this.name,
    required this.items,
  });

  final int id;
  final String name;
  final List<CollectionItem> items;
}

class CollectionItem {
  const CollectionItem({
    required this.id,
    required this.part,
    required this.enchantment,
  });

  final int id;
  final String part;
  final String enchantment;
}

class CollectionInput {
  const CollectionInput({required this.name, required this.items});

  final String name;
  final List<CollectionItemInput> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name.trim(),
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class CollectionItemInput {
  const CollectionItemInput({
    this.id,
    required this.part,
    required this.enchantment,
  });

  final int? id;
  final String part;
  final String enchantment;

  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'part': part.trim(),
    'enchantment': enchantment.trim(),
  };
}
