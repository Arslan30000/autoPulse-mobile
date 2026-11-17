import 'dart:async';

import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/models/driving_context.dart';
import 'package:autopulse_ai/services/driving_context/driving_context_controller.dart';

import 'driving_context_card.dart';

/// Passive overlay. Its entire hit-test region passes through to the dashboard.
/// Mount only when no higher-priority DTC alert is visible; mounting is quiet.
class ContextChangeBanner extends StatefulWidget {
  const ContextChangeBanner({super.key, required this.controller});
  final DrivingContextController controller;
  @override
  State<ContextChangeBanner> createState() => _ContextChangeBannerState();
}

class _ContextChangeBannerState extends State<ContextChangeBanner> {
  Timer? _dismiss;
  ContextNotice? _notice;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _revision = widget.controller.notice?.revision ?? 0;
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(ContextChangeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_update);
    _dismiss?.cancel();
    _notice = null;
    _revision = widget.controller.notice?.revision ?? 0;
    widget.controller.addListener(_update);
  }

  void _update() {
    final notice = widget.controller.notice;
    if (notice == null) {
      _dismiss?.cancel();
      if (_notice != null) setState(() => _notice = null);
    } else if (notice.revision != _revision) {
      _revision = notice.revision;
      _dismiss?.cancel();
      setState(() => _notice = notice);
      _dismiss = Timer(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _notice = null);
      });
    }
  }

  @override
  void dispose() {
    _dismiss?.cancel();
    widget.controller.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return IgnorePointer(
      child: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: _notice == null
                  ? const SizedBox.shrink()
                  : Padding(
                      key: ValueKey(_notice!.revision),
                      padding: const EdgeInsets.all(12),
                      child: Material(
                        color: AppColors.surfaceSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: contextColor(_notice!.context.state),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                contextIcon(_notice!.context.state),
                                color: contextColor(_notice!.context.state),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Driving context: ${_notice!.context.state.label}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(_notice!.context.state.description),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
