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
      users.push({ id: doc.id, ...doc.data() } as User);
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
      users.push({ id: doc.id, ...doc.data() } as User);
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

  // SIMPLIFIED: Get financial statistics - only revenue and outstanding debt
  async getFinancialStats(): Promise<any> {
    try {
      // Get all cash products for revenue calculation
      const cashProductsRef = collection(this.firestore, 'cash_products');
      const cashSnapshot = await getDocs(cashProductsRef);
      
      let totalRevenue = 0;
      let totalCashTransactions = 0;
      
      cashSnapshot.forEach(doc => {
        const data = doc.data();
        totalRevenue += data['total'] || 0;
        totalCashTransactions++;
      });

      // Get all debt products for outstanding calculation
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtSnapshot = await getDocs(debtProductsRef);
      
      let totalOutstanding = 0;
      let totalDebtTransactions = 0;
      
      debtSnapshot.forEach(doc => {
        const data = doc.data();
        const remainingBalance = data['remainingBalance'] || data['total'] || 0;
        totalOutstanding += remainingBalance;
        totalDebtTransactions++;
      });

      const totalTransactions = totalCashTransactions + totalDebtTransactions;

      // Get store count for average calculation
      const storeOwners = await this.getStoreOwners();
      const activeStoreCount = storeOwners.filter(store => store.status === 'active').length;
      const avgStoreRevenue = activeStoreCount > 0 ? totalRevenue / activeStoreCount : 0;

      return {
        totalRevenue,
        totalOutstanding,
        avgStoreRevenue: Math.round(avgStoreRevenue),
        totalTransactions
      };
    } catch (error) {
      console.error('Error loading financial stats:', error);
      return {
        totalRevenue: 0,
        totalOutstanding: 0,
        avgStoreRevenue: 0,
        totalTransactions: 0
      };
    }
  }

  // SIMPLIFIED: Get today's activity
  async getTodayActivity(): Promise<any> {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      let todayTransactions = 0;
      let todayNewDebts = 0;
      let todayPayments = 0;

      // Get all cash products and filter on client side
      const cashProductsRef = collection(this.firestore, 'cash_products');
      const cashSnapshot = await getDocs(cashProductsRef);
      
      cashSnapshot.forEach(doc => {
        const data = doc.data();
        const createdDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
        
        if (createdDate >= today && createdDate < tomorrow) {
          todayTransactions++;
        }
      });

      // Get all debt products and filter on client side
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtSnapshot = await getDocs(debtProductsRef);
      
      debtSnapshot.forEach(doc => {
        const data = doc.data();
        const createdDate = data['created_at']?.toDate ? data['created_at'].toDate() : new Date(data['created_at']);
        
        // Count new debts created today
        if (createdDate >= today && createdDate < tomorrow) {
          todayNewDebts++;
        }

        // Count payments made today
        const payments = data['payments'] || [];
        payments.forEach((payment: any) => {
          const paymentDate = payment.paymentDate?.toDate ? payment.paymentDate.toDate() : new Date(payment.paymentDate);
          if (paymentDate >= today && paymentDate < tomorrow) {
            todayPayments++;
          }
        });
      });

      return {
        transactions: todayTransactions,
        newDebts: todayNewDebts,
        payments: todayPayments
      };
    } catch (error) {
      console.error('Error loading today activity:', error);
      return {
        transactions: 0,
        newDebts: 0,
        payments: 0
      };
    }
  }

  // SIMPLIFIED: Get top performing stores - only revenue based
  async getTopStores(limitCount: number = 5): Promise<any[]> {
    try {
      const storeOwners = await this.getStoreOwners();
      const storePerformance = [];

      for (const store of storeOwners) {
        if (store.status === 'active') {
          // Get store's cash products for revenue
          const cashProductsRef = collection(this.firestore, 'cash_products');
          const cashQuery = query(
            cashProductsRef,
            where('store_owner_id', '==', store.id)
          );
          const cashSnapshot = await getDocs(cashQuery);
          
          let storeRevenue = 0;
          cashSnapshot.forEach(doc => {
            storeRevenue += doc.data()['total'] || 0;
          });

          // Get employee count
          const employees = await this.getUsersByRole('Employee');
          const storeEmployees = employees.filter(emp => 
            emp.store_owner_id === store.id || emp.created_at === store.id
          );

          storePerformance.push({
            id: store.id,
            name: store.store_name || store.full_name || 'Unknown Store',
            revenue: Math.round(storeRevenue),
            employeeCount: storeEmployees.length,
            status: store.status
          });
        }
      }

      return storePerformance
        .sort((a, b) => b.revenue - a.revenue)
        .slice(0, limitCount);
    } catch (error) {
      console.error('Error loading top stores:', error);
      return [];
    }
  }

  // SIMPLIFIED: Get debt health - just total outstanding by age
  async getDebtHealth(): Promise<any> {
    try {
      const debtProductsRef = collection(this.firestore, 'debt_products');
      const debtSnapshot = await getDocs(debtProductsRef);
      
      const now = new Date();
      const debtHealth = {
        current: 0,
        overdue30: 0,
        overdue60: 0,
        overdue90: 0
      };

      debtSnapshot.forEach(doc => {
        const data = doc.data();
        const paymentStatus = data['payment_status'];
        
        if (paymentStatus !== 'paid') {
          const dueDate = data['dueDate']?.toDate ? data['dueDate'].toDate() : new Date(data['dueDate']);
          const remainingBalance = data['remainingBalance'] || data['total'] || 0;
          const daysOverdue = Math.floor((now.getTime() - dueDate.getTime()) / (1000 * 60 * 60 * 24));

          if (daysOverdue <= 0) {
            debtHealth.current += remainingBalance;
          } else if (daysOverdue <= 30) {
            debtHealth.overdue30 += remainingBalance;
          } else if (daysOverdue <= 60) {
            debtHealth.overdue60 += remainingBalance;
          } else {
            debtHealth.overdue90 += remainingBalance;
          }
        }
      });

      return debtHealth;
    } catch (error) {
      console.error('Error loading debt health:', error);
      return {
        current: 0,
        overdue30: 0,
        overdue60: 0,
        overdue90: 0
      };
    }
  }

  // SIMPLIFIED: Get growth metrics
  async getGrowthMetrics(): Promise<any> {
    try {
      const thirtyDaysAgo = new Date();
      thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

      // New stores in last 30 days
      const storeOwners = await this.getStoreOwners();
      const newStores = storeOwners.filter(store => {
        const createdDate = store.created_at?.toDate ? store.created_at.toDate() : new Date(store.created_at);
        return createdDate >= thirtyDaysAgo;
      }).length;

      // New users in last 30 days
      const allUsers = await this.getAllUsers();
      const newUsers = allUsers.filter(user => {
        const createdDate = user.created_at?.toDate ? user.created_at.toDate() : new Date(user.created_at);
        return createdDate >= thirtyDaysAgo;
      }).length;

      return {
        newStores,
        newUsers
      };
    } catch (error) {
      console.error('Error loading growth metrics:', error);
      return {
        newStores: 0,
        newUsers: 0
      };
    }
  }

  // SIMPLIFIED: Get critical alerts - only high overdue debt
  async getCriticalAlerts(): Promise<any[]> {
    try {
      const alerts = [];

      // Only alert: High overdue debt
      const debtHealth = await this.getDebtHealth();
      const totalOverdue90 = debtHealth.overdue90;
      
      if (totalOverdue90 > 5000) {
        alerts.push({
          icon: 'warning',
          color: 'danger',
          message: `High overdue debt: ${totalOverdue90.toLocaleString()} PHP in 90+ days category`,
          type: 'high_overdue'
        });
      }

      return alerts;
    } catch (error) {
      console.error('Error loading critical alerts:', error);
      return [];
    }
  }
}