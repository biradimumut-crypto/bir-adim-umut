import 'package:flutter/material.dart';

/// Admin ekranları için mobil uyumlu header widget'ı
class AdminMobileHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onRefresh;
  final List<Widget>? actions;

  const AdminMobileHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.onRefresh,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve aksiyonlar
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onRefresh != null || (actions != null && actions!.isNotEmpty)) ...[
                const SizedBox(width: 8),
                // Aksiyonlar
                if (actions != null)
                  ...actions!
                else if (onRefresh != null)
                  _buildRefreshButton(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRefreshButton() {
    return OutlinedButton.icon(
      onPressed: onRefresh,
      icon: const Icon(Icons.refresh, size: 18),
      label: const Text('Yenile'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}

/// Admin header için aksiyon butonları
class AdminHeaderActions extends StatelessWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onAdd;
  final String? addLabel;
  final List<Widget>? extraActions;

  const AdminHeaderActions({
    super.key,
    this.onRefresh,
    this.onAdd,
    this.addLabel,
    this.extraActions,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (onRefresh != null)
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Yenile'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        if (onAdd != null)
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: Text(addLabel ?? 'Ekle'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        if (extraActions != null) ...extraActions!,
      ],
    );
  }
}
