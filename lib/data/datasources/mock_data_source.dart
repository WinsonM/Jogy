import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/comment_model.dart';

class MockDataSource {
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

  // Mock posts
  static List<PostModel> getPosts() {
    final now = DateTime.now();

    return [
      PostModel(
        id: 'post1',
        user: _users[0],
        location: const LocationModel(
          latitude: 39.9042,
          longitude: 116.4074,
          placeName: 'Forbidden City',
          address: 'Beijing, China',
        ),
        content:
            'Amazing architecture! The Forbidden City is truly breathtaking 🏯',
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
        location: const LocationModel(
          latitude: 39.9082,
          longitude: 116.4014,
          placeName: 'Jingshan Park',
          address: 'Beijing, China',
        ),
        content: 'Sunset view from Jingshan Park 🌅',
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
        location: const LocationModel(
          latitude: 39.9000,
          longitude: 116.4100,
          placeName: 'Wangfujing Street',
          address: 'Beijing, China',
        ),
        content: 'Best street food in Beijing! 🍢',
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
        location: const LocationModel(
          latitude: 39.9065,
          longitude: 116.4120,
          placeName: 'Beihai Park',
          address: 'Beijing, China',
        ),
        content: 'Morning walk at Beihai Park 🚶‍♂️',
        imageUrls: ['https://picsum.photos/400/400?random=4'],
        likes: 123,
        isLiked: true,
        comments: [],
        createdAt: now.subtract(const Duration(hours: 8)),
      ),
      PostModel(
        id: 'post5',
        user: _users[0],
        location: const LocationModel(
          latitude: 39.9023,
          longitude: 116.4022,
          placeName: 'Temple of Heaven',
          address: 'Beijing, China',
        ),
        content: 'Ancient temple architecture 🏛️',
        imageUrls: ['https://picsum.photos/400/400?random=5'],
        likes: 456,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      PostModel(
        id: 'post6',
        user: _users[1],
        location: const LocationModel(
          latitude: 39.9101,
          longitude: 116.4093,
          placeName: 'Lama Temple',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.9076,
          longitude: 116.4181,
          placeName: '798 Art Zone',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.8989,
          longitude: 116.4048,
          placeName: 'Qianmen Street',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.9124,
          longitude: 116.4010,
          placeName: 'Drum Tower',
          address: 'Beijing, China',
        ),
        content: 'Historic drumming performance 🥁',
        imageUrls: ['https://picsum.photos/400/400?random=9'],
        likes: 234,
        isLiked: false,
        comments: [],
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      PostModel(
        id: 'post10',
        user: _users[1],
        location: const LocationModel(
          latitude: 39.9051,
          longitude: 116.3969,
          placeName: 'Houhai Lake',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.8998,
          longitude: 116.4157,
          placeName: 'Yonghe Temple',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.9033,
          longitude: 116.4205,
          placeName: 'Sanlitun',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.9132,
          longitude: 116.4134,
          placeName: 'Confucius Temple',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.8975,
          longitude: 116.4099,
          placeName: 'Tiantan Park',
          address: 'Beijing, China',
        ),
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
        location: const LocationModel(
          latitude: 39.9090,
          longitude: 116.3958,
          placeName: 'Shichahai',
          address: 'Beijing, China',
        ),
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
