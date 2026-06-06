import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:share_plus/share_plus.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MCForumApp());
}

const kPrimary = Color(0xFF3B5BDB);
const kYes     = Color(0xFF0CA678);
const kYesBg   = Color(0xFFE6F7F1);
const kNo      = Color(0xFFE8590C);
const kNoBg    = Color(0xFFFDEFE6);
const kGold    = Color(0xFFF59F00);
const kGoldBg  = Color(0xFFFFF8E6);
const kBg      = Color(0xFFF7F8FA);
const kCard    = Color(0xFFFFFFFF);
const kBorder  = Color(0xFFE3E7EE);
const kSoft    = Color(0xFF5A6172);
const kFaint   = Color(0xFF9097A8);
const kPur     = Color(0xFF7048E8);
const kBrs     = Color(0xFFEDF0FD);

// 管理者UID（結果入力権限）
const kAdminUid = 'LNZHy6qDl9WyeKiF0MNo0rDkh0w1';


// 称号システム
Map<String, String> getTitleFromScore(double accuracy, int totalVotes) {
  if (totalVotes < 5) return {'icon': '🔍', 'label': '見習い予測者', 'color': '9097A8'};
  if (accuracy >= 0.90) return {'icon': '🔮', 'label': '神託者', 'color': '7048E8'};
  if (accuracy >= 0.80) return {'icon': '🌟', 'label': '大予言者', 'color': 'F59F00'};
  if (accuracy >= 0.70) return {'icon': '⭐', 'label': '予言者', 'color': '3B5BDB'};
  if (accuracy >= 0.60) return {'icon': '📈', 'label': '分析家', 'color': '0CA678'};
  return {'icon': '🔍', 'label': '見習い予測者', 'color': '9097A8'};
}

String getTitleFromUserData(Map<String, dynamic>? data) {
  if (data == null) return '🔍 見習い予測者';
  final totalVotes = data['totalVotes'] ?? 0;
  final influenceScore = (data['influence_score'] ?? 0.0).toDouble();
  final accuracy = totalVotes > 0 ? (influenceScore / (1 + totalVotes * 0.1) / 100) : 0.0;
  final t = getTitleFromScore(accuracy, totalVotes);
  return t['icon']! + ' ' + t['label']!;
}

const kExpertiseTags = [
  '経済・金融', 'AI・テクノロジー', '政治・社会', '未確認現象・予言',
];

class Topic {
  final String id, question, category, authorName, authorUid, deadline;
  final bool sponsored;
  final int prize, yesCount, noCount;
  final bool resolved;
  final String? actualResult;
  final double authorInfluenceScore;
  final String judgeCondition; // 判定基準

  Topic({
    required this.id, required this.question, required this.category,
    required this.authorName, required this.authorUid, required this.deadline,
    this.sponsored = false, this.prize = 0,
    this.yesCount = 0, this.noCount = 0,
    this.resolved = false, this.actualResult,
    this.authorInfluenceScore = 0,
    this.judgeCondition = '',
  });

  factory Topic.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Topic(
      id: doc.id,
      question: d['question'] ?? '',
      category: d['category'] ?? '',
      authorName: d['authorName'] ?? '',
      authorUid: d['authorUid'] ?? '',
      deadline: d['deadline'] ?? '',
      sponsored: d['sponsored'] ?? false,
      prize: d['prize'] ?? 0,
      yesCount: d['yesCount'] ?? 0,
      noCount: d['noCount'] ?? 0,
      resolved: d['resolved'] ?? false,
      actualResult: d['actualResult'],
      authorInfluenceScore: (d['authorInfluenceScore'] ?? 0).toDouble(),
      judgeCondition: d['judgeCondition'] ?? '',
    );
  }
}

class MCForumApp extends StatelessWidget {
  const MCForumApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MC forum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: kCard,
          foregroundColor: Color(0xFF1A1D29),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;
  final _pages = const [HomeScreen(), SearchScreen(), RankingScreen(), MessagesScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_idx],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _idx,
        onTap: (i) => setState(() => _idx = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: kPrimary,
        unselectedItemColor: kFaint,
        backgroundColor: kCard,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'ホーム'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: '探す'),
          BottomNavigationBarItem(icon: Icon(Icons.emoji_events_outlined), activeIcon: Icon(Icons.emoji_events), label: 'ランキング'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'メッセージ'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'マイページ'),
        ],
      ),
      floatingActionButton: _idx == 0
          ? FloatingActionButton(
              backgroundColor: kPrimary,
              onPressed: () => _showPostSheet(context),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showPostSheet(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿にはログインが必要です')));
      return;
    }
    final userDoc = await FirebaseFirestore.instance.doc('users/\${user.uid}').get();
    final isPremium = userDoc.data()?['isPremium'] ?? false;
    final isAdmin = user.uid == kAdminUid;
    if (!isPremium && !isAdmin) {
      if (context.mounted) showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('プレミアム会員限定', style: TextStyle(fontWeight: FontWeight.w800)),
          content: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.star, color: kGold, size: 48),
            SizedBox(height: 12),
            Text('トピックの作成はプレミアム会員のみ利用できます。', textAlign: TextAlign.center),
            SizedBox(height: 8),
            Text('月額 ¥980 で無制限にトピックを作成できます。', style: TextStyle(fontSize: 12, color: kSoft), textAlign: TextAlign.center),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('閉じる')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kGold, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('プレミアムに登録 ¥980/月'),
            ),
          ],
        ),
      );
      return;
    }
    if (context.mounted) showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const PostTopicSheet(),
    );
  }
}

// ── ホーム画面 ─────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _filter = 'all';

  final _catTabs = [
    ('all', 'すべて'), ('sponsor', 'スポンサー'),
    ('経済・金融', '経済'), ('AI・テクノロジー', 'AI'),
    ('政治・社会', '政治'), ('未確認現象・予言', '予言'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7),
              gradient: const LinearGradient(colors: [kPrimary, Color(0xFF5C7CFA)]),
            ),
            child: CustomPaint(size: const Size(16, 16), painter: _MCLogoPainter()),
          ),
          const SizedBox(width: 8),
          RichText(text: const TextSpan(
            text: 'MC',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF1A1D29), letterSpacing: -.5),
            children: [TextSpan(text: ' forum', style: TextStyle(color: kPrimary))],
          )),
          const Spacer(),
          const _AuthButton(),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(84),
          child: Column(children: [
            TabBar(
              controller: _tabCtrl,
              labelColor: kPrimary,
              unselectedLabelColor: kFaint,
              indicatorColor: kPrimary,
              tabs: const [Tab(text: 'すべて'), Tab(text: 'フォロー中')],
            ),
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _catTabs.length,
                itemBuilder: (ctx, i) {
                  final on = _filter == _catTabs[i].$1;
                  return GestureDetector(
                    onTap: () => setState(() => _filter = _catTabs[i].$1),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8, bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                      decoration: BoxDecoration(
                        color: on ? kPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: on ? kPrimary : kBorder),
                      ),
                      child: Text(_catTabs[i].$2,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: on ? Colors.white : kFaint)),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _feedView(followingOnly: false),
          _feedView(followingOnly: true),
        ],
      ),
    );
  }

  Widget _feedView({required bool followingOnly}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (followingOnly && uid == null) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.group_outlined, size: 64, color: kFaint),
        const SizedBox(height: 12),
        const Text('ログインしてフォロー中の予測者を見る', style: TextStyle(color: kSoft, fontSize: 13)),
      ]));
    }

    if (followingOnly) {
      return FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('follows')
            .where('followerId', isEqualTo: uid)
            .get(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
          final followedUids = snap.data!.docs
              .map((d) => (d.data() as Map)['followeeId'] as String).toList();
          if (followedUids.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.group_add_outlined, size: 64, color: kFaint),
              const SizedBox(height: 12),
              const Text('まだ誰もフォローしていません', style: TextStyle(color: kSoft, fontSize: 13)),
            ]));
          }
          return _topicsStream(authorUidIn: followedUids);
        },
      );
    }

    return _topicsStream();
  }

  Widget _topicsStream({List<String>? authorUidIn}) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FutureBuilder<List<String>>(
      future: uid == null ? Future.value([]) :
        FirebaseFirestore.instance
          .collection('blocks')
          .where('blockerId', isEqualTo: uid)
          .get()
          .then((s) => s.docs.map((d) => (d.data())['blockedId'] as String).toList()),
      builder: (ctx, blockedSnap) {
        final blockedUids = blockedSnap.data ?? [];
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('topics')
              .orderBy('authorInfluenceScore', descending: true)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
            var docs = snap.data!.docs.map((d) => Topic.fromDoc(d)).toList();
            // ブロックユーザーのトピックを除外
            docs = docs.where((t) => !blockedUids.contains(t.authorUid)).toList();
            if (authorUidIn != null) {
              docs = docs.where((t) => authorUidIn.contains(t.authorUid)).toList();
            }
            if (_filter == 'sponsor') docs = docs.where((t) => t.sponsored).toList();
            else if (_filter != 'all') docs = docs.where((t) => t.category == _filter).toList();
            if (docs.isEmpty) return _emptyFeed();
            return ListView.builder(
              itemCount: docs.length,
              itemBuilder: (ctx, i) => TopicCard(topic: docs[i]),
            );
          },
        );
      },
    );
  }

  Widget _emptyFeed() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Icon(Icons.bar_chart, size: 64, color: kFaint),
    const SizedBox(height: 12),
    const Text('まだトピックがありません', style: TextStyle(color: kSoft, fontSize: 14)),
  ]));
}

// ── Auth ボタン ────────────────────────────────────────
class _AuthButton extends StatelessWidget {
  const _AuthButton();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.data != null) {
          return TextButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('ログアウト', style: TextStyle(fontSize: 11, color: kSoft)),
          );
        }
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kYes, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _signIn(ctx),
          child: const Text('🔑 ログイン'),
        );
      },
    );
  }

  Future<void> _signIn(BuildContext ctx) async {
    try {
      final gUser = await GoogleSignIn().signIn();
      if (gUser == null) return;
      final cred = await gUser.authentication;
      final ac = GoogleAuthProvider.credential(accessToken: cred.accessToken, idToken: cred.idToken);
      final res = await FirebaseAuth.instance.signInWithCredential(ac);
      final u = res.user!;
      final ref = FirebaseFirestore.instance.doc('users/${u.uid}');
      if (!(await ref.get()).exists) {
        await ref.set({
          'uid': u.uid, 'name': u.displayName, 'email': u.email,
          'color': '#3b5bdb', 'accuracy': 0, 'totalVotes': 0,
          'points': 1000, 'expertise': [], 'is_anonymous': false,
          'accuracy_by_category': {}, 'followerCount': 0,
          'followingCount': 0, 'influence_score': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('✓ ログインしました：${u.displayName}')));
    } catch (e) {
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('ログイン失敗：$e')));
    }
  }
}

// ── フォローボタン ─────────────────────────────────────
class FollowButton extends StatelessWidget {
  final String targetUid;
  final String targetName;
  const FollowButton({super.key, required this.targetUid, required this.targetName});

  Future<void> _toggle(BuildContext context, bool isFollowing) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('フォローにはログインが必要です')));
      return;
    }
    if (uid == targetUid) return;
    final followRef = FirebaseFirestore.instance.doc('follows/${uid}_$targetUid');
    if (isFollowing) {
      await followRef.delete();
      final myDoc = await FirebaseFirestore.instance.doc('users/$uid').get();
      if ((myDoc.data()?['followingCount'] ?? 0) > 0) {
        await FirebaseFirestore.instance.doc('users/$uid').update({'followingCount': FieldValue.increment(-1)});
      }
      final theirDoc = await FirebaseFirestore.instance.doc('users/$targetUid').get();
      if ((theirDoc.data()?['followerCount'] ?? 0) > 0) {
        await FirebaseFirestore.instance.doc('users/$targetUid').update({'followerCount': FieldValue.increment(-1)});
      }
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetName のフォローを解除しました')));
    } else {
      await followRef.set({'followerId': uid, 'followeeId': targetUid, 'createdAt': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance.doc('users/$uid').update({'followingCount': FieldValue.increment(1)});
      await FirebaseFirestore.instance.doc('users/$targetUid').update({'followerCount': FieldValue.increment(1)});
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$targetName をフォローしました ✓')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid == targetUid) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .doc('follows/${uid}_$targetUid')
          .snapshots(),
      builder: (ctx, snap) {
        final isFollowing = snap.data?.exists ?? false;
        return GestureDetector(
          onTap: () => _toggle(context, isFollowing),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isFollowing ? kBg : kPrimary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isFollowing ? kBorder : kPrimary),
            ),
            child: Text(
              isFollowing ? 'フォロー中' : 'フォロー',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: isFollowing ? kSoft : Colors.white),
            ),
          ),
        );
      },
    );
  }
}


// ── トピックカード ─────────────────────────────────────
class TopicCard extends StatefulWidget {
  final Topic topic;
  const TopicCard({super.key, required this.topic});
  @override
  State<TopicCard> createState() => _TopicCardState();
}

class _TopicCardState extends State<TopicCard> {
  String? _myVote;
  double _confidence = 70;
  bool _showConfidenceSlider = false;
  bool _showChangeReason = false;
  String? _pendingChange;
  bool _isAnonymous = false;

  @override
  void initState() {
    super.initState();
    _loadMyVote();
    _loadAnonymousMode();
  }

  Future<void> _loadMyVote() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .doc('predictions/${uid}_${widget.topic.id}').get();
    if (doc.exists && mounted) {
      setState(() {
        _myVote = doc.data()?['prediction_value'];
        _confidence = (doc.data()?['confidence'] ?? 70).toDouble();
      });
    }
  }

  Future<void> _loadAnonymousMode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.doc('users/$uid').get();
    if (doc.exists && mounted) {
      setState(() => _isAnonymous = doc.data()?['is_anonymous'] ?? false);
    }
  }

  Future<void> _castVote(String choice) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投票にはログインが必要です')));
      return;
    }
    await FirebaseFirestore.instance.doc('predictions/${uid}_${widget.topic.id}').set({
      'uid': uid, 'topicId': widget.topic.id,
      'category': widget.topic.category,
      'prediction_value': choice,
      'confidence': _confidence.round(),
      'is_anonymous': _isAnonymous,
      'initial_value': choice,
      'change_count': 0, 'history': [],
      'resolved': false,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance.doc('topics/${widget.topic.id}').update({
      '${choice}Count': FieldValue.increment(1),
    });
    await FirebaseFirestore.instance.doc('users/$uid').update({
      'totalVotes': FieldValue.increment(1),
      'points': FieldValue.increment(10),
    });
    if (mounted) setState(() { _myVote = choice; _showConfidenceSlider = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${choice == 'yes' ? '✓ YES' : '✓ NO'} で予測（確信度 ${_confidence.round()}%）')));
  }

  Future<void> _changeVote(String newChoice, String reason) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prev = _myVote!;
    await FirebaseFirestore.instance.doc('predictions/${uid}_${widget.topic.id}').update({
      'prediction_value': newChoice,
      'confidence': _confidence.round(),
      'change_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([{
        'from': prev, 'to': newChoice, 'reason': reason,
        'confidence_before': _confidence.round(),
        'timestamp': DateTime.now().toIso8601String(),
      }]),
    });
    await FirebaseFirestore.instance.doc('topics/${widget.topic.id}').update({
      '${prev}Count': FieldValue.increment(-1),
      '${newChoice}Count': FieldValue.increment(1),
    });
    await FirebaseFirestore.instance.doc('vote_velocity/${widget.topic.id}').set({
      'topicId': widget.topic.id, 'category': widget.topic.category,
      'totalChangers': FieldValue.increment(1),
      '${prev == 'yes' ? 'yesToNo' : 'noToYes'}': FieldValue.increment(1),
      'reasonBreakdown.$reason': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    if (mounted) setState(() { _myVote = newChoice; _showChangeReason = false; });
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('🔄 ${prev.toUpperCase()}→${newChoice.toUpperCase()}（$reason）')));
  }

  void _openUserProfile(BuildContext context, Topic t) {
    if (t.authorUid.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => UserProfileScreen(uid: t.authorUid, name: t.authorName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.topic;
    final tot = t.yesCount + t.noCount;
    final yp = tot > 0 ? t.yesCount / tot : 0.5;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: t.sponsored ? const Color(0xFFFFFBE6) : kCard,
        border: Border(bottom: BorderSide(color: kBorder.withOpacity(.5))),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (t.sponsored) _sponsorBar(t),
          if (t.resolved) _resolvedBanner(t),
          _juryBanner(t, context),
          _authorRow(context, t),
          const SizedBox(height: 8),
          Text(t.question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                height: 1.55, color: Color(0xFF1A1D29))),
          if (t.judgeCondition.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kBorder),
              ),
              child: Row(children: [
                const Icon(Icons.gavel, size: 11, color: kFaint),
                const SizedBox(width: 5),
                Expanded(child: Text('判定基準：${t.judgeCondition}',
                    style: const TextStyle(fontSize: 10, color: kSoft))),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          if (_myVote == null && !_showConfidenceSlider && !t.resolved) _voteButtons(),
          if (_myVote == null && _showConfidenceSlider && !t.resolved) _confidenceVotePanel(),
          if (_myVote != null) _resultBar(yp, tot),
          if (_myVote != null) _weightedScoreBar(t),
          if (_myVote != null && !_showChangeReason && !t.resolved) _changeButton(),
          if (_showChangeReason && !t.resolved) _reasonSheet(),
          _actionBar(t),
        ]),
      ),
    );
  }

  Widget _juryBanner(Topic t, BuildContext context) {
    if (t.category != '未確認現象・予言') return const SizedBox.shrink();
    if (t.resolved) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1a0533), Color(0xFF2d1465)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF7048E8).withOpacity(.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('🔮 ', style: TextStyle(fontSize: 16)),
          Text('オカルト大陪審', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB197FC))),
          Spacer(),
          Text('証拠を提出して判定に参加', style: TextStyle(fontSize: 9, color: Color(0xFF9775FA))),
        ]),
        const SizedBox(height: 8),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('topics').doc(t.id)
              .collection('evidence').snapshots(),
          builder: (ctx, snap) {
            final count = snap.data?.docs.length ?? 0;
            return Row(children: [
              Text('証拠 $count件提出済み',
                  style: const TextStyle(fontSize: 10, color: Color(0xFFCCC2FF))),
              const Spacer(),
              GestureDetector(
                onTap: () => _showEvidenceSheet(context, t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7048E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('証拠を提出 / 見る',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              ),
            ]);
          },
        ),
      ]),
    );
  }

  void _showEvidenceSheet(BuildContext context, Topic t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0d0f1a),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => EvidenceSheet(topic: t),
    );
  }

  Widget _resolvedBanner(Topic t) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: t.actualResult == 'yes' ? kYesBg : kNoBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: t.actualResult == 'yes' ? kYes : kNo),
    ),
    child: Row(children: [
      Icon(t.actualResult == 'yes' ? Icons.check_circle : Icons.cancel,
          size: 14, color: t.actualResult == 'yes' ? kYes : kNo),
      const SizedBox(width: 6),
      Text('結果確定：${t.actualResult == 'yes' ? 'YES（的中）' : 'NO（的中）'}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
              color: t.actualResult == 'yes' ? kYes : kNo)),
    ]),
  );

  Widget _sponsorBar(Topic t) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: kGoldBg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kGold.withOpacity(.3))),
    child: Row(children: [
      const Text('SPONSORED',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kGold, letterSpacing: 1)),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFE8A3))),
        child: Text('🎁 ¥${t.prize}',
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFB8860B))),
      ),
    ]),
  );

  Widget _authorRow(BuildContext context, Topic t) => Row(children: [
    GestureDetector(
      onTap: () => _openUserProfile(context, t),
      child: CircleAvatar(radius: 14, backgroundColor: kPrimary,
          child: Text(t.authorName.isNotEmpty ? t.authorName[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: GestureDetector(
        onTap: () => _openUserProfile(context, t),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(t.authorName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 5),
            if (t.authorInfluenceScore >= 50)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: t.authorInfluenceScore >= 100 ? kYesBg : kGoldBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  t.authorInfluenceScore >= 100 ? '🏆 Top予測者' : '⭐ 実績あり',
                  style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700,
                      color: t.authorInfluenceScore >= 100 ? kYes : kGold),
                ),
              ),
          ]),
          Text('${t.category} · 締切 ${t.deadline}',
              style: const TextStyle(fontSize: 9, color: kFaint)),
        ]),
      ),
    ),
    if (t.authorUid.isNotEmpty)
      FollowButton(targetUid: t.authorUid, targetName: t.authorName),
    const SizedBox(width: 4),
    IconButton(icon: const Icon(Icons.more_horiz, color: kFaint),
        onPressed: () => _showMenu(), padding: EdgeInsets.zero,
        constraints: const BoxConstraints()),
  ]);

  Widget _voteButtons() => Column(children: [
    Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: () => setState(() => _showConfidenceSlider = true),
        icon: const Icon(Icons.check, size: 16, color: kYes),
        label: const Text('そう思う', style: TextStyle(fontWeight: FontWeight.w700, color: kYes)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: kYes),
            padding: const EdgeInsets.symmetric(vertical: 10)),
      )),
      const SizedBox(width: 8),
      Expanded(child: OutlinedButton.icon(
        onPressed: () => setState(() => _showConfidenceSlider = true),
        icon: const Icon(Icons.close, size: 16, color: kNo),
        label: const Text('思わない', style: TextStyle(fontWeight: FontWeight.w700, color: kNo)),
        style: OutlinedButton.styleFrom(side: const BorderSide(color: kNo),
            padding: const EdgeInsets.symmetric(vertical: 10)),
      )),
    ]),
    const SizedBox(height: 4),
    const Text('タップして確信度を設定できます', style: TextStyle(fontSize: 10, color: kFaint)),
  ]);

  Widget _confidenceVotePanel() => Container(
    padding: const EdgeInsets.all(13),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('確信度を設定してください',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kSoft)),
        Text('${_confidence.round()}%',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimary)),
      ]),
      Slider(
        value: _confidence, min: 50, max: 100, divisions: 50,
        activeColor: _confidence >= 80 ? kYes : _confidence >= 65 ? kGold : kPrimary,
        onChanged: (v) => setState(() => _confidence = v),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
        Text('50%\nやや確信', style: TextStyle(fontSize: 9, color: kFaint, height: 1.4), textAlign: TextAlign.center),
        Text('75%\n確信', style: TextStyle(fontSize: 9, color: kFaint, height: 1.4), textAlign: TextAlign.center),
        Text('100%\n確実', style: TextStyle(fontSize: 9, color: kFaint, height: 1.4), textAlign: TextAlign.center),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Switch(value: _isAnonymous, onChanged: (v) => setState(() => _isAnonymous = v),
            activeColor: kPrimary, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        const SizedBox(width: 6),
        const Text('匿名で予測する', style: TextStyle(fontSize: 11, color: kSoft)),
        const Spacer(),
        const Text('（結果公開後に開示）', style: TextStyle(fontSize: 9, color: kFaint)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: ElevatedButton.icon(
          onPressed: () => _castVote('yes'),
          icon: const Icon(Icons.check, size: 16),
          label: const Text('YES で予測', style: TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: kYes, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11)),
        )),
        const SizedBox(width: 8),
        Expanded(child: ElevatedButton.icon(
          onPressed: () => _castVote('no'),
          icon: const Icon(Icons.close, size: 16),
          label: const Text('NO で予測', style: TextStyle(fontWeight: FontWeight.w700)),
          style: ElevatedButton.styleFrom(backgroundColor: kNo, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11)),
        )),
      ]),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => setState(() => _showConfidenceSlider = false),
        child: const Center(child: Text('キャンセル', style: TextStyle(fontSize: 11, color: kFaint))),
      ),
    ]),
  );

  Widget _weightedScoreBar(Topic t) {
    return FutureBuilder<Map<String, double>>(
      future: _calcAllScores(t.id, t.yesCount, t.noCount),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final weightedYesPct = snap.data!['weighted'] ?? 50;
        final debateYesPct = snap.data!['debate'] ?? 50;
        final simplePct = (t.yesCount + t.noCount) > 0
            ? t.yesCount / (t.yesCount + t.noCount) * 100
            : 50;
        final wDiff = (weightedYesPct - simplePct).toStringAsFixed(1);
        final dDiff = (debateYesPct - simplePct).toStringAsFixed(1);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF0FD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 重み付き集合知
            Row(children: [
              const Text('🧠 重み付き集合知',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary)),
              const Spacer(),
              Text('YES ${weightedYesPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
              const SizedBox(width: 4),
              _diffBadge(double.parse(wDiff)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: weightedYesPct / 100, minHeight: 4,
                  backgroundColor: kBorder,
                  valueColor: const AlwaysStoppedAnimation(kPrimary))),
            const SizedBox(height: 8),
            // 議論オッズ
            Row(children: [
              const Text('⚔️ 議論オッズ',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPur)),
              const Spacer(),
              Text('YES ${debateYesPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPur)),
              const SizedBox(width: 4),
              _diffBadge(double.parse(dDiff), color: kPur),
            ]),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(value: debateYesPct / 100, minHeight: 4,
                  backgroundColor: kBorder,
                  valueColor: const AlwaysStoppedAnimation(kPur))),
            const SizedBox(height: 4),
            const Text('議論の「納得」数で補正した確率',
                style: TextStyle(fontSize: 9, color: kFaint)),
          ]),
        );
      },
    );
  }

  Widget _diffBadge(double diff, {Color color = kPrimary}) {
    if (diff.abs() < 0.5) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(.1), borderRadius: BorderRadius.circular(4)),
      child: Text('${diff > 0 ? '+' : ''}${diff.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Future<Map<String, double>> _calcAllScores(String topicId, int yesCount, int noCount) async {
    final total = yesCount + noCount;
    final simplePct = total > 0 ? yesCount / total * 100 : 50.0;

    // 重み付きスコア計算
    final preds = await FirebaseFirestore.instance.collection('predictions').get();
    final topicPreds = preds.docs.where((d) => (d.data())['topicId'] == topicId).toList();

    double weightedYes = 0, weightedTotal = 0;
    for (final pred in topicPreds) {
      final data = pred.data();
      final uid = data['uid'] as String? ?? '';
      if (uid.isEmpty) continue;
      final vote = data['prediction_value'] as String? ?? '';
      final userDoc = await FirebaseFirestore.instance.doc('users/$uid').get();
      final influenceScore = (userDoc.data()?['influence_score'] ?? 0).toDouble();
      final weight = influenceScore > 0 ? influenceScore : 1.0;
      weightedTotal += weight;
      if (vote == 'yes') weightedYes += weight;
    }
    final weightedPct = weightedTotal > 0 ? (weightedYes / weightedTotal) * 100 : simplePct;

    // 議論オッズ計算
    final comments = await FirebaseFirestore.instance
        .collection('topics').doc(topicId).collection('comments').get();
    int yesLikes = 0, noLikes = 0;
    for (final c in comments.docs) {
      final d = c.data();
      final likes = (d['likes'] ?? 0) as int;
      if (d['stance'] == 'yes') yesLikes += likes;
      else noLikes += likes;
    }
    final likeDiff = (yesLikes - noLikes) * 0.5;
    final debatePct = (simplePct + likeDiff).clamp(5.0, 95.0);

    return {
      'weighted': weightedPct,
      'debate': debatePct,
    };
  }

  Widget _resultBar(double yp, int tot) => Column(children: [
    Stack(children: [
      ClipRRect(borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(value: yp, minHeight: 28, backgroundColor: kNoBg,
              valueColor: const AlwaysStoppedAnimation(kYesBg))),
      Positioned.fill(child: Row(children: [
        Padding(padding: const EdgeInsets.only(left: 10),
            child: Text('YES ${(yp * 100).round()}%',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kYes))),
        const Spacer(),
        Padding(padding: const EdgeInsets.only(right: 10),
            child: Text('${((1 - yp) * 100).round()}% NO',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kNo))),
      ])),
    ]),
    const SizedBox(height: 6),
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('$tot人が予測', style: const TextStyle(fontSize: 10, color: kFaint)),
      Row(children: [
        Text('あなた: ${_myVote == 'yes' ? 'YES' : 'NO'} ',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(4),
              border: Border.all(color: kBorder)),
          child: Text('確信度 ${_confidence.round()}%',
              style: const TextStyle(fontSize: 9, color: kSoft, fontWeight: FontWeight.w600)),
        ),
      ]),
    ]),
    const SizedBox(height: 8),
  ]);

  Widget _changeButton() => GestureDetector(
    onTap: () => setState(() {
      _showChangeReason = true;
      _pendingChange = _myVote == 'yes' ? 'no' : 'yes';
    }),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: const Color(0xFFF1F3F7),
          borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
      child: Text('🔄 ${_myVote == 'yes' ? 'NOに変更する' : 'YESに変更する'}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: _myVote == 'yes' ? kNo : kYes)),
    ),
  );

  Widget _reasonSheet() => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('変更する理由は？',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kSoft)),
      const SizedBox(height: 8),
      Wrap(spacing: 7, runSpacing: 7, children: [
        _reasonChip('📰 新情報が出た', '新情報が出た'),
        _reasonChip('👥 多数派に合わせた', '多数派に合わせた'),
        _reasonChip('📱 SNSトレンド', 'SNSトレンドを見た'),
        _reasonChip('🎓 専門家の意見', '専門家の意見を読んだ'),
        _reasonChip('📊 経済指標', '経済指標が変わった'),
        _reasonChip('💭 直感が変わった', '直感が変わった'),
      ]),
      const SizedBox(height: 8),
      TextButton(onPressed: () => _changeVote(_pendingChange!, '理由なし'),
          child: const Text('理由なしで変更する', style: TextStyle(fontSize: 11, color: kFaint))),
    ]),
  );

  Widget _reasonChip(String label, String value) => GestureDetector(
    onTap: () => _changeVote(_pendingChange!, value),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder)),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kSoft)),
    ),
  );

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => CommentsSheet(topicId: widget.topic.id, myVote: _myVote),
    );
  }

  Widget _actionBar(Topic t) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isAdmin = uid == kAdminUid;
    return Row(children: [
      _abtn(Icons.favorite_border, '${t.yesCount}', () {}),
      StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('topics').doc(widget.topic.id)
            .collection('comments').snapshots(),
        builder: (ctx, snap) {
          final count = snap.data?.docs.length ?? 0;
          return _abtn(Icons.chat_bubble_outline,
              count > 0 ? '$count' : '',
              () => _openComments(context));
        },
      ),
      _abtn(Icons.share, 'シェア',
              () => Share.share('MC forum: ${t.question}\nhttps://mcforum.vercel.app')),
      if (isAdmin && !t.resolved)
        TextButton(
          onPressed: () => _showResultDialog(t),
          child: const Text('結果入力', style: TextStyle(fontSize: 11, color: kGold, fontWeight: FontWeight.w700)),
        ),
      if (isAdmin && t.resolved)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: kYesBg, borderRadius: BorderRadius.circular(6)),
          child: const Text('判定済み', style: TextStyle(fontSize: 10, color: kYes, fontWeight: FontWeight.w700)),
        ),
    ]);
  }

  Widget _abtn(IconData icon, String label, VoidCallback onTap) => TextButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 15, color: kFaint),
    label: Text(label, style: const TextStyle(fontSize: 11, color: kFaint)),
    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
  );

  Future<void> _showResultDialog(Topic t) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('結果を入力', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(t.question, style: const TextStyle(fontSize: 12, color: kSoft)),
          const SizedBox(height: 16),
          const Text('実際の結果は？', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kYes, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _resolveTopicAndUpdateScores(t, 'yes');
              },
              child: const Text('YES が的中'),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kNo, foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _resolveTopicAndUpdateScores(t, 'no');
              },
              child: const Text('NO が的中'),
            )),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('キャンセル')),
        ],
      ),
    );
  }

  Future<void> _resolveTopicAndUpdateScores(Topic t, String result) async {
    if (!mounted) return;
    try {
      // 1. トピックを結果確定
      await FirebaseFirestore.instance.doc('topics/${t.id}').update({
        'resolved': true,
        'actualResult': result,
      });

      // 2. 全predictionsを取得してフィルター（インデックス不要）
      final allPreds = await FirebaseFirestore.instance
          .collection('predictions').get();
      final preds = allPreds.docs.where((d) =>
          (d.data())['topicId'] == t.id).toList();

      // 3. 各ユーザーのスコアを更新
      for (final pred in preds) {
        final data = pred.data();
        final uid = data['uid'] as String? ?? '';
        if (uid.isEmpty) continue;
        final vote = data['prediction_value'] as String? ?? '';
        final category = data['category'] as String? ?? t.category;
        final isCorrect = vote == result;
        await pred.reference.update({'resolved': true});

        // 確信度連動ボーナスポイント
        if (isCorrect) {
          final confidence = (data['confidence'] ?? 50) as int;
          int bonusPt = 10; // 基本
          if (confidence >= 90) bonusPt = 50;
          else if (confidence >= 80) bonusPt = 40;
          else if (confidence >= 70) bonusPt = 30;
          else if (confidence >= 60) bonusPt = 20;
          await FirebaseFirestore.instance.doc('users/$uid').update({
            'points': FieldValue.increment(bonusPt),
          });
        }

        final userRef = FirebaseFirestore.instance.doc('users/$uid');
        final userDoc = await userRef.get();
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData == null) continue;

        final acc = Map<String, dynamic>.from(userData['accuracy_by_category'] ?? {});
        final catData = Map<String, dynamic>.from(
            acc[category] != null ? Map<String, dynamic>.from(acc[category] as Map)
            : {'correct': 0, 'total': 0});
        catData['total'] = ((catData['total'] ?? 0) as int) + 1;
        if (isCorrect) catData['correct'] = ((catData['correct'] ?? 0) as int) + 1;
        acc[category] = catData;

        int totalCorrect = 0, totalAll = 0;
        for (final cat in acc.values) {
          final m = cat as Map;
          totalCorrect += (m['correct'] ?? 0) as int;
          totalAll += (m['total'] ?? 0) as int;
        }
        final accuracy = totalAll > 0 ? totalCorrect / totalAll : 0.0;
        final influenceScore = accuracy * (1 + totalAll * 0.1) * 100;

        await userRef.update({
          'accuracy_by_category': acc,
          'influence_score': influenceScore,
        });

        final userTopics = await FirebaseFirestore.instance
            .collection('topics').where('authorUid', isEqualTo: uid).get();
        for (final topic in userTopics.docs) {
          await topic.reference.update({'authorInfluenceScore': influenceScore});
        }
      }

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              '✅ 結果確定：${result.toUpperCase()}が的中。${preds.length}件のスコアを更新しました')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー：$e')));
    }
  }
  void _showMenu() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 6),
      Container(width: 36, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 12),
      ListTile(
        leading: const Icon(Icons.person_outline),
        title: const Text('プロフィールを見る'),
        onTap: () {
          Navigator.pop(ctx);
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => UserProfileScreen(uid: widget.topic.authorUid, name: widget.topic.authorName),
          ));
        },
      ),
      ListTile(
        leading: const Icon(Icons.block, color: kNo),
        title: const Text('ブロックする', style: TextStyle(color: kNo)),
        onTap: () async {
          Navigator.pop(ctx);
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) return;
          final targetUid = widget.topic.authorUid;
          if (targetUid.isEmpty) return;
          await FirebaseFirestore.instance
              .doc('blocks/${uid}_$targetUid')
              .set({'blockerId': uid, 'blockedId': targetUid,
                    'createdAt': FieldValue.serverTimestamp()});
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${widget.topic.authorName} をブロックしました')));
        },
      ),
      ListTile(
        leading: const Icon(Icons.flag_outlined, color: kNo),
        title: const Text('報告する', style: TextStyle(color: kNo)),
        onTap: () => Navigator.pop(ctx),
      ),
      const SizedBox(height: 16),
    ]),
  );
}

// ── トピック投稿シート ─────────────────────────────────
class PostTopicSheet extends StatefulWidget {
  const PostTopicSheet({super.key});
  @override
  State<PostTopicSheet> createState() => _PostTopicSheetState();
}

class _PostTopicSheetState extends State<PostTopicSheet> {
  final _q = TextEditingController();
  final _judge = TextEditingController();
  String _cat = '経済・金融';
  String _deadline = '2026年12月末';
  bool _loading = false;

  Future<void> _post() async {
    if (_q.text.trim().isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _loading = true);
    final userDoc = await FirebaseFirestore.instance.doc('users/$uid').get();
    final influenceScore = (userDoc.data()?['influence_score'] ?? 0).toDouble();
    await FirebaseFirestore.instance.collection('topics').add({
      'question': _q.text.trim(), 'category': _cat, 'deadline': _deadline,
      'judgeCondition': _judge.text.trim(),
      'authorUid': uid, 'authorName': userDoc.data()?['name'] ?? '',
      'authorInfluenceScore': influenceScore,
      'sponsored': false, 'prize': 0, 'yesCount': 0, 'noCount': 0,
      'commentCount': 0, 'resolved': false, 'actualResult': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 予測トピックを投稿しました')));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 14),
          const Text('予測トピックを作成', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _cat,
            decoration: const InputDecoration(labelText: 'カテゴリ', border: OutlineInputBorder()),
            items: kExpertiseTags.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
            onChanged: (v) => setState(() => _cat = v!),
          ),
          const SizedBox(height: 12),
          TextField(controller: _q, maxLines: 3, maxLength: 100,
            decoration: const InputDecoration(
              labelText: '質問文（YES/NOで答えられる形式）', border: OutlineInputBorder(),
              hintText: '例：〇〇は2026年末までに△△を達成しますか？',
            )),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _deadline,
            decoration: const InputDecoration(labelText: '締切', border: OutlineInputBorder()),
            items: ['2026年9月末', '2026年12月末', '2027年3月末']
                .map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
            onChanged: (v) => setState(() => _deadline = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _judge,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: '判定基準（任意）',
              border: OutlineInputBorder(),
              hintText: '例：防衛省が公式発表した場合YES',
              helperText: '何が起きたらYES/NOと判定するかを明確に',
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: _loading ? null : _post,
              child: _loading
                  ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                  : const Text('投稿する', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── 探す画面 ───────────────────────────────────────────
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('探す', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(children: [
        Padding(padding: const EdgeInsets.all(14),
          child: TextField(decoration: InputDecoration(
            hintText: 'トピック・ユーザーを検索...',
            prefixIcon: const Icon(Icons.search, color: kFaint),
            filled: true, fillColor: const Color(0xFFF1F3F7),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
          ))),
        const Padding(padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
            child: Text('🔥 今急上昇', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kFaint, letterSpacing: 1))),
        ...[
          ('日銀は2026年内に追加利上げを行う？', '経済 · 2,847人が予測'),
          ('W杯で日本はグループリーグを突破する？', 'スポーツ · 5,201人が予測'),
          ('iPhone 18はAI機能を日本語完全対応する？', 'テクノロジー · 1,923人が予測'),
        ].asMap().entries.map((e) => ListTile(
          leading: Text('${e.key + 1}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: kPrimary)),
          title: Text(e.value.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          subtitle: Text(e.value.$2, style: const TextStyle(fontSize: 10, color: kFaint)),
        )),
        const Padding(padding: EdgeInsets.fromLTRB(14, 16, 14, 8),
            child: Text('📁 専門領域から探す', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kFaint, letterSpacing: 1))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
          child: GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 2.5,
            children: [
              _catCard(context, '💹 経済・金融', '経済・金融', kYesBg, kYes),
              _catCard(context, '🤖 AI・テクノロジー', 'AI・テクノロジー', const Color(0xFFEDF0FD), kPrimary),
              _catCard(context, '🏛 政治・社会', '政治・社会', const Color(0xFFF3EFFE), kPur),
              _catCard(context, '🔮 未確認現象・予言', '未確認現象・予言', const Color(0xFFE0F7FA), const Color(0xFF006064)),
            ],
          )),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _catCard(BuildContext context, String label, String category, Color bg, Color fg) =>
    GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => CategoryTopicsScreen(category: category, label: label),
      )),
      child: Container(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
        child: Center(child: Text(label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)))));
}

// ── メッセージ画面（Firestore連動） ───────────────────────
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  void _showUserSearch(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインが必要です')));
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => UserSearchSheet(onSelect: (uid, name) {
        Navigator.pop(context);
        _openChat(context, uid, name);
      }),
    );
  }

  void _openChat(BuildContext context, String partnerUid, String partnerName) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('メッセージにはログインが必要です')));
      return;
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatScreen(partnerUid: partnerUid, partnerName: partnerName),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('メッセージ', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () => _showUserSearch(context),
          ),
        ],
      ),
      body: uid == null
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: kFaint),
              const SizedBox(height: 12),
              const Text('ログインしてメッセージを使う', style: TextStyle(color: kSoft, fontSize: 13)),
            ]))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('follows')
                  .where('followerId', isEqualTo: uid)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
                final follows = snap.data!.docs;
                if (follows.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.group_outlined, size: 64, color: kFaint),
                    const SizedBox(height: 12),
                    const Text('フォロー中のユーザーがいません', style: TextStyle(color: kSoft, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text('ホームでユーザーをフォローしましょう', style: TextStyle(color: kFaint, fontSize: 11)),
                  ]));
                }
                return ListView.builder(
                  itemCount: follows.length,
                  itemBuilder: (ctx, i) {
                    final data = follows[i].data() as Map<String, dynamic>;
                    final followeeUid = data['followeeId'] as String;
                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.doc('users/$followeeUid').get(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const SizedBox(height: 60);
                        final user = snap.data!.data() as Map<String, dynamic>?;
                        if (user == null) return const SizedBox.shrink();
                        final name = user['name'] ?? 'ユーザー';
                        return ListTile(
                          onTap: () => _openChat(context, followeeUid, name),
                          leading: CircleAvatar(backgroundColor: kPrimary,
                              child: Text(name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                          title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          subtitle: const Text('タップしてメッセージを送る',
                              style: TextStyle(fontSize: 11, color: kFaint)),
                          trailing: const Icon(Icons.chevron_right, color: kFaint),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}

// ── マイページ ─────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        final user = snap.data;
        if (user == null) return _notLoggedIn(ctx);
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.doc('users/${user.uid}').snapshots(),
          builder: (ctx, snap) {
            final data = snap.data?.data() as Map<String, dynamic>?;
            return DefaultTabController(
              length: 3,
              child: Scaffold(
                appBar: AppBar(toolbarHeight: 0),
                body: Column(children: [
                  // 常に表示されるプロフィールヘッダー
                  Container(
                    color: kCard,
                    child: Column(children: [
                      _profileHeader(ctx, user, data),
                      _statRow(data),
                      const Divider(height: 1),
                      const TabBar(
                        labelColor: kPrimary,
                        unselectedLabelColor: kFaint,
                        indicatorColor: kPrimary,
                        tabs: [
                          Tab(text: '投票履歴'),
                          Tab(text: '分野別精度'),
                          Tab(text: '設定'),
                        ],
                      ),
                    ]),
                  ),
                  // タブコンテンツ
                  Expanded(
                    child: TabBarView(children: [
                      _historyTab(ctx, user, data),
                      _accuracyTab(data),
                      _settingsTab(ctx, user, data),
                    ]),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Widget _notLoggedIn(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: const Text('マイページ', style: TextStyle(fontWeight: FontWeight.w800))),
    body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.person_outline, size: 64, color: kFaint),
      const SizedBox(height: 16),
      const Text('ログインしてマイページを表示', style: TextStyle(color: kSoft, fontSize: 14)),
      const SizedBox(height: 20),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13)),
        onPressed: () async {
          try {
            final gUser = await GoogleSignIn().signIn();
            if (gUser == null) return;
            final cred = await gUser.authentication;
            final ac = GoogleAuthProvider.credential(accessToken: cred.accessToken, idToken: cred.idToken);
            await FirebaseAuth.instance.signInWithCredential(ac);
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('ログイン失敗：$e')));
          }
        },
        child: const Text('🔑 Googleでログイン', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    ])),
  );

  Widget _historyTab(BuildContext ctx, User user, Map<String, dynamic>? data) => ListView(children: [
    const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text('最近の予測', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
    _historyItem('日銀は2026年内に追加利上げを行う？', 'YES', '結果待ち', Colors.grey, 70),
    _historyItem('米国の利下げは年内に2回以上？', 'YES', '的中 +10pt', kYes, 85),
    _historyItem('ビットコインは15万ドルを超える？', 'NO', '外れ', kNo, 60),
    const SizedBox(height: 80),
  ]);

  Widget _accuracyTab(Map<String, dynamic>? data) {
    final acc = data?['accuracy_by_category'] as Map<String, dynamic>? ?? {};
    return ListView(children: [
      Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(14), border: Border.all(color: kBorder)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('カテゴリ別の的中率', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          SizedBox(height: 4),
          Text('予測数が多いほど精度が信頼できます', style: TextStyle(fontSize: 11, color: kFaint)),
        ]),
      ),
      if (acc.isEmpty) const Padding(
        padding: EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.bar_chart, size: 48, color: kFaint),
          SizedBox(height: 12),
          Text('まだカテゴリ別データがありません', style: TextStyle(color: kSoft, fontSize: 13)),
        ]),
      ),
      ...kExpertiseTags.map((cat) {
        final catData = acc[cat] as Map<String, dynamic>?;
        final correct = catData?['correct'] ?? 0;
        final total = catData?['total'] ?? 0;
        final rate = total > 0 ? correct / total : 0.0;
        return _accuracyRow(cat, rate, total);
      }),
      const SizedBox(height: 80),
    ]);
  }

  Widget _accuracyRow(String category, double rate, int total) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
    child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        Row(children: [
          Text('${(rate * 100).round()}%',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                  color: rate >= 0.7 ? kYes : rate >= 0.5 ? kGold : kNo)),
          Text(' / $total予測', style: const TextStyle(fontSize: 11, color: kFaint)),
        ]),
      ]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: rate, minHeight: 6, backgroundColor: kBorder,
              valueColor: AlwaysStoppedAnimation(rate >= 0.7 ? kYes : rate >= 0.5 ? kGold : kNo))),
    ]),
  );

  Widget _settingsTab(BuildContext ctx, User user, Map<String, dynamic>? data) {
    final expertise = List<String>.from(data?['expertise'] ?? []);
    final isAnonymous = data?['is_anonymous'] ?? false;
    return ListView(children: [
      const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('専門領域（複数選択可）', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
      const Padding(padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text('あなたの専門領域の予測は重み付けに反映されます', style: TextStyle(fontSize: 11, color: kFaint))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: kExpertiseTags.map((tag) {
          final selected = expertise.contains(tag);
          return GestureDetector(
            onTap: () async {
              final newList = selected
                  ? expertise.where((e) => e != tag).toList()
                  : [...expertise, tag];
              await FirebaseFirestore.instance.doc('users/${user.uid}').update({'expertise': newList});
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text(selected ? '$tag を削除' : '$tag を追加')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? kPrimary : kCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? kPrimary : kBorder),
              ),
              child: Text(tag, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : kSoft)),
            ),
          );
        }).toList()),
      ),
      const SizedBox(height: 20),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(12), border: Border.all(color: kBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('匿名予測モード', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('オンにすると予測が匿名で表示されます', style: TextStyle(fontSize: 11, color: kFaint)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(isAnonymous ? '匿名ON' : '匿名OFF',
                style: TextStyle(color: isAnonymous ? kPrimary : kSoft, fontWeight: FontWeight.w700)),
            Switch(value: isAnonymous, activeColor: kPrimary,
                onChanged: (v) async {
                  await FirebaseFirestore.instance.doc('users/${user.uid}').update({'is_anonymous': v});
                }),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kGoldBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGold.withOpacity(.3))),
        child: Row(children: [
          const Text('🎁 保有ポイント',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFB8860B))),
          const Spacer(),
          Text('${data?['points'] ?? 1000} pt',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kGold)),
        ]),
      ),
      const SizedBox(height: 20),
      // プレミアム会員登録
      _premiumSection(ctx, user, data),
      const SizedBox(height: 80),
    ]);
  }

  Widget _premiumSection(BuildContext ctx, User user, Map<String, dynamic>? data) {
    final isPremium = data?['isPremium'] ?? false;
    if (isPremium) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF664d00), Color(0xFF3d2e00)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kGold.withOpacity(.5)),
        ),
        child: const Row(children: [
          Text('⭐', style: TextStyle(fontSize: 24)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('プレミアム会員', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kGold)),
            Text('トピック作成・全機能が利用可能です', style: TextStyle(fontSize: 11, color: Color(0xFFFFD470))),
          ])),
        ]),
      );
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kGoldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGold.withOpacity(.3)),
      ),
      child: Column(children: [
        const Row(children: [
          Text('⭐', style: TextStyle(fontSize: 24)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('プレミアム会員', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFFB8860B))),
            Text('月額 ¥980 でトピック作成が可能になります', style: TextStyle(fontSize: 11, color: kSoft)),
          ])),
        ]),
        const SizedBox(height: 12),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Column(children: [
          _PremiumFeatureRow(icon: '🎯', text: 'トピック作成（無制限）'),
          _PremiumFeatureRow(icon: '📊', text: '集合知データへの優先アクセス'),
          _PremiumFeatureRow(icon: '🔔', text: '結果確定の即時通知'),
        ])),
        const SizedBox(height: 14),
        SizedBox(width: double.infinity, child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: kGold, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          onPressed: () {
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('準備中です。近日公開予定！')));
          },
          child: const Text('プレミアムに登録する ¥980/月',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        )),
      ]),
    );
  }

  Widget _profileHeader(BuildContext ctx, User user, Map<String, dynamic>? data) {
    final isPremium = data?['isPremium'] ?? false;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Column(children: [
        // ボタン行（上部）
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          GestureDetector(
            onTap: () => _shareProphetCard(ctx, user, data),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1a0533),
                border: Border.all(color: kPur.withOpacity(.4)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text('🔮 シェア',
                  style: TextStyle(fontSize: 10, color: Color(0xFFB197FC), fontWeight: FontWeight.w700)),
            ),
          ),
          GestureDetector(
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('ログアウトしました')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: kNo.withOpacity(.3)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.logout, size: 11, color: kNo),
                SizedBox(width: 3),
                Text('ログアウト', style: TextStyle(fontSize: 10, color: kNo, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        // 中央：アイコン・名前・称号
        GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => ProfileEditScreen(user: user, data: data),
          )),
          child: Stack(alignment: Alignment.bottomRight, children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: _parseColor(data?['color'] ?? '#3b5bdb'),
              child: Text(
                (data?['name'] ?? user.displayName ?? '?').isNotEmpty
                    ? (data?['name'] ?? user.displayName ?? '?')[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            Container(width: 16, height: 16,
              decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
              child: const Icon(Icons.edit, color: Colors.white, size: 9)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(data?['name'] ?? user.displayName ?? 'ユーザー',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (isPremium) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFf59f00), Color(0xFFe67700)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('⭐ Premium',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
            ),
          ],
        ]),
        const SizedBox(height: 2),
        Text(getTitleFromUserData(data), style: const TextStyle(fontSize: 10, color: kFaint)),
        if (data?['bio'] != null && (data!['bio'] as String).isNotEmpty)
          Text(data['bio'], style: const TextStyle(fontSize: 11, color: kSoft),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
      ]),
    );
  }
  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return kPrimary;
    }
  }

  void _shareProphetCard(BuildContext ctx, User user, Map<String, dynamic>? data) {
    if (data == null) return;
    final name = data['name'] ?? user.displayName ?? 'ユーザー';
    final totalVotes = data['totalVotes'] ?? 0;
    final influenceScore = (data['influence_score'] ?? 0.0).toDouble();
    final accuracy = totalVotes > 0
        ? (influenceScore / (1 + totalVotes * 0.1) / 100 * 100).toStringAsFixed(0)
        : '0';
    final title = getTitleFromUserData(data);
    final expertise = List<String>.from(data['expertise'] ?? []);
    final topExpertise = expertise.isNotEmpty ? expertise.first : '';
    final expertiseLine = topExpertise.isNotEmpty ? '\n専門：$topExpertise' : '';
    final shareText = '🔮 MC forum 予言者カード\n\n'
        '$title\n\n'
        '$name\n'
        '的中率 ${accuracy}%$expertiseLine\n'
        '予測数 ${totalVotes}件\n\n'
        'Twitterは予測を流す場所。\n'
        'ここは予測を証明する場所。\n\n'
        '▶ https://mcforum.vercel.app\n'
        '#MC_forum #予測SNS #集合知';
    Share.share(shareText);
  }

  Widget _statRow(Map<String, dynamic>? data) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      _stat('${data?['totalVotes'] ?? 0}', '予測', kPrimary),
      _stat('${data?['points'] ?? 1000}pt', 'ポイント', kGold),
      _stat('${data?['followerCount'] ?? 0}', 'フォロワー', kYes),
      _stat('${data?['followingCount'] ?? 0}', 'フォロー中', kSoft),
    ]),
  );

  Widget _stat(String v, String l, Color c) => Column(children: [
    Text(v, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
    Text(l, style: const TextStyle(fontSize: 10, color: kFaint)),
  ]);

  Widget _historyItem(String q, String vote, String result, Color color, int confidence) => ListTile(
    leading: Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    title: Text(q, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    subtitle: Row(children: [
      Container(margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: vote == 'YES' ? kYesBg : kNoBg, borderRadius: BorderRadius.circular(4)),
          child: Text(vote, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: vote == 'YES' ? kYes : kNo))),
      const SizedBox(width: 5),
      Container(margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: kBorder)),
          child: Text('確信度 $confidence%', style: const TextStyle(fontSize: 9, color: kSoft))),
      const SizedBox(width: 5),
      Padding(padding: const EdgeInsets.only(top: 4),
          child: Text(result, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w600))),
    ]),
  );
}

// ── ユーザープロフィール画面 ───────────────────────────
class UserProfileScreen extends StatelessWidget {
  final String uid;
  final String name;
  const UserProfileScreen({super.key, required this.uid, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.doc('users/$uid').get(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
          final data = snap.data!.data() as Map<String, dynamic>?;
          if (data == null) return const Center(child: Text('ユーザーが見つかりません'));
          return ListView(children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: kCard,
              child: Column(children: [
                CircleAvatar(radius: 40, backgroundColor: kPrimary,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700))),
                const SizedBox(height: 12),
                Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(getTitleFromUserData(data), style: const TextStyle(fontSize: 12, color: kFaint)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  FollowButton(targetUid: uid, targetName: name),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final me = FirebaseAuth.instance.currentUser?.uid;
                      if (me == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('ログインが必要です')));
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ChatScreen(partnerUid: uid, partnerName: name),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: kYesBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kYes),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.chat_bubble_outline, size: 14, color: kYes),
                        SizedBox(width: 5),
                        Text('メッセージ', style: TextStyle(fontSize: 11,
                            fontWeight: FontWeight.w700, color: kYes)),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .doc('blocks/${FirebaseAuth.instance.currentUser?.uid}_$uid')
                        .snapshots(),
                    builder: (ctx, snap) {
                      final isBlocked = snap.data?.exists ?? false;
                      return GestureDetector(
                        onTap: () async {
                          final me = FirebaseAuth.instance.currentUser?.uid;
                          if (me == null) return;
                          if (isBlocked) {
                            await FirebaseFirestore.instance
                                .doc('blocks/${me}_$uid').delete();
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$name のブロックを解除しました')));
                          } else {
                            await FirebaseFirestore.instance
                                .doc('blocks/${me}_$uid')
                                .set({'blockerId': me, 'blockedId': uid,
                                      'createdAt': FieldValue.serverTimestamp()});
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$name をブロックしました')));
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isBlocked ? kNoBg : kBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isBlocked ? kNo : kBorder),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.block, size: 14, color: isBlocked ? kNo : kFaint),
                            const SizedBox(width: 5),
                            Text(isBlocked ? 'ブロック中' : 'ブロック',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                    color: isBlocked ? kNo : kFaint)),
                          ]),
                        ),
                      );
                    },
                  ),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _stat('${data['totalVotes'] ?? 0}', '予測'),
                  _stat('${data['followerCount'] ?? 0}', 'フォロワー'),
                  _stat('${data['followingCount'] ?? 0}', 'フォロー中'),
                ]),
              ]),
            ),
            const Divider(height: 1),
            if ((data['expertise'] as List?)?.isNotEmpty == true) ...[
              const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('専門領域', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(spacing: 8, runSpacing: 8,
                    children: (data['expertise'] as List).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: kBrs, borderRadius: BorderRadius.circular(16)),
                      child: Text(tag.toString(),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPrimary)),
                    )).toList()),
              ),
              const SizedBox(height: 16),
            ],
            const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('最近の予測', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800))),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('topics')
                  .where('authorUid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox(height: 60);
                final topics = snap.data!.docs;
                if (topics.isEmpty) return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('まだ予測がありません', style: TextStyle(color: kFaint, fontSize: 12)),
                );
                return Column(children: topics.map((doc) {
                  final t = Topic.fromDoc(doc);
                  return ListTile(
                    title: Text(t.question,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    subtitle: Text('${t.category} · YES ${t.yesCount} / NO ${t.noCount}',
                        style: const TextStyle(fontSize: 10, color: kFaint)),
                    trailing: t.resolved
                        ? const Icon(Icons.check_circle, color: kYes, size: 16)
                        : const Icon(Icons.access_time, color: kFaint, size: 16),
                  );
                }).toList());
              },
            ),
            const SizedBox(height: 80),
          ]);
        },
      ),
    );
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimary)),
    Text(l, style: const TextStyle(fontSize: 10, color: kFaint)),
  ]);
}

// ── チャット画面（Firestore連動） ───────────────────────
class ChatScreen extends StatefulWidget {
  final String partnerUid;
  final String partnerName;
  const ChatScreen({super.key, required this.partnerUid, required this.partnerName});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String _chatId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  Future<void> _send() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_ctrl.text.trim().isEmpty) return;
    final text = _ctrl.text.trim();
    _ctrl.clear();
    final chatId = _chatId(uid, widget.partnerUid);
    await FirebaseFirestore.instance
        .collection('chats').doc(chatId).collection('messages')
        .add({
      'text': text, 'senderId': uid, 'receiverId': widget.partnerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final chatId = _chatId(uid, widget.partnerUid);
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16, backgroundColor: kPrimary,
              child: Text(widget.partnerName[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Text(widget.partnerName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('chats').doc(chatId).collection('messages')
                .orderBy('createdAt', descending: false).snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
              final msgs = snap.data!.docs;
              if (msgs.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.chat_bubble_outline, size: 48, color: kFaint),
                  const SizedBox(height: 12),
                  Text('${widget.partnerName} にメッセージを送る',
                      style: const TextStyle(color: kSoft, fontSize: 13)),
                ]));
              }
              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(14),
                itemCount: msgs.length,
                itemBuilder: (ctx, i) {
                  final m = msgs[i].data() as Map<String, dynamic>;
                  final isMe = m['senderId'] == uid;
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: isMe ? kPrimary : kCard,
                        borderRadius: BorderRadius.circular(16),
                        border: isMe ? null : Border.all(color: kBorder),
                      ),
                      child: Text(m['text'] ?? '',
                          style: TextStyle(fontSize: 13, color: isMe ? Colors.white : kSoft)),
                    ),
                  );
                },
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: kCard, border: Border(top: BorderSide(color: kBorder))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'メッセージを入力...',
                filled: true, fillColor: const Color(0xFFF1F3F7),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: Container(
                width: 44, height: 44,
                decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── プロフィール編集画面 ────────────────────────────────
class ProfileEditScreen extends StatefulWidget {
  final User user;
  final Map<String, dynamic>? data;
  const ProfileEditScreen({super.key, required this.user, required this.data});
  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _bioCtrl;
  String _selectedColor = '#3b5bdb';
  String? _selectedAge;
  String? _selectedGender;
  String? _selectedPref;
  String? _selectedJob;
  bool _loading = false;

  final _colors = [
    '#3b5bdb', '#0ca678', '#e8590c', '#f59f00',
    '#7048e8', '#e64980', '#1098ad', '#2f9e44',
    '#1a1d29', '#495057',
  ];

  final _ageOptions = ['10代', '20代', '30代', '40代', '50代', '60代以上'];
  final _genderOptions = ['男性', '女性', 'その他', '回答しない'];
  final _jobOptions = ['会社員', '経営者・役員', '公務員', '自営業・フリーランス',
      '学生', '研究者・教員', '医療・福祉', '金融・保険', 'IT・エンジニア', 'その他'];
  final _prefOptions = ['北海道', '青森', '岩手', '宮城', '秋田', '山形', '福島',
      '茨城', '栃木', '群馬', '埼玉', '千葉', '東京', '神奈川', '新潟', '富山',
      '石川', '福井', '山梨', '長野', '岐阜', '静岡', '愛知', '三重', '滋賀',
      '京都', '大阪', '兵庫', '奈良', '和歌山', '鳥取', '島根', '岡山', '広島',
      '山口', '徳島', '香川', '愛媛', '高知', '福岡', '佐賀', '長崎', '熊本',
      '大分', '宮崎', '鹿児島', '沖縄', '海外在住'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.data?['name'] ?? widget.user.displayName ?? '');
    _bioCtrl = TextEditingController(text: widget.data?['bio'] ?? '');
    _selectedColor = widget.data?['color'] ?? '#3b5bdb';
    _selectedAge = widget.data?['age'];
    _selectedGender = widget.data?['gender'];
    _selectedPref = widget.data?['prefecture'];
    _selectedJob = widget.data?['job'];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return kPrimary;
    }
  }

  void _shareProphetCard(BuildContext ctx, User user, Map<String, dynamic>? data) {
    if (data == null) return;
    final name = data['name'] ?? user.displayName ?? 'ユーザー';
    final totalVotes = data['totalVotes'] ?? 0;
    final influenceScore = (data['influence_score'] ?? 0.0).toDouble();
    final accuracy = totalVotes > 0
        ? (influenceScore / (1 + totalVotes * 0.1) / 100 * 100).toStringAsFixed(0)
        : '0';
    final title = getTitleFromUserData(data);
    final expertise = List<String>.from(data['expertise'] ?? []);
    final topExpertise = expertise.isNotEmpty ? expertise.first : '';

    final expertiseLine = topExpertise.isNotEmpty ? '\n専門：$topExpertise' : '';
    final shareText = '🔮 MC forum 予言者カード\n\n'
        '$title\n\n'
        '$name\n'
        '的中率 \${accuracy}%\$expertiseLine\n'
        '予測数 \${totalVotes}件\n\n'
        'Twitterは予測を流す場所。\n'
        'ここは予測を証明する場所。\n\n'
        '▶ https://mcforum.vercel.app\n'
        '#MC_forum #予測SNS #集合知';

    Share.share(shareText);
  }

  bool get _isAttributeComplete =>
      _selectedAge != null && _selectedGender != null &&
      _selectedPref != null && _selectedJob != null;

  bool get _wasAttributeComplete =>
      widget.data?['age'] != null && widget.data?['gender'] != null &&
      widget.data?['prefecture'] != null && widget.data?['job'] != null;

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);

    final updates = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'color': _selectedColor,
      if (_selectedAge != null) 'age': _selectedAge,
      if (_selectedGender != null) 'gender': _selectedGender,
      if (_selectedPref != null) 'prefecture': _selectedPref,
      if (_selectedJob != null) 'job': _selectedJob,
    };

    // 段階的ボーナス計算
    int bonusPoints = 0;
    final prevData = widget.data ?? {};

    // ステップ1：年齢＋性別（初回）
    if (_selectedAge != null && _selectedGender != null &&
        prevData['age'] == null && prevData['gender'] == null) {
      bonusPoints += 100;
      updates['step1Completed'] = true;
    }
    // ステップ2：都道府県（初回）
    if (_selectedPref != null && prevData['prefecture'] == null) {
      bonusPoints += 100;
      updates['step2Completed'] = true;
    }
    // ステップ3：職業（初回）
    if (_selectedJob != null && prevData['job'] == null) {
      bonusPoints += 100;
      updates['step3Completed'] = true;
    }

    if (bonusPoints > 0) {
      updates['points'] = FieldValue.increment(bonusPoints) as Object;
    }

    await FirebaseFirestore.instance.doc('users/${widget.user.uid}').update(updates);

    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
      final msg = bonusPoints > 0
          ? '✅ プロフィールを更新しました！ +${bonusPoints}pt 🎉'
          : '✅ プロフィールを更新しました';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: const Text('保存', style: TextStyle(
                color: kPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // アイコンプレビュー
        Center(child: Column(children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: _parseColor(_selectedColor),
            child: Text(
              _nameCtrl.text.isNotEmpty ? _nameCtrl.text[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 36,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          const Text('アイコンカラーを選択',
              style: TextStyle(fontSize: 12, color: kFaint)),
        ])),
        const SizedBox(height: 20),

        // カラー選択
        Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center,
          children: _colors.map((c) => GestureDetector(
            onTap: () => setState(() => _selectedColor = c),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _parseColor(c),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedColor == c ? Colors.white : Colors.transparent,
                  width: 3,
                ),
                boxShadow: _selectedColor == c ? [
                  BoxShadow(color: _parseColor(c).withOpacity(.5),
                      blurRadius: 8, spreadRadius: 2)
                ] : null,
              ),
              child: _selectedColor == c
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          )).toList(),
        ),
        const SizedBox(height: 28),

        // 名前
        const Text('表示名', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtrl,
          maxLength: 30,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '表示名を入力',
            counterText: '',
          ),
        ),
        const SizedBox(height: 20),

        // 自己紹介
        const Text('自己紹介', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextField(
          controller: _bioCtrl,
          maxLines: 3,
          maxLength: 100,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '専門分野や予測スタイルを教えてください',
          ),
        ),
        const SizedBox(height: 24),

        // 属性情報ボーナスバナー
        if (!_wasAttributeComplete) Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: kGoldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kGold.withOpacity(.4)),
          ),
          child: Row(children: [
            const Text('🎁', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('属性情報を入力して 最大+300pt',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFB8860B))),
              Text('年齢・性別で+100pt、都道府県で+100pt、職業で+100pt（各初回のみ）',
                  style: TextStyle(fontSize: 10, color: kSoft)),
            ])),
          ]),
        ),
        if (!_wasAttributeComplete) const SizedBox(height: 20),

        // 属性情報
        const Text('属性情報（任意・最大+300pt）',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('予測精度の重み付けに使用されます。企業向けデータとして活用されます。',
            style: TextStyle(fontSize: 10, color: kFaint)),
        const SizedBox(height: 12),

        // 年齢
        DropdownButtonFormField<String>(
          value: _selectedAge,
          decoration: const InputDecoration(labelText: '年齢', border: OutlineInputBorder()),
          items: _ageOptions.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
          onChanged: (v) => setState(() => _selectedAge = v),
        ),
        const SizedBox(height: 12),

        // 性別
        DropdownButtonFormField<String>(
          value: _selectedGender,
          decoration: const InputDecoration(labelText: '性別', border: OutlineInputBorder()),
          items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
          onChanged: (v) => setState(() => _selectedGender = v),
        ),
        const SizedBox(height: 12),

        // 都道府県
        DropdownButtonFormField<String>(
          value: _selectedPref,
          decoration: const InputDecoration(labelText: '都道府県', border: OutlineInputBorder()),
          items: _prefOptions.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setState(() => _selectedPref = v),
        ),
        const SizedBox(height: 12),

        // 職業
        DropdownButtonFormField<String>(
          value: _selectedJob,
          decoration: const InputDecoration(labelText: '職業', border: OutlineInputBorder()),
          items: _jobOptions.map((j) => DropdownMenuItem(value: j, child: Text(j))).toList(),
          onChanged: (v) => setState(() => _selectedJob = v),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _loading ? null : _save,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('保存する',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ── コメントシート（議論バトル版） ───────────────────────
class CommentsSheet extends StatefulWidget {
  final String topicId;
  final String? myVote;
  const CommentsSheet({super.key, required this.topicId, this.myVote});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String _stance = 'yes'; // yes or no

  @override
  void initState() {
    super.initState();
    _stance = widget.myVote ?? 'yes';
  }

  Future<void> _post() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('コメントにはログインが必要です')));
      return;
    }
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final userDoc = await FirebaseFirestore.instance.doc('users/$uid').get();
    await FirebaseFirestore.instance
        .collection('topics').doc(widget.topicId)
        .collection('comments').add({
      'uid': uid,
      'authorName': userDoc.data()?['name'] ?? '',
      'text': _ctrl.text.trim(),
      'stance': _stance,
      'likes': 0,
      'likedBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .doc('topics/${widget.topicId}')
        .update({'commentCount': FieldValue.increment(1)});
    _ctrl.clear();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _likeComment(String commentId, List likedBy) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('topics').doc(widget.topicId)
        .collection('comments').doc(commentId);
    if (likedBy.contains(uid)) {
      await ref.update({
        'likes': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'likes': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
              color: kCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kBorder))),
          child: Column(children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('議論バトル', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('「納得」を集めた意見はオッズが上がります',
                style: TextStyle(fontSize: 10, color: kFaint)),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('topics').doc(widget.topicId)
                .collection('comments')
                .orderBy('likes', descending: true)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
              final comments = snap.data!.docs;
              final myUid = FirebaseAuth.instance.currentUser?.uid;

              if (comments.isEmpty) {
                return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.forum_outlined, size: 48, color: kFaint),
                  const SizedBox(height: 12),
                  const Text('まだ意見がありません', style: TextStyle(color: kSoft, fontSize: 13)),
                  const SizedBox(height: 8),
                  const Text('最初の意見を投稿してみましょう！', style: TextStyle(color: kFaint, fontSize: 11)),
                ]));
              }

              final yesComments = comments.where((d) => (d.data() as Map)['stance'] == 'yes').toList();
              final noComments = comments.where((d) => (d.data() as Map)['stance'] == 'no').toList();

              return ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(14),
                children: [
                  // YES側
                  if (yesComments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: kYesBg, borderRadius: BorderRadius.circular(6)),
                      child: Text('✓ YES派の意見 (${yesComments.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kYes)),
                    ),
                    const SizedBox(height: 8),
                    ...yesComments.map((doc) => _commentItem(doc, myUid, kYes, kYesBg)),
                    const SizedBox(height: 16),
                  ],
                  // NO側
                  if (noComments.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: kNoBg, borderRadius: BorderRadius.circular(6)),
                      child: Text('✗ NO派の意見 (${noComments.length})',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNo)),
                    ),
                    const SizedBox(height: 8),
                    ...noComments.map((doc) => _commentItem(doc, myUid, kNo, kNoBg)),
                  ],
                ],
              );
            },
          ),
        ),
        Container(
          padding: EdgeInsets.only(
              left: 14, right: 14, top: 10,
              bottom: MediaQuery.of(context).viewInsets.bottom + 10),
          decoration: BoxDecoration(color: kCard,
              border: Border(top: BorderSide(color: kBorder))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // YES/NO スタンス選択
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _stance = 'yes'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _stance == 'yes' ? kYes : kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _stance == 'yes' ? kYes : kBorder),
                  ),
                  child: Text('✓ YES派として投稿',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _stance == 'yes' ? Colors.white : kFaint)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _stance = 'no'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _stance == 'no' ? kNo : kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _stance == 'no' ? kNo : kBorder),
                  ),
                  child: Text('✗ NO派として投稿',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: _stance == 'no' ? Colors.white : kFaint)),
                ),
              )),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: '根拠を入力...「納得」を集めるとオッズUP！',
                  filled: true, fillColor: const Color(0xFFF1F3F7),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              )),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _loading ? null : _post,
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _stance == 'yes' ? kYes : kNo,
                    shape: BoxShape.circle,
                  ),
                  child: _loading
                      ? const Padding(padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send, color: Colors.white, size: 18),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _commentItem(DocumentSnapshot doc, String? myUid, Color stanceColor, Color stanceBg) {
    final c = doc.data() as Map<String, dynamic>;
    final likes = c['likes'] ?? 0;
    final likedBy = List<String>.from(c['likedBy'] ?? []);
    final isLiked = myUid != null && likedBy.contains(myUid);
    final name = c['authorName'] ?? '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 14, backgroundColor: stanceColor,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: stanceBg, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: stanceColor.withOpacity(.2))),
            child: Text(c['text'] ?? '',
                style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D29))),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _likeComment(doc.id, likedBy),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 14, color: isLiked ? kPrimary : kFaint),
              const SizedBox(width: 4),
              Text('納得 $likes',
                  style: TextStyle(fontSize: 10, color: isLiked ? kPrimary : kFaint,
                      fontWeight: isLiked ? FontWeight.w700 : FontWeight.normal)),
            ]),
          ),
        ])),
      ]),
    );
  }
}

// ── ユーザー検索シート ─────────────────────────────────
class UserSearchSheet extends StatefulWidget {
  final void Function(String uid, String name) onSelect;
  const UserSearchSheet({super.key, required this.onSelect});
  @override
  State<UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends State<UserSearchSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    final me = FirebaseAuth.instance.currentUser?.uid;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('name')
        .startAt([query])
        .endAt(['$query'])
        .limit(20)
        .get();
    final results = snap.docs
        .where((d) => d.id != me)
        .map((d) => {'uid': d.id, ...d.data()})
        .toList();
    if (mounted) setState(() { _results = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          const Text('ユーザーを検索', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'ユーザー名を入力...',
              prefixIcon: const Icon(Icons.search, color: kFaint),
              filled: true, fillColor: const Color(0xFFF1F3F7),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
            ),
            onChanged: _search,
          ),
          const SizedBox(height: 12),
          Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: kPrimary))
              : _results.isEmpty
                  ? const Center(child: Text('ユーザーが見つかりません',
                      style: TextStyle(color: kFaint, fontSize: 13)))
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (ctx, i) {
                        final u = _results[i];
                        final name = u['name'] ?? 'ユーザー';
                        return ListTile(
                          onTap: () => widget.onSelect(u['uid'], name),
                          leading: CircleAvatar(backgroundColor: kPrimary,
                              child: Text(name[0].toUpperCase(),
                                  style: const TextStyle(color: Colors.white,
                                      fontWeight: FontWeight.w700))),
                          title: Text(name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          trailing: const Icon(Icons.chevron_right, color: kFaint),
                        );
                      },
                    )),
        ]),
      ),
    );
  }
}

// ── オカルト大陪審：証拠シート ───────────────────────────
class EvidenceSheet extends StatefulWidget {
  final Topic topic;
  const EvidenceSheet({super.key, required this.topic});
  @override
  State<EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends State<EvidenceSheet> {
  final _urlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _verdict = 'true'; // true or false
  bool _loading = false;

  Future<void> _submit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログインが必要です')));
      return;
    }
    if (_descCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    final userDoc = await FirebaseFirestore.instance.doc('users/$uid').get();
    await FirebaseFirestore.instance
        .collection('topics').doc(widget.topic.id)
        .collection('evidence').add({
      'uid': uid,
      'authorName': userDoc.data()?['name'] ?? '',
      'description': _descCtrl.text.trim(),
      'url': _urlCtrl.text.trim(),
      'verdict': _verdict,
      'votes': 0,
      'votedBy': [],
      'createdAt': FieldValue.serverTimestamp(),
    });
    _urlCtrl.clear();
    _descCtrl.clear();
    if (mounted) setState(() => _loading = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ 証拠を提出しました')));
  }

  Future<void> _voteEvidence(String evId, List votedBy, String verdict) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = FirebaseFirestore.instance
        .collection('topics').doc(widget.topic.id)
        .collection('evidence').doc(evId);
    if (votedBy.contains(uid)) {
      await ref.update({'votes': FieldValue.increment(-1), 'votedBy': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'votes': FieldValue.increment(1), 'votedBy': FieldValue.arrayUnion([uid])});
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0d0f1a),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF141728),
              border: Border(bottom: BorderSide(color: const Color(0xFF252A45))),
            ),
            child: Column(children: [
              Container(width: 36, height: 4,
                  decoration: BoxDecoration(color: const Color(0xFF252A45),
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('🔮 ', style: TextStyle(fontSize: 20)),
                Text('オカルト大陪審', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFB197FC))),
              ]),
              const SizedBox(height: 4),
              Text(widget.topic.question,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9775FA)),
                  textAlign: TextAlign.center),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('topics').doc(widget.topic.id)
                  .collection('evidence')
                  .orderBy('votes', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF7048E8)));
                final evidences = snap.data!.docs;
                final myUid = FirebaseAuth.instance.currentUser?.uid;

                final trueEv = evidences.where((d) => (d.data() as Map)['verdict'] == 'true').toList();
                final falseEv = evidences.where((d) => (d.data() as Map)['verdict'] == 'false').toList();
                final trueVotes = trueEv.fold<int>(0, (s, d) => s + ((d.data() as Map)['votes'] ?? 0) as int);
                final falseVotes = falseEv.fold<int>(0, (s, d) => s + ((d.data() as Map)['votes'] ?? 0) as int);
                final total = trueVotes + falseVotes;

                return ListView(controller: scrollCtrl, padding: const EdgeInsets.all(16), children: [
                  // 大陪審スコア
                  if (total > 0) Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1a0533), Color(0xFF2d1465)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      const Text('大陪審スコア', style: TextStyle(fontSize: 11, color: Color(0xFF9775FA), fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: Column(children: [
                          Text('${total > 0 ? (trueVotes / total * 100).toStringAsFixed(0) : 0}%',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF51CF66))),
                          const Text('予言的中', style: TextStyle(fontSize: 10, color: Color(0xFF8CE99A))),
                        ])),
                        Container(width: 1, height: 40, color: const Color(0xFF252A45)),
                        Expanded(child: Column(children: [
                          Text('${total > 0 ? (falseVotes / total * 100).toStringAsFixed(0) : 0}%',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFFFF6B6B))),
                          const Text('予言外れ', style: TextStyle(fontSize: 10, color: Color(0xFFFFB8B8))),
                        ])),
                      ]),
                    ]),
                  ),

                  // 的中側の証拠
                  if (trueEv.isNotEmpty) ...[
                    const Text('✅ 的中の証拠', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF51CF66))),
                    const SizedBox(height: 8),
                    ...trueEv.map((doc) => _evidenceItem(doc, myUid, const Color(0xFF51CF66))),
                    const SizedBox(height: 16),
                  ],
                  // 外れ側の証拠
                  if (falseEv.isNotEmpty) ...[
                    const Text('❌ 外れの証拠', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFF6B6B))),
                    const SizedBox(height: 8),
                    ...falseEv.map((doc) => _evidenceItem(doc, myUid, const Color(0xFFFF6B6B))),
                    const SizedBox(height: 16),
                  ],

                  if (evidences.isEmpty) Center(child: Column(children: [
                    const SizedBox(height: 40),
                    const Text('🔮', style: TextStyle(fontSize: 48)),
                    const SizedBox(height: 12),
                    const Text('まだ証拠がありません', style: TextStyle(color: Color(0xFF9775FA), fontSize: 13)),
                    const Text('最初の証拠を提出してください', style: TextStyle(color: Color(0xFF4A5278), fontSize: 11)),
                  ])),
                ]);
              },
            ),
          ),
          // 証拠投稿フォーム
          Container(
            padding: EdgeInsets.only(
                left: 16, right: 16, top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12),
            decoration: const BoxDecoration(
              color: Color(0xFF141728),
              border: Border(top: BorderSide(color: Color(0xFF252A45))),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _verdict = 'true'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _verdict == 'true' ? const Color(0xFF2B8A3E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _verdict == 'true' ? const Color(0xFF51CF66) : const Color(0xFF252A45)),
                    ),
                    child: Text('✅ 的中の証拠', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _verdict == 'true' ? const Color(0xFF51CF66) : const Color(0xFF4A5278))),
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _verdict = 'false'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _verdict == 'false' ? const Color(0xFF862E2E) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _verdict == 'false' ? const Color(0xFFFF6B6B) : const Color(0xFF252A45)),
                    ),
                    child: Text('❌ 外れの証拠', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: _verdict == 'false' ? const Color(0xFFFF6B6B) : const Color(0xFF4A5278))),
                  ),
                )),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'ニュースURL（任意）',
                  hintStyle: const TextStyle(color: Color(0xFF4A5278), fontSize: 12),
                  filled: true, fillColor: const Color(0xFF1A1E35),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextField(
                  controller: _descCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: '証拠の説明を入力...',
                    hintStyle: const TextStyle(color: Color(0xFF4A5278), fontSize: 12),
                    filled: true, fillColor: const Color(0xFF1A1E35),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _loading ? null : _submit,
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: Color(0xFF7048E8), shape: BoxShape.circle),
                    child: _loading
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _evidenceItem(DocumentSnapshot doc, String? myUid, Color color) {
    final e = doc.data() as Map<String, dynamic>;
    final votes = e['votes'] ?? 0;
    final votedBy = List<String>.from(e['votedBy'] ?? []);
    final isVoted = myUid != null && votedBy.contains(myUid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF141728),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 10, backgroundColor: color,
              child: Text((e['authorName'] ?? '?')[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          Text(e['authorName'] ?? '', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          const Spacer(),
          GestureDetector(
            onTap: () => _voteEvidence(doc.id, votedBy, e['verdict']),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isVoted ? Icons.how_to_vote : Icons.how_to_vote_outlined,
                  size: 14, color: isVoted ? color : const Color(0xFF4A5278)),
              const SizedBox(width: 3),
              Text('$votes', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: isVoted ? color : const Color(0xFF4A5278))),
            ]),
          ),
        ]),
        const SizedBox(height: 6),
        Text(e['description'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFFCCC2FF))),
        if ((e['url'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(e['url'], style: const TextStyle(fontSize: 10, color: Color(0xFF7048E8),
              decoration: TextDecoration.underline)),
        ],
      ]),
    );
  }
}

class _PremiumFeatureRow extends StatelessWidget {
  final String icon;
  final String text;
  const _PremiumFeatureRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(children: [
      Text(icon, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 8),
      Text(text, style: const TextStyle(fontSize: 12, color: kSoft)),
    ]),
  );
}

// ── カテゴリトピック一覧画面 ─────────────────────────────
class CategoryTopicsScreen extends StatelessWidget {
  final String category;
  final String label;
  const CategoryTopicsScreen({super.key, required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('topics')
            .where('category', isEqualTo: category)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator(color: kPrimary));
          final topics = snap.data!.docs.map((d) => Topic.fromDoc(d)).toList();
          if (topics.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.bar_chart, size: 64, color: kFaint),
              const SizedBox(height: 12),
              Text('$labelのトピックはまだありません',
                  style: const TextStyle(color: kSoft, fontSize: 14)),
            ]));
          }
          return ListView.builder(
            itemCount: topics.length,
            itemBuilder: (ctx, i) => TopicCard(topic: topics[i]),
          );
        },
      ),
    );
  }
}

// ── ランキング画面 ────────────────────────────────────
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});
  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ランキング', style: TextStyle(fontWeight: FontWeight.w800)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: kPrimary,
          unselectedLabelColor: kFaint,
          indicatorColor: kPrimary,
          isScrollable: true,
          tabs: const [
            Tab(text: '総合'),
            Tab(text: '経済・金融'),
            Tab(text: 'AI・テクノロジー'),
            Tab(text: '政治・社会'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _rankingList(null),
          _rankingList('経済・金融'),
          _rankingList('AI・テクノロジー'),
          _rankingList('政治・社会'),
        ],
      ),
    );
  }

  Widget _rankingList(String? category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('influence_score', descending: true)
          .limit(50)
          .snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
        var users = snap.data!.docs
            .map((d) => d.data() as Map<String, dynamic>)
            .where((u) => (u['influence_score'] ?? 0) > 0)
            .toList();

        if (category != null) {
          users = users.where((u) {
            final acc = u['accuracy_by_category'] as Map?;
            if (acc == null) return false;
            return acc.containsKey(category);
          }).toList();

          users.sort((a, b) {
            final accA = (a['accuracy_by_category'] as Map?)?[category] as Map?;
            final accB = (b['accuracy_by_category'] as Map?)?[category] as Map?;
            final scoreA = accA != null && (accA['total'] ?? 0) > 0
                ? (accA['correct'] ?? 0) / (accA['total'] ?? 1) : 0.0;
            final scoreB = accB != null && (accB['total'] ?? 0) > 0
                ? (accB['correct'] ?? 0) / (accB['total'] ?? 1) : 0.0;
            return scoreB.compareTo(scoreA);
          });
        }

        if (users.isEmpty) {
          return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: kFaint),
            SizedBox(height: 12),
            Text('まだランキングデータがありません', style: TextStyle(color: kSoft, fontSize: 13)),
            SizedBox(height: 8),
            Text('予測して的中率を積み上げましょう', style: TextStyle(color: kFaint, fontSize: 11)),
          ]));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: users.length,
          itemBuilder: (ctx, i) {
            final u = users[i];
            final name = u['name'] ?? 'ユーザー';
            final influenceScore = (u['influence_score'] ?? 0.0).toDouble();
            final totalVotes = u['totalVotes'] ?? 0;
            final expertise = List<String>.from(u['expertise'] ?? []);

            double displayScore = influenceScore;
            if (category != null) {
              final acc = (u['accuracy_by_category'] as Map?)?[category] as Map?;
              if (acc != null && (acc['total'] ?? 0) > 0) {
                displayScore = (acc['correct'] ?? 0) / (acc['total'] ?? 1) * 100;
              }
            }

            final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}';

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: i < 3 ? [
                  const Color(0xFFFFF8E6),
                  const Color(0xFFF5F5F5),
                  const Color(0xFFFFF3EE),
                ][i] : kCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i < 3 ? [kGold, kBorder, kNo.withOpacity(.3)][i] : kBorder),
              ),
              child: Row(children: [
                SizedBox(width: 32, child: Text(medal,
                    style: TextStyle(fontSize: i < 3 ? 22 : 14, fontWeight: FontWeight.w800,
                        color: i < 3 ? [kGold, kSoft, kNo][i] : kFaint),
                    textAlign: TextAlign.center)),
                const SizedBox(width: 10),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: _parseColor(u['color'] ?? '#3b5bdb'),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  if (expertise.isNotEmpty)
                    Text(expertise.take(2).join(' · '),
                        style: const TextStyle(fontSize: 10, color: kFaint)),
                  Text(getTitleFromUserData(u), style: const TextStyle(fontSize: 10, color: kFaint)),
                  Text('\$totalVotes予測', style: const TextStyle(fontSize: 10, color: kFaint)),
                ])),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${displayScore.toStringAsFixed(1)}pt',
                      style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800,
                        color: i == 0 ? kGold : i == 1 ? kSoft : i == 2 ? kNo : kPrimary,
                      )),
                  Text(category == null ? '影響力スコア' : '的中率',
                      style: const TextStyle(fontSize: 9, color: kFaint)),
                ]),
              ]),
            );
          },
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return kPrimary; }
  }
}

// ── MC Logo Painter ────────────────────────────────────
class _MCLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    final w = size.width / 24;
    final h = size.height / 24;
    path.moveTo(4*w, 18*h);
    path.lineTo(4*w, 8*h);
    path.lineTo(8*w, 13*h);
    path.lineTo(12*w, 6*h);
    path.lineTo(16*w, 13*h);
    path.lineTo(20*w, 8*h);
    path.lineTo(20*w, 18*h);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}