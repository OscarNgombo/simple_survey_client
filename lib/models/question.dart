class Question {
  final String name;
  final String type;
  final String required;
  final String text;
  final String? description;
  final Map<String, dynamic>? options;
  final Map<String, dynamic>? fileProperties;

  Question({
    required this.name,
    required this.type,
    required this.required,
    required this.text,
    this.description,
    this.options,
    this.fileProperties,
  });
}
