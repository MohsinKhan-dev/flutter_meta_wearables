import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_meta_wearables/flutter_meta_wearables.dart';

void main() {
  runApp(const MetaWearablesExampleApp());
}

class MetaWearablesExampleApp extends StatelessWidget {
  const MetaWearablesExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meta Wearables Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _wearables = MetaWearables.instance;
  bool _initialized = false;
  String _status = 'Not initialized';
  RegistrationState _registrationState = RegistrationState.unavailable;
  List<DeviceIdentifier> _devices = [];
  StreamSubscription? _registrationSub;
  StreamSubscription? _devicesSub;

  @override
  void dispose() {
    _registrationSub?.cancel();
    _devicesSub?.cancel();
    _wearables.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      await _wearables.initialize();
      setState(() {
        _initialized = true;
        _status = 'Initialized';
      });
      _registrationSub = _wearables.registrationState.listen((state) {
        setState(() => _registrationState = state);
      });
      _devicesSub = _wearables.devices.listen((devices) {
        setState(() => _devices = devices);
      });
    } catch (e) {
      setState(() => _status = 'Init failed: $e');
    }
  }

  Future<void> _register() async {
    try {
      await _wearables.startRegistration();
      setState(() => _status = 'Registration started');
    } catch (e) {
      setState(() => _status = 'Registration failed: $e');
    }
  }

  Future<void> _unregister() async {
    try {
      await _wearables.startUnregistration();
      setState(() => _status = 'Unregistration started');
    } catch (e) {
      setState(() => _status = 'Unregistration failed: $e');
    }
  }

  Future<void> _pairMockDevice() async {
    try {
      final mockKit = _wearables.mockDeviceKit;
      if (mockKit == null) return;
      final device = await mockKit.pairRaybanMeta();
      await device.powerOn();
      await device.don();
      await device.unfold();
      setState(() => _status = 'Mock device paired: ${device.deviceId}');
    } catch (e) {
      setState(() => _status = 'Mock pair failed: $e');
    }
  }

  void _openStreaming() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StreamingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meta Wearables')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: $_status'),
                    const SizedBox(height: 8),
                    Text('Registration: ${_registrationState.name}'),
                    const SizedBox(height: 8),
                    Text('Devices: ${_devices.length}'),
                    if (_devices.isNotEmpty)
                      ...(_devices.map((d) => Text('  - ${d.name ?? d.id}'))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!_initialized)
              FilledButton(
                onPressed: _initialize,
                child: const Text('Initialize SDK'),
              ),
            if (_initialized) ...[
              FilledButton(
                onPressed: _register,
                child: const Text('Connect Glasses'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _unregister,
                child: const Text('Disconnect Glasses'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: _pairMockDevice,
                child: const Text('Pair Mock Device (Debug)'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _devices.isNotEmpty ? _openStreaming : null,
                child: const Text('Start Streaming'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StreamingPage extends StatefulWidget {
  const StreamingPage({super.key});

  @override
  State<StreamingPage> createState() => _StreamingPageState();
}

class _StreamingPageState extends State<StreamingPage> {
  final _wearables = MetaWearables.instance;
  MetaWearablesStreamSession? _session;
  StreamSessionState _streamState = StreamSessionState.stopped;
  Uint8List? _capturedPhoto;
  String _error = '';
  StreamSubscription? _stateSub;
  StreamSubscription? _errorSub;

  @override
  void initState() {
    super.initState();
    _startStreaming();
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _errorSub?.cancel();
    _session?.stop();
    super.dispose();
  }

  Future<void> _startStreaming() async {
    try {
      // Check/request permission first
      final permStatus = await _wearables.checkPermissionStatus(
        WearablePermission.camera,
      );
      if (permStatus != PermissionStatus.granted) {
        final reqStatus = await _wearables.requestPermission(
          WearablePermission.camera,
        );
        if (reqStatus != PermissionStatus.granted) {
          setState(() => _error = 'Camera permission denied');
          return;
        }
      }

      final session = await _wearables.startStreamSession();
      setState(() => _session = session);

      _stateSub = session.state.listen((state) {
        setState(() => _streamState = state);
      });
      _errorSub = session.errors.listen((error) {
        setState(() => _error = error.name);
      });
    } catch (e) {
      setState(() => _error = 'Failed to start stream: $e');
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final photo = await _session?.capturePhoto();
      if (photo != null) {
        setState(() => _capturedPhoto = photo.bytes);
      }
    } catch (e) {
      setState(() => _error = 'Capture failed: $e');
    }
  }

  Future<void> _stopStream() async {
    await _session?.stop();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Stream'),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _stopStream,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _session != null
                ? WearableVideoView(
                    session: _session!,
                    fit: BoxFit.contain,
                    placeholder: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text('State: ${_streamState.name}'),
                      ],
                    ),
                  )
                : Center(
                    child: _error.isNotEmpty
                        ? Text('Error: $_error',
                            style: const TextStyle(color: Colors.red))
                        : const CircularProgressIndicator(),
                  ),
          ),
          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error, style: const TextStyle(color: Colors.red)),
            ),
          if (_capturedPhoto != null)
            Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              child: Image.memory(_capturedPhoto!, fit: BoxFit.contain),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilledButton.icon(
                  onPressed: _streamState == StreamSessionState.streaming
                      ? _capturePhoto
                      : null,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture'),
                ),
                OutlinedButton.icon(
                  onPressed: _stopStream,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
