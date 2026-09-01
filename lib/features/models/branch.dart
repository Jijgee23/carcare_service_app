class Branch {
  final String id;
  final String name;

  const Branch({required this.id, required this.name});

  factory Branch.fromJson(Map<String, dynamic> j) =>
      Branch(id: j['id'] as String, name: j['name'] as String);
}
