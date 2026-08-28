import 'package:flutter/material.dart';

import '../admin/admin_screens.dart';
import '../customer/customer_screens.dart';
import '../employee/employee_screens.dart';
import '../shared/role_tab_shell.dart';
import '../storeowner/storeowner_screens.dart';
import '../../models/user_role.dart';

RoleTabConfig adminTabConfig() => RoleTabConfig(
      role: UserRole.admin,
      tabs: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.store), label: 'Stores'),
        NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
        NavigationDestination(icon: Icon(Icons.analytics), label: 'Analytics'),
        NavigationDestination(icon: Icon(Icons.settings), label: 'System'),
      ],
      screens: const [
        AdminDashboardTab(),
        AdminStoresTab(),
        AdminUsersTab(),
        AdminAnalyticsTab(),
        AdminSystemTab(),
      ],
    );

RoleTabConfig storeOwnerTabConfig() => RoleTabConfig(
      role: UserRole.storeOwner,
      tabs: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'POS'),
        NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Debts'),
        NavigationDestination(icon: Icon(Icons.inventory), label: 'Inventory'),
        NavigationDestination(icon: Icon(Icons.groups), label: 'Employees'),
      ],
      screens: const [
        StoreOwnerDashboardTab(),
        StoreOwnerSalesTab(),
        StoreOwnerDebtsTab(),
        StoreOwnerInventoryTab(),
        StoreOwnerEmployeesTab(),
      ],
    );

RoleTabConfig employeeTabConfig() => RoleTabConfig(
      role: UserRole.employee,
      tabs: const [
        NavigationDestination(icon: Icon(Icons.dashboard), label: 'Dashboard'),
        NavigationDestination(icon: Icon(Icons.receipt), label: 'Sales'),
        NavigationDestination(icon: Icon(Icons.shopping_cart), label: 'Debts'),
        NavigationDestination(icon: Icon(Icons.inventory_2), label: 'Products'),
        NavigationDestination(icon: Icon(Icons.assessment), label: 'Reports'),
      ],
      screens: const [
        EmployeeDashboardTab(),
        EmployeeSalesTab(),
        EmployeePosScreen(),
        EmployeeProductsTab(),
        EmployeeReportsTab(),
      ],
    );

RoleTabConfig customerTabConfig() => RoleTabConfig(
      role: UserRole.customer,
      tabs: const [
        NavigationDestination(icon: Icon(Icons.person), label: 'My Account'),
        NavigationDestination(icon: Icon(Icons.money), label: 'My Debts'),
        NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        NavigationDestination(icon: Icon(Icons.store), label: 'Products'),
        NavigationDestination(icon: Icon(Icons.notifications), label: 'Alerts'),
      ],
      screens: const [
        CustomerAccountTab(),
        CustomerDebtsTab(),
        CustomerHistoryTab(),
        CustomerProductsTab(),
        CustomerAlertsTab(),
      ],
    );
