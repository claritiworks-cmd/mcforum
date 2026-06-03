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
const kAdminUid = 'OnAJ7rXVRbZ3k58VwfDabaFcY1k2';

const kExpertiseTags = [
  'AI・機械学習', '暗号資産・Web3', 'テクノロジー',
  '経済・金融', '政治・社会', 'スポーツ',
  'エンタメ', 'ヘルスケア', '環境・エネルギー',
  '未確認現象・予言',
];

class Topic {
  final String id, question, category, authorName, authorUid, deadline;
  final bool sponsored;
  final int prize, yesCount, noCount;
  final bool resolved;
  final String? actualResult;
  final double authorInfluenceScore;

  Topic({
    required this.id, required this.question, required this.category,
    required this.authorName, required this.authorUid, required this.deadline,
    this.sponsored = false, this.prize = 0,
    this.yesCount = 0, this.noCount = 0,
    this.resolved = false, this.actualResult,
    this.authorInfluenceScore = 0,
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
  final _pages = const [HomeScreen(), SearchScreen(), MessagesScreen(), ProfileScreen()];

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

  void _showPostSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('投稿にはログインが必要です')));
      return;
    }
    showModalBottomSheet(
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
    ('経済・金融', '経済'), ('AI・機械学習', 'AI'),
    ('暗号資産・Web3', '暗号資産'), ('政治・社会', '政治'),
    ('スポーツ', 'スポーツ'), ('エンタメ', 'エンタメ'),
    ('未確認現象・予言', '予言'),
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
          _authorRow(context, t),
          const SizedBox(height: 8),
          Text(t.question,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                height: 1.55, color: Color(0xFF1A1D29))),
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
      future: _calcWeightedScore(t.id),
      builder: (ctx, snap) {
        if (!snap.hasData) return const SizedBox.shrink();
        final weightedYesPct = snap.data!['yes'] ?? 50;
        final simplePct = (t.yesCount + t.noCount) > 0
            ? t.yesCount / (t.yesCount + t.noCount) * 100
            : 50;
        final diff = (weightedYesPct - simplePct).toStringAsFixed(1);
        final diffColor = weightedYesPct > simplePct ? kYes : kNo;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFEDF0FD),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('🧠 重み付き集合知',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary)),
              const Spacer(),
              Text('YES ${weightedYesPct.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPrimary)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: diffColor.withOpacity(.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${weightedYesPct > simplePct ? '+' : ''}$diff%',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: diffColor),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: weightedYesPct / 100,
                minHeight: 5,
                backgroundColor: kBorder,
                valueColor: const AlwaysStoppedAnimation(kPrimary),
              ),
            ),
            const SizedBox(height: 4),
            const Text('的中率の高い予測者の意見を重視した確率',
                style: TextStyle(fontSize: 9, color: kFaint)),
          ]),
        );
      },
    );
  }

  Future<Map<String, double>> _calcWeightedScore(String topicId) async {
    final preds = await FirebaseFirestore.instance
        .collection('predictions')
        .get();
    final topicPreds = preds.docs
        .where((d) => (d.data())['topicId'] == topicId)
        .toList();
    if (topicPreds.isEmpty) return {'yes': 50, 'no': 50};

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
    if (weightedTotal == 0) return {'yes': 50, 'no': 50};
    final yesPct = (weightedYes / weightedTotal) * 100;
    return {'yes': yesPct, 'no': 100 - yesPct};
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
      builder: (_) => CommentsSheet(topicId: widget.topic.id),
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
              _catCard('🤖 AI・機械学習', const Color(0xFFEDF0FD), kPrimary),
              _catCard('🪙 暗号資産・Web3', kGoldBg, kGold),
              _catCard('💹 経済・金融', kYesBg, kYes),
              _catCard('⚽ スポーツ', kNoBg, kNo),
              _catCard('🏛 政治・社会', const Color(0xFFF3EFFE), kPur),
              _catCard('💻 テクノロジー', const Color(0xFFFDEEF4), const Color(0xFFE64980)),
              _catCard('🔮 未確認現象・予言', const Color(0xFFE0F7FA), const Color(0xFF006064)),
            ],
          )),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _catCard(String label, Color bg, Color fg) => Container(
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
    child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg))));
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
      const SizedBox(height: 80),
    ]);
  }

  Widget _profileHeader(BuildContext ctx, User user, Map<String, dynamic>? data) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
    child: Column(children: [
      // 上部：編集・ログアウトボタン
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        GestureDetector(
          onTap: () => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => ProfileEditScreen(user: user, data: data),
          )),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: kBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('編集', style: TextStyle(fontSize: 11, color: kSoft, fontWeight: FontWeight.w600)),
          ),
        ),
        GestureDetector(
          onTap: () async {
            await FirebaseAuth.instance.signOut();
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('ログアウトしました')));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: kNo.withOpacity(.4)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.logout, size: 12, color: kNo),
              SizedBox(width: 4),
              Text('ログアウト', style: TextStyle(fontSize: 11, color: kNo, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      // 中央：アイコン・名前・ランク
      GestureDetector(
        onTap: () => Navigator.push(ctx, MaterialPageRoute(
          builder: (_) => ProfileEditScreen(user: user, data: data),
        )),
        child: Stack(alignment: Alignment.bottomRight, children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: _parseColor(data?['color'] ?? '#3b5bdb'),
            child: Text(
              (data?['name'] ?? user.displayName ?? '?').isNotEmpty
                  ? (data?['name'] ?? user.displayName ?? '?')[0].toUpperCase() : '?',
              style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700),
            ),
          ),
          Container(
            width: 22, height: 22,
            decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            child: const Icon(Icons.edit, color: Colors.white, size: 12),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Text(data?['name'] ?? user.displayName ?? 'ユーザー',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      if (data?['bio'] != null && (data!['bio'] as String).isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(data['bio'],
              style: const TextStyle(fontSize: 11, color: kSoft),
              maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
        ),
      const Text('🥈 分析家ランク', style: TextStyle(fontSize: 12, color: kFaint)),
    ]),
  );

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return kPrimary;
    }
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
                const Text('🥈 分析家ランク', style: TextStyle(fontSize: 12, color: kFaint)),
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
  bool _loading = false;

  final _colors = [
    '#3b5bdb', '#0ca678', '#e8590c', '#f59f00',
    '#7048e8', '#e64980', '#1098ad', '#2f9e44',
    '#1a1d29', '#495057',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
        text: widget.data?['name'] ?? widget.user.displayName ?? '');
    _bioCtrl = TextEditingController(text: widget.data?['bio'] ?? '');
    _selectedColor = widget.data?['color'] ?? '#3b5bdb';
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _loading = true);
    await FirebaseFirestore.instance.doc('users/${widget.user.uid}').update({
      'name': _nameCtrl.text.trim(),
      'bio': _bioCtrl.text.trim(),
      'color': _selectedColor,
    });
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ プロフィールを更新しました')));
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

// ── コメントシート ─────────────────────────────────────
class CommentsSheet extends StatefulWidget {
  final String topicId;
  const CommentsSheet({super.key, required this.topicId});
  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _ctrl = TextEditingController();
  bool _loading = false;

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
      'createdAt': FieldValue.serverTimestamp(),
    });
    await FirebaseFirestore.instance
        .doc('topics/${widget.topicId}')
        .update({'commentCount': FieldValue.increment(1)});
    _ctrl.clear();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: kCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kBorder))),
          child: Column(children: [
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            const Text('コメント', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('topics').doc(widget.topicId)
                .collection('comments')
                .orderBy('createdAt', descending: false)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kPrimary));
              final comments = snap.data!.docs;
              if (comments.isEmpty) {
                return const Center(child: Text('まだコメントがありません',
                    style: TextStyle(color: kFaint, fontSize: 13)));
              }
              return ListView.builder(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(14),
                itemCount: comments.length,
                itemBuilder: (ctx, i) {
                  final c = comments[i].data() as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      CircleAvatar(radius: 14, backgroundColor: kPrimary,
                          child: Text(
                            (c['authorName'] ?? '?').isNotEmpty
                                ? c['authorName'][0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontSize: 11,
                                fontWeight: FontWeight.w700),
                          )),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c['authorName'] ?? '',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F7),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(c['text'] ?? '',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1D29))),
                        ),
                      ])),
                    ]),
                  );
                },
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
          child: Row(children: [
            Expanded(child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: 'コメントを入力...',
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
                decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                child: _loading
                    ? const Padding(padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
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