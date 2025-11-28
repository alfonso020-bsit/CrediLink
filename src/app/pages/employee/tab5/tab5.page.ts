import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, orderBy, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import { TransactionDetailsModal } from './transaction-details-modal.component';
import { ModalController } from '@ionic/angular';
import autoTable from 'jspdf-autotable';

export interface ReportFilter {
  startDate: string;
  endDate: string;
  transactionType: 'all' | 'cash' | 'debt' | 'stock';
  status: string;
  employeeId: string;
}

export interface TransactionReport {
  id: string;
  firestoreId: string;
  type: 'cash' | 'debt' | 'stock';
  date: Date;
  customerName: string;
  totalAmount: number;
  status: string;
  paymentStatus?: string;
  employeeName: string;
  employeeId: string;
  itemsCount: number;
  details: any;
  
  // Display properties (optional)
  displayType?: string;
  displayAmount?: string;
  displayStatus?: string;
  displayBalance?: string;
  transactionType?: string;
  productName?: string;
  quantity?: number;
  remainingBalance?: number;
  initialPayment?: number;
  dueDate?: any;
  
  // Stock transaction specific fields
  stockAction?: string;
  previousStock?: number;
  newStock?: number;
  reason?: string;
  
  // NEW: Payment tracking for debt transactions
  payments?: any[];
  userPayments?: any[];
  isCreatedByCurrentUser?: boolean;
  hasRecordedPayments?: boolean;
}

@Component({
  selector: 'app-tab5',
  templateUrl: './tab5.page.html',
  styleUrls: ['./tab5.page.scss'],
  standalone: false,
})
export class Tab5Page implements OnInit {
  // Report Data
  cashTransactions: any[] = [];
  debtTransactions: any[] = [];
  stockTransactions: any[] = [];
  combinedReport: TransactionReport[] = [];
  
  // Filtering
// UPDATED: Default date range to show all data
currentFilter: ReportFilter = {
  startDate: this.getDefaultStartDate(),
  endDate: this.getDefaultEndDate(),
  transactionType: 'all',
  status: 'all',
  employeeId: 'current'
};

  // UI State
  isLoading = false;
  showFilterModal = false;
  
  // Employees list (for filter)
  employees: any[] = [];
  
  // Summary data - UPDATED with stock metrics
  reportSummary = {
    totalTransactions: 0,
    totalCashAmount: 0,
    totalDebtAmount: 0,
    totalStockTransactions: 0,
    stockAdjustments: 0,
    stockIn: 0,
    stockOut: 0,
    completedTransactions: 0,
    pendingTransactions: 0
  };

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private alertController: AlertController,
    private modalController: ModalController
  ) { }

  async ngOnInit() {
    await this.loadInitialData();
  }
  // Add this helper method
getCurrentUserName(): string {
  const currentUser = this.authService.getCurrentUser();
  return currentUser?.full_name || 'Current User';
}

async loadInitialData() {
  const loading = await this.loadingController.create({
    message: 'Loading report data...'
  });
  await loading.present();

  try {
    // Load employees FIRST
    await this.loadEmployees();
    console.log('✅ Employees loaded:', this.employees);
    
    // Then generate report
    await this.generateReport();
  } catch (error) {
    console.error('Error loading initial data:', error);
    this.showToast('Error loading report data', 'danger');
  } finally {
    await loading.dismiss();
  }
}

private async loadEmployeeName(employeeId: string): Promise<string> {
  if (!employeeId) return 'Unknown Employee';
  
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    if (!storeOwnerId) return 'Unknown Employee';

    // Try to get employee from local cache first
    const cachedEmployee = this.employees.find(emp => emp.id === employeeId);
    if (cachedEmployee) {
      return cachedEmployee.full_name;
    }

    // If not found in cache, query Firestore directly
    const usersRef = collection(this.firestore, 'users');
    const q = query(
      usersRef,
      where('store_owner_id', '==', storeOwnerId),
      where('id', '==', employeeId)
    );
    
    const querySnapshot = await getDocs(q);
    if (!querySnapshot.empty) {
      const employeeData = querySnapshot.docs[0].data();
      const employeeName = employeeData['full_name'] || 'Unknown Employee';
      
      // Cache this employee for future use
      if (!this.employees.some(emp => emp.id === employeeId)) {
        this.employees.push({
          id: employeeId,
          full_name: employeeName
        });
      }
      
      return employeeName;
    }
  } catch (error) {
    console.error('Error loading employee name:', error);
  }
  
  return 'Unknown Employee';
}

 // NEW: Get default start date (1 year ago to show more data)
private getDefaultStartDate(): string {
  const date = new Date();
  date.setFullYear(date.getFullYear() - 1); // Show last year by default
  date.setDate(1); // First day of the month
  return date.toISOString().split('T')[0];
}

// NEW: Get default end date (today)
private getDefaultEndDate(): string {
  return new Date().toISOString().split('T')[0];
}

  async loadEmployees() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
      
      if (!storeOwnerId) return;

      const usersRef = collection(this.firestore, 'users');
      const q = query(
        usersRef,
        where('store_owner_id', '==', storeOwnerId),
        where('role', 'in', ['employee', 'manager'])
      );
      
      const querySnapshot = await getDocs(q);
      this.employees = querySnapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));

      // Add current employee option
      this.employees.unshift({
        id: 'current',
        full_name: 'My Transactions Only'
      });

      this.employees.unshift({
        id: 'all',
        full_name: 'All Employees'
      });

    } catch (error) {
      console.error('Error loading employees:', error);
    }
  }

//   async generateReport() {
//   this.isLoading = true;
  
//   try {
//     await Promise.all([
//       this.loadCashTransactions(),
//       this.loadDebtTransactions(),
//       this.loadStockTransactions()
//     ]);

//     this.combineTransactions();
//     this.calculateSummary();
    
//   } catch (error) {
//     console.error('Error generating report:', error);
//     this.showToast('Error generating report', 'danger');
//   } finally {
//     this.isLoading = false;
//   }
// }

async loadCashTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    if (!storeOwnerId) return;

    const cashProductsRef = collection(this.firestore, 'cash_products');
    
    let q = query(
      cashProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );

    const querySnapshot = await getDocs(q);
    
    const allCashTransactions = await Promise.all(
      querySnapshot.docs.map(async (doc) => {
        const data = doc.data();
        const transactionDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
        
        const totalAmount = this.cleanAndParseNumber(data['total']);
        
        // Get employee information
        const transactionEmployeeId = data['employee_id'] || '';
        const transactionEmployeeName = await this.loadEmployeeName(transactionEmployeeId);
        
        const isCreatedByCurrentUser = transactionEmployeeId === currentUser?.id;
        
        console.log('💰 Cash Transaction Employee Info:', {
          docId: doc.id,
          employeeId: transactionEmployeeId,
          employeeName: transactionEmployeeName,
          foundInEmployees: !!this.employees.find(emp => emp.id === transactionEmployeeId)
        });

        const transaction: TransactionReport = {
          id: data['id'] || doc.id,
          firestoreId: doc.id,
          type: 'cash',
          date: transactionDate,
          customerName: data['customerName'] || 'Walk-in Customer',
          totalAmount: totalAmount,
          status: 'completed',
          paymentStatus: 'paid',
          employeeName: transactionEmployeeName,
          employeeId: transactionEmployeeId,
          itemsCount: data['items']?.length || 0,
          details: data,
          isCreatedByCurrentUser: isCreatedByCurrentUser,
          displayType: 'Cash Sale',
          displayAmount: `PHP ${totalAmount.toFixed(2)}`,
          displayStatus: this.getStatusBadge('completed', 'paid')
        };
        
        return transaction;
      })
    );

    // Apply employee filter
    this.cashTransactions = allCashTransactions.filter(transaction => {
      switch (this.currentFilter.employeeId) {
        case 'current':
          return transaction.isCreatedByCurrentUser;
        case 'all':
          return true;
        default:
          return transaction.employeeId === this.currentFilter.employeeId;
      }
    });

    this.cashTransactions.sort((a, b) => b.date.getTime() - a.date.getTime());
    console.log(`✅ Loaded ${this.cashTransactions.length} cash transactions`);

  } catch (error) {
    console.error('Error loading cash transactions:', error);
    this.cashTransactions = [];
  }
}

// Add this debug method to check employee data
private debugEmployeeData() {
  console.log('🔍 DEBUG: Checking employee data');
  
  const currentUser = this.authService.getCurrentUser();
  console.log('Current User:', {
    id: currentUser?.id,
    name: currentUser?.full_name,
    storeOwnerId: currentUser?.store_owner_id
  });

  // Check debt transactions
  if (this.debtTransactions.length > 0) {
    console.log('Debt Transactions Employee Data:');
    this.debtTransactions.slice(0, 3).forEach((tx, index) => {
      console.log(`Debt ${index + 1}:`, {
        id: tx.id,
        employeeId: tx.employeeId,
        employeeName: tx.employeeName,
        detailsEmployeeName: tx.details?.['employee_name'],
        detailsEmployeeId: tx.details?.['employee_id']
      });
    });
  }

  // Check cash transactions
  if (this.cashTransactions.length > 0) {
    console.log('Cash Transactions Employee Data:');
    this.cashTransactions.slice(0, 3).forEach((tx, index) => {
      console.log(`Cash ${index + 1}:`, {
        id: tx.id,
        employeeId: tx.employeeId,
        employeeName: tx.employeeName,
        detailsEmployeeName: tx.details?.['employee_name'],
        detailsEmployeeId: tx.details?.['employee_id']
      });
    });
  }
}

// Call this in your generateReport method
async generateReport() {
  this.isLoading = true;
  
  try {
    await Promise.all([
      this.loadCashTransactions(),
      this.loadDebtTransactions(),
      this.loadStockTransactions()
    ]);

    this.combineTransactions();
    this.calculateSummary();
    
    // DEBUG: Check employee data
    this.debugEmployeeData();
    
  } catch (error) {
    console.error('Error generating report:', error);
    this.showToast('Error generating report', 'danger');
  } finally {
    this.isLoading = false;
  }
}

async loadDebtTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    if (!storeOwnerId) return;

    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    // First, load ALL debt transactions for the store owner
    let q = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );

    const querySnapshot = await getDocs(q);
    
    // Process all debt transactions and filter based on employee involvement
    const allDebtTransactions = querySnapshot.docs.map(doc => {
      const data = doc.data();
      const transactionDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
      
      // Clean numeric fields
      const totalAmount = this.cleanAndParseNumber(data['total']);
      const remainingBalance = this.cleanAndParseNumber(data['remainingBalance'] || data['total'] || 0);
      const initialPayment = this.cleanAndParseNumber(data['initialPayment'] || 0);
      
      // Get payments array
      const payments = data['payments'] || [];
      
      // Get employee information - try multiple fields
      const transactionEmployeeId = data['employee_id'] || data['user_id'] || data['employeeId'] || '';
      const transactionEmployeeName = this.getEmployeeNameFromData(data, currentUser);
      
      // Check if current user recorded any payments
      const userPayments = payments.filter((payment: any) => 
        payment.paid_by === currentUser?.full_name
      );
      
      const isCreatedByCurrentUser = transactionEmployeeId === currentUser?.id;
      const hasRecordedPayments = userPayments.length > 0;
      const isInvolved = isCreatedByCurrentUser || hasRecordedPayments;
      
      console.log('💳 Debt Transaction Employee Info:', {
        docId: doc.id,
        customer: data['customerName'],
        employeeId: transactionEmployeeId,
        employeeName: transactionEmployeeName,
        dataFields: {
          employee_id: data['employee_id'],
          employee_name: data['employee_name'],
          user_id: data['user_id'],
          user_name: data['user_name']
        }
      });

      // Create the transaction object with ALL properties
      const transaction: TransactionReport = {
        id: data['id'] || doc.id,
        firestoreId: doc.id,
        type: 'debt',
        date: transactionDate,
        customerName: data['customerName'] || 'Unknown Customer',
        totalAmount: totalAmount,
        status: data['status'] || 'pending',
        paymentStatus: data['payment_status'] || 'unpaid',
        employeeName: transactionEmployeeName,
        employeeId: transactionEmployeeId,
        itemsCount: data['items']?.length || 0,
        remainingBalance: remainingBalance,
        initialPayment: initialPayment,
        dueDate: data['dueDate'],
        details: data,
        // Add payment information
        payments: payments,
        userPayments: userPayments,
        isCreatedByCurrentUser: isCreatedByCurrentUser,
        hasRecordedPayments: hasRecordedPayments,
        // Display properties
        displayType: 'Debt Sale',
        displayAmount: `PHP ${totalAmount.toFixed(2)}`,
        displayStatus: this.getStatusBadge(data['status'] || 'pending', data['payment_status'] || 'unpaid'),
        displayBalance: `PHP ${remainingBalance.toFixed(2)}`
      };
      
      return transaction;
    });

    // Apply employee filter after loading all transactions
    this.debtTransactions = allDebtTransactions.filter(transaction => {
      const currentUser = this.authService.getCurrentUser();
      
      switch (this.currentFilter.employeeId) {
        case 'current':
          // Show transactions where current user is involved (created OR recorded payments)
          return transaction.isCreatedByCurrentUser || transaction.hasRecordedPayments;
          
        case 'all':
          // Show all transactions
          return true;
          
        default:
          // Show transactions for specific employee
          if (this.currentFilter.employeeId === transaction.employeeId) {
            return true;
          }
          // Also include if specific employee recorded payments (optional)
          const hasEmployeePayments = transaction.payments?.some((payment: any) => 
            payment.paid_by === this.getEmployeeNameById(this.currentFilter.employeeId)
          );
          return hasEmployeePayments;
      }
    });

    // Sort by date
    this.debtTransactions.sort((a, b) => b.date.getTime() - a.date.getTime());

    console.log(`✅ Loaded ${this.debtTransactions.length} debt transactions`);
    console.log(`📊 Employee Names:`, this.debtTransactions.map(t => ({
      customer: t.customerName,
      employeeName: t.employeeName,
      employeeId: t.employeeId
    })));

  } catch (error) {
    console.error('Error loading debt transactions:', error);
    this.debtTransactions = [];
  }
}

private getEmployeeNameFromData(data: any, currentUser: any): string {
  console.log('🔍 getEmployeeNameFromData - Data fields:', {
    employee_id: data['employee_id'],
    availableFields: Object.keys(data).filter(key => 
      key.includes('employee') || key.includes('user') || key.includes('name')
    )
  });

  // Method 1: Try to find employee name from employees array using employee_id
  const employeeId = data['employee_id'];
  if (employeeId) {
    const employee = this.employees.find(emp => emp.id === employeeId);
    if (employee) {
      console.log('✅ Found employee from employees array:', employee.full_name);
      return employee.full_name;
    }
    
    // If employee ID matches current user, use current user's name
    if (employeeId === currentUser?.id) {
      console.log('✅ Employee ID matches current user');
      return currentUser.full_name || 'Current Employee';
    }
  }

  // Method 2: Check if this transaction was created by current user
  if (data['store_owner_id'] === currentUser?.store_owner_id) {
    // For transactions without explicit employee info, check if current user might be involved
    const currentUserId = currentUser?.id;
    
    // If we have payments, check if current user recorded any payments
    if (data['payments'] && Array.isArray(data['payments'])) {
      const userPayments = data['payments'].filter((payment: any) => 
        payment.paid_by === currentUser?.full_name
      );
      if (userPayments.length > 0) {
        console.log('✅ Current user recorded payments for this transaction');
        return currentUser.full_name || 'Current Employee';
      }
    }
    
    // If transaction has no specific employee but belongs to current user's store
    // and we can't determine otherwise, assume it's the current user
    console.log('⚠️ No specific employee data, assuming current user');
    return currentUser.full_name || 'Current Employee';
  }

  // Final fallback
  console.log('❌ Could not determine employee name, using fallback');
  return 'Unknown Employee';
}

// Add helper method to get employee name by ID
private getEmployeeNameById(employeeId: string): string {
  if (employeeId === 'current') {
    const currentUser = this.authService.getCurrentUser();
    return currentUser?.full_name || '';
  }
  
  const employee = this.employees.find(emp => emp.id === employeeId);
  return employee?.full_name || '';
}
// ADD THIS METHOD: Clean and parse numbers from corrupted data
private cleanAndParseNumber(value: any): number {
  console.log('🔧 cleanAndParseNumber input:', value, 'Type:', typeof value);
  
  if (value === null || value === undefined) {
    return 0;
  }
  
  // If it's already a clean number, return it
  if (typeof value === 'number' && !isNaN(value)) {
    return value;
  }
  
  const valueStr = value.toString().trim();
  console.log('🔧 String value:', valueStr);
  
  // Handle the corrupted format: "±4 7 5 . 0 0" or "±&4&7&5&.&0&0"
  if (valueStr.includes('±') || valueStr.includes('&') || /\d\s+\d/.test(valueStr)) {
    console.log('🔄 Detected corrupted format, cleaning...');
    
    // Remove all special characters, spaces, and & symbols
    let cleanedValue = valueStr
      .replace(/[±₱&]/g, '')  // Remove special symbols
      .replace(/\s/g, '')     // Remove all spaces
      .replace(/[^\d.]/g, ''); // Remove any other non-numeric except decimal
    
    console.log('🔧 After cleaning:', cleanedValue);
    
    // Parse the cleaned number
    if (cleanedValue) {
      const numValue = parseFloat(cleanedValue);
      if (!isNaN(numValue)) {
        console.log('✅ Successfully parsed:', numValue);
        return numValue;
      }
    }
  }
  
  // For normal string numbers
  if (typeof value === 'string') {
    const cleaned = value.replace(/[^\d.]/g, '');
    const numValue = parseFloat(cleaned);
    const result = isNaN(numValue) ? 0 : numValue;
    console.log('✅ Normal string conversion:', result);
    return result;
  }
  
  console.log('❌ Could not parse, returning 0');
  return 0;
}

// ADD THIS DEBUG METHOD to check your data before PDF generation
private debugDataBeforePDF(): void {
  console.log('=== DATA DEBUG BEFORE PDF ===');
  
  // Check summary data
  console.log('Report Summary:', {
    totalCashAmount: this.reportSummary.totalCashAmount,
    totalDebtAmount: this.reportSummary.totalDebtAmount,
    types: {
      cash: typeof this.reportSummary.totalCashAmount,
      debt: typeof this.reportSummary.totalDebtAmount
    }
  });
  
  // Check first few transactions
  if (this.cashTransactions.length > 0) {
    console.log('First Cash Transaction:', {
      totalAmount: this.cashTransactions[0].totalAmount,
      displayAmount: this.cashTransactions[0].displayAmount
    });
  }
  
  if (this.debtTransactions.length > 0) {
    console.log('First Debt Transaction:', {
      totalAmount: this.debtTransactions[0].totalAmount,
      remainingBalance: this.debtTransactions[0].remainingBalance,
      initialPayment: this.debtTransactions[0].initialPayment
    });
  }
  
  // Test the cleanAndParseNumber function
  const testCases = ['±4 7 5 . 0 0', '±&4&7&5&.&0&0', '±1 9 9 . 0 0', '175.00'];
  testCases.forEach(test => {
    console.log(`Test "${test}":`, this.cleanAndParseNumber(test));
  });
}

async loadStockTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    if (!storeOwnerId) return;

    // Try both collection names for compatibility
    const stockCollections = ['stock_transactions', 'stock_transaction'];
    let stockTransactions: TransactionReport[] = [];

    for (const collectionName of stockCollections) {
      try {
        const stockTransactionsRef = collection(this.firestore, collectionName);
        let q = query(
          stockTransactionsRef,
          where('store_owner_id', '==', storeOwnerId)
        );

        // Apply employee filter only
        if (this.currentFilter.employeeId === 'current') {
          q = query(q, where('user_id', '==', currentUser.id));
        } else if (this.currentFilter.employeeId !== 'all') {
          q = query(q, where('user_id', '==', this.currentFilter.employeeId));
        }

        const querySnapshot = await getDocs(q);
        
        const transactions = querySnapshot.docs
          .map(doc => {
            const data = doc.data();
            const transactionDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
            
            const transactionType = data['type'] || 'adjustment';
            const quantity = data['quantity'] || 0;
            const changeType = data['change_type'] || (quantity >= 0 ? 'increase' : 'decrease');
            
            const transaction: TransactionReport = {
              id: doc.id,
              firestoreId: doc.id,
              type: 'stock',
              date: transactionDate,
              customerName: data['product_name'] || 'Stock Adjustment',
              totalAmount: 0,
              status: 'completed',
              employeeName: data['user_name'] || currentUser?.full_name || 'Employee',
              employeeId: data['user_id'],
              itemsCount: 1,
              transactionType: transactionType,
              productName: data['product_name'] || 'Unknown Product',
              quantity: Math.abs(quantity),
              details: data,
              // Stock specific fields
              stockAction: this.getStockActionDisplay(transactionType, changeType),
              previousStock: data['previous_stock'] || 0,
              newStock: data['new_stock'] || 0,
              reason: data['reason'] || 'Stock adjustment'
            };
            
            // Add display properties
            transaction.displayType = 'Stock Transaction';
            transaction.displayAmount = this.getStockTransactionDescription(transaction);
            transaction.displayStatus = this.getStatusBadge(transaction.status);
            transaction.customerName = transaction.productName || 'Stock Item';
            
            return transaction;
          })
          .sort((a, b) => b.date.getTime() - a.date.getTime()); // Remove date filtering

        stockTransactions = transactions;
        console.log(`✅ Loaded ${transactions.length} stock transactions from ${collectionName}`);
        break; // Use the first successful collection
      } catch (error) {
        console.log(`⚠️ Could not load from ${collectionName}:`, error);
        continue;
      }
    }

    this.stockTransactions = stockTransactions;

  } catch (error) {
    console.error('Error loading stock transactions:', error);
    this.stockTransactions = [];
  }
}

 combineTransactions() {
  this.combinedReport = [];
  
  // Add cash transactions
  if (this.currentFilter.transactionType === 'all' || this.currentFilter.transactionType === 'cash') {
    this.combinedReport.push(...this.cashTransactions);
  }

  // Add debt transactions
  if (this.currentFilter.transactionType === 'all' || this.currentFilter.transactionType === 'debt') {
    this.combinedReport.push(...this.debtTransactions);
  }

  // Add stock transactions
  if (this.currentFilter.transactionType === 'all' || this.currentFilter.transactionType === 'stock') {
    this.combinedReport.push(...this.stockTransactions);
  }

  // Apply date filter only when combining
  this.combinedReport = this.combinedReport.filter(transaction => 
    this.filterByDate(transaction.date)
  );

  // Apply status filter
  if (this.currentFilter.status !== 'all') {
    this.combinedReport = this.combinedReport.filter(tx => {
      if (this.currentFilter.status === 'completed') {
        return tx.status === 'completed' || tx.paymentStatus === 'paid';
      } else if (this.currentFilter.status === 'pending') {
        return tx.status === 'pending' || tx.paymentStatus === 'partially_paid' || tx.paymentStatus === 'unpaid';
      } else if (this.currentFilter.status === 'overdue') {
        return tx.status === 'overdue';
      }
      return true;
    });
  }

  // Sort by date (newest first)
  this.combinedReport.sort((a, b) => b.date.getTime() - a.date.getTime());
}
// UPDATED: Summary calculation with clean numbers
calculateSummary() {
  const stockIn = this.stockTransactions.filter(tx => 
    tx.details?.change_type === 'increase' || tx.details?.type === 'stock_in'
  ).length;
  
  const stockOut = this.stockTransactions.filter(tx => 
    tx.details?.change_type === 'decrease' || tx.details?.type === 'stock_out'
  ).length;

  // Ensure we're using clean numbers for calculations
  const totalCashAmount = this.cashTransactions.reduce((sum, tx) => {
    const cleanAmount = this.cleanAndParseNumber(tx.totalAmount);
    return sum + cleanAmount;
  }, 0);

  const totalDebtAmount = this.debtTransactions.reduce((sum, tx) => {
    const cleanAmount = this.cleanAndParseNumber(tx.totalAmount);
    return sum + cleanAmount;
  }, 0);

  this.reportSummary = {
    totalTransactions: this.combinedReport.length,
    totalCashAmount: totalCashAmount,
    totalDebtAmount: totalDebtAmount,
    totalStockTransactions: this.stockTransactions.length,
    stockAdjustments: this.stockTransactions.length,
    stockIn: stockIn,
    stockOut: stockOut,
    completedTransactions: this.combinedReport.filter(tx => 
      tx.status === 'completed' || tx.paymentStatus === 'paid'
    ).length,
    pendingTransactions: this.combinedReport.filter(tx => 
      tx.status === 'pending' || tx.paymentStatus === 'partially_paid' || tx.paymentStatus === 'unpaid'
    ).length
  };
}

  // NEW: Helper method for stock action display
  getStockActionDisplay(type: string, changeType: string): string {
    const actions: Record<string, string> = {
      'stock_in': 'Stock In',
      'stock_out': 'Stock Out',
      'adjustment': changeType === 'increase' ? 'Stock Increase' : 'Stock Decrease',
      'set': 'Stock Set'
    };
    return actions[type] || 'Stock Adjustment';
  }

  // UPDATED: Enhanced stock transaction description
  getStockTransactionDescription(tx: TransactionReport): string {
    const quantity = tx.quantity || 0;
    const productName = tx.productName || 'Product';
    const action = tx.stockAction || 'Adjustment';
    
    if (tx.previousStock !== undefined && tx.newStock !== undefined) {
      return `${action}: ${quantity} units (${tx.previousStock} → ${tx.newStock})`;
    }
    
    return `${action}: ${quantity} ${productName}`;
  }

  async exportToCSV() {
  try {
    const headers = ['Date', 'Type', 'Customer/Product', 'Amount/Details', 'Status', 'Employee', 'Items/Quantity', 'Additional Info'];
    const csvData = this.combinedReport.map(tx => {
      let additionalInfo = '';
      let amountDisplay = '';
      
      if (tx.type === 'debt') {
        const cleanBalance = this.cleanAndParseNumber(tx.remainingBalance);
        additionalInfo = `Balance: PHP ${cleanBalance.toFixed(2)}`;
        amountDisplay = `PHP ${this.cleanAndParseNumber(tx.totalAmount).toFixed(2)}`;
      } else if (tx.type === 'stock') {
        additionalInfo = `${tx.stockAction} | Reason: ${tx.reason}`;
        amountDisplay = this.getStockTransactionDescription(tx);
      } else {
        amountDisplay = `PHP ${this.cleanAndParseNumber(tx.totalAmount).toFixed(2)}`;
      }
      
      return [
        this.formatDate(tx.date),
        tx.displayType || tx.type,
        tx.customerName,
        amountDisplay,
        tx.displayStatus || tx.status,
        tx.employeeName,
        tx.type === 'stock' ? `${tx.quantity} units` : `${tx.itemsCount} items`,
        additionalInfo
      ];
    });

    const csvContent = [headers, ...csvData]
      .map(row => row.map(field => `"${field}"`).join(','))
      .join('\n');

    const blob = new Blob([csvContent], { type: 'text/csv' });
    const url = window.URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `employee-report-${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    window.URL.revokeObjectURL(url);

    this.showToast('CSV report downloaded successfully', 'success');
  } catch (error) {
    console.error('Error generating CSV:', error);
    this.showToast('Error generating CSV report', 'danger');
  }
}
  

  // Filter helpers
  filterByDate(transactionDate: Date): boolean {
    const startDate = new Date(this.currentFilter.startDate);
    const endDate = new Date(this.currentFilter.endDate);
    endDate.setHours(23, 59, 59, 999);

    return transactionDate >= startDate && transactionDate <= endDate;
  }

  getFirstDayOfMonth(): string {
    const date = new Date();
    date.setDate(1);
    return date.toISOString().split('T')[0];
  }

  // UI helpers
  getStatusBadge(status: string, paymentStatus?: string): string {
    if (paymentStatus) {
      switch (paymentStatus) {
        case 'paid': return 'Paid';
        case 'partially_paid': return 'Partial';
        case 'unpaid': return 'Unpaid';
      }
    }
    
    switch (status) {
      case 'completed': return 'Completed';
      case 'pending': return 'Pending';
      case 'overdue': return 'Overdue';
      default: return status;
    }
  }

  getStatusColor(status: string, paymentStatus?: string): string {
    if (paymentStatus) {
      switch (paymentStatus) {
        case 'paid': return 'success';
        case 'partially_paid': return 'warning';
        case 'unpaid': return 'danger';
      }
    }
    
    switch (status) {
      case 'completed': return 'success';
      case 'pending': return 'warning';
      case 'overdue': return 'danger';
      default: return 'medium';
    }
  }

  capitalizeFirst(text: string): string {
    return text.charAt(0).toUpperCase() + text.slice(1);
  }

  formatDate(date: Date): string {
    return date.toLocaleDateString('en-PH', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

async viewTransactionDetails(transaction: TransactionReport) {
  const modal = await this.modalController.create({
    component: TransactionDetailsModal,
    componentProps: {
      transaction: transaction,
      formatDate: this.formatDate.bind(this)
    },
    cssClass: 'transaction-details-modal'
  });
  
  await modal.present();
}

  // Filter methods
openFilterModal() {
  // Ensure current filter values are set
  this.currentFilter = {
    ...this.currentFilter,
    startDate: this.currentFilter.startDate || this.getDefaultStartDate(),
    endDate: this.currentFilter.endDate || this.getDefaultEndDate()
  };
  this.showFilterModal = true;
}

  closeFilterModal() {
    this.showFilterModal = false;
  }

  async applyFilters() {
    this.closeFilterModal();
    this.logFilterState();
    await this.generateReport();
  }

  async clearFilters() {
    this.currentFilter = {
      startDate: this.getFirstDayOfMonth(),
      endDate: new Date().toISOString().split('T')[0],
      transactionType: 'all',
      status: 'all',
      employeeId: 'current'
    };
    
    await this.generateReport();
  }

async exportToPDF() {
  const loading = await this.loadingController.create({
    message: 'Generating PDF report...'
  });
  await loading.present();

  try {
    console.log('=== PDF GENERATION STARTED ===');
    
    // IMPORTANT: Call debug before generating PDF
    this.debugDataBeforePDF();
    
    const doc = new jsPDF();
    const currentUser = this.authService.getCurrentUser();
    const employeeName = currentUser?.full_name || 'Unknown Employee';
    const currentDate = new Date().toLocaleDateString('en-PH');
    const currentTime = new Date().toLocaleTimeString();

    // Title Section
    doc.setFontSize(20);
    doc.setTextColor(41, 128, 185);
    doc.text('EMPLOYEE TRANSACTION REPORT', 105, 20, { align: 'center' });
    
    doc.setFontSize(12);
    doc.setTextColor(100, 100, 100);
    doc.text(`Generated by: ${employeeName}`, 105, 30, { align: 'center' });
    doc.text(`Date: ${currentDate} at ${currentTime}`, 105, 36, { align: 'center' });
    
    const dateRangeText = `Period: ${this.formatFilterDate(this.currentFilter.startDate)} - ${this.formatFilterDate(this.currentFilter.endDate)}`;
    doc.text(dateRangeText, 105, 42, { align: 'center' });

    let finalY = 50;

    // ===== SUMMARY SECTION ===== (FIXED: Use cleanAndParseNumber)
    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('SUMMARY OVERVIEW', 20, finalY);
    finalY += 10;

    const summaryData = [
      ['Total Transactions', this.reportSummary.totalTransactions.toString()],
      ['Cash Sales Total', `PHP ${this.cleanAndParseNumber(this.reportSummary.totalCashAmount).toFixed(2)}`],
      ['Debt Sales Total', `PHP ${this.cleanAndParseNumber(this.reportSummary.totalDebtAmount).toFixed(2)}`],
      ['Stock Transactions', this.reportSummary.totalStockTransactions.toString()],
      ['Stock In', this.reportSummary.stockIn.toString()],
      ['Stock Out', this.reportSummary.stockOut.toString()],
      ['Completed', this.reportSummary.completedTransactions.toString()],
      ['Pending', this.reportSummary.pendingTransactions.toString()]
    ];

    autoTable(doc, {
      startY: finalY,
      head: [['Metric', 'Value']],
      body: summaryData,
      theme: 'grid',
      headStyles: { fillColor: [66, 139, 202] },
      styles: { fontSize: 11, cellPadding: 3 }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;

    // ===== CASH SALES SECTION ===== (FIXED: Use cleanAndParseNumber)
    const cashTransactions = this.combinedReport.filter(tx => tx.type === 'cash');
    if (cashTransactions.length > 0) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(34, 139, 34);
      doc.text(`CASH SALES (${cashTransactions.length})`, 20, finalY);
      finalY += 10;

      const cashData = cashTransactions.map(tx => [
        this.formatDateShort(tx.date),
        this.truncateText(tx.customerName, 20),
        `PHP ${this.cleanAndParseNumber(tx.totalAmount).toFixed(2)}`, // FIXED
        tx.displayStatus || 'Completed',
        `${tx.itemsCount || 0} items`
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Customer', 'Amount', 'Status', 'Items']],
        body: cashData,
        theme: 'grid',
        headStyles: { fillColor: [34, 139, 34] },
        styles: { fontSize: 9, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable.finalY + 15;
    }

    // ===== DEBT SALES SECTION ===== (FIXED: Use cleanAndParseNumber)
    const debtTransactions = this.combinedReport.filter(tx => tx.type === 'debt');
    if (debtTransactions.length > 0) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(255, 165, 0);
      doc.text(`DEBT SALES (${debtTransactions.length})`, 20, finalY);
      finalY += 10;

      const debtData = debtTransactions.map(tx => [
        this.formatDateShort(tx.date),
        this.truncateText(tx.customerName, 18),
        `PHP ${this.cleanAndParseNumber(tx.totalAmount).toFixed(2)}`, // FIXED
        `PHP ${this.cleanAndParseNumber(tx.initialPayment).toFixed(2)}`, // FIXED
        `PHP ${this.cleanAndParseNumber(tx.remainingBalance).toFixed(2)}`, // FIXED
        tx.displayStatus || 'Pending'
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Customer', 'Total', 'Paid', 'Balance', 'Status']],
        body: debtData,
        theme: 'grid',
        headStyles: { fillColor: [255, 165, 0] },
        styles: { fontSize: 9, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable.finalY + 15;
    }

    // ===== STOCK TRANSACTIONS SECTION =====
    const stockTransactions = this.combinedReport.filter(tx => tx.type === 'stock');
    if (stockTransactions.length > 0) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(155, 89, 182);
      doc.text(`STOCK TRANSACTIONS (${stockTransactions.length})`, 20, finalY);
      finalY += 10;

      const stockData = stockTransactions.map(tx => [
        this.formatDateShort(tx.date),
        this.truncateText(tx.productName || tx.customerName, 15),
        tx.stockAction || 'Adjustment',
        (tx.quantity || 0).toString(),
        (tx.previousStock || 0).toString(),
        (tx.newStock || 0).toString(),
        this.truncateText(tx.reason || 'N/A', 15)
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Product', 'Action', 'Qty', 'Prev', 'New', 'Reason']],
        body: stockData,
        theme: 'grid',
        headStyles: { fillColor: [155, 89, 182] },
        styles: { fontSize: 9, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable.finalY + 15;
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
      `Transaction Type: ${this.getTransactionTypeLabel()}`,
      `Status: ${this.getStatusLabel()}`,
      `Employee: ${this.getEmployeeFilterLabel()}`,
      `Date Range: ${this.formatFilterDate(this.currentFilter.startDate)} - ${this.formatFilterDate(this.currentFilter.endDate)}`,
      `Total Records: ${this.combinedReport.length} transactions`
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
    const footerText = `Report generated by ${employeeName} on ${currentDate} at ${currentTime}`;
    doc.text(footerText, 105, doc.internal.pageSize.getHeight() - 10, { align: 'center' });

    // Save PDF
    const fileName = `employee-report-${new Date().toISOString().split('T')[0]}.pdf`;
    doc.save(fileName);

    this.showToast('PDF report downloaded successfully!', 'success');
    console.log('=== PDF GENERATION COMPLETED ===');

  } catch (error) {
    console.error('Error generating PDF:', error);
    this.showToast('Error generating PDF report', 'danger');
  } finally {
    await loading.dismiss();
  }
}

// Keep these helper methods:
private formatDateShort(date: Date): string {
  try {
    if (!date) return 'N/A';
    return date.toLocaleDateString('en-PH', {
      month: 'short',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true
    }).replace(',', '');
  } catch (error) {
    return 'Invalid Date';
  }
}

private truncateText(text: string, maxLength: number): string {
  if (!text || text === 'undefined' || text === 'null') return 'N/A';
  const cleanText = String(text).trim();
  if (cleanText.length <= maxLength) return cleanText;
  return cleanText.substring(0, maxLength - 2) + '..';
}


// NEW: Calculate column widths based on content
private calculateColumnWidths(headers: string[], data: string[][], totalWidth: number): number[] {
  const numColumns = headers.length;
  const baseWidth = totalWidth / numColumns;
  
  // Define relative widths based on column type
  const relativeWidths = headers.map((header, index) => {
    const headerLower = header.toLowerCase();
    if (headerLower.includes('date')) return 0.8;
    if (headerLower.includes('customer') || headerLower.includes('product') || headerLower.includes('reason')) return 1.2;
    if (headerLower.includes('amount') || headerLower.includes('price') || headerLower.includes('total') || headerLower.includes('balance')) return 0.9;
    if (headerLower.includes('status') || headerLower.includes('action')) return 0.8;
    if (headerLower.includes('items') || headerLower.includes('qty')) return 0.6;
    return 1.0;
  });

  const totalRelative = relativeWidths.reduce((sum, width) => sum + width, 0);
  
  return relativeWidths.map(width => (width / totalRelative) * totalWidth);
}

// ADD THIS METHOD: Use the same formatPrice from your working inventory
private formatPrice(price: any): string {
  console.log('🔧 formatPrice called with:', price, 'Type:', typeof price);
  
  if (price === null || price === undefined) {
    return '0.00';
  }
  
  // If it's already a number, just format it
  if (typeof price === 'number') {
    console.log('✅ Already a number, formatting:', price.toFixed(2));
    return price.toFixed(2);
  }
  
  const priceStr = price.toString().trim();
  console.log('🔧 Price string:', priceStr);
  
  // Handle the specific problematic format: "±4 5 . 0 0"
  if (priceStr.includes('±') || /\d\s+\d/.test(priceStr)) {
    console.log('🔄 Detected problematic format, cleaning...');
    
    // Remove all special characters and spaces
    let cleanedPrice = priceStr
      .replace(/[±₱&]/g, '')  // Remove special symbols
      .replace(/\s/g, '')     // Remove all spaces
      .replace(/[^\d.]/g, ''); // Remove any other non-numeric except decimal
    
    console.log('🔧 After cleaning:', cleanedPrice);
    
    // If we have something like "45.00", parse it
    if (cleanedPrice) {
      const numPrice = parseFloat(cleanedPrice);
      if (!isNaN(numPrice)) {
        console.log('✅ Successfully parsed:', numPrice.toFixed(2));
        return numPrice.toFixed(2);
      }
    }
  }
  
  // For normal string numbers
  if (typeof price === 'string') {
    const cleaned = price.replace(/[^\d.]/g, '');
    const numPrice = parseFloat(cleaned);
    const result = isNaN(numPrice) ? '0.00' : numPrice.toFixed(2);
    console.log('✅ Normal string conversion:', result);
    return result;
  }
  
  console.log('❌ Could not parse, returning 0.00');
  return '0.00';
}

// NEW: Section header with underline
private drawSectionHeader(pdf: jsPDF, title: string, x: number, y: number): number {
  pdf.setFontSize(14);
  pdf.setFont('helvetica', 'bold');
  pdf.setTextColor(52, 73, 94);
  pdf.text(title, x, y);
  
  // Underline
  pdf.setDrawColor(52, 152, 219);
  pdf.setLineWidth(0.5);
  pdf.line(x, y + 1, x + pdf.getTextWidth(title), y + 1);
  
  return y + 10;
}
// NEW: Helper method to get employee filter label
private getEmployeeFilterLabel(): string {
  if (this.currentFilter.employeeId === 'all') return 'All Employees';
  if (this.currentFilter.employeeId === 'current') {
    const currentUser = this.authService.getCurrentUser();
    return currentUser?.full_name || 'Current Employee';
  }
  
  const employee = this.employees.find(emp => emp.id === this.currentFilter.employeeId);
  return employee?.full_name || 'Selected Employee';
}

  // Utility methods
  private async showToast(message: string, color: string) {
    const toast = await this.toastController.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }

  // Refresh method
  async doRefresh(event: any) {
    await this.generateReport();
    event.target.complete();
  }

  // Getter for filtered transactions
  get filteredTransactions(): TransactionReport[] {
    return this.combinedReport;
  }

  // UI Helper Methods
  formatFilterDate(dateString: string): string {
    const date = new Date(dateString);
    return date.toLocaleDateString('en-PH', {
      month: 'short',
      day: 'numeric',
      year: 'numeric'
    });
  }

// Fix the filter display methods
getTransactionTypeLabel(): string {
  const types: Record<string, string> = {
    'cash': 'Cash Sales',
    'debt': 'Debt Sales',
    'stock': 'Stock Transactions'
  };
  return types[this.currentFilter.transactionType] || 'All Types';
}

getStatusLabel(): string {
  const statuses: Record<string, string> = {
    'completed': 'Completed',
    'pending': 'Pending',
    'overdue': 'Overdue'
  };
  return statuses[this.currentFilter.status] || 'All Status';
}

hasActiveFilters(): boolean {
  return this.currentFilter.transactionType !== 'all' || 
         this.currentFilter.status !== 'all' ||
         this.currentFilter.employeeId !== 'current' ||
         this.currentFilter.startDate !== this.getDefaultStartDate() ||
         this.currentFilter.endDate !== this.getDefaultEndDate();
}

// Update clear filters to show all data
async clearFilter() {
  this.currentFilter = {
    startDate: this.getDefaultStartDate(), // Use the new default
    endDate: this.getDefaultEndDate(), // Use the new default
    transactionType: 'all',
    status: 'all',
    employeeId: 'current'
  };
  
  await this.generateReport();
}

  clearTransactionTypeFilter() {
    this.currentFilter.transactionType = 'all';
    this.applyFilters();
  }

  clearStatusFilter() {
    this.currentFilter.status = 'all';
    this.applyFilters();
  }

  filterByType(type: 'all' | 'cash' | 'debt' | 'stock') {
    this.currentFilter.transactionType = type;
    this.applyFilters();
  }

  filterByStatus(status: string) {
    this.currentFilter.status = status;
    this.applyFilters();
  }

  getTransactionIcon(type: string): string {
    const icons: Record<string, string> = {
      'cash': 'cash',
      'debt': 'card',
      'stock': 'cube'
    };
    return icons[type] || 'receipt';
  }

  getTransactionTypeClass(type: string): string {
    return `transaction-type-${type}`;
  }
  // Add these methods to your Tab5Page class

// Helper for stock action icons
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

// Helper for stock action colors
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

// Helper for amount color classes
getAmountColorClass(transaction: TransactionReport): string {
  if (transaction.type !== 'stock') return '';
  
  const action = transaction.stockAction?.toLowerCase() || '';
  if (action.includes('in') || action.includes('increase')) {
    return 'stock-increase';
  } else if (action.includes('out') || action.includes('decrease')) {
    return 'stock-decrease';
  }
  return '';
}
// Add this method for debugging
logFilterState() {
  console.log('Current Filter State:', {
    startDate: this.currentFilter.startDate,
    endDate: this.currentFilter.endDate,
    transactionType: this.currentFilter.transactionType,
    status: this.currentFilter.status,
    employeeId: this.currentFilter.employeeId,
    hasActiveFilters: this.hasActiveFilters()
  });
  
  console.log('Data Counts:', {
    cash: this.cashTransactions.length,
    debt: this.debtTransactions.length,
    stock: this.stockTransactions.length,
    combined: this.combinedReport.length
  });
}

}