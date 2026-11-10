/** Dados de SLA para o painel do caso. */
public with sharing class CaseController {

    @AuraEnabled
    public static List<MarcoView> getMarcos(Id caseId) {
        try {
            Datetime now = Datetime.now();
            List<MarcoView> views = new List<MarcoView>();
            for (CaseMilestone milestone : SlaSelector.milestonesByCase(caseId)) {
                MarcoView view = new MarcoView();
                view.nome = milestone.MilestoneType.Name;
                view.prazo = milestone.TargetDate;
                view.concluido = milestone.CompletionDate != null;
                view.violado = SlaService.isViolated(milestone.TargetDate, milestone.CompletionDate, now);
                views.add(view);
            }
            return views;
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível carregar os marcos de SLA.');
        }
    }

    @AuraEnabled
    public static Id vincularSla(Id caseId) {
        try {
            return SlaService.vincularEntitlement(caseId);
        } catch (IllegalArgumentException e) {
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Não foi possível vincular o SLA ao caso.');
        }
    }

    public class MarcoView {
        @AuraEnabled public String nome;
        @AuraEnabled public Datetime prazo;
        @AuraEnabled public Boolean concluido;
        @AuraEnabled public Boolean violado;
    }
}