import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_text_styles.dart';
import '../../data/models/waste_bank.dart';
import '../../services/location_service.dart';
import '../../services/sqlite_service.dart';
import '../../data/models/quest_challenge.dart';
import '../compass/compass_view.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key});

  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  LatLng _userLocation = LocationService.defaultLocation;
  List<WasteBank> _wasteBanks = [];
  List<WasteBank> _filteredBanks = [];
  WasteBank? _selectedBank;
  String _selectedMaterialFilter = 'Semua';
  bool _isMapView = true;
  bool _isLoading = true;

  final List<String> _materialFilters = ['Semua', 'Plastik', 'Kertas', 'Kardus', 'E-Waste', 'Logam'];

  @override
  void initState() {
    super.initState();
    _loadLocationAndBanks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLocationAndBanks() async {
    setState(() => _isLoading = true);

    final pos = await LocationService.instance.getCurrentLocation();
    final banks = await SqliteService.instance.getWasteBanks();

    if (mounted) {
      setState(() {
        _userLocation = pos;
        _wasteBanks = banks;
        _filteredBanks = banks;
        _selectedBank = banks.isNotEmpty ? banks.first : null;
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredBanks = _wasteBanks.where((bank) {
        final matchesQuery = query.isEmpty ||
            bank.name.toLowerCase().contains(query) ||
            bank.address.toLowerCase().contains(query);

        final matchesMaterial = _selectedMaterialFilter == 'Semua' ||
            bank.acceptedMaterials.any((m) => m.toLowerCase().contains(_selectedMaterialFilter.toLowerCase()));

        return matchesQuery && matchesMaterial;
      }).toList();
    });
  }

  Future<void> _openGoogleMapsRoute(double lat, double lng, {String? label}) async {
    // Real-time quest progress update
    SqliteService.instance.incrementQuestProgressByType(QuestType.visitWasteBank, amount: 1);

    final cleanLabel = Uri.encodeComponent(label ?? 'Bank Sampah');
    final googleNavUri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
    final googleMapsDirUrl = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$cleanLabel&travelmode=driving');
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($cleanLabel)');

    try {
      if (await canLaunchUrl(googleNavUri)) {
        await launchUrl(googleNavUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(googleMapsDirUrl)) {
        await launchUrl(googleMapsDirUrl, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      if (await canLaunchUrl(geoUri)) {
        await launchUrl(geoUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(googleMapsDirUrl, mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka Google Maps: $e')),
        );
      }
    }
  }

  void _openBankDetailModal(WasteBank bank) {
    setState(() => _selectedBank = bank);
    final distanceKm = LocationService.instance.calculateDistanceKm(
      _userLocation,
      LatLng(bank.latitude, bank.longitude),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(bank.name, style: AppTextStyles.titleMedium),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Text(
                      distanceKm < 1 ? '${(distanceKm * 1000).round()} meter' : '${distanceKm.toStringAsFixed(1)} km',
                      style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryDark),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(bank.address, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              // Status Buka & Estimasi Waktu Tempuh
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'Buka (${bank.openingHours})',
                          style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF047857), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      const Icon(Icons.two_wheeler_rounded, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${((distanceKm / 30.0) * 60).clamp(2, 90).round()} mnt', style: AppTextStyles.bodySmall),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      const Icon(Icons.directions_walk_rounded, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text('${((distanceKm / 4.5) * 60).clamp(3, 180).round()} mnt', style: AppTextStyles.bodySmall),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Menerima Jenis Sampah:', style: AppTextStyles.labelSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: bank.acceptedMaterials.map((mat) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondary,
                      borderRadius: AppSpacing.roundedSm,
                    ),
                    child: Text(mat, style: AppTextStyles.bodySmall),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              // Dual Action Buttons: Kompas Navigator & Rute Google Maps
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CompassView(targetBank: bank),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Arahkan Kompas', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openGoogleMapsRoute(bank.latitude, bank.longitude, label: bank.name);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.map_rounded, size: 16, color: Color(0xFF16A34A)),
                      label: const Text('Rute Google Maps', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Tempat Setor & Peta', style: AppTextStyles.titleLarge),
        actions: [
          IconButton(
            icon: Icon(_isMapView ? Icons.list_alt_rounded : Icons.map_outlined),
            tooltip: _isMapView ? 'Lihat Daftar' : 'Lihat Peta',
            onPressed: () => setState(() => _isMapView = !_isMapView),
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded),
            tooltip: 'Lokasi Saya',
            onPressed: () {
              _mapController.move(_userLocation, 14.5);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => _applyFilters(),
                    decoration: InputDecoration(
                      hintText: 'Cari nama bank sampah atau lokasi...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),

                // Material filter chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                    itemCount: _materialFilters.length,
                    itemBuilder: (context, index) {
                      final mat = _materialFilters[index];
                      final isSelected = _selectedMaterialFilter == mat;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(mat),
                          selected: isSelected,
                          selectedColor: AppColors.primarySoft,
                          backgroundColor: AppColors.surface,
                          labelStyle: AppTextStyles.labelSmall.copyWith(
                            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : AppColors.border,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedMaterialFilter = mat);
                            _applyFilters();
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),

                // Content View (Map or List)
                Expanded(
                  child: _isMapView ? _buildMapView() : _buildListView(),
                ),
              ],
            ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userLocation,
            initialZoom: 14.0,
            minZoom: 4,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.trashquest',
            ),
            if (_selectedBank != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      _userLocation,
                      LatLng(_selectedBank!.latitude, _selectedBank!.longitude),
                    ],
                    strokeWidth: 3.5,
                    color: const Color(0xFF10B981),
                    pattern: StrokePattern.dashed(segments: const [12, 6]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                // User Location Marker
                Marker(
                  point: _userLocation,
                  width: 32,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: AppSpacing.subtleShadow,
                    ),
                    child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 20),
                  ),
                ),

                // Waste Banks Markers
                ..._filteredBanks.map((bank) {
                  final isSelected = _selectedBank?.id == bank.id;
                  return Marker(
                    point: LatLng(bank.latitude, bank.longitude),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () => _openBankDetailModal(bank),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accent : AppColors.primaryDark,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: AppSpacing.subtleShadow,
                        ),
                        child: const Icon(
                          Icons.recycling_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),

        // Quick bottom floating card for selected bank with direct Google Maps route button
        if (_selectedBank != null)
          Positioned(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            bottom: 16,
            child: InkWell(
              onTap: () => _openBankDetailModal(_selectedBank!),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.roundedLg,
                  boxShadow: AppSpacing.cardShadow,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppSpacing.roundedMd,
                      ),
                      child: const Icon(Icons.near_me_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_selectedBank!.name, style: AppTextStyles.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            '${LocationService.instance.calculateDistanceKm(_userLocation, LatLng(_selectedBank!.latitude, _selectedBank!.longitude)).toStringAsFixed(1)} km • Ketuk untuk panduan & rute',
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick Google Maps Button
                    IconButton(
                      tooltip: 'Buka Google Maps',
                      icon: const Icon(Icons.map_rounded, color: Color(0xFF16A34A), size: 24),
                      onPressed: () {
                        _openGoogleMapsRoute(
                          _selectedBank!.latitude,
                          _selectedBank!.longitude,
                          label: _selectedBank!.name,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildListView() {
    if (_filteredBanks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('Tidak ada bank sampah ditemukan', style: AppTextStyles.titleSmall),
            const SizedBox(height: 4),
            Text('Coba kata kunci atau filter material lain.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: _filteredBanks.length,
      itemBuilder: (context, index) {
        final bank = _filteredBanks[index];
        final distanceKm = LocationService.instance.calculateDistanceKm(
          _userLocation,
          LatLng(bank.latitude, bank.longitude),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppSpacing.roundedMd,
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => _openBankDetailModal(bank),
            borderRadius: AppSpacing.roundedMd,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(bank.name, style: AppTextStyles.titleMedium),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: AppSpacing.roundedSm,
                        ),
                        child: Text(
                          distanceKm < 1 ? '${(distanceKm * 1000).round()} m' : '${distanceKm.toStringAsFixed(1)} km',
                          style: AppTextStyles.labelMedium.copyWith(color: AppColors.primaryDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(bank.address, style: AppTextStyles.bodyMedium),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(bank.openingHours, style: AppTextStyles.bodySmall),
                      const Spacer(),
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 2),
                      Text('${bank.rating}', style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CompassView(targetBank: bank),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.navigation_rounded, size: 14),
                          label: const Text('Kompas', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            _openGoogleMapsRoute(bank.latitude, bank.longitude, label: bank.name);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.map_rounded, size: 14, color: Color(0xFF16A34A)),
                          label: const Text('Google Maps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
