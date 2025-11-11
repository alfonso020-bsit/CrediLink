import { Component } from '@angular/core';
import { NgForm } from '@angular/forms';
import { Router } from '@angular/router';
import { ToastController, LoadingController } from '@ionic/angular';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-forgot-password',
  templateUrl: './forgot-password.page.html',
  styleUrls: ['./forgot-password.page.scss'],
  standalone: false,
})
export class ForgotPasswordPage {
  isLoading = false;
  resetSent = false;
  resetToken = '';
  userEmail = '';
  resetLink = '';

  constructor(
    private router: Router,
    private toastCtrl: ToastController,
    private loadingCtrl: LoadingController,
    private authService: AuthService
  ) { }

  async onResetPassword(form: NgForm) {
    if (form.invalid) {
      await this.showToast('Please enter a valid email address', 'danger');
      return;
    }

    this.isLoading = true;
    this.userEmail = form.value.email;

    try {
      // This will send an actual email via EmailJS
      this.resetToken = await this.authService.requestPasswordReset(this.userEmail);
      
      // Create reset link for development display
      this.resetLink = `${window.location.origin}/reset-password?token=${this.resetToken}&email=${encodeURIComponent(this.userEmail)}`;
      
      this.resetSent = true;
      await this.showToast('Password reset instructions sent to your email!', 'success');
      
    } catch (error: any) {
      console.error('Forgot password error:', error);
      await this.showToast(error.message || 'Failed to send reset email', 'danger');
    } finally {
      this.isLoading = false;
    }
  }

  goToLogin() {
    this.router.navigate(['/login']);
  }

  goToResetPage() {
    // Navigate to reset password page with token
    this.router.navigate(['/reset-password'], {
      queryParams: {
        email: this.userEmail,
        token: this.resetToken
      }
    });
  }

  private async showToast(message: string, color: string) {
    const toast = await this.toastCtrl.create({
      message,
      duration: 5000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }
}