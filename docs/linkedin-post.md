Publiquei no GitHub um projeto de Service Cloud: um motor de SLA e escalonamento de casos.

O caso recebe o SLA da prioridade (Alta, Média ou Baixa). A plataforma acompanha a primeira resposta e a resolução. Quando um marco vence, um job de hora em hora registra o escalonamento e abre uma tarefa para o dono do caso.

Algumas decisões que tomei:

- Os prazos ficam no Entitlement Process, não no Apex. A plataforma não permite criar marcos por código, então a configuração fica no metadado e o código cuida só da vinculação e do escalonamento.
- O registro de escalonamento tem uma chave única por marco. Se o job rodar duas vezes, o mesmo marco não escalona de novo.
- O deploy não agenda o job. Agendar é uma decisão de quem administra a org.
- Os testes rodam com um usuário que tem só o permission set do projeto, não como administrador. Assim pegam erros de permissão de campo que um admin não veria.

Resultado na Developer Edition: 155 testes passando e cobertura de 93,8% nas classes do motor. Sem ocorrências críticas na análise estática.

O que ainda falta: a tela com os marcos no caso não está no repositório, e fechar o caso não conclui os marcos automaticamente. Está tudo no README, na seção de limitações.

Repositório: https://github.com/JoaoGuilherme777/motor-sla-casos

#Salesforce #ServiceCloud #Apex #SLA