import 'dart:math' as math;
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/comment_model.dart';

class MockDataSource {
  // 用于动态生成模拟数据的中心点位置
  // 默认使用北京坐标，可以通过 setCenter 更新为用户当前位置
  static double _centerLat = 39.9042;
  static double _centerLng = 116.4074;

  // 设置中心点位置（通常在获取用户位置后调用）
  static void setCenter(double lat, double lng) {
    _centerLat = lat;
    _centerLng = lng;
  }

  // 在中心点周围生成随机偏移（约 100-500 米范围内）
  static LocationModel _randomLocationNear(String placeName, String address) {
    final random = math.Random();
    // 生成 -0.003 到 0.003 的随机偏移（约 300 米范围）
    final latOffset = (random.nextDouble() - 0.5) * 0.006;
    final lngOffset = (random.nextDouble() - 0.5) * 0.006;
    return LocationModel(
      latitude: _centerLat + latOffset,
      longitude: _centerLng + lngOffset,
      placeName: placeName,
      address: address,
    );
  }

  // Mock users
  static final List<UserModel> _users = [
    const UserModel(
      id: 'user1',
      username: 'Alice Chen',
      avatarUrl: 'https://i.pravatar.cc/150?img=1',
      bio: 'Digital nomad & coffee enthusiast ☕️',
      followers: 1234,
      following: 567,
    ),
    const UserModel(
      id: 'user2',
      username: 'Bob Zhang',
      avatarUrl: 'https://i.pravatar.cc/150?img=2',
      bio: 'Travel photographer 📸',
      followers: 5678,
      following: 234,
    ),
    const UserModel(
      id: 'user3',
      username: 'Carol Li',
      avatarUrl: 'https://i.pravatar.cc/150?img=3',
      bio: 'Food lover & blogger 🍜',
      followers: 9012,
      following: 890,
    ),
    const UserModel(
      id: 'user4',
      username: 'David Wang',
      avatarUrl: 'https://i.pravatar.cc/150?img=4',
      bio: 'Tech enthusiast 💻',
      followers: 3456,
      following: 123,
    ),
  ];

  // Mock posts - 动态生成在中心点周围
  static List<PostModel> getPosts() {
    final now = DateTime.now();

    return [
      PostModel(
        id: 'post1',
        user: _users[0],
        location: _randomLocationNear('Nearby Cafe', 'Your Area'),
        content: 'Amazing architecture! This place is truly breathtaking 🏯',
        imageUrls: [
          'https://picsum.photos/400/400?random=1',
          'https://picsum.photos/400/400?random=11',
          'https://picsum.photos/400/400?random=21',
        ],
        likes: 234,
        isLiked: false,
        favorites: 67,
        isFavorited: false,
        comments: [
          CommentModel(
            id: 'comment1',
            userId: _users[1].id,
            username: _users[1].username,
            avatarUrl: _users[1].avatarUrl,
            content: 'Wow! I need to visit this place!',
            createdAt: now.subtract(const Duration(hours: 2)),
          ),
          CommentModel(
            id: 'comment2',
            userId: _users[2].id,
            username: _users[2].username,
            avatarUrl: _users[2].avatarUrl,
            content: 'Beautiful shot! 📸',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
        createdAt: now.subtract(const Duration(hours: 5)),
      ),
      PostModel(
        id: 'post2',
        user: _users[1],
        location: _randomLocationNear('Park View', 'Your Area'),
        content: 'Sunset view from the park 🌅',
        imageUrls: [
          'https://picsum.photos/400/400?random=2',
          'https://picsum.photos/400/400?random=12',
        ],
        likes: 567,
        isLiked: true,
        favorites: 89,
        isFavorited: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 12)),
      ),
      PostModel(
        id: 'post3',
        user: _users[2],
        location: _randomLocationNear('Food Street', 'Your Area'),
        content: 'Best street food around! 🍢',
        imageUrls: ['https://picsum.photos/400/400?random=3'],
        likes: 890,
        isLiked: false,
        comments: [
          CommentModel(
            id: 'comment3',
            userId: _users[3].id,
            username: _users[3].username,
            avatarUrl: _users[3].avatarUrl,
            content: 'I love this place!',
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
        ],
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      PostModel(
        id: 'post4',
        user: _users[3],
        location: _randomLocationNear('Morning Walk Spot', 'Your Area'),
        content: 'Morning walk at the park 🚶‍♂️',
        imageUrls: ['https://picsum.photos/400/400?random=4'],
        likes: 123,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      PostModel(
        id: 'post5',
        user: _users[0],
        location: _randomLocationNear('Historic Site', 'Your Area'),
        content: 'Ancient architecture 🏛️',
        imageUrls: ['https://picsum.photos/400/400?random=5'],
        likes: 456,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      PostModel(
        id: 'post6',
        user: _users[1],
        location: _randomLocationNear('Temple', 'Your Area'),
        content: 'Peaceful atmosphere here 🙏',
        imageUrls: ['https://picsum.photos/400/400?random=6'],
        likes: 678,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 15)),
      ),
      PostModel(
        id: 'post7',
        user: _users[2],
        location: _randomLocationNear('Art District', 'Your Area'),
        content: 'Modern art meets old factory 🎨',
        imageUrls: ['https://picsum.photos/400/400?random=7'],
        likes: 789,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 20)),
      ),
      PostModel(
        id: 'post8',
        user: _users[3],
        location: _randomLocationNear('Shopping Street', 'Your Area'),
        content: 'Traditional shopping street 🏮',
        imageUrls: ['https://picsum.photos/400/400?random=8'],
        likes: 345,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 18)),
      ),
      PostModel(
        id: 'post9',
        user: _users[0],
        location: _randomLocationNear('Tower', 'Your Area'),
        content: 'Historic performance 🥁',
        imageUrls: ['https://picsum.photos/400/400?random=9'],
        likes: 234,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      PostModel(
        id: 'post10',
        user: _users[1],
        location: _randomLocationNear('Lakeside', 'Your Area'),
        content: 'Lakeside cafe vibes ☕',
        imageUrls: ['https://picsum.photos/400/400?random=10'],
        likes: 567,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 10)),
      ),
      PostModel(
        id: 'post11',
        user: _users[2],
        location: _randomLocationNear('Temple Garden', 'Your Area'),
        content: 'Incense and prayers 🕯️',
        imageUrls: ['https://picsum.photos/400/400?random=11'],
        likes: 890,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 25)),
      ),
      PostModel(
        id: 'post12',
        user: _users[3],
        location: _randomLocationNear('Nightlife District', 'Your Area'),
        content: 'Nightlife district 🌃',
        imageUrls: ['https://picsum.photos/400/400?random=12'],
        likes: 1234,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 30)),
      ),
      PostModel(
        id: 'post13',
        user: _users[0],
        location: _randomLocationNear('Cultural Center', 'Your Area'),
        content: 'Learning from the ancient wise 📚',
        imageUrls: ['https://picsum.photos/400/400?random=13'],
        likes: 456,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      PostModel(
        id: 'post14',
        user: _users[1],
        location: _randomLocationNear('Park', 'Your Area'),
        content: 'Morning tai chi session 🧘',
        imageUrls: ['https://picsum.photos/400/400?random=14'],
        likes: 678,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 35)),
      ),
      PostModel(
        id: 'post15',
        user: _users[2],
        location: _randomLocationNear('Lake', 'Your Area'),
        content: 'Boat ride on the lake 🚣',
        imageUrls: ['https://picsum.photos/400/400?random=15'],
        likes: 901,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 40)),
      ),
    ];
  }

  static Future<List<PostModel>> fetchPosts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return getPosts();
  }

  static Future<PostModel?> getPostById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    try {
      return getPosts().firstWhere((post) => post.id == id);
    } catch (e) {
      return null;
    }
  }
}
