import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/success_dialog.dart';

/// Bildirimler Sayfası - Takım davetleri ve sistem bildirimleri
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Scaffold(
        body: Center(child: Text(lang.isTurkish ? 'Giriş yapmalısınız' : 'Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(lang.isTurkish ? 'Bildirimler' : 'Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(uid),
            child: Text(lang.isTurkish ? 'Tümünü Okundu İşaretle' : 'Mark All Read'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .orderBy('created_at', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Bildirim yok',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notif = notifications[index].data() as Map<String, dynamic>;
              final notifId = notifications[index].id;
              return _buildNotificationItem(notif, notifId);
            },
          );
        },
      ),
    );
  }

  Widget _buildNotificationItem(Map<String, dynamic> notif, String notifId) {
    final lang = context.read<LanguageProvider>();
    final type = notif['notification_type'] ?? '';
    final status = notif['notification_status'] ?? 'pending';
    final timestamp = notif['created_at'] as Timestamp?;
    final isRead = status == 'read' || status == 'accepted' || status == 'declined';

    IconData icon;
    Color color;
    String title;
    String? subtitle;
    List<Widget>? actions;

    switch (type) {
      case 'team_invite':
        icon = Icons.group_add;
        color = const Color(0xFF6EC6B5);
        title = lang.isTurkish ? 'Takım Daveti' : 'Team Invite';
        subtitle = lang.isTurkish 
            ? '${notif['team_name'] ?? 'Bir takım'} sizi davet etti'
            : '${notif['team_name'] ?? 'A team'} invited you';
        
        if (status == 'pending') {
          actions = [
            _buildActionButton(
              lang.isTurkish ? 'Kabul Et' : 'Accept',
              Colors.green,
              () => _handleInviteResponse(notifId, notif, true),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              lang.isTurkish ? 'Reddet' : 'Decline',
              Colors.red,
              () => _handleInviteResponse(notifId, notif, false),
            ),
          ];
        } else if (status == 'accepted') {
          subtitle = lang.isTurkish 
              ? '${notif['team_name']} takımına katıldınız ✓'
              : 'You joined ${notif['team_name']} ✓';
        } else if (status == 'declined') {
          subtitle = lang.isTurkish ? 'Daveti reddettiniz' : 'You declined the invite';
        }
        break;
        
      case 'donation_thanks':
        icon = Icons.favorite;
        color = const Color(0xFFE07A5F);
        title = lang.isTurkish ? 'Teşekkürler!' : 'Thank You!';
        subtitle = lang.isTurkish 
            ? '${notif['charity_name']} için bağışınız alındı'
            : 'Your donation to ${notif['charity_name']} was received';
        break;
        
      case 'step_milestone':
        icon = Icons.emoji_events;
        color = const Color(0xFFF2C94C);
        title = lang.isTurkish ? 'Tebrikler!' : 'Congratulations!';
        subtitle = notif['message'] ?? (lang.isTurkish ? 'Yeni bir başarı kazandınız' : 'You earned a new achievement');
        break;
        
      default:
        icon = Icons.notifications;
        color = Colors.grey;
        title = lang.isTurkish ? 'Bildirim' : 'Notification';
        subtitle = notif['message'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : const Color(0xFF6EC6B5).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : const Color(0xFF6EC6B5).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isRead ? Colors.grey[700] : Colors.black,
                          ),
                        ),
                        if (!isRead)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6EC6B5),
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              if (timestamp != null)
                Text(
                  _formatTime(timestamp.toDate()),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
          if (actions != null) ...[
            const SizedBox(height: 12),
            Row(children: actions),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return Expanded(
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} dk önce';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} saat önce';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} gün önce';
    } else {
      return '${date.day}.${date.month}.${date.year}';
    }
  }

  Future<void> _handleInviteResponse(
    String notifId,
    Map<String, dynamic> notif,
    bool accept,
  ) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final lang = context.read<LanguageProvider>();

    try {
      if (accept) {
        // Kullanıcının mevcut takımı var mı kontrol et
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.data()?['current_team_id'] != null) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 8),
                  Text(lang.isTurkish ? 'Uyarı' : 'Warning'),
                ],
              ),
              content: Text(lang.isTurkish ? 'Zaten bir takımdasınız. Önce ayrılmalısınız.' : 'You are already in a team. You must leave first.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.ok),
                ),
              ],
            ),
          );
          return;
        }

        final teamId = notif['sender_team_id'];
        
        // Takıma katıl
        await _firestore.collection('teams').doc(teamId).collection('team_members').doc(uid).set({
          'team_id': teamId,
          'user_id': uid,
          'member_status': 'active',
          'join_date': Timestamp.now(),
          'member_total_hope': 0.0,
          'member_daily_steps': 0,
        });

        await _firestore.collection('teams').doc(teamId).update({
          'members_count': FieldValue.increment(1),
          'member_ids': FieldValue.arrayUnion([uid]),
        });

        await _firestore.collection('users').doc(uid).update({
          'current_team_id': teamId,
        });

        // Activity log
        final now = Timestamp.now();
        
        // Global
        await _firestore.collection('activity_logs').add({
          'user_id': uid,
          'activity_type': 'team_joined',
          'team_name': notif['team_name'],
          'created_at': now,
          'timestamp': now,
        });
        
        // User subcollection
        await _firestore.collection('users').doc(uid).collection('activity_logs').add({
          'user_id': uid,
          'activity_type': 'team_joined',
          'team_name': notif['team_name'],
          'created_at': now,
          'timestamp': now,
        });

        await showSuccessDialog(
          context: context,
          title: lang.isTurkish ? 'Hoş Geldin!' : 'Welcome!',
          message: notif['team_name'] ?? '',
          subtitle: lang.isTurkish 
              ? '${notif['team_name']} takımına katıldınız!' 
              : 'You joined ${notif['team_name']} team!',
          icon: Icons.group_add_rounded,
          gradientColors: [const Color(0xFF6EC6B5), const Color(0xFF4CAF50)],
          buttonText: lang.isTurkish ? 'Harika!' : 'Great!',
        );
      }

      // Bildirimi güncelle
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notifId)
          .update({
        'notification_status': accept ? 'accepted' : 'declined',
      });
    } catch (e) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 28),
              const SizedBox(width: 8),
              Text(lang.isTurkish ? 'Hata' : 'Error'),
            ],
          ),
          content: Text('$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.ok),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _markAllAsRead(String uid) async {
    final lang = context.read<LanguageProvider>();
    try {
      final batch = _firestore.batch();
      final notifs = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('notification_status', isEqualTo: 'pending')
          .get();

      for (var doc in notifs.docs) {
        // Sadece davet olmayan bildirimleri okundu işaretle
        if (doc.data()['notification_type'] != 'team_invite') {
          batch.update(doc.reference, {'notification_status': 'read'});
        }
      }

      await batch.commit();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.mark_email_read, color: const Color(0xFF6EC6B5), size: 48),
          title: Text(lang.isTurkish ? 'Tamam' : 'Done'),
          content: Text(lang.isTurkish ? 'Tüm bildirimler okundu işaretlendi' : 'All notifications marked as read'),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6EC6B5),
                foregroundColor: Colors.white,
              ),
              child: Text(lang.ok),
            ),
          ],
        ),
      );
    } catch (e) {
      print('Hata: $e');
    }
  }
}
