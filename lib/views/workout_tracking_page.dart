import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import '../models/workout_exercise_model.dart';
import '../widgets/pose_painter.dart';

// Angle smoothing helper class
class AngleSmoothing {
  final int windowSize;
  final List<double> _history = [];

  AngleSmoothing({this.windowSize = 5});

  double smooth(double newValue) {
    _history.add(newValue);
    if (_history.length > windowSize) {
      _history.removeAt(0);
    }

    double sum = 0;
    double weightSum = 0;
    for (int i = 0; i < _history.length; i++) {
      double weight = (i + 1).toDouble();
      sum += _history[i] * weight;
      weightSum += weight;
    }

    return sum / weightSum;
  }

  void reset() {
    _history.clear();
  }
}

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

  List<Pose>? _poses;
  bool _isDetectionActive = false;

  // Workout tracking
  int _currentExerciseIndex = 0;
  int _currentSet = 1;
  int _repCount = 0;
  bool _isResting = false;
  int _restTimeRemaining = 60;
  Timer? _restTimer;

  // Improved rep detection
  bool _isInStartPosition = true;
  bool _isInEndPosition = false;
  int _framesInDownPosition = 0;
  int _framesInUpPosition = 0;

  // Smoothing
  final AngleSmoothing _kneeSmoothing = AngleSmoothing(windowSize: 5);

  // Accuracy thresholds - TUNED FOR BETTER INDOOR DETECTION
  final double _confidenceThreshold = 0.25; // More forgiving
  final double _downAngleThreshold = 120; // Easier to trigger "down"
  final double _upAngleThreshold = 155; // Standard "up"
  final int _requiredFramesInPosition = 2; // Faster response

  // Feedback
  String _feedbackMessage = 'Get ready!';
  Color _feedbackColor = Colors.white;

  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.accurate,
      ),
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
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFocusMode(FocusMode.auto);

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

    _frameCount++;
    if (_frameCount % 2 != 0) {
      _isBusy = false;
      return;
    }

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
        } else {
          _updateFeedback('Step back! I can\'t see you', Colors.red);
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
    if (Platform.isAndroid) {
      var rotationValue = sensorOrientation;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationValue = (sensorOrientation + 0) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationValue);
    } else {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final WriteBuffer allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    return InputImage.fromBytes(
      bytes: bytes,
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

    // Left side landmarks
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    // Right side landmarks
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];

    double currentKneeAngle = 0;
    bool hasValidSide = false;

    // Use whichever side has better visibility (likelihood)
    if (lKnee != null && lHip != null && lAnkle != null && 
        lKnee.likelihood > _confidenceThreshold) {
      currentKneeAngle = _calculateAngle(lHip, lKnee, lAnkle);
      hasValidSide = true;
    } else if (rKnee != null && rHip != null && rAnkle != null && 
               rKnee.likelihood > _confidenceThreshold) {
      currentKneeAngle = _calculateAngle(rHip, rKnee, rAnkle);
      hasValidSide = true;
    }

    if (!hasValidSide) {
      _updateFeedback('Step back and stay visible', Colors.orange);
      return;
    }

    final smoothedAngle = _kneeSmoothing.smooth(currentKneeAngle);

    // Rep detection state machine
    if (smoothedAngle < _downAngleThreshold) {
      _framesInDownPosition++;
      _framesInUpPosition = 0;

      if (_framesInDownPosition >= _requiredFramesInPosition && !_isInEndPosition) {
        _isInEndPosition = true;
        _isInStartPosition = false;
        _updateFeedback('Good depth! Now stand up', Colors.green);
      }
    } else if (smoothedAngle > _upAngleThreshold) {
      _framesInUpPosition++;
      _framesInDownPosition = 0;

      if (_framesInUpPosition >= _requiredFramesInPosition && _isInEndPosition && !_isInStartPosition) {
        _isInStartPosition = true;
        _isInEndPosition = false;
        _incrementRep();
        _updateFeedback('Great! ${_repCount}/${currentExercise.reps}', Colors.green);
      }
    } else {
      if (!_isInEndPosition) {
        _updateFeedback('Go lower...', Colors.yellow);
      }
    }
  }

  void _updateFeedback(String message, Color color) {
    if (mounted && _feedbackMessage != message) {
      setState(() {
        _feedbackMessage = message;
        _feedbackColor = color;
      });
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
      _framesInDownPosition = 0;
      _framesInUpPosition = 0;
      _isInEndPosition = false;
      _isInStartPosition = true;
      _repCount = 0;
    });
    _kneeSmoothing.reset();
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
        _kneeSmoothing.reset();
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

    _kneeSmoothing.reset();
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
            const Text('Rest Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('${_restTimeRemaining}s', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
      SnackBar(content: Text(message), backgroundColor: Colors.green, duration: const Duration(seconds: 2)),
    );
  }

  void _completeWorkout() {
    setState(() => _isDetectionActive = false);

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
      SnackBar(content: Text(message), backgroundColor: Colors.red),
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
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Stack(
          children: [
            Positioned.fill(child: CameraPreview(_cameraController!)),

            if (_poses != null && _poses!.isNotEmpty && _isDetectionActive)
              Positioned.fill(
                child: CustomPaint(
                  painter: PosePainter(
                    poses: _poses!,
                    imageSize: Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    ),
                    isFrontCamera: _cameraController!.description.lensDirection == CameraLensDirection.front,
                  ),
                ),
              ),

            if (_isDetectionActive)
              Positioned(
                top: 200,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: _feedbackColor.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _feedbackMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

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
