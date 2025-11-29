String formatSecondsToHms(int totalSeconds) {
  if (totalSeconds <= 0) return '0 s';
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  final parts = <String>[];
  if (hours > 0) parts.add('${hours} hr');
  if (minutes > 0) parts.add('${minutes} m');
  if (seconds > 0 || parts.isEmpty) parts.add('${seconds} s');
  return parts.join(' ');
}
