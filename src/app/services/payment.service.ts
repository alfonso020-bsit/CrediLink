import { Injectable } from '@angular/core';
import { Firestore, doc, updateDoc, Timestamp, collection, addDoc } from '@angular/fire/firestore';
import { AuthService } from './auth.service';

export interface PaymentData {
  debtProductId: string;
  amount: number;
  notes?: string;
  paid_by: string;
  payment_date: any;
}

export interface PaymentHistory {
  amount: number;
  paymentDate: any;
  receipt_image?: string;
  paid_by?: string;
  notes?: string;
}

@Injectable({
  providedIn: 'root'
})
export class PaymentService {

  constructor(
    private firestore: Firestore,
    private authService: AuthService
  ) { }

  async recordDebtPayment(
    debtProductId: string, 
    amount: number, 
    currentBalance: number,
    notes?: string
  ): Promise<void> {
    try {
      const debtProductRef = doc(this.firestore, 'debt_products', debtProductId);
      const currentUser = this.authService.getCurrentUser();
      
      const newBalance = currentBalance - amount;
      
      if (newBalance < 0) {
        throw new Error('Payment amount cannot exceed remaining balance');
      }

      // Create payment history entry
      const paymentHistory: PaymentHistory = {
        amount: amount,
        paymentDate: Timestamp.now(),
        paid_by: currentUser?.full_name || 'Employee',
        ...(notes && { notes: notes })
      };

      // Get current debt product to update payments array
      const updateData: any = {
        remainingBalance: newBalance,
        payment_status: newBalance <= 0 ? 'paid' : 'partially_paid',
        status: newBalance <= 0 ? 'paid' : 'pending'
      };

      // Add to payments array
      updateData['payments'] = [...(updateData['payments'] || []), paymentHistory];

      await updateDoc(debtProductRef, updateData);

      // Also record in separate payments collection for reporting
      await this.recordPaymentInCollection({
        debtProductId,
        amount,
        notes,
        paid_by: currentUser?.full_name || 'Employee',
        payment_date: Timestamp.now()
      });

    } catch (error) {
      console.error('Error recording debt payment:', error);
      throw error;
    }
  }

  private async recordPaymentInCollection(paymentData: PaymentData): Promise<void> {
    try {
      const paymentsRef = collection(this.firestore, 'payments');
      await addDoc(paymentsRef, paymentData);
    } catch (error) {
      console.error('Error recording payment in collection:', error);
      // Don't throw error here as the main payment was already recorded
    }
  }

  async getPaymentHistory(debtProductId: string): Promise<PaymentHistory[]> {
    try {
      const debtProductRef = doc(this.firestore, 'debt_products', debtProductId);
      // In a real implementation, you would fetch the document and return payments array
      // For now, return empty array
      return [];
    } catch (error) {
      console.error('Error getting payment history:', error);
      return [];
    }
  }

  calculatePaymentStatus(remainingBalance: number, initialPayment?: number): string {
    if (remainingBalance <= 0) {
      return 'paid';
    } else if (initialPayment && initialPayment > 0) {
      return 'partially_paid';
    } else {
      return 'unpaid';
    }
  }

  validatePaymentAmount(amount: number, remainingBalance: number): boolean {
    return amount > 0 && amount <= remainingBalance;
  }
}