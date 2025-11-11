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

  isLoading = true;

  constructor(private adminService: AdminService) { }

  ngOnInit() {
    this.loadPlatformStats();
  }

  async loadPlatformStats() {
    try {
      this.platformStats = await this.adminService.getPlatformStats();
    } catch (error) {
      console.error('Error loading platform stats:', error);
    } finally {
      this.isLoading = false;
    }
  }

  refreshData() {
    this.isLoading = true;
    this.loadPlatformStats();
  }
}