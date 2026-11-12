/**
 * Called ONCE after the external system has verified an import's results.
 * A row lock and an explicit state transition make repeated completion
 * notifications idempotent. No trigger invokes Database.executeBatch.
 */
public with sharing class SenvoraImportOrchestrator {
    public class UnknownRunException extends Exception {}
    public class InvalidRunKeyException extends Exception {}

    public class EnqueueResult {
        public String status;
        public String jobId;
        public Boolean wasEnqueued;

        public EnqueueResult(String status, String jobId, Boolean wasEnqueued) {
            this.status = status;
            this.jobId = jobId;
            this.wasEnqueued = wasEnqueued;
        }
    }

    public static EnqueueResult complete(String runKey) {
        if (String.isBlank(runKey) || runKey.length() > 80) {
            throw new InvalidRunKeyException('runKey must contain 1-80 characters.');
        }

        // Serialize requests for the same run. The unique external ID prevents
        // two run records with the same key.
        List<Senvora_Import_Run__c> runs = [
            SELECT Id, Run_Key__c, Status__c, Batch_Job_Id__c
            FROM Senvora_Import_Run__c
            WHERE Run_Key__c = :runKey
            LIMIT 1
            FOR UPDATE
        ];
        if (runs.isEmpty()) {
            throw new UnknownRunException('Import run not found.');
        }

        Senvora_Import_Run__c runRecord = runs[0];
        if (runRecord.Status__c != 'Ready') {
            return new EnqueueResult(
                runRecord.Status__c, runRecord.Batch_Job_Id__c, false
            );
        }

        // One Batch for the entire import, not one Batch per Opportunity.
        Id jobId = Database.executeBatch(
            new SenvoraAccountRecalcBatch(runRecord.Id, runKey), 100
        );
        update as user new Senvora_Import_Run__c(
            Id = runRecord.Id,
            Status__c = 'Queued',
            Batch_Job_Id__c = String.valueOf(jobId)
        );

        // Enqueued jobs do not execute if this transaction rolls back.
        return new EnqueueResult('Queued', String.valueOf(jobId), true);
    }
}
