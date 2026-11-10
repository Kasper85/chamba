import 'package:flutter_test/flutter_test.dart';
import 'package:chamba/data/models/job_request.dart';
import 'package:chamba/data/models/job_state_machine.dart';

void main() {
  group('Loop L1: JobStatus Enum & JobStateMachine', () {
    test('JobStatus enum contains all Flujo v2 states from ALCANCE.md §1', () {
      expect(JobStatus.values, contains(JobStatus.searching));
      expect(JobStatus.values, contains(JobStatus.negotiating));
      expect(JobStatus.values, contains(JobStatus.accepted));
      expect(JobStatus.values, contains(JobStatus.onTheWay));
      expect(JobStatus.values, contains(JobStatus.onSite));
      expect(JobStatus.values, contains(JobStatus.inProgress));
      expect(JobStatus.values, contains(JobStatus.forConfirmation));
      expect(JobStatus.values, contains(JobStatus.completed));
      expect(JobStatus.values, contains(JobStatus.inDispute));
      expect(JobStatus.values, contains(JobStatus.cancelled));
      expect(JobStatus.values, contains(JobStatus.refunded));
      expect(JobStatus.values.length, equals(11));
    });

    test('Maps string/backend names to JobStatus and vice versa', () {
      expect(JobStateMachine.toBackendName(JobStatus.searching), equals('BUSCANDO'));
      expect(JobStateMachine.toBackendName(JobStatus.negotiating), equals('NEGOCIANDO'));
      expect(JobStateMachine.toBackendName(JobStatus.accepted), equals('ACEPTADA'));
      expect(JobStateMachine.toBackendName(JobStatus.onTheWay), equals('EN_CAMINO'));
      expect(JobStateMachine.toBackendName(JobStatus.onSite), equals('EN_SITIO'));
      expect(JobStateMachine.toBackendName(JobStatus.inProgress), equals('EN_EJECUCION'));
      expect(JobStateMachine.toBackendName(JobStatus.forConfirmation), equals('POR_CONFIRMAR'));
      expect(JobStateMachine.toBackendName(JobStatus.completed), equals('COMPLETADA'));
      expect(JobStateMachine.toBackendName(JobStatus.inDispute), equals('EN_DISPUTA'));
      expect(JobStateMachine.toBackendName(JobStatus.cancelled), equals('CANCELADA'));
      expect(JobStateMachine.toBackendName(JobStatus.refunded), equals('REEMBOLSADA'));

      // From backend string
      expect(JobStateMachine.fromBackendName('BUSCANDO'), equals(JobStatus.searching));
      expect(JobStateMachine.fromBackendName('NEGOCIANDO'), equals(JobStatus.negotiating));
      expect(JobStateMachine.fromBackendName('ACEPTADA'), equals(JobStatus.accepted));
      expect(JobStateMachine.fromBackendName('EN_CAMINO'), equals(JobStatus.onTheWay));
      expect(JobStateMachine.fromBackendName('EN_SITIO'), equals(JobStatus.onSite));
      expect(JobStateMachine.fromBackendName('EN_EJECUCION'), equals(JobStatus.inProgress));
      expect(JobStateMachine.fromBackendName('POR_CONFIRMAR'), equals(JobStatus.forConfirmation));
      expect(JobStateMachine.fromBackendName('COMPLETADA'), equals(JobStatus.completed));
      expect(JobStateMachine.fromBackendName('EN_DISPUTA'), equals(JobStatus.inDispute));
      expect(JobStateMachine.fromBackendName('CANCELADA'), equals(JobStatus.cancelled));
      expect(JobStateMachine.fromBackendName('REEMBOLSADA'), equals(JobStatus.refunded));
    });

    test('Validates all valid transitions according to ALCANCE.md §1 & §4', () {
      // BUSCANDO
      expect(JobStateMachine.canTransition(JobStatus.searching, JobStatus.negotiating), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.searching, JobStatus.cancelled), isTrue);

      // NEGOCIANDO
      expect(JobStateMachine.canTransition(JobStatus.negotiating, JobStatus.accepted), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.negotiating, JobStatus.cancelled), isTrue);

      // ACEPTADA
      expect(JobStateMachine.canTransition(JobStatus.accepted, JobStatus.onTheWay), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.accepted, JobStatus.cancelled), isTrue);

      // EN_CAMINO
      expect(JobStateMachine.canTransition(JobStatus.onTheWay, JobStatus.onSite), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.onTheWay, JobStatus.cancelled), isTrue);

      // EN_SITIO
      expect(JobStateMachine.canTransition(JobStatus.onSite, JobStatus.inProgress), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.onSite, JobStatus.cancelled), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.onSite, JobStatus.inDispute), isTrue);

      // EN_EJECUCION
      expect(JobStateMachine.canTransition(JobStatus.inProgress, JobStatus.forConfirmation), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.inProgress, JobStatus.inDispute), isTrue);

      // POR_CONFIRMAR
      expect(JobStateMachine.canTransition(JobStatus.forConfirmation, JobStatus.completed), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.forConfirmation, JobStatus.inDispute), isTrue);

      // EN_DISPUTA
      expect(JobStateMachine.canTransition(JobStatus.inDispute, JobStatus.completed), isTrue);
      expect(JobStateMachine.canTransition(JobStatus.inDispute, JobStatus.refunded), isTrue);
    });

    test('Rejects invalid transitions and throws InvalidJobTransitionException', () {
      expect(JobStateMachine.canTransition(JobStatus.searching, JobStatus.completed), isFalse);
      expect(JobStateMachine.canTransition(JobStatus.searching, JobStatus.inProgress), isFalse);
      expect(JobStateMachine.canTransition(JobStatus.completed, JobStatus.searching), isFalse);
      expect(JobStateMachine.canTransition(JobStatus.completed, JobStatus.inProgress), isFalse);
      expect(JobStateMachine.canTransition(JobStatus.cancelled, JobStatus.searching), isFalse);
      expect(JobStateMachine.canTransition(JobStatus.refunded, JobStatus.completed), isFalse);
      expect(JobStateMachine.canTransition(JobStatus.forConfirmation, JobStatus.onTheWay), isFalse);

      expect(
        () => JobStateMachine.assertCanTransition(JobStatus.searching, JobStatus.completed),
        throwsA(isA<InvalidJobTransitionException>()),
      );
      expect(
        () => JobStateMachine.assertCanTransition(JobStatus.completed, JobStatus.inProgress),
        throwsA(isA<InvalidJobTransitionException>()),
      );
    });
  });
}

