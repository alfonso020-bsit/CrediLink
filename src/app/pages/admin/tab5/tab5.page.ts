import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, updateDoc, Timestamp } from '@angular/fire/firestore';
import { Router } from '@angular/router';

interface AdminProfile {
  id: number;
  username: string;
  full_name: string;
  email: string;
  phone_number: string;
  role: string;
  status: string;
  created_at: any;
  updated_at: any;
}

@Component({
  selector: 'app-tab5',
  templateUrl: './tab5.page.html',
  styleUrls: ['./tab5.page.scss'],
  standalone: false,
})
export class Tab5Page implements OnInit {
  adminProfile: AdminProfile | null = null;
  isLoading: boolean = false;
  
  // Edit mode
  isEditingProfile: boolean = false;
  editedProfile: Partial<AdminProfile> = {};

  constructor(
    private firestore: Firestore,
    private router: Router,
    private alertController: AlertController,
    private loadingController: LoadingController,
    private toastController: ToastController
  ) { }

  async ngOnInit() {
    await this.loadAdminProfile();
  }

  async loadAdminProfile() {
    this.isLoading = true;
    try {
      const usersRef = collection(this.firestore, 'all_users');
      const adminQuery = query(usersRef, where('role', '==', 'Admin'));
      const querySnapshot = await getDocs(adminQuery);

      if (!querySnapshot.empty) {
        const adminDoc = querySnapshot.docs[0];
        const data = adminDoc.data();
        
        this.adminProfile = {
          id: data['id'] || 0,
          username: data['username'] || '',
          full_name: data['full_name'] || '',
          email: data['email'] || '',
          phone_number: data['phone_number']?.toString() || '',
          role: data['role'] || 'Admin',
          status: data['status'] || 'active',
          created_at: data['created_at'] || Timestamp.now(),
          updated_at: data['updated_at'] || Timestamp.now()
        };

        this.editedProfile = {
          full_name: this.adminProfile.full_name,
          email: this.adminProfile.email,
          phone_number: this.adminProfile.phone_number
        };
      }
    } catch (error) {
      console.error('Error loading admin profile:', error);
      await this.showToast('Error loading profile', 'danger');
    } finally {
      this.isLoading = false;
    }
  }

  toggleEditProfile() {
    if (this.isEditingProfile && this.adminProfile) {
      this.editedProfile = {
        full_name: this.adminProfile.full_name,
        email: this.adminProfile.email,
        phone_number: this.adminProfile.phone_number
      };
    }
    this.isEditingProfile = !this.isEditingProfile;
  }

  async saveProfile() {
    const alert = await this.alertController.create({
      header: 'Confirm Changes',
      message: 'Are you sure you want to update your profile?',
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Save',
          handler: async () => {
            await this.updateProfile();
          }
        }
      ]
    });
    await alert.present();
  }

  async updateProfile() {
    const loading = await this.loadingController.create({
      message: 'Updating profile...'
    });
    await loading.present();

    try {
      const usersRef = collection(this.firestore, 'all_users');
      const adminQuery = query(usersRef, where('role', '==', 'Admin'));
      const querySnapshot = await getDocs(adminQuery);

      if (!querySnapshot.empty) {
        const adminDocRef = querySnapshot.docs[0].ref;
        
        await updateDoc(adminDocRef, {
          full_name: this.editedProfile.full_name,
          email: this.editedProfile.email,
          phone_number: this.editedProfile.phone_number,
          updated_at: Timestamp.now()
        });

        if (this.adminProfile) {
          this.adminProfile.full_name = this.editedProfile.full_name || this.adminProfile.full_name;
          this.adminProfile.email = this.editedProfile.email || this.adminProfile.email;
          this.adminProfile.phone_number = this.editedProfile.phone_number || this.adminProfile.phone_number;
          this.adminProfile.updated_at = Timestamp.now();
        }

        this.isEditingProfile = false;
        await this.showToast('Profile updated successfully', 'success');
      }
    } catch (error) {
      console.error('Error updating profile:', error);
      await this.showToast('Error updating profile', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  formatDate(date: any): string {
    if (!date) return 'N/A';
    try {
      const jsDate = date.toDate ? date.toDate() : new Date(date);
      return jsDate.toLocaleDateString('en-PH', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  }

  getInitials(name: string): string {
    if (!name) return 'AD';
    const words = name.split(' ');
    if (words.length >= 2) {
      return words[0].charAt(0) + words[1].charAt(0);
    }
    return name.substring(0, 2).toUpperCase();
  }

  async logout() {
    const alert = await this.alertController.create({
      header: 'Logout',
      message: 'Are you sure you want to logout?',
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Logout',
          handler: async () => {
            try {
              localStorage.clear();
              this.router.navigate(['/login']);
              await this.showToast('Logged out successfully', 'success');
            } catch (error) {
              console.error('Error logging out:', error);
              await this.showToast('Error logging out', 'danger');
            }
          }
        }
      ]
    });
    await alert.present();
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