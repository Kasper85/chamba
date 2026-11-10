import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:chamba/data/services/api_client.dart';
import 'package:chamba/data/services/jobs_api_service.dart';
import 'package:chamba/data/models/job_request.dart';

void main() {
  group('JobsApiService Unit Tests', () {
    test('createJob envía POST /api/v1/jobs y retorna JobRequest serializado', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/jobs');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['title'], 'Fuga de gas');
        expect(body['budget'], 75.0);

        return http.Response(
          jsonEncode({
            'id': 'job-backend-100',
            'clientId': 'user-1',
            'title': 'Fuga de gas',
            'description': 'Manguera desgastada en balón',
            'category': 'gasfiteria',
            'budget': 75.0,
            'district': 'Chiclayo',
            'status': 'BUSCANDO',
            'securityPin': '1234',
            'createdAt': DateTime.now().toIso8601String(),
            'bids': [],
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockClient,
      );
      final service = JobsApiService(apiClient: apiClient);

      final job = await service.createJob(
        title: 'Fuga de gas',
        description: 'Manguera desgastada en balón',
        category: 'gasfiteria',
        budget: 75.0,
        district: 'Chiclayo',
      );

      expect(job.id, 'job-backend-100');
      expect(job.status, JobStatus.searching);
      expect(job.securityPin, '1234');
      expect(job.budget, 75.0);
    });

    test('getJobs envía GET /api/v1/jobs con role y status y retorna lista de JobRequest', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/jobs');
        expect(request.url.queryParameters['role'], 'worker');
        expect(request.url.queryParameters['status'], 'BUSCANDO');

        return http.Response(
          jsonEncode([
            {
              'id': 'job-1',
              'title': 'Instalación de tomacorriente',
              'category': 'electricidad',
              'budget': 50.0,
              'district': 'José Leonardo Ortiz',
              'status': 'BUSCANDO',
              'bids': [],
            }
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockClient,
      );
      final service = JobsApiService(apiClient: apiClient);

      final jobs = await service.getJobs(
        role: 'worker',
        status: JobStatus.searching,
      );

      expect(jobs, hasLength(1));
      expect(jobs.first.id, 'job-1');
      expect(jobs.first.title, 'Instalación de tomacorriente');
      expect(jobs.first.status, JobStatus.searching);
    });

    test('acceptBid envía POST /api/v1/jobs/:id/bids/:bidId/accept y retorna JobRequest ACEPTADA', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/jobs/job-1/bids/bid-1/accept');

        return http.Response(
          jsonEncode({
            'id': 'job-1',
            'title': 'Cerrajería urgente',
            'category': 'cerrajeria',
            'budget': 60.0,
            'agreedPrice': 60.0,
            'district': 'Chiclayo',
            'status': 'ACEPTADA',
            'workerId': 'wp-10',
            'bids': [
              {
                'id': 'bid-1',
                'jobRequestId': 'job-1',
                'workerId': 'wp-10',
                'amount': 60.0,
                'status': 'ACEPTADA',
              }
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        baseUrl: 'http://localhost:3000',
        httpClient: mockClient,
      );
      final service = JobsApiService(apiClient: apiClient);

      final acceptedJob = await service.acceptBid(
        jobId: 'job-1',
        bidId: 'bid-1',
      );

      expect(acceptedJob.status, JobStatus.accepted);
      expect(acceptedJob.workerId, 'wp-10');
      expect(acceptedJob.bids.first.status.name, 'accepted');
    });
  });
}

