import { Component, Input } from '@angular/core';
import { ModalController } from '@ionic/angular';

interface CalendarEvent {
  date: Date;
  type: 'transaction' | 'due_date';
  transactionId: string;
  customerName: string;
  amount: number;
  status: string;
  isOverdue?: boolean;
  debtData?: any;
}

@Component({
  selector: 'app-debt-view',
  templateUrl: './debt-view.component.html',
  styleUrls: ['./debt-view.component.scss'],
  standalone: false,
})
export class DebtViewComponent {
  @Input() debtEvent!: CalendarEvent;
  @Input() storeName: string = '';

  constructor(private modalController: ModalController) {}

  getCustomerInitials(): string {
    if (!this.debtEvent.customerName) return '?';
    
    const names = this.debtEvent.customerName.trim().split(' ');
    if (names.length === 1) {
      return names[0].substring(0, 2).toUpperCase();
    } else {
      const firstInitial = names[0].charAt(0).toUpperCase();
      const lastInitial = names[names.length - 1].charAt(0).toUpperCase();
      return firstInitial + lastInitial;
    }
  }
  // Add this method to your existing DebtViewComponent class
viewTransactionHistory() {
  // Implement transaction history view logic
  console.log('View transaction history for:', this.debtEvent.customerName);
}
  getCustomerColor(): string {
    if (!this.debtEvent.customerName) return '#666666';
    
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    
    const colorIndex = this.debtEvent.customerName.charCodeAt(0) % colors.length;
    return colors[colorIndex];
  }

  getStatusClass(): string {
    switch (this.debtEvent.status) {
      case 'paid': return 'status-paid';
      case 'partially_paid': return 'status-partial';
      case 'unpaid': return this.debtEvent.isOverdue ? 'status-overdue' : 'status-unpaid';
      default: return 'status-unknown';
    }
  }

  getStatusIcon(): string {
    switch (this.debtEvent.status) {
      case 'paid': return 'checkmark-circle';
      case 'partially_paid': return 'time';
      case 'unpaid': return this.debtEvent.isOverdue ? 'warning' : 'alert-circle';
      default: return 'help-circle';
    }
  }

  getStatusText(): string {
    switch (this.debtEvent.status) {
      case 'paid': return 'Fully Paid';
      case 'partially_paid': return 'Partially Paid';
      case 'unpaid': return this.debtEvent.isOverdue ? 'Overdue' : 'Unpaid';
      default: return 'Unknown Status';
    }
  }

  getStatusColor(): string {
    switch (this.debtEvent.status) {
      case 'paid': return 'success';
      case 'partially_paid': return 'warning';
      case 'unpaid': return this.debtEvent.isOverdue ? 'danger' : 'medium';
      default: return 'medium';
    }
  }

  recordPayment() {
    // Implement payment recording logic
    console.log('Record payment for:', this.debtEvent);
  }

  contactCustomer() {
    // Implement customer contact logic
    console.log('Contact customer:', this.debtEvent.customerName);
  }

  dismiss() {
    this.modalController.dismiss();
  }
}