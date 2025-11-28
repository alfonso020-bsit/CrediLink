import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, updateDoc, doc, orderBy, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';


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
  employeeName?: string;
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
  employeeName?: string;
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

// Add this type declaration after your imports (before the component class)
declare module 'jspdf' {
  interface jsPDF {
    lastAutoTable?: {
      finalY: number;
    };
  }
}

@Component({
  selector: 'app-storeowner-tab2',
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
  searchTimeout: any;

  // Add these properties to your existing component
  showReportModal = false;
  reportType: 'cash' | 'debt' | 'combined' = 'combined';
  reportStartDate: string = '';
  reportEndDate: string = '';
  reportDebtStatus: string = 'all';
  showPreview = false;


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
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) {
      throw new Error('User not authenticated');
    }

    console.log('Loading cash products for store owner:', storeOwnerId);

    const cashProductsRef = collection(this.firestore, 'cash_products');
    
    const q = query(
      cashProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    const querySnapshot = await getDocs(q);
    
    // Load all cash products first
    const cashProducts = querySnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        items: data['items'] || [],
        total: data['total'] || 0,
        paymentMethod: data['paymentMethod'] || 'cash',
        amountPaid: data['amountPaid'] || 0,
        change: data['change'] || 0,
        status: data['status'] || 'completed',
        receipt_image: data['receipt_image'] || '',
        created_at: data['created_at'] || null,
        employee_id: data['employee_id'] || '',
        store_owner_id: data['store_owner_id'] || '',
        customerName: data['customerName'] || '',
        customerPhone: data['customerPhone'] || '',
        employeeName: '' // Will be populated below
      };
    });

    // Get unique employee IDs from all cash products
    const employeeIds = [...new Set(cashProducts.map(product => product.employee_id).filter(id => id))];
    
    // Pre-fetch all employee names
    const employeeNamesMap = await this.getEmployeeNamesMap(employeeIds);
    
    // Assign employee names to each cash product
    this.cashProducts = cashProducts.map(product => ({
      ...product,
      employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
    }));

    // Sort by date (newest first)
    this.cashProducts.sort((a, b) => {
      const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
      const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
      return dateB.getTime() - dateA.getTime();
    });

    console.log(`Loaded ${this.cashProducts.length} cash products for store owner`);
  } catch (error) {
    console.error('Error loading cash products:', error);
    this.cashProducts = [];
  }
}

async loadDebtProducts() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) {
      throw new Error('User not authenticated');
    }

    console.log('Loading debt products for store owner:', storeOwnerId);

    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    const q = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    const querySnapshot = await getDocs(q);
    
    // Load all debt products first
    const debtProducts = querySnapshot.docs.map(doc => {
      const data = doc.data();
      
      // ✅ FIXED: Calculate remainingBalance properly with null safety
      const total = data['total'] || 0;
      const remainingBalance = data['remainingBalance'] ?? total;
      const initialPayment = data['initialPayment'] || 0;
      const payments = data['payments'] || []; // ✅ FIXED: Ensure payments is always an array
      
      // Determine payment_status based on actual data
      let payment_status = data['payment_status'] || 'unpaid';
      if (remainingBalance <= 0) {
        payment_status = 'paid';
      } else if (initialPayment > 0 || payments.length > 0) {
        payment_status = 'partially_paid';
      }
      
      return {
        items: data['items'] || [],
        total: total,
        paymentMethod: data['paymentMethod'] || 'debt',
        customerName: data['customerName'] || '',
        customerPhone: data['customerPhone'] || '',
        dueDate: data['dueDate'] || null,
        status: data['status'] || 'pending',
        receipt_image: data['receipt_image'] || '',
        created_at: data['created_at'] || null,
        store_owner_id: data['store_owner_id'] || '',
        employee_id: data['employee_id'] || '',
        payment_status: payment_status, // ✅ Use calculated status
        id: data['id'] || doc.id,
        firestoreId: doc.id,
        initialPayment: initialPayment,
        remainingBalance: remainingBalance, // ✅ Use calculated remaining balance
        originalTotal: data['originalTotal'] || total,
        payments: payments, // ✅ Now guaranteed to be an array
        employeeName: '' // Will be populated below
      };
    });

    // Get unique employee IDs from all debt products
    const employeeIds = [...new Set(debtProducts.map(product => product.employee_id).filter(id => id))];
    
    // Pre-fetch all employee names
    const employeeNamesMap = await this.getEmployeeNamesMap(employeeIds);
    
    // Assign employee names to each debt product
    this.debtProducts = debtProducts.map(product => ({
      ...product,
      employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
    }));

    // CRITICAL: Update statuses after loading
    this.updateDebtStatuses();
    console.log(`Loaded ${this.debtProducts.length} debt products for store owner`);
    
  } catch (error) {
    console.error('Error loading debt products:', error);
    this.debtProducts = [];
  }
}

// More efficient version that only queries for specific employee IDs
async getEmployeeNamesMap(employeeIds: string[]): Promise<{ [key: string]: string }> {
  const employeeNamesMap: { [key: string]: string } = {};
  
  if (!employeeIds.length) return employeeNamesMap;

  try {
    console.log('🔍 Efficiently fetching employee names for IDs:', employeeIds);
    
    const usersRef = collection(this.firestore, 'all_users');
    
    // Since we can't use 'in' with document IDs directly, we'll query each one
    for (const employeeId of employeeIds) {
      try {
        const userDoc = doc(this.firestore, 'all_users', employeeId);
        const { getDoc } = await import('@angular/fire/firestore');
        const docSnapshot = await getDoc(userDoc);
        
        if (docSnapshot.exists()) {
          const userData = docSnapshot.data();
          const userRole = userData['role'];
          
          if (userRole === 'Employee') {
            const employeeName = userData['full_name'] || userData['name'] || userData['displayName'] || 'Unknown Employee';
            employeeNamesMap[employeeId] = employeeName;
            console.log(`✅ Found employee: ${employeeId} -> ${employeeName}`);
          } else {
            employeeNamesMap[employeeId] = 'Unknown Employee';
            console.log(`❌ User ${employeeId} is not an Employee (Role: ${userRole})`);
          }
        } else {
          employeeNamesMap[employeeId] = 'Unknown Employee';
          console.log(`❌ Employee document ${employeeId} not found`);
        }
      } catch (error) {
        console.error(`Error fetching employee ${employeeId}:`, error);
        employeeNamesMap[employeeId] = 'Unknown Employee';
      }
    }
    
    console.log('✅ Final employee names map:', employeeNamesMap);
    return employeeNamesMap;
    
  } catch (error) {
    console.error('Error in getEmployeeNamesMapEfficient:', error);
    const defaultMap: { [key: string]: string } = {};
    employeeIds.forEach(id => defaultMap[id] = 'Unknown Employee');
    return defaultMap;
  }
}

async getEmployeeName(employeeId: string): Promise<string> {
  if (!employeeId) return 'Unknown Employee';
  
  try {
    console.log('🔍 Fetching employee name for ID:', employeeId);
    
    const employeesRef = collection(this.firestore, 'employees');
    
    // Try multiple possible ID fields since structure might vary
    let q = query(employeesRef, where('id', '==', employeeId));
    let querySnapshot = await getDocs(q);
    
    if (querySnapshot.empty) {
      // Try with document ID
      q = query(employeesRef, where('employee_id', '==', employeeId));
      querySnapshot = await getDocs(q);
    }
    
    if (querySnapshot.empty) {
      // Try with uid field
      q = query(employeesRef, where('uid', '==', employeeId));
      querySnapshot = await getDocs(q);
    }
    
    if (querySnapshot.empty) {
      // Try getting by document ID directly
      const employeeDoc = doc(this.firestore, 'employees', employeeId);
      const docSnapshot = await getDocs(query(collection(this.firestore, 'employees'), where('__name__', '==', employeeId)));
      if (!docSnapshot.empty) {
        querySnapshot = docSnapshot;
      }
    }
    
    if (!querySnapshot.empty) {
      const employeeData = querySnapshot.docs[0].data();
      const employeeName = employeeData['full_name'] || employeeData['name'] || employeeData['displayName'] || 'Unknown Employee';
      console.log('✅ Found employee:', employeeName);
      return employeeName;
    }
    
    console.log('❌ No employee found with ID:', employeeId);
    return 'Unknown Employee';
  } catch (error) {
    console.error('Error fetching employee name:', error);
    return 'Unknown Employee';
  }
}
// Add this method to refresh employee names before generating reports
async refreshEmployeeNamesForReport() {
  console.log('🔄 Refreshing employee names for report...');
  
  // Get all unique employee IDs from both cash and debt products
  const allEmployeeIds = [
    ...new Set([
      ...this.cashProducts.map(p => p.employee_id),
      ...this.debtProducts.map(p => p.employee_id)
    ].filter(id => id))
  ];

  if (allEmployeeIds.length === 0) {
    console.log('No employee IDs found to refresh');
    return;
  }

  const employeeNamesMap = await this.getEmployeeNamesMap(allEmployeeIds);

  // Update cash products
  this.cashProducts = this.cashProducts.map(product => ({
    ...product,
    employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
  }));

  // Update debt products
  this.debtProducts = this.debtProducts.map(product => ({
    ...product,
    employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
  }));

  console.log('✅ Employee names refreshed for report');
}

// updateDebtStatuses() {
//   const now = new Date();
  
//   console.log('🔄 updateDebtStatuses - Checking all debts:');
  
//   this.debtProducts.forEach(debt => {
//     console.log('🔍 Checking debt:', {
//       customer: debt.customerName,
//       remainingBalance: debt.remainingBalance,
//       initialPayment: debt.initialPayment,
//       currentPaymentStatus: debt.payment_status
//     });

//     // CRITICAL: Use the actual remaining balance from Firestore first
//     // If remainingBalance is explicitly set to 0, mark as paid
//     if (debt.remainingBalance === 0) {
//       debt.payment_status = 'paid';
//       debt.status = 'paid';
//       console.log('✅ Setting to PAID - remaining balance is 0');
//     }
//     // Update payment_status based on remaining balance
//     else if (debt.remainingBalance !== undefined && debt.remainingBalance !== null) {
//       if (debt.remainingBalance <= 0) {
//         debt.payment_status = 'paid';
//         debt.status = 'paid';
//         console.log('✅ Setting to PAID - no balance remaining');
//       } else if (debt.initialPayment && debt.initialPayment > 0) {
//         debt.payment_status = 'partially_paid';
//         console.log('🟡 Setting to PARTIALLY_PAID - has initial payment');
//       } else {
//         debt.payment_status = 'unpaid';
//         console.log('🔴 Setting to UNPAID - no payments made');
//       }
//     }
    
//     // Update status based on due date (only if not already paid)
//     if (debt.payment_status !== 'paid' && debt.dueDate) {
//       const dueDate = debt.dueDate.toDate ? debt.dueDate.toDate() : new Date(debt.dueDate);
//       if (dueDate < now) {
//         debt.status = 'overdue';
//         console.log('⏰ Setting to OVERDUE - past due date');
//       } else {
//         debt.status = 'pending';
//         console.log('⏳ Setting status to PENDING - not due yet');
//       }
//     }

//     console.log('📊 Final status:', {
//       payment_status: debt.payment_status,
//       status: debt.status,
//       remainingBalance: debt.remainingBalance
//     });
//     console.log('---');
//   });
// }
updateDebtStatuses() {
  const now = new Date();
  
  console.log('🔄 updateDebtStatuses - Checking all debts:');
  
  this.debtProducts.forEach(debt => {
    // ✅ FIXED: Proper null safety checks with explicit defaults
    const remainingBalance = debt.remainingBalance ?? debt.total ?? 0;
    const initialPayment = debt.initialPayment ?? 0;
    const currentPaymentStatus = debt.payment_status;
    const payments = debt.payments ?? []; // ✅ FIXED: Ensure payments is always an array
    
    console.log('🔍 Checking debt:', {
      customer: debt.customerName,
      remainingBalance: remainingBalance,
      initialPayment: initialPayment,
      currentPaymentStatus: currentPaymentStatus,
      paymentsCount: payments.length,
      firestoreId: debt.firestoreId
    });

    // ✅ FIXED: ALWAYS recalculate payment_status based on remainingBalance
    // This ensures UI consistency with the actual data
    if (remainingBalance <= 0) {
      debt.payment_status = 'paid';
      debt.remainingBalance = 0; // ✅ Ensure it's explicitly set to 0
      console.log('✅ Setting to PAID - remaining balance is 0 or negative');
    } else if (initialPayment > 0 || payments.length > 0) {
      debt.payment_status = 'partially_paid';
      console.log('🟡 Setting to PARTIALLY_PAID - has payments made');
    } else {
      debt.payment_status = 'unpaid';
      console.log('🔴 Setting to UNPAID - no payments made');
    }

    // ✅ FIXED: Update status based on payment_status AND due date
    if (debt.payment_status === 'paid') {
      debt.status = 'paid';
      console.log('✅ Setting status to PAID - payment_status is paid');
    } else {
      // Only check due date for unpaid/partially paid debts
      if (debt.dueDate) {
        try {
          const dueDate = debt.dueDate.toDate ? debt.dueDate.toDate() : new Date(debt.dueDate);
          if (dueDate < now) {
            debt.status = 'overdue';
            console.log('⏰ Setting status to OVERDUE - past due date');
          } else {
            debt.status = 'pending';
            console.log('⏳ Setting status to PENDING - not due yet');
          }
        } catch (error) {
          console.error('❌ Error parsing due date:', error);
          debt.status = 'pending';
          console.log('⏳ Setting status to PENDING - invalid due date');
        }
      } else {
        debt.status = 'pending';
        console.log('⏳ Setting status to PENDING - no due date');
      }
    }

    // ✅ CRITICAL: Ensure remainingBalance is consistent
    if (debt.payment_status === 'paid') {
      debt.remainingBalance = 0;
    }

    console.log('📊 Final status:', {
      payment_status: debt.payment_status,
      status: debt.status,
      remainingBalance: debt.remainingBalance,
      calculatedRemainingBalance: remainingBalance
    });
    console.log('---');
  });
}

// Enhanced refreshDebtStatus method
async refreshDebtStatus(debtProduct: DebtProduct): Promise<boolean> {
  try {
    if (!debtProduct.firestoreId) {
      console.error('❌ Cannot refresh status: No firestoreId');
      return false;
    }

    const { doc, getDoc } = await import('@angular/fire/firestore');
    const debtProductRef = doc(this.firestore, 'debt_products', debtProduct.firestoreId);
    const docSnapshot = await getDoc(debtProductRef);
    
    if (docSnapshot.exists()) {
      const data = docSnapshot.data();
      
      console.log('🔄 Fresh data from Firestore:', {
        remainingBalance: data['remainingBalance'],
        payment_status: data['payment_status'],
        status: data['status']
      });
      
      // Update the local debt product with fresh data
      const index = this.debtProducts.findIndex(d => d.firestoreId === debtProduct.firestoreId);
      if (index !== -1) {
        this.debtProducts[index].remainingBalance = data['remainingBalance'];
        this.debtProducts[index].payment_status = data['payment_status'];
        this.debtProducts[index].status = data['status'];
        this.debtProducts[index].initialPayment = data['initialPayment'];
        this.debtProducts[index].payments = data['payments'] || [];
        
        console.log('✅ Successfully updated local debt data:', {
          customer: this.debtProducts[index].customerName,
          remainingBalance: this.debtProducts[index].remainingBalance,
          payment_status: this.debtProducts[index].payment_status,
          status: this.debtProducts[index].status
        });
        
        return true;
      } else {
        console.log('❌ Debt not found in local array');
        return false;
      }
    } else {
      console.log('❌ Document not found in Firestore');
      return false;
    }
  } catch (error) {
    console.error('❌ Error refreshing debt status:', error);
    return false;
  }
}

  // Cash Products Methods
  viewCashReceipt(cashProduct: CashProduct) {
    this.selectedCashProduct = cashProduct;
    this.showCashReceiptModal = true;
  }

  closeCashReceiptModal() {
    this.showCashReceiptModal = false;
    this.selectedCashProduct = null;
  }

  // Debt Products Methods - UPDATED
async viewDebtReceipt(debtProduct: DebtProduct) {
  try {
    console.log('📄 Opening debt receipt for:', debtProduct.customerName);
    
    // First, refresh the debt data from Firestore to get the latest status
    await this.refreshDebtStatus(debtProduct);
    
    // Find the updated debt in the local array
    const updatedDebt = this.debtProducts.find(d => d.firestoreId === debtProduct.firestoreId);
    
    if (updatedDebt) {
      // Use the updated data
      this.selectedDebtProduct = { ...updatedDebt };
      console.log('✅ Using updated debt data:', {
        customer: this.selectedDebtProduct.customerName,
        remainingBalance: this.selectedDebtProduct.remainingBalance,
        payment_status: this.selectedDebtProduct.payment_status,
        status: this.selectedDebtProduct.status
      });
    } else {
      // Fallback to the original data
      this.selectedDebtProduct = debtProduct;
      console.log('⚠️ Using original debt data (not found in updated array)');
    }
    
    this.showDebtReceiptModal = true;
    
  } catch (error) {
    console.error('❌ Error opening debt receipt:', error);
    // Fallback: use the original data
    this.selectedDebtProduct = debtProduct;
    this.showDebtReceiptModal = true;
    this.showToast('Error loading receipt details', 'warning');
  }
}

  closeDebtReceiptModal() {
    this.showDebtReceiptModal = false;
    this.selectedDebtProduct = null;
  }

// REPLACE your modal-related methods with these enhanced versions

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

async processPayment(): Promise<void> {
  if (!this.selectedDebtForPayment) {
    console.error('❌ No debt selected for payment');
    this.showToast('No debt selected for payment', 'danger');
    return;
  }

  // Store reference before potential null issues
  const debtToUpdate = this.selectedDebtForPayment;
  
  console.log('🔄 Processing payment:', {
    amount: this.paymentAmount,
    customer: debtToUpdate.customerName,
    maxAmount: this.maxPaymentAmount
  });

  const maxAmount = this.maxPaymentAmount;
  
  // Validation
  if (!this.paymentAmount || this.paymentAmount <= 0) {
    this.showToast('Please enter a valid payment amount', 'warning');
    return;
  }
  
  if (this.paymentAmount > maxAmount) {
    this.showToast(`Payment cannot exceed ${this.formatCurrency(maxAmount)}`, 'warning');
    return;
  }

  const loading = await this.loadingController.create({
    message: 'Processing payment...',
    spinner: 'crescent'
  });
  await loading.present();

  try {
    console.log('💰 Recording payment to Firestore...');
    
    await this.recordDebtPayment(
      debtToUpdate, 
      this.paymentAmount, 
      this.paymentNotes || undefined
    );
    
    console.log('✅ Payment recorded successfully');
    
    // CRITICAL: Refresh the specific debt status immediately
    await this.refreshDebtStatus(debtToUpdate);
    
    // Close modal and show success
    this.closePaymentModal();
    this.showToast(`Payment of ${this.formatCurrency(this.paymentAmount)} recorded successfully!`, 'success');
    
    // Also reload all data to ensure consistency
    await this.loadDebtProducts();
    
  } catch (error: any) {
    console.error('❌ Error processing payment:', error);
    this.showToast(
      error?.message || 'Error processing payment. Please try again.', 
      'danger'
    );
  } finally {
    await loading.dismiss();
  }
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

// Test method for debugging (remove after fixing)
testPaymentModal(): void {
  console.log('🧪 Testing payment modal with dummy data');
  
  // Create dummy debt data
  const dummyDebt: DebtProduct = {
    id: 'test-123',
    firestoreId: 'test-firestore-123',
    items: [],
    total: 1000,
    paymentMethod: 'debt',
    customerName: 'Test Customer',
    customerPhone: '09123456789',
    dueDate: new Date(),
    status: 'pending',
    receipt_image: '',
    created_at: new Date(),
    store_owner_id: 'test-owner',
    employee_id: 'test-employee',
    payment_status: 'unpaid',
    remainingBalance: 1000,
    originalTotal: 1000,
    payments: []
  };
  
  this.openPaymentModal(dummyDebt);
}

  async recordDebtPayment(debtProduct: DebtProduct, amount: number, notes?: string) {
    try {
      if (!debtProduct.firestoreId) {
        throw new Error('Debt product Firestore ID is missing');
      }

      console.log('💰 Recording payment:', {
        debtId: debtProduct.firestoreId,
        customer: debtProduct.customerName,
        amount: amount,
        currentBalance: debtProduct.remainingBalance
      });

      const { doc, getDoc, updateDoc, Timestamp } = await import('@angular/fire/firestore');
      
      const debtProductRef = doc(this.firestore, 'debt_products', debtProduct.firestoreId);
      
      const docSnapshot = await getDoc(debtProductRef);
      if (!docSnapshot.exists()) {
        throw new Error(`Debt product document not found: ${debtProduct.firestoreId}`);
      }
      
      const currentData = docSnapshot.data();
      const currentBalance = currentData['remainingBalance'] || currentData['total'] || 0;
      const newBalance = currentBalance - amount;
      
      if (newBalance < 0) {
        throw new Error('Payment amount cannot exceed remaining balance');
      }

      const paymentHistory: PaymentHistory = {
        amount: amount,
        paymentDate: Timestamp.now(),
        paid_by: this.authService.getCurrentUser()?.full_name || 'Store Owner',
        ...(notes && { notes: notes })
      };

      const currentPayments = currentData['payments'] || [];
      const updatedPayments = [...currentPayments, paymentHistory];

      const newPaymentStatus = newBalance <= 0 ? 'paid' : 'partially_paid';

      const updateData: any = {
        remainingBalance: newBalance,
        payment_status: newPaymentStatus,
        payments: updatedPayments,
        updated_at: Timestamp.now()
      };

      // Update status based on payment status
      if (newPaymentStatus === 'paid') {
        updateData.status = 'paid';
      } else if (debtProduct.dueDate) {
        const dueDate = debtProduct.dueDate.toDate ? debtProduct.dueDate.toDate() : new Date(debtProduct.dueDate);
        const now = new Date();
        updateData.status = dueDate < now ? 'overdue' : 'pending';
      }

      // If this is the first payment, also set initialPayment
      if (currentPayments.length === 0 && (!currentData['initialPayment'] || currentData['initialPayment'] === 0)) {
        updateData.initialPayment = amount;
      }

      console.log('📝 Updating debt with data:', updateData);

      await updateDoc(debtProductRef, updateData);
      console.log('✅ Payment recorded successfully');

      // Reload debt products to reflect changes
      await this.loadDebtProducts();

    } catch (error) {
      console.error('❌ Error recording debt payment:', error);
      throw error;
    }
  }

  // Utility Methods
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
    return `PHP ${amount?.toFixed(2) || '0.00'}`;
  }

  // Filter Methods
  get filteredCashProducts(): CashProduct[] {
    let filtered = this.cashProducts;

    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(product => 
        product.customerName?.toLowerCase().includes(term) ||
        product.id?.toLowerCase().includes(term) ||
        product.employeeName?.toLowerCase().includes(term) ||
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
        product.id?.toLowerCase().includes(term) ||
        product.employeeName?.toLowerCase().includes(term)
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

  // Summary Methods
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

  getTotalCashSales(): number {
    return this.cashProducts.reduce((total, product) => total + product.total, 0);
  }

  getTotalOutstanding(): number {
    return this.debtProducts
      .filter(debt => debt.payment_status !== 'paid')
      .reduce((total, debt) => total + (debt.remainingBalance || debt.total), 0);
  }

  getDebtCountByStatus(status: string): number {
    return this.debtProducts.filter(debt => debt.payment_status === status).length;
  }

  // Event Handlers
  async doRefresh(event: any) {
    await this.loadSalesData();
    event.target.complete();
  }

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

  segmentChanged() {
    // The segment change will automatically update the view
  }

  searchChanged() {
    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      // The getters will automatically update the view
    }, 300);
  }

  filterChanged() {
    // The getters will automatically update the view
  }

  // TrackBy functions
  trackByCashId(index: number, item: CashProduct): string {
    return item.id || index.toString();
  }

  trackByDebtId(index: number, item: DebtProduct): string {
    return item.firestoreId || item.id || index.toString();
  }

  // Image error handler
  handleImageError(event: any, type: 'cash' | 'debt') {
    console.log('Image load error:', event);
    event.target.style.display = 'none';
  }

  // Share receipt functionality
  async shareReceipt(product: any) {
    this.showToast('Share functionality would be implemented here', 'primary');
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

  // ADDED FOR SALES REPORT
 // Add these methods to your component

openReportModal() {
  // Set default date range to last 30 days
  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - 30);
  
  this.reportStartDate = startDate.toISOString().split('T')[0];
  this.reportEndDate = endDate.toISOString().split('T')[0];
  this.showReportModal = true;
  this.showPreview = false;
}

closeReportModal() {
  this.showReportModal = false;
  this.showPreview = false;
}

onReportTypeChange() {
  this.updateReportData();
}

onDateFilterChange() {
  this.updateReportData();
}

setDateRange(range: 'today' | 'week' | 'month' | 'year') {
  const today = new Date();
  let startDate = new Date();
  
  switch (range) {
    case 'today':
      startDate = new Date(today);
      startDate.setHours(0, 0, 0, 0);
      break;
    case 'week':
      startDate.setDate(today.getDate() - 7);
      break;
    case 'month':
      startDate.setMonth(today.getMonth() - 1);
      break;
    case 'year':
      startDate.setFullYear(today.getFullYear() - 1);
      break;
  }
  
  this.reportStartDate = startDate.toISOString().split('T')[0];
  this.reportEndDate = today.toISOString().split('T')[0];
  this.updateReportData();
}

get filteredReportData(): any[] {
  let data: any[] = [];
  
  // Combine data based on report type
  if (this.reportType === 'cash' || this.reportType === 'combined') {
    data = [...data, ...this.cashProducts];
  }
  if (this.reportType === 'debt' || this.reportType === 'combined') {
    data = [...data, ...this.debtProducts];
  }
  
  // Filter by date range
  if (this.reportStartDate && this.reportEndDate) {
    const start = new Date(this.reportStartDate);
    const end = new Date(this.reportEndDate);
    end.setHours(23, 59, 59, 999); // Include entire end date
    
    data = data.filter(item => {
      const itemDate = item.created_at?.toDate ? item.created_at.toDate() : new Date(item.created_at);
      return itemDate >= start && itemDate <= end;
    });
  }
  
  // Filter debt by status
  if (this.reportType !== 'cash' && this.reportDebtStatus !== 'all') {
    data = data.filter(item => {
      if (item.paymentMethod === 'debt') {
        return this.reportDebtStatus === 'overdue' ? 
          item.status === 'overdue' : 
          item.payment_status === this.reportDebtStatus;
      }
      return true;
    });
  }
  
  return data;
}

updateReportData() {
  // This will trigger the getter to update filtered data
  this.showPreview = false;
}

previewReport() {
  this.showPreview = true;
}

getReportCashTotal(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'cash')
    .reduce((total, item) => total + item.total, 0);
}

getReportDebtTotal(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'debt')
    .reduce((total, item) => total + item.total, 0);
}

getReportOutstandingTotal(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'debt' && item.payment_status !== 'paid')
    .reduce((total, item) => total + (item.remainingBalance || item.total), 0);
}


// Replace your current generateSalesPDF method with this:

async generateSalesPDF() {
  const loading = await this.loadingController.create({
    message: 'Generating Sales Report PDF...'
  });
  await loading.present();

  try {
    
    console.log('=== SALES PDF GENERATION STARTED ===');
    await this.refreshEmployeeNamesForReport();
    const doc = new jsPDF();
    const currentUser = this.authService.getCurrentUser();
    const storeName = currentUser?.store_name || 'Store';
    const currentDate = new Date().toLocaleDateString('en-PH');
    const currentTime = new Date().toLocaleTimeString();

    // Title Section
    doc.setFontSize(20);
    doc.setTextColor(41, 128, 185);
    doc.text('STORE SALES REPORT', 105, 20, { align: 'center' });
    
    doc.setFontSize(12);
    doc.setTextColor(100, 100, 100);
    doc.text(`${storeName}`, 105, 30, { align: 'center' });
    doc.text(`Generated on: ${currentDate} at ${currentTime}`, 105, 36, { align: 'center' });
    
    const dateRangeText = `Period: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`;
    doc.text(dateRangeText, 105, 42, { align: 'center' });

    let finalY = 50;

    // ===== SUMMARY SECTION =====
    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('SUMMARY OVERVIEW', 20, finalY);
    finalY += 10;

    const summaryData = [
      ['Total Transactions', this.filteredReportData.length.toString()],
      ['Cash Sales Total', `PHP ${this.getReportCashTotal().toFixed(2)}`],
      ['Debt Sales Total', `PHP ${this.getReportDebtTotal().toFixed(2)}`],
      ['Outstanding Balance', `PHP ${this.getReportOutstandingTotal().toFixed(2)}`],
      ['Grand Total', `PHP ${(this.getReportCashTotal() + this.getReportDebtTotal()).toFixed(2)}`]
    ];

    autoTable(doc, {
      startY: finalY,
      head: [['Metric', 'Value']],
      body: summaryData,
      theme: 'grid',
      headStyles: { fillColor: [66, 139, 202] },
      styles: { fontSize: 11, cellPadding: 3 }
    });

    // Use type assertion for lastAutoTable
    finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;

    // ===== CASH SALES SECTION =====
    const cashTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'cash');
    if (cashTransactions.length > 0 && (this.reportType === 'cash' || this.reportType === 'combined')) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(34, 139, 34);
      doc.text(`CASH SALES (${cashTransactions.length})`, 20, finalY);
      finalY += 10;

      const cashData = cashTransactions.map(tx => [
        this.formatDateShort(tx.created_at),
        this.truncateText(tx.customerName || 'Walk-in Customer', 20),
        `PHP ${tx.total.toFixed(2)}`,
         tx.employeeName, // This will now have the actual employee name
        `${tx.items?.length || 0} items`
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Customer', 'Amount', 'Employee', 'Items']],
        body: cashData,
        theme: 'grid',
        headStyles: { fillColor: [34, 139, 34] },
        styles: { fontSize: 9, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;
    }

    // ===== DEBT SALES SECTION =====
    const debtTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'debt');
    if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(255, 165, 0);
      doc.text(`DEBT SALES (${debtTransactions.length})`, 20, finalY);
      finalY += 10;

      const debtData = debtTransactions.map(tx => [
        this.formatDateShort(tx.created_at),
        this.truncateText(tx.customerName, 18),
        `PHP ${tx.total.toFixed(2)}`,
        `PHP ${(tx.initialPayment || 0).toFixed(2)}`,
        `PHP ${(tx.remainingBalance || tx.total).toFixed(2)}`,
        this.getPaymentStatusDisplay(tx.payment_status),
        tx.employeeName
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Customer', 'Total', 'Paid', 'Balance', 'Status', 'Employee']],
        body: debtData,
        theme: 'grid',
        headStyles: { fillColor: [255, 165, 0] },
        styles: { fontSize: 8, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;
    }

    // ===== DEBT STATUS BREAKDOWN =====
    if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(220, 53, 69);
      doc.text('DEBT STATUS BREAKDOWN', 20, finalY);
      finalY += 10;

      const statusBreakdown = this.getDebtStatusBreakdown(debtTransactions);
      const statusData = Object.entries(statusBreakdown).map(([status, count]) => [
        status,
        count.toString(),
        `PHP ${this.getDebtAmountByStatus(debtTransactions, status).toFixed(2)}`
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Status', 'Count', 'Total Amount']],
        body: statusData,
        theme: 'grid',
        headStyles: { fillColor: [220, 53, 69] },
        styles: { fontSize: 10, cellPadding: 3 }
      });

      finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;
    }

    // ===== FILTER INFORMATION SECTION =====
    if (finalY > 250) {
      doc.addPage();
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('FILTER INFORMATION', 20, finalY);
    finalY += 10;

    doc.setFontSize(10);
    doc.setTextColor(100, 100, 100);
    
    const filterInfo = [
      `Report Type: ${this.getReportTypeLabel()}`,
      `Date Range: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`,
      `Debt Status Filter: ${this.getDebtStatusLabel()}`,
      `Total Cash Transactions: ${cashTransactions.length}`,
      `Total Debt Transactions: ${debtTransactions.length}`,
      `Report Generated: ${currentDate} at ${currentTime}`
    ];

    filterInfo.forEach(info => {
      if (finalY > 270) {
        doc.addPage();
        finalY = 20;
      }
      doc.text(info, 20, finalY);
      finalY += 6;
    });

    // Footer
    doc.setFontSize(8);
    doc.setTextColor(150, 150, 150);
    const footerText = `Report generated by ${storeName}`;
    doc.text(footerText, 105, doc.internal.pageSize.height - 10, { align: 'center' });

    // Save PDF
    const fileName = `sales-report-${this.reportType}-${new Date().toISOString().split('T')[0]}.pdf`;
    doc.save(fileName);

    this.showToast('Sales report downloaded successfully!', 'success');
    console.log('=== SALES PDF GENERATION COMPLETED ===');

  } catch (error) {
    console.error('Error generating PDF:', error);
    this.showToast('Error generating sales report', 'danger');
  } finally {
    await loading.dismiss();
  }
}
// Main PDF Generation Method - FIXED
async createSalesPDF() {
  const jsPDF = (await import('jspdf')).default;
  await import('jspdf-autotable');
  
  const doc = new jsPDF();
  
  const currentUser = this.authService.getCurrentUser();
  const storeName = currentUser?.store_name || 'Store';
  const currentDate = new Date().toLocaleDateString('en-PH');
  const currentTime = new Date().toLocaleTimeString();

  // Track page numbers manually since getNumberOfPages() might not be available
  let currentPage = 1;
  const totalPages = 1; // We'll update this as we add pages

  // ===== HEADER SECTION =====
  doc.setFontSize(20);
  doc.setTextColor(41, 128, 185);
  doc.text('SALES REPORT', 105, 20, { align: 'center' });
  
  doc.setFontSize(12);
  doc.setTextColor(100, 100, 100);
  doc.text(`${storeName}`, 105, 30, { align: 'center' });
  doc.text(`Generated on: ${currentDate} at ${currentTime}`, 105, 36, { align: 'center' });
  
  const dateRangeText = `Period: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`;
  doc.text(dateRangeText, 105, 42, { align: 'center' });

  let finalY = 50;

  // ===== SUMMARY SECTION =====
  doc.setFontSize(14);
  doc.setTextColor(40, 40, 40);
  doc.text('SUMMARY OVERVIEW', 20, finalY);
  finalY += 10;

  const summaryData = [
    ['Report Type', this.getReportTypeLabel()],
    ['Date Range', `${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`],
    ['Total Transactions', this.filteredReportData.length.toString()],
    ['Cash Sales Total', `PHP ${this.getReportCashTotal().toFixed(2)}`],
    ['Debt Sales Total', `PHP ${this.getReportDebtTotal().toFixed(2)}`],
    ['Outstanding Balance', `PHP ${this.getReportOutstandingTotal().toFixed(2)}`]
  ];

  (doc as any).autoTable({
    startY: finalY,
    head: [['Metric', 'Value']],
    body: summaryData,
    theme: 'grid',
    headStyles: { fillColor: [66, 139, 202] },
    styles: { fontSize: 11, cellPadding: 3 }
  });

  finalY = (doc as any).lastAutoTable.finalY + 15;

  // ===== CASH SALES DETAILED TABLE =====
  const cashTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'cash');
  if (cashTransactions.length > 0 && (this.reportType === 'cash' || this.reportType === 'combined')) {
    if (finalY > 250) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(34, 139, 34);
    doc.text(`CASH SALES DETAILS (${cashTransactions.length} transactions)`, 20, finalY);
    finalY += 10;

    const cashData = cashTransactions.map(tx => [
      this.formatDateShort(tx.created_at),
      this.truncateText(tx.id || 'N/A', 15),
      this.truncateText(tx.customerName || 'Walk-in Customer', 18),
      this.truncateText(tx.employeeName || 'Unknown', 15),
      `PHP ${tx.total.toFixed(2)}`,
      `PHP ${tx.amountPaid.toFixed(2)}`,
      `PHP ${tx.change.toFixed(2)}`,
      (tx.items?.length || 0).toString()
    ]);

    (doc as any).autoTable({
      startY: finalY,
      head: [['Date', 'Receipt ID', 'Customer', 'Employee', 'Total', 'Paid', 'Change', 'Items']],
      body: cashData,
      theme: 'grid',
      headStyles: { fillColor: [34, 139, 34] },
      styles: { fontSize: 8, cellPadding: 2 },
      didDrawPage: (data: any) => {
        // Update current page when new page is drawn
        currentPage = data.pageNumber;
      }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;
  }

  // ===== DEBT SALES DETAILED TABLE =====
  const debtTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'debt');
  if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
    if (finalY > 250) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(255, 165, 0);
    doc.text(`DEBT SALES DETAILS (${debtTransactions.length} transactions)`, 20, finalY);
    finalY += 10;

    const debtData = debtTransactions.map(tx => [
      this.formatDateShort(tx.created_at),
      this.truncateText(tx.customerName, 16),
      this.truncateText(tx.customerPhone || 'N/A', 12),
      this.truncateText(tx.employeeName || 'Unknown', 12),
      `PHP ${tx.total.toFixed(2)}`,
      `PHP ${(tx.initialPayment || 0).toFixed(2)}`,
      `PHP ${(tx.remainingBalance || tx.total).toFixed(2)}`,
      this.formatDateShort(tx.dueDate),
      this.getPaymentStatusDisplay(tx.payment_status),
      (tx.items?.length || 0).toString()
    ]);

    (doc as any).autoTable({
      startY: finalY,
      head: [['Date', 'Customer', 'Phone', 'Employee', 'Total', 'Paid', 'Balance', 'Due Date', 'Status', 'Items']],
      body: debtData,
      theme: 'grid',
      headStyles: { fillColor: [255, 165, 0] },
      styles: { fontSize: 7, cellPadding: 2 },
      didDrawPage: (data: any) => {
        // Update current page when new page is drawn
        currentPage = data.pageNumber;
      }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;
  }

  // ===== DEBT STATUS BREAKDOWN =====
  if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
    if (finalY > 250) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(220, 53, 69);
    doc.text('DEBT STATUS BREAKDOWN', 20, finalY);
    finalY += 10;

    const statusBreakdown = this.getDebtStatusBreakdown(debtTransactions);
    const statusData = Object.entries(statusBreakdown).map(([status, count]) => [
      status,
      count.toString(),
      `PHP ${this.getDebtAmountByStatus(debtTransactions, status).toFixed(2)}`
    ]);

    (doc as any).autoTable({
      startY: finalY,
      head: [['Status', 'Count', 'Total Amount']],
      body: statusData,
      theme: 'grid',
      headStyles: { fillColor: [220, 53, 69] },
      styles: { fontSize: 10, cellPadding: 3 },
      didDrawPage: (data: any) => {
        currentPage = data.pageNumber;
      }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;
  }

  // ===== FILTER INFORMATION =====
  if (finalY > 250) {
    doc.addPage();
    currentPage++;
    finalY = 20;
  }

  doc.setFontSize(14);
  doc.setTextColor(40, 40, 40);
  doc.text('FILTER INFORMATION', 20, finalY);
  finalY += 10;

  doc.setFontSize(10);
  doc.setTextColor(100, 100, 100);
  
  const filterInfo = [
    `Report Type: ${this.getReportTypeLabel()}`,
    `Date Range: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`,
    `Debt Status Filter: ${this.getDebtStatusLabel()}`,
    `Total Cash Transactions: ${cashTransactions.length}`,
    `Total Debt Transactions: ${debtTransactions.length}`,
    `Grand Total: PHP ${(this.getReportCashTotal() + this.getReportDebtTotal()).toFixed(2)}`
  ];

  filterInfo.forEach(info => {
    if (finalY > 270) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }
    doc.text(info, 20, finalY);
    finalY += 6;
  });

  // Footer - FIXED: Use currentPage instead of getNumberOfPages()
  this.addFooterToAllPages(doc, storeName, currentDate, currentTime, currentPage);

  // Save PDF
  const fileName = `sales-report-${this.reportType}-${new Date().toISOString().split('T')[0]}.pdf`;
  doc.save(fileName);
}

// Helper method to add footer to all pages
private addFooterToAllPages(doc: any, storeName: string, currentDate: string, currentTime: string, totalPages: number) {
  const pageCount = totalPages;
  
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setTextColor(150, 150, 150);
    const footerText = `Report generated by ${storeName} on ${currentDate} at ${currentTime} | Page ${i} of ${pageCount}`;
    doc.text(footerText, 105, doc.internal.pageSize.height - 10, { align: 'center' });
  }
}
private formatDateShort(date: any): string {
  if (!date) return 'N/A';
  try {
    const jsDate = date.toDate ? date.toDate() : new Date(date);
    return jsDate.toLocaleDateString('en-PH', {
      month: 'short',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch (error) {
    return 'Invalid Date';
  }
}

private formatFilterDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
}

private truncateText(text: string, maxLength: number): string {
  if (!text || text === 'undefined' || text === 'null') return 'N/A';
  const cleanText = String(text).trim();
  if (cleanText.length <= maxLength) return cleanText;
  return cleanText.substring(0, maxLength - 2) + '..';
}

private getReportTypeLabel(): string {
  const types: Record<string, string> = {
    'cash': 'Cash Sales Only',
    'debt': 'Debt Sales Only',
    'combined': 'Combined Sales'
  };
  return types[this.reportType] || 'All Sales';
}

private getDebtStatusLabel(): string {
  const statuses: Record<string, string> = {
    'all': 'All Status',
    'unpaid': 'Unpaid Only',
    'partially_paid': 'Partially Paid Only',
    'paid': 'Paid Only',
    'overdue': 'Overdue Only'
  };
  return statuses[this.reportDebtStatus] || 'All Status';
}

private getPaymentStatusDisplay(status: string): string {
  const statusMap: Record<string, string> = {
    'unpaid': 'Unpaid',
    'partially_paid': 'Partial',
    'paid': 'Paid'
  };
  return statusMap[status] || status;
}

private getDebtStatusBreakdown(debtTransactions: any[]): Record<string, number> {
  const breakdown: Record<string, number> = {
    'Unpaid': 0,
    'Partially Paid': 0,
    'Paid': 0,
    'Overdue': 0
  };

  debtTransactions.forEach(tx => {
    if (tx.status === 'overdue') {
      breakdown['Overdue']++;
    } else {
      switch (tx.payment_status) {
        case 'unpaid': breakdown['Unpaid']++; break;
        case 'partially_paid': breakdown['Partially Paid']++; break;
        case 'paid': breakdown['Paid']++; break;
      }
    }
  });

  return breakdown;
}

private getDebtAmountByStatus(debtTransactions: any[], status: string): number {
  return debtTransactions
    .filter(tx => {
      if (status === 'Overdue') return tx.status === 'overdue';
      switch (status) {
        case 'Unpaid': return tx.payment_status === 'unpaid';
        case 'Partially Paid': return tx.payment_status === 'partially_paid';
        case 'Paid': return tx.payment_status === 'paid';
        default: return false;
      }
    })
    .reduce((sum, tx) => sum + tx.total, 0);
}
}