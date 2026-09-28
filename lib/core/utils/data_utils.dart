import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../ui/common/layout/default_layout.dart';

class DataUtils {
  static void showToast({required String msg}) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.CENTER,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.black,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }

  static String formatTime(int seconds) {
    if (seconds > 9) {
      return '$seconds';
    } else {
      return seconds.toString().padLeft(2, '0');
    }
  }

  static String getReactionSpeedMessage(int reactionTime) {
    if (reactionTime <= 120) {
      return "(상위 1%)\n초인적인 반응 속도! 혹시 프로게이머? 🎯";
    } else if (reactionTime <= 160) {
      return "(상위 5%)\n매우 빠른 속도! ⚡️ ";
    } else if (reactionTime <= 250) {
      return "(상위 20%)\n훌륭한 반응 속도! 🚀";
    } else if (reactionTime <= 300) {
      return "(상위 50%)\n평균 이상! 빠른 편이에요! 👍";
    } else if (reactionTime <= 400) {
      return "(상위 60%)\n평균 속도! 연습하면 더 좋아질 거예요! 😊";
    } else if (reactionTime <= 450) {
      return "(상위 70%)\n조금만 더 노력해봐요! 💪";
    } else {
      return "(상위 90%)\n조금만 더 집중해봅시다! 🧘";
    }
  }
}
