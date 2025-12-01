import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, Timestamp } from '@angular/fire/firestore';
import { HttpClient } from '@angular/common/http';
import { AdminService } from 'src/app/services/admin.service';
import { lastValueFrom } from 'rxjs';

export interface User {
  id: string;
  username: string;
  full_name: string;
  email: string;
  phone_number: string;
  role: 'StoreOwner' | 'Employee' | 'Customer';
  status: 'active' | 'inactive';
  created_at: any;
  region?: string;
  province?: string;
  municipality?: string;
  barangay?: string;
  sitio_purok?: string;
  store_name?: string; // For StoreOwners
  store_owner_id?: string; // For Employees
  profile_image?: string;
  color: string;
  initials: string;
  address: string;
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
  selector: 'app-tab3',
  templateUrl: './tab3.page.html',
  styleUrls: ['./tab3.page.scss'],
  standalone: false,
})
export class Tab3Page implements OnInit {
  // User Data
  allUsers: User[] = [];
  filteredUsers: User[] = [];
  
  // Summary Statistics
  totalUsers: number = 0;
  totalStoreOwners: number = 0;
  totalEmployees: number = 0;
  totalCustomers: number = 0;
  activeUsers: number = 0;
  newUsersThisMonth: number = 0;

  // Filters
  searchTerm: string = '';
  selectedRole: string = 'all';
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
  showUserModal: boolean = false;
  selectedUserDetail: User | null = null;

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
    await this.loadUsers();
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

  // Location change handlers
  onRegionChange() {
    console.log('📍 Region changed to:', this.selectedRegion);
    
    this.selectedProvince = 'all';
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.provinces = [];
    this.municipalities = [];
    this.barangays = [];
    
    if (this.selectedRegion && this.selectedRegion !== 'all' && this.phLocations) {
      const regionData = this.phLocations[this.selectedRegion];
      if (regionData?.province_list) {
        this.provinces = Object.keys(regionData.province_list).sort();
        console.log(`✅ Loaded ${this.provinces.length} provinces`);
      }
    }
    
    this.onFilterChange();
  }

  onProvinceChange() {
    console.log('📍 Province changed to:', this.selectedProvince);
    
    this.selectedMunicipality = 'all';
    this.selectedBarangay = 'all';
    this.municipalities = [];
    this.barangays = [];
    
    if (this.selectedRegion && this.selectedRegion !== 'all' && 
        this.selectedProvince && this.selectedProvince !== 'all' && 
        this.phLocations) {
      const provinceData = this.phLocations[this.selectedRegion]?.province_list[this.selectedProvince];
      if (provinceData?.municipality_list) {
        this.municipalities = Object.keys(provinceData.municipality_list).sort();
        console.log(`✅ Loaded ${this.municipalities.length} municipalities`);
      }
    }
    
    this.onFilterChange();
  }

  onMunicipalityChange() {
    console.log('📍 Municipality changed to:', this.selectedMunicipality);
    
    this.selectedBarangay = 'all';
    this.barangays = [];
    
    if (this.selectedRegion && this.selectedRegion !== 'all' && 
        this.selectedProvince && this.selectedProvince !== 'all' && 
        this.selectedMunicipality && this.selectedMunicipality !== 'all' && 
        this.phLocations) {
      const municipalityData = this.phLocations[this.selectedRegion]
        ?.province_list[this.selectedProvince]
        ?.municipality_list[this.selectedMunicipality];
      
      if (municipalityData?.barangay_list) {
        this.barangays = municipalityData.barangay_list.sort();
        console.log(`✅ Loaded ${this.barangays.length} barangays`);
      }
    }
    
    this.onFilterChange();
  }

  onBarangayChange() {
    console.log('📍 Barangay changed to:', this.selectedBarangay);
    this.onFilterChange();
  }

  async loadUsers() {
    this.isLoading = true;
    const loading = await this.loadingController.create({
      message: 'Loading all users...'
    });
    await loading.present();

    try {
      const usersRef = collection(this.firestore, 'all_users');
      const querySnapshot = await getDocs(usersRef);
      
      this.allUsers = [];

      for (const userDoc of querySnapshot.docs) {
        const data = userDoc.data();
        
        const user: User = {
          id: userDoc.id,
          username: data['username'] || 'N/A',
          full_name: data['full_name'] || 'Unknown User',
          email: data['email'] || 'N/A',
          phone_number: data['phone_number'] || 'N/A',
          role: data['role'] || 'Customer',
          status: data['status'] || 'active',
          created_at: data['created_at'] || Timestamp.now(),
          region: data['region'] || '',
          province: data['province'] || '',
          municipality: data['municipality'] || '',
          barangay: data['barangay'] || '',
          sitio_purok: data['sitio_purok'] || '',
          store_name: data['store_name'] || '',
          store_owner_id: data['store_owner_id'] || '',
          profile_image: data['profile_image'] || null,
          color: this.getUserColor(data['full_name'] || 'Unknown'),
          initials: this.getUserInitials(data['full_name'] || 'Unknown'),
          address: this.buildUserAddress(data)
        };

        this.allUsers.push(user);
      }

      // Calculate summary statistics
      this.calculateSummary();

      // Apply initial filters
      this.applyFilters();

      console.log(`✅ Loaded ${this.allUsers.length} users`);

    } catch (error) {
      console.error('Error loading users:', error);
      this.showToast('Error loading users', 'danger');
    } finally {
      this.isLoading = false;
      await loading.dismiss();
    }
  }

  calculateSummary() {
    this.totalUsers = this.allUsers.length;
    this.totalStoreOwners = this.allUsers.filter(u => u.role === 'StoreOwner').length;
    this.totalEmployees = this.allUsers.filter(u => u.role === 'Employee').length;
    this.totalCustomers = this.allUsers.filter(u => u.role === 'Customer').length;
    this.activeUsers = this.allUsers.filter(u => u.status === 'active').length;
    
    const now = new Date();
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
    
    this.newUsersThisMonth = this.allUsers.filter(user => {
      const createdDate = user.created_at?.toDate ? user.created_at.toDate() : new Date(user.created_at);
      return createdDate >= startOfMonth;
    }).length;
  }

  // Filtering Methods
  applyFilters() {
    let filtered = [...this.allUsers];

    // Search filter
    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter(user =>
        user.full_name.toLowerCase().includes(term) ||
        user.username.toLowerCase().includes(term) ||
        user.email.toLowerCase().includes(term) ||
        user.phone_number.includes(term) ||
        user.address.toLowerCase().includes(term) ||
        (user.store_name && user.store_name.toLowerCase().includes(term))
      );
    }

    // Role filter
    if (this.selectedRole !== 'all') {
      filtered = filtered.filter(user => user.role === this.selectedRole);
    }

    // Region filter
    if (this.selectedRegion && this.selectedRegion !== 'all') {
      const selectedRegionName = this.getRegionName(this.selectedRegion);
      filtered = filtered.filter(user => {
        const userRegionName = user.region || '';
        return userRegionName.toLowerCase() === selectedRegionName.toLowerCase();
      });
    }

    // Province filter
    if (this.selectedProvince && this.selectedProvince !== 'all') {
      filtered = filtered.filter(user => {
        const userProvince = user.province || '';
        return userProvince.toLowerCase() === this.selectedProvince.toLowerCase();
      });
    }

    // Municipality filter
    if (this.selectedMunicipality && this.selectedMunicipality !== 'all') {
      filtered = filtered.filter(user => {
        const userMunicipality = user.municipality || '';
        return userMunicipality.toLowerCase() === this.selectedMunicipality.toLowerCase();
      });
    }

    // Barangay filter
    if (this.selectedBarangay && this.selectedBarangay !== 'all') {
      filtered = filtered.filter(user => {
        const userBarangay = user.barangay || '';
        return userBarangay.toLowerCase() === this.selectedBarangay.toLowerCase();
      });
    }

    // Status filter
    if (this.statusFilter !== 'all') {
      filtered = filtered.filter(user => user.status === this.statusFilter);
    }

    // Date filter
    if (this.dateFilter !== 'all') {
      filtered = this.filterByDateJoined(filtered, this.dateFilter);
    }

    // Sort
    this.filteredUsers = this.sortUsers(filtered);
  }

  filterByDateJoined(users: User[], filter: string): User[] {
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
        return users;
    }

    return users.filter(user => {
      const createdDate = user.created_at?.toDate ? user.created_at.toDate() : new Date(user.created_at);
      return createdDate >= startDate;
    });
  }

  sortUsers(users: User[]): User[] {
    return [...users].sort((a, b) => {
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
          return a.full_name.localeCompare(b.full_name);
        
        case 'role':
          return a.role.localeCompare(b.role);
        
        case 'location':
          const locationA = (a.province || '') + (a.municipality || '');
          const locationB = (b.province || '') + (b.municipality || '');
          return locationA.localeCompare(locationB);
        
        default:
          return a.full_name.localeCompare(b.full_name);
      }
    });
  }

  // User Management Methods
  async toggleUserStatus(user: User) {
    const newStatus = user.status === 'active' ? 'inactive' : 'active';
    const action = newStatus === 'active' ? 'activate' : 'deactivate';

    const alert = await this.alertController.create({
      header: 'Confirm',
      message: `Are you sure you want to ${action} ${user.full_name}?`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Confirm',
          handler: async () => {
            await this.updateUserStatus(user.id, newStatus);
          }
        }
      ]
    });

    await alert.present();
  }

  async updateUserStatus(userId: string, status: 'active' | 'inactive') {
    const loading = await this.loadingController.create({
      message: 'Updating user status...'
    });
    await loading.present();

    try {
      await this.adminService.updateUserStatus(userId, status);
      
      const userIndex = this.allUsers.findIndex(user => user.id === userId);
      if (userIndex !== -1) {
        this.allUsers[userIndex].status = status;
        this.applyFilters();
      }

      this.showToast(`User ${status === 'active' ? 'activated' : 'deactivated'} successfully`, 'success');
      
    } catch (error) {
      console.error('Error updating user status:', error);
      this.showToast('Error updating user status', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  // UI Methods
  async viewUserDetails(user: User) {
    this.selectedUserDetail = user;
    this.showUserModal = true;
  }

  closeUserModal() {
    this.showUserModal = false;
    this.selectedUserDetail = null;
  }

  toggleFilters() {
    this.showFilters = !this.showFilters;
  }

  // Filter Management
  hasActiveFilters(): boolean {
    return this.searchTerm !== '' || 
           this.selectedRole !== 'all' ||
           this.selectedRegion !== 'all' || 
           this.selectedProvince !== 'all' || 
           this.selectedMunicipality !== 'all' || 
           this.selectedBarangay !== 'all' ||
           this.statusFilter !== 'all' || 
           this.dateFilter !== 'all';
  }

  clearRoleFilter() {
    this.selectedRole = 'all';
    this.onFilterChange();
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
    this.selectedRole = 'all';
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
    this.loadUsers();
  }

  // Utility Methods
  private getUserColor(fullName: string): string {
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
      '#FF9F43', '#10AC84', '#EE5A24', '#0984E3', '#6C5CE7'
    ];
    const colorIndex = fullName.charCodeAt(0) % colors.length;
    return colors[colorIndex];
  }

  private getUserInitials(fullName: string): string {
    if (!fullName) return '??';
    
    const words = fullName.trim().split(' ');
    if (words.length === 1) {
      return words[0].substring(0, 2).toUpperCase();
    } else {
      const firstInitial = words[0].charAt(0).toUpperCase();
      const lastInitial = words[words.length - 1].charAt(0).toUpperCase();
      return firstInitial + lastInitial;
    }
  }

  private buildUserAddress(userData: any): string {
    const addressParts = [];
    if (userData.sitio_purok) addressParts.push(userData.sitio_purok);
    if (userData.barangay) addressParts.push(userData.barangay);
    if (userData.municipality) addressParts.push(userData.municipality);
    if (userData.province) addressParts.push(userData.province);
    if (userData.region) addressParts.push(userData.region);
    
    return addressParts.join(', ') || 'Address not specified';
  }

  getRoleBadgeColor(role: string): string {
    switch (role) {
      case 'StoreOwner': return 'primary';
      case 'Employee': return 'tertiary';
      case 'Customer': return 'success';
      default: return 'medium';
    }
  }

  getRoleLabel(role: string): string {
    switch (role) {
      case 'StoreOwner': return 'Store Owner';
      case 'Employee': return 'Employee';
      case 'Customer': return 'Customer';
      default: return role;
    }
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