import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/admin_service.dart';
import '../../models/charity_model.dart';
import '../../widgets/admin/admin_data_table.dart';

/// Vakıf/Topluluk/Birey yönetimi ekranı
class AdminCharitiesScreen extends StatefulWidget {
  const AdminCharitiesScreen({super.key});

  @override
  State<AdminCharitiesScreen> createState() => _AdminCharitiesScreenState();
}

class _AdminCharitiesScreenState extends State<AdminCharitiesScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;
  
  List<CharityModel> _charities = [];
  List<CharityModel> _communities = [];
  List<CharityModel> _individuals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final charities = await _adminService.getAllCharities(type: RecipientType.charity);
      final communities = await _adminService.getAllCharities(type: RecipientType.community);
      final individuals = await _adminService.getAllCharities(type: RecipientType.individual);
      
      if (mounted) {
        setState(() {
          _charities = charities;
          _communities = communities;
          _individuals = individuals;
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
        // Header - Mobil uyumlu
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bağış Alıcıları',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Vakıf, Topluluk ve Bireyler',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ),
        
        // Tabs - Mobil uyumlu
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicator: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey[600],
            labelPadding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.business, size: 18),
                    const SizedBox(width: 4),
                    Text('Vakıf (${_charities.length})', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.groups, size: 18),
                    const SizedBox(width: 4),
                    Text('Topluluk (${_communities.length})', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person, size: 18),
                    const SizedBox(width: 4),
                    Text('Birey (${_individuals.length})', style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Tab Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildList(_charities, RecipientType.charity),
                    _buildList(_communities, RecipientType.community),
                    _buildList(_individuals, RecipientType.individual),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildList(List<CharityModel> items, RecipientType type) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == RecipientType.charity
                  ? Icons.business_outlined
                  : type == RecipientType.community
                      ? Icons.groups_outlined
                      : Icons.person_outline,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              '${type.displayName} bulunamadı',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(type: type),
              icon: const Icon(Icons.add),
              label: Text('${type.displayName} Ekle'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Üst kısımda Ekle butonu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAddDialog(type: type),
                icon: const Icon(Icons.add, size: 18),
                label: Text('${type.displayName} Ekle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        // Liste
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildCharityCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCharityCard(CharityModel item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Görsel
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(item.imageUrl!, fit: BoxFit.cover),
                        )
                      : Icon(
                          item.type == RecipientType.charity
                              ? Icons.business
                              : item.type == RecipientType.community
                                  ? Icons.groups
                                  : Icons.person,
                          color: Colors.purple,
                          size: 24,
                        ),
                ),
                const SizedBox(width: 12),
                
                // Bilgiler
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          _buildStatusBadge(item.isActive),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.category != null 
                            ? CharityCategory.values
                                .firstWhere((c) => c.value == item.category, orElse: () => CharityCategory.humanitarian)
                                .displayName
                            : 'Kategori belirtilmemiş',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 10),
            
            // İstatistikler - Wrap ile mobil uyumlu
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _buildStatChip(
                  Icons.flag,
                  'Hedef: ${_formatNumber(item.targetAmount.toInt())} H',
                  Colors.blue,
                ),
                _buildStatChip(
                  Icons.paid,
                  'Toplanan: ${_formatNumber(item.collectedAmount.toInt())} H',
                  Colors.green,
                ),
                _buildStatChip(
                  Icons.people,
                  '${item.donorCount} bağışçı',
                  Colors.orange,
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // İlerleme çubuğu
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İlerleme',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      '%${item.progressPercentage.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: item.progressPercentage / 100,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      item.progressPercentage >= 100 ? Colors.green : Colors.blue,
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Aksiyon butonları - Wrap ile mobil uyumlu
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _showEditDialog(item),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Düzenle', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () => _toggleStatus(item),
                  icon: Icon(
                    item.isActive ? Icons.visibility_off : Icons.visibility,
                    size: 16,
                  ),
                  label: Text(item.isActive ? 'Pasifleştir' : 'Aktifleştir', style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () => _showTargetDialog(item),
                  icon: const Icon(Icons.flag, size: 16),
                  label: const Text('Hedef', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
                TextButton.icon(
                  onPressed: () => _showDeleteConfirmation(item),
                  icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                  label: const Text('Sil', style: TextStyle(fontSize: 12, color: Colors.red)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Pasif',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green : Colors.grey,
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  void _showAddDialog({RecipientType? type}) {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final targetController = TextEditingController(text: '0');
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final websiteController = TextEditingController();
    final logoUrlController = TextEditingController();
    final bannerUrlController = TextEditingController();
    RecipientType selectedType = type ?? RecipientType.charity;
    CharityCategory? selectedCategory;
    
    // Yüklenen görseller için state
    Uint8List? logoImageBytes;
    Uint8List? bannerImageBytes;
    String? logoFileName;
    String? bannerFileName;
    bool isUploadingLogo = false;
    bool isUploadingBanner = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Yeni Bağış Alıcısı Ekle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<RecipientType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Tür *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.category),
                    ),
                    items: RecipientType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedType = value!);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CharityCategory>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'İlgi Alanı Kategorisi *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.interests),
                    ),
                    items: CharityCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'İsim *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  // Logo - Dosya Yükleme
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.image, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Logo (Listede görünecek)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (logoImageBytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  logoImageBytes!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  logoFileName ?? 'Seçilen dosya',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      logoImageBytes = null;
                                      logoFileName = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  tooltip: 'Kaldır',
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploadingLogo ? null : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 512,
                                        maxHeight: 512,
                                      );
                                      
                                      if (pickedFile != null) {
                                        final bytes = await pickedFile.readAsBytes();
                                        setDialogState(() {
                                          logoImageBytes = bytes;
                                          logoFileName = pickedFile.name;
                                        });
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Görsel seçilemedi: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(isUploadingLogo ? 'Yükleniyor...' : 'Logo Seç'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Banner/Kapak Fotoğrafı - Dosya Yükleme
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.panorama, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Kapak Fotoğrafı', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (bannerImageBytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  bannerImageBytes!,
                                  width: 120,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bannerFileName ?? 'Seçilen dosya',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      bannerImageBytes = null;
                                      bannerFileName = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  tooltip: 'Kaldır',
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploadingBanner ? null : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1200,
                                        maxHeight: 600,
                                      );
                                      
                                      if (pickedFile != null) {
                                        final bytes = await pickedFile.readAsBytes();
                                        setDialogState(() {
                                          bannerImageBytes = bytes;
                                          bannerFileName = pickedFile.name;
                                        });
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Görsel seçilemedi: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(isUploadingBanner ? 'Yükleniyor...' : 'Kapak Fotoğrafı Seç'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: targetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Hedef Miktar (Hope)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.flag),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'İletişim Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
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
                if (nameController.text.isEmpty || descriptionController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('İsim ve açıklama zorunludur')),
                  );
                  return;
                }
                
                if (selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen bir kategori seçin')),
                  );
                  return;
                }

                // Görselleri yükle
                String? finalLogoUrl;
                String? finalBannerUrl;
                
                try {
                  // Logo yükle
                  if (logoImageBytes != null) {
                    setDialogState(() => isUploadingLogo = true);
                    final logoRef = FirebaseStorage.instance.ref()
                        .child('charity_logos')
                        .child('${DateTime.now().millisecondsSinceEpoch}_$logoFileName');
                    await logoRef.putData(logoImageBytes!);
                    finalLogoUrl = await logoRef.getDownloadURL();
                    setDialogState(() => isUploadingLogo = false);
                  }
                  
                  // Banner yükle
                  if (bannerImageBytes != null) {
                    setDialogState(() => isUploadingBanner = true);
                    final bannerRef = FirebaseStorage.instance.ref()
                        .child('charity_banners')
                        .child('${DateTime.now().millisecondsSinceEpoch}_$bannerFileName');
                    await bannerRef.putData(bannerImageBytes!);
                    finalBannerUrl = await bannerRef.getDownloadURL();
                    setDialogState(() => isUploadingBanner = false);
                  }
                } catch (e) {
                  setDialogState(() {
                    isUploadingLogo = false;
                    isUploadingBanner = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Görsel yükleme hatası: $e'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final charity = CharityModel(
                  id: '',
                  name: nameController.text,
                  description: descriptionController.text,
                  type: selectedType,
                  imageUrl: finalLogoUrl,
                  bannerUrl: finalBannerUrl,
                  targetAmount: double.tryParse(targetController.text) ?? 0,
                  category: selectedCategory!.value,
                  contactEmail: emailController.text.isNotEmpty ? emailController.text : null,
                  contactPhone: phoneController.text.isNotEmpty ? phoneController.text : null,
                  website: websiteController.text.isNotEmpty ? websiteController.text : null,
                  createdAt: DateTime.now(),
                );

                Navigator.pop(context);
                
                try {
                  await _adminService.createCharity(charity);
                  await _loadData();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${selectedType.displayName} başarıyla eklendi'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Hata: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(CharityModel item) {
    final nameController = TextEditingController(text: item.name);
    final descriptionController = TextEditingController(text: item.description);
    final emailController = TextEditingController(text: item.contactEmail ?? '');
    final phoneController = TextEditingController(text: item.contactPhone ?? '');
    final websiteController = TextEditingController(text: item.website ?? '');
    
    // Mevcut kategoriyi bul
    CharityCategory? selectedCategory;
    if (item.category != null) {
      try {
        selectedCategory = CharityCategory.values.firstWhere(
          (c) => c.value == item.category,
          orElse: () => CharityCategory.humanitarian,
        );
      } catch (_) {
        selectedCategory = CharityCategory.humanitarian;
      }
    }
    
    // Mevcut görseller
    String? currentLogoUrl = item.imageUrl;
    String? currentBannerUrl = item.bannerUrl;
    
    // Yeni yüklenecek görseller
    Uint8List? newLogoBytes;
    Uint8List? newBannerBytes;
    String? newLogoFileName;
    String? newBannerFileName;
    bool isUploadingLogo = false;
    bool isUploadingBanner = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${item.type.displayName} Düzenle'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'İsim *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama *',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<CharityCategory>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'İlgi Alanı Kategorisi *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.interests),
                    ),
                    items: CharityCategory.values.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() => selectedCategory = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'İletişim Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Telefon',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.language),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Logo - Dosya Yükleme
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.image, size: 20, color: Colors.blue),
                            SizedBox(width: 8),
                            Text('Logo (Listede görünecek)', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (newLogoBytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  newLogoBytes!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  newLogoFileName ?? 'Yeni logo seçildi',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      newLogoBytes = null;
                                      newLogoFileName = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  tooltip: 'Kaldır',
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ] else if (currentLogoUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  currentLogoUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Mevcut logo',
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 68,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        onPressed: () {
                                          setDialogState(() {
                                            currentLogoUrl = null;
                                          });
                                        },
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                        tooltip: 'Sil',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        onPressed: isUploadingLogo ? null : () async {
                                          try {
                                            final picker = ImagePicker();
                                            final pickedFile = await picker.pickImage(
                                              source: ImageSource.gallery,
                                              maxWidth: 512,
                                              maxHeight: 512,
                                            );
                                            
                                            if (pickedFile != null) {
                                              final bytes = await pickedFile.readAsBytes();
                                              setDialogState(() {
                                                newLogoBytes = bytes;
                                                newLogoFileName = pickedFile.name;
                                              });
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Görsel seçilemedi: $e')),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                        tooltip: 'Değiştir',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploadingLogo ? null : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 512,
                                        maxHeight: 512,
                                      );
                                      
                                      if (pickedFile != null) {
                                        final bytes = await pickedFile.readAsBytes();
                                        setDialogState(() {
                                          newLogoBytes = bytes;
                                          newLogoFileName = pickedFile.name;
                                        });
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Görsel seçilemedi: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(isUploadingLogo ? 'Yükleniyor...' : 'Logo Seç'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Banner/Kapak Fotoğrafı - Dosya Yükleme
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.panorama, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text('Kapak Fotoğrafı', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (newBannerBytes != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  newBannerBytes!,
                                  width: 120,
                                  height: 60,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  newBannerFileName ?? 'Yeni kapak seçildi',
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: IconButton(
                                  onPressed: () {
                                    setDialogState(() {
                                      newBannerBytes = null;
                                      newBannerFileName = null;
                                    });
                                  },
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  tooltip: 'Kaldır',
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                            ] else if (currentBannerUrl != null) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  currentBannerUrl!,
                                  width: 120,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 120,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Mevcut kapak',
                                  style: TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(
                                width: 68,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        onPressed: () {
                                          setDialogState(() {
                                            currentBannerUrl = null;
                                          });
                                        },
                                        icon: const Icon(Icons.delete, color: Colors.red, size: 18),
                                        tooltip: 'Sil',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        onPressed: isUploadingBanner ? null : () async {
                                          try {
                                            final picker = ImagePicker();
                                            final pickedFile = await picker.pickImage(
                                              source: ImageSource.gallery,
                                              maxWidth: 1200,
                                              maxHeight: 600,
                                            );
                                            
                                            if (pickedFile != null) {
                                              final bytes = await pickedFile.readAsBytes();
                                              setDialogState(() {
                                                newBannerBytes = bytes;
                                                newBannerFileName = pickedFile.name;
                                              });
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Görsel seçilemedi: $e')),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.edit, color: Colors.blue, size: 18),
                                        tooltip: 'Değiştir',
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploadingBanner ? null : () async {
                                    try {
                                      final picker = ImagePicker();
                                      final pickedFile = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 1200,
                                        maxHeight: 600,
                                      );
                                      
                                      if (pickedFile != null) {
                                        final bytes = await pickedFile.readAsBytes();
                                        setDialogState(() {
                                          newBannerBytes = bytes;
                                          newBannerFileName = pickedFile.name;
                                        });
                                      }
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Görsel seçilemedi: $e')),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(isUploadingBanner ? 'Yükleniyor...' : 'Kapak Fotoğrafı Seç'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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
                if (selectedCategory == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen bir kategori seçin')),
                  );
                  return;
                }
                
                String? finalLogoUrl = currentLogoUrl;
                String? finalBannerUrl = currentBannerUrl;
                
                // Yeni logo yüklendiyse Firebase'e yükle
                if (newLogoBytes != null) {
                  setDialogState(() => isUploadingLogo = true);
                  try {
                    final logoRef = FirebaseStorage.instance
                        .ref()
                        .child('charity_images')
                        .child('${item.id}_logo_${DateTime.now().millisecondsSinceEpoch}.jpg');
                    await logoRef.putData(newLogoBytes!);
                    finalLogoUrl = await logoRef.getDownloadURL();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Logo yüklenemedi: $e')),
                    );
                    setDialogState(() => isUploadingLogo = false);
                    return;
                  }
                  setDialogState(() => isUploadingLogo = false);
                }
                
                // Yeni banner yüklendiyse Firebase'e yükle
                if (newBannerBytes != null) {
                  setDialogState(() => isUploadingBanner = true);
                  try {
                    final bannerRef = FirebaseStorage.instance
                        .ref()
                        .child('charity_images')
                        .child('${item.id}_banner_${DateTime.now().millisecondsSinceEpoch}.jpg');
                    await bannerRef.putData(newBannerBytes!);
                    finalBannerUrl = await bannerRef.getDownloadURL();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kapak fotoğrafı yüklenemedi: $e')),
                    );
                    setDialogState(() => isUploadingBanner = false);
                    return;
                  }
                  setDialogState(() => isUploadingBanner = false);
                }
                
                final updatedCharity = item.copyWith(
                  name: nameController.text,
                  description: descriptionController.text,
                  category: selectedCategory!.value,
                  imageUrl: finalLogoUrl,
                  bannerUrl: finalBannerUrl,
                  contactEmail: emailController.text.isNotEmpty ? emailController.text : null,
                  contactPhone: phoneController.text.isNotEmpty ? phoneController.text : null,
                  website: websiteController.text.isNotEmpty ? websiteController.text : null,
                );

                Navigator.pop(context);
                await _adminService.updateCharity(updatedCharity);
                _loadData();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Güncellendi')),
                  );
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTargetDialog(CharityModel item) {
    final targetController = TextEditingController(text: item.targetAmount.toInt().toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hedef Belirle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${item.name} için yeni hedef miktar belirleyin.'),
            const SizedBox(height: 16),
            TextField(
              controller: targetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Hedef Miktar (Hope)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final target = double.tryParse(targetController.text) ?? 0;
              Navigator.pop(context);
              await _adminService.updateCharityTarget(item.id, target);
              _loadData();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hedef güncellendi')),
                );
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _toggleStatus(CharityModel item) async {
    await _adminService.toggleCharityStatus(item.id, !item.isActive);
    _loadData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(item.isActive ? 'Pasifleştirildi' : 'Aktifleştirildi'),
        ),
      );
    }
  }

  void _showDeleteConfirmation(CharityModel item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silmeyi Onayla'),
        content: Text('"${item.name}" silinecek. Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _adminService.deleteCharity(item.id);
              _loadData();
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Silindi'), backgroundColor: Colors.red),
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

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}
