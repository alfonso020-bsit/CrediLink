import { Component, OnInit } from '@angular/core';
import { Router } from '@angular/router';
import { ToastController, LoadingController } from '@ionic/angular';
import { AuthService, User } from '../../../services/auth.service';
import { StoreService, StoreProfile } from '../../../services/store.service';

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
  showSettings: boolean = false;
  
  // Store data for form (only additional fields)
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
    private toastController: ToastController,
    private loadingController: LoadingController,
    private router: Router // Add Router for navigation
  ) { }

  async ngOnInit() {
    await this.loadUserData();
    await this.loadStoreProfile();
  }

  async loadUserData() {
    this.currentUser = this.authService.getCurrentUser();
    
    // Generate avatars from store name - handle undefined case
    const storeName = this.currentUser?.store_name || 'Store';
    const svgAvatar = this.storeService.generateStoreAvatar(storeName);
    this.storeAvatar = this.storeService.svgToBase64(svgAvatar);
    this.storeAvatarLarge = this.storeService.svgToBase64(svgAvatar);
  }

  async loadStoreProfile() {
    this.storeProfile = await this.storeService.getStoreProfile();
    
    // Initialize form data with existing store profile
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

  toggleSettings() {
    this.showSettings = !this.showSettings;
    // Reset image preview when closing settings
    if (!this.showSettings) {
      this.imagePreview = null;
      this.selectedFile = null;
    }
  }

  onFileSelected(event: any) {
    const file = event.target.files[0];
    if (file) {
      // Check file size (max 2MB)
      if (file.size > 2 * 1024 * 1024) {
        this.showToast('Image size should be less than 2MB', 'warning');
        return;
      }

      this.selectedFile = file;
      
      // Create preview
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
      // Convert image to base64 if selected
      if (this.imagePreview && this.imagePreview.startsWith('data:image')) {
        this.storeData.store_image = this.imagePreview;
      }

      await this.storeService.saveStoreProfile(this.storeData);
      
      await loading.dismiss();
      await this.showToast('Store profile saved successfully!', 'success');
      
      // Reload store profile and close settings
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
      
      // Reload store profile
      await this.loadStoreProfile();
    } catch (error: any) {
      await this.showToast(error.message || 'Error removing store image', 'danger');
    }
  }

  // Logout method
  async logout() {
    const loading = await this.loadingController.create({
      message: 'Logging out...',
      duration: 1500
    });
    
    await loading.present();
    
    // Use setTimeout to show the loading message
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