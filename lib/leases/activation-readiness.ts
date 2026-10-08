import {moveInPreparationKinds, type MoveInPreparationKind} from '@/lib/leases/move-in';

/** Server-loaded evidence only. This assessment grants no tenancy or resident access. */
export type ActivationEvidence = Readonly<{
  currentApproval: boolean;
  heldReservation: boolean;
  execution: Readonly<{verified: boolean; currentDraft: boolean; documentHash: string}> | null;
  deposit: Readonly<{verified: boolean; requiredMinor: number; settledMinor: number; currency: string}> | null;
  preparation: readonly Readonly<{kind: MoveInPreparationKind; version: number; state: string; evidenceReference: string}>[];
}>;

export function activationReadiness(evidence: ActivationEvidence) {
  const blockers: string[] = [];
  if (evidence.currentApproval !== true) blockers.push('current_application_approval');
  if (evidence.heldReservation !== true) blockers.push('held_unit_reservation');
  const execution = evidence.execution;
  if (!execution || execution.verified !== true || execution.currentDraft !== true || !/^[a-f0-9]{64}$/i.test(execution.documentHash)) blockers.push('verified_current_execution');
  const deposit = evidence.deposit;
  if (!deposit || deposit.verified !== true || deposit.currency !== 'JMD' || !Number.isSafeInteger(deposit.requiredMinor) || deposit.requiredMinor < 0 || !Number.isSafeInteger(deposit.settledMinor) || deposit.settledMinor < deposit.requiredMinor) blockers.push('verified_deposit');
  for (const kind of moveInPreparationKinds) {
    const rows = evidence.preparation.filter(row => row.kind === kind);
    const valid = rows.every(row => Number.isSafeInteger(row.version) && row.version > 0);
    const latestVersion = valid && rows.length ? Math.max(...rows.map(row => row.version)) : 0;
    const latest = rows.filter(row => row.version === latestVersion);
    if (!valid || latest.length !== 1 || latest[0].state !== 'ready' || latest[0].evidenceReference.trim().length < 5) blockers.push(`preparation_${kind}`);
  }
  return Object.freeze({eligible: blockers.length === 0, blockers: Object.freeze(blockers)});
}
