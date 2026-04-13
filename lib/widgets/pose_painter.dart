import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final bool isFrontCamera;

  PosePainter({
    required this.poses,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 8
      ..style = PaintingStyle.fill;

    for (final pose in poses) {
      // Draw landmarks (joints)
      for (final landmark in pose.landmarks.values) {
        final point = _translatePoint(
          landmark.x,
          landmark.y,
          size,
        );
        canvas.drawCircle(point, 5, pointPaint);
      }

      // Draw skeleton connections
      _drawLine(canvas, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, paint, size);

      _drawLine(canvas, pose, PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.leftHip, PoseLandmarkType.rightHip, paint, size);

      _drawLine(canvas, pose, PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, paint, size);
      _drawLine(canvas, pose, PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, paint, size);
    }
  }

  void _drawLine(
      Canvas canvas,
      Pose pose,
      PoseLandmarkType type1,
      PoseLandmarkType type2,
      Paint paint,
      Size size,
      ) {
    final landmark1 = pose.landmarks[type1];
    final landmark2 = pose.landmarks[type2];

    if (landmark1 != null && landmark2 != null) {
      final point1 = _translatePoint(landmark1.x, landmark1.y, size);
      final point2 = _translatePoint(landmark2.x, landmark2.y, size);
      canvas.drawLine(point1, point2, paint);
    }
  }

  Offset _translatePoint(double x, double y, Size size) {
    if (isFrontCamera) {
      // Flip X coordinate for front camera mirroring
      return Offset(
        size.width - (x * size.width / imageSize.width),
        y * size.height / imageSize.height,
      );
    }
    return Offset(
      x * size.width / imageSize.width,
      y * size.height / imageSize.height,
    );
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.poses != poses;
  }
}
