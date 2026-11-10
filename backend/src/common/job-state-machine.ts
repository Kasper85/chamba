export enum JobStatus {
  BUSCANDO = 'BUSCANDO',
  NEGOCIANDO = 'NEGOCIANDO',
  ACEPTADA = 'ACEPTADA',
  EN_CAMINO = 'EN_CAMINO',
  EN_SITIO = 'EN_SITIO',
  EN_EJECUCION = 'EN_EJECUCION',
  POR_CONFIRMAR = 'POR_CONFIRMAR',
  COMPLETADA = 'COMPLETADA',
  EN_DISPUTA = 'EN_DISPUTA',
  CANCELADA = 'CANCELADA',
  REEMBOLSADA = 'REEMBOLSADA',
}

export class InvalidJobTransitionException extends Error {
  constructor(public readonly from: JobStatus, public readonly to: JobStatus) {
    super(`Transición no válida de ${from} a ${to} según ALCANCE.md §1 & §4.`);
    this.name = 'InvalidJobTransitionException';
  }
}

export class JobStateMachine {
  private static readonly validTransitions: Readonly<Record<JobStatus, readonly JobStatus[]>> = {
    [JobStatus.BUSCANDO]: [JobStatus.NEGOCIANDO, JobStatus.CANCELADA],
    [JobStatus.NEGOCIANDO]: [JobStatus.ACEPTADA, JobStatus.CANCELADA],
    [JobStatus.ACEPTADA]: [JobStatus.EN_CAMINO, JobStatus.CANCELADA],
    [JobStatus.EN_CAMINO]: [JobStatus.EN_SITIO, JobStatus.CANCELADA],
    [JobStatus.EN_SITIO]: [JobStatus.EN_EJECUCION, JobStatus.CANCELADA, JobStatus.EN_DISPUTA],
    [JobStatus.EN_EJECUCION]: [JobStatus.POR_CONFIRMAR, JobStatus.EN_DISPUTA],
    [JobStatus.POR_CONFIRMAR]: [JobStatus.COMPLETADA, JobStatus.EN_DISPUTA],
    [JobStatus.EN_DISPUTA]: [JobStatus.COMPLETADA, JobStatus.REEMBOLSADA],
    [JobStatus.COMPLETADA]: [],
    [JobStatus.CANCELADA]: [],
    [JobStatus.REEMBOLSADA]: [],
  };

  static canTransition(current: JobStatus, next: JobStatus): boolean {
    const allowed = this.validTransitions[current] || [];
    return allowed.includes(next);
  }

  static assertCanTransition(current: JobStatus, next: JobStatus): void {
    if (!this.canTransition(current, next)) {
      throw new InvalidJobTransitionException(current, next);
    }
  }
}

