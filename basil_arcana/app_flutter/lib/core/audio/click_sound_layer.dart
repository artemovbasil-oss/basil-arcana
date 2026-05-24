import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'click_sound.dart';

class ClickSoundLayer extends StatefulWidget {
  const ClickSoundLayer({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<ClickSoundLayer> createState() => _ClickSoundLayerState();
}

class _ClickSoundLayerState extends State<ClickSoundLayer> {
  static const _maxTapDistance = 18.0;
  static const _maxTapDuration = Duration(milliseconds: 650);

  final Map<int, _PointerTapCandidate> _tapCandidates = {};

  @override
  void dispose() {
    _tapCandidates.clear();
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    _tapCandidates[event.pointer] = _PointerTapCandidate(
      position: event.position,
      time: event.timeStamp,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    final candidate = _tapCandidates.remove(event.pointer);
    if (candidate == null) {
      return;
    }
    final distance = (event.position - candidate.position).distance;
    final duration = event.timeStamp - candidate.time;
    if (distance <= _maxTapDistance && duration <= _maxTapDuration) {
      playClickSound();
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final candidate = _tapCandidates[event.pointer];
    if (candidate == null) {
      return;
    }
    final distance = (event.position - candidate.position).distance;
    if (max(event.delta.distance, distance) > _maxTapDistance) {
      _tapCandidates.remove(event.pointer);
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _tapCandidates.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: widget.child,
    );
  }
}

class _PointerTapCandidate {
  const _PointerTapCandidate({
    required this.position,
    required this.time,
  });

  final Offset position;
  final Duration time;
}
