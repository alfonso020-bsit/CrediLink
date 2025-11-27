import { Component, OnInit, ViewChild } from '@angular/core';
import { NgForm } from '@angular/forms';
import { AlertController, ToastController, LoadingController } from '@ionic/angular';
import { HttpClient } from '@angular/common/http';
import { AuthService, User } from 'src/app/services/auth.service';
import { EmployeeService, EmployeeProfile } from 'src/app/services/employee.service';
import { Firestore, collection, doc, setDoc, updateDoc, query, where, getDocs, Timestamp } from '@angular/fire/firestore';
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

// Add this interface at the top with other interfaces
interface EmployeeWithProfile extends User {
  profile?: EmployeeProfile;
  profileImageError?: boolean;
}

@Component({
  selector: 'app-tab5',
  templateUrl: './tab5.page.html',
  styleUrls: ['./tab5.page.scss'],
  standalone: false,
})
export class Tab5Page implements OnInit {
  @ViewChild('employeeForm') employeeForm!: NgForm;
  
  // FIX: Change from User[] to EmployeeWithProfile[]
  employees: EmployeeWithProfile[] = [];
  isLoading = false;
  isLoadingEmployees = false;
  showPassword = false;

  // Form mode - 'create' or 'edit'
  formMode: 'create' | 'edit' = 'create';
  editingEmployeeId: string | null = null;

  // Employee Details Modal
  showEmployeeDetails = false;
  // FIX: Change from User to EmployeeWithProfile
  selectedEmployee: EmployeeWithProfile | null = null;
  selectedEmployeeProfile: EmployeeProfile | null = null;

  // Address Selection Variables
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
    private firestore: Firestore,
    private authService: AuthService,
    private employeeService: EmployeeService,
    private alertController: AlertController,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private http: HttpClient
  ) { }

  async ngOnInit() {
    await this.loadLocationData();
    this.loadEmployees();
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

  // Employee Details Modal
  // Employee Details Modal
async viewEmployee(employee: EmployeeWithProfile) {
  const loading = await this.loadingController.create({
    message: 'Loading employee details...'
  });
  
  await loading.present();

  try {
    this.selectedEmployee = employee;
    
    // Get employee profile data from employee_profiles collection
    this.selectedEmployeeProfile = await this.employeeService.getEmployeeProfile(employee.id!);
    
    console.log('Employee Profile Loaded:', this.selectedEmployeeProfile); // Debug log
    
    this.showEmployeeDetails = true;
    
  } catch (error: any) {
    console.error('Error loading employee details:', error);
    await this.showToast('Error loading employee details', 'danger');
  } finally {
    await loading.dismiss();
  }
}

  closeEmployeeDetails() {
    this.showEmployeeDetails = false;
    this.selectedEmployee = null;
    this.selectedEmployeeProfile = null;
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

  isAddressComplete(): boolean {
    return !!(this.selectedRegion && this.selectedProvince && this.selectedMunicipality && this.selectedBarangay);
  }

  // Enhanced form validation
  isFormValid(): boolean {
    if (!this.employeeForm?.valid) return false;
    if (!this.isAddressComplete()) return false;
    
    // Additional validation for create mode
    if (this.formMode === 'create') {
      const formData = this.employeeForm.value;
      if (formData.password !== formData.confirmPassword) {
        return false;
      }
    }
    
    return true;
  }

  togglePassword() {
    this.showPassword = !this.showPassword;
  }

  // Reset form to create mode
  resetForm() {
    this.formMode = 'create';
    this.editingEmployeeId = null;
    if (this.employeeForm) {
      this.employeeForm.resetForm();
    }
    this.selectedRegion = '';
    this.selectedProvince = '';
    this.selectedMunicipality = '';
    this.selectedBarangay = '';
    this.showPassword = false;
  }

  // Employee Management Methods
  async loadEmployees() {
    this.isLoadingEmployees = true;
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser?.id) {
        throw new Error('User not authenticated');
      }

      // Get employees with their profiles
      const employeesWithProfiles = await this.employeeService.getStoreEmployeesWithProfiles(currentUser.id);
      
      // FIX: Cast to EmployeeWithProfile[]
      this.employees = employeesWithProfiles.map(emp => ({
        ...emp.user,
        profile: emp.profile
      })) as EmployeeWithProfile[];
      
    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      this.isLoadingEmployees = false;
    }
  }

  refreshEmployees() {
    this.loadEmployees();
  }

  async onSubmit(form: NgForm) {
    if (!this.isFormValid()) {
      await this.showToast('Please fill all required fields correctly', 'warning');
      return;
    }

    const formData = form.value;

    // Check if passwords match (only for create mode)
    if (this.formMode === 'create' && formData.password !== formData.confirmPassword) {
      await this.showToast('Passwords do not match', 'warning');
      return;
    }

    this.isLoading = true;

    try {
      if (this.formMode === 'create') {
        // CREATE new employee - WITH POSITION
        const employeeData = {
          username: formData.username,
          password: formData.password,
          full_name: formData.full_name,
          email: formData.email || '',
          phone_number: formData.phone_number || '',
          position: formData.position || '',
          province: this.selectedProvince,
          municipality: this.selectedMunicipality,
          barangay: this.selectedBarangay,
          sitio_purok: formData.sitio_purok || ''
        };

        await this.authService.createStoreEmployee(employeeData);
        await this.showToast('Employee created successfully!', 'success');
        
      } else if (this.formMode === 'edit' && this.editingEmployeeId) {
        // UPDATE existing employee - WITH POSITION
        const updateData = {
          full_name: formData.full_name,
          email: formData.email || '',
          phone_number: formData.phone_number || '',
          position: formData.position || '',
          province: this.selectedProvince,
          municipality: this.selectedMunicipality,
          barangay: this.selectedBarangay,
          sitio_purok: formData.sitio_purok || ''
        };

        await this.authService.updateStoreEmployee(this.editingEmployeeId, updateData);
        await this.showToast('Employee updated successfully!', 'success');
      }
      
      // Reset form and refresh list
      this.resetForm();
      await this.loadEmployees();
      
    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      this.isLoading = false;
    }
  }

  // Edit employee - FIX: Accept EmployeeWithProfile
  async editEmployee(employee: EmployeeWithProfile) {
    try {
      const loading = await this.loadingController.create({
        message: 'Loading employee data...'
      });
      await loading.present();

      // Get fresh employee data
      const freshEmployee = await this.authService.getStoreEmployeeById(employee.id!);
      
      if (!freshEmployee) {
        throw new Error('Employee not found');
      }

      // Set form to edit mode
      this.formMode = 'edit';
      this.editingEmployeeId = employee.id!;

      // Fill form with employee data
      setTimeout(() => {
        if (this.employeeForm && this.employeeForm.form) {
          this.employeeForm.form.patchValue({
            username: freshEmployee.username,
            full_name: freshEmployee.full_name,
            email: freshEmployee.email || '',
            phone_number: freshEmployee.phone_number || '',
            position: freshEmployee.position || '',
            sitio_purok: freshEmployee.sitio_purok || ''
          });
        }

        // Set address fields
        this.selectedRegion = this.findRegionByProvince(freshEmployee.province);
        this.loadProvincesForRegion(this.selectedRegion);
        this.selectedProvince = freshEmployee.province;
        this.loadMunicipalitiesForProvince(this.selectedProvince);
        this.selectedMunicipality = freshEmployee.municipality;
        this.loadBarangaysForMunicipality(this.selectedMunicipality);
        this.selectedBarangay = freshEmployee.barangay;

        loading.dismiss();
        
        // Scroll to form
        const formElement = document.querySelector('ion-card');
        if (formElement) {
          formElement.scrollIntoView({ behavior: 'smooth' });
        }
      }, 100);

    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    }
  }

  // Helper methods to load address data for editing
  private findRegionByProvince(province: string): string {
    if (!this.phLocations) return '';
    
    for (const regionCode in this.phLocations) {
      const region = this.phLocations[regionCode];
      if (region.province_list && region.province_list[province]) {
        return regionCode;
      }
    }
    return '';
  }

  private loadProvincesForRegion(regionCode: string) {
    if (this.phLocations && this.phLocations[regionCode]?.province_list) {
      this.provinces = Object.keys(this.phLocations[regionCode].province_list);
    } else {
      this.provinces = [];
    }
  }

  private loadMunicipalitiesForProvince(province: string) {
    if (this.selectedRegion && province && this.phLocations && 
        this.phLocations[this.selectedRegion]?.province_list[province]?.municipality_list) {
      this.municipalities = Object.keys(
        this.phLocations[this.selectedRegion].province_list[province].municipality_list
      );
    } else {
      this.municipalities = [];
    }
  }

  private loadBarangaysForMunicipality(municipality: string) {
    if (this.selectedRegion && this.selectedProvince && municipality && this.phLocations && 
        this.phLocations[this.selectedRegion]?.province_list[this.selectedProvince]?.municipality_list[municipality]) {
      this.barangays = this.phLocations[this.selectedRegion]
        .province_list[this.selectedProvince]
        .municipality_list[municipality].barangay_list;
    } else {
      this.barangays = [];
    }
  }

  // FIX: Accept EmployeeWithProfile
  async toggleEmployeeStatus(employee: EmployeeWithProfile) {
    const newStatus = employee.status === 'active' ? 'inactive' : 'active';
    
    const alert = await this.alertController.create({
      header: 'Confirm',
      message: `Are you sure you want to ${newStatus === 'active' ? 'activate' : 'deactivate'} ${employee.full_name}?`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Confirm',
          handler: async () => {
            await this.updateEmployeeStatus(employee.id!, newStatus);
          }
        }
      ]
    });

    await alert.present();
  }

  async updateEmployeeStatus(employeeId: string, status: 'active' | 'inactive') {
    const loading = await this.loadingController.create({
      message: 'Updating status...'
    });
    
    await loading.present();

    try {
      await this.authService.updateUserStatus(employeeId, status);
      await this.showToast(`Employee ${status === 'active' ? 'activated' : 'deactivated'} successfully`, 'success');
      await this.loadEmployees();
    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  // FIX: Accept EmployeeWithProfile
  async deleteEmployee(employee: EmployeeWithProfile) {
    const alert = await this.alertController.create({
      header: 'Delete Employee',
      message: `Are you sure you want to delete ${employee.full_name}? This action cannot be undone.`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Delete',
          role: 'destructive',
          handler: async () => {
            await this.confirmDeleteEmployee(employee.id!);
          }
        }
      ]
    });

    await alert.present();
  }

  async confirmDeleteEmployee(employeeId: string) {
    const loading = await this.loadingController.create({
      message: 'Deleting employee...'
    });
    
    await loading.present();

    try {
      await this.authService.deleteStoreEmployee(employeeId);
      await this.showToast('Employee deleted successfully', 'success');
      await this.loadEmployees();
      
      // If we were editing this employee, reset the form
      if (this.editingEmployeeId === employeeId) {
        this.resetForm();
      }
    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      await loading.dismiss();
    }
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

  // Avatar helper methods
  getInitials(fullName: string): string {
    if (!fullName) return '?';
    return fullName
      .split(' ')
      .map(name => name.charAt(0))
      .join('')
      .toUpperCase()
      .substring(0, 2);
  }

  getAvatarColor(fullName: string): string {
    if (!fullName) return '#666666';
    
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9',
      '#F8C471', '#82E0AA', '#F1948A', '#85C1E9', '#D7BDE2'
    ];
    
    const colorIndex = fullName.charCodeAt(0) % colors.length;
    return colors[colorIndex];
  }
}