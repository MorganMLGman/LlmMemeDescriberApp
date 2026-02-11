import 'package:flutter/material.dart';
import 'api_service.dart';
import 'meme_model.dart';

class MemeProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<Meme> _memes = [];
  int _currentOffset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _token;
  static const int _limit = 10;

  List<Meme> get memes => _memes;
  bool get isLoading => _isLoading;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get token => _token;

  void setToken(String? token) {
    _token = token;
  }

  /// Fetches the next page of memes from the backend.
  Future<void> fetchNextPage() async {
    // Prevent multiple simultaneous fetches or fetching if we've reached the end
    if (_isLoading || !_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.fetchMemes(offset: _currentOffset, limit: _limit);

      if (response.items.isEmpty) {
        _hasMore = false;
      } else {
        _memes.addAll(response.items);
        _currentOffset += response.items.length;

        // If we got fewer items than requested, there are no more
        if (response.items.length < _limit) {
          _hasMore = false;
        }
      }
    } catch (e) {
      debugPrint('Error fetching memes: $e');
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clears the list and starts from offset 0 again.
  Future<void> refresh() async {
    _memes.clear();
    _currentOffset = 0;
    _hasMore = true;
    _errorMessage = null;
    notifyListeners(); // Immediate UI update to show loader
    await fetchNextPage();
  }

  /// Resets all state (used on logout).
  void reset() {
    _memes.clear();
    _currentOffset = 0;
    _hasMore = true;
    _isLoading = false;
    _errorMessage = null;
    _token = null;
    notifyListeners();
  }
}
