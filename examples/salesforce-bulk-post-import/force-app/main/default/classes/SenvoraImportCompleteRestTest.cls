@IsTest
private class SenvoraImportCompleteRestTest {
    @IsTest
    static void rejectsCallerWithoutCustomPermission() {
        RestRequest request = new RestRequest();
        request.requestURI = '/services/apexrest/senvora/v1/import-complete';
        request.httpMethod = 'POST';
        request.requestBody = Blob.valueOf('{"runKey":"SAP-TEST"}');
        RestContext.request = request;
        RestContext.response = new RestResponse();

        Test.startTest();
        SenvoraImportCompleteRest.complete();
        Test.stopTest();

        System.assertEquals(403, RestContext.response.statusCode);
        String response = RestContext.response.responseBody.toString();
        System.assert(response.contains('Forbidden'));
    }
}
