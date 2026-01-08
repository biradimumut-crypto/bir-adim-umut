import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Yorum yönetimi ekranı
class AdminCommentsScreen extends StatefulWidget {
  const AdminCommentsScreen({super.key});

  @override
  State<AdminCommentsScreen> createState() => _AdminCommentsScreenState();
}

class _AdminCommentsScreenState extends State<AdminCommentsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _comments = [];
  Map<String, String> _charityNames = {};
  Map<String, String> _userNames = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    
    try {
      // Tüm yorumları al
      final commentsSnapshot = await _firestore
          .collection('charity_comments')
          .orderBy('created_at', descending: true)
          .get();
      
      final comments = <Map<String, dynamic>>[];
      final charityIds = <String>{};
      final userIds = <String>{};
      
      for (var doc in commentsSnapshot.docs) {
        final data = doc.data();
        data['id'] = doc.id;
        comments.add(data);
        
        if (data['charity_id'] != null) {
          charityIds.add(data['charity_id']);
        }
        if (data['user_id'] != null) {
          userIds.add(data['user_id']);
        }
      }
      
      // Charity isimlerini al
      final charityNames = <String, String>{};
      for (var charityId in charityIds) {
        try {
          final charityDoc = await _firestore.collection('charities').doc(charityId).get();
          if (charityDoc.exists) {
            charityNames[charityId] = charityDoc.data()?['name'] ?? 'Bilinmiyor';
          }
        } catch (e) {
          charityNames[charityId] = 'Bilinmiyor';
        }
      }
      
      // Kullanıcı isimlerini al - full_name > display_name > user_name > email sırası
      final userNames = <String, String>{};
      for (var userId in userIds) {
        try {
          final userDoc = await _firestore.collection('users').doc(userId).get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            // Öncelik sırası: full_name > display_name > user_name > email
            String userName = userData?['full_name'] ?? 
                              userData?['display_name'] ?? 
                              userData?['user_name'] ?? 
                              userData?['email'] ?? 
                              'Anonim';
            userNames[userId] = userName;
          } else {
            userNames[userId] = 'Kullanıcı bulunamadı';
          }
        } catch (e) {
          userNames[userId] = 'Hata: $e';
        }
      }
      
      if (mounted) {
        setState(() {
          _comments = comments;
          _charityNames = charityNames;
          _userNames = userNames;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu Sil'),
        content: const Text('Bu yorumu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      await _firestore.collection('charity_comments').doc(commentId).delete();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorum başarıyla silindi'),
            backgroundColor: Colors.green,
          ),
        );
        _loadComments();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yorum Yönetimi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Kullanıcı yorumlarını yönet',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Toplam ${_comments.length} yorum',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadComments,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Yenile', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_comments.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.comment_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz yorum yok',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          else
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  // Tablo başlığı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(flex: 2, child: Text('Kullanıcı', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Bağış Alıcısı', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 4, child: Text('Yorum', style: TextStyle(fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Tarih', style: TextStyle(fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('İşlem', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  
                  // Yorum listesi
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _comments.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final comment = _comments[index];
                      final userId = comment['user_id'] ?? '';
                      final charityId = comment['charity_id'] ?? '';
                      final createdAt = comment['created_at'] as Timestamp?;
                      
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Kullanıcı
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.blue.withOpacity(0.1),
                                    child: Text(
                                      (_userNames[userId] ?? 'A')[0].toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _userNames[userId] ?? 'Anonim',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Bağış Alıcısı
                            Expanded(
                              flex: 2,
                              child: Text(
                                _charityNames[charityId] ?? 'Bilinmiyor',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            
                            // Yorum
                            Expanded(
                              flex: 4,
                              child: Text(
                                comment['comment'] ?? '',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                            
                            // Tarih
                            Expanded(
                              flex: 2,
                              child: Text(
                                createdAt != null
                                    ? DateFormat('dd.MM.yyyy HH:mm').format(createdAt.toDate())
                                    : '-',
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ),
                            
                            // İşlem butonu
                            SizedBox(
                              width: 80,
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () => _showCommentDetail(comment),
                                    icon: const Icon(Icons.visibility, size: 20),
                                    tooltip: 'Detay',
                                    color: Colors.blue,
                                  ),
                                  IconButton(
                                    onPressed: () => _deleteComment(comment['id']),
                                    icon: const Icon(Icons.delete, size: 20),
                                    tooltip: 'Sil',
                                    color: Colors.red,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  void _showCommentDetail(Map<String, dynamic> comment) {
    final userId = comment['user_id'] ?? '';
    final charityId = comment['charity_id'] ?? '';
    final createdAt = comment['created_at'] as Timestamp?;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorum Detayı'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Kullanıcı', _userNames[userId] ?? 'Anonim'),
              const SizedBox(height: 12),
              _buildDetailRow('Bağış Alıcısı', _charityNames[charityId] ?? 'Bilinmiyor'),
              const SizedBox(height: 12),
              _buildDetailRow(
                'Tarih',
                createdAt != null
                    ? DateFormat('dd.MM.yyyy HH:mm:ss').format(createdAt.toDate())
                    : '-',
              ),
              const SizedBox(height: 16),
              const Text(
                'Yorum:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(comment['comment'] ?? ''),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _deleteComment(comment['id']);
            },
            icon: const Icon(Icons.delete),
            label: const Text('Sil'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
