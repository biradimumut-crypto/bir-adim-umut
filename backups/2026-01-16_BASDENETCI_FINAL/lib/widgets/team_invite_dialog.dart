import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../services/team_service.dart';
import '../services/notification_service.dart';
import '../providers/language_provider.dart';
import 'success_dialog.dart';

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
    final lang = context.read<LanguageProvider>();
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        lang.teamInviteTitle,
        textAlign: TextAlign.center,
        style: const TextStyle(
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
              color: const Color(0xFF6EC6B5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  widget.notification.teamName ?? lang.unknownText,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6EC6B5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.invitedYouToTeam(widget.notification.senderName ?? ''),
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
            lang.teamInviteDesc,
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
            lang.reject,
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
              : Text(
                  lang.accept,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ],
    );
  }

  /// Daveti Kabul Et
  Future<void> _acceptInvite() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _isLoading = true);

    final result = await _teamService.acceptTeamInvite(
      notificationId: widget.notification.id,
      teamId: widget.notification.senderTeamId,
    );

    if (!mounted) return;

    if (result['success']) {
      // Başarılı dialog göster (konfetili)
      widget.onDismiss();
      Navigator.of(context).pop();
      await showSuccessDialog(
        context: context,
        title: lang.isTurkish ? 'Hoş Geldin!' : 'Welcome!',
        message: widget.notification.teamName ?? lang.team,
        subtitle: lang.successfullyJoinedTeam(widget.notification.teamName ?? lang.team),
        icon: Icons.group_add_rounded,
        gradientColors: [const Color(0xFF6EC6B5), const Color(0xFF4CAF50)],
        buttonText: lang.isTurkish ? 'Harika!' : 'Great!',
      );
    } else {
      // Hata dialog göster
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(lang.isTurkish ? 'Hata' : 'Error'),
          content: Text(lang.errorWithMessage(result['error'] ?? lang.unknownError)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(lang.ok),
            ),
          ],
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  /// Daveti Reddet
  Future<void> _rejectInvite() async {
    final lang = context.read<LanguageProvider>();
    setState(() => _isLoading = true);

    final result = await _teamService.rejectTeamInvite(widget.notification.id);

    if (!mounted) return;

    if (result['success']) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 28),
              const SizedBox(width: 8),
              Text(lang.isTurkish ? 'Bilgi' : 'Info'),
            ],
          ),
          content: Text(lang.inviteRejectedMsg),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(lang.ok),
            ),
          ],
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
