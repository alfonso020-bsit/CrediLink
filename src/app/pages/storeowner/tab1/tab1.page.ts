import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ToastController, LoadingController, ModalController } from '@ionic/angular';
import { AuthService, User } from '../../../services/auth.service';
import { StoreService, StoreProfile } from '../../../services/store.service';
import { Firestore, collection, query, where, getDocs, Timestamp, limit} from '@angular/fire/firestore';
import { DebtViewComponent } from './debt-view.component';
import { CalendarViewComponent } from './calendar-view.component';

interface DashboardMetrics {
  todayRevenue: number;
  todayTransactions: number;
  pendingDebts: number;
  totalDebtAmount: number;
  overdueDebts: number;
  activeEmployees: number;
  totalEmployees: number;
  monthlyRevenue: number;
  monthlyTransactions: number;
}

interface Transaction {
  id: string;
  type: 'cash' | 'debt';
  customerName: string;
  employeeName: string;
  total: number;
  date: Date;
  status?: string;
}

interface EmployeePerformance {
  name: string;
  todaySales: number;
  transactionCount: number;
  initials: string;
  avatarColor: string;
}

interface Employee {
  id: string;
  full_name?: string;
  employeeName?: string;
  name?: string;
  store_owner_id?: string;
  role?: string;
}

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
  selector: 'app-storeowner-tab1',
  templateUrl: './tab1.page.html',
  styleUrls: ['./tab1.page.scss'],
  standalone: false,
})
export class Tab1Page implements OnInit {
  currentUser: User | null = null;
  storeProfile: StoreProfile | null = null;
  storeAvatar: string = '';
  storeAvatarLarge: string = '';
  showSettings: boolean = false;  showFilter: boolean = false; // Add this for filter visibility
  
  // Auto-refresh properties
  private refreshInterval: any;
  private readonly REFRESH_INTERVAL = 5000; // 5 seconds  showFilter: boolean = false; // Add this for filter visibility
  
  // Dashboard Data
  dashboardMetrics: DashboardMetrics = {
    todayRevenue: 0,
    todayTransactions: 0,
    pendingDebts: 0,
    totalDebtAmount: 0,
    overdueDebts: 0,
    activeEmployees: 0,
    totalEmployees: 0,
    monthlyRevenue: 0,
    monthlyTransactions: 0
  };

  recentTransactions: Transaction[] = [];
  topEmployees: EmployeePerformance[] = [];
  calendarEvents: CalendarEvent[] = [];
  isLoadingDashboard: boolean = false;

  // Filter Properties
  selectedDateRange: string = 'today';
  customDate: string = new Date().toISOString();
  transactionFilter: string = 'all';
  startDate: Date = new Date();
  endDate: Date = new Date();

  // Store data for form
  storeData: any = {
    store_description: '',
    store_address: '',
    business_permit_number: '',
    operating_hours: {
      open: '08:00',
      close: '17:00',
      days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    },
    social_media: {
      facebook: '',
      instagram: '',
      website: ''
    }
  };
  
  selectedFile: File | null = null;
  imagePreview: string | null = null;

  constructor(
    private authService: AuthService,
    public storeService: StoreService,
    private firestore: Firestore,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private modalController: ModalController,
    private router: Router
  ) { }

  async ngOnInit() {
    await this.checkAuthentication();
    await this.loadUserData();
    await this.loadStoreProfile();
    this.initializeDateRange();
    await this.loadDashboardData();
    this.startAutoRefresh();
  }
  async ionViewWillEnter() {
    // Check authentication when view enters
    await this.checkAuthentication();
    await this.loadDashboardData();
  }

  ngOnDestroy() {
    // Clean up interval when component is destroyed
    this.stopAutoRefresh();
  }

  initializeDateRange() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    switch (this.selectedDateRange) {
      case 'today':
        this.startDate = new Date(today);
        this.endDate = new Date(today);
        this.endDate.setHours(23, 59, 59, 999);
        break;
      case 'yesterday':
        const yesterday = new Date(today);
        yesterday.setDate(yesterday.getDate() - 1);
        this.startDate = yesterday;
        this.endDate = yesterday;
        this.endDate.setHours(23, 59, 59, 999);
        break;
      case 'thisWeek':
        const startOfWeek = new Date(today);
        startOfWeek.setDate(today.getDate() - today.getDay());
        this.startDate = startOfWeek;
        this.endDate = new Date(today);
        this.endDate.setHours(23, 59, 59, 999);
        break;
      case 'thisMonth':
        const startOfMonth = new Date(today.getFullYear(), today.getMonth(), 1);
        this.startDate = startOfMonth;
        this.endDate = new Date(today);
        this.endDate.setHours(23, 59, 59, 999);
        break;
      case 'lastMonth':
        const firstDayLastMonth = new Date(today.getFullYear(), today.getMonth() - 1, 1);
        const lastDayLastMonth = new Date(today.getFullYear(), today.getMonth(), 0);
        this.startDate = firstDayLastMonth;
        this.endDate = lastDayLastMonth;
        this.endDate.setHours(23, 59, 59, 999);
        break;
      case 'custom':
        const custom = new Date(this.customDate);
        this.startDate = new Date(custom);
        this.endDate = new Date(custom);
        this.endDate.setHours(23, 59, 59, 999);
        break;
    }
  }

// Authentication check method - FIXED
private async checkAuthentication() {
  this.currentUser = this.authService.getCurrentUser();
  
  if (!this.currentUser) {
    console.log('❌ No user found, redirecting to login');
    this.router.navigate(['/home']);
    return;
  }

  // Use 'StoreOwner' (without space) to match your actual data
  if (this.currentUser.role !== 'StoreOwner') {
    console.log('❌ User is not a store owner, redirecting to login');
    console.log('❌ User role:', this.currentUser.role);
    this.showToast('Access denied. Store owner role required.', 'danger');
    this.authService.logout();
    this.router.navigate(['/home']);
    return;
  }

  console.log('✅ User authenticated:', this.currentUser.full_name);
}

// Auto-refresh methods
private startAutoRefresh() {
  this.refreshInterval = setInterval(() => {
    if (!this.showSettings && !this.showFilter) {
      // Use silent refresh (no loading indicators)
      this.loadDashboardData(false);
      console.log('🔄 Auto-refreshing dashboard data silently');
    }
  }, this.REFRESH_INTERVAL);
}

  private stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval);
    }
  }

  // Manual refresh method
// Manual refresh method
async refreshData() {
  this.stopAutoRefresh(); // Stop auto-refresh during manual refresh
  
  const loading = await this.loadingController.create({
    message: 'Refreshing data...',
    duration: 1000
  });
  
  await loading.present();
  
  try {
    // Manual refresh should show loading
    await this.loadDashboardData(true);
    await this.showToast('Data refreshed successfully!', 'success');
  } catch (error) {
    console.error('Error refreshing data:', error);
    await this.showToast('Error refreshing data', 'danger');
  } finally {
    await loading.dismiss();
    this.startAutoRefresh(); // Restart auto-refresh
  }
}

  // Toggle filter visibility
  toggleFilter() {
    this.showFilter = !this.showFilter;
    if (this.showFilter) {
      this.showSettings = false; // Close settings if filter opens
    }
  }

  async loadUserData() {
    this.currentUser = this.authService.getCurrentUser();
    
    const storeName = this.currentUser?.store_name || 'Store';
    const svgAvatar = this.storeService.generateStoreAvatar(storeName);
    this.storeAvatar = this.storeService.svgToBase64(svgAvatar);
    this.storeAvatarLarge = this.storeService.svgToBase64(svgAvatar);
  }

  async loadStoreProfile() {
    this.storeProfile = await this.storeService.getStoreProfile();
    
    if (this.storeProfile) {
      this.storeData = { 
        store_description: this.storeProfile.store_description || '',
        store_address: this.storeProfile.store_address || '',
        business_permit_number: this.storeProfile.business_permit_number || '',
        operating_hours: this.storeProfile.operating_hours || {
          open: '08:00',
          close: '17:00',
          days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
        },
        social_media: this.storeProfile.social_media || {
          facebook: '',
          instagram: '',
          website: ''
        }
      };
    }
  }

async loadDashboardData(showLoading: boolean = true) {
  if (showLoading) {
    this.isLoadingDashboard = true;
  }
  
  try {
    await Promise.all([
      this.loadTodayMetrics(),
      this.loadRecentTransactions(),
      this.loadEmployeePerformance(),
      this.loadMonthlyMetrics(),
      this.loadDebtCalendar()
    ]);
    
    console.log('✅ Store dashboard data loaded successfully');
  } catch (error) {
    console.error('❌ Error loading dashboard data:', error);
    if (showLoading) {
      this.showToast('Error loading dashboard data', 'danger');
    }
  } finally {
    if (showLoading) {
      this.isLoadingDashboard = false;
    }
  }
}

  async loadTodayMetrics() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.id;
      
      if (!storeOwnerId) return;

      // Use filtered date range
      const startDate = this.startDate;
      const endDate = this.endDate;

      // Load cash transactions for the date range
      const cashProductsRef = collection(this.firestore, 'cash_products');
      const cashQuery = query(
        cashProductsRef,
        where('store_owner_id', '==', storeOwnerId),
        where('created_at', '>=', Timestamp.fromDate(startDate)),
        where('created_at', '<=', Timestamp.fromDate(endDate))
      );

      // Load all debt transactions for the store
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtQuery = query(
        debtProductsRef,
        where('store_owner_id', '==', storeOwnerId)
      );

      const [cashSnapshot, debtSnapshot] = await Promise.all([
        getDocs(cashQuery),
        getDocs(debtQuery)
      ]);

      const periodCashTransactions = cashSnapshot.docs.map(doc => doc.data());
      const debtTransactions = debtSnapshot.docs.map(doc => doc.data());

      // Calculate metrics
      const periodRevenue = periodCashTransactions.reduce((sum, tx) => sum + (tx['total'] || 0), 0);
      const pendingDebts = debtTransactions.filter(tx => 
        tx['payment_status'] === 'unpaid' || tx['payment_status'] === 'partially_paid'
      );
      const overdueDebts = pendingDebts.filter(tx => {
        const dueDate = tx['dueDate']?.toDate();
        return dueDate && dueDate < new Date();
      });

      // Load employee count
      const employeesCount = await this.getEmployeesCount(storeOwnerId);

      this.dashboardMetrics.todayRevenue = periodRevenue;
      this.dashboardMetrics.todayTransactions = periodCashTransactions.length;
      this.dashboardMetrics.pendingDebts = pendingDebts.length;
      this.dashboardMetrics.totalDebtAmount = pendingDebts.reduce((sum, tx) => sum + (tx['remainingBalance'] || 0), 0);
      this.dashboardMetrics.overdueDebts = overdueDebts.length;
      this.dashboardMetrics.activeEmployees = employeesCount.active;
      this.dashboardMetrics.totalEmployees = employeesCount.total;

    } catch (error) {
      console.error('Error loading today metrics:', error);
    }
  }

  async loadMonthlyMetrics() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.id;
      
      if (!storeOwnerId) return;

      const startOfMonth = new Date();
      startOfMonth.setDate(1);
      startOfMonth.setHours(0, 0, 0, 0);
      
      const endOfMonth = new Date(startOfMonth);
      endOfMonth.setMonth(endOfMonth.getMonth() + 1);

      // Load monthly cash transactions
      const cashProductsRef = collection(this.firestore, 'cash_products');
      const cashQuery = query(
        cashProductsRef,
        where('store_owner_id', '==', storeOwnerId),
        where('created_at', '>=', Timestamp.fromDate(startOfMonth)),
        where('created_at', '<', Timestamp.fromDate(endOfMonth))
      );

      const cashSnapshot = await getDocs(cashQuery);
      const monthlyTransactions = cashSnapshot.docs.map(doc => doc.data());

      const monthlyRevenue = monthlyTransactions.reduce((sum, tx) => sum + (tx['total'] || 0), 0);

      this.dashboardMetrics.monthlyRevenue = monthlyRevenue;
      this.dashboardMetrics.monthlyTransactions = monthlyTransactions.length;

    } catch (error) {
      console.error('Error loading monthly metrics:', error);
    }
  }

async loadRecentTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) return;

    // Load recent transactions for the date range
    const cashProductsRef = collection(this.firestore, 'cash_products');
    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    // For now, remove the date range filter to avoid index issues
    // You can add it back after creating the index
    const cashQuery = query(
      cashProductsRef,
      where('store_owner_id', '==', storeOwnerId),
      // where('created_at', '>=', Timestamp.fromDate(this.startDate)),
      // where('created_at', '<=', Timestamp.fromDate(this.endDate)),
      limit(20)
    );

    const debtQuery = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId),
      // where('created_at', '>=', Timestamp.fromDate(this.startDate)),
      // where('created_at', '<=', Timestamp.fromDate(this.endDate)),
      limit(20)
    );

    const [cashSnapshot, debtSnapshot] = await Promise.all([
      getDocs(cashQuery),
      getDocs(debtQuery)
    ]);

    const cashTransactions: Transaction[] = cashSnapshot.docs.map(doc => ({
      id: doc.id,
      type: 'cash' as const,
      customerName: doc.data()['customerName'] || 'Walk-in Customer',
      employeeName: doc.data()['employeeName'] || 'Store Owner',
      total: doc.data()['total'] || 0,
      date: doc.data()['created_at']?.toDate()
    }));

    const debtTransactions: Transaction[] = debtSnapshot.docs.map(doc => ({
      id: doc.id,
      type: 'debt' as const,
      customerName: doc.data()['customerName'] || 'Unknown Customer',
      employeeName: doc.data()['employeeName'] || 'Store Owner',
      total: doc.data()['total'] || 0,
      date: doc.data()['created_at']?.toDate(),
      status: doc.data()['payment_status']
    }));

    const allTransactions: Transaction[] = [
      ...cashTransactions,
      ...debtTransactions
    ];

    // Filter by date range client-side
    const filteredTransactions = allTransactions.filter(tx => {
      return tx.date >= this.startDate && tx.date <= this.endDate;
    });

    // Sort by date client-side (descending - newest first)
    this.recentTransactions = filteredTransactions
      .sort((a, b) => b.date.getTime() - a.date.getTime())
      .slice(0, 10);

  } catch (error) {
    console.error('Error loading recent transactions:', error);
    // Fallback: Load without any filtering
    await this.loadRecentTransactionsFallback();
  }
}

// Add this fallback method
async loadRecentTransactionsFallback() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) return;

    const cashProductsRef = collection(this.firestore, 'cash_products');
    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    const cashQuery = query(
      cashProductsRef,
      where('store_owner_id', '==', storeOwnerId),
      limit(10)
    );

    const debtQuery = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId),
      limit(10)
    );

    const [cashSnapshot, debtSnapshot] = await Promise.all([
      getDocs(cashQuery),
      getDocs(debtQuery)
    ]);

    const cashTransactions: Transaction[] = cashSnapshot.docs.map(doc => ({
      id: doc.id,
      type: 'cash' as const,
      customerName: doc.data()['customerName'] || 'Walk-in Customer',
      employeeName: doc.data()['employeeName'] || 'Store Owner',
      total: doc.data()['total'] || 0,
      date: doc.data()['created_at']?.toDate()
    }));

    const debtTransactions: Transaction[] = debtSnapshot.docs.map(doc => ({
      id: doc.id,
      type: 'debt' as const,
      customerName: doc.data()['customerName'] || 'Unknown Customer',
      employeeName: doc.data()['employeeName'] || 'Store Owner',
      total: doc.data()['total'] || 0,
      date: doc.data()['created_at']?.toDate(),
      status: doc.data()['payment_status']
    }));

    const allTransactions: Transaction[] = [
      ...cashTransactions,
      ...debtTransactions
    ];

    this.recentTransactions = allTransactions
      .sort((a, b) => b.date.getTime() - a.date.getTime())
      .slice(0, 10);

  } catch (error) {
    console.error('Error in fallback transaction loading:', error);
    this.recentTransactions = [];
  }
}

async loadEmployeePerformance() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) return;

    // Load employees first
    const employeesSnapshot = await getDocs(query(
      collection(this.firestore, 'all_users'),
      where('store_owner_id', '==', storeOwnerId),
      where('role', '==', 'Employee')
    ));

    const employees: Employee[] = employeesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    // Create employee name mapping
    const employeeNameMap = new Map();
    employees.forEach(emp => {
      const employeeName = emp.full_name || emp.employeeName || emp.name || 'Unknown Employee';
      employeeNameMap.set(emp.id, employeeName);
    });

    // Load transactions without date filter initially
    const cashSnapshot = await getDocs(query(
      collection(this.firestore, 'cash_products'),
      where('store_owner_id', '==', storeOwnerId)
      // Remove date filters to avoid index issues
      // where('created_at', '>=', Timestamp.fromDate(this.startDate)),
      // where('created_at', '<=', Timestamp.fromDate(this.endDate))
    ));

    const periodTransactions = cashSnapshot.docs.map(doc => doc.data());

    // Filter by date range client-side
    const filteredTransactions = periodTransactions.filter(tx => {
      const txDate = tx['created_at']?.toDate();
      return txDate && txDate >= this.startDate && txDate <= this.endDate;
    });

    // Group transactions by employee
    const employeePerformanceMap = new Map();
    
    filteredTransactions.forEach(tx => {
      const employeeId = tx['employee_id'];
      const employeeName = tx['employeeName'] || employeeNameMap.get(employeeId) || 'Unknown Employee';
      
      if (!employeePerformanceMap.has(employeeId)) {
        employeePerformanceMap.set(employeeId, {
          name: employeeName,
          todaySales: 0,
          transactionCount: 0,
          initials: this.getInitials(employeeName),
          avatarColor: this.getAvatarColor(employeeName)
        });
      }
      
      const employeeData = employeePerformanceMap.get(employeeId);
      employeeData.todaySales += tx['total'] || 0;
      employeeData.transactionCount += 1;
    });

    this.topEmployees = Array.from(employeePerformanceMap.values())
      .sort((a, b) => b.todaySales - a.todaySales)
      .slice(0, 3);

  } catch (error) {
    console.error('Error loading employee performance:', error);
    this.topEmployees = [];
  }
}

  async loadDebtCalendar() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const storeOwnerId = currentUser?.id;
      
      if (!storeOwnerId) return;

      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtQuery = query(
        debtProductsRef,
        where('store_owner_id', '==', storeOwnerId)
      );

      const debtSnapshot = await getDocs(debtQuery);
      const events: CalendarEvent[] = [];

      debtSnapshot.docs.forEach(doc => {
        const data = doc.data();
        const transactionDate = data['created_at']?.toDate();
        const dueDate = data['dueDate']?.toDate();
        const today = new Date();

        // Add transaction date event
        if (transactionDate) {
          events.push({
            date: transactionDate,
            type: 'transaction',
            transactionId: doc.id,
            customerName: data['customerName'] || 'Unknown Customer',
            amount: data['total'] || 0,
            status: data['payment_status'] || 'unpaid',
            debtData: data
          });
        }

        // Add due date event
        if (dueDate) {
          events.push({
            date: dueDate,
            type: 'due_date',
            transactionId: doc.id,
            customerName: data['customerName'] || 'Unknown Customer',
            amount: data['remainingBalance'] || 0,
            status: data['payment_status'] || 'unpaid',
            isOverdue: dueDate < today,
            debtData: data
          });
        }
      });

      this.calendarEvents = events.sort((a, b) => a.date.getTime() - b.date.getTime());

    } catch (error) {
      console.error('Error loading debt calendar:', error);
    }
  }

  // Filter Methods
  onDateRangeChange() {
    this.initializeDateRange();
    this.loadDashboardData();
  }

  onCustomDateChange() {
    if (this.selectedDateRange === 'custom') {
      this.initializeDateRange();
      this.loadDashboardData();
    }
  }

  onTransactionFilterChange(event: any) {
    this.transactionFilter = event.detail.value;
  }

  getFilteredTransactions(): Transaction[] {
    if (this.transactionFilter === 'all') {
      return this.recentTransactions;
    }
    return this.recentTransactions.filter(tx => tx.type === this.transactionFilter);
  }

  getDateRangeLabel(): string {
    switch (this.selectedDateRange) {
      case 'today': return 'Today\'s';
      case 'yesterday': return 'Yesterday\'s';
      case 'thisWeek': return 'This Week\'s';
      case 'thisMonth': return 'This Month\'s';
      case 'lastMonth': return 'Last Month\'s';
      case 'custom': return 'Selected Date\'s';
      default: return 'Today\'s';
    }
  }

  getUpcomingDebtEvents(): CalendarEvent[] {
    const today = new Date();
    return this.calendarEvents
      .filter(event => event.date >= today)
      .slice(0, 3);
  }

// Modal Methods - Keep these as they are
async openDebtCalendar() {
  const modal = await this.modalController.create({
    component: CalendarViewComponent,
    componentProps: {
      calendarEvents: this.calendarEvents,
      storeName: this.currentUser?.store_name,
    },
    cssClass: 'debt-calendar-modal'
  });
  
  await modal.present();
}

async openDebtDetails(event: CalendarEvent) {
  const modal = await this.modalController.create({
    component: DebtViewComponent,
    componentProps: {
      debtEvent: event,
      storeName: this.currentUser?.store_name
    },
    cssClass: 'debt-details-modal'
  });
  
  await modal.present();
}

// Add this method for date details (like employee has)
async openDateDetails(date: Date) {
  const dayEvents = this.calendarEvents.filter(event => 
    this.isSameDay(event.date, date)
  );

  const modal = await this.modalController.create({
    component: CalendarViewComponent,
    componentProps: {
      calendarEvents: dayEvents,
      selectedDate: date,
      storeName: this.currentUser?.store_name
    },
    cssClass: 'date-details-modal'
  });
  
  await modal.present();
}

// Add this helper method
private isSameDay(date1: Date, date2: Date): boolean {
  return date1.getDate() === date2.getDate() &&
         date1.getMonth() === date2.getMonth() &&
         date1.getFullYear() === date2.getFullYear();
}

  async generateReport() {
    const loading = await this.loadingController.create({
      message: 'Generating report...',
    });
    await loading.present();

    // Simulate report generation
    setTimeout(async () => {
      await loading.dismiss();
      this.showToast('Report generated successfully!', 'success');
    }, 2000);
  }

  // ... rest of your existing methods (getEmployeesCount, getInitials, getAvatarColor, etc.)
  private async getEmployeesCount(storeOwnerId: string): Promise<{active: number, total: number}> {
    try {
      const usersRef = collection(this.firestore, 'all_users');
      const employeesQuery = query(
        usersRef,
        where('store_owner_id', '==', storeOwnerId),
        where('role', '==', 'Employee')
      );

      const snapshot = await getDocs(employeesQuery);
      const totalEmployees = snapshot.docs.length;
      
      return {
        active: totalEmployees,
        total: totalEmployees
      };
    } catch (error) {
      console.error('Error loading employees count:', error);
      return { active: 0, total: 0 };
    }
  }

private getInitials(fullName: string): string {
  if (!fullName) return '?';
  
  const names = fullName.trim().split(' ');
  if (names.length === 1) {
    return names[0].substring(0, 2).toUpperCase();
  } else {
    const firstInitial = names[0].charAt(0).toUpperCase();
    const lastInitial = names[names.length - 1].charAt(0).toUpperCase();
    return firstInitial + lastInitial;
  }
}

private getAvatarColor(fullName: string): string {
  if (!fullName) return '#666666';
  
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
    '#F8C471', '#82E0AA', '#F1948A', '#85C1E9', '#D7BDE2'
  ];
  
  const colorIndex = fullName.charCodeAt(0) % colors.length;
  return colors[colorIndex];
}

 // Update your existing toggleSettings method
  toggleSettings() {
    this.showSettings = !this.showSettings;
    if (this.showSettings) {
      this.showFilter = false; // Close filter if settings opens
      this.stopAutoRefresh(); // Stop auto-refresh when settings are open
    } else {
      this.startAutoRefresh(); // Restart auto-refresh when settings close
      this.imagePreview = null;
      this.selectedFile = null;
    }
  }

  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      if (file.size > 2 * 1024 * 1024) {
        this.showToast('Image size should be less than 2MB', 'warning');
        return;
      }

      this.selectedFile = file;
      
      const reader = new FileReader();
      reader.onload = (e: any) => {
        this.imagePreview = e.target.result;
      };
      reader.readAsDataURL(file);
    }
  }

  async saveStoreProfile() {
    const loading = await this.loadingController.create({
      message: 'Saving store profile...',
    });
    await loading.present();

    try {
      if (this.imagePreview && this.imagePreview.startsWith('data:image')) {
        this.storeData.store_image = this.imagePreview;
      }

      await this.storeService.saveStoreProfile(this.storeData);
      
      await loading.dismiss();
      await this.showToast('Store profile saved successfully!', 'success');
      
      await this.loadStoreProfile();
      this.showSettings = false;
      this.imagePreview = null;
      this.selectedFile = null;
      
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast(error.message || 'Error saving store profile', 'danger');
    }
  }

  async deleteStoreImage() {
    try {
      await this.storeService.deleteStoreImage();
      this.imagePreview = null;
      this.storeData.store_image = '';
      await this.showToast('Store image removed successfully!', 'success');
      
      await this.loadStoreProfile();
    } catch (error: any) {
      await this.showToast(error.message || 'Error removing store image', 'danger');
    }
  }

 // Update logout method to handle auto-refresh cleanup
  async logout() {
    this.stopAutoRefresh(); // Clean up interval
    
    const loading = await this.loadingController.create({
      message: 'Logging out...',
      duration: 1500
    });
    
    await loading.present();
    
    setTimeout(async () => {
      this.authService.logout();
      await loading.dismiss();
      this.router.navigate(['/home']);
      this.showToast('Logged out successfully', 'success');
    }, 1500);
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
}