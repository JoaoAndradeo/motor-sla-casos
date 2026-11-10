@IsTest
private class SlaEscalationJobTest {

    @IsTest
    static void executeEscalatesOverdueMilestones() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = new Account(Name = 'Cliente Job');
            insert a;
            Case c = new Case(Subject = 'Job SLA', AccountId = a.Id, Prioridade_SLA__c = 'Alta');
            insert c;
            SlaService.vincularEntitlement(c.Id);

            Test.startTest();
            new SlaEscalationJob().execute(null);
            Test.stopTest();

            // Os marcos ainda estão no prazo: nada deve ser escalonado agora.
            System.assertEquals(0, [SELECT COUNT() FROM Escalonamento_SLA__c WHERE Caso__c = :c.Id]);
        }
    }

    @IsTest
    static void agendarRegistersHourlyJob() {
        System.runAs(SlaTestUsers.gestor()) {
            Test.startTest();
            Id jobId = SlaEscalationJob.agendar();
            Test.stopTest();

            CronTrigger scheduled = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
            System.assertEquals(SlaEscalationJob.CRON_HOURLY, scheduled.CronExpression);
        }
    }
}