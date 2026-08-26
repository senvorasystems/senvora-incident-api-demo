import { NextRequest, NextResponse } from "next/server";

import { lookupIncidents } from "@/lib/incidents";
import { validateLookupRequest } from "@/lib/validation";

export const runtime = "nodejs";

const JSON_CONTENT_TYPE = "application/json";

export async function POST(request: NextRequest) {
  try {
    const configuredApiKey = process.env.INCIDENT_API_KEY;

    if (!configuredApiKey) {
      return errorResponse(
        500,
        "SERVICE_CONFIGURATION_ERROR",
        "The service is not configured correctly.",
      );
    }

    if (request.headers.get("x-api-key") !== configuredApiKey) {
      return errorResponse(401, "UNAUTHORIZED", "Authentication failed.");
    }

    if (!request.headers.get("content-type")?.toLowerCase().startsWith(JSON_CONTENT_TYPE)) {
      return invalidRequest("Content-Type must be application/json.");
    }

    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return invalidRequest("The request body must contain valid JSON.");
    }

    const validation = validateLookupRequest(body);
    if (!validation.valid) {
      return invalidRequest(validation.message);
    }

    return NextResponse.json({ results: lookupIncidents(validation.caseIds) });
  } catch {
    return errorResponse(
      500,
      "INTERNAL_ERROR",
      "The service could not process the request.",
    );
  }
}

function invalidRequest(message: string) {
  return errorResponse(400, "INVALID_REQUEST", message);
}

function errorResponse(status: number, code: string, message: string) {
  return NextResponse.json({ error: { code, message } }, { status });
}
