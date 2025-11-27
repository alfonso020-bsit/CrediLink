import { Component, OnInit } from '@angular/core';
import { AlertController, ToastController, LoadingController } from '@ionic/angular';
import { ProductService, Product } from 'src/app/services/product.service';
import { AuthService } from 'src/app/services/auth.service';
import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';

@Component({
  selector: 'app-storeowner-tab4',
  templateUrl: './tab4.page.html',
  styleUrls: ['./tab4.page.scss'],
  standalone: false,
})
export class Tab4Page implements OnInit {

  // Product data
  products: Product[] = [];
  filteredProducts: Product[] = [];
  searchTerm: string = '';
  activeFilter: string = '';

  // Modal states
  showProductDetailsModal = false;
  showLowStockModal = false;

  // Loading states
  isLoading = false;

  // Product summary
  productSummary = {
    total_products: 0,
    in_stock: 0,
    low_stock: 0,
    out_of_stock: 0
  };

  // Product details
  productDetails: Product | null = null;

  // Low stock products
  lowStockProducts: Product[] = [];
  outOfStockProducts: Product[] = [];
  inStockProducts: Product[] = [];

  constructor(
    private productService: ProductService,
    private authService: AuthService,
    private alertController: AlertController,
    private toastController: ToastController,
    private loadingController: LoadingController
  ) { }
    // Add this method to your component class
 // Replace your current formatPrice method with this:
  private formatPrice(price: any): string {
    console.log('🔧 formatPrice called with:', price, 'Type:', typeof price);
    
    if (price === null || price === undefined) {
      return '0.00';
    }
    
    // If it's already a number, just format it
    if (typeof price === 'number') {
      console.log('✅ Already a number, formatting:', price.toFixed(2));
      return price.toFixed(2);
    }
    
    const priceStr = price.toString().trim();
    console.log('🔧 Price string:', priceStr);
    
    // Handle the specific problematic format: "±4 5 . 0 0"
    if (priceStr.includes('±') || /\d\s+\d/.test(priceStr)) {
      console.log('🔄 Detected problematic format, cleaning...');
      
      // Remove all special characters and spaces
      let cleanedPrice = priceStr
        .replace(/[±₱&]/g, '')  // Remove special symbols
        .replace(/\s/g, '')     // Remove all spaces
        .replace(/[^\d.]/g, ''); // Remove any other non-numeric except decimal
      
      console.log('🔧 After cleaning:', cleanedPrice);
      
      // If we have something like "45.00", parse it
      if (cleanedPrice) {
        const numPrice = parseFloat(cleanedPrice);
        if (!isNaN(numPrice)) {
          console.log('✅ Successfully parsed:', numPrice.toFixed(2));
          return numPrice.toFixed(2);
        }
      }
    }
    
    // For normal string numbers
    if (typeof price === 'string') {
      const cleaned = price.replace(/[^\d.]/g, '');
      const numPrice = parseFloat(cleaned);
      const result = isNaN(numPrice) ? '0.00' : numPrice.toFixed(2);
      console.log('✅ Normal string conversion:', result);
      return result;
    }
    
    console.log('❌ Could not parse, returning 0.00');
    return '0.00';
  }
  async ngOnInit() {
    await this.loadProducts();
  }

  async ionViewWillEnter() {
    await this.loadProducts();
  }

  // Product Management Methods
  async loadProducts() {
    this.isLoading = true;
    try {
      this.products = await this.productService.getStoreProducts();
      this.filteredProducts = [...this.products];
      this.updateProductSummary();
      console.log('✅ Inventory loaded:', this.products.length, 'products');
    } catch (error: any) {
      console.error('❌ Error loading inventory:', error);
      await this.showToast(error.message, 'danger');
    } finally {
      this.isLoading = false;
    }
  }

  updateProductSummary() {
    this.inStockProducts = this.products.filter(p => p.stock_quantity > p.min_stock_level);
    this.lowStockProducts = this.products.filter(p => 
      p.stock_quantity > 0 && p.stock_quantity <= p.min_stock_level
    );
    this.outOfStockProducts = this.products.filter(p => p.stock_quantity === 0);

    this.productSummary = {
      total_products: this.products.length,
      in_stock: this.inStockProducts.length,
      low_stock: this.lowStockProducts.length,
      out_of_stock: this.outOfStockProducts.length
    };
  }

  filterProducts() {
    if (!this.searchTerm) {
      this.filteredProducts = [...this.products];
      return;
    }

    const term = this.searchTerm.toLowerCase();
    this.filteredProducts = this.products.filter(product =>
      product.name.toLowerCase().includes(term) ||
      product.barcode.toLowerCase().includes(term) ||
      product.category.toLowerCase().includes(term) ||
      (product.brand && product.brand.toLowerCase().includes(term)) ||
      (product.description && product.description.toLowerCase().includes(term))
    );
  }

  // Quick Actions
  async showLowStock() {
    if (this.lowStockProducts.length === 0) {
      await this.showToast('No low stock products found', 'success');
      return;
    }
    this.showLowStockModal = true;
  }

  async showOutOfStock() {
    if (this.outOfStockProducts.length === 0) {
      await this.showToast('No out of stock products found', 'success');
      return;
    }

    this.activeFilter = 'Out of Stock';
    this.filteredProducts = [...this.outOfStockProducts];
    this.showToast(`Showing ${this.outOfStockProducts.length} out of stock products`, 'warning');
  }

  showAllProducts() {
    this.clearFilter();
    this.showToast('Showing all products', 'success');
  }

  clearFilter() {
    this.activeFilter = '';
    this.searchTerm = '';
    this.filteredProducts = [...this.products];
  }

  getFilterColor(): string {
    switch (this.activeFilter) {
      case 'Low Stock': return 'warning';
      case 'Out of Stock': return 'danger';
      default: return 'primary';
    }
  }

  // PDF Export Functionality
 // PDF Export Functionality
async exportInventory() {
  const loading = await this.loadingController.create({
    message: 'Generating PDF report...',
  });
  await loading.present();

  try {
    await this.generatePDFReport();
    await this.showToast('PDF report downloaded successfully!', 'success');
  } catch (error: any) {
    console.error('Error generating PDF:', error);
    await this.showToast('Error generating PDF report: ' + error.message, 'danger');
  } finally {
    await loading.dismiss();
  }
}

private async generatePDFReport() {
  return new Promise((resolve, reject) => {
    try {
      const doc = new jsPDF();
      const currentUser = this.authService.getCurrentUser();
      const storeName = currentUser?.store_name || 'My Store';
      const ownerName = currentUser?.full_name || 'Store Owner';
      const currentDate = new Date().toLocaleDateString();
      const currentTime = new Date().toLocaleTimeString();

      // 🔥 ADD DEBUG LOGS TO SEE WHAT'S HAPPENING
      console.log('=== PDF GENERATION DEBUG ===');
      if (this.inStockProducts.length > 0) {
        const sampleProduct = this.inStockProducts[0];
        console.log('Sample Product Debug:');
        console.log('  Product Name:', sampleProduct.name);
        console.log('  Raw Selling Price:', sampleProduct.selling_price, 'Type:', typeof sampleProduct.selling_price);
        console.log('  Raw Cost Price:', sampleProduct.cost_price, 'Type:', typeof sampleProduct.cost_price);
        console.log('  Formatted Selling:', this.formatPrice(sampleProduct.selling_price));
        console.log('  Formatted Cost:', this.formatPrice(sampleProduct.cost_price));
        
        // Test the formatPrice function directly
        const testInput = '±4 5 . 0 0';
        console.log('  Test formatPrice("±4 5 . 0 0"):', this.formatPrice(testInput));
      }
      console.log('=== END DEBUG ===');

      // Title Section
      doc.setFontSize(20);
      doc.setTextColor(40, 40, 40);
      doc.text('INVENTORY REPORT', 105, 20, { align: 'center' });
      
      doc.setFontSize(12);
      doc.setTextColor(100, 100, 100);
      doc.text(storeName, 105, 30, { align: 'center' });
      doc.text(`Owner: ${ownerName}`, 105, 36, { align: 'center' });
      doc.text(`Generated on: ${currentDate} at ${currentTime}`, 105, 42, { align: 'center' });

      // Summary Section
      doc.setFontSize(14);
      doc.setTextColor(40, 40, 40);
      doc.text('SUMMARY', 20, 55);

      autoTable(doc, {
        startY: 60,
        head: [['Total Products', 'In Stock', 'Low Stock', 'Out of Stock']],
        body: [[
          this.productSummary.total_products.toString(),
          this.productSummary.in_stock.toString(),
          this.productSummary.low_stock.toString(),
          this.productSummary.out_of_stock.toString()
        ]],
        theme: 'grid',
        headStyles: { fillColor: [66, 139, 202] },
        styles: { fontSize: 11, cellPadding: 3 }
      });

      let finalY = (doc as any).lastAutoTable.finalY + 15;

      // In Stock Products Table
      if (this.inStockProducts.length > 0) {
        doc.setFontSize(14);
        doc.setTextColor(34, 139, 34); // Green color for in stock
        doc.text('IN STOCK PRODUCTS', 20, finalY);
        
        // 🔥 ADD MORE DEBUGGING FOR EACH PRODUCT
        const inStockData = this.inStockProducts.map(product => {
          const formattedSelling = this.formatPrice(product.selling_price);
          const formattedCost = this.formatPrice(product.cost_price);
          
          console.log(`Product: ${product.name}`);
          console.log(`  Selling: ${product.selling_price} -> ${formattedSelling}`);
          console.log(`  Cost: ${product.cost_price} -> ${formattedCost}`);
          
          return [
            product.name,
            product.barcode,
            product.category,
            product.brand || 'N/A',
            `${product.stock_quantity} ${product.unit_of_measure}`,
            `PHP${formattedSelling}`,
            `PHP${formattedCost}`
          ];
        });

        autoTable(doc, {
          startY: finalY + 5,
          head: [['Product Name', 'Barcode', 'Category', 'Brand', 'Stock', 'Selling Price', 'Cost Price']],
          body: inStockData,
          theme: 'grid',
          headStyles: { fillColor: [34, 139, 34] },
          styles: { fontSize: 9, cellPadding: 2 },
          columnStyles: {
            5: { cellWidth: 25 }, // Selling Price column
            6: { cellWidth: 25 }  // Cost Price column
          }
        });

        finalY = (doc as any).lastAutoTable.finalY + 15;
      }

      // Low Stock Products Table
      if (this.lowStockProducts.length > 0) {
        // Add new page if needed
        if (finalY > 250) {
          doc.addPage();
          finalY = 20;
        }

        doc.setFontSize(14);
        doc.setTextColor(255, 165, 0); // Orange color for low stock
        doc.text('LOW STOCK PRODUCTS (NEEDS RESTOCKING)', 20, finalY);
        
        const lowStockData = this.lowStockProducts.map(product => [
          product.name,
          product.barcode,
          product.category,
          product.brand || 'N/A',
          `${product.stock_quantity}/${product.min_stock_level} ${product.unit_of_measure}`,
          `PHP${this.formatPrice(product.selling_price)}`,
          `PHP${this.formatPrice(product.cost_price)}`
        ]);

        autoTable(doc, {
          startY: finalY + 5,
          head: [['Product Name', 'Barcode', 'Category', 'Brand', 'Stock (Current/Min)', 'Selling Price', 'Cost Price']],
          body: lowStockData,
          theme: 'grid',
          headStyles: { fillColor: [255, 165, 0] },
          styles: { fontSize: 9, cellPadding: 2 },
          columnStyles: {
            5: { cellWidth: 25 }, // Selling Price column
            6: { cellWidth: 25 }  // Cost Price column
          }
        });

        finalY = (doc as any).lastAutoTable.finalY + 15;
      }

      // Out of Stock Products Table
      if (this.outOfStockProducts.length > 0) {
        // Add new page if needed
        if (finalY > 250) {
          doc.addPage();
          finalY = 20;
        }

        doc.setFontSize(14);
        doc.setTextColor(220, 53, 69); // Red color for out of stock
        doc.text('OUT OF STOCK PRODUCTS (URGENT ATTENTION NEEDED)', 20, finalY);
        
        const outOfStockData = this.outOfStockProducts.map(product => [
          product.name,
          product.barcode,
          product.category,
          product.brand || 'N/A',
          `0/${product.min_stock_level} ${product.unit_of_measure}`,
          `PHP${this.formatPrice(product.selling_price)}`,
          `PHP${this.formatPrice(product.cost_price)}`
        ]);

        autoTable(doc, {
          startY: finalY + 5,
          head: [['Product Name', 'Barcode', 'Category', 'Brand', 'Stock (Current/Min)', 'Selling Price', 'Cost Price']],
          body: outOfStockData,
          theme: 'grid',
          headStyles: { fillColor: [220, 53, 69] },
          styles: { fontSize: 9, cellPadding: 2 },
          columnStyles: {
            5: { cellWidth: 25 }, // Selling Price column
            6: { cellWidth: 25 }  // Cost Price column
          }
        });

        finalY = (doc as any).lastAutoTable.finalY + 15;
      }

      // Footer
      if (finalY > 270) {
        doc.addPage();
        finalY = 20;
      }

      doc.setFontSize(10);
      doc.setTextColor(100, 100, 100);
      doc.text('--- End of Report ---', 105, finalY + 10, { align: 'center' });

      // Generate filename with timestamp
      const timestamp = new Date().toISOString().slice(0, 19).replace(/[:.]/g, '-');
      const filename = `Inventory_Report_${storeName.replace(/\s+/g, '_')}_${timestamp}.pdf`;

      // Save the PDF
      doc.save(filename);
      resolve(true);

    } catch (error) {
      reject(error);
    }
  });
}

  // Product Details Methods
  openProductDetailsModal(product: Product) {
    this.productDetails = product;
    this.showProductDetailsModal = true;
  }

  closeProductDetailsModal() {
    this.showProductDetailsModal = false;
    this.productDetails = null;
  }

  closeLowStockModal() {
    this.showLowStockModal = false;
  }

  // Stock Status Helpers
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
}