import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quiz_monster/core/utils/data_utils.dart';
import 'package:quiz_monster/data/models/quiz_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

final wishlistViewModelProvider = NotifierProvider(
  () => WishlistViewModel(),
);

class WishlistViewModel extends Notifier<List<int>> {
  @override
  List<int> build() {
    getWishlist();
    return [];
  }

  Future<void> getWishlist() async {
    final pref = await SharedPreferences.getInstance();
    final resp = pref.getStringList('wishlist');
    if (resp == null) {
      pref.setStringList('wishlist', []);
      state = [];
    } else {
      state = resp.map((e) => int.parse(e)).toList();
    }
  }

  Future<void> toggleLike(QuizModel model) async {
    final pref = await SharedPreferences.getInstance();
    final resp = pref.getStringList('wishlist');
    final qid = model.id.toString();

    if (resp == null) {
      pref.setStringList('wishlist', [qid]);
      state = [model.id];
      return;
    }

    final wishlist = [...resp];
    final index = wishlist.indexWhere((e) => e == qid);
    if (index == -1) {
      /// 추가
      wishlist.insert(0, qid);
      DataUtils.showToast(msg: '위시리스트에 추가되었습니다');
    } else {
      /// 삭제
      wishlist.removeAt(index);
      DataUtils.showToast(msg: '위시리스트에서 삭제되었습니다');
    }

    pref.setStringList('wishlist', wishlist);
    state = wishlist.map((e) => int.parse(e)).toList();
  }
}
