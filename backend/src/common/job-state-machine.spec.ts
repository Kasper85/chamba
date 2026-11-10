import { describe, it, expect } from 'vitest';
import { JobStatus, JobStateMachine, InvalidJobTransitionException } from './job-state-machine.js';

describe('Loop L1: Backend JobStateMachine', () => {
  it('JobStatus enum defines all 11 states from ALCANCE.md §1', () => {
    expect(JobStatus.BUSCANDO).toBe('BUSCANDO');
    expect(JobStatus.NEGOCIANDO).toBe('NEGOCIANDO');
    expect(JobStatus.ACEPTADA).toBe('ACEPTADA');
    expect(JobStatus.EN_CAMINO).toBe('EN_CAMINO');
    expect(JobStatus.EN_SITIO).toBe('EN_SITIO');
    expect(JobStatus.EN_EJECUCION).toBe('EN_EJECUCION');
    expect(JobStatus.POR_CONFIRMAR).toBe('POR_CONFIRMAR');
    expect(JobStatus.COMPLETADA).toBe('COMPLETADA');
    expect(JobStatus.EN_DISPUTA).toBe('EN_DISPUTA');
    expect(JobStatus.CANCELADA).toBe('CANCELADA');
    expect(JobStatus.REEMBOLSADA).toBe('REEMBOLSADA');
  });

  it('validates valid transitions according to ALCANCE.md §1 & §4', () => {
    expect(JobStateMachine.canTransition(JobStatus.BUSCANDO, JobStatus.NEGOCIANDO)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.BUSCANDO, JobStatus.CANCELADA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.NEGOCIANDO, JobStatus.ACEPTADA)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.NEGOCIANDO, JobStatus.CANCELADA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.ACEPTADA, JobStatus.EN_CAMINO)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.ACEPTADA, JobStatus.CANCELADA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.EN_CAMINO, JobStatus.EN_SITIO)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.EN_CAMINO, JobStatus.CANCELADA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.EN_SITIO, JobStatus.EN_EJECUCION)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.EN_SITIO, JobStatus.CANCELADA)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.EN_SITIO, JobStatus.EN_DISPUTA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.EN_EJECUCION, JobStatus.POR_CONFIRMAR)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.EN_EJECUCION, JobStatus.EN_DISPUTA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.POR_CONFIRMAR, JobStatus.COMPLETADA)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.POR_CONFIRMAR, JobStatus.EN_DISPUTA)).toBe(true);

    expect(JobStateMachine.canTransition(JobStatus.EN_DISPUTA, JobStatus.COMPLETADA)).toBe(true);
    expect(JobStateMachine.canTransition(JobStatus.EN_DISPUTA, JobStatus.REEMBOLSADA)).toBe(true);
  });

  it('rejects invalid transitions and throws InvalidJobTransitionException', () => {
    expect(JobStateMachine.canTransition(JobStatus.BUSCANDO, JobStatus.COMPLETADA)).toBe(false);
    expect(JobStateMachine.canTransition(JobStatus.COMPLETADA, JobStatus.BUSCANDO)).toBe(false);
    expect(JobStateMachine.canTransition(JobStatus.CANCELADA, JobStatus.BUSCANDO)).toBe(false);
    expect(JobStateMachine.canTransition(JobStatus.REEMBOLSADA, JobStatus.COMPLETADA)).toBe(false);

    expect(() =>
      JobStateMachine.assertCanTransition(JobStatus.BUSCANDO, JobStatus.COMPLETADA),
    ).toThrow(InvalidJobTransitionException);

    expect(() =>
      JobStateMachine.assertCanTransition(JobStatus.COMPLETADA, JobStatus.EN_EJECUCION),
    ).toThrow(InvalidJobTransitionException);
  });
});

