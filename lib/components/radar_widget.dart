import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RadarWidget extends StatefulWidget {
  final double lat;
  final double lng;

  const RadarWidget({
    super.key,
    required this.lat,
    required this.lng,
  });

  @override
  State<RadarWidget> createState() => _RadarWidgetState();
}

class _RadarWidgetState extends State<RadarWidget> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(
        Uri.parse(
          'https://embed.windy.com/embed2.html?lat=${widget.lat}&lon=${widget.lng}&zoom=8&level=surface&overlay=radar&menu=&message=&marker=&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=m%2Fs&metricTemp=%C2%B0C&radarRange=-1',
        ),
      );
  }

  @override
  void didUpdateWidget(covariant RadarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) {
      _controller.loadRequest(
        Uri.parse(
          'https://embed.windy.com/embed2.html?lat=${widget.lat}&lon=${widget.lng}&zoom=8&level=surface&overlay=radar&menu=&message=&marker=&calendar=now&pressure=&type=map&location=coordinates&detail=&metricWind=m%2Fs&metricTemp=%C2%B0C&radarRange=-1',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}
