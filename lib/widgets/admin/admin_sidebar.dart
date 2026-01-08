import 'package:flutter/material.dart';

/// Admin paneli sol menü navigasyonu
class AdminSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF1E1E2D) : const Color(0xFF1E3A5F),
      child: SafeArea(
        child: Column(
          children: [
            // Logo & Header
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bir Adım Umut',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white24, height: 1),
            
            // Menu Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildMenuItem(
                    index: 0,
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    subtitle: 'Genel Bakış',
                  ),
                  _buildMenuItem(
                    index: 1,
                    icon: Icons.people_rounded,
                    title: 'Kullanıcılar',
                    subtitle: 'Kullanıcı Yönetimi',
                  ),
                  _buildMenuItem(
                    index: 2,
                    icon: Icons.groups_rounded,
                    title: 'Takımlar',
                    subtitle: 'Takım Yönetimi',
                  ),
                  _buildMenuItem(
                    index: 3,
                    icon: Icons.volunteer_activism_rounded,
                    title: 'Vakıf/Topluluk/Birey',
                    subtitle: 'Bağış Alıcıları',
                  ),
                  _buildMenuItem(
                    index: 4,
                    icon: Icons.paid_rounded,
                    title: 'Bağış Raporları',
                    subtitle: 'Detaylı Raporlar',
                  ),
                  _buildMenuItem(
                    index: 5,
                    icon: Icons.notifications_rounded,
                    title: 'Bildirimler',
                    subtitle: 'Bildirim Yönetimi',
                  ),
                  _buildMenuItem(
                    index: 6,
                    icon: Icons.emoji_events_rounded,
                    title: 'Rozetler',
                    subtitle: 'Rozet Yönetimi',
                  ),
                  _buildMenuItem(
                    index: 7,
                    icon: Icons.comment_rounded,
                    title: 'Yorumlar',
                    subtitle: 'Yorum Yönetimi',
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    child: Divider(color: Colors.white24),
                  ),
                  
                  _buildMenuItem(
                    index: 8,
                    icon: Icons.bar_chart_rounded,
                    title: 'Analitik',
                    subtitle: 'İndirme & Reklam',
                  ),
                  _buildMenuItem(
                    index: 9,
                    icon: Icons.history_rounded,
                    title: 'Admin Logları',
                    subtitle: 'İşlem Geçmişi',
                  ),
                ],
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Super Admin',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Admin panelinden çıkış yap
                      Navigator.of(context).pop(); // Drawer'ı kapat
                      Navigator.of(context).pop(); // Admin panelinden çık
                    },
                    icon: const Icon(Icons.logout, color: Colors.white70),
                    tooltip: 'Çıkış Yap',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onItemSelected(index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: Colors.white.withOpacity(0.2))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.white60,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isSelected ? Colors.white60 : Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.blue[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
