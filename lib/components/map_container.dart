import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:webview_flutter/webview_flutter.dart';

class MapContainer extends StatefulWidget {
  final LatLng userLocation;

  const MapContainer({
    super.key,
    required this.userLocation,
  });

  @override
  State<MapContainer> createState() => _MapContainerState();
}

class _MapContainerState extends State<MapContainer> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  @override
  void didUpdateWidget(covariant MapContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userLocation != widget.userLocation) {
      _initWebView();
    }
  }

  void _initWebView() {
    final String url =
        'https://embed.windy.com/embed2.html?lat=${widget.userLocation.latitude}&lon=${widget.userLocation.longitude}&detailLat=${widget.userLocation.latitude}&detailLon=${widget.userLocation.longitude}&width=650&height=450&zoom=8&level=surface&overlay=radar&product=radar&menu=&message=&marker=true&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=default&metricTemp=default&radarRange=-1';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(url));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 380,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}
