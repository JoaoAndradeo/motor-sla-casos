/**
 * Roda o escalonamento de marcos vencidos a cada hora.
 * O agendamento não é feito pelo deploy: é uma decisão separada, tomada por quem administra a org.
 */
public with sharing class SlaEscalationJob implements Schedulable {

    public static final String JOB_NAME = 'Motor SLA - escalonamento horario';
    public static final String CRON_HOURLY = '0 0 * * * ?';

    public void execute(SchedulableContext context) {
        SlaService.escalarVencidos(Datetime.now());
    }

    /** Agenda o job de hora em hora. Chamar uma única vez por org. */
    public static Id agendar() {
        return System.schedule(JOB_NAME, CRON_HOURLY, new SlaEscalationJob());
    }
}