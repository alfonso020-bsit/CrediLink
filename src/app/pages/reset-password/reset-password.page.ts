import { Component, OnInit } from '@angular/core';
import { NgForm } from '@angular/forms';
import { Router, ActivatedRoute } from '@angular/router';
import { ToastController, LoadingController } from '@ionic/angular';
import { AuthService } from '../../services/auth.service';

@Component({
  selector: 'app-reset-password',
  templateUrl: './reset-password.page.html',
  styleUrls: ['./reset-password.page.scss'],
  standalone: false,
})
export class ResetPasswordPage implements OnInit {
  showPassword = false;
  isLoading = false;
  resetSuccess = false;
  userEmail = '';
  resetToken = '';
  showTokenField = false;
  tokenValid = true;

  constructor(
    private router: Router,
    private route: ActivatedRoute,
    private toastCtrl: ToastController,
    private loadingCtrl: LoadingController,
    private authService: AuthService
  ) { }

  ngOnInit() {
    // Get email and token from query parameters
    this.route.queryParams.subscribe(params => {
      this.userEmail = params['email'] || '';
      this.resetToken = params['token'] || '';
      this.showTokenField = !!this.resetToken;

      // Validate token if present
      if (this.resetToken && this.userEmail) {
        this.validateToken();
      }
    });
  }

  async validateToken() {
    try {
      this.tokenValid = await this.authService.verifyResetToken(this.userEmail, this.resetToken);
      if (!this.tokenValid) {
        await this.showToast('Invalid or expired reset token. Please request a new reset link.', 'danger');
      }
    } catch (error) {
      this.tokenValid = false;
      await this.showToast('Error validating token', 'danger');
    }
  }

  togglePassword() {
    this.showPassword = !this.showPassword;
  }

  async onResetPassword(form: NgForm) {
    if (form.invalid) {
      await this.showToast('Please fill in all fields correctly', 'danger');
      return;
    }

    const { newPassword, confirmPassword } = form.value;

    if (newPassword !== confirmPassword) {
      await this.showToast('Passwords do not match', 'danger');
      return;
    }

    if (newPassword.length < 6) {
      await this.showToast('Password must be at least 6 characters long', 'danger');
      return;
    }

    if (this.resetToken && !this.tokenValid) {
      await this.showToast('Invalid reset token. Please request a new reset link.', 'danger');
      return;
    }

    this.isLoading = true;

    try {
      if (this.resetToken) {
        // Reset password using token
        await this.authService.resetPasswordWithToken(this.userEmail, this.resetToken, newPassword);
      } else {
        // Direct password reset (admin functionality)
        await this.authService.updatePasswordByEmail(this.userEmail, newPassword);
      }
      
      this.resetSuccess = true;
      await this.showToast('Password reset successfully! You can now login with your new password.', 'success');
      
    } catch (error: any) {
      console.error('Reset password error:', error);
      await this.showToast(error.message || 'Failed to reset password', 'danger');
    } finally {
      this.isLoading = false;
    }
  }

  goToLogin() {
    this.router.navigate(['/login']);
  }

  requestNewReset() {
    this.router.navigate(['/forgot-password']);
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