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
  getDocs 
} from '@angular/fire/firestore';
import { Timestamp } from '@angular/fire/firestore';

export interface StoreProfile {
  id?: string;
  store_owner_id: string; // Foreign key to all_users
  store_image?: string; // base64 string
  store_description?: string;
  store_address?: string; // Specific store address (could be different from user address)
  business_permit_number?: string;
  established_date?: any; // Timestamp
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
  created_at: any;
  updated_at: any;
}

@Injectable({
  providedIn: 'root'
})
export class StoreService {

  constructor(private firestore: Firestore) { }

  // Create or update store profile
  async saveStoreProfile(storeData: Partial<StoreProfile>): Promise<void> {
    try {
      const currentUser = JSON.parse(localStorage.getItem('currentUser') || '{}');
      
      if (!currentUser || currentUser.role !== 'StoreOwner') {
        throw new Error('Only store owners can manage store profiles');
      }

      const storesRef = collection(this.firestore, 'store_profiles');
      
      // Check if store profile already exists
      const q = query(storesRef, where('store_owner_id', '==', currentUser.id));
      const querySnapshot = await getDocs(q);
      
      let storeDocRef;
      
      if (querySnapshot.empty) {
        // Create new store profile
        storeDocRef = doc(storesRef);
        const newStore: StoreProfile = {
          id: storeDocRef.id,
          store_owner_id: currentUser.id,
          store_image: storeData.store_image || '',
          store_description: storeData.store_description || '',
          store_address: storeData.store_address || '',
          business_permit_number: storeData.business_permit_number || '',
          established_date: storeData.established_date || Timestamp.now(),
          operating_hours: storeData.operating_hours || {
            open: '08:00',
            close: '17:00',
            days: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
          },
          social_media: storeData.social_media || {},
          created_at: Timestamp.now(),
          updated_at: Timestamp.now()
        };
        
        await setDoc(storeDocRef, newStore);
      } else {
        // Update existing store profile
        storeDocRef = doc(this.firestore, 'store_profiles', querySnapshot.docs[0].id);
        const updateData = {
          ...storeData,
          updated_at: Timestamp.now()
        };
        await updateDoc(storeDocRef, updateData);
      }
      
    } catch (error) {
      console.error('Error saving store profile:', error);
      throw error;
    }
  }

  // Get store profile by owner ID
  async getStoreProfile(storeOwnerId?: string): Promise<StoreProfile | null> {
    try {
      const currentUser = JSON.parse(localStorage.getItem('currentUser') || '{}');
      const ownerId = storeOwnerId || currentUser.id;
      
      if (!ownerId) {
        return null;
      }

      const storesRef = collection(this.firestore, 'store_profiles');
      const q = query(storesRef, where('store_owner_id', '==', ownerId));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return null;
      }
      
      return querySnapshot.docs[0].data() as StoreProfile;
    } catch (error) {
      console.error('Error getting store profile:', error);
      return null;
    }
  }

  // Delete store image
  async deleteStoreImage(): Promise<void> {
    try {
      const currentUser = JSON.parse(localStorage.getItem('currentUser') || '{}');
      
      if (!currentUser || currentUser.role !== 'StoreOwner') {
        throw new Error('Only store owners can manage store profiles');
      }

      const storeProfile = await this.getStoreProfile();
      if (!storeProfile?.id) {
        throw new Error('Store profile not found');
      }

      const storeDocRef = doc(this.firestore, 'store_profiles', storeProfile.id);
      await updateDoc(storeDocRef, {
        store_image: '',
        updated_at: Timestamp.now()
      });
      
    } catch (error) {
      console.error('Error deleting store image:', error);
      throw error;
    }
  }

  // Generate avatar from store name - FIXED to handle undefined
  generateStoreAvatar(storeName: string | undefined): string {
    if (!storeName) {
      // Return default avatar if no store name
      return `
        <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect width="100" height="100" fill="#666666" rx="10"/>
          <text x="50" y="60" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="40" font-weight="bold">?</text>
        </svg>
      `;
    }
    
    const firstLetter = storeName.charAt(0).toUpperCase();
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    
    const colorIndex = storeName.charCodeAt(0) % colors.length;
    const backgroundColor = colors[colorIndex];
    
    return `
      <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="${backgroundColor}" rx="10"/>
        <text x="50" y="60" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="40" font-weight="bold">${firstLetter}</text>
      </svg>
    `;
  }

  // Convert SVG to base64
  svgToBase64(svgString: string): string {
    return 'data:image/svg+xml;base64,' + btoa(svgString);
  }

  // Get complete store information for employees
async getEmployeeStoreProfile(): Promise<{ storeInfo: any; storeProfile: StoreProfile | null }> {
  try {
    const currentUser = JSON.parse(localStorage.getItem('currentUser') || '{}');
    
    if (!currentUser || currentUser.role !== 'Employee' || !currentUser.store_owner_id) {
      throw new Error('Employee not linked to a store');
    }

    // Get store owner information from all_users
    const storeOwner = await this.getStoreOwnerById(currentUser.store_owner_id);
    if (!storeOwner) {
      throw new Error('Store owner not found');
    }

    // Get store profile from store_profiles
    const storeProfile = await this.getStoreProfile(currentUser.store_owner_id);

    return {
      storeInfo: {
        store_name: storeOwner.store_name,
        owner_name: storeOwner.full_name,
        email: storeOwner.email,
        phone_number: storeOwner.phone_number,
        province: storeOwner.province,
        municipality: storeOwner.municipality,
        barangay: storeOwner.barangay,
        sitio_purok: storeOwner.sitio_purok
      },
      storeProfile: storeProfile
    };
  } catch (error) {
    console.error('Error getting employee store profile:', error);
    throw error;
  }
}

// Helper method to get store owner by ID
async getStoreOwnerById(storeOwnerId: string): Promise<any> {
  try {
    const userRef = doc(this.firestore, 'all_users', storeOwnerId);
    const userDoc = await getDoc(userRef);
    
    if (!userDoc.exists()) {
      return null;
    }
    
    return userDoc.data();
  } catch (error) {
    console.error('Error getting store owner:', error);
    return null;
  }
}
// Add these methods to your existing store.service.ts

// Get store information for receipts
async getStoreInfoForReceipt(): Promise<any> {
  try {
    const currentUser = JSON.parse(localStorage.getItem('currentUser') || '{}');
    
    if (!currentUser) {
      return this.getDefaultStoreInfo();
    }

    let storeOwnerId: string;

    if (currentUser.role === 'StoreOwner') {
      storeOwnerId = currentUser.id;
    } else if (currentUser.role === 'Employee' && currentUser.store_owner_id) {
      storeOwnerId = currentUser.store_owner_id;
    } else {
      return this.getDefaultStoreInfo();
    }

    // Get store owner info
    const storeOwner = await this.getStoreOwnerById(storeOwnerId);
    if (!storeOwner) {
      return this.getDefaultStoreInfo();
    }

    // Get store profile
    const storeProfile = await this.getStoreProfile(storeOwnerId);

    // Build complete store info
    return {
      name: storeOwner.store_name || `${storeOwner.full_name}'s Store`,
      address: this.buildAddress(storeOwner),
      phone: storeOwner.phone_number,
      email: storeOwner.email,
      logo_url: storeProfile?.store_image,
      receipt_header: storeProfile?.store_description || 'Retail Receipt',
      receipt_footer: 'Thank you for your purchase!',
      currency_symbol: '₱',
      tax_rate: 0
    };

  } catch (error) {
    console.error('Error getting store info for receipt:', error);
    return this.getDefaultStoreInfo();
  }
}

// Build address from user data
private buildAddress(user: any): string {
  const addressParts = [];
  if (user.sitio_purok) addressParts.push(user.sitio_purok);
  if (user.barangay) addressParts.push(user.barangay);
  if (user.municipality) addressParts.push(user.municipality);
  if (user.province) addressParts.push(user.province);
  
  return addressParts.join(', ') || 'Address not specified';
}

// Default store info as fallback
private getDefaultStoreInfo(): any {
  return {
    name: 'Retail Store',
    address: 'Address not specified',
    receipt_header: 'Retail Receipt',
    receipt_footer: 'Thank you for your purchase!',
    currency_symbol: '₱',
    tax_rate: 0
  };
}
// Get complete store information for employees
}

