/// Converts a media duration to the whole seconds used by outgoing messages.
///
/// Rounding up prevents a recording such as 9.9 seconds from being sent as
/// 9 seconds. A maximum is useful for capture flows with a hard duration cap.
int normalizedVideoDurationSeconds(Duration duration, {int? maxSeconds}) {
  final milliseconds = duration.inMilliseconds;
  final seconds = milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;
  if (maxSeconds == null || seconds <= maxSeconds) {
    return seconds;
  }
  return maxSeconds;
}
