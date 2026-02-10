import 'package:flutter/material.dart';
import 'api_service.dart';
import 'meme_model.dart';

class MemeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Meme> _memes = [];
  int _currentPage = 1;
  bool _isLoading = false;
  bool _hasMore = true;

  List<Meme> get memes => _memes;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;

  Future<void> fetchNextPage() async {
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final newMemes = await _apiService.fetchMemes(_currentPage);
      if (newMemes.isEmpty) {
        _hasMore = false;
      } else {
        _memes.addAll(newMemes);
        _currentPage++;
      }
    } catch (e) {
      debugPrint('Error fetching memes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    _memes.clear();
    _currentPage = 1;
    _hasMore = true;
    await fetchNextPage();
  }
}
