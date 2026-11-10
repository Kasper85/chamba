import 'job_request.dart';

class InvalidJobTransitionException implements Exception {
  final JobStatus from;
  final JobStatus to;
  final String message;

  InvalidJobTransitionException(this.from, this.to)
      : message = 'Transición no válida de ${from.name} a ${to.name} según ALCANCE.md §1 & §4.';

  @override
  String toString() => 'InvalidJobTransitionException: $message';
}

/// Máquina de estados centralizada para el ciclo de vida de una chamba (ALCANCE.md §1).
class JobStateMachine {
  static const Map<JobStatus, Set<JobStatus>> _validTransitions = {
    JobStatus.searching: {
      JobStatus.negotiating,
      JobStatus.cancelled,
    },
    JobStatus.negotiating: {
      JobStatus.accepted,
      JobStatus.cancelled,
    },
    JobStatus.accepted: {
      JobStatus.onTheWay,
      JobStatus.cancelled,
    },
    JobStatus.onTheWay: {
      JobStatus.onSite,
      JobStatus.cancelled,
    },
    JobStatus.onSite: {
      JobStatus.inProgress,
      JobStatus.cancelled,
      JobStatus.inDispute,
    },
    JobStatus.inProgress: {
      JobStatus.forConfirmation,
      JobStatus.inDispute,
    },
    JobStatus.forConfirmation: {
      JobStatus.completed,
      JobStatus.inDispute,
    },
    JobStatus.inDispute: {
      JobStatus.completed,
      JobStatus.refunded,
    },
    JobStatus.completed: {},
    JobStatus.cancelled: {},
    JobStatus.refunded: {},
  };

  /// Retorna si la transición de [current] a [next] es permitida por la spec.
  static bool canTransition(JobStatus current, JobStatus next) {
    final allowed = _validTransitions[current];
    return allowed != null && allowed.contains(next);
  }

  /// Valida la transición lanzando [InvalidJobTransitionException] si no es válida.
  static void assertCanTransition(JobStatus current, JobStatus next) {
    if (!canTransition(current, next)) {
      throw InvalidJobTransitionException(current, next);
    }
  }

  /// Mapea el enum de Flutter al nombre canónico del backend (ALCANCE.md §1).
  static String toBackendName(JobStatus status) {
    switch (status) {
      case JobStatus.searching:
        return 'BUSCANDO';
      case JobStatus.negotiating:
        return 'NEGOCIANDO';
      case JobStatus.accepted:
        return 'ACEPTADA';
      case JobStatus.onTheWay:
        return 'EN_CAMINO';
      case JobStatus.onSite:
        return 'EN_SITIO';
      case JobStatus.inProgress:
        return 'EN_EJECUCION';
      case JobStatus.forConfirmation:
        return 'POR_CONFIRMAR';
      case JobStatus.completed:
        return 'COMPLETADA';
      case JobStatus.inDispute:
        return 'EN_DISPUTA';
      case JobStatus.cancelled:
        return 'CANCELADA';
      case JobStatus.refunded:
        return 'REEMBOLSADA';
    }
  }

  /// Parsea cualquier variante de string (UPPERCASE o camelCase) a [JobStatus].
  static JobStatus fromBackendName(String name) {
    final normalized = name.trim().toUpperCase();
    switch (normalized) {
      case 'BUSCANDO':
      case 'SEARCHING':
        return JobStatus.searching;
      case 'NEGOCIANDO':
      case 'NEGOTIATING':
        return JobStatus.negotiating;
      case 'ACEPTADA':
      case 'ACCEPTED':
        return JobStatus.accepted;
      case 'EN_CAMINO':
      case 'ON_THE_WAY':
      case 'ONTHEWAY':
        return JobStatus.onTheWay;
      case 'EN_SITIO':
      case 'ON_SITIO':
      case 'ON_SITE':
      case 'ONSITE':
        return JobStatus.onSite;
      case 'EN_EJECUCION':
      case 'IN_PROGRESS':
      case 'INPROGRESS':
      case 'IN_EXECUTION':
        return JobStatus.inProgress;
      case 'POR_CONFIRMAR':
      case 'FOR_CONFIRMATION':
      case 'FORCONFIRMATION':
        return JobStatus.forConfirmation;
      case 'COMPLETADA':
      case 'COMPLETED':
        return JobStatus.completed;
      case 'EN_DISPUTA':
      case 'IN_DISPUTE':
      case 'INDISPUTE':
        return JobStatus.inDispute;
      case 'CANCELADA':
      case 'CANCELLED':
        return JobStatus.cancelled;
      case 'REEMBOLSADA':
      case 'REFUNDED':
        return JobStatus.refunded;
      default:
        throw ArgumentError('Estado de chamba desconocido: $name');
    }
  }
}

