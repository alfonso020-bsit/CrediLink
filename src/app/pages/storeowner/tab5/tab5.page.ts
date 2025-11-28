import { Component, OnInit, ViewChild } from '@angular/core';
import { NgForm } from '@angular/forms';
import { AlertController, ToastController, LoadingController, ModalController } from '@ionic/angular';
import { HttpClient } from '@angular/common/http';
import { AuthService, User } from 'src/app/services/auth.service';
import { EmployeeService, EmployeeProfile } from 'src/app/services/employee.service';
import { Firestore, collection, doc, setDoc, updateDoc, query, where, getDocs, Timestamp, orderBy } from '@angular/fire/firestore';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';
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

interface EmployeeWithProfile extends User {
  profile?: EmployeeProfile;
  profileImageError?: boolean;
  latestSalary?: number; // Add latest salary from salary_records
}

interface EmployeeReportData {
  employee: EmployeeWithProfile;
  profile: EmployeeProfile | null;
}

interface SalaryRecord {
  id?: string;
  employee_id: string;
  employee_name: string;
  amount: number;
  period_start: Date;
  period_end: Date;
  status: 'paid'; // Always paid as per policy
  payment_date: Date;
  notes?: string;
  created_at: any;
}

interface MonthlySalarySummary {
  month: string;
  year: number;
  totalSalary: number;
  employeeCount: number;
}

@Component({
  selector: 'app-tab5',
  templateUrl: './tab5.page.html',
  styleUrls: ['./tab5.page.scss'],
  standalone: false,
})
export class Tab5Page implements OnInit {
  @ViewChild('employeeForm') employeeForm!: NgForm;
  
  employees: EmployeeWithProfile[] = [];
  isLoading = false;
  isLoadingEmployees = false;
  showPassword = false;

  // Form mode - 'create' or 'edit'
  formMode: 'create' | 'edit' = 'create';
  editingEmployeeId: string | null = null;

  // Employee Details Modal
  showEmployeeDetails = false;
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

  // Report and Salary Management Properties
  showReportModal = false;
  showSalaryModal = false;
  activeReportView: 'analytics' = 'analytics'; // Only analytics view now
  
  // Salary Management
  salaryRecords: SalaryRecord[] = [];
  newSalaryRecord: Partial<SalaryRecord> = {
    amount: 0,
    period_start: new Date(),
    period_end: new Date(),
    status: 'paid', // Always paid as per policy
    payment_date: new Date()
  };
  
  // Analytics Data
  totalEmployees: number = 0;
  activeEmployees: number = 0;
  inactiveEmployees: number = 0;
  totalMonthlySalary: number = 0;
  monthlySalaryHistory: MonthlySalarySummary[] = [];

  // Add these properties to your class
  searchTerm: string = '';
  statusFilter: string = 'all';
  filteredEmployees: EmployeeWithProfile[] = [];

  // Add this property to control form visibility
  showEmployeeForm: boolean = false;

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private employeeService: EmployeeService,
    private alertController: AlertController,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private modalController: ModalController,
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

  // // Employee Management Methods
  // async loadEmployees() {
  //   this.isLoadingEmployees = true;
  //   try {
  //     const currentUser = this.authService.getCurrentUser();
  //     if (!currentUser?.id) {
  //       throw new Error('User not authenticated');
  //     }

  //     // Get employees with their profiles
  //     const employeesWithProfiles = await this.employeeService.getStoreEmployeesWithProfiles(currentUser.id);
      
  //     // FIX: Cast to EmployeeWithProfile[]
  //     this.employees = employeesWithProfiles.map(emp => ({
  //       ...emp.user,
  //       profile: emp.profile
  //     })) as EmployeeWithProfile[];
      
  //   } catch (error: any) {
  //     await this.showToast(error.message, 'danger');
  //   } finally {
  //     this.isLoadingEmployees = false;
  //   }
  // }

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
      
      // Close the form after successful creation
      this.closeEmployeeForm();
      
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
      
      // Reset form but don't close (stay in edit mode until user cancels)
      this.resetForm();
    }
    
    // Refresh list
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

  // Employee Management Methods - UPDATED
  async loadEmployees() {
    this.isLoadingEmployees = true;
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser?.id) {
        throw new Error('User not authenticated');
      }

      // Get employees with their profiles
      const employeesWithProfiles = await this.employeeService.getStoreEmployeesWithProfiles(currentUser.id);
      
      // Cast to EmployeeWithProfile[] and load latest salaries
      this.employees = await Promise.all(
        employeesWithProfiles.map(async (emp) => {
          const employeeWithProfile = {
            ...emp.user,
            profile: emp.profile
          } as EmployeeWithProfile;
          
          // Load latest salary from salary_records
          employeeWithProfile.latestSalary = await this.getLatestEmployeeSalary(emp.user.id!);
          
          return employeeWithProfile;
        })
      );
      
      // Update analytics data
      this.updateAnalyticsData();
      this.applyFilters();
      
    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      this.isLoadingEmployees = false;
    }
  }
  // Filter methods
applyFilters() {
  let filtered = this.employees;

  // Apply search filter
  if (this.searchTerm) {
    const term = this.searchTerm.toLowerCase();
    filtered = filtered.filter(employee =>
      employee.full_name.toLowerCase().includes(term) ||
      employee.position?.toLowerCase().includes(term) ||
      employee.username.toLowerCase().includes(term) ||
      employee.email?.toLowerCase().includes(term) ||
      employee.phone_number?.includes(term)
    );
  }

  // Apply status filter
  if (this.statusFilter !== 'all') {
    filtered = filtered.filter(employee => employee.status === this.statusFilter);
  }

  this.filteredEmployees = filtered;
}

onSearchInput() {
  this.applyFilters();
}

onFilterChange() {
  this.applyFilters();
}

hasActiveFilters(): boolean {
  return this.searchTerm !== '' || this.statusFilter !== 'all';
}

clearSearch() {
  this.searchTerm = '';
  this.applyFilters();
}

clearStatusFilter() {
  this.statusFilter = 'all';
  this.applyFilters();
}

clearAllFilters() {
  this.searchTerm = '';
  this.statusFilter = 'all';
  this.applyFilters();
}

// Alternative simpler approach if you don't need the complex query:
async getLatestEmployeeSalary(employeeId: string): Promise<number> {
  try {
    const salaryRef = collection(this.firestore, 'salary_records');
    
    // Simple query - just get all paid salaries for this employee
    const q = query(
      salaryRef,
      where('employee_id', '==', employeeId),
      where('status', '==', 'paid')
    );
    
    const querySnapshot = await getDocs(q);
    
    if (!querySnapshot.empty) {
      // Sort by period_end on client side
      const records = querySnapshot.docs
        .map(doc => {
          const data = doc.data();
          return {
            amount: data['amount'] || 0,
            period_end: data['period_end']?.toDate() || new Date(0)
          };
        })
        .sort((a, b) => b.period_end.getTime() - a.period_end.getTime());
      
      return records[0]?.amount || 0;
    }
    
    return 0;
  } catch (error) {
    console.error('Error loading latest salary:', error);
    return 0;
  }
}

  // Update analytics data
  updateAnalyticsData() {
    this.totalEmployees = this.employees.length;
    this.activeEmployees = this.employees.filter(e => e.status === 'active').length;
    this.inactiveEmployees = this.employees.filter(e => e.status === 'inactive').length;
    
    // Calculate total monthly salary from latest salaries
    this.totalMonthlySalary = this.employees.reduce((sum, emp) => {
      return sum + (emp.latestSalary || 0);
    }, 0);
  }

async loadSalaryRecords() {
  try {
    const currentUser = this.authService.getCurrentUser();
    if (!currentUser?.id) return;

    const salaryRef = collection(this.firestore, 'salary_records');
    
    // Use a simpler query that doesn't require composite index
    const q = query(
      salaryRef,
      where('store_owner_id', '==', currentUser.id)
    );
    
    const querySnapshot = await getDocs(q);
    this.salaryRecords = querySnapshot.docs.map(doc => {
      const data = doc.data();
      return {
        id: doc.id,
        employee_id: data['employee_id'],
        employee_name: data['employee_name'],
        amount: data['amount'],
        period_start: data['period_start']?.toDate(),
        period_end: data['period_end']?.toDate(),
        status: data['status'],
        payment_date: data['payment_date']?.toDate(),
        notes: data['notes'],
        created_at: data['created_at']
      };
    });

    // Sort by period_end on client side
    this.salaryRecords.sort((a, b) => 
      new Date(b.period_end).getTime() - new Date(a.period_end).getTime()
    );

  } catch (error) {
    console.error('Error loading salary records:', error);
  }
}

  async addSalaryRecord() {
    if (!this.newSalaryRecord.employee_id || !this.newSalaryRecord.amount || this.newSalaryRecord.amount <= 0) {
      this.showToast('Please select an employee and enter a valid amount', 'warning');
      return;
    }

    const loading = await this.loadingController.create({
      message: 'Adding salary record...'
    });
    await loading.present();

    try {
      const currentUser = this.authService.getCurrentUser();
      const selectedEmployee = this.employees.find(e => e.id === this.newSalaryRecord.employee_id);

      if (!selectedEmployee) {
        throw new Error('Selected employee not found');
      }

      const salaryData = {
        employee_id: this.newSalaryRecord.employee_id,
        employee_name: selectedEmployee.full_name,
        amount: this.newSalaryRecord.amount,
        period_start: Timestamp.fromDate(new Date(this.newSalaryRecord.period_start!)),
        period_end: Timestamp.fromDate(new Date(this.newSalaryRecord.period_end!)),
        status: 'paid', // Always paid as per policy
        payment_date: Timestamp.now(),
        notes: this.newSalaryRecord.notes || '',
        store_owner_id: currentUser?.id,
        created_at: Timestamp.now(),
        updated_at: Timestamp.now()
      };

      const salaryRef = collection(this.firestore, 'salary_records');
      await setDoc(doc(salaryRef), salaryData);

      this.showToast('Salary record added successfully!', 'success');
      this.closeSalaryModal();
      await this.loadSalaryRecords();
      
      // Reload employees to update latest salaries
      await this.loadEmployees();

    } catch (error) {
      console.error('Error adding salary record:', error);
      this.showToast('Error adding salary record', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

// REPORT GENERATION - UPDATED (Only active employees)
async generateEmployeeReport() {
  const loading = await this.loadingController.create({
    message: 'Generating Employee Report...'
  });
  await loading.present();

  try {
    const { jsPDF } = await import('jspdf');
    const autoTable = await import('jspdf-autotable');
    
    const doc = new jsPDF();
    const currentUser = this.authService.getCurrentUser();
    const storeName = currentUser?.store_name || 'Store';
    const currentDate = new Date().toLocaleDateString('en-PH');
    const currentTime = new Date().toLocaleTimeString();

    // Filter only active employees for the report
    const activeEmployees = this.employees.filter(emp => emp.status === 'active');

    // Title Section
    doc.setFontSize(20);
    doc.setTextColor(41, 128, 185);
    doc.text('EMPLOYEE MASTER REPORT', 105, 20, { align: 'center' });
    
    doc.setFontSize(12);
    doc.setTextColor(100, 100, 100);
    doc.text(`${storeName}`, 105, 30, { align: 'center' });
    doc.text(`Generated on: ${currentDate} at ${currentTime}`, 105, 36, { align: 'center' });

    let finalY = 50;

    // Analytics Summary Section
    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('EMPLOYEE ANALYTICS SUMMARY', 20, finalY);
    finalY += 10;

    const summaryData = [
      ['Total Employees', this.totalEmployees.toString()],
      ['Active Employees', this.activeEmployees.toString()],
      ['Inactive Employees', this.inactiveEmployees.toString()],
      ['Total Monthly Salary', `PHP ${this.totalMonthlySalary.toLocaleString()}`],
      ['Active Employees in Report', activeEmployees.length.toString()],
      ['Report Date', currentDate]
    ];

    autoTable.default(doc, {
      startY: finalY,
      head: [['Metric', 'Value']],
      body: summaryData,
      theme: 'grid',
      headStyles: { fillColor: [66, 139, 202] },
      styles: { fontSize: 11, cellPadding: 3 }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;

    // Generate individual employee reports - ONLY ACTIVE EMPLOYEES
    for (const employee of activeEmployees) {
      if (finalY > 200) {
        doc.addPage();
        finalY = 20;
      }

      // Employee Header
      doc.setFontSize(16);
      doc.setTextColor(34, 139, 34);
      doc.text(`EMPLOYEE: ${employee.full_name.toUpperCase()}`, 20, finalY);
      finalY += 10;

      // Employee Basic Information
      const basicInfo = [
        ['Full Name', employee.full_name],
        ['Username', employee.username],
        ['Position', employee.position || 'N/A'],
        ['Status', employee.status.toUpperCase()],
        ['Email', employee.email || 'N/A'],
        ['Phone', employee.phone_number || 'N/A'],
        ['Latest Salary', `PHP ${(employee.latestSalary || 0).toLocaleString()}`],
        ['Address', this.formatEmployeeAddress(employee)]
      ];

      autoTable.default(doc, {
        startY: finalY,
        head: [['Field', 'Details']],
        body: basicInfo,
        theme: 'grid',
        headStyles: { fillColor: [34, 139, 34] },
        styles: { fontSize: 10, cellPadding: 3 }
      });

      finalY = (doc as any).lastAutoTable.finalY + 10;

      // Employee Profile Information (if available)
      if (employee.profile) {
        const profileInfo = [];
        
        if (employee.profile.hire_date) {
          profileInfo.push(['Hire Date', this.formatFirestoreDate(employee.profile.hire_date)]);
        }
        if (employee.profile.facebook_url) {
          profileInfo.push(['Facebook', employee.profile.facebook_url]);
        }
        if (employee.profile.instagram_url) {
          profileInfo.push(['Instagram', employee.profile.instagram_url]);
        }
        if (employee.profile.emergency_contact?.name) {
          profileInfo.push(['Emergency Contact', employee.profile.emergency_contact.name]);
          profileInfo.push(['Relationship', employee.profile.emergency_contact.relationship || 'N/A']);
          profileInfo.push(['Contact Phone', employee.profile.emergency_contact.phone_number || 'N/A']);
        }

        if (profileInfo.length > 0) {
          autoTable.default(doc, {
            startY: finalY,
            head: [['Profile Information', '']],
            body: profileInfo,
            theme: 'grid',
            headStyles: { fillColor: [128, 0, 128] },
            styles: { fontSize: 9, cellPadding: 2 }
          });

          finalY = (doc as any).lastAutoTable.finalY + 15;
        }
      }

      // Add separation between employees
      finalY += 10;
    }

    // If no active employees, show message
    if (activeEmployees.length === 0) {
      if (finalY > 200) {
        doc.addPage();
        finalY = 20;
      }
      
      doc.setFontSize(14);
      doc.setTextColor(255, 0, 0);
      doc.text('NO ACTIVE EMPLOYEES FOUND', 105, finalY, { align: 'center' });
    }

    // Footer
    doc.setFontSize(8);
    doc.setTextColor(150, 150, 150);
    const footerText = `Employee Report - ${storeName} - Confidential - Active Employees Only`;
    doc.text(footerText, 105, doc.internal.pageSize.height - 10, { align: 'center' });

    // Save PDF
    const safeStoreName = storeName.replace(/[^a-zA-Z0-9]/g, '-');
    const fileName = `employee-report-active-${safeStoreName}-${new Date().toISOString().split('T')[0]}.pdf`;
    doc.save(fileName);

    this.showToast(`Active employee report downloaded successfully! (${activeEmployees.length} employees)`, 'success');

  } catch (error) {
    console.error('Error generating employee report:', error);
    this.showToast('Error generating employee report', 'danger');
  } finally {
    await loading.dismiss();
  }
}

  // MODAL METHODS - SIMPLIFIED
  openReportModal() {
    this.showReportModal = true;
    this.activeReportView = 'analytics';
  }

  closeReportModal() {
    this.showReportModal = false;
  }

  setReportView(view: 'analytics') {
    this.activeReportView = view;
  }

  openSalaryModal() {
    this.showSalaryModal = true;
    this.loadSalaryRecords();
  }

  closeSalaryModal() {
    this.showSalaryModal = false;
    this.newSalaryRecord = {
      amount: 0,
      period_start: new Date(),
      period_end: new Date(),
      status: 'paid',
      payment_date: new Date()
    };
  }

  // Remove hire date calendar methods entirely

  // ... (keep all other existing methods the same)

  // UTILITY METHODS
  private formatEmployeeAddress(employee: EmployeeWithProfile): string {
    const addressParts = [
      employee.sitio_purok,
      employee.barangay,
      employee.municipality,
      employee.province
    ].filter(part => part && part.trim() !== '');
    
    const fullAddress = addressParts.join(', ');
    return this.truncateText(fullAddress, 35);
  }

  private truncateText(text: string, maxLength: number): string {
    if (!text || text === 'undefined' || text === 'null') return 'N/A';
    
    const cleanText = String(text).trim();
    if (cleanText.length <= maxLength) return cleanText;
    
    return cleanText.substring(0, maxLength - 3) + '...';
  }

  formatFirestoreDate(date: any): string {
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

  safeToDate(date: any): Date | null {
    if (!date) return null;
    try {
      if (date.toDate && typeof date.toDate === 'function') {
        return date.toDate();
      }
      return new Date(date);
    } catch (error) {
      console.error('Error converting date:', error);
      return null;
    }
  }

  async showToast(message: string, color: string) {
    const toast = await this.toastController.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }

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

  getSalaryStatusColor(status: string): string {
    return 'success'; // Always success since status is always 'paid'
  }

  // Method to show the employee form
openEmployeeForm() {
  this.showEmployeeForm = true;
  this.formMode = 'create';
  this.resetForm();
}

// Method to close the employee form
closeEmployeeForm() {
  this.showEmployeeForm = false;
  this.resetForm();
}

// Update the resetForm method to also hide the form
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
}