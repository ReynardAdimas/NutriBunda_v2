import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_constants.dart';
import '../../data/datasources/local/local_steps_datasource.dart';

class StepsSyncService {
  final LocalStepsDatasource _localStepsDatasource; 
  final String _authToken; 

  StepsSyncService(this._localStepsDatasource, this._authToken); 

  Future<void> syncPendingSteps(int userId) async {
    final unsyncedRecords = await _localStepsDatasource.getUnsyncedSteps(userId);

    for(final record in unsyncedRecords){
      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/steps'), 
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          }, 
          body: jsonEncode({
            'date': record['date'],
            'steps': record['steps'],
            'calories_burned': record['calories_burned'],
          }),
        );

        if (response.statusCode == 200) {
          await _localStepsDatasource.markAsSynced(record['id'] as int);
        }
      } catch (e) {
        continue;
      }
    }
  }
}