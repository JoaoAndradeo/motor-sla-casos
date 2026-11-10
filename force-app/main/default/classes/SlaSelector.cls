/** Todas as consultas do motor de SLA. Nenhuma consulta fica dentro de loop. */
public with sharing class SlaSelector {

    public static Map<Id, Case> casesById(Set<Id> caseIds) {
        return new Map<Id, Case>([
            SELECT Id, AccountId, EntitlementId, Prioridade_SLA__c
            FROM Case
            WHERE Id IN :caseIds
            WITH USER_MODE
        ]);
    }

    public static Map<String, Id> slaProcessIdsByName(Set<String> names) {
        Map<String, Id> idsByName = new Map<String, Id>();
        for (SlaProcess process : [
            SELECT Id, Name
            FROM SlaProcess
            WHERE Name IN :names
            WITH USER_MODE
        ]) {
            idsByName.put(process.Name, process.Id);
        }
        return idsByName;
    }

    public static Entitlement entitlementFor(Id accountId, Id slaProcessId) {
        List<Entitlement> found = [
            SELECT Id
            FROM Entitlement
            WHERE AccountId = :accountId
              AND SlaProcessId = :slaProcessId
            WITH USER_MODE
            LIMIT 1
        ];
        return found.isEmpty() ? null : found[0];
    }

    public static List<CaseMilestone> milestonesByCase(Id caseId) {
        return [
            SELECT Id, CaseId, MilestoneType.Name, TargetDate, CompletionDate
            FROM CaseMilestone
            WHERE CaseId = :caseId
            WITH USER_MODE
            ORDER BY TargetDate
        ];
    }

    /** Marcos ainda abertos cujo prazo já passou em relação a 'now'. */
    public static List<CaseMilestone> openMilestonesPastTarget(Datetime now) {
        return [
            SELECT Id, CaseId, MilestoneType.Name, TargetDate, CompletionDate
            FROM CaseMilestone
            WHERE CompletionDate = null
              AND TargetDate < :now
            WITH USER_MODE
        ];
    }

    public static Set<String> existingEscalationKeys(Set<String> keys) {
        Set<String> found = new Set<String>();
        for (Escalonamento_SLA__c escalation : [
            SELECT Chave_Marco__c
            FROM Escalonamento_SLA__c
            WHERE Chave_Marco__c IN :keys
            WITH USER_MODE
        ]) {
            found.add(escalation.Chave_Marco__c);
        }
        return found;
    }
}