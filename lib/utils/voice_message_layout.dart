import 'package:flutter/material.dart';

import 'constants.dart';

const int kVoiceMessageMinDuration = 5;
const int kVoiceMessageMaxDuration = 60;

String voiceMessageDurationText(int duration) => "$duration''";

double voiceMessageDurationWidth(
  BuildContext context,
  int duration,
  TextStyle textStyle,
) {
  final textPainter = TextPainter(
    text: TextSpan(text: voiceMessageDurationText(duration), style: textStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final minWidth = textPainter.width + kBubbleVoiceDurationPadding * 2;
  final maxWidth = MediaQuery.sizeOf(context).width / 2;
  if (duration <= kVoiceMessageMinDuration) {
    return minWidth;
  }
  if (duration >= kVoiceMessageMaxDuration) {
    return maxWidth;
  }
  final ratio =
      (duration - kVoiceMessageMinDuration) /
      (kVoiceMessageMaxDuration - kVoiceMessageMinDuration);
  return minWidth + (maxWidth - minWidth) * ratio;
}
