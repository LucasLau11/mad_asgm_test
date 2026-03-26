import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import '../models/workout_exercise_model.dart';
import '../widgets/pose_painter.dart';

class WorkoutTrackingPage extends StatefulWidget {
  final List<Exercise> exercises;
  final String workoutName;

  const WorkoutTrackingPage({
    Key? key,
    required this.exercises,
    required this.workoutName,
  }) : super(key: key);

  @override
  State<WorkoutTrackingPage> createState() => _WorkoutTrackingPageState();
}

class _WorkoutTrackingPageState extends State<WorkoutTrackingPage> {
  CameraController? _cameraController;
  late PoseDetector _poseDetector;
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;

  List<Pose>? _poses;
  bool _isDetectionActive = false;

  // Workout tracking
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  int _repCount = 0;
  bool _isResting = false;
  int _restTimeRemaining = 60;
  Timer? _restTimer;

  // Rep detection
  bool _isInStartPosition = false;
  bool _isInEndPosition = false;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(),
    );
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showError('No cameras available');
        return;
      }

      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {});

      _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (!_canProcess || _isBusy || !_isDetectionActive) return;
    _isBusy = true;

    final inputImage = _inputImageFromCameraImage(image);
    if (inputImage == null) {
      _isBusy = false;
      return;
    }

    try {
      final poses = await _poseDetector.processImage(inputImage);

      if (mounted && !_isResting && _isDetectionActive) {
        setState(() {
          _poses = poses;
        });

        if (poses.isNotEmpty) {
          _detectRep(poses.first);
        }
      }
    } catch (e) {
      print('Pose detection error: $e');
    }

    _isBusy = false;
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController!.description;
    final sensorOrientation = camera.sensorOrientation;

    InputImageRotation? rotation;
    if (camera.lensDirection == CameraLensDirection.back) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      rotation = InputImageRotationValue.fromRawValue(
        (360 - sensorOrientation) % 360,
      );
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // Combine bytes from all planes
    int numBytes = 0;
    for (final plane in image.planes) {
      numBytes += plane.bytes.length;
    }

    final Uint8List allBytes = Uint8List(numBytes);
    int nextIndex = 0;
    for (final plane in image.planes) {
      allBytes.setRange(
        nextIndex,
        nextIndex + plane.bytes.length,
        plane.bytes,
      );
      nextIndex += plane.bytes.length;
    }

    return InputImage.fromBytes(
      bytes: allBytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  void _detectRep(Pose pose) {
    final currentExercise = widget.exercises[_currentExerciseIndex];

    final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
    final leftAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rightAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    if (leftKnee != null && rightKnee != null &&
        leftHip != null && rightHip != null &&
        leftAnkle != null && rightAnkle != null) {

      final leftKneeAngle = _calculateAngle(leftHip, leftKnee, leftAnkle);
      final rightKneeAngle = _calculateAngle(rightHip, rightKnee, rightAnkle);
      final avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2;

      if (avgKneeAngle < 100 && !_isInEndPosition) {
        _isInEndPosition = true;
        _isInStartPosition = false;
      } else if (avgKneeAngle > 160 && _isInEndPosition && !_isInStartPosition) {
        _isInStartPosition = true;
        _isInEndPosition = false;
        _incrementRep();
      }
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    var angle = radians.abs() * 180.0 / math.pi;
    if (angle > 180.0) {
      angle = 360.0 - angle;
    }
    return angle;
  }

  void _startDetection() {
    setState(() {
      _isDetectionActive = true;
    });
  }

  void _incrementRep() {
    final currentExercise = widget.exercises[_currentExerciseIndex];

    setState(() {
      _repCount++;
    });

    if (_repCount >= currentExercise.reps) {
      _completeSet();
    }
  }

  void _completeSet() {
    final currentExercise = widget.exercises[_currentExerciseIndex];

    if (_currentSet >= currentExercise.sets) {
      if (_currentExerciseIndex < widget.exercises.length - 1) {
        setState(() {
          _currentExerciseIndex++;
          _currentSet = 1;
          _repCount = 0;
          _isDetectionActive = false;
        });
        _showCompletionSnackbar('Exercise Complete! Moving to next exercise.');
      } else {
        _completeWorkout();
      }
    } else {
      _startRestPeriod();
    }
  }

  void _startRestPeriod() {
    setState(() {
      _isResting = true;
      _isDetectionActive = false;
      _restTimeRemaining = 60;
      _currentSet++;
      _repCount = 0;
    });

    _showRestSnackbar();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _restTimeRemaining--;
      });

      if (_restTimeRemaining <= 0) {
        _endRestPeriod();
      }
    });
  }

  void _endRestPeriod() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  void _showRestSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rest Time',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${_restTimeRemaining}s',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        duration: Duration(seconds: _restTimeRemaining),
        backgroundColor: const Color(0xFF9FA8DA),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Skip',
          textColor: Colors.white,
          onPressed: _endRestPeriod,
        ),
      ),
    );
  }

  void _showCompletionSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _completeWorkout() {
    setState(() {
      _isDetectionActive = false;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Workout Complete! 🎉'),
        content: const Text('Congratulations! You\'ve completed the workout.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _canProcess = false;
    _cameraController?.dispose();
    _poseDetector.close();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentExercise = widget.exercises[_currentExerciseIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _cameraController == null || !_cameraController!.value.isInitialized
            ? const Center(
          child: CircularProgressIndicator(color: Colors.white),
        )
            : Stack(
          children: [
            // Camera Preview
            Positioned.fill(
              child: CameraPreview(_cameraController!),
            ),

            // Pose overlay
            if (_poses != null && _poses!.isNotEmpty && _isDetectionActive)
              Positioned.fill(
                child: CustomPaint(
                  painter: PosePainter(
                    poses: _poses!,
                    imageSize: Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    ),
                  ),
                ),
              ),

            // Top bar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Quit Workout?'),
                            content: const Text('Your progress will be lost.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pop(context);
                                },
                                child: const Text('Quit'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.close, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text('Quit', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(currentExercise.name),
                            content: SingleChildScrollView(child: Text(currentExercise.instructions)),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text('Guide', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Exercise info
            Positioned(
              top: 80,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(currentExercise.sets, (index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 40,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index < _currentSet ? const Color(0xFF9FA8DA) : Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 12),
                  Text('Set $_currentSet of ${currentExercise.sets}', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                  const SizedBox(height: 8),
                  Text(currentExercise.name, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            // Rep counter
            if (!_isResting)
              Positioned(
                bottom: 200,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$_repCount', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                        Text('${currentExercise.reps} Reps', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),

            // Start Set button
            if (!_isResting)
              Positioned(
                bottom: 80,
                left: 40,
                right: 40,
                child: ElevatedButton(
                  onPressed: _isDetectionActive ? null : _startDetection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDetectionActive ? Colors.grey : const Color(0xFFDAD9FF),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(_isDetectionActive ? 'Detecting...' : 'Start Set', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              ),

            // Manual count button
            Positioned(
              bottom: 20,
              left: 40,
              right: 40,
              child: OutlinedButton(
                onPressed: _incrementRep,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Tap To Count Manually', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}