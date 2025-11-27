import { Component, OnInit, ViewChild } from '@angular/core';
import { IonInput, AlertController, ToastController, LoadingController } from '@ionic/angular';
import { ProductService, Product, ProductSearchResult } from 'src/app/services/product.service';
import { AuthService } from 'src/app/services/auth.service';
import { CameraService } from 'src/app/services/camera.service';
import { BarcodeScannerService } from 'src/app/services/barcode-scanner.service';
import { JsqrBarcodeScannerService } from 'src/app/services/jsqr-barcode-scanner.service';
import { QuaggaBarcodeScannerService } from 'src/app/services/quagga-barcode-scanner.service'; // Add this

@Component({
  selector: 'app-tab4',
  templateUrl: './tab4.page.html',
  styleUrls: ['./tab4.page.scss'],
  standalone: false,
})
export class Tab4Page implements OnInit {
  @ViewChild('barcodeInput', { read: IonInput }) barcodeInput!: IonInput;

  // Product data
  products: Product[] = [];
  filteredProducts: Product[] = [];
  searchTerm: string = '';

  // Modal states
  showProductModal = false;
  showBarcodeInput = false;
  showStockModal = false;
  showScannerModal = false;

  // Form data
  selectedProduct: Product | null = null;
  formProduct: Product = this.getDefaultProduct();
  enableBulkPricing = false;

  // Barcode input
  manualBarcode: string = '';
  scannedProduct: ProductSearchResult | null = null;

  // Scanner states
  isScanning = false;

  // Stock adjustment
  stockAdjustment = {
    type: 'stock_in',
    quantity: 0,
    reason: ''
  };

  // Loading states
  isLoading = false;
  isSaving = false;
  isAdjustingStock = false;

  // Product summary
  productSummary = {
    total_products: 0,
    in_stock: 0,
    low_stock: 0,
    out_of_stock: 0
  };

  // Product details
  showProductDetailsModal = false;
  productDetails: Product | null = null;
  productTransactions: any[] = [];

  // Add these with your other properties
  showCameraOptions = false;
  isCapturingImage = false;
  cameraImage: string | null = null;

  // Add this with your other modal states
  showLowStockModal = false;
  lowStockProducts: Product[] = [];

  enableAdvancedBulk = false;

  showAdvancedFilters = false;
  filters = {
    category: '',
    stockStatus: '',
    minPrice: null as number | null,
    maxPrice: null as number | null,
    addedAfter: '',
    addedBefore: '',
    sortBy: 'name_asc',
    productType: ''
  };

  showOutOfStockModal = false;
  outOfStockProducts: Product[] = [];
  // Test barcodes
  testBarcodes: string[] = [];

  // Barcode input timeout
  private barcodeTimeout: any;

  constructor(
    private productService: ProductService,
    private authService: AuthService,
    private alertController: AlertController,
    private toastController: ToastController,
    private loadingController: LoadingController,
    private cameraService: CameraService, // Add this
    // private barcodeScannerService: BarcodeScannerService,
    private jsqrBarcodeScannerService: JsqrBarcodeScannerService,// Use JSQR instead // Add this
    private quaggaBarcodeScannerService: QuaggaBarcodeScannerService // Add this
  ) { }

  // Camera Methods
// In your Tab4Page component
// In your Tab4Page component - FIXED VERSION
async captureProductImage() {
  try {
    this.isCapturingImage = true;
    
    console.log('Starting image capture...');
    
    // Use the camera service directly
    const imageDataUrl = await this.cameraService.takePicture();
    
    if (imageDataUrl) {
      this.cameraImage = imageDataUrl;
      
      // If we're in the product modal, set the image
      if (this.showProductModal) {
        this.formProduct.image_url = imageDataUrl;
        await this.showToast('Product image captured successfully!', 'success');
      } else {
        await this.showToast('Image captured! Open product form to use it.', 'success');
      }
    }
    
  } catch (error: any) {
    console.error('Capture image error:', error);
    
    // Only show error if it wasn't a user cancellation
    if (!error.message.includes('canceled') && !error.message.includes('User cancelled')) {
      let errorMessage = 'Failed to capture image';
      
      if (error.message.includes('permission')) {
        errorMessage = 'Camera permission denied. Please allow camera access in your browser settings.';
      } else if (error.message.includes('not available')) {
        errorMessage = 'Camera not available on this device.';
      } else {
        errorMessage = `Failed to capture image: ${error.message}`;
      }
      
      await this.showToast(errorMessage, 'danger');
    } else {
      console.log('User canceled image capture');
    }
  } finally {
    this.isCapturingImage = false;
  }
}

async pickImageFromGallery() {
  try {
    const imageDataUrl = await this.cameraService.pickFromGallery();
    this.cameraImage = imageDataUrl;
    
    // If we're in the product modal, set the image
    if (this.showProductModal) {
      this.formProduct.image_url = imageDataUrl;
      await this.showToast('Image selected from gallery!', 'success');
    } else {
      await this.showToast('Image selected! Open product form to use it.', 'success');
    }
    
  } catch (error: any) {
    console.error('Pick image error:', error);
    if (!error.message.includes('canceled')) {
      await this.showToast('Failed to pick image: ' + error.message, 'danger');
    }
  }
}

clearCapturedImage() {
  this.cameraImage = null;
  if (this.showProductModal) {
    this.formProduct.image_url = '';
  }
}

// Product Type Handling
onProductTypeChange() {
  // Ensure has_barcode is always a boolean by providing a default value
  const hasBarcode = this.formProduct.has_barcode ?? true;
  
  if (hasBarcode) {
    // Clear custom ID when switching to barcode product
    this.formProduct.custom_product_id = '';
  } else {
    // Clear barcode when switching to no-barcode product
    this.formProduct.barcode = '';
    this.scannedProduct = null;
    // Generate a custom ID if empty
    if (!this.formProduct.custom_product_id) {
      this.generateCustomId();
    }
  }
}
// Custom ID Generation
generateCustomId() {
  const timestamp = new Date().getTime().toString().slice(-4);
  const random = Math.floor(Math.random() * 1000).toString().padStart(3, '0');
  this.formProduct.custom_product_id = `PROD-${timestamp}${random}`;
}

// Bulk Options Management
addBulkOption() {
  if (!this.formProduct.bulk_options) {
    this.formProduct.bulk_options = [];
  }
  
  this.formProduct.bulk_options.push({
    unit: '',
    pieces: 1,
    selling_price: 0,
    cost_price: 0,
    is_default: this.formProduct.bulk_options.length === 0 // First one is default
  });
}

removeBulkOption(index: number) {
  if (this.formProduct.bulk_options && this.formProduct.bulk_options.length > index) {
    const wasDefault = this.formProduct.bulk_options[index].is_default;
    this.formProduct.bulk_options.splice(index, 1);
    
    // If we removed the default, set the first one as default
    if (wasDefault && this.formProduct.bulk_options.length > 0) {
      this.formProduct.bulk_options[0].is_default = true;
    }
  }
}

setDefaultBulkOption(index: number) {
  if (this.formProduct.bulk_options) {
    // Set all others to false
    this.formProduct.bulk_options.forEach((option, i) => {
      option.is_default = i === index;
    });
  }
}

private async showCameraPermissionAlert() {
  const alert = await this.alertController.create({
    header: 'Camera Permission Required',
    message: 'Please allow camera access to use the barcode scanner. You can also use manual barcode entry.',
    buttons: [
      {
        text: 'Enter Manually',
        handler: () => {
          this.enterBarcodeManually();
        }
      },
      {
        text: 'Try Again',
        handler: () => {
          this.scanBarcodeWithCamera();
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
  // Update the scan method:
async scanBarcodeWithCamera() {
  try {
    const loading = await this.loadingController.create({
      message: 'Opening camera scanner...',
      duration: 8000
    });
    await loading.present();

    console.log('Starting JSQR barcode scanner...');
    
    const barcode = await this.jsqrBarcodeScannerService.scanBarcode();
    
    await loading.dismiss();

    if (barcode) {
      console.log('Barcode scanned successfully:', barcode);
      await this.showToast(`✅ Barcode scanned: ${barcode}`, 'success');
      await this.handleScannedBarcode(barcode);
    } else {
      await this.showToast('❌ No barcode detected', 'warning');
    }

  } catch (error: any) {
    await this.loadingController.dismiss();
    
    console.error('JSQR scan error:', error);
    
    if (error.message.includes('permission')) {
      await this.showCameraPermissionAlert();
    } else if (error.message.includes('too long')) {
      await this.showToast('⏱️ ' + error.message, 'warning');
    } else {
      await this.showToast(`❌ ${error.message}`, 'danger');
    }
  }
}

// Update camera options to use JSQR:
// Update camera options to include Quagga:
async openCameraOptions() {
  const alert = await this.alertController.create({
    header: 'Camera & Barcode Options',
    message: 'Choose an option',
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
        text: '🖼️ Upload Barcode Image',
        handler: () => {
          this.uploadBarcodeImage();
        }
      },
      {
        text: '📸 Capture Product Image',
        handler: () => {
          this.captureProductImage();
        }
      },
      {
        text: '🖼️ Pick from Gallery',
        handler: () => {
          this.pickImageFromGallery();
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

// Add Quagga scanning method
async scanBarcodeWithQuagga() {
  try {
    const loading = await this.loadingController.create({
      message: 'Opening 1D barcode scanner...'
    });
    await loading.present();

    console.log('Starting Quagga barcode scanner...');
    
    const barcode = await this.quaggaBarcodeScannerService.scanBarcode();
    
    await loading.dismiss();

    if (barcode) {
      console.log('Barcode scanned successfully:', barcode);
      await this.showToast(`✅ Barcode scanned: ${barcode}`, 'success');
      await this.handleScannedBarcode(barcode);
    } else {
      await this.showToast('❌ No barcode detected', 'warning');
    }

  } catch (error: any) {
    await this.loadingController.dismiss();
    
    console.error('Quagga scan error:', error);
    
    if (error.message.includes('permission')) {
      await this.showCameraPermissionAlert();
    } else if (error.message.includes('timeout')) {
      await this.showToast('⏱️ Scanning took too long. Please try again with better lighting.', 'warning');
    } else {
      await this.showToast(`❌ ${error.message}`, 'danger');
    }
  }
}

// Add upload method for JSQR:
// Update upload method to use Quagga for better 1D barcode support:
async uploadBarcodeImage() {
  const input = document.createElement('input');
  input.type = 'file';
  input.accept = 'image/*';
  
  input.onchange = async (event: any) => {
    const file = event.target.files[0];
    if (file) {
      try {
        const loading = await this.loadingController.create({
          message: 'Reading barcode from image...'
        });
        await loading.present();

        // Use Quagga for file scanning (better for 1D barcodes)
        const barcode = await this.quaggaBarcodeScannerService.scanBarcodeFromFile(file);
        
        await loading.dismiss();

        if (barcode) {
          await this.showToast(`✅ Barcode found: ${barcode}`, 'success');
          await this.handleScannedBarcode(barcode);
        } else {
          await this.showToast('❌ No barcode found in image', 'warning');
        }
      } catch (error: any) {
        await this.loadingController.dismiss();
        await this.showToast('❌ ' + error.message, 'danger');
      }
    }
  };
  
  input.click();
}


  async ngOnInit() {
    this.testBarcodes = this.productService.getTestBarcodes();
    await this.loadProducts();
  }

  async ionViewWillEnter() {
    await this.loadProducts();
  }

  // Barcode Scanner Methods - FIXED
  openBarcodeInput() {
    this.showBarcodeInput = true;
    this.scannedProduct = null;
    this.manualBarcode = '';
    
    // Focus the input field with proper error handling
    setTimeout(() => {
      this.focusBarcodeInput();
    }, 300);
  }

  private async focusBarcodeInput() {
    try {
      if (this.barcodeInput) {
        await this.barcodeInput.setFocus();
      } else {
        // Fallback: try to focus using native element
        const nativeElement = document.querySelector('ion-input#barcodeInput') as HTMLIonInputElement;
        if (nativeElement) {
          await nativeElement.setFocus();
        }
      }
    } catch (error) {
      console.warn('Could not focus barcode input:', error);
    }
  }

  openBarcodeInputForForm() {
    this.closeProductModal();
    this.openBarcodeInput();
  }

  clearBarcodeInput() {
    this.manualBarcode = '';
    this.scannedProduct = null;
  }

  clearScanResult() {
    this.scannedProduct = null;
    this.manualBarcode = '';
  }

  async onBarcodeInput() {
    // Clear previous timeout
    if (this.barcodeTimeout) {
      clearTimeout(this.barcodeTimeout);
    }

    // Wait for user to stop typing
    this.barcodeTimeout = setTimeout(async () => {
      if (this.manualBarcode.length >= 8) {
        await this.handleScannedBarcode(this.manualBarcode);
      }
    }, 800);
  }

  async handleScannedBarcode(barcode: string) {
    try {
      const loading = await this.loadingController.create({
        message: 'Searching product...',
      });
      await loading.present();

      this.scannedProduct = await this.productService.searchOrCreateProductByBarcode(barcode);
      
      await loading.dismiss();
      
      if (this.scannedProduct.exists) {
        await this.showToast('Product found in inventory!', 'success');
      } else {
        await this.showToast('New product detected', 'warning');
      }

    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    }
  }

  openAddProductWithBarcode() {
    if (this.scannedProduct?.product) {
      this.formProduct = { ...this.scannedProduct.product };
      this.showBarcodeInput = false;
      this.showProductModal = true;
    }
  }

async viewScannedProduct() {
  if (this.scannedProduct?.product) {
    this.showBarcodeInput = false;
    this.showScannerModal = false; // Close scanner modal if open
    
    // Directly set up the product details modal
    this.productDetails = this.scannedProduct.product;
    
    const loading = await this.loadingController.create({
      message: 'Loading product details...'
    });
    
    try {
      await loading.present();
      this.productTransactions = await this.productService.getProductTransactions(this.scannedProduct.product.id!);
      await loading.dismiss();
      
      this.showProductDetailsModal = true;
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast('Error loading product details', 'danger');
    }
  }
}

  // Manual barcode entry (fallback)
  async enterBarcodeManually() {
    const alert = await this.alertController.create({
      header: 'Enter Barcode',
      inputs: [
        {
          name: 'barcode',
          type: 'text',
          placeholder: 'Enter barcode number',
          attributes: {
            inputmode: 'numeric',
            pattern: '[0-9]*'
          }
        }
      ],
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Search',
          handler: async (data) => {
            if (data.barcode && data.barcode.trim() !== '') {
              await this.handleScannedBarcode(data.barcode.trim());
            }
            return false;
          }
        }
      ]
    });

    await alert.present();
  }

  // Product Management Methods
  async loadProducts() {
    this.isLoading = true;
    try {
      this.products = await this.productService.getStoreProducts();
      this.filteredProducts = [...this.products];
      this.updateProductSummary();
      console.log('✅ Products loaded:', this.products.length);
    } catch (error: any) {
      console.error('❌ Error loading products:', error);
      await this.showToast(error.message, 'danger');
    } finally {
      this.isLoading = false;
    }
  }

  updateProductSummary() {
    this.productSummary = {
      total_products: this.products.length,
      in_stock: this.products.filter(p => p.stock_quantity > p.min_stock_level).length,
      low_stock: this.products.filter(p => 
        p.stock_quantity > 0 && p.stock_quantity <= p.min_stock_level
      ).length,
      out_of_stock: this.products.filter(p => p.stock_quantity === 0).length
    };
  }

  // Fast search implementation
  fastSearchProducts(searchTerm: string): Product[] {
    return this.productService.searchLocalProducts(this.products, searchTerm);
  }

// Filter Methods
onFiltersToggle() {
  if (this.showAdvancedFilters) {
    this.applyFilters();
  }
}

applyFilters() {
  let filtered = [...this.products];

  // Text search
  if (this.searchTerm) {
    filtered = this.fastSearchProducts(this.searchTerm);
  }

  // Category filter
  if (this.filters.category) {
    filtered = filtered.filter(product => 
      product.category === this.filters.category
    );
  }

  // Stock status filter
  if (this.filters.stockStatus) {
    switch (this.filters.stockStatus) {
      case 'in_stock':
        filtered = filtered.filter(product => 
          product.stock_quantity > product.min_stock_level
        );
        break;
      case 'low_stock':
        filtered = filtered.filter(product => 
          product.stock_quantity > 0 && product.stock_quantity <= product.min_stock_level
        );
        break;
      case 'out_of_stock':
        filtered = filtered.filter(product => product.stock_quantity === 0);
        break;
    }
  }

  // Price range filter
  if (this.filters.minPrice !== null) {
    filtered = filtered.filter(product => 
      product.selling_price >= this.filters.minPrice!
    );
  }
  if (this.filters.maxPrice !== null) {
    filtered = filtered.filter(product => 
      product.selling_price <= this.filters.maxPrice!
    );
  }

  // Date filters
  if (this.filters.addedAfter) {
    const afterDate = new Date(this.filters.addedAfter);
    filtered = filtered.filter(product => {
      const productDate = new Date(product.created_at);
      return productDate >= afterDate;
    });
  }
  if (this.filters.addedBefore) {
    const beforeDate = new Date(this.filters.addedBefore);
    filtered = filtered.filter(product => {
      const productDate = new Date(product.created_at);
      return productDate <= beforeDate;
    });
  }

  // Product type filter
  if (this.filters.productType) {
    if (this.filters.productType === 'barcode') {
      filtered = filtered.filter(product => product.has_barcode);
    } else if (this.filters.productType === 'no_barcode') {
      filtered = filtered.filter(product => !product.has_barcode);
    }
  }

  // Apply sorting
  filtered = this.sortProducts(filtered);

  this.filteredProducts = filtered;
}

sortProducts(products: Product[]): Product[] {
  const sorted = [...products];
  
  switch (this.filters.sortBy) {
    case 'name_asc':
      return sorted.sort((a, b) => a.name.localeCompare(b.name));
    case 'name_desc':
      return sorted.sort((a, b) => b.name.localeCompare(a.name));
    case 'price_asc':
      return sorted.sort((a, b) => a.selling_price - b.selling_price);
    case 'price_desc':
      return sorted.sort((a, b) => b.selling_price - a.selling_price);
    case 'stock_asc':
      return sorted.sort((a, b) => a.stock_quantity - b.stock_quantity);
    case 'stock_desc':
      return sorted.sort((a, b) => b.stock_quantity - a.stock_quantity);
    case 'date_desc':
      return sorted.sort((a, b) => 
        new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );
    case 'date_asc':
      return sorted.sort((a, b) => 
        new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
      );
    default:
      return sorted;
  }
}

// Update your existing filterProducts method to use the new filter system
filterProducts() {
  this.applyFilters();
}

// Clear individual filter
clearFilter(filterKey: string) {
  switch (filterKey) {
    case 'category':
      this.filters.category = '';
      break;
    case 'stockStatus':
      this.filters.stockStatus = '';
      break;
    case 'minPrice':
      this.filters.minPrice = null;
      break;
    case 'maxPrice':
      this.filters.maxPrice = null;
      break;
    case 'addedAfter':
      this.filters.addedAfter = '';
      break;
    case 'addedBefore':
      this.filters.addedBefore = '';
      break;
    case 'productType':
      this.filters.productType = '';
      break;
  }
  this.applyFilters();
}

// Clear all filters
clearAllFilters() {
  this.filters = {
    category: '',
    stockStatus: '',
    minPrice: null,
    maxPrice: null,
    addedAfter: '',
    addedBefore: '',
    sortBy: 'name_asc',
    productType: ''
  };
  this.searchTerm = '';
  this.applyFilters();
}

// Check if any filters are active
hasActiveFilters(): boolean {
  return (
    this.filters.category !== '' ||
    this.filters.stockStatus !== '' ||
    this.filters.minPrice !== null ||
    this.filters.maxPrice !== null ||
    this.filters.addedAfter !== '' ||
    this.filters.addedBefore !== '' ||
    this.filters.productType !== '' ||
    this.filters.sortBy !== 'name_asc' ||
    this.searchTerm !== ''
  );
}

// Get active filters for display
getActiveFilters(): { key: string; label: string }[] {
  const activeFilters: { key: string; label: string }[] = [];

  if (this.searchTerm) {
    activeFilters.push({ key: 'search', label: `Search: "${this.searchTerm}"` });
  }

  if (this.filters.category) {
    activeFilters.push({ key: 'category', label: `Category: ${this.filters.category}` });
  }

  if (this.filters.stockStatus) {
    const statusLabels = {
      'in_stock': 'In Stock',
      'low_stock': 'Low Stock', 
      'out_of_stock': 'Out of Stock'
    };
    activeFilters.push({ 
      key: 'stockStatus', 
      label: `Stock: ${statusLabels[this.filters.stockStatus as keyof typeof statusLabels]}` 
    });
  }

  if (this.filters.minPrice !== null) {
    activeFilters.push({ key: 'minPrice', label: `Min Price: ₱${this.filters.minPrice}` });
  }

  if (this.filters.maxPrice !== null) {
    activeFilters.push({ key: 'maxPrice', label: `Max Price: ₱${this.filters.maxPrice}` });
  }

  if (this.filters.addedAfter) {
    activeFilters.push({ key: 'addedAfter', label: `After: ${this.filters.addedAfter}` });
  }

  if (this.filters.addedBefore) {
    activeFilters.push({ key: 'addedBefore', label: `Before: ${this.filters.addedBefore}` });
  }

  if (this.filters.productType) {
    const typeLabels = {
      'barcode': 'Barcode Products',
      'no_barcode': 'No Barcode Products'
    };
    activeFilters.push({ 
      key: 'productType', 
      label: `Type: ${typeLabels[this.filters.productType as keyof typeof typeLabels]}` 
    });
  }

  if (this.filters.sortBy !== 'name_asc') {
    const sortLabels = {
      'name_desc': 'Name (Z-A)',
      'price_asc': 'Price (Low to High)',
      'price_desc': 'Price (High to Low)',
      'stock_asc': 'Stock (Low to High)',
      'stock_desc': 'Stock (High to Low)',
      'date_desc': 'Newest First',
      'date_asc': 'Oldest First'
    };
    activeFilters.push({ 
      key: 'sortBy', 
      label: `Sort: ${sortLabels[this.filters.sortBy as keyof typeof sortLabels]}` 
    });
  }

  return activeFilters;
}
async showOutOfStock() {
  try {
    const outOfStockProducts = await this.productService.getOutOfStockProducts();
    
    if (outOfStockProducts.length === 0) {
      await this.showToast('No out of stock products found', 'success');
      return;
    }

    // Set the products and show the modal (you'll need to create this modal)
    this.outOfStockProducts = outOfStockProducts;
    this.showOutOfStockModal = true;

  } catch (error: any) {
    await this.showToast(error.message, 'danger');
  }
}
closeOutOfStockModal() {
  this.showOutOfStockModal = false;
  this.outOfStockProducts = [];
}

// Filter to show only out of stock products
filterToOutOfStockProducts() {
  this.searchTerm = 'out of stock';
  this.filteredProducts = [...this.outOfStockProducts];
  this.closeOutOfStockModal();
}
  // Product Modal Methods
  openAddProductModal() {
    this.selectedProduct = null;
    this.formProduct = this.getDefaultProduct();
    this.enableBulkPricing = false;
    this.scannedProduct = null;
    this.showProductModal = true;
  }

// Update editProduct to handle bulk options
editProduct(product: Product) {
  this.selectedProduct = product;
  this.formProduct = { ...product };
  
  // Initialize bulk_options if undefined
  this.formProduct.bulk_options = this.formProduct.bulk_options ?? [];
  
  const hasBulkOptions = this.formProduct.bulk_options.length > 0;
  
  this.enableBulkPricing = !!(product.bulk_unit && product.pieces_per_bulk && product.bulk_selling_price) || 
                           hasBulkOptions;
  
  this.enableAdvancedBulk = hasBulkOptions;
  this.scannedProduct = null;
  this.showProductModal = true;
}

  closeProductModal() {
    this.showProductModal = false;
    this.selectedProduct = null;
    this.formProduct = this.getDefaultProduct();
    this.scannedProduct = null;
  }

    // Enhanced form validation
    isFormValid(): boolean {
      // Basic required fields
      const basicValid = !!(
        this.formProduct.name &&
        this.formProduct.category &&
        this.formProduct.stock_quantity >= 0 &&
        this.formProduct.cost_price >= 0 &&
        this.formProduct.selling_price >= 0 &&
        this.formProduct.unit_of_measure
      );

      // Product type specific validation - ensure has_barcode is treated as boolean
      const hasBarcode = this.formProduct.has_barcode ?? true;
      
      if (hasBarcode) {
        return basicValid && !!this.formProduct.barcode;
      } else {
        return basicValid && !!this.formProduct.custom_product_id;
      }
    }

  async saveProduct() {
    if (!this.isFormValid()) {
      await this.showToast('Please fill all required fields correctly', 'warning');
      return;
    }

    this.isSaving = true;
    try {
      if (this.selectedProduct) {
        await this.productService.updateProduct(this.selectedProduct.id!, this.formProduct);
        await this.showToast('Product updated successfully!', 'success');
      } else {
        await this.productService.createProduct(this.formProduct);
        await this.showToast('Product added successfully!', 'success');
      }

      this.closeProductModal();
      await this.loadProducts();

    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      this.isSaving = false;
    }
  }

  // Stock Adjustment Methods
  adjustStock(product: Product) {
    this.selectedProduct = product;
    this.stockAdjustment = {
      type: 'stock_in',
      quantity: 0,
      reason: ''
    };
    this.showStockModal = true;
  }

  closeStockModal() {
    this.showStockModal = false;
    this.selectedProduct = null;
    this.stockAdjustment = {
      type: 'stock_in',
      quantity: 0,
      reason: ''
    };
  }

  onAdjustmentTypeChange() {
    this.stockAdjustment.quantity = 0;
  }

  calculateNewStock(): number {
    if (!this.selectedProduct) return 0;

    const currentStock = this.selectedProduct.stock_quantity;
    const adjustment = this.stockAdjustment.quantity;

    switch (this.stockAdjustment.type) {
      case 'stock_in':
        return currentStock + adjustment;
      case 'stock_out':
        return currentStock - adjustment;
      case 'set':
        return adjustment;
      default:
        return currentStock;
    }
  }

  getNewStockColor(): string {
    const newStock = this.calculateNewStock();
    const minStock = this.selectedProduct?.min_stock_level || 0;

    if (newStock === 0) return 'danger';
    if (newStock <= minStock) return 'warning';
    return 'success';
  }

  isStockFormValid(): boolean {
    return !!(
      this.stockAdjustment.quantity > 0 &&
      this.stockAdjustment.reason.trim() &&
      this.selectedProduct
    );
  }

  async saveStockAdjustment() {
    if (!this.isStockFormValid() || !this.selectedProduct) {
      await this.showToast('Please fill all required fields', 'warning');
      return;
    }

    this.isAdjustingStock = true;
    try {
      const newQuantity = this.calculateNewStock();
      
      if (this.stockAdjustment.type === 'stock_out' && newQuantity < 0) {
        await this.showToast('Cannot remove more stock than available', 'warning');
        return;
      }

      await this.productService.updateStock(
        this.selectedProduct.id!,
        newQuantity,
        this.stockAdjustment.reason,
        this.stockAdjustment.type
      );

      await this.showToast('Stock updated successfully!', 'success');
      this.closeStockModal();
      await this.loadProducts();

    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      this.isAdjustingStock = false;
    }
  }

  // Product Actions
  async deleteProduct(product: Product) {
    const alert = await this.alertController.create({
      header: 'Delete Product',
      message: `Are you sure you want to delete "${product.name}"? This action cannot be undone.`,
      buttons: [
        {
          text: 'Cancel',
          role: 'cancel'
        },
        {
          text: 'Delete',
          role: 'destructive',
          handler: async () => {
            await this.confirmDeleteProduct(product.id!);
          }
        }
      ]
    });

    await alert.present();
  }

  async confirmDeleteProduct(productId: string) {
    const loading = await this.loadingController.create({
      message: 'Deleting product...'
    });
    
    await loading.present();

    try {
      await this.productService.deleteProduct(productId);
      await this.showToast('Product deleted successfully', 'success');
      await this.loadProducts();
    } catch (error: any) {
      await this.showToast(error.message, 'danger');
    } finally {
      await loading.dismiss();
    }
  }

  // Product Details Methods
  async viewProductDetails(product: Product) {
    try {
      const loading = await this.loadingController.create({
        message: 'Loading product details...'
      });
      await loading.present();

      const transactions = await this.productService.getProductTransactions(product.id!);
      
      await loading.dismiss();

      let transactionsHtml = '<p><em>No transactions found</em></p>';
      if (transactions.length > 0) {
        transactionsHtml = transactions.slice(0, 5).map(t => `
          <p><strong>${new Date(t.created_at.toDate()).toLocaleDateString()}:</strong> 
          ${this.formatTransactionType(t.type)} - ${t.quantity} units - ${t.reason}</p>
        `).join('');
      }

      const alert = await this.alertController.create({
        header: product.name,
        message: `
          <div style="text-align: left;">
            ${product.image_url ? `<img src="${product.image_url}" alt="${product.name}" style="max-width: 200px; margin-bottom: 16px; border-radius: 8px;">` : ''}
            <p><strong>Barcode:</strong> ${product.barcode}</p>
            <p><strong>Category:</strong> ${product.category}</p>
            <p><strong>Brand:</strong> ${product.brand || 'N/A'}</p>
            <p><strong>Description:</strong> ${product.description || 'N/A'}</p>
            <p><strong>Current Stock:</strong> ${product.stock_quantity} ${product.unit_of_measure}</p>
            <p><strong>Stock Range:</strong> ${product.min_stock_level} - ${product.max_stock_level}</p>
            <p><strong>Price:</strong> ₱${product.selling_price.toFixed(2)} per ${product.unit_of_measure}</p>
            ${product.bulk_unit ? `
              <p><strong>Bulk Price:</strong> ₱${product.bulk_selling_price?.toFixed(2)} per ${product.pieces_per_bulk} ${product.bulk_unit}</p>
            ` : ''}
            <p><strong>Cost Price:</strong> ₱${product.cost_price.toFixed(2)}</p>
            
            <h4 style="margin-top: 16px; margin-bottom: 8px;">Recent Transactions:</h4>
            ${transactionsHtml}
          </div>
        `,
        buttons: [
          {
            text: 'Adjust Stock',
            handler: () => {
              this.adjustStock(product);
            }
          },
          {
            text: 'Edit',
            handler: () => {
              this.editProduct(product);
            }
          },
          {
            text: 'Close',
            role: 'cancel'
          }
        ]
      });

      await alert.present();

    } catch (error: any) {
      await this.showToast('Error loading product details: ' + error.message, 'danger');
    }
  }

  // Old Scanner Methods (for compatibility)
  openScanner() {
    this.showScannerModal = true;
  }

  closeScannerModal() {
    this.showScannerModal = false;
  }

  startScanner() {
    this.isScanning = true;
  }

  stopScanner() {
    this.isScanning = false;
  }

  scanAgain() {
    this.scannedProduct = null;
  }

  // Update getDefaultProduct to initialize bulk_options
getDefaultProduct(): Product {
  const currentUser = this.authService.getCurrentUser();
  
  return {
    barcode: '',
    name: '',
    description: '',
    category: 'Groceries',
    brand: '',
    stock_quantity: 0,
    min_stock_level: 10,
    max_stock_level: 100,
    cost_price: 0,
    selling_price: 0,
    unit_of_measure: 'piece',
    image_url: '',
    is_active: true,
    store_owner_id: currentUser?.id || '',
    created_at: new Date(),
    updated_at: new Date(),
    has_barcode: true, // Explicitly set to boolean
    custom_product_id: '', // Initialize empty
    bulk_options: [] // Initialize empty array
  };
}

  getStockStatusClass(product: Product): string {
    if (product.stock_quantity === 0) return 'product-out-of-stock';
    if (product.stock_quantity <= product.min_stock_level) return 'product-low-stock';
    return 'product-in-stock';
  }

  getStockStatusColor(product: Product): string {
    if (product.stock_quantity === 0) return 'danger';
    if (product.stock_quantity <= product.min_stock_level) return 'warning';
    return 'success';
  }

  getStockStatusText(product: Product): string {
    if (product.stock_quantity === 0) return 'Out of Stock';
    if (product.stock_quantity <= product.min_stock_level) return 'Low Stock';
    return 'In Stock';
  }

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

  handleImageError(event: any) {
    event.target.style.display = 'none';
    if (event.target.nextElementSibling) {
      event.target.nextElementSibling.style.display = 'flex';
    }
  }

async showLowStock() {
  try {
    const lowStockProducts = await this.productService.getLowStockProducts();
    
    if (lowStockProducts.length === 0) {
      await this.showToast('No low stock products found', 'success');
      return;
    }

    // Set the products and show the modal
    this.lowStockProducts = lowStockProducts;
    this.showLowStockModal = true;

  } catch (error: any) {
    await this.showToast(error.message, 'danger');
  }
}

closeLowStockModal() {
  this.showLowStockModal = false;
  this.lowStockProducts = [];
}

// Optional: Filter to show only low stock products
filterToLowStockProducts() {
  this.searchTerm = 'low stock';
  this.filteredProducts = [...this.lowStockProducts];
  this.closeLowStockModal();
}

  async exportInventory() {
    await this.showToast('Export feature coming soon!', 'info');
  }

  // Modal-based product details
  async openProductDetailsModal(product: Product) {
    this.productDetails = product;
    
    const loading = await this.loadingController.create({
      message: 'Loading product details...'
    });
    
    try {
      await loading.present();
      this.productTransactions = await this.productService.getProductTransactions(product.id!);
      await loading.dismiss();
      
      this.showProductDetailsModal = true;
    } catch (error: any) {
      await loading.dismiss();
      await this.showToast('Error loading product details', 'danger');
    }
  }

  closeProductDetailsModal() {
    this.showProductDetailsModal = false;
    this.productDetails = null;
    this.productTransactions = [];
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

  // Add this to your Tab4Page to test immediately
async testStoreOwnerDetection() {
  console.log('🔍 TEST: Store Owner Detection');
  
  const currentUser = this.authService.getCurrentUser();
  console.log('👤 Current User:', {
    id: currentUser?.id,
    role: currentUser?.role,
    store_owner_id: currentUser?.store_owner_id,
    full_name: currentUser?.full_name
  });

  // Test the product service method directly
  const storeOwnerId = (this.productService as any).getCurrentStoreOwnerId?.();
  console.log('🎯 Product Service Store Owner ID:', storeOwnerId);

  // Expected store owner ID for employees
  const expectedStoreOwnerId = currentUser?.role === 'Employee' 
    ? currentUser.store_owner_id 
    : currentUser?.id;
  
  console.log('✅ Expected Store Owner ID:', expectedStoreOwnerId);
  console.log('❓ Match:', storeOwnerId === expectedStoreOwnerId);
}

// Add this to your Tab4Page to test barcode search
async testSpecificBarcodeSearch() {
  const testBarcode = '0067238891183'; // Your Dove product barcode
  
  console.log('🔍 TEST: Specific Barcode Search');
  console.log('🎯 Testing barcode:', testBarcode);
  
  // Test the product service directly
  const product = await this.productService.getProductByBarcode(testBarcode);
  console.log('🔍 Direct getProductByBarcode result:', product);
  
  if (product) {
    console.log('✅ Product FOUND in database:', product.name);
  } else {
    console.log('❌ Product NOT FOUND in database');
    
    // Let's check what products we have
    const allProducts = await this.productService.getStoreProducts();
    console.log('📦 All products barcodes:', allProducts.map(p => p.barcode));
    
    // Check if any product has a similar barcode
    const similarProducts = allProducts.filter(p => 
      p.barcode.includes(testBarcode) || testBarcode.includes(p.barcode)
    );
    console.log('🔍 Similar products found:', similarProducts);
  }
}

// Add this method to your Tab4Page class
getTransactionColor(type: string): string {
  const colorMap: { [key: string]: string } = {
    'stock_in': 'success',
    'stock_out': 'danger', 
    'set': 'warning',
    'adjustment': 'primary'
  };
  return colorMap[type] || 'medium';
}

// Update your existing formatTransactionType method:
formatTransactionType(type: string): string {
  const typeMap: { [key: string]: string } = {
    'stock_in': 'Stock In',
    'stock_out': 'Stock Out', 
    'set': 'Set Quantity',
    'adjustment': 'Adjustment'
  };
  return typeMap[type] || type;
}
}