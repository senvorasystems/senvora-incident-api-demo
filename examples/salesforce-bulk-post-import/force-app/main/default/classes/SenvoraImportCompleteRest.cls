/**
 * External integration calls this REST endpoint only after loading/updating
 * all Opportunities and checking API-level success/failure responses.
 * OAuth, Apex class access, and a custom permission protect the entry point.
 */
@RestResource(urlMapping='/senvora/v1/import-complete')
global with sharing class SenvoraImportCompleteRest {
    @HttpPost
    global static void complete() {
        if (!FeatureManagement.checkPermission('Senvora_Complete_Import')) {
            respond(403, 'Forbidden', null, 'Missing custom permission.');
            return;
        }

        if (RestContext.request == null || RestContext.request.requestBody == null) {
            respond(400, 'BadRequest', null, 'JSON request body is required.');
            return;
        }

        Map<String, Object> requestBody;
        try {
            requestBody = (Map<String, Object>) JSON.deserializeUntyped(
                RestContext.request.requestBody.toString()
            );
        } catch (Exception invalidJson) {
            respond(400, 'BadRequest', null, 'Invalid JSON object.');
            return;
        }

        Object keyValue = requestBody == null ? null : requestBody.get('runKey');
        String runKey = keyValue == null ? '' : String.valueOf(keyValue).trim();
        if (String.isBlank(runKey) || runKey.length() > 80) {
            respond(400, 'BadRequest', null, 'runKey must contain 1-80 characters.');
            return;
        }

        try {
            SenvoraImportOrchestrator.EnqueueResult result =
                SenvoraImportOrchestrator.complete(runKey);
            respond(
                result.wasEnqueued ? 202 : 200,
                result.status,
                result.jobId,
                result.wasEnqueued ? 'Batch queued.' : 'Run already handled.'
            );
        } catch (SenvoraImportOrchestrator.UnknownRunException unknownRun) {
            respond(404, 'NotFound', null, 'Create the import run before completing it.');
        }
    }

    private static void respond(
        Integer statusCode, String state, String jobId, String message
    ) {
        RestContext.response.statusCode = statusCode;
        RestContext.response.addHeader('Content-Type', 'application/json');
        RestContext.response.responseBody = Blob.valueOf(JSON.serialize(
            new Map<String, Object>{
                'status' => state,
                'jobId' => jobId,
                'message' => message
            }
        ));
    }
}
