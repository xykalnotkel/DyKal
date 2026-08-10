import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/fullscreen_media_viewer.dart';

class ViewProfileScreen extends StatefulWidget {
  final String partnerId;
  const ViewProfileScreen({super.key, required this.partnerId});

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _mediaVisibility = 0; // 0: Semua ke Galeri, 1: Hanya Foto, 2: Manual (Tidak)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMediaVisibility();
  }

  Future<void> _loadMediaVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _mediaVisibility = prefs.getInt('media_visibility_pref') ?? 0;
    });
  }

  Future<void> _setMediaVisibility(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('media_visibility_pref', value);
    setState(() => _mediaVisibility = value);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _coupleId => AuthService().coupleId ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? DyKalTheme.backgroundDark
          : DyKalTheme.background,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.doc('users/${widget.partnerId}').snapshots(),
        builder: (context, snap) {
          final d = snap.data?.data() as Map<String, dynamic>?;
          final name = (d?['displayName'] as String?) ?? 'Pasangan';
          final email = (d?['email'] as String?) ?? '';
          final photo = d?['photoUrl'] as String?;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: DyKalTheme.surfaceDark,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo != null)
                        CachedNetworkImage(imageUrl: photo, fit: BoxFit.cover)
                      else
                        Container(decoration: const BoxDecoration(gradient: DyKalTheme.dykalGradient)),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (email.isNotEmpty)
                              Text(
                                email,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            const SizedBox(height: 6),
                            _presenceBadge(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Quick Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _actionTile(
                          icon: Icons.call,
                          label: 'Telepon',
                          color: DyKalTheme.online,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/audioCall',
                            arguments: {'isCaller': true, 'type': 'audio'},
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _actionTile(
                          icon: Icons.videocam,
                          label: 'Video Call',
                          color: DyKalTheme.primary,
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/videoCall',
                            arguments: {'isCaller': true, 'type': 'video'},
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Pengaturan Visibilitas Media (WhatsApp Style)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: DyKalTheme.cardOf(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: DyKalTheme.borderOf(context)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.visibility_rounded, size: 20, color: DyKalTheme.primary),
                          const SizedBox(width: 10),
                          const Text(
                            'Visibilitas Media di Galeri',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pilih apakah media dari chat ini otomatis disimpan ke Galeri HP kamu.',
                        style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _visibilityChip(0, 'Semua'),
                          const SizedBox(width: 8),
                          _visibilityChip(1, 'Hanya Foto'),
                          const SizedBox(width: 8),
                          _visibilityChip(2, 'Manual (Tidak)'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Shared Media Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: DyKalTheme.primary,
                    labelColor: DyKalTheme.primary,
                    unselectedLabelColor: DyKalTheme.textSecondaryOf(context),
                    tabs: const [
                      Tab(text: 'Media Chat'),
                      Tab(text: 'Dokumen'),
                      Tab(text: 'Voice Note'),
                    ],
                  ),
                ),
              ),

              // Shared Media Content
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 320,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMediaTab(),
                      _buildDocumentsTab(),
                      _buildAudioTab(),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          );
        },
      ),
    );
  }

  Widget _presenceBadge() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.doc('presence/${widget.partnerId}').snapshots(),
      builder: (_, ps) {
        final pd = ps.data?.data() as Map<String, dynamic>?;
        final online = pd?['isOnline'] ?? false;
        final lastSeen = pd?['lastSeen'];
        String text = online ? 'Sedang online' : 'Offline';
        if (!online && lastSeen is Timestamp) {
          final dt = lastSeen.toDate();
          text = 'Terakhir dilihat ${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 8, color: online ? DyKalTheme.online : Colors.white60),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
      },
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _visibilityChip(int value, String label) {
    final active = _mediaVisibility == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setMediaVisibility(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? DyKalTheme.primary : DyKalTheme.surfaceDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? DyKalTheme.primary : DyKalTheme.borderOf(context)),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: active ? Colors.white : DyKalTheme.textSecondaryOf(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaTab() {
    if (_coupleId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats/$_coupleId/messages')
          .where('type', isEqualTo: 'image')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('Belum ada media foto/video', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12)),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final url = data['imageUrl'] as String?;
            if (url == null) return const SizedBox.shrink();

            return GestureDetector(
              onTap: () => FullscreenMediaViewer.open(context, url: url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: DyKalTheme.cardOf(context)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDocumentsTab() {
    if (_coupleId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('couples/$_coupleId/letters').snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('Belum ada dokumen surat', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final text = data['text'] as String? ?? 'Surat';
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DyKalTheme.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mail_outline_rounded, color: DyKalTheme.primary, size: 20),
              ),
              title: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(data['fromName'] ?? '', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 11)),
            );
          },
        );
      },
    );
  }

  Widget _buildAudioTab() {
    if (_coupleId.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats/$_coupleId/messages')
          .where('type', isEqualTo: 'voice')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Text('Belum ada rekaman suara', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 12)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final dur = data['voiceDuration'] ?? 0;
            return ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DyKalTheme.secondary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mic, color: DyKalTheme.secondary, size: 20),
              ),
              title: Text('Voice Note ($dur detik)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(data['fromId'] == AuthService().myId ? 'Kamu' : 'Pasangan', style: TextStyle(color: DyKalTheme.textSecondaryOf(context), fontSize: 11)),
            );
          },
        );
      },
    );
  }
}
