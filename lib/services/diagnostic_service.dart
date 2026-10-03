import 'package:autopulse_ai/models/diagnostic.dart';
import 'package:autopulse_ai/data/mock/mock_data.dart';

abstract class DiagnosticService {
  Future<List<Anomaly>> getAnomalies();
  Future<List<DTC>> getDTCs();
  Future<Anomaly?> getAnomalyById(String id);
}

class MockDiagnosticService implements DiagnosticService {
  @override
  Future<List<Anomaly>> getAnomalies() async {
    return MockData.anomalies;
  }

  @override
  Future<List<DTC>> getDTCs() async {
    return MockData.dtcs;
  }

  @override
  Future<Anomaly?> getAnomalyById(String id) async {
    try {
      return MockData.anomalies.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
