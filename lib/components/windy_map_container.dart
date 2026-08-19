import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WindyMapContainer extends StatefulWidget {
  final LatLng userLocation;

  const WindyMapContainer({
    super.key,
    required this.userLocation,
  });

  @override
  State<WindyMapContainer> createState() => _WindyMapContainerState();
}

class _WindyMapContainerState extends State<WindyMapContainer> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    final double lat = widget.userLocation.latitude;
    final double lng = widget.userLocation.longitude;

    final String windyUrl =
        'https://embed.windy.com/embed2.html?lat=$lat&lon=$lng&detailLat=$lat&detailLon=$lng&width=650&height=450&zoom=8&level=surface&overlay=wind&product=ecmwf&menu=&message=&marker=true&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=m%2Fs&metricTemp=%C2%B0C&radarRange=-1';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('Windy WebView error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(windyUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: const Color(0xFF1E293B),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.cyanAccent,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
