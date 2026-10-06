import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:quiz_monster/core/theme/responsive/layout.dart';

class TimePicker extends StatelessWidget {
  final void Function(Duration) onTimerDurationChanged;
  final Duration newDuration;
  const TimePicker({
    super.key,
    required this.newDuration,
    required this.onTimerDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: context.layout(300, mobile: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: CupertinoTimerPicker(
        mode: CupertinoTimerPickerMode.ms,
        initialTimerDuration: newDuration,
        onTimerDurationChanged: onTimerDurationChanged,
      ),
    );
  }
}
