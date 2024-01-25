import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_mao/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as location;
import 'package:permission_handler/permission_handler.dart' as permission;

class TrackingPage extends StatefulWidget {
  const TrackingPage({Key? key}) : super(key: key);

  @override
  State<TrackingPage> createState() => TrackingPageState();
}

class TrackingPageState extends State<TrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();

  static const LatLng sourceLocation = LatLng(37.33500926, -122.03272188);
  static const LatLng destination = LatLng(37.33429383, -122.06600055);

  List<LatLng> polylineCoordinates = [];

void getPolyPoints() async {
  PolylinePoints polylinePoints = PolylinePoints();
  try {
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      google_api_key,
      PointLatLng(sourceLocation.latitude, sourceLocation.longitude),
      PointLatLng(destination.latitude, destination.longitude),
    );

    if (result.points.isNotEmpty) {
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }
    setState(() {});
  } catch (e) {
    print("Error getting route: $e");
  }
}



  @override
  void initState() {
    _checkLocationPermission();
    super.initState();
  }

  Future<void> _checkLocationPermission() async {
    var status = await permission.Permission.location.request();
    if (status == permission.PermissionStatus.granted) {
      getPolyPoints();
    } else {
      // Handle permission denied
      // You might want to show a dialog or message to inform the user
      print('Location permission denied');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Track order",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
      ),
      body: GoogleMap(
        zoomControlsEnabled: true,
        rotateGesturesEnabled: true,
        zoomGesturesEnabled: true,
        polylines: {
          Polyline(
            polylineId: const PolylineId("route"),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 6,
          ),
        },
        initialCameraPosition:
            const CameraPosition(target: sourceLocation, zoom: 13.5),
        markers: {
          const Marker(markerId: MarkerId("source"), position: sourceLocation),
          const Marker(
              markerId: MarkerId("destination"), position: destination),
        },
      ),
    );
  }
}
