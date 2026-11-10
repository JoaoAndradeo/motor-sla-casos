/** Usuário de teste com o permission set Gestor_SLA. Os testes rodam como esse usuário (runAs). */
@IsTest
public class SlaTestUsers {

    public static User gestor() {
        Profile adminProfile = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            ProfileId = adminProfile.Id,
            LastName = 'Gestor SLA Teste',
            Email = 'gestor.sla.teste@example.com',
            Username = 'gestor.sla.' + Datetime.now().getTime() + '@example.com',
            Alias = 'gsla',
            TimeZoneSidKey = 'America/Sao_Paulo',
            LocaleSidKey = 'pt_BR',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'pt_BR'
        );
        insert u;
        PermissionSet gestorSla = [SELECT Id FROM PermissionSet WHERE Name = 'Gestor_SLA' LIMIT 1];
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = gestorSla.Id);
        return u;
    }
}