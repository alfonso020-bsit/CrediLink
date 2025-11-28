import { NgModule } from '@angular/core';
import { PreloadAllModules, RouterModule, Routes } from '@angular/router';

const routes: Routes = [
  {
    path: '',
    redirectTo: 'home',
    pathMatch: 'full'
  },
  {
    path: 'home',
    loadChildren: () => import('./home/home.module').then(m => m.HomePageModule)
  },
  {
    path: 'login',
    loadChildren: () => import('./pages/login/login.module').then(m => m.LoginPageModule)
  },
  {
    path: 'register',
    loadChildren: () => import('./pages/register/register.module').then(m => m.RegisterPageModule)
  },

    // ✅ ADMIN ROUTES
  {
    path: 'admin',
    loadChildren: () => import('./pages/admin/tabs/tabs.module').then(m => m.TabsPageModule)
  },
  // ✅ EMPLOYEE ROUTES
  {
    path: 'employee',
    loadChildren: () => import('./pages/employee/tabs/tabs.module').then(m => m.TabsPageModule)
  },
   // ✅ CUSTOMER ROUTES
  {
    path: 'customer',
    loadChildren: () => import('./pages/customer/tabs/tabs.module').then(m => m.TabsPageModule)
  },
   // ✅ STORE OWNER ROUTES
  {
    path: 'storeowner',
    loadChildren: () => import('./pages/storeowner/tabs/tabs.module').then(m => m.TabsPageModule)
  },
  {
    path: 'forgot-password',
    loadChildren: () => import('./pages/forgot-password/forgot-password.module').then( m => m.ForgotPasswordPageModule)
  },
  {
    path: 'reset-password',
    loadChildren: () => import('./pages/reset-password/reset-password.module').then( m => m.ResetPasswordPageModule)
  },
];

@NgModule({
  imports: [
    RouterModule.forRoot(routes, { preloadingStrategy: PreloadAllModules })
  ],
  exports: [RouterModule]
})
export class AppRoutingModule { }
