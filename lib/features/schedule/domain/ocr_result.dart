class OcrTemplate {
  const OcrTemplate({required this.id, required this.name});

  final int id;
  final String name;
}

class OcrField {
  const OcrField({required this.name, required this.text});

  final String name;
  final String text;
}

class OcrAnalysis {
  const OcrAnalysis({required this.fields});

  final List<OcrField> fields;
}
