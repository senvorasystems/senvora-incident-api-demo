export interface Incident {
  id: string;
  status: string;
  severity: string;
  title: string;
  description: string;
}

export interface IncidentLookupResult {
  caseId: string;
  found: boolean;
  incident: Incident | null;
}

const incidentsBySalesforceCaseId: Readonly<Record<string, Incident>> = {
  "500ak000033teGKAAY": {
    id: "INC-2026-0001",
    status: "Investigating",
    severity: "High",
    title: "GC5060 electrical installation issue",
    description:
      "Engineering is investigating an electrical installation issue associated with the referenced Salesforce Case.",
  },
};

export function lookupIncidents(caseIds: readonly string[]): IncidentLookupResult[] {
  return caseIds.map((caseId) => {
    const incident = incidentsBySalesforceCaseId[caseId];

    return {
      caseId,
      found: incident !== undefined,
      incident: incident ?? null,
    };
  });
}
