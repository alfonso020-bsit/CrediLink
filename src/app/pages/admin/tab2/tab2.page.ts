import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, doc, updateDoc, Timestamp } from '@angular/fire/firestore';
import { HttpClient } from '@angular/common/http';
import { AdminService } from 'src/app/services/admin.service';
import { lastValueFrom } from 'rxjs';

export interface Store {
  id: string;
  name: string;
  owner_id: string;
  owner_name: string;
  email: string;
  profile_image?: string | null;
  color: string;
  initials: string;
  address: string;
  contact: string;
  description?: string | null;
  category?: string | null;
  status: 'active' | 'inactive';
  productCount: number;
  operating_hours?: any;
  business_permit_number?: string;
  established_date?: any;
  social_media?: any;
  created_at: any;
  region?: string;
  province?: string;
  municipality?: string;
  barangay?: string;
}

export interface Product {
  id: string;
  name: string;
  description?: string | null;
  selling_price: number;
  category: string;
  unit: string;
  stock_quantity: number;
  store_id: string;
  store_name: string;
  is_available: boolean;
}

interface Region {
  code: string;
  name: string;
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
  selector: 'app-tab2',
  templateUrl: './tab2.page.html',
  styleUrls: ['./tab2.page.scss'],
  standalone: false,
})
export class Tab2Page implements OnInit {
  // Store Data
  allStores: Store[] = [];
  filteredStores: Store[] = [];
  storeProducts: Product[] = [];
  
  // Summary Statistics
  totalStores: number = 0;
  activeStores: number = 0;
  newStoresThisMonth: number = 0;
  totalProducts: number = 0;

  // Filters
  searchTerm: string = '';
  selectedRegion: string = 'all';
  selectedProvince: string = 'all';
  selectedMunicipality: string = 'all';
  selectedBarangay: string = 'all';
  statusFilter: string = 'all';
  dateFilter: string = 'all';
  sortBy: string = 'newest';
  showFilters: boolean = false;

  // Location Data (from phil.json)
  regions: Region[] = [];
  provinces: string[] = [];
  municipalities: string[] = [];
  barangays: string[] = [];
  
  // JSON data
  phLocations: LocationData | null = null;
  isLoadingLocations = true;

  // UI States
  isLoading: boolean = false;
  showStoreModal: boolean = false;
  selectedStoreDetail: Store | null = null;

  // Search timeout
  searchTimeout: any;

  constructor(
    private firestore: Firestore,
    private adminService: AdminService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private alertController: AlertController,
    private http: HttpClient
  ) { }

  async ngOnInit() {
    await this.loadLocationData();
    await this.loadStores();
  }

  async loadLocationData() {
    try {
      const locationData = await lastValueFrom(
        this.http.get<LocationData>('assets/data/phil.json')
      );
      
      if (locationData) {
        this.phLocations = locationData;
        this.loadRegions();
      } else {
        throw new Error('No location data received');
      }
      
      this.isLoadingLocations = false;
    } catch (error) {
      console.error('Error loading location data:', error);
      this.isLoadingLocations = false;
      this.phLocations = null;
      await this.showToast('Error loading location data. Please check your connection.', 'danger');
    }
  }

  loadRegions() {
    if (this.phLocations) {
      this.regions = Object.keys(this.phLocations).map(key => ({
        code: key,
        name: this.phLocations![key].region_name
      })).sort((a, b) => a.name.localeCompare(b.name));
    }
  }

  // Get region name from code
  getRegionName(regionCode: string): string {
    if (!regionCode || !this.phLocations) return '';
    return this.phLocations[regionCode]?.region_name || '';
  }

  // Location change handlers - FIXED VERSION
  onRegionChange() {
    console.log('📍 Region changed to:', this.selectedRegion);
    
    // Reset dependent filters
    this.selectedProvince = 'all';
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.provinces = [];
    this.municipalities = [];
    this.barangays = [];
    
    // Load provinces for selected region
    if (this.selectedRegion && this.selectedRegion !== 'all' && this.phLocations) {
      const regionData = this.phLocations[this.selectedRegion];
      if (regionData?.province_list) {
        this.provinces = Object.keys(regionData.province_list).sort();
        console.log(`✅ Loaded ${this.provinces.length} provinces for region ${this.selectedRegion}`);
      } else {
        console.warn('❌ No provinces found for region:', this.selectedRegion);
      }
    }
    
    this.onFilterChange();
  }

  onProvinceChange() {
    console.log('📍 Province changed to:', this.selectedProvince);
    
    // Reset dependent filters
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.municipalities = [];
    this.barangays = [];
    
    // Load municipalities for selected province
    if (this.selectedRegion && this.selectedRegion !== 'all' && 
        this.selectedProvince && this.selectedProvince !== 'all' && 
        this.phLocations) {
      const provinceData = this.phLocations[this.selectedRegion]?.province_list[this.selectedProvince];
      if (provinceData?.municipality_list) {
        this.municipalities = Object.keys(provinceData.municipality_list).sort();
        console.log(`✅ Loaded ${this.municipalities.length} municipalities for province ${this.selectedProvince}`);
      } else {
        console.warn('❌ No municipalities found for province:', this.selectedProvince);
      }
    }
    
    this.onFilterChange();
  }

  onMunicipalityChange() {
    console.log('📍 Municipality changed to:', this.selectedMunicipality);
    
    // Reset dependent filters
    this.selectedBarangay = 'all';
    this.barangays = [];
    
    // Load barangays for selected municipality
    if (this.selectedRegion && this.selectedRegion !== 'all' && 
        this.selectedProvince && this.selectedProvince !== 'all' && 
        this.selectedMunicipality && this.selectedMunicipality !== 'all' && 
        this.phLocations) {
      const municipalityData = this.phLocations[this.selectedRegion]
        ?.province_list[this.selectedProvince]
        ?.municipality_list[this.selectedMunicipality];
      
      if (municipalityData?.barangay_list) {
        this.barangays = municipalityData.barangay_list.sort();
        console.log(`✅ Loaded ${this.barangays.length} barangays for municipality ${this.selectedMunicipality}`);
      } else {
        console.warn('❌ No barangays found for municipality:', this.selectedMunicipality);
      }
    }
    
    this.onFilterChange();
  }

  onBarangayChange() {
    console.log('📍 Barangay changed to:', this.selectedBarangay);
    this.onFilterChange();
  }

  async loadStores() {
    this.isLoading = true;
    const loading = await this.loadingController.create({
      message: 'Loading all stores...'
    });
    await loading.present();

    try {
      // Get all store owners
      const storeOwners = await this.adminService.getStoreOwners();
      this.allStores = [];
      this.totalProducts = 0;

      for (const storeOwner of storeOwners) {
        // Get store profile
        let storeProfile: any = null;
        try {
          const storeProfilesRef = collection(this.firestore, 'store_profiles');
          const profileQuery = query(storeProfilesRef, where('store_owner_id', '==', storeOwner.id));
          const profileSnapshot = await getDocs(profileQuery);
          
          if (!profileSnapshot.empty) {
            storeProfile = profileSnapshot.docs[0].data();
          }
        } catch (error) {
          console.warn(`Could not load store profile for ${storeOwner.id}:`, error);
        }

        // Count products for this store
        const productsRef = collection(this.firestore, 'products');
        const productQuery = query(
          productsRef, 
          where('store_owner_id', '==', storeOwner.id),
          where('is_active', '==', true)
        );
        const productSnapshot = await getDocs(productQuery);
        const productCount = productSnapshot.size;
        this.totalProducts += productCount;

        const storeName = storeOwner.store_name || `${storeOwner.full_name}'s Store` || 'Unknown Store';
        
        const store: Store = {
          id: storeOwner.id || 'unknown-id',
          name: storeName,
          owner_id: storeOwner.id || 'unknown-owner',
          owner_name: storeOwner.full_name || 'Unknown Owner',
          email: storeOwner.email || '',
          profile_image: storeProfile?.store_image || null,
          color: this.getStoreColor(storeName),
          initials: this.getStoreInitials(storeName),
          address: this.buildStoreAddress(storeOwner, storeProfile),
          contact: storeOwner.phone_number || 'N/A',
          description: storeProfile?.store_description || null,
          category: 'Sari-Sari Store',
          status: storeOwner.status || 'active',
          productCount: productCount,
          operating_hours: storeProfile?.operating_hours,
          business_permit_number: storeProfile?.business_permit_number,
          established_date: storeProfile?.established_date,
          social_media: storeProfile?.social_media,
          created_at: storeOwner.created_at || Timestamp.now(),
          region: storeOwner.region,
          province: storeOwner.province,
          municipality: storeOwner.municipality,
          barangay: storeOwner.barangay
        };

        this.allStores.push(store);
      }

      // Calculate summary statistics
      this.totalStores = this.allStores.length;
      this.activeStores = this.allStores.filter(store => store.status === 'active').length;
      this.newStoresThisMonth = this.calculateNewStoresThisMonth();

      // Apply initial filters
      this.applyFilters();

      console.log(`✅ Loaded ${this.allStores.length} stores with ${this.totalProducts} total products`);

    } catch (error) {
      console.error('Error loading stores:', error);
      this.showToast('Error loading stores', 'danger');
    } finally {
      this.isLoading = false;
      await loading.dismiss();
    }
  }

  calculateNewStoresThisMonth(): number {
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    return this.allStores.filter(store => {
      const createdDate = store.created_at?.toDate ? store.created_at.toDate() : new Date(store.created_at);
      return createdDate >= startOfMonth;
    }).length;
  }

  // Filtering Methods - FIXED VERSION
  applyFilters() {
    let filtered = [...this.allStores];

    // Search filter
    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(store =>
        store.name.toLowerCase().includes(term) ||
        store.owner_name.toLowerCase().includes(term) ||
        store.address.toLowerCase().includes(term) ||
        store.email.toLowerCase().includes(term) ||
        store.contact.includes(term)
      );
    }

    // Region filter - FIXED: Compare region names properly
    if (this.selectedRegion && this.selectedRegion !== 'all') {
      const selectedRegionName = this.getRegionName(this.selectedRegion);
      filtered = filtered.filter(store => {
        const storeRegionName = store.region || '';
        return storeRegionName.toLowerCase() === selectedRegionName.toLowerCase();
      });
    }

    // Province filter - FIXED: Compare province names directly
    if (this.selectedProvince && this.selectedProvince !== 'all') {
      filtered = filtered.filter(store => {
        const storeProvince = store.province || '';
        return storeProvince.toLowerCase() === this.selectedProvince.toLowerCase();
      });
    }

    // Municipality filter - FIXED: Compare municipality names directly
    if (this.selectedMunicipality && this.selectedMunicipality !== 'all') {
      filtered = filtered.filter(store => {
        const storeMunicipality = store.municipality || '';
        return storeMunicipality.toLowerCase() === this.selectedMunicipality.toLowerCase();
      });
    }

    // Barangay filter
    if (this.selectedBarangay && this.selectedBarangay !== 'all') {
      filtered = filtered.filter(store => {
        const storeBarangay = store.barangay || '';
        return storeBarangay.toLowerCase() === this.selectedBarangay.toLowerCase();
      });
    }

    // Status filter
    if (this.statusFilter !== 'all') {
      filtered = filtered.filter(store => store.status === this.statusFilter);
    }

    // Date filter
    if (this.dateFilter !== 'all') {
      filtered = this.filterByDateJoined(filtered, this.dateFilter);
    }

    // Sort
    this.filteredStores = this.sortStores(filtered);
  }

  filterByDateJoined(stores: Store[], filter: string): Store[] {
    const now = new Date();
    let startDate: Date;

    switch (filter) {
      case 'today':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        break;
      case 'week':
        startDate = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 7);
        break;
      case 'month':
        startDate = new Date(now.getFullYear(), now.getMonth(), 1);
        break;
      case 'year':
        startDate = new Date(now.getFullYear(), 0, 1);
        break;
      default:
        return stores;
    }

    return stores.filter(store => {
      const createdDate = store.created_at?.toDate ? store.created_at.toDate() : new Date(store.created_at);
      return createdDate >= startDate;
    });
  }

  sortStores(stores: Store[]): Store[] {
    return [...stores].sort((a, b) => {
      switch (this.sortBy) {
        case 'newest':
          const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
          const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
          return dateB.getTime() - dateA.getTime();
        
        case 'oldest':
          const dateAOld = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
          const dateBOld = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
          return dateAOld.getTime() - dateBOld.getTime();
        
        case 'name':
          return a.name.localeCompare(b.name);
        
        case 'products':
          return b.productCount - a.productCount;
        
        case 'location':
          const locationA = (a.province || '') + (a.municipality || '');
          const locationB = (b.province || '') + (b.municipality || '');
          return locationA.localeCompare(locationB);
        
        default:
          return a.name.localeCompare(b.name);
      }
    });
  }

  // Store Management Methods
  async toggleStoreStatus(store: Store) {
    const newStatus = store.status === 'active' ? 'inactive' : 'active';
    const action = newStatus === 'active' ? 'activate' : 'deactivate';

    const alert = await this.alertController.create({
      header: 'Confirm',
      message: `Are you sure you want to ${action} ${store.name}?`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Confirm',
          handler: async () => {
            await this.updateStoreStatus(store.id, newStatus);
          }
        }
      ]
    });

    await alert.present();
  }

  async updateStoreStatus(storeId: string, status: 'active' | 'inactive') {
    const loading = await this.loadingController.create({
      message: 'Updating store status...'
    });
    await loading.present();

    try {
      await this.adminService.updateUserStatus(storeId, status);
      
      // Update local store data
      const storeIndex = this.allStores.findIndex(store => store.id === storeId);
      if (storeIndex !== -1) {
        this.allStores[storeIndex].status = status;
        this.applyFilters();
      }

      this.showToast(`Store ${status === 'active' ? 'activated' : 'deactivated'} successfully`, 'success');
      
    } catch (error) {
      console.error('Error updating store status:', error);
      this.showToast('Error updating store status', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  async loadStoreProducts(storeId: string) {
    try {
      const productsRef = collection(this.firestore, 'products');
      const productQuery = query(
        productsRef, 
        where('store_owner_id', '==', storeId),
        where('is_active', '==', true)
      );
      const productSnapshot = await getDocs(productQuery);
      
      this.storeProducts = productSnapshot.docs.map(doc => {
        const data = doc.data();
        return {
          id: doc.id,
          name: data['product_name'] || data['name'] || 'Unknown Product',
          description: data['product_description'] || data['description'] || null,
          selling_price: data['selling_price'] || 0,
          category: data['product_category'] || data['category'] || 'Uncategorized',
          unit: data['unit'] || 'piece',
          stock_quantity: data['stock_quantity'] || 0,
          store_id: storeId,
          store_name: this.selectedStoreDetail?.name || 'Unknown Store',
          is_available: (data['stock_quantity'] || 0) > 0
        };
      });
    } catch (error) {
      console.error('Error loading store products:', error);
      this.storeProducts = [];
    }
  }

  // UI Methods
  async viewStoreDetails(store: Store) {
    this.selectedStoreDetail = store;
    await this.loadStoreProducts(store.id);
    this.showStoreModal = true;
  }

  closeStoreModal() {
    this.showStoreModal = false;
    this.selectedStoreDetail = null;
    this.storeProducts = [];
  }

  viewStoreProducts(store: Store) {
    this.showToast(`Viewing products for ${store.name}`, 'primary');
    this.closeStoreModal();
  }

  toggleFilters() {
    this.showFilters = !this.showFilters;
  }

  // Filter Management
  hasActiveFilters(): boolean {
    return this.searchTerm !== '' || 
           this.selectedRegion !== 'all' || 
           this.selectedProvince !== 'all' || 
           this.selectedMunicipality !== 'all' || 
           this.selectedBarangay !== 'all' ||
           this.statusFilter !== 'all' || 
           this.dateFilter !== 'all';
  }

  clearRegionFilter() {
    this.selectedRegion = 'all';
    this.selectedProvince = 'all';
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.provinces = [];
    this.municipalities = [];
    this.barangays = [];
    this.onFilterChange();
  }

  clearProvinceFilter() {
    this.selectedProvince = 'all';
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.municipalities = [];
    this.barangays = [];
    this.onFilterChange();
  }

  clearMunicipalityFilter() {
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.barangays = [];
    this.onFilterChange();
  }

  clearBarangayFilter() {
    this.selectedBarangay = 'all';
    this.onFilterChange();
  }

  clearStatusFilter() {
    this.statusFilter = 'all';
    this.onFilterChange();
  }

  clearDateFilter() {
    this.dateFilter = 'all';
    this.onFilterChange();
  }

  clearAllFilters() {
    this.searchTerm = '';
    this.selectedRegion = 'all';
    this.selectedProvince = 'all';
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.provinces = [];
    this.municipalities = [];
    this.barangays = [];
    this.statusFilter = 'all';
    this.dateFilter = 'all';
    this.applyFilters();
  }

  // Event Handlers
  onSearchChange() {
    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      this.applyFilters();
    }, 300);
  }

  onFilterChange() {
    this.applyFilters();
  }

  onSortChange() {
    this.applyFilters();
  }

  refreshData() {
    this.loadStores();
  }

  // Utility Methods
  private getStoreColor(storeName: string): string {
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
      '#FF9F43', '#10AC84', '#EE5A24', '#0984E3', '#6C5CE7'
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

  private buildStoreAddress(storeOwner: any, storeProfile: any): string {
    if (storeProfile?.store_address) {
      return storeProfile.store_address;
    }
    
    const addressParts = [];
    if (storeOwner.sitio_purok) addressParts.push(storeOwner.sitio_purok);
    if (storeOwner.barangay) addressParts.push(storeOwner.barangay);
    if (storeOwner.municipality) addressParts.push(storeOwner.municipality);
    if (storeOwner.province) addressParts.push(storeOwner.province);
    if (storeOwner.region) addressParts.push(storeOwner.region);
    
    return addressParts.join(', ') || 'Address not specified';
  }

  formatJoinDate(date: any): string {
    if (!date) return 'Unknown date';
    
    try {
      const jsDate = date.toDate ? date.toDate() : new Date(date);
      const now = new Date();
      const diffTime = Math.abs(now.getTime() - jsDate.getTime());
      const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

      if (diffDays === 1) return 'Yesterday';
      if (diffDays < 7) return `${diffDays} days ago`;
      if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
      if (diffDays < 365) return `${Math.floor(diffDays / 30)} months ago`;
      return `${Math.floor(diffDays / 365)} years ago`;
    } catch (error) {
      return 'Unknown date';
    }
  }

  formatDate(date: any): string {
    if (!date) return 'N/A';
    
    try {
      const jsDate = date.toDate ? date.toDate() : new Date(date);
      return jsDate.toLocaleDateString('en-PH', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  }

  getStatusLabel(status: string): string {
    return status === 'active' ? 'Active' : 'Inactive';
  }

  getDateFilterLabel(filter: string): string {
    const labels: { [key: string]: string } = {
      'today': 'Today',
      'week': 'This Week',
      'month': 'This Month',
      'year': 'This Year'
    };
    return labels[filter] || filter;
  }

  getProductBadgeColor(category: string): string {
    const colors: { [key: string]: string } = {
      'Groceries': 'success',
      'Electronics': 'primary',
      'Clothing': 'warning',
      'Household': 'secondary',
      'Food': 'danger',
      'Beverages': 'tertiary'
    };
    return colors[category] || 'medium';
  }

  handleImageError(event: any) {
    const target = event.target as HTMLImageElement;
    target.style.display = 'none';
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