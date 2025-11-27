import { Component, Input } from '@angular/core';
import { ModalController } from '@ionic/angular';
import { TransactionReport } from './tab5.page';

@Component({
  selector: 'app-transaction-details-modal',
  templateUrl: './transaction-details-modal.component.html',
  styleUrls: ['./transaction-details-modal.component.scss'],
  standalone: false,
})
export class TransactionDetailsModal {
  @Input() transaction!: TransactionReport;
  @Input() formatDate!: (date: Date) => string;

  constructor(private modalController: ModalController) {}

  async dismiss() {
    try {
      await this.modalController.dismiss();
    } catch (error) {
      console.error('Error dismissing modal:', error);
      const modalElement = document.querySelector('app-transaction-details-modal');
      if (modalElement) {
        modalElement.remove();
      }
    }
  }

  onBackdropClick(event: any) {
    if (event.target === event.currentTarget) {
      this.dismiss();
    }
  }

  getStatusColor(transaction: TransactionReport): string {
    if (transaction.paymentStatus) {
      switch (transaction.paymentStatus) {
        case 'paid': return 'success';
        case 'partially_paid': return 'warning';
        case 'unpaid': return 'danger';
      }
    }
    
    switch (transaction.status) {
      case 'completed': return 'success';
      case 'pending': return 'warning';
      case 'overdue': return 'danger';
      default: return 'medium';
    }
  }

  getStockActionIcon(transaction: TransactionReport): string {
    if (transaction.type !== 'stock') return 'cube';
    
    const action = transaction.stockAction?.toLowerCase() || '';
    if (action.includes('in') || action.includes('increase')) {
      return 'arrow-up';
    } else if (action.includes('out') || action.includes('decrease')) {
      return 'arrow-down';
    }
    return 'swap-vertical';
  }

  getStockActionColor(transaction: TransactionReport): string {
    if (transaction.type !== 'stock') return 'medium';
    
    const action = transaction.stockAction?.toLowerCase() || '';
    if (action.includes('in') || action.includes('increase')) {
      return 'success';
    } else if (action.includes('out') || action.includes('decrease')) {
      return 'warning';
    }
    return 'medium';
  }

  formatDueDate(dueDate: any): string {
    if (dueDate?.toDate) {
      return dueDate.toDate().toLocaleDateString();
    }
    return new Date(dueDate).toLocaleDateString();
  }
}