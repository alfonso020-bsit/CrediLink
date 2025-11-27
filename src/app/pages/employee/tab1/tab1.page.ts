import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ToastController, LoadingController } from '@ionic/angular';
import { AuthService, User } from '../../../services/auth.service';
import { StoreService, StoreProfile } from '../../../services/store.service';
import { EmployeeService, EmployeeProfile } from '../../../services/employee.service';

@Component({
  selector: 'app-employee-tab1',
  templateUrl: './tab1.page.html',
  styleUrls: ['./tab1.page.scss'],
  standalone: false,
})
export class Tab1Page implements OnInit {
  currentUser: User | null = null;
  storeInfo: any = null;
  storeProfile: StoreProfile | null = null;
  employeeProfile: EmployeeProfile | null = null;
  storeAvatar: string = '';
  
  // CHANGE THESE: Use initials instead of SVG
  employeeInitials: string = '';
  employeeInitialsLarge: string = '';
  employeeAvatarColor: string = '';
  employeeAvatarColorLarge: string = '';
  
  showSettings: boolean = false;
  showStoreInfo: boolean = false;
  
  employeeData: any = {
    phone_number: '',
    facebook_url: '',
    emergency_contact: {
      name: '',
      relationship: '',
      phone_number: ''
    }
  };
  
  selectedEmployeeFile: File | null = null;
  employeeImagePreview: string | null = null;

  constructor(
    private authService: AuthService,
    private storeService: StoreService,
    private employeeService: EmployeeService,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private router: Router
  ) {}

  async ngOnInit() {
    console.log('🔄 Tab1 ngOnInit');
    await this.loadUserData();
  }

  async ionViewWillEnter() {
    console.log('🔄 Tab1 ionViewWillEnter - Reloading data');
    await this.loadUserData();
  }

  async loadUserData() {
    this.currentUser = this.authService.getCurrentUser();
    
    console.log('👤 Current user in Tab1:', this.currentUser?.full_name);
    console.log('🔑 User ID:', this.currentUser?.id);
    
    if (!this.currentUser || this.currentUser.role !== 'Employee') {
      console.error('❌ Access denied - not an employee');
      this.showToast('Access denied. Employee role required.', 'danger');
      this.router.navigate(['/home']);
      return;
    }

    console.log('✅ Employee authenticated:', this.currentUser.full_name);
    
    // Clear previous data first
    this.storeInfo = null;
    this.storeProfile = null;
    this.employeeProfile = null;
    
    // Load data for the current user
    await this.loadStoreInformation();
    await this.loadEmployeeProfile();
  }

 async loadEmployeeProfile() {
  try {
    console.log('🔄 Loading employee profile for:', this.currentUser?.full_name);
    
    if (!this.currentUser) {
      console.log('❌ No current user for employee profile');
      return;
    }

    this.employeeProfile = await this.employeeService.getEmployeeProfile();
    
    console.log('📋 Employee profile loaded:', this.employeeProfile ? 'Yes' : 'No');
    
    // DEBUG: Check if position exists in different sources
    console.log('💼 Position from employee profile:', this.employeeProfile?.position);
    console.log('💼 Position from current user:', this.currentUser.position);
    
    // If employee profile doesn't have position but current user does, add it
    if (this.employeeProfile && !this.employeeProfile.position && this.currentUser.position) {
      this.employeeProfile.position = this.currentUser.position;
      console.log('✅ Added position from current user to employee profile');
    }

    if (this.employeeProfile) {
      console.log('👤 Profile belongs to employee ID:', this.employeeProfile.employee_id);
      console.log('💼 Final position value:', this.employeeProfile.position);
    }

    // Initialize employee form data
    this.employeeData = {
      phone_number: this.employeeProfile?.phone_number || this.currentUser?.phone_number || '',
      facebook_url: this.employeeProfile?.facebook_url || '',
      emergency_contact: this.employeeProfile?.emergency_contact || {
        name: '',
        relationship: '',
        phone_number: ''
      }
    };

    console.log('📝 Employee form data initialized:', this.employeeData);

    // Generate employee initials and color
    if (this.currentUser?.full_name) {
      this.employeeInitials = this.getInitials(this.currentUser.full_name);
      this.employeeInitialsLarge = this.employeeInitials;
      this.employeeAvatarColor = this.getAvatarColor(this.currentUser.full_name);
      this.employeeAvatarColorLarge = this.employeeAvatarColor;
      
      console.log('🖼️ Employee initials generated:', this.employeeInitials);
      console.log('🎨 Avatar color:', this.employeeAvatarColor);
    }
  } catch (error) {
    console.error('❌ Error loading employee profile:', error);
  }
}

  // ADD THESE HELPER METHODS
  private getInitials(fullName: string): string {
    if (!fullName) return '?';
    
    const names = fullName.trim().split(' ');
    if (names.length === 1) {
      // Single name - take first 2 characters
      return names[0].substring(0, 2).toUpperCase();
    } else {
      // Multiple names - take first letter of first and last name
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

  // ... rest of your methods remain the same ...

  async loadStoreInformation() {
    if (!this.currentUser) {
      console.log('❌ No current user for store information');
      return;
    }

    const loading = await this.loadingController.create({
      message: 'Loading store information...',
    });
    await loading.present();

    try {
      const storeData = await this.storeService.getEmployeeStoreProfile();
      this.storeInfo = storeData.storeInfo;
      this.storeProfile = storeData.storeProfile;

      await loading.dismiss();
      console.log('✅ Store information loaded for:', this.currentUser.full_name);
      console.log('🏪 Store name:', this.storeInfo?.store_name);
      
    } catch (error: any) {
      await loading.dismiss();
      console.error('❌ Error loading store information:', error);
      this.showToast(error.message || 'Failed to load store information', 'danger');
    }
  }

  toggleSettings() {
    this.showSettings = !this.showSettings;
    this.showStoreInfo = false;
    if (!this.showSettings) {
      this.employeeImagePreview = null;
      this.selectedEmployeeFile = null;
    }
  }

  toggleStoreInfo() {
    this.showStoreInfo = !this.showStoreInfo;
    this.showSettings = false;
  }

  onEmployeeFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      if (file.size > 2 * 1024 * 1024) {
        this.showToast('Image size should be less than 2MB', 'warning');
        return;
      }

      this.selectedEmployeeFile = file;
      
      const reader = new FileReader();
      reader.onload = (e: any) => {
        this.employeeImagePreview = e.target.result;
      };
      reader.readAsDataURL(file);
    }
  }

  async saveEmployeeProfile() {
    const loading = await this.loadingController.create({
      message: 'Saving employee profile...',
    });
    await loading.present();

    try {
      const updateData: any = {
        phone_number: this.employeeData.phone_number,
        facebook_url: this.employeeData.facebook_url,
        emergency_contact: this.employeeData.emergency_contact
      };

      if (this.employeeImagePreview && this.employeeImagePreview.startsWith('data:image')) {
        updateData.profile_image = this.employeeImagePreview;
      }

      await this.employeeService.saveEmployeeProfile(updateData);
      
      await loading.dismiss();
      await this.showToast('Profile saved successfully!', 'success');
      
      await this.loadEmployeeProfile();
      this.showSettings = false;
      this.employeeImagePreview = null;
      this.selectedEmployeeFile = null;
      
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast(error.message || 'Error saving profile', 'danger');
    }
  }

  async deleteEmployeeProfileImage() {
    try {
      await this.employeeService.deleteEmployeeProfileImage();
      this.employeeImagePreview = null;
      await this.showToast('Profile picture removed!', 'success');
      
      await this.loadEmployeeProfile();
    } catch (error: any) {
      await this.showToast(error.message || 'Error removing picture', 'danger');
    }
  }

// In your employee tabs component (if you have one)
async logout() {
  const loading = await this.loadingController.create({
    message: 'Logging out...',
  });
  
  await loading.present();
  
  // Clear all component data before logging out
  this.currentUser = null;
  this.storeInfo = null;
  this.storeProfile = null;
  this.employeeProfile = null;
  this.employeeData = {
    phone_number: '',
    facebook_url: '',
    emergency_contact: {
      name: '',
      relationship: '',
      phone_number: ''
    }
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
}