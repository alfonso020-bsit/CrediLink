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
  
  // // ✅ ADMIN ROUTES
  // {
  //   path: 'admin/tab1',
  //   loadChildren: () => import('./pages/admin/tab1/tab1.module').then(m => m.Tab1PageModule)
  // },
  // {
  //   path: 'tab2',
  //   loadChildren: () => import('./pages/admin/tab2/tab2.module').then( m => m.Tab2PageModule)
  // },
  // {
  //   path: 'tab3',
  //   loadChildren: () => import('./pages/admin/tab3/tab3.module').then( m => m.Tab3PageModule)
  // },
  // {
  //   path: 'tab4',
  //   loadChildren: () => import('./pages/admin/tab4/tab4.module').then( m => m.Tab4PageModule)
  // },
  // {
  //   path: 'tab5',
  //   loadChildren: () => import('./pages/admin/tab5/tab5.module').then( m => m.Tab5PageModule)
  // },

  // // ✅ EMPLOYEE ROUTES
  // {
  //   path: 'employee/tab1',
  //   loadChildren: () => import('./pages/employee/tab1/tab1.module').then(m => m.Tab1PageModule)
  // },
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
  // // ✅ CUSTOMER ROUTES
  // {
  //   path: 'customer/tab1',
  //   loadChildren: () => import('./pages/customer/tab1/tab1.module').then(m => m.Tab1PageModule)
  // },
   // ✅ STORE OWNER ROUTES
  {
    path: 'storeowner',
    loadChildren: () => import('./pages/storeowner/tabs/tabs.module').then(m => m.TabsPageModule)
  },
  // // ✅ STORE OWNER ROUTES
  // {
  //   path: 'storeowner/tab1',
  //   loadChildren: () => import('./pages/storeowner/tab1/tab1.module').then( m => m.Tab1PageModule)
  // },
  {
    path: 'forgot-password',
    loadChildren: () => import('./pages/forgot-password/forgot-password.module').then( m => m.ForgotPasswordPageModule)
  },
  {
    path: 'reset-password',
    loadChildren: () => import('./pages/reset-password/reset-password.module').then( m => m.ResetPasswordPageModule)
  },
  {
    path: 'tab2',
    loadChildren: () => import('./pages/storeowner/tab2/tab2.module').then( m => m.Tab2PageModule)
  },
  {
    path: 'tab3',
    loadChildren: () => import('./pages/storeowner/tab3/tab3.module').then( m => m.Tab3PageModule)
  },
  {
    path: 'tab4',
    loadChildren: () => import('./pages/storeowner/tab4/tab4.module').then( m => m.Tab4PageModule)
  },
  {
    path: 'tab5',
    loadChildren: () => import('./pages/storeowner/tab5/tab5.module').then( m => m.Tab5PageModule)
  },
  {
    path: 'tab2',
    loadChildren: () => import('./pages/customer/tab2/tab2.module').then( m => m.Tab2PageModule)
  },
  {
    path: 'tab3',
    loadChildren: () => import('./pages/customer/tab3/tab3.module').then( m => m.Tab3PageModule)
  },
  {
    path: 'tab4',
    loadChildren: () => import('./pages/customer/tab4/tab4.module').then( m => m.Tab4PageModule)
  },
  {
    path: 'tab5',
    loadChildren: () => import('./pages/customer/tab5/tab5.module').then( m => m.Tab5PageModule)
  },
  {
    path: 'tab2',
    loadChildren: () => import('./pages/employee/tab2/tab2.module').then( m => m.Tab2PageModule)
  },
  {
    path: 'tab3',
    loadChildren: () => import('./pages/employee/tab3/tab3.module').then( m => m.Tab3PageModule)
  },
  {
    path: 'tab4',
    loadChildren: () => import('./pages/employee/tab4/tab4.module').then( m => m.Tab4PageModule)
  },
  {
    path: 'tab5',
    loadChildren: () => import('./pages/employee/tab5/tab5.module').then( m => m.Tab5PageModule)
  },
];

@NgModule({
  imports: [
    RouterModule.forRoot(routes, { preloadingStrategy: PreloadAllModules })
  ],
  exports: [RouterModule]
})
export class AppRoutingModule { }


// import { NgModule } from '@angular/core';
// import { PreloadAllModules, RouterModule, Routes } from '@angular/router';

// const routes: Routes = [
//   {
//     path: 'home',
//     loadChildren: () => import('./home/home.module').then( m => m.HomePageModule)
//   },
//   {
//     path: '',
//     redirectTo: 'home',
//     pathMatch: 'full'
//   },
//   {
//     path: 'login',
//     loadChildren: () => import('./pages/login/login.module').then( m => m.LoginPageModule)
//   },
//   {
//     path: 'register',
//     loadChildren: () => import('./pages/register/register.module').then( m => m.RegisterPageModule)
//   },
//   {
//     path: 'tab1',
//     loadChildren: () => import('./pages/admin/tab1/tab1.module').then( m => m.Tab1PageModule)
//   },
//   {
//     path: 'tab1',
//     loadChildren: () => import('./pages/employee/tab1/tab1.module').then( m => m.Tab1PageModule)
//   },
//   {
//     path: 'tab1',
//     loadChildren: () => import('./pages/customer/tab1/tab1.module').then( m => m.Tab1PageModule)
//   },
// ];

// @NgModule({
//   imports: [
//     RouterModule.forRoot(routes, { preloadingStrategy: PreloadAllModules })
//   ],
//   exports: [RouterModule]
// })
// export class AppRoutingModule { }
