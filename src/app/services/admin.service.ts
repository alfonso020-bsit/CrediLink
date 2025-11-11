import { Injectable } from '@angular/core';
import { Firestore, collection, query, where, getDocs, doc, updateDoc, deleteDoc } from '@angular/fire/firestore';
import { User } from './auth.service';

@Injectable({
  providedIn: 'root'
})
export class AdminService {

  constructor(private firestore: Firestore) { }

  // Get all users from all_users collection
  async getAllUsers(): Promise<User[]> {
    const usersRef = collection(this.firestore, 'all_users');
    const querySnapshot = await getDocs(usersRef);
    
    const users: User[] = [];
    querySnapshot.forEach((doc) => {
      users.push(doc.data() as User);
    });
    
    return users;
  }

  // Get users by role
  async getUsersByRole(role: string): Promise<User[]> {
    const usersRef = collection(this.firestore, 'all_users');
    const q = query(usersRef, where('role', '==', role));
    const querySnapshot = await getDocs(q);
    
    const users: User[] = [];
    querySnapshot.forEach((doc) => {
      users.push(doc.data() as User);
    });
    
    return users;
  }

  // Get store owners (StoreOwner role)
  async getStoreOwners(): Promise<User[]> {
    return this.getUsersByRole('StoreOwner');
  }

  // Get employees
  async getEmployees(): Promise<User[]> {
    return this.getUsersByRole('Employee');
  }

  // Get customers
  async getCustomers(): Promise<User[]> {
    return this.getUsersByRole('Customer');
  }

  // Update user status (active/inactive)
  async updateUserStatus(userId: string, status: 'active' | 'inactive'): Promise<void> {
    const userRef = doc(this.firestore, 'all_users', userId);
    await updateDoc(userRef, { status });
  }

  // Get platform statistics
  async getPlatformStats(): Promise<any> {
    const users = await this.getAllUsers();
    
    const storeOwners = users.filter(user => user.role === 'StoreOwner');
    const employees = users.filter(user => user.role === 'Employee');
    const customers = users.filter(user => user.role === 'Customer');
    
    return {
      totalStores: storeOwners.length,
      totalEmployees: employees.length,
      totalCustomers: customers.length,
      totalUsers: users.length,
      activeStores: storeOwners.filter(store => store.status === 'active').length
    };
  }
}