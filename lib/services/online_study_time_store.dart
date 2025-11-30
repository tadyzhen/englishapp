import 'dart:async';
import 'package:flutter/foundation.dart';

/// 全域管理「線上學習時間」的 store。
///
/// - 每個 uid 對應一個 ValueNotifier<int>，存目前顯示用的秒數。
/// - 單一全域 Timer 每秒幫線上的使用者秒數 +1。
/// - 從 Firestore 重新載入時，用 updateFromServer 對齊基準，但不讓秒數往回跳。
class OnlineStudyTimeStore {
  OnlineStudyTimeStore._internal();

  static final OnlineStudyTimeStore instance = OnlineStudyTimeStore._internal();

  final Map<String, ValueNotifier<int>> _secondsByUid = {};
  final Map<String, bool> _onlineByUid = {};
  Timer? _timer;

  /// 從 server 資料更新某個使用者目前的「基準秒數」與線上狀態。
  /// [baseSeconds] 應該是 Firestore todayStudySeconds + startAt 推算後的值。
  void updateFromServer({
    required String uid,
    required int baseSeconds,
    required bool isOnline,
  }) {
    final notifier =
        _secondsByUid.putIfAbsent(uid, () => ValueNotifier<int>(baseSeconds));
    // 以 server 為基準，但不讓時間往回跳
    if (baseSeconds > notifier.value) {
      notifier.value = baseSeconds;
    }
    _onlineByUid[uid] = isOnline;
    _ensureTimer();
  }

  /// 取得對應 uid 的秒數 ValueListenable，用於 UI 綁定顯示。
  /// 若尚未存在，會以 0 建立一個新的 notifier。
  ValueListenable<int> listenableFor(String uid) {
    return _secondsByUid.putIfAbsent(uid, () => ValueNotifier<int>(0));
  }

  /// 目前是否標記為線上。
  bool isOnline(String uid) => _onlineByUid[uid] ?? false;

  void _ensureTimer() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      bool hasOnline = false;
      _secondsByUid.forEach((uid, notifier) {
        if (_onlineByUid[uid] == true) {
          hasOnline = true;
          notifier.value = notifier.value + 1;
        }
      });
      if (!hasOnline) {
        // 若目前沒有任何線上使用者，就暫停 timer 以節省資源
        _timer?.cancel();
        _timer = null;
      }
    });
  }
}
