import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../models/admin_badge_model.dart';

/// Rozet yönetimi ekranı
class AdminBadgesScreen extends StatefulWidget {
  const AdminBadgesScreen({super.key});

  @override
  State<AdminBadgesScreen> createState() => _AdminBadgesScreenState();
}

class _AdminBadgesScreenState extends State<AdminBadgesScreen> {
  final AdminService _adminService = AdminService();
  
  List<AdminBadgeModel> _badges = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    try {
      final badges = await _adminService.getAllBadges();
      if (mounted) {
        setState(() {
          _badges = badges;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rozet Yönetimi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Toplam ${_badges.length} rozet tanımlı',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadBadges,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Yenile', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAddBadgeDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni Rozet', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Rozet Listesi
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _badges.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('Henüz rozet tanımlanmamış', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 350,
                        childAspectRatio: MediaQuery.of(context).size.width > 600 ? 0.85 : 0.72,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _badges.length,
                      itemBuilder: (context, index) {
                        final badge = _badges[index];
                        return _buildBadgeCard(badge);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(AdminBadgeModel badge) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst kısım - İkon ve durum
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _getLevelColor(badge.level).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: badge.iconUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            badge.iconUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.emoji_events, color: _getLevelColor(badge.level), size: 18),
                          ),
                        )
                      : Icon(Icons.emoji_events, color: _getLevelColor(badge.level), size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(badge.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis, maxLines: 1),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _buildLevelBadge(badge.level),
                          const SizedBox(width: 4),
                          _buildStatusBadge(badge.isActive),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 6),
            
            // Açıklama
            Text(badge.description, style: TextStyle(color: Colors.grey[600], fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis),
            
            const SizedBox(height: 6),
            
            // Kriter bilgileri - Compact
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(6)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kriter', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                        Text(_formatCriteriaValue(badge.criteriaType, badge.criteriaValue), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ödül', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          Text('${badge.rewardHope} H', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.amber)),
                        ],
                      ),
                    ),
                  ),
                  Container(width: 1, height: 20, color: Colors.grey[300]),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Kazanan', style: TextStyle(fontSize: 8, color: Colors.grey[600])),
                          Text('${badge.earnedCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Aksiyon butonları - Sadece iconlar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => _showEditBadgeDialog(badge),
                  icon: const Icon(Icons.edit, size: 18),
                  color: Colors.blue,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Düzenle',
                ),
                IconButton(
                  onPressed: () => _showDeleteConfirmation(badge),
                  icon: const Icon(Icons.delete, size: 18),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Sil',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelBadge(BadgeLevel level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _getLevelColor(level).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getLevelColor(level).withOpacity(0.3)),
      ),
      child: Text(
        level.displayName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: _getLevelColor(level),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Color _getLevelColor(BadgeLevel level) {
    switch (level) {
      case BadgeLevel.bronze:
        return Colors.brown;
      case BadgeLevel.silver:
        return Colors.blueGrey;
      case BadgeLevel.gold:
        return Colors.amber;
      case BadgeLevel.platinum:
        return Colors.teal;
      case BadgeLevel.diamond:
        return Colors.purple;
    }
  }

  String _formatCriteriaValue(BadgeCriteriaType type, int value) {
    switch (type) {
      case BadgeCriteriaType.steps:
        return '$value adım';
      case BadgeCriteriaType.donations:
        return '$value H';
      case BadgeCriteriaType.referrals:
        return '$value davet';
      case BadgeCriteriaType.streak:
        return '$value gün';
      case BadgeCriteriaType.teamJoin:
        return 'Takıma katıl';
      case BadgeCriteriaType.custom:
        return '$value';
    }
  }

  void _showAddBadgeDialog() {
    _showBadgeDialog(null);
  }

  void _showEditBadgeDialog(AdminBadgeModel badge) {
    _showBadgeDialog(badge);
  }

  void _showBadgeDialog(AdminBadgeModel? badge) {
    final isEdit = badge != null;
    final nameController = TextEditingController(text: badge?.name ?? '');
    final descController = TextEditingController(text: badge?.description ?? '');
    final iconController = TextEditingController(text: badge?.iconUrl ?? '');
    final valueController = TextEditingController(text: badge?.criteriaValue.toString() ?? '0');
    final rewardController = TextEditingController(text: badge?.rewardHope.toString() ?? '0');
    
    BadgeCriteriaType selectedCriteria = badge?.criteriaType ?? BadgeCriteriaType.steps;
    BadgeLevel selectedLevel = badge?.level ?? BadgeLevel.bronze;
    bool isActive = badge?.isActive ?? true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final screenWidth = MediaQuery.of(context).size.width;
          final dialogWidth = screenWidth > 600 ? 500.0 : screenWidth * 0.9;
          final isMobile = screenWidth < 500;
          return AlertDialog(
          title: Text(isEdit ? 'Rozet Düzenle' : 'Yeni Rozet Ekle'),
          content: SizedBox(
            width: dialogWidth,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Rozet Adı *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: iconController,
                    decoration: const InputDecoration(
                      labelText: 'İkon URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kriter Türü ve Hedef Değer - Mobilde alt alta
                  if (isMobile) ...[
                    DropdownButtonFormField<BadgeCriteriaType>(
                      value: selectedCriteria,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Kriter Türü',
                        border: OutlineInputBorder(),
                      ),
                      items: BadgeCriteriaType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type.displayName, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedCriteria = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Hedef Değer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<BadgeCriteriaType>(
                          value: selectedCriteria,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Kriter Türü',
                            border: OutlineInputBorder(),
                          ),
                          items: BadgeCriteriaType.values.map((type) {
                            return DropdownMenuItem(
                              value: type,
                              child: Text(type.displayName, overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedCriteria = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: valueController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Hedef Değer',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Seviye ve Ödül - Mobilde alt alta
                  if (isMobile) ...[
                    DropdownButtonFormField<BadgeLevel>(
                      value: selectedLevel,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Seviye',
                        border: OutlineInputBorder(),
                      ),
                      items: BadgeLevel.values.map((level) {
                        return DropdownMenuItem(
                          value: level,
                          child: Text(level.displayName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() => selectedLevel = value!);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: rewardController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Ödül (Hope)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ] else
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<BadgeLevel>(
                          value: selectedLevel,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Seviye',
                            border: OutlineInputBorder(),
                          ),
                          items: BadgeLevel.values.map((level) {
                            return DropdownMenuItem(
                              value: level,
                              child: Text(level.displayName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setDialogState(() => selectedLevel = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: rewardController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Ödül (Hope)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Aktif'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() => isActive = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isEmpty || descController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ad ve açıklama zorunludur')),
                  );
                  return;
                }

                final newBadge = AdminBadgeModel(
                  id: badge?.id ?? '',
                  name: nameController.text,
                  description: descController.text,
                  iconUrl: iconController.text,
                  criteriaType: selectedCriteria,
                  criteriaValue: int.tryParse(valueController.text) ?? 0,
                  level: selectedLevel,
                  rewardHope: int.tryParse(rewardController.text) ?? 0,
                  isActive: isActive,
                  earnedCount: badge?.earnedCount ?? 0,
                  createdAt: badge?.createdAt ?? DateTime.now(),
                );

                Navigator.pop(context);
                
                if (isEdit) {
                  await _adminService.updateBadge(newBadge);
                } else {
                  await _adminService.createBadge(newBadge);
                }
                
                _loadBadges();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'Rozet güncellendi' : 'Rozet oluşturuldu')),
                  );
                }
              },
              child: Text(isEdit ? 'Güncelle' : 'Ekle'),
            ),
          ],
        );
        },
      ),
    );
  }

  void _showDeleteConfirmation(AdminBadgeModel badge) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rozeti Sil'),
        content: Text(
          '"${badge.name}" rozetini silmek istediğinize emin misiniz?\n\n'
          'Bu rozeti kazanmış ${badge.earnedCount} kullanıcı var.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _adminService.deleteBadge(badge.id);
              _loadBadges();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Rozet silindi'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
