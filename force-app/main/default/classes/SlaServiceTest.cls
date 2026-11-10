@IsTest
private class SlaServiceTest {

    private static Account newAccount() {
        Account a = new Account(Name = 'Cliente SLA Teste');
        insert a;
        return a;
    }

    private static Case newCase(Id accountId, String priority) {
        Case c = new Case(Subject = 'Caso SLA', AccountId = accountId, Prioridade_SLA__c = priority);
        insert c;
        return c;
    }

    @IsTest
    static void processNameFollowsPriority() {
        System.assertEquals(SlaService.PROCESS_HIGH, SlaService.processNameFor('Alta'));
        System.assertEquals(SlaService.PROCESS_MEDIUM, SlaService.processNameFor('Media'));
        System.assertEquals(SlaService.PROCESS_LOW, SlaService.processNameFor('Baixa'));
        System.assertEquals(SlaService.PROCESS_MEDIUM, SlaService.processNameFor(null), 'Sem prioridade, o padrão é Média');
    }

    @IsTest
    static void violationOnlyWhenTargetPassedAndNotCompleted() {
        Datetime now = Datetime.now();

        System.assert(SlaService.isViolated(now.addHours(-1), null, now), 'Prazo vencido e aberto é violação');
        System.assert(!SlaService.isViolated(now.addHours(-1), now.addMinutes(-30), now), 'Marco concluído não é violação');
        System.assert(!SlaService.isViolated(now.addHours(2), null, now), 'Prazo que ainda não venceu não é violação');
    }

    @IsTest
    static void vincularEntitlementLinksCaseAndPlatformCreatesMilestones() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = newAccount();
            Case c = newCase(a.Id, 'Media');

            Test.startTest();
            Id entitlementId = SlaService.vincularEntitlement(c.Id);
            Test.stopTest();

            Case linked = [SELECT EntitlementId FROM Case WHERE Id = :c.Id];
            System.assertEquals(entitlementId, linked.EntitlementId, 'O caso deve apontar para o Entitlement da prioridade');
            Integer milestones = [SELECT COUNT() FROM CaseMilestone WHERE CaseId = :c.Id];
            System.assertEquals(2, milestones, 'A plataforma deve criar primeira resposta e resolução');
        }
    }

    @IsTest
    static void vincularEntitlementRejectsCaseWithoutAccount() {
        System.runAs(SlaTestUsers.gestor()) {
            Case c = newCase(null, 'Alta');

            Boolean rejected = false;
            try {
                SlaService.vincularEntitlement(c.Id);
            } catch (IllegalArgumentException e) {
                rejected = true;
            }
            System.assert(rejected, 'Caso sem conta não pode receber SLA');
        }
    }

    @IsTest
    static void vincularEntitlementReusesEntitlementForSameAccountAndPriority() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = newAccount();
            Case first = newCase(a.Id, 'Media');
            Case second = newCase(a.Id, 'Media');

            Id firstId = SlaService.vincularEntitlement(first.Id);
            Id secondId = SlaService.vincularEntitlement(second.Id);

            System.assertEquals(firstId, secondId, 'Mesma conta e prioridade devem usar o mesmo Entitlement');
            System.assertEquals(1, [SELECT COUNT() FROM Entitlement WHERE AccountId = :a.Id]);
        }
    }

    @IsTest
    static void escalarVencidosEscalatesEachMilestoneOnceAndFlagsCase() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = newAccount();
            Case c = newCase(a.Id, 'Media');
            SlaService.vincularEntitlement(c.Id);
            Datetime later = Datetime.now().addDays(2);

            Test.startTest();
            Integer first = SlaService.escalarVencidos(later);
            Integer second = SlaService.escalarVencidos(later);
            Test.stopTest();

            System.assertEquals(2, first, 'Os dois marcos vencidos devem gerar um escalonamento cada');
            System.assertEquals(0, second, 'Nenhum marco pode ser escalonado de novo');
            System.assertEquals(2, [SELECT COUNT() FROM Escalonamento_SLA__c WHERE Caso__c = :c.Id]);
            Case flagged = [SELECT Escalonado__c FROM Case WHERE Id = :c.Id];
            System.assertEquals(true, flagged.Escalonado__c, 'O caso deve ficar marcado como escalonado');
        }
    }

    @IsTest
    static void escalarVencidosIgnoresMilestonesStillInTime() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = newAccount();
            Case c = newCase(a.Id, 'Baixa');
            SlaService.vincularEntitlement(c.Id);

            Integer escalated = SlaService.escalarVencidos(Datetime.now());

            System.assertEquals(0, escalated, 'Marcos com prazo futuro não devem escalonar');
        }
    }

    @IsTest
    static void escalarVencidosHandlesManyCasesInBulk() {
        System.runAs(SlaTestUsers.gestor()) {
            Account a = newAccount();
            Case seed = newCase(a.Id, 'Media');
            Id entitlementId = SlaService.vincularEntitlement(seed.Id);

            List<Case> cases = new List<Case>();
            for (Integer i = 0; i < 100; i++) {
                cases.add(new Case(Subject = 'Lote ' + i, AccountId = a.Id, Prioridade_SLA__c = 'Media', EntitlementId = entitlementId));
            }
            insert cases;

            Datetime later = Datetime.now().addDays(2);
            Integer queriesBefore = Limits.getQueries();
            Integer escalated = SlaService.escalarVencidos(later);
            Integer queriesUsed = Limits.getQueries() - queriesBefore;

            System.assertEquals(202, escalated, '101 casos com dois marcos cada');
            System.assert(queriesUsed <= 8, 'Consultas devem ser em lote. Usadas: ' + queriesUsed);
        }
    }
}