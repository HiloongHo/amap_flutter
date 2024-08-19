import 'dart:async';
import 'dart:io';

import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<String?> getAddressFromLatLng(double latitude, double longitude) async {
    const String apiKey = "ca5d840008b86fe2276e7a42b938c622"; // 替换成你的API Key
    const String url = "https://restapi.amap.com/v3/geocode/regeo";

    Dio dio = Dio();
    try {
      final response = await dio.get(url, queryParameters: {
        "output": "json",
        "location": "$longitude,$latitude",
        "key": apiKey,
      });

      if (response.statusCode == 200) {
        final data = response.data;
        if (data["status"] == "1") {
          final address = data["regeocode"]["formatted_address"];
          return address;
        } else {
          print("高德API请求失败: ${data["info"]}");
          return null;
        }
      } else {
        print("网络请求失败，状态码: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("请求发生错误: $e");
      return null;
    }
  }

  Map<String, Object>? _locationResult;
  StreamSubscription<Map<String, Object>>? _locationListener;
  final AMapFlutterLocation _locationPlugin = AMapFlutterLocation();

  @override
  void initState() {
    super.initState();
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    requestPermission();
    AMapFlutterLocation.setApiKey("1dbf56e2e8a4d0e4cdc2df9efd36bc71", "dfb64c0463cb53927914364b5c09aba0");

    if (Platform.isIOS) {
      requestAccuracyAuthorization();
    }

    _locationListener = _locationPlugin.onLocationChanged().listen((Map<String, Object> result) {
      // 确保 latitude 和 longitude 被转换为 double 类型
      dynamic latitudeValue = result["latitude"];
      dynamic longitudeValue = result["longitude"];

      double? latitude = (latitudeValue is String) ? double.tryParse(latitudeValue) : latitudeValue as double?;
      double? longitude = (longitudeValue is String) ? double.tryParse(longitudeValue) : longitudeValue as double?;

      if (latitude != null && longitude != null) {
        print("定位成功: 纬度: $latitude, 经度: $longitude");
        _getAddressFromLocation(latitude, longitude);
      }

      if (_locationResult != result) {
        setState(() {
          _locationResult = result;
        });
      }
    });

    _startLocation(); // 自动启动定位
  }

  @override
  void dispose() {
    super.dispose();
    _locationListener?.cancel();
    _locationPlugin.destroy();
  }

  void _setLocationOption() {
    AMapLocationOption locationOption = AMapLocationOption();
    locationOption.onceLocation = false;
    locationOption.needAddress = true;
    locationOption.geoLanguage = GeoLanguage.DEFAULT;
    locationOption.desiredLocationAccuracyAuthorizationMode = AMapLocationAccuracyAuthorizationMode.ReduceAccuracy;
    locationOption.fullAccuracyPurposeKey = "AMapLocationScene";
    locationOption.locationInterval = 2000;
    locationOption.locationMode = AMapLocationMode.Hight_Accuracy;
    locationOption.distanceFilter = -1;
    locationOption.desiredAccuracy = DesiredAccuracy.Best;
    locationOption.pausesLocationUpdatesAutomatically = false;
    _locationPlugin.setLocationOption(locationOption);
  }

  void _startLocation() {
    _setLocationOption();
    _locationPlugin.startLocation();
  }

  void _stopLocation() {
    _locationPlugin.stopLocation();
  }

  Container _createButtonContainer() {
    return Container(
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          ElevatedButton(
            onPressed: _startLocation,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.blue),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: const Text('开始定位'),
          ),
          Container(width: 20.0),
          ElevatedButton(
            onPressed: _stopLocation,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.blue),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: const Text('停止定位'),
          )
        ],
      ),
    );
  }

  Widget _resultWidget(String key, Object value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          alignment: Alignment.centerRight,
          width: 100.0,
          child: Text('$key :'),
        ),
        Container(width: 5.0),
        Flexible(child: Text('$value', softWrap: true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> widgets = <Widget>[];
    widgets.add(_createButtonContainer());

    if (_locationResult != null) {
      _locationResult?.forEach((key, value) {
        widgets.add(_resultWidget(key, value));
      });
    }

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('定位软件'),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: widgets,
        ),
      ),
    );
  }

  void requestAccuracyAuthorization() async {
    AMapAccuracyAuthorization currentAccuracyAuthorization = await _locationPlugin.getSystemAccuracyAuthorization();
    if (currentAccuracyAuthorization == AMapAccuracyAuthorization.AMapAccuracyAuthorizationFullAccuracy) {
      print("精确定位类型");
    } else if (currentAccuracyAuthorization == AMapAccuracyAuthorization.AMapAccuracyAuthorizationReducedAccuracy) {
      print("模糊定位类型");
    } else {
      print("未知定位类型");
    }
  }

  void requestPermission() async {
    bool hasLocationPermission = await requestLocationPermission();
    if (hasLocationPermission) {
      print("定位权限申请通过");
    } else {
      print("定位权限申请不通过");
    }
  }

  Future<bool> requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status == PermissionStatus.granted) {
      return true;
    } else {
      status = await Permission.location.request();
      return status == PermissionStatus.granted;
    }
  }

  void _getAddressFromLocation(double latitude, double longitude) async {
    String? address = await getAddressFromLatLng(latitude, longitude);
    if (address != null) {
      setState(() {
        _locationResult?["address"] = address; // 将地址添加到位置结果中
      });
      print("当前地理位置: $address");
    } else {
      print("无法获取地理位置");
    }
  }
}
