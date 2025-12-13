import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../services/team_service.dart';
import '../services/notification_service.dart';

/// Takım Davet Dialog Widget
/// 
/// Kullanıcıya gelen davet bildirimini gösteren ve
/// Kabul Et / Reddet seçenekleri sunan dialog.
class TeamInviteDialog extends StatefulWidget {
  final NotificationModel notification;
  final VoidCallback onDismiss;

  const TeamInviteDialog({
    Key? key,
    required this.notification,
    required this.onDismiss,
  }) : super(key: key);

  @override
  State<TeamInviteDialog> createState() => _TeamInviteDialogState();
}

class _TeamInviteDialogState extends State<TeamInviteDialog> {
  final TeamService _teamService = TeamService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text(
        '🎉 Takım Daveti',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          // Takım adı ve gönderici
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  widget.notification.teamName ?? 'Bilinmiyor',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.notification.senderName} sizi takıma davet etti',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Açıklama metni
          Text(
            'Bu takıma katılarak diğer üyelerle birlikte adım atabilir, takım sıralamasında yer alabilirsiniz.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        // Reddet Butonu
        TextButton(
          onPressed: _isLoading
              ? null
              : () async {
                  await _rejectInvite();
                },
          child: Text(
            'Reddet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Kabul Et Butonu
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () async {
                  await _acceptInvite();
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Kabul Et',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  /// Daveti Kabul Et
  Future<void> _acceptInvite() async {
    setState(() => _isLoading = true);

    final result = await _teamService.acceptTeamInvite(
      notificationId: widget.notification.id,
      teamId: widget.notification.senderTeamId,
    );

    if (!mounted) return;

    if (result['success']) {
      // Başarılı snackbar göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ ${widget.notification.teamName ?? "Takıma"} başarıyla katıldınız!',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
      widget.onDismiss();
      Navigator.of(context).pop();
    } else {
      // Hata snackbar göster
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '❌ Hata: ${result['error'] ?? 'Bilinmeyen hata'}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  /// Daveti Reddet
  Future<void> _rejectInvite() async {
    setState(() => _isLoading = true);

    final result = await _teamService.rejectTeamInvite(widget.notification.id);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '👋 Davet reddedildi.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      widget.onDismiss();
      Navigator.of(context).pop();
    } else {
      setState(() => _isLoading = false);
    }
  }
}

/// Bildirim Listener Widget
/// 
/// Uygulama açıldığında veya arka planda çalışırken bildirimleri dinleyen
/// ve davet geldiğinde otomatik olarak dialog gösteren widget.
class NotificationListener extends StatefulWidget {
  final String userId;
  final Widget child;

  const NotificationListener({
    Key? key,
    required this.userId,
    required this.child,
  }) : super(key: key);

  @override
  State<NotificationListener> createState() => _NotificationListenerState();
}

class _NotificationListenerState extends State<NotificationListener> {
  final NotificationService _notificationService = NotificationService();
  final Set<String> _displayedNotifications = {};

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: _notificationService.getPendingNotificationsStream(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final notifications = snapshot.data as List;

          // Yeni bildirimleri kontrol et ve göster
          for (var notification in notifications) {
            if (!_displayedNotifications.contains(notification.id)) {
              _displayedNotifications.add(notification.id);

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _showNotificationDialog(notification);
                }
              });
            }
          }
        }

        return widget.child;
      },
    );
  }

  /// Bildirim Dialog'unu Göster
  void _showNotificationDialog(dynamic notification) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => TeamInviteDialog(
        notification: notification,
        onDismiss: () {
          _displayedNotifications.remove(notification.id);
        },
      ),
    );
  }
}
