import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SensorPage extends StatefulWidget {
  const SensorPage({Key? key, required this.device}) : super(key: key);
  final BluetoothDevice device;

  @override
  SensorPageState createState() => SensorPageState();
}

class SensorPageState extends State<SensorPage> {
  final String serviceUuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
  final String characteristicUuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
  bool isReady = false;
  int _currentIndex = 0;
  Stream<List<int>>? stream;
  List<double> traceDust = [];

  @override
  void initState() {
    super.initState();
    isReady = false;
    connectToDevice();
  }

  void _initializeStream(BluetoothCharacteristic characteristic) {
    setState(() {
      stream = characteristic.value;
      isReady = true;
    });
  }

  connectToDevice() async {
    Timer(const Duration(seconds: 15), () {
      if (!isReady) {
        disconnectFromDevice();
        _pop();
      }
    });

    try {
      await widget.device.connect();
      // ignore: empty_catches
    } on PlatformException {}

    await widget.device.requestMtu(517);

    setState(() {
      isReady = true;
    });

    discoverServices();
  }

  disconnectFromDevice() {
    widget.device.disconnect();
  }

  discoverServices() async {
    List<BluetoothService> services = await widget.device.discoverServices();
    BluetoothCharacteristic? targetCharacteristic;

    for (var service in services) {
      if (service.uuid.toString() == serviceUuid) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == characteristicUuid) {
            targetCharacteristic = characteristic;
            break;
          }
        }
        if (targetCharacteristic != null) {
          break;
        }
      }
    }

    if (targetCharacteristic == null) {
      _pop();
    } else {
      targetCharacteristic.setNotifyValue(!targetCharacteristic.isNotifying);
      _initializeStream(targetCharacteristic);
    }
  }

  _pop() {
    Navigator.of(context).pop(true);
  }

  String _dataParser(List<int> dataFromDevice) {
    String buffer = '';
    buffer += utf8.decode(dataFromDevice);
    int delimiterIndex = buffer.indexOf('\n');

    if (delimiterIndex != -1) {
      String message = buffer.substring(0, delimiterIndex);
      buffer = buffer.substring(delimiterIndex + 1);
      return message;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nir Sensor'),
      ),
      body: Container(
        child: !isReady
            ? const Center(
                child: Text(
                  'Waiting...',
                  style: TextStyle(fontSize: 24, color: Colors.red),
                ),
              )
            : StreamBuilder<List<int>>(
                stream: stream,
                builder:
                    (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (snapshot.connectionState == ConnectionState.active) {
                    var currentValue = _dataParser(snapshot.data ?? []);

                    if (currentValue.isNotEmpty) {
                      traceDust.add(double.tryParse(currentValue) ?? 0);
                    }

                    return Center(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          flex: 1,
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Text('Current value from Sensor',
                                    style: TextStyle(fontSize: 14)),
                                Text('$currentValue ug/m3',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24))
                              ]),
                        )
                      ],
                    ));
                  } else {
                    return const Text('Check the stream');
                  }
                },
              ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
        ],
        currentIndex: _currentIndex,
        onTap: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
