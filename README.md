# Motor de SLA e Escalonamento de Casos

Controle de prazo de atendimento por prioridade no Service Cloud. Cada caso recebe o SLA da sua prioridade, a plataforma acompanha os marcos (primeira resposta e resolução) e o escalonamento abre um registro e uma tarefa para o dono do caso quando um marco vence.

## Por que importa

Prazo sem controle vira promessa quebrada: o cliente espera, e ninguém percebe o atraso até ele reclamar. O motor torna o prazo visível por prioridade e age sozinho quando um marco vence.

## Ganho

- Prazo padronizado por prioridade, sem depender da memória de cada atendente.
- Escalonamento automático com tarefa para o dono do caso, em vez de descobrir os atrasos em relatório depois.
- Histórico em `Escalonamento_SLA__c`: dá para medir quantas vezes um marco venceu, e em qual prioridade.
- Mudar um prazo é configuração no Entitlement Process, não reescrita de código.

## Como funciona

1. O atendente define `Prioridade_SLA__c` no caso (Alta, Média ou Baixa).
2. `SlaService.vincularEntitlement` vincula o caso ao Entitlement da prioridade. Se a conta ainda não tem esse Entitlement, ele é criado.
3. A plataforma cria os marcos a partir do Entitlement Process da prioridade.
4. Um job roda de hora em hora e chama `SlaService.escalarVencidos`. Para cada marco vencido e ainda aberto, cria um `Escalonamento_SLA__c` e marca o caso como escalonado.
5. O Flow `Escalonamento_SLA_Tarefa` abre uma tarefa de prioridade alta para o dono do caso.

## Por que os prazos vêm do Entitlement Process

A plataforma não permite criar `CaseMilestone` por Apex. Os prazos ficam no metadado, em três processos (`Suporte_SLA_Alta`, `Suporte_SLA_Media`, `Suporte_SLA_Baixa`), e o código cuida só da vinculação e do escalonamento. Para mudar um prazo, edite o processo correspondente.

Uma nova versão do processo não altera os casos que já estão vinculados.

## Estrutura

```
force-app/main/default/
├── classes/
│   ├── SlaSelector.cls          consultas (WITH USER_MODE, sem SOQL em loop)
│   ├── SlaService.cls           regras: prioridade, vínculo, violação e escalonamento
│   ├── SlaEscalationJob.cls     job agendável (hora em hora)
│   ├── CaseController.cls       endpoints @AuraEnabled para a tela do caso
│   └── *Test.cls                testes, com SlaTestUsers para rodar como gestor
├── entitlementProcesses/        três processos, um por prioridade
├── milestoneTypes/              Primeira_Resposta e Resolucao
├── flows/
│   └── Escalonamento_SLA_Tarefa Cria a tarefa para o dono do caso
├── objects/
│   ├── Case/fields/             Prioridade_SLA__c, Escalonado__c, Data_Escalonamento__c
│   └── Escalonamento_SLA__c/    registro de cada escalonamento, com chave única por marco
└── permissionsets/
    ├── Gestor_SLA               gestão: vincula SLA e vê os escalonamentos
    └── Agente_Atendimento       somente leitura
```

`Escalonamento_SLA__c` tem `Chave_Marco__c` como chave externa única. Um marco escalonado não é escalonado de novo, mesmo que o job rode outra vez.

## Instalação

Pré-requisitos: Salesforce CLI e uma Developer Edition.

```bash
sf org login web --alias DevEd --set-default --instance-url https://login.salesforce.com
sf project deploy validate --source-dir force-app --target-org DevEd --test-level RunLocalTests
sf project deploy start --source-dir force-app --target-org DevEd --test-level RunLocalTests
sf org assign permset --name Gestor_SLA --target-org DevEd
```

Use `validate` antes do `start`. Ele mostra erros de metadado e de teste sem alterar a org.

**Agendamento:** o deploy não agenda o job. Para ativar o escalonamento de hora em hora, rode uma vez no Developer Console (Execute Anonymous):

```apex
SlaEscalationJob.agendar();
```

Para desativar, abort o job em *Setup → Scheduled Jobs*.
