# SENVORA Incident Demo API

Minimal, controlled REST API used to demonstrate an enterprise integration path between Salesforce Agentforce/Apex and an external incident service. This repository contains demo data only; it is not a production incident system and must not be presented as production-ready.

## Architecture

```text
Salesforce / Agentforce
        |
GetLinkedIncidentAction (implemented separately)
        |
Salesforce Named Credential
        | HTTPS + X-API-Key
SENVORA Incident Demo API
        |
Structured JSON response
```

The integration key is:

```text
External Incident.salesforceCaseId = Salesforce Case.Id
```

The service uses Next.js App Router, TypeScript, the Node.js runtime, and an in-memory demo dataset. It has no database, ORM, authentication framework, or external runtime dependency beyond Next.js.

## Endpoints

### Health

`GET /api/v1/health` requires no authentication and returns HTTP `200`:

```json
{
  "status": "ok",
  "service": "senvora-incident-api-demo"
}
```

### Incident lookup

```http
POST /api/v1/incidents/lookup
Content-Type: application/json
X-API-Key: <secret>
```

Request bodies contain between 1 and 50 Salesforce Case IDs:

```json
{
  "caseIds": ["500ak000033teGKAAY"]
}
```

An authorized, valid lookup always returns HTTP `200`. Every input produces one result in the same position, including duplicate inputs.

Found response:

```json
{
  "results": [
    {
      "caseId": "500ak000033teGKAAY",
      "found": true,
      "incident": {
        "id": "INC-2026-0001",
        "status": "Investigating",
        "severity": "High",
        "title": "GC5060 electrical installation issue",
        "description": "Engineering is investigating an electrical installation issue associated with the referenced Salesforce Case."
      }
    }
  ]
}
```

Not-found response:

```json
{
  "results": [
    {
      "caseId": "500ak000033teGLAAY",
      "found": false,
      "incident": null
    }
  ]
}
```

## Authentication and errors

The lookup endpoint compares `X-API-Key` with `process.env.INCIDENT_API_KEY`. Secrets must never be committed to Git. Missing or incorrect client credentials return HTTP `401` with code `UNAUTHORIZED` and message `Authentication failed.`

If the server variable is absent, the endpoint returns HTTP `500` with `SERVICE_CONFIGURATION_ERROR`. Invalid JSON, content type, request shape, list size, or Case ID returns HTTP `400` with `INVALID_REQUEST`. Unexpected failures return HTTP `500` with `INTERNAL_ERROR`. Responses never include stack traces, exception messages, or secret details.

A Case ID must be an alphanumeric string of 15 or 18 characters beginning with `500`. Salesforce checksum validation is intentionally outside this demo's scope.

## Local setup

Prerequisites: Node.js and npm.

```powershell
npm install
Copy-Item .env.example .env.local
```

Replace the placeholder in `.env.local` with a local demo key. `.env.local` is ignored by Git. Start and validate the service:

```powershell
npm run dev
npm run lint
npm run typecheck
npm run build
```

No test framework was added solely for this small demo. Exercise the API manually while the development server is running.

Health:

```powershell
Invoke-RestMethod -Method Get -Uri 'http://localhost:3000/api/v1/health'
```

Found, not found, ordering, and duplicate preservation:

```powershell
$headers = @{ 'X-API-Key' = 'replace-with-local-demo-key' }
$body = @{
  caseIds = @(
    '500ak000033teGKAAY',
    '500ak000033teGLAAY',
    '500ak000033teGKAAY'
  )
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri 'http://localhost:3000/api/v1/incidents/lookup' `
  -Headers $headers `
  -ContentType 'application/json' `
  -Body $body
```

Unauthorized request:

```powershell
Invoke-WebRequest `
  -SkipHttpErrorCheck `
  -Method Post `
  -Uri 'http://localhost:3000/api/v1/incidents/lookup' `
  -ContentType 'application/json' `
  -Body '{"caseIds":["500ak000033teGKAAY"]}'
```

Equivalent curl lookup:

```bash
curl -X POST http://localhost:3000/api/v1/incidents/lookup \
  -H "Content-Type: application/json" \
  -H "X-API-Key: replace-with-local-demo-key" \
  -d '{"caseIds":["500ak000033teGKAAY","500ak000033teGLAAY"]}'
```

## Vercel deployment

1. Review and commit the project in a repository intended for this service.
2. Import that repository into Vercel as a Next.js project.
3. Add `INCIDENT_API_KEY` as a protected environment variable for the desired Vercel environments.
4. Deploy and configure Salesforce Named Credential to call the HTTPS deployment URL.

Do not place the API key in source code, `.env.example`, Git history, Vercel build output, or Salesforce Apex.

## Demo dataset

- `500ak000033teGKAAY` maps to controlled demo incident `INC-2026-0001`.
- `500ak000033teGLAAY` deliberately has no incident entry and returns `found: false`.
- Every other structurally valid Case ID also returns `found: false`.

These records are fictional demo fixtures and make no claim about a real organization, system, Case, or incident.
