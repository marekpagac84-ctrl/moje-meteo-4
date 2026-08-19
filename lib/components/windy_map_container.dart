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
    _initWebView();
  }

  void _initWebView() {
    final double lat = widget.userLocation.latitude;
    final double lng = widget.userLocation.longitude;

    final String windyUrl =
        'https://embed.windy.com/embed2.html?lat=$lat&lon=$lng&detailLat=$lat&detailLon=$lng&width=650&height=450&zoom=8&level=surface&overlay=rain&product=ecmwf&menu=&message=true&marker=true&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=default&metricTemp=default&radarRange=-1';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(windyUrl));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 420,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              Container(
                color: const Color(0xFF1E293B),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.cyanAccent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
