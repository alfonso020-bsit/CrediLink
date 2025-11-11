import { Component, OnInit } from '@angular/core';
import { NgForm } from '@angular/forms';
import { Router } from '@angular/router';
import { ToastController, LoadingController } from '@ionic/angular';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../../services/auth.service';
import { lastValueFrom } from 'rxjs';

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
  selector: 'app-register',
  templateUrl: './register.page.html',
  styleUrls: ['./register.page.scss'],
  standalone: false,
})
export class RegisterPage implements OnInit {
  showPassword = false;
  selectedRole: 'Customer' | 'StoreOwner' = 'Customer';
  
  // Location data
  regions: Region[] = [];
  provinces: string[] = [];
  municipalities: string[] = [];
  barangays: string[] = [];
  
  // Selected values
  selectedRegion: string = '';
  selectedProvince: string = '';
  selectedMunicipality: string = '';
  selectedBarangay: string = '';
  
  // Search functionality
  searchRegion = '';
  searchProvince = '';
  searchMunicipality = '';
  searchBarangay = '';
  
  // Modal states
  showRegionModal = false;
  showProvinceModal = false;
  showMunicipalityModal = false;
  showBarangayModal = false;
  
  // JSON data
  phLocations: LocationData | null = null;
  isLoadingLocations = true;

  constructor(
    private router: Router,
    private toastCtrl: ToastController,
    private loadingCtrl: LoadingController,
    private authService: AuthService,
    private http: HttpClient
  ) { }

  async ngOnInit() {
    await this.loadLocationData();
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
      }));
    }
  }

  // Get region name from code
  getRegionName(regionCode: string): string {
    if (!regionCode || !this.phLocations) return '';
    return this.phLocations[regionCode]?.region_name || '';
  }

  // Search functionality
  get filteredRegions(): Region[] {
    if (!this.searchRegion) return this.regions;
    return this.regions.filter(region => 
      region.name.toLowerCase().includes(this.searchRegion.toLowerCase())
    );
  }

  get filteredProvinces(): string[] {
    if (!this.searchProvince) return this.provinces;
    return this.provinces.filter(province => 
      province.toLowerCase().includes(this.searchProvince.toLowerCase())
    );
  }

  get filteredMunicipalities(): string[] {
    if (!this.searchMunicipality) return this.municipalities;
    return this.municipalities.filter(municipality => 
      municipality.toLowerCase().includes(this.searchMunicipality.toLowerCase())
    );
  }

  get filteredBarangays(): string[] {
    if (!this.searchBarangay) return this.barangays;
    return this.barangays.filter(barangay => 
      barangay.toLowerCase().includes(this.searchBarangay.toLowerCase())
    );
  }

  // Search handlers
  onRegionSearch() {
    // Search is handled by the filteredRegions getter
  }

  onProvinceSearch() {
    // Search is handled by the filteredProvinces getter
  }

  onMunicipalitySearch() {
    // Search is handled by the filteredMunicipalities getter
  }

  onBarangaySearch() {
    // Search is handled by the filteredBarangays getter
  }

  // Modal open handlers
  openRegionSelection() {
    this.searchRegion = '';
    this.showRegionModal = true;
  }

  openProvinceSelection() {
    if (!this.selectedRegion) {
      this.showToast('Please select a region first', 'warning');
      return;
    }
    this.searchProvince = '';
    this.showProvinceModal = true;
  }

  openMunicipalitySelection() {
    if (!this.selectedProvince) {
      this.showToast('Please select a province first', 'warning');
      return;
    }
    this.searchMunicipality = '';
    this.showMunicipalityModal = true;
  }

  openBarangaySelection() {
    if (!this.selectedMunicipality) {
      this.showToast('Please select a municipality first', 'warning');
      return;
    }
    this.searchBarangay = '';
    this.showBarangayModal = true;
  }

  // Modal close handlers
  closeRegionSelection() {
    this.showRegionModal = false;
  }

  closeProvinceSelection() {
    this.showProvinceModal = false;
  }

  closeMunicipalitySelection() {
    this.showMunicipalityModal = false;
  }

  closeBarangaySelection() {
    this.showBarangayModal = false;
  }

  // Selection handlers
  selectRegion(regionCode: string) {
    this.selectedRegion = regionCode;
    this.selectedProvince = '';
    this.selectedMunicipality = '';
    this.selectedBarangay = '';
    
    // Load provinces for selected region
    if (this.phLocations && this.phLocations[regionCode]?.province_list) {
      this.provinces = Object.keys(this.phLocations[regionCode].province_list);
    } else {
      this.provinces = [];
    }
    this.municipalities = [];
    this.barangays = [];
    
    this.closeRegionSelection();
  }

  selectProvince(provinceName: string) {
    this.selectedProvince = provinceName;
    this.selectedMunicipality = '';
    this.selectedBarangay = '';
    
    // Load municipalities for selected province
    if (this.selectedRegion && provinceName && this.phLocations && 
        this.phLocations[this.selectedRegion]?.province_list[provinceName]?.municipality_list) {
      this.municipalities = Object.keys(
        this.phLocations[this.selectedRegion].province_list[provinceName].municipality_list
      );
    } else {
      this.municipalities = [];
    }
    this.barangays = [];
    
    this.closeProvinceSelection();
  }

  selectMunicipality(municipalityName: string) {
    this.selectedMunicipality = municipalityName;
    this.selectedBarangay = '';
    
    // Load barangays for selected municipality
    if (this.selectedRegion && this.selectedProvince && municipalityName && this.phLocations && 
        this.phLocations[this.selectedRegion]?.province_list[this.selectedProvince]?.municipality_list[municipalityName]) {
      this.barangays = this.phLocations[this.selectedRegion]
        .province_list[this.selectedProvince]
        .municipality_list[municipalityName].barangay_list;
    } else {
      this.barangays = [];
    }
    
    this.closeMunicipalitySelection();
  }

  selectBarangay(barangay: string) {
    this.selectedBarangay = barangay;
    this.closeBarangaySelection();
  }

  selectRole(role: 'Customer' | 'StoreOwner') {
    this.selectedRole = role;
  }

  togglePassword() {
    this.showPassword = !this.showPassword;
  }

  async onRegister(form: NgForm) {
    if (form.invalid) {
      await this.showToast('Please fill in all required fields correctly', 'danger');
      return;
    }

    // Validate location selection
    if (!this.selectedRegion || !this.selectedProvince || !this.selectedMunicipality || !this.selectedBarangay) {
      await this.showToast('Please complete your address information', 'danger');
      return;
    }

    const { password, confirmPassword } = form.value;

    // Check if passwords match
    if (password !== confirmPassword) {
      await this.showToast('Passwords do not match', 'danger');
      return;
    }

    const loading = await this.loadingCtrl.create({
      message: `Creating your ${this.selectedRole === 'Customer' ? 'customer' : 'store owner'} account...`,
    });
    await loading.present();

    try {
      const { 
        username, 
        fullName, 
        email, 
        phoneNumber,
        sitioPurok 
      } = form.value;
      
      const userData = {
        username: username.trim(),
        password: password,
        full_name: fullName.trim(),
        email: email?.trim() || '',
        phone_number: phoneNumber?.trim() || '',
        province: this.selectedProvince,
        municipality: this.selectedMunicipality,
        barangay: this.selectedBarangay,
        sitio_purok: sitioPurok?.trim() || ''
      };

      // Register based on selected role
      if (this.selectedRole === 'Customer') {
        await this.authService.registerCustomer(userData);
      } else {
        await this.authService.registerStoreOwner(userData);
      }
      
      await loading.dismiss();
      await this.showToast(
        `${this.selectedRole === 'Customer' ? 'Customer' : 'Store owner'} account created successfully! Please login.`, 
        'success'
      );
      
      // Navigate to login page
      this.router.navigate(['/login']);
      
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast(error.message || 'Registration failed', 'danger');
    }
  }

  goToLogin() {
    this.router.navigate(['/login']);
  }

  private async showToast(message: string, color: string) {
    const toast = await this.toastCtrl.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }
}