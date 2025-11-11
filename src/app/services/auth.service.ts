import { Injectable } from '@angular/core';
import { Firestore, collection, doc, setDoc, query, where, getDocs, Timestamp, updateDoc, getDoc, deleteDoc } from '@angular/fire/firestore';
import emailjs from 'emailjs-com';

export interface User {
  id?: string;
  username: string;
  password_hash: string;
  full_name: string;
  email?: string;
  phone_number?: string;
  province: string;
  municipality: string;
  barangay: string;
  sitio_purok?: string;
  role: 'Admin' | 'Employee' | 'Customer' | 'StoreOwner';
  status: 'active' | 'inactive';
  created_at: any;
  updated_at: any;
  store_owner_id?: string; // ID of the store owner who created this employee
}

export interface PasswordResetToken {
  id?: string;
  email: string;
  token: string;
  expires_at: any;
  used: boolean;
  created_at: any;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private currentUser: User | null = null;

  // ✅ EMAILJS CONFIGURATION - ADD THIS
  private emailjsConfig = {
    serviceId: 'service_40dgh2o',
    templateId: 'template_wkq2cqy', 
    publicKey: 'qWoBqAsvb6ntesysn'
  };

  constructor(private firestore: Firestore) {
    // ✅ INITIALIZE EMAILJS - ADD THIS
    emailjs.init(this.emailjsConfig.publicKey);
  }

  // ✅ ADD EMAIL SENDING METHOD
  private async sendPasswordResetEmail(email: string, resetLink: string, userFullName: string): Promise<void> {
    try {
      console.log('📧 Preparing to send email to:', email);
      
      const templateParams = {
        to_email: email,
        to_name: userFullName,
        reset_link: resetLink,
        app_name: 'CrediLink',
        support_email: 'support@credilink.com',
        from_name: 'CrediLink Support'
      };

      console.log('📧 Template parameters:', templateParams);
      console.log('📧 Using Service ID:', this.emailjsConfig.serviceId);
      console.log('📧 Using Template ID:', this.emailjsConfig.templateId);

      const response = await emailjs.send(
        this.emailjsConfig.serviceId,
        this.emailjsConfig.templateId,
        templateParams
      );
      
      console.log('✅ Email sent successfully! Status:', response.status);
      console.log('✅ Response:', response.text);
      
    } catch (error: any) {
      console.error('❌ Failed to send email:', error);
      
      // Detailed error information
      console.error('❌ Error status:', error?.status);
      console.error('❌ Error text:', error?.text);
      console.error('❌ Error message:', error?.message);
      
      if (error.status === 422) {
        throw new Error('Email template configuration error. Please check template variables.');
      } else if (error.status === 400) {
        throw new Error('Invalid email parameters.');
      } else if (error.status === 401) {
        throw new Error('Email service authentication failed.');
      } else {
        throw new Error('Failed to send password reset email. Please try again later.');
      }
    }
  }

  // Simple password hashing
  private hashPassword(password: string): string {
    return btoa(password);
  }

  private verifyPassword(password: string, hash: string): boolean {
    return btoa(password) === hash;
  }

  // Generate random token for password reset
  private generateResetToken(): string {
    return Math.random().toString(36).substring(2, 15) + Math.random().toString(36).substring(2, 15);
  }

  // Check if username exists
  async checkUsernameExists(username: string): Promise<boolean> {
    const usersRef = collection(this.firestore, 'all_users');
    const q = query(usersRef, where('username', '==', username.toLowerCase()));
    const querySnapshot = await getDocs(q);
    return !querySnapshot.empty;
  }

  // Check if email exists
  async checkEmailExists(email: string): Promise<boolean> {
    if (!email) return false;
    
    const usersRef = collection(this.firestore, 'all_users');
    const q = query(usersRef, where('email', '==', email.toLowerCase()));
    const querySnapshot = await getDocs(q);
    return !querySnapshot.empty;
  }

  // Get user by email
  async getUserByEmail(email: string): Promise<User | null> {
    if (!email) return null;
    
    const usersRef = collection(this.firestore, 'all_users');
    const q = query(usersRef, where('email', '==', email.toLowerCase()));
    const querySnapshot = await getDocs(q);
    
    if (querySnapshot.empty) return null;
    
    return querySnapshot.docs[0].data() as User;
  }

  // Get user by username
  async getUserByUsername(username: string): Promise<User | null> {
    if (!username) return null;
    
    const usersRef = collection(this.firestore, 'all_users');
    const q = query(usersRef, where('username', '==', username.toLowerCase()));
    const querySnapshot = await getDocs(q);
    
    if (querySnapshot.empty) return null;
    
    return querySnapshot.docs[0].data() as User;
  }

  // PASSWORD RESET FUNCTIONALITY

  // ✅ UPDATED: Request password reset - NOW SENDS ACTUAL EMAIL
  async requestPasswordReset(email: string): Promise<string> {
    try {
      console.log('🔐 Starting password reset for:', email);

      // Check if email exists
      const userExists = await this.checkEmailExists(email);
      if (!userExists) {
        throw new Error('No account found with this email address.');
      }

      // Get user data
      const user = await this.getUserByEmail(email);
      if (!user) {
        throw new Error('No account found with this email address.');
      }

      console.log('👤 User found:', user.full_name);

      // Generate reset token
      const resetToken = this.generateResetToken();
      
      // Calculate expiration (1 hour from now)
      const expiresAt = new Date();
      expiresAt.setHours(expiresAt.getHours() + 1);

      // Store reset token in Firestore
      const resetTokensRef = collection(this.firestore, 'password_reset_tokens');
      const newTokenRef = doc(resetTokensRef);
      
      const resetTokenData: PasswordResetToken = {
        id: newTokenRef.id,
        email: email.toLowerCase(),
        token: resetToken,
        expires_at: Timestamp.fromDate(expiresAt),
        used: false,
        created_at: Timestamp.now()
      };

      await setDoc(newTokenRef, resetTokenData);
      console.log('✅ Reset token stored in Firestore');

      // Create reset link
      const resetLink = `${window.location.origin}/reset-password?token=${resetToken}&email=${encodeURIComponent(email)}`;
      
      console.log('📧 Attempting to send email...');
      console.log('🔗 Reset Link:', resetLink);

      // ✅ THIS IS WHAT SENDS THE ACTUAL EMAIL
      await this.sendPasswordResetEmail(email, resetLink, user.full_name);

      console.log('✅ Password reset process completed for:', email);
      return resetToken;

    } catch (error: any) {
      console.error('❌ Password reset request error:', error);
      throw new Error(error.message || 'Failed to process password reset request.');
    }
  }

  // Verify reset token
  async verifyResetToken(email: string, token: string): Promise<boolean> {
    try {
      const resetTokensRef = collection(this.firestore, 'password_reset_tokens');
      const q = query(
        resetTokensRef, 
        where('email', '==', email.toLowerCase()),
        where('token', '==', token),
        where('used', '==', false)
      );
      
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        return false;
      }

      const tokenDoc = querySnapshot.docs[0];
      const tokenData = tokenDoc.data() as PasswordResetToken;

      // Check if token is expired
      const now = new Date();
      const expiresAt = tokenData.expires_at.toDate();
      
      if (now > expiresAt) {
        // Mark token as used
        await updateDoc(doc(this.firestore, 'password_reset_tokens', tokenDoc.id), {
          used: true
        });
        return false;
      }

      return true;

    } catch (error) {
      console.error('Token verification error:', error);
      return false;
    }
  }

  // Reset password using token
  async resetPasswordWithToken(email: string, token: string, newPassword: string): Promise<void> {
    try {
      // Verify token first
      const isValidToken = await this.verifyResetToken(email, token);
      if (!isValidToken) {
        throw new Error('Invalid or expired reset token.');
      }

      // Get the token document
      const resetTokensRef = collection(this.firestore, 'password_reset_tokens');
      const q = query(
        resetTokensRef, 
        where('email', '==', email.toLowerCase()),
        where('token', '==', token)
      );
      
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        throw new Error('Invalid reset token.');
      }

      const tokenDoc = querySnapshot.docs[0];

      // Update user's password
      await this.updatePasswordByEmail(email, newPassword);

      // Mark token as used
      await updateDoc(doc(this.firestore, 'password_reset_tokens', tokenDoc.id), {
        used: true,
        used_at: Timestamp.now()
      });

    } catch (error: any) {
      console.error('Password reset error:', error);
      throw new Error(error.message || 'Failed to reset password.');
    }
  }

  // Update password by email
  async updatePasswordByEmail(email: string, newPassword: string): Promise<void> {
    try {
      const usersRef = collection(this.firestore, 'all_users');
      const q = query(usersRef, where('email', '==', email.toLowerCase()));
      const querySnapshot = await getDocs(q);
      
      if (querySnapshot.empty) {
        throw new Error('User not found.');
      }
      
      const userDoc = querySnapshot.docs[0];
      await updateDoc(doc(this.firestore, 'all_users', userDoc.id), {
        password_hash: this.hashPassword(newPassword),
        updated_at: Timestamp.now()
      });
      
    } catch (error) {
      console.error('Update password error:', error);
      throw new Error('Failed to update password.');
    }
  }

  // Update password for current logged-in user
  async updateCurrentUserPassword(currentPassword: string, newPassword: string): Promise<void> {
    try {
      const currentUser = this.getCurrentUser();
      if (!currentUser) {
        throw new Error('No user is currently logged in.');
      }

      // Verify current password
      const user = await this.getUserByUsername(currentUser.username);
      if (!user || !this.verifyPassword(currentPassword, user.password_hash)) {
        throw new Error('Current password is incorrect.');
      }

      // Update password
      await this.updatePasswordByEmail(user.email || '', newPassword);

      // Update local storage if current user
      if (this.currentUser) {
        this.currentUser.password_hash = this.hashPassword(newPassword);
        this.currentUser.updated_at = Timestamp.now();
        localStorage.setItem('currentUser', JSON.stringify(this.currentUser));
      }

    } catch (error: any) {
      console.error('Update current user password error:', error);
      throw new Error(error.message || 'Failed to update password.');
    }
  }

  // EXISTING METHODS (keep all your existing methods)

  // Update registerCustomer method
  async registerCustomer(userData: {
    username: string;
    password: string;
    full_name: string;
    email?: string;
    phone_number?: string;
    province: string;
    municipality: string;
    barangay: string;
    sitio_purok?: string;
  }): Promise<void> {
    try {
      const exists = await this.checkUsernameExists(userData.username);
      if (exists) {
        throw new Error('Username already exists');
      }

      // Check if email already exists if provided
      if (userData.email) {
        const emailExists = await this.checkEmailExists(userData.email);
        if (emailExists) {
          throw new Error('Email already exists');
        }
      }

      const usersRef = collection(this.firestore, 'all_users');
      const newUserRef = doc(usersRef);
      
      const newUser: User = {
        id: newUserRef.id,
        username: userData.username.toLowerCase(),
        password_hash: this.hashPassword(userData.password),
        full_name: userData.full_name,
        email: userData.email || '',
        phone_number: userData.phone_number || '',
        province: userData.province,
        municipality: userData.municipality,
        barangay: userData.barangay,
        sitio_purok: userData.sitio_purok || '',
        role: 'Customer',
        status: 'active',
        created_at: Timestamp.now(),
        updated_at: Timestamp.now()
      };

      await setDoc(newUserRef, newUser);
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  }

  // Update registerStoreOwner method
  async registerStoreOwner(userData: {
    username: string;
    password: string;
    full_name: string;
    email?: string;
    phone_number?: string;
    province: string;
    municipality: string;
    barangay: string;
    sitio_purok?: string;
  }): Promise<void> {
    try {
      const exists = await this.checkUsernameExists(userData.username);
      if (exists) {
        throw new Error('Username already exists');
      }

      // Check if email already exists if provided
      if (userData.email) {
        const emailExists = await this.checkEmailExists(userData.email);
        if (emailExists) {
          throw new Error('Email already exists');
        }
      }

      const usersRef = collection(this.firestore, 'all_users');
      const newUserRef = doc(usersRef);
      
      const newUser: User = {
        id: newUserRef.id,
        username: userData.username.toLowerCase(),
        password_hash: this.hashPassword(userData.password),
        full_name: userData.full_name,
        email: userData.email || '',
        phone_number: userData.phone_number || '',
        province: userData.province,
        municipality: userData.municipality,
        barangay: userData.barangay,
        sitio_purok: userData.sitio_purok || '',
        role: 'StoreOwner',
        status: 'active',
        created_at: Timestamp.now(),
        updated_at: Timestamp.now()
      };

      await setDoc(newUserRef, newUser);
    } catch (error) {
      console.error('Store owner registration error:', error);
      throw error;
    }
  }

  // Login with username, password, and role
  async login(username: string, password: string, role: 'Admin' | 'Employee' | 'Customer' | 'StoreOwner'): Promise<User> {
    try {
      const usersRef = collection(this.firestore, 'all_users');
      
      // Normalize username to lowercase
      const normalizedUsername = username.trim().toLowerCase();
      
      console.log('Attempting login:', { username: normalizedUsername, role });

      // Query for username and role
      const q = query(
        usersRef, 
        where('username', '==', normalizedUsername),
        where('role', '==', role)
      );
      
      const querySnapshot = await getDocs(q);
      
      console.log('Query results:', querySnapshot.size, 'documents found');

      if (querySnapshot.empty) {
        throw new Error('Invalid username or role');
      }

      const userDoc = querySnapshot.docs[0];
      const user = userDoc.data() as User;
      
      console.log('Found user:', user.username, user.role);

      // Verify password
      if (!this.verifyPassword(password, user.password_hash)) {
        throw new Error('Invalid password');
      }

      // Check active status
      if (user.status !== 'active') {
        throw new Error('Account is inactive. Please contact administrator.');
      }

      this.currentUser = user;
      localStorage.setItem('currentUser', JSON.stringify(user));

      return user;
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  getCurrentUser(): User | null {
    if (!this.currentUser) {
      const stored = localStorage.getItem('currentUser');
      if (stored) {
        this.currentUser = JSON.parse(stored);
      }
    }
    return this.currentUser;
  }

  logout(): void {
    this.currentUser = null;
    localStorage.removeItem('currentUser');
  }

  isLoggedIn(): boolean {
    return this.getCurrentUser() !== null;
  }

 // Create employee for store owner
async createStoreEmployee(userData: {
  username: string;
  password: string;
  full_name: string;
  email?: string;
  phone_number?: string;
  province: string;
  municipality: string;
  barangay: string;
  sitio_purok?: string;
}): Promise<void> {
  try {
    const currentUser = this.getCurrentUser();
    
    // ✅ Only store owners can create employees for their store
    if (!currentUser || currentUser.role !== 'StoreOwner') {
      throw new Error('Only store owners can create employee accounts for their store');
    }

    // Check if username exists
    const exists = await this.checkUsernameExists(userData.username);
    if (exists) {
      throw new Error('Username already exists');
    }

    // Check if email already exists if provided
    if (userData.email) {
      const emailExists = await this.checkEmailExists(userData.email);
      if (emailExists) {
        throw new Error('Email already exists');
      }
    }

    const usersRef = collection(this.firestore, 'all_users');
    const newUserRef = doc(usersRef);
    
    const newEmployee: User = {
      id: newUserRef.id,
      username: userData.username.toLowerCase(),
      password_hash: this.hashPassword(userData.password),
      full_name: userData.full_name,
      email: userData.email || '',
      phone_number: userData.phone_number || '',
      province: userData.province,
      municipality: userData.municipality,
      barangay: userData.barangay,
      sitio_purok: userData.sitio_purok || '',
      role: 'Employee',
      status: 'active',
      // ✅ CRITICAL: Link employee to store owner
      store_owner_id: currentUser.id, // The store owner who created this employee
      created_at: Timestamp.now(),
      updated_at: Timestamp.now()
    };

    await setDoc(newUserRef, newEmployee);
    
    console.log('✅ Employee created successfully for store owner:', currentUser.id);
    
  } catch (error) {
    console.error('Create store employee error:', error);
    throw error;
  }
  }

  // Get employees for current store owner
async getStoreEmployees(): Promise<User[]> {
  try {
    const currentUser = this.getCurrentUser();
    
    if (!currentUser || currentUser.role !== 'StoreOwner') {
      throw new Error('Only store owners can view their employees');
    }

    const usersRef = collection(this.firestore, 'all_users');
    // ✅ Query employees that belong to this store owner
    const q = query(
      usersRef, 
      where('role', '==', 'Employee'),
      where('store_owner_id', '==', currentUser.id)
    );
    
    const querySnapshot = await getDocs(q);
    
    const employees: User[] = [];
    querySnapshot.forEach((doc) => {
      employees.push(doc.data() as User);
    });
    
    return employees;
    
  } catch (error) {
    console.error('Get store employees error:', error);
    throw error;
  }
}
// Update user status (active/inactive)
async updateUserStatus(userId: string, status: 'active' | 'inactive'): Promise<void> {
  try {
    const userRef = doc(this.firestore, 'all_users', userId);
    await updateDoc(userRef, { 
      status,
      updated_at: Timestamp.now()
    });
    
    console.log('✅ User status updated:', userId, status);
  } catch (error) {
    console.error('Update user status error:', error);
    throw new Error('Failed to update user status');
  }
}
// Delete employee (only for store owners)
async deleteStoreEmployee(employeeId: string): Promise<void> {
  try {
    const currentUser = this.getCurrentUser();
    
    if (!currentUser || currentUser.role !== 'StoreOwner') {
      throw new Error('Only store owners can delete their employees');
    }

    // First, verify this employee belongs to the current store owner
    const employeeRef = doc(this.firestore, 'all_users', employeeId);
    const employeeDoc = await getDoc(employeeRef);
    
    if (!employeeDoc.exists()) {
      throw new Error('Employee not found');
    }

    const employee = employeeDoc.data() as User;
    
    if (employee.store_owner_id !== currentUser.id) {
      throw new Error('You can only delete your own employees');
    }

    // Delete the employee
    await deleteDoc(employeeRef);
    
    console.log('✅ Employee deleted:', employeeId);
    
  } catch (error) {
    console.error('Delete employee error:', error);
    throw error;
  }
}
// Update employee information
async updateStoreEmployee(employeeId: string, updateData: {
  full_name?: string;
  email?: string;
  phone_number?: string;
  province?: string;
  municipality?: string;
  barangay?: string;
  sitio_purok?: string;
  status?: 'active' | 'inactive';
}): Promise<void> {
  try {
    const currentUser = this.getCurrentUser();
    
    if (!currentUser || currentUser.role !== 'StoreOwner') {
      throw new Error('Only store owners can update their employees');
    }

    // First, verify this employee belongs to the current store owner
    const employeeRef = doc(this.firestore, 'all_users', employeeId);
    const employeeDoc = await getDoc(employeeRef);
    
    if (!employeeDoc.exists()) {
      throw new Error('Employee not found');
    }

    const employee = employeeDoc.data() as User;
    
    if (employee.store_owner_id !== currentUser.id) {
      throw new Error('You can only update your own employees');
    }

    // Prepare update data
    const updatePayload: any = {
      updated_at: Timestamp.now()
    };

    // Add only the fields that are provided
    if (updateData.full_name !== undefined) updatePayload.full_name = updateData.full_name;
    if (updateData.email !== undefined) updatePayload.email = updateData.email;
    if (updateData.phone_number !== undefined) updatePayload.phone_number = updateData.phone_number;
    if (updateData.province !== undefined) updatePayload.province = updateData.province;
    if (updateData.municipality !== undefined) updatePayload.municipality = updateData.municipality;
    if (updateData.barangay !== undefined) updatePayload.barangay = updateData.barangay;
    if (updateData.sitio_purok !== undefined) updatePayload.sitio_purok = updateData.sitio_purok;
    if (updateData.status !== undefined) updatePayload.status = updateData.status;

    // Update the employee
    await updateDoc(employeeRef, updatePayload);
    
    console.log('✅ Employee updated successfully:', employeeId);
    
  } catch (error) {
    console.error('Update employee error:', error);
    throw error;
  }
}

// Get employee by ID
async getStoreEmployeeById(employeeId: string): Promise<User | null> {
  try {
    const currentUser = this.getCurrentUser();
    
    if (!currentUser || currentUser.role !== 'StoreOwner') {
      throw new Error('Only store owners can view their employees');
    }

    const employeeRef = doc(this.firestore, 'all_users', employeeId);
    const employeeDoc = await getDoc(employeeRef);
    
    if (!employeeDoc.exists()) {
      return null;
    }

    const employee = employeeDoc.data() as User;
    
    // Verify this employee belongs to the current store owner
    if (employee.store_owner_id !== currentUser.id) {
      throw new Error('You can only view your own employees');
    }

    return employee;
    
  } catch (error) {
    console.error('Get employee by ID error:', error);
    throw error;
  }
}
}

// import { Injectable } from '@angular/core';
// import { Firestore, collection, doc, setDoc, query, where, getDocs, Timestamp } from '@angular/fire/firestore';

// export interface User {
//   id?: string;
//   username: string;
//   password_hash: string;
//   full_name: string;
//   email?: string;
//   phone_number?: string;
//   role: 'Admin' | 'Employee' | 'Customer';
//   status: 'active' | 'inactive';
//   created_at: any;
//   updated_at: any;
// }

// @Injectable({
//   providedIn: 'root'
// })
// export class AuthService {
//   private currentUser: User | null = null;

//   constructor(private firestore: Firestore) {}

//   // Simple password hashing
//   private hashPassword(password: string): string {
//     return btoa(password);
//   }

//   private verifyPassword(password: string, hash: string): boolean {
//     return btoa(password) === hash;
//   }

//   // Check if username exists
//   async checkUsernameExists(username: string): Promise<boolean> {
//     const usersRef = collection(this.firestore, 'all_users');
//     const q = query(usersRef, where('username', '==', username.toLowerCase()));
//     const querySnapshot = await getDocs(q);
//     return !querySnapshot.empty;
//   }

//   // Register new customer
//   async registerCustomer(userData: {
//     username: string;
//     password: string;
//     full_name: string;
//     email?: string;
//     phone_number?: string;
//   }): Promise<void> {
//     try {
//       const exists = await this.checkUsernameExists(userData.username);
//       if (exists) {
//         throw new Error('Username already exists');
//       }

//       const usersRef = collection(this.firestore, 'all_users');
//       const newUserRef = doc(usersRef);
      
//       const newUser: User = {
//         id: newUserRef.id,
//         username: userData.username.toLowerCase(),
//         password_hash: this.hashPassword(userData.password),
//         full_name: userData.full_name,
//         email: userData.email || '',
//         phone_number: userData.phone_number || '',
//         role: 'Customer',
//         status: 'active',
//         created_at: Timestamp.now(),
//         updated_at: Timestamp.now()
//       };

//       await setDoc(newUserRef, newUser);
//     } catch (error) {
//       console.error('Registration error:', error);
//       throw error;
//     }
//   }

//   // Login with username, password, and role
//   async login(username: string, password: string, role: 'Admin' | 'Employee' | 'Customer'): Promise<User> {
//     try {
//       const usersRef = collection(this.firestore, 'all_users');
      
//       // Normalize username to lowercase
//       const normalizedUsername = username.trim().toLowerCase();
      
//       console.log('Attempting login:', { username: normalizedUsername, role });

//       // Query for username and role
//       const q = query(
//         usersRef, 
//         where('username', '==', normalizedUsername),
//         where('role', '==', role)
//       );
      
//       const querySnapshot = await getDocs(q);
      
//       console.log('Query results:', querySnapshot.size, 'documents found');

//       if (querySnapshot.empty) {
//         throw new Error('Invalid username or role');
//       }

//       const userDoc = querySnapshot.docs[0];
//       const user = userDoc.data() as User;
      
//       console.log('Found user:', user.username, user.role);

//       // Verify password
//       if (!this.verifyPassword(password, user.password_hash)) {
//         throw new Error('Invalid password');
//       }

//       // Check active status
//       if (user.status !== 'active') {
//         throw new Error('Account is inactive. Please contact administrator.');
//       }

//       this.currentUser = user;
//       localStorage.setItem('currentUser', JSON.stringify(user));

//       return user;
//     } catch (error) {
//       console.error('Login error:', error);
//       throw error;
//     }
//   }

//   getCurrentUser(): User | null {
//     if (!this.currentUser) {
//       const stored = localStorage.getItem('currentUser');
//       if (stored) {
//         this.currentUser = JSON.parse(stored);
//       }
//     }
//     return this.currentUser;
//   }

//   logout(): void {
//     this.currentUser = null;
//     localStorage.removeItem('currentUser');
//   }

//   isLoggedIn(): boolean {
//     return this.getCurrentUser() !== null;
//   }

//   async createEmployee(userData: {
//     username: string;
//     password: string;
//     full_name: string;
//     email?: string;
//     phone_number?: string;
//   }): Promise<void> {
//     try {
//       const currentUser = this.getCurrentUser();
//       if (!currentUser || currentUser.role !== 'Admin') {
//         throw new Error('Only admins can create employee accounts');
//       }

//       const exists = await this.checkUsernameExists(userData.username);
//       if (exists) {
//         throw new Error('Username already exists');
//       }

//       const usersRef = collection(this.firestore, 'all_users');
//       const newUserRef = doc(usersRef);
      
//       const newEmployee: User = {
//         id: newUserRef.id,
//         username: userData.username.toLowerCase(),
//         password_hash: this.hashPassword(userData.password),
//         full_name: userData.full_name,
//         email: userData.email || '',
//         phone_number: userData.phone_number || '',
//         role: 'Employee',
//         status: 'active',
//         created_at: Timestamp.now(),
//         updated_at: Timestamp.now()
//       };

//       await setDoc(newUserRef, newEmployee);
//     } catch (error) {
//       console.error('Create employee error:', error);
//       throw error;
//     }
//   }
  
// }
