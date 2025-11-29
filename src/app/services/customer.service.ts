import { Injectable } from '@angular/core';
import { 
  Firestore, 
  collection, 
  doc, 
  setDoc, 
  getDoc, 
  updateDoc, 
  query,
  where,
  getDocs,
  Timestamp 
} from '@angular/fire/firestore';
import { AuthService, User } from './auth.service';

export interface CustomerProfile {
  id?: string;
  customer_id: string; // Foreign key to all_users document ID
  date_of_birth?: string;
  gender?: string;
  preferred_store?: string;
  profile_image?: string; // base64 string
  social_media?: {
    facebook?: string;
    instagram?: string;
  };
  preferred_contact_method?: string;
  receive_promotions?: boolean;
  receive_debt_reminders?: boolean;
  created_at: any;
  updated_at: any;
}

@Injectable({
  providedIn: 'root'
})
export class CustomerService {

  constructor(
    private firestore: Firestore,
    private authService: AuthService
  ) { }

  // Create or update customer profile
  async saveCustomerProfile(profileData: Partial<CustomerProfile>): Promise<void> {
    try {
      const currentUser = this.authService.getCurrentUser();
      
      if (!currentUser || currentUser.role !== 'Customer') {
        throw new Error('Only customers can manage their profiles');
      }

      if (!currentUser.id) {
        throw new Error('User ID not found');
      }

      const customerProfilesRef = collection(this.firestore, 'customer_profiles');
      
      // Check if customer profile already exists
      const q = query(customerProfilesRef, where('customer_id', '==', currentUser.id));
      const querySnapshot = await getDocs(q);
      
      let profileDocRef;
      
      if (querySnapshot.empty) {
        // Create new customer profile
        profileDocRef = doc(customerProfilesRef);
        const newProfile: CustomerProfile = {
          id: profileDocRef.id,
          customer_id: currentUser.id,
          date_of_birth: profileData.date_of_birth || '',
          gender: profileData.gender || '',
          preferred_store: profileData.preferred_store || '',
          profile_image: profileData.profile_image || '',
          social_media: profileData.social_media || {
            facebook: '',
            instagram: ''
          },
          preferred_contact_method: profileData.preferred_contact_method || 'sms',
          receive_promotions: profileData.receive_promotions !== false,
          receive_debt_reminders: profileData.receive_debt_reminders !== false,
          created_at: Timestamp.now(),
          updated_at: Timestamp.now()
        };
        
        await setDoc(profileDocRef, newProfile);
      } else {
        // Update existing customer profile
        profileDocRef = doc(this.firestore, 'customer_profiles', querySnapshot.docs[0].id);
        const updateData = {
          ...profileData,
          updated_at: Timestamp.now()
        };
        
        await updateDoc(profileDocRef, updateData);
      }
      
      console.log('✅ Customer profile saved successfully');
      
    } catch (error) {
      console.error('Error saving customer profile:', error);
      throw error;
    }
  }

  // Get customer profile by customer ID
  async getCustomerProfile(customerId?: string): Promise<CustomerProfile | null> {
    try {
      const currentUser = this.authService.getCurrentUser();
      const custId = customerId || currentUser?.id;
      
      if (!custId) {
        return null;
      }

      const customerProfilesRef = collection(this.firestore, 'customer_profiles');
      const q = query(customerProfilesRef, where('customer_id', '==', custId));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return null;
      }
      
      return querySnapshot.docs[0].data() as CustomerProfile;
    } catch (error) {
      console.error('Error getting customer profile:', error);
      return null;
    }
  }

  // Get complete customer info (combining all_users and customer_profiles)
  async getCompleteCustomerInfo(): Promise<{ userInfo: User; customerProfile: CustomerProfile | null }> {
    try {
      const currentUser = this.authService.getCurrentUser();
      
      if (!currentUser || currentUser.role !== 'Customer') {
        throw new Error('Only customers can access this information');
      }

      const customerProfile = await this.getCustomerProfile(currentUser.id);

      return {
        userInfo: currentUser,
        customerProfile: customerProfile
      };
    } catch (error) {
      console.error('Error getting complete customer info:', error);
      throw error;
    }
  }

  // Delete customer profile image
  async deleteCustomerProfileImage(): Promise<void> {
    try {
      const currentUser = this.authService.getCurrentUser();
      
      if (!currentUser || currentUser.role !== 'Customer') {
        throw new Error('Only customers can manage their profile');
      }

      const customerProfile = await this.getCustomerProfile();
      if (!customerProfile?.id) {
        throw new Error('Customer profile not found');
      }

      const profileDocRef = doc(this.firestore, 'customer_profiles', customerProfile.id);
      await updateDoc(profileDocRef, {
        profile_image: '',
        updated_at: Timestamp.now()
      });
      
    } catch (error) {
      console.error('Error deleting customer profile image:', error);
      throw error;
    }
  }

  // Generate SVG avatar for customer (like store owner)
  generateCustomerAvatar(name: string): string {
    const initials = this.getInitials(name);
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    const color = colors[name.charCodeAt(0) % colors.length];
    
    return `
      <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <circle cx="50" cy="50" r="50" fill="${color}"/>
        <text x="50" y="55" font-family="Arial, sans-serif" font-size="40" fill="white" text-anchor="middle" dominant-baseline="middle">${initials}</text>
      </svg>
    `;
  }

  // Convert SVG to base64 (like store owner)
  svgToBase64(svgString: string): string {
    return 'data:image/svg+xml;base64,' + btoa(svgString);
  }

  // Helper method to get initials
  private getInitials(fullName: string): string {
    if (!fullName) return '?';
    
    const names = fullName.trim().split(' ');
    if (names.length === 1) {
      return names[0].substring(0, 2).toUpperCase();
    } else {
      const firstInitial = names[0].charAt(0).toUpperCase();
      const lastInitial = names[names.length - 1].charAt(0).toUpperCase();
      return firstInitial + lastInitial;
    }
  }
}