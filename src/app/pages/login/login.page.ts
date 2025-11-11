import { Component, OnInit } from '@angular/core';
import { NgForm } from '@angular/forms';
import { Router } from '@angular/router';
import { ToastController, LoadingController } from '@ionic/angular';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-login',
  templateUrl: './login.page.html',
  styleUrls: ['./login.page.scss'],
  standalone: false,
})
export class LoginPage implements OnInit {
  showPassword = false;
  selectedRole: 'Admin' | 'Employee' | 'Customer' | 'StoreOwner' = 'Customer';

  constructor(
    private router: Router,
    private toastCtrl: ToastController,
    private loadingCtrl: LoadingController,
    private authService: AuthService
  ) { }

  ngOnInit() {
  }

  togglePassword() {
    this.showPassword = !this.showPassword;
  }

  // Helper method to get display name for roles
  getRoleDisplayName(): string {
    switch (this.selectedRole) {
      case 'Admin': return 'Admin';
      case 'Employee': return 'Employee';
      case 'Customer': return 'Customer';
      case 'StoreOwner': return 'Store Owner';
      default: return 'User';
    }
  }

  async onLogin(form: NgForm) {
    if (form.invalid) {
      await this.showToast('Please fill in all fields correctly', 'danger');
      return;
    }

    const loading = await this.loadingCtrl.create({
      message: 'Logging in...',
    });
    await loading.present();

    try {
      const { username, password } = form.value;
      
      const user = await this.authService.login(username, password, this.selectedRole);
      
      await loading.dismiss();
      await this.showToast(`Welcome back, ${user.full_name}!`, 'success');
      
      // Navigate based on role
      const role = user.role.toLowerCase();

      if (role === 'admin') {
        this.router.navigate(['/admin/tab1']);
      } else if (role === 'employee') {
        this.router.navigate(['/employee/tab1']);
      } else if (role === 'customer') {
        this.router.navigate(['/customer/tab1']);
      } else if (role === 'storeowner') {
        this.router.navigate(['/storeowner/tab1']);
      } else {
        await this.showToast('Unknown role', 'danger');
      }
      
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast(error.message || 'Login failed', 'danger');
    }
  }

  forgotPassword() {
  this.router.navigate(['/forgot-password']);
  }

  goToRegister() {
    // Navigate to register page - the register page will handle role selection
    this.router.navigate(['/register']);
  }

  private async showToast(message: string, color: string) {
    const toast = await this.toastCtrl.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }
}