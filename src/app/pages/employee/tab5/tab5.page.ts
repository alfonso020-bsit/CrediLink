import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, orderBy, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';
import { TransactionDetailsModal } from './transaction-details-modal.component';
import { ModalController } from '@ionic/angular';

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

  async loadInitialData() {
    const loading = await this.loadingController.create({
      message: 'Loading report data...'
    });
    await loading.present();

    try {
      await Promise.all([
        this.loadEmployees(),
        this.generateReport()
      ]);
    } catch (error) {
      console.error('Error loading initial data:', error);
      this.showToast('Error loading report data', 'danger');
    } finally {
      await loading.dismiss();
    }
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
    
  } catch (error) {
    console.error('Error generating report:', error);
    this.showToast('Error generating report', 'danger');
  } finally {
    this.isLoading = false;
  }
}

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

    // Apply employee filter only
    if (this.currentFilter.employeeId === 'current') {
      q = query(q, where('employee_id', '==', currentUser.id));
    } else if (this.currentFilter.employeeId !== 'all') {
      q = query(q, where('employee_id', '==', this.currentFilter.employeeId));
    }

    const querySnapshot = await getDocs(q);
    
    this.cashTransactions = querySnapshot.docs
      .map(doc => {
        const data = doc.data();
        const transactionDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
        
        const transaction: TransactionReport = {
          id: data['id'] || doc.id,
          firestoreId: doc.id,
          type: 'cash',
          date: transactionDate,
          customerName: data['customerName'] || 'Walk-in Customer',
          totalAmount: data['total'] || 0,
          status: 'completed',
          paymentStatus: 'paid',
          employeeName: data['employee_name'] || currentUser?.full_name || 'Employee',
          employeeId: data['employee_id'],
          itemsCount: data['items']?.length || 0,
          details: data
        };
        
        // Add display properties
        transaction.displayType = 'Cash Sale';
        transaction.displayAmount = `₱${transaction.totalAmount.toFixed(2)}`;
        transaction.displayStatus = this.getStatusBadge(transaction.status, transaction.paymentStatus);
        
        return transaction;
      })
      .sort((a, b) => b.date.getTime() - a.date.getTime()); // Remove date filtering

  } catch (error) {
    console.error('Error loading cash transactions:', error);
    this.cashTransactions = [];
  }
}

async loadDebtTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id;
    
    if (!storeOwnerId) return;

    const debtProductsRef = collection(this.firestore, 'debt_products');
    let q = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );

    // Apply employee filter only
    if (this.currentFilter.employeeId === 'current') {
      q = query(q, where('employee_id', '==', currentUser.id));
    } else if (this.currentFilter.employeeId !== 'all') {
      q = query(q, where('employee_id', '==', this.currentFilter.employeeId));
    }

    const querySnapshot = await getDocs(q);
    
    this.debtTransactions = querySnapshot.docs
      .map(doc => {
        const data = doc.data();
        const transactionDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
        
        // Handle undefined values with defaults
        const remainingBalance = data['remainingBalance'] || data['total'] || 0;
        const initialPayment = data['initialPayment'] || 0;
        
        const transaction: TransactionReport = {
          id: data['id'] || doc.id,
          firestoreId: doc.id,
          type: 'debt',
          date: transactionDate,
          customerName: data['customerName'] || 'Unknown Customer',
          totalAmount: data['total'] || 0,
          status: data['status'] || 'pending',
          paymentStatus: data['payment_status'] || 'unpaid',
          employeeName: data['employee_name'] || currentUser?.full_name || 'Employee',
          employeeId: data['employee_id'],
          itemsCount: data['items']?.length || 0,
          remainingBalance: remainingBalance,
          initialPayment: initialPayment,
          dueDate: data['dueDate'],
          details: data
        };
        
        // Add display properties
        transaction.displayType = 'Debt Sale';
        transaction.displayAmount = `₱${transaction.totalAmount.toFixed(2)}`;
        transaction.displayStatus = this.getStatusBadge(transaction.status, transaction.paymentStatus);
        transaction.displayBalance = `₱${remainingBalance.toFixed(2)}`;
        
        return transaction;
      })
      .sort((a, b) => b.date.getTime() - a.date.getTime()); // Remove date filtering

  } catch (error) {
    console.error('Error loading debt transactions:', error);
    this.debtTransactions = [];
  }
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
  // UPDATED: Enhanced summary calculation with stock metrics
  calculateSummary() {
    const stockIn = this.stockTransactions.filter(tx => 
      tx.details?.change_type === 'increase' || tx.details?.type === 'stock_in'
    ).length;
    
    const stockOut = this.stockTransactions.filter(tx => 
      tx.details?.change_type === 'decrease' || tx.details?.type === 'stock_out'
    ).length;

    this.reportSummary = {
      totalTransactions: this.combinedReport.length,
      totalCashAmount: this.cashTransactions.reduce((sum, tx) => sum + tx.totalAmount, 0),
      totalDebtAmount: this.debtTransactions.reduce((sum, tx) => sum + tx.totalAmount, 0),
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

  // // UPDATED: Enhanced transaction details for stock transactions
  // getTransactionDetailsMessage(transaction: TransactionReport): string {
  //   let message = '';

  //   // Basic transaction info
  //   message += `<div class="detail-item"><strong>Type:</strong> ${transaction.displayType || transaction.type}</div>`;
  //   message += `<div class="detail-item"><strong>Date:</strong> ${this.formatDate(transaction.date)}</div>`;
  //   message += `<div class="detail-item"><strong>Employee:</strong> ${transaction.employeeName}</div>`;
  //   message += `<div class="detail-item"><strong>Status:</strong> ${transaction.displayStatus || transaction.status}</div>`;

  //   if (transaction.type === 'cash' || transaction.type === 'debt') {
  //     message += `<div class="detail-item"><strong>Customer:</strong> ${transaction.customerName}</div>`;
  //     message += `<div class="detail-item"><strong>Amount:</strong> ${transaction.displayAmount || `₱${transaction.totalAmount.toFixed(2)}`}</div>`;
  //     message += `<div class="detail-item"><strong>Items:</strong> ${transaction.itemsCount}</div>`;
      
  //     if (transaction.type === 'debt') {
  //       const remainingBalance = transaction.remainingBalance || 0;
  //       const initialPayment = transaction.initialPayment || 0;
        
  //       message += `<div class="detail-item"><strong>Remaining Balance:</strong> ₱${remainingBalance.toFixed(2)}</div>`;
  //       message += `<div class="detail-item"><strong>Initial Payment:</strong> ₱${initialPayment.toFixed(2)}</div>`;
        
  //       if (transaction.dueDate) {
  //         const dueDate = transaction.dueDate.toDate ? transaction.dueDate.toDate() : new Date(transaction.dueDate);
  //         message += `<div class="detail-item"><strong>Due Date:</strong> ${dueDate.toLocaleDateString()}</div>`;
  //       }
  //     }
  //   } else if (transaction.type === 'stock') {
  //     message += `<div class="detail-item"><strong>Product:</strong> ${transaction.productName}</div>`;
  //     message += `<div class="detail-item"><strong>Action:</strong> ${transaction.stockAction}</div>`;
  //     message += `<div class="detail-item"><strong>Quantity:</strong> ${transaction.quantity} units</div>`;
      
  //     if (transaction.reason) {
  //       message += `<div class="detail-item"><strong>Reason:</strong> ${transaction.reason}</div>`;
  //     }
      
  //     if (transaction.previousStock !== undefined && transaction.newStock !== undefined) {
  //       message += `<div class="detail-item"><strong>Stock Change:</strong> ${transaction.previousStock} → ${transaction.newStock}</div>`;
  //     }
  //   }

  //   return message;
  // }

  // UPDATED: Enhanced export methods to include stock details
  async exportToCSV() {
    try {
      const headers = ['Date', 'Type', 'Customer/Product', 'Amount/Details', 'Status', 'Employee', 'Items/Quantity', 'Additional Info'];
      const csvData = this.combinedReport.map(tx => {
        let additionalInfo = '';
        
        if (tx.type === 'debt' && tx.remainingBalance) {
          additionalInfo = `Balance: ₱${tx.remainingBalance.toFixed(2)}`;
        } else if (tx.type === 'stock') {
          additionalInfo = `${tx.stockAction} | Reason: ${tx.reason}`;
        }
        
        return [
          this.formatDate(tx.date),
          tx.displayType || tx.type,
          tx.customerName,
          tx.displayAmount || this.getStockTransactionDescription(tx),
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
  

  // Keep all other existing methods the same...
  // [All your existing methods remain unchanged below this point]
  // Only the methods above have been updated

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

// SIMPLER PDF Version - More reliable
async exportToPDF() {
  const loading = await this.loadingController.create({
    message: 'Generating PDF report...'
  });
  await loading.present();

  try {
    const pdf = new jsPDF();
    const pageWidth = pdf.internal.pageSize.getWidth();
    const margin = 20;
    let yPosition = 20;

    // Title
    pdf.setFontSize(16);
    pdf.text('Employee Transaction Report', pageWidth / 2, yPosition, { align: 'center' });
    yPosition += 15;

    // Date Range
    pdf.setFontSize(10);
    const dateRange = `${this.formatFilterDate(this.currentFilter.startDate)} - ${this.formatFilterDate(this.currentFilter.endDate)}`;
    pdf.text(`Date Range: ${dateRange}`, pageWidth / 2, yPosition, { align: 'center' });
    yPosition += 20;

    // Summary Section
    pdf.setFontSize(12);
    pdf.text('Summary', margin, yPosition);
    yPosition += 10;

    pdf.setFontSize(10);
    const summaries = [
      `Total Transactions: ${this.reportSummary.totalTransactions}`,
      `Cash Sales Total: ₱${this.reportSummary.totalCashAmount.toFixed(2)}`,
      `Debt Sales Total: ₱${this.reportSummary.totalDebtAmount.toFixed(2)}`,
      `Stock Transactions: ${this.reportSummary.totalStockTransactions}`,
      `Stock In: ${this.reportSummary.stockIn} | Stock Out: ${this.reportSummary.stockOut}`,
      `Completed: ${this.reportSummary.completedTransactions} | Pending: ${this.reportSummary.pendingTransactions}`
    ];

    summaries.forEach(summary => {
      if (yPosition > 270) {
        pdf.addPage();
        yPosition = 20;
      }
      pdf.text(summary, margin, yPosition);
      yPosition += 7;
    });

    yPosition += 10;

    // Transactions Section
    if (this.combinedReport.length > 0) {
      pdf.setFontSize(12);
      pdf.text('Transaction Details', margin, yPosition);
      yPosition += 10;

      this.combinedReport.forEach((transaction, index) => {
        if (yPosition > 270) {
          pdf.addPage();
          yPosition = 20;
        }

        // Transaction Header
        pdf.setFontSize(10);
        pdf.setFont('helvetica', 'bold');
        const header = `${this.formatDateForPDF(transaction.date)} - ${transaction.displayType}`;
        pdf.text(header, margin, yPosition);
        pdf.setFont('helvetica', 'normal');
        yPosition += 7;

        // Transaction Details
        pdf.setFontSize(9);
        pdf.text(`Customer: ${transaction.customerName}`, margin + 5, yPosition);
        yPosition += 5;
        
        const details = transaction.displayAmount || this.getStockTransactionDescription(transaction);
        pdf.text(`Details: ${details}`, margin + 5, yPosition);
        yPosition += 5;
        
        pdf.text(`Status: ${transaction.displayStatus} | Employee: ${transaction.employeeName}`, margin + 5, yPosition);
        yPosition += 5;

        // Additional Info
        if (transaction.type === 'debt' && transaction.remainingBalance) {
          pdf.text(`Balance: ₱${transaction.remainingBalance.toFixed(2)}`, margin + 5, yPosition);
          yPosition += 5;
        } else if (transaction.type === 'stock' && transaction.reason) {
          pdf.text(`Reason: ${transaction.reason}`, margin + 5, yPosition);
          yPosition += 5;
        }

        // Separator
        if (index < this.combinedReport.length - 1) {
          yPosition += 3;
          pdf.setDrawColor(200, 200, 200);
          pdf.line(margin, yPosition, pageWidth - margin, yPosition);
          yPosition += 5;
        }
      });
    } else {
      pdf.text('No transactions found for the selected filters.', margin, yPosition);
    }

    // Footer
    pdf.setFontSize(8);
    pdf.setTextColor(150, 150, 150);
    pdf.text(`Generated on ${new Date().toLocaleDateString()}`, pageWidth / 2, pdf.internal.pageSize.getHeight() - 10, { align: 'center' });

    // Save PDF
    const fileName = `employee-report-${new Date().toISOString().split('T')[0]}.pdf`;
    pdf.save(fileName);

    this.showToast('PDF report downloaded successfully', 'success');
  } catch (error) {
    console.error('Error generating PDF:', error);
    this.showToast('Error generating PDF report', 'danger');
  } finally {
    await loading.dismiss();
  }
}

// NEW: Helper method for PDF date formatting
private formatDateForPDF(date: Date): string {
  return date.toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit'
  });
}

// NEW: Helper method to truncate long text for PDF
private truncateText(text: string, maxLength: number): string {
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength - 3) + '...';
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