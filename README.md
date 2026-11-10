# Motor de SLA e Escalonamento de Casos

Controle de prazo de atendimento por prioridade no Service Cloud. Cada caso recebe o SLA da sua prioridade, a plataforma acompanha os marcos (primeira resposta e resolução) e o escalonamento abre um registro e uma tarefa para o dono do caso quando um marco vence.

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

## Testes

- 155 testes na DevEd, todos passando.
- Cobertura agregada das classes do motor: 93,8%.
- `SlaEscalationJob` tem teste para a execução e para o agendamento.
- Os testes rodam como um usuário com o permission set `Gestor_SLA` (`SlaTestUsers`), não como administrador. Assim, pegam erros de permissão de campo que um admin não veria.
- Os testes não dependem de dados existentes: cada um cria os próprios registros.

Para testar o escalonamento sem esperar o prazo, o teste chama `escalarVencidos` com uma data à frente da atual. O mesmo truque foi usado na validação manual da DevEd.

Análise estática: `sf code-analyzer run --target force-app --rule-selector Recommended`. Não há ocorrências críticas nem altas (severidade 1 ou 2). As de severidade 3 e 4 são documentação ApexDoc e mensagens de asserção.

## Limitações

- **Sem tela de painel no repositório.** `CaseController` já expõe `getMarcos` e `vincularSla`, mas o componente LWC que mostra os marcos não foi incluído.
- **Fechar o caso não conclui os marcos.** A API 68 não permite configurar esse critério de conclusão no Entitlement Process. Por isso, a regra "marco concluído não escalona" depende de `CompletionDate` preenchido por outro meio, e não tem teste automatizado.
- **Notificação para o dono, não para a fila.** `Fila_Destino__c` é um texto (`Gestao_SLA`), não uma fila real.
- **Cobertura de `CaseController` em 81%.** Os dois `catch` genéricos não são testados.
- **Sem Knowledge e sem Omni-Channel.** Não estavam disponíveis na org usada.
- **Assunto da tarefa com o nome técnico do marco** (`Primeira_Resposta`).

## Decisões

Este projeto não tem documento de decisões separado. As escolhas estão descritas aqui:

- **Entitlement Process em vez de marcos por Apex:** a plataforma bloqueia a criação de `CaseMilestone` por código.
- **Chave externa em `Escalonamento_SLA__c`:** torna o escalonamento idempotente. Rodar o job duas vezes não gera registros duplicados.
- **Job não agendado pelo deploy:** agendar é uma decisão operacional, não de código. Ela fica com quem administra a org.
- **Camadas `Selector`, `Service` e `Controller`:** consulta, regra e interface ficam separadas, e a regra pode ser testada sem a tela.