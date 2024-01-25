import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mao/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? mapController;
  Location location = Location();
  List<LatLng> pathPoints = [];
  bool isTripStarted = false;
  LocationData? currentLocation;
  PolylinePoints polylinePoints = PolylinePoints();

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    // Check and request location permissions
    permission_handler.PermissionStatus permissionStatus =
        await permission_handler.Permission.locationWhenInUse.status;
    if (permissionStatus != permission_handler.PermissionStatus.granted) {
      permissionStatus =
          await permission_handler.Permission.locationWhenInUse.request();
      if (permissionStatus != permission_handler.PermissionStatus.granted) {
        _showLocationPermissionDeniedDialog();
        return;
      }
    }

    // Get the initial location when permissions are granted
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      currentLocation = await location.getLocation();
      _moveToCurrentLocation();
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        _showLocationPermissionDeniedDialog();
      }
    }
  }

  void _moveToCurrentLocation() {
    if (currentLocation != null && mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(currentLocation!.latitude!, currentLocation!.longitude!),
        ),
      );
    }
  }

  void _showLocationPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Location Permission Required'),
          content: Text('Please enable location permissions in settings.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
            TextButton(
              onPressed: () {
                permission_handler.openAppSettings(); // Open app settings
              },
              child: Text('Settings'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Trip Tracker'),
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: CameraPosition(
          target: LatLng(
            currentLocation?.latitude ?? 37.7749,
            currentLocation?.longitude ?? -122.4194,
          ),
          zoom: 13.0,
        ),
        polylines: {
          Polyline(
            polylineId: PolylineId('trip'),
            color: Colors.blue,
            points: pathPoints,
          ),
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isTripStarted) {
            // Change the end coordinates to your desired latitude and longitude
            _endTripAtSpecificLocation(
                LatLng(37.420016385359794, -122.07880270828765));
          } else {
            _startTrip();
          }
        },
        child: Icon(isTripStarted ? Icons.stop : Icons.play_arrow),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    setState(() {
      mapController = controller;
    });
  }

  void _startTrip() {
    setState(() {
      isTripStarted = true;
      pathPoints.clear();
    });

    // Start location updates
    location.onLocationChanged.listen((LocationData currentLocation) {
      if (isTripStarted) {
        _updatePath(
            LatLng(currentLocation.latitude!, currentLocation.longitude!));
      }
    });
  }

  void _endTripAtSpecificLocation(LatLng endLocation) async {
    // Decode the polyline from start to end
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      google_api_key,
      PointLatLng(currentLocation!.latitude!, currentLocation!.longitude!),
      PointLatLng(endLocation.latitude, endLocation.longitude),
    );

// Add the decoded points to the path
    for (PointLatLng point in result.points) {
      _updatePath(LatLng(point.latitude, point.longitude));
    }

    setState(() {
      isTripStarted = false;
    });

    // Stop location updates
    location.onLocationChanged.listen(null);

    // Calculate total distance
    double totalDistance = _calculateTotalDistance();

    // Show distance in a dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Trip Summary'),
          content:
              Text('Total Distance: ${totalDistance.toStringAsFixed(2)} km'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _updatePath(LatLng point) {
    setState(() {
      pathPoints.add(point);
      mapController?.animateCamera(CameraUpdate.newLatLng(point));
    });
  }

  double _calculateTotalDistance() {
    double totalDistance = 0.0;

    for (int i = 1; i < pathPoints.length; i++) {
      totalDistance += _calculateDistance(pathPoints[i - 1], pathPoints[i]);
    }

    return totalDistance;
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double radius = 6371.0; // Earth's radius in km

    double haversine(double theta) {
      return sin(theta / 2.0) * sin(theta / 2.0);
    }

    double toRadians(double degrees) {
      return degrees * (pi / 180);
    }

    double lat1 = toRadians(start.latitude);
    double lon1 = toRadians(start.longitude);
    double lat2 = toRadians(end.latitude);
    double lon2 = toRadians(end.longitude);

    double dlat = lat2 - lat1;
    double dlon = lon2 - lon1;

    double a = haversine(dlat) + cos(lat1) * cos(lat2) * haversine(dlon);
    double c = 2 * asin(sqrt(a));

    return radius * c;
  }
}
