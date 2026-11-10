/**
 * Regras do motor de SLA.
 * Os marcos (CaseMilestone) são criados pela plataforma a partir do Entitlement Process.
 * Este serviço vincula o caso ao processo da prioridade e escalona os marcos vencidos.
 */
public with sharing class SlaService {

    public static final String PROCESS_HIGH = 'Suporte_SLA_Alta';
    public static final String PROCESS_MEDIUM = 'Suporte_SLA_Media';
    public static final String PROCESS_LOW = 'Suporte_SLA_Baixa';
    public static final String QUEUE_MANAGERS = 'Gestao_SLA';

    /** Nome do processo de SLA da prioridade. Sem prioridade, usa Média. */
    public static String processNameFor(String priority) {
        if (priority == 'Alta') {
            return PROCESS_HIGH;
        }
        return (priority == 'Baixa') ? PROCESS_LOW : PROCESS_MEDIUM;
    }

    /** Violação: o prazo passou e o marco ainda não foi concluído. */
    public static Boolean isViolated(Datetime targetDate, Datetime completionDate, Datetime now) {
        return completionDate == null && targetDate != null && targetDate < now;
    }

    /**
     * Vincula o caso ao Entitlement da prioridade (criado se ainda não existir para a conta).
     * A plataforma cria os marcos ao gravar o caso com o Entitlement. Devolve o Id do Entitlement.
     */
    public static Id vincularEntitlement(Id caseId) {
        Case theCase = SlaSelector.casesById(new Set<Id>{ caseId }).get(caseId);
        if (theCase == null) {
            throw new IllegalArgumentException('Caso não encontrado ou sem acesso.');
        }
        if (theCase.AccountId == null) {
            throw new IllegalArgumentException('O caso precisa de uma conta para receber SLA.');
        }

        String processName = processNameFor(theCase.Prioridade_SLA__c);
        Id processId = SlaSelector.slaProcessIdsByName(new Set<String>{ processName }).get(processName);
        if (processId == null) {
            throw new IllegalArgumentException('Processo de SLA não encontrado: ' + processName);
        }

        Entitlement entitlement = SlaSelector.entitlementFor(theCase.AccountId, processId);
        if (entitlement == null) {
            entitlement = new Entitlement(
                Name = processName,
                AccountId = theCase.AccountId,
                SlaProcessId = processId
            );
            Database.insert(entitlement, true, AccessLevel.USER_MODE);
        }

        theCase.EntitlementId = entitlement.Id;
        Database.update(theCase, true, AccessLevel.USER_MODE);
        return entitlement.Id;
    }

    /**
     * Escalona os marcos vencidos em 'now'. Um Escalonamento_SLA__c por marco e uma atualização
     * por lote de casos. Devolve quantos escalonamentos foram criados.
     */
    public static Integer escalarVencidos(Datetime now) {
        List<CaseMilestone> overdue = SlaSelector.openMilestonesPastTarget(now);
        if (overdue.isEmpty()) {
            return 0;
        }

        Set<String> keys = new Set<String>();
        for (CaseMilestone milestone : overdue) {
            keys.add(chaveDoMarco(milestone.Id));
        }
        Set<String> alreadyEscalated = SlaSelector.existingEscalationKeys(keys);

        List<Escalonamento_SLA__c> escalations = new List<Escalonamento_SLA__c>();
        for (CaseMilestone milestone : overdue) {
            String key = chaveDoMarco(milestone.Id);
            if (alreadyEscalated.contains(key)) {
                continue;
            }
            escalations.add(new Escalonamento_SLA__c(
                Caso__c = milestone.CaseId,
                Marco__c = milestone.MilestoneType.Name,
                Fila_Destino__c = QUEUE_MANAGERS,
                Data__c = now,
                Chave_Marco__c = key
            ));
        }
        if (escalations.isEmpty()) {
            return 0;
        }

        Database.SaveResult[] results = Database.insert(escalations, false, AccessLevel.USER_MODE);
        Set<Id> flaggedCaseIds = new Set<Id>();
        Integer created = 0;
        for (Integer i = 0; i < results.size(); i++) {
            if (results[i].isSuccess()) {
                created++;
                flaggedCaseIds.add(escalations[i].Caso__c);
            }
        }
        if (flaggedCaseIds.isEmpty()) {
            return 0;
        }

        List<Case> casesToFlag = SlaSelector.casesById(flaggedCaseIds).values();
        for (Case theCase : casesToFlag) {
            theCase.Escalonado__c = true;
            theCase.Data_Escalonamento__c = now;
        }
        Database.update(casesToFlag, false, AccessLevel.USER_MODE);
        return created;
    }

    public static String chaveDoMarco(Id milestoneId) {
        return String.valueOf(milestoneId);
    }
}