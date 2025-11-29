import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ToastController, LoadingController, ModalController } from '@ionic/angular';
import { AuthService, User } from '../../../services/auth.service';
import { CustomerService, CustomerProfile } from '../../../services/customer.service';
import { Firestore, collection, query, where, getDocs, Timestamp, limit, orderBy } from '@angular/fire/firestore';
import { StoreService } from '../../../services/store.service';
interface DashboardMetrics {
  totalSpending: number;
  totalTransactions: number;
  pendingDebts: number;
  totalDebtAmount: number;
  overdueDebts: number;
  storesVisited: number;
  favoriteStore: string;
  monthlySpending: number;
  monthlyTransactions: number;
}

interface Transaction {
  id: string;
  type: 'cash' | 'debt';
  storeName: string;
  storeId: string;
  total: number;
  date: Date;
  items?: number;
  storeColor: string;
  storeInitials: string;
  storeProfileImage?: string;
}

interface StoreVisit {
  storeId: string;
  storeName: string;
  visitCount: number;
  totalSpending: number;
  lastVisit: Date;
  color: string;
  initials: string;
  rating: number;
  storeProfileImage?: string;
}

interface DebtPayment {
  id: string;
  storeName: string;
  storeId: string;
  amount: number;
  dueDate: Date;
  isOverdue: boolean;
  originalAmount: number;
  paidAmount: number;
  storeColor: string;
  storeInitials: string;
  storeProfileImage?: string; // Add this
}

@Component({
  selector: 'app-customer-tab1',
  templateUrl: './tab1.page.html',
  styleUrls: ['./tab1.page.scss'],
  standalone: false,
})
export class Tab1Page implements OnInit {
  currentUser: User | null = null;
  customerProfile: CustomerProfile | null = null;
  
  // Avatar properties like store owner
  customerAvatar: string = '';
  customerAvatarLarge: string = '';
  
  showSettings: boolean = false;
  
  // Dashboard Data
  dashboardMetrics: DashboardMetrics = {
    totalSpending: 0,
    totalTransactions: 0,
    pendingDebts: 0,
    totalDebtAmount: 0,
    overdueDebts: 0,
    storesVisited: 0,
    favoriteStore: '',
    monthlySpending: 0,
    monthlyTransactions: 0
  };

  recentTransactions: Transaction[] = [];
  favoriteStores: StoreVisit[] = [];
  debtPayments: DebtPayment[] = [];
  isLoadingDashboard: boolean = false;

  // Customer data for form
  customerData: any = {
    date_of_birth: '',
    gender: '',
    preferred_store: '',
    social_media: {
      facebook: '',
      instagram: ''
    },
    preferred_contact_method: 'sms',
    receive_promotions: true,
    receive_debt_reminders: true
  };
  
  selectedFile: File | null = null;
  imagePreview: string | null = null;

  constructor(
    private authService: AuthService,
    public customerService: CustomerService,
    private storeService: StoreService,
    private firestore: Firestore,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private modalController: ModalController,
    private router: Router
  ) { }

  async ngOnInit() {
    await this.checkAuthentication();
    await this.loadUserData();
    await this.loadCustomerProfile();
    await this.loadDashboardData();
  }

  async ionViewWillEnter() {
    await this.checkAuthentication();
    await this.loadDashboardData();
  }

  // Authentication check method - like store owner
  private async checkAuthentication() {
    this.currentUser = this.authService.getCurrentUser();
    
    if (!this.currentUser) {
      console.log('❌ No user found, redirecting to login');
      this.router.navigate(['/home']);
      return;
    }

    if (this.currentUser.role !== 'Customer') {
      console.log('❌ User is not a customer, redirecting to login');
      console.log('❌ User role:', this.currentUser.role);
      this.showToast('Access denied. Customer role required.', 'danger');
      this.authService.logout();
      this.router.navigate(['/home']);
      return;
    }

    console.log('✅ Customer authenticated:', this.currentUser.full_name);
  }

  // Update your loadUserData method:
async loadUserData() {
  this.currentUser = this.authService.getCurrentUser();
  
  const customerName = this.currentUser?.full_name || 'Customer';
  
  // Generate avatars directly in the component
  const svgAvatar = this.generateCustomerAvatar(customerName);
  const svgAvatarLarge = this.generateCustomerAvatarLarge(customerName);
  
  this.customerAvatar = this.svgToBase64(svgAvatar);
  this.customerAvatarLarge = this.svgToBase64(svgAvatarLarge);
}

// Add this helper method to convert SVG to base64
svgToBase64(svgString: string): string {
  return 'data:image/svg+xml;base64,' + btoa(svgString);
}

  async loadCustomerProfile() {
    try {
      console.log('🔄 Loading customer profile for:', this.currentUser?.full_name);
      
      if (!this.currentUser) {
        console.log('❌ No current user for customer profile');
        return;
      }

      this.customerProfile = await this.customerService.getCustomerProfile();
      
      console.log('📋 Customer profile loaded:', this.customerProfile ? 'Yes' : 'No');

      if (this.customerProfile) {
        console.log('👤 Profile belongs to customer ID:', this.customerProfile.customer_id);
      }

      // Initialize customer form data
      this.customerData = {
        date_of_birth: this.customerProfile?.date_of_birth || '',
        gender: this.customerProfile?.gender || '',
        preferred_store: this.customerProfile?.preferred_store || '',
        social_media: this.customerProfile?.social_media || {
          facebook: '',
          instagram: ''
        },
        preferred_contact_method: this.customerProfile?.preferred_contact_method || 'sms',
        receive_promotions: this.customerProfile?.receive_promotions !== false,
        receive_debt_reminders: this.customerProfile?.receive_debt_reminders !== false
      };

      console.log('📝 Customer form data initialized:', this.customerData);

    } catch (error) {
      console.error('❌ Error loading customer profile:', error);
    }
  }

  // Manual refresh method - like store owner
  async refreshData() {
    const loading = await this.loadingController.create({
      message: 'Refreshing data...',
      duration: 1000
    });
    
    await loading.present();
    
    try {
      await this.loadDashboardData();
      await this.showToast('Data refreshed successfully!', 'success');
    } catch (error) {
      console.error('Error refreshing data:', error);
      await this.showToast('Error refreshing data', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

async loadDashboardData() {
  this.isLoadingDashboard = true;
  
  try {
    console.log('🔄 Starting to load dashboard data...');
    
    await Promise.all([
      this.loadCustomerMetrics().catch(err => console.error('Metrics error:', err)),
      this.loadRecentTransactions().catch(err => console.error('Transactions error:', err)),
      this.loadFavoriteStores().catch(err => console.error('Stores error:', err)),
      this.loadDebtPayments().catch(err => console.error('Debts error:', err))
    ]);
    
    console.log('✅ Customer dashboard data loaded successfully');
  } catch (error) {
    console.error('❌ Error loading dashboard data:', error);
    this.showToast('Error loading dashboard data', 'danger');
  } finally {
    this.isLoadingDashboard = false;
    console.log('🏁 Dashboard loading completed');
  }
}

  // Load customer metrics - similar to store owner but for customer data
  async loadCustomerMetrics() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      if (!customerName) return;

      // Load cash transactions for this customer
      const cashProductsRef = collection(this.firestore, 'cash_products');
      const cashQuery = query(
        cashProductsRef,
        where('customerName', '==', customerName)
      );

      // Load debt transactions for this customer
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtQuery = query(
        debtProductsRef,
        where('customerName', '==', customerName)
      );

      const [cashSnapshot, debtSnapshot] = await Promise.all([
        getDocs(cashQuery),
        getDocs(debtQuery)
      ]);

      const cashTransactions = cashSnapshot.docs.map(doc => doc.data());
      const debtTransactions = debtSnapshot.docs.map(doc => doc.data());

      // Calculate metrics
      const totalSpending = cashTransactions.reduce((sum, tx) => sum + (tx['total'] || 0), 0) +
                           debtTransactions.reduce((sum, tx) => sum + (tx['total'] || 0), 0);
      
      const pendingDebts = debtTransactions.filter(tx => 
        tx['payment_status'] === 'unpaid' || tx['payment_status'] === 'partially_paid'
      );
      
      const overdueDebts = pendingDebts.filter(tx => {
        const dueDate = tx['dueDate']?.toDate();
        return dueDate && dueDate < new Date();
      });

      // Get unique stores visited
      const allTransactions = [...cashTransactions, ...debtTransactions];
      const uniqueStores = new Set(allTransactions.map(tx => tx['store_owner_id']));

      // Calculate monthly spending (current month)
      const startOfMonth = new Date();
      startOfMonth.setDate(1);
      startOfMonth.setHours(0, 0, 0, 0);
      
      const monthlyTransactions = allTransactions.filter(tx => {
        const txDate = tx['created_at']?.toDate();
        return txDate && txDate >= startOfMonth;
      });

      const monthlySpending = monthlyTransactions.reduce((sum, tx) => sum + (tx['total'] || 0), 0);

      // Find favorite store (most visited)
      const storeVisitCount: { [key: string]: number } = {};
      allTransactions.forEach(tx => {
        const storeId = tx['store_owner_id'];
        storeVisitCount[storeId] = (storeVisitCount[storeId] || 0) + 1;
      });

      const favoriteStoreId = Object.keys(storeVisitCount).reduce((a, b) => 
        storeVisitCount[a] > storeVisitCount[b] ? a : b, ''
      );

      // Get store name from all_users
      let favoriteStore = '';
      if (favoriteStoreId) {
        const storeOwner = await this.authService.getStoreOwnerById(favoriteStoreId);
        favoriteStore = storeOwner?.store_name || 'Favorite Store';
      }

      this.dashboardMetrics.totalSpending = totalSpending;
      this.dashboardMetrics.totalTransactions = allTransactions.length;
      this.dashboardMetrics.pendingDebts = pendingDebts.length;
      this.dashboardMetrics.totalDebtAmount = pendingDebts.reduce((sum, tx) => sum + (tx['remainingBalance'] || tx['total'] || 0), 0);
      this.dashboardMetrics.overdueDebts = overdueDebts.length;
      this.dashboardMetrics.storesVisited = uniqueStores.size;
      this.dashboardMetrics.favoriteStore = favoriteStore;
      this.dashboardMetrics.monthlySpending = monthlySpending;
      this.dashboardMetrics.monthlyTransactions = monthlyTransactions.length;

    } catch (error) {
      console.error('Error loading customer metrics:', error);
    }
  }

async loadRecentTransactions() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const customerName = currentUser?.full_name;
    
    if (!customerName) return;

    // Remove orderBy and limit to avoid index issues - we'll sort manually
    const cashProductsRef = collection(this.firestore, 'cash_products');
    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    const [cashSnapshot, debtSnapshot] = await Promise.all([
      getDocs(query(cashProductsRef, where('customerName', '==', customerName))),
      getDocs(query(debtProductsRef, where('customerName', '==', customerName)))
    ]);

    const cashTransactions: Transaction[] = await Promise.all(
      cashSnapshot.docs.map(async doc => {
        const data = doc.data();
        const storeName = await this.getStoreName(data['store_owner_id']);
        const storeProfileImage = await this.getStoreProfileImage(data['store_owner_id']);
        
        return {
          id: doc.id,
          type: 'cash' as const,
          storeName: storeName,
          storeId: data['store_owner_id'],
          total: data['total'] || 0,
          date: data['created_at']?.toDate() || new Date(),
          items: data['items']?.length || 0,
          storeColor: this.getStoreColor(storeName),
          storeInitials: this.getStoreInitials(storeName),
          storeProfileImage: storeProfileImage || undefined
        };
      })
    );

    const debtTransactions: Transaction[] = await Promise.all(
      debtSnapshot.docs.map(async doc => {
        const data = doc.data();
        const storeName = await this.getStoreName(data['store_owner_id']);
        const storeProfileImage = await this.getStoreProfileImage(data['store_owner_id']);
        
        return {
          id: doc.id,
          type: 'debt' as const,
          storeName: storeName,
          storeId: data['store_owner_id'],
          total: data['total'] || 0,
          date: data['created_at']?.toDate() || new Date(),
          items: data['items']?.length || 0,
          storeColor: this.getStoreColor(storeName),
          storeInitials: this.getStoreInitials(storeName),
          storeProfileImage: storeProfileImage || undefined
        };
      })
    );

    // Sort manually in memory and limit to 5
    this.recentTransactions = [...cashTransactions, ...debtTransactions]
      .sort((a, b) => b.date.getTime() - a.date.getTime())
      .slice(0, 5);

  } catch (error) {
    console.error('Error loading recent transactions:', error);
    this.recentTransactions = [];
  }
}
// Add this method to get store profile image
private async getStoreProfileImage(storeOwnerId: string): Promise<string | null> {
  try {
    if (!storeOwnerId) return null;
    
    const storeProfile = await this.storeService.getStoreProfile(storeOwnerId);
    return storeProfile?.store_image || null; // Note: your service uses 'store_image' not 'profile_image'
  } catch (error) {
    console.error('Error getting store profile image:', error);
    return null;
  }
}


async loadFavoriteStores() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const customerName = currentUser?.full_name;
    
    if (!customerName) {
      console.log('❌ No customer name found for favorite stores');
      return;
    }

    console.log('🔄 Loading favorite stores for:', customerName);

    // Load all transactions to analyze store visits
    const cashProductsRef = collection(this.firestore, 'cash_products');
    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    const [cashSnapshot, debtSnapshot] = await Promise.all([
      getDocs(query(cashProductsRef, where('customerName', '==', customerName))),
      getDocs(query(debtProductsRef, where('customerName', '==', customerName)))
    ]);

    const allTransactions = [
      ...cashSnapshot.docs.map(doc => doc.data()),
      ...debtSnapshot.docs.map(doc => doc.data())
    ];

    console.log(`📊 Found ${allTransactions.length} total transactions`);

    // Group by store
    const storeStats: { [key: string]: StoreVisit } = {};

    for (const tx of allTransactions) {
      const storeId = tx['store_owner_id'];
      
      if (!storeId) {
        console.log('⚠️ Transaction missing store_owner_id:', tx);
        continue;
      }

      const storeName = await this.getStoreName(storeId);
      const storeProfileImage = await this.getStoreProfileImage(storeId);
      
      console.log(`🏪 Store ${storeId}: ${storeName}, Has Image: ${!!storeProfileImage}`);

      if (!storeStats[storeId]) {
        storeStats[storeId] = {
          storeId: storeId,
          storeName: storeName,
          visitCount: 0,
          totalSpending: 0,
          lastVisit: new Date(0),
          color: this.getStoreColor(storeName),
          initials: this.getStoreInitials(storeName),
          rating: 4.5,
          storeProfileImage: storeProfileImage || undefined
        };
      }

      storeStats[storeId].visitCount += 1;
      storeStats[storeId].totalSpending += tx['total'] || 0;
      
      const txDate = tx['created_at']?.toDate();
      if (txDate && txDate > storeStats[storeId].lastVisit) {
        storeStats[storeId].lastVisit = txDate;
      }
    }

    this.favoriteStores = Object.values(storeStats)
      .sort((a, b) => b.visitCount - a.visitCount)
      .slice(0, 3);

    console.log(`✅ Loaded ${this.favoriteStores.length} favorite stores:`, this.favoriteStores);

  } catch (error) {
    console.error('❌ Error loading favorite stores:', error);
    this.favoriteStores = [];
  }
}

  async loadDebtPayments() {
    try {
      const currentUser = this.authService.getCurrentUser();
      const customerName = currentUser?.full_name;
      
      if (!customerName) return;

      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtQuery = query(
        debtProductsRef,
        where('customerName', '==', customerName),
        where('payment_status', 'in', ['unpaid', 'partially_paid'])
      );

      const debtSnapshot = await getDocs(debtQuery);
      const payments: DebtPayment[] = await Promise.all(
        debtSnapshot.docs.map(async doc => {
          const data = doc.data();
          const storeName = await this.getStoreName(data['store_owner_id']);
          const dueDate = data['dueDate']?.toDate();
          const today = new Date();
          
          return {
            id: doc.id,
            storeName: storeName,
            storeId: data['store_owner_id'],
            amount: data['remainingBalance'] || data['total'] || 0,
            dueDate: dueDate,
            isOverdue: dueDate ? dueDate < today : false,
            originalAmount: data['total'] || 0,
            paidAmount: (data['total'] || 0) - (data['remainingBalance'] || 0),
            storeColor: this.getStoreColor(storeName),
            storeInitials: this.getStoreInitials(storeName)
          };
        })
      );

      this.debtPayments = payments.sort((a, b) => a.dueDate.getTime() - b.dueDate.getTime());

    } catch (error) {
      console.error('Error loading debt payments:', error);
      this.debtPayments = [];
    }
  }

// Update your existing getStoreName method to be more efficient
private async getStoreName(storeOwnerId: string): Promise<string> {
  try {
    if (!storeOwnerId) return 'Unknown Store';
    
    // Try to get from store profile first
    const storeProfile = await this.storeService.getStoreProfile(storeOwnerId);
    if (storeProfile) {
      // Get store name from store owner info
      const storeOwner = await this.storeService.getStoreOwnerById(storeOwnerId);
      return storeOwner?.store_name || 'Unknown Store';
    }
    
    // Fallback to auth service
    const storeOwner = await this.authService.getStoreOwnerById(storeOwnerId);
    return storeOwner?.store_name || 'Unknown Store';
  } catch (error) {
    console.error('Error getting store name:', error);
    return 'Unknown Store';
  }
}

  // Helper methods for store avatars
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

  // Helper methods
  getFullAddress(): string {
    if (!this.currentUser) return '';
    return `${this.currentUser.barangay}, ${this.currentUser.municipality}, ${this.currentUser.province}`;
  }

  getUpcomingPayments(): DebtPayment[] {
    return this.debtPayments.slice(0, 3);
  }

  // Action methods
  toggleSettings() {
    this.showSettings = !this.showSettings;
    if (!this.showSettings) {
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

  async saveCustomerProfile() {
    const loading = await this.loadingController.create({
      message: 'Saving profile...',
    });
    await loading.present();

    try {
      const updateData: any = {
        date_of_birth: this.customerData.date_of_birth,
        gender: this.customerData.gender,
        preferred_store: this.customerData.preferred_store,
        social_media: this.customerData.social_media,
        preferred_contact_method: this.customerData.preferred_contact_method,
        receive_promotions: this.customerData.receive_promotions,
        receive_debt_reminders: this.customerData.receive_debt_reminders
      };

      if (this.imagePreview && this.imagePreview.startsWith('data:image')) {
        updateData.profile_image = this.imagePreview;
      }

      await this.customerService.saveCustomerProfile(updateData);
      
      await loading.dismiss();
      await this.showToast('Profile saved successfully!', 'success');
      
      await this.loadCustomerProfile();
      this.showSettings = false;
      this.imagePreview = null;
      this.selectedFile = null;
      
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast(error.message || 'Error saving profile', 'danger');
    }
  }

  async deleteProfileImage() {
    try {
      await this.customerService.deleteCustomerProfileImage();
      this.imagePreview = null;
      await this.showToast('Profile picture removed!', 'success');
      
      await this.loadCustomerProfile();
    } catch (error: any) {
      await this.showToast(error.message || 'Error removing picture', 'danger');
    }
  }

  // Navigation methods
  async openDebtDetails() {
    this.router.navigate(['/customer/debts']);
  }

  async openPaymentDetails(payment: DebtPayment) {
    this.showToast(`Payment details for ${payment.storeName}`, 'primary');
  }

  async logout() {
    const loading = await this.loadingController.create({
      message: 'Logging out...',
    });
    
    await loading.present();
    
    // Clear all component data before logging out
    this.currentUser = null;
    this.customerProfile = null;
    this.customerData = {
      date_of_birth: '',
      gender: '',
      preferred_store: '',
      social_media: {
        facebook: '',
        instagram: ''
      },
      preferred_contact_method: 'sms',
      receive_promotions: true,
      receive_debt_reminders: true
    };
    
    setTimeout(async () => {
      this.authService.logout();
      await loading.dismiss();
      this.router.navigateByUrl('/home', { replaceUrl: true });
      this.showToast('Logged out successfully', 'success');
    }, 1000);
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
  // Add these methods to your Tab1Page class
generateCustomerAvatar(name: string): string {
  const initials = this.getCustomerInitials(name);
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
  ];
  const color = colors[name.charCodeAt(0) % colors.length];
  
  // Create a proper SVG with explicit dimensions
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="80" height="80" viewBox="0 0 80 80">
      <circle cx="40" cy="40" r="40" fill="${color}"/>
      <text x="40" y="45" font-family="Arial, sans-serif" font-size="32" fill="white" text-anchor="middle" dominant-baseline="middle" font-weight="bold">${initials}</text>
    </svg>
  `;
  return svg;
}

generateCustomerAvatarLarge(name: string): string {
  const initials = this.getCustomerInitials(name);
  const colors = [
    '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
    '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
  ];
  const color = colors[name.charCodeAt(0) % colors.length];
  
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="120" height="120" viewBox="0 0 120 120">
      <circle cx="60" cy="60" r="60" fill="${color}"/>
      <text x="60" y="65" font-family="Arial, sans-serif" font-size="48" fill="white" text-anchor="middle" dominant-baseline="middle" font-weight="bold">${initials}</text>
    </svg>
  `;
  return svg;
}

private getCustomerInitials(fullName: string): string {
  if (!fullName) return 'CU';
  
  const names = fullName.trim().split(' ');
  if (names.length === 1) {
    return names[0].substring(0, 2).toUpperCase();
  } else {
    const firstInitial = names[0].charAt(0).toUpperCase();
    const lastInitial = names[names.length - 1].charAt(0).toUpperCase();
    return firstInitial + lastInitial;
  }
}

}