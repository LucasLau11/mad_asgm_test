import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import '../models/workout_exercise_model.dart';
import '../widgets/pose_painter.dart';
import '../controllers/database_service.dart';
import '../services/workout_database_service.dart';

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

// ─── Exercise type enum ────────────────────────────────────────────────────────
enum ExerciseType { squat, pushUp, sitUp, unknown }

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
  DateTime? _startTime;

  // Improved rep detection
  bool _isInStartPosition = true;
  bool _isInEndPosition = false;
  int _framesInDownPosition = 0;
  int _framesInUpPosition = 0;

  // Smoothing — separate smoothers for squat and lunge to ensure accuracy
  final AngleSmoothing _lKneeSmoothing = AngleSmoothing(windowSize: 5);
  final AngleSmoothing _rKneeSmoothing = AngleSmoothing(windowSize: 5);
  final AngleSmoothing _lElbowSmoothing = AngleSmoothing(windowSize: 5);
  final AngleSmoothing _rElbowSmoothing = AngleSmoothing(windowSize: 5);
  final AngleSmoothing _hipSmoothing = AngleSmoothing(windowSize: 5);

  // ── Squat thresholds ──────────────────────────────────────────────────────
  final double _squatDownAngle = 115;
  final double _squatUpAngle   = 160;

  // ── Push-up thresholds ────────────────────────────────────────────────────
  final double _pushUpDownAngle = 100;
  final double _pushUpUpAngle   = 155;


  final double _confidenceThreshold = 0.25;
  final int _requiredFramesInPosition = 2;

  // Feedback
  String _feedbackMessage = 'Get ready!';
  Color _feedbackColor = Colors.white;

  int _frameCount = 0;

  ExerciseType _getExerciseType(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('squat'))    return ExerciseType.squat;
    if (lower.contains('push'))     return ExerciseType.pushUp;
    if (lower.contains('sit'))    return ExerciseType.sitUp;
    return ExerciseType.unknown;
  }

  ExerciseType get _currentExerciseType =>
      _getExerciseType(widget.exercises[_currentExerciseIndex].name);

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
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
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
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
      debugPrint('Pose detection error: $e');
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
    switch (_currentExerciseType) {
      case ExerciseType.squat:
        _detectSquatRep(pose);
        break;
      case ExerciseType.pushUp:
        _detectPushUpRep(pose);
        break;
      case ExerciseType.sitUp:
        _detectSitUpRep(pose);
        break;
      case ExerciseType.unknown:
        _updateFeedback('Use manual count for this exercise', Colors.orange);
        break;
    }
  }

  void _detectSquatRep(Pose pose) {
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];

    // 1. RELAX CONFIDENCE (Real life is noisy)
    const double realLifeMinConf = 0.30;
    bool bodyVisible = (lKnee?.likelihood ?? 0) > realLifeMinConf &&
        (lAnkle?.likelihood ?? 0) > realLifeMinConf &&
        (rAnkle?.likelihood ?? 0) > realLifeMinConf &&
        (lHip?.likelihood ?? 0) > realLifeMinConf;

    if (!bodyVisible || nose == null) {
      _updateFeedback('Step back! Ensure full body is visible', Colors.orange);
      return;
    }

    // 2. SCALED DISTANCE (Use torso as a ruler)
    double torsoHeight = (lHip!.y - lShoulder!.y).abs();
    double bodyHeight = (lAnkle!.y - nose.y).abs();

    if (bodyHeight < torsoHeight * 1.6) {
      _updateFeedback('Too close! I can\'t see your feet', Colors.orange);
      return;
    }
    double footHorizontalDist = (lAnkle.x - rAnkle!.x).abs();

    if (footHorizontalDist > torsoHeight * 1.2) {
      _updateFeedback('Feet too far apart! Is this a lunge?', Colors.red);
      return;
    }
    // 3. SMOOTHED ANGLES
    double lAngle = _calculateAngle(lHip, lKnee!, lAnkle);
    double rAngle = _calculateAngle(rHip!, rKnee!, rAnkle!);

    // Use separate smoothing for each leg to handle jitter
    double smoothedL = _lKneeSmoothing.smooth(lAngle);
    double smoothedR = _rKneeSmoothing.smooth(rAngle);
    double avgAngle = (smoothedL + smoothedR) / 2;

    // 4. FORGIVING SYMMETRY (Increase from 25 to 40)
    // Real people don't stand perfectly square to the camera
    if (avgAngle < 150 && (smoothedL - smoothedR).abs() > 40) {
      _updateFeedback('Try to keep both knees even', Colors.orange);
      return;
    }

    _processRepCycle(
      avgAngle,
      downThreshold: _squatDownAngle,
      upThreshold: 160,
      downFeedback: 'Good depth!',
      midFeedback: 'Go lower...',
    );
  }

  void _detectPushUpRep(Pose pose) {
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final lElbow    = pose.landmarks[PoseLandmarkType.leftElbow];
    final lWrist    = pose.landmarks[PoseLandmarkType.leftWrist];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final rElbow    = pose.landmarks[PoseLandmarkType.rightElbow];
    final rWrist    = pose.landmarks[PoseLandmarkType.rightWrist];
    final hip      = pose.landmarks[PoseLandmarkType.leftHip];

    if (lShoulder != null && rShoulder != null && hip != null && (hip.likelihood ?? 0) > 0.5) {
      double verticalDist = (lShoulder.y - hip.y).abs();
      double horizontalDist = (lShoulder.x - hip.x).abs();
      double frontalWidth = (lShoulder.x - rShoulder.x).abs();

      if (verticalDist > horizontalDist * 1.5 && verticalDist > frontalWidth * 1.5) {
        _updateFeedback('Get down into a plank!', Colors.red);
        return;
      }
    }

    double angle = 0;
    bool valid = false;
    const double floorMinConf = 0.2;
    final lConf = lElbow?.likelihood ?? 0;
    final rConf = rElbow?.likelihood ?? 0;

    if (lConf > floorMinConf && lShoulder != null && lElbow != null && lWrist != null) {
      angle = _calculateAngle(lShoulder, lElbow, lWrist);
      valid = true;
    } else if (rConf > floorMinConf && rShoulder != null && rElbow != null && rWrist != null) {
      angle = _calculateAngle(rShoulder, rElbow, rWrist);
      valid = true;
    }

    if (!valid) {
      _updateFeedback('Show your upper body clearly', Colors.orange);
      return;
    }

    final smoothed = _lElbowSmoothing.smooth(angle);
    _processRepCycle(
      smoothed,
      downThreshold: _pushUpDownAngle,
      upThreshold:   _pushUpUpAngle ,
      downFeedback:  'Great depth! Push up!',
      midFeedback:   'Lower your chest...',
    );
  }
  /*void _detectLungesRep(Pose pose) {
    final lKnee  = pose.landmarks[PoseLandmarkType.leftKnee];
    final lHip   = pose.landmarks[PoseLandmarkType.leftHip];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rKnee  = pose.landmarks[PoseLandmarkType.rightKnee];
    final rHip   = pose.landmarks[PoseLandmarkType.rightHip];
    final rAnkle = pose.landmarks[PoseLandmarkType.rightAnkle];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final nose = pose.landmarks[PoseLandmarkType.nose];

    // 1. Basic Visibility Check
    const double minConfidence = 0.5;
    bool lLegVisible = (lKnee?.likelihood ?? 0) > minConfidence && (lAnkle?.likelihood ?? 0) > minConfidence;
    bool rLegVisible = (rKnee?.likelihood ?? 0) > minConfidence && (rAnkle?.likelihood ?? 0) > minConfidence;

    if ((nose?.likelihood ?? 0) > 0.8 && !lLegVisible && !rLegVisible) {
      _updateFeedback('Step back! Show your full body', Colors.orange);
      return;
    }

    if (lHip == null || rHip == null || lKnee == null || rKnee == null || lAnkle == null || rAnkle == null || lShoulder == null) {
      _updateFeedback('Stay fully in frame', Colors.orange);
      return;
    }

    // 2. Body Orientation Check (Verticality)
    // Multiplied by 1.8 to allow more natural lean during deep lunges
    if ((lShoulder.x - lHip.x).abs() > (lShoulder.y - lHip.y).abs() * 1.8) {
      _updateFeedback('Keep your back straight!', Colors.red);
      return;
    }

    // 3. IMPROVED Foot Distance
    double dx = (lAnkle.x - rAnkle.x).abs();
    double dy = (lAnkle.y - rAnkle.y).abs();
    double maxFootDist = dx > dy ? dx : dy;
    double torsoHeight = (lHip.y - lShoulder.y).abs();

    // 4. Calculate Angles first
    double lAngle = _calculateAngle(lHip, lKnee, lAnkle);
    double rAngle = _calculateAngle(rHip, rKnee, rAnkle);
    double activeKneeAngle = math.min(lAngle, rAngle);

    // 5. SMART FEEDBACK: Only prompt "Bigger step" if they are actually trying to lunge (angle < 150)
    // Reduced multiplier to 0.45 for better sensitivity
    if (activeKneeAngle < 150 && maxFootDist < torsoHeight * 0.45) {
      _updateFeedback('Take a bigger step!', Colors.orange);
      return;
    }

    // 6. Detect Active Leg / Anti-Squat
    // In a lunge, one knee must bend significantly more than the other
    if (activeKneeAngle < 140 && (lAngle - rAngle).abs() < 12) {
      _updateFeedback('Lunge with one leg forward!', Colors.orange);
      return;
    }

    final smoothed = _rKneeSmoothing.smooth(activeKneeAngle);

    // 7. Process Rep
    _processRepCycle(
      smoothed,
      downThreshold: _lungesDownAngle,
      upThreshold:   160,
      downFeedback:  'Good lunge! Now stand up',
      midFeedback:   'Lunge deeper...',
    );
  }*/
  void _detectSitUpRep(Pose pose) {
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];
    final lAnkle = pose.landmarks[PoseLandmarkType.leftAnkle];

    // We only strictly need shoulders to track the torso movement
    if (lShoulder == null || rShoulder == null) {
      _updateFeedback('Show your shoulders', Colors.orange);
      return;
    }

    double shoulderWidth = (lShoulder.x - rShoulder.x).abs();
    double trackingValue;

    // --- FRONTAL LOGIC WITH FALLBACK ---
    // If nose is missing or very close to the top edge, we assume the user is lying FLAT
    if (nose == null || (nose.likelihood ?? 0) < 0.3) {
      // Treat as "Lying Flat" (Large Angle)
      trackingValue = 160;
    } else {
      // If we have hips, use the nose-to-hip ratio
      if (lHip != null && rHip != null) {
        double avgHipY = (lHip.y + rHip.y) / 2;
        double verticalDist = (avgHipY - nose.y).abs();
        double ratio = verticalDist / (shoulderWidth > 0 ? shoulderWidth : 1);
        trackingValue = 180 - (ratio * 65);
      } else {
        // Fallback: If no hips, track how high the nose is above the shoulders
        double avgShoulderY = (lShoulder.y + rShoulder.y) / 2;
        double verticalDist = (avgShoulderY - nose.y).abs();
        double ratio = verticalDist / (shoulderWidth > 0 ? shoulderWidth : 1);
        // Nose far above shoulders = Sitting Up
        trackingValue = 180 - (ratio * 120);
      }
    }

    // --- RELAXED STANDING CHECK ---
    // Only check if you're standing if we can actually see your ankles/hips
    if (lAnkle != null && lHip != null && (lAnkle.likelihood ?? 0) > 0.5) {
      double hipToAnkleDist = (lAnkle.y - lHip.y).abs();
      double torsoHeight = (lShoulder.y - lHip.y).abs();
      if (hipToAnkleDist > torsoHeight * 1.8) {
        _updateFeedback('Get down on the floor!', Colors.red);
        return;
      }
    }

    final smoothedValue = _hipSmoothing.smooth(trackingValue);

    _processRepCycle(
      smoothedValue,
      downThreshold: 85, // Sitting Up
      upThreshold: 140,  // Lying Flat
      downFeedback: 'Great! Now lie back',
      midFeedback: 'Sit up higher',
    );
  }

  void _processRepCycle(
      double smoothedAngle, {
        required double downThreshold,
        required double upThreshold,
        required String downFeedback,
        required String midFeedback,
      }) {
    if (smoothedAngle < downThreshold) {
      _framesInDownPosition++;
      _framesInUpPosition = 0;

      if (_framesInDownPosition >= _requiredFramesInPosition && !_isInEndPosition) {
        _isInEndPosition    = true;
        _isInStartPosition  = false;
        _updateFeedback(downFeedback, Colors.green);
      }
    } else if (smoothedAngle > upThreshold) {
      _framesInUpPosition++;
      _framesInDownPosition = 0;

      if (_framesInUpPosition >= _requiredFramesInPosition &&
          _isInEndPosition &&
          !_isInStartPosition) {
        _isInStartPosition  = true;
        _isInEndPosition    = false;
        _incrementRep();
        _updateFeedback(
          'Great! $_repCount/${widget.exercises[_currentExerciseIndex].reps}',
          Colors.green,
        );
      }
    } else {
      if (!_isInEndPosition) {
        _updateFeedback(midFeedback, Colors.yellow);
      }
    }
  }

  void _updateFeedback(String message, Color color) {
    if (mounted && _feedbackMessage != message) {
      setState(() {
        _feedbackMessage = message;
        _feedbackColor   = color;
      });
    }
  }

  double _calculateAngle(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final radians = math.atan2(c.y - b.y, c.x - b.x) -
        math.atan2(a.y - b.y, a.x - b.x);
    var angle = radians.abs() * 180.0 / math.pi;
    if (angle > 180.0) angle = 360.0 - angle;
    return angle;
  }

  void _startDetection() {
    setState(() {
      _isDetectionActive    = true;
      _framesInDownPosition = 0;
      _framesInUpPosition   = 0;
      _isInEndPosition      = false;
      _isInStartPosition    = true;
      _repCount             = 0;
    });
    _lKneeSmoothing.reset();
    _rKneeSmoothing.reset();
    _lElbowSmoothing.reset();
    _rElbowSmoothing.reset();
  }

  void _incrementRep() {
    setState(() => _repCount++);

    if (_repCount >= widget.exercises[_currentExerciseIndex].reps) {
      _completeSet();
    }
  }

  void _completeSet() {
    if (_currentSet >= widget.exercises[_currentExerciseIndex].sets) {
      if (_currentExerciseIndex < widget.exercises.length - 1) {
        setState(() {
          _currentExerciseIndex++;
          _currentSet          = 1;
          _repCount            = 0;
          _isDetectionActive   = false;
        });
        _showCompletionSnackbar('Moving to next exercise.');
      } else {
        _completeWorkout();
      }
    } else {
      _startRestPeriod();
    }
  }

  void _startRestPeriod() {
    setState(() {
      _isResting         = true;
      _isDetectionActive = false;
      _restTimeRemaining = 60;
      _currentSet++;
      _repCount          = 0;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _restTimeRemaining--);
      if (_restTimeRemaining <= 0) _endRestPeriod();
    });
  }

  void _endRestPeriod() {
    _restTimer?.cancel();
    if (mounted) setState(() => _isResting = false);
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

  Future<void> _completeWorkout() async {
    setState(() => _isDetectionActive = false);

    final durationMinutes = DateTime.now().difference(_startTime!).inMinutes;

    final weightRecords = await DatabaseService().getWeightRecords();
    double userWeight = 70.0;
    if (weightRecords.isNotEmpty) userWeight = weightRecords.first.weightKg;

    double caloriesBurned = (8.0 * userWeight * (durationMinutes / 60.0));
    if (caloriesBurned < 1) caloriesBurned = durationMinutes * 5.0;

    final currentUserId = DatabaseService.currentUserId;
    await WorkoutDatabaseService().insertWorkoutHistory(
      userId:      currentUserId,
      workoutName: widget.workoutName,
      duration:    durationMinutes,
      calories:    caloriesBurned,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Workout Complete! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Congratulations! You\'ve completed the workout.'),
            const SizedBox(height: 16),
            Text('Duration: $durationMinutes mins',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              'Calories Burned: ${caloriesBurned.toStringAsFixed(1)} kcal',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ],
        ),
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
        child: _cameraController == null ||
            !_cameraController!.value.isInitialized
            ? const Center(
            child: CircularProgressIndicator(color: Colors.white))
            : Stack(
          children: [
            Positioned.fill(child: CameraPreview(_cameraController!)),

            // Pose overlay
            if (_poses != null &&
                _poses!.isNotEmpty &&
                _isDetectionActive)
              Positioned.fill(
                child: CustomPaint(
                  painter: PosePainter(
                    poses: _poses!,
                    imageSize: Size(
                      _cameraController!.value.previewSize!.height,
                      _cameraController!.value.previewSize!.width,
                    ),
                    isFrontCamera: _cameraController!
                        .description.lensDirection ==
                        CameraLensDirection.front,
                  ),
                ),
              ),

            // Feedback overlay
            if (_isDetectionActive)
              Positioned(
                top: 200,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
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

            // Top Bar
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
                            content:
                            const Text('Your progress will be lost.'),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.close,
                                color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text('Quit',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
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
                            content: SingleChildScrollView(
                                child:
                                Text(currentExercise.instructions)),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  child: const Text('Close')),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.play_circle_outline,
                                color: Colors.white, size: 20),
                            SizedBox(width: 4),
                            Text('Guide',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Progress
            Positioned(
              top: 80,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(currentExercise.sets,
                            (index) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            width: 40,
                            height: 8,
                            decoration: BoxDecoration(
                              color: index < _currentSet
                                  ? const Color(0xFF9FA8DA)
                                  : Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Set $_currentSet of ${currentExercise.sets}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentExercise.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            // Rest Overlay
            if (_isResting)
              Positioned(
                bottom: 40,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF9FA8DA),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black45,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Rest Time',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Next: ${currentExercise.name}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            '${_restTimeRemaining}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 16),
                          IconButton(
                            onPressed: _endRestPeriod,
                            icon: const Icon(Icons.skip_next,
                                color: Colors.white, size: 32),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Active Workout UI
            if (!_isResting) ...[
              // Rep counter
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
                      border:
                      Border.all(color: Colors.white, width: 4),
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_repCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 48,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${currentExercise.reps} Reps',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Start Set button
              Positioned(
                bottom: 80,
                left: 40,
                right: 40,
                child: ElevatedButton(
                  onPressed:
                  _isDetectionActive ? null : _startDetection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isDetectionActive
                        ? Colors.grey
                        : const Color(0xFFDAD9FF),
                    foregroundColor: Colors.black87,
                    padding:
                    const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    _isDetectionActive ? 'Detecting...' : 'Start Set',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
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
                    padding:
                    const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(
                        color: Colors.white, width: 2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    'Tap To Count Manually',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
