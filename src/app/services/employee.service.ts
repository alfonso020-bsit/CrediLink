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

export interface EmployeeProfile {
  id?: string;
  employee_id: string; // Foreign key to all_users
  profile_image?: string; // base64 string
  facebook_url?: string;
  instagram_url?: string;
  phone_number?: string; // Can be different from all_users
  emergency_contact?: {
    name: string;
    relationship: string;
    phone_number: string;
  };
  position?: string;
  hire_date?: any; // Timestamp
  salary?: number;
  created_at: any;
  updated_at: any;
}

@Injectable({
  providedIn: 'root'
})
export class EmployeeService {

  constructor(
    private firestore: Firestore,
    private authService: AuthService
  ) { }

  // Create or update employee profile
 // Create or update employee profile
async saveEmployeeProfile(profileData: Partial<EmployeeProfile>): Promise<void> {
  try {
    const currentUser = this.authService.getCurrentUser();
    
    if (!currentUser || currentUser.role !== 'Employee') {
      throw new Error('Only employees can manage their profiles');
    }

    if (!currentUser.id) {
      throw new Error('User ID not found');
    }

    const employeeProfilesRef = collection(this.firestore, 'employee_profiles');
    
    // Check if employee profile already exists
    const q = query(employeeProfilesRef, where('employee_id', '==', currentUser.id));
    const querySnapshot = await getDocs(q);
    
    let profileDocRef;
    
    if (querySnapshot.empty) {
      // Create new employee profile
      profileDocRef = doc(employeeProfilesRef);
      const newProfile: EmployeeProfile = {
        id: profileDocRef.id,
        employee_id: currentUser.id,
        profile_image: profileData.profile_image || '',
        facebook_url: profileData.facebook_url || '',
        instagram_url: profileData.instagram_url || '',
        phone_number: profileData.phone_number || '',
        emergency_contact: profileData.emergency_contact || {
          name: '',
          relationship: '',
          phone_number: ''
        },
        // POSITION IS NOT SET HERE - it comes from all_users
        hire_date: profileData.hire_date || Timestamp.now(),
        salary: profileData.salary || 0,
        created_at: Timestamp.now(),
        updated_at: Timestamp.now()
      };
      
      await setDoc(profileDocRef, newProfile);
    } else {
      // Update existing employee profile - EXCLUDE POSITION
      profileDocRef = doc(this.firestore, 'employee_profiles', querySnapshot.docs[0].id);
      const updateData = {
        ...profileData,
        updated_at: Timestamp.now()
      };
      // Remove position if it somehow gets included
      delete updateData.position;
      await updateDoc(profileDocRef, updateData);
    }
    
    console.log('✅ Employee profile saved successfully');
    
  } catch (error) {
    console.error('Error saving employee profile:', error);
    throw error;
  }
}

  // Get employee profile by employee ID
  async getEmployeeProfile(employeeId?: string): Promise<EmployeeProfile | null> {
    try {
      const currentUser = this.authService.getCurrentUser();
      const empId = employeeId || currentUser?.id;
      
      if (!empId) {
        return null;
      }

      const employeeProfilesRef = collection(this.firestore, 'employee_profiles');
      const q = query(employeeProfilesRef, where('employee_id', '==', empId));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return null;
      }
      
      return querySnapshot.docs[0].data() as EmployeeProfile;
    } catch (error) {
      console.error('Error getting employee profile:', error);
      return null;
    }
  }

  // Get complete employee info (combining all_users and employee_profiles)
  async getCompleteEmployeeInfo(): Promise<{ userInfo: User; employeeProfile: EmployeeProfile | null }> {
    try {
      const currentUser = this.authService.getCurrentUser();
      
      if (!currentUser || currentUser.role !== 'Employee') {
        throw new Error('Only employees can access this information');
      }

      const employeeProfile = await this.getEmployeeProfile(currentUser.id);

      return {
        userInfo: currentUser,
        employeeProfile: employeeProfile
      };
    } catch (error) {
      console.error('Error getting complete employee info:', error);
      throw error;
    }
  }

  // Delete employee profile image
  async deleteEmployeeProfileImage(): Promise<void> {
    try {
      const currentUser = this.authService.getCurrentUser();
      
      if (!currentUser || currentUser.role !== 'Employee') {
        throw new Error('Only employees can manage their profile');
      }

      const employeeProfile = await this.getEmployeeProfile();
      if (!employeeProfile?.id) {
        throw new Error('Employee profile not found');
      }

      const profileDocRef = doc(this.firestore, 'employee_profiles', employeeProfile.id);
      await updateDoc(profileDocRef, {
        profile_image: '',
        updated_at: Timestamp.now()
      });
      
    } catch (error) {
      console.error('Error deleting employee profile image:', error);
      throw error;
    }
  }

  // Get employees for a store owner
  async getStoreEmployeesWithProfiles(storeOwnerId: string): Promise<{ user: User; profile: EmployeeProfile | null }[]> {
    try {
      // First get all employees for this store owner from all_users
      const usersRef = collection(this.firestore, 'all_users');
      const q = query(
        usersRef, 
        where('role', '==', 'Employee'),
        where('store_owner_id', '==', storeOwnerId)
      );
      
      const querySnapshot = await getDocs(q);
      
      const employees: { user: User; profile: EmployeeProfile | null }[] = [];
      
      // For each employee, get their profile from employee_profiles
      for (const doc of querySnapshot.docs) {
        const user = doc.data() as User;
        const profile = await this.getEmployeeProfile(user.id);
        
        employees.push({
          user: user,
          profile: profile
        });
      }
      
      return employees;
      
    } catch (error) {
      console.error('Error getting store employees with profiles:', error);
      throw error;
    }
  }

  // Generate avatar from employee name
  generateEmployeeAvatar(fullName: string | undefined): string {
    if (!fullName) {
      // Return default avatar if no name
      return `
        <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
          <rect width="100" height="100" fill="#666666" rx="50"/>
          <text x="50" y="60" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="40" font-weight="bold">?</text>
        </svg>
      `;
    }
    
    const firstLetter = fullName.charAt(0).toUpperCase();
    const colors = [
      '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4', '#FFEAA7',
      '#DDA0DD', '#98D8C8', '#F7DC6F', '#BB8FCE', '#85C1E9'
    ];
    
    const colorIndex = fullName.charCodeAt(0) % colors.length;
    const backgroundColor = colors[colorIndex];
    
    return `
      <svg width="100" height="100" viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">
        <rect width="100" height="100" fill="${backgroundColor}" rx="50"/>
        <text x="50" y="60" text-anchor="middle" fill="white" font-family="Arial, sans-serif" font-size="40" font-weight="bold">${firstLetter}</text>
      </svg>
    `;
  }

  // Convert SVG to base64
  svgToBase64(svgString: string): string {
    return 'data:image/svg+xml;base64,' + btoa(svgString);
  }
}