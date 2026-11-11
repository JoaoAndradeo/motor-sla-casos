import { LightningElement, api, wire } from 'lwc';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getMarcos from '@salesforce/apex/CaseController.getMarcos';
import vincularSla from '@salesforce/apex/CaseController.vincularSla';

const GENERIC_ERROR = 'Não foi possível concluir a ação. Tente novamente.';

function extractMessage(error) {
    if (error && error.body && error.body.message) {
        return error.body.message;
    }
    if (error && typeof error.message === 'string') {
        return error.message;
    }
    return GENERIC_ERROR;
}

function decorate(marco) {
    let situacao = 'Dentro do prazo';
    let variante = 'success';
    let icone = 'utility:clock';

    if (marco.concluido) {
        situacao = 'Concluído';
        variante = 'inverse';
        icone = 'utility:check';
    } else if (marco.violado) {
        situacao = 'Prazo vencido';
        variante = 'error';
        icone = 'utility:warning';
    }

    return {
        ...marco,
        key: marco.nome,
        rotulo: marco.nome.replace(/_/g, ' '),
        situacao,
        variante,
        icone,
        classe: 'slds-box slds-box_small slds-m-bottom_x-small marco marco_' + variante
    };
}

export default class SlaMarcos extends LightningElement {
    @api recordId;

    marcos = [];
    errorMessage;
    isWorking = false;
    carregou = false;
    wiredMarcos;

    @wire(getMarcos, { caseId: '$recordId' })
    handleMarcos(result) {
        this.wiredMarcos = result;
        if (result.data) {
            this.marcos = result.data.map(decorate);
            this.errorMessage = undefined;
            this.carregou = true;
        } else if (result.error) {
            this.marcos = [];
            this.errorMessage = extractMessage(result.error);
            this.carregou = true;
        }
    }

    get isBusy() {
        return this.isWorking || !this.carregou;
    }

    get temMarcos() {
        return this.marcos.length > 0;
    }

    get mostrarVincular() {
        return this.carregou && !this.temMarcos && !this.errorMessage;
    }

    get violados() {
        return this.marcos.filter((marco) => marco.violado).length;
    }

    get temViolacao() {
        return this.violados > 0;
    }

    get resumoViolacao() {
        return this.violados === 1 ? '1 marco com prazo vencido' : this.violados + ' marcos com prazo vencido';
    }

    async vincular() {
        this.isWorking = true;
        try {
            await vincularSla({ caseId: this.recordId });
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'SLA vinculado',
                    message: 'Os marcos de primeira resposta e resolução foram criados para este caso.',
                    variant: 'success'
                })
            );
            await refreshApex(this.wiredMarcos);
        } catch (error) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Não foi possível vincular',
                    message: extractMessage(error),
                    variant: 'error'
                })
            );
        } finally {
            this.isWorking = false;
        }
    }
}
