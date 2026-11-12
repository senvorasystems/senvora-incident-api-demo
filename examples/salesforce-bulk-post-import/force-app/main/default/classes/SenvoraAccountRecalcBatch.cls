/**
 * Recalculates Accounts affected by ONE completed external import.
 *
 * Important: the QueryLocator returns distinct Accounts, not Opportunities.
 * Multiple imported Opportunities referencing the same Account therefore do
 * not generate repeated Account updates within this job.
 */
public with sharing class SenvoraAccountRecalcBatch
    implements Database.Batchable<Account>, Database.Stateful {

    private Id runRecordId;
    private String runKey;
    private Integer updatedAccounts = 0;
    private Integer failedAccounts = 0;
    private List<String> errorSamples = new List<String>();

    public SenvoraAccountRecalcBatch(Id runRecordId, String runKey) {
        this.runRecordId = runRecordId;
        this.runKey = runKey;
    }

    public Database.QueryLocator start(Database.BatchableContext context) {
        return Database.getQueryLocator([
            SELECT Id
            FROM Account
            WHERE Id IN (
                SELECT AccountId
                FROM Opportunity
                WHERE Senvora_Import_Run_Key__c = :runKey
            )
        ]);
    }

    public void execute(Database.BatchableContext context, List<Account> scope) {
        if (scope.isEmpty()) {
            return;
        }

        Set<Id> accountIds = new Set<Id>();
        for (Account accountRecord : scope) {
            accountIds.add(accountRecord.Id);
        }

        // Count ALL won Opportunities on each affected Account, not only those
        // belonging to this import. This gives a correct current total.
        Map<Id, Integer> wonCountsByAccount = new Map<Id, Integer>();
        for (AggregateResult result : [
            SELECT AccountId accountId, COUNT(Id) wonCount
            FROM Opportunity
            WHERE AccountId IN :accountIds AND IsWon = true
            GROUP BY AccountId
        ]) {
            wonCountsByAccount.put(
                (Id) result.get('accountId'),
                (Integer) result.get('wonCount')
            );
        }

        List<Account> updates = new List<Account>();
        for (Id accountId : accountIds) {
            Integer countWon = wonCountsByAccount.containsKey(accountId)
                ? wonCountsByAccount.get(accountId)
                : 0;
            updates.add(new Account(
                Id = accountId,
                Senvora_Won_Opportunity_Count__c = countWon
            ));
        }

        // A failed Account does not roll back successful Accounts in this scope.
        // The external import has already committed in earlier transactions.
        Database.SaveResult[] results = Database.update(
            updates, false, AccessLevel.USER_MODE
        );

        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                updatedAccounts++;
            } else {
                failedAccounts++;
                rememberErrors(updates[i].Id, results[i]);
            }
        }
    }

    public void finish(Database.BatchableContext context) {
        AsyncApexJob job = [
            SELECT NumberOfErrors
            FROM AsyncApexJob
            WHERE Id = :context.getJobId()
            LIMIT 1
        ];

        Boolean hasErrors = failedAccounts > 0 || job.NumberOfErrors > 0;
        Senvora_Import_Run__c completedRun = new Senvora_Import_Run__c(
            Id = runRecordId,
            Status__c = hasErrors ? 'CompletedWithErrors' : 'Completed',
            Batch_Job_Id__c = String.valueOf(context.getJobId()),
            Updated_Accounts__c = updatedAccounts,
            Failed_Accounts__c = failedAccounts,
            Failed_Scopes__c = job.NumberOfErrors,
            Completed_At__c = System.now(),
            Error_Samples__c = String.join(errorSamples, '\n')
        );
        update as user completedRun;
    }

    private void rememberErrors(Id accountId, Database.SaveResult result) {
        for (Database.Error errorRecord : result.getErrors()) {
            if (errorSamples.size() >= 5) {
                return;
            }
            String message = String.valueOf(accountId) + ': ' +
                String.valueOf(errorRecord.getStatusCode()) + ' - ' +
                errorRecord.getMessage();
            errorSamples.add(message.length() > 300 ? message.left(300) : message);
        }
    }
}
