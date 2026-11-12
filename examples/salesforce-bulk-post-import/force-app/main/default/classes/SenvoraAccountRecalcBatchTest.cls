@IsTest
private class SenvoraAccountRecalcBatchTest {
    @IsTest
    static void processesTwoAccountsOnlyOnceWithTwoHundredOpportunities() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'SENVORA Training Account A'),
            new Account(Name = 'SENVORA Training Account B')
        };
        insert accounts;

        String won = [
            SELECT MasterLabel FROM OpportunityStage
            WHERE IsWon = true AND IsActive = true LIMIT 1
        ].MasterLabel;
        String open = [
            SELECT MasterLabel FROM OpportunityStage
            WHERE IsWon = false AND IsActive = true LIMIT 1
        ].MasterLabel;
        String runKey = 'SAP-TRAINING-200';

        Senvora_Import_Run__c runRecord = new Senvora_Import_Run__c(
            Run_Key__c = runKey,
            Status__c = 'Ready'
        );
        insert runRecord;

        List<Opportunity> opportunities = new List<Opportunity>();
        for (Integer i = 0; i < 200; i++) {
            opportunities.add(new Opportunity(
                Name = 'Imported opportunity ' + i,
                AccountId = i < 190 ? accounts[0].Id : accounts[1].Id,
                StageName = i % 2 == 0 ? won : open,
                CloseDate = Date.today().addDays(30),
                Senvora_Import_Run_Key__c = runKey
            ));
        }
        insert opportunities;

        // An older won Opportunity must also count in Account A's total.
        insert new Opportunity(
            Name = 'Older won opportunity',
            AccountId = accounts[0].Id,
            StageName = won,
            CloseDate = Date.today(),
            Senvora_Import_Run_Key__c = 'PREVIOUS-RUN'
        );

        Test.startTest();
        SenvoraImportOrchestrator.EnqueueResult first =
            SenvoraImportOrchestrator.complete(runKey);
        SenvoraImportOrchestrator.EnqueueResult repeated =
            SenvoraImportOrchestrator.complete(runKey);
        System.assertEquals(true, first.wasEnqueued);
        System.assertEquals(false, repeated.wasEnqueued);
        System.assertEquals(first.jobId, repeated.jobId);
        Test.stopTest();

        Set<Id> accountIds = new Set<Id>{accounts[0].Id, accounts[1].Id};
        Map<Id, Account> results = new Map<Id, Account>([
            SELECT Id, Senvora_Won_Opportunity_Count__c
            FROM Account WHERE Id IN :accountIds
        ]);
        // Account A: 95 won among 190 imported + 1 older = 96.
        System.assertEquals(
            Decimal.valueOf('96'),
            results.get(accounts[0].Id).Senvora_Won_Opportunity_Count__c
        );
        // Account B: 5 won among 10 imported.
        System.assertEquals(
            Decimal.valueOf('5'),
            results.get(accounts[1].Id).Senvora_Won_Opportunity_Count__c
        );

        Senvora_Import_Run__c completed = [
            SELECT Status__c, Updated_Accounts__c, Failed_Accounts__c,
                Failed_Scopes__c, Completed_At__c, Batch_Job_Id__c
            FROM Senvora_Import_Run__c WHERE Id = :runRecord.Id
        ];
        System.assertEquals('Completed', completed.Status__c);
        System.assertEquals(Decimal.valueOf('2'), completed.Updated_Accounts__c);
        System.assertEquals(Decimal.valueOf('0'), completed.Failed_Accounts__c);
        System.assertEquals(Decimal.valueOf('0'), completed.Failed_Scopes__c);
        System.assertNotEquals(null, completed.Completed_At__c);
        System.assertEquals(first.jobId, completed.Batch_Job_Id__c);
    }

    @IsTest
    static void noMatchingOpportunitiesCompletesWithoutUpdates() {
        Senvora_Import_Run__c runRecord = new Senvora_Import_Run__c(
            Run_Key__c = 'SAP-EMPTY-RUN',
            Status__c = 'Ready'
        );
        insert runRecord;

        Test.startTest();
        SenvoraImportOrchestrator.complete(runRecord.Run_Key__c);
        Test.stopTest();

        Senvora_Import_Run__c completed = [
            SELECT Status__c, Updated_Accounts__c, Failed_Accounts__c
            FROM Senvora_Import_Run__c WHERE Id = :runRecord.Id
        ];
        System.assertEquals('Completed', completed.Status__c);
        System.assertEquals(Decimal.valueOf('0'), completed.Updated_Accounts__c);
        System.assertEquals(Decimal.valueOf('0'), completed.Failed_Accounts__c);
    }

    @IsTest
    static void rejectsUnknownRun() {
        Boolean didThrow = false;
        try {
            SenvoraImportOrchestrator.complete('RUN-NOT-REGISTERED');
        } catch (SenvoraImportOrchestrator.UnknownRunException expected) {
            didThrow = true;
        }
        System.assertEquals(true, didThrow);
    }
}
