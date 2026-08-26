const MAX_CASE_IDS = 50;
const SALESFORCE_CASE_ID_PATTERN = /^500[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?$/;

type ValidationResult =
  | { valid: true; caseIds: string[] }
  | { valid: false; message: string };

export function validateLookupRequest(body: unknown): ValidationResult {
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    return invalid("The request body must be a JSON object.");
  }

  const caseIds = (body as Record<string, unknown>).caseIds;

  if (!Array.isArray(caseIds)) {
    return invalid("caseIds must be an array.");
  }

  if (caseIds.length === 0) {
    return invalid("caseIds must contain at least one element.");
  }

  if (caseIds.length > MAX_CASE_IDS) {
    return invalid(`caseIds must contain no more than ${MAX_CASE_IDS} elements.`);
  }

  for (let index = 0; index < caseIds.length; index += 1) {
    const caseId = caseIds[index];

    if (typeof caseId !== "string" || caseId.length === 0) {
      return invalid(`caseIds[${index}] must be a non-empty string.`);
    }

    if (!SALESFORCE_CASE_ID_PATTERN.test(caseId)) {
      return invalid(`caseIds[${index}] must be a valid Salesforce Case ID.`);
    }
  }

  return { valid: true, caseIds };
}

function invalid(message: string): ValidationResult {
  return { valid: false, message };
}
