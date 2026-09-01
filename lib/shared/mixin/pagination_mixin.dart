import 'package:flutter/material.dart';

mixin PaginationMixin<T extends StatefulWidget> on State<T> {
  final ScrollController scrollController = ScrollController();

  void initPagination(VoidCallback onLoadMore) {
    scrollController.addListener(() {
      final pos = scrollController.position;
      if (pos.pixels >= pos.maxScrollExtent - 300) onLoadMore();
    });
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }
}
