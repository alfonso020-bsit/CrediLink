import { Component, OnInit, OnDestroy } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, doc, Timestamp, onSnapshot, Unsubscribe } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';

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

export interface DebtNotification {
  id: string;
  type: 'new_debt' | 'payment_received' | 'due_soon' | 'overdue' | 'fully_paid';
  title: string;
  message: string;
  debtId: string;
  customerName: string;
  timestamp: any;
  read: boolean;
  priority: 'low' | 'medium' | 'high';
}

@Component({
  selector: 'app-storeowner-tab3',
  templateUrl: './tab3.page.html',
  styleUrls: ['./tab3.page.scss'],
  standalone: false,
})
export class Tab3Page implements OnInit, OnDestroy {
  allDebtProducts: DebtProduct[] = [];
  filteredDebts: DebtProduct[] = [];
  notifications: DebtNotification[] = [];
  
  // Analytics
  totalOutstanding: number = 0;
  overdueAmount: number = 0;
  totalDebtCustomers: number = 0;
  collectionRate: number = 0;
  
  // Debt aging
  debtAging = {
    current: 0,
    '1-30': 0,
    '31-60': 0,
    '61-90': 0,
    '90+': 0
  };
  
  // Employee performance
  employeeDebtSummary: any[] = [];
  
  // Filters
  searchTerm: string = '';
  statusFilter: string = 'all';
  employeeFilter: string = 'all';
  dateFilter: string = 'all';
  
  // UI States
  showNotifications: boolean = false;
  activeView: 'overview' | 'debts' | 'customers' | 'employees' = 'overview';
  unreadNotifications: number = 0;
  
  // Firestore listeners
  private debtUnsubscribe: Unsubscribe | null = null;
  private notificationUnsubscribe: Unsubscribe | null = null;

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private alertController: AlertController,
    private modalController: ModalController
  ) { }

  async ngOnInit() {
    await this.loadDebtData();
    this.setupRealTimeListeners();
  }

  ngOnDestroy() {
    if (this.debtUnsubscribe) {
      this.debtUnsubscribe();
    }
    if (this.notificationUnsubscribe) {
      this.notificationUnsubscribe();
    }
  }

  async loadDebtData() {
    const loading = await this.loadingController.create({
      message: 'Loading debt data...'
    });
    await loading.present();

    try {
      await Promise.all([
        this.loadAllDebts(),
        this.loadNotifications()
      ]);
      this.calculateAnalytics();
      this.calculateEmployeePerformance();
    } catch (error) {
      console.error('Error loading debt data:', error);
      this.showToast('Error loading debt data', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  async loadAllDebts() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.id;
      
      if (!storeOwnerId) {
        throw new Error('User not authenticated');
      }

      const debtProductsRef = collection(this.firestore, 'debt_products');
      const q = query(
        debtProductsRef,
        where('store_owner_id', '==', storeOwnerId)
      );
      
      const querySnapshot = await getDocs(q);
      
      this.allDebtProducts = await Promise.all(
        querySnapshot.docs.map(async (doc) => {
          const data = doc.data();
          
          // ✅ FIXED: Calculate remainingBalance properly with null safety
          const total = data['total'] || 0;
          const remainingBalance = data['remainingBalance'] ?? total;
          const initialPayment = data['initialPayment'] || 0;
          const payments = data['payments'] || [];
          
          // ✅ FIXED: Calculate status based on actual data from Firestore
          let payment_status = data['payment_status'] || 'unpaid';
          let status = data['status'] || 'pending';
          
          // ✅ CRITICAL: Use the actual remainingBalance from Firestore to determine status
          if (remainingBalance <= 0) {
            payment_status = 'paid';
            status = 'paid';
          } else if (initialPayment > 0 || payments.length > 0) {
            payment_status = 'partially_paid';
          } else {
            payment_status = 'unpaid';
          }
          
          const debtProduct: DebtProduct = {
            items: data['items'] || [],
            total: total,
            paymentMethod: data['paymentMethod'] || 'debt',
            customerName: data['customerName'] || '',
            customerPhone: data['customerPhone'] || '',
            dueDate: data['dueDate'] || null,
            status: status, // ✅ Use calculated status
            receipt_image: data['receipt_image'] || '',
            created_at: data['created_at'] || null,
            store_owner_id: data['store_owner_id'] || '',
            employee_id: data['employee_id'] || '',
            payment_status: payment_status, // ✅ Use calculated payment_status
            id: data['id'] || doc.id,
            firestoreId: doc.id,
            initialPayment: initialPayment,
            remainingBalance: remainingBalance, // ✅ Use actual remaining balance from Firestore
            originalTotal: data['originalTotal'] || total,
            payments: payments,
            employeeName: await this.getEmployeeName(data['employee_id'])
          };
          
          console.log('📥 Tab3 - Loaded debt:', {
            customer: debtProduct.customerName,
            remainingBalance: debtProduct.remainingBalance,
            payment_status: debtProduct.payment_status,
            status: debtProduct.status,
            firestoreId: debtProduct.firestoreId
          });
          
          return debtProduct;
        })
      );

      // ✅ FIXED: Call updateDebtStatuses to ensure consistency
      this.updateDebtStatuses();
      this.filteredDebts = [...this.allDebtProducts];
      
      // Debug all debts
      this.debugAllDebts();
      
    } catch (error) {
      console.error('Error loading debts:', error);
      this.allDebtProducts = [];
      this.filteredDebts = [];
    }
  }

  async loadNotifications() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.id;
      
      if (!storeOwnerId) return;

      const notificationsRef = collection(this.firestore, 'debt_notifications');
      const q = query(
        notificationsRef,
        where('store_owner_id', '==', storeOwnerId),
        where('read', '==', false)
      );
      
      const querySnapshot = await getDocs(q);
      this.notifications = querySnapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          type: data['type'],
          title: data['title'],
          message: data['message'],
          debtId: data['debtId'],
          customerName: data['customerName'],
          timestamp: data['timestamp'],
          read: data['read'],
          priority: data['priority']
        };
      });

      this.unreadNotifications = this.notifications.length;
      
    } catch (error) {
      console.error('Error loading notifications:', error);
      this.notifications = [];
    }
  }

  setupRealTimeListeners() {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) return;

    // Real-time debt listener
    const debtProductsRef = collection(this.firestore, 'debt_products');
    const debtQuery = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    this.debtUnsubscribe = onSnapshot(debtQuery, (snapshot) => {
      console.log('🔄 Tab3 - Real-time debt update detected');
      snapshot.docChanges().forEach((change) => {
        if (change.type === 'added' || change.type === 'modified') {
          this.checkForNotifications(change.doc.data(), change.type);
        }
      });
      this.loadDebtData(); // Reload data when changes occur
    });

    // Real-time notification listener
    const notificationsRef = collection(this.firestore, 'debt_notifications');
    const notificationQuery = query(
      notificationsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    this.notificationUnsubscribe = onSnapshot(notificationQuery, (snapshot) => {
      this.loadNotifications();
    });
  }

  async checkForNotifications(debtData: any, changeType: string) {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) return;

    const now = new Date();
    const dueDate = debtData.dueDate?.toDate ? debtData.dueDate.toDate() : new Date(debtData.dueDate);
    const daysUntilDue = Math.ceil((dueDate.getTime() - now.getTime()) / (1000 * 60 * 60 * 24));

    // Check for due soon (3 days before due date)
    if (daysUntilDue <= 3 && daysUntilDue > 0 && debtData.payment_status !== 'paid') {
      await this.createNotification({
        store_owner_id: storeOwnerId,
        type: 'due_soon',
        title: 'Debt Due Soon',
        message: `Debt for ${debtData.customerName} is due in ${daysUntilDue} days`,
        debtId: debtData.id || debtData.firestoreId,
        customerName: debtData.customerName,
        timestamp: Timestamp.now(),
        read: false,
        priority: 'medium'
      });
    }

    // Check for overdue
    if (daysUntilDue < 0 && debtData.payment_status !== 'paid') {
      await this.createNotification({
        store_owner_id: storeOwnerId,
        type: 'overdue',
        title: 'Debt Overdue',
        message: `Debt for ${debtData.customerName} is ${Math.abs(daysUntilDue)} days overdue`,
        debtId: debtData.id || debtData.firestoreId,
        customerName: debtData.customerName,
        timestamp: Timestamp.now(),
        read: false,
        priority: 'high'
      });
    }

    // Check for new payments
    if (changeType === 'modified' && debtData.payments) {
      const currentDebt = this.allDebtProducts.find(d => d.firestoreId === (debtData.id || debtData.firestoreId));
      if (currentDebt && currentDebt.payments && debtData.payments.length > currentDebt.payments.length) {
        const newPayment = debtData.payments[debtData.payments.length - 1];
        await this.createNotification({
          store_owner_id: storeOwnerId,
          type: 'payment_received',
          title: 'Payment Received',
          message: `Payment of PHP ${newPayment.amount} received from ${debtData.customerName}`,
          debtId: debtData.id || debtData.firestoreId,
          customerName: debtData.customerName,
          timestamp: Timestamp.now(),
          read: false,
          priority: 'low'
        });
      }
    }

    // Check for fully paid
    if (debtData.payment_status === 'paid' && changeType === 'modified') {
      const currentDebt = this.allDebtProducts.find(d => d.firestoreId === (debtData.id || debtData.firestoreId));
      if (currentDebt && currentDebt.payment_status !== 'paid') {
        await this.createNotification({
          store_owner_id: storeOwnerId,
          type: 'fully_paid',
          title: 'Debt Fully Paid',
          message: `Debt for ${debtData.customerName} has been fully paid`,
          debtId: debtData.id || debtData.firestoreId,
          customerName: debtData.customerName,
          timestamp: Timestamp.now(),
          read: false,
          priority: 'low'
        });
      }
    }
  }

  async createNotification(notificationData: any) {
    try {
      const { addDoc, collection } = await import('@angular/fire/firestore');
      const notificationsRef = collection(this.firestore, 'debt_notifications');
      await addDoc(notificationsRef, notificationData);
    } catch (error) {
      console.error('Error creating notification:', error);
    }
  }

  async markNotificationAsRead(notificationId: string) {
    try {
      const { doc, updateDoc } = await import('@angular/fire/firestore');
      const notificationRef = doc(this.firestore, 'debt_notifications', notificationId);
      await updateDoc(notificationRef, { read: true });
    } catch (error) {
      console.error('Error marking notification as read:', error);
    }
  }

  async markAllNotificationsAsRead() {
    try {
      const { writeBatch, doc } = await import('@angular/fire/firestore');
      const batch = writeBatch(this.firestore);
      
      this.notifications.forEach(notification => {
        const notificationRef = doc(this.firestore, 'debt_notifications', notification.id);
        batch.update(notificationRef, { read: true });
      });
      
      await batch.commit();
      this.showToast('All notifications marked as read', 'success');
    } catch (error) {
      console.error('Error marking all notifications as read:', error);
      this.showToast('Error updating notifications', 'danger');
    }
  }

  calculateAnalytics() {
    // ✅ FIXED: Use the updated debt statuses for calculations
    this.totalOutstanding = this.allDebtProducts
      .filter(debt => debt.payment_status !== 'paid')
      .reduce((sum, debt) => sum + (debt.remainingBalance || debt.total), 0);

    this.overdueAmount = this.allDebtProducts
      .filter(debt => debt.status === 'overdue')
      .reduce((sum, debt) => sum + (debt.remainingBalance || debt.total), 0);

    this.totalDebtCustomers = new Set(
      this.allDebtProducts
        .filter(debt => debt.payment_status !== 'paid')
        .map(debt => debt.customerPhone)
    ).size;

    const totalDebt = this.allDebtProducts.reduce((sum, debt) => sum + debt.total, 0);
    const collected = this.allDebtProducts.reduce((sum, debt) => 
      sum + (debt.initialPayment || 0) + 
      (debt.payments?.reduce((pSum, payment) => pSum + payment.amount, 0) || 0), 0);
    
    this.collectionRate = totalDebt > 0 ? (collected / totalDebt) * 100 : 100;

    this.calculateDebtAging();
  }

  calculateDebtAging() {
    const now = new Date();
    this.debtAging = { current: 0, '1-30': 0, '31-60': 0, '61-90': 0, '90+': 0 };
    
    this.allDebtProducts
      .filter(debt => debt.payment_status !== 'paid' && debt.dueDate)
      .forEach(debt => {
        const dueDate = debt.dueDate.toDate ? debt.dueDate.toDate() : new Date(debt.dueDate);
        const daysOverdue = Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24));
        const amount = debt.remainingBalance || debt.total;
        
        if (daysOverdue <= 0) {
          this.debtAging.current += amount;
        } else if (daysOverdue <= 30) {
          this.debtAging['1-30'] += amount;
        } else if (daysOverdue <= 60) {
          this.debtAging['31-60'] += amount;
        } else if (daysOverdue <= 90) {
          this.debtAging['61-90'] += amount;
        } else {
          this.debtAging['90+'] += amount;
        }
      });
  }

  calculateEmployeePerformance() {
    const employeeMap = new Map();
    
    this.allDebtProducts.forEach(debt => {
      if (!employeeMap.has(debt.employee_id)) {
        employeeMap.set(debt.employee_id, {
          employeeId: debt.employee_id,
          employeeName: debt.employeeName || 'Unknown Employee',
          totalDebts: 0,
          totalAmount: 0,
          outstandingBalance: 0,
          paidDebts: 0,
          collectionRate: 0
        });
      }
      
      const employeeStats = employeeMap.get(debt.employee_id);
      employeeStats.totalDebts++;
      employeeStats.totalAmount += debt.total;
      
      if (debt.payment_status !== 'paid') {
        employeeStats.outstandingBalance += debt.remainingBalance || debt.total;
      } else {
        employeeStats.paidDebts++;
      }
    });

    // Calculate collection rate for each employee
    employeeMap.forEach(employee => {
      employee.collectionRate = employee.totalAmount > 0 ? 
        ((employee.totalAmount - employee.outstandingBalance) / employee.totalAmount) * 100 : 100;
    });
    
    this.employeeDebtSummary = Array.from(employeeMap.values())
      .sort((a, b) => b.outstandingBalance - a.outstandingBalance);
  }

  // ✅ FIXED: Proper updateDebtStatuses method
  updateDebtStatuses() {
    const now = new Date();
    
    console.log('🔄 Tab3 - updateDebtStatuses - Checking all debts:');
    
    this.allDebtProducts.forEach(debt => {
      // ✅ FIXED: Proper null safety checks with explicit defaults
      const remainingBalance = debt.remainingBalance ?? debt.total ?? 0;
      const initialPayment = debt.initialPayment ?? 0;
      const payments = debt.payments ?? [];
      
      console.log('🔍 Checking debt:', {
        customer: debt.customerName,
        remainingBalance: remainingBalance,
        initialPayment: initialPayment,
        currentPaymentStatus: debt.payment_status,
        firestoreId: debt.firestoreId
      });

      // ✅ FIXED: ALWAYS recalculate payment_status based on remainingBalance
      // This ensures UI consistency with the actual data
      if (remainingBalance <= 0) {
        debt.payment_status = 'paid';
        debt.status = 'paid';
        debt.remainingBalance = 0; // ✅ Ensure it's explicitly set to 0
        console.log('✅ Setting to PAID - remaining balance is 0 or negative');
      } else if (initialPayment > 0 || payments.length > 0) {
        debt.payment_status = 'partially_paid';
        console.log('🟡 Setting to PARTIALLY_PAID - has payments made');
      } else {
        debt.payment_status = 'unpaid';
        console.log('🔴 Setting to UNPAID - no payments made');
      }

      // ✅ FIXED: Only check due date for unpaid/partially paid debts
      // Don't override paid status with overdue/pending
      if (debt.payment_status !== 'paid' && debt.dueDate) {
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

  // ✅ FIXED: Enhanced filter method
  applyFilters() {
    let filtered = this.allDebtProducts;

    // Search filter
    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(debt => 
        debt.customerName?.toLowerCase().includes(term) ||
        debt.customerPhone?.toLowerCase().includes(term) ||
        debt.employeeName?.toLowerCase().includes(term)
      );
    }

    // Status filter
    if (this.statusFilter !== 'all') {
      filtered = filtered.filter(debt => {
        if (this.statusFilter === 'overdue') {
          return debt.status === 'overdue';
        } else if (this.statusFilter === 'paid') {
          return debt.payment_status === 'paid';
        } else {
          return debt.payment_status === this.statusFilter;
        }
      });
    }

    // Employee filter
    if (this.employeeFilter !== 'all') {
      filtered = filtered.filter(debt => debt.employee_id === this.employeeFilter);
    }

    this.filteredDebts = filtered;
    
    console.log('🔍 Tab3 - Applied filters:', {
      originalCount: this.allDebtProducts.length,
      filteredCount: this.filteredDebts.length,
      statusFilter: this.statusFilter
    });
  }

  // Debug method to check all debts
  debugAllDebts(): void {
    console.log('=== TAB3 DEBUG - ALL DEBTS ===');
    this.allDebtProducts.forEach((debt, index) => {
      console.log(`Debt ${index + 1}:`, {
        customer: debt.customerName,
        firestoreId: debt.firestoreId,
        total: debt.total,
        remainingBalance: debt.remainingBalance,
        payment_status: debt.payment_status,
        status: debt.status,
        calculatedShouldBePaid: (debt.remainingBalance ?? debt.total) <= 0
      });
    });
    
    const paidCount = this.allDebtProducts.filter(d => d.payment_status === 'paid').length;
    const partiallyPaidCount = this.allDebtProducts.filter(d => d.payment_status === 'partially_paid').length;
    const unpaidCount = this.allDebtProducts.filter(d => d.payment_status === 'unpaid').length;
    
    console.log('📊 Summary:', {
      total: this.allDebtProducts.length,
      paid: paidCount,
      partially_paid: partiallyPaidCount,
      unpaid: unpaidCount
    });
    console.log('=== END TAB3 DEBUG ===');
  }

  // Utility methods
  async getEmployeeName(employeeId: string): Promise<string> {
    if (!employeeId) return 'Unknown Employee';
    
    try {
      const employeesRef = collection(this.firestore, 'all_users');
      const q = query(employeesRef, where('__name__', '==', employeeId));
      const querySnapshot = await getDocs(q);
      
      if (!querySnapshot.empty) {
        const employeeData = querySnapshot.docs[0].data();
        return employeeData['full_name'] || employeeData['name'] || employeeData['displayName'] || 'Unknown Employee';
      }
      
      return 'Unknown Employee';
    } catch (error) {
      console.error('Error fetching employee name:', error);
      return 'Unknown Employee';
    }
  }

  formatCurrency(amount: number): string {
    return `PHP ${amount?.toFixed(2) || '0.00'}`;
  }

  formatDate(date: any): string {
    if (!date) return 'N/A';
    
    try {
      const jsDate = date.toDate ? date.toDate() : new Date(date);
      return jsDate.toLocaleDateString('en-PH', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  }

  getPaymentStatusColor(status: string): string {
    switch (status) {
      case 'paid': return 'success';
      case 'partially_paid': return 'warning';
      case 'unpaid': return 'danger';
      default: return 'medium';
    }
  }

  getStatusColor(status: string): string {
    switch (status) {
      case 'paid': return 'success';
      case 'pending': return 'warning';
      case 'overdue': return 'danger';
      default: return 'medium';
    }
  }

  getNotificationColor(priority: string): string {
    switch (priority) {
      case 'high': return 'danger';
      case 'medium': return 'warning';
      case 'low': return 'success';
      default: return 'medium';
    }
  }

  getEmployeePerformanceColor(employee: any): string {
    if (employee.collectionRate >= 80) return 'success';
    if (employee.collectionRate >= 60) return 'warning';
    return 'danger';
  }

  // View management
  setActiveView(view: 'overview' | 'debts' | 'customers' | 'employees') {
    this.activeView = view;
  }

  toggleNotifications() {
    this.showNotifications = !this.showNotifications;
  }

  // Refresh method
  async doRefresh(event: any) {
    await this.loadDebtData();
    event.target.complete();
  }

  // Report Generation (keep your existing method)
  async generateDebtReport() {
    // ... your existing generateDebtReport method ...
  }

  getTopDebtors(limit: number = 5): any[] {
    const customerMap = new Map();
    
    this.allDebtProducts
      .filter(debt => debt.payment_status !== 'paid')
      .forEach(debt => {
        if (!customerMap.has(debt.customerPhone)) {
          customerMap.set(debt.customerPhone, {
            name: debt.customerName,
            phone: debt.customerPhone,
            totalOwed: 0,
            debtCount: 0
          });
        }
        
        const customer = customerMap.get(debt.customerPhone);
        customer.totalOwed += debt.remainingBalance || debt.total;
        customer.debtCount++;
      });
    
    return Array.from(customerMap.values())
      .sort((a, b) => b.totalOwed - a.totalOwed)
      .slice(0, limit);
  }

  private truncateText(text: string, maxLength: number): string {
    if (!text || text === 'undefined' || text === 'null') return 'N/A';
    
    const cleanText = String(text)
      .trim()
      .replace(/[^\w\s]/gi, '')
      .substring(0, maxLength);
    
    return cleanText.length >= maxLength ? cleanText + '..' : cleanText;
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

  // Additional helper methods
  getAgingBreakdown(): any[] {
    return [
      { label: 'Current', amount: this.debtAging.current },
      { label: '1-30 Days', amount: this.debtAging['1-30'] },
      { label: '31-60 Days', amount: this.debtAging['31-60'] },
      { label: '61-90 Days', amount: this.debtAging['61-90'] },
      { label: '90+ Days', amount: this.debtAging['90+'] }
    ];
  }

  getAgingPercentage(amount: number): number {
    const totalAging = Object.values(this.debtAging).reduce((sum, val) => sum + val, 0);
    return totalAging > 0 ? (amount / totalAging) * 100 : 0;
  }

  getCustomersWithDebt(): any[] {
    const customerMap = new Map();
    
    this.allDebtProducts
      .filter(debt => debt.payment_status !== 'paid')
      .forEach(debt => {
        if (!customerMap.has(debt.customerPhone)) {
          customerMap.set(debt.customerPhone, {
            name: debt.customerName,
            phone: debt.customerPhone,
            totalOwed: 0,
            debtCount: 0
          });
        }
        
        const customer = customerMap.get(debt.customerPhone);
        customer.totalOwed += debt.remainingBalance || debt.total;
        customer.debtCount++;
      });
    
    return Array.from(customerMap.values())
      .sort((a, b) => b.totalOwed - a.totalOwed);
  }

  getNotificationIcon(type: string): string {
    switch (type) {
      case 'new_debt': return 'add-circle';
      case 'payment_received': return 'cash';
      case 'due_soon': return 'time';
      case 'overdue': return 'warning';
      case 'fully_paid': return 'checkmark-done';
      default: return 'notifications';
    }
  }

  getDebtIcon(status: string): string {
    switch (status) {
      case 'paid': return 'checkmark-circle';
      case 'partially_paid': return 'time';
      case 'unpaid': return 'alert-circle';
      default: return 'document-text';
    }
  }

  // Navigation methods
  viewDebtDetails(debt: DebtProduct) {
    console.log('View debt details:', debt);
  }

  viewCustomerDetails(customer: any) {
    console.log('View customer details:', customer);
  }
}