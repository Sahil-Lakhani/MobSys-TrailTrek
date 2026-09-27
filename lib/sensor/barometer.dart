import 'dart:math' as math;

class Barometer {
  Barometer._();

  static const double seaLevelHpa = 1013.25;

  static double altitudeMetres(double pressureHpa, [double? seaLevelHpa]) {
    final reference = seaLevelHpa ?? Barometer.seaLevelHpa;
    return 44330.0 * (1.0 - math.pow(pressureHpa / reference, 0.1903));
  }

  static const double minGainStepM = 0.6;

  static double accumulateGain(double previous, double current) {
    final delta = current - previous;
    return delta > minGainStepM ? delta : 0.0;
  }

  static double smooth(double previous, double sample, [double alpha = 0.15]) =>
      previous.abs() < 0.001 ? sample : previous + alpha * (sample - previous);
}
