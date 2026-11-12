import 'package:flutter/material.dart';
import 'package:autopulse_ai/core/theme/app_colors.dart';
import 'package:autopulse_ai/services/obd/dtc_monitor.dart';

/// App-wide, dismissible foreground alert; repeated scans do not repeat alerts.
class DtcAlertHost extends StatefulWidget {
  const DtcAlertHost({
    super.key,
    required this.monitor,
    required this.onViewCodes,
    required this.child,
  });
  final DtcMonitor monitor;
  final VoidCallback onViewCodes;
  final Widget child;
  @override
  State<DtcAlertHost> createState() => _DtcAlertHostState();
}

class _DtcAlertHostState extends State<DtcAlertHost> {
  int _revision = 0;
  List<String> _codes = const [];
  @override
  void initState() {
    super.initState();
    _revision = widget.monitor.alertRevision;
    widget.monitor.addListener(_update);
  }

  @override
  void didUpdateWidget(DtcAlertHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.monitor != widget.monitor) {
      oldWidget.monitor.removeListener(_update);
      widget.monitor.addListener(_update);
      _revision = widget.monitor.alertRevision;
      _codes = const [];
    }
  }

  void _update() {
    if (widget.monitor.alertCodes.isEmpty) {
      if (_codes.isNotEmpty) setState(() => _codes = const []);
    } else if (_revision != widget.monitor.alertRevision) {
      setState(() {
        _revision = widget.monitor.alertRevision;
        _codes = widget.monitor.alertCodes;
      });
    }
  }

  @override
  void dispose() {
    widget.monitor.removeListener(_update);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      if (_codes.isNotEmpty)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Material(
                    color: AppColors.surfaceSecondary,
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.warning),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 8),
                                const Text(
                                  'Diagnostic codes detected',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _codes.take(4).join(', ') +
                                      (_codes.length > 4 ? '…' : ''),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _codes = const []);
                                    widget.onViewCodes();
                                  },
                                  child: const Text('View codes'),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Dismiss diagnostic alert',
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _codes = const []),
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
    ],
  );
}
