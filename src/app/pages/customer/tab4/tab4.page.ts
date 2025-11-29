import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, doc, getDoc } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { StoreService } from 'src/app/services/store.service';
import { User } from '@angular/fire/auth'; // Add this import

export interface Store {
  id: string;
  name: string;
  owner_id: string;
  profile_image?: string | null;
  color: string;
  initials: string;
  address: string;
  contact: string;
  description?: string | null;
  category?: string | null;
  isOpen: boolean;
  rating?: number;
  productCount: number;
  operating_hours?: {
    open: string;
    close: string;
    days: string[];
  };
  business_permit_number?: string;
  established_date?: any;
  social_media?: {
    facebook?: string;
    instagram?: string;
    website?: string;
  };
}

export interface Product {
  id: string;
  name: string;
  description?: string | null;
  selling_price: number;
  cost_price?: number;
  category: string;
  unit: string;
  pieces?: number;
  stock_quantity: number;
  min_stock?: number;
  barcode?: string | null;
  product_image?: string | null;
  store_id: string;
  store_name: string;
  store_color: string;
  is_available: boolean;
  pricing_option: string;
  created_at?: any;
}

export interface StoreProfile {
  id: string;
  store_owner_id: string;
  store_address: string;
  store_description?: string | null;
  store_image?: string | null;
  business_permit_number?: string;
  established_date?: any;
  operating_hours?: {
    open: string;
    close: string;
    days: string[];
  };
  social_media?: {
    facebook?: string;
    instagram?: string;
    website?: string;
  };
  created_at?: any;
  updated_at?: any;
}

// Add these interfaces at the top of your file, after the existing interfaces

export interface UserData {
  store_name?: string;
  phone_number?: string;
  barangay?: string;
  municipality?: string;
  region?: string; // Add this
  province?: string;
  sitio_purok?: string;
  full_name?: string;
  email?: string;
  role?: string;
  uid?: string; // Add this
}

export interface ProductData {
  product_name?: string;
  product_description?: string;
  selling_price?: number;
  cost_price?: number;
  product_category?: string;
  unit?: string;
  pieces?: number;
  stock_quantity?: number;
  min_stock?: number;
  barcode?: string;
  product_image?: string;
  image_url?: string;
  pricing_option?: string;
  created_at?: any;
  store_owner_id?: string;
  // Remove the index signature and add specific optional properties
  name?: string;
  image?: string;
  category?: string;
  description?: string;
}

@Component({
  selector: 'app-customer-tab4',
  templateUrl: './tab4.page.html',
  styleUrls: ['./tab4.page.scss'],
  standalone: false,
})
export class Tab4Page implements OnInit {
  // Add these properties
  currentUser: any = null;
  userRegion: string = '';
  userProvince: string = '';
  stores: Store[] = [];
  products: Product[] = [];
  filteredProducts: Product[] = [];
  storeProducts: Product[] = []; // Products for selected store in modal
  
  // Search and filter
  searchTerm: string = '';
  selectedStore: string = 'all';
  selectedCategory: string = 'all';
  priceRange: string = 'all';
  sortBy: string = 'name';
  
  // View mode
  viewMode: 'stores' | 'products' = 'stores';
  
  // Loading states
  isLoading: boolean = false;
  searchTimeout: any;
  
  // Selected store for detailed view
  selectedStoreDetail: Store | null = null;
  showStoreModal: boolean = false;

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
    console.log('🏁 Tab4 ngOnInit started');
      this.logMethodCall('ngOnInit');
      await this.loadCurrentUserLocation();
      await this.loadStoresAndProducts();

  }

 // Add this method to get current user's location
async loadCurrentUserLocation() {
  try {
    const user = this.authService.getCurrentUser(); // This returns your custom User type
    
    if (user) {
      const userId = user.id; // Use the id property from your User interface
      
      if (!userId) {
        console.error('User ID not found');
        return;
      }

      const userRef = doc(this.firestore, 'all_users', userId);
      const userDoc = await getDoc(userRef);
      
      if (userDoc.exists()) {
        const userData = userDoc.data() as UserData;
        this.currentUser = userData;
        
        // Access properties safely - they are defined in your User interface
        this.userRegion = userData.region || '';
        this.userProvince = userData.province || '';
        
        console.log('📍 Current user location:', {
          region: this.userRegion,
          province: this.userProvince,
          userId: userId,
          userRole: user.role
        });
      } else {
        console.log('User document not found in all_users collection');
      }
    } else {
      console.log('No user logged in');
    }
  } catch (error) {
    console.error('Error loading current user location:', error);
  }
}

async loadStoresAndProducts() {
  // Prevent multiple simultaneous loads
  if (this.isLoading) {
    console.log('⏳ Load already in progress, skipping...');
    return;
  }

  const loading = await this.loadingController.create({
    message: 'Loading stores and products...'
  });
  await loading.present();

  try {
    this.isLoading = true;
    
    // Clear existing data first
    this.stores = [];
    this.products = [];
    this.filteredProducts = [];
    
    console.log('🔄 Starting to load stores and products...');
    
    // Load stores first, then products (sequential to avoid race conditions)
    await this.loadStores();
    await this.loadProducts();
    
    this.applyFilters();
    
    console.log('✅ Successfully loaded stores and products');
    
  } catch (error) {
    console.error('Error loading data:', error);
    this.showToast('Error loading stores and products', 'danger');
  } finally {
    this.isLoading = false;
    await loading.dismiss();
  }
}

// Replace your loadStores() method with this fixed version:

async loadStores() {
  try {
    console.log('🔄 Loading stores...');
    
    const usersRef = collection(this.firestore, 'all_users');
    const q = query(usersRef, where('role', '==', 'StoreOwner'));
    const querySnapshot = await getDocs(q);
    
    console.log(`🏪 Found ${querySnapshot.size} store owners`);
    
    // Clear the stores array first to prevent duplicates
    this.stores = [];
    
    // Use a Set to track processed store owner IDs to prevent duplicates
    const processedStoreOwnerIds = new Set<string>();
    
    for (const userDoc of querySnapshot.docs) {
      const userData = userDoc.data() as UserData;
      const storeOwnerId = userDoc.id;
      
      // Skip if we've already processed this store owner
      if (processedStoreOwnerIds.has(storeOwnerId)) {
        console.log(`⏭️ Skipping duplicate store owner: ${storeOwnerId}`);
        continue;
      }
      
      processedStoreOwnerIds.add(storeOwnerId);
      
      console.log(`📝 Processing store: ${userData.store_name}`, userData);
      
      // 🔥 FILTER BY LOCATION: Only include stores in the same region and province
      if (this.userRegion && this.userProvince) {
        const storeRegion = userData.region || '';
        const storeProvince = userData.province || '';
        
        console.log(`📍 Location check for store: ${userData.store_name}`, {
          storeLocation: `${storeProvince}, ${storeRegion}`,
          userLocation: `${this.userProvince}, ${this.userRegion}`
        });
        
        // Case-insensitive comparison for better matching
        const regionMatch = storeRegion?.toLowerCase() === this.userRegion?.toLowerCase();
        const provinceMatch = storeProvince?.toLowerCase() === this.userProvince?.toLowerCase();
        
        if (!regionMatch || !provinceMatch) {
          console.log(`📍 Skipping store ${userData.store_name} - location mismatch`);
          continue;
        }
        
        console.log(`✅ Store ${userData.store_name} matches user location`);
      }
      
      // Get store profile from store_profiles collection
      let storeProfile: StoreProfile | null = null;
      try {
        const storeProfilesRef = collection(this.firestore, 'store_profiles');
        const profileQuery = query(storeProfilesRef, where('store_owner_id', '==', storeOwnerId));
        const profileSnapshot = await getDocs(profileQuery);
        
        console.log(`📋 Found ${profileSnapshot.size} store profiles for owner ${storeOwnerId}`);
        
        if (!profileSnapshot.empty) {
          const profileDoc = profileSnapshot.docs[0];
          storeProfile = {
            id: profileDoc.id,
            store_owner_id: profileDoc.data()['store_owner_id'],
            store_image: profileDoc.data()['store_image'],
            store_description: profileDoc.data()['store_description'],
            store_address: profileDoc.data()['store_address'],
            business_permit_number: profileDoc.data()['business_permit_number'],
            established_date: profileDoc.data()['established_date'],
            operating_hours: profileDoc.data()['operating_hours'],
            social_media: profileDoc.data()['social_media'],
            created_at: profileDoc.data()['created_at'],
            updated_at: profileDoc.data()['updated_at']
          };
          console.log('🏬 Store profile data:', storeProfile);
        } else {
          console.log('❌ No store profile found for:', storeOwnerId);
        }
      } catch (error) {
        console.warn(`Could not load store profile for ${storeOwnerId}:`, error);
        storeProfile = null;
      }
      
      // Count products for this store
      const productsRef = collection(this.firestore, 'products');
      const productQuery = query(
        productsRef, 
        where('store_owner_id', '==', storeOwnerId),
        where('is_active', '==', true) // Only count active products
      );
      const productSnapshot = await getDocs(productQuery);
      const productCount = productSnapshot.size;
      
      const storeName = userData.store_name || `${userData.full_name}'s Store` || 'Unknown Store';
      const store: Store = {
        id: storeOwnerId,
        name: storeName,
        owner_id: storeOwnerId,
        profile_image: storeProfile?.store_image || null,
        color: this.getStoreColor(storeName),
        initials: this.getStoreInitials(storeName),
        address: storeProfile?.store_address || this.buildStoreAddress(userData),
        contact: userData.phone_number || 'N/A',
        description: storeProfile?.store_description || null,
        category: 'Sari-Sari Store',
        isOpen: this.checkIfStoreIsOpen(storeProfile?.operating_hours),
        rating: undefined,
        productCount: productCount,
        operating_hours: storeProfile?.operating_hours,
        business_permit_number: storeProfile?.business_permit_number,
        established_date: storeProfile?.established_date,
        social_media: storeProfile?.social_media
      };
      
      this.stores.push(store);
      console.log(`✅ Added store: ${storeName} with ${productCount} products`);
    }
    
    // Sort stores by product count (most products first)
    this.stores.sort((a, b) => b.productCount - a.productCount);
    
    console.log(`🎉 Loaded ${this.stores.length} unique stores`);
    
  } catch (error) {
    console.error('❌ Error loading stores:', error);
    this.stores = [];
  }
}

async loadProducts() {
  try {
    console.log('🔄 Loading products...');
    
    const productsRef = collection(this.firestore, 'products');
    const q = query(productsRef, where('is_active', '==', true));
    const querySnapshot = await getDocs(q);
    
    console.log(`📦 Found ${querySnapshot.size} products`);
    
    this.products = [];
    
    for (const productDoc of querySnapshot.docs) {
      const data = productDoc.data() as ProductData;
      const storeOwnerId = data.store_owner_id;
      
      console.log(`🔍 Processing product:`, data.name);
      
      if (storeOwnerId) {
        // Find store info - ONLY from existing stores array, don't create new ones
        const store = this.stores.find(s => s.owner_id === storeOwnerId);
        
        if (!store) {
          console.log(`🏪 Store not found for owner ${storeOwnerId}, skipping product`);
          continue; // Skip products whose stores we don't have
        }
        
        // FIX: Use bracket notation to safely access optional properties
        const productName = data.product_name || data['name'] || 'Unknown Product';
        const productImage = data.product_image || data.image_url || data['image'] || null;
        const productCategory = data.product_category || data['category'] || 'Uncategorized';
        const productDescription = data.product_description || data['description'] || null;
        
        const product: Product = {
          id: productDoc.id,
          name: productName,
          description: productDescription,
          selling_price: data.selling_price || 0,
          cost_price: data.cost_price || 0,
          category: productCategory,
          unit: data.unit || 'piece',
          pieces: data.pieces || 1,
          stock_quantity: data.stock_quantity || 0,
          min_stock: data.min_stock || 0,
          barcode: data.barcode || null,
          product_image: productImage,
          store_id: storeOwnerId,
          store_name: store.name,
          store_color: store.color,
          is_available: (data.stock_quantity || 0) > 0,
          pricing_option: data.pricing_option || 'piece',
          created_at: data.created_at || null
        };
        
        this.products.push(product);
        console.log(`✅ Added product: ${product.name} for store: ${store.name}`);
      } else {
        console.warn('❌ Product has no store_owner_id:', data.name);
      }
    }
    
    console.log(`🎉 Loaded ${this.products.length} products`);
    
  } catch (error) {
    console.error('❌ Error loading products:', error);
    this.products = [];
  }
}

private logMethodCall(methodName: string) {
  const stack = new Error().stack;
  console.log(`📞 ${methodName} called from:`, stack?.split('\n')[2]?.trim());
}
// Add this new method to handle store search:

// Filtered stores for display
get filteredStores(): Store[] {
  if (!this.searchTerm || this.viewMode !== 'stores') {
    return this.stores;
  }

  const term = this.searchTerm.toLowerCase();
  return this.stores.filter(store =>
    store.name.toLowerCase().includes(term) ||
    store.address.toLowerCase().includes(term) ||
    store.category?.toLowerCase().includes(term) ||
    (store.description && store.description.toLowerCase().includes(term))
  );
}
  // Load products for specific store (for modal)
  async loadStoreProducts(storeId: string) {
    this.storeProducts = this.products.filter(product => 
      product.store_id === storeId && product.is_available
    );
  }

  // Check if store is currently open based on operating hours
  private checkIfStoreIsOpen(operatingHours?: any): boolean {
    if (!operatingHours) return true;
    
    const now = new Date();
    const currentDay = now.toLocaleString('en-US', { weekday: 'long' });
    const currentTime = now.toTimeString().slice(0, 5);
    
    const days = operatingHours.days || [];
    if (!days.includes(currentDay)) {
      return false;
    }
    
    const openTime = operatingHours.open || '00:00';
    const closeTime = operatingHours.close || '23:59';
    
    return currentTime >= openTime && currentTime <= closeTime;
  }

  // Store information helpers
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

  private buildStoreAddress(storeOwner: any): string {
    if (!storeOwner) return 'Address not available';
    
    const addressParts = [];
    if (storeOwner.sitio_purok) addressParts.push(storeOwner.sitio_purok);
    if (storeOwner.barangay) addressParts.push(storeOwner.barangay);
    if (storeOwner.municipality) addressParts.push(storeOwner.municipality);
    if (storeOwner.province) addressParts.push(storeOwner.province);
    if (storeOwner.region) addressParts.push(storeOwner.region);
    
    return addressParts.join(', ') || 'Address not specified';
  }

  // Add a method to show location info in the UI
getLocationInfo(): string {
  if (this.userProvince && this.userRegion) {
    return `Stores in ${this.userProvince}, ${this.userRegion}`;
  } else if (this.userProvince) {
    return `Stores in ${this.userProvince}`;
  } else if (this.userRegion) {
    return `Stores in ${this.userRegion}`;
  }
  return 'All Stores';
}

  // Filtering and Sorting
  applyFilters() {
    let filtered = this.products;

    // Filter by store
    if (this.selectedStore !== 'all') {
      filtered = filtered.filter(product => product.store_id === this.selectedStore);
    }

    // Filter by category
    if (this.selectedCategory !== 'all') {
      filtered = filtered.filter(product => product.category === this.selectedCategory);
    }

    // Filter by price range
    if (this.priceRange !== 'all') {
      filtered = this.filterByPriceRange(filtered, this.priceRange);
    }

    // Filter by availability
    filtered = filtered.filter(product => product.is_available);

    // Search filter
    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(product =>
        product.name.toLowerCase().includes(term) ||
        product.description?.toLowerCase().includes(term) ||
        product.category.toLowerCase().includes(term) ||
        product.store_name.toLowerCase().includes(term)
      );
    }

    // Sort
    this.filteredProducts = this.sortProducts(filtered);
  }

  private filterByPriceRange(products: Product[], range: string): Product[] {
    switch (range) {
      case 'under50':
        return products.filter(p => p.selling_price < 50);
      case '50-100':
        return products.filter(p => p.selling_price >= 50 && p.selling_price <= 100);
      case '100-200':
        return products.filter(p => p.selling_price > 100 && p.selling_price <= 200);
      case 'over200':
        return products.filter(p => p.selling_price > 200);
      default:
        return products;
    }
  }

  private sortProducts(products: Product[]): Product[] {
    return [...products].sort((a, b) => {
      switch (this.sortBy) {
        case 'name':
          return a.name.localeCompare(b.name);
        case 'price_low':
          return a.selling_price - b.selling_price;
        case 'price_high':
          return b.selling_price - a.selling_price;
        case 'store':
          return a.store_name.localeCompare(b.store_name);
        case 'category':
          return a.category.localeCompare(b.category);
        default:
          return a.name.localeCompare(b.name);
      }
    });
  }

  // View store details
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

  // View store from product
  viewStoreFromProduct(storeId: string) {
    const store = this.stores.find(s => s.id === storeId);
    if (store) {
      this.viewStoreDetails(store);
    }
  }

viewStoreProducts() {
  if (this.selectedStoreDetail) {
    this.viewMode = 'products';
    this.selectedStore = this.selectedStoreDetail.id;
    this.closeStoreModal();
    this.applyFilters(); // This will filter products by selected store
  }
}

  // View mode switching
  switchViewMode(mode: 'stores' | 'products') {
    this.viewMode = mode;
    if (mode === 'products') {
      this.applyFilters();
    }
  }

  // Get unique categories for filter
  get categories(): string[] {
    const categories = [...new Set(this.products.map(p => p.category))];
    return categories.sort();
  }

  // Get products count by category
  getProductsCountByCategory(category: string): number {
    return this.products.filter(p => p.category === category && p.is_available).length;
  }

  // Get stores count by category
  getStoresCountByCategory(category: string): number {
    const storeIds = new Set(
      this.products
        .filter(p => p.category === category && p.is_available)
        .map(p => p.store_id)
    );
    return storeIds.size;
  }

  // Format operating hours for display
  formatOperatingHours(operatingHours: any): string {
    if (!operatingHours) return 'Not specified';
    
    const days = operatingHours.days || [];
    const open = operatingHours.open || '00:00';
    const close = operatingHours.close || '23:59';
    
    if (days.length === 7) {
      return `Daily ${open} - ${close}`;
    } else {
      return `${days.join(', ')} ${open} - ${close}`;
    }
  }

  // Utility Methods
  formatCurrency(amount: number): string {
    return `₱${amount?.toFixed(2) || '0.00'}`;
  }

  getProductBadgeColor(category: string): string {
    const colors: { [key: string]: string } = {
      'Groceries': 'success',
      'Electronics': 'primary',
      'Clothing': 'warning',
      'Household': 'secondary',
      'Food': 'danger',
      'Beverages': 'tertiary',
      'Snacks': 'success',
      'Drinks': 'primary',
      'Toiletries': 'warning',
      'Essentials': 'secondary'
    };
    return colors[category] || 'medium';
  }

  getStockStatusColor(quantity: number): string {
    if (quantity === 0) return 'danger';
    if (quantity <= 10) return 'warning';
    return 'success';
  }

  getStockStatusText(quantity: number): string {
    if (quantity === 0) return 'Out of Stock';
    if (quantity <= 10) return 'Low Stock';
    return 'In Stock';
  }

  // Event Handlers
  onFilterChange() {
    this.applyFilters();
  }

// Update your onSearchChange method:

onSearchChange() {
  clearTimeout(this.searchTimeout);
  this.searchTimeout = setTimeout(() => {
    if (this.viewMode === 'products') {
      this.applyFilters();
    }
    // For stores view, we use the computed filteredStores getter
  }, 300);
}

  async doRefresh(event: any) {
    await this.loadStoresAndProducts();
    event.target.complete();
  }

  // Image error handler
  handleImageError(event: any, type: 'store' | 'product') {
    console.log('Image load error:', event);
    const target = event.target as HTMLImageElement;
    target.style.display = 'none';
  }

  // TrackBy for performance
  trackByStoreId(index: number, item: Store): string {
    return item.id;
  }

  trackByProductId(index: number, item: Product): string {
    return item.id;
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