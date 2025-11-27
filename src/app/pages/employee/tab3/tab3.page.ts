import { Component, OnInit, ViewChild } from '@angular/core';
import { IonInput, AlertController, ToastController, LoadingController } from '@ionic/angular';
import { ProductService, Product } from 'src/app/services/product.service';
import { AuthService } from 'src/app/services/auth.service';
import { JsqrBarcodeScannerService } from 'src/app/services/jsqr-barcode-scanner.service';
import { QuaggaBarcodeScannerService } from 'src/app/services/quagga-barcode-scanner.service';
import { Firestore } from '@angular/fire/firestore';
import { DebtCustomerRegistrationService } from 'src/app/services/debt-customer-registration.service';
import { LocationService } from 'src/app/services/location.service'; // ← ADD THIS IMPORT
// Add this import
import { StoreService } from 'src/app/services/store.service';

// Add these imports for receipt generation
import html2canvas from 'html2canvas';
import jsPDF from 'jspdf';

export interface CartItem {
  product: Product;
  quantity: number;
  unit: string;
  price: number;
  subtotal: number;
  pricingOption?: string; // 'piece' or bulk unit
  totalPieces?: number;   // Total pieces for bulk items
}

export interface Sale {
  id?: string;
  items: CartItem[];
  total: number;
  paymentMethod: 'cash' | 'debt';
  amountPaid?: number;
  change?: number;
  customerName?: string;
  customerPhone?: string;
  dueDate?: Date;
  status: 'completed' | 'pending' | 'cancelled';
  created_at: any;
  employee_id: string;
  store_owner_id: string;
  receipt_image?: string;
   // ADD THESE NEW PROPERTIES FOR INITIAL PAYMENT FEATURE
  initialPayment?: number;
  remainingBalance?: number;
  originalTotal?: number;
}

@Component({
  selector: 'app-tab3',
  templateUrl: './tab3.page.html',
  styleUrls: ['./tab3.page.scss'],
  standalone: false,
})
export class Tab3Page implements OnInit {
  @ViewChild('barcodeInput', { read: IonInput }) barcodeInput!: IonInput;

  // Cart and Sales
  cart: CartItem[] = [];
  filteredCart: CartItem[] = [];
  cartSearchTerm: string = '';
  paymentMethod: 'cash' | 'debt' = 'cash';
  amountPaid: number = 0;
  customerName: string = '';
  customerPhone: string = '';
  
  // Barcode scanning
  manualBarcode: string = '';
  showBarcodeInput: boolean = false;
  isContinuousScan: boolean = false;
  private barcodeTimeout: any;
  private continuousScanTimeout: any;

  // Modals
  showPaymentModal: boolean = false;
  showCustomerModal: boolean = false;
  showReceiptModal: boolean = false;

  // Current sale
  currentSale: Sale | null = null;

  // Product Search
  showProductSearch: boolean = false;
  productSearchTerm: string = '';
  searchResults: Product[] = [];
  private searchTimeout: any;

  // Product Options Modal
  showProductOptionsModal: boolean = false;
  selectedProduct: Product | null = null;
  selectedPricingOption: string = 'piece';
  selectedQuantity: number = 1;

  currentStoreInfo: any = null;

  // Add these properties to your component
  passwordsMatch: boolean = false;
  isPasswordValid: boolean = false;

  // Add to your component properties
  filteredCustomers: any[] = [];
  customerSearchTerm: string = '';
  showNewCustomerForm: boolean = false;
  newCustomer: any = {
    full_name: '',
    phone_number: '',
    email: '',
    province: '',
    municipality: '',
    barangay: '',
    sitio_purok: '',
    username: '', // ADD THIS
    password: '',
    confirmPassword: ''   // ADD THIS
  };
  // Location data for debt customer registration
  municipalities: string[] = [];
  barangays: string[] = [];

  // Selected location values for debt customer
  selectedMunicipality: string = '';
  selectedBarangay: string = '';

  // Search functionality for location modals
  searchMunicipality = '';
  searchBarangay = '';

  // Modal states for location selection
  showMunicipalityModal = false;
  showBarangayModal = false;

  // Store owner location info
  storeOwnerLocationInfo: any = null;

  // Add these properties to your component
  selectedDueDateOption: '15' | '30' | 'custom' = '15';
  customDueDate: string = '';
  calculatedDueDate: string = '';

  // Add these new properties - MAKE SURE THEY ARE PROPERLY INITIALIZED
  initialPayment: number = 0;
  remainingBalance: number = 0;
  originalTotal: number = 0;

  // Add this with your other ViewChild declarations
  @ViewChild('productSearchInput', { read: IonInput }) productSearchInput!: IonInput;

  constructor(
    private productService: ProductService,
    private authService: AuthService,
    private locationService: LocationService,
    private debtCustomerRegistrationService: DebtCustomerRegistrationService,
    private alertController: AlertController,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private jsqrBarcodeScannerService: JsqrBarcodeScannerService,
    private quaggaBarcodeScannerService: QuaggaBarcodeScannerService,
    private storeService: StoreService,
    private firestore: Firestore, 
  ) { }
  // Product Search Methods
openProductSearch() {
  this.showProductSearch = true;
  this.productSearchTerm = '';
  this.searchResults = [];
  
  setTimeout(() => {
    this.focusProductSearchInput();
  }, 300);
}

// Product Options Methods
openProductOptions(product: Product) {
  this.selectedProduct = product;
  this.selectedPricingOption = 'piece';
  this.selectedQuantity = 1;
  this.showProductOptionsModal = true;
  this.showProductSearch = false;
}

closeProductOptionsModal() {
  this.showProductOptionsModal = false;
  this.selectedProduct = null;
  this.selectedPricingOption = 'piece';
  this.selectedQuantity = 1;
}

// Bulk Options Methods - Update to handle null
hasBulkOptions(product: Product | null): boolean {
  if (!product) return false;
  return !!(product.bulk_options && product.bulk_options.length > 0);
}

getBulkOptions(product: Product | null): any[] {
  if (!product) return [];
  return product.bulk_options || [];
}
// Add these missing methods:

// For cart item quantity adjustment
adjustQuantity(change: number) {
  const newQuantity = this.selectedQuantity + change;
  const maxQuantity = this.getMaxQuantityForOption();
  
  if (newQuantity >= 1 && newQuantity <= maxQuantity) {
    this.selectedQuantity = newQuantity;
  }
}

// For cart items - get maximum quantity based on pricing option
getMaxQuantity(item: CartItem): number {
  if (item.pricingOption === 'piece') {
    return item.product.stock_quantity;
  }

  // For bulk items, calculate based on pieces
  if (item.totalPieces) {
    return Math.floor(item.product.stock_quantity / item.totalPieces * item.quantity);
  }

  return item.product.stock_quantity;
}
onReceiptModalDismiss() {
  // Only complete sale if the user clicked "Done", not when they click outside or press back
  if (this.currentSale) {
    console.log('🔍 DEBUG: Receipt modal dismissed with active sale');
    // Don't complete sale automatically - let the user click "Done"
  }
}
// For editing cart items
editCartItem(item: CartItem) {
  this.selectedProduct = item.product;
  this.selectedPricingOption = item.pricingOption || 'piece';
  this.selectedQuantity = item.quantity;
  this.showProductOptionsModal = true;
}
selectPricingOption(option: string) {
  this.selectedPricingOption = option;
  this.validateQuantity();
}
validateQuantity() {
  const maxQuantity = this.getMaxQuantityForOption();
  if (this.selectedQuantity > maxQuantity) {
    this.selectedQuantity = maxQuantity;
  }
  if (this.selectedQuantity < 1) {
    this.selectedQuantity = 1;
  }
}
calculateBulkSavings(unitPrice: number, bulkOption: any): number {
  if (!bulkOption || !bulkOption.pieces || bulkOption.pieces === 0) return 0;
  const piecePrice = bulkOption.selling_price / bulkOption.pieces;
  const savings = ((unitPrice - piecePrice) / unitPrice) * 100;
  return Math.round(savings * 100) / 100;
}

calculateSimpleBulkSavings(product: Product | null): number {
  if (!product || !product.bulk_selling_price || !product.pieces_per_bulk) return 0;
  const piecePrice = product.bulk_selling_price / product.pieces_per_bulk;
  const savings = ((product.selling_price - piecePrice) / product.selling_price) * 100;
  return Math.round(savings * 100) / 100;
}

getMaxQuantityForOption(): number {
  if (!this.selectedProduct) return 0;

  if (this.selectedPricingOption === 'piece') {
    return this.selectedProduct.stock_quantity;
  }

  // For bulk options, calculate max based on pieces
  if (this.hasBulkOptions(this.selectedProduct)) {
    const bulkOption = this.getBulkOptions(this.selectedProduct).find(opt => opt.unit === this.selectedPricingOption);
    if (bulkOption) {
      return Math.floor(this.selectedProduct.stock_quantity / bulkOption.pieces);
    }
  }

  // For simple bulk pricing
  if (this.selectedProduct.bulk_unit === this.selectedPricingOption && this.selectedProduct.pieces_per_bulk) {
    return Math.floor(this.selectedProduct.stock_quantity / this.selectedProduct.pieces_per_bulk);
  }

  return 0;
}

getTotalPieces(): number {
  if (!this.selectedProduct) return this.selectedQuantity;

  if (this.selectedPricingOption === 'piece') {
    return this.selectedQuantity;
  }

  if (this.hasBulkOptions(this.selectedProduct)) {
    const bulkOption = this.getBulkOptions(this.selectedProduct).find(opt => opt.unit === this.selectedPricingOption);
    if (bulkOption?.pieces) {
      return this.selectedQuantity * bulkOption.pieces;
    }
  }

  if (this.selectedProduct.bulk_unit === this.selectedPricingOption && this.selectedProduct.pieces_per_bulk) {
    return this.selectedQuantity * this.selectedProduct.pieces_per_bulk;
  }

  return this.selectedQuantity;
}

calculateTotalPrice(): number {
  if (!this.selectedProduct) return 0;

  if (this.selectedPricingOption === 'piece') {
    return this.selectedQuantity * this.selectedProduct.selling_price;
  }

  if (this.hasBulkOptions(this.selectedProduct)) {
    const bulkOption = this.getBulkOptions(this.selectedProduct).find(opt => opt.unit === this.selectedPricingOption);
    if (bulkOption?.selling_price) {
      return this.selectedQuantity * bulkOption.selling_price;
    }
  }

  if (this.selectedProduct.bulk_unit === this.selectedPricingOption) {
    return this.selectedQuantity * (this.selectedProduct.bulk_selling_price || 0);
  }

  return 0;
}

addToCartWithOptions() {
  if (!this.selectedProduct) {
    this.showToast('No product selected', 'warning');
    return;
  }

  let price = 0;
  let unit = this.selectedProduct.unit_of_measure;

  if (this.selectedPricingOption === 'piece') {
    price = this.selectedProduct.selling_price;
    unit = this.selectedProduct.unit_of_measure;
  } else if (this.hasBulkOptions(this.selectedProduct)) {
    const bulkOption = this.getBulkOptions(this.selectedProduct).find(opt => opt.unit === this.selectedPricingOption);
    if (bulkOption) {
      price = bulkOption.selling_price;
      unit = bulkOption.unit;
    } else {
      this.showToast('Invalid bulk option selected', 'warning');
      return;
    }
  } else if (this.selectedProduct.bulk_unit === this.selectedPricingOption) {
    price = this.selectedProduct.bulk_selling_price || 0;
    unit = this.selectedProduct.bulk_unit || '';
  } else {
    this.showToast('Invalid pricing option', 'warning');
    return;
  }

  const cartItem: CartItem = {
    product: this.selectedProduct,
    quantity: this.selectedQuantity,
    unit: unit,
    price: price,
    subtotal: this.calculateTotalPrice(),
    pricingOption: this.selectedPricingOption,
    totalPieces: this.getTotalPieces()
  };

  // Check if similar item already exists in cart
  const existingIndex = this.cart.findIndex(item => 
    item.product.id === cartItem.product.id && 
    item.unit === cartItem.unit
  );

  if (existingIndex > -1) {
    // Update existing item
    this.cart[existingIndex].quantity += cartItem.quantity;
    this.cart[existingIndex].subtotal += cartItem.subtotal;
    this.showToast(`Updated quantity of ${this.selectedProduct.name}`, 'success');
  } else {
    // Add new item
    this.cart.push(cartItem);
    this.showToast(`Added ${this.selectedProduct.name} to cart`, 'success');
  }

  this.closeProductOptionsModal();
  this.filterCartItems();
}
private async focusProductSearchInput() {
  try {
    if (this.productSearchInput) {
      await this.productSearchInput.setFocus();
    }
  } catch (error) {
    console.warn('Could not focus product search input:', error);
  }
}

async onProductSearch() {
  // Clear previous timeout
  if (this.searchTimeout) {
    clearTimeout(this.searchTimeout);
  }

  this.searchTimeout = setTimeout(async () => {
    if (this.productSearchTerm.trim().length >= 2) {
      await this.searchProducts(this.productSearchTerm.trim());
    } else {
      this.searchResults = [];
    }
  }, 300);
}

async searchProducts(searchTerm: string) {
  try {
    // Get all products first
    const allProducts = await this.productService.getStoreProducts();
    
    // Filter products based on search term
    this.searchResults = allProducts.filter(product => 
      product.name.toLowerCase().includes(searchTerm.toLowerCase()) ||
      product.category.toLowerCase().includes(searchTerm.toLowerCase()) ||
      (product.brand && product.brand.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (product.custom_product_id && product.custom_product_id.toLowerCase().includes(searchTerm.toLowerCase())) ||
      (product.barcode && product.barcode.toLowerCase().includes(searchTerm.toLowerCase()))
    );

    console.log(`🔍 Found ${this.searchResults.length} products matching "${searchTerm}"`);

  } catch (error: any) {
    console.error('Error searching products:', error);
    await this.showToast('Error searching products', 'danger');
  }
}

// Update the existing addProductToCart method to handle search closure
async addProductToCart(product: Product) {
  // Check stock availability
  if (product.stock_quantity <= 0) {
    await this.showToast(`${product.name} is out of stock`, 'warning');
    return;
  }

  // Check if product already in cart
  const existingItem = this.cart.find(item => item.product.id === product.id);
  
  if (existingItem) {
    // Check if we can increase quantity
    if (existingItem.quantity >= product.stock_quantity) {
      await this.showToast(`Cannot add more ${product.name}. Only ${product.stock_quantity} in stock.`, 'warning');
      return;
    }
    
    // Increment quantity
    existingItem.quantity++;
    existingItem.subtotal = existingItem.quantity * existingItem.price;
    await this.showToast(`Increased quantity of ${product.name}`, 'success');
  } else {
    // Add new item to cart
    const price = product.selling_price;
    const cartItem: CartItem = {
      product: product,
      quantity: 1,
      unit: product.unit_of_measure,
      price: price,
      subtotal: price
    };
    this.cart.push(cartItem);
    await this.showToast(`Added ${product.name} to cart`, 'success');
  }

  // Close search and update filtered cart
  this.showProductSearch = false;
  this.productSearchTerm = '';
  this.searchResults = [];
  this.filterCartItems();
}

// Add product icon method (similar to your Tab4)
getProductIcon(product: Product): string {
  switch (product.category.toLowerCase()) {
    case 'beverages': return 'wine';
    case 'snacks': return 'fast-food';
    case 'dairy': return 'nutrition';
    case 'meat': return 'restaurant';
    case 'vegetables': return 'leaf';
    case 'fruits': return 'nutrition';
    case 'household': return 'home';
    case 'personal care': return 'person';
    default: return 'cube';
  }
}


  async ngOnInit() {
    await this.loadProducts();
    this.filteredCart = [...this.cart];
    await this.loadStoreInfo(); // Add this line
    await this.loadStoreOwnerLocationInfo();
    this.calculateRemainingBalance(); 
  }

  // Load store information
  async loadStoreInfo() {
    try {
      this.currentStoreInfo = await this.storeService.getStoreInfoForReceipt();
      console.log('Store info loaded:', this.currentStoreInfo);
    } catch (error) {
      console.error('Error loading store info:', error);
      // Set default store info if there's an error
      this.currentStoreInfo = {
        name: 'Retail Store',
        address: 'Address not specified',
        receipt_header: 'Retail Receipt',
        receipt_footer: 'Thank you for your purchase!',
        currency_symbol: '₱',
        tax_rate: 0
      };
    }
  }
  async loadProducts() {
    // Preload products for faster searching
    await this.productService.getStoreProducts();
  }

  // Continuous Scanning Methods
  toggleContinuousScan() {
    if (this.isContinuousScan) {
      this.stopContinuousScan();
    } else {
      this.startContinuousScan();
    }
  }

  startContinuousScan() {
    this.isContinuousScan = true;
    this.showBarcodeInput = true;
    this.manualBarcode = '';
    
    setTimeout(() => {
      this.focusBarcodeInput();
    }, 300);

    this.showToast('Continuous scan mode activated. Start scanning products.', 'success');
  }

  stopContinuousScan() {
    this.isContinuousScan = false;
    this.showBarcodeInput = false;
    this.clearContinuousScanTimeout();
    this.showToast('Continuous scan mode deactivated', 'warning');
  }

  private clearContinuousScanTimeout() {
    if (this.continuousScanTimeout) {
      clearTimeout(this.continuousScanTimeout);
    }
  }

  private resetContinuousScanTimeout() {
    this.clearContinuousScanTimeout();
    this.continuousScanTimeout = setTimeout(() => {
      if (this.isContinuousScan) {
        this.stopContinuousScan();
        this.showToast('Continuous scan stopped due to inactivity', 'warning');
      }
    }, 3000); // Stop after 3 seconds of inactivity
  }

  // Barcode Scanning Methods
  openBarcodeInput() {
    this.showBarcodeInput = true;
    this.manualBarcode = '';
    
    setTimeout(() => {
      this.focusBarcodeInput();
    }, 300);
  }

  private async focusBarcodeInput() {
    try {
      if (this.barcodeInput) {
        await this.barcodeInput.setFocus();
      }
    } catch (error) {
      console.warn('Could not focus barcode input:', error);
    }
  }

  async onBarcodeInput() {
    // Clear previous timeout
    if (this.barcodeTimeout) {
      clearTimeout(this.barcodeTimeout);
    }

    this.barcodeTimeout = setTimeout(async () => {
      if (this.manualBarcode.length >= 8) {
        await this.handleScannedBarcode(this.manualBarcode);
        
        // Reset for continuous scanning
        if (this.isContinuousScan) {
          this.manualBarcode = '';
          this.resetContinuousScanTimeout();
          setTimeout(() => {
            this.focusBarcodeInput();
          }, 100);
        } else {
          this.manualBarcode = '';
        }
      }
    }, 500); // Reduced timeout for faster response
  }

  async handleScannedBarcode(barcode: string) {
    try {
      const loading = await this.loadingController.create({
        message: 'Searching product...',
        duration: 2000 // Auto dismiss after 2 seconds
      });
      await loading.present();

      const result = await this.productService.searchOrCreateProductByBarcode(barcode);
      
      await loading.dismiss();
      
      if (result.exists && result.product) {
        await this.addProductToCart(result.product);
        
        if (!this.isContinuousScan) {
          this.showBarcodeInput = false;
        }
      } else {
        await this.showToast('Product not found in inventory', 'warning');
      }

    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    }
  }

  // Camera Scanning Methods
async openCameraOptions() {
  const alert = await this.alertController.create({
    header: 'Scan Barcode',
    message: 'Choose scanning method',
    buttons: [
      {
        text: '📊 1D Barcodes (UPC/EAN) - Recommended',
        handler: () => {
          this.scanBarcodeWithQuagga();
        }
      },
      {
        text: '📷 QR Codes',
        handler: () => {
          this.scanBarcodeWithCamera();
        }
      },
      {
        text: '🔍 Search Products',
        handler: () => {
          this.openProductSearch();
        }
      },
      {
        text: '⌨️ Manual Barcode Entry',
        handler: () => {
          this.openBarcodeInput();
        }
      },
      {
        text: 'Cancel',
        role: 'cancel'
      }
    ]
  });

  await alert.present();
}

  async scanBarcodeWithQuagga() {
    try {
      const loading = await this.loadingController.create({
        message: 'Opening barcode scanner...'
      });
      await loading.present();

      const barcode = await this.quaggaBarcodeScannerService.scanBarcode();
      
      await loading.dismiss();

      if (barcode) {
        await this.showToast(`✅ Barcode scanned: ${barcode}`, 'success');
        await this.handleScannedBarcode(barcode);
      } else {
        await this.showToast('❌ No barcode detected', 'warning');
      }

    } catch (error: any) {
      await this.loadingController.dismiss();
      await this.showToast(`❌ ${error.message}`, 'danger');
    }
  }

  async scanBarcodeWithCamera() {
    try {
      const loading = await this.loadingController.create({
        message: 'Opening QR scanner...'
      });
      await loading.present();

      const barcode = await this.jsqrBarcodeScannerService.scanBarcode();
      
      await loading.dismiss();

      if (barcode) {
        await this.showToast(`✅ QR scanned: ${barcode}`, 'success');
        await this.handleScannedBarcode(barcode);
      } else {
        await this.showToast('❌ No QR code detected', 'warning');
      }

    } catch (error: any) {
      await this.loadingController.dismiss();
      await this.showToast(`❌ ${error.message}`, 'danger');
    }
  }

  // // Cart Management Methods
  // async addProductToCart(product: Product) {
  //   // Check stock availability
  //   if (product.stock_quantity <= 0) {
  //     await this.showToast(`${product.name} is out of stock`, 'warning');
  //     return;
  //   }

  //   // Check if product already in cart
  //   const existingItem = this.cart.find(item => item.product.id === product.id);
    
  //   if (existingItem) {
  //     // Check if we can increase quantity
  //     if (existingItem.quantity >= product.stock_quantity) {
  //       await this.showToast(`Cannot add more ${product.name}. Only ${product.stock_quantity} in stock.`, 'warning');
  //       return;
  //     }
      
  //     // Increment quantity
  //     existingItem.quantity++;
  //     existingItem.subtotal = existingItem.quantity * existingItem.price;
  //     await this.showToast(`Increased quantity of ${product.name}`, 'success');
  //   } else {
  //     // Add new item to cart
  //     const price = product.selling_price;
  //     const cartItem: CartItem = {
  //       product: product,
  //       quantity: 1,
  //       unit: product.unit_of_measure,
  //       price: price,
  //       subtotal: price
  //     };
  //     this.cart.push(cartItem);
  //     await this.showToast(`Added ${product.name} to cart`, 'success');
  //   }

  //   // Update filtered cart
  //   this.filterCartItems();
  // }

  filterCartItems() {
    if (!this.cartSearchTerm) {
      this.filteredCart = [...this.cart];
    } else {
      const searchTerm = this.cartSearchTerm.toLowerCase();
      this.filteredCart = this.cart.filter(item =>
        item.product.name.toLowerCase().includes(searchTerm) ||
        item.product.barcode.toLowerCase().includes(searchTerm) ||
        item.product.category.toLowerCase().includes(searchTerm)
      );
    }
  }

  increaseQuantity(item: CartItem) {
    if (item.quantity < item.product.stock_quantity) {
      item.quantity++;
      item.subtotal = item.quantity * item.price;
      this.filterCartItems();
    } else {
      this.showToast(`Cannot add more. Only ${item.product.stock_quantity} in stock.`, 'warning');
    }
  }

  decreaseQuantity(item: CartItem) {
    if (item.quantity > 1) {
      item.quantity--;
      item.subtotal = item.quantity * item.price;
      this.filterCartItems();
    }
  }

  removeFromCart(item: CartItem) {
    const index = this.cart.indexOf(item);
    if (index > -1) {
      this.cart.splice(index, 1);
      this.filterCartItems();
      this.showToast('Item removed from cart', 'warning');
    }
  }

  clearCart() {
    this.cart = [];
    this.filteredCart = [];
    this.cartSearchTerm = '';
    this.showToast('Cart cleared', 'warning');
  }

  // Price Calculations
  get subtotal(): number {
    return this.cart.reduce((sum, item) => sum + item.subtotal, 0);
  }

  get total(): number {
    return this.subtotal; // You can add tax here if needed
  }

  get change(): number {
    return this.amountPaid - this.total;
  }

openPaymentModal() {
  if (this.cart.length === 0) {
    this.showToast('Cart is empty', 'warning');
    return;
  }
  
  // Check if any items exceed stock
  const outOfStockItems = this.cart.filter(item => item.quantity > item.product.stock_quantity);
  if (outOfStockItems.length > 0) {
    this.showToast('Some items exceed available stock', 'warning');
    return;
  }
  
  // Reset initial payment data when opening modal
  this.initialPayment = 0;
  this.calculateRemainingBalance();
  
  if (this.paymentMethod === 'debt') {
    this.showCustomerModal = true;
    // Load customers when modal opens
    this.onCustomerSearch();
  } else {
    // For cash sales, go directly to payment modal
    this.showPaymentModal = true;
    this.amountPaid = this.total;
    this.resetDueDate(); // Reset due date when opening modal
  }
}

  // processPayment() {
  //   if (this.paymentMethod === 'cash' && this.amountPaid < this.total) {
  //     this.showToast('Amount paid is less than total', 'warning');
  //     return;
  //   }

  //   // Create sale record
  //   const currentUser = this.authService.getCurrentUser();
  //   const storeOwnerId = currentUser?.store_owner_id || currentUser?.id || '';

  //   this.currentSale = {
  //     id: this.generateReceiptId(),
  //     items: [...this.cart],
  //     total: this.total,
  //     paymentMethod: this.paymentMethod,
  //     amountPaid: this.paymentMethod === 'cash' ? this.amountPaid : 0,
  //     change: this.paymentMethod === 'cash' ? this.change : 0,
  //     customerName: this.customerName || undefined,
  //     customerPhone: this.customerPhone || undefined,
  //     status: 'completed',
  //     created_at: new Date(),
  //     employee_id: currentUser?.id || '',
  //     store_owner_id: storeOwnerId
  //   };

  //   // Show receipt
  //   this.showReceiptModal = true;
  //   this.showPaymentModal = false;
  //   this.showCustomerModal = false;
  // }

   // Add this method to calculate remaining balance
// Add this method to calculate remaining balance
calculateRemainingBalance() {
  // Ensure initial payment doesn't exceed total
  if (this.initialPayment > this.total) {
    this.initialPayment = this.total;
  }
  
  // Ensure initial payment is not negative
  if (this.initialPayment < 0) {
    this.initialPayment = 0;
  }
  
  this.remainingBalance = this.total - this.initialPayment;
  this.originalTotal = this.total;
}

processPayment() {
  if (this.paymentMethod === 'cash' && this.amountPaid < this.total) {
    this.showToast('Amount paid is less than total', 'warning');
    return;
  }

  // For debt sales, calculate due date
  let dueDate: Date | null = null;
  if (this.paymentMethod === 'debt') {
    dueDate = this.calculateDueDate();
    
    // Validate custom date is within 30 days policy
    if (this.selectedDueDateOption === 'custom' && this.customDueDate) {
      const customDate = new Date(this.customDueDate);
      const today = new Date();
      const maxDate = new Date();
      maxDate.setDate(today.getDate() + 30);
      
      if (customDate > maxDate) {
        this.showToast('Due date cannot exceed 30 days from today', 'warning');
        return;
      }
      
      if (customDate < today) {
        this.showToast('Due date cannot be in the past', 'warning');
        return;
      }
    }
  }

  // Create sale record
  const currentUser = this.authService.getCurrentUser();
  const storeOwnerId = currentUser?.store_owner_id || currentUser?.id || '';

  this.currentSale = {
    id: this.generateReceiptId(),
    items: [...this.cart],
    total: this.paymentMethod === 'debt' ? this.remainingBalance : this.total,
    paymentMethod: this.paymentMethod,
    amountPaid: this.paymentMethod === 'cash' ? this.amountPaid : this.initialPayment,
    change: this.paymentMethod === 'cash' ? this.change : 0,
    customerName: this.customerName || undefined,
    customerPhone: this.customerPhone || undefined,
    dueDate: dueDate || undefined,
    status: 'completed',
    created_at: new Date(),
    employee_id: currentUser?.id || '',
    store_owner_id: storeOwnerId,
    // ADD INITIAL PAYMENT DATA
    initialPayment: this.initialPayment,
    remainingBalance: this.remainingBalance,
    originalTotal: this.originalTotal
  };

  // Show receipt
  this.showReceiptModal = true;
  this.showPaymentModal = false;
  this.showCustomerModal = false;
}

  // Helper method to get today's date in YYYY-MM-DD format
  getTodayDate(): string {
    return new Date().toISOString().split('T')[0];
  }

  // Helper method to get maximum due date (30 days from today)
  getMaxDueDate(): string {
    const maxDate = new Date();
    maxDate.setDate(maxDate.getDate() + 30);
    return maxDate.toISOString().split('T')[0];
  }

  // Helper method to check if payment should be disabled
  isPaymentDisabled(): boolean {
    if (this.paymentMethod === 'cash') {
      return this.amountPaid < this.total;
    } else if (this.paymentMethod === 'debt') {
      // For debt sales, check if due date is valid
      if (this.selectedDueDateOption === 'custom' && !this.customDueDate) {
        return true;
      }
      return false;
    }
    return false;
  }

// Add this method to reset due date when modal opens
resetDueDate() {
  this.selectedDueDateOption = '15';
  this.customDueDate = '';
  this.calculateDueDate();
}
 async completeSale() {
  try {
    if (!this.currentSale) {
      this.showToast('No sale data to complete', 'warning');
      return;
    }

    const loading = await this.loadingController.create({
      message: 'Processing sale and updating inventory...',
    });
    await loading.present();

    try {
      // Generate receipt as base64 first
      const receiptBase64 = await this.generateReceiptBase64();

      // Update inventory and save sale data
      await this.processSaleAndUpdateInventory(receiptBase64);

      await loading.dismiss();

      // Clear cart and reset
      this.cart = [];
      this.filteredCart = [];
      this.cartSearchTerm = '';
      this.customerName = '';
      this.customerPhone = '';
      this.amountPaid = 0;
      this.showReceiptModal = false;
      this.currentSale = null;
      this.stopContinuousScan();
      
      this.showToast('Sale completed successfully! Inventory updated.', 'success');
      
    } catch (error: any) {
      await loading.dismiss();
      console.error('Error in sale completion process:', error);
      this.showToast('Error completing sale: ' + error.message, 'danger');
    }
    
  } catch (error: any) {
    console.error('Error in completeSale:', error);
    this.showToast('Unexpected error: ' + error.message, 'danger');
  }
}
private async generateReceiptBase64(): Promise<string> {
  try {
    // Wait for the receipt to render
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const receiptElement = document.getElementById('receipt-content');
    
    if (!receiptElement) {
      throw new Error('Receipt element not found');
    }

    // Create a clone for better rendering
    const clone = receiptElement.cloneNode(true) as HTMLElement;
    clone.style.width = '400px';
    clone.style.padding = '20px';
    clone.style.background = 'white';
    
    const tempContainer = document.createElement('div');
    tempContainer.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      z-index: -1000;
      opacity: 0;
    `;
    tempContainer.appendChild(clone);
    document.body.appendChild(tempContainer);

    const canvas = await html2canvas(clone, {
      useCORS: true,
      backgroundColor: '#ffffff',
      scale: 2, // Higher resolution
      logging: false
    } as any);

    // Clean up
    document.body.removeChild(tempContainer);

    return canvas.toDataURL('image/png', 1.0);
    
  } catch (error) {
    console.error('Error generating receipt base64:', error);
    return ''; // Return empty string if generation fails
  }
}
private async processSaleAndUpdateInventory(receiptBase64: string) {
  if (!this.currentSale) return;

  try {
    const currentUser = this.authService.getCurrentUser();
    const storeOwnerId = currentUser?.store_owner_id || currentUser?.id || '';

    console.log('🔄 Starting sale processing:', {
      itemsCount: this.currentSale.items.length,
      storeOwnerId: storeOwnerId
    });

    // 1. Update inventory for each product
    for (const item of this.currentSale.items) {
      await this.updateProductInventory(item);
    }

    // 2. Save sale data to appropriate collection
    await this.saveSaleData(receiptBase64, storeOwnerId);

    console.log('✅ Sale processing completed successfully');

  } catch (error) {
    console.error('Error in processSaleAndUpdateInventory:', error);
    throw error;
  }
}

private async updateProductInventory(cartItem: CartItem) {
  try {
    const product = cartItem.product;
    
    // Check if product ID exists
    if (!product.id) {
      throw new Error(`Product ID is undefined for ${product.name}. Cannot update inventory.`);
    }
    
    // Calculate quantity to deduct based on pricing option
    let quantityToDeduct = cartItem.quantity;
    
    if (cartItem.pricingOption !== 'piece' && cartItem.totalPieces) {
      // For bulk items, deduct based on total pieces
      quantityToDeduct = cartItem.totalPieces;
    }

    console.log('📦 Updating inventory:', {
      product: product.name,
      productId: product.id,
      currentStock: product.stock_quantity,
      quantityToDeduct: quantityToDeduct,
      pricingOption: cartItem.pricingOption,
      totalPieces: cartItem.totalPieces
    });

    // Update product stock
    const newStockQuantity = product.stock_quantity - quantityToDeduct;
    
    if (newStockQuantity < 0) {
      throw new Error(`Insufficient stock for ${product.name}. Available: ${product.stock_quantity}, Required: ${quantityToDeduct}`);
    }

    // Update product in Firestore - product.id is now guaranteed to be string
    await this.productService.updateProductStock(product.id, newStockQuantity);

    console.log(`✅ Updated inventory for ${product.name}: ${product.stock_quantity} -> ${newStockQuantity}`);

  } catch (error) {
    console.error(`❌ Error updating inventory for ${cartItem.product.name}:`, error);
    throw error;
  }
}

private async saveSaleData(receiptBase64: string, storeOwnerId: string) {
  if (!this.currentSale) return;

  try {
    // Helper function to sanitize data for Firestore
    const sanitizeForFirestore = (data: any): any => {
      if (data === undefined) return null;
      if (data === null) return null;
      if (typeof data === 'object' && !Array.isArray(data) && data !== null) {
        const sanitized: any = {};
        for (const key in data) {
          if (data[key] !== undefined) {
            sanitized[key] = sanitizeForFirestore(data[key]);
          }
        }
        return sanitized;
      }
      if (Array.isArray(data)) {
        return data.map(item => sanitizeForFirestore(item));
      }
      return data;
    };

    // Create sale data object - MAKE SURE TO INCLUDE INITIAL PAYMENT DATA
    const saleData: any = {
      id: this.currentSale.id,
      total: this.currentSale.total,
      paymentMethod: this.currentSale.paymentMethod,
      amountPaid: this.currentSale.amountPaid || 0,
      change: this.currentSale.change || 0,
      customerName: this.currentSale.customerName || '',
      customerPhone: this.currentSale.customerPhone || '',
      status: 'completed',
      receipt_image: receiptBase64,
      created_at: new Date(),
      store_owner_id: storeOwnerId,
      employee_id: this.authService.getCurrentUser()?.id || '',
      // ✅ ADD THESE CRITICAL FIELDS:
      initialPayment: this.currentSale.initialPayment || 0,
      remainingBalance: this.currentSale.remainingBalance || this.currentSale.total,
      originalTotal: this.currentSale.originalTotal || this.currentSale.total
    };

    // Simplify items
    const simplifiedItems = this.currentSale.items.map(item => ({
      product_id: item.product.id || '',
      product_name: item.product.name || '',
      product_barcode: item.product.barcode || '',
      product_category: item.product.category || '',
      quantity: item.quantity || 0,
      unit: item.unit || '',
      price: item.price || 0,
      subtotal: item.subtotal || 0,
      pricing_option: item.pricingOption || '',
      total_pieces: item.totalPieces || 0
    }));

    saleData.items = simplifiedItems;

    // Sanitize the entire object before saving
    const sanitizedData = sanitizeForFirestore(saleData);

    console.log('💾 Saving sanitized sale data:', {
      collection: this.currentSale.paymentMethod === 'cash' ? 'cash_products' : 'debt_products',
      data: sanitizedData,
      initialPayment: sanitizedData.initialPayment,
      remainingBalance: sanitizedData.remainingBalance
    });

    // Save to appropriate collection
    if (this.currentSale.paymentMethod === 'cash') {
      await this.saveToCashProducts(sanitizedData);
    } else {
      await this.saveToDebtProducts(sanitizedData);
    }

  } catch (error) {
    console.error('Error saving sale data:', error);
    throw error;
  }
}

private async saveToCashProducts(saleData: any) {
  try {
    const { collection, doc, setDoc, serverTimestamp } = await import('@angular/fire/firestore');
    const cashProductsRef = collection(this.firestore, 'cash_products');
    
    // Use the custom receipt ID as the document ID
    const cashProductDocRef = doc(cashProductsRef, saleData.id);
    
    const sanitizedData = {
      ...saleData,
      created_at: serverTimestamp()
    };
    
    // Use setDoc with the custom document ID
    await setDoc(cashProductDocRef, sanitizedData);
    console.log('✅ Cash sale saved to cash_products collection with ID:', saleData.id);
  } catch (error) {
    console.error('❌ Error saving to cash_products:', error);
    throw error;
  }
}

private async saveToDebtProducts(saleData: any) {
  try {
    const { collection, doc, setDoc, serverTimestamp } = await import('@angular/fire/firestore');
    const debtProductsRef = collection(this.firestore, 'debt_products');
    
    // Use the custom receipt ID as the document ID
    const debtProductDocRef = doc(debtProductsRef, saleData.id);
    
    // Determine the correct payment_status based on initial payment
    const hasInitialPayment = this.initialPayment > 0;
    const paymentStatus = hasInitialPayment ? 'partially_paid' : 'unpaid';
    
    const debtSaleData = {
      ...saleData, // This includes the custom 'id' field
      created_at: serverTimestamp(),
      dueDate: this.currentSale?.dueDate ? 
               (await import('@angular/fire/firestore')).Timestamp.fromDate(new Date(this.currentSale.dueDate)) : 
               null,
      status: 'pending',
      payment_status: paymentStatus, // ✅ FIX: Set based on initial payment
      initialPayment: this.initialPayment || 0, // ✅ FIX: Include initial payment
      remainingBalance: this.remainingBalance || saleData.total, // ✅ FIX: Include remaining balance
      originalTotal: this.originalTotal || saleData.total // ✅ FIX: Include original total
    };
    
    console.log('💾 Saving debt product with data:', {
      initialPayment: debtSaleData.initialPayment,
      remainingBalance: debtSaleData.remainingBalance,
      payment_status: debtSaleData.payment_status,
      total: debtSaleData.total
    });
    
    // Use setDoc with the custom document ID
    await setDoc(debtProductDocRef, debtSaleData);
    console.log('✅ Debt sale saved to debt_products collection with ID:', saleData.id);
    
    return saleData.id;
  } catch (error) {
    console.error('❌ Error saving to debt_products:', error);
    throw error;
  }
}

// Receipt Generation Methods
generateReceiptId(): string {
  const timestamp = new Date().getTime();
  const random = Math.floor(Math.random() * 1000);
  return `RCP-${timestamp}-${random}`;
}

// Enhanced Receipt Generation Methods with Initial Payment Support
async downloadReceiptAsImage() {
  try {
    if (!this.currentSale) {
      this.showToast('No sale data available', 'warning');
      return;
    }

    // Wait for the modal to be fully rendered
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const receiptElement = document.getElementById('receipt-content');
    
    if (!receiptElement) {
      this.showToast('Receipt element not found', 'danger');
      return;
    }

    // Create a high-resolution clone
    const clone = receiptElement.cloneNode(true) as HTMLElement;
    clone.style.width = '100%';
    clone.style.transform = 'scale(2)';
    clone.style.transformOrigin = 'top left';
    
    const tempContainer = document.createElement('div');
    tempContainer.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      z-index: -1000;
      opacity: 0;
    `;
    tempContainer.appendChild(clone);
    document.body.appendChild(tempContainer);

    // Use type assertion to bypass TypeScript checking
    const canvas = await html2canvas(clone, {
      useCORS: true,
      allowTaint: true,
      backgroundColor: '#ffffff',
      logging: false,
      scale: 2 // Higher resolution
    } as any);

    // Clean up
    document.body.removeChild(tempContainer);

    // Create high quality image
    const imageData = canvas.toDataURL('image/png', 1.0);
    const link = document.createElement('a');
    link.download = `receipt-${this.currentSale.id || 'unknown'}.png`;
    link.href = imageData;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    this.showToast('Receipt downloaded as image', 'success');
  } catch (error: any) {
    console.error('Error downloading receipt as image:', error);
    this.showToast('Error downloading receipt: ' + error.message, 'danger');
  }
}

/// ALTERNATIVE: Dynamic PDF sizing
async downloadReceiptAsPDF() {
  try {
    if (!this.currentSale) {
      this.showToast('No sale data available', 'warning');
      return;
    }

    // Wait for rendering
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const receiptElement = document.getElementById('receipt-content');
    
    if (!receiptElement) {
      this.showToast('Receipt element not found', 'danger');
      return;
    }

    // Create optimized clone
    const clone = receiptElement.cloneNode(true) as HTMLElement;
    
    // Thermal receipt styling
    clone.style.cssText = `
      width: 70mm !important;
      max-width: 70mm !important;
      padding: 5mm !important;
      margin: 0 !important;
      font-family: 'Courier New', monospace !important;
      font-size: 10px !important;
      line-height: 1.1 !important;
      background: white !important;
      color: black !important;
      box-sizing: border-box !important;
    `;

    const tempContainer = document.createElement('div');
    tempContainer.style.cssText = `
      position: fixed;
      top: -1000px;
      left: -1000px;
      width: 70mm;
      background: white;
      padding: 5mm;
      z-index: -1000;
      opacity: 0;
    `;
    tempContainer.appendChild(clone);
    document.body.appendChild(tempContainer);

    // Calculate content height in mm
    const contentHeightPx = clone.scrollHeight;
    const contentHeightMm = (contentHeightPx * 25.4) / 96; // Convert pixels to mm
    const pdfHeight = Math.max(contentHeightMm + 10, 100); // Add 10mm padding, min 100mm

    console.log('Content height:', contentHeightPx, 'px =', contentHeightMm, 'mm');

    // Create PDF with dynamic height
    const pdf = new jsPDF({
      orientation: 'portrait',
      unit: 'mm',
      format: [80, pdfHeight], // 80mm width, dynamic height
      compress: true
    });

    // Capture with proper DPI calculation
    const canvas = await html2canvas(clone, {
      backgroundColor: '#ffffff',
      scale: 3, // Higher resolution for better print quality
      logging: false,
      width: 264, // 70mm at 96 DPI
      height: contentHeightPx,
      useCORS: true,
      allowTaint: false
    } as any);

    // Clean up
    document.body.removeChild(tempContainer);

    // Add image to fill PDF
    const imgData = canvas.toDataURL('image/png', 1.0);
    const pageWidth = pdf.internal.pageSize.getWidth();
    const pageHeight = pdf.internal.pageSize.getHeight();
    
    // Fill the PDF page with the image
    pdf.addImage(imgData, 'PNG', 0, 0, pageWidth, pageHeight, '', 'FAST');

    pdf.save(`receipt-${this.currentSale.id}.pdf`);
    this.showToast('Receipt downloaded as PDF', 'success');
    
  } catch (error: any) {
    console.error('Error downloading PDF:', error);
    this.showToast('Error downloading PDF', 'danger');
  }
}

// Create optimized HTML for PDF receipt
private createPDFReceiptHTML(): string {
  const store = this.currentStoreInfo;
  const currencySymbol = store?.currency_symbol || '₱';

  if (!this.currentSale) {
    return '<div>No sale data available</div>';
  }

  return `
    <div style="width: 100%; font-family: 'Courier New', monospace; font-size: 12px; line-height: 1.2;">
      <!-- Store Header -->
      <div style="text-align: center; border-bottom: 1px dashed #000; padding-bottom: 8px; margin-bottom: 10px;">
        ${store?.logo_url ? `
          <img src="${store.logo_url}" alt="${store.name}" style="max-width: 50px; max-height: 40px; margin-bottom: 4px;">
        ` : ''}
        <h2 style="font-size: 14px; margin: 0 0 4px 0; font-weight: bold;">${store?.name || 'Retail Store'}</h2>
        <p style="font-size: 10px; margin: 2px 0;">${store?.receipt_header || 'Retail Receipt'}</p>
        ${store?.address ? `<p style="font-size: 9px; margin: 1px 0;">${store.address}</p>` : ''}
        ${store?.phone ? `<p style="font-size: 9px; margin: 1px 0;">Tel: ${store.phone}</p>` : ''}
        <p style="font-size: 9px; margin: 1px 0;">${this.getCurrentDateTime()}</p>
        <p style="font-size: 9px; margin: 1px 0;">Receipt #: ${this.currentSale.id}</p>
      </div>

      <!-- Receipt Items -->
      <div style="margin-bottom: 10px;">
        ${this.currentSale.items.map(item => `
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 10px;">
            <div style="flex: 3; font-weight: bold; word-break: break-word;">${this.truncateText(item.product.name, 20)}</div>
            <div style="flex: 2; text-align: center; font-size: 9px;">
              ${item.quantity} × ${this.formatPrice(item.price, currencySymbol)}
            </div>
            <div style="flex: 2; text-align: right; font-weight: bold; font-size: 10px;">
              ${this.formatPrice(item.subtotal, currencySymbol)}
            </div>
          </div>
        `).join('')}
      </div>

      <!-- Receipt Summary -->
      <div style="border-top: 1px dashed #000; padding-top: 8px;">
        <div style="display: flex; justify-content: space-between; margin-bottom: 3px; font-size: 11px;">
          <span>Subtotal:</span>
          <span>${this.formatPrice(this.currentSale.total, currencySymbol)}</span>
        </div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 12px; border-top: 1px solid #000; padding-top: 3px;">
          <span><strong>Total:</strong></span>
          <span><strong>${this.formatPrice(this.currentSale.total, currencySymbol)}</strong></span>
        </div>

        <!-- Payment Details -->
        <div style="margin-top: 8px; padding-top: 6px; border-top: 1px dotted #666;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 10px;">
            <span>Payment Method:</span>
            <span>${this.currentSale.paymentMethod === 'cash' ? 'CASH' : 'DEBT'}</span>
          </div>
          
          ${this.currentSale.paymentMethod === 'cash' ? `
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 10px;">
              <span>Amount Paid:</span>
              <span>${this.formatPrice(this.currentSale.amountPaid || 0, currencySymbol)}</span>
            </div>
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 10px;">
              <span>Change:</span>
              <span>${this.formatPrice(this.currentSale.change || 0, currencySymbol)}</span>
            </div>
          ` : ''}

          ${this.currentSale.paymentMethod === 'debt' && this.currentSale.customerName ? `
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 10px;">
              <span>Customer:</span>
              <span>${this.currentSale.customerName}</span>
            </div>
            ${this.currentSale.customerPhone ? `
              <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 10px;">
                <span>Phone:</span>
                <span>${this.currentSale.customerPhone}</span>
              </div>
            ` : ''}
          ` : ''}
        </div>
      </div>

      <!-- Receipt Footer -->
      <div style="text-align: center; margin-top: 10px; padding-top: 6px; border-top: 1px dashed #000; font-size: 9px;">
        <p style="margin: 4px 0; font-weight: bold;">${store?.receipt_footer || 'Thank you for your purchase!'}</p>
        <p style="margin: 4px 0;">Please come again!</p>
      </div>
    </div>
  `;
}

// Improved text truncation for PDF
private truncateText(text: string, maxLength: number): string {
  if (!text) return '';
  if (text.length <= maxLength) return text;
  return text.substring(0, maxLength - 1) + '…';
}

// Add this method for receipt-style date formatting
getReceiptDateTime(): string {
  const now = new Date();
  const month = now.toLocaleString('en', { month: 'short' });
  const day = now.getDate();
  const year = now.getFullYear();
  const time = now.toLocaleTimeString('en-PH', { 
    hour: '2-digit', 
    minute: '2-digit',
    hour12: false 
  });
  
  return `${month} ${day}-${year} ${time}`;
}

// Update the high-res method with type assertion
async downloadReceiptAsImageHighRes() {
  try {
    if (!this.currentSale) {
      this.showToast('No sale data available', 'warning');
      return;
    }

    // Create a temporary visible receipt element
    const tempReceipt = this.createTemporaryReceiptElement();
    document.body.appendChild(tempReceipt);

    // Wait for rendering
    await new Promise(resolve => setTimeout(resolve, 500));

    // Double the size for high resolution using CSS
    tempReceipt.style.transform = 'scale(2)';
    tempReceipt.style.transformOrigin = 'top left';
    tempReceipt.style.width = `${tempReceipt.scrollWidth * 2}px`;
    tempReceipt.style.height = `${tempReceipt.scrollHeight * 2}px`;

    // Capture with high resolution
    const canvas = await html2canvas(tempReceipt, {
      useCORS: true,
      backgroundColor: '#ffffff',
      logging: false,
      scale: 3 // Ultra high resolution
    } as any);

    // Clean up
    document.body.removeChild(tempReceipt);

    // Download
    const imageData = canvas.toDataURL('image/png', 1.0);
    this.downloadImage(imageData, `receipt-${this.currentSale.id}-ultra-hd.png`);
    
    this.showToast('Ultra HD receipt downloaded', 'success');
  } catch (error: any) {
    console.error('Error in high-res download:', error);
    this.showToast('Error downloading receipt', 'danger');
  }
}

// Update the simple receipt download method with type assertion
async downloadReceiptSimple() {
  try {
    if (!this.currentSale) {
      this.showToast('No sale data available', 'warning');
      return;
    }

    // Create a simple receipt HTML
    const receiptHTML = this.createSimpleReceiptHTML();
    
    // Create a temporary container
    const tempContainer = document.createElement('div');
    tempContainer.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 400px;
      background: white;
      padding: 20px;
      font-family: 'Courier New', monospace;
      border: 2px solid #000;
      z-index: 10000;
      box-shadow: 0 0 20px rgba(0,0,0,0.3);
    `;
    tempContainer.innerHTML = receiptHTML;
    
    document.body.appendChild(tempContainer);

    // Wait a bit for rendering
    await new Promise(resolve => setTimeout(resolve, 100));

    // Capture the receipt
    const canvas = await html2canvas(tempContainer, {
      backgroundColor: '#ffffff',
      logging: false,
    } as any);

    // Clean up
    document.body.removeChild(tempContainer);

    // Download
    const imageData = canvas.toDataURL('image/png', 1.0);
    this.downloadImage(imageData, `receipt-${this.currentSale.id}.png`);
    
    this.showToast('Receipt downloaded successfully', 'success');
  } catch (error: any) {
    console.error('Error downloading receipt:', error);
    this.showToast('Error downloading receipt: ' + error.message, 'danger');
  }
}
// Update the temporary receipt element creation to include initial payment details
private createTemporaryReceiptElement(): HTMLElement {
  const tempDiv = document.createElement('div');
  tempDiv.id = 'temp-receipt';
  tempDiv.innerHTML = this.createEnhancedReceiptHTML();
  tempDiv.style.cssText = `
    position: fixed;
    top: 0;
    left: 0;
    width: 400px;
    background: white;
    padding: 20px;
    font-family: 'Courier New', monospace;
    border: 2px solid #000;
    z-index: 10000;
    box-shadow: 0 0 20px rgba(0,0,0,0.3);
  `;
  return tempDiv;
}
// Enhanced receipt HTML that properly shows initial payment for debt products
private createEnhancedReceiptHTML(): string {
  const store = this.currentStoreInfo;
  const currencySymbol = store?.currency_symbol || '₱';

  if (!this.currentSale) {
    return '<div>No sale data available</div>';
  }

  const isDebtWithInitialPayment = this.currentSale.paymentMethod === 'debt' && 
                                  this.currentSale.initialPayment && 
                                  this.currentSale.initialPayment > 0;

  return `
    <div style="width: 100%; font-family: 'Courier New', monospace;">
      <!-- Store Header -->
      <div style="text-align: center; border-bottom: 2px dashed #000; padding-bottom: 10px; margin-bottom: 15px;">
        ${store?.logo_url ? `
          <img src="${store.logo_url}" alt="${store.name}" style="max-width: 150px; max-height: 80px; margin-bottom: 8px;">
        ` : ''}
        <h2 style="font-size: 20px; margin: 0 0 8px 0; font-weight: bold;">${store?.name || 'Retail Store'}</h2>
        <p style="font-size: 14px; margin: 4px 0;">${store?.receipt_header || 'Retail Receipt'}</p>
        ${store?.address ? `<p style="font-size: 12px; margin: 4px 0;">${store.address}</p>` : ''}
        ${store?.phone ? `<p style="font-size: 12px; margin: 4px 0;">Tel: ${store.phone}</p>` : ''}
        <p style="font-size: 12px; margin: 4px 0;">${this.getCurrentDateTime()}</p>
        <p style="font-size: 12px; margin: 4px 0;">Receipt #: ${this.currentSale.id || 'N/A'}</p>
      </div>

      <!-- Receipt Items -->
      <div style="margin-bottom: 15px;">
        ${this.currentSale.items.map(item => `
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 12px;">
            <div style="flex: 2; font-weight: bold;">${item.product.name}</div>
            <div style="flex: 1; text-align: center;">
              ${item.quantity} × ${this.formatPrice(item.price, currencySymbol)}
            </div>
            <div style="flex: 1; text-align: right; font-weight: bold;">
              ${this.formatPrice(item.subtotal, currencySymbol)}
            </div>
          </div>
        `).join('')}
      </div>

      <!-- Receipt Summary -->
      <div style="border-top: 2px dashed #000; padding-top: 10px;">
        ${isDebtWithInitialPayment ? `
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 12px;">
            <span>Original Total:</span>
            <span>${this.formatPrice(this.currentSale.originalTotal || this.currentSale.total, currencySymbol)}</span>
          </div>
          <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 12px; color: #d32f2f;">
            <span>Initial Payment:</span>
            <span>- ${this.formatPrice(this.currentSale.initialPayment, currencySymbol)}</span>
          </div>
        ` : ''}
        
        <div style="display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 14px; border-top: 1px solid #000; padding-top: 4px;">
          <span><strong>Total:</strong></span>
          <span><strong>${this.formatPrice(this.currentSale.total, currencySymbol)}</strong></span>
        </div>

        <!-- Payment Details -->
        <div style="margin-top: 10px; padding-top: 8px; border-top: 1px dotted #666;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
            <span>Payment Method:</span>
            <span>${this.currentSale.paymentMethod === 'cash' ? 'CASH' : 'DEBT'}</span>
          </div>
          
          ${this.currentSale.paymentMethod === 'cash' ? `
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
              <span>Amount Paid:</span>
              <span>${this.formatPrice(this.currentSale.amountPaid || 0, currencySymbol)}</span>
            </div>
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
              <span>Change:</span>
              <span>${this.formatPrice(this.currentSale.change || 0, currencySymbol)}</span>
            </div>
          ` : ''}

          ${this.currentSale.paymentMethod === 'debt' && this.currentSale.customerName ? `
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
              <span>Customer:</span>
              <span>${this.currentSale.customerName}</span>
            </div>
            ${this.currentSale.customerPhone ? `
              <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
                <span>Phone:</span>
                <span>${this.currentSale.customerPhone}</span>
              </div>
            ` : ''}
            
            ${this.currentSale.initialPayment && this.currentSale.initialPayment > 0 ? `
              <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
                <span>Paid Now:</span>
                <span>${this.formatPrice(this.currentSale.initialPayment, currencySymbol)}</span>
              </div>
            ` : ''}
            
            ${this.currentSale.remainingBalance && this.currentSale.remainingBalance > 0 ? `
              <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px; font-weight: bold; color: #f57c00;">
                <span>Remaining Balance:</span>
                <span>${this.formatPrice(this.currentSale.remainingBalance, currencySymbol)}</span>
              </div>
            ` : ''}
            
            ${this.currentSale.dueDate ? `
              <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
                <span>Due Date:</span>
                <span>${new Date(this.currentSale.dueDate).toLocaleDateString('en-PH')}</span>
              </div>
            ` : ''}
          ` : ''}
        </div>
      </div>

      <!-- Receipt Footer -->
      <div style="text-align: center; margin-top: 12px; padding-top: 8px; border-top: 2px dashed #000; font-size: 11px;">
        <p style="margin: 6px 0; font-weight: bold;">${store?.receipt_footer || 'Thank you for your purchase!'}</p>
        ${this.currentSale.paymentMethod === 'debt' && this.currentSale.remainingBalance && this.currentSale.remainingBalance > 0 ? `
          <p style="margin: 6px 0; color: #f57c00; font-weight: bold;">
            Please pay the remaining balance by the due date.
          </p>
        ` : ''}
        <p style="margin: 6px 0;">Please come again!</p>
      </div>
    </div>
  `;
}

// Add these helper methods to your Tab3Page class

// Helper method to safely check initial payment
hasInitialPayment(): boolean {
  return !!(this.currentSale?.initialPayment && this.currentSale.initialPayment > 0);
}

// Helper method to safely check remaining balance
hasRemainingBalance(): boolean {
  return !!(this.currentSale?.remainingBalance && this.currentSale.remainingBalance > 0);
}

// Helper method to safely check if it's debt with initial payment
isDebtWithInitialPayment(): boolean {
  return this.currentSale?.paymentMethod === 'debt' && this.hasInitialPayment();
}

// Helper method to create simple receipt HTML
private createSimpleReceiptHTML(): string {
  const store = this.currentStoreInfo;
  const currencySymbol = store?.currency_symbol || '₱';

  return `
    <div style="width: 100%; font-family: 'Courier New', monospace;">
      <!-- Store Header -->
      <div style="text-align: center; border-bottom: 2px dashed #000; padding-bottom: 10px; margin-bottom: 15px;">
        ${store?.logo_url ? `
          <img src="${store.logo_url}" alt="${store.name}" style="max-width: 150px; max-height: 80px; margin-bottom: 8px;">
        ` : ''}
        <h2 style="font-size: 20px; margin: 0 0 8px 0; font-weight: bold;">${store?.name || 'Retail Store'}</h2>
        <p style="font-size: 14px; margin: 4px 0;">${store?.receipt_header || 'Retail Receipt'}</p>
        ${store?.address ? `<p style="font-size: 12px; margin: 4px 0;">${store.address}</p>` : ''}
        ${store?.phone ? `<p style="font-size: 12px; margin: 4px 0;">Tel: ${store.phone}</p>` : ''}
        <p style="font-size: 12px; margin: 4px 0;">${this.getCurrentDateTime()}</p>
        <p style="font-size: 12px; margin: 4px 0;">Receipt #: ${this.currentSale?.id || 'N/A'}</p>
      </div>

      <!-- Receipt Items -->
      <div style="margin-bottom: 15px;">
        ${this.currentSale?.items.map(item => `
          <div style="display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 12px;">
            <div style="flex: 2; font-weight: bold;">${item.product.name}</div>
            <div style="flex: 1; text-align: center;">
              ${item.quantity} × ${this.formatPrice(item.price, currencySymbol)}
            </div>
            <div style="flex: 1; text-align: right; font-weight: bold;">
              ${this.formatPrice(item.subtotal, currencySymbol)}
            </div>
          </div>
        `).join('')}
      </div>

      <!-- Receipt Summary -->
      <div style="border-top: 2px dashed #000; padding-top: 10px;">
        <div style="display: flex; justify-content: space-between; margin-bottom: 4px; font-size: 12px;">
          <span>Subtotal:</span>
          <span>${this.formatPrice(this.currentSale?.total || 0, currencySymbol)}</span>
        </div>
        <div style="display: flex; justify-content: space-between; margin-bottom: 6px; font-size: 14px;">
          <span><strong>Total:</strong></span>
          <span><strong>${this.formatPrice(this.currentSale?.total || 0, currencySymbol)}</strong></span>
        </div>

        <!-- Payment Details -->
        <div style="margin-top: 10px; padding-top: 8px; border-top: 1px dotted #666;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
            <span>Payment Method:</span>
            <span>${this.currentSale?.paymentMethod === 'cash' ? 'CASH' : 'DEBT'}</span>
          </div>
          
          ${this.currentSale?.paymentMethod === 'cash' ? `
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
              <span>Amount Paid:</span>
              <span>${this.formatPrice(this.currentSale?.amountPaid || 0, currencySymbol)}</span>
            </div>
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
              <span>Change:</span>
              <span>${this.formatPrice(this.currentSale?.change || 0, currencySymbol)}</span>
            </div>
          ` : ''}

          ${this.currentSale?.paymentMethod === 'debt' && this.currentSale?.customerName ? `
            <div style="display: flex; justify-content: space-between; margin-bottom: 2px; font-size: 11px;">
              <span>Customer:</span>
              <span>${this.currentSale.customerName}</span>
            </div>
          ` : ''}
        </div>
      </div>

      <!-- Receipt Footer -->
      <div style="text-align: center; margin-top: 12px; padding-top: 8px; border-top: 2px dashed #000; font-size: 11px;">
        <p style="margin: 6px 0; font-weight: bold;">${store?.receipt_footer || 'Thank you for your purchase!'}</p>
        <p style="margin: 6px 0;">Please come again!</p>
      </div>
    </div>
  `;
}

// Helper method for downloading images
private downloadImage(dataUrl: string, filename: string) {
  const link = document.createElement('a');
  link.download = filename;
  link.href = dataUrl;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
}

// Improved print method with better popup handling
async printReceipt() {
  try {
    if (!this.currentSale) {
      this.showToast('No sale data available', 'warning');
      return;
    }

    // Create print content
    const printContent = this.createPrintableReceiptHTML();
    
    // Try to open print window with better error handling
    let printWindow: Window | null = null;
    
    try {
      printWindow = window.open('', '_blank', 'width=400,height=600,scrollbars=no,toolbar=no,location=no');
      
      if (!printWindow) {
        // If popup is blocked, show user-friendly instructions
        this.showPopupInstructions();
        return;
      }

      // Write the print content
      printWindow.document.write(`
        <!DOCTYPE html>
        <html>
          <head>
            <title>Receipt - ${this.currentSale.id}</title>
            <style>
              @media print {
                body { 
                  margin: 0 !important; 
                  padding: 0 !important;
                  -webkit-print-color-adjust: exact !important;
                  print-color-adjust: exact !important;
                }
                .receipt { 
                  max-width: 80mm !important;
                  margin: 0 auto !important;
                  padding: 10px !important;
                  border: none !important;
                  box-shadow: none !important;
                }
                .no-print { display: none !important; }
              }
              @page { 
                margin: 0 !important; 
                size: auto !important;
              }
              body { 
                font-family: 'Courier New', monospace !important; 
                margin: 0; 
                padding: 10px;
                background: white !important;
                color: black !important;
                width: 80mm;
                margin: 0 auto;
              }
              .receipt { 
                max-width: 80mm; 
                margin: 0 auto;
                border: 1px solid #ccc;
                padding: 15px;
                background: white;
              }
              .receipt-header {
                text-align: center;
                border-bottom: 1px dashed #000;
                padding-bottom: 10px;
                margin-bottom: 12px;
              }
              .receipt-header h2 {
                font-size: 16px;
                margin: 0 0 8px 0;
                font-weight: bold;
              }
              .receipt-header p {
                margin: 4px 0;
                font-size: 12px;
              }
              .receipt-item {
                display: flex;
                justify-content: space-between;
                margin-bottom: 6px;
                font-size: 12px;
              }
              .item-name {
                flex: 3;
                font-weight: bold;
              }
              .item-details {
                flex: 2;
                text-align: center;
                font-size: 11px;
              }
              .item-total {
                flex: 2;
                text-align: right;
                font-weight: bold;
              }
              .receipt-summary {
                border-top: 1px dashed #000;
                padding-top: 10px;
                font-size: 12px;
              }
              .summary-row {
                display: flex;
                justify-content: space-between;
                margin-bottom: 6px;
              }
              .total-row {
                border-top: 1px solid #000;
                padding-top: 4px;
                font-size: 14px;
              }
              .payment-details {
                margin-top: 10px;
                padding-top: 8px;
                border-top: 1px dotted #666;
                font-size: 11px;
              }
              .receipt-footer {
                text-align: center;
                margin-top: 12px;
                padding-top: 8px;
                border-top: 1px dashed #000;
                font-size: 11px;
              }
              .print-button {
                display: block;
                width: 100%;
                padding: 10px;
                margin: 10px 0;
                background: #007bff;
                color: white;
                border: none;
                border-radius: 4px;
                cursor: pointer;
                font-size: 14px;
              }
              .print-button:hover {
                background: #0056b3;
              }
            </style>
          </head>
          <body>
            ${printContent}
            <div class="no-print" style="text-align: center; margin-top: 20px;">
              <button class="print-button" onclick="window.print()">🖨️ Print Receipt</button>
              <button class="print-button" onclick="window.close()" style="background: #6c757d;">❌ Close Window</button>
              <p style="font-size: 12px; color: #666; margin-top: 10px;">
                If print dialog doesn't open automatically, click the "Print Receipt" button above.
              </p>
            </div>
            <script>
              // Try to auto-print after a short delay
              setTimeout(function() {
                window.print();
              }, 500);
              
              // Close window after print (if possible)
              window.onafterprint = function() {
                setTimeout(function() {
                  window.close();
                }, 1000);
              };
            </script>
          </body>
        </html>
      `);

      printWindow.document.close();
      
      // Focus the window
      printWindow.focus();
      
    } catch (error) {
      console.error('Error opening print window:', error);
      this.showPopupInstructions();
    }

  } catch (error: any) {
    console.error('Error printing receipt:', error);
    this.showToast('Error printing receipt: ' + error.message, 'danger');
  }
}

// Show user-friendly popup instructions
private showPopupInstructions() {
  this.alertController.create({
    header: 'Popup Blocked',
    message: 'Please allow popups for this site to print receipts. Here\'s how:<br><br>' +
             '1. Look for the popup blocker icon in your address bar<br>' +
             '2. Click it and select "Always allow popups from this site"<br>' +
             '3. Try printing again<br><br>' +
             'Alternatively, you can download the receipt as PDF or Image instead.',
    buttons: [
      {
        text: 'Download as PDF',
        handler: () => {
          this.downloadReceiptAsPDF();
        }
      },
      {
        text: 'Download as Image',
        handler: () => {
          this.downloadReceiptSimple();
        }
      },
      {
        text: 'OK',
        role: 'cancel'
      }
    ]
  }).then(alert => alert.present());
}

// Update this method in your .ts file
private createPrintableReceiptHTML(): string {
  const store = this.currentStoreInfo;
  const currencySymbol = store?.currency_symbol || '₱';

  // Add null checks for currentSale
  if (!this.currentSale) {
    return '<div>No sale data available</div>';
  }

  return `
    <div class="receipt">
      <!-- Receipt Header -->
      <div class="receipt-header">
        ${store?.logo_url ? `
          <div class="store-logo">
            <img src="${store.logo_url}" alt="${store.name}" style="max-width: 150px; max-height: 80px; margin-bottom: 8px;">
          </div>
        ` : ''}
        <h2>${store?.name || 'Retail Store'}</h2>
        <p>${store?.receipt_header || 'Retail Receipt'}</p>
        ${store?.address ? `<p>${store.address}</p>` : ''}
        ${store?.phone ? `<p>Tel: ${store.phone}</p>` : ''}
        <p>${this.getCurrentDateTime()}</p>
        <p>Receipt #: ${this.currentSale.id || 'N/A'}</p>
      </div>

      <!-- Receipt Items -->
      <div class="receipt-items">
        ${this.currentSale.items.map(item => `
          <div class="receipt-item">
            <div class="item-name">${item.product.name}</div>
            <div class="item-details">${item.quantity} × ${this.formatPrice(item.price, currencySymbol)}</div>
            <div class="item-total">${this.formatPrice(item.subtotal, currencySymbol)}</div>
          </div>
        `).join('')}
      </div>

      <!-- Receipt Summary -->
      <div class="receipt-summary">
        <div class="summary-row">
          <span>Subtotal:</span>
          <span>${this.formatPrice(this.currentSale.total, currencySymbol)}</span>
        </div>
        <div class="summary-row total-row">
          <span><strong>Total:</strong></span>
          <span><strong>${this.formatPrice(this.currentSale.total, currencySymbol)}</strong></span>
        </div>

        <!-- Payment Details -->
        <div class="payment-details">
          <div class="summary-row">
            <span>Payment Method:</span>
            <span>${this.currentSale.paymentMethod === 'cash' ? 'CASH' : 'DEBT'}</span>
          </div>
          
          ${this.currentSale.paymentMethod === 'cash' ? `
            <div class="summary-row">
              <span>Amount Paid:</span>
              <span>${this.formatPrice(this.currentSale.amountPaid || 0, currencySymbol)}</span>
            </div>
            <div class="summary-row">
              <span>Change:</span>
              <span>${this.formatPrice(this.currentSale.change || 0, currencySymbol)}</span>
            </div>
          ` : ''}

          ${this.currentSale.paymentMethod === 'debt' && this.currentSale.customerName ? `
            <div class="summary-row">
              <span>Customer:</span>
              <span>${this.currentSale.customerName}</span>
            </div>
            ${this.currentSale.customerPhone ? `
              <div class="summary-row">
                <span>Phone:</span>
                <span>${this.currentSale.customerPhone}</span>
              </div>
            ` : ''}
          ` : ''}
        </div>
      </div>

      <!-- Receipt Footer -->
      <div class="receipt-footer">
        <p>${store?.receipt_footer || 'Thank you for your purchase!'}</p>
        <p>Please come again!</p>
      </div>
    </div>
  `;
}

  // Utility Methods
  private async showToast(message: string, color: string) {
    const toast = await this.toastController.create({
      message,
      duration: 3000,
      color,
      position: 'bottom'
    });
    await toast.present();
  }

// Update the formatPrice method to handle undefined
formatPrice(price: number | undefined, currencySymbol?: string): string {
  const symbol = currencySymbol || '₱';
  const actualPrice = price || 0;
  return `${symbol}${actualPrice.toFixed(2)}`;
}

  getCurrentDateTime(): string {
    return new Date().toLocaleString('en-PH', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  }

//  // Update the onCustomerSearch method
// async onCustomerSearch() {
//   try {
//     if (this.customerSearchTerm.trim().length >= 2) {
//       this.filteredCustomers = await this.authService.searchCustomersByLocation(this.customerSearchTerm);
//     } else if (this.customerSearchTerm.trim() === '') {
//       this.filteredCustomers = await this.authService.getCustomersByStoreOwnerLocation();
//     }
//   } catch (error) {
//     console.error('Error searching customers:', error);
//     this.filteredCustomers = [];
//     this.showToast('Error loading customers', 'danger');
//   }
// }

selectCustomer(customer: any) {
  this.customerName = customer.full_name;
  this.customerPhone = customer.phone_number;
  this.showCustomerModal = false;
  this.showPaymentModal = true;
  
  // You can also store the customer ID for debt tracking
  console.log('Selected customer:', customer);
}

onCustomerModalDismiss() {
  this.customerSearchTerm = '';
  this.filteredCustomers = [];
}

// Add to your Tab3Page class in tab3.page.ts

// Update your existing registerNewCustomer method to include credential validation
async registerNewCustomer() {
  try {
    // Validate all required fields including credentials
    if (!this.isFormValid()) {
      this.showToast('Please fill all required fields correctly', 'warning');
      return;
    }

    // Validate phone number format
    const phoneRegex = /^[0-9+\-\s()]{10,}$/;
    if (!phoneRegex.test(this.newCustomer.phone_number)) {
      this.showToast('Please enter a valid phone number (at least 10 digits)', 'warning');
      return;
    }

    const loading = await this.loadingController.create({
      message: 'Registering customer...'
    });
    await loading.present();

    try {
      // Use the debt customer registration service with credentials
      await this.debtCustomerRegistrationService.registerDebtCustomer({
        full_name: this.newCustomer.full_name.trim(),
        phone_number: this.newCustomer.phone_number.trim(),
        email: this.newCustomer.email?.trim() || '',
        municipality: this.selectedMunicipality,
        barangay: this.selectedBarangay,
        sitio_purok: this.newCustomer.sitio_purok?.trim() || '',
        username: this.newCustomer.username.trim(),        // ADD THIS
        password: this.newCustomer.password.trim()         // ADD THIS
      });

      await loading.dismiss();
      
      this.showToast('Customer registered successfully!', 'success');
      this.showNewCustomerForm = false;
      
      // Reset form and location selections
      this.resetCustomerForm();
      
      // Refresh customer list
      await this.onCustomerSearch();
      
    } catch (error: any) {
      await loading.dismiss();
      throw error;
    }
    
  } catch (error: any) {
    console.error('Error registering customer:', error);
    this.showToast('Error registering customer: ' + error.message, 'danger');
  }
}

// Update your resetCustomerForm method
private resetCustomerForm() {
  this.newCustomer = {
    full_name: '',
    phone_number: '',
    email: '',
    sitio_purok: '',
    username: '',           // ADD THIS
    password: '',           // ADD THIS
    confirmPassword: ''     // ADD THIS
  };
  this.selectedMunicipality = '';
  this.selectedBarangay = '';
  this.barangays = [];
  this.searchMunicipality = '';
  this.searchBarangay = '';
  this.passwordsMatch = false;
  this.isPasswordValid = false;
}

// ✅ ENHANCED: Location loading with initialization
async loadStoreOwnerLocationInfo() {
  try {
    // Ensure location data is loaded first
    await this.locationService.loadLocationData();

    const loading = await this.loadingController.create({
      message: 'Loading store location...',
      duration: 2000
    });
    await loading.present();

    this.storeOwnerLocationInfo = await this.debtCustomerRegistrationService.getStoreOwnerLocationInfo();
    
    await loading.dismiss();

    if (this.storeOwnerLocationInfo) {
      this.municipalities = this.storeOwnerLocationInfo.municipalities || [];
      console.log('📍 Store owner location loaded:', {
        province: this.storeOwnerLocationInfo.province,
        region: this.storeOwnerLocationInfo.region,
        municipalitiesCount: this.municipalities.length
      });
      
      // Show location info to user
      this.showToast(`Store location: ${this.storeOwnerLocationInfo.province}, ${this.storeOwnerLocationInfo.region}`, 'success');
    } else {
      console.warn('⚠️ No store owner location info found');
      this.municipalities = [];
      this.showToast('Store location information not available. Please ensure store owner has set their province in their profile.', 'warning');
    }
  } catch (error) {
    console.error('Error loading store owner location info:', error);
    this.municipalities = [];
    this.showToast('Error loading store location information', 'danger');
  }
}

// ✅ NEW: Load barangays when municipality is selected
private loadBarangaysForSelectedMunicipality() {
  if (this.storeOwnerLocationInfo && this.selectedMunicipality) {
    this.barangays = this.debtCustomerRegistrationService.getBarangays(
      this.selectedMunicipality, 
      this.storeOwnerLocationInfo.province
    );
    
    console.log('📍 Loaded barangays:', {
      municipality: this.selectedMunicipality,
      province: this.storeOwnerLocationInfo.province,
      barangaysCount: this.barangays.length
    });

    // Auto-clear barangay selection when municipality changes
    this.selectedBarangay = '';
  } else {
    this.barangays = [];
    this.selectedBarangay = '';
  }
}

// ✅ UPDATED: Municipality selection with barangay loading
selectMunicipality(municipalityName: string) {
  this.selectedMunicipality = municipalityName;
  
  // Load barangays for selected municipality
  this.loadBarangaysForSelectedMunicipality();
  
  this.closeMunicipalitySelection();
}

// ✅ ENHANCED: New customer form opening
async openNewCustomerForm() {
  // Validate store owner location first
  const hasLocation = await this.debtCustomerRegistrationService.validateStoreOwnerLocation();
  
  if (!hasLocation) {
    this.showToast('Store location not set. Please ensure store owner has set their province in their profile.', 'warning');
    return;
  }

  this.showNewCustomerForm = true;
  
  // Reset form
  this.resetCustomerForm();
  
  // Load location data
  await this.loadStoreOwnerLocationInfo();
}

// ✅ UPDATE: Enhanced customer search to show location info
async onCustomerSearch() {
  try {
    if (this.customerSearchTerm.trim().length >= 2) {
      this.filteredCustomers = await this.authService.searchCustomersByLocation(this.customerSearchTerm);
    } else if (this.customerSearchTerm.trim() === '') {
      this.filteredCustomers = await this.authService.getCustomersByStoreOwnerLocation();
    }

    console.log('🔍 Customer search results:', {
      searchTerm: this.customerSearchTerm,
      resultsCount: this.filteredCustomers.length,
      customers: this.filteredCustomers.map(c => ({
        name: c.full_name,
        province: c.province,
        region: c.region,
        municipality: c.municipality
      }))
    });

  } catch (error) {
    console.error('Error searching customers:', error);
    this.filteredCustomers = [];
    this.showToast('Error loading customers', 'danger');
  }
}




// Search functionality for municipalities
get filteredMunicipalities(): string[] {
  if (!this.searchMunicipality) return this.municipalities;
  return this.municipalities.filter(municipality => 
    municipality.toLowerCase().includes(this.searchMunicipality.toLowerCase())
  );
}

// Search functionality for barangays
get filteredBarangays(): string[] {
  if (!this.searchBarangay) return this.barangays;
  return this.barangays.filter(barangay => 
    barangay.toLowerCase().includes(this.searchBarangay.toLowerCase())
  );
}

// Modal open handlers
openMunicipalitySelection() {
  if (!this.storeOwnerLocationInfo) {
    this.showToast('Store location information not available', 'warning');
    return;
  }
  this.searchMunicipality = '';
  this.showMunicipalityModal = true;
}

openBarangaySelection() {
  if (!this.selectedMunicipality) {
    this.showToast('Please select a municipality first', 'warning');
    return;
  }
  this.searchBarangay = '';
  this.showBarangayModal = true;
}

// Modal close handlers
closeMunicipalitySelection() {
  this.showMunicipalityModal = false;
}

closeBarangaySelection() {
  this.showBarangayModal = false;
}



selectBarangay(barangay: string) {
  this.selectedBarangay = barangay;
  this.closeBarangaySelection();
}

// Search handlers
onMunicipalitySearch() {
  // Search is handled by the filteredMunicipalities getter
}

onBarangaySearch() {
  // Search is handled by the filteredBarangays getter
}
// Password validation method
validatePassword() {
  // Check if password meets minimum requirements
  this.isPasswordValid = this.newCustomer.password && this.newCustomer.password.length >= 4;
  
  // Check if passwords match
  this.passwordsMatch = this.newCustomer.password === this.newCustomer.confirmPassword && this.newCustomer.password !== '';
}

// Username input handler
onUsernameInput() {
  // You can add username validation here if needed
  // For example, check for special characters, etc.
  if (this.newCustomer.username) {
    this.newCustomer.username = this.newCustomer.username.toLowerCase();
  }
}

// Form validation method
isFormValid(): boolean {
  const basicInfoValid = this.newCustomer.full_name && 
                        this.newCustomer.phone_number && 
                        this.selectedMunicipality && 
                        this.selectedBarangay;
  
  const credentialsValid = this.newCustomer.username && 
                          this.newCustomer.password && 
                          this.newCustomer.confirmPassword && 
                          this.isPasswordValid && 
                          this.passwordsMatch;
  
  return basicInfoValid && credentialsValid;
}
// Add this method to calculate due date
calculateDueDate() {
  const today = new Date();
  const dueDate = new Date();
  
  if (this.selectedDueDateOption === '15') {
    dueDate.setDate(today.getDate() + 15);
  } else if (this.selectedDueDateOption === '30') {
    dueDate.setDate(today.getDate() + 30);
  } else if (this.selectedDueDateOption === 'custom' && this.customDueDate) {
    dueDate.setTime(new Date(this.customDueDate).getTime());
  }
  
  // Format date for display
  this.calculatedDueDate = dueDate.toLocaleDateString('en-PH', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    weekday: 'long'
  });
  
  return dueDate;
}
}