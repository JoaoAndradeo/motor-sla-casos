import { createElement } from 'lwc';
import SlaMarcos from 'c/slaMarcos';
import { refreshApex } from '@salesforce/apex';
import getMarcos from '@salesforce/apex/CaseController.getMarcos';
import vincularSla from '@salesforce/apex/CaseController.vincularSla';

jest.mock(
    '@salesforce/apex/CaseController.getMarcos',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return { default: createApexTestWireAdapter(jest.fn()) };
    },
    { virtual: true }
);
jest.mock('@salesforce/apex/CaseController.vincularSla', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex', () => ({ refreshApex: jest.fn(() => Promise.resolve()) }), { virtual: true });

// eslint-disable-next-line @lwc/lwc/no-async-operation
const flushPromises = () => new Promise((resolve) => setTimeout(resolve, 0));

const CASE_ID = '500000000000001';

const MARCOS = [
    { nome: 'Primeira_Resposta', prazo: '2026-11-11T13:00:00.000Z', concluido: false, violado: true },
    { nome: 'Resolucao', prazo: '2026-11-12T13:00:00.000Z', concluido: false, violado: false }
];

function mount() {
    const element = createElement('c-sla-marcos', { is: SlaMarcos });
    element.recordId = CASE_ID;
    document.body.appendChild(element);
    return element;
}

function situacoes(element) {
    return [...element.shadowRoot.querySelectorAll('lightning-badge')].map((badge) => badge.label);
}

describe('c-sla-marcos', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('lista os marcos com nome legivel e situacao', async () => {
        const element = mount();
        getMarcos.emit(MARCOS);
        await flushPromises();

        const nomes = [...element.shadowRoot.querySelectorAll('.marco-nome')].map((p) => p.textContent);
        expect(nomes).toEqual(['Primeira Resposta', 'Resolucao']);
        expect(situacoes(element)).toEqual(['Prazo vencido', 'Dentro do prazo']);
    });

    it('marca o marco concluido como concluido, mesmo com prazo passado', async () => {
        const element = mount();
        getMarcos.emit([{ ...MARCOS[0], concluido: true, violado: false }]);
        await flushPromises();

        expect(situacoes(element)).toEqual(['Concluído']);
    });

    it('mostra um resumo quando ha marcos vencidos', async () => {
        const element = mount();
        getMarcos.emit(MARCOS);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.resumo-violacao').textContent).toBe('1 marco com prazo vencido');
    });

    it('nao mostra o resumo quando todos estao no prazo', async () => {
        const element = mount();
        getMarcos.emit([MARCOS[1]]);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.resumo-violacao')).toBeNull();
    });

    it('oferece vincular o SLA quando o caso nao tem marcos', async () => {
        const element = mount();
        getMarcos.emit([]);
        await flushPromises();

        expect(element.shadowRoot.querySelector('.sem-sla')).toBeTruthy();
        expect(element.shadowRoot.querySelector('.botao-vincular')).toBeTruthy();
    });

    it('vincula o SLA e recarrega os marcos', async () => {
        vincularSla.mockResolvedValue('550000000000001');
        const element = mount();
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        getMarcos.emit([]);
        await flushPromises();

        element.shadowRoot.querySelector('.botao-vincular').click();
        await flushPromises();

        expect(vincularSla).toHaveBeenCalledWith({ caseId: CASE_ID });
        expect(refreshApex).toHaveBeenCalledTimes(1);
        expect(toastHandler.mock.calls[0][0].detail.variant).toBe('success');
    });

    it('mostra o erro do Apex ao vincular', async () => {
        vincularSla.mockRejectedValue({ body: { message: 'O caso precisa de uma conta para receber SLA.' } });
        const element = mount();
        const toastHandler = jest.fn();
        element.addEventListener('lightning__showtoast', toastHandler);
        getMarcos.emit([]);
        await flushPromises();

        element.shadowRoot.querySelector('.botao-vincular').click();
        await flushPromises();

        const toast = toastHandler.mock.calls[0][0].detail;
        expect(toast.variant).toBe('error');
        expect(toast.message).toBe('O caso precisa de uma conta para receber SLA.');
        expect(refreshApex).not.toHaveBeenCalled();
    });

    it('mostra o erro quando a carga dos marcos falha', async () => {
        const element = mount();
        getMarcos.error({ message: 'Não foi possível carregar os marcos de SLA.' });
        await flushPromises();

        expect(element.shadowRoot.querySelector('.error-message').textContent).toBe(
            'Não foi possível carregar os marcos de SLA.'
        );
        expect(element.shadowRoot.querySelector('.botao-vincular')).toBeNull();
    });
});
