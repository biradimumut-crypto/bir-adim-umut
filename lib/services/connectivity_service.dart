import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

/// İnternet bağlantısı durumunu kontrol eden servis
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  Timer? _checkTimer;

  /// Bağlantı kontrolünü başlat
  void startMonitoring() {
    // İlk kontrol
    checkConnectivity();
    
    // Her 10 saniyede bir kontrol et
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      checkConnectivity();
    });
  }

  /// Bağlantı kontrolünü durdur
  void stopMonitoring() {
    _checkTimer?.cancel();
  }

  /// İnternet bağlantısını kontrol et
  Future<bool> checkConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      _isOnline = false;
    } on TimeoutException catch (_) {
      _isOnline = false;
    } catch (_) {
      _isOnline = false;
    }
    
    _connectivityController.add(_isOnline);
    return _isOnline;
  }

  void dispose() {
    _checkTimer?.cancel();
    _connectivityController.close();
  }
}

/// Offline banner widget'ı
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: ConnectivityService().connectivityStream,
      initialData: ConnectivityService().isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        
        if (isOnline) return const SizedBox.shrink();
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.orange[700],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.wifi_off, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Çevrimdışı mod - Veriler senkronize edilecek',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
