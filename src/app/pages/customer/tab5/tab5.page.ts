import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, doc, getDoc, updateDoc, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { StoreService } from 'src/app/services/store.service';
import { DayEventsModalComponent } from 'src/app/pages/customer/tab5/day-events-modal.component';

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
  
  // Store information
  storeName?: string;
  storeProfileImage?: string;
  storeColor?: string;
  storeInitials?: string;
  storeAddress?: string;
  storeContact?: string;
  
  // Additional fields for alerts
  isOverdue?: boolean;
  daysUntilDue?: number;
  days_remaining?: number;
}

export interface PaymentHistory {
  amount: number;
  paymentDate: any;
  receipt_image?: string;
  paid_by?: string;
  notes?: string;
}

export interface CalendarDay {
  date: string | null;
  day: number | null;
  hasDebtEvents: boolean;
  debtCount: number;
  isDueToday: boolean;
  isDueSoon: boolean;
  isOverdue: boolean;
  hasPayments: boolean;
  hasNewStores: boolean;
  events: CalendarEvent[];
}

export interface CalendarEvent {
  type: 'debt_created' | 'payment_made' | 'due_date' | 'new_store' | 'payment_reminder';
  debt?: DebtProduct;
  payment?: PaymentHistory;
  store?: any;
  title: string;
  description: string;
  color: string;
  icon: string;
}

export interface Alert {
  id: string;
  type: 'new_store' | 'payment_reminder' | 'due_date_alert' | 'overdue_alert' | 'system';
  title: string;
  message: string;
  date: any;
  read: boolean;
  actionUrl?: string;
  storeId?: string;
  debtId?: string;
  priority: 'low' | 'medium' | 'high';
}

@Component({
  selector: 'app-customer-tab5',
  templateUrl: './tab5.page.html',
  styleUrls: ['./tab5.page.scss'],
  standalone: false,
})
export class Tab5Page implements OnInit {
  debts: DebtProduct[] = [];
  filteredDebts: DebtProduct[] = [];
  calendarDays: CalendarDay[] = [];
  alerts: Alert[] = [];
  unreadAlertsCount: number = 0;
  
  // Summary statistics
  totalDebtAmount: number = 0;
  dueSoonAmount: number = 0;
  overdueAmount: number = 0;
  dueSoonCount: number = 0;
  overdueCount: number = 0;
  
  // Calendar
  currentDate: Date = new Date();
  currentMonth: string = '';
  selectedDate: string = '';
  weekDays: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  
  // Filtering
  currentFilter: string = 'all';
  showAlertsPanel: boolean = false;
  
  // UI states
  isLoading: boolean = false;
  showDebtModal: boolean = false;
  selectedDebt: DebtProduct | null = null;

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private storeService: StoreService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private modalController: ModalController,
    private alertController: AlertController
  ) { }

  async ngOnInit() {
    await this.loadAllData();
    this.generateCalendar();
  }

  async loadAllData() {
    const loading = await this.loadingController.create({
      message: 'Loading your financial overview...'
    });
    await loading.present();

    try {
      this.isLoading = true;
      await Promise.all([
        this.loadDebts(),
        this.loadAlerts(),
        this.checkForNewStores()
      ]);
       this.debugCalendarEvents();
      
    } catch (error) {
      console.error('Error loading data:', error);
      this.showToast('Error loading your data', 'danger');
    } finally {
      this.isLoading = false;
      await loading.dismiss();
    }
  }

  async loadDebts() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      if (!customerName) {
        throw new Error('User not authenticated');
      }

      console.log('🔄 Loading debts for customer:', customerName);

      const debtProductsRef = collection(this.firestore, 'debt_products');
      const q = query(
        debtProductsRef,
        where('customerName', '==', customerName)
      );
      
      const querySnapshot = await getDocs(q);
      this.debts = [];
      
      for (const debtDoc of querySnapshot.docs) {
        const data = debtDoc.data();
        const debt = await this.transformDebtData(debtDoc.id, data);
        this.debts.push(debt);
      }
      
      this.calculateSummary();
      this.applyFilter();
      
      console.log(`✅ Loaded ${this.debts.length} debt records for alerts`);
      
    } catch (error) {
      console.error('Error loading debts:', error);
      await this.loadDebtsFallback();
    }
  }

private async transformDebtData(id: string, data: any): Promise<DebtProduct> {
  // Get store information
  const storeInfo = await this.getStoreInfo(data['store_owner_id']);
  
  // Calculate remaining balance
  const remainingBalance = data['remainingBalance'] !== undefined 
    ? data['remainingBalance'] 
    : (data['total'] - (data['amountPaid'] || 0)) || 0;

  // Handle dates properly - convert Timestamp to Date if needed
  const dueDate = data['dueDate'];
  const created_at = data['created_at'];
  
  // Calculate days remaining
  let daysRemaining = 0;
  let isOverdue = false;
  
  if (dueDate) {
    const dueDateObj = dueDate?.toDate ? dueDate.toDate() : new Date(dueDate);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    const dueDateOnly = new Date(dueDateObj);
    dueDateOnly.setHours(0, 0, 0, 0);
    
    const timeDiff = dueDateOnly.getTime() - today.getTime();
    daysRemaining = Math.ceil(timeDiff / (1000 * 3600 * 24));
    isOverdue = dueDateObj < today && data['payment_status'] !== 'paid';
  }

  // Handle payments array with proper date conversion
  const payments: PaymentHistory[] = (data['payments'] || []).map((payment: any) => ({
    amount: payment.amount,
    paymentDate: payment.paymentDate, // Keep as Timestamp, we'll convert in calendar
    receipt_image: payment.receipt_image || data['receiptImage'],
    paid_by: payment.paid_by,
    notes: payment.notes
  }));

  return {
    // Required properties from Firestore - KEEP AS TIMESTAMP
    items: data['items'] || [],
    total: data['total'] || 0,
    paymentMethod: data['paymentMethod'] || 'debt',
    customerName: data['customerName'] || '',
    customerPhone: data['customerPhone'] || '',
    dueDate: dueDate, // Keep original Timestamp
    status: data['status'] || 'pending',
    receipt_image: data['receipt_image'] || data['receiptImage'] || '',
    created_at: created_at, // Keep original Timestamp
    store_owner_id: data['store_owner_id'] || '',
    employee_id: data['employee_id'] || '',
    payment_status: data['payment_status'] || 'unpaid',
    
    // Document IDs
    id: data['id'],
    firestoreId: id,
    
    // Financial details
    initialPayment: data['initialPayment'] || 0,
    remainingBalance: remainingBalance,
    originalTotal: data['originalTotal'] || data['total'] || 0,
    payments: payments,
    
    // Store information
    storeName: storeInfo.storeName,
    storeProfileImage: storeInfo.storeProfileImage,
    storeColor: storeInfo.storeColor,
    storeInitials: storeInfo.storeInitials,
    storeAddress: storeInfo.storeAddress,
    storeContact: storeInfo.storeContact,
    
    // Status calculations for alerts
    isOverdue: isOverdue,
    daysUntilDue: this.calculateDaysUntilDue(dueDate),
    days_remaining: daysRemaining
  };
}
// Enhanced debug method to see exact date comparisons
debugSpecificDates() {
  console.log('=== SPECIFIC DATE DEBUG ===');
  
  // Check the specific dates from your sample data
  const sampleDates = [
    '2025-11-27', // created_at
    '2025-11-28', // paymentDate  
    '2025-12-12'  // dueDate
  ];
  
  this.debts.forEach((debt, debtIndex) => {
    console.log(`\n=== Debt ${debtIndex + 1} Details ===`);
    
    // Debug created_at date
    if (debt.created_at) {
      let createdDate: Date;
      if (debt.created_at?.toDate) {
        createdDate = debt.created_at.toDate();
      } else {
        createdDate = new Date(debt.created_at);
      }
      createdDate.setHours(0, 0, 0, 0);
      console.log('Created date:', createdDate, 'Timestamp:', createdDate.getTime());
    }
    
    // Debug due date
    if (debt.dueDate) {
      let dueDate: Date;
      if (debt.dueDate?.toDate) {
        dueDate = debt.dueDate.toDate();
      } else {
        dueDate = new Date(debt.dueDate);
      }
      dueDate.setHours(0, 0, 0, 0);
      console.log('Due date:', dueDate, 'Timestamp:', dueDate.getTime());
    }
    
    // Debug payment dates
    if (debt.payments) {
      debt.payments.forEach((payment, paymentIndex) => {
        if (payment.paymentDate) {
          let paymentDate: Date;
          if (payment.paymentDate?.toDate) {
            paymentDate = payment.paymentDate.toDate();
          } else {
            paymentDate = new Date(payment.paymentDate);
          }
          paymentDate.setHours(0, 0, 0, 0);
          console.log(`Payment ${paymentIndex + 1} date:`, paymentDate, 'Timestamp:', paymentDate.getTime());
        }
      });
    }
  });
  
  // Check calendar dates
  console.log('\n=== Calendar Date Checks ===');
  sampleDates.forEach(dateStr => {
    const day = this.calendarDays.find(d => d.date === dateStr);
    const calendarDate = new Date(dateStr);
    calendarDate.setHours(0, 0, 0, 0);
    
    console.log(`Calendar date ${dateStr}:`, calendarDate, 'Timestamp:', calendarDate.getTime());
    if (day) {
      console.log(`  - Has events: ${day.hasDebtEvents}, Event count: ${day.events.length}`);
    }
  });
}

  private async getStoreInfo(storeOwnerId: string): Promise<any> {
    try {
      if (!storeOwnerId) {
        return this.getDefaultStoreInfo();
      }

      // Get store profile
      const storeProfile = await this.storeService.getStoreProfile(storeOwnerId);
      
      // Get store owner info for store name
      const storeOwner = await this.storeService.getStoreOwnerById(storeOwnerId);
      
      const storeName = storeOwner?.store_name || 'Unknown Store';
      const storeColor = this.getStoreColor(storeName);
      const storeInitials = this.getStoreInitials(storeName);

      return {
        storeName: storeName,
        storeProfileImage: storeProfile?.store_image || null,
        storeColor: storeColor,
        storeInitials: storeInitials,
        storeAddress: this.buildStoreAddress(storeOwner),
        storeContact: storeOwner?.phone_number || 'N/A'
      };
    } catch (error) {
      console.error('Error getting store info:', error);
      return this.getDefaultStoreInfo();
    }
  }

  private getDefaultStoreInfo() {
    return {
      storeName: 'Unknown Store',
      storeProfileImage: null,
      storeColor: '#666666',
      storeInitials: '??',
      storeAddress: 'Address not available',
      storeContact: 'N/A'
    };
  }

  private buildStoreAddress(storeOwner: any): string {
    if (!storeOwner) return 'Address not available';
    
    const addressParts = [];
    if (storeOwner.barangay) addressParts.push(storeOwner.barangay);
    if (storeOwner.municipality) addressParts.push(storeOwner.municipality);
    if (storeOwner.province) addressParts.push(storeOwner.province);
    
    return addressParts.join(', ') || 'Address not specified';
  }

  private getStoreColor(storeName: string): string {
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    const colorIndex = storeName.charCodeAt(0) % colors.length;
    return colors[colorIndex];
  }

  private getStoreInitials(storeName: string): string {
    if (!storeName) return '??';
    
    const words = storeName.trim().split(' ');
    if (words.length === 1) {
      return words[0].substring(0, 2).toUpperCase();
    } else {
      const firstInitial = words[0].charAt(0).toUpperCase();
      const lastInitial = words[words.length - 1].charAt(0).toUpperCase();
      return firstInitial + lastInitial;
    }
  }

  private calculateDaysUntilDue(dueDate: any): number {
    if (!dueDate) return 0;
    
    const due = dueDate.toDate ? dueDate.toDate() : new Date(dueDate);
    const today = new Date();
    const diffTime = due.getTime() - today.getTime();
    const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
    
    return diffDays;
  }

  private calculateSummary() {
    // Only consider unpaid or partially paid debts
    const activeDebts = this.debts.filter(debt => 
      debt.payment_status !== 'paid'
    );

    this.totalDebtAmount = activeDebts.reduce((sum, debt) => sum + (debt.remainingBalance || debt.total), 0);
    
    this.dueSoonAmount = activeDebts
      .filter(debt => debt.days_remaining !== undefined && debt.days_remaining <= 15 && debt.days_remaining >= 0)
      .reduce((sum, debt) => sum + (debt.remainingBalance || debt.total), 0);
    
    this.overdueAmount = activeDebts
      .filter(debt => debt.isOverdue)
      .reduce((sum, debt) => sum + (debt.remainingBalance || debt.total), 0);
    
    this.dueSoonCount = activeDebts.filter(debt => 
      debt.days_remaining !== undefined && debt.days_remaining <= 15 && debt.days_remaining >= 0
    ).length;
    
    this.overdueCount = activeDebts.filter(debt => debt.isOverdue).length;
  }

  async loadAlerts() {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser?.id) return;

      this.generateAlertsFromDebts();
      
    } catch (error) {
      console.error('Error loading alerts:', error);
    }
  }

  private generateAlertsFromDebts() {
    this.alerts = [];
    
    // Generate payment reminders
    this.debts.forEach(debt => {
      if (debt.payment_status !== 'paid') {
        // Due soon alerts (15, 10, 5, 1 days before due date)
        if (debt.days_remaining !== undefined && debt.days_remaining <= 15 && debt.days_remaining > 0) {
          this.alerts.push({
            id: `due_soon_${debt.firestoreId}_${debt.days_remaining}`,
            type: 'payment_reminder',
            title: 'Payment Due Soon',
            message: `Payment of ${this.formatCurrency(debt.remainingBalance || debt.total)} for ${debt.storeName} is due in ${debt.days_remaining} day${debt.days_remaining === 1 ? '' : 's'}`,
            date: new Date(),
            read: false,
            debtId: debt.firestoreId,
            priority: debt.days_remaining <= 5 ? 'high' : debt.days_remaining <= 10 ? 'medium' : 'low'
          });
        }
        
        // Overdue alerts
        if (debt.isOverdue) {
          const overdueDays = Math.abs(debt.days_remaining || 0);
          this.alerts.push({
            id: `overdue_${debt.firestoreId}_${overdueDays}`,
            type: 'overdue_alert',
            title: 'Overdue Payment',
            message: `Your payment of ${this.formatCurrency(debt.remainingBalance || debt.total)} for ${debt.storeName} is ${overdueDays} day${overdueDays === 1 ? '' : 's'} overdue`,
            date: new Date(),
            read: false,
            debtId: debt.firestoreId,
            priority: 'high'
          });
        }
      }
      
      // Payment made alerts
      if (debt.payments && debt.payments.length > 0) {
        debt.payments.forEach((payment, index) => {
          this.alerts.push({
            id: `payment_${debt.firestoreId}_${index}`,
            type: 'payment_reminder',
            title: 'Payment Received',
            message: `Payment of ${this.formatCurrency(payment.amount)} received for ${debt.storeName}`,
            date: payment.paymentDate?.toDate ? payment.paymentDate.toDate() : new Date(payment.paymentDate),
            read: true, // Mark past payments as read
            debtId: debt.firestoreId,
            priority: 'low'
          });
        });
      }
    });
    
    // Sort alerts by date (newest first)
    this.alerts.sort((a, b) => {
      const dateA = a.date?.toDate ? a.date.toDate() : new Date(a.date);
      const dateB = b.date?.toDate ? b.date.toDate() : new Date(b.date);
      return dateB.getTime() - dateA.getTime();
    });
    
    this.unreadAlertsCount = this.alerts.filter(alert => !alert.read).length;
  }

  async checkForNewStores() {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser?.region || !currentUser?.province) return;

      // Check for new stores in the same area
      const usersRef = collection(this.firestore, 'all_users');
      const q = query(
        usersRef, 
        where('role', '==', 'StoreOwner'),
        where('region', '==', currentUser.region),
        where('province', '==', currentUser.province)
      );
      
      const querySnapshot = await getDocs(q);
      const storeCount = querySnapshot.size;
      
      // Simple logic: if we found stores, add a new store alert
      if (storeCount > 0) {
        this.alerts.push({
          id: 'new_stores_available',
          type: 'new_store',
          title: 'New Stores Available',
          message: `There are ${storeCount} stores in your area accepting CrediLink payments`,
          date: new Date(),
          read: false,
          priority: 'medium'
        });
        
        this.unreadAlertsCount = this.alerts.filter(alert => !alert.read).length;
      }
    } catch (error) {
      console.error('Error checking for new stores:', error);
    }
  }

  // Calendar Methods - Updated to show all events
  generateCalendar() {
    const year = this.currentDate.getFullYear();
    const month = this.currentDate.getMonth();
    
    this.currentMonth = this.currentDate.toLocaleDateString('en-US', { 
      month: 'long', 
      year: 'numeric' 
    });
    
    const firstDay = new Date(year, month, 1);
    const lastDay = new Date(year, month + 1, 0);
    const startingDayOfWeek = firstDay.getDay();
    const daysInMonth = lastDay.getDate();
    
    this.calendarDays = [];
    
    // Add empty days for the beginning of the month
    for (let i = 0; i < startingDayOfWeek; i++) {
      this.calendarDays.push(this.createEmptyDay());
    }
    
    // Add days of the month
    for (let day = 1; day <= daysInMonth; day++) {
      const dateString = `${year}-${(month + 1).toString().padStart(2, '0')}-${day.toString().padStart(2, '0')}`;
      this.calendarDays.push(this.createCalendarDay(day, dateString));
    }
  }

  private createEmptyDay(): CalendarDay {
    return {
      date: null,
      day: null,
      hasDebtEvents: false,
      debtCount: 0,
      isDueToday: false,
      isDueSoon: false,
      isOverdue: false,
      hasPayments: false,
      hasNewStores: false,
      events: []
    };
  }

private createCalendarDay(day: number, dateString: string): CalendarDay {
  const date = new Date(dateString);
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const events: CalendarEvent[] = [];
  
  // Find debt events for this date with PROPER TIMESTAMP HANDLING
  this.debts.forEach(debt => {
    // Debt creation dates
    if (debt.created_at) {
      try {
        let createdDate: Date;
        if (debt.created_at?.toDate) {
          // Firestore Timestamp object
          createdDate = debt.created_at.toDate();
        } else if (debt.created_at instanceof Date) {
          // Already a Date object
          createdDate = debt.created_at;
        } else {
          // String or other format
          createdDate = new Date(debt.created_at);
        }
        
        createdDate.setHours(0, 0, 0, 0);
        const calendarDate = new Date(dateString);
        calendarDate.setHours(0, 0, 0, 0);
        
        console.log(`Comparing created: ${createdDate.getTime()} vs calendar: ${calendarDate.getTime()}`);
        
        if (createdDate.getTime() === calendarDate.getTime()) {
          events.push({
            type: 'debt_created',
            debt: debt,
            title: `Debt Created - ${debt.storeName}`,
            description: `New debt of ${this.formatCurrency(debt.total)}`,
            color: '#4ECDC4',
            icon: 'document-text'
          });
        }
      } catch (error) {
        console.warn('Invalid created_at date:', debt.created_at, error);
      }
    }
    
    // Due dates
    if (debt.dueDate) {
      try {
        let dueDate: Date;
        if (debt.dueDate?.toDate) {
          // Firestore Timestamp object
          dueDate = debt.dueDate.toDate();
        } else if (debt.dueDate instanceof Date) {
          // Already a Date object
          dueDate = debt.dueDate;
        } else {
          // String or other format
          dueDate = new Date(debt.dueDate);
        }
        
        dueDate.setHours(0, 0, 0, 0);
        const calendarDate = new Date(dateString);
        calendarDate.setHours(0, 0, 0, 0);
        
        console.log(`Comparing due: ${dueDate.getTime()} vs calendar: ${calendarDate.getTime()}`);
        
        if (dueDate.getTime() === calendarDate.getTime()) {
          events.push({
            type: 'due_date',
            debt: debt,
            title: `Payment Due - ${debt.storeName}`,
            description: `Amount due: ${this.formatCurrency(debt.remainingBalance || debt.total)}`,
            color: debt.isOverdue ? '#FF6B6B' : '#FFD93D',
            icon: 'calendar'
          });
        }
      } catch (error) {
        console.warn('Invalid dueDate:', debt.dueDate, error);
      }
    }
    
    // Payment dates
    if (debt.payments) {
      debt.payments.forEach((payment, paymentIndex) => {
        if (payment.paymentDate) {
          try {
            let paymentDate: Date;
            if (payment.paymentDate?.toDate) {
              // Firestore Timestamp object
              paymentDate = payment.paymentDate.toDate();
            } else if (payment.paymentDate instanceof Date) {
              // Already a Date object
              paymentDate = payment.paymentDate;
            } else {
              // String or other format
              paymentDate = new Date(payment.paymentDate);
            }
            
            paymentDate.setHours(0, 0, 0, 0);
            const calendarDate = new Date(dateString);
            calendarDate.setHours(0, 0, 0, 0);
            
            console.log(`Comparing payment ${paymentIndex}: ${paymentDate.getTime()} vs calendar: ${calendarDate.getTime()}`);
            
            if (paymentDate.getTime() === calendarDate.getTime()) {
              events.push({
                type: 'payment_made',
                debt: debt,
                payment: payment,
                title: `Payment Made - ${debt.storeName}`,
                description: `Paid: ${this.formatCurrency(payment.amount)}`,
                color: '#6BCF7F',
                icon: 'cash'
              });
            }
          } catch (error) {
            console.warn('Invalid paymentDate:', payment.paymentDate, error);
          }
        }
      });
    }
  });
  
  const hasDebtEvents = events.length > 0;
  const isDueToday = date.getTime() === today.getTime();
  
  // Check debt status for this day
  const isDueSoon = events.some(event => event.type === 'due_date' && event.debt?.days_remaining !== undefined && event.debt.days_remaining <= 15 && event.debt.days_remaining >= 0);
  const isOverdue = events.some(event => event.type === 'due_date' && event.debt?.isOverdue);
  const hasPayments = events.some(event => event.type === 'payment_made');
  const hasNewStores = events.some(event => event.type === 'new_store');
  
  return {
    date: dateString,
    day,
    hasDebtEvents,
    debtCount: events.length,
    isDueToday,
    isDueSoon,
    isOverdue,
    hasPayments,
    hasNewStores,
    events: events
  };
}

  // Public methods for template access
  getAlertColor(priority: string): string {
    switch (priority) {
      case 'high': return '#FF6B6B';
      case 'medium': return '#FFD93D';
      case 'low': return '#4ECDC4';
      default: return '#666666';
    }
  }

  getAlertIcon(type: string): string {
    switch (type) {
      case 'new_store': return 'storefront';
      case 'payment_reminder': return 'notifications';
      case 'due_date_alert': return 'calendar';
      case 'overdue_alert': return 'warning';
      case 'system': return 'information-circle';
      default: return 'notifications';
    }
  }

// Helper methods for template - FIXED VERSION
hasDebtCreatedEvent(day: CalendarDay): boolean {
  return day.events && day.events.some(event => event.type === 'debt_created');
}

hasPaymentMadeEvent(day: CalendarDay): boolean {
  return day.events && day.events.some(event => event.type === 'payment_made');
}

hasDueDateEvent(day: CalendarDay): boolean {
  return day.events && day.events.some(event => event.type === 'due_date');
}

hasAlertEvent(day: CalendarDay): boolean {
  return day.events && day.events.some(event => event.type === 'new_store' || event.type === 'payment_reminder');
}

  // Alert Management
  toggleAlertsPanel() {
    this.showAlertsPanel = !this.showAlertsPanel;
    if (this.showAlertsPanel) {
      this.markAllAlertsAsRead();
    }
  }

  markAlertAsRead(alert: Alert) {
    alert.read = true;
    this.unreadAlertsCount = this.alerts.filter(a => !a.read).length;
  }

  markAllAlertsAsRead() {
    this.alerts.forEach(alert => alert.read = true);
    this.unreadAlertsCount = 0;
  }

  async handleAlertAction(alert: Alert) {
    this.markAlertAsRead(alert);
    
    switch (alert.type) {
      case 'new_store':
        this.showToast('Navigating to stores...', 'primary');
        break;
      case 'payment_reminder':
      case 'due_date_alert':
      case 'overdue_alert':
        if (alert.debtId) {
          const debt = this.debts.find(d => d.firestoreId === alert.debtId);
          if (debt) {
            this.viewDebtDetails(debt);
          }
        }
        break;
    }
  }

  deleteAlert(alert: Alert) {
    this.alerts = this.alerts.filter(a => a.id !== alert.id);
    this.unreadAlertsCount = this.alerts.filter(a => !a.read).length;
  }

  previousMonth() {
    this.currentDate = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() - 1, 1);
    this.generateCalendar();
  }

  nextMonth() {
    this.currentDate = new Date(this.currentDate.getFullYear(), this.currentDate.getMonth() + 1, 1);
    this.generateCalendar();
  }

  selectDate(day: CalendarDay) {
    if (!day.date || !day.hasDebtEvents) return;
    
    this.selectedDate = day.date;
    this.showDayEvents(day);
  }

// Replace your showDayEvents method in tab5.page.ts with this enhanced version:

// Replace your showDayEvents method in tab5.page.ts with this:

async showDayEvents(day: CalendarDay) {
  if (!day.date || day.events.length === 0) return;
  
  const modal = await this.modalController.create({
    component: DayEventsModalComponent,
    componentProps: {
      day: day,
      formatDate: this.formatDate.bind(this),
      formatCurrency: this.formatCurrency.bind(this)
    },
    cssClass: 'day-events-modal'
  });

  await modal.present();

  const { data } = await modal.onWillDismiss();
  
  // Handle action from modal (if user clicks "View Debt Details")
  if (data?.action === 'viewDebt' && data?.debt) {
    this.viewDebtDetails(data.debt);
  }
}

  private generateEventsSummary(events: CalendarEvent[]): string {
    if (events.length === 0) return 'No events for this day.';
    
    return events.map(event => 
      `• ${event.title}: ${event.description}`
    ).join('\n\n');
  }

  getEventBadgeColor(day: CalendarDay): string {
    if (day.isOverdue) return 'danger';
    if (day.isDueSoon) return 'warning';
    if (day.hasPayments) return 'success';
    if (day.hasNewStores) return 'primary';
    return 'medium';
  }

  getEventBadgeIcon(day: CalendarDay): string {
    if (day.isOverdue) return 'warning';
    if (day.isDueSoon) return 'calendar';
    if (day.hasPayments) return 'cash';
    if (day.hasNewStores) return 'storefront';
    return 'notifications';
  }

  // Filtering Methods
  applyFilter() {
    switch (this.currentFilter) {
      case 'all':
        this.filteredDebts = [...this.debts];
        break;
      case 'due_soon':
        this.filteredDebts = this.debts.filter(debt => 
          debt.days_remaining !== undefined && 
          debt.days_remaining <= 15 && 
          debt.days_remaining >= 0 &&
          debt.payment_status !== 'paid'
        );
        break;
      case 'overdue':
        this.filteredDebts = this.debts.filter(debt => 
          debt.isOverdue && debt.payment_status !== 'paid'
        );
        break;
      case 'paid':
        this.filteredDebts = this.debts.filter(debt => debt.payment_status === 'paid');
        break;
      default:
        this.filteredDebts = [...this.debts];
    }
  }

  filterByStatus(status: string) {
    this.currentFilter = status;
    this.applyFilter();
    this.selectedDate = '';
  }

  // Debt Management
  async viewDebtDetails(debt: DebtProduct) {
    this.selectedDebt = debt;
    this.showDebtModal = true;
  }

  closeDebtModal() {
    this.showDebtModal = false;
    this.selectedDebt = null;
  }

  async markAsPaid() {
    if (!this.selectedDebt) return;
    
    const alert = await this.alertController.create({
      header: 'Mark as Paid',
      message: `Are you sure you want to mark this debt of ${this.formatCurrency(this.selectedDebt.remainingBalance || this.selectedDebt.total)} as paid?`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Mark Paid',
          handler: async () => {
            await this.updateDebtStatus('paid');
          }
        }
      ]
    });
    
    await alert.present();
  }

  private async updateDebtStatus(status: string) {
    if (!this.selectedDebt?.firestoreId) return;
    
    try {
      const debtRef = doc(this.firestore, 'debt_products', this.selectedDebt.firestoreId);
      const updateData: any = {
        payment_status: status,
        status: status === 'paid' ? 'paid' : 'pending',
        updated_at: Timestamp.now()
      };
      
      if (status === 'paid') {
        updateData.remainingBalance = 0;
        
        // Add to payment history if not already there
        const newPayment: PaymentHistory = {
          amount: this.selectedDebt.remainingBalance || this.selectedDebt.total,
          paymentDate: Timestamp.now(),
          paid_by: 'Customer (Self)',
          notes: 'Marked as paid via alerts tab'
        };
        
        const currentPayments = this.selectedDebt.payments || [];
        updateData.payments = [...currentPayments, newPayment];
      }
      
      await updateDoc(debtRef, updateData);
      
      this.showToast('Debt status updated successfully', 'success');
      this.closeDebtModal();
      await this.loadAllData();
      
    } catch (error) {
      console.error('Error updating debt:', error);
      this.showToast('Error updating debt status', 'danger');
    }
  }

  async contactStore() {
    if (!this.selectedDebt) return;
    
    const alert = await this.alertController.create({
      header: 'Contact Store',
      message: `Would you like to contact ${this.selectedDebt.storeName} about your debt?`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Call',
          handler: () => {
            window.open(`tel:${this.selectedDebt?.storeContact}`, '_system');
          }
        },
        {
          text: 'Message',
          handler: () => {
            window.open(`sms:${this.selectedDebt?.storeContact}`, '_system');
          }
        }
      ]
    });
    
    await alert.present();
  }

  // Fallback method
  async loadDebtsFallback() {
    try {
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const querySnapshot = await getDocs(debtProductsRef);
      
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      const debtProducts: DebtProduct[] = [];
      
      for (const doc of querySnapshot.docs) {
        const data = doc.data();
        if (data['customerName'] === customerName) {
          const debt = await this.transformDebtData(doc.id, data);
          debtProducts.push(debt);
        }
      }

      this.debts = debtProducts.sort((a, b) => {
        if (a.isOverdue && !b.isOverdue) return -1;
        if (!a.isOverdue && b.isOverdue) return 1;
        
        const dateA = a.dueDate?.toDate ? a.dueDate.toDate() : new Date(a.dueDate);
        const dateB = b.dueDate?.toDate ? b.dueDate.toDate() : new Date(b.dueDate);
        return dateA.getTime() - dateB.getTime();
      });

      this.calculateSummary();
      this.applyFilter();
      this.generateCalendar();
      
      console.log(`✅ Loaded ${this.debts.length} debt records (fallback)`);
    } catch (error) {
      console.error('Error in debt fallback:', error);
      this.debts = [];
    }
  }

  // Utility Methods
  formatCurrency(amount: number): string {
    return `₱${amount?.toFixed(2) || '0.00'}`;
  }

  formatDate(date: any): string {
    if (!date) return 'N/A';
    
    try {
      const dateObj = date instanceof Date ? date : date.toDate();
      return dateObj.toLocaleDateString('en-US', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  }

  getStatusColor(status: string): string {
    switch (status) {
      case 'due_soon': return 'warning';
      case 'overdue': return 'danger';
      case 'paid': return 'success';
      default: return 'primary';
    }
  }

  getStatusText(status: string): string {
    switch (status) {
      case 'due_soon': return 'Due Soon';
      case 'overdue': return 'Overdue';
      case 'paid': return 'Paid';
      default: return 'Active';
    }
  }

  getDaysRemainingText(days: number | undefined): string {
    if (days === undefined) return 'Unknown';
    if (days === 0) return 'Due today';
    if (days === 1) return '1 day left';
    if (days > 1) return `${days} days left`;
    if (days === -1) return '1 day overdue';
    return `${Math.abs(days)} days overdue`;
  }

  async doRefresh(event: any) {
    await this.loadAllData();
    this.generateCalendar();
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

  // TrackBy for performance
  trackByDebtId(index: number, item: DebtProduct): string {
    return item.firestoreId || item.id || index.toString();
  }

  trackByStoreId(index: number, item: any): string {
    return item.id || index.toString();
  }

  trackByAlertId(index: number, item: Alert): string {
    return item.id || index.toString();
  }
// Enhanced debug method
debugCalendarEvents() {
  console.log('=== CALENDAR DEBUG INFO ===');
  console.log('Total debts:', this.debts.length);
  
  this.debts.forEach((debt, index) => {
    console.log(`Debt ${index + 1}:`, {
      store: debt.storeName,
      created: debt.created_at,
      createdType: typeof debt.created_at,
      due: debt.dueDate,
      dueType: typeof debt.dueDate,
      payments: debt.payments?.length || 0,
      paymentDates: debt.payments?.map(p => ({
        date: p.paymentDate,
        type: typeof p.paymentDate,
        amount: p.amount
      }))
    });

    // Log specific dates for your sample data
    if (debt.customerName === "Sofhia Nicole A. Castillo") {
      console.log('=== SAMPLE DEBT DETAILS ===');
      console.log('Created date:', debt.created_at);
      console.log('Due date:', debt.dueDate);
      console.log('Payment dates:', debt.payments?.map(p => p.paymentDate));
    }
  });

  console.log('Current month:', this.currentMonth);
  console.log('Calendar days with events:');
  
  let foundEvents = false;
  this.calendarDays.forEach(day => {
    if (day.hasDebtEvents) {
      foundEvents = true;
      console.log(`Day ${day.day}:`, {
        events: day.events.length,
        eventTypes: day.events.map(e => e.type)
      });
    }
  });

  if (!foundEvents) {
    console.log('No calendar days with events found!');
    console.log('Checking specific dates from sample data...');
    
    // Check the specific dates from your sample data
    const sampleDates = [
      '2025-11-27', // created_at
      '2025-12-12', // dueDate  
      '2025-11-28'  // paymentDate
    ];
    
    sampleDates.forEach(dateStr => {
      const day = this.calendarDays.find(d => d.date === dateStr);
      if (day) {
        console.log(`Date ${dateStr}:`, {
          hasEvents: day.hasDebtEvents,
          events: day.events.length
        });
      }
    });
  }
}
forceCalendarRefresh() {
  this.generateCalendar();
  this.showToast('Calendar refreshed', 'success');
}
}