import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../controllers/database_service.dart';
import '../models/heart_rate_model.dart';
import 'heart_rate_history_page.dart';

class HeartRatePage extends StatefulWidget {
  const HeartRatePage({super.key});

  @override
  State<HeartRatePage> createState() => _HeartRatePageState();
}

class _HeartRatePageState extends State<HeartRatePage> {
  final dbService = DatabaseService();

  CameraController? _cameraController;
  bool _isCameraReady = false;
  bool _isMeasuring = false;
  bool _fingerDetected = false;
  bool _isStopping = false; // prevent double-stop

  int _currentBpm = 0;
  String _measurementStatus = 'Place finger on camera';

  // Stores brightness values from each frame
  final List<double> _redValues = [];

  // Show the live average so user can see what value their camera reads
  // This helps us debug the threshold
  double _liveAverage = 0;

  final int _measurementDuration = 15;
  int _secondsRemaining = 15;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  @override
  void dispose() {
    _cameraController?.setFlashMode(FlashMode.off);
    _cameraController?.dispose();
    super.dispose();
  }

  void _requestCameraPermission() async {
    PermissionStatus status = await Permission.camera.request();
    if (status.isGranted) {
      _initCamera();
    } else {
      setState(() {
        _measurementStatus = 'Camera permission denied';
      });
    }
  }

  void _initCamera() async {
    try {
      List<CameraDescription> cameras = await availableCameras();
      CameraDescription rearCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        rearCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      // Flash stays OFF until user presses Start Measuring

      if (mounted) {
        setState(() {
          _isCameraReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _measurementStatus = 'Camera error: $e';
        });
      }
    }
  }

  void _startMeasuring() async {
    if (_cameraController == null || !_isCameraReady || _isMeasuring) return;

    setState(() {
      _isMeasuring = true;
      _isStopping = false;
      _redValues.clear();
      _currentBpm = 0;
      _secondsRemaining = _measurementDuration;
      _measurementStatus = 'Keep finger still on camera...';
    });

    // Turn on flash when measurement starts
    await _cameraController!.setFlashMode(FlashMode.torch);

    // Start reading frames
    await _cameraController!.startImageStream((CameraImage image) {
      _processCameraFrame(image);
    });

    // Start countdown separately
    _startCountdown();
  }

  void _startCountdown() async {
    for (int i = _measurementDuration; i > 0; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_isMeasuring) return;
      setState(() {
        _secondsRemaining = i - 1;
      });
    }
    // Countdown done — stop
    _stopMeasuring();
  }

  void _stopMeasuring() async {
    // Prevent calling stop twice
    if (_isStopping) return;
    _isStopping = true;

    // Stop image stream safely
    try {
      if (_cameraController != null &&
          _cameraController!.value.isStreamingImages) {
        await _cameraController!.stopImageStream();
      }
    } catch (e) {
      // ignore stop errors
    }

    // Turn off flash when measurement is done
    await _cameraController?.setFlashMode(FlashMode.off);

    // Debug: print collected values to console so we can see the signal
    print('=== RAW VALUES (${_redValues.length} frames) ===');
    print(_redValues.map((v) => v.toStringAsFixed(1)).join(', '));
    double minV = _redValues.reduce((a, b) => a < b ? a : b);
    double maxV = _redValues.reduce((a, b) => a > b ? a : b);
    print('=== MIN: $minV  MAX: $maxV  RANGE: ${maxV - minV} ===');

    int bpm = _calculateBpm();

    if (mounted) {
      setState(() {
        _isMeasuring = false;
        _isStopping = false;
        _currentBpm = bpm;
        _measurementStatus = bpm == 0
            ? 'Could not detect. Try again.'
            : 'Measurement complete!';
      });
    }
  }

  void _processCameraFrame(CameraImage image) {
    // Skip if we are in the process of stopping
    if (_isStopping) return;

    try {
      final bytes = image.planes[0].bytes;

      double sum = 0;
      int count = 0;
      for (int i = 0; i < bytes.length; i += 10) {
        sum += bytes[i];
        count++;
      }

      double average = sum / count;

      // FIX: Use a much more relaxed threshold
      // Without finger: average is HIGH (bright, flash lighting up everything)
      // With finger: average DROPS because finger blocks most light
      // The exact threshold depends on the device — we use 200 as default
      // and show the live average so user can see what their device reads
      bool fingerOn = average < 200;

      if (mounted) {
        setState(() {
          _liveAverage = average;
          _fingerDetected = fingerOn;
          if (!fingerOn && _isMeasuring) {
            _measurementStatus = 'Place finger firmly on camera (value: ${average.toInt()})';
          } else if (fingerOn && _isMeasuring) {
            _measurementStatus = 'Finger detected! Hold still... $_secondsRemaining s';
          }
        });
      }

      if (fingerOn) {
        _redValues.add(average);
      }
    } catch (e) {
      // skip bad frames
    }
  }

  int _calculateBpm() {
    if (_redValues.length < 30) return 0;

    print('=== BPM DEBUG ===');
    print('Total frames collected: ${_redValues.length}');
    print('First 10 raw values: ${_redValues.take(10).toList()}');

    // Step 1: Smooth with moving average
    List<double> smoothed = [];
    int windowSize = 5;
    for (int i = windowSize; i < _redValues.length; i++) {
      double avg = 0;
      for (int j = i - windowSize; j < i; j++) {
        avg += _redValues[j];
      }
      smoothed.add(avg / windowSize);
    }

    if (smoothed.isEmpty) return 0;

    // Step 2: Normalize
    double minVal = smoothed.reduce((a, b) => a < b ? a : b);
    double maxVal = smoothed.reduce((a, b) => a > b ? a : b);
    double range = maxVal - minVal;

    print('Smoothed min: $minVal, max: $maxVal, range: $range');

    if (range < 1.0) {
      print('Range too small — signal too flat');
      return 0;
    }

    List<double> normalized = smoothed.map((v) => (v - minVal) / range).toList();

    // Step 3: Try different thresholds and min distances
    // Use lower threshold and smaller min distance to catch more peaks
    int minPeakDistance = 10; // lowered from 20
    double threshold = 0.3;   // lowered from 0.5

    List<int> peakIndices = [];
    for (int i = 1; i < normalized.length - 1; i++) {
      if (normalized[i] > threshold &&
          normalized[i] > normalized[i - 1] &&
          normalized[i] > normalized[i + 1]) {
        if (peakIndices.isEmpty || i - peakIndices.last >= minPeakDistance) {
          peakIndices.add(i);
        }
      }
    }

    print('Peaks found: ${peakIndices.length} at indices: $peakIndices');

    if (peakIndices.length < 2) {
      print('Not enough peaks found');
      return 0;
    }

    // Step 4: Calculate BPM from average interval between peaks
    List<int> intervals = [];
    for (int i = 1; i < peakIndices.length; i++) {
      intervals.add(peakIndices[i] - peakIndices[i - 1]);
    }

    double avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    print('Avg interval between peaks: $avgInterval frames');

    // Calculate actual FPS from measurement
    double actualSeconds = _measurementDuration.toDouble();
    double fps = _redValues.length / actualSeconds;
    print('Estimated FPS: $fps');

    double secondsPerBeat = avgInterval / fps;
    double bpm = 60.0 / secondsPerBeat;
    print('Calculated BPM before clamp: $bpm');

    return bpm.clamp(40, 180).round();
  }

  void _saveReading() async {
    if (_currentBpm == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please take a measurement first.')),
      );
      return;
    }

    String status = HeartRateModel.getStatus(_currentBpm);

    HeartRateModel newRecord = HeartRateModel(
      id: 0,
      bpm: _currentBpm,
      status: status,
      note: '',
      createdOn: '',
    );

    await dbService.insertHeartRateRecord(newRecord);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved! $_currentBpm bpm - $status')),
    );
  }

  Color _getStatusColor(int bpm) {
    if (bpm == 0) return Colors.grey;
    switch (HeartRateModel.getStatus(bpm)) {
      case 'Low': return Colors.blue;
      case 'Normal': return Colors.green;
      case 'Elevated': return Colors.orange;
      case 'High': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = _getStatusColor(_currentBpm);
    String status = _currentBpm == 0 ? '' : HeartRateModel.getStatus(_currentBpm);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Heart Rate Monitor',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HeartRateHistoryPage()),
              );
            },
            child: const Text(
              'History',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ---- Camera Box ----
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  alignment: Alignment.center,
                  children: [

                    // Camera preview
                    if (_isCameraReady && _cameraController != null)
                      SizedBox.expand(child: CameraPreview(_cameraController!))
                    else
                      Center(
                        child: _measurementStatus.contains('denied') ||
                            _measurementStatus.contains('error')
                            ? Text(
                          _measurementStatus,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        )
                            : const CircularProgressIndicator(color: Colors.red),
                      ),

                    // Outer pulse circle
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _fingerDetected ? Colors.red : Colors.red.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),

                    // Inner pulse circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _fingerDetected
                              ? Colors.red.withOpacity(0.7)
                              : Colors.red.withOpacity(0.15),
                          width: 2,
                        ),
                      ),
                    ),

                    // Heart icon
                    Icon(
                      Icons.favorite,
                      color: _fingerDetected ? Colors.red : Colors.red.withOpacity(0.4),
                      size: 40,
                    ),

                    // Status text
                    Positioned(
                      bottom: 16,
                      left: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _measurementStatus,
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                    // Countdown badge
                    if (_isMeasuring)
                      Positioned(
                        top: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$_secondsRemaining',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),

                    // Live average value (top left) — helps debug threshold
                    if (_isCameraReady)
                      Positioned(
                        top: 16,
                        left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'val: ${_liveAverage.toInt()}',
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Threshold tip
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                '💡 Tip: Cover the ENTIRE rear camera + flash with your fingertip. '
                    'The "val" number in the top left should drop when your finger is on. '
                    'If finger is not detected, press firmly.',
                style: TextStyle(fontSize: 11, color: Colors.orange),
              ),
            ),

            const SizedBox(height: 16),

            // ---- Current Reading Card ----
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('Current Reading', style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text(
                    _currentBpm == 0 ? '--' : '$_currentBpm',
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
                  ),
                  const Text('BPM', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 12),
                  if (_currentBpm > 0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$status Heart Rate',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 8,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('60', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      Text('100', style: TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ---- Start Measuring Button ----
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: (!_isCameraReady || _isMeasuring) ? null : _startMeasuring,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.15),
                  foregroundColor: Colors.red,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.1),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  _isMeasuring ? 'Measuring... $_secondsRemaining s' : 'Start Measuring',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ---- Save Reading Button ----
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _currentBpm == 0 ? null : _saveReading,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.withOpacity(0.2),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save, size: 18),
                    SizedBox(width: 8),
                    Text('Save Reading', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}