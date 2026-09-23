class PaginationMeta {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;
  final bool hasPrev;
  final bool hasNext;

  const PaginationMeta({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
    required this.hasPrev,
    required this.hasNext,
  });

  factory PaginationMeta.fromJson(Map<String, dynamic> json) => PaginationMeta(
    page: json['page'] as int,
    pageSize: json['pageSize'] as int,
    total: json['total'] as int,
    totalPages: json['totalPages'] as int,
    hasPrev: json['hasPrev'] as bool,
    hasNext: json['hasNext'] as bool,
  );

  static PaginationMeta empty(int page, int pageSize) => PaginationMeta(
    page: page,
    pageSize: pageSize,
    total: 0,
    totalPages: 0,
    hasPrev: false,
    hasNext: false,
  );
}

class PagedResult<T> {
  final List<T> items;
  final PaginationMeta pagination;
  const PagedResult({required this.items, required this.pagination});
}
