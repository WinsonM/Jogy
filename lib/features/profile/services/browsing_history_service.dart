import '../../../data/models/post_model.dart';

/// Service to track browsing history of posts.
/// Currently stores in-memory; can be extended to use local storage.
class BrowsingHistoryService {
  static final BrowsingHistoryService _instance =
      BrowsingHistoryService._internal();

  factory BrowsingHistoryService() => _instance;

  BrowsingHistoryService._internal();

  final List<PostModel> _history = [];
  static const int _maxHistorySize = 100;

  /// Add a post to browsing history (most recent first).
  void addToHistory(PostModel post) {
    // Remove if already exists to avoid duplicates
    _history.removeWhere((p) => p.id == post.id);
    // Add to front
    _history.insert(0, post);
    // Trim if exceeds max size
    if (_history.length > _maxHistorySize) {
      _history.removeLast();
    }
  }

  /// Get all browsing history (most recent first).
  List<PostModel> getHistory() => List.unmodifiable(_history);

  /// Clear all browsing history.
  void clearHistory() => _history.clear();

  /// Remove a deleted post from browsing history.
  void removePost(String postId) {
    _history.removeWhere((p) => p.id == postId);
  }

  /// Check if history is empty.
  bool get isEmpty => _history.isEmpty;

  /// Get the number of items in history.
  int get length => _history.length;
}
