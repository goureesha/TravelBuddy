import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/blog_service.dart';
import '../services/team_service.dart';

class BlogScreen extends StatefulWidget {
  const BlogScreen({super.key});

  @override
  State<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends State<BlogScreen> {
  String? _selectedTeamId; // null = personal/solo
  String _selectedLabel = 'Personal';

  // ══════════════════════════════════
  // TEAM PICKER
  // ══════════════════════════════════
  void _pickMode() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Select Mode', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF00BFA5), child: Icon(Icons.person, color: Colors.white, size: 20)),
            title: Text('Personal', style: GoogleFonts.inter(color: Colors.white)),
            subtitle: Text('Your personal travel blog', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
            trailing: _selectedTeamId == null ? const Icon(Icons.check_circle, color: Color(0xFF00BFA5)) : null,
            onTap: () { setState(() { _selectedTeamId = null; _selectedLabel = 'Personal'; }); Navigator.pop(ctx); },
          ),
          const Divider(color: Colors.white12, height: 1),
          StreamBuilder<QuerySnapshot>(
            stream: TeamService.getMyTeams(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
              final teams = snapshot.data!.docs;
              if (teams.isEmpty) return const SizedBox.shrink();
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: teams.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return ListTile(
                    leading: const CircleAvatar(backgroundColor: Color(0xFF1A73E8), child: Icon(Icons.group, color: Colors.white, size: 20)),
                    title: Text(data['name'] ?? '', style: GoogleFonts.inter(color: Colors.white)),
                    trailing: _selectedTeamId == doc.id ? const Icon(Icons.check_circle, color: Color(0xFF1A73E8)) : null,
                    onTap: () { setState(() { _selectedTeamId = doc.id; _selectedLabel = data['name'] ?? 'Team'; }); Navigator.pop(ctx); },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ══════════════════════════════════
  // CREATE POST
  // ══════════════════════════════════
  void _showCreatePost() async {
    final captionCtrl = TextEditingController();
    XFile? pickedImage;
    bool isPosting = false;
    String? errorMsg;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share a Moment', style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: captionCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'What\'s happening on the road?',
                  hintStyle: GoogleFonts.inter(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Image preview
              if (pickedImage != null)
                Stack(
                  children: [
                    FutureBuilder<Uint8List>(
                      future: pickedImage!.readAsBytes(),
                      builder: (ctx, snap) {
                        if (!snap.hasData) return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(snap.data!, height: 160, width: double.infinity, fit: BoxFit.cover),
                        );
                      },
                    ),
                    Positioned(top: 6, right: 6, child: GestureDetector(
                      onTap: () => setModalState(() => pickedImage = null),
                      child: Container(padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close, color: Colors.white, size: 16)),
                    )),
                  ],
                ),
              if (pickedImage != null) const SizedBox(height: 12),
              // Error message
              if (errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(errorMsg!, style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 12))),
                    ]),
                  ),
                ),
              Row(
                children: [
                  // Gallery button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
                      if (img != null) {
                        setModalState(() { pickedImage = img; errorMsg = null; });
                      }
                    },
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1A73E8),
                      side: BorderSide(color: const Color(0xFF1A73E8).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Camera button
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200, imageQuality: 80);
                      if (img != null) {
                        setModalState(() { pickedImage = img; errorMsg = null; });
                      }
                    },
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00BFA5),
                      side: BorderSide(color: const Color(0xFF00BFA5).withOpacity(0.3)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: isPosting
                        ? null
                        : () async {
                            if (captionCtrl.text.trim().isEmpty && pickedImage == null) return;
                            setModalState(() { isPosting = true; errorMsg = null; });

                            try {
                              final bytes = pickedImage != null ? await pickedImage!.readAsBytes() : null;
                              await BlogService.createPost(
                                teamId: _selectedTeamId,
                                caption: captionCtrl.text,
                                imageBytes: bytes,
                                imageName: pickedImage?.name,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                            } catch (e) {
                              setModalState(() {
                                isPosting = false;
                                errorMsg = 'Failed to post: ${e.toString().replaceAll('Exception: ', '')}';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isPosting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Post', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════
  // BUILD
  // ══════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        title: Text('Travel Blog', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: _pickMode,
            icon: Icon(
              _selectedTeamId == null ? Icons.person_rounded : Icons.group_rounded,
              size: 18, color: const Color(0xFF00BFA5),
            ),
            label: Text(
              _selectedLabel,
              style: GoogleFonts.inter(color: const Color(0xFF00BFA5), fontSize: 13),
            ),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
              stream: BlogService.getTeamBlog(_selectedTeamId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final posts = snapshot.data?.docs ?? [];
                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories_rounded, size: 64, color: Colors.white.withOpacity(0.12)),
                        const SizedBox(height: 12),
                        Text('No posts yet', style: GoogleFonts.inter(color: Colors.white38)),
                        const SizedBox(height: 4),
                        Text('Share your travel moments!', style: GoogleFonts.inter(color: Colors.white24, fontSize: 13)),
                      ],
                    ),
                  );
                }

                // Sort by createdAt (newest first) client-side
                posts.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
                  if (aTime == null || bTime == null) return 0;
                  return bTime.compareTo(aTime);
                });

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final doc = posts[index];
                    final data = doc.data() as Map<String, dynamic>;
                    return _blogPostCard(doc.id, data, currentUid);
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreatePost,
        backgroundColor: const Color(0xFF00BFA5),
        child: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
      ),
    );
  }

  Widget _blogPostCard(String postId, Map<String, dynamic> data, String? currentUid) {
    final caption = data['caption'] ?? '';
    final imageUrl = data['imageUrl'] ?? '';
    final userName = data['userName'] ?? 'Unknown';
    final userPhoto = data['userPhoto'] ?? '';
    final likes = List<String>.from(data['likes'] ?? []);
    final likeCount = (data['likeCount'] as num?)?.toInt() ?? 0;
    final isLiked = currentUid != null && likes.contains(currentUid);
    final createdAt = data['createdAt'] as Timestamp?;
    final timeStr = createdAt != null
        ? DateFormat('dd MMM · h:mm a').format(createdAt.toDate())
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage: userPhoto.isNotEmpty ? NetworkImage(userPhoto) : null,
                  backgroundColor: const Color(0xFF1A73E8),
                  child: userPhoto.isEmpty ? Text(userName[0], style: const TextStyle(color: Colors.white)) : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                      Text(timeStr, style: GoogleFonts.inter(color: Colors.white30, fontSize: 11)),
                    ],
                  ),
                ),
                if (data['userId'] == currentUid)
                  IconButton(
                    onPressed: () => BlogService.deletePost(_selectedTeamId, postId),
                    icon: Icon(Icons.delete_outline, color: Colors.white.withOpacity(0.2), size: 18),
                  ),
              ],
            ),
          ),

          // Image
          if (imageUrl.isNotEmpty)
            ClipRRect(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  height: 250,
                  color: Colors.white.withOpacity(0.04),
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  height: 150,
                  color: Colors.white.withOpacity(0.04),
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.white24)),
                ),
              ),
            ),

          // Caption
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Text(caption, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.4)),
          ),

          // Like button
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 14, 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => BlogService.toggleLike(_selectedTeamId, postId),
                  icon: Icon(
                    isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isLiked ? Colors.redAccent : Colors.white30,
                    size: 22,
                  ),
                ),
                Text(
                  likeCount > 0 ? '$likeCount' : '',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
