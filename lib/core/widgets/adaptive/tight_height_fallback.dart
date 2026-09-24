import 'package:flutter/material.dart';

/// Controls above an expanding results area. When the height is too short for
/// both (landscape tablet with the keyboard open), the body scrolls as a whole
/// and the results keep a minimum height instead of overflowing.
///
/// The keyboard itself triggers the switch, so both parts are reparented with
/// GlobalKeys: rebuilding them would drop a search field's focus, close the
/// keyboard and flip the layout straight back.
class TightHeightFallback extends StatefulWidget {
  const TightHeightFallback({
    super.key,
    required this.controls,
    required this.results,
  });

  final List<Widget> controls;
  final Widget results;

  @override
  State<TightHeightFallback> createState() => _TightHeightFallbackState();
}

class _TightHeightFallbackState extends State<TightHeightFallback> {
  static const _minResultsHeight = 240.0;
  static const _tightHeight = 420.0;

  final _controlsKey = GlobalKey();
  final _resultsKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final controls = KeyedSubtree(
      key: _controlsKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: widget.controls,
      ),
    );
    final results = KeyedSubtree(key: _resultsKey, child: widget.results);
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight >= _tightHeight) {
          return Column(children: [controls, Expanded(child: results)]);
        }
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
          child: Column(
            children: [
              controls,
              SizedBox(height: _minResultsHeight, child: results),
            ],
          ),
        );
      },
    );
  }
}
