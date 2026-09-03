import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bossScheduleVoiceEnabledStorageKey = 'boss_schedule_voice_enabled';

String bossScheduleVoiceMessage({
  required String bossType,
  required String boss,
  required int leadSeconds,
}) {
  if (leadSeconds == 0) return '$bossType $boss 타임입니다.';
  return '$bossType $boss ${leadSeconds ~/ 60}분 전입니다.';
}

Future<bool> isBossScheduleVoiceEnabled() async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.reload();
  return preferences.getBool(bossScheduleVoiceEnabledStorageKey) ?? true;
}

Future<void> speakBossScheduleMessage(
  FlutterTts tts,
  String message, {
  bool awaitCompletion = false,
}) async {
  await tts.setLanguage('ko-KR');
  await tts.setSpeechRate(0.5);
  await tts.setPitch(1);
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        <IosTextToSpeechAudioCategoryOptions>[
          IosTextToSpeechAudioCategoryOptions.duckOthers,
        ],
        IosTextToSpeechAudioMode.spokenAudio,
      );
      await tts.setSharedInstance(true);
    } catch (_) {
      // iOS audio-session setup is best effort; TTS can still use defaults.
    }
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      await tts.setAudioAttributesForNavigation();
    } catch (_) {
      // Navigation audio attributes are optional for TTS engines.
    }
  }
  await tts.awaitSpeakCompletion(awaitCompletion);
  await tts.stop();
  await tts.speak(message, focus: true);
}
