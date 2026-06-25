import 'package:flutter/material.dart';

import 'opponent_chip_density.dart';

/// Hàng đối thủ/bot: cuộn ngang khi đông người, tự kéo tới người đang lượt.
class GameOpponentRow extends StatefulWidget {
  const GameOpponentRow({
    super.key,
    required this.itemCount,
    required this.activeIndex,
    required this.itemBuilder,
    this.density,
    this.scrollThreshold = 4,
    this.botOnly = false,
  });

  final int itemCount;
  final int activeIndex;
  final OpponentChipDensity? density;
  final int scrollThreshold;
  final bool botOnly;
  final Widget Function(BuildContext context, int index) itemBuilder;

  OpponentChipDensity get _density => density ??
      (botOnly
          ? OpponentChipDensityX.forBotCount(itemCount)
          : OpponentChipDensityX.forOpponentCount(itemCount));

  double get _chipWidth =>
      botOnly ? _density.botChipWidth : _density.chipWidth;

  double get _rowHeight =>
      botOnly ? _density.botRowHeight : _density.rowHeight;

  @override
  State<GameOpponentRow> createState() => _GameOpponentRowState();
}

class _GameOpponentRowState extends State<GameOpponentRow> {
  late final ScrollController _scroll;
  int _lastActiveIndex = -1;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
  }

  @override
  void didUpdateWidget(GameOpponentRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex ||
        oldWidget.itemCount != widget.itemCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToActive() {
    if (!mounted || widget.itemCount < widget.scrollThreshold) return;
    if (!_scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToActive());
      return;
    }

    final index = widget.activeIndex.clamp(0, widget.itemCount - 1);
    if (index == _lastActiveIndex && _scroll.position.pixels > 0) return;
    _lastActiveIndex = index;

    final viewport = _scroll.position.viewportDimension;
    final center = index * widget._chipWidth + widget._chipWidth / 2;
    final target = (center - viewport / 2).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );

    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    if (widget.itemCount < widget.scrollThreshold) {
      return ClipRect(
        child: SizedBox(
          height: widget._rowHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.itemCount; i++)
                SizedBox(
                  width: widget._chipWidth,
                  child: widget.itemBuilder(context, i),
                ),
            ],
          ),
        ),
      );
    }

    return ClipRect(
      child: SizedBox(
        height: widget._rowHeight,
        child: ListView.builder(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemExtent: widget._chipWidth,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
        ),
      ),
    );
  }
}
