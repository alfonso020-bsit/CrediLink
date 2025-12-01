import { Component, OnInit } from '@angular/core';
import { AdminService } from 'src/app/services/admin.service';

@Component({
  selector: 'app-tab1',
  templateUrl: './tab1.page.html',
  styleUrls: ['./tab1.page.scss'],
  standalone: false
})
export class Tab1Page implements OnInit {
  platformStats = {
    totalStores: 0,
    totalEmployees: 0,
    totalCustomers: 0,
    totalUsers: 0,
    activeStores: 0
  };

  financialStats = {
    totalRevenue: 0,
    totalOutstanding: 0,
    avgStoreRevenue: 0,
    totalTransactions: 0
  };

  todayActivity = {
    transactions: 0,
    newDebts: 0,
    payments: 0
  };

  topStores: any[] = [];
  debtHealth = {
    current: 0,
    overdue30: 0,
    overdue60: 0,
    overdue90: 0
  };

  growth = {
    newStores: 0,
    newUsers: 0
  };

  criticalAlerts: any[] = [];

  isLoading = true;

  constructor(private adminService: AdminService) { }

  async ngOnInit() {
    await this.loadDashboardData();
  }

  async loadDashboardData() {
    try {
      await Promise.all([
        this.loadPlatformStats(),
        this.loadFinancialStats(),
        this.loadTodayActivity(),
        this.loadTopStores(),
        this.loadDebtHealth(),
        this.loadGrowthMetrics(),
        this.loadCriticalAlerts()
      ]);
    } catch (error) {
      console.error('Error loading dashboard data:', error);
    } finally {
      this.isLoading = false;
    }
  }

  async loadPlatformStats() {
    try {
      this.platformStats = await this.adminService.getPlatformStats();
    } catch (error) {
      console.error('Error loading platform stats:', error);
    }
  }

  async loadFinancialStats() {
    try {
      this.financialStats = await this.adminService.getFinancialStats();
    } catch (error) {
      console.error('Error loading financial stats:', error);
    }
  }

  async loadTodayActivity() {
    try {
      this.todayActivity = await this.adminService.getTodayActivity();
    } catch (error) {
      console.error('Error loading today activity:', error);
    }
  }

  async loadTopStores() {
    try {
      this.topStores = await this.adminService.getTopStores(5);
    } catch (error) {
      console.error('Error loading top stores:', error);
    }
  }

  async loadDebtHealth() {
    try {
      this.debtHealth = await this.adminService.getDebtHealth();
    } catch (error) {
      console.error('Error loading debt health:', error);
    }
  }

  async loadGrowthMetrics() {
    try {
      this.growth = await this.adminService.getGrowthMetrics();
    } catch (error) {
      console.error('Error loading growth metrics:', error);
    }
  }

  async loadCriticalAlerts() {
    try {
      this.criticalAlerts = await this.adminService.getCriticalAlerts();
    } catch (error) {
      console.error('Error loading critical alerts:', error);
    }
  }

  refreshData() {
    this.isLoading = true;
    this.loadDashboardData();
  }
}