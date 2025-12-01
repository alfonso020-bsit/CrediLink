import { Component, OnInit } from '@angular/core';
import { Firestore, collection, query, where, getDocs, Timestamp } from '@angular/fire/firestore';
import { LoadingController, ToastController } from '@ionic/angular';
import { HttpClient } from '@angular/common/http';
import { lastValueFrom } from 'rxjs';

interface AnalyticsData {
  // User Analytics
  totalUsers: number;
  activeUsers: number;
  inactiveUsers: number;
  storeOwners: number;
  employees: number;
  customers: number;
  newUsersToday: number;
  newUsersThisWeek: number;
  newUsersThisMonth: number;
  userGrowthRate: number;

  // Store Analytics
  totalStores: number;
  activeStores: number;
  inactiveStores: number;
  newStoresToday: number;
  newStoresThisWeek: number;
  newStoresThisMonth: number;
  storeGrowthRate: number;

  // Product Analytics
  totalProducts: number;
  availableProducts: number;
  outOfStockProducts: number;
  averageProductsPerStore: number;

  // Location Analytics
  topRegions: { name: string; count: number; percentage: number }[];
  topProvinces: { name: string; count: number; percentage: number }[];
  topMunicipalities: { name: string; count: number; percentage: number }[];

  // Time-based Analytics
  userRegistrationTrend: { date: string; count: number }[];
  storeRegistrationTrend: { date: string; count: number }[];
  
  // Role Distribution
  roleDistribution: { role: string; count: number; percentage: number }[];
}

interface LocationData {
  [regionCode: string]: {
    region_name: string;
    province_list: {
      [provinceName: string]: {
        municipality_list: {
          [municipalityName: string]: {
            barangay_list: string[];
          };
        };
      };
    };
  };
}

@Component({
  selector: 'app-tab4',
  templateUrl: './tab4.page.html',
  styleUrls: ['./tab4.page.scss'],
  standalone: false,
})
export class Tab4Page implements OnInit {
  analytics: AnalyticsData = {
    totalUsers: 0,
    activeUsers: 0,
    inactiveUsers: 0,
    storeOwners: 0,
    employees: 0,
    customers: 0,
    newUsersToday: 0,
    newUsersThisWeek: 0,
    newUsersThisMonth: 0,
    userGrowthRate: 0,
    totalStores: 0,
    activeStores: 0,
    inactiveStores: 0,
    newStoresToday: 0,
    newStoresThisWeek: 0,
    newStoresThisMonth: 0,
    storeGrowthRate: 0,
    totalProducts: 0,
    availableProducts: 0,
    outOfStockProducts: 0,
    averageProductsPerStore: 0,
    topRegions: [],
    topProvinces: [],
    topMunicipalities: [],
    userRegistrationTrend: [],
    storeRegistrationTrend: [],
    roleDistribution: []
  };

  isLoading: boolean = false;
  selectedTimeRange: string = '7days';
  phLocations: LocationData | null = null;
  lastUpdated: Date = new Date();

  // Filters
  selectedRole: string = 'all';
  selectedRegion: string = 'all';
  selectedProvince: string = 'all';
  selectedMunicipality: string = 'all';
  selectedBarangay: string = 'all';
  statusFilter: string = 'all';
  showFilters: boolean = false;

  // Location Data
  regions: { code: string; name: string }[] = [];
  provinces: string[] = [];
  municipalities: string[] = [];
  barangays: string[] = [];

  // UI States
  showUserChart: boolean = true;
  showStoreChart: boolean = true;
  showLocationChart: boolean = true;

  // Expose Math to template
  Math = Math;

  constructor(
    private firestore: Firestore,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private http: HttpClient
  ) { }

  async ngOnInit() {
    await this.loadLocationData();
    await this.loadAnalytics();
  }

  async loadLocationData() {
    try {
      const locationData = await lastValueFrom(
        this.http.get<LocationData>('assets/data/phil.json')
      );
      this.phLocations = locationData;
    } catch (error) {
      console.error('Error loading location data:', error);
    }
  }

  async loadAnalytics() {
    this.isLoading = true;
    const loading = await this.loadingController.create({
      message: 'Loading analytics data...'
    });
    await loading.present();

    try {
      // Load all data concurrently
      await Promise.all([
        this.loadUserAnalytics(),
        this.loadStoreAnalytics(),
        this.loadProductAnalytics(),
        this.loadLocationAnalytics(),
        this.loadTrendAnalytics()
      ]);

      this.lastUpdated = new Date();
      await this.showToast('Analytics loaded successfully', 'success');
    } catch (error) {
      console.error('Error loading analytics:', error);
      await this.showToast('Error loading analytics data', 'danger');
    } finally {
      this.isLoading = false;
      await loading.dismiss();
    }
  }

  async loadUserAnalytics() {
    const usersRef = collection(this.firestore, 'all_users');
    const snapshot = await getDocs(usersRef);
    
    const users = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    this.analytics.totalUsers = users.length;
    this.analytics.activeUsers = users.filter((u: any) => u.status === 'active').length;
    this.analytics.inactiveUsers = users.filter((u: any) => u.status === 'inactive').length;
    this.analytics.storeOwners = users.filter((u: any) => u.role === 'StoreOwner').length;
    this.analytics.employees = users.filter((u: any) => u.role === 'Employee').length;
    this.analytics.customers = users.filter((u: any) => u.role === 'Customer').length;

    // Calculate new users
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);

    this.analytics.newUsersToday = users.filter((u: any) => {
      const createdDate = u.created_at?.toDate ? u.created_at.toDate() : new Date(u.created_at);
      return createdDate >= today;
    }).length;

    this.analytics.newUsersThisWeek = users.filter((u: any) => {
      const createdDate = u.created_at?.toDate ? u.created_at.toDate() : new Date(u.created_at);
      return createdDate >= weekAgo;
    }).length;

    this.analytics.newUsersThisMonth = users.filter((u: any) => {
      const createdDate = u.created_at?.toDate ? u.created_at.toDate() : new Date(u.created_at);
      return createdDate >= monthStart;
    }).length;

    const lastMonthUsers = users.filter((u: any) => {
      const createdDate = u.created_at?.toDate ? u.created_at.toDate() : new Date(u.created_at);
      return createdDate >= lastMonthStart && createdDate < monthStart;
    }).length;

    this.analytics.userGrowthRate = lastMonthUsers > 0 
      ? ((this.analytics.newUsersThisMonth - lastMonthUsers) / lastMonthUsers) * 100 
      : 100;

    // Role distribution
    this.analytics.roleDistribution = [
      { 
        role: 'Store Owners', 
        count: this.analytics.storeOwners, 
        percentage: (this.analytics.storeOwners / this.analytics.totalUsers) * 100 
      },
      { 
        role: 'Employees', 
        count: this.analytics.employees, 
        percentage: (this.analytics.employees / this.analytics.totalUsers) * 100 
      },
      { 
        role: 'Customers', 
        count: this.analytics.customers, 
        percentage: (this.analytics.customers / this.analytics.totalUsers) * 100 
      }
    ];
  }

  async loadStoreAnalytics() {
    const usersRef = collection(this.firestore, 'all_users');
    const storeQuery = query(usersRef, where('role', '==', 'StoreOwner'));
    const snapshot = await getDocs(storeQuery);
    
    const stores = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    this.analytics.totalStores = stores.length;
    this.analytics.activeStores = stores.filter((s: any) => s.status === 'active').length;
    this.analytics.inactiveStores = stores.filter((s: any) => s.status === 'inactive').length;

    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const weekAgo = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
    const lastMonthStart = new Date(now.getFullYear(), now.getMonth() - 1, 1);

    this.analytics.newStoresToday = stores.filter((s: any) => {
      const createdDate = s.created_at?.toDate ? s.created_at.toDate() : new Date(s.created_at);
      return createdDate >= today;
    }).length;

    this.analytics.newStoresThisWeek = stores.filter((s: any) => {
      const createdDate = s.created_at?.toDate ? s.created_at.toDate() : new Date(s.created_at);
      return createdDate >= weekAgo;
    }).length;

    this.analytics.newStoresThisMonth = stores.filter((s: any) => {
      const createdDate = s.created_at?.toDate ? s.created_at.toDate() : new Date(s.created_at);
      return createdDate >= monthStart;
    }).length;

    const lastMonthStores = stores.filter((s: any) => {
      const createdDate = s.created_at?.toDate ? s.created_at.toDate() : new Date(s.created_at);
      return createdDate >= lastMonthStart && createdDate < monthStart;
    }).length;

    this.analytics.storeGrowthRate = lastMonthStores > 0 
      ? ((this.analytics.newStoresThisMonth - lastMonthStores) / lastMonthStores) * 100 
      : 100;
  }

  async loadProductAnalytics() {
    const productsRef = collection(this.firestore, 'products');
    const activeQuery = query(productsRef, where('is_active', '==', true));
    const snapshot = await getDocs(activeQuery);
    
    const products = snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));

    this.analytics.totalProducts = products.length;
    this.analytics.availableProducts = products.filter((p: any) => (p.stock_quantity || 0) > 0).length;
    this.analytics.outOfStockProducts = products.filter((p: any) => (p.stock_quantity || 0) === 0).length;
    this.analytics.averageProductsPerStore = this.analytics.totalStores > 0 
      ? Math.round(this.analytics.totalProducts / this.analytics.totalStores) 
      : 0;
  }

  async loadLocationAnalytics() {
    const usersRef = collection(this.firestore, 'all_users');
    const snapshot = await getDocs(usersRef);
    
    const users = snapshot.docs.map(doc => doc.data());

    // Count by region
    const regionCounts: { [key: string]: number } = {};
    const provinceCounts: { [key: string]: number } = {};
    const municipalityCounts: { [key: string]: number } = {};

    users.forEach((user: any) => {
      if (user.region) {
        regionCounts[user.region] = (regionCounts[user.region] || 0) + 1;
      }
      if (user.province) {
        provinceCounts[user.province] = (provinceCounts[user.province] || 0) + 1;
      }
      if (user.municipality) {
        municipalityCounts[user.municipality] = (municipalityCounts[user.municipality] || 0) + 1;
      }
    });

    // Top 5 regions
    this.analytics.topRegions = Object.entries(regionCounts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: (count / this.analytics.totalUsers) * 100
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    // Top 5 provinces
    this.analytics.topProvinces = Object.entries(provinceCounts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: (count / this.analytics.totalUsers) * 100
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);

    // Top 5 municipalities
    this.analytics.topMunicipalities = Object.entries(municipalityCounts)
      .map(([name, count]) => ({
        name,
        count,
        percentage: (count / this.analytics.totalUsers) * 100
      }))
      .sort((a, b) => b.count - a.count)
      .slice(0, 5);
  }

  async loadTrendAnalytics() {
    const usersRef = collection(this.firestore, 'all_users');
    const snapshot = await getDocs(usersRef);
    const users = snapshot.docs.map(doc => doc.data());

    // Get date range based on selection
    const days = this.selectedTimeRange === '7days' ? 7 : 30;
    const trendData: { [key: string]: { users: number; stores: number } } = {};

    for (let i = days - 1; i >= 0; i--) {
      const date = new Date();
      date.setDate(date.getDate() - i);
      const dateStr = date.toISOString().split('T')[0];
      trendData[dateStr] = { users: 0, stores: 0 };
    }

    // Count users by date
    users.forEach((user: any) => {
      const createdDate = user.created_at?.toDate ? user.created_at.toDate() : new Date(user.created_at);
      const dateStr = createdDate.toISOString().split('T')[0];
      
      if (trendData[dateStr]) {
        trendData[dateStr].users++;
        if (user.role === 'StoreOwner') {
          trendData[dateStr].stores++;
        }
      }
    });

    // Convert to array format
    this.analytics.userRegistrationTrend = Object.entries(trendData).map(([date, data]) => ({
      date: this.formatTrendDate(date),
      count: data.users
    }));

    this.analytics.storeRegistrationTrend = Object.entries(trendData).map(([date, data]) => ({
      date: this.formatTrendDate(date),
      count: data.stores
    }));
  }

  formatTrendDate(dateStr: string): string {
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  }

  async onTimeRangeChange() {
    await this.loadTrendAnalytics();
  }

  async refreshAnalytics() {
    await this.loadAnalytics();
  }

  getGrowthIcon(rate: number): string {
    return rate >= 0 ? 'trending-up' : 'trending-down';
  }

  getGrowthColor(rate: number): string {
    return rate >= 0 ? 'success' : 'danger';
  }

  formatPercentage(value: number): string {
    return value.toFixed(1) + '%';
  }

  formatNumber(value: number): string {
    return value.toLocaleString();
  }

  formatLastUpdated(): string {
    const now = new Date();
    const diff = now.getTime() - this.lastUpdated.getTime();
    const minutes = Math.floor(diff / 60000);
    
    if (minutes < 1) return 'Just now';
    if (minutes === 1) return '1 minute ago';
    if (minutes < 60) return `${minutes} minutes ago`;
    
    const hours = Math.floor(minutes / 60);
    if (hours === 1) return '1 hour ago';
    return `${hours} hours ago`;
  }

  getMaxTrendValue(trend: { date: string; count: number }[]): number {
    if (!trend || trend.length === 0) return 1;
    const max = Math.max(...trend.map(t => t.count));
    return max > 0 ? max : 1;
  }

  getBarHeight(count: number, trend: { date: string; count: number }[]): number {
    const maxValue = this.getMaxTrendValue(trend);
    const maxHeight = 180; // Maximum height in pixels
    const minHeight = 40; // Minimum height for visibility when count > 0
    
    if (count === 0) {
      return 8; // Very small bar for zero values
    }
    
    // Calculate proportional height with minimum threshold
    const proportionalHeight = (count / maxValue) * maxHeight;
    return Math.max(proportionalHeight, minHeight);
  }

  private async showToast(message: string, color: string) {
    const toast = await this.toastController.create({
      message,
      duration: 2000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }
}