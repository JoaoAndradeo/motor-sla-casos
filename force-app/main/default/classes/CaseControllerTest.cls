@IsTest
private class CaseControllerTest {

    @IsTest
    static void getMarcosListsPlatformMilestones() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = new Account(Name = 'Cliente Painel');
            insert a;
            Case c = new Case(Subject = 'Painel SLA', AccountId = a.Id, Prioridade_SLA__c = 'Media');
            insert c;
            CaseController.vincularSla(c.Id);

            List<CaseController.MarcoView> views = CaseController.getMarcos(c.Id);

            System.assertEquals(2, views.size());
            System.assertEquals(false, views[0].concluido);
            System.assertEquals(false, views[0].violado, 'Prazo ainda não venceu no momento do teste');
        }
    }

    @IsTest
    static void vincularSlaReturnsEntitlementThroughController() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = new Account(Name = 'Cliente Vincular');
            insert a;
            Case c = new Case(Subject = 'Vincular', AccountId = a.Id, Prioridade_SLA__c = 'Alta');
            insert c;

            Id entitlementId = CaseController.vincularSla(c.Id);

            System.assertEquals(entitlementId, [SELECT EntitlementId FROM Case WHERE Id = :c.Id].EntitlementId);
        }
    }

    @IsTest
    static void vincularSlaHidesInternalErrorsFromUser() {
        System.runAs(SlaTestUsers.gestor()) {
            Case c = new Case(Subject = 'Sem conta');
            insert c;

            Boolean rejected = false;
            try {
                CaseController.vincularSla(c.Id);
            } catch (AuraHandledException e) {
                rejected = true;
            }
            System.assert(rejected, 'Caso sem conta deve virar AuraHandledException para a tela');
        }
    }
}