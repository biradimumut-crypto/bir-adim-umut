import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Giriş yapmalısınız')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => _markAllAsRead(uid),
            child: const Text('Tümünü Okundu İşaretle'),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notifications')
            .where('receiver_uid', isEqualTo: uid)
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
    final type = notif['type'] ?? '';
    final status = notif['status'] ?? 'pending';
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
        color = Colors.blue;
        title = 'Takım Daveti';
        subtitle = '${notif['team_name'] ?? 'Bir takım'} sizi davet etti';
        
        if (status == 'pending') {
          actions = [
            _buildActionButton(
              'Kabul Et',
              Colors.green,
              () => _handleInviteResponse(notifId, notif, true),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              'Reddet',
              Colors.red,
              () => _handleInviteResponse(notifId, notif, false),
            ),
          ];
        } else if (status == 'accepted') {
          subtitle = '${notif['team_name']} takımına katıldınız ✓';
        } else if (status == 'declined') {
          subtitle = 'Daveti reddettiniz';
        }
        break;
        
      case 'donation_thanks':
        icon = Icons.favorite;
        color = Colors.purple;
        title = 'Teşekkürler!';
        subtitle = '${notif['charity_name']} için bağışınız alındı';
        break;
        
      case 'step_milestone':
        icon = Icons.emoji_events;
        color = Colors.amber;
        title = 'Tebrikler!';
        subtitle = notif['message'] ?? 'Yeni bir başarı kazandınız';
        break;
        
      default:
        icon = Icons.notifications;
        color = Colors.grey;
        title = 'Bildirim';
        subtitle = notif['message'];
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.grey[200]! : Colors.blue.withOpacity(0.3),
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
                              color: Colors.blue,
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

    try {
      if (accept) {
        // Kullanıcının mevcut takımı var mı kontrol et
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.data()?['current_team_id'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Zaten bir takımdasınız. Önce ayrılmalısınız.'),
              backgroundColor: Colors.orange,
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
        await _firestore.collection('activity_logs').add({
          'user_id': uid,
          'activity_type': 'team_joined',
          'team_name': notif['team_name'],
          'created_at': Timestamp.now(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 ${notif['team_name']} takımına katıldınız!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Bildirimi güncelle
      await _firestore.collection('notifications').doc(notifId).update({
        'status': accept ? 'accepted' : 'declined',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markAllAsRead(String uid) async {
    try {
      final batch = _firestore.batch();
      final notifs = await _firestore
          .collection('notifications')
          .where('receiver_uid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (var doc in notifs.docs) {
        // Sadece davet olmayan bildirimleri okundu işaretle
        if (doc.data()['type'] != 'team_invite') {
          batch.update(doc.reference, {'status': 'read'});
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tüm bildirimler okundu işaretlendi')),
      );
    } catch (e) {
      print('Hata: $e');
    }
  }
}
