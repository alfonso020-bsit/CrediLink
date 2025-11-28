import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, updateDoc, doc, orderBy, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';

export interface CashProduct {
  id?: string;
  items: any[];
  total: number;
  paymentMethod: 'cash';
  amountPaid: number;
  change: number;
  status: 'completed';
  receipt_image: string;
  created_at: any;
  employee_id: string;
  store_owner_id: string;
  customerName?: string;
  customerPhone?: string;
}

export interface DebtProduct {
  id?: string;
  firestoreId?: string;
  items: any[];
  total: number;
  paymentMethod: 'debt';
  customerName: string;
  customerPhone: string;
  dueDate: any;
  status: 'pending' | 'paid' | 'overdue';
  receipt_image: string;
  created_at: any;
  store_owner_id: string;
  employee_id: string;
  initialPayment?: number;
  remainingBalance?: number;
  originalTotal?: number;
  payment_status: 'unpaid' | 'partially_paid' | 'paid';
  payments?: PaymentHistory[];
  [key: string]: any;
}

export interface PaymentHistory {
  amount: number;
  paymentDate: any;
  receipt_image?: string;
  paid_by?: string;
  notes?: string;
}

@Component({
  selector: 'app-tab2',
  templateUrl: './tab2.page.html',
  styleUrls: ['./tab2.page.scss'],
  standalone: false,
})
export class Tab2Page implements OnInit {
  cashProducts: CashProduct[] = [];
  debtProducts: DebtProduct[] = [];
  
  selectedCashProduct: CashProduct | null = null;
  selectedDebtProduct: DebtProduct | null = null;
  
  showCashReceiptModal = false;
  showDebtReceiptModal = false;
  showPaymentModal = false;
  
  segmentValue: 'cash' | 'debt' = 'cash';
  
  // Payment modal properties
  paymentAmount: number = 0;
  paymentNotes: string = '';
  selectedDebtForPayment: DebtProduct | null = null;
  
  // Search and filter
  searchTerm: string = '';
  statusFilter: string = 'all';

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private modalController: ModalController,
    private alertController: AlertController
  ) { }

  async ngOnInit() {
    await this.loadSalesData();
  }

  async loadSalesData() {
    const loading = await this.loadingController.create({
      message: 'Loading sales data...'
    });
    await loading.present();

    try {
      await Promise.all([
        this.loadCashProducts(),
        this.loadDebtProducts()
      ]);
    } catch (error) {
      console.error('Error loading sales data:', error);
      this.showToast('Error loading sales data', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  async loadCashProducts() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
      
      if (!storeOwnerId) {
        throw new Error('User not authenticated');
      }

      const cashProductsRef = collection(this.firestore, 'cash_products');
      
      // Simple query without composite index requirements
      const q = query(
        cashProductsRef,
        where('store_owner_id', '==', storeOwnerId)
        // Removed orderBy to avoid composite index requirement
      );
      
      const querySnapshot = await getDocs(q);
      
      // Sort manually on the client side
      this.cashProducts = querySnapshot.docs
        .map(doc => ({
          id: doc.id,
          ...doc.data()
        } as CashProduct))
        .sort((a, b) => {
          const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
          const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
          return dateB.getTime() - dateA.getTime(); // Descending order
        });

      console.log(`Loaded ${this.cashProducts.length} cash products`);
    } catch (error) {
      console.error('Error loading cash products:', error);
      // Fallback: try to load without filters
      await this.loadCashProductsFallback();
    }
  }

  async loadCashProductsFallback() {
    try {
      const cashProductsRef = collection(this.firestore, 'cash_products');
      const querySnapshot = await getDocs(cashProductsRef);
      
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
      
      // Filter manually on client side
      this.cashProducts = querySnapshot.docs
        .map(doc => ({
          id: doc.id,
          ...doc.data()
        } as CashProduct))
        .filter(product => product.store_owner_id === storeOwnerId)
        .sort((a, b) => {
          const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
          const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
          return dateB.getTime() - dateA.getTime();
        });

      console.log(`Loaded ${this.cashProducts.length} cash products (fallback)`);
    } catch (error) {
      console.error('Error in cash products fallback:', error);
      this.cashProducts = [];
    }
  }

async loadDebtProducts() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    if (!storeOwnerId) {
      throw new Error('User not authenticated');
    }

    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    const q = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    const querySnapshot = await getDocs(q);
    
    this.debtProducts = querySnapshot.docs
      .map(doc => {
        const data = doc.data();
        
        // FIX: Check if remainingBalance exists, don't use || with data['total']
        const remainingBalance = data['remainingBalance'] !== undefined 
          ? data['remainingBalance'] 
          : data['total'] || 0;

        // Create complete DebtProduct object with all required properties
        const debtProduct: DebtProduct = {
          // Required properties from Firestore data
          items: data['items'] || [],
          total: data['total'] || 0,
          paymentMethod: data['paymentMethod'] || 'debt',
          customerName: data['customerName'] || '',
          customerPhone: data['customerPhone'] || '',
          dueDate: data['dueDate'] || null,
          status: data['status'] || 'pending',
          receipt_image: data['receipt_image'] || '',
          created_at: data['created_at'] || null,
          store_owner_id: data['store_owner_id'] || '',
          employee_id: data['employee_id'] || '',
          payment_status: data['payment_status'] || 'unpaid',
          
          // Optional properties
          id: data['id'], // Custom receipt ID from document data
          firestoreId: doc.id, // Firestore document ID
          initialPayment: data['initialPayment'] || 0,
          remainingBalance: remainingBalance, // Use the fixed calculation
          originalTotal: data['originalTotal'] || data['total'] || 0,
          payments: data['payments'] || []
        };

        // DEBUG LOG - Enhanced to show the actual values
        console.log('📋 Loaded Debt Product:', {
          customId: debtProduct.id,
          firestoreId: debtProduct.firestoreId,
          customer: debtProduct.customerName,
          total: debtProduct.total,
          initialPayment: debtProduct.initialPayment,
          remainingBalance: debtProduct.remainingBalance,
          payment_status: debtProduct.payment_status,
          status: debtProduct.status,
          firestoreRemainingBalance: data['remainingBalance'], // Actual value from Firestore
          firestorePaymentStatus: data['payment_status'] // Actual value from Firestore
        });
        
        return debtProduct;
      })
      .sort((a, b) => {
        const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
        const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
        return dateB.getTime() - dateA.getTime();
      });

    console.log(`Loaded ${this.debtProducts.length} debt products`);
  } catch (error) {
    console.error('Error loading debt products:', error);
    await this.loadDebtProductsFallback();
  }
}

async loadDebtProductsFallback() {
  try {
    const debtProductsRef = collection(this.firestore, 'debt_products');
    const querySnapshot = await getDocs(debtProductsRef);
    
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    // Filter manually on client side
    this.debtProducts = querySnapshot.docs
      .map(doc => {
        const data = doc.data();
        
        // FIX: Same fix for fallback method
        const remainingBalance = data['remainingBalance'] !== undefined 
          ? data['remainingBalance'] 
          : data['total'] || 0;

        const debtProduct: DebtProduct = {
          items: data['items'] || [],
          total: data['total'] || 0,
          paymentMethod: data['paymentMethod'] || 'debt',
          customerName: data['customerName'] || '',
          customerPhone: data['customerPhone'] || '',
          dueDate: data['dueDate'] || null,
          status: data['status'] || 'pending',
          receipt_image: data['receipt_image'] || '',
          created_at: data['created_at'] || null,
          store_owner_id: data['store_owner_id'] || '',
          employee_id: data['employee_id'] || '',
          payment_status: data['payment_status'] || 'unpaid',
          id: data['id'],
          firestoreId: doc.id,
          initialPayment: data['initialPayment'] || 0,
          remainingBalance: remainingBalance, // Use the fixed calculation
          originalTotal: data['originalTotal'] || data['total'] || 0,
          payments: data['payments'] || []
        };

        console.log('📋 Fallback Loaded Debt Product:', {
          customId: debtProduct.id,
          customer: debtProduct.customerName,
          total: debtProduct.total,
          remainingBalance: debtProduct.remainingBalance,
          payment_status: debtProduct.payment_status,
          firestoreRemainingBalance: data['remainingBalance']
        });
        
        return debtProduct;
      })
      .filter(product => product.store_owner_id === storeOwnerId)
      .sort((a, b) => {
        const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
        const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
        return dateB.getTime() - dateA.getTime();
      });

    console.log(`Loaded ${this.debtProducts.length} debt products (fallback)`);
  } catch (error) {
    console.error('Error in debt products fallback:', error);
    this.debtProducts = [];
  }
}

//  updateDebtStatuses() {
//   const now = new Date();
  
//   console.log('🔄 updateDebtStatuses - Checking all debts:');
  
//   this.debtProducts.forEach(debt => {
//     console.log('🔍 Checking debt:', {
//       customer: debt.customerName,
//       initialPayment: debt.initialPayment,
//       remainingBalance: debt.remainingBalance,
//       currentPaymentStatus: debt.payment_status
//     });

//     // Update payment_status based on remaining balance
//     if (debt.remainingBalance !== undefined) {
//       if (debt.remainingBalance <= 0) {
//         debt.payment_status = 'paid';
//         console.log('✅ Setting to PAID - no balance remaining');
//       } else if (debt.initialPayment && debt.initialPayment > 0) {
//         debt.payment_status = 'partially_paid';
//         console.log('🟡 Setting to PARTIALLY_PAID - has initial payment');
//       } else {
//         debt.payment_status = 'unpaid';
//         console.log('🔴 Setting to UNPAID - no payments made');
//       }
//     }
    
//     // Update status based on due date
//     if (debt.dueDate) {
//       const dueDate = debt.dueDate.toDate ? debt.dueDate.toDate() : new Date(debt.dueDate);
//       if (dueDate < now && debt.payment_status !== 'paid') {
//         debt.status = 'overdue';
//         console.log('⏰ Setting to OVERDUE - past due date');
//       } else if (debt.payment_status === 'paid') {
//         debt.status = 'paid';
//         console.log('✅ Setting status to PAID - fully paid');
//       } else {
//         debt.status = 'pending';
//         console.log('⏳ Setting status to PENDING - not due yet');
//       }
//     }

//     console.log('📊 Final status:', {
//       payment_status: debt.payment_status,
//       status: debt.status
//     });
//     console.log('---');
//   });
// }

  // Cash Products Methods
  viewCashReceipt(cashProduct: CashProduct) {
    this.selectedCashProduct = cashProduct;
    this.showCashReceiptModal = true;
  }

  closeCashReceiptModal() {
    this.showCashReceiptModal = false;
    this.selectedCashProduct = null;
  }

  // Debt Products Methods
  viewDebtReceipt(debtProduct: DebtProduct) {
    this.selectedDebtProduct = debtProduct;
    this.showDebtReceiptModal = true;
  }

  closeDebtReceiptModal() {
    this.showDebtReceiptModal = false;
    this.selectedDebtProduct = null;
  }

// Enhanced openPaymentModal with explicit modal state management
openPaymentModal(debtProduct: DebtProduct): void {
  console.log('💳 Opening payment modal for:', debtProduct.customerName);
  
  // CRITICAL: Ensure all other modals are closed first
  this.showCashReceiptModal = false;
  this.showDebtReceiptModal = false;
  
  try {
    // Create a deep copy to avoid reference issues
    this.selectedDebtForPayment = JSON.parse(JSON.stringify(debtProduct));
    
    // Ensure selectedDebtForPayment is not null before accessing properties
    if (!this.selectedDebtForPayment) {
      throw new Error('Failed to create debt copy');
    }
    
    // Ensure all required fields exist
    if (this.selectedDebtForPayment.remainingBalance === undefined || 
        this.selectedDebtForPayment.remainingBalance === null) {
      this.selectedDebtForPayment.remainingBalance = this.selectedDebtForPayment.total;
    }
    
    if (!this.selectedDebtForPayment.originalTotal) {
      this.selectedDebtForPayment.originalTotal = this.selectedDebtForPayment.total;
    }
    
    // Set payment amount to remaining balance
    const remainingBalance = this.selectedDebtForPayment.remainingBalance ?? this.selectedDebtForPayment.total;
    this.paymentAmount = remainingBalance > 0 ? remainingBalance : 0;
    this.paymentNotes = '';
    
    // Small delay to ensure other modals are dismissed
    setTimeout(() => {
      this.showPaymentModal = true;
      console.log('✅ Payment modal state set to true');
    }, 100);
    
    console.log('📊 Payment modal data prepared:', {
      customer: this.selectedDebtForPayment.customerName,
      remainingBalance: this.selectedDebtForPayment.remainingBalance,
      paymentAmount: this.paymentAmount,
      modalState: this.showPaymentModal
    });
    
  } catch (error) {
    console.error('❌ Error in openPaymentModal:', error);
    this.showToast('Error opening payment modal', 'danger');
  }
}

// Enhanced openPaymentModalFromDebtReceipt
async openPaymentModalFromDebtReceipt(debtProduct: DebtProduct): Promise<void> {
  console.log('💳 Opening payment modal from debt receipt for:', debtProduct.customerName);
  
  try {
    // Store the debt product data FIRST (before closing anything)
    const debtCopy: DebtProduct = JSON.parse(JSON.stringify(debtProduct));
    
    // Ensure all required fields exist
    if (debtCopy.remainingBalance === undefined || debtCopy.remainingBalance === null) {
      debtCopy.remainingBalance = debtCopy.total;
    }
    
    if (!debtCopy.originalTotal) {
      debtCopy.originalTotal = debtCopy.total;
    }
    
    // Prepare the payment data
    this.selectedDebtForPayment = debtCopy;
    this.paymentAmount = debtCopy.remainingBalance > 0 ? debtCopy.remainingBalance : 0;
    this.paymentNotes = '';
    
    console.log('📋 Payment data prepared, closing debt modal...');
    
    // Close the debt receipt modal
    this.showDebtReceiptModal = false;
    this.selectedDebtProduct = null;
    
    // Wait longer for modal animation to complete
    await new Promise(resolve => setTimeout(resolve, 400));
    
    console.log('🔄 Opening payment modal...');
    
    // Now open the payment modal
    this.showPaymentModal = true;
    
    // Verify modal opened
    setTimeout(() => {
      console.log('🔍 Modal verification:', {
        showPaymentModal: this.showPaymentModal,
        selectedDebtForPayment: !!this.selectedDebtForPayment,
        customerName: this.selectedDebtForPayment?.customerName
      });
    }, 100);
    
    console.log('✅ Payment modal opened successfully');
    
  } catch (error) {
    console.error('❌ Error in openPaymentModalFromDebtReceipt:', error);
    this.showToast('Error opening payment modal', 'danger');
  }
}

// Enhanced closePaymentModal
closePaymentModal(): void {
  console.log('🔒 Closing payment modal');
  this.showPaymentModal = false;
  
  // Delay clearing data to allow modal animation
  setTimeout(() => {
    this.selectedDebtForPayment = null;
    this.paymentAmount = 0;
    this.paymentNotes = '';
    console.log('✅ Payment modal data cleared');
  }, 300);
}

// Enhanced debug method
debugPaymentModal(): void {
  const debugInfo = {
    'Modal State': this.showPaymentModal,
    'Has Debt Selected': !!this.selectedDebtForPayment,
    'Customer Name': this.selectedDebtForPayment?.customerName || 'N/A',
    'Payment Amount': this.paymentAmount,
    'Max Payment': this.maxPaymentAmount,
    'Remaining Balance': this.selectedDebtForPayment?.remainingBalance || 0,
    'Total Debt': this.selectedDebtForPayment?.total || 0,
    'Firestore ID': this.selectedDebtForPayment?.firestoreId || 'N/A'
  };
  
  console.log('🔍 ===== PAYMENT MODAL DEBUG INFO =====');
  console.table(debugInfo);
  console.log('Full Debt Object:', this.selectedDebtForPayment);
  console.log('=====================================');
  
  // Also show in alert for easier viewing
  this.alertController.create({
    header: 'Payment Modal Debug',
    message: Object.entries(debugInfo)
      .map(([key, value]) => `${key}: ${value}`)
      .join('<br>'),
    buttons: ['Close']
  }).then(alert => alert.present());
}

// Updated getter with proper null safety
get maxPaymentAmount(): number {
  if (!this.selectedDebtForPayment) {
    console.log('❌ maxPaymentAmount: No debt selected');
    return 0;
  }
  
  // Store in local variable after null check
  const debt = this.selectedDebtForPayment;
  const remaining = debt.remainingBalance ?? debt.total ?? 0;
  const max = remaining > 0 ? remaining : debt.total ?? 0;
  
  console.log('📊 maxPaymentAmount calculated:', max);
  return max;
}

  async processPayment() {
    if (!this.selectedDebtForPayment) return;

    // Validate payment amount
    const maxAmount = this.selectedDebtForPayment.remainingBalance || this.selectedDebtForPayment.total;
    if (this.paymentAmount <= 0 || this.paymentAmount > maxAmount) {
      this.showToast('Invalid payment amount', 'warning');
      return;
    }

    const loading = await this.loadingController.create({
      message: 'Processing payment...'
    });
    await loading.present();

    try {
      await this.recordDebtPayment(
        this.selectedDebtForPayment, 
        this.paymentAmount, 
        this.paymentNotes
      );
      
      this.closePaymentModal();
      this.showToast('Payment recorded successfully!', 'success');
      
    } catch (error) {
      console.error('Error processing payment:', error);
      this.showToast('Error processing payment', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

async recordDebtPayment(debtProduct: DebtProduct, amount: number, notes?: string) {
  try {
    // Make sure we're using the correct document ID
    if (!debtProduct.firestoreId) {
      throw new Error('Debt product Firestore ID is missing');
    }

    console.log('🔍 DEBUG recordDebtPayment:', {
      customId: debtProduct.id,
      firestoreId: debtProduct.firestoreId,
      customer: debtProduct.customerName,
      currentBalance: debtProduct.remainingBalance,
      paymentAmount: amount
    });

    const { doc, getDoc, updateDoc, Timestamp, collection, query, where, getDocs } = await import('@angular/fire/firestore');
    
    // Use the Firestore document ID (firestoreId) to update
    const debtProductRef = doc(this.firestore, 'debt_products', debtProduct.firestoreId);
    
    // Check if document exists before updating
    const docSnapshot = await getDoc(debtProductRef);
    if (!docSnapshot.exists()) {
      console.error('❌ Document not found with firestoreId:', debtProduct.firestoreId);
      throw new Error(`Debt product document not found: ${debtProduct.firestoreId}`);
    }

    console.log('✅ Document found, proceeding with update...');
    
    // Calculate new remaining balance
    const currentBalance = debtProduct.remainingBalance || debtProduct.total;
    const newBalance = currentBalance - amount;
    
    if (newBalance < 0) {
      throw new Error('Payment amount cannot exceed remaining balance');
    }

    // Create payment history entry
    const paymentHistory: PaymentHistory = {
      amount: amount,
      paymentDate: Timestamp.now(),
      paid_by: this.authService.getCurrentUser()?.full_name || 'Employee',
      ...(notes && { notes: notes })
    };

    // Get current payments array from the document snapshot
    const currentData = docSnapshot.data();
    const currentPayments = currentData['payments'] || [];
    const updatedPayments = [...currentPayments, paymentHistory];

    // Determine new payment status
    const newPaymentStatus = newBalance <= 0 ? 'paid' : 'partially_paid';

    // Update debt product
    const updateData: any = {
      remainingBalance: newBalance,
      payment_status: newPaymentStatus,
      status: newBalance <= 0 ? 'paid' : debtProduct.status,
      payments: updatedPayments,
      updated_at: Timestamp.now()
    };

    // If this is the first payment, also set initialPayment
    if (currentPayments.length === 0 && debtProduct.initialPayment === 0) {
      updateData.initialPayment = amount;
    }

    console.log('📝 Updating with data:', updateData);

    await updateDoc(debtProductRef, updateData);
    console.log('✅ Payment recorded successfully for debt product:', debtProduct.id);
    console.log('🔄 New payment_status:', newPaymentStatus);

    // Reload debt products to reflect changes
    await this.loadDebtProducts();

  } catch (error) {
    console.error('❌ Error recording debt payment:', error);
    
    // More detailed error logging
    if (error instanceof Error) {
      console.error('Error details:', {
        message: error.message,
        customId: debtProduct.id,
        firestoreId: debtProduct.firestoreId,
        stack: error.stack
      });
    }
    
    throw error;
  }
}

  getStatusColor(status: string): string {
    switch (status) {
      case 'completed':
      case 'paid':
        return 'success';
      case 'pending':
        return 'warning';
      case 'overdue':
        return 'danger';
      default:
        return 'medium';
    }
  }

  getPaymentStatusColor(paymentStatus: string): string {
    switch (paymentStatus) {
      case 'paid':
        return 'success';
      case 'partially_paid':
        return 'warning';
      case 'unpaid':
        return 'danger';
      default:
        return 'medium';
    }
  }

  formatDate(date: any): string {
    if (!date) return 'N/A';
    
    try {
      const jsDate = date.toDate ? date.toDate() : new Date(date);
      return jsDate.toLocaleDateString('en-PH', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  }

  formatCurrency(amount: number): string {
    return `₱${amount?.toFixed(2) || '0.00'}`;
  }

  get filteredCashProducts(): CashProduct[] {
    let filtered = this.cashProducts;

    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(product => 
        product.customerName?.toLowerCase().includes(term) ||
        product.id?.toLowerCase().includes(term) ||
        this.formatCurrency(product.total).toLowerCase().includes(term)
      );
    }

    return filtered;
  }

  get filteredDebtProducts(): DebtProduct[] {
    let filtered = this.debtProducts;

    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(product => 
        product.customerName?.toLowerCase().includes(term) ||
        product.customerPhone?.toLowerCase().includes(term) ||
        product.id?.toLowerCase().includes(term)
      );
    }

    if (this.statusFilter !== 'all') {
      filtered = filtered.filter(product => 
        this.statusFilter === 'overdue' ? 
        product.status === 'overdue' : 
        product.payment_status === this.statusFilter
      );
    }

    return filtered;
  }

  async doRefresh(event: any) {
    await this.loadSalesData();
    event.target.complete();
  }

  private async showToast(message: string, color: string) {
    const toast = await this.toastController.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }
  // Add these methods to your Tab2Page component

// Manual refresh method
async doRefreshManual() {
  const loading = await this.loadingController.create({
    message: 'Refreshing data...',
    duration: 3000
  });
  
  await loading.present();
  
  try {
    await this.loadSalesData();
    this.showToast('Data refreshed successfully', 'success');
  } catch (error) {
    console.error('Error refreshing data:', error);
    this.showToast('Error refreshing data', 'danger');
  } finally {
    await loading.dismiss();
  }
}

// Segment change handler
segmentChanged() {
  this.loadSalesData();
}

// Search change handler
searchChanged() {
  // Debounce search to improve performance
  clearTimeout(this.searchTimeout);
  this.searchTimeout = setTimeout(() => {
    // The getters filteredCashProducts and filteredDebtProducts 
    // will automatically update the view
  }, 300);
}

// Filter change handler
filterChanged() {
  // The getters will automatically update the view
}

// TrackBy functions for better performance
trackByCashId(index: number, item: CashProduct): string {
  return item.id || index.toString();
}

trackByDebtId(index: number, item: DebtProduct): string {
  return item.firestoreId || item.id || index.toString();
}

// Summary calculation methods
getTodayCashTotal(): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  return this.cashProducts
    .filter(product => {
      const productDate = product.created_at?.toDate ? product.created_at.toDate() : new Date(product.created_at);
      productDate.setHours(0, 0, 0, 0);
      return productDate.getTime() === today.getTime();
    })
    .reduce((total, product) => total + product.total, 0);
}

getTodayCashCount(): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  return this.cashProducts.filter(product => {
    const productDate = product.created_at?.toDate ? product.created_at.toDate() : new Date(product.created_at);
    productDate.setHours(0, 0, 0, 0);
    return productDate.getTime() === today.getTime();
  }).length;
}

getTotalOutstanding(): number {
  return this.debtProducts
    .filter(debt => debt.payment_status !== 'paid')
    .reduce((total, debt) => total + (debt.remainingBalance || debt.total), 0);
}

getDebtCountByStatus(status: string): number {
  return this.debtProducts.filter(debt => debt.payment_status === status).length;
}

// Image error handler
handleImageError(event: any, type: 'cash' | 'debt') {
  console.log('Image load error:', event);
  event.target.style.display = 'none';
}

// Share receipt functionality (placeholder)
async shareReceipt(product: any) {
  // This would integrate with your sharing service
  this.showToast('Share functionality would be implemented here', 'primary');
}

// Add this property to your component class
searchTimeout: any;
}