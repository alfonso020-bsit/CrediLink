// debt-customer-registration.service.ts
import { Injectable } from '@angular/core';
import { Firestore, collection, doc, setDoc, query, where, getDocs, Timestamp } from '@angular/fire/firestore';
import { AuthService, User } from './auth.service';
import { LocationService } from './location.service';

export interface DebtCustomerRegistrationData {
  full_name: string;
  phone_number: string;
  email?: string;
  municipality: string;
  barangay: string;
  sitio_purok?: string;
  username?: string; // ADD THIS
  password?: string; // ADD THIS
}
// ADD THIS NEW INTERFACE FOR DEBT SALE DATA
export interface DebtSaleData {
  id: string;
  total: number;
  paymentMethod: 'debt';
  customerName: string;
  customerPhone: string;
  dueDate: Date; // ADD THIS
  status: 'pending' | 'paid' | 'overdue';
  receipt_image: string;
  created_at: any;
  store_owner_id: string;
  employee_id: string;
  items: any[];
  initialPayment?: number;
  remainingBalance?: number;
  originalTotal?: number;

}

@Injectable({
  providedIn: 'root'
})
export class DebtCustomerRegistrationService {

  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private locationService: LocationService
  ) { }

 // ✅ ENHANCED: Register customer with complete location hierarchy validation AND custom credentials
async registerDebtCustomer(customerData: DebtCustomerRegistrationData): Promise<void> {
  try {
    const currentUser = this.authService.getCurrentUser();
    
    if (!currentUser) {
      throw new Error('User not authenticated');
    }

    console.log('🔍 DEBUG: Starting customer registration for:', customerData.full_name);

    // Get store owner's complete location information
    const storeOwnerLocation = await this.getStoreOwnerCompleteLocation();
    
    if (!storeOwnerLocation) {
      throw new Error('Store owner location information not available. Please ensure store owner has set their province in their profile.');
    }

    console.log('📍 DEBUG: Store owner location:', storeOwnerLocation);

    const { storeOwnerId, province, region, regionCode } = storeOwnerLocation;

    // ✅ VALIDATE: Check if selected municipality belongs to store owner's province
    const isValidMunicipality = this.validateMunicipalityBelongsToProvince(
      customerData.municipality, 
      province, 
      regionCode
    );
    
    if (!isValidMunicipality) {
      throw new Error(`Selected municipality "${customerData.municipality}" does not belong to ${province}. Please select a valid municipality from the list.`);
    }

    // ✅ VALIDATE: Check if selected barangay belongs to selected municipality
    const isValidBarangay = this.validateBarangayBelongsToMunicipality(
      customerData.barangay,
      customerData.municipality,
      province,
      regionCode
    );

    if (!isValidBarangay) {
      throw new Error(`Selected barangay "${customerData.barangay}" does not belong to ${customerData.municipality}. Please select a valid barangay from the list.`);
    }

    // ✅ ENHANCED: Handle username - custom or auto-generated
    let username: string;
    const cleanPhone = customerData.phone_number.replace(/\D/g, '');
    
    if (customerData.username && customerData.username.trim() !== '') {
      // Use custom username
      username = customerData.username.trim().toLowerCase();
      console.log('👤 Using custom username:', username);
    } else {
      // Auto-generate from phone number
      username = `cust_${cleanPhone}`.toLowerCase();
      console.log('👤 Using auto-generated username:', username);
    }

    // ✅ ENHANCED: Handle password - custom or default
    let password: string;
    if (customerData.password && customerData.password.trim() !== '') {
      // Use custom password
      password = customerData.password.trim();
      
      // Validate password strength (optional)
      if (password.length < 4) {
        throw new Error('Password must be at least 4 characters long');
      }
      console.log('🔐 Using custom password');
    } else {
      // Use default password
      password = 'default123';
      console.log('🔐 Using default password');
    }

    // Check if username exists
    const usernameExists = await this.authService.checkUsernameExists(username);
    if (usernameExists) {
      throw new Error(`Username "${username}" already exists. Please choose a different username.`);
    }

    // Check if email already exists if provided
    if (customerData.email && customerData.email.trim() !== '') {
      const emailExists = await this.authService.checkEmailExists(customerData.email);
      if (emailExists) {
        throw new Error('Email already exists');
      }
    }

    const usersRef = collection(this.firestore, 'all_users');
    const newUserRef = doc(usersRef);
    
    // ✅ COMPLETE customer data with ALL location fields matching your User interface
    const newUser: User = {
      id: newUserRef.id,
      username: username,
      password_hash: this.authService['hashPassword'](password), // Use custom or default password
      full_name: customerData.full_name.trim(),
      email: customerData.email?.trim() || '',
      phone_number: customerData.phone_number.trim(),
      // ✅ AUTO-SET from store owner's location (same as your register page)
      region: region,
      province: province,
      // ✅ From form selection (validated to belong to store owner's province)
      municipality: customerData.municipality,
      barangay: customerData.barangay,
      sitio_purok: customerData.sitio_purok?.trim() || '',
      role: 'Customer',
      status: 'active',
      store_owner_id: storeOwnerId, // Link to store owner
      created_at: Timestamp.now(),
      updated_at: Timestamp.now()
    };

    await setDoc(newUserRef, newUser);
    
    console.log('✅ Debt customer registered successfully:', {
      customer: customerData.full_name,
      username: username,
      storeOwner: storeOwnerId,
      completeAddress: `${customerData.barangay}, ${customerData.municipality}, ${province}, ${region}`,
      phone: customerData.phone_number,
      hasCustomPassword: !!customerData.password
    });
    
  } catch (error) {
    console.error('❌ Debt customer registration error:', error);
    throw error;
  }
}

  // ✅ UPDATED: Get complete store owner location with region code
  private async getStoreOwnerCompleteLocation(): Promise<{
    storeOwnerId: string;
    province: string;
    region: string;
    regionCode: string;
  } | null> {
    try {
      const currentUser = this.authService.getCurrentUser();
      
      if (!currentUser) {
        console.log('❌ DEBUG: No current user found');
        return null;
      }

      let storeOwnerId: string;
      let storeOwner: User;

      // ALWAYS get the store owner's location, even for employees
      if (currentUser.role === 'Employee' && currentUser.store_owner_id) {
        console.log('🔍 DEBUG: User is employee, fetching store owner...');
        storeOwnerId = currentUser.store_owner_id;
        const storeOwnerData = await this.authService.getStoreOwnerById(storeOwnerId);
        
        if (!storeOwnerData) {
          console.log('❌ DEBUG: Store owner not found for employee');
          return null;
        }
        storeOwner = storeOwnerData;
      } else if (currentUser.role === 'StoreOwner') {
        console.log('🔍 DEBUG: User is store owner, using own location');
        storeOwnerId = currentUser.id!;
        storeOwner = currentUser;
      } else {
        console.log('❌ DEBUG: User role not supported or missing store_owner_id');
        return null;
      }

      console.log('🔍 DEBUG: Store owner data:', {
        id: storeOwner.id,
        province: storeOwner.province,
        region: storeOwner.region
      });

      // Validate store owner has complete location data
      if (!storeOwner.province || typeof storeOwner.province !== 'string') {
        console.log('❌ DEBUG: Store owner province is not set or invalid');
        return null;
      }

      // Get region information from location service
      const regionInfo = this.locationService.getRegionByProvince(storeOwner.province);
      if (!regionInfo) {
        console.log('❌ DEBUG: Could not find region for province:', storeOwner.province);
        return null;
      }

      // Use store owner's region if available, otherwise use from location service
      const region = storeOwner.region || regionInfo.regionName;

      return {
        storeOwnerId,
        province: storeOwner.province,
        region: region,
        regionCode: regionInfo.regionCode
      };

    } catch (error) {
      console.error('❌ DEBUG: Error getting store owner complete location:', error);
      return null;
    }
  }

  // ✅ NEW: Validate municipality belongs to store owner's province
  private validateMunicipalityBelongsToProvince(
    municipality: string, 
    province: string, 
    regionCode: string
  ): boolean {
    if (!municipality || !province || !regionCode) {
      console.log('❌ DEBUG: Missing location data for validation');
      return false;
    }

    const municipalities = this.locationService.getMunicipalitiesByProvince(regionCode, province);
    const isValid = municipalities.includes(municipality);
    
    console.log('🔍 DEBUG: Municipality validation:', {
      municipality,
      province,
      regionCode,
      isValid,
      availableMunicipalities: municipalities.length
    });

    return isValid;
  }

  // ✅ NEW: Validate barangay belongs to selected municipality
  private validateBarangayBelongsToMunicipality(
    barangay: string,
    municipality: string,
    province: string,
    regionCode: string
  ): boolean {
    if (!barangay || !municipality || !province || !regionCode) {
      console.log('❌ DEBUG: Missing location data for barangay validation');
      return false;
    }

    const barangays = this.locationService.getBarangaysByMunicipality(regionCode, province, municipality);
    const isValid = barangays.includes(barangay);
    
    console.log('🔍 DEBUG: Barangay validation:', {
      barangay,
      municipality,
      province,
      regionCode,
      isValid,
      availableBarangays: barangays.length
    });

    return isValid;
  }

  // ✅ UPDATED: Get store owner's location info for the form
  async getStoreOwnerLocationInfo(): Promise<{
    province: string;
    region: string;
    municipalities: string[];
  } | null> {
    try {
      console.log('🔍 DEBUG: Starting getStoreOwnerLocationInfo');
      
      const completeLocation = await this.getStoreOwnerCompleteLocation();
      
      if (!completeLocation) {
        console.log('❌ DEBUG: Could not get complete location info');
        return null;
      }

      const { province, region, regionCode } = completeLocation;

      console.log('🔍 DEBUG: Getting municipalities for:', {
        province,
        region,
        regionCode
      });

      // Get municipalities for the province
      const municipalities = this.locationService.getMunicipalitiesByProvince(regionCode, province);
      
      console.log('🔍 DEBUG: Municipalities found:', municipalities?.length || 0);

      const result = {
        province: province,
        region: region,
        municipalities: municipalities || []
      };

      console.log('✅ DEBUG: Location info result:', result);
      return result;

    } catch (error) {
      console.error('❌ DEBUG: Error getting store owner location info:', error);
      return null;
    }
  }

  // ✅ UPDATED: Get barangays for selected municipality with better error handling
  getBarangays(municipality: string, storeOwnerProvince: string): string[] {
    if (!municipality || !storeOwnerProvince) {
      console.log('❌ DEBUG: Missing municipality or province for barangay lookup');
      return [];
    }
    
    const regionInfo = this.locationService.getRegionByProvince(storeOwnerProvince);
    if (!regionInfo) {
      console.log('❌ DEBUG: Could not find region for province:', storeOwnerProvince);
      return [];
    }

    const barangays = this.locationService.getBarangaysByMunicipality(
      regionInfo.regionCode,
      storeOwnerProvince,
      municipality
    );

    console.log('🔍 DEBUG: Barangays loaded:', {
      municipality,
      province: storeOwnerProvince,
      regionCode: regionInfo.regionCode,
      barangaysCount: barangays.length
    });

    return barangays;
  }

  // ✅ NEW: Helper method to validate if store owner has location set
  async validateStoreOwnerLocation(): Promise<boolean> {
    const location = await this.getStoreOwnerCompleteLocation();
    return location !== null;
  }

  // ✅ NEW: Get complete address summary for display
  getCompleteAddressSummary(municipality: string, barangay: string, sitioPurok?: string): string {
    const storeOwnerLocation = this.getStoreOwnerCompleteLocationSync();
    if (!storeOwnerLocation) return '';

    let address = `${barangay}, ${municipality}, ${storeOwnerLocation.province}, ${storeOwnerLocation.region}`;
    
    if (sitioPurok) {
      address = `${sitioPurok}, ${address}`;
    }

    return address;
  }

  // ✅ NEW: Synchronous version for UI methods
  private getStoreOwnerCompleteLocationSync(): { province: string; region: string } | null {
    try {
      const currentUser = this.authService.getCurrentUser();
      if (!currentUser) return null;

      let storeOwner: User;

      if (currentUser.role === 'Employee' && currentUser.store_owner_id) {
        // For synchronous access in UI, we use current user data
        // In a real app, you might want to cache the store owner data
        storeOwner = currentUser;
      } else if (currentUser.role === 'StoreOwner') {
        storeOwner = currentUser;
      } else {
        return null;
      }

      if (!storeOwner.province) return null;

      const regionInfo = this.locationService.getRegionByProvince(storeOwner.province);
      if (!regionInfo) return null;

      return {
        province: storeOwner.province,
        region: storeOwner.region || regionInfo.regionName
      };
    } catch (error) {
      console.error('Error getting store owner location sync:', error);
      return null;
    }
  }
}