import { Component, OnInit } from '@angular/core';
import { AlertController, LoadingController, ModalController, ToastController } from '@ionic/angular';
import { Firestore, collection, query, where, getDocs, updateDoc, doc, orderBy, Timestamp } from '@angular/fire/firestore';
import { AuthService } from 'src/app/services/auth.service';
import { jsPDF } from 'jspdf';
import autoTable from 'jspdf-autotable';


export interface SaleItem {
  id: string;
  name: string;
  quantity: number;
  sellingPrice: number;
  costPrice: number;
  totalSelling: number;
  totalCost: number;
  profit: number;
  unit: string;
  pricing_option: string;
  product_barcode: string;
  // NEW: Add fields that exist in your database
  product_category?: string;
  total_pieces?: number;
  pieces_per_unit?: number;
  is_bulk_sale?: boolean;
  productId?: string;
  // Add for debugging
  originalData?: any;
}

export interface CashProduct {
  id?: string;
  items: SaleItem[];
  total: number;
  totalCost: number;
  profit: number;
  profitMargin: number;
  paymentMethod: 'cash';
  amountPaid: number;
  change: number;
  status: 'completed';
  receipt_image: string;
  created_at: any;
  employee_id: string;
  store_owner_id: string;
  customerName?: string;
  customerPhone?: string;
  employeeName?: string;
  // Add for debugging
  rawItems?: any[];
}

export interface DebtProduct {
  id?: string;
  firestoreId?: string;
  items: SaleItem[];
  total: number;
  totalCost: number;
  profit: number;
  profitMargin: number;
  originalSalesTotal: number;
  paymentMethod: 'debt';
  customerName: string;
  customerPhone: string;
  dueDate: any;
  status: 'pending' | 'paid' | 'overdue';
  receipt_image: string;
  created_at: any;
  store_owner_id: string;
  employee_id: string;
  employeeName?: string;
  initialPayment?: number;
  remainingBalance?: number;
  originalTotal?: number;
  payment_status: 'unpaid' | 'partially_paid' | 'paid';
  payments?: PaymentHistory[];
  [key: string]: any;
  // Add for debugging
  rawItems?: any[];
}

export interface PaymentHistory {
  amount: number;
  paymentDate: any;
  receipt_image?: string;
  paid_by?: string;
  notes?: string;
}

// Add this type declaration after your imports (before the component class)
declare module 'jspdf' {
  interface jsPDF {
    lastAutoTable?: {
      finalY: number;
    };
  }
}

@Component({
  selector: 'app-storeowner-tab2',
  templateUrl: './tab2.page.html',
  styleUrls: ['./tab2.page.scss'],
  standalone: false,
})
export class Tab2Page implements OnInit {
  cashProducts: CashProduct[] = [];
  debtProducts: DebtProduct[] = [];
  
  selectedCashProduct: CashProduct | null = null;
  selectedDebtProduct: DebtProduct | null = null;
  
  showCashReceiptModal = false;
  showDebtReceiptModal = false;
  showPaymentModal = false;
  
  segmentValue: 'cash' | 'debt' = 'cash';
  
  // Payment modal properties
  paymentAmount: number = 0;
  paymentNotes: string = '';
  selectedDebtForPayment: DebtProduct | null = null;
  
  // Search and filter
  searchTerm: string = '';
  statusFilter: string = 'all';
  searchTimeout: any;

  // Add these properties to your existing component
  showReportModal = false;
  reportType: 'cash' | 'debt' | 'combined' = 'combined';
  reportStartDate: string = '';
  reportEndDate: string = '';
  reportDebtStatus: string = 'all';
  showPreview = false;


  constructor(
    private firestore: Firestore,
    private authService: AuthService,
    private loadingController: LoadingController,
    private toastController: ToastController,
    private modalController: ModalController,
    private alertController: AlertController
  ) { }

  async ngOnInit() {
    await this.loadSalesData();
  }
// Alternative debug method without productId
async debugProductCosts(): Promise<void> {
  console.log('🔍 DEBUG: Checking product cost data...');
  
  // Check a few products to see their cost data
  const sampleProducts = this.cashProducts.slice(0, 3);
  
  for (const product of sampleProducts) {
    console.log('--- Product Analysis ---');
    console.log('Cash Product ID:', product.id);
    console.log('Total Sales:', product.total);
    console.log('Total Cost:', product.totalCost);
    console.log('Profit:', product.profit);
    console.log('Margin:', product.profitMargin?.toFixed(1) + '%');
    
    if (product.items && product.items.length > 0) {
      for (const item of product.items) {
        console.log('📦 Item:', item.name);
        console.log('  ID:', item.id);
        console.log('  Quantity:', item.quantity);
        console.log('  Selling Price:', item.sellingPrice);
        console.log('  Cost Price:', item.costPrice);
        console.log('  Total Selling:', item.totalSelling);
        console.log('  Total Cost:', item.totalCost);
        console.log('  Profit:', item.profit);
        
        const itemMargin = item.totalSelling > 0 ? (item.profit / item.totalSelling) * 100 : 0;
        console.log('  Margin:', itemMargin.toFixed(1) + '%');
        console.log('  Is Bulk Sale:', item.is_bulk_sale);
        
        // Use the item's id to look up in products collection
        // This assumes the item.id matches the product document ID in Firestore
        if (item.id) {
          const { doc, getDoc } = await import('@angular/fire/firestore');
          const productDoc = await getDoc(doc(this.firestore, 'products', item.id));
          if (productDoc.exists()) {
            const data = productDoc.data();
            console.log('  🔥 Firestore Product Data for ID', item.id, ':', {
              cost_price: data?.['cost_price'],
              selling_price: data?.['selling_price'],
              pieces: data?.['pieces'],
              unit: data?.['unit']
            });
            
            // Check if cost data is missing
            if (!data?.['cost_price'] && data?.['cost_price'] !== 0) {
              console.log('  ❌ MISSING COST DATA - cost_price is undefined or null');
              console.log('  Available fields:', Object.keys(data || {}));
            }
          } else {
            console.log('  ❌ No product found in Firestore with ID:', item.id);
          }
        }
      }
    }
    console.log('--- End Product Analysis ---');
  }
}

async debugProblematicTransactions(): Promise<void> {
  console.log('🔍 DEBUG: Problematic Transactions Analysis');
  
  // Find the specific transactions with problematic items
  const problematicTransactionIds = [
    'RCP-1764249150765-833',
    'RCP-1764309349375-927'
  ];
  
  const problematicTransactions = [
    ...this.cashProducts.filter(tx => problematicTransactionIds.includes(tx.id!)),
    ...this.debtProducts.filter(tx => problematicTransactionIds.includes(tx.id!))
  ];
  
  console.log('📦 Raw data from problematic transactions:');
  problematicTransactions.forEach(tx => {
    console.log(`Transaction: ${tx.id}`, {
      items: tx.items,
      rawItems: tx['rawItems'] // Check if we have original data
    });
    
    // Check each item in detail
    tx.items?.forEach((item, index) => {
      console.log(`  Item ${index}:`, {
        id: item.id,
        name: item.name,
        originalData: item['originalData'],
        hasProductId: !!item.id,
        hasProductName: !!item.name,
        sellingPrice: item.sellingPrice,
        quantity: item.quantity,
        totalSelling: item.totalSelling
      });
    });
  });
}

// Call this method after loadSalesData to see what's happening
async loadSalesData() {
  const loading = await this.loadingController.create({
    message: 'Loading sales data...'
  });
  await loading.present();

  try {
    await Promise.all([
      this.loadCashProducts(),
      this.loadDebtProducts()
    ]);
    
    // NEW: Calculate profit after loading data
    await this.calculateProfitForSales();
    
    // DEBUG: Check the results
    await this.debugProductCosts();
    await this.debugTopProducts();
    
  } catch (error) {
    console.error('Error loading sales data:', error);
    this.showToast('Error loading sales data', 'danger');
  } finally {
    await loading.dismiss();
  }
}
private debugItemMapping(items: any[]): void {
  console.log('🔍 DEBUG ITEM MAPPING:');
  items.forEach((item, index) => {
    console.log(`Item ${index}:`, {
      // Raw data from Firestore
      rawProductId: item.product_id,
      rawName: item.product_name, 
      rawPrice: item.price,
      // All available fields
      allFields: Object.keys(item),
      // After normalization
      normalizedId: item.id,
      normalizedName: item.name,
      normalizedSellingPrice: item.sellingPrice
    });
  });
}
async loadCashProducts() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) {
      throw new Error('User not authenticated');
    }

    console.log('Loading cash products for store owner:', storeOwnerId);

    const cashProductsRef = collection(this.firestore, 'cash_products');
    
    const q = query(
      cashProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    const querySnapshot = await getDocs(q);
    
      const cashProducts = querySnapshot.docs.map(doc => {
        const data = doc.data();
        console.log('📦 Raw cash product data:', data);
        
        return {
          id: data['id'] || doc.id,
          items: (data['items'] || []).map((item: any) => this.normalizeItemData(item)),
          total: data['total'] || 0,
          // NEW: Add default profit values
          totalCost: 0, // Will be calculated later
          profit: 0, // Will be calculated later
          profitMargin: 0, // Will be calculated later
          paymentMethod: data['paymentMethod'] || 'cash',
          amountPaid: data['amountPaid'] || 0,
          change: data['change'] || 0,
          status: data['status'] || 'completed',
          receipt_image: data['receipt_image'] || '',
          created_at: data['created_at'] || null,
          employee_id: data['employee_id'] || '',
          store_owner_id: data['store_owner_id'] || '',
          customerName: data['customerName'] || '',
          customerPhone: data['customerPhone'] || '',
          employeeName: '', // Will be populated below
          rawItems: data['items'] || []
        } as CashProduct;
      });

    // Get unique employee IDs from all cash products
    const employeeIds = [...new Set(cashProducts.map(product => product.employee_id).filter(id => id))];
    
    // Pre-fetch all employee names
    const employeeNamesMap = await this.getEmployeeNamesMap(employeeIds);
    
    // Assign employee names to each cash product
    this.cashProducts = cashProducts.map(product => ({
      ...product,
      employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
    }));

    // Sort by date (newest first)
    this.cashProducts.sort((a, b) => {
      const dateA = a.created_at?.toDate ? a.created_at.toDate() : new Date(a.created_at);
      const dateB = b.created_at?.toDate ? b.created_at.toDate() : new Date(b.created_at);
      return dateB.getTime() - dateA.getTime();
    });

    console.log(`✅ Loaded ${this.cashProducts.length} cash products for store owner`);
    
    // Log the first product to verify data structure
    if (this.cashProducts.length > 0) {
      const sampleProduct = this.cashProducts[0];
      console.log('✅ Sample loaded product:', {
        id: sampleProduct.id,
        total: sampleProduct.total,
        amountPaid: sampleProduct.amountPaid,
        change: sampleProduct.change,
        items: sampleProduct.items.map(item => ({
          name: item.name,
          id: item.id,
          sellingPrice: item.sellingPrice,
          quantity: item.quantity,
          subtotal: item.totalSelling,
          unit: item.unit
        }))
      });
    }
    
  } catch (error) {
    console.error('Error loading cash products:', error);
    this.cashProducts = [];
  }
}

async loadDebtProducts() {
  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.id;
    
    if (!storeOwnerId) {
      throw new Error('User not authenticated');
    }

    console.log('Loading debt products for store owner:', storeOwnerId);

    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    const q = query(
      debtProductsRef,
      where('store_owner_id', '==', storeOwnerId)
    );
    
    const querySnapshot = await getDocs(q);
    
    // Load all debt products first with default profit values
    const debtProducts = querySnapshot.docs.map(doc => {
      const data = doc.data();
      
      // DEBUG: Log raw items for problematic transactions
      if (data['id'] === 'RCP-1764249150765-833' || data['id'] === 'RCP-1764309349375-927') {
        console.log(`🔍 RAW DEBT ITEMS for ${data['id']}:`, data['items']);
      }
      
      // ✅ FIXED: Calculate remainingBalance properly with null safety
      const total = data['total'] || 0;
      const remainingBalance = data['remainingBalance'] ?? total;
      const initialPayment = data['initialPayment'] || 0;
      const payments = data['payments'] || [];
      
      // Determine payment_status based on actual data
      let payment_status = data['payment_status'] || 'unpaid';
      if (remainingBalance <= 0) {
        payment_status = 'paid';
      } else if (initialPayment > 0 || payments.length > 0) {
        payment_status = 'partially_paid';
      }
      
      return {
        items: (data['items'] || []).map((item: any) => this.normalizeItemData(item)), // NORMALIZE HERE
        total: total,
        // NEW: Add default profit values
        totalCost: 0, // Will be calculated later
        profit: 0, // Will be calculated later
        profitMargin: 0, // Will be calculated later
        paymentMethod: data['paymentMethod'] || 'debt',
        customerName: data['customerName'] || '',
        customerPhone: data['customerPhone'] || '',
        dueDate: data['dueDate'] || null,
        status: data['status'] || 'pending',
        receipt_image: data['receipt_image'] || '',
        created_at: data['created_at'] || null,
        store_owner_id: data['store_owner_id'] || '',
        employee_id: data['employee_id'] || '',
        payment_status: payment_status,
        id: data['id'] || doc.id,
        firestoreId: doc.id,
        initialPayment: initialPayment,
        remainingBalance: remainingBalance,
        originalTotal: data['originalTotal'] || total,
        payments: payments,
        employeeName: '',
        rawItems: data['items'] || [] // Store raw items for debugging
      } as DebtProduct; // Explicit type assertion
    });

    // Get unique employee IDs from all debt products
    const employeeIds = [...new Set(debtProducts.map(product => product.employee_id).filter(id => id))];
    
    // Pre-fetch all employee names
    const employeeNamesMap = await this.getEmployeeNamesMap(employeeIds);
    
    // Assign employee names to each debt product
    this.debtProducts = debtProducts.map(product => ({
      ...product,
      employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
    }));

    // CRITICAL: Update statuses after loading
    this.updateDebtStatuses();
    console.log(`Loaded ${this.debtProducts.length} debt products for store owner`);
    
  } catch (error) {
    console.error('Error loading debt products:', error);
    this.debtProducts = [];
  }
}

// More efficient version that only queries for specific employee IDs
async getEmployeeNamesMap(employeeIds: string[]): Promise<{ [key: string]: string }> {
  const employeeNamesMap: { [key: string]: string } = {};
  
  if (!employeeIds.length) return employeeNamesMap;

  try {
    console.log('🔍 Efficiently fetching employee names for IDs:', employeeIds);
    
    const usersRef = collection(this.firestore, 'all_users');
    
    // Since we can't use 'in' with document IDs directly, we'll query each one
    for (const employeeId of employeeIds) {
      try {
        const userDoc = doc(this.firestore, 'all_users', employeeId);
        const { getDoc } = await import('@angular/fire/firestore');
        const docSnapshot = await getDoc(userDoc);
        
        if (docSnapshot.exists()) {
          const userData = docSnapshot.data();
          const userRole = userData['role'];
          
          if (userRole === 'Employee') {
            const employeeName = userData['full_name'] || userData['name'] || userData['displayName'] || 'Unknown Employee';
            employeeNamesMap[employeeId] = employeeName;
            console.log(`✅ Found employee: ${employeeId} -> ${employeeName}`);
          } else {
            employeeNamesMap[employeeId] = 'Unknown Employee';
            console.log(`❌ User ${employeeId} is not an Employee (Role: ${userRole})`);
          }
        } else {
          employeeNamesMap[employeeId] = 'Unknown Employee';
          console.log(`❌ Employee document ${employeeId} not found`);
        }
      } catch (error) {
        console.error(`Error fetching employee ${employeeId}:`, error);
        employeeNamesMap[employeeId] = 'Unknown Employee';
      }
    }
    
    console.log('✅ Final employee names map:', employeeNamesMap);
    return employeeNamesMap;
    
  } catch (error) {
    console.error('Error in getEmployeeNamesMapEfficient:', error);
    const defaultMap: { [key: string]: string } = {};
    employeeIds.forEach(id => defaultMap[id] = 'Unknown Employee');
    return defaultMap;
  }
}

async getEmployeeName(employeeId: string): Promise<string> {
  if (!employeeId) return 'Unknown Employee';
  
  try {
    console.log('🔍 Fetching employee name for ID:', employeeId);
    
    const employeesRef = collection(this.firestore, 'employees');
    
    // Try multiple possible ID fields since structure might vary
    let q = query(employeesRef, where('id', '==', employeeId));
    let querySnapshot = await getDocs(q);
    
    if (querySnapshot.empty) {
      // Try with document ID
      q = query(employeesRef, where('employee_id', '==', employeeId));
      querySnapshot = await getDocs(q);
    }
    
    if (querySnapshot.empty) {
      // Try with uid field
      q = query(employeesRef, where('uid', '==', employeeId));
      querySnapshot = await getDocs(q);
    }
    
    if (querySnapshot.empty) {
      // Try getting by document ID directly
      const employeeDoc = doc(this.firestore, 'employees', employeeId);
      const docSnapshot = await getDocs(query(collection(this.firestore, 'employees'), where('__name__', '==', employeeId)));
      if (!docSnapshot.empty) {
        querySnapshot = docSnapshot;
      }
    }
    
    if (!querySnapshot.empty) {
      const employeeData = querySnapshot.docs[0].data();
      const employeeName = employeeData['full_name'] || employeeData['name'] || employeeData['displayName'] || 'Unknown Employee';
      console.log('✅ Found employee:', employeeName);
      return employeeName;
    }
    
    console.log('❌ No employee found with ID:', employeeId);
    return 'Unknown Employee';
  } catch (error) {
    console.error('Error fetching employee name:', error);
    return 'Unknown Employee';
  }
}
// Add this method to refresh employee names before generating reports
async refreshEmployeeNamesForReport() {
  console.log('🔄 Refreshing employee names for report...');
  
  // Get all unique employee IDs from both cash and debt products
  const allEmployeeIds = [
    ...new Set([
      ...this.cashProducts.map(p => p.employee_id),
      ...this.debtProducts.map(p => p.employee_id)
    ].filter(id => id))
  ];

  if (allEmployeeIds.length === 0) {
    console.log('No employee IDs found to refresh');
    return;
  }

  const employeeNamesMap = await this.getEmployeeNamesMap(allEmployeeIds);

  // Update cash products
  this.cashProducts = this.cashProducts.map(product => ({
    ...product,
    employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
  }));

  // Update debt products
  this.debtProducts = this.debtProducts.map(product => ({
    ...product,
    employeeName: employeeNamesMap[product.employee_id] || 'Unknown Employee'
  }));

  console.log('✅ Employee names refreshed for report');
}

// updateDebtStatuses() {
//   const now = new Date();
  
//   console.log('🔄 updateDebtStatuses - Checking all debts:');
  
//   this.debtProducts.forEach(debt => {
//     console.log('🔍 Checking debt:', {
//       customer: debt.customerName,
//       remainingBalance: debt.remainingBalance,
//       initialPayment: debt.initialPayment,
//       currentPaymentStatus: debt.payment_status
//     });

//     // CRITICAL: Use the actual remaining balance from Firestore first
//     // If remainingBalance is explicitly set to 0, mark as paid
//     if (debt.remainingBalance === 0) {
//       debt.payment_status = 'paid';
//       debt.status = 'paid';
//       console.log('✅ Setting to PAID - remaining balance is 0');
//     }
//     // Update payment_status based on remaining balance
//     else if (debt.remainingBalance !== undefined && debt.remainingBalance !== null) {
//       if (debt.remainingBalance <= 0) {
//         debt.payment_status = 'paid';
//         debt.status = 'paid';
//         console.log('✅ Setting to PAID - no balance remaining');
//       } else if (debt.initialPayment && debt.initialPayment > 0) {
//         debt.payment_status = 'partially_paid';
//         console.log('🟡 Setting to PARTIALLY_PAID - has initial payment');
//       } else {
//         debt.payment_status = 'unpaid';
//         console.log('🔴 Setting to UNPAID - no payments made');
//       }
//     }
    
//     // Update status based on due date (only if not already paid)
//     if (debt.payment_status !== 'paid' && debt.dueDate) {
//       const dueDate = debt.dueDate.toDate ? debt.dueDate.toDate() : new Date(debt.dueDate);
//       if (dueDate < now) {
//         debt.status = 'overdue';
//         console.log('⏰ Setting to OVERDUE - past due date');
//       } else {
//         debt.status = 'pending';
//         console.log('⏳ Setting status to PENDING - not due yet');
//       }
//     }

//     console.log('📊 Final status:', {
//       payment_status: debt.payment_status,
//       status: debt.status,
//       remainingBalance: debt.remainingBalance
//     });
//     console.log('---');
//   });
// }
updateDebtStatuses() {
  const now = new Date();
  
  console.log('🔄 updateDebtStatuses - Checking all debts:');
  
  this.debtProducts.forEach(debt => {
    // ✅ FIXED: Proper null safety checks with explicit defaults
    const remainingBalance = debt.remainingBalance ?? debt.total ?? 0;
    const initialPayment = debt.initialPayment ?? 0;
    const currentPaymentStatus = debt.payment_status;
    const payments = debt.payments ?? []; // ✅ FIXED: Ensure payments is always an array
    
    console.log('🔍 Checking debt:', {
      customer: debt.customerName,
      remainingBalance: remainingBalance,
      initialPayment: initialPayment,
      currentPaymentStatus: currentPaymentStatus,
      paymentsCount: payments.length,
      firestoreId: debt.firestoreId
    });

    // ✅ FIXED: ALWAYS recalculate payment_status based on remainingBalance
    // This ensures UI consistency with the actual data
    if (remainingBalance <= 0) {
      debt.payment_status = 'paid';
      debt.remainingBalance = 0; // ✅ Ensure it's explicitly set to 0
      console.log('✅ Setting to PAID - remaining balance is 0 or negative');
    } else if (initialPayment > 0 || payments.length > 0) {
      debt.payment_status = 'partially_paid';
      console.log('🟡 Setting to PARTIALLY_PAID - has payments made');
    } else {
      debt.payment_status = 'unpaid';
      console.log('🔴 Setting to UNPAID - no payments made');
    }

    // ✅ FIXED: Update status based on payment_status AND due date
    if (debt.payment_status === 'paid') {
      debt.status = 'paid';
      console.log('✅ Setting status to PAID - payment_status is paid');
    } else {
      // Only check due date for unpaid/partially paid debts
      if (debt.dueDate) {
        try {
          const dueDate = debt.dueDate.toDate ? debt.dueDate.toDate() : new Date(debt.dueDate);
          if (dueDate < now) {
            debt.status = 'overdue';
            console.log('⏰ Setting status to OVERDUE - past due date');
          } else {
            debt.status = 'pending';
            console.log('⏳ Setting status to PENDING - not due yet');
          }
        } catch (error) {
          console.error('❌ Error parsing due date:', error);
          debt.status = 'pending';
          console.log('⏳ Setting status to PENDING - invalid due date');
        }
      } else {
        debt.status = 'pending';
        console.log('⏳ Setting status to PENDING - no due date');
      }
    }

    // ✅ CRITICAL: Ensure remainingBalance is consistent
    if (debt.payment_status === 'paid') {
      debt.remainingBalance = 0;
    }

    console.log('📊 Final status:', {
      payment_status: debt.payment_status,
      status: debt.status,
      remainingBalance: debt.remainingBalance,
      calculatedRemainingBalance: remainingBalance
    });
    console.log('---');
  });
}

// Enhanced refreshDebtStatus method
async refreshDebtStatus(debtProduct: DebtProduct): Promise<boolean> {
  try {
    if (!debtProduct.firestoreId) {
      console.error('❌ Cannot refresh status: No firestoreId');
      return false;
    }

    const { doc, getDoc } = await import('@angular/fire/firestore');
    const debtProductRef = doc(this.firestore, 'debt_products', debtProduct.firestoreId);
    const docSnapshot = await getDoc(debtProductRef);
    
    if (docSnapshot.exists()) {
      const data = docSnapshot.data();
      
      console.log('🔄 Fresh data from Firestore:', {
        remainingBalance: data['remainingBalance'],
        payment_status: data['payment_status'],
        status: data['status']
      });
      
      // Update the local debt product with fresh data
      const index = this.debtProducts.findIndex(d => d.firestoreId === debtProduct.firestoreId);
      if (index !== -1) {
        this.debtProducts[index].remainingBalance = data['remainingBalance'];
        this.debtProducts[index].payment_status = data['payment_status'];
        this.debtProducts[index].status = data['status'];
        this.debtProducts[index].initialPayment = data['initialPayment'];
        this.debtProducts[index].payments = data['payments'] || [];
        
        console.log('✅ Successfully updated local debt data:', {
          customer: this.debtProducts[index].customerName,
          remainingBalance: this.debtProducts[index].remainingBalance,
          payment_status: this.debtProducts[index].payment_status,
          status: this.debtProducts[index].status
        });
        
        return true;
      } else {
        console.log('❌ Debt not found in local array');
        return false;
      }
    } else {
      console.log('❌ Document not found in Firestore');
      return false;
    }
  } catch (error) {
    console.error('❌ Error refreshing debt status:', error);
    return false;
  }
}

  // Cash Products Methods
  viewCashReceipt(cashProduct: CashProduct) {
    this.selectedCashProduct = cashProduct;
    this.showCashReceiptModal = true;
  }

  closeCashReceiptModal() {
    this.showCashReceiptModal = false;
    this.selectedCashProduct = null;
  }

  // Debt Products Methods - UPDATED
async viewDebtReceipt(debtProduct: DebtProduct) {
  try {
    console.log('📄 Opening debt receipt for:', debtProduct.customerName);
    
    // First, refresh the debt data from Firestore to get the latest status
    await this.refreshDebtStatus(debtProduct);
    
    // Find the updated debt in the local array
    const updatedDebt = this.debtProducts.find(d => d.firestoreId === debtProduct.firestoreId);
    
    if (updatedDebt) {
      // Use the updated data
      this.selectedDebtProduct = { ...updatedDebt };
      console.log('✅ Using updated debt data:', {
        customer: this.selectedDebtProduct.customerName,
        remainingBalance: this.selectedDebtProduct.remainingBalance,
        payment_status: this.selectedDebtProduct.payment_status,
        status: this.selectedDebtProduct.status
      });
    } else {
      // Fallback to the original data
      this.selectedDebtProduct = debtProduct;
      console.log('⚠️ Using original debt data (not found in updated array)');
    }
    
    this.showDebtReceiptModal = true;
    
  } catch (error) {
    console.error('❌ Error opening debt receipt:', error);
    // Fallback: use the original data
    this.selectedDebtProduct = debtProduct;
    this.showDebtReceiptModal = true;
    this.showToast('Error loading receipt details', 'warning');
  }
}

  closeDebtReceiptModal() {
    this.showDebtReceiptModal = false;
    this.selectedDebtProduct = null;
  }

// REPLACE your modal-related methods with these enhanced versions

// Enhanced openPaymentModal with explicit modal state management
openPaymentModal(debtProduct: DebtProduct): void {
  console.log('💳 Opening payment modal for:', debtProduct.customerName);
  
  // CRITICAL: Ensure all other modals are closed first
  this.showCashReceiptModal = false;
  this.showDebtReceiptModal = false;
  
  try {
    // Create a deep copy to avoid reference issues
    this.selectedDebtForPayment = JSON.parse(JSON.stringify(debtProduct));
    
    // Ensure selectedDebtForPayment is not null before accessing properties
    if (!this.selectedDebtForPayment) {
      throw new Error('Failed to create debt copy');
    }
    
    // Ensure all required fields exist
    if (this.selectedDebtForPayment.remainingBalance === undefined || 
        this.selectedDebtForPayment.remainingBalance === null) {
      this.selectedDebtForPayment.remainingBalance = this.selectedDebtForPayment.total;
    }
    
    if (!this.selectedDebtForPayment.originalTotal) {
      this.selectedDebtForPayment.originalTotal = this.selectedDebtForPayment.total;
    }
    
    // Set payment amount to remaining balance
    const remainingBalance = this.selectedDebtForPayment.remainingBalance ?? this.selectedDebtForPayment.total;
    this.paymentAmount = remainingBalance > 0 ? remainingBalance : 0;
    this.paymentNotes = '';
    
    // Small delay to ensure other modals are dismissed
    setTimeout(() => {
      this.showPaymentModal = true;
      console.log('✅ Payment modal state set to true');
    }, 100);
    
    console.log('📊 Payment modal data prepared:', {
      customer: this.selectedDebtForPayment.customerName,
      remainingBalance: this.selectedDebtForPayment.remainingBalance,
      paymentAmount: this.paymentAmount,
      modalState: this.showPaymentModal
    });
    
  } catch (error) {
    console.error('❌ Error in openPaymentModal:', error);
    this.showToast('Error opening payment modal', 'danger');
  }
}

// Enhanced openPaymentModalFromDebtReceipt
async openPaymentModalFromDebtReceipt(debtProduct: DebtProduct): Promise<void> {
  console.log('💳 Opening payment modal from debt receipt for:', debtProduct.customerName);
  
  try {
    // Store the debt product data FIRST (before closing anything)
    const debtCopy: DebtProduct = JSON.parse(JSON.stringify(debtProduct));
    
    // Ensure all required fields exist
    if (debtCopy.remainingBalance === undefined || debtCopy.remainingBalance === null) {
      debtCopy.remainingBalance = debtCopy.total;
    }
    
    if (!debtCopy.originalTotal) {
      debtCopy.originalTotal = debtCopy.total;
    }
    
    // Prepare the payment data
    this.selectedDebtForPayment = debtCopy;
    this.paymentAmount = debtCopy.remainingBalance > 0 ? debtCopy.remainingBalance : 0;
    this.paymentNotes = '';
    
    console.log('📋 Payment data prepared, closing debt modal...');
    
    // Close the debt receipt modal
    this.showDebtReceiptModal = false;
    this.selectedDebtProduct = null;
    
    // Wait longer for modal animation to complete
    await new Promise(resolve => setTimeout(resolve, 400));
    
    console.log('🔄 Opening payment modal...');
    
    // Now open the payment modal
    this.showPaymentModal = true;
    
    // Verify modal opened
    setTimeout(() => {
      console.log('🔍 Modal verification:', {
        showPaymentModal: this.showPaymentModal,
        selectedDebtForPayment: !!this.selectedDebtForPayment,
        customerName: this.selectedDebtForPayment?.customerName
      });
    }, 100);
    
    console.log('✅ Payment modal opened successfully');
    
  } catch (error) {
    console.error('❌ Error in openPaymentModalFromDebtReceipt:', error);
    this.showToast('Error opening payment modal', 'danger');
  }
}

// Enhanced closePaymentModal
closePaymentModal(): void {
  console.log('🔒 Closing payment modal');
  this.showPaymentModal = false;
  
  // Delay clearing data to allow modal animation
  setTimeout(() => {
    this.selectedDebtForPayment = null;
    this.paymentAmount = 0;
    this.paymentNotes = '';
    console.log('✅ Payment modal data cleared');
  }, 300);
}

async processPayment(): Promise<void> {
  if (!this.selectedDebtForPayment) {
    console.error('❌ No debt selected for payment');
    this.showToast('No debt selected for payment', 'danger');
    return;
  }

  // Store reference before potential null issues
  const debtToUpdate = this.selectedDebtForPayment;
  
  console.log('🔄 Processing payment:', {
    amount: this.paymentAmount,
    customer: debtToUpdate.customerName,
    maxAmount: this.maxPaymentAmount
  });

  const maxAmount = this.maxPaymentAmount;
  
  // Validation
  if (!this.paymentAmount || this.paymentAmount <= 0) {
    this.showToast('Please enter a valid payment amount', 'warning');
    return;
  }
  
  if (this.paymentAmount > maxAmount) {
    this.showToast(`Payment cannot exceed ${this.formatCurrency(maxAmount)}`, 'warning');
    return;
  }

  const loading = await this.loadingController.create({
    message: 'Processing payment...',
    spinner: 'crescent'
  });
  await loading.present();

  try {
    console.log('💰 Recording payment to Firestore...');
    
    await this.recordDebtPayment(
      debtToUpdate, 
      this.paymentAmount, 
      this.paymentNotes || undefined
    );
    
    console.log('✅ Payment recorded successfully');
    
    // CRITICAL: Refresh the specific debt status immediately
    await this.refreshDebtStatus(debtToUpdate);
    
    // Close modal and show success
    this.closePaymentModal();
    this.showToast(`Payment of ${this.formatCurrency(this.paymentAmount)} recorded successfully!`, 'success');
    
    // Also reload all data to ensure consistency
    await this.loadDebtProducts();
    
  } catch (error: any) {
    console.error('❌ Error processing payment:', error);
    this.showToast(
      error?.message || 'Error processing payment. Please try again.', 
      'danger'
    );
  } finally {
    await loading.dismiss();
  }
}

// Enhanced debug method
debugPaymentModal(): void {
  const debugInfo = {
    'Modal State': this.showPaymentModal,
    'Has Debt Selected': !!this.selectedDebtForPayment,
    'Customer Name': this.selectedDebtForPayment?.customerName || 'N/A',
    'Payment Amount': this.paymentAmount,
    'Max Payment': this.maxPaymentAmount,
    'Remaining Balance': this.selectedDebtForPayment?.remainingBalance || 0,
    'Total Debt': this.selectedDebtForPayment?.total || 0,
    'Firestore ID': this.selectedDebtForPayment?.firestoreId || 'N/A'
  };
  
  console.log('🔍 ===== PAYMENT MODAL DEBUG INFO =====');
  console.table(debugInfo);
  console.log('Full Debt Object:', this.selectedDebtForPayment);
  console.log('=====================================');
  
  // Also show in alert for easier viewing
  this.alertController.create({
    header: 'Payment Modal Debug',
    message: Object.entries(debugInfo)
      .map(([key, value]) => `${key}: ${value}`)
      .join('<br>'),
    buttons: ['Close']
  }).then(alert => alert.present());
}

// Updated getter with proper null safety
get maxPaymentAmount(): number {
  if (!this.selectedDebtForPayment) {
    console.log('❌ maxPaymentAmount: No debt selected');
    return 0;
  }
  
  // Store in local variable after null check
  const debt = this.selectedDebtForPayment;
  const remaining = debt.remainingBalance ?? debt.total ?? 0;
  const max = remaining > 0 ? remaining : debt.total ?? 0;
  
  console.log('📊 maxPaymentAmount calculated:', max);
  return max;
}

// // Test method for debugging (remove after fixing)
// testPaymentModal(): void {
//   console.log('🧪 Testing payment modal with dummy data');
  
//   // Create dummy debt data
//   const dummyDebt: DebtProduct = {
//     id: 'test-123',
//     firestoreId: 'test-firestore-123',
//     items: [],
//     total: 1000,
//     paymentMethod: 'debt',
//     customerName: 'Test Customer',
//     customerPhone: '09123456789',
//     dueDate: new Date(),
//     status: 'pending',
//     receipt_image: '',
//     created_at: new Date(),
//     store_owner_id: 'test-owner',
//     employee_id: 'test-employee',
//     payment_status: 'unpaid',
//     remainingBalance: 1000,
//     originalTotal: 1000,
//     payments: []
//   };
  
//   this.openPaymentModal(dummyDebt);
// }

  async recordDebtPayment(debtProduct: DebtProduct, amount: number, notes?: string) {
    try {
      if (!debtProduct.firestoreId) {
        throw new Error('Debt product Firestore ID is missing');
      }

      console.log('💰 Recording payment:', {
        debtId: debtProduct.firestoreId,
        customer: debtProduct.customerName,
        amount: amount,
        currentBalance: debtProduct.remainingBalance
      });

      const { doc, getDoc, updateDoc, Timestamp } = await import('@angular/fire/firestore');
      
      const debtProductRef = doc(this.firestore, 'debt_products', debtProduct.firestoreId);
      
      const docSnapshot = await getDoc(debtProductRef);
      if (!docSnapshot.exists()) {
        throw new Error(`Debt product document not found: ${debtProduct.firestoreId}`);
      }
      
      const currentData = docSnapshot.data();
      const currentBalance = currentData['remainingBalance'] || currentData['total'] || 0;
      const newBalance = currentBalance - amount;
      
      if (newBalance < 0) {
        throw new Error('Payment amount cannot exceed remaining balance');
      }

      const paymentHistory: PaymentHistory = {
        amount: amount,
        paymentDate: Timestamp.now(),
        paid_by: this.authService.getCurrentUser()?.full_name || 'Store Owner',
        ...(notes && { notes: notes })
      };

      const currentPayments = currentData['payments'] || [];
      const updatedPayments = [...currentPayments, paymentHistory];

      const newPaymentStatus = newBalance <= 0 ? 'paid' : 'partially_paid';

      const updateData: any = {
        remainingBalance: newBalance,
        payment_status: newPaymentStatus,
        payments: updatedPayments,
        updated_at: Timestamp.now()
      };

      // Update status based on payment status
      if (newPaymentStatus === 'paid') {
        updateData.status = 'paid';
      } else if (debtProduct.dueDate) {
        const dueDate = debtProduct.dueDate.toDate ? debtProduct.dueDate.toDate() : new Date(debtProduct.dueDate);
        const now = new Date();
        updateData.status = dueDate < now ? 'overdue' : 'pending';
      }

      // If this is the first payment, also set initialPayment
      if (currentPayments.length === 0 && (!currentData['initialPayment'] || currentData['initialPayment'] === 0)) {
        updateData.initialPayment = amount;
      }

      console.log('📝 Updating debt with data:', updateData);

      await updateDoc(debtProductRef, updateData);
      console.log('✅ Payment recorded successfully');

      // Reload debt products to reflect changes
      await this.loadDebtProducts();

    } catch (error) {
      console.error('❌ Error recording debt payment:', error);
      throw error;
    }
  }

  // Utility Methods
  getStatusColor(status: string): string {
    switch (status) {
      case 'completed':
      case 'paid':
        return 'success';
      case 'pending':
        return 'warning';
      case 'overdue':
        return 'danger';
      default:
        return 'medium';
    }
  }

  getPaymentStatusColor(paymentStatus: string): string {
    switch (paymentStatus) {
      case 'paid':
        return 'success';
      case 'partially_paid':
        return 'warning';
      case 'unpaid':
        return 'danger';
      default:
        return 'medium';
    }
  }

  formatDate(date: any): string {
    if (!date) return 'N/A';
    
    try {
      const jsDate = date.toDate ? date.toDate() : new Date(date);
      return jsDate.toLocaleDateString('en-PH', {
        year: 'numeric',
        month: 'short',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
      });
    } catch (error) {
      return 'Invalid Date';
    }
  }

  formatCurrency(amount: number): string {
    return `PHP ${amount?.toFixed(2) || '0.00'}`;
  }

  // In your filter methods, add types:
  get filteredCashProducts(): CashProduct[] {
    let filtered = this.cashProducts;

    if (this.searchTerm) {
      const term = this.searchTerm.toLowerCase();
      filtered = filtered.filter((product: CashProduct) => 
        product.customerName?.toLowerCase().includes(term) ||
        product.id?.toLowerCase().includes(term) ||
        product.employeeName?.toLowerCase().includes(term) ||
        this.formatCurrency(product.total).toLowerCase().includes(term)
      );
    }

    return filtered;
  }

    get filteredDebtProducts(): DebtProduct[] {
      let filtered = this.debtProducts;

      if (this.searchTerm) {
        const term = this.searchTerm.toLowerCase();
        filtered = filtered.filter((product: DebtProduct) => 
          product.customerName?.toLowerCase().includes(term) ||
          product.customerPhone?.toLowerCase().includes(term) ||
          product.id?.toLowerCase().includes(term) ||
          product.employeeName?.toLowerCase().includes(term)
        );
      }

      if (this.statusFilter !== 'all') {
        filtered = filtered.filter((product: DebtProduct) => 
          this.statusFilter === 'overdue' ? 
          product.status === 'overdue' : 
          product.payment_status === this.statusFilter
        );
      }

      return filtered;
    }

  // Summary Methods
  getTodayCashTotal(): number {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    return this.cashProducts
      .filter(product => {
        const productDate = product.created_at?.toDate ? product.created_at.toDate() : new Date(product.created_at);
        productDate.setHours(0, 0, 0, 0);
        return productDate.getTime() === today.getTime();
      })
      .reduce((total, product) => total + product.total, 0);
  }

  getTodayCashCount(): number {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    
    return this.cashProducts.filter(product => {
      const productDate = product.created_at?.toDate ? product.created_at.toDate() : new Date(product.created_at);
      productDate.setHours(0, 0, 0, 0);
      return productDate.getTime() === today.getTime();
    }).length;
  }

  getTotalCashSales(): number {
    return this.cashProducts.reduce((total, product) => total + product.total, 0);
  }

  getTotalOutstanding(): number {
    return this.debtProducts
      .filter(debt => debt.payment_status !== 'paid')
      .reduce((total, debt) => total + (debt.remainingBalance || debt.total), 0);
  }

  getDebtCountByStatus(status: string): number {
    return this.debtProducts.filter(debt => debt.payment_status === status).length;
  }

  // Event Handlers
  async doRefresh(event: any) {
    await this.loadSalesData();
    event.target.complete();
  }

  async doRefreshManual() {
    const loading = await this.loadingController.create({
      message: 'Refreshing data...',
      duration: 3000
    });
    
    await loading.present();
    
    try {
      await this.loadSalesData();
      this.showToast('Data refreshed successfully', 'success');
    } catch (error) {
      console.error('Error refreshing data:', error);
      this.showToast('Error refreshing data', 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  segmentChanged() {
    // The segment change will automatically update the view
  }

  searchChanged() {
    clearTimeout(this.searchTimeout);
    this.searchTimeout = setTimeout(() => {
      // The getters will automatically update the view
    }, 300);
  }

  filterChanged() {
    // The getters will automatically update the view
  }

  // TrackBy functions
  trackByCashId(index: number, item: CashProduct): string {
    return item.id || index.toString();
  }

  trackByDebtId(index: number, item: DebtProduct): string {
    return item.firestoreId || item.id || index.toString();
  }

  // Image error handler
  handleImageError(event: any, type: 'cash' | 'debt') {
    console.log('Image load error:', event);
    event.target.style.display = 'none';
  }

  // Share receipt functionality
  async shareReceipt(product: any) {
    this.showToast('Share functionality would be implemented here', 'primary');
  }

  private async showToast(message: string, color: string) {
    const toast = await this.toastController.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }

  // ADDED FOR SALES REPORT
 // Add these methods to your component

openReportModal() {
  // Set default date range to last 30 days
  const endDate = new Date();
  const startDate = new Date();
  startDate.setDate(startDate.getDate() - 30);
  
  this.reportStartDate = startDate.toISOString().split('T')[0];
  this.reportEndDate = endDate.toISOString().split('T')[0];
  this.showReportModal = true;
  this.showPreview = false;
}

closeReportModal() {
  this.showReportModal = false;
  this.showPreview = false;
}

onReportTypeChange() {
  this.updateReportData();
}

onDateFilterChange() {
  this.updateReportData();
}

setDateRange(range: 'today' | 'week' | 'month' | 'year') {
  const today = new Date();
  let startDate = new Date();
  
  switch (range) {
    case 'today':
      startDate = new Date(today);
      startDate.setHours(0, 0, 0, 0);
      break;
    case 'week':
      startDate.setDate(today.getDate() - 7);
      break;
    case 'month':
      startDate.setMonth(today.getMonth() - 1);
      break;
    case 'year':
      startDate.setFullYear(today.getFullYear() - 1);
      break;
  }
  
  this.reportStartDate = startDate.toISOString().split('T')[0];
  this.reportEndDate = today.toISOString().split('T')[0];
  this.updateReportData();
}

get filteredReportData(): any[] {
  let data: any[] = [];
  
  // Combine data based on report type
  if (this.reportType === 'cash' || this.reportType === 'combined') {
    data = [...data, ...this.cashProducts];
  }
  if (this.reportType === 'debt' || this.reportType === 'combined') {
    data = [...data, ...this.debtProducts];
  }
  
  // Filter by date range
  if (this.reportStartDate && this.reportEndDate) {
    const start = new Date(this.reportStartDate);
    const end = new Date(this.reportEndDate);
    end.setHours(23, 59, 59, 999); // Include entire end date
    
    data = data.filter((item: any) => {
      const itemDate = item.created_at?.toDate ? item.created_at.toDate() : new Date(item.created_at);
      return itemDate >= start && itemDate <= end;
    });
  }
  
  // Filter debt by status
  if (this.reportType !== 'cash' && this.reportDebtStatus !== 'all') {
    data = data.filter((item: any) => {
      if (item.paymentMethod === 'debt') {
        return this.reportDebtStatus === 'overdue' ? 
          item.status === 'overdue' : 
          item.payment_status === this.reportDebtStatus;
      }
      return true;
    });
  }
  
  return data;
}

updateReportData() {
  // This will trigger the getter to update filtered data
  this.showPreview = false;
}

previewReport() {
  this.showPreview = true;
}

getReportCashTotal(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'cash')
    .reduce((total, item) => total + item.total, 0);
}

// Fix report calculations
getReportDebtTotal(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'debt')
    .reduce((total: number, item: any) => {
      // For debt products, use originalSalesTotal if available
      if (item.originalSalesTotal) {
        return total + item.originalSalesTotal;
      }
      // Fallback: calculate from items
      return total + (item.items?.reduce((sum: number, item: SaleItem) => sum + (item.totalSelling || 0), 0) || item.total || 0);
    }, 0);
}

getReportOutstandingTotal(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'debt' && item.payment_status !== 'paid')
    .reduce((total, item) => total + (item.remainingBalance || item.total), 0);
}


async generateSalesPDF() {
  const loading = await this.loadingController.create({
    message: 'Generating Sales Report PDF...'
  });
  await loading.present();

  try {
    console.log('=== SALES PDF GENERATION STARTED ===');
    await this.refreshEmployeeNamesForReport();
    const doc = new jsPDF();
    const currentUser = this.authService.getCurrentUser();
    const storeName = currentUser?.store_name || 'Store';
    const currentDate = new Date().toLocaleDateString('en-PH');
    const currentTime = new Date().toLocaleTimeString();

    // Title Section
    doc.setFontSize(20);
    doc.setTextColor(41, 128, 185);
    doc.text('STORE SALES REPORT', 105, 20, { align: 'center' });
    
    doc.setFontSize(12);
    doc.setTextColor(100, 100, 100);
    doc.text(`${storeName}`, 105, 30, { align: 'center' });
    doc.text(`Generated on: ${currentDate} at ${currentTime}`, 105, 36, { align: 'center' });
    
    const dateRangeText = `Period: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`;
    doc.text(dateRangeText, 105, 42, { align: 'center' });

    let finalY = 50;

    // ===== PROFIT SUMMARY SECTION =====
    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('PROFIT SUMMARY', 20, finalY);
    finalY += 10;

    const profitSummaryData = [
      ['Total Cash Sales', `PHP ${this.getReportCashTotal().toFixed(2)}`],
      ['Total Cash Profit', `PHP ${this.getReportCashProfit().toFixed(2)}`],
      ['Average Cash Margin', `${this.getReportCashMargin().toFixed(3)}%`],
      ['Total Debt Sales', `PHP ${this.getReportDebtTotal().toFixed(2)}`],
      ['Total Debt Profit', `PHP ${this.getReportDebtProfit().toFixed(2)}`],
      ['Average Debt Margin', `${this.getReportDebtMargin().toFixed(3)}%`],
      ['Grand Total Sales', `PHP ${(this.getReportCashTotal() + this.getReportDebtTotal()).toFixed(2)}`],
      ['Grand Total Profit', `PHP ${(this.getReportCashProfit() + this.getReportDebtProfit()).toFixed(2)}`],
      ['Overall Margin', `${this.getReportOverallMargin().toFixed(3)}%`]
    ];

    autoTable(doc, {
      startY: finalY,
      head: [['Metric', 'Value']],
      body: profitSummaryData,
      theme: 'grid',
      headStyles: { fillColor: [66, 139, 202] },
      styles: { fontSize: 11, cellPadding: 3 }
    });

    finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;

    // ===== CASH SALES SECTION WITH PROFIT =====
    const cashTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'cash');
    if (cashTransactions.length > 0 && (this.reportType === 'cash' || this.reportType === 'combined')) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(34, 139, 34);
      doc.text(`CASH SALES WITH PROFIT (${cashTransactions.length})`, 20, finalY);
      finalY += 10;

      const cashData = cashTransactions.map(tx => [
        this.formatDateShort(tx.created_at),
        this.truncateText(tx.customerName || 'Walk-in Customer', 15),
        `PHP ${tx.total.toFixed(2)}`,
        `PHP ${tx.totalCost?.toFixed(2) || '0.00'}`,
        `PHP ${tx.profit?.toFixed(2) || '0.00'}`,
        `${(tx.profitMargin || 0).toFixed(3)}%`,
        tx.employeeName,
        `${tx.items?.length || 0} items`
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Customer', 'Sales', 'Cost', 'Profit', 'Margin', 'Employee', 'Items']],
        body: cashData,
        theme: 'grid',
        headStyles: { fillColor: [34, 139, 34] },
        styles: { fontSize: 8, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;
    }

    // ===== DEBT SALES SECTION WITH PROFIT =====
    const debtTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'debt');
    if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
      if (finalY > 250) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(14);
      doc.setTextColor(255, 165, 0);
      doc.text(`DEBT SALES WITH PROFIT (${debtTransactions.length})`, 20, finalY);
      finalY += 10;

      // In the DEBT SALES SECTION WITH PROFIT part, change:
      const debtData = debtTransactions.map(tx => [
        this.formatDateShort(tx.created_at),
        this.truncateText(tx.customerName, 15),
        // Use originalSalesTotal instead of total for sales amount
        `PHP ${(tx.originalSalesTotal || tx.items?.reduce((sum: number, item: SaleItem) => sum + (item.totalSelling || 0), 0) || 0).toFixed(2)}`,
        `PHP ${tx.totalCost?.toFixed(2) || '0.00'}`,
        `PHP ${tx.profit?.toFixed(2) || '0.00'}`,
        `${(tx.profitMargin || 0).toFixed(3)}%`,
        `PHP ${(tx.remainingBalance || tx.total).toFixed(2)}`,
        this.getPaymentStatusDisplay(tx.payment_status),
        tx.employeeName
      ]);

      autoTable(doc, {
        startY: finalY,
        head: [['Date', 'Customer', 'Sales', 'Cost', 'Profit', 'Margin', 'Balance', 'Status', 'Employee']],
        body: debtData,
        theme: 'grid',
        headStyles: { fillColor: [255, 165, 0] },
        styles: { fontSize: 7, cellPadding: 2 }
      });

      finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;
    }

    // ===== TOP PERFORMING PRODUCTS =====
    if (finalY > 250) {
      doc.addPage();
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(128, 0, 128);
    doc.text('TOP PERFORMING PRODUCTS', 20, finalY);
    finalY += 10;

    const topProducts = this.getTopPerformingProducts();
    const productData = topProducts.map((product, index) => [
      (index + 1).toString(),
      this.truncateText(product.name, 20),
      product.quantity.toString(),
      `PHP ${product.totalSales.toFixed(2)}`,
      `PHP ${product.totalCost.toFixed(2)}`,
      `PHP ${product.totalProfit.toFixed(2)}`,
      `${product.margin.toFixed(3)}%`
    ]);

    autoTable(doc, {
      startY: finalY,
      head: [['#', 'Product Name', 'Qty Sold', 'Sales', 'Cost', 'Profit', 'Margin']],
      body: productData,
      theme: 'grid',
      headStyles: { fillColor: [128, 0, 128] },
      styles: { fontSize: 8, cellPadding: 2 }
    });

    finalY = (doc as any).lastAutoTable?.finalY + 15 || finalY + 100;

    // ===== FILTER INFORMATION SECTION =====
    if (finalY > 250) {
      doc.addPage();
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(40, 40, 40);
    doc.text('REPORT INFORMATION', 20, finalY);
    finalY += 10;

    doc.setFontSize(10);
    doc.setTextColor(100, 100, 100);
    
    const filterInfo = [
      `Report Type: ${this.getReportTypeLabel()}`,
      `Date Range: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`,
      `Debt Status Filter: ${this.getDebtStatusLabel()}`,
      `Total Cash Transactions: ${cashTransactions.length}`,
      `Total Debt Transactions: ${debtTransactions.length}`,
      `Report Generated: ${currentDate} at ${currentTime}`
    ];

    filterInfo.forEach(info => {
      if (finalY > 270) {
        doc.addPage();
        finalY = 20;
      }
      doc.text(info, 20, finalY);
      finalY += 6;
    });

    // Footer
    doc.setFontSize(8);
    doc.setTextColor(150, 150, 150);
    const footerText = `Profit Analysis Report - ${storeName}`;
    doc.text(footerText, 105, doc.internal.pageSize.height - 10, { align: 'center' });

    // Save PDF
    const fileName = `profit-report-${this.reportType}-${new Date().toISOString().split('T')[0]}.pdf`;
    doc.save(fileName);

    this.showToast('Profit report downloaded successfully!', 'success');
    console.log('=== PROFIT PDF GENERATION COMPLETED ===');

  } catch (error) {
    console.error('Error generating PDF:', error);
    this.showToast('Error generating profit report', 'danger');
  } finally {
    await loading.dismiss();
  }
}
// Add these methods to your component
getReportCashProfit(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'cash')
    .reduce((total, item) => total + (item.profit || 0), 0);
}

getReportDebtProfit(): number {
  return this.filteredReportData
    .filter(item => item.paymentMethod === 'debt')
    .reduce((total, item) => total + (item.profit || 0), 0);
}

getReportCashMargin(): number {
  const cashTotal = this.getReportCashTotal();
  const cashProfit = this.getReportCashProfit();
  const margin = cashTotal > 0 ? (cashProfit / cashTotal) * 100 : 0;
  return this.formatMargin(margin);
}

getReportDebtMargin(): number {
  const debtTotal = this.getReportDebtTotal();
  const debtProfit = this.getReportDebtProfit();
  const margin = debtTotal > 0 ? (debtProfit / debtTotal) * 100 : 0;
  return this.formatMargin(margin);
}

getReportOverallMargin(): number {
  const totalSales = this.getReportCashTotal() + this.getReportDebtTotal();
  const totalProfit = this.getReportCashProfit() + this.getReportDebtProfit();
  const margin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0;
  return this.formatMargin(margin);
}

getTopPerformingProducts(): any[] {
  const productMap = new Map<string, any>();
  
  // Collect all items from both cash and debt products
  this.filteredReportData.forEach((transaction: any) => {
    if (transaction.items) {
      transaction.items.forEach((item: SaleItem) => {
        // CRITICAL FIX: Use product ID as the key, not name
        const productKey = item.id || `unknown-${item.name}`;
        
        // Get the best available name
        let productName = item.name;
        
        // If name is missing or generic, try to use ID substring as fallback
        if (!productName || 
            productName === 'Unknown Product' || 
            productName === 'N/A' ||
            productName === 'undefined' ||
            productName === 'null') {
          productName = item.id ? `Product ${item.id.substring(0, 8)}` : 'Unknown Product';
        }
        
        const existing = productMap.get(productKey);
        
        if (existing) {
          // Update existing entry
          existing.quantity += item.quantity;
          existing.totalSales += item.totalSelling || 0;
          existing.totalCost += item.totalCost || 0;
          existing.totalProfit += item.profit || 0;
        } else {
          // Create new entry
          productMap.set(productKey, {
            id: item.id || productKey,
            name: productName,
            quantity: item.quantity,
            totalSales: item.totalSelling || 0,
            totalCost: item.totalCost || 0,
            totalProfit: item.profit || 0,
            margin: (item.totalSelling || 0) > 0 ? ((item.profit || 0) / (item.totalSelling || 0)) * 100 : 0
          });
        }
      });
    }
  });
  
  // Convert map to array and sort by profit (descending)
  return Array.from(productMap.values())
    .sort((a, b) => b.totalProfit - a.totalProfit)
    .slice(0, 10);
}
// Main PDF Generation Method - FIXED
async createSalesPDF() {
  const jsPDF = (await import('jspdf')).default;
  await import('jspdf-autotable');
  
  const doc = new jsPDF();
  
  const currentUser = this.authService.getCurrentUser();
  const storeName = currentUser?.store_name || 'Store';
  const currentDate = new Date().toLocaleDateString('en-PH');
  const currentTime = new Date().toLocaleTimeString();

  // Track page numbers manually since getNumberOfPages() might not be available
  let currentPage = 1;
  const totalPages = 1; // We'll update this as we add pages

  // ===== HEADER SECTION =====
  doc.setFontSize(20);
  doc.setTextColor(41, 128, 185);
  doc.text('SALES REPORT', 105, 20, { align: 'center' });
  
  doc.setFontSize(12);
  doc.setTextColor(100, 100, 100);
  doc.text(`${storeName}`, 105, 30, { align: 'center' });
  doc.text(`Generated on: ${currentDate} at ${currentTime}`, 105, 36, { align: 'center' });
  
  const dateRangeText = `Period: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`;
  doc.text(dateRangeText, 105, 42, { align: 'center' });

  let finalY = 50;

  // ===== SUMMARY SECTION =====
  doc.setFontSize(14);
  doc.setTextColor(40, 40, 40);
  doc.text('SUMMARY OVERVIEW', 20, finalY);
  finalY += 10;

  const summaryData = [
    ['Report Type', this.getReportTypeLabel()],
    ['Date Range', `${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`],
    ['Total Transactions', this.filteredReportData.length.toString()],
    ['Cash Sales Total', `PHP ${this.getReportCashTotal().toFixed(2)}`],
    ['Debt Sales Total', `PHP ${this.getReportDebtTotal().toFixed(2)}`],
    ['Outstanding Balance', `PHP ${this.getReportOutstandingTotal().toFixed(2)}`]
  ];

  (doc as any).autoTable({
    startY: finalY,
    head: [['Metric', 'Value']],
    body: summaryData,
    theme: 'grid',
    headStyles: { fillColor: [66, 139, 202] },
    styles: { fontSize: 11, cellPadding: 3 }
  });

  finalY = (doc as any).lastAutoTable.finalY + 15;

  // ===== CASH SALES DETAILED TABLE =====
  const cashTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'cash');
  if (cashTransactions.length > 0 && (this.reportType === 'cash' || this.reportType === 'combined')) {
    if (finalY > 250) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(34, 139, 34);
    doc.text(`CASH SALES DETAILS (${cashTransactions.length} transactions)`, 20, finalY);
    finalY += 10;

    const cashData = cashTransactions.map(tx => [
      this.formatDateShort(tx.created_at),
      this.truncateText(tx.id || 'N/A', 15),
      this.truncateText(tx.customerName || 'Walk-in Customer', 18),
      this.truncateText(tx.employeeName || 'Unknown', 15),
      `PHP ${tx.total.toFixed(2)}`,
      `PHP ${tx.amountPaid.toFixed(2)}`,
      `PHP ${tx.change.toFixed(2)}`,
      (tx.items?.length || 0).toString()
    ]);

    (doc as any).autoTable({
      startY: finalY,
      head: [['Date', 'Receipt ID', 'Customer', 'Employee', 'Total', 'Paid', 'Change', 'Items']],
      body: cashData,
      theme: 'grid',
      headStyles: { fillColor: [34, 139, 34] },
      styles: { fontSize: 8, cellPadding: 2 },
      didDrawPage: (data: any) => {
        // Update current page when new page is drawn
        currentPage = data.pageNumber;
      }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;
  }

  // ===== DEBT SALES DETAILED TABLE =====
  const debtTransactions = this.filteredReportData.filter(tx => tx.paymentMethod === 'debt');
  if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
    if (finalY > 250) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(255, 165, 0);
    doc.text(`DEBT SALES DETAILS (${debtTransactions.length} transactions)`, 20, finalY);
    finalY += 10;

    const debtData = debtTransactions.map(tx => [
      this.formatDateShort(tx.created_at),
      this.truncateText(tx.customerName, 16),
      this.truncateText(tx.customerPhone || 'N/A', 12),
      this.truncateText(tx.employeeName || 'Unknown', 12),
      `PHP ${tx.total.toFixed(2)}`,
      `PHP ${(tx.initialPayment || 0).toFixed(2)}`,
      `PHP ${(tx.remainingBalance || tx.total).toFixed(2)}`,
      this.formatDateShort(tx.dueDate),
      this.getPaymentStatusDisplay(tx.payment_status),
      (tx.items?.length || 0).toString()
    ]);

    (doc as any).autoTable({
      startY: finalY,
      head: [['Date', 'Customer', 'Phone', 'Employee', 'Total', 'Paid', 'Balance', 'Due Date', 'Status', 'Items']],
      body: debtData,
      theme: 'grid',
      headStyles: { fillColor: [255, 165, 0] },
      styles: { fontSize: 7, cellPadding: 2 },
      didDrawPage: (data: any) => {
        // Update current page when new page is drawn
        currentPage = data.pageNumber;
      }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;
  }

  // ===== DEBT STATUS BREAKDOWN =====
  if (debtTransactions.length > 0 && (this.reportType === 'debt' || this.reportType === 'combined')) {
    if (finalY > 250) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }

    doc.setFontSize(14);
    doc.setTextColor(220, 53, 69);
    doc.text('DEBT STATUS BREAKDOWN', 20, finalY);
    finalY += 10;

    const statusBreakdown = this.getDebtStatusBreakdown(debtTransactions);
    const statusData = Object.entries(statusBreakdown).map(([status, count]) => [
      status,
      count.toString(),
      `PHP ${this.getDebtAmountByStatus(debtTransactions, status).toFixed(2)}`
    ]);

    (doc as any).autoTable({
      startY: finalY,
      head: [['Status', 'Count', 'Total Amount']],
      body: statusData,
      theme: 'grid',
      headStyles: { fillColor: [220, 53, 69] },
      styles: { fontSize: 10, cellPadding: 3 },
      didDrawPage: (data: any) => {
        currentPage = data.pageNumber;
      }
    });

    finalY = (doc as any).lastAutoTable.finalY + 15;
  }

  // ===== FILTER INFORMATION =====
  if (finalY > 250) {
    doc.addPage();
    currentPage++;
    finalY = 20;
  }

  doc.setFontSize(14);
  doc.setTextColor(40, 40, 40);
  doc.text('FILTER INFORMATION', 20, finalY);
  finalY += 10;

  doc.setFontSize(10);
  doc.setTextColor(100, 100, 100);
  
  const filterInfo = [
    `Report Type: ${this.getReportTypeLabel()}`,
    `Date Range: ${this.formatFilterDate(this.reportStartDate)} - ${this.formatFilterDate(this.reportEndDate)}`,
    `Debt Status Filter: ${this.getDebtStatusLabel()}`,
    `Total Cash Transactions: ${cashTransactions.length}`,
    `Total Debt Transactions: ${debtTransactions.length}`,
    `Grand Total: PHP ${(this.getReportCashTotal() + this.getReportDebtTotal()).toFixed(2)}`
  ];

  filterInfo.forEach(info => {
    if (finalY > 270) {
      doc.addPage();
      currentPage++;
      finalY = 20;
    }
    doc.text(info, 20, finalY);
    finalY += 6;
  });

  // Footer - FIXED: Use currentPage instead of getNumberOfPages()
  this.addFooterToAllPages(doc, storeName, currentDate, currentTime, currentPage);

  // Save PDF
  const fileName = `sales-report-${this.reportType}-${new Date().toISOString().split('T')[0]}.pdf`;
  doc.save(fileName);
}

private addFooterToAllPages(doc: any, storeName: string, currentDate: string, currentTime: string, totalPages: number) {
  const pageCount = totalPages;
  
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    doc.setFontSize(8);
    doc.setTextColor(150, 150, 150);
    const footerText = `Report generated by ${storeName} on ${currentDate} at ${currentTime} | Page ${i} of ${pageCount}`;
    doc.text(footerText, 105, doc.internal.pageSize.height - 10, { align: 'center' });
  }
}
private formatDateShort(date: any): string {
  if (!date) return 'N/A';
  try {
    const jsDate = date.toDate ? date.toDate() : new Date(date);
    return jsDate.toLocaleDateString('en-PH', {
      month: 'short',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit'
    });
  } catch (error) {
    return 'Invalid Date';
  }
}

private formatFilterDate(dateString: string): string {
  const date = new Date(dateString);
  return date.toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'short',
    day: 'numeric'
  });
}
async debugTopProducts(): Promise<void> {
  console.log('🔍 DEBUG: Top Performing Products Analysis');
  
  const topProducts = this.getTopPerformingProducts();
  
  console.log('📊 Top Products Raw Data:');
  topProducts.forEach((product, index) => {
    console.log(`Product ${index + 1}:`, {
      name: product.name,
      id: product.id,
      quantity: product.quantity,
      totalSales: product.totalSales,
      totalCost: product.totalCost,
      totalProfit: product.totalProfit,
      margin: product.margin
    });
  });
  
  // Check the original items that contribute to top products
  console.log('🔍 Checking source items for top products:');
  const allItems: any[] = [];
  
  this.filteredReportData.forEach((transaction: any) => {
    if (transaction.items) {
      transaction.items.forEach((item: SaleItem) => {
        allItems.push({
          transactionId: transaction.id,
          itemName: item.name,
          itemId: item.id,
          quantity: item.quantity,
          totalSelling: item.totalSelling,
          profit: item.profit
        });
      });
    }
  });
  
  // Show items that have "Unknown Product" or "N/A" names
  const problematicItems = allItems.filter(item => 
    !item.itemName || 
    item.itemName === 'Unknown Product' || 
    item.itemName === 'N/A'
  );
  
  console.log('❌ Problematic Items (missing names):', problematicItems);
  
  if (problematicItems.length > 0) {
    console.log('🔧 Suggested fixes:');
    problematicItems.forEach(item => {
      console.log(`- Item ID: ${item.itemId}, Transaction: ${item.transactionId}`);
      console.log(`  Suggested name: "Product ${item.itemId?.substring(0, 8) || 'Unknown'}"`);
    });
  }
}
private truncateText(text: string, maxLength: number): string {
  if (!text || text === 'undefined' || text === 'null' || text === 'N/A') {
    return 'Unknown';
  }
  
  const cleanText = String(text).trim();
  if (cleanText.length <= maxLength) return cleanText;
  return cleanText.substring(0, maxLength - 2) + '..';
}

private getReportTypeLabel(): string {
  const types: Record<string, string> = {
    'cash': 'Cash Sales Only',
    'debt': 'Debt Sales Only',
    'combined': 'Combined Sales'
  };
  return types[this.reportType] || 'All Sales';
}

private getDebtStatusLabel(): string {
  const statuses: Record<string, string> = {
    'all': 'All Status',
    'unpaid': 'Unpaid Only',
    'partially_paid': 'Partially Paid Only',
    'paid': 'Paid Only',
    'overdue': 'Overdue Only'
  };
  return statuses[this.reportDebtStatus] || 'All Status';
}

private getPaymentStatusDisplay(status: string): string {
  const statusMap: Record<string, string> = {
    'unpaid': 'Unpaid',
    'partially_paid': 'Partial',
    'paid': 'Paid'
  };
  return statusMap[status] || status;
}

private getDebtStatusBreakdown(debtTransactions: any[]): Record<string, number> {
  const breakdown: Record<string, number> = {
    'Unpaid': 0,
    'Partially Paid': 0,
    'Paid': 0,
    'Overdue': 0
  };

  debtTransactions.forEach((tx: any) => {
    if (tx.status === 'overdue') {
      breakdown['Overdue']++;
    } else {
      switch (tx.payment_status) {
        case 'unpaid': breakdown['Unpaid']++; break;
        case 'partially_paid': breakdown['Partially Paid']++; break;
        case 'paid': breakdown['Paid']++; break;
      }
    }
  });

  return breakdown;
}

private getDebtAmountByStatus(debtTransactions: any[], status: string): number {
  return debtTransactions
    .filter((tx: any) => {
      if (status === 'Overdue') return tx.status === 'overdue';
      switch (status) {
        case 'Unpaid': return tx.payment_status === 'unpaid';
        case 'Partially Paid': return tx.payment_status === 'partially_paid';
        case 'Paid': return tx.payment_status === 'paid';
        default: return false;
      }
    })
    .reduce((sum: number, tx: any) => sum + tx.total, 0);
}
async calculateProfitForSales() {
  try {
    console.log('💰 Calculating profit for all sales...');
    
    // Calculate profit for cash products (unchanged)
    this.cashProducts = await Promise.all(
      this.cashProducts.map(async (product) => {
        const enhancedItems = await this.calculateItemsProfit(product.items);
        const totalCost = enhancedItems.reduce((sum, item) => sum + (item.totalCost || 0), 0);
        const profit = product.total - totalCost;
        const profitMargin = product.total > 0 ? (profit / product.total) * 100 : 0;
        
        return {
          ...product,
          items: enhancedItems,
          totalCost,
          profit,
          profitMargin
        } as CashProduct;
      })
    );
    
    // FIXED: Calculate profit for debt products using ITEMS total, not the remaining balance
    this.debtProducts = await Promise.all(
      this.debtProducts.map(async (product) => {
        const enhancedItems = await this.calculateItemsProfit(product.items);
        
        // CRITICAL FIX: Calculate original sales total from items, not from product.total
        const originalSalesTotal = enhancedItems.reduce((sum, item) => sum + (item.totalSelling || 0), 0);
        const totalCost = enhancedItems.reduce((sum, item) => sum + (item.totalCost || 0), 0);
        const profit = originalSalesTotal - totalCost;
        const profitMargin = originalSalesTotal > 0 ? (profit / originalSalesTotal) * 100 : 0;
        
        return {
          ...product,
          items: enhancedItems,
          totalCost,
          profit,
          profitMargin,
          originalSalesTotal // Store the calculated original sales amount
        } as DebtProduct;
      })
    );
    
    console.log('✅ Profit calculation completed');
  } catch (error) {
    console.error('Error calculating profit:', error);
  }
}
// Add this helper method to format margins with 3 decimals
private formatMargin(margin: number): number {
  return Number(margin.toFixed(3));
}

async calculateItemsProfit(items: SaleItem[]): Promise<SaleItem[]> {
  console.log('🔄 Starting profit calculation for', items.length, 'items');
  
  return await Promise.all(
    items.map(async (item) => {
      try {
        const productId = item.id;
        console.log('🔍 Processing item:', {
          name: item.name,
          productId: productId,
          sellingPrice: item.sellingPrice,
          quantity: item.quantity,
          unit: item.unit,
          pricing_option: item.pricing_option
        });

        // If we have a valid product ID that looks like a Firestore ID (not our fallback IDs)
        if (productId && !productId.startsWith('name-') && !productId.startsWith('unknown-') && !productId.startsWith('temp-')) {
          const { doc, getDoc } = await import('@angular/fire/firestore');
          const productDoc = await getDoc(doc(this.firestore, 'products', productId));
          
          if (productDoc.exists()) {
            const productData = productDoc.data();
            console.log('📦 Product data from Firestore for', item.name, ':', {
              cost_price: productData?.['cost_price'],
              selling_price: productData?.['selling_price'],
              pieces: productData?.['pieces'],
              unit: productData?.['unit']
            });

            if (productData) {
              const costPriceFromDB = productData['cost_price'];
              if (costPriceFromDB !== undefined && costPriceFromDB !== null && costPriceFromDB !== 0) {
                const isBulkSale = this.isBulkSale(item, productData);
                console.log('📊 Sale type:', { isBulkSale, itemUnit: item.unit, productUnit: productData['unit'] });
                
                const costPrice = this.calculateCostPrice(item, productData, isBulkSale);
                const sellingPrice = item.sellingPrice || 0;
                const quantity = item.quantity || 1;
                
                const totalSelling = sellingPrice * quantity;
                const totalCost = costPrice * quantity;
                const profit = totalSelling - totalCost;

                console.log('💰 Final calculation for', item.name, ':', {
                  costPrice,
                  sellingPrice,
                  quantity,
                  totalCost,
                  totalSelling,
                  profit,
                  margin: ((profit / totalSelling) * 100).toFixed(1) + '%'
                });

                return {
                  ...item,
                  costPrice,
                  totalSelling,
                  totalCost,
                  profit,
                  is_bulk_sale: isBulkSale,
                  pieces_per_unit: productData['pieces'] || 1
                } as SaleItem;
              }
            }
          }
        }
        
        // Fallback: Use default cost calculation
        console.log('⚠️ Using fallback cost calculation for:', item.name);
        return this.createSaleItemWithDefaults(item);

      } catch (error) {
        console.error('❌ Error calculating item profit for', item.name, ':', error);
        return this.createSaleItemWithDefaults(item);
      }
    })
  );
}

private isBulkSale(saleItem: any, productData: any): boolean {
  // Method 1: Check if sale unit matches bulk unit
  if (saleItem.unit === productData['unit'] && productData['unit'] !== 'piece') {
    return true;
  }
  
  // Method 2: Check pricing option
  if (saleItem.pricing_option === 'bulk' || saleItem.pricing_option === 'tray' || saleItem.pricing_option === 'pack') {
    return true;
  }
  
  // Method 3: Check if quantity matches bulk quantity
  if (productData['pieces'] && saleItem.quantity >= productData['pieces']) {
    return true;
  }
  
  return false;
}
private normalizeItemData(item: any): SaleItem {
  console.log('🔄 Normalizing item data - RAW:', item);
  
  // DEBUG: Check what fields actually exist
  console.log('🔍 Available fields in raw item:', Object.keys(item));
  
  // Handle different field name variations - FIXED VERSION
  const id = item.product_id || item.id || item.productId || '';
  const name = item.product_name || item.name || 'Unknown Product';
  
  // If we have raw data but normalization failed, use the raw data directly
  let finalId = id;
  let finalName = name;
  
  // If we have raw data with values but normalized is undefined, use raw data
  if ((!finalId || finalId === '') && item.product_id) {
    finalId = item.product_id;
    console.log('✅ Using raw product_id:', finalId);
  }
  
  if ((!finalName || finalName === 'Unknown Product') && item.product_name) {
    finalName = item.product_name;
    console.log('✅ Using raw product_name:', finalName);
  }
  
  // If we still don't have an ID but have a name, create a stable ID
  if (!finalId && finalName && finalName !== 'Unknown Product') {
    finalId = `name-${finalName.replace(/\s+/g, '-').toLowerCase()}`;
    console.log('✅ Created ID from name:', finalId);
  }
  
  // Last resort fallbacks
  if (!finalId) {
    finalId = `unknown-${Math.random().toString(36).substring(2, 9)}`;
    console.log('⚠️ Created random ID as fallback:', finalId);
  }
  
  if (!finalName || finalName === 'Unknown Product') {
    finalName = `Product ${finalId.substring(0, 8)}`;
    console.log('⚠️ Created fallback name:', finalName);
  }
  
  // Get pricing data - handle all possible field names
  const sellingPrice = item.price || item.sellingPrice || item.unit_price || 0;
  const quantity = item.quantity || item.qty || 1;
  const totalSelling = item.subtotal || item.total_price || sellingPrice * quantity;
  
  const normalizedItem = {
    id: finalId,
    name: finalName,
    quantity: quantity,
    sellingPrice: sellingPrice,
    costPrice: 0, // Will be calculated
    totalSelling: totalSelling,
    totalCost: 0, // Will be calculated
    profit: 0, // Will be calculated
    unit: item.unit || 'piece',
    pricing_option: item.pricing_option || 'piece',
    product_barcode: item.product_barcode || '',
    product_category: item.product_category || '',
    total_pieces: item.total_pieces || 1,
    is_bulk_sale: false,
    // Store all original data for debugging
    originalData: {
      product_id: item.product_id,
      product_name: item.product_name,
      id: item.id,
      name: item.name,
      price: item.price,
      sellingPrice: item.sellingPrice,
      quantity: item.quantity,
      subtotal: item.subtotal,
      // Include all raw fields for debugging
      allRawFields: Object.keys(item)
    }
  } as SaleItem;

  console.log('✅ Final normalized item:', {
    id: normalizedItem.id,
    name: normalizedItem.name,
    sellingPrice: normalizedItem.sellingPrice,
    quantity: normalizedItem.quantity,
    totalSelling: normalizedItem.totalSelling
  });
  
  return normalizedItem;
}

private calculateCostPrice(saleItem: any, productData: any, isBulkSale: boolean): number {
  if (isBulkSale) {
    // Bulk sale: Use the wholesale cost directly
    return productData['cost_price'] || 0;
  } else {
    // Piece sale: Calculate cost per piece
    const bulkCost = productData['cost_price'] || 0;
    const piecesPerUnit = productData['pieces'] || 1;
    return bulkCost / piecesPerUnit;
  }
}

private createSaleItemWithDefaults(item: any): SaleItem {
  const sellingPrice = item.sellingPrice || item.price || 0;
  const quantity = item.quantity || 1;
  
  // BETTER FALLBACK: Use a more conservative estimate
  // Or better yet, throw an error to identify missing cost data
  const costPrice = sellingPrice * 0.9; // Assume 10% margin instead of 30%
  
  const totalSelling = sellingPrice * quantity;
  const totalCost = costPrice * quantity;
  const profit = totalSelling - totalCost;

  console.warn('⚠️ Using fallback cost calculation for:', item.name, {
    sellingPrice,
    costPrice,
    profit,
    margin: ((profit / totalSelling) * 100).toFixed(1) + '%'
  });

  return {
    ...item,
    costPrice,
    totalSelling,
    totalCost,
    profit,
    unit: item.unit || 'piece',
    pricing_option: item.pricing_option || 'piece',
    is_bulk_sale: false
  } as SaleItem;
}

// Helper methods for the HTML templates
hasMixedSaleTypes(product: CashProduct | DebtProduct): boolean {
  if (!product.items) return false;
  
  const hasBulk = product.items.some(item => item.is_bulk_sale);
  const hasPiece = product.items.some(item => !item.is_bulk_sale);
  
  return hasBulk && hasPiece;
}

getSaleTypeLabel(product: CashProduct | DebtProduct): string {
  if (!product.items) return 'Mixed';
  
  const bulkCount = product.items.filter(item => item.is_bulk_sale).length;
  const pieceCount = product.items.filter(item => !item.is_bulk_sale).length;
  
  if (bulkCount > 0 && pieceCount > 0) return 'Mixed';
  if (bulkCount > 0) return 'Bulk Sales';
  return 'Piece Sales';
}

getBulkSalesCount(type: 'today' | 'total'): number {
  const products = type === 'today' ? 
    this.cashProducts.filter(p => this.isToday(p.created_at)) : 
    this.cashProducts;
  
  return products.filter(product => 
    product.items && product.items.some(item => item.is_bulk_sale)
  ).length;
}

getPieceSalesCount(type: 'today' | 'total'): number {
  const products = type === 'today' ? 
    this.cashProducts.filter(p => this.isToday(p.created_at)) : 
    this.cashProducts;
  
  return products.filter(product => 
    product.items && product.items.some(item => !item.is_bulk_sale)
  ).length;
}

getTodaySaleTypesCount(): number {
  return this.getBulkSalesCount('today') + this.getPieceSalesCount('today');
}

getTotalSaleTypesCount(): number {
  return this.getBulkSalesCount('total') + this.getPieceSalesCount('total');
}

private isToday(date: any): boolean {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  const productDate = date?.toDate ? date.toDate() : new Date(date);
  productDate.setHours(0, 0, 0, 0);
  
  return productDate.getTime() === today.getTime();
}

// Toggle for item breakdown
showItemBreakdown: boolean = false;

toggleItemBreakdown(): void {
  this.showItemBreakdown = !this.showItemBreakdown;
}

// Profit calculation methods with safe access
getTodayCashProfit(): number {
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  
  return this.cashProducts
    .filter(product => {
      const productDate = product.created_at?.toDate ? product.created_at.toDate() : new Date(product.created_at);
      productDate.setHours(0, 0, 0, 0);
      return productDate.getTime() === today.getTime();
    })
    .reduce((total, product) => total + (product.profit || 0), 0);
}

// Update your margin calculation methods
getTodayCashMargin(): number {
  const todayTotal = this.getTodayCashTotal();
  const todayProfit = this.getTodayCashProfit();
  const margin = todayTotal > 0 ? (todayProfit / todayTotal) * 100 : 0;
  return this.formatMargin(margin);
}


getTotalCashProfit(): number {
  return this.cashProducts.reduce((total, product) => total + (product.profit || 0), 0);
}

getAverageCashMargin(): number {
  const totalSales = this.getTotalCashSales();
  const totalProfit = this.getTotalCashProfit();
  const margin = totalSales > 0 ? (totalProfit / totalSales) * 100 : 0;
  return this.formatMargin(margin);
}


// Fix the main debt profit calculation
getTotalDebtProfit(): number {
  return this.debtProducts.reduce((total, debt) => total + (debt.profit || 0), 0);
}

getAverageDebtMargin(): number {
  // Use originalSalesTotal if available, otherwise calculate from items
  const totalDebtSales = this.debtProducts.reduce((total: number, debt: DebtProduct) => {
    if (debt.originalSalesTotal) {
      return total + debt.originalSalesTotal;
    }
    // Fallback: calculate from items
    return total + (debt.items?.reduce((sum: number, item: SaleItem) => sum + (item.totalSelling || 0), 0) || 0);
  }, 0);
  
  const totalProfit = this.getTotalDebtProfit();
  const margin = totalDebtSales > 0 ? (totalProfit / totalDebtSales) * 100 : 0;
  return this.formatMargin(margin);
} 

getRealizedDebtProfit(): number {
  return this.debtProducts
    .filter(debt => debt.payment_status === 'paid')
    .reduce((total, debt) => total + (debt.profit || 0), 0);
}
getProfitClass(profit: number): string {
  return profit >= 0 ? 'profit-positive' : 'profit-negative';
}

getMarginClass(margin: number): string {
  if (margin >= 30) return 'margin-high';
  if (margin >= 15) return 'margin-medium';
  return 'margin-low';
}
debugDebtProfitFix(): void {
  console.log('🔍 DEBUGGING DEBT PROFIT FIX:');
  
  this.debtProducts.forEach((debt: DebtProduct, index: number) => {
    const itemsTotal = debt.items?.reduce((sum: number, item: SaleItem) => sum + (item.totalSelling || 0), 0) || 0;
    const calculatedProfit = debt.profit || 0;
    const calculatedMargin = debt.profitMargin || 0;
    
    console.log(`Debt ${index + 1}:`, {
      customer: debt.customerName,
      databaseTotal: debt.total, // This is the remaining balance
      itemsCalculatedTotal: itemsTotal, // This is the original sales amount
      originalSalesTotal: debt.originalSalesTotal, // The new calculated field
      totalCost: debt.totalCost,
      profit: calculatedProfit,
      margin: calculatedMargin.toFixed(3) + '%',
      initialPayment: debt.initialPayment,
      remainingBalance: debt.remainingBalance
    });
  });
  
  const totalOriginalSales = this.debtProducts.reduce((sum: number, debt: DebtProduct) => {
    return sum + (debt.originalSalesTotal || debt.items?.reduce((itemSum: number, item: SaleItem) => itemSum + (item.totalSelling || 0), 0) || 0);
  }, 0);
  
  const totalProfit = this.getTotalDebtProfit();
  
  console.log('📊 DEBT PROFIT SUMMARY AFTER FIX:', {
    totalOriginalSales: totalOriginalSales.toFixed(2),
    totalProfit: totalProfit.toFixed(2),
    overallMargin: ((totalProfit / totalOriginalSales) * 100).toFixed(3) + '%'
  });
}
}