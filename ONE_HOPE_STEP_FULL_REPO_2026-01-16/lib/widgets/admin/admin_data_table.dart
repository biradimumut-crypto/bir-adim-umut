import 'package:flutter/material.dart';

/// Genel amaçlı veri tablosu widget'ı
class AdminDataTable<T> extends StatelessWidget {
  final List<T> data;
  final List<AdminDataColumn<T>> columns;
  final bool isLoading;
  final String? emptyMessage;
  final Function(T)? onRowTap;
  final ScrollController? scrollController;

  const AdminDataTable({
    super.key,
    required this.data,
    required this.columns,
    this.isLoading = false,
    this.emptyMessage,
    this.onRowTap,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              emptyMessage ?? 'Veri bulunamadı',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
              headingTextStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columnSpacing: 24,
              horizontalMargin: 24,
              columns: columns
                  .map((col) => DataColumn(
                        label: Text(col.title),
                        numeric: col.isNumeric,
                      ))
                  .toList(),
              rows: data.map((item) {
                return DataRow(
                  onSelectChanged: onRowTap != null ? (_) => onRowTap!(item) : null,
                  cells: columns
                      .map((col) => DataCell(col.cellBuilder(item)))
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tablo sütun tanımı
class AdminDataColumn<T> {
  final String title;
  final Widget Function(T item) cellBuilder;
  final bool isNumeric;

  AdminDataColumn({
    required this.title,
    required this.cellBuilder,
    this.isNumeric = false,
  });
}

/// Arama ve filtre bar'ı
class AdminSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(String)? onChanged;
  final VoidCallback? onClear;
  final List<Widget>? actions;

  const AdminSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Ara...',
    this.onChanged,
    this.onClear,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: hintText,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          onClear?.call();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          if (actions != null) ...[
            const SizedBox(width: 16),
            ...actions!,
          ],
        ],
      ),
    );
  }
}

/// Durum badge'i
class StatusBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  factory StatusBadge.active() => const StatusBadge(
        text: 'Aktif',
        color: Colors.green,
        icon: Icons.check_circle,
      );

  factory StatusBadge.inactive() => const StatusBadge(
        text: 'Pasif',
        color: Colors.grey,
        icon: Icons.cancel,
      );

  factory StatusBadge.banned() => const StatusBadge(
        text: 'Banlı',
        color: Colors.red,
        icon: Icons.block,
      );

  factory StatusBadge.verified() => const StatusBadge(
        text: 'Onaylı',
        color: Colors.blue,
        icon: Icons.verified,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Aksiyon butonları
class AdminActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;
  final bool isDestructive;

  const AdminActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? (isDestructive ? Colors.red : Colors.blue);
    
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: buttonColor,
        style: IconButton.styleFrom(
          backgroundColor: buttonColor.withOpacity(0.1),
        ),
      ),
    );
  }
}
